with recursive source_rows as (
 select 'user_app_state' as table_name, to_jsonb(t) || jsonb_build_object('updated_at', floor(extract(epoch from updated_at)*1000)) as doc from public.user_app_state t
 union all select 'user_daily_progress', to_jsonb(t) || jsonb_build_object('updated_at', floor(extract(epoch from updated_at)*1000)) from public.user_daily_progress t
 union all select 'user_custom_foods', to_jsonb(t) || jsonb_build_object('updated_at', floor(extract(epoch from updated_at)*1000)) from public.user_custom_foods t
), numbered as (
 select table_name, row_number() over () as rid, doc from source_rows
), nodes as (
 select table_name,rid,array[]::text[] as path,doc as val from numbered
 union all
 select n.table_name,n.rid,n.path || c.key,c.val
 from nodes n cross join lateral (
   select key,value as val from jsonb_each(case when jsonb_typeof(n.val)='object' then n.val else '{}'::jsonb end)
   union all
   select (ordinality-1)::text,value from jsonb_array_elements(case when jsonb_typeof(n.val)='array' then n.val else '[]'::jsonb end) with ordinality
 ) c
), leaves as (
 select table_name,rid,array_to_json(path)::text || '|' || jsonb_typeof(val) || '|' ||
 case jsonb_typeof(val)
 when 'number' then encode(float8send(case when (val#>>'{}')::float8=0 then 0::float8 else (val#>>'{}')::float8 end),'hex')
 when 'null' then 'null'
 when 'object' then '{}'
 when 'array' then '[]'
 else val#>>'{}' end as token
 from nodes
 where jsonb_typeof(val) not in ('object','array') or val in ('{}'::jsonb,'[]'::jsonb)
), hashes as (
 select table_name,rid,md5(string_agg(token,E'\n' order by token collate "C")) as fingerprint from leaves group by table_name,rid
)
select table_name,count(*) as rows,jsonb_agg(fingerprint order by fingerprint) as fingerprints from hashes group by table_name order by table_name;
