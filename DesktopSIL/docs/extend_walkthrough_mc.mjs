// Targeted edit of the original 21-slide guide; retain its source in docs/build.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {appendMonteCarloSlides} from './monte_carlo_slides.mjs';

async function main(){
  const here=path.dirname(fileURLToPath(import.meta.url));
  const runtime='C:/Users/bmatt/.cache/codex-runtimes/codex-primary-runtime/dependencies';
  const skill='C:/Users/bmatt/.codex/plugins/cache/openai-primary-runtime/presentations/26.1026.10807/skills/presentations';
  process.env.RUNTIME_NODE_MODULES=path.join(runtime,'node/node_modules');
  const {PresentationFile,FileBlob}=await import(pathToFileURL(path.join(here,'build/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs')).href);
  const {finalizePresentation,resolvePresentationFont}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
  const font=resolvePresentationFont({fontFamily:'Segoe UI'});
  const stage=path.join(here,'build/mc-update');await fs.mkdir(stage,{recursive:true});
  const original=path.join(stage,'original.pptx');
  try {await fs.access(original);} catch {await fs.copyFile(process.argv[2]??path.join(here,'Desktop_SIL_Walkthrough.pptx'),original);}
  const deck=await PresentationFile.importPptx(await FileBlob.load(original));
  if(deck.slides.items.length!==21) throw Error('Expected the original 21-slide guide as input.');
  const inspection=await deck.inspect({kind:'slide,textbox,table',maxChars:200000});
  const records=inspection.records;
  function shapeWithText(value){
    const matches=records.filter(r=>r.kind==='textbox'&&r.text===value);
    if(matches.length!==1) throw Error('Could not uniquely locate source text: '+value);
    return deck.resolve(matches[0].id);
  }
  shapeWithText('codex/desktop-sil     November 1, 2026').text='feature/SITL_sim_Codex     Updated November 4, 2026';
  shapeWithText('User workflow, generated C, Betaflight SITL and project files').text='User workflow, Monte Carlo studies, generated C and Betaflight SITL';
  shapeWithText('Verification and measured performance').text='Verification and November 1 benchmarks';
  shapeWithText('ODE5 is now the default. Run setup permits 16, 32 or 64 kHz integration while retaining independent sensor/controller rates.').text='ODE5 remains the default. Integration options are 3.2, 4, 6.4, 8, 16, 32 and 64 kHz, with shorter steps at event times.';
  const timing=deck.resolve(records.find(r=>r.kind==='table'&&r.slideIndex===9).id);
  timing.cells.set(0,2,'Current BMI270 defaults');
  timing.cells.set(1,2,'PID / mixer: 3.2 kHz');
  timing.cells.set(3,2,'Gyro 3.2 kHz\nAccel 800 Hz');
  timing.cells.set(4,2,'ANGLE attitude: 400 Hz\nRATE attitude: 100 Hz');
  timing.cells.set(5,1,'Receiver frames, held references and independently sampled logs');
  timing.cells.set(5,2,'RC 100 Hz\nLogging 4 kHz');
  deck.slides.items[9].speakerNotes.text+=' Current defaults updated November 4 from DesktopSIL/docs/Firmware_Timing.md and supplied presets. PID divider 1, attitude divider 2. Legacy cases retain their saved timing. The integration grid remains 16 kHz and logging defaults to 4 kHz.';
  deck.slides.items[14].speakerNotes.text+=' These benchmark numbers describe the earlier November 1 build and logging settings, rather than a new benchmark of the current defaults.';
  deck.slides.items[17].speakerNotes.text+=' Current integration options and event-alignment behavior: DesktopSIL/docs/Firmware_Timing.md. The measured convergence comparisons remain the original historical results.';
  await appendMonteCarloSlides(deck,{here,font});
  if(deck.slides.items.length!==32) throw Error('Expected 32 slides after extension.');
  await fs.mkdir(path.join(stage,'rendered'),{recursive:true});
  for(const [i,slide] of deck.slides.items.entries()){
    const png=await deck.export({slide,format:'png',scale:1});
    await fs.writeFile(path.join(stage,'rendered',`slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));
  }
  await fs.writeFile(path.join(stage,'final-inspection.json'),JSON.stringify(await deck.inspect({kind:'slide,textbox,table,notes',maxChars:250000}),null,2));
  const candidate=path.join(stage,'candidate.pptx');
  await(await PresentationFile.exportPptx(deck)).save(candidate);
  const outputDir=path.join(here,'build/mc-deliverables');await fs.mkdir(outputDir,{recursive:true});
  const finalPath=path.join(outputDir,`Desktop_SIL_Walkthrough_${Date.now()}.pptx`);
  const tables=[10,12,13,14,15,17,18,25,28,29,31,32];
  const result=await finalizePresentation({workspaceDir:path.dirname(here),candidatePath:candidate,finalPath,
    pythonExecutable:path.join(runtime,'python/python.exe'),integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),
    layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit',...tables.flatMap(n=>['--require-native-table-slide',String(n)])],
    explicitTotalSlideCount:32,requiredNativeTableOwnerSlides:tables,fontPolicy:{basis:'reference',families:[font],referencePath:original,referenceSha256:createHash('sha256').update(await fs.readFile(original)).digest('hex')},verifyArtifactToolImport:true,
    receiptPath:path.join(stage,'validation.json')});
  await fs.writeFile(path.join(stage,'validated-path.txt'),finalPath);
  console.log(JSON.stringify(result));
}
main().catch(e=>{console.error(e.stack?.split('\n').slice(0,6).join('\n')??String(e));process.exitCode=1;});
