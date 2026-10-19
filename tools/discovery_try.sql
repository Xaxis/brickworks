-- What supabase/discovery.sql does, tried inside the rolled-back transaction
-- of a dry run: nothing here is kept.
--
--   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node --env-file=.env \
--     tools/apply_sql.mjs supabase/discovery.sql --dry --try=tools/discovery_try.sql --table=gallery_picks
--
-- After the live files (trust, tested, comments, builds, versions,
-- follows), which the project has. One made-up account, made and gone with
-- the transaction, 13 or over at a Resend test address, so every model here
-- is a test model, which only a list asked with tests shows. Times are set
-- by hand: inside one transaction now() never moves. Each statement is on
-- one line: the dry run splits at a semicolon that ends a line.
--
--   Tower   120 parts, listed 3 days ago, Tested, built twice this week
--   Wall    180 parts, listed 30 days ago, built four times 10 days ago
--   Bridge  900 parts, listed 20 days ago, built once this week, and
--           remixed this week by Longer
--   Barn     60 parts, listed 2 days ago, Tested, never built
--   Longer  950 parts, listed yesterday, a remix of Bridge, nothing else
--   Mill    300 parts, listed 40 days ago, Tested, nothing this week
--
-- And Bob, whose collection holds every piece of Tower and of Barn, and one
-- of Wall's three.
create function pg_temp.tries(statement text) returns text language plpgsql as $$ begin execute statement; return 'allowed'; exception when others then return 'refused: ' || sqlerrm; end $$;
insert into auth.users (id, instance_id, aud, role, email) values ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'discovery-ada@resend.dev'), ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'discovery-bob@resend.dev');
select public.answer_age('00000000-0000-4000-8000-0000000000d1', true)->>'over_13' as ada;
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, remixed_from) values ('DiscTry001', '00000000-0000-4000-8000-0000000000d1', 'Discovery Try Tower', 'Ada Try', 120, 100, true, now() - interval '3 days', true, null), ('DiscTry002', '00000000-0000-4000-8000-0000000000d1', 'Discovery Try Wall', 'Ada Try', 180, 100, true, now() - interval '30 days', true, null), ('DiscTry003', '00000000-0000-4000-8000-0000000000d1', 'Discovery Try Bridge', 'Ada Try', 900, 100, true, now() - interval '20 days', true, null), ('DiscTry004', '00000000-0000-4000-8000-0000000000d1', 'Discovery Try Barn', 'Ada Try', 60, 100, true, now() - interval '2 days', true, null), ('DiscTry006', '00000000-0000-4000-8000-0000000000d1', 'Discovery Try Mill', 'Ada Try', 300, 100, true, now() - interval '40 days', true, null);
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, remixed_from) values ('DiscTry005', '00000000-0000-4000-8000-0000000000d1', 'Discovery Try Bridge, longer', 'Ada Try', 950, 100, true, now() - interval '1 day', true, 'DiscTry003');
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, listed_at, parts, 100 from public.shared_models where id like 'DiscTry%';
insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) select id, 1, '0.3.0', repeat('a', 64), parts, 3, '{"stands": {"ok": true, "why": "Try"}, "steps": {"ok": true, "why": "Try"}, "parts": {"ok": true, "why": "Try"}, "whole": {"ok": true, "why": "Try"}}', true from public.shared_models where id in ('DiscTry001', 'DiscTry004', 'DiscTry006');
-- Builds finished, as count_build counts them, then moved to when they were.
select public.count_build('DiscTry001', repeat('1', 32)) and public.count_build('DiscTry001', repeat('2', 32)) as tower, public.count_build('DiscTry002', repeat('1', 32)) and public.count_build('DiscTry002', repeat('2', 32)) and public.count_build('DiscTry002', repeat('3', 32)) and public.count_build('DiscTry002', repeat('4', 32)) as wall, public.count_build('DiscTry003', repeat('1', 32)) as bridge;
update public.model_builds set at = now() - interval '10 days' where model = 'DiscTry002';
-- The score: a build 3, a remix 2, Tested 5.
select public.gallery_score(2, 0, true) as "two builds, Tested", public.gallery_score(4, 0, false) as "four builds", public.gallery_score(1, 1, false) as "a build and a remix", public.gallery_score(0, 0, true) as "Tested alone", public.gallery_score(null, null, null) as "nothing";
-- Top builds, as the gallery asks it (with tests, these being test models): Wall 12, Tower 11, then Bridge, Barn and Mill at 5 (Bridge built once, then the newer), Longer 0.
select c->>'id' as id, c->>'name' as name, c->>'builds' as builds, c->>'remixes' as remixes, c->>'tested' as tested from public.directory_models('{"tests": true, "sort": "top", "words": "discovery:* & try:*", "size": 10}'::jsonb) c;
-- It pages: two at a time, nothing twice, nothing missed.
select string_agg(c->>'id', ', ') as "page 1" from public.directory_models('{"tests": true, "sort": "top", "words": "discovery:* & try:*", "size": 2, "skip": 0}'::jsonb) c;
select string_agg(c->>'id', ', ') as "page 2" from public.directory_models('{"tests": true, "sort": "top", "words": "discovery:* & try:*", "size": 2, "skip": 2}'::jsonb) c;
select string_agg(c->>'id', ', ') as "page 3" from public.directory_models('{"tests": true, "sort": "top", "words": "discovery:* & try:*", "size": 2, "skip": 4}'::jsonb) c;
-- Most built, and the other sorts, as before.
select string_agg(c->>'id', ', ') as "most built" from public.directory_models('{"tests": true, "sort": "builds", "words": "discovery:* & try:*", "size": 10}'::jsonb) c;
select string_agg(c->>'id', ', ') as "newest" from public.directory_models('{"tests": true, "words": "discovery:* & try:*", "size": 10}'::jsonb) c;
-- Small builds: the Size filter's Small (under 200 parts), by Top builds: Wall, Tower, Barn.
select string_agg(c->>'id', ', ') as "small builds" from public.directory_models('{"tests": true, "sort": "top", "words": "discovery:* & try:*", "most": 199, "size": 10}'::jsonb) c;
-- Without tests, a visitor's list: none of them.
select count(*) as "a visitor's Top builds of test models" from public.directory_models('{"sort": "top", "words": "discovery:* & try:*", "size": 10}'::jsonb) c;
-- The week: Tower (2 builds, Tested: 11), Bridge (a build and Longer: 5), Barn (listed this week, Tested: 5). Not Wall (built 10 days ago), Mill (nothing this week), Longer (nothing says it builds).
select w->'card'->>'id' as id, w->'week'->>'builds' as builds, w->'week'->>'remixes' as remixes, w->'week'->>'tested' as tested, w->'week'->>'score' as score from public.gallery_week(true, 10) w where w->'card'->>'id' like 'DiscTry%';
-- The pick, worked out: Tower. A visitor's leaves out test models.
select p->>'chosen' as chosen, p->'card'->>'id' as model, p->'week'->>'score' as score, p->>'pick' as pick from (select public.gallery_pick(true) as p) x;
select coalesce(p->'card'->>'id', 'none') as "a visitor's pick", coalesce(p->'card'->>'id', '') like 'DiscTry%' as "is a test model" from (select public.gallery_pick(false) as p) x;
-- The owner chooses Mill for a week: it is the pick, said chosen, until a week from now, with its own week's numbers.
select public.gallery_choose_pick('DiscTry006', 7) - 'pick' - 'chosen_at' as "Mill chosen";
select p->>'chosen' as chosen, p->'card'->>'id' as model, (p->>'until')::timestamptz = now() + interval '7 days' as "until a week from now", p->'week' as week from (select public.gallery_pick(true) as p) x;
-- What may not be chosen: a model not in the gallery, a model nobody has, and a length that is not 1 to 31 days.
update public.shared_models set listed = false, listed_at = null where id = 'DiscTry005';
select public.gallery_choose_pick('DiscTry005', 7) as "unlisted", public.gallery_choose_pick('NoSuchOne1', 7) as "nobody's";
select pg_temp.tries($q$select public.gallery_choose_pick('DiscTry004', 0)$q$) as "0 days", pg_temp.tries($q$select public.gallery_choose_pick('DiscTry004', 32)$q$) as "32 days", pg_temp.tries($q$insert into public.gallery_picks (model, chosen_at, until) values ('DiscTry004', now(), now() + interval '40 days')$q$) as "40 days, written directly";
-- The newest choice wins; one that left the gallery is passed over, back to the one before.
select public.gallery_choose_pick('DiscTry004', 3)->>'model' as "then Barn, for three days";
select p->'card'->>'id' as "the pick" from (select public.gallery_pick(true) as p) x;
select string_agg((c->>'model') || ' shown ' || (c->>'shown') || ' test ' || (c->>'test'), ', ') as "the open choices, newest first" from public.gallery_choices() c where c->>'model' like 'DiscTry%';
update public.shared_models set listed = false, listed_at = null where id = 'DiscTry004';
select p->'card'->>'id' as "Barn unlisted: the pick", p->>'chosen' as chosen from (select public.gallery_pick(true) as p) x;
-- Ended: back to the worked-out pick, and an end that was ended once is not ended again.
select public.gallery_end_pick((public.gallery_pick(true)->>'pick')::bigint) as "Mill ended";
select p->'card'->>'id' as "the pick now", p->>'chosen' as chosen from (select public.gallery_pick(true) as p) x;
select public.gallery_end_pick(max(id)) as "Barn's, ended", public.gallery_end_pick(min(id)) as "Mill's again" from public.gallery_picks where model in ('DiscTry004', 'DiscTry006');
-- A choice that ran out is not the pick.
select public.gallery_choose_pick('DiscTry003', 1)->>'model' as "Bridge for a day";
update public.gallery_picks set chosen_at = now() - interval '2 days', until = now() - interval '1 day' where model = 'DiscTry003';
select p->'card'->>'id' as "a day later: the pick", p->>'chosen' as chosen from (select public.gallery_pick(true) as p) x;
-- Build with what I own. What four models need, as api/share.js counts it; Bridge not counted yet. The same lot twice is one.
select public.owned_keep_needs('DiscTry001', '[{"part": "3001", "colour": 4, "qty": 2}, {"part": "3003", "colour": 1, "qty": 1}]') as tower, public.owned_keep_needs('DiscTry002', '[{"part": "3001", "colour": 15, "qty": 2}, {"part": "3001", "colour": 15, "qty": 1}]') as wall, public.owned_keep_needs('DiscTry004', '[{"part": "3001", "colour": 4, "qty": 1}]') as barn, public.owned_keep_needs('DiscTry006', '[{"part": "3001", "colour": 2, "qty": 300}]') as mill;
select public.owned_keep_needs('DiscTry002', '[{"part": "3001", "colour": 15, "qty": 3}]') as "wall again, in place of before", (select count(*) from public.model_needs where model = 'DiscTry002') as "wall's lots";
select pg_temp.tries($q$select public.owned_keep_needs('DiscTry004', '{"part": "3001"}')$q$) as "needs that are not a list";
-- Bob's pool: two red bricks, a blue one, a white one, and 50 green.
select public.owned_keep_pool('00000000-0000-4000-8000-0000000000d2', '[{"part": "3001", "colour": 4, "qty": 2}, {"part": "3003", "colour": 1, "qty": 1}, {"part": "3001", "colour": 15, "qty": 1}, {"part": "3001", "colour": 2, "qty": 50}]', '{"99999-1"}') as "Bob's pool";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000d2') - 'at' as "what is kept of it", public.owned_pool_of('00000000-0000-4000-8000-0000000000d1') as "Ada has none";
update public.shared_models set listed = true, listed_at = now() - interval '2 days' where id = 'DiscTry004';
-- Each card, for Bob: Tower 3 of 3, Barn (listed again) 1 of 1, Wall 1 of 3, Mill 50 of 300, Bridge not counted (Longer is unlisted). For nobody: no share at all.
select c->>'id' as id, c->'owned'->>'have' as have, c->'owned'->>'pieces' as pieces from public.directory_models('{"tests": true, "words": "discovery:* & try:*", "pool": "00000000-0000-4000-8000-0000000000d2", "size": 10}'::jsonb) c;
select count(*) filter (where c ? 'owned') as "cards with a share, asked with no pool" from public.directory_models('{"tests": true, "words": "discovery:* & try:*", "size": 10}'::jsonb) c;
-- By what Bob owns: the whole of Tower and Barn first (more pieces first), then Wall (a third), Mill (a sixth), and Bridge, not counted. What he can build now: Tower and Barn, by Top builds.
select string_agg(c->>'id', ', ') as "sort owned" from public.directory_models('{"tests": true, "words": "discovery:* & try:*", "pool": "00000000-0000-4000-8000-0000000000d2", "sort": "owned", "size": 10}'::jsonb) c;
select string_agg(c->>'id', ', ') as "build now" from public.directory_models('{"tests": true, "words": "discovery:* & try:*", "pool": "00000000-0000-4000-8000-0000000000d2", "buildable": true, "sort": "top", "size": 10}'::jsonb) c;
select pg_temp.tries($q$select public.owned_keep_pool(null, '[]')$q$) as "a pool of nobody";
-- An account taken out: none of its models in the week or the pick.
insert into public.barred_accounts (account, reason) values ('00000000-0000-4000-8000-0000000000d1', 'Try');
select count(*) as "its models in the week" from public.gallery_week(true, 20) w where w->'card'->>'id' like 'DiscTry%';
select coalesce(public.gallery_pick(true)->'card'->>'id', 'none') like 'DiscTry%' as "its model the pick";
delete from public.barred_accounts where account = '00000000-0000-4000-8000-0000000000d1';
-- Nobody but the server: no grant on gallery_picks to any key, the service role's included; the functions the service role's alone.
select count(*) as "grants on gallery_picks to anon, authenticated or service_role" from information_schema.role_table_grants where table_schema = 'public' and table_name = 'gallery_picks' and grantee in ('anon', 'authenticated', 'service_role');
select relname, relrowsecurity from pg_class where relname = 'gallery_picks' and relkind = 'r';
select count(*) as "grants on the needs and pools tables to anon, authenticated or service_role" from information_schema.role_table_grants where table_schema = 'public' and table_name in ('model_needs', 'model_needs_kept', 'collection_pools', 'collection_pools_kept') and grantee in ('anon', 'authenticated', 'service_role');
select string_agg(relname || ' ' || relrowsecurity, ', ' order by relname) as "row security" from pg_class where relname in ('model_needs', 'model_needs_kept', 'collection_pools', 'collection_pools_kept') and relkind = 'r';
select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon, has_function_privilege('authenticated', p.oid, 'execute') as authenticated, has_function_privilege('service_role', p.oid, 'execute') as service_role from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('owned_keep_needs', 'owned_keep_pool', 'owned_forget_pool', 'owned_pool_of', 'owned_uncounted', 'gallery_score', 'directory_models', 'gallery_shows', 'gallery_week_counts', 'gallery_week_of', 'gallery_week', 'gallery_pick', 'gallery_choose_pick', 'gallery_end_pick', 'gallery_choices') order by p.proname;
-- Every question builds.sql's directory_models knew, answered the same, card for card and in order: the old function made again here, beside the new.
create function pg_temp.directory_models_before(query jsonb) returns setof jsonb language sql stable as $$
    with asked as (
        select nullif(query->>'words', '') as words,
               nullif(query->>'kind', '') as kind,
               nullif(query->>'tag', '') as tag,
               (query->>'least')::integer as least_parts,
               (query->>'most')::integer as most_parts,
               coalesce((query->>'own_steps')::boolean, false) as own_steps,
               coalesce((query->>'technic')::boolean, false) as technic,
               coalesce((query->>'tested')::boolean, false) as tested,
               (query->>'owner')::uuid as owner,
               nullif(query->>'collection', '') as collection,
               (query->>'favourites')::uuid as favourites,
               coalesce((query->>'private')::boolean, false) as private,
               coalesce((query->>'tests')::boolean, false) as tests,
               coalesce(nullif(query->>'sort', ''), 'newest') as sort,
               least(greatest(coalesce((query->>'size')::integer, 25), 1), 49) as size,
               least(greatest(coalesce((query->>'skip')::integer, 0), 0), 20000) as skip
    )
    select public.directory_card(m)
      from asked a
     cross join public.shared_models m
      left join public.model_stats s on s.model = m.id
      left join lateral (
          select count(*) as n from public.shared_models r
           where r.remixed_from = m.id and r.published) rx on true
      left join lateral (
          select coalesce(
              (select i.at from public.model_collection_items i
                where i.collection = a.collection and i.model = m.id),
              (select f.at from public.model_favourites f
                where f.account = a.favourites and f.model = m.id)) as at) added on true
     where m.published and not m.barred
       and not exists (select 1 from public.barred_accounts b where b.account = m.owner)
       and (m.listed or a.private)
       and (not m.test or a.tests or a.private)
       and (a.words is null or m.search @@ to_tsquery('simple'::regconfig, a.words))
       and (a.kind is null or m.kind = a.kind)
       and (a.tag is null or m.tags @> array[a.tag])
       and (a.least_parts is null or m.parts >= a.least_parts)
       and (a.most_parts is null or m.parts <= a.most_parts)
       and (not a.own_steps or m.own_steps)
       and (not a.technic or m.technic)
       and (not a.tested or public.model_tested(m.id))
       and (a.owner is null or (m.owner = a.owner and m.author is not null and m.listed))
       and (a.collection is null or exists (select 1 from public.model_collection_items i
                                             where i.collection = a.collection and i.model = m.id))
       and (a.favourites is null or exists (select 1 from public.model_favourites f
                                             where f.account = a.favourites and f.model = m.id))
     order by
        case when a.sort = 'added' then added.at end desc nulls last,
        case when a.sort = 'views' then coalesce(s.views, 0) end desc nulls last,
        case when a.sort = 'likes' then coalesce(s.likes, 0) end desc nulls last,
        case when a.sort = 'remixes' then rx.n end desc nulls last,
        case when a.sort = 'builds' then coalesce(s.builds, 0) end desc nulls last,
        m.listed_at desc nulls last, m.updated_at desc, m.id desc
     limit (select size from asked) offset (select skip from asked)
$$;
select count(*) as questions, count(*) filter (where same) as "answered the same", string_agg(q::text, ' | ') filter (where not same) as "answered otherwise" from (select q, (select coalesce(jsonb_agg(c order by o), '[]') from pg_temp.directory_models_before(q) with ordinality as t(c, o)) = (select coalesce(jsonb_agg(c order by o), '[]') from public.directory_models(q) with ordinality as t(c, o)) as same from (values ('{}'::jsonb), ('{"sort": "views"}'::jsonb), ('{"sort": "likes"}'::jsonb), ('{"sort": "remixes"}'::jsonb), ('{"sort": "builds"}'::jsonb), ('{"tests": true}'::jsonb), ('{"tests": true, "sort": "builds"}'::jsonb), ('{"tests": true, "sort": "remixes"}'::jsonb), ('{"tests": true, "tested": true}'::jsonb), ('{"tests": true, "most": 199}'::jsonb), ('{"tests": true, "least": 200, "sort": "likes"}'::jsonb), ('{"tests": true, "size": 2, "skip": 3}'::jsonb), ('{"tests": true, "words": "discovery:* & try:*"}'::jsonb), ('{"owner": "00000000-0000-4000-8000-0000000000d1", "tests": true}'::jsonb), ('{"owner": "00000000-0000-4000-8000-0000000000d1", "private": true}'::jsonb), ('{"kind": "castle"}'::jsonb)) as v(q)) x;
-- How long they take: on the project's own gallery, and on one made here of 5,000 listed models, 20,000 builds over 30 days, 1,000 remixes and 500 Tested, all gone with the transaction.
create function pg_temp.timed(statement text) returns text language plpgsql as $$ declare t0 timestamptz; best numeric := null; first numeric := null; took numeric; begin for i in 1..3 loop t0 := clock_timestamp(); execute statement; took := round(extract(epoch from clock_timestamp() - t0) * 1000, 1); first := coalesce(first, took); best := least(coalesce(best, took), took); end loop; return format('%s ms first, %s ms best of 3', first, best); end $$;
select pg_temp.timed($q$select count(*) from public.directory_models('{"sort": "top", "size": 25}'::jsonb)$q$) as "the project's Top builds, page 1", pg_temp.timed($q$select count(*) from public.directory_models('{"size": 25}'::jsonb)$q$) as "its newest, page 1", pg_temp.timed($q$select public.gallery_pick(false)$q$) as "its pick";
insert into public.shared_models (id, owner, name, author, parts, bytes, listed, listed_at, test, remixed_from) select 'DiscB' || lpad(g::text, 5, '0'), '00000000-0000-4000-8000-0000000000d1', 'Discovery big ' || g, 'Ada Try', 20 + (g * 37) % 3000, 100, true, now() - (g * interval '13 minutes'), true, case when g % 5 = 0 then 'DiscB' || lpad((1 + (g * 7) % 4999)::text, 5, '0') end from generate_series(1, 5000) g;
insert into public.share_versions (model, n, at, parts, bytes) select id, 1, listed_at, parts, 100 from public.shared_models where id like 'DiscB%';
insert into public.share_tests (model, n, app, file_hash, parts, steps, tests, passed) select id, 1, '0.3.0', repeat('b', 64), parts, 3, '{"stands": {"ok": true, "why": "Try"}, "steps": {"ok": true, "why": "Try"}, "parts": {"ok": true, "why": "Try"}, "whole": {"ok": true, "why": "Try"}}', true from public.shared_models where id like 'DiscB%' and right(id, 1) = '7';
insert into public.model_builds (model, device, at) select 'DiscB' || lpad((1 + (g * 7919) % 5000)::text, 5, '0'), md5('discovery' || g), now() - ((g % 720) * interval '1 hour') from generate_series(1, 20000) g on conflict do nothing;
insert into public.model_stats (model, builds) select model, count(*) from public.model_builds where model like 'DiscB%' group by model on conflict (model) do update set builds = excluded.builds;
select (select count(*) from public.shared_models where id like 'DiscB%') as models, (select count(*) from public.model_builds where model like 'DiscB%') as builds, (select count(*) from public.model_builds where model like 'DiscB%' and at > now() - interval '7 days') as "builds this week", (select count(*) from public.shared_models where remixed_from like 'DiscB%') as remixes, (select count(*) from public.share_tests where model like 'DiscB%') as tested;
analyze public.shared_models;
analyze public.model_builds;
analyze public.model_stats;
select pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "sort": "top", "size": 25}'::jsonb)$q$) as "Top builds, page 1", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "sort": "top", "size": 25, "skip": 2000}'::jsonb)$q$) as "Top builds, page 81", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "sort": "builds", "size": 25}'::jsonb)$q$) as "Most built, page 1", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "size": 25}'::jsonb)$q$) as "newest, page 1";
-- And on the big gallery, deep pages too.
select count(*) as "big gallery: questions", count(*) filter (where same) as "answered the same", string_agg(q::text, ' | ') filter (where not same) as "answered otherwise" from (select q, (select coalesce(jsonb_agg(c order by o), '[]') from pg_temp.directory_models_before(q) with ordinality as t(c, o)) = (select coalesce(jsonb_agg(c order by o), '[]') from public.directory_models(q) with ordinality as t(c, o)) as same from (values ('{"tests": true}'::jsonb), ('{"tests": true, "sort": "builds"}'::jsonb), ('{"tests": true, "sort": "remixes", "skip": 2000}'::jsonb), ('{"tests": true, "sort": "views", "skip": 4990}'::jsonb), ('{"tests": true, "tested": true, "skip": 100}'::jsonb), ('{"tests": true, "most": 199, "sort": "builds"}'::jsonb)) as v(q)) x;
select pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "sort": "top", "most": 199, "size": 9}'::jsonb)$q$) as "the small shelf", pg_temp.timed($q$select count(*) from public.gallery_week(true, 10)$q$) as "the week's ten", pg_temp.timed($q$select public.gallery_pick(true)$q$) as "the pick";
-- Top builds on the big gallery pages too: the first 75 by three pages of 25 are the first 75 at once, in the same order.
select (select string_agg(c->>'id', ',' order by k, o) from (select 1 as k, c, o from public.directory_models('{"tests": true, "sort": "top", "size": 25, "skip": 0}'::jsonb) with ordinality as t(c, o) union all select 2, c, o from public.directory_models('{"tests": true, "sort": "top", "size": 25, "skip": 25}'::jsonb) with ordinality as t(c, o) union all select 3, c, o from public.directory_models('{"tests": true, "sort": "top", "size": 25, "skip": 50}'::jsonb) with ordinality as t(c, o)) p) = (select string_agg(c->>'id', ',' order by k, o) from (select 1 as k, c, o from public.directory_models('{"tests": true, "sort": "top", "size": 49, "skip": 0}'::jsonb) with ordinality as t(c, o) union all select 2, c, o from public.directory_models('{"tests": true, "sort": "top", "size": 26, "skip": 49}'::jsonb) with ordinality as t(c, o)) q) as "three pages are one list";
-- Build with what I own on the big gallery: every model needing 60 lots (300,000 rows), and Bob's collection at 2,000, then 5,000, then 20,000 lots (the most a collection holds), each kept as api/collection.js keeps it.
insert into public.model_needs (model, part, colour, qty) select m.id, (3001 + ((g * 13 + k * 7) % 900))::text, (k * 3 + g) % 40, 1 + (g + k) % 4 from generate_series(1, 5000) g join public.shared_models m on m.id = 'DiscB' || lpad(g::text, 5, '0') cross join generate_series(1, 60) k on conflict do nothing;
insert into public.model_needs_kept (model, pieces) select model, sum(qty) from public.model_needs where model like 'DiscB%' group by model;
analyze public.model_needs;
analyze public.model_needs_kept;
create function pg_temp.pool_of(lots integer) returns jsonb language sql as $$ select jsonb_agg(jsonb_build_object('part', (3001 + (i * 7) % 900)::text, 'colour', (i / 900) % 40, 'qty', 1 + i % 20)) from generate_series(1, lots) i $$;
select pg_temp.timed($q$select public.owned_keep_pool('00000000-0000-4000-8000-0000000000d2', pg_temp.pool_of(2000))$q$) as "keeping 2,000 lots";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000d2') - 'at' - 'unknown' as "kept";
analyze public.collection_pools;
select pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "sort": "owned", "size": 25}'::jsonb)$q$) as "2,000 lots: by what I own, page 1", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "buildable": true, "sort": "top", "size": 9}'::jsonb)$q$) as "build now", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "size": 25}'::jsonb)$q$) as "newest, with shares";
select pg_temp.timed($q$select public.owned_keep_pool('00000000-0000-4000-8000-0000000000d2', pg_temp.pool_of(5000))$q$) as "keeping 5,000 lots";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000d2') - 'at' - 'unknown' as "kept";
analyze public.collection_pools;
select pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "sort": "owned", "size": 25}'::jsonb)$q$) as "5,000 lots: by what I own, page 1", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "buildable": true, "sort": "top", "size": 9}'::jsonb)$q$) as "build now", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "size": 25}'::jsonb)$q$) as "newest, with shares";
select pg_temp.timed($q$select public.owned_keep_pool('00000000-0000-4000-8000-0000000000d2', pg_temp.pool_of(20000))$q$) as "keeping 20,000 lots";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000d2') - 'at' - 'unknown' as "kept";
analyze public.collection_pools;
select pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "sort": "owned", "size": 25}'::jsonb)$q$) as "20,000 lots: by what I own, page 1", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "buildable": true, "sort": "top", "size": 9}'::jsonb)$q$) as "build now", pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "size": 25}'::jsonb)$q$) as "newest, with shares";
select c->>'id' as "20,000 lots: the best share", c->'owned' as owned from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "sort": "owned", "size": 3}'::jsonb) c;
select count(*) as "what 20,000 lots build now, of 5,000" from public.directory_models('{"tests": true, "pool": "00000000-0000-4000-8000-0000000000d2", "buildable": true, "size": 49}'::jsonb) c;
select pg_temp.timed($q$select count(*) from public.directory_models('{"tests": true, "sort": "top", "size": 25}'::jsonb)$q$) as "and Top builds with no pool, the needs there";
select public.owned_forget_pool('00000000-0000-4000-8000-0000000000d2') as "Bob's collection deleted: the pool forgotten";
select public.owned_pool_of('00000000-0000-4000-8000-0000000000d2') is null as "none kept"
