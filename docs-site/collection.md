---
tools: parts_list, edit_collection
panels: CollectionDialog#my-collection
ai: The sets and parts a person owns, kept with their account: what a model needs that they lack, and what they can build now. parts_list which=need lists what is missing, which=buildable what the collection can build, which=compare a= b= what two sets or models share and what to buy to build b from a. edit_collection adds the loose parts a person shows in a photo of their pile, in one call, each lot marked as the session's for the person to keep or take back; it never changes their sets or their own lots. edit_collection missing= puts how many of each named part a set they own is missing to a count, all its copies together, and says each change as was N, now M so it can be put back; none=true says a set has nothing missing only while nothing is marked, and is refused otherwise: the lots are named to unmark them; missing= is sent alone, not with add= or remove=.
rules:
  - The collection comes from Rebrickable (with the person's own key), a BrickLink or Rebrickable list, or typed in.
title: My collection
nav: My collection
description: Tell Brickworks the sets and parts you own, then see what a model needs that you do not have, what you can build now, and build from a set's parts.
---

My collection is the sets and loose parts you own. With it, Brickworks says what a model needs that you do not have, what you can build now, and lets you build from one set's parts. It is **File › My collection…**, kept with your account on every device you sign in on.

## Add your sets {#my-collection}

![My collection, empty, on What I own: a box for set numbers with Add sets and Photo…, Rebrickable CSV… and BrickLink XML…, your Rebrickable key or username with Fetch, and the Loose parts row; What do I need? and What can I build? along the top.](/docs/img/collection-dialog.webp "File › My collection…")

On the **What I own** page, any of these:

- Type set numbers (*10237-1, 6020*) and press **Add sets**.
- **Photo…** finds a set from a photo of its box, its booklet's cover or a minifigure, and offers the three it thinks most likely. The photo goes to Brickognize, a third party, and Brickworks says so the first time. A minifigure is kept by its BrickLink number, its parts not counted.
- **Rebrickable CSV…** or **BrickLink XML…** reads a list you exported there.
- From your Rebrickable account: your own **Rebrickable API key** and **User token** (or username and password), then **Fetch**. The key goes only to Rebrickable and is not kept. Fetching again replaces what came from Rebrickable before.

Each set is counted out into its parts.

> [!NOTE]
> A change made at the same moment on another device, or by your AI, is kept as well as yours. If a count you change was changed somewhere else since you looked, nothing is changed, and My collection shows it as it is now for you to change again.

<!-- covers
ui:my collection
lib:a rebrickable account
lib:collection kept with the account
lib:collection sums
api:/api/collection
-->

## Add loose parts {#loose}

Under *What I own*, the **Loose parts** row adds a tub of bricks a lot at a time:

1. Type the part's number or a few words (*red 2x4 brick*, *3001*, or a BrickLink number), choose **Photo…** to find it from a picture, or take it in the parts bin. **Like this** offers parts that look like the one chosen.
2. Pick its colour, say how many, and choose **Add**.

Each lot is listed under *Loose parts*, to change its count or remove it.

**From a photo, with your AI:** show your AI a photo of your pile and ask it to add what it sees. **Keep them** makes the lots it added yours; **Take back what Claude added** (or whichever AI it was) takes exactly those off. It never changes your sets or your own lots.

<!-- covers
ui:loose parts in my collection
lib:a session's loose parts over mcp
-->

## Mark a set's missing parts {#sets}

Beside a set, choose **Missing parts…** and say how many of each are missing (**All missing** marks every part, to count back in what you find). What do I need? and What can I build? then count only what is there, and **Build from it** leaves them out of the bin.

**Closest to whole** lists your sets with parts missing, nearest to complete first, and **What it needs** says what each is short of, less any loose parts that make it up.

<!-- covers
ui:a set from a photo
ui:a set's missing parts
-->

## What do I need? {#need}

![The car's parts list, 61 pieces in 32 lots: each with how many, its picture, number, name and colour; along the top What do I need?, Save as CSV, and the BrickLink, Rebrickable and LEGO® Pick a Brick lists.](/docs/img/collection-parts-list.webp "Build › Parts list (P).")

**Build › What do I need?…** (or **What do I need?** on the parts list, [[P]]) lists what the model uses that you do not own, and what you own that could stand in. Export what is left as a shopping list: see [Buy the parts](/docs/exports#shop-lists).

## What can I build? {#build}

**File › What can I build?…** ranks the examples, your saved models and LDraw's models of real sets by how much of each you own. On the website, [the gallery](/docs/gallery) sorts by **Parts I own**, and its *You can build now* shelf has the models you have every part for.

## Build from a set's parts {#set-bin}

Build something else from a set you own, as an alternate build:

1. Type the set's number into the parts bin's search (*10497-1*, or *set 10497*) and choose **Build from it** at the top of the bin. Or choose **Build from it** beside a set under *What I own*, or **Build from them all**.
2. The bin becomes that set's parts, a tile for each part in each colour, with how many are left. Each part you put down takes one; undo or a delete gives it back. A part with none left is greyed but still yours to use, and the bin says how far over the set the model is.
3. **All parts** goes back to the whole catalogue.

Where the LDraw community has a model of the set, the bin follows its booklet: the parts of the step you are on come first, and it turns to the next step as they go in (**‹** and **›** turn it by hand). A set with several models, such as *8841-1*, offers them under *Follow a booklet:*. The choice is saved with the model.

## Compare two sets or models {#compare-sets}

**File › Compare two sets or models…** puts any two side by side: a set by its number (*7140*), a saved model or an example, or the model open now.

1. Choose **A**, what you have, and **B**, what you want to build, then **Compare**.
2. The tabs **In both**, **Only in A** and **Only in B** list the parts by part and colour. A piece of B that A has in another moulding of the same part counts as in both; spare parts, stickers and parts you made are not counted.
3. **Only in B** is what to buy: **BrickLink**, **Rebrickable** and **LEGO® Pick a Brick** under it write it for that shop. **Swap** turns it round.

<!-- covers
ui:compare two sets or models
lib:parts compare
-->
