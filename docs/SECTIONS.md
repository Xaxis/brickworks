# Sections

A builder builds one section at a time. A set's parts come in numbered
bags, and each bag builds a part of the model: the base, a wall, the roof,
a wing built in the hand and put on. The owner asked for the CAD to do the
same (2026-10-16): to "intelligently break out sections" a builder can
"separate out and evaluate individually".

Brickworks does four things with sections. Each works with the assistant
switched off; each is also a tool a Claude session has.

| In the window | Over MCP | What it does |
|---|---|---|
| Build, Suggest sections | `suggest_sections` | proposes how to split the model |
| the model tree's Accept, Merge, Split, rename | `make_sections` | makes them sub-assemblies, one undo |
| `Y`, Build, Break out the section | `break_out_section` | pulls one away to work on, puts it back |
| `Shift+Y`, View, Exploded view | — | draws every section apart |
| Build, Evaluate the section… | `evaluate_section` | weighs one alone |

## How a suggestion is made

Nothing here reads the model a third way. Two readings already exist and
are reused (`src/assembly/sections.gd`):

- **The booklet planner** (`Instructions`): what rests on what, which
  sub-builds a booklet builds on the side (a sub-model that holds together,
  a minifigure, a hose), and so the order sections come in.
- **The build check's joint graph**, as Balance builds it: stud joints as
  the lattice holds them (`Stability.contacts`, 36 shared cells to a stud,
  measured on a 2 x 4 on a 2 x 4) and pins, axles, balls, clips, hinges and
  glue (`Joints`), a pin worth two studs.

Then:

1. Parts that never part are one unit: a sub-assembly the file already has,
   when it fits in a section and is one piece, and each of the planner's
   sub-builds.
2. The booklet's own order is cut, not the model in space. A bag is a run
   of the build, so what a section needs is in it or an earlier one. Cut
   in space first, where the joint graph holds least, Sungnyemun came out
   as two halves side by side, each built onto the other.
3. A cut falls near every bag's worth, about one for every 90 parts (at
   least 2, at most 40), between half and 1.6 bags from the last, where
   least holds the units before it to the units after.
4. Each run is then its pieces by the joint graph, so each section is one
   piece. A piece under 0.3 of a bag goes in with one it is held to: its
   own run's first, then the run before, then the run after. One the
   graph holds to nothing goes with what the planner says it rests on.
   Parts held by nothing at all are Loose parts; minifigures are a
   section of their own, as a set bags them.
5. Sections are numbered so each comes after every one it needs, by the
   planner's needs less its guesses; where two need each other, the one
   begun first comes first.
6. Each is named by where it is: Base, Top, Left side, Front, Back, Upper
   part, or the name of the sub-model it is (not a file's "subModel-48").
   The way it comes off is up when it stands on the rest's studs and
   nothing stands on it, and otherwise out the side of the model it is on.

## Breaking out and putting back

`Y` moves the chosen sub-assembly away from the model the way it comes off:
up two bricks clear of the top, or two studs clear of the side. It moves by
whole studs across and whole bricks up, so it stays on the lattice and a
part put on it snaps as anywhere. It is one undo step.

Where each part stood is kept with the model (`BrickWorld.broken_out`) and
carried by the history, so undo and redo keep it right. `Y` again puts
each part back exactly where it was: the stored transform, not the moved
one minus the offset. A part added while the section was out goes back by
the offset. Putting back is one more undo step.

A file saved, autosaved or exported while a section is out is written with
the section in place. Other programs never see a model pulled apart.

## Not holding the window

A model of 600 parts or more is read on a worker, as the build check is:
from copies of the model and its lattice, every part's geometry loaded and
the tables filled first, the library holding new arrivals aside. The
Working bar says "Suggesting sections… 3 of 8" with Cancel; what is left
on the window's thread is paced. On 10179-1 (5,266 parts, 15 to 16 s on
the desktop) the window's own work in any frame was at most 35 ms (the
two copies), and a new suggestion redraws only its own rows of the model
tree (29 ms; the whole tree of 392 sub-assemblies was 62). 500 to 640
frames were drawn meanwhile. On this box, loaded to 40, the longest of
them was 94 to 142 ms, as long as idle frames of the same model were (69
to 173 ms). Over MCP the call becomes a job past 20 s, as every tool does.

In a browser (a local export drawn in software, on this loaded box),
`tools/web/sections_flow.mjs --timing` on 10179-1, counting from the press
of Suggest sections, with the same page idle first, model tree open:

| | Took | Longest frame of the app's own work | Frames over 100 ms |
|---|---|---|---|
| before (2026-10-17, 02:59) | 122 s, counted from before the button was found | 7,299 ms | 49 |
| the rows walked once (f303a3b) | 30 s | 146 ms | 4, against 0 idle with the tree folded |
| the rows kept until the tree changes | 44 s | 271 ms | 5, against 1 in 15 s idle |

The 7.3 s frame came the moment the tree, with 10179-1's 392 sub-assembly
rows, was open and in view, not at the end of the worker's run: the page
was told where each row is by asking the tree for it a row at a time, each
a search of the whole tree, twice a second. The CPU profile cannot name a
GDScript function (the page's thread is WebAssembly and WebGL calls); the
moment, the laps of the window's own work (none over 51 ms) and its going
away with the rows walked once say what it was. What is left over 100 ms
is the press itself (271 ms: the Working bar shown and the parts found)
and the frame the model and its lattice are copied in for the worker.

## The exploded view

`Shift+Y` draws every section apart, each lifted by its place in the
stack, lowest least, and spread out from the middle, over 0.6 s, and
back. Only the picture moves (`BrickWorld.set_drawn`, as Simulate uses):
the model, the history and the file do not change. A change to the model
puts it back together at once.

The view frames everything as it is drawn apart, and goes back to where
it was after. A click picks what is drawn under the pointer: the lattice
is asked once for each way the sections moved, the ray moved back by it,
and the nearest part moved that way wins. So a section is chosen where it
is seen, at the level the sections are in, and Evaluate the section… and
`Y` work on it. The selection's outline is drawn round the parts where
they are drawn.

## Evaluating a section

Evaluate the section… shows the chosen one on its own:

- its parts as the parts list counts them, its lots and its weight;
- whether it holds together: one piece by the joint graph, and by the build
  check run on it alone (`check_design`'s check);
- whether it stands built on its own base (Balance);
- what joins it to the rest, in studs and pins, and what that carries: a
  stud is trusted with 80 g (Stability's working load);
- how many steps it takes alone, as the booklet would build it.

Its parts list, its BrickLink wanted list and its own booklet are a click
away, written by the same code as the whole model's.

## Measured

`src/dev/sections_probe.gd` on four sets from `vendor/omr/files`, chosen
once: one built as one model, one with its author's sub-models, one
Technic, one big. Desktop, 2026-10-17, on a loaded machine.

| Set | Parts | Sections | Sizes | Suggest | Need a later one |
|---|---|---|---|---|---|
| 21016-1 Sungnyemun, one model | 325 | 3 | 82 to 127 | 0.1 to 0.2 s | none |
| 31025-1 Mountain Hut, 10 sub-models | 549 | 5, a minifigure, 25 loose | 33 to 275 | 0.2 to 0.3 s | none |
| 42093-1 Corvette, Technic | 576 | 5, inside its one sub-model | 56 to 164 | 2 to 4 s | 3 of 5 |
| 10179-1, 5,266 parts | 5,266 | 42 and 254 loose parts | 46 to 299 | 9 to 15 s | 21 of 43 |

On all four:

- every part is in exactly one suggestion;
- the parts as the parts list counts them, and the grams, add up to the
  whole model's: 325, 549, 576 and 5,266; 255.8 g, 630.9 g, 660.7 g and
  7,424.6 g;
- each section is one piece to the build check run on it alone: all of
  them on the three smaller sets, 40 of 42 on 10179-1 (one holds 4 parts
  its file has off their studs);
- each has its own steps, as the booklet would build it alone;
- accepted, they are sub-assemblies in one undo step, undone and redone
  whole;
- two sections each, one up and one to the side, broken out by whole
  studs and bricks in one undo step, a file written meanwhile the same as
  before, put back with every part where it was to the bit, each way
  undone and redone;
- the exploded view draws every part apart and changes nothing of the
  model, its history or its file;
- `suggest_sections`, `evaluate_section`, `make_sections` and
  `break_out_section` over MCP, the first two changing nothing
  (`read_only_probe` too).

Sungnyemun's Base, its own booklet: 36 steps, written by the booklet's own
code with the rest of the model left out.

Pictures, drawn by the GPU: `bench/results/sections-2026-10-16/shots/`.

In a browser, `tools/web/sections_flow.mjs` on a local export of the web
build, by clicks and keys on 21016-1: Suggest sections in the model tree
(3, covering all 325 parts), a click on a suggestion selecting its 127
parts, a double-click renaming one, Split (3 to 4) and Merge (back to 3),
Accept all (3 sub-assemblies), Evaluate… on one (144 parts, 105 g, one
piece, 38 steps), `Y` out and `Y` back with every part where it was, each
way undone and redone, `Shift+Y` apart and together, and three undos back
to the model as it opened. Pictures in `bench/results/sections-2026-10-16/web/`.

## What is left

- Interlocked models. A Technic frame or a UCS hull is sub-models that
  need each other both ways; 3 of the Corvette's 5 sections and 21 of
  10179-1's 43 need a later one. No cut along the build order fixes that.
- Loose parts. The joint graph reads studs, pins, axles, clips and
  hinges, not a tile held from the side or a tyre on its rim. On 10179-1,
  254 parts it holds to nothing are a section of loose parts.

## For other code

`Sections.graph_of(bricks, library, lattice)` is the joint graph with
nothing of the window: studs (rigid, but a single round stud turns),
`turns` (hinges, turntables, clips on bars, balls), `pins` (plugs in
sockets; a pin turns, an axle in a cross hole does not, and it does not
tell them apart) and `fixed` (glue, a hose's pieces, magnets).
`Sections.break_out(path)` and `break_out_parts(ids)` pull a section or
any parts off the way they come off; `put_back(key)` puts them back.

