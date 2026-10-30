---
tools: search_parts, find_parts_like
ai: Finding parts by words, number, shape or a photo, and the colours they come in. An assistant finds real parts with search_parts or by their look with find_parts_like, never by guessing a part number.
rules:
  - Every part is from the LDraw library; printed parts are found with the word print, stickered ones with sticker.
  - Colours are LDraw colour codes, and a part comes only in colours it was really made in.
title: The parts bin
nav: The parts bin
description: Find any part by name, number, shape or a photo, keep the ones you use, and choose its colour.
---

The parts bin is the top of the left-hand column. [[P]] opens it, and [[/]] goes straight to its search. Each part's name is under its picture, *Plate 1×2*, *Brick 1×1 with Stud on 1 Side*; its number is on its tooltip. Where names begin alike and run long, each goes on from the words that set it apart. While a picture is still coming, the part is drawn in its place from its size and studs, so no tile is ever a blank square.

<!-- covers
ui:parts bin
-->

## Search {#search}

Type what you want in words: *2x4 brick*, *slope 45*, *wheel*, *window*, a part number like *3001*, or what is printed on it, with *print*: *control panel print*. The bin understands builders' words: *SNOT* finds bricks with side studs and brackets, *cheese* the small slopes, *Erling* the headlight brick, *Travis* the brick with studs on four sides, *macaroni* the curved corners, *jumper*, *click hinge* and *cheese grater* what builders mean by them. A size alone is a brick: *2x4* lists Brick 2 × 4 first. A size with a kind of part lists that kind first: *1x4 brick* is bricks, *2x2 tile* tiles. Every part comes from the LDraw library, and its geometry is fetched the first time it is used and kept.

<!-- covers
lib:part search
lib:mesh fetch
-->

### Find a part from a photo {#photo}

The camera in the search field takes a photo of a real part and finds it. The photo goes to Brickognize, a service that recognises parts, and the bin says so before the first one is sent.

<!-- covers
ui:find a part from a photo
-->

## Recent, Favourites and Techniques {#shelves}

**Recent** keeps the parts you used last. Right-click a part to keep it in **Favourites**. **Techniques** holds worked constructions from real sets, such as a row of hinged plates or a SNOT wall: a click takes one whole into hand, [[R]] turns it, and a click puts it down.

<!-- covers
ui:recent and favourite parts
ui:techniques in the bin
lib:worked constructions
-->

## What fits {#fits}

Select a part in the model, or take one in hand, and choose **Fits** beside Techniques: the bin lists the parts that fit it, the best fits first. A beam lists its pins, a clip its bars, a bar its clips, a hinge's base its top, a click hinge its other half, a ball its socket, and a jumper the 1 × 1 parts that sit on its stud; then the parts that sit on its studs, the ones real sets use most first. Type to narrow it: *axle* among a beam's fits lists the axles that go through it. Picking a part from the list keeps it on the part you asked about. Double-click a part in the list to put it on the selected part, where it fits and there is room: a pin goes into a beam's hole. [[Ctrl+Z]] takes it off.

## Colours {#colours}

The palette under the bin holds every colour parts are made in, and a part's own colours come first. [[[]] and [[]]] step through them, and [[Shift+C]] finds one by name or LDraw number. A part is drawn in its true colour, transparent and metallic finishes included.

Tick **Only parts made in it** beside the colour's name and the bin lists only the parts real sets have in that colour, *Sand Green* or any other; choose another colour and the list follows it.

## Swap, list and plain parts {#swap}

Double-click a part in the bin to swap what is selected for it: three red bricks become three red masonry bricks in one step, in their places and colour, and [[Ctrl+Z]] swaps them back. **List**, under the bin, shows a row per part with its number, its size in studs and how many colours it was made in. Clear **Prints** beside it and printed and stickered parts leave the bin. **Only parts made in it**, **Prints** and **List** stay as you left them the next time you open Brickworks.

<!-- covers
ui:palette
lib:true colour
lib:finishes
-->

## Prints, stickers and made parts {#prints}

**Print…** and **Stickers…** in the bin decorate parts, and **Make a part…** makes one the LEGO Group never made. See [Minifigures, prints and made parts](/docs/figures-and-prints).

## How the app's dialogs look {#dialogs}

Every dialog, chooser and menu in the app has the panels' dark face, on the desktop and on the web, and every button is edged so it can be seen on its face; a question's default button is the strong blue one.

<!-- covers
ui:the app's dialogs and menus
ui:buttons seen and read
-->
