---
tools: parts_list, edit_collection, compare_with_set
panels: CollectionDialog#my-collection
ai: The sets and parts a person owns, kept with their account: what a model needs that they lack, and what they can build now. parts_list which=need lists what is missing, which=buildable what the collection can build, which=compare a= b= what two sets or models share and what to buy to build b from a. edit_collection adds the loose parts a person shows in a photo of their pile, in one call, each lot marked as the session's for the person to keep or take back; it never changes their sets or their own lots. edit_collection missing= puts how many of each named part a set they own is missing to a count, all its copies together, and says each change as was N, now M so it can be put back; none=true says a set has nothing missing only while nothing is marked, and is refused otherwise, naming what is: the lots are named to unmark them, or none=true is sent again with marked= the number of lots it named; missing= is sent alone, not with add= or remove=. edit_collection built= marks sets kept built on a shelf (["7140-1"], or {set, copies} for how many copies, 0 to take them apart), each said as was N; a built copy's parts, its spares apart, are left out of what can be built, the bin and mine=true; built= is sent alone.
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
- From your Rebrickable account: your own **Rebrickable API key** and **User token** (or username and password), then **Fetch**. The key goes only to Rebrickable and is not kept. Fetching again replaces what came from Rebrickable before. A set's missing parts stay marked, as far as the copies Rebrickable lists hold them; Brickworks says if any could not be.

**Save sets as CSV** and **Save sets as XML** save your sets as a Rebrickable sets list and a BrickLink XML, each saying which you keep built. The XML does not say which sets' spare parts you kept; the CSV does. Read back into Brickworks, a file adds to what is there, as every file does: to restore your collection from one, read it into an empty collection (**Start over** first).

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

**From a photo, with your AI:** show your AI a photo of your pile and ask it to add what it sees. **Keep them** makes the lots it added yours; **Take back what Claude added** (or whichever AI it was) takes exactly those off. Adding them never changes your sets or your own lots.

<!-- covers
ui:loose parts in my collection
lib:a session's loose parts over mcp
-->

## Mark a set's missing parts {#sets}

Beside a set, choose **Missing parts…** and say how many of each are missing (**All missing** marks every part, to count back in what you find). What do I need? and What can I build? then count only what is there, and **Build from it** leaves them out of the bin.

**Closest to whole** lists your sets with parts missing, nearest to complete first, and **What it needs** says what each is short of, less any loose parts that make it up.

Your AI can mark them too: tell it what a set is missing, or that you found it all, and it says each part it changed, as it was and as it is now, so any change can be put back.

<!-- covers
ui:a set from a photo
ui:a set's missing parts
-->

## Sets you keep built {#built}

A set standing built on your shelf is not loose parts. Press **Built** beside it on *What I own*, and its parts leave What can I build?, Build from my bricks and a design your AI makes from your parts; its spares still count. Press **Built** again when you take it apart, and they come back. With two or more copies, each press marks one more copy built (*Built 1 of 2*), and after the last, none. The summary at the top says how many pieces stand built.

The mark is kept with your account and in the files Save sets as CSV and as XML make. Your AI can mark a set too: tell it which sets you keep built, or took apart, and it says each as it was, so it can be put back. An older Brickworks keeps the set but not the mark, and counts every set.

## Where each part is kept {#places}

A sorted collection lives in drawers, boxes and trays. **Where it's kept…** on *What I own* lists every part and colour you own, your sets' parts with them, each with a place to type: "drawer 3", "B12", "the red tub", up to 40 characters (a longer one is said, never cut short). Press Enter, or move on, and it is kept with your account, on every device you sign in on. To place many at once, find them (a number, a name, a colour, or a place's own words), type the place under the find, and press **Put them there**; it asks first when that would move parts you keep somewhere else already, and can put only those kept nowhere. With nothing typed, the parts shown come off their places, once you say yes, since a place taken off cannot be undone. **By place** lists them in the order of a walk round the drawers: *drawer 2* before *drawer 10*.

The parts list then offers **By where it's kept**, and each row names its place; typing a place in its find shows what is kept there. The booklet's parts box says under each part's count where to take it from, *from drawer 3*. Turn off **Say where each is kept in the booklet** for a booklet you make for someone else.

**Save places as CSV** writes every place as a spreadsheet (part, colour, colour name, place), and **Places CSV…** reads one back, or one of your own with a Part, a Colour and a Place column: each place it names is set, and anything you do not own is said and left out. Start over forgets the places with everything else.

A place stays when the last of its part and colour goes: a lot taken out, a set removed, or an import or a Rebrickable fetch that replaced what came before. When the part comes back it is in its drawer again. Until then *Where it's kept* lists it, faint, as one you own none of now: empty its place and press Enter to take it off, or read a places CSV that leaves its place empty. It takes no new place, and Put them there passes it by.

Your AI can set them too: tell it where you keep your parts, and it places them all in one go, saying where each was, so any can be put back. An older Brickworks shows your collection without its places and leaves them as they are with your account.

<!-- covers
ui:where each part is kept
-->

## What do I need? {#need}

![The car's parts list, 61 pieces in 32 lots: each with how many, its picture, number, name and colour; along the top What do I need?, Save as CSV, and the BrickLink, Rebrickable and LEGO® Pick a Brick lists.](/docs/img/collection-parts-list.webp "Build › Parts list (P).")

**Build › What do I need?…** (or **What do I need?** on the parts list, [[P]]) lists what the model uses that you do not own, and what you own that could stand in. Export what is left as a shopping list: see [Buy the parts](/docs/exports#shop-lists).

## Make a model easier to buy {#rare}

A part in a colour that comes in three sets or fewer is one few sellers have. The parts list ([[P]]) says over its rows how many of the model's lots are like that, by Rebrickable's set inventories, and marks each such row "rare: in 2 sets". Press that line and each rare lot is shown with a swap that comes in 20 sets or more: the same shape in its own colour (another mould of the part that holds every connection the old one did, or a print's own plain part where it is still made), or else the nearest colour of the same finish and see-through-ness that its part comes in, its ΔE said. The lots of one colour go to one colour where their parts allow, so a fox stays one orange. Only a swap that keeps the look starts ticked: the same shape in its colour, or a close colour (ΔE 10 or under) of the same finish. Every other says what it changes ("a different colour", "not see-through", "loses its chrome") and waits for you to tick it; a print keeps its print unless you tick it, and a part no colour of which comes in 20 sets says so and has no box. A touch anywhere on a row ticks it. Then **Swap**: a part in your hand goes back where it was first, as Escape puts it, every copy of a sub-model changes with it, a locked part stays, and the whole swap is one undo step. The line then says what changed and what is still rare. Your Claude does the same with replace_parts rare=true, in one call: it swaps those that keep the look, and the others only where it names them with lots=.

<!-- covers
ui:rare lots swapped for common ones
-->

## What can I build? {#build}

**File › What can I build?…** opens on **Real sets**: every LEGO® set Rebrickable lists, the one you could build most of first. Each says how much of it you have in its colours (*92%*), how many pieces are short, and how much you have in any colour; the sets you own are left out. Your sets' parts and your loose parts all count, and another moulding of a part stands in, as What do I need? counts them.

- **What do I need?** beside a set lists the parts you are short of for it, to find or to [buy](/docs/exports#shop-lists).
- **Open** puts a set's official LDraw model on the baseplate, where one exists (**See it** on the website).
- **Find a set** finds one by its number or a word of its name. The size choice starts at *50 pieces or more*, so minifigures and key chains do not fill the top; **Any size** lists them all.

**Models** ranks the examples, your saved models and LDraw's models of real sets the same way. On the website, [the gallery](/docs/gallery) sorts by **Parts I own**, and its *You can build now* shelf has the models you have every part for. Your AI hears both lists when it asks what you can build.

<!-- covers
lib:every set ranked
-->

## Build from a set's parts {#set-bin}

Build something else from a set you own, as an alternate build:

1. Type the set's number into the parts bin's search (*10497-1*, or *set 10497*) and choose **Build from it** at the top of the bin. Or choose **Build from it** beside a set under *What I own*.
2. The bin becomes that set's parts, a tile for each part in each colour, with how many are left. Each part you put down takes one; undo or a delete gives it back. A part with none left is greyed but still yours to use, and the bin says how far over the set the model is.
3. **All parts** goes back to the whole catalogue.

Where the LDraw community has a model of the set, the bin follows its booklet: the parts of the step you are on come first, and it turns to the next step as they go in (**‹** and **›** turn it by hand). A set with several models, such as *8841-1*, offers them under *Follow a booklet:*. The choice is saved with the model.

## Build from my bricks {#my-bricks}

Build from everything you own, so a model never needs a part you do not have:

1. Choose **Build from my bricks** at the top of *What I own*.
2. The bin becomes your own parts: your sets' parts, less any you marked missing and those of [sets you keep built](#built), and your loose parts, a tile for each part in each colour with how many you have left. Each part you put down takes one; undo or a delete gives it back. The status bar says when you put down the last one you own.
3. A part with none left is greyed but still yours to use. One more than you own is marked over on its tile, on the line at the top of the bin and in the parts list ([[P]]).

A set you marked **Built** is left out: its parts stand on your shelf, and only its spares count. The choice is saved with the model, and follows your collection as it changes. Ask your own Claude for a design "from my collection" and it is held to the same parts: the app tells it each part the design goes over, and by how many.

## Compare two sets or models {#compare-sets}

**File › Compare › Compare two sets or models…** puts any two side by side: a set by its number (*7140*), a saved model or an example, or the model open now.

1. Choose **A**, what you have, and **B**, what you want to build, then **Compare**.
2. The tabs **In both**, **Only in A** and **Only in B** list the parts by part and colour. A piece of B that A has in another moulding of the same part counts as in both; spare parts, stickers and parts you made are not counted.
3. **Only in B** is what to buy: **BrickLink**, **Rebrickable** and **LEGO® Pick a Brick** under it write it for that shop. **Swap** turns it round.

<!-- covers
ui:compare two sets or models
lib:parts compare
-->

## Check a build against its set {#set-check}

**File › Compare › Compare with the set…** checks the model you have open against the real set's own model from the library: the set it was opened from, or one you type by its number (*7140* or *7140-1*). Every difference is a row under the set's own step it is in, as its author stepped it (*step 3 of the Wing, which goes on in step 12*):

- a part **taken away**, **added**, **recoloured**, **moved** (even a stud, or turned), **swapped** for another moulding of it, or put in **another sub-model**;
- where it is in your model: its sub-model and the line of the file (*the Wing (copy 2), line 412*).

Press a row to select that part and frame it; a part taken away shows as a red ghost where the set has it. A model that is the set says it matches. Your Claude asks the same with `compare_with_set`, and is told how to put each change back. The check only reads: your model and its file are left as they were.

<!-- covers
ui:compare with the set
lib:set check
-->
