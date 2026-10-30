---
tools: edit_model, look_at_model, check_design, attachment_points, where_to_attach, make_unique, clear_model, undo, suggest_sections, make_sections, break_out_section, evaluate_section
ai: How parts go down, snap, turn and move once placed, and how a model is grouped into sub-assemblies and sections. An assistant does the same with edit_model and edit_selection, reads the model with look_at_model, and checks a change with check_design before making it.
rules:
  - Positions are studs across (x), plates up (y) and studs deep (z); 3 plates make a brick.
  - One LDraw unit is 0.4 mm: a stud is 8 mm (20 LDU), a brick 9.6 mm (24 LDU), a plate 3.2 mm (8 LDU).
  - A part goes down only where nothing else is, on studs or joints it really fits.
  - Copies of a sub-assembly follow the original until made unique (make_unique).
  - Every change, an assistant's included, is one undo step.
title: Placing and moving parts
nav: Placing and moving parts
description: How a part goes down, turns, snaps to studs and joints, and moves once it is there.
---

![A Technic go-kart in the builder, close up, one beam selected and outlined in yellow.](/img/technic-720.webp "A selected part is outlined in yellow.")

## A part in hand {#in-hand}

Brickworks rests in the **Select** tool. A part you choose from the parts bin, or take with [[Q]], is *in hand*: it follows the pointer, snapping to whatever it would really fit, and a click puts it down. It stays in hand so you can put down several; [[Esc]] or a right-click lets go.

- [[Alt]]-click or [[G]] on a part takes one like it into hand.
- [[R]] turns the part in hand (or the selection) a step; [[Shift+R]] the other way. [[T]] tips it over.
- **Snap** and **Turn** on the toolbar set how far a nudge moves and how far [[R]] turns.
- A drag never places a part: on a part it carries the part, anywhere else it turns the view.

<!-- covers
ui:place and remove
ui:snap and turn step
lib:occupancy lattice
-->

## Type a number {#typed}

With a part or a copy in hand, type a number to move it exactly: a small field opens at the pointer, the part stays where its ghost was, and the ghost shows where the number puts it, red where there is no room. [[Enter]] puts it down, one step to undo; [[Esc]] closes the field and the part follows the pointer again.

- **3x** moves it 3 studs along x, **-2z** 2 studs back, **2py** 2 plates up. **b** is a brick, **l** an LDraw unit, **mm** a millimetre: **-14ly** is 14 LDU down. A stud is the unit when none is given.
- A number alone goes the way the ghost last went: **3** after moving it right is 3 studs right.
- **23.58r** turns it 23.58°, about the joint it is on or upright; **30t** tilts it forwards. Straight after [[R]] or [[T]], before the pointer moves, a number alone is that turn instead of their step: [[R]] then **30** turns it 30°.
- Several at once: **2x-1py**. Sums work too: **40/2+1lx**.
- On the model, straight after [[R]] or [[T]] turned a selection, a number takes their place the same way, shown in hand until [[Enter]].

<!-- covers
ui:type a number while moving
-->

Parts sit on a lattice of studs and plates, as real bricks do: a part goes down only where nothing else already is, and a model opened from a file with parts a fraction off their studs can have them squared up with **Tools › Seat parts on their studs**.

<!-- covers
ui:seat an old model
-->

## Under, beside and sideways {#sideways}

Aim at the underside of an overhang and the part goes beneath it. Tip a plate with [[T]] and aim at a side stud (a headlight brick, a bracket) and it goes on sideways, studs out. Parts with studs on their sides are read at their real width.

<!-- covers
ui:place under a part and on side studs
lib:sideways building
-->

## Onto a joint {#joints}

A Technic pin, axle, beam, clip or bar in hand snaps into a hole, onto a pin, an axle or a bar it would really go into. [[R]] turns it about the joint, [[T]] the other way on. A gear pointed onto an axle beside another gear is seated in mesh where the teeth allow, and the status line says what it meshes with, or why not: too far apart, a bush in the way, square spurs.

<!-- covers
ui:snap onto a joint
ui:gears put in mesh by hand
lib:placing a part by its connectors
lib:round joints
-->

## Connect by a point {#connect}

A long Technic beam has many holes, and the one you want is rarely the one the pointer finds first. With the part in hand press [[N]], or choose **Connect** on the toolbar: its pins, holes, axles, bars and clips light up in blue where it stands. Click the one it goes on by, then the pin, hole or bar it goes on: only that point snaps, so a 1 x 16 goes on its pins by its end hole at once. [[R]] turns it about the joint, [[N]] again picks another point, and [[Esc]] goes back to placing as usual.

With nothing in hand, Connect works on a part already in the model: click the part, then its point, then where it goes. The move is one step to undo, and [[Esc]] puts it back where it was. Studs still go on by the stud grid, as every part does.

<!-- covers
ui:connect by a point
-->

## Copy, paste and duplicate {#copy}

Select, then [[Ctrl+C]] and [[Ctrl+V]], or [[Ctrl+D]] to duplicate. The copy is in hand: a click puts it down, [[R]] turns it, [[Esc]] puts it away. After [[Ctrl+D]], or a click with the **Clone** tool, another copy stays in hand for the next, so five window bays are five clicks; [[Esc]] or a right-click stops. [[Ctrl]]-drag on a part copies it straight off. [[Ctrl+X]] cuts.

<!-- covers
ui:copy paste and duplicate
-->

## Move and turn what is down {#move}

Select parts, then [[X]] lifts them: they follow the pointer, a click puts them down and [[Esc]] puts them back where they were. [[R]] turns a selection where it stands. Where it has no room to turn, the parts in the way light up for a second (red, or amber on a red part) and it comes into hand already turned: aim and click to put it where it fits, or [[Esc]] to leave it as it was. [[T]] and the **Rotate** tool do the same. The arrow keys (or [[W]] [[A]] [[S]] [[D]]) nudge it a stud, and [[Page Up]] and [[Page Down]] raise or lower it.

The **Move**, **Rotate** and **Hinge** tools on the toolbar do the same with the mouse alone. Exact positions are typed in [Properties](/docs/panels-and-settings#properties), or as a [number while it is in hand](#typed).

<!-- covers
ui:move and turn a selection
ui:tool modes
-->

## Rings and arrows {#handles}

With the **Rotate** tool, a click on a part puts three rings on it; with **Move**, three arrows. Drag a ring to turn the selection about that axis, or an arrow to slide it along one. A click on the part again does the tool's own step: **Rotate** turns it by the turn step, **Move** picks it up.

- The tag beside them says whose axes they are: **Part axes** (the part's own, however the part under it is turned), **Model axes** or **View axes**. Click the tag for the next.
- They stand where the part hangs from: the pin, hinge or clip it turns on, or the stud [[R]] turns it about. [[Alt]]-click another point to turn about it; [[Alt]]-click empty space to go back.
- A ring snaps to quarter turns near its middle, to the **Turn** step on the ring, to 5° just outside it and to 1° further out. Faint circles mark where while you drag. An arrow snaps to the **Snap** step, and to the finest step when the pointer is well off its line.
- Type a number while you drag, or straight after, to make it exact: degrees for a ring (**23.58**), a length for an arrow (**3** studs, **2p** plates). [[Enter]] puts it there; [[Esc]] leaves the drag as it was.
- Nothing goes through anything: a drag stops at the last place with room, and the part in the way lights up.
- [[Esc]] or a right-click while dragging puts it back. Each drag is one step to undo.

<!-- covers
ui:handles on the selection
-->

## Mirror, replace and paint {#mirror}

- **Edit › Mirror** ([[Shift+M]]) mirrors the selection, swapping each part for its left- or right-handed twin where there is one.
- **Edit › Replace with the part in hand** swaps every selected part for the one you hold, keeping where each was.
- [[C]] paints the selection in the current colour; the **Paint** tool paints each part you click.

<!-- covers
ui:mirror a selection
ui:replace part
-->

## Lock and hide {#lock-hide}

[[L]] locks the selection so nothing moves it by accident; [[Shift+L]] unlocks everything. [[Ctrl+H]] hides the selection, [[Shift+H]] shows only it, and [[Alt+H]] shows everything again.

<!-- covers
ui:lock parts
ui:hide and show only
-->

## Sub-assemblies {#sub-assemblies}

Select some parts and press [[Ctrl+G]] to make them a sub-assembly and name it. A click then takes it whole, a double-click edits inside it, and [[Esc]] leaves. Copies made with [[Ctrl+D]] follow the original: change one and they all change, until **Build › Make this copy unique**. [[Enter]] (or a double-click) edits inside the selected one, [[F2]] renames it, and **Ungroup** ([[Ctrl+Shift+G]]) takes it apart one level.

<!-- covers
ui:sub-assemblies
-->

## Sections {#sections}

Big models are built in sections, as big sets are. **Build › Suggest sections** proposes them from how the model is put together; the model tree's **Accept**, **Merge**, **Split** and **Evaluate** shape them. [[Y]] breaks the selected section out to work on it alone and puts it back; [[Shift+Y]] is the exploded view of every section.

<!-- covers
ui:sections
lib:sections suggested
lib:angled sections
-->

## Undo and history {#undo}

[[Ctrl+Z]] undoes and [[Ctrl+Shift+Z]] redoes. **History** on the toolbar (or **Edit › History**) lists the steps you can go back to. Whatever the AI puts down is one undo step too.

<!-- covers
ui:undo and redo
ui:undo history
-->

## Measure {#measure}

Press [[U]] and click two points: the distance in studs, plates and millimetres. One LDraw unit is exactly 0.4 mm: a stud is 8 mm across, a brick 9.6 mm tall and a plate 3.2 mm.

<!-- covers
ui:measure
-->
