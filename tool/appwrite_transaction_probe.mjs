// Stage a no-op on one migrated row, then roll back. Never commit this probe.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';

const endpoint='https://fra.cloud.appwrite.io/v1';
const project='6ac5fccb0004756daef1';
const key=process.env.APPWRITE_API_KEY;
if(!key) throw new Error('APPWRITE_API_KEY required');
async function call(path,method='GET',body) {
  const result=await fetch(endpoint+path,{method,headers:{'X-Appwrite-Project':project,
    'X-Appwrite-Key':key,'content-type':'application/json'},
    body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});
  const data=result.status===204?{}:await result.json();
  if(!result.ok) {
    const missingScope=typeof data.message==='string'?data.message.match(/missing scope \(([^)]+)\)/)?.[1]:undefined;
    throw new Error(JSON.stringify({status:result.status,type:data.type,missingScope}));
  }
  return data;
}
function fingerprint(row) {
  return createHash('sha256').update(JSON.stringify({
    user_id:row.user_id,payload:row.payload,revision:row.revision,updated_at:row.updated_at,
    permissions:row.$permissions,
  })).digest('hex');
}
const rowsPath='/tablesdb/public/tables/user_app_state/rows';
const query=new URLSearchParams();
query.append('queries[]',JSON.stringify({method:'limit',values:[1]}));
const page=await call(`${rowsPath}?${query}`);
assert.equal(page.total,14,'Unexpected source snapshot count; stop before staging');
const before=page.rows[0];
assert.ok(before?.$id&&before.user_id);
const rowPath=`${rowsPath}/${encodeURIComponent(before.$id)}`;
let tx;
let rollback;
try {
  const transaction=await call('/tablesdb/transactions','POST',{ttl:60});
  assert.equal(typeof transaction.$id,'string');
  tx=transaction.$id;
  await call(rowPath,'PATCH',{data:{user_id:before.user_id},transactionId:tx});
  const staged=await call(`${rowPath}?transactionId=${encodeURIComponent(tx)}`);
  assert.equal(fingerprint(staged),fingerprint(before),'Staged snapshot differs from source');
} finally {
  if(tx) rollback=await call(`/tablesdb/transactions/${encodeURIComponent(tx)}`,'PATCH',{rollback:true});
}
assert.equal(fingerprint(await call(rowPath)),fingerprint(before),'Row changed after rollback');
console.log(JSON.stringify({probe:'stage-noop-and-rollback',passed:true,
  rollbackStatus:rollback.status,applicationDataAndPermissionsUnchanged:true}));
