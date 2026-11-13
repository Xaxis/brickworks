---
tools: view_model, set_floor, in_view, view_board, save_view
ai: Turning, sliding and zooming the camera, navigation presets, the view cube, views saved with the model, the split view, cutting away and X-ray, stress colours, stud directions, edges and studs, and the floor the model stands on. An assistant looks at the model as the person does, and changes nothing by looking. view_model draws it from one side; view_board draws up to six sides (front, back, left, right, top and the corner) in one labelled picture, and can edge named parts in magenta and ghost the rest, draw parts see-through as X-ray does, show the model built to a step with that step's new parts edged, or with "studs": true colour it as Stud directions does. in_view says the views kept, the step the timeline is at, the part in hand, and the reference picture. set_floor sets the floor.
rules:
  - view_model looks from corner, top, front, back, left or right; corner shows the shape best.
  - view_model view=NAME looks from a view the person saved with the model, exactly as their window draws it; a name it does not keep is answered with those it does.
  - save_view name=NAME keeps where the person's window looks from now with the model, as Save this view… does; in_view lists the views kept, each with its key.
  - Floors are a baseplate (16, 32 or 48 studs, or any size in eights to 192), a grid, or none.
  - view_model and view_board change nothing, and always draw every edge and stud, whatever the person's window shows.
title: The view
nav: The view
description: Turn, slide and zoom the camera, look from any side, save a view, and see inside a model.
---

The view is how you look at the model: from any side, close up, two ways at once, or cut open. It is all in the **View** menu, and none of it changes the model.

## Turn, slide and zoom {#camera}

| To | With a mouse | On a trackpad |
|---|---|---|
| Turn | Drag on empty space, or right-drag | Two fingers |
| Slide | [[Shift]]-drag, or [[Space]] and drag | [[Shift]] and two fingers |
| Zoom to the pointer | The wheel | Pinch |

A drag that starts on a part moves the part. With nothing selected, the arrows turn the view, [[W]] [[A]] [[S]] [[D]] slide it and [[=]] [[-]] zoom. The **Orbit**, **Pan** and **Zoom** tools ([[O]], [[H]], [[Z]]) make every left drag move the view. The pointer shows what a drag will do. For touch screens, see [On a tablet or a phone](/docs/web-and-desktop#phone).

A still model costs nothing to leave open: the app draws only when something changes, and on a slow computer it draws a lighter look while you move.

<!-- covers
ui:camera controls
ui:left-button navigation
ui:pointer cursors
ui:drawing only what changed
ui:a lighter look where frames are slow
lib:quitting cleanly
-->

## Look from a side {#sides}

- [[1]] to [[7]] look from the front, back, left, right, above, below and three-quarters (**Isometric**); [[0]] is the default view. All are in **View › Viewpoint**.
- [[F]] fits the selection, or everything when nothing is selected; [[Shift+F]] or [[Home]] always fits the whole model.
- [[`]] (**View › Orthographic**) switches between square-on and perspective.
- **Turn the model left** or **right** ([[Shift+Q]], [[Shift+E]]) turns the model itself a quarter turn on its floor.
- **View › Full screen** ([[F11]]).

## The view cube {#view-cube}

![The view cube in the corner of the view, its faces named, with buttons round it to slide, zoom and fit.](/docs/img/the-view-cube.webp "The view cube: click a face, edge or corner to look from there.")

The cube at the top right turns with the view. Click a face, an edge or a corner to look from there, or drag it to turn. Its arrows turn the view a step a click. Under it: a pad to drag the view sideways, zoom out and in, and fit.

<!-- covers
ui:view cube
-->

## Navigate like Studio, Blender or Mecabricks {#presets}

**Tools › Settings…**, **Navigate like**, sets what the right and middle buttons do:

| Preset | Right-drag | Middle-drag |
|---|---|---|
| Studio | Turn | Slide |
| Blender | Turn | Turn |
| Mecabricks | Slide | Zoom |

[[Shift]] swaps turning and sliding. **Invert zoom direction** turns the wheel round.

<!-- covers
ui:navigation presets
-->

## Save a view {#saved-views}

Look from where you want, choose **View › Viewpoint › Save this view…** ([[Alt+V]]) and give it a name. It is kept in the model's file, so it is there on any computer. The first nine have keys, [[Alt+Shift+1]] to [[Alt+Shift+9]], and rows in **View › Viewpoint**. The dialog lists them with **Look from it** and **Remove**. Render's **Camera** offers each one, and **Render each saved view** queues a picture from all of them.

<!-- covers
ui:saved views
lib:a session keeps a view over mcp
-->

## A second view beside the model {#split}

![The model area split in two: the red car turned three-quarters on the left, and straight from the front on the right with Front, Top, Side, Back and Fit above it.](/docs/img/the-view-split.webp "View › Split (F8) shows the model from two sides at once.")

**View › Split** ([[F8]]) adds a square-on view beside the model. **Front**, **Top**, **Side** and **Back** turn it, **Fit** frames the model, **×** closes it. Its wheel and drag zoom and slide it alone. Build in either view: a part for a side stud is easiest to aim square on. Short of room, the right-hand column folds while the split is on.

<!-- covers
ui:split view
-->

## Cut away and X-ray {#see-inside}

![The red car cut away by a plane, showing the inside of its parts, with the cut-away's strip of choices along the view.](/docs/img/the-view-cut.webp "View › Cut away (K) shows the inside; its strip changes the shape and side.")

**View › Cut away** ([[K]]) puts a plane through the model, with a strip of controls along the view:

- The slider (or the wheel) moves the cut; **X**, **Y** and **Z** turn it; **Flip** ([[Shift+K]]) cuts the other side away; **Ghost** leaves a faint copy of what is cut.
- The strip's first list, or **View › Cut away by**, takes out **A box** ([[Alt+X]]), **A sphere** ([[Alt+Z]]) or **A cylinder** ([[Alt+Y]]) round the selection instead. Drag a face's knob to move it a plate at a time; **Grow** and **Shrink** move them all.

The cut is saved with the model; renders and instructions draw the model whole. **View › X-ray** ([[I]]) shows the selection through everything in front of it.

<!-- covers
ui:cut-away
ui:cut away by a shape
ui:x-ray
-->

## Stress {#stress}

**View › Stress** colours each part by how near its weakest joint is to giving way: red past what its studs hold, amber close. Point at a part to read what it carries; the panel lists the weakest, worst first. With the assistant on, a red part's right-click menu has **Ask Claude to brace this…**.

### Strengthen {#strengthen}

Choose a red or amber joint in Stress's panel and it looks for the fewest parts that make that joint hold, the way a builder fixes one: a plate across the seam onto the part beside it, a brick or a short column under it down to the ground, or a second pin through the next two holes in line. The parts are drawn as a ghost where they would go, with what they do: "Strengthen adds a Plate 1 x 2 across the seam, onto the Brick 1 x 4 beside it. Then it holds about 2.6 times its working load." Press **Strengthen** to put them down; one undo takes them off again. Each fix has room where it goes and is weighed with the whole model before it is offered, so it never makes another joint weak. When a joint has no fix of up to three parts, the panel says so.

If you have a collection, **From my bricks** makes the fix of parts you own, in colours you still have one of after the model's own, and says when a part is not yours.

An assistant gets the same fixes from weakest_joints: each red or amber joint comes with its fix and the edit_model call that puts it down, and `"mine": true` makes them of your parts.

<!-- covers
ui:stress view
ui:strengthen a weak joint
-->

## Stud directions {#studs}

**View › Stud directions** colours each part by where its studs point: green up, red down, blue front, yellow back, orange left, cyan right; black for two ways or more, grey for none. A legend counts each.

<!-- covers
ui:stud directions
-->

## Edges and studs {#edges-studs}

**View › Edges and studs** hides the line where parts meet, or every stud, to see the shapes alone; a big model draws faster. Renders, instructions and shared pictures always draw both.

<!-- covers
ui:edges and studs
-->

## Floor and stud grid {#floor}

**View › Floor** chooses a baseplate (16, 32, 48 studs or any size, in a baseplate colour), a **Grid floor** or **No floor**. **The baseplate is part of the model** counts it in the parts list and the booklet. **View › Stud grid** ([[Alt+G]]) draws lines between the studs.

<!-- covers
ui:floor
ui:stud grid
-->

## What an assistant sees {#assistant-sees}

An assistant you connect looks at the model as you do, and changes nothing by looking (`view_model`, `view_board`).

<!-- covers
lib:what a session sees over mcp
-->
