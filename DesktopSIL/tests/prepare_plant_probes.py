from pathlib import Path
import copy,json,math,subprocess,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import configuration as cfg
import runner

def main():
    baseline=cfg.from_matlab(json.loads((cfg.ROOT/"catalog/hover_settings.json").read_text()))
    baseline["duration"]=1; baseline["initial"][6:8]=[math.degrees(.03),math.degrees(-.02)]
    cases=[]
    for fidelity in ("high","low"):
        for noise in (False,True):
            c=copy.deepcopy(baseline); c.update(fidelity=fidelity,noise=noise); cases.append((f"{fidelity}_{int(noise)}",c))
    for fidelity in ("high","low"):
        c=copy.deepcopy(baseline); c["fidelity"]=fidelity
        c["plant"].update(m=.13,C11=.00051,C21=-.55,tau_wing=.065,g=9.7,CDx=.7,CDy=.4,CDz=.8,CDw=.5,v_ref=.7,w_ref=.6,p_ref=80,q_ref=70,r_ref=90)
        c["gyro"].update(sample_rate=2000,density=.01,bandwidth=650)
        c["accel"].update(sample_rate=1000,density=.00025,bandwidth=450)
        cases.append((f"{fidelity}_retuned",c))
    c=copy.deepcopy(baseline); c["gyro"]["sample_rate"]=3000; c["accel"]["sample_rate"]=1000
    cases.append(("high_flexible_rates",c))
    manifest=[]
    for tag,c in cases:
        folder=runner.prepare(c); output=cfg.ROOT/"verification"/("adapter_"+tag+".csv")
        subprocess.run([str(cfg.ROOT/"build/adapter_probe.exe"),str(folder/"case.txt"),str(output)],check=True,env=runner.environment(folder),creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
        manifest.append({"tag":tag,"case":c,"output":str(output)})
    (cfg.ROOT/"verification/adapter_cases.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("Prepared",len(manifest),"native plant probes")
if __name__=="__main__": main()
