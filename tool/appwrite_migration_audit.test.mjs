import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { validateRows, rowFingerprint, comparisonRow, restoreEmptyObjects, validateTargetDefaults } from './appwrite_migration_audit.mjs';

test('checks falsy defaults strictly instead of confusing 0/false with NULL',()=>{
  const columns = [
    {key:'water_cups',default:0,status:'available'},
    {key:'steps',default:0,status:'available'},
    {key:'workout_completed',default:false,status:'available'},
  ];
  assert.equal(validateTargetDefaults('user_daily_progress',columns),true);
  assert.throws(()=>validateTargetDefaults('user_daily_progress',columns.map(c=>({...c,default:null}))),/default/);
  assert.throws(()=>validateTargetDefaults('user_daily_progress',columns.map(c=>c.key==='workout_completed'?{...c,default:true}:c)),/default/);
  assert.throws(()=>validateTargetDefaults('user_app_state',[
    {key:'payload',default:"'{}'::jsonb",status:'available'},{key:'revision',default:1,status:'available'},
  ]),/default/);
});

test('repairs only exact source-empty-object paths, retaining legitimate arrays', () => {
  const pathHash = createHash('md5').update(JSON.stringify(['nested','0','map'])).digest('hex');
  const imported = {nested:[{map:[],list:[]}],list:[]};
  assert.deepEqual(restoreEmptyObjects(imported,[pathHash]),{nested:[{map:{},list:[]}],list:[]});
  assert.deepEqual(imported,{nested:[{map:[],list:[]}],list:[]});
  assert.deepEqual(restoreEmptyObjects({nested:[{map:{}}]},[pathHash]),{nested:[{map:{}}]});
  assert.throws(()=>restoreEmptyObjects({nested:[{map:[1]}]},[pathHash]),/precondition/);
  assert.throws(()=>restoreEmptyObjects({},[pathHash]),/missing/);
});

const owners = new Set(['owner']);
const profile = { user_id: 'owner', payload: '{"profile":{}}', revision: 3 };
test('fingerprint ignores object order but preserves types and array order', () => {
  assert.equal(rowFingerprint({a:1,b:{x:'עברית',y:[]}}),rowFingerprint({b:{y:[],x:'עברית'},a:1}));
  assert.notEqual(rowFingerprint({a:1}),rowFingerprint({a:'1'}));
  assert.notEqual(rowFingerprint([1,2]),rowFingerprint([2,1]));
  assert.notEqual(rowFingerprint({}),rowFingerprint([]));
  assert.notEqual(rowFingerprint(null),rowFingerprint('null'));
});
test('comparison normalizes JSON payloads and timestamp timezones', () => {
  const row = {...profile,updated_at:'2026-10-07T12:00:00+03:00'};
  assert.deepEqual(comparisonRow('user_app_state',row),comparisonRow('user_app_state',{
    ...row,payload:{profile:{}},updated_at:'2026-10-07T09:00:00Z', $id:'ignored', $permissions:[],
  }));
  assert.throws(()=>comparisonRow('user_app_state',{...row,updated_at:'bad'}),/timestamp/);
});
test('accepts imported JSON strings and checks expected count', () => {
  assert.equal(validateRows('user_app_state', [profile], owners, 1).dataValid, true);
  assert.throws(() => validateRows('user_app_state', [profile], owners, 2), /row count/);
});
test('rejects missing owners, duplicate keys, and malformed payloads', () => {
  assert.throws(() => validateRows('user_app_state', [profile], new Set(), 1), /owner/);
  assert.throws(() => validateRows('user_app_state', [profile, profile], owners, 2), /duplicate/);
  assert.throws(() => validateRows('user_app_state', [{...profile,payload:'broken'}], owners, 1), /JSON/);
});
test('rejects invalid counter types and ranges', () => {
  const row = { user_id:'owner', day_key:'2026-10-07', water_cups:3, steps:200, workout_completed:false };
  assert.equal(validateRows('user_daily_progress', [row], owners, 1).dataValid, true);
  assert.throws(() => validateRows('user_daily_progress', [{...row,steps:-1}], owners, 1), /invalid/);
  assert.throws(() => validateRows('user_daily_progress', [{...row,workout_completed:'false'}], owners, 1), /invalid/);
});
