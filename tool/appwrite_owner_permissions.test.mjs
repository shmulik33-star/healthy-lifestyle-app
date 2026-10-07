import test from 'node:test';
import assert from 'node:assert/strict';
import { ownerReadPermission,prepareOwnerPermissions } from './appwrite_owner_permissions.mjs';
import { comparisonRow,rowFingerprint } from './appwrite_migration_audit.mjs';

const owner='00000000-0000-0000-0000-000000000001';
const owners=new Set([owner]);
const definition={rowSecurity:true,$permissions:[]};
function fixture() {
  const rows=Array.from({length:9},(_,i)=>({$id:`row-${i}`,user_id:owner,food_id:`food-${i}`,
    updated_at:'2026-10-07T00:00:00Z',payload:'{}',$permissions:[]}));
  return {rows,hashes:rows.map(row=>rowFingerprint(comparisonRow('user_custom_foods',row)))};
}
test('owner read role is exact and rejects role injection',()=>{
  assert.equal(ownerReadPermission(owner),`read("user:${owner}")`);
  assert.throws(()=>ownerReadPermission('any'),/identifier/);
  assert.throws(()=>ownerReadPermission(`${owner}") write("any`),/identifier/);
});
test('prepares owner-only reads without mutating data; rerun is idempotent',()=>{
  const {rows,hashes}=fixture();
  const operations=prepareOwnerPermissions('user_custom_foods',definition,rows,owners,hashes);
  assert.ok(operations.every(op=>JSON.stringify(op.permissions)===JSON.stringify([ownerReadPermission(owner)])));
  assert.ok(rows.every(row=>row.$permissions.length===0));
  const already=rows.map(row=>({...row,$permissions:[ownerReadPermission(owner)]}));
  assert.equal(prepareOwnerPermissions('user_custom_foods',definition,already,owners,hashes).length,9);
});
test('refuses disabled security, broad permissions, foreign owners and source mismatch',()=>{
  const {rows,hashes}=fixture();
  const prepare=(def=definition,items=rows,ids=owners,expected=hashes)=>
    prepareOwnerPermissions('user_custom_foods',def,items,ids,expected);
  assert.throws(()=>prepare({...definition,rowSecurity:false}),/row security/);
  assert.throws(()=>prepare({...definition,$permissions:['read("any")']}),/table permissions/);
  assert.throws(()=>prepare(definition,rows.map(row=>({...row,$permissions:['read("any")']}))),/existing permissions/);
  assert.throws(()=>prepare(definition,rows,new Set()),/owner/);
  assert.throws(()=>prepare(definition,rows,owners,[...hashes.slice(1),'invalid']),/mismatch/);
});
