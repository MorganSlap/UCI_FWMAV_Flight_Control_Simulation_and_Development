"""Reproducible experiment design and isolated native SIL batches.

No Tk calls are made here. The ordinary runner and run format are reused.
"""
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
from pathlib import Path
import copy
import csv
import datetime as dt
import hashlib
import json
import math
import os
import threading
import time
import uuid
import h5py
import numpy as np
from scipy import stats
from scipy.stats import qmc
import configuration as cfg
import runner
import storage
from analysis import rms

FORMAT='DesktopSILMonteCarlo'
SIGNAL_CATALOG=json.loads((cfg.ROOT/'catalog/native_signals.json').read_text())
DISTRIBUTIONS={'uniform':'A: minimum, B: maximum',
    'normal':'A: mean, B: standard deviation',
    'truncated normal':'A: mean, B: standard deviation, C: minimum, D: maximum',
    'log uniform':'A: positive minimum, B: positive maximum',
    'triangular':'A: minimum, B: most likely, C: maximum',
    'choices':'A: JSON list of equally likely values, e.g. [20, 30, 40]',
    'fixed':'A: value'}
MODES=('absolute','offset','percent change')
SIGNALS=['roll_rad','pitch_rad','yaw_rad','p_radps','q_radps','r_radps',
    'estimate_roll_rad','estimate_pitch_rad','error_roll_rad','error_pitch_rad',
    'x_m','y_m','altitude_m','u_mps','v_mps','w_mps',
    'raw_gyro_x_radps','raw_gyro_y_radps','raw_accel_x_g','raw_accel_y_g',
    'motor1_pot','motor2_pot','motor3_pot','motor4_pot']
METRICS={
    'peak_tilt_deg':'Peak tilt from vertical (deg)',
    'attitude_estimation_rms_deg':'Worst roll/pitch estimation RMS (deg)',
    'peak_attitude_error_deg':'Peak absolute roll/pitch estimation error (deg)',
    'angle_tracking_rms_deg':'Worst roll/pitch ANGLE tracking RMS (deg)',
    'rate_tracking_rms_dps':'Worst roll/pitch RATE tracking RMS (deg/s)',
    'peak_body_rate_dps':'Peak absolute body-rate component (deg/s)',
    'horizontal_drift_m':'Maximum horizontal displacement from release (m)',
    'vertical_drift_m':'Maximum vertical displacement from release (m)',
    'final_altitude_change_m':'Final altitude change from release (m, positive up)',
    'motor_rail_percent':'Time any motor is within 1 pot of a configured rail (%)',
    'settling_time_s':'Final-command settling time (s; unavailable if unsettled)',
    'final_roll_deg':'Final true roll (deg)', 'final_pitch_deg':'Final true pitch (deg)'}


def atomic_json(path,value):
    path=Path(path); pending=path.with_name(path.name+'.pending')
    pending.write_text(json.dumps(value,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    # Windows can briefly deny replacement while the GUI or another reader has
    # the prior manifest open. Keep the complete prior file and retry the swap.
    for attempt in range(21):
        try: pending.replace(path); break
        except PermissionError:
            if attempt==20: raise
            time.sleep(.05)


def get_parameter(case,path):
    if path.startswith('firmware.'):
        name=path.split('.',1)[1]; value=cfg.firmware_value(case,name)
        return int(value) if cfg.BY_NAME[name]['Type']=='integer' else value
    value=case
    for key in path.split('.'): value=value[int(key)] if isinstance(value,list) else value[key]
    return value


def parameter_label(path):
    labels={'plant.m':'Mass (kg)','plant.S':'Thrust arm (m)',
        'plant.tau_wing':'Actuator time constant (s)',
        'plant.tensor.0.0':'Roll inertia (kg m²)','plant.tensor.1.1':'Pitch inertia (kg m²)',
        'plant.tensor.2.2':'Yaw inertia (kg m²)', 'firmware.angle_p_gain':'ANGLE P gain'}
    if path in labels: return labels[path]
    fields=('x (m)','y (m)','z (m)','u (m/s)','v (m/s)','w (m/s)',
        'roll (deg)','pitch (deg)','yaw (deg)','p (deg/s)','q (deg/s)','r (deg/s)')
    if path.startswith(('initial.','reference.')):
        kind,index=path.split('.'); return ('Initial ' if kind=='initial' else 'Reference ')+fields[int(index)]
    if path.startswith('firmware.'):
        name=path.split('.',1)[1]; parts=name.split('_')
        if len(parts)==2 and parts[0] in ('p','i','d','f') and parts[1] in ('roll','pitch','yaw'):
            return parts[1].title()+' '+parts[0].upper()+' gain'
        return 'Firmware '+name.replace('_',' ')
    return path.replace('_',' ')


def parameter_catalog(case):
    """Only runtime inputs; omit derived aliases, notes, raw CLI, and seed policy."""
    result={}
    def walk(value,path):
        if isinstance(value,dict):
            for key,v in value.items():
                if key not in ('inertia','area_mode','resolution_bits'): walk(v,path+'.'+key)
        elif isinstance(value,list):
            for i,v in enumerate(value): walk(v,path+'.'+str(i))
        elif isinstance(value,(int,float,bool)):
            if path.startswith('plant.tensor.'):
                _,_,i,j=path.split('.')
                if int(i)!=int(j): return  # The current generated plant uses only diagonal inertia.
            result[path]={'value':value,'kind':'bool' if isinstance(value,bool) else 'number'}
    for key in ('plant','gyro','accel','initial','reference','schedule'): walk(case.get(key,[]),key)
    for key in ('duration','throttle','reference_time','warmup','arm_settle','spoolup','rc_hz','plant_hz','log_hz','noise','drag','known_accel_calibration'):
        walk(case[key],key)
    for key,choices in (('fidelity',('high','low')),('command_mode',('angle','rate','receiver'))):
        result[key]={'value':case[key],'kind':'choice','constraint':'Choices: '+', '.join(choices)}
    for name,item in cfg.BY_NAME.items():
        if item['Type'] in ('integer','choice'):
            result['firmware.'+name]={'value':get_parameter(case,'firmware.'+name),'kind':item['Type'],'constraint':item['Constraint']}
    return result


def set_parameter(case,path,value):
    if path.startswith('firmware.'):
        name=path.split('.',1)[1]
        if cfg.BY_NAME[name]['Type']=='integer': value=int(np.rint(float(value)))
        cfg.set_firmware(case,name,value); return
    old=get_parameter(case,path)
    if isinstance(old,bool):
        if value not in (True,False,0,1): raise ValueError(path+': use choices [true, false] or [0, 1].')
        value=bool(value)
    elif isinstance(old,str):
        value=str(value)
    else:
        value=float(value)
        if not math.isfinite(value): raise ValueError(path+': value must be finite.')
    keys=path.split('.'); parent=case
    for key in keys[:-1]: parent=parent[int(key)] if isinstance(parent,list) else parent[key]
    parent[int(keys[-1]) if isinstance(parent,list) else keys[-1]]=value
    if path.startswith('plant.tensor.'):
        i,j=map(int,keys[-2:]); case['plant']['tensor'][j][i]=value
        case['plant']['inertia']=np.diag(case['plant']['tensor']).tolist()


def default_design(base):
    return {'format':FORMAT,'version':1,'name':'Attitude robustness','base':cfg.upgrade(base),
        'count':24,'seed':7421,'method':'Latin hypercube','noise_seeds':'independent','workers':1,
        'include_nominal':True,'variables':[
            {'path':'plant.m','distribution':'uniform','mode':'percent change','args':[-5,5],'group':''},
            {'path':'plant.S','distribution':'uniform','mode':'percent change','args':[-5,5],'group':''},
            {'path':'plant.tau_wing','distribution':'uniform','mode':'percent change','args':[-10,10],'group':''}],
        'analysis':{'start_s':0,'settling_band_deg':1,'settling_band_dps':5,'settling_hold_s':.5,
            'criteria':[{'metric':'peak_tilt_deg','op':'<=','limit':20},
                        {'metric':'attitude_estimation_rms_deg','op':'<=','limit':3}]},
        'signals':SIGNALS[:10]+['altitude_m','motor1_pot'],'grid_points':501}


def variation_example(name):
    def variable(path,distribution,args,mode='absolute',group=''):
        return dict(path=path,distribution=distribution,args=args,mode=mode,group=group)
    if name=='Plant tolerances':
        return [variable('plant.m','uniform',[-5,5],'percent change'),variable('plant.S','uniform',[-5,5],'percent change'),
                variable('plant.tau_wing','uniform',[-10,10],'percent change')]
    if name=='PID gains':
        return [variable('firmware.'+term+'_'+axis,'uniform',[-10,10],'percent change') for axis in ('roll','pitch') for term in ('p','i')]
    if name=='Initial attitude':
        return [variable('initial.'+str(i),'uniform',[-5,5],'offset') for i in (6,7)]
    if name=='Sensor biases':
        return [variable(sensor+'.bias.'+str(i),'truncated normal',[0,std,-3*std,3*std],'offset')
            for sensor,std in (('gyro',.05),('accel',.002)) for i in range(3)]
    if name=='Noise seeds only': return []
    raise ValueError('Unknown variation example.')


def draw_distribution(variable,u):
    d=variable['distribution']; a=variable['args']
    if d=='choices':
        if not a: raise ValueError('Choices cannot be empty.')
        return [a[min(int(q*len(a)),len(a)-1)] for q in u]
    if d=='fixed':
        if len(a)!=1: raise ValueError('Fixed needs one value.')
        return [a[0]]*len(u)
    a=np.asarray(a,dtype=float)
    if not np.isfinite(a).all(): raise ValueError('Distribution parameters must be finite.')
    counts={'uniform':2,'normal':2,'truncated normal':4,'log uniform':2,'triangular':3}
    if d not in counts or len(a)!=counts[d]: raise ValueError('Wrong distribution or number of parameters.')
    if d in ('uniform','log uniform'):
        if a[1]<=a[0] or (d=='log uniform' and a[0]<=0): raise ValueError('Minimum must be below maximum (positive for log uniform).')
        values=a[0]+u*(a[1]-a[0]) if d=='uniform' else np.exp(np.log(a[0])+u*np.log(a[1]/a[0]))
    elif d in ('normal','truncated normal'):
        if a[1]<=0: raise ValueError('Standard deviation must be positive.')
        if d=='normal': values=stats.norm.ppf(u,loc=a[0],scale=a[1])
        else:
            if a[3]<=a[2]: raise ValueError('Truncation minimum must be below maximum.')
            values=stats.truncnorm.ppf(u,(a[2]-a[0])/a[1],(a[3]-a[0])/a[1],loc=a[0],scale=a[1])
    else:
        if not a[0]<=a[1]<=a[2] or a[2]<=a[0]: raise ValueError('Triangular requires minimum ≤ mode ≤ maximum.')
        values=stats.triang.ppf(u,(a[1]-a[0])/(a[2]-a[0]),loc=a[0],scale=a[2]-a[0])
    return values.tolist()


def validate_analysis(analysis):
    for name in ('start_s','settling_band_deg','settling_band_dps','settling_hold_s'):
        x=float(analysis[name])
        if not math.isfinite(x) or x<0 or (name!='start_s' and x==0): raise ValueError('Invalid analysis '+name)
    for c in analysis['criteria']:
        if c['metric'] not in METRICS or c['op'] not in ('<=','>=') or not math.isfinite(float(c['limit'])):
            raise ValueError('Choose an available metric, comparison and finite limit.')


def materialize(design,row):
    case=cfg.upgrade(design['base'])
    for path,value in row['values'].items(): set_parameter(case,path,value)
    case['seed']=row['noise_seed']; case['realtime']=False
    case['name']=f"{design['name']} / {'nominal' if row['nominal'] else 'trial '+str(row['id'])}"
    case['notes']=case.get('notes','')+'\nMonte Carlo: exact sampled values are saved in the parent study.'
    return case


def sample_design(design,cancel=None):
    if design.get('format')!=FORMAT: raise ValueError('Not a desktop Monte Carlo design.')
    count=int(design['count']); seed=int(design['seed'])
    if count!=design['count'] or not 1<=count<=10000: raise ValueError('Choose 1–10000 trials.')
    if seed!=design['seed'] or not 0<=seed<2**32: raise ValueError('Design seed must be a uint32 integer.')
    if design['workers'] not in (1,2,3,4): raise ValueError('Use 1–4 workers; one minimizes memory use.')
    if design['method'] not in ('Random','Latin hypercube'): raise ValueError('Unknown sampling method.')
    if design['noise_seeds'] not in ('independent','common'): raise ValueError('Unknown noise seed policy.')
    if int(design['grid_points'])!=design['grid_points'] or not 101<=design['grid_points']<=2001: raise ValueError('Display grid must have 101–2001 points.')
    if not design['signals'] or len(set(design['signals']))!=len(design['signals']) or len(design['signals'])>64: raise ValueError('Choose 1–64 unique envelope signals.')
    if any(not isinstance(k,str) or '/' in k or not k for k in design['signals']): raise ValueError('Invalid signal key.')
    unknown=set(design['signals'])-set(SIGNAL_CATALOG)
    if unknown: raise ValueError('Unknown envelope signals: '+', '.join(sorted(unknown)))
    validate_analysis(design['analysis']); base=cfg.upgrade(design['base']); runner.validate(base)
    catalog=parameter_catalog(base); variables=design['variables']; seen=set(); groups=[]
    for i,v in enumerate(variables):
        path=v['path']
        if path not in catalog or path in seen: raise ValueError('Unknown or duplicate parameter: '+path)
        seen.add(path)
        if v['mode'] not in MODES: raise ValueError('Unknown variation mode.')
        original=get_parameter(base,path)
        if v['mode']!='absolute' and (isinstance(original,(str,bool)) or (v['mode']=='percent change' and original==0)):
            raise ValueError(path+': use absolute values or offsets; percentage changes require a nonzero numeric baseline.')
        # Reject known inactive aliases rather than silently varying an ignored input.
        if path in ('plant.Ax','plant.Ay','plant.Az','plant.Aomega') and base['plant']['area_mode']!='direct':
            raise ValueError(path+': baseline uses wing factors; vary its Factor field instead.')
        if path.endswith('Factor') and base['plant']['area_mode']=='direct': raise ValueError(path+': baseline uses direct areas.')
        if path in ('gyro.sample_rate','accel.sample_rate') and base['timing_profile']=='BMI270': raise ValueError('Select Custom timing in the baseline before varying sensor rates.')
        group=v.get('group','').lstrip('-')
        groups.append(('shared',group) if group else ('independent',i))
    unique=list(dict.fromkeys(groups)); dimension=max(1,len(unique))
    streams=np.random.SeedSequence(seed).spawn(2)
    rng=np.random.default_rng(streams[0])
    u=qmc.LatinHypercube(d=dimension,rng=rng).random(count) if design['method']=='Latin hypercube' else rng.random((count,dimension))
    u=np.clip(u,np.finfo(float).eps,1-np.finfo(float).eps)
    columns={}
    for v,g in zip(variables,groups):
        quantiles=u[:,unique.index(g)]
        if v.get('group','').startswith('-'): quantiles=1-quantiles
        values=draw_distribution(v,quantiles); baseline=get_parameter(base,v['path'])
        if v['mode']=='offset': values=[baseline+x for x in values]
        if v['mode']=='percent change': values=[baseline*(1+x/100) for x in values]
        columns[v['path']]=values
    noise_rng=np.random.default_rng(streams[1]); seeds=[]; used=set()
    while len(seeds)<count:
        value=int(noise_rng.integers(0,2**32,dtype=np.uint64))
        if value not in used: seeds.append(value); used.add(value)
    rows=[]
    if design['include_nominal']: rows.append({'id':0,'nominal':True,'noise_seed':int(base['seed']),'values':{}})
    for i in range(count):
        rows.append({'id':i+1,'nominal':False,'noise_seed':seeds[i] if design['noise_seeds']=='independent' else int(base['seed']),
                     'values':{path:values[i] for path,values in columns.items()}})
    errors=[]
    for row in rows:
        if cancel is not None and cancel.is_set(): raise InterruptedError('Sampling cancelled; no simulations were started.')
        try:
            case=materialize(design,row); runner.validate(case)
            if design['analysis']['start_s']>=case['duration']: raise ValueError('Analysis start must precede trial duration.')
            row['values']={path:get_parameter(case,path) for path in row['values']}
        except Exception as e: errors.append(f"Trial {row['id']}: {e}")
    if errors: raise ValueError(f'{len(errors)} invalid sampled trials. No trials were resampled or started.\n'+'\n'.join(errors[:8]))
    return rows


def metric_values(record,analysis):
    """Metrics use full-resolution saved signals, not ensemble display samples."""
    t=record['time_s']; start=float(analysis['start_s'])
    if start>=t[-1]: raise ValueError('Analysis window contains no flight data.')
    time=np.r_[start,t[t>start]]
    def y(key):
        signal=record.signals[key]; return np.interp(time,signal.time,signal.values)
    roll,pitch=y('roll_rad'),y('pitch_rad')
    result={'peak_tilt_deg':float(np.rad2deg(np.arccos(np.clip(np.cos(roll)*np.cos(pitch),-1,1))).max()),
        'attitude_estimation_rms_deg':max(rms(time,np.rad2deg(y('error_'+k))) for k in ('roll_rad','pitch_rad')),
        'peak_attitude_error_deg':max(float(np.max(np.abs(np.rad2deg(y('error_'+k))))) for k in ('roll_rad','pitch_rad')),
        'peak_body_rate_dps':max(float(np.max(np.abs(np.rad2deg(y(k))))) for k in ('p_radps','q_radps','r_radps')),
        'horizontal_drift_m':float(np.max(np.hypot(y('x_m')-record['x_m'][0],y('y_m')-record['y_m'][0]))),
        'vertical_drift_m':float(np.max(np.abs(y('z_m')-record['z_m'][0]))),
        'final_altitude_change_m':float(record['z_m'][0]-y('z_m')[-1]),
        'final_roll_deg':float(np.rad2deg(roll[-1])), 'final_pitch_deg':float(np.rad2deg(pitch[-1])),
        'angle_tracking_rms_deg':None,'rate_tracking_rms_dps':None,'settling_time_s':None}
    mode=record.settings['command_mode']; angle=mode=='angle'; errors=[]; command_changes=[]
    for key in (('roll_rad','pitch_rad') if angle else ('p_radps','q_radps')):
        requested=record.signals[('setpoint_' if mode=='receiver' else 'reference_')+key]
        changes=np.flatnonzero(np.diff(requested.values)!=0)+1
        if len(changes): command_changes.append(float(requested.time[changes[-1]]))
        ix=np.clip(np.searchsorted(requested.time,time,side='right')-1,0,len(requested.time)-1)
        error=y(key)-requested.values[ix]
        if angle: error=np.arctan2(np.sin(error),np.cos(error))
        errors.append(np.rad2deg(error))
    result['angle_tracking_rms_deg' if angle else 'rate_tracking_rms_dps']=max(rms(time,e) for e in errors)
    last_command=max([start]+command_changes)
    band=analysis['settling_band_deg' if angle else 'settling_band_dps']
    active=time>=last_command; tt=time[active]; within=np.max(np.abs(np.asarray(errors)[:,active]),axis=0)<=band
    if mode!='receiver' and len(tt):
        bad=np.flatnonzero(~within); first=int(bad[-1]+1) if len(bad) else 0
        if first<len(tt) and tt[-1]-tt[first]>=analysis['settling_hold_s']:
            result['settling_time_s']=float(tt[first]-last_command)
    low=float(cfg.firmware_value(record.settings,'min_command'))+.1*float(cfg.firmware_value(record.settings,'motor_idle'))
    high=float(cfg.firmware_value(record.settings,'max_throttle'))
    motors=np.asarray([y(f'motor{i}_pot') for i in range(1,5)])
    rail=np.any((motors<=low+1)|(motors>=high-1),axis=0).astype(float)
    result['motor_rail_percent']=float(100*np.sum(rail[:-1]*np.diff(time))/(time[-1]-time[0]))
    return result


def assess(metrics,criteria):
    violations=[]
    for c in criteria:
        value=metrics.get(c['metric'])
        if value is None or not math.isfinite(value): violations.append(c['metric']+': unavailable / unsettled')
        elif not (value<=c['limit'] if c['op']=='<=' else value>=c['limit']): violations.append(f"{c['metric']}: {value:.6g} {c['op']} {c['limit']}: failed")
    return not violations,violations


def create_study(design,root,cancel=None):
    rows=sample_design(design,cancel)
    folder=Path(root)/(dt.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]); folder.mkdir(parents=True)
    design=copy.deepcopy(design); design['base']=cfg.upgrade(design['base'])
    design['engine_sha256']=hashlib.sha256(runner.EXE.read_bytes()).hexdigest()
    design['created']=dt.datetime.now(dt.timezone.utc).isoformat()
    atomic_json(folder/'study.json',design); atomic_json(folder/'analysis.json',design['analysis'])
    manifest={'format':FORMAT,'status':'ready','rows':[{**r,'status':'pending','attempt':0} for r in rows]}
    atomic_json(folder/'manifest.json',manifest)
    with (folder/'samples.csv').open('w',newline='',encoding='utf-8-sig') as f:
        fields=['id','nominal','noise_seed']+[v['path'] for v in design['variables']]
        writer=csv.DictWriter(f,fieldnames=fields); writer.writeheader()
        for row in rows: writer.writerow({**{k:row[k] for k in fields[:3]},**row['values']})
    max_time=max(r['values'].get('duration',design['base']['duration']) for r in rows)
    with h5py.File(folder/'ensemble.h5','w') as f:
        f.attrs['purpose']='Display-grid samples only; full-resolution data are in runs.'
        f.create_dataset('time_s',data=np.linspace(0,max_time,int(design['grid_points'])))
        for key in design['signals']:
            f.create_dataset(key,shape=(len(rows),int(design['grid_points'])),dtype='f8',fillvalue=np.nan,
                chunks=(1,int(design['grid_points'])),compression='gzip',compression_opts=1)
    return folder


def process_alive(pid):
    if os.name=='nt':
        import ctypes
        from ctypes import wintypes
        k=ctypes.WinDLL('kernel32',use_last_error=True)
        k.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD]; k.OpenProcess.restype=wintypes.HANDLE
        k.GetExitCodeProcess.argtypes=[wintypes.HANDLE,ctypes.POINTER(wintypes.DWORD)]
        k.CloseHandle.argtypes=[wintypes.HANDLE]
        handle=k.OpenProcess(0x1000,False,pid)
        if not handle: return ctypes.get_last_error()!=87  # fail closed on access errors
        try:
            code=wintypes.DWORD(); return not k.GetExitCodeProcess(handle,ctypes.byref(code)) or code.value==259
        finally: k.CloseHandle(handle)
    try: os.kill(pid,0); return True
    except ProcessLookupError: return False


def acquire_study_lock(folder):
    """One writer per study; allow recovery after an interrupted application."""
    lock=Path(folder)/'study.lock'
    if lock.exists():
        owner=json.loads(lock.read_text())
        if process_alive(int(owner['pid'])):
            raise RuntimeError('This study is being updated in another window/process. Wait for it to finish or stop it there first.')
        lock.unlink()
    try:
        with lock.open('x') as f: json.dump({'pid':os.getpid()},f)
    except FileExistsError:
        raise RuntimeError('Another process started updating this study. Try again after it finishes.') from None
    return lock


class BatchControl:
    def __init__(self):
        self.cancel=threading.Event(); self.paused=threading.Event(); self.lock=threading.Lock()
        self.folders=set(); self.processes=set()
    def register(self,kind,value):
        with self.lock:
            if kind=='folder':
                self.folders.add(value)
                if self.cancel.is_set(): (value/'stop').touch()
                elif self.paused.is_set(): (value/'pause').touch()
            elif kind=='process': self.processes.add(value)
    def pause(self,on):
        if on: self.paused.set()
        else: self.paused.clear()
        with self.lock:
            for folder in self.folders:
                if on: (folder/'pause').touch()
                else: (folder/'pause').unlink(missing_ok=True)
    def stop(self):
        self.cancel.set(); self.paused.clear()
        with self.lock:
            for folder in self.folders:
                (folder/'stop').touch(); (folder/'pause').unlink(missing_ok=True)
    def terminate(self):
        self.stop()
        with self.lock:
            for process in self.processes:
                if process.poll() is None: process.terminate()


def analyze_run(folder,analysis,signals,grid):
    record=storage.load_run(folder); metrics=metric_values(record,analysis); curves={}
    for key in signals:
        if key not in record.signals: raise ValueError('Envelope signal unavailable: '+key)
        signal=record.signals[key]; values=signal.values
        if signal.unit in ('rad','rad/s'): values=np.rad2deg(values)
        curves[key]=np.interp(grid,signal.time,values,left=np.nan,right=np.nan)
    return metrics,curves


def run_study(folder,control=None,notify=lambda *args:None,retry_errors=False):
    folder=Path(folder); control=control or BatchControl(); lock=acquire_study_lock(folder)
    try:
        design=storage.read_json(folder/'study.json'); manifest=storage.read_json(folder/'manifest.json')
        if design['engine_sha256']!=hashlib.sha256(runner.EXE.read_bytes()).hexdigest():
            raise ValueError('The native executable changed. Start a new study to avoid mixing engine versions.')
        analysis=storage.read_json(folder/'analysis.json'); rows=manifest['rows']
        eligible={'pending','running','stopped'}|({'failed','analysis failed'} if retry_errors else set())
        pending=[i for i,row in enumerate(rows) if row['status'] in eligible]
        with h5py.File(folder/'ensemble.h5','r') as f: grid=f['time_s'][()]
        manifest['status']='running'; atomic_json(folder/'manifest.json',manifest)
        def trial(index):
            row=copy.deepcopy(rows[index]); case=materialize(design,row)
            run_folder=folder/'runs'/f"trial_{row['id']:05d}_attempt_{row['attempt']:02d}"
            run_folder.parent.mkdir(exist_ok=True)
            result={'run_folder':str(run_folder.relative_to(folder)),'metrics':{},'passed':None,'violations':[],'error':''}
            try:
                if control.cancel.is_set(): return index,{**result,'status':'stopped'},{}
                runner.execute(case,run_folder,progress=control.register)
                summary=storage.read_json(run_folder/'engine_summary.json')
                if not summary.get('completed'): return index,{**result,'status':'stopped'},{}
                result['status']='analysis failed'
                metrics,curves=analyze_run(run_folder,analysis,design['signals'],grid)
                passed,violations=assess(metrics,analysis['criteria'])
                return index,{**result,'status':'complete','metrics':metrics,'passed':passed,'violations':violations},curves
            except Exception as e:
                status='stopped' if control.cancel.is_set() else result.get('status','failed')
                return index,{**result,'status':status,'error':str(e)},{}
            finally:
                with control.lock:
                    control.folders.discard(run_folder)
                    control.processes={p for p in control.processes if p.poll() is None}
        with ThreadPoolExecutor(max_workers=int(design['workers'])) as pool:
            active={}
            while pending or active:
                while pending and len(active)<design['workers'] and not control.cancel.is_set() and not control.paused.is_set():
                    i=pending.pop(0); rows[i].update(status='running',attempt=rows[i].get('attempt',0)+1)
                    atomic_json(folder/'manifest.json',manifest); active[pool.submit(trial,i)]=i
                    notify('trial',(i,copy.deepcopy(rows[i])))
                if control.cancel.is_set() and not active: break
                if not active:
                    control.cancel.wait(.1); continue
                done,_=wait(active,timeout=.15,return_when=FIRST_COMPLETED)
                for future in done:
                    active.pop(future); i,result,curves=future.result()
                    if curves:
                        with h5py.File(folder/'ensemble.h5','a') as f:
                            for key,values in curves.items(): f[key][i,:]=values
                    rows[i].update(result); atomic_json(folder/'manifest.json',manifest)
                    notify('trial',(i,copy.deepcopy(rows[i])))
        manifest['status']='stopped' if control.cancel.is_set() else 'finished'
        atomic_json(folder/'manifest.json',manifest)
        export_results(folder)
        return manifest
    finally: lock.unlink(missing_ok=True)


def summarize(folder):
    folder=Path(folder); manifest=storage.read_json(folder/'manifest.json'); rows=[r for r in manifest['rows'] if not r['nominal']]
    complete=[r for r in rows if r['status']=='complete']; metrics={}
    for key in METRICS:
        values=[r['metrics'][key] for r in complete if r['metrics'].get(key) is not None]
        if values:
            q=np.percentile(values,[5,50,95]); metrics[key]={'n':len(values),'mean':float(np.mean(values)),
                'std':float(np.std(values,ddof=1)) if len(values)>1 else None,'p05':float(q[0]),'median':float(q[1]),'p95':float(q[2]),'minimum':min(values),'maximum':max(values)}
    return {'requested':len(rows),'complete':len(complete),'criteria_pass':sum(r.get('passed') is True for r in complete),
        'outcomes':{key:sum(r['status']==key for r in rows) for key in ('pending','running','complete','failed','analysis failed','stopped')},
        'metrics':metrics,'note':'Nominal is excluded. Quantiles are empirical distributions, not confidence intervals. Failed/stopped trials are excluded from numeric metrics and listed separately.'}


def export_results(folder,destination=None):
    folder=Path(folder); destination=Path(destination or folder); destination.mkdir(parents=True,exist_ok=True)
    design=storage.read_json(folder/'study.json'); manifest=storage.read_json(folder/'manifest.json')
    atomic_json(destination/'summary.json',summarize(folder))
    fields=['id','nominal','noise_seed','status','passed','error','run_folder']+[v['path'] for v in design['variables']]+list(METRICS)
    with (destination/'metrics.csv').open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.DictWriter(f,fieldnames=fields); writer.writeheader()
        for r in manifest['rows']: writer.writerow({**{k:r.get(k,'') for k in fields[:7]},**r['values'],**r.get('metrics',{})})


def reprocess(folder,analysis,notify=lambda *args:None,cancel=None):
    folder=Path(folder); validate_analysis(analysis)
    lock=acquire_study_lock(folder)
    try:
        manifest=storage.read_json(folder/'manifest.json'); updates=[]
        for i,row in enumerate(manifest['rows']):
            if cancel is not None and cancel.is_set(): raise InterruptedError('Reprocessing cancelled; previous metrics were retained.')
            if row['status']!='complete': continue
            metrics=metric_values(storage.load_run(folder/row['run_folder']),analysis)
            passed,violations=assess(metrics,analysis['criteria'])
            updates.append((i,metrics,passed,violations)); notify('status',f"Reprocessed trial {row['id']}")
        # Calculate all metrics first: invalid windows leave prior analysis intact.
        # Envelope caches are unchanged; only scalar metrics/limits are reprocessed.
        if cancel is not None and cancel.is_set(): raise InterruptedError('Reprocessing cancelled; previous metrics were retained.')
        for i,metrics,passed,violations in updates:
            manifest['rows'][i].update(metrics=metrics,passed=passed,violations=violations)
        history=folder/'analysis_history'; history.mkdir(exist_ok=True)
        atomic_json(history/(uuid.uuid4().hex+'.json'),storage.read_json(folder/'analysis.json'))
        atomic_json(folder/'analysis.json',analysis); atomic_json(folder/'manifest.json',manifest); export_results(folder)
    finally: lock.unlink(missing_ok=True)
