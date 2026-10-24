# Brickworks against the field

Written 2026-10-12 against `next3` at `dc413fe`: what has shipped to
brickworks.diy plus what is about to. It covers BrickLink Studio 2.26,
Mecabricks, LEGO Digital Designer (retired), LeoCAD, LDCad, Bricksmith, the
web and mobile tools around them (LEGO Builder, BrickHub, Brickit,
Rebrickable) and AI brick design in research and in products.

**What it is for.** The owner wants Brickworks to be the most advanced LEGO
CAD and the best AI LEGO designer. This file says where that is already true,
where it is not, and what to build next. `docs/ROADMAP.md` stays the plan for
the designer's model quality; this file is the view from outside.

**How it was made.**
- Every competitor claim links a source in [Sources](#sources): official
  help pages, release notes, papers, store listings, and forum threads where
  people complain.
- Every Brickworks claim links the recipe in `.claude/skills/verify/` or the
  source file that does it.
- A cell marked *unverified* rests on a search summary rather than a page
  read in full. Rebrickable's pages refuse automated readers, so its rows
  are search summaries of its own help pages. "Not found" means a search
  turned up nothing, which is weaker than "does not exist".

**Still in progress, not counted here:** floor options, progress bars, the
design benchmark and retrieving techniques from real sets. They are being
built in other worktrees and are not on `next3`.

## In one page

**Where Brickworks leads today**

1. **An AI designer inside a CAD.**
   - No CAD surveyed ships generative design. Studio's Sculpture and Mosaic
     are rule-based converters [st-sculpture]. No AI was found in LeoCAD
     26.09, Mecabricks, LDCad or Bricksmith [lc-2609].
   - The research systems either build boxes on a 20³ grid (BrickGPT
     [bgpt-paper]) or run outside any editor (BrickAgent [brickagent]).
   - Brickworks designs from a sentence or a picture in real parts. It checks
     every brick, details each named assembly against real sets, and leaves an
     editable model with a booklet and an orderable parts list. People can use
     their own Claude plan through the connector or MCP ([assistant], [mcp]).
2. **Checks while you build.**
   - Positions are integers on a 2 LDU lattice. A part a fraction of a stud
     off is a fault ([geometry]).
   - Clutch, levers and slender loads are checked per joint
     ([stability.gd]). Weight and "stands up" are on the status bar all the
     time.
   - Each part's real colours are marked on the palette ([parts]).
   - Studio's stability check calls itself "very conservative" and "often
     flags parts that are actually well connected" [st-stab].
   - Mecabricks, LeoCAD and LDCad check no physics at all [mb-collision]
     [collision-2016] [ld-collide].
3. **One app on every platform.** The same build runs in a browser, on a
   phone and on Linux, macOS and Windows ([web], [release]). Studio is
   Windows and Mac only [st-platform] and LDD is gone [ldd-end]. Mecabricks
   is browser-only by choice [mb-online]. LDCad and Bricksmith each cover one
   or two desktops [ld-download] [bs-home].
4. **Very big models.**
   - 200,000 bricks draw in 14 draw calls at 131 fps on an M3 Max
     ([README]). Nothing is drawn while the model stands still ([view]).
   - Build order for 8,603 parts takes 5 s ([view]).
   - LDD crawled at 6,000 parts [ldd-big]. A ~17,000-brick Mecabricks render
     failed [mb-eb9]. Studio warns that collision detection "can take a lot
     of resources" on large designs [st-collide].
5. **Making parts in the app.**
   - Bricks, plates, tiles, slopes, rounds, brackets and Technic bricks at
     any size, or any part changed ([elements]).
   - Prints painted or brought in as pictures, stickers with a true-size PDF
     sheet ([prints]), and minifigure moulds sculpted ([minifig]).
   - Studio needs PartDesigner, a separate app, which decorates 28 parts
     [st-pd] [st-pd-decal]. Mecabricks refuses custom shapes
     [mb-nocustom].
6. **Breadth in one place.** Flexible parts laid by their ends, posing with
   keyframes, LEGO Art plans, brickify from OBJ/STL/glTF, and a collection
   with stand-ins and "what can I build" ([view], [brickify], [collection]).

**Where it trails today** (candidly, most of this is Studio):

1. **Instructions you can author.**
   - Studio has a Step Editor, Page Design, PDF and PNG export, and new-part
     highlighting [st-im] [st-stepedit] [st-im-export]. LeoCAD's timeline
     moves parts between steps [lc-history].
   - Brickworks generates a booklet whose steps can be built as drawn, keeps
     the steps a file already had, and lets a person end a step (E), move a
     part to another step, merge, split and reorder steps, and set how each
     is printed: turned, tilted, zoomed, larger or smaller, a new page or a
     page alone, its parts list off, a callout or pages of its own, steps a
     page. A turn is saved as LDraw's ROTSTEP. It prints to PDF, A4 or
     letter. What Studio has that it lacks: dragging a picture, a callout or
     a parts list to a place on the page, a page's own layout, text and
     pictures added to a page, and new-part highlighting ([view] [cadtask]).
2. **Rendering.**
   - Studio's Eyesight is a Cycles path tracer with a POV-Ray/LGEO option
     [st-eyesight] [st-pov]. Mecabricks has a render farm and a Blender
     add-on [mb-farm] [mb-addon]. LeoCAD hands off to POV-Ray or Blender
     [lc-history].
   - Brickworks' Render is raster accumulation (SDFGI, SSAO, soft shadows,
     64 jittered frames). It is good, but it is not a path tracer
     ([view]).
3. **Working together and being seen.**
   - Studio has Build Together, live co-editing over LAN or a relay
     [st-bt], and a moderated Gallery [st-gallery].
   - Mecabricks has a public library with an embed [mb-model], and
     Rebrickable has more than 200,000 MOCs [rb-wiki].
   - Brickworks has share links, a public gallery with remixing, likes and
     moderation, and people's pages and lists ([web]); and Build together,
     two people editing one model live by a link, in a browser or the
     desktop, each Undo their own, the model byte-identical on every side
     once nothing is on its way ([together], 2026-10-24). A link keeps its versions: publishing again keeps the old one
     at `/m/<id>/v/<n>`, says what changed by part and step, and keeps a
     builder's place when the steps they built did not change ([web]).
4. **Buying the parts.**
   - Studio shows BrickLink Price Guide prices and puts a model on a wanted
     list in one click [st-price] [st-wanted].
   - Brickworks writes the XML and links each part's page. BrickLink's
     prices need a seller's API keys ([collection]).
5. **Studio's own parts.** A Studio-only part (`bl_…`, PartDesigner) is
   left out on open. Brickworks' `.io` export has never been seen opening in
   Studio ([model-io], `CHANGELOG.md`).
6. **Learning and trust.**
   - Studio opens with an interactive tutorial and has official videos
     [st-tutorial] [st-video]. LeoCAD and LDCad have documentation sites
     [lc-docs] [ld-docs]. Brickworks has an eight-card tour ([building]).
   - Brickworks is 0.2.0, released yesterday, with unsigned desktop builds.
     It asks for an email sign-in before anything can be seen, which was the
     owner's decision in `HANDOFF.md`.
   - Studio has years of users, and Mecabricks' embed has existed since 2013
     [mb-eb4].
7. **3D export.**
   - Studio writes `.dae` and POV-Ray [st-export]. Mecabricks writes OBJ,
     DAE and STL [mb-farm]. LeoCAD writes OBJ, 3DS and COLLADA [lc-history],
     and LDCad writes glTF2 [ld-17b1].
   - Brickworks writes GLB, glTF, OBJ with its MTL, and STL at real size,
     every part a node in its sub-model ([model-io]).
8. **Flexible parts, at the top end.** LDCad's path and spring system shapes
   rubber bands round circles and builds shock absorbers. It maps a path's
   length to a real part number [ld-meta]. Brickworks lays seven kinds
   along a path and has no rubber bands or springs ([geometry]).
9. **The AI is unproven outside our own ruler.**
   - BrickBench, released four days ago, is the first public measure of
     exactly what Brickworks does. Brickworks has not been run on it
     [bb-paper].
   - By our own ruler (`docs/ROADMAP.md`), designs are still thinner than
     real sets: castle run 24 has 121 shapes and 13 colours, where a set of
     2,400 parts has 262 and 28.
   - A small house costs 11 minutes and $2.40 at high effort
     (`HANDOFF.md`).

**Level with everyone:** accessibility. No tool surveyed shows evidence of
work on it, and Brickworks has none either (item 14).

## The matrix

### LEGO CAD tools

Versions are the latest found:
- Studio 2.26.9_1 (30 Sep 2026) [st-rn]
- LeoCAD 26.09 (20 Sep 2026) [lc-2609]
- LDCad 1.7 beta 2b (Mar 2026; the last stable release is 1.6d2, 2022)
  [ld-download]
- Bricksmith 3.1 (Feb 2022) [bs-files]
- LDD 4.3.12 (2019; downloads ended 2022) [ldd-wiki]
- Mecabricks has no version numbers. Its Blender add-on was updated in Sept
  2025 [mb-addon], and most of its documentation is Brickset's 2020 series.

| | BrickLink Studio | Mecabricks | LDD (retired) | LeoCAD | LDCad | Bricksmith | Brickworks |
|---|---|---|---|---|---|---|---|
| **Modelling, snapping, connections** | connectors snap and turn the part to fit; a Connect tool; hinge detection; a rotate gizmo; collision optional [st-snap] [st-connect] [st-rotate] [st-collide] | snap by hand: hover, press S, click a point on each part; slower than LDD or Studio, users say [mb-brickset-build] | auto-connect, no overlaps, hinges in 15° steps; Hinge Align "notoriously buggy" [ldd-lugnet] | grid snapping; new parts go against the face under the pointer; "does NOT implement" connectivity [lc-tutorial] [lc-history] [lc-noconn] | connection snapping from a separate shadow library; the author says it was "never meant as the main building tool" [ld-meta] [ld-snap] | grid drag and nudge; "Insert Related" adds a tyre to a wheel; no connection snapping found [bs-history] [bs-changelog] | integer 2 LDU lattice, exact collision; 24 orientations; snap stud, ½ stud, ½ plate or free; pins, axles, bars and clips placed by connection; side studs; hinge swing; mirror ([building] [geometry]) |
| **Part library, search** | LDraw-derived plus BrickLink's own; search by BrickLink ID, words, size, `=compatible()`; Element ID search in Early Access [st-search] [st-rn] | its own library, not LDraw; no count published [mb-ldraw] | LEGO's own geometry; last parts 2018 [ldd-blog] | LDraw including unofficial; search, palettes, favourites [lc-library] [lc-releases] | LDraw including unofficial; a bin tree with set inventories, templates, favourites [ld-gui] | LDraw (2022-01 bundled); keyword search [bs-home] [bs-history] | 28,319 placeable (4,735 of them unofficial); ranked search by name, number and set; Recent and Favourites ([parts]) |
| **Colours** | every BrickLink family plus render-only ones; a validator for combinations never made [st-colors] [st-validator] | colour picker plus a material list; glitter and opal in the add-on [mb-brickset-build] [mb-addon] | Standard mode allows only real combinations [ldd-modes] | LDraw colours, a picker [lc-tutorial] | LDConfig colours, colour wheels [ld-gui] | LDraw colours by hue; a material filter [bs-history] | 322 colours, each finish drawn; the years each part was made in each colour ([parts] [view]) |
| **Sub-models, steps** | nested, linked copies; the Step Editor moves parts between steps [st-submodel] [st-stepedit] | groups and parenting; no steps [mb-brickset-build] | groups only; build order not saved [ldd-order] | in-place sub-models; a timeline that drags parts between steps [lc-history] [lc-2609] | full MPD, nested editing, rotation steps [ld-advedit] [ld-steps] | sub-models, step rotations, split step [bs-history] | `Ctrl-G` sub-assemblies, a model tree, `.mpd`; steps worked out, or a file's own kept, moved between, merged, split and reordered; rotation steps read and written ([building] [view]) |
| **Instructions** | Instruction Maker: steps, page design, callouts, part lists per step, BOM with Element IDs, PDF/PNG; its automatic split "works best on simple builds" [st-im] [st-callout] [st-bom] [st-divide] [st-im-export] | no instruction maker found (*unverified*) | Building Guide: automatic, uneditable, HTML only [ldd-guide] | a dialog that prints, with a BOM picture, earlier steps faded, HTML export [lc-history] [lc-cli] | stepping only; pages by LPub3D (*unverified*) [ld-features] | steps only; LPub for print [bs-home] | a booklet worked out, then laid out by hand: each step turned, tilted, zoomed, sized, on a new page or alone, its parts list on or off, a sub-assembly in a callout or on its own pages, steps a page, steps merged, split and reordered, one undo each, saved as ROTSTEP and the app's own lines; a page laid out by hand: each step's picture, parts list, callout and number dragged and sized, snapping to the margins and each other, words, pictures and arrows added, each going with its step when the pages change, nothing printed on anything else; new parts outlined (off per booklet); callouts "2x", turn signs (off per step), arrows, a cover, parts by colour with element numbers; prints A4 or Letter; no rotation of a box, no rulers ([view]) |
| **Rendering** | Eyesight (Cycles) path tracer on CPU or NVIDIA only; POV-Ray with LGEO; turntables and build animations [st-eyesight] [st-pov] [st-anim] [st-amd] | a render farm, 10 free a day to 0.7 MP, credits beyond (2020); Blender add-on, Advanced $25 [mb-farm] [mb-addon] [mb-render-compare] | real-time only [ldd-wiki] | POV-Ray with LGEO; Blender since 25.09 [lc-history] | OpenGL; PNG and POV-Ray, animations too [ld-features] | OpenGL; POV-Ray through LDView [bs-home] | real-time with seams and finishes; Render: raster accumulation up to 64 frames, HDRIs, depth of field, 4K, turntable WebP/MP4 ([view]) |
| **Stability, physics** | colours weak parts pink or red; "very conservative" [st-stab] | none; a collision toggle asked for in May 2026, unanswered [mb-collision] | not found | none [collision-2016] | none; a Lua proof of concept [ld-collide] | not found | per joint: clutch, levers, slenderness, each with a margin; weight; selects weak joints ([stability.gd] [geometry]) |
| **Flexible parts** | the Flex tool bends most chains, hoses and stud strings, with control points since 2.25 [st-flex] [st-rn]; "pseudo-physics" complaints before that [st-flex-forum] | its own path system since 2019: several paths, springs, live geometry [mb-flex] | the Flex tool fails with other parts attached [ldd-flex] | generated hoses, flex axles, strings, shock absorbers, Flex-System hoses, pneumatic tubes [lc-history] | the deepest: Bézier paths, rubber bands round circles, springs, skins of donor parts, length mapped to a real part number [ld-meta] [ld-advedit] | LSynth built in: hoses and bands [bs-lsynth] | tube, ribbed hose, flex hose, flex axle, string, chain, tread laid by their ends, reshaped later, bought as one part; no bands or springs ([geometry] [model-io]) |
| **Custom parts, prints, stickers** | PartDesigner, a separate app: parts and connections, OBJ/DAT import, decals on 28 parts [st-pd] [st-pd-decal] | Part Manager paints a PNG over the UV map, with metal ink, chrome and stickers; no custom shapes [mb-partmgr] [mb-nocustom] | none official; mods [ldd-custom] | texture mapping, a Minifig Wizard [lc-texmap] [lc-releases] | embedded textures; new flexible parts by template [ld-17b1] [ld-meta] | planar texture mapping, a minifig generator [bs-history] | element maker (7 families, any size), change any part, paint or import prints, stickers with a PDF sheet, sculpted moulds ([elements] [prints] [minifig]) |
| **Import, export** | in: io, ldr/mpd, lxf, a wanted list, a set, OBJ/STL as a sculpture, mosaics. out: ldr/mpd, lxfml, POV, dae, csv, a wanted list, Sketchfab; no OBJ/STL [st-import] [st-export] | in: LDD, Studio. out: OBJ, DAE, STL, `.zmbx` for Blender; no LDraw out [mb-lddimport] [mb-farm] [mb-addon] [mb-eb9] | lxf; LDraw through ldraw.xml [ldd-ldraw] | ldr/mpd; LDD in; out OBJ, 3DS, COLLADA, CSV, HTML, images, a BrickLink XML [lc-history] [lc-cli] | LDraw; out PNG, POV-Ray, glTF2, Collada (partial) [ld-features] [ld-17b1] | LDraw; a part list [bs-history] | in: ldr/mpd, io (locked ones too), lxf, OBJ/STL/glTF to brickify. out: ldr/mpd, io (not yet seen opening in Studio), glTF/GLB, OBJ, STL, PNG, a BrickLink XML, a Rebrickable CSV, the booklet, a sticker PDF. Another tool's LDraw file comes back exactly as it went in (54 of 54 measured, author, licence and LDCad's flexible parts kept), and a part it cannot draw is kept, not dropped ([model-io] [brickify] [cadtask]) |
| **Collaboration, sharing** | Build Together, live co-editing; a Gallery; the Designer Program [st-bt] [st-gallery] | a public library with likes, comments and an embed [mb-model] [mb-eb4] | Design byME ended 2012 [ldd-wiki] | by file | not found | none | a link `/m/<id>` that keeps its versions and says what changed, an embed card, a read-only viewer with steps and booklet, a copy to edit; Build together: two people co-edit one model live by a link, in browsers and the desktop, each with their own Undo ([web] [account] [together]) |
| **Collection, BrickLink, Rebrickable** | Price Guide prices, a one-click wanted list, a My Collection palette; no Rebrickable [st-price] [st-wanted] [st-collection] | inventory as CSV or BrickLink XML [mb-model] | ordering ended 2012 [ldd-wiki] | a BrickLink XML [lc-history] | Rebrickable inventories as part bins [ld-rb] | a part list only | a collection from Rebrickable, a BrickLink XML or typing; what is short and what could stand in; what you can build; a wanted list or Rebrickable CSV; no prices ([collection]) |
| **Platforms, price** | Windows, macOS; free; LEGO account sign-in [st-platform] [st-wiki] [st-signin] | browser only, on purpose; free; render credits; Patreon $1–50 [mb-online] [mb-patreon] | Windows, old macOS; free; withdrawn [ldd-wiki] [ldd-end] | Windows, macOS, Linux (AppImage, Flatpak, Snap); free, open source [lc-download] [lc-2609] | Windows, Linux; macOS under Wine; free for personal use, closed source [ld-download] [ld-mac] [ld-faq] | macOS 10.11+; free [bs-home] | browser (any desktop, phones), Linux, macOS, Windows; free, open source; email sign-in required; AI on your own key or Claude plan ([web] [release]) |
| **Big models** | collision "can take a lot of resources"; detail level trades for speed [st-collide] | very large sets crashed it (2013); a ~17,000-brick render failed (2020) [mb-eb4] [mb-eb9] | 32-bit; "slows to a crawl" at 6,000 [ldd-big] | "optimized for large models"; faster than LDView on Datsville [lc-home] [lc-datsville] | redraws only what changed; snapping slows large sub-models [ld-17b1] [ld-advedit] | a threaded parser; speed work through 3.1 [bs-history] | instanced: 200,000 bricks in 14 draw calls at 131 fps (M3 Max); nothing drawn while idle; an 8,603-part build order in 5 s ([README] [view]) |
| **UX, keys, mouse** | right-drag orbit, WASD, numpad views, remappable keys; a 2.24 gizmo regression, undone [st-nav] [st-keys] [st-rotate] | W select, S snap, D clone, M move, numpad views; "steep learning curve" [mb-brickset-build] | "the rotation tool sucks" [ldd-requests] | Alt-drag navigation, remappable; an LDD-style mouse; a 26.09 rotation gizmo [lc-tutorial] [lc-2609] | "very non-standard GUI" [lc-datsville]; drag turns, Shift pans [ld-keys] | Mac-native, trackpad gestures, 3Dconnexion; nudges uneven on turned parts [bs-history] [bs-nudge] | Studio's controls by default, or Blender's or Mecabricks'; menus with keys; tool modes; a pointer that shows what a click does; a view cube; cut-away and x-ray ([building] [view]) |
| **AI design** | none; Sculpture is rule-based [st-sculpture] [st-rn], and was 75% stable in ResemBrick's test [resembrick] | none found | none | none found [lc-2609] | none found | none found | Claude from a sentence or a picture: every brick checked; 77 worked constructions, patterns, rooms, figures, parts it makes, LEGO Art plans; a detail pass per assembly; your own key, or your plan by connector or MCP ([assistant] [mcp]) |
| **AI-assisted editing** | none | none found | none | none; a command line for batch export [lc-cli] | none; Lua scripts can change the model [ld-script] | none | Claude edits the open model, hand-built or not: `edit_model`, `restyle_model`, `add_rooms`, `review_model`; it knows nothing of the selection ([assistant]) |
| **Learning** | an interactive tutorial at first launch; official videos [st-tutorial] [st-video] | Brickset's tutorial series; a forum [mb-brickset-build] [mb-home] | a manual, gone [ldd-blog] | a guide and tutorials [lc-docs] | docs and a script API [ld-docs] | a tutorial; an LPub guide [bs-home] | an eight-card tour, a controls sheet, hints in the status bar ([building] [view]) |
| **Accessibility** | not found (a gizmo size, remappable keys) [st-rn] | not found | not found | high-contrast stud and edge options; HiDPI [lc-releases] [lc-2609] | not found | not found | none found in `src/ui` |
| **Mobile, tablet** | none [st-platform] | works on touch screens; an iPad Pro with a pen reported [mb-brickset-build] [mb-tablet] | none | "iOS compatibility" in 26.09's notes; no app found [lc-2609] | none | none | a phone layout with drawers, touch orbit and pinch, buttons for keys; tablets not measured ([web], `src/ui/touch_tools.gd`) |

### Around the build: instruction apps, scanners, catalogues and AI generators

None of these is a CAD. They are here because people use them on either side
of one. "—" means the tool does not do it at all. The Brickworks column only
adds what this comparison needs; the full detail is in the table above.

| | LEGO Builder app | BrickHub and LDraw web viewers | Brickit | Rebrickable | AI generators: BrickGPT, BrickAgent, BrickForgerAI | Brickworks |
|---|---|---|---|---|---|---|
| **Modelling, connections** | — | — (viewers) [brickhub] [ldraw-viewer] | — | — (points people to Studio and Mecabricks) [rb-virtual] | BrickGPT: 8 rectangular bricks, one unit tall, on a 20³ grid [bgpt-paper]. BrickAgent: `attach` by exact connector fit [brickagent]. BrickForgerAI: a 55-part library (vendor claim) [bforger] | exact lattice and connector snapping over 28,319 parts ([building]) |
| **Part library, search** | LEGO's own sets only | the LDraw library, unofficial too [brickhub-model] | ~1,600 shapes recognised from a photo [brickit-abc] | 64.9k parts and 28.5k sets catalogued [rb-api] | BrickBench: 14,441 parts [bb-paper] | 28,319 placeable (`catalogue.json`) |
| **Colours** | true to the set | recolour in the viewer [bijs] | ignores colour on purpose, the developer says in reviews [brickit-app] | exact, similar or ignored when matching [rb-build] | BrickGPT: nearest LDraw colour, or a UV texture [bgpt-paper]. BrickBench: texture asks met 49–83% [bb-paper] | 322 colours, real availability per part ([parts]) |
| **Sub-models, steps** | LEGO's own | the file's steps, editable [bijs] | — | the designer's file [rb-moc] | BrickGPT orders bottom-up, which CMU calls a build guide [bgpt-site] | worked out; a file's steps dropped (item 1) |
| **Instructions** | 3D steps to zoom and turn, for select sets; PDFs for the rest [legobuilder] | generated live from LDraw [brickhub] | build ideas with steps [brickit-app] | images, video, or a Studio/LDraw/LDD file viewed in the browser [rb-moc] [rb-viewer] | BrickForgerAI: a PDF (vendor claim) [bforger] | a printable booklet ([view]) |
| **Rendering** | real-time 3D | three.js PBR [bijs] | — | uploaded images | BrickGPT: a PNG [bgpt-code] | studio render, turntables ([view]) |
| **Stability, physics** | — | — | — | — | BrickGPT: Gurobi force balance and rollback, 98.8% stable [bgpt-paper]. BrickAgent: PyBullet rigid bodies, which by the authors' own account do not test clutch [bb-paper] | clutch and levers per joint ([stability.gd]) |
| **Flexible parts** | — | as the file draws them | — | — | — | laid along a path ([geometry]) |
| **Custom parts, prints** | — | textured LDraw parts [brickhub-model] | — | — | — | element maker, prints, stickers ([elements] [prints]) |
| **Import, export** | — | LDraw in; a "Studio-safe" LDraw out [brickhub-model] | not found | in: CSV, BrickLink XML, BrickStore, LDraw, LDD, Studio. out: BrickLink XML, BrickOwl, a Pick a Brick CSV [rb-import] [rb-bl] [pab] | `.ldr` or `.mpd` [bgpt-code] [brickagent] | `.ldr`, `.mpd`, `.io` out; `.io`, `.lxf` in ([model-io]) |
| **Collaboration, sharing** | Build Together: a PIN, turns on steps, select sets [legobuilder] | a public page per model [brickhub] | — | 200,000+ MOCs, 2.1M users [rb-wiki] | BrickBench's gallery [bb-site] | unlisted links ([web]) |
| **Collection, shops** | keeps your collection [legobuilder] | — | the pile is the collection | the Build engine over what you own; pushes to BrickLink and BrickOwl [rb-build] [rb-bl] | Alt-Build limits an agent to one set's parts [brickagent] | Rebrickable and BrickLink import, shortfall, stand-ins, wanted lists ([collection]) |
| **Platforms, price** | iOS, iPadOS, Android; free [legobuilder-site] | web; free [brickhub] | iOS, Android, Apple-silicon Mac; $6.99 a month or from $34.99 a year [brickit-app] | web; Pro $4.90 and Designer $9.90 a month (*unverified*) [rb-plans] | BrickGPT: MIT, a demo [bgpt-demo]. BrickAgent: MIT, on pip [brickagent]. BrickForgerAI: monthly, prices differ by listing [bforger] | web and desktop; free, open source |
| **Performance, big models** | set-sized | — | — | — | BrickGPT median 40.8 s a model [bgpt-paper]; BrickBench's Set setting is 400–4,000 parts [bb-paper] | the 9,429-part Orthanc opens in the browser builder from the landing page |
| **UX** | the camera "a little weird", step order unlike the book (reviews) [legobuilder] | — | pieces must be spread thin, touching ones merge (reviews) [brickit-app] | — | — | Studio-style controls ([view]) |
| **AI design** | — | — | suggests builds from a fixed library [brickit-app] | — | see [AI design](#ai-design-where-the-field-is) | see the same section and item 5 |
| **AI-assisted editing** | — | — | — | — | none: each builds from nothing | `edit_model`, `restyle_model`, `add_rooms` ([assistant]) |
| **Learning** | guided content for some themes [legobuilder] | — | — | help pages | — | the tour ([building]) |
| **Accessibility** | VoiceOver reads unlabeled buttons (a review, Dec 2025) [legobuilder] | not found | not found | not found | — | none (item 14) |
| **Mobile, tablet** | the point of it | works in a phone browser | the point of it | web | — | a phone layout; a build mode is item 4 |

## AI design: where the field is

The research moved fast in the last eighteen months, and the most relevant
paper appeared four days ago.

- **BrickGPT** (CMU, ICCV 2025 best paper) is the one most people have heard
  of [bgpt-paper] [bgpt-site].
  - It is a fine-tuned 1B Llama that writes bricks bottom to top: eight
    rectangular bricks (1x1 to 2x6), all one unit tall, on a 20x20x20 grid.
  - A Gurobi force-balance check with rollback makes it 100% valid and 98.8%
    stable, at a median 40.8 s a model.
  - No plates, slopes, SNOT or Technic.
- **Later work keeps rectangular bricks** and improves stability or speed:
  - STABLE, on the same grid, takes 57.6 s a sample, against the 895 s of
    BrickGPT with rollback and rejection sampling, on point-cloud inputs
    [stable].
  - ResemBrick works from a few photos and was 100% stable on 198 objects
    [resembrick].
  - BrickAnything works from point clouds [brickanything].
- **Real parts and real connections.** LegoACE (SIGGRAPH Asia 2025) uses 28
  brick types and warns its output may not be buildable [legoace]. BrickNet
  (CVPR 2026) learns 9,743 LDraw parts and five connection types, but caps a
  build at 100 parts and checks no gravity [bricknet].
- **BrickBench and BrickAgent** (Kulits, Xu, Jones, Schmid, Wu; 8 Oct 2026)
  are the yardstick that matters here, because they measure what Brickworks
  does [bb-paper] [bb-site] [brickagent].
  - The setup: a frontier model as an agent, given a parts library and a
    checker (`add`, `attach`, `find`, `connectors`, `view`, and `check` with
    PyBullet stability), building from text.
  - 300 prompts in three settings: up to 400 parts, 400–4,000 parts, and
    the 783 parts of set 10698.
  - With the checker, every frontier agent is 100% valid. Claude Opus 5.5
    scores VQA 0.952 and a design ELO inside GPT-6 Astra's interval, at
    $5.90 a build. BrickGPT scores VQA 0.024.
  - Without the checker, GPT-6 Astra is valid on 40% of prompts.
  - Human raters still picked the human-made model in 323 of 360 ratings
    (90%).
  - The authors' own stated limit: their stability check is a rigid-body
    proxy that does not test clutch.
- **Consumer apps.**
  - BrickForgerAI (Sept 2026) claims text to LDraw with instructions from a
    55-part library, and a beta "detailed" mode with slopes and SNOT. No
    gallery could be checked [bforger] [bforger-ph].
  - The rest found are image filters, mosaics (LEGO's own 40179 Mosaic
    Maker) or mesh stylisers (Tripo) with no parts list [mosaic40179]
    [tripo].
  - A small `lego-mcp` server gives Claude a stud grid of bricks, plates,
    tiles and slopes [legomcp].
- **The CAD tools have shipped no generative AI.** Studio's Sculpture turns a
  mesh into a brick shell with no stability analysis [st-sculpture]. Nothing
  AI appears in its release notes through 2.26.9_1 [st-rn]. Nothing was
  found for LeoCAD 26.09, Mecabricks, LDCad or Bricksmith [lc-2609].

**What this means for Brickworks.**
- Its design loop is the BrickAgent recipe (a frontier model, a parts
  library, a checker) with a great deal on top:
  - a lattice exact to 2 LDU instead of collision hulls;
  - clutch, levers and support checked per joint instead of a rigid-body
    drop;
  - 77 worked constructions with real part numbers;
  - patterns that do the counting (`repeat`, `mirror`, `fill`, `round`,
    `shape`, `prism`);
  - rooms, minifigures, parts it makes itself and LEGO Art plans;
  - a second pass on each named assembly, measured against real sets;
  - and it runs inside a CAD where people can then edit the result
    ([assistant]).
- No public tool does all of that. But BrickBench is the first external,
  repeatable measure, and Brickworks has not been put on it. Until it is,
  "the most brilliant AI designer" is a claim made with our own ruler
  (`tools/style.py`, `tools/texture.py`).
- That ruler says our models are still thinner than real sets: castle run
  24 has 121 shapes and 13 colours, where a 2,400-part set has 262 and 28
  (`docs/ROADMAP.md`).
- The cost is high for a casual user: 11 minutes and $2.40 for a small house
  on an API key at high effort (`HANDOFF.md`).

## What to build next: fifteen, ranked

Ranked by how many people building would notice it in their first week,
multiplied by how far it puts Brickworks past the field. Each item is sized
for one agent in under three hours. **Touches** lists the files it changes.
**Proof** is the check its recipe in `.claude/skills/verify/` gets.

| # | Item | Today against the field | Who notices |
|---|---|---|---|
| 1 | Keep and edit the author's steps | trails Studio, LeoCAD, LDCad, Bricksmith | anyone opening another tool's model; every MOC designer |
| 2 | Studio files open whole | trails Studio | most people who bring a model in |
| 3 | Ask Claude about the selection | no one has it | every AI user |
| 4 | Build mode on a phone or tablet | matches BrickHub's viewer and the LEGO Builder app; ahead of Studio | anyone building from a shared model |
| 5 | Put the designer on BrickBench | unmeasured | the claim itself |
| 6 | A stress view | beats Studio's check | anyone building something tall or long |
| 7 | Export glTF, OBJ, STL | trails Studio, Mecabricks, LeoCAD, LDCad | people who render, print or use AR |
| 8 | A public gallery with remixing | trails Studio, Mecabricks, Rebrickable | every visitor |
| 9 | Sketch first: three cheap drafts | no one has it | every AI user, at the first design |
| 10 | Worked constructions in the parts bin | Studio has plain sub-assemblies | people building by hand |
| 11 | Find a part from a photo | Brickit and RebrickNet do it outside a CAD | most builders, sometimes |
| 12 | Instruction page design | close to Studio's: pages by hand, new parts outlined | MOC designers |
| 13 | Gear trains in Pose | LDCad needs a script | Technic builders |
| 14 | Accessibility | no one has it | fewer people, more acutely |
| 15 | Monthly new parts | trails Studio's cadence | builders of new sets |

### 1. Keep the author's build steps, and let people edit them

*Trails Studio, LeoCAD, LDCad and Bricksmith, which all keep a file's steps
and let people change them [st-stepedit] [lc-history] [ld-steps]
[bs-history]. Anyone who opens someone else's model notices, and so does
every MOC designer.*

Brickworks reads `0 STEP` into `LdrModel.Placement.step`, then drops it:
- `BrickWorld.Brick` has no step field.
- `Instructions.plan` always works the order out from scratch.
- `ModelStore.to_text(with_steps)` writes that worked-out order back.

So a Studio or LDCad model opened and saved here loses the steps its
designer made, and the booklet never uses them.

**Done, 2026-10-12** (`src/assembly/author_steps.gd`; the recipe is "the
author's steps" in `.claude/skills/verify/features/view.md`). As specified,
with what building it showed: a sub-model's steps are its own, so a copy's
step in the model that places it is kept apart (`BrickWorld.unit_steps`);
the steps Brickworks itself wrote into every file it saved are not an
author's and are not kept (`0 Author: Brickworks` without the line
`0 !BRICKWORKS AUTHORED_STEPS`); `0 ROTSTEP` ends a step too; and the
timeline also reorders, merges and deletes steps.

**Spec.**
- On open, give `Brick` a `step: int = -1` set from `Placement.step` in
  `ModelStore.open_text`. The `.io` and `.lxf` readers open through it too.
- On save, write those numbers back whenever any brick has one.
- A model whose bricks all carry a step is "built in the author's steps".
  `Instructions.plan(authored=true)` then groups by `brick.step` and skips
  `_sequence`. It still finds callouts by `unit`, and it ignores regions
  and the per-step limits.
- The timeline (`StepsBar`) gets a fourth order, "Author's steps", which is
  the default for such a model.
- Edit gets *Move to previous step*, *Move to next step* and *New step from
  selection* (`Shift-[`, `Shift-]`, `Shift-N`). Each is one undo.
- In a hand-built model, the first step edit copies the worked-out order
  into `brick.step`. While steps are authored, a newly placed part joins the
  step the timeline is on.

**Touches:** `src/render/brick_world.gd`, `src/parts/model_store.gd`,
`src/assembly/instructions.gd`, `src/ui/steps_bar.gd`, `src/ui/shell.gd`,
`src/assembly/builder.gd`.

**Proof:**
- `io_probe` round-trips an `.mpd` with five authored steps, and they come
  back unchanged.
- `booklet_probe` counts the author's steps on the pages.
- A browser flow moves a part one step and checks the timeline's caption.

### 2. Studio files open whole: Studio-only parts come from the file itself

*Trails Studio, whose format most people's models are in.*

**Done, 2026-10-19** (`StudioDecor.carried` in `src/parts/studio_decor.gd`;
the recipe is "open a studio model" in
`.claude/skills/verify/features/model-io.md`). In two parts. On 2026-10-14
the `bl_` prints, stickers and Part Designer parts came from the file with
their pictures, and set 31213's file placed 1,501 of 1,501, its three
prints drawn (that file is not ours and is not kept here). Now so does any
other part the library has not got: a part newer than it, which
`model.ldr` names by LDraw's number and `model2.ldr` carries by that
number or by BrickLink's. The picker hands `StudioIo.read` the library to
ask. What building it showed:
- The BrickLink number is not known for a part the library has not got,
  so it is found by place. Each section of `model2.ldr` is the same model
  as `model.ldr`'s, so the line that puts a part in the same place is the
  same part (`StudioDecor.bricklink_names`). A line nothing matches maps
  nothing.
- They go in the parts bin's existing "From Studio" category (made on
  2026-10-14), not a new "Studio part" one.
- `whole_2025.io` placed 4 of 6 before and 6 of 6 after, on the desktop
  (`io_probe`) and in a browser (`io_flow.mjs`). BrickLink's black (11) in
  a part's own faces comes out LDraw's 0, not light turquoise. Saved as
  `.mpd` and opened into a library that had never seen them, the six are
  the same: triangles, colours and pictures.
- The last step, Studio under Wine, was not tried: nothing third-party is
  installed on this machine. So `CHANGELOG.md` still says the `.io` export
  is not yet seen opening in Studio.

Today Brickworks leaves out a part only Studio has (a `bl_…` part or a
PartDesigner part) and names it in the status bar. The 2025 test set placed
1,498 of 1,501 parts ([model-io]). Yet the `.io` already carries what is
needed:
- `model2.ldr` holds "the geometry of every part it uses", and custom parts
  sit in `CustomParts/` (both noted in `src/parts/studio_io.gd`).
- PartForge already builds a part from LDraw text inside the app. That is
  how made parts in an `.mpd` open (`CustomParts.take_from`).

**Spec.**
- For each part `open_text` reports in `missing_ids`, look in `model2.ldr`
  and then `CustomParts/` for an `0 FILE` section by that name or by its
  BrickLink number.
- Pass what is found, with its subfiles, to `CustomParts.add(keep=false)` as
  a made part in a "Studio part" category.
- `model2.ldr` uses BrickLink colour numbers, so map them through
  `colors.json`'s `bricklink` field. This is Studio's colour bug in
  reverse.
- Then place the parts as usual. An `.mpd` saved afterwards embeds them, as
  it already does for made parts.
- Finally, try opening Brickworks' own `.io` export in Studio under Wine,
  using a community recipe [st-wine-lutris]. If Studio will not run there,
  say so in the recipe and keep "not yet seen opening in Studio" in
  `CHANGELOG.md`.

**Touches:** `src/parts/studio_io.gd`, `src/parts/model_store.gd`
(`studio_part`, `open_text`), `src/parts/custom_parts.gd`.

**Proof:** `io_probe` opens a fixture `.io` whose `model2.ldr` carries one
`bl_` print. All 1,501 of 1,501 parts are placed and the print is drawn.

### 3. Ask Claude about the selection

*Ahead of everyone. No CAD has AI editing [st-rn] [lc-2609], and BrickBench's
agents only build from nothing [bb-paper].*

A person selects a wall, a roof or a wing, right-clicks and chooses *Ask
Claude about this…*, then types "make this look like weathered stone", "add
a balcony here" or "this hinge is weak, fix it". Today the chat does not
know what is selected (`src/ui/chat_panel.gd`). A request has to describe
the part in words, though `edit_model` already takes brick numbers.

**Spec.**
- `Shell.open_context` gets the item. It opens the chat with a removable
  chip: "About 46 selected parts".
- `ChatPanel.ask` sends the selection's brick numbers, its box in studs, and
  its counts of parts and colours. It also sends one close-up render framed
  on the selection, from `ModelShot`. The words say: change these, and only
  what touches them unless asked.
- A `selection` tool returns the same over the connector and MCP, so it
  works on the person's own plan too.
- `Assistant._checked` reports any bricks outside the selection that an
  edit changed, and the reply says so.

**Touches:** `src/ui/shell.gd`, `src/ui/chat_panel.gd`,
`src/ai/assistant.gd` (the tool list, `_model_from_world`),
`src/net/command_socket.gd`.

**Proof:**
- A probe selects the example car's roof and asks for it in blue through a
  recorded brain. Only roof bricks change.
- `tools/mcp_check.py` lists `selection`.

### 4. Build mode: a shared model, step by step, on a phone or tablet

*Ahead of Studio, which is desktop-only [st-platform]. Level with
BrickHub's and Rebrickable's browser viewers [bijs] [rb-viewer] and the LEGO
Builder app, whose 3D steps cover only LEGO's own sets [legobuilder].*

This brings Brickworks level, not ahead. It still matters: every model made
here, by hand or by Claude, should be buildable from a phone without a PDF.
A shared model already opens at `/app?view=<id>` with its timeline
(`src/ui/share_view.gd`), but nothing there is made for building at a table.

**Spec.**
- A *Build it* button turns the viewer into a step player:
  - big Back and Next buttons (46 pt, as `TouchTools`) and swipes;
  - each step's new parts drawn in full, with what is already built faded
    (x-ray's see-through pass inverted, `BrickWorld.set_xray`);
  - a strip of the step's parts as thumbnails with "2x".
- Each step opens on the view the booklet chose for it (`BookletMaker`
  decides each step's view). The person can still turn it.
- The step reached is kept per link in `localStorage`, so a phone that
  sleeps comes back where it was.
- It uses the author's steps where there are any (item 1), and
  `Instructions.plan` otherwise.

**Touches:** `src/ui/share_view.gd`, `src/ui/steps_bar.gd`,
`src/render/brick_world.gd`, `src/ui/part_thumbnails.gd`, `src/main.gd`
(`_enter_view`).

**Proof:** a browser flow at `fit_check.mjs`'s phone size opens a shared
link and presses Next three times:
- The canvas shows the fade, and the caption reads "Step 3 of N".
- After a reload, it is still on step 3.

### 5. Put the designer on BrickBench

*The only external ruler there is, and the claim needs one.*

BrickBench (8 Oct 2026) scores agents on validity, prompt alignment and
design, using VQA and pairwise ELO, over 300 prompts. Its evaluation
scripts are MIT-licensed [brickagent]. Claude Opus 5.5 with BrickAgent
scored VQA 0.952 and design ELO 1252 in the Model setting [bb-paper].
Brickworks gives Claude far more than BrickAgent does, and nobody knows
whether that is worth points.

**Spec.**
- `tools/brickbench.py` renders BrickBench prompts with their
  `scripts/prompt.py`. It runs each through `tools/claude_run.sh --brief`,
  on the plan, under `heavy`, on its own port.
- It writes the `.mpd` their `check_submission.py` accepts, runs their
  `verify.py` and `vqa.py`, and puts our numbers beside their Table 1.
- Start with ten prompts from the Model setting. Then try Alt-Build, where
  only set 10698's 783 parts may be used: map `BRICKAGENT_SET` onto the
  assistant's collection hook.
- Where it can fail: parts outside BrickNet's 14,441, and our lattice and
  their connector check disagreeing. Write both into `docs/ROADMAP.md`.
- This is the outside half of the design benchmark already in progress, not
  a replacement for it.

**Touches:** a new `tools/brickbench.py`, `tools/claude_run.sh` (an output
path), `docs/ROADMAP.md`.

**Proof:** their `verify.py` passes on the ten pilot builds, and the table
is committed.

### 6. A stress view instead of a list of weak joints

*Studio colours weak parts pink and red. Its own help calls the check "very
conservative": it "often flags parts that are actually well connected"
[st-stab]. Brickworks has better numbers and shows less of them.*

Build, Check stability selects the risky parts and prints one line
(`Shell._check_stability`). `Stability.Risk` already carries a `margin`, but
only for failing joints.

**Spec.**
- `Stability.check` also returns every joint's margin, keyed by the brick
  above it.
- *View → Stress* tints every part by its weakest joint: red under 1, amber
  under 2, everything else in its own colour, faded.
  - The tint is for display only, drawn by a second MultiMesh per batch as
    x-ray draws its ghosts (`BrickWorld.set_xray`).
  - The paint is never changed.
- Hovering a part says "carries 212 g on 2 studs, margin 0.7".
- Each weak joint offers "Ask Claude to brace this" (item 3).

**Touches:** `src/assembly/stability.gd`, `src/render/brick_world.gd`,
`src/ui/shell.gd`, `src/ui/see_inside.gd` (as the pattern for turning it on
and off), `src/ui/status_bar.gd`.

**Proof:** a probe builds a column of 1x1s carrying a 2x10 plate as a
cantilever. The plate's root reads red, and a column of 2x2s reads plain.

**Done, 2026-10-22** (`src/ui/stress_view.gd`; the recipe is "stress view"
in `.claude/skills/verify/features/view.md`). As specified, with what
building it showed:
- The margins are Balance's, not a second weighing. A stud joint that alone
  holds what is past it is levered about the edge it would turn on, against
  its studs' 1 N each there. A joint that shares its load, as a bonded
  wall's does, is not weighed, so it is never libelled. The weight pressing
  on a stud, which Check stability's list weighs, holds whatever presses it.
- A bare 2x10 on one stud is not red: the stud holds it 4.8 times over. Red
  needs the cantilever loaded, 8 g of 2x2s at its tip (margin 0.7), and so
  the probe loads it. Then every 1x1 under it reads red too, and on 2x2s the
  root holds 6.2 times over.
- On eight OMR sets that stand (75969-1, 7191-1, 10262-1, 70816-1, 10270-1,
  10264-1, 75060-1, 21318-1; 925 to 2,993 parts) one part reads red. It is
  21318-1's branch of leaves, 9 g on a 6L bar in a 1x1 brick's side stud, at
  0.74 of the stud's working load (2.2 times short of where it lets go).
  10264-1's Technic axle through a cross block read red until a contact on a
  part with no studs stopped counting as a stud joint. The eight shipped
  models read none. Orthanc, a session's design, reads 31: three inner cores
  of up to 496 parts, each on a column of 1x1 round bricks, leaning on the
  walls with no joint to them.
- Off, it costs nothing. On, turning it on is one 26 ms frame on 75969-1
  and the tint comes 0.6 s later; orbit, select all and a step are as
  before. Each change's weighing, on its worker, grows by 10% to 150%
  (75969-1, 602 to 734 ms; the castle, 155 to 380).
- Not weighed: a part's joint to the floor or the baseplate, which Balance
  stands it on (a tower's foot), and pins, axles, clips and hinges.

### 7. Export the model as a 3D file: glTF/GLB, OBJ and STL

*Trails Studio (`.dae`) [st-export], Mecabricks (OBJ, DAE, STL) [mb-farm],
LeoCAD (OBJ, 3DS, COLLADA) [lc-history] and LDCad (glTF2) [ld-17b1].*

This also closes the rendering gap by way of Blender instead of in-house.
Brickworks reads meshes in for brickify (`src/parts/mesh_file.gd` uses
`GLTFDocument`) but writes none out. For Cycles-quality pictures, a 3D
printer or AR, the answer is a file.

**Done, 2026-10-13** (`src/parts/mesh_export.gd`; the recipe is "3d model
export" in `.claude/skills/verify/features/model-io.md`). As specified,
with what building it showed: glTF is written by hand, not by
`GLTFDocument.append_from_scene`, which on 4.7.2 writes a mesh for every
`MeshInstance3D`, drops a `MultiMesh`'s colours and runs in one call. Each
shape is written once and every part is a node pointing at it, which is
glTF's own instancing, so Orthanc writes whole: 4.7 MB in 0.4 s, no frame
held past 63 ms. OBJ and STL cannot share a shape, so they are capped, OBJ
at 1,000,000 triangles and STL at 3,000,000 (Orthanc's 2,575,061 fit; its
STL is 123 MB in 2.5 s). STL is binary, not text: a fifth of the size. It
is one closed volume per part wherever the part's own LDraw shape is
closed; 7 of the car's 61 parts have gaps in LDraw's geometry (4600 is open
underneath by 0.8 mm), written as LDraw draws them, for a slicer to mend.

**Spec.**
- *File → Export → 3D model…* builds an export-only scene from the world:
  one `MeshInstance3D` per brick, under a node per sub-model.
- The plastic shaders do not survive glTF, so give each colour a
  `StandardMaterial3D` from `colors.json`:
  - roughness and metallic from the finish (chrome, metallic, pearl);
  - alpha for transparent colours.
- Write glTF/GLB with `GLTFDocument.append_from_scene` and
  `generate_buffer` (a download in a browser) or `write_to_filesystem` (the
  desktop).
- Write STL as one merged mesh for printing, and OBJ with an MTL by hand.
  Both are plain text.
- The 9,429-part Orthanc has to export. If the exporter takes it, write
  identical parts as instances (`EXT_mesh_gpu_instancing`). If not, find
  the largest size that works, cap there and say so.

**Touches:** a new `src/parts/mesh_export.gd`, `src/ui/exports.gd`,
`src/ui/shell.gd`.

**Proof:**
- A probe exports the example car as a GLB and reads it back with
  `GLTFDocument.append_from_file`. The node count equals the part count,
  and the bounds match `_built_bounds()` to 1 LDU.
- The STL reads back as one closed volume per part.

### 8. A public gallery, and remixing from it

*Trails Studio's Gallery [st-gallery], Mecabricks' public library
[mb-model] and Rebrickable's 200,000 MOCs [rb-wiki].*

Shared links exist: `api/share.js`, `/m/<id>`, an embed card, and *Open in
Brickworks*. But every link is unlisted. Nobody can find a model they were
not sent, so a newcomer never sees what people build here.

**Done, 2026-10-13** (`web/gallery.html`, `supabase/gallery.sql`; the
recipes are "gallery page" and "seed the gallery" in
`.claude/skills/verify/features/web.md`). As specified, with what building it
showed: the columns went in a file of their own, applied to the live project
as additions only; going into the gallery is counted on top of publishing
(`may_list`, 6 an hour); the owner's unlist also bars the model, so its owner
cannot list it again, and that refusal is a 409, since the panel answers a 403
by publishing at a new link; the viewer's bar says "remixed from" too, since a
person never sees the share page; and six of the project's own models were
listed from a project account so it is not empty.

**The directory, 2026-10-13** (`supabase/directory.sql`, `api/_directory.js`;
the recipes are under "The directory" in
`.claude/skills/verify/features/web.md`). The owner asked for "a robust
directory of submitted projects that users chose to share". `/gallery` now
searches names, credits, tags and descriptions, filters by kind (guessed in
the Share panel from the name with the subject vocabulary, and changeable),
size, the builder's own instructions and Technic, and sorts by newest, most
viewed, most liked and most remixed, with the question in the address. Each
model's `/m/<id>` is now a page of its own rather than a hop to the viewer:
its description and tags, a licence (CC BY 4.0 unless its owner chooses CC
BY-SA 4.0 or all rights reserved; a version of a CC BY-SA model must keep it,
and one of an all-rights-reserved model cannot be listed), its views, likes
and remixes, and its remix tree. Steps, own steps and Technic are counted from
the file by the server, like the part count. A view counts once per visitor
per day, never for a robot, and nothing writes per page request. Cards show a
small WebP the app makes beside the big picture, so a page of them is light on
a phone. A model this one came from is named only while it is listed, so a
listed remix no longer makes public a link its owner only sent to some people.

**People, 2026-10-13** (`supabase/people.sql`, `api/people.js`). Profiles at
`/u/<handle>` by a name the builder chooses, listing only what they listed and
are credited for; likes counted on each model; favourites, private; and
collections, public (a page at `/c/<id>`) or private, gathered from any
model's page. A visitor signs in where they are, with the app's own emailed
code, and `/profile` is where they look after all of it.

**Spec.**
- `supabase/shared_models.sql` gets `listed boolean default false`, granted
  to the visitor's key.
- The share panel gets a tick box, "List it in the gallery"
  (`share_panel.gd`).
- `api/share.js?op=list&page=` returns the listed rows, newest first, with
  the picture each already has.
- `web/gallery.html` is a static grid of links to `/m/<id>`, built like the
  download page.
- *Open in Brickworks* already copies a model. The copy records
  `remixed_from`, and its page says "remixed from X".
- It reuses publishing's edge checks (LDraw only, the size limit,
  `may_publish`) and adds an owner-only unlist to `api/admin.js`.

**Touches:** `supabase/shared_models.sql`, `api/share.js`, `api/admin.js`,
`src/ui/share_panel.gd`, new `web/gallery.html` and `web/gallery.js`,
`tools/deploy.sh` (the route).

**Proof:**
- `share_flow.mjs` publishes with the box ticked and finds the card on
  `/gallery`. With the box unticked, the card is gone.
- `download_check.mjs`'s CSP check passes on the new page.

### 9. Sketch first: three cheap drafts before a full design

*No one does this. It answers the cost.*

A small house costs 11 minutes and $2.40 at high effort, or 4 minutes and
$0.72 at medium (`HANDOFF.md`), and a person learns whether the brief was
understood only after paying. BrickBench's three best agents cost $0.92
to $5.90 a build [bb-paper].

**Done, 2026-10-13** (`Assistant.sketch`, `src/ai/sketches.gd`; the recipe
is "sketch first" in `.claude/skills/verify/features/assistant.md`). As
specified, with what building it showed: the three are checked for being
three ideas — two within 15% on every size whose outlines from the front,
the side and above overlap 70% are one, and the later is sent back once;
150 parts counts a pattern as the parts it lays; the design from the
chosen sketch is a fresh conversation, opening on its picture and its
parts, so the full model is not paid to read the sketches' turn; and
over MCP `choose_sketch` picks. On the subscription, a held-out lighthouse
sketched in 132 s and 12.4k tokens out against 490 s and 39.4k for the
design after it.

**Spec.**
- *Sketch first* is a toggle beside Build it, on by default for a first
  design.
- It asks for three `submit_design` sketches in one turn, on the cheaper
  model and effort of `Brain`. Each is massing only: under 150 parts, no
  detail pass and no rooms.
- Each sketch is checked (`_checked`) but not applied. It is rendered
  off-world with `ModelShot` and shown as one of three cards in the chat.
- Choosing a card applies that sketch and continues the normal loop from
  there, at the chosen model and effort. The other two are dropped.
- The connector gets `sketch: true` on `submit_design`, which answers with
  three pictures.
- The run card says what the sketches cost.

**Touches:** `src/ai/assistant.gd` (a sketch path beside `design`),
`src/ai/brain.gd`, `src/ai/model_shot.gd`, `src/ui/chat_panel.gd`.

**Proof:**
- A probe with a recorded brain returns three sketches and applies the
  second.
- `assistant_flow.mjs` with its fake key shows three cards.

### 10. Worked constructions in the parts bin, for people building by hand

*Studio 2.26.6 added a palette of pre-built sub-assemblies [st-rn]. This
goes further: each entry is a technique, with the reason it works.*

The assistant has 77 worked constructions with real parts and coordinates
(`src/ai/techniques.gd`, `show_technique`). Among them: a window in a wall,
a smooth diagonal, a round tower, an eye with a highlight, a roof ridge.
Someone building by hand cannot reach any of them.

**Spec.**
- The bin gets a *Techniques* tab beside Recent and Favourites, grouped by
  `Techniques.GROUPS`.
- Each tile shows the construction's thumbnail, drawn once and cached as
  part thumbnails are, with its one-line reason.
- Choosing a tile turns its placements into LDraw lines (the path paste
  already takes) and holds them as one carried group (`Carry.hold`). `R`
  turns it, a click puts it down, and the whole drop is one undo.
- The colour in hand replaces the construction's main colour.

**Touches:** `src/ui/parts_bin.gd`, `src/ui/part_shelf.gd`,
`src/assembly/carry.gd`, `src/ai/techniques.gd` (an LDraw view of each),
`src/ui/part_thumbnails.gd`.

**Proof:** a probe opens the tab and drops "window in a wall" onto a wall.
The check passes, and the brick count rises by the technique's part count.

### 11. Find a part from a photo

*Brickit recognises about 1,600 shapes in a pile [brickit-abc], and
Rebrickable built RebrickNet [rb-wiki]. Neither runs inside a CAD.*

"What is this piece?" is the most common question a builder has.
Brickognize's API is public and accepts calls from any origin. It has
`/predict/parts/`, which answers with BrickLink numbers
[brickognize-api].

**Spec.**
- A camera button in the parts bin's search field opens the picker that
  `src/net/pick_image.gd` already provides. On a phone it takes a photo; on
  a desktop it opens a picture.
- The browser posts the picture to `api.brickognize.com/predict/parts/`.
- The top matches are mapped from BrickLink numbers to LDraw through the
  numbers Properties already shows. They appear as the bin's results, each
  with its confidence, and can be added to the collection.
- `connect-src` in the content security policy (`tools/deploy.sh`) gets
  the API's origin.
- Check Brickognize's terms of service before shipping [brickognize-tos].
  If they ask for server calls, add `api/identify.js` with a rate limit.

**Touches:** `src/ui/parts_bin.gd`, `src/net/pick_image.gd`,
`src/parts/part_library.gd` (BrickLink to LDraw), `tools/deploy.sh` (the
CSP).

**Proof:** a browser flow gives it a photo of a 3001 (a new fixture under
`tests/fixtures/`), and Brick 2 x 4 comes first.

### 12. Instruction page design: a view per step, page breaks, new parts marked

*Trails Studio's Page Design [st-im] [st-callout].*

**Done (2026-10-17):** each step's view, zoom, size, page breaks and parts
list, saved as `0 ROTSTEP` and `0 !BRICKWORKS` lines; the page laid out by
hand (pictures, parts lists, callouts and numbers dragged, sized and
snapped, words and pictures added); new parts outlined, on by default
(`mark_new`, now a band outside the ink line). See docs/INSTRUCTIONS.md,
"The page by hand". The spec below is kept as it was asked.

The booklet is generated well, with callouts, turn signs, arrows and
element numbers, but nobody can change it. Studio lets a designer set a
step's camera, break a page and mark new parts. Brickworks already has
`mark_new` in its ink shader, switched off (`src/render/booklet_studio.gd`).

**Spec.** This depends on item 1.
- Each step can keep a view (one of eight turns and a tilt), a scale, and
  "start a new page".
  - These are written as `0 ROTSTEP`, the MLCad convention LDraw tools
    widely read, plus a `0 !BW` meta for scale and page breaks.
  - Brickworks reads both back.
- In the timeline, *This step's view* sets the view from the current
  camera, and *New page here* breaks the page.
- The booklet gets *Mark new parts* (`mark_new`).
- `Booklet.lay_out` honours the breaks.

**Touches:** `src/parts/ldr_model.gd`, `src/render/booklet_maker.gd`,
`src/render/booklet_studio.gd`, `src/assembly/booklet.gd`,
`src/ui/steps_bar.gd`.

**Proof:** `booklet_probe` runs a model with two `ROTSTEP`s and one break.
The page count rises by one, and the turned step's picture differs from the
default.

### 13. Gear trains that turn together when posed

*LDCad can animate a mechanism, but only by writing a Lua script
[ld-script]. Studio, Mecabricks and LeoCAD pose by hand. No tool turns a
gear train from one handle.*

Pose and animate (`src/assembly/pose.gd`) gives each hinge or turntable its
own slider. Technic builders want to turn the crank and watch the gears and
everything they carry follow.

**Spec.**
- Find gears by their catalogue names ("Technic Gear 24 Tooth…"), with
  tooth count n. Cover the spur family (8, 12, 16, 20, 24, 36, 40), whose
  pitch radius is n/16 studs.
- Two gears mesh when their axles are parallel and their centres are
  (n1+n2)/16 studs apart, within 0.05.
- Turning one gear's joint turns each gear meshed with it by −n1/n2. Gears
  on the same axle turn together, through the axle-in-bore joints `Joints`
  already finds.
- The pose panel shows *Driven by* with the train, and an animation keys
  only the driver.
- Bevel and worm gears are not in this first version, and the panel says so.

**Touches:** `src/assembly/pose.gd` (`Poser.transforms_for`),
`src/assembly/joints.gd`, `src/ui/pose_panel.gd`.

**Proof:** a probe with an 8-tooth gear driving a 24-tooth gear on a beam
turns the 8 through 360°. The 24 reads −120°.

### 14. An accessibility pass

*No tool surveyed shows any evidence of accessibility work. Reviews of
LEGO's own app say VoiceOver reads unlabeled buttons [legobuilder].*

Godot 4.5 and later speak to screen readers through AccessKit on the
desktop [godot45]. Brickworks sets no accessible names and has no interface
size setting (nothing in `src/ui`).

**Spec.**
- Settings gets *Interface size* (85–150%). It multiplies the factor from
  `Main._match_screen_density` and is kept in `shell_prefs`.
- Settings gets *Reduce motion*, which turns off the build animation, the
  shimmer placeholders and camera easing.
- Every toolbar button, menu item, palette swatch and part tile gets an
  `accessibility_name`: its words and key, the colour's name, or the part's
  title.
- The edit bar and the parts grid join the keyboard focus order, so Tab
  reaches them.
- Status-line messages go to a live region.
- Test whether AccessKit reaches a screen reader in the WebAssembly build,
  which is unknown, and record the answer either way.

**Touches:** `src/ui/shell.gd`, `src/ui/toolbar.gd`, `src/ui/parts_bin.gd`,
`src/ui/shell_prefs.gd`, `src/main.gd`, `src/render/build_playback.gd`.

**Proof:**
- A probe walks the scene tree and fails on any visible `Button` without
  an accessible name.
- On the desktop, a screen reader (Orca on Linux) is recorded saying
  "Select, V" on focus.

### 15. New parts every month, without the 90-minute rebuild

*Studio added about 790 parts across 2.26.1 to 2.26.4 [st-rn], and the LDraw
library and its unofficial tracker grow every month.*

**Done, 2026-10-22** (`tools/update_parts.py`; the recipe is "update the
parts" in `.claude/skills/verify/features/pipeline.md`). As specified, with
two changes. It compares with the library rather than the catalogue: the
catalogue keeps no source hashes, and the library on disk is what it was
built from, which the tool keeps true by changing both together. And it
uploads nothing: `tools/storage_parts.py` and `tools/storage_ldraw.py` do,
and every deploy runs the first anyway. Today's unofficial zip took 194 s
for 205 parts (81 new), the 2026-09 update on a library one release behind
723 s for 462, each part byte for byte the full build's. The proof is
`src/dev/new_parts_probe.gd`, which finds three new parts in the bin and
places them, in a window rather than a browser.

Brickworks already carries 4,735 unofficial parts (`catalogue.json`). But
refreshing them means the full mesh build: about 90 minutes, then
`refresh_catalogue`. So new sets' parts arrive late.

**Spec.**
- `tools/update_parts.py` fetches LDraw's update and unofficial zips and
  compares them with the catalogue by file hash.
- It builds only the parts that are new or changed, plus the parts that
  include them, through `tools/build_custom.py`'s path, which takes seconds
  a part.
- It then refreshes the catalogue, packs the web parts and uploads them to
  the bucket. Names are content-hashed, so older builds keep working.
- It prints "N new parts: …" for `CHANGELOG.md`.
- `docs/RELEASING.md` gets a monthly line to run it. It is not a cron job,
  because uploads cost money.

**Touches:** a new `tools/update_parts.py`, `tools/build_custom.py`,
`tools/refresh_catalogue.py`, `tools/fetch_data.sh`.

**Proof:**
- Run against a library one release behind, the parts added in the next
  release appear in `catalogue.json`.
- A browser flow finds one of them in the bin and places it.

## Sections: one at a time

Builders build a section at a time, as a set's bags come. Studio has
sub-models: made from a selection (`Ctrl+G`), cloned with the clones
following, released, kept in palettes and in the step list [st-submodel].
Its help page on them describes no way to suggest them, no view that pulls
one away from the model or all of them apart, and no check of one on its
own (read 2026-10-17). Brickworks suggests sections from the booklet planner and
the build check's joint graph, breaks one out and puts it back to the bit,
draws them all apart, and weighs one alone: parts, weight, one piece,
balance, the joints that hold it, its own booklet ([sections]).

## Considered and not ranked

Each of these is real. Each was left out because it costs too much, the fix
lies outside this code, or the decision is the owner's.

- **A path tracer of our own.** Godot has none. Studio got its renderer by
  building Eyesight from Cycles [st-wiki]. Exporting glTF (item 7) puts
  Cycles one import away, and Render stays the quick picture.
- **BrickLink prices in the app.** BrickLink's API wants a seller's keys and
  agreement to its terms ([collection]). Studio is BrickLink's own app, so
  this stays a gap until someone holds those keys. Rebrickable can push a
  list to BrickOwl [rb-bl]; BrickOwl's API terms were not checked.
- **A native iPad app.** The web build already runs on a tablet. Measure it
  on one before building anything.
- **Letting people in without signing in.**
  - LeoCAD, LDCad and Bricksmith ask for no account at all [lc-home]
    [ld-download] [bs-home]. Brickworks shows a sign-in screen first.
  - The owner chose that (`HANDOFF.md`, 2026-10-11). It is likely the
    largest single loss of first visits, so it is worth deciding again with
    numbers rather than keeping it as a default.
- **Rubber bands and springs as flexible parts** (LDCad [ld-meta]). They
  are few next to hoses and chains. Add them when someone asks.
- **The name.** A $2.99 LDraw viewer called "Brickworks", last updated in
  2017, is still on the Mac App Store [name-clash]. This matters only if
  this Brickworks goes to that store.

## Sources

Brickworks' own claims link into this repository.

[building]: ../.claude/skills/verify/features/building.md
[sections]: SECTIONS.md
[geometry]: ../.claude/skills/verify/features/geometry.md
[parts]: ../.claude/skills/verify/features/parts.md
[model-io]: ../.claude/skills/verify/features/model-io.md
[cadtask]: CADTASK.md
[assistant]: ../.claude/skills/verify/features/assistant.md
[view]: ../.claude/skills/verify/features/view.md
[web]: ../.claude/skills/verify/features/web.md
[account]: ../.claude/skills/verify/features/account.md
[together]: TOGETHER.md
[elements]: ../.claude/skills/verify/features/elements.md
[mcp]: ../.claude/skills/verify/features/mcp.md
[release]: ../.claude/skills/verify/features/release.md
[minifig]: ../.claude/skills/verify/features/minifig.md
[brickify]: ../.claude/skills/verify/features/brickify.md
[prints]: ../.claude/skills/verify/features/prints.md
[collection]: ../.claude/skills/verify/features/collection.md
[stability.gd]: ../src/assembly/stability.gd
[README]: ../README.md

The rest, by tool. The links were read while this was written, except
Rebrickable's and LEGO.com's pages: those refuse automated readers, so
those claims rest on search summaries of the linked page. Recheck those
by hand.

**BrickLink Studio:**
[st-rn] release notes ·
[st-wiki] Wikipedia ·
[st-snap] snapping ·
[st-connect] Connect tool ·
[st-rotate] rotation and hinges ·
[st-collide] collision ·
[st-search] part search ·
[st-colors] colours ·
[st-validator] colour validator ·
[st-submodel] submodels ·
[st-stepedit] Step Editor ·
[st-im] Instruction Maker ·
[st-callout] callouts ·
[st-bom] bill of materials ·
[st-divide] Divide into steps ·
[st-im-export] instruction export ·
[st-eyesight] Eyesight ·
[st-pov] POV-Ray ·
[st-anim] animation ·
[st-stab] stability check ·
[st-flex] Flex tool ·
[st-flex-forum] flex complaints ·
[st-pd] PartDesigner ·
[st-pd-decal] decals ·
[st-import] import ·
[st-export] export ·
[st-bt] Build Together ·
[st-gallery] Gallery ·
[st-price] prices ·
[st-wanted] wanted list ·
[st-collection] My Collection ·
[st-platform] system requirements ·
[st-nav] navigation ·
[st-keys] shortcuts ·
[st-tutorial] tutorial ·
[st-video] official video ·
[st-sculpture] Sculpture ·
[st-signin] LEGO account sign-in ·
[st-amd] NVIDIA-only GPU rendering ·
[st-wine-lutris] Studio under Wine

**Mecabricks:**
[mb-home] site ·
[mb-brickset-build] Brickset: building ·
[mb-farm] Brickset: render farm ·
[mb-partmgr] Brickset: Part Manager ·
[mb-addon] Blender add-on ·
[mb-ldraw] its own library ·
[mb-flex] flexible parts ·
[mb-eb4] Eurobricks thread, 2013 ·
[mb-eb9] Eurobricks thread, 2020 ·
[mb-model] a public model page ·
[mb-nocustom] no custom shapes ·
[mb-online] online only ·
[mb-collision] collision request, 2026 ·
[mb-patreon] Patreon ·
[mb-lddimport] LDD import ·
[mb-tablet] tablets ·
[mb-render-compare] renderer comparison

**LDD:**
[ldd-wiki] Wikipedia ·
[ldd-lugnet] 2003 review ·
[ldd-blog] 2018 update ·
[ldd-modes] modes ·
[ldd-order] build order ·
[ldd-guide] Building Guide ·
[ldd-flex] Flex tool ·
[ldd-custom] custom bricks ·
[ldd-ldraw] LDraw mapping ·
[ldd-big] large models ·
[ldd-requests] feature requests ·
[ldd-end] discontinued

**LeoCAD:**
[lc-home] site ·
[lc-releases] releases ·
[lc-2609] 26.09 ·
[lc-history] history ·
[lc-tutorial] tutorial ·
[lc-library] library ·
[lc-cli] command line ·
[lc-noconn] no connectivity ·
[lc-texmap] textures ·
[lc-datsville] Datsville notes ·
[lc-download] download ·
[lc-docs] docs ·
[collision-2016] no tool detects collisions, 2016

**LDCad:**
[ld-download] download ·
[ld-features] features ·
[ld-advedit] advanced editing ·
[ld-meta] meta and flexible parts ·
[ld-keys] keys ·
[ld-script] script API ·
[ld-gui] interface ·
[ld-17b1] 1.7 beta 1 ·
[ld-snap] snapping, by its author ·
[ld-faq] FAQ ·
[ld-steps] steps ·
[ld-rb] Rebrickable part bins ·
[ld-collide] collision script ·
[ld-mac] macOS ·
[ld-docs] docs

**Bricksmith:**
[bs-home] site ·
[bs-history] version history ·
[bs-lsynth] LSynth ·
[bs-files] releases ·
[bs-nudge] nudging complaint ·
[bs-changelog] changelog

**Web, mobile and collection:**
[brickhub] BrickHub ·
[brickhub-model] a BrickHub model ·
[bijs] buildinginstructions.js ·
[ldraw-viewer] LDraw.org viewer ·
[legobuilder] LEGO Builder app ·
[legobuilder-site] LEGO Builder ·
[brickit-app] Brickit app ·
[brickit-abc] Brickit tested ·
[rb-wiki] Rebrickable on Wikipedia ·
[rb-api] Rebrickable API ·
[rb-build] Build engine ·
[rb-moc] MOC instructions ·
[rb-viewer] instruction viewer ·
[rb-import] importing ·
[rb-bl] BrickLink export ·
[rb-plans] plans ·
[rb-virtual] virtual building ·
[pab] Pick a Brick upload ·
[brickognize-api] Brickognize API ·
[brickognize-tos] Brickognize terms ·
[name-clash] "Brickworks" on the Mac App Store

**AI:**
[bgpt-paper] BrickGPT paper ·
[bgpt-site] BrickGPT site ·
[bgpt-code] BrickGPT code ·
[bgpt-demo] BrickGPT demo ·
[stable] STABLE ·
[brickanything] BrickAnything ·
[resembrick] ResemBrick ·
[legoace] LegoACE ·
[bricknet] BrickNet ·
[bb-paper] BrickBench paper ·
[bb-site] BrickBench site ·
[brickagent] BrickAgent ·
[bforger] BrickForgerAI ·
[bforger-ph] BrickForgerAI on Product Hunt ·
[mosaic40179] LEGO Mosaic Maker ·
[tripo] Tripo stylisation ·
[legomcp] lego-mcp ·
[godot45] Godot 4.5 (AccessKit)

[st-rn]: https://www.bricklink.com/v3/studio/download.page
[st-wiki]: https://en.wikipedia.org/wiki/BrickLink_Studio
[st-snap]: https://studiohelp.bricklink.com/hc/en-us/articles/5412087360919
[st-connect]: https://studiohelp.bricklink.com/hc/en-us/articles/6481651047319
[st-rotate]: https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351
[st-collide]: https://studiohelp.bricklink.com/hc/en-us/articles/5412820155927
[st-search]: https://studiohelp.bricklink.com/hc/en-us/articles/6502499385111
[st-colors]: https://studiohelp.bricklink.com/hc/en-us/articles/5459441964695
[st-validator]: https://studiohelp.bricklink.com/hc/en-us/articles/6501160941591
[st-submodel]: https://studiohelp.bricklink.com/hc/en-us/articles/5625432131863
[st-stepedit]: https://studiohelp.bricklink.com/hc/en-us/articles/5626973531287
[st-im]: https://studiohelp.bricklink.com/hc/en-us/articles/5626403887511
[st-callout]: https://studiohelp.bricklink.com/hc/en-us/articles/5679958311191
[st-bom]: https://studiohelp.bricklink.com/hc/en-us/articles/5681358947095
[st-divide]: https://studiohelp.bricklink.com/hc/en-us/articles/7123910550039
[st-im-export]: https://studiohelp.bricklink.com/hc/en-us/articles/5628123432215
[st-eyesight]: https://studiohelp.bricklink.com/hc/en-us/articles/6505772624023
[st-pov]: https://studiohelp.bricklink.com/hc/en-us/articles/6506022103447
[st-anim]: https://studiohelp.bricklink.com/hc/en-us/articles/6507015818263
[st-stab]: https://studiohelp.bricklink.com/hc/en-us/articles/6501498505111-Stability-check
[st-flex]: https://studiohelp.bricklink.com/hc/en-us/articles/6481921905303
[st-flex-forum]: https://www.eurobricks.com/forum/forums/topic/195433-handling-of-bendable-flexible-parts-in-bricklink-studio
[st-pd]: https://studiohelp.bricklink.com/hc/en-us/articles/5872512112663
[st-pd-decal]: https://studiohelp.bricklink.com/hc/en-us/articles/5877861085079
[st-import]: https://studiohelp.bricklink.com/hc/en-us/articles/6502277722647
[st-export]: https://studiohelp.bricklink.com/hc/en-us/articles/6502197862679
[st-bt]: https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767
[st-gallery]: https://studiohelp.bricklink.com/hc/en-us/articles/5705436653847
[st-price]: https://studiohelp.bricklink.com/hc/en-us/articles/5705572363159
[st-wanted]: https://studiohelp.bricklink.com/hc/en-us/articles/5705925898135-Upload-as-a-Wanted-List
[st-collection]: https://studiohelp.bricklink.com/hc/en-us/articles/20062101879447
[st-platform]: https://studiohelp.bricklink.com/hc/en-us/articles/5404381697559
[st-nav]: https://studiohelp.bricklink.com/hc/en-us/articles/5409213150487
[st-keys]: https://studiohelp.bricklink.com/hc/en-us/articles/5706320095255
[st-tutorial]: https://studiohelp.bricklink.com/hc/en-us/articles/6476848743447
[st-video]: https://www.youtube.com/watch?v=4ekcte_3Ow4
[st-sculpture]: https://studiohelp.bricklink.com/hc/en-us/articles/6508264220183
[st-signin]: https://studiohelp.bricklink.com/hc/en-us/articles/35041828645143-Studio-v-2-25-9-Critical-Update-released
[st-amd]: https://www.eurobricks.com/forum/forums/topic/185909-studio-gpu-rendering-with-amd-gpu
[st-wine-lutris]: https://lutris.net/games/bricklink-studio
[mb-home]: https://mecabricks.com/
[mb-brickset-build]: https://brickset.com/article/52336/let-s-build-in-mecabricks
[mb-farm]: https://brickset.com/article/52611/mecabricks-the-render-farm
[mb-partmgr]: https://brickset.com/article/53013/mecabricks-the-part-manager
[mb-addon]: https://www.mecabricks.com/en/shop/product/4
[mb-ldraw]: https://forums.ldraw.org/post-38924.html
[mb-flex]: https://www.eurobricks.com/forum/forums/topic/170705-mecabricks-new-flexible-part-tools
[mb-eb4]: https://www.eurobricks.com/forum/forums/topic/69050-software-mecabricks-online-design-tool/page/4
[mb-eb9]: https://www.eurobricks.com/forum/forums/topic/69050-software-mecabricks-online-design-tool/page/9
[mb-model]: https://mecabricks.com/en/models/7l2BlMpnv0N
[mb-nocustom]: https://www.mecabricks.com/en/forum/topic/4504
[mb-online]: https://www.mecabricks.com/en/forum/topic/2638
[mb-collision]: https://www.mecabricks.com/en/forum/topic/76253
[mb-patreon]: https://www.patreon.com/mecabricks/membership
[mb-lddimport]: https://forums.ldraw.org/post-27390.html
[mb-tablet]: https://www.eurobricks.com/forum/forums/topic/103517-digital-tools-for-tablets
[mb-render-compare]: https://www.eurobricks.com/forum/forums/topic/166074-comparison-of-lego-rendering-engines/page/2
[ldd-wiki]: https://en.wikipedia.org/wiki/Lego_Digital_Designer
[ldd-lugnet]: https://news.lugnet.com/cad/?n=10408
[ldd-blog]: https://thebrickblogger.com/2018/03/lego-digital-designer-2018-update
[ldd-modes]: https://www.eurobricks.com/forum/forums/topic/75324-difference-between-standard-and-extended-modes
[ldd-order]: https://www.eurobricks.com/forum/forums/topic/157337-ldd-changing-building-order
[ldd-guide]: https://www.eurobricks.com/forum/forums/topic/147343-help-exporting-lego-directions
[ldd-flex]: https://www.eurobricks.com/forum/forums/topic/78351-accurate-way-to-use-the-flex-tool
[ldd-custom]: https://www.eurobricks.com/forum/forums/topic/170286-custom-ldd-bricks-and-fixes/page/104
[ldd-ldraw]: https://forums.ldraw.org/thread-4028.html
[ldd-big]: https://www.eurobricks.com/forum/forums/topic/172319-ldd-4311-max-of-pieces/
[ldd-requests]: https://www.eurobricks.com/forum/forums/topic/35736-key-topic-ldd-feature-requests
[ldd-end]: https://www.brothers-brick.com/2022/01/12/lego-fully-discontinuing-lego-digital-designer-in-favor-of-bricklink-studio
[lc-home]: https://www.leocad.org/
[lc-releases]: https://github.com/leozide/leocad/releases
[lc-2609]: https://github.com/leozide/leocad/releases/tag/v26.09
[lc-history]: https://www.leocad.org/docs/history.html
[lc-tutorial]: https://www.leocad.org/docs/tutorial1.html
[lc-library]: https://www.leocad.org/docs/library.html
[lc-cli]: https://www.leocad.org/docs/cli.html
[lc-noconn]: https://github.com/leozide/leocad/issues/841
[lc-texmap]: https://www.leocad.org/docs/texmap.html
[lc-datsville]: https://github.com/mjhorvath/Datsville/wiki/Software-Notes
[lc-download]: https://www.leocad.org/download.html
[lc-docs]: https://www.leocad.org/docs/start.html
[collision-2016]: https://www.eurobricks.com/forum/forums/topic/143937-detection-of-colision
[ld-download]: http://www.melkert.net/LDCad/download
[ld-features]: http://www.melkert.net/LDCad/features
[ld-advedit]: http://www.melkert.net/LDCad/docs/advEdit
[ld-meta]: http://www.melkert.net/LDCad/tech/meta
[ld-keys]: http://www.melkert.net/LDCad/docs/keys
[ld-script]: http://www.melkert.net/LDCad/docs/scriptAPI
[ld-gui]: http://www.melkert.net/LDCad/docs/gui
[ld-17b1]: https://forums.ldraw.org/post-51059.html
[ld-snap]: https://forums.ldraw.org/post-54435.html
[ld-faq]: http://www.melkert.net/LDCad/faq
[ld-steps]: https://forums.ldraw.org/post-24178.html
[ld-rb]: https://forums.ldraw.org/post-36851.html
[ld-collide]: https://forums.ldraw.org/post-44312.html
[ld-mac]: https://forums.ldraw.org/post-40896.html
[ld-docs]: http://www.melkert.net/LDCad/docs
[bs-home]: https://bricksmith.sourceforge.io/
[bs-history]: https://bricksmith.sourceforge.io/VersionHistory.html
[bs-lsynth]: https://bricksmith.sourceforge.io/LSynth.html
[bs-files]: https://sourceforge.net/projects/bricksmith/files/
[bs-nudge]: https://www.eurobricks.com/forum/forums/topic/172918-confusion-and-problems-with-bricksmith-and-ldraworg
[bs-changelog]: https://mac.softpedia.com/progChangelog/Bricksmith-Changelog-9135.html
[brickhub]: https://brickhub.org/
[brickhub-model]: https://brickhub.org/i/1216
[bijs]: https://github.com/LasseD/buildinginstructions.js
[ldraw-viewer]: https://library.ldraw.org/model-viewer
[legobuilder]: https://apps.apple.com/us/app/lego-builder-3d-instructions/id1486159728
[legobuilder-site]: https://www.lego.com/en-us/builder-app
[brickit-app]: https://apps.apple.com/us/app/brickit-your-brick-collection/id1477221636
[brickit-abc]: https://www.abc15.com/brickit-app-for-building-legos
[rb-wiki]: https://en.wikipedia.org/wiki/Rebrickable
[rb-api]: https://rebrickable.com/api/
[rb-build]: https://rebrickable.com/help/build-engine/
[rb-moc]: https://rebrickable.com/help/types-of-moc-building-instructions/
[rb-viewer]: https://rebrickable.com/blog/274/new-features-for-moc-instructions/
[rb-import]: https://rebrickable.com/help/importing-parts/
[rb-bl]: https://rebrickable.com/help/bricklink/
[rb-plans]: https://rebrickable.com/plans/
[rb-virtual]: https://rebrickable.com/help/virtual-building/
[pab]: https://www.newelementary.com/2024/10/pick-brick-new-upload-feature-now-live.html
[brickognize-api]: https://api.brickognize.com/openapi.json
[brickognize-tos]: https://brickognize.com/terms-of-service/
[name-clash]: https://apps.apple.com/us/app/brickworks/id1176177802?mt=12
[bgpt-paper]: https://arxiv.org/html/2505.05469v3
[bgpt-site]: https://avalovelace1.github.io/BrickGPT/
[bgpt-code]: https://github.com/AvaLovelace1/BrickGPT
[bgpt-demo]: https://huggingface.co/spaces/cmu-gil/BrickGPT-Demo
[stable]: https://arxiv.org/html/2605.06947v1
[brickanything]: https://arxiv.org/abs/2605.26182
[resembrick]: https://arxiv.org/html/2608.09597v1
[legoace]: https://huggingface.co/VAST-AI/LegoACE
[bricknet]: https://arxiv.org/html/2604.22984v1
[bb-paper]: https://arxiv.org/html/2610.12452v1
[bb-site]: https://brickben.ch
[brickagent]: https://github.com/kulits/BrickAgent
[bforger]: https://brickforgerai.com
[bforger-ph]: https://www.producthunt.com/posts/1239306
[mosaic40179]: https://www.lego.com/en-us/product/40179
[tripo]: https://www.tripo3d.ai/features/ai-model-stylization
[legomcp]: https://github.com/Axel-Jalonen/lego-mcp
[godot45]: https://godotengine.org/releases/4.5/index.html
