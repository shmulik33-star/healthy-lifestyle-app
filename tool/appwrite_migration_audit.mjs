import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

export function restoreEmptyObjects(payload, allowedPathHashes) {
  const expected = new Set(allowedPathHashes);
  const matched = new Set();
  function restore(value, path) {
    const hash = createHash('md5').update(JSON.stringify(path)).digest('hex');
    if (expected.has(hash)) {
      if (!((Array.isArray(value) && value.length === 0) ||
          (value && !Array.isArray(value) && typeof value === 'object' && Object.keys(value).length === 0))) {
        throw new Error('Repair precondition failed: expected empty container');
      }
      matched.add(hash);
      return {};
    }
    if (Array.isArray(value)) return value.map((item,index) => restore(item,[...path,String(index)]));
    if (value && typeof value === 'object') {
      return Object.fromEntries(Object.entries(value).map(([key,item]) => [key,restore(item,[...path,key])]));
    }
    return value;
  }
  const result = restore(payload,[]);
  if (matched.size !== expected.size) throw new Error('Repair precondition failed: source path missing');
  return result;
}

// Match PostgreSQL's comparison query without exporting personal data.
// Numbers use IEEE-754 bytes; object key order is irrelevant, array order is not.
export function rowFingerprint(row) {
  const tokens = [];
  function visit(value, path) {
    let type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
    if (type === 'object' && Object.keys(value).length) {
      for (const [key, child] of Object.entries(value)) visit(child, [...path, key]);
      return;
    }
    if (type === 'array' && value.length) {
      value.forEach((child, index) => visit(child, [...path, String(index)]));
      return;
    }
    let scalar = String(value);
    if (type === 'number') {
      if (!Number.isFinite(value)) throw new Error('Non-finite fingerprint number');
      const bytes = Buffer.alloc(8);
      bytes.writeDoubleBE(Object.is(value, -0) ? 0 : value);
      scalar = bytes.toString('hex');
    } else if (type === 'array') scalar = '[]';
    else if (type === 'object') scalar = '{}';
    tokens.push(`${JSON.stringify(path)}|${type}|${scalar}`);
  }
  visit(row, []);
  tokens.sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
  return createHash('md5').update(tokens.join('\n')).digest('hex');
}

export function comparisonRow(table, row) {
  const result = { user_id: row.user_id, updated_at: new Date(row.updated_at).getTime() };
  if (!Number.isFinite(result.updated_at)) throw new Error('Invalid update timestamp');
  if (table === 'user_daily_progress') {
    for (const key of ['day_key', 'water_cups', 'steps', 'workout_completed']) result[key] = row[key];
  } else {
    result.payload = typeof row.payload === 'string' ? JSON.parse(row.payload) : row.payload;
    if (table === 'user_app_state') result.revision = row.revision;
    else result.food_id = row.food_id;
  }
  return result;
}

export const expectedCounts = {
  user_app_state: 14,
  user_daily_progress: 59,
  user_custom_foods: 9,
};

export function validateTargetDefaults(table, columns) {
  const expected = table === 'user_app_state' ? {payload:'{}',revision:1} :
    table === 'user_daily_progress' ? {water_cups:0,steps:0,workout_completed:false} : {};
  for (const [key,value] of Object.entries(expected)) {
    const column = columns.find(column=>column.key===key);
    if (!column || column.status!=='available' || column.default!==value) {
      throw new Error(`${table}: unexpected default for ${key}`);
    }
  }
  return true;
}

// Never print user IDs, emails, payloads, credentials, or HTTP response bodies.
export function validateRows(table, rows, userIds, expectedCount) {
  if (rows.length !== expectedCount) throw new Error(`${table}: unexpected row count`);
  const keys = new Set();
  for (const row of rows) {
    if (!userIds.has(row.user_id)) throw new Error(`${table}: owner missing from Auth`);
    const key = JSON.stringify([row.user_id, row.food_id ?? row.day_key ?? null]);
    if (keys.has(key)) throw new Error(`${table}: duplicate logical key`);
    keys.add(key);
    if (table === 'user_daily_progress') {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(row.day_key) ||
          !Number.isInteger(row.water_cups) || row.water_cups < 0 || row.water_cups > 100 ||
          !Number.isInteger(row.steps) || row.steps < 0 || row.steps > 500000 ||
          typeof row.workout_completed !== 'boolean') {
        throw new Error(`${table}: invalid daily progress`);
      }
    } else {
      let payload;
      try { payload = typeof row.payload === 'string' ? JSON.parse(row.payload) : row.payload; }
      catch { throw new Error(`${table}: invalid JSON payload`); }
      if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
        throw new Error(`${table}: payload must be an object`);
      }
      if (table === 'user_app_state' && (!Number.isInteger(row.revision) || row.revision < 1)) {
        throw new Error(`${table}: invalid revision`);
      }
    }
  }
  return { table, rows: rows.length, uniqueKeys: keys.size, ownersValid: true, dataValid: true };
}

async function audit() {
  const key = process.env.APPWRITE_API_KEY;
  if (!key) throw new Error('APPWRITE_API_KEY is required; never pass it as a command argument');
  const endpoint = 'https://fra.cloud.appwrite.io/v1';
  const project = '6ac5fccb0004756daef1';
  async function get(path) {
    const response = await fetch(`${endpoint}${path}`, {
      headers: { 'X-Appwrite-Project': project, 'X-Appwrite-Key': key },
      signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) throw new Error(`Appwrite audit request failed (${response.status})`);
    return response.json();
  }
  async function list(path, field) {
    const all = [];
    for (let offset = 0; ; offset += 100) {
      const query = new URLSearchParams();
      query.append('queries[]', JSON.stringify({ method: 'limit', values: [100] }));
      query.append('queries[]', JSON.stringify({ method: 'offset', values: [offset] }));
      const page = await get(`${path}?${query}`);
      if (!Array.isArray(page[field])) throw new Error('Unexpected Appwrite response');
      all.push(...page[field]);
      if (all.length >= page.total) return all;
      if (!page[field].length) throw new Error('Pagination ended before total');
    }
  }
  const users = await list('/users', 'users');
  if (users.length !== 14) throw new Error('Unexpected imported Auth user count');
  const userIds = new Set(users.map(user => user.$id));
  const tables = [];
  const repairPlan = process.env.APPWRITE_EMPTY_OBJECT_PLAN ?
    JSON.parse(await readFile(process.env.APPWRITE_EMPTY_OBJECT_PLAN, 'utf8')) : null;
  for (const [table, count] of Object.entries(expectedCounts)) {
    const path = `/tablesdb/public/tables/${table}`;
    const definition = await get(path);
    const defaultsValid = validateTargetDefaults(table,definition.columns ?? []);
    const rows = await list(`${path}/rows`, 'rows');
    const indexes = await get(`${path}/indexes`);
    const repairedRows = table === 'user_app_state' && repairPlan ? rows.map(row => {
      const ownerHash = createHash('md5').update(row.user_id).digest('hex');
      const ownerPlan = repairPlan.find(entry => entry.owner_hash === ownerHash);
      if (!ownerPlan) throw new Error('Repair plan missing owner');
      const payload = comparisonRow(table,row).payload;
      return {...row,payload:restoreEmptyObjects(payload,ownerPlan.empty_object_paths)};
    }) : null;
    tables.push({
      ...validateRows(table, rows, userIds, count),
      fingerprints: rows.map(row => rowFingerprint(comparisonRow(table, row))).sort(),
      repairedFingerprints: repairedRows?.map(row => rowFingerprint(comparisonRow(table,row))).sort(),
      fieldFingerprints: table === 'user_app_state' ? Object.fromEntries(
        ['user_id', 'payload', 'revision', 'updated_at'].map(field => [field,
          rows.map(row => rowFingerprint({[field]:comparisonRow(table,row)[field]})).sort()]),
      ) : undefined,
      rowSecurity: definition.rowSecurity,
      defaultsValid,
      columns: definition.columns?.map(column => ({key:column.key,type:column.type,
        status:column.status,required:column.required,default:column.default})),
      tablePermissionCount: definition.$permissions?.length ?? 0,
      rowsWithPermissions: rows.filter(row => row.$permissions?.length > 0).length,
      ownerOnlyRead: rows.every(row => JSON.stringify(row.$permissions) ===
        JSON.stringify([`read("user:${row.user_id}")`])),
      indexes: indexes.indexes.map(index => ({key:index.key,type:index.type,status:index.status,
        columns:index.columns,orders:index.orders})),
    });
  }
  console.log(JSON.stringify({ project, users: users.length, tables }, null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  audit().catch(error => { console.error(error.message); process.exitCode = 1; });
}
