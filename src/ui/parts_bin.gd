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
const RESULT_LIMIT := 240
## Milliseconds of quiet before a search runs. Long enough that typing a
## word is one search, short enough to feel immediate.
const SEARCH_DEBOUNCE := 160

## Categories worth a button, in the order a builder reaches for them.
const CATEGORIES: Array[String] = [
	"All", "Brick", "Plate", "Tile", "Slope", "Technic", "Wedge",
	"Round", "Arch", "Panel", "Bracket", "Hinge", "Vehicle", "Minifig",
]

## The colours offered as swatches: the standard palette a set is
## actually moulded in, rather than all 322 including one-offs.
const SWATCHES: Array[int] = [
	15, 71, 7, 72, 0, 4, 5, 27, 2, 10, 1, 9, 14, 25, 70, 28,
	19, 84, 26, 22, 3, 73, 6, 272, 288, 320, 191, 226, 212, 308,
	47, 40, 36, 33, 34, 43, 41, 46, 379, 378, 383, 297, 80, 135,
]

var library: PartLibrary
var thumbnails: PartThumbnails

var _search: LineEdit
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _swatch_row: FlowContainer
var _category_row: FlowContainer

var _category: String = "Brick"
var _results: Array[PartLibrary.PartInfo] = []
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
	_search.placeholder_text = "Search 24,731 parts…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search_typed)
	root.add_child(_search)

	_category_row = FlowContainer.new()
	_category_row.add_theme_constant_override("h_separation", 4)
	_category_row.add_theme_constant_override("v_separation", 4)
	root.add_child(_category_row)
	for name: String in CATEGORIES:
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.button_pressed = name == _category
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_category.bind(name))
		_category_row.add_child(button)

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
	_build_swatches()
	_run_search("")


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
		button.button_pressed = button.text == name
	_run_search(_search.text)


func _on_search_typed(_text: String) -> void:
	# Debounced: a held key would otherwise scan the library per character.
	_search_at = Time.get_ticks_msec()
	_pending = true


func _process(_delta: float) -> void:
	if _pending and Time.get_ticks_msec() - _search_at >= SEARCH_DEBOUNCE:
		_pending = false
		_run_search(_search.text)


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

	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.is_redirect():
			continue
		if not info.packed:
			continue  # no geometry in this build; cannot be placed
		if wanted_category != "all":
			if not info.category.to_lower().begins_with(wanted_category):
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
		if found.size() >= RESULT_LIMIT * 4:
			break

	_sort_for(found, query)
	if found.size() > RESULT_LIMIT:
		found.resize(RESULT_LIMIT)
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
	var name: String = info.name.strip_edges()
	var lowered: String = name.to_lower()
	var score: int = 0

	# A bare "<Family> N x M" is the plainest form there is.
	if PLAIN.search(name) != null:
		score += 100
	# A qualifier after the size ("with Groove", "Inverted") is still a
	# real part, just a more specific one.
	elif QUALIFIED.search(name) != null:
		score += 60

	if lowered.begins_with("brick"):
		score += 14
	elif lowered.begins_with("plate"):
		score += 12
	elif lowered.begins_with("tile"):
		score += 10
	elif lowered.begins_with("slope"):
		score += 8

	if _is_decorated(info):
		score -= 70
	if info.unofficial:
		score -= 40
	# Shortcuts are assemblies, not parts; useful but not staples.
	if info.kind.to_lower().contains("shortcut"):
		score -= 25
	# Long names mean many qualifiers, which means a specialist part.
	score -= name.length() / 8
	return score


static var PLAIN := RegEx.create_from_string(
	"^(Brick|Plate|Tile|Slope|Panel|Wedge)\\s+\\d+\\s*x\\s*\\d+$")
static var QUALIFIED := RegEx.create_from_string(
	"^(Brick|Plate|Tile|Slope|Panel|Wedge)\\s+\\d+\\s*x\\s*\\d+\\s")


static func _is_decorated(info: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.to_lower()
	return (name.contains("pattern") or name.contains("sticker")
		or name.contains("print"))


func _fill_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_cells.clear()
	if thumbnails:
		thumbnails.clear_queue()

	for info: PartLibrary.PartInfo in _results:
		_grid.add_child(_make_cell(info))

	var shown: int = _results.size()
	if shown == 0:
		_status.text = "nothing matches"
	elif shown >= RESULT_LIMIT:
		_status.text = "first %d matches" % shown
	else:
		_status.text = "%d part%s" % [shown, "" if shown == 1 else "s"]


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


func selected_color() -> int:
	return _selected_color


func focus_search() -> void:
	_search.grab_focus()
	_search.select_all()
