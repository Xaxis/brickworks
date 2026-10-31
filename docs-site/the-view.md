---
tools: view_model, set_floor, in_view
ai: Turning, sliding and zooming the camera, navigation presets, cutting away and X-ray, stress colours, and the floor the model stands on. An assistant looks from a side with view_model and sets the floor with set_floor.
rules:
  - view_model looks from corner, top, front, back, left or right; corner shows the shape best.
  - Floors are a baseplate (16, 32 or 48 studs, or any size in eights to 192), a grid, or none.
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

## A second view beside the model {#split}

**View › Split** ([[F8]]) puts a second view of the model beside the first, square on from the front. **Front**, **Top**, **Side** and **Back** at its top turn it, **Fit** frames the whole model in it, and **×** goes back to one view. It starts looking where the main view looks, at the same size, and follows it until you move it: the wheel over it zooms it, and a drag over it slides it, without moving the main view. A right drag over it does nothing, since a view square on cannot turn. Once moved it keeps its own zoom and place, and the app remembers them with the split.

The second view works like the first. A part in hand shows in both. A click there puts the part down or picks a part. A box drawn there selects what it surrounds. Connect's points and the rotate and move handles are drawn in both views and can be taken in either. A part for a side stud or under an overhang is easier to aim square on. The split takes its room from the model's, never from the parts bin or the panels, and the app keeps it on for next time. On a phone, a tablet held upright, or a window too small for two views, it is greyed.

<!-- covers
ui:split view
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

## A picture to build over {#reference}

**Make › Reference picture…** lays a photo, a plan or a drawing (PNG, JPEG, WebP, BMP or SVG) in the scene to build over: on the floor under the model, or standing behind it as the front or the side view sees it. It opens as wide as the model, half see-through, with its corners showing.

- **Width** is typed in studs, to a twentieth of a stud. Drag a corner to size it from the corner across; drag the picture to slide it.
- **Opacity** fades it from 0 to 100%.
- **Locked** leaves the mouse to the model: a click through the picture picks the part behind it. Unlocked, a click on the picture picks it out.
- **Choose another…** swaps the picture and keeps where it lies; **Remove** takes it away.

Each change is one step of **Edit › Undo**, whether you lay the picture, move it, size it, fade it, lock it, swap it or take it away. Dragging the opacity slider counts as one step, and so does typing a width.

The picture is kept in the model's file, on lines other LDraw programs ignore, so it opens again with the model. A change to the picture alone counts as unsaved work, so New and Open ask before replacing the model, and the autosave keeps the picture. It is never in a render, the instructions, the parts list, an export or a shared link.

An assistant sees it with `in_view`: the picture, where it lies, and the model drawn on it. `in_view` also tells it the step the timeline is at and the part in your hand. It changes nothing.

<!-- covers
ui:reference picture
-->

## Pointers and speed {#pointers}

The pointer shows what a drag will do: a hand to slide, an arrow round to turn, a magnifier to zoom, a brush to paint. When the model is still, the app stops drawing, so it costs nothing to leave open; on a slow computer it uses a lighter look while you move, and the full look as soon as you stop. Quitting with a big model mid-way waits for its work to finish, so the last save is whole.

<!-- covers
ui:pointer cursors
ui:drawing only what changed
ui:a lighter look where frames are slow
lib:quitting cleanly
-->
