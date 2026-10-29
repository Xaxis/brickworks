---
title: Exports and renders
nav: Exports and renders
description: Every file Brickworks saves, from LDraw and Studio files to 3D models, pictures, shopping lists and photo-real renders.
---

**File › Export** has every format. On the desktop each asks where to save; in a browser it downloads.

| Export | What it is for |
|---|---|
| LDraw model (`.ldr`, or `.mpd` with its sub-models) | The open format: LDCad, LeoCAD, Studio and every LDraw tool read it |
| BrickLink Studio model (`.io`) | Open it in Studio, with its steps |
| 3D model (`.glb`, `.gltf`, `.obj`, `.stl`) | Blender, AR, a 3D printer |
| Picture of the model (`.png`) | A picture with nothing behind the model |
| BrickLink wanted list (`.xml`) | Buy the parts on BrickLink |
| Rebrickable parts list (`.csv`) | Buy the parts, or check them against your sets on Rebrickable |
| All my models (`.zip`) | Every model saved here, as LDraw files: a copy of your own |

<!-- covers
ui:save as a studio model
ui:3d model export
ui:picture of the model
-->

![File › Export › BrickLink Studio model, the model as an .io file.](/img/compare-io-720.webp "A Studio file, with its steps.")

## Parts lists for shops {#shop-lists}

The parts list ([[P]], or **Build › Parts list**) counts every part by colour. The BrickLink and Rebrickable exports group them by lot, the way shops sell them; with [your collection](/docs/collection) set, what you own is taken off first.

<!-- covers
ui:parts lists for shops
-->

## 3D models {#3d}

**3D model…** writes the model as glTF (`.glb` or `.gltf`) in its colours, OBJ, or STL for a printer, each part with its real shape.

![The 3D model export's formats.](/img/compare-export3d-640.webp "Export a 3D model: glb, gltf, obj or stl.")

## Render {#render}

**File › Render…** (or the toolbar's camera) makes a photo-real picture of the model, or a turntable that turns it round, on a backdrop in studio light. Choose the backdrop, the angle and the quality; the best takes longer.

<!-- covers
ui:photo-real render
lib:studio renderer
-->

## Booklets {#booklets}

The building instructions save as a PDF or as PNG pages: see [Instructions and booklets](/docs/instructions#save).
