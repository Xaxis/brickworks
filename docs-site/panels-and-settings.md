---
panels: ControlsDialog#settings
ai: The window's parts (menus, toolbar, the parts bin and its colours down the left, the model tree and properties down the right with the assistant as a tab beside them, the status bar), and every setting. Exact positions and hinge angles are typed in Properties.
rules:
  - Settings (,) and the keys sheet (F1, Help › Keys and controls) are two dialogs; the keys sheet keeps the rows that say what is typed into its box.
  - Properties take X, Y and Z to the hundredth of an LDraw unit.
title: Panels, layout and settings
nav: Panels and settings
description: The window's panels, the toolbar and status bar, the properties of a part, and every setting.
---

## The window {#window}

Along the top are the **menus** and under them the **toolbar**: the tools, Snap and Turn, Select by, History, Account and Share. Down the left are the **parts bin** and its colours. Down the right are the **model tree** and **properties**, and the **assistant** when it is on, as a tab beside them: the strip at the column's edge has one for each, and a click on one shows it. Along the foot, the **status bar** says what just happened and what a press will do, and a strip of the commonest keys sits over the model.

<!-- covers
ui:status bar
ui:controls panel and hint
-->

## Your own keys {#keys}

Every tool has a key: [[Shift+X]] Move, [[Shift+O]] Rotate, [[Shift+I]] Hinge, [[Shift+V]] Clone, [[Shift+P]] Paint, [[Shift+G]] Hide and [[Shift+Delete]] Delete. [[C]] paints what is selected; with nothing selected, it says how to paint.

Coming from another program? In the keys sheet ([[F1]]), or in Settings, **Keys like** puts on the keys of BrickLink Studio, Mecabricks or LDCad: with Studio's, [[V]] is Select, [[C]] Clone, [[H]] Hinge, [[L]] Hide, [[Ctrl+G]] makes a sub-model, the arrows turn the part, and [[W]] [[A]] [[S]] [[D]] move it.

To set a key yourself, click it in the keys sheet and press the one you want. [[Esc]] keeps the old key, [[Backspace]] leaves it with none. A key another command already has is refused, and the sheet says whose it is. A few keys are kept for themselves ([[Esc]], [[Enter]], [[Tab]], [[F1]]), and in a browser the browser's own ([[Ctrl+N]], [[Ctrl+T]], [[Ctrl+W]]). **Back to these keys** drops the ones you set. Your keys stay on this computer, and when you are signed in they go with your account to any browser or computer you sign in on.

<!-- covers
ui:keys of one's own
-->

## Colours on keys {#colour-keys}

Select some parts and press [[Shift+1]] to [[Shift+0]] to paint them one of your ten favourite colours, or [[Ctrl+Shift+1]] to [[Ctrl+Shift+0]] for the colours the model uses most, [[Ctrl+Shift+1]] the most. One key paints them all, and one [[Ctrl+Z]] takes it back. With a part in hand, the key is that part's colour. [[[]] and [[]]] still step through the colours beside the one you have.

The favourites start as the colours LEGO® sets use most: Black, Light Bluish Grey, White and so on. To change one, open the keys sheet ([[F1]]), find **Colours**, click a favourite's swatch and pick a colour. Your favourites are kept with your keys, so they follow your account. With Studio's keys they have no key at first, as in Studio; set any of them in the sheet.

To select more like what is selected: [[Alt+C]] the same colour, [[Alt+P]] the same part, [[Alt+J]] everything joined to it, [[Alt+I]] everything else. With Studio's keys, [[Shift+V]] goes through the same colour, the same part, both and everything joined, a press each.

<!-- covers
ui:colour keys
-->

## Docked panels {#panels}

Fold a panel by its header, and drag the bar between two to share the room. A click on a column's strip folds it away to the edge, and another brings it back. The model keeps at least 60% of the window's width, so in most windows one column shows beside it at a time, and opening one folds the other; a window about twice as wide as it is tall shows both. **View** turns each panel on or off, and [[Tab]] shows or hides them all. Brickworks remembers the layout, the folds and the snap you chose, and starts with them next time.

<!-- covers
ui:docked panels
ui:remembered layout
-->

## The model tree {#model-tree}

At the top of the right-hand column, the model tree lists the model's sub-assemblies and sections by name, inside one another. Click one to select it, double-click to edit inside it. **View › Model tree** shows or hides it.

<!-- covers
ui:model tree
-->

## Properties {#properties}

Select a part and the right-hand column says what it is, under the model tree: its part, its colour, where it stands and what it is joined to, every field in sight. Type its **X**, **Y** and **Z** to the hundredth of an LDraw unit, or, when it hangs from a joint, its **Hinge** angle in degrees. With nothing selected, it holds the floor's settings.

<!-- covers
ui:properties panel
ui:typed place and hinge
-->

## Tooltips and busy work {#busy}

Rest on a control for its tooltip; a tooltip never blocks a click on what is under it. When a command takes more than a moment, a bar at the foot says what Brickworks is working on, with **Cancel**.

<!-- covers
ui:tooltips let clicks through
ui:what the app is busy with
-->

## Settings {#settings}

**Tools › Settings…** ([[,]]) opens Settings, what you can change:

- **Navigate like** Studio, Blender or Mecabricks, and which way the wheel zooms ([The view](/docs/the-view#presets)).
- **New models start on**: the floor a new model gets.
- **Interface size** (85 to 150%) and **Reduce motion** ([Accessibility](/docs/accessibility)).
- **Assistant (AI)**: *Build by hand only*, or *Show the assistant* ([Connect Claude](/docs/connect-claude#assistant-on)), and **AI…**: who designs, Claude or another AI on your own key ([Another AI on your own key](/docs/ai#other-ais)).
- The app's version, at the foot.

**Help › Keys and controls** ([[F1]]) opens the keys sheet on its own: every key and gesture, drawn as keys and pictures of the mouse, in two columns as tall as the window, with the keys the menus show beside them ([Keyboard shortcuts](/docs/shortcuts)). Type into its box and only the rows whose keys or words say it stay: *hinge*, *undo*, *Ctrl*. The letters go to the box, not to the tools they are keys of; Escape closes it.
