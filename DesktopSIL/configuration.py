"""Shared settings, native CLI scopes, receiver layout and plant derivation."""
from pathlib import Path
import copy
import json
import math
import re
import numpy as np

ROOT=Path(__file__).resolve().parent
SCHEMA=json.loads((ROOT/"catalog/firmware_schema.json").read_text())
BY_NAME={item["Name"]:item for item in SCHEMA}

def selected_profiles(cli):
    selected={"profile":0,"rateprofile":0,"battery_profile":0}
    for line in cli.splitlines():
        match=re.fullmatch(r"\s*(profile|rateprofile|battery_profile)\s+(\d+)\s*",line)
        if match: selected[match[1]]=int(match[2])
    return selected

def firmware_value(case,name,index=None):
    item=BY_NAME.get(name,{"Scope":"master","Default":""}); scope=item["Scope"]
    if index is None: index=case.get("profiles",selected_profiles(case["firmware_cli"])).get(scope,0)
    current={"profile":0,"rateprofile":0,"battery_profile":0}; value=str(item["Default"])
    for line in case["firmware_cli"].splitlines():
        m=re.fullmatch(r"\s*(profile|rateprofile|battery_profile)\s+(\d+)\s*",line)
        if m: current[m[1]]=int(m[2])
        m=re.fullmatch(r"\s*set\s+"+re.escape(name)+r"\s*=\s*(.*?)\s*",line)
        if m and (scope=="master" or current[scope]==index): value=m[1]
    return value

def validate_firmware_value(name,value):
    if name not in BY_NAME: raise ValueError(f"Unknown firmware setting: {name}")
    item=BY_NAME[name]; text=str(value).strip(); kind=item["Type"]
    if "\n" in text or "\r" in text: raise ValueError("A setting value must be one line.")
    if kind=="integer":
        x=float(text)
        if not math.isfinite(x) or x!=int(x) or not item["Minimum"]<=x<=item["Maximum"]: raise ValueError(f"{name}: {item['Constraint']}")
        text=str(int(x))
    elif kind=="choice" and text not in item["Choices"]: raise ValueError(f"{name}: {item['Constraint']}")
    elif kind=="array":
        parts=text.split(",")
        if len(parts)!=item["ArrayLength"] or any(not math.isfinite(float(v)) for v in parts): raise ValueError(f"{name}: {item['Constraint']}")
    elif kind=="text" and item["LengthMaximum"] is not None:
        if not item["LengthMinimum"]<=len(text)<=item["LengthMaximum"]: raise ValueError(f"{name}: {item['Constraint']}")
    return text

def set_firmware(case,name,value,index=None):
    value=validate_firmware_value(name,value); scope=BY_NAME[name]["Scope"]
    profiles=case.get("profiles",selected_profiles(case["firmware_cli"]))
    if index is None: index=profiles.get(scope,0)
    current={"profile":0,"rateprofile":0,"battery_profile":0}; lines=[]; found=False
    for line in case["firmware_cli"].splitlines():
        m=re.fullmatch(r"\s*(profile|rateprofile|battery_profile)\s+(\d+)\s*",line)
        if m: current[m[1]]=int(m[2])
        if re.match(r"\s*set\s+"+re.escape(name)+r"\s*=",line) and (scope=="master" or current[scope]==index):
            line=f"set {name} = {value}"; found=True
        lines.append(line)
    if not found:
        if scope!="master": lines.append(f"{scope} {index}")
        lines.append(f"set {name} = {value}")
        if scope!="master": lines.append(f"{scope} {profiles.get(scope,0)}")
    case["firmware_cli"]="\n".join(lines)+"\n"

def upgrade(case):
    case=copy.deepcopy(case)
    if case.get("Format")=="HoverWorkbenchSettings": return from_matlab(case["Settings"],case.get("Options",{}))
    if "sim_fidelity" in case and "Betaflight" in case: return from_matlab(case)
    defaults={"fidelity":"high","notes":"","default_plots":True,"schedule":[],"rc_hz":100,"plant_hz":16000,
              "profiles":selected_profiles(case["firmware_cli"]),"custom_receiver":False,"motor_order":[1,2,3,4]}
    for key,value in defaults.items(): case.setdefault(key,value)
    for sensor,hz,rng in (("gyro",3200,1000),("accel",1600,4)):
        case[sensor].setdefault("sample_rate",hz); case[sensor].setdefault("range",rng); case[sensor].setdefault("resolution_bits",16)
    p=case["plant"]
    for key,value in {"wing_type":15,"AxFactor":.5,"AyFactor":.5,"AzFactor":.35,"AomegaFactor":1,"v_ref":.5,"w_ref":.5,
                      "p_ref":180/math.pi,"q_ref":180/math.pi,"r_ref":180/math.pi,"k_tau":0,"area_mode":"direct"}.items(): p.setdefault(key,value)
    p.setdefault("tensor",np.diag(p["inertia"]).tolist())
    return case

def from_matlab(settings,options=None):
    options=options or {}; original=copy.deepcopy(settings)
    s=json.loads((ROOT/"catalog/script_defaults.json").read_text())
    for key,value in original.items():
        if isinstance(value,dict) and isinstance(s.get(key),dict): s[key].update(value)
        else: s[key]=value
    case=json.loads((ROOT/"presets/noisy_hover.json").read_text())
    case.update(name=options.get("RunLabel","Imported MATLAB settings"),duration=s["t_sim"],fidelity=s["sim_fidelity"],
                noise=bool(s["noise_true"]),drag=bool(s.get("drag_enabled",True)),seed=s["seed"],
                initial=[float(x) if i<6 else math.degrees(x) for i,x in enumerate(np.asarray(s["X0"]).ravel())],
                reference=[float(x) if i<6 else math.degrees(x) for i,x in enumerate(np.asarray(s["Xref"]).ravel())],
                firmware_cli=s["Betaflight"]["CLI"],default_plots=options.get("DefaultPlots",True),reference_time=0)
    case["profiles"]=selected_profiles(case["firmware_cli"])
    for k in ("m","g","S","rho","C11","C21","CDx","CDy","CDz","CDw","tau_wing","wing_type","AxFactor","AyFactor","AzFactor","AomegaFactor","v_ref","w_ref","k_tau"):
        case["plant"][k]=s[k]
    for key in ("p_ref","q_ref","r_ref"): case["plant"][key]=math.degrees(s[key])
    case["plant"]["tensor"]=s["I"]; case["plant"]["inertia"]=np.diag(s["I"]).tolist(); case["plant"]["area_mode"]="wing factors"
    for sensor in ("gyro","accel"):
        for key,target in (("noise_density","density"),("BW","bandwidth"),("bias","bias"),("vibration","vibration"),("sample_rate","sample_rate"),("range","range"),("resolution_bits","resolution_bits")):
            case[sensor][target]=np.asarray(s[sensor][key]).ravel().tolist() if key=="bias" else s[sensor][key]
    adapter=s.get("FirmwareAdapter",{})
    for key,target in {"CommandMode":"command_mode","RcRateHz":"rc_hz","WarmupSeconds":"warmup","ArmSettleSeconds":"arm_settle","SpoolupSeconds":"spoolup","ThrottlePWM":"throttle","UseKnownAccelCalibration":"known_accel_calibration","MotorOrder":"motor_order"}.items():
        if key in adapter: case[target]=adapter[key]
    case["schedule"]=[[row[0]]+[math.degrees(x) for x in row[1:]] for row in adapter.get("ReferenceSchedule",[])]
    case["custom_receiver"]=bool(adapter.get("ReceiverPWM",[]))
    if case["custom_receiver"]: case["receiver_flight"]=adapter["ReceiverPWM"]
    if adapter.get("StartupReceiverPWM",[]): case["receiver_disarmed"]=adapter["StartupReceiverPWM"]
    case["matlab_settings"]=original
    case["legacy_controller"]="Betaflight" not in original
    case["known_accel_calibration"]=adapter.get("UseKnownAccelCalibration",False)
    if "ThrottlePWM" not in adapter:
        p=derived(upgrade(case)); low=float(firmware_value(case,"min_command"))+.1*float(firmware_value(case,"motor_idle"))
        maximum=float(firmware_value(case,"max_throttle")); minimum=float(firmware_value(case,"min_check"))
        case["throttle"]=minimum+(2000-minimum)*(p["u0"]-low)/(maximum-low)
    return upgrade(case)

def derived(case):
    p=copy.deepcopy(case["plant"]); p["inertia"]=np.diag(p["tensor"]).tolist()
    p["wing_area"]=math.pi*4*p["wing_type"]*.00064516; p["Aref"]=4*p["wing_area"]
    if p["area_mode"]=="wing factors":
        for key in ("Ax","Ay","Az","Aomega"): p[key]=p[key+"Factor"]*p["Aref"]
    if not case["drag"]:
        for key in ("CDx","CDy","CDz","CDw"): p[key]=0
    p["u0"]=(p["m"]*p["g"]/4-p["C21"])/p["C11"]
    p["Xu"]=p["rho"]*p["CDx"]*p["Ax"]*p["v_ref"]
    p["Yv"]=p["rho"]*p["CDy"]*p["Ay"]*p["v_ref"]
    p["Zw"]=p["rho"]*p["CDz"]*p["Az"]*p["w_ref"]
    for key,rate in (("Lp","p_ref"),("Mq","q_ref"),("Nr","r_ref")): p[key]=p["rho"]*p["CDw"]*p["Aomega"]*p["S"]**3*math.radians(p[rate])
    A=np.zeros((12,12)); B=np.zeros((12,4))
    for i in range(3): A[i,3+i]=1; A[6+i,9+i]=1
    A[3,3]=-p["Xu"]/p["m"]; A[3,7]=-p["g"]
    A[4,4]=-p["Yv"]/p["m"]; A[4,6]=p["g"]; A[5,5]=-p["Zw"]/p["m"]
    for i,key in enumerate(("Lp","Mq","Nr")): A[9+i,9+i]=-p[key]/p["inertia"][i]
    B[5,:]=-p["C11"]/p["m"]
    B[9,:]=p["S"]*p["C11"]/p["inertia"][0]*np.array([0,-1,0,1])
    B[10,:]=p["S"]*p["C11"]/p["inertia"][1]*np.array([1,0,-1,0])
    B[11,:]=p["k_tau"]/p["inertia"][2]*np.array([1,-1,1,-1])
    p["A"]=A.tolist(); p["B"]=B.tolist(); return p

def receiver_channels(case):
    mapping="AETR1234"; ranges=np.tile([1000.,2000.],(4,1)); modes={}
    for line in case["firmware_cli"].splitlines():
        parts=line.split()
        if not parts: continue
        if parts[0]=="defaults": mapping="AETR1234"; ranges[:]=[1000,2000]; modes={}
        if parts[0]=="map" and len(parts)==2: mapping=parts[1]
        if parts[:2]==["rxrange","reset"]: ranges[:]=[1000,2000]
        elif parts[0]=="rxrange" and len(parts)>=4: ranges[int(parts[1])]=[float(parts[2]),float(parts[3])]
        if parts[0]=="aux" and len(parts)>=6: modes[int(parts[1])]=list(map(int,parts[2:6]))
    if sorted(mapping)!=sorted("AETR1234"): raise ValueError("Receiver map must contain A, E, T, R and 1–4 exactly once.")
    throttle=mapping.index("T"); mid=float(firmware_value(case,"mid_rc")); flight=np.full(16,1000.)
    for i,letter in enumerate("AER"): flight[mapping.index(letter)]=ranges[i,0]+(mid-1000)*(ranges[i,1]-ranges[i,0])/1000
    flight[throttle]=case["throttle"]
    arm=None; angle=None
    for mode in (0,1):
        row=next((modes[k] for k in sorted(modes) if modes[k][0]==mode and modes[k][3]>modes[k][2]),None)
        if row is None: continue
        _,aux,low,high=row; channel=mapping.index(str(aux+1)) if aux<4 else 4+aux
        on=(low+high)/2; off=2000 if low<=1000<high else 1000
        if mode==0: arm=(channel,on,off); flight[channel]=on
        else: angle=(channel,on,off); flight[channel]=on if case["command_mode"]=="angle" else off
    if arm is None: raise ValueError("Configure an ARM AUX range for automatic startup.")
    if angle is None and case["command_mode"]=="angle": raise ValueError("Configure an ANGLE AUX range for angle commands.")
    if case["custom_receiver"]: flight=np.asarray(case["receiver_flight"],dtype=float)
    armed=flight.copy(); armed[throttle]=ranges[3,0]
    disarmed=armed.copy(); disarmed[arm[0]]=arm[2]
    if case["custom_receiver"]: disarmed=np.asarray(case["receiver_disarmed"],dtype=float)
    return {"rc_flight":flight.tolist(),"rc_armed":armed.tolist(),"rc_disarmed":disarmed.tolist(),
            "map":mapping,"throttle_index":throttle,"arm_index":arm[0],"angle_index":None if angle is None else angle[0]}
