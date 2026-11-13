---
tools: save_model, open_model
panels: SavedModelsDialog#rename, VersionsDialog#versions, CompareView#compare, LibraryDialog#library
ai: Saving and opening models, their last 20 versions and what changed since each, the library of real sets, and the files Brickworks opens (LDraw, Studio, LDD, 3D models). An assistant saves with save_model and opens a saved model, a version, a gallery model or a library set with open_model; open_model versions=true version=N reads what changed since that save, opening nothing.
rules:
  - Saved names are unique: a save under a name another model has is refused.
  - Opening over unsaved changes asks first; open_model takes discard_changes.
  - An account keeps up to 500 models today; once plans are on, Free keeps 25 and Pro any number.
title: Saving, opening and files
nav: Saving and files
description: Save a model, find it again, get an earlier save back, and bring in files from other programs.
---

Every model you save is kept in this browser and with your account, so it opens on any computer you sign in on, and the last 20 saves of each are kept too. It is all in the **File** menu.

## Save {#save}

1. Press [[Ctrl+S]] (**File › Save**).
2. The first time, say what to call the model and press **Save**. A name another saved model has is refused: choose another.

**File › Save as…** ([[Ctrl+Shift+S]]) saves a copy under a new name, and you go on working in the copy.

<!-- covers
ui:name asked at the first save
lib:save and reopen
lib:browser keeps the models
lib:models kept with the account
api:/api/models
-->

> [!NOTE]
> An account keeps up to 500 models today; once plans are on, Free keeps 25 and Pro any number ([Plans](/docs/plans)). Near the limit Brickworks says so, and **Delete old models…** makes room. A browser can clear what a site keeps when it runs short of space: if yours might, Brickworks says so once, and your account's copy keeps your models safe.

<!-- covers
ui:models may be cleared warning
ui:account full offer
-->

## Pick up where you left off {#start-up}

Each tab keeps its model a few seconds after every change, saved or not. Reload, close the tab or come back tomorrow, and the model is there as you left it. With nothing to come back to, Brickworks opens your last saved model, or the example car.

If that model cannot be opened (none of its parts are in the catalogue), Brickworks says so above the model and keeps it in **File › Open** as it was, never lost.

<!-- covers
ui:working model that could not open
-->

## Open a model {#open}

![File › Open… as a menu: From a file on this computer, From the library, and Rename or delete saved models at the top; then three saved models, newest first, each with its count of bricks and when it was saved; then the examples.](/docs/img/saving-open.webp "File › Open… (Ctrl+O): your saved models, newest first, then the examples.")

**File › Open…** ([[Ctrl+O]]) lists your saved models, newest first, each with how many bricks it has and when it was saved, then the examples. Choose one to open it. **File › Open recent** has your last eight.

If the model on the baseplate has changes you have not saved, Brickworks asks first: **Save**, **Don't save** or **Cancel**. After **Don't save**, **Edit › Undo** still brings them back.

<!-- covers
ui:open over unsaved work
-->

### Rename or delete a model {#rename}

**Rename or delete saved models…**, at the top of **File › Open…**, lists them all with **Rename…** and **Delete…**. A delete asks first, and the row it leaves has **Undo**.

<!-- covers
ui:rename or delete saved models
-->

## Start another model {#new}

- **File › New** ([[Ctrl+N]]) starts a model on an empty baseplate, asking first if the one there has changes not saved.
- **File › New tab** starts one in a tab of its own, leaving this one as it is (**New window**, [[Ctrl+Shift+N]], in the desktop app).
- **File › Clear the baseplate…** takes every brick off the model you are in. It asks first, and it cannot be undone.

## Get an earlier save back {#versions}

![The Versions dialog for Red car: a line on what Open and Compare do, a note that the model has changes not saved, Save it now, then its four saves, newest first, each with the day, the time and its count of parts, the newest marked the last save, and Compare and Open on each.](/docs/img/saving-versions.webp "File › Versions…: the model's last 20 saves, to compare or open.")

Every save is also kept as a version: the last 20 of each model. A save that changes nothing keeps no copy.

1. Choose **File › Versions…**. The saves of the model on the baseplate are listed newest first, each with when it was saved and how many parts it has.
2. Press **Compare** to see what changed since that save, or **Open** to put that save on the baseplate in place of what is there. Save it then, and it is the newest again.

If the model has changes you have not saved, Versions says so: **Save it now** keeps them as a version before you open another.

<!-- covers
ui:versions of a model
lib:model versions
-->

## Compare with a save {#compare}

**File › Compare › Compare with…**, or **Compare** on a row of **File › Versions…**, shows what changed since that save, on the model itself:

- added since: green;
- taken away: red ghosts where they stood;
- moved or turned: amber, with a faint ghost where they were;
- painted another colour: violet.

Everything else is faded. The panel over the model counts each kind, and **Next** and **Previous** frame the changes one by one. Comparing changes nothing; **Close** or [[Esc]] puts the view back. Inside a sub-assembly, only that sub-assembly is compared.

<!-- covers
ui:compare with a save
lib:model diff
-->

## Keep a copy of everything {#backup}

**File › Export › All my models (.zip)** downloads every model saved here as LDraw files in one .zip: a copy of your own to keep anywhere. Versions and unsaved work are not in it. To bring a model back, unzip it and open its .ldr with **File › Open… › From a file on this computer**.

## The library {#library}

**File › Library…** ([[Ctrl+Shift+O]]) has LDraw's models of real sets and models the community shared. Search as you type, filter, and open one: it opens in a new tab, and the model here stays as it is. See [The LDraw library](/docs/ldraw-library).

<!-- covers
ui:library
-->

## Put one model into another {#into}

**File › Import › Into this model…** lists your saved models and the examples, with **From a file on this computer…** and **From the library…** at the top. Choose one and it comes into your hand whole, as one sub-assembly; click where it goes. In the library, a card's **Put in this model** does the same with a real set or a model someone shared, when its licence lets it be built on.

Everything in it comes with it: its sub-assemblies, its author's build steps, parts Brickworks cannot draw (kept in the file, in their sub-assembly and step), and its maker, written in its sub-assembly's header. A sub-assembly named like one of yours is given a name of its own ("Roof 2"), and the bar says so. One **Undo** takes all of it out. Your model keeps every line of its own file; when it is someone else's file with no build steps, its parts stay in its one step and the model you put in keeps its own steps inside its sub-assembly.

A session does the same with `open_model into=true` (see [MCP tools](/docs/mcp-tools)).

<!-- covers
ui:put a model into this one
-->

## Bring in a file from another program {#formats}

**File › Import** reads these, and **File › Open… › From a file on this computer** reads the first three:

| File | Choose |
|---|---|
| LDraw `.ldr`, `.mpd` | **LDraw model**. Sub-models and steps come in as they are. |
| BrickLink Studio `.io` | **BrickLink Studio model**. Locked files too, with their prints, stickers and steps. |
| LEGO® Digital Designer `.lxf` | **LEGO® Digital Designer model**. |
| 3D models: OBJ, STL, PLY, 3MF, VOX, FBX, glTF, GLB | **3D model to brickify**, which builds it in bricks: see [Brickify](/docs/art-and-brickify#brickify). |

A model from Studio, LDCad or LeoCAD keeps its author's own build steps: see [Instructions](/docs/instructions#authors-steps). What Brickworks writes is in [Exports](/docs/exports).

<!-- covers
lib:ldr read and write
ui:open a studio model
ui:open an ldd model
-->
