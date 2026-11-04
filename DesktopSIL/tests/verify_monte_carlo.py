"""MC sampling, numerical definitions, real parallel trials and resume checks."""
from pathlib import Path
import copy
import json
import sys
import threading
import time
import unittest
from unittest.mock import patch
import tempfile
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import monte_carlo as mc
import mc_charts
import runner
import storage


def design():
    d=mc.default_design(runner.load_case(runner.ROOT/'presets/noisy_recovery.json'))
    d['base'].update(duration=2,log_hz=400,noise=True); d.update(count=4,workers=2,grid_points=101)
    return d


class SamplingTests(unittest.TestCase):
    def test_atomic_manifest_transient_reader(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT/'build') as directory:
            path=Path(directory)/'manifest.json'; mc.atomic_json(path,{'old':True})
            original=Path.replace; failures=[]
            def replacement(source,destination):
                if len(failures)<2:
                    failures.append(1)
                    self.assertEqual(storage.read_json(path),{'old':True})
                    raise PermissionError('Transient reader')
                return original(source,destination)
            with patch.object(Path,'replace',replacement): mc.atomic_json(path,{'new':True})
            self.assertEqual(storage.read_json(path),{'new':True})

    def test_reproducible_and_latin_strata(self):
        d=design(); d['count']=20; d['include_nominal']=False; d['variables']=d['variables'][:1]
        a=mc.sample_design(d); self.assertEqual(a,mc.sample_design(d))
        x=np.array([r['values']['plant.m'] for r in a])/d['base']['plant']['m']
        self.assertEqual(sorted(np.floor((x-.95)/.1*20).astype(int)),list(range(20)))
        self.assertEqual(len({r['noise_seed'] for r in a}),20)
        d['noise_seeds']='common'; b=mc.sample_design(d)
        self.assertEqual([r['values'] for r in a],[r['values'] for r in b])
        self.assertEqual({r['noise_seed'] for r in b},{d['base']['seed']})

    def test_distributions_groups_integer_and_symmetry(self):
        u=np.linspace(.001,.999,99)
        for kind,args,lo,hi in [('uniform',[2,3],2,3),('truncated normal',[2,1,1,3],1,3),('log uniform',[1,100],1,100),('triangular',[1,2,4],1,4)]:
            values=np.asarray(mc.draw_distribution({'distribution':kind,'args':args},u))
            self.assertTrue(np.all((values>=lo)&(values<=hi)))
        self.assertAlmostEqual(mc.draw_distribution({'distribution':'normal','args':[4,2]},np.array([.5]))[0],4)
        self.assertEqual(mc.draw_distribution({'distribution':'choices','args':[False,True]},np.array([.2,.8])),[False,True])
        d=design(); d['include_nominal']=False
        d['variables']=[{'path':'plant.CDx','distribution':'uniform','mode':'absolute','args':[1,2],'group':'drag'},
            {'path':'plant.CDy','distribution':'uniform','mode':'absolute','args':[1,2],'group':'-drag'},
            {'path':'firmware.p_roll','distribution':'normal','mode':'absolute','args':[21,1],'group':''}]
        rows=mc.sample_design(d)
        for r in rows:
            self.assertAlmostEqual(r['values']['plant.CDx']+r['values']['plant.CDy'],3)
            self.assertIsInstance(r['values']['firmware.p_roll'],int)
        case=copy.deepcopy(d['base']); mc.set_parameter(case,'plant.tensor.0.1',1e-7)
        self.assertEqual(case['plant']['tensor'][1][0],1e-7)
        self.assertEqual(d['base']['plant']['tensor'][1][0],0)

    def test_invalid_is_not_resampled(self):
        d=design(); d['variables']=[{'path':'plant.m','distribution':'fixed','mode':'absolute','args':[-1],'group':''}]
        with self.assertRaisesRegex(ValueError,'No trials were resampled'): mc.sample_design(d)
        d=design(); d['variables'][0].update(path='initial.6')
        # Recovery roll is nonzero; test a zero-valued position instead.
        d['variables'][0]['path']='initial.0'
        with self.assertRaisesRegex(ValueError,'nonzero'): mc.sample_design(d)

    def test_metrics_and_criteria(self):
        base=design()['base']; record=storage.Record('.',base)
        t=np.array([0.,1.,2.]); values={'roll_rad':[.1,.1,.1],'pitch_rad':[0,0,0],
            'error_roll_rad':[.01,.01,.01],'error_pitch_rad':[0,0,0],
            'p_radps':[0,0,0],'q_radps':[0,0,0],'r_radps':[0,0,0],
            'x_m':[0,3,6],'y_m':[0,4,8],'z_m':[0,1,2],
            'reference_roll_rad':[0,0,0],'reference_pitch_rad':[0,0,0]}
        for i in range(1,5): values[f'motor{i}_pot']=[1800]*3
        for key,value in values.items(): record.add(key,t,value)
        result=mc.metric_values(record,design()['analysis'])
        self.assertAlmostEqual(result['horizontal_drift_m'],10)
        self.assertAlmostEqual(result['attitude_estimation_rms_deg'],np.rad2deg(.01))
        self.assertAlmostEqual(result['angle_tracking_rms_deg'],np.rad2deg(.1))
        self.assertIsNone(result['settling_time_s']); self.assertEqual(result['final_altitude_change_m'],-2)
        self.assertFalse(mc.assess(result,[{'metric':'settling_time_s','op':'<=','limit':4}])[0])

    def test_categorical_signals_and_cancellation(self):
        d=design(); d['variables']=[{'path':'fidelity','distribution':'choices','mode':'absolute','args':['high','low'],'group':''}]
        rows=mc.sample_design(d)
        self.assertEqual({r['values']['fidelity'] for r in rows if not r['nominal']},{'high','low'})
        cancelled=threading.Event(); cancelled.set()
        with self.assertRaises(InterruptedError): mc.sample_design(d,cancelled)
        d['signals']=['not_a_signal']
        with self.assertRaisesRegex(ValueError,'Unknown envelope'): mc.sample_design(d)


def integration():
    root=runner.ROOT/'runs'/'monte_carlo'; d=design(); folder=mc.create_study(d,root)
    manifest=mc.run_study(folder)
    assert all(r['status']=='complete' for r in manifest['rows']),manifest
    assert len({r['run_folder'] for r in manifest['rows']})==5
    assert mc.summarize(folder)['complete']==4
    # Same design, serial scheduling: exact saved signal arrays must be unchanged.
    serial=copy.deepcopy(d); serial['workers']=1; other=mc.create_study(serial,root); b=mc.run_study(other)
    for arow,brow in zip(manifest['rows'],b['rows']):
        a=storage.load_run(folder/arow['run_folder']); bb=storage.load_run(other/brow['run_folder'])
        assert arow['metrics']==brow['metrics']
        assert all(np.array_equal(a[key],bb[key]) for key in a.dtype.names),arow['id']
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_agg import FigureCanvasAgg
    exports=runner.ROOT/'verification/ui_exports/monte_carlo'; exports.mkdir(parents=True,exist_ok=True)
    payload=mc_charts.prepare(folder,'roll_rad','peak_tilt_deg','plant.m')
    assert payload['n']==4 and payload['envelope']['traces'].shape==(4,101)
    for view in mc_charts.VIEWS:
        fig=Figure(figsize=(10,5),layout='constrained'); FigureCanvasAgg(fig); mc_charts.render(fig,payload,view)
        fig.savefig(exports/(view.replace(' / ','_').replace(' ','_')+'.png'))
    mc_charts.export_envelope(payload,exports/'envelope.csv'); mc.export_results(folder,exports)
    analysis=copy.deepcopy(d['analysis']); analysis['criteria']=[{'metric':'peak_tilt_deg','op':'<=','limit':0}]
    mc.reprocess(folder,analysis); assert mc.summarize(folder)['criteria_pass']==0
    assert len(list((folder/'analysis_history').glob('*.json')))==1
    cancelled=threading.Event(); cancelled.set(); prior=(folder/'manifest.json').read_bytes()
    try: mc.reprocess(folder,d['analysis'],cancel=cancelled)
    except InterruptedError: pass
    else: raise AssertionError('Reprocessing ignored cancellation')
    assert (folder/'manifest.json').read_bytes()==prior
    lock=mc.acquire_study_lock(folder)
    try:
        try: mc.reprocess(folder,d['analysis'])
        except RuntimeError: pass
        else: raise AssertionError('Allowed two study writers')
    finally: lock.unlink()
    # Pausing before flight must not permit time advancement; stop and resume keep seeds.
    class Pausing(mc.BatchControl):
        def __init__(self): super().__init__(); self.ready=threading.Event()
        def register(self,kind,value):
            super().register(kind,value)
            if kind=='folder': self.pause(True)
            if kind=='process': self.ready.set()
    paused=design(); paused.update(count=2,workers=1,include_nominal=False)
    paused_folder=mc.create_study(paused,root); control=Pausing(); errors=[]
    def work():
        try: mc.run_study(paused_folder,control)
        except Exception as e: errors.append(str(e))
    thread=threading.Thread(target=work); thread.start(); assert control.ready.wait(15)
    start=time.monotonic(); spool=None
    while time.monotonic()-start<10:
        candidates=list(paused_folder.glob('runs/*/signals.bin'))
        if candidates: spool=candidates[0]; break
        time.sleep(.05)
    assert spool is not None
    size=spool.stat().st_size; time.sleep(.2); assert spool.stat().st_size==size
    control.stop(); thread.join(15); assert not thread.is_alive() and not errors,errors
    stopped=storage.read_json(paused_folder/'manifest.json'); assert stopped['status']=='stopped'
    resumed=mc.run_study(paused_folder); assert all(r['status']=='complete' for r in resumed['rows'])
    assert [r['noise_seed'] for r in stopped['rows']]==[r['noise_seed'] for r in resumed['rows']]
    assert resumed['rows'][0]['attempt']==2
    # Configuration-valid but insufficient warmup must be recorded as engine failure.
    bad=design(); bad.update(count=1,workers=1,include_nominal=False); bad['base'].update(warmup=0,arm_settle=0)
    bad_folder=mc.create_study(bad,root); failure=mc.run_study(bad_folder)
    assert failure['rows'][0]['status']=='failed' and failure['rows'][0]['error']
    assert mc.summarize(bad_folder)['complete']==0
    report={'passed':True,'parallel_serial_exact_match':True,'full_resolution_metrics':True,'nominal_excluded':True,
        'pause_stop_resume':True,'failed_trials_recorded':True,'chart_views':len(mc_charts.VIEWS),'reprocessing':True,
        'study':str(folder),'serial_study':str(other),'resumed_study':str(paused_folder),'failure_study':str(bad_folder)}
    (runner.ROOT/'verification/monte_carlo_acceptance.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2))


if __name__=='__main__':
    result=unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(SamplingTests))
    if not result.wasSuccessful(): raise SystemExit(1)
    integration()
