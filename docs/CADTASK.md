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
| A real set's file opened, saved and opened again: exact? | 0 of 48 exact; 2 exact but for the model moved onto the ground; 38 the same shapes once retired numbers are allowed. The repository's five .io and one LDD file: 5 of 6 exact. *Since (the same day): 48 of 48, and the six 6 of 6, the saved file the author's own but for one line of the app's* | not measured |
| ...what is lost | the author's name and licence (every file), LDCad's flexible parts (5 of 48), the steps (4 of 44). *Since: nothing; what the app cannot draw is kept and said* | not measured |
| Frames at 100 / 1,000 / 5,000 parts | over budget at every size on this box; in a browser the app's own work alone is over 33 ms in every act from 925 parts | not measured |
| A set built from its steps, actions a part | 15.5 and 14.9 (the first 8 parts of two sets; modelled 12.6 and 9.5) | modelled 14.1 and 11.8 |
| ...put down exactly | 5 of 8 and 0 of 8: all 8 put down were in place and turn, 3 of them in the wrong colour; 8 of the 16 could not be put down | not measured |
| ...seconds a part | modelled 8.3 to 9.2, or 9.8 to 11.4 with the steps marked | modelled 10.1 to 10.6, or 10.3 to 11.3 |
| ...what cannot be built through the interface | both clip plates of the plane's step 4; 6157, whose number does not bring it first in the search; the old greys, by their swatch; parts off the 24 turns. *Since: the clip plates, a browser click where its ghost stood, and 8841-1's plates off the 24 turns swung onto their joints (sections 4 and 5)* | not measured |

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

### Since: a file comes back as it went in (the fidelity unit, the same day)

**What changed.** A file another tool wrote (its `0 Author:` not Brickworks)
is now kept when it opens (`SourceFile`), and every save of it is that file
again with only what changed: a part as it was keeps its line byte for byte;
a part moved, turned, recoloured, swapped, taken away or added is written as
such, in place, in its sub-model's frame, under the number the file used. The
lift that stands a model on the ground is the view's and is taken off again
on every save. A file Brickworks wrote is written whole, as before (the 12
shipped models save byte for byte as they did). What one line cannot say (a
copy of a sub-model changed apart from its other copies, an assembly made) is
written whole, under the author's name and licence, with what the app could
not show carried in. The judge now reads the saved file itself as the
original was read: numbers as written, the file's coordinates, steps,
sub-models, every meta line and the author.

**Measured.** The same 54 files, the same probe, before (`f77fded`) and
after, judged alike (`bench/results/fidelity-2026-10-16/`). The judge pairs
each part with the nearest that fits, not the first: in a rope of identical
pieces under an LDU apart a piece took its neighbour's place, and so on down
the rope, so two readings of one file were called moved. The morning's
"42043-1 moves 58 parts and turns 4" and 42123-1's 16 were that, not the app.

| | before | after |
|---|---|---|
| exact: the saved file read as the original was (numbers as written, the file's coordinates, steps, sub-models), every meta line and the author kept, and the app's model the same opened again | 0 of 54 | **54 of 54** (the 48 real sets' files: 48 of 48) |
| ...the parts alone | 5 of 54 | 54 of 54 |
| ...the meta lines and the author | 0 of 54 | 54 of 54 |
| author's steps kept | 41 of 44 | 44 of 44 |
| the app's model the same when the saved file opens | 53 of 54 | 54 of 54 |
| parts lost on open: neither shown nor kept | 4,715 in 7 files | **0**; the 4,715 are kept, saved back and said |
| lines the saved file has that the original has not | every line rewritten | 1 a file, `0 !BRICKWORKS FLOOR …`; none taken away |
| saving 42043-1 (7,909 parts) | 695 s | **0.35 s** |
| the slowest save of the 54 | 695 s | 0.36 s (10283-1) |

Written as `.io` the same, the text in a zip. The strict columns of the table
above (the app's own model against the file) are what they were, 5 of 54: the
model on the baseplate is still stood on the ground and holds a retired
number as the part it became, by design; neither reaches the file now.

In a browser (a local export of the branch, SwiftShader), 42082-1 opened
through Open… > From a file says "167 not shown, kept in the file (42082 -
18575 ×22, 42082 - 27940 ×30, …)" (its 166 carried parts and the rope) while
its parts arrive, and File, Export, LDraw model downloads the file again line
for line: 5,479 part lines of 5,479, no line different but the app's own.
`io_flow` passes there too: bay_2025.io in, its Part Designer part kept and
named, out as .io counting 6 parts, in again. Not measured: edits on the 54
(the fidelity probe edits a file drawn for it, and saves four real sets
whole).

**Where the twelve minutes went.** Everything before the sub-models' frames
took half a second of 42043-1's save (the steps 127 ms, the parts in order
102 ms, the figures 272 ms); `Assemblies.file_frames` ran on past seven and a
half minutes before the profile was stopped. For each of 103 copies it read
every part of the model twice (`content`, a pass over 7,909 parts a call) and
scored up to 400 ways the copy might lie on the first copy of its kind, each
way scoring every part, though only an exact fit is used. It now reads every
copy's parts in one pass, refuses a copy whose parts and colours differ from
its first copy's at once, and gives a way up at its first part that lands on
nothing (`exact_match`). Saved untouched, 42043-1 is now its own file again
in 0.35 s; written whole (an assembly made), 2.6 to 2.8 s.

**Why the parts were lost.** 42082-1's 1,052 parts left out in a browser are
two things: the 166 parts the file carries (`0 FILE 42082 - 18575.dat`), which
the web build cannot build for want of the LDraw library, and one rope that
LDCad drew as 886 pieces of `4-4cyli` skin. The desktop builds the carried
parts, so its 886 are the rope alone. Neither is a part the app could draw,
and neither is dropped now: both stay in the file and are saved back, and
File, Open says so, the rope once by its sub-model ("ropeLQ-1 (flexible)"),
not 886 times by its piece. 3315-1 came back 28 LDU higher with 5 parts gone
because its hollow book, a shortcut the file carries (`3315 - 33009.dat`) and
the app reads as a sub-model titled "33009", was written out as `33009.ldr`;
opened again, a reference to 33009 is the library's part 33009, so the five parts
inside it (466a to 466d) became one part from the library, and the model,
its lowest point now 20 LDU lower, was lifted 28 LDU where it had been
lifted 8. A sub-model is now never
given a file name that is a part number (`33009_.ldr`). The same save also
left out the subparts and primitives the file's parts are drawn from (10 of
its 21 carried files): the same session still had them built, a new one would
not have. A carried part is now written with what it is drawn from
(`CustomParts.drawn_from`). And a file kept is not rewritten at all.

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

## 4. Building from a booklet, the gaps closed (2026-10-16, later)

The five gaps a builder feels most while building from a booklet (1, 2, 4,
6 and 12 below), each at its cause, in Studio's idiom, each with a key.

- **Next step, `E`** (Build and Edit, Build steps). The parts put down since
  the last step make a step, and the next part starts another
  (`AuthorSteps.close_step`), as Studio's step button is modelled. In a
  model with no steps the parts so far are step 1; pressed with nothing put
  down since, it says so and makes no empty step. One undo, the person's.
  By the model it costs a step what Studio's E does (a thought and a key),
  where before each step was its parts shift-clicked and Shift-N after.
- **A part number typed lists that part first.** It always did, here and
  on brickworks.diy: the first run's web export was made in a worktree with
  no `PARTS_URL`, so `tools/web_pack.py` offered only the 15,571 parts with
  the smallest meshes of 29,587, and the bin hid 6157 and 39767; "6157" then led with a
  minifigure leg whose shop number, 761579, has it in its keywords. The
  measurement was wrong, not the search. Now `cadtask.py build` refuses an
  export that does not offer every part, as the hosted build does, and the
  bin says so when a number typed names a part its build cannot place
  ("6157 is not in this build of the app"). `search_probe` asks every number
  the three sets use (64): each leads with its own part.
- **Clip plates and parts that hang past their plate go where the set has
  them.** The ghost snapped a part across the stud grid by its box's size,
  and a 4081b's box is 20 x 38 with its clip, so it stood half a stud aside;
  and it was dropped onto the bottom of its box, the clip's, 2 LDU below its
  plate, so it stood up. Now a part's sockets say where the studs go when
  its box disagrees (`Builder._socket_phase`), and it sits on its plate where
  that leaves room (`Builder._hangs_below`). Every plain part, whose box and
  sockets agree, goes where it went. Parts off the 24 turns were not met in
  the two sets built (8841-1's four 4262s are), and are not fixed here.
- **A colour by its name or number, `Shift-C`.** A field beside Colour
  shows, from all 320, the colours that answer ("light grey", "dark gray",
  "71"), the best first and named over them, and Enter takes it into hand, as Studio's colour
  menu filters as you type. The old greys are not in the short palette and
  look like the bluish greys beside them under All. Half the first run's
  wrong colours were the flow's own: it looked for swatches by LDConfig's
  values, and the app draws `colors.json`'s (7 is #9BA19D in one and
  138,146,141 in the other), so it took a brown for 8. The flow now looks by
  what is drawn, takes a swatch only when it is plainly that colour, reads
  the colour in hand back, and types the name otherwise.
- **Right steps the timeline after a part was taken by its tile.** The
  bin's tiles, categories and buttons took the keyboard focus when clicked,
  and Godot moves the focus with the arrows: Right walked round the bin.
  Nothing in the bin but its search takes the keys now.

**Measured again**, the same first 8 parts of the same two sets, the same
flow with E once a step and colours taken as above, on an export that offers
every part (`bench/results/buildux-2026-10-16/run8b`, this box at load 50 to
70, SwiftShader):

| set | put down | exact (number, colour, place, turn) | steps kept | actions a part | of them typed | motor seconds a part | Right after a tile |
|---|---|---|---|---|---|---|---|
| 5762-1 Plane, before | 6 of 8 | 5 | — | 15.5 | 3.8 | 9.1 | did not step |
| 5762-1 Plane, after | **8 of 8** | **6** | 4 of 4 | 17.4 | 5.5 | 8.8 | steps |
| 8643-1, before | 2 of 8 | 0 | — | 14.9 | 4.1 | 8.1 | — |
| 8643-1, after | **8 of 8** | **8** | 2 of 2 | 15.6 | 5.8 | 7.6 | steps |

Every part was put down, 14 of 16 exactly where, in the colour and the turn
the file has; before, 8 of 16 were put down and 5 were exact. The two that
are not are the plane's clip plates: the flow saw the ghost where the file
has them and clicked, and they went down a stud forward and 2 LDU up, the
click having struck the front face of the plate they stand on, at its edge.
`handbuild_probe`, aiming at the middle of that plate, puts both exactly.
The flow now waits to see the ghost there twice before it clicks; that did
not change it.

**The whole plane**, 40 minutes of building (`buildux-2026-10-16/whole`):
35 of its 52 parts tried, 16 put down, 11 exact, and the 8 steps they make
kept as the file has them. The clip plates went a stud forward again, and
the 1 x 6 plate of step 4 then had no room where the file has it; nearly all
of the 19 gaps after are parts standing on a part that is not there. Why a
click in the browser puts a clip plate other than where its ghost was seen,
when the desktop does not, was not found in the time: it is the next thing
to find, and the plane cannot be built whole through the interface until it
is. 8643-1 was not built whole.

Actions a part rose, 15.5 to 17.4 and 14.9 to 15.6, for three reasons that
are each a part done right that was done wrong or not at all before: the
parts that could not be put down before cost actions and are now put down;
an old grey is now its name typed (`Shift-C`, 7 to 9 letters, Enter) where
it was a click on the wrong swatch; and a step is now marked (one key). The
flow also clicked a look-alike swatch first 4 times before typing the name.
Pointing fell (49 to 41 and 41 to 34 pointer moves), and the motor time a
part, the measured actions at the model's operator times, fell 9.1 to 8.8 s
and 8.1 to 7.6 s. The wall clock here (42 and 63 s a part) is this box at
load 50 to 70, not the app.

**Modelled** (the keystroke-level model, `tools/bench/cadtask_klm.py`, now
with E for a step and an old grey's name typed in full), seconds a part:

| set | Brickworks, steps marked: before | after | Studio, steps marked |
|---|---|---|---|
| 5762-1 Plane, whole (52 parts) | 11.35 | **10.24** | 11.27 |
| 8643-1, whole (61) | 9.97 | **8.86** | 10.54 |
| 8841-1 Balance, whole (59) | 9.83 | **8.81** | 10.25 |

With the author's steps marked, building here is now modelled 9 to 16%
faster a part than in Studio, where it was 1% slower on the plane. Without
steps it is about 4% slower than before (9.58, 8.56 and 8.67 s), the old
greys' names typed in full, which is the most a person types: the line over
the palette names the first match, and the flow typed 7 to 9 letters.

## 5. What the ghost shows is where the part goes (2026-10-16, later still)

**Why a click in the browser put the clip plates a stud forward.** A click
aims before it puts, since a finger has no move before it. Godot reads a
move from the browser's `pointermove`, to the fraction of a CSS pixel, and a
press or release from `mousedown` and `mouseup`, whose `clientX` Chrome cuts
to the whole pixel (measured: a move to 100.6 is a press at 100, at device
pixel ratios 1, 1.25 and 2). So the click was aimed up to a pixel up and
left of where the ghost had been aimed. On the edge of a face it struck the
face beside; against a side, where the place steps by 2 LDU, the next step.
The desktop's moves and presses come in the same whole pixels, so it never
showed there, and a person's mouse on a high-density screen (most laptops)
meets it just as the flow did. The smallest case, one 4081b over the front
edge of a 2 x 2 plate with the pointer stepped across the edge a third of a
pixel at a time (`tools/web/placing_flow.mjs`, `bench/results/placing-2026-10-16`):

| | clicks that put a clip plate down | somewhere other than its ghost |
|---|---|---|
| before | 35 | **16**: a stud forward and 2 LDU up, as the plane's were, and 2 LDU along a side |
| after | 35 | 0 (one more read the page's ghost before the part had arrived; below) |

**The fix** (`Main._true_point`): a press, a release, the system's pointer
and a part let go from the bin within a CSS pixel of the last move are taken
at that move's place. Every place a put-down was aimed apart from its ghost
goes through it: the click that puts the part in hand down, the drop of a
part dragged out of the bin or carried, Shift-click, Alt-click's pick, the
Select tool's click, the right click's menu, and the ghost re-aimed after a
key, a fetched part or a closed box (`Main._pointer`, `Main._pointed`).
Nothing else computes a put-down apart from its ghost: `Builder.place`,
the carried group's and the minifigure's put the transform the ghost shows.

**And a ghost left behind.** Every run's first aim after a part was taken
from its tile read a ghost hundreds of LDU from the pointer (the "540 to 560
LDU" of section 3's failed runs, and the first of the 35 clicks above). A
ghost re-aimed with no event of its own, as when the part's shape arrives
after the pointer has moved onto the model, was aimed at the system's
pointer: in the browser it stood where the first of two moves had been
and stayed there until the next move, while a click put the part under the
pointer; on the desktop, with a probe's events, wherever the real pointer was
left. Now it is aimed where the app last saw the pointer move or press,
unless the system's pointer has moved since over a window of the app's own
(`Main._pointer`). `placing_probe` takes 3022 and 3023 from their tiles and
moves onto the model in one move and in two: the first case failed before
(its ghost 255 pixels from the pointer) and all four pass.

**Parts off the 24 turns** (`Builder._closings`). A part on something round
in something round is turned about it to where another of its ends comes
onto an end of a part down that takes it, as Studio turns a part to fit its
connections ([its help on snapping](https://studiohelp.bricklink.com/hc/en-us/articles/5412087360919)): found for the person until R or T is pressed, one
of R's stops on the way round, and where T's next way onto the joint lands.
8841-1's two 4262s hang from an axle at 66.4 degrees, their lower holes on
two pins: aimed at its pin, each now stands where the file has it to 0.001
LDU and 0.0001 of its matrix, the first after one T. Their holes were not
holes to the app at all: LDraw draws 4262's ends as plain cylinders, so a
round hole a pin's size through a plate's thickness is now a pin hole, its
mouth a collar's half further out than a counterbored Technic hole's
(`JointSnap.ends_of`).

**Proved** on the desktop by `placing_probe` (every click sent as a browser
sends one): 35 clicks across the edge, all where the ghost stood; the
plane's two clip plates exactly as the file has them; a bar in a clip, a
hinge's base and top, two slopes, a Technic brick and a pin in its hole,
each put where its ghost stood to 0.01 LDU; both 4262s as the file has them.
In a browser by `tools/web/placing_flow.mjs`: the plane's two clip plates
put where their ghosts stood and as the file has them; 8841-1's file opened
up to its plates, each 4262 aimed at its pin as the page says the pin is,
and put where its ghost stood and as the file has it (after one `T` and two).

## The gaps, by how much a builder would feel them

Nothing here was fixed in the unit that found them; 1, 2, 4 (the clip
plates), 6 and 12 were fixed after (section 4), and 4's parts off the 24
turns on a joint after that (section 5).

1. **No "next step" while building.** *Fixed: `E` (section 4).* A builder following a booklet, or
   writing one, puts each step's parts in its own step. Here every step is
   its parts shift-clicked and Edit, New step from selection, after. Studio
   has a Create step button (E) and puts new parts in the current step. On
   the 21-step plane this turns Brickworks from 14% faster a part to 1%
   slower, by the model.
2. **A part number typed in the search does not always come first.**
   *Not so: the export measured offered only half the parts (section 4).* "6157"
   puts 3816cpc44 first; the flow had to give up on that part. A builder
   working from a parts list types numbers all day.
3. **Every interaction in a browser is over budget from 925 parts up, by the
   app's own work alone**: an orbit frame's own work 158 ms at 925 parts and
   2.7 s at 5,025; a part swept over the model 355 ms and 1.1 s. That is
   before any drawing, so a graphics card does not take it away.
4. **Some parts cannot be put where the set has them through the
   interface** (*the clip plates fixed, section 4; turns off the 24 not*): both 1 x 1 clip plates of the plane's step 4 (the ghost stood
   10 LDU off and came no nearer), and parts at angles off the 24 turns or at
   places that are not whole LDU (8841-1 has 4 and 14 of them).
5. **A file's own parts are left out**: 42082-1 opens with 3,973 of its
   5,025 parts in a browser, the 1,052 left out being parts the file carries
   (`0 FILE 42082 - 18575.dat`), and with 4,139 on the desktop.
   *Since:* none is dropped. What the app cannot draw stays in the file and is
   saved back, and File, Open names it.
6. **Colours are found by look in a palette of 320**: the old greys (7 and
6. **Colours are found by look in a palette of 320** (*fixed: `Shift-C`,
   a colour by its name or number, section 4*): the old greys (7 and
   8), all over older sets, show only after All, and Black and Rubber Black
   look the same. The flow put 3 of its 8 parts in the wrong colour for want
   of them. Studio's colour menu filters as you type
   ([5459441964695]).
7. **Saving drops the author's name and licence** from every file, and with
   them `!HISTORY`, `!THEME`, `!CATEGORY`, `BFC` and other tools' meta lines.
   For files under an attribution licence that is the credit itself.
   *Since:* a file another tool wrote is saved as it was, every line kept.
8. **LDCad's flexible parts are lost** on open: hoses, strings and bands
   drawn as a skin of primitives. 225 of the repository's 1,576 files use them.
   *Since:* kept in the file and named once each; still not drawn.
9. **Opening moves the model onto the ground** (36 of 48 files), so a saved
   file has every coordinate changed, and a diff of the file says nothing.
   *Since:* the lift is the view's, and the file keeps its coordinates.
10. **Big files save slowly**: 42043-1 (7,909 parts) took 12 minutes to
    write its LDraw; the next slowest 14 s.
    *Since:* 0.35 s kept as it was, 2.8 s written whole.
11. **Opening the app's own save again is not always the same model**:
    3315-1 comes back 28 LDU higher with 5 parts gone; 42043-1 with 58 parts
    moved; 4 of 44 files have their author's steps changed.
    *Since:* a file kept is the same model opened again. Written whole, 3315-1
    keeps its parts (its sub-model titled "33009" went out as `33009.ldr` and
    came back as the part 33009). Written whole, every part comes back, a few
    of the biggest models' (6 of 4,139 in 42082-1, 8 of 7,908 in 42043-1)
    within rounding of where they were: a place is written to four decimals
    through its sub-model's frame, and the probe, printing tenths, finds them
    either side of one.
12. **Right stops stepping the timeline once a part has been taken from the
    bin by a click** (*fixed: the tile kept the keys, section 4*) (in a browser; the desktop probe takes its part without
    a click, and Right worked there). Next worked every time it was tried.
13. **Retired part numbers are written as the part they became** (5,623
    parts in 45 of 48 files): the same shape in the same place, another line.
    *Since:* written back under the file's own number.

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

`build` measures the worktree's own web export (`tools/export.sh web`), and
refuses one that does not offer every part, as the hosted build does: a
worktree has no `.env`, so give the export `PARTS_URL` (any value; only that
it is set decides, `tools/web_pack.py`) and `serve.py --parts` serves every
part. Give a Godot run its own `XDG_DATA_HOME` with `godot/export_templates`
linked in, or the export fails on "configuration errors".

Run it bare: it puts each Godot run and browser under `heavy` itself. It writes
to `bench/results/cadtask-<date>/` in the main checkout (git-ignored):
`REPORT.md`, the probe's rows, the judged rows and the pictures. The
comparison and the sampler are pinned by `tests/test_cadtask.py`.
