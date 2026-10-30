---
ai: A walk through one small model by hand: put parts down, change them, make a build step, save, check that it stands, and share it. The same steps an assistant takes with tools: edit_model, edit_steps, save_model, check_design.
rules:
  - A step is everything put down since the last one (E).
  - The first save asks for a name; File › Versions keeps the last 20 saves.
title: Your first model
nav: Your first model
description: Put parts down, colour and turn them, make a step, save the model and share it, in about ten minutes.
---

This walks through one small model from an empty baseplate to a link you can send. Everything here works the same in a browser and in the desktop app.

## 1. Take the tour {#tour}

**Help › Take the tour** shows where everything is, a panel at a time. A first visit opens on an example model; **File › New** clears the baseplate for your own.

<!-- covers
ui:tour
-->

## 2. Put a part down {#place}

Press [[P]] or click a part in the **parts bin** on the left: it is now *in hand* and follows the pointer over the baseplate, snapping to the studs. Click to put it down. It stays in hand, so each click puts down another. Press [[Esc]] or right-click to let go, and [[Q]] to take the last part back.

- [[R]] turns the part in hand a quarter turn; [[T]] tips it onto its side.
- [[[]] and [[]]] step through colours; [[Shift+C]] asks for a colour by name or number.
- A part aimed under an overhang goes underneath it; a part tipped with [[T]] and aimed at a side stud goes on sideways.

## 3. Change it {#change}

Click a part to select it. Drag it to carry it somewhere else, press [[Delete]] to take it away, [[C]] to paint it in the current colour, or [[Ctrl+D]] to duplicate it. [[Ctrl+Z]] undoes anything, and **Edit › History** goes back several steps at once.

## 4. Make a step {#step}

Press [[E]] when a stage is done: everything put down since the last step becomes one build step. [[B]] opens the timeline to see them in order. The booklet and the step player on your model's page follow these steps. See [Instructions and booklets](/docs/instructions).

## 5. Save it {#save}

Press [[Ctrl+S]]. The first save asks what to call the model. It is kept in this browser (or on this computer) and with your account, so **File › Open** finds it anywhere you sign in. **File › Versions…** keeps its last 20 saves.

## 6. Check it holds {#check}

**Tools › Check stability** shows whether it would stand and which joints would give way. A red part is one that would come loose. See [Joints and mechanisms](/docs/joints-and-mechanisms#stability).

## 7. Share it {#share}

**File › Share…** publishes the model with a picture, a name and a kind. You get a link anyone can open in 3D, step through and build, with no account. See [Sharing a model](/docs/sharing).

> [!TIP]
> Want Claude to build the first draft? Turn on the assistant (**Tools › Settings…**, *Assistant (AI)*) and see [Connect Claude](/docs/connect-claude).
