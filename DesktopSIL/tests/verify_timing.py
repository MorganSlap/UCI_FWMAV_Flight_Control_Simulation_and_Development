"""Measure actual native task dispatch, rather than trusting settings labels."""
from pathlib import Path
import json
import sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import runner
import storage
import configuration as cfg


def main():
    reports={}
    variants=(('bmi_angle','BMI270',3200,800,1,2,100,'angle'),
              ('bmi_rate','BMI270',3200,800,1,2,100,'rate'),
              ('bmi_dividers','BMI270',3200,800,2,4,250,'angle'),
              ('custom_8k','Custom',8000,1000,4,1,1000,'angle'),
              ('legacy','Legacy 4 kHz',3200,1600,1,2,100,'angle'))
    for name,profile,gyro,accel,pid,imu,rx,mode in variants:
        case=runner.load_case(runner.ROOT/'presets/noisy_hover.json')
        case.update(duration=2,noise=False,timing_profile=profile,rc_hz=rx,command_mode=mode)
        case['gyro']['sample_rate']=gyro; case['accel']['sample_rate']=accel
        cfg.set_firmware(case,'pid_process_denom',pid); cfg.set_firmware(case,'imu_process_denom',imu)
        folder=runner.execute(case,progress=lambda *args:None)
        summary=storage.read_json(folder/'engine_summary.json'); data=storage.load_run(folder)
        expected=cfg.timing(case)
        expected['attitude_hz']=expected['angle_attitude_hz'] if mode=='angle' else 100
        for task in ('gyro','pid','accel','attitude'):
            measured=summary['task_timing'][task]['measured_hz']
            assert abs(measured/expected[task+'_hz']-1)<.001,(name,task,measured,expected)
        assert summary['completed'] and np.all(data['armed']==1)
        assert np.all(data['gyro_period_us']==int(1e6/expected['gyro_hz']))
        assert np.all(data['pid_period_us']==int(1e6/expected['pid_hz']))
        assert len(data['time_s'])==8001 and data.signals['task_gyro_dt_s'].group=='Firmware task timing'
        reports[name]={'folder':str(folder),'expected':expected,**summary}
        print(name,json.dumps(summary['task_timing']),flush=True)
    old=runner.load_case(runner.ROOT/'presets/noisy_hover.json'); old.pop('timing_profile')
    assert cfg.upgrade(old)['timing_profile']=='Legacy 4 kHz'
    reports['passed']=True
    (runner.ROOT/'verification/timing_acceptance.json').write_text(json.dumps(reports,indent=2)+'\n')


if __name__=='__main__': main()
