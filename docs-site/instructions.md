---
tools: edit_steps, booklet_layout
ai: Build steps, the timeline, and the booklet laid out from them as a set's is, saved as PDF or PNG pages. An assistant edits steps with edit_steps and reads the booklet's pages with booklet_layout. How a step is printed, the paper, the cover and pages laid out by hand are on the page about the booklet's layout.
rules:
  - A step's turn is saved as LDraw's 0 ROTSTEP, which LPub, LDCad and Studio read.
  - A model from Studio, LDCad or LeoCAD keeps its author's own steps.
  - A model saved in Brickworks opens again in the steps it was saved in; Plan steps works them out afresh.
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

![The timeline under the model: the car built to its first step, a slider and a row of numbered steps, the parts the step adds, and Start, Back, Reverse, Play, Next, End, the speed, Build order, the find (Find a step by part or colour), Instructions and Done, and under them the Booklet row.](/docs/img/instructions-timeline.webp "Build › Timeline (B): the steps a booklet is made of.")

[[B]] (**Build › Timeline**) opens the timeline under the model: the build from an empty baseplate to the finished model.

- **Start** and **End** ([[Home]], [[End]]) go to the empty baseplate and the finished model.
- **Back** and **Next** ([[Left]], [[Right]]) go a step at a time; click a box in the row of steps to go to that step.
- **Play** ([[Space]]) builds it, and **Reverse** takes it apart; **1x** sets the speed.
- The order button chooses what it plays: **Build order**, the way you would put it together; **As made**, the order the parts were placed in; **History**, every change; or **Author's steps**.
- **Instructions** opens the booklet, and **Done** puts the timeline away.

In **Author's steps**, a row of buttons under it changes the step showing: **Earlier**, **Later**, **Merge with next**, **Delete step**, **New step from selection** and **Move to step…**; **Plan steps** works the steps out again from the model as it is. The **Booklet** row changes how the step is printed: see [Booklet layout](/docs/booklet-layout#booklet-by-hand).

<!-- covers
ui:build animation
-->

### On a phone {#timeline-phone}

![The timeline on a phone, 390 pixels across: the car built to its fourth step, and along the foot the row of steps, the step's parts as pictures with how many of each, its words, and one row of Back, the step's number, Next, Parts and More.](/docs/img/instructions-timeline-phone.webp "On a phone: one row a thumb works, the rest in More.")

On a phone held upright the timeline is one row a thumb can work: **Back**, the step's number, **Next**, **Parts** and **More**, each a fingertip.

- **Swipe** along the bar to turn the page: to the left for the next step, to the right for the one before.
- Tap the step's number, **Step 12 of 35**, for every step at once, and tap the one to go to.
- **Parts** shows the parts the step adds as pictures, with how many of each beside them. Tap it again to give the model the room.
- **More** has the rest: **Play**, **Start** and **End**, the order, **Find…**, **Instructions**, **Done**, and the **Booklet** row.
- Put the steps away to build and open them again, and they come back to the step you left.

A tablet, and a phone held sideways, keep the whole bar.

<!-- covers
ui:the steps bar on a phone
-->

### The author's steps {#authors-steps}

A model made in Studio, LDCad or LeoCAD keeps its author's own steps: the timeline opens in **Author's steps**, and the booklet follows them. The steps you make with [[E]] are your model's author's steps too.

<!-- covers
ui:the author's steps
-->

### The steps you saved {#saved-steps}

A model you save comes back in the steps it was saved in. As you build, Brickworks works the steps out for you, and Save writes them into the file as LDraw's `0 STEP` lines, which LPub, LDCad and Studio read too. Open the model again and those are its steps: the timeline opens in **Author's steps**, and the booklet you printed or shared is the one you get back. Nothing more is written into the file to say so.

From then on, an edit changes only the steps it touches:

- A part you put down goes in the step of the part it rests on. One on the floor, or held only from the side, goes in a new last step.
- A part you put on one you put down since you opened the model goes in that one's step until the step holds as many parts as Brickworks puts in a step of a model that size (4 under 150 parts, 6 under 500, 8 from then on). The next starts a new step after the last, so ten bricks stacked one at a time are two steps or more, never one that grows each session. A part put on what the file built goes in that part's step however many are there, as a detail goes with the wall it is on.
- A part you move keeps its step, unless everything it now rests on comes later: then it goes in that step. That holds however you move it: dragged, nudged with the arrow keys, typed, turned or by an assistant. Several moved together are followed from the bottom up, each after what it rests on.
- A part you take off leaves its step, and a step left empty is gone.

Change a step yourself (**Earlier**, **Merge with next**, a part moved to another step) and the steps are yours, as an author's are. To have Brickworks work the steps out again from the model as it is, press **Plan steps** in the timeline's row: it is one Undo. A step you gave a name, notes or a page of its own keeps them on the step most of its parts go to. Where two such steps' parts come to share one step, only one name and page can stand there: **Plan steps** says how many before it changes anything, and keeps both steps' notes. An assistant asks for the same with edit_steps' plan, and is told the same after. While you hold parts you picked up, the steps wait: put them down, or press Escape, first. A Brickworks file with no steps in it, such as an older autosave, is worked out afresh when it opens.

### A step's name {#step-name}

A step can have a name, as in Studio: **Name…** in the timeline's **Booklet** row, or **Build › Build steps › Name the step…** ([[Shift+F2]]), names the step the timeline is on, "Build the cockpit". The timeline says it after the step's number, **Build it** under the number, and the booklet beside the number on its page. Clear the words to take it off. A name is up to 80 letters as you see them: an emoji or a letter with its accents counts once, and a letter keeps at most four accents. A name of only characters that show nothing (zero-width spaces, joiners, direction marks) is refused, and the dialog says why. Each is one Undo, and the name is saved with the step in the model's file. A sub-model placed more than once is built in one set of steps, so a name given to one copy's step names that step in every copy, and Brickworks says so. A step that only puts on sub-models built where they stand has no step of its own: its name is said before the name of the first step built in it, "Both wings on · Wing plate". An assistant names a step with edit_steps, a callout's step too.

<!-- covers
ui:a step's name
-->

### Find a step {#find-step}

Looking for the step that puts on the red 1 x 1 plate? Type it into the find at the end of the timeline's buttons, beside the order button: a part's number (**3024**), its name (**plate 1 x 1**, or **1x1 plate**), a colour (**red**) or both (**red 3024**). As you type, it lists every step that places one, with how many where it is more than one ("7 ×2"), and marks those steps along the top of the row of steps. Click one to go there; [[Enter]] goes to each in turn, and [[Shift+Enter]] back. [[Escape]] clears it, and **Done** takes it away with the timeline.

A part in a sub-model is found in the sub-model's own steps, the step that builds it, with every copy counted: "14 · Support Vehicle - Hose ×48" is step 14, built 48 times. When no step places what you typed, it says so, and where the model has the part in another colour, which: "No step places “blue 3024”: the model has it in 4 other colours". On a phone or a tablet, **Find…** opens it above the keyboard. An assistant finds the same steps with edit_steps' find.

<!-- covers
ui:find a step by what it places
-->

## The booklet {#booklet}

**Build › Instructions…** ([[Alt+B]], or **Instructions** on the toolbar or the timeline, and in **File › Export** beside the other files a model is written as) lays the booklet out from the steps and opens it in its own tab. In the desktop app it first asks where to save it, a PDF first: name it `.pdf` and the PDF is written there and opens in your PDF reader; choose **Web page** as the type and the booklet opens in your browser, to print or save as a PDF there.

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

A shared model's page has its booklet and **Build it**, the step player: see [A model's page](/docs/model-pages#build-it). Its last step posts a photo of what you built on the model's page: [Show your build](/docs/model-pages#show-your-build).
