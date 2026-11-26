---
tools: edit_model, look_at_model, check_design, attachment_points, where_to_attach
ai: How a person puts a part down by hand: in hand from the parts bin, snapped to the studs, turned, placed a typed distance away, under and beside other parts, onto a Technic joint, by a connector they choose, and track to track. An assistant places parts with edit_model, by connector names from attachment_points or where_to_attach, reads the model with look_at_model, and checks a change with check_design before making it.
rules:
  - Positions are studs across (x), plates up (y) and studs deep (z); 3 plates make a brick.
  - One LDraw unit is 0.4 mm: a stud is 8 mm (20 LDU), a brick 9.6 mm (24 LDU), a plate 3.2 mm (8 LDU).
  - A part goes down only where nothing else is, on studs or joints it really fits.
  - Tracks go end to end with edit_model's attach, {"to": "c1.track[1]", "by": "track[0]"}, each end numbered as attachment_points lists them.
  - Every change, an assistant's included, is one undo step.
title: Placing parts
nav: Placing parts
description: Take a part in hand, snap it to the studs, turn it, and put it down exactly where it goes, on its side or onto a Technic joint.
---

Every part goes in the same way: you take it *in hand*, it follows the pointer and snaps to whatever it would really fit, and a click puts it down. The parts are in the [parts bin](/docs/parts-bin) on the left.

## Put a part down {#in-hand}

1. Click a part in the parts bin, or press [[/]], type its name and click it. It is now in hand and follows the pointer, snapping to the studs.
2. Press [[R]] to turn it a step, [[Shift+R]] to turn it back, and [[T]] to tip it onto its side.
3. Click to put it down. It stays in hand, so each click puts down another.
4. Press [[Esc]] or right-click to let go.

[[Q]] takes the last part back into hand, and [[Alt]]-click or [[G]] on a part in the model takes one like it. A drag never puts a part down: on a part it carries it, anywhere else it turns the view. A part goes down only where nothing else is, as a real brick does.

<!-- covers
ui:place and remove
lib:occupancy lattice
-->

## Choose the Snap and Turn steps {#snap-turn}

**Snap** and **Turn** on the toolbar set how far a part moves and turns:

- **Snap**: **Stud**, **½ stud**, **½ plate** or **Free**: what a part snaps to as it goes down, and how far the arrow keys move a selection.
- **Turn**: 90°, 45°, 15° or 5°: how far [[R]] and the Rotate tool turn.

<!-- covers
ui:snap and turn step
-->

## Put it an exact distance away {#typed}

![A red 2 x 4 brick in hand over an empty baseplate, seen through as a ghost, and the small field at the pointer reading 3x, with x +3 studs, Enter puts it down under it.](/docs/img/placing-parts-typed.webp "Type a number with a part in hand: the field opens at the pointer and the ghost shows where it goes.")

With a part or a copy in hand, type a number. A small field opens at the pointer and a ghost shows where the number puts the part, red where there is no room. [[Enter]] puts it down; [[Esc]] closes the field.

- **3x** is 3 studs along x, **-2z** 2 studs back, **2py** 2 plates up. The axis can come first, **x 3**: with something lifted or copied in hand, [[X]], [[Y]] or [[Z]] opens the field too. **b** is a brick, **l** an LDraw unit and **mm** a millimetre: **-14ly** is 14 LDU down. With no unit, a number is studs.
- A number alone goes the way the ghost last went: **3** after moving it right is 3 studs right.
- **30r** turns it 30° and **30t** tilts it forwards. Straight after [[R]] or [[T]], a number alone is that turn, on a part in hand or a selection.
- Several at once: **2x-1py**. Sums work too: **40/2+1lx**.

<!-- covers
ui:type a number while moving
-->

## Under, beside and sideways {#sideways}

- Aim at the underside of an overhang and the part goes beneath it.
- Tip a plate with [[T]] and aim at a side stud, on a headlight brick or a bracket, and it goes on sideways, studs out. Parts with studs on their sides are read at their real width.
- A 4740 dish, or a small part with one tube under it, goes onto a single stud, as its sets have it. A cone put on a stud sits at the stud's stop.
- A model opened from a file with parts a fraction off their studs can have them squared up with **Tools › Seat parts on their studs**. A part too far from any stud to seat, floating in the air, is selected and said, to move by hand.

<!-- covers
ui:place under a part and on side studs
lib:sideways building
ui:seat an old model
-->

## Onto a Technic joint {#joints}

A Technic pin, axle, beam, clip or bar in hand snaps into a hole, onto a pin, an axle or a bar it would really go into. [[R]] turns it about the joint and [[T]] puts it on the other way round. An axle goes through a hole flush with its far face; point past that face and it goes on through to where you point.

A gear aimed at an axle beside another gear is seated in mesh where the teeth allow. The status line says what it meshes with, or why it cannot: too far apart, a bush in the way, square spurs.

<!-- covers
ui:snap onto a joint
ui:gears put in mesh by hand
lib:placing a part by its connectors
lib:round joints
-->

## Onto a ball joint {#balls}

A tow ball socket, a Technic ball socket or a Joint-8 socket in hand goes onto the ball it is aimed at, and a ball goes into a socket the same way. It goes on turned as you hold it when there is room, and lined up with the ball when not. [[R]] turns it about the ball's own axis, and [[T]] puts it on by another socket of the part, such as a link's other end.

Once it is on, select it and the **Rotate** tool's rings stand on the ball's centre: drag one, or type a number, to turn it any way about the ball. A sub-assembly on a ball gets three sliders in **Build › Motions…**, one for each way it turns.

<!-- covers
ui:ball joints by hand
-->

## By the joint you pick it up by {#grabbed}

A part picked up off the model goes on by the joint you took hold of. Point at a side stud of a brick with studs on its sides and press [[X]], or drag it from there, and that stud goes into the hole you aim at. Pick a beam up by its end hole and that hole goes onto the pin. Studs, stud holes, pins, holes, axles, bars, clips and balls all work this way.

[[R]] turns the part about that joint, and [[T]] lets go of it, so the part snaps as one from the parts bin does. Where the part you aim at has nothing that takes the joint you hold, the part goes on by a joint that fits. A part taken from the parts bin, a copy, or several parts at once go on as before.

<!-- covers
ui:on by the joint it was picked up by
-->

## By the hole you choose {#connect}

![A Technic beam in hand over the baseplate, its pin holes lit in blue, each a point it can go on by.](/docs/img/placing-parts-connect.webp "Connect (N) lights a part's points: click the one it goes on by, then where it goes.")

A long beam has many holes, and the pointer rarely finds the one you want first. **Connect** lets you choose:

1. With the part in hand, press [[N]] (or **Connect** on the toolbar). Its pins, holes, axles, bars and clips light up in blue.
2. Click the point it goes on by.
3. Click the pin, hole or bar it goes on. Only that point snaps, so a 1 × 16 beam goes on by its end hole at once.

You need not remember it: while a part in hand sits on a joint, the status bar says "N picks which of its points goes on (Connect)". A pin or an axle goes in from the side you point from. [[T]] turns it the other way round, [[R]] about the joint, [[N]] picks another point, and [[Esc]] goes back to placing as usual. With nothing in hand, Connect moves a part already down: click the part, its point, then where it goes.

<!-- covers
ui:connect by a point
-->

## Lay train track {#tracks}

A track in hand (9V, 12V, 4.5V, RC, 6-wide or roller coaster) snaps to the free end of a track near the pointer, and a click lays it on. [[R]] puts its next end to the joint, so a curve turns the other way. A 4.5V or 12V rail's sleeper goes down with it. Sixteen curves close a circle.

<!-- covers
ui:train tracks end to end
-->

To copy, move, mirror or group what is down, see [Moving and changing parts](/docs/changing-parts).
