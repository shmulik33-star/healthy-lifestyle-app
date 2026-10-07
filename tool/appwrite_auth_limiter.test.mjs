import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../infra/auth-rate-limit/worker.mjs';
import {handleCloud} from '../functions/_shared/appwrite-cloud.mjs';

test('private limiter accepts only hashed keys and reports shared binding result',async()=>{
  let calls=0;
  const env={LOGIN_LIMIT:{limit:async({key})=>{
    calls++;assert.equal(key,'a'.repeat(64));return {success:false};
  }}};
  const valid=new Request('https://internal/limit',{method:'POST',body:JSON.stringify({key:'a'.repeat(64)})});
  assert.deepEqual(await (await worker.fetch(valid,env)).json(),{success:false});
  assert.equal(calls,1);
  for(const key of ['192.0.2.1','email@example.test',null]) {
    assert.equal((await worker.fetch(new Request('https://internal/limit',{
      method:'POST',body:JSON.stringify({key})}),env)).status,400);
  }
  assert.equal(calls,1);
});
test('Pages service-binding limiter hashes IP and fails closed on service outage',async()=>{
  const origin='https://preview.healthy-lifestyle-app.pages.dev';
  const input=()=>new Request(origin+'/api/cloud/sign-in',{method:'POST',
    headers:{origin,'content-type':'application/json','cf-connecting-ip':'192.0.2.1'},
    body:JSON.stringify({email:'test@example.test',password:'password8'})});
  const env={APPWRITE_PREVIEW_ENABLED:'true',APPWRITE_API_KEY:'test',AUTH_RATE_LIMITER:{
    fetch:async(url,options)=>{
      assert.equal(url,'https://internal/limit');
      assert.match(JSON.parse(options.body).key,/^[a-f0-9]{64}$/);
      assert.ok(!options.body.includes('192.0.2.1'));
      return new Response(JSON.stringify({success:false}));
    }}};
  assert.equal((await handleCloud(input(),env,'sign-in',()=>assert.fail())).status,429);
  env.AUTH_RATE_LIMITER.fetch=async()=>new Response('{}',{status:503});
  assert.equal((await handleCloud(input(),env,'sign-in',()=>assert.fail())).status,503);
});
