import {readFile,writeFile,readdir} from 'node:fs/promises';
import {resolve,join,relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {previewOfflineWorker} from './preview_offline_worker.mjs';
import {startPreviewOffline} from './preview_offline_bootstrap.mjs';

export function isStaticAsset(path) {
  if(path.includes('..') || path.includes('\\') || path.includes('?') || path.endsWith('.map')) return false;
  return ['index.html','flutter_bootstrap.js','main.dart.js','flutter.js','manifest.json','favicon.png',
    'canvaskit/canvaskit.js','canvaskit/canvaskit.wasm'].includes(path) ||
    /^(assets|icons)\//.test(path);
}
export async function preparePreviewOffline(directory) {
  const root=resolve(directory);
  const bootstrapPath=join(root,'flutter_bootstrap.js');
  const bootstrap=await readFile(bootstrapPath,'utf8');
  // Flutter downloads default Roboto unless that family exists in the manifest.
  // Alias the existing bundled Rubik regular face for that default role too;
  // no dependency on obsolete SDK Roboto files, new fonts or remote downloads.
  const fontManifestPath=join(root,'assets/FontManifest.json');
  const fonts=JSON.parse(await readFile(fontManifestPath,'utf8'));
  const regular=fonts.find(font=>font.family==='Rubik')?.fonts.find(font=>font.weight===400);
  if(regular?.asset!=='assets/fonts/Rubik-Regular.ttf') throw new Error('Bundled Rubik regular face required');
  await readFile(join(root,'assets',regular.asset));
  await writeFile(fontManifestPath,JSON.stringify([
    ...fonts.filter(font=>font.family!=='Roboto'),{family:'Roboto',fonts:[{asset:regular.asset}]},
  ]));
  const marker='_flutter.loader.load(';
  const preparedOffset=bootstrap.indexOf('(function startPreviewOffline(');
  const offset=preparedOffset>=0?preparedOffset:bootstrap.lastIndexOf(marker);
  if(offset<0 || (preparedOffset<0 && bootstrap.indexOf(marker)!==offset)) throw new Error('Unexpected Flutter bootstrap shape');
  await writeFile(bootstrapPath,bootstrap.slice(0,offset)+`(${startPreviewOffline.toString()})();\n`);
  const indexPath=join(root,'index.html');
  const index=await readFile(indexPath,'utf8');
  await writeFile(indexPath,index.replace(/\s*<link\b[^>]*href="https:\/\/fonts\.(?:googleapis|gstatic)\.com[^>]*>/g,''));
  async function walk(directory) {
    const files=[];
    for(const entry of await readdir(directory,{withFileTypes:true})) {
      const path=join(directory,entry.name);
      if(entry.isDirectory()) files.push(...await walk(path));
      else if(entry.isFile()) files.push(path);
    }
    return files;
  }
  const assets=[];
  let bytes=0;
  for(const path of (await walk(root)).sort()) {
    const name=relative(root,path).replaceAll('\\','/');
    if(!isStaticAsset(name)) continue;
    const content=await readFile(path);
    bytes+=content.length;
    assets.push({path:name,integrity:'sha256-'+createHash('sha256').update(content).digest('base64')});
  }
  for(const required of ['index.html','flutter_bootstrap.js','main.dart.js',
    'canvaskit/canvaskit.js','canvaskit/canvaskit.wasm','assets/FontManifest.json']) {
    if(!assets.some(asset=>asset.path===required)) throw new Error(`Missing static asset: ${required}`);
  }
  const version=createHash('sha256').update(previewOfflineWorker.toString()).update(JSON.stringify(assets)).digest('hex').slice(0,24);
  await writeFile(join(root,'flutter_service_worker.js'),
    `// Preview-only static application cache. Never caches API traffic.\n(${previewOfflineWorker.toString()})(self,${JSON.stringify({version,assets})});\n`);
  await writeFile(join(root,'offline-build.json'),JSON.stringify({version,assetCount:assets.length,bytes})+'\n');
  return {version,assetCount:assets.length,bytes};
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(await preparePreviewOffline('build/web')));
}
