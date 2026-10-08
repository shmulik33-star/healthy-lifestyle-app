import test from 'node:test';
import assert from 'node:assert/strict';
import {runInNewContext} from 'node:vm';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createServer} from 'node:http';
import {previewOfflineWorker} from './preview_offline_worker.mjs';
import {isStaticAsset,preparePreviewOffline} from './prepare_preview_offline.mjs';

function harness({host='preview.healthy-lifestyle-app.pages.dev',production=false,failPath,fetchAsset}={}) {
  const listeners={};
  const stores=new Map([['unrelated-user-cache',new Map()]]);
  const downloads=[];
  let offline=false;
  let claims=0;
  const caches={
    keys:async()=>[...stores.keys()],
    delete:async name=>stores.delete(name),
    open:async name=>{
      if(!stores.has(name)) stores.set(name,new Map());
      const store=stores.get(name);
      return {put:async(key,response)=>store.set(key,response.clone()),
        match:async key=>store.get(key)?.clone()};
    },
  };
  const scope={location:{hostname:host,origin:'https://'+host},
    clients:{claim:async()=>claims++},addEventListener:(name,listener)=>listeners[name]=listener};
  const build={version:'version-a',production,assets:[
    {path:'index.html',integrity:'sha256-a'},
    {path:'main.dart.js',integrity:'sha256-b'},
    {path:'assets/FontManifest.json',integrity:'sha256-c'},
  ]};
  runInNewContext(`(${previewOfflineWorker.toString()})(scope,build)`,{
    scope,build,caches,URL,Request,Response,AbortSignal,
    fetch:async request=>{
      downloads.push(request);
      if(offline || new URL(request.url).pathname===failPath) throw new Error('Unavailable');
      if(fetchAsset) return fetchAsset(request);
      return new Response(new URL(request.url).pathname);
    },
  });
  const lifecycle=async name=>{
    let promise;
    listeners[name]({waitUntil:value=>promise=value});
    await promise;
  };
  const request=(path,{method='GET',mode='cors'}={})=>{
    let response;
    listeners.fetch({request:{url:new URL(path,scope.location.origin).href,method,mode},
      respondWith:value=>response=value});
    return response;
  };
  return {stores,downloads,lifecycle,request,setOffline:()=>offline=true,getClaims:()=>claims};
}

test('offline asset allowlist excludes APIs, maps and arbitrary dynamic resources',()=>{
  for(const path of ['index.html','main.dart.js','assets/FontManifest.json','icons/Icon-192.png',
    'canvaskit/canvaskit.wasm']) assert.equal(isStaticAsset(path),true,path);
  for(const path of ['api/cloud/session','api/cloud/state','main.dart.js.map','version.json',
    'assets/../api/cloud/state','assets/file?password=secret','canvaskit/skwasm.wasm']) {
    assert.equal(isStaticAsset(path),false,path);
  }
});

test('complete static cache starts navigation and assets without any network',async()=>{
  const h=harness();
  await h.lifecycle('install');
  for(const request of h.downloads) {
    assert.equal(request.credentials,'omit');
    assert.equal(request.cache,'no-store');
    assert.match(request.integrity,/^sha256-/);
  }
  await h.lifecycle('activate');
  h.setOffline();
  assert.equal(await (await h.request('/',{mode:'navigate'})).text(),'/');
  assert.equal(await (await h.request('/main.dart.js')).text(),'/main.dart.js');
  assert.equal(h.downloads.length,3);
  assert.equal(h.getClaims(),1);
  assert.ok(h.stores.has('unrelated-user-cache'));
});

test('Pages canonical redirects cannot poison online or offline navigation responses',async()=>{
  const server=createServer((request,response)=>{
    if(request.url==='/index.html' || request.url==='/main.dart.js') {
      response.writeHead(308,{location:'/'}).end();
    } else response.writeHead(200,{'content-type':'text/html','x-static-test':'retained'}).end('verified shell');
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const origin='http://127.0.0.1:'+server.address().port;
  try {
    const h=harness({fetchAsset:request=>fetch(origin+new URL(request.url).pathname)});
    await h.lifecycle('install');
    assert.equal(new URL(h.downloads[0].url).pathname,'/','Download canonical document, not redirect alias');
    const redirected=await fetch(origin+'/index.html');
    assert.equal(redirected.redirected,true,'Fixture must reproduce real followed redirect');
    for(const path of ['/','/index.html','/main.dart.js']) {
      const response=await h.request(path,{mode:'navigate'});
      assert.equal(response.redirected,false,path);
      assert.equal(response.headers.get('x-static-test'),'retained');
      assert.equal(await response.text(),'verified shell');
    }
    // Defensively normalize previously cached redirected documents too.
    h.stores.get('fit-preview-shell-version-a').set('/index.html',redirected);
    h.setOffline();
    const offline=await h.request('/',{mode:'navigate'});
    assert.equal(offline.redirected,false);
    assert.equal(await offline.text(),'verified shell');
    assert.equal(h.downloads.length,3,'No offline network fallback');
  } finally {
    await new Promise(resolve=>server.close(resolve));
  }
});

test('API, cross-origin, POST and query requests are never intercepted or cached',async()=>{
  const h=harness();
  await h.lifecycle('install');
  for(const [path,options] of [
    ['/api/cloud/session',{}],['/api/cloud/state',{mode:'navigate'}],
    ['/main.dart.js',{method:'POST'}],['/main.dart.js?token=private',{}],
    ['https://other.example/main.dart.js',{}],['/private-profile',{}],
  ]) assert.equal(h.request(path,options),undefined,path);
  assert.equal(h.downloads.length,3);
});

test('failed install preserves previous cache and never activates partial build',async()=>{
  const h=harness({failPath:'/main.dart.js'});
  h.stores.set('fit-preview-shell-previous',new Map());
  await assert.rejects(h.lifecycle('install'),/Incomplete static build/);
  assert.ok(!h.stores.has('fit-preview-shell-version-a'));
  assert.ok(h.stores.has('fit-preview-shell-previous'));
  assert.ok(h.stores.has('unrelated-user-cache'));
  assert.equal(h.getClaims(),0);
});

test('worker refuses installation on production hostname',async()=>{
  const h=harness({host:'healthy-lifestyle-app.pages.dev'});
  await assert.rejects(h.lifecycle('install'),/Preview-only/);
  assert.equal(h.downloads.length,0);
});

test('explicit production build starts offline without caching API or unknown origins',async()=>{
  const h=harness({host:'healthy-lifestyle-app.pages.dev',production:true});
  await h.lifecycle('install');
  await h.lifecycle('activate');
  h.setOffline();
  assert.equal(await (await h.request('/',{mode:'navigate'})).text(),'/');
  assert.equal(h.request('/api/cloud/state'),undefined);
  assert.equal(h.request('https://other.example/main.dart.js'),undefined);
  const unknown=harness({host:'architect-ai-cloud-pilot.netlify.app',production:true});
  await assert.rejects(unknown.lifecycle('install'),/Preview-only/);
});

test('Preview preparation uses local renderer, removes external stylesheet and hashes static files',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'fit-preview-offline-'));
  try {
    await mkdir(join(directory,'canvaskit'));
    await mkdir(join(directory,'assets'));
    await mkdir(join(directory,'assets/assets/fonts'),{recursive:true});
    const files={
      'index.html':'<!DOCTYPE html><link href="https://fonts.googleapis.com/css2?family=Rubik" rel="stylesheet">',
      'flutter_bootstrap.js':'_flutter.buildConfig={};\n_flutter.loader.load({serviceWorkerSettings:{}});',
      'main.dart.js':'console.log("app");',
      'canvaskit/canvaskit.js':'renderer',
      'canvaskit/canvaskit.wasm':'wasm',
      'assets/FontManifest.json':JSON.stringify([{family:'Rubik',fonts:[{weight:400,asset:'assets/fonts/Rubik-Regular.ttf'}]}]),
      'assets/assets/fonts/Rubik-Regular.ttf':'bundled font',
    };
    for(const [path,content] of Object.entries(files)) await writeFile(join(directory,path),content);
    const result=await preparePreviewOffline(directory);
    assert.equal(result.assetCount,7);
    const fonts=JSON.parse(await readFile(join(directory,'assets/FontManifest.json'),'utf8'));
    assert.equal(fonts.find(font=>font.family==='Roboto').fonts[0].asset,'assets/fonts/Rubik-Regular.ttf');
    const bootstrap=await readFile(join(directory,'flutter_bootstrap.js'),'utf8');
    assert.match(bootstrap,/canvasKitBaseUrl:'canvaskit\/'/);
    assert.match(bootstrap,/canvasKitVariant:'full'/);
    assert.ok(!bootstrap.includes('serviceWorkerSettings'));
    assert.ok(!(await readFile(join(directory,'index.html'),'utf8')).includes('fonts.googleapis'));
    const worker=await readFile(join(directory,'flutter_service_worker.js'),'utf8');
    assert.ok(worker.includes(result.version));
    assert.match(worker,/sha256-/);
    assert.ok(!worker.includes('skipWaiting()'));
    assert.doesNotMatch(worker,/\b(?:localStorage|indexedDB)\s*[.(]/);
    assert.deepEqual(await preparePreviewOffline(directory),result);
  } finally {
    await rm(directory,{recursive:true,force:true});
  }
});
