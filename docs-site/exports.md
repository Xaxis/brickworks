---
tools: export_model, parts_list
ai: Every file Brickworks writes but renders: LDraw, Studio, 3D models, a picture, BrickLink, Rebrickable and LEGO® Pick a Brick parts lists, and all models as a .zip. An assistant exports with export_model and lists the parts with parts_list; renders are on the Render page.
rules:
  - A render, a Studio file, a picture and the instructions answer with a job number; follow it with job.
  - On the desktop an export asks where to save; in a browser it downloads.
  - export_model format=pickabrick names the parts with no LEGO® element number in its answer; tell the person, they buy those elsewhere.
  - A BrickLink wanted list takes condition (new, used, any), wanted_list (an ID) and notify; nothing is uploaded, the person uploads the file.
title: Exports
nav: Exports
description: Save the model as a file for another program, a 3D printer or a shop: LDraw, Studio, 3D models, a picture and parts lists.
---

**File › Export** writes the model, or its parts list, as a file for another program, a 3D printer or a shop. In a browser each downloads; in the desktop app each asks where to save it. For a picture worth keeping, a turntable or a video of the build, see [Render](/docs/render).

| Export | What it is for |
|---|---|
| LDraw model (`.ldr`, or `.mpd` with its sub-models) | The open format: LDCad, LeoCAD, Studio and every LDraw tool read it |
| BrickLink Studio model (`.io`) | Open it in Studio, with its steps |
| 3D model (`.glb`, `.gltf`, `.obj`, `.stl`, `.3mf`) | Blender, AR, a 3D printer, one printing in colour |
| Picture of the model (`.png`) | The model alone, 2400 x 1600, with nothing behind it |
| BrickLink wanted list (`.xml`) | Buy the parts on BrickLink |
| Rebrickable parts list (`.csv`) | Buy the parts, or check them against your sets on Rebrickable |
| LEGO® Pick a Brick list (`.csv`), [[Alt+L]] | Buy the parts new from LEGO® Pick a Brick, by their element numbers |
| All my models (`.zip`) | Every model saved here, as LDraw files: see [Keep a copy of everything](/docs/saving-and-files#backup) |

<!-- covers
ui:save as a studio model
ui:picture of the model
-->

## Buy the parts {#shop-lists}

The parts list ([[P]], or **Build › Parts list**) counts every part by colour, and has a button for each shop under it. The BrickLink and Rebrickable lists group the parts by lot, the way shops sell them. With [your collection](/docs/collection) set up, what you own is taken off first.

**LEGO® Pick a Brick** ([[Alt+L]]) writes the list LEGO® Pick a Brick uploads: each part's LEGO® element number and how many. Its upload takes 400 lines a file and 999 of an element, so a bigger model comes as several files (in a browser, one .zip of them). A part with no element number known (a few prints, old moulds, parts you made) is left off, and Brickworks names it, to buy elsewhere.

<!-- covers
ui:parts lists for shops
-->

### What the BrickLink list asks for {#bricklink}

The arrow beside **BrickLink** on the parts list sets what the wanted list asks of each part, as BrickLink's upload reads it:

- **Condition**: new or used, new only, or used only.
- **Wanted list**: empty for your main list; for another, the number after `wantedMoreID=` in its address on BrickLink.
- **Email me when one is listed for sale.**

**Save the list** writes it so, and the parts list and **File › Export** go on writing it so until you change it. Nothing is uploaded: upload the file on BrickLink under **Wanted › Upload**.

## 3D models {#3d}

![The 3D model export dialog: a choice of glb, gltf, obj, stl or 3mf, each with a line on what it is for.](/docs/img/exports-3d.webp "File › Export › 3D model…")

**File › Export › 3D model…** writes the model at its real size, each part with its real shape:

- **GLB** or **glTF**, in its colours, for Blender, three.js and AR viewers. A part shape is kept once however often it is used, so any model fits.
- **OBJ**, with an `.mtl` of its colours.
- **STL**, one mesh in millimetres, for a slicer.
- **3MF**, to print in colour: an object for each colour, so your slicer gives each its own filament. When it asks, load it as one object of several parts. It is in millimetres, standing on the bed.

A part moulded in two colours goes to both, and a printed pattern is painted on its part for a slicer that reads a triangle's colour. The parts are LDraw's shapes at their exact size, not loosened for a printer, so printed parts may fit real bricks tightly.

<!-- covers
ui:3d model export
-->

## Booklets {#booklets}

The building instructions save as a PDF or as PNG pages: see [Instructions and booklets](/docs/instructions#save).
