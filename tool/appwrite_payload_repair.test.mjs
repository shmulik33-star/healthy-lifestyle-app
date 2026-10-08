import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { prepareRepairs } from './appwrite_payload_repair.mjs';
import { rowFingerprint, comparisonRow } from './appwrite_migration_audit.mjs';

const md5 = value => createHash('md5').update(value).digest('hex');
function fixture() {
  const rows = Array.from({length:14},(_,i)=>({$id:`row-${i}`,user_id:`owner-${i}`,
    revision:1,updated_at:'2026-10-07T00:00:00Z',payload:'{"map":[],"list":[]}',$permissions:[]}));
  const plans = rows.map(row=>({owner_hash:md5(row.user_id),empty_object_paths:[md5('["map"]')]}));
  const expected = rows.map(row=>rowFingerprint(comparisonRow('user_app_state',{
    ...row,payload:{map:{},list:[]},
  })));
  return {rows,plans,expected};
}
test('preflights all 14 source-matching operations without modifying input',()=>{
  const {rows,plans,expected} = fixture();
  const operations = prepareRepairs(rows,plans,expected);
  assert.equal(operations.length,14);
  assert.ok(operations.every(op=>op.before!==op.after));
  assert.equal(rows[0].payload,'{"map":[],"list":[]}');
  assert.deepEqual(operations[0].repaired.payload,{map:{},list:[]});
});
test('refuses wrong counts, duplicate owners, missing plans and source mismatch',()=>{
  const {rows,plans,expected} = fixture();
  assert.throws(()=>prepareRepairs(rows.slice(1),plans,expected),/count/);
  assert.throws(()=>prepareRepairs([rows[0],...rows.slice(0,13)],plans,expected),/identities/);
  assert.throws(()=>prepareRepairs(rows,[...plans.slice(1),plans[1]],expected),/plan/);
  assert.throws(()=>prepareRepairs(rows,plans,[...expected.slice(1),'invalid']),/match source/);
});
