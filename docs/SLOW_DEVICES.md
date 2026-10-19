# Slow devices

Work in progress (stopped at the owner's spin-down, 2026-10-19 06:10 AKDT).

On a weak device a frame of Brickworks takes 0.5 to 3 s. Chromium drawing in
software (SwiftShader) is what the release checks use for one. A frame there
costs about the same whatever is happening in it, a swing, a drag or a turn
(docs/MECHANISMS.md, swingtrace). The app's own work in such a frame is a few
milliseconds. So the lever is what a frame draws.

`FrameBudget` (`src/render/frame_budget.gd`) times the frames the app draws.
Where they are slow, it draws less. Where they are quick, it changes nothing
and writes nothing to the renderer.

## How the app decides (built, not yet tuned)

- It times each drawn frame that follows a drawn frame: the time from the
  end of one drawing to the end of the next, less that frame's own work
  (from process_frame to frame_pre_draw). On a graphics card that is the
  display's pace. In software it is the drawing.
- Two seconds after the window is up, it draws ten frames on purpose and
  times them (a write of what the renderer already has wakes a frame). It
  skips two warm frames, then keeps timing every frame it draws anyway.
- It judges by the second fastest of the last six frames. A quick device's
  rare long frames (a shader compiled, a model read in) therefore never
  count. Over SLOW_MS (50 ms), it cuts the next rung. At 4x over it cuts two
  rungs, and at 16x over, three. Then it looks again.
- It only lowers the look, never raises it within a session. Probes leave it
  off unless they call `watch()`, as IdleDraw does. It is also off when
  headless.
- Rungs, in their first order, still to be re-ordered by measurement:
  ssao (Forward+ only), dense (3D at one pixel to the point on a screen
  over 1.25x), msaa, glow, shadow_soft (hard filter), shadow_size (atlas
  half across), shadow (the sun casts none, lit at
  `BrickWorld.light_energy(…, false)`), scale (3D at half a pixel to the
  point).
- Caveat: shadow_soft and shadow_size are global in the RenderingServer,
  so they would also lower the photo-real render's shadows
  (studio_render's sky light). Either keep them off the ladder or lift them
  while a render runs.

## What a frame costs, setting by setting (only begun)

Measured with `tools/web/look_cost.mjs --mode=cuts` on a local export of
this branch, laptop size (1280 x 800 at 1x), empty editor, one round:

| cut | app's timing | page's gap | load |
|---|---|---|---|
| none | 26.1 ms | 27.6 ms | 16 |
| msaa | 719 ms | 695 ms | 17 |
| every rung | 737 ms | 574 ms | 21 |

This cannot be read as a cost yet. The empty editor drew at 26 ms a frame,
so the app rightly cut nothing there. After the first pinned cut, frames
were 27x slower, which no cut explains. Swingtrace saw SwiftShader slow
down the longer it drew without rest. So the order of measuring, or the
change itself (a render target reallocated at runtime?), is suspect. The
next run interleaves "none" between cuts, and it hung: its first look never
finished within 600 s. Neither the 500-part model, nor the phone, nor the
viewer has been measured yet.

## A capable device looks the same

`tools/probe.sh look_probe -- --shots=DIR` writes three views on the GPU.
On rel-m86 (no FrameBudget) it ran on the RX 6700 XT (Forward+), failed its
"frame budget is there and watching" check, as a check that fails without
the change should, and wrote the three pictures. On this branch it has not
run yet: the job timed out while waiting in the queue. The byte compare
with `cmp` is still to do, on Forward+ and on `--rendering-method
gl_compatibility`.

## Next

1. Fix look_cost's hang. Measure each cut with "none" between cuts, at both
   sizes and in all three scenes, two rounds, beside a rel-m86 export
   under the same load.
2. Order the ladder by those costs. Drop or guard the global shadow rungs.
3. Run look_probe here and on rel-m86 on the GPU, and `cmp` the pictures.
4. Before and after acts (`--mode=acts`, `--gate`) on both builds.

## Proposal: a switch for the look

Not built (the owner keeps the interface as it is). If wanted later, a
Settings choice of Draw: Automatic / Full / Light would let a person on a
slow device keep the full look for a screenshot, or choose the light one
on a capable device to save battery.
