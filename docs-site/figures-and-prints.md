---
tools: add_minifig, print_part, make_part
panels: MinifigDialog#minifig, MouldEditor#mould, PrintEditor#prints, ElementDialog#make-a-part
ai: Minifigures from real parts, prints and stickers drawn on parts, the printed versions real parts came in, and parts made when no real one will do. An assistant adds a figure with add_minifig, prints or stickers a part with print_part, and makes a part with make_part.
rules:
  - A print or a made part is saved inside the model, so the file opens anywhere.
  - make_part only when nothing in the catalogue fits; search_parts first.
title: Minifigures, prints and made parts
nav: Figures, prints and made parts
description: Build a minifigure from real parts, draw prints and stickers, and make a part the LEGO Group never made.
---

## The minifigure builder {#minifig}

**Build › Minifigure builder…** ([[M]]) makes a figure from real parts: headgear, head, torso, arms, hands, legs and accessories, each chosen in its slot, in any colour it was made in. Stand it in the model when it is done. Claude can add one too (`add_minifig`).

<!-- covers
ui:minifig builder
lib:minifig assembly
lib:add a minifig
-->

### Make a mould {#mould}

For headgear or a hand-held piece that does not exist, choose its slot and **Make a mould…**: shape it, and it is used like any other part in the figure.

<!-- covers
ui:mould maker
lib:custom moulds
-->

## Prints {#prints}

Hold a part and choose **Print…** in the parts bin, or **Build › Print on a part…** for the part selected: draw the print and it is printed on the face where it stands. In the minifigure builder, **Draw a print…** does the same for a torso or a face. The print is saved with the model.

<!-- covers
ui:print designer
ui:prints and stickers in the parts bin
lib:custom prints
-->

## Stickers {#stickers}

**Build › Put a sticker on…**, click a face of the model, then draw the sticker that goes there. The model's stickers are laid out on a sticker sheet you can print, as a set's sheet is.

<!-- covers
lib:stickers
lib:sticker sheet
-->

## Printed versions {#printed-versions}

Select a part and choose **Build › Printed versions…** (or from its right-click menu, or in Properties) to swap it for one of the printed or stickered versions the LEGO Group made of it. A BrickLink Studio model's own prints and stickers come in with it.

<!-- covers
ui:printed versions
lib:studio decorations
-->

## Make a part {#make-a-part}

When no real part will do, **Make a part…** in the parts bin (or **Build › Part maker…**, starting from the part in hand) makes one of your own: change its size, its studs, its holes and its shape, and it is built as a real part would be, with studs and connections that snap. Made parts are kept in your parts library and saved inside each model that uses them, so the file opens anywhere. Claude can make one too, when nothing in the catalogue fits (`make_part`).

<!-- covers
ui:make a part
lib:build a part in the app
lib:change a part
lib:element maker
lib:made parts in the library and in files
lib:the assistant makes a part
-->
