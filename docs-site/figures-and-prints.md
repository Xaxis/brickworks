---
tools: add_minifig, print_part, make_part
panels: MinifigDialog#minifig, MouldEditor#mould, MeshPartDialog#own-part, PrintEditor#prints, ElementDialog#make-a-part
ai: Minifigures from real parts, prints and stickers drawn on parts, the printed versions real parts came in, and parts made when no real one will do. An assistant adds a figure with add_minifig, prints or stickers a part with print_part, and makes a part with make_part.
rules:
  - A print or a made part is saved inside the model, so the file opens anywhere.
  - make_part only when nothing in the catalogue fits; search_parts first.
title: Minifigures, prints and made parts
nav: Figures, prints and made parts
description: Build a minifigure from real parts, draw prints and stickers, and make a part the LEGO Group never made.
---

Here you make what the parts catalogue does not have: a minifigure of your own, a print or a sticker on any part, a printed version the LEGO Group made, or a whole new part. All of it is in the **Make** menu, and the parts bin has **Make a part…**, **Print…** and **Stickers…** at its top. What you make goes in the parts bin, under **Custom**, **My prints** or **My stickers**, and inside every model that uses it, so the file opens anywhere.

## The minifigure builder {#minifig}

![The minifigure builder: the figure's slots down the left, the heads that fit the chosen slot in the middle with colours under them, and the figure turning on the right with Keep and Place in model.](/docs/img/figures-minifig.webp "Make › Minifigure builder… (M): a figure from real parts, slot by slot.")

1. **Make › Minifigure builder…** ([[M]]).
2. Click a slot down the left, from headgear to feet and what it holds in each hand.
3. Choose a part from every real one that fits the slot, or search them, and a colour: a dot marks the colours that part is really made in.
4. Name the figure. **Keep** keeps it to use again; **Place in model** puts it in your hand like a part: point at a stud, [[R]] to turn it, click to stand it there.

An assistant can add one too (`add_minifig`).

<!-- covers
ui:minifig builder
lib:minifig assembly
lib:add a minifig
-->

### Make a mould {#mould}

For headgear or something to hold that does not exist, choose its slot and **Make a mould…**. Drag on the part to sculpt it with the brushes down the left (pull, push, inflate, smooth, pinch, flatten, grab), with symmetry on both sides; what joins it to the figure is locked. **Save mould** makes the part and puts it on the figure.

<!-- covers
ui:mould maker
lib:custom moulds
-->

For hair you already have as a 3D file, choose **Headgear** and **Your own…**: see [A part from a 3D file](#own-part). It is seated on the head and worn like any hair.

## Prints {#prints}

![The print designer on a white 2 x 2 tile, started from a control panel: the drawing tools down the left, the canvas in the middle, the tile with the print on it at the top right with Start from, Add a picture… and Layers under it, and the colours along the foot.](/docs/img/figures-print.webp "Print… in the parts bin draws on the part in hand.")

1. Hold a part, or select one in the model, and press **Print…** in the parts bin (or **Make › Print on a part…**). In the minifigure builder, **Draw a print…** does the same for a torso, a face or legs.
2. Draw on its face with the brush, lines, boxes, ovals, a fill, words and an eraser, in LEGO® colours and on layers. Or **Start from** a starter (a dial, a screen, a sign, a number plate, a control panel, a face) or one of the LEGO Group's prints of the same part, or **Add a picture…** (PNG, JPEG, WebP, BMP or SVG): **Fit it** or **Cover**, and **LEGO® inks** keeps it to a few flat colours, as a real print is.
3. **Save print**. The printed part goes under **My prints** and into your hand to place.

<!-- covers
ui:print designer
ui:prints and stickers in the parts bin
lib:custom prints
-->

## Stickers {#stickers}

**Make › Put a sticker on…**, then click a face of the model: the sticker is drawn the same way, sized to that face and the faces level with it ([[Shift]]-click for one face alone), and stuck on. **Stickers…** in the bin opens the model's sticker sheet: **Stick on…**, **Move…** or **Peel off** each sticker, and **Save sheet as PDF** or **PNG (300 dpi)** to print at actual size. Your stickers are kept under **My stickers**.

<!-- covers
lib:stickers
lib:sticker sheet
-->

## Printed versions {#printed-versions}

![Printed versions of a red 2 x 2 tile: a grid of the 433 printed and stickered tiles the LEGO Group made, each with its number and name, to swap the selected tile for.](/docs/img/figures-printed-versions.webp "Make › Printed versions… swaps a part for a print the LEGO Group made.")

Select a part and choose **Make › Printed versions…** (or from its right-click menu, or Properties) to swap it for one of the printed or stickered versions the LEGO Group made. A BrickLink Studio model's own prints and stickers come in with it.

<!-- covers
ui:printed versions
lib:studio decorations
-->

## Make a part {#make-a-part}

![The Make a part dialog with Wedge chosen among its ten families: a red wedge plate in the preview, its width and length, which side is straight, and the words under them saying what it is, its far corner cut flat.](/docs/img/figures-part-maker.webp "Make a part…: a 2 x 4 wedge plate with its far corner cut flat.")

1. Press **Make a part…** in the parts bin (or **Make › Make a part…**, which starts from the part in hand).
2. Choose a family: **Brick**, **Slope**, **Curved**, **Inverted**, **Round**, **Bracket**, **Technic**, **Clip**, **Bar** or **Wedge**. Or type a part number: **Start from it** resizes it, **Change it** changes the part itself (longer, taller, studs off or on, a piece cut out).
3. Set its size in studs and plates, and what its family asks: a slope's angle, which way a bracket or a clip faces, a wedge's straight side and **Far corner cut flat**. The preview is the part itself.
4. Name it and press **Add to parts**. It goes in the bin under **Custom**, with studs and connections that snap like a real part's.

An assistant makes one only when nothing in the catalogue fits (`make_part`).

<!-- covers
ui:make a part
lib:build a part in the app
lib:change a part
lib:element maker
lib:made parts in the library and in files
lib:the assistant makes a part
-->

### A part from a 3D file {#own-part}

![A goblet brought in from an STL file, beside a 1 x 1 brick for its size: its longest side in mm, the turn buttons, This is hair, and one button for each connector to put on it.](/docs/img/figures-own-part.webp "Make a part… › From a 3D file…: a goblet from an STL, beside a 1 x 1 brick.")

1. Press **Make a part…** and then **From a 3D file…**, and choose an **STL** or an **OBJ** file. In a browser your browser's file chooser opens; on the desktop, your system's.
2. It comes in upright, centred and at LDraw's scale, beside a 1 x 1 brick so you can see its size. Change **Size** (its longest side) in **LDU**, **mm** or **studs**. If it came in lying down, **Tip forward** or **Tip sideways**; **Turn** faces it the other way. An STL or OBJ does not say what it is measured in, so it is read as millimetres; if that makes it smaller than 4 mm or longer than 400 mm, you are asked: **Millimetres**, **Centimetres**, **Metres** or **Inches**.
3. Choose a connector, then click on the part where it goes: **Stud**, **Anti-stud**, **Bar**, **Bar hole** or **Pin hole**. A bar on a thin stem runs along the stem. **Take off** removes one.
4. Name it and press **Add to parts**. It goes in the bin under **Custom** and into your hand, and every model that uses it carries it, so the file opens on another computer and in LDCad.

A file that is not a closed shape (it has holes in its surface) is refused, with how to close it in Blender, and so is one whose numbers are damaged. A file with more than 9,000 triangles is simplified if the shape stays within 1% of its size; past 120,000 it is refused, and so is a file over 32 MB, before it is read. A part may be at most 400 mm (50 studs) long, longer than any LEGO® element.

A model that uses a part you made carries it whatever it was opened from: your own model, a set, or someone else's file. Save, Export, a link, a kept sub-assembly and, on the desktop, a copy to the clipboard all take it with them.

Each part you make is named by what it is: its name ends in a tag of its whole file, so the same part made twice is one part, and a part someone else made is never mistaken for yours. A file from an older version of Brickworks may name someone else's part the way it named one of yours; it opens with their part under a name of its own, and both are kept.

![Hair brought in from an STL file, seated on a minifigure's head: Your own hair, Seated on a minifigure's head, and Wear it.](/docs/img/figures-own-hair.webp "Headgear › Your own…: hair from an STL, seated on the head.")

**Hair.** In the minifigure builder choose **Headgear**, then **Your own…**, or press **This is hair** on any part from a file. Brickworks stands the hair up and faces it forward (a ponytail's tail at the back, a wig's open side at the face), sizes it to fit round the head, and seats it: the inside of its crown goes on the head's stud, with a socket like a real hair piece's, so it turns with the head. If it guessed wrong, **Turn** and **Tip** put it right. **Wear it** puts it on the figure.

<!-- covers
ui:own part from a 3D file
lib:parts from 3D files
-->
