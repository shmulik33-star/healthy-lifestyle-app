import { readFile,writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { comparisonRow,expectedCounts,rowFingerprint,validateRows } from './appwrite_migration_audit.mjs';

export function ownerReadPermission(owner) {
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(owner)) {
    throw new Error('Invalid imported owner identifier');
  }
  return `read("user:${owner}")`;
}

export function prepareOwnerPermissions(table,definition,rows,owners,sourceFingerprints) {
  if (definition.rowSecurity!==true || !Array.isArray(definition.$permissions) || definition.$permissions.length) {
    throw new Error('Expected row security enabled with no table permissions');
  }
  validateRows(table,rows,owners,expectedCounts[table]);
  if (new Set(rows.map(row=>row.$id)).size!==rows.length || rows.some(row=>!row.$id)) {
    throw new Error('Invalid row identities');
  }
  const hashes=rows.map(row=>rowFingerprint(comparisonRow(table,row))).sort();
  if (JSON.stringify(hashes)!==JSON.stringify([...sourceFingerprints].sort())) {
    throw new Error('Source data mismatch before permission update');
  }
  return rows.map(row=>{
    const permissions=[ownerReadPermission(row.user_id)];
    if (!Array.isArray(row.$permissions) ||
        (row.$permissions.length && JSON.stringify(row.$permissions)!==JSON.stringify(permissions))) {
      throw new Error('Unexpected existing permissions; refusing to overwrite');
    }
    return {row,permissions,before:rowFingerprint(comparisonRow(table,row))};
  });
}

async function run() {
  const key=process.env.APPWRITE_API_KEY;
  if (!key) throw new Error('Missing API key');
  const project='6ac5fccb0004756daef1';
  async function request(path,method='GET',body) {
    const response=await fetch('https://fra.cloud.appwrite.io/v1'+path,{
      method,headers:{'X-Appwrite-Project':project,'X-Appwrite-Key':key,'Content-Type':'application/json'},
      body:body ? JSON.stringify(body):undefined,signal:AbortSignal.timeout(30000),
    });
    if (!response.ok) throw new Error(`Permission request failed (${response.status})`);
    return response.json();
  }
  const query=new URLSearchParams();
  query.append('queries[]',JSON.stringify({method:'limit',values:[100]}));
  const users=await request(`/users?${query}`);
  if (users.total!==14 || users.users?.length!==14) throw new Error('Unexpected Auth count');
  const owners=new Set(users.users.map(user=>user.$id));
  const source=JSON.parse(await readFile('tool/appwrite_comparison_source.local.json','utf8'));
  const batches=[];
  for (const table of Object.keys(expectedCounts)) {
    const path=`/tablesdb/public/tables/${table}`;
    const definition=await request(path);
    const page=await request(`${path}/rows?${query}`);
    if (page.total!==expectedCounts[table]) throw new Error('Unexpected target count');
    const expected=source.find(entry=>entry.table_name===table)?.fingerprints;
    if (!expected) throw new Error('Missing source comparison');
    const operations=prepareOwnerPermissions(table,definition,page.rows,owners,expected);
    batches.push({table,path,operations});
  }
  if (!process.argv.includes('--apply')) {
    console.log(JSON.stringify({mode:'dry-run',tables:3,rows:82,ownerOnlyRead:true}));
    return;
  }
  if (!process.env.APPWRITE_PERMISSIONS_BACKUP) throw new Error('Backup path required');
  await writeFile(process.env.APPWRITE_PERMISSIONS_BACKUP,JSON.stringify({project,batches:batches.map(batch=>({
    table:batch.table,rows:batch.operations.map(op=>({rowId:op.row.$id,permissions:op.row.$permissions})),
  }))}),{flag:'wx',mode:0o600});
  let changed=0;
  for (const batch of batches) for (const op of batch.operations) {
    if (JSON.stringify(op.row.$permissions)===JSON.stringify(op.permissions)) continue;
    const path=`${batch.path}/rows/${encodeURIComponent(op.row.$id)}`;
    const fresh=await request(path);
    if (rowFingerprint(comparisonRow(batch.table,fresh))!==op.before ||
        JSON.stringify(fresh.$permissions)!==JSON.stringify(op.row.$permissions)) {
      throw new Error('Target changed; stopped before overwriting permissions');
    }
    const result=await request(path,'PATCH',{permissions:op.permissions});
    if (rowFingerprint(comparisonRow(batch.table,result))!==op.before ||
        JSON.stringify(result.$permissions)!==JSON.stringify(op.permissions)) {
      throw new Error('Permission update verification failed');
    }
    changed++;
  }
  for (const batch of batches) {
    const definition=await request(batch.path);
    const page=await request(`${batch.path}/rows?${query}`);
    if (page.total!==expectedCounts[batch.table]) throw new Error('Final count mismatch');
    prepareOwnerPermissions(batch.table,definition,page.rows,owners,
      source.find(entry=>entry.table_name===batch.table).fingerprints);
    if (page.rows.some(row=>JSON.stringify(row.$permissions)!==JSON.stringify([ownerReadPermission(row.user_id)]))) {
      throw new Error('Final owner permissions mismatch');
    }
  }
  console.log(JSON.stringify({mode:'applied',tables:3,rows:82,changed,ownerOnlyRead:true,dataUnchanged:true}));
}
if (process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  run().catch(()=>{console.error('Permission setup stopped; inspect aggregate audit before retry. No private data is logged.');process.exitCode=1;});
}
