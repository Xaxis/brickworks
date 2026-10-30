---
tools: make_art, brickify, look_at_picture
panels: MosaicDialog#mosaic, BrickifyDialog#brickify
ai: A picture laid as a mosaic of plates and round tiles, as LEGO® Art sets are, and any 3D model (OBJ, STL, PLY, 3MF, VOX, FBX, glTF, GLB) laid in bricks. An assistant lays a mosaic with make_art (it replaces what is on the baseplate) and a 3D model with brickify (a job).
rules:
  - A mosaic panel is 16 x 16 studs; make_art takes 1 to 6 panels each way.
  - brickify's size is studs along the model's longest side, 6 to 64 (24 when not said).
  - A file fetched by link is at most 96 MB.
title: Mosaics and brickify
nav: Mosaics and brickify
description: Turn a picture into a wall of plates, as LEGO® Art sets are, and turn any 3D model into bricks.
---

## Mosaic from a picture {#mosaic}

**Make › Mosaic from a picture…** turns a picture into a wall of plates and round tiles. Choose its size and its colours, and the panel lays it out as LEGO® Art sets are: in square sections with a plan for each, numbered colour by colour.

<!-- covers
ui:mosaic
lib:LEGO Art layout
lib:LEGO Art plans
-->

### Designed with Claude {#art-with-claude}

In the mosaic panel, **Design with Claude** has Claude design the picture itself, or ask the assistant for a picture laid in LEGO® bricks: Claude draws in the colours plates come in, at the size you choose (`make_art`).

<!-- covers
ui:LEGO Art designed by Claude
-->

## Brickify a 3D model {#brickify}

**Make › Brickify a 3D model…** ([[Ctrl+I]]), or **File › Import › 3D model to brickify**, takes a sculpt, a scan or any 3D model (OBJ, STL, PLY, 3MF, VOX, FBX, glTF or GLB) and lays it in bricks at the size you choose: solid or hollow, in its own colours or one, with real parts that hold together. It is built in steps, from the ground up, so it comes with instructions. With [your collection](/docs/collection) set, it can build from the parts you own.

<!-- covers
ui:brickify a 3d model
lib:brickify
lib:3d model files
lib:brickify from a collection
lib:brickify steps
-->
