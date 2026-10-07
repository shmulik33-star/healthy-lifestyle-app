import test from 'node:test';
import assert from 'node:assert/strict';
import {CloudError,createRepository,handleCloud,mergeDaily,sessionCookie} from '../functions/_shared/appwrite-cloud.mjs';

const origin='https://preview.healthy-lifestyle-app.pages.dev';
const env={APPWRITE_PREVIEW_ENABLED:'true',APPWRITE_API_KEY:'server-secret',
  AUTH_RATE_LIMITER:{limit:async()=>({success:true})}};
const request=(action,body,headers={})=>new Request(`${origin}/api/cloud/${action}`,{
  method:body===undefined?'GET':'POST',headers:{origin,'content-type':'application/json',
    cookie:'__Host-fit-appwrite=session-secret','x-fit-expected-user':'owner',...headers},
  body:body===undefined?undefined:JSON.stringify(body)});
const json=value=>new Response(JSON.stringify(value));

test('daily merge is monotonic and rejects malformed logical days and counters',()=>{
  assert.deepEqual(mergeDaily({water_cups:8,steps:100,workout_completed:true},
    {day_key:'2026-10-07',water_cups:2,steps:200,workout_completed:false}),
    {day_key:'2026-10-07',water_cups:8,steps:200,workout_completed:true});
  for(const day of ['2026-02-30','2026-99-01','today']) assert.throws(()=>mergeDaily(null,
    {day_key:day,water_cups:0,steps:0,workout_completed:false}),CloudError);
  for(const water of [null,-1,1.2,101]) assert.throws(()=>mergeDaily(null,
    {day_key:'2026-10-07',water_cups:water,steps:0,workout_completed:false}),CloudError);
});
test('session cookie is host-only, HttpOnly and rejects header injection',()=>{
  const cookie=sessionCookie('abc+/=_-','2026-10-08T00:00:00Z');
  for(const flag of ['Secure','HttpOnly','SameSite=Strict','Path=/']) assert.ok(cookie.includes(flag));
  assert.ok(!cookie.includes('Domain='));
  assert.throws(()=>sessionCookie('abc; injected=true','2026-10-08'),CloudError);
});
test('production, missing configuration and cross-origin requests fail before upstream calls',async()=>{
  const never=()=>assert.fail('must not contact Appwrite');
  assert.equal((await handleCloud(request('session'),{},'session',never)).status,503);
  assert.equal((await handleCloud(new Request('https://healthy-lifestyle-app.pages.dev/api/cloud/session'),env,'session',never)).status,503);
  assert.equal((await handleCloud(request('state',{}, {origin:'https://attacker.test'}),env,'state',never)).status,403);
  assert.equal((await handleCloud(request('session',undefined,{'sec-fetch-site':'cross-site'}),env,'session',never)).status,403);
});
test('identity verification uses session only; server ownership ignores supplied user id',async()=>{
  let calls=0;
  const fetcher=async(url,options)=>{
    calls++;
    if(url.endsWith('/account')) {
      assert.equal(options.headers['X-Appwrite-Key'],undefined);
      assert.equal(options.headers['X-Appwrite-Session'],'session-secret');
      return json({$id:'owner',email:'owner@example.test'});
    }
    assert.equal(options.headers['X-Appwrite-Key'],'server-secret');
    const queries=new URL(url).searchParams.getAll('queries[]').map(JSON.parse);
    assert.deepEqual(queries[0],{method:'equal',attribute:'user_id',values:['owner']});
    return json({total:1,rows:[{$id:'row',$permissions:['private'],user_id:'owner',revision:2,payload:'{}'}]});
  };
  const result=await handleCloud(request('state'),env,'state',fetcher);
  assert.deepEqual(await result.json(),{row:{revision:2,payload:{}}});
  assert.equal(calls,2);
  assert.equal(result.headers.get('cache-control'),'no-store');
});
test('account switch rejects stale expected owner without accessing rows',async()=>{
  let calls=0;
  const result=await handleCloud(request('state',{payload:{},expectedRevision:0},
    {'x-fit-expected-user':'previous-user'}),env,'state',async()=>{
      calls++;return json({$id:'owner'});
    });
  assert.equal(result.status,401);assert.equal(calls,1);
});
test('missing/duplicate cookies never authorize access',async()=>{
  for(const cookie of ['', '__Host-fit-appwrite=a; __Host-fit-appwrite=b']) {
    const result=await handleCloud(request('session',undefined,{cookie}),env,'session',()=>assert.fail());
    assert.equal(result.status,401);
  }
});
test('auth fails closed without shared limiter and limits attempts before password checks',async()=>{
  const input={email:'owner@example.test',password:'not-a-real-password'};
  const noLimiter={...env,AUTH_RATE_LIMITER:undefined};
  assert.equal((await handleCloud(request('sign-in',input),noLimiter,'sign-in',()=>assert.fail())).status,503);
  const denied={...env,AUTH_RATE_LIMITER:{limit:async()=>({success:false})}};
  assert.equal((await handleCloud(request('sign-in',input,{'cf-connecting-ip':'192.0.2.1'}),denied,'sign-in',()=>assert.fail())).status,429);
});
test('sign-in never sends the admin key with the user session or returns secrets',async()=>{
  const result=await handleCloud(request('sign-in',{email:'owner@example.test',password:'password8'},
    {'cf-connecting-ip':'192.0.2.1'}),env,'sign-in',async(url,options)=>{
    if(url.endsWith('/sessions/email')) {
      assert.equal(options.headers['X-Appwrite-Key'],'server-secret');
      return json({secret:'session-secret',expire:'2026-10-08T00:00:00Z'});
    }
    assert.equal(options.headers['X-Appwrite-Key'],undefined);
    assert.equal(options.headers['X-Appwrite-Session'],'session-secret');
    return json({$id:'owner',email:'owner@example.test',password:'must-not-leak'});
  });
  assert.equal(result.status,200);
  assert.deepEqual(await result.json(),{user:{id:'owner',email:'owner@example.test'}});
  assert.ok(result.headers.get('set-cookie').includes('HttpOnly'));
});
test('repository rejects cross-owner rows even if upstream returns them',async()=>{
  const repo=createRepository(async()=>({total:1,rows:[{user_id:'someone-else'}]}),'owner');
  await assert.rejects(repo.list('user_app_state'),error=>error.code==='cloud_unavailable');
});
test('transaction stages row version before merge; commits only owner-scoped data',async()=>{
  const calls=[];
  const repo=createRepository(async(path,method='GET',body)=>{
    calls.push({path,method,body});
    if(path==='/tablesdb/transactions') return {$id:'tx'};
    if(path.endsWith('/transactions/tx')) return {status:'committed'};
    if(path.includes('?transactionId=tx')) return {$id:'row',user_id:'owner',revision:3};
    if(method==='GET') return {total:1,rows:[{$id:'row',user_id:'owner',revision:1}]};
    return {$id:'row',...body.data};
  },'owner');
  const row=await repo.mutate('user_app_state',null,remote=>{
    assert.equal(remote.revision,3); // not the pre-stage revision
    return {payload:'{}',revision:4,user_id:'attacker'};
  });
  assert.equal(row.user_id,'owner');
  const writes=calls.filter(call=>call.method==='PATCH'&&call.path.includes('/rows/'));
  assert.deepEqual(writes[0].body,{data:{user_id:'owner'},transactionId:'tx'});
  assert.deepEqual(writes[1].body.permissions,['read("user:owner")']);
  assert.equal(calls.at(-1).body.commit,true);
});
test('CAS conflict rolls back and never commits',async()=>{
  const calls=[];
  const repo=createRepository(async(path,method,body)=>{
    calls.push({path,body});
    if(path==='/tablesdb/transactions') return {$id:'tx'};
    return {total:0,rows:[]};
  },'owner');
  await assert.rejects(repo.mutate('user_app_state',null,()=>{throw new CloudError('conflict',409);}),
    error=>error.code==='conflict');
  assert.deepEqual(calls.at(-1).body,{rollback:true});
  assert.ok(!calls.some(call=>call.body?.commit));
});
test('upstream failures never expose credentials or raw response bodies',async()=>{
  const result=await handleCloud(request('session'),env,'session',async()=>
    new Response('sensitive upstream error including password', {status:500}));
  assert.equal(result.status,503);
  assert.deepEqual(await result.json(),{error:'cloud_unavailable'});
});
