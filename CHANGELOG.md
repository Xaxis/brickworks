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

- LDCad's hoses, ropes, strings and bands are drawn: each as one piece,
  from the file's own lines, in its colour and step, to click and hide.
  They used to be kept in the file but left out of the view.
- New chat for this tab, in Account and the assistant panel: Claude opens
  on a new chat whose first message names the tab, in claude.ai, the
  Claude app or Claude Code. That chat builds in this tab and no other.
- Each window says which Claude chat is working in it, on the toolbar and
  in Account. When two chats work in one, it says so, and Keep this one
  moves the other off.

### Changed

- With several tabs or windows open, a new Claude chat that has not chosen
  one asks before its first change, listing them. It used to build in the
  tab used last, which could be the one another chat was building in.
- Claude finds a tab by its model's name as well as its id: "the castle
  tab".

- In a browser, the parts a file carries are built and shown: the LEGO®
  Technic set 42082 leaves out 3 parts instead of 167. The download is
  about 1.4 MB larger for it.
- A part in hand keeps up over a big model. Aiming a brick over the
  4,139 parts of set 42082 took up to 747 ms a move; it takes about 2 ms.
  A pin or a sticker in hand asks only the parts near the pointer.
- A file opened straight after a big one opens at once. Set 8202 after
  42082 waited 12 s for the status bar to finish weighing 42082; it now
  opens in 1.5 s, and the new model is weighed after.

## [0.3.0] - 2026-10-16

A release about the whole craft. A model can be rendered, shared by
link, laid out as an instruction booklet whose steps build as drawn,
posed and animated, printed and stickered, brickified from a 3D file,
laid from a picture as Brick Art, and exported to Studio, BrickLink, Rebrickable or a 3D
program. A file another program wrote comes back exactly as it went in,
and a 4,000-part set stays quick to select, undo and step through.
Building by hand from a booklet takes fewer actions, and with the
assistant switched off nothing of it is missing. Claude, on your plan,
shows the model in 3D beside its answers and builds characters on real
joints. Models saved by 0.2.0 open in 0.3.0 unchanged.

### Added

- Characters with faces. A person's or a head's eyes, an animal's eyes on
  the sides of its head and its nose, joints covered in the body's colour,
  and a torso that leans forward, back or to the side.

- A part on a round joint swings to join the part its other end meets,
  as Studio turns a part to fit: R steps through it and T lands on it, so
  a Technic link at 66 degrees goes where the set has it.

- Building from a booklet takes fewer actions. E makes the parts put down
  since the last step into a step of their own, one undo. Shift-C opens a
  colour field: type a name or a number and the line above the palette
  names the colour it will take, so the old greys are a few letters away.

- Figures on joints. Ask for a person, an animal or a head and it is laid
  on working joints, posed as asked, and a character built as a stack is
  sent back once to be jointed. Judged blind against real LEGO® sets on
  subjects no one tuned on, these designs were preferred to the last
  release's on every count.

- The model in Claude, in 3D. Where Claude shows Brickworks beside its
  calls (claude.ai and the Claude apps), the card is the real model now,
  in the parts' own shapes and colours, not four pictures of it: drag to
  turn it, zoom, and click a part to pick it. Claude is told which brick
  you picked, and it is selected in your Brickworks tab, so "make this
  blue" means that one. Check tints the joints that would give way,
  Instructions steps through the booklet's steps, Parts lists the pieces
  with a BrickLink wanted list, full screen gives it the window, and Open
  in Brickworks goes to your tab. Opening a model or brickifying a 3D file
  shows the card too. It asks your tab for the model itself, so it shows
  the model whatever Claude's app hands it, and where a browser cannot
  draw in 3D it is the turntable of pictures it was.

- The parts nobody sees, coloured the way big sets colour them. Tools,
  Colour the hidden parts… finds every part that cannot be seen from any of
  128 sides of the finished model, and gives them a colour for each section,
  build stage or half, so you can tell where you are while you build, as the
  core of the LEGO® Eiffel Tower set is red one way and yellow the other.
  A few strong colours, in the order real sets use them (blue, yellow, red,
  green), each part only in a colour it is made in, never one the outside
  is made of or one a seen part beside it has; it shows the inside cut open
  first, it is one step to undo, and
  a real set's own colours are never changed without a yes. The booklet says
  each colour where its group starts. Claude offers it at the end of a big
  model built in sections, and `colour_hidden_parts` does it over MCP.
  docs/HIDDEN_COLOURS.md is the research and the measure of 1,500 real sets.

- Models that cannot vanish. Every save is kept as a version, the last 20
  of each model: File, Versions… opens any of them again. File, Export,
  All my models downloads every saved model in one .zip. In a browser,
  Brickworks asks the browser to keep its storage at your first save, and
  Account says whether it agreed. Where it would not, or in Safari, which
  deletes a site's data after seven days without a visit, a line above the
  model says so once, with Download my models. And a save with no parts in
  it never goes over a model that has some, unless you cleared it.

- A dome or a ball as one shape: Claude says `{"pattern": "shell", "kind":
  "dome" or "ball", "across": 24}` and the app lays a closed shell of
  hinged panels, as the LEGO® Death Star II set builds its own:
  twelve strips of panels on clip hinges, each band's panels sized to the
  round they are on, the strips taking turns so the higher ones lap the
  lower ones' edges, wedge plates tapering each panel toward the top, a lip
  over every seam between bands, a course of bricks closing the slot at
  the foot, and for the crown discs of plates stepping in under a dish. A
  dome is 20 to 32 studs across and a ball, on a stand with a course round
  its middle, 24 to 32. Domes built by hand from the guide's recipe left
  daylight between every strip and band; this one still shows slivers at
  some seams, up to a stud wide, and its crown steps like a stack of
  plates.
- Decorated parts, brought in and taken out. A BrickLink Studio file opens
  with its prints, its stickers and the parts made in Studio's Part Designer,
  each with its picture, where they used to be left out (set 31213's file now
  opens all 1,501 parts, its three Studio prints drawn); an .io saved here
  carries your own prints and stickers in Studio's form too (not yet seen
  opening in Studio itself). Any part the LEGO Group printed or put a sticker
  on can be swapped for one of those versions: Edit, Printed versions…, on a
  part's right-click menu, or under its name in Properties. LDraw's own
  stickers go on the face they are put on, lying on it. And Claude can print
  a picture handed over as its own data, base64 or a data: URI, not only a
  web link (print_part's picture_data, up to 2 MB), swap a part for a
  printed version (version=) and stick on one of LDraw's stickers
  (sticker_part=).

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

- Big files open in seconds: the LEGO® Technic set 42082, 4,139 parts, in
  about 3 seconds where it took 14, part for part the same model.
- A body built on real joints passes the check. On the real sets of
  LDraw's model repository it refused 3,361 joined pairs, a ball in its
  socket or a bar in its clip; it refuses 440 now, and still catches every
  true collision.
- Booklets a Technic builder can follow: a part held by a pin or an axle
  goes in after what holds it, and a model shown on its stand is built in
  its own frame. Parts put in under one already placed fell from 11% to 6%
  of steps on sets nobody tuned on.

- Brickify lays the whole model again, and quicker: all 28 test models
  whole in the smooth style, and the 40-stud bunny in about four fifths
  of the time it took.

- A file another program wrote comes back as it went in. Of 48 real sets'
  files from LDraw's model repository, every one is saved and reopened
  exactly: its author and licence, its part numbers as written, its
  coordinates, its steps, its sub-models and LDCad's flexible parts. A part
  this app cannot draw is kept in the file and named when it opens, never
  dropped. Saving a 7,909-part set takes a third of a second, not twelve
  minutes.

- Big models stay quick. On a 4,000-part set, selecting everything takes a
  tenth of a second, undoing a move of all of it half a second, and a step
  of the timeline a thirtieth. In a browser that undo was still running
  after fifteen minutes.

- The booklet's steps can be built as drawn: a part goes in only once what
  holds it is there, and never under one already placed. A section that
  touches nothing built before it gets a stage of its own.

- Brickify's colours read right. A grey or black model stays grey or black
  instead of turning brown or blue, and every part is in a colour it is
  really sold in, with its element number.

- The desktop app checks parts against their exact shapes, as the web
  build does, for every part a real set uses.

- The build check holds what real sets hold, measured against every set in
  the LDraw model repository (docs/CONNECTIONS.md): click hinges, a towball
  or a ball turned in its socket, and a clip turned to an odd angle on its
  bar now hold, and a model whose wheels stand a hair off the ground stands
  on them. Curved and concave parts — domes, quarter rings, dishes,
  windscreens, ring plates — collide as their shapes, not as solid boxes,
  so what real sets put inside one fits, and parts that meet on a seam at
  45 degrees no longer overlap there. attachment_points lists a part's bars
  and clips, and a part goes on a bar or a clip by axis and joint. A smooth
  dome 16 studs across is a worked construction (show_technique "smooth
  dome"), and a search for a dome says so.

- A model opened from another tool stands on the ground by its parts'
  shapes. A wheel drawn spun on its axle, a gear turned to mesh, stood the
  whole model on the corner of its box, up to 12 LDU in the air, and the
  check called every part floating; a model drawn up in the air comes down
  onto the ground (one this app saved keeps its height). A part a file
  carries is built from the subparts and primitives the file carries for
  it, where 1,401 such parts in real sets' files could not be built, and
  what stood on them floated. A part opened by a retired number is the new
  part where the old one put it: 3139 tyres came in as 3139b turned across
  their own axles, drawn right but checked and saved a quarter turn wrong.
  A part nobody has moved is checked where it stands, a figure's part at
  any angle among them, and a part pushed into another is held by it (a
  figure's arm swung off its socket's line still holds the hand and what
  it carries). A hose LSynth drew is one piece, as is a pneumatic tube
  with its ends. The older
  finger hinge plates (4275b, 4276b) hold by their fingers.

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

- The Wizard's Tower stands with no weak joints again. Its door's arch
  stood on one 1 x 1 each side, so once parts collided as their shapes the
  status bar said "8 weak joints (overloaded)": 83 to 85 g on studs that
  hold 80. A 1 x 2 across the wall under each foot of the arch now ties the
  jamb into the wall behind. A tower Claude designs gets the same tie at
  its door.

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

### Fixed

- Closing the app after opening a model of 600 parts or more no longer
  crashes it, and an edit made just before closing is kept.
- A booklet whose sub-assembly needs pages of its own is made whole, where
  it used to stop with an error.

- In a browser, a click puts the part where its ghost stood. Across a
  plate's edge 16 of 35 clicks used to land a stud forward or 2 LDU up;
  now none do.
- A scene with a character in it, a pyramid with its statues or a river
  with its creatures, is no longer sent back as a figure without joints.
- When Claude's call takes long enough to become a job, its answer keeps
  the picture and the 3D card, and the window no longer redraws a ticking
  clock while it waits.
- A mirrored copy of a sub-assembly reopens as the copy it was, not as
  the original.
- With a graphics card, the ground under a model with no floor is the
  background's grey, not a pale disc.

- Clip plates seat by their sockets, where their box used to put them a
  stud off.
- A clicked tile in the parts bin no longer keeps the arrow keys.
- A design no longer inherits the last one's subject: after a character, a
  car or a tower was being sent back as a figure.

- Brickify keeps the whole model. A leg, a spout or a wing thinner than a
  stud is laid a stud thick instead of never reaching the bricks, so a fox,
  a figure and an aircraft no longer come out with nothing. A piece apart is
  joined to the rest by a pillar or a plate across the joint, not dropped;
  what nothing can join is said, where and why. A model that would tip, or
  stands on legs or wheels a few studs wide, is laid on a stand, and the
  panel weighs it before it says "buildable". If a size lays nothing, the
  panel says the smallest that keeps it. Plates go down as 3023b, the number
  LDraw gives the commonest plate today, so parts lists find its element.
- Checking a big Technic model is quick again. Since parts are checked where
  they stand, a turned part's collision cover is hundreds of boxes, and a part
  a file carries can be tens of thousands (the drum of the 42112 concrete
  mixer, turned on its truck); every question of what touches what asked
  every box of one against every box of the other, and checking that set
  took 17 minutes. Only where two covers meet is asked now, by the rows of
  cells they cover: the same answers, and 42112 opens and checks in under a
  minute, 75144 in 23 s from 12 minutes.
- A big model no longer stutters twice a second with the model tree folded
  away: the tree was worked out whether or not it was showing, 30 to 40 ms
  of every half second on Orthanc and at every change to it, Brick Art's
  laying out and the Timeline's first step among them.
- In a browser drawing in software, the parts bin draws a screenful of its
  pictures in one frame of the model rather than four, so after a big model
  opens the screen is held for its pictures half as long; the page is told
  each hold, for the checks.
- The minifigure builder and What do I need? say they are working the first
  time they are opened, as the other slow commands do, and so do Versions,
  the cut-away, Make a sub-assembly, Copy and Settings on a big model.
- Stopping the Timeline on a big model while it lays the parts out in steps
  ended in a script error, and laying them out held the window for a step's
  worth of looking at a time, a quarter of a second on Orthanc in a browser;
  it gives the window back between the parts of a step now.
- A part turned round the upright to an angle that is not a quarter turn
  was accepted standing on several studs, which in plastic meet its tubes
  and walls and grip nothing. The check now says so, and accepts it on the
  one stud a part really swivels on: a round plate's, a jumper's centre
  stud, a turntable.

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
