---
tools: make_art, brickify, look_at_picture
panels: MosaicDialog#mosaic, BrickifyDialog#brickify
ai: A picture laid as a mosaic of plates and round tiles, as LEGO® Art sets are, and any 3D model (OBJ, STL, PLY, 3MF, VOX, FBX, glTF, GLB) laid in bricks. An assistant lays a mosaic with make_art (it replaces what is on the baseplate) and a 3D model with brickify (a job), and can bring either in from a link. in_view shows it the reference picture, where it lies, and the model drawn on it.
rules:
  - A mosaic panel is 16 x 16 studs; make_art takes 1 to 6 panels each way.
  - brickify's size is studs along the model's longest side, 6 to 64 (24 when not said).
  - A file fetched by link is at most 96 MB on the desktop, and 4 MB in a browser, where Brickworks's own site fetches it.
title: Mosaics, brickify and a picture to build over
nav: Mosaics and brickify
description: Turn a picture into a mosaic, as LEGO® Art sets are, turn any 3D model into bricks, and lay a picture in the scene to build over.
---

Three things start from a picture or a 3D file, all in the **Make** menu: a mosaic laid in plates and tiles, a 3D model laid in bricks, and a picture to build over.

## Mosaic from a picture {#mosaic}

![The Build this picture panel in Brick Art: a fox laid in 3 x 3 panels of round and square tiles above, with Panels across and down at 3, Depth, the texture choices, and what it comes to in studs, centimetres and parts.](/docs/img/art-brick-art.webp "Brick Art: the picture as LEGO® Art sets lay one, panel by panel.")

1. **Make › Mosaic from a picture…** and choose a picture.
2. Choose how it is laid:
   - **Brick Art**, the default, as LEGO® Art sets are: **Panels across** and **down** (each 16 x 16 studs, up to 6 each way), **Depth** (what stands out raised up to 6 plates), and round tiles, quarter circles along curves, smooth tiles where it is flat and **Accent stars**, each on or off.
   - **Classic**: plates, flat, **Width** 8 to 96 studs. **Mixed plate sizes** lays each run of one colour in the largest plate it fills, up to 8 x 8, so it takes far fewer parts; off, a 1 x 1 on every stud.
3. **Colours**: **All colours**, **A set's colours** (type its number, and only the colours of that set's parts are used), or **What I own**, from [My collection](/docs/collection). **Blend colours** mixes nearby studs to suggest a colour there is none of.
4. To build part of the picture, press **Crop** and drag a rectangle; **Whole picture** takes it all again.
5. **Build it**.

The panel says, as you change it, its size in studs and centimetres and what it comes to. Then the parts list ([[P]]) has what to buy, with a Pick a Brick file.

<!-- covers
ui:mosaic
lib:LEGO Art layout
lib:LEGO Art plans
-->

![The same panel in Classic, its colours from set 21178: the fox laid in plates in that set's colours, with the set's swatches under its number.](/docs/img/art-classic.webp "Classic, in the colours of one set's parts.")

### Designed with Claude {#art-with-claude}

With the assistant on, **Design with Claude** in the panel has Claude lay the picture itself, keeping to your crop and colours (`make_art`).

<!-- covers
ui:LEGO Art designed by Claude
-->

## Brickify a 3D model {#brickify}

![The Brickify panel for a fox model: the fox laid in bricks turning in a picture, Size 24 studs, Scale, Up, Hollow, A stand where it needs one, Surface, Colour and the Brickify button.](/docs/img/art-brickify.webp "Make › Brickify a 3D model… (Ctrl+I): its choices, and what they come to.")

1. **Make › Brickify a 3D model…** ([[Ctrl+I]]) or **File › Import › 3D model to brickify**, and choose a sculpt, a scan or any 3D file: OBJ, STL, PLY, 3MF, VOX, FBX, glTF or GLB.
2. Set its **Size**, 6 to 64 studs along its longest side, and which way is **Up** if it lies on its side. The panel says what it comes to in studs, bricks and centimetres.
3. Choose **Hollow** or solid; **A stand where it needs one** (on unless you untick it) for a model that would tip; **Surface**, **Smooth** (slopes, curves, tiles and studs sideways) or **Plain bricks and plates**; and **Colour**: its own, one colour, or its own in at most so many (1 to 12). **Lay it from my collection** uses the parts you own first.
4. **Brickify**.

It goes down beside the model as one sub-assembly named after the file, of real parts that hold together, built in steps from the ground up. The panel then offers its **Booklet**, a **BrickLink** or **Rebrickable** list, and **What do I need?**.

<!-- covers
ui:brickify a 3d model
lib:brickify
lib:3d model files
lib:brickify from a collection
lib:brickify steps
-->

![The fox brickified on the baseplate, in orange, white and black bricks with slopes along its back, and Booklet, BrickLink, Rebrickable and What do I need? in the panel.](/docs/img/art-brickified.webp "The fox, brickified at 24 studs.")

### From a link {#brickify-link}

An assistant you connect can bring a model or a picture in from a link to the file itself. In a browser the site fetches it for you: sign in, a file up to 4 MB, on the open web. When a link brings nothing, Brickworks says why. A bigger file you save first, then bring in with **Make › Brickify a 3D model…** or **Make › Print on a part…**.

<!-- covers
api:POST /api/account?op=fetch
lib:words for a failed request
-->

## A picture to build over {#reference}

**Make › Reference picture…** ([[Alt+N]]) lays a photo, a plan or a drawing (PNG, JPEG, WebP, BMP or SVG) in the scene, half see-through, to build over: **On the floor** under the model, or standing behind it as the front or the side view sees it.

- **Width** is typed in studs; drag a corner to size it, or the picture to slide it.
- **Opacity** fades it, 0 to 100%.
- **Locked** lets clicks through to the model behind it.
- **Choose another…** swaps the picture where it lies; **Remove** takes it away.

Each change is a step of **Edit › Undo**. The picture is saved in the model's file, which other LDraw programs read as before, and is never in a render, the instructions, a parts list or a shared link.

<!-- covers
ui:reference picture
-->
