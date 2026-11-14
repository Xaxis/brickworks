// What supabase/console3.sql reads, in a test's Postgres (db3_check.mjs,
// api3_check.mjs): console2's files and the connector's, then stand-ins for
// Supabase's own sessions and storage and for the site's tables it finds in,
// each with the columns it reads.
import { NEEDS } from "./needs2.mjs";

export const NEEDS3 = [...NEEDS, "supabase/oauth.sql", "supabase/canary.sql", "supabase/console2.sql"];

export const STAND_INS = `
  create table if not exists auth.sessions (id uuid primary key, user_id uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now());
  create table if not exists auth.refresh_tokens (id bigserial primary key, token text,
    session_id uuid references auth.sessions (id) on delete cascade);
  create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text,
    metadata jsonb, created_at timestamptz not null default now());
  create table if not exists public.people (account uuid primary key references auth.users (id) on delete cascade,
    handle text not null unique, name text, bio text, created_at timestamptz not null default now());
  create table if not exists public.model_collections (id text primary key, owner uuid not null references auth.users (id)
    on delete cascade, name text not null, description text, public boolean not null default false,
    created_at timestamptz not null default now(), updated_at timestamptz not null default now());
  create table if not exists public.model_collection_items (collection text not null references public.model_collections (id)
    on delete cascade, model text not null, added_at timestamptz not null default now(), primary key (collection, model));
  create table if not exists public.reports (id bigserial primary key, model text, handle text, collection text, comment bigint,
    reason text not null, note text, contact text, reporter uuid references auth.users (id) on delete set null, visitor text,
    at timestamptz not null default now(), resolved_at timestamptz, resolution text);
`;
