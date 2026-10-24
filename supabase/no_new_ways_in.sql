-- No password, and no new address, on a person's account, 2026-10-24:
-- orangecheck's follow-up to its review of signing in with orangecheck (H1).
--
-- Brickworks signs people in with a code emailed to them (api/otp.js) or
-- with orangecheck (api/orangecheck.js), never with a password. Supabase,
-- though, lets any session set a password on its own account
-- (PUT /auth/v1/user) and sign in with it, and ask for the account's
-- address to be changed: a way in that nothing here started, which neither
-- unlinking orangecheck nor Sign out everywhere could end. Setting a
-- password also signs out every other session of the account, so a stolen
-- session could sign the person out. That call goes to Supabase, not to
-- Brickworks, so it is refused here, where Supabase writes it.
--
-- What Supabase writes on the paths people use, measured 2026-10-24: an
-- account is made with a random password hash nobody knows (admin
-- generate_link, which api/otp.js asks, and the admin API, which
-- api/orangecheck.js asks), and neither signing in by a code nor asking for
-- a second code before the first is used changes it. So accounts are made
-- as before; only a change is refused:
--
--   - a password hash changed on an account whose address is not one of
--     Resend's test addresses (@resend.dev), which no person receives mail
--     at, and which the tests sign in by password (tools/web/session.mjs);
--   - an account's address changed, or a change asked for, on any account.
--     Brickworks has no way to change an address (the address is the
--     account, and profiles keep the one it was made with). The owner who
--     must, in Supabase's dashboard, drops the trigger for the moment.
--
-- Supabase answers the refused call with an error (500, "Database error
-- updating user"); nothing is changed and no session is ended. api/_auth.js
-- refuses a password session all the same, for any hash set before this.
--
-- And two more, at orangecheck's second re-check (N2, 2026-10-24):
--
--   - a sign-in by password, on any account but a test account's. Public
--     sign-up is open, and Supabase confirms an address by itself, so
--     POST /auth/v1/signup with a password made an account and handed out
--     a session at once. The account's own row cannot tell that password
--     from the random one every account is made with, so the refusal is
--     where a password signs in: the row Supabase writes of how a session
--     began (auth.mfa_amr_claims, 'password'). Supabase commits the
--     account before that, so the account a public sign-up made was
--     refused too, as its making committed, by a trigger here until
--     Supabase took no sign-ups (disable_signup, 2026-10-24): it goes with
--     supabase/drop_no_public_sign_up.sql, and the daily canary
--     (api/_canary.js) holds that sign-up is off.
--   - enrolling a second factor (auth.mfa_factors: an authenticator app, a
--     phone, a key), on any account. Brickworks asks for none, and a
--     stolen session could enrol one of its own.
--
-- Only additions: functions and triggers. Applying it again changes
-- nothing.

create or replace function public.auth_users_no_new_ways_in()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.encrypted_password is distinct from old.encrypted_password
       and coalesce(old.email, '') !~* '@resend[.]dev$' then
        raise exception 'Brickworks signs nobody in with a password' using errcode = '42501';
    end if;
    if new.email is distinct from old.email
       or (coalesce(new.email_change, '') <> '' and new.email_change is distinct from old.email_change) then
        raise exception 'Brickworks does not change the address an account signs in with' using errcode = '42501';
    end if;
    return new;
end;
$$;

drop trigger if exists no_new_ways_in on auth.users;
create trigger no_new_ways_in
    before update of encrypted_password, email, email_change on auth.users
    for each row execute function public.auth_users_no_new_ways_in();

create or replace function public.auth_sessions_no_password()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.authentication_method = 'password' and not exists (
        select 1 from auth.sessions s join auth.users u on u.id = s.user_id
         where s.id = new.session_id and u.email ~* '@resend[.]dev$') then
        raise exception 'Brickworks signs nobody in with a password' using errcode = '42501';
    end if;
    return new;
end;
$$;

drop trigger if exists no_password_sign_in on auth.mfa_amr_claims;
create trigger no_password_sign_in
    before insert or update of authentication_method on auth.mfa_amr_claims
    for each row execute function public.auth_sessions_no_password();

create or replace function public.auth_no_second_factor()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    raise exception 'Brickworks enrols no second factor' using errcode = '42501';
end;
$$;

drop trigger if exists no_second_factor on auth.mfa_factors;
create trigger no_second_factor
    before insert on auth.mfa_factors
    for each row execute function public.auth_no_second_factor();

-- Run by Supabase's own role when it writes: granted it by name, so they
-- run whatever is taken from PUBLIC (supabase/no_client_access.sql).
grant execute on function public.auth_users_no_new_ways_in(), public.auth_sessions_no_password(),
    public.auth_no_second_factor() to supabase_auth_admin;
