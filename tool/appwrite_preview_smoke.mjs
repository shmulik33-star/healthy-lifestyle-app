// Configuration probe only: no credentials, valid account or data writes.
// The malformed sign-in reaches the private limiter, then fails validation
// before contacting Appwrite. It consumes one Preview rate-limit attempt.
import assert from 'node:assert/strict';

const preview='https://preview.healthy-lifestyle-app.pages.dev';
const production='https://healthy-lifestyle-app.pages.dev';
async function expect(origin,action,status,error,options={}) {
  let result;
  for(let attempt=0;attempt<12;attempt++) {
    result=await fetch(`${origin}/api/cloud/${action}`,{
      ...options,signal:AbortSignal.timeout(20000),redirect:'error',
    });
    // Stable hostname propagation can briefly mix the preceding deployment.
    // Bounded retries do not turn a persistently unavailable service into a pass.
    if(result.status!==503 || attempt===11) break;
    await result.arrayBuffer();
    await new Promise(resolve=>setTimeout(resolve,5000));
  }
  assert.equal(result.status,status,`${origin}: ${action} HTTP status`);
  assert.deepEqual(await result.json(),{error},`${origin}: ${action} safe response`);
  assert.ok(result.headers.get('cache-control')?.includes('no-store'));
  assert.equal(result.headers.get('set-cookie'),null);
  console.log(`${origin}: ${action} returned expected ${status} (${error})`);
}

// Current production can predate the adapter and return the static SPA fallback.
// A deployed adapter must instead explicitly fail closed. Never accept a live
// JSON session response here, even if it says no user is signed in.
const prod=await fetch(`${production}/api/cloud/session`,{
  signal:AbortSignal.timeout(20000),redirect:'error',
});
assert.equal(prod.headers.get('set-cookie'),null);
if(prod.status===503) {
  assert.deepEqual(await prod.json(),{error:'cloud_not_configured'});
} else if(prod.status===200) {
  assert.ok(prod.headers.get('content-type')?.includes('text/html'));
  assert.match(await prod.text(),/<!doctype html>/i);
} else {
  assert.equal(prod.status,404);
}
console.log('Production Appwrite session route is absent or explicitly disabled.');
await expect(preview,'session',401,'authentication_required');
await expect(preview,'sign-in',403,'forbidden',{
  method:'POST',headers:{origin:'https://example.invalid','content-type':'application/json'},body:'{}',
});
await expect(preview,'sign-in',400,'invalid_input',{
  method:'POST',headers:{origin:preview,'content-type':'application/json'},body:'{}',
});
console.log('Preview configuration and private limiter probe passed; live login/sync QA still required.');
