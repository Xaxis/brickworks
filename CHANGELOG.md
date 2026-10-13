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

- A BrickLink Studio .io opens in its own colours. It was read from the
  copy inside that uses BrickLink's colour numbers, so white came in blue.
  Files locked with AES open too, and a part only Studio has is named in
  the status bar instead of counted.

- The build order no longer puts anything in the air before the model
  reaches it (Orthanc: 193 parts to 6), puts wheels on last, and builds
  sub-models a file places as callouts. The timeline numbers its steps
  as the booklet does, and an 8,600-part model's order takes 5 s, not 87.

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
