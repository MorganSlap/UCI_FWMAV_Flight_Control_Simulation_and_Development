// Append the Monte Carlo walkthrough to the existing 21-slide desktop guide.
import fs from 'node:fs/promises';
import path from 'node:path';

export async function appendMonteCarloSlides(deck,{here,font='Segoe UI'}) {
  const ink='#182639',muted='#4E6076';
  function text(s,value,x,y,w,h,size=26,bold=false,color=ink){
    const box=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
    box.text=value;box.text.style={typeface:font,fontSize:size,bold,color};return box;
  }
  function slide(title,notes=''){
    const s=deck.slides.add();s.background.fill='#F7F8FA';
    text(s,title,54,36,1170,70,44,true);
    s.speakerNotes.text='Sources: DesktopSIL/docs/Monte_Carlo.md, monte_carlo.py, monte_carlo_ui.py, mc_charts.py. '+notes;
    return s;
  }
  function paragraphs(s,items,x=60,y=150,w=1150,spacing=125,size=28){
    items.forEach((v,i)=>text(s,v,x,y+spacing*i,w,spacing-12,size));
  }
  async function screenshot(s,file,items){
    paragraphs(s,items,54,154,315,132,25);
    s.images.add({blob:new Uint8Array(await fs.readFile(path.join(here,'images',file))),contentType:'image/png',alt:file.replaceAll('_',' ').replace('.png',''),fit:'contain',position:{left:392,top:120,width:834,height:584}});
  }
  function table(s,values,widths,y=145,height=430){
    const t=s.tables.add({rows:values.length,columns:values[0].length,left:60,top:y,width:1160,height,columnWidths:widths,values});
    t.borders.assign({fill:'#D8DEE7',width:1,style:'solid'});
    for(let r=0;r<values.length;r++)for(let c=0;c<values[0].length;c++){
      const cell=t.getCell(r,c);cell.fill=r===0?'#182639':(r%2?'#FFFFFF':'#EDF1F6');
      cell.text.style={typeface:font,fontSize:24,color:r===0?'#FFFFFF':ink,bold:r===0};
    }
    return t;
  }

  let s=slide('Monte Carlo studies and the captured case',
    'The Monte Carlo workspace starts with a copy of the app startup case. Selecting another flight case on Settings does not automatically recapture it. Use current settings as baseline explicitly snapshots the current settings. Capturing a new baseline detaches the open study. A loaded design has its own saved baseline. Only selected variation rows and the chosen noise-seed policy change between trials. All parameters apply before calibration and flight release.');
  paragraphs(s,[
    '1. On Settings, choose a flight case and configure its duration, commands, initial state, noise, filters and firmware.',
    '2. Open Monte Carlo and select Use current settings as baseline. Confirm the captured case name, mode and noise state.',
    '3. Add the parameters you want to vary. Every trial runs that captured case with its sampled values.',
    'Changing Settings later does not update the snapshot. Capture the baseline again, or load a design containing the intended case.'
  ]);

  s=slide('Sampling and noise settings',
    'Design seed controls reproducible parameter samples. Random sampling uses independent draws. Latin hypercube stratifies each independent percentile dimension. A separate RNG stream assigns distinct per-trial noise seeds. Common noise seeds preserve the baseline seed, but rate or RNG-consumption changes can alter physical noise histories. Noise OFF remains OFF. Nominal runs use baseline parameters and are excluded from population statistics. Calibration runs in each trial and may compensate sampled biases. The framework permits 1 to 10000 sampled trials and 1 to 4 workers.');
  await screenshot(s,'walkthrough_mc_sampling.png',[
    'Set trial count and design seed. Latin hypercube spreads samples across each input range.',
    'Independent noise seeds vary the noise realization. Common seeds reuse the baseline seed.',
    'One worker uses less memory. Up to four workers run separate trials in parallel.',
    'Include nominal to compare the baseline. It stays outside the population statistics.'
  ]);

  s=slide('Parameter variations',
    'Type a fragment in the parameter field and select an exact catalog path. The label shows the baseline and constraints. Distribution argument order appears below the editor. Supported distributions: uniform, normal, truncated normal, log uniform, triangular, choices and fixed. Normal is unbounded. Truncated normal and positive log uniform can enforce appropriate physical ranges. Parameter options cover runtime plant, sensor, initial-state, command and native scalar firmware settings. Hardware-only firmware settings may have no effect in this model. Preview validates every sampled case without clipping or resampling invalid cases.');
  await screenshot(s,'monte_carlo_design_ui.png',[
    'Choose a variation example or search for a parameter. Check its baseline value and units.',
    'Select the distribution and value convention. Enter its parameters in brackets.',
    'Press Add / update parameter. Select an existing row to edit or remove it.',
    'Preview sampled values validates every case before starting any simulation.'
  ]);

  s=slide('Variation values and coupled inputs',
    'Percent change means baseline*(1+draw/100), offset means baseline+draw, and absolute means draw. The supplied example mass is 0.11 kg. Native integer firmware settings use nearest-integer rounding. Percentile groups create fully shared or reversed percentile ranks, not an arbitrary covariance matrix or partial correlation coefficient. Inactive derived aliases are rejected. The current generated plant exposes diagonal inertia only. Angular UI initial states and references use degrees and degrees/s. Sensor and native firmware parameters retain their displayed units.');
  table(s,[['Convention','Example entry','Effect in a trial'],
    ['Percent change','Mass: uniform [-5, 5]','A 0.11 kg baseline spans 0.1045 to 0.1155 kg.'],
    ['Offset','Initial roll: uniform [-1, 1]','A 5° baseline spans 4° to 6°.'],
    ['Absolute','ANGLE P: choices [18, 20, 22]','The sampled value directly sets the gain.'],
    ['Percentile group','Roll and pitch P: rate_p','Both use the same percentile. Prefix one group with - to reverse it.'],
    ['Noise seeds only','No variation rows','Independent seeds vary noise while retaining the case parameters.']
  ],[250,390,520],145,430);
  text(s,'Angular initial states and references use degrees. Firmware integer settings round to menu values. Preview shows the exact values that will run.',60,605,1160,85,26,false,muted);

  s=slide('Batch execution and trial review',
    'Start new study creates an immutable design and sample table before executing any trial. Each trial has its own native process and archive. Pause stops queued trials; active startup calibration may finish before the flight pauses. Stop preserves completed results and leaves pending work resumable. Resume uses the saved samples and seeds. Retry failed trials reruns engine/analysis failures in new attempt folders, not completed trials that merely miss criteria. Resume rejects a changed executable hash. Double-clicking a completed trial opens the ordinary Explore page with full-resolution data.');
  await screenshot(s,'walkthrough_mc_trials.png',[
    'Start new study after a successful preview. The table shows execution and criteria separately.',
    'Pause holds the batch. Stop keeps completed trials and leaves remaining work resumable.',
    'Resume pending uses the saved samples. Enable Retry failed trials for execution failures.',
    'Double-click a trial to inspect its full signals in Explore. Load its settings to rerun it.'
  ]);

  s=slide('Response envelopes in the analysis page',
    'The analysis page collapses study controls and shows only relevant selectors. Show study controls reveals setup and batch actions. Response envelopes use the saved common display grid and at most 20 faint trial traces. Shading is pointwise empirical 5th to 95th percentiles of completed sampled trials. It is not a statistical confidence interval or a bound on complete trajectories. Nominal is a separate comparison. Failed and stopped trials do not enter numeric distributions, and outcome counts identify them separately. Display-grid interpolation can miss peaks. Scalar metrics use full-resolution logs.');
  await screenshot(s,'monte_carlo_analysis_ui.png',[
    'Choose Response envelope, a signal, and the completed-trial subset.',
    'The line shows the median. Shading shows pointwise 5th to 95th percentiles.',
    'Nominal is a separate comparison. The shaded spread is not a confidence interval.',
    'Undock enlarges the plot. Export saves it. Metrics use full logs, beyond the display grid.'
  ]);

  s=slide('Metrics and pass/fail criteria',
    'Analysis begins at the configured flight time, excluding startup. RMS uses time weighting. Tracking error is True minus requested command, while estimation error is True minus Estimated with wrapped angular differences. Settling begins after the final actual logged roll/pitch command change, or analysis start if later, and requires both axes inside the band until the end for the minimum final settled interval. Settling is unavailable for raw receiver mode or unsettled runs. All criteria must pass; missing required metrics fail their criterion. Reprocess recalculates full-resolution scalar metrics from saved runs and archives previous analysis settings without rerunning simulations.');
  table(s,[['Metric','Definition','Units'],
    ['Tracking RMS','Larger roll/pitch true-minus-command RMS; use the ANGLE or RATE metric for the case.','deg or deg/s'],
    ['Attitude estimation RMS','Larger roll/pitch RMS of wrapped True minus Estimated attitude.','deg'],
    ['Settling time','Both axes remain inside the final-command band through the end, for the minimum hold interval.','s'],
    ['Other performance limits','Peak tilt/rate, displacement from release, final attitude, and time near motor output rails.','Shown per metric']
  ],[295,675,190],145,420);
  text(s,'In Study design, set the analysis window, settling bands and limits. Reprocess metrics updates saved results without rerunning. Unavailable metrics fail required limits.',60,592,1160,100,26,false,muted);

  s=slide('Comparing outcomes across trials',
    'Metric distribution contains a histogram and empirical CDF. Parameter response uses the selected sampled input and metric, colored by criteria outcome. Sensitivity ranks numeric, nonconstant inputs by Spearman rank correlation and omits categorical variables. Coupled inputs can confound attribution. Outcomes/convergence shows all sampled trial statuses, while the running mean uses completed trials with the selected metric in trial-ID order. Convergence of one mean is not proof of tail-probability or distribution convergence. A 24-trial example is a workflow demonstration rather than a quantified reliability guarantee.');
  table(s,[['View','What it shows','How to use it'],
    ['Metric distribution','Histogram and cumulative fraction','See spread, tails and the fraction below a requirement.'],
    ['Parameter response','Sampled input versus metric','Inspect trends and cases that miss the limits.'],
    ['Sensitivity','Spearman rank association','Find candidate influences for follow-up studies.'],
    ['Outcomes / convergence','Trial status counts and running mean','Check failures and whether a metric stabilizes with more trials.']
  ],[300,390,470],145,405);
  text(s,'Inspect execution failures separately. A stable running mean does not establish convergence of rare outcomes. Coupled inputs can make sensitivity rankings ambiguous.',60,595,1160,100,26,false,muted);

  s=slide('Sensitivity in the noisy-recovery example',
    'Source: verification/monte_carlo_example.json and its recorded study; docs/images/walkthrough_mc_sensitivity.png. The figure uses the same mc_charts.prepare and render calculations as the application, with larger labels for presentation. Metric: worst roll/pitch ANGLE tracking RMS, full 0 to 10 s window, 24 complete sampled trials. Initial roll has the strongest absolute Spearman association in this sample. The metric includes the initial recovery transient. This is an observed association, not a causal ranking or a universal airframe result.');
  text(s,'The selected metric is ANGLE tracking RMS over the full 10-second recovery. Initial tilt contributes to that metric.',60,123,1160,85,27);
  s.images.add({blob:new Uint8Array(await fs.readFile(path.join(here,'images/walkthrough_mc_sensitivity.png'))),contentType:'image/png',alt:'Spearman parameter associations for the saved 24-trial noisy recovery study',fit:'contain',position:{left:60,top:215,width:1160,height:390}});
  text(s,'Use a later analysis start and Reprocess metrics when comparing behavior after recovery. Shared gain groups limit attribution to an individual gain.',60,615,1160,80,25,false,muted);

  s=slide('Saved studies, reuse and export',
    'Study folders are under the selected results library/monte_carlo/study-id. Save design includes the captured baseline, distributions and analysis configuration for a new study. Open study selects study.json to reopen existing results or resume exact pending samples. New study always creates a separate folder. study.json stores the original design and executable hash; analysis.json stores current postprocessing; analysis_history retains older definitions. Each attempt stores ordinary settings/data-only native run archives; no model or initialization-script copies. signals.h5 retains full logged signals while ensemble.h5 contains a bounded display grid.');
  table(s,[['Action / file','Purpose'],
    ['Save design / Load design','Reuse the captured baseline and sampling rules for a new study.'],
    ['Open study: study.json','Reopen saved results or resume the exact pending samples.'],
    ['Export menu','Save plot PNG/PDF, envelope CSV, and metrics CSV/summary JSON.'],
    ['runs/trial_…/signals.h5','Full logged signals and settings for individual attempts.'],
    ['samples.csv / ensemble.h5','Exact sampled inputs and noise seeds / cached display curves.']
  ],[510,650],145,430);
  text(s,'The existing Explore tools remain available for each trial. Saving a reusable design and reopening a completed study serve different workflows.',60,610,1160,80,26,false,muted);

  s=slide('Reproducing the supplied recovery study',
    'Source: presets/monte_carlo_recovery.json and verification/monte_carlo_example.json. Baseline: 10 s ANGLE recovery from roll +5 deg and pitch -3 deg to zero angles, noise ON, 5 Hz gyro/accel filters, BMI270 timing, ODE5 base 16000 Hz, logging 4000 Hz. Design: 24 Latin-hypercube trials, seed 7421, independent noise seeds, 2 workers, nominal included. Variations: mass/arm +/-5%, actuator time constant +/-10%, initial roll/pitch offsets +/-1 deg, roll/pitch P +/-10% sharing rate_p. Limits: peak tilt <=20 deg and worst roll/pitch estimation RMS <=3 deg. Recorded study: 24 complete and 24 pass, maximum peak tilt 7.1174878 deg, maximum estimation RMS 1.1060498 deg. The thresholds do not impose position or altitude hold.');
  paragraphs(s,[
    '1. Select Load design and open DesktopSIL/presets/monte_carlo_recovery.json. Its baseline already contains the complete flight case.',
    '2. Preview the 24 samples plus nominal, then start the study. It varies mass, arm length, actuator response, initial tilt and P gains.'
  ],60,138,1150,110,27);
  table(s,[['Recorded example result','Value'],['Sampled trials completed / passed','24 / 24'],['Largest peak tilt among trials','7.12° against a 20° limit'],['Largest attitude estimation RMS','1.11° against a 3° limit']],[760,400],370,230);
  text(s,'These results apply to the stated example and limits. Fixed throttle leaves altitude and position uncontrolled. Choose limits that match your own test objective.',60,620,1160,75,25,false,muted);
}
