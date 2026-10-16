# Brickify: the field, where we stand, and the plan

Read on **2026-10-15**, against `main` at `7a55e86`. The owner forwarded a
comment:

> "If you want to make something with widespread demand that doesn't either
> encroach on or risks redundancy to what already exists, you should make
> something that takes a preexisting 3D model (generic formats) and
> serializes it into a build schematic, minimally with greedy-meshed standard
> bricks but ideally with SNOT and unique curve/'illegal' techniques (it's a
> big rabbit hole, but it'd be worth it)"

Brickworks has this already: **Brickify**
([brickify.gd](../src/assembly/brickify.gd),
[the panel](../src/ui/brickify_dialog.gd)). This file surveys every tool and
paper that does the same, measures ours against a greedy brick stack and
the best free outside tool on 14 models, and ranks the units that would make
it the best 3D-to-brick converter there is.

**How it was made.**
- Three research passes on 2026-10-15: tools and products, research papers,
  and where builders ask for this. Each kept a short quote for every claim.
  The claims the plan rests on were then read again by hand: Studio's
  Sculpture help, NiemanSculpt's pages, BrickSolvr, ObjToSchematic's README,
  legolization's README, Lambrecht's paper, Berard's slides, and three Reddit
  threads. All matched.
- *Unverified* marks a claim seen only in a search summary or on a page that
  refused us. Reddit was read through the Arctic Shift archive [arctic].
  Rebrickable was not fetched at all.
- The measurements are [brickify_bench.gd](../src/dev/brickify_bench.gd) and
  [brickify_bench.py](../tools/bench/brickify_bench.py); "Repeat it" at the end
  gives the commands. Downloaded models were only ever read as data.
- [RESEARCH.md](RESEARCH.md) (2026-10-14) covers AI design and the CAD tools at
  large; [COMPETITIVE.md](COMPETITIVE.md) is the feature matrix. Neither is
  repeated here.

## In one page

**The field.** About forty tools turn a mesh into bricks. Most give a
voxel stack of standard bricks: Studio's Sculpture, Bricker, BrickSolvr and a
dozen small repositories. Three go further. NiemanSculpt (free for
non-commercial use; Windows and macOS) lays slopes, wedges and SNOT in six
directions, with connectivity only in its paid version. legolization (GPL,
Python, August 2026) bonds bricks by the papers' methods, checks a full force
balance and writes a booklet, but lays three slopes. Research is further
behind on parts: every learned system lays rectangular bricks one brick
tall, and the one automatic SNOT method leaves loose plates. **No other
tool or paper lays slopes, curves, inverted slopes, wedges, tiles and
sideways studs together and then checks the build as a design. Brickify
does; what it lacks is reliability, colour and economy, not parts.**

**The demand.** Real but particular. People without the craft ask, one at a
time, for their model as a set "including instructions and colored bricks".
Builders reject a stack of bricks ("Isn't this just a voxelise algorithm?")
and ask for plates, slopes and SNOT, a parts list and a price, and to build
from what they own. The comment the owner forwarded is that builder's view.

**Where we stand, measured** on 14 freely licensed models at 24 and 48
studs, against a greedy stack of standard bricks and legolization:
- **It loses models.** It laid nothing for 3 of 14 at 24 studs (a fox, a
  figure, an aircraft: thin legs and gear never reach its grid, the body
  floats, and the mend takes every part out). It kept the whole model in 13
  of 28 runs; legolization kept every one it finished.
- **What it keeps holds together, mostly.** Every build it laid is one piece
  and passes the check; Balance says 4 of the 24 would tip, and the panel
  says "buildable" without weighing.
- **Its surface is the smoothest we measured:** 99% of its tops are slopes,
  curves and tiles, a third the studs of a plain build. But it is no closer
  to the model than a greedy stack (silhouette IoU 0.950 against 0.948 at 48
  studs), and only 3° better in shading.
- **Colour is its weakest point:** 1.5 to 2.5 times the palette's floor,
  worse than its own plain mode and than legolization; a cow's black patches
  come out brown.
- **It uses 2.6 times the greedy stack's parts,** 38% of them 1x1s, with
  fewer seams bridged (42% against 55%).
- **It is fast:** 4 s at 24 studs and 32 s at 48, where legolization took
  12 minutes on average at 24 and ran out of time on 5 of 14.

**The plan**, ranked (section 4):
1. **Keep the whole model**: join or support what it now drops; never place
   nothing. *Done 2026-10-15, section 5: whole in 25 of 28 from 13.*
2. **Colour that reads right**: a hue-keeping match, faces voted by what is
   seen, only colours the part is made in. *2026-10-16, section 6: 1.28 times
   the floor at 48 studs from 1.54, every part with an element number; a
   figure's hair top, smooth against plain at 48, wholeness (24 of 28) and
   time not there yet.*
3. **Bond like a builder**: fewer, longer parts and staggered seams in the
   hidden core.
4. **Fit the surface by distance**, with the slope angles it lacks.
5. **SNOT that holds**: Lambrecht's turned cubes, tied to the core.
6. **Show it**: the homepage, /compare with the bench, and a first run with
   CC0 samples and a staged panel.
7. **Buy it, or build it from what you own**: booklet, wanted list, price,
   collection.
8. **Model and sculpture modes**, to 128 studs, the second tier of
   techniques behind an option.
9. **Every file people have**: PLY, 3MF, VOX, FBX.

What makes it clearly the best is a public bench on which it is the only
tool that lays every model whole, in one piece, standing, closer to the
model than a voxel stack, in colours within 1.3 times the palette's floor,
with a price and a booklet attached (section 4, "The target").

## 1. The field

### Tools that turn a mesh into bricks

**Parts** means real LEGO® parts a person can buy (LDraw or Studio files);
**voxels** means brick-shaped blocks for a picture. Every row was read
2026-10-15; *unverified* marks a claim seen only in a search summary.

| Tool | Price, platform, last release | Makes | Slopes, curves | SNOT | Stability, bond | Colour | Instructions, parts, price | Out |
|---|---|---|---|---|---|---|---|---|
| **BrickLink Studio, Sculpture** [st-sculpture] | Free; Windows and macOS | Parts: bricks, "1x1 only" or the bricks you pick, walls and base a set thickness [st-sculpture] | None mentioned | No | Suggests its Connectivity Check when it fails [st-sculpture]; ResemBrick measured its output 75.0% stable [resem] | From the OBJ's `.mtl` or by layer; "can use bricks in colors that are not available" [st-sculpture] | One step a layer; Studio's own instruction maker and BrickLink cart | `.io`, LDraw. In: OBJ, STL only [st-sculpture] |
| **NiemanSculpt** [nieman] [nieman-guide] | Free for non-commercial use, Pro paid; Windows, macOS, v2.4.3 Sept 2026 [nieman-dl] | Parts, "elements in 160+ shapes"; OBJ and STL in [nieman] [nieman-guide] | Styles "Standard slopes", "All slopes", "Wedge plates" [nieman-guide] | "100% collision-free SNOT generation in all six directions", SNOT bricks inside to hold them [nieman] [nieman-guide] | Pro only: connectivity "99.5% to 100%" studs up, "98.5% to 99.7%" with SNOT; no force check [nieman-guide] | Textures and material colours; Pro: only colours LEGO® parts are made in, and price limits per part [nieman] [nieman-guide] | — | LDraw |
| **Bricker** (Blender) [bricker] | $65, GPL, no public repository; Blender 2.93–5.0, v3.2.1 Jan 2026 [bricker] | Bricks and plates, plus studs, cylinders, cones or custom objects as "bricks" [bricker] | One brick at a time, by hand ("Change Brick Type") [bricker-docs] | No | Merge "Random" or "Greedy" ("fewest amount of bricks possible") [bricker-docs] | From UV textures; LEGO® colours need a second paid add-on [bricker] | Brick count and weight; no instructions or list [bricker-docs] | LDraw since 1.3 [bricker-docs] |
| **Mecalizer** (Blender) [mecalizer] | $35 on Mecabricks' shop; Blender 3.4 and later [mecalizer] | Parts, as presets: "bricks, plates, slopes, and angles", or any part you add [mecalizer] | Presets | — | — | Texture or vertex colour to Mecabricks' palette [mecalizer] | — | Blender scene |
| **legolization** (Python) [lz] | Free, GPL-3.0, PyPI 0.5.0 Aug 2026; one maintainer, 9 stars [lz] | Parts: bricks, plates, tiles [lz] | Three slopes (45° 2x1, 2x2; 33° 3x1), placed only where cells match exactly [lz] | `--snot`: sideways 1x1 tiles on brackets, free-standing wall columns only [lz] | Seven layout strategies from the papers (Luo, Kollsker, Bao, Lee, Min); a rigid-block force check as a linear program; repair [lz] | Nearest vertex colour, to the LDraw palette [lz] | Steps, a bill of materials, an HTML or PDF booklet (with LeoCAD) [lz] | `.ldr`, `.mpd`. In: OBJ, STL, PLY, VOX |
| **BrickSolvr** (web) [bricksolvr] | Free, in the browser, no upload [bricksolvr] | Bricks, from STL, OBJ, GLB or PLY [bricksolvr] | No | No | "nothing is left floating, and weak spots are reinforced" [bricksolvr] | A colour cap, or only colours you own [bricksolvr] | A layer-by-layer guide; a CSV of sizes, colours and counts [bricksolvr] | CSV |
| **drububu Legolizer** [drububu] | A paid service; the software "not available for download" [drububu] | Bricks and plates | — | — | — | 16 colours | Layer instructions, a parts list with cost [drububu] | OBJ, STL, LXF, IO, LDR and more |
| **LSculpt** [lsculpt] [lambrecht] | Free, about 2008, Windows | 1x1 plates turned to face out: "oriented in any of the principle Cartesian directions" [lambrecht] | No | Yes: the whole surface | "may be poorly connected" (the builder adds the core) [lambrecht] | No | No | LDraw |
| **Brick My World** (iOS) [bmw] | Free with in-app purchases; 2.3 stars from 12 ratings [bmw] | Bricks or plates from a phone scan or OBJ, USDZ, glTF [bmw] | ? | ? | ? | Recolour by hand | PDF, brick list, BrickOwl wishlist [bmw] | LDraw |
| **HPI Brickify / faBrickation** [fabrickation] (our feature's name, taken first) | Research, no licence | LEGO® bricks for the bulk, 3D-printed parts for the detail [fabrickation] | Printed | — | — | — | Building instructions and an OpenSCAD file [hpi] | STL, SCAD |
| **Blender voxel add-ons** (a free brick generator, Legolizer, LegoIT) [lego-gen] | Free or paid | Voxels for a render | No | No | No | Texture | No | Mesh |
| **AI stylisers** (Tripo "Stylize", Neural4D) [tripo-node] | Paid | A mesh styled as bricks, voxels or Minecraft blocks [tripo-node] | No | No | No | Texture | No | GLB |
| **Small open repositories** [img2lego] [brickalize] [brickr-qt] [cv2ldr] | Mostly no licence, 0–48 stars | Bricks (img2lego claims slopes, wedges, curved slopes) | Rarely | No | Connectivity at most | Some | Some write a BrickLink wanted list | LDraw or images |
| **Brickworks Brickify** ([brickify.gd](../src/assembly/brickify.gd)) | Free, browser and desktop | Parts on the plate grid: bricks inside, plates at the surface | Straight, curved and inverted slopes, wedges, corner rounds, tiles | Studs-sideways bricks with tiles on flat flanks | Checked as a design is (overlaps, support, one piece; not weighed), then mended: what fails is taken out | Oklab match to 41 current solid colours | The booklet; a BrickLink wanted list and Rebrickable CSV of any model | LDraw, `.io`, glTF, OBJ, STL. In: OBJ, STL, glTF, GLB |

Not found anywhere: a mesh converter inside Mecabricks, LeoCAD, LDCad or
Bricksmith; the LEGO Group's own is a photo mosaic of 1x1 plates [mosaic40179].

### ObjToSchematic, the Minecraft tool whose flow is admired

ObjToSchematic (BSD-3-Clause, 527 stars) turns an OBJ into Minecraft blocks
[o2s]. Its 1.0 code "will no longer receive any updates or bug fixes"; 2.0 is a
web app that converts "on your machine" [o2s] [o2s2]. What is worth copying is
the flow: five steps in order, each with its own button, so a later step runs
again without the earlier ones [o2s]:

1. **Import**: the file and its rotation.
2. **Materials**: each material Solid or Textured, its filtering and wrap.
3. **Voxelise**: the axis the size is set along, the size, multisampling, how
   overlapping voxels share colour; ambient occlusion as a "purely visual"
   preview.
4. **Assign**: the block palette, dithering (off, ordered, random), colour
   accuracy, "smart averaging" (colour from visible faces only), lighting.
5. **Export**: four game formats and OBJ.

### Research

| Work | Input to output | Parts | Slopes | SNOT | Colour | Stability | Measured, and result | Code |
|---|---|---|---|---|---|---|---|---|
| Gower et al. 1998 [gower] | Voxels to bricks, one height | Bricks | No | No | No | Penalties: bricks not crossing the joints below | Penalty only | — |
| Testuz, Schwartzburg, Pauly 2013 [testuz] | Mesh to 1x1s, merged | Bricks | No | No | Nearest texture point, then LEGO® colour | A brick joining two parts of the graph is a "weak articulation point", split and merged again | One piece; weak points; 2–27 s; a 1,315-brick bust built | GPL ([brickr][brickr-qt]) |
| **Legolization**, Luo et al. 2015 [luo] [luo-slides] | Voxels to bricks | 11 bricks, 1x1 to 2x8 | No | No | Colour constraints | Force balance per brick; refine around the weakest brick by splitting and merging its neighbours | 1,642 bricks in 19 s, built in 8 h; 8,277 in 22 min [luo-slides]. Built, 76.5% stable by ResemBrick's solver [resem] | None public |
| Kollsker, Malaguti, Stidsen 2021 [kollsker] | Voxels to bricks | Bricks (plates in the thesis) | No | No | — | Integer programming with a static-equilibrium QP | Up to 77,000 brick positions; part-funded by the LEGO Group [kollsker] | Data only |
| Zhou, Chen, Xu 2019, "Vivid LEGO® Architectural Sculptures" [zhou] | Mesh to bricks | 11 bricks, 13 slopes, 5 round | **Yes**, four yaw turns | No: "Bricks aligned in multiple orientations… are not supported" [zhou] | — | Re-layout, then plate support layers | Qualitative; four built | — |
| Ljubič, Bohak 2025 [ljubic] | Car meshes to bricks | Bricks, plates, slopes, tiles | On top surfaces only | No | — | — | Time only, 8–31 s [ljubic] | — |
| **Lambrecht** 2006 [lambrecht] | Mesh to oriented 1x1 plates | 1x1 plates | No | **Yes**: cubes of 20 plates each turned to the surface | No | None | The full bunny (69,451 triangles) in under 0.5 s [lambrecht] | A free program ([LSculpt][lsculpt]) |
| Image2Lego 2021 [image2lego] | Image to voxels to bricks | Bricks | No | No | Nearest RGB, k-means | Not measured; hollow faces "collapsed" when built [image2lego] | IoU 0.700 at 16³ | — |
| StableLego 2024 [stablelego] | A layout to its stability | 1xN, 2xN bricks | No | No | No | Force balance (Gurobi) | 99.56% right on 225 built [stablelego] | MIT |
| BrickGPT 2025 [bgpt] | Text to bricks, 20³ | 8 bricks | No | No | Optional | StableLego, roll back | 98.8% stable [bgpt] | MIT |
| LegoACE 2025 [legoace] | Text or normals to LDraw | 28 parts incl. slopes, curves, 87087 | Yes | Yes, learned | — | None | CLIP | MIT |
| STABLE 2026 [stable] | Point cloud to bricks | 8 bricks | No | No | No | Rewards + StableLego | IoU 0.907 [stable] | MIT |
| **BrickAnything** 2026 [banything] | Mesh or points to bricks | 8 bricks | No | No | No | StableLego, roll back to the parent | Stable set: IoU 0.788, Chamfer 0.128, 100% stable; hard set 0.586, 0.130, 83.4% [banything] | MIT |
| **ResemBrick** 2026 [resem] | Photos to mesh to bricks | Rectangles | No | No | CIELAB palette | Gurobi + a learned surrogate | 198 objects at R=24: MS-SSIM 0.955, LPIPS 0.075, 100% stable; **Studio 0.733, 0.204, 75.0%** [resem] | None |
| LEGO®-Maker 2025 [legomaker] | Image to LDraw | "&gt;100 unique brick types" | ? | ? | Yes | Collision rollback | User study | None found |

**What the field has not done** (each a gap Brickworks can lead in):
- **SNOT that holds.** The one automatic studs-out method lays loose 1x1
  plates and leaves the core to the builder [lambrecht]. "There is no fully
  automated solution available for generating studs-out sculptures" [bbh].
  No stability solver models side studs: StableLego "only considers cubic
  blocks" [stablelego].
- **Every surface part at once.** Zhou fits slopes and rounds with yaw turns
  only [zhou]; Ljubič slopes the top only [ljubic]; no paper fits inverted
  slopes or wedges. Brickify already lays all of these.
- **Plate-height rows.** Every learned system works in one-brick-tall cells
  [bgpt] [stable] [banything] [resem].
- **Scale.** Learned methods stop at 20³ or R=24; the classical ones reach
  17,755 bricks [luo-slides].
- **A measure that sees a slope.** Voxel IoU cannot reward one; nobody scores
  the surface against the parts' real geometry.
- **Built for real.** Few builds, and no study of how long a brickified model
  takes to build or how often a builder errs.

### Where the demand shows

Reddit was read through the Arctic Shift archive [arctic] (reddit.com refuses
automated readers); the links go to reddit.com. Rebrickable was not fetched
(the owner allows it once a day). Counts are lower bounds.

- **People without the craft ask for it, one at a time.** Eight r/lego
  requests in 2024–25 to turn a 3D model, a scan or a house into a build,
  0–2 upvotes each: "including instructions and colored bricks" [r-house];
  "I just need the list of parts… so that I can calculate how much the total
  thing will cost me", for a 9,648-part brick-stack figure [r-parts].
- **Builders reject filler.** On the launch of HPI's Brickify web app
  (r/DigitalLego, Jan 2026), the top comment (+20) asks where the thinking is
  in a model built of bricks alone; the next (+5): "a neat idea with really
  no audience" [r-brickify]. On BrickFormer (r/lego, 85 upvotes): "does only
  'fill' with bricks or uses smart techniques" (+6) and "Isn't this just a
  voxelise algorithm?" [r-brickformer]. On Hacker News: "Using bricks other
  than 2x2 and 2x4 blocks creatively… is really important" [hn-legogpt-c].
- **They name what is missing.** Plates: "I can only use bricks, not plates,
  so all the vertical detail is lost" [r-plates]. Studio's Sculpture "won't
  use plates, tiles, curves, slopes, hinges, just basic bricks" [r-legofy].
  Size: "maybe I don't want to build a duck that is 100 bricks tall"
  [r-brickformer]. Seams: a September 2026 converter's author cut badly
  aligned seams "from 38% to 3%" [r-seams].
- **Research and "build from what you own" draw far more than converters.**
  BrickGPT's launch on Hacker News: 596 points [hn-legogpt]; Image2Lego 98
  [hn-image2lego]; Brickit, which reads your pile, 646 and 659 [hn-brickit1]
  [hn-brickit2]. Brick converters posted there drew 1–5 points [hn-conv].
  Under an AI generator's launch in October 2026: "It would be useful to be
  able to create designs using only parts which are on hand" [hn-onhand].
- **People pay.** Bricker sells at $65 with "1000+" sales [bricker-ratings];
  sculpture kits sell for $90–$1,600 [bricker-builds]. The LEGO Group's own
  model builders use internal "LEGOizer software" [vice-legoizer].
- **The legality question is the biggest of all.** r/lego's "is this
  illegal?" posts reach 824 to 4,076 upvotes [r-illegal] [r-illegal2], far
  above any converter post.

**What follows.** The market is not "a converter": BrickSolvr, Studio and a
dozen repositories give away bricks-only stacks, and builders call them
ugly. It is a converter whose output an experienced builder would not be
ashamed of, that holds together, that comes with a booklet and a price, and
that can be built from what you own. That is a narrow target. Brickworks has more of
its pieces than any other tool (the parts, a check, a booklet, wanted lists,
a collection); section 3 measures what is missing.

## 2. What "illegal" means, and what Brickify should do with it

**The meaning.** The LEGO Group has internal design rules for how parts
may connect, "for stability and to avoid unnecessary stress" [lego-illegal].
The source builders cite is a 2006 talk by Jamie Berard, a designer at the
LEGO Group, *Stressing the Elements* [berard]. Its tests:

- whether a part is under stress that could damage it over time;
- whether a child can still take the parts apart;
- "Can it be built and played with by a 7 year old?";
- "Can one brick replace the need for 5?", which "Reduces Tolerance
  Accumulation";
- "Support Everything!" [berard].

Berard now says the word "was never meant to be official" [bn-illegal]. In
LEGO® Ideas challenges "all building techniques are allowed" unless that
challenge says otherwise [lego-illegal]. So "illegal" means *out of the
system*: it may hold on a shelf, but it depends on a part flexing, on a
tolerance, or on friction.

**Three tiers for a converter.**

| Tier | Techniques | Why |
|---|---|---|
| **Use by default** | Plates and bricks with staggered seams; slopes, curved and inverted slopes, wedge plates, tiles; SNOT on the 5-plates-to-2-studs rule with brackets, bricks with studs on the side (87087, 11211, 4733, 32952) and the headlight brick [ba-snot] [ward]; jumper and headlight offsets; click hinges on a click, "in multiples of 22.5 degrees" [berard]; walls angled on Pythagorean triples (set 10297) [bn-math]; turntables; bars, clips and hands as designed; one stud in a Technic hole, as decoration [berard] | Each snaps into place, stays in the system, and appears in official sets |
| **Behind an option**, each use named in the check | A tile between studs (not illegal: "a tiny bit thinner than a plate" [bn-illegal]); a plate wedged between studs, legal in old sets and illegal now (Berard's frigate: "1x2 plates wedged between two studs" [berard]); friction hinges carrying load; a side stud in a Technic hole ("technically legal… not recommended" [berard]); parts held only by gravity | They hold for display, but depend on tolerance or friction, cannot be checked by snapping, and change from part to part |
| **Never** | A plate forced into a tile's, slope's or open brick's underside; a pin half seated or pushed into a round brick; more than one stud in Technic holes; a cone on an underside pin; a sideways brick sitting directly on a stud (the logo adds 0.14 mm); interlocked headlight bricks; a click hinge between clicks; bent rigid parts; glue, cutting or paint [berard] [bn-illegal] [stonewars-t] | They deform or break parts, or cannot be taken apart |

**For Brickify.**
- Everything Brickify lays is meant to be first tier: plates, bricks,
  slopes, tiles and studs-sideways bricks on the grid. Its check refuses an
  overlap on a 2 LDU lattice, which catches a part forced into another by
  more than that, but not a 0.14 mm interference such as a sideways brick on
  a stud's logo.
- The SNOT the comment asks for is legal, and is what official sets do. The
  "unique curve and illegal techniques" a sculptor would add are mostly the
  second tier. They belong in a *sculpture* mode, off by default, each use
  named, because Brickify's promise is that what it lays can be built and
  will hold.
- Builders want the check itself. A 23,000-piece model drew 1,001 upvotes
  after its builder found that BrickLink's Studio "didn't flag the illegal
  technique" [r-illegal]. A check that names a tier-two or
  tier-three connection, in any model and not only a brickified one, is
  something no CAD offers.

## 3. Our standing, measured

### The models

Fourteen models, chosen to span what people bring: scans, sculpts, low-poly
game models, textured vehicles, a figure, a print-test boat and a whole
scene. Each was downloaded from its primary source on 2026-10-15 and kept
outside the repository; `LICENCE.json` beside each records its source, its
licence word for word, and its file. Pictures in this file are of the
CC0 and CC-BY models only.

| Model | What it tests | Source | Licence | Triangles, format |
|---|---|---|---|---|
| Stanford bunny [m-stanford] | the classic scan; PLY | Stanford 3D Scanning Repository | Research use; no commercial use without permission. Not pictured, not committed | 69,451, PLY |
| Armadillo [m-stanford] | a dense scan, thin limbs | the same | the same | 345,944, PLY |
| Utah teapot [m-teapot] | thin handle and spout | Newell, 1975, as hosted in common-3d-test-models | No licence documented. Not pictured | 6,320, OBJ |
| Spot [m-crane] | texture colours on an animal | Keenan Crane | CC0 | 5,856, OBJ and PNG, no `.mtl` |
| Bob [m-crane] | a textured blob | Keenan Crane | CC0 | 10,688, OBJ, MTL, PNG |
| Fox [m-fox] | a low-poly animal on thin legs | PixelMannen; rig by tomkranis; glTF by AsoboStudio and scurest | CC0 model, CC-BY 4.0 rig | 576, GLB |
| Milk truck [m-truck] | a textured vehicle | Cesium | CC-BY 4.0 | 3,624, GLB |
| Toy car [m-toycar] | a detailed vehicle (its display cloth left out) | Guido Odendahl, Eric Chadwick | CC0 | 108,936, GLB |
| Avocado [m-avocado] | a textured organic shape | Microsoft, via Khronos | CC0 | 682, GLB |
| Figure [m-kenney] | a game character | Kenney, Mini Characters | CC0 | 876, OBJ, MTL, PNG |
| Hayes bust [m-hayes] | a scanned sculpture | Smithsonian, NPG.76.27 | CC0 | 150,000, GLB |
| Bell X-1 [m-x1] | thin wings, landing gear | Smithsonian, NASM A19510007000 | CC0 | 99,586, OBJ, MTL, JPG |
| 3DBenchy [m-benchy] | the 3D-printing test boat | Creative Tools | CC0 | 225,706, STL |
| Greek tholos [m-tholos] | a whole scene: temple, ground, trees | nicolioos, via Objaverse and Sketchfab | CC-BY 4.0 | 38,122, GLB |

Brickify reads OBJ, STL, glTF and GLB. The two PLY scans were written as OBJ
for it, Spot was given a three-line `.mtl` naming its picture, and the toy
car's display cloth was left out; [brickify_bench.py](../tools/bench/brickify_bench.py)
`prepare` does all three.

### How it was measured

Each model was laid at two sizes, 24 and 48 studs along its longest side
(about 19 and 38 cm), four ways:

- **smooth**: Brickify as the panel lays it by default (Surface smooth,
  the model's own colours, not hollow), checked and mended.
- **plain**: Brickify with Surface set to plain bricks and plates.
- **greedy**: the baseline the comment asks for at the least: the same
  measured model cut into whole-brick cells (a stud across, a brick tall),
  each course covered by the largest of the 11 standard bricks (1x1 to 2x8)
  of one colour that fits, studs up, the long way turned on alternate
  courses. It shares Brickify's measuring and colours, so what differs is the
  layout alone. Nothing mended.
- **outside**: legolization 0.5.0 [lz], at 24 studs only, at the same scale
  (its `--pitch` set to Brickify's), with every finishing pass it has on:
  `--slopes --tiles --snot --mesh-colour-mode sampled
  --largest-component-only`, one seed, and a step a layer
  (`--steps layer --no-subassemblies`: its default smart steps more than
  doubled its time on the avocado, 1,151 s against 501 s, for the same 917
  parts; the avocado and the fox kept their first, default runs). Each run
  had 30 minutes. Its build is moved onto the model by its box and nudged
  (translation only) toward the surface, which can only help it. At 48
  studs it was not run: at 24 it took 12 minutes on average.

The measures ([brickify_bench.py](../tools/bench/brickify_bench.py)):

- **Likeness.** Model and build are ray cast from 14 directions (6 faces, 8
  corners), orthographic, 320 x 320. *Silhouette IoU* is the mean over the
  views. The hit points are each one's visible surface: *Chamfer* is the mean
  of the two mean nearest-point distances, *Hausdorff95* the larger of the two
  95th percentiles, *F@0.5* the F-score of points within half a stud of the
  other surface. Distances in studs, and the build's real part geometry is
  used, studs and all.
- **Parts.** Count, distinct part-and-colour lots, the share that are shaped
  (slopes, curves, wedges, tiles), the share of the plan whose top part is
  shaped, studs left showing, the share of 1x1s, and parts in a colour no element
  of theirs comes in (by Rebrickable's element list, `elements.json`).
- **Validity and stability.** Our check as `check_design` runs it (overlaps,
  floating, pieces), weighed by Balance (bridge stud joints past their
  working load, tipping margin). *Seams bridged*: of the pairs of parts side
  by side in a course, the share a third part joins from above or below.
  *Weak points*: parts whose removal splits the model (Testuz's weak
  articulation points [testuz]).
- **Colour.** For the 10 models with colours of their own: each visible point
  of the model against the nearest visible point of the build, mean
  CIEDE2000, and the *floor*: the model's colour against the nearest colour
  in the palette, which no layout can beat.
- **Time.** Measure, lay and check (legolization: its whole run, for the
  runs that finished), on a box shared with other jobs (load 20 to 60 on
  24 threads), so read as an upper bound.

### What it found

**Did it lay the model, and all of it?**

Of the models, at each size: laid at all; whole (95% of the model's visible surface within a stud of the build's); in one piece with the check passing; that, and standing by Balance with no stud joint past its working load; parts the mend took out (mean).

| Studs | Arm | Laid | Whole | One piece, check passes | And stands, no joint past its load | Mended (mean) | Seconds (mean) | Seconds (most) |
|---|---|---|---|---|---|---|---|---|
| 24 | smooth | 11/14 | 4/14 | 11/14 | 8/14 | 53 | 4.0 | 8 |
| 24 | plain | 11/14 | 7/14 | 11/14 | 6/14 | 32 | 2.3 | 6 |
| 24 | greedy | 14/14 | 9/14 | 0/14 | 0/14 | 0 | 0.0 | 0 |
| 24 | outside | 9/14 | 9/14 | 7/14 | 5/14 | 0 | 706.0 | 1536 |
| 48 | smooth | 13/14 | 9/14 | 13/14 | 11/14 | 160 | 32.1 | 159 |
| 48 | plain | 13/14 | 9/14 | 13/14 | 11/14 | 136 | 23.1 | 127 |
| 48 | greedy | 14/14 | 10/14 | 0/14 | 0/14 | 0 | 0.1 | 0 |

**The layout, where all three of ours kept the model whole.**

At 24 studs, 4 models: avocado, bob, milk-truck, spot.
At 48 studs, 9 models: armadillo, avocado, benchy, bob, milk-truck, smithsonian-1, spot, stanford-bunny, utah-teapot.

| Studs | Arm | Parts | Lots | Shaped parts | Tops shaped | Bare studs | IoU | Chamfer (studs) | Lost95 (studs) | Added95 (studs) | F@0.5 stud | Normal error (°) | ΔE2000 (coloured) | Seams bridged | Weak points | 1x1 share | Not a real element |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 24 | smooth | 878 | 110 | 21% | 99% | 38 | 0.916 | 0.23 | 0.60 | 0.52 | 0.950 | 35.5 | 17.4 | 37% | 23.7% | 41% | 1.9% |
| 24 | plain | 722 | 74 | 0% | 0% | 210 | 0.911 | 0.24 | 0.50 | 0.50 | 0.958 | 35.7 | 16.3 | 39% | 23.6% | 39% | 0.2% |
| 24 | greedy | 312 | 45 | 0% | 0% | 219 | 0.905 | 0.26 | 0.45 | 0.63 | 0.902 | 36.6 | 19.3 | 56% | 20.9% | 22% | 0.6% |
| 24 | palette floor |  |  |  |  |  |  |  |  |  |  |  | 7.0 |  |  |  |  |
| 48 | smooth | 4,330 | 149 | 24% | 99% | 338 | 0.950 | 0.23 | 0.46 | 0.56 | 0.943 | 37.8 | 10.1 | 42% | 23.5% | 38% | 1.7% |
| 48 | plain | 3,452 | 87 | 0% | 0% | 1,016 | 0.953 | 0.21 | 0.38 | 0.48 | 0.973 | 38.9 | 8.8 | 49% | 26.7% | 39% | 0.2% |
| 48 | greedy | 1,664 | 49 | 0% | 0% | 1,019 | 0.948 | 0.23 | 0.40 | 0.62 | 0.932 | 41.0 | 9.3 | 55% | 16.2% | 16% | 0.6% |
| 48 | palette floor |  |  |  |  |  |  |  |  |  |  |  | 6.8 |  |  |  |  |

**Against the outside tool, on the models it laid.**

At 24 studs, 7 models both Brickify and it laid: avocado, benchy, bob, spot, stanford-bunny, toy-car, utah-teapot.

| Studs | Arm | Parts | Lots | Shaped parts | Tops shaped | Bare studs | IoU | Chamfer (studs) | Lost95 (studs) | Added95 (studs) | F@0.5 stud | Normal error (°) | ΔE2000 (coloured) | Seams bridged | Weak points | 1x1 share | Not a real element |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 24 | smooth | 750 | 70 | 27% | 98% | 37 | 0.871 | 0.35 | 1.48 | 0.85 | 0.884 | 42.0 | 16.9 | 41% | 29.6% | 44% | 1.5% |
| 24 | plain | 580 | 43 | 0% | 0% | 222 | 0.896 | 0.27 | 0.78 | 0.79 | 0.917 | 43.2 | 15.4 | 46% | 33.3% | 44% | 0.1% |
| 24 | greedy | 272 | 27 | 0% | 0% | 235 | 0.893 | 0.28 | 0.68 | 0.88 | 0.898 | 43.7 | 15.6 | 53% | 26.7% | 24% | 0.2% |
| 24 | outside | 1,108 | 61 | 19% | 31% | 335 | 0.806 | 0.48 | 0.70 | 1.14 | 0.518 | 39.1 | 13.3 | 42% | 23.2% | 41% | 7.9% |
| 24 | palette floor |  |  |  |  |  |  |  |  |  |  |  | 6.5 |  |  |  |  |

**What the numbers say.**
1. **It drops what it cannot hold, and sometimes all of it.** Brickify
   laid nothing for the fox, the figure and the Bell X-1 at 24 studs, and 2
   parts for the fox at 48. It kept the whole model (95% of the model's
   surface within a stud of the build) for 4 of 14 at 24 studs and 9 of 14
   at 48. The Hayes bust kept 37% of itself at 24 studs (plain kept 75%),
   the toy car 73%, the tholos 67% at 48 (its temple and trees went), and
   the teapot lost its spout and handle at both sizes, which Brickify's own
   coverage figure (98%) hides. legolization kept every model it finished,
   the fox's legs included; the greedy stack kept 9 and 10, but every one of
   its 28 builds has parts floating.
2. **What it keeps is one piece, but does not always stand.** All 24 builds
   it laid pass the check in one piece. Weighed by Balance, 3 of the 11 at
   24 studs (the armadillo, the avocado, the milk truck) and 1 of the 13 at
   48 (the avocado) would tip, and the milk truck has two stud joints past
   their working load at both sizes. The panel's status line says
   "buildable in one piece" for all of them: it checks but does not weigh,
   and it does not say what it left out. For the fox it would say "0 parts
   in 0 colours — no bricks", and not why
   ([brickify_dialog.gd](../src/ui/brickify_dialog.gd)).
3. **The surface is what it promises, and shading shows a little of it.**
   99% of the top of every model it kept is a slope, curve or tile,
   against none for plain and greedy, and the studs left showing fall from
   about 1,016 to 338 at 48 studs (from 210 to 38 at 24). The surface's
   normal error, what shading shows, is 37.8° against plain's 38.9° and the
   greedy stack's 41.0° at 48 studs: better, by little.
4. **But it is no closer to the model.** Where all three of ours kept the
   model, they are within 0.005 of each other in silhouette IoU (0.950,
   0.953 and 0.948 at 48 studs) and 0.02 studs in Chamfer (0.23, 0.21,
   0.23). The slopes are chosen per stud by a flat-or-curved flag, and the
   side faces are one-stud staircases in every arm.
5. **Colour is 1.5 to 2.5 times the floor, and smooth is worse than
   plain.** CIEDE2000 averages 10.1 for smooth at 48 studs, 8.8 for plain
   and 9.3 for greedy, against a floor of 6.8 (the model's colours matched
   to the nearest in the palette); at 24 studs, 17.4, 16.3 and 19.3 against
   7.0. Spot's black patches came out Reddish Brown and the figure's black
   hair dark blue: in Oklab a 25% grey is nearer Reddish Brown (8.3) than
   Black (9.8). 1.7% of smooth's parts are in a colour no element of that
   part comes in; and the commonest plate is laid as 3023, which LDraw moved
   to 3023b, so it has no element number in a parts list.
6. **It uses many small parts.** At 48 studs smooth used 2.6 times the
   greedy stack's parts (4,330 against 1,664), 38% of them 1x1s against
   16%. Of the pairs of parts side by side, 42% are bridged by a third part,
   against 55% for greedy, and 23.5% of parts are weak points whose loss
   splits the model, against 16.2%.
7. **It is slow on big scenes.** 32 s on average at 48 studs, 159 s for the
   tholos, on a box shared with other jobs; plain 23 s; the greedy stack
   under a second.
8. **The outside tool, legolization, against Brickify at 24 studs.** It
   finished 9 of 14 within 30 minutes each (125 s to 26 minutes; the
   figure, the milk truck, the armadillo, the bust and the tholos ran out of
   time), and 7 of its 9 are one piece. On the 7 models both laid:
   - **Ours is nearer the model's shape**: IoU 0.871 against 0.806, Chamfer
     0.35 against 0.48 studs. Its builds come out fat, half a stud and more
     past the model on every side (added95 1.14 studs against our 0.85).
   - **It loses less of the model**: lost95 0.70 studs against our 1.48;
     it laid the fox and the toy car's roof, where we laid nothing and an
     open shell.
   - **Its colour is better**: CIEDE2000 13.3 against our 16.9, and Spot's
     patches are black. But 7.9% of its parts are in a colour the part is
     not made in, against our 1.5%.
   - **Its shading is a little better**: normal error 39.1° against 42.0°,
     from SNOT tiles on flat walls; but 31% of its top is shaped against
     our 98%, and its slope pass laid between 0 and 53 slopes a model.
   - **It uses more parts**, 1,108 against 750 (its builds are fatter and
     hollow), and bonds them about as we do: 42% of neighbours bridged
     against our 41%, fewer weak points (23% against 30%), as many 1x1s
     (41% against 44%).
   - **It is two orders slower**: 706 s on average, against 4 s.

### Side by side

Each row is one model from the same corner, lit the same: the model, then
Brickify smooth, Brickify plain, the greedy stack and legolization, each
labelled with its part count. Drawn by `brickify_bench.py pictures` from the
parts' own geometry, studs and all.

**Where it works.** Spot, at 24 studs. Brickify's top is slopes and tiles
where the others show studs; its black patches are Reddish Brown (unit 2).

![Spot at 24 studs: the model, Brickify smooth, Brickify plain, the greedy stack and legolization](brickify/spot-24.jpg)

Bob, at 24 studs.

![Bob at 24 studs, five ways](brickify/bob-24.jpg)

3DBenchy, at 24 studs.

![3DBenchy at 24 studs, five ways](brickify/benchy-24.jpg)

The avocado, at 24 studs.

![The avocado at 24 studs, five ways](brickify/avocado-24.jpg)

**Where it loses the model.** The fox, at 24 studs (model CC0 by
PixelMannen; rig CC-BY 4.0 by tomkranis): Brickify lays nothing (its legs
are thinner than a stud, the body floats, and the mend takes it all out);
the greedy stack keeps the body, floating; legolization keeps the legs.

![The fox at 24 studs: Brickify smooth and plain empty, the greedy stack and legolization](brickify/fox-24.jpg)

The Hayes bust, at 24 studs: smooth kept 37% of it, plain 75%; legolization
ran out of time (30 minutes).

![The Hayes bust at 24 studs, five ways](brickify/smithsonian-1-24.jpg)

The toy car, at 24 studs: its body is an open shell; legolization closes
the roof, ours leave it open.

![The toy car at 24 studs, five ways](brickify/toy-car-24.jpg)

The Greek tholos, at 48 studs ("Greek Tholos" by nicolioos, CC-BY 4.0,
drawn here in bricks): the temple on its thin columns and the trees are
gone from both of Brickify's builds; the greedy stack keeps them, floating.

![The Greek tholos at 48 studs, four ways](brickify/objaverse-48.jpg)

## 4. The plan

Nine units, ranked by how much each moves the measures above toward the
target below, with what builders ask for as the tie-breaker. Each is one
agent's bounded task; each ends with the bench run again
(`brickify_bench.py`, the same 14 models) and its numbers put beside today's.
Units 1 to 3 come first because the others are worth little while Brickify
drops a fox's body or paints a cow brown.

### The target: clearly the best, by measure

On the 14-model bench at 24 and 48 studs, against the greedy stack and every
outside tool that can be run:

| Measure | Today (smooth) | Target |
|---|---|---|
| Laid at all | 24 of 28 | 28 of 28 |
| Whole (95% of the model's surface within a stud of the build) | 13 of 28 | 28 of 28 |
| One piece, our check passes | 24 of 28 | 28 of 28 |
| And standing, no stud joint past its load (Balance) | 19 of 28 | 28 of 28, and passing an independent force check (StableLego's, or legolization's `analyze`) |
| Likeness, where all arms keep the model | IoU equal to the greedy stack's | Silhouette IoU and normal error better than every other arm on every model |
| Colour (ΔE2000 against the palette's floor) | 1.5 times at 48 studs, 2.5 at 24; legolization better | at most 1.3 times, and better than every other arm |
| Parts, against the greedy stack | 2.6 times as many, 38% of them 1x1 | at most 1.6 times, at most 20% 1x1 |
| Side-by-side seams bridged | 42% | at least 60% |
| Parts in a colour that exists | 98.3% | 100%, each with its element number |
| Time at 48 studs (desktop) | 32 s mean, 159 s most | 15 s mean, 60 s most |
| What it hands over | The model; any booklet or list by hand | Booklet, wanted list with a price, and what you already own subtracted, in one press |

Then say so: the bench, its models' licences and the numbers go on
/compare, so anyone can run it against us.

### 1. Keep the whole model

**Why.** The worst result of the bench. A fox, a figure and an aircraft came
out with nothing at 24 studs, and the fox as 2 parts at 48; the bust kept
37% of itself at 24 and the toy car 73%; the teapot lost its spout and
handle at both sizes, which Brickify's coverage figure (98%) hides. Whole,
it was 13 of 28. legolization kept every model it finished, the fox's legs
included, because it fills every cell the surface touches; the greedy stack
kept them too, floating. The cause, read from the runs: legs and stands
thinner than a stud never reach the grid (the fox's grid starts 9 plates
up, the figure's 12), so the largest piece kept is a body in the air; the check then finds every part floating and `mend` takes
them all out. `mend` removes what does not hold; it never joins it.

**What.** (a) Measure thin parts conservatively: a stud column is in where
any of its nine sub-columns is, and a part thinner than a plate is
thickened to one, so nothing of the mesh vanishes. (b) Join, don't drop: a
piece apart is tied to the body by the smallest legal joint that reaches
(a plate across, a bracket, a column of 1x1 rounds as a leg), and only
dropped if none does, and then named. (c) A model that would float or
tip (Balance found 4 of the 24 it laid would tip), or stands on less than a
few studs, gets what a set gives it: a stand, on by default and said; and
the status line weighs before it says "buildable". (d) Never place
nothing: say what could not be held and why.

**Measure.** Laid 28 of 28; whole 28 of 28 (lost95 at most a stud); one
piece and standing, by Balance, on all 28, the status line saying so and
naming any stand added; the teapot's spout and handle and the fox's legs
present (a probe each, with CC0 fixtures for the fox and the figure).

**Touches.** `brickify.gd` (voxelise, `_one_piece`, `mend`), `shapes.gd`
(stitch), `brickify_probe.gd`.

### 2. Colour that reads right

**Why.** ΔE2000 is 1.5 times the palette's floor at 48 studs and 2.5 times at
24, smooth is worse than plain (10.1 against 8.8 at 48), and legolization,
matching by the nearest vertex's colour, beats us (13.3 against 16.9 on the
seven both laid). Two causes, both reproduced: Oklab's straight-line
distance sends a dark neutral to a coloured neighbour (a 25%
grey is 8.3 from Reddish Brown and 9.8 from Black; CIEDE2000 picks Black),
so Spot's black patches came out brown and the figure's black hair blue;
and the smooth surface's slopes and tiles show colours sampled for the
cell, not the face they show, which is why smooth scores worse than plain.
Separately, 1.7% of smooth's parts are in a colour no element comes in,
and Shapes lays retired numbers (3023, which LDraw moved to 3023b), so
`PartLibrary.element_for` finds no element number for the commonest plate
and the parts list goes without one.

**What.** Match with a hue-keeping distance (CIEDE2000, or Oklab with
chroma weighted up for near-neutrals); vote each cell's colour by the
visible faces only (ObjToSchematic's "smart averaging" [o2s]); give a
surface part the colour of the surface it shows; choose among the colours
the part is actually made in (Rebrickable's elements), else the nearest it
is; resolve a moved number before looking up its element; offer ordered
dithering on flat panels.

**Measure.** ΔE2000 at most 1.3 times the floor at 48 studs; smooth no worse
than plain; no neutral source turned chromatic on Spot or the figure;
parts in a colour that exists 100%, each with an element number.

### 3. Bond like a builder

**Why.** Where all three of ours kept the model, smooth used 4,330 parts at
48 studs to the greedy stack's 1,664; 38% were 1x1s (greedy 16%); 42% of the
pairs side by side were bridged by a third part (greedy 55%); and 23% of
parts were weak points whose loss splits the model (greedy 16%). Builders
say "we usually don't want to stack 1x1 bricks" [r-brickformer] and judge
a converter by its seams [r-seams]. Legolization's refinement, splitting and
merging around the weakest brick, is the published method [luo-slides];
Kollsker's lookahead and staggering reward [kollsker] and legolization's
seven strategies [lz] are the open ones.

**What.** After Shapes lays the surface, refine the hidden core: merge runs
into the longest brick of one colour (the core is one colour already),
offset each course's seams from the one below, split and merge again
around each weak point, keep 1x1s to where the surface needs them, and keep
every change only if the check still passes.

**Measure.** Parts at most 1.6 times the greedy stack's; 1x1 share at most
20%; seams bridged at least 60%; weak points no more than greedy's;
Balance's bridge joints past their load still 0; likeness unchanged.

### 4. Fit the surface by distance

**Why.** Where nothing is lost, smooth is no closer to the model than plain
(Chamfer 0.23 against 0.21 studs at 48, IoU 0.950 against 0.953), and its
normal error, what shading shows, is only 1.1° better (37.8° against
38.9°). Slopes are chosen per stud from a flat or curved flag, not by how
near each puts the surface.

**What.** Score every candidate surface part (slope, curve, inverted,
wedge, tile, round) by its distance to the mesh at the third-of-a-stud
samples Brickify already takes, and by its normal, and keep the best; add
the angles it lacks: 65° and 75° slopes, double curves, round 2x2 bricks
and domes, wedge slopes, quarter tiles.

**Measure.** Chamfer 20% and normal error 30% below plain's at both sizes;
smooth no worse than plain on any model.

### 5. SNOT that holds

**Why.** It is what the comment asks for, and what no tool yet does in a way
that holds: NiemanSculpt lays SNOT in six directions but reports
connectivity "98.5% to 99.7%" [nieman-guide]; the one published method
lays loose plates [lambrecht]; no stability solver models side studs
[stablelego]. In Brickify, sideways parts are 2 to 3% of a build, on flat
flanks only; every steep face is a one-stud staircase in every arm.
legolization's SNOT tiles on flat walls give it a lower normal error than
ours (39.1° against 42.0° on the seven both laid), though 31% of its top is
shaped against our 98%: the walls are where the error is.

**What.** Lambrecht's cubes on the lattice Brickworks already has: 2 x 2
studs by 5 plates, each surface cube turned to its area-weighted normal and
laid as plates, slopes and curves facing out, each tied to the core by
bricks with studs on the side (87087, 11211, 30414), brackets or headlight
bricks, and checked by the same check. First-tier connections only.

**Measure.** Normal error on faces steeper than 60° down by 30%;
Hausdorff95 in the side views down; one piece; parts at most 15% more.

### 6. Show it: first run, the homepage, /compare

**Why.** Neither the homepage nor /compare mentions Brickify, and the tour
does not reach it ([index.html](../web/index.html),
[compare.html](../web/compare.html), [tour.gd](../src/ui/tour.gd)).
ObjToSchematic's admired flow is five steps, each re-run on its own [o2s].

**What.** After units 1 to 3, so what is shown holds up:
- **Homepage**: "Any 3D model, in parts you can buy": a model beside its
  Brickify build and a greedy stack, with the bench's numbers.
- **/compare**: a table of what each converter lays (Studio's Sculpture,
  NiemanSculpt, Bricker, legolization, BrickSolvr, Brickworks), and the
  bench, with its models and licences, for anyone to repeat.
- **First run**: a "Brickify a model" card with three CC0 samples (Spot,
  Bob, the avocado). The panel as stages, Model, Size, Colours, Lay,
  Check, Booklet and buy, each re-run alone; a preview before it is
  placed; what was lost drawn over the model, never silently.

**Measure.** `brickify_flow.mjs`: a sample placed from a cold start in 3
clicks and under 60 s on a preview; the pages pass the trademark test; the
tour has a Brickify step.

### 7. Buy it, or build it from what you own

**Why.** "I just need the list of parts… so that I can calculate how much the
total thing will cost me" [r-parts]; "create designs using only parts which
are on hand" [hn-onhand]; Brickit, which works from your pile, drew 646
and 659 points [hn-brickit1] [hn-brickit2]. Brickworks has the booklet, the BrickLink
wanted list, the Rebrickable list and the collection's shortfall, but none
is offered from Brickify, and no price is shown (BrickLink's price guide
wants a seller's keys). NiemanSculpt Pro limits parts by price
[nieman-guide].

**What.** From the placed build, in one press: the booklet by courses, with
SNOT panels as sub-assemblies and every step's partial build checked to
stand (Balance), the wanted list, and a price where the owner chooses a
source (a BrickLink key, or BrickOwl's API). "Lay from my collection": the
collection as a constraint, parts and colours on hand first, stand-ins by
colour then by size, the shortfall said.

**Measure.** Every step's partial build stands, on the bench's builds; with a
test collection (set 10698's 790 parts), the share of parts drawn from it
and what that costs in ΔE2000.

### 8. Model and sculpture

**Why.** A playable model and a display sculpture want different things,
and the size cap (64 studs) and the times (159 s at 48) stop sculptures.

**What.** *Model*: a solid, bonded core, first-tier connections only.
*Sculpture*: a hollow shell, SNOT, sizes to 128 studs, a stand, and, behind an option,
the second tier from section 2, each use named in the check. Both run in the
background on the web as now. And the check learns the tiers for any
model, brickified or not: it names a second- or third-tier connection where
it finds one, which builders ask of Studio and do not get (section 2).

**Measure.** 96 studs under 2 minutes on the desktop; plastic and price per
mode reported; second-tier uses counted and named; a probe model with one
connection of each tier, each named right.

### 9. Every file people have

**Why.** Scans come as PLY (2 of the 14 had to be converted; BrickSolvr and
legolization read it [bricksolvr] [lz]); Spot came as an OBJ and a picture
with no `.mtl`, and came in grey until we wrote one; 3D printing sites
default to 3MF; voxel artists save VOX; FBX is the animation tools' format;
Brick My World reads USDZ [bmw].

**What.** PLY (text and binary, either byte order), 3MF (a zip of XML, with
colours), VOX (MagicaVoxel's colours, a voxel to a stud), FBX through
Godot's `FBXDocument`, and a picture picked for an OBJ that names none.
USDZ only if Godot gains a reader: its USDC is a binary crate with none in
the engine.

**Measure.** The bench's 14 read with no conversion; a fixture of each format
in `brickify_probe`.

### What each unit moves

| Unit | Laid, whole | Likeness | Colour | Parts, bond, stability | Cost | Experience |
|---|---|---|---|---|---|---|
| 1 Keep the whole model | **28/28** | lost95 | — | one piece and standing, by joining | — | nothing silently lost |
| 2 Colour | — | — | **ΔE2000 ≤ 1.3 x floor** | — | real elements | the colours look right |
| 3 Bond | — | — | — | **−40% parts, 1x1s, seams** | fewer parts | sturdier |
| 4 Fit by distance | — | **Chamfer, normals** | — | — | — | smoother |
| 5 SNOT | — | **steep faces** | — | holds | — | the comment's ask |
| 6 Show it | — | — | — | — | — | **found, tried in 60 s** |
| 7 Buy, own | — | — | — | partial builds stand | **price, shortfall** | one press to buy |
| 8 Modes | — | — | — | per mode | plastic | sculptures to 128 studs |
| 9 Files | — | — | colour of bare OBJs | — | — | **any file opens** |

## 5. Unit 1, done: Brickify keeps the whole model (2026-10-15)

Unit 1 of the plan, and a bug. Brickify laid nothing for the fox, the
Kenney figure and the Bell X-1 at 24 studs, kept the whole model in 13 of 28
runs, called a model buildable without weighing it, and laid the commonest
plate as 3023, a number LDraw has moved to 3023b. Branch
`worktree-agent-af9a21f60d09d744a`, with `main` at `4138091` merged.

**In short.** On the same 14 models it now lays all 28 runs (from 24), keeps
25 of them whole (from 13), and all 28 are in one piece with the check
passing (from 24). None tips (4 of the 24 laid did), 8 of them standing on
a stand they were given, each said with its reason; 22 stand with no stud
joint past its working load (from 19), and 6 still have one or more (from 2:
the joins and the parts now laid carry weight on few studs). What it leaves
out it says: how much, where, and why.
The target was 26 of 28 whole; it falls one short (below, and "What is
left"). It is slower: 12 s on average at 24 studs and 72 s at 48, against
6.7 and 47 on `main` today.

**What changed** ([brickify.gd](../src/assembly/brickify.gd),
[shapes.gd](../src/ai/shapes.gd), [the panel](../src/ui/brickify_dialog.gd)):

1. **Thin parts measured conservatively** (`_touched`, `_thin`). A cell was the
   model's only where the middle of its stud was inside, so a leg a third of
   a stud across never reached the grid. Now every cell the surface passes
   through is found as well (each triangle against each cell its box
   reaches, by separating axes), and one counts where nothing measured is
   among the 26 cells round it: a part thinner than a stud or a plate, at the
   size chosen. The cells it passes through between such a part and the body
   join the two, and a part one plate thick is made two, so its plates cross
   each other's joints. A thick body comes out no fatter: its own surface
   cells always have a measured cell beside them. The columns of thin parts
   are laid plain (`plain_at`: no slope, wedge or top tile there): a wing two
   plates thick in tiles, wedges and slopes came apart into bits nothing held.
2. **Join, don't drop.** On the grid (`_join`), each piece apart is joined to
   the rest by the cheapest way, along the model's own thin surface first,
   else through the air, a plate up or down costing less than a stud across,
   so a join is a pillar more than a bridge; it starts beside the piece's
   middle and is two studs square. A largest piece standing on nothing is
   stood on the ground. In the plan, Shapes no longer prunes Brickify's pieces
   (`keep_pieces`: that prune was where the teapot's spout went), and once its
   own first ways are spent it lays the plates, then the slopes, about each
   joint again as plates crossing it (`rejoin`), each way kept only if it
   leaves fewer pieces. Once laid and
   checked, what is still apart or held by nothing (floating to the lattice,
   or not held by the parts' real shapes, which main's exact check now
   reports by index) is joined by the least that reaches (`_tie`): a 1 x 2
   plate under or over a joint where two parts stand side by side, or the
   shortest pillar of 1 x 1s onto anything held, each stud checked against
   the part's real cover. A round of joins that joins nothing is taken back.
   Only dust, a piece too far to join, or what nothing joins is taken out,
   and never the body; each is said: how much, where on the model, and why.
   What no part fills, a hundredth of the model or more, is said too.
3. **Never nothing.** A size that lays nothing says why and gives the
   smallest size that lays it whole (half again a try, to 64 studs), and the
   panel sets the size to it.
4. **A stand** (`_stance`, `lay_stand`). A model that stands only on feet of
   three studs or fewer (a fox's legs, an aircraft's wheels), comes within
   half a stud of tipping, or stands in pieces only the ground would join is
   laid on a stand under its feet and its centre of mass, a stud and a half
   round and a stud more: two plates whose joints cross (strips along x under
   strips along z), tiled where the model does not stand, black, or the one
   colour asked for, or the darkest of the colours it is cut to. Weighed with
   Balance once laid; if it would tip after all, or all but, it gets one
   then. A sphere on its twelve studs does not: feet decide, not a share of
   the plan. A stud joint past its working load is propped by a pillar under
   what it carries, kept only if fewer are past their load. A Stand choice
   on the panel (and `stand=` on the tool) turns stands off.
5. **Weighed before "buildable"** (`Brickify.said`). The panel's line and the
   tool's answer say whether it is one piece, whether it stands (Balance,
   its margin and edge), on what (its own studs, or the stand and why), what
   was joined and propped, and what was left out, where and why.
   "Buildable" only when it is one piece, passes the check, stands, and no
   stud joint is past its working load.
6. **Today's numbers** (`Shapes.current`). Shapes lays each part by the number
   LDraw gives it now, read from the catalogue's stubs: 3023 goes down as
   3023b, and so would a part LDraw moves later. Only stubs that move a part
   nowhere are followed (all but 68 of 1,161); the probe checks that none of
   the 86 parts Brickify may lay is one of the 68.
7. **Fewer checks.** Each check on a big model is seconds, more since the
   exact check; the mend takes what collides out in one round, joins in at
   most two, and takes what is still loose out in one more.

### The bench again

The research's bench, measuring what it measured: the same 14 models,
prepared the same way, at 24 and 48 studs, smooth, plain and the greedy
stack, measured by `brickify_bench.py` (legolization was not run again).
There are two befores. The research's own run on `7a55e86`. And `main` at
`4138091`, whose check now also asks every part's real shape (the exact
check), so every check costs more; that one is the fair before for time.
The box was shared with other jobs at a load of 30 to 55 on 24 threads
throughout, so read times as upper bounds.

The bench changed in three ways, all so it measures the model and not its
base: a stand's parts are left out of likeness, bond and the count of shaped
tops; the model is lowered by the stand's two plates so it lines up with the
model it came from (`stand_of`, `build_mesh`); and the pictures draw the
stand. Parts and time count the stand. The greedy stack is laid over the new
measuring's grid, so it now has the thin parts too. `report` adds a column
for runs standing on a stand.

**Smooth, the panel's default: laid, whole, one piece, standing.**

| Run | Studs | Laid | Whole | One piece, check passes | And stands, no joint past its load | On a stand | Seconds (mean) | Seconds (most) |
|---|---|---|---|---|---|---|---|---|
| research | 24 | 11/14 | 4/14 | 11/14 | 8/14 | 0 | 4.0 | 8 |
| main | 24 | 11/14 | 4/14 | 10/14 | 7/14 | 0 | 6.7 | 13 |
| after | 24 | 14/14 | 12/14 | 14/14 | 13/14 | 5 | 12.1 | 27 |
| research | 48 | 13/14 | 9/14 | 13/14 | 11/14 | 0 | 32.1 | 159 |
| main | 48 | 13/14 | 9/14 | 13/14 | 11/14 | 0 | 47.1 | 210 |
| after | 48 | 14/14 | 13/14 | 14/14 | 9/14 | 2 | 71.6 | 298 |

**Plain, Surface set to plain bricks and plates.**

| Run | Studs | Laid | Whole | One piece, check passes | And stands, no joint past its load | On a stand | Seconds (mean) | Seconds (most) |
|---|---|---|---|---|---|---|---|---|
| research | 24 | 11/14 | 7/14 | 11/14 | 6/14 | 0 | 2.3 | 6 |
| main | 24 | 11/14 | 7/14 | 11/14 | 6/14 | 0 | 3.6 | 10 |
| after | 24 | 14/14 | 14/14 | 14/14 | 9/14 | 4 | 8.0 | 26 |
| research | 48 | 13/14 | 9/14 | 13/14 | 11/14 | 0 | 23.1 | 127 |
| main | 48 | 13/14 | 9/14 | 13/14 | 11/14 | 0 | 32.1 | 170 |
| after | 48 | 14/14 | 13/14 | 14/14 | 9/14 | 2 | 54.9 | 205 |

**The layout, smooth, on the models whole in every run**, so likeness and
cost are of the same models. Parts count the stand where one was given.

At 24 studs, the 4 models whole in every run: avocado, bob, milk-truck, spot.

| Run | Parts | 1x1 share | Seams bridged | Weak points | Tops shaped | IoU | Chamfer | Lost95 | Added95 | Normal (°) | ΔE2000 | Seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| research | 878 | 41% | 37% | 23.7% | 99% | 0.916 | 0.23 | 0.60 | 0.52 | 35.5 | 17.4 | 4.7 |
| main | 878 | 41% | 37% | 23.7% | 99% | 0.916 | 0.23 | 0.60 | 0.52 | 35.5 | 17.4 | 6.9 |
| after | 972 | 41% | 37% | 24.1% | 98% | 0.925 | 0.21 | 0.46 | 0.52 | 35.3 | 17.1 | 8.9 |

At 48 studs, the 9 models whole in every run: armadillo, avocado, benchy, bob, milk-truck, smithsonian-1, spot, stanford-bunny, utah-teapot.

| Run | Parts | 1x1 share | Seams bridged | Weak points | Tops shaped | IoU | Chamfer | Lost95 | Added95 | Normal (°) | ΔE2000 | Seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| research | 4,330 | 38% | 42% | 23.5% | 99% | 0.950 | 0.23 | 0.46 | 0.56 | 37.8 | 10.1 | 23.7 |
| main | 4,311 | 38% | 42% | 23.6% | 99% | 0.949 | 0.23 | 0.46 | 0.56 | 37.8 | 10.1 | 37.9 |
| after | 4,359 | 39% | 42% | 24.3% | 99% | 0.950 | 0.23 | 0.44 | 0.56 | 37.8 | 10.1 | 55.1 |

**Each model, smooth**: parts, lost95 in studs (whole is at most 1), and
whether it stands (by Balance with no stud joint past its working load; "on
a stand" where it was given one).

| Model | Studs | research: parts, lost95, stands | main: parts, lost95, stands | after: parts, lost95, stands |
|---|---|---|---|---|
| armadillo | 24 | 493, 4.04, tips | 493, 4.04, tips | 603, 1.26, stands |
| armadillo | 48 | 2,686, 0.50, stands | 2,684, 0.50, stands | 2,740, 0.46, stands |
| avocado | 24 | 829, 0.73, tips | 827, 0.73, tips | 855, 0.73, on a stand |
| avocado | 48 | 4,514, 0.40, tips | 4,511, 0.40, tips | 4,561, 0.40, on a stand |
| benchy | 24 | 467, 1.13, stands | 465, 1.13, stands | 555, 0.63, stands |
| benchy | 48 | 2,782, 0.43, stands | 2,775, 0.42, stands | 2,833, 0.42, stands |
| bob | 24 | 910, 0.42, stands | 910, 0.42, stands | 1,062, 0.31, stands |
| bob | 48 | 4,029, 0.35, stands | 4,029, 0.35, stands | 4,151, 0.35, stands |
| character | 24 | nothing laid | nothing laid | 627, 0.46, stands |
| character | 48 | nothing laid | nothing laid | 2,869, 0.58, 3 joints over |
| fox | 24 | nothing laid | nothing laid | 224, 0.50, on a stand |
| fox | 48 | 2, 31.63, stands | 2, 31.63, stands | 967, 0.39, 2 joints over |
| milk-truck | 24 | 768, 0.91, 2 joints over | 768, 0.91, 2 joints over | 889, 0.45, on a stand |
| milk-truck | 48 | 4,261, 0.56, 2 joints over | 4,261, 0.56, 2 joints over | 4,314, 0.56, 2 joints over |
| objaverse | 24 | 970, 6.48, stands | 970, 6.48, stands | 2,213, 0.75, 16 joints over |
| objaverse | 48 | 4,962, 13.92, stands | 4,960, 13.92, stands | 10,986, 2.43, 57 joints over |
| smithsonian-1 | 24 | 407, 11.29, stands | 407, 11.29, stands | 1,218, 0.60, stands |
| smithsonian-1 | 48 | 7,713, 0.40, stands | 7,707, 0.40, stands | 7,782, 0.39, stands |
| smithsonian-2 | 24 | nothing laid | nothing laid | 171, 1.08, on a stand |
| smithsonian-2 | 48 | 405, 13.34, stands | 405, 13.34, stands | 650, 0.85, stands |
| spot | 24 | 1,005, 0.35, stands | 1,005, 0.35, stands | 1,081, 0.34, on a stand |
| spot | 48 | 4,787, 0.39, stands | 4,787, 0.39, stands | 4,956, 0.39, on a stand |
| stanford-bunny | 24 | 985, 1.59, stands | 985, 1.59, stands | 1,011, 0.91, stands |
| stanford-bunny | 48 | 4,887, 0.39, stands | 4,864, 0.39, stands | 4,902, 0.39, stands |
| toy-car | 24 | 444, 4.95, stands | 444, 4.95, not one piece | 756, 0.50, stands |
| toy-car | 48 | 2,745, 4.13, stands | 2,742, 4.13, stands | 3,437, 0.90, 3 joints over |
| utah-teapot | 24 | 607, 1.20, stands | 597, 1.20, stands | 668, 0.33, stands |
| utah-teapot | 48 | 3,310, 0.70, stands | 3,178, 0.70, stands | 2,996, 0.65, stands |

**What the numbers say.**
1. **Nothing is laid as nothing.** The fox, the figure and the X-1 are laid
   at both sizes. The fox at 24 studs keeps all four legs and stands on a
   4 × 12 stand, because its legs reached the ground as two pieces. The fox
   at 48 is 967 parts, where it was 2.
2. **Whole in 25 of 28, from 13.** The Hayes bust at 24 studs went from
   lost95 11.3 to 0.60, the toy car from 4.95 and 4.13 to 0.50 and 0.90,
   the teapot (spout and handle) from 1.20 to 0.33, the tholos at 24 from
   6.48 to 0.75. Plain is whole in 27 of 28.
3. **Every build is one piece and passes the check, and every one stands.**
   Eight were given a stand: the avocado at both sizes and the X-1 at 24
   would tip; the fox at 48, Spot at both sizes and the milk truck at 24
   stand on feet of three studs or fewer; the fox at 24 stood in two pieces.
   Six still have a stud joint past its working load: 2 to 3 on the figure,
   the fox and the toy car at 48, the milk truck's 2 at 48 as before, and 16
   and 57 on the tholos, whose columns and trees are now laid.
4. **Nothing else got worse on the models whole before.** IoU, Chamfer,
   normal error, colour, seams bridged and the share of 1x1s are equal or a
   little better; lost95 is lower. Parts rise by 1% at 48 studs and 11% at 24,
   mostly stands. Weak points rise by under a point.
5. **Time is the cost.** On those same models, 8.9 s against 6.9 at 24
   studs and 55 s against 38 at 48. Across all 28 runs it is 12.1 s and 72 s
   on average, 27 s and 298 s at most, against `main`'s 6.7 and 47, 13 and
   210. Joining in the plan and the mend's extra checks are most of it, and
   the models laid now (the tholos keeps its temple: 10,986 parts at 48 where
   it laid 4,960) are bigger.

### Proof

- `brickify_probe` (headless), new section "the whole model", written
  against what `main` has too so it runs there. The fox at 24 studs
  (`tests/fixtures/brickify/fox.obj`: a CC0 model, CC BY 4.0 conversion,
  credited in the file) is laid with each of its four legs there from the
  foot up, with 97% of it in a part and nothing left out, one piece, standing.
  A body with a cube floating a stud and a half over it
  (`BrickifySamples.floating`) has a part at the cube's middle. A post with
  a block past its edge (`BrickifySamples.overhang`) is given a stand and
  stands on it. Every number laid in the probe's builds is the one LDraw
  gives the part today, and none of the 86 parts Brickify may lay has a stub
  that turns it. **On `main` `4138091` it fails 7 checks** (the fox lays
  nothing, the cube is dropped, the post tips with no stand, 3023 is laid).
  On the branch it passes; the forty-stud bunny takes 12.9 s.
- `brickify_ui_probe` (windowed): the panel's line weighs now: "buildable in
  one piece; it stands on a stand 12 × 9 studs, added because it would tip,
  its centre of mass 1.4 studs past what it stands on …". `shapes`,
  `patterns`, `cabins`, `exact`, `app_tools`, `example_name` and `mcp_sync`
  pass (the tool's schema has `stand` now).
- In a browser on a preview (`https://brickworks-fkmqo20xu-xaxis-projects.vercel.app`),
  `tools/release/preview_checks.sh` runs `brickify` (the bunny) and the new
  `brickify_fox` (the fox at 24 studs, whose line must say it stands on a
  stand). Both pass. The fox read "263 parts in 9 colours, buildable in one
  piece; it stands on a stand 4 × 12 studs … nothing of it left out".

### What is left

- **Three runs not whole.** The armadillo at 24 (lost95 1.26) and the X-1 at
  24 (1.08): small surface parts on thin parts (cheese slopes on wedges,
  1x1 plates, tiles) that nothing holds, taken out and said. Plain keeps both
  whole. An experiment that lays the columns about such loose parts again
  plain made the armadillo whole (0.53) but left the X-1's wing seams worse
  until it was made to keep only the lay that keeps more; it was not benched
  at full size and is not in this branch. The tholos at 48 (2.43): a scene of
  columns and trees, 782 parts taken out, and not whole in plain either.
- **Joints past their load** on six runs. Props are tried and kept only when
  they help; on these they rarely did. Bracing such joints belongs with unit
  3 (bond).
- **A hollow model's floor**: the hollow sphere's bottom cap is a piece that
  nothing joins (on `main` too, silently); now it is said.
- **Time**, above. Faster joining in the plan, by keeping the pieces between
  rounds, is the next lever.
- **The colour of a cell** and the smooth surface's look are unit 2's; this
  unit did not touch them, and ΔE2000 is unchanged.

## 6. Unit 2: colour that reads right (2026-10-16)

Unit 2 of the plan, and the time unit 1 cost. Brickify matched each sampled
colour to the palette by Oklab's straight line, which sends a 25% grey to
Reddish Brown before Black. It gave a cell the colour of samples stepped a
fixed way into the model, so the cell that shows often took its colour from
the cells round it or from a surface nobody sees. It gave a slope the colour
of the stud above it. 1.3% of smooth's parts on `main` today are in a colour
no element of theirs comes in. Branch `worktree-agent-a9905a5be6483ab5d`,
from `main` at `2789cd0`.

**In short.** On the 10 bench models with colours of their own, ΔE2000 at 48
studs is 1.28 times the palette's floor, from 1.54 (9.5 against 11.4; floor
7.4), and at 24 studs 1.54 times, from 2.00. Spot's black patches are black:
none of its neutral surface is laid in a strong colour, from 40%. The
figure's hair is black, not Dark Blue, but 8% of its neutral surface is still
laid in a colour, from 72% (18% at 24 studs, from 70%). Every part of all 56
runs has an element number, from 98.7% of smooth's. Two targets are missed.
Smooth is still a little worse than plain at 48 studs (9.5 against 9.0; it
was 11.4 against 10.6), though level at 24 (11.5 against 11.6). And the
forty-stud bunny is slower, not faster: 17.7 s against `main`'s 15.8 in the
same batch. One more run is not whole than on `main`: 24 of 28, from 25.

**What changed** ([brickify.gd](../src/assembly/brickify.gd),
[shapes.gd](../src/ai/shapes.gd)):

1. **Matched as an eye judges** (`Brickify.de2000`, `_nearest`). Each
   sampled colour goes to the palette colour nearest by CIEDE2000, the
   measure the bench scores by, weighed among the few nearest in a straight
   line in L\*a\*b\*. A 25% grey goes to Black (11.0 away), not Reddish
   Brown (17.7); a 38% grey to Dark Bluish Grey.
2. **A cell coloured by what shows of it** (`_shown_at`): ObjToSchematic's
   "smart averaging", by visible faces only [o2s]. A sample votes for the
   cell whose face shows it: out from just inside the surface along its
   normal, the last of the model's cells before the air, or, where the grid
   stops short of the surface, the first going in. A surface buried in
   another part of the model (inside it a quarter of a stud ahead and behind:
   a figure's head under its hair) or with more than a stud and a half of the
   model in front of it (a truck's inside) votes for nothing. A face wound
   the wrong way round is read the other way.
3. **A slope in the colour of the surface it stands for** (`Plan._shown`,
   Brickify's grids only): the top plate of each stud it covers, the colour
   most of them are, a tie to the stud above. A design's shapes keep the
   colour above, as before.
4. **Every part in a colour the LEGO Group sells it in.** A slope sold in none of the
   palette's colours is not laid (`sold_in`): the inverted 2 x 2 slope laid
   under overhangs, 3660a, has no element at all. Any other part with no
   element in its colour is laid in the nearest colour, by CIEDE2000, that it
   has one in (`made_colours`, after laying and again after the mend). One
   colour asked for is kept as asked.
5. **Measured where the time goes** ([brickify_phases.gd](../src/dev/brickify_phases.gd)),
   and two cuts. The stitch maps the plan once a round, not once for each
   piece it tries, and the mend weighs a check (Balance) only once it passes
   in one piece (`weigh_whole` in `Assistant._check`): on the 48-stud scans
   weighing was 0.6 to 4.5 s of each of their three checks.
6. **The bench** measures what the plan asks: the share of the model's
   neutral surface (CIELAB chroma under 5) laid in a strong colour (chroma 20
   or more: Reddish Brown is 37, Dark Blue 27, Black 9). Each run records its
   phases, and `pictures --before RUN` draws each arm before and after.

**Tried and taken out.** Pairing every piece the stitch could in one round
halved the 48-stud scans' pairing, but changed which joins were made: the
probe's hollow sphere came out with more parts than the solid one (1,682
against 1,624). Filtering every plate, brick and edge part by the colours it
is sold in as Shapes lays it, and swapping 3660a for the mould the LEGO Group sells,
3660b, ran only together with that pairing and were taken out with it,
unmeasured alone.

### The bench again

The same 14 models at 24 and 48 studs, smooth and plain; `main` laid in its
own checkout at a load of 45 to 60, the branch in two processes at once at a
load of 10 to 45, so the seconds are not a fair ratio; the bunny below is.
The greedy stack was not laid again.

| Run | Arm | Studs | Laid | Whole | One piece, check passes | And stands, no joint past its load | On a stand | Parts | Seconds (mean) | Seconds (most) |
|---|---|---|---|---|---|---|---|---|---|---|
| main | smooth | 24 | 14/14 | 12/14 | 14/14 | 13/14 | 5 | 11,933 | 12.0 | 39 |
| after | smooth | 24 | 14/14 | 11/14 | 14/14 | 11/14 | 5 | 12,241 | 9.6 | 25 |
| main | smooth | 48 | 14/14 | 13/14 | 14/14 | 9/14 | 2 | 58,145 | 73.8 | 374 |
| after | smooth | 48 | 14/14 | 13/14 | 14/14 | 9/14 | 2 | 57,947 | 59.0 | 241 |
| main | plain | 24 | 14/14 | 14/14 | 14/14 | 9/14 | 4 | 10,056 | 8.2 | 30 |
| after | plain | 24 | 14/14 | 13/14 | 14/14 | 9/14 | 5 | 10,377 | 7.2 | 25 |
| main | plain | 48 | 14/14 | 13/14 | 14/14 | 9/14 | 2 | 48,390 | 54.8 | 248 |
| after | plain | 48 | 14/14 | 12/14 | 14/14 | 9/14 | 4 | 47,505 | 40.3 | 205 |

**Colour**, mean CIEDE2000 over the 10 models with colours of their own
(avocado, Bob, the figure, the fox, the milk truck, the tholos, both
Smithsonian models, Spot, the toy car), against the palette's floor (7.4).
Per model, the ratio to the floor at 48 studs went from a median of 1.39
(1.09 to 2.97) to 1.21 (0.93 to 2.33); at 24, from 1.81 (1.30 to 3.30) to
1.39 (1.18 to 2.89).

| Studs | Arm | ΔE2000 main | ΔE2000 after | Times the floor, main | Times the floor, after |
|---|---|---|---|---|---|
| 24 | smooth | 14.9 | 11.5 | 2.00 | 1.54 |
| 24 | plain | 14.0 | 11.6 | 1.89 | 1.56 |
| 48 | smooth | 11.4 | 9.5 | 1.54 | 1.28 |
| 48 | plain | 10.6 | 9.0 | 1.43 | 1.21 |

**Each coloured model, smooth**: ΔE2000, and the share of its neutral surface
laid in a strong colour (how much of it is neutral in brackets).

| Model | Studs | ΔE2000 main → after | Floor | Neutral laid in a colour, main → after |
|---|---|---|---|---|
| avocado | 24 | 18.2 → 11.2 | 8.2 | (none neutral) |
| avocado | 48 | 9.0 → 9.6 | 8.2 | (none neutral) |
| Bob | 24 | 12.7 → 11.0 | 3.8 | (under 1% neutral) |
| Bob | 48 | 11.4 → 8.9 | 3.8 | (under 1% neutral) |
| figure | 24 | 15.9 → 14.5 | 12.3 | 70% → 18% (of 21%) |
| figure | 48 | 14.3 → 11.5 | 12.3 | 72% → 8.0% (of 21%) |
| fox | 24 | 7.7 → 6.7 | 4.6 | 21% → 17% (of 17%) |
| fox | 48 | 6.0 → 5.9 | 4.6 | 8.7% → 8.0% (of 17%) |
| milk truck | 24 | 25.8 → 11.0 | 7.8 | 23% → 4.3% (of 80%) |
| milk truck | 48 | 12.3 → 7.9 | 7.8 | 20% → 2.0% (of 80%) |
| tholos | 24 | 16.8 → 13.6 | 10.9 | 37% → 24% (of 16%) |
| tholos | 48 | 17.8 → 12.2 | 10.9 | 37% → 16% (of 16%) |
| Hayes bust | 24 | 11.5 → 10.8 | 5.9 | (under 1% neutral) |
| Hayes bust | 48 | 7.4 → 7.4 | 5.9 | (under 1% neutral) |
| Bell X-1 | 24 | 10.2 → 9.6 | 7.0 | 80% → 52% (of 6%) |
| Bell X-1 | 48 | 10.3 → 9.6 | 7.0 | 79% → 46% (of 6%) |
| Spot | 24 | 11.6 → 9.9 | 8.1 | 33% → 0.0% (of 22%) |
| Spot | 48 | 10.2 → 9.0 | 8.1 | 40% → 0.0% (of 22%) |
| toy car | 24 | 18.3 → 16.3 | 5.7 | 48% → 38% (of 26%) |
| toy car | 48 | 15.7 → 13.1 | 5.7 | 34% → 19% (of 26%) |

**Parts with an element number**: smooth 934 of 70,078 without one on `main`
(1.3%), none of 70,188 after; plain 110 of 58,446 (0.19%), none of 57,882.
**Parts**: at 24 studs smooth uses 2.6% more (avocado 23%, fox 28%, milk truck
15% more: more colours told apart), at 48 0.3% fewer.

**Where the time goes**, the forty-stud bunny (the probe's) laid three times
by `main` and by the branch in one job, side by side (medians, seconds):

| | Total | Measure (colour) | Lay (core, stitch) | Check (checks) |
|---|---|---|---|---|
| main | 15.8 (15.6 to 18.0) | 0.9 | 10.0 | 5.3 (1) |
| branch | 17.7 (17.7 to 18.0) | 1.1 (0.8) | 8.0 (3.5, 4.2) | 8.3 (2) |

The lay is 2 s faster: the stitch's 35 rounds now map the plan once each.
Of the stitch, the rejoin (21 tries, each a piece count of the whole plan) is
2.2 s and finding the pieces each round 0.9. The check is 3 s slower: the
branch lays the bunny differently (2,069 parts against 2,249), and its mend
takes 3 parts out and checks again where `main`'s passes at once. On the 48-stud scans the stitch
runs out of its 96 rounds on `main` and on the branch alike.

**What the numbers say.**
1. **The colours read as the model's.** Spot's patches are black where they
   were Reddish Brown; the figure's hair black where it was Dark Blue; the
   milk truck's white side white, with its logo, where it was black. The
   colour target, 1.3 times the floor at 48 studs, is met: 1.28.
2. **A slope's colour helps, but smooth is not yet level with plain at 48
   studs**: 9.5 against 9.0 (0.5 apart, from 0.8). At 24 they are level.
3. **Neutral stays neutral on Spot, not yet on the figure**: 8% of its
   neutral surface at 48 studs and 18% at 24 is laid in a colour; in the
   pictures, the top of its hair is in the skin's Dark Orange.
4. **Every part is one the LEGO Group sells in that colour.** The cost shows on the
   uncoloured models: a part not sold in Light Bluish Grey (on `main` the
   commonest was the 3 x 3 brick without corner, 30505, 132 of them) is laid
   in the nearest colour it is sold in, Dark Bluish Grey, so the grey Stanford
   bunny has a few dark corners.
5. **Finer colour costs a little wholeness.** A thin part in more colours
   than one is laid in more parts that hold each other less: the Bell X-1 at
   48 studs lost its undercarriage (53 parts nothing could hold up, lost95
   10.4 studs) and stands on a stand; the tholos at 24 lost 72 parts (2.1).
   The tholos at 48 is now whole (from 2.43). Smooth whole: 24 of 28, from
   25; plain 25, from 27.
6. **Time is not back.** The lay is faster and the scans' seconds are lower,
   but the same-batch measure of the bunny is 12% slower, all of it the
   second check.

Spot at 48 studs (Keenan Crane, CC0):

![Spot at 48 studs: the model, then Brickify smooth before and after](brickify/unit2-spot-48.jpg)

The Kenney figure at 48 studs (CC0): the hair black, its top still the
skin's colour.

![The figure at 48 studs: the model, then smooth before and after](brickify/unit2-character-48.jpg)

The milk truck at 24 studs (Cesium, CC-BY 4.0): its white side was black.

![The milk truck at 24 studs: the model, then smooth before and after](brickify/unit2-milk-truck-24.jpg)

The Bell X-1 at 48 studs (Smithsonian, CC0): its undercarriage is gone.

![The Bell X-1 at 48 studs: the model, then smooth before and after](brickify/unit2-smithsonian-2-48.jpg)

### Proof

- `brickify_probe` (headless): all 57 checks pass, with a new section,
  colour that reads right: CIEDE2000 against Sharma, Wu and Dalal's test
  pair (2.0425); the greys from black to white matched to Black, Dark Bluish
  Grey, Light Bluish Grey and White and nothing else; every part of the
  28-stud bunny with an element number. The hollow sphere is 1,599 parts
  against the solid's 1,606.
- `brickify_ui_probe` (in a window, on the GPU), `shapes_probe`,
  `exact_probe` (29 passed) and `patterns_probe`: all pass.
- `tools/web/brickify_flow.mjs` needs a preview, and was not run.

### What is left

- **The figure's hair top**, laid in the skin's colour, and the neutral
  surfaces of the Bell X-1 and the toy car still laid in a colour.
- **Wholeness with finer colour**: lay a thin part in one colour, or let a
  plate reach across a colour edge where that holds the part, before the
  mend takes it out (the X-1 at 48, the tholos at 24).
- **Smooth level with plain**: the tiles and wedges still show the colour of
  their cell, not of the face they show.
- **Time**: the bunny's second check, and the rejoin's piece counts (each
  try counts the whole plan's pieces).
- **Dithering on flat panels** was not tried.

## Repeat it

The models are not in the repository (two are Stanford's, for research use
only). `LICENCE.json` beside each records its source and licence; the table
in "The models" lists them.

```sh
S=<a scratch folder>; W=<this checkout>
uv venv -p /usr/bin/python3.12 $S/venv && VIRTUAL_ENV=$S/venv uv pip install numpy scipy trimesh embreex pillow
# each model in $S/models/<slug>/ with a LICENCE.json ("files": [the model first, then what it names])
$S/venv/bin/python -I $W/tools/bench/brickify_bench.py prepare --models $S/models --into $S/prepared
cd $W && XDG_DATA_HOME=$W/.scratch-data heavy godot --headless --path $W \
    --script src/dev/brickify_bench.gd -- $S/prepared/jobs.json $S/run
# legolization, its own venv and a scratch HOME (GPL-3.0; run, never imported):
uv venv -p /usr/bin/python3.12 $S/outside/venv && VIRTUAL_ENV=$S/outside/venv uv pip install legolization==0.5.0
#   unpack vendor/complete.zip into $S/outside/home/.cache/pyldraw3/complete, add ldraw/parts.lst and a
#   lowercase ldconfig.ldr, then `HOME=$S/outside/home ldraw generate --yes`
#   this run gave it 24 studs only ("sizes": [24] in a copy of jobs.json) and 30 minutes a model:
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py outside $S/run --jobs $S/outside.json \
    --tool $S/outside/venv/bin/legolization --home $S/outside/home --timeout 1800
#   outside.json now names each outside.mpd; with "arms": [] on each model the Godot run checks only those:
XDG_DATA_HOME=$W/.scratch-data heavy godot --headless --path $W --script src/dev/brickify_bench.gd -- $S/outside.json $S/run
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py measure $S/run
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py pictures $S/run --into $S/pictures
python3 tools/bench/brickify_bench.py report $S/run
# a change measured (unit 2): main laid in its own checkout ($S/main) and the branch in another,
# each half of the models a process ("sizes" and "arms" per model in the jobs file), then
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py pictures $S/after --into $S/pictures \
    --arms smooth --before $S/main
# where the time goes, main's beside the branch's in one heavy job (only the ratio means anything):
XDG_DATA_HOME=$W/.scratch-data heavy godot --headless --path $W --script src/dev/brickify_phases.gd -- 3
```

The run behind sections 3 and 4 used the app at `7a55e86` (main), on
2026-10-15, the box shared with other jobs at a load of 20 to 60 on 24
threads; section 6's, `2789cd0` and the branch on 2026-10-16, at a load of
10 to 60.

## Each model, every arm

As section 3 measures them. *Coverage* is Brickify's own figure, the share of the measured studs and plates inside a part; it has none for an outside build. *Lost95* and *Added95* are the 95th percentiles, in studs, of the model's surface from the build's and the build's from the model's. legolization ran at 24 studs only, and its time is its whole run.


| Model | Studs | Arm | Parts | Coverage | Shaped | IoU | Chamfer | Lost95 | Added95 | Normal (°) | ΔE2000 | Check | Pieces | Seams bridged | Seconds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| armadillo | 24 | smooth | 493 | 88% | 29% | 0.758 | 0.47 | 4.04 | 0.55 | 49.5 | — | passes | 1 | 49% | 4.1 |
| armadillo | 24 | plain | 317 | 89% | 0% | 0.776 | 0.43 | 3.27 | 0.52 | 49.7 | — | passes | 1 | 53% | 2.8 |
| armadillo | 24 | greedy | 187 | 95% | 0% | 0.848 | 0.22 | 0.44 | 0.56 | 49.4 | — | 140 problems (floating 140) | 17 | 52% | 0.0 |
| armadillo | 48 | smooth | 2,686 | 99% | 29% | 0.912 | 0.24 | 0.50 | 0.53 | 44.2 | — | passes | 1 | 49% | 26.0 |
| armadillo | 48 | plain | 1,903 | 99% | 0% | 0.925 | 0.20 | 0.38 | 0.48 | 45.1 | — | passes | 1 | 60% | 12.3 |
| armadillo | 48 | greedy | 1,034 | 97% | 0% | 0.918 | 0.23 | 0.40 | 0.59 | 47.0 | — | 115 problems (floating 115) | 34 | 53% | 0.1 |
| avocado | 24 | smooth | 829 | 96% | 20% | 0.908 | 0.27 | 0.73 | 0.63 | 39.0 | 18.5 | passes | 1 | 32% | 6.6 |
| avocado | 24 | plain | 685 | 96% | 0% | 0.901 | 0.30 | 0.73 | 0.57 | 37.4 | 18.5 | passes | 1 | 34% | 4.1 |
| avocado | 24 | greedy | 330 | 98% | 0% | 0.911 | 0.28 | 0.47 | 0.56 | 38.9 | 17.4 | 24 problems (floating 24) | 4 | 55% | 0.0 |
| avocado | 24 | outside | 917 | — | 12% | 0.811 | 0.54 | 0.68 | 1.09 | 35.9 | 16.1 | passes | 1 | 42% | 1150.9 |
| avocado | 48 | smooth | 4,514 | 100% | 16% | 0.959 | 0.20 | 0.40 | 0.50 | 35.4 | 9.1 | passes | 1 | 34% | 26.2 |
| avocado | 48 | plain | 3,817 | 100% | 0% | 0.964 | 0.17 | 0.32 | 0.47 | 34.6 | 8.8 | passes | 1 | 35% | 17.4 |
| avocado | 48 | greedy | 1,867 | 99% | 0% | 0.959 | 0.19 | 0.36 | 0.57 | 35.5 | 9.0 | 22 problems (floating 22) | 7 | 49% | 0.2 |
| benchy | 24 | smooth | 467 | 93% | 32% | 0.864 | 0.27 | 1.13 | 0.54 | 37.2 | — | passes | 1 | 50% | 2.5 |
| benchy | 24 | plain | 369 | 97% | 0% | 0.902 | 0.21 | 0.63 | 0.49 | 38.3 | — | passes | 1 | 50% | 2.6 |
| benchy | 24 | greedy | 187 | 95% | 0% | 0.897 | 0.23 | 0.49 | 0.61 | 38.5 | — | 51 problems (floating 51) | 15 | 49% | 0.0 |
| benchy | 24 | outside | 1,304 | — | 19% | 0.809 | 0.48 | 0.75 | 1.11 | 37.7 | — | passes | 1 | 49% | 1030.0 |
| benchy | 48 | smooth | 2,782 | 100% | 33% | 0.961 | 0.21 | 0.43 | 0.56 | 35.0 | — | passes | 1 | 49% | 10.9 |
| benchy | 48 | plain | 1,799 | 100% | 0% | 0.962 | 0.20 | 0.39 | 0.49 | 35.1 | — | passes | 1 | 55% | 4.9 |
| benchy | 48 | greedy | 973 | 97% | 0% | 0.956 | 0.25 | 0.44 | 0.62 | 35.8 | — | 73 problems (floating 73) | 19 | 64% | 0.1 |
| bob | 24 | smooth | 910 | 97% | 25% | 0.913 | 0.21 | 0.42 | 0.53 | 42.9 | 13.2 | passes | 1 | 37% | 3.5 |
| bob | 24 | plain | 730 | 97% | 0% | 0.909 | 0.21 | 0.43 | 0.51 | 47.5 | 10.9 | passes | 1 | 40% | 1.4 |
| bob | 24 | greedy | 311 | 97% | 0% | 0.900 | 0.21 | 0.35 | 0.65 | 48.6 | 11.9 | 12 problems (floating 12) | 7 | 55% | 0.0 |
| bob | 24 | outside | 1,212 | — | 19% | 0.799 | 0.46 | 0.66 | 1.11 | 42.3 | 10.9 | passes | 1 | 44% | 460.1 |
| bob | 48 | smooth | 4,029 | 100% | 22% | 0.954 | 0.20 | 0.35 | 0.55 | 40.9 | 11.4 | passes | 1 | 43% | 27.5 |
| bob | 48 | plain | 3,487 | 100% | 0% | 0.958 | 0.18 | 0.31 | 0.49 | 46.0 | 7.2 | passes | 1 | 46% | 8.6 |
| bob | 48 | greedy | 1,506 | 98% | 0% | 0.946 | 0.23 | 0.37 | 0.66 | 47.4 | 8.3 | 19 problems (floating 19) | 6 | 62% | 0.1 |
| character | 24 | smooth | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 1.9 |
| character | 24 | plain | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 0.9 |
| character | 24 | greedy | 144 | 92% | 0% | 0.734 | 0.58 | 4.48 | 0.93 | 43.4 | 19.9 | 144 problems (floating 144) | 21 | 44% | 0.0 |
| character | 48 | smooth | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 16.9 |
| character | 48 | plain | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 9.4 |
| character | 48 | greedy | 801 | 93% | 0% | 0.791 | 0.99 | 9.01 | 1.90 | 39.9 | 18.8 | 801 problems (floating 801) | 43 | 46% | 0.1 |
| fox | 24 | smooth | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 0.4 |
| fox | 24 | plain | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 0.2 |
| fox | 24 | greedy | 45 | 94% | 0% | 0.760 | 0.35 | 1.94 | 0.62 | 47.1 | 9.7 | 45 problems (floating 45) | 5 | 39% | 0.0 |
| fox | 24 | outside | 478 | — | 25% | 0.624 | 0.56 | 0.87 | 1.30 | 46.0 | 8.5 | passes | 1 | 37% | 125.5 |
| fox | 48 | smooth | 2 | 0% | 0% | 0.006 | 8.87 | 31.63 | 0.48 | 62.1 | 38.7 | passes | 1 | 100% | 2.8 |
| fox | 48 | plain | 2 | 0% | 0% | 0.006 | 8.87 | 31.63 | 0.48 | 62.1 | 38.7 | passes | 1 | 100% | 1.1 |
| fox | 48 | greedy | 294 | 95% | 0% | 0.878 | 0.26 | 0.46 | 0.60 | 38.9 | 6.0 | 292 problems (floating 292) | 13 | 61% | 0.1 |
| milk-truck | 24 | smooth | 768 | 98% | 16% | 0.914 | 0.24 | 0.91 | 0.45 | 21.7 | 26.1 | passes | 1 | 40% | 4.7 |
| milk-truck | 24 | plain | 719 | 99% | 0% | 0.910 | 0.28 | 0.51 | 0.45 | 18.0 | 25.9 | passes | 1 | 37% | 3.8 |
| milk-truck | 24 | greedy | 279 | 92% | 0% | 0.901 | 0.35 | 0.60 | 0.73 | 17.8 | 36.8 | 5 problems (floating 5) | 8 | 46% | 0.0 |
| milk-truck | 48 | smooth | 4,261 | 100% | 18% | 0.963 | 0.25 | 0.56 | 0.66 | 17.7 | 12.3 | passes | 1 | 43% | 29.4 |
| milk-truck | 48 | plain | 3,486 | 100% | 0% | 0.966 | 0.23 | 0.41 | 0.45 | 15.1 | 11.6 | passes | 1 | 44% | 7.8 |
| milk-truck | 48 | greedy | 1,890 | 98% | 0% | 0.966 | 0.24 | 0.41 | 0.58 | 19.2 | 12.1 | 11 problems (floating 11) | 11 | 67% | 0.1 |
| objaverse | 24 | smooth | 970 | 84% | 22% | 0.726 | 0.90 | 6.48 | 1.00 | 39.6 | 18.9 | passes | 1 | 39% | 7.6 |
| objaverse | 24 | plain | 992 | 93% | 0% | 0.778 | 0.76 | 5.99 | 1.00 | 40.6 | 18.0 | passes | 1 | 40% | 3.7 |
| objaverse | 24 | greedy | 410 | 96% | 0% | 0.799 | 0.66 | 4.85 | 1.10 | 44.6 | 20.7 | 53 problems (floating 53) | 71 | 35% | 0.0 |
| objaverse | 48 | smooth | 4,962 | 67% | 18% | 0.717 | 2.00 | 13.92 | 1.78 | 38.5 | 17.8 | passes | 1 | 38% | 159.2 |
| objaverse | 48 | plain | 4,003 | 65% | 0% | 0.671 | 2.08 | 13.97 | 1.96 | 43.2 | 18.1 | passes | 1 | 41% | 127.2 |
| objaverse | 48 | greedy | 3,165 | 94% | 0% | 0.877 | 0.79 | 6.82 | 2.07 | 40.1 | 18.7 | 1105 problems (floating 1105) | 330 | 46% | 0.1 |
| smithsonian-1 | 24 | smooth | 407 | 37% | 13% | 0.522 | 1.74 | 11.29 | 1.38 | 51.5 | 18.7 | passes | 1 | 31% | 5.0 |
| smithsonian-1 | 24 | plain | 868 | 75% | 0% | 0.888 | 0.32 | 1.10 | 1.00 | 44.1 | 15.9 | passes | 1 | 29% | 2.0 |
| smithsonian-1 | 24 | greedy | 414 | 91% | 0% | 0.914 | 0.22 | 0.41 | 0.59 | 46.8 | 10.8 | 314 problems (floating 314) | 80 | 26% | 0.0 |
| smithsonian-1 | 48 | smooth | 7,713 | 99% | 11% | 0.961 | 0.21 | 0.40 | 0.51 | 42.1 | 7.4 | passes | 1 | 26% | 26.6 |
| smithsonian-1 | 48 | plain | 7,345 | 100% | 0% | 0.960 | 0.19 | 0.36 | 0.47 | 43.4 | 7.2 | passes | 1 | 26% | 70.8 |
| smithsonian-1 | 48 | greedy | 2,482 | 95% | 0% | 0.955 | 0.23 | 0.40 | 0.60 | 44.7 | 7.6 | 40 problems (floating 40) | 37 | 51% | 0.3 |
| smithsonian-2 | 24 | smooth | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 1.9 |
| smithsonian-2 | 24 | plain | 0 | 0% | 0% | — | — | — | — | — | — | nothing laid | 0 | — | 1.8 |
| smithsonian-2 | 24 | greedy | 19 | 95% | 0% | 0.666 | 0.40 | 2.37 | 0.63 | 60.9 | 10.3 | 10 problems (floating 10) | 11 | 32% | 0.0 |
| smithsonian-2 | 24 | outside | 328 | — | 27% | 0.616 | 0.36 | 0.65 | 1.10 | 36.8 | 8.6 | passes | 46 | 41% | 279.2 |
| smithsonian-2 | 48 | smooth | 405 | 93% | 34% | 0.565 | 1.61 | 13.34 | 0.50 | 58.7 | 10.1 | passes | 1 | 44% | 3.8 |
| smithsonian-2 | 48 | plain | 315 | 93% | 0% | 0.565 | 1.61 | 13.50 | 0.44 | 60.9 | 9.5 | passes | 1 | 54% | 2.6 |
| smithsonian-2 | 48 | greedy | 125 | 87% | 0% | 0.561 | 1.65 | 13.50 | 0.63 | 62.3 | 9.8 | 20 problems (floating 20) | 3 | 56% | 0.0 |
| spot | 24 | smooth | 1,005 | 100% | 22% | 0.930 | 0.18 | 0.35 | 0.49 | 38.3 | 11.6 | passes | 1 | 41% | 4.0 |
| spot | 24 | plain | 755 | 100% | 0% | 0.925 | 0.19 | 0.35 | 0.46 | 39.8 | 10.0 | passes | 1 | 46% | 1.0 |
| spot | 24 | greedy | 330 | 97% | 0% | 0.909 | 0.22 | 0.38 | 0.60 | 41.2 | 11.1 | 11 problems (floating 11) | 8 | 69% | 0.0 |
| spot | 24 | outside | 1,171 | — | 10% | 0.814 | 0.49 | 0.75 | 1.17 | 39.6 | 9.1 | passes | 1 | 52% | 623.0 |
| spot | 48 | smooth | 4,787 | 100% | 22% | 0.954 | 0.22 | 0.39 | 0.54 | 39.8 | 10.2 | passes | 1 | 46% | 27.6 |
| spot | 48 | plain | 3,664 | 100% | 0% | 0.955 | 0.20 | 0.36 | 0.48 | 41.2 | 9.1 | passes | 1 | 53% | 20.2 |
| spot | 48 | greedy | 1,802 | 98% | 0% | 0.948 | 0.24 | 0.39 | 0.61 | 42.6 | 9.7 | 8 problems (floating 8) | 5 | 60% | 0.2 |
| stanford-bunny | 24 | smooth | 985 | 98% | 32% | 0.887 | 0.29 | 1.59 | 0.54 | 44.7 | — | passes | 1 | 46% | 4.7 |
| stanford-bunny | 24 | plain | 654 | 99% | 0% | 0.923 | 0.20 | 0.38 | 0.48 | 45.4 | — | passes | 1 | 59% | 1.2 |
| stanford-bunny | 24 | greedy | 341 | 97% | 0% | 0.913 | 0.24 | 0.41 | 0.62 | 47.2 | — | 19 problems (floating 19) | 19 | 61% | 0.0 |
| stanford-bunny | 24 | outside | 1,658 | — | 21% | 0.814 | 0.52 | 0.76 | 1.25 | 42.3 | — | passes | 1 | 35% | 947.9 |
| stanford-bunny | 48 | smooth | 4,887 | 100% | 28% | 0.959 | 0.22 | 0.39 | 0.58 | 41.6 | — | passes | 1 | 53% | 22.3 |
| stanford-bunny | 48 | plain | 3,451 | 100% | 0% | 0.964 | 0.20 | 0.35 | 0.51 | 43.1 | — | passes | 1 | 66% | 19.1 |
| stanford-bunny | 48 | greedy | 2,208 | 98% | 0% | 0.957 | 0.25 | 0.40 | 0.64 | 47.1 | — | 115 problems (floating 115) | 25 | 56% | 0.2 |
| toy-car | 24 | smooth | 444 | 73% | 27% | 0.705 | 0.97 | 4.95 | 2.62 | 45.5 | 24.4 | passes | 1 | 36% | 7.0 |
| toy-car | 24 | plain | 485 | 97% | 0% | 0.825 | 0.56 | 1.96 | 2.49 | 44.7 | 22.0 | passes | 1 | 32% | 5.8 |
| toy-car | 24 | greedy | 204 | 95% | 0% | 0.827 | 0.59 | 2.27 | 2.48 | 43.3 | 22.0 | passes | 5 | 48% | 0.0 |
| toy-car | 24 | outside | 724 | — | 23% | 0.801 | 0.39 | 0.62 | 1.14 | 34.9 | 17.1 | passes | 46 | 32% | 1535.8 |
| toy-car | 48 | smooth | 2,745 | 98% | 24% | 0.851 | 0.99 | 4.13 | 5.16 | 37.5 | 21.6 | passes | 1 | 37% | 54.0 |
| toy-car | 48 | plain | 2,155 | 98% | 0% | 0.844 | 0.99 | 4.02 | 4.95 | 38.5 | 20.7 | passes | 1 | 39% | 15.1 |
| toy-car | 48 | greedy | 1,025 | 97% | 0% | 0.846 | 1.00 | 3.85 | 4.94 | 40.8 | 20.3 | 27 problems (floating 27) | 23 | 54% | 0.0 |
| utah-teapot | 24 | smooth | 607 | 98% | 30% | 0.891 | 0.25 | 1.20 | 0.58 | 46.7 | — | passes | 1 | 46% | 1.7 |
| utah-teapot | 24 | plain | 383 | 98% | 0% | 0.890 | 0.24 | 0.96 | 0.55 | 49.0 | — | passes | 1 | 59% | 0.4 |
| utah-teapot | 24 | greedy | 201 | 98% | 0% | 0.894 | 0.22 | 0.39 | 0.64 | 48.2 | — | 41 problems (floating 41) | 17 | 37% | 0.0 |
| utah-teapot | 24 | outside | 769 | — | 27% | 0.790 | 0.47 | 0.69 | 1.13 | 41.1 | — | passes | 1 | 42% | 201.3 |
| utah-teapot | 48 | smooth | 3,310 | 99% | 33% | 0.923 | 0.30 | 0.70 | 0.59 | 43.9 | — | passes | 1 | 38% | 16.7 |
| utah-teapot | 48 | plain | 2,117 | 99% | 0% | 0.921 | 0.27 | 0.55 | 0.53 | 46.2 | — | passes | 1 | 56% | 6.3 |
| utah-teapot | 48 | greedy | 1,212 | 98% | 0% | 0.931 | 0.25 | 0.43 | 0.68 | 49.4 | — | 180 problems (floating 180) | 31 | 34% | 0.1 |

## Sources

All read on 2026-10-15.

**Tools**

[st-sculpture]: https://studiohelp.bricklink.com/hc/en-us/articles/6508264220183
[nieman]: https://niemansculpt.redwoodlug.org/
[nieman-guide]: https://niemansculpt.redwoodlug.org/using-niemansculpt/
[nieman-dl]: https://niemansculpt.redwoodlug.org/download
[bricker]: https://superhivemarket.com/products/bricker
[bricker-docs]: https://superhivemarket.com/products/bricker/docs
[bricker-ratings]: https://superhivemarket.com/products/bricker/ratings
[mecalizer]: https://www.mecabricks.com/en/shop/product/7
[lz]: https://github.com/hbmartin/legolization
[bricksolvr]: https://bricksolvr.com/
[drububu]: https://drububu.com/miscellaneous/legolizer/index.html
[lsculpt]: https://wiki.ldraw.org/wiki/LSculpt
[bmw]: https://apps.apple.com/us/app/brick-my-world/id6739494216
[fabrickation]: https://hpi.de/baudisch/projects/fabrickation.html
[hpi]: https://github.com/ad-si/Brickify
[lego-gen]: https://superhivemarket.com/products/lego-generator-
[tripo-node]: https://comfy.icu/node/TripoStylizeModel
[img2lego]: https://github.com/giorgioguttilla/img2lego
[brickalize]: https://github.com/CreativeMindstorms/brickalize
[brickr-qt]: https://github.com/Daekkyn/brickr
[cv2ldr]: https://github.com/pennyforge/ColouredVoxels2LDR
[mosaic40179]: https://www.lego.com/en-us/product/40179
[o2s]: https://github.com/LucasDower/ObjToSchematic
[o2s2]: https://objtoschematic.com/
[bricker-builds]: https://brickerbuilds.com/

**Research**

[gower]: https://miis.maths.ox.ac.uk/623/1/LegoModelAutomation.pdf
[testuz]: https://infoscience.epfl.ch/record/189856/files/lego.pdf
[luo]: https://history.siggraph.org/?p=210389
[luo-slides]: https://www.slideshare.net/slideshow/legolization-optimizing-lego-designs-siggraph-asia-2015/54893421
[kollsker]: https://orbit.dtu.dk/en/publications/c51c9ca2-06d0-4f73-9c3c-3641f1e12124
[zhou]: https://staff.ustc.edu.cn/~xjchen99/2019cgf-lego-zhou.pdf
[ljubic]: https://lgm.fri.uni-lj.si/wp-content/uploads/2025/09/244517379.pdf
[lambrecht]: https://lego.bldesign.org/LSculpt/lambrecht_legovoxels.pdf
[image2lego]: https://ar5iv.labs.arxiv.org/html/2108.08477
[stablelego]: https://arxiv.org/html/2402.10711
[bgpt]: https://arxiv.org/html/2505.05469
[legoace]: https://huggingface.co/VAST-AI/LegoACE
[stable]: https://arxiv.org/html/2605.06947
[banything]: https://arxiv.org/html/2605.26182
[resem]: https://arxiv.org/html/2608.09597v1
[legomaker]: https://api.crossref.org/works/10.1145%2F3763285
[bbh]: https://brickbuildershandbook.com/all-about-lego-sculptures/

**Techniques**

[lego-illegal]: https://www.lego.com/en-us/service/help-topics/article/using-illegal-building-techniques-in-lego-ideas-challenges
[berard]: http://bramlambrecht.com/tmp/jamieberard-brickstress-bf06.pdf
[bn-illegal]: https://bricknerd.com/home/illegal-snot-stressful-techniques-for-sideways-building-9-7-23
[bn-math]: https://bricknerd.com/home/hidden-math-the-numbers-that-make-lego-work-6-10-22
[ba-snot]: https://brickarchitect.com/parts/category-3
[ward]: https://www.brickpile.com/wp-content/uploads/2018/07/brick-geometry-bbtb2018.pdf
[stonewars-t]: https://stonewars.com/news/illegal-building-technique-lego-ford-model-t/

**Builders**

[arctic]: https://arctic-shift.photon-reddit.com/
[r-house]: https://www.reddit.com/r/lego/comments/1k4dorw/
[r-parts]: https://www.reddit.com/r/lego/comments/1ja5uj1/
[r-legofy]: https://www.reddit.com/r/lego/comments/1bzndq2/
[r-brickify]: https://www.reddit.com/r/DigitalLego/comments/1qkloni/
[r-brickformer]: https://www.reddit.com/r/lego/comments/1llpnhh/
[r-plates]: https://www.reddit.com/r/DigitalLego/comments/1soz4so/
[r-seams]: https://www.reddit.com/r/DigitalLego/comments/1w8doc3/
[r-illegal]: https://www.reddit.com/r/lego/comments/1rqjklv/
[r-illegal2]: https://www.reddit.com/r/lego/comments/1s0et9w/
[hn-legogpt]: https://news.ycombinator.com/item?id=43933891
[hn-legogpt-c]: https://news.ycombinator.com/item?id=43934427
[hn-image2lego]: https://news.ycombinator.com/item?id=28273015
[hn-brickit1]: https://news.ycombinator.com/item?id=27693560
[hn-brickit2]: https://news.ycombinator.com/item?id=32796324
[hn-conv]: https://news.ycombinator.com/item?id=19299861
[hn-onhand]: https://news.ycombinator.com/item?id=49938598
[vice-legoizer]: https://www.vice.com/en/article/make-any-image-into-lego-art-with-the-legoizer/

**Models**

[m-stanford]: http://graphics.stanford.edu/data/3Dscanrep/
[m-teapot]: https://github.com/alecjacobson/common-3d-test-models
[m-crane]: https://www.cs.cmu.edu/~kmcrane/Projects/ModelRepository/
[m-fox]: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox
[m-truck]: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CesiumMilkTruck
[m-toycar]: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/ToyCar
[m-avocado]: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Avocado
[m-kenney]: https://kenney.nl/assets/mini-characters
[m-hayes]: https://npg.si.edu/object/npg_NPG.76.27
[m-x1]: https://airandspace.si.edu/collection-objects/bell-x-1/nasm_A19510007000
[m-benchy]: https://www.3dbenchy.com/license/
[m-tholos]: https://sketchfab.com/3d-models/greek-tholos-b4fbe06384ba439e93643fc8818e5da4
