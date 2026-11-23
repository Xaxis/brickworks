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
