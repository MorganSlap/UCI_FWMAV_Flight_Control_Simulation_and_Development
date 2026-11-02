"""Long-flight step-halving and archived ODE3 / regenerated ODE5 comparisons."""
from pathlib import Path
import copy,json,sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import runner,storage

def compare(a,b):
    time=a["time_s"]
    def maximum(keys,angular=False):
        differences=[]
        for key in keys:
            delta=a[key]-np.interp(time,b["time_s"],b[key])
            if angular: delta=np.rad2deg(np.arctan2(np.sin(delta),np.cos(delta)))
            differences.append(float(np.max(np.abs(delta))))
        return differences
    return {"max_attitude_difference_deg":maximum(["roll_rad","pitch_rad","yaw_rad"],True),
            "max_position_difference_m":maximum(["x_m","y_m","z_m"]),
            "max_rate_difference_radps":maximum(["p_radps","q_radps","r_radps"]),
            "final_roll_pitch_deg":[np.rad2deg(a[key][-1]).item() for key in ("roll_rad","pitch_rad")],
            "final_position_m":[float(a[key][-1]) for key in ("x_m","y_m","z_m")]}

def run(case):
    folder=runner.execute(case,progress=lambda kind,value:print(value,flush=True) if kind=="folder" else None)
    data=storage.load_run(folder)
    assert np.all(np.isfinite(data["roll_rad"])) and np.all(data["armed"]==1)
    return data

def main():
    report={"solver":"ode5","default_maximum_step_s":1/16000}
    baseline_report=runner.ROOT/"verification/ode3_baseline_acceptance.json"
    old_report=storage.read_json(baseline_report) if baseline_report.exists() else {}
    baseline_folder=old_report.get("hover_60_seconds",{}).get("folder")
    old=storage.load_run(baseline_folder) if baseline_folder and Path(baseline_folder).is_dir() else None
    case=copy.deepcopy(old.settings) if old is not None else runner.load_case(runner.ROOT/"presets/noisy_hover.json")
    case.update(plant_hz=16000,duration=60)
    current=run(case)
    if old is not None:
        report["ode3_vs_ode5_noisy_60s"]={**compare(old,current),"ode5_run":str(current.folder),"ode3_run":str(old.folder)}
    else:
        report["ode3_vs_ode5_noisy_60s"]={"status":"skipped","reason":"Archived ODE3 run is unavailable; run archives are not committed."}
    for key in ("roll_rad","pitch_rad","yaw_rad","p_radps","q_radps","r_radps"):
        error=current[key]-current["estimate_"+key]
        if key.endswith("_rad"): error=np.arctan2(np.sin(error),np.cos(error))
        assert np.allclose(current["error_"+key],error,rtol=0,atol=1e-12)
    assert np.all(np.isin(current["mahony_accel_accepted"],[0,1]))
    assert np.all(np.diff(current["mahony_update_count"])>=0)
    assert np.ptp(current["mahony_update_count"])>0
    assert np.std(current["filtered_input_p_radps"]-current["estimate_p_radps"])>0
    report["signal_definitions"]={"true_minus_estimated_verified":True,"mahony_input_taps_distinct_from_rate_feedback":True,
        "mahony_accel_acceptance_fraction":float(np.mean(current["mahony_accel_accepted"]))}
    del current,old
    for noise in (False,True):
        case=runner.load_case(runner.ROOT/"presets/noisy_recovery.json" if not noise else runner.ROOT/"presets/noisy_hover.json")
        case.update(duration=300,noise=noise,log_hz=200,plant_hz=16000)
        coarse=run(case); case["plant_hz"]=32000; fine=run(case)
        result=compare(coarse,fine); result.update(noise=noise,duration_s=300,runs=[str(coarse.folder),str(fine.folder)])
        report["step_halving_noisy" if noise else "step_halving_quiet_recovery"]=result
        if not noise:
            assert max(result["max_attitude_difference_deg"])<1e-5
            assert max(result["max_position_difference_m"])<1e-5
        del coarse,fine
    report["passed"]=True
    (runner.ROOT/"verification/integrator_convergence.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))

if __name__=="__main__": main()
