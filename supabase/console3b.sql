-- The owner's console, part C, after its review (c3fix, 2026-11-15;
-- docs/ADMIN.md): admin_export again, as console3.sql made it but quick on
-- a busy account.
--
-- The export of a test account with a thousand connector tabs took 6 to 10
-- seconds in the database and timed out at the site about half the time:
-- every row was made whole (to_jsonb of the row) before the secret columns
-- were taken out, so each tab's 110 KB tool list (relay_tabs.hello) was read
-- and taken apart, and every value over 8 KB was written out as text only to
-- be measured. Now
--   - the columns are named from the catalogue and the hidden ones never
--     read: hello (the tab's own answers to initialize and tools/list) and
--     list (that tool list's text) join hash, rh, code_challenge, channel,
--     secret and token, and oc_rh, the orangecheck handle kept beside rh;
--   - a value is measured with pg_column_size, not written out as text: one
--     stored in over 8 KB is not read at all, and one whose JSON is over
--     8 KB is not given either; each is {"not_exported": its bytes}.
--
-- Over the test accounts the export is the same as before, row for row and
-- column for column, but for the columns now hidden and the bytes a value
-- left out is said to have (as stored, where it was stored in over 8 KB).
-- The busy account's export takes 0.15 to 0.2 s in the database (6.2 to
-- 9.8 s before). Only admin_export changes; it is still the server's alone.

-- Every row of [p_account] in every table of public with a foreign key to
-- auth.users ("table" or "table.column" when a table has two), at most
-- 1000 a table, and the items of its lists:
-- {tables: {name: [rows]}, more: {name: rows in all, where over 1000}, at}.
-- Never what keeps a sign-in safe: oauth_codes, oc_sessions and the audit are
-- left out, and every column named as a secret (hash, rh, oc_rh,
-- code_challenge, channel, secret, token) or as the connector's working
-- state (hello, list) is never read. A value over 8 KB, stored or as JSON,
-- is the app's own working state, not something the person wrote: it is
-- given as {"not_exported": its bytes}, so the download stays one a browser
-- can hold.
create or replace function public.admin_export(p_account uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    found record;
    rows jsonb;
    named text;
    total bigint;
    shown text;
    out jsonb := '{}'::jsonb;
    more jsonb := '{}'::jsonb;
    hidden constant text[] := array['hash', 'rh', 'oc_rh', 'code_challenge', 'channel', 'secret', 'token', 'hello', 'list'];
begin
    for found in
        select c.conrelid as rel, c.conrelid::regclass::text as tbl, rel.relname, a.attname as col,
               count(*) over (partition by c.conrelid) as columns
          from pg_catalog.pg_constraint c
          join pg_catalog.pg_class rel on rel.oid = c.conrelid
          join pg_catalog.pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
         where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and cardinality(c.conkey) = 1
           and rel.relnamespace = 'public'::regnamespace
           and rel.relname not in ('oauth_codes', 'oc_sessions', 'admin_audit')
         order by rel.relname, a.attname
    loop
        named := case when found.columns > 1 then found.relname || '.' || found.col else found.relname end;
        execute format('select count(*) from %s where %I = $1', found.tbl, found.col) into total using p_account;
        if total = 0 then
            continue;
        end if;
        -- The row as an object of its shown columns, forty to a
        -- jsonb_build_object (which takes at most a hundred arguments).
        select string_agg(part, ' || ' order by chunk) into shown
          from (select chunk, 'pg_catalog.jsonb_build_object(' || string_agg(pair, ', ' order by attnum) || ')' as part
                  from (select a.attnum, (row_number() over (order by a.attnum) - 1) / 40 as chunk,
                               format('%L, case when pg_catalog.pg_column_size(t.%I) > 8192 '
                                      || 'then pg_catalog.jsonb_build_object(''not_exported'', pg_catalog.pg_column_size(t.%I)) '
                                      || 'when pg_catalog.pg_column_size(pg_catalog.to_jsonb(t.%I)) > 8192 '
                                      || 'then pg_catalog.jsonb_build_object(''not_exported'', pg_catalog.pg_column_size(pg_catalog.to_jsonb(t.%I))) '
                                      || 'else pg_catalog.to_jsonb(t.%I) end', a.attname, a.attname, a.attname, a.attname, a.attname, a.attname) as pair
                          from pg_catalog.pg_attribute a
                         where a.attrelid = found.rel and a.attnum > 0 and not a.attisdropped
                           and a.attname <> all (hidden)) cols
                 group by chunk) parts;
        if shown is null then
            shown := '''{}''::jsonb';
        end if;
        execute format('select coalesce(jsonb_agg(%s), ''[]''::jsonb) from (select * from %s where %I = $1 limit 1000) t',
                       shown, found.tbl, found.col)
           into rows using p_account;
        out := out || jsonb_build_object(named, rows);
        if total > 1000 then
            more := more || jsonb_build_object(named, total);
        end if;
    end loop;
    begin
        execute 'select coalesce(jsonb_agg(to_jsonb(i)), ''[]''::jsonb) from (select i.* from public.model_collection_items i '
             || 'join public.model_collections c on c.id = i.collection where c.owner = $1 limit 1000) i'
           into rows using p_account;
        if jsonb_array_length(rows) > 0 then
            out := out || jsonb_build_object('model_collection_items', rows);
        end if;
    exception when undefined_table or undefined_column then
        null;
    end;
    return jsonb_build_object('tables', out, 'more', more, 'at', now());
end;
$$;

revoke all on function public.admin_export(uuid) from public, anon, authenticated;
grant execute on function public.admin_export(uuid) to service_role;

notify pgrst, 'reload schema';
