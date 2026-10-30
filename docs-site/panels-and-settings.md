---
panels: ControlsDialog#settings
ai: The window's parts (menus, toolbar, the left column of parts bin, model tree and properties, the assistant on the right, the status bar), and every setting. Exact positions and hinge angles are typed in Properties.
rules:
  - Settings (,) and the keys sheet (F1, Help › Keys and controls) are two dialogs; the keys sheet keeps the rows that say what is typed into its box.
  - Properties take X, Y and Z to the hundredth of an LDraw unit.
title: Panels, layout and settings
nav: Panels and settings
description: The window's panels, the toolbar and status bar, the properties of a part, and every setting.
---

## The window {#window}

Along the top are the **menus** and under them the **toolbar**: the tools, Snap and Turn, Select by, History, Account and Share. Down the left are the **parts bin**, the **model tree** and **properties**; on the right, the **assistant** when it is on. Along the foot, the **status bar** says what just happened and what a press will do, and a strip of the commonest keys sits over the model.

<!-- covers
ui:status bar
ui:controls panel and hint
-->

## Docked panels {#panels}

Fold a panel by its header, and drag the bar between two to share the room. Under 1600 units across, one column shows beside the model. **View** turns each panel on or off, and [[Tab]] shows or hides them all. Brickworks remembers the layout, the folds and the snap you chose, and starts with them next time.

<!-- covers
ui:docked panels
ui:remembered layout
-->

## The model tree {#model-tree}

Under the parts bin, the model tree lists the model's sub-assemblies and sections by name, inside one another. Click one to select it, double-click to edit inside it. **View › Model tree** shows or hides it.

<!-- covers
ui:model tree
-->

## Properties {#properties}

Select a part and the foot of the left-hand column says what it is: its part, its colour, where it stands and what it is joined to. Type its **X**, **Y** and **Z** to the hundredth of an LDraw unit, or, when it hangs from a joint, its **Hinge** angle in degrees. With nothing selected, it holds the floor's settings.

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
