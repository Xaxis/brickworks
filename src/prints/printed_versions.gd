## Edit, Printed versions…: the prints and stickered versions the LEGO Group
## made of the part picked out, as the library has them, each drawn with its
## print, to swap it for: a plain 2 x 2 tile made a control panel, a
## minifigure's plain torso made a uniform, a printed one made plain again.
##
## The versions are the library's own parts (PartLibrary.prints_of: 3068b
## has hundreds), the prints first and the most used first, narrowed by
## words typed ("porsche", "control"). A click swaps every selected part of
## that kind for the version, each in its own colour where it stands, as
## one step to undo (PrintStudio.swap_to, which print_part's version= is
## too), and closes the panel.
class_name PrintedVersions
extends PanelContainer

## The most cells laid out at once; words narrow the rest.
const MOST := 240
const CELL := Vector2(118, 140)

var studio: PrintStudio
var thumbnails: PartThumbnails

var _plain: String = ""
var _ids := PackedInt64Array()
var _colour: int = 15
var _heading: Label
var _search: LineEdit
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _sight: ThumbTile.Sight
var _close: Button


func _ready() -> void:
	visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.99)
	backing.border_color = Color(1, 1, 1, 0.16)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	for side: String in ["left", "right", "top", "bottom"]:
		backing.set("content_margin_" + side, 14)
	add_theme_stylebox_override("panel", backing)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 15)
	_heading.clip_text = true
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	_search = LineEdit.new()
	_search.placeholder_text = "words on it: control panel…"
	_search.custom_minimum_size = Vector2(220, 0)
	_search.tooltip_text = "Only the versions whose name has every word typed"
	_search.text_changed.connect(func(_text: String) -> void: _fill())
	header.add_child(_search)
	_close = Button.new()
	_close.text = "Close"
	_close.tooltip_text = "Back to the model (Escape)"
	_close.focus_mode = Control.FOCUS_NONE
	_close.add_theme_font_size_override("font_size", 12)
	_close.pressed.connect(close)
	header.add_child(_close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_scroll.add_child(_grid)
	_sight = ThumbTile.Sight.new(_scroll, _grid)
	_scroll.resized.connect(func() -> void:
		_grid.columns = maxi(2, int((_scroll.size.x - 14.0) / (CELL.x + 6.0))))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1.0, 0.86, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	visibility_changed.connect(func() -> void:
		if not visible and thumbnails != null:
			thumbnails.watch(self, []))


## Open on the versions of [param plain], to swap the parts numbered
## [param ids] for one; drawn in [param colour], the first part's.
func open(plain: String, ids: PackedInt64Array, colour: int) -> void:
	_plain = plain
	_ids = ids
	_colour = colour
	var info: PartLibrary.PartInfo = studio.library.parts.get(plain)
	var all: Array[PartLibrary.PartInfo] = studio.versions_of(plain)
	var printed: int = all.filter(func(one: PartLibrary.PartInfo) -> bool:
		return one.decor() & PartLibrary.PartInfo.PRINTED != 0).size()
	_heading.text = "Printed versions of %s %s: %d print%s%s" % [plain,
		Inventory._tidy(info.name) if info != null else "", printed, "" if printed == 1 else "s",
		", %d stickered" % (all.size() - printed) if all.size() > printed else ""]
	_search.text = ""
	_status.text = ("Click one to swap %s for it, in %s colour, where it stands. Edit, Undo "
		% ["the part" if ids.size() == 1 else "the %d parts" % ids.size(),
			"its" if ids.size() == 1 else "each one's"] + "puts it back.")
	visible = true
	_fill()


func close() -> void:
	visible = false


func _fill() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var found: Array[PartLibrary.PartInfo] = studio.versions_of(_plain, _search.text)
	# The plain part first, to take a print off again.
	var plain: PartLibrary.PartInfo = studio.library.parts.get(_plain)
	if plain != null and _search.text.strip_edges().is_empty():
		_grid.add_child(_cell(plain, "Plain"))
	for info: PartLibrary.PartInfo in found.slice(0, MOST):
		_grid.add_child(_cell(info, info.printed()))
	if found.size() > MOST:
		_status.text = "The first %d of %d: type words to narrow them." % [MOST, found.size()]
	elif found.is_empty():
		_status.text = "None has \"%s\" in its name." % _search.text.strip_edges()
	_sight.forget()


func _cell(info: PartLibrary.PartInfo, words: String) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = CELL
	cell.focus_mode = Control.FOCUS_NONE
	cell.tooltip_text = "%s\n%s" % [info.id, info.name.strip_edges().replace("  ", " ")]
	cell.set_meta("part", info.id)
	var tile := ThumbTile.new()
	tile.caption = info.id
	tile.position = Vector2(11, 6)
	tile.size = Vector2(CELL.x - 22, CELL.x - 22)
	cell.add_child(tile)
	cell.set_meta("tile", tile)
	tile.show_part(info.id, _colour, true)
	if thumbnails != null:
		var ready_now: ImageTexture = thumbnails.peek(info.id, _colour, true)
		if ready_now != null:
			tile.show_picture(ready_now, false)
	var label := Label.new()
	label.text = "%s\n%s" % [info.id, words]
	label.add_theme_font_size_override("font_size", 10)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(4, CELL.x - 14)
	label.size = Vector2(CELL.x - 8, CELL.y - CELL.x + 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	cell.pressed.connect(func() -> void: _choose(info.id))
	return cell


func _choose(part_id: String) -> void:
	var said: String = await studio.swap_to(_ids, part_id)
	studio.said.emit(said.trim_suffix("."))
	if said.begins_with("Swapped"):
		close()
	else:
		_status.text = said


func _process(_delta: float) -> void:
	if not visible or thumbnails == null or not _sight.changed():
		return
	thumbnails.watch(self, _sight.tiles())


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Every other key stops here while it is open: they are the model's
## shortcuts, and a word typed into the search is not a command.
func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


## Its controls by name, for a browser check: the search, Close, and the
## first cells as version_<n> (0 is the plain part while nothing is typed).
func controls_by_name() -> Dictionary:
	var named: Dictionary = {"versions_search": _search, "versions_close": _close}
	var n: int = 0
	for cell: Node in _grid.get_children():
		if n >= 24:
			break
		named["version_%d" % n] = cell
		n += 1
	return named


## The part ids the cells offer, in order: for a check.
func offered() -> PackedStringArray:
	var out := PackedStringArray()
	for cell: Node in _grid.get_children():
		out.append(str(cell.get_meta("part", "")))
	return out
