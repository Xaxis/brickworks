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
| ...what is lost | the author's name and licence (every file), LDCad's flexible parts (5 of 48), the steps (4 of 44). *Since: nothing; what the app cannot draw is kept and said; and LDCad's flexible parts are drawn, on the desktop and in a browser (flexdraw, section 1)* | not measured |
| Frames at 100 / 1,000 / 5,000 parts | over budget at every size on this box; in a browser the app's own work alone was over 33 ms in every act from 925 parts. Since "Big models, after": a turn, a step and select all no longer grow with the model, and the move of everything, its undo and redo are a fifth to a sixteenth of what they were (headless, 4,139 parts). Since "A part in hand over a big model": a part, a pin, a copy, a figure or a sticker in hand moves over 4,139 parts as over 92 | not measured |
| A set built from its steps, actions a part | 15.5 and 14.9 (the first 8 parts of two sets; modelled 12.6 and 9.5) | modelled 14.1 and 11.8 |
| ...put down exactly | 5 of 8 and 0 of 8: all 8 put down were in place and turn, 3 of them in the wrong colour; 8 of the 16 could not be put down | not measured |
| ...seconds a part | modelled 8.3 to 9.2, or 9.8 to 11.4 with the steps marked | modelled 10.1 to 10.6, or 10.3 to 11.3 |
| ...what cannot be built through the interface | both clip plates of the plane's step 4; 6157, whose number does not bring it first in the search; the old greys, by their swatch; parts off the 24 turns. *Since: the clip plates, a browser click where its ghost stood, and 8841-1's plates off the 24 turns swung onto their joints (sections 4 and 5)* | not measured |

**The answer to "why this and not Studio" is not yet "it is as faithful".**
A Studio builder's file does not come back as they wrote it, and building a
set from its booklet has no way to say where a step ends. By the model the
hand is faster here; the measured runs took a quarter to over a half more
actions than their model, most of it aiming.

**By the end of the same day it is, on what was measured.** Every one of the
48 real sets' files, and the six Studio and LDD files, comes back as its
author wrote it (section 1, "since"). `E` ends a step as Studio's Create step
does, a colour is found by its name, and a click puts the part where its
ghost stood: rebuilding the plane by hand, 29 of the 52 parts tried went
down, every one exact (sections 4 and 5). The 4,139-part crane opens in 3.3 seconds, not
13.7, and selecting all of it, undoing a move of all of it and stepping its
timeline take a tenth, a half and a thirtieth of a second (section 2, and
"Big files open in seconds"). A part in hand moves over it as over a
92-part model: a 2 x 4 brick's aiming 0.9 ms a move headless and its worst
place 2 ms, not 747 ("A part in hand over a big model"). Still behind:
places off the 2 LDU lattice, and Studio itself never run beside it.

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

### Since: what a file carries is drawn (the flexdraw unit, the same day)

**What changed.** LDCad's flexible parts are drawn. LDCad keeps the path a
hose, a rope, a band or a cable follows in `!LDCAD` meta lines and writes
what it draws below them, after `0 !LDCAD GENERATED`: primitives bent along
the path a segment at a time (42082-1's rope is `4-4cyli` 886 times), pieces
of a donor section the file carries, or the polygons themselves, with the
parts at its ends (a pneumatic tube's `165`, a string's `572a`) as parts.
Each such sub-model's skin is now built from its own lines without its
parts (`CustomParts.begin_skins`, `PartForge.build_skin`) as one part of its
own, each on the engine's worker threads beside the parts the file carries
(`CustomParts._built_at_once`), so a big set's first open hardly waits for
it. (A thread started for each instead hung a browser page on 42082-1's
four: a new thread's worker there starts only once the page is free.) It
goes in the sub-model as
one piece: in the copy's colour, where the file puts it, in the step the
file places the copy in, selected by a click on it and hidden with the rest. Its end parts stay
parts. The file is not changed: the piece stands for its GENERATED line, so
a save untouched is the file again, byte for byte; the piece moved,
recoloured or taken away writes the model whole, the skin carried as a part
(`0 FILE <sub-model>-flex.dat`, with the path's meta lines where nothing
else was in the sub-model, and the donor sections it is drawn from), which
opens again drawn. A generated sub-model of nothing but parts (a pneumatic
hose LDCad laid as 166 segments, a chain) has no skin: its parts were drawn
already, and `Flex.items_in` reads it as one hose. A skin is weighed by its
cover, not its box (`Stability.grams`): as a shell of the box it spans,
42082-1's rope weighed 1.3 kg; by its cover, 1.5 g.

And every build ships LDraw's primitives, all 2,844 (`assets/ldraw/p/`,
copied from `vendor/ldraw/p` by `tools/export.sh`; 10 MB of text, about
1.4 MB more over the wire in the compressed pck, 21.3 MB in all). A build has
no `vendor/`: the web build, and a desktop download, had only the eleven
primitives the element maker draws with, so neither could build a skin, nor
most of the parts a file carries.

**The files.** 42082-1 and the first three in SHA-1 order of their names
among the repository's files whose generated sub-models have 50 lines or more
that are not parts: 8202-1, 42058-1, 42053-1. Desktop renders on the
graphics card and pictures of a local web export in Chromium on SwiftShader
are in `bench/results/flexdraw-2026-10-16/` (`desktop-m39/` and `web-m39/`
from this branch on m39; `desktop/`, `web/` and `desktop-before/` from
the same change on m37, and before it).

| file | what is flexible | pieces of skin drawn, desktop | their faces | in a browser: sub-models drawn; parts not shown |
|---|---|---|---|---|
| 42082-1 (crane) | the hoist rope, two rubber bands, a PF cable, two flexible axles | 6 (of 4 sub-models) | 42,032 | 4 of 4; 3, where the fidelity unit's export said 167 |
| 8202-1 | a rubber string round a pulley | 1 | 8,480 | 1 of 1; 2 |
| 42058-1 | a ribbed exhaust hose, drawn as polygons | 1 | 11,840 | 1 of 1; 1 |
| 42053-1 | four rigid 3 mm hoses, two flexible axles, a flex-system hose (its 15 pneumatic tubes are `166` segments, drawn before) | 7 (of 3) | 5,632 | 3 of 3; 4 |

Each skin's faces were counted again by the Python pipeline
(`tools/ldraw/geometry.flatten`, which builds the library's meshes) from the
same file: the six skins that are nothing but skin match it face for face
(288, 8,560, 28,224, 2,336, 8,480, 11,840). Across the repository, the 238
files with generated content have 1,161 generated sub-models; 596 have a skin,
and every one built on the desktop (2.4 million faces, 49 s of building in
all, `skin_census.json`). Of those, 455 match the Python pipeline's flatten
of the same sub-model face for face, their bounds within 0.05 LDU; the other
108 compared all have fewer faces than it, as a skin must where its
sub-model has parts in it, which it leaves to be parts; 33 had no flatten to
compare with (`skin_vs_python.txt`). In the pictures, 42082-1's rope
runs from the winch over the boom and down to the hook block in two falls;
8202-1's white string loops the pulley and runs along the fork; 42058-1's
grey ribbed hose curves from the engine; 42053-1's hoses stand between the
valves and the frame. Before, those places were empty. In a browser the
same pieces are drawn, and what is still not shown is a carried part drawn
from an official part or subpart, which no build ships (42082-1's 13971,
8202-1's 57719 of `79` and `80` ribbed-hose segments, 42053-1's 26280 and
47223d-f1).

**Could a flexible part be one of Brickworks' own hoses** (`Flex`, Build,
Hose, tube or chain…)? Where LDCad laid real segments (a pneumatic tube of
`166`, a ribbed hose of `79`), it already is: those are parts, and
`Flex.items_in` reads the sub-model as one hose. Where it drew a skin, not
without loss. `Flex` lays segments along its own curve between two ends, and
its kinds have no rope, rubber band, cable or polygon skin; laid again, the
hose would not be where the author's is, and saving it back needs LDCad's
path written as LDCad writes it. Drawing the skin shows exactly what the
author saw, and the file stays theirs. Re-laying one as a Brickworks hose
is a step a person could ask for, written whole, not what opening does.

**Open time.** The four files opened as `bigmodel_probe` opens one (the
store's open, the app's handlers, two frames), each three times in one app,
one after another, before (`01ccd68`, release m39, with "openspeed"'s faster
open) and after side by side at once on this box (load about 25 on 24
cores), twice, so both had the same machine
(`bench/results/flexdraw-2026-10-16/open-m39-*.log`). The first open of a
file builds what it carries; the others find it built.

| file | parts | first open, before → after | opened again, quickest of 2 |
|---|---|---|---|
| 42082-1 | 4,139 | 3.30 → 3.61 s; 3.68 → 4.12 s | 1.00 → 1.04 s; 1.32 → 1.45 s |
| 8202-1 | 69 | 5.2 → 11.3 s; 0.23 → 11.8 s, *see below* | 70 → 89 ms; 22 → 98 ms |
| 42058-1 | 138 | 1.80 → 1.87 s; 5.65 → 1.07 s | 258 → 319 ms; 270 → 276 ms |
| 42053-1 | 2,719 | 2.03 → 2.13 s; 1.74 → 1.65 s | 275 → 292 ms; 319 → 288 ms |

Building a skin is the new work (42082-1's four 1.0 s on one thread,
8202-1's 0.16 s, 42058-1's 0.33 s). Each is built on the engine's worker
threads beside the parts the file carries, begun before them and joined
after, and a sub-model already read this session is not read again: on
42058-1 and 42053-1 that leaves nothing the box's noise does not swamp.
**The misses.** 42082-1 opens 9 to 12% slower the first time and 4 to 10%
after. 8202-1, 69 parts, opens again 20 to 75 ms slower, in the app's
handlers after the open (laying the floor takes 27 ms more: the skin's box,
turned, reaches 20 LDU below the model; the rest was not found). And its
first open right after 42082-1 waited for the app's check of 42082-1, still
reading the library on a worker: a new part is not added while a check
reads (`PartLibrary.add_custom`), and a skin is new on every first open in a
session, where a part a file carries is kept on disk and found at start
(the before side's first opens of it took 5.2 s and 0.23 s).

**The round trip** (`cadtask.py roundtrip`, the 54 files of the fidelity
sample, `bench/results/flexdraw-2026-10-16/roundtrip-m39/`) is as the fidelity
unit left it: 54 of 54 saved untouched are the same file, every meta line
and the author kept, the app's model the same opened again, 44 of 44
author's steps kept, nothing lost on open. And the 4,713 lines of skin in 5
of the files, which were kept and said, are drawn: 62 pieces in 8 files (3
of them skins of polygons only, which no count had seen). What is still not
shown is 2 parts in 2 files the library has not got, where it was 4,715; the
same shapes up to the lift, 52 of 54 where it was 47. The judge reads a piece
of skin as the lines of its copy it stands for (`cadtask.skins_apart`), or it
calls the piece added and every primitive lost.

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
| a part in hand, a move at its worst (since: "A part in hand over a big model") | 47 → 32 | 616 → 30 | 1,177 → 42 |

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
the same 2,015 parts at once and had 2,441 and 2,436 six minutes on
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
measured here, and it is left. *Since: it was the part's resting height asked
column by column over the crane's tower, 663 ms a frame → 30 ("A part in hand
over a big model").*

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

### Big files open in seconds (2026-10-16, later)

Opening 42082-1 (a Technic crane: 4,139 parts shown, parts of its own
carried in the file, an LDCad rope) took 18 s headless; Studio opens it in
seconds. `ModelStore.open_text` now keeps what each phase took
(`open_phases`), and `bigmodel_probe.gd -- --open` opens a file and nothing
else, `--dump` writing the world it opened part by part. Each file's first
open in a fresh process (the parts it carries built, as for a person opening
it), headless at load 25 to 45, main (e502c58) and this branch run side by
side, in ms (`bench/results/openspeed-2026-10-16/final-*.log`):

| phase | 75969-1 (925 parts) | 42082-1 (4,139 parts) |
|---|---|---|
| reading the file (`LdrModel.parse`) | 66 → 19 | 763 → 240 |
| building the parts it carries | 1,098 → 296 | 1,854 → 847 |
| putting the parts down: drawn, covers, lattice | 880 → 240 | 6,806 → 1,857 |
| everything else in `open_text` | 22 → 24 | 130 → 129 |
| the bar's opened handlers | 716 → 52 | 4,035 → 128 |
| **open, until it settles** | **2,827 → 677** | **13,687 → 3,314** |
| opened again, the carried parts built (the quicker of two) | 550 → 217 | 4,365 → 1,313 |

Main's own run of the same probe, earlier in the day, was 18.0 s for
42082-1 (load 40 to 60); across this unit's runs main took 10.6 to 13.7 s
and this branch, as committed, 3.2 to 3.3 s. Where it went, and what changed:

- **One handler of the bar's opened, 3 to 4.9 s, was the offer to seat
  old models' parts** (`SeatOffer.check`, `Seating.misplaced`). Not its walk
  over the parts: for each part and turn it found the corner of the part's
  cover by making every cell of it (`Builder._cells_for`), once in Seating
  and once in `Assistant._corner_cell`, and a Technic part's cover is
  thousands of cells. The corner now comes from the cover's boxes
  (`Builder._cell_span`); on every part of both files in all 24 turns and
  the file's own, at four places, on and off the lattice, it is the same
  corner (37,000 of 37,000).
- **Putting the parts down was the turned parts' covers.** A part off the
  24 turns has its cover worked out cell by cell (`BrickLattice
  .cells_for_turned`): 510 covers and 1.27 million cells on 42082-1, 5.4 s of
  the 6.3 s it spent placing. They are the same covers by the same code,
  now set going on the engine's worker threads as each part is read and
  worked out while the parts are drawn (`Builder.prepare_covers`,
  `finish_covers`). And a part's cover is worked out once for each part
  and turn, with its bound and rows, and moved to where each part stands
  (`Builder.register`, `BrickLattice.occupy_moved`). Making the cell walk
  itself cheaper, by line rather than by cell or skipping lines a thin box
  never reaches, gave the same cells no faster, and was left out.
- **The parts a file carries were built one after another**, each made and
  voxelised in GDScript (`PartForge`): 28 of 42082-1's, 15 parts and the
  subparts and primitives they are drawn from, the biggest (24121) half a
  second alone. They are built all at once on worker threads now,
  their meshes made on the main thread (`CustomParts._built_at_once`); the
  parts kept from files opened before are built the same way when the app
  starts (`CustomParts.load_all`).
- **Reading split every line a character at a time** (`LdrModel._fields`):
  now the engine's split, the same fields on all 62,532 lines of both files,
  as written and trimmed.

Nothing is lost. The world each file opened into, written part by part
(number, colour, transform, sub-model path, step, lattice cover, and the
store's title, unshown parts, lift, floor and set, the sub-models' steps and
the undo history), is byte for byte main's for both files. The 54 files of
the round trip (`tools/bench/cadtask.py`'s judge on `roundtrip_probe.gd`)
judge exactly as the fidelity unit's did: 54 of 54 saved files the author's
own, as LDraw and as .io. A build without threads (the "Web (no threads)"
export) works the covers and the carried parts out on its one thread, as
before; it gets the seat offer, the moved covers and the reading.

In a browser (each build's threaded export served locally with every part,
`cad_frames.mjs --only=open`, SwiftShader on this box; the web build has no
LDraw library, so the parts a file carries are kept in it and not shown, on
both), File, Open to the first parts down: 75969-1 2.6 and 3.1 s → 1.2 and
1.4 s; 42082-1 6.7 s → 4.8 s (one run; in the second the count of parts
fired early on both builds). The worst frame's own work: 2.4 to 2.9 s → 1.0
to 1.1 s, and 6.3 s → 3.6 s. Until the page is quiet is still 8 to 60 s on
either build, the parts outside the web pack arriving one by one and each
drawn in software, and was no better here (`web-*/frames*.log`).

The probe (`bigmodel`, in `tools/check.sh`) now also opens the two sets,
where the checkout has `vendor/omr`, each once and first: 42082-1 must open
whole and take no more than LINEAR's share of its 4.5 times the parts (at
most 8.0x). This branch: 4.5x (693 ms and 3,094 ms); main 5.3x (1,968 ms and
10,478 ms), run side by side.

Found on the way, and left: **the engine dumps core as it quits after
opening any file that carries parts of its own** (75969-1 and 42082-1 every
time, on main as on this branch; 4883-1, which carries none, never; not
under gdb, and not mended by emptying PartForge's cache of parsed primitives,
waiting 600 frames, or not freeing the window first). On the desktop that is
a crash as the app closes. The check opens the sets in a process of its own
so it can say so rather than fail on it.

Mended the same day. Not the parts the file carries but its size: 10129-1,
1,454 parts and none carried, did it too, and 4883-1 is 121 parts. A model
of 600 parts or more is weighed on a worker after every change, and the
engine keeps a worker task until somebody waits for it; quitting while the
weigh ran left its task to the engine, which freed it after GDScript had
gone (SIGSEGV in a null lock, then SIGABRT from the crash handler). A task started from GDScript and never
waited for does it in a ten-line script. Every task the app waits for now
goes through `WorkerTasks`, which collects those still out as the tree goes,
and the app writes the working model as it closes: an edit made in the 2.5 s
before was lost too. The check opens the sets in its own run again and
quits with the weigh on a worker, so a crash on the way out fails it;
`quit_probe` quits by the close request and File, Quit after an edit.

### A part in hand over a big model (2026-10-16, later)

"Big models, after" left a part in hand: swept over 42082-1 on the desktop's
graphics card it still had frames of a second, and in a browser a move's own
work was 355 ms at 925 parts and 1.1 s at 5,025. A builder sweeps parts over
the model all day.

**Where a move went.** `bigmodel_probe.gd -- --sweep --profile` takes each
of five things into hand as a person does (a 2 x 4 brick and a Technic pin
by their tiles, a copy of eight parts by Copy and Paste, a figure from the
figure builder, a sticker), sweeps it across the model 40 moves, a step a
frame, then aims again at each place alone (`Main._refresh_preview`) and in
its pieces, and at every place on a 32 x 20 grid over the model: one line
across a model misses where aiming is dear. On 42082-1's 4,139 parts, main:

- **A part's resting height was asked column by column** (`Builder._settle`,
  `BrickLattice.resting_height`): a 2 x 4 brick stands on 800 columns of
  2 LDU, and each column read every part in its 40-LDU column bucket box by
  box. Over the crane's tower, where a bucket holds hundreds of Technic parts
  of 74 boxes each, one aim took 747 ms headless and 921 ms on the desktop.
  A copy held asked it for each of its boxes (364 and 743 ms), a figure for
  its feet (198 and 297 ms).
- **A Technic pin asked every connector of every part** which one it was
  aimed at (`JointSnap.aimed_at` over all 14,108): 12.7 ms every move, wherever
  it was.
- **A sticker asked every part** whether the line met its box
  (`Stickers.face_at`): 9 to 13 ms every move, and then the triangles of every
  part whose box it met, in the world's order.
- The page's state, the hover outline, the cursor and the moment told at once
  cost nothing a move (0.02 ms together). In a browser the frames' own work
  from process to drawing (`brickworksState.busy`) stayed under 30 ms in every
  move even where the move took 1.2 s: the aiming is the pointer's own
  handling, done before the frame's process, and the page's timing missed it.
  A move is read from the drawn frame less its WebGL (`drawn_own_*`).

**What changed**, each placing exactly where it did:

- A footprint rests in one pass over the parts under it
  (`BrickLattice.rise_onto`, which `surface_under` is now one box of): each
  part in the buckets the boxes reach asked once, by its bound first, the
  highest first, and none after the first whose top cannot lift them more.
  `_settle`, `settle_figure` and a held group's every box (`Carry.aim`) use
  it; `resting_height` is gone.
- The connectors and the parts' drawn boxes are kept by where they are
  (`BrickGrid`, 40-LDU cells), part by part as the model changes: a line
  from the eye asks only the parts whose cells it crosses, in the world's
  order, so the end aimed at (`JointSnap.site_grid`, `near`) and the parts
  a sticker's line meets (`Stickers._along`) are what asking every one
  found. `Builder.joint_sites` is read from the same kept ends.
- A sticker's faces are asked nearest part first, and a part whose box
  begins past a face already struck is not asked; its flat faces are read
  from the triangles kept for aiming, not fetched back from the drawing at
  every move.

Headless (the app's own work, nothing drawn), the aiming alone, median of
the sweep's 40 moves and the worst place of the 640, in ms, main → this
branch; a frame of the sweep is the engine's 7 ms at every size on both but
for the pin on 42082-1 (11.4 → 6.9):

| in hand | 4883-1 (92) | 75969-1 (925) | 42082-1 (4,139) |
|---|---|---|---|
| a 2 x 4 brick | 1.3, 15 → 0.3, 1.6 | 1.4, 419 → 0.5, 1.4 | 1.5, 747 → 0.9, 2.2 |
| a Technic pin | 0.7, 12 → 0.6, 15 | 1.4, 124 → 0.6, 91 | 12.7, 141 → 1.3, 81 |
| a copy of eight parts | 0.5, 4 → 0.4, 4 | 0.7, 51 → 0.7, 1.5 | 1.8, 364 → 1.7, 71 |
| a figure | 1.3, 8 → 1.0, 1.4 | 1.2, 138 → 1.0, 2.2 | 1.7, 198 → 1.5, 2.8 |
| a sticker | 23, 55 → 23, 39 | 1.6, 45 → 0.03, 37 | 9.3, 54 → 0.04, 35 |

On the desktop, windowed under xvfb on the box's graphics card (a frame
copied to xvfb is most of 15 ms here), the sweep's median and worst frame,
in ms, main → this branch:

| in hand | 92 parts | 925 parts | 4,139 parts |
|---|---|---|---|
| a 2 x 4 brick | 19, 41 → 13, 15 | 18, 354 → 16, 23 | 29, 663 → 22, 30 |
| a Technic pin | 16, 33 → 15, 28 | 18, 105 → 16, 31 | 51, 124 → 22, 91 |
| a copy of eight parts | 16, 24 → 14, 19 | 17, 28 → 18, 23 | 25, 364 → 23, 42 |
| a figure | 17, 36 → 16, 26 | 18, 95 → 17, 24 | 26, 331 → 22, 31 |
| a sticker | 42, 87 → 20, 84 | 19, 55 → 17, 24 | 38, 130 → 23, 86 |

In a browser on SwiftShader (`cad_frames.mjs --only=place --arrive=900`:
the parts a model fetches as it opens all arrived first, each build served
on a port of its own), a 2 x 4 brick swept 40 moves, each drawn frame's own
work less its WebGL, median, 95th percentile and worst, in ms:

| | 4883-1 (92) | 75969-1 (901 here) | 42082-1 (3,973 here) |
|---|---|---|---|
| main | 29, 45, 47 | 30, 445, 616 | 31, 958, 1,177 |
| this branch | 15, 22, 32 | 22, 27, 30 | 23, 34, 42 |

The worst moves on main are the brick over the dense middle of each model,
as on the desktop. The browser leaves out the parts these files carry
(section 1's gap 5), so 75969-1 and 42082-1 are fewer parts here; both
builds opened the same counts. One move at 5,025 parts is over 33 ms at the
95th percentile (34) and the worst (42), on a box at load 30 to 40.

Every ghost where it was: the 600 moves of the desktop sweeps (548 with a
ghost; the sticker's faces are drawn there) put each ghost in the same place
to 0.01 LDU, the same turn and the same can-go-down on main and this branch
(`windowed-*.json`), and at every move of every sweep the near ones asked
found what asking every one found (the check below). `placing_probe`: 35 of
35 clicks across the plate's edge where the ghost stood, and every part
after; `handbuild_probe` 352 checks, `feel_probe` 48, and the headless
probes the change reaches pass but `technic_hand`, whose two failures (the
design check seats a bar and a clip put 2 LDU off, where the probe wants
them refused) are the same on 01ccd68 without this change. In a browser,
`placing_flow.mjs` on this branch's export: 35 clicks across the edge, 0 off
the ghost; 8 of 11 parts where their ghosts stood and 4 of 4 as the file has
them, the hinge base, the hinge top and the 3040b off exactly as in m38's
preview run, place for place.

**The check.** `bigmodel` (`tools/check.sh`) sweeps the five over its made
models of 1,000 and 5,000 parts (one size of their four bricks now a Technic
brick with holes, so a pin has holes to find) and holds each move flat: the
sweep's frame at most 3x, and the aiming alone at most 3x with a 1 ms floor.
Main fails two: a pin 3.8x (2.2 → 8.3 ms) and a sticker 5.3x (2.5 → 13.0 ms).
And it holds that the connectors the builder keeps are `sites_in`'s in its
order, that the end aimed at is the same with and without the grid at every
move, that every part a sticker's line meets is in `_along` in order, and
(windowed) that the part a sticker goes on is the one every part's faces
asked in order strike first. The tower's columns are not in the made
models, which grow wider and not denser: the column-by-column cost was
density, not size, and is shown by the real set above, not held by the check.

**Left.** A pin's first aim at a joint it was not on searches the ways onto
it (`Builder._best_on_joint`: up to 64 poses, each asked for room and the
joins it makes): 60 to 140 ms on 925 and 4,139 parts, on main the same; it is
the parts round the joint, not the model's size. A sticker over 4883-1's
detailed parts asks the triangles of the part it lies on: 20 to 40 ms a
move, main too. A held copy's collision test over the densest place, 71 ms at
one place of 640. The first move after a change with a pin or a sticker in
hand walks the model for what changed (`BrickGrid.follow`): 2 ms at 925 parts
and 8 to 16 at 4,139, against reading every connector again, 24 to 63 ms;
the first ever keeps every part, 58 to 113 ms.

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

**And a ghost left behind, on the desktop.** A ghost re-aimed with no
event of its own, as when the part's shape arrives after the pointer has
moved onto the model, was aimed at the system's pointer, which with a
probe's events is wherever the real pointer was left. Now it is aimed where
the app last saw the pointer move or press, unless the system's pointer has
moved since over a window of the app's own (`Main._pointer`).
`placing_probe` takes 3022 and 3023 from their tiles and moves onto the
model in one move and in two: the first case failed before (its ghost 260
pixels from the pointer) and all four pass. The browser's like case is not
this one (below).

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

**The first aim after a part is taken from its tile, in the browser.** The
flow's other seven parts (a bar in a clip, a hinge, slopes, a Technic brick
and a pin) were each taken from the search, the pointer moved onto the
model in one jump, and the ghost read: every one stood where the jump had
started, 500 LDU and more off, behind the bin, until the next move, and a
click put the part under the pointer (this is the "540 to 560 LDU" of
section 3's failed runs, and the first of the edge's 35 clicks). The page
received the jump's last move and Godot's own pointer followed it, but the
app's input never saw it: it went to a window of the app's own, the tile's
tooltip, up as the pointer left (`diag3`: the app's last move halfway, the
system's pointer on the model). Now a move the app never saw is followed
from the system's pointer once the moves stop (`Main._follow_unseen_move`;
not while a button is down or a menu or a dialog is up).

| browser, `placing_flow.mjs` | the edge's 35 clicks | the seven parts after a take |
|---|---|---|
| before | 1 elsewhere (the first) | 0 put where the ghost stood |
| after (`web5`) | **0 elsewhere** | **4 of 7**; the hinge base and the 2 x 1 slope a stud from their ghosts, and the hinge's top red where the flow aimed it |

The two left are not explained: the ghost followed is aimed at the system's
pointer, which a browser gives in whole pixels, and the click's own move,
at the fraction, may aim a stud over; a person's hand moves again before it
clicks, and the ghost then follows that move exactly.

**The whole plane again** (`cadtask.py build --only 5762-1 --most 0
--minutes 40`, its flow on an export with the click's fix,
`bench/results/placing-2026-10-16/plane`), against the run before:

| | tried | put down | exact | steps kept | actions a part | seconds a part |
|---|---|---|---|---|---|---|
| before (`buildux-2026-10-16/whole`) | 35 | 16 | 11 | 8 of 8 | 15.7 | 27.2 |
| after | **52 of 52** | **29** | **29** | 12 of 12 | 15.8 | 47.6 (the box at load 40 to 70) |

Both clip plates and both 1 x 6 plates that then had no room went where the
file has them, and every part put down is exact. The 23 parts still not
put down are places off the 2 LDU lattice (6141s at z 63 and 72, 2421 at
y 35; whole LDU, not even), parts that stand on one of those, 54383/4 and
41769 the wedge plates of step 5, whose ghosts would not come to their
place in eight aims, and the propeller (50746) on its 4286. Off-lattice
places and the wedge plates are the next gaps.

## The gaps, by how much a builder would feel them

Nothing here was fixed in the unit that found them; 1, 2, 4 (the clip
plates), 6 and 12 were fixed after (section 4), 3 had its own (section 2,
"Big models, after"), and 4's parts off the 24 turns on a joint after that
(section 5).

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
3. **Every interaction in a browser was over budget from 925 parts up, by the
   app's own work alone**: an orbit frame's own work 158 ms at 925 parts and
   2.7 s at 5,025; a part swept over the model 355 ms and 1.1 s. That is
   before any drawing, so a graphics card does not take it away. Since
   "Big models, after" (section 2) a turn, select all, a move of everything
   with its undo and redo, Delete and its undo and a step no longer walk
   the model where they should not; a part swept in hand still does.
   *Since "A part in hand over a big model" (section 2): a move's own work
   in a browser at 5,025 parts is 23 ms median and 34 at the 95th
   percentile, against 31 and 958 (1.2 s worst); headless and on the desktop a
   move no longer grows with the model, a brick, a pin, a copy, a figure or
   a sticker.*
4. **Some parts cannot be put where the set has them through the
   interface** (*the clip plates fixed, section 4; turns off the 24 not*): both 1 x 1 clip plates of the plane's step 4 (the ghost stood
   10 LDU off and came no nearer), and parts at angles off the 24 turns or at
   places that are not whole LDU (8841-1 has 4 and 14 of them).
5. **A file's own parts are left out**: 42082-1 opens with 3,973 of its
   5,025 parts in a browser, the 1,052 left out being parts the file carries
   (`0 FILE 42082 - 18575.dat`), and with 4,139 on the desktop.
   *Since:* none is dropped. What the app cannot draw stays in the file and is
   saved back, and File, Open names it. *And since flexdraw, a browser builds
   them too (every build ships LDraw's primitives): 42082-1 in a browser
   leaves out 3, copies of one part drawn from an official subpart, where it left out 167.*
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
   *Since:* kept in the file and named once each; *and since flexdraw,
   drawn, one piece each, as LDCad drew them (section 1).*
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
