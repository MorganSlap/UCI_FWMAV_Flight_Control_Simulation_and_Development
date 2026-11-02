"""Flight-analysis definitions matched to Hover Workbench's saved-run views."""
import numpy as np

def rms(time,error):
    if len(time)<2 or time[-1]<=time[0]: return float(np.sqrt(np.mean(error**2)))
    return float(np.sqrt(np.trapezoid(error**2,time)/(time[-1]-time[0])))

def flight_analysis(record,axis):
    name=("Roll","Pitch","Yaw")[axis]; angle=("roll_rad","pitch_rad","yaw_rad")[axis]; rate=("p_radps","q_radps","r_radps")[axis]
    mode=record.settings.get("command_mode","receiver"); angle_mode=mode=="angle" and axis<2
    tracking=angle if angle_mode else rate; estimate="estimate_"+(angle if angle_mode else rate)
    command="reference_"+tracking if mode!="receiver" else "setpoint_"+rate
    panels=[]
    def panel(title,description,keys):
        series=[]
        for key,label in keys:
            item=record.series(key)
            if item: series.append((label,item[1],item[2]))
        panels.append({"title":title,"description":description,"series":series})
    unit="deg" if angle_mode else "deg/s"
    panel(f"{name} {'angle' if angle_mode else 'rate'}: command and response",f"True plant response and estimated feedback; requested command before receiver shaping ({unit}).",[(command,"Requested command" if mode!="receiver" else "Native receiver rate"),(tracking,"True plant"),(estimate,"Estimated attitude (Mahony)" if angle_mode else "Estimated rate (firmware gyro)")])
    if angle_mode:
        panel(f"{name} angular rate feedback","True body rate versus processed gyro used as the firmware rate estimate. Mahony has no separate body-rate state (deg/s).",[(rate,"True body rate"),("estimate_"+rate,"Estimated rate (firmware gyro)")])
    else:
        panel(f"{name} attitude estimate","Orientation resulting from the rate response: true versus estimated (deg).",[(angle,"True plant"),("estimate_"+angle,"Betaflight attitude")])
    panel(f"{name} attitude estimation error","Wrapped true angle minus estimated angle; zero means an accurate estimate (deg).",[("error_"+angle,"True − estimated")])
    panel(f"{name} rate-controller contributions","Native P, I, D, feedforward and sum before motor mixing. Values are firmware PID units, not torque.",[(f"{name.lower()}_{term}",label) for term,label in (("P","P"),("I","I"),("D","D"),("F","Feedforward"),("PID_sum","Sum"))])
    panel("Actuator outputs after mixing","All four firmware motor commands; dashed reference is the plant's hover trim (PWM / pot).",[(f"motor{i}_pot",f"Motor {i}") for i in range(1,5)])
    trim=record.variables.get("u0",record.variables.get("trim_pot"))
    if trim is not None and panels[-1]["series"]:
        time=panels[-1]["series"][0][1]; panels[-1]["series"].append(("Hover trim",np.array([time[0],time[-1]]),np.array([trim,trim])))
    panel(f"{name} raw gyro sensor error","Raw sensor measurement minus ideal sensor input, before firmware processing. This is NOT estimation error (deg/s).",[(f"gyro_error_{'xyz'[axis]}_radps","Raw − Ideal sensor")])
    panel(f"{name} rate estimation error","True plant body rate minus the firmware processed-rate estimate; zero means exact rate feedback (deg/s).",[("error_"+rate,"True − Estimated rate")])
    tracking_rms=float("nan"); estimator_rms=float("nan")
    actual=record.signals.get(tracking); requested=record.signals.get(command)
    if actual and requested:
        indices=np.clip(np.searchsorted(requested.time,actual.time,side="right")-1,0,len(requested.time)-1)
        error=actual.values-requested.values[indices]
        if angle_mode: error=np.arctan2(np.sin(error),np.cos(error))
        tracking_rms=rms(actual.time,np.rad2deg(error))
    estimate_error=record.signals.get("error_"+angle)
    if estimate_error: estimator_rms=rms(estimate_error.time,np.rad2deg(estimate_error.values))
    motors=[record.signals[f"motor{i}_pot"].values for i in range(1,5) if f"motor{i}_pot" in record.signals]
    metrics={"axis":name,"mode":mode,"tracking_rms":tracking_rms,"tracking_unit":unit,"estimator_rms_deg":estimator_rms,
             "motor_min":min(float(x.min()) for x in motors) if motors else float("nan"),"motor_max":max(float(x.max()) for x in motors) if motors else float("nan")}
    return panels,metrics
