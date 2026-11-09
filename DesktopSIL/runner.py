"""Configure and run the native SIL. MATLAB is not imported or launched."""
from __future__ import annotations
import argparse
import copy
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid
import configuration as config_api
import runtime_support

ROOT = Path(__file__).resolve().parent
EXE = runtime_support.select_engine(ROOT)
FW_PROFILE = {f"{g}_{a}" for a in ("roll", "pitch", "yaw") for g in "pidf"} | {"angle_p_gain"}

def load_case(path):
    with open(path, encoding="utf-8-sig") as f:
        case = config_api.upgrade(json.load(f))
    validate(case)
    return case

def fw_value(case, name):
    return config_api.firmware_value(case,name)

def set_fw(case, name, value):
    config_api.set_firmware(case,name,value)

def validate(case):
    def number(value, name, low=None, high=None):
        if not isinstance(value, (int, float)) or not math.isfinite(value): raise ValueError(f"{name} must be finite.")
        if low is not None and value < low: raise ValueError(f"{name} must be at least {low}.")
        if high is not None and value > high: raise ValueError(f"{name} must be at most {high}.")
    number(case["duration"], "Duration", .001, 3600)
    number(case["throttle"], "Throttle", 1000, 2000)
    number(case["seed"], "Seed", 0, 4294967295)
    if int(case["seed"]) != case["seed"]: raise ValueError("Seed must be an integer.")
    number(case["reference_time"], "Reference start", 0, case["duration"])
    if case["command_mode"] not in ("angle", "rate", "receiver"): raise ValueError("Choose angle, rate or receiver mode.")
    for key in ("warmup", "arm_settle", "spoolup"): number(case[key], key, 0, 60)
    number(case["log_hz"],"Logging rate",1,16000)
    number(case.get("rc_hz",100),"Receiver rate",1,2000)
    if case.get("plant_hz",16000) not in config_api.INTEGRATION_RATES:
        raise ValueError("ODE5 base integration rate must be one of: "+", ".join(map(str,config_api.INTEGRATION_RATES))+" Hz.")
    profile=case.get("timing_profile","Legacy 4 kHz")
    if profile not in config_api.TIMING_PROFILES: raise ValueError("Choose a valid firmware timing profile.")
    if profile=="BMI270" and (case["gyro"]["sample_rate"]!=3200 or case["accel"]["sample_rate"]!=800):
        raise ValueError("BMI270 uses 3200 Hz gyro and 800 Hz accelerometer. Choose Custom to experiment with other rates.")
    if profile=="Custom":
        if case["gyro"]["sample_rate"] not in (1000,2000,3000,3200,4000,8000): raise ValueError("Custom gyro rates: 1000, 2000, 3000, 3200, 4000 or 8000 Hz.")
        if case["accel"]["sample_rate"] not in (100,200,400,800,1000,1600,2000,4000): raise ValueError("Choose a supported custom accelerometer rate.")
    for key in ("initial", "reference"):
        if len(case[key]) != 12: raise ValueError(f"{key} must have 12 values.")
        for x in case[key]: number(x, key)
    if abs(case["initial"][7]) >= 80: raise ValueError("Initial pitch must be inside ±80° (Euler plant singularity at ±90°).")
    # This plant has no altitude, position or heading feedback.
    # Full Xref is retained for MATLAB parity; native firmware consumes only
    # the active angle/rate entries, as in the existing adapter.
    plant = case["plant"]
    for key in ("m", "g", "S", "C11", "tau_wing"): number(plant[key], key, 1e-12)
    for key in ("rho", "Ax", "Ay", "Az", "Aomega", "CDx", "CDy", "CDz", "CDw"): number(plant[key], key, 0)
    number(plant["C21"], "C21")
    if len(plant["inertia"]) != 3: raise ValueError("Inertia requires three principal moments.")
    for x in plant["inertia"]: number(x, "Inertia", 1e-12)
    for key in ("gyro", "accel"):
        sensor = case[key]
        for item in ("density", "bandwidth", "vibration"): number(sensor[item], key + " " + item, 0)
        if len(sensor["bias"]) != 3: raise ValueError(f"{key} bias requires three values.")
        for x in sensor["bias"]: number(x, key + " bias")
        number(sensor.get("sample_rate",3200 if key=="gyro" else 1600),key+" sample rate",1,64000)
        number(sensor.get("range",1000 if key=="gyro" else 4),key+" range",1e-12)
        number(sensor.get("resolution_bits",16),key+" resolution bits",1,32)
    for key in ("receiver_flight", "receiver_disarmed", "receiver_armed"):
        if len(case[key]) != 16: raise ValueError(f"{key} must have 16 channels.")
        for x in case[key]: number(x, key, 750, 2250)
    for key in ("throttle_channel", "angle_channel"):
        number(case[key], key, 1, 16)
        if int(case[key]) != case[key]: raise ValueError(f"{key} must be an integer.")
    divider=float(fw_value(case,"pid_process_denom"))
    if divider!=int(divider) or not 1<=divider<=16: raise ValueError("PID divider must be an integer from 1 to 16.")
    divider=float(fw_value(case,"imu_process_denom"))
    if divider!=int(divider) or not 1<=divider<=4: raise ValueError("Attitude estimator divider must be an integer from 1 to 4.")
    if fw_value(case, "motor_pwm_protocol") != "PWM":
        raise ValueError("The plant adapter currently requires motor_pwm_protocol = PWM.")
    if case.get("fidelity","high") not in ("high","low"): raise ValueError("Choose high or low fidelity.")
    if sorted(case.get("motor_order",[1,2,3,4]))!=[1,2,3,4]: raise ValueError("Motor order must be a permutation of 1, 2, 3, 4.")
    previous=-1
    for row in case.get("schedule",[]):
        if len(row)!=4: raise ValueError("Each command row needs time, roll, pitch and yaw rate.")
        for x in row: number(x,"Command sequence")
        if row[0]<=previous or row[0]<0: raise ValueError("Command times must be nonnegative and strictly increasing.")
        previous=row[0]
    if case.get("schedule") and case["command_mode"]=="receiver": raise ValueError("Clear the command sequence before using raw receiver mode.")
    if "tensor" in plant:
        import numpy as np
        tensor=np.asarray(plant["tensor"])
        if tensor.shape!=(3,3) or not np.isfinite(tensor).all() or not np.allclose(tensor,tensor.T) or np.min(np.linalg.eigvalsh(tensor))<=0: raise ValueError("Inertia tensor must be symmetric and positive definite.")
    for key in ("wing_type","AxFactor","AyFactor","AzFactor","AomegaFactor","v_ref","w_ref","p_ref","q_ref","r_ref"):
        if key in plant: number(plant[key],key,1e-12 if key=="wing_type" else 0)
    for scope,count in (("profile",3),("rateprofile",6),("battery_profile",3)):
        value=case.get("profiles",{}).get(scope,0)
        if value!=int(value) or not 0<=value<count: raise ValueError(f"Invalid {scope} index.")

def prepare(case, folder=None):
    case = config_api.upgrade(case)
    validate(case)
    engine_details = runtime_support.validate_engine(EXE, ROOT)
    if folder is None:
        stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
        folder = Path(case.get("storage_root",ROOT/"runs")) / (stamp + "_" + uuid.uuid4().hex[:6])
    folder = Path(folder).resolve()
    folder.mkdir(parents=True, exist_ok=False)
    (folder / "settings.json").write_text(json.dumps(case, indent=2) + "\n", encoding="utf-8")
    cli_case = copy.deepcopy(case)
    if case["known_accel_calibration"]:
        bias = case["accel"]["bias"] if case["noise"] else [0, 0, 0]
        offsets = [int(math.copysign(math.floor(abs(-x * case["plant"]["g"] * 256 / 9.80665) + .5), -x)) for x in bias]
        set_fw(cli_case, "acc_calibration", ",".join(map(str, offsets + [1])))
    cli = re.sub(r"(?m)^\s*(?:save|exit|dump all)\s*$", "", cli_case["firmware_cli"])
    profile_text="\n".join(f"{scope} {int(value)}" for scope,value in case["profiles"].items())
    (folder / "configuration.cli").write_text(cli + "\n"+profile_text+"\ndump all\nsave\n", encoding="ascii")
    p = config_api.derived(case)
    (folder/"derived.json").write_text(json.dumps(p,indent=2)+"\n",encoding="utf-8")
    config = {k: case[k] for k in ("duration", "realtime", "warmup", "arm_settle", "spoolup", "log_hz", "reference_time", "seed", "noise", "plant_hz")}
    config["mode"] = {"angle":16,"rate":32,"receiver":0}[case["command_mode"]]
    timing=config_api.timing(case)
    config.update(firmware_hz=timing["gyro_hz"],firmware_accel_hz=timing["accel_hz"],synchronized_clock=int(timing["synchronized"]))
    config.update(linear=int(case["fidelity"]=="low"),gyro_hz=case["gyro"]["sample_rate"],accel_hz=case["accel"]["sample_rate"],
                  rc_hz=case["rc_hz"],pid_divider=int(fw_value(case,"pid_process_denom")),motor_order=case["motor_order"])
    for key in ("initial", "reference"):
        config[key] = [x if i < 6 else math.radians(x) for i, x in enumerate(case[key])]
    channels=config_api.receiver_channels(case)
    for key in ("rc_flight","rc_armed","rc_disarmed"): config[key]=channels[key]
    for key in ("m","g","S","rho","C11","C21","inertia","Ax","Ay","Az","Aomega","CDx","CDy","CDz","CDw","tau_wing","Xu","Yv","Zw"):
        config[{"m": "mass", "g": "gravity", "S": "arm_length"}.get(key, key)] = p[key]
    import numpy as np
    config["linear_A"]=np.asarray(p["A"]).ravel(order="F").tolist()
    config["linear_B"]=np.asarray(p["B"]).ravel(order="F").tolist()
    for sensor in ("gyro", "accel"):
        for key in ("density","bandwidth","bias","vibration","range"): config[f"{sensor}_{key}"] = case[sensor][key]
    lines = []
    for key, value in config.items():
        values = value if isinstance(value, list) else [value]
        lines.append(key + " " + " ".join(format(float(x), ".17g") for x in values))
    for row in case["schedule"]: lines.append("command "+" ".join(format(x,".17g") for x in [row[0]]+[math.radians(x) for x in row[1:]]))
    (folder / "case.txt").write_text("\n".join(lines) + "\n", encoding="ascii")
    metadata = {**engine_details, "engine_sha256": hashlib.sha256(EXE.read_bytes()).hexdigest(),
                "firmware_commit": case["firmware_commit"], "created": dt.datetime.now(dt.timezone.utc).isoformat(),
                "angular_settings_units": "degrees and degrees/s", "logged_angular_units": "radians and radians/s",
                "model": "hover_linear_sil" if case["fidelity"]=="low" else "hover_plant_sil", "source_model": "lin_hover_sim", "solver": "ode5", "maximum_step_s": 1/case["plant_hz"],
                "rate_estimate_source": "gyro.gyroADCf: processed rate feedback; Mahony has no separate angular-rate state",
                "filtered_imu_source": "exact gx/gy/gz and ax/ay/az arguments to imuMahonyAHRSupdate, held between estimator updates",
                "fixture_noise": "Box-Muller with deterministic LCG; free-flight noise is generated Simulink code",
                "firmware_timing":timing,"timing_scope":"Ideal sensor clock and native task scheduling; CPU execution time, bus latency and hardware jitter are not modeled"}
    (folder / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return folder

def environment(folder, trace=False):
    env = os.environ.copy()
    env["PATH"] = str(EXE.parent) + os.pathsep + env.get("PATH", "")
    env["BF_DESKTOP_CASE"] = "case.txt"
    settings=config_api.upgrade(json.loads((Path(folder)/"settings.json").read_text())) if (Path(folder)/"settings.json").exists() else None
    timing=config_api.timing(settings) if settings else {"gyro_hz":4000,"accel_hz":4000,"synchronized":False}
    env["BF_DESKTOP_GYRO_HZ"]=str(int(timing["gyro_hz"]))
    env["BF_DESKTOP_ACCEL_HZ"]=str(int(timing["accel_hz"]))
    env["BF_DESKTOP_SYNC"]="1" if timing["synchronized"] else "0"
    if trace: env["BF_DESKTOP_TRACE"] = "1"
    else: env.pop("BF_DESKTOP_TRACE", None)
    return env

def configure(folder):
    with (folder / "configuration.log").open("w", encoding="utf-8") as log:
        result = subprocess.run([str(EXE), "--config", "configuration.cli"], cwd=folder, env=environment(folder),
                                stdout=log, stderr=subprocess.STDOUT, timeout=45, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    text = (folder / "configuration.log").read_text(errors="replace")
    if result.returncode or "###ERROR" in text or "prepareSave failed" in text:
        errors = "\n".join(x for x in text.splitlines() if "ERROR" in x or "failed" in x)
        raise RuntimeError("Betaflight rejected the configuration: " + errors + "\n" + str(folder / "configuration.log"))

def execute(case, folder=None, progress=None, trace=False):
    import time
    application_start=time.perf_counter()
    folder = prepare(case, folder)
    if progress: progress("folder", folder)
    configure(folder)
    with (folder / "engine.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([str(EXE)], cwd=folder, env=environment(folder, trace), stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            if progress: progress("process", process)
            for line in process.stdout:
                log.write(line); log.flush()
                if line.startswith("[DESKTOP]"):
                    if progress: progress("status", line.strip())
                    else: print(line.strip(), flush=True)
            code = process.wait()
            if progress: progress("status","[DESKTOP] Archiving full-resolution signals…")
            import storage
            storage.finalize(folder)
            metadata=storage.read_json(folder/"metadata.json")
            metadata.update(application_wall_seconds=time.perf_counter()-application_start,
                            status="failed" if code else ("complete" if storage.read_json(folder/"engine_summary.json").get("completed") else "stopped"))
            (folder/"metadata.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")
            if code: raise RuntimeError(f"Native engine exited with code {code}. See {folder / 'engine.log'}")
        finally:
            if process.poll() is None: process.terminate(); process.wait(timeout=5)
    return folder

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", nargs="?", default=str(ROOT / "presets/noisy_hover.json"))
    parser.add_argument("--duration", type=float)
    parser.add_argument("--output")
    parser.add_argument("--trace", action="store_true")
    args = parser.parse_args()
    case = load_case(args.case)
    if args.duration is not None: case["duration"] = args.duration
    print(execute(case, args.output, trace=args.trace))
