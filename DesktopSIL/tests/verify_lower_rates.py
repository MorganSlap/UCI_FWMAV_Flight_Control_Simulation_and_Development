"""Compare lower ODE5 grids with 16 kHz using identical sensors and firmware."""
from pathlib import Path
import copy
import json
import sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import runner
import storage
import configuration as cfg
from verify_integrator import compare


def run(case):
    folder=runner.execute(case,progress=lambda *args:None)
    data=storage.load_run(folder); summary=storage.read_json(folder/'engine_summary.json')
    assert summary['completed'] and np.all(data['armed']==1)
    assert all(np.isfinite(data[k]).all() for k in data.dtype.names)
    expected=cfg.timing(case)
    for task in ('gyro','pid','accel'):
        assert abs(summary['task_timing'][task]['measured_hz']/expected[task+'_hz']-1)<1e-5
    assert summary['integration']['maximum_step_s']<=1/case['plant_hz']+1e-10
    assert data.settings['plant_hz']==case['plant_hz']
    assert data.metadata['measured_integration']==summary['integration']
    print(case['name'],case['plant_hz'],case['log_hz'],summary['integration'],flush=True)
    return data,summary


def main():
    report={}
    for name,preset,noise in (('quiet_recovery','noisy_recovery.json',False),('noisy_hover','noisy_hover.json',True)):
        case=runner.load_case(runner.ROOT/'presets'/preset)
        case.update(duration=60,plant_hz=16000,log_hz=4000,noise=noise)
        baseline,summary=run(case)
        results={'baseline':{'folder':str(baseline.folder),**summary}}
        for rate in (3200,4000,6400,8000):
            case['plant_hz']=rate
            data,summary=run(case); difference=compare(data,baseline)
            assert max(difference['max_attitude_difference_deg'])<(.05 if noise else .001),difference
            assert max(difference['max_position_difference_m'])<(.05 if noise else .001),difference
            expected_steps=6400 if rate in (3200,4000) else 9600
            assert summary['integration']['steps']==60*expected_steps
            results[str(rate)]={'folder':str(data.folder),'comparison_to_16000':difference,**summary}
            del data
        if not noise:
            case.update(plant_hz=3200,log_hz=3200)
            data,summary=run(case); difference=compare(data,baseline)
            assert summary['integration']['steps']==60*3200
            assert max(difference['max_attitude_difference_deg'])<.001,difference
            results['aligned_3200_logging']={'folder':str(data.folder),'comparison_to_16000':difference,**summary}
            del data
        report[name]=results
        del baseline
    # Both generated plants and a faster firmware clock must accept the lower base grid.
    case=runner.load_case(runner.ROOT/'presets/noisy_hover.json')
    case.update(duration=2,plant_hz=3200,fidelity='low',noise=False,timing_profile='Custom')
    case['gyro']['sample_rate']=8000; case['accel']['sample_rate']=1000
    data,summary=run(case)
    assert summary['integration']['mean_steps_per_second']>=8000
    report['linear_custom_8k']={'folder':str(data.folder),**summary}
    report['passed']=True
    (runner.ROOT/'verification/lower_integration_rates.json').write_text(json.dumps(report,indent=2)+'\n')
    print('All lower-rate acceptance checks passed.',flush=True)


if __name__=='__main__': main()
