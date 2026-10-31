# Rendering: toward a set's own product shots

The owner, 2026-10-29: "Should build more advanced rendering features for
effects and hyper realistic backgrounds (and hyper realistic rendering) such
that Lego might use for its actual product renders."

This is the research, the recommendation, and what the first slice
(render340) built and measured. The renderer itself is described in
`src/render/studio_render.gd`'s header and in the verify skill
(`.claude/skills/verify/features/view.md`, `photo-real render`,
`studio renderer`, `product look`).

## The answer in ten lines

1. A realtime Product look in Godot gets most of the way to a product
   shot. It is built (Render, Look, Product; render_model `look=product`).
   It costs nothing in the window and nothing more in render time.
2. The last of the way is light transport that a rasteriser fakes: glass in
   front of glass, light bounced through clear parts, caustics, true soft
   area light, and a real bevel on every edge. That is a path tracer's job.
3. The path tracer to use is Cycles, through Blender run headless. Do not
   bundle it. Call it on the desktop when Blender is installed, as Render
   already calls ffmpeg. Run it on a GPU worker for people on the web.
4. Parts reach Blender as the LDraw file itself, through ldr_tools_blender
   (MIT), which already maps LDraw colours to Cycles materials. ImportLDraw
   (GPLv2+) is the fallback with the richer look options.
5. LuxCore (Apache-2.0) and Mitsuba 3 (BSD) are not worth the extra work.
   Neither has an LDraw importer, and Mitsuba is a research renderer.
6. On the web, the realtime look is what runs in the tab, with fewer effects
   under Compatibility. A path-traced still is a server job.
7. The realtime Product look stays free, as docs/PLANS.md (plans332) keeps
   renders free. The desktop, which is Pro there, simply draws it with more.
8. Server path-traced stills cost real GPU time, so they suit Pro: a monthly
   allowance, then metered.
9. A real geometric bevel needs the full mesh build again (about 1.5 h on 20
   cores, 2.1 GB, 46,476 files) and more triangles in the window. Do it for
   the Cycles export only, never for the window's meshes.
10. Next, in order: R2 Cycles on the desktop, R3 the server worker, R4 logo
    studs and the bevel at export, R5 lifestyle scenes, R6 the web's look.

Since APP_UX3 pathtrace (2026-10-31), Best is path traced in the app itself
where the card has Vulkan's ray tracing pipeline: soft shadows and light
bounced off the floor and between parts, in seconds (section 5c). Cycles is
still the way to a real bevel and caustics, and the web still has no tracer.

## 1. What makes a LEGO® product render read as real

Each line says what the eye uses, then what we do about it.

**The plastic.**
- **Opaque parts are ABS.** ABS is a dielectric with a polished-mould
  gloss. Product shots show a broad soft lobe under a sharp highlight, and
  the reflection strengthens towards the silhouette (Fresnel). Pale
  colours glow a little in shadow because light scatters under the surface.
- **Clear parts are polycarbonate, not ABS.** Newer ones are MABS
  ([BrickNerd, "Every type of plastic used by LEGO"](https://bricknerd.com/home/every-type-of-plastic-used-by-lego-5-20-22);
  [BrickNerd, "A clear path forward for transparent bricks"](https://bricknerd.com/home/a-clear-path-forward-for-transparent-bricks-1-21-22)).
  A clear part refracts what is behind it and tints it; it does not veil it.
- **Chrome is a vacuum-metallised mirror.** Metallic paint is a satin metal
  with flake in it. Pearl is a pigmented sheen that brightens towards the
  edges. Rubber has no polish at all.
- **The community renderers model exactly these classes.** ImportLDraw's
  Cycles materials are plastic, transparent, rubber, chrome, metal,
  pearlescent, glow, glitter, speckle and fabric
  ([ImportLDraw](https://github.com/TobyLobster/ImportLDraw)), and
  ldr_tools_blender's are similar
  ([ldr_tools_blender](https://github.com/ScanMountGoat/ldr_tools_blender)).
  Our FINISHES in `plastic_body.gdshaderinc` already sort every LDraw
  colour into the same classes.

**The geometry.**
- **Real edges are rounded**, and every highlight runs along those rounds.
  A model with razor edges reads as CG at once.
- **Bricks leave a hair of gap between them.** We already draw that seam in
  the window.
- **Studs carry the logo**, which LDraw has as logo-stud primitives.
  ImportLDraw offers all three as options: bevel edges, gaps between
  bricks, and the logo on studs. It also offers slightly concave walls "for
  more natural reflections".
- **Mould seams and faint sink marks** matter only in close-ups.

**The light.**
- **A studio set:** a large soft key, a fill to lift the shadow side, and a
  rim from behind that draws a line along every top edge and stud.
- **An HDRI environment**, which is also what the gloss reflects.
- **A contact shadow and ambient occlusion** where parts meet the floor and
  each other.

**The camera.**
- **A normal-to-long lens** (50-100 mm full-frame), low, three-quarter: the
  box-front view.
- **A little depth of field** on hero shots; none on catalogue shots.

**The background.**
- **A seamless sweep:** white for catalogue shots, a soft gradient or a dark
  backdrop with a pool of light for hero shots.
- **Lifestyle scenes:** a table, a shelf, a child's room. These are
  composited or built sets, a later unit.

**The finish.**
- **A film-like tone curve** that rolls highlights off rather than clipping
  them.
- **Colours that hold their hue.** LEGO's palette is the brand, so a red
  must stay red.
- **Light grading.**

## 2. Godot 4.7's realtime ceiling

What the engine offers, for this project, on this box (RX 6700 XT, Godot
4.7.2):

| Effect | Forward+ (desktop) | Compatibility (every browser) | Used |
|---|---|---|---|
| PBR plastic, metallic, roughness, specular | yes | yes | yes, already |
| Clear coat (CLEARCOAT, CLEARCOAT_ROUGHNESS) | yes | not drawn | Product |
| Subsurface scattering (SSS_STRENGTH) | yes, screen-space, scale in world units | no | no: BACKLIGHT, keyed to lightness, instead |
| Refraction (hint_screen_texture) | yes | wrong picture in a viewport | no longer: render340-342's glass, until render353 (section 5b) |
| Multiply blend (blend_mul) | yes | yes | Product, clear parts: every surface tints what is behind it (render353) |
| SDFGI global illumination | yes | no | Good and Best, already |
| VoxelGI | yes, needs a bake per model | no | no: SDFGI needs no bake |
| SSAO | yes | no | yes, already; deeper in Product |
| SSIL | yes | no | **no**: its half-size checker of samples showed as dashes at Good |
| SSR | yes | no | **no**: Godot will not draw it in a viewport with a transparent background, which the render's scene viewport is ("Screen-space reflections are not supported in viewports with a transparent background") |
| Volumetric fog | yes | no | not yet (haze for lifestyle scenes, R5) |
| DOF | post blur, or many frames through a lens | the lens only | the lens, already (Best) |
| Tone mapping | Linear, Reinhard, Filmic, ACES, AgX (agx_white, agx_contrast) | the same curves | Product: Filmic |
| Antialiasing | MSAA, TAA, FXAA, FSR | MSAA, FXAA | frames averaged under jitter, already |
| Soft shadows | PCSS-like, by light angular size; atlas to 8192 | basic PCF | area key sampled across frames, already |

What we found while building it:

- **AgX turned red to orange.** It rolls bright colours off to white
  through a hue path that takes a saturated red through orange. The sports
  car's bricks came out the orange of a traffic cone
  (`bench/results/render340-2026-10-29/`, the first product render).
  Filmic keeps red red. Product uses Filmic, with saturation ×1.18 and
  contrast ×1.06 put back.
- **The HDRI's radiance map needs `Sky.PROCESS_MODE_QUALITY`.** It costs
  nothing that matters, because it is filtered once per render.
- **The soft key hatched grey faces with its own shadow at Good.** Its
  filter spreads over many texels of the shadow map, and a face turned
  from the light lies behind the map across that spread. Normal bias
  moves the test a texel or two and did not reach. The product key's
  depth bias is 0.12 (render342, section 5a).

**Our meshes** (`tools/build_meshes.py`, `tools/ldraw/meshfile.py`):
- **Smooth normals except across LDraw type-2 edge lines**, so creases are
  hard.
- **No bevel, no logo studs, no gap.** The seam is drawn in the shader from
  the part's box.
- **Size:** 46,476 distinct shapes, 2.1 GB, quantised to 10 bytes a vertex.
  A full build is about 1.5 h on 20 cores (its own header). Each part's
  connectors, and so its studs, are in the file.

**Reachable in realtime:**
- **Achieved.** A well-lit studio shot of glossy plastic with rounded
  box-edges and stud rims, clear parts seen into and through (their own
  walls and tubes, and other clear parts behind them, render353), metals
  reflecting a studio, soft area shadows, contact shadow and AO, a lens,
  and a graded film curve. That is the after pictures below.
- **Not reachable.** Light bent by a clear part (render353's glass tints
  what is behind it and does not move it). Light through clear parts:
  their shadows are grey, not coloured. Caustics. Edges rounded where they
  are not on the part's box or a stud's rim: a slope's edge. True
  subsurface glow in white bricks.

**Cost on the web against the desktop:**
- **Compatibility has no SDFGI, SSAO, clear coat or quality soft shadows**,
  and draws in a browser's one thread.
- **What Product gives a browser:** the glass, the bevel normal, the
  rig, Filmic and the backdrops. A browser's sky is not used for
  reflections, because it lit wrongly there (see `_dress`).
- **Best's 32 frames there** cost what they always did. The product
  shaders add a branch per fragment, and a clear part a second pass,
  which is nothing next to that.

## 3. An offline path tracer

| | **Cycles (Blender)** | **LuxCoreRender** | **Mitsuba 3** |
|---|---|---|---|
| Licence | Cycles: Apache-2.0 ([cycles](https://projects.blender.org/blender/cycles)); Blender: GNU GPL ([blender.org/about/license](https://www.blender.org/about/license/)) | Apache-2.0 ([luxcorerender.org](https://luxcorerender.org/)) | BSD-3-Clause style ([mitsuba3](https://github.com/mitsuba-renderer/mitsuba3)) |
| LDraw path | ldr_tools_blender (MIT), ImportLDraw (GPLv2+): import an .ldr/.mpd and build the materials | none: would need our own exporter and materials | none: our own scene writer |
| GPU | CUDA, OptiX, HIP (AMD), Metal, oneAPI | OpenCL, CUDA | CUDA, LLVM (CPU) |
| Denoiser | OpenImageDenoise, OptiX | OIDN | none built in |
| Headless | `blender -b -P script.py` | the SDK or pyluxcore | Python |
| Size | a Blender install, several hundred MB (unmeasured) | smaller, but a plugin to maintain | a pip wheel |
| Fit | best: a maintained importer, every finish mapped, the bevel, logo and gap options already there | good engine, nothing for us | a research renderer, wrong tool |

**Licensing.**
- **Calling Blender as a separate program** (a subprocess, the way Render
  calls ffmpeg) is use, not linking. Brickworks's code stays its own, and
  the add-ons run inside Blender.
- **Bundling Blender in our packages** would mean shipping GPL software:
  its source offered with it, and its size in every download.
- **So: don't bundle.** Find it where it is installed (as
  `RenderOutput.ffmpeg` finds ffmpeg) and say how to get it when it is
  not. A server worker runs Blender on our machine and ships nothing.

**Render time.** Not measured in this unit: Blender is not installed on
this box. That is R2's first measurement. These are estimates from
experience with LDraw scenes, and are to be replaced by numbers:
- **GPU:** a 1080p still of a few hundred to a few thousand parts, a few
  hundred samples with denoising, is tens of seconds on a current
  mid-range card.
- **CPU:** minutes.
- **Turntables:** 36 to 72 such frames, so minutes on a GPU and an hour or
  more on a CPU.

**Desktop, or server for web users.**
- **Desktop:** free to us, needs Blender, no upload.
- **Server:** needs the model uploaded (an .ldr is kilobytes), a queue, a
  GPU worker, and a picture back.
- **Server cost** is GPU time × the rate. At an assumed $0.50-$1 per hour
  for a rented consumer-class GPU (an assumption to check at R3), a 60 s
  still is 1-2 cents and a 36-frame turntable 30-60 cents. That is cheap
  per render, but unbounded without a limit, which is why it belongs to a
  plan.

**Parts to materials.** ldr_tools_blender maps LDraw colours to Cycles
materials by colour code and LDConfig finish. Our `PartLibrary.BrickColor`
finish numbers are the same classes, so for a custom part, or a colour
LDConfig lacks, our finish can be passed through as a material override.
Prints that Brickworks draws itself (`PartPrints`) export as textures,
which both importers read. That export needs checking in R2.

**Recommendation.**
- **Cycles via Blender headless**, importing with ldr_tools_blender, behind
  Render's quality choice as a fourth grade, "Studio (path traced)".
- **On the desktop** when Blender is found. On the web, a server job.
- **The realtime Product look stays the preview and the default.**

## 4. The look gap today, and after the first slice

Three models (plus the orrery), Best, 1280×720, hero view, on Forward+ on
the GPU (`tools/probe.sh render_probe -- --model=…`). Pictures are in
`bench/results/render340-2026-10-29/`:
- `*_best.png`: before;
- `*_product.png`: after, Product with the gradient backdrop;
- `*_before_after.png`: side by side;
- `sports_car_product_dark_dof.png`: dark backdrop at f/4;
- `crop2.png` and `crop8.png`: the edge dashes before and after the fix.

| Model | Parts | Before (window look) | After (Product) |
|---|---|---|---|
| sports_car | 187 | 3,859 ms | 4,230 ms |
| corner_shop | 797 | 5,441 ms | 5,393 ms |
| barn_owl | 1,032 | 4,314 ms | 4,273 ms |
| orrery | 520 | 4,925 ms | 4,565 ms |

The gaps before, against a real product shot:
1. The plastic was matte, with one soft highlight and no gloss on top. It
   read as clay or a CAD view.
2. Edges were razor sharp, with no line of light along them.
3. The clear windscreen was a grey veil.
4. Pearl gold read as flat mustard, and chrome as grey plastic in its
   finish's drawn studio.
5. The sweep was one flat colour, with no fall of light.
6. The tone was ACES at the window's settings: fine, but video-game
   contrast.

After: 1, 2 (on box edges), 3 (in front of opaque parts), 4 and 5 are
closed, and 6 is a film curve. What is still visibly short of a LEGO
product shot:
- edges that are not on a part's box (slopes, curves) are still sharp
  (stud rims rounded in render353);
- no logo on the studs;
- clear behind clear (closed in render353, section 5b);
- no light through clear parts;
- black read as mid-grey, and at Good grey faces were hatched (both
  fixed in render342, section 5a);
- no lifestyle scenes.

The rest needs the path tracer.

**The bevel**, three ways:
- **A real bevel at the mesh build.** Every part's shapes are built again
  (1.5 h on 20 cores) and uploaded again (2.1 GB). It adds a chamfer strip
  on every crease, an estimated 30-60% more triangles, which the window
  pays for at every frame. Not worth it for the window.
- **A real bevel at Cycles export.** ImportLDraw and ldr_tools_blender
  already do this, per render, in Blender. This is the plan (R4).
- **The normal trick, built here.** The normal near the edges of the
  part's body box is bent as a rounded box's would be: within a bevel's
  width, at least 0.6 LDU and 2.2 pixels.
  - It never invents a round, but it misses edges that are not on the box.
  - It costs a few ALU operations per fragment, in the render's shaders
    only.
  - A round a pixel or two across is seen at its average turn, with its
    gloss spread. Drawn exactly, its highlight came out as dashes along
    every edge at Good (`crop2.png` against `crop8.png`).

## 5. The first slice, as built

- **The look.** `RenderSettings.look` is "window" or "product". In the
  dialog it is the Look row; over MCP, render_model's `look`.
  - Product stages the render's copy of the model with
    `BrickWorld.product`, which draws each batch in its
    `PRODUCT_SHADERS` variant (`plastic_product*.gdshader`, defining
    `PLASTIC_PRODUCT` in `plastic_body.gdshaderinc`).
  - The window's BrickWorld never sets it, and its shaders compile without
    the product code.
- **Plastic** (opaque ABS, plain finish): roughness 0.3-0.38, specular
  0.35 under a clear coat of 0.55 at roughness 0.07 (one surface's 4.5%
  shared by the two lobes), and a little colour-keyed glow in shadow.
- **Chrome:** metal at roughness 0.06, reflecting the studio's sky.
- **Metallic:** metal at 0.34 under a clear coat.
- **Pearl:** metallic 0.65 under a coat.
- **Rubber:** roughness 0.8.
- **Transparent:** the screen behind, bent by the normal, times the
  colour itself (LDConfig's value is the part against white), with a low
  specular so its edges reflect and its face is not veiled. Replaced in
  render353 (section 5b).
- **Light** (`StudioRender.PRODUCT_RIG`, Forward+):
  - the key is the window's own key;
  - a fill sits low on the camera's left;
  - a rim comes from behind and above;
  - all three sit over the softbox HDRI, which is also the ambient light
    and what everything reflects, its room flagged down to 20% and its
    softboxes left whole (`studio_sky.gdshader`, `PRODUCT_ROOM`).
  - A chosen photographed place still replaces the rig, as it did.
- **Backdrops** (`RenderSettings.BACKDROPS`, one table for the dialog and
  render_model):
  - white, a plain sweep;
  - gradient, near-white falling 42% by the edges;
  - grey;
  - dark, near-black with a pool of light, falling 80%.
  - The fall is `fall` and `pool` in `studio_backdrop.gdshader`, measured
    along the sweep from the model.
- **Depth of field:** Best's lens, already there. render_model's
  `depth_of_field` asks for f/4 focused 40% back, and draws at Best.
- **Tone:** Filmic, white 4, saturation 1.08, contrast 1.03, exposure 0.7
  of the window's (`PRODUCT_*`; render342 set them on colour swatches).
- **AO:** SSAO at intensity 1.6 and radius 10 LDU. SDFGI at Good and Best,
  as before.

Proof (`tools/probe.sh product_render_probe`, on the GPU, 2026-10-29):
- every batch of the render's copy in a product shader (6 of 6), and none
  of the window's;
- the picture differs from the window look's by 0.116;
- white corners 0.95;
- gradient 0.96 under the model, 0.83 in its corners;
- dark corners 0.01;
- detail 0.0113 sharp, 0.0090 at f/2;
- **the window's frame on the card 2.624 ms before and 2.614 ms after**,
  with its environment unchanged.

## 5a. Black, the hatching and colour (render342)

The owner wants renders good enough for product shots. Three things kept
the first slice short of that.

**Black read as mid-grey on the white sweep.** The causes, as measured
on 2x4 swatches at Good (`product_render_probe`'s swatches):
- **The reflected room (the root cause).** The softbox HDRI is brought
  to an average of one, which is as bright as the key light, and most of
  it is a white cyclorama and a lit floor. Every glossy face mirrored 4-6%
  of that room. Black's own colour is 2%, so the reflection was three
  times the plastic. Halving the sky took black's mean lightness from
  0.218 to 0.162 on its own.
- **The gloss counted twice.** Specular 0.5 (4%) under a coat of 0.55
  (another 2%) is half as much again as ABS's one surface reflects.
- **Not the tone curve.** ACES in Filmic's place took black only from
  0.218 to 0.196. **Not the bevel normal**, which is a line along each
  edge, and **not ambient light**: halving ambient energy moved black by
  0.003.

The fix is what a product photographer does: black flags round the
subject. The product look's sky is the same softbox studio with its room
at 20% and its softboxes (over six times the average) whole, so highlights
stay crisp and black stays black. The plastic's specular is 0.35 under the
coat. Black's bricks now average 0.17 (0.13 in the window look; 0.155 is
LDraw's own #1b2a34). Dark bluish grey stays 3 dE from its own colour,
not crushed into black.

**The hatching on grey faces at Good** was the soft key's own shadow (see
section 2): grain on a light grey face of 0.038, 0.006 with shadows off,
0.024 at a normal bias of 6 (render340 set 3), 0.0069 at a depth bias of
0.12.
The window look's renders still show it at Good (0.034). The same bias
would fix them, but they are outside this unit.

**Colour.** Mean colour of the middle of each swatch's lit face (the face
the key lights and the camera sees, a fifth in from each edge), against
LDConfig's value, CIEDE2000 (about 1 is the least an eye tells apart):

| Colour | LDraw | Before (render340) | dE | After (render342) | dE |
|---|---|---|---|---|---|
| black | #1b2a34 | #2d3031 | 7.0 | #26292a | 6.3 |
| dark bluish grey | #646464 | #706e6b | 4.5 | #6d6b68 | 3.2 |
| dark red | #720012 | #8c181f | 5.9 | #810914 | 3.6 |
| dark blue | #19325a | #273d6a | 3.9 | #1b3360 | 1.2 |
| red | #b40000 | #ca0f0e | 4.8 | #be0504 | 2.2 |
| yellow | #fac80a | #eacb0a | 4.8 | #e2c506 | 5.4 |
| blue | #1e5aa8 | #2266b8 | 4.3 | #1b5fad | 1.9 |
| green | #00852b | #19a033 | 9.5 | #0a9229 | 4.8 |
| white | #f4f4f4 | #dbdad7 | 5.8 | #dad8d6 | 6.1 |
| tan | #d7ba8c | #d3bd90 | 2.4 | #ceb98e | 2.7 |
| light bluish grey | #969696 | #a6a3a0 | 4.8 | #9f9d9a | 3.0 |
| trans clear | #fcfcfc | #e2e2e2 | 5.4 | #d9d9d8 | 7.5 |
| trans red | #c91a09 | #e48480 | 25.5 | #ca1b0f | 0.8 |
| trans dark blue | #0020a0 | #7c84da | 32.5 | #0e23ac | 1.9 |
| trans yellow | #f5cd2f | #e7d890 | 11.8 | #dbc62e | 5.4 |
| trans green | #237841 | #8acd9f | 28.6 | #2b8648 | 4.9 |
| **mean, the six bright** | | | **5.28** | | **3.85** |
| **mean, the five clear** | | | **20.77** | | **4.11** |

The clear colours were washed to pastels for two reasons:
- **The glass model.** The hue was kept at full strength, with a sixth of
  the light let past untinted.
- **The engine.** At Good and Best, Godot lights a clear part's reflection
  from its global illumination, where the white sweep is at full
  strength. At glass's own specular that laid a white veil over the face.

Now what gets through is the screen times the colour, and the specular is
low enough that only the edges reflect.

Two other things moved the exposure:
- **The meter counted the look's glass.** It is drawn opaque, and so dark
  on the meter's clear background. The meter now leaves it out, as it
  already left out the window look's see-through glass.
- **The plain sweep's level crept** towards white over its four rounds in
  the curve's shoulder. Its gain now follows the last round's answer.

A film curve compresses white against a saturated colour, so the two are
traded: white comes out #dad8d6 while red, blue and green sit on their
own. Brighter exposures ran the colours past LDraw's and white was still
short.

Pictures: `bench/results/render342-2026-10-29/`:
- `*_best_gradient_before_after.png`: Best, gradient, render340 then
  render342;
- `*_good_white_before_after.png`: Good on the white sweep;
- `crop_*.png`: the black parts and the grey faces, at 3x;
- `swatches_before_after.png`: the swatches.

## 5b. Clear parts, the web, and stud rims (render353)

**Clear parts read as solid.** Trans red, blue, yellow and green had their
colour after render342 but looked like opaque plastic
(`bench/results/render342-2026-10-29/swatches_before_after.png`). The
cause, found on the swatches and a clear wall in front of a trans-red one:
- **The glass was one surface deep.** It read the picture behind it from
  a copy of the screen, which the engine makes once, after the opaque
  parts and before any clear one, and it drew only its nearest surface
  (a depth prepass with alpha 1). So a clear brick's own far walls, tubes
  and studs were never behind it, and on the plain sweep its face was the
  floor times one flat tint: a solid.
- **Clear behind clear was not there at all.** The clear wall's face over
  the trans-red wall came out #d0d0d0, the sweep (red by 0.00, as
  r - (g + b)/2).
- **Not the balance of absorption and transmission, the refraction's
  strength, the clear coat (off on glass) or the sweep's brightness.**
  Each moves the tint, none puts the far side of the part in the picture.

The fix: every surface of a clear part, front and back, multiplies what is
behind it by what one surface lets through (`plastic_product_glass.gdshader`,
blend_mul, the batch's first pass): the square root of LDConfig's colour
per surface, so a wall at normal incidence gives the colour render342
matched, more plastic gives more colour (a ray along a wall, within 4 LDU
of the box's edge, counts 2.5 walls), and the bend of the ray inside
(ABS about 1.5) keeps the slant short. A multiply needs no order, so no
sorting and nothing inside out. Then the reflections are added on top
(`plastic_product_trans`, premultiplied with alpha 0): the key and rim on
every surface, inside ones too, which is what outlines the tubes, and
the rounded edges at specular 0.7 for a bright rim (0.15 face on, as
before, so no veil). The refraction's bend is given up: on a brick's flat
face it moved nothing, and a thin wall moves little.

Measured (`product_render_probe`, Good, white sweep; the before is
main at 7864e6c4 with the same probe):

| | Before | After |
|---|---|---|
| trans clear | #d9d9d8, dE 7.5 | #ededec, dE 3.2 |
| trans red | #ca1b0f, dE 0.8 | #d4211b, dE 3.5 |
| trans dark blue | #0e23ac, dE 1.9 | #1d24a3, dE 1.5 |
| trans yellow | #dbc62e, dE 5.4 | #f0cb25, dE 1.2 |
| trans green | #2b8648, dE 4.9 | #2a6b38, dE 4.4 |
| **mean, the five clear** | **4.11** | **2.76** |
| a clear wall over a trans-red one | #d0d0d0, red by 0.00 | #a85251, red by 0.34 |
| the same on nothing (no backdrop) | black: alpha 1.00, lightness 0.16 | glass: alpha 0.98, lightness 0.65 |
| the window's frame on the card | 2.620 ms | 2.604 ms before the renders, 2.609 after |

The opaque colours are where render342 left them (bright mean 3.86;
black's bricks 0.179, under 0.19, the stud rims' highlights the 0.007).

**On nothing** (the None backdrop, a transparent picture) there is
nothing behind the glass to tint, and it would come out clear; before, it
came out black. There the glass is blended as the window's is, its colour
in the picture's alpha (`over_nothing`, set by StudioRender).

**The web.** Under Compatibility the old glass's screen read came back as
the wrong part of the picture: the sports car's windscreen showed a flat
taupe patch with pieces of the red bodywork in it
(`compat/sports_car_before.png`). The multiply reads nothing, so the same
glass draws there. `PREMUL_ALPHA_FACTOR` does not compile under
Compatibility (`premul_alpha` undeclared in the GLES3 scene shader), so the
reflections are premultiplied by hand. Compatibility's picture is sRGB, so
the multiply is the linear factor to the 1/2.2 there.

In Chromium on SwiftShader (`product_render_flow.mjs`, Quick, 720p, the
web build of main at 7864e6c4 against this one, each served locally):
- main's clear glass is white: the black wall behind it shows only at its
  ends, 0.11% of the picture grey and near black, and the check fails;
  here 1.25%, and it passes (at least 0.5%);
- the red glass is red on every backdrop (0.86% on white, 0.13% on dark);
- the render's longest frame is no longer than main's: 512 ms against 619
  for the first picture, which compiles the shaders, then 28-49 ms
  against 36-78.

**Stud rims.** The box's round left every stud a knife edge. A stud's top
edge is now rounded the same way (`stud_rim`: the 6 LDU stud on the 20 LDU
grid from the part's box corner, standing to the box's top), so each stud
carries a ring of light. Slopes' edges are still sharp: their plane is not
in anything the shader is given.

Pictures, `bench/results/render353-2026-10-29/`:
- `desktop/*_before.png`, `*_after.png`, `*_before_after.png`: Forward+,
  Good, white sweep: swatches (`swatches.ldr` there), sports_car,
  corner_shop, barn_owl;
- `compat/`: the same under Compatibility (the desktop binary with
  `--rendering-method gl_compatibility`, Xvfb);
- `web/`: the web build in Chromium on SwiftShader
  (`tools/web/product_render_flow.mjs`): the glass walls on each backdrop,
  and the three models;
- `before/`: the probe's pictures and output on main.

## 5c. Best path traced in the app (APP_UX3 pathtrace)

- **Where.** `PathTracer.available()`: a RenderingDevice with Vulkan's ray
  tracing pipeline and buffer device addresses. The RX 6700 XT on RADV has
  the pipeline but not ray queries, so the tracer is raygen, miss and
  closest-hit shaders (`src/render/path_tracer.glsl`), not a compute pass.
  Never on the web or under Compatibility: there Best is frames averaged,
  as before, and Render's quality note says why.
- **What it traces.** The staged copy of the model, every MultiMesh batch
  as instances of one bottom-level structure per mesh, and the sweep. The
  light is the photographed place (importance-sampled, with MIS) or the
  window's sky, and the rig's lights; only the key casts a shadow, as in
  the window. Plastic is a diffuse base under a GGX coat; clear parts are
  thin tinted glass. Six bounces. The sweep lights the model as its own
  colour and is scaled to the backdrop's lightness for the eye alone.
- **Exposure** is metered as the raster's is, so a traced picture is as
  light as the window; tone mapping is the window's own curve, exactly.
- **Passes.** Each frame the card is given about 28 ms of tracing (8 for
  the render queue), timed by the card's own timestamps: a band of rows
  while a whole sample is more than that, up to 32 samples when it is
  less. The window's frame time is no measure of it: under Xvfb a frame is
  25-30 ms of copying whatever the card does, and the card has room.
- **Measured** (`tools/probe.sh pathtrace`, RX 6700 XT, 1400x900 window):
  - the car at 1280x720 and 256 samples in 3.3-4.2 s (the bar is 60 s;
    before the card timed its passes, one sample a frame, 11.5 s);
  - its RMSE against 4,096 samples 0.0083 (bar 0.02); 16 samples 0.031;
  - a column's shadow widening from foot to tip, 4.0, 7.5 and 12.2 LDU,
    where frames averaged draws 4.2, 7.8 and 12.0: both soft;
  - under a white shelf over an orange floor, orange 0.318, 0.272 and
    0.375 traced against 0.262, 0.207 and 0.331 frames averaged: the
    floor's light, where frames averaged has only its sky and the
    backdrop's colour reflected;
  - three queued renders of the car at 960x540 and 128 samples in 22 s,
    one after another, while the window turned every frame: its median
    frame 28 ms and 95% within 51, against 35 and 55 turning with nothing
    drawn on a box shared with other jobs.
- **The render queue** (File, Render queue…; `render_queue` over MCP)
  draws pictures one after another with Render's settings while the
  window is used. Each keeps the view and the model as they were when
  added. Its tracer shares the bottom-level structures with Render's,
  builds new ones a few a frame, and meters in four frames, so starting a
  picture does not hold the window.
- **Not done.** A transparent picture stays frames averaged (its contact
  shadow on nothing is the raster's). No denoiser: 256 samples are clean
  enough on the car, and Cycles keeps OIDN for R2.

## 6. Web and desktop

- **Desktop (Forward+):**
  - Product in full.
  - Then Cycles as a fourth grade when Blender is installed (R2).
- **Web (Compatibility):**
  - Product's shaders, rig, film curve and backdrops, without SDFGI, AO or
    clear coat.
  - Path-traced stills from the server (R3).
  - Product under Compatibility was drawn once in render340 (on the GPU
    under Xvfb, `--rendering-method gl_compatibility`, Good, 960×540,
    12.7 s): it compiled and drew, with the backdrop's fall, the rig and
    the curve, but the windscreen showed a pale patch where its refraction
    read the wrong picture (`sports_car_compat_product.png`).
  - render353 gave the glass a multiply that reads nothing (section 5b),
    and proves it in a browser: `tools/web/product_render_flow.mjs` opens
    a black wall behind clear glass and a white one behind trans red, and
    draws Product on each backdrop, failing on a flat picture, red glass
    that is not red, or a black wall that does not show dark through the
    clear glass.

## 7. The paid plan

docs/PLANS.md (branch plans332) puts Pro at the desktop app and Claude
builds without a limit. It rules out moving renders behind Pro: "client-side,
so patchable on the web", and "takes something away".

- **The realtime Product look follows that, and is free everywhere.** On
  the desktop it is fuller, and the desktop is Pro there, so Pro gets the
  best realtime look without gating anything.
- **Server path-traced stills and turntables** are new, cost us real GPU
  time, and cannot be patched round, since they run on our machine. They
  fit Pro as an allowance: say 20 stills a month, and turntables counted
  as frames. Past it they are metered or refused. The numbers come from
  R3's measured cost.
- **Desktop Cycles on the person's own Blender** costs us nothing. It goes
  with the desktop, so with Pro.

## 8. The remaining units, in order

Each says what it does and the bar it must reach.

1. **R2 Cycles on the desktop.**
   - **What:** Render's fourth grade, "Studio (path traced)". It writes
     the model as .mpd with our camera, the rig as area lights, the HDRI
     and the sweep. It runs `blender -b` with ldr_tools_blender (vendored
     at a pinned version, MIT), and reads the PNG back.
   - **Bar:**
     - the same 3 models path traced, next to this unit's after pictures,
       the camera matching to the pixel;
     - the measured time on this box's GPU and CPU, for a still and a
       36-frame turntable;
     - when Blender is missing, a plain "install Blender" message and the
       Product look offered instead;
     - render_model `quality=studio`;
     - the window untouched (product_render_probe).
2. **R3 path-traced renders on the server.**
   - **What:** an API job (the .mpd and the settings in, a PNG or WebP
     out) on a rented GPU worker, the queue on Supabase.
   - **Bar:**
     - a web user's render back in under 2 minutes at 1080p, measured;
     - the cost per still and per turntable, measured;
     - the Pro allowance enforced server-side (Admission);
     - a preview deploy proving it end to end (unit_preview.sh).
3. **R4 real geometry at export.**
   - **What:** the bevel, the gap between bricks and logo studs, on in
     the Cycles export (ImportLDraw-style options).
   - **Bar:** close-ups of a 2×4 brick and a slope against a photograph
     of the real part, the edge highlight and the logo matching, and the
     time added per render measured.
4. **R5 lifestyle scenes.**
   - **What:** a table, a shelf and a play mat, as HDRI-and-floor presets
     (Poly Haven CC0, recorded in ATTRIBUTION), in both the realtime and
     Cycles paths, with haze (volumetric fog) on the desktop.
   - **Bar:** each preset on 3 models; the model sitting on the surface,
     with its shadow and reflection; no stretched HDRI at the horizon.
5. **R6 the web's Product look.** Proven and the glass fixed in
   render353 (section 5b, `product_render_flow.mjs`); what is left is the
   frame budget below.
   - **What:** Product proven and tuned under Compatibility.
   - **Bar:**
     - `render_flow.mjs` presses Product and draws each backdrop;
     - no frame over the dialog's existing budget (`worst_frame_ms`);
     - pictures in Chromium on SwiftShader next to the desktop's;
     - unit_preview.sh pass.
6. **R7 the box-edge bevel's misses.** Stud rims done in render353
   (section 5b); slopes are left.
   - **What:** slopes and stud rims rounded in the realtime look, either
     from the LDraw edge lines baked into a per-part edge texture at build
     time, or a screen-space edge detect in the render's own pass.
   - **Bar:** the crops in `bench/results/render340-2026-10-29/` with
     slope and stud edges lit, no dashes at Good, and the window's frame
     unchanged.

## Sources

- Godot 4 docs:
  - [Environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)
  - [Standard Material 3D (clearcoat, refraction, subsurface)](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)
  - [Renderer feature comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
  - [Spatial shader built-ins](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
- Blender importers and renderers:
  - [ImportLDraw](https://github.com/TobyLobster/ImportLDraw): GPLv2+; Cycles and EEVEE looks, bevel, gaps, logo studs, concave walls, the finish materials.
  - [ldr_tools_blender](https://github.com/ScanMountGoat/ldr_tools_blender): MIT; instancing by part and colour, Cycles materials, models of hundreds of thousands of parts.
  - [Blender licence](https://www.blender.org/about/license/)
  - [Cycles](https://projects.blender.org/blender/cycles)
  - [LuxCoreRender](https://luxcorerender.org/)
  - [Mitsuba 3](https://github.com/mitsuba-renderer/mitsuba3)
- LEGO's plastics (hobbyist sources, not official):
  - [BrickNerd, every type of plastic used by LEGO](https://bricknerd.com/home/every-type-of-plastic-used-by-lego-5-20-22)
  - [BrickNerd, 2026 edition](https://bricknerd.com/home/every-type-of-plastic-used-by-lego-2026-edition-3-12-26)
  - [BrickNerd, transparent bricks](https://bricknerd.com/home/a-clear-path-forward-for-transparent-bricks-1-21-22)
- HDRIs: Poly Haven, CC0, in docs/ATTRIBUTION.md.
- Measurements: this unit's probe and renders,
  `bench/results/render340-2026-10-29/`.
