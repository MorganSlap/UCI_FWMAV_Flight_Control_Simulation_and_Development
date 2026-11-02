"""Workbench configuration, run-library and analysis features for the native UI."""
import copy
import json
from pathlib import Path
import subprocess
import threading
import tkinter as tk
from tkinter import ttk,filedialog,messagebox
import numpy as np
import configuration as cfg
import storage
from analysis import flight_analysis
from plots import Plot,export_panels

class ParityFeatures:
    def enhance(self):
        self.preferences=cfg.ROOT/"preferences.json"
        prefs=storage.read_json(self.preferences)
        self.data_root=Path(prefs.get("storage_root",cfg.ROOT/"runs"))
        self.load_generation=0; self._populate_busy=False
        self.field(self.run_box,11,"Dynamics fidelity","fidelity",choices=("high","low"))
        self.check(self.run_box,12,"Show default plots after loading runs","default_plots")
        self.field(self.run_box,13,"Run notes","notes")
        self.field(self.run_box,14,"ODE5 integration rate (Hz)","plant_hz",choices=("16000","32000","64000"))
        casebar=self.run_page.winfo_children()[0]
        ttk.Button(casebar,text="Angle pulses",command=lambda:self.catalog_preset("angle")).pack(side="left",padx=6)
        ttk.Button(casebar,text="Rate doublets",command=lambda:self.catalog_preset("rate")).pack(side="left",padx=6)
        ttk.Button(casebar,text="Script defaults",command=lambda:self.catalog_preset("script_defaults")).pack(side="left",padx=6)
        commands=self.section(self.run_page,"Command sequence — held until the next row")
        ttk.Label(commands,text="Rows: time (s), roll, pitch, yaw rate. ANGLE: deg, deg, deg/s. RATE: deg/s. Before the first row, constant reference applies.",style="Muted.TLabel").pack(anchor="w",pady=4)
        self.sequence=tk.Text(commands,height=7,bg="#121d2b",fg="#e2e9f2",insertbackground="white",font=("Consolas",11))
        self.sequence.pack(fill="x")
        row=ttk.Frame(commands); row.pack(fill="x",pady=6)
        ttk.Button(row,text="Add row",command=self.add_command).pack(side="left")
        ttk.Button(row,text="Remove last",command=self.remove_command).pack(side="left",padx=6)
        ttk.Button(row,text="Use constant reference",command=lambda:self.sequence.delete("1.0","end")).pack(side="left")
        self.full_pid(); self.full_sensors(); self.full_plant(); self.interface_page(); self.receiver_page()
        self.catalog_page(); self.command_sections_page(); self.derived_page()
        self.noise_text=tk.StringVar(value="Noise ON")
        ttk.Checkbutton(self.run_toolbar,textvariable=self.noise_text,variable=self.fields["noise"]).pack(side="right",padx=8)
        self.fields["noise"].trace_add("write",lambda *a:self.noise_text.set("Noise ON" if self.fields["noise"].get() else "Noise OFF"))
        self.fields["default_plots"].trace_add("write",lambda *a:self.show_default() if hasattr(self,"default_choice") else None)
        # A sidebar keeps every settings page reachable at ordinary window sizes.
        self.settings_tabs.configure(style="Sidebar.TNotebook")
        ttk.Style(self).layout("Sidebar.TNotebook.Tab",[])
        parent=self.settings_tabs.master
        sidebar=ttk.Frame(parent,padding=(8,12)); sidebar.pack(side="left",fill="y",before=self.settings_tabs)
        self.settings_tabs.pack_configure(side="left")
        self.setting_search=tk.StringVar(); self.setting_search.trace_add("write",lambda *a:self.search_settings())
        ttk.Label(sidebar,text="FIND A SETTING",style="Subhead.TLabel").pack(anchor="w",pady=(0,6))
        ttk.Entry(sidebar,textvariable=self.setting_search,width=25).pack(fill="x",pady=(0,8))
        self.settings_nav=tk.Listbox(sidebar,width=25,exportselection=False,bg="#152131",fg="#e2e9f2",selectbackground="#4a607a",relief="flat",font=("Segoe UI",10))
        self.settings_nav.pack(fill="both",expand=True)
        self.settings_nav.bind("<<ListboxSelect>>",self.navigate_settings)
        self.settings_tabs.bind("<<NotebookTabChanged>>",self.settings_changed,add="+")
        self.search_settings()
        self.default_views(); self.analysis_page()
        self.pages.bind("<<NotebookTabChanged>>",lambda e:self.show_default() if self.pages.index(self.pages.select())==1 else None,add="+")
        self.protocol("WM_DELETE_WINDOW",self.close)
        self.bind("<Control-f>",lambda e:self.setting_search_focus())

    def clear_page(self,title):
        page=self.setting_bodies[title]
        for child in page.winfo_children(): child.destroy()
        return page

    def full_pid(self):
        page=self.clear_page("PID / angle control")
        box=self.section(page,"Active native profiles")
        self.profile_vars={}
        for i,(scope,label,count) in enumerate((("profile","PID profile",3),("rateprofile","Rate profile",6),("battery_profile","Battery profile",3))):
            ttk.Label(box,text=label).grid(row=i,column=0,sticky="w",padx=(0,18),pady=4)
            variable=tk.StringVar(); self.profile_vars[scope]=variable
            control=ttk.Combobox(box,textvariable=variable,values=list(range(count)),state="readonly",width=20)
            control.grid(row=i,column=1,sticky="w",pady=4); control.bind("<<ComboboxSelected>>",lambda e,s=scope:self.select_profile(s))
        box=self.section(page,"Rate-controller gains — selected PID profile")
        for j,label in enumerate(("Axis","P","I","D","Feedforward")): ttk.Label(box,text=label).grid(row=0,column=j,padx=12,pady=6)
        for i,axis in enumerate(("roll","pitch","yaw"),1):
            ttk.Label(box,text=axis.title()).grid(row=i,column=0,padx=12)
            for j,term in enumerate("pidf",1):
                name=f"{term}_{axis}"; var=tk.StringVar(); self.fw_fields[name]=var
                control=ttk.Entry(box,textvariable=var,width=10); control.grid(row=i,column=j,padx=10,pady=5)
                self.field_widgets["firmware."+name]=(control,f"{axis} {term.upper()} gain")
        box=self.section(page,"Angle control and tuning mode")
        for i,(name,label) in enumerate((("angle_p_gain","Angle P gain"),("angle_limit","Angle limit (deg)"),("simplified_pids_mode","Simplified PID tuning"))): self.firmware_field(box,i,name,label)
        ttk.Label(page,text="Native menu values are applied to the selected profile. Simplified tuning can recalculate manual gains.\nUse the firmware catalog for all PID, I-term, feedforward and rate-profile settings.",style="Muted.TLabel").pack(anchor="w",pady=10)

    def firmware_field(self,parent,row,name,label=None):
        item=cfg.BY_NAME[name]
        self.field(parent,row,label or name.replace("_"," "),name,choices=item["Choices"] if item["Type"]=="choice" else None,firmware=True)

    def full_sensors(self):
        page=self.clear_page("Gyro / accelerometer")
        for sensor,title,units in (("gyro","GYROSCOPE","deg/s"),("accel","ACCELEROMETER","g")):
            box=self.section(page,title)
            fields=[("sample_rate","Sensor sample rate (Hz)"),("range","Sensor range (deg/s)" if sensor=="gyro" else "Sensor range (g)"),("resolution_bits","Resolution metadata (bits)"),("density",f"Noise density ({units}/√Hz)"),("bandwidth","Noise bandwidth (Hz)"),("bias",f"Bias X, Y, Z ({units})"),("vibration",f"24 Hz wing vibration ({units})")]
            for i,(key,label) in enumerate(fields): self.field(box,i,label,sensor+"."+key)
            names=("simplified_gyro_filter","gyro_lpf1_type","gyro_lpf1_static_hz","gyro_lpf1_dyn_min_hz","gyro_lpf1_dyn_max_hz","gyro_lpf2_static_hz","gyro_calib_noise_limit") if sensor=="gyro" else ("acc_lpf_hz",)
            for row,name in enumerate(names,len(fields)): self.firmware_field(box,row,name)
        box=self.section(page,"Attitude estimator — native Mahony gains")
        self.field(box,0,"Physical proportional gain Kp","estimator_kp")
        self.field(box,1,"Physical integral gain Ki","estimator_ki")
        ttk.Label(page,text="Kp and Ki are multiplied by 10000 for the native firmware. Resolution fields are retained from MATLAB;\nvirtual firmware ADC quantization is fixed by the SITL drivers. White-noise power is density² × bandwidth, without dividing by sample rate.",style="Muted.TLabel").pack(anchor="w",pady=10)

    def full_plant(self):
        page=self.clear_page("Physical plant")
        self.fields.pop("plant.inertia",None)
        box=self.section(page,"Airframe, atmosphere and actuators")
        fields=(("m","Vehicle mass (kg)"),("S","Thrust moment arm (m)"),("wing_type","Wing size product (in²)"),("C11","Thrust slope C11 (N/pot)"),("C21","Thrust intercept C21 (N)"),("tau_wing","Actuator time constant (s)"),("k_tau","Yaw effectiveness — linear plant only (N m/pot)"),("g","Gravity (m/s²)"),("rho","Air density (kg/m³)"))
        for i,(key,label) in enumerate(fields): self.field(box,i,label,"plant."+key)
        inertia=self.section(page,"Body inertia tensor (kg m²) — original plants use its diagonal")
        for i in range(3):
            for j in range(3):
                var=tk.StringVar(); path=f"plant.tensor.{i}.{j}"; self.fields[path]=var
                control=ttk.Entry(inertia,textvariable=var,width=18); control.grid(row=i,column=j,padx=6,pady=5)
                self.field_widgets[path]=(control,f"Inertia tensor {i+1},{j+1}")
        box=self.section(page,"Aerodynamic reference speeds and rates")
        for i,(key,label) in enumerate((("v_ref","Horizontal reference speed (m/s)"),("w_ref","Vertical reference speed (m/s)"),("p_ref","Roll reference rate (deg/s)"),("q_ref","Pitch reference rate (deg/s)"),("r_ref","Yaw reference rate (deg/s)"))): self.field(box,i,label,"plant."+key)
        box=self.section(page,"Drag coefficients and effective areas")
        for i,key in enumerate(("CDx","CDy","CDz","CDw")): self.field(box,i,key,"plant."+key)
        self.field(box,4,"Area parameterization","plant.area_mode",choices=("wing factors","direct"))
        for i,key in enumerate(("AxFactor","AyFactor","AzFactor","AomegaFactor","Ax","Ay","Az","Aomega"),5): self.field(box,i,key+(" / Aref" if key.endswith("Factor") else " (m²; direct mode)"),"plant."+key)
        ttk.Label(page,text="Reference speeds set linearized drag. The nonlinear plant retains quadratic drag. Disable all drag on Run setup.\nWing-factor mode recalculates areas when wing size changes. The nonlinear plant has no modeled yaw thrust moment.",style="Muted.TLabel").pack(anchor="w",pady=10)
        reference=self.setting_bodies["Initial state / references"]
        extra=self.section(reference,"Remaining reference-state entries — saved but not used by native angle/rate control")
        for i,(index,label) in enumerate(((0,"X (m)"),(1,"Y (m)"),(2,"Z down (m)"),(3,"U (m/s)"),(4,"V (m/s)"),(5,"W (m/s)"),(8,"Yaw heading (deg)"))): self.field(extra,i,label,f"reference.{index}")

    def interface_page(self):
        page=self.setting_page("Firmware interface"); box=self.section(page,"Startup and receiver scheduling")
        for row,(key,label) in enumerate((("rc_hz","Receiver update rate (Hz)"),("warmup","Calibration warmup (s)"),("arm_settle","Arming settle time (s)"),("spoolup","Throttle settling before release (s)"),("motor_order","Plant motor order (1–4)"))): self.field(box,row,label,key)
        self.firmware_field(box,5,"pid_process_denom","PID / mixer divider (1–16; gyro remains 4 kHz)")
        ttk.Label(page,text="Command mode, fixed throttle and known-bias calibration are on Run setup. Native sensor filtering and calibration\nrun inside the original firmware. Every run validates arming, requested mode, motor count and loop periods.",style="Muted.TLabel").pack(anchor="w",pady=10)

    def receiver_page(self):
        page=self.setting_page("Receiver channels"); box=self.section(page,"Receiver pulses (µs)")
        self.check(box,0,"Use custom receiver pulses (otherwise map and AUX ranges generate them)","custom_receiver")
        for j,label in enumerate(("Channel","Calibration / disarmed","Armed / flight")): ttk.Label(box,text=label,style="Subhead.TLabel").grid(row=1,column=j,padx=12,pady=8)
        for i in range(16):
            ttk.Label(box,text=f"CH {i+1}").grid(row=i+2,column=0,padx=12)
            for j,key in enumerate(("receiver_disarmed","receiver_flight"),1):
                variable=tk.StringVar(); path=f"{key}.{i}"; self.fields[path]=variable
                control=ttk.Entry(box,textvariable=variable,width=18); control.grid(row=i+2,column=j,padx=12,pady=3)
                self.field_widgets[path]=(control,f"Channel {i+1} {key}")
        ttk.Button(page,text="Restore automatic channels",command=self.automatic_receiver).pack(anchor="w",pady=8)
        ttk.Label(page,text="Custom flight pulses override the throttle field. Arming uses the flight AUX values with minimum throttle.\nStick pulses apply directly in raw receiver mode; ANGLE/RATE modes generate stick pulses from references.",style="Muted.TLabel").pack(anchor="w")

    def catalog_page(self):
        page=self.setting_page("Firmware catalog")
        ttk.Label(page,text=f"{len(cfg.SCHEMA)} settings from the pinned firmware's CLI catalog",style="Subhead.TLabel").pack(anchor="w")
        bar=ttk.Frame(page); bar.pack(fill="x",pady=8)
        self.catalog_query=tk.StringVar(); self.catalog_query.trace_add("write",lambda *a:self.refresh_catalog())
        ttk.Entry(bar,textvariable=self.catalog_query,width=32).pack(side="left")
        self.catalog_group=tk.StringVar(value="All groups")
        groups=["All groups"]+sorted({s["Group"] for s in cfg.SCHEMA})
        control=ttk.Combobox(bar,textvariable=self.catalog_group,values=groups,state="readonly",width=26); control.pack(side="left",padx=6); control.bind("<<ComboboxSelected>>",lambda e:self.refresh_catalog())
        ttk.Button(bar,text="Import CLI / JSON…",command=self.import_firmware).pack(side="left",padx=4)
        ttk.Button(bar,text="Export CLI / JSON…",command=self.export_firmware).pack(side="left",padx=4)
        self.catalog_tree=ttk.Treeview(page,columns=("value","scope","constraint"),show="tree headings",height=17)
        self.catalog_tree.heading("#0",text="Setting"); self.catalog_tree.column("#0",width=230)
        for name,width in (("value",130),("scope",100),("constraint",330)): self.catalog_tree.heading(name,text=name.title()); self.catalog_tree.column(name,width=width)
        self.catalog_tree.pack(fill="both",expand=True); self.catalog_tree.bind("<<TreeviewSelect>>",self.catalog_selected)
        self.catalog_help=tk.StringVar(value="Select a setting. Profile selection is shared with the PID page.")
        ttk.Label(page,textvariable=self.catalog_help,wraplength=950).pack(anchor="w",pady=8)
        editor=ttk.Frame(page); editor.pack(fill="x")
        self.catalog_edit=tk.StringVar(); self.catalog_control=ttk.Combobox(editor,textvariable=self.catalog_edit,width=45); self.catalog_control.pack(side="left")
        ttk.Button(editor,text="Apply setting",command=self.apply_catalog).pack(side="left",padx=8)
        ttk.Label(page,text="Receiver map, ranges, failsafe, AUX modes, adjustments, features and mixer commands are editable in Complete CLI.\nThe real firmware validates the complete configuration before a run. Unsupported hardware remains outside the simulated plant.",style="Muted.TLabel").pack(anchor="w",pady=12)

    def command_sections_page(self):
        page=self.setting_page("Receiver / modes / mixer")
        self.command_sections={"Receiver map, ranges and failsafe":("map","rxrange","rxfail"),"AUX modes and adjustments":("aux","adjrange"),"Motor and servo mixer":("mixer","mmix","smix","servo"),"Features":("feature",)}
        self.command_section=tk.StringVar(value=next(iter(self.command_sections)))
        selector=ttk.Combobox(page,textvariable=self.command_section,values=list(self.command_sections),width=42,state="readonly")
        selector.pack(anchor="w",pady=8); selector.bind("<<ComboboxSelected>>",lambda e:self.show_command_section())
        ttk.Label(page,text="These are native CLI commands. Receiver mapping and AUX ranges also drive automatic startup-channel generation.\nApply this section to update the complete CLI document; the firmware checks its syntax before running.",style="Muted.TLabel").pack(anchor="w",pady=8)
        self.command_text=tk.Text(page,height=24,bg="#121d2b",fg="#dce5ef",insertbackground="white",font=("Consolas",11),wrap="none")
        self.command_text.pack(fill="both",expand=True)
        buttons=ttk.Frame(page); buttons.pack(fill="x",pady=8)
        ttk.Button(buttons,text="Apply section",command=self.apply_command_section).pack(side="left")
        ttk.Button(buttons,text="Reload from complete CLI",command=self.show_command_section).pack(side="left",padx=8)

    def show_command_section(self):
        if not hasattr(self,"command_text"): return
        prefixes=self.command_sections[self.command_section.get()]
        lines=[line for line in self.cli.get("1.0","end-1c").splitlines() if line.split() and line.split()[0] in prefixes]
        self.command_text.delete("1.0","end"); self.command_text.insert("1.0","\n".join(lines))

    def apply_command_section(self):
        try:
            case=self.collect(); prefixes=self.command_sections[self.command_section.get()]
            replacement=self.command_text.get("1.0","end-1c").splitlines()
            if any(line.strip() and not line.lstrip().startswith("#") and line.split()[0] not in prefixes for line in replacement): raise ValueError("This section only accepts: "+", ".join(prefixes))
            lines=[]; inserted=False
            for line in case["firmware_cli"].splitlines():
                if line.split() and line.split()[0] in prefixes:
                    if not inserted: lines.extend(replacement); inserted=True
                else: lines.append(line)
            if not inserted: lines.extend(replacement)
            case["firmware_cli"]="\n".join(lines)+"\n"; self.case=case; self.populate()
        except Exception as e: messagebox.showerror("CLI commands",str(e))

    def derived_page(self):
        page=self.setting_page("Derived values")
        ttk.Button(page,text="Recalculate",command=self.refresh_derived).pack(anchor="w",pady=6)
        self.derived_text=tk.Text(page,height=35,bg="#121d2b",fg="#dce5ef",font=("Consolas",10),wrap="none")
        self.derived_text.pack(fill="both",expand=True)

    def populate(self):
        self._populate_busy=True
        self.case=cfg.upgrade(self.case)
        self.case["estimator_kp"]=float(cfg.firmware_value(self.case,"imu_dcm_kp"))/10000
        self.case["estimator_ki"]=float(cfg.firmware_value(self.case,"imu_dcm_ki"))/10000
        if not self.case["custom_receiver"]:
            try:
                channels=cfg.receiver_channels(self.case)
                self.case["receiver_disarmed"]=channels["rc_disarmed"]; self.case["receiver_flight"]=channels["rc_flight"]
            except ValueError: pass
        self._legacy_populate()
        for key,var in self.profile_vars.items(): var.set(str(self.case["profiles"][key]))
        self.sequence.delete("1.0","end")
        self.sequence.insert("1.0","\n".join(", ".join(f"{x:g}" for x in row) for row in self.case["schedule"]))
        self.refresh_catalog(); self.show_command_section(); self._populate_busy=False

    def collect(self):
        case=self._legacy_collect()
        lines=self.sequence.get("1.0","end").strip().splitlines(); sequence=[]
        for line in lines:
            if line.strip(): sequence.append([float(x) for x in line.replace(","," ").split()])
        case["schedule"]=sequence
        case["storage_root"]=str(self.data_root)
        if self.settings_tabs.tab(self.settings_tabs.select(),"text")!="Firmware CLI":
            for key,name in (("estimator_kp","imu_dcm_kp"),("estimator_ki","imu_dcm_ki")): cfg.set_firmware(case,name,str(round(case[key]*10000)))
        import runner
        runner.validate(case)
        return case

    def catalog_preset(self,kind):
        file=cfg.ROOT/"catalog"/("script_defaults.json" if kind=="script_defaults" else kind+"_settings.json")
        self.case=cfg.from_matlab(json.loads(file.read_text()))
        self.case["name"]={"hover":"Noisy trimmed hover","recovery":"Noisy attitude recovery","angle":"Angle pulses","rate":"Rate doublets","script_defaults":"Script defaults"}[kind]
        self.populate()
    def add_command(self):
        lines=self.sequence.get("1.0","end").strip().splitlines()
        try: t=float(lines[-1].replace(","," ").split()[0])+1 if lines else 0
        except ValueError: t=0
        self.sequence.insert("end",("\n" if lines else "")+f"{t:g}, 0, 0, 0")
    def remove_command(self):
        lines=self.sequence.get("1.0","end").strip().splitlines()[:-1]; self.sequence.delete("1.0","end"); self.sequence.insert("1.0","\n".join(lines))
    def automatic_receiver(self):
        try: self.case=self.collect(); self.case["custom_receiver"]=False; self.populate()
        except Exception as e: messagebox.showerror("Receiver",str(e))
    def select_profile(self,scope):
        if self._populate_busy: return
        try:
            chosen=int(self.profile_vars[scope].get()); self.case=self.collect(); self.case["profiles"][scope]=chosen
            self.case["firmware_cli"]+=f"\n{scope} {chosen}\n"; self.populate()
        except Exception as e: messagebox.showerror("Profile",str(e))
    def settings_changed(self,event=None):
        if not hasattr(self,"settings_nav"): return
        current=self.settings_tabs.select()
        if current in self.nav_tabs:
            index=self.nav_tabs.index(current); self.settings_nav.selection_clear(0,"end"); self.settings_nav.selection_set(index)
        title=self.settings_tabs.tab(current,"text")
        if title=="Derived values": self.refresh_derived()
        if title=="Firmware catalog": self.refresh_catalog()
        if title=="Receiver / modes / mixer": self.show_command_section()
        if title=="Gyro / accelerometer" and hasattr(self,"cli"):
            text={"firmware_cli":self.cli.get("1.0","end-1c"),"profiles":self.case["profiles"]}
            for key,name in (("estimator_kp","imu_dcm_kp"),("estimator_ki","imu_dcm_ki")): self.fields[key].set(float(cfg.firmware_value(text,name))/10000)
    def search_settings(self):
        if not hasattr(self,"settings_nav"): return
        query=self.setting_search.get().lower(); self.settings_nav.delete(0,"end"); self.nav_tabs=[]
        for tab in self.settings_tabs.tabs():
            title=self.settings_tabs.tab(tab,"text"); matches=query in title.lower()
            for key,(widget,label) in self.field_widgets.items():
                if not widget.winfo_exists(): continue
                if str(widget).startswith(str(tab)+".") and (query in key.lower() or query in label.lower()): matches=True
            if title=="Firmware catalog" and any(query in item["Name"].lower() for item in cfg.SCHEMA): matches=True
            if matches or not query: self.nav_tabs.append(tab); self.settings_nav.insert("end",title)
    def navigate_settings(self,event=None):
        indices=self.settings_nav.curselection()
        if indices: self.settings_tabs.select(self.nav_tabs[indices[0]])
    def setting_search_focus(self): self.pages.select(0); self.focus_set()
    def refresh_derived(self):
        try:
            value=cfg.derived(self.collect()); text=json.dumps(value,indent=2)
        except Exception as e: text="Cannot calculate: "+str(e)
        self.derived_text.configure(state="normal"); self.derived_text.delete("1.0","end"); self.derived_text.insert("1.0",text); self.derived_text.configure(state="disabled")
    def refresh_catalog(self):
        if not hasattr(self,"catalog_tree"): return
        self.catalog_tree.delete(*self.catalog_tree.get_children())
        case=copy.deepcopy(self.case)
        if hasattr(self,"cli"): case["firmware_cli"]=self.cli.get("1.0","end-1c")
        query=self.catalog_query.get().lower(); group=self.catalog_group.get()
        for item in cfg.SCHEMA:
            if query not in item["Name"].lower() or (group!="All groups" and item["Group"]!=group): continue
            self.catalog_tree.insert("","end",iid=item["Name"],text=item["Name"],values=(cfg.firmware_value(case,item["Name"]),item["Scope"],item["Constraint"]))
    def catalog_selected(self,event=None):
        selected=self.catalog_tree.selection()
        if not selected: return
        name=selected[0]; item=cfg.BY_NAME[name]
        self.catalog_edit.set(self.catalog_tree.item(name,"values")[0])
        self.catalog_control.configure(values=item["Choices"],state="readonly" if item["Type"]=="choice" else "normal")
        self.catalog_help.set(f"{name} • {item['Scope']} • {item['Constraint']} • Default: {item['Default']}")
    def apply_catalog(self):
        selected=self.catalog_tree.selection()
        if not selected: return
        try:
            self.case=self.collect(); cfg.set_firmware(self.case,selected[0],self.catalog_edit.get()); self.populate()
        except Exception as e: messagebox.showerror("Firmware setting",str(e))
    def import_firmware(self):
        path=filedialog.askopenfilename(filetypes=[("Firmware config","*.cli *.txt *.json")])
        if not path: return
        try:
            case=self.collect(); text=Path(path).read_text(encoding="utf-8-sig")
            if Path(path).suffix.lower()==".json":
                payload=json.loads(text); payload=payload.get("Configuration",payload)
                if "Settings" in payload: payload=payload["Settings"]["Betaflight"]
                text=payload.get("CLI",payload.get("firmware_cli"))
                if not isinstance(text,str): raise ValueError("No CLI document found.")
            case["firmware_cli"]=text; case["profiles"]=cfg.selected_profiles(text); self.case=case; self.populate()
        except Exception as e: messagebox.showerror("Import firmware",str(e))
    def export_firmware(self):
        path=filedialog.asksaveasfilename(defaultextension=".cli",filetypes=[("CLI","*.cli"),("JSON","*.json")])
        if not path: return
        try:
            case=self.collect(); text=case["firmware_cli"]+"\n"+"\n".join(f"{k} {v}" for k,v in case["profiles"].items())+"\n"
            Path(path).write_text(json.dumps({"CLI":text,"FirmwareCommit":case["firmware_commit"]},indent=2) if Path(path).suffix==".json" else text,encoding="utf-8")
        except Exception as e: messagebox.showerror("Export firmware",str(e))

    def explorer_page(self):
        page=ttk.Frame(self.pages,padding=8); self.pages.add(page,text="  Explore signals  ")
        sidebar=ttk.Frame(page,padding=8); sidebar.pack(side="left",fill="y")
        ttk.Button(sidebar,text="Open native / MATLAB run…",command=self.browse_run).pack(fill="x",pady=4)
        ttk.Button(sidebar,text="Results library…",command=self.choose_library).pack(fill="x",pady=4)
        self.search=tk.StringVar(); self.search.trace_add("write",lambda *a:self.filter_signals())
        ttk.Entry(sidebar,textvariable=self.search,width=30).pack(fill="x",pady=4)
        self.signal_group=tk.StringVar(value="All groups")
        self.signal_group_control=ttk.Combobox(sidebar,textvariable=self.signal_group,values=["All groups"],state="readonly",width=28)
        self.signal_group_control.pack(fill="x",pady=4); self.signal_group_control.bind("<<ComboboxSelected>>",lambda e:self.filter_signals())
        self.angular_plot_units=tk.StringVar(value="Degrees")
        ttk.Combobox(sidebar,textvariable=self.angular_plot_units,values=("Degrees","Stored units"),state="readonly",width=28).pack(fill="x",pady=4)
        self.signals=tk.Listbox(sidebar,selectmode="extended",exportselection=False,width=33,bg="#131f2e",fg="#d8e4f0",selectbackground="#52657d",relief="flat")
        self.signals.pack(fill="both",expand=True,pady=4); self.signals.bind("<Double-Button-1>",lambda e:self.add_signals())
        ttk.Button(sidebar,text="Plot selected signals",command=self.add_signals).pack(fill="x",pady=4)
        ttk.Button(sidebar,text="Export selected CSV…",command=self.export_signal_csv).pack(fill="x",pady=4)
        ttk.Button(sidebar,text="Export MATLAB workspace…",command=self.export_workspace).pack(fill="x",pady=4)
        ttk.Button(sidebar,text="Open signals in MATLAB",command=self.to_matlab_workspace).pack(fill="x",pady=4)
        ttk.Button(sidebar,text="Use this run's settings",command=self.use_record_settings).pack(fill="x",pady=4)
        main=ttk.Frame(page); main.pack(side="left",fill="both",expand=True)
        tools=ttk.Frame(main); tools.pack(fill="x",pady=5)
        self.plot_mode=tk.StringVar(value="Overlay on active plot")
        ttk.Combobox(tools,textvariable=self.plot_mode,values=("Overlay on active plot","Replace active plot","Create a new plot"),state="readonly",width=25).pack(side="left")
        ttk.Button(tools,text="New plot",command=self.new_plot).pack(side="left",padx=4)
        ttk.Button(tools,text="Clear plot",command=self.clear_plot).pack(side="left",padx=4)
        ttk.Button(tools,text="Close plot",command=self.close_plot).pack(side="left",padx=4)
        self.explorer=ttk.Notebook(main); self.explorer.pack(fill="both",expand=True); self.new_plot()
        details=ttk.Notebook(main); details.pack(fill="x",pady=6)
        self.saved_settings_text=tk.Text(details,height=5,bg="#152131",fg="#ccd8e6",font=("Consolas",9),wrap="none")
        self.saved_metadata_text=tk.Text(details,height=5,bg="#152131",fg="#ccd8e6",font=("Consolas",9),wrap="word")
        details.add(self.saved_settings_text,text="Saved settings"); details.add(self.saved_metadata_text,text="Run details")
        self.explore_hint=tk.StringVar(value="Double-click follows the plot mode. Select another run to overlay comparisons. Signals retain their own time grids.")
        ttk.Label(main,textvariable=self.explore_hint,style="Muted.TLabel",wraplength=850).pack(anchor="w",pady=4)

    def default_views(self):
        page=self.pages.nametowidget(self.pages.tabs()[1])
        for child in page.winfo_children(): child.destroy()
        bar=ttk.Frame(page,padding=8); bar.pack(fill="x")
        self.default_run=tk.StringVar(); self.default_run_control=ttk.Combobox(bar,textvariable=self.default_run,state="readonly",width=38)
        self.default_run_control.pack(side="left",padx=4); self.default_run_control.bind("<<ComboboxSelected>>",lambda e:self.choose_run_label(self.default_run.get()))
        self.default_choice=tk.StringVar(value="True attitude")
        self.groups={"True attitude":["roll_rad","pitch_rad","yaw_rad"],"True angular rates":["p_radps","q_radps","r_radps"],
            "Position / altitude":["x_m","y_m","altitude_m"],"Body velocity":["u_mps","v_mps","w_mps"],
            "Estimated attitude":["estimate_roll_rad","estimate_pitch_rad","estimate_yaw_rad"],"Estimated body rates":["estimate_p_radps","estimate_q_radps","estimate_r_radps"],
            "Filtered gyro into Mahony":[f"filtered_input_{a}_radps" for a in "pqr"],"Filtered accel into Mahony":[f"filtered_input_accel_{a}_mps2" for a in "xyz"],
            "Estimated position":["estimate.x","estimate.y","estimate.z"],"Estimated velocity":["estimate.u","estimate.v","estimate.w"],
            "Attitude estimation errors":["error_roll_rad","error_pitch_rad","error_yaw_rad"],"Rate estimation errors":["error_p_radps","error_q_radps","error_r_radps"],
            "Motor commands":[f"motor{i}_pot" for i in range(1,5)],"Raw gyro":[f"raw_gyro_{a}_radps" for a in "xyz"],"Raw accel":[f"raw_accel_{a}_mps2" for a in "xyz"]}
        choice=ttk.Combobox(bar,textvariable=self.default_choice,values=list(self.groups),state="readonly",width=29)
        choice.pack(side="left",padx=5); choice.bind("<<ComboboxSelected>>",lambda e:self.show_default())
        ttk.Button(bar,text="Full duration",command=lambda:self.default_plots[self.default_choice.get()].home()).pack(side="left",padx=4)
        ttk.Button(bar,text="Undock all",command=self.undock_defaults).pack(side="left",padx=4)
        self.default_description=tk.StringVar()
        ttk.Label(page,textvariable=self.default_description,wraplength=1150,style="Muted.TLabel").pack(anchor="w",padx=12,pady=5)
        self.default_container=ttk.Frame(page); self.default_container.pack(fill="both",expand=True)
        self.default_plots={}
        for title in self.groups: self.default_plots[title]=Plot(self.default_container,title)
        self.show_default()
        ttk.Label(page,text="Position shows altitude = −z. Body velocity w is positive down. Home restores the full saved duration. Display reduction preserves extrema; exports retain original samples.",style="Muted.TLabel").pack(anchor="w",padx=12,pady=6)

    def show_default(self):
        if not hasattr(self,"default_choice"): return
        for plot in self.default_plots.values(): plot.pack_forget()
        plot=self.default_plots[self.default_choice.get()]; plot.pack(fill="both",expand=True)
        if self.data is None: return
        title=self.default_choice.get()
        descriptions={
            "Estimated attitude":"Mahony attitude output from the firmware (0.1° telemetry resolution). This is not a low-pass-filtered truth signal.",
            "Estimated body rates":"Final processed gyro used as the firmware rate estimate/controller feedback. Mahony has no separate angular-rate state; this is distinct from its filtered input below.",
            "Filtered gyro into Mahony":"Exact gyro arguments consumed by Mahony, after firmware filtering/downsampling. Values are held between estimator updates.",
            "Filtered accel into Mahony":"Exact accelerometer arguments consumed by Mahony, after filtering/calibration, converted back to body-FRD specific force (m/s²). Values are held between estimator updates.",
            "Attitude estimation errors":"True plant attitude − Estimated attitude, wrapped to ±180°. This is estimation error, not sensor noise.",
            "Rate estimation errors":"True plant body rate − Estimated firmware body rate. Filtered-input and raw-sensor diagnostics are separate signals.",
            "Raw gyro":"Simulated sensor measurements before Betaflight calibration/filtering; includes bias, white noise, vibration and sampling.",
            "Raw accel":"Simulated accelerometer specific force before Betaflight processing, in body-FRD axes (m/s²)."}
        self.default_description.set(descriptions.get(title,"True state and control signals are recorded directly from the plant and firmware. Angular plots use degrees."))
        if not self.fields["default_plots"].get():
            plot.replace([]); plot.empty_message="Default plots are disabled. Enable them on Run setup. Data and custom plots remain available."; plot.draw(); return
        if title in ("Estimated position","Estimated velocity") and ("matlab_settings" not in self.data.settings or "Betaflight" in self.data.settings.get("matlab_settings",{})):
            plot.replace([]); plot.empty_message="Unavailable: this IMU-only firmware interface does not estimate position or velocity. Reserved zero channels are not measurements."; plot.draw(); return
        plot.empty_message="No matching signals were logged in this run. Exact Mahony input taps are available only in runs made with the updated engine."
        plot.replace([item for key in self.groups[title] if (item:=self.data.series(key))])

    def undock_defaults(self):
        if self.data is None: return
        window=tk.Toplevel(self); window.title("Default plots — "+self.data.folder.name); window.geometry("1150x760")
        notebook=ttk.Notebook(window); notebook.pack(fill="both",expand=True)
        for title,keys in self.groups.items():
            plot=Plot(notebook,title); notebook.add(plot,text=title)
            if title in ("Estimated position","Estimated velocity"):
                plot.empty_message="Position and velocity estimates are unavailable for native IMU-only runs."
            else: plot.replace([item for key in keys if (item:=self.data.series(key))])

    def analysis_page(self):
        page=ttk.Frame(self.pages,padding=8); self.pages.add(page,text="  Flight analysis  ")
        bar=ttk.Frame(page); bar.pack(fill="x",pady=5)
        self.analysis_run=tk.StringVar(); self.analysis_run_control=ttk.Combobox(bar,textvariable=self.analysis_run,state="readonly",width=39)
        self.analysis_run_control.pack(side="left",padx=4); self.analysis_run_control.bind("<<ComboboxSelected>>",lambda e:self.choose_run_label(self.analysis_run.get()))
        self.analysis_axis=tk.StringVar(value="Roll"); control=ttk.Combobox(bar,textvariable=self.analysis_axis,values=("Roll","Pitch","Yaw"),state="readonly",width=10)
        control.pack(side="left",padx=5); control.bind("<<ComboboxSelected>>",lambda e:self.draw_analysis())
        ttk.Button(bar,text="Export all panels…",command=self.export_analysis).pack(side="left",padx=4)
        ttk.Button(bar,text="Undock panels",command=self.undock_analysis).pack(side="left",padx=4)
        self.analysis_summary=tk.StringVar(value="Select a saved run to analyze its commands, response, estimator and PID contributions.")
        ttk.Label(page,textvariable=self.analysis_summary,wraplength=1150,style="Subhead.TLabel").pack(anchor="w",pady=7)
        self.analysis_tabs=ttk.Notebook(page); self.analysis_tabs.pack(fill="both",expand=True)
        self.analysis_plots=[]; self.analysis_notes=[]
        for title in ("Tracking","Feedback","Attitude error","PID contributions","Motor outputs","Raw sensor error","Rate error"):
            frame=ttk.Frame(self.analysis_tabs); self.analysis_tabs.add(frame,text=title)
            note=tk.StringVar(); self.analysis_notes.append(note)
            ttk.Label(frame,textvariable=note,wraplength=1150,style="Muted.TLabel").pack(anchor="w",padx=12,pady=7)
            plot=Plot(frame,title); plot.pack(fill="both",expand=True); self.analysis_plots.append(plot)
        ttk.Label(page,text="RMS values use the whole run, weighted by time, including command transients. Analysis uses saved settings and signals, never unsaved editor values.",style="Muted.TLabel").pack(anchor="w",pady=6)

    def draw_analysis(self):
        if self.data is None: return
        try:
            panels,metrics=flight_analysis(self.data,("Roll","Pitch","Yaw").index(self.analysis_axis.get()))
            self.analysis_panels=panels
            for plot,note,panel in zip(self.analysis_plots,self.analysis_notes,panels):
                note.set(panel["title"]+" — "+panel["description"]); plot.title=panel["title"]
                plot.empty_message="Required signals were not logged in this run."; plot.replace(panel["series"])
            self.analysis_summary.set(f"{self.data.folder.name} | {metrics['mode'].upper()} | {metrics['axis']} tracking RMS {metrics['tracking_rms']:.4g} {metrics['tracking_unit']} | Estimator RMS {metrics['estimator_rms_deg']:.4g} deg\nMotor range {metrics['motor_min']:.3f}–{metrics['motor_max']:.3f} µs / pot")
        except Exception as e: self.analysis_summary.set("Analysis unavailable: "+str(e))
    def export_analysis(self,path=None):
        if not hasattr(self,"analysis_panels"): return
        if path is None: path=filedialog.asksaveasfilename(defaultextension=".pdf",filetypes=[("PDF","*.pdf"),("PNG","*.png")])
        if path: export_panels(self.analysis_panels,path)
    def undock_analysis(self):
        if not hasattr(self,"analysis_panels"): return
        window=tk.Toplevel(self); window.title("Flight analysis — "+self.data.folder.name); window.geometry("1150x760")
        tabs=ttk.Notebook(window); tabs.pack(fill="both",expand=True)
        for panel in self.analysis_panels:
            frame=ttk.Frame(tabs); tabs.add(frame,text=panel["title"])
            ttk.Label(frame,text=panel["description"],wraplength=1050,style="Muted.TLabel").pack(anchor="w",padx=12,pady=8)
            plot=Plot(frame,panel["title"]); plot.pack(fill="both",expand=True); plot.replace(list(panel["series"]))

    def read_data(self,folder,preview=False):
        if not preview: self.load_generation+=1
        generation=self.load_generation
        def worker():
            try:
                record=storage.load_run(folder,preview)
                if not preview and generation!=self.load_generation: return
                self.events.put(("data",(Path(folder),record,preview)))
            except Exception as e: self.events.put(("read_error","" if preview else str(e)))
        threading.Thread(target=worker,daemon=True).start()
    def set_data(self,folder,data):
        self.data=data; self.data_folder=Path(folder)
        for widget,payload in ((self.saved_settings_text,data.settings),(self.saved_metadata_text,data.metadata)):
            widget.configure(state="normal"); widget.delete("1.0","end"); widget.insert("1.0",json.dumps(payload,indent=2,ensure_ascii=False)); widget.configure(state="disabled")
        groups=["All groups"]+sorted({s.group for s in data.signals.values()}); self.signal_group_control.configure(values=groups)
        if self.signal_group.get() not in groups: self.signal_group.set("All groups")
        self.filter_signals(); self.show_default(); self.draw_analysis()
        for label,path in self.run_labels.items():
            if path==self.data_folder: self.default_run.set(label); self.analysis_run.set(label); break
    def filter_signals(self):
        if not hasattr(self,"signals"): return
        self.signals.delete(0,"end"); self.visible_signal_keys=[]
        if self.data is None: return
        query=self.search.get().lower(); group=self.signal_group.get()
        for key,signal in self.data.signals.items():
            if query in (key+" "+signal.label).lower() and (group=="All groups" or signal.group==group):
                self.visible_signal_keys.append(key); self.signals.insert("end",key)
    def selected_signal_keys(self): return [self.visible_signal_keys[i] for i in self.signals.curselection()]
    def add_signals(self):
        if self.data is None: return
        keys=self.selected_signal_keys()
        if not keys: return
        if self.plot_mode.get()=="Create a new plot": self.new_plot()
        plot=self.explorer.nametowidget(self.explorer.select())
        if self.plot_mode.get()=="Replace active plot": plot.replace([])
        for key in keys:
            label,time,values=self.data.series(key,degrees=self.angular_plot_units.get()=="Degrees"); plot.add(self.data_folder.name+" / "+label,time,values)
        units={self.data.signals[key].unit for key in keys}
        self.explore_hint.set("Mixed units share this axis. Use separate plots when scales differ." if len(units)>1 else "Overlay retains traces from other runs. Full duration covers all plotted signals.")
    def clear_plot(self): self.explorer.nametowidget(self.explorer.select()).replace([])
    def close_plot(self):
        plot=self.explorer.nametowidget(self.explorer.select()); self.explorer.forget(plot); plot.destroy()
        if not self.explorer.tabs(): self.new_plot()
    def export_signal_csv(self,folder=None):
        if self.data is None: return
        keys=self.selected_signal_keys()
        if not keys: messagebox.showinfo("Export signals","Select signals in the browser first."); return
        if folder is None: folder=filedialog.askdirectory(title="Export one CSV per selected signal")
        if folder: storage.export_csv(self.data,keys,folder)
    def export_workspace(self,path=None):
        if self.data is None: return
        keys=self.selected_signal_keys() or list(self.data.signals)
        if path is None: path=filedialog.asksaveasfilename(defaultextension=".mat",filetypes=[("MATLAB workspace","*.mat")])
        if not path: return
        helper=storage.export_mat(self.data,keys,path)
        self.status.set("Exported full-resolution hoverSignals and hoverRun; run "+helper.name+" in MATLAB.")
    def use_record_settings(self):
        if self.data is not None: self.case=copy.deepcopy(self.data.settings); self.populate(); self.pages.select(0)
    def to_matlab_workspace(self):
        if self.data is None: return
        try:
            import uuid
            executable=Path(r"C:\Program Files\MATLAB\R2025b\bin\matlab.exe")
            if not executable.exists():
                chosen=filedialog.askopenfilename(title="Select matlab.exe",filetypes=[("MATLAB executable","matlab.exe")])
                if not chosen: return
                executable=Path(chosen)
            folder=self.data.folder/"exports"; folder.mkdir(exist_ok=True)
            helper=storage.export_mat(self.data,self.selected_signal_keys() or list(self.data.signals),folder/("workspace_"+uuid.uuid4().hex[:8]+".mat"))
            command="run('"+str(helper).replace("'","''")+"')"
            subprocess.Popen([str(executable),"-desktop","-r",command])
            self.status.set("Opening a MATLAB desktop with hoverRun and hoverSignals.")
        except Exception as e: messagebox.showerror("MATLAB workspace",str(e))
    def choose_library(self):
        folder=filedialog.askdirectory(initialdir=self.data_root,title="Select native or MATLAB results library")
        if folder:
            self.data_root=Path(folder); self.preferences.write_text(json.dumps({"storage_root":str(self.data_root)},indent=2)+"\n"); self.refresh_runs()
    def refresh_runs(self):
        if not hasattr(self,"data_root"): return
        files=sorted(self.data_root.glob("*/settings.json"),reverse=True)
        self.run_paths=[]; self.run_labels={}
        if hasattr(self,"runs"): self.runs.delete(0,"end")
        for path in files:
            if not any((path.parent/name).exists() for name in ("signals.h5","signals.csv","run.mat")): continue
            try:
                case=cfg.upgrade(storage.read_json(path)); label=f"{path.parent.name} | {case['name']} | {case['duration']:g} s"
                self.run_paths.append(path); self.run_labels[label]=path.parent
                if hasattr(self,"runs"): self.runs.insert("end",label)
            except (ValueError,KeyError,TypeError,OSError): continue
        for control in (getattr(self,"default_run_control",None),getattr(self,"analysis_run_control",None)):
            if control: control.configure(values=list(self.run_labels))
    def choose_run_label(self,label):
        if label in self.run_labels: self.read_data(self.run_labels[label])
