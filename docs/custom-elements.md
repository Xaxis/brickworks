# Custom elements

How the LEGO Group makes a new element, as far as the public record goes,
and what Brickworks' element maker does about it. Researched 2026-10-10.
Each claim names its source and how strong the source is; anything not
found is said to be not found.

## How LEGO designs an element

**Who and how many.**
- LEGO's own 2010 Company Profile, p. 7: "The creative core is made up of
  120 designers" and "There are about 3,900 different elements in the LEGO
  range – plus 58 different LEGO colours." Primary
  ([archived PDF](https://web.archive.org/web/20121209100137/http://cache.lego.com/upload/contentTemplating/AboutUsFactsAndFiguresContent/otherfiles/download98E142631E71927FDD52304C1C0F1685.pdf)).
- Older LEGO job postings described the element-design department as making
  "more than 350 new LEGO® elements every year". Secondary: seen only in
  search snippets and a mirror; LEGO's pages are gone.
- A set designer does not draw the mould. Karsten Juel Bunch (LEGO element
  design) told New Elementary in 2020 that element design is a support group
  of about 50 people and product designers "apply for resources". Secondary,
  an interview ([New Elementary](https://newelementary.com/2020/06/lego-element-design-karsten-bunch-interview.html)).
- Daniel Konstanski's *The Secret Life of LEGO Bricks* (2022) describes
  "frames": a yearly budget of new moulds, recolours and prints per product
  line. Secondary, a book, as quoted by [Brick Architect](https://brickarchitect.com/cite/C1).

**Software.**
- 2008: a LEGO creative director told DEVELOP3D that designers modelled new
  elements in Rhino, prototyped them on an in-house SLA printer, and that
  engineers then "model the elements in Unigraphics" (now Siemens NX) for
  mould-flow and stress analysis; moulds have "up to sixteen cavities".
  Secondary, trade press ([DEVELOP3D](https://www.develop3d.com/profiles/childs-play-LEGO-Design-Factory-Tour-Toys-bricks)).
- 2026-09-29: a LEGO Sr. Mould Designer posting asks for "High Proficiency
  3D CAD Skills (NX and Teamcentre)" and mentions "some of the tightest
  tolerances in the entire injection moulding industry". Primary
  ([lego.com careers](https://www.lego.com/en-us/careers/job/sr-mould-designer-3ea00402a435100e00e150aeb1fe0000)).
  An element-designer posting copied elsewhere lists "Rhino, NX, ZBrush or
  similar". Secondary.
- LEGO is reported to keep using a version of LEGO Digital Designer
  internally after retiring it publicly (Brothers Brick, 2022). Secondary,
  no LEGO quote.
- **Not found:** any LEGO use of PTC Creo or Autodesk for elements; the
  name of the tool set designers build models in; an "element committee".

**Dimensions and tolerance.**
- LEGO's patent WO2019106129 (filed 2018-11-30): a 2 x 4 brick "is about
  3.2 cm in length, about 1.6 cm in width and about 0.96 cm in height
  (excluding knobs), and the diameter of each knob is about 0.48 cm", and
  these "may vary at most 1%" to stay compatible; such elements are
  "traditionally" ABS. Primary ([Google Patents](https://patents.google.com/patent/WO2019106129A1/en)).
- The 2010 Company Profile says moulds are "accurate to within 10 my
  (= 0.01 mm)". LEGO's history page says ABS (from 1963) allowed moulding
  "to an accuracy of 1/200 mm". Primary. The often-repeated 0.002 mm figure
  was **not found** in any LEGO source.
- US 3,005,282 (filed 1958-07-28, Danish priority 1958-01-28, granted
  1961-10-24, Interlego A.G.): the stud-and-tube coupling. Claim 1 is a
  hollow block whose studs clamp against a tubular projection and the side
  walls; claim 2 makes the tube's inside diameter equal to the stud's. It
  gives **no dimensions and no material**. Primary
  ([Google Patents](https://patents.google.com/patent/US3005282A/en)).
- Secondary only (fan measurement): stud height 1.7 or 1.8 mm, a brick
  0.1 mm shy of its pitch on each side (7.8 mm for 1 x 1), wall 1.6 mm (one
  source says 1.2). **Not found** from LEGO: draft angles, wall thickness,
  clutch force. The tube's ~6.51 mm outside diameter is arithmetic
  (8√2 − 4.8), not a published figure.

**Numbers.** LEGO's help pages: every piece has an element number, and "many
pieces have a four or five digit design number molded on the inside"; design
number plus colour identifies a piece. Primary
([lego.com](https://www.lego.com/en-gb/service/help-topics/article/identifying-lego-set-and-piece-numbers)).
LDraw numbers parts by design ID only — design 3004, not the tan element
4109995 ([LDraw part number spec](https://www.ldraw.org/part-number-spec.html)).
That older element numbers are design + colour (300121 is a red 3001) and
newer ones sequential 7-digit numbers is Brickset's account (secondary); this
project measured the first independently: 98.4% of the six-digit elements in
its table begin with their design number (`.claude/skills/verify/features/parts.md`).

## What LDraw asks of a part nobody has numbered

From ldraw.org, primary:
- The header ([spec, rev. 2025-02-21](https://www.ldraw.org/article/398.html)):
  description, `Name:`, `Author:`, `!LDRAW_ORG Unofficial_Part`, then
  `!LICENSE Licensed under CC BY 4.0 : see CAreadme.txt`; `BFC CERTIFY CCW`
  is required of official parts; `!CATEGORY` only when the description's
  first word is not a category.
- A part with no known LEGO number gets a `u` number, and a third-party part
  a `t` number — both assigned by the Parts Library admin. So a part made
  here must not invent one ([file names](https://ldraw.org/article/512.html):
  25 characters, `a-z 0-9 _ -`).
- A model file can carry its own files ([MPD spec, rev. 2](https://www.ldraw.org/article/47.html)):
  each starts with `0 FILE <name>`, the first is the model, and "there are no
  clear scoping or namespace rules" — a file called `stud.dat` inside one
  would replace every stud. (The spec's own example carries an unofficial
  part; it does not discuss the practice further.)

## What Brickworks does

A designer opens **Make a part…** in the parts bin, picks a family —
brick/plate/tile (with studs on any of its sides), slope, curved slope,
inverted slope, round, bracket, Technic brick — and its size in studs and
plates, or types a part number such as 3001 or 30414 and resizes it. A
turning preview shows the part as it will be, with its size in millimetres,
its studs on top and on its sides, where studs go in underneath, its
Technic holes and, for a slope, the angle its face really makes. **Add to
parts** puts it in the bin under Custom.

- **The file** (`src/parts/element_maker.gd`) is an unofficial LDraw part
  with the header above, drawn as the library draws its own: `stud.dat` per
  stud, `stud4.dat` tubes and `stud3.dat` pins underneath, `box5.dat` shell
  and cavity, 4 LDU (1.6 mm) walls and top. Its 2 x 4 brick is 3001 triangle
  for triangle. LEGO's named slope angles are the library's proportions: the
  "33" is 20 down over 40 (26.6°), as 3298 is drawn. The later families take
  their numbers off the library's parts the same way, and the tests hold each
  standard size to its part: side studs 10 LDU under the top and every 20
  down (87087, 22885), so a plate on them lines up with the brick's top; a
  bracket's upright 4 LDU in front of its plate (99781, 99780, 44728); a
  curved slope's face an eighth of a circle in the part's proportions, as
  11477 draws it; a Technic hole 10 LDU under the top, a 12 LDU bore with a
  16 LDU mouth two deep in each face (3700, 3701, 6541). It is named `bw-`
  and its shape (`bw-b2x7x3`, `bw-b1x4x3-sf`, `bw-k1x2x1d`, `bw-c4x2x3r4`,
  `bw-h1x4`), never a `u` number, and the header carries the spec it was
  made from, so it can be read back and remade.
- **The geometry** comes from that file, built in the app by a GDScript port
  of the mesh build (`src/parts/part_forge.gd`) — because neither an exported
  desktop build nor a browser has Python. The port produces the same `.lbm`
  bytes as `tools/build_meshes.py` for every fixture and for 28 library parts,
  checked on every run of the suite — Technic bricks among them, since the
  port merges a hole's two faces and clears its bore as the pipeline does.
  So a made part has studs and anti-studs found the same way as every other
  part's, the same collision cover, and the same sockets: a plate clutches a
  made brick's side studs, a Technic pin goes through a made hole, and the
  assistant's checker counts both as holding.
- **A part that exists can be changed** — what a LEGO designer is asked
  for far more often than a new element. Any part, typed into "Start from a
  part": a part of the families is resized as its family; any other — or
  any part at all, with "Change it" — is changed from its own geometry
  (`src/parts/part_editor.gd`): made longer, wider or taller, its studs taken
  off or put on, a piece cut out, so whatever the change does not touch stays
  as LEGO made it, print included. A cut-out is closed as a mould would make
  it: a cap where plastic was cut, a 4 LDU wall where the cut opened into the
  hollow underside; a corner cut out of 3003 has the studs and size of 2357,
  LEGO's corner brick. Longer repeats a
  stud's slice of the part where its cut faces match: 3700 made six long has
  3894's studs, holes, pins and collision exactly, 3001 made eight long is
  3007, 98283 made four long has 15533's studs and tubes. A part with no
  such slice (a 1 x 1, a round brick across, a one-wide slope) is refused,
  and the dialog says so. It works from the part's built mesh, which every
  build of the app has — a browser fetches it if it must — rather than its
  LDraw source, which neither a browser nor an exported desktop has; so the
  file it writes is the mesh's triangles and creases with each connector
  stated in a `0 !BRICKWORKS CONNECTOR` meta line, which other LDraw programs
  ignore and both the app and the mesh pipeline read.
- **The file goes with the model.** Saving a model that uses one embeds the
  part as a `0 FILE bw-….dat` section; opening it anywhere — including a
  copy of the app that never made the part — rebuilds it from that section.
  The `bw-` prefix keeps it clear of the namespace problem the MPD spec
  warns about.
- **A carried part may draw on LDraw's own files.** Somebody else's file
  often carries parts drawn from the library's subparts and parts, which
  the desktop reads from `vendor/ldraw` and no build ships (34,122 files,
  495 MB). In a browser those a file names are fetched as it opens, from
  `ldraw/parts/` beside the geometry (`tools/storage_ldraw.py` put them
  there), and kept for the visit (`CustomParts.fetch_sources`). Of the
  repository's 1,576 real sets' files, 190 need some: one file, 3 KB, for
  42082-1; 26 files, 563 KB, at most (41075-1).
- **The pipeline** can build just made parts in seconds:
  `tools/build_custom.py` takes `.dat` files or a model file, writes meshes
  and catalogue entries, merges them into a catalogue with `--into`, and
  with `--check` reads a model file as any LDraw tool would and says whether
  every carried part is complete.

## What this is not

It does not design a mould. Draft angles, gates, ejector pins, cooling and
the 0.1 mm a real brick is shy of its pitch are not in LDraw, and not here.
Parts are drawn at LDraw's nominal size: exact pitch, and a 1.6 mm stud
where LEGO moulds about 1.7–1.8. An inverted slope's wedge is drawn solid
where a mould would core it, and so is a Technic brick round its holes (the
library's are hollow there); side studs are solid studs on the face where
the library's are hollow and let into it; a curved slope's face is eight
straight strips round its curve. There are no clips, bars, hinges or axle
holes, and a library part can be resized from its family only if its name
says it is one ("Brick 2 x 4", "Technic Brick 1 x 4 with Holes", not
"Brick 2 x 4 with Holes"). Prints are drawn in the figure builder (below).

## Prints of one's own

Researched 2026-10-11, as above: each claim names its source.

**What LDraw has.** The !TEXMAP extension (ldraw.org, revised 2020-08-01)
projects a PNG onto the faces between `0 !TEXMAP START <method> <points>
<png>` and `0 !TEXMAP END`; programs that do not read it draw the plain
faces. PLANAR takes three corners of the picture; the spec does not say
which is which, and the MPD spec's own example, LeoCAD's documentation and
LDCad's author agree the first is the top left, the second the top right
and the third the bottom left. CYLINDRICAL takes a bottom centre, a top
centre, a point where the picture's middle touches, and an angle; its V
direction is self-contradictory in the spec (ldraw.org forum thread 13633),
and LDView and LDCad both run it down from the top. Off the picture the
spec is silent: LDView clamps to a clear border. A model file carries the
picture as `0 !DATA <name>.png` with base64 in `0 !:` lines of at most 80
characters (MPD spec rev. 2). Primary for the syntax; the conventions are
LDView's source (TREModel.cpp), read here.

**What BrickLink Studio does.** PartDesigner, a separate application, makes
decorated figure parts from imported PNGs ("Add images (.png file type
only)", reference sizes 416 x 320 for a head, 608 x 512 for a torso), for 28
parts, and a decal tool applies an image to a part's surface; no drawing in
the app or layers are documented, and its curved-surface projection is
reported to miss faces. It exports custom parts in its own format
(`0 PE_TEX_INFO <base64>` and UVs appended to each triangle, or a projection
box), which other LDraw programs do not read; Brickworks reads it into
TEXMAP and writes ours back in it (`src/parts/studio_decor.gd`, 2026-10-14).
Primary (studiohelp.bricklink.com) and forum; the format as ldr_tools
reverse-engineered it from Studio's own code, checked against a file Studio
saved.

**What Mecabricks does.** Decorations are uploaded as PNGs painted in
another program on a UV layout Mecabricks provides, for parts it has
layouts for (heads, torsos, legs, arms; not hair or hats); there is no
in-app drawing, and new moulds are made by its staff. Secondary (its
author's forum posts).

**What Brickworks does.** The print is drawn in the app, on a canvas that
is the part's printable area exactly — a head's face unrolled from its
cylinder, a torso's trapezoid, the hips and both legs side by side, a
tile's top or a slope's face, found from the part's own geometry, so any
part can be printed — with a brush, lines, boxes, ovals, a fill, words, an
eraser, a picked colour, LEGO's colours, layers, a mirror for symmetric
faces and undo, while the part turns beside it wearing the print. It can
start from a clean sheet, from any of LEGO's prints of the same mould read
off the library's own geometry (3626cp01's grin onto 3626c's face), from a
print made before, or from a picture of one's own. It is saved as a real
LDraw part with standard TEXMAP and the picture in the model file as !DATA:
LDView, a program that has never seen Brickworks, draws the face, the badge
and the lettering where the app does (`shots/print_ldview_front.png`,
`_back.png`). Where Studio's decal tool places an imported PNG, this places
a PNG, JPEG, WebP or SVG on any face found from the part's own geometry —
fitted, covering, cropped, turned, see-through, its background cleared,
in full colour or mapped to at most so many of LEGO's inks — and draws on it
after. And stickers as LEGO makes them: a film of their own over a part's
face or two parts' faces, sized to the faces less LEGO's 0.1 mm a side, and
the model's sheet of them printed at true size with cut lines. See
`.claude/skills/verify/features/prints.md`.
