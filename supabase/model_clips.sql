-- A model's clip (turntable, docs/SOCIAL.md section "The units, in waves",
-- rank 2): the model turning once round, at most 4 seconds and 1.5 MB, a
-- seamless loop, recorded in its designer's own browser from its page's 3D
-- view (web/turntable-clip.js, web/model-page.js) and served at /m/<id>.mp4
-- (/m/<id>.webm where that browser cannot record MP4). Its page names it in
-- og:video and a twitter:card player, so a link pasted into Discord, Slack
-- or X turns there (api/share.js).
--
-- Additive only: a new table and a new bucket, nothing else changed.
--
-- One row per model: what the clip is, and which version of the model it
-- shows. A republish makes a new version, and the page names a clip only
-- while it is of the newest; the designer's next visit records it again.
-- The row goes with its model (on delete cascade), and so with its account.
-- Its file is not a row: api/share.js deletes it on unpublish, api/_erase.js
-- with the account, and the daily sweep any no published model owns.
create table if not exists public.model_clips (
    model    text primary key references public.shared_models (id) on delete cascade,
    version  integer not null check (version between 1 and 999999),
    kind     text not null check (kind in ('mp4', 'webm')),
    width    integer not null check (width between 16 and 1920),
    height   integer not null check (height between 16 and 1920),
    ms       integer not null check (ms between 1 and 4001),
    bytes    integer not null check (bytes between 1 and 1572864),
    made_at  timestamptz not null default now()
);

-- Read and written by the server alone, with the secret key, after it has
-- found the model published (a visitor) or the caller its owner (an
-- upload): no policy, and nothing for the key a page holds.
alter table public.model_clips enable row level security;
revoke all on public.model_clips from anon, authenticated;

-- The files, <id>.mp4 or <id>.webm, in a private bucket of their own: the
-- others take only their own kinds of file and are left as they are.
-- 1.5 MB, the clip's own ceiling (api/_clip.js MAX_CLIP_BYTES). No policy
-- on storage.objects names it.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shared-clips', 'shared-clips', false, 1572864, array['video/mp4', 'video/webm'])
on conflict (id) do nothing;
