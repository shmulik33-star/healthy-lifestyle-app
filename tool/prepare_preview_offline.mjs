import {readFile,writeFile,readdir,mkdir,copyFile} from 'node:fs/promises';
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
export async function preparePreviewOffline(directory,{flutterRoot=process.env.FLUTTER_ROOT}={}) {
  const root=resolve(directory);
  const bootstrapPath=join(root,'flutter_bootstrap.js');
  const bootstrap=await readFile(bootstrapPath,'utf8');
  if(bootstrap.includes('function startPreviewOffline')) throw new Error('Already prepared; rebuild Flutter first');
  if(!flutterRoot) throw new Error('FLUTTER_ROOT is required for the bundled default font');
  // Flutter otherwise downloads default Roboto during engine initialization,
  // even though the application's own theme uses its bundled Rubik family.
  const sdkFonts=join(flutterRoot,'bin/cache/artifacts/material_fonts');
  const fontManifestPath=join(root,'assets/FontManifest.json');
  const fonts=JSON.parse(await readFile(fontManifestPath,'utf8'));
  await mkdir(join(root,'assets/fonts'),{recursive:true});
  await copyFile(join(sdkFonts,'roboto-regular.ttf'),join(root,'assets/fonts/Roboto-Regular.ttf'));
  await copyFile(join(sdkFonts,'roboto_license.txt'),join(root,'assets/fonts/Roboto-LICENSE.txt'));
  if(!fonts.some(font=>font.family==='Roboto')) {
    fonts.push({family:'Roboto',fonts:[{asset:'fonts/Roboto-Regular.ttf'}]});
  }
  await writeFile(fontManifestPath,JSON.stringify(fonts));
  const marker='_flutter.loader.load(';
  const offset=bootstrap.lastIndexOf(marker);
  if(offset<0 || bootstrap.indexOf(marker)!==offset) throw new Error('Unexpected Flutter bootstrap shape');
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
