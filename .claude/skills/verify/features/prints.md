# Prints and stickers

Printed parts and stickers of one's own, on any face of any part: drawn in the
app or brought in from a picture file, saved as real LDraw parts with !TEXMAP
and their pictures carried in the model file, and a model's sticker sheet
printed at true size.

<!-- covers: lib:custom prints, ui:print designer, lib:stickers, lib:sticker sheet, ui:prints and stickers in the parts bin, cli:prints and stickers in a browser -->

## Sub-features

- `custom prints` (`src/prints/part_prints.gd`, `PartPrints`; the pixels in
  `print_paint.gd`, `PrintPaint`): a print drawn here is an `Area` of a part and a
  picture for it. `areas_for` finds them from the part's own mesh: a round head's
  face and the back of it, each half way round its cylinder (CYLINDRICAL, 180
  degrees, from 3 LDU above where the cylinder starts to 3 below where it ends:
  3626c's canvas is 408 x 190); a torso's front and back (PLANAR, the largest face
  turned that way and any as large as a third of it further out, its canvas the
  face's extent plus half an LDU: 973's front is a trapezoid on a 390 x 330
  canvas); a right leg with its hips and left leg as one front over all three, the
  legs 12 under the hips (`LEGS_UNDER_HIPS`, as `Minifig.LEGS` has them); any
  other part's largest outward faces, named by how they face (a tile's top, a
  slope's slope, a brick's sides), and a curved top — a dish's, no one way up
  having 45% of its upward faces and six or more ways up — printed from above
  over all of it (`any_depth`: 3960's 4 x 4 dish). Ten pixels to the LDU, no side
  over 512. A canvas pixel's place on the part is LDraw's !TEXMAP projection
  worked out as LDView works it out (`Area.uv`, after TREModel.cpp): PLANAR's
  first point the picture's top left, second top right, third bottom left;
  CYLINDRICAL's U `0.5 + angle/a` round from the third point's side, growing to
  the right seen from outside, V down from the top point. The part file
  (`part_text`) is the plain part's triangles from its mesh, each area's faces
  inside its own `0 !TEXMAP START ... <png>` / `0 !TEXMAP END`, its connectors as
  `0 !BRICKWORKS CONNECTOR` lines, its creases, and `0 // Printed by Brickworks:
  from=<part> areas=<keys>`; named `bw-<part>-p<tag>`, the tag six hex digits of
  MD5 over the part, the title and every picture, so the same print twice is the
  same part. A pair of legs is three files sharing one picture and one tag.
  `build` is `PartForge.build` with each block's faces handed over in colour
  `UNDER_PICTURE + n`, so they come out as surfaces of their own, then given
  texture coordinates by the block's own projection, colour 16 back, and the
  picture (`Lbm.PartMesh.prints`, by surface; `print_files`, the PNG bytes by
  name). `BrickWorld` and `PartThumbnails` draw a printed surface with
  `plastic_print.gdshader` (`#define PLASTIC_PRINT` in `plastic_body`: the
  picture mixed over the plastic by its alpha, linearised as the plastic's colour
  is, clear off the picture as LDView's clamp-to-border is). `finished` keeps a
  picture to the area's mask, grown a pixel, and clears its outermost pixels.
  `picture_of` reads one of LEGO's prints off its part (every face not in colour
  16, on the area) onto a canvas: 3626cp01's grin on 3626c's face; `prints_of`
  lists a mould's real prints, the most used first. Kept like any made part
  (`CustomParts.add`: a file with a TEXMAP is built by `PartPrints.build`, its
  pictures kept beside it in `user://custom_parts/` and found there again at
  start-up), filed under **My prints** (`PartPrints.bin_for`; the bin's
  `LEADING` puts My prints and My stickers first); a model carries each picture
  as an MPD `0 !DATA <name>.png` section, base64 in `0 !:` lines of 76
  characters after the FILE sections (`LdrModel.write_ldr`, `embedded_data` when
  read), so it opens in a library that never saw it and in LDView. On a figure
  see [minifig](minifig.md).
- `print designer` (`src/prints/print_editor.gd`, `PrintEditor`; the canvas
  `print_canvas.gd`, `PrintCanvas`; pictures `print_picture.gd`, `PrintPicture`;
  files `picture_file.gd`, `PictureFile`; starters `starters.gd`, `Starters`):
  opened from the parts bin's **Print…** (the part in hand, a 2 x 2 tile when
  none), from the figure builder's "Draw a print…" ([minifig](minifig.md)), or by
  typing a part into "or print on". A tab per area. Tools: brush and eraser
  (round, hard-edged), line, box and oval (filled or outlined), fill (a run of one
  colour on the active layer, on the raw pixels as one int each), text (the font's
  own glyphs from the text server, so headless too), pick a colour, **Move
  picture**; a size; Mirror, which draws every mark again reflected about the
  canvas's middle; layers (add, delete, up, down, show; a picture layer says so);
  undo and redo (Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y; a stroke or a drag is one step, 40
  kept). **Add a picture…** reads PNG, JPEG, WebP, BMP or SVG (`PictureFile`: the
  first bytes say which, then the name; an SVG drawn 1024 pixels on its longer
  side; a file dialog on the desktop, the page's own file picker in a browser)
  onto a layer of its own, kept as itself (`PrintPicture`: the source, its
  middle, scale, turn, crop, opacity) and fitted to the face (the mask's extent).
  Move drags it, its edges and middle snapping to the face's edges and middle
  within 8 screen pixels (`PrintCanvas._snap`); Ctrl+wheel sizes it. The picture
  panel: Fit it, Cover, Middle; Size (per cent of fitted), Turn (degrees), Crop
  left/right/top/bottom, Opacity; **LEGO inks** (each colour the palette's
  nearest in Oklab, worked out once per 12-bit colour) and "at most N inks" (the
  most used kept, the rest to the nearest of those) or full colour; Clear its
  background (the corners' colour, within 0.09 in Oklab, made clear); Mirror it;
  Make it ink (pixels, to draw on — any mark on a picture layer does that too).
  What a layer shows is made from the source in kept steps — the crop resized
  by the engine, cleared, mapped, see-through — so a drag only re-places it.
  Colours: LEGO's solid, metallic and pearl colours in sets today, with black and
  white. Start from: a clean sheet, a starter (dial, screen, sign, number plate,
  control panel, face — drawn for the canvas they go on), prints made here of the
  mould, LEGO's prints of it. Beside the canvas the part turns wearing the picture
  as it is drawn (`preview_meshes`). Save print makes the part, files it under My
  prints and puts it in hand; Escape closes it.
- `stickers` (`src/prints/stickers.gd`, `Stickers`): a sticker is an element of
  its own laid over a face, not a change to the part. `face_at` finds the face a
  ray meets — the first brick it strikes (its triangles in its own axes, the
  nearest by `Rays.nearest`), the flat face struck, and, unless Shift is held,
  every brick beside it whose faces lie in the same plane and touch, square to
  the struck brick's edges (two 1 x 4 tiles side by side are
  one 80 x 40 LDU face). The picture's down is the world's on a face that stands
  and the screen's on one that lies. A sticker is that rectangle less LEGO's 0.1 mm
  a side (`SHY`, a real brick is that much shy of its pitch) and a 0.2 mm margin
  (`MARGIN`): 78.5 x 38.5 LDU, 31.4 x 15.4 mm for the two tiles. Its file
  (`text_for`) is a film `THICK` (0.25 LDU, 0.1 mm, as LDraw's official stickers
  are drawn) with its top in a PLANAR TEXMAP block, `!CATEGORY Sticker`,
  `0 // Sticker by Brickworks: w= h=`, no connectors and so no collision cover;
  named `bw-st-<tag>`, filed under **My stickers**. `stick` puts it on the face
  through `Builder.put_part` (one undo takes it off), in white film (`FILM`);
  `Builder.take_off` peels one off as one step. `stuck_to` is the bricks under a
  placed sticker (points across it, half an LDU behind it, inside their bounds):
  what the booklet needs.
- `sticker sheet` (`src/prints/sticker_sheet.gd`, `StickerSheet`): every
  sticker a model uses, one per placed copy, laid out on A4 from its top left
  (12 mm margin, 6 mm gaps, a label under each), with a 50 mm scale bar. `pdf`
  writes one A4 page (595.276 x 841.89 pt) by hand: each sticker its own
  FlateDecode RGB image on white (zlib's format, which Godot's deflate is), drawn
  into exactly its size in points (mm x 72/25.4) by a `cm` matrix, a 0.3 pt cut
  line round it in blue (`CUT`), Helvetica labels. `picture` draws the same page
  at 300 dpi (2480 x 3508), the cut line a pixel inside each sticker's edge, and
  `png_bytes` adds a pHYs chunk so the PNG says it is 300 dpi (`png_dpi` reads it).
- `prints and stickers in the parts bin` (`src/prints/print_studio.gd`,
  `PrintStudio`, made by main; `sticker_sheet_dialog.gd`, `StickerSheetDialog`):
  the bin's **Print…** and **Stickers…** buttons (`print_wanted`,
  `stickers_wanted`). Print… opens the designer on the part in hand, or, with
  one part picked out in the model (Shift-click), on that part: saved, the
  printed part takes its place, in its colour (`_in_place`: `take_off` then
  `put_part`, two steps of undo), and is in My prints too. Under My prints and My
  stickers a cell is labelled with the name its maker gave it
  (`PartPrints.given_name`, out of "…, Custom Print Monument Valley" or "Sticker
  … mm, Brick Street") and drawn with its picture (`ThumbTile.printed`); other
  parts keep their id and the bin's plain picture. Stickers… opens the sheet: the
  model's stickers with their size and count, each with Stick on…, Move… and Peel off; the stickers made
  before that the model does not use; New sticker…; Save sheet as PDF / as PNG
  (300 dpi) — a file dialog on the desktop, a download in a browser. A face is
  asked for by a pane laid over the view (`ask_for_face`), so the click goes to
  nothing else; Escape or the right button says no.

## How to reach it

```sh
godot --path .     # hold a part, Parts bin > Print…  ·  Parts bin > Stickers… > New sticker…, click a face
```

## How to check it

```sh
godot --headless --path . --script src/dev/print_probe.gd
godot --headless --path . --script src/dev/sticker_probe.gd     # needs pdftoppm and pdfinfo (poppler-utils)
godot --path . --resolution 1400x900 --script src/dev/print_ui_probe.gd     # needs a display
godot --path . --resolution 1400x900 --script src/dev/studio_ui_probe.gd    # needs a display
tools/build_custom.py shots/print_probe.mpd --check
# in a real browser, against a preview (tools/deploy.sh without --prod) or a local export;
# source .env first so browser.mjs signs the page in; a preview is behind Vercel's login
# without BW_BYPASS, and the flow sees only "Log in to Vercel"
BW_BYPASS=$VERCEL_BYPASS node tools/web/studio_flow.mjs --url=https://<a preview>/app --out=shots/studio_web
```

Proves it when:

- `print_probe` ends `a print drawn here is on the part where it was drawn, in the
  app and the file`: 3626c's face and back (CYLINDRICAL 180), 973's front and back
  with the front's TEXMAP points top left, top right, bottom left and its mask a
  trapezoid, one front over 3815b, 3816c and 3817c, 3068b's top 410 x 410, 3039's
  slope; the paint document's brush, mirror, fill, undo, redo, words and layers;
  then a face, a torso front and back, a pair of legs and a tile printed, each
  part its plain part to the triangle, the collision box and the connector, its
  pictures on surfaces of their own, and every printed corner carrying exactly
  the coordinates its file's TEXMAP line gives its position (160 on the head);
  the same print twice is the same part; a figure in the prints stands exactly as
  the plain one, the printed left leg on the left; the hips come and go with the
  legs; the print is first in its slot; the model file carries the pictures as
  !DATA in lines under 80, reads back to the same bytes, and a library that never
  saw them builds all four parts and keeps the pictures; 3626cp01's grin lands on
  the middle of the face and nothing on the back; 973p01's stripes on the front.
  It leaves the figure's file in `shots/print_probe.mpd`, and `build_custom.py
  --check` reads it strictly ("all complete").
- `sticker_probe` ends `pictures go on any face and stickers on any faces, and the
  sheet prints true to size`: an SVG read in at 1024 x 512; a JPEG named .png read
  by its bytes; a photograph fitted to a 2 x 2 tile's top, moved (its left edge
  clear), undone, turned 30 degrees and made smaller (the face's corner clear, its
  middle covered), cropped to half, see-through at half (alpha 127), mapped to
  LEGO's inks (every pixel a palette colour), at most 3 inks, or full colour
  (thousands); a logo's white background cleared; a drag 3 pixels off the face's
  edge and 2 off its middle snapped to both; 18 starters on square, long and tall
  canvases; a photograph on 3068b and a logo on 3037's slope made into parts under
  My prints, the slope's print on its slanted face only; 98138's round top round
  on its canvas; 3960's dish printed from above over 496 curved faces. Then two
  2431 tiles side by side: a click on one finds the top of both (80 x 40 LDU, 2
  bricks), one with Shift, and one aimed along the edge a tile's two top
  triangles share; the sticker 78.5 x 38.5 LDU (31.4 x 15.4 mm), a film 0.25 LDU
  thick with no connectors or cover, under My stickers; stuck on at the middle of
  both tiles' top, its printed face up, stuck to both (`stuck_to`), listed by the
  parts list as "Sticker 31.4 x 15.4 mm, … (custom element)" and named in the bin
  by the name it was given; undo, redo, peeled off and undone; the model file read back into a library that
  never saw it with the same picture bytes. The sheet: `pdfinfo` says one A4 page;
  `pdftoppm -r 600` renders it and the cut line measures 31.39 x 15.39 mm against
  the sticker's 31.40 x 15.40, inside the two real tiles' tops (31.8 x 15.8 mm) by
  0.41 mm; the PNG says 300 dpi, is 2480 x 3508, and its cut line measures 31.41 x
  15.41 mm. It leaves `shots/print_stickers.pdf`, `print_stickers_300dpi.png` and
  `print_sticker_probe.mpd`.
- `studio_ui_probe` ends `a photo, a logo and a sticker were put on a model by hand,
  saved and opened`: Print… on a held 2 x 2 tile, a photograph brought in, covered
  and dragged with the mouse, saved — its bin cell says "Monument Valley" and
  differs from the plain picture of it where the photograph is — and clicked
  down; the Brickworks logo (web/icon.svg) on 3037's slope, its background
  cleared, in LEGO inks; a plain 2 x 2 tile in the model picked out with
  Shift-click, Print… on it, a dial starter saved (named "Dial" for it), and the
  printed tile standing
  where the plain one stood in its white, nothing left picked out and no outline
  drawn; Stickers…, New sticker…, a click on one of two 1 x 4 tiles, a street sign
  drawn with the fill, box and text tools, saved and stuck across both; the sheet;
  the model saved with four !DATA pictures and four made parts, and opened again
  through Open… > From a file on this computer… (its file dialog up, the file
  chosen in it) with all four. **Look at** `shots/studio_photo_editor.png`, `studio_slope_editor.png`,
  `studio_sticker_editor.png`, `studio_model.png`, `studio_sticker_top.png`,
  `studio_sheet.png`, `studio_reopened.png`.
- `studio_flow.mjs` (the web build, WebGL 2 and IndexedDB, which the desktop
  probes cannot vouch for) ends `studio flow: a photo, a logo and a sticker made in the browser, measured, carried and opened`: the
  scene opened through Open… > From a file; Print… with "or print on" 3068b, a
  photograph brought in through Add a picture… (the page's own file input),
  covered, saved and clicked down; web/icon.svg on 3037's slope, its background
  cleared, in LEGO inks; Stickers… > New sticker…, a click on the two tiles, a
  sign drawn and stuck on; the sheet saved as a PDF download and measured by
  `tools/sticker_sheet_check.py` within 0.1 mm; the model exported and opened in
  a second, empty browser with all its printed parts. No script error reaches
  the console. **Look at** `shots/studio_web/*.png`.

## Gotchas

- **A print is a surface with texture coordinates, and nothing else is.** The
  .lbm format has no UVs; a printed part's are worked out when it is built, from
  its file's TEXMAP lines, and live only in memory (`Lbm.PartMesh.prints`). A
  printed part changed by the element maker (`PartEditor.shape_of`) loses its
  picture.
- **LDraw's cylindrical spec contradicts itself** on which way V runs (ldraw.org
  forum thread 13633). LDView and LDCad measure it down from the top point;
  `Area.uv` does too, and U as LDView does, per corner rather than per triangle
  (a print's faces never reach the cylinder's seam, which is behind the area).
  Off the picture, LDView clamps to a clear border and LDCad (2014) stretched the
  edge pixels, so every finished picture has a clear outermost pixel.
- **A packed array read out of an Array or Dictionary is a copy**, as in
  elements.md, and it bit twice here: `preview_meshes` built empty meshes, and
  `Stickers.in_model` listed each sticker with no bricks, so the sheet was empty.
  Both gather in plain Arrays now.
- **atan2 of -0.0 is half a turn.** A tile's top seen from in front had its
  facing's z at -0.0 and the preview showed it from behind; a face looking straight
  up or down is turned to from the front. And a `Vector3` key with a -0.0 hashes
  apart from the same key with 0.0: direction keys add 0.0 to each component.
- **Two buttons called Fill.** The paint bucket and the picture panel's button
  had one name, and a check that found buttons by their words pressed the bucket
  and filled the picture into ink. The panel's are "Fit it" and "Cover".
- **The head is 30% cylinder.** 3626c's faces are 3557 LDU² of which 1055 are on
  its 13 LDU cylinder; the rest is its top, neck and both their insides. A head
  counts as round at 20%.
- **A click on the middle of a tile is a click on a crack.** A tile's top is
  two triangles meeting on its diagonal, which runs through its middle; a ray
  aimed there met neither in floating point and the engine's
  `TriangleMesh.intersect_ray` answered with the tile's far side, so a sticker
  for two tiles went on the floor under them — and the same ray gave the top a
  moment earlier. `Rays.nearest` tests every triangle grown a hundredth of an
  LDU (`GROW`), so the two overlap along the edge; `sticker_probe` aims at that
  very point. Picking a face goes by the click's own position
  (`InputEventMouseButton.global_position`), not `get_mouse_position()`, which
  is the system's pointer that a check's clicks do not move; and the pane takes
  the release too, or the builder put the part in hand down.
- **A made print's picture is a surface of its own**, and the bin draws surface
  0 only (official prints read better at 96 pixels without their detail), so
  every cell under My prints was a red frame round a hole until the bin asked
  for those with their print.
- **A browser flow listens for file pickers from the start.** Playwright only
  catches a picker while something listens for one; a `waitForEvent` added
  just before the click, on a page whose frames took most of a second, was
  sometimes switched on after the app had asked (`input.click()` with the click
  still live), and the picker was never seen. `studio_flow.mjs` keeps one
  `filechooser` listener on each page and takes pickers from it.
- **A brick leaving the selection has to say so.** `take_off` erased the plain
  tile from the selection without `selection_changed`, and the world's rebuild
  redraws the outline only while something is selected, so after a print in
  place a yellow box stayed round the print. `take_off` and `_lift_figure` (a
  figure picked up while picked out) now emit it.
- **A sticker is in nobody's way, and in no lattice.** Having no cover, the
  lattice's ray does not find it: it is peeled off and moved from the sticker
  sheet, not by clicking it. `Stability` passes over a brick with no boxes.
- **Studio and LDCad were not run here** (neither runs on this Linux box);
  LDView 4.7 (its release AppImage, extracted, under Xvfb) was, and draws the
  prints where the app does (`shots/print_ldview_front.png`, `_back.png`). The
  files keep to the TEXMAP spec as LDView reads it; Studio's own PartDesigner
  writes `PE_TEX_INFO` instead, which other programs do not read
  (docs/custom-elements.md).
