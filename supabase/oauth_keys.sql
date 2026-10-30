-- Clients that sign their token requests, 2026-10-29 (docs/PROVIDERS.md, P1).
--
-- ChatGPT names itself as Claude does, by the address of its Client ID
-- Metadata Document (https://chatgpt.com/oauth/client.json). Unlike
-- Claude's, that document says ChatGPT proves itself at the token endpoint
-- with a JWT it signs (private_key_jwt, RFC 7523), by a key published at
-- its jwks_uri. api/oauth.js keeps, beside what it kept of a client:
--
--   auth_method   private_key_jwt, one more kind, for such a client
--   jwks_uri      where a document's client publishes its public keys
--   jwks          the public keys a client gave when it registered here
--                 (RFC 7591), for one that has no address for them
--
-- Public keys only: nothing here signs anything. Additive: two nullable
-- columns, and auth_method allowed one value more, so every row there now
-- is as good after as before, and the code before this file never writes
-- either column. Claude's rows never have either.
--
-- Applied with tools/apply_sql.mjs (--dry first). No function, so no line
-- in later.tsv.

alter table public.oauth_clients add column if not exists jwks_uri text
    constraint oauth_clients_jwks_uri_check check (length(jwks_uri) <= 500 and jwks_uri ~ '^https://[^#[:space:]]+$');
alter table public.oauth_clients add column if not exists jwks jsonb
    constraint oauth_clients_jwks_check check (jsonb_typeof(jwks -> 'keys') = 'array' and length(jwks::text) <= 10000);

alter table public.oauth_clients drop constraint if exists oauth_clients_auth_method_check;
alter table public.oauth_clients add constraint oauth_clients_auth_method_check
    check (auth_method in ('none', 'client_secret_post', 'client_secret_basic', 'private_key_jwt'));

-- A client that signs has keys to be checked by.
alter table public.oauth_clients drop constraint if exists oauth_clients_signs_with_keys;
alter table public.oauth_clients add constraint oauth_clients_signs_with_keys
    check (auth_method <> 'private_key_jwt' or jwks_uri is not null or jwks is not null);
