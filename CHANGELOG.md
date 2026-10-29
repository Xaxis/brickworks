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

- Designing with another provider's model on your own key, the first part of
  it. A model on OpenAI, or on any server that speaks OpenAI's Chat
  Completions (OpenRouter, Groq, Together, Mistral, DeepSeek, Gemini, or Ollama,
  LM Studio and vLLM on your own computer), is given the same instructions
  and tools Claude is, builds in the window, and answers the same fresh look
  at its first save. Your key goes from your computer to the provider and
  nowhere else. From the command line for now (`--ask-provider`); the
  settings to choose a provider in the app come next (docs/PROVIDERS.md).
- The LDraw library on the website, at brickworks.diy/library: every model
  of a real set the app's Library opens, browsed as the gallery is, by a
  set's name, number, theme or modeller, its themes as pills and its order,
  size and years in Filters. Each set has a page of its own, as a shared
  model has: its picture, who modelled it for LDraw's Official Model
  Repository and under which licence, its parts list, Share, and Open in
  Brickworks, which opens it in the app as File, Library… does.
- Settings, AI: choose who designs. Claude, as before, or another AI on your
  own API key: OpenAI, the Anthropic API, Google Gemini, OpenRouter, Mistral,
  Groq, Together, DeepSeek, xAI, or any server that speaks OpenAI's Chat
  Completions (Ollama, LM Studio, vLLM). Pick a model from the provider's own
  list, set the temperature, the max output and the reasoning effort where
  the model takes them, and Test it: one tool call and one picture, and it
  says plainly what works. Design with it from the assistant's column. Your
  key is kept on your computer in a file encrypted to it, or for the visit
  only, and is never sent to us, logged or saved with a model.

## [0.10.0] - 2026-10-28

A release about a second look. When Claude designs something new, a fresh
pair of eyes now looks at it before it is finished: a Claude session that
never saw the designing is shown three pictures and the person's whole
request, and says what reads as a generic box and the three changes a set
designer would make first. Judged against the same designs without it,
designs with it were preferred in two of every three verdicts. Parts with
studs on their sides are no longer read as wider than they are, and the
Tested mark judges a build by its own parts and its own joints.

### Added

- A fresh pair of eyes at a new design's first save. Claude Code, started
  on its own and shown only the request and three pictures of the model,
  names what makes it read as the subject, what reads as a generic box,
  and the three biggest changes; the designing chat makes them. Where no
  Claude Code runs, the chat is shown the same pictures and asked the same
  question, and answers it before it builds on.
- The fresh eyes judge by the person's whole request, in their own words,
  and never ask to take away anything it names.
- Every lot on a model's Parts tab shows its own part, drawn by Brickworks.

### Changed

- A chat through the connector hears the model's sizes once for itself,
  not once for every tab.
- A step's parts are counted as a booklet shows them, and a side build
  counts as one step.

### Fixed

- Claude Code is found where its installer puts it, so an app started from
  a desktop icon can use it.
- A part with studs on its side (87087, 4733, 30414) is no longer taken
  for a wider one: a shape built beside it is told when it would float,
  and its foot is laid in plates.
- The Tested mark: a build that tips is let settle and fails only where a
  joint gives; a part is judged by its own shape, never another's moved
  out of place; chains are held by their sprockets; and real sets'
  booklets, colours and joints pass it.
- Rename or delete stays in reach however many models are saved.
- On a phone, Build it comes up where it stays, so a finger never lands
  on the timeline.

## [0.9.0] - 2026-10-26

A release about the app's own face, and about counting and finding what a
model is made of. Every dialog, menu and button wears the app's dark look
and can be seen on it, and a file chooser opens where you would look. A
model has one part count, the pieces a builder takes out of the box, and
Stress weighs a Technic model's pins and axles, the Cat D11 in seconds.
Search finds a technique by its words and a part by its number, and a
photo's part comes in its colour. Claude lays real pieces that do the job,
where the model can hold them, and Instructions saves a PDF.

### Added

- Instructions saves a PDF beside the booklet's page, every step and the
  parts list in it, ready to print or send.
- The app starts on its own mark, not the engine's.
- Stress weighs pins and axles, so a Technic model's joints are weighed
  too: an axle keyed in its hole, or pins on two lines, hold square, and a
  lone line of pins turns unless their friction holds it. On the Cat D11
  it weighs 146 joints, 125 of them pins or axles, in seconds; it took 47
  to list 14 studs.

### Changed

- Every dialog and menu wears the app's own dark face, the engine's own
  questions among them (a new folder, overwriting a file).
- A file chooser opens where you would look: where that kind of file came
  from last, else Pictures for a picture, Documents for a model and
  Downloads for a mesh to brickify or a shopping list. Never the folder the
  app is installed in.
- Every button can be seen on the dark face, edged in the tick boxes'
  outline, and a question's default is the strong blue with white words.
  Read off the pixels, 307 of 653 buttons fell short before; none do now.
- A model's part count is the pieces a builder takes out of the box, and
  every place that counts says the same: the model tree, the viewer, the
  steps bar and the toast. The Cat D11 is 3,868, where some said 6,793 for
  its motors' cables drawn in segments.
- Techniques are found by their words, best first, and titled as words:
  "stairs" finds stairs, and "door" leads with doors.
- A part number finds the part it numbers: 3648 is the gear, not a torso
  printed "Set 3648".
- A photo's part comes in the photo's colour when Brickognize is sure of
  it, and the line says which.
- Every tooltip stays inside the window, a long one in lines.
- Claude's feature pass offers only a piece that is the feature, sized to
  fit the model (a tail light gets a clear part), and lays a real set's
  piece where the model can hold it, finding the hold itself. A scene or a
  building stands on its own plates, not on a baseplate the brief's size.
- A Claude using the connector hears how to work once a sitting, as Claude
  Code does, and begins each design with its subject.
- A returning person sees their last model at once, and is signed in
  behind it.
- Build together: someone who joins sees the model from the owner's view,
  people go by the names on their profiles, and the panel keeps its size as
  the chat grows.
- A minifigure holds what it is given in its hand, the right way round and
  clear of its own body, and says so when a part has nothing a hand can hold.
- A model's moves are named only where something really moves that way: a
  castle's drawbridge is no crane's boom.

### Fixed

- Edit › Select by › Part number or name selects the parts it lists inside
  sub-models too; on a big Technic set it found them and selected none.
- The first design Claude makes on a new account is a model of its own,
  not built into the example car.
- A save made by hand is never refused by the benchmark's piece count.
- The detail pass puts a door in its wall and at the wall's height, and a
  window in the wall rather than on the ground beside it.
- An edit says how many bricks it made again when the request named no
  count.

## [0.8.0] - 2026-10-25

A release about building with others, and by any hand. Build together puts
two people on one model at once, live, each with their own undo. The app
works with a screen reader and the keyboard alone, and on a tablet by touch.
Finding a part is quicker and surer: search ranks parts by how much real
sets use them and answers to BrickLink's and Rebrickable's names and the
element numbers printed in instructions, a photo of a part finds it, and
the parts bin holds the worked constructions the assistant knows. A booklet
saves itself as a PDF, and Sign in with orangecheck works on the desktop.

### Added

- The parts bin has a Techniques tab: 91 worked constructions, such as a
  window in a wall, a round tower or a smooth diagonal, each with why it
  works. Choose one and it is in hand whole; R turns it, a click puts it
  down, and one Undo takes it back.
- A camera in the parts search finds a part from a photo, through
  Brickognize. The app says before the first photo that it goes to them.
- Search ranks parts by how much real sets use them, so "door frame" finds
  the frame in hundreds of sets first, and folds prints and stickers under
  their part's tile behind a count. It answers to BrickLink's and
  Rebrickable's names ("Technic, Liftarm Thick 1 x 5"), Technic words, and
  the element numbers printed in instructions, which bring the part in
  their colour.
- The booklet saves itself as a PDF, or as PNG pages, from its own bar,
  beside Print. The Wizard's Tower's 590 pages make a 40 MB PDF in seven
  seconds.
- On a tablet, Brickworks is built by touch: the phone's layout laid wide,
  every target a finger's size, turned either way round.
- Sign in with orangecheck on the desktop: its button opens orangecheck in
  your browser, and the app is signed in when you come back.
- Brickworks works with a screen reader on the desktop. Every button, part,
  colour and field says its name ("Select, V", "Brick 2 x 4, 3001"), and
  what the status line says is read out. F6 (or Tab, with a screen reader
  running) goes from the model into the toolbar, the parts and the colours;
  Return takes a part, and Return again puts it down where the middle of the
  view is. Settings has Interface size
  (85 to 150%) and Reduce motion.
- On brickworks.diy, a public collection can be followed: its page leads
  with a cover of its models' pictures, Follow and how many follow it, and
  what is put in it shows in the follower's feed. A model's page says how
  many collections it is in, each a card a click away. Share on a model's
  page opens a sheet with its link and the code to embed it, each with
  Copy, and the embed is drawn in the light or dark its viewer chose.
- Build together: File › Build together… gives a link to the model, and
  whoever opens it, signed in, builds it with you at the same time, in a
  browser or the desktop app. Each of you sees the other's parts go down,
  move, change colour and come off as it happens, and who is here. Undo
  takes back only your own changes. Two people moving one part at once
  both see it end in the same place, and the one whose move was overtaken
  is told. Everything the model is goes too: its name, the floor, motions,
  build steps, the booklet's looks, the colours of hidden parts, and parts
  printed or made in the app. Each person's pointer shows in the others'
  view with their name, and the panel has a short chat for people 13 and
  over. A reload or a lost connection goes back into the session by
  itself. A Claude connected to one person's tab builds for everyone. The
  owner ends the session; the model stays theirs.

### Changed
- A first visit to brickworks.diy/app downloads half as much before the
  parts bin is usable: 17 MB where it was 31. The engine and its pack are
  sent compressed harder, the pack leaves out the developers' own scripts
  and carries only the parts the first screen draws, and the rest of the
  parts come in one piece while the app starts.

### Fixed

- After a menu or the snap chooser was used with the mouse, the arrow keys
  stopped moving the selection: the keys stayed with the menu's button.
  They go back to the model when the menu closes.
- A model Claude had worked on, saved as one file with sub-models, came
  back from the autosave without its name.
- A step edit on a big model with its own steps is quick: on the Wizard's
  Tower it takes a fifth of a second where it took up to four.
- A rare script error in the stability and section workers, seen under a
  heavy load, is gone: what a worker reads is now locked.
- Saving, exporting or moving parts between steps on a big model with its
  own steps says so on the status bar before the app is held, as it does on
  any other big model. The Wizard's Tower's Save held the window for up to a
  second, and a step edit for up to three, with nothing said.
- When Claude asks for a change that changes nothing, such as painting a
  part the colour it already is, or one its part was never made in, the
  answer says nothing changed and why, instead of "Done" with an empty
  list of changes.
- On brickworks.diy, /challenges goes to the challenge page instead of
  "not found", and every page's footer links the challenge.
- The sign-in screen says your models are kept with your account as well
  as on the device, as they have been since 2026-10-23. It said they were
  not kept with your account, and so did the FAQ and the privacy page.
- Signed in on a new browser, a phone or a fresh install, Brickworks opens
  on the model you saved last instead of the example car. A first visit, and
  an account with no models yet, still start on the example car.
- After Claude works on a model over the connector, nothing of its is left
  in your hand and the view shows the whole model. A print Claude made was
  left in hand, so the first click put down a stray part, and the view was
  still framed on the empty baseplate the design began on. A view you turned
  while Claude worked is left as you turned it.
- The words in an SVG print. A sign, a menu board or a name plate drawn
  with SVG text, by a person or by Claude, printed without its words: the
  app's SVG renderer draws no text. Its words are now set in the app's font
  and drawn as outlines, with their size, weight, colour and alignment. Text
  that cannot be drawn is refused with why, and a picture with nothing in it
  is refused rather than said to be printed.
- Putting a part down never moves the rest of the model. A part that
  reaches below the floor, a gear on an axle in a Technic brick on the
  baseplate or a car's wheel under its chassis, goes where its ghost shows,
  and the status line says how far below the floor it reaches. The model
  used to rise to stand on it, lifting the build off the baseplate, and two
  gears put down there could not then be turned by hand.

## [0.7.0] - 2026-10-24

A release about models a person can build, and keep. The Tested mark now
means what it says: every part held by a stud, a joint or what catches it,
and no two parts passing into each other, by their real shapes. The
Wizard's Tower, the orrery, the castle and every house model in the
gallery pass. Signed in, the desktop keeps your models with your
account, in step with every browser you use, and File › Open renames and
deletes them. Every export asks where to save it and says where it went,
and opening a model over work not saved always asks first, with Undo to
bring it back. A big booklet is drawn about six times faster, and View ›
Stress counts the weak joints and steps through them. Gears put down by
hand mesh, a door hangs on its frame's hinge, and Claude picks a figure's
parts as real sets do and answers an edit in a quarter of the words.
Models saved by 0.6.0 open in 0.7.0 unchanged.

### Added

- View › Stress has a panel down the model's right edge: the legend, how
  many joints are past their working load and how many near it ("0 past
  working load · 0 near it" on a model that holds), and the weakest joints,
  worst first. A click on a row, or Next and Previous, selects that part,
  frames it with what holds it, and says what would fix it: "It needs 1.4
  times the hold it has: brace it, give it more studs, or move weight back
  over the Brick 1 x 1". Close turns Stress off. Claude reads the same list
  with weakest_joints.
- Your models are kept with your account. Signed in, each save goes to the
  account as well as this computer, and every browser and desktop you sign
  in to has them in File › Open. The computer's copy stays, so offline and
  signed out work as before. A save made from an older version is kept
  beside the newer one as "Name 2", never over it.
- File › Open › Rename or delete saved models…: Rename asks the name as
  Save does, Delete asks first and leaves Undo on its row. A rename or a
  delete made on another device is followed here. Save says plainly when
  the account is nearly full or full (500 models or 64 MB), with Delete old
  models…, and Account says where your models are in each case: signed
  out, kept, full or offline.
- In a big set you can find where a part is. The parts list shows each
  part's picture, a click on a row selects and frames every one of it, and
  Select by › Part number or name… opens the list's find. Claude finds the
  same parts with look_at_model part= and color=.
- Gears put down by hand mesh. A gear held over an axle seats where it
  meshes the gear beside it, and the status line says what it meshes;
  dragged along its axle it slides and stops in mesh; turning one turns
  the other at their teeth's ratio. When two cannot mesh the app says why:
  too far apart, square spurs, a part in the way, or how far to slide the
  other.
- A door held over its frame goes into it on the frame's hinge, shut, as
  Studio seats one, wherever the frame is pointed at; it stood beside the
  frame or on its studs. A window's shutter and its pane go on the window's
  hinge the same way, and swing on it as a door does.

### Changed

- The Tested mark means a person can build it: a shared model is marked only
  when every part is held by a stud or a joint or caught where it is, and no
  two parts pass into each other, by the parts' real shapes as the design
  check reads them. A figure or a second build standing on its own beside
  the model is fine; a part left resting on, against or inside another is
  not. Before, a part touching a held part counted as held and collisions
  were never asked about. A model that is not marked says
  why on its page, to its owner; one too big to build to its last step in the
  time a share takes still says what it failed.
- Every export, Instructions and Save as open your system's Save dialog
  first, in the last folder used or Documents, with the model's name, and
  ask before writing over a file. The status bar then says where the file
  went, with Show in folder. 0.6.0 wrote .io files and booklets straight
  into Downloads, and Instructions with no browser did nothing you could
  see; now it says where the booklet is. A session's export over MCP still
  writes without asking.
- A big booklet is drawn about six times faster, and its cover is there in
  seconds. It is laid out a page at a time, four pictures a frame, each
  finished on a worker thread, and opens in the browser as it is drawn.
  The castle's booklet (2,497 parts, 400 steps) took 79 to 95 s on a
  desktop's graphics card and now takes about 15, every page the same.
- Claude's answers over MCP carry what its next step needs. An edit says
  what it changed and what that broke, with a close look at the change,
  not the whole design again: 413 tokens where it was 1,771. check_design
  draws nothing it did not check, and edit= asks "what if" of the model as
  it stands. A whole design over MCP finishes sooner: on four held-out
  briefs, 10.2 minutes and 51 calls at the median, where it took 12.9 and
  74.
- Claude picks a figure's parts as real sets do. Whose a head, a hat or a
  torso is comes from the official figures, so "smile" never gets a
  licensed character's head or a baby's, and arms take the colour official
  figures pair with the torso. Every part a design places, and every part
  search_parts and the palette's search offer, is the part made now, never
  an obsolete one; a file you open keeps its numbers. A part goes only in a
  colour it was made in, and a rounded body can be laid as a sculpted solid
  in one connected piece.
- A design's worked-out steps put each part in at the step where something
  holds it, so a model designed with Claude passes the Tested mark's steps
  and colours as saved: 10 of the twelve house designs, where 4 did. Saving
  from outside names a part held only by its tube between four studs, as a
  dome can be, which BrickBench counts as a piece of its own, and says to
  seat it on a jumper.
- The Technic Go-Kart steers from its steering wheel: it turns a column
  through a bearing, a universal joint and a 16-tooth pinion over a rack
  pinned to the knuckles, so Grab on the wheel turns both front wheels.
  The orrery and the Wizard's Tower carry their own steps, in an order a
  person can follow.
- Publish sends a picture with nothing behind the model, so it sits on the
  site's light theme and its dark, and a 4:3 picture for the gallery's
  cards. The app records who laid a model's parts, by hand, with Claude or
  by Brickify, and the card's mark follows that, not the tags.
- [brickworks.diy](https://brickworks.diy): on a phone the app has a layout
  built for a finger, with a bar for the name and Undo, one row of tools,
  and sheets for the parts, the colours, More and a held part's actions.
  You can sign in there with orangecheck, beside the emailed code; the
  desktop signs in by code, as before. The site works by keyboard alone and
  names every control for a screen reader, and the gallery has twelve new
  house models, every one Tested.
- An account is reached only by its emailed code (or orangecheck, on the
  web): the server refuses a password, a change of address and a sign-up
  made any other way.

### Fixed

- Opening a model saved with no parts opens it, empty, under its name.
  0.5.0 and 0.6.0 said "Opened … 0 parts" with the last model still there,
  and Save then wrote that model's parts under the new one's name. A file
  that does not open says why, wherever it was opened from.
- New always asks over work not saved. In a browser, an Escape pressed a
  moment before New could reach the window after it and close its question
  unseen, so New did nothing.
- A part that only touches another no longer holds anything up: it carries
  what stands on it, straight down, and nothing hangs from it or levers on
  it. A bow hanging 66 g on four studs read safe because a ladder's foot
  rested under it; it reads amber now. The status bar's verdict weighs the
  joints as View › Stress does.
- A model's step count is the same on its page, its Tested note and its
  booklet: the castle's page said 65 steps where its booklet has 399.
- A part LDraw keeps in one colour for old files is placed as the part it
  draws, in that colour, so the parts list and a BrickLink order carry the
  part made now. 241901, a white 3 x 6 plate, was placed as 2419 in red.
- add_rooms seats its furniture on the floor's studs: the armchair turns on
  its base, and the four-poster bed stands on the grid.
- A big set from the library is on the screen in seconds. Its parts the
  build has not got are fetched as soon as its file is read, sixteen at a
  time, and it is drawn once they are there, before the rest of its open is
  done. The Boutique Hotel's 3,164 parts took a minute or more in a
  browser; now under a quarter of that.
- A set's address typed into a tab with work not saved asks first, as every
  other open does. Before, the set was not opened and only the status bar
  said why.
- File › Open and Open recent say when each model was saved by your
  computer's clock ("today at 07:48:46"), as Versions does. They said the
  time in UTC.
- Following somebody no longer counts their older models as new on your
  avatar; only what they publish after you follow them counts.
- Save on a new model nobody has named asks what to call it first, as Save
  as does, and New's "Save, then start new" asks too; a name another saved
  model has is refused rather than written over. Before, it was saved as
  "Untitled" without a word.
- View › Default view puts the view back on the model, or on the baseplate
  when nothing is built, as Fit does; it turned the view and kept a zoom
  lost in empty space.
- Picking a colour keeps the parts' pictures in the bin until each is drawn
  in the new colour; the whole grid went blank for seconds.
- A shared model: Build it on its page starts the build at step 1, in one
  press; Next and Back on its timeline outline each step's new parts and
  bring them into view, as the step player does; and "Parts of it move" is
  said only when something in it moves that its card names.
- Opening a model over one with changes not saved asks first, as New does:
  Save, Don't save or Cancel. File › Open and its examples, Open recent, a
  file from the computer, Collection › Open and Versions all ask, and an
  open can be undone: Edit › Undo, or History, brings back the model it
  replaced as it stood. Before, the model went with no question and Undo
  had nothing to undo.
- A real set's figures no longer count as parts passing into each other
  where official sets build them so: a helmet under a roof, a backpack
  against a head, legs in a seat, a hand on a door. The check learns
  these fits, and how deep each goes, from the official sets themselves;
  a brick pushed into a brick, or a figure pushed through a wall, is still
  refused.
- A big model no longer holds the window a quarter of a second after it
  opens: the shapes of its parts are read for dragging on a worker.
- A part a design stands on a shape's top, a coupling's plate among them, is
  held by the studs the shape keeps for it, not set down on tiles.
- The house's and the lighthouse's leaves and lamp sit on their studs.
- The kart's steering column is held by an angle connector, and the castle's
  moat and lawns by a course of plates beneath them, so neither drops a part
  when picked up.
- A part nothing joins but that cannot slide out any way, as the orrery's
  planet rings are caught round its core, is no longer said to come away in
  the hand.
- The Wizard's Tower is one piece a person can pick up: its columns stand on
  studs and are tied to its core, and its guards hold their shields by the
  handle.
- A beard worn round a figure's neck under its head is held, as it is in the
  hand; the check had called it held by nothing.

## [0.6.0] - 2026-10-23

A release about big models and what holds them. View > Stress tints every
part by how near its weakest joint is to letting go, and flags only a joint
that really is weak: on eight real sets that stand, one part reads red, a
9 g branch on one stud. A big model opens without freezing the window, and
Timeline on one no longer pauses. Turning a model's moving parts by hand is
lighter, most of all on a phone. A part laid at an angle is held by the
studs it sits on, so the tow truck's fifth wheel turns on its axle. Claude
finds a part by the words a builder uses for it, and never offers a place
for a part that it then refuses. On brickworks.diy the gallery, model pages
and profiles are new, with a feed, comments in threads and notifications.
Models saved by 0.5.0 open in 0.6.0 unchanged.

### Added

- View, Stress tints every part by how near its weakest joint is to letting
  go: red past its studs' working load, amber within twice it, and every
  other part faded in its own colour. Only a joint that alone holds what is
  past it is weighed, such as a cantilever's root or a part hung under
  another, so a bonded wall is never flagged. On eight sets from the Library
  that stand, of 925 to 2,993 parts, one part reads red: 21318-1's branch of
  leaves, 9 g on one side stud. Point at a part and the status bar says what
  it carries: "carries 11 g on 1 stud, margin 0.7". Right-click a red or
  amber part for Ask Claude to brace this, which writes the request with the
  joint's numbers. Stress only draws: the model, its colours and its history
  are untouched, and turned off it costs nothing. Claude reads the same
  margins with check_design. A part's joint to the floor or a baseplate, and
  pins, axles, clips and hinges, are not weighed yet.

### Changed

- A big model opens without freezing the window. File > Open, the Library
  and Versions read it on a worker and lay its parts a slice of each frame,
  the status bar counting "Opening 8466-1… 40%". The view still turns, and
  edits, Save and Claude's tools wait until the model is whole. 8466-1 from
  the Library held a browser for 3.7 to 3.8 seconds at once and 2 more
  after; its longest moment now is a third to half a second. A model of
  under 200 parts opens in one frame, as before.
- Turning a model's moving parts by hand is lighter. Each frame of the drag
  looks at the parts near each moving part once, not twice, and keeps what
  it learned for the rest of the drag. Turning 8808-1's steering wheel with
  a finger on a phone, the app's own work in the slowest frame is 25 to
  29 ms, where it was 21 to 72 ms and over the 33 ms a smooth frame allows
  three times in five. Where the steering stops is unchanged.
- Claude's search_parts finds the part a builder means, in a builder's
  words. Parts are ranked by how many of the words they have, whole words
  only, plain parts before their prints, and builders' shape words and the
  names set inventories use are read as LDraw's. One word the catalogue
  does not use no longer hides a part: 42 builders' searches find their
  part in the first five, where 17 did, in a third of the time.
- [brickworks.diy](https://brickworks.diy), on the same account as the app,
  has a new gallery, model pages and profiles, your own picture as your
  avatar, a feed, comments in threads with replies, and notifications. A
  busy moment there no longer signs you out.

### Fixed

- A part laid at an angle is held by the studs it sits on, and not by one
  it only leans on. The tow truck's (6753-1) fifth wheel, tipped on its
  axle, was held by a stud of the brick under it, so a drag would not turn
  it: it turns on its axle now. A part turned on one stud, as the
  convertible's (5767-1) windscreen sides are, turns on that stud. A part
  seated in another with no stud, a control stick in its socket, joins it
  in Suggest sections and Evaluate the section, and two plates that only
  touch do not.
- A part on the stud of a turned part is held where either has no exact
  shape. A 1 x 1 tile on a chamfered 2 x 4 wing, in a ball of hinged
  panels, was refused as held by nothing, and Brickify, mending a design,
  took such a part out as loose.
- Claude's where_to_attach offers only places edit_selection takes. It
  judged by shapes with their studs cut away, so a part's tooth pushed into
  the next stud looked clear. On four shipped models, 166 of its 649 offers
  were refused; now none of 401 are.
- Timeline on a big model no longer pauses as it finds how the parts join:
  on Orthanc's 9,541 parts in a browser, that was up to a quarter of a
  second with the bar unable to move.

## [0.5.0] - 2026-10-22

A release about opening and moving real models. File > Library… opens any
of 1,575 models of real LEGO® sets and their alternate builds, from LDraw's
Official Model Repository, each with its cover, its builder credited and its
licence, in a tab of its own; the gallery's shared models are a shelf beside
them. Grab turns 85 of the repository's sets by their steering as the real
ones turn, where 0.4.0 turned 59: universal joints bend, racks keep their
pinions, a loop comes back where it began, and a hinge turns as far as its
parts let it. My Claude designs a new model twice, side by side, and keeps
the better, and Undo takes back all of a session's first design. The window
no longer stops while Claude moves a part or checks a design. Brickify lays
more of a model's steep sides on their sides, and the undersides of
overhangs in slopes you can buy. Claude's domes of hinged panels build
again, and a second design in one chat keeps its own subject. Models saved
by 0.4.0 open in 0.5.0 unchanged.

### Added

- File, Library… opens any model of a real LEGO® set that LDraw's Official
  Model Repository has, or a model the community shared in the gallery.
  Search by name or set number, filter by theme, years and size, and sort;
  the covers come a page at a time. Open puts the model in a new tab (a new
  window on the desktop), so the model you have open is never touched. A set
  opens credited to the LDraw member who made it, under its licence, with a
  link to its LDraw page in Properties; a community model is copied into
  your models as Open in Brickworks on its page does. The desktop keeps
  what it fetched, so a set opened once opens again offline. Your Claude
  can find the sets too (gallery library=true) and open one (open_model
  library=).
- brickworks.diy has a light theme as well as the dark one, and you choose:
  System, Light or Dark, at the foot of every page, on Menu on a phone, and
  in Settings. System, the default, follows your computer. The page changes
  as you press, opens in your choice from then on with no flash of the
  other, and the browser's bar takes the page's colour. Signed in, your
  account keeps it, so a new browser follows once you sign in. In the light
  theme a pressed button, such as Following, now has an edge you can see.

- My Claude designs a new model twice, side by side, and keeps the better.
  A second session starts with yours, in a copy of the app with no window
  and a baseplate of its own. When both have built, the app is shown each
  design's pictures and your brief, and keeps the one a set designer would
  rather ship; it goes on your baseplate as one step, so Undo brings the
  other back. Against the real sets of 44 subjects the kept design won
  overall 26.7% of the time, where one design won 21.6%, and the wait was
  1.19 times one design's. A change to a model, a selection, Sketch first
  and Claude on your plan over the connector or MCP are one session, as
  before.

### Changed

- On brickworks.diy a model's card is the same on every page, and its
  picture is larger: cut 4:3 from the middle of the shared picture, so a
  model fills a card about 1.4 times wider. A model's remixes are shown as
  full cards too, a profile's and a collection's cards now say what moves,
  and a model's facts, tags and Tested mark are one kind of round pill
  throughout the site. Counts of nothing are no longer shown: a model
  nobody has liked or remixed yet, or a profile nobody follows yet, no
  longer says so with a zero. Your
  account shows a round avatar in a colour of your own, made from your
  handle. Type sizes and corners across the site come from one short scale,
  so pages that were a little different now match.

- Brickify lays more of a model's steep sides on their sides. A side was
  turned only where it fell in one of a fixed set of blocks two studs by
  five plates; at a side's top or foot such a block also held the top or
  the underside it turned into, or a thin cap over it, and the whole block
  stayed upright. The blocks are now tried at each height a plate apart, and
  a thin cap that runs back over the model's core is held by it. On three
  of the models Brickify is measured on (Bob, the Stanford bunny and
  3DBenchy) at 48 studs, 42% of the steep faces are laid by parts turned to
  face them, from 27%, in 4% more parts; every build is still checked as
  one piece, and every step of its booklet stands. A part on its side that
  rested on the model held by no stud, once a part beside it was taken out,
  now goes with it.
- Brickify turns a side that leans out as one piece of work. Where a side
  leaned out down one of those blocks, the block past it was turned and the
  block itself, with the model past it, stayed upright. The two are now laid
  on their side together, two blocks deep: 44% of the steep faces of the
  same three models at 48 studs, from 42%, in 2% more parts.
- Brickify turns a side on its side from 65 degrees, where it was 69: 46% of
  the steep faces of the same three models at 48 studs, from 44%, the steep
  faces 7.2% nearer the model than laid with their studs up, every build in
  8% more parts than before any were turned and in the same time.
- Brickify lays the undersides of overhangs in inverted slopes you can buy.
  It knew the inverted 3 x 1 and 2 x 2 slopes by older moulds, sold in a few
  of its colours and in none, and it lays a part only in a colour that is
  sold, so it laid neither of them, or the 3 x 2 they pair into. It now lays
  the moulds sold today, in 22 and 33 of its colours. At 48 studs, Bob's
  leaning faces laid by a part leaning the same way rise from 8.3% to 10.5%
  and the error over all its faces falls 3.5%; Spot, the Stanford bunny and
  3DBenchy come out the same or a little nearer. Each build is one piece, in
  under 1% more parts. A collection's older moulds still count as the same
  slope.

### Fixed

- Claude's second design in one chat is judged as what it is. Asked for an
  owl's head and then a house roof without pressing Clear, Claude was told
  the house was a creature with nothing on a joint, and your own Claude over
  the connector had the house sent back to be built as a jointed owl. Asked
  to make the owl's head bigger, the app's own designer forgot it was an owl.
  A design submitted under a name of another subject now begins a new
  subject, and a change to the model you have keeps the one it was.
- A dome or a ball of hinged panels that Claude lays as one shell builds
  again. Its crown, a big inverted dish, was set down on a disc of plates:
  the studs ran into its rim and nothing held it, so the check refused
  every such shell. The dish is now held by round plates up into the 2 x 2
  under its middle, as a builder holds one, with tiles under its rim.
- A part Claude hangs on a hinge brick (3937) now tips whichever way it is
  asked. The hinge brick's top tips one way only, and the app laid it facing
  the same way whatever the angle, so a wing, a flap or a lid tipped the
  other way had its top folded into its base and the design was refused
  since 15 October. The hinge is now turned round to face the tip, as a
  builder turns it, so a pair of wings tipped apart builds. Laid by hand
  folded into its base, a hinge is still refused.
- Claude asked for a head, a bust or a wing alone (an owl's head, a bust
  of a man) is no longer sent back to build a whole jointed animal or
  person in its place. A whole figure or creature with nothing on a joint
  is still sent back once.
- A steering turned one way, the other and back now comes back where it was
  built. A turn that could not quite close its linkage kept it a little
  open, and the next turn took the gap for closed: Red Fury's (5533-1)
  steering came back with a wheel 6.4 LDU off. Each joint of a linkage is
  now measured against how it was built, a turn keeps only a closed
  linkage, and a knuckle a turn slid out along its axle slides back when
  the steering is turned back. Its wheels come back within 0.004 LDU. On 20
  real sets turned this way, all 20 now come back within 0.02 LDU, where 17
  did.
- A universal joint drawn as one part bends as a universal joint. It was
  read as one stiff part fixed to whichever shaft lined up with it, so it
  turned with a wheel one way and with the frame the other: the 4x4
  off-roader (8466-1), turned one way and back, left one 10.7 LDU off. It
  is now its own cross, turning on a pin to the shaft in each end, as a
  universal joint built of its three parts does.
- Undo takes back all of a Claude session's first design. The first design
  a session submits chooses what the model stands on, and only that change
  of floor was kept for Undo: the parts it laid were in no step, so undoing
  everything after two small designs left 55 and 8 parts on the baseplate.
  A call's parts and its floor are now one step, which Undo takes back and
  Redo puts back whole, a baseplate that is part of the build too. Undoing
  a change of colour to a model's own baseplate left the old one as the
  floor, no longer part of the model; it comes back as it was. And a design
  undone and redone stays Claude's: the next one submitted is laid in its
  place, where it was laid beside it.
- A part that Undo takes off and Redo puts back keeps its number. It came
  back under a new one, so whatever had named it lost it: Claude's next
  edit by the number it had been told found no such part, and rejecting
  the pieces the surface pass laid said they were off while all of them
  still stood.
- A message in the status bar lasts its full four seconds when the same
  words are said again. The first saying's timer cleared them as it ran
  out: Check stability pressed twice two seconds apart dropped the weak
  joints it named half a second after the second press, leaving only the
  balance, and "1 selected" vanished early after selecting, clearing and
  selecting again.
- A shared model's motions play in full on a slow connection. A motion is
  judged by its parts' exact shapes, which the web fetches as they are
  wanted. They were asked for only once the model's joints had been read,
  all of them in the file's order, and a press waited up to 10 s and then
  played without those still on their way: with its parts coming a second
  or two apart, the house's (1484-1) second gate stopped at 6° of 90°, and
  its mailbox door, held to the box by joints read without the door's
  shape, did not open at all. The shapes are now asked for as soon as the
  model's parts are here, those of the parts a motion moves and sweeps past
  first, and a press waits for those alone: 0.9 to 4.3 s on that
  connection, and none on a normal one, where a phone had waited 5 to 10 s.
  A press that still meets a part whose shape is on its way is worked out
  again once it has come, and the joints are read again once the shapes
  they were read without are here, in the builder on the web as on a link.
- A steering no longer loses the rack it is turned by. A pinion standing at
  the end of its rack could be carried past the rack's last tooth by a
  turn, and the next turn found it out of the rack and turned it alone, the
  steering left where it was: the 4x4 off-roader's (8466-1), turned one way
  and back, left its rack 2 LDU over. A steering now stops where a pinion
  it is turned by would leave its rack, and turns back from there.
- Claude is told the real size of the pieces it finds in real sets. Every
  part whose shape is lopsided was measured on the wrong side of itself,
  so 4,388 of the 9,555 named pieces had the wrong size: 7745's track oval
  was offered as 209 x 161 studs and is 136 x 88. The 2,556 pieces of
  craft found round a bracket, hinge or slope were cut out again from
  their real neighbours and described again from new pictures.
- Brickify no longer leaves out the model beside a side it turned. Where a
  side laid on its side ended, the model past it, a stud wide, was held to
  the rest only side by side and was taken out before anything could join
  it: a small bunny lost 2% of itself. It is now joined to the rest first.
  A brick with studs on its side that such a side hangs from is no longer
  laid again as a plain brick while pieces are being joined, which had let
  most of the side fall away.
- Brickify no longer leaves a part hanging past what its studs hold beside
  a side it turned. Where nothing can prop it, the side about it is laid
  again upright, as a builder would bond that overhang, and the build that
  holds better is kept. Only that place is laid again, so it costs a second
  or two rather than the whole model's time over.
- A hinge turns only as far as its parts let it. The two halves of the
  joint being turned were never tested against each other, so a hinge
  brick's top swung through its base either way, though the base's square
  shoulder stops it 6° the wrong way. The halves are now judged by their
  real shapes, all but the pin and what it turns in: that top stops at 6°
  one way and lies down on its side at 95° the other, a 1 x 4 swivel plate
  swings round one way and stops at 3° the other, and a click hinge goes
  90° each way.
- The window no longer freezes while Claude moves a part, checks a design,
  asks where a part attaches or settles a feature. Each was worked out in
  one piece on the app's main thread: in a Technic design session, turning
  a motorcycle's chassis 40° held the window 16 to 20 s while the joints
  inside it swung to rest, nothing drawn and the session told nothing, and
  a call that holds the thread cannot become a job. A move is now worked
  out beside the window, as a big check already was, so the window draws
  throughout and a move still going after 20 s answers as a job. Every
  design is now checked beside the window, not only those of 300 parts or
  more: the motorcycle's 60 to 126 parts took 0.4 to 1.3 s to check. And a
  feature's real pieces are fitted beside it: a loader's review_model and
  settle_feature took 1.6 to 2.2 s. Replayed, the motorcycle's session has
  no call holding the window a second, where 13 did, the longest for
  19.7 s; a loader's has one, where 14 did. What each call answers is
  unchanged.
- The window no longer stops for a moment after each part moved, each undo
  and each part placed. Once the model stood still, the app read how its
  parts are joined, ready for the next drag, and weighed it for the status
  bar, both on the main thread for a model of under 300 and 600 parts: on a
  motorcycle of 126 parts that held the window 0.4 s and then 0.2 s every
  time, and on a 248-part backhoe loader 1.8 s and then up to 2.2 s. Both
  now run beside the window at any size, as a shared model's player already
  read its joints, and the longest frame after a move, an undo or a part
  placed is 18 ms on all three models measured, where it was 0.17 to 2.2 s.
  A drag that starts before the reading is done waits for the rest of it.
  And a press on a part while Claude is moving one now says why nothing
  happens, as a press does while a big model's joints are still being read.
  A model weighed or read beside the window while parts were moved could be
  read half moved, its worker stopping with an error: each reading now has a
  copy of its own.

- Pressing a motion's button on a shared model's page just after Reset no
  longer stalls the page. The model's joints, changed by the Reset, were
  read again in the frame of the press, though a worker was already
  reading them: 96 ms of one frame for 1484-1's house here, several times
  that on a slow phone. The press now waits for the worker's reading.
  And on a slow phone a press's work is spread more evenly: with the CPU
  slowed four times its longest piece of a frame was 76 to 88 ms, and is
  now no more than one of its frames, 49 to 68 ms.
- A motion played backwards puts the axle a part slides along back where
  it was built. A telescope's tube runs out along an axle held in the
  frame's bricks, and each step of its run slid the axle half as far, until
  the axle reached the end of its room on its line: 19.5 LDU out, then
  played back, 19.5 past where it was built the other way. "Show it all",
  played backwards, left it there. The axle now stays in what carries it
  and moves only where the part on it runs out of room.
- A part let go after a drag is kept where it was let go, every time.
  The check of its way after the release runs beside the window, and there
  a part whose real shape the drag had not looked at yet was judged by its
  2 LDU cells, which reach past it: 42024-1's small actuator, drawn out to
  its stop and let go, was still kept 2.25 LDU short of it about one time
  in four, where a pin joiner's cells met a liftarm the joiner is clear of.
  The check now reads each part's shape wherever it runs.
- A steering column comes back where it began. 8448-1's steering wheel,
  turned 30° one way, 60° the other and back, left its column 0.2 LDU along
  its pinion's axle: a slide the loop did not need, and each step moved a
  little of it. An axle's slide in a loop now moves only where the loop
  needs it, and the column comes back within 0.008 LDU on all five of the
  set's models. 42125-1's suspension arms no longer slide a tenth of an LDU
  into the parts beside them as it steers.
- A loop no longer slides a part along its axle further than what is on the
  axle lets it. 5533-1's steering closed by sliding its arm 1.75 LDU into
  its brick; the slide is held now where the parts on the axle's line meet
  (a gear or a bush against the beam it is beside), read from their exact
  shapes where they are at hand.
- A frame that swings into the model and stops there no longer spins up a
  wheel on a free axle in it. The stop was taken from the frame's own turn
  alone, so each step the wheel kept the turn the frame's fall would have
  given it and spun faster, for the 40 s a swing may last. A Claude
  session's move_part that tipped a motorcycle over waited on that swing as
  it landed, testing for room at every step, and never answered: it hung
  600 s until the session's connection to the app dropped. The wheel now
  turns on as it was turning and comes to rest, and a swing worked out for
  a move_part stops after 8 s at most, where it was last checked for room,
  and says so.
- A steering column through two universal joints of the older kind (4L)
  steers. 8448-1's file draws its column turned a little round its own
  line, so each joint's centre sat in one fork only: its steering wheel
  turned nothing, and the steering turned at its pinion was refused,
  "Locked", once the pinion had turned far enough to meet the column's
  centre. A centre is in both its forks now, as the 3L joint's was, and the
  wheel steers: 30° of it slides the rack 6.4 LDU, and 60° back 12.5 the
  other way. A stud no longer holds a part tilted past it that it does not
  reach: the column was read as held by one 13 LDU below it.
- A loop let go after a drag is checked from where it was last checked, as
  the drag got there, and the pose it is kept in is the one checked. Its way
  was solved afresh from where it was let go, through poses the drag never
  showed, and where that met something the section was put back there
  without a word: 42024-1's actuator, let go at its stop 4 LDU out, was kept
  once in three at 1.75. A stop found after the release is now said ("it
  stopped where ..., short of where it was let go"), and only that: a
  pendulum that swung and came to rest, or a flywheel that coasted on, is
  not said to have stopped short.
- A part held in round holes by two others holds them together. 8808-1's
  side panels each stand on two headlight bricks' side studs, and were read
  as turning with one brick on its one stud: on a phone, a finger on the
  steering wheel that landed on the panel beside it took the panel, and the
  steering did not turn. The panels are one with the chassis now, as built.
- A loop turned in big steps comes back where it began. 8808-1's steering
  wheel turned 90°, -180° and 90° came back with its column 1.8 LDU along
  its axle; it comes back within 0.003 LDU.
- A steering built into a chassis of pins turns, its knuckles with it. On
  42125-1 the steering took in every pin of the frame around it, 106 joints,
  and was refused as too big to move; parts their pins hold as one now move
  as one, and the steering's 35 joints turn it: 30° of its pinion slides the
  rack 8 LDU and turns each knuckle 11.5°, both ways and back. Its rack,
  hung on its track rods, slides along what it rests on; its suspension arms
  stay put as the wheels steer, where they slid along their axles until a
  bush met a shock absorber; and its steering column turns through its two
  universal joints, whose centres the file draws a quarter turn off their
  forks.
- A tyre with no exact shape is judged by its round, not its box. 8820-1's
  steering stopped at 6° of 30, where a corner of a tyre's box met the
  steering top beside it; it turns 24° now, where the tyre meets the plate
  under it.
- Turning 8416-1's fork lift by the gear on its axle is held by the worm
  that drives that axle, as a worm holds any gear turned from the gear's
  side; turn the worm's axle to lift it.
- A model file's own copy of a LEGO® part is read as that part. Studio
  writes the parts it has versions of into the file under names of the
  file's own ("42125 - 60483.dat"), and they were read as parts nobody
  made: no pins or holes, no exact shape. On 42125-1 the steering's tie
  rods sat in their knuckles held by nothing. A copy drawn as its part is,
  to within 1 LDU, now has that part's pins, holes and exact shape; it is
  still drawn and saved as the file had it. Of the 2,017 such copies in
  the real sets we test with, 1,768 are read so; one drawn otherwise stays
  the file's own.
- In the browser on a slow phone, a model opens with all of its parts. The
  app asks once as it starts where the parts it does not carry are kept,
  and a phone still starting when that question timed out was never told:
  every such part stayed away for the whole visit. A shared 8808 racer
  opened without the 25 parts of its steering and said only "Parts of it
  move". The question is now asked again, as a part's download is.
- A half pin standing in a belt wheel's rim turns with the wheel. Nothing
  named the holes in the rim, so the pin was held by nothing and stayed
  where it was, and 8074's crane stopped at once when its turntable was
  turned.
- A part slid along an axle stops at the bearing the axle turns in. The
  bearing was let through by everything that moved with the axle, so the
  telescope's carriage in Claude's observatory slid into it, and the two
  were stuck as one after. A part that turns and slides on its axle is
  now tested as it slides too.
- A part stopped against another whose exact shape has not loaded (in a
  browser, at first) no longer goes straight through it on the next move.
- A model file's own copy of a gear is a gear. A copy read as its part had
  the gear's holes but not its teeth: Simulate and turning a gear by hand
  passed it by, and a gear train stopped at it. It now meshes and turns at
  its teeth's ratio, and a copied turntable, driving ring or sprocket is
  read as its part too. On 42121-1 a copied 20 tooth gear turned 20° turns
  the 12 tooth gear it meshes 33.3°; on 42083-1 a copied clutch gear drives
  the differential. Of the 60 copies of gears and their kin in 44 of the
  real sets we test with, 55 are read so.
- Check stability, the balance a drag shows and the Tested mark read stud
  joints as Suggest sections and the build check do: a stud pointing
  sideways holds what is on it and is weighed, and a part seated in another
  (a pin in a beam, a cone on an antenna) or two parts at an angle side by
  side are held together but not weighed as studs. On 40 real sets, parts in
  no joint went from 1,122 to 567 and whether each stands is unchanged; a
  2 x 12 wedge read as held by one stud at five times its working load is
  not, and no Tested result changed. Weighing a model takes about half as
  long again.
- The stability on the status bar and Evaluate the section read what holds
  what as Check stability and Suggest sections do. Two parts whose covers
  overlap, a pin in a beam or a cone on an antenna, were each weighed as
  standing on the other's studs, and a section was said to stand on studs
  of the rest and carry it on the same studs: 40335-1's four loose parts
  stood on 43 studs and carried 44. Each stud joint is now weighed by its
  own studs, one at least, not by the area its parts' covers touch: a
  Falcon Heavy's 4 x 6 plates hold six cones and two round bricks on ten
  studs and were said to hold them on two, seven joints over. On 45 real
  sets no other stability verdict changed; 203 sections are described
  otherwise, and 32 come off another way, upward where they only stand on
  the rest. Check stability, a drag's balance and the Tested mark read what
  holds what in a tenth to a fifth less time on 1,000-part Technic sets.
- Check stability, a drag's balance and the Tested mark weigh two parts
  whose covers overlap by what holds them. With no stud of either in the
  other, the edges where the two covers differ were weighed as studs: a
  Technic beam on its long pin was held by one stud at 9.6 times its working
  load (8272-1), an axle through a motorcycle's wheel at 150 times
  (42036-1), and a rim in its tyre, a hinge tile on its hinge and a digger's
  arm on its holder were over too. They are held by their pin, axle, hinge
  or turntable, or seated one in the other, and weighed by no stud, as the
  stability on the status bar weighs them. And a stud is read where its
  tip is in its own part's cover as well as the part it holds, or in a
  hollow underside no cover fills: the cones on 1793-1's tilted round plates
  and on brackets' side studs stand on their studs, and 12 parts of four
  sets' "Loose parts" are in the sections they are built into. On 45 real
  sets, five joints said to be overloaded are not; whether each stands, the
  status bar's stability and every Tested result are unchanged.
- Evaluate the section and Suggest sections say what joins a section by
  what holds it. Two parts whose covers overlap, with no stud of either in
  the other, were counted there as studs where the covers' edges differ:
  1793-1's section on its 4 x 4 turntable stood on 18 studs of it, and a
  section of 42077-1's Technic car on 73, where 7 are studs. Each
  such pair is one pin, axle or clip joint now, held by its pin, axle, hinge
  or turntable or seated in the other, as Check stability weighs it, and it
  still joins what it joined: "it is held by 1 pin, axle or clip joint
  alone". On 45 real sets 164 sections are described otherwise, 2,994 fewer
  studs and 1,356 more joints in all, and 21 come off another way, 14 of
  them upward now that nothing stands on them. Which parts make each
  suggested section is unchanged.
- A stud whose tip is in more than one part's cover is in the one with a
  socket for it. A turned part's cover keeps every cell its boxes touch,
  and the first part named was taken: 1793-1's tilted hinge plates stood in
  the corner panel round them, not in the plate on them, and 8466-1's
  stacked plates in the bricks beside them. Six of 1793-1's pairs are stud
  joints again; on 45 real sets whether each stands, every overloaded joint
  and every Tested result are unchanged.
- Grab moves what studs hold with what holds them. A stud whose tip is in
  its own part's cover as well as another's was read as in nothing:
  9470-1's plate on Shelob's wedge, held by two of its studs, turned with
  the winch axle over it. And of two parts that turn against each other,
  a stud was put in whichever one's box had a face nearest its foot,
  however far off: plates on 8466-1's and 8836-1's Technic bricks were read
  as standing on pins and axles 20 to 150 LDU away that turn in those
  bricks, and held them still. Such a part takes a stud now only where it
  reaches it and takes it, by a socket or a hole. On 45 real sets 20 move
  otherwise, most a pin or an axle turning in its hole again. 7191-1's
  X-wing's four wings are geared to their worm, as built: a plate's studs
  44 LDU from the gear's axle held it, and with it one wing, to the
  fuselage. Grabbed, a wing now says to turn the worm's axle. Of 20 sets
  with a steering the same 17 steer, and 6753-1's, which would not move,
  turns both ways.

## [0.4.0] - 2026-10-20

A release about models that move. A model now carries its own named motions,
"Open the dome" or "Extend the telescope": kept with one press from what
moves, recorded by dragging the real parts, or set joint by joint in Build >
Motions, played forwards and back, strung into a sequence that shows it all,
filmed from File > Render, and played by anyone from its shared link. Grab
moves parts as the real ones move, racks and pinions, cranks and sliders,
worms and friction included, and Simulate turns them the same way. Brickify
reads PLY, 3MF, VOX and FBX. Part names read right, a part that fails to
load is asked for again and never lost from the file, and File > New tab
starts a second model beside the first. Models saved by 0.3.0 open in 0.4.0
unchanged.

### Added

- File > New tab starts a new model in a tab of its own, on an empty
  baseplate, and a reload keeps it. On the desktop it is New window
  (Ctrl+Shift+N), which starts the app again for a model of its own.

- Anybody can play with what moves on a shared link: steer the wheels by
  the steering wheel, swing a boom, open the doors, turn a gearbox by its
  input, by mouse or by finger. It is the builder's own grab, on the same
  joints, stops and couplings. Nothing is kept, and Reset puts it all back.
  The gallery's card says what a model moves, and Technic or mechanism
  finds it.

- A monthly challenge on brickworks.diy, whose rules the site checks on
  the stored model: entered, voted on and won, and followers hear of
  entries in their feed.

- The gallery rewards designs that build. Top builds sorts by builds
  finished, remixes and the Tested mark, never views. The front has this
  week's pick and a shelf of small builds, under 200 parts. Signed in with
  your sets, every model says how much of it you own and what you can
  build now.

- A designer's page leads with what their models earned: builds finished,
  remixes, Tested, comments. The designer alone sees each model's last 30
  days, and who built it.

- Brickify reads more of the 3D files people have, in the desktop app and
  in the browser: PLY scans, as text or binary, in their own colours; 3MF
  from 3D printing sites, its parts placed as the file places them and in
  its colours and pictures; MagicaVoxel's .vox, every voxel a cube in its
  colour (set the size to the model's width in voxels and each voxel is a
  stud); and FBX. An OBJ chosen together with one picture and no .mtl is
  coloured by the picture, where it came in grey; on the desktop the one
  picture beside such an OBJ is read with it. A file that cannot be read
  says what is wrong with it, and one cut short, or claiming more than it
  holds, is refused at once. USDZ is not read, and says so.

- Build, Motions… (it was Pose and animate…): a model's own named
  movements, "Open the doors" or "Steer left and right", saved with it.
  What moves is offered as motions to keep, one press each. Play plays
  one in the view and leaves the model where it ends; Play backwards
  takes it back; Play all runs them in order, and Loop runs it until
  Stop. The panel says where a part stopped and what it met. New motion:
  name it, press Record and drag the real parts in the view, and each
  drag is kept as keys at the times it happened, the model put back
  after; or set it joint by joint, with a slider for each joint that
  moves and its keys on a strip of time, each eased, linear or held.
  Every change is one step to undo. Render animation draws the motion
  chosen. Claude's animate_model keeps its keys as the motion
  "Animation", to play here.

- File, Render… has Animation beside Turntable: choose one of the
  model's motions, or All, in order, and Render animation plays it and
  keeps every frame at the quality, size, light and lens chosen for a
  picture. The camera is as the picture is (As I see it), or fitted to
  what the moving parts sweep through the whole motion (Framed on what
  moves), so a crane's boom fills the frame rather than sitting small in
  the whole model's box. The files are named after the model and the
  motion, "Crane Lift the boom.webp" and ".mp4", numbered when one of that
  name is already there; in a browser the WebP downloads. Progress and
  Cancel as for a turntable. The Motions panel's Render animation and
  Claude's render_motion draw it the same way.
- A shared model's motions play on its link. Its view has a button for
  each, "Open the dome", "Extend the telescope", over the model: press
  one and it plays, its button lit while the model stands where it
  ends; press it again and it goes back. Reset puts everything back, and
  nothing is kept. A model without motions plays as before, by dragging
  what moves. Its gallery card and its page say what it does, "Moves:
  open the dome, extend the telescope", and Claude's gallery and
  open_model name each motion, for play_motion to play.
- A motion made of motions: a sequence. In Build, Motions…, New
  sequence keeps one of every motion the model has, in order, as "Show it
  all"; its editor names it and changes its order with Up, Down, Take out
  and Add. Played, each motion begins where the one before left the model;
  played backwards, they go back in reverse order. It is a row like any
  motion, rendered whole, a button on a shared link, and saved in the file
  as one line naming its motions. A motion it names that is gone is said
  and passed over, and comes back with an undo. Claude makes one with
  define_motion sequence=.

- Delete your account, from your account page on brickworks.diy:
  Settings, Delete this account, with your address typed to confirm. It
  goes with everything of yours on the server: your shared models and
  their versions, comments, favourites, collections, follows, the photos
  of your builds and of your models, the sets you own and your Claude
  connections. The account page also shows your Claude connections, with
  a way to end one.

- Follow people, and a feed of what concerns you. Follow is on every
  profile and beside a model's designer on its page; it needs an account
  that said it is 13 or over, and following somebody tells them nothing
  and opens no way to write to them. A profile shows how many follow it
  and how many it follows, never who follows it; whom somebody follows is
  listed on their profile only if they choose to show it on /profile.
  /feed shows, newest first, new models and new versions from the people
  you follow, photos of real builds of your models and by people you
  follow, comments on your models and remixes of them, each a link to the
  thing. Account, in the site's header and in the app, carries a small
  count of what came since you last opened the feed, and opening it clears
  the count. The day's one email can now tell of new models, new
  versions, photos and remixes too, each chosen on /profile and off until
  then. Needs `supabase/follows.sql` applied, after the rest of the
  release's SQL; until then the profile shows no Follow, the feed says it
  is not open yet, and everything else works as before.
- Real builds on shared models. Reaching a model's last step in the step
  player or the viewer, by stepping on to it from the step before, counts
  the model as built once on that device: no account and nothing about the
  builder, only a random key the device makes for itself and keeps, which
  the server keeps an HMAC of. Robots are not counted, as views are not.
  "12 built" is on the model's page, its gallery card and the viewer, and
  the gallery has a Most built sort. And "I built it": somebody signed in
  who is 13 or over can add a photo of their real build to a model, with a
  line about it, from the model's page, at most three on a model. The
  photo goes from the page straight to storage, at most 8 MB, as a JPEG, a
  PNG or a WebP; the server decodes it to its pixels and makes a new JPEG
  from them alone, so where, when and on what phone it was taken never
  reach a page, and a file that is not really a picture does not decode
  and is refused. The original is deleted at once. Photos show in a strip
  of builds on the model's page and on the builder's profile; the model's
  owner can hide one; anyone can report one, and the site's owner sees it
  on the admin page and takes it out, its file deleted from storage. Needs
  `supabase/builds.sql` applied after `trust.sql` and `tested.sql`, before
  the code is deployed.
- A "Tested" mark on shared models. As a model is published, the app
  builds it by the steps its link carries and tests four things: it stands
  at every step, weighed as the build check weighs it; no part of a step
  is put down in the air or hidden behind what is already built, by the
  booklet's own rules; every part is made in its colour, by the
  catalogue's colour lists; and nothing is loose. A model that passes all
  four is marked Tested on its page, its gallery card and in the viewer,
  with the four results on hover or a tap, and the gallery has a Tested
  only filter. A model that fails one is told which and why, plainly, in
  the Share panel and on its own page, and only its owner sees it. The
  server cannot run the tests, so it keeps what the app found as the app's
  finding, with the app's version, once it has checked that the finding is
  of the very file and steps published; the site's owner can clear a mark
  from the admin page. A 2,042-part set is tested in about 2 seconds; a
  model that would take more than 15 goes untested rather than hold its
  share. Needs `supabase/tested.sql` applied before the code that writes
  it is deployed.
- Versions of a shared model. Publishing a model again makes its next
  version and keeps the one before: the link shows the newest, and
  `/m/<id>/v/<n>` shows an older one, marked as older, with the newest a
  click away. What changed is worked out from the two files, not typed:
  the parts added and removed by part and colour, the steps added, taken
  out or changed by number, and the first step that differs. The model's
  page and the viewer say it short ("Version 2: 2 parts added and 2
  removed in step 3."), with what its owner wrote in the Share panel's new
  What changed? box. Someone building from a phone keeps their place: on
  step 2 when the model changed from step 3, they stay on step 2; on
  step 5, they are told the model changed from step 3 and offered it. A
  copy made with Open in Brickworks records which version it came from,
  and its page says so. Unpublishing takes every version away. Needs
  `supabase/versions.sql` applied before the deploy.
- Ground rules for the site. Terms of use and community guidelines, at
  brickworks.diy/terms and /guidelines, in plain words: credit and the
  three licences, no copied designs passed off as yours, no personal
  photos of children, designs made with the AI designer or Brickify said
  to be so, LEGO® written as an adjective, and what gets a model or an
  account taken out. Every page's footer links them, and the Share panel
  says beside Publish that publishing means agreeing to the guidelines.
- One question at the first sign-in, on the site and in the app: when
  were you born, as a month and a year, with nothing before the answer to
  say what the right one is. Brickworks keeps only whether you are 13 or
  over, and when you said so, never the date. Under 13 you can build, keep
  your models and share them by link; the gallery, a public profile, a
  public collection and a name shown on a link are for people 13 and over,
  and the server refuses them, politely, whatever asks. Accounts already
  there are asked once, at their next sign-in.
- Reports reach the site's owner by email within the hour, at most one
  email an hour, each report with a link to its row on the admin page.
  A report about a test account's model is never emailed: it is rendered
  and recorded instead.
- Takedown requests answer back: a counter-notice for a model taken out by
  mistake, the statements a copyright notice needs, and a marked place for
  the site's copyright agent.
- Comments on a shared model and on a single step of it. A model's page
  lists them, oldest first, each saying where it was said ("on step 7 of
  version 2", and when that is an older version), with a box and a step
  picker to add one. In the viewer and the step player each step shows how
  many it has; tap the count to read them and, signed in, to add one on
  that step. Anybody can read them. Writing needs an account that answered
  13 or over, 10 comments an hour and 50 a day at most, in plain words: a
  link stays words. Without an account, or under 13, the page and the app
  say why, politely, where the box would be. A model's builder can hide a
  comment on it or turn comments off; anybody can report one, and the
  site's owner removes it from the admin page. The builder can ask, on
  their profile page, for one email a day about new comments on their
  models; it is off until they do. Needs `supabase/comments.sql` applied,
  after `trust.sql`, before the deploy.

- Arrows of your own on a booklet page. Lay out page… has Draw an arrow:
  drag on the page from where the arrow starts to where it points, then
  drag its middle to bend it, and set it red (where a part goes in) or
  black, thin or broad. Each is one undo, saved as `0 !BRICKWORKS ARROW`
  and printed over the page; `edit_booklet arrow=` draws one over MCP and
  `booklet_layout` lists them. A file without arrows prints as before.
- The turn sign, where the builder turns the model: a step seen more than
  60 degrees round, or more than 45 degrees higher or lower, than the step
  before gets the sign LEGO® booklets use, under its number. On Lay out
  page… select it and press Delete to take it off (`0 !BRICKWORKS
  TURN_SIGN OFF`), Put back to have it again; `edit_booklet sign=false`
  over MCP.
- A sub-assembly built on pages of its own can be laid out by hand: its
  pages are among the pages of Lay out page…, and its steps'
  pictures, parts lists and numbers are dragged and sized, and words,
  pictures and arrows added, as on any page.
- Pneumatic cylinders move. Drag a cylinder's rod, or the arm it raises,
  and the rod slides in and out along its stroke and stops at its ends,
  with everything the arm carries: on 42080-1's crane the arm rises with
  its saw, its gripper and the log in the gripper. Parts the joints read as
  joined to nothing, an axle in a pin's stop bush, an axle joiner, a gear a
  file carries as a part of its own, a log held in a gripper, are held by
  what they sit in and no longer stay in the air. A hose bends rather than
  holding what it joins.
- Flick a wheel, a gear train or a turntable and let go while it turns: it
  keeps turning at the speed you gave it and slows to a stop against its
  bearings' friction. The gears it drives count through their ratios, so a
  gear that turns a small one fast coasts less far than it would alone. The
  status bar says how fast it coasts, and the step says how far it spun and
  where it stopped. A part on a joint that holds, a hinge or a pin with
  friction ridges, stays where it is let go. move_part spin= lets a part go
  turning over MCP.
- A universal joint at an angle turns its far shaft unevenly, ahead of the
  near one and behind it within each half turn, as a real one does, and
  the gears past it with it; it turned them at the average rate.
- Hoses bend and follow what they join. Raise an arm, swing a cylinder or
  turn a turret that one end of a pneumatic tube, a ribbed hose, a
  flex-system hose, a flexible axle or a string is in, and the hose is laid
  again between its two fittings as it moves, as long as it was and bent
  the way it was: on 42080-1's crane the tubes from the cab follow the arm
  up. Before, the hose stayed where it was drawn and its end came out of
  its fitting. A hose has a length: pulled as far as it reaches it holds
  what it joins, and the status bar and move_part say which hose holds it.
  The hose is part of the move's one undo step. Saved, a hose LDCad laid
  keeps LDCad's path in the file, where the hose now lies, so LDCad opens
  it bent as it was left.

### Changed

- A slow device draws less, and a capable one exactly as before. Where
  frames are slow (a weak laptop, an old phone, a browser drawing in
  software) the app lowers its look a rung at a time, while the editor
  loads, until a frame keeps up, and stops looking once nothing is left
  to cut. There are no new settings.

- Claude's play_motion shows its picture from the side that sees most of
  what moves, and says which: a back wall's doors opened behind a dome are
  pictured from the back, not the front corner. view= chooses one.
- Pressing a motion's button on a shared link no longer holds the page
  while the motion is worked out: it is worked out a little each frame, so
  a slow phone keeps drawing while it does.

- brickworks.diy is one site. Every page has the same header, with four
  things in it (Gallery, Download, Account, Open the app), and the same
  short footer; the questions, the changelog and the legal pages are in
  the footer. The landing page shows the app with a real model, then what
  it does (whether a model stands, gear trains at their real ratios, moving
  a part as the real one moves, Studio files both ways, booklets), each in
  a picture from the app and a line, and models from the gallery. Your account page is one page: your models,
  favourites, collections, the sets you own and what they build, whom you
  follow, your build photos, and your settings.

- The browser check of grabbing parts now times what the app does when a
  swinging part is let go and when it comes to rest and is kept, and fails
  past a tenth of a second. A release was held on a wait of several
  seconds at that moment in a browser drawing in software. It was the
  drawing: the release before waited as long on the same machine under the
  same load, and the app's own work there is a quarter of a millisecond at
  the let-go and 16 ms at the keep.
- What is placed on a booklet page goes with its step. A step's picture,
  parts list, number, callout, words, pictures and arrows are kept with the
  room the step had on its page (`0 !BRICKWORKS PANEL`); when a merge, a
  page break or steps a page moves the step, they move and scale with it.
  Where one thing would still lie on another, the page is printed with it
  moved to the nearest free room, and Lay out page… outlines it in red and
  says what it was on.
- Brickify gives what it lays steps of its own, as a builder would build
  it: a course a step from the bottom, each side panel built on the side as
  a sub-assembly and put on once the core behind it is up, and every step's
  build standing (weighed; a course that would not stand goes in with the
  next). They are the file's own steps, so the timeline, the booklet and a
  saved file follow them. Once it is down the Brickify panel stays in the
  corner with Booklet, BrickLink and Rebrickable, a press each, of the build
  alone. Lay it from my collection lays it from what you own: your parts in
  their colours first, then the same part in a near colour, then two
  smaller parts, and says what is still short. There is no price yet:
  BrickLink's price guide needs a seller's keys. Over MCP, brickify says how
  to get its booklet and lists and takes `collection=true`.

- A booklet page laid out by hand. Lay out page… on the timeline's Booklet
  row (or Build, Booklet page) shows the step's page to scale with its
  pictures: drag a step's picture, its parts list, its callout and its
  number where they go and drag a corner to size them, each snapping to
  the page's margins and middle and to the other items; add words, and a
  picture of your own from a file. Every drop is one undo, saved in the
  model's file as the app's own lines (`0 !BRICKWORKS PLACE`, `TEXT`,
  `IMAGE`, the picture as LDraw's `0 !DATA`), and Instructions prints the
  page just so; a file without them prints as before. Over MCP,
  `edit_booklet` takes `place=` and `text=` and `booklet_layout` says
  where each item is.
- The parts each step adds are outlined in orange in the booklet's
  pictures, as Studio and the LEGO® app outline them; Outline new on the
  Booklet row turns it off for the booklet.

- The booklet, laid out by hand, as Studio's Instruction Maker lays one
  out. On the timeline (B), a Booklet row for the step showing, and Build,
  Booklet page: turn the step's picture round or tilt it (or use the view
  the window looks from), zoom in on what it adds, draw it larger or
  smaller, start a new page, give it a page alone, leave its parts list off,
  build a sub-assembly in a callout box or on pages of its own, and say how
  many steps go on a page. Steps merge, split, move earlier or later (not
  before the step they stand on) and take parts from each other as before.
  Every change is one undo and is saved in the model's file: a turn as
  LDraw's own `0 ROTSTEP`, which LPub, LDCad and Studio read, the rest as
  lines other programs pass over. Someone else's file with its steps
  changed keeps every line nobody changed. Instructions prints the booklet
  just so. Over MCP, `booklet_layout` reads the pages and `edit_booklet`
  sets a step.
- Sections, as a builder builds one at a time. Build, Suggest sections
  splits any model the way a set splits into bags: each section one
  piece, of a sensible size, joined to the rest by few joints, numbered
  in build order. The suggestions sit in the model tree to accept,
  rename, merge or split; accepted, they are sub-assemblies, one undo.
  `Y` breaks a section out of the model to work on and puts it back
  exactly; `Shift+Y` draws every section apart. Evaluate the section
  weighs one alone: its parts, weight, whether it holds together and
  stands, what joins it and what that carries, and its own booklet.
  Claude has the same as `suggest_sections`, `make_sections`,
  `break_out_section` and `evaluate_section`.
- LDCad's hoses, ropes, strings and bands are drawn: each as one piece,
  from the file's own lines, in its colour and step, to click and hide.
  They used to be kept in the file but left out of the view.
- New chat for this tab, in Account and the assistant panel: Claude opens
  on a new chat whose first message names the tab, in claude.ai, the
  Claude app or Claude Code. That chat builds in this tab and no other.
- Each window says which Claude chat is working in it, on the toolbar and
  in Account. When two chats work in one, it says so, and Keep this one
  moves the other off.
- A part on a joint can be taken hold of and moved as the real one moves.
  With Select, drag a hinge's leaf, a clip on a bar, a turntable's top, a
  wheel or a gear, a minifigure's arm or a ball joint: everything built on
  it comes along, it stops where it meets the model, and the gears it
  drives turn by their teeth. The model's balance and its loaded joints
  show while it moves. A pin without friction ridges swings down when let
  go. Each drag is one undo step. A Claude session does the same with
  move_part. Posing one copy of a shared sub-assembly makes it its own
  first, so the other copies stay as they were. Hold still on a hand or a
  hook for a moment, then drag, and the whole chain of joints back to the
  body follows it.
- A part held at both ends moves as its loop allows: drag a steering arm
  and the other arm and the track rod follow it, turn an engine's crank
  and its rod and piston go up and down. A loop that will not close where
  the pointer is stops at the nearest pose that does, and a loop with no
  freedom says it is locked. An engine's piston now slides in its
  cylinder.
- A model turned past its edge falls over when let go, about the edge it
  tips over, until it lies on the floor, in the same undo step: "tipped
  over to the left and lies on its side". A model standing on a
  baseplate's studs does not, and says the studs hold it.
- Let go, a part on a free joint swings. An arm on a pin without friction
  ridges, an axle in a round hole or a free turntable swings down past
  where it hangs and back, a little less each time as the joint's friction
  takes its share, and comes to rest hanging; an arm on two such pins
  swings as a double pendulum. It stops dead where it meets the model. A
  click catches it where it is. A model that tips falls as a body falls,
  slowly at first and faster as it goes, rather than in a fixed half
  second, and what hangs on a free joint in it swings on as it lands.
  move_part says how it swung and where it came to rest.
- What hangs on a gear that turns goes round with it, and every joint
  without friction inside what moved swings down when let go, not only the
  one dragged.
- Claude can move a part along its whole chain of joints to a point:
  move_part with to=.
- A gear rack moves with its pinion: turn a steering wheel, or a column
  that turns the pinion through bevels, and the rack on the track rod goes
  a tooth for every tooth of the pinion, and the arms and wheels turn with
  it; turn a wheel and the column turns.
- A scissor lift rises and folds as its foot is dragged along its rail.
- A worm turns its gear a tooth for each of its turns, and holds it: take
  hold of the gear's side and nothing turns, and the status bar says the
  worm holds it and to turn the worm's axle instead.
- Linear actuators move as the real ones do: drag the rod and it draws out
  or in, never past the ends of its stroke, and the boom it lifts rises
  with it; turn a small actuator's input (or move_part it) and the rod goes
  out a turn's worth of its screw. The boom itself is held by the actuator's
  screw, and says so.
- A steering column that rides on joints that move, in a cab on hinges,
  turns its pinion through its gears as exactly as a column that stands
  still, and the cab stays put while it turns.
- Parts a set has off the grid can be put where the set has them. In
  Properties, X, Y and Z take any place to the hundredth of an LDU, not
  only whole steps of two, and Hinge, shown when the selection hangs from
  a hinge, pin, axle or clip, swings it about that joint to the angle
  typed, as Studio's hinge tool does. A part put on the studs of a part
  that stands off
  the grid, under it or against its side sits on that part's studs, where
  it went up to an LDU beside them. The three sets of the CAD task test
  have 39 such parts (a balance's pans hung at 66.4 degrees, wheels,
  propellers, lights in clips); 31 now go where the file has them, all
  but a car's eight tyres.


- Working out a booklet's steps, for a model without steps of its own,
  takes about two thirds of the time it did, and gives the same steps,
  step for step: the steps score's 100 held-out files plan in 30 to 36 s
  where they took 44 to 55 s on a busy machine, and 76161's Batwing on its
  stand (2,398 parts) in 2.7 to 3.4 s where it took 2.8 to 5.0. A file's
  own stickers and prints no longer sort the whole parts library again
  before the first figure is found.
- A step given a page alone in the booklet is drawn as large as fills the
  page, where it kept to ten millimetres a stud and sat small in the
  middle.
- Build it, the step player, sees each step from where its designer turned
  it (a `ROTSTEP`, or the Booklet row), as the booklet draws it.
- Building a shared model from a phone: a page of Build it changes only
  that step's parts. On 4,000 parts with the phone's processor slowed
  four times, Next and Back took 90 to 500 ms and the last step 1.4 s;
  most turns now take 35 to 90 ms. Tap the progress bar to jump to a
  step. A tap on Build it while the steps are still being worked out now
  opens it when they are, where it did nothing, and a model in one piece
  works its steps out without first sorting the whole parts library: the
  first step of 1,000 parts comes up in 9 to 12 s instead of 45.
- The first drag of a session in a browser no longer builds the balance
  mark's shaders in its first frame: they are built, unseen, as soon as the
  model has been read.
- Dragging a part on a joint: the status bar says where it is ten times a
  second rather than every frame, and a big section drawn by its slide (an
  actuator's arm) is checked for room when you pause, as a turned one is,
  instead of holding the window: one such frame took 31 s.
- A model you share carries its build steps, worked out once when you
  share it, so a phone opening the link to build from works nothing out:
  on 4,000 parts with the processor slowed four times the steps are in
  about 3 s after the page first draws, where working them out took 75 to
  135 s. Links shared before this work their steps out as they did. The
  page also asks for the model while the app is still starting, the
  step player no longer stalls twice a second on a big model, and the
  parts' pictures of the pages to come are drawn while you build, so a
  page's parts list is there when you turn to it.
- With several tabs or windows open, a new Claude chat that has not chosen
  one asks before its first change, listing them. It used to build in the
  tab used last, which could be the one another chat was building in.
- Claude finds a tab by its model's name as well as its id: "the castle
  tab".
- With two chats in one tab, one chat's undo no longer takes back the
  other's change.

- Brickify's slopes follow the model. Each slope, curved slope and
  inverted slope is chosen by how near it lays the surface to the model's
  own, measured at thirds of a stud, the longest where it is as near, and
  only in a colour that part is sold in.
- Brickify lays a steep side on its side. Where a model's surface is
  steeper than about 70 degrees, it is laid in plates, slopes and tiles
  turned to face out, held by bricks with studs on their side, in steps two
  fifths of a stud deep instead of a stud. The build is still checked as
  one piece, and takes about 8% more parts.
- In a browser, the parts a file carries are built and shown: the LEGO®
  Technic set 42082 leaves out 3 parts instead of 167. The download is
  about 1.4 MB larger for it.
- A part in hand keeps up over a big model. Aiming a brick over the
  4,139 parts of set 42082 took up to 747 ms a move; it takes about 2 ms.
  A pin or a sticker in hand asks only the parts near the pointer.
- A file opened straight after a big one opens at once. Set 8202 after
  42082 waited 12 s for the status bar to finish weighing 42082; it now
  opens in 1.5 s, and the new model is weighed after.
- Render opens smoothly the first time. Its renderer is made ready while
  you are not using the window, so in a browser no frame of the first open
  builds more than one shader: its longest frame went from 140 ms to 91 ms,
  and the first draft comes half a second sooner. On the desktop the first
  open's longest frame went from as much as 133 ms to 19 ms.
- A booklet's worked-out steps are easier to follow. A step no longer hides
  one of its own new parts behind another, puts like parts that go on
  together in one (a row of tiles, the 1 x 1s round a rim), and puts on the
  parts beside a sub-assembly in the step that puts it on; a part goes in
  once what it touches stands, reading what rests on what off the parts'
  shapes; wheels go on last, as the sets' own booklets put them; and a
  section of one step has no banner of its own. On 100 real sets nobody
  tuned on, steps with a hidden new part went from 14.5% to 12.1%, steps
  leaving a part floating from 10.3% to 7.5%, parts the build check calls
  floating from 12.2% to 8.0% (each with a half-built model on the table at
  its own lowest point), and steps of one part from 23.3% to 19.5%; the
  order agrees with the sets' own about as well (Kendall tau 0.30 to 0.28,
  within its noise). Working the steps out takes about twice as long.
- A booklet builds more of a set's own sub-assemblies on the side again, as
  callouts: a robot's arms pinned to its body, a car's steering knuckles,
  a ship's wings. On 100 real sets nobody tuned on, 54% of the sets' own
  sub-assemblies are built on the side, from 51%, and steps with a hidden
  new part went from 12.1% to 11.4%.
- A model's booklet is held to be the same however you got to it: opened
  first, or opened again after other models, its steps are the same, and
  the app's own checks now say so on every run. Over 200 real sets planned
  in one go in two orders, and each on its own, none differs. Two runs
  that differed earlier the same day had read two versions of the part
  library, one with other wheels and tyres, not anything opened before.

### Fixed

- Mirror and a half turn in place keep a selection on its own footprint.
  Each used to go round a point that could be half a stud off the middle,
  and put the selection a stud over, or say "no room to mirror it there".

- Animations. A posed joint comes back where it was built, Play leaves
  alone the parts it never moved, a session's keys on a part play and
  render, a part that meets the model while rendering is said, and every
  MP4 is made at its own frame rate.

- Suggest sections reads a stud that points sideways as holding what is on
  it, and no longer joins two parts at an angle that only stand side by
  side. On 10179-1 a 2 x 3 plate on edge went into a section without the
  bricks it is on, held there by the plate beside it; now every section of
  that set is one piece but one, whose loose parts nothing holds.
- In the browser, a part whose download fails for a moment (a timeout, a
  dropped connection, the server busy) is asked for again, three more times
  over 20 seconds, where it used to be given up at once: a model opened on
  a poor connection came up short of that part, and nothing said so. A part
  that still has not come is said in the status bar, once, when the rest of
  the model is in: how many parts could not be loaded, and that they are
  kept in the file. One that arrives later is put down. Saving one of your
  own models while a part was still on its way left the part out of the
  file; it is kept where it was.
- A model with a part that has not arrived, or never does, is kept as you
  work on it, as any model is. Until now nothing done to it was kept: once
  one part failed to load, closing the tab or a crash lost everything since
  the model opened. It comes back with every part, the missing one put down
  when it arrives. A model of your own with a part this version does not
  know also keeps that part now, where Save and the working copy used to
  drop it once you had changed the model.
- Part names with an accent, a degree sign or another script read as LDraw
  writes them, and searching finds them: "Théoden", "Curve 90°", "Å", "忍者",
  where the parts panel and Claude read "ThÃ©oden" and "90Â°", and "Å" was
  cut short. The library was read as Latin-1 when its files are UTF-8; an
  older file that is not UTF-8 is still read as Latin-1. Keywords the
  library's own files carry misread, "ThÃ©oden" among them, are read as
  meant too.
- Claude gets your model's motions right when it plays them. A motion
  that follows another ("Extend the telescope" after "Open the dome
  panel") is checked after it, where it used to be checked alone and said
  to stop on the shut dome. Turning a wheel says how far the rack it drives
  slid, and which way. The picture of a sequence shows each moment as it
  was, where it showed the telescope slid out through the shut dome. A
  render can be taken from the back (view=), and says when what a motion
  moves is behind the model from the camera.
- When a joint will not move after a motion, Claude is told what holds it
  ("the studs of the Door grip the Brick 1 x 6 above it") and what to do,
  where it was told the part was "already there" or only part of the
  biggest body.
- Claude's design check says when a gear stands in a rack's teeth, and when
  one stands beside a rack and not in them, with how far to move it.
- A model Claude saved under a name of its own no longer counts as unsaved:
  opening another model straight after asked to save it first.
- When Claude turns a part, it is told which way the part went (a door
  into the model or out from it), and a joint's height comes in plates, as
  everywhere else, where it was given in studs.
- Suggest sections on a big model opened straight after another works on
  the whole model again. The parts new to it were read in the background
  without their shapes, so no pin, axle or clip joined anything: 10179-1
  came out as twelve sections, one of 3,517 parts in three pieces, where
  it is 49. The build check, the weighing and Grab's reading of the
  joints, each done in the background on a big model, read every part's
  shape the same way now.
- The app no longer crashes when Claude looks at your model while a big
  one is still opening. A model of 600 parts or more has its joints read
  in the background as it opens, and Claude's look at it read the same
  table of gears at the same moment; the two readings could leave the app
  holding none, and it closed. That table and five like it are now read
  either as the app starts or one reader at a time.
- A BrickLink Studio file opens whole when it uses a part newer than the
  library. Studio carries every part's shape in the file, and now any part
  the library has not got is taken from there, where it used to be left
  out and named in the status bar: found by its number, or by BrickLink's
  where the two differ, drawn with its print and in the colours you expect.
  It joins the parts bin under From Studio, and a model saved afterwards
  carries it, so it opens anywhere.
- A model's page opened by somebody signed in who is not its owner no
  longer shows a refused request in their browser's console: asking
  whether the model failed one of its tests, to tell its owner, is now
  answered with nothing to tell rather than refused.
- The page stands still between Claude's calls again. The line in Account
  and the assistant panel that says which Claude chat works in this tab
  kept its "2 min ago" true on a clock, and twice a minute made its rows
  again, which in a browser drawing in software is the whole window drawn
  again. It now says the time of day the chat's last call came, "last:
  changed the model at 14:07", which needs no clock.

- Tyres whose own drawing closed their hole go round a rim. Some tyres are
  drawn as pieces that run into each other without closing, and the space
  each part takes was read as solid right across the tyre's hole, so no rim
  could go in and the tyre's ghost never went round one: 56891, and 22 more
  of the library's 118 tyres, seven of them drawn with no hole at all
  (23798, a tractor's, among them). Space inside a tyre's hole that a line
  along its axle sees straight through is empty now. Parts made in the app
  are built the same way.
- A part whose underside is not whole studs across takes studs on its own
  stud grid. The places it takes studs were measured from the edge of its
  underside, so a flared or rounded edge put them off its studs by up to
  half a stud: minifigure heads and hips, wings with a chamfer, 8643-1's
  cab top (50949) and some 1,250 other parts.
- A quick drag in a slow browser grabs the part as it should. Pressed and
  dragged at once, a part was taken by its chain of joints instead, as if
  held still first, whenever a frame took longer than 0.4 s to draw: the
  hold was timed from the press to the first move the app read, a frame
  apart. It is now timed by what the frames saw. The same went for a
  finger's tap on a slow phone, which read as a hold and took the part off,
  a click on the view cube's arrows and zoom, which did nothing, and a
  flywheel let go while it turned, which a slow frame before the release
  made stop dead instead of coasting.
- A quick drag on a slow page grabs the part even when the frame that
  handles the press is itself slow. That frame can spend half a second
  reading the model's joints or drawing, and that time counted as the press
  being held: a flywheel turned by a quick drag was taken by its chain
  instead. A hold is now timed from the first frame after the one that
  handled the press, so that frame's own work is never a hold. The same
  goes for a finger held on a part to take it off, and for the view cube's
  arrows and zoom.

- Eight more real sets steer both ways and back: 42050-1, 8258-1, 8273-1
  and its Utility Cargo Truck, 8289-1 and its Tow Truck, 9395-1 and
  9397-1's Snowplow. Their steering wheel turned and their rack did not: a
  cross block with four pins was read as one pin, joined to the first thing
  it was in, and that made the rack one with the beams the pinion turns in.
  A part with pins on more than one line is no longer read as a pin. Every
  set the OMR has with a steering is now turned both ways and back by
  `tools/steer_sweep.py`, which writes a table of what steers and why the
  rest do not.
- More real sets steer both ways and back, and more of their doors,
  turntables and booms come back where they were. The 1980s steering rack, a
  rod ringed with teeth that runs through its holder, is read as a rack its
  gear pushes, where it was locked (8022, 8024, 8815, 8820 and 8832); a
  steering rack riding on half pins slides over them in its groove instead
  of being held by them (42076-1); a rack in a housing of its own slides in
  it (42043-1's outriggers); a steering link's end drawn as plain rounds
  holds its towball; and an axle turning in a loop no longer meets the
  bearing it turns in (8862-1). Turned out and turned back in separate
  moves, a part no longer stops short against what it was built against; a
  steered tyre scrubs on the baseplate rather than stopping on it; and a
  cable or a rubber band bends out of the way of what moves. When a move
  stops against the model, move_part and the status bar say which two parts
  met, or which part would go through the floor, where they said "something
  is in the way". `tools/move_sweep.py` moves every real set's turntable,
  doors and booms both ways and back over MCP and writes a table of what
  moves and what stopped each one.
- Parts built flush against each other no longer stop a move at the first
  degree. A grab finds room with cells 2 LDU across, and each cell reaches
  a little past its part, so two parts built side by side met as soon as
  either moved: 10295-1's right door, the floors of 10185-1 and 10220-1,
  and a hinge plate on a plate with studs on one edge. Where the cells meet,
  the move now asks the two parts' exact shapes, the same shapes the build
  check uses, and stops only where those overlap by more than 1 LDU. A part
  without an exact shape is still judged by its cells. Of 382 doors,
  turntables and booms in 260 real sets, 145 now turn both ways and back,
  up from 103, and three more sets steer (8285-1, 42035-1 and 5510-1).
  `tools/move_sweep.py` judges every stop the same way and says whether the
  real parts meet there or only their cells did. A door that stops against
  its frame counts as moving to its stop. A thing counts as turning only
  when it turns a whole degree, not when free joints inside it swing.
- The steering racks with holes (6630, 6592 and 32185) slide on the studs
  standing in the channel underneath them. 8448-1's rack sat on a plate's
  studs and was read as one with the frame, so in all five of its models
  the pinion turned and the rack did not. The studs are found from the
  rack's shape, so they still hold it once it has slid off their grid.
  8448-1's rack and 5533-1's now slide with their pinion and come back.
  8448-1's second turn still stops where a steering link meets a wheel rim,
  so it does not yet steer both ways.
- A steering arm hung on two ball joints, upper and lower, turns on the
  line through them, as a real kingpin does. It used to be refused as "on
  a ball in a closed loop". 9392-1's arm turns that way.
- Reading a model's joints on two threads at once no longer stops the
  app. The cache of each part's axles and holes is now filled under a
  lock.
- What stays when you move a part of a model is chosen on purpose, not by
  weight alone. It is a part you locked, else what stands on the
  baseplate's studs, else the body with the most parts, unless something
  standing on the floor (not a tyre, which rolls) is heavier. It used to be
  the heaviest body, and a part is weighed by its box: 42081-1's bucket, a
  curved shell, came to 535 g and outweighed the loader's frame. A part a
  model file carries as its own, described only by its number ("23798"),
  now takes the name the catalogue gives that number, so 42081-1's tyre is
  read as a tyre and no longer stands on a baseplate stud, and 42110-1's
  steering arms are found as steering arms.
- A part goes where you point it in more of a real set. On a jumper
  plate's middle stud, or on a part that stands on one, a part sits on
  that stud, where it went half a stud aside. A curved slope whose flared
  sides make it wider than its studs (the cab roof of 8643-1) sits on its
  studs, where it went half a stud aside. Aimed at the side of a part, a
  part goes against it rather than half inside it, at the plate you point
  at, and not up onto what overhangs it: a 1 x 12 beside a 1 x 2 under the
  end of a 1 x 4. And a wheel, a bush or a beam goes on an axle anywhere
  along it, where it went on only at the axle's end.
- What you set on a step stays on that step. A step's turn, zoom, size,
  page break, page alone, parts list, turn sign, placed picture, parts
  list and number, words, pictures and arrows moved onto the next step
  once a step's parts had been taken off the model and a part put on: the
  next step edit numbered the steps again and the settings stayed with the
  numbers. They now go with the step's parts through every move, merge,
  split, part moved, step taken out, undo and redo, and a save. That edit
  also changed the step after the one asked for; it changes the one asked
  for. Merging a step into a turned one keeps the turn, and a split or a
  part moved out leaves the settings with the parts that stay. The page
  editor no longer shows a moved step's old picture while it draws the
  new one. A turned first step no longer moves the booklet's lines and
  the floor's on each save.

- Brickify takes a 3D model on this computer. Over MCP, brickify file= its
  path lays it, and a path given as a link does too; only an OBJ, STL,
  glTF or GLB is read. A Claude session given a path had it refused,
  opened the file dialog for a person who was not there, and told them to
  serve the folder on this computer, which is refused as well.
- A steering column turned once turns back. A gear turned off the grid
  read the four studs of the plate under it as held in it, so the column,
  both kingpins and their gears were locked to the chassis, and a second
  turn was refused as "held rigidly". Two parts turned askew to each other
  now hold by more than one stud only where the studs go into sockets or
  holes. move_part says a joint whose line stands upright stays where it
  is put, rather than that it swings down.
- A car's steering turns both ways and back. A session's kart turned its
  steering wheel 30 degrees, and the turn back swung the whole chassis
  round the front axle: a front tyre's tread, whose gaps its part file
  reads as sockets, had come over a baseplate stud and was taken for
  standing on it, so the front axle became what stays. The same tyre made
  the steering's gears lock when the session made the front axle a
  sub-assembly, the parts put back a hair differently. A tyre stands on no
  stud now. And a bush, a gear or a beam sitting on a plate's studs is not
  held by them unless they go into one of its holes: the kart's bush on its
  deck had locked the steering column to the chassis.
- A part that will not move says what holds it, by name and number. "the
  Technic Axle 4 (#15) would turn on its axle in the Technic Plate 2 x 8
  with Holes (#11), but the Brick 2 x 2 Round (#25) grips the Technic Axle
  4 (#15) and the studs of the Technic Plate 2 x 8 with Holes (#11) grip
  the Brick 2 x 2 Round (#25)", in move_part's answer and in the status bar
  as the part is carried instead; a train whose gears lock names what it
  is held between. It used to say "held rigidly to what stays (26 bodies,
  30 joints ...)", which no one could act on.
- A steering column with a round brick on it turns back too. Turned 60
  degrees, the brick brought one of its studs under the gear beside it,
  and the gear reading took the gear for standing on it: the steering's
  train was held to the chassis and the turn back turned the column alone.
  A gear stands on a stud only where the stud is in one of its holes.
- A part locked or unlocked is read as such by the next grab. The joints
  were read again only when the model changed, so after unlocking, a
  steering stayed locked by parts no longer locked.
- An arrow on a booklet page can be aimed at what a step adds without
  seeing the page. booklet_layout says where each step's new parts are on
  its page, and edit_booklet arrow= says whether the tip is on them or how
  far off. A session drew its arrow for a steering wheel onto the seat
  beside it, and told the person it pointed at the wheel.
- A tyre goes on its rim over MCP too. attachment_points names a rim's
  barrel and a tyre's hole, each by its middle and how wide it is (30699's
  and 56904's are both 30.4 mm), and a tyre put by its axis at the rim's
  point goes round it. A session asked for a car with tyres was told the
  tyre had no studs and nothing clutched to it, and had it refused by its
  axis.
- A model without steps of its own, given the worked-out ones by its first
  booklet edit, built the second copy of a sub-model (10016-1's second
  wheels) differently once it was saved and opened again.
- A universal joint passes a turn on. Turning 8062-1's crane winch turns
  the shafts past its two universal joints with it, the joints' crosses
  turning between their ends; it did not move at all, the cross meeting the
  far end at once. Shafts in line turn one for one; a
  joint at an angle turns its far shaft at the mean of its ratio.

- A big loop dragged by its linear actuator follows the pointer at frame
  rate. 42081-1's digging arm, 262 parts in a loop of 25 joints, cost 253 ms
  a frame on average and held some frames 2.9 s; it now costs 11 ms, and
  18 at worst. 42024-1's small actuator, in a loop of 36 joints, went from
  148 ms to 9, and no longer stops for a frame where nothing is in its way.
  Let go, the arm is checked and kept in 4 to 6 s, from 19.

- A big section dragged into something and back, then let go, is kept
  where it was let go. It was put back at the place it had met something
  earlier in the drag: 42081-1's arm let go 20 LDU out was kept 60 LDU in.

- In a browser, a step of the timeline on a big model is quick again, and a
  big model no longer stutters. Since parts could be grabbed and moved on
  their joints, the page looked for every part's drag handle twice a second,
  for a test that was not running: a step on a 925-part model took 6 s, on a
  4,000-part model each look held a frame for 180 to 460 ms, and on a
  2,184-part one drawn without a graphics card the page drew one frame a
  second. It now draws sixty.
- A part that is not a box lies where its own shape has room. A 2 x 2
  corner plate put on a plate beside the arm of a wheel holder, its missing
  corner round the arm, stood a plate up on the arm, and could not be put
  where 8643-1's booklet has it.
- A part that hangs below the part a model was built up from goes on, and
  the model rises to stand on it. A bracket whose arm hangs past the bottom
  plate, a wheel or a tyre lower than the chassis, stood on the floor
  instead or could not be put at all, so a car built from its booklet could
  never have its wheels. The status line says how far the model rose, and
  one undo takes the part off and the model down again.
- A tyre goes on its rim. Aimed at a rim, the tyre in hand snaps round it,
  centred and square, `R` and `T` turning it about the rim and over; a rim
  goes into a tyre the same way. A tyre drawn with no connector of its own
  is joined to its rim by its round hole, so it turns with its wheel. A
  tyre's hole is open through it (92 of
  the library's 118 tyres, from 31): a tyre's cover was closed at its
  sidewalls, so the wheel holder's pin ran into it and no tyre could be
  put on its rim, even typed in Properties.

- A shared model's Build it draws the steps before the one shown faded
  again in a browser. Since the faster page turns, they were sometimes
  drawn dark, in their own colours.

- Build it in a browser now and then drew the parts of earlier steps in
  their own colours where they should be faded.
- The app no longer crashes, now and then, as it starts with parts kept from
  set files, or as it opens a file with parts or hoses of its own. Godot
  crashes when several threads run a piece of script for the first time at
  once, and the parts were built on every thread at once. The first build now
  runs on one thread before the rest.

- The step player lists the parts a step puts on beside a sub-assembly. An
  author's step that put a sub-assembly on with parts of its own showed
  those parts arriving and never said to pick them up.
- A wheel rim LDraw names as an alias ("=Wheel Rim …") is a wheel in a
  booklet. It went on as any other part, wherever its height put it.
- A part a set's file carries, kept by the app, is kept with the pieces it
  is drawn from. It used to be missing after a restart, and a model saved
  then went out without them.

- The pictures the assistant judges its work by no longer draw dark tops
  white from one side. Its fill light caught the stud tops of the far rows,
  and a dark grey model could read as banded in white.
- The gallery no longer shows the models Brickworks's own checks share
  while they run, and neither do profiles, collections or the sitemap.
  Each is still at its own link.
- Brickify stops when you cancel it, close its panel or quit. It used to
  run on to its end: quitting during a large run waited 25 s, and now
  takes under a second.
- Quitting while a render is being saved keeps it. A picture already drawn
  is written as the app closes, a turntable keeps the frames it has, and
  the app's log says what was not finished. Before, a 4K picture being
  saved as you quit was lost without a word.
- In a browser, opening Render a second time no longer stalls the page.
  Two of its frames waited 170-800 ms each to read the draft back; now
  none takes over 50 ms, and the draft is the same.
- In a browser, a part a file carries that is drawn from LDraw's own
  subparts or parts is built too. The files it needs are fetched as it
  opens, only those (42082-1: one, 3 KB), and kept for the visit. 190 of
  the 1,576 real sets' files left parts out for want of them; they now
  open with the same parts as on the desktop.

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
