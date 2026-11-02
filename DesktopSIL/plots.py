"""Responsive Tk plots; full data retained, extrema preserved for drawing."""
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import numpy as np

COLORS = ("#efaa32", "#55b9ed", "#b18ae8", "#61cf9a", "#ef7f8d", "#c7d1de")

def display_signal(name, values):
    if name.endswith("_radps"): return name[:-6] + " (deg/s)", np.rad2deg(values)
    if name.endswith("_rad"): return name[:-4] + " (deg)", np.rad2deg(values)
    return name.replace("_", " "), values

def extrema_indices(y, budget):
    """Keep endpoints and both extrema in every display bucket, in time order."""
    if len(y) <= budget: return np.arange(len(y))
    edges = np.linspace(0, len(y), max(2, budget // 2), dtype=int)
    keep = [0, len(y) - 1]
    for a, b in zip(edges[:-1], edges[1:]):
        if b > a:
            keep.extend((a + int(np.argmin(y[a:b])), a + int(np.argmax(y[a:b]))))
    return np.unique(keep)

class Plot(ttk.Frame):
    def __init__(self, parent, title="Signals", **kwargs):
        super().__init__(parent, **kwargs)
        self.series, self.limits, self.drag = [], None, None
        self.title = title
        self.empty_message="Run a simulation or add saved signals"
        toolbar = ttk.Frame(self); toolbar.pack(fill="x", padx=8, pady=6)
        ttk.Label(toolbar, text=title, style="Subhead.TLabel").pack(side="left")
        ttk.Button(toolbar, text="Full duration", command=self.home).pack(side="right")
        ttk.Button(toolbar, text="Undock", command=self.undock).pack(side="right", padx=4)
        ttk.Button(toolbar, text="Clear selected", command=self.clear_selected).pack(side="right", padx=4)
        ttk.Button(toolbar,text="Export…",command=self.export).pack(side="right",padx=4)
        self.canvas = tk.Canvas(self, bg="#151d29", highlightthickness=0, height=350)
        self.canvas.pack(fill="both", expand=True, padx=8)
        self.legend = tk.Listbox(self, height=3, selectmode="extended", exportselection=False,
            bg="#202b3b", fg="#dce4ee", selectbackground="#52657d", relief="flat", font=("Segoe UI", 9))
        self.legend.pack(fill="x", padx=8, pady=5)
        ttk.Label(self, text="Wheel: zoom time  •  Drag: pan  •  Double-click: full duration  •  Select legend rows to remove", style="Muted.TLabel").pack(anchor="w", padx=8, pady=(0,6))
        self.canvas.bind("<Configure>", lambda e: self.draw())
        self.canvas.bind("<MouseWheel>", self.zoom)
        self.canvas.bind("<ButtonPress-1>", self.pan_start)
        self.canvas.bind("<B1-Motion>", self.pan)
        self.canvas.bind("<Double-Button-1>", lambda e: self.home())
    def add(self, name, x, y):
        self.series.append((name, x, y))
        self.legend.insert("end", name)
        self.legend.itemconfig("end", fg=COLORS[(len(self.series)-1) % len(COLORS)])
        self.home()
    def replace(self, series):
        self.series = []; self.legend.delete(0,"end")
        for name,x,y in series:
            self.series.append((name,x,y)); self.legend.insert("end",name)
            self.legend.itemconfig("end",fg=COLORS[(len(self.series)-1)%len(COLORS)])
        self.home()
    def clear_selected(self):
        selected = set(self.legend.curselection())
        self.replace([s for i,s in enumerate(self.series) if i not in selected])
    def home(self):
        self.limits = None
        self.draw()
    def extent(self):
        if not self.series: return 0,1
        return min(s[1][0] for s in self.series), max(s[1][-1] for s in self.series)
    def zoom(self, event):
        lo,hi = self.limits or self.extent(); width=max(1,self.canvas.winfo_width()-90)
        fraction=np.clip((event.x-65)/width,0,1); center=lo+(hi-lo)*fraction
        span=max(1e-6,(hi-lo)*(.8 if event.delta>0 else 1.25))
        self.limits=(center-span*fraction,center+span*(1-fraction)); self.draw()
    def pan_start(self, event): self.drag=(event.x,self.limits or self.extent())
    def pan(self, event):
        if self.drag:
            start,(lo,hi)=self.drag; d=(event.x-start)*(hi-lo)/max(1,self.canvas.winfo_width()-90)
            self.limits=(lo-d,hi-d); self.draw()
    def draw(self):
        c=self.canvas; c.delete("all"); w=c.winfo_width(); h=c.winfo_height()
        if w<100 or h<100: return
        left,right,top,bottom=65,w-22,22,h-42
        lo,hi=self.limits or self.extent()
        if hi<=lo: hi=lo+1
        visible=[]
        for name,x,y in self.series:
            a=max(0,np.searchsorted(x,lo)-1); b=min(len(x),np.searchsorted(x,hi,side="right")+1)
            xx=x[a:b]; yy=y[a:b]; valid=np.isfinite(yy)
            visible.append((xx[valid],yy[valid]))
        arrays=[y for x,y in visible if len(y)]
        ymin=min(float(y.min()) for y in arrays) if arrays else -1
        ymax=max(float(y.max()) for y in arrays) if arrays else 1
        pad=max((ymax-ymin)*.08,abs(ymax)*1e-5,1e-6); ymin-=pad; ymax+=pad
        for i in range(6):
            px=left+(right-left)*i/5; py=bottom-(bottom-top)*i/5
            c.create_line(px,top,px,bottom,fill="#2b3747"); c.create_line(left,py,right,py,fill="#2b3747")
            c.create_text(px,bottom+17,text=f"{lo+(hi-lo)*i/5:.4g}",fill="#a9b8ca",font=("Segoe UI",9))
            c.create_text(left-8,py,anchor="e",text=f"{ymin+(ymax-ymin)*i/5:.4g}",fill="#a9b8ca",font=("Segoe UI",9))
        c.create_text((left+right)/2,h-8,text="Simulation time (s)",fill="#a9b8ca",font=("Segoe UI",9))
        if not self.series:
            c.create_text(w/2,h/2,text=self.empty_message,fill="#a9b8ca",font=("Segoe UI",12),width=max(100,w-100)); return
        for i,(x,y) in enumerate(visible):
            if len(y)<2: continue
            indices=extrema_indices(y,max(200,int(right-left)*2))
            px=np.clip(left+(x[indices]-lo)/(hi-lo)*(right-left),left,right)
            py=bottom-(y[indices]-ymin)/(ymax-ymin)*(bottom-top)
            coords=np.column_stack((px,py)).ravel().tolist()
            c.create_line(*coords,fill=COLORS[i%len(COLORS)],width=1.4)
    def undock(self):
        window=tk.Toplevel(self); window.title(self.title); window.geometry("1100x650")
        plot=Plot(window,self.title); plot.pack(fill="both",expand=True); plot.replace(list(self.series))
        plot.empty_message=self.empty_message; plot.draw()
    def export(self,path=None):
        if path is None: path=filedialog.asksaveasfilename(defaultextension=".png",filetypes=[("PNG","*.png"),("PDF","*.pdf")])
        if not path: return
        export_panels([{"title":self.title,"description":"","series":self.series}],path,[self.limits])

def export_panels(panels,path,limits=None):
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_agg import FigureCanvasAgg
    n=len(panels); cols=2 if n>1 else 1; rows=(n+cols-1)//cols
    figure=Figure(figsize=(12,4*rows),layout="constrained"); FigureCanvasAgg(figure)
    for i,panel in enumerate(panels):
        ax=figure.add_subplot(rows,cols,i+1)
        for j,(label,x,y) in enumerate(panel["series"]):
            style="--" if "trim" in label.lower() or "command" in label.lower() else "-"
            ax.plot(x,y,style,label=label,color=COLORS[j%len(COLORS)],linewidth=.9)
        ax.set_title(panel["title"]+"\n"+panel.get("description",""),fontsize=9,wrap=True)
        ax.set_xlabel("Simulation time (s)"); ax.grid(True,alpha=.3)
        if panel["series"]: ax.legend(fontsize=8)
        if limits and limits[i]: ax.set_xlim(*limits[i])
    figure.savefig(path,dpi=180)
