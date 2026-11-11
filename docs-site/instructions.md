---
tools: edit_steps, booklet_layout
ai: Build steps, the timeline, and the booklet laid out from them as a set's is, saved as PDF or PNG pages. An assistant edits steps with edit_steps and reads the booklet's pages with booklet_layout. How a step is printed, the paper, the cover and pages laid out by hand are on the page about the booklet's layout.
rules:
  - A step's turn is saved as LDraw's 0 ROTSTEP, which LPub, LDCad and Studio read.
  - A model from Studio, LDCad or LeoCAD keeps its author's own steps.
title: Instructions and booklets
nav: Instructions and booklets
description: Build steps, the timeline that plays them, and the booklet of building instructions Brickworks lays out from them, saved as a PDF.
---

Build steps are the order a model goes together in. From them Brickworks lays out building instructions as a set's booklet has them, ready to print or save as a PDF. Steps are in **Build › Build steps** and on the timeline ([[B]]); the booklet is **Build › Instructions…** ([[Alt+B]]).

## A booklet in three steps {#quick}

1. As you build, press [[E]] each time a step is done: whatever you put down since the last step becomes one.
2. Press [[Alt+B]]. The booklet opens in a tab of its own: a cover, each step's picture with the parts it adds in a box, sub-assemblies built in callouts beside the step they go on, and the parts list at the back.
3. Press **Save as PDF** at the top of the booklet, or **Print**.

A model from Studio, LDCad or LeoCAD already has its author's steps, so you can go straight to step 2.

![A page of a building instructions booklet made by Brickworks.](/img/booklet-720.webp "A booklet page: each step's picture and the parts it adds.")

<!-- covers
ui:the booklet
-->

## Change the steps {#steps}

**Build › Build steps** has every change, and each is one Undo:

| To | Press |
|---|---|
| Close a step: what you put down since becomes one | [[E]] |
| Move the selected parts a step earlier or later | [[Shift+[]], [[Shift+]]] |
| Make a step of the selected parts | [[Shift+N]] |
| Move the selected parts to any step | [[Alt+T]], its number, [[Enter]] |
| Move the step the timeline is on earlier or later | [[Alt+[]], [[Alt+]]] |
| Merge it with the next step | [[Alt+E]] |
| Take the step out, its parts joining the step before | [[Alt+Delete]] |

<!-- covers
ui:build steps
-->

### Any step in one go {#move-to-step}

Under the timeline's slider is a row of the steps, one box a step. The steps the selected parts are in are marked in yellow: drag that mark onto any other step, however far, and the parts go there. The booklet follows.

With LDCad's keys, [[Page Up]] and [[Page Down]] go to the next and previous step while the timeline is up; with Studio's, [[Ctrl+D]] and [[Ctrl+A]] move the selected parts a step later and earlier, as Studio's step editor does.

<!-- covers
ui:any step in one go
-->

## The timeline {#timeline}

![The timeline under the model: the car built to its first step, a slider and a row of numbered steps, the parts the step adds, and Start, Back, Reverse, Play, Next, End, the speed, Build order, Instructions and Done.](/docs/img/instructions-timeline.webp "Build › Timeline (B): the steps a booklet is made of.")

[[B]] (**Build › Timeline**) opens the timeline under the model: the build from an empty baseplate to the finished model.

- **Start** and **End** ([[Home]], [[End]]) go to the empty baseplate and the finished model.
- **Back** and **Next** ([[Left]], [[Right]]) go a step at a time; click a box in the row of steps to go to that step.
- **Play** ([[Space]]) builds it, and **Reverse** takes it apart; **1x** sets the speed.
- The order button chooses what it plays: **Build order**, the way you would put it together; **As made**, the order the parts were placed in; **History**, every change; or **Author's steps**.
- **Instructions** opens the booklet, and **Done** puts the timeline away.

In **Author's steps**, a row of buttons under it changes the step showing: **Earlier**, **Later**, **Merge with next**, **Delete step**, **New step from selection** and **Move to step…**. The **Booklet** row changes how the step is printed: see [Booklet layout](/docs/booklet-layout#booklet-by-hand).

<!-- covers
ui:build animation
-->

### The author's steps {#authors-steps}

A model made in Studio, LDCad or LeoCAD keeps its author's own steps: the timeline opens in **Author's steps**, and the booklet follows them. The steps you make with [[E]] are your model's author's steps too.

<!-- covers
ui:the author's steps
-->

## The booklet {#booklet}

**Build › Instructions…** ([[Alt+B]], or **Instructions** on the toolbar or the timeline) lays the booklet out from the steps and opens it in its own tab.

To change how a step is printed, the paper, the cover or the layout of a page, see [Booklet layout](/docs/booklet-layout).

## Save it as a PDF or pictures {#save}

At the top of the booklet:

- **Print** prints it.
- **Save as PDF** saves it as one PDF, its type in the file, so it reads and prints the same on any computer. Its words are words, so a reader can find and copy a step number or a part's element number.
- **Save pages as PNG** saves a .zip of a picture a page, at 300 dots an inch.

The booklet's own page is 269 x 199 mm on its side, which fits A4 and US Letter turned on their side with a margin to spare, so one PDF prints on both.

The PDF prints Latin, Cyrillic, Greek, Hebrew and Arabic letters as you typed them, and emoji in outline. A letter no font here has (Japanese, on the web) prints as **?**, and the message after the save names those letters; the booklet's page and its PNG pages show them as typed.

<!-- covers
ui:the booklet as a PDF and as PNG pages
-->

## On the website {#web}

A shared model's page has its booklet and **Build it**, the step player: see [A model's page](/docs/model-pages#build-it).
