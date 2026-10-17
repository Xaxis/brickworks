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
   when it fits in a section, and each of the planner's sub-builds.
2. Units are joined strongest first. The strength of a join is what holds
   two units over the root of their sizes multiplied, `w / sqrt(a·b)`: two
   bricks on four studs join before two walls on four studs.
3. Joining stops at about one section for every 90 parts (at least 2, at
   most 40), and no section grows past 1.7 times the average. What is
   left between sections is where the model is held least.
4. A section under 0.3 of the average goes in with the one it is held to
   most. Minifigures are a section of their own, as a set bags them.
5. Sections are numbered in the planner's order: one comes after another
   when any of its parts needs one of the other's. Ties go to the lower.
6. Each is named by where it is: Base, Top, Left side, Front, Back, or the
   name of the sub-model it is. The way it comes off is up when it stands
   on the rest's studs and nothing stands on it, and otherwise out the
   side of the model it is on.

A section is joined only along joints, so each is one piece.

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

## The exploded view

`Shift+Y` draws every section apart along its way off, over 0.6 s, and
back. Only the picture moves (`BrickWorld.set_drawn`, as Simulate uses):
the model, the history and the file do not change. A change to the model
puts it back together at once.

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

RESULTS

## What is left

LEFT
