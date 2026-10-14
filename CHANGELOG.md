# Changelog

What changed in each release of the desktop app, newest first. The web
build at brickworks.diy is deployed continuously and is not versioned
here; a desktop release is a snapshot of it, with the whole part library
inside so it works offline.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and versions follow [Semantic Versioning](https://semver.org/). New
entries go under `[Unreleased]`; `tools/release.py version --set X.Y.Z`
moves them into a section for the release. `docs/RELEASING.md` is the
whole cycle.

## [Unreleased]

### Added

- Parts and sections turned any way, held by real hinges. The properties
  panel has Tilt and Roll beside Turn, so a selection tips about its
  middle as well as turning round. A design can turn a section yaw, then
  pitch, then roll (or about any axis), build one section within another,
  repeat one round a centre with each copy turned on two axes, and hang a
  section on a tilting hinge, a clip on a bar or click hinge plates, both
  halves laid for it, the check holding it by its hinge. That is how a real
  set builds a dome or a sphere, from small flat panels on hinges, and a
  round band from skins built sideways: Claude can now do both, and is
  told how (read_guide "round", show_technique "hinged panels" and
  "sideways skins").

- Build by hand only: Settings, Assistant (AI) takes the assistant out of
  the window altogether — its column, Ask Claude about this… in the menus
  and on a part, Design with Claude in Brick Art, the Claude connector and
  its card in the tour — and switches the connector off with it. A first
  visit starts this way, on the parts bin, with one button, Show the
  assistant, that turns it on in one press; brickworks.diy/app?assistant=on
  opens with it on, and the site's links about Claude use that. A computer
  that has used Claude here keeps it. Turned on again, all of it comes back.
- Sketch first: a first design can begin with three quick sketches to
  choose between, so you see whether your brief was understood before a
  full design is paid for. Each is the model's main masses only, under 150
  parts, made in one go on a cheaper Claude, checked, and shown as a picture
  in the chat with what the three cost. Choose one and it goes on the
  baseplate, and the whole model is designed from it at the model and
  effort you chose. It is ticked beside Build it; untick it to go straight
  to a full design. Claude over the connector, My Claude and a session of
  your own can sketch too: `submit_design` with `sketch: true` answers
  with the three pictures, and `choose_sketch` picks one.
- Export the model as a 3D file: File, Export, 3D model… writes a GLB (the
  default), a glTF, an OBJ with its MTL, or an STL, at the model's real
  size, for Blender and other 3D programs, AR viewers and 3D printers. In a
  glTF every part is a node under a node for its sub-model, each shape is
  kept once however many times it is used, and each colour is a material
  with its alpha and its finish (chrome, metallic, pearl, rubber), so even
  the 9,429-part Wizard's Tower writes whole. The STL is one mesh in millimetres,
  standing on Z, for a slicer. OBJ and STL hold every triangle of every
  part, so they say how many they can take and point at GLB past it. In a
  browser it is a download (an OBJ and its MTL come as one zip); on the
  desktop it goes to Downloads. Claude can do it too, with export_model.
- Claude can do what you do from the menus, over the connector, My Claude
  and a session of your own: choose the floor, edit the build steps, lay a
  hose, tube or chain between two connectors, swing a hinge or a
  turntable and animate it, undo and redo, open one of your models, read the parts list
  and what your collection is short of, render a picture or a turntable,
  and export the model as LDraw, a Studio .io, a picture, a BrickLink or
  Rebrickable list, or its building instructions. Each change is one undo.
- Ask Claude about this…: select parts, right-click one (or Ctrl+K), and
  ask for a change to just those — "make this wing curved", "recolour
  this in tan", "why is this not stable?". Claude sees the parts, where
  they stand and pictures of them, and may change only them and a little
  room round them; it asks before reaching further. Everything else stays
  where it was, the model must still hold together, and the whole request
  is one undo. Works with your own key, with My Claude, and with Claude
  over the connector, which gets `selection` and `edit_selection` tools.
- A model's own build steps are kept. A Studio, LDCad, LeoCAD or Bricksmith
  model opened and saved here kept its parts and lost its designer's steps,
  which were replaced by the order Brickworks works out; now every part, and
  every sub-model with steps of its own, keeps its step through open, edit
  and save, as .ldr, .mpd and .io. The timeline opens such a model in
  Author's steps and the booklet follows them. Steps can be changed as in
  those tools: Edit, Build steps (Move to previous or next step, Shift-[ and
  Shift-]; New step from selection, Shift-N; a step earlier or later, merged
  with the next, or taken out), on the timeline too, each one undo.

- A floor of your choosing under every model (View, Floor; the properties
  with nothing selected): a baseplate 16, 32 or 48 studs square or any
  size in eights, in the colours baseplates come in; a grid floor with no
  plate, as Studio has; or nothing, as a car stands on a table. Saved
  with the model. The baseplate can be made part of the model, counted
  and in the booklet's first step. Settings says what new models start
  on, and the assistant chooses one for what it builds.
- Build it, on a shared model's link: the model as a step player for
  building it with real bricks, made for a phone or a tablet propped
  beside the pile and working on the desktop too. Full screen, a step at
  a time, with big Back and Next buttons and a swipe; what is already
  built drawn faded and the step's new parts in full colour and outlined;
  the step's parts along the bottom, a picture and "2x" each, as a
  booklet's callout; the model turned with one finger and zoomed with
  two. Each step opens on the side the booklet would draw it from. The
  step reached is kept for that link on that device, so a phone that
  sleeps comes back where it was.
- Building instructions laid out like a LEGO® instruction booklet, from the toolbar's
  new Instructions button (and the timeline's): landscape pages that
  print on A4 or Letter, a big number and a parts box with a picture of
  every part per step, several small steps to a page, every part outlined
  in ink, the model turned round with a sign when a step's parts are
  behind it, red arrows onto small parts, sub-assemblies and minifigures
  built in callouts ("2x") with an arrow to where they go, a cover, the
  finished model front and back, and the parts list by colour with
  element numbers. On the web it opens in a new tab, ready to print.
- File, Export, BrickLink Studio model (.io): the model, its build order
  and a picture of it, in the zip Studio opens its own files from. Not
  yet seen opening in Studio itself; what is inside is plain LDraw.
- Brick Art: Mosaic lays a picture the way a modern LEGO® Art set builds one —
  2 × 4 tiles in courses, round and quarter-round accents, raised up to
  six plates deep, a panel at a time — or as classic 1 × 1 plates. Claude
  can plan one too, look at it, and revise it.
- Hoses, tubes, strings and chains (Build, Hose, tube or chain…): laid
  along a path between the connectors you click, and reshaped later. A
  laid hose is counted as the one hose a shop sells.
- Pose and animate: a slider for every hinge, turntable and joint a
  sub-assembly turns on, and keyframes played as an animation.
- File, Render…: a picture or a turntable worth keeping, Quick, Good or
  Best, up to 4K, on a studio sweep with soft shadows.
- Share by link (File, Share…): a brickworks.diy/m/ link with a picture
  and a card wherever it is pasted, and a 3D viewer with the steps, the
  booklet and the parts list. Open in Brickworks copies it into your own
  models.
- My collection: the sets and parts you own — by set number, a Rebrickable
  or BrickLink file, or your Rebrickable account — kept with your account;
  what a model still needs, what could stand in, and which models you
  could build.
- Brickify: a 3D model in OBJ, STL or glTF laid in LEGO® bricks at the size
  you pick.
- Prints and stickers: draw a print or bring in a picture for any face of
  a part, or a sticker for a model, saved as real LDraw parts, and a
  model's sticker sheet printed at true size.
- File, Export: a BrickLink wanted list and a Rebrickable parts list. File,
  Import: LEGO® Digital Designer's .lxf.

### Changed

- Part search finds a printed part by what is printed on it: "porsche
  print", "control panel print", "wood grain print", or "3623 print" for
  every print of the 1 x 3 plate; "sticker" finds parts with stickers on.
  It reads a part's keywords too, so "porsche" finds the turbo printed on
  a Porsche, and the figure builder finds a torso by its character. Plain
  searches answer as before. Claude is told when a part it finds has
  prints.

- A BrickLink Studio .io opens in its own colours. It was read from the
  copy inside that uses BrickLink's colour numbers, so white came in blue.
  Files locked with AES open too, and a part only Studio has is named in
  the status bar instead of counted.

- The build order no longer puts anything in the air before the model
  reaches it (the Wizard's Tower: 193 parts to 6), puts wheels on last, and builds
  sub-models a file places as callouts. The timeline numbers its steps
  as the booklet does, and an 8,600-part model's order takes 5 s, not 87.

- Export › Picture, a shared link's picture and a Studio file's thumbnail
  put the model in the middle and fill the frame with it. They were framed
  on the box round the model, so a flat car sat low in its own picture and
  an L-shaped model off to one side.
- The mosaic mode that lays a picture like a LEGO® Art set is now called
  Brick Art, a name of our own. The app, the site and the designer
  write LEGO® as the LEGO Group's Fair Play policy asks, and its notice is
  in Help, About, on share pages and on every page of the site
  (docs/TRADEMARKS.md).

## [0.2.0] - 2026-10-11

A release about doing it right. Parts that are drawn inside their
footprint — wing plates, turntable tops, flags, plant leaves — now sit
squarely on their studs, and a model that puts anything a fraction of a
stud off is told so. Clips on bars, hinges and turntables are understood
as the joints they are, and a section that leans has to lean on one. The
minifigure builder offers every minifigure part there is. Claude, on your
plan, keeps building while you are in the chat. Models saved by 0.1.0
open in 0.2.0; parts of them drawn inside their footprint may have been
saved a tenth of a stud off their studs, and `src/dev/reseat.gd` moves
them back.

### Added

- The design assistant can give a building that stands floors and
  furnished rooms in one call (`add_rooms`): a library, a forge, a dungeon,
  a bedchamber and more, furnished from real sets' furniture, with stairs
  or ladders between them.
- Round joints: a clip on a bar, a bar in a hollow stud, a hinge's pin in
  its eye and a turntable's top on its base are joints, at any angle about
  their shared axis, and only there.
- `hinge: true` on a section: the assistant leans an assembly on a hinge
  brick in one line, the pin found for it.
- The minifigure builder offers all 4,263 minifigure parts: capes, visors
  and plumes, back gear, skirts and tails, footwear, a second hand, and
  every head, torso, hip and leg mould, each where real sets put it.
- Towers in one call: a prism with faceted piers clustered round its core,
  horns that end in square caps, lit windows up its faces, open at the back
  onto furnished floors.
- Worked examples of what real sets build: leaning on a hinge (6085's
  gatehouse flag), a corner on a turntable (10182 Cafe Corner), and more.

### Changed

- A placement's x and z are the corner of the whole studs a part stands
  on, so whole numbers seat every part on its studs.
- A part a fraction of a stud off the studs below it is a fault, with the
  place it would grip; a section that leans on nothing is refused.
- The pointer shows what a click will do, the controls are listed with
  their icons, and scrolling over a panel or dialog no longer moves the
  model behind it.
- Thumbnails show a placeholder until their picture arrives.
- The palette, links, tick boxes and the count over the model read more
  clearly.

### Fixed

- A sticker on an upright face, each bit of a string, hose, cable or chain,
  and cars coupled by magnets no longer count as pieces of their own. The
  check that says a model is "in 4 pieces", and Check stability, hold a
  sticker by the face it lies on and a flexible part where its ends are
  fixed. A brick touching nothing is still loose. And a vehicle with its
  driver in it is no longer let stand apart as "a figure".
- Wing plates, turntable tops, flags, antennas and plant leaves placed at
  whole studs stood a tenth of a stud off the studs below them.
- Every model opens standing on the ground.
- A reopened model keeps its saved name instead of "Untitled".

## [0.1.0] - 2026-10-10

The first desktop release: Brickworks for Linux, macOS and Windows, with
all 28,319 parts on disk, so building, saving and the instructions need
no network at all. Designing with Claude still does, on your own API key
or Claude plan. The macOS and Windows builds are not yet signed by Apple
or Microsoft, so each asks once before it first opens, and the steps for
that are beside each download.

### Added

- Every part in the LDraw library that can be placed, at true size on a
  2 LDU lattice: 28,319 parts in 322 colours, searchable by name, number
  and the sets they came in.
- Building by hand: place against any face, box select, paint, nudge,
  rotate, lift and move, undo and redo, and a build timeline to drag
  along or play either way.
- Designing with Claude from a sentence, on an Anthropic API key of your
  own or your own Claude plan through Connect Claude. The key goes only to
  Anthropic.
- Build steps recovered from the geometry, a parts list by colour (CSV),
  printable instructions, photo mosaics, and LDraw `.ldr` / `.mpd` in and
  out.
- An MCP port (`--mcp`) so a Claude Code session can drive the app.
- The version in the window title and in Help (`,`), and `--about` on the
  command line, so a downloaded build can say which release it is.
