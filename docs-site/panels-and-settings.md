---
panels: ControlsDialog#settings
ai: The window's parts (menus, toolbar, the parts bin and its colours down the left, the model tree and properties down the right with the assistant as a tab beside them, the status bar), and every setting. Exact positions and hinge angles are typed in Properties.
rules:
  - Settings and Keys and controls (F1) are one panel.
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

## Docked panels {#panels}

Fold a panel by its header, and drag the bar between two to share the room. A click on a column's strip folds it away to the edge, and another brings it back. In a window narrower than about 1,260 pixels, one column shows beside the model at a time. **View** turns each panel on or off, and [[Tab]] shows or hides them all. Brickworks remembers the layout, the folds and the snap you chose, and starts with them next time.

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

**Tools › Settings…** ([[,]]) and **Help › Keys and controls** ([[F1]]) open one panel: the list of every key and gesture, drawn as keys and pictures of the mouse, and beside it what you can change:

- **Navigate like** Studio, Blender or Mecabricks, and which way the wheel zooms ([The view](/docs/the-view#presets)).
- **New models start on**: the floor a new model gets.
- **Interface size** (85 to 150%) and **Reduce motion** ([Accessibility](/docs/accessibility)).
- **Assistant (AI)**: *Build by hand only*, or *Show the assistant* ([Connect Claude](/docs/connect-claude#assistant-on)), and **AI…**: who designs, Claude or another AI on your own key ([Another AI on your own key](/docs/ai#other-ais)).
- The app's version, under the list.
