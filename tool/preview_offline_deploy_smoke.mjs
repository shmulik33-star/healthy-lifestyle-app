import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const preview='https://preview.healthy-lifestyle-app.pages.dev';
const production='https://healthy-lifestyle-app.pages.dev';
const productionOnly=process.argv.includes('--production');
const target=productionOnly?production:preview;
const expected=JSON.parse(await readFile('build/web/offline-build.json','utf8'));
async function text(url) {
  const response=await fetch(url,{cache:'no-store',signal:AbortSignal.timeout(20000)});
  assert.equal(response.status,200);
  return response.text();
}
let ready=false;
for(let attempt=0;attempt<12;attempt++) {
  try {
    const actual=JSON.parse(await text(target+'/offline-build.json'));
    assert.deepEqual(actual,expected);
    const worker=await text(target+'/flutter_service_worker.js');
    assert.ok(worker.includes(expected.version));
    assert.ok(worker.includes('fit-preview-shell-'));
    assert.ok(worker.includes('function withoutRedirect(response)'));
    const document=await fetch(target+'/',{cache:'no-store',signal:AbortSignal.timeout(20000)});
    assert.equal(document.status,200);
    assert.equal(document.redirected,false,'Canonical navigation document must not redirect');
    const bootstrap=await text(target+'/flutter_bootstrap.js');
    assert.ok(bootstrap.includes('function startPreviewOffline'));
    assert.ok(bootstrap.includes("canvasKitBaseUrl:'canvaskit/'"));
    assert.ok(!(await text(target+'/')).includes('href="https://fonts.googleapis.com'));
    assert.ok(worker.includes('"production":'+productionOnly),'Offline host gate must match deployment target');
    ready=true;
    break;
  } catch(error) {
    if(attempt===11) throw error;
    await new Promise(resolve=>setTimeout(resolve,5000));
  }
}
assert.ok(ready);
const prodWorker=await text(production+'/flutter_service_worker.js');
if(productionOnly||process.env.APPWRITE_PRODUCTION_READY==='true') {
  assert.ok(prodWorker.includes('fit-preview-shell-')&&prodWorker.includes('"production":true'),'Approved production offline build required');
} else assert.ok(!prodWorker.includes('fit-preview-shell-'),'Preview offline worker must not be deployed to Production before approval');
console.log(`${productionOnly?'Production':'Preview'} static offline build verified: ${expected.version}, ${expected.assetCount} assets.`);
console.log('Browser offline boot and phone retest are separate checks; this HTTP probe alone does not prove them.');
