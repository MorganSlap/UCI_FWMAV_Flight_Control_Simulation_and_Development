"""Exercise MC UI while preserving existing single-run settings and plotting."""
from pathlib import Path
import copy
import json
import sys
import time
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from app import App
from tkinter import messagebox
import monte_carlo as mc
import mc_charts
import runner
import storage


def pump(app,predicate,timeout=40):
    start=time.monotonic()
    while not predicate():
        app.update()
        if time.monotonic()-start>timeout:
            panel=app.monte_carlo
            raise TimeoutError(f'UI operation timed out; busy={panel.busy}; status={panel.status.get()}; folder={panel.folder}')
        time.sleep(.02)
    app.update()


def main():
    errors=[]
    def error(title,text):
        errors.append(title+': '+str(text)); print(errors[-1],flush=True)
    messagebox.showerror=error
    app=App(); app.report_callback_exception=lambda *args:errors.append(str(args[1])); app.update()
    panel=app.monte_carlo
    try:
        app.fields['duration'].set('1'); app.fields['log_hz'].set('400')
        panel.capture_baseline(); baseline=copy.deepcopy(app.collect())
        app.pages.select(panel); app.update()
        panel.inputs['count'].set('3'); panel.inputs['workers'].set('2'); panel.inputs['grid_points'].set('101')
        for example in ('Initial attitude','PID gains','Sensor biases','Noise seeds only','Plant tolerances'):
            panel.example.set(example); panel.apply_example(); mc.sample_design(panel.collect())
        panel.parameter.set('firmware.angle_p_gain'); panel.dist.set('choices'); panel.mode.set('absolute'); panel.args.set('[18,20,22]'); panel.add_variable()
        assert any(v['path']=='firmware.angle_p_gain' for v in panel.variables)
        panel.rule_metric.set('peak_tilt_deg'); panel.rule_limit.set('25'); panel.add_rule()
        panel.start(); assert panel.busy
        pump(app,lambda:panel.folder is not None and not panel.busy and panel.payload is not None)
        study=panel.folder
        assert panel.manifest['status']=='finished' and panel.payload['n']==3
        assert all(r['status']=='complete' for r in panel.manifest['rows'])
        assert app.collect()==baseline,'Batch modified the single-run settings.'
        panel.tabs.select(2)
        app.update()
        assert panel.toolbar.winfo_ismapped() and panel.toolbar.winfo_height()>20,'Plot toolbar is clipped.'
        for view in mc_charts.VIEWS:
            panel.view.set(view); panel.refresh_chart(); pump(app,lambda:not panel.busy)
            assert panel.figure.axes
        # Rapid selector changes while chart work is in progress must render the last selection.
        panel.signal.set('pitch_rad'); panel.refresh_chart()
        panel.signal.set('error_roll_rad'); panel.refresh_chart()
        pump(app,lambda:not panel.busy and panel.payload['signal']=='error_roll_rad')
        panel.undock(); app.update()
        panel.trials.selection_set('1'); panel.open_trial()
        pump(app,lambda:app.data is not None and str(study) in str(app.data.folder))
        assert app.data.settings['name'].startswith(panel.design['name'])
        panel.inputs['start_s'].set('.1'); panel.rule_limit.set('0'); panel.add_rule(); panel.reprocess()
        pump(app,lambda:not panel.busy and panel.payload['summary']['criteria_pass']==0)
        assert storage.read_json(study/'analysis.json')['start_s']==.1
        panel.open_study(study); pump(app,lambda:not panel.busy)
        assert panel.inputs['start_s'].get()=='0.1'
        # Normal simulation must still work after batch, reprocessing and plotting.
        app.pages.select(0); app.fields['duration'].set('.5'); app.run()
        pump(app,lambda:not app.running)
        pump(app,lambda:app.data_folder==app.folder)
        assert app.data['time_s'][-1]==.5
        assert not errors,errors
        report={'passed':True,'batch_trials':3,'workers':2,'baseline_unchanged':True,'variation_examples':5,
            'chart_views':len(mc_charts.VIEWS),'rapid_selection':True,'open_trial_in_explorer':True,'undock':True,
            'reprocess_reload':True,'normal_run_after_batch':True,'callback_errors':errors,'study':str(study)}
        (runner.ROOT/'verification/monte_carlo_ui_acceptance.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report,indent=2))
    finally:
        panel.stop(); app.stop(); pump(app,lambda:not app.running and not panel.busy)
        app.destroy()
    # Closing the application during a batch must stop its owned child processes.
    closing=App(); closing.update(); cp=closing.monte_carlo
    cp.design['base']['duration']=60; cp.inputs['count'].set('4'); cp.inputs['workers'].set('2'); cp.start()
    pump(closing,lambda:cp.control is not None and bool(cp.control.processes))
    processes=list(cp.control.processes); closing.close(); start=time.monotonic()
    while True:
        try:
            closing.update()
            if not closing.winfo_exists(): break
        except Exception as e:
            if 'application has been destroyed' in str(e): break
            raise
        if time.monotonic()-start>20: raise TimeoutError('Closing during batch left the application running.')
        time.sleep(.02)
    assert all(p.poll() is not None for p in processes)
    assert not errors,errors
    report['close_stops_child_processes']=True
    (runner.ROOT/'verification/monte_carlo_ui_acceptance.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__': main()
