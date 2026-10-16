# The CAD task test: building here, measured against Studio

Run on **2026-10-16** at `2789cd0`. The community's first question is
"Studio exists, why this?" ([COMPETITIVE.md](COMPETITIVE.md)). Until today
nothing measured whether building here is as faithful and as fast as in
BrickLink Studio. This is the first baseline: real sets' files through every
format the app writes, the frames a builder feels, and three real sets built
from their steps through the interface a person has.

**Studio itself was not run.** It needs Wine, which is not on this machine,
and installing it needs a password ([RESEARCH.md](RESEARCH.md), item 8). So
every Studio number below is **modelled, not measured**: a keystroke-level
model built from Studio's own help pages. Brickworks is modelled the same way,
so the two are like for like, and then measured.

## The headline

| question | measured here | Studio |
|---|---|---|
| A real set's file opened, saved and opened again: exact? | 0 of 48 exact; 2 exact but for the model moved onto the ground; 38 the same shapes once retired numbers are allowed. The repository's five .io and one LDD file: 5 of 6 exact | not measured |
| ...what is lost | the author's name and licence (every file), LDCad's flexible parts (5 of 48), the steps (4 of 44) | not measured |
| Frames at 100 / 1,000 / 5,000 parts | over budget at every size on this box; in a browser the app's own work alone was over 33 ms in every act from 925 parts. Since "Big models, after": a turn, a step and select all no longer grow with the model, and the move of everything, its undo and redo are a fifth to a sixteenth of what they were (headless, 4,139 parts) | not measured |
| A set built from its steps, actions a part | 15.5 and 14.9 (the first 8 parts of two sets; modelled 12.6 and 9.5) | modelled 14.1 and 11.8 |
| ...put down exactly | 5 of 8 and 0 of 8: all 8 put down were in place and turn, 3 of them in the wrong colour; 8 of the 16 could not be put down | not measured |
| ...seconds a part | modelled 8.3 to 9.2, or 9.8 to 11.4 with the steps marked | modelled 10.1 to 10.6, or 10.3 to 11.3 |
| ...what cannot be built through the interface | both clip plates of the plane's step 4; 6157, whose number does not bring it first in the search; the old greys, by their swatch; parts off the 24 turns | not measured |

**The answer to "why this and not Studio" is not yet "it is as faithful".**
A Studio builder's file does not come back as they wrote it, and building a
set from its booklet has no way to say where a step ends. By the model the
hand is faster here; the measured runs took a quarter to over a half more
actions than their model, most of it aiming.

## 1. Files opened, saved and opened again

**What was run.** 48 real sets' files from the LDraw model repository
(`vendor/omr/files`), eight from each of six sizes from 1 part to 7,909, in
the order of a hash of their names, one file a set; and every `.io` and
`.lxf` the repository carries (five Studio files, one LDD file). Each was read
as File, Open reads it, opened, saved as Save writes it (LDraw with its steps)
and as Export, Studio writes it (the same LDraw in a zip), and each saved file
was opened again. `src/dev/roundtrip_probe.gd` uses the app's own code for all
of it; `tools/bench/cadtask.py` compares. 52,594 parts in all.

**Exact** means every part's number, colour, place to the LDU and turn, its
sub-model and its author's step are what the file said.

| written as | exact | exact but for the lift | the same shapes but for the lift and renumbering | parts back, the same shape in the same place | author's steps kept |
|---|---|---|---|---|---|
| LDraw (.ldr, .mpd) | 5 of 54 (9%) | 7 of 54 (13%) | 44 of 54 (81%) | 47,067 of 52,594 (89%) | 40 of 44 (91%) |
| Studio (.io) | the same | the same | the same | the same | the same |

The `.io` is the same text in a zip, and nothing is lost in the zip. The five
Studio files and the LDD file come back exact but one (a print renumbered).
None of the 48 real sets' files does.

What changes, commonest first:

1. **The author's name and licence are gone.** Every saved file says
   `0 Author: Brickworks` (`LdrModel._write_one` writes it), and 48 of 48 lose
   their `0 !LICENSE` line. Every file in the model repository is under CCAL
   2.0, an attribution licence: the credit it asks for is what is dropped.
   The file's own `0 !HISTORY`, `!THEME`, `!CATEGORY`, `!KEYWORDS`, `BFC` and
   LDCad, LeoCAD and MLCad meta lines go too.
2. **Retired part numbers are written as the part they became**: 5,623 parts in
   45 of 48 files (3023 as 3023b, 32556 as 32556a, 30028 as 30028b turned and
   moved 5 LDU as its stub says). The same shape in the same place; another
   line in the file. 1,488 of the repository's 1,576 files use a retired
   number somewhere (49,541 lines), so nearly every one is rewritten so.
3. **The whole model moves onto the ground** in 36 of 48 files: up by 2 to 224
   LDU (19 the median), or down by 6. Every coordinate in the saved file
   differs from the author's.
4. **LDCad's flexible parts are lost**: hoses, strings and bands that LDCad
   draws as a skin of primitives (`0 !LDCAD PATH_SKIN`, `axlehol8`, `4-4cyli`,
   `box4o8a`). 4,713 lines in five files, the parts they draw missing from the
   model. 225 of the repository's 1,576 files use such skins.
5. **The author's steps change** in 4 of 44 files that have them: 42043-1 and
   10272-1 in their sub-models, 10283-1 two parts a step early, 3315-1 with
   all of it.
6. **Opened again, the app's own model is not the same** in 6 of 54: 3315-1
   comes back 28 LDU higher with 5 of its 732 parts gone (it carries 21 parts
   of its own and the saved file 11); 42043-1 moves 58 parts and turns 4;
   42123-1 moves 16.

Opening and saving take long on big files (headless on the desktop, this box
at load 40 to 60):

| parts | files | open, median | open, most | save, median | save, most |
|---|---|---|---|---|---|
| 1–29 | 13 | 0.05 s | 0.5 s | 0 s | 0.3 s |
| 30–99 | 8 | 0.1 s | 1.1 s | 0 s | 0.1 s |
| 100–299 | 8 | 0.3 s | 2.1 s | 0.2 s | 2.0 s |
| 300–799 | 9 | 1.5 s | 9.2 s | 0.2 s | 0.6 s |
| 800–2,500 | 8 | 5.1 s | 32 s | 4.8 s | 13 s |
| 2,501 and up | 8 | 14 s | 22 s | 10 s | **718 s** |

The 718 s is 42043-1 (7,909 parts, sub-models five deep): twelve minutes to
write its LDraw. In the app a save is worked out a slice at a time, so the
window stays alive, but the save takes that long. Where the time goes was not
measured.

## 2. The frames a builder feels

**What was run.** Three real sets' files, the first in hash order within 10%
of 100, 1,000 and 5,000 parts: 4883-1 (92), 75969-1 (925) and 42082-1
(5,025). Each opened as File, Open opens it, then: a right-drag orbit, a
2 x 4 brick in hand swept over the model, Ctrl-A, Delete, Ctrl-Z, and the
timeline (B) stepped on. On the desktop (`src/dev/cadtask_frames.gd`) the
window ran under xvfb-run, drawn by llvmpipe in software, with 100 parts
shift-clicked as well; in a browser (`tools/web/cad_frames.mjs`) on SwiftShader,
every engine frame timed in the page with its time in WebGL apart. Budgets:
16.7 ms a frame on the desktop, 33 ms in a browser.

**Every act misses its budget here at its worst frame, at every size**: 41
of 42, the one under being a 92-part browser page standing still. This box
has no graphics card for these runs, and it was shared at a load of 35 to 60
on 24 cores: a frame that draws costs the software rasteriser a second or
more. So
the drawn frame says what this box can do, not what a person's computer
does. The useful numbers are the ones the drawing does not swamp: the app's
own work in a frame, and how the times grow with the model.

On the desktop, the median, 95th percentile and worst frame, in ms:

| act | 92 parts | 925 parts | 5,025 parts |
|---|---|---|---|
| a frame drawn with nothing changed | 987 / 1,484 / 1,523 | 871 / 950 / 1,035 | 6,531 / 10,431 / 11,790 |
| orbit | 871 / 1,376 / 1,528 | 901 / 1,107 / 1,238 | 6,444 / 8,863 / 10,974 |
| a part in hand, swept | 702 / 923 / 1,213 | 1,121 / 2,392 / 3,789 | 4,946 / 8,091 / 9,083 |
| select all | 684 / 1,221 / 1,341 | 1,140 / 1,861 / 2,255 | 2,904 / 3,125 / 3,869 |
| a step of the timeline (Next) | 490 / 611 / 658 | 868 / 1,597 / 2,402 | 511 / 612 / 654 |
| open, to the first frame drawn | 2.1 s | 5.1 s | 37 s |
| timeline (B) opens | 2.0 s | 4.4 s | 12.8 s |

The probe draws every frame, as a benchmark must (`IdleDraw` is off in a
probe that does not turn it on; the app standing still draws nothing). So
the first row is what drawing the model once costs here: about a second at
92 and 925 parts and six and a half at 5,025, llvmpipe drawing a 1,400 x 900
window under xvfb on a loaded box. Every act sits on that floor. Above it,
the worst frame of a part swept over 925 parts is 4.3 times the floor, and
select all and a step 2.6 and 2.8 times; at 5,025 parts nothing rises far
above a floor of seconds. 42082-1 opened with 4,139 of its 5,025 parts here.
Selecting 100, Delete and Undo did not do what they say: the probe
shift-clicked the first hundred parts, and a click takes a part's whole
sub-assembly (`Builder.takes`), so the clicks took each other back, leaving
none selected at 92 and 925 parts and 36 at 5,025. The probe now clicks only
parts not yet taken, and records the engine's own process time apart from
the drawing; neither change has run yet.

In a browser, the 95th percentile and the worst frame, in ms (an engine
frame that draws nothing costs a millisecond, so the median says nothing;
one number where they are the same). Select, delete, undo and the step are
from a second run that waited for each to finish, which the first run's
three-second window did not at 5,025 parts:

| act | 92 parts | 925 parts | 5,025 parts |
|---|---|---|---|
| orbit | 1,067 / 1,452 | 4,155 / 5,648 | 13,951 / 20,496 |
| a part in hand, swept | 2,388 / 3,807 | 3,200 / 4,132 | 12,631 / 105,813 |
| select all | 6 / 98 | 5,376 | 64,947 |
| delete all | 187 | 5,133 | 8,371 |
| undo | 1,579 | 4,527 | not ended in 15 min |
| a step of the timeline (Next) | 1,034 | 1,112 | not reached |
| open, until it settles | 4.5 s | 22 s | 32 s |
| timeline (B) opens | 0.5 s | 4.3 s | 75 s |

The app's own work in its worst frame (the frame less its time in WebGL):

| act | 92 parts | 925 parts | 5,025 parts |
|---|---|---|---|
| orbit | 42 | 158 | 2,664 |
| a part in hand, swept | 108 | 355 | 1,130 |
| select all | 54 | 269 | 688 |
| delete all | 23 | 258 | 684 |
| undo | 123 | 523 | — |
| a step of the timeline (Next) | 90 | 69 | — |
| open | 193 | 2,459 | 6,528 |

Over 33 ms in every act from 925 parts up, and in every act but Delete at
92. At 5,025 parts one frame of select all took 65 s, and the run's wait for
the undo after Delete had not ended 15 minutes later, when it was stopped for
time; its steps were not reached. Two things the browser runs found besides:

- **42082-1 opens in a browser with 3,973 of its 5,025 parts** (4,139 on
  the desktop). The browser says the 1,052 it leaves out are not in the
  library: they are parts the file carries itself (`0 FILE 42082 -
  18575.dat`, 115 such sections), and the web build has no LDraw library to
  build a carried part from. Why the desktop leaves 886 out was not looked
  at.
- **Right did not step the timeline once a part had been taken from the
  bin.** In the first browser run, after the brick swept over the model was
  taken by a click on its tile, five presses of Right after B left the
  timeline on step 1 of 15 (and of 240, and of 363), while B, Ctrl-A and
  Delete all worked. In the second run, with no tile clicked, one press of
  Right stepped it (the 92-part model). The likely reason is that the clicked tile keeps the
  keyboard focus and Godot moves focus with the arrow keys; it was not
  proven. The status bar's list of keys gives the timeline Home, End and
  space, not Right. Steps are now measured by a click on Next.

### Big models, after (2026-10-16)

The app's own work was over budget in every act from 925 parts up, so the
next unit measured where it went and cut it (`src/dev/bigmodel_probe.gd --
--profile`, headless, so no drawing: every handler of the builder's, world's,
timeline's and store's signals timed one by one, every node's `_process` in
an orbit, and the pieces of an edit and an undo timed alone). On 42082-1,
4,139 of its parts here:

- **A turn of the view** asked the model what was under the still pointer in
  every frame, for the cursor (`Main._cursor_state`), and the lattice marched
  that line from the eye a cell at a time, to its 20,000th cell on a miss:
  22 to 26 ms a frame at every size, and in a browser up to 2.9 s a frame of
  scripts on 42082-1. Now nothing is asked while the view is held or moving,
  and a line is marched only through the box round what was ever put in.
- **A move of everything** matched every sub-model's copies against it again
  (`Assemblies.copies_follow`), up to 400 tries a pair, the model walked twice
  an assembly: most of the 13 s. The rest was the lattice, which puts a
  Technic part's cover (74 boxes on average; 305,648 for the set) in and out
  box by box. Now an assembly moved whole, all its parts alike, is left
  alone (it is the shape it was), a pass reads the model once, a perfect fit
  ends the search, and a part is put in every bucket its bound reaches.
- **Undo and redo** worked each part's cover out again from the part, and
  matched every copy again for the step they left newest: redo 9.4 s, the
  undo of Delete 7.5 s. Now a part moved by whole cells has its cover moved
  (`BrickLattice.shift`), a part taken off carries its cover in the step, and
  the step an undo or redo leaves newest is settled (`Builder.settled`).
- **A step of the timeline** asked every brick whether it was on show and
  wrote every batch holding one that changed again whole. Now the batches
  are written once in the order and a step is a count raised or lowered in
  each (`BrickWorld.reveal_upto`).
- **Select all** grew with the model and no faster: 140 ms. The 65 s in a
  browser was drawing the outline in software.
- **In a browser, twice a second**, the page's state walked every part three
  times for the sub-assemblies, and every connector of every part after any
  change. Now they are kept until the model changes, and the connectors are
  read only with a part in hand.

The app's own work, headless on this box (load 40 to 60), each act from its
key or click until it has happened and two frames more, the quicker of two,
main (63cab62) and this branch run in turn in the same minutes, in ms; an
orbit is its median frame:

| act | made 1,000 | made 5,000 | 4883-1 (92) | 75969-1 (925) | 42082-1 (4,139) |
|---|---|---|---|---|---|
| orbit, a frame | 24 → 7 | 22 → 7 | 23 → 7 | 39 → 7 | 26 → 7 |
| select all | 32 → 32 | 142 → 151 | 23 → 23 | 75 → 53 | 140 → 152 |
| D, everything moved | 223 → 131 | 2,917 → 684 | 69 → 28 | 585 → 224 | 13,096 → 1,943 |
| Ctrl-Z of that | 132 → 100 | 585 → 454 | 57 → 31 | 399 → 132 | 3,541 → 528 |
| Ctrl-Shift-Z | 228 → 111 | 2,690 → 482 | 63 → 23 | 555 → 137 | 9,380 → 588 |
| Delete | 91 → 68 | 294 → 314 | 44 → 26 | 226 → 92 | 882 → 473 |
| Ctrl-Z of that | 215 → 96 | 3,062 → 326 | 56 → 31 | 441 → 103 | 7,541 → 413 |
| a step (Next) | 51 → 21 | 65 → 21 | 70 → 21 | 66 → 21 | 101 → 21 |

"Made" are the probe's own models (towers of four bricks in eight colours,
fifty to a sub-model); their numbers are the suite's run of the probe against
each (`check-before.log`, `check-h.log`). A step after is the frame it is
drawn in and two idle ones, 7 ms each here: ten steps alone take under a
millisecond at either size, against 26 and 304 ms on main. Select all did
not change, and grows with the model, no faster.

In a browser on SwiftShader, main's export and this branch's, the app's own
work in the worst frame of each act (the frame less its time in WebGL), in
ms; an orbit's median frame too. The move and its undo and redo are new to
the browser run (`cad_frames.mjs` presses D, Ctrl-Z and Ctrl-Shift-Z with
everything selected), so main has none here; headless above, they were 13 s,
3.5 s and 9.4 s on main at 4,139 parts:

| act | 92 parts | 925 parts | 5,025 parts |
|---|---|---|---|
| an orbit frame, median | 38 → 22 | 78 → 28 | 216 → 27 |
| an orbit, its worst frame | 102 → 68 | 182 → 110 | 2,949 → 109 |
| select all | 76 → 53 | 100 → 70 | 235 → 91 |
| D, everything moved | — → 203 | — → 530 | — → 879 |
| Ctrl-Z of that | — → 173 | — → 216 | — → 559 |
| Ctrl-Shift-Z | — → 153 | — → 140 | — → 277 |
| Delete of everything | 85 → 97 | 275 → 113 | 1,584 → 703 |
| Ctrl-Z of that | 147 → 147 | 418 → 116 | 3,380 → 297 |
| a step (Next), the worst of five | 200 → 37 | 76 → 54 | 323 → 35 |

The scripts alone (a frame's own work from process to drawing, which the
page now lists for every frame over 8 ms, `brickworksState.busy`), worst
frame: an orbit 82 → 76, 161 → 73 and 2,925 → 52 ms; select all 46 → 16,
38 → 48 and 209 → 93; Delete's undo 12 → 17, 375 → 101 and 3,360 → 12.

Read with care. The 5,025-part file opened in a browser with 3,973 of its
parts on main's run and 2,015 on this branch's (the parts the web build
fetches when a model needs them did not arrive in that page; see below), so
its after column is a smaller model; the headless table is the like for
like. Each frame here is seconds of software drawing, so the page's state,
written twice a second, was written in every frame of a turn: an orbit's
median of 22 to 28 ms at every size is that and the engine's own work, not
the model's. The worst frames still over 16 ms are the edits themselves,
each one frame. And on a box at load 40 to 60, a frame's time includes
waiting for a core.

The parts that did not arrive were not this branch's doing: 42082-1 opened
in a fresh page on main's export and this branch's side by side, each read
the same 2,015 parts at once and had 2,373 four minutes on, in both
(`flows/arrival-*.log`), the rest fetched one by one from the parts server
on a loaded box. On main's run the 15 minutes of a part swept in hand, which
the branch's rerun of 42082-1 left out, gave them time to come.

On the desktop, now on the box's graphics card (an RX 6700 XT; the frames
above, and the CAD task test's, were drawn by llvmpipe in software, so a
frame there was a second whatever the app did), windowed under xvfb with
Mesa copying each frame to it, `src/dev/cadtask_frames.gd` with the click
fixed, main → this branch, one run each; median / 95th percentile / worst
frame in ms. Copying a frame to xvfb is most of 20 ms by itself, so a frame
under that is not to be had here:

| act | 92 parts | 925 parts | 5,025 parts (4,139 here) |
|---|---|---|---|
| a frame drawn with nothing changed | 27 / 41 / 42 → 20 / 33 / 33 | 26 / 42 / 49 → 25 / 42 / 48 | 36 / 55 / 71 → 33 / 45 / 54 |
| orbit | 25 / 41 / 47 → 23 / 36 / 43 | 51 / 69 / 99 → 22 / 33 / 65 | 55 / 72 / 110 → 32 / 46 / 57 |
| a part in hand, swept | 38 / 49 / 65 → 35 / 51 / 53 | 50 / 81 / 280 → 28 / 60 / 232 | 59 / 489 / 1,076 → 39 / 550 / 1,088 |
| 100 parts selected, a shift-click each | 24 / 29 / 33 → 22 / 35 / 37 | 29 / 39 / 40 → 24 / 48 / 48 | 30 / 45 / 52 → 36 / 45 / 52 |
| select all | 20 / 30 / 35 → 20 / 29 / 31 | 24 / 55 / 69 → 24 / 35 / 69 | 29 / 52 / 154 → 33 / 53 / 170 |
| Delete of those 100 | 19 / 38 / 65 → 29 / 37 / 43 | 27 / 56 / 72 → 30 / 55 / 106 | 34 / 62 / 192 → 29 / 59 / 165 |
| Ctrl-Z of that | 22 / 41 / 102 → 22 / 34 / 70 | 24 / 50 / 77 → 26 / 46 / 54 | 25 / 58 / 94 → 33 / 63 / 94 |
| a step of the timeline (Next) | 27 / 44 / 63 → 28 / 53 / 69 | 27 / 65 / 75 → 21 / 37 / 57 | 25 / 71 / 81 → 24 / 40 / 47 |
| open, to the first frame drawn | 0.3 s → 0.3 s | 3.4 s → 3.3 s | 17.8 s → 18.0 s |
| timeline (B) opens | 0.2 s → 0.1 s | 0.7 s → 0.6 s | 2.4 s → 2.8 s |

The click now takes parts not yet taken: 92, 124 and 100 selected (75969-1's
clicks take whole sub-assemblies), Delete took them all and Ctrl-Z put them
back, and Right stepped the timeline at every size. A part held over the
4,139-part model still has worst frames of a second; where that goes was not
measured here, and it is left.

The probe is in `tools/check.sh` (`bigmodel`): it makes the two models,
measures each act twice and keeps the quicker, and holds ratios, never
times: from 1,000 to 5,000 parts an orbit frame and a step (and ten steps
alone) at most 3x, select all, the move, its undo and redo, Delete and its
undo at most 9x (linear is 5, quadratic 25); and at most 3 asks of what is
under the pointer in a 30-frame turn, every part's cover in the lattice its
part's own after the moves, and the page's sub-assemblies kept while
nothing changes. Main at 63cab62 fails six of them: the move 13.1x, its redo
11.8x, Delete's undo 14.2x, ten steps 11.8x, 29 asks in a turn, and the
page's answer worked out at every asking.

## 3. Building a real set from its steps

**What was run.** Three small sets chosen by the same hash: 5762-1 Plane (52
parts, 21 steps), 8643-1 (61 parts, 10 steps) and 8841-1 Balance (63 parts,
4 steps), each one model with its author's steps. `tools/web/cad_task_flow.mjs`
builds them in a browser with only what a person has: a click in the parts
search, the number typed, a click on the first tile; the colour's swatch,
found on screen by its look; R and T to the file's turn; the pointer moved
until the ghost stands where the file has the part (the page says where the
ghost is, as a person sees it), and a click. Every input is counted. A part
the interface cannot get to its place in a few tries is a gap, and nothing
is put there. The model is exported by File, Export and compared with the
file part by part.

**Measured.** The first 8 parts of two of the sets, one set after another
(`build/build.json`; the third was not reached in the time):

| set | tried | put down | exact (number, colour, place, turn) | actions | actions a part | modelled, Brickworks | modelled, Studio | seconds a part, this box |
|---|---|---|---|---|---|---|---|---|
| 5762-1 Plane | 8 | 6 | 5; one in red for old light grey (7) | 124 | 15.5 | 12.6 | 14.1 | 41 |
| 8643-1 | 8 | 2 | 0; both in brown (370) for old dark grey (8) | 119 | 14.9 | 9.5 | 11.8 | 31 |

Every part put down is in its place and turn, to the LDU, up to the one
shift a baseplate gives. The wrong colours are the swatch finder not finding
the old greys, which show only after All in the palette; a person meets the
same palette. The plane's actions: 49 pointer moves, 25 clicks, 20 keys, 30
characters typed; 7 searches, 4 colour picks, 7 turns; 22 of the pointer
moves were corrections, the ghost not yet where the file has the part. Against
the model of the same 8 parts the run took 30 more pointer moves and 12 more
clicks, and 13 fewer keys. Its
motor time by the model's operator times is 9.1 s a part against the model's
11.4 (the model also counts thinking, which a script does not do); the wall
clock, 41 s a part, is mostly software drawing.

What could not be built through the interface, in the order met:

- the plane's two 1 x 1 clip plates (4081b, step 4): the ghost stood 10 LDU
  too high and 10 to 20 LDU aside after 7 aims each, and came no nearer;
- 8643-1's four 6157s (step 1): "6157" typed in the search puts 3816cpc44
  first, and the flow takes the first tile, as a person reading the top of
  the list does;
- 8643-1's 32028 and 3795 (step 2), which stand on what was not built: the
  ghost found only the plate below.

The pictures beside the files: `build/5762-1_Plane_side_by_side.png` shows
the plane's first plates in the file's places and shape beside the whole
plane, the bottom plate red where the file has grey;
`build/8643-1_Combination-with-8644_side_by_side.png` shows two plates in
place, brown where the file has dark grey. Each pair was looked at.

Two runs before this one failed and are kept apart (`build/sidebyside-0918`,
`build/badanchor-1033`): the flow recorded the first part where the page's
report of the ghost said it stood, and on this box that report was 540 to
560 LDU from where the part went (the run above logs both), so every later
part aimed at nothing. The flow now reads the first part's place back from the
app's own LDraw export.

**Studio, modelled.** The keystroke-level model (Card, Moran and Newell:
K 0.28 s, P 1.1 s, B 0.1 s, H 0.4 s, M 1.35 s) of the same part list in each
app, from each app's documented controls. Studio's come from its help pages
(search [6502499385111], placing and turning [5410338956695], rotation
[5411433123351], colour [5411673129879], steps [5626973531287]); every
assumption where a page is silent is listed in `tools/bench/cadtask_klm.py`.
**Modelled, not measured**, both of them:

| set | parts | Brickworks, s a part | with its steps marked | Studio, s a part | with its steps marked |
|---|---|---|---|---|---|
| 5762-1 Plane | 52 | 9.2 | 11.4 | 10.6 | 11.3 |
| 8643-1 | 61 | 8.3 | 10.0 | 10.3 | 10.5 |
| 8841-1 Balance | 59 | 8.4 | 9.8 | 10.1 | 10.3 |

By the model Brickworks is 14 to 19% faster a part, because a part stays in
hand after a click (a second copy costs no search) and a colour is one click
on an open palette. Marking the author's steps takes that back: there is no
"next step" while building here, so each step is its parts shift-clicked and
Edit, New step from selection afterwards, and on the 21-step plane that makes
Brickworks the slower. Studio's own snapping, which turns a part to fit, is
not modelled, so Studio's turns may be fewer than modelled.

[6502499385111]: https://studiohelp.bricklink.com/hc/en-us/articles/6502499385111
[5410338956695]: https://studiohelp.bricklink.com/hc/en-us/articles/5410338956695
[5411433123351]: https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351
[5411673129879]: https://studiohelp.bricklink.com/hc/en-us/articles/5411673129879
[5626973531287]: https://studiohelp.bricklink.com/hc/en-us/articles/5626973531287

## The gaps, by how much a builder would feel them

Nothing here was fixed in the unit that measured them; each is a unit of
its own. Item 3 has had its (section 2, "Big models, after").

1. **No "next step" while building.** A builder following a booklet, or
   writing one, puts each step's parts in its own step. Here every step is
   its parts shift-clicked and Edit, New step from selection, after. Studio
   has a Create step button (E) and puts new parts in the current step. On
   the 21-step plane this turns Brickworks from 14% faster a part to 1%
   slower, by the model.
2. **A part number typed in the search does not always come first.** "6157"
   puts 3816cpc44 first; the flow had to give up on that part. A builder
   working from a parts list types numbers all day.
3. **Every interaction in a browser was over budget from 925 parts up, by the
   app's own work alone**: an orbit frame's own work 158 ms at 925 parts and
   2.7 s at 5,025; a part swept over the model 355 ms and 1.1 s. That is
   before any drawing, so a graphics card does not take it away. Since
   "Big models, after" (section 2) a turn, select all, a move of everything
   with its undo and redo, Delete and its undo and a step no longer walk
   the model where they should not; a part swept in hand still does.
4. **Some parts cannot be put where the set has them through the
   interface**: both 1 x 1 clip plates of the plane's step 4 (the ghost stood
   10 LDU off and came no nearer), and parts at angles off the 24 turns or at
   places that are not whole LDU (8841-1 has 4 and 14 of them).
5. **A file's own parts are left out**: 42082-1 opens with 3,973 of its
   5,025 parts in a browser, the 1,052 left out being parts the file carries
   (`0 FILE 42082 - 18575.dat`), and with 4,139 on the desktop.
6. **Colours are found by look in a palette of 320**: the old greys (7 and
   8), all over older sets, show only after All, and Black and Rubber Black
   look the same. The flow put 3 of its 8 parts in the wrong colour for want
   of them. Studio's colour menu filters as you type
   ([5459441964695]).
7. **Saving drops the author's name and licence** from every file, and with
   them `!HISTORY`, `!THEME`, `!CATEGORY`, `BFC` and other tools' meta lines.
   For files under an attribution licence that is the credit itself.
8. **LDCad's flexible parts are lost** on open: hoses, strings and bands
   drawn as a skin of primitives. 225 of the repository's 1,576 files use them.
9. **Opening moves the model onto the ground** (36 of 48 files), so a saved
   file has every coordinate changed, and a diff of the file says nothing.
10. **Big files save slowly**: 42043-1 (7,909 parts) took 12 minutes to
    write its LDraw; the next slowest 14 s.
11. **Opening the app's own save again is not always the same model**:
    3315-1 comes back 28 LDU higher with 5 parts gone; 42043-1 with 58 parts
    moved; 4 of 44 files have their author's steps changed.
12. **Right stops stepping the timeline once a part has been taken from the
    bin by a click** (in a browser; the desktop probe takes its part without
    a click, and Right worked there). Next worked every time it was tried.
13. **Retired part numbers are written as the part they became** (5,623
    parts in 45 of 48 files): the same shape in the same place, another line.

[5459441964695]: https://studiohelp.bricklink.com/hc/en-us/articles/5459441964695

## How to run it again

```sh
python3 tools/bench/cadtask.py sample      # the files each part uses, the same every run
python3 tools/bench/cadtask.py all         # all three, then REPORT.md
python3 tools/bench/cadtask.py roundtrip   # or one: roundtrip, frames, build, report
```

`frames --platform web --only step,undo` measures those acts again and keeps
the rest; `build --only 5762-1 --most 8 --minutes 8` builds one set's first
parts. On this box, at load 40, the round trip took 20 minutes, the frames an
hour (the 5,025-part model most of it) and two sets' first 8 parts 15
minutes, each after a wait of 10 to 30 minutes for a slot.

Run it bare: it puts each Godot run and browser under `heavy` itself. The
desktop frames mean something only on the graphics card: inside a `gpu`
lease, `MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900
--script src/dev/cadtask_frames.gd -- --frames-out=FILE.json MODEL...`, as
"Big models, after" ran them. The app's own work at any size, and where it
goes, is `src/dev/bigmodel_probe.gd` (bare, the suite's check; with
`-- --profile PATH...`, every handler and piece timed). It writes
to `bench/results/cadtask-<date>/` in the main checkout (git-ignored):
`REPORT.md`, the probe's rows, the judged rows and the pictures. The
comparison and the sampler are pinned by `tests/test_cadtask.py`.
