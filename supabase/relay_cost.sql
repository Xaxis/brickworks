-- The relay's cost to each call, 2026-10-29 (relay338).
--
-- A call through the connector (api/mcp.js) took 2.3 to 3 seconds when the
-- tab's own work took a tenth of one, in 173 recorded design sessions: a
-- dozen round trips to the database one after another, a quarter of a
-- megabyte read on every call, and two waits of up to 350 ms. Two columns
-- of relay_tabs (relay.sql) take the largest of those away:
--
--   list         which tools the tab's hello serves: a short hash of them
--                (listOf), written beside the hello by op=hello, so a call
--                learns whether the conversation's tools have changed
--                without reading the hello itself, the app's whole tool
--                list. Null whenever the hello is written without it (the
--                trigger below), as a relay from before this writes it,
--                and the relay then reads the hello as it did.
--   answered_at  when the tab last answered a call: while that was within
--                the last minute a chat is working with it, and its asks
--                for work look in the queue every 100 ms rather than 350.
--
-- Additive: two nullable columns and a trigger of their own. Nothing reads
-- them but api/mcp.js; a relay from before neither reads nor writes them.
alter table public.relay_tabs add column if not exists list        text;
alter table public.relay_tabs add column if not exists answered_at timestamptz;

-- A hello written without its list leaves no list, rather than another
-- hello's. Only an update that writes hello runs it (op=hello's), so the
-- tab's word every ten seconds that it is alive never compares two
-- quarter-megabyte hellos.
create or replace function public.relay_tabs_list_kept()
returns trigger
language plpgsql
as $$
begin
  if new.hello is distinct from old.hello and new.list is not distinct from old.list then
    new.list := null;
  end if;
  return new;
end;
$$;

create or replace trigger relay_tabs_list_kept
  before update of hello on public.relay_tabs
  for each row execute function public.relay_tabs_list_kept();

revoke all on function public.relay_tabs_list_kept() from public, anon, authenticated;
