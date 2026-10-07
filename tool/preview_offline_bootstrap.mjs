// Serialized after Flutter's generated loader/buildConfig, in Preview only.
export function startPreviewOffline() {
  if(['preview.healthy-lifestyle-app.pages.dev','localhost','127.0.0.1'].includes(location.hostname) &&
      'serviceWorker' in navigator) {
    const status=document.createElement('div');
    status.setAttribute('role','status');
    status.setAttribute('dir','rtl');
    status.style.cssText='position:fixed;top:8px;right:8px;max-width:310px;padding:8px 12px;'+
      'border-radius:12px;background:#fff;color:#28536B;font:14px system-ui;z-index:10001;box-shadow:0 2px 8px #0003';
    const label=document.createElement('span');
    const close=document.createElement('button');
    close.textContent=' ×';
    close.setAttribute('aria-label','סגור הודעת הכנה ללא רשת');
    close.onclick=()=>status.remove();
    status.append(label,close);
    document.body.append(status);
    label.textContent='מכין את האפליקציה לפתיחה ללא אינטרנט…';
    const showReady=()=>{
      label.textContent='האפליקציה מוכנה לפתיחה ללא אינטרנט';
      setTimeout(()=>status.remove(),15000);
    };
    navigator.serviceWorker.register('flutter_service_worker.js',{
      scope:'/',updateViaCache:'none',
    }).then(registration=>{
      const observe=()=>{
        if(registration.waiting) {
          label.textContent='עדכון מוכן. יופעל לאחר סגירת כל חלונות האפליקציה.';
        } else if(registration.active && !registration.installing) showReady();
        const installing=registration.installing;
        if(installing) installing.addEventListener('statechange',()=>{
          if(installing.state==='activated') showReady();
          else if(installing.state==='installed' && registration.active) {
            label.textContent='עדכון מוכן. יופעל לאחר סגירת כל חלונות האפליקציה.';
          } else if(installing.state==='redundant') {
            label.textContent='ההכנה ללא רשת לא הושלמה. התחברו ופתחו שוב.';
          }
        });
      };
      observe();
      registration.addEventListener('updatefound',observe);
    }).catch(()=>{
      label.textContent='ההכנה ללא רשת לא הושלמה. התחברו ופתחו שוב.';
    });
  }
  // Local full CanvasKit supports both Chromium and Safari. Rubik is already
  // bundled by Flutter; no Google Fonts stylesheet is required for app startup.
  _flutter.loader.load({config:{canvasKitBaseUrl:'canvaskit/',canvasKitVariant:'full'}});
}
