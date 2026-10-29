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

**File › Render…** (or the toolbar's camera) makes a picture of the model worth keeping, a turntable, or an animation of one of its motions. The picture on the left is a quick draft of the render, drawn again every time a choice changes, so what comes out is what you looked at; **Render** only makes it better. A render runs a piece at a time, with its progress on the bar and **Cancel** (or [[Esc]]) to stop it; when it is done it downloads, or on the desktop goes to Downloads.

<!-- covers
ui:photo-real render
lib:studio renderer
-->

The choices are a photographer's:

| Choice | What there is |
|---|---|
| Quality | A quick one in the window's own look, up to Best: frames averaged for soft shadows from an area light, smooth edges, shading under every ledge, and depth of field |
| Look | **As in the window**, or **Product** (below) |
| Size | 720p, 1080p, 4K, Square, or Custom |
| Backdrop | White, Gradient, Grey, Dark, a Colour you pick, or None (a transparent picture), with a contact shadow under the model if you like |
| Light | Three lights, as in the window; or photographed light: a softbox studio, window light, or daylight |
| View | Three-quarter like the box, the view you are looking at, front, side, back three-quarter, low looking up, or from above |
| Lens | The focal length, and an aperture from Off to f/2 for depth of field (blur comes with Best) |

### The Product look {#product-look}

**Product** draws the model as a set's own pictures are: glossy plastic with rounded edges, clear parts that bend the light and keep their colour, and a studio's key, fill and rim light, with film-like tones. Black parts stay black and every colour stays true to its LDraw colour. It goes with any backdrop; at Best, with an aperture set, depth of field softens what is out of focus.

<!-- covers
lib:product look
-->

### Animation {#animation}

**Animation** plays one of the model's [motions](/docs/joints-and-mechanisms#motions), or all of them in order, and keeps every frame as an animated WebP, at the quality, size, light and lens chosen for a picture. The camera stays as you see it, or is framed on what moves.

## Booklets {#booklets}

The building instructions save as a PDF or as PNG pages: see [Instructions and booklets](/docs/instructions#save).
