---
title: The view
nav: The view
description: Turn, slide and zoom the camera, choose how the mouse navigates, and see inside a model.
---

## Turn, slide and zoom {#camera}

With the left button, a drag on nothing turns the view; [[Shift]]-drag or [[Space]]-drag slides it; the wheel or a pinch zooms to the pointer. The right and middle buttons do what the navigation preset says (below). [[F]] frames the selection, or everything; [[0]] is the usual view; [[1]] to [[7]] are front, back, left, right, top, bottom and three-quarter; and [[`]] switches between square-on and perspective.

The **Orbit**, **Pan** and **Zoom** tools ([[O]], [[H]], [[Z]]) make a left drag only move the view, for a trackpad or a touchscreen.

<!-- covers
ui:camera controls
ui:left-button navigation
-->

## Navigate like Studio, Blender or Mecabricks {#presets}

**Tools › Settings…**, *Navigate like*, sets what the right and middle buttons do, so your hands keep what they know:

| Preset | Right-drag | Middle-drag |
|---|---|---|
| Studio | Turn | Slide |
| Blender | Turn | Turn |
| Mecabricks | Slide | Zoom |

[[Shift]] with either gives the other of turning and sliding. Settings also says which way the wheel zooms.

<!-- covers
ui:navigation presets
-->

## The view cube {#view-cube}

The cube in the corner turns the view to the face you click and shows which way the model faces. Its buttons zoom in and out.

<!-- covers
ui:view cube
-->

## Cut away and X-ray {#see-inside}

- **View › Cut away** ([[K]]) puts a plane through the model. Drag the strip's slider to move it, choose **X**, **Y** or **Z**, **Flip** to cut the other side away, and **Ghost** to leave a faint copy of what is cut.
- **View › X-ray** ([[I]] with a part selected, or inside a sub-assembly) shows the selection through everything in front of it.

<!-- covers
ui:cut-away
ui:x-ray
-->

## Stress {#stress}

**View › Stress** colours each part by how hard its joints work to hold the model up: red is close to giving way. Point at a part to read why. Right-click a red part and **Ask Claude to brace this**.

<!-- covers
ui:stress view
-->

## Floor and stud grid {#floor}

**View › Floor** sets what the model stands on: a baseplate 16, 32 or 48 studs (or any size in eights to 192), in a colour baseplates come in, a grid floor, or nothing at all, as a car or a ship stands on a table. With nothing selected, the properties panel has the same. **Settings › New models start on** chooses the floor a new model gets. **View › Stud grid** draws the studs' grid over the floor.

<!-- covers
ui:floor
ui:stud grid
-->

## Pointers and speed {#pointers}

The pointer shows what a drag will do: a hand to slide, an arrow round to turn, a magnifier to zoom, a brush to paint. When the model is still, the app stops drawing, so it costs nothing to leave open; on a slow computer it uses a lighter look while you move, and the full look as soon as you stop. Quitting with a big model mid-way waits for its work to finish, so the last save is whole.

<!-- covers
ui:pointer cursors
ui:drawing only what changed
ui:a lighter look where frames are slow
lib:quitting cleanly
-->
