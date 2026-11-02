"""Native SIL desktop controls. All simulation work runs in a separate process."""
import copy
import json
from pathlib import Path
import queue
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import numpy as np
import runner
from plots import Plot, display_signal
from parity_ui import ParityFeatures

class App(ParityFeatures,tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Flight Simulation | Native Desktop SIL")
        self.geometry("1330x900"); self.minsize(1040,720); self.configure(bg="#151d29")
        self.case=runner.load_case(runner.ROOT/"presets/noisy_hover.json")
        self.fields={}; self.fw_fields={}; self.setting_bodies={}; self.field_widgets={}; self.events=queue.Queue(); self.running=False
        self.process=None; self.folder=None; self.data=None; self.custom_count=0
        self.closing=False; self.paused=False; self.preview_pending=False; self.stop_requested=False
        self.style()
        header=ttk.Frame(self,padding=(22,14)); header.pack(fill="x")
        ttk.Label(header,text="FLIGHT SIMULATION",style="Title.TLabel").pack(side="left")
        ttk.Label(header,text="GENERATED C PLANT  /  BETAFLIGHT SITL",style="Muted.TLabel").pack(side="left",padx=24)
        ttk.Button(header,text="Save settings…",command=self.save).pack(side="right",padx=4)
        ttk.Button(header,text="Load settings…",command=self.load).pack(side="right",padx=4)
        controls=ttk.Frame(self,padding=(22,6)); controls.pack(fill="x")
        self.run_toolbar=controls
        self.run_button=ttk.Button(controls,text="▶  Run simulation",style="Accent.TButton",command=self.run)
        self.run_button.pack(side="left")
        self.pause_button=ttk.Button(controls,text="Pause",command=self.pause,state="disabled"); self.pause_button.pack(side="left",padx=8)
        self.stop_button=ttk.Button(controls,text="Stop",command=self.stop,state="disabled"); self.stop_button.pack(side="left")
        self.status=tk.StringVar(value="Ready • settings apply to the next run")
        ttk.Label(controls,textvariable=self.status).pack(side="left",padx=18)
        self.progress=ttk.Progressbar(self,maximum=100); self.progress.pack(fill="x",padx=22,pady=(3,10))
        self.pages=ttk.Notebook(self); self.pages.pack(fill="both",expand=True,padx=18,pady=(0,10))
        settings=ttk.Frame(self.pages); self.pages.add(settings,text="  Settings  ")
        self.settings_tabs=ttk.Notebook(settings); self.settings_tabs.pack(fill="both",expand=True,padx=8,pady=8)
        run=self.setting_page("Run setup")
        self.run_page=run
        preset=ttk.LabelFrame(run,text="Flight case",padding=16); preset.pack(fill="x",pady=8)
        ttk.Button(preset,text="Noisy trimmed hover",command=lambda:self.preset("noisy_hover.json")).pack(side="left",padx=6)
        ttk.Button(preset,text="Noisy roll recovery",command=lambda:self.preset("noisy_recovery.json")).pack(side="left",padx=6)
        box=self.section(run,"Run configuration")
        self.run_box=box
        for row,(label,key) in enumerate((("Case name","name"),("Simulation duration (s)","duration"),("Throttle receiver command (µs)","throttle"),("Logging rate (Hz)","log_hz"),("Noise seed","seed"),("Reference starts at (s)","reference_time"))): self.field(box,row,label,key)
        self.field(box,6,"Command mode","command_mode",choices=("angle","rate","receiver"))
        for row,(label,key) in enumerate((("Sensor and actuator noise ON","noise"),("Simulate aerodynamic drag","drag"),("Pace flight at real time","realtime"),("Apply known accelerometer bias calibration","known_accel_calibration")),7): self.check(box,row,label,key)
        ttk.Label(run,text="Selectable linear / nonlinear plant • ODE5 (Dormand–Prince) • Default maximum step 1/16000 s\nThrottle is fixed; altitude and horizontal position are not controlled. Gains and physical parameters apply without recompilation.\nIntegration rate, sensor rates and PID divider are configurable. Calibration and arming precede flight; pacing applies to flight only.",style="Muted.TLabel",justify="left").pack(anchor="w",pady=16)
        self.pid_page(); self.sensor_page(); self.initial_page(); self.plant_page(); self.firmware_page()
        plotpage=ttk.Frame(self.pages); self.pages.add(plotpage,text="  Default plots  ")
        self.plots=ttk.Notebook(plotpage); self.plots.pack(fill="both",expand=True)
        self.default_plots={}
        self.groups={
            "True attitude": ["roll_rad","pitch_rad","yaw_rad"],
            "Estimated attitude": ["estimate_roll_rad","estimate_pitch_rad","estimate_yaw_rad"],
            "Angular rates": ["p_radps","q_radps","r_radps"],
            "Filtered gyro": ["filtered_p_radps","filtered_q_radps","filtered_r_radps"],
            "Position": ["x_m","y_m","z_m"], "Body velocity": ["u_mps","v_mps","w_mps"],
            "Raw gyro": [f"raw_gyro_{a}_radps" for a in "xyz"],
            "Raw accel": [f"raw_accel_{a}_mps2" for a in "xyz"],
            "Motor commands": [f"motor{i}_pot" for i in range(1,5)]}
        for title in self.groups:
            plot=Plot(self.plots,title); self.plots.add(plot,text=title); self.default_plots[title]=plot
        self.explorer_page()
        archive=ttk.Frame(self.pages,padding=14); self.pages.add(archive,text="  Saved runs  ")
        ttk.Label(archive,text="Every run saves its settings, effective firmware configuration, signals and timing report.",style="Subhead.TLabel").pack(anchor="w",pady=10)
        row=ttk.Frame(archive); row.pack(fill="x")
        ttk.Button(row,text="Refresh",command=self.refresh_runs).pack(side="left")
        ttk.Button(row,text="Open selected signals",command=self.open_archive).pack(side="left",padx=8)
        ttk.Button(row,text="Load selected settings",command=self.load_archive_settings).pack(side="left")
        ttk.Button(row,text="Open run folder…",command=self.browse_run).pack(side="right")
        self.runs=tk.Listbox(archive,bg="#202b3b",fg="#e2e9f2",font=("Consolas",11),relief="flat",selectbackground="#52657d")
        self.runs.pack(fill="both",expand=True,pady=12); self.runs.bind("<Double-Button-1>",lambda e:self.open_archive())
        ttk.Label(self,text="C engine runs independently of MATLAB • Angular inputs use degrees • HDF5 archives and CSV/MAT data exports use SI units",style="Muted.TLabel").pack(anchor="w",padx=24,pady=(0,10))
        self.enhance(); self.populate(); self.refresh_runs(); self.protocol("WM_DELETE_WINDOW",self.close)
        self.after(100,self.poll)
        self.bind("<MouseWheel>",self.scroll_settings,add="+")
    def scroll_settings(self,event):
        if self.pages.index(self.pages.select())!=0: return
        if event.widget.winfo_class() in ("Text","Listbox","TCombobox","Treeview"): return
        outer=self.settings_tabs.nametowidget(self.settings_tabs.select())
        if not str(event.widget).startswith(str(outer)+"."): return
        for widget in outer.winfo_children():
            if isinstance(widget,tk.Canvas): widget.yview_scroll(-int(event.delta/120),"units"); break
    def style(self):
        s=ttk.Style(self); s.theme_use("clam")
        s.configure(".",background="#202b3b",foreground="#e2e9f2",font=("Segoe UI",10),borderwidth=0)
        s.configure("TFrame",background="#202b3b"); s.configure("TLabel",background="#202b3b")
        s.configure("Title.TLabel",font=("Segoe UI",20,"bold"),foreground="#f4b340")
        s.configure("Subhead.TLabel",font=("Segoe UI",11,"bold"))
        s.configure("Muted.TLabel",foreground="#adbbcc",font=("Segoe UI",9))
        s.configure("TButton",padding=(12,7),background="#35465d"); s.map("TButton",background=[("active","#465c78")])
        s.configure("Accent.TButton",background="#e8a631",foreground="#15202c"); s.map("Accent.TButton",background=[("active","#ffc55b")])
        s.configure("TEntry",fieldbackground="#121d2b",foreground="#f1f5fa",insertcolor="white",padding=6)
        s.configure("TCombobox",fieldbackground="#121d2b",foreground="#f1f5fa",padding=5)
        s.map("TCombobox",fieldbackground=[("readonly","#121d2b")],foreground=[("readonly","#f1f5fa")])
        s.configure("TNotebook",background="#151d29"); s.configure("TNotebook.Tab",padding=(12,9),background="#2c3a4e")
        s.map("TNotebook.Tab",background=[("selected","#41536b")],foreground=[("selected","#ffca66")])
        s.configure("TLabelframe",bordercolor="#47566b",relief="solid",borderwidth=1)
        s.configure("TLabelframe.Label",foreground="#f0bd68",font=("Segoe UI",11,"bold"))
        s.configure("TCheckbutton",padding=5); s.map("TCheckbutton",background=[("active","#35465d")])
        s.configure("Horizontal.TProgressbar",background="#e8a631",troughcolor="#151d29")
    def setting_page(self,title):
        outer=ttk.Frame(self.settings_tabs); self.settings_tabs.add(outer,text=title)
        canvas=tk.Canvas(outer,bg="#202b3b",highlightthickness=0); scroll=ttk.Scrollbar(outer,orient="vertical",command=canvas.yview)
        scroll.pack(side="right",fill="y"); canvas.pack(side="left",fill="both",expand=True); canvas.configure(yscrollcommand=scroll.set)
        body=ttk.Frame(canvas,padding=18); item=canvas.create_window(0,0,window=body,anchor="nw")
        body.bind("<Configure>",lambda e:canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.bind("<Configure>",lambda e:canvas.itemconfigure(item,width=e.width))
        self.setting_bodies[title]=body
        return body
    def section(self,parent,title):
        box=ttk.LabelFrame(parent,text=title,padding=14); box.pack(fill="x",pady=8); return box
    def field(self,parent,row,label,path,choices=None,firmware=False):
        ttk.Label(parent,text=label).grid(row=row,column=0,sticky="w",padx=(0,18),pady=4)
        v=tk.StringVar(); widget=(ttk.Combobox(parent,textvariable=v,values=choices,state="readonly",width=21) if choices else ttk.Entry(parent,textvariable=v,width=24))
        widget.grid(row=row,column=1,sticky="w",pady=4)
        (self.fw_fields if firmware else self.fields)[path]=v
        self.field_widgets[("firmware." if firmware else "")+path]=(widget,label)
    def check(self,parent,row,label,path):
        v=tk.BooleanVar(); ttk.Checkbutton(parent,text=label,variable=v).grid(row=row,column=0,columnspan=2,sticky="w",pady=3); self.fields[path]=v
    def pid_page(self):
        page=self.setting_page("PID / angle control"); box=self.section(page,"Native Betaflight PID gains — profile 0")
        for j,name in enumerate(("Axis","P","I","D","Feedforward")): ttk.Label(box,text=name,style="Subhead.TLabel").grid(row=0,column=j,padx=12,pady=6)
        for i,axis in enumerate(("roll","pitch","yaw"),1):
            ttk.Label(box,text=axis.title()).grid(row=i,column=0,padx=12)
            for j,gain in enumerate("pidf",1):
                v=tk.StringVar(); self.fw_fields[f"{gain}_{axis}"]=v
                ttk.Entry(box,textvariable=v,width=10).grid(row=i,column=j,padx=10,pady=6)
        box=self.section(page,"Angle mode attitude control")
        self.field(box,0,"Angle P gain","angle_p_gain",firmware=True)
        ttk.Label(page,text="These are native firmware menu values. The default roll/pitch gains reproduce the original torque-based PI gains approximately.\nYaw torque is absent in the nonlinear plant. Optional PID shaping remains disabled in the supplied cases.",style="Muted.TLabel").pack(anchor="w",pady=10)
    def sensor_page(self):
        page=self.setting_page("Gyro / accelerometer")
        for key,title,biasunit,densityunit in (("gyro","GYROSCOPE • 3200 Hz","deg/s","deg/s/√Hz"),("accel","ACCELEROMETER • 1600 Hz","g","g/√Hz")):
            box=self.section(page,title)
            for row,(label,path) in enumerate(((f"Noise density ({densityunit})","density"),("Sensor noise bandwidth (Hz)","bandwidth"),(f"Bias X, Y, Z ({biasunit})","bias"),(f"24 Hz wing vibration amplitude ({biasunit})","vibration"))): self.field(box,row,label,f"{key}.{path}")
            self.field(box,4,"Firmware low-pass cutoff (Hz)","gyro_lpf1_static_hz" if key=="gyro" else "acc_lpf_hz",firmware=True)
        ttk.Label(page,text="White-noise power retains the original density² × bandwidth mask formula. Free-flight sample rates and sensor saturation limits are compiled.\nDefault gyro filter: native PT1 at 5 Hz. Default accelerometer filter: native PT2 at 5 Hz. Additional firmware filters are in the CLI page.",style="Muted.TLabel").pack(anchor="w",pady=10)
    def initial_page(self):
        page=self.setting_page("Initial state / references"); box=self.section(page,"Initial state — angles and rates are entered in degrees")
        labels=("X position (m)","Y position (m)","Z position, down (m)","U body velocity (m/s)","V body velocity (m/s)","W body velocity (m/s)","Roll (deg)","Pitch (deg)","Yaw (deg)","P rate (deg/s)","Q rate (deg/s)","R rate (deg/s)")
        for i,label in enumerate(labels): self.field(box,i,label,f"initial.{i}")
        box=self.section(page,"Reference command — applied at the start time on Run setup")
        for row,i in enumerate((6,7,9,10,11)): self.field(box,row,labels[i],f"reference.{i}")
        ttk.Label(page,text="ANGLE uses roll and pitch angles plus yaw rate. RATE uses P, Q and R body rates. Other reference values are unused.\nA stationary fixture aligns the estimator to the initial tilt before release into free flight.",style="Muted.TLabel").pack(anchor="w",pady=10)
    def plant_page(self):
        page=self.setting_page("Physical plant"); box=self.section(page,"Rigid body and actuator")
        fields=(("Mass (kg)","m"),("Principal inertia Ix, Iy, Iz (kg m²)","inertia"),("Moment arm (m)","S"),("Gravity (m/s²)","g"),("Air density (kg/m³)","rho"),("Thrust slope C11 (N/pot)","C11"),("Thrust intercept C21 (N)","C21"),("Actuator time constant (s)","tau_wing"))
        for i,(label,key) in enumerate(fields): self.field(box,i,label,"plant."+key)
        box=self.section(page,"Quadratic drag — switch all drag off on Run setup")
        for i,key in enumerate(("CDx","CDy","CDz","CDw","Ax","Ay","Az","Aomega")): self.field(box,i,key + (" (m²)" if key.startswith("A") else ""),"plant."+key)
    def firmware_page(self):
        page=self.setting_page("Firmware CLI")
        ttk.Label(page,text="Configuration is processed by the real Betaflight CLI before each run.",style="Subhead.TLabel").pack(anchor="w")
        ttk.Label(page,text="PID and filter controls update this text when you enter this page. Keep the 4 kHz loop, PWM output and four-motor mixer.\nChanging receiver mapping or AUX ranges also requires matching receiver arrays in the saved JSON. Startup verifies arming, modes and loop timing.",style="Muted.TLabel").pack(anchor="w",pady=8)
        self.cli=tk.Text(page,height=25,bg="#111b29",fg="#d8e4f0",insertbackground="white",font=("Consolas",10),undo=True,wrap="none")
        self.cli.pack(fill="both",expand=True)
        self.cli_page=page.master.master
        self.settings_tabs.bind("<<NotebookTabChanged>>",self.sync_cli)
    def _legacy_explorer_page(self):
        page=ttk.Frame(self.pages,padding=8); self.pages.add(page,text="  Explore signals  ")
        sidebar=ttk.Frame(page,padding=8); sidebar.pack(side="left",fill="y")
        ttk.Button(sidebar,text="Open saved run…",command=self.browse_run).pack(fill="x",pady=5)
        self.search=tk.StringVar(); self.search.trace_add("write",lambda *args:self.filter_signals())
        ttk.Entry(sidebar,textvariable=self.search,width=29).pack(fill="x",pady=5)
        self.signals=tk.Listbox(sidebar,selectmode="extended",exportselection=False,width=30,bg="#131f2e",fg="#d8e4f0",selectbackground="#52657d",relief="flat")
        self.signals.pack(fill="both",expand=True,pady=5); self.signals.bind("<Double-Button-1>",lambda e:self.add_signals())
        ttk.Button(sidebar,text="Add selected to plot",command=self.add_signals).pack(fill="x",pady=5)
        ttk.Button(sidebar,text="New blank plot",command=self.new_plot).pack(fill="x",pady=5)
        self.explorer=ttk.Notebook(page); self.explorer.pack(side="left",fill="both",expand=True); self.new_plot()
    def new_plot(self):
        self.custom_count+=1; p=Plot(self.explorer,f"Custom plot {self.custom_count}"); self.explorer.add(p,text=f"Plot {self.custom_count}"); self.explorer.select(p)
    def get_path(self,source,path):
        value=source
        for key in path.split("."): value=value[int(key)] if isinstance(value,list) else value[key]
        return value
    def set_path(self,source,path,value):
        keys=path.split("."); target=source
        for key in keys[:-1]: target=target[int(key)] if isinstance(target,list) else target[key]
        key=int(keys[-1]) if isinstance(target,list) else keys[-1]; target[key]=value
    def _legacy_populate(self):
        for path,var in self.fields.items():
            value=self.get_path(self.case,path)
            var.set(", ".join(f"{x:g}" for x in value) if isinstance(value,list) else value)
        for name,var in self.fw_fields.items(): var.set(runner.fw_value(self.case,name) or "0")
        self.cli.delete("1.0","end"); self.cli.insert("1.0",self.case["firmware_cli"])
        self.last_setting_page=self.settings_tabs.select()
    def _legacy_collect(self):
        case=copy.deepcopy(self.case)
        case["firmware_cli"]=self.cli.get("1.0","end-1c")
        if self.settings_tabs.tab(self.settings_tabs.select(),"text")=="Firmware CLI":
            import configuration
            case["profiles"]=configuration.selected_profiles(case["firmware_cli"])
            for name,var in self.fw_fields.items(): var.set(runner.fw_value(case,name) or "0")
        for path,var in self.fields.items():
            prior=self.get_path(case,path); value=var.get()
            try:
                if isinstance(prior,list): value=[float(x.strip()) for x in value.split(",")]
                elif isinstance(prior,bool): value=bool(value)
                elif isinstance(prior,(int,float)): value=float(value)
            except ValueError as e: raise ValueError(f"Invalid value for {path}: {value}") from e
            self.set_path(case,path,value)
        for name,var in self.fw_fields.items():
            runner.set_fw(case,name,var.get())
        return case
    def sync_cli(self,event=None):
        if not hasattr(self,"cli") or not hasattr(self,"last_setting_page"): return
        current=self.settings_tabs.select(); title=self.settings_tabs.tab(current,"text")
        if current==self.last_setting_page: return
        previous=self.settings_tabs.tab(self.last_setting_page,"text")
        if previous=="Firmware CLI" and title!="Firmware CLI":
            temp={"firmware_cli":self.cli.get("1.0","end-1c")}
            import configuration
            self.case["profiles"]=configuration.selected_profiles(temp["firmware_cli"])
            if hasattr(self,"profile_vars"):
                for scope,variable in self.profile_vars.items(): variable.set(str(self.case["profiles"][scope]))
            for name,var in self.fw_fields.items(): var.set(runner.fw_value(temp,name) or "0")
        if title=="Firmware CLI":
            temp={"firmware_cli":self.cli.get("1.0","end-1c"),"profiles":self.case["profiles"]}
            for name,var in self.fw_fields.items(): runner.set_fw(temp,name,var.get())
            self.cli.delete("1.0","end"); self.cli.insert("1.0",temp["firmware_cli"])
        self.last_setting_page=current
    def preset(self,name):
        self.case=runner.load_case(runner.ROOT/"presets"/name); self.populate()
    def save(self):
        try:
            self.sync_cli(); case=self.collect()
            path=filedialog.asksaveasfilename(defaultextension=".json",filetypes=[("SIL settings","*.json")])
            if path: Path(path).write_text(json.dumps(case,indent=2)+"\n",encoding="utf-8"); self.case=case
        except Exception as e: messagebox.showerror("Settings",str(e))
    def load(self):
        path=filedialog.askopenfilename(filetypes=[("SIL settings","*.json")])
        if path: self.load_settings_path(path)
    def load_settings_path(self,path):
        try: self.case=runner.load_case(path); self.populate()
        except Exception as e: messagebox.showerror("Load settings",str(e))
    def run(self):
        if self.running: return
        try: self.sync_cli(); self.case=self.collect()
        except Exception as e: messagebox.showerror("Check settings",str(e)); return
        self.running=True; self.folder=None; self.process=None; self.paused=False; self.stop_requested=False; self.progress["value"]=0
        self.run_button.configure(state="disabled"); self.stop_button.configure(state="normal"); self.pause_button.configure(state="normal",text="Pause")
        self.status.set("Preparing native firmware…")
        case=copy.deepcopy(self.case)
        self.run_case=case
        def worker():
            try:
                folder=runner.execute(case,progress=lambda kind,value:self.events.put((kind,value)))
                self.events.put(("done",folder))
            except Exception as e: self.events.put(("error",str(e)))
        threading.Thread(target=worker,daemon=True).start()
    def pause(self):
        if self.folder and self.running:
            self.paused=not self.paused; path=self.folder/"pause"
            if self.paused: path.touch(); self.status.set("Paused")
            else: path.unlink(missing_ok=True); self.status.set("Running")
            self.pause_button.configure(text="Resume" if self.paused else "Pause")
    def stop(self):
        if self.running: self.stop_requested=True
        if self.folder: (self.folder/"stop").touch(); (self.folder/"pause").unlink(missing_ok=True)
    def poll(self):
        try:
            while True:
                kind,value=self.events.get_nowait()
                if kind=="folder":
                    self.folder=value
                    if self.stop_requested: self.stop()
                elif kind=="process": self.process=value
                elif kind=="status":
                    if " TIME " in value:
                        t=float(value.split()[-1]); self.progress["value"]=100*t/self.run_case["duration"]
                        if not self.paused: self.status.set(f"Flight time {t:.2f} / {self.run_case['duration']:g} s")
                        if self.run_case["realtime"] and not self.preview_pending and self.folder and not self.closing:
                            self.preview_pending=True; self.read_data(self.folder,preview=True)
                    else: self.status.set(value.replace("[DESKTOP] ",""))
                elif kind in ("done","error"):
                    self.running=False; self.process=None; self.run_button.configure(state="normal")
                    self.pause_button.configure(state="disabled"); self.stop_button.configure(state="disabled")
                    self.refresh_runs()
                    if kind=="error":
                        self.status.set("Run failed — see the saved logs")
                        if not self.closing: messagebox.showerror("Simulation",value)
                    else:
                        summary=json.loads((value/"engine_summary.json").read_text())
                        metadata=json.loads((value/"metadata.json").read_text())
                        self.status.set(f"{'Stopped' if summary['stopped'] else 'Complete'} • {summary['simulation_seconds']:g} s flight • {metadata.get('application_wall_seconds',summary['total_wall_seconds']):.2f} s total • engine {summary['speed_ratio']:.1f}× real time")
                        if (value/"signals.h5").exists() and not self.closing: self.read_data(value)
                elif kind=="data":
                    folder,data,preview=value
                    if preview:
                        self.preview_pending=False
                        if not self.running or folder!=self.folder: continue
                    self.set_data(folder,data)
                elif kind=="read_error":
                    self.preview_pending=False
                    if value and not self.closing: messagebox.showerror("Open signals",value)
        except queue.Empty: pass
        if self.closing and not self.running: self.destroy(); return
        self.after(100,self.poll)
    def _legacy_read_data(self,folder,preview=False):
        def worker():
            try:
                # Ignore a partial final line while a run is writing.
                with (Path(folder)/"signals.csv").open("rb") as f: blob=f.read()
                blob=blob[:blob.rfind(b"\n")+1]
                import io
                data=np.genfromtxt(io.BytesIO(blob),delimiter=",",names=True)
                data=np.atleast_1d(data)
                if len(data)<2: raise ValueError("No flight samples yet.")
                self.events.put(("data",(folder,data,preview)))
            except Exception as e: self.events.put(("read_error","" if preview else str(e)))
        threading.Thread(target=worker,daemon=True).start()
    def _legacy_set_data(self,folder,data):
        self.data=data; self.data_folder=Path(folder)
        for title,names in self.groups.items():
            series=[]
            for name in names:
                label,values=display_signal(name,data[name]); series.append((label,data["time_s"],values))
            self.default_plots[title].replace(series)
        self.filter_signals()
    def _legacy_filter_signals(self):
        if not hasattr(self,"signals"): return
        self.signals.delete(0,"end")
        if self.data is not None:
            for name in self.data.dtype.names[1:]:
                if self.search.get().lower() in name.lower(): self.signals.insert("end",name)
    def _legacy_add_signals(self):
        if self.data is None: return
        plot=self.explorer.nametowidget(self.explorer.select())
        for index in self.signals.curselection():
            name=self.signals.get(index); label,y=display_signal(name,self.data[name]); plot.add(self.data_folder.name+" / "+label,self.data["time_s"],y)
    def _legacy_refresh_runs(self):
        self.run_paths=sorted((runner.ROOT/"runs").glob("*/settings.json"),reverse=True)
        if hasattr(self,"runs"):
            self.runs.delete(0,"end")
            for path in self.run_paths:
                try:
                    c=json.loads(path.read_text()); self.runs.insert("end",f"{path.parent.name}   {c['name']}   {c['duration']:g} s")
                except (ValueError,OSError): pass
    def open_archive(self):
        if self.runs.curselection(): self.read_data(self.run_paths[self.runs.curselection()[0]].parent)
    def load_archive_settings(self):
        if self.runs.curselection(): self.load_settings_path(self.run_paths[self.runs.curselection()[0]])
    def browse_run(self):
        folder=filedialog.askdirectory(initialdir=runner.ROOT/"runs")
        if folder: self.read_data(Path(folder))
    def close(self):
        self.closing=True; self.stop()
        if not self.running: self.destroy()
        else:
            self.status.set("Stopping the native process…")
            self.after(5000,self.force_close)
    def force_close(self):
        if self.process and self.process.poll() is None: self.process.terminate()
        if not self.running: self.destroy()

if __name__=="__main__":
    App().mainloop()
