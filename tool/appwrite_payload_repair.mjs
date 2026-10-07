import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { comparisonRow, restoreEmptyObjects, rowFingerprint } from './appwrite_migration_audit.mjs';

const table = 'user_app_state';
const project = '6ac5fccb0004756daef1';
const endpoint = 'https://fra.cloud.appwrite.io/v1';

export function prepareRepairs(rows, plans, expectedFingerprints) {
  if (rows.length !== 14 || expectedFingerprints.length !== 14 || plans.length !== 14) {
    throw new Error('Unexpected repair row or plan count');
  }
  if (new Set(rows.map(row => row.user_id)).size !== 14 ||
      new Set(rows.map(row => row.$id)).size !== 14 || rows.some(row => !row.$id)) {
    throw new Error('Invalid repair row identities');
  }
  const operations = rows.map(row => {
    const hash = createHash('md5').update(row.user_id).digest('hex');
    const matches = plans.filter(plan => plan.owner_hash === hash);
    if (matches.length !== 1) throw new Error('Missing or ambiguous source repair plan');
    const payload = restoreEmptyObjects(comparisonRow(table,row).payload,matches[0].empty_object_paths);
    const repaired = {...row,payload};
    return { row, repaired, before:rowFingerprint(comparisonRow(table,row)),
      after:rowFingerprint(comparisonRow(table,repaired)) };
  });
  if (JSON.stringify(operations.map(op=>op.after).sort()) !== JSON.stringify([...expectedFingerprints].sort())) {
    throw new Error('Repaired data does not match source; no writes performed');
  }
  return operations;
}

async function run() {
  const key = process.env.APPWRITE_API_KEY;
  if (!key) throw new Error('APPWRITE_API_KEY required');
  const apply = process.argv.includes('--apply');
  const plans = JSON.parse(await readFile('tool/appwrite_empty_objects.local.json','utf8'));
  const source = JSON.parse(await readFile('tool/appwrite_comparison_source.local.json','utf8'));
  const expected = source.find(entry=>entry.table_name===table)?.fingerprints;
  if (!expected) throw new Error('Source comparison missing');
  async function request(path, method='GET', body) {
    const response = await fetch(endpoint+path,{
      method,
      headers:{'X-Appwrite-Project':project,'X-Appwrite-Key':key,'Content-Type':'application/json'},
      body:body ? JSON.stringify(body) : undefined,
      signal:AbortSignal.timeout(30000),
    });
    if (!response.ok) throw new Error(`Repair request failed (${response.status}); check target before retry`);
    return response.json();
  }
  const path = `/tablesdb/public/tables/${table}/rows`;
  const query = new URLSearchParams();
  query.append('queries[]',JSON.stringify({method:'limit',values:[100]}));
  const page = await request(`${path}?${query}`);
  if (page.total !== 14 || page.rows?.length !== 14) throw new Error('Unexpected target count');
  const operations = prepareRepairs(page.rows,plans,expected);
  const changed = operations.filter(op=>op.before!==op.after);
  if (!apply) {
    console.log(JSON.stringify({project,mode:'dry-run',rows:14,changes:changed.length,matchesSource:true}));
    return;
  }
  const backup = process.env.APPWRITE_REPAIR_BACKUP;
  if (!backup) throw new Error('APPWRITE_REPAIR_BACKUP required before writing');
  // Exclusive creation: do not replace a previous recovery copy.
  await writeFile(backup,JSON.stringify({project,table,createdAt:new Date().toISOString(),rows:page.rows}),
    {flag:'wx',mode:0o600});
  let completed = 0;
  for (const op of changed) {
    const rowPath = `${path}/${encodeURIComponent(op.row.$id)}`;
    const fresh = await request(rowPath);
    if (rowFingerprint(comparisonRow(table,fresh))!==op.before ||
        JSON.stringify(fresh.$permissions)!==JSON.stringify(op.row.$permissions)) {
      throw new Error('Target changed since preflight; stopped before overwriting');
    }
    // Intentionally omit revision, timestamps, owner ID and permissions.
    const result = await request(rowPath,'PATCH',{data:{payload:JSON.stringify(op.repaired.payload)}});
    if (rowFingerprint(comparisonRow(table,result))!==op.after ||
        JSON.stringify(result.$permissions)!==JSON.stringify(op.row.$permissions)) {
      throw new Error('Updated row verification failed; recovery backup retained');
    }
    completed++;
  }
  const verified = await request(`${path}?${query}`);
  if (verified.total!==14 || JSON.stringify(verified.rows.map(row=>rowFingerprint(comparisonRow(table,row))).sort()) !==
      JSON.stringify([...expected].sort())) throw new Error('Final source comparison failed');
  console.log(JSON.stringify({project,mode:'applied',rows:14,changed:completed,matchesSource:true}));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run().catch(()=>{ console.error('Payload repair stopped. Inspect aggregate verification and backup before retry; no credentials or payloads are logged.'); process.exitCode=1; });
}
