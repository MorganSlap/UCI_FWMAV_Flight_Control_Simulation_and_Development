"""Bounded Monte Carlo chart preparation; no full-resolution runs stay in RAM."""
from pathlib import Path
import csv
import re
import h5py
import numpy as np
from scipy.stats import spearmanr
import storage
import monte_carlo as mc

VIEWS=('Response envelope','Metric distribution','Parameter response','Sensitivity','Outcomes / convergence')


def prepare(folder,signal,metric,parameter,selection='All completed'):
    folder=Path(folder)
    lock=folder/'study.lock'
    if lock.exists() and mc.process_alive(int(storage.read_json(lock)['pid'])):
        raise RuntimeError('This study is being updated. Stop or finish the batch before loading its analysis charts.')
    design=storage.read_json(folder/'study.json'); manifest=storage.read_json(folder/'manifest.json')
    rows=manifest['rows']; chosen=[(i,r) for i,r in enumerate(rows) if r['status']=='complete' and not r['nominal']
        and (selection=='All completed' or r.get('passed')==(selection=='Criteria passed'))]
    nominal=next(((i,r) for i,r in enumerate(rows) if r['nominal'] and r['status']=='complete'),None)
    payload={'signal':signal,'metric':metric,'parameter':parameter,'selection':selection,'n':len(chosen),
        'summary':mc.summarize(folder),'study_name':design['name'],'sensitivities':[],'envelope':None,'nominal':None}
    with h5py.File(folder/'ensemble.h5','r') as f:
        grid=f['time_s'][()]
        if signal not in f: raise ValueError('Signal was not included in this study’s envelope cache.')
        if chosen:
            values=f[signal][[i for i,r in chosen],:]; count=np.isfinite(values).sum(axis=0); valid=count>0
            q=np.nanpercentile(values[:,valid],[5,50,95],axis=0)
            display=np.unique(np.linspace(0,len(values)-1,min(20,len(values))).astype(int))
            payload['envelope']={'time':grid[valid],'p05':q[0],'median':q[1],'p95':q[2],'count':count[valid],
                'traces':values[display][:,valid]}
        if nominal: payload['nominal']=(grid,f[signal][nominal[0],:])
    valid=[r for i,r in chosen if r.get('metrics',{}).get(metric) is not None]
    payload['metric_values']=np.array([r['metrics'][metric] for r in valid])
    payload['trial_ids']=np.array([r['id'] for r in valid])
    payload['nominal_metric']=nominal[1]['metrics'].get(metric) if nominal else None
    payload['parameter_values']=[r['values'].get(parameter) for r in valid]
    payload['metric_passed']=np.array([r['passed'] for r in valid],dtype=bool)
    for var in design['variables']:
        path=var['path']; x=[r['values'].get(path) for r in valid]
        if len(valid)<3 or not all(isinstance(v,(int,float)) and not isinstance(v,bool) for v in x): continue
        if np.ptp(x)==0 or np.ptp(payload['metric_values'])==0: continue
        rho=float(spearmanr(x,payload['metric_values']).statistic)
        if np.isfinite(rho): payload['sensitivities'].append((path,rho))
    payload['sensitivities'].sort(key=lambda item:abs(item[1]),reverse=True)
    return payload


def style_axis(ax):
    ax.set_facecolor('#172232'); ax.tick_params(colors='#c9d5e3',labelsize=9)
    for spine in ax.spines.values(): spine.set_color('#506077')
    ax.grid(alpha=.18,color='#b1bed0'); ax.xaxis.label.set_color('#dce6f2'); ax.yaxis.label.set_color('#dce6f2')
    ax.title.set_color('#f0bd68')


def render(figure,payload,view):
    figure.clear(); figure.set_facecolor('#172232')
    if payload is None:
        ax=figure.add_subplot(); style_axis(ax); ax.text(.5,.5,'Run or open a Monte Carlo study',ha='center',va='center',color='white',transform=ax.transAxes); return
    d=payload; metric=mc.METRICS[d['metric']]; values=d['metric_values']
    def axes(count=1):
        aa=[figure.add_subplot(1,count,i+1) for i in range(count)]
        for ax in aa: style_axis(ax)
        return aa
    if view=='Response envelope':
        ax,=axes(); e=d['envelope']
        if e:
            for row in e['traces']: ax.plot(e['time'],row,color='#55b9ed',alpha=.12,linewidth=.7)
            ax.fill_between(e['time'],e['p05'],e['p95'],color='#55b9ed',alpha=.3,label='Pointwise 5th–95th percentile')
            ax.plot(e['time'],e['median'],color='#efaa32',linewidth=1.7,label='Median')
        if d['nominal'] is not None: ax.plot(*d['nominal'],color='#61cf9a',linestyle='--',label='Nominal (excluded from statistics)')
        unit='deg/s' if d['signal'].endswith('_radps') else 'deg' if d['signal'].endswith('_rad') else mc.SIGNAL_CATALOG[d['signal']]['unit']
        label=re.sub(r'_(?:radps|rad|mps2|mps|m|pot|us|g)$','',d['signal']).replace('_',' ')
        if label.startswith('error '): label='True − Estimated '+label[6:]
        ax.set(xlabel='Flight time (s)',ylabel=label+(f' ({unit})' if unit else ''),title=f"Response spread • {d['n']} completed trials\nEmpirical population percentiles; not confidence bounds")
        if e or d['nominal'] is not None: ax.legend(fontsize=8,facecolor='#dce6f2')
    elif view=='Metric distribution':
        a,b=axes(2)
        if len(values):
            a.hist(values,bins=min(30,max(3,int(np.sqrt(len(values))))),color='#55b9ed',alpha=.85)
            ordered=np.sort(values); b.step(ordered,np.arange(1,len(values)+1)/len(values),where='post',marker='.',color='#efaa32')
            for ax in (a,b):
                if d['nominal_metric'] is not None: ax.axvline(d['nominal_metric'],color='#61cf9a',linestyle='--',label='Nominal'); ax.legend(fontsize=8)
        a.set(title=f'Distribution • n = {len(values)}',xlabel=metric,ylabel='Trials')
        b.set(title='Empirical cumulative distribution',xlabel=metric,ylabel='Fraction ≤ value',ylim=(0,1.02))
    elif view=='Parameter response':
        ax,=axes(); x=d['parameter_values']
        if x and all(v is not None for v in x):
            numeric=all(isinstance(v,(int,float)) and not isinstance(v,bool) for v in x)
            if not numeric:
                labels=list(dict.fromkeys(map(str,x))); x=[labels.index(str(v)) for v in x]; ax.set_xticks(range(len(labels)),labels,rotation=20)
            ax.scatter(x,values,c=np.where(d['metric_passed'],'#61cf9a','#ef7f8d'),alpha=.8,s=28)
        ax.set(xlabel=mc.parameter_label(d['parameter']),ylabel=metric,title='Parameter versus outcome\nGreen: criteria passed • red: criteria failed; association is not causation')
    elif view=='Sensitivity':
        ax,=axes(); items=d['sensitivities'][:12][::-1]
        if items:
            paths,rho=zip(*items); labels=[mc.parameter_label(path) for path in paths]
            ax.barh(labels,rho,color=['#55b9ed' if r>=0 else '#ef7f8d' for r in rho]); ax.axvline(0,color='#dce6f2',linewidth=.8)
        else: ax.text(.5,.5,'At least 3 complete trials and varying numeric inputs/outcomes are needed.',ha='center',color='white',wrap=True,transform=ax.transAxes)
        ax.set(xlim=(-1,1),xlabel='Spearman rank correlation',title='Parameter association with '+metric+'\nCategorical / constant inputs omitted; coupled inputs can confound interpretation')
    else:
        a,b=axes(2); summary=d['summary']; outcomes=summary['outcomes']
        labels=['Pass','Criteria fail','Engine / analysis fail','Stopped','Pending / running']
        counts=[summary['criteria_pass'],summary['complete']-summary['criteria_pass'],outcomes['failed']+outcomes['analysis failed'],outcomes['stopped'],outcomes['pending']+outcomes['running']]
        a.bar(range(5),counts,color=['#61cf9a','#efaa32','#ef7f8d','#b18ae8','#647b96']); a.set_xticks(range(5),labels,rotation=25,ha='right'); a.set(title='All sampled trial outcomes (nominal excluded)',ylabel='Trials')
        if len(values): b.plot(np.arange(1,len(values)+1),np.cumsum(values)/np.arange(1,len(values)+1),color='#efaa32')
        b.set(title='Running metric mean in trial-ID order',xlabel='Completed trials with this metric',ylabel=metric)
    figure.suptitle(d['study_name']+' • '+d['selection'],color='#dce6f2',fontsize=11)


def export_envelope(payload,path):
    e=payload['envelope']
    if e is None: raise ValueError('No completed-trial envelope to export.')
    with Path(path).open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.writer(f); writer.writerow(['time_s','p05','median','p95','valid_trials'])
        writer.writerows(zip(e['time'],e['p05'],e['median'],e['p95'],e['count']))
