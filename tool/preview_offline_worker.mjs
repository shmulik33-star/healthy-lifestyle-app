// Serialized into the Preview-only generated service worker. No cloud/session
// payloads are read here. The manifest contains only build-time static assets.
export function previewOfflineWorker(scope, build) {
  const prefix='fit-preview-shell-';
  const cacheName=prefix+build.version;
  const allowedHosts=['preview.healthy-lifestyle-app.pages.dev','localhost','127.0.0.1'];
  const assets=new Map(build.assets.map(asset=>['/'+asset.path,asset]));
  const allowed=()=>allowedHosts.includes(scope.location.hostname);
  async function download(asset) {
    const request=new Request(new URL('/'+asset.path,scope.location.origin),{
      credentials:'omit',cache:'no-store',integrity:asset.integrity,signal:AbortSignal.timeout(90000),
    });
    const response=await fetch(request);
    if(!response.ok || response.type==='opaque') throw new Error('Static asset unavailable');
    return response;
  }
  scope.addEventListener('install',event=>{
    event.waitUntil((async()=>{
      if(!allowed()) throw new Error('Preview-only offline worker');
      const cache=await caches.open(cacheName);
      try {
        // Bounded parallelism; integrity failures leave the preceding worker
        // active. Do NOT skipWaiting or reload clients with unsaved edits.
        let cursor=0;
        const results=await Promise.allSettled(Array.from({length:4},async()=>{
          while(cursor<build.assets.length) {
            const asset=build.assets[cursor++];
            await cache.put('/'+asset.path,await download(asset));
          }
        }));
        if(results.some(result=>result.status==='rejected')) throw new Error('Incomplete static build');
      } catch(error) {
        await caches.delete(cacheName);
        throw error;
      }
    })());
  });
  scope.addEventListener('activate',event=>{
    event.waitUntil((async()=>{
      // Only our versioned static caches, never localStorage, IndexedDB or
      // another feature's caches. Retain one preceding static build as well.
      const previous=(await caches.keys()).filter(name=>name.startsWith(prefix)&&name!==cacheName);
      await Promise.all(previous.slice(0,-1).map(name=>caches.delete(name)));
      await scope.clients.claim();
    })());
  });
  scope.addEventListener('fetch',event=>{
    const request=event.request;
    const url=new URL(request.url);
    if(!allowed() || request.method!=='GET' || url.origin!==scope.location.origin ||
        url.pathname.startsWith('/api/') || url.search) return;
    const path=request.mode==='navigate' && ['/', '/index.html'].includes(url.pathname)
      ? '/index.html' : url.pathname;
    const asset=assets.get(path);
    if(!asset) return; // Includes every unknown/authenticated/dynamic resource.
    event.respondWith((async()=>{
      const cache=await caches.open(cacheName);
      const cached=await cache.match(path);
      if(cached) return cached;
      // Rare browser eviction: recover only a hash-verified static asset.
      try {
        const response=await download(asset);
        await cache.put(path,response.clone());
        return response;
      } catch {
        return new Response('Offline application files unavailable. Reconnect and reopen.',{
          status:503,headers:{'content-type':'text/plain; charset=utf-8','cache-control':'no-store'},
        });
      }
    })());
  });
}
