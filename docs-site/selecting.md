---
tools: selection, edit_selection
ai: Selecting parts by click, box, colour, part or connection, and what a selection can do, from its keys and the menu on a part. Asked about a selection, an assistant reads it with selection and changes only it with edit_selection.
rules:
  - edit_selection may change only the selected parts and the room just round them; more room must be asked for (room, why).
  - A change that reaches outside the selection is refused whole.
title: Selecting and editing
nav: Selecting and editing
description: Choose one part, many, or every part like it, and what you can do to a selection from its keys and the menu on a part.
---

What you select is what the next key, tool or command changes. Select by clicking in the model, by **Edit › Select by** or **Select by** on the toolbar, and right-click a part for everything you can do to it.

## Click, add and take away {#click}

Click a part to select it: it is outlined in yellow, and a part under the pointer is outlined faintly (in a browser with no graphics card to draw with, once the pointer stops). [[Shift]]-click or [[Ctrl]]-click adds a part or takes it away. [[Ctrl+A]] selects everything, [[Ctrl+Shift+A]] nothing, and [[Esc]] closes whatever is open, then lets go of the selection.

<!-- covers
ui:selection outline
ui:the hover drawn at the device's pace
ui:selection edits
-->

## Draw a box round them {#box}

[[Ctrl]]-drag starting off any part, on the baseplate or the space round it, to draw a box: every part inside it is selected. ([[Ctrl]]-drag on a part copies it.)

<!-- covers
ui:box select
-->

## Take every part like it {#select-by}

![The red car with every red part outlined as selected after Same colour, the other colours left out.](/docs/img/selecting-same-colour.webp "Edit › Select by › Same colour (Alt+C) takes every part of the selection's colour.")

Select one part, then choose from **Select by** on the toolbar or **Edit › Select by**:

| Choose | Key | What it takes |
|---|---|---|
| Same colour | [[Alt+C]] | every part of its colour |
| Same part | [[Alt+P]] | every part of its shape, in any colour |
| Same part and colour | [[Alt+A]] | both at once; [[Shift]]-double-click does the same |
| Everything connected | [[Alt+J]] | everything held to it, through studs and joints |
| Same sub-model | | the sub-assembly it belongs to |
| Part number or name… | [[Ctrl+F]] | parts found by number, name or colour |
| The opposite | [[Alt+I]] | everything that is not selected |

<!-- covers
ui:select by colour part or connection
-->

## Change a selection by key {#edits}

| Press | What happens |
|---|---|
| [[C]] | Paint it the current colour |
| Arrows, [[W]] [[A]] [[S]] [[D]] | Nudge it; with nothing selected, turn or slide the view |
| [[Page Up]], [[Page Down]] | Raise or lower it |
| [[X]] | Lift it to carry it; a click puts it down |
| [[R]] | Turn it where it stands |
| [[Delete]] | Take it away |
| [[Shift+M]] | Mirror it |
| [[Ctrl+G]] | Make it a sub-assembly |
| [[L]] | Lock it |
| [[Ctrl+H]], [[Shift+H]] | Hide it, or show only it |

Each is explained on [Moving and changing parts](/docs/changing-parts).

## Use the menu on a part {#part-menu}

![The menu that opens on a right-click on a part, with ways to select what is like it or connected to it, hide it, paint it, copy it and more.](/docs/img/selecting-menu.webp "A right-click on a part opens its menu.")

Right-click a part and its menu has, from the top:

- **Ask Claude about this…**, with the assistant on ([Designing with AI](/docs/ai)), and **Ask Claude to brace this…** while **View › Stress** shows the part weak; **Comment on it…**, pinned to the part.
- **Select everything joined to it**, **Select the same part**, **Select the same colour**.
- **Hide** and **Show only the selection**.
- **Copy**, **Duplicate**, **Delete**.
- **Paint with** the colour in hand, **Split into smaller parts**, **Merge into bigger parts**, **Replace with the part in hand** and **Printed versions…**.
- **Swing on its hinge**, for a part that hangs from one.
- **Move to previous step**, **Move to next step** and **Move to step…**, for the [build steps](/docs/instructions).
- **Make a sub-assembly…** and **Properties**.

Every row and its key: [On a part](/docs/menus#on-a-part).

## Swing on a hinge {#swing}

Select what hangs from a hinge, a clip or a turntable and press [[J]] to swing it one way, [[Shift+J]] the other, as far as it has room. Its exact angle is typed in [Properties](/docs/panels-and-settings#properties).

<!-- covers
ui:swing on a hinge
-->

## Meet on hinges {#meet}

Select a part and the part it should meet, across a chain of hinges, clips or turntables, and press **Meet** in [Properties](/docs/panels-and-settings#properties). Every joint between them swings so a free end of one takes a free end of the other: a click hinge's finger goes into a fork, a pin into its eye, a clip onto a bar. A line of eight hinged plates closes into a ring, 45° each; a wing swings up to meet its strut.

Each joint turns as little as it can, and a click hinge stops on its clicks. Everything built on the chain comes along, in one step to undo. When no swing can make them meet, nothing moves, and the status bar says how far apart the nearest swing leaves them, or what is in the way.

<!-- covers
ui:meet on hinges
-->
