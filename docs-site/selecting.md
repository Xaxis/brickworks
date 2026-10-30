---
tools: selection, edit_selection
ai: Selecting parts by click, box, colour, part or connection, and what a selection can do. Asked about a selection, an assistant reads it with selection and changes only it with edit_selection.
rules:
  - edit_selection may change only the selected parts and the room just round them; more room must be asked for (room, why).
  - A change that reaches outside the selection is refused whole.
title: Selecting and editing
nav: Selecting and editing
description: Choose one part, many, or every part like it, and what you can do to a selection.
---

## Click, add and take away {#click}

Click a part to select it; it is outlined in yellow, and a part under the pointer is outlined faintly. [[Shift]]-click or [[Ctrl]]-click adds a part to the selection or takes it away. [[Ctrl+A]] selects everything, and [[Esc]] lets go of whatever is open, then of the selection.

<!-- covers
ui:selection outline
ui:selection edits
-->

## Box select {#box}

[[Ctrl]]-drag on the baseplate (on nothing) draws a box: every part inside it is selected.

<!-- covers
ui:box select
-->

## Select by colour, part or connection {#select-by}

Select a part, then **Select by** on the toolbar or **Edit › Select by**:

- **Same colour**, **Same part**, or **Same part and colour**: every part that matches it. [[Shift]]-double-click picks every part like it at once.
- **Everything connected**: everything held to it, through studs and joints.
- **Same sub-model**: the sub-assembly it belongs to.
- **Part number or name…**: find parts in the model by number, name or colour.
- **The opposite**: everything that is not selected.

<!-- covers
ui:select by colour part or connection
-->

## What a selection can do {#edits}

| Press | What happens |
|---|---|
| [[C]] | Paint it the current colour |
| Arrows, [[W]] [[A]] [[S]] [[D]] | Nudge it a step; with nothing selected, turn or slide the view |
| [[Page Up]], [[Page Down]] | Raise or lower it |
| [[Delete]] | Take it away |
| [[X]] | Lift it to move it; click to put it down |
| [[R]] | Turn it where it stands |
| [[J]], [[Shift+J]] | Swing it on the hinge it hangs from |
| [[Shift+M]] | Mirror it |
| [[Ctrl+G]] | Make it a sub-assembly |
| [[L]] | Lock it |
| [[Ctrl+H]], [[Shift+H]] | Hide it, or show only it |

A right-click on a part opens its menu: Ask Claude about it, select what is connected, hide, paint, its printed versions, copy, delete, make a sub-model and its properties. See [On a part](/docs/menus#on-a-part).

## Swing on a hinge {#swing}

Select what hangs from a hinge, a clip or a turntable and press [[J]] to swing it one way, [[Shift+J]] the other, as far as it has room. Its exact angle can be typed in [Properties](/docs/panels-and-settings#properties).

<!-- covers
ui:swing on a hinge
-->

## Meet on hinges {#meet}

Select a part and the part it should meet, across a chain of hinges, clips or turntables, and press **Meet** in [Properties](/docs/panels-and-settings#properties). Every joint between them swings so a free hinge end of one takes a free end of the other: a click hinge's finger goes into a fork, a pin into its eye, a clip onto a bar. A line of eight hinged plates closes into a ring, 45° each; a wing swings up to meet its strut.

Each joint turns as little as it can, and a click hinge stops on its clicks. Everything built on the chain comes along, and the whole swing is one step to undo. When no swing can make them meet, nothing moves, and the status bar says why: how far apart the nearest swing leaves them, in plates, or what would be in the way.

<!-- covers
ui:meet on hinges
-->
