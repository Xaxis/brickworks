# Brickworks

A dimensionally exact brick construction system. Every part that has been
modelled, at true size, assembled under real connection rules, with a
design assistant that produces buildable models rather than plausible
pictures of them.

**[brickworks.diy](https://brickworks.diy)**

---

## What it is

28,319 placeable parts converted from the LDraw Parts Library, at exact
dimensions
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
specific reason when something will not hold. Once the model holds, it
goes back over each part of it on its own — the gatehouse, each tower,
each run of wall — close up, measured against what real sets of that
size and kind are made of. "A medieval castle with a gatehouse, four
corner towers and a long curtain wall between them" came back as 1,895
parts that stand up (`models/castle.ldr`).

## Where the numbers land

| | |
|---|---|
| Parts | 28,319 placeable, from a catalogue of 29,479 |
| Colours | 322, in 11 shader buckets |
| Connectors | 196,541 studs · 44,656 tubes · 8,679 pin holes · 1,319 axle holes |
| Renderer | 200,000 bricks · 14 draw calls · 131 fps (M3 Max, Forward+) |
| Web build | 10.4 MB over the wire, 881 resident, the rest fetched |
| Largest design | 1,895 parts from one sentence, in 41 minutes |
| Desktop build | 1.1 GB, the whole library on disk |

The difference between 28,319 and 29,479 is 1,160 redirect stubs —
"~Moved to 3665" — which forward to whatever replaced them and are not
things anyone can place.

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

Controls: click to place, right-click to remove, drag a box to select,
shift-click to add to the selection, `R` rotate, `[` `]` colour, `C`
paint what is under the cursor, `G` pick it up, `X` lift it off to move
it, `Q` `E` turn the model, `B` build steps, `P` parts list, `Tab`
panels, `/` search, `F` frame, `Cmd-Z` undo, `,` for the rest.

Right-drag turns the view, middle-drag turns it too, the wheel zooms,
and a trackpad turns with two fingers and slides with shift. Which way
the wheel goes, and whether the middle button turns or slides, are the
two bindings the CAD tools disagree about, so both are settings.

Every one of those is pressed for real in `src/dev/controls_probe.gd`
and `src/dev/feel_probe.gd`, because a hint that lies is worse than
none — and the second of those asks a different question: not whether
each control works, but what happens when somebody reaches for what
they are used to. It found left-drag placing a brick.

## What you can do with a model

A finished model is the least useful form a design takes, so it does not
have to stay one.

- **A parts list** — every part in every colour, counted by the lot,
  which is the unit a shop sells. Out as CSV.
- **Build instructions** — the step order is recovered from the geometry
  rather than the order things were placed: every brick rests on
  something already there, and a step stays in one part of the model.
  A big model is built a part at a time, as a set is — the gatehouse,
  then a tower — with each part pictured on its own. Out as a single
  printable page with a picture per step.
- **A mosaic** — a photograph matched to the forty-four colours a
  1×1 plate is really moulded in, perceptually rather than
  arithmetically, and dithered because against a palette that small flat
  matching gives bands.
- **LDraw `.ldr`** — what you build here opens in LDView, LeoCAD, Studio
  or Mecabricks, and what you made there opens here. A design in
  assemblies goes out as an `.mpd`, a sub-model per assembly.

## Accounts

Building is free and needs no account: every part, search, save, load,
stability, instructions, parts list and mosaic. The design assistant
needs one, because it spends money per request and an endpoint holding
an API key that anyone may call is a bill waiting to happen.

That split is enforced by construction — nothing in `Builder`,
`BrickWorld` or `PartsBin` imports `Account`. Sign-in is a one-time code
sent to your email: no password to choose badly, reuse, forget or reset.
The code is minted by Supabase and delivered from our own sender, and the
session token is Supabase's throughout — verified at the edge by
signature against the published key rather than by asking Supabase on
every request. A design is charged per conversation rather than per round
trip.

## Or design on the Claude you already pay for

If you have Claude Code installed and signed in, tick **My Claude** in
the design panel. Brickworks starts a session on this machine and points
it back at itself, so the thinking is done on your own Claude
subscription: no API key, no account here, nothing billed by us.

That session can reach this app's bricks and nothing else on your
computer — no shell, no files, none of your other MCP servers. It is
started with `--tools "" --restricted --strict-mcp-config`, so the only
tools in front of it are the nine Brickworks serves.

It is a desktop feature, because a browser cannot start a program.

## Or bring your own session

The design loop lives in the app, not on a server. The real catalogue
answers searches, the real collision lattice decides whether a brick
fits, and what holds together goes on the baseplate. None of that needs
an API key — only the model proposing the placements does.

So if you already have a Claude Code session open, it can be that model:

```sh
claude mcp add brickworks -- /path/to/brickworks/tools/brickworks_mcp.py
godot --path . -- --mcp
```

Driving it from a session you already have open, rather than letting the
app start one, is the same thing by hand. Your session gets the same nine
tools the app's own assistant uses —
search the catalogue, check a design against the lattice, look at what is
built, submit it — and the bricks land in the window while you watch. No
key is pasted into the app, no account is needed, and nothing is billed
here, because the only thing spending tokens is the session you already
had.

The port is 127.0.0.1 only and closed unless `--mcp` asks for it.

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
