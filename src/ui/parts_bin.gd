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
## on screen.
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
	"Brick", "Plate", "Tile", "Slope", "Technic", "Wedge", "Panel",
	"Bracket", "Arch", "Hinge", "Plant", "Animal", "Minifig",
]

## Categories kept out of the default view. They are still searchable and
## still have their own button; they are simply not what anyone means by
## "show me the parts".
const BURIED: Array[String] = ["Sticker", "Obsolete", "Moved"]

## The colours offered as swatches: the standard palette a set is
## actually moulded in, rather than all 322 including one-offs.
const SWATCHES: Array[int] = [
	15, 71, 7, 72, 0, 4, 5, 27, 2, 10, 1, 9, 14, 25, 70, 28,
	19, 84, 26, 22, 3, 73, 6, 272, 288, 320, 191, 226, 212, 308,
	47, 40, 36, 33, 34, 43, 41, 46, 379, 378, 383, 297, 80, 135,
]

var library: PartLibrary
var thumbnails: PartThumbnails

## How many parts can be placed at all, and how many of those the default
## view sets aside. Both are shown, because a bin that says "20,581" to
## someone who was told there are 29,479 parts looks broken.
var _offerable: int = 0
var _set_aside: int = 0

var _search: LineEdit
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _swatch_row: FlowContainer
var _category_row: FlowContainer

var _category: String = "All"
var _results: Array[PartLibrary.PartInfo] = []
var _shown: int = 0
var _categories: Array[String] = []
var _cells: Dictionary = {}            ## part id -> TextureRect
var _selected_part: String = ""
var _selected_color: int = 4
var _search_at: int = 0
var _pending: bool = false

signal part_chosen(part_id: String)
signal color_chosen(color_code: int)


func _ready() -> void:
	custom_minimum_size = Vector2(336, 0)
	_build()
	set_process(true)


func _build() -> void:
	# An opaque backing, or the model shows through the text. Slightly
	# translucent so the viewport still reads as continuous behind it.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 10
	backing.content_margin_bottom = 10
	add_theme_stylebox_override("panel", backing)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "Parts"
	title.add_theme_font_size_override("font_size", 16)
	root.add_child(title)

	_search = LineEdit.new()
	# Filled in once the catalogue is loaded; the count differs between
	# the desktop build and the web pack.
	_search.placeholder_text = "Search parts…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_typed)
	root.add_child(_search)

	# Built from the catalogue once it is loaded, not from a fixed list.
	var category_scroll := ScrollContainer.new()
	category_scroll.custom_minimum_size = Vector2(0, 58)
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(category_scroll)

	_category_row = FlowContainer.new()
	_category_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_row.add_theme_constant_override("h_separation", 4)
	_category_row.add_theme_constant_override("v_separation", 4)
	category_scroll.add_child(_category_row)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_scroll.add_child(_grid)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.6)
	# Two lines when it needs them. The line has to carry where the rest
	# of the catalogue went, and truncating that leaves the bin looking
	# short of parts with no explanation — the thing the line is for.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var colour_title := Label.new()
	colour_title.text = "Colour"
	colour_title.add_theme_font_size_override("font_size", 13)
	root.add_child(colour_title)

	_swatch_row = FlowContainer.new()
	_swatch_row.add_theme_constant_override("h_separation", 3)
	_swatch_row.add_theme_constant_override("v_separation", 3)
	root.add_child(_swatch_row)


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

	_categories = ["All"]
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
		button.toggle_mode = true
		button.button_pressed = category == _category
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_on_category.bind(category))
		_category_row.add_child(button)


func _build_swatches() -> void:
	for child: Node in _swatch_row.get_children():
		child.queue_free()
	for code: int in SWATCHES:
		var color: PartLibrary.BrickColor = library.color(code)
		var button := Button.new()
		button.custom_minimum_size = Vector2(22, 22)
		button.tooltip_text = "%s (%d)" % [color.name, code]
		button.toggle_mode = true
		button.button_pressed = code == _selected_color

		var style := StyleBoxFlat.new()
		style.bg_color = color.rgb
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		# Transparent plastic needs to read as transparent in a swatch, or
		# trans-clear and white are the same square.
		if color.is_transparent():
			style.border_width_bottom = 4
			style.border_color = Color(color.rgb, 1.0).darkened(0.35)
		button.add_theme_stylebox_override("normal", style)

		var chosen: StyleBoxFlat = style.duplicate()
		chosen.border_width_left = 2
		chosen.border_width_right = 2
		chosen.border_width_top = 2
		chosen.border_width_bottom = 2
		chosen.border_color = Color(1, 1, 1, 0.95)
		button.add_theme_stylebox_override("pressed", chosen)
		button.add_theme_stylebox_override("hover", chosen)

		button.pressed.connect(_on_colour.bind(code))
		_swatch_row.add_child(button)


func _on_colour(code: int) -> void:
	_selected_color = code
	for child: Node in _swatch_row.get_children():
		var button: Button = child
		button.button_pressed = button.tooltip_text.ends_with("(%d)" % code)
	color_chosen.emit(code)
	# Previews are per colour, so the grid has to be redrawn.
	_fill_grid()


func _on_category(name: String) -> void:
	_category = name
	for child: Node in _category_row.get_children():
		var button: Button = child
		button.button_pressed = button.tooltip_text == name
	_run_search(_search.text)


func _on_search_typed(_text: String) -> void:
	# Debounced: a held key would otherwise scan the library per character.
	_search_at = Time.get_ticks_msec()
	_pending = true


func _process(_delta: float) -> void:
	if _pending and Time.get_ticks_msec() - _search_at >= SEARCH_DEBOUNCE:
		_pending = false
		_run_search(_search.text)

	# Grow the grid as it is scrolled. Checking here rather than on a
	# scroll signal covers the case where the window is resized and the
	# existing page no longer fills it.
	if _shown < _results.size() and _scroll != null:
		var bar: VScrollBar = _scroll.get_v_scroll_bar()
		if bar.max_value <= 0.0:
			return
		var remaining: float = bar.max_value - bar.value - bar.page
		if remaining < 260.0:
			_show_more()


func _run_search(query: String) -> void:
	if library == null:
		return
	_results = _find(query.strip_edges(), _category)
	_fill_grid()


## Search, ranked so the plain part comes before its printed variants.
##
## A plain substring match over the catalogue is fast enough to do
## outright and never surprises anyone, which a fuzzy match would. What
## it does need is ordering: "brick 2 x 4" matches 3001 and several
## hundred stickered and printed versions of 3001, and only one of those
## is what was meant.
func _find(query: String, category: String) -> Array[PartLibrary.PartInfo]:
	var needles: PackedStringArray = query.to_lower().split(" ", false)
	var wanted_category: String = category.to_lower()
	var found: Array[PartLibrary.PartInfo] = []
	var set_aside: int = 0

	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect():
			continue
		if not info.reachable:
			continue  # no geometry anywhere in this build
		if wanted_category == "all":
			# Stickers and superseded parts are still findable by name or
			# by their own button; they are just not what anyone means by
			# "show me the parts". Counted as they are skipped so the
			# status line can say how many and where they went — silently
			# dropping 7,738 parts is indistinguishable from losing them.
			if needles.is_empty() and _is_buried(info.category):
				set_aside += 1
				continue
		elif info.category.to_lower() != wanted_category:
			continue

		if not needles.is_empty():
			var haystack: String = (
				info.id + " " + info.name + " " + info.category).to_lower()
			var matched: bool = true
			for needle: String in needles:
				if not haystack.contains(needle):
					matched = false
					break
			if not matched:
				continue

		found.append(info)

	_set_aside = set_aside
	_sort_for(found, query)
	return found


## Sort results for a query: match quality first, then staple-ness.
static func _sort_for(found: Array[PartLibrary.PartInfo], query: String) -> void:
	var scores: Dictionary = {}
	for info: PartLibrary.PartInfo in found:
		scores[info.id] = _staple_score(info) + _match_score(info, query)

	found.sort_custom(func(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
		var a_score: int = scores[a.id]
		var b_score: int = scores[b.id]
		if a_score != b_score:
			return a_score > b_score
		var a_area: int = a.footprint_studs().x * a.footprint_studs().y
		var b_area: int = b.footprint_studs().x * b.footprint_studs().y
		if a_area != b_area:
			return a_area < b_area
		return a.id.naturalnocasecmp_to(b.id) < 0)


static func _rank_shared(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
	var a_score: int = _staple_score(a)
	var b_score: int = _staple_score(b)
	if a_score != b_score:
		return a_score > b_score
	# Within a tier, the smaller part first: a bin reads better going up
	# in size than jumping about.
	var a_area: int = a.footprint_studs().x * a.footprint_studs().y
	var b_area: int = b.footprint_studs().x * b.footprint_studs().y
	if a_area != b_area:
		return a_area < b_area
	return a.id.naturalnocasecmp_to(b.id) < 0


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

	if name == wanted:
		score += 400                      # exactly the thing named
	elif name.begins_with(wanted):
		score += 260                      # the thing, plus a qualifier
	elif name.contains(wanted):
		score += 140                      # the words, in order, somewhere
	if _squeeze(info.id) == wanted:
		score += 500                      # asked for by number
	return score


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
	for child: Node in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_shown = 0
	if thumbnails:
		thumbnails.clear_queue()
	_scroll.scroll_vertical = 0
	_show_more()


## Add the next page of cells. Called on first fill and again whenever
## the scroll reaches the end, so the whole result set is reachable
## without ever building 28,000 controls.
func _show_more() -> void:
	var limit: int = mini(_shown + PAGE, _results.size())
	while _shown < limit:
		_grid.add_child(_make_cell(_results[_shown]))
		_shown += 1
	_update_status()


func _update_status() -> void:
	var total: int = _results.size()
	if total == 0:
		_status.text = "nothing matches"
	elif _shown >= total:
		_status.text = "%s part%s" % [_comma(total), "" if total == 1 else "s"]
	else:
		_status.text = "%s of %s — scroll for more" % [
			_comma(_shown), _comma(total)]

	# Where the rest went. Only on the default view, since that is the
	# only place anything is held back.
	if _set_aside > 0:
		_status.text += "\n%s stickers and obsolete parts set aside — search finds them" % _comma(_set_aside)
	_status.tooltip_text = ("%s parts can be placed in this build"
		% _comma(_offerable))


func _make_cell(info: PartLibrary.PartInfo) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(74, 84)
	button.tooltip_text = "%s\n%s\n%d x %d studs, %s" % [
		info.id, info.name.strip_edges(),
		info.footprint_studs().x, info.footprint_studs().y,
		_height_text(info)]
	button.toggle_mode = true
	button.button_pressed = info.id == _selected_part
	button.pressed.connect(_on_part.bind(info.id))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	button.add_child(box)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(0, 60)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(image)

	var label := Label.new()
	label.text = info.id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(1, 1, 1, 0.65)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	_cells[info.id] = image
	if thumbnails:
		var ready_now: ImageTexture = thumbnails.request(info.id, _selected_color)
		if ready_now:
			image.texture = ready_now
	return button


static func _height_text(info: PartLibrary.PartInfo) -> String:
	var plates: int = int(round(info.size.y / 8.0))
	if plates <= 1:
		return "1 plate"
	if plates == 3:
		return "1 brick"
	return "%d plates" % plates


func _on_part(part_id: String) -> void:
	_selected_part = part_id
	for child: Node in _grid.get_children():
		var button: Button = child
		button.button_pressed = false
	part_chosen.emit(part_id)


## Called by the thumbnailer when a preview finishes.
func on_thumbnail(part_id: String, color_code: int, texture: ImageTexture) -> void:
	if color_code != _selected_color:
		return
	var cell: TextureRect = _cells.get(part_id)
	if cell != null and is_instance_valid(cell):
		cell.texture = texture


## Geometry the web build had to fetch has landed. Ask again for the
## preview that could not be drawn without it — but only if that part is
## still on screen, so a scroll does not draw thumbnails for a page
## nobody is looking at any more.
func on_geometry_arrived(part_id: String) -> void:
	var cell: TextureRect = _cells.get(part_id)
	if cell == null or not is_instance_valid(cell) or cell.texture != null:
		return
	if thumbnails:
		thumbnails.request(part_id, _selected_color)


## Follow a part and colour that were chosen somewhere else — the
## eyedropper.
##
## Reuses the ordinary colour handler rather than repeating what it
## does, including redrawing the grid: previews are rendered per colour,
## so a palette that changed without them would show the new colour
## selected above a grid of the old one.
func show_held(part_id: String, color_code: int) -> void:
	_selected_part = part_id
	if color_code != _selected_color:
		_on_colour(color_code)
	for child: Node in _grid.get_children():
		var button: Button = child
		button.button_pressed = button.tooltip_text.begins_with(part_id)


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
