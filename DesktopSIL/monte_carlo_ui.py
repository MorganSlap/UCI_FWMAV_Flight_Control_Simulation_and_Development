"""A separate Monte Carlo workspace; UI callbacks never execute simulations."""
import copy
import json
from pathlib import Path
import queue
import threading
import tkinter as tk
from tkinter import ttk,filedialog,messagebox
from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg,NavigationToolbar2Tk
import monte_carlo as mc
import mc_charts
import storage


class MonteCarloPanel(ttk.Frame):
    def __init__(self,app):
        super().__init__(app.pages,padding=10); self.app=app
        style=ttk.Style(self)
        style.configure('MC.Treeview',background='#121d2b',fieldbackground='#121d2b',foreground='#e2e9f2',rowheight=26)
        style.map('MC.Treeview',background=[('selected','#425b78')],foreground=[('selected','#ffffff')])
        app.pages.add(self,text='  Monte Carlo  ')
        self.design=mc.default_design(app.case); self.folder=None; self.manifest=None; self.payload=None
        self.events=queue.Queue(); self.job=None; self.control=None; self._busy=False; self.chart_pending=False
        self.variables=copy.deepcopy(self.design['variables']); self.criteria=copy.deepcopy(self.design['analysis']['criteria'])
        self.inputs={}; self.root=app.data_root/'monte_carlo'
        context=ttk.Frame(self); context.pack(fill='x',pady=(0,5))
        self.header_toggle=ttk.Button(context,text='Hide study controls',command=self.toggle_study_controls)
        self.header_toggle.pack(side='right',padx=(8,0))
        self.baseline_label=tk.StringVar()
        baseline=ttk.Label(context,textvariable=self.baseline_label,style='Muted.TLabel')
        baseline.pack(side='left',fill='x',expand=True)
        baseline.bind('<Configure>',lambda e:baseline.configure(wraplength=max(250,e.width)))
        self.study_controls=ttk.Frame(self); self.study_controls.pack(fill='x')
        self.study_controls_visible=True
        top=ttk.Frame(self.study_controls); top.pack(fill='x')
        for label,callback in (('Use current settings as baseline',self.capture_baseline),('Save design…',self.save_design),('Load design…',self.load_design),('Open study…',self.open_study)):
            ttk.Button(top,text=label,command=callback).pack(side='left',padx=3)
        controls=ttk.Frame(self.study_controls); controls.pack(fill='x',pady=6)
        self.start_button=ttk.Button(controls,text='Start new study',style='Accent.TButton',command=self.start); self.start_button.pack(side='left')
        self.resume_button=ttk.Button(controls,text='Resume pending',command=self.resume); self.resume_button.pack(side='left',padx=4)
        self.pause_button=ttk.Button(controls,text='Pause',command=self.pause,state='disabled'); self.pause_button.pack(side='left',padx=4)
        self.stop_button=ttk.Button(controls,text='Stop batch',command=self.stop,state='disabled'); self.stop_button.pack(side='left')
        self.retry=tk.BooleanVar(); ttk.Checkbutton(controls,text='Retry failed trials on resume',variable=self.retry).pack(side='left',padx=8)
        self.progress=ttk.Progressbar(self.study_controls,maximum=100); self.progress.pack(fill='x')
        self.status=tk.StringVar(value='Capture your baseline, choose variations, then preview or run.'); ttk.Label(self.study_controls,textvariable=self.status,wraplength=1150).pack(anchor='w',pady=6)
        self.tabs=ttk.Notebook(self); self.tabs.pack(fill='both',expand=True)
        outer=ttk.Frame(self.tabs); self.tabs.add(outer,text='Study design')
        self.design_canvas=tk.Canvas(outer,bg='#202b3b',highlightthickness=0); scroll=ttk.Scrollbar(outer,command=self.design_canvas.yview)
        scroll.pack(side='right',fill='y'); self.design_canvas.pack(side='left',fill='both',expand=True); self.design_canvas.configure(yscrollcommand=scroll.set)
        self.body=ttk.Frame(self.design_canvas,padding=8); window=self.design_canvas.create_window(0,0,window=self.body,anchor='nw')
        self.body.bind('<Configure>',lambda e:self.design_canvas.configure(scrollregion=self.design_canvas.bbox('all')))
        self.design_canvas.bind('<Configure>',lambda e:self.design_canvas.itemconfigure(window,width=e.width))
        app.bind('<MouseWheel>',self.scroll_design,add='+')
        self.build_design(); self.build_trials(); self.build_analysis(); self.populate()
        self.tabs.bind('<<NotebookTabChanged>>',self.analysis_layout)
        self.after_id=self.after(100,self.poll)

    @property
    def busy(self): return self._busy

    def show_study_controls(self,show):
        self.study_controls_visible=show
        if show: self.study_controls.pack(fill='x',before=self.tabs)
        else: self.study_controls.pack_forget()
        self.header_toggle.configure(text='Hide study controls' if show else 'Show study controls')

    def toggle_study_controls(self):
        self.show_study_controls(not self.study_controls_visible)

    def analysis_layout(self,event=None):
        # Give charts the setup controls' space; keep batch controls visible
        # during execution and leave their reveal button available at all times.
        analyzing=self.tabs.select()==str(self.analysis_page)
        self.show_study_controls(not analyzing or bool(self.control and self.busy and str(self.stop_button['state'])=='normal'))

    def scroll_design(self,event):
        if str(event.widget).startswith(str(self.body)+'.') and event.widget.winfo_class() not in ('Text','Listbox','TCombobox','Treeview'):
            self.design_canvas.yview_scroll(-int(event.delta/120),'units')

    def box(self,parent,title):
        frame=ttk.LabelFrame(parent,text=title,padding=12); frame.pack(fill='x',pady=6); return frame

    def field(self,parent,row,label,key,choices=None,column=0):
        ttk.Label(parent,text=label).grid(row=row,column=column,sticky='w',padx=(0,12),pady=4)
        v=tk.StringVar(); self.inputs[key]=v
        w=ttk.Combobox(parent,textvariable=v,values=choices,state='readonly',width=24) if choices else ttk.Entry(parent,textvariable=v,width=27)
        w.grid(row=row,column=column+1,sticky='w',padx=(0,20),pady=4); return w

    def build_design(self):
        box=self.box(self.body,'Sampling and execution')
        self.field(box,0,'Study name','name'); self.field(box,1,'Number of sampled trials','count')
        self.field(box,2,'Design seed','seed'); self.field(box,3,'Sampling method','method',('Latin hypercube','Random'))
        self.field(box,0,'Noise seeds','noise_seeds',('independent','common'),2)
        self.field(box,1,'Parallel workers','workers',(1,2,3,4),2)
        self.field(box,2,'Envelope display points','grid_points',None,2)
        self.nominal=tk.BooleanVar(); ttk.Checkbutton(box,text='Also run the nominal baseline (excluded from population statistics)',variable=self.nominal).grid(row=4,column=0,columnspan=4,sticky='w',pady=5)
        ttk.Label(box,text='Each trial uses the captured baseline; subsequent edits on Settings do not alter this study. Independent noise seeds vary sensor/actuator noise; common seeds isolate parameter effects. One worker minimizes memory use. Batch runs are unpaced.',style='Muted.TLabel',wraplength=1020).grid(row=5,column=0,columnspan=4,sticky='w')
        box=self.box(self.body,'Parameters to vary — values use the main UI units; firmware values use native CLI units')
        examples=ttk.Frame(box); examples.pack(fill='x',pady=(0,6))
        ttk.Label(examples,text='Variation example').pack(side='left')
        self.example=tk.StringVar(value='Plant tolerances')
        ttk.Combobox(examples,textvariable=self.example,values=('Plant tolerances','PID gains','Initial attitude','Sensor biases','Noise seeds only'),state='readonly',width=23).pack(side='left',padx=8)
        ttk.Button(examples,text='Replace variation rows',command=self.apply_example).pack(side='left')
        table=ttk.Frame(box); table.pack(fill='x')
        self.var_tree=ttk.Treeview(table,style='MC.Treeview',columns=('path','distribution','mode','args','group'),show='headings',height=6,selectmode='browse')
        for key,width in (('path',240),('distribution',130),('mode',120),('args',240),('group',120)):
            self.var_tree.heading(key,text=key.title()); self.var_tree.column(key,width=width)
        scrollbar=ttk.Scrollbar(table,command=self.var_tree.yview); scrollbar.pack(side='right',fill='y')
        self.var_tree.configure(yscrollcommand=scrollbar.set)
        self.var_tree.pack(side='left',fill='x',expand=True); self.var_tree.bind('<<TreeviewSelect>>',self.select_variable)
        edit=ttk.Frame(box); edit.pack(fill='x',pady=7)
        ttk.Label(edit,text='Parameter').grid(row=0,column=0,sticky='w'); self.parameter=tk.StringVar(value='plant.m')
        self.parameter_control=ttk.Combobox(edit,textvariable=self.parameter,width=40); self.parameter_control.grid(row=0,column=1,sticky='w',padx=8)
        self.parameter.trace_add('write',self.parameter_info)
        self.param_info=tk.StringVar(); ttk.Label(edit,textvariable=self.param_info,style='Muted.TLabel',wraplength=530).grid(row=0,column=2,columnspan=2,sticky='w')
        self.dist=tk.StringVar(value='uniform'); ttk.Label(edit,text='Distribution').grid(row=1,column=0,sticky='w')
        ttk.Combobox(edit,textvariable=self.dist,values=tuple(mc.DISTRIBUTIONS),state='readonly',width=22).grid(row=1,column=1,sticky='w',padx=8,pady=5)
        self.mode=tk.StringVar(value='percent change'); ttk.Label(edit,text='Value convention').grid(row=1,column=2,sticky='w')
        ttk.Combobox(edit,textvariable=self.mode,values=mc.MODES,state='readonly',width=20).grid(row=1,column=3,padx=8)
        self.args=tk.StringVar(value='[-5, 5]'); ttk.Label(edit,text='Distribution parameters').grid(row=2,column=0,sticky='w')
        ttk.Entry(edit,textvariable=self.args,width=40).grid(row=2,column=1,sticky='w',padx=8)
        self.group=tk.StringVar(); ttk.Label(edit,text='Percentile group (optional)').grid(row=2,column=2,sticky='w'); ttk.Entry(edit,textvariable=self.group,width=22).grid(row=2,column=3,padx=8)
        self.dist_help=tk.StringVar(); self.dist.trace_add('write',lambda *a:self.dist_help.set(mc.DISTRIBUTIONS[self.dist.get()]))
        self.dist_help.set(mc.DISTRIBUTIONS['uniform']); ttk.Label(box,textvariable=self.dist_help,style='Muted.TLabel').pack(anchor='w')
        buttons=ttk.Frame(box); buttons.pack(fill='x',pady=6)
        for label,callback in (('Add / update parameter',self.add_variable),('Remove selected',self.remove_variable),('Preview sampled values',self.preview)):
            ttk.Button(buttons,text=label,command=callback).pack(side='left',padx=3)
        ttk.Label(box,text='Enter parameters in brackets, e.g. [-5, 5]. Percent change means baseline × (1 + sample/100). Offsets are added to baseline. Native integer firmware values are rounded. Empty group = independent; matching group names share a percentile; prefix one with “-” to reverse it. Hardware-only firmware settings may have no simulated effect.',style='Muted.TLabel',wraplength=1030).pack(anchor='w')
        box=self.box(self.body,'Metrics and pass / fail criteria')
        self.field(box,0,'Analyze from flight time (s)','start_s'); self.field(box,1,'ANGLE settling band (deg)','settling_band_deg')
        self.field(box,0,'RATE settling band (deg/s)','settling_band_dps',column=2); self.field(box,1,'Minimum final settled interval (s)','settling_hold_s',column=2)
        self.criteria_tree=ttk.Treeview(box,style='MC.Treeview',columns=('metric','op','limit'),show='headings',height=4,selectmode='browse')
        for key in ('metric','op','limit'): self.criteria_tree.heading(key,text=key.title())
        self.criteria_tree.column('metric',width=600); self.criteria_tree.column('op',width=65); self.criteria_tree.column('limit',width=90)
        self.criteria_tree.grid(row=2,column=0,columnspan=4,sticky='ew',pady=8)
        editor=ttk.Frame(box); editor.grid(row=3,column=0,columnspan=4,sticky='w')
        self.rule_metric=tk.StringVar(value='peak_tilt_deg'); ttk.Combobox(editor,textvariable=self.rule_metric,values=tuple(mc.METRICS),state='readonly',width=33).pack(side='left')
        self.rule_op=tk.StringVar(value='<='); ttk.Combobox(editor,textvariable=self.rule_op,values=('<=','>='),state='readonly',width=4).pack(side='left',padx=4)
        self.rule_limit=tk.StringVar(value='20'); ttk.Entry(editor,textvariable=self.rule_limit,width=12).pack(side='left')
        ttk.Button(editor,text='Add / update limit',command=self.add_rule).pack(side='left',padx=4); ttk.Button(editor,text='Remove selected',command=self.remove_rule).pack(side='left')
        ttk.Label(box,text='Criteria apply together. An unavailable metric fails its criterion. ANGLE and RATE tracking have separate units. “Settled” requires both roll and pitch to remain within their final-command band through the end of the run; startup is excluded from all metrics.',style='Muted.TLabel',wraplength=1030).grid(row=4,column=0,columnspan=4,sticky='w',pady=6)
        box=self.box(self.body,'Response envelopes and data retention')
        ttk.Label(box,text='Signal keys to cache for envelopes (comma separated). Angular curves display degrees. Full signals for every trial remain available through Open trial.',style='Muted.TLabel',wraplength=1030).pack(anchor='w')
        self.signal_text=tk.Text(box,height=3,bg='#121d2b',fg='#e2e9f2',insertbackground='white',wrap='word'); self.signal_text.pack(fill='x',pady=5)
        add=ttk.Frame(box); add.pack(fill='x')
        self.envelope_signal=tk.StringVar(value='raw_gyro_x_radps')
        ttk.Combobox(add,textvariable=self.envelope_signal,values=tuple(mc.SIGNAL_CATALOG),width=40).pack(side='left')
        ttk.Button(add,text='Add envelope signal',command=self.add_envelope_signal).pack(side='left',padx=6)
        ttk.Label(box,text='Metrics use full-resolution logs. Envelope caches interpolate onto a bounded display grid; peaks between display points can be missed. Study folders store settings and data, with a trial table and original run archives. No scripts or models are copied.',style='Muted.TLabel',wraplength=1030).pack(anchor='w')

    def build_trials(self):
        page=ttk.Frame(self.tabs,padding=8); self.tabs.add(page,text='Trials / sampled values')
        bar=ttk.Frame(page); bar.pack(fill='x')
        ttk.Button(bar,text='Open selected trial in Explore',command=self.open_trial).pack(side='left')
        ttk.Button(bar,text='Load selected trial settings',command=self.load_trial_settings).pack(side='left',padx=5)
        ttk.Button(bar,text='Export metrics / summary…',command=self.export_tables).pack(side='left')
        self.trials=ttk.Treeview(page,style='MC.Treeview',columns=('id','status','passed','seed','tilt','error'),show='headings',selectmode='browse',height=12)
        for key,label,width in (('id','Trial',75),('status','Execution',120),('passed','Criteria',100),('seed','Noise seed',130),('tilt','Peak tilt (deg)',130),('error','Estimate RMS (deg)',160)):
            self.trials.heading(key,text=label,command=lambda k=key:self.sort_trials(k)); self.trials.column(key,width=width)
        scroll=ttk.Scrollbar(page,command=self.trials.yview); self.trials.configure(yscrollcommand=scroll.set); scroll.pack(side='right',fill='y')
        self.trials.pack(fill='both',expand=True,pady=8); self.trials.bind('<<TreeviewSelect>>',self.trial_details); self.trials.bind('<Double-1>',lambda e:self.open_trial())
        self.details=tk.Text(page,height=8,bg='#121d2b',fg='#dce6f2',wrap='word'); self.details.pack(fill='x')

    def build_analysis(self):
        page=ttk.Frame(self.tabs,padding=6); self.analysis_page=page; self.tabs.add(page,text='Monte Carlo analysis')
        bar=ttk.Frame(page); bar.pack(fill='x')
        self.view=tk.StringVar(value=mc_charts.VIEWS[0]); self.signal=tk.StringVar(value='roll_rad'); self.metric=tk.StringVar(value='angle_tracking_rms_deg'); self.scatter_parameter=tk.StringVar(value='plant.m'); self.selection=tk.StringVar(value='All completed')
        self.chart_controls=[]; self.selector_widgets={}
        for row,col,label,var,values,width in ((0,0,'View',self.view,mc_charts.VIEWS,24),(1,0,'Signal',self.signal,mc.SIGNALS,36),(1,0,'Metric',self.metric,tuple(mc.METRICS),36),(1,2,'Parameter',self.scatter_parameter,(),24),(0,2,'Trial subset',self.selection,('All completed','Criteria passed','Criteria failed'),24)):
            title=ttk.Label(bar,text=label); title.grid(row=row,column=col,sticky='w',padx=6,pady=3)
            combo=ttk.Combobox(bar,textvariable=var,values=values,state='readonly',width=width); combo.grid(row=row,column=col+1,sticky='w',pady=3)
            combo.bind('<<ComboboxSelected>>',lambda e:self.refresh_chart()); self.chart_controls.append(combo)
            self.selector_widgets[label]=(title,combo)
        bar.columnconfigure(4,weight=1)
        actions=ttk.Frame(bar); actions.grid(row=0,column=4,sticky='e',padx=(12,0))
        for label,callback in (('Undock',self.undock),('Reprocess metrics',self.reprocess)):
            ttk.Button(actions,text=label,command=callback).pack(side='left',padx=2)
        export=ttk.Menubutton(actions,text='Export…'); export.pack(side='left',padx=2)
        menu=tk.Menu(export,tearoff=False,bg='#202b3b',fg='#e2e9f2',activebackground='#425b78',activeforeground='white')
        for label,callback in (('Plot (PNG / PDF)…',self.export_plot),('Envelope (CSV)…',self.export_envelope),('Metrics / summary (CSV / JSON)…',self.export_tables)):
            menu.add_command(label=label,command=callback)
        export.configure(menu=menu)
        self.view.trace_add('write',lambda *args:self.layout_selectors()); self.layout_selectors()
        self.chart_note=tk.StringVar(value='Select a completed or stopped study. Nominal is excluded from population statistics.')
        note=ttk.Label(page,textvariable=self.chart_note,style='Muted.TLabel'); note.pack(fill='x',pady=5)
        note.bind('<Configure>',lambda e:note.configure(wraplength=max(250,e.width)))
        self.figure=Figure(figsize=(10,4),layout='constrained'); self.canvas=FigureCanvasTkAgg(self.figure,master=page)
        self.toolbar=NavigationToolbar2Tk(self.canvas,page,pack_toolbar=False); self.toolbar.pack(side='bottom',fill='x')
        self.canvas.get_tk_widget().pack(fill='both',expand=True)
        mc_charts.render(self.figure,None,self.view.get()); self.canvas.draw_idle()

    def layout_selectors(self):
        view=self.view.get()
        for name,show in (('Signal',view=='Response envelope'),('Metric',view!='Response envelope'),('Parameter',view=='Parameter response')):
            for widget in self.selector_widgets[name]:
                if show: widget.grid()
                else: widget.grid_remove()

    def populate(self):
        d=self.design
        for key,var in self.inputs.items(): var.set(str(d[key] if key in d else d['analysis'][key]))
        self.nominal.set(d['include_nominal']); self.variables=copy.deepcopy(d['variables']); self.criteria=copy.deepcopy(d['analysis']['criteria'])
        self.signal_text.delete('1.0','end'); self.signal_text.insert('1.0',', '.join(d['signals']))
        self.baseline_label.set(f"Captured baseline: {d['base']['name']} • {d['base']['duration']:g} s • {d['base']['command_mode'].upper()} • noise {'ON' if d['base']['noise'] else 'OFF'} • stored inside the study")
        self.parameter_catalog=mc.parameter_catalog(d['base'])
        self.parameter_control.configure(values=tuple(self.parameter_catalog))
        if self.metric.get() in ('angle_tracking_rms_deg','rate_tracking_rms_dps'):
            self.metric.set('angle_tracking_rms_deg' if d['base']['command_mode']=='angle' else 'rate_tracking_rms_dps')
        self.refresh_editors(); self.parameter_info()

    def parameter_info(self,*args):
        if not hasattr(self,'param_info'): return
        path=self.parameter.get()
        try:
            catalog=getattr(self,'parameter_catalog',{})
            self.parameter_control.configure(values=tuple(catalog) if path in catalog else tuple(k for k in catalog if path.lower() in k.lower()))
            item=catalog[path]
            unit=' UI angular values are degrees / degrees per second.' if path.startswith(('initial.','reference.','schedule.')) else ''
            label=self.app.field_widgets.get(path,(None,mc.parameter_label(path)))[1]
            self.param_info.set(label+' — Baseline: '+str(item['value'])+'. '+item.get('constraint','')+unit)
        except (KeyError,ValueError): self.param_info.set('Type a name fragment, then use the dropdown arrow to choose an exact parameter path.')

    def refresh_editors(self):
        self.var_tree.delete(*self.var_tree.get_children())
        for i,v in enumerate(self.variables): self.var_tree.insert('','end',iid=str(i),values=(v['path'],v['distribution'],v['mode'],json.dumps(v['args']),v.get('group','')))
        self.criteria_tree.delete(*self.criteria_tree.get_children())
        for i,c in enumerate(self.criteria): self.criteria_tree.insert('','end',iid=str(i),values=(mc.METRICS[c['metric']],c['op'],c['limit']))

    def select_variable(self,event=None):
        selected=self.var_tree.selection()
        if not selected: return
        v=self.variables[int(selected[0])]
        self.parameter.set(v['path']); self.dist.set(v['distribution']); self.mode.set(v['mode']); self.args.set(json.dumps(v['args'])); self.group.set(v.get('group',''))

    def add_variable(self):
        try:
            path=self.parameter.get().strip()
            if path not in self.parameter_catalog: raise ValueError('Choose a parameter from the catalog.')
            raw=self.args.get().strip(); args=json.loads(raw if raw.startswith('[') else '['+raw+']')
            v={'path':path,'distribution':self.dist.get(),'mode':self.mode.get(),'args':args,'group':self.group.get().strip()}
            mc.draw_distribution(v,__import__('numpy').array([.1,.5,.9]))
            index=next((i for i,old in enumerate(self.variables) if old['path']==path),len(self.variables))
            if index==len(self.variables): self.variables.append(v)
            else: self.variables[index]=v
            self.refresh_editors()
        except Exception as e: messagebox.showerror('Parameter variation',str(e))

    def remove_variable(self):
        selected=self.var_tree.selection()
        if selected: self.variables.pop(int(selected[0])); self.refresh_editors()

    def apply_example(self):
        self.variables=mc.variation_example(self.example.get()); self.refresh_editors()
        if self.example.get()=='Noise seeds only':
            self.inputs['noise_seeds'].set('independent')
            self.status.set('Independent seeds selected. Captured baseline noise is '+('ON.' if self.design['base']['noise'] else 'OFF; enable noise in Settings and recapture the baseline to produce noise variation.'))
        elif self.example.get()=='Sensor biases':
            self.status.set('Sensor biases use deg/s and g. Startup gyro calibration remains active; known accelerometer calibration compensates each trial’s bias when enabled in the baseline.')

    def add_rule(self):
        try:
            rule={'metric':self.rule_metric.get(),'op':self.rule_op.get(),'limit':float(self.rule_limit.get())}
            index=next((i for i,r in enumerate(self.criteria) if r['metric']==rule['metric']),len(self.criteria))
            if index==len(self.criteria): self.criteria.append(rule)
            else: self.criteria[index]=rule
            self.refresh_editors()
        except Exception as e: messagebox.showerror('Metric limit',str(e))

    def remove_rule(self):
        selected=self.criteria_tree.selection()
        if selected: self.criteria.pop(int(selected[0])); self.refresh_editors()

    def collect_analysis(self):
        a={key:float(self.inputs[key].get()) for key in ('start_s','settling_band_deg','settling_band_dps','settling_hold_s')}; a['criteria']=copy.deepcopy(self.criteria); mc.validate_analysis(a); return a

    def collect(self):
        d=copy.deepcopy(self.design)
        for key in ('name','method','noise_seeds'): d[key]=self.inputs[key].get()
        for key in ('count','seed','workers','grid_points'): d[key]=int(self.inputs[key].get())
        d.update(include_nominal=self.nominal.get(),variables=copy.deepcopy(self.variables),analysis=self.collect_analysis(),signals=[x.strip() for x in self.signal_text.get('1.0','end').split(',') if x.strip()])
        return d

    def capture_baseline(self):
        if self.busy: return
        try:
            self.app.sync_cli(); baseline=self.app.collect(); self.design=self.collect(); self.design['base']=baseline; self.populate()
            self.detach_study()
            self.status.set('Baseline captured. Saved trial settings will include derived parameters and effective firmware configuration.')
        except Exception as e: messagebox.showerror('Capture baseline',str(e))

    def detach_study(self):
        """A new baseline/design must not masquerade as the currently open archive."""
        self.folder=None; self.manifest=None; self.payload=None; self.chart_pending=False
        self.update_trials(); self.progress['value']=0; self.details.delete('1.0','end')
        self.chart_note.set('Run or open a study to analyze its saved results.')
        mc_charts.render(self.figure,None,self.view.get()); self.canvas.draw_idle()

    def add_envelope_signal(self):
        key=self.envelope_signal.get().strip()
        if key not in mc.SIGNAL_CATALOG: messagebox.showerror('Envelope signal','Choose an exact signal key from the catalog.'); return
        current=[x.strip() for x in self.signal_text.get('1.0','end').split(',') if x.strip()]
        if key not in current:
            current.append(key); self.signal_text.delete('1.0','end'); self.signal_text.insert('1.0',', '.join(current))

    def launch_job(self,target,status,batch=False,cancellable=False):
        if self.busy: return False
        self._busy=True
        self.status.set(status); self.start_button.configure(state='disabled'); self.resume_button.configure(state='disabled')
        self.stop_button.configure(state='normal' if batch or cancellable else 'disabled'); self.pause_button.configure(state='normal' if batch else 'disabled',text='Pause')
        self.reveal_for_job=batch or cancellable
        if batch or cancellable: self.show_study_controls(True)
        def worker():
            try: target()
            except InterruptedError as e: self.events.put(('status',str(e)))
            except Exception as e: self.events.put(('error',str(e)))
            finally: self.events.put(('idle',None))
        self.job=threading.Thread(target=worker,daemon=True); self.job.start(); return True

    def preview(self):
        if self.busy: return
        try: d=self.collect()
        except Exception as e: messagebox.showerror('Study design',str(e)); return
        self.control=mc.BatchControl()
        def work(): self.events.put(('preview',mc.sample_design(d,self.control.cancel)))
        self.launch_job(work,'Validating all sampled cases…',cancellable=True)

    def save_design(self):
        try:
            d=self.collect(); path=filedialog.asksaveasfilename(defaultextension='.json',filetypes=[('Monte Carlo design','*.json')])
            if path:
                if (Path(path).parent/'manifest.json').exists(): raise ValueError('Save reusable designs outside existing study archives; their original design is immutable.')
                mc.atomic_json(path,d)
        except Exception as e: messagebox.showerror('Save design',str(e))

    def load_design(self):
        if self.busy: return
        path=filedialog.askopenfilename(filetypes=[('Monte Carlo design','*.json')])
        if path:
            try:
                d=storage.read_json(Path(path))
                if d.get('format')!=mc.FORMAT: raise ValueError('Choose a Monte Carlo design / study file.')
                self.design=d; self.populate(); self.detach_study(); self.status.set('Design loaded. Start new study creates a separate archive.')
            except Exception as e: messagebox.showerror('Load design',str(e))

    def start(self):
        if self.busy or self.app.running:
            if self.app.running: messagebox.showinfo('Monte Carlo','Finish or stop the single simulation first.')
            return
        try: d=self.collect()
        except Exception as e: messagebox.showerror('Study design',str(e)); return
        self.control=mc.BatchControl(); root=self.app.data_root/'monte_carlo'
        def work():
            folder=mc.create_study(d,root,self.control.cancel); self.events.put(('folder',folder))
            manifest=mc.run_study(folder,self.control,lambda k,v:self.events.put((k,v)))
            self.events.put(('finished',(folder,manifest)))
        self.launch_job(work,'Validating samples and creating study…',batch=True)

    def resume(self):
        if self.busy or self.app.running or self.folder is None: return
        self.control=mc.BatchControl(); folder=self.folder; retry=self.retry.get()
        def work():
            manifest=mc.run_study(folder,self.control,lambda k,v:self.events.put((k,v)),retry_errors=retry)
            self.events.put(('finished',(folder,manifest)))
        self.launch_job(work,'Resuming the saved design and exact sampled values…',batch=True)

    def pause(self):
        if self.control and self.busy:
            on=not self.control.paused.is_set(); self.control.pause(on)
            self.pause_button.configure(text='Resume' if on else 'Pause'); self.status.set('Paused: queued trials wait; active calibration may finish before flight pauses.' if on else 'Batch running…')

    def stop(self):
        if self.control and self.busy: self.control.stop(); self.status.set('Stopping active trials; pending trials remain available to resume.')

    def terminate(self):
        if self.control: self.control.terminate()

    def open_study(self,path=None):
        if self.busy: return
        path=path or filedialog.askopenfilename(initialdir=self.app.data_root/'monte_carlo',title='Open study.json',filetypes=[('Monte Carlo study','study.json')])
        if not path: return
        try:
            folder=Path(path).parent if Path(path).is_file() else Path(path); d=storage.read_json(folder/'study.json')
            if d.get('format')!=mc.FORMAT: raise ValueError('Choose a study folder containing study.json.')
            self.folder=folder; self.design=d; self.design['analysis']=storage.read_json(folder/'analysis.json',d['analysis']); self.populate()
            self.manifest=storage.read_json(folder/'manifest.json'); self.update_trials(); self.status.set('Opened '+str(folder)); self.refresh_chart()
        except Exception as e: messagebox.showerror('Open study',str(e))

    def update_trials(self):
        self.trials.delete(*self.trials.get_children())
        if not self.manifest: return
        for i,r in enumerate(self.manifest['rows']):
            self.trials.insert('','end',iid=str(i),values=self.trial_cells(r))
        done=sum(r['status'] not in ('pending','running') for r in self.manifest['rows']); self.progress['value']=100*done/len(self.manifest['rows'])

    def trial_cells(self,r):
        m=r.get('metrics',{}); fmt=lambda key:f"{m[key]:.4g}" if m.get(key) is not None else '—'
        return ('Nominal' if r['nominal'] else r['id'],r['status'],'Pass' if r.get('passed') is True else 'Fail' if r.get('passed') is False else '—',r['noise_seed'],fmt('peak_tilt_deg'),fmt('attitude_estimation_rms_deg'))

    def sort_trials(self,column,reverse=False):
        def key(item):
            value=self.trials.set(item,column)
            try: return (0,float(value))
            except ValueError: return (1,value)
        for i,item in enumerate(sorted(self.trials.get_children(),key=key,reverse=reverse)): self.trials.move(item,'',i)
        self.trials.heading(column,command=lambda:self.sort_trials(column,not reverse))

    def selected_trial(self):
        selected=self.trials.selection()
        return self.manifest['rows'][int(selected[0])] if selected and self.manifest else None

    def trial_details(self,event=None):
        row=self.selected_trial(); self.details.delete('1.0','end')
        if row: self.details.insert('1.0',json.dumps(row,indent=2))

    def open_trial(self):
        row=self.selected_trial()
        if row and row.get('run_folder') and (self.folder/row['run_folder']/'signals.h5').exists():
            self.app.read_data(self.folder/row['run_folder']); self.app.pages.select(2)

    def load_trial_settings(self):
        row=self.selected_trial()
        if row and row.get('run_folder') and (self.folder/row['run_folder']/'settings.json').exists():
            self.app.load_settings_path(self.folder/row['run_folder']/'settings.json'); self.app.pages.select(0)

    def refresh_chart(self):
        if self.busy: self.chart_pending=True; return
        if self.folder is None: return
        self.chart_pending=False
        design=storage.read_json(self.folder/'study.json'); self.chart_controls[1].configure(values=design['signals'])
        paths=[v['path'] for v in design['variables']]; self.chart_controls[3].configure(values=paths)
        if self.signal.get() not in design['signals']: self.signal.set(design['signals'][0])
        if self.scatter_parameter.get() not in paths: self.scatter_parameter.set(paths[0] if paths else '')
        folder=self.folder; args=(self.signal.get(),self.metric.get(),self.scatter_parameter.get(),self.selection.get())
        def work(): self.events.put(('chart',mc_charts.prepare(folder,*args)))
        self.launch_job(work,'Preparing Monte Carlo analysis…')

    def reprocess(self):
        if self.busy or self.folder is None: return
        try: analysis=self.collect_analysis()
        except Exception as e: messagebox.showerror('Analysis settings',str(e)); return
        folder=self.folder
        self.control=mc.BatchControl()
        def work():
            mc.reprocess(folder,analysis,lambda k,v:self.events.put((k,v)),cancel=self.control.cancel)
            self.events.put(('finished',(folder,storage.read_json(folder/'manifest.json'))))
        self.launch_job(work,'Recomputing full-resolution metrics using the Study design analysis settings…',cancellable=True)

    def export_tables(self):
        if self.busy or self.folder is None: return
        path=filedialog.askdirectory(title='Export metrics.csv and summary.json')
        if path:
            try: mc.export_results(self.folder,path); self.status.set('Exported metrics.csv and summary.json.')
            except Exception as e: messagebox.showerror('Export metrics',str(e))

    def export_plot(self):
        path=filedialog.asksaveasfilename(defaultextension='.png',filetypes=[('PNG','*.png'),('PDF','*.pdf')])
        if path:
            try: self.figure.savefig(path,dpi=180,facecolor=self.figure.get_facecolor())
            except Exception as e: messagebox.showerror('Export plot',str(e))

    def export_envelope(self):
        if not self.payload: return
        path=filedialog.asksaveasfilename(defaultextension='.csv',filetypes=[('CSV','*.csv')])
        if path:
            try: mc_charts.export_envelope(self.payload,path)
            except Exception as e: messagebox.showerror('Export envelope',str(e))

    def undock(self):
        if not self.payload: return
        window=tk.Toplevel(self); window.title('Monte Carlo • '+self.view.get()); window.geometry('1150x700')
        figure=Figure(figsize=(11,6),layout='constrained'); canvas=FigureCanvasTkAgg(figure,master=window)
        toolbar=NavigationToolbar2Tk(canvas,window,pack_toolbar=False); toolbar.pack(side='bottom',fill='x')
        canvas.get_tk_widget().pack(fill='both',expand=True)
        mc_charts.render(figure,self.payload,self.view.get()); canvas.draw_idle()

    def poll(self):
        refresh=False
        try:
            while True:
                kind,value=self.events.get_nowait()
                if kind=='folder':
                    self.folder=value; self.payload=None; self.manifest=storage.read_json(value/'manifest.json'); self.update_trials(); self.status.set('Running study: '+value.name)
                elif kind=='trial':
                    i,row=value; self.manifest['rows'][i]=row
                    self.trials.item(str(i),values=self.trial_cells(row))
                    rows=self.manifest['rows']; done=sum(r['status'] not in ('pending','running') for r in rows); self.progress['value']=100*done/len(rows)
                    if not self.control.paused.is_set(): self.status.set(f"{sum(r['status']=='complete' for r in rows)} complete / {len(rows)} total • {sum(r['status']=='running' for r in rows)} active")
                elif kind=='finished':
                    self.folder,self.manifest=value; self.update_trials(); refresh=True
                elif kind=='preview':
                    window=tk.Toplevel(self); window.title('Sample preview — no simulations started'); window.geometry('950x650')
                    text=tk.Text(window,wrap='none'); text.pack(fill='both',expand=True); text.insert('1.0',f'All {len(value)} cases passed validation. First 12 rows:\n\n'+json.dumps(value[:12],indent=2)); text.configure(state='disabled')
                    self.status.set(f'Validated {len(value)} cases. Exact samples and seeds are fixed by the design.')
                elif kind=='chart':
                    self.payload=value; summary=value['summary']; self.chart_note.set(f"{summary['complete']} / {summary['requested']} trials complete • {summary['criteria_pass']} passed all criteria • Nominal excluded"+(f" • {mc.METRICS[value['metric']]}" if self.view.get()!='Response envelope' else ''))
                    mc_charts.render(self.figure,value,self.view.get()); self.canvas.draw_idle(); self.status.set('Study ready for analysis: '+self.folder.name)
                elif kind=='error':
                    self.status.set('Monte Carlo operation failed: '+value)
                    if not self.app.closing: messagebox.showerror('Monte Carlo',value)
                elif kind=='status': self.status.set(value)
                elif kind=='idle':
                    self._busy=False
                    refresh=refresh or self.chart_pending
                    self.start_button.configure(state='normal'); self.resume_button.configure(state='normal'); self.pause_button.configure(state='disabled',text='Pause'); self.stop_button.configure(state='disabled')
                    if self.reveal_for_job: self.analysis_layout()
        except queue.Empty: pass
        if refresh and not self.app.closing: self.after(120,self.refresh_chart)
        self.after_id=self.after(100,self.poll)
