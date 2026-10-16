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
| A real set's file opened, saved and opened again: exact? | 0 of 48 exact; 2 exact but for the model moved onto the ground; 38 the same shapes once retired numbers are allowed. the repository's five .io and one LDD file: 5 of 6 exact | not measured |
| ...what is lost | the author's name and licence (every file), LDCad's flexible parts (5 of 48), the steps (4 of 44) | not measured |
| Frames at 100 / 1,000 / 5,000 parts | over budget at every size on this box; in a browser the app's own work alone is over 33 ms in every act from 925 parts | not measured |
| A set built from its steps, actions a part | 16.3 (first 8 parts of the plane; modelled 12.6) | modelled 14.1 |
| ...seconds a part | modelled 8.3 to 9.2, or 9.8 to 11.4 with the steps marked | modelled 10.1 to 10.6, or 10.3 to 11.3 |
| ...what cannot be built through the interface | both clip plates of the plane's step 4; parts off the 24 turns; a part whose number does not come first in the search | not measured |

**The answer to "why this and not Studio" is not yet "it is as faithful".**
A Studio builder's file does not come back as they wrote it, and building a
set from its booklet has no way to say where a step ends. By the model the
hand is faster here; the measured run took nearly a third more actions than its
model, all of it aiming.

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
frame that draws nothing costs a millisecond, so the median says nothing):

| act | 92 parts | 925 parts | 5,025 parts |
|---|---|---|---|
| orbit | 1,067 / 1,452 | 4,155 / 5,648 | 13,951 / 20,496 |
| a part in hand, swept | 2,388 / 3,807 | 3,200 / 4,132 | 12,631 / 105,813 |
| select all | 14 / 980 | 9,268 | over 3,017 (no frame finished) |
| delete all | 5 / 302 | 2,884 | 36,203 |
| undo | 5 / 125 | 2,895 | over 3,010 (no frame finished) |
| open, until it settles | 4.5 s | 22 s | 32 s |
| timeline (B) opens | 0.5 s | 4.3 s | 75 s |

The app's own work in its worst frame (the frame less its time in WebGL):

| act | 92 parts | 925 parts | 5,025 parts |
|---|---|---|---|
| orbit | 42 | 158 | 2,664 |
| a part in hand, swept | 108 | 355 | 1,130 |
| select all | 43 | 90 | — |
| delete all | 29 | 203 | 132 |
| undo | 104 | 39 | — |
| open | 193 | 2,459 | 6,528 |

Over 33 ms in every act from 925 parts up, and in the orbit, the sweep, the
select and the undo at 92. Two things the browser run found besides:

- **42082-1 opens in a browser with 3,973 of its 5,025 parts** (4,139 on
  the desktop). The browser says the 1,052 it leaves out are not in the
  library: they are parts the file carries itself (`0 FILE 42082 -
  18575.dat`, 115 such sections), and the web build has no LDraw library to
  build a carried part from. Why the desktop leaves 886 out was not looked
  at.
- **Right does not step the timeline in the browser.** After B, five presses
  of Right left it on step 1 of 15 (and of 240, and of 363). The status
  bar's list of keys gives the timeline Home, End and space only; Main steps
  it on Right when it is up, but in the browser it did not move. So the
  browser's step change was not measured; `cad_frames.mjs` now clicks Next,
  as the desktop run does.

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

**Measured.** The first 8 parts of the plane, on a page of its own (the
three sets side by side on one browser read one page's ghost while another
held the machine, and put the plane's first part 560 LDU from where it was
recorded; the flow now builds them one after another):

| | tried | put down | exact (place and turn) | actions | actions a part | seconds a part, this box |
|---|---|---|---|---|---|---|
| 5762-1 Plane, first 8 parts | 8 | 6 | 6 of 6 in place and turn; 5 in the file's colour (one 71 for 7, the swatch finder's mistake, since fixed) | 130 | 16.3 | 56 |

The actions: 49 pointer moves, 25 clicks, 26 keys and 30 characters typed;
22 of the pointer moves were corrections, the ghost not yet where the file
has the part. The model of the same 8 parts says 12.6 actions a part; the
run took 16.3, the difference all in pointing (30 more pointer moves) and
clicks (12 more). Its motor time by the model's operator times is 9.3 s a
part against the model's 11.4 (the model also counts thinking, M, which a
script does not do), and the wall clock 56 s a part, most of it waiting for
software drawing. The side-by-side picture
(`build/trial-0828/5762-1_Plane_side_by_side.png`) shows the six plates of
the plane's first steps in the file's places and colours beside the whole
plane opened from its file.

The two parts not put down are the finding: both 1 x 1 clip plates (4081b)
of step 4, where the ghost would not stand at the file's place in 6 or 7
aims (it stood 10 LDU too high and 10 to 20 LDU aside, and came no
nearer). Of the actions, 7 were searches, 4 colour picks and 7 turns.

A run one set after another (the plane, then 8643-1) met the fault the
side-by-side run had: the plane's first plate was not where the flow had
recorded it, so the next seven parts, each meant to stand on it, found only
the baseplate (the ghost 8 LDU low) and were given up. The likely cause is the
page's report of the ghost lagging the pointer on a loaded box; it was not
proven. The flow now reads the first part's place back from the app's own
LDraw export before it aims anything else. That run is the one to quote next;
it had not finished when this was written.

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

Nothing here was fixed in this unit; each is a unit of its own.

1. **No "next step" while building.** A builder following a booklet, or
   writing one, puts each step's parts in its own step. Here every step is
   its parts shift-clicked and Edit, New step from selection, after. Studio
   has a Create step button (E) and puts new parts in the current step. On
   the 21-step plane this turns Brickworks from 14% faster a part to 1%
   slower, by the model.
2. **A part number typed in the search does not always come first.** "6157"
   puts 3816cpc44 first; the flow had to give up on that part. A builder
   working from a parts list types numbers all day.
3. **Every interaction in a browser is over budget from 925 parts up, by the
   app's own work alone**: an orbit frame's own work 158 ms at 925 parts and
   2.7 s at 5,025; a part swept over the model 355 ms and 1.1 s. That is
   before any drawing, so a graphics card does not take it away.
4. **Some parts cannot be put where the set has them through the
   interface**: both 1 x 1 clip plates of the plane's step 4 (the ghost stood
   10 LDU off and came no nearer), and parts at angles off the 24 turns or at
   places that are not whole LDU (8841-1 has 4 and 14 of them).
5. **A file's own parts are left out**: 42082-1 opens with 3,973 of its
   5,025 parts in a browser, the 1,052 left out being parts the file carries
   (`0 FILE 42082 - 18575.dat`), and with 4,139 on the desktop.
6. **Colours are found by look in a palette of 320**: the old greys (7 and
   8), all over older sets, show only after All, and Black and Rubber Black
   look the same. Studio's colour menu filters as you type
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
12. **Right does not step the timeline in a browser**; on the desktop it
    does, and so does Next.
13. **Retired part numbers are written as the part they became** (5,623
    parts in 45 of 48 files): the same shape in the same place, another line.

[5459441964695]: https://studiohelp.bricklink.com/hc/en-us/articles/5459441964695

## How to run it again

```sh
python3 tools/bench/cadtask.py sample      # the files each part uses, the same every run
python3 tools/bench/cadtask.py all         # all three, then REPORT.md
python3 tools/bench/cadtask.py roundtrip   # or one: roundtrip, frames, build, report
```

Run it bare: it puts each Godot run and browser under `heavy` itself. It writes
to `bench/results/cadtask-<date>/` in the main checkout (git-ignored):
`REPORT.md`, the probe's rows, the judged rows and the pictures. The
comparison and the sampler are pinned by `tests/test_cadtask.py`.
