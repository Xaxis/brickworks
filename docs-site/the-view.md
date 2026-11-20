---
tools: view_model, set_floor, in_view, view_board, save_view
ai: Turning, sliding and zooming the camera, navigation presets, the view cube, views saved with the model, the split view, cutting away and X-ray, stress colours, stud directions, connection points, edges and studs, and the floor the model stands on. An assistant looks at the model as the person does, and changes nothing by looking. view_model draws it from one side; view_board draws up to six sides (front, back, left, right, top and the corner) in one labelled picture, and can edge named parts in magenta and ghost the rest, draw parts see-through as X-ray does, show the model built to a step with that step's new parts edged, or with "studs": true colour it as Stud directions does. view_model with "marks": true marks every connection point in its picture as View › Connection points does. in_view says the views kept, the step the timeline is at, the part in hand, and the reference picture. set_floor sets the floor.
rules:
  - view_model looks from corner, top, front, back, left or right; corner shows the shape best.
  - view_model view=NAME looks from a view the person saved with the model, exactly as their window draws it; a name it does not keep is answered with those it does.
  - save_view name=NAME keeps where the person's window looks from now with the model, as Save this view… does; in_view lists the views kept, each with its key.
  - Floors are a baseplate (16, 32 or 48 studs, or any size in eights to 192), a grid, or none.
  - view_model marks=true marks where the parts connect, filled for what goes in (studs, pins, axles, bars, balls) and hollow for what takes one (anti-studs, pin and axle holes, clips, sockets), each at its own size; the marks are in that picture alone.
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

### Lift {#lift}

Press **Lift** in Stress's panel, then click a part: the model is lifted off the floor by that part, as you would pick it up by it. Every joint between it and the rest then carries the weight below it, levered about the edge it would turn on. The joint nearest letting go goes first, and the rest is weighed again without it, until what is left holds. The part in your hand is blue, what comes away red, a joint that holds past its working load amber; the panel names each thing that comes away, with the weight it carried and how far past what lets it go: "Lifted by Brick 1 x 4: 14 parts come away, 23 g of 27". Press a row to select and frame those parts. Click another part to lift by it instead; press **Lift** again to set the model down. A wall of eight 1 x 4 bricks lifted by a top brick holds; at sixteen, the brick standing on one stud of the brick under the one in your hand lets go, and the fourteen past it come away.

An assistant reads the same with weakest_joints `"lift_by"`, a part's number: what comes away, every part of it by number, and the joints left nearest letting go.

### Swing {#swing}

Press **Swing** in Stress's panel, then click a part: the model is swung by that part the way a child swooshes a toy, about a metre of arc in half a second, a quarter turn, down through the bottom and up. Every joint then carries what is past it pulled by gravity and by the swing together, at the moment of the arc that is hardest on it: the bottom pulls hardest, more than three times the weight, and the start and the end of the swing lever things sideways. The first joint past what lets it go comes away with everything past it, and the swing goes on without it. The panel names it first, with when, its parts, its weight and its studs: "Swung by Brick 2 x 4: Plate 2 x 10 on the right comes away first, 0.19 s in: 5 parts, 8.3 g, at its 2 studs". Press its row and **Strengthen** offers a fix that makes it hold longer in the swing, or hold all the way; put it down and the model is swung again, so you see whether it now holds. Press **Lift** to hold it still by the same part, or **Swing** again to set it down.

An assistant reads the same with weakest_joints `"swing"`, a part's number, and can change the arc with `"arc"` (metres, seconds, turn).

![The car lifted by a headlight's round plate in Stress: the plate blue, the rest of the car red, and the panel naming the one-stud joint that lets go and the 60 parts that come away.](/docs/img/the-view-lift.webp "Lift: the car hangs from one stud, and comes away whole.")

<!-- covers
ui:stress view
ui:strengthen a weak joint
ui:lift by a part
ui:swing by a part
-->

## Stud directions {#studs}

**View › Stud directions** colours each part by where its studs point: green up, red down, blue front, yellow back, orange left, cyan right; black for two ways or more, grey for none. A legend counts each.

<!-- covers
ui:stud directions
-->

## Connection points {#connection-points}

**View › Connection points** marks where parts connect. With a part in hand it marks the parts near it, and with nothing in hand the part under the pointer. What goes in is filled: studs, pins, axles (a cross), bars and balls. What takes one is hollow, a ring the size of what goes in it: anti-studs, pin holes, axle holes (a cross), clips, the mouth of a hollow a bar fits, and sockets. A pin or an axle is marked at its ends. Blue is what the part in hand can go onto, faint grey what it cannot, and the end of the part in hand that goes onto the joint it is aimed at is amber, so the third hole of a beam is found without counting. It is on to start with; the menu item turns it off. The marks are never saved, rendered, put in a picture or drawn in instructions.

<!-- covers
ui:connection points
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
