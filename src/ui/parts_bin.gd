## The parts bin: find a part among 24,731 and pick it up.
##
## The catalogue has always been searchable; until now nothing in the app
## could reach it, and building meant cycling a hard-coded list with the
## bracket keys. This is the panel that makes the library usable.
##
## Three things it has to get right:
##
## Search that answers as you type. 24,731 short strings is small enough
## to scan outright — no index, no fuzzy matching to be surprised by —
## but only if the scan is debounced and capped, so a held-down key does
## not run it once per character over the whole library.
##
## Previews that do not stall the frame. Rendered live by
## [PartThumbnails], a couple per frame, and only for the rows actually
## on screen; each cell is a [ThumbTile], which stands in for its picture
## until it comes.
##
## Ordering that puts the likely part first. Someone searching "brick
## 2 x 4" wants 3001, not the four hundred printed variants of it.
class_name PartsBin
extends PanelContainer

const COLUMNS := 4
## How many cells are added at a time. The grid grows as it is scrolled
## rather than stopping at a cap: a fixed limit meant that of 28,319
## parts you could only ever see the first 240, with nothing to say the
## rest existed.
const PAGE := 120
## Milliseconds of quiet before a search runs. Long enough that typing a
## word is one search, short enough to feel immediate.
const SEARCH_DEBOUNCE := 160

## Categories that lead, when the catalogue has them. Everything else is
## added after these, ordered by how many parts it holds.
##
## A hand-written list was the bug: thirteen names covered 12,438 of
## 28,319 parts and the other 15,881 were unreachable by any button,
## because LDraw has 94 categories and most of them are not things you
## would think to type.
const LEADING: Array[String] = [
	"My prints", "My stickers", "Custom", "Brick", "Plate", "Tile", "Slope", "Technic", "Wedge", "Panel",
	"Bracket", "Arch", "Hinge", "Plant", "Animal", "Minifig",
]

## Categories kept out of the default view. They are still searchable and
## still have their own button; they are simply not what anyone means by
## "show me the parts".
const BURIED: Array[String] = ["Sticker", "Obsolete", "Moved"]

## The palette: every colour, grouped by what kind of plastic it is.
##
## It was a fixed row of 44, chosen once, which held five colours LEGO
## stopped making (Light Grey, Brown, Purple...) and left out Medium
## Azure, Dark Orange, Coral and the rest of what sets are built in
## today — 278 colours could only be had through a model that already
## used them. Now every one is here. What a set is built in now comes
## first; the rest are a press away, not gone.
##
## Each group is [title, the finishes in it, transparent or not or
## either (null)].
const GROUPS: Array = [
	["Solid", [PartLibrary.BrickColor.Finish.PLASTIC,
		PartLibrary.BrickColor.Finish.FLUORESCENT], false],
	["Transparent", [PartLibrary.BrickColor.Finish.PLASTIC,
		PartLibrary.BrickColor.Finish.FLUORESCENT,
		PartLibrary.BrickColor.Finish.MILKY], true],
	["Chrome, metallic, pearl", [PartLibrary.BrickColor.Finish.CHROME,
		PartLibrary.BrickColor.Finish.METAL,
		PartLibrary.BrickColor.Finish.PEARL], null],
	["Glitter, opal, speckle, glow, rubber, fabric", [
		PartLibrary.BrickColor.Finish.GLITTER, PartLibrary.BrickColor.Finish.OPAL,
		PartLibrary.BrickColor.Finish.SPECKLE, PartLibrary.BrickColor.Finish.GLOW,
		PartLibrary.BrickColor.Finish.RUBBER, PartLibrary.BrickColor.Finish.FABRIC], null],
]
## LDraw's two meta-colours, "the colour of whatever contains me" and
## "the edge colour". Not plastic; choosing one would be a bug.
const NOT_A_COLOUR: Array[int] = [16, 24]

var library: PartLibrary
var thumbnails: PartThumbnails
## Asked how a part's cells lie, to read a worked construction (_reader).
var builder: Builder
## How much bigger than on a desktop the bin is drawn, set before it is
## shown: a phone's parts sheet (PhoneShell) draws it in points.
var zoom: float = 1.0
## The least a button in it is tall, in the window's units: a fingertip,
## on a phone. Nothing on a desktop.
var least: float = 0.0
## On a phone: a finger dragged on the grid scrolls it, as everything on
## a phone scrolls, rather than carrying the part out onto the model.
var by_finger: bool = false

## How many parts can be placed at all, and how many of those the default
## view sets aside. Both are shown, because a bin that says "20,581" to
## someone who was told there are 29,479 parts looks broken.
var _offerable: int = 0
var _set_aside: int = 0

var _search: LineEdit
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _palette: VBoxContainer
var _palette_scroll: ScrollContainer
var _all_colours: Button
## A colour by its name or number: the palette shows what matches.
var _colour_find: LineEdit
## The colour Enter would take there, or -1 (brickworksState.colour_first).
var _found_first: int = -1
var _colour_note: Label
var _swatches: Dictionary = {}         ## int code -> Swatch
var _category_row: FlowContainer
var _category_scroll: ScrollContainer

var _category: String = "All"
var _make_button: Button
var _print_button: Button
var _stickers_button: Button
var _results: Array[PartLibrary.PartInfo] = []
## The tiles, in order: the results with each print, sticker and assembly of
## a part that is among them folded under it (_fold), and those of the parts
## opened (_open) after it.
var _display: Array[PartLibrary.PartInfo] = []
## Part id -> the prints, stickers and assemblies of it folded under its tile.
var _folds: Dictionary = {}
## Part id -> true, for each part whose folded tiles are shown.
var _open: Dictionary = {}
var _folded: int = 0
var _listing: int = 0
## The last results _find marked as listed, and under which listing.
var _listed: Array[PartLibrary.PartInfo] = []
var _listed_as: int = 0
var _shown: int = 0
var _categories: Array[String] = []
var _cells: Dictionary = {}            ## part id -> ThumbTile
var _sight: ThumbTile.Sight
var _selected_part: String = ""
var _selected_color: int = 4
var _search_at: int = 0
var _pending: bool = false

signal part_chosen(part_id: String)
## A part was kept in Favourites, or taken out.
signal part_favourited(part_id: String, kept: bool)
signal color_chosen(color_code: int)
## A swatch clicked by hand, once the colour in hand is that colour: what
## is selected takes it too (Main._on_swatch_pressed). The eyedropper and
## the bracket keys choose a colour without one.
signal swatch_pressed(color_code: int)
## "Make a part" was pressed: the element maker, for a part that is not
## in the library yet.
signal make_wanted
## "Print…" was pressed: the print designer, for the part in hand; and
## "Stickers…": the model's sticker sheet (PrintStudio).
signal print_wanted
signal stickers_wanted
## A worked construction chosen under Techniques, to hold whole: its parts
## as Carry holds them, and its name.
signal construction_chosen(parts: Array, name: String)
## A part or a construction chosen from the keyboard (Tab to its tile, then
## Return): the keys go to the model, to aim it and put it down.
signal chose_by_keyboard


## [param units] of the desktop's bin, drawn at its zoom.
func _z(units: float) -> float:
	return units * zoom


## A colour chosen as a swatch of the palette is pressed: the phone's own
## swatches (PhoneShell) take it through here, so it does what a press does.
func choose_colour(code: int) -> void:
	_on_colour(code)
	swatch_pressed.emit(code)


func _ready() -> void:
	custom_minimum_size = Vector2(_z(336), 0)
	_build()
	set_process(true)


func _build() -> void:
	# An opaque backing, or the model shows through the text. Slightly
	# translucent so the viewport still reads as continuous behind it.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	backing.content_margin_left = _z(10)
	backing.content_margin_right = _z(10)
	backing.content_margin_top = _z(10)
	backing.content_margin_bottom = _z(10)
	add_theme_stylebox_override("panel", backing)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(_z(8)))
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "Parts"
	title.add_theme_font_size_override("font_size", ceili(_z(16)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var make := Button.new()
	_make_button = make
	make.text = "Make a part…"
	make.tooltip_text = ("A brick, plate, tile, slope or round part of any "
		+ "size, or a part here resized — it joins the bin under Custom")
	FocusGuard.by_keyboard(make)
	make.add_theme_font_size_override("font_size", ceili(_z(12)))
	make.custom_minimum_size = Vector2(least, least)
	make.pressed.connect(func() -> void: make_wanted.emit())
	head.add_child(make)
	_print_button = Button.new()
	_print_button.text = "Print…"
	_print_button.tooltip_text = ("Print a picture or a drawing on the part in hand — a tile, a "
		+ "slope, any face — as a part of its own, under My prints; with one part picked out in "
		+ "the model (Shift-click), on that part, where it stands")
	FocusGuard.by_keyboard(_print_button)
	_print_button.add_theme_font_size_override("font_size", ceili(_z(12)))
	_print_button.custom_minimum_size = Vector2(least, least)
	_print_button.pressed.connect(func() -> void: print_wanted.emit())
	head.add_child(_print_button)
	_stickers_button = Button.new()
	_stickers_button.text = "Stickers…"
	_stickers_button.tooltip_text = ("The model's stickers: a new one for any face, the sheet "
		+ "to print at true size")
	FocusGuard.by_keyboard(_stickers_button)
	_stickers_button.add_theme_font_size_override("font_size", ceili(_z(12)))
	_stickers_button.custom_minimum_size = Vector2(least, least)
	_stickers_button.pressed.connect(func() -> void: stickers_wanted.emit())
	head.add_child(_stickers_button)

	_search = LineEdit.new()
	# Filled in once the catalogue is loaded; the count differs between
	# the desktop build and the web pack.
	_search.placeholder_text = "Search parts…"
	_search.accessibility_name = "Search parts"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_typed)
	if zoom != 1.0:
		_search.add_theme_font_size_override("font_size", ceili(_z(14)))
	_search.custom_minimum_size.y = least
	root.add_child(_search)
	_add_photo_button()

	# Built from the catalogue once it is loaded, not from a fixed list.
	var category_scroll := ScrollContainer.new()
	category_scroll.custom_minimum_size = Vector2(0, _z(58))
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(category_scroll)
	_category_scroll = category_scroll

	_category_row = FlowContainer.new()
	_category_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_row.add_theme_constant_override("h_separation", int(_z(4)))
	_category_row.add_theme_constant_override("v_separation", int(_z(4)))
	category_scroll.add_child(_category_row)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A row of parts at the least, whatever else the column holds: the
	# model tree and the properties open give back their room before the
	# parts do (PanelStack.heights).
	_scroll.custom_minimum_size.y = _z(PARTS_LEAST)
	root.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(_z(4)))
	_grid.add_theme_constant_override("v_separation", int(_z(4)))
	_scroll.add_child(_grid)
	_sight = ThumbTile.Sight.new(_scroll, _grid)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", ceili(_z(12)))
	_status.modulate = Color(1, 1, 1, 0.72)
	# Two lines when it needs them. The line has to carry where the rest
	# of the catalogue went, and truncating that leaves the bin looking
	# short of parts with no explanation — the thing the line is for.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	# The colours are a section of their own at the foot of the column
	# (Main puts it there), as Studio keeps its colour palette under its
	# parts: the parts grid above takes whatever room there is, and what
	# changes height there — the properties opening on a selection, the
	# model tree — moves the grid's foot and never the palette.
	colours = PanelContainer.new()
	colours.name = "Colours"
	colours.mouse_filter = Control.MOUSE_FILTER_STOP
	colours.add_theme_stylebox_override("panel", PanelStack.section_style())
	var colour_box := VBoxContainer.new()
	colour_box.add_theme_constant_override("separation", 6)
	colours.add_child(colour_box)
	var colour_head := HBoxContainer.new()
	colour_box.add_child(colour_head)
	var colour_title := Label.new()
	colour_title.text = "Colour"
	colour_title.add_theme_font_size_override("font_size", 13)
	colour_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colour_head.add_child(colour_title)
	# A colour by its name or number, as Studio's colour menu filters as you
	# type. The old greys (7 and 8), all over older sets, show only after
	# All and look like the bluish greys beside them: a builder building
	# from a booklet put three parts of eight in the wrong one (the CAD task
	# test, 2026-10-16). Enter takes the first; Shift-C comes here.
	_colour_find = LineEdit.new()
	_colour_find.placeholder_text = "Name or number"
	_colour_find.accessibility_name = "Find a colour by name or number"
	_colour_find.tooltip_text = ("A colour by its name or number, every colour there is: "
		+ "Enter takes the first (Shift-C)")
	_colour_find.clear_button_enabled = true
	_colour_find.custom_minimum_size = Vector2(132, 0)
	_colour_find.add_theme_font_size_override("font_size", 12)
	_colour_find.text_changed.connect(func(_text: String) -> void: _build_swatches())
	_colour_find.text_submitted.connect(_take_found_colour)
	colour_head.add_child(_colour_find)
	_all_colours = Button.new()
	_all_colours.toggle_mode = true
	_all_colours.flat = true
	FocusGuard.by_keyboard(_all_colours)
	_all_colours.add_theme_font_size_override("font_size", 12)
	_all_colours.toggled.connect(func(_on: bool) -> void: _build_swatches())
	colour_head.add_child(_all_colours)

	# Scrolls rather than grows: three hundred colours shown at once would
	# push the parts grid off the bottom of the panel. Sized to what it
	# holds where there is room (_fit_palette).
	_palette_scroll = ScrollContainer.new()
	_palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette_scroll.custom_minimum_size = Vector2(0, PALETTE_FLOOR)
	colour_box.add_child(_palette_scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette.add_theme_constant_override("separation", 2)
	_palette_scroll.add_child(_palette)
	_palette.minimum_size_changed.connect(_fit_palette)
	resized.connect(_fit_palette)

	# Always two lines tall, whatever it says: it was one line for a colour
	# and two for a part, and choosing a part moved the palette up 19 px
	# under the pointer, so the next colour clicked was a row off
	# (brickworks.diy, 2026-10-12). What does not fit is on its tooltip.
	_colour_note = Label.new()
	_colour_note.add_theme_font_size_override("font_size", 12)
	_colour_note.modulate = Color(1, 1, 1, 0.78)
	_colour_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_colour_note.max_lines_visible = NOTE_LINES
	_colour_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_colour_note.mouse_filter = Control.MOUSE_FILTER_PASS
	colour_box.add_child(_colour_note)
	var font: Font = _colour_note.get_theme_font("font")
	_colour_note.custom_minimum_size.y = ceilf(font.get_height(12) * NOTE_LINES
		+ float(_colour_note.get_theme_constant("line_spacing")) * (NOTE_LINES - 1))


## Fill in once the library is available.
func populate() -> void:
	if library == null:
		return
	# The catalogue holds 1,160 redirect stubs — "~Moved to 3665" — that
	# forward to the part that replaced them. Counting them here promised
	# more parts than the bin could ever show, which is one of the two
	# reasons the bin looked like it was hiding things.
	var offerable: int = 0
	for id: String in library.ids():
		var entry: PartLibrary.PartInfo = library.parts[id]
		if not entry.is_redirect() and entry.reachable:
			offerable += 1
	_offerable = offerable
	library.prepare_search()
	_search.placeholder_text = "Search %s parts…" % _comma(offerable)
	_build_categories()
	_build_swatches()
	_run_search("")


## The category buttons, taken from what the catalogue actually holds.
func _build_categories() -> void:
	var counts: Dictionary = {}
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect() or not info.reachable:
			continue
		var category: String = info.category.strip_edges()
		if category.is_empty():
			continue
		counts[category] = int(counts.get(category, 0)) + 1

	var rest: Array[String] = []
	for category: String in counts:
		if category in LEADING:
			continue
		rest.append(category)
	# Biggest first, so the useful ones are near the front.
	rest.sort_custom(func(a: String, b: String) -> bool:
		return int(counts[a]) > int(counts[b]))

	# The parts reached for lately and the ones kept, beside All: the bin
	# is searched once per part and then wanted again and again. And the
	# assistant's worked constructions, each with why it works.
	_categories = ["All", RECENT, FAVOURITES, TECHNIQUES]
	for category: String in LEADING:
		if counts.has(category):
			_categories.append(category)
	for category: String in rest:
		_categories.append(category)

	for child: Node in _category_row.get_children():
		child.queue_free()
	for category: String in _categories:
		var button := Button.new()
		var total: int = int(counts.get(category, 0))
		button.text = category if category == "All" else "%s %d" % [
			category, total]
		button.tooltip_text = category
		button.set_meta("category", category)
		if category == RECENT or category == FAVOURITES:
			button.text = _shelf_label(category)
			button.set_meta("shelf", category)
			button.tooltip_text = ("The parts you chose lately, newest first"
				if category == RECENT
				else "The parts you keep: right-click any part to add it or take it out")
		if category == TECHNIQUES:
			button.text = "%s %d" % [TECHNIQUES, Techniques.all().size()]
			button.tooltip_text = ("Worked constructions, each with why it works: choose one "
				+ "to hold it whole, R turns it, a click puts it down")
		button.toggle_mode = true
		button.button_pressed = category == _category
		FocusGuard.by_keyboard(button)
		button.add_theme_font_size_override("font_size", ceili(_z(12)))
		button.custom_minimum_size = Vector2(least, least)
		button.pressed.connect(_on_category.bind(category))
		_category_row.add_child(button)
	# Whole rows and the scroll bar to say there are more (_fit_palette).
	# A fixed 58 showed the top few units of a third row's buttons.
	if _category_row.get_child_count() > 0:
		var last: Control = _category_row.get_child(_category_row.get_child_count() - 1)
		_chip_tall = last.get_combined_minimum_size().y
	_fit_palette()


func _build_swatches() -> void:
	for child: Node in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	_swatches.clear()
	var everything: bool = _all_colours.button_pressed
	var asked: String = _colour_find.text.strip_edges() if _colour_find != null else ""
	_found_first = -1
	if not asked.is_empty():
		_build_found(asked)
		return

	var current: int = 0
	var total: int = 0
	for group: Array in GROUPS:
		var now: Array[PartLibrary.BrickColor] = []
		var rest: Array[PartLibrary.BrickColor] = []
		for code: int in library.colors:
			var color: PartLibrary.BrickColor = library.colors[code]
			if not _in_group(color, group):
				continue
			total += 1
			if library.is_current(code):
				now.append(color)
				current += 1
			else:
				rest.append(color)
		now.sort_custom(_in_palette_order)
		rest.sort_custom(_in_palette_order)
		var showing_rest: bool = everything and not rest.is_empty()
		if now.is_empty() and not showing_rest:
			continue

		var title := Label.new()
		title.text = group[0]
		title.add_theme_font_size_override("font_size", 11)
		title.modulate = Color(1, 1, 1, 0.7)
		_palette.add_child(title)
		if not now.is_empty():
			_palette.add_child(_flow_of(now))
		if showing_rest:
			if not now.is_empty():
				var line := HSeparator.new()
				line.modulate = Color(1, 1, 1, 0.35)
				_palette.add_child(line)
			_palette.add_child(_flow_of(rest))

	_all_colours.text = "Current only" if everything else "All %d" % total
	if library.recent_since > 0:
		_all_colours.tooltip_text = (
			"Only the %d colours in sets since %d" % [current, library.recent_since]
			if everything else
			"Also the %d colours not in a set since %d, or in no set inventory"
				% [total - current, library.recent_since])
	_mark_swatches()


## The palette while a colour is asked for by name or number: the colours
## that answer, best first, from every colour there is.
func _build_found(asked: String) -> void:
	var found: Array[PartLibrary.BrickColor] = colours_named(library, asked)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1, 1, 1, 0.7)
	# The first by name, so a person types only until it is the one wanted.
	title.text = "No colour is called that" if found.is_empty() \
		else "%s (%d) first of %d: Enter takes it" % [found[0].name, found[0].code,
			found.size()]
	_found_first = -1 if found.is_empty() else found[0].code
	_palette.add_child(title)
	if not found.is_empty():
		_palette.add_child(_flow_of(found))
	_mark_swatches()


## Every colour whose name or number answers [param asked], best first: its
## number exactly, its name exactly (LDraw's or LEGO's), its name beginning
## so, every word in it, then numbers that begin so. Gray is grey, as
## BrickLink and Rebrickable spell it; within a rank the most used first.
static func colours_named(library: PartLibrary, asked: String) -> Array[PartLibrary.BrickColor]:
	var said: String = _colour_words(asked)
	var ranked: Array = []
	if said.is_empty() or library == null:
		return []
	for code: int in library.colors:
		var color: PartLibrary.BrickColor = library.colors[code]
		if code in NOT_A_COLOUR or not _in_any_group(color):
			continue
		var rank: int = _colour_rank(color, said)
		if rank >= 0:
			ranked.append([rank, color])
	ranked.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		var x: PartLibrary.BrickColor = a[1]
		var y: PartLibrary.BrickColor = b[1]
		if x.sets != y.sets:
			return x.sets > y.sets
		return x.code < y.code)
	var out: Array[PartLibrary.BrickColor] = []
	for pair: Array in ranked:
		out.append(pair[1])
	return out


static func _colour_words(text: String) -> String:
	var words: String = text.to_lower().replace("_", " ").replace("-", " ").replace("gray", "grey")
	while words.contains("  "):
		words = words.replace("  ", " ")
	return words.strip_edges()


## How well [param color] answers [param said] (from _colour_words): 0 its
## number, 1 its LDraw name, 2 LEGO's, 3 a name beginning so, 4 every word
## in a name, 5 a number beginning so; -1 not at all.
static func _colour_rank(color: PartLibrary.BrickColor, said: String) -> int:
	if said.is_valid_int():
		if int(said) == color.code:
			return 0
		return 5 if str(color.code).begins_with(said) else -1
	var names: Array[String] = [_colour_words(color.name), _colour_words(color.lego_name)]
	if names[0] == said:
		return 1
	if names[1] == said:
		return 2
	for name: String in names:
		if not name.is_empty() and name.begins_with(said):
			return 3
	for name: String in names:
		var every: bool = not name.is_empty()
		for word: String in said.split(" ", false):
			if not (" %s " % name).contains(" %s" % word):
				every = false
				break
		if every:
			return 4
	return -1


static func _in_any_group(color: PartLibrary.BrickColor) -> bool:
	for group: Array in GROUPS:
		if (group[1] as Array).has(color.drawn_as):
			var wanted: Variant = group[2]
			if wanted == null or bool(wanted) == color.is_transparent():
				return true
	return false


## Enter in the colour's name: the first that answers, in hand, as a click
## on its swatch takes it, and the palette back as it was with that one
## showing.
func _take_found_colour(text: String) -> void:
	var found: Array[PartLibrary.BrickColor] = colours_named(library, text)
	if found.is_empty():
		return
	var code: int = found[0].code
	_colour_find.text = ""
	_build_swatches()
	_on_colour(code)
	swatch_pressed.emit(code)


## The parts on the first tiles, in order: what a person reads off the top
## of the list (brickworksState.found, for tools/web/cad_task_flow.mjs).
func first_found(most: int = 6) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in mini(most, _display.size()):
		out.append(_display[n].id)
	return out


## The colour Enter in the colour's name would take, or -1.
func colour_first() -> int:
	return _found_first


## Shift-C: the colour's name, to be typed.
func focus_colour_find() -> void:
	if _colour_find == null:
		return
	_colour_find.grab_focus()
	_colour_find.select_all()


## The palette's window, and the rows of categories: sized by the column
## they are in, which only the window changes, so that nothing a person
## does while building moves them.
##
## The palette is the whole of what it holds where that fits in
## PALETTE_SHARE of the column, and otherwise a scrolling window onto it.
## It was a fixed 168, and the colours a set is built in today run to
## about 195: the last group's title sat cut in half under the colour's
## name at the foot of the panel, on the first screen anyone sees. And on
## a phone held sideways that 168 and the rest of the panel took all of
## its height: the parts list was a sliver with no part in it.
##
## It was sized by the parts bin it sat in, and the bin by what was under
## it: at 1440 x 900 the parts grid had room for two rows (brickworks.diy,
## 2026-10-12).
func _fit_palette() -> void:
	if _palette == null or _palette_scroll == null:
		return
	var tall_column: float = column.size.y if column != null else size.y
	# Two rows of categories, or one in a column too short to spare them.
	if _chip_tall > 0.0:
		var rows: int = 2 if tall_column >= SHORT else 1
		_category_scroll.custom_minimum_size.y = _chip_tall * rows \
			+ float(_category_row.get_theme_constant("v_separation")) * (rows - 1)
	var wants: float = _palette.get_combined_minimum_size().y
	var tall: float = clampf(minf(wants, tall_column * PALETTE_SHARE), PALETTE_FLOOR,
		maxf(wants, PALETTE_FLOOR))
	tall = roundf(tall)
	if absf(_palette_scroll.custom_minimum_size.y - tall) > 0.5:
		_palette_scroll.custom_minimum_size.y = tall


## The column the bin and the colours are sections of (Main): their sizes
## are the column's share, not the bin's.
var column: Control:
	set(to):
		column = to
		if column != null:
			column.resized.connect(_fit_palette)
			_fit_palette.call_deferred()
## The colours: a section of the column of their own, under the model tree
## and the properties (Main).
var colours: PanelContainer

## The palette's share of the column's height: four rows and more of the
## colours a set is built in today at 1440 x 900, the rest a scroll away.
const PALETTE_SHARE := 0.14
## A row and a half of colours and the title over them.
const PALETTE_FLOOR := 48.0
## A row of parts: a cell and the space under it.
const PARTS_LEAST := 88.0
## A column shorter than this shows one row of categories, not two.
const SHORT := 700.0
var _chip_tall: float = 0.0


func _flow_of(colors: Array[PartLibrary.BrickColor]) -> FlowContainer:
	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	for color: PartLibrary.BrickColor in colors:
		var swatch := Swatch.new(color)
		swatch.set_pressed_no_signal(color.code == _selected_color)
		var code: int = color.code
		swatch.pressed.connect(func() -> void:
			_on_colour(code)
			swatch_pressed.emit(code))
		_swatches[color.code] = swatch
		flow.add_child(swatch)
	return flow


func _in_group(color: PartLibrary.BrickColor, group: Array) -> bool:
	if color.code in NOT_A_COLOUR:
		return false
	if not (group[1] as Array).has(color.drawn_as):
		return false
	var wanted: Variant = group[2]
	return wanted == null or bool(wanted) == color.is_transparent()


## Whether the palette shows a colour: the short one, or the long one.
func _is_offered(code: int, everything: bool) -> bool:
	if library == null or not library.colors.has(code) or code in NOT_A_COLOUR:
		return false
	return everything or library.is_current(code)


## Greys first, white to black, then the rest round the colour wheel
## from red, light before dark within a hue: a colour is found by what
## it looks like, and its name is on the tooltip.
static func _in_palette_order(a: PartLibrary.BrickColor, b: PartLibrary.BrickColor) -> bool:
	var ka: Vector3 = _palette_key(a)
	var kb: Vector3 = _palette_key(b)
	if ka.x != kb.x:
		return ka.x < kb.x
	if ka.y != kb.y:
		return ka.y < kb.y
	return ka.z < kb.z


static func _palette_key(color: PartLibrary.BrickColor) -> Vector3:
	var lab: Vector3 = Mosaic._oklab(Color(color.rgb, 1.0))
	var chroma: float = Vector2(lab.y, lab.z).length()
	if chroma < 0.035:
		return Vector3(0.0, -lab.x, float(color.code))
	# In steps of twenty degrees from just before red, so one hue's light
	# and dark shades sit together.
	var hue: float = fposmod(rad_to_deg(atan2(lab.z, lab.y)) + 15.0, 360.0)
	return Vector3(1.0, floorf(hue / 20.0), -lab.x)


func _on_colour(code: int) -> void:
	_selected_color = code
	# A colour chosen elsewhere — the eyedropper on an old model — that
	# the short palette does not show opens the long one, or the palette
	# would say nothing is chosen. Here, where the choice changes, and
	# not on every rebuild, or "Current only" could never be pressed
	# while holding one.
	if not _swatches.has(code) and _is_offered(code, true):
		_all_colours.set_pressed_no_signal(true)
		_build_swatches()
	for key: int in _swatches:
		var swatch: Swatch = _swatches[key]
		swatch.set_pressed_no_signal(key == code)
		swatch.queue_redraw()
	_say_colour()
	color_chosen.emit(code)
	# Previews are per colour: every tile is pointed at the new one and keeps
	# the picture it has until that one is drawn. The grid was made again,
	# every tile blank for the seconds the pictures took (walk180 A3), and
	# scrolled back to its top.
	for cell: Node in _grid.get_children():
		var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
		if not tile is ThumbTile:
			continue
		var one: ThumbTile = tile
		one.show_part(one.part_id, code, one.printed, true)
		var ready_now: ImageTexture = thumbnails.peek(one.part_id, code, one.printed) if thumbnails else null
		if ready_now:
			one.show_picture(ready_now, false)
	# The same tiles, so what is in sight is told again: they wait on new pictures.
	if _sight != null:
		_sight.forget()
	_techniques_seen = []


## How many lines the note under the palette always takes.
const NOTE_LINES := 2

## What is selected in the model, while a colour clicked paints it
## (Main._on_swatch_pressed): part id -> how many, colour -> how many.
## Empty when nothing is, or when the colour is for what goes down next.
var _chosen_parts: Dictionary = {}
var _chosen_colours: Dictionary = {}


## Say what is selected under the palette, not the part in hand: with a
## brick selected the note described the part in hand and its colours,
## while a click on a colour painted the brick (brickworks.diy, 2026-10-12).
func show_selection(parts: PackedStringArray, colours: PackedInt32Array) -> void:
	var by_part: Dictionary = {}
	var by_colour: Dictionary = {}
	for part: String in parts:
		by_part[part] = int(by_part.get(part, 0)) + 1
	for code: int in colours:
		by_colour[code] = int(by_colour.get(code, 0)) + 1
	if by_part == _chosen_parts and by_colour == _chosen_colours:
		return
	_chosen_parts = by_part
	_chosen_colours = by_colour
	_mark_swatches()


## The part the note and the dots are about: the selected one, all of one
## part; none, when the selection is of several; or the part in hand.
func _subject() -> PartLibrary.PartInfo:
	if _chosen_parts.is_empty():
		return library.parts.get(_selected_part)
	if _chosen_parts.size() == 1:
		return library.parts.get(str(_chosen_parts.keys()[0]))
	return null


## Which colours the part in hand was really made in: those carry a dot.
## A colour it was never made in is dimmed, not hidden — a builder may
## want it anyway — and only where the part's list is complete, which
## for every one of the forty most used parts it is not (some of their
## colours have no LDraw counterpart), so the dot is what mostly shows.
func _mark_swatches() -> void:
	if library == null:
		return
	var info: PartLibrary.PartInfo = _subject()
	for code: int in _swatches:
		var swatch: Swatch = _swatches[code]
		var made: int = 0
		if info != null and info.availability_known():
			if info.colors.has(code):
				made = 1
			elif info.never_made_in(code):
				made = -1
		if swatch.made_in != made:
			swatch.made_in = made
			swatch.queue_redraw()
		swatch.tooltip_text = _swatch_tip(swatch.color, info, made)
		swatch.accessibility_description = swatch.tooltip_text.trim_prefix(swatch.color.name) \
			.strip_edges()
	_say_colour()


func _swatch_tip(color: PartLibrary.BrickColor, info: PartLibrary.PartInfo,
		made: int) -> String:
	var tip: String = "%s (%d), %s" % [color.name, color.code, color.finish_name()]
	if not library.is_current(color.code) and library.recent_since > 0:
		if library.colour_use(color.code).y > 0:
			tip += "\nnot in a set since %d" % library.recent_since
		else:
			tip += "\nin no set inventory"
	if info != null:
		if made > 0:
			tip += "\n%s comes in it" % info.id
		elif made < 0:
			tip += "\n%s was never made in it" % info.id
	return tip


## The colour in hand, in words, under the palette.
func _say_colour() -> void:
	if _colour_note == null or library == null:
		return
	var text: String = ""
	var info: PartLibrary.PartInfo = _subject()
	if not _chosen_parts.is_empty():
		var count: int = 0
		for part: String in _chosen_parts:
			count += int(_chosen_parts[part])
		var what: String = "%d parts" % count
		if info != null:
			what = Inventory._tidy(info.name) if count == 1 \
				else "%d × %s" % [count, Inventory._tidy(info.name)]
		var colour: String = " in %d colours" % _chosen_colours.size()
		if _chosen_colours.size() == 1:
			colour = " in " + library.color(int(_chosen_colours.keys()[0])).name
		text = "%s%s, selected: a colour clicked paints %s" % [what, colour,
			"it" if count == 1 else "them"]
		if info != null and info.availability_known():
			text += ". A dot marks the %s it comes in" % Counted.of(info.colors.size(), "colour")
	else:
		var color: PartLibrary.BrickColor = library.color(_selected_color)
		text = "%s, %s" % [color.name, color.finish_name()]
		if info != null and info.availability_known():
			text += ". A dot marks the %s %s comes in" % [Counted.of(info.colors.size(), "colour"),
				info.id]
			if not info.colors_partial:
				text += "; it was made in no other"
	_colour_note.text = text
	_colour_note.tooltip_text = text


## One colour in the palette, drawn as what it is: see-through over a
## check, chrome and metal with a highlight across them, glitter and
## speckle with their flecks. A flat square of the body colour made
## chrome silver and light grey the same swatch.
class Swatch extends Button:
	const SIZE := 17
	var color: PartLibrary.BrickColor
	## 1 the part in hand was made in this colour, -1 it is known never
	## to have been, 0 nobody knows.
	var made_in: int = 0

	func _init(of: PartLibrary.BrickColor) -> void:
		color = of
		custom_minimum_size = Vector2(SIZE, SIZE)
		toggle_mode = true
		FocusGuard.by_keyboard(self)
		var nothing := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(state, nothing)
		add_theme_stylebox_override("focus", FocusGuard.ring(2))
		set_meta("code", of.code)
		# Its name, as a screen reader says it; the rest of its tooltip
		# (PartsBin._swatch_tip) is its description.
		accessibility_name = of.name

	# Filled rectangles and nothing else. A polygon, a circle or a line
	# between them breaks the 2D batch, and 84 swatches drawn that way cost
	# 149 draw calls a frame — two to four milliseconds measured on a
	# 200,000-brick model, more than the finishes themselves cost in 3D.
	func _draw() -> void:
		var box := Rect2(Vector2.ONE, size - Vector2(2, 2))
		var body := Color(color.shown, 1.0)
		const F := PartLibrary.BrickColor.Finish
		var corner: Vector2 = box.position
		var across: Vector2 = box.size
		if color.is_transparent():
			var light := Color(0.82, 0.83, 0.85)
			var dark := Color(0.45, 0.46, 0.5)
			var half: Vector2 = across * 0.5
			draw_rect(Rect2(corner, half), light)
			draw_rect(Rect2(corner + half, half), light)
			draw_rect(Rect2(corner + Vector2(half.x, 0), half), dark)
			draw_rect(Rect2(corner + Vector2(0, half.y), half), dark)
			draw_rect(box, Color(body, 0.62))
		else:
			draw_rect(box, body)
		var finish: int = color.drawn_as
		if finish == F.CHROME or finish == F.METAL:
			# Bright above, dark below, the way a polished face reflects a
			# room: sharp on chrome, soft on metallic paint.
			var strength: float = 0.75 if finish == F.CHROME else 0.4
			draw_rect(Rect2(corner, Vector2(across.x, across.y * 0.38)), Color(1, 1, 1, strength))
			draw_rect(Rect2(corner + Vector2(0, across.y * 0.62), Vector2(across.x, across.y * 0.38)),
				Color(0, 0, 0, strength * 0.6))
		elif finish == F.PEARL:
			draw_rect(Rect2(corner, Vector2(across.x, across.y * 0.4)), Color(1, 1, 1, 0.28))
		elif finish == F.SPECKLE or finish == F.GLITTER or finish == F.OPAL:
			var dot: Color = Color(color.fleck, 1.0)
			if finish == F.GLITTER:
				dot = dot.lightened(0.5)
			elif finish == F.OPAL:
				dot = Color(1, 1, 1, 0.8)
			for at: Vector2 in [Vector2(0.25, 0.3), Vector2(0.7, 0.2), Vector2(0.5, 0.55),
					Vector2(0.2, 0.75), Vector2(0.78, 0.72)]:
				draw_rect(Rect2(corner + across * at - Vector2.ONE, Vector2(2, 2)), dot)
		elif finish == F.GLOW or finish == F.FLUORESCENT:
			_frame(box.grow(-1.0), 1.5, Color(body.lightened(0.6), 0.9))
		elif finish == F.MILKY:
			draw_rect(box, Color(1, 1, 1, 0.3))
		elif finish == F.RUBBER:
			draw_rect(Rect2(corner + Vector2(0, across.y * 0.7), Vector2(across.x, across.y * 0.3)),
				Color(0, 0, 0, 0.3))
		elif finish == F.FABRIC:
			for n: int in 3:
				draw_rect(Rect2(corner + Vector2(across.x * (0.2 + 0.3 * n), 0),
					Vector2(1, across.y)), Color(0, 0, 0, 0.25))
		if made_in > 0:
			# The part in hand comes in it: a dot in the corner, ringed so
			# it shows on white as well as on black.
			var spot: Vector2 = corner + across - Vector2(5, 5)
			draw_rect(Rect2(spot, Vector2(5, 5)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(spot + Vector2.ONE, Vector2(3, 3)), Color(1, 1, 1, 0.95))
		elif made_in < 0:
			# Never made in it: dimmed.
			draw_rect(box, Color(0.11, 0.12, 0.14, 0.6))
		if button_pressed:
			_frame(Rect2(Vector2.ZERO, size), 2.0, Color(1, 1, 1, 0.95))
		elif is_hovered():
			_frame(Rect2(Vector2.ZERO, size), 1.0, Color(1, 1, 1, 0.6))
		else:
			_frame(Rect2(Vector2.ZERO, size), 1.0, Color(0, 0, 0, 0.35))

	## An outline as four filled strips, for the same reason.
	func _frame(area: Rect2, width: float, tint: Color) -> void:
		draw_rect(Rect2(area.position, Vector2(area.size.x, width)), tint)
		draw_rect(Rect2(area.position + Vector2(0, area.size.y - width), Vector2(area.size.x, width)), tint)
		draw_rect(Rect2(area.position + Vector2(0, width), Vector2(width, area.size.y - 2 * width)), tint)
		draw_rect(Rect2(area.position + Vector2(area.size.x - width, width),
			Vector2(width, area.size.y - 2 * width)), tint)


## Where a browser test finds the bin's own button.
func controls_by_name() -> Dictionary:
	var named: Dictionary = {"parts list": _scroll}
	# The search and the first part it found: how a browser check takes a
	# part by its number, as a person does (tools/web/assembly_flow.mjs).
	named["part search"] = _search
	named["photo search"] = _photo_button
	# Its question before the first photo, and the Techniques tab and its
	# rows by name (tools/web/bin_flow.mjs).
	if _telling != null:
		named["photo choose"] = _telling.get_ok_button()
	for child: Node in _category_row.get_children():
		if str(child.get_meta("category", "")) == TECHNIQUES:
			named["techniques"] = child
		elif str(child.get_meta("category", "")) == "All":
			named["all parts"] = child
	for child: Node in _grid.get_children():
		if child.has_meta("technique"):
			named["technique " + str(child.get_meta("technique"))] = child
	named["colour find"] = _colour_find
	named["all colours"] = _all_colours
	named["palette"] = _palette_scroll
	if _grid.get_child_count() > 0:
		named["first part"] = _grid.get_child(0)
	# The first tile's count of what is folded under it (_fold_badge).
	for child: Node in _grid.get_children():
		for inner: Node in child.get_children():
			if inner is Button:
				named["first fold"] = inner
				break
		if named.has("first fold"):
			break
	if _make_button != null:
		named["make part"] = _make_button
	if _print_button != null:
		named["print part"] = _print_button
		named["stickers"] = _stickers_button
	return named


## Show one category's parts, as its button would.
func show_category(name: String) -> void:
	if _categories.has(name):
		_on_category(name)


func _on_category(name: String) -> void:
	_category = name
	for child: Node in _category_row.get_children():
		var button: Button = child
		button.button_pressed = str(button.get_meta("category", "")) == name
	_run_search(_search.text)


func _on_search_typed(text: String) -> void:
	# Debounced: a held key would otherwise scan the library per character.
	# A first key after a pause is answered at once, and the keys that follow
	# it quickly once they stop.
	var now: int = Time.get_ticks_msec()
	var quiet: bool = not _pending and now - _search_at >= SEARCH_DEBOUNCE
	_search_at = now
	if quiet:
		_run_search(text)
	else:
		_pending = true


func _process(_delta: float) -> void:
	if _pending and Time.get_ticks_msec() - _search_at >= SEARCH_DEBOUNCE:
		_pending = false
		_run_search(_search.text)

	# Grow the grid as it is scrolled. Checking here rather than on a
	# scroll signal covers the case where the window is resized and the
	# existing page no longer fills it.
	if _shown < _display.size() and _scroll != null:
		var bar: VScrollBar = _scroll.get_v_scroll_bar()
		if bar.max_value > 0.0 and bar.max_value - bar.value - bar.page < 260.0:
			# A page a frame at most, so no one frame makes them all.
			_show_more(FIRST_PAGE)

	# And say what is in sight, for the same reason: a scroll, a resize,
	# a page added and the dock folding all change it, and only the last
	# has a signal.
	if thumbnails != null and _category == TECHNIQUES:
		var count: int = _grid.get_child_count()
		var now: Array = [_scroll.scroll_vertical, _scroll.size, _grid.size, count,
			_grid.get_child(0).get_instance_id() if count > 0 else 0]
		if now != _techniques_seen:
			_techniques_seen = now
			thumbnails.watch(self, _technique_tiles())
	elif thumbnails != null and _sight != null and _sight.changed():
		thumbnails.watch(self, _sight.tiles())


func _run_search(query: String) -> void:
	if library == null:
		return
	_guesses.clear()
	_set_parts.clear()
	if _category == TECHNIQUES:
		_results = []
		_fill_techniques(query.strip_edges())
		return
	_results = _find(query.strip_edges(), _category)
	# An element number, as a booklet prints it, is a part in a colour: the
	# colour is taken in hand, so its tile is drawn and placed in it.
	var element: Array = library.part_of_element(query)
	if not element.is_empty() and int(element[1]) != _selected_color \
			and library.colors.has(int(element[1])):
		_on_colour(int(element[1]))
	_guesses.clear()
	_open.clear()
	_fill_grid()


## Search, ranked so the plain part comes before its printed variants.
##
## A plain substring match over the catalogue is fast enough to do
## outright and never surprises anyone, which a fuzzy match would. What
## it does need is ordering: "brick 2 x 4" matches 3001 and several
## hundred stickered and printed versions of 3001, and only one of those
## is what was meant.
##
## In the library's words, as the assistant's search asks
## (PartLibrary.in_ldraw_words): "2x4" as "2 x 4", "cheese slope" as
## what LDraw files it under.
func _find(query: String, category: String) -> Array[PartLibrary.PartInfo]:
	var asked: String = PartLibrary.in_ldraw_words(query)
	var needles: PackedStringArray = asked.split(" ", false)
	if category == RECENT or category == FAVOURITES:
		return _from_shelf(category, needles)
	var wanted_category: String = category.to_lower()
	if needles.is_empty():
		return _unasked(wanted_category)
	# The assistant's search, every word asked (PartSearch): ranked by how
	# well a part answers and then by how much real sets use it, so "door
	# frame" is 60596, in 850 sets, before 80400a, in 24 (walk239 A13). It
	# leaves out what LDraw keeps only for old files where the part made now
	# stands for it (PartLibrary.current): "slope inverted 2x2" showed 3660a,
	# obsolete, beside 3660c. Still there in its own category.
	var found: Array[PartLibrary.PartInfo] = []
	# Each marked as listed as it is kept, for _fold.
	_listing += 1
	for info: PartLibrary.PartInfo in library.search(query, -1, true):
		if not info.reachable:
			continue  # no geometry anywhere in this build
		if wanted_category != "all" and info.category.to_lower() != wanted_category:
			continue
		info.listed_in = _listing
		found.append(info)
	_set_aside = 0
	_listed = found
	_listed_as = _listing
	return found


## A category's parts with nothing typed, staples first: worked out once a
## category, since sorting twenty thousand parts by their names is most of a
## second, and asked again each time the search is cleared.
func _unasked(wanted_category: String) -> Array[PartLibrary.PartInfo]:
	var key: String = "%s %d" % [wanted_category, library.ids().size()]
	if _unasked_cache.has(key):
		_set_aside = int(_unasked_cache[key][1])
		return _unasked_cache[key][0]
	var found: Array[PartLibrary.PartInfo] = []
	var set_aside: int = 0
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect():
			continue
		if not info.reachable:
			continue  # no geometry anywhere in this build
		if wanted_category == "all" and library.superseded(id):
			continue
		if wanted_category == "all":
			# Stickers and superseded parts are still findable by name or
			# by their own button; they are just not what anyone means by
			# "show me the parts". Counted as they are skipped so the
			# status line can say how many and where they went — silently
			# dropping 7,738 parts is indistinguishable from losing them.
			if _is_buried(info.category):
				set_aside += 1
				continue
		elif info.category.to_lower() != wanted_category:
			continue
		found.append(info)
	_set_aside = set_aside
	_sort_for(found, "")
	_unasked_cache[key] = [found, set_aside]
	return found


## Category and catalogue size -> [its parts with nothing typed, set aside].
var _unasked_cache: Dictionary = {}


## Sort results for a query: match quality first, then staple-ness.
## LDraw suffixes a printed part with p and a number: 3001p01.
static var PRINTED: RegEx = RegEx.create_from_string("p[0-9]+[a-z]?$")
## The words a query asks for a print or a sticker in, once
## PartLibrary.in_ldraw_words has put them in the index's words.
const DECOR_WORDS: Array[String] = ["print", "sticker"]
## What a printed or renamed version of another part costs a staple.
const VARIANT := 400
## What being found only through its keywords costs: more than any score
## spans, so every part a query's words found by name comes first.
const KEYWORDS_ONLY := 100000
## A query's word found in what is printed on a part: above a name that
## begins with the word (260), so the thing printed outranks the shape.
const PRINTED_HIT := 300
## A query that is a part number, or the start of one: 3023, 3023b.
static var NUMBER: RegEx = RegEx.create_from_string("^[0-9]+[a-z]*$")

## The two shelves, shown as categories (see PartShelf).
const RECENT := "Recent"
const FAVOURITES := "Favourites"
## The worked constructions (Techniques), shown as a category beside them.
const TECHNIQUES := "Techniques"
## What a construction's picture is asked for by: this and its name.
const TECHNIQUE := "technique:"
const STAR := "res://assets/ui/tools/star.svg"


## Keep a part in Favourites, or take it out, and show it.
func _toggle_favourite(part_id: String) -> void:
	var kept: bool = PartShelf.toggle_favourite(part_id)
	for child: Node in _grid.get_children():
		if str(child.get_meta("part", "")) == part_id and child.has_meta("star"):
			(child.get_meta("star") as Control).visible = kept
	part_favourited.emit(part_id, kept)
	_refresh_shelf()


## The parts on a shelf, in its own order, that this build can place and
## that match what is typed.
func _from_shelf(shelf: String, needles: PackedStringArray) -> Array[PartLibrary.PartInfo]:
	var ids: PackedStringArray = PartShelf.recent() if shelf == RECENT \
		else PartShelf.favourites()
	var found: Array[PartLibrary.PartInfo] = []
	for id: String in ids:
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info == null or not info.reachable:
			continue
		if PartLibrary.matched(info, needles) != PartLibrary.NOT_MATCHED:
			found.append(info)
	_set_aside = 0
	return found


func _shelf_label(shelf: String) -> String:
	var count: int = (PartShelf.recent() if shelf == RECENT else PartShelf.favourites()).size()
	return "%s %d" % [shelf, count]


## The shelves' counts on their buttons, and the grid again if a shelf is
## what is showing.
func _refresh_shelf() -> void:
	for child: Node in _category_row.get_children():
		if child.has_meta("shelf"):
			(child as Button).text = _shelf_label(str(child.get_meta("shelf")))
	if _category == FAVOURITES:
		_run_search(_search.text)


static func _sort_for(found: Array[PartLibrary.PartInfo], query: String) -> void:
	# Found by its name before found only through its keywords, whatever
	# the scores: a query keeps every answer its name matching gave it,
	# in that order, and what the keywords add comes after.
	var needles: PackedStringArray = query.split(" ", false)
	# Each part's place worked out once, its score and then its footprint
	# in one number, and the parts sorted by their places: the 20,000 of
	# All with nothing typed took 1.2 s natively and most of 3 s of a first
	# visit's start on the web, looking a part's score up and working its
	# footprint out again in each of 300,000 comparisons (load250). The
	# order is the one that was: score, then the smaller footprint, then
	# the number.
	var count: int = found.size()
	var places := PackedInt64Array()
	places.resize(count)
	var ids := PackedStringArray()
	ids.resize(count)
	for n: int in count:
		var info: PartLibrary.PartInfo = found[n]
		var score: int = _staple_score(info) + _match_score(info, query) \
			+ _usage_score(info) - (KEYWORDS_ONLY
				if PartLibrary.matched(info, needles) == PartLibrary.BY_KEYWORDS else 0)
		var studs: Vector2i = info.footprint_studs()
		places[n] = score * AREA_SPAN - mini(studs.x * studs.y, AREA_SPAN - 1)
		ids[n] = info.id
	var order: Array = range(count)
	order.sort_custom(func(a: int, b: int) -> bool:
		if places[a] != places[b]:
			return places[a] > places[b]
		return ids[a].naturalnocasecmp_to(ids[b]) < 0)
	var sorted: Array[PartLibrary.PartInfo] = []
	sorted.resize(count)
	for n: int in count:
		sorted[n] = found[order[n]]
	found.assign(sorted)


## Wider than any part's footprint in studs, so a score and a footprint
## make one number that sorts as the two did.
const AREA_SPAN := 1 << 20


static func _rank_shared(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
	var a_score: int = _staple_score(a) + _usage_score(a)
	var b_score: int = _staple_score(b) + _usage_score(b)
	if a_score != b_score:
		return a_score > b_score
	# Within a tier, the smaller part first: a bin reads better going up
	# in size than jumping about.
	var a_area: int = a.footprint_studs().x * a.footprint_studs().y
	var b_area: int = b.footprint_studs().x * b.footprint_studs().y
	if a_area != b_area:
		return a_area < b_area
	return a.id.naturalnocasecmp_to(b.id) < 0


## How much real sets reach for this part.
##
## The ranking above this was built out of what a name looks like, and a
## name cannot tell you that 3062b, the 1x1 round brick, is in 4,496
## catalogued sets and 71075a is in seventeen, and both are named like
## the ordinary thing. Measured over thirty-five ordinary queries: twelve
## led with the part real sets use most, and the leader carried 73% of
## the usage the best match had. Sixteen and 81% with this.
##
## It promotes and never demotes. Four fifths of the library does not
## join to a set inventory, so those parts are told nothing either way;
## a rule that pushed them down would bury the library on no evidence.
## Filling the gap with explicit zeros, to push down the parts
## Rebrickable knows and no set contains, was measured: 221 parts moved
## and no ranking changed. It is not here.
##
## Capped well under the weakest name tier on purpose, so it orders
## parts *within* what was asked for and never over it. A search for
## "plate 4 x 4" must still lead with the 4 x 4 — 3031, in 4,688 sets —
## and not with the 2 x 4 that is in seventeen thousand.
static func _usage_score(info: PartLibrary.PartInfo) -> int:
	if info.in_sets <= 0:
		return 0                          # nobody knows, so say nothing
	# Logarithmic, because the gap between a part in ten sets and one in
	# a hundred matters and the gap between five thousand and nine
	# thousand does not: both are staples.
	return mini(100, int(log(float(info.in_sets)) * 11.0))


## How well a part answers a particular query, on top of how staple it is.
##
## Staple-ness alone is not enough once someone types something: a search
## for "brick 2 x 4" ranked Brick 1 x 2 above Brick 2 x 4, because both
## are equally plain and the 1 x 2 is smaller. What was missing is any
## credit for actually matching what was asked.
##
## The size in the query is the part that matters most. LDraw pads its
## names with double spaces ("Brick  2 x  4"), so both sides are squeezed
## before comparing or nothing ever matches exactly.
static func _match_score(info: PartLibrary.PartInfo, query: String) -> int:
	if query.is_empty():
		return 0
	var wanted: String = _squeeze(query)
	var name: String = _squeeze(info.name)
	var score: int = 0

	# A print asked for. "print" and "sticker" are the index's words and
	# in no name (PartLibrary.ALSO_KNOWN_AS), so the rest of the query is
	# what is scored: in the name as for any part, and above all in what
	# is printed on it. "flame print" wants a tile with flames on it, not
	# Flame 3.5L, the flame-shaped piece in marbled trans yellow, which
	# begins with the word and so outscored every print of one.
	var decor_asked: int = 0
	for word: String in DECOR_WORDS:
		if (" %s " % wanted).contains(" %s " % word):
			decor_asked |= PartLibrary.PartInfo.PRINTED if word == "print" \
				else PartLibrary.PartInfo.STICKERED | PartLibrary.PartInfo.STICKER
			wanted = _squeeze((" %s " % wanted).replace(" %s " % word, " "))
	if (info.decor() & decor_asked) != 0:
		# And what was asked for is not a variant of anything here: it does
		# not pay a variant's cost (_staple_score), or the stickers whose
		# names happen to say Print ("Porsche Bag Print") led "porsche
		# print" for not being called a Pattern.
		if _a_print_by_name(info) and not name.begins_with("=") \
				and not name.begins_with("~"):
			score += VARIANT
		var on_it: String = info.printed().to_lower()
		for word: String in wanted.split(" ", false):
			if word.length() >= 3 and not word.is_valid_float() and word != "with" \
					and on_it.contains(word):
				score += PRINTED_HIT
				break
	if wanted.is_empty():
		return score

	# Whole words, not the starts of longer ones.
	#
	# A search for "bar" answered with Barrel 4.5 x 4.5, because
	# "barrel" begins with "bar" and that scored as "the thing, plus a
	# qualifier". "clip" answered with a solar panel, "wedge plate" with
	# a 2 x 16 triple with an axle hole. The staples were all there and
	# all below the oddities, which for an assistant that takes the
	# first result is the same as their not being there at all.
	var spaced: String = _apart(name)
	var asked: String = _apart(wanted)
	# Both sides carry a space at each end already, so a whole-word
	# prefix is a plain begins_with and a whole-word hit is a plain
	# contains. Adding another space to either made the middle tier
	# unreachable, which quietly flattened the ranking: "panel" led with
	# a Technic Panel 3 x 7 because the plain panels had stopped
	# scoring as the thing itself.
	if name == wanted:
		score += 400                      # exactly the thing named
	elif spaced.begins_with(asked):
		score += 260                      # the thing, plus a qualifier
	elif spaced.contains(asked):
		score += 140                      # the words, in order, somewhere
	if _squeeze(info.id) == wanted:
		score += 500                      # asked for by number
	elif NUMBER.search(wanted) != null and info.id.to_lower().begins_with(wanted) \
			and not info.id.substr(wanted.length(), 1).is_valid_int():
		# The same mould under another letter or print: 3023 asked for,
		# 3023b and 3023bp00 meant. Searched as text, 3023 also begins
		# 30236 and 30239, a spider, which led the prints for it.
		score += 350
	elif NUMBER.search(wanted) != null and info.id.to_lower().begins_with(wanted):
		# Another number that merely starts the same: after the family,
		# not among it.
		score -= 300

	# The size asked for, counted on its own.
	#
	# "slope 45 2 x 4" came back with Slope Brick 45 2 x 1. The phrase
	# matched nothing — the name says "slope brick", the query said
	# "slope" — so every candidate scored the same, and the tiebreak
	# below takes the smallest part. The size is the one thing in a
	# query that is never decoration, and it was the one thing not
	# scored.
	var asked_size: Vector2 = _size_named(wanted)
	if asked_size != Vector2.ZERO:
		var found_size: Vector2 = _size_named(name)
		if found_size == asked_size:
			score += 300
		elif found_size == Vector2(asked_size.y, asked_size.x):
			# A 4 x 2 is a 2 x 4 turned round, and LDraw picks one
			# order per part while a builder says either.
			score += 240

	# A part named for what it has not got.
	#
	# "Brick 1 x 2 without Centre Stud" answered a search for a jumper,
	# which is a plate *with* a centre stud — the one word that matters
	# is the one the match ignored. Asking for a feature and being
	# offered its absence is worse than being offered nothing.
	if spaced.contains(" without ") and not asked.contains(" without "):
		score -= 300
	return score


## The first two numbers of the footprint a name or a query states, e.g.
## "Brick 2 x 4 x 0.667" -> (2, 4). Zero when none is stated.
##
## Reusing SIZE below rather than a second pattern for the same thing:
## it already finds the phrase, and the numbers are what is in it.
static func _size_named(text: String) -> Vector2:
	var found: RegExMatch = SIZE.search(_squeeze(text))
	if found == null:
		return Vector2.ZERO
	var numbers: PackedStringArray = found.get_string().split("x", false)
	if numbers.size() < 2:
		return Vector2.ZERO
	return Vector2(numbers[0].strip_edges().to_float(),
		numbers[1].strip_edges().to_float())


## The text with its punctuation opened out into spaces and a space at
## each end, so a whole word can be looked for by looking for it with a
## space on both sides. "Solar/Clip-On" holds the word clip; "Barrel"
## does not hold the word bar.
static func _apart(text: String) -> String:
	var out: String = ""
	for ch: String in text:
		out += ch if (ch >= "a" and ch <= "z") \
			or (ch >= "0" and ch <= "9") or ch == "." else " "
	return " " + _squeeze(out) + " "


## Collapse runs of whitespace, for comparing names that are padded.
static func _squeeze(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


## How much this looks like a part someone would reach for.
##
## Sorting by triangle count put the oddities first — the flattest, least
## detailed things in the library — which is the opposite of useful. What
## a bin wants at the top is the staples, and a staple announces itself
## in its name: "Brick 2 x 4" and nothing else. Decoration, qualifiers
## and unofficial status each push a part down.
static func _staple_score(info: PartLibrary.PartInfo) -> int:
	var name: String = _squeeze(info.name.strip_edges())
	var lowered: String = name.to_lower()
	var score: int = 0

	# A printed or renamed version of another part is the same shape
	# with a picture on it, and there are thousands of them. Somebody
	# searching by shape never wants one, and without this they crowd
	# out the part they are a variant of: a query for a wedge plate
	# answered with one usable suggestion and then four prints of a
	# single 2 x 3 — Aquashark, a silver V, a red V, an MTron logo.
	#
	# A penalty rather than an exclusion. Asking for "aquashark" by name
	# should still find it; it just should not arrive uninvited.
	if name.begins_with("=") or name.begins_with("~") or _a_print_by_name(info):
		score -= VARIANT

	# Modulex is a different product altogether — a separate,
	# architect's system on its own scale, filed in the same library.
	# Nobody building with LEGO wants one, and "cheese slope" answered
	# with a Modulex brick.
	if lowered.begins_with("modulex"):
		score -= 400


	# Plainness is measured by what comes *after* the size, not by the
	# whole name matching a shape.
	#
	# Two families broke the anchored version. LDraw names a slope "Slope
	# Brick 45 2 x 1" — the angle sits between the family and the size,
	# so nothing anchored at the start ever matched and every slope
	# scored zero, which is why searching for one led with Slope 5 x 8 x
	# 0.667. And the modern flat tiles are "Tile 1 x 2 with Groove": the
	# groove is what a tile *is*, but it read as a qualifier, so the
	# three tiles everyone uses ranked below genuinely obscure ones.
	var size: RegExMatch = SIZE.search(name)
	if size != null:
		var tail: String = name.substr(size.get_end()).strip_edges()
		# Only on a tile. The groove is what a flat tile is, so "Tile 1 x 2
		# with Groove" is the standard part — but "Brick 1 x 2 with
		# Groove" is a masonry variant, and letting the rule apply to
		# every family put those variants alongside the plain bricks on
		# the first page of the bin.
		if lowered.begins_with("tile"):
			for free: String in FREE_QUALIFIERS:
				if tail.to_lower().begins_with(free):
					tail = tail.substr(free.length()).strip_edges()
		var qualifiers: int = (0 if tail.is_empty()
			else tail.split(" ", false).size())
		score += maxi(100 - qualifiers * 18, 10)
		# A third dimension is a specialisation, not just a longer name.
		# Without this, Brick 1 x 2 x 2 scores exactly what Brick 2 x 2
		# does and then wins the tie on footprint, because it is a stud
		# narrower — so searching for "brick" led with the tall ones.
		if size.get_string().count("x") > 1:
			score -= 12

	# A part named for a family outranks one that merely mentions it.
	# Ranked, not flat. The default view is sorted by this alone, and a
	# uniform bonus made its first page one of everything — which reads
	# as a sample rather than as a bin. A real bin opens on bricks.
	for family: String in FAMILIES:
		if lowered.begins_with(family):
			score += int(FAMILIES[family])
			break

	if _is_decorated(info):
		score -= 70
	if info.unofficial:
		score -= 40
	# Shortcuts are assemblies, not parts; useful but not staples.
	if info.kind.to_lower().contains("shortcut"):
		score -= 25
	return score


## Families and how fundamental each one is. Panels and wedges were
## missing entirely, and since almost every plain panel is
## three-dimensional they took the height penalty with nothing to offset
## it — so "panel" led with Panel 3 x 5 Solar/Clip-On/Deltoid.
static var FAMILIES: Dictionary = {
	"brick": 14, "plate": 12, "tile": 10, "slope": 8,
	"panel": 8, "wedge": 8, "bracket": 6, "arch": 6,
}


## "2 x 4", or "5 x 8 x 0.667". Anywhere in the name, because the family
## word is not always what comes before it.
static var SIZE := RegEx.create_from_string(
	"\\d+(\\.\\d+)?\\s*x\\s*\\d+(\\.\\d+)?(\\s*x\\s*\\d+(\\.\\d+)?)?")

## Qualifiers that describe the standard form of a part rather than a
## variant of it, and so should cost nothing. Only "with groove": a tile
## "without Groove" is the old mould, and treating both as standard put
## the superseded one first.
static var FREE_QUALIFIERS: PackedStringArray = PackedStringArray([
	"with groove"])


## A print by its name or its number: what a variant's cost was written
## for, before the index could tell a print from its name.
static func _a_print_by_name(info: PartLibrary.PartInfo) -> bool:
	return info.name.to_lower().contains("pattern") or PRINTED.search(info.id) != null


static func _is_decorated(info: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.to_lower()
	return (name.contains("pattern") or name.contains("sticker")
		or name.contains("print"))


static func _is_buried(category: String) -> bool:
	for name: String in BURIED:
		if category.begins_with(name):
			return true
	return false


func _fill_grid() -> void:
	# Out of the grid now, not at the end of the frame, or what is in
	# sight is worked out over the old cells and the new ones together.
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cells.clear()
	_shown = 0
	_scroll.scroll_vertical = 0
	_grid.columns = COLUMNS
	_fold()
	_show_more(FIRST_PAGE)


## How many tiles a search shows at once, before the rest are added as the
## grid is scrolled (_process): the rows in sight and more, where a full page
## took longer to make than the search took to run.
const FIRST_PAGE := 32


## The results as tiles: each print, sticker and assembly of a part that is
## among them folded under its part's tile, which counts them and opens them
## (_make_cell). A search for 3008 or "slope 45 2 x 4" listed the plain part
## and then dozens of its stickered versions, "Showing 120 of 315" (walk239
## A13); Studio keeps a decorated part behind its plain one. One assembly LDraw
## draws whole is put beside its part instead, as the window with its glass is
## what a house is built of: 60593c01 after 60593. Not when a print or a
## sticker is asked for, nor for a shelf's or a photo's parts, each chosen.
func _fold() -> void:
	_display = []
	_folds = {}
	_folded = 0
	var asked: String = " %s " % PartLibrary.in_ldraw_words(_search.text)
	if not _guesses.is_empty() or not _set_parts.is_empty() or _category == RECENT or _category == FAVOURITES \
			or asked.contains(" print ") or asked.contains(" sticker "):
		_display = _results.duplicate()
		return
	# Each listed part marked as this listing's, and each folded one as its
	# folded, where a dictionary entry for each of twenty thousand took
	# longer than the search.
	_listing += 1
	if not is_same(_listed, _results):
		for info: PartLibrary.PartInfo in _results:
			info.listed_in = _listing
	else:
		_listing = _listed_as
	var groups: Dictionary = {}     ## PartInfo -> [its prints and assemblies listed]
	for info: PartLibrary.PartInfo in _results:
		var of: PartLibrary.PartInfo = info.folds_under()
		if of == null or of.listed_in != _listing:
			continue
		info.listed_in = -_listing
		var into: Variant = groups.get(of)
		if into == null:
			into = []
			groups[of] = into
		(into as Array).append(info)
	for info: PartLibrary.PartInfo in _results:
		if info.listed_in == -_listing:
			continue
		_display.append(info)
		if groups.is_empty() or not groups.has(info):
			continue
		var under: Array = groups[info]
		for n: int in under.size():
			var one: PartLibrary.PartInfo = under[n]
			if not one.whole_of.is_empty():
				_display.append(one)
				under.remove_at(n)
				break
		if under.is_empty():
			continue
		_folds[info.id] = under
		_folded += under.size()
		if _open.has(info.id):
			for one: PartLibrary.PartInfo in under:
				_display.append(one)


## Open the tiles folded under [param part_id], or fold them again, where the
## grid stands.
func toggle_fold(part_id: String) -> void:
	if not _folds.has(part_id):
		return
	if _open.has(part_id):
		_open.erase(part_id)
	else:
		_open[part_id] = true
	var at: int = _scroll.scroll_vertical
	var keep: int = _shown
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cells.clear()
	_shown = 0
	_fold()
	var through: int = _display.find(library.parts.get(part_id)) + 1
	if _open.has(part_id):
		through += (_folds[part_id] as Array).size()
	_show_more(maxi(keep, through))
	_scroll.set_deferred("scroll_vertical", at)


## Add the next page of cells. Called on first fill and again whenever
## the scroll reaches the end, so the whole result set is reachable
## without ever building 28,000 controls.
func _show_more(most: int = PAGE) -> void:
	var limit: int = mini(_shown + most, _display.size())
	while _shown < limit:
		_grid.add_child(_make_cell(_display[_shown]))
		_shown += 1
	_update_status()


func _update_status() -> void:
	var total: int = _display.size()
	if not _set_parts.is_empty():
		_status.text = "The parts of %s, the most used first" % set_shown
		_status.tooltip_text = "Search or choose a category to see every part again"
		return
	if not _guesses.is_empty():
		_status.text = "From your photo, most likely first, as Brickognize sees it" + (
			"" if _guessed_colour.is_empty() else ", in %s" % _guessed_colour)
		_status.tooltip_text = _guessed_note
		return
	if _category == TECHNIQUES:
		_status.text = "nothing matches" if _techniques_shown == 0 else (
			"%s: choose one to hold it whole" % Counted.of(_techniques_shown, "worked construction"))
		_status.tooltip_text = "R turns what is held, a click puts it down, Esc puts it away"
		return
	if total == 0 and _category == RECENT and _search.text.strip_edges().is_empty():
		_status.text = "The parts you choose will be here, newest first."
	elif total == 0 and _category == FAVOURITES and _search.text.strip_edges().is_empty():
		_status.text = "Right-click any part to keep it here."
	elif total == 0:
		_status.text = "nothing matches"
	elif _shown >= total:
		_status.text = "%s part%s" % [_comma(total), "" if total == 1 else "s"]
	else:
		_status.text = "Showing %s of %s — scroll for more" % [
			_comma(_shown), _comma(total)]
	# What the tiles hold folded: said where nothing else is, on one line.
	if _folded > 0 and _set_aside == 0:
		_status.text += ("\n1 more folded under its part: press +" if _folded == 1
			else "\n%s more folded under their parts: press +" % _comma(_folded))

	# Where the rest went. Only on the default view, since that is the
	# only place anything is held back.
	if _set_aside > 0:
		# One line: as two it took a row from the parts it is about.
		_status.text += "\nStickers and retired parts: search finds them."
		_status.tooltip_text = "%s stickers and retired parts" % _comma(_set_aside)
	if _set_aside == 0:
		_status.tooltip_text = ("%s parts can be placed in this build"
			% _comma(_offerable))
	# A number typed that names a part this build cannot place: said, or the
	# first tile reads as the answer. A web export without its parts served
	# offered 6157 nowhere, and "6157" led with a minifigure leg whose shop
	# number has it in it (the CAD task test, 2026-10-16).
	var typed: String = _search.text.strip_edges().to_lower()
	var named: PartLibrary.PartInfo = library.parts.get(typed) if library != null else null
	if named != null and not named.reachable:
		_status.text = "%s is not in this build of the app\n%s" % [typed, _status.text]


func _make_cell(info: PartLibrary.PartInfo) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(_z(74), _z(84))
	# LDraw pads its names into columns, "Brick  1 x  2", which reads as
	# a typo in a tooltip.
	button.tooltip_text = "%s\n%s\n%d x %d studs, %s" % [
		info.id, Inventory._tidy(info.name),
		info.footprint_studs().x, info.footprint_studs().y,
		_height_text(info)]
	# The id, on the button, rather than read back out of the tooltip.
	# The tooltip starts with the id and then a newline, so matching it
	# by prefix lights 30055 when you pick 3005 — and there is no reason
	# for a lookup to go through a string meant for a person.
	button.set_meta("part", info.id)
	button.toggle_mode = true
	# Clicked, a tile kept the keys: the arrows then walked the focus round
	# the grid, and Right never reached the timeline (the CAD task test,
	# 2026-10-16). So a click leaves the keys with the model, and only Tab
	# and the arrows bring them here, where Return takes the part.
	FocusGuard.by_keyboard(button)
	button.add_theme_stylebox_override("focus", FocusGuard.ring())
	# Its title, as a screen reader says it, and its number and size after.
	button.accessibility_name = "%s, %s" % [Inventory._tidy(info.name), info.id]
	button.accessibility_description = "%d x %d studs, %s" % [
		info.footprint_studs().x, info.footprint_studs().y, _height_text(info)]
	button.button_pressed = info.id == _selected_part
	button.pressed.connect(_on_part.bind(info.id))
	button.tooltip_text += "\nRight-click to keep it in Favourites, or drag it onto the model"
	button.gui_input.connect(func(event: InputEvent) -> void:
		_cell_input(button, info.id, event))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	button.add_child(box)

	# Its size is the cell's, never the picture's, so nothing moves when
	# the picture lands.
	# A print or sticker made here is drawn with its picture. The face it is
	# on is a surface of its own, which a plain picture leaves out: under My
	# prints every tile was a hole where its print should be.
	var made_print: bool = info.category in [PartPrints.MY_PRINTS, PartPrints.MY_STICKERS]
	var image := ThumbTile.new(info.id, _selected_color, made_print)
	image.custom_minimum_size = Vector2(0, _z(60))
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(image)
	button.set_meta("tile", image)

	var label := Label.new()
	var given: String = PartPrints.given_name(info.name) if info.id.begins_with("bw-") else ""
	label.text = given if not given.is_empty() else info.id
	if _set_parts.has(info.id):
		label.text = "%s  ×%d" % [info.id, int(_set_parts[info.id])]
		button.tooltip_text = "%d in %s\n%s" % [int(_set_parts[info.id]), set_shown, button.tooltip_text]
	if _guesses.has(info.id):
		label.text = "%s  %d%%" % [info.id, roundi(float(_guesses[info.id]) * 100.0)]
		button.tooltip_text = "Brickognize is %d%% sure of it\n%s" % [
			roundi(float(_guesses[info.id]) * 100.0), button.tooltip_text]
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Eleven, not nine: at a laptop's 0.92 nine was eight pixels high.
	label.add_theme_font_size_override("font_size", ceili(_z(11)))
	label.modulate = Color(1, 1, 1, 0.75)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if by_finger and _folds.has(info.id):
		# Its "+N" has the foot's right end, a fingertip (_fold_badge): the
		# number keeps to the room beside it.
		var foot := HBoxContainer.new()
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_theme_constant_override("separation", 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(label)
		var beside := Control.new()
		beside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		beside.custom_minimum_size.x = least + _z(2.0)
		foot.add_child(beside)
		box.add_child(foot)
	else:
		box.add_child(label)

	# A star in the corner for a part kept in Favourites.
	var star: TextureRect = Icons.picture(STAR, _z(14.0), Icons.density(self))
	star.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	star.offset_left = -_z(18.0)
	star.offset_right = -_z(4.0)
	star.offset_top = _z(4.0)
	star.offset_bottom = _z(18.0)
	star.visible = PartShelf.is_favourite(info.id)
	button.add_child(star)
	button.set_meta("star", star)
	if _folds.has(info.id):
		button.add_child(_fold_badge(info))

	_cells[info.id] = image
	if thumbnails:
		var ready_now: ImageTexture = thumbnails.peek(info.id, _selected_color, made_print)
		if ready_now:
			image.show_picture(ready_now, false)
	return button


## The count in a tile's corner of the prints, stickers and assemblies folded
## under it, which opens them after it and folds them again: a fingertip
## square on a phone or a tablet, in the tile's foot, clear of its picture.
## In the top corner it covered the picture's middle, and the first tap on
## a part with prints folded under it opened them rather than taking the
## part (walk256, T1). Not a stop for the keys, as no tile is (a field gives
## them back at Tab, FocusGuard); typed, "3008 print" and "3008 sticker" list
## them, unfolded, and its tooltip says so.
func _fold_badge(info: PartLibrary.PartInfo) -> Button:
	var count: int = (_folds[info.id] as Array).size()
	var opened: bool = _open.has(info.id)
	var badge := Button.new()
	badge.text = "%s%d" % ["−" if opened else "+", count]
	badge.tooltip_text = "%s %s print%s, sticker%s and assembl%s of %s; typed, \"%s print\" lists them" % [
		"Fold away" if opened else "Show", _comma(count), "" if count == 1 else "s",
		"" if count == 1 else "s", "y" if count == 1 else "ies", info.id, info.id]
	badge.focus_mode = Control.FOCUS_NONE
	# Eleven by a finger: ten came out under twelve points.
	badge.add_theme_font_size_override("font_size", ceili(_z(11.0 if by_finger else 10.0)))
	if by_finger:
		var across: Vector2 = Vector2(maxf(least, _z(24.0)), maxf(least, _z(18.0)))
		badge.custom_minimum_size = across
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_right = -_z(2.0)
		badge.offset_bottom = -_z(2.0)
		badge.offset_left = badge.offset_right - across.x
		badge.offset_top = badge.offset_bottom - across.y
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = _z(2.0)
		badge.offset_top = _z(2.0)
		badge.custom_minimum_size = Vector2(maxf(least, _z(24.0)), maxf(least, _z(18.0)))
	badge.pressed.connect(toggle_fold.bind(info.id))
	return badge


## A part pressed and dragged out of the bin: picked up, its ghost after
## the pointer over the model, and put down where it is let go (Main), as
## Studio and Mecabricks have it. A drag did nothing but carry the part's
## tooltip along with the pointer (brickworks.diy, 2026-10-12).
signal part_drag_moved(at: Vector2)
signal part_dropped(at: Vector2)
## How far the pointer goes with the button down before it is a drag.
const DRAG_START := 8.0
var _drag_from: Vector2 = Vector2.INF
var _drag_part: String = ""
## A finger dragged the grid since it came down (by_finger).
var _scrolled: bool = false
## Whose press began it: a finger's moves are taken from it alone.
var _drag_device: int = 0


func is_dragging_part() -> bool:
	return not _drag_part.is_empty()


func _cell_input(button: Button, part_id: String, event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null:
		if press.button_index == MOUSE_BUTTON_RIGHT and press.pressed:
			_toggle_favourite(part_id)
			button.accept_event()
		elif press.button_index == MOUSE_BUTTON_LEFT and press.pressed:
			_drag_from = press.global_position
			_drag_device = press.device
			_scrolled = false
		elif press.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = Vector2.INF
			# A finger that scrolled the grid let go: no part is picked.
			if _scrolled:
				_scrolled = false
				button.accept_event()
				return
			if not _drag_part.is_empty():
				_drag_part = ""
				button.tooltip_text = str(button.get_meta("tip", button.tooltip_text))
				part_dropped.emit(press.global_position)
		return
	var motion := event as InputEventMouseMotion
	if motion == null or _drag_from == Vector2.INF \
			or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if by_finger:
		if _scrolled or motion.global_position.distance_to(_drag_from) >= DRAG_START:
			# The tile's press let go as a ScrollContainer lets go of a row's:
			# a touch's own lift, after the mouse's, tapped the tile still
			# under the finger and took the part.
			if not _scrolled:
				button.notification(NOTIFICATION_SCROLL_BEGIN)
			_scrolled = true
			# A finger's move once. On the web it comes twice, as the touch's
			# (DEVICE_ID_EMULATION) and as the page's pointermove, read as a
			# mouse's: the grid went 2.09 points for each the finger went.
			if motion.device == _drag_device:
				_scroll.scroll_vertical -= roundi(motion.relative.y)
			button.accept_event()
		return
	if _drag_part.is_empty():
		if motion.global_position.distance_to(_drag_from) < DRAG_START:
			return
		_drag_part = part_id
		# No tooltip while it is carried: it followed the pointer out.
		button.set_meta("tip", button.tooltip_text)
		button.tooltip_text = ""
		_on_part(part_id)
	part_drag_moved.emit(motion.global_position)
	button.accept_event()


static func _height_text(info: PartLibrary.PartInfo) -> String:
	var plates: int = int(round(info.size.y / 8.0))
	if plates <= 1:
		return "1 plate"
	if plates == 3:
		return "1 brick"
	return "%d plates" % plates


func _on_part(part_id: String) -> void:
	var by_keyboard: bool = FocusGuard.keys_with_a_control(get_viewport())
	_selected_part = part_id
	PartShelf.used(part_id)
	_refresh_shelf()
	# The clicked one stays lit. This set every cell unpressed including
	# the one just pressed, so choosing a part looked like choosing
	# nothing — the only sign anything had happened was the ghost.
	for child: Node in _grid.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("part", "")) == part_id
	_mark_swatches()
	part_chosen.emit(part_id)
	_keys_to_model(by_keyboard)


## After a part or a construction is chosen from the keyboard: the keys are
## the model's, to aim what is in hand and put it down.
func _keys_to_model(by_keyboard: bool) -> void:
	if not by_keyboard:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	chose_by_keyboard.emit()


## Follow a part and colour that were chosen somewhere else — the
## eyedropper.
##
## Reuses the ordinary colour handler rather than repeating what it
## does, including redrawing the grid: previews are rendered per colour,
## so a palette that changed without them would show the new colour
## selected above a grid of the old one.
func show_held(part_id: String, color_code: int) -> void:
	_selected_part = part_id
	PartShelf.used(part_id)
	_refresh_shelf()
	if color_code != _selected_color:
		_on_colour(color_code)
	for child: Node in _grid.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("part", "")) == part_id
	_mark_swatches()


func selected_color() -> int:
	return _selected_color


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	var count: int = 0
	for n: int in range(text.length() - 1, -1, -1):
		out = text[n] + out
		count += 1
		if count % 3 == 0 and n > 0:
			out = "," + out
	return out


func focus_search() -> void:
	_search.grab_focus()
	_search.select_all()


# -- worked constructions -----------------------------------------------------


## How many constructions the Techniques show, for what is typed.
var _techniques_shown: int = 0
## What was in sight when the Techniques' tiles were last told (_process).
var _techniques_seen: Array = []
## An assistant of the bin's own that reads a construction as a design's
## words are read (Techniques.as_ldraw): never the one designing, whose
## reading of its own model that would reset.
var _reading: Assistant


func _reader() -> Assistant:
	if _reading == null:
		_reading = Assistant.new()
		_reading.library = library
		_reading.builder = builder
		add_child(_reading)
	return _reading


## The worked constructions, in the order show_technique lists them: by what
## they are for, and under that one a row, with its picture and why it
## works. What is typed finds them (Techniques.found): the groups the best
## of it is in first, and in each the best first.
func _fill_techniques(query: String) -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cells.clear()
	_shown = 0
	_scroll.scroll_vertical = 0
	_grid.columns = 1
	_techniques_seen = []
	_techniques_shown = 0
	var listed: Array = Techniques.all()
	var groups: Array = Techniques.GROUPS
	if not query.strip_edges().is_empty():
		listed = Techniques.found(query).map(func(one: Array) -> Dictionary: return one[1])
		groups = []
		for technique: Dictionary in listed:
			if not groups.has(str(technique.get("group", ""))):
				groups.append(str(technique.get("group", "")))
	for group: String in groups:
		var titled: bool = false
		for one: Variant in listed:
			var technique: Dictionary = one
			if str(technique.get("group", "")) != group:
				continue
			if not titled:
				titled = true
				var title := Label.new()
				title.text = Techniques.title(group)
				title.add_theme_font_size_override("font_size", ceili(_z(11)))
				title.modulate = Color(1, 1, 1, 0.7)
				_grid.add_child(title)
			_grid.add_child(_technique_cell(technique))
			_techniques_shown += 1
	_update_status()


func _technique_cell(technique: Dictionary) -> Control:
	var name: String = str(technique["name"])
	var id: String = TECHNIQUE + name
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, _z(64))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	FocusGuard.by_keyboard(button)
	button.add_theme_stylebox_override("focus", FocusGuard.ring())
	button.set_meta("technique", name)
	button.accessibility_name = Techniques.title(name)
	button.accessibility_description = "%s. %d parts" % [Techniques.reason(technique),
		(technique["bricks"] as Array).size()]
	button.tooltip_text = "%s: %s.\n\n%s\n\n%d parts: choose it to hold it whole" % [
		Techniques.title(name), technique["when"], technique["why"],
		(technique["bricks"] as Array).size()]
	button.pressed.connect(_on_technique.bind(name))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = _z(2)
	row.offset_right = -_z(6)
	row.add_theme_constant_override("separation", int(_z(8)))
	button.add_child(row)
	var image := ThumbTile.new(id, _selected_color)
	image.custom_minimum_size = Vector2(_z(60), _z(60))
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(image)
	button.set_meta("tile", image)
	_cells[id] = image

	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var title := Label.new()
	title.text = Techniques.title(name)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.add_theme_font_size_override("font_size", ceili(_z(12)))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(title)
	var reason := Label.new()
	reason.text = Techniques.reason(technique)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.max_lines_visible = 2
	reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason.add_theme_font_size_override("font_size", ceili(_z(11)))
	reason.modulate = Color(1, 1, 1, 0.75)
	reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(reason)

	if thumbnails:
		thumbnails.offer_group(id, Techniques.parts_of(technique), func(colour: int) -> Array:
			return Carry.from_ldraw(Techniques.as_ldraw(technique, _reader(), colour), library))
		var ready_now: ImageTexture = thumbnails.peek(id, _selected_color)
		if ready_now:
			image.show_picture(ready_now, false)
	return button


## The Techniques' tiles, those in sight first and top down, then those
## below and those above. Its rows are not all one height, as a grid of
## parts' are, so ThumbTile.Sight cannot say.
func _technique_tiles() -> Array[ThumbTile]:
	var window := Rect2(Vector2(0, _scroll.scroll_vertical), _scroll.size)
	var seen: Array[ThumbTile] = []
	var below: Array[ThumbTile] = []
	var above: Array[ThumbTile] = []
	for cell: Node in _grid.get_children():
		if not cell.has_meta("tile"):
			continue
		var tile: ThumbTile = cell.get_meta("tile")
		var box := Rect2((cell as Control).position, (cell as Control).size)
		tile.in_sight = box.intersects(window)
		if tile.in_sight:
			seen.append(tile)
		elif box.position.y >= window.end.y:
			below.append(tile)
		else:
			above.push_front(tile)
	seen.append_array(below)
	seen.append_array(above)
	return seen


## A construction chosen: its parts, in the colour in hand where its main
## colour was, held whole once each one's geometry is here (Main).
func _on_technique(name: String) -> void:
	var by_keyboard: bool = FocusGuard.keys_with_a_control(get_viewport())
	for child: Node in _grid.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("technique", "")) == name
	var parts: Array = await technique_parts(name, _selected_color)
	if parts.is_empty():
		_status.text = "%s could not be had: its parts did not load" % name
		return
	construction_chosen.emit(parts, name)
	_keys_to_model(by_keyboard)


## A construction's parts as Carry holds them, in [param colour] where its
## main colour was: written as LDraw lines and read back, the path a paste
## takes. Waits for any part not here yet, which the web fetches.
func technique_parts(name: String, colour: int) -> Array:
	var technique: Dictionary = Techniques.named(name)
	if technique.is_empty():
		return []
	var reader: Assistant = _reader()
	await reader._ensure_parts(reader._read_model({"bricks": technique["bricks"],
		"sections": technique.get("sections", []),
		"repeat_section": technique.get("repeat_section", [])}))
	return Carry.from_ldraw(Techniques.as_ldraw(technique, reader, colour), library)


# -- a part from a photo ------------------------------------------------------


## The camera in the search field.
const PHOTO := "res://assets/ui/tools/photo.svg"
var _photo_button: Button
var _picker: PickImage
var _brickognize: Brickognize
var _telling: ConfirmationDialog
## A set's parts, shown as the bin's results (show_set, /app?parts=<set>):
## id -> how many of it the set has, and which set, in words. Empty once
## anything else is shown.
var _set_parts: Dictionary = {}
var set_shown: String = ""


## A set's parts as the bin's results (sets364): each part its inventory
## has ([lots]: [[part, colour, qty], ...], tools/collection_data.py's), the
## most used first, as the photo's answer is shown; [title] says which set.
## Its parts in every colour are one tile, the colour in hand the bin's.
## Returns how many parts it could show.
func show_set(title: String, lots: Array) -> int:
	var counts: Dictionary = {}
	for row: Variant in lots:
		if not row is Array or (row as Array).size() < 3:
			continue
		var id: String = library.resolve(str(row[0]))
		counts[id] = int(counts.get(id, 0)) + int(row[2])
	var found: Array[PartLibrary.PartInfo] = []
	for id: String in counts:
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info != null and info.reachable and not info.is_redirect():
			found.append(info)
	found.sort_custom(func(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
		return int(counts[a.id]) > int(counts[b.id]) if int(counts[a.id]) != int(counts[b.id]) else a.id < b.id)
	if found.is_empty():
		return 0
	if _category == TECHNIQUES:
		_category = "All"
		for child: Node in _category_row.get_children():
			(child as Button).button_pressed = str(child.get_meta("category", "")) == _category
	_guesses.clear()
	_results = found
	_set_parts = counts
	set_shown = title
	_fill_grid()
	return found.size()


## Which set's parts the bin shows, or "" when it shows anything else.
func set_showing() -> String:
	return set_shown if not _set_parts.is_empty() else ""


## The parts a photo was answered with, by id -> how sure Brickognize is:
## the bin's results while they are shown, and empty once anything else is.
var _guesses: Dictionary = {}
## What of the answer the bin has no part for, said on the status line's tooltip.
var _guessed_note: String = ""
## The colour the photo was seen in, by name, or "".
var _guessed_colour: String = ""
## How sure Brickognize must be of a photo's colour for it to be taken.
const COLOUR_LEAST := 0.3


## A button in the search field, at its end, as the field's own clear button
## is: the field keeps its text clear of it.
func _add_photo_button() -> void:
	_photo_button = Button.new()
	_photo_button.flat = true
	FocusGuard.by_keyboard(_photo_button)
	_photo_button.tooltip_text = "Find a part from a photo of it"
	_photo_button.accessibility_name = "Find a part from a photo"
	_photo_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var wide: float = maxf(_z(26), least)
	_photo_button.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_photo_button.offset_left = -wide
	_photo_button.offset_right = 0
	_photo_button.pressed.connect(_ask_photo)
	_search.add_child(_photo_button)
	var picture: TextureRect = Icons.picture(PHOTO, _z(16.0), Icons.density(self))
	picture.set_anchors_preset(Control.PRESET_CENTER)
	picture.grow_horizontal = Control.GROW_DIRECTION_BOTH
	picture.grow_vertical = Control.GROW_DIRECTION_BOTH
	picture.modulate = Color(1, 1, 1, 0.8)
	_photo_button.add_child(picture)
	for kind: String in ["normal", "read_only"]:
		var style: StyleBox = _search.get_theme_stylebox(kind).duplicate()
		style.content_margin_right = maxf(style.content_margin_right, 0.0) + wide
		_search.add_theme_stylebox_override(kind, style)

	_picker = PickImage.new()
	_picker.camera = by_finger
	_picker.picked.connect(_identify)
	_picker.failed.connect(func(why: String) -> void:
		if why != "no picture chosen":
			_status.text = why)
	add_child(_picker)
	_brickognize = Brickognize.new()
	_brickognize.answered.connect(show_guesses)
	_brickognize.failed.connect(func(why: String) -> void:
		_status.text = why
		_status.tooltip_text = why)
	add_child(_brickognize)


## The camera pressed: the photo goes to Brickognize, a third party, which
## is said before the first one and never sent without one chosen.
func _ask_photo() -> void:
	if bool(ShellPrefs.value("photo_told")):
		# Straight from the press: a browser opens its picker only while a
		# real click is still being handled (PickImage).
		_picker.ask()
		return
	if _telling == null:
		_telling = ConfirmationDialog.new()
		_telling.title = "Find a part from a photo"
		_telling.dialog_text = ("The photo you choose is sent to Brickognize "
			+ "(brickognize.com), a third party that identifies LEGO® parts. Under its "
			+ "terms it may keep the photo and use it to train its recognition.\n\n"
			+ "Nothing is sent until you choose a photo.")
		_telling.dialog_autowrap = true
		_telling.ok_button_text = "Choose a photo"
		_telling.confirmed.connect(func() -> void:
			ShellPrefs.put("photo_told", true)
			_picker.ask())
		add_child(_telling)
	_telling.popup_centered(Vector2i(roundi(_z(420)), 0))


func _identify(photo: Image) -> void:
	_status.text = "Asking Brickognize what part this is…"
	_status.tooltip_text = ""
	_brickognize.identify(photo)


## A photo's answer as the bin's results: each guess's BrickLink number as
## the part here, most likely first, with how sure Brickognize is.
func show_guesses(guesses: Array) -> void:
	var found: Array[PartLibrary.PartInfo] = []
	var scores: Dictionary = {}
	var none: PackedStringArray = PackedStringArray()
	for guess: Dictionary in guesses:
		var id: String = library.by_shop(str(guess["bricklink"]))
		var info: PartLibrary.PartInfo = library.parts.get(id)
		if info == null or not info.reachable:
			none.append(str(guess["bricklink"]))
			continue
		if scores.has(id):
			continue
		scores[id] = float(guess["score"])
		found.append(info)
	_guessed_note = "" if none.is_empty() else (
		"Also named, and not parts here: BrickLink %s" % ", ".join(none))
	if found.is_empty():
		_status.text = ("Brickognize saw no part it knows in that photo: try another, the part "
			+ "alone on a plain background") if guesses.is_empty() \
			else "Brickognize named parts this build has not got: %s" % ", ".join(none)
		_status.tooltip_text = _status.text
		return
	# Parts, not constructions: what was shown under Techniques gives way.
	if _category == TECHNIQUES:
		_category = "All"
		for child: Node in _category_row.get_children():
			(child as Button).button_pressed = str(child.get_meta("category", "")) == _category
	_results = found
	_guesses = scores
	# In the colour the photo shows, taken in hand as an element number's
	# is: the photo of a black slope was shown in red, the colour that was
	# in hand (walk256 S3). Kept as it is where Brickognize is not sure.
	_guessed_colour = ""
	var seen: Dictionary = _brickognize.colour
	var code: int = int(PartLibrary.by_bricklink.get(int(seen.get("bricklink", -1)), -1)) \
		if not seen.is_empty() and float(seen.get("score", 0.0)) >= COLOUR_LEAST else -1
	if code >= 0 and library.colors.has(code):
		_guessed_colour = library.color(code).name
		if code != _selected_color:
			_on_colour(code)
	_fill_grid()
