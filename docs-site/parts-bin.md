---
tools: search_parts, find_parts_like, palettes, edit_palette
ai: Finding parts by words, number, shape or a photo, and the colours they come in. An assistant finds real parts with search_parts, the parts like one (to swap it for) with search_parts like=, or by their look with find_parts_like, never by guessing a part number.
rules:
  - Every part is from the LDraw library; printed parts are found with the word print, stickered ones with sticker.
  - Colours are LDraw colour codes, and a part comes only in colours it was really made in.
  - The person's palettes are theirs, kept for every model: palettes reads them; edit_palette makes one of the open model's parts (bricks=, each in its colour) and sub-assemblies (assembly=, assembly_bricks=) in one call, and place puts a sub-assembly down whole. Ask the person before deleting a palette or taking a sub-assembly out (agreed=true).
title: The parts bin
nav: The parts bin
description: Find any part by name, number, shape or a photo, keep the ones you use, and choose its colour.
---

The parts bin is where every part comes from. It is the top of the left-hand column; [[/]] goes straight to its search, opening the bin if it was put away (**View › Panels › Parts bin** shows or hides it).

<!-- covers
ui:parts bin
-->

## Search for a part {#search}

![The parts bin with slope 2 x 2 typed in its search, the slopes it found shown as pictures with their names, and how many it found at the foot.](/docs/img/parts-bin-search.webp "Type what you want: the bin finds it by name, number or the words builders use.")

Press [[/]] and type what you want: *2x4 brick*, *slope 45*, *wheel*, *window*, a part number like *3001*, or what is printed on it, with *print*: *control panel print*. Click a part to take it in hand.

- A size alone is a brick: *2x4* lists Brick 2 × 4 first. A size with a kind lists that kind first: *2x2 tile* is tiles.
- Builders' words work: *SNOT* finds bricks with side studs and brackets, *cheese* the small slopes, *Erling* the headlight brick, *Travis* the brick with studs on four sides, *macaroni* the curved corners.
- A part's name is under its picture and its number on its tooltip. A count like **+82** on a tile is its prints and other versions, folded under it: [[+]] shows them.

Every part is from the LDraw library, fetched once and kept.

<!-- covers
lib:part search
lib:mesh fetch
-->

### Find a part from a photo {#photo}

The camera in the search field finds a real part from a photo of it. The photo goes to Brickognize, a service that recognises parts, and the bin says so before the first is sent. Its terms allow personal use only, so photo search is not in Pro's commercial licence.

<!-- covers
ui:find a part from a photo
-->

## Use the shelves {#shelves}

![The parts bin as it opens: its shelves along the top, a grid of part pictures with their names, and how many it shows at the foot.](/docs/img/parts-bin-shelves.webp "The bin's shelves and its parts.")

The chips along the top of the bin are its shelves, and stay in sight however narrow the column; the kinds of part after them, *Brick*, *Plate* and the rest, scroll.

- **Recent**: the parts you used last.
- **Favourites**: right-click a part to keep it here.
- **Palettes**: your own (below). Recent, Favourites, Palettes and Techniques count what they hold.
- **New**: parts first made in the two latest years the catalogue knows, now 2025 and 2026.
- **Techniques**: worked constructions from real sets, a row of hinged plates, a SNOT wall; a click takes one whole into hand.
- **Fits** and **Like this**: what fits the part selected or in hand, and parts like it (below).

Typing narrows any shelf.

<!-- covers
ui:recent and favourite parts
ui:techniques in the bin
lib:worked constructions
ui:new parts in the bin
-->

### Keep palettes of your own {#palettes}

A palette is a named set of parts in their colours and whole sub-assemblies, there in every model. **New palette** makes one. In an open palette, **Add** keeps the part in hand, the selected parts, or the selection as one sub-assembly; a click takes one back into hand. **More** takes one out, renames it or deletes the palette.

Your Claude can make one too: ask it to keep the parts of what you built as a palette, and the **Palettes** chip counts it with yours. It asks before it deletes anything.

<!-- covers
lib:a session keeps and uses palettes over mcp
-->

## Find what fits, or a part like it {#fits}

Select a part, or take one in hand, and choose **Fits**: the bin lists what fits it, the best first: a beam's pins, a clip's bars, a hinge's other half, then the parts that sit on its studs. Double-click one to put it on the selected part: a pin goes into a beam's hole.

## Like this {#like-this}

**Like this** lists parts of its size and kind first, those real sets use most, then the rest of its size (a 2 × 4 brick's Plate 2 × 4 and Tile 2 × 4), then its kind in other sizes. Double-click one, or tap it on a phone, and every selected part is swapped for it, keeping its place, turn, colour and step.

## Choose a colour {#colours}

The palette under the bin holds every colour parts are made in, the part's own colours first. Click one, or press [[[]] and [[]]] to step through them, or [[Shift+C]] to find one by name or LDraw number. A part is drawn in its true colour, transparent and metallic finishes included.

- Tick **Only parts made in it** and the bin lists only the parts real sets have in that colour.
- With a part in hand, rest the pointer on a colour: its tooltip says in how many sets the part comes in it, *3001 comes in it, in 1,011 sets*, or *rare in this colour* in three or fewer, so a piece lost in it is hard to replace. The counts are Rebrickable's set inventories.

<!-- covers
ui:rare colours in the bin
ui:palette
lib:true colour
lib:finishes
-->

## Swap, list and plain parts {#swap}

Double-click any part in the bin to swap what is selected for it, in one undo step. **List**, under the bin, shows a row per part with its number, size and how many colours it was made in. Clear **Prints** and printed and stickered parts leave the bin. Both stay as you left them.

## Prints, stickers and made parts {#prints}

**Print…** and **Stickers…** in the bin decorate parts, and **Make a part…** makes one the LEGO Group never made. See [Minifigures, prints and made parts](/docs/figures-and-prints).
