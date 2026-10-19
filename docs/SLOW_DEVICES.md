# Slow devices

On a weak device a frame of Brickworks takes 0.3 to 3 s. Chromium drawing in
software (SwiftShader) is what the release checks use for one. The app's own
work in such a frame is a few milliseconds. So the lever is what a frame
draws.

`FrameBudget` (`src/render/frame_budget.gd`) times the frames the app draws.
Where they are slow, it draws less. Where they are quick, it changes nothing
and writes nothing to the renderer. There are no new controls.

## How the app decides

- It times each drawn frame that follows a drawn frame: the time from the
  end of one drawing to the end of the next, less that frame's own work
  (from process_frame to frame_pre_draw).
- Two seconds after the window is up, it draws frames on purpose until ten
  are timed (a write of what the renderer already has wakes a frame). It
  skips two warm frames, then keeps timing every frame it draws anyway.
- It judges by the second fastest of the last six frames, so a quick
  device's rare long frames (a shader compiled, a model read in) never
  count. Over SLOW_MS (50 ms), it cuts the next rung. At 4x over it cuts
  two, at 16x three. Then it looks again.
- **In a browser it also waits for the drawing.** A browser hands each
  frame to its GPU process and goes on; the frame is drawn there later. In
  software, a dozen frames were handed over at the display's 17 ms each
  while SwiftShader took 0.3 to 3 s to draw each one. So on the web a look
  ends with a fence after its frames (`GpuFence`), and when it passes, the
  look is judged again by the time from its start, less its frames' own
  work, a frame. On the desktop there is no fence.
- It only lowers the look, never raises it within a session. Probes leave it
  off unless they call `watch()`, as IdleDraw does. It is also off when
  headless.
- The ladder, in order (why, below): ssao (Forward+ only), dense (the 3D at
  one pixel to the point on a screen over 1.25x), msaa (edges one sample
  deep), scale (the 3D at half a pixel to the point), shadow (the sun casts
  none, lit at `BrickWorld.light_energy(…, false)`), glow.

## Two things that made the first numbers wrong

**The 26 -> 719 ms jump was the page, not the cut.** The first round timed
frames by when the page handed them over. On rel-m87, with nothing cut and
no FrameBudget, the first turn of the view in the empty editor read 37 to
49 ms a frame and the next ones 270 to 700 ms. One look on this branch drew
four frames at 12 to 25 ms and then six at 382 to 864 ms, nothing changed in
between. Timed instead up to a WebGL fence after each turn (the page puts
one in and waits until the GPU process has passed it), the page's gaps were
17 to 33 ms in every turn while each frame took 336 to 1,903 ms to draw, and
SwiftShader finished a turn 4 to 27 s after the page had moved on. "none"
was measured first, while the GPU process still had room, and "msaa" second,
paying for its own frames and for none's. Measured with fences and "none"
between cuts, msaa off costs 0.6 to 0.8 of the "none" either side, not 27
times more.

**look_cost hung because a look counted frames drawn, not frames timed.**
Only a frame drawn right after a drawn frame is timed, and `GpuFence` holds
the drawing while the parts bin's pictures are read back. Recorded frame by
frame (`window.lookFrames` with each engine frame's WebGL calls), one look
of ten drew only four frames in 4.6 s, each apart from the last; the hung
run's look ended with `timed: [23, 31.2]`, and the check waited for a third
that nothing would draw. Now a look counts the frames it timed, and ends
after drawing three times as many as it meant to. The check waits for the
look to end, not for a count.

Also found and fixed in the check: a turn that ended 10 px below where it
began tilted the view over the model in a run's 17 turns, and "none" fell
from 1,004 to 126 ms a frame at a steady load. Each turn now presses at the
middle and comes back to it. And each cut is drawn once before any is
measured: the first frames with a look SwiftShader has not drawn before
build its programs.

## What each rung buys

Measured with `tools/web/look_cost.mjs --mode=cuts` on local exports of
this branch (before the order and the fence below; each cut is pinned, so
its cost does not depend on them) and of rel-m87, in Chromium on
SwiftShader, at the laptop size (1280 x 800 at 1x) and the phone size (390
x 844 at 3x), in the empty editor, the editor with 6392-1 (500 parts) and
8808-1 in the shared viewer. Three chains ran side by side, one heavy slot
each, each A B A B: rel-m87, this branch, rel-m87, this branch. Load 20 to
73 on 24 cores; a release was shipping and other agents were running.

Each cut's frame against the "none" just before and after it in the same
page, round 1 / round 2 (1.00 is no saving, 0.50 halves a frame):

| cut | laptop empty | laptop model | laptop share | phone empty | phone model | phone share | mean |
|---|---|---|---|---|---|---|---|
| dense | - | - | - | 0.38 / 0.37 | 0.75 / 0.79 | 0.50 / 0.53 | 0.56 |
| msaa | 0.74 / 0.73 | 0.47 / 0.45 | 0.73 / 0.69 | 0.79 / 0.78 | 0.57 / 0.56 | 0.72 / 0.60 | 0.65 |
| scale | 0.58 / 0.60 | 0.91 / 0.93 | 0.60 / 0.59 | 0.31 / 0.30 | 0.73 / 0.73 | 0.39 / 0.46 | 0.59 |
| shadow | 0.85 / 0.78 | 0.77 / 0.94 | 0.75 / 0.75 | 0.70 / 0.91 | 0.85 / 0.84 | 0.80 / 0.97 | 0.83 |
| glow | 1.06 / 0.94 | 0.80 / 0.94 | 0.89 / 0.95 | 0.77 / 0.95 | 1.09 / 0.91 | 0.97 / 0.98 | 0.94 |
| shadow_soft | 0.83 / 0.89 | 0.86 / 0.89 | 0.89 / 0.91 | 0.93 / 0.94 | 1.15 / 0.81 | 0.79 / 0.89 | 0.90 |
| shadow_size | 0.93 / 1.01 | 0.96 / 0.99 | 1.00 / 0.89 | 1.09 / 1.00 | 0.89 / 1.08 | 0.97 / 1.10 | 0.99 |
| ui | 1.05 / 0.95 | 0.84 / 1.02 | 0.99 / 1.09 | 1.01 / 0.94 | 1.08 / 1.01 | 0.98 / 0.68 | 0.97 |
| ladder | 0.23 / 0.22 | 0.28 / 0.27 | 0.27 / 0.26 | 0.17 / 0.16 | 0.24 / 0.24 | 0.15 / 0.13 | 0.22 |

"ladder" is every rung at once (dense, msaa, scale, shadow, glow and, in
these runs, the two dropped below); "ui" is the interface not drawn, to see
what it costs: nothing measurable. With every rung cut a frame still took
167 to 513 ms: SwiftShader on this box is over the budget whatever is cut,
so the app ends there with every rung down.

The look as it is, a frame (median of six turns, each up to its fence; the
first turn of each page is a warm-up and not counted):

| size, scene | base r1 | branch r1 | base r2 | branch r2 |
|---|---|---|---|---|
| laptop empty | 636 ms (load 20-28) | 1065 ms (load 42-48) | 1023 ms (load 42-47) | 1005 ms (load 43-50) |
| laptop model | 1137 ms (load 35-40) | 1810 ms (load 47-69) | 1825 ms (load 59-63) | 1253 ms (load 32-48) |
| laptop share | 1127 ms (load 41-43) | 1033 ms (load 44-50) | 1194 ms (load 49-56) | 800 ms (load 30-43) |
| phone empty | 1865 ms (load 40-46) | 2056 ms (load 47-69) | 1828 ms (load 46-54) | 1432 ms (load 31-48) |
| phone model | - | 1881 ms (load 42-56) | 2514 ms (load 56-62) | 1857 ms (load 42-49) |
| phone share | 1818 ms (load 43-47) | 1864 ms (load 43-62) | 1787 ms (load 43-47) | 1278 ms (load 28-43) |

At the same load the branch's "none" is rel-m87's: laptop empty 1,023 ms
(base, load 42-47) against 1,065 and 1,005 (branch, 42-50); phone share
1,818 and 1,787 (base, 43-47) against 1,864 (branch, 43-62). The base's own
rounds moved with the load (laptop empty 636 ms at 20-28, 1,023 at 42-47),
which is why a cut is read against its neighbours and not against another
run. dense, msaa, scale and everything cut agree within 0.05 between the
rounds in every cell but the phone viewer's (msaa 0.72 / 0.60, scale 0.39 /
0.46), and are trusted; shadow and glow moved by up to 0.2 between rounds
and are said as "about". rel-m87's first phone run with the model never
finished copying the set in (900 s), so that cell has one base round.

## The ladder's order

dense, msaa, scale, shadow, glow; ssao before them on Forward+.

- dense (0.56 on average, 0.37 to 0.79) and scale (0.59) buy the most: in
  software a frame costs its pixels.
- msaa (0.65) goes before scale. On the laptop it bought more (0.64 against
  0.70 on average, and 0.46 against 0.92 with the model in), and edges
  drawn one sample deep are seen far less than the whole view at half.
- shadow, about 0.83: the sun casts none, and is lit up to match.
- glow, about 0.94: next to nothing in software, last.
- ssao is not measured (the web has none) and stays first on Forward+,
  where a desktop on a weak card would have it.

A device a little over the budget loses one rung, the one that buys the
most; one far over loses two or three at once (4x, 16x); SwiftShader at
0.4 to 2 s a frame loses them all within a few looks.

## The two global shadow rungs: dropped

shadow_soft (the sun's shadow filtered from one sample) and shadow_size (its
atlas at half across) were set through
`RenderingServer.directional_soft_shadow_filter_set_quality` and
`directional_shadow_atlas_set_size`, which are global: every directional
light in every viewport, the photo-real render's sky light among them. They
are dropped, not guarded. Measured, shadow_soft bought about 0.90 and
shadow_size 0.99 (the atlas at half across bought nothing), while "shadow"
bought 0.83 and takes the sun's shadow from the main view only. Guarding
them would have meant lifting both for every render and proving the render
unchanged, for rungs that buy nothing "shadow" (the sun's own
`shadow_enabled`, which the render's lights do not share) does not.

## A capable device looks the same

`tools/probe.sh look_probe -- --shots=DIR` on the RX 6700 XT, on this branch
and on rel-m87, three views of the house, compared with `cmp`:

- Forward+ (Vulkan on the card): view_0, view_1 and view_2 identical. The
  probe's first look timed frames at 8 to 12 ms, judged them quick and cut
  nothing; the window was still four samples deep at full scale, with glow
  and the sun's shadow.
- Compatibility, through Mesa's zink (OpenGL ES on the card's Vulkan; the
  env is in look_probe's header): identical, all three. Under Xvfb without
  zink, Compatibility drew on llvmpipe, in software, where FrameBudget
  rightly lowers the look, so that run cannot prove a capable device.
- One run differed, in view_0 only, in 4,750 pixels, all in the status
  line (rows 783 to 796): "opened House — 71 bricks" against the Select
  hint. The bar shows a message for 4 s and that run's first look ended
  sooner. The probe now waits 5 s after opening before its pictures, and
  base and branch were run again with it.
- Forward+ pictures of rel-m86 and rel-m87 taken two hours apart were
  identical too: the pictures are steady from run to run.

The probe's "every frame timed is quick" check failed once on
Compatibility (two of six first-look frames at 48 and 75 ms, the rest 17 to
27) while the app, judging by the second fastest, rightly cut nothing. It
now checks the judgment the app makes, and says the worst frame.

## A person's acts, before and after

`look_cost.mjs --mode=acts --gate` on local exports of rel-m87 and this
branch's final build, A B A B, each act timed up to a fence after it: a turn
of the view, a part dragged (and undone), a 2 x 4 brick in hand swept over
the model, and in the viewer Play's steering wheel turned. A frame, by the
fence:

| size, scene, act | base r1 | branch r1 | base r2 | branch r2 |
|---|---|---|---|---|
| laptop empty, orbit | 908 ms (load 38) | 512 ms (load 26) | 668 ms (load 26) | 370 ms (load 21) |
| laptop empty, drag | 887 ms (load 38) | 175 ms (load 26) | 644 ms (load 26) | 187 ms (load 21) |
| laptop empty, place | 669 ms (load 38) | 153 ms (load 26) | 693 ms (load 26) | 187 ms (load 21) |
| laptop model, orbit | 1043 ms (load 35) | 274 ms (load 30) | 883 ms (load 27) | 151 ms (load 19) |
| laptop model, drag | 1007 ms (load 35) | 253 ms (load 30) | 840 ms (load 27) | 150 ms (load 19) |
| laptop model, place | 1021 ms (load 35) | 208 ms (load 30) | 881 ms (load 27) | 154 ms (load 19) |
| laptop share, play_drag | 768 ms (load 43) | 191 ms (load 27) | 483 ms (load 22) | 120 ms (load 18) |
| phone empty, orbit | 1636 ms (load 36) | 327 ms (load 29) | 862 ms (load 22) | 256 ms (load 19) |
| phone empty, drag | 1024 ms (load 36) | 187 ms (load 29) | 659 ms (load 22) | 115 ms (load 19) |
| phone empty, place | 1190 ms (load 36) | 262 ms (load 29) | 771 ms (load 22) | 151 ms (load 19) |
| phone model, orbit | 1228 ms (load 32) | 259 ms (load 27) | 920 ms (load 19) | 156 ms (load 21) |
| phone model, drag | 944 ms (load 32) | 139 ms (load 27) | 632 ms (load 19) | 162 ms (load 21) |
| phone model, place | 1216 ms (load 32) | 203 ms (load 27) | 744 ms (load 19) | 334 ms (load 21) |
| phone share, play_drag | 1430 ms (load 29) | 214 ms (load 26) | 879 ms (load 19) | 212 ms (load 24) |

The gate, "drawn in software, the app chose a lighter look by the end of
the acts": this branch 6 of 6 in both rounds; rel-m87 0 of 6 in both, as a
build without FrameBudget must. With the look lowered a frame took 0.15
to 0.30 of rel-m87's in the same round (round 2 ran at much the same load
on both, 18 to 27), but for the empty editor's first turn (0.55) and one
phone place (0.45): 115 to 512 ms against 483 to 1,636. In
the model and the viewer every rung was already cut by the time the page
had loaded (the judgments at 10 to 32 s); in the empty editor at the end of
the first turn, so that turn is the dearest of the branch's (370 and 512 ms
on the laptop).

## The frames gate

`tools/web/cad_frames.mjs --gate --arrive=300 --only=orbit,select_all,step`
on 75969-1 (925 parts), as the release runs it, on local exports of
rel-m87 and this branch's final build, two pairs (base then branch, then
branch then base), load 28 to 39: every check passed on both, both times.
The app's own work, base / branch:

| | pair 1 | pair 2 |
|---|---|---|
| orbit, 95th percentile (bar 200 ms) | 25.7 / 31.4 ms | 30.8 / 24.3 ms |
| orbit, median | 19.2 / 19.6 ms | 17.9 / 18.1 ms |
| select all, worst frame (bar 400 ms) | 56.9 / 75.7 ms | 54.8 / 52.2 ms |
| Next, worst of five (bar 200 ms) | 17.5 / 14.4 ms | 19.4 / 28.0 ms |

The pairs disagree on which is slower, by as much each way: no change in
the app's own work that this can see.

## Also run

What `featuremap affected` lists against rel-m87, with `tools/probe.sh` on
the final code: typing 8/0, offgrid, share_play 40/0, share_view 173/0,
placing 38/0, quit 17/0, empty_save 8/0, update 7/0, unrestored 18/0,
versions 28/0, page_places 7/0, design_undo 20/0, viewer_tools 36/0,
gallery_tool 48/0, mcp_sync 12/0, bigmodel 43/0 (ok/FAIL), cadtask_frames
on the house (every act timed); `-- --about` and `-- --model=models/car.ldr
--out=…` (61 parts in, 61 out).

## What got worse

- **The look on a slow device**, by design. In software every rung is cut
  within half a minute: no multisampling, no sun shadow, no glow, and the
  3D drawn at half a point (a quarter of a laptop's pixels; on a 3x phone,
  a thirty-sixth) and stretched. The interface stays sharp. SwiftShader is
  still over the budget with all of it cut (167 to 513 ms a frame), so
  that is where it ends there.
- **The first turn in the editor waits for the cuts.** The editor's first
  look is drawn while the parts bin reads its pictures back, which holds
  the drawing between frames, so no fence judges it and its timed frames
  (handed over cheap) say quick. The app cut during the first turn of the
  view instead (laptop: at 22, 27 and 32 s; phone: at 24 and 30 s), so that
  turn ran at 512 ms a frame against 274 once cut. In the model and the
  viewer the cuts were made while the page loaded.
- **Frames drawn on purpose.** A look draws frames nobody asked for: in
  software up to 10 to 20 of them, 0.3 to 3 s each, over the first half
  minute.
- Nothing measurable in the app's own work (the frames gate above), and
  nothing on a capable device (the pictures above).

## How to measure

```
python3 tools/web/serve.py BUILD PORT --parts assets/generated/parts --delay 0 \
    --share L00kM0del1=vendor/omr/files/6392-1.mpd --share Pl4yFl0w01=vendor/omr/files/8808-1.mpd &
set -a; . ./.env; set +a
node tools/web/look_cost.mjs --url=http://127.0.0.1:PORT --out=DIR --mode=cuts --rounds=1 --base=7 \
    --sizes=laptop --cuts=dense,msaa,scale,shadow,glow,ui,ladder
```

Run the base and the branch in turn, A B A B, each in one heavy slot, and
record `uptime` with each (the rows carry the load too). A cut is read
against the "none" just before and after it in the same page, which cancels
the box's load as it drifts; the first measurement of each page is a
warm-up and is not counted. A cut's number is trusted when its two rounds
agree; the base's runs beside the branch's, at the same load, show that
the look as it is costs what it did before.

## Next

1. Look again when a look was held apart (the editor's first, while the
   parts bin reads its pictures back), so a slow device is cut before its
   first turn rather than during it.
2. Measure on a real weak device, a phone and a laptop's integrated card.
   SwiftShader stands in for one: there a frame costs its pixels, and on a
   real card multisampling, glow and the shadow atlas may weigh more.
3. ssao (Forward+, the desktop) is first on the ladder and not measured:
   the web has none to measure.

## Proposal: a switch for the look

Not built (the owner keeps the interface as it is). If wanted later, a
Settings choice of Draw: Automatic / Full / Light would let a person on a
slow device keep the full look for a screenshot, or choose the light one
on a capable device to save battery.
