# The studio on phones

phonetruth, 2026-11-18. The owner asked two things: does the studio need a
mobile version, or should phone users be warned? This page answers both
from measurements. Every earlier phone check (phone_flow, phonewalk_flow,
tablet_flow and the probes' phone sizes) was desktop Chromium pretending
to be a phone, on this box's fast CPU and SwiftShader. None had run
WebKit, a phone's CPU speed, a phone's memory or a mobile network.

## The answer, short

- **One adaptive studio, not a separate mobile version.** What fails on a
  phone is the engine's start and its memory, not the layout. A separate
  mobile mode on the same engine would fail the same way. The phone layout
  already does the walk by finger: all 23 acts at 390x844, and 21 on
  WebKit's shorter iPhone screens (390x664, 393x659), where Motions' list is
  under a row tall.
  Only a native app changes the engine's limits, and that is not worth its
  cost before real phones' numbers say so (the judgement, below).
- **Warn, never gate,** and only with numbers the owner can change. Three
  warnings are built, and a fourth for a start the browser refuses:
  - a browser without WebGL 2 is told at once and the download stops;
  - a phone opening a model past **10,101 parts** is asked first;
  - a phone's first visit says how long it will take;
  - a refused engine memory is said plainly instead of hanging.
- **The owner sets the numbers** in `/admin#switches`, under **Phones**:
  `phone_parts` (10,101) and `phone_start_s` (40 s). Each is per deployment,
  audited, and shown beside the measured value.
- **The start by phase, and the first cut** (webstart11, below): the
  scripts' compile is the largest phase on every engine (24.5 s of a 72 s
  first visit at CPU/4) and fills 432 MB; the catalogue's JSON filled the
  last 87 MB. The web now reads the catalogue from columns: 519 → 432 MB
  of Wasm memory, the catalogue's read x0.37 at CPU/4.
- **Before any ad push**, what breaks first and what it costs:
  [docs/CAPACITY.md](CAPACITY.md).

## What works on what

Measured on 2026-11-18 against brickworks.diy, signed in with a shared test
account, each configuration in a fresh browser profile. Five stand-ins:

- Chromium's phone emulation at this box's full speed (390x844, touch);
- Playwright's WebKit as an iPhone 13 and as an iPhone 15;
- Chromium at a quarter and at a sixth of this box's CPU, on DevTools' Fast
  4G.

The two WebKit columns differ only in screen and user agent, not in speed,
so the gap between them is the box's load (71 against 26).

| | Chromium as a phone | WebKit as an iPhone 13 | WebKit as an iPhone 15 | Chromium, CPU ¼, Fast 4G | Chromium, CPU ⅙, Fast 4G |
|---|---|---|---|---|---|
| The studio starts | yes, 10.5 s | yes, 21.3 s | yes, 12.4 s | yes, 58.4 s | yes, 94.8 s |
| A return starts it | 9.1 s | 21.3 s (uncached, below) | 13.8 s (uncached) | 42.8 s | 81.7 s |
| Every gallery model opens and stays, up to 10,101 parts | yes | yes | yes | yes | yes |
| Past the gallery, up to 50,505 parts | yes (1.65 GB tab) | yes | yes | not tried | not tried |
| Turning the car, frames/s; own work p95 | 6.8/s; 13 ms | 3.8/s; 61 ms | 9.3/s; 12 ms | 8/s; 39 ms | 3.1/s; 196 ms |
| Turning Orthanc (10,101), frames/s; own work p95 | 4.2/s; 17 ms | 2/s; 40 ms | 4.5/s; 22 ms | 5.1/s; 58 ms | 2.1/s; 188 ms |
| The walk by finger, 23 acts | 23 (20 + Motions 3 re-walked) | 21 | 21 | 20 + Motions not re-walked | 20 + Motions not re-walked |

Frames per second here are measured to a WebGL fence on SwiftShader (or
llvmpipe for WebKit), a software GPU. They measure what the app's own work
costs per frame, not a phone's frame rate: a phone's GPU draws far faster
than a CPU drawing in software.

The whole measure, as `phonetruth_flow.mjs --table` wrote it (the results
are in `bench/results/phonetruth-2026-11-18/measures/`):

| | Chromium as a phone (today's checks) | WebKit as an iPhone 13 | WebKit as an iPhone 15 | Chromium, CPU 1/4, Fast 4G | Chromium, CPU 1/6, Fast 4G |
|---|---|---|---|---|---|
| first visit, cold, to working | 10.5 s | 21.3 s | 12.4 s | 58.4 s | 94.8 s |
| … engine's files had come | 0.9 s | 5.4 s | 2.3 s | 10.2 s | 11.4 s |
| … engine started | 7.5 s | 15.9 s | 9.4 s | 52.2 s | 85.0 s |
| … started once its files had come | 6.6 s | 10.4 s | 7.0 s | 42.0 s | 73.6 s |
| … over the wire | 9 MB | 19 MB | 19 MB | 9 MB | 9 MB |
| a return, to working | 9.1 s | 21.3 s | 13.8 s | 42.8 s | 81.7 s |
| peak memory, first visit (Pss / Wasm / JS heap) | 807 MB / 519 MB / 15 MB | 1748 MB / 519 MB / – | 1774 MB / 519 MB / – | 890 MB / 519 MB / 13 MB | 859 MB / 519 MB / 13 MB |
| Orthanc (10,101 parts) opened | 32.5 s | 58.1 s | 31.2 s | 62.4 s | 128.4 s |
| peak memory, Orthanc | 935 MB / 519 MB / 18 MB | 1821 MB / 519 MB / – | 2484 MB / 519 MB / – | 942 MB / 621 MB / 15 MB | 930 MB / 620 MB / 25 MB |
| turning the car: frames/s; own work p95 | 6.8/s; 13.1 ms | 3.8/s; 60.5 ms | 9.3/s; 11.6 ms | 8/s; 39.1 ms | 3.1/s; 195.6 ms |
| turning Orthanc: frames/s; own work p95 | 4.2/s; 17.1 ms | 2/s; 39.6 ms | 4.5/s; 21.7 ms | 5.1/s; 57.9 ms | 2.1/s; 188 ms |
| largest model open and kept | Wizard's Tower (10,101) | Wizard's Tower ×5 (50,505) | Wizard's Tower ×5 (50,505) | Wizard's Tower (10,101) | Wizard's Tower (10,101) |
| … A friendly maintenance robot (151) | 15.8 s; 875 MB / 519 MB / 16 MB | 27.0 s; 1760 MB / 519 MB / – | 17.7 s; 1733 MB / 519 MB / – | 43.3 s; 881 MB / 519 MB / 14 MB | 90.3 s; 813 MB / 519 MB / 15 MB |
| … 21011 Brandenburg Gate (362) | 18.3 s; 841 MB / 519 MB / 13 MB | 29.5 s; 1761 MB / 519 MB / – | 16.8 s; 1723 MB / 519 MB / – | 46.1 s; 886 MB / 519 MB / 13 MB | 86.1 s; 828 MB / 519 MB / 15 MB |
| … 6080 King's Castle (741) | 24.9 s; 855 MB / 519 MB / 18 MB | 27.4 s; 1927 MB / 519 MB / – | 23.0 s; 1914 MB / 519 MB / – | 71.8 s; 893 MB / 519 MB / 16 MB | 86.6 s; 856 MB / 519 MB / 18 MB |
| … A barn owl (1,032) | 13.7 s; 861 MB / 519 MB / 16 MB | 20.8 s; 1823 MB / 519 MB / – | 19.1 s; 1789 MB / 519 MB / – | 52.5 s; 845 MB / 519 MB / 14 MB | 82.8 s; 838 MB / 519 MB / 17 MB |
| … A castle, from one sentence (2,497) | 11.1 s; 871 MB / 519 MB / 18 MB | 25.1 s; 1960 MB / 519 MB / – | 21.1 s; 1988 MB / 519 MB / – | 54.8 s; 884 MB / 519 MB / 19 MB | 90.7 s; 835 MB / 519 MB / 19 MB |
| … Wizard's Tower (10,101) | 12.4 s; 873 MB / 519 MB / 19 MB | 29.6 s; 2411 MB / 620 MB / – | 28.1 s; 2384 MB / 620 MB / – | 119.4 s; 860 MB / 519 MB / 18 MB | 129.7 s; 868 MB / 519 MB / 19 MB |
| … Wizard's Tower ×2 (20,202) | – | 38.6 s; 3001 MB / 620 MB / – | 32.7 s; 2916 MB / 720 MB / – | – | – |
| … Wizard's Tower ×3 (30,303) | – | 37.6 s; 2972 MB / 620 MB / – | 40.9 s; 3340 MB / 620 MB / – | – | – |
| … Wizard's Tower ×5 (50,505) | – | 54.7 s; 3067 MB / 722 MB / – | 62.9 s; 2117 MB / 721 MB / – | – | – |
| the walk by finger: acts done | 20 of 23 | 21 of 23 | 21 of 23 | 20 of 23 | 20 of 23 |
| box load at the start | 28 | 71 | 26 | 44 | 113 |

- Memory is each phase's peak. *Pss* is the content process's: Chromium's
  renderer, or WebKit's web process. Wasm is the engine's memory as it
  grew, and the JS heap is Chromium's.
- WebKit's Pss includes its software drawing, which an iPhone does in a
  separate GPU process (below).
- *Engine started* is the window drawn. *Started once its files had come*
  is what a phone's CPU takes after the download.
- The largest-model row of each column is only as far as that column was
  taken. Chromium as a phone went to Wizard's Tower ×5 in the run below.

**The walk by finger.** `tools/web/phonewalk_flow.mjs` does 23 acts of the
studio with taps, drags and the on-screen keyboard only:
- a part to the last step;
- a render;
- a booklet page;
- Like this;
- Check stability;
- Cut away;
- My collection;
- Measure;
- the page editor: opened, an item moved, an item resized, words added,
  Done;
- split and merge;
- a 15° turn;
- a wall of eight bricks from the search;
- painting;
- Motions: kept and played, recorded, a joint's slider;
- Simulate: played, scrubbed, its driver changed.

Two misses were the walk's own, and are fixed in it:

- **Motions** at 390x844 (all three Chromium columns). The motion's row
  sat across the top of its panel's list, and the walk scrolled the list
  the wrong way to bring it in. Fixed, the three Motions acts pass at
  390x844 (`motions-debug/`). The 4x and 6x walks were not re-run for them.
- **Select all on an "iPhone"** (WebKit). The walk cleared the bin's
  search with Control+A, but Godot's web build takes Command for its
  shortcuts when the browser says it is an Apple one. So each search
  typed an "a" in front of the last: *a3020a3001a1x4 brick* found
  nothing, and the turn, the wall and the paint failed. With Command+A
  all three pass.

What is left is the studio's. On WebKit as an iPhone 13 and 15 (390x664
and 393x659), Motions' list is under one row tall: Keep never came wholly
into sight, and the joint's slider followed it out (fault 6).

## As models grow

The gallery stops at Wizard's Tower (10,101 parts). Past that, the measure
put the tower beside itself 2, 3 and 5 times as one model, handed to the
page as a shared model (`phonetruth_flow.mjs --steps=…,beyond`).

| Model | Chromium as a phone: tab (renderer Pss) / Wasm | WebKit as an iPhone 13: WebProcess Pss / Wasm |
|---|---|---|
| 151 to 2,497 parts (5 gallery models) | 0.81–0.89 GB / 519 MB | 1.76–1.96 GB / 519 MB |
| Wizard's Tower, 10,101 | 0.86 GB / 519 MB | 2.41 GB / 620 MB |
| ×2, 20,202 | 1.04 GB / 722 MB | 3.00 GB / 620 MB |
| ×3, 30,303 | 1.31 GB / 822 MB | 2.97 GB / 620 MB |
| ×5, 50,505 | 1.65 GB / 1,023 MB | 3.07 GB / 722 MB |

Every one opened and stayed open: a computer's browser has no phone's
limit to hit, so these are measures of size, not of survival.

**What the numbers say.**
- Up to 10,101 parts a model costs no memory past the studio's own. The
  engine grows its Wasm memory to 519 MB at every start, whatever is
  opened, and the tab sits at 0.8–0.9 GB.
- Past that, Chromium's tab grows about 20 MB for every 1,000 parts:
  0.86 GB at 10,101 and 1.65 GB at 50,505.
- An iPhone's tab is killed at about 1.4–1.5 GB (cited below). At this
  rate it reaches that at about 38,000 parts. At 20,202 it is already past
  70% of it.
- So `phone_parts` is **10,101**: the largest model measured to cost a
  phone nothing past the studio itself. Nothing in the gallery is past it
  today.

**WebKit here draws in software inside its own process** (WPE on llvmpipe).
Its Pss carries the drawing's memory, which an iPhone keeps in a separate
GPU process. So it is an upper bound on what WebKit's own work costs, not
an iPhone's figure.

## The start, phase by phase

webstart11, 2026-11-18. Each phase of a first visit timed on the build's
own marks, never a trace: the engine's files (Resource Timing), the Wasm
compiled and instantiated (timed apart), the engine's own start (its
Build configuration line), then `main.gd`'s boot marks and the car's 61
parts drawn. Two builds at the same moment, each in a browser of its own,
the order alternating (`tools/web/start_phases.mjs`). The box was at load
60–99 of 24 cores throughout, so the seconds are a loaded box's; the
ratios between the two builds are what hold. Results:
`bench/results/webstart11-2026-11-18/`.

**Where a CPU/4 + Fast 4G first visit goes** (Chromium, 5 pairs, the
base's medians):

| Phase | Lasts | Ends at |
|---|---|---|
| The engine's files (9 MB over the wire) | 12.1 s | 12.1 s |
| Wasm compiled, beside the download | 11.0 s | 12.3 s |
| The engine's own start | 5.5 s | 18.2 s |
| **The scripts compiled** | **24.5 s** | 41.2 s |
| The data pack waited for | 1.9 s | 43.1 s |
| **The catalogue read** | **10.0 s** | 54.5 s |
| The window built | 9.3 s | 63.6 s |
| The car laid and drawn | 8.3 s | 72.4 s |

The main thread is busy 48.5 s of it. On WebKit as an iPhone 13 (full
speed, no throttle: WebKit takes none) the scripts take 9.4 s and the
catalogue 2.9 s of a 25 s start.

**What fills the 519 MB of Wasm memory.** A web page's Wasm memory never
shrinks, so whatever the start needs at its height it keeps.
- The engine's own start: 48 MB (34 MB without threads).
- **Compiling the first screen's scripts: to 432 MB.** GDScript holds the
  parse trees of the whole start's script closure at once; on a desktop
  debug build the compile peaks at 520 MB and settles at 203 MB. Every
  engine and build measured reaches 432 MB at the scripts' mark.
- **The catalogue's JSON: the last 87 MB.** Its 14 MB of text is 4 bytes a
  character as a Godot String, and its tree of 29,668 parts' Dictionaries
  rose to +341 MB at its height on a desktop, then kept +198 MB.

**The cut built: the web reads its catalogue from columns.** The export
writes the pack's catalogue as columns (`assets/web/catalogue.bin`: one
packed array a field, 11.5 MB) and reads them back field for field, or
stops (`src/dev/write_all_order.gd`). The web build ships them in the
JSON's place; desktop still reads the JSON. Every field of every part is
the JSON's (`catalogue_columns_probe`). On a desktop the read's height is
+139 MB against +341 MB, in 869 ms against 2,019 ms.

| Same moment, base → after (medians) | Chromium, desktop | Chromium, CPU/4 + Fast 4G | WebKit as an iPhone 13 |
|---|---|---|---|
| Pairs; the box's load | 5; 60–99 | 5; 69–96 | 5; 51–81 |
| The catalogue read | 2.7 → 1.1 s (x0.45) | 10.0 → 3.7 s (x0.37) | 2.2 → 0.8 s (x0.35) |
| First visit, working | 33.9 → 27.2 s (pairs x0.87) | 72.4 → 68.4 s (pairs x0.91) | 18.4 → 18.7 s (pairs x1.02) |
| A return, working | 31.4 → 24.4 s (pairs x0.91) | not run | not run |
| Main thread's CPU to working | 10.6 → 9.1 s | 48.5 → 44.3 s | 11.7 → 10.7 s |
| **Wasm memory at its height** | **519 → 432 MB** | **519 → 432 MB** | **519 → 432 MB** |
| Content process's Pss at working | 817 → 786 MB | 849 → 772 MB | 1,792 → 1,676 MB |

The after build was faster than the base in 5 of 5 desktop pairs, both
visits, and in 4 of 5 at CPU/4. On WebKit the catalogue's 1.4 s is under
the box's noise there: its pairs ran 0.59 to 1.80 of each other, the
slowest from the download on, before the catalogue is read. Its Wasm
memory was 432 MB in every visit on every engine: the script compile now
sets the height, not the catalogue. `phonetruth_flow` on the after build
(CPU/4, load about 50) started the studio in 64.6 s and returned in
47.5 s, and turned the car at 8.3 frames a second, own work p95 37.6 ms
(39.1 ms before).

**The next cuts, in order of seconds:**
1. **The scripts' compile** (24.5 s at CPU/4, and the 432 MB). A smaller
   first-screen closure: the classes the first window names but does not
   use until a press (the assistant, Together, the booklet, the forge)
   loaded on first use, as the Later scripts already are. It is the start's
   largest phase on every engine and the whole of its memory.
2. **The window** (9.3 s at CPU/4): what `_ready` builds that the first
   screen does not show.

**Tried, and not a cut: the Wasm's compiled code kept between visits.** Godot's loader
hands `instantiateStreaming` a Response it made itself, to count the
download, and a desktop return still compiled the Wasm for 5–7 s, so
V8's code cache looked lost. Handing it the fetched Response instead
(the export's `index.js` patched, the progress read off a clone) did
not help: 3 pairs on a desktop, the return's compile 5.4 → 6.1 s,
working slower in all 3 (x1.1;
`bench/results/webstart11-2026-11-18/codecache-desktop/`). Why V8 kept
nothing is not found; until it is, this is not a cut.

### What the first screen compiles and never runs (webstart12)

webstart12, 2026-11-19. The assistant, Together, the booklet's maker and
the forge were already loaded on first use (`src/later.gd`); what is left
is read here function by function. `src/dev/start_uses.gd` boots the app
as a first visit does under Godot's script profiler (`-d --profiling`),
lets the window settle with nobody touching it, and prints every function
that ran; `tools/web/start_uses.py` sets that against the first screen
(`tools/web/start_closure.py`), counted in tokens, not bytes: this code's
comments are a third of its bytes and cost no compile.

- **The first screen: 214 scripts, 1,032k tokens. 77% of them ran before
  a press** (791k), in a phone's window and in a desktop's alike. 71
  scripts never ran: 240k tokens, 23%.
- What never ran, largest first, each with its share of the scripts'
  24.5 s at CPU/4 and of the 384 MB they grow the Wasm memory by
  (apportioned by tokens): Grab 33k (0.8 s, 12 MB; the first drag);
  Instructions 30k (0.7 s, 11 MB; named by 11 scripts of the first
  screen); MinifigData 25k (0.6 s, 9 MB; a table read by the figures);
  AuthorSteps 11k; PartPrints 9k; the sign-in screen 6.5k (a signed-out
  visit's first screen); BookletStudio 6k; TogetherWords, Bands,
  ModelFilePicker, SeenParts, BuildSteps, Swing and SubmodelFile 5k each;
  the rest under 4.5k.
- **So no deferral alone meets the bar.** Every script that never ran,
  deferred, takes 23% off: the scripts' phase about 24.5 → 19 s, not 12.
  The phase is the compile of code the start runs.
- **The memory is set by the largest compile, not the total.** Godot
  holds the parse of every script one load compiles until that load ends,
  and 124 of the 214 name each other in one cycle (804k tokens, 78%). On
  this box's desktop build the first screen's compile peaks at 591 MB and
  keeps 223; loaded a cycle at a time, the cycles that name nothing back
  first (`src/dev/start_cost.gd --pre=`), it peaks at 502 MB in the same
  time. A script already compiled costs a later load next to nothing (four
  of the largest named by a new script: 58 ms), so a cycle compiled first
  is not parsed again.

What was done with it, and what it gave, in 3 pairs a config at the same
moment against pre261 286529440 (`bench/results/webstart12-2026-11-19/`,
load 50 to 109):

| | WebKit as an iPhone 13 | Chromium, CPU/4, Fast 4G | Chromium desktop |
|---|---|---|---|
| Wasm at its height | 432 → 360 MB | 432 → 360 MB | 432 → 360 MB |
| scripts' phase | 7.4 → 6.4 s (x0.87) | 22.5 → 25.5 s (x1.13) | 6.2 → 7.1 s (x1.11) |
| working | 19.4 → 17.3 s | 57.1 → 59.2 s | 24.2 → 25.3 s |
| main thread's CPU to working | 11.5 → 12.2 s | 46.6 → 48.9 s | 9.0 → 9.7 s |

- **The first screen compiled a cycle at a time** (`BrickworksLoop`
  loads `assets/web/first_order.txt`, which the web export writes from
  `tools/web/start_closure.py --order`, before the engine loads
  main.tscn): 79 loads, the largest the 124-script cycle. It costs CPU
  everywhere, 5 to 8% of the main thread's: each load parses again the
  scripts it names that an earlier one compiled. WebKit still started
  sooner, its memory grown less; Chromium started later. So **only an
  iPhone or iPad compiles so** (the shell's own test of one), where the
  memory is what is short, and every other browser as before.
- **The figure rules' tables (MinifigData, 25k tokens) load on first
  use** through `Later`, read by `Minifig.table(name)`.
- **Not met: 300 MB, and 12 s at CPU/4.** What is left is the cycle
  itself: 124 scripts that name each other compile as one whatever is
  asked first, 78% of the first screen. Under 300 needs that cycle cut,
  class by class, so that its parts compile apart: the Next.

### Where live's 432 MB comes from, and a return's seconds (webstart13)

webstart13, 2026-11-22. webstart12 read 360 MB and live reads 432: both
are right. `tools/web/start_phases.mjs` now keeps every growth of the
heap the page's own thread asks for (the size asked, the size before and
after) and holds each visit 30 s past working (`--hold=30`). Live (m318),
3 visits a config at load 109 to 126
(`bench/results/webstart13-2026-11-20/live/`):

- **WebKit as an iPhone 13: layered compile is on** (the page took it for
  an iPhone; the threaded engine, the switch off). Every growth its own
  thread asked for was 300 MB or under, so the Wasm memory stood at 360 at
  the scripts', the catalogue's and working's marks in 2 visits of 3. In
  all 3 it was 432 within 30 s of working: 5 to 6 s after the window was
  built, from a thread that is not the page's (a worker's growth is its
  own copy of the import, unseen here). webstart12 read at working only.
- **Chromium as a phone: the compile itself reaches 432**: the page's own
  thread asked for 360 MB at the scripts' mark (no layered compile off
  Apple, webstart12's choice).
- **Where an iPhone's start goes**, median of 3, s: first visit 23.8 (the
  engine's files 7.9, wasm compiled 4.6, engine 0.7, scripts 6.2, the data
  pack 2.4, catalogue 0.7, window 1.2, first part 0.7, to working 4.7); a
  return 19.5 (files 3.3, wasm 0.5, engine 0.7, scripts 6.5, data 1.0,
  catalogue 0.7, window 1.5, first part 1.0, to working 5.1). The engine's
  wasm was asked for only once the switch answered (op=phone), at 1.6 s on
  a return as on a first visit. The main thread's own CPU to working is
  12.0 to 12.8 s of it: the bar's 8 s is under the page's own work.

What was done with it (measured at the same moments against live in
`bench/results/webstart13-2026-11-20/proofs-<sha>/`, queued behind a
release when written):

- **The search's index waits for the start** (`PartLibrary.
  search_ahead_held`, let go of by `Main._search_ahead_after_start` once
  the start's model is laid and every part of it is here, 20 s at most):
  it was the start's one worker task over the whole catalogue, begun as
  the bin first fills, and ran beside the model's last seconds. A key typed
  meanwhile has it made at once, as before (`searchahead_probe`).
- **A return starts the engine at once on an iPhone or iPad that last
  heard the switch off** (`brickworks.phoneEngine` in localStorage, the
  shell's `brickworksEngine`): the question is still asked and its answer
  kept, so the switch turned on reaches such a device a visit late; one
  that last heard on waits for the answer, so off reaches it at once.

**Not met, and why**: an iPhone's return at 8 s and Chromium's at 6 need
the scripts' 6.5 s and the 5 s from the window to working cut, which is the
124-script cycle (above) and the model's laying, not the start's order;
300 MB is the same cycle's compile (300 to 360 at its height on an iPhone,
over 360 on Chromium).

### Start building, and what the timer could not see (webstart14)

webstart14, 2026-11-27 (`bench/results/webstart14-2026-11-27/FINDINGS.txt`,
every phase before and after).

- **webstart13's proof was a stale page.** `place_build.py` pointed
  `index.html` at `/e/<hash>/` and `/b/<sha>/` and left export.sh's
  `index.html.br` of the page before it; `serve.py --compressed` sent that
  to Chromium (which takes brotli from 127.0.0.1; WebKit does not), so every
  Chromium visit asked for an `index.js` that was not there: "Engine is not
  defined". The stale copies now go (`tests/test_place_build.py`).
- **No timed Chromium return read its cache.** The parts mirror's routes
  (`page_routes.mjs`) turned each page's HTTP cache off, as Playwright's
  do, so every return fetched the engine and its pack again (CDP
  `fromDiskCache` false), 5 s of a desktop return at 20 Mbps that no
  visitor's return pays. `start_phases` now launches with `keepCache`.
- **Start building finds the engine here.** The home page prefetches the
  engine and its pack on intent, on a computer's connection
  (`web/landing.js` `studioAhead`): 9.7 MB, the 5 s a desktop first visit
  spent on the files. Intent is a member signed in (at idle after the
  load), or the pointer within 200 px of a link into the studio, its focus
  or a press, or the hero band scrolled past. Every visit at idle cost the site 9.7 MB per visitor who
  never pressed Start. Not on a phone's width, a cellular, slow or
  Save-Data connection, nor an iPhone or iPad.
- **Not the car's parts.** Asked for as soon as the catalogue is read,
  they were read in the open and the time from the first part to working
  did not shrink: tried and taken out.
- **webstart13's held search index held the current-mould index too.**
  The search index's worker made the index `PartLibrary.current` reads
  first; held, the start's open made it on the page's thread, 0.9 to 2.6 s
  of its "known" phase against live's 0.02. It is made on a worker while
  the search's waits (`_current_ahead`, `searchahead_probe`).

**What is left** is the page's own work, which no ordering of the start
moves: the first screen's GDScript compile (4.3 s on a desktop, 4.6 on a
phone, 6.5 on an iPhone, every visit, the 124-script cycle above), the
engine's own start (0.6 to 1.3), the catalogue and the window (2 to 2.5),
and 1.6 to 3.2 s from the first part to the car drawn, two frames of which
one is 1 to 2 s of drawing in software.

## The no-threads export on WebKit

`Web (no threads)` (`build/web-nothreads`, unshared memory) against the
threaded build, both base, at the same moments:

| | Threads | No threads |
|---|---|---|
| WebKit as an iPhone 13, working (4 pairs, load 73–98) | 25.2 s | **17.7 s** (x0.70; faster in 3 of 4) |
| … the scripts' compile | 9.4 s | 5.0 s |
| … all threads' CPU to working | 27.5 s | 22.2 s |
| … WebProcess Pss at working | 1,779 MB | 1,613 MB |
| Chromium, CPU/4 + Fast 4G, working (3 pairs, load 60–77) | 65.6 s | 64.9 s (x1.00) |
| … renderer Pss at working | 853 MB | 791 MB |
| Wasm memory at its height, both engines | 519 MB | 519 MB |
| Together, two browsers (`together_flow --desktop=no`, about load 100) | 42 checks passed before its 45 minutes ran out; pointer late, Follow and the outline failed | 71 passed, 5 failed: a change's and the pointer's time, Follow (2), the outline |
| WebKit's walk: render, a booklet page, Simulate played, scrubbed, driven | done (phonetruth's walk) | done, 5 of 5; Motions' Keep fails on both (fault 6) |

**My judgement: serve it to iPhones, behind the owner's switch, once one
real iPhone agrees. Android keeps threads.**
- On WebKit it started in 0.70 of the time, the scripts' compile almost
  halved, and its process held 166 MB less. On Chromium it was no faster
  (x1.00): there threads cost nothing and help the work after the start.
- It does what the threaded build does: Together's edits, undo, comments,
  reload and the session in 71 checks; render, the booklet and Simulate by
  finger on WebKit. Its failures in Together are the threaded build's at
  the same load (the timing bars, Follow, the outline), so they are this
  box's, not its own.
- What it costs is the workers. With no threads the engine runs each
  pool task in the frame that asks for it: weighing a model past 600
  parts, the booklet's pictures and PDF, the search's index. Such a frame
  is the whole task long. The app allows for it in three places already
  (custom_parts, builder, booklet_studio); the rest would need the same.
- Its Wasm memory reaches the same height (519 MB, 432 MB with the
  columns). What it changes on iOS is the shared memory's 2 GB maximum,
  reserved up front, which an iPhone has refused (godot#70621). Only a real
  iPhone can say how often that happens, so the switch waits on one.
- **The switch is built** (nothreads, 2026-11-19): below.

### The switch: iPhones and iPads on the engine without threads

`/admin#switches` › Phones › "iPhones and iPads use the engine without
threads" (`phone_nothreads`, default **off**; `POST /api/admin?op=phone_engine
{on}`, audited, this deployment's scope only). Every page reads it at
`/api/plans?op=phone`, a minute at the CDN.

- **Built and deployed both.** `tools/export.sh web` exports `Web (no
  threads)` into `build/web-nothreads` after the threaded one and stops if
  any of its 8 packs (pck, data, parts, primitives, light, type, the two
  audio worklets) is not the threaded export's byte for byte. tools/deploy.sh
  hands it to tools/web/place_build.py, which copies only its engine
  (`index.js`, `index.wasm`, their brotli, its worklets: 6 files, 6.6 MB
  over the wire) to its own `/e/<hash>/` and names it in the page's
  `GODOT_CONFIG.nothreads`; it refuses one whose packs or page differ but
  for the engine's settings. The deployment says its file count and is
  refused past 15,000.
- **Chosen on the page.** The page names both engines and asks for neither
  in its markup (src/boot/shell.html, `brickworksEngine`): iOS and iPadOS
  (an iPhone, iPad or iPod user agent, or a Mac's with
  `navigator.maxTouchPoints` over 1, as an iPad's Safari says it is) ask
  `op=phone` first and start the engine without threads while the switch is
  on, the threaded one while it is off, unanswered or past 2.5 s. Every
  other browser starts the threaded one at once, asking nothing.
- **What off costs.** An iPhone's first visit asks `op=phone` as it did
  (the first-visit time, `#eta`, takes the same answer: one question). An
  iPad, and an iPhone coming back, ask it once more than before: a few
  hundred bytes, cached a minute at the CDN, waited for before the engine.
  Everyone else's requests are base's.

Measured on local copies of one export placed as a deployment is
(tools/web/serve.py `--phone-nothreads on|off`), WebKit and Chromium in
software on this box (results: `bench/results/nothreads-2026-11-19/`):

| | |
|---|---|
| Switch off, each browser's requests against base's page (`engine_choice.mjs --base`) | iPhone 20 and 20, the same; Mac Safari, the same; iPad and iPad-as-Mac one more (`op=phone`) |
| Switch on: the engine started | iPhone, iPad, iPad as a Mac: without threads, nothing of the threaded one asked; Mac Safari, Android Chromium, a computer: threaded |
| WebKit as an iPhone 13, working, switch on against off (4 same-moment pairs, load 40–53) | **14.8 s against 17.9** (x0.84; faster in 4 of 4); scripts' compile 5.6 against 7.5 s; 105 MB less held |

What a pool task costs without threads, each frame's own work, in WebKit
(`cad_frames.mjs --engine=webkit` on the export without threads, at load
30–40):

| Pool task | Without threads | Under 100 ms? |
|---|---|---|
| The search's index, the first part number typed | made in frames already (PartLibrary.index_on_a_worker); the app's scripts 24 ms at most | yes |
| Weighing a model past 600 parts (Main.weigh_joints, Stability.check_paced) | one frame the whole weigh: 1.7 s on 75969-1 (925 parts), **8.6 s on Orthanc (10,101)**, and again after every edit | **no** |
| The booklet's pictures | in frames already (BookletStudio) | see the walk |
| The booklet's PDF on the web | never a pool task: written in the page's own frames with or without threads (Main, BookletRead) | the same as with threads |

**So the switch stays off until the weigh is paced.** With threads the
status bar weighs a model past 600 parts on a worker; without, it weighs it
in the frame, and an iPhone holding Orthanc would stop for seconds at every
edit. It needs the weigh in frames (or the status bar's verdict asked for,
not made at every edit, past 600 parts without threads): a unit of its own.
The rest of the pool tasks found by grep (grab_drag, parts_bin, model_store,
strengthen, tested, the rest) run where they ask too; the walk below drives
the ones a phone reaches.


## The faults, each with its cause and fix

In order of how many people they reach.

1. **The start is the phone's CPU, not its network.**
   - *Measured.* At a quarter of this box's speed on Fast 4G, the engine's
     files took 10.2 s and the studio started 42.0 s after that: 58.4 s in
     all. A return, with every file cached, still took 42.8 s. At a sixth
     the start took 73.6 s after the files (the box was at load 113 then).
     On WebKit as an iPhone, at full speed, the boot marks were:
     - compiled at 7.3 s;
     - the catalogue at 9.0 s;
     - the window at 10.1 s;
     - the car laid at 10.3 s.
   - *Cause.* Everything after the download runs at the phone's speed:
     compiling and instantiating the 39 MB `index.wasm`, reading the parts
     catalogue, and building the window. The download is 9–10 MB.
   - *Fix.* Cut the start itself (webstart11, phones first). First time
     each phase on a throttled phone, then: a smaller Wasm, the catalogue
     read on first use, and the compiled module kept between visits.
     **Built here:** a phone's first visit says how long it will take.
     **webstart11** timed each phase (above): the scripts' compile is the
     largest on every engine, then the catalogue, which now reads x0.37.

2. **The studio's memory before any model.**
   - *Measured.* The engine grows its Wasm memory to 519 MB at every start,
     on every engine. Chromium's tab is then at 0.8 GB; WebKit's process,
     with its software drawing, at 1.75 GB.
   - *Cause.* The threaded build asks for a shared memory: 32 MB to start,
     2 GB at most. Whatever the engine loads at start fills it to 519 MB.
     On iOS, Wasm memory and SharedArrayBuffers share one 2 GB cage, and
     "only ~300 MB" is reliably available (WebKit 269937). A 2 GB shared
     maximum has been refused outright on an iPhone (godot#70621).
   - *Fix.* Find what fills 519 MB and keep it out of the start. Measure the
     no-threads export (`Web (no threads)`, unshared memory, Godot's
     default since 4.3 for Apple's sake) on a real iPhone, and serve it to
     iOS if it holds. **Built here:** a refused memory is said plainly with
     what to do, and the files still coming are let go. Before, the loader
     sat at "Sorting the bin…" for ever: the refusal is thrown outside the
     start's promise, and nothing heard it.
     **webstart11:** the catalogue's 87 MB kept out of it (519 → 432 MB on
     every engine), and the no-threads export judged on WebKit (above).
     The 432 MB left is the scripts' compile.

3. **A model past 10,101 parts grows the tab about 20 MB per 1,000 parts**
   (above). **Built here:** the question before it opens on a phone.

4. **Frames on a slow phone.**
   - *Measured.* The app's own work per frame, turning by two fingers, at
     p95:

     | Speed | The car (61 parts) | Orthanc (10,101) |
     |---|---|---|
     | Full speed | 13.1 ms | 17.1 ms |
     | 4x slower | 39.1 ms | 57.9 ms |
     | 6x slower | 196 ms | 188 ms |

     The 6x run was at load 113.
   - *Cause.* Each frame's own work, at the phone's speed. DevTools does
     not slow the GPU process, so the drawing's cost is a computer's here.
   - *Fix.* A later unit: what the app does each frame when nothing moves.
     The studio stays usable at 4x; at 6x, turning is a slide show.

5. **No WebGL 2: the whole download, then Godot's words.**
   - *Cause.* Godot's web export draws only with WebGL 2. The loader named
     the missing feature only after the 15 MB download, in Godot's words,
     with advice to the server.
   - **Fixed here.** It is said at once in plain words, with what to do,
     and the engine's files are let go: 2.6–5.6 MB had come, then nothing.
     The model pages' 3D view had also accepted WebGL 1, which three.js
     0.186 cannot draw with. It now asks for WebGL 2 alone.

6. **Motions on a short phone.**
   - *Measured.* WebKit as an iPhone 13 has 390x664 of page once Safari's
     bars are drawn, and as an iPhone 15, 393x659. There Motions' list showed less than one row between
     its title and its foot: Keep was never wholly in sight, so the walk
     could not keep the suggested motion, nor set a joint by its slider.
     At 390x844 all three Motions acts pass.
   - *Cause.* At the top of the page sit the moved-parts strip ("16 parts
     have new numbers in the LDraw library", about 75 px, on any model
     whose parts the LDraw library renumbered) and the assistant's bar
     (about 45 px). The panel's own title, Render animation row and status
     line stand still around the list. What is left for the list is about
     50 px.
   - *Fix* (the studio's UI, outside this unit):
     - on a phone, fold the moved-parts strip to one line, or put it under
       More;
     - let Motions' foot (Render animation and the status) scroll with its
       list;
     - give a panel the height the view gives up, as the parts sheet does.

## The warnings built

Each warning states a fact and what to do. None of them stops anyone.
Each fires only in its own case. `tools/web/phonewarn_flow.mjs` proves
that on a phone (390x844 and 430x932), a tablet (820x1180, touch) and a
computer (1280x800). It runs as the `phonewarn` check on every preview.

| Warning | When it fires | Where | Never fires for |
|---|---|---|---|
| "This browser can't draw the studio in 3D: it has no WebGL 2…" | `Engine.getMissingFeatures` names WebGL 2 | the loader (`src/boot/shell.html`), at once; the engine's files are let go | a browser with WebGL 2, whatever else it lacks |
| "First visit on this phone: about N s to go. Later visits start sooner." | a phone (touch only, no fine pointer, short side under 600 px) that has not started this engine before | the loader, under the bar; counts down from the download's rate plus `phone_start_s` | a tablet, a computer, a phone returning to the same engine |
| "About N parts: on a phone this may close the tab…" with Not now / Open it anyway | a phone pressing a way into the studio (`/app?view=`, `?copy=`, `?library=`) from a model's or a set's page, when the model has more than `phone_parts` | the page, as a dialog (`web/phone-warn.js`) | a tablet, a computer, a model at or under the number, a press with a key held (a new tab) |
| "This browser would not give the studio the memory it needs (…)…" | the engine's `WebAssembly.Memory` is refused (Safari's "Out of memory", Chromium's "could not allocate memory") before it starts | the loader; the time to wait stops and the files still coming are let go | any other start failure, which keeps its own words |

**The owner's numbers.** `/admin#switches` → **Phones**:
- `phone_parts`: the parts past which a phone is asked. Measured default
  10,101.
- `phone_start_s`: the seconds a phone takes to start once the files are
  in. Measured default 40.

*Keep them* saves both, for the deployment the console is on
(brickworks.diy, or a preview's own). A number outside its range (50 to
100,000 parts, 1 to 600 s) is refused with words. Each save is audited,
and the console shows who set each number and when, beside its measured
default. Pages read the
numbers from `GET /api/plans?op=phone`, with the defaults used until it
answers. A press made before the answer waits up to 2 s for it, so it is
not judged by the default.

Every line is in English, German, French and Spanish.

## A mobile version, or one adaptive studio

**My judgement: one adaptive studio. No separate mobile app or mobile mode
now.**

**What a phone lacks is not the layout.**
- The phone layout already does the walk by finger: all 23 acts at
  390x844, none of them on a control under 44 points, and 21 on WebKit's
  iPhone 13 and 15 screens (390x664, 393x659), where one panel (Motions) is
  too short.
- The panels fold, the bin and the drawer sit under a thumb, Measure and the
  move handles take a finger, and the page editor works by touch. All of
  that was built (phonewalk, phonepanels, fingertools) and is checked on
  every release (`phone`, `tablet`).

**What a phone lacks is the engine's start and memory.** A "mobile mode"
on the same Godot web engine would carry both unchanged:
- The same 39 MB Wasm to compile.
- The same catalogue to read.
- The same 519 MB of Wasm memory at start.
- The same 2 GB shared maximum, which iOS may refuse.

A lighter UI would save a little drawing per frame. It would not touch
the start, which is where a phone loses 40–75 s.

**A native app is the only "version" that changes those limits.** Godot
exports to iOS and Android with no browser around it: no Wasm, no 2 GB
cage, and threads with no COOP/COEP. It costs:
- two store listings and their reviews;
- a signing pipeline per platform;
- a second release lane;
- a 1.4 GB tab limit traded for an app's own, which on iOS is still set by
  jetsam.

Desktop downloads are paused today. A phone app is the same kind of work
with stricter stores. It is worth it only if real phones say the web
start cannot be brought under about 20 s, and nothing measured here says
that yet.

**What to do instead, in order:**
1. **webstart11**: the start, phones first. Time each phase at 4x with
   no throttled network, then cut the biggest. Phones are where the
   start costs most and where it is felt.
2. **A memory unit**: what fills the 519 MB at start, and the no-threads
   web export measured against the threaded one on WebKit and a real
   iPhone (start, frames, memory). If it holds, serve iOS that build.
   That ends the shared-memory refusal and the 2 GB cage.
3. **A short phone's panels** (fault 6): the moved-parts strip folded on
   a phone, and Motions' foot scrolling with its list.
4. **Real phones**: one Android at about $200 and one iPhone 13-class,
   driven over remote debugging. They replace this document's stand-ins
   and set `phone_parts` and `phone_start_s` from what they measure.
   The console takes the new numbers with no deploy.

## What this measure cannot say

- **Playwright's WebKit is not iOS Safari.**
  - It is WPE WebKit on Linux, drawing in software (llvmpipe) inside its
    own web process.
  - It has no jetsam, so nothing is ever killed for memory, and no
    Gigacage limit as an iPhone sets it.
  - Its frames are the CPU's drawing, not an Apple GPU's.
  - Its runs had Playwright's request routing on: the towers the measure
    hands the page, and the tests' parts mirror. Routing turns the HTTP
    cache off ([Playwright](https://playwright.dev/docs/api/class-page#page-route)),
    so WebKit sent every request with `Cache-Control: no-cache`, the head's
    preload among them. The preload was not reused, and the engine's
    6.9 MB Wasm and 2.4 MB pack came twice: 19 MB over the wire where
    Chromium took 9 MB. A return fetched everything again, so WebKit's
    returns are no faster than its first visits. Neither is Safari's, which
    caches as Chromium does.
  - What it proves: the page, the loader, the engine and the studio run on
    WebKit's JavaScript and Wasm, with WebKit's COOP/COEP and
    SharedArrayBuffer, at an iPhone's screen size and touch. What it
    cannot prove: that an iPhone keeps the tab.
- **Chromium's CPU throttle is a stand-in for a slow phone's CPU.**
  - It slows the page's own work. The GPU process is not slowed, so the
    drawing's cost is still a computer's (cited below).
  - Lighthouse calibrates 4x on a high-end desktop as a mid-tier phone,
    and suggests 10x for a low-end one. This box is a Ryzen 9 5900X
    (12 cores, 24 threads), so 4x stands for a mid-tier phone and 6x for
    one below it. A low-end phone is slower still.
- **The box was loaded** (load 28 to 125 on 24 cores) by other work while
  this ran. The load at each run's start is in the table. Throttled
  timings at a higher load are slower than a quiet phone's. Compare runs
  only at a similar load.
- **A link pasted straight into the studio** (`/app?view=…`) is not
  warned: the warning is on the model's page, where the count is known
  before the studio is fetched. The studio itself could ask once it has
  the model, but by then a phone has paid the start.
- **A phone's own memory warning** (iOS's didReceiveMemoryWarning, Android's
  onTrimMemory) never reaches a web page. A tab that is killed reloads, and
  the page cannot tell why.


## What the platforms allow, cited

**WebGL 2.**
- Godot 4's web export draws only with WebGL 2, through the Compatibility
  renderer, and has no WebGL 1 path
  ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)).
  The same page warns that "Safari has several issues with WebGL 2.0
  support".
- Safari has had WebGL 2 since Safari 15 on iOS 15, drawn on Metal through
  ANGLE ([WebKit](https://webkit.org/blog/11989/new-webkit-features-in-safari-15/)).
  Chrome for Android has had it since 58
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebGL2RenderingContext)).
- Chromium's GPU blocklist turns WebGL off on one class of Android GPU:
  those with no separate GPU process and no reset notification
  ([software_rendering_list.json](https://chromium.googlesource.com/chromium/src/+/main/gpu/config/software_rendering_list.json)).
- The model pages' 3D view uses three.js 0.186, which since r163 also
  draws only with WebGL 2. Its check accepted WebGL 1 until this unit.

**Memory per tab.**
- On an iPhone, a tab's WebContent process has a soft limit of "around
  1.5GB". Above it the process is "subject to getting killed by jetsam",
  and the limit is lower on iPhones with less RAM. One reporter measured
  about 1.5 GB on an iPhone 12 Pro and about 3 GB on a 15 Pro
  ([WebKit 277848](https://bugs.webkit.org/show_bug.cgi?id=277848)).
- WebKit's Gigacage held 2 GB of such allocations on iOS. An 8 GB iPad gave
  a page only 1.88 GB
  ([WebKit 268816](https://bugs.webkit.org/show_bug.cgi?id=268816)).
- Wasm memory and SharedArrayBuffers share that cage. A duplicate bug is
  titled "Only ~300 MB of RAM is reliably available to WebAssembly pages"
  ([WebKit 269937](https://bugs.webkit.org/show_bug.cgi?id=269937)).
- In Safari, `memory.grow()` does not fail. The tab is killed and
  reopened instead, and "too much memory is decided based on system
  pressure not a fixed limit"
  ([WebKit 221530](https://bugs.webkit.org/show_bug.cgi?id=221530)).
- The "A problem repeatedly occurred" reload is jetsam's
  `per_process_limit`. It has been seen past 1.4 GB in a Wasm app on an
  iPhone 13 Pro ([WebKit 256703](https://bugs.webkit.org/show_bug.cgi?id=256703)).
- Godot #70621: on iOS 16.2, a `WebAssembly.Memory` with a 2048 MB maximum
  failed as out of memory, and a 256 MB maximum worked
  ([godot#70621](https://github.com/godotengine/godot/issues/70621)).
  Brickworks' threaded build asks for exactly that: shared, 32 MB to start,
  2048 MB at most (build/web/index.js).
- Chrome on Android kills background tabs aggressively, losing their state
  ([Chrome](https://developer.chrome.com/blog/tab-discarding/)). No
  official per-tab figure for Android is published.

**Threads.**
- Safari 15.2 (iOS 15.2) added COOP and COEP and turned SharedArrayBuffer
  back on for cross-origin isolated pages
  ([WebKit](https://webkit.org/blog/12140/new-webkit-features-in-safari-15-2/)).
  Android Chrome 88 requires the same isolation
  ([Chrome](https://developer.chrome.com/blog/enabling-shared-array-buffer)).
- Godot 4.3 added a single-threaded web export and made it the default.
  Among its reasons, the long-standing problems on Apple devices "fortunately
  disappear" without threads
  ([Godot](https://godotengine.org/article/progress-report-web-export-in-4-3/)).
  The 4.7 docs say threads "always had compatibility issues" on iOS.
- Brickworks has a no-threads preset (`Web (no threads)`,
  build/web-nothreads), but only the threaded build is deployed.
- Emscripten notes that threads together with memory growth make
  JavaScript's reads of Wasm memory slow
  ([Emscripten](https://emscripten.org/docs/porting/pthreads.html)).

**Sound.**
- An AudioContext must be made or resumed inside a user gesture
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices);
  [WebKit 180522](https://bugs.webkit.org/show_bug.cgi?id=180522)).
- iOS suspends it when the page goes to the background
  ([WebKit 231105](https://bugs.webkit.org/show_bug.cgi?id=231105)).
- Godot resumes it on every key, mouse, touch and IME event
  ([display_server_web.cpp](https://github.com/godotengine/godot/blob/master/platform/web/display_server_web.cpp)).

**The soft keyboard.**
- Since Chrome 108, Android Chrome resizes only the visual viewport when
  the keyboard opens, as Safari on iOS does
  ([Chrome](https://developer.chrome.com/blog/viewport-resize-behavior)).
  `visualViewport` exists in both
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/VisualViewport)).
- Godot's `html/experimental_virtual_keyboard` uses a hidden input. It
  never reads `visualViewport`
  ([library_godot_display.js](https://github.com/godotengine/godot/blob/master/platform/web/js/libs/library_godot_display.js)).
  The studio lifts its own dialogs above the keyboard (dialogs_430,
  field_drag).

**In the background.**
- A hidden tab's requestAnimationFrame is paused
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame)).
  Chrome holds its timers to once a second, then once a minute after five
  minutes ([Chrome](https://developer.chrome.com/blog/timer-throttling-in-chrome-88)).
- On iOS, "tabs are completely suspended when possible"
  ([WebKit](https://webkit.org/blog/8970/how-web-content-can-affect-power-usage/)).
  Low Power Mode caps requestAnimationFrame at 30 frames a second
  ([WebKit 215745](https://bugs.webkit.org/show_bug.cgi?id=215745)).
- A frozen Android page runs nothing, and a discarded one starts again
  ([Chrome](https://developer.chrome.com/docs/web-platform/page-lifecycle-api)).
  The studio keeps every edit in IndexedDB as it is made, so a reload
  reopens the work (docs/APP_UX8.md, the connector with the tab hidden).

**How honest the stand-ins are.**
- A 4x CPU throttle is Lighthouse's calibration of a high-end desktop down
  to a mid-tier phone (a Moto G4). Its table suggests 10x for a low-end
  phone ([Lighthouse](https://github.com/GoogleChrome/lighthouse/blob/main/docs/throttling.md)).
- DevTools calls throttling "a first-order approximation"
  ([DevTools](https://developer.chrome.com/docs/devtools/device-mode)).
  Its CPU throttling "doesn't touch the GPU process"
  ([DevTools](https://developer.chrome.com/blog/devtools-grounded-real-world)).
- Fast 4G is 9 Mbps down × 0.9, 1.5 Mbps up × 0.9, and 60 ms × 2.75 =
  165 ms a request
  ([NetworkManager.ts](https://github.com/ChromeDevTools/devtools-frontend/blob/main/front_end/core/sdk/NetworkManager.ts)).
- Playwright's WebKit is WebKit's main branch with patches, not Safari. On
  Linux it is WPE's MiniBrowser
  ([Playwright](https://playwright.dev/docs/browsers)). It shares
  JavaScriptCore and WebKit's layout with iOS Safari. It has none of
  iOS's jetsam limits or Gigacage size, and none of its Metal path:
  here it draws on Mesa's llvmpipe. So it tells what WebKit runs and how,
  never whether an iPhone keeps the tab.
