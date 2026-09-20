# Brickworks

A dimensionally exact brick construction system. Every part that has been
modelled, at true size, assembled under real connection rules, with a
design assistant that produces buildable models rather than plausible
pictures of them.

**[brickworks.diy](https://brickworks.diy)**

---

## What it is

24,731 parts converted from the LDraw Parts Library, at exact dimensions
— 1 LDU is 0.4 mm, a stud pitch is 8 mm, a brick is 9.6 mm tall. Those
numbers were measured from the library rather than looked up, and the
tests assert them so a library update cannot move them quietly.

Bricks sit on a 2 LDU integer lattice, so a placement is exact, collision
is integer comparison with no tolerance, and a model saved today loads
identically tomorrow. Point at a face and the next part goes against it.

The design assistant takes a sentence and returns a model. It never
touches geometry: it proposes placements in studs and plates, and a
deterministic validator resolves every one against the real lattice —
overlap, support, connection — and hands back the specific brick and the
specific reason when something will not hold.

## Where the numbers land

| | |
|---|---|
| Parts | 24,731 — 18,645 moulds, 4,961 shortcuts |
| Colours | 322, in 11 shader buckets |
| Connectors | 196,541 studs · 44,656 tubes · 8,679 pin holes · 1,319 axle holes |
| Renderer | 200,000 bricks · 14 draw calls · 131 fps (M3 Max, Forward+) |
| Web build | 10.2 MB over the wire, 881 parts resident |
| Desktop build | 1.0 GB, the whole library |

## Running it

```sh
tools/fetch_data.sh          # the LDraw library into vendor/ (not committed)
tools/build_meshes.py        # convert it: ~45 min, writes assets/generated/
godot --path .               # build something

tools/design.py "a small lighthouse on a rocky base"
tools/export.sh web          # or mac
tools/deploy.sh --prod       # needs VERCEL_TOKEN
python3 -m pytest tests/ -q
```

Controls: click to place, right-click to remove, `R` rotate, `[` `]` part,
`;` `'` colour, alt-drag orbit, shift-drag pan, wheel zoom, `F` frame.

## How it is put together

`docs/ARCHITECTURE.md` is the real document — what is decided and *why*,
especially where the obvious choice turned out to be wrong. Three
examples of the kind of thing it records:

- Winding reverses from three independent causes that compose by XOR.
  Miss one and parts render inside-out, but only once culling is on.
- A tube is not a socket. It sits *between* four studs, and the smallest
  parts have no tube at all — so where a stud may go is derived by
  projecting the underside and filling the enclosed voids.
- The lattice is 2 LDU because it must divide 20, 10, 24 and 8. At 4 LDU
  a 1×1 brick straddles a cell at each end and measures 1.4 studs across.

## Attribution

Part geometry is derived from **the LDraw™ Parts Library**, © the LDraw
community, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). LDraw™ is a
trademark owned and licensed by the Estate of James Jessiman. This
project is not affiliated with or endorsed by LDraw.org.

LEGO® is a trademark of the LEGO Group of companies which does not
sponsor, authorize or endorse this site.

Full terms, including what may and may not be redistributed from each
source, are in `docs/ATTRIBUTION.md`.
