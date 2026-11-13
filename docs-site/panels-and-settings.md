---
panels: ControlsDialog#settings
ai: The window's parts (the menus with Account at the far right, the toolbar, the parts bin and its colours down the left, the model tree and properties down the right with the assistant as a tab beside them, the key strip over the model, the status bar), Properties, the keys sheet, your own keys, and every setting. Exact positions and hinge angles are typed in Properties; in_view reads the model's size and weight as the status bar says them.
rules:
  - Settings (,) and the keys sheet (F1, Help › Keys and controls) are two dialogs; the keys sheet keeps the rows that say what is typed into its box.
  - Properties take X, Y and Z to the hundredth of an LDraw unit.
title: Panels, layout and settings
nav: Panels and settings
description: The window's panels, the toolbar and status bar, the properties of a part, and every setting.
---

This page is a map of the window, what Properties holds, and every setting. Settings is **Tools › Settings…** ([[,]]); every key is on the keys sheet, **Help › Keys and controls** ([[F1]]).

## The window {#window}

![The Brickworks window with a part of the red car selected, eight parts outlined and numbered: the menus, the toolbar, the parts bin, the colours, the view cube, the key strip, Properties down the right, and the status bar.](/docs/img/panels-window.webp "The window: 1 menus, 2 toolbar, 3 parts bin, 4 colours, 5 view cube, 6 key strip, 7 Properties, 8 status bar.")

1. **Menus**, with the Brickworks menu at the far left (Find a command, the docs, About) and **Account** at the far right.
2. **Toolbar**: file, undo, the tools, Snap and Turn, and the view tools.
3. **Parts bin**, with **Make a part…**, **Print…** and **Stickers…** at its top.
4. **Colours**, under the bin.
5. **View cube** ([The view](/docs/the-view#view-cube)).
6. **Key strip**: the commonest keys and mouse moves, over the model. **View › Panels › Key strip** hides it.
7. **Properties** and the model tree, down the right. With the assistant on, it has a tab of its own on the same strip, and one shows at a time.
8. **Status bar**: what just happened, what a click would do now, and the model's size.

Rest on a control for its tooltip; it never blocks a click. A long job shows a bar at the foot with **Cancel**. To ask what any control does, use [What's This?](/docs/accessibility#whats-this).

<!-- covers
ui:status bar
ui:controls panel and hint
ui:tooltips let clicks through
ui:what the app is busy with
-->

## Size and weight {#size}

The status bar says how many parts the model has, whether it stands, its weight, and its size in studs, plates and centimetres, as "61 bricks · stands up · 52 g · 4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 × 4.96 cm". The baseplate is left out. Select some parts and it says their size instead. With a part in hand it says where a click would put it: "x 3, z 1 studs · 6 plates up".

<!-- covers
ui:model size and weight
-->

## Docked panels {#panels}

Fold a panel by its header, and drag the bar between two to share the room. A click on a column's strip folds it to the edge; another brings it back. In a window about 1,350 pixels wide or more, both columns show beside the model; narrower, one at a time. **View › Panels** shows or hides each, and [[Tab]] all of them. The layout is remembered.

Panels that open over the model (the keys sheet, Render, the parts list) stack like windows: the last opened is in front, and a click or its key brings one forward.

<!-- covers
ui:docked panels
ui:remembered layout
ui:the panel asked for last in front
-->

## The model tree {#model-tree}

The model tree lists the model's sub-assemblies and sections by name, one inside another. Click one to select it, double-click to edit inside it.

Drag one onto another to put it inside that one, or onto **Model** to bring it back to the top. The row it would go into is outlined as you carry it, and none is where it cannot go (into itself, where it already is, or into what is inside it). Hold it at the tree's top or bottom edge to scroll to a row out of sight. Each drop is one step of **Undo**. A suggested section dragged onto another merges them. On a phone or a tablet, hold the row a moment, then drag it: a finger that moves at once scrolls the tree. A model shared to look at, or one still opening, takes no drop.

<!-- covers
ui:model tree
-->

## Properties {#properties}

Select a part and Properties says what it is: its part, colour, place and what it is joined to. Type its **X**, **Y** and **Z** (to the hundredth of an LDraw unit), its **Turn**, **Tilt** and **Roll**, or, on a joint, its **Hinge** angle. With two parts selected across hinges, **Meet** swings them together ([Meet on hinges](/docs/joints-and-mechanisms#meet)). With nothing selected it holds the floor and the model's size and weight.

While Properties is folded, the same fields sit under the parts bin; **More** opens the rest.

<!-- covers
ui:properties panel
ui:properties under the bin
ui:typed place and hinge
-->

## Your own keys {#keys}

**Keys like**, in the keys sheet or Settings, puts on the keys of BrickLink Studio, Mecabricks or LDCad. With Studio's, [[V]] is Select, [[C]] Clone, [[H]] Hinge and [[L]] Hide.

To set one yourself, click a key in the keys sheet and press the new one; [[Esc]] keeps the old, [[Backspace]] leaves none. A key another command has is refused, saying whose it is. [[Esc]], [[Enter]], [[Tab]], [[F1]] and the browser's own keys ([[Ctrl+N]], [[Ctrl+T]], [[Ctrl+W]]) cannot be set. **Back to these keys** drops yours. Signed in, your keys follow you to any browser.

<!-- covers
ui:keys of one's own
-->

## Colours on keys {#colour-keys}

[[Shift+1]] to [[Shift+0]] paint the selection one of ten favourite colours, and [[Ctrl+Shift+1]] to [[Ctrl+Shift+0]] the colours the model uses most. With a part in hand, the key is its colour. To change a favourite, find **Colours** in the keys sheet and click its swatch.

<!-- covers
ui:colour keys
-->

## Settings {#settings}

![Settings: Invert zoom direction, Navigate like Studio, Keys like Brickworks and Graphics, Interface size 100% and Language, Reduce motion and Say when a long job is done, New models start on, Assistant (AI) with AI: Claude…, and the version and Updates at the foot.](/docs/img/panels-settings.webp "Tools › Settings… (,) in the desktop app; a browser has no Graphics or Updates.")

- **Invert zoom direction**, and **Navigate like** Studio, Blender or Mecabricks ([The view](/docs/the-view#presets)).
- **Keys like** (above).
- **Interface size**, 85 to 150%, and **Reduce motion** ([Accessibility](/docs/accessibility)).
- **Language**: English, Deutsch, Français or Español. Parts and colours keep their names. A link can choose one: brickworks.diy/app?lang=de.
- **Say when a long job is done**: a design, a Best render, the render queue or a build video that finishes while you are elsewhere says so (a browser asks first whether it may notify you).
- **New models start on**: the floor a new model gets.
- **Assistant (AI)**: *Build by hand only*, or *Show the assistant* ([Connect your AI](/docs/connect#assistant-on)). **AI: Claude…** chooses who designs ([Another AI on your own key](/docs/ai#other-ais)).
- The app's version, at the foot. The desktop app adds **Graphics** and **Updates** ([The desktop app](/docs/web-and-desktop#desktop)).

<!-- covers
ui:interface languages
ui:a long job says when it is done
-->

## The keys sheet {#keys-sheet}

![The keys sheet with turn typed in its box: only the rows that say turn are left, each with its keys drawn as keys.](/docs/img/panels-keys.webp "Help › Keys and controls (F1), searched for turn.")

**Help › Keys and controls** ([[F1]]) lists every key and mouse move, drawn as keys and pictures of the mouse. Type in its box and only the rows that say it stay: *turn*, *hinge*, *Ctrl*. [[Esc]] closes it. Every key is also on [Keyboard shortcuts](/docs/shortcuts).

## How the app's dialogs look {#dialogs}

Every dialog, chooser and menu has the panels' dark face, every button is edged so it can be seen, and a question's default button is the strong blue one.

<!-- covers
ui:the app's dialogs and menus
ui:buttons seen and read
-->
