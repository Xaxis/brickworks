# Parts

Finding one of 28,000 parts by the words a builder would type, and getting its
geometry in front of them.

<!-- covers: lib:part search, ui:parts bin, ui:palette, lib:mesh fetch, ui:recent and favourite parts, ui:techniques in the bin, ui:find a part from a photo, cli:dialog look probe, cli:picker folder probe, ui:the app's dialogs and menus, ui:where a chooser opens, cli:contrast probe, ui:buttons seen and read -->

## Sub-features

- `part search`: ranked search over the catalogue (`assets/generated/catalogue.json`,
  14 MB). Matches the LDraw title, the category and the number, and is judged on
  whether the *first* few answers are usable rather than on recall. The bin and
  the assistant ask in the library's words (`PartLibrary.in_ldraw_words`): a
  size as people type it, "2x4", "2X4", "2×4", is spelled LDraw's way, "2 x 4",
  and a builder's word ("cheese slope", "jumper") is put in LDraw's. The bin
  asked in neither: "brick 2x4" found nothing there (brickworks.diy at dd5c10c,
  2026-10-12). `vocab_probe` holds both spellings to the same answer;
  `handbuild_probe` types them into the bin's field.
  A print is found by what is printed on it: the bin and the assistant match
  one index, `PartLibrary.matched` over `PartInfo.own_words` (number, name,
  category, and "print" or "sticker" for what is on the part,
  `PartLibrary.decor_of`: LDraw names a print a Pattern, a part with its
  stickers on a Sticker Shortcut, and the Sticker category is the stickers)
  and then `keyword_words`, the part's !KEYWORDS ("Porsche", "Speed
  Champions", the sets, BrickLink's number). A part found only through its
  keywords is listed after every part its name found (`_sort_for`,
  `KEYWORDS_ONLY`), so a plain query keeps its answers and their order.
  "printed", "pattern", "decal" and plurals are put in the index's two words
  (`ALSO_KNOWN_AS`). Of 28,426 parts that are not redirects, 9,935 are
  prints, 2,632 have stickers on, 49 both, and 4,265 are stickers. Asked for
  a print, a print does not pay a variant's cost (`VARIANT`, which still
  keeps prints under their plain part otherwise), and the query's words found
  in what is printed (`PartInfo.printed`, the print's words the plain part's
  name has not got) score `PRINTED_HIT`, above a name that begins with the
  word: "flame print" leads with a round tile and a 45 slope with flames
  printed on, not the flame piece in marbled yellow. `_index_prints` gives each print and stickered part its
  plain part (`print_of`, by number: 3623 for 3623pt1, 3068b for 3068bd2j;
  584 have none in the catalogue) and `prints_of` the other way. "porsche
  print" found four stickers whose names say "Porsche Bag Print", and "turbo
  print" nothing; 15068pt2's keywords alone say Porsche (2026-10-13).
  Nothing in the catalogue changed: names, categories and keywords were all
  in it, so the web needs no rebuild. `search_parts` says it on each line
  (", 11 prints"; ", a print of 3623") and once in full ("3623 has 11 prints:
  ...; search_parts \"3623 print\" lists them"); `find_parts_like` ends with
  the prints that show what it was asked for (`Assistant._printed_with`),
  since its families are plain moulds. The figure builder's search
  (`MinifigDialog._matches`) reads the same index. `print_search_probe`
  holds 26 print queries to parts read off the catalogue, 22 plain queries to
  the part they led with before (and, in the bin, the two rows an index of
  names alone gives; in search_parts no print ahead of a plain part), and the
  tool results.
  `search_parts` (and `find_parts_like`'s prints) no longer needs every word:
  `PartLibrary.search` asks `PartSearch` (`src/parts/part_search.gd`), a word
  index made at the first search (about a second, once). A part is ranked by
  how many of the asked words it has, then plain before prints, stickers and
  Duplo, then how many in the builder's own words, then what the words are
  worth (rarer words more), and parts within a tenth of each other in
  `_sort_for`'s order. Words match whole, with plurals ("4" is not in
  "6410654"); a size is the name's first "N x M", either way round, with its
  height if asked; colour words are dropped unless a print is asked; a part
  number asked leads; two words a name runs together are found ("air tank",
  Airtank). A builder's shape words (`SAME_SHAPE`: macaroni, quarter, dome
  bottom, spiky, bowl, half circle) are also read as the catalogue's, and the
  words set inventories name each plain part by are read beside its name
  (`PartInfo.also_called`, from `assets/ldraw/part_names.json`, made by
  `tools/part_names.py` from Rebrickable's parts.csv through the one join in
  `tools/rebrickable.py`; 553 is "Brick Round 2 x 2 Dome Top" there). Asked by
  shape, a print has no more of the words than its plain part. A word no part
  has is said ("No part's name has ..."). The bin still filters to parts with
  every word. `shaping_search_probe` holds 42 builders' queries (the m147
  round's seven failed searches, earlier sessions', and set inventories'
  shape words) to the parts an expert wants in the first five, the round's
  searches that found their part to the same first answer, and the batch's
  time; run it as is and with `-- --parts-only=` BrickNet's list. Base
  (`dec645b3`) met 17 of 42 and none of the seven, at 108 ms a search.
  Then by how much real sets use a part (search242, walk239 A13: "door frame"
  led with 80400a, in 24 sets, over 60596, in 850): among the parts that
  answer as well (every word in the part's own name; else bands of how well),
  a part filed under a word asked first (its category: "wedge" is Wedge 4 x 4
  Curved, not Technic Wedge Belt Wheel), then `PartInfo.commonness`, the sets
  and pieces the set inventories hold it in (`assets/ldraw/part_usage.json`,
  made by `tools/part_usage.py` from `assets/generated/sets/`; run it after
  `tools/collection_data.py`), the catalogue's `in_sets` where that has
  none. A part's number typed leads among those with as many words. A word
  begun matches the words it starts ("doo", as typed), one a letter off a
  word no part has is taken for the word ("tyle", "hindge", "axel"), and two
  run together are both ("doorframe"). Brick, plate and tile are each a
  family and a height: asked of a part of another family, it answers by how
  tall it is (`PartSearch.HEIGHTS`): "wedge brick" is a 3.5-plate Wedge, not
  45677, the curved 4 x 4 x 0.667. A brick, plate or tile "with" something,
  not round, is BrickLink's Modified and Rebrickable's Special: "plate
  modified" is 15573, the jumper. `select_by` asks without these
  (`loose = false`). Keys are sorted as whole numbers over dense arrays, and
  the index is made on a worker once the bin is filled
  (`PartLibrary.prepare_search`), so a first key typed answers in about
  30 ms on a quiet box (54 ms the slowest letter at load 13, twice that at
  38). `search_rank_probe` holds 63 queries written before the change
  (names, sizes, numbers, misspellings) to the parts an expert wants in the
  first three, in the bin and in search_parts: base 78% and 81%, now 98%
  both; five more of a family and its kind ("round brick", "plate
  modified"), 3 of 5 before the height and Modified rules, 5 after; and a
  first keystroke said against 50 ms, failing past 150.
  And in the names builders use, BrickLink's and Rebrickable's (names248:
  "liftarm 5" missed 32316, LDraw's Technic Beam 5). Rebrickable's words for
  a part (`also_called`) and its size where LDraw's name gives none or
  another (`PartInfo.also_size`, part_names.json's "sizes": 32316 is a 1 x 5
  there) are its own name, matched as fully as LDraw's, so usage decides
  between the parts either answers. BrickLink's words for LDraw's
  (`PartSearch.SAME_WORD`: liftarm a beam, Modified Special, connector
  joiner, bushing bush, a half bush Bush 1/2, a 3L pin Pin Long) count in
  full too, as do a length and a gear's teeth as builders write them (3L is
  3, 24t and z24 are 24 Tooth). In the bin, which wants every word, the words
  a name puts in brackets and its Modified (`QUALIFIERS`) tell versions apart
  and are not required: "Technic, Gear 24 Tooth (2nd Version - 1 Axle
  Hole)" is 3648b. An element number as a booklet prints it (six to eight
  digits, `PartLibrary.part_of_element`, from elements.json's pairs and its
  "also", every other element of a pair, made by `rebrickable.elements`)
  puts its part first; the bin takes its colour in hand, so its tile is
  drawn and placed in it, and search_parts says "Element 4142135 is 32316 in
  Black (colour 0)". A number LDraw keeps as an obsolete part in one colour
  (4121715, a black 2780) is its element. elements.json is read with the
  index on its worker (`prepare_search`), so the first element number typed
  takes 3 ms, not 155. `search_rank_probe` holds 31 more queries written
  before the change (BrickLink names short and in full, Rebrickable's,
  Technic words, a BrickLink number, four element numbers each in its
  colour): base 39% in the bin and 55% in search_parts, now 100% both
  (top 1, 97%); search242's 68 at 99% top 1 and 100% top 3. elements.json's
  "also" is in the shared data only once `tools/refresh_catalogue.py` has
  run with this `tools/rebrickable.py`; until then 300123 (a blue 2 x 4 only
  "also" has) finds nothing.
- `parts bin`: the panel that shows the results, with a category filter and the
  current colour applied to the thumbnails. It searches through `PartSearch`
  (every word, ranked as search_parts ranks), and folds each print, sticker
  and assembly of a part that is listed too under that part's tile, behind a
  count in its corner (`PartsBin._fold`, `_fold_badge`; by a finger a
  44-point square in the tile's foot, clear of its picture, which a tap
  takes the part from: walk256 T1): pressed, they follow the tile, pressed
  again they fold; typed with "print" or "sticker" they are
  listed as themselves, which is how the keys reach them (no tile takes the
  keys, and a field gives them back at Tab, `FocusGuard`). One assembly LDraw
  draws whole is put beside its part instead (60593c01, the window with its
  glass, after 60593; `PartLibrary.wholes_of`). `bin_fold_probe` types 3008,
  3001, 3039 and 3069b and opens and folds each; `bin_flow.mjs` does the same
  in a browser at 1280 and 390. A part dragged out of it is in hand
  from the start of the drag, its ghost follows the pointer over the model and
  it is put down where it is let go (`PartsBin._cell_input`, `part_dropped`);
  let go over a panel, it stays in hand. Its tooltip hides while it is carried.
  A drag did nothing and carried the tooltip along (2026-10-12). **Make a part…** in its header
  opens the element maker, and made parts lead the categories as Custom —
  see [elements](elements.md).
- `previews` (`src/ui/part_thumbnails.gd`, `src/ui/thumb_tile.gd`): each cell is
  a `ThumbTile`. A colour picked points each tile at the new colour
  (`show_part(..., keep)`) and it keeps the picture it had until the new one
  lands, then crossfades: the grid was made again, every tile blank for
  seconds (walk180 A3). Until its picture is drawn it is a placeholder the picture's
  size with a band of light crossing it (`src/ui/shimmer.gdshader`, one shared
  material driven by `TIME`: no script runs per waiting tile; only on a tile
  in sight, `ThumbTile.in_sight`, set by `ThumbTile.Sight`, because a shader
  reading `TIME` anywhere on the window has every frame drawn — see the
  gotcha below), the part number
  under it; the picture fades in over it (0.2 s); a part that cannot be drawn
  (no geometry, a failed fetch) shows a brick outline and "no preview", and is
  tried again after 30 s if it comes back into sight. The bin tells
  `PartThumbnails.watch` which tiles are in sight (`ThumbTile.Sight`: the rows on
  screen, then a screenful below, then half above) and only those are drawn or
  fetched, in that order; `PartLibrary.prefer` puts their fetches ahead of ones
  scrolled past, behind only a part somebody clicked. `request()` still draws a
  picture wanted outside a grid, after the tiles in sight.
- `palette`: every colour can be chosen by hand, grouped by kind of plastic
  (solid; transparent; chrome, metallic, pearl; glitter, opal, speckle, glow,
  rubber, fabric), greys first and then round the colour wheel. What sets are
  built in now leads (`PartLibrary.is_current`: the colour's own `years` if the
  colour data carries them, otherwise any part in a set in it since
  `recent_since` — 84 colours); "All 320" adds the rest after a rule. Each
  swatch is drawn as its finish; its name, finish and status are on hover, and
  the colour in hand is named under the palette, in a note always two lines
  tall (the rest on its tooltip): it grew from one line to two when a part was
  chosen and moved the palette 19 px under the pointer. With parts selected,
  and a click on a colour would paint them, the note describes them instead
  ("Brick 2 x 4 in Red, selected: a colour clicked paints it", and the dots are
  that part's; `PartsBin.show_selection`, `Main._tell_bin_selection`). A dot marks the colours the
  part in hand was really made in; a colour it was never made in is dimmed, but
  only where its list is complete. A swatch clicked with parts selected and
  nothing in hand paints them too, one undo step (`swatch_pressed`,
  `Main._on_swatch_pressed`, Edit, Paint the selection), as Studio's palette
  does: it only changed the colour in hand, and the brick a person had
  selected stayed red (2026-10-12). With a part in hand it is the colour of
  what goes down next. `handbuild_probe` clicks one. The bracket keys and the
  eyedropper go through `_on_colour` without painting, which opens the long
  palette for a colour the short one does not show. A colour by its name or
  number (2026-10-16): the field beside Colour (`Shift-C` puts the keys in
  it; Build and the controls list say so) shows, from every colour there is,
  those that answer (`PartsBin.colours_named`: the number exactly, LDraw's or
  LEGO's name exactly, a name beginning so, every word in a name, numbers
  beginning so; gray is grey; the most used first), the line over them naming
  the first ("Light Grey (7) first of 3"), so a name is typed only until it
  is the one; Enter takes it into hand as a click on its swatch does, the
  field emptied and the keys given back. The old greys (7 Light Grey, 8 Dark Grey), all over older sets,
  are not in the short palette and look like the bluish greys beside them
  under All: the CAD task test put 3 parts of 8 in the wrong colour for want
  of them. `handbuild_probe -- only=build_from_a_booklet` types "light grey",
  "dark gray", "71" and "Light Bluish" and reads the colour in hand. The mosaic keeps its own 44 (`Mosaic.PALETTE`). The palette
  is a section of its own at the foot of the left-hand column
  (`PartsBin.colours`, under the model tree and the properties), as tall as
  what it holds up to 14% of the column and a scroll beyond
  (`_fit_palette`): a fixed 168 cut the last group's title in half, and sized
  by the bin it sat in, the parts grid had room for two rows at 1440 x 900.
  Nothing but the window's height changes it. In a column under 700 units
  the categories take one row: on a phone held sideways the parts list had
  been a sliver with no part in it. Otherwise the category buttons show two
  whole rows and a scroll bar, not the top of a third.
- `mesh fetch`: a part whose mesh is not in the shipped pack is fetched from the
  storage bucket at run time. Several callers can ask for the same part at once,
  and every one of them has to hear that it arrived. Geometry and exact shapes
  (and so the bin's previews) go through one fetch, `PartLibrary._ask`: a fault
  that may pass (no answer, 408, 429, 5xx: `may_pass`) is asked again after
  `RETRY_AFTER` (2, 6, 12 s), a 404 or the bucket's 400 is final; a part asked
  for while it waits joins the wait, and a wait holds no place of the six open
  at once. A model's parts still not come once nothing of it is on its way are
  said once in the status bar ("27 bricks — 2 parts could not be loaded, and
  are kept in the file", `ModelStore.not_coming`); they stay awaited, so Save
  writes them where the file had them, the app's own files too, and one that
  arrives later is put down.
- `availability`: which colours each part was really moulded in, and the years it
  appeared in a set. Joined from Rebrickable's tables by `tools/rebrickable.py`
  at catalogue-build time; read by `PartInfo.colors` / `colors_recent` /
  `never_made_in()`; surfaced on the search line and as `check_design` advice.
- `what each colour is`: `assets/generated/colors.json`, written only by
  `refresh_catalogue.write_colors` (`build_meshes.py` calls the same function).
  Per colour: LDraw's code, name, values and finish; its LDConfig `group`
  ("internal common material" is 16, 24 and sticker film — `BrickColor.is_plastic()`
  says no); LEGO's `lego_ids` and `lego_name` from LDConfig's `// LEGOID`
  comments (185 colours: 71 is LEGO's Medium Stone Grey); `plain_code` for a
  rubber or canvas variant (Rubber Black is Black to Rebrickable and a shop); and,
  for the 210 codes the colour join reaches, `rebrickable_id` (+
  `rebrickable_also` where Rebrickable keeps two entries for one colour),
  `rebrickable_name`, `years`, `sets`, `current` (in a set within two years of
  the newest in the tables: 77 colours) and `matched_by`, the evidence.
  `bricklink`, BrickLink's colour number, for the 197 codes
  `tools/bricklink_colours.py` has one for (`PartLibrary.bricklink_colour`, which
  asks for the plain colour of a rubber one). That table was built once, on
  2026-10-12, from Rebrickable's colours page (the Internet Archive's copy: the
  live page is behind Cloudflare), the SetDB guide, BrickLink's own colour guide
  and LDConfig's LEGO numbers; its docstring says which evidence a pair needs.
  `HELD_BACK` names 12 colours a source pairs that the evidence does not bear
  out. Two of the hand-made table's 61 were wrong and were settled by the owner
  (2026-10-12): 41 Trans Medium Blue is 74, not 15 (Trans-Light Blue, LDraw 43),
  and 179 Pearl Silver has none, since 95 Flat Silver is LDraw 315. Any other
  colour has no number and a guessed one orders the wrong colour. `colour_matches()` is the join; see the gotcha below.
- `how often a part is really used`: `rebrickable.usage()` counts the distinct
  catalogued sets each part appears in and writes `in_sets` onto every part that
  joins. `PartLibrary.staples(n)` gives the most used, `PartsBin._usage_score`
  folds it into search ranking, and `Assistant._what_sets_are_built_from()` puts
  the top thirty in the system prompt.
- `how a kind of set is built`: `rebrickable.kinds()` measures, for every word
  that names 20+ real models, the parts those sets reach for *more often than
  sets in general* and the colours they build in — 267 kinds in 86 KB of the
  catalogue, over models only (see `set norms` below for what is not one). Each
  kind also carries `common`: its 40 most used parts by the share of its sets
  that use them at all, which lift cannot say — lift finds what makes a castle a
  castle, and a 1,895-part castle also has some 260 shapes, mostly ordinary ones.
  Both are counted in **sets, not lots**: counted by lot, a set with the 1 x 2
  plate in four colours used it four times, and the castle's share of 1 x 2
  plates came to 346%. `PartLibrary.kinds_for(brief)` matches a brief's words against it
  and `how_real_sets_build_this`, a tool, is how the assistant asks.
- `set norms`: what a real LEGO set of a given size is made of — lots, shapes,
  colours, how many of one piece is normal, shapes used once or twice, its main
  colour's share, and the share of its pieces as big as a 2 x 4 brick (`big`,
  sized through the one LDraw join by `rebrickable.piece_size`; a median 9-11%
  at every size) — measured over every catalogued model set by
  `rebrickable.set_norms(entries)` and written into the catalogue header.
  `PartLibrary.normal_for(parts)` gives the band; `Assistant._variety()` says
  when a design is well under it; the system prompt carries the whole table.
- `element numbers`: the LEGO element a part in a colour actually is —
  `3001` in red is `300121` — so a parts list is orderable rather than
  descriptive. `rebrickable.elements()` writes `assets/generated/elements.json`
  (0.9 MB, 41,376 pairs over 5,300 parts); `PartLibrary.element_for()` loads it
  lazily; `Inventory.Lot.element` carries it into the CSV and the booklet. The
  CSV also carries `lego_colour` (LEGO's name) and `rebrickable_colour`, last so
  the first eight columns stay where they were.

- `recent and favourite parts` (`src/ui/part_shelf.gd`): *Recent* and
  *Favourites* sit beside *All* in the bin. A part chosen (or picked off the
  model with G) goes to the front of Recent, 24 kept; right-click any part to
  keep it in Favourites, marked with a star. Kept in `user://part_shelf.cfg`,
  never under a probe (`PartShelf.keeps`), which points it at a file of its own.
- `techniques in the bin` (`src/ai/techniques.gd`, the bin's Techniques):
  *Techniques* sits beside Recent and Favourites, the assistant's worked
  constructions (`Techniques.all()`, 91 on 2026-10-24) under their
  `Techniques.GROUPS`, one a row with its picture (`PartThumbnails.offer_group`,
  drawn once a colour and cached as a part's is) and its one-line reason
  (`Techniques.reason`, the first sentence of its *why*), titled as words
  ("Door in a wall", `Techniques.title`). What is typed finds them, best
  first (`Techniques.found`): every word in a construction's name, group or
  use, whole, through its plural or as a word's start or end, worth most in
  the name; the groups with the best first, the best first in each. walk256
  TQ1: "door" led with columns and an awning, and "stairs" found nothing;
  `technique_search_probe` asks 18 queries written before the change, each
  needing its construction in the first three rows (12 of 18 on base, 18 of
  18 now). A row chosen is read as a design's words are, by an
  assistant of the bin's own (`Techniques.as_ldraw`, never the one designing),
  into LDraw lines and back (`Carry.from_ldraw`, the path a paste takes), and
  held whole (`EditVerbs.hold`): R turns it, a click puts it down, one undo
  takes it all back. The colour in hand stands in for its main colour
  (`Techniques.main_colour`, the colour most of its parts are in).
- `find a part from a photo` (`src/net/brickognize.gd`): the camera in the
  bin's search field. The first press says the photo goes to Brickognize, a
  third party that may keep it and train on it (their terms, read 2026-10-24),
  and that nothing is sent until a photo is chosen (`ShellPrefs` `photo_told`,
  once a device); then the picker (`PickImage`, the camera on a phone; on
  the desktop Godot's file dialog, opened where the last picture was
  chosen from, else Pictures: see `where a chooser opens`). The question
  and the chooser are in the app's look (see `the app's dialogs and
  menus`). The
  photo, at most 1024 px, is posted to `api.brickognize.com/predict/parts/`
  from wherever the app runs (CORS `*`, no key; `connect-src` in
  `tools/deploy.sh`); its BrickLink numbers become parts here by
  `PartLibrary.by_shop` (LDraw's "BrickLink 3062" keyword, else the number,
  else the mould under a letter) and show as the bin's results, each with how
  sure Brickognize is. The colour it sees is asked for too
  (`predict_color=true&top_k_colors=1`, `Brickognize.colour`, a BrickLink
  colour number through `PartLibrary.by_bricklink`) and taken in hand, as an
  element number's is, where it is at least `COLOUR_LEAST` sure, and the
  line says "in Black": a black slope's photo came back in the red in hand
  (walk256 S3). `photo_search_stub_probe` answers Black at 0.81 and 0.12 and
  none; `bin_flow.mjs` sends the blue 3039 fixture live and reads the colour
  in hand turn blue. Offline, refused, garbled or empty, the status line says
  so in words.
- `the app's dialogs and menus` (`Look.dialogs`, called first in
  `Main._ready`): every dialog of the engine's (AcceptDialog,
  ConfirmationDialog, FileDialog and the questions a FileDialog asks
  itself: Create Folder, the overwrite question) has the panels' dark face
  (`Look.FACE`), faint edge and round corners for its frame, title bar and
  body, on the desktop and the web; every menu (the menu bar's, a part's,
  every list's) on both, and on the desktop every popup (the colour
  picker's) too. Put in the default theme before the first window is made,
  so it reaches every one; sizes stay the engine's. A menu's rows
  (`Look.menus`): the row under the pointer or the keyboard's focus is
  `Look.ROW_LIT` edged in `Look.ACCENT`, a greyed row's words and every
  key `Look.GREYED`, so every state reads 4.5:1 or better off the window's
  pixels (APP_UX A2: a greyed row with the focus was a blank bar, its words
  the highlight's grey). `keysheet_probe` reads every row of the six menus
  in each state (normal, under the pointer, focused, greyed, greyed and
  focused); it read 1.94:1 at worst before. `tools/web/desktop_same.mjs`
  needs a base build with keysheet's menus from then on.
  walk256 DS1 (2026-10-25) found the photo search's question, Build
  together and the choosers in the engine's grey. `dialog_look_probe`
  opens each as a person does (Render's panel gives the face), then pops
  up every other dialog and menu in the window and reads them all: 134 of
  its checks failed on desk263's build, none after.
- `buttons seen and read` (`Look.buttons`, called first in `Main._ready`
  beside `Look.dialogs`): every button of the engine's (Button,
  OptionButton, MenuButton) and every tab not chosen is edged in
  `Look.OUTLINE` (the tick boxes' outline, #d4d9e2), inside its own box,
  so nothing moves; the engine's fill alone, black at 60% on the dark
  face, was 1.0:1, and "Start a session", Cancel and Join read as words.
  A question's default (a ConfirmationDialog's or FileDialog's OK) is
  `DefaultButton`, a type variation of Button in `Look.STRONG` with white
  words, told apart from the rest; Render's strong button is the same
  blue (its words were 3.4:1). A chosen tab or segment is `Look.CHOSEN`
  (the accent at 65%; at 38% it was 2.0:1). The panels' own faint edges
  (the model bar's, the toolbar's choosers, the library's and
  collection's tabs, the figure builder's cells, the parts rail's line)
  are `Look.OUTLINE` too. On the desktop and the web: the web's main
  window changed with it (the parts tiles, the model bar), so
  `desktop_same.mjs` takes a base build with contrast270 in it from then
  on. `contrast_probe` (extends `dialog_look_probe`, the same windows plus
  the main window and its fifteen main panels) reads every button off the
  pixels: its edge or fill 3:1 on its face on the side it is best told
  on, its words 4.5:1 in their own colour on its fill and drawn 3:1, its
  picture 3:1, a question's default 3:1 from the rest; a flat button, a
  link, a tick box or a toolbar's faceless button is its words or
  picture. 307 of 653 buttons failed on rel-m176, none after
  (2026-10-26). The app has one theme, its dark one.
- `where a chooser opens` (`OpenFrom`, `ShellPrefs` `open_folders`): on
  the desktop every file chooser opens in the folder the last file of its
  kind was chosen from, while it is there; else a picture (the photo
  search's, Print's, LEGO Art's, the page editor's) in Pictures, a model
  (File, Open, From a file) in the folder the last export went to
  (`SaveTo`) or Documents, a 3D model to brickify and a shop's list for My
  collection in Downloads, where a browser saves them; never the install
  folder, where Godot's own dialog starts. The sticker sheet's Save is the
  Save dialog every export has (`StickerSheetDialog.save_sheet`, `SaveTo`).
  `picker_folder_probe` opens each and chooses a file in it.
- `a part asked for by number` lists its own family first: `3023` gives 3023b,
  3023a and the 3023 prints before 30236 or the 30239 spider (`NUMBER` in
  `_match_score`). And only them: digits that number a part here match
  numbers only, never words in a name or keywords (`PartSearch.ranked`,
  `as_words`), so 3648 is the two gears and not the torsos of set 3648
  ("Set 3648" in their keywords), nor 3001 a torso printed with a 3001 brick
  (walk256 S3); digits no part is numbered by are still looked for as words,
  as a BrickLink number in keywords is. `search_probe` `_only_numbered`, 12
  numbers in the bin's search and the assistant's.
- `thumbnails of light parts` are lit less (`PartThumbnails._light_for`), so a
  white part has a top and sides instead of one flat silhouette.

## How to reach it

```sh
godot --path .     # press P, or the Parts list button, then type
```

The bucket behind `mesh fetch` is `PARTS_URL` in `.env`, also announced by
`GET /api/account` as `parts_url`.

## How to check it

Static: the catalogue itself is built by `tools/refresh_catalogue.py` (see
[pipeline](pipeline.md)); nothing static covers the ranking.

Runtime:

```sh
godot --headless --path . --script src/dev/search_probe.gd          # what it returns; names as LDraw writes them (Théoden, 90°)
godot --headless --path . --script src/dev/search_probe.gd -- --catalogue=PATH  # a corrected catalogue, before it is swapped in
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd  # Recent, Favourites, 3023
godot --path . --resolution 1280x860 --script src/dev/bin_techniques_probe.gd  # Techniques: window in a wall onto a wall, three more; shots/bin_techniques/
godot --headless --path . --script src/dev/technique_search_probe.gd  # 18 queries, each's construction in the first three rows; titles as words
godot --headless --path . --script src/dev/photo_search_stub_probe.gd  # the camera with Brickognize stubbed on 9061: told first, nothing sent, every failure in words
godot --path . --resolution 1280x860 --script src/dev/photo_search_probe.gd -- --keep  # Brickognize live: 5 parts drawn by ModelShot, at least 4 right in the first three
tools/probe.sh dialog_look_probe -- --shots=DIR  # every dialog, chooser and desktop menu in the app's look, read off the window's pixels (108 on 2026-10-26)
tools/probe.sh picker_folder_probe                # every chooser in Pictures, Documents or Downloads first, then where its kind last came from
tools/probe.sh contrast_probe -- --shots=DIR      # every button's edge 3:1, words 4.5:1, a question's default told apart (653 buttons on 2026-10-26); -- --main-only --every lists each
node tools/web/bin_flow.mjs --url=http://127.0.0.1:9063/ --out=DIR   # both in a browser at 1280 and 390 (serve.py on 9063; Brickognize live)
godot --headless --path . --script src/dev/vocab_probe.gd           # the words a builder types
godot --headless --path . --script src/dev/print_search_probe.gd    # a print by what is on it; plain parts unmoved
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd -- only=prints_by_their_print  # typed into the bin; shots/handbuild/prints_by_their_print.png
godot --headless --path . --script src/dev/search_quality_probe.gd  # how much is worth reading
godot --headless --path . --script src/dev/inventory_probe.gd       # parts lists of known models
godot --headless --path . --script src/dev/fetch_probe.gd           # every caller hears it arrived
godot --headless --path . --script src/dev/fetch_retry_probe.gd     # a failing host on 9191 (-- --port=N): asked again, said once, saved and autosaved whole; the deployment asked again where parts live
node tools/web/fetch_retry_flow.mjs --url=http://127.0.0.1:9195/ --out=DIR   # the crane in a browser, its fetches cut then 503; a part 404s and the tab reloads with it still awaited (needs serve.py on 9195)
godot --headless --path . --script src/dev/availability_probe.gd    # what was really made, and silence otherwise
godot --headless --path . --script src/dev/variety_probe.gd        # whether a model reads as a set
godot --headless --path . --script src/dev/usage_probe.gd         # whether search leads with the part sets use
godot --headless --path . --script src/dev/search_rank_probe.gd   # 68 held-out queries and 31 in builders' names (BrickLink, Rebrickable, Technic, element numbers in their colour), bin and search_parts, top 3 at 90% each; a first keystroke under 50 ms
godot --path . --resolution 1280x860 --script src/dev/bin_fold_probe.gd  # prints folded under their part, opened, folded, typed; shots/bin_fold/ (PROBE_SIZE=390x844 too)
godot --headless --path . --script src/dev/kinds_probe.gd         # whether a castle knows it is arches
tools/check.sh --network    # adds remote_probe: geometry over the wire
```

Techniques prove it when `bin_techniques_probe` exits 0: every construction
listed under its group, "window in a wall" held whole (17 parts) with the
colour in hand where its red was, R turning it through four quarters, a click
putting it on the wall's top in the wall's line, the model checking as a design
does, and one undo taking all 17 back; then "smooth diagonal", "round tower"
and "corner on a turntable" likewise on the ground. Look at
`shots/bin_techniques/tab.png`: each row's picture is the whole construction.
The photo search proves it when `photo_search_stub_probe` exits 0 and
`photo_search_probe` says at least 4 of 5 (5 of 5 on 2026-10-24: 3001, 3039,
3062b, 3069b, 3700); the live one needs Brickognize up, so it is in
`tools/suite/out.txt`. The photos it draws are kept in `tests/fixtures/photos/`.

Proves it when: each exits 0 with no `FAIL`. `search` prints its answers for a
handful of queries — read them, they are the point. `vocab` is the one that fails
when the index stops answering a plain English word.

For the bin, launch the app, press `P`, type "wedge": the results are parts whose
titles contain it, drawn in the current colour. `handbuild_probe` types into
the search field key by key ("brick 2x4", "plate 2x8", "2X4 brick", "cheese
slope") and reads what leads; the rest of the panel is hands-only, so say so
rather than claiming it. The palette below
it is covered by `colour_probe` (windowed, in the suite): the short palette has
today's colours and not retired ones, every one of the 320 can be pressed and
held, the eyedropper on a retired colour shows it chosen, and the held part's
colours carry the dot. It leaves `shots/palette.png` — look at it.

The previews are covered by `placeholder_probe` (windowed, in the suite, also
the minifigure builder's grid and slots):

```sh
xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/placeholder_probe.gd
```

`colour_probe` and `placeholder_probe` both open the parts bin by its rail
first, as a person does. A 1400-wide window is about 1520 units, short of the
1600 that holds both columns beside the model, so the columns take turns and a
first visit shows the assistant with the bin folded. A folded bin has no tile in
sight and draws no previews, which is right; until 2026-10-12 both probes read
it as previews never drawn and no tiles in view (#98).

Proves it when it exits 0: the bin opens from its rail, a fresh grid starts all
placeholders, every tile in
sight becomes its picture with no cell changing size, a grid scrolled to row 40
before anything is drawn draws the rows in sight before the screenful below and
none of the 130-odd far below or scrolled past, two parts with no geometry end
as "no preview", once drawn no tile is processing or shimmering, and a colour
picked by its swatch leaves no tile in sight blank or shimmering before each
is its new colour's picture, in the same tiles. It leaves
`shots/placeholders/desktop_*.png` (loading, loaded, failed) — look at them.

On the web, with the network slowed so the waiting shows (export with
`PARTS_URL` set so every part is reachable; the flow starts
`tools/web/serve.py --parts`, which answers `/api/account` as the deployment
would and serves `/parts/*.lbm` late, and counts what it served):

```sh
PARTS_URL=http://127.0.0.1:8761/parts/ tools/export.sh web
node tools/web/placeholder_flow.mjs --build=build/web --port=8761 \
  --parts=assets/generated/parts --out=shots/placeholders
```

Throttling with Playwright's `page.route` instead saw none of the app's
fetches: a run scrolled 4,680 parts deep and counted nothing. A `context.route`
on `.lbm` does see them today (`fetch_retry_flow.mjs`, 2026-10-20), on a local
export and on the deployment's bucket alike.

It scrolls the bin and the builder's heads and photographs each mid-load and
after (`shots/placeholders/web_*.png`); it fails only on a script error or if
nothing was fetched. Whether the waiting looks right is for a person to see.

## Gotchas

- **A one-pixel line can vanish.** The app is drawn at 0.875 of its design
  size in a 1400-wide window (and the browser's own scale on top), so a hard
  1 px line can fall between two rows of pixels and cover neither: the "no
  preview" brick lost its top edge that way. Draw thin strokes antialiased, or
  as filled rects at least 1.5 wide.

- **A tile clipped out of the bin is still on the window.** Godot culls a
  canvas item only once it is off the window, not when a scrolled parent clips
  it, and the shimmer reads `TIME`, so a waiting tile anywhere on the window
  has every frame drawn. In a 1280 x 860 browser the bin's first row out of
  sight sat under the colours, and the page drew every frame standing still,
  a second of software rasterising each (idle_check: 16 of 16; on the desktop
  at 1280 x 860, idle_probe 62 of 62). Only tiles in sight shimmer now
  (2026-10-11); `placeholder_probe` still finds every tile in sight shimmering
  while it waits.

- **A picture of a part is a frame of the whole window.** The next screenful
  below, drawn ahead so a scroll finds it, is pictures nobody sees, and each
  drew the model again: the first part taken in hand resized the palette and
  a dozen of them kept the castle drawing for 23 s with the pointer still.
  Tiles out of sight are drawn, and handed their pictures, only in a frame
  drawn anyway (`PartThumbnails._next_job`); tiles in sight as before.
  `idle_probe -- --model=res://models/castle.ldr` is the check. And the
  pictures in sight are drawn eight to a frame, each in a stage of its own
  (`PartThumbnails.STAGES`, a viewport, world, camera and holder each): one
  a frame, a screenful took 25 to 45 s to fill in a browser drawing in
  software (2026-10-13). `placeholder_probe` has the 16 tiles in sight drawn
  in 4 frames, before any of the next screenful.

- **A grid rebuilt with the same number of cells is a different grid.** A new
  colour rebuilds every cell in the same places; `ThumbTile.Sight` compares the
  first and last cells by identity, or it would keep watching freed tiles and
  the new ones would shimmer for ever.

- **"Dim what the part was never made in" dims nothing on the parts people
  use.** All forty most used parts have a partial colour list (some of their
  colours have no LDraw counterpart), and a partial list can never say
  "never". So the palette marks positively — a dot on each colour the part is
  known in — and dims only where the list is complete.

- **"Another way" was the whole question.** A search result said a part had
  "N studs on top and M facing another way", which is true of a bracket, a
  headlight brick and anything with a stud underneath — and whether the part
  does the job in hand then cost an `attachment_points` call. It says which
  way now: `87087` is "1 stud on top and 1 facing sideways", `99207` is "2 on
  top and 4 facing sideways". Named in the part's own frame and not the
  world's, because an unplaced part has no world and `rot` decides where it
  ends up, so "+x" would be a claim about something nobody has chosen yet.

- **A name can only say so much about a part.** Ranking built out of plainness,
  qualifiers, prints and sizes cannot tell you that 3062b, "Brick 1 x 1 Round
  with Hollow Stud", is in 4,496 sets while 71075a, named just as plainly, is in
  seventeen. Over 35 ordinary queries: **12 led with the part real sets use most
  and the leader carried 71% of the usage the best match had; 16 and 81% once
  `in_sets` counted.** It fixed "round brick 1 x 1", "hinge" (4625, 190 sets ->
  3937, 2,174), "antenna" (104, 5 -> 3957a, 918) and "jumper" (1745, 367 ->
  87580, 2,941).

  Two disciplines hold it up, both asserted. **It promotes and never demotes**:
  5,988 of 29,479 parts join to an inventory, so a zero is silence. And it is
  **capped under the weakest name tier** (100 against 140), so "plate 4 x 4"
  still leads with the 4x4 in 3,603 sets, not the 2x4 in 7,969. Filling the gap
  with explicit zeros to push down parts no set contains moved 221 parts and
  changed no ranking; it is not here.

  Score a ranking against the same usage number the ranking reads. The first
  diagnostic counted inventory *rows* and reported 3023 in "25,944 sets" and 7891
  in none; the honest figures are 9,285 distinct sets and 1.
- **The one join between the libraries is `rebrickable._matcher`.** Colours and
  usage both need to know which Rebrickable part an LDraw id is, and two copies
  of a join drift apart. Extracting it changed nothing: 6,419 parts with colour
  lists and 40,474 element pairs before and after, **0 answers different** — the
  check that made the refactor safe to keep.

- **Lift, not count, or every kind of set is the same list of plates.** Counted
  plainly a castle and a spaceship are both mostly 1x2 plates — true and useless.
  Dividing by what sets in general do gives a castle the arch door at **26x**,
  arched window panels at 15x, lattice windows at 14x, in tan and pearl gold; a
  spaceship the round brick with fins at 9.5x, 2x2 brackets at 7x, in white and
  grey. `kinds_probe` asserts the thing that could fail: **a castle and a
  spaceship share 0 of twelve parts.**

  Four defects it found, each fixed in the data: LDraw files Duplo train track
  under "Train", so `train` led with two Duplo tracks at 70x; minifig
  accessories took the top four places for `pirate` and buried the hull, so
  categories split what a set is *built from* from what it *carries*; 68 entries
  across 367 kinds had lift <= 1.0, the thinner kinds padding their twelve out
  with ordinary plates; and `REAL_MODEL = 20` parts, or the kinds are keychains,
  backpacks and Adidas shoes. Only parts that join to a placeable LDraw id, which
  is asserted over all of them.

  **A kind of thing is a meaning, and the meaning is not in the inventories.**
  Generic words got through — `large`, `play`, `version` — and it mattered because
  the most specific-looking kind goes first, so "a large castle" led with `large`
  over 88 sets instead of `castle` over 175. Dropping kinds whose parts are not
  distinctive was measured and **refuted**: `play` tops out at 190x and `version`
  at 121x, above castle's 26x, while `farm` is 3.3, `car` 4.2 and `fire` 4.5. So
  `NOT_A_KIND` is a word list, 343 kinds, and the probe asserts both halves.

  **It arrives with the brief, not as a tool to call.** Measured twice on this
  project: a capability a design can get by without is one it never uses — it
  reached for sideways building because a smooth sign face is impossible
  studs-up, and never for a wedge plate across three runs. `opening_for()` puts
  it in the first message; a revision naming no kind gets nothing, asserted. It
  admits ignorance: a lighthouse matches nothing and says so. A prefix match at
  4+ letters makes "spaceship" find `space`, the word real sets use.
- **The prompt now says what a set is made of, not what I think it should be.**
  Every other piece of advice in it about what to reach for was mine: tile a
  roof, curve a bonnet, use a bracket for a sign. `_what_sets_are_built_from()`
  is the catalogue counting instead, and the first thing it says is not advice at
  all — **a LEGO set is mostly plates.** Eight of the ten most used parts are
  plates; the 2x4 brick everyone pictures is number 22. A design reaches for what
  it remembers, and what a model remembers about LEGO is bricks.

- **"Does it read as a set" is measured, not judged.** Banded by size over 8,243
  models: one of 350-800 parts has about 158 part-and-colour lots, 123 shapes, 19
  colours, and at most about 23 of any one piece. `models/station.ldr` is the
  fixture because it provoked this — 535 parts, 45 lots, 30 shapes, **86 of one
  brick**: the right size, the wrong texture, and nothing said so.

  **A multiple of the median read like a tolerance and was not one.** Firing
  below 0.6x the median shapes and above 2x the median repeat fires on **29-34%
  of real LEGO sets**, measured against the same inventories the norms come from.
  A third of real sets told they are repetitive is noise, and this project holds
  advice to the standard that it must not fire on good models. The bands carry
  their tails now — 5th percentile for lots, shapes and colours, 95th for the
  largest lot — which is **9.1% of real models overall, worst band 10.2%**. The
  medians are still what gets *reported*, because "a real set this size has
  about 123 shapes" is the useful sentence; the percentile only decides whether
  to speak.

  **A tail is only as good as the population under it.** The norms were first
  measured over every set, and the thinnest sets of every size are not models:
  mosaics, LEGO Art, DOTS, bulk tubs, education packs, Duplo. Over 1,800 parts
  that put the 5th percentile at **21 shapes** (2,305 tiles in two shapes is a
  "set") and the 95th of one piece at 660, so a 1,828-part castle with 30 shapes
  and 320 of one brick was told nothing at all. `rebrickable.NOT_A_MODEL` leaves
  them out by theme, and `NAMED_NOT_A_MODEL` by name for the ones filed
  elsewhere (Creator bulk tubs, a film character's mosaic). Decided by what the
  product is, never by how varied it is, or the cut would move the threshold it
  sets. Over 1,800 parts it is **134 shapes** now, median 262, and 511 of one.
  The station's 30 shapes moved from the 4.2nd percentile to the 1.1st.

  2nd/98th would be rarer and was rejected on evidence, measured with the
  mosaics in: it missed the fire station on both counts. `variety_probe` asserts both directions, including that a model with a
  real set's median spread is left alone and so is one using 58 of a piece, which
  nine real sets in ten are under and the old rule called repetitive at 48.

  Advice, never a fault. Beware testing it with a control that is itself thin:
  mine had 20 shapes, the check correctly flagged it, and for a moment that
  looked like a false positive.
- **What a design places is a part made now.** `PartLibrary.current` follows
  the redirects and then, for a part LDraw keeps only for old files (an alias
  "=", an obsolete mould, a "~" part: `is_stale`), gives the current part of
  the same mesh, or of its family (`family_of`, the name up to "with") in the
  same box (not a print, whose twin is only its own drawing), agreeing on what
  it is with and without, closest named, then most used: 3660, which walk180's session
  knew from memory, was LDraw's obsolete 3660a nineteen times on a tug's
  parts list; it is 3660c. The designer maps every new placement through it
  (`Assistant._current_parts`, at the end of `_read_model` and `_edit`, and
  says so once a part), `search_parts` and the palette's search leave such a
  part out (`superseded`; the palette's Obsolete category still shows it),
  and find_parts_like and how_real_sets_build_this name the current part; a
  superseded number typed into search_parts brings its twin first
  (`search_probe`), and `print_search_probe`'s names-alone index leaves the
  same parts out as the bin. Built once, about 0.4 s. A
  file opened keeps its numbers. `part_choice_probe -- stale` scans every
  number (758 such parts have a current twin): base 778 placed as a part
  kept for old files, 23 offered by search_parts, 25 shown by the palette; the
  branch 0, 0, 0. A part LDraw draws in one colour only (its "physical
  colour" parts, `PartInfo.fixed_colour`: 303923, "~_Slope Brick 45 2 x 2
  Blue") is the part it draws, in that colour (`current_colour`, from
  `_index_colours`: the part of the same box and triangles that takes any
  colour, current and plain first, named most alike): 3039 in blue, for a
  design (its colour set to that one, and said) and for a file opened
  (`ModelStore._open_into`), which otherwise keeps its numbers.
  `part_choice_probe -- colours`: 206 of the 208 placed so, the two left with
  no part made now drawn as they are; a design's 303923 in red and a file's
  are 3039 in blue; search_parts offers none. Before, none had its colour,
  and 67 were placed as their part in the colour a design gave (241901, a
  white 3 x 6 plate, as 2419 in red).
- **Which moulding a bare part number means is settled by LDraw's redirects, not
  by the alphabet.** `3023a` and `3023b` are both "Plate 1 x 2" and both reduce
  to `3023`, so whichever was indexed first took the number — and every `3023`
  element went to `3023a`, while every model in the repo uses `3023b`. LDraw
  itself answers it: part `3023` is "~Moved to 3023b". Following the redirect
  took element coverage on the pairs real models use from 94% to 97%.

- **The element join is confirmed by LEGO's own numbering, independently.** An
  old-style element number is the design number with a two-digit colour
  appended, so `3001` + red is `300121` and `3024` + black is `302426`. Of the
  3,846 pairs whose element is six digits or fewer, **98.4%** begin with the
  design number — a check the join never consulted. Do not run that test over
  7-digit elements: those are sequential and carry no design number, and
  including them scores 14% and looks like a broken join.

- **The connector table is classified from the primitives' own descriptions,
  not their filenames.** `axlehol8` is "Technic Axle Perimeter" — part of a solid
  axle — and registering it as a hole made every Technic axle report an
  `axle_hole`: part 3705, a plain Axle 4, came out as `{axle: 2, axle_hole: 1}`.
  `axl2hol8` is "Technic Axle Hole Reduced Perimeter" and really is a hole. One
  letter apart, opposite meanings. Nine registered names (`bar`, `bar2`,
  `barhole`, `ball`, `balljnt`, `socket`, `socket2`, `axle2`, `npeghol1`) did not
  exist in the library at all, so BAR, BALL and SOCKET had never been detected
  once. There is still **no bar primitive**: a bar is a plain 3.2 mm cylinder, so
  finding one needs a radius measured, not a filename read — which is why a clip
  has nothing to grip.

  **Measuring the radius was tried and is not enough.** Part 30374, "Bar 4L
  Lightsaber Blade", is a single `4-4cyli` scaled `(4, 80, 4)`, so the obvious
  test is a cylinder whose two perpendicular scales are ~4 LDU with a third at
  least half a stud long. Measured against the 570 parts whose name says bar,
  antenna or rod, that finds 45% of them — and fires on **19.8% of a 400-part
  sample of everything else**: minifig arms, torsos and heads are full of
  radius-4 cylinders. A false bar lets a clip hold thin air, which is the
  direction that costs something, so radius alone cannot ship. What it needs is
  some test that the cylinder is *exposed* with a free end, which is geometry
  work rather than a tree walk.

  **Nor by shape and name.** Of the 313 parts whose name says bar, antenna or
  rod, only **six** are thin rods by their bounding box — 104, 30374, 87994 and
  three others. The rest are a bar with something on the end: a hilt, a flag, a
  tool. So the bar has to be found *inside* the part, which is the same geometry
  problem again.

  **Nor by the shape of its collision boxes.** The boxes are the
  stud-removed cover, so a bar ought to stand out: part 30374 is two of them,
  4x40x2 and 2x40x4, a cross approximating a 4 LDU rod. Testing for a box thin
  in two axes and long in the third finds 63% of bar-named parts and fires on
  **39.3%** of everything else — worse than the radius test, because the greedy
  cover produces thin slivers for any part that is not boxy. Four approaches
  have now been measured and rejected; what would work is a curated list of
  which parts are bars, gated by name, using the rod-shaped box for the
  position. That is semantic knowledge, not geometry.

  **What did work (2026-10-10): the winding, and a pair.** A cylinder's BFC
  winding says which side is plastic, so `connectivity.rounds` records a
  *shaft* (facing out) or a *bore* (facing in, after INVERTNEXT) with its radius
  and length, merged end to end along each axis — a clip's eye is a radius-4
  bore in every clip primitive, a hollow stud's is 4, a pin's barrel is 6 with a
  bore of 4 inside it. A minifig arm's radius-4 cylinder is still a shaft, and
  that is no longer the danger it was, because nothing is forgiven for a shaft
  alone: a joint is a shaft in a *coaxial* bore of another part, the same size
  to 1 LDU, and only the overlap inside that bore is forgiven. A clip on thin
  air has no shaft in it; a clip on a minifig arm is a clip on a 3.2 mm round,
  which it really does grip. Tubes and studs give bores only where they carry
  on a bore of the part itself (3062b is bored right through, 3709b's holes run
  down through the tubes under them), which keeps every plain brick out: 3001,
  3003, 3005, 3020, 3024 and 3068b get nothing. 17,539 of 29,591 parts do, so
  the whole catalogue has to be rebuilt to carry them (`pipeline.md`).

  **And clips cannot be inverted to avoid it.** The tempting shortcut is to skip
  bars and say a clip grips whatever occupies its jaw. Two things stop it: the
  bar part itself has no connectors at all, so there is no pair to confirm; and a
  clip's own position is often inside its own plastic (4085b, Plate 1x1 with Clip
  Vertical), so a gripped bar *overlaps* the clip rather than sitting in free
  space. Forgiving that overlap would need a far looser rule than the pin's —
  which demands collinear axes within 4 LDU — and a loose rule here would hide
  real faults. 213 parts carry a clip and none of them can grip anything yet.

- **Hinges have no connector kind of their own, and need none.** The old
  hinges — 3937/3938, 4213/4214, the ones `models/car.ldr` is built with — are
  drawn from plain cylinders and boxes, so there is nothing to detect by name,
  and that is exactly what the shafts and bores read: a hinge brick's top
  (3830) has a radius-6 pin and its base (3831) a radius-6 eye on the same axis
  through both origins, a hinge plate's (2430 in 2429) 3.9 in 4, and 3938's
  two radius-4 pins sit in 3937's two eyes. 4213/4214, the car roof, are
  fingers on both halves (shafts, no bore), so they make no joint. The
  click-lock family's primitives (`clh1`..`clh15`, `arm1`..`arm3`,
  `4-4crh1/2`) are still unread; 78 parts use them.

- **`npeghol*` is subtracted geometry, not a connector.** "Technic Peg Hole
  Negative" marks where material is *missing*, which is not the same as where a
  pin can go: Technic Beam 2 draws one at its waist, between its two real holes,
  so the beam reported three holes and the middle one took no pin.

- **Unknown is not "never made", and the whole feature turns on that.** The join
  knows 6,427 of the 8,591 plain parts, and 700 of those have a *short* list:
  made in one of 61 Rebrickable colours LDraw has no counterpart for (HO,
  vintage 1949, Clikits, Duplo-only, two-tone Bionicle masks), or known only from
  element numbers with no set inventory behind it. `never_made_in()` refuses to
  answer for an empty list *or* a `colors_partial` one — read `colors` directly
  only if you have handled both.

- **The colour join was the reason the checker was silent.** Matching by name
  then exact RGB left Dark Purple unnamed — Rebrickable's 85, 17,000 parts — so
  **49 of the 50 most used parts were short** and `_never_made` said nothing
  about them. Rebrickable numbered its colours by LDraw's codes, and LDraw has
  since *renamed* some (85 Dark_Purple is Medium_Lilac now: the id stands) and
  *moved* others (Rebrickable's 41 "Trans-Light Blue" is LDraw 43: the name
  wins). `colour_matches()` tells them apart by whether the name belongs to
  another code today, adds LEGO's names from LDConfig (2026's "Blue Violet" is
  LDraw 431, not 89; "Vibrant Yellow" is 368), narrows an RGB shared by several
  codes by finish (Pearl Titanium is 316, not a paint), and assigns one code per
  colour, two kinds of evidence beating one. Now 212 of 273 Rebrickable colours
  join, **1 of the top 50 parts is short** (top 200: 6, was 141), and 41,376
  element pairs survive (40,474). Checked against LDraw's model repository, 276
  real sets drawn in LDraw codes: the join agrees with how they are coloured for
  55 of the 56 colours they pair — the one is Flat Silver, which old models draw
  as 179 and LDConfig now names 315.

  **Measured on those real sets, `_never_made` fires on 1.3% of the lots it can
  judge (606 of 46,881), against 4.0% before** — and every one is false, since a
  real set has every part it is drawn in. What is left is mostly not colour: old
  models' codes (179, 41, 83) and mould variants the part join cannot separate
  (3665a). Still too often for a fault; it stays advice. Matching the leftover
  colours by swatch was tried and measured earlier: nearest-ΔE picks Dark Blue
  Violet for Dark Purple and merges "Pearl Sand Blue" into "Sand Blue". It does
  not work; do not retry it without new data.

- **A check against a colour the part was made in proves nothing.** The first
  version of this probe asserted `not 3001.never_made_in(484)` — but 3001 *was*
  made in Dark Orange, so deleting the `colors_partial` guard altogether still
  passed. It uses Light Violet (20) now, which is genuinely absent from 3001's
  short list. Mutate the guard away and watch that check fail before trusting it.

- **The loose part-number match is name-gated, and was wrong without it.**
  Stripping a mould suffix matched LDraw `6216c` (an electric motor) to
  Rebrickable `6216` (a curved brick), `3240a` to a Duplo door, and LDraw's
  zero-padded sticker `004324b` to part `4324`, a Fabuland rake. It now requires
  the two names to share a four-letter word, which took the disagreement rate
  from 2.5% to 0 across 182 matches.

- **Rebrickable's grant allows one download a day.** `tools/fetch_data.sh --force`
  deliberately will not re-fetch their tables if the local copy is less than a
  day old. That is a licence condition; see `docs/ATTRIBUTION.md`, which also
  carries the required "Catalog data: Rebrickable" credit and where it must show.

- **The catalogue load is the 15–20s start-up.** Every probe pays it.
- `fetch` covers the case that broke: two callers asking for the same part, one of
  them never being told it arrived.
- `fetch_retry` takes about 3 minutes: 20 s the last part's three waits,
  about 45 s the autosave's part (two opens, each autosave's 2.5 s, a reopen
  while 3001 waits 20 s), and about 50 s the deployment's question
  (`Deployment`, /api/account on the probe's host: an ask held past its 20 s
  timeout then asked again, and a 503 every time's three waits). Its
  host is in the probe (a TCPServer polled each frame), so it needs no network;
  it waits for the deployment's answer first, which would otherwise point the
  library back at the real bucket. `fetch_retry_flow` reads the status bar
  every quarter second: what it says clears itself after four.
- The web build cannot read `assets/generated/parts` — it carries a smaller pack
  chosen by `tools/web_pack.py` and fetches the rest. A part that works on the
  desktop can still be missing on the web; `remote_probe` is what checks the path
  the web build uses.
