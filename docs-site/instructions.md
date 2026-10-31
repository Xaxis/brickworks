---
tools: edit_steps, booklet_layout, edit_booklet
panels: PageEditor#lay-out
ai: Build steps, the timeline, the booklet laid out from them as a set's is, each step's page set by hand, and saving it as PDF or PNG pages. An assistant edits steps with edit_steps, reads the booklet's pages with booklet_layout, and sets a step's page with edit_booklet.
rules:
  - A step's turn is saved as LDraw's 0 ROTSTEP, which LPub, LDCad and Studio read.
  - A model from Studio, LDCad or LeoCAD keeps its author's own steps.
title: Instructions and booklets
nav: Instructions and booklets
description: Build steps, the timeline, the booklet Brickworks lays out from them, laying a page out by hand, and saving it as a PDF.
---

## Build steps {#steps}

A model's build steps are the order it goes together in. Press [[E]] as you build: what was put down since the last step becomes one. **Build › Build steps** moves the selected parts a step earlier ([[Shift+[]]) or later ([[Shift+]]]), makes a step of them ([[Shift+N]]), and moves the step the timeline is on earlier ([[Alt+[]]) or later ([[Alt+]]]), merges it with the next ([[Alt+E]]) or deletes it ([[Alt+Delete]]).

<!-- covers
ui:build steps
-->

### Any step in one go {#move-to-step}

Under the timeline's slider is a row of the steps, one box a step. The steps the selected parts are in are marked in yellow: drag that mark onto any other step and the parts go there, however far. **Move to step…** ([[Alt+T]], also on the menu on a part) does the same with the step's number typed: [[Alt+T]], 17, [[Enter]]. Each is one Undo, and the booklet follows.

With LDCad's keys, [[Page Up]] and [[Page Down]] go to the next and previous step while the timeline is up; with Studio's, [[Ctrl+D]] and [[Ctrl+A]] move the selected parts a step later and earlier there, as in Studio's step editor.

<!-- covers
ui:any step in one go
-->

## The timeline {#timeline}

[[B]] opens the timeline under the model: the build from an empty baseplate to the finished model. [[Left]] and [[Right]] step through it, [[Space]] plays it, and [[Home]] and [[End]] go to its start and end. Its buttons are **Earlier**, **Later**, **Merge with next**, **Delete step**, **New step from selection** and **Move to step…**; click a step in its row of steps to go to it.

<!-- covers
ui:build animation
-->

### The author's steps {#authors-steps}

A model made in Studio, LDCad or LeoCAD keeps its author's own steps: the timeline opens in **Author's steps**, and the booklet follows them.

<!-- covers
ui:the author's steps
-->

## The booklet {#booklet}

**Build › Instructions…** (or **Instructions** on the toolbar) lays out a booklet from the steps, as a set's is: a cover, each step's picture with the parts it adds in a box, sub-assemblies built in callouts beside the step they go on, and the parts list at the back. It opens in its own tab, ready to print.

<!-- covers
ui:the booklet
-->

![A page of a building instructions booklet made by Brickworks.](/img/booklet-720.webp "A booklet page: each step's picture and the parts it adds.")

### Each step by hand {#booklet-by-hand}

The timeline's **Booklet** row, or **Build › Booklet page**, changes how the step the timeline is on is printed: turn the view, look from higher or lower, use the window's view, zoom in or out, bigger or smaller on the page, start a new page or have a page alone, show its parts box or not, build its sub-assembly in a callout, and how many steps go on a page. **Outline new parts** outlines each step's new parts in orange.

On a step inside a callout, **Turn left**, **Turn right**, **Higher**, **Lower**, **This view** and **Usual view** turn that step's picture alone, from the way the callout faces, and the steps after it in the callout until turned again. The turn is saved in the sub-model's file as a ROTSTEP, as LPub reads it.

<!-- covers
ui:the booklet by hand
-->

### Lay a page out {#lay-out}

**Lay out the page…** on the Booklet row puts the page in your hands: drag its picture, parts list, callout and step number where they go, and a corner to size each. **Add words**, **Add a picture…**, and **Draw an arrow**: drag it, drag its middle to bend it, and set its colour and width. A callout's own pages turn with **Previous** and **Next page**.

Words or a picture turn by the round knob above them (it settles on every 15°), or type **Turn** in degrees; **Opacity** fades them. An arrow bends through as many points as you like: drag the dot in the middle of any stretch to add a bend, and double-click a bend to take it out. Drag a guide out of the ruler along the top or the left; what you drag near it lands on it, and dragging the guide back into its ruler takes it away. Guides are never printed. The PDF and the PNG pages print each turn, fade and bend as the page shows it. Words or a picture turned beside something else are kept off it by their turned outline, as the page draws them.

Claude can do all of it for you over the connector: turn and fade words or a picture, bend an arrow through points, lay guides, and turn a callout's step. Each is one Undo.

Laid out one page the way you like, press **Apply to later pages**: every later page with as many steps gets the same layout, its picture where yours is and drawn no larger than the booklet draws a step, and moved clear of a parts list that grew for a step of many parts. One Undo takes it all back. Set **Per page** first so the pages have the same number of steps.

<!-- covers
ui:the booklet page by hand
-->

## Save it {#save}

Beside **Print**, the booklet has **Save as PDF** and **Save pages as PNG**, a .zip of a picture a page at 300 dots an inch. The PDF carries its own type, so it reads the same on any computer.

<!-- covers
ui:the booklet as a PDF and as PNG pages
-->

## On the website {#web}

A shared model's page has its booklet and **Build it**, the step player: see [A model's page](/docs/model-pages#build-it).
