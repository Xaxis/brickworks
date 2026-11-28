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
still the way to a real bevel and caustics. Since photoreal28 (2026-11-26),
Best in a browser is path traced too, on the visitor's own graphics card:
the desktop's shaders ported to WebGL2 at the export (section 5ac).
Since photoreal1 (2026-11-21), Best in the Product look is judged blind
beside real photographs. Its studs carry the logo, its edges and slopes are
moulded, and light bends through clear parts. The judge still finds the
photograph every time, now less sure (section 5e, with what is left).

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
- no logo on the studs (traced at Best, Product look, since photoreal1,
  section 5e);
- clear behind clear (closed in render353, section 5b);
- no light through clear parts (refracted at Best, Product look, since
  photoreal1);
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

## 5d. Lights in the model, and plastics that glow (APP_UX5 lights)

- **What a model keeps.** Up to 8 lights (`SceneLights`, a `0 !BRICKWORKS
  LIGHT {json}` line each after the file's first line): a bulb, a spot, a sun
  or a square panel, its place and aim in the file's coordinates, colour,
  strength, a spot's cone, a bulb's radius or a panel's side, and shadows.
  Strength 1 lights a face 100 LDU from a lamp, or any face turned to a sun,
  as the window's key does; a lamp falls off with the square of distance.
  Older Brickworks and other LDraw readers pass over the lines.
- **What is read, and what is kept as it is.** Only the main model's lines,
  up to an MPD's second `0 FILE` (or `0 !DATA`, or its first `0 NOFILE`): a
  sub-model's lights and saved views are its own, and stay in it. At most 4
  of the 8 are suns: the studio's three lights, the sky (Good) and four suns
  are eight, the most either renderer draws, so the tracer and the raster
  always light the same. Each number is rounded to the thousandth a file
  keeps before it is checked, so a strength that would be written as 0 is
  refused, with why. A line that is no light (not `{`-words, past the first
  64 tried, of a kind there is not, a ninth light, a fifth sun) is not read
  and stays in the file word for word: where it was in someone else's file,
  after the lights in Brickworks' own (written whole); the open says how
  many and why on the status bar. A save takes out exactly the lines the
  open read (`SceneLights._sorting`, the one rule for both), writes a light
  read and not changed since in its author's words, and keeps the file's
  line ends.
- **Rasterised** as Godot's own lights (`StudioRender._place_lamps`): an
  OmniLight3D, a SpotLight3D (its edge the rim to the power 3, which Godot
  takes as `spot_angle_attenuation` 1/3: it raises the rim to the
  reciprocal, and at 3 the floor beside the car had a third of the light), a
  DirectionalLight3D; a panel a spot opened to 80 degrees falling off as the
  cosine, its size softening the shadows. **Path traced** by the tracer's
  `from_lamps`, the same fall, cone and edge, the panel a true square of
  light, each lamp's random numbers a stream of their own.
- **Nothing outside a spot changes.** The exposure and the sweep's level
  are metered with the lamps hidden, as a photographer meters the set and
  then adds a lamp; the lamps are bounced by neither the raster's global
  illumination (`light_indirect_energy` 0) nor the tracer (first surface
  only), so the draft shows the light Best draws, and a pixel whose surface
  is outside the cone is the same pixel. Their bounce is what is given up.
  For that the same settings draw the same picture: the tracer's samples
  take their numbers from their own index and the seed, not from how its
  passes fell (a pass's size follows the card's timing, and changes only
  between whole samples); and a raster picture in one piece is drawn wider
  and cut back when it has occlusion, as pieces were, since its last
  column came out darker and not the same twice.
- **Dark** (Render's Light, `lighting` "dark"; `render_model light=dark`):
  the studio's three lights and the sky put out, the ambient 0.025, the
  sweep beyond the lights' reach 4% of its colour, no metering. The neons
  (Trans Neon Green, Orange, Yellow, Red) and Glow In Dark give off light, as
  Eyesight draws them: the plastic shaders' `glow` (2.0 times their colour)
  and, rasterised, a light at each 80-LDU lump of them (12 at most, no
  shadow); traced, their faces are lights of their own, opaque and clear.
- **On Compatibility** (the web's renderer), which draws at most 8 bulbs
  and spots on one thing (`max_lights_per_object`; the stage's batches are
  one thing each, so in effect the set, and spots counted apart): while
  anything glows the glow keeps at least 2 lights of its own
  (`GLOW_KEPT`), the model's bulbs making room by the dimmest given to the
  one nearest it (where the two are, by energy), and the glow's lumps
  gathered into the lights it has (a few rounds of k-means weighted by
  power), so its energy only ever goes into a glow light, never a bulb.
  Folded into the nearest bulb instead (the first design), 8 bulbs over a
  neon grid drew the glow from where the bulbs hang, the picture's mean
  177.6 to 117.6 and its far floor black. Now, the mean / the floor left /
  right of the grid with 0 and 8 bulbs: Forward+ 171.2 / 134.0 / 168.3 and
  174.9 / 154.7 / 168.3; Compatibility 175.3 / 139.8 / 169.8 and 175.6 /
  155.4 / 166.1 (the left floor, under the bulbs, rising as on Forward+).
  Compatibility
  adds light in sRGB, so Dark there is calibrated against Forward+ on the
  card through zink: exposure x2, lamps x4 over `BrickWorld.light_energy`,
  and the model's suns sharing what Forward+ gives them together (it adds
  in linear light and encodes the sum, so 4 equal suns light about 1.9 times
  one: each is scaled by the sum's 1/2.2th power over the sum of the
  powers). The car's mean under 0 to 4 suns: Forward+ 18.4, 103.7, 134.5,
  151.8, 162.3; Compatibility 22.6, 109.2, 140.6, 158.5, 166.5 (it was 9.9,
  24.0, 33.7, 41.7, 48.8). No exposure and lamp energy alone brought one
  sun and four within 15% (24 pairs tried).
- **Measured** (`tools/probe.sh lights`): see the probe's numbers in its
  run log; the bar is 0 px changed outside the cone both ways (on
  Compatibility, which draws a shadowed light in passes of its own, none
  more than a level apart and none lighter on the whole: 92,700 px came
  out a level apart, more of them darker, the mean -0.135 of a level) and
  the
  floor the spot lights beside the car 15% and 10 levels lighter, on a grey
  sweep (the car's roof is black), and the plate round a neon 1 x 1 three
  times as light as round a Trans Green one.

## 5e. Beside real photographs (photoreal1)

On 2026-11-21 the owner asked whether Render makes bricks look like real
bricks. Until then no render had been put beside a photograph: the path
tracer had been measured for speed and noise only. This unit built the
bench first, measured, then changed the tracer and measured again.

**The bench.**
- **Six close-ups** of real parts in free-licence photographs
  (`tools/photoreal/photos/`, credited in docs/ATTRIBUTION.md):
  - a black 2x4 on leather;
  - a red 2x4 slope;
  - a grey 1x3 on a table;
  - a clear round 1x1;
  - three 2x2s from above;
  - a green plate's corner in macro.
- **Four real sets** beside their own product pictures
  (`vendor/rebrickable/set_pictures/`): 6512 Landscape Loader, 6532 Diesel
  Dumper, 6657 Fire Patrol Copter and 6660 Hook & Haul Wrecker. All are from
  before 2000, so none is in realset's held-out pool (which starts at 2000).
- **The probe** (`tools/probe.sh photoreal`) draws each shot at Best,
  Product look, matching its photograph: same model, angle, lens, framing,
  backdrop, depth of field and size, at 256 samples, path traced.
- **The judge** (`tools/bench/photoreal.py judge`) is blind. It is Claude
  (claude-opus-5-5, on the subscription) shown the photograph and the render under
  opaque names, both cropped to the same shape and size and saved as JPEG
  at 92. Each pair is shown in both orders. It is asked which picture is
  the photograph of real bricks, how sure it is, and what gives the render
  away. That makes 20 trials a round.
  - A render as real as the photograph is picked half the time.
  - Each "before" round was drawn the same day, from a locked worktree at
    pre261 (16744b131).

**What changed** (Best, Product look only: `PathTracer.product`). The
window's own look and its Best are drawn as before.
- **The logo on every stud**, raised 0.15 LDU with rounded flanks. It is
  drawn as a normal from the letters' distance field in the closest-hit
  shader, on any stud top whose part has studs (`part_body_top`). No mesh
  build is needed.
- **Rounded edges.** The product look's bevel and stud rim, from
  `plastic_body.gdshaderinc`, are now in the tracer and drawn exactly,
  with no pixel-averaging. A part alone no longer gets the painted dark seam.
- **A slope's moulded grain**: two octaves of normal noise on a straight
  slope's face, with a satin coat instead of a mirror.
- **Light bent through clear parts.** The tracer refracts at index 1.585
  (polycarbonate), with total internal reflection inside.
- **Gloss that varies across a face.** Each part also gets its own shade
  and faint scuffs. These made no measurable difference; see the rounds
  below.
- **No sampling sparkle.**
  - One sample may give at most 3x what its exposure draws as white
    (`PRODUCT_MOST`; the window look's Best keeps 40).
  - The resolve cleans the picture: each pixel becomes the weighted mean
    of its neighbours within 3 px. A neighbour is weighed down by how far
    it is, and by how unlike it is in units of the noise a mean of 256
    samples carries (`PRODUCT_DENOISE` 3.0). Edges and logos are kept.

**The numbers.** Pick rate means how often the judge chose the photograph;
"sure" is its mean confidence, from 0.5 to 1.

| Round | Code | Close-ups (12) | Sets (8) | All (20) |
|---|---|---|---|---|
| before | pre261 | 12 found, sure 0.963 | 8 found, 0.877 | 1.00, 0.929 |
| after1 | logo, bevel, refraction | 12, 0.932 | 8, 0.866 | 1.00, 0.906 |
| before2 | pre261, depth of field added to the shots | 12, 0.958 | 8, 0.885 | 1.00, 0.929 |
| after2 | + denoise 1.2, uneven gloss | 12, 0.920 | 8, 0.861 | 1.00, 0.896 |
| before3 | pre261, the macro reframed | 12, 0.958 | 8, 0.895 | 1.00, 0.933 |
| after5 | + sample cap, denoise 3.0 | 12, 0.920 | 8, 0.849 | 1.00, 0.891 |
| after7 | + per-part tone, scuffs, dust | 12, 0.927 | 8, 0.866 | 1.00, 0.903 |
| **final** | dust taken out (c95d80f51) | **12, 0.920** | **8, 0.868** | **1.00, 0.899** |

Read plainly:
- **The judge still finds the photograph every time**, before and after,
  in close-ups and sets, in both orders. The bar was a lower pick rate,
  and it was not met.
- **It is less sure.** The three before-rounds scored 0.929, 0.929 and
  0.933; the five after-rounds 0.891 to 0.906. No shot became more certain.
  The closest is set 6512, at 68 (before 72 and 80).
- **Dust backfired.** Flecks of dust were called "white firefly speckles"
  and taken out. The scuffs and the per-part shade moved nothing that
  can be measured (0.891 against 0.899).

What it said, verbatim:
- The black 2x4, before: *"B is a flat, matte, untextured model with
  path-tracer noise."*
- The black 2x4, after: *"B looks like a clean CG model with a flat,
  featureless background and noisy blur that comes from the renderer."*
- Three 2x2s, before: *"B's studs are blank, its surfaces are perfectly
  flat and matte, and its edges are razor sharp."*
- Three 2x2s, after: *"B's bricks look perfectly uniform, with the same
  logo and the same shadow on every stud."*

The render's tells it named, out of about 100 a round:

| Tell | before3 | final |
|---|---|---|
| too clean: no wear, dust, scratches, mould or gate marks | 22 | 24 |
| too uniform: colour, gloss, every stud alike | 16 | 29 |
| sampling noise or grain, mostly in out-of-focus areas | 17 | 17 |
| backdrop: featureless sweep, hard horizon | 16 | 14 |
| edges too sharp | 9 | 10 |
| logos (missing before; "too perfect" after) | 11 | 8 |
| faceted round parts | 4 | 3 |
| clear parts | 10 | 8 |
| a figure stood beside the vehicle | 5 | 3 |

**Time.** The car at Best, Product, 1280x720, 256 samples, three runs
each. The pre261 tree and this one ran at the same moment, twice:
- 3.20 s against 3.86 s;
- 4.06 s against 3.50 s.

Both are well under the 8.4 s bar, and the difference is the card's noise.

**Pictures.** `bench/results/photoreal1-2026-11-21/side_by_side/` has one
row per shot: the photograph, before3, and final. `all_before_after.jpg`
holds all ten rows. Each judge's every verdict is in `judge_<round>.json`
beside them.

**What is left, in order** (biggest share of the tells first):
1. **The sweep on pure white for set shots.** Every set's own picture is
   a cut-out on white with a soft shadow. Ours shows the sweep's floor
   meeting its wall (14 tells). It needs a shadow catcher: the backdrop
   drawn at exactly its colour wherever the model casts no shadow.
   - Best cannot do this today. It never path traces a picture with
     nothing behind the model (`RenderSettings.traced_here`), so a
     transparent cut-out falls back to raster frames averaged.
   - The tracer already carries the coverage it would need (the resolve's
     alpha).
   - A try at judging the sets cut out onto white stopped there:
     comparing a raster cut-out with a traced render would mix two
     changes.
2. **Noise in out-of-focus areas** (17 tells). At f/11 to f/22, 256
   samples leave grain in the blur. Options: more samples for the lens
   alone, or a denoiser that knows depth, normal and albedo (the
   tracer's first hit can write them).
3. **Variety a real part has.**
   - Uniformity was named more after than before (16 to 29), once the
     logo made every stud alike.
   - Each stud's logo should differ slightly in depth and sharpness, as
     moulds wear.
   - Gate marks belong on the studs of the parts that have them.
   - Scuffs a judge does not read as procedural.
   - Any added point detail must be larger and softer than a firefly.
4. **Clear parts tinted too deep.** The tint is the colour at each face,
   so a pane seen through both faces gets its colour squared. 6660's
   Trans Medium Blue windscreen came out deep blue where the photograph
   shows it pale. The fix is absorption by thickness (Beer–Lambert).
5. **Faceted round parts**: the silhouettes of 16-sided primitives. This
   needs higher-resolution primitives (48-sided) in the mesh build, which
   was not this unit's. Prove it on the harness parts first.
6. **What the bench cannot fix in the renderer.**
   - The close-ups' photographs sit on leather, stone and tabletops; ours
     on a plain sweep. That is R5's lifestyle scenes.
   - OMR stands 6657's and 6660's figures beside the vehicle; the box
     seats them.
   - Old sets' plastic is yellowed and faded in their photographs.

## 5f. Staged as the photographs, and colour fitted to them (photoreal2)

The owner's ask, the same day: match the staging and calibrate the colour
against the photographs before anything else, and be honest in the
numbers. photoreal1's judge had been comparing staging as much as
rendering: a sweep's horizon against a cut-out on white, a pool of light
against a tent.

**Staging taken out first** (bench copies only; no set file changed).
- **The shadow catcher.** Best, Product, path traced on a backdrop draws
  the backdrop at exactly its colour, darkened only where the model keeps
  light from it (each light once and the sky four times, weighed by the
  light each brings, so a big soft light's shadow is as soft as it is).
- **A light tent** where a photograph has one (the product look, studio
  light, a light backdrop):
  - white walls at `TENT_FILL` 0.4 and a panel overhead at 3 more;
  - a soft key where the rig's key stands (`TENT_KEY`, 0.45 rad from its
    middle to its edge), which the light's turn moves;
  - a dark port where the camera stands, which a glossy top mirrors.
- **Photographed places** (the window and daylight HDRIs) only for the
  room photographs: the black 2x4, the green plate and set 6657.
- **The white card.** Exposure is metered as a photographer meters: a
  white card where the model stands, on the floor, `PHOTO_EV` (0.33) stops
  over the paper's own light.
- **Framing, lens and figures** fitted to each photograph
  (`tools/photoreal/shots.json`). In the bench copies, 6660's driver is
  seated in the cab and 6657's pilot, who stood beside the copter, is
  taken out. The judge still names 6657's empty cockpit: its picture's
  pilot sits inside, which the OMR file does not have.

**The same-day before.** photoreal1's renderer with the staging matched,
drawn from a locked worktree (4b3250dbf), judged three times. The rounds
agree within 0.002:

| Round | Close-ups (12) | Sets (8) | All (20) |
|---|---|---|---|
| before1 | 12 found, sure 0.917 | 7, 0.815 | 19, 0.877 |
| before2 | 12, 0.914 | 7, 0.823 | 19, 0.878 |
| before3 | 12, 0.915 | 7, 0.825 | 19, 0.879 |

**How colour is measured.** Each close-up has a box on its lit faces in
the photograph and the same face in the render (`faces` in shots.json,
drawn before any fitting). Each box's colour is the mean CIELAB (D65) of
its pixels with the lightest and darkest fifths dropped. The distance is
CIEDE2000. `python3 tools/bench/photoreal.py colour TAG` writes the table.

**What the measure found.** Three faults, each fixed at its root:
- **A white backdrop's model was drawn a stop too light.** Inverting the
  curve at 1.0 never stopped below the top in floating point
  (1.055 − 0.055), so the search ran on to twice white.
- **A low camera metered the wall.** The card was read from everything
  that was not the model, which for the red slope (13° up) was mostly the
  sweep's rise. That is lit less than the floor, so the model came out
  twice as light as the card. The card's picture now leaves the rise
  black (`path_tracer.glsl`), and only the floor is read.
- **The plastic was dull.** LDraw's colours, kept exactly as the file
  says, came out duller and darker than a camera draws the same parts.

**The camera, fitted.** The probe's `--raw` writes each picture's light
before any exposure or curve. A camera was fitted to the tent close-ups'
faces from that light, so each try costs no render:
- saturation in linear light, as a camera's colour matrix gives it
  (`PHOTO_LINEAR_SATURATION` 1.6);
- `camera_curve`: linear to 0.6, then a shoulder reaching white at 2.5
  times white, so a lit red keeps its shading. A narrow shoulder clipped
  the red slope to flat pure red;
- no contrast or saturation after the curve: contrast round 0.5 capped
  white at 0.91, and the paper's goal ran off the top again.
- A full 3x3 matrix fitted no better. It turned LDraw yellow orange, so
  it was not used.

**ΔE2000 on each close-up's faces** (main faces carry the bar of 5):

| Shot | Face | Before | After |
|---|---|---|---|
| black 2x4 (room) | top, main | 39.3 | 38.3 |
| | long side | 14.3 | 15.3 |
| red 2x4 slope (tent) | slope, main | 14.9 | **1.9** |
| | end | 11.8 | 21.3 |
| grey 1x3 (tabletop) | long side, main | 26.5 | 18.3 |
| clear round 1x1 (cut-out) | body, main | 32.9 | 48.2 |
| three 2x2s (tent) | green top, main | 8.2 | **4.2** |
| | red top, main | 13.7 | **3.1** |
| | blue top, main | 7.1 | **3.5** |
| green plate (room) | top, main | 13.4 | 23.6 |

Read plainly:
- **Every tent face is under 5**, on two photographs from two cameras.
- **The room and cut-out photographs are not.** In each, the face is lit
  by a light we do not have:
  - the black 2x4's top mirrors a bright window (L* 62 on black plastic);
  - the grey 1x3's long side is in a lamp's deep shade (L* 13);
  - the green plate's top carries a sheen;
  - the clear brick was cut out from a dark surround, so it shows dark
    teal where ours, in front of white paper, shows light.
- None of the three HDRIs at any of eight turns brought them within 10:
  `--turns=… --lighting=…` sweeps, in the unit's scratch.
- **The red slope's shaded end is 21 off.** The photograph's end is a
  sixth of its lit face's light; the tent's fill leaves ours at half.

**Renderer tells, in the brief's order.**
- **The logo's true outline.** Letters 0.2 LDU high, strokes 0.6 wide
  (a fifth of the letter height, as the real logo's), flat on top with
  steep flanks. Strokes a whole LDU wide were read as "LE¢O".
- **Clear parts absorb by thickness (Beer–Lambert).** The colour is lost
  over `GLASS_DEPTH`, 8 LDU, along the path inside, in place of a tint at
  each face. A pane seen through both faces is no longer squared.
- **A soft area light without a crescent in the studs**: the tent's key.
- **Variety without fireflies.** Each stud's logo is turned, offset,
  deepened and softened a hair by its own hash. A third of the studs
  carry a gate dimple.
- **Edges.** A rounding drawn on a flat face turns its normal right round
  to the next face. At the model's outline that half faced away from the
  eye: lit by nothing and reflecting nothing, it drew two pixels of black
  down every silhouette. The judge named it on the black 2x4 in every
  round until it was fixed.
  - A rounding now faces the eye at least as its face does at a glance
    (0.25), and its paths leave by the rounded normal.
  - The outline shows a soft highlight instead, as the photograph's does.
  - The last round named no outline.
- **The slope's grain**: finer than photoreal1's, as shallow. A deeper,
  coarser grain was read as "blotchy procedural noise": the denoise
  takes its glints for sampling grain.
- **Not done: the denoise guided by albedo and normal.** It is the
  grain's real fix, and the clear brick's "smeared edges".

**The judge** (claude-opus-5-5, the same prompt, both orders, 20 trials):

| Round | Code | Close-ups (12) | Sets (8) | All (20) |
|---|---|---|---|---|
| before, three rounds | photoreal1's renderer, staged (4b3250dbf) | 12, 0.914 to 0.917 | 7, 0.815 to 0.825 | 19, 0.877 to 0.879 |
| after1 | camera, tent key, Beer–Lambert (da72622af) | 12, 0.913 | 8, 0.843 | 20, 0.885 |
| after2 | + legible logo, fine grain, gate dimples (aa773ad1b) | 12, 0.902 | 6, 0.811 | 18, 0.865 |
| **after3** | + no black outline (2b0e8db15) | **12, 0.908** | **7, 0.820** | **19, 0.872** |

- **The bar was not met.** It was the photograph found 16 times or fewer
  in 20, or a mean confidence of 0.80 or less.
- **The judge cannot tell after from before.** The three after-rounds
  found it 18 to 20 times, sure 0.865 to 0.885, mean 0.874. The before's
  three rounds were 19 times, 0.877 to 0.879.
- Set 6512 is a coin toss in every round (55 to 60), taken for the
  photograph in one order or both. Every close-up was found, in both
  orders, in every round.
- **What it names** (tells a round, before1 against after2):
  - clean, no wear: 28 against 30;
  - uniform: 34 against 29;
  - backdrop: 18 against 15;
  - noise: 15 against 10;
  - edges: 16 against 14;
  - saturated: 4 against 9.
- "Oversaturated" is new, said of reds and greens whose mean colour is
  within 5 of the photograph's. It is the flatness of a saturated face
  with no wear on it, not its colour.

**Time.** The car at Best, Product, 1280x720, 256 samples: 1.99, 2.01 and
2.33 s, against the before's 1.20 to 1.64 s the same day (the bar is
8.4 s). The white card's metering and the tent's key cost the difference.

**Pictures.** `bench/results/photoreal2-2026-11-21/side_by_side/` has one
row per shot: the photograph, photoreal1's renderer staged, and
photoreal2. The colour tables are `colour_before.json` and
`colour_after.json`; every verdict is in `judge_<round>.json`.

**What is left, in order:**
1. **Wear and variety on the plastic.** This is the judge's first tell in
   every round: scuffs, dust and mould marks it does not read as
   procedural, and a face's tone varying across it.
2. **The denoise guided by albedo and normal**, so a grain's glints and a
   clear part's edges survive it.
3. **The room photographs' light.** Their lights cannot be matched with
   the three HDRIs we have. A light placed per shot (a lamp, a window
   panel) would let the black 2x4's top mirror a window, as its
   photograph does.
4. **The backdrops' texture** (leather, stone, desk): R5's lifestyle
   scenes. They are the judge's third tell.
5. **A clear part's photograph needs its surround.** The cut-out's dark
   teal cannot be reached in front of white paper.

## 5g. Gloss that mirrors the lights, colour fitted per colour (photoreal3)

The owner's ask, 2026-11-22: real gloss that reflects the light first, then
form, focus and wear; measure against the photographs and be honest in the
numbers.

**Measured first.** `tools/bench/photoreal.py gloss TAG` writes each
close-up's highlight share and peak (pixels over the face's median L* by
10 or more) in boxes on its tops and studs, and its main faces' L* spread,
photograph beside render. On photoreal2's tree the photographs' tops had
highlights the renders did not: the green 2x2 8.0% of its top at +27 L*
against 0.0% at +8; the blue 8.4% at +30 against 0.1% at +10. Two causes:
- **The camera's saturation clipped them.** `PHOTO_LINEAR_SATURATION` 1.6
  pushed a lit red's green and blue below zero and clamped them, so a
  highlight on a red top came out the same red as the face. It is 1.3 now,
  and the colour it gave is in the albedo instead (below).
- **The plastic's gloss was a blur.** Half the coat was a broad lobe of its
  own that smeared every light it mirrored into the face's colour, and the
  tent had nothing for a top to mirror but its walls.

**Gloss** (`src/render/path_tracer.glsl`).
- ABS is one clear skin over its colour: a sharp coat at index 1.55
  (`ABS_F0` 0.0465 face on, Schlick to all of it at a glance), roughness
  0.07. A stud's top is satin (0.3); a hairline scratch roughens the coat
  (0.6), so on a top that mirrors the dark camera it shows as a faint light
  line.
- The tent has two soft boxes behind the model (`TENT_BOX` 8, `tent_box`),
  each 1.2 rad wide from 2 to 38 degrees up, sampled by the lights as the
  panel is. The panel overhead is 60 degrees across (`TENT_TOP` 6).
- A stud leans a hair (up to 0.06 rad, its own), its logo has flanks that
  catch the light, and a moulded face sinks 0.05% towards its middle, so
  each reflection bends a little, as a real part's do.

**Form.** Red, green, blue and black take albedos fitted to the
photographs (`PathTracer.PRODUCT_ALBEDO`): each face's light in the
photograph, uncurved through `camera_curve` and with the camera's
saturation undone, over the render's, times the albedo it was drawn
with. Not a global saturation: each colour is moved only as far as
its own photograph says. A slope's grain is now small round bumps, flat
between, each a glint; the noise of bumps everywhere before veiled the
face pink and read as "procedural noise".

**Focus.** The close-ups that are sharp from front to back in their
photographs are drawn at the f-number that keeps them so at their framing
(`f_stop` in `shots.json`: 64 for the black 2x4 and the slope, 32 for the
grey and the clear round). The denoise is guided by what each pixel first
meets, its normal and its albedo's lightness summed beside the light
(`guide`, binding 10 and resolve binding 2): a neighbour turned another way
or of another albedo is kept apart, so flat faces are cleaned harder
(`PRODUCT_DENOISE` 3 to 5) and a bump, a logo's flank or a clear edge
keeps its edge.

**Wear.** The stud's injection gate is a nub in a ring a millimetre
across on about one stud in three, which the gloss catches as a dot; the
half-millimetre dimple before was too faint for the judge to see. Edge
scuffs were tried and taken out: the judge read them as "dashed
artifacts" along every edge.

**The logo reads across the part.** The black 2x4's photograph shows its
logos running over the brick's width; ours ran down its length, and from
its camera read upside down: "mirrored, garbled lettering" in every round.
It runs along the part's z now. The three 2x2s and the green plate are
turned a quarter in their bench files, so theirs still read as their
photographs' do; the judge has not called a logo mirrored since.

**Rooms.** In a photographed place the backdrop is a table, not paper:
what the model mirrors, or is lit by, past the table's edge is the place's
panorama, where the sweep's rise hid it before. The eye still sees the
backdrop as before; the tent and the studio are untouched. The grey 1x3's
photograph is a room's daylight from its left, not a tent: a sweep of
turns and lights puts it at daylight turned 270. A window panel that the
black 2x4's top would mirror was tried first and made no difference; it
was the sweep's rise that hid it, and with the room now seen it has not
been tried again.

**The judge** (the same model, prompt, 20 trials in both orders). The bar
was found at most 16 of 20 or a mean confidence at most 0.80, against a
same-day before.

| round | what it had | found | sure |
|---|---|---|---|
| before 1, 2, 3 | photoreal2's tree | 20, 18, 20 | 0.881, 0.861, 0.874 |
| a1 | the coat, the albedos, the saturation, focus | 19 | 0.869 |
| a2 | soft boxes, satin studs, stud lean, sink, scuffs | 19 | 0.868 |
| a3 | the guided denoise, the slope's bumps, no scuffs | 19 | 0.868 |
| a4 | the gate, scratches that scatter | 18 | 0.844 |
| a5 | the room past the table, the grey's daylight | 20 | 0.871 |
| a6 | the logo across | 18 | 0.852 |
| a7 | the green plate turned (final) | 18 | 0.859 |

- **The bar is not met.** 18 of 20 at 0.859 is inside the before's own
  spread (18 to 20, 0.861 to 0.881; three rounds 0.020 apart, not within
  the 0.01 asked). Every round since a1 sits from 0.844 to 0.871: nothing
  here moved the judge beyond its noise.
- Every close-up was found in both orders in every round. Every miss in
  every round, before and after, is set 6512 (sure 55 to 62), taken for
  the photograph in one order or both.
- **What it names now:** clean plastic with no dust, wear or yellowing,
  first in nearly every verdict; featureless backdrops; uniform colour; the
  slope's texture as noise; sets sharp from front to back. The logo and
  the gate tells it named are gone; its other tells are not about gloss.

**Gloss and colour, before (photoreal2's tree) and after (a7).** ΔE2000 of
each main face against its photograph:

| shot | face | before | after |
|---|---|---|---|
| three 2x2s | green top | 4.2 | 2.6 |
| three 2x2s | red top | 3.1 | 2.6 |
| three 2x2s | blue top | 3.5 | 0.3 |
| red slope | slope | 1.9 | 1.6 |
| grey 1x3 | long side | 18.3 | 13.1 |
| green plate | top | 23.6 | 19.4 |
| black 2x4 | top | 38.3 | 39.1 |
| clear round | body | 48.2 | 48.0 |

Highlights (share of the box, peak over the face's median L*), photograph,
before, after:

| shot | box | photograph | before | after |
|---|---|---|---|---|
| three 2x2s | green | 8.0%, +27 | 0.0%, +8 | 0.4%, +15 |
| three 2x2s | blue | 8.4%, +30 | 0.1%, +10 | 0.4%, +15 |
| three 2x2s | red | 0.3%, +14 | 0.0%, +4 | 0.0%, +10 |
| red slope | slope | 0.4%, +14 | 0.3%, +4 | 0.3%, +7 |
| black 2x4 | studs and top | 1.2%, +23 | 0.5%, +16 | 0.9%, +24 |
| grey 1x3 | stud and top | 38.5%, +46 | 4.1%, +33 | 4.8%, +32 |
| green plate | studs | 32.7%, +28 | 1.2%, +17 | 7.3%, +21 |

- The tent's faces are all within 5 (they were 4.2 at worst; 2.6 now).
- The highlights' peaks came most of the way to the photographs' (+8 to
  +15 against +27 on the green top); their share did not. A real top's
  highlight is a broad sheen of a window or a softbox over much of it; ours
  are the edges of the soft boxes on the studs and rims.
- The L* spread of a face (a real top's shading across it) is still a
  third to a tenth of the photographs': 1.8 against 7.8 on the green top.
- The black 2x4 (its top a window's reflection at L* 62 against our 18)
  and the clear round (a cut-out on dark teal) are where they were.

**Time.** The car at Best, Product, 1280x720, 256 samples: 2.21, 2.33 and
2.37 s (the bar is 8.4 s; photoreal2's 1.99 to 2.33 s). The window's own
frame is not touched: everything here is in the path tracer's product
look.

**Pictures.** `bench/results/photoreal3-2026-11-22/side_by_side/` has one
row per shot: the photograph, photoreal2's tree, and this. Every verdict is
in `judge_<round>.json`; the colour and gloss tables are
`colour_p2before1.json`, `colour_a7.json`, `gloss_p2before1.json` and
`gloss_a7.json`.

**What is left, in order:**
1. **Wear, dust and age.** The judge's first tell in every verdict of every
   round. Fine dust on a top, a part's tone varying across it, white
   plastic yellowed, as a used brick's are, without reading as point noise.
2. **The backdrops' texture** (leather, stone, desk): R5's lifestyle
   scenes. Every close-up's second tell.
3. **A top's broad sheen and its shading across it.** A softbox seen in a
   top as a large soft gradient, not only on the rims: the L* spread is a
   third of the photographs'.
4. **The room photographs' light.** With the room now seen past the table,
   a window panel per shot could let the black 2x4's top mirror its window.
5. **A clear part's photograph needs its surround**, as 5f said.

## 5h. One picture at a time, the scenes matched, the judge's tells (photoreal4)

The owner's ask, 2026-11-22, continued: the bricks in a render should look
like real LEGO® bricks, judged blind beside real photographs.

**A measure that can see progress.** The paired judge (5e) found the
photograph 18 to 20 times in 20 in every round of 5f and 5g while the
pictures visibly improved: shown two pictures, it keys on any difference
between them, staging as much as rendering. `photoreal.py solo` shows
every photograph and every render alone, shuffled into one pool in a
random order, and asks "a photograph of real LEGO bricks, or a computer
render?" with the chance it gives a photograph and why (`SOLO_PROMPT_VERSION`
1; the paired prompt is unchanged). It reports the photographs and each
tree's renders apart, close-ups and sets apart, per round, and the spread
of the rounds. `photoreal.py tally` groups the tells either judge names.
- **It is stable**: three rounds of two trials each move a tree's mean by
  0.01 at most.
- **It did not separate photoreal2 from photoreal3** (the same day, three
  rounds each): photoreal2's renders 0.119 to 0.129, photoreal3's 0.117 to
  0.122, none called a photograph; the photographs 0.807 to 0.812. Both
  trees' renders read as renders alone; 5g's gloss moved neither judge.
- **Set 6512's picture is itself a render.** Alone, the judge gives it
  0.05, as low as our renders, and every paired miss of 5e to 5g was it.
  It is marked `photo_is_render` in `shots.json` and counted apart from the
  photographs ("reference render"); the paired judge still shows it, so its
  two trials are found in no round.

**Scenes that differ only in the rendering.** A set's camera is fitted to
its photograph's outline, not by eye: `photoreal.py masks` floods each
photograph from its border to its parts' outline (a soft shadow is
backdrop; `mask.far` where a shadow is darker), and `photoreal_probe
--fit` renders the outline alone at a quarter size and moves yaw, pitch,
roll, zoom, shift and focal length while the overlap (intersection over
union) grows, halving its steps. The fitted camera is in `shots.json`.

| shot | what differed from the photograph | what changed | outline overlap before, after |
|---|---|---|---|
| set 6512 | camera by eye; the model's own file absent | its own `set_6512.mpd`, camera fitted, `mask.far` 130 | 0.62, 0.85 |
| set 6532 | camera by eye; the tractor straight on its trailer joint; the driver turned | `set_6532.mpd`: the tractor turned 20 degrees on its joint, the driver seated and facing as photographed; camera fitted | 0.72, 0.87 |
| set 6657 | the pilot stood beside the copter, out of the photograph | the pilot seated in the cockpit facing the camera, as photographed; camera fitted | 0.58, 0.89 |
| set 6660 | the cab's glass a darker blue; the driver's arms down | glass trans light blue (43, from 41); arms forward 35 degrees; camera fitted | 0.64, 0.82 |

The prints were already the photographs' (5f). 6660's overlap stops at
0.82 because its photograph's white B-pillar meets its white paper, and
the flood takes the pillar as backdrop. Matching the scenes did not move
the solo judge on the sets (0.045 before, 0.048 after): it never named the
staging alone, only beside the photograph.

**The judge's tells, biggest first.** Each was measured by the solo judge
on the renders alone (one round of three trials, all on, then each taken
away with `photoreal_probe --without=KEY`); kept only where a measure
moved.

| tell | what it is | renders' mean, on | without it | kept as |
|---|---|---|---|---|
| a lens's softness | the camera's own blur: each pixel blended with its eight neighbours | 0.270 | 0.157 | on in the product look (`PRODUCT_SOFTNESS` 0.6) |
| parts never quite square | each part turned and lifted a hair, its own (`_seated`) | 0.270 | 0.186 | on (`PRODUCT_SEATING` 1.0; sets 2.5) |
| dust | a film on tops that face up, and motes | 0.270 | 0.238 | on (`PRODUCT_DUST` 0.3) |
| the backdrop's paper | broad unevenness and fibre in the sweep and the shadow catcher | 0.155 | 0.139 | per shot only (`paper`) |
| the camera | sensor grain matched to each photograph's measured noise, fall-off, fringes | 0.155 | 0.137 | per shot only (`grain`, `vignette`, `aberration`) |
| age | whites yellowed, colours dulled, gloss worn in patches | 0.155 | 0.159 | per shot only (`age`): it moved the whites' colour, not the judge |

- **Age** moved the measure it was for: the pale parts' b* (a white's
  yellow) inside each set's outline, photograph against render, 6532 10.3
  against 1.0 before and 7.8 after; 6660 10.1 against 0.0 and 8.4. It did
  not move the solo judge (0.159 without, 0.155 with). It is a shot's
  setting, off in the app.
- **The camera** settings match each photograph's own (sensor noise from
  `photoreal.py camera`, Immerkær's estimate over its non-white pixels):
  the app has no photograph to match, so they are off there.
- Glass scratches and the worn gloss ride on age; neither changes a part
  with `age` 0.

**Tried and taken out.**
- **Each part's own tone and broad swirls** across a face (older parts
  differ by batch; flow lines): renders 0.245 against 0.252 beside them,
  paired 19 of 20 at 0.839. It moved nothing.
- **The sun fade** ("a few parts faded much more than the rest"): it was
  never measured alone, and in a close-up of one part which way its number
  fell decided the shot: the red slope went to ΔE2000 5.7 from its
  photograph, past the tent's 5.

**Each part is one number.** A part with a print or a window is drawn in
one batch per surface (a printed head in two, a torso in four), and the
tracer numbered each batch's instance on its own: seating moved a print
apart from its part, and each surface wore its own way. The number is now
the part's place (`PathTracer._part_key`), the same for all its surfaces,
checked on a printed head, a torso and a window drawn in a window.

**The judges** (the same day; the solo three rounds of two trials, with the
photographs; f3 the final renders):

| | solo: renders called a photograph | solo: mean chance, per round | paired: found | paired: sure |
|---|---|---|---|---|
| photographs | 54 of 54 | 0.893 to 0.899 | | |
| photoreal3 (a7) | 0 of 60 | 0.116 to 0.137 | 18 of 20 (5g) | 0.859 (5g) |
| photoreal4 (f3) | 7 of 60 | 0.209 to 0.237 | 18 of 20 | 0.824 |

- **The solo bar is met.** Photoreal4's lowest round (0.209) is above
  photoreal3's highest (0.137); the rounds spread 0.021 and 0.028.
  Photoreal4's renders are called a photograph 7 times in 60, photoreal3's
  never.
- The gain is in the close-ups (0.165 to 0.285): the green plate 0.33 to
  0.71 (called a photograph 6 of 6), the 2x2s 0.12 to 0.33, the slope 0.24
  to 0.38. The sets rose a little (0.064 to 0.120: 6532 0.07 to 0.14, 6657
  0.10 to 0.14, 6660 0.04 to 0.16) and none is called a photograph.
- **One shot's number is a lottery.** f1, with each part numbered by its
  instance, had the black 2x4 at 0.78 (6 of 6 called a photograph: "small
  dust specks, fine scratches, tiny nicks"); f3, the same code with the
  parts numbered by place, has it at 0.09. Where the specks and scratches
  fall decided it. f1's renders came to 0.259 to 0.265 in all, f2's (with
  the fade) 0.215 to 0.233: a tree's mean over ten shots holds, a shot's
  does not.
- **The paired bar is not met**: 18 of 20 (both misses set 6512, a render
  beside a render) at 0.824, against at most 16 or 0.80. Beside its
  photograph every other shot is still found, sure 0.62 to 0.95; the
  three 2x2s fell most (0.83 to 0.70).
- **What both still name:** no wear (79 of the solo's render tells for
  photoreal4), uniform plastic across parts and faces (76), logos and
  studs (32) and the backdrop (30).

**Colour, gloss and time.** The tent's faces against their photographs:
green top 2.5, red top 2.9, blue top 0.8, the slope 1.8 (all within 5;
5g's 2.6, 2.6, 0.3, 1.6). The sets' whites (b* of their pale parts inside
the photograph's outline): 6532 7.8 against the photograph's 10.3 (a7
1.0), 6660 8.4 against 10.1 (a7 0.0); 6657 4.7 against 14.3. Highlights
and L* spreads are where 5g left them (the green top's spread 2.8 against
7.8). The car at Best, Product, 1280x720, 256 samples: 2.48, 2.53 and
2.55 s (the bar is 8.4 s).

**Pictures.** `bench/results/photoreal4-2026-11-22/side_by_side/`: one row
per shot, the photograph, photoreal3 (a7) and this (f3). The verdicts are
`solo_p2p3.json`, `solo_p3p4_f3.json` and `judge_f3.json` (f1 and f2 beside
them).

**What is left, in order:**
1. **Uniformity across a set's parts.** Real parts of one colour differ a
   little from each other in tone and gloss, by batch and by age; ours are
   one material. The first tell in the sets.
2. **The close-ups' backdrops** (leather, stone, desk), as 5g said.
3. **A top's broad sheen** and its shading across it (L* spread a third of
   the photographs').
4. **The paired judge** will find any staging left: 6660's B-pillar, the
   minifigs' printing on a small face, and 6512, which no render can pass.

## 5i. The judge's tells, one change at a time (photoreal5)

The owner's ask, 2026-11-22, continued. Each of the judge's tells got one
change, committed alone. A locked snapshot of the tree after each change
was drawn (`photoreal_probe`, 256 samples, seed 1), and all of them were
judged in one pool with photoreal4's final (f3) and the photographs: the
solo judge, three rounds of two trials (`solo_p5w1.json`). A change stayed
only if the tree's mean over all ten shots rose over the tree before it.

| tree | the change | solo, per round | close-ups | sets | called a photograph | kept |
|---|---|---|---|---|---|---|
| f3 | photoreal4's final, judged again today | 0.246 0.227 0.236 | 0.29-0.33 | 0.12-0.13 | 11 of 60 | |
| s1 | stud logos: tall, narrow letters slanted a fifth, as a real stud's; a half-millimetre gate | 0.242 0.245 0.227 | 0.30-0.32 | 0.11-0.13 | 8 of 60 | yes |
| s2 | a part resting on the floor is turned only about the vertical, never lifted | 0.231 0.215 0.230 | 0.29-0.31 | 0.11-0.12 | 5 of 60 | no |
| s3 | a dark hairline under each part: its sides' lowest 0.6 LDU darkened, their gloss gone | 0.240 0.257 0.255 | 0.32-0.34 | 0.12-0.14 | 11 of 60 | yes |
| s4 | the close-ups' surfaces: leather under the black 2x4, a stone counter under the green plate | 0.164 0.153 0.161 | 0.17-0.19 | 0.12-0.13 | 0 of 60 | no |
| s5 | wear with a shot's age: wider scratches over more of a part, edges rubbed matt | 0.174 0.165 0.179 | 0.18-0.20 | 0.13-0.14 | 1 of 60 | yes |
| s6 | an edge's rounding varies along it, 0.3 to 0.9 LDU | 0.155 0.157 0.164 | 0.16-0.17 | 0.14-0.16 | 0 of 60 | no |
| s7 | a matte desk's specks and smudges under the grey 1x3 | 0.222 0.234 0.241 | 0.28-0.30 | 0.13-0.15 | 9 of 60 | yes |

The photographs: 0.901 to 0.914, 54 of 54.

- **The logos.** Verdicts that called our logos mirrored or garbled fell
  from 11 (f3) to 4 (s1); the black 2x4's, upside down to the camera as in
  its photograph, is still read as "mirrored" (6 in s7). The tree's mean
  did not move (0.236 against 0.238), and the logo was kept for its tell.
- **Contact** cut "floating" from 17 verdicts to 13 but the tree fell
  (0.225 against 0.238), and was taken out.
- **Seams** rose 0.026 and were kept.
- **Leather and stone** were the largest fall: every verdict on the black
  called its floor a "procedural Voronoi" texture, and the plate's counter
  "flat procedural speckle" (the black 0.70 to 0.04, the plate 0.62 to
  0.26). Both were taken out. Our black's glossy sides mirrored the
  pattern, a second tell.
- **The desk** under the grey 1x3 took it from 0.10 to 0.68, and its
  "blotchy denoiser" mottle and "diagonal shadow wedge" left the verdicts:
  they were the paper's fine fibre mirrored in its glossy faces. The desk
  has no fine grain. Other shots on paper may gain from the same, untried.
- **Edges** with a rounding that varies fell 0.014 in every round, the
  close-ups most, and were taken out.
- **Wear** rose 0.014, the sets 0.01. It rides on a shot's age, which is 0
  in the app, so the app's plastic is unchanged.
- **One shot's number is still a lottery.** The red slope, which neither
  s4 nor s7 touched, went 0.21 to 0.24 at s4 and 0.24 to 0.48 at s7.
  Only changes of 0.05 or more in the tree's mean are clear; s1, s2, s5
  and s6 are inside that.

**The final tree** (logos, seams, wear and the desk; `solo_p5fin.json`,
judged the same day beside f3 and s7):

| | solo, per round | close-ups | sets | called a photograph | paired: found, sure |
|---|---|---|---|---|---|
| photoreal4 (f3) | 0.236 0.232 0.224 | 0.30-0.32 | 0.11-0.13 | 10 of 60 | 18 of 20, 0.824 (5h) |
| photoreal5 | 0.242 0.228 0.212 | 0.27-0.31 | 0.13-0.15 | 8 of 60 | 18 of 20, 0.831 |

- **The bars are not met.** The trees are not separated: the close-ups'
  lowest round (0.269) is under photoreal4's highest (0.310), the sets'
  (0.128) a hair under it (0.129). The paired judge's two misses are
  still only set 6512.
- Without the contact change the red slope fell to 0.18 (0.58 in s7), and
  verdicts naming no contact shadow or a floating part rose from 22 to
  29. Contact is the first tell to try again, judged on more than one
  draw of each tree.
- The tent's faces are where they were: 2.5, 2.9, 0.8, the slope 1.8.

**The car at Best** (Product, 1280x720, 256 samples), each snapshot's
median: 2.46, 2.53, 2.46, 2.58, 2.49, 2.71 and 2.36 s; the final tree
2.58 s.

**What is left, in order:**
1. **Contact**: "almost no contact shadow" is the commonest tell on the
   close-ups; the hairline under a part on white reads to some verdicts
   as a cut-out's outline.
2. **The black 2x4**: its plastic is a dull blue-grey where the
   photograph's mirrors the room (ΔE2000 39 on its top), and its logo
   reads as mirrored.
3. **Sets show no logo on their studs** at a set's distance; the
   photographs' do.
4. **Speckle**: the grain of 256 samples on dark faces, read as a path
   tracer's.
5. **Colour**: the red slope reads crimson beside its photograph's orange
   red, though its measured face is ΔE2000 1.8.

## 5j. The ceiling: Cycles on the same scenes, and what carries the gap (photoreal6)

The solo judge calls the photographs a photograph at about 0.90 and our
renders at 0.21 to 0.24 (5h, 5i). Two units tuned one tell at a time and
never moved the tree's mean much, against a gap of 0.65. So before building
again, this unit asked two things: how far a production path tracer gets
with the same geometry, and which factor carries the gap.

**The answer.** The renderer does not carry the gap:
- Cycles, with ldr_tools_blender's LEGO materials, drew our own scenes at
  0.19, against our tracer's 0.23.
- A real photograph keeps 0.85 even with its fine surface smoothed away
  (dust, scratches, texture, noise, JPEG).

What both renderers share is the staging: the light, the backdrop and its
shadow, and the exposure. The judge names the backdrop in 74 to 77 of 80
verdicts and the light in 70 to 75, in both renderers alike.

One factor moved the judge well beyond its noise: the camera's processing.
A camera's sharpening and the photograph's own JPEG took the close-ups from
0.29 to 0.40-0.43 in three pools. The sets did not move.

**The bench** (`tools/photoreal/cycles/`, the verify skill's `photoreal
cycles`). It is a tool on this box and never part of the app or its build.
- **Blender 5.2.4 LTS**, in `~/.local/opt/blender-5.2.4-linux-x64` (the
  official build, its sha256 checked). It is not bundled and not installed
  system-wide.
- **ldr_tools_blender 0.5.3** (MIT), in
  `~/.local/opt/ldr_tools_blender-0.5.3`. It needs Blender 5.1 or later.
- **Cycles runs on the CPU.** The RX 6700 XT's HIP needs `/dev/kfd`, which
  belongs to the `render` group, and this user is not in it.
- **One scene for both renderers.** `photoreal_probe -- --cycles` reads
  each shot back from the render it has just drawn. It writes the parts
  where they stood, seated as the tracer seats them, as flat LDraw. It
  writes the camera, lens, tent or place, key, sweep and the exposure the
  white card metered as JSON. `--draw=N` draws a tree again with the
  tracer's seed N.
- **`render.py`** imports the parts through ldr_tools_blender with its own
  materials: Cycles' subsurface (Burley), smudged gloss, a bevel, logo
  studs, 48-sided round primitives and a hair of gap between parts.
  - Colour: each colour takes the albedo our tracer draws it with, so the
    plastic is the same. ldr_tools' own table drew the black brick slate
    blue, because it uses #1B2A34 straight from LDConfig.
  - Light: the tracer's own tent formula as an environment, with its key
    as a sun of the same size and strength, or the same HDRI turned as the
    tracer turns it.
  - The sweep is a shadow catcher.
  - Sampling: 256 samples, adaptive at 0.01, with OpenImageDenoise.
    The brief asked for 1024. At the box's load of 50 to 140, a 1024-sample
    tree took over five hours, so the trees were drawn at 256. Our own
    tracer at 4096 samples scored as at 256 (below), so noise is not what
    the judge reads.
- **`finish.py`** draws the backdrop as the tracer's catcher draws it. Then
  it gives the picture the tracer's own finish: softness, the same
  exposure, vignette, linear saturation, camera_curve, sRGB and grain. So
  the two pictures differ only in how the light was drawn.
- **The photograph side** (`photo_trees.py`): each
  photograph as the judge is shown it, judged as a tree of its own. It is
  judged once as it is, as a control, and once through a 5-pixel median,
  which takes out what a render lacks and keeps the shapes, light and
  framing.

**The pools.** Each tree was drawn twice (seeds 1 and 2). Each was judged
solo (2 rounds of 2 trials a draw, so 80 verdicts a tree) in a pool with the
ten photographs, as `solo_<pool>.json` and `table_<pool>.md` in
`bench/results/photoreal6-2026-11-22/`. photoreal5's final tree (p5) is in
every pool. Across five pools it scored 0.227, 0.238, 0.226, 0.220 and
0.227, so the judge's noise on a two-draw tree is about ±0.01. Its
close-ups are 0.28 to 0.31 and its sets 0.13 to 0.14.

| tree | what differs from p5 | pool | mean | close-ups, per round | sets, per round | called a photograph |
|---|---|---|---|---|---|---|
| photographs | | p6main | 0.912 | 0.908 0.906 | 0.922 0.923 | 36 of 36 |
| p5 | photoreal5's final, our tracer, 256 samples | p6main | 0.227 | 0.302 0.273 | 0.139 0.136 | 10 of 80 |
| **cy** (the ceiling) | Cycles with ldr_tools' materials | p6main | **0.192** | 0.192 0.183 | 0.189 0.206 | 8 of 80 |
| p5clean | 4096 samples | p6main | 0.217 | 0.275 0.271 | 0.129 0.141 | 10 of 80 |
| p5camera | a camera's sharpening, then the photograph's JPEG | p6main | 0.295 | 0.427 0.400 | 0.119 0.114 | 19 of 80 |
| cycamera | cy, the same | p6main | 0.252 | 0.276 0.273 | 0.230 0.206 | 18 of 80 |
| p5camera | the same, again | p6camera | 0.293 | 0.404 0.406 | 0.128 0.124 | 20 of 80 |
| p5camera | the same, again | p6camparts | 0.264 | 0.360 0.367 | 0.110 0.119 | 14 of 80 |
| p5jpeg | the JPEG alone | p6camparts | 0.250 | 0.358 0.318 | 0.121 0.114 | 14 of 80 |
| p5sharp | the sharpening alone | p6camparts | 0.228 | 0.274 0.310 | 0.130 0.134 | 10 of 80 |
| photoasis | a photograph, judged as a tree (control) | p6photo | 0.818 | 0.891 0.905 | 0.696 0.699 | 36 of 40 |
| photosoft | the photograph through a 5-pixel median | p6photo | 0.768 | 0.844 0.848 | 0.650 0.655 | 36 of 40 |
| cy | the ceiling, again | p6sss1 | 0.171 | 0.184 0.184 | 0.153 0.147 | 4 of 80 |
| cynosss | Cycles with no subsurface (first draw) | p6sss1 | 0.157 | 0.206 0.178 | 0.100 0.109 | 3 of 40 |
| cy | the ceiling, again | p6geom | 0.172 | 0.180 0.183 | 0.154 0.160 | 5 of 80 |
| cyplaingeom | Cycles with plain studs, 16-sided primitives, no gap | p6geom | 0.119 | 0.120 0.108 | 0.125 0.127 | 0 of 80 |

The photograph side's sets include 6512, whose "photograph" is itself a
render (0.05). Without it, the three photographed sets are 0.92 as they
are and 0.86 smoothed.

**The factors, ranked** (each against p5 in its own pool):
1. **The camera's processing, +0.07** (+0.066, +0.026, +0.068 in three
   pools; Cycles +0.060). It all comes from the close-ups (+0.13, +0.05,
   +0.13); the sets lose 0.02. Neither half alone does it: the JPEG alone
   gives +0.01 and the sharpening alone -0.01. The judge reads "sharpening
   halos and JPEG blockiness" as a phone's picture.
2. **The fine surface, 0.05 of a photograph.** A photograph with its dust,
   scratches, plastic texture, sensor noise and JPEG blocks smoothed away
   drops from 0.90 to 0.85 (close-ups) and from 0.92 to 0.86 (sets). The
   judge names wear in 79 or 80 of every 80 render verdicts. Yet wear is
   not what makes a photograph a photograph: it is only the easiest
   difference to put into words.
3. **The renderer, -0.035.** Cycles scored under ours:
   - It gained on the sets (0.19-0.21 against 0.14), where its logo studs
     and rounder primitives show. 6660 rose from 0.17 to 0.46.
   - It lost on the close-ups, where its shadow catcher lost the contact
     shadow. "Floating" or no contact shadow is named in 48 of its 80
     verdicts, against 19 of ours. The grey 1x3's sky gave a blue shadow,
     which the judge read as a "blue-tinted shadow polygon".
   - Its logo tells were fewer (25 against 33) and its seam tells fewer
     (27 against 42).
4. **Noise, none.** 4096 samples scored 0.217 against 256's 0.227.
5. **Geometry, +0.05 inside Cycles.** Without its logo studs, 48-sided
   primitives and gap, Cycles fell from 0.172 to 0.119: close-ups by 0.07
   and sets by 0.03. Its logo tells rose from 22 to 58 of 80. Our tracer's
   bump-drawn logos are named in 33 to 40 of 80. So real logo geometry is
   the second lever, after the light.
6. **The plastic lit from inside, none.** Cycles without its subsurface
   scored 0.157 against its own 0.171 in one pool, on its first draw (the
   second was queued). The close-ups gained 0.01 and the sets lost 0.05,
   which is about the noise on a set mean.

Both Cycles swaps only rank what is inside a ceiling that is itself under
ours.

**What lies outside the renderer.** Both renderers stand at about 0.2 on
the same staging. A photograph keeps 0.85 without its fine surface. So the
gap is in what both were given:
- the light: the tent formula and its key, or the HDRI turned;
- the backdrop: a seamless sweep and its catcher's soft shadow;
- the exposure and tone.

The judge's tells after wear are exactly these. It names the backdrop in
74 to 77 of 80 verdicts ("featureless", "seamless", "idealised soft
shadow") and the light in 70 to 75 ("even studio lighting", "no real
falloff"), in both renderers alike. The brief's light factor, an HDRI
fitted per photograph, is the next measure. This unit did not draw it.

**The ceiling is under the bar.** Cycles itself scores 0.19, under
photoreal5's own trees. So no renderer swap meets photoreal5's bars:
- the close-ups' and sets' lowest rounds above photoreal5's highest;
- 15 of 60 called a photograph;
- logo tells under 5 of 60.

**Step 3: the camera's processing, built into our renderer.** The
product look's camera gets two settings of its own, as it has grain and
vignette (RenderSettings `sharpen`, `jpeg`):
- `sharpen` is an unsharp mask after the curve, in the resolve shader: a
  Gaussian 1.2 pixels wide over the samples' own mean, with a two-level
  threshold.
- `jpeg` sends the finished picture through Godot's JPEG at that quality
  and back (StudioRender._through_jpeg), on a worker.

Both are on Best only. Compatibility gets neither, because its picture
never passes the tracer's resolve. The Product look's own values are none
(PRODUCT_SHARPEN, PRODUCT_JPEG 0), so a render outside the bench is
unchanged and the car's time is untouched. Whether the Product look should
process its pictures by default is the owner's call: it would put a JPEG's
blocks into every Best picture.

The first draw put each shot through its photograph's own processing:
sharpen 0.6, then JPEG 90 for the close-ups and 75 for the sets (6512 none).
Drawn twice from p6snap2 and judged beside p5 and the same processing
applied afterwards (`table_p6step3.md`):

| tree | mean | close-ups, per round | sets, per round | called a photograph |
|---|---|---|---|---|
| p5 | 0.227 | 0.284 0.293 | 0.131 0.138 | 9 of 80 |
| p5built (the processing, drawn by our renderer) | 0.260 | 0.367 0.359 | 0.107 0.104 | 16 of 80 |
| p5camera (the same, applied afterwards) | 0.253 | 0.334 0.347 | 0.125 0.116 | 12 of 80 |

Built in, the processing does what it did as a pass afterwards. The
close-ups rose by 0.07, and their lowest round (0.359) is above
photoreal5's highest (0.31). The sets fell by 0.03, as they did in every
pool. So it is kept only where it moved: the close-ups' shots carry it, and
the sets' have none (`shots.json`).

Judged again as kept, two draws from p6snap2 (`table_p6final.md`):

| tree | mean | close-ups, per round | sets, per round | called a photograph |
|---|---|---|---|---|
| p5 | 0.229 | 0.264 0.310 | 0.136 0.149 | 8 of 80 |
| p5kept | 0.265 | 0.354 0.370 | 0.117 0.121 | 15 of 80 |

Some checks on what was kept:
- **Unprocessed shots are untouched.** p5kept's set pictures are
  pixel-identical to p5's. So with no processing asked for, the code and
  the pre261 merge draw exactly what photoreal5 drew.
- **The judge's noise.** Those identical set pictures still scored 0.142
  in one tree and 0.119 in the other. So the judge's noise on a set mean
  is about 0.02. The sets' falls with the processing (0.02 to 0.03) are
  at that noise: no gain, rather than a loss.
- **Against photoreal5's bars:**

| bar | photoreal6 (kept) | met |
|---|---|---|
| close-ups' lowest round above photoreal5's highest (0.31) | 0.354 | yes |
| sets' lowest round above photoreal5's highest (0.15) | 0.117 (pictures unchanged) | no |
| at least 15 of 60 called a photograph | 15 of 80 (11 of 60) | no |
| logo tell under 5 of 60 | 36 of 80 | no |
| paired judge at most 16 of 20, or sure at most 0.80 | 19 of 20, 0.836 (p6cam_d1) | no |
| tent faces within ΔE2000 5 | green 2.5, red 3.0, blue 0.8, slope 2.0 | yes |
| the car at Best no slower than 2.9 s | 2.70 and 3.02 s, against photoreal5's 3.10 and 3.15 at the same moments | yes, against photoreal5 at the same load |
| the model unchanged | no processing by default; unprocessed pictures pixel-identical | yes |

**The car.** It asks for no processing, so its time cannot move. Timed in
turn at load 57 to 77, as the probe's median of three:
- before (p6snap1, photoreal5's code): 3.10, then 3.15 s;
- after (p6snap2): 2.70, then 3.02 s.

At that load photoreal5's own code is over 2.9 s too.

**The probes**, from p6snap2, all passed: photoreal (11), product_render
(18), pathtrace (20), lights (102), render (41), edges (25), lineart (36)
and motions_render (33). `tools/check.sh --lists`, `site_lang --check`
and `featuremap check` passed. ci_gate's suite failed only on the docs
site's list, which now names the Cycles bench as internal. pre261 moved by
95 commits after p6snap2, so it was merged again (7bcbdbd60, none of them
touching the tracer or the bench). ci_gate passed on that merge. The eight
probes were queued again on it (p6snap3), with the unit's report.

**Running it.** On 2026-11-22 the box held up to 75 brickworks jobs in
heavy's queue, at load 50 to 140. This unit's runs went through two slot
servers in its scratch, one command file at a time. Each tree's pictures
are in `shots/photoreal/<tag>/` of the snapshot worktrees:
- p6snap1 (10854b3a0) holds p6_d1/d2 (p5), c_d1/d2 (cy), cns/cg (the Cycles
  swaps), p6c (p5clean), p6j/p6s/p6q (camera, sharpening, JPEG), cj
  (cycamera) and photoasis/photosoft.
- p6snap2 (599e7ad87) holds step 3's p6cam_d1/d2.

## 5k. Staged as photographs are: the light, the surface, the camera (photoreal7)

photoreal6 found the gap was the staging, not the renderer: Cycles on the
same scenes scored no better. Its judge's reasons were the backdrop
("featureless", "a CG void") and the light ("no falloff", "evenly lit").
Both come from how a picture was staged. The tent's lights sit at
infinity, and the sweep is a shadow catcher drawn flat at its own colour.

A product photograph's light stands near the model. So photoreal7 builds a
**stage**, a choice the app offers (`RenderSettings.stage`, Render's
Background, `StudioRender.STAGES`). It is not a backdrop tuned to one
shot. Each stage has:
- **A near key.** A soft box near the model, a ball in the tracer
  (`scene.near`), sampled once per bounce with its shadow. Its light falls
  off with the square of the distance and across its face (a cosine
  power, `near_aim.w`). The side nearer it is lighter, and the floor
  darkens away from it. It is turned as the rig's key is, raised
  `STAGE_KEY_RISE` degrees, `STAGE_KEY_FAR` model radii away, and gives
  the middle `STAGE_KEY_SHARE` of the tent's key.
- **A surface lit as any surface is.** It is not a shadow catcher
  (`stage.x`), except **Photographed on white**, which keeps the catcher.
  Paper gets its fibres, a desk its specks. A wooden table, a leather desk
  pad and terrazzo get a photographed tile at its real size: Poly Haven's
  CC0 diffuse maps in `assets/surfaces/`, binding 11, with each one's
  displacement map in alpha. That height tilts the floor's normal
  (`stage_relief`), so leather's pebbles catch the key. Each has its own
  roughness, so wood and terrazzo carry a sheen. A table runs on behind
  the model as far as in front, so its far edge is seen only at the
  horizon, and past it is the room: the lighting's HDRI, or the window's.
- **The camera.** The white card where the model stands is still metered
  for exposure (`_meter_card`, at the 60th percentile on a textured
  stage). Its colour is read too (`_floor_colour`; the card is drawn
  white, so this is the light's colour, not the surface's), for a white
  balance (`balance`, the share of the card's cast taken out). A camera's
  tone curve (`tone`) bends the encoded picture by an S through 0, a half
  and 1, in the resolve (`camera_tone`). Both apply to every photographic
  product picture, staged or not (`PRODUCT_TONE` 0.5, `PRODUCT_BALANCE` 1).

With no stage and tone and balance 0, every new buffer field is zero or one
and no random number is drawn, so a render is pixel-identical to
photoreal6's. Only Best on the desktop draws a stage, a tone curve or a
white balance. Compatibility and the web draw a stage's colour alone, and
the web export leaves `assets/surfaces/` out.

**What the judge said.** Seven trees, two draws each, judged solo (two
rounds of two trials, the photographs in the pool) in three runs, each run
with photoreal6's kept tree (p6) beside them:

- **A**: the stages (paper, desk, leather, white) with each shot's own
  fitted key.
- **B**: A with the camera (tone 0.5, balance 1).
- **C**: B with the camera's finish (sharpen 0.6, JPEG 90) on the sets too.
- **D**: photoreal6's staging with the tone curve alone.
- **E**: photoreal6's staging with the tone curve and white balance.
- **F**: E with LDraw's raised logo (`p/logo5.dat`) baked into a height map
  in place of the drawn strokes (4076cfbd9, taken out at c16955560).

| run | tree | close-ups, per round | sets, per round | called a photograph |
|---|---|---|---|---|
| 1 | p6 | 0.363 0.323 | 0.131 0.136 | 13 of 80 |
| 1 | A | 0.326 0.323 | 0.131 0.133 | 12 of 80 |
| 1 | B | 0.366 0.355 | 0.121 0.118 | 16 of 80 |
| 1 | C | 0.395 0.365 | 0.116 0.119 | 18 of 80 |
| 2 | p6 | 0.340 0.310 | 0.141 0.144 | 11 of 80 |
| 2 | B | 0.368 0.375 | 0.123 0.131 | 16 of 80 |
| 2 | D | 0.341 0.335 | 0.151 0.147 | 15 of 80 |
| 2 | E | 0.344 0.379 | 0.136 0.161 | 15 of 80 |
| 3 | p6 | 0.327 0.343 | 0.145 0.134 | 12 of 80 |
| 3 | E | 0.360 0.363 | 0.140 0.158 | 16 of 80 |
| 3 | F | 0.335 0.331 | 0.139 0.156 | 16 of 80 |

- **The judge's noise.** B's and C's close-ups were the same pictures, byte
  for byte, and scored 0.366 and 0.355 in one tree, 0.395 and 0.365 in the
  other. So a close-up round moves about 0.03 by the judge alone.
- **The light and the surface (A) did not gain.** Close-ups fell 0.02 and
  the sets held. Per shot it went both ways: the grey 1x3 on the desk rose
  from 0.31 to 0.47, and the red slope on white fell from 0.47 to 0.23 (the
  judge: "almost no contact shadow, the brick appears to float"). The
  black 2x4 on leather fell from 0.21 to 0.09. On paper the sets drew a
  horizon where the photographs' sweep has none ("a visible floor/backdrop
  horizon line"). So a stage stays a choice and is not the default. The
  bench's shots ask for none. Its key keeps the fitted rule (below).
- **The camera gained, in every run.** The tone curve and white balance
  lifted the close-ups over the same tree without them: B over A by 0.036
  (run 1), E over p6 by 0.037 (run 2) and 0.027 (run 3). In runs 2 and 3,
  E's lowest close-up round is above p6's highest. They cost the sets
  nothing: E's sets are 0.006 and 0.009 above p6's. The red slope rose
  from 0.44 to 0.47 without them to 0.64 to 0.68 with them, in all five
  toned trees. The tone curve alone (D) gained 0.013, within the noise.
  So both are the product look's own (`PRODUCT_TONE` 0.5,
  `PRODUCT_BALANCE` 1). The tent's faces stayed within ΔE2000 2.7 of their
  photographs (E: green 2.7, red 1.6, blue 2.6, the slope 2.1).
- **The camera's finish stays off (step 5).** On the sets (C over B) it
  moved them by 0.002. photoreal6 found no gain on the close-ups either.
  So `PRODUCT_SHARPEN` and `PRODUCT_JPEG` stay 0: no gain, so no default.
- **The logo (step 4) was not the letters' shapes.** LDraw's own raised
  letters, judged beside the same tree with the drawn strokes, scored the
  close-ups 0.025 to 0.03 lower in both rounds. The judge named the logos
  in 44 verdicts of 80 against 40. Its words were the same: "identical on
  every stud", "mirrored", "rotated inconsistently". So the bake was taken
  out. What gives the logo away is that every stud's is the same, and the
  angle it is seen at, not the letters' outlines.

**The fitted key (step 1).** For each shot, the staged key was turned
round the model (8 ways), raised (15, 40, 65 degrees), moved (2.5 or 6
radii) and brightened (half, 1 or 2 times the tent's key): 96 small draws
each, scored against the photograph by `tools/photoreal/fit_light.py`
(the correlation of their logged lightness, blurred a little):

| shot | turn | rise | far | share | score |
|---|---|---|---|---|---|
| black_2x4 | 225 | 40 | 2.5 | 2 | 0.746 |
| red_slope_2x4 | 0 | 40 | 2.5 | 2 | 0.962 |
| grey_1x3 | 225 | 65 | 6 | 0.5 | 0.945 |
| trans_round_1x1 | 270 | 40 | 6 | 2 | 0.751 |
| three_2x2_top | 90 | 15 | 2.5 | 0.5 | 0.979 |
| green_plate_macro | 270 | 15 | 6 | 2 | 0.486 |
| set_6512 | 135 | 15 | 2.5 | 2 | 0.832 |
| set_6532 | 90 | 65 | 2.5 | 2 | 0.822 |
| set_6657 | 225 | 65 | 6 | 0.5 | 0.928 |
| set_6660 | 270 | 40 | 6 | 0.5 | 0.929 |

The rule is the median of each: rise 40 degrees, 4 radii away (4.25), at
twice the tent's key (`STAGE_KEY_RISE`, `STAGE_KEY_FAR`,
`STAGE_KEY_SHARE`). The turn is the rig's, as before: where a photograph's
key stood depends on the shot, not on a rule.

**Against the brief's bars** (the kept tree is E: photoreal6's staging
with the product look's own tone and white balance):

| bar | photoreal7 (kept) | met |
|---|---|---|
| close-ups' lowest round above photoreal6's highest | 0.344 over 0.340 (run 2), 0.360 over 0.343 (run 3) | yes, in both runs |
| sets' lowest round above photoreal6's highest | 0.136 under 0.144, 0.140 under 0.145 (the means 0.006 and 0.009 above) | no |
| at least 15 of 60 called a photograph | 15 and 16 of 80 (of 72 with a photograph) | no |
| logo tell under 5 of 60 | 39 and 40 of 80; LDraw's letters 44 | no |
| paired judge at most 16 of 20, or sure at most 0.80 | 18 of 20, 0.837 (p7e_d1; photoreal6's 19, 0.836) | no |
| tent faces within ΔE2000 5 | green 2.7, red 1.6, blue 2.6, slope 2.1 | yes |
| the car at Best no slower than 2.9 s | 2.32 and 2.56 s, against the unit's base 2.35 and 2.75 at the same moments (in turn, load 50 to 62) | yes |
| the model unchanged | a render reads the model and writes nothing to it | yes |
| unprocessed pictures of the old staging pixel-identical when no stage is chosen | 10 of 10 byte for byte against photoreal6's draw 1, with tone and balance 0, at the final code | yes |

The judge's tells for the kept tree, in 80 verdicts: wear 80 ("perfectly
clean, uniform plastic with no yellowing or scuffs"), backdrop 76, light
70, edges 56, speckle 51, logos 40. The next lever is wear: a set's parts
yellowed and scuffed unevenly, part by part, and a stud's logo that
differs from the next.

## 5l. No two parts alike (photoreal8)

photoreal7's judge named our sameness in nearly every verdict: "perfectly
uniform yellow with no variation from piece to piece", "every stud is
identical", "the three bricks line up exactly". A real model's parts come
from different batches, have been handled differently, and sit as the
moulds' tolerance lets them. photoreal8 draws that, part by part, and only in the
picture. The model and its file are never changed. Each variation is
seeded by the part's place (`PathTracer._part_key`), so the same model
renders the same every time.

**Measured on the photographs first.** These are the targets, and a lever
may show no more than they do:
- **Colour.** Between neighbouring parts of one colour facing one way
  (`face_lab`, the lightest and darkest fifths of a box left out), the
  CIEDE2000 is 2.1 (6532's yellows), 3.2 and 4.2 (6660's and 6657's reds),
  and 2.6 and 4.2 (6660's whites). Hue and chroma are 1.0 to 2.6 of it.
  photoreal7's renders differ by 0.8 and 1.1 between reds: one colour,
  one batch. Their whites already differ by more than the photographs'
  (3.5 and 8.6), from photoreal4's yellowing, which is each part's own.
- **Gloss and wear.** Across one face of each of six white parts on
  6660's side, the lightness's spread is 0.2 to 3.8 on five and 15 on the
  sixth (scuffed and specked). The render's are 0.4 to 3.2.
- **The seat.** Seen from above (three_2x2_top), the photograph's three
  bricks are square to each other within 0.01 degrees, 0.13 to 0.17 LDU
  off line across, and 0.39 and 0.60 LDU apart. photoreal4's seating
  turned ours 0.36 degrees apart and slid them 0.05.

**The levers.** Each is a `RenderSettings` value (below 0, the product
look's own, `StudioRender.PRODUCT_*`), drawn only where Best is path
traced, in the Product look:
- **batch** (path_tracer.glsl `batch_of`): a part's colour turned in
  Oklab, so a stray is as far to the eye in every colour. At 1 its hue
  turns by up to 4 degrees, its chroma by up to 8 percent and its light by
  up to 12 (a pale part's 4, since its age already strays it), each by a
  bell held within 1 sd (`batch_bell`). Two of 6657's reds then differ by
  2.4, against its photograph's 4.2.
- **handling** (`handled_of`, `print_of`): a part's polish its own (20
  percent, sd), dulled and scuffed the more the part has been handled
  (most parts a little, a few a lot: the square of its own number). The
  most handled third show a fingertip's print in what they mirror, 12 by
  15 mm on one of its sides, in ridges half a millimetre apart. Only the
  faces a hand touches, never an underside.
- **studs** (closest hit `stud_logo`, raygen's stud top): each stud's logo
  its own depth and softness, some with grime where the letters meet the
  top, and each stud's top its own sheen. The amount goes to the closest
  hit in the instance's fourth word (`info.w`, 0 to 255).
- **play** (`PathTracer._seated`): photoreal4's seating as the photograph
  measures it. A part's turn about the vertical is `PLAY_TURN` (0.15) of
  the seating's, and its slide across `PLAY_SHIFT` (1.5) times it. Drawn,
  the three bricks are square to each other within 0.12 degrees and one
  stands 0.16 LDU off line.

Two first tries were wrong, and the pictures said so before the judge did.
The batch first turned the hue in linear RGB, and moved a red part 0.1 to
0.4 in the picture: a saturated red is drawn with its green and blue at 0,
so only its light can carry a stray. Handling first only dulled the polish
a little, and changed no face's spread on the trucks.

With all four at 0, every new buffer field is zero and no new random number
is drawn, so a render is pixel-identical to photoreal7's: 10 of 10 shots
byte for byte from every code snapshot the unit drew, the last at 447c372fb.
Compatibility and the web draw none of them. They have no path tracer, and
a part's colour there is its colour.

**What the judge said.** Solo, two draws each, two rounds of two trials,
the photographs in the pool, in three runs, each with photoreal7's kept
tree (base) beside them:

| run | tree | close-ups, per round | sets, per round | called a photograph |
|---|---|---|---|---|
| 1 | base | 0.313 0.324 | 0.156 0.152 | 15 of 80 |
| 1 | batch, first stray | 0.347 0.314 | 0.156 0.151 | 15 of 80 |
| 1 | batch, twice that | 0.420 0.416 | 0.154 0.166 | 20 of 80 |
| 1 | handling | 0.295 0.293 | 0.170 0.175 | 13 of 80 |
| 1 | studs | 0.377 0.379 | 0.138 0.141 | 20 of 80 |
| 1 | play | 0.360 0.348 | 0.160 0.146 | 19 of 80 |
| 1 | all four (batch's first stray) | 0.335 0.331 | 0.174 0.174 | 16 of 80 |
| 2 | base | 0.360 0.336 | 0.154 0.151 | 16 of 80 |
| 2 | batch twice, studs, play | 0.379 0.400 | 0.158 0.158 | 18 of 80 |
| 2 | that and handling 0.5 | 0.318 0.292 | 0.170 0.168 | 11 of 80 |
| 3 | base | 0.348 0.337 | 0.160 0.169 | 17 of 80 |
| 3 | kept, its bells held within 1.5 sd | 0.379 0.357 | 0.163 0.159 | 17 of 80 |
| 3 | **kept, its bells held within 1 sd** | **0.392 0.373** | **0.174 0.191** | **19 of 80** |

- **The judge's level moves between runs.** The same base pictures scored
  0.313 and 0.324 on the close-ups in run 1, 0.360 and 0.336 in run 2. So
  a tree is compared only with the base judged beside it.
- **batch, studs and play each gained.** Over the base in run 1, the batch
  at twice its first stray lifted the close-ups by 0.10 (the black 2x4 from
  0.17 to 0.47), the studs by 0.06 and the play by 0.035. The first stray
  was within the noise. So the batch's stray was doubled, and all three are
  the product look's own (`PRODUCT_BATCH`, `PRODUCT_STUDS`, `PRODUCT_PLAY`
  1).
- **Handling lowered the close-ups and lifted the sets, in both runs.**
  A close-up is one part. When that part is a handled one, its scuffs are
  "spread evenly like a procedural texture" (the black 2x4 fell from 0.17
  to 0.07). Among many parts of a set, a few handled ones read as real
  (6660 rose from 0.17 to 0.24). It gained on neither at once, so
  `PRODUCT_HANDLING` stays 0. Next for it: scuffs gathered where a hand
  holds a part, not spread over every face.
- **Held within 1 sd.** Unheld, the batch drew three_2x2_top's green
  brick 5.9 from its photograph's colour (2.7 with no stray), past the
  tent's bar of 5, and held within 1.5 sd still 5.2. A batch that far off
  never leaves the factory, so each of its bells is held within 1 sd
  (`batch_bell`): the green is 3.7. Held so, the kept tree lifted the
  close-ups by 0.040 and the sets by 0.018 over the base beside it (run 3),
  its lowest round above the base's highest in both.

**Against the brief's bars** (the kept tree is batch, studs and play at 1,
the batch's bells held):

| bar | photoreal8 (kept) | met |
|---|---|---|
| close-ups' lowest round above photoreal7's highest | 0.373 over 0.348 (run 3; run 2, before the hold, 0.379 over 0.360) | yes |
| sets' lowest round above photoreal7's highest | 0.174 over 0.169 (run 3; run 2 0.158 over 0.154) | yes |
| at least 15 of 60 called a photograph | 19 of 80 (of 72 with a photograph; the base 17) | yes |
| the wear or uniform tell under 40 of 80 | wear 76 of 80 (the base 78), "uniform" 67 (the base 75): the backdrop, the light and the edges are called uniform as often as the plastic | no |
| paired judge at most 16 of 20, or sure at most 0.80 | 20 of 20, sure 0.844 (photoreal7's 18 of 20, 0.837) | no |
| tent faces within ΔE2000 5 | green 3.7, red 1.6, blue 2.7, the slope 1.3 | yes |
| the car at Best no slower than 2.9 s, or than photoreal7 in turn | medians 2.06, 2.18, 2.39 and 2.29 s at load 26, against photoreal7's 2.06, 2.21, 2.06 and 2.00 in turn (ABBA twice): under 2.9 s, and about 0.15 s (7 percent) slower than the base. At load 80 both pass 2.9: 3.07 and 2.85 against the base's 2.96 and 2.71 at load 60 to 73 | under 2.9 s, yes; as fast as the base in turn, no |
| the model unchanged | the levers act in `PathTracer.stage` and the shader; the bench's models are unchanged after every draw (git status) | yes |
| pixel-identical with the variation off | 10 of 10 byte for byte against photoreal7's tree, all four at 0, at 447c372fb | yes |

The judge's tells for the kept tree, in 80 verdicts (run 3, the base's in
brackets): wear 76 (78), backdrop 74 (74), light 69 (71), logos 44 (44),
edges 44 (49), speckle 40 (49), plastic 33 (46), floating 13 (18). The
paired judge still names "identical studs with no gate marks", "garbled,
overlapping LEGO lettering", "minifig head has no printed face" (6660) and
"perfectly uniform, spotless plastic". The face is there: in our 6660 the
driver sits higher than in the photograph, so the cap stands through the
roof's glass and the face is hidden behind its edge. The next
levers: a stud's gate mark and its logo's lettering, handling's scuffs
gathered where a hand holds a part, and 6660's driver seated as built.

## 5m. Where hands leave their marks (photoreal9)

photoreal8's judge still named the same things: no wear, the backdrop, the
light, the stud lettering ("garbled, overlapping", "mirrored") and, on 6660,
a driver with no face. photoreal9 measured the photographs for each, built
what they show as render-only levers, and judged each alone and together.

**Measured on the photographs first** (each picture's backdrop outside the
model's mask, in CIELAB, against photoreal8's kept draw):
- **The tables.** The close-ups' surfaces vary by 12 L* (the leather), 11.7
  (the desk) and 18 (the stone) across the frame; ours by 9, 2.4 and 3. The
  desk falls 6.4 L* darker from right to left; ours by 0.2. The leather's
  grain is 3.5 near the camera and 0.9 far off (a shallow depth of field);
  ours is 0.2 at both.
- **The shade.** Under the two white-backdrop sets (6532, 6660) the shade is
  3 to 4 b* bluer than the lit white (b* -4.2 and -3.2); ours is 2.8 and 1.4
  yellower. Under the close-ups on white it is within 1 of ours.
- **Wear.** Of the close-ups, only the black 2x4 is handled: pale scuffs
  along its top's edges and specks. The rest are clean.
- **Studs.** The photographs' letters read as single raised strokes. Ours
  read as outlined strokes, which the judge calls garbled. three_2x2_top shows
  a gate mark on 2 of its 12 studs.
- **6660's driver.** The set's car base (4212b) has a 2 x 2 open centre,
  and the driver sits in it, his face turned to the camera. Ours sat on the
  base's studs, 20 LDU higher, with his cap 9 LDU up through the roof's
  glass and his face hidden.

**The levers.** Each is drawn only where Best is path traced, in the
Product look, and is seeded by the part's place. The model and its file are
never changed.
- **rubbed** (`RenderSettings.rubbed`, path_tracer.glsl `gathered_wear`):
  handled wear where hands and stacking touch a part, not spread over every
  face. Patchy scuffs, matt and a little paler, within half a millimetre of
  the body's edges, most near its top. Hairline scratches across that band.
  Each stud's top rim rubbed and its wall streaked up and down. Dust in the
  corner at each stud's foot. Every part gets some, and some get more (its
  own number). Kept as a lever, 0 unless asked (below).
- **Letters, tried and taken out.** Each stud's letters were moulded crisp
  (a flank a tenth of an LDU, so a stroke is one stroke), with rough, pale
  tops and the gate mark wider. Two versions were judged in two pools, and
  both lowered the close-ups, by 0.04 and 0.035. three_2x2_top lost its
  "garbled LEG0" tell, but the black 2x4 fell from 0.38 to 0.18 ("stud logos
  look like a flat texture", "printed flat, not raised").
- **The room's walls, tried and taken out.** The tent's walls were made
  bluer than its lamps. The shadow catcher's shade moved by 1 b*, even with
  walls far bluer than any room's, because the shade is lit mostly by the
  lights the walls do not colour. The photographs' gap is 6 to 7.
- **The stage, not built.** The leather at 750 LDU drew as speckled sand,
  since it is a colour with no relief. The terrazzo's chips came out pink
  against the photograph's grey stone. On grey_1x3, no aperture from f/4 to
  f/16 blurred the desk as the photograph does without also blurring the
  brick's far end (`measure9`'s near and far grain).

**Off is the old picture exactly: two versions of the shader.** A shader
with the levers compiled in but all at 0 moved 20,000 pixels of
three_2x2_top by up to 11 levels. The compiler orders and fuses the arithmetic
differently once there is more code, and the closest hit's added code alone
was enough to do it. So `path_tracer.glsl` has `#[versions]`. "plain" is
photoreal8's code, byte for byte, and "marks" adds the levers under
`#ifdef MARKS`. `PathTracer` makes the marks pipeline only when a picture
asks for wear (`marked`, `_make_marked`). Its hit table's range is the
plain one's, so the staged instances find their hit group in either. With
rubbed at 0, 20 of 20 pictures (10 shots, both seeds) match photoreal8's
kept draws byte for byte, at 13eb4a8fa plus this change.

**What the judge said.** Solo, two draws each, two rounds of two trials,
the photographs in the pool, photoreal8's kept draws (base) in every pool:

| pool | tree | close-ups, per round | sets, per round | called a photograph |
|---|---|---|---|---|
| 1 | base | 0.434 0.397 | 0.151 0.152 | 21 of 80 |
| 1 | letters | 0.367 0.383 | 0.157 0.170 | 20 of 80 |
| 1 | rubbed | 0.406 0.403 | 0.184 0.166 | 21 of 80 |
| 1 | driver seated | 0.411 0.404 | 0.154 0.161 | 22 of 80 |
| 1 | all three | 0.338 0.360 | 0.161 0.170 | 16 of 80 |
| 2 | base | 0.365 0.388 | 0.164 0.159 | 19 of 80 |
| 2 | letters as high as photoreal8's | 0.340 0.343 | 0.173 0.167 | 16 of 80 |
| 2 | rubbed, driver seated | **0.448 0.448** | 0.154 0.149 | **24 of 80** |
| 2 | all three | 0.400 0.390 | 0.153 0.144 | 20 of 80 |
| 3 | base | 0.386 0.362 | 0.194 0.191 | 20 of 80 |
| 3 | rubbed, driver seated | 0.394 0.370 | 0.139 0.138 | 18 of 80 |
| 4 | base | 0.338 0.331 | 0.160 0.165 | 13 of 80 |
| 4 | rubbed, driver seated | 0.364 0.364 | 0.147 0.138 | 18 of 80 |
| 4 | that, his head turned | 0.376 0.403 | 0.148 0.138 | 18 of 80 |

- **The wear lifted the close-ups by 0.025 on the mean of four pools,
  within the judge's noise.** It was beyond the noise in pool 2 only. It
  lifted the black 2x4, whose photograph is handled, in all four pools (0.38
  to 0.46, 0.18 to 0.72, 0.19 to 0.44, 0.24 to 0.41). It lowered the grey
  1x3, whose photograph is clean, in all four ("uniform blotchy noise on the
  faces"). It moved the sets by -0.015 on the mean. So `PRODUCT_RUBBED`
  stays 0, and the wear is drawn only when asked for, as photoreal8's
  handling is.
- **A picture alone moves 0.1 to 0.2 between pools.** The base's identical
  black 2x4 scored 0.38, 0.18, 0.19 and 0.24, and its 6660 scored 0.18,
  0.23, 0.32 and 0.21. Pool 4's two kept trees differ only in 6660, yet
  their close-ups differ by 0.03. Only a tree judged beside its base, over
  many pools, says anything.
- **The driver is seated as built** (tools/photoreal/models/set_6660.mpd).
  He sits in the base's open centre, his cap 3 LDU under the roof's glass,
  his head and cap turned 55 degrees to the camera as the photograph shows
  his face. 6660 scored 0.02 to 0.18 below the base in each pool, inside
  that shot's own spread. The tells are the same as before ("no LEGO logo
  on the studs", spotless plastic, the white void). The model is the set's
  bench model, so it is kept as the set is built.

**Against the brief's bars** (the kept tree: photoreal8's look, the wear
lever off, 6660's driver seated):

| bar | photoreal9 | met |
|---|---|---|
| close-ups' lowest round above photoreal8's highest (0.392) | the wear and driver: 0.448 in pool 2, 0.370, 0.364 in pools 3 and 4 | no |
| sets' lowest round above photoreal8's highest (0.191) | 0.138 to 0.184 | no |
| at least 24 of 80 called a photograph | 24 (pool 2), then 18 and 18 | once |
| the backdrop tell under 50 of 80, the light tell under 50 | backdrop 75 to 78, light 61 to 68 | no |
| the wear tell under 60 of 80 | 75 to 80 | no |
| paired judge at most 18 of 20, or sure at most 0.80 | 18 of 20, sure 0.82 (the kept tree, its close-ups photoreal8's own pictures; with the wear on 18 of 20, 0.83; photoreal8 was judged 20 of 20) | yes, within the paired judge's own noise |
| tent faces within ΔE2000 5 | green 3.7, red 1.6, blue 2.7, the slope 1.3 (the levers on and off alike) | yes |
| the car at Best within 2.9 s | medians 2.80 and 2.85 s with the wear on, at load 60 (off by default: the plain pipeline, as photoreal8) | yes |
| the model unchanged | the levers act in the shader; the bench's 6660 model is corrected, as the brief asked | yes |
| pixel-identical with every lever off | 20 of 20 byte for byte | yes |

**Desktop, Compatibility and the web.** All of it is drawn by the desktop's
path tracer at Best. Compatibility and the web draw none of it, since they
have no path tracer. The web could have the wear cheaply. `gathered_wear`
needs only a hit's place in its part's box, which the raster's product
material can have from the instance's box. The edge band and the dust ring
would then be a roughness and albedo change in that shader, at about the
cost of its existing edge highlight.

**Next.** The judge's three tells are unchanged on every tree: the white
void ("seamless pure white background"), the light, and spotless plastic.
For the sets, it also says the studs have no LEGO logo. At a set's
distance the letters' relief is under a pixel, so a stud there needs its
logo drawn as the eye resolves it, not as geometry. The tables need relief,
not colour: leather's cells and stone's grain shaded by a normal from the
surface's own texture. The wear on light colours reads as noise: its scuffs
should follow the edge, not a 3D noise.

## 5n. The stage matched to the photographs by measure (photoreal10)

photoreal9 measured what each photograph's stage shows and found the
render's tables flat, its desk evenly lit and its shade yellower than the
photographs'. photoreal10 built each as a lever and tuned it until the
render's own measure was within 20% of the photograph's (within 1 b* for the
shade), before any judge was asked.

**The measure.** `tools/photoreal/stage_measure.py` is photoreal9's
measure9: the backdrop outside the model's outline, in CIELAB. One fix,
`--frame-fix`: the outline seeds the whole frame edge as backdrop, so where
the render's frame cuts the model (6532's yellow front) 40 yellow pixels at
b* +64 were counted in the shade's core and moved its b* by +3. With the fix
the photographs' numbers stay as they were, except where a photograph's own
frame cuts a part (green_plate_macro's core).

**The levers.** Each is drawn only where Best is path traced, in the
Product look, on a backdrop, and is seeded by the place. The model and its
file are never changed. Each is 0 unless asked
(`StudioRender.PRODUCT_TABLE`, `_TABLE_LIGHT`, `_FILL`).
- **table** (`RenderSettings.table`, with `surface` 1 a desk, 2 a leather
  pad, 3 a stone counter): the table's own relief and colour
  (`table_height`, `table_normal`, `table_paper`). The leather has domed cells
  about 1.5 mm across with thin creases between them. The stone has grains a
  few tenths of a millimetre across over a mottle. The desk has an orange
  peel and broad blotches. The relief's normal is in the denoiser's guide;
  without it the filter smoothed the relief away.
- **table_light** (the model's radii): the light falls off across the table
  from a lamp that stands near it, toward the staged key, by the inverse
  cube of the distance (`table_falloff`). A photograph's desk is never lit
  evenly.
- **fill**: the shade is tinted towards daylight's fill by as much of the
  light as the model keeps from it (`shadow_marked`). The open floor stays
  the backdrop's colour exactly, and the deepest shade is the bluest. Tinting
  the fill against the key, as photoreal9 tinted the walls, moved the shade
  by 1 to 3 b* whatever the strength: most of what lights the open floor
  lights the shade too, and their ratio kept the colour.
- **The lens.** The black 2x4's leather is drawn at f/45, focused at 0.3 of
  its depth (it was f/64 at 0.45), so its grain falls off with distance as the
  photograph's does. This is the shot's own camera, set in the bench's shots
  file with the table.

**Measured, photograph : before : after** (`--frame-fix`; after is the
judged draws, both seeds, the tables from tables_dN and the shade from
all_dN):

| measure | photograph | before | after |
|---|---|---|---|
| leather spread (black_2x4) | 12.0 | 9.0 | 9.4, 9.4 |
| leather grain far / near | 0.91 / 3.46 | 0.21 / 0.19 | 0.86 / 3.45, 0.86 / 3.35 |
| desk spread (grey_1x3) | 11.7 | 2.4 | 9.5, 9.5 |
| desk fall, right less left | -6.4 | +0.2 | -7.0, -7.0 |
| stone spread (green_plate_macro) | 17.6 | 3.0 | 15.9, 15.6 |
| 6532 shade b* (fill 0.75) | -4.2 | -0.1 | -4.8, -4.9 |
| 6660 shade b* (fill 0.75) | -3.2 | +1.4 | -3.2, -3.0 |

The leather's spread is the one measure short: 22% under, 0.2 outside
the band. Deeper relief, darker creases, more tone per cell and a broader
tone all left it at 9.3 to 9.4. The spread is taken over the lit part, at a
quarter of the picture's size, where the cells are a pixel or two across.

**Judged.** One solo pool with the photographs, each tree drawn twice in a
snapshot, beside photoreal9's kept draws (the mean chance the judge gave a
photograph, per round; bench/results/photoreal10-2026-11-23):

| tree | close-ups | sets | called a photograph |
|---|---|---|---|
| photoreal9 | 0.370 0.389 | 0.157 0.167 | 17 of 80 |
| tables | 0.490 0.484 | 0.192 0.210 | 31 of 80 |
| fill | 0.404 0.421 | 0.150 0.152 | 20 of 80 |
| both | 0.521 0.554 | 0.150 0.147 | 30 of 80 |

The tables tree's sets are photoreal9's pictures byte for byte, so their
rise of 0.035 to 0.04 is the judge's noise. The tables lifted the black 2x4
from 0.27 to 0.65 and the grey 1x3 from 0.32 to 0.65; the green plate stayed
at 0.68 to 0.71. **Kept: the tables**, in the bench's shots
(tools/photoreal/shots.json). A table is the photograph's own, so the
product look's default stays without one. **The fill is not kept**: alone it
moved the close-ups by 0.03, at the noise, and the sets it was built for by
-0.01. With the tables it added 0.03 and 0.07 (the grey 1x3 to 0.84), which
it did not do alone. It stays a lever, 0 unless asked.

What the judge still names, of 80 verdicts on the tables tree: the backdrop
71 (photoreal9 75) and the light 63 (69). Leather and stone were tried once
before as a colour with no relief, and the judge called both procedural
(photoreal5). Now their relief is drawn, and they gained. The paired judge
on the kept tree found the photograph 18 times in 20, sure 0.827, the same as
photoreal9's 18 and 0.823. The tent's four main faces stay within ΔE2000 5
(1.3, 3.7, 1.6, 2.7). The car at Best took 2.05, 2.14 and 2.88 s.

**Tried and taken out, never judged.** A lever that could not reach its
number was not judged.
- **Letters as single raised strokes.** The photographs' strokes are
  lighter than the stud's top (photoreal10's logo measure, signed: +0.51 of each stroke's
  contrast, +1.9 L* at a set's distance). A rounded ridge at full height drew
  them darker (-0.16 to -0.36), because its walls stand near 45 degrees and
  mirror the floor. At a third or half of that height they turn lighter but
  faint (+0.27 to +0.40 L* at distance). A smooth finish on the walls did not
  change the sign.
- **Wear along part edges** in place of scuffs from a noise. The close-ups
  carry no age, so it drew nothing there. On the sets an edge is a pixel or
  two, and the faces' own grain (0.16 against the photographs' 0.04) does not
  come from the wear. No measure could see it.

## 5q. The plastic itself: five things real parts have, judged one at a time (photoreal13)

Every verdict on photoreal10 to photoreal12 named the plastic as the main
tell: the parts too clean, too even, their edges ruled. photoreal13 drew five
things a real part has, each as a lever on photoreal10's stage. Each was then
judged alone beside the photographs, against the same tree with all five
off, in one pool, at one moment, on the same seeds. The pictures are the
app's own: File › Render, Best, Product, as a person draws them
(`tools/photoreal/app_shots.py --older`, photoreal10's stage).

**The five** (commit 1b8320906 keeps all of them):
- **logo**: each stroke of the stud's letters as a rounded ridge with no flat
  top, as the mould raises it.
- **edge**: each edge's rounding (`ROUND`, 0.6 LDU) strays along it, half as
  much again either way, each part its own way. A nick here and there widens
  it to twice that, so the line of light along the edge breaks. A slope's face is also rounded into the part's ends: photoreal10
  drew that edge as a ruled corner.
- **lint**: dust settled on what faces up, as specks a few hundredths to
  a fifth of a millimetre across, thicker in patches and at each stud's
  foot, with now and then a curl of fibre.
- **mould**: one injection gate per part on one stud's top, whitened by
  the stress, and a faint sink over each tube.
- **sheen**: each part's gloss its own, its colour drifting a hair across it.

**Judged** (solo, 2 rounds of 2 trials, the photographs in the same pool,
600 verdicts, none lost: bench/results/photoreal13-2026-11-23/solo_p13pool;
the pictures side by side: arms_grid.jpg there):

| arm | called a photograph | mean p | close-ups | sets |
|---|---|---|---|---|
| all five off (photoreal10) | 11 of 80 | 0.188 | 0.271 | 0.062 |
| logo | 4 of 80 | 0.159 | 0.218 | 0.069 |
| **edge** | **16 of 80** | 0.223 | 0.333 | 0.059 |
| lint | 10 of 80 | 0.184 | 0.266 | 0.062 |
| mould | 12 of 80 | 0.189 | 0.275 | 0.060 |
| sheen | 11 of 80 | 0.186 | 0.270 | 0.059 |
| all five | 14 of 80 | 0.228 | 0.337 | 0.063 |

The edge's gain is on one picture and one seed, and it is not noise there.
On seed 1, red_slope_2x4 was called a render 4 times of 4 with the edges
off, in every arm that leaves them off. With the edges on, alone or with
the other four, it was called a photograph 4 times of 4. The judge's words
changed from "crisp, regular edge bevels" and "sharp, perfectly straight
edges and corners" to "the side faces have small surface flaws". On seed 2
the slope was already called a photograph 4 of 4. green_plate_macro went
from 7 of 8 to 8 of 8.

**Kept: the edges**, on unless asked off (`StudioRender.PRODUCT_EDGE` 1,
`RenderSettings.edge`). The amount goes to the card in each part's record,
in the byte of `info.w` above the studs' (`PathTracer.edge`), because the
closest hit reads no scene. **Taken out**, rather than left as levers:
- **logo** lost green_plate_macro, every one of its 8 calls (0.28 against
  0.65). The judge saw the letters "rotated inconsistently from stud to
  stud, some upside down", "garbled or mirrored". A rounded ridge lit from
  the side reads as sunk on some studs and raised on others.
- **lint, mould and sheen** moved nothing the judge sees. With lint on, "no
  dust" was still named in 78% of the verdicts (82% with it off). With the
  gates drawn, missing "mould marks" were named in 42% (46%). With sheen,
  "uniform colour" was named in 90% (90%). At the judge's 1024 pixels a
  speck a fifth of a millimetre across is a pixel or two on a close-up. The
  gate's ring was made twice as big once before (photoreal3), and the judge
  then called it "garbled marks inside the logo".

**Confirmed on the kept tree** (76a70e95a, imported, no runtime patch),
its edges on against `--without=edge`, on four seeds, in a second pool
(360 verdicts, none lost: solo_p13confirm). Without the edges the pictures
are photoreal10's within the pass split's 4 levels (10 of 10 shots, seed
1), and with them the judged edge arm's within 4:

| tree | called a photograph | mean p | close-ups | sets | paired |
|---|---|---|---|---|---|
| edges off (photoreal10) | 29 of 160 | 0.217 | 0.313 | 0.073 | 19 of 20, sure 0.860 |
| edges on (photoreal13) | 32 of 160 | 0.251 | 0.368 | 0.076 | 19 of 20, sure 0.859 |

The mean p is higher with the edges on every seed, in both rounds (8 of 8:
seed 1 0.249 against 0.212, seed 3 0.246 against 0.179). In the first pool
it was higher on both seeds in both rounds too (4 of 4). red_slope_2x4 is
called a photograph 16 of 16 times with them and 13 of 16 without. The
count, 32 of 160 against 29, is a small gain. Scaled to the brief's 80
verdicts, the two pools give 16 and 16 against photoreal10's 15 in
photoreal12's pool. **The bar (above 15 of 80, beyond the noise) is not
met.** The edges are kept because they are a consistent gain at no cost.
The paired judge holds (19 of 20 against 19 of 20).

**Time.** The car at Best, Product, 1280x720, 256 samples, drawn at the
same moment with the edges and without (photoreal_probe --car, three
renders each, four rounds, each tree started first twice): the median of
12 renders is 2.87 s with the edges against 2.73 s without, 5% more. The
round medians overlap (on 2.47 to 3.21 s, off 2.51 to 2.79 s). The edge
adds two value noises to each hit, and only near an edge does it change
the normal.

**What the judge still names**, of the 80 verdicts on the edge arm (with
the edges off in brackets): the backdrop or what the model stands on 85%
(86%), the light or the shadow 82% (81%), "uniform" colour or gloss 94%
(90%), no dust 68% (82%), no scratches or wear 72% (81%). The edges took
some of the dust and wear tells, the only ones that moved. On black_2x4 the
photograph's top mirrors a bright room and ours is dark. That is the
staging, not the plastic: photoreal12 measured it at 5.7 stops of top over
side in the photograph, against -1.3 in photoreal11's render.

## 5r. A large source behind the model, measured then judged (photoreal14)

photoreal13's verdicts named the light next to the plastic: a black
brick's top drawn as dark as its sides, where the photograph's top is 7.4
stops over its side. In the photographs, a glossy top mirrors something large and
bright behind the model: a window or a softbox. photoreal14 added one, render-only, seeded, off unless asked:
a rectangle (`RenderSettings.source`, `source_rise`, `_turn`, `_wide`,
`_tall`, `_fall`, `_key`; path_tracer.glsl `source_light`, `source_pick`
uniform on its plane, one-sample MIS with the BSDF), 90 by 50 degrees,
sharp-edged, behind the model, rising with the camera's pitch so a flat
top mirrors its middle. A way towards it passes the sweep (`lit_mask`),
as a softbox stands in front of the paper.

**Measured first** (tools/photoreal/reflect_measure.py, each close-up's
top against its side in stops and its edges' lines of light, the boxes
in shots.json `reflect`; bench/results/photoreal14-2026-11-23/
reflect_table.txt and reflect_default.txt):

| close-up | photograph | photoreal13 | fitted | the default kept |
|---|---|---|---|---|
| black_2x4 top/side | +7.42 | -2.09 | +7.30 | +7.30 |
| grey_1x3 top/side | +0.95 | -1.93 | +0.96 | +4.54 |
| green_plate top/side | +3.05 | +0.88 | +2.47 | +2.45 |
| green_plate top edge line | 3.1 px | 8.8 | 5.0 | 4.9 |
| red_slope top/side | +1.77 | +1.32 | +1.44 | +1.33 |
| red_slope slope top line | 2.3 px | 5.9 | 2.4 | 5.8 |
| red_slope slope foot line | 2.8 px | 1.2 | 1.1 | 1.2 |
| trans_round top/side | -0.37 | +0.12 | +0.24 | +0.12 |
| three_2x2 stud rim line | 3.5 px | 2.9 | 3.0 | 3.0 |

Three lines no source reaches: the red slope's foot (the bevel rounds
only a box's own edges, none at the slope's crease), and the grey and
green top edges (their width is the edge's shape, whatever the light).

**Judged after** (solo, 2 rounds of 2 trials, two draws an arm, the
photographs in each pool). The fit by measure, each shot its own, gained
nothing beyond noise twice (p14pool +0.018, p14confirm none). The black
brick's fit on every table did gain, and in every round and draw:

| arm (pool) | called a photograph | mean p | close-ups | sets |
|---|---|---|---|---|
| off: photoreal13's tree (p14tables) | 19 of 80 | 0.262 | 0.394 | 0.065 |
| **on every table: 128, the key at 0.05** | **28 of 80** | 0.337 | 0.515 | 0.071 |
| on, with a thinner logo (p14logo) | 17 of 80 | 0.262 | 0.387 | 0.074 |
| on (p14logo) | 28 of 80 | 0.325 | 0.487 | 0.083 |

grey_1x3 went from 0.13 to 0.58 and black_2x4 from 0.24 to 0.41. In
the tent the source lost the red slope (0.53 against 0.75), so the tent
has none: its pictures are byte for byte as before. That arm (128 on a
table, `SOURCE_KEY` 0.05) was made the default on a table, then taken off
again (below). The judge preferred
it over its measured mismatch on grey (+4.5 stops against +0.95): matching
the numbers is not what the judge rewards. The thinner logo (strokes
with gaps between the letters, one gate a part) was read as outlined lettering and taken out.

**The table kept its colour** (photoreal14b). Drawn first, the tables paled
towards the source, most on the whole car at the app's camera: wood and
terrazzo nearly white. Proved by the app's own renderer, the car on each
table at 1280x720 and 256 samples, five ways (bench/results/
photoreal14-2026-11-23/spill/): not the white balance (off, nothing moved:
within 0.3), not the meter (its exposure and card colour the same whether
the table mirrors the source or not), but the table's own gloss. The white
card the exposure is metered on is matte, so a table mirroring a 90 by 50
degree source was brighter than the card says white is: its glare as bright
again as its own colour. Schlick's glance term kept it even with the
table's specular at 0, so the table now takes only the source's diffuse
light, and the bounce leaves the source to the light's pick for it
(`on_table`, `SOURCE_SPILL` 0). At the meter's own level, the table's
colour is within CIEDE2000 4.6, 6.7, 3.5 and 3.9 of the source off (desk,
wood, leather, terrazzo; 7.4, 29, 39 and 30 mirrored), and a black brick's
top still mirrors it: +7.45 stops over its side, +7.42 in the photograph.
Beside the car on the side its lamp stands, the source-off picture is
brighter than its own colour, in a pool of the lamp's light; a table lit by
the source has no pool, so a patch there is darker than off (CIEDE2000 desk
5.1, wood 16.5, terrazzo 16.7, leather 20.3).

**Judged again, and off in the app.** The pools above were drawn with the
table mirroring the source, so the fixed tree was judged once more against
it off, from a locked snapshot (e68902b36), draws 9 and 10 (solo, 2 rounds
of 2 trials; bench/results/photoreal14-2026-11-23/solo_p14fixpool):

| arm | called a photograph | mean p | draw 9 | draw 10 | close-ups, rounds 1 and 2 |
|---|---|---|---|---|---|
| off | 16 of 80 | 0.261 | 0.267 | 0.255 | 0.387, 0.397 |
| on, the table keeping its colour | 18 of 80 | 0.278 | 0.279 | 0.277 | 0.408, 0.429 |

On led by 0.012 and 0.022 a draw, under the 0.03 a default needs: the
first pools' gain was mostly the pale, glaring table, which the photographs
do not have. So `StudioRender.PRODUCT_SOURCE` is 0: off in the app, the
photo bench asks for it (`SOURCE_LEVEL` 128 on a table) until its judge
keeps it, and a person's Render on a table draws as it did before
photoreal14, byte for byte. The light-and-shadow tell is named on 94% of
the fixed tree's verdicts. (That judge kept one blind name a picture, and
its "0.012 and 0.022" was one draw of it. Judged again by the fixed judge,
the source lifted every table close-up in every draw and is on: 5t.)

## 5s. The moulded skin's breakup, measured then judged (photoreal15)

The judge names "uniform colour and gloss" on nearly every verdict, and in
the close-up photographs a top's highlight is broken and wobbly where ours
is ruled. photoreal15 added four levers for moulded ABS's own unevenness,
render-only, seeded by the part, in the tracer's marks version only (the
plain version draws every default picture, byte for byte as before):
`peel`, an orange-peel waviness of the skin (two octaves of noise on the
normal, cells of 2.5 LDU, path_tracer.glsl `peeled`); `sink`, a dip just
off each stud's foot and over each tube (`sunk`); `polish`, sharper tops
than satin sides (`polish_split`); `scuff`, a few hairlines and pits
(`sparse_scuffs`). Each is `RenderSettings.peel` and so on, and
`StudioRender.PRODUCT_*` 0.

**Measured first** (tools/photoreal/breakup_measure.py, boxes and lines in
shots.json `breakup`; bench/results/photoreal15-2026-11-23/
measure_table.txt): a face's mottle in stops once its plane and broad
shading are taken out, a highlight line's or a mirrored outline's wobble in
pixels, the dip by a stud's foot. Tolerances, set first: mottle within 30%,
wobble within 0.5 px, dip within 0.2 stops.

| close-up | photograph | off | peel 0.5 | peel 1 |
|---|---|---|---|---|
| three_2x2 green top mottle | 0.026 | 0.022 | 0.034 | 0.051 |
| three_2x2 blue top mottle | 0.022 | 0.018 | 0.025 | 0.043 |
| red_slope end mottle | 0.034 | 0.029 | 0.030 | 0.035 |
| red_slope top strip mottle | 0.138 | 0.012 | 0.021 | 0.046 |
| black_2x4 mirrored stud outline | 2.13 px | 0.24 | 0.24 | 0.26 |
| green_plate top mottle | 0.34 | 0.04 | 0.04 | - |
| green_plate dip by a stud | -0.76 | -0.07 | -0.07 | - |

Peel at 0.5 fits the tent's tops; above it they turn blotchy. The
photographs' large numbers are not the skin: wear, dust and the room each
top mirrors. No lever reaches them without spoiling the tent, so those
shots were reported, not fitted. Sink moved no measure (the dip -0.07 at
any depth) and polish moved its one target the wrong way, so neither was
judged.

**Judged** (solo, 2 rounds of 2 trials, draws 11 and 12, the photographs in
the pool, from a locked snapshot of 714695819; bench/results/
photoreal15-2026-11-23/solo_p15pool):

| arm | called a photograph | mean p | draw 11 | draw 12 | close-ups, rounds 1 and 2 |
|---|---|---|---|---|---|
| off | 21 of 80 | 0.280 | 0.263 | 0.296 | 0.417, 0.424 |
| peel 0.5 | 16 of 80 | 0.255 | 0.258 | 0.252 | 0.378, 0.367 |
| scuff 2 | 12 of 80 | 0.227 | 0.225 | 0.228 | 0.315, 0.349 |
| peel and scuff | 16 of 80 | 0.255 | 0.265 | 0.246 | 0.382, 0.368 |
| photoreal14's source on the tables | 24 of 80 | 0.317 | 0.366 | 0.269 | 0.482, 0.483 |
| the source, peel and scuff | 30 of 80 | 0.363 | 0.382 | 0.344 | 0.568, 0.545 |

Every lever lost to the off arm: peel by 0.044 a round in draw 12, scuff
by 0.03 to 0.08 in every round and draw (red_slope's hairlines read as
render marks). With the source on, peel and scuff led the source alone by
0.026 and 0.006 in draw 11, under the 0.03 a default needs; their draw-12
lead came from grey_1x3, whose two pictures differ in 2,034 pixels of
786,432. So all four stay at 0, and a person's Render draws as before.

**The judge's noise is the picture's name.** The off arm and the source arm
share seven byte-identical pictures a draw (the tent and the sets). Repeats
of one picture agree within 0.024; byte-identical twins under two blind
names differ by up to 0.37 (three_2x2_top in draw 12: 0.66 and 0.28). So a
pool's rounds repeat each verdict rather than adding new ones, and an arm's
mean over ten shots carries about 0.024 of noise from the names alone. A
lever worth keeping has to lead across draws and shots, not rounds.

## 5t. A judge whose noise is measured, and the levers judged again (photoreal16)

**A blind name is a seed.** photoreal15's fourteen twin pairs were asked
again an hour later, six more times each, at their own paths in their own
folder. Every old gap came back (old gap against new, r 0.99):
three_2x2_top in draw 12 scored 0.65 under one name and 0.29 under the
other, ten verdicts each, with the same bytes in the same folder. The judge
reads one picture two ways ("small flaws, a real photograph" near 0.65,
"garbled logos, a render" near 0.3), and the exact prompt, of which the
file name is a part, settles which. Most names leave both open; some lock
one. Position and neighbours played no part. Ten pictures under eight fresh
names, three times each, shuffled into one pool, showed no pull from a
verdict's place in the pool (r +0.01 against what is left once its name's
mean is taken out) or from the verdict asked just before it (r +0.04). The
judge only ever opened its own file. The old judge kept one name a picture
for every round, so its rounds repeated one draw. It also ran inside the
checkout, so each verdict's context held a path naming the unit, "solo"
and "blind", and main's newest commits.

**The fix** (`tools/bench/photoreal.py`, `_fresh`): every verdict, solo or
paired, photograph or render, sees its picture under a fresh random name,
alone in a fresh folder in the system's temporary folder, outside any
checkout, and the copy is taken away after. Rounds are shuffled as before.
An arm is scored as the mean over its shots of each shot's mean verdict,
with a bootstrap 95% interval (the shots drawn again, then each picture's
verdicts). Against a base it is scored shot by shot, a picture the same in
both arms counting as one. Any byte-identical twins give the judge's own
noise (`score`; several pools' verdicts add up).

**Measured** (two pools from a locked snapshot of 8df1b3205, draws 11 to
14, 2 rounds of 2 trials each, the photographs in; the off arm asked twice
under two labels; 1,680 verdicts, 0 errors;
bench/results/photoreal16-2026-11-23/solo_p16pool and solo_p16pool2):

| twins | difference (95%) | tells apart at 95% |
|---|---|---|
| off and its twin, first pool (4 verdicts a picture) | +0.017 (+0.001 to +0.046) | 0.023 |
| the second pool | -0.001 (-0.019 to +0.014) | 0.016 |
| both (8 verdicts a picture, 40 pictures) | +0.008 (-0.001 to +0.023) | 0.012 |

The first pool's twin interval missed 0 by 0.001. One shot carried it:
three_2x2_top, whose verdicts split 0.3 and 0.65 within a picture. Drawn
from the pools' own verdicts, the same interval holds 0 for 98.7% of 300
simulated twin pairs. The second pool held 0, and so did both together.
With fresh names an arm's mean repeats between pools: off 0.298 and 0.292,
the source's lead +0.104 and +0.107. The old judge's twin gaps had a
spread (sd) of 0.099, and the same pictures moved by 0.095 a picture (sd)
between the old judge and the new.

**The levers judged again** (both pools; against off, shot by shot):

| arm | mean (95%) | against off, all shots | close-ups | the shots it changes |
|---|---|---|---|---|
| off | 0.295 (0.116 to 0.512) | | | |
| the source on tables (photoreal14) | 0.400 (0.185 to 0.619) | +0.106 (+0.000 to +0.259) | +0.176 (+0.006 to +0.409) | +0.352 (+0.043 to +0.690), 12 pictures of 12 ahead |
| peel 0.5 | 0.253 (0.088 to 0.476) | -0.042 (-0.127 to +0.008) | -0.074 | three_2x2_top -0.36 to -0.46 in every draw |
| source, peel and scuff | 0.384 (0.157 to 0.619) | +0.089 (-0.061 to +0.265) | +0.145 | three_2x2_top -0.32 to -0.39 in every draw |

The source changes only the three table close-ups and lifts every one in
every draw: grey_1x3 from 0.12 to 0.82, black_2x4 from 0.28 to 0.61,
green_plate from 0.87 to 0.91. Over all ten shots its interval starts at
0.000 only because a resample of ten shots draws none of those three 2.8%
of the time, and there the two arms are the same pictures. So the source
is kept: `StudioRender.PRODUCT_SOURCE` is `SOURCE_LEVEL` (128) on a table
under the studio's light, and none in the tent. Peel turns the top-down
three_2x2 from "real" to "render" in every draw, and it drags the
source-peel-scuff arm below the source alone, so both stay at 0. With
peel and scuff added to the source, black_2x4 rose to 0.78 (0.61 with the
source alone, and peel alone lowers it), so the source with scuff and
without peel is the next arm worth judging.

**The design ladder's realset screen is built the same way, and is left as
it is.** realset.shown copies a model's views into one folder per set,
bench/results/blind/<set>/, under a name fixed by the model's key
(pairwise.opaque). The judge runs in that folder, inside the checkout.
realset.ask keeps each ordered pair's verdict on disk under its two names
and reads it back, so asking again repeats it. Both orders are asked, so
position is balanced, but a set's side carries one name in every
comparison of that set, and each rung one more. A design's place on a
ladder is therefore one draw of each pair of names. Fresh names for every
ask, and a folder outside the checkout, would make its verdicts samples
(tools/design_ladder.py, place_one and order; realset.ask and shown).

## 5u. A set photographed, not floating (photoreal19)

Close-ups were called photographs about 0.6 of the time, whole sets 0.03
to 0.10, and every set verdict named "a seamless pure white infinite
background" and "flawless uniform plastic with no wear or dust". Beside
the set photographs the judge holds, our sets differ in what they stand
on: the photographs' sweep is clipped white like ours, but glossy, the
model's colours bounced and faintly mirrored under it, its shade a cool
lavender and tight to the model. Ours was a neutral grey shade, broad
and soft, on paper that mirrors nothing.

**The floor** (`RenderSettings.floor`, `StudioRender.PRODUCT_FLOOR`,
`_floor_of`; path_tracer.glsl's photo version, `floor_kept` and
`floor_over`): on the bare seamless paper (the shadow catcher, with no
table's relief and no surface of its own), it is drawn as a product
photograph's. Exposed past white (`FLOOR_OVER` 1.6 on a white
sweep), so only the shade near the model shows; that shade cooled toward
the fill's daylight as it deepens; the light the parts send down onto it
(a blocked sample traces the part and lights it) laid on in their colour;
and glossy (`FLOOR_F0` 0.04, `FLOOR_GLOSS` 0.3), the model mirrored in
it a little and blurred. A lit stage, a table's relief and a surface are
their own and left as they were: the judge saw the floor only on the
bare seamless, and with it on the gallery card's desk (CardPhoto.LOOK, a
table on the catcher) took a pink bounce and a gloss nobody judged. The photo version is the marks version with this, so
the plain and marks versions compile to the same SPIR-V as before.

**Handled plastic** (judged, taken out). Each part's gloss a shade its
own, soft dull patches, hairline scratches where it was rubbed, specks
of dust on what faces up, a hazed windscreen and a deeper sink. It moved
no set (+0.002), and it lost two close-ups in every draw: grey_1x3 0.80
to 0.38, red_slope_2x4 0.82 to 0.62. Its dulled patches evened out the
scuffs the judge had read as real ("small dust specks and scuffs on the
top face") and the slope's glinting grain ("an even noise pattern"). A
version that only adds marks drew within 0.7% of the pixels of the
close-ups, its specks lost in what a top mirrors. Neither is kept; the
first is a81721153.

**The logo is not drawn mirrored.** black_2x4's camera looks at every
stud from the far side: its renders' logos read upside down, as the
photograph's do, and turned half a turn they read LEGO, which a mirrored
logo never does (bench/results/photoreal19-2026-11-24/logo). Crisp
upside-down italic letters read as mirrored; the photograph's are worn
soft.

**Judged** (photoreal16's solo judge, fresh names, draws 11 to 14 of
the 10 shots from locked snapshots of a81721153, 2 trials, 4 rounds,
2,000 verdicts, 0 errors; bench/results/photoreal19-2026-11-24):

| arm | mean (95%) | against src, all shots | close-ups | sets |
|---|---|---|---|---|
| src (the app's defaults) | 0.395 (0.182 to 0.612) | | | |
| src again (twin) | 0.397 | +0.000 | +0.000 | +0.000 |
| floor | 0.412 (0.196 to 0.633) | +0.020 (+0.005 to +0.043) | +0.025 (+0.001 to +0.059) | +0.012 (+0.003 to +0.021) |
| handled skin | 0.334 (0.153 to 0.535) | -0.062 (-0.156 to +0.005) | -0.104 (-0.249 to +0.007) | +0.002 (+0.001 to +0.003) |
| both | 0.380 (0.186 to 0.597) | -0.015 (-0.100 to +0.039) | -0.035 (-0.169 to +0.061) | +0.014 (+0.005 to +0.023) |

The floor leads src on every shot it changes, in nearly every draw:
three_2x2_top 0.55 to 0.64 (4 draws of 4), red_slope_2x4 0.82 to 0.86
(4 of 4), set_6532 0.058 to 0.078 and set_6657 0.048 to 0.070 (4 of 4
each), set_6512 and set_6660 by a few thousandths (4 of 4). The table
shots are the same pictures. So it is on: `PRODUCT_FLOOR` is 1. The sets
are still far from the photographs (0.06 against 0.93): every set
verdict still names flawless plastic and a seamless backdrop.

## 5x. A photograph's focus on a whole model, fitted then judged (photoreal23)

photoreal22 read every verdict since photoreal5 and found depth of field
the set tell most tied to the judge's number (r +0.75): "everything in
focus" on 0.58 of our set verdicts and none of the photographs'. Under
photoreal20's and 21's lamps the focus words and the number moved
together, and so did the colour, so those pools could not say which one
the judge reads. This arm moves the focus alone.

**Where a photograph focuses.** `tools/photoreal/dof_measure.py` measures
an edge's width (px at 1024 wide) in boxes on the near, middle and far
parts of each set. Each photograph is focused on its driver, in the middle
of the model, not on its nearest feature: 6532's head 2.80 against 5.00
near and 4.05 far, and 6660's cab 1.93 against 3.85 and 3.80. 6657's
photograph is sharp nearly throughout (2.37 to 2.67).

**The fit** (bench/results/photoreal23-2026-11-26/sweep, 112 variants of
the product camera's softness, the f-number, the focus across the model's
depth, and a sharpen; the miss is the RMS log ratio of the three widths):

| set | photograph near / middle / far | src | fitted | miss src → fitted |
|---|---|---|---|---|
| 6532 | 5.00 / 2.80 / 4.05 | 5.16 / 3.07 / 3.92 | 4.91 / 2.92 / 4.20 | 0.060 → 0.033 |
| 6660 | 3.85 / 1.93 / 3.80 | 4.26 / 2.46 / 3.95 | 4.27 / 2.26 / 3.67 | 0.151 → 0.109 |
| 6657 | 2.67 / 2.37 / 2.65 | 3.02 / 2.62 / 2.42 | 2.65 / 2.48 / 2.74 | 0.106 → 0.032 |

The fitted values are softness 0 and f/10 at 0.42 of the depth (6532), f/9.5
at 0.5 (6660), and f/16 at 0.30 (6657). 6512's picture is itself a render
with everything in focus, so it only lost the softness. Taking off
`PRODUCT_SOFTNESS` sharpened 6532's driver only from 3.07 to 2.96. The
rest of the soft middle was the focus plane sitting behind him. On 6660
no lens gets the cab under 2.26: a sharpen of 0.3 reached 2.14, but it was
left out, because that is the camera's processing, not its focus. The
colour did not move (CIEDE2000 against the photographs 3.00, 5.36 and
6.10, against src's 3.00, 5.35 and 6.06).

**Judged** (photoreal16's solo judge, fresh names, the four sets at
draws 11 to 22 from a locked snapshot of pre261 3aa31d158, 2 trials, 4
rounds; the close-ups and the car are src's bytes):

| arm | sets (95%) | against src, sets | all ten shots | set verdicts: depth of field a photo tell / "everything in focus" |
|---|---|---|---|---|
| src | 0.057 (0.040 to 0.074) | | | 0.40 / 0.34 |
| src again (twin) | 0.057 | +0.000 | +0.000 | 0.37 / 0.33 |
| focus fitted | 0.057 (0.038 to 0.076) | -0.000 (-0.003 to +0.003) | -0.000 (-0.001 to +0.001) | 0.56 / 0.20 |
| twice the blur (another pool) | 0.065 (0.045 to 0.082) | +0.008 (+0.000 to +0.015) | +0.003 (-0.000 to +0.007) | 0.70 / 0.09 |

The fitted focus changed what the judge said, and not its number. On 6532
it named depth of field as a photo tell in 0.94 of its verdicts (src 0.70),
"everything in focus" fell from 0.34 to 0.08, and the number stayed at 0.080.
6660's photo tell rose from 0.14 to 0.36 and its number stayed at 0.044.
So the r +0.75 was the lamps moving both at once. The focus words are read
off the picture; they do not decide it.

Twice the blur (half the fitted f-number, the focus kept) rose on
every photographed set: 6660 +0.017 and 6657 +0.011 in 12 draws of 12, 6532
+0.006 in 8. Yet 0.90 of its verdicts called it "synthetic-looking
depth-of-field blur", and 6532's far wheel goes past the photograph's
(6.47 px against 4.05). Its all-shot interval does not clear 0. Focus is at
most a lever of about 0.01 on sets that stand 0.87 below their
photographs. Nothing changes: `PRODUCT_SOFTNESS` stays 0.6, the app's lens
stays off, and tools/photoreal/shots.json keeps its lenses. Of
photoreal22's two candidates, the plastic's colour as photographed is the
one left to judge alone.

## 5y. The sets' plastic as photographed (photoreal24)

The lead's look at 6660 found four differences from its photograph:

- the photograph's whites are warm cream, ours cool;
- its windscreen is pale, ours saturated cyan;
- its hook is a warm grey, ours bluish;
- its hubs read white, ours grey.

**The models are right.** The hubs are white 15 and read grey from the light: the photograph's whites sit at
L92-98, as bright as its backdrop. The hook is old light grey 7. The app's 7 is LDConfig's #8A928D
(L59.8). Rebrickable's #9BA19D is 6 L brighter. The photographed hook is L70.7 with b* +12: age. Old
dark grey 8 is in none of the photographed sets.

**Fitted.** The photo probe takes a shot's `"colours"` (LDraw code to hex) for that shot alone and puts
them back after it. Each set's families were fitted by colourfit's pixel-weighted CIEDE2000. That brought
the sets from 3.00 / 5.35 / 6.06 to 2.31 / 1.72 / 2.76 (6532, 6657, 6660). What is left is lightness: the
photographs' exposure and floor shade, not plastic.

**Judged** (photoreal16's solo judge, draws 11 to 22, 2 trials x 4 rounds; bench/results/photoreal24-2026-11-26):

| arm | sets against src (95%) | 6532 | 6657 | 6660 | 6512 |
|---|---|---|---|---|---|
| each set's plastic fitted | +0.002 (-0.006 to +0.009) | -0.009 | +0.008 | +0.010 | same pictures |
| paler clear tints only (43 #dafbff, 46 #ffe253) | -0.004 (-0.006 to -0.001) | same pictures | -0.006 | -0.004 | -0.006 |

The fitted sets move about 0.01 each way and not at all together. The tints alone lose, and the judge
names the pane's "glowing cyan edges": thick edges keep their colour, so a paler face sets them apart. So
colour stays as it is: 43, 46, 7 and 15 keep LDConfig's values. The set renders still sit near 0.06
against their photographs' 0.93. What the photographs earn is age and variation (named in 0.71 and 0.88 of
their verdicts); no render earns either.

## 5z. Every tell at once, then each taken out (photoreal25)

Each lever alone had moved the judge by about zero, while it names five or six tells on every render.
So this round put them all on at once, each at the strength its own round measured best:

- **F**: the fitted focus (5x);
- **C**: each set's own plastic (5y);
- **W**: wear and age. On the sets that is shots.json's age, handling 1.0, dust 0.4 and seating 2.5. On the
  close-ups it is rubbed 1.0 and their dust;
- **K**: the camera: 1024 samples, shots.json's grain, vignette and aberration, and JPEG at the
  photographs' own quality (75 on Rebrickable's set pictures, 90 on the close-ups) with sharpen 0.6 on
  the close-ups;
- **E**: photoreal18's rounded edges, on the sets only.

Then it took each one out in turn. All pools used photoreal16's solo judge on ten shots, draws 11 to 16;
the files are in bench/results/photoreal25-2026-11-26.

| against src (95%) | photographed sets | close-ups | all ten shots |
|---|---|---|---|
| all five levers | +0.113 (+0.055 to +0.153) | -0.047 (-0.161 to +0.028) | +0.006 (-0.069 to +0.070) |
| src again (twin) | +0.002 (-0.002 to +0.006) | -0.009 | +0.005 |

The sets moved about ten times as far as any single lever had (the floor's +0.012 in 5u): 6532 0.08 to
0.21, 6657 0.07 to 0.12, 6660 0.05 to 0.20, each in 6 of 6 draws, in two pools with two seeds. The ten-shot number did not move, because grey_1x3 (-0.27) and
three_2x2_top (-0.10) fell as far.

What each lever carries (all minus all-without-it, paired by draw, on the photographed sets):

| lever | carries | read |
|---|---|---|
| W wear and age | +0.092 (+0.030 to +0.134) | carries it: 6532 +0.11, 6660 +0.13, 6657 +0.03, 6 of 6 each |
| E rounded edges | +0.024 (+0.004 to +0.051) | 6532 only (+0.053), as in photoreal18 (+0.027) |
| K camera | +0.015 (-0.017 to +0.040) | 6657 only (+0.037) |
| F focus | -0.020 (-0.083 to +0.024) | nothing; 6532 is better without it |
| C plastic | -0.026 (-0.046 to -0.006) | costs: the cream fit loses 6532 again |

The words agree. With W out, wear stops being a photo tell (0.17 to 0.01) and so does "variation in the
plastic" (0.12 to 0.00).

**Nothing becomes a default.** W is the photographed sets' history (thirty-year-old, handled plastic):
bench content. A user's new model is not dusty or yellowed. E helps one set, and photoreal18 measured
three_2x2_top -0.106 with it on a close-up, so as a default a close-up would get worse. The port was taken
back out (3e36ec52d), because even off it moves the default bytes by up to 6 levels on 0.23% of
pixels. The close-ups' own wear and camera are bench content too: W costs three_2x2_top and black_2x4,
and K costs grey_1x3. The car is in no arm, and its pictures are the same bytes in every arm.

The sets still stand at 0.12 to 0.21 against their photographs' 0.93. The tells no lever touched are now
the most named:

- the stage: seamless pure white with an idealised soft shadow, named in 0.99 of the verdicts, while the
  photographs' shadows are a photo tell in 0.83;
- the edges ("crisp, uniform edge bevels", 0.90);
- the wear itself, read as "procedural-looking micro-scratches".

The judge now names a render tool more often (0.30 to 0.40).

## 5aa. The stage measured from the photographs, and played-with plastic as a choice (photoreal26)

5z left the stage as the most named tell. So this round measured it from the photographs, not from
the judge. On each photographed set, and the same way on our draws (bench/results/photoreal26-2026-11-26,
scripts/stage26.py), it measured:

- the open floor's brightness and how it falls off;
- the shade's profile: how much darker the floor is at 0-1, 1-2, 2-4, 4-8, 8-16 and 16-32% of the
  model's height from it, how wide it reaches, and its colour;
- the parts' colour bounced onto the floor;
- the shade pixel for pixel against the photograph, whose camera each shot is fitted to.

What the photographs show, against src:

- **The floor.** 6532's and 6660's is clipped white, as ours is. Neither falls off.
- **The shade.** It is fainter and narrower than ours. On 6532 its rings are 1.6, 0.6 and then 0 L*;
  ours were 6.3, 4.3, 2.6 and 1.4.
- **Its colour.** It is lavender (a* +2 to +4, b* -2), where ours was a daylight fill's blue (a* 0,
  b* -3).
- **Bounce and gloss.** 6532 has a warm glow under its yellow front. No bounce or gloss lever reaches it.
- **Where the shade falls.** It lies under the chassis, away from the camera. Ours falls toward the
  camera, cast by the tent's low soft boxes behind the model.
- **6657 and 6512.** 6657 is daylight on a beige board, with a hard cast shadow. 6512's "photograph" is
  a render on a grey gradient. Neither is the tent's stage.

**The fit.** The floor alone was fitted, through new bench levers (RenderSettings `floor_boxes`,
`floor_over`, `floor_key`, `floor_shade`, `floor_bounce`, `floor_f0`, `floor_rough`), so the model's own
light was kept. The best setting was:

- the sweep exposed further past white (2.4 for 1.6);
- more of the key on the floor (1.5);
- the shade most of the way to lavender (0.8).

| error from the photographs | 6532 | 6660 | red_slope | trans_round | three_2x2 |
|---|---|---|---|---|---|
| shade, pixel for pixel (L*), src | 1.29 | 1.01 | 0.38 | 0.26 | 1.64 |
| shade, fitted | 0.88 | 0.90 | 0.30 | 0.20 | 0.98 |
| shade's tint (a*b*), src | 2.4 | 4.3 | 2.0 | 8.3 | 2.5 |
| shade's tint, fitted | 0.7 | 2.4 | 0.3 | 6.3 | 1.6 |

What did not help:

- Taking the soft boxes off the floor moved the shade the right way, but made it twice as dark
  under 6660.
- The bounce and a glossier floor moved nothing.
- The tables, black_2x4, grey_1x3 and green_plate_macro, are untouched byte for byte.

**The judge did not move.** One pool, photoreal16's solo judge, ten shots, draws 11 to 16, 2 trials by
4 rounds, seed 261:

| against src (95%) | photographed sets | close-ups |
|---|---|---|
| the fitted stage | +0.005 (-0.001 to +0.013) | +0.002 (-0.024 to +0.023) |
| the fitted stage, Played with | +0.176 (+0.058 to +0.287) | -0.207 (-0.412 to -0.018) |

The sets did not move beyond the interval, so **the stage is not a default.** The levers stay at
photoreal19's values unless asked, and a picture without them is byte for byte src's.

The words say why. "Soft, idealised shadow" is a render tell in 0.98 of the fitted stage's set
verdicts, and the photographs' "soft, natural contact shadows" are a photo tell in 0.96. The same
shade is named for whichever verdict the plastic has already decided. Played with takes it to 0.91.

**Played with, as a choice.** photoreal25's wear and age are now Render's Plastic row (RenderSettings
`plastic`, StudioRender `PLAYED_*`):

- **New** is the default. A person's model is new, and the default bytes do not change.
- **Played with** draws age 1.0, handling 1.0, dust 0.4 and seating 2.5, at Best in the Product look.
  Any of the four asked for by number still wins.

On the sets it is +0.18 (6532 +0.21, 6660 +0.26, 6657 +0.06, each in 6 of 6 draws), and "yellowed"
becomes a photo tell. On new single parts it costs: grey_1x3 -0.60, black_2x4 -0.47, three_2x2_top
-0.19. That is why it is a choice for a model that has been played with, and never the default.

## 5ab. The stud logo's hand, and Played with in the browser (photoreal27)

**The logo is right.** The judge called black_2x4's logo "mirrored" in 27 to 46 of 48 verdicts
(photoreal26's pool), and never the photograph's. Turned by the same angle, the render's stud and the
photograph's both read "LEGO" upright, left to right, and three_2x2_top's top view reads upright in
both. The text runs along the stud's +z with its letters' tops toward +x, and z × x is +y, toward the
eye: right in the part's own space, and Godot's space is LDraw's turned, never mirrored. Only the path
tracer draws a logo (the raster's parts have plain studs), so there was nothing to fix. What the judge
reads as mirrored is near upside-down text with crisp, doubled strokes.

**Played with where nothing traces rays.** A browser, the simpler graphics mode, a card without ray
tracing and a picture on nothing all draw Best by averaging raster frames, and Played with drew there
as New. Now the raster's Product plastic draws it from the same RenderSettings levers
(`StudioRender._raster_wear`):

- `plastic_body.gdshaderinc` under `PLASTIC_PRODUCT` takes `wear_age`, `wear_dust` and
  `wear_handling`, and copies the tracer's own wear: whites and greys yellowed, each part its own amount
  (a number per part from where it stands on the stage, `wear_stage`); handled patches; finger marks;
  hairline scratches; and knocked edges. Where the coat is worn, the gloss is blurred rather than
  taken away.
- Dust is only what Played with adds beyond New's. The tracer's New already carries `PRODUCT_DUST`'s
  film, and the raster's New stands for it. The whole of `PLAYED_DUST` turned every top milky, three
  times the tracer's shift from New. The tracer's motes come out of its denoise as part of the film,
  so here the film takes their share evenly. Drawn sharp, they read as grit on every top.
- The stage seats each part as the tracer seats its copy, by `PathTracer.seat`.
- New's uniforms are 0, so its bytes are as before: byte for byte against the baseline on all eleven
  shots drawn.

The note under Plastic no longer says Played with needs path tracing.

**The stud logo in the browser.** The judge named "studs with no LEGO logo" in 332 of the browser's 480
New verdicts. The raster's Product plastic now raises the tracer's logo (`stud_logo`, stroke for stroke,
the same way round) at Best only (`stud_logos`, `StudioRender._raster_logos`). Best's 32 averaged
frames resolve letters finer than a pixel, where Quick's and Good's single frame would alias.

**What the judge said of the browser's Best.** photoreal16's solo judge, the ten shots, one draw (the
raster draws the same picture at every draw: 11 and 12 match to 2 pixels in a million), 6 trials by 8
rounds, 48 verdicts a picture, three pools (seeds 271, 272 and 273). Every browser picture sits at the
floor: 0.03 to 0.17 called a photograph, against the photographs' 0.93.

| against New (95%) | all shots | close-ups | sets |
|---|---|---|---|
| Played with, pool 1 | +0.010 (+0.001 to +0.024) | +0.016 (+0.001 to +0.038) | +0.001 |
| Played with, pool 2 | +0.009 (+0.001 to +0.023) | +0.016 (+0.003 to +0.036) | 0.000 |
| New with the logo, pool 2 | +0.006 (-0.000 to +0.017) | +0.012 (+0.002 to +0.026) | -0.001 |
| New with the logo, pool 3 | +0.007 (+0.000 to +0.019) | +0.013 (+0.002 to +0.030) | -0.001 |
| Played with and the logo, pool 2 | +0.019 (+0.003 to +0.040) | +0.031 (+0.006 to +0.061) | +0.002 |
| Played with and the logo, pool 3 | +0.019 (+0.003 to +0.041) | +0.032 (+0.007 to +0.063) | +0.001 |

The judge names the studs (no logo, plain) as a render's tell in 331 and 327 of New's 480 verdicts, and
in 114 and 99 once the logo is drawn; Played with's 318 become 110 and 112. It reads the logo as
"mirrored" in 71 of 960, all but 5 on black_2x4: from that camera the word is upside down, as it is in
the photograph, and both read LEGO turned half round. green_plate_macro gains the most (+0.045 and
+0.055; +0.092 and +0.097 with Played with). No shot falls in both pools by more than the pools differ
on an unchanged pair: set_6532's Played with is -0.001 in one pool and -0.004 in the other.

## 5ac. Best path traced in the browser, on the visitor's card (photoreal28)

**What runs.** The desktop's own tracer, not another one. `tools/web/tracer_port.py` turns
path_tracer.glsl's raygen and closest hit into one GLSL ES 3.00 fragment shader at the export
(tracer.js beside index.html). The raygen's main becomes a fragment drawing a band of rows into two
RGBA32F targets, the running sum and the guide, read back the next pass. The closest hit becomes a
function, the storage buffers become data textures 2048 texels wide, and `traceRayEXT` becomes a walk
of two-level trees that `page_tracer.js` builds in the page: one per shape (binned SAH), and one over the
placed parts. The same Scene, Pass and Resolve blocks, the same samples by their own index and the seed,
and the same plain, marked and photo versions. `PathTracer` gives the page what it gives the card on
the desktop (`PageTracer`, base64 one way and JavaScript buffers back). No tracer of anyone else's is
in it, so no licence is to be recorded: it is our own shader text, ported by our own script, with our
own trees. tracer.js (about 420 KB) is fetched only when a path-traced Best starts, so a first visit
loads nothing more: the first screen's scripts are the same 220 and 7,390,694 bytes
(`start_closure.closure`, before and after).

Where the browser has no WebGL2 float targets, or draws without a graphics card (SwiftShader,
llvmpipe: minutes a picture), Best stays frames averaged and the result says which. `?tracer=on` asks
for the tracer anyway, `?tracer=off` turns it off.

**The same picture as the desktop's.** At the same seed the browser's tracer draws the desktop's Best
sample for sample. On the card through EGL (`gpu28.py`, the shaders and textures the page gets), the
four close-ups differ from the desktop's draw 11 by 0.05 to 0.09 of 255 on average, under 0.01% of
pixels by more than 8. The desktop's own draws 11 and 12 differ by 0.3 to 1.7, 0.5% to 5% of pixels.
black_2x4's white mirrored top, the logos, the terrazzo and the focus are all there. On a set
(set_6532, sheets/set_6532.jpg) the raster's grey ground and waxy plastic give way to the
desktop's white studio, glossy plastic, clear headlights and soft shadow, and the browser's picture
and the desktop's cannot be told apart by eye.

**The first compile.** A shader has no calls, so each `trace()` is copied in where it is called, and
the closest hit with it. A shadow ray's walk through clear parts reads only which part and how far, yet
it carried the whole moulded surface (logos, wear) into seventeen places. The card's first compile
took 11 s to link and 47 s more at the first draw, and Chrome's GPU process would sit through it. That
walk now asks for the bare hit (`RT_BARE`, the port's own flag). The walk itself was copied in
too: through_masked held two of them, the solid parts and then the clear parts' faces, and it is
copied into every shadow ray, so 34 of the shader's 37 walks were there. One `walk()` in a loop
now does both, leaving 20. On llvmpipe its pictures are the same to the bit. On the card they
differ by 0.03 of 255 on average, in 1% of pixels: float rounding on the clear parts' paths.
The photo version's first compile with no shader cache, on a loaded box (gpu28.py, the link and
then GL_COMPLETION_STATUS_KHR, as the page waits): 16.6 s + 124.6 s before, 14.5 + 100.2 with
`RT_BARE`, 4.7 + 49.2 with the one walk. And it traces 2.4 to 2.6 times faster: a set
1,130 → 473 ms a sample a megapixel, a close-up 205 → 77, measured in turn A B A B in one lease.
A browser without KHR_parallel_shader_compile could only learn whether the tracer compiled by
asking for its link status, which waits out the compile on the page's own thread. There Best
stays frames averaged, and the result says the page would freeze.

**Pacing.** A pass is given only after the last one's fence has signalled. It is a band of rows sized
to 12 ms of the card where the browser times the card's work (EXT_disjoint_timer_query_webgl2, in
Chrome). Firefox and Safari do not time it, and there the frames' gap paces it. The browser holds the
next frame until the card has drawn this one, so a pass is always done by the next frame however long
it took. The page's own frame is timed first, over three frames given no pass. The band grows while
frames come within 6 ms (or 35%) of it and shrinks past 18 ms (or 100%) more. At 60 a second that
is the 22 and 34 ms it was first given. A fixed 22/34 ms starved the tracer wherever the studio's
own frames were slow (25 a second, or SwiftShader): the band sat at its smallest. A picture shown
part way down a block divides each part by its own count, and Finish now waits for the block to
reach the last row. Through the script's fetch, the first compile and the metering, the dialog
said "setting up the model 0%". It now says what it waits on.

**The bench reset the card.** The bench's first harness gave the card whole pictures of a set in one
pass, past the kernel's 10 s, and the ring was reset four times (15:42). The page never gives a whole
picture. The bench now gives bands of about 150 ms.

**Time to a clean picture.** On this box's RX 6700 XT, with the shipped shader, a sample of a
megapixel takes 58 to 78 ms for a close-up and 408 to 649 ms for a set. red_slope takes 337 and
three_2x2_top 278 (much of the picture is the bright, rough backdrop), and trans_round 443
(clear plastic). The default Best is 1920x1080 and the tracer has 12 ms of each 16.7 ms frame. So
a close-up's 256 samples take about a minute here and a set's 6 to 8 minutes. A mid laptop's card is
about a quarter of this one. In a 30 s Best it reaches about 35 samples of a close-up and 4 to 6 of
a set. SwiftShader is the floor, and it does not trace unless asked (`?tracer=on`). On the bench
page at 256x215, its first sample came after 26 s and 8 samples after 81 s. Its frames came every
16.7 ms (p95 20.5) except one of 8.1 s at the first draw, where SwiftShader compiles the shader in the
GPU process. In the app it meters the light at 20 s a sample.

**The judge.** photoreal16's fixed solo judge, as photoreal17 to 27 ran it: 6 trials of 8 rounds,
each picture scored against the browser's raster, intervals by bootstrap over trials. Pool c28, nine
shots, the browser's tracer at 256 samples:

| | close-ups | sets |
|---|---|---|
| raster | 0.051 | 0.034 |
| tracer, 32 samples | 0.385 | 0.045 |
| tracer, 256 samples | 0.723 | 0.057 |
| desktop Best | 0.775 | 0.057 |

Against the raster, shot by shot, the tracer at 256 is ahead beyond its interval on every shot.
Close-ups +0.672 (+0.528 .. +0.803). The four sets +0.007 (+0.005 .. +0.009), +0.039, +0.036 and
+0.011. Against desktop Best it is within 0.012 on eight of the nine. The ninth is three_2x2_top
(0.444 against 0.683, and 0.370 against 0.653 in pool a28). Its two pictures are 0.28 of 255
apart, nothing over 30, so the judge is telling apart pictures no one could. Pool d28 put the
desktop's draws 11 and 12 side by side on that shot and on black_2x4. The two desktop draws were
0.076 and 0.173 apart, and the tracer was as far from draw 11 (-0.183 and +0.165). Over the two
shots the tracer scored 0.609, draw 11 0.618 and draw 12 0.493.
At 32 samples nothing has settled: grey_1x3 scores 0.105 against 0.820 at 256. The guided clean
leaves a fine grain in the shadow and on the dark brick (sheets/grey_spp_crop.jpg), and the judge
reads it as a render. Pool e28 added 128 samples. At 128, every set, trans_round, green_plate,
red_slope and three_2x2_top are within 0.010 of 256. black_2x4 is 0.154 short and grey_1x3 0.689
short: grey_1x3 scores 0.113 at 32, 0.119 at 128 and 0.808 at 256. The judge wants about 256
samples of a close-up before its number stops moving.

**30 s on a mid laptop: not yet.** Pool f28 judged what such a Best leaves (`laptop28.sh`). Each
shot was drawn at the default Best's 2.07 megapixels, at the samples a card a quarter of this one
reaches in 30 s: 33 to 45 of a close-up, 7 of red_slope, 9 of three_2x2_top, 4 to 6 of a set. Then
it was made the judge's size. Against the tracer at 256: green_plate +0.010, black_2x4 +0.045,
three_2x2_top +0.265 (the judge again), trans_round -0.011, but grey_1x3 -0.502 and red_slope
-0.658. The sets score 0.032 (0.027 .. 0.038), the raster's 0.033: in 30 s on such a card a set
has nothing over the raster, and it looks grainy (sheets/laptop30.jpg). So this round is NO-GO on
its own bar. Waited for, the browser's Best is the desktop's. Finished at 30 s on a modest card,
a set is not. What is left is a clean that holds at 4 to 8 samples: an edge-avoiding filter over
several passes, guided by the normals and albedo the tracer already writes, in place of the one
7x7 pass. Then f28 again.

## 5ad. Denoised in the browser, and never worse than the raster (photoreal29)

**The filter.** The desktop's only denoiser is the resolve's one 7x7 guided pass (`cleaned()`),
which wants about 256 samples. The browser now goes past it with SVGF's spatial part
(`src/render/page_denoise.frag`, run by page_tracer.js before the resolve). There are five à-trous
passes, 1, 2, 4, 8 and 16 pixels apart, on a 5x5 B3 kernel. The ported tracer sums two more targets
for it. u_more holds the eye's first hit: its albedo and its depth along the camera. u_even holds the
even samples' light and kind apart from the odd ones. So each pixel has two halves of its samples.
Their difference is the pixel's measured noise, never an assumed one, and the passes carry that
variance on, weights squared. Two neighbours are averaged as far as they are alike in light (in units
of that noise, blurred 3x3), albedo, normal, depth (against the surface's own slope) and kind
(plastic by lightness, clear plastic, the sweep, nothing).
Three things the pictures taught:

- SVGF divides the light by the albedo and filters that. Here the clear coat's white reflection,
  divided by a saturated blue's red channel, came back fifty times over and turned the white print
  on a minifig's overalls pink. The light is filtered as it is, and the albedo is an edge stop.
- An edge out of focus is a band of pixels, each a mean of the part and what is behind it, from 1
  to 5 samples. By luck some are all part and some all backdrop, and their guide is as noisy as
  their light. Every stop held them apart, and the blurred edge stayed torn. Where the halves of
  most pixels round a pixel met different kinds, only the light stops the filter, in units of how
  the band's light varies. A print's line is two pixels wide, a third of those, and stays sharp.
- Each pass is drawn in bands of half a megapixel. On this box's card a pass over 2 Mpx takes
  9-27 ms in all, so about 100 ms on a mid laptop's card.

**Never worse.** Best in a browser draws Best's frames averaged first (10% of the bar) and keeps
showing them while the trace refines behind ("Path tracing behind this picture: N of 256 samples").
Each second the page measures what the denoise leaves on the model (`PageTracer.gauge`: the halves'
noise after the passes, relative to the light, over a 4x4 grid of every 16x16 pixels). The cells
are copied into a buffer behind a fence and read a second later, once the card has drawn them, so
the page's thread never waits on the card for the measure (read at once, the traced page on
SwiftShader was held 2.4 s once); an older measure is grainier, so the switch only comes later.
The end's decision measures and reads at once. It shows
the traced picture only once that is under `StudioRender.TRACED_NOISE`, and then says "Path
traced, still refining". Finish now, a lost context or the end keep whichever picture is better,
and the result says when it kept the frames.

**The judge** (pool g29: photoreal16's solo judge, 6 trials x 8 rounds, the ten shots). Each shot
was drawn as a mid laptop's 5, 15 and 30 s leave it (f28's sample counts at a sixth, a half and
all of them; `laptop29.sh`, one `gpu --brief` job a shot), then denoised. d is the light stop at 8
standard deviations, e at 4.

| label | close-ups | sets |
| --- | --- | --- |
| raster | 0.047 | 0.033 |
| d, 5 s | 0.450 | 0.031 |
| d, 15 s | 0.587 | 0.036 |
| d, 30 s | 0.600 | 0.046 |
| e, 30 s | 0.653 | 0.049 |
| tracer, 256 samples | 0.655 | 0.057 |

Against the raster, shot by shot, both 30 s arms are ahead beyond the interval on every shot. The
sets with e: +0.010, +0.015, +0.036 and +0.003. With d: +0.011, +0.007, +0.022 and +0.010. f28's raw
30 s sets had scored 0.032 against the raster's 0.033. At 30 s, e on the close-ups is the tracer at
256 (0.653 against 0.655). grey_1x3, f28's worst at -0.502, scores 0.884 against 256's 0.824.
At 5 s a set has one sample. Two sets are below the raster (-0.004 and -0.005, beyond the
interval) and two tie it. So at 5 s those sets must keep the frames.

**Where to switch.** With d, every draw that left 0.059 or less (`laptop29`'s measure, the app's
own) scored at or over the raster: at 15 s the sets by +0.001 to +0.005, at 30 s by +0.007 to
+0.022. Every set's first sample left 0.166 or more. So `TRACED_NOISE` is 0.1, and at a mid
laptop's pace a set switches at its second or third sample. A close-up switches at its first
measure (0.010 to 0.032 at 5 s), and so does the clear round (0.033, +0.009). red_slope's first
sample left 0.218 and scored +0.103: it keeps the frames a few seconds longer than it had to.
Pool h29 judged e at 5 and 15 s too. There set_6532 at 15 s was 0.002 under the raster (beyond
the interval) though it left only 0.043, where d's draw left 0.040 and scored +0.005. e is ahead
at 30 s, but no level of e's noise separates its draws as cleanly. So the page filters with d
(`DENOISE_TUNE`, light stop 8).

Bar by bar: the 30 s draws, denoised, beat the raster beyond the interval on every close-up and
every set. What Render shows at 5, 15 and 30 s is the raster where the trace left over 0.1 and the
trace where it left under, and in g29 every one of those scored at or over the raster. The first
screen is the same 220 scripts and 7,390,694 bytes. Sheets: `sheets/grey_1x3.jpg`,
`sheets/set_6532.jpg`, `sheets/red_slope_2x4.jpg` (the raster, raw and denoised at 30 s,
denoised at 5 and 15 s, and 256).

What is left. The à-trous leaves a faint grid in a shadow on white at 5 samples. An edge out of
focus is softer than raw but still not smooth. Both show only at twice the judge's size. The
desktop's Best still has only the 7x7 pass. It traces at 256 on a card that traces rays, so it
does not need this, but it could use the same filter for Finish now.

## 5ae. A whole set beside its photograph: the scene first, then a high-key exposure (photoreal30)

**The tells.** photoreal16's solo judge on the four sets, today's desktop Best (pre261) over four
draws, 192 verdicts (pool p1, `bench/results/photoreal30-2026-11-27/scripts/tells30.py`). The share of
verdicts naming each, render tells:

| tell | share |
| --- | --- |
| plastic pristine, no wear or dust | 0.99 |
| shadow soft, idealised | 0.95 |
| backdrop a seamless white | 0.94 |
| plastic one flat colour and gloss | 0.94 |
| seams between parts too even | 0.74 |
| no sensor noise | 0.63 |
| edges crisp, bevels identical | 0.58 |
| light even, CG | 0.52 |
| clear parts glassy | 0.48 |
| focus, depth of field | 0.44 |
| minifigs | 0.40 |

Looked at beside the photographs, three things were wrong before any look: 6532's model stood 6%
too large and to the left of where its photograph has it; 6657's photograph is lit by a hard sun
from behind and to the right, its shadow falling to the left, where ours came from the other side;
and every white part was darker than the photographs'. On 6660's door the photograph reads 254, 249,
237 and ours 215, 213, 200 (the card metered at `PHOTO_EV` draws a white part's lit side at L 86; the
photographs have theirs at the paper's own white, as a high-key product photograph does). Two tells
are the models' own and left: 6660's antennas stand up where the photograph's lie back, and the
photographed minifigs face the camera.

**The scene first.** `tools/photoreal/shots.json` now has the photographed sets (thirty years old)
played with (`"plastic": "played"`, Render's own Played with) and 6532 framed as its photograph (zoom
1.461, shift -0.023, 0.008, from the model's box in both). 6512's picture is a render and stays New.
6657's daylight turned to 230 degrees cast its shadow to the left as the photograph's falls, but the
daylight's sun is low where the photograph's is high: the shadow came out long, a glare ran along
the nose, and the judge put 6657 lower in both pools that had it (pool p5, the same draws with and
without: 0.16 against 0.23; p4, fresh draws: 0.147 against today's 0.219). So its light stays as it
was.

**Then the looks** (pool p2: 3 trials x 3 rounds, four draws an arm, the photographs and
photoreal29's tracer at 256 in the same pool; the sets, mean p):

| arm | sets | against the scene matched |
| --- | --- | --- |
| photoreal29's tracer at 256 (g29: 0.057) | 0.059 | |
| today's desktop Best, today's bench | 0.161 | -0.066 (-0.192 .. +0.007) |
| c: the scene matched | 0.227 | |
| c + parts moulded 0.5 LDU under the grid | 0.190 | -0.037 (-0.130 .. +0.022) |
| **c + half a stop high-key** | **0.316** | **+0.089 (+0.015 .. +0.177)** |
| c + a whole stop | 0.176 | -0.052 (-0.225 .. +0.067) |

- **High-key** (`RenderSettings.high_key`, `StudioRender.PRODUCT_HIGH_KEY` 0.5, `_meter_card`): the
  card where the model stands is metered half a stop past `PHOTO_EV`. 6660's door draws 227, 226, 221.
  It took "plastic one flat colour" from 0.98 to 0.77 and "shadow idealised" from 0.97 to 0.76. A
  whole stop washed the colours out and lost what half had gained.
- **Only on paper.** Beside the close-ups (pool p3), half a stop greyed the black 2x4 on leather in
  every draw (0.64, 0.50, 0.77 to 0.15, 0.08, 0.17) and held the parts on white. A product
  photograph on a table is exposed for the table, so high-key is a paper backdrop's (`PAPER_WHITE`
  or lighter): on a coloured one the card is kept, and the three table close-ups draw byte for byte
  as pre261's.
- **Moulded under the grid** (`RenderSettings.clearance`, `PathTracer.clearance`, `_narrower`): a real
  brick is 7.8 mm on an 8 mm grid, so each part was drawn 0.5 LDU narrower across, about its middle,
  each instance's own transform (parts under 10 LDU across untouched). The slot showed, the judge
  did not move ("seams too even" stayed at 0.74), so `PRODUCT_CLEARANCE` is 0, a lever for asking.

**The bar** (fresh draws 21-24, 3 trials x 4 rounds, today's tracer at 256 as base; sets from pool
p6 on the final tree and bench, close-ups from p4, which 6657's light does not touch):

| | sets | 6512 | 6532 | 6657 | 6660 | close-ups |
|---|---|---|---|---|---|---|
| today's tracer at 256 (photoreal29's g29) | 0.061 | 0.036 | 0.090 | 0.079 | 0.041 | 0.651 |
| today's desktop Best (pre261) | 0.173 | 0.035 | 0.201 | 0.212 | 0.242 | 0.652 |
| photoreal30 | **0.399** | 0.036 | 0.633 | 0.233 | 0.694 | 0.669 |

Sets against today's tracer +0.337 (95% +0.076 .. +0.609), against today's desktop +0.226 (+0.008 ..
+0.444). Close-ups against today's tracer +0.018 (-0.056 .. +0.101), against today's desktop +0.017
(-0.008 .. +0.047): within. 6512's photograph is itself a render and nothing reads it as a
photograph, so it holds every column at about 0.036.

**What a person's render gained.** The bar's arms differ in the scene as well as the renderer: the
bench now plays with the three old sets and frames 6532 as its photograph, which Render already
offered. The renderer's own share is high-key's +0.089 (+0.015 .. +0.177) over the matched scene
(pool p2); the rest of the +0.226 over today's desktop is the bench matching its scenes. Compare
rounds on the same scenes from here on.

Sheets, each set's photograph beside today's tracer at 256, today's desktop Best and this round's
(draw 22), in `bench/results/photoreal30-2026-11-27/sheets/`: `set_6532.jpg`, `set_6660.jpg`,
`set_6657.jpg`. The first screen is
the same 220 scripts and 7,399,110 bytes.

What is left. The plastic is still read as pristine in nearly every verdict, played with or not,
and the shadow on white as soft. The photographs' sets show dust in the studs' corners and a matt
haze on the most handled faces that Played with draws fainter. photoreal29's à-trous filter is not
yet the desktop's: its raygen would sum the albedo, depth and even samples as page_tracer.js does,
and the five passes run as a compute shader before the resolve.

## 5af. The browser's denoise on the desktop, and the shadow on white (photoreal31)

**Not merged (NO-GO).** The filter and `floor_rise` below live on branch `photoreal31` (eb8fc82d5) only;
the app keeps the 7 x 7 and has neither setting. This section is the round's record.

Every arm here is drawn on photoreal30's bench (`tools/photoreal/shots.json` as photoreal30 left it:
the old sets played with, 6532 framed as its photograph, high-key on paper), at Best's 256 samples,
fresh draws 21-24 for the sets and 21-23 for the close-ups. Each arm is that file with one key added
to every shot. The judge is photoreal16's solo judge, 3 trials x 4 rounds (192 verdicts an arm on the
sets, 216 on the close-ups), base today's desktop Best (t31: pre261 with photoreal30 merged). Results and scripts are in
`bench/results/photoreal31-2026-11-27/`.

**The denoise built.** The raygen sums what the eye first met (its albedo and depth) and the even
samples apart, as page_tracer.js does (`path_tracer.glsl`'s `more` and `even`). page_denoise.frag is
a compute shader, `path_tracer_denoise.glsl`: the light and its variance from the two halves, five
à-trous passes 1, 2, 4, 8 and 16 apart between two pictures in turn, then the light and coverage,
seven dispatches. With the filter on, the resolve reads its output in place of `cleaned()`.
`tools/web/tracer_port.py` swaps the browser's in, and `tests/test_page_tracer.py` holds them. The
first draws had no filtered light: an untyped list given to a typed `Array[RDUniform]` dropped the
filter's uniform sets. The lists are typed now.

**Judged against today's 7 x 7** (the light stop is how far apart in the noise's standard
deviations two neighbours' light may be and still be averaged; the browser's is 8 at its 4 to 8
samples):

| arm | pool | sets | against t31 | close-ups | against t31 |
| --- | --- | --- | --- | --- | --- |
| a31: light stop 8 (the browser's) | p1, p2 | 0.110 | -0.293 (-0.553 .. -0.037) | 0.555 | -0.128 (-0.253 .. -0.019) |
| l4: light stop 4 | p3 | 0.164 | -0.227 (-0.439 .. -0.021) | | |
| l2: light stop 2 | p3, p4 | 0.357 | -0.034 (-0.252 .. +0.122) | 0.567 | -0.096 (-0.285 .. +0.049) |
| l1: light stop 1 | p3, p4 | 0.259 | -0.132 (-0.396 .. +0.007) | 0.579 | -0.083 (-0.288 .. +0.052) |
| t31: today's desktop Best | | 0.391 to 0.404 | | 0.663 to 0.683 | |

By shot (p3 and p4), l2 against t31:

| | 6512 | 6532 | 6657 | 6660 | black_2x4 | green plate | grey_1x3 | red slope | three_2x2_top | trans round |
|---|---|---|---|---|---|---|---|---|---|---|
| t31 | 0.035 | 0.590 | 0.234 | 0.706 | 0.658 | 0.804 | 0.777 | 0.894 | 0.772 | 0.071 |
| l2 | 0.033 | 0.748 | 0.290 | 0.357 | 0.490 | 0.815 | 0.907 | 0.888 | 0.233 | 0.069 |

At 256 samples the 7 x 7 leaves a faint grain on a flat face, and the judge reads it as a camera's.
At the browser's stop the filter takes it, and "no sensor noise" rose from 0.43 to 0.76 of the
verdicts, with the plastic read flatter. A lower stop keeps more of it. At 2 the sets tie within
the interval, with 6532 and 6657 up, but 6660 loses half (its verdicts name "studs lack logo") and
three_2x2_top loses two thirds (looked at close, the red top has scratch-like marks and specks the
7 x 7 draws fainter). No stop met the bar: no worse on the close-ups, and better
on the sets beyond the interval. So the desktop's Best keeps the 7 x 7 and the filter is a lever:
`RenderSettings.denoise_light` (`StudioRender.PRODUCT_DENOISE_LIGHT` 0, `PathTracer.denoise_light`).
At 0 the resolve takes a negative denoise as the 7 x 7's, and the filter's four pictures are a pixel
each, so a render that does not ask pays nothing for it (they are about 530 MB at 4k). Today's bench
drawn by default is byte for byte t31's, close-ups and sets, and asked for at 2 byte for byte l2's.
Asked for, the seven dispatches took 66.3 ms on the card at 4k (`pathtrace_probe`, which holds them
under 150 ms).

**The shadow on white.** Mapped in bands of lightness beside the photographs
(`shadow_bands31.py`), a photograph's shade is deepest right under the model and gone a little way
out. Ours is lighter under the body and a faint grey all round it, because the tent's walls and
boxes send light in low, from near the floor's horizon. That light reaches under a raised body and
greys a wide ring. `RenderSettings.floor_rise` (`photo_gloss.z`, `PRODUCT_FLOOR_RISE` 0) fades the
tent's light on the floor from nothing at the horizon to all of it at `FLOOR_RISE` (a sine of 0.5)
up, so the floor is lit from above, as the panel lights it. It is general, with no per-set light.

| arm | pool | sets | against |
| --- | --- | --- | --- |
| r31: a31 + floor_rise 1 | p1 | 0.115 | a31 +0.005 (twins of 4 identical pictures: -0.011, the pool tells 0.014) |
| s31: l2 + floor_rise 1 + floor_key 2 | p5 | 0.407 | l2 +0.043 (-0.011 .. +0.140) |
| t31 in the same pool | p5 | 0.396 | l2 +0.038 (-0.105 .. +0.246) |

The core under the body darkened and the ring cleared, and "shadow idealised" went from 0.69 to 0.64.
The sets did not move beyond their interval (6660 0.352 to 0.538, 6532 0.761 to 0.749, 6657 0.285
to 0.307), so floor_rise stays 0, a lever.

The bar's probes and flows are in FINDINGS.txt. Sheets, each photograph beside today's desktop Best and
this round's arm, in `bench/results/photoreal31-2026-11-27/sheets/`: `set_6532_l2_d21.jpg`,
`set_6660_l2_d21.jpg`, `set_6660_s31_d21.jpg`, `black_2x4_l2_d21.jpg`, `three_2x2_top_l2_d21.jpg`.

What is left. The tells the judge names on the sets are still the plastic's pristine faces (0.98),
the seamless white (0.95) and its flat colour (0.66), not the clean. A denoise for the desktop's
fewer samples (its window's Best while it gathers) may still take the filter, and is unjudged.

## 5ag. Light under the skin (photoreal32)

**Not merged (NO-GO).** The lever below lives on branch `photoreal32` (b604613d4) only; the app has
no such setting. This section is the round's record. Bench, base, judge and draws are photoreal31's
(5af): photoreal30's `shots.json`, Best's 256 samples, sets drawn 21-24 and close-ups 21-23, the solo
judge at 3 trials x 4 rounds, base today's desktop Best (t31). Results and scripts are in
`bench/results/photoreal32-2026-11-27/`.

**What the photographs' faces carry that ours do not** (measured on the bench's photographs beside
t31 at the judge's frames: `measure/`, `look/`, scripts `faces32.py`, `boxes32.py`, `shade32.py`):

- A colour's lightness spreads wider across a photographed part: the red slope's middle half spans
  5.9 L* in its photograph and 1.3 in ours; black_2x4's grey 16.0 against 7.1.
- A photographed red keeps its hue as it lightens (h 37 to 45 from L* 10 to 70 on the red slope, 37-39
  on three_2x2_top's). Ours turns pink in its lightest pixels (h 31 and 27 at L* 60-80 on the slope,
  32 in three_2x2_top's lightest tenth). A lit yellow is lemon in ours (h 96-100 on 6512, 6532 and
  6660, against 89-95 in the photographs); 6532's and 6660's shaded yellows are amber in the
  photographs (h 72-77) where ours are 77-83, though 6512's go the other way.
- Flat tops carry a finer texture: black_2x4's black 2.1 times ours, grey_1x3's white 3 times. The red
  slope's moulded grain is the other way round (ours 1.5 times the photograph's).
- At a set's scale (`look/c6660_door.jpg`): dust specks and a fibre on 6660's windscreen, a lit white
  edge soft and luminous, faint seams. Ours has crisp edges, darker seams and a spotless windscreen.

**Built: light under the skin.** ABS is lit from inside. Light goes in under the clear skin, scatters
off the pigment and comes out a little way off, so a shade's edge softens in the part's own colour
and a white stays bright in its shade. At the eye's first plastic hit, a share of the samples
(`RenderSettings.subsurface`) light the hit at a point drawn round it from Burley's normalised
diffusion (2015). Its mean free path is `subsurface_reach` LDU over 1.85 - A + 7|A - 0.8|^3 for each
channel's albedo A, so a red's fringe is red and a white's is wide. A short bare probe finds that
point on the part's own skin. The body's diffuse is weighed there by the profile over the draw's
chance, and the gloss is lit there too, a hair from the hit. A point past an edge finds no skin, and
the hit lights itself. The browser's port takes the same code. It is general, has no per-set
content, and at 0 draws no random number. Lit the first way (the gloss at the hit, the body under the
skin, two lights a sample), a set took 1.4 to 1.8 times as long.

The second form also made the desktop's shadow rays, the walk through clear parts and the probe
bare. They ran the whole closest hit (moulding, logos, grain) only to be told whether something
was there; the closest hit now returns at once when the payload asks for a bare hit, as the port's
walk already did. Today's bench drawn with the lever at 0 matches t31 to within 1/255 on a few
pixels (6512, 6532 and 6660 on one to three rows; three_2x2_top 0.025% of pixels, at most 2). The shader's
arithmetic was reordered. The six other pictures are byte for byte. The car did not get measurably
faster.

**Judged** (pool s1 the sets, c1 the close-ups; u3 and u6 the lever at 1 with reach 3 and 6 LDU):

| arm | sets | against t31 | close-ups | against t31 |
| --- | --- | --- | --- | --- |
| t31: today's desktop Best | 0.318 | | 0.696 | |
| u3: reach 3 | 0.268 | -0.051 (-0.119 .. +0.003) | 0.668 | -0.028 (-0.088 .. +0.019) |
| u6: reach 6 | 0.309 | -0.010 (-0.058 .. +0.036) | 0.686 | -0.009 (-0.044 .. +0.022) |

By shot: 6532 0.459 / 0.318 / 0.386 (t31 / u3 / u6), 6660 0.555 / 0.487 / 0.596, 6657 and 6512
level; black_2x4 0.744 / 0.592 / 0.676, three_2x2_top 0.789 / 0.715 / 0.734, the grey, green and
red slope a hair up. trans_round, which has no opaque plastic, drew byte for byte in all three arms
and scored within 0.003 (the pool tells 0.005 apart). The tells on the sets did not move: plastic
pristine 0.99 / 0.98 / 0.97, uniform colour 0.82 / 0.89 / 0.83, seamless white 0.92 / 0.94 / 0.92.

**Why it moved nothing.** At the judge's 1024 pixels a set is about one LDU a pixel. The profile
softens a shade's edge by a pixel or two, and the studio's light is broad, so a face's light barely
changes across it. A set drawn with it at reach 6 differs from t31 by 0.36 to 0.83/255 on average,
as t31's own draw 21 differs from its draw 22 (0.36 to 0.90). On the close-ups (ten pixels an LDU) the stud's shade side and the
slope's grain soften, and black_2x4 and three_2x2_top read a little less real. The probe looks only
along the hit's normal, so the light that goes round an edge (a lit face glowing into the shaded
face beside it, the clearest sign of a translucent part) is left out, by design of the cheap probe.

**Time.** The car at Best (`photoreal_probe --car --car-under --car-reach`, interleaved with
pre261's, two rounds, median of three): pre261 5.42 and 6.69 s, the branch at 0 5.95 and 7.22,
reach 3 5.47 and 7.40, reach 6 5.65 and 11.68. The box drifted between rounds. The sets, not
interleaved, against t31's draws: reach 3 1.29 times, reach 6 1.45 times. Both are over the 1.15 bar
on the sets.

**Browser and desktop.** The page's tracer (tracer_port.py's GLSL ES with page_tracer.js's packing,
run on the card through EGL as in photoreal28) drew the red slope at reach 6 from the desktop's own
capture, 256 samples. The two agree in the mean (each channel within 0.3/255) and by eye, but differ
by 2.1/255 a pixel, 13% of pixels by more than 8, where photoreal28's pair differed by 0.05 to 0.09.
Averaged over 4 to 16 pixel blocks they differ as two desktop draws of the shot do (0.75 to 0.40
against 0.75 to 0.25): the same picture from parted random streams, not a bias. A control at today's
defaults was queued on the card and stopped unrun. Nothing merges, so this bar decided nothing.

**Next.** The largest measured gaps are not in the plastic. A colour's lightness spread and hue in
the light come from the light and the camera's curve: the reds' pink and the yellows' khaki are
where the light is strongest. The plastic's next step is the light that goes round an edge: probes
along the two tangents as well as the normal (King et al. 2013), with the edge's own normal there.
At a set's scale, dust and fine scratches on clear parts are what a windscreen shows. A hazed
windscreen was tried in handled plastic (5u) and moved no set; sharp specks were not.

## 5ah. A shelf's dust, and the window a part mirrors (photoreal33)

The lead's read of photoreal32's black_2x4 sheet named five tells, largest first: the room a black
part mirrors, wear, edges, focus, the floor. This round measured all five on the bench, built the two
largest, and judged them as photoreal31 did (5af): photoreal30's `shots.json`, Best's 256 samples,
sets drawn 21-24 and close-ups 21-23, the fixed solo judge at 3 trials x 4 rounds, base today's
desktop Best (t31, still pre261's renderer). Results and scripts are in
`bench/results/photoreal33-2026-11-27/` (`measure/`, `sheets/`, `solo_*`).

**Measured** (photograph against t31 at the judge's frames; `scripts/measure33.py`,
`tools/photoreal/reflect_measure.py`):

| tell | measure | photograph | t31 |
| --- | --- | --- | --- |
| 1 the room mirrored | black_2x4 top over its side | +7.42 stops | -1.22 |
| | green_plate's top over its side | +3.05 | -1.04 |
| | black_2x4's top, L* | 65 | 12 |
| 2 wear | the sets' fine texture, sd of L* a 2 px blur takes out (6532 red, yellow, blue; 6660 red, blue) | 2.8, 1.0, 4.0; 1.7, 1.6 | 1.4, 1.4, 1.9; 1.4, 1.8 |
| | the judge's set verdicts calling the plastic clean | 0.00 | 0.75 |
| 3 edges | the line of light along an edge, px wide (grey_1x3's top edge; three_2x2_top's stud rim) | 10.2; 3.5 | 3.9; 2.1 |
| 4 focus | an edge's width behind the part over on it (black_2x4; green_plate) | 1.95; 4.33 | 0.87; 3.09 |
| 5 floor | black_2x4's leather, thin dark lines (ridge p90/p50) | 5.5 | 25.7 |

The room is the largest gap by far on the two close-ups photographed by a window; the studio table
(red slope, +1.77 against +1.47) and the daylight grey 1x3 (+0.95 against +1.18) are near their
photographs already. On the sets the judge's commonest tells after the white background are "no
dust or scratches" and the clear parts.

**Built: dust specks on played plastic** (path_tracer.glsl `mote_at`, `mote_amount`). A set that has
stood on a shelf carries sharp grit and fluff a tenth of a millimetre to half a millimetre across on
every top and windscreen, where photoreal4's soft dust film is never a point. One speck in a 2 LDU
cell's chance, its size and pale or dark colour from the cell's hash and the part's own number, laid
flat on the face it lands on. Its amount is the dust asked for times the age squared: Played with
(age 1, dust 0.4) has them all, a new part none, the close-ups' slightly aged parts (age 0.3, dust
0.5 to 0.6) a ninth to a seventh as many.
Tops take them, sides an eighth as many, a clear part's skin 0.6 as many, where it hides what is
behind it. The browser's port takes the same code. Three bugs found on the way:

- A speck was a sphere kept inside its cube, and a part's faces lie on whole LDU, on the cubes'
  sides: no speck met a face. It is now measured across the face, on a grid set off whole LDU.
- `surface_of`'s normal is the triangle's as its file wound it, out of the part or into it; a speck
  asked for one facing up and met none on the 6660's hood. A level face now takes them either way.
  photoreal4's dust film reads the same normal the same way and so lies on only some tops; it is
  left as the judge has seen it all along (a next step to measure).
- A clear part's scratches were read at whatever its mirrored ray met, not at the glass.

**Built and taken out: the window's room mirrored.** photoreal14's large source (5r), on by default
on a studio table, was given to the window and daylight places. Daylight lost its sun's shadow (the
6657) and blackened the grey 1x3's sides, so it went at once. By the window it closed the measured
gap: black_2x4's top +6.07 stops over its side (photograph +7.42), green_plate's +2.52 (+3.05). The
judge then read the black 2x4 as a render in 36 of 36 verdicts (t31: 3 of 36; 0.72 to 0.03). Its
logos, legible at last, were called mirrored in 34 (they are not, 5ab), and its top a CG mirror in
25: one flat white, where the photograph's has a gradient across it and its studs' tops mirror the
window too. The green plate rose a little (0.84 to 0.90). It is not kept.

**Judged** (s1 the sets; c1 the close-ups; b33 the specks with the window source, c33 the same with
specks up to 1 mm in a 3 LDU cell, branch `photoreal33c`; d33 the specks alone, this branch):

| arm | sets | against t31 | close-ups | against t31 |
| --- | --- | --- | --- | --- |
| t31: today's desktop Best | 0.302 | | 0.679 | |
| b33: specks, window source | 0.631 | +0.328 (+0.105 .. +0.474) | 0.640 | -0.040 (-0.310 .. +0.117) |
| c33: larger specks, window source | 0.647 | +0.345 (+0.106 .. +0.534) | 0.567 | -0.112 (-0.358 .. +0.047) |
| d33: specks (pool c1d, its own t31 0.687) | (b33's pictures) | (b33's) | 0.784 | +0.097 (+0.068 .. +0.127) |

By set (t31 / b33 / c33): 6532 0.459 / 0.877 / 0.895, 6657 0.225 / 0.723 / 0.814, 6660 0.491 / 0.887 /
0.846; 6512, new plastic and so speckless, drew byte for byte in every arm and scored 0.035 in each.
The judge names what it sees: "dust specks on the dump bed and tires", "uneven scuffed gloss on the
red". The share of set verdicts calling the plastic clean (`scripts/pristine33.py`, which reads
"clean" only of the plastic) fell from 0.75 to 0.28 (b33) and 0.25 (c33), and those naming its age
as a photograph's evidence rose from 0.29 to 0.71 and 0.75. No set is lit by the window, so d33's
sets are b33's, byte for byte (drawn again at draw 21 to be sure), and b33's set result is d33's.

By close-up (t31 / b33 / c33): black_2x4 0.722 / 0.032 / 0.032, green_plate 0.839 / 0.902 / 0.891,
grey_1x3 0.781 / 0.926 / 0.842, red slope 0.887 / 0.923 / 0.924, three_2x2_top 0.767 / 0.846 /
0.606, trans_round 0.080 / 0.210 / 0.109. The larger specks read as blobs on three_2x2_top's tops.
d33 against its pool's t31, every close-up higher: black_2x4 0.868 / 0.741, green_plate 0.916 /
0.821, grey_1x3 0.923 / 0.818, red slope 0.927 / 0.885, three_2x2_top 0.849 / 0.777, trans_round
0.219 / 0.079 (photographs 0.97, 0.95, 0.95, 0.92, 0.87, 0.89). Close-up verdicts calling the plastic
clean fell from 0.20 to 0.04.

**Time.** The car at Best (`photoreal_probe --car`: Product, 1280x720, 256 samples, three renders a
run), pre261 and this branch interleaved, three rounds: pre261's medians 5.10, 5.51 and 4.80 s, the
specks' 4.77, 5.06 and 5.30 s (0.98 times). A new part asks for no speck and `mote_at` returns at its
first line. A first timing ran against a pre261 snapshot whose `.godot` was copied from this branch's
tree, so its imported tracer was this branch's (an imported RDShaderFile is what runs, not the
`.glsl`); it is not counted. `scripts/snap33.sh` now takes `SNAP_FROM`, and pre261's snapshot copies
the pre261 worktree's import.

**The browser's Best and the desktop's agree** (`scripts/pair33.sh`: what the desktop gave its tracer
at draw 11, packed as `page_tracer.js` packs it, run through `tracer_port.py`'s GLSL ES on the card at
256 samples): black_2x4 differs from the desktop's by 1.6/255 a pixel on average and 0.26/255 over
16 px blocks, set_6660 by 0.15/255 and 0.13/255, every speck in the same place on the hood and the
windscreen (`sheets/pair_*_desktop_page.jpg`). The port needed no change.

`render_open_check`'s first open (the Render dialog's draft in a software-drawn browser, budget 250
ms a frame) ran over by 2 to 97 ms on the final export in 6 of 7 turns, and pre261's export, run at the
same moment, over by 49 ms in 1 of 4: the longest frames 192 to 347 ms against 211 to 299. The draft
links the same six programs at the same sizes in both, and the page's tracer is not fetched until
Best is asked for, so nothing this round changed runs in it; the frames wait in `getParameter` on
the browser's GPU process, with the box loaded by other projects' runs.

**Checks** from a locked snapshot of the final code: pathtrace_probe 20 ok, product_render_probe 18,
render_probe 55, lights_probe 102, motions_render_probe 33, none failed. source_probe fails only on
its time, the car's Best on a table under an absolute 2.9 s: run beside pre261's snapshot, the final
code went over on one table of four (the desk, 3.51 s), pre261 on three (the desk 3.44, leather 3.30,
terrazzo 3.18); every other check passed in both (30 and 28 ok). `product_render_flow` fails the same four checks as pre261 (the red glass 0.39, 0.39 and 0.33% red
against 0.5%; on white the model 1.5% of the picture against 2%).

**Next.** The window's room is still the largest measured gap, and a source alone is not it: the
photograph's top mirrors a window with a gradient across it and a stud's top mirrors it too, where
ours drew one flat white and black studs. The leather's cells are named in 34 of t31's own 36
black_2x4 verdicts, though they called it a photograph. Then the dust film's tops (above) and the
edges' line of light.

## 5ai. The window a part mirrors, as a room, and the leather's grain (photoreal34, not kept)

This round built 5ah's two "next" tells, the window room and the leather, and judged each against
today's desktop Best (d33, pre261 with photoreal33) as 5ah did: Best's 256 samples, close-ups drawn
21-23, the fixed solo judge at 3 trials x 4 rounds. Neither is kept: the room lost by far, the
leather changed nothing the judge could see. Results, sheets and both levers as patches
(`window_room34.patch`, `leather34.patch`) are in `bench/results/photoreal34-2026-11-28/`.

Only the black 2x4 and the green plate stand on a table under Window light, and only the black 2x4
on leather; red_slope_2x4 was drawn in every arm at every draw and came out byte for byte d33's, and
no set stands on a table or in the window's light. So each lever was judged on the shots it changes.

**The room** (`tools/photoreal/room_by_window.py`, kept as a bench tool). The loft hall is
photographed from the middle of its room: its windows reach 23 degrees up, and a camera looking down
at 40 degrees sees a level top mirror the plaster above them (0.27 times the panorama's mean). The
tool draws the panorama again from a table by the window: the room taken as a box of the size its
photograph shows, each way from the table met with the box's walls, the photograph read where that
point of the wall is, and turned so the window stands behind the model, a little to its left, as
StudioRender's turn puts it whatever the camera's heading. The sun through that window (800 against
a sky of 50 to 100) is clipped to the sky's level, or it puts a hard glint on every satin stud top.
How near the window is was set by the photographs: from 1.2 m the window lit the table less, the
exposure rose to meet it, and every top mirrored the sky at white (the black 2x4's top 0.97, the
green plate's 0.84; photographs 0.32 and 0.35); from 0.6 m the tops measure as the photographs do:

| measure (draw 21) | photograph | d33 | the room at 0.6 m |
| --- | --- | --- | --- |
| black_2x4 top over its side | +7.42 stops | -1.22 | +5.41 |
| black_2x4 top | 0.32 | 0.01 | 0.50, a gradient across it |
| green_plate top over its side | +3.05 | -1.04 | +2.49 |
| green_plate top | 0.35 | 0.14 | 0.36 |

The judge (pool cu34, 72 verdicts an arm) called it a photograph far less: 0.203 against d33's 0.889,
-0.686 (-0.824 .. -0.536). The black 2x4 was called a photograph in 0 of 36 verdicts (d33 36 of 36):
its top and studs "chrome-like", "mirror-chrome", and its logos, now legible, "mirrored" in 33 (they
read as the photograph's do: `sheets/logo_*`). The green plate fell from 36 to 12, its top grey under
a sheen that covers the whole plate, where the photograph's sheen lies over part of a green top.
Measured right and judged wrong: in the photograph the stud tops stay dark while the top around them
shines, where ours mirror the window as brightly as the top does (why theirs stay dark is not
measured here). A window mirrored at the photograph's strength is
not, alone, what makes a black brick read as a photograph; d33's dark top already does.

**The leather** (`table_height` and `table_paper`, kind 2). 5ah's cells had creases cut a cell's width
in, thin dark lines round every cell (ridge p90/p50 25.7, the photograph's 5.5). Here the pebbles are
1.6 mm across, fall softly into shallow creases, and the larger are parted again by finer creases at
0.45 of the size; the colour darkens a little in the creases. Ridge 12.2. Judged alone (pool le34, the
black 2x4 on the loft hall as before, 36 verdicts an arm): 0.880 against d33's 0.881, -0.001 (-0.016
.. +0.016); both called a photograph 36 of 36, the floor named as a pattern in 17 verdicts against
21. Free, and no gain the judge can show while d33's black 2x4 is called a photograph every time.

**Not reached:** the edges' line of light and focus on the close-ups. The close-ups judged here are
near their photographs already (d33 0.88 to 0.89 against the photographs' 0.96 to 0.97); the sets
(0.63, 5ah) hold the room to grow, and in photoreal33's set verdicts the white seamless background,
clean plastic and even light are named far more than edges (about one in five).

## 5aj. ABS mirrors blurred: the photograph's width, and what it costs (photoreal35, not kept)

5ai's room had the photographs' brightness and the wrong sharpness: the judge called the black 2x4
"chrome". This round blurred what moulded ABS mirrors to the photograph's width and judged it as 5ai
did (d33 the base, draws 21-23 for close-ups and 21-24 for sets, 3 trials x 4 rounds). It is not
kept. The lever is `bench/results/photoreal35-2026-11-28/gloss_blur35.patch` (with 5ai's room and
leather under it).

**The lever.** A least roughness for moulded ABS's skin (`RenderSettings.gloss_blur`, in the scene's
free `marks.y`), added to each face's own roughness as two blurs add (`(r^4 + b^4)^(1/4)` in GGX
alpha), so a handled patch or a stud's satin top stays rougher. A slope's moulded grain kept its
own: blurred, its glints went and the face read flat. At 0 the pictures are byte for byte 5ai's.

**The width, measured** on the black 2x4 in 5ai's room (draw 21; `breakup_measure.py`'s mirrored
stud: how many pixels the stud's mirror image takes to go from dark to the top's level):

| gloss_blur | stud mirrored, side | stud mirrored, foot | top | green plate top edge |
| --- | --- | --- | --- | --- |
| photograph | 7.3 px | 14.0 px | 0.33 | 7.3 px |
| 0 (5ai) | 1.6 | 9.4 | 0.50 | 3.6 |
| 0.15 | 2.0 | 11.6 | 0.59 | 4.0 |
| 0.20 | 2.8 | 12.4 | 0.64 | 4.8 |
| 0.30 | 4.6 | 14.0 | 0.62 | 5.6 |
| 0.40 | 7.5 | 14.6 | 0.49 | 6.4 |

0.35 was judged. Two arms: s35, 5ai's room with the blur; u35, the blur on the loft hall as pre261
draws Window light. No set stands by the window, so the sets were judged once (s35).

**Judged** (pools cu35, oc35, st35):

| pool | d33 | arm | against d33 (95%) |
| --- | --- | --- | --- |
| black 2x4 + green plate, s35 (room + blur) | 0.896 | 0.359 | -0.537 (-0.824 .. -0.225) |
| black 2x4 + green plate, u35 (blur alone) | 0.896 | 0.899 | +0.004 (-0.005 .. +0.015) |
| the other four close-ups (s35 = blur alone there) | 0.729 | 0.575 | -0.156 (-0.435 .. -0.002) |
| the four sets | 0.635 | 0.653 | +0.018 (-0.005 .. +0.057) |

The blur took "chrome" off the room: 0 of 36 verdicts on the black 2x4 (5ai: 30). But the room's
black 2x4 was still called a photograph 0 of 36 times (5ai: 0): its top is a pale satin grey under a
window that fills it, its logos are lit and "mirrored" in 31 (they face as the photograph's do:
`sheets/black_2x4_logos_photo_s35.png`), and the leather, lit by the window too, is "procedural" in
17. The green plate fell from 36 to 26 under a milky haze.

Without the room the blur changed nothing the judge could see on the window close-ups, and cost the
top-down studio shot its gloss: three_2x2_top 0.849 (36 of 36) to 0.277 (1 of 36), "plastic looks
matte, without real gloss", "uniform flat lighting". Its photograph shows small crisp glints of the
softbox on the stud rims; blurred to the black 2x4's width they spread to nothing. grey_1x3 went
0.926 to 0.879. One set gained: 6657, daylight, 0.741 to 0.816 (its d33 verdicts name "fairly
uniform gloss on the red bricks"); the other three held.

What this says. The photographs disagree with a single roughness: the black 2x4 mirrors a stud
softly, the three 2x2s mirror a softbox crisply. One haze for all ABS can match one of them. And
sharpness is not what makes today's renders read as renders: of d33's 408 verdicts here, 5 name
gloss, a sheen or a reflection at all. They name the background (318, which the photographs share),
clean plastic (327) and even light (165).

Where the gap is, for a later round (d33 against its photograph, this round's pools):
trans_round_1x1 0.21 against 0.90, its tells a faceted, polygonal cylinder silhouette (11 of 36),
idealised refraction, no contact shadow, and a bright cyan where the photographed part is a dark,
aged teal; set_6657 0.74 against 0.95; the black 2x4 0.88 against 0.97. set_6512 is at its ceiling:
its reference is itself a render (0.04, ours 0.04). Edges were named on close-ups only for the
transparent round's facets, and focus only on it and 6512, so 5ah's line of light and focus on
close-ups were not built.

Best's time is unchanged: the car at 256 samples 5.39 s against pre261's 5.73 (medians of three
runs each, interleaved).

## 6. Web and desktop

- **Desktop (Forward+):**
  - Product in full.
  - Then Cycles as a fourth grade when Blender is installed (R2).
- **Web (Compatibility):**
  - Product's shaders, rig, film curve and backdrops, without SDFGI, AO or
    clear coat.
  - Best path traced in the page on the visitor's own card, by the desktop's
    shaders ported to WebGL2 (photoreal28, section 5ac); frames averaged
    where the browser has no card or no float targets.
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

Each says what it does and the bar it must reach. What Best's own look
still lacks beside real photographs, ranked by how often a blind judge
named it, is in section 5e's last list. Those come first: the bar for each
is a lower pick rate on `tools/bench/photoreal.py` than a same-day before.

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
