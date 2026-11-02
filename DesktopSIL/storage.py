"""Settings/data-only archives and independent time-series import/export."""
from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace
import json
import re
import h5py
import numpy as np
from scipy.io import savemat
import configuration

@dataclass
class Signal:
    key: str
    time: np.ndarray
    values: np.ndarray
    unit: str=""
    group: str="Other"
    label: str=""

class Record:
    def __init__(self,folder,settings,metadata=None,variables=None):
        self.folder=Path(folder); self.settings=settings; self.metadata=metadata or {}; self.variables=variables or {}; self.signals={}
    def add(self,key,time,values,unit="",group="Other",label=""):
        self.signals[key]=Signal(key,np.asarray(time).reshape(-1),np.asarray(values).reshape(-1),unit,group,label or key)
    @property
    def dtype(self): return SimpleNamespace(names=("time_s",)+tuple(self.signals))
    def __getitem__(self,key):
        if key=="time_s": return next(iter(self.signals.values())).time
        return self.signals[key].values
    def series(self,key,degrees=True):
        s=self.signals.get(key)
        if s is None: return None
        values=s.values; unit=s.unit
        if degrees and unit in ("rad","rad/s"): values=np.rad2deg(values); unit="deg" if unit=="rad" else "deg/s"
        label=s.label
        if label in (key,key.replace("_"," ")):
            label=re.sub(r"_(?:radps|rad|mps2|mps|m|pot|us)$","",key).replace("_"," ")
        return f"{label} ({unit})" if unit else label,s.time,values

def infer_unit(name):
    for suffix,unit in (("_radps","rad/s"),("_rad","rad"),("_mps2","m/s²"),("_mps","m/s"),("_m","m"),("_pot","pot"),("_us","µs")):
        if name.endswith(suffix): return unit
    return "native PID" if any(x in name for x in ("_P","_I","_D","_F","_sum")) else ""

def infer_group(name):
    if name.startswith(("raw_","ideal_")): return "Raw / ideal IMU"
    if name.startswith("reference_"): return "Requested commands"
    if name.startswith("estimate_"): return "Estimated state"
    if name.startswith("filtered_"): return "Filtered gyro"
    if name.startswith(("motor","actuator","control")): return "Controls"
    if name.startswith(("error_","gyro_error")): return "Measurement / estimation errors"
    if any(x in name for x in ("_P","_I","_D","_F","_sum")): return "Native PID contributions"
    if name.startswith(("altitude","inertial")): return "Derived motion"
    return "Plant / firmware"

def augment(record):
    s=record.signals
    # Older archives called the rate-controller feedback "filtered". It is
    # distinct from the additional downsampled gyro consumed by Mahony.
    for axis in "pqr":
        old=f"filtered_{axis}_radps"; new=f"estimate_{axis}_radps"
        if old in s:
            previous=s.pop(old)
            if new not in s: record.add(new,previous.time,previous.values,"rad/s","Estimated state",f"Estimated body rate {axis} — firmware processed gyro")
    for key,signal in s.items():
        if key.startswith("filtered_input_"):
            signal.group="Filtered IMU (Mahony input)"
            signal.label="Filtered "+key.removeprefix("filtered_input_").removesuffix("_radps").removesuffix("_mps2").replace("_"," ")+" into Mahony"
        elif key.startswith("mahony_"):
            signal.group="Mahony internals (diagnostic)"
        elif key.startswith("error_"):
            signal.group="Estimation errors (True − Estimated)"
        elif key.startswith("gyro_error_"):
            signal.group="Sensor errors (Raw − Ideal)"
    def add(key,time,values,unit,group):
        if key not in s: record.add(key,time,values,unit,group)
    if "z_m" in s:
        z=s["z_m"]; add("altitude_m",z.time,-z.values,"m","Derived motion")
    if all(k in s for k in ("u_mps","v_mps","w_mps","roll_rad","pitch_rad","yaw_rad")):
        t=s["u_mps"].time
        vals=[np.interp(t,s[k].time,s[k].values) for k in ("u_mps","v_mps","w_mps","roll_rad","pitch_rad","yaw_rad")]
        u,v,w,phi,theta,psi=vals
        if record.settings.get("fidelity","high")=="low": vx,vy,vz=u,v,w
        else:
            sp,cp,st,ct,ss,cs=np.sin(phi),np.cos(phi),np.sin(theta),np.cos(theta),np.sin(psi),np.cos(psi)
            vx=ct*cs*u+(sp*st*cs-cp*ss)*v+(cp*st*cs+sp*ss)*w
            vy=ct*ss*u+(sp*st*ss+cp*cs)*v+(cp*st*ss-sp*cs)*w
            vz=-st*u+sp*ct*v+cp*ct*w
        for key,y in (("altitude_rate_mps",-vz),("inertial_vx_mps",vx),("inertial_vy_mps",vy),("inertial_vz_mps",vz)): add(key,t,y,"m/s","Derived motion")
    for true,estimate in (("roll_rad","estimate_roll_rad"),("pitch_rad","estimate_pitch_rad"),("yaw_rad","estimate_yaw_rad"),("p_radps","estimate_p_radps"),("q_radps","estimate_q_radps"),("r_radps","estimate_r_radps")):
        if true in s and estimate in s:
            a,b=s[true],s[estimate]; d=np.interp(b.time,a.time,a.values)-b.values
            if true.endswith("_rad"): d=np.arctan2(np.sin(d),np.cos(d))
            record.add("error_"+true,b.time,d,a.unit,"Estimation errors (True − Estimated)","True − Estimated "+true.split("_")[0])
    for axis in "xyz":
        raw=s.get(f"raw_gyro_{axis}_radps"); ideal=s.get(f"ideal_gyro_{axis}_radps")
        if raw and ideal:
            ix=np.clip(np.searchsorted(ideal.time,raw.time,side="right")-1,0,len(ideal.time)-1)
            add(f"gyro_error_{axis}_radps",raw.time,raw.values-ideal.values[ix],"rad/s","Sensor errors (Raw − Ideal)")
        acc=s.get(f"raw_accel_{axis}_mps2")
        if acc: add(f"raw_accel_{axis}_g",acc.time,acc.values/record.settings.get("plant",{}).get("g",9.81),"g","Raw / ideal IMU")
    trim=record.variables.get("u0",record.variables.get("trim_pot"))
    for i in range(1,5):
        motor=s.get(f"motor{i}_pot")
        if motor and trim is not None: add(f"control_delta{i}_pot",motor.time,motor.values-trim,"pot","Controls")
    return record

def read_json(path,default=None):
    return json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else (default or {})

def load_native(folder,preview=False):
    folder=Path(folder); settings=configuration.upgrade(read_json(folder/"settings.json"))
    record=Record(folder,settings,read_json(folder/"metadata.json"),read_json(folder/"derived.json"))
    if (folder/"signals.h5").exists():
        with h5py.File(folder/"signals.h5","r") as f:
            times={}
            for key,node in f["signals"].items():
                time_id=node.attrs["time_id"]
                if time_id not in times: times[time_id]=f["time"][time_id][()]
                record.add(node.attrs["key"],times[time_id],node["values"][()],node.attrs["unit"],node.attrs["group"],node.attrs["label"])
        return augment(record)
    if (folder/"signals.bin").exists():
        names=(folder/"signals.header").read_text().strip().split(",")
        width=len(names); raw=np.fromfile(folder/"signals.bin",dtype="<f8"); data=raw[:len(raw)//width*width].reshape(-1,width)
    else:
        import io
        blob=(folder/"signals.csv").read_bytes(); blob=blob[:blob.rfind(b"\n")+1]
        names=blob.split(b"\n",1)[0].decode().strip().split(",")
        data=np.loadtxt(io.BytesIO(blob),delimiter=",",skiprows=1,ndmin=2)
    if len(data)<1: raise ValueError("No flight samples are available yet.")
    t=data[:,0]
    for i,name in enumerate(names[1:],1): record.add(name,t,data[:,i],infer_unit(name),infer_group(name),name.replace("_"," "))
    return augment(record)

def finalize(folder):
    folder=Path(folder)
    if not (folder/"signals.bin").exists() and not (folder/"signals.csv").exists(): return
    record=load_native(folder); pending=folder/"signals.pending.h5"
    with h5py.File(pending,"w") as f:
        f.attrs["format"]="DesktopSILSignals"; f.attrs["version"]=1
        tg=f.create_group("time"); sg=f.create_group("signals"); known={}
        for i,s in enumerate(record.signals.values()):
            identity=(s.time.__array_interface__["data"][0],len(s.time))
            if identity not in known:
                key=f"t{len(known)}"; tg.create_dataset(key,data=s.time,compression="gzip",compression_opts=1,shuffle=True); known[identity]=key
            node=sg.create_group(f"s{i:04d}"); node.attrs.update(key=s.key,unit=s.unit,group=s.group,label=s.label,time_id=known[identity])
            node.create_dataset("values",data=s.values,compression="gzip",compression_opts=1,shuffle=True)
        f.flush()
    pending.replace(folder/"signals.h5")
    # Only remove this run's transient uncompressed signal spool after the
    # complete HDF5 archive is closed and atomically installed.
    for name in ("signals.bin","signals.csv"): (folder/name).unlink(missing_ok=True)
    summary=read_json(folder/"engine_summary.json")
    metadata=read_json(folder/"metadata.json"); metadata.update(status="complete" if summary.get("completed") else ("stopped" if summary.get("stopped") else "failed"),signal_count=len(record.signals))
    (folder/"metadata.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")

def matlab_value(file,node):
    if isinstance(node,h5py.Group): return {k:matlab_value(file,v) for k,v in node.items()}
    data=node[()]; cls=node.attrs.get("MATLAB_class",b"")
    if cls==b"char": return "".join(chr(int(x)) for x in data.ravel())
    if h5py.check_dtype(ref=node.dtype):
        values=[matlab_value(file,file[ref]) if ref else None for ref in data.ravel()]
        return values[0] if data.size==1 else values
    if data.size==1: return data.item()
    return data.T.tolist()

def load_matlab(folder):
    folder=Path(folder); payload=read_json(folder/"settings.json")
    settings=configuration.upgrade(payload)
    with h5py.File(folder/"run.mat","r") as f:
        root=f["record"]; metadata=matlab_value(f,root["Metadata"])
        variables={}
        for key in ("u0","sim_fidelity"):
            if key in root["Variables"]: variables[key]=matlab_value(f,root["Variables"][key])
        record=Record(folder,settings,metadata,variables); source=root["Signals"]
        fields={k:v[()].ravel() for k,v in source.items()}
        for i in range(len(fields["Key"])):
            item={k:matlab_value(f,f[refs[i]]) for k,refs in fields.items()}
            record.add(item["Key"],item["Time"],item["Data"],item["Unit"],item["Group"],item["Name"])
    # Add canonical aliases for native analysis while retaining every original
    # key and its independent time grid in the signal browser.
    aliases={}
    for old,new in zip(("x","y","z","u","v","w","phi","theta","psi","p","q","r"),("x_m","y_m","z_m","u_mps","v_mps","w_mps","roll_rad","pitch_rad","yaw_rad","p_radps","q_radps","r_radps")):
        aliases["state."+old]=new
        if old in ("phi","theta","psi"): aliases["estimate."+old]="estimate_"+new
        if old in ("p","q","r"): aliases["estimate."+old]="estimate_"+new
        aliases["command."+old]="reference_"+new
    for axis,letter in zip(("roll","pitch","yaw"),"pqr"):
        aliases[f"betaflight.receiver_rate.{axis}"]=f"setpoint_{letter}_radps"
        for term in ("P","I","D","F","Sum"): aliases[f"betaflight.pid.{axis}.{term}"]=f"{axis}_{'PID_sum' if term=='Sum' else term}"
    for i in range(1,5): aliases[f"betaflight.motor{i}"]=f"motor{i}_pot"
    for sensor,unit in (("gyro","radps"),("accel","mps2")):
        for kind,target in (("measured","raw"),("ideal","ideal")):
            for i,axis in enumerate("xyz",1): aliases[f"logged.logsout.imu_{sensor}_{kind}.{i}"]=f"{target}_{sensor}_{axis}_{unit}"
    for old,new in aliases.items():
        if old in record.signals:
            s=record.signals[old]; values=s.values
            if old.startswith("command.") and s.unit in ("deg","deg/s"): values=np.deg2rad(values)
            record.add(new,s.time,values,infer_unit(new),infer_group(new),new.replace("_"," "))
    return augment(record)

def load_run(folder,preview=False):
    folder=Path(folder)
    return load_matlab(folder) if (folder/"run.mat").exists() and not (folder/"signals.h5").exists() else load_native(folder,preview)

def export_csv(record,keys,folder):
    folder=Path(folder); folder.mkdir(parents=True,exist_ok=True)
    outputs=[]
    for key in keys:
        s=record.signals[key]; name=re.sub(r"[^A-Za-z0-9_.-]","_",key)+".csv"; path=folder/name
        np.savetxt(path,np.column_stack((s.time,s.values)),delimiter=",",header=f"time_s,{key} [{s.unit}]",comments="",fmt="%.17g"); outputs.append(path)
    return outputs

def export_mat(record,keys,path):
    signals={}; original={}
    for i,key in enumerate(keys):
        s=record.signals[key]; safe=re.sub(r"\W","_",key)
        if not safe or not safe[0].isalpha(): safe="signal_"+safe
        safe=safe[:55]+f"_{i}"
        signals[safe]={"Time":s.time.reshape(-1,1),"Data":s.values.reshape(-1,1),"Unit":s.unit,"Name":key}
        original[safe]=key
    savemat(path,{"hoverSignals":signals,"hoverRun":{"SettingsJSON":json.dumps(record.settings),"MetadataJSON":json.dumps(record.metadata),"SourceFolder":str(record.folder)},"signalNames":original},long_field_names=True,do_compression=True)
    helper=Path(path).with_suffix(".m"); filename=Path(path).name.replace("'","''")
    helper.write_text("% Load full-resolution signals into the MATLAB workspace.\n"+f"load(fullfile(fileparts(mfilename('fullpath')),'{filename}'));\n"+"keys=fieldnames(hoverSignals);\nfor k=1:numel(keys)\n    s=hoverSignals.(keys{k});\n    ts=timeseries(s.Data,s.Time,'Name',s.Name);\n    ts.DataInfo.Units=s.Unit;\n    hoverSignals.(keys{k})=ts;\nend\n",encoding="utf-8")
    return helper
