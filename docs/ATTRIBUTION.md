# Attribution and licensing of source data

This project renders geometry it did not author. The terms below are
obligations, not courtesies: they must appear in the application's about
screen and in any distributed build.

## LDraw Parts Library

All part geometry derives from the LDraw Parts Library.

- Every file in the library carries `0 !LICENSE Licensed under CC BY 4.0`
  or `CC BY 2.0 and CC BY 4.0`. Verified across all 24,735 files in
  `parts/` as of the 2025-05 release: 23,244 CC BY 4.0, 1,491 dual.
- CC BY permits commercial use and derivative works — which is what a
  converted mesh is — provided attribution is given.
- Required notice:

  > This application uses the LDraw™ Parts Library, © the LDraw community,
  > licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
  > LDraw™ is a trademark owned and licensed by the Estate of James
  > Jessiman. This application is not affiliated with or endorsed by
  > LDraw.org.

- Source: https://library.ldraw.org/
- Nine of the library's primitives are copied unchanged into
  `assets/ldraw/` and ship in every build — `stud`, `stud3`, `stud4`,
  `box4`, `box5`, `4-4cyli`, `4-4disc`, `4-4edge` and `4-4ring3`, authored by
  James Jessiman (each file names him), CC BY 4.0 — because the element
  maker (`src/parts/element_maker.gd`) draws every part it makes from them
  and the app has to build those parts where the library is not to hand.
  A part the maker writes is an unofficial part, not a library one: its
  header names the maker as its author, and LDraw's own `u` and `t`
  numbers are assigned by the Parts Library admin, so it uses none.

## LDraw Official Model Repository

Some of the worked constructions the assistant can look up
(`src/ai/techniques.gd`) are sub-models of real sets as modelled in
LDraw's Official Model Repository (https://library.ldraw.org/omr), read
into this app's coordinates, or groups of parts cut from inside them.
Those files carry `0 !LICENSE Redistributable under CCAL version 2.0`,
which is CC BY 2.0, or `Licenced under CC BY 4.0` (10359 Fountain
Garden); files marked "free for non-commercial use" were left out. Each
technique names its set and modeller in its own text, and here:

- `lamp post`: 4886 Building Bonanza, modelled by Robert Paciorek, CC BY 2.0.
- `tree`: 4956 House, modelled by Marc Giraudet, CC BY 2.0.
- `bed`: 10297 Boutique Hotel, modelled by Philippe Hurbain, CC BY 2.0.
- `bench`: 2150 Train Station, modelled by Robert Paciorek, CC BY 2.0.
- `armchair`: 10246 Detective’s Office, modelled by Willy Tschager, CC BY 2.0.
- `table`: 31025 Mountain Hut, modelled by Stefan Frenz, CC BY 2.0.
- `planter`: 4956 House, modelled by Marc Giraudet, CC BY 2.0.
- `chimney`: 10182 Cafe Corner, modelled by Max Martin Richter, CC BY 2.0.
- `fence`: 3189 Heartlake Stables, modelled by Takeshi Takahashi, CC BY 2.0.
- `rough stone wall`, `cobbled path`, `log pile`: 21325 Medieval Blacksmith, modelled by Vincent Messenet, CC BY 2.0.
- `weathered stone wall`: 9471 Uruk-hai Army, modelled by Philippe Hurbain, CC BY 2.0.
- `corbelled wall walk`, `postern arch`: 6080 King's Castle, modelled by Stefan Frenz, CC BY 2.0.
- `oversail on inverted slopes`: 10176 Royal King's Castle, modelled by Marc Giraudet, CC BY 2.0.
- `stone corbel`: 7327 Scorpion Pyramid, modelled by Christian Neumann, CC BY 2.0.
- `balustrade`, `clipped hedge`: 10359 Fountain Garden, modelled by Orion Pobursky, CC BY 4.0.
- `embossed brick wall`: 75980 Attack on The Burrow, modelled by Stefan Frenz, CC BY 2.0.
- `columns with capitals`, `striped awning`, `staircase`: 10278 Police Station, modelled by Philippe Hurbain, CC BY 2.0.
- `stone column`: 4954 Model Town House, modelled by Marc Giraudet, CC BY 2.0.
- `turned wooden pillar`: 10182 Cafe Corner, modelled by Max Martin Richter, CC BY 2.0.
- `turret spire`: 75969 Hogwarts Astronomy Tower, modelled by Stefan Frenz, CC BY 2.0.
- `roof ridge`: 75954 Hogwarts Great Hall, modelled by Stefan Frenz, CC BY 2.0.
- `arched window`, `bookcase`: 10270 Bookshop, modelled by Ulrich Röder, CC BY 2.0.
- `window with shutters`, `dresser`: 10243 Parisian Restaurant, modelled by Willy Tschager, CC BY 2.0.
- `rock outcrop`, `anvil`: 9476 The Orc Forge, modelled by Philippe Hurbain, CC BY 2.0.
- `rocky ground with plants`: 6066 Camouflaged Outpost, modelled by Takeshi Takahashi, CC BY 2.0.
- `stone with ivy`: 6071 Forestmen's Crossing, modelled by Takeshi Takahashi, CC BY 2.0.
- `hedge with flowers`, `sofa`: 10297 Boutique Hotel, modelled by Philippe Hurbain, CC BY 2.0.
- `leafy plant`, `fireplace`, `wall lantern`, `campfire`: 5766 Log Cabin, modelled by Marc Giraudet, CC BY 2.0.
- `flower bed`: 5891 Apple Tree House, modelled by Marc Giraudet, CC BY 2.0.
- `hearth`: 30210 Frodo with Cooking Corner, modelled by Stan Isachenko, CC BY 2.0.
- `chest`: 10267 Gingerbread House, modelled by Orion Pobursky, CC BY 2.0.
- `potion shelf`: 75953 Hogwarts Whomping Willow, modelled by Stefan Frenz, CC BY 2.0.
- `four-poster bed`: 21318 Tree House, modelled by Orion Pobursky, CC BY 2.0.
- `hanging lamp`: 10246 Detective’s Office, modelled by Willy Tschager, CC BY 2.0.
- `bedside lamp`: 75948 Hogwarts Clock Tower, modelled by Stefan Frenz, CC BY 2.0.

## LEGO trademarks

Quoted from the LEGO Group's Fair Play guidelines
(https://www.lego.com/legal/notices-and-policies/fair-play/):

> If the LEGO trademark is used at all, it should always be used as an
> adjective, not as a noun.

> [the mark should appear] in the same typeface as the surrounding text
> and should not be isolated or set apart.

> The LEGO logo [should] NEVER be used on an unofficial web site.

and the mark "cannot be used in an Internet address". Note also:

> a disclaimer will not serve to undo an improper trademark use.

Required notice, which must appear in the about screen, the README and
the web footer:

> LEGO® is a trademark of the LEGO Group of companies which does not
> sponsor, authorize or endorse this site.

Binding consequences for naming and UI copy:

- **Never "LEGOs", never "a LEGO".** Adjective only: "models built of
  LEGO® bricks". Always carry the ®.
- **The mark may not appear in the domain, package name, application
  identifier or repository name.** The application is called Brickworks
  for this reason, the repository is `Xaxis/brickworks`, the domain is
  brickworks.diy, and the Python package is `brickworks-tools` — that
  last one carried the old name longest, in a file nobody reads.
- No LEGO logo, brand typography or product photography anywhere.
- No minifigure trade dress in branding — the app icon, store banner or
  marketing. Rendering minifigure *parts* inside the app from CC BY
  geometry is what every fan tool has done for thirty years and is a
  different question from putting one on the box.
- No stud-array pattern as a logo mark.
- Part names come from LDraw's descriptions, which are descriptive
  ("Brick 2 x 4"), not from LEGO's marketing names.

Precedent is otherwise reassuring: LDraw (1995), LeoCAD (1997),
Mecabricks and BrickStore have run for decades unchallenged, and the
LEGO Group bought BrickLink in 2019 and still ships Studio on the LDraw
library. Enforcement has gone at clone-brick manufacturers and retail
trade dress, not at CAD software.

## Catalogue metadata

**Rebrickable** — safe to redistribute, attribution required. Their
downloads page grants:

> You can use these files for any purpose, including commercial,
> provided you acknowledge Rebrickable as your source of data.

with the condition that automated downloading happens "at most once a
day". This is a custom informal grant rather than a named licence, so
the quotation above is the pinned snapshot, read 2026-10-05.

In use since 2026-10-05, and the reason: LDraw models geometry and has
no idea what LEGO ever moulded, so it will render a wedge plate in a
colour that never existed. `tools/fetch_data.sh` fetches six of their
tables into `vendor/rebrickable/`, and `tools/rebrickable.py` joins them
to the LDraw library to give each part the colours it was really made in
and the years it appeared in a set. Nothing of theirs is redistributed:
the index is derived at build time and the tables are gitignored. The
once-a-day condition is enforced in the fetch itself, where `--force`
will not re-download a table less than a day old.

Required credit: "Catalog data: Rebrickable" — in `web/index.html`'s
footer and on every instruction booklet (`src/assembly/booklet.gd`).

**BrickLink** — do not redistribute. The API is OAuth-gated and catalog
downloads are login-gated; the LEGO Group has owned BrickLink since
2019, so its terms are effectively LEGO's. Using BrickLink *identifiers*
is fine — LDraw embeds them in its own CC BY `!KEYWORDS` lines — but
mirroring the catalogue is not. Nothing is lost by declining: BrickLink
Studio's part library is the LDraw library.

**LDCad shadow library** — CC BY-SA 4.0, which is *not* the parts
library's CC BY 4.0. ShareAlike is viral: connectivity data derived from
it must itself be released under CC BY-SA 4.0. If it is ever used, it
ships as a separately licensed data file rather than compiled in. The
connectivity this project uses is derived from the parts library's own
primitives instead, and carries no such obligation.

**Rendered images are not derivative works** of the LDraw library, so
part thumbnails rendered here are unencumbered — which is the reason to
render our own rather than hotlink anyone's CDN.
