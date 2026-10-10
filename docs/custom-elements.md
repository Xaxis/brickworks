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
brick/plate/tile, slope, inverted slope, round — and its size in studs and
plates, or types a part number such as 3001 and resizes it. A turning
preview shows the part as it will be, with its size in millimetres, its
studs, where studs go in underneath and, for a slope, the angle its face
really makes. **Add to parts** puts it in the bin under Custom.

- **The file** (`src/parts/element_maker.gd`) is an unofficial LDraw part
  with the header above, drawn as the library draws its own: `stud.dat` per
  stud, `stud4.dat` tubes and `stud3.dat` pins underneath, `box5.dat` shell
  and cavity, 4 LDU (1.6 mm) walls and top. Its 2 x 4 brick is 3001 triangle
  for triangle. LEGO's named slope angles are the library's proportions: the
  "33" is 20 down over 40 (26.6°), as 3298 is drawn. It is named `bw-` and
  its shape (`bw-b2x7x3`), never a `u` number, and the header carries the
  spec it was made from, so it can be read back and remade.
- **The geometry** comes from that file, built in the app by a GDScript port
  of the mesh build (`src/parts/part_forge.gd`) — because neither an exported
  desktop build nor a browser has Python. The port produces the same `.lbm`
  bytes as `tools/build_meshes.py` for every fixture and for 16 library parts,
  checked on every run of the suite. So a made part has studs and anti-studs
  found the same way as every other part's, the same collision cover, and
  the same sockets.
- **The file goes with the model.** Saving a model that uses one embeds the
  part as a `0 FILE bw-….dat` section; opening it anywhere — including a
  copy of the app that never made the part — rebuilds it from that section.
  The `bw-` prefix keeps it clear of the namespace problem the MPD spec
  warns about.
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
where a mould would core it. Families are the plain ones: no clips, bars,
hinges, Technic holes or prints, and a library part can be resized only if
its name says it is plain ("Brick 2 x 4", not "Brick 2 x 4 with Holes").
