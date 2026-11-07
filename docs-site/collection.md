---
tools: parts_list, edit_collection
panels: CollectionDialog#my-collection
ai: The sets and parts a person owns, kept with their account: what a model needs that they lack, and what they can build now. parts_list which=need lists what is missing, which=buildable what the collection can build. edit_collection adds the loose parts a person shows in a photo of their pile, in one call, each lot marked as the session's for the person to keep or take back; it never changes their sets or their own lots.
rules:
  - The collection comes from Rebrickable (with the person's own key), a BrickLink or Rebrickable list, or typed in.
title: My collection
nav: My collection
description: Tell Brickworks the sets and parts you own, then see what a model needs that you do not have, and what you can build now.
---

## Your sets and parts {#my-collection}

**File › My collection…** keeps the sets and loose parts you own. Bring them in from your Rebrickable account (with your own Rebrickable key), from a BrickLink or Rebrickable list, or type them in. Each set is counted out into its parts. Your collection is kept with your account, so it is there on every device you sign in on.

Each change you make is made on your collection as your account keeps it, so a change made at the same moment on another device, or by Claude, is kept as well as yours. If a count you change was changed somewhere else since you looked, nothing is changed: My collection says so and shows the collection as it is now, for you to change it again. Fetching from your Rebrickable account replaces what came from Rebrickable before, by a fetch or an export, and the loose parts brought in before (listed as such); the parts you count by hand, a BrickLink list and what Claude added stay, and a set you typed that Rebrickable lists is kept once. If the connection drops while a change is being sent, My collection says it may have been made: open it again to see. A copy of Brickworks from before this still takes a set out; if it read your collection before a change made elsewhere, it asks you to update it (on the web, reload the page) first.

<!-- covers
ui:my collection
lib:a rebrickable account
lib:collection kept with the account
lib:collection sums
api:/api/collection
-->

## Loose parts {#loose}

<!-- covers
ui:loose parts in my collection
lib:a session's loose parts over mcp
-->

Most people own a tub of loose bricks as well as their sets. Under *What I own*, the **Loose parts** row adds them a lot at a time: type the part's number or a few words (*red 2x4 brick*, *3001*, or a BrickLink number), or choose **Photo…** to find it from a picture, or take a part in the parts bin; then pick its colour, say how many, and choose **Add**. **Like this** offers the parts that look like the one chosen. Each lot is listed under *Loose parts* (lots brought in from a list are listed under where they came from), where you can change its count or remove it. Adding more of a part and colour you already have adds to that lot.

What do I need? and What can I build? count your loose parts with your sets', and they are kept with your account like the rest.

**From a photo, with Claude.** Show your own Claude a photo of your pile and ask it to add what it sees: it adds every lot in one go, each marked as that chat's. *What I own* then says what it added, so you can look the lots over: **Keep them** makes them your own, and **Take back what Claude added** takes exactly those lots off again. Claude never changes your sets or the lots you added yourself.

## Sets as they really are {#sets}

<!-- covers
ui:a set from a photo
ui:a set's missing parts
-->

**A set from a photo.** Beside **Add sets**, choose **Photo…** and pick a photo of the set's box, the cover of its building instructions, or a minifigure. Brickworks asks Brickognize what it shows and offers the three it thinks most likely; choose the right one to add it. A photo of the box's front, on its own, works best. The photo goes to Brickognize, a third party, and Brickworks says so the first time. A minifigure is kept among your sets by its BrickLink number; its parts are not counted, as Brickworks has no list of what is in each.

**Parts missing from a set.** Most sets that have been played with are short of a few pieces. Beside a set under *What I own*, choose **Missing parts…** and say how many of each part are missing; **All missing** marks every part, for counting back in what you find. What do I need? and What can I build? then count only what is there. **Closest to whole** lists your sets with parts missing, those nearest to complete first, and **What it needs** shows what do I need? for that set: its missing parts, less any loose parts you have added that make them up. Loose parts count towards any set; parts of your other sets do not, since taking them would break those sets.

## What do I need? {#need}

**Build › What do I need?…** (or [[P]], then *What do I need?*) lists what this model uses that you do not own, and what you own that could stand in for it. Export what is left as a shopping list: see [Parts lists for shops](/docs/exports#shop-lists).

## Build from a set's parts {#set-bin}

Build something else from a set you own, as an alternate build. Type the set's number into the parts bin's search (*10497-1*, or *set 10497*) and choose **Build from it** on the line that comes up at the top of the bin; or choose **Build from it** beside a set under *What I own*, or **Build from them all** for every set there, counted together.

The parts bin becomes that set's parts, a tile for each part in each colour, with how many are left. Taking a tile takes its colour too. Each part you put down takes one from its count, and undo or a delete gives it back. A part with none left is greyed and can still be used: the bin then says how many over the set the model is. The line at the top of the bin names the set and how many of its parts are left; **All parts** goes back to every part. A search or a category picks among the set's parts, and typing another set's number offers to add its parts.

Where the LDraw community has made a model of the set, the bin follows its booklet: the parts of the step you are on come first, each marked with a line along its top, and the line under the set's says which step it is and how many parts it still wants. As those parts go in, the bin turns to the next step by itself; **‹** and **›** turn it by hand, and **Stop** lists the set's parts most held first again. A set with several models, such as *8841-1*'s Desert Racer and its five alternates, offers them by name under *Follow a booklet:* when you type its number: choose the one you are building.

The choice is saved with the model, so opening it brings the set's parts back to the bin.

## What can I build? {#build}

**File › What can I build?…** ranks models by how much of each you already own. On the website, [the gallery](/docs/gallery) can sort by **Parts I own**, and its *You can build now* shelf shows models you have every part for.
