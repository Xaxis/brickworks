---
panels: PatternDialog#patterns
tools: edit_model, pattern_parts, mirror_parts, split_parts, merge_parts, make_unique, clear_model, undo, suggest_sections, make_sections, break_out_section, evaluate_section, measure
ai: Changing parts once they are down: copy and duplicate, patterns, lifting, nudging and turning a selection, the Move and Rotate tools' rings and arrows, mirror, replace and paint, split and merge, lock and hide, sub-assemblies and sections, undo, and measuring. An assistant does the same with edit_model; pattern_parts lays a row, a grid or levels of copies in one call, a copy with no room named by its column, row and level and the part in its way; mirror_parts (in place, or as a copy across the model's middle), split_parts and merge_parts change parts it names and answer with the change pictured, new parts edged in magenta; measure gives the distance and angle between two connectors it names.
rules:
  - Copies of a sub-assembly follow the original until made unique (make_unique).
  - Nothing goes through anything: a copy, move or turn with no room is refused, or stops at the last place with room.
  - Every change, an assistant's included, is one undo step.
title: Moving and changing parts
nav: Moving and changing parts
description: Copy and lay out patterns, move and turn what is down, mirror, split and merge, lock and hide, make sub-assemblies, undo, and measure.
---

Everything here works on the selection: click a part, or see [Selecting and editing](/docs/selecting) to take many.

## Copy, paste and duplicate {#copy}

Select, then [[Ctrl+C]] and [[Ctrl+V]], or [[Ctrl+D]] to duplicate; [[Ctrl+X]] cuts. The copy is in hand: a click puts it down, [[R]] turns it and [[Esc]] puts it away. After [[Ctrl+D]], or a click with the **Clone** tool, another copy stays in hand for the next, so five window bays are five clicks. [[Ctrl]]-drag on a part copies it straight off.

<!-- covers
ui:copy paste and duplicate
-->

## Lay out copies in a pattern {#patterns}

![The Pattern dialog: In a row, In a grid, Round and Along a hose; In all 4, counting the selection; along x every 4.0 studs; 3 copies, each 4 studs along x, each with room; Cancel and Put them down.](/docs/img/building-pattern.webp "Edit › Pattern… copies the selection in a line, a grid or round a circle.")

A fence, a colonnade, a round tower or a wheel's spokes are copies laid out at once.

- **Straight after a copy:** put a [[Ctrl+D]] copy down one step along, then type `11x` and [[Enter]]: it is one of 11 in a row, each a step apart. `/4` puts three more between the copy and its original. One [[Ctrl+Z]] takes them all back.
- **Edit › Pattern…** ([[Ctrl+Shift+D]]) copies the selection **In a row**, **In a grid** of columns, rows and levels, **Round** what it stands on or hangs from, or **Along a hose**. **In all** counts the selection: 16 is a ring of sixteen.

The copies are drawn as you type. One with no room is red and says what is in its way, and nothing goes down until they all fit.

<!-- covers
ui:patterns
lib:pattern's grid over mcp
-->

## Lift, nudge and turn {#move}

- Drag a part with the **Select** tool and it goes where you let go, with what rests on it: the bricks stacked on top come along, each where it was. A part held by something that stays, such as a plate across to a brick beside, stays with all that is on it, and what the part stands on never comes. Hold [[Shift]] as you drag to move it alone; let go of [[Shift]] to take the rest up again. One [[Ctrl+Z]] puts it all back. A finger's drag carries the same.
- [[X]] lifts the selection: it follows the pointer, a click puts it down and [[Esc]] puts it back.
- The arrow keys or [[W]] [[A]] [[S]] [[D]] nudge it a Snap step; [[Page Up]] and [[Page Down]] raise and lower it.
- [[R]] turns it where it stands. With no room there, the parts in the way light up and it comes into hand turned: click where it fits, or [[Esc]].

Exact positions and angles are typed in [Properties](/docs/panels-and-settings#properties).

<!-- covers
ui:move and turn a selection
ui:a dragged part carries what rests on it
-->

## Drag rings and arrows {#handles}

![The red car with one brick selected and the Rotate tool's three rings round it, one for each way it can turn.](/docs/img/building-rotate.webp "The Rotate tool: drag a ring to turn the selection, in the toolbar's turn step.")

The **Move**, **Rotate** and **Hinge** tools on the toolbar work with the mouse or a finger. With **Rotate**, a click on a part puts three rings on it; with **Move**, three arrows. Drag a ring to turn the selection, or an arrow to slide it. **Hinge** swings a part on its hinge, clip or turntable.

![The red car with one brick selected and the Move tool's three arrows on it, red, green and blue.](/docs/img/building-move.webp "The Move tool: drag an arrow to slide the selection along it.")

- The panes between the arrows slide it on two axes. The pale outer ring turns it about the view; a drag inside the rings rolls it freely.
- The tag beside them says whose axes they are, **Part axes**, **Model axes** or **View axes**; click it for the next. [[Alt]]-click a point to turn about it.
- A ring snaps to quarter turns near its middle, to the **Turn** step on it, and finer further out. An arrow snaps to the **Snap** step.
- Type a number as you drag to make it exact: **23.58** degrees, **3** studs, **2p** plates.
- A drag stops where the room ends. [[Esc]] or a right-click puts it back.
- On a phone or a tablet they are a fingertip wide: tap a part, then drag a ring, an arrow or a pane with one finger, and tap the tag for the next axes. The view stays still under that finger, even if you rest it on the handle first. A second finger puts the drag back and moves the view instead.

<!-- covers
ui:handles on the selection
ui:measure and handles by finger
ui:tool modes
-->

## Mirror, replace and paint {#mirror}

- **Edit › Mirror** ([[Shift+M]]) mirrors the selection, swapping each part for its left- or right-handed twin where there is one.
- **Edit › Replace with the part in hand** ([[Alt+R]]) swaps every selected part for the one you hold, each where it was.
- [[C]] paints the selection in the current colour; the **Paint** tool paints each part you click.

<!-- covers
ui:mirror a selection
ui:replace part
-->

## Split and merge {#split-merge}

- [[Alt+S]] splits the selection: a plate, brick or tile into 1 × 1s, a 1 × 1 brick into three plates, a slope into 1-wide slopes.
- [[Alt+M]] merges the selected plates, bricks and tiles of each colour into the fewest real parts made in it: three stacked plates become a brick.

What was attached stays attached. When no real part fits, the status bar says so and nothing changes.

<!-- covers
ui:split and merge parts
-->

## Lock and hide {#lock-hide}

[[L]] locks the selection so nothing moves it by accident; [[Shift+L]] unlocks everything. [[Ctrl+H]] hides the selection, [[Shift+H]] shows only it, and [[Alt+H]] shows everything again.

<!-- covers
ui:lock parts
ui:hide and show only
-->

## Group parts into a sub-assembly {#sub-assemblies}

Select some parts and press [[Ctrl+G]] (**Build › Make a sub-assembly…**) to group and name them. A click then takes it whole; [[Enter]] or a double-click edits inside it and [[Esc]] leaves. [[F2]] renames it and **Ungroup** ([[Ctrl+Shift+G]]) takes it apart. Its [[Ctrl+D]] copies follow it, change one and they all change, until **Build › Make this copy unique**.

<!-- covers
ui:sub-assemblies
-->

## Build in sections {#sections}

Big models are built in sections, as big sets are. **Build › Suggest sections** proposes them, and the model tree's **Accept**, **Merge**, **Split** and **Evaluate** shape them. [[Y]] breaks the selected section out to work on alone, and back; [[Shift+Y]] explodes them all.

<!-- covers
ui:sections
lib:sections suggested
lib:angled sections
-->

## Undo {#undo}

[[Ctrl+Z]] undoes and [[Ctrl+Shift+Z]] redoes. **History** on the toolbar, or **Edit › History**, lists the steps to go back to. Whatever an AI puts down is one undo step too.

<!-- covers
ui:undo and redo
ui:undo history
-->

## Measure {#measure}

Press [[U]] and click two points: the distance in studs, plates and millimetres. A point near a pin, hole, axle, bar or hinge goes on its middle, and near a stud on the middle of its top; with both on one connector it gives the angle between them too, to a tenth of a degree. A stud is 8 mm across, a plate 3.2 mm tall and a brick 9.6 mm.

On a phone or a tablet, Measure is in **More › Tools**: tap two points. Each tap goes on the stud or connector nearest your fingertip, so it reads what a click right on it would. Holding your finger down doesn't pick up a part while the ruler is out.

<!-- covers
ui:measure
-->
