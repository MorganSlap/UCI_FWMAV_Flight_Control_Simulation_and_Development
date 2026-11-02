"""End-to-end native SIL acceptance checks, including original-host replay."""
from pathlib import Path
import json
import os
import shutil
import socket
import subprocess
import sys
import time
import uuid
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import runner
import storage
import configuration as cfg
from plots import extrema_indices

def run_case(name, duration=10, **changes):
    case=runner.load_case(runner.ROOT/"presets"/name)
    case["duration"]=duration; case.update(changes)
    folder=runner.execute(case,progress=lambda *args:None)
    data=storage.load_run(folder)
    assert all(np.isfinite(data[key]).all() for key in data.dtype.names)
    assert np.all(data["armed"]==1)
    summary=json.loads((folder/"engine_summary.json").read_text())
    assert summary["completed"]
    return folder,data,summary

def exact_firmware_replay(folder):
    """Replay identical IMU/RC requests through the existing TCP host binary."""
    trace=np.fromfile(folder/"firmware_trace.bin",dtype="<f8").reshape(-1,92)
    target=runner.ROOT/"runs"/("replay_"+uuid.uuid4().hex[:8]); target.mkdir()
    shutil.copy2(folder/"configuration.cli",target/"configuration.cli")
    exe=runner.ROOT.parent/"Betaflight/build/betaflight_simulink.exe"
    env=runner.environment(target); env.pop("BF_DESKTOP_CASE",None)
    hidden=getattr(subprocess,"CREATE_NO_WINDOW",0)
    with (target/"firmware.log").open("w") as log:
        configured=subprocess.run([str(exe),"--config","configuration.cli"],cwd=target,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=hidden,timeout=45)
        assert configured.returncode==0
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1",0)); port=reservation.getsockname()[1]
        process=subprocess.Popen([str(exe),"--host-port",str(port)],cwd=target,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=hidden)
        start=time.monotonic(); sock=None
        try:
            while sock is None:
                try: sock=socket.create_connection(("127.0.0.1",port),timeout=1)
                except OSError:
                    if time.monotonic()-start>15: raise
                    time.sleep(.05)
            sock.settimeout(5); sock.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
            for k,row in enumerate(trace):
                sock.sendall(row[:52].tobytes()); packet=bytearray()
                while len(packet)<320:
                    block=sock.recv(320-len(packet))
                    if not block: raise RuntimeError("Firmware connection closed")
                    packet.extend(block)
                actual=np.frombuffer(packet,dtype="<f8")
                assert np.array_equal(actual,row[52:]), f"Firmware mismatch at exchange {k}: {np.flatnonzero(actual!=row[52:])}"
        finally:
            if sock: sock.close()
            if process.poll() is None: process.terminate(); process.wait(timeout=10)
    return {"exchanges":len(trace),"response_words_per_exchange":40,"exactly_equal":True,"wall_seconds":time.monotonic()-start}

def pause_stop():
    case=runner.load_case(runner.ROOT/"presets/noisy_hover.json"); case.update(duration=4,realtime=True)
    folder=runner.prepare(case); runner.configure(folder)
    with (folder/"engine.log").open("w") as log:
        process=subprocess.Popen([str(runner.EXE)],cwd=folder,env=runner.environment(folder),stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
        try:
            start=time.monotonic()
            while "TIME 0.3000" not in (folder/"engine.log").read_text():
                if time.monotonic()-start>15: raise TimeoutError("No native flight progress")
                time.sleep(.03)
            (folder/"pause").touch(); time.sleep(.1)
            frozen=(folder/"signals.bin").stat().st_size; time.sleep(.3)
            assert (folder/"signals.bin").stat().st_size==frozen, "Flight advanced while paused"
            (folder/"pause").unlink(); time.sleep(.3); (folder/"stop").touch()
            assert process.wait(timeout=5)==0
            summary=json.loads((folder/"engine_summary.json").read_text())
            assert summary["stopped"] and not summary["completed"] and summary["simulation_seconds"]<2
        finally:
            if process.poll() is None: process.terminate(); process.wait(timeout=5)
    return summary

def expanded_settings():
    report={}
    for name in ("angle","rate"):
        case=cfg.from_matlab(json.loads((runner.ROOT/f"catalog/{name}_settings.json").read_text()))
        folder=runner.execute(case,progress=lambda *args:None); data=storage.load_run(folder)
        for row in case["schedule"]:
            ix=np.searchsorted(data["time_s"],row[0]+.01)
            for axis,key in enumerate(("roll_rad","pitch_rad","r_radps") if name=="angle" else ("p_radps","q_radps","r_radps")):
                assert abs(np.rad2deg(data["reference_"+key][ix])-row[axis+1])<1e-10
        report[name+"_sequence"]={"rows":len(case["schedule"]),"folder":str(folder),"passed":True}
    case=runner.load_case(runner.ROOT/"presets/noisy_hover.json"); case.update(duration=1,fidelity="low",rc_hz=200)
    case["profiles"].update(profile=1,rateprofile=2,battery_profile=1)
    cfg.set_firmware(case,"angle_p_gain",24); cfg.set_firmware(case,"pid_process_denom",4)
    case["gyro"]["sample_rate"]=3000; case["accel"]["sample_rate"]=1000
    folder=runner.execute(case,progress=lambda *args:None); data=storage.load_run(folder)
    assert np.all(data["pid_period_us"]==1000)
    summary=storage.read_json(folder/"engine_summary.json"); assert summary["linear"]
    assert summary["gyro_hz"]==3000 and summary["accel_hz"]==1000
    assert cfg.firmware_value(storage.load_run(folder).settings,"angle_p_gain")=="24"
    report["profiles_linear_rates"]={**summary,"profiles":case["profiles"]}
    case=runner.load_case(runner.ROOT/"presets/noisy_hover.json"); case.update(duration=1,command_mode="receiver")
    case["firmware_cli"]+="\nmap TAER1234\n"
    case["custom_receiver"]=False; channels=cfg.receiver_channels(case)
    case["receiver_flight"]=channels["rc_flight"]; case["receiver_disarmed"]=channels["rc_disarmed"]; case["custom_receiver"]=True
    folder=runner.execute(case,progress=lambda *args:None); data=storage.load_run(folder)
    assert np.all(data["armed"]==1) and np.all(np.isfinite(data["roll_rad"]))
    report["raw_receiver_custom_map"]={"map":"TAER1234","throttle_channel":channels["throttle_index"]+1,"passed":True}
    case.update(warmup=60)
    folder=runner.execute(case,progress=lambda kind,value:(value/"stop").touch() if kind=="folder" else None)
    assert storage.read_json(folder/"engine_summary.json")["phase"]=="startup"
    assert not (folder/"signals.h5").exists()
    report["stop_during_calibration"]={"clean_exit":True}
    return report

def main():
    report={}
    first,d,summary=run_case("noisy_hover.json",60)
    report["hover_60_seconds"]={**summary,"max_roll_pitch_deg":max(float(np.abs(np.rad2deg(d[k])).max()) for k in ("roll_rad","pitch_rad")),"final_z_m":float(d["z_m"][-1])}
    assert report["hover_60_seconds"]["max_roll_pitch_deg"]<10
    report["hover_60_seconds"].update(samples=len(d["time_s"]),archive_bytes=(first/"signals.h5").stat().st_size,folder=str(first))
    del d
    recovery,r,summary=run_case("noisy_recovery.json",20)
    report["recovery"]={**summary,"initial_roll_pitch_deg":[float(np.rad2deg(r[k][0])) for k in ("roll_rad","pitch_rad")],"final_roll_pitch_deg":[float(np.rad2deg(r[k][-1])) for k in ("roll_rad","pitch_rad")]}
    assert np.allclose(report["recovery"]["initial_roll_pitch_deg"],[5,-3])
    assert np.max(np.abs(report["recovery"]["final_roll_pitch_deg"]))<3
    del r
    a,da,_=run_case("noisy_hover.json",1)
    b,db,_=run_case("noisy_hover.json",1)
    assert all(np.array_equal(da[key],db[key]) for key in da.dtype.names)
    report["repeatability"]={"identical_samples":True,"samples":len(da["time_s"])}
    quiet,dq,_=run_case("noisy_hover.json",5,noise=False)
    assert np.max(np.abs(dq["roll_rad"]))<1e-8 and np.max(np.abs(dq["pitch_rad"]))<1e-8
    report["noise_toggle"]={"quiet_max_roll_rad":float(np.max(np.abs(dq["roll_rad"]))),"noisy_raw_gyro_std_deg_s":float(np.std(np.rad2deg(da["raw_gyro_x_radps"])))}
    c=runner.load_case(runner.ROOT/"presets/noisy_hover.json"); c["duration"]=.5
    runner.set_fw(c,"angle_p_gain","25"); c["initial"][6]=2; c["drag"]=False
    changed=runner.execute(c,progress=lambda *args:None)
    assert "set angle_p_gain = 25" in (changed/"configuration.log").read_text()
    text=(changed/"case.txt").read_text()
    for key in ("CDx","CDy","CDz","CDw"): assert f"{key} 0\n" in text
    data=storage.load_run(changed)
    assert abs(np.rad2deg(data["roll_rad"][0])-2)<1e-12
    report["runtime_settings"]={"angle_p_verified_in_native_dump":25,"initial_roll_deg":2,"all_drag_coefficients_zero":True}
    report["pause_resume_stop"]=pause_stop()
    report["expanded_configuration"]=expanded_settings()
    c=runner.load_case(runner.ROOT/"presets/noisy_hover.json"); c["duration"]=1
    traced=runner.execute(c,progress=lambda *args:None,trace=True)
    report["original_firmware_replay"]=exact_firmware_replay(traced)
    y=np.zeros(10000); y[1234]=100; y[5678]=-70; keep=extrema_indices(y,400)
    assert 1234 in keep and 5678 in keep and 0 in keep and 9999 in keep
    report["plot_decimation"]={"extrema_preserved":True}
    report["passed"]=True
    (runner.ROOT/"verification/native_acceptance.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))

if __name__=="__main__": main()
