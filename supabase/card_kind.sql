-- What a model's card is, 2026-11-23 (unit cardlook; docs/PLAN.md row 4,
-- api/share.js op=card, tools/web/card_sweep.mjs, src/render/card_photo.gd).
--
-- A publish sends the model's card as the cut-out, and the app then draws
-- it as a photograph of the model on a desk and puts that on the link
-- (op=card): path traced where the graphics card traces rays, frames
-- averaged in a browser, not at all on a phone. So the gallery holds three
-- kinds of card, and the sweep the lead runs on the box's graphics card
-- draws, traced, every listed model's that is not already traced.
--
--   card_kind  how the card on the link was drawn: 'traced' or 'raster'
--              (op=card says which); null while it is the cut-out the
--              publish sent, or was put before this file
--   card_at    when op=card or the sweep last put it. A publish after it
--              (updated_at later) sent a cut-out again, so the card is the
--              cut-out whatever card_kind says: the sweep reads
--              card_at < updated_at as null, and a publish never has to
--              clear either
--
-- Only added; nothing granted: the service key alone reads and writes
-- them (api/share.js, the sweep). Before this file is applied op=card puts
-- the card all the same and says nothing of its kind.

alter table public.shared_models add column if not exists card_kind text;
alter table public.shared_models add column if not exists card_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'shared_models_card_kind') then
    alter table public.shared_models add constraint shared_models_card_kind
      check (card_kind is null or card_kind in ('traced', 'raster'));
  end if;
end $$;
