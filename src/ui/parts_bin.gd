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
var _colour_note: Label
var _swatches: Dictionary = {}         ## int code -> Swatch
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

	var colour_head := HBoxContainer.new()
	root.add_child(colour_head)
	var colour_title := Label.new()
	colour_title.text = "Colour"
	colour_title.add_theme_font_size_override("font_size", 13)
	colour_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colour_head.add_child(colour_title)
	_all_colours = Button.new()
	_all_colours.toggle_mode = true
	_all_colours.flat = true
	_all_colours.focus_mode = Control.FOCUS_NONE
	_all_colours.add_theme_font_size_override("font_size", 11)
	_all_colours.toggled.connect(func(_on: bool) -> void: _build_swatches())
	colour_head.add_child(_all_colours)

	# Scrolls rather than grows: three hundred colours shown at once would
	# push the parts grid off the bottom of the panel.
	_palette_scroll = ScrollContainer.new()
	_palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_palette_scroll.custom_minimum_size = Vector2(0, 168)
	root.add_child(_palette_scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette.add_theme_constant_override("separation", 2)
	_palette_scroll.add_child(_palette)

	_colour_note = Label.new()
	_colour_note.add_theme_font_size_override("font_size", 11)
	_colour_note.modulate = Color(1, 1, 1, 0.7)
	_colour_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_colour_note)


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
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_category.bind(category))
		_category_row.add_child(button)


func _build_swatches() -> void:
	for child: Node in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	_swatches.clear()
	var everything: bool = _all_colours.button_pressed

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
		title.add_theme_font_size_override("font_size", 10)
		title.modulate = Color(1, 1, 1, 0.55)
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


func _flow_of(colors: Array[PartLibrary.BrickColor]) -> FlowContainer:
	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	for color: PartLibrary.BrickColor in colors:
		var swatch := Swatch.new(color)
		swatch.set_pressed_no_signal(color.code == _selected_color)
		swatch.pressed.connect(_on_colour.bind(color.code))
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
	# Previews are per colour, so the grid has to be redrawn.
	_fill_grid()


## Which colours the part in hand was really made in: those carry a dot.
## A colour it was never made in is dimmed, not hidden — a builder may
## want it anyway — and only where the part's list is complete, which
## for every one of the forty most used parts it is not (some of their
## colours have no LDraw counterpart), so the dot is what mostly shows.
func _mark_swatches() -> void:
	if library == null:
		return
	var info: PartLibrary.PartInfo = library.parts.get(_selected_part)
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
	var color: PartLibrary.BrickColor = library.color(_selected_color)
	var text: String = "%s, %s" % [color.name, color.finish_name()]
	var info: PartLibrary.PartInfo = library.parts.get(_selected_part)
	if info != null and info.availability_known():
		text += ". A dot marks the %d colours %s comes in" % [info.colors.size(), info.id]
		if not info.colors_partial:
			text += "; it was made in no other"
	_colour_note.text = text


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
		focus_mode = Control.FOCUS_NONE
		var nothing := StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, nothing)
		set_meta("code", of.code)

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
## LDraw suffixes a printed part with p and a number: 3001p01.
static var PRINTED: RegEx = RegEx.create_from_string("p[0-9]+[a-z]?$")


static func _sort_for(found: Array[PartLibrary.PartInfo], query: String) -> void:
	var scores: Dictionary = {}
	for info: PartLibrary.PartInfo in found:
		scores[info.id] = _staple_score(info) + _match_score(info, query) \
			+ _usage_score(info)

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
	if (name.begins_with("=") or name.begins_with("~")
			or lowered.contains("pattern") or PRINTED.search(info.id) != null):
		score -= 400

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
		_status.text = "Showing %s of %s — scroll for more" % [
			_comma(_shown), _comma(total)]

	# Where the rest went. Only on the default view, since that is the
	# only place anything is held back.
	if _set_aside > 0:
		_status.text += "\nStickers and retired parts are left out; search finds them."
		_status.tooltip_text = "%s stickers and retired parts" % _comma(_set_aside)
	if _set_aside == 0:
		_status.tooltip_text = ("%s parts can be placed in this build"
			% _comma(_offerable))


func _make_cell(info: PartLibrary.PartInfo) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(74, 84)
	button.tooltip_text = "%s\n%s\n%d x %d studs, %s" % [
		info.id, info.name.strip_edges(),
		info.footprint_studs().x, info.footprint_studs().y,
		_height_text(info)]
	# The id, on the button, rather than read back out of the tooltip.
	# The tooltip starts with the id and then a newline, so matching it
	# by prefix lights 30055 when you pick 3005 — and there is no reason
	# for a lookup to go through a string meant for a person.
	button.set_meta("part", info.id)
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
	# The clicked one stays lit. This set every cell unpressed including
	# the one just pressed, so choosing a part looked like choosing
	# nothing — the only sign anything had happened was the ghost.
	for child: Node in _grid.get_children():
		var button: Button = child
		button.button_pressed = str(button.get_meta("part", "")) == part_id
	_mark_swatches()
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
		button.button_pressed = str(button.get_meta("part", "")) == part_id
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
