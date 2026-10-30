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

The parts bin is the top of the left-hand column. [[P]] opens it, and [[/]] goes straight to its search.

<!-- covers
ui:parts bin
-->

## Search {#search}

Type what you want in words: *2x4 brick*, *slope 45*, *wheel*, *window*, a part number like *3001*, or what is printed on it, with *print*: *control panel print*. The bin understands builders' words, so *SNOT* finds bricks with side studs and *cheese* finds the small slopes. Every part comes from the LDraw library, and its geometry is fetched the first time it is used and kept.

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

## Colours {#colours}

The palette under the bin holds every colour parts are made in, and a part's own colours come first. [[[]] and [[]]] step through them, and [[Shift+C]] finds one by name or LDraw number. A part is drawn in its true colour, transparent and metallic finishes included.

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
