-- signin7: read only (inside the dry run's rolled-back transaction). Are the triggers that refuse a new
-- password, a new address and a second factor on every session there in production, and enabled?
select c.relname as on_table, t.tgname as trigger_name, t.tgenabled as enabled, p.proname as runs
  from pg_trigger t join pg_class c on c.oid = t.tgrelid join pg_proc p on p.oid = t.tgfoid
 where not t.tgisinternal and t.tgname in ('no_new_ways_in', 'no_password_sign_in', 'no_second_factor') order by 2;
-- Which ways in Supabase itself holds for accounts (identities by provider): Brickworks makes only email.
select provider, count(*) as identities from auth.identities group by provider order by 1;
