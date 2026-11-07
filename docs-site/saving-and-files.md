---
tools: save_model, open_model
panels: SavedModelsDialog#open, VersionsDialog#versions, CompareView#compare, LibraryDialog#library
ai: Saving and opening models, their last 20 versions and what changed since each, the library of real sets, and the files Brickworks opens (LDraw, Studio, LDD, 3D models). An assistant saves with save_model and opens a saved model, a version, a gallery model or a library set with open_model; open_model versions=true version=N reads what changed since that save, opening nothing.
rules:
  - Saved names are unique: a save under a name another model has is refused.
  - Opening over unsaved changes asks first; open_model takes discard_changes.
  - Free keeps up to 25 models with the account; Pro keeps any number.
title: Saving, opening and files
nav: Saving and files
description: Where models are kept, versions, the library of real sets, and every file Brickworks opens.
---

## Save {#save}

[[Ctrl+S]] saves the model under its name; the first save asks what to call it, and refuses a name another saved model has. **File › Save as…** ([[Ctrl+Shift+S]]) keeps a copy under another name. Models are kept in your browser (on your computer in the desktop app) and privately with your account, so they open wherever you sign in.

<!-- covers
ui:name asked at the first save
lib:save and reopen
lib:browser keeps the models
lib:models kept with the account
api:/api/models
-->

> [!NOTE]
> A browser can clear what a site keeps when it runs short of space. If yours might, Brickworks says so once, and your account's copy is what keeps your models safe. An account keeps up to 500 models today; once Pro opens, Free keeps 25 and Pro any number ([Plans](/docs/plans)). Near the limit it says so, and **Delete old models…** makes room.

<!-- covers
ui:models may be cleared warning
ui:account full offer
-->

## Open {#open}

**File › Open…** ([[Ctrl+O]]) reopens a saved model, an example, or a file from this computer. Opening over changes you have not saved asks first (*Save*, *Don't save*, *Cancel*), and after *Don't save*, **Edit › Undo** still brings them back. **Rename or delete saved models…** at the foot of Open renames or deletes them; a deleted model's row has **Undo**.

<!-- covers
ui:open over unsaved work
ui:rename or delete saved models
-->

If the model you were working on cannot be opened at start-up (none of its parts are in the catalogue), it is kept in **File › Open** and said above the model, never lost.

<!-- covers
ui:working model that could not open
-->

## Versions {#versions}

**File › Versions…** keeps the last 20 saves of the model on the baseplate. **Open** on any one of them to go back to it.

<!-- covers
ui:versions of a model
lib:model versions
-->

## Compare with a save {#compare}

**File › Compare with…**, or **Compare** on a row of **File › Versions…**, shows what changed since that save, on the model itself. Parts added since are green, parts taken away are red ghosts where they stood, parts moved or turned are amber with a faint ghost where they were, and parts painted another colour are violet. Everything that did not change is faded. A part moved by less than half an LDU has not moved, and of several identical parts the fewest changes are shown: one brick moved to the end of a row is one moved part, not one taken away and one added.

The panel over the model counts each kind. **Next** and **Previous** step through the changes one by one, and the view frames each. Comparing changes nothing: the model, its undo history and whether it is saved stay as they were. **Close** or [[Esc]] puts the view back. While you are editing inside a sub-assembly, only that sub-assembly is compared, and the panel says so.

<!-- covers
ui:compare with a save
lib:model diff
-->

## The library {#library}

**File › Library…** (or **Open › From the library…**) opens any of LDraw's models of real sets, or a model the community shared. Search it as you type, filter it, and open one in a new tab or window. See [The LDraw library](/docs/ldraw-library).

<!-- covers
ui:library
-->

## Files it opens {#formats}

| File | How |
|---|---|
| LDraw `.ldr`, `.mpd` | **File › Import › LDraw model**, or **Open › From a file**. Sub-models and steps come in as they are. |
| BrickLink Studio `.io` | **File › Import › BrickLink Studio model**. Locked files too, with their prints, stickers and steps. |
| LEGO® Digital Designer `.lxf` | **File › Import › LEGO® Digital Designer model**. |
| 3D models | **File › Import › 3D model to brickify**: OBJ, STL, PLY, 3MF, VOX, FBX, glTF, GLB. See [Brickify](/docs/art-and-brickify#brickify). |

A model from Studio, LDCad or LeoCAD keeps its author's own build steps: see [Instructions](/docs/instructions#authors-steps).

<!-- covers
lib:ldr read and write
ui:open a studio model
ui:open an ldd model
-->

What Brickworks saves and exports is in [Exports and renders](/docs/exports).
