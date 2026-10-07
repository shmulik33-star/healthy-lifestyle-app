const ENDPOINT='https://fra.cloud.appwrite.io/v1';
const PROJECT='6ac5fccb0004756daef1';
const COOKIE='__Host-fit-appwrite';
const TABLES=['user_app_state','user_daily_progress','user_custom_foods'];
export class CloudError extends Error {
  constructor(code,status=400) { super(code); this.code=code; this.status=status; }
}
const object=value=>value && typeof value==='object' && !Array.isArray(value);
function requireObject(value) {
  if (!object(value)) throw new CloudError('invalid_input');
  return value;
}
function dayKey(value) {
  if (typeof value!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new CloudError('invalid_input');
  const date=new Date(value+'T00:00:00Z');
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0,10)!==value) throw new CloudError('invalid_input');
  return value;
}
export function mergeDaily(remote,input) {
  dayKey(input.day_key);
  if (!Number.isInteger(input.water_cups) || input.water_cups<0 || input.water_cups>100 ||
      !Number.isInteger(input.steps) || input.steps<0 || input.steps>500000 ||
      typeof input.workout_completed!=='boolean') throw new CloudError('invalid_input');
  return {day_key:input.day_key,water_cups:Math.max(remote?.water_cups??0,input.water_cups),
    steps:Math.max(remote?.steps??0,input.steps),workout_completed:!!remote?.workout_completed||input.workout_completed};
}
function foodId(value) {
  if (typeof value!=='string' || !value.length || value.length>128) throw new CloudError('invalid_input');
  return value;
}
function safeRow(row) {
  if (!row) return null;
  const result=Object.fromEntries(Object.entries(row).filter(([key])=>!key.startsWith('$') && key!=='user_id'));
  if (typeof result.payload==='string') result.payload=JSON.parse(result.payload);
  return result;
}
function response(body,status=200,extra={}) {
  return new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store','x-content-type-options':'nosniff',...extra}});
}
export function sessionCookie(secret,expiry) {
  if (typeof secret!=='string' || !/^[A-Za-z0-9_+=\/-]+$/.test(secret)) throw new CloudError('cloud_unavailable',503);
  const expires=new Date(expiry);
  if (!Number.isFinite(expires.getTime())) throw new CloudError('cloud_unavailable',503);
  return `${COOKIE}=${secret}; Path=/; Secure; HttpOnly; SameSite=Strict; Expires=${expires.toUTCString()}`;
}
function readCookie(request) {
  const cookies=(request.headers.get('cookie')??'').split(';').map(part=>part.trim());
  const matches=cookies.filter(part=>part.startsWith(COOKIE+'='));
  if (matches.length!==1) return null;
  const value=matches[0].slice(COOKIE.length+1);
  return /^[A-Za-z0-9_+=\/-]+$/.test(value)?value:null;
}

export function createRepository(call,owner) {
  const path=table=>{
    if (!TABLES.includes(table)) throw new CloudError('invalid_input');
    return `/tablesdb/public/tables/${table}/rows`;
  };
  async function list(table,filters=[],transactionId) {
    const rows=[];
    for(let offset=0;;offset+=100) {
      const query=new URLSearchParams();
      for(const q of [{method:'equal',attribute:'user_id',values:[owner]},...filters,
        {method:'limit',values:[100]},{method:'offset',values:[offset]}]) query.append('queries[]',JSON.stringify(q));
      if(transactionId) query.set('transactionId',transactionId);
      const page=await call(`${path(table)}?${query}`);
      if(!Array.isArray(page.rows)||!Number.isInteger(page.total)) throw new CloudError('cloud_unavailable',503);
      if(page.rows.some(row=>row.user_id!==owner)) throw new CloudError('cloud_unavailable',503);
      rows.push(...page.rows);
      if(rows.length>=page.total) return rows;
      if(!page.rows.length||rows.length>10000) throw new CloudError('cloud_unavailable',503);
    }
  }
  const filters=key=>key ? [{method:'equal',attribute:key[0],values:[key[1]]}]:[];
  async function find(table,key,tx) {
    const rows=await list(table,filters(key),tx);
    if(rows.length>1) throw new CloudError('cloud_unavailable',503);
    return rows[0]??null;
  }
  async function mutate(table,key,build) {
    for(let attempt=0;attempt<3;attempt++) {
      const transaction=await call('/tablesdb/transactions','POST',{ttl:60});
      const tx=transaction.$id;
      if(typeof tx!=='string') throw new CloudError('cloud_unavailable',503);
      try {
        let existing=await find(table,key);
        if(existing) {
          // Register the row version BEFORE reading the merge/CAS inputs.
          // Appwrite conflict checks start at staging, not at an earlier list.
          await call(`${path(table)}/${encodeURIComponent(existing.$id)}`,'PATCH',{
            data:{user_id:owner},transactionId:tx,
          });
          existing=await call(`${path(table)}/${encodeURIComponent(existing.$id)}?transactionId=${encodeURIComponent(tx)}`);
          if(existing.user_id!==owner) throw new CloudError('cloud_unavailable',503);
        }
        const data=await build(existing);
        const permissions=[`read("user:${owner}")`];
        let saved;
        if(data===null) {
          if(existing) await call(`${path(table)}/${encodeURIComponent(existing.$id)}?transactionId=${encodeURIComponent(tx)}`,'DELETE');
          saved=null;
        } else {
          const body={data:{...data,user_id:owner,updated_at:new Date().toISOString()},permissions,transactionId:tx};
          saved=existing ? await call(`${path(table)}/${encodeURIComponent(existing.$id)}`,'PATCH',body)
            : await call(path(table),'POST',{...body,rowId:crypto.randomUUID()});
        }
        const commit=await call(`/tablesdb/transactions/${encodeURIComponent(tx)}`,'PATCH',{commit:true});
        if(commit.status!=='committed') throw new CloudError('cloud_unavailable',503);
        return saved;
      } catch(error) {
        await call(`/tablesdb/transactions/${encodeURIComponent(tx)}`,'PATCH',{rollback:true}).catch(()=>{});
        // CAS conflicts require client re-merge; storage conflicts can be re-read.
        if(error.code==='storage_conflict' && attempt<2) continue;
        if(error.code==='storage_conflict') throw new CloudError('conflict',409);
        throw error;
      }
    }
  }
  return {list,find,mutate};
}

export async function handleCloud(request,env,action,fetcher=fetch) {
  try {
    const url=new URL(request.url);
    if(env.APPWRITE_PREVIEW_ENABLED!=='true' || !env.APPWRITE_API_KEY ||
      url.origin!==(env.APPWRITE_ORIGIN??'https://preview.healthy-lifestyle-app.pages.dev')) {
      throw new CloudError('cloud_not_configured',503);
    }
    if(request.headers.get('sec-fetch-site')==='cross-site') throw new CloudError('forbidden',403);
    if(!['GET','POST'].includes(request.method)) throw new CloudError('method_not_allowed',405);
    if(request.method==='POST' && (request.headers.get('origin')!==url.origin ||
      !request.headers.get('content-type')?.startsWith('application/json'))) throw new CloudError('forbidden',403);
    let body={};
    if(request.method==='POST') {
      const text=await request.text();
      if(new TextEncoder().encode(text).length>2_000_000) throw new CloudError('request_too_large',413);
      try {body=requireObject(JSON.parse(text));} catch {throw new CloudError('invalid_input');}
    }
    async function call(path,method='GET',data,session,admin=true) {
      const headers={'X-Appwrite-Project':PROJECT,'content-type':'application/json'};
      if(session) headers['X-Appwrite-Session']=session;
      else if(admin) headers['X-Appwrite-Key']=env.APPWRITE_API_KEY;
      const upstream=await fetcher(ENDPOINT+path,{method,headers,body:data?JSON.stringify(data):undefined,
        signal:AbortSignal.timeout(15000)});
      if(!upstream.ok) {
        const status=upstream.status;
        throw new CloudError(status===409?'storage_conflict':status===429?'rate_limited':
          status===401?'authentication_required':'cloud_unavailable',status===429?429:status===409?409:status===401?401:503);
      }
      return upstream.status===204?{}:upstream.json();
    }
    if(['sign-in','sign-up'].includes(action) && request.method==='POST') {
      // Server-key auth bypasses Appwrite's ordinary IP limits. Fail closed
      // until a shared Cloudflare limiter is configured; never use process RAM.
      if(!env.AUTH_RATE_LIMITER?.limit && !env.AUTH_RATE_LIMITER?.fetch) throw new CloudError('auth_not_configured',503);
      const ip=request.headers.get('cf-connecting-ip');
      if(!ip) throw new CloudError('auth_not_configured',503);
      const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(`auth:${ip}`));
      const key=Array.from(new Uint8Array(digest),byte=>byte.toString(16).padStart(2,'0')).join('');
      let allowed;
      if(env.AUTH_RATE_LIMITER.limit) allowed=(await env.AUTH_RATE_LIMITER.limit({key})).success;
      else {
        const limit=await env.AUTH_RATE_LIMITER.fetch('https://internal/limit',{
          method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({key})});
        if(!limit.ok) throw new CloudError('auth_not_configured',503);
        allowed=(await limit.json()).success;
      }
      if(allowed!==true) throw new CloudError('rate_limited',429);
      if(typeof body.email!=='string'||body.email.length>254||!body.email.includes('@')||
        typeof body.password!=='string'||body.password.length>256||!body.password.length) throw new CloudError('invalid_input');
      if(action==='sign-up') {
        if(body.password.length<8) throw new CloudError('password_too_short');
        try { await call('/account','POST',{userId:crypto.randomUUID(),email:body.email,password:body.password},null,false); }
        catch(error) { if(error.status===409) throw new CloudError('account_exists',409); throw error; }
      }
      let session;
      try {session=await call('/account/sessions/email','POST',{email:body.email,password:body.password});}
      catch(error) {if(error.status===401) throw new CloudError('invalid_credentials',401);throw error;}
      const user=await call('/account','GET',undefined,session.secret,false);
      return response({user:{id:user.$id,email:user.email}},200,{'set-cookie':sessionCookie(session.secret,session.expire)});
    }
    const secret=readCookie(request);
    if(!secret) throw new CloudError('authentication_required',401);
    // No admin key on identity verification: untrusted user_id/JWT metadata
    // are never substituted for the account returned by Appwrite.
    const user=await call('/account','GET',undefined,secret,false);
    if(typeof user.$id!=='string'||!/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$/.test(user.$id)) throw new CloudError('authentication_required',401);
    if(action==='session'&&request.method==='GET') return response({user:{id:user.$id,email:user.email}});
    if(action==='sign-out'&&request.method==='POST') {
      await call('/account/sessions/current','DELETE',undefined,secret,false);
      return response({ok:true},200,{'set-cookie':`${COOKIE}=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0`});
    }
    if(request.headers.get('x-fit-expected-user')!==user.$id) throw new CloudError('authentication_required',401);
    const repo=createRepository(call,user.$id);
    if(action==='state') {
      if(request.method==='GET') return response({row:safeRow(await repo.find('user_app_state'))});
      requireObject(body.payload);
      if(!Number.isSafeInteger(body.expectedRevision)||body.expectedRevision<0) throw new CloudError('invalid_input');
      const row=await repo.mutate('user_app_state',null,remote=>{
        if((remote?.revision??0)!==body.expectedRevision) throw new CloudError('conflict',409);
        return {payload:JSON.stringify(body.payload),revision:(remote?.revision??0)+1};
      });
      return response({row:safeRow(row)});
    }
    if(action==='daily') {
      if(request.method==='GET') return response({rows:(await repo.list('user_daily_progress')).map(safeRow)});
      const input=mergeDaily(null,body); // Validate before starting a transaction.
      const row=await repo.mutate('user_daily_progress',['day_key',input.day_key],remote=>mergeDaily(remote,input));
      return response({row:safeRow(row)});
    }
    if(action==='foods') {
      if(request.method==='GET') return response({rows:(await repo.list('user_custom_foods')).map(safeRow)});
      if(!Array.isArray(body.rows)||body.rows.length>100) throw new CloudError('invalid_input');
      for(const row of body.rows) {foodId(row.food_id);requireObject(row.payload);}
      for(const row of body.rows) await repo.mutate('user_custom_foods',['food_id',row.food_id],remote=>{
        const remoteStamp=remote?new Date(remote.updated_at).getTime():null;
        const expected=row.expectedUpdatedAt==null?null:new Date(row.expectedUpdatedAt).getTime();
        if(remoteStamp!==expected) throw new CloudError('conflict',409);
        return {food_id:row.food_id,payload:JSON.stringify(row.payload)};
      });
      return response({ok:true});
    }
    if(action==='delete-foods'&&request.method==='POST') {
      if(!Array.isArray(body.ids)||body.ids.length>100) throw new CloudError('invalid_input');
      const snapshot=await repo.find('user_app_state');
      const tombstones=snapshot?requireObject(JSON.parse(snapshot.payload)).deletedCustomFoodIds:null;
      for(const id of body.ids) {
        foodId(id);
        if(!object(tombstones)||!Object.hasOwn(tombstones,id)) throw new CloudError('invalid_input');
      }
      for(const id of body.ids) await repo.mutate('user_custom_foods',['food_id',id],()=>null);
      return response({ok:true});
    }
    throw new CloudError('not_found',404);
  } catch(error) {
    // Never log upstream bodies, credentials, health payloads or session secrets.
    const code=error instanceof CloudError?error.code:'cloud_unavailable';
    return response({error:code},error instanceof CloudError?error.status:503);
  }
}
