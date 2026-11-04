// Rebuild with the bundled artifact-tool libraries linked under docs/build/node_modules.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {appendMonteCarloSlides} from './monte_carlo_slides.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(here,'build/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs')).href);
const skill='C:/Users/bmatt/.codex/plugins/cache/openai-primary-runtime/presentations/26.1026.10807/skills/presentations';
const runtime='C:/Users/bmatt/.cache/codex-runtimes/codex-primary-runtime/dependencies';
process.env.RUNTIME_NODE_MODULES=path.join(runtime,'node/node_modules');
const {finalizePresentation,resolvePresentationFont}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const font=resolvePresentationFont({fontFamily:'Segoe UI'});
const deck=Presentation.create({slideSize:{width:1280,height:720}});
const ink='#182639',muted='#4E6076',accent='#B87912';
function text(s,value,x,y,w,h,size=26,bold=false,color=ink){
  const box=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
  box.text=value;box.text.style={typeface:font,fontSize:size,bold,color};return box;
}
function slide(title,notes=''){
  const s=deck.slides.add();s.background.fill='#F7F8FA';
  text(s,title,54,36,1170,70,44,true);
  s.speakerNotes.text=notes;
  return s;
}
function paragraphs(s,items,x=60,y=160,w=1150,spacing=105,size=27){
  items.forEach((v,i)=>text(s,v,x,y+spacing*i,w,spacing-12,size));
}
async function screenshot(s,file,items){
  paragraphs(s,items,54,154,315,132,25);
  s.images.add({blob:new Uint8Array(await fs.readFile(path.join(here,'images',file))),contentType:'image/png',alt:file.replaceAll('_',' ').replace('.png',''),fit:'contain',position:{left:392,top:120,width:834,height:584}});
}
function table(s,values,widths,y=150,height=470){
  const t=s.tables.add({rows:values.length,columns:values[0].length,left:60,top:y,width:1160,height,columnWidths:widths,values});
  t.borders.assign({fill:'#D8DEE7',width:1,style:'solid'});
  for(let r=0;r<values.length;r++)for(let c=0;c<values[0].length;c++){
    const cell=t.getCell(r,c);cell.fill=r===0?'#182639':(r%2?'#FFFFFF':'#EDF1F6');
    cell.text.style={typeface:font,fontSize:24,color:r===0?'#FFFFFF':ink,bold:r===0};
  }
  return t;
}
let s=deck.slides.add();s.background.fill='#182639';
text(s,'Native desktop\nflight simulation',64,145,1130,200,68,true,'#FFFFFF');
text(s,'User workflow, Monte Carlo studies, generated C and Betaflight SITL',68,395,1100,100,31,false,'#D5DFEB');
text(s,'feature/SITL_sim_Codex     Updated November 4, 2026',68,610,1100,48,24,false,'#F0BC61');
s.speakerNotes.text='Companion guide: DesktopSIL/README.md. This implementation is a Python/Tk interface around generated Simulink C linked directly with the actual pinned Betaflight SITL firmware. The original Simulink model and MATLAB workbench were preserved.';

s=slide('Opening the application','Sources: DesktopSIL/Open Desktop SIL.cmd, launch.ps1, setup-python.ps1. These instructions refer to the current prepared workspace. Python dependencies and the native engine are already built on this computer. A fresh clone needs the setup/build steps in README.md.');
paragraphs(s,[
  '1. In File Explorer, open the UCI_FWMAV_Flight_Control_Simulation_and_Development project folder.',
  '2. Open DesktopSIL and double-click Open Desktop SIL.cmd. It starts the Python desktop interface.',
  '3. Choose Noisy trimmed hover and press Run simulation. The GUI launches the native engine automatically.',
  'MATLAB is needed to regenerate the plant, not to run this desktop simulation. Setup and rebuild commands are in DesktopSIL/README.md.'
],60,145,1150,125,28);

s=slide('Run setup','Sources: DesktopSIL/app.py, parity_ui.py, presets/noisy_hover.json. Screenshot from a completed 10-second noisy hover run. The total time shown includes firmware configuration and HDF5 archiving.');
await screenshot(s,'run_setup.png',[
  'Open “Open Desktop SIL.cmd” and choose a complete flight case.',
  'Duration, fidelity, throttle, noise, drag and logging share one page.',
  'Press Run. Changes apply to the next flight without recompilation.',
  'Save settings creates a reusable JSON configuration.'
]);
s=slide('PID gains and firmware profiles','Sources: DesktopSIL/configuration.py and parity_ui.py. Default roll P/I/D/F = 133/4/0/0, pitch = 134/4/0/0, yaw = 0/0/0/0, angle P = 20. These are native menu values, not torque gains. The screenshot shows the default active profile.');
await screenshot(s,'pid.png',[
  'Select PID, rate and battery profiles before editing their settings.',
  'Roll, pitch and yaw gains use native Betaflight menu units.',
  'Angle P is the outer attitude-loop gain for ANGLE mode.',
  'The 409-setting catalog and complete CLI share this configuration.'
]);
s=slide('Simulated sensors and native filters','Sources: DesktopSIL/native/desktop_sil.c, generated/hover_plant_sil_ert_rtw/hover_plant_sil.c, configuration.py. Noise mask power = density² × bandwidth; the white-noise block divides by its sample period. Both default firmware LPF cutoff values are 5 Hz, but gyro and accel filter types are different. Resolution fields are metadata; firmware ADC quantization is fixed.');
await screenshot(s,'sensors.png',[
  'Sensor rate, range, bias, white noise and vibration define the measurements.',
  'Firmware filters process those measurements after the virtual ADC.',
  'The examples use 5 Hz gyro and accelerometer low-pass cutoffs.',
  'Noise stays enabled. The toolbar toggle is visible on every page.'
]);
s=slide('Default plots','Sources: DesktopSIL/parity_ui.py and plots.py. Default plots begin at the complete run extent. Rendering uses extrema-preserving downsampling; logged data is retained. Native position/velocity estimates are explicitly unavailable, rather than showing reserved zeros.');
await screenshot(s,'default_plots.png',[
  'Choose a saved run and a view: attitude, rates, motion, errors, motors or raw IMU.',
  'Wheel zooms time. Drag pans. Full duration restores the complete run.',
  'Undock opens an independent plot window. Export creates PNG or PDF.',
  'The default-plots toggle does not disable signal logging.'
]);
s=slide('Explore and compare signals','Sources: DesktopSIL/parity_ui.py, plots.py, storage.py. Actual mouse double-click was verified in the visible application. Each signal retains its own time grid. Degrees and Stored units affect displayed angular values, not logged samples.');
await screenshot(s,'explore.png',[
  'Filter by signal name or group, then double-click to plot.',
  'Choose overlay, replace, or a new plot. Load another run to compare it.',
  'Select legend rows to remove individual traces, or clear the entire plot.',
  'Export full logged samples as CSV or MATLAB timeseries.'
]);
s=slide('Flight analysis','Sources: DesktopSIL/analysis.py and parity_ui.py. RMS is time weighted across the whole selected run, including command transients. Native PID contributions are not torque. The example pictured uses ANGLE roll tracking.');
await screenshot(s,'analysis.png',[
  'Choose a run and axis. Analysis reads that run’s saved settings.',
  'Tracking separates requested command, plant response and firmware feedback.',
  'Other panels show estimation error, PID terms, motors and raw gyro error.',
  'Seven panels separate attitude/rate estimation error from raw sensor error.'
]);
s=slide('Plant model used for C generation','Sources: DesktopSIL/matlab/buildPlantCode.m and model/hover_plant_sil.slx. The picture is an export of the actual generated-model source, not a redrawn schematic. It contains copied original actuator, dynamics, ideal IMU, sensor and sample blocks. Betaflight is linked separately in the native executable.');
text(s,'The original blocks are copied into separate linear and nonlinear models. The source simulation remains unchanged.',60,125,1150,70,27);
s.images.add({blob:new Uint8Array(await fs.readFile(path.join(here,'images/generated_plant.png'))),contentType:'image/png',alt:'Actual Simulink plant prepared for C generation',fit:'contain',position:{left:75,top:215,width:1130,height:460}});

s=slide('Closed-loop data and timing','Sources: DesktopSIL/native/desktop_sil.c, plant_adapter.c and Betaflight/host/bf_host.c. The adapter calls the actual host step function directly. Native sensor values are delivered as virtual ADC measurements; truth attitude is not substituted for estimator feedback. Maximum solver step is 1/16000 s, with shorter steps to reach configured events.');
table(s,[['Stage','Data / behavior','Current BMI270 defaults'],['Firmware output','Four motor commands minus plant hover trim','PID / mixer: 3.2 kHz'],['Actuator and dynamics','Original actuator response; linear or nonlinear motion','ODE5: max step 1/16000 s'],['Ideal IMU and sensors','Body rates and specific force, with noise and bias','Gyro 3.2 kHz\nAccel 800 Hz'],['Betaflight input','Virtual ADC, calibration, filters, estimator, PID and mixer','ANGLE attitude: 400 Hz\nRATE attitude: 100 Hz'],['Command and logging','Receiver frames, held references and independently sampled logs','RC 100 Hz\nLogging 4 kHz']],[230,610,320],145,450);
text(s,'The UI uses degrees. Plant and archived angular signals use radians. Receiver and motor values use µs / pot.',60,625,1160,65,25,false,muted);

s=slide('Generating and compiling C','Sources: DesktopSIL/matlab/buildPlantCode.m, build.ps1. MATLAB R2025b Update 3, Simulink Coder and Embedded Coder were already installed. ert.tlc generates C with continuous-time support, fixed-step ode5, tunable parameters, separate output/update and code-only generation. Cygwin GCC 13.5 compiles and links the generated plant and actual firmware. Generated Academic License headers are preserved.');
paragraphs(s,[
  '1. Copy the existing plant and sensors into hover_plant_sil.slx and hover_linear_sil.slx.',
  '2. Generate C with Embedded Coder: ERT target, ODE5, tunable parameters and separate output/update functions.',
  '3. Compile the generated C and native adapter with GCC and link them into the pinned Betaflight SITL executable.',
  '4. Run without MATLAB. Rebuild only when equations, blocks, or firmware source change.'
],60,145,1145,125,29);

s=slide('Applications and programming languages','Sources: DesktopSIL/requirements.txt, build.ps1, app.py, runner.py. This is a rewritten desktop UI, not automatically generated App Designer code. Python handles configuration and charts; flight stepping stays in C. Cygwin DLLs are packaged next to the executable.');
table(s,[['Component','Technology','Purpose'],['Modeling / generation','MATLAB + Simulink + Embedded Coder','Original blocks, C generation and numerical verification'],['Flight computation','C + actual Betaflight SITL','Plant integration, simulated sensors and flight software'],['Native build','Cygwin GCC + PowerShell','Compile and link the standalone executable'],['Desktop interface','Python + Tk','Configuration, run control and interactive plots'],['Data / exports','NumPy, h5py, SciPy, Matplotlib','HDF5, CSV, MATLAB files, PNG and PDF']],[270,390,500],145,480);

s=slide('Critical file locations','Paths are relative to the repository root. Full file map and rebuild commands: DesktopSIL/README.md. Runtime outputs and the Python environment are ignored by Git and are rebuilt on a fresh checkout.');
table(s,[['Under DesktopSIL/','Role'],['Open Desktop SIL.cmd','Launch the application'],['app.py; parity_ui.py','Desktop pages, run controls and analysis UI'],['native/desktop_sil.c; plant_adapter.c','Native closed loop and generated-model interface'],['matlab/buildPlantCode.m; model/','Reproducible code-generation workflow and copied models'],['generated/*_ert_rtw/','Generated C and header files'],['build/hover_desktop_sil.exe; build/venv/','Runnable engine and isolated Python environment']],[650,510],145,490);

s=slide('Run archives and MATLAB interoperability','Sources: DesktopSIL/storage.py and runner.py. Transient binary spool is removed only after a completed HDF5 archive has been closed and installed. No model or script copies are included in each run. Existing MATLAB v7.3 workbench run.mat files are supported; selected.mat + helper were loaded using the MATLAB MCP server and yielded three timeseries with 8001 samples.');
table(s,[['Saved item','Contents'],['settings.json + derived.json','Input configuration and calculated plant values'],['configuration.cli + native EEPROM','Effective firmware configuration'],['signals.h5','Signal values, time grids, units and groups'],['metadata.json + engine_summary.json','Firmware pin, executable SHA256, timing and status'],['engine / configuration logs','Diagnostics for setup or run failures']],[490,670],145,400);
text(s,'CSV/MAT exports keep every logged sample. The MATLAB helper creates hoverSignals timeseries and hoverRun metadata.',60,590,1150,80,28);

s=slide('Verification and November 1 benchmarks','Sources: DesktopSIL/verification/runtime_plant_equivalence.json, native_acceptance.json and ui_acceptance.json. Seven ODE5 plant tests used asymmetric motor inputs [3,-2,1,4], both fidelities, noise on/off, changed mass, drag, actuator, sensor density and rates. Every case was below 3.1e-14. Error is component-wise across different physical units. The 3.62-second engine timing is a sample measurement, not a controlled benchmark against MATLAB, and excludes HDF5 archiving.');
table(s,[['Check','Observed result'],['Generated ODE5 C versus Simulink','Seven cases passed; maximum absolute difference < 3.1 × 10⁻¹⁴'],['Actual firmware replay','29,202 exchanges; all 40 response values exactly equal'],['Desktop workflow','Repeated runs, 15 views, seven analysis panels, import/export passed'],['60-second noisy ODE5 run','3.62 s engine time; 960,001 rows; 239.9 MB HDF5 archive'],['Five-minute step-halving tests','Quiet and noisy cases converge; details on the following slides']],[465,695],145,425);
text(s,'In the 60-second case, roll/pitch stayed within 1.46°. Position drift remains because the example has no altitude or position control.',60,600,1160,78,26,false,muted);

s=slide('Scope and first review','Sources: DesktopSIL/README.md, native/desktop_sil.c, configuration.py. Known differences: stationary startup fixture uses a different normal RNG transformation from MATLAB; free-flight noise uses generated Simulink code. This is not a hard real-time target. Full firmware catalog does not imply all hardware/peripherals are modeled. Runtime parameters are applied between runs.');
paragraphs(s,[
  'Review the noisy hover and recovery cases first, then angle pulses and rate doublets. Compare true attitude with the estimate and raw IMU.',
  'The current plant has no altitude sensor, position controller, or nonlinear thrust-generated yaw moment. Fixed throttle does not guarantee altitude hold.',
  'Startup fixture noise differs from MATLAB’s random normal transformation. The generated free-flight plant and actual firmware were verified separately.',
  'Use README.md for rebuild commands, file locations and archive details. Settings changes apply to the next run. Live parameter editing is not implemented.'
],60,145,1150,126,28);

s=slide('Estimated outputs and filtered inputs','Sources: Betaflight/host/bf_host.c makeResponse; pinned Betaflight src/main/flight/imu.c and src/main/sensors/gyro.c; DesktopSIL/build.ps1 passive telemetry taps; storage.py and analysis.py. gyro.gyroADCf is rate-controller feedback. Mahony additionally consumes gyroGetFilteredDownsampled and accAdc. Internal Mahony correction rates are exposed only as propagation diagnostics.');
table(s,[['Term in the app','Exact meaning'],['Estimated attitude','Mahony attitude output; native Euler telemetry quantized to 0.1°'],['Estimated body rates','Processed gyro used for rate feedback; Mahony has no separate p/q/r state'],['Filtered gyro / accel into Mahony','Exact input arguments after firmware filtering and calibration'],['Estimation errors','True − Estimated; attitude differences wrap to ±180°'],['Raw gyro sensor error','Raw − Ideal, before firmware processing; a separate diagnostic']],[430,730],145,445);
text(s,'Mahony propagation-rate diagnostics are also logged. Postprocessing does not differentiate attitude to invent a rate estimate.',60,615,1160,75,25,false,muted);

s=slide('ODE5 and the drift investigation','Sources: verification/integrator_convergence.json, runtime_plant_equivalence.json. ODE5 is fifth-order Dormand–Prince: https://www.mathworks.com/help/simulink/ug/fixed-step-solvers-in-simulink.html . Fixed-step is a requirement of the chosen ERT generation route, not a physical requirement of the plant. Tests compare identical settings and seeds. Position/attitude figures below are maximum component-wise differences over saved samples.');
table(s,[['Comparison','Max attitude difference','Max position difference'],['ODE3 vs ODE5: noisy 60 s','6.61 × 10⁻¹² degrees','2.66 × 10⁻¹¹ m'],['ODE5, 16 vs 32 kHz: quiet 300 s','2.50 × 10⁻¹¹ degrees','2.46 × 10⁻⁹ m'],['ODE5, 16 vs 32 kHz: noisy 300 s','3.18 × 10⁻¹¹ degrees','1.02 × 10⁻⁹ m']],[600,280,280],150,320);
paragraphs(s,[
  'ODE5 remains the default. Integration options are 3.2, 4, 6.4, 8, 16, 32 and 64 kHz, with shorter steps at event times.',
  'These cases do not show integration-driven drift. Estimator bias, feedback quantization and uncontrolled position can still cause motion.'
],60,510,1150,89,27);

s=slide('Updating the plant from Simulink','Sources: DesktopSIL/matlab/buildPlantCode.m, native/plant_adapter.c, native/desktop_sil.c, configuration.py, README.md. This is the current workflow; automatic arbitrary-plant plugin loading is not implemented. The builder references named source blocks and the C adapter references generated parameter fields.');
paragraphs(s,[
  '1. Edit and validate the original Simulink plant. Keep the current input/output contract when possible.',
  '2. In MATLAB, run buildPlantCode("high") and buildPlantCode("low"). Then run DesktopSIL/build.ps1 in PowerShell.',
  '3. Run plant-equivalence, native-flight and step-halving checks. Start a new desktop run with the rebuilt engine.',
  'New ports, block names or parameters also require adapter/schema updates. Edit the Simulink source. Regeneration replaces the generated C.'
],60,145,1150,125,28);

s=slide('A modular plant for different airframes','Proposed future architecture, not yet implemented. For actuator i, R_i maps its local frame to the body frame and r_i is its body-frame position relative to the CG. Sum body forces and moments including reaction torque and aerodynamic loads; handle gravity once in the chosen dynamics convention. A reusable rigid-body model integrates force/moment, with separate sensors. The current adapter assumes four motor outputs and the existing mixer; arbitrary geometry/count requires matching control allocation and interfaces. MathWorks modular subsystem guidance: https://www.mathworks.com/help/simulink/slref/subsystem.html .');
paragraphs(s,[
  'Actuators: map commands to each flapper’s local force and reaction moment, including its dynamic response.',
  'Mount geometry: rotate local forces into body axes and add r × F moments about the center of gravity.',
  'Rigid-body dynamics: integrate total body force/moment using mass, inertia and a consistent gravity convention. Keep sensor models separate.',
  'Arm lengths, mount orientations and actuator models become configuration data. The mixer/control allocator must match the resulting control authority.'
],60,145,1150,125,28);

s=slide('Python development and executable distribution','Source: https://pyinstaller.org/en/stable/operating-mode.html . PyInstaller one-folder builds bundle the interpreter and dependencies; one-file builds extract dependencies on startup and start more slowly. DesktopSIL already has a native C executable; the GUI is Python/Tk. Packaging is a distribution step and does not accelerate the compiled flight loop. No tested installer has been produced yet.');
paragraphs(s,[
  'For ongoing development, keep the Python interface and isolated environment. The launcher already opens it without terminal commands.',
  'For other users, bundle the GUI, Python/Tk libraries, catalogs, presets, native engine and runtime DLLs into an application folder with a shortcut.',
  'A single-file executable is possible, but a one-folder package is easier to debug and avoids unpacking all dependencies at every launch.',
  'Packaging changes installation, not solver speed. Keep run archives in a writable data folder outside the installed application.'
],60,145,1150,125,28);

await appendMonteCarloSlides(deck,{here,font});
await fs.mkdir(path.join(here,'build/rendered'),{recursive:true});
for(const [i,sl] of deck.slides.items.entries()){
  const png=await deck.export({slide:sl,format:'png',scale:1});
  await fs.writeFile(path.join(here,'build/rendered',`slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));
}
await fs.mkdir(path.join(here,'build/final'),{recursive:true});
const publicationFile=path.join(here,'build/final',`Desktop_SIL_Walkthrough_${Date.now()}.pptx`);
const candidate=path.join(here,'build/candidate.pptx');
await (await PresentationFile.exportPptx(deck)).save(candidate);
const result=await finalizePresentation({workspaceDir:path.dirname(here),candidatePath:candidate,finalPath:publicationFile,
  pythonExecutable:path.join(runtime,'python/python.exe'),integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),
  layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit',...[10,12,13,14,15,17,18,25,28,29,31,32].flatMap(n=>['--require-native-table-slide',String(n)])],
  explicitTotalSlideCount:32,requiredNativeTableOwnerSlides:[10,12,13,14,15,17,18,25,28,29,31,32],fontPolicy:{basis:'design',families:[font]},verifyArtifactToolImport:true,
  receiptPath:path.join(here,'../build/presentation_validation.json')});
await fs.copyFile(publicationFile,path.join(here,'Desktop_SIL_Walkthrough.pptx'));
console.log(JSON.stringify(result));
