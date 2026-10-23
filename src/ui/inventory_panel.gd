## The parts list, on screen.
##
## Shown over the model rather than beside it, because it is something
## you consult and dismiss rather than work alongside — and because at
## four hundred pieces it wants the room.
##
## Every row carries its colour as a swatch. A list that says "Red" and
## "Dark Red" in the same typeface on the same page is a list that will
## get mis-ordered, and the colour is the half of a lot most easily got
## wrong. And its picture: on a hotel of 3,164 parts the list was 686 rows
## of numbers, and a part is known by its shape before its number.
##
## A row is also the way to the parts in the model. Clicked, it selects every
## one of them and the view frames them; the find field over the rows keeps
## the ones a number, a name or a colour answers ("3004", "1x2 brick", "blue
## 1x2 brick"), and Enter selects all of those. Studio's palette has an "In
## model" view that does this; without it, finding where the one blue 1 x 2
## brick of a hotel was had no route at all (walk180, 2026-10-23).
class_name InventoryPanel
extends PanelContainer

## The tallest a row is: its picture's side.
const ROW := 30

var library: PartLibrary
## Draws the rows' pictures, those in sight (main's, the parts bin's own).
var thumbnails: PartThumbnails

var _rows: GridContainer
var _scroll: ScrollContainer
var _sight: ThumbTile.Sight
var _find: LineEdit
## Every lot's row, made once a showing: [Inventory.Lot, Button]. The find
## takes rows out of the list and puts them back rather than making them
## again.
var _made: Array = []
## Where the list was scrolled to, and the stock it was of, for opening it
## again where it was after a row was clicked.
var _was_at: int = 0
var _was_of: String = ""
## Scrolled to once the rows are laid out, or -1.
var _scroll_to: int = -1
var _heading: Label
var _stock: Inventory
var _title: String = "Model"
var _need: Button
var _csv: Button
var _bricklink: Button
var _rebrickable: Button
var _done: Button

signal closed
## Select these bricks and show them: a row clicked, or Enter in the find.
## [param what] is what they are, said in the bar.
signal chosen(ids: PackedInt64Array, what: String)
## The parts against the person's collection: CollectionDialog.
signal need_wanted
## A shop's list was asked for: "bricklink" or "rebrickable".
signal shop_wanted(shop: String)


func _header_button(header: Container, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 11)
	button.focus_mode = Control.FOCUS_NONE
	header.add_child(button)
	return button


## What a shop's list came to, said where it was asked for.
func tell(line: String) -> void:
	if not line.is_empty():
		_heading.text = line


## Its controls, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = {"parts_need": _need, "parts_csv": _csv,
		"parts_bricklink": _bricklink, "parts_rebrickable": _rebrickable, "parts_done": _done,
		"parts_find": _find}
	# The first row shown, which a click selects in the model.
	if _rows.get_child_count() > 0:
		named["parts_row"] = _rows.get_child(0)
	return named


func _ready() -> void:
	visible = false
	_build()
	visibility_changed.connect(func() -> void:
		if not visible and thumbnails != null:
			thumbnails.watch(self, []))


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 14
	backing.content_margin_bottom = 14
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 15)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)

	_need = _header_button(header, "What do I need?",
		"These parts against your collection: what is short, and what could stand in")
	_need.pressed.connect(func() -> void:
		hide_list()
		need_wanted.emit())
	_csv = _header_button(header, "Save as CSV", "A spreadsheet, or a shop's bulk-add box")
	_csv.pressed.connect(_on_csv)
	# The two shops' own lists, here as well as under File › Export: the
	# list is where somebody decides to buy the parts, and a shared model's
	# viewer has no File menu at all.
	_bricklink = _header_button(header, "BrickLink",
		"A BrickLink wanted list (.xml), to upload under Wanted › Upload")
	_bricklink.pressed.connect(func() -> void: shop_wanted.emit("bricklink"))
	_rebrickable = _header_button(header, "Rebrickable",
		"A Rebrickable parts list (.csv), to import into a list of your own")
	_rebrickable.pressed.connect(func() -> void: shop_wanted.emit("rebrickable"))

	_done = _header_button(header, "Done", "")
	_done.pressed.connect(hide_list)

	_find = LineEdit.new()
	_find.placeholder_text = "Find in the model: a part's number, its name, a colour…"
	_find.tooltip_text = ("Only the parts that answer it: 3004, brick 1x2, blue 1x2 brick.\n"
		+ "Enter selects all of them in the model; a row selects its own")
	_find.clear_button_enabled = true
	_find.add_theme_font_size_override("font_size", 12)
	_find.text_changed.connect(func(_text: String) -> void: _filter())
	_find.text_submitted.connect(func(_text: String) -> void: _choose_shown())
	column.add_child(_find)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	# One column of a grid rather than a box: a grid's rows are what
	# ThumbTile.Sight reads the rows in sight from, to draw their pictures
	# and no others.
	_rows = GridContainer.new()
	_rows.columns = 1
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("v_separation", 2)
	_scroll.add_child(_rows)
	_sight = ThumbTile.Sight.new(_scroll, _rows)


func is_showing() -> bool:
	return visible


## Take stock and show it.
func show_for(world: BrickWorld, from_library: PartLibrary,
		scenery: Dictionary, title: String) -> bool:
	library = from_library
	_title = title
	_stock = Inventory.of(world, from_library, scenery)
	if _stock.pieces == 0:
		return false

	_heading.text = _counts()

	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_made.clear()
	for lot: Inventory.Lot in _stock.lots:
		var row: Button = _row(lot)
		_made.append([lot, row])
		_rows.add_child(row)
	_sight.forget()

	visible = true
	# Where it was, when it is the same model's list again: the way to find
	# one part, look at it, and come back for the next.
	var of: String = "%s %d %d" % [title, _stock.pieces, _stock.lot_count()]
	var at: int = _was_at if of == _was_of else 0
	_was_of = of
	_find.text = ""
	_scroll.scroll_vertical = 0
	_scroll_to = at
	return true


## Show it with the find ready to type into (Edit, Select by, Part number
## or name).
func show_finding(world: BrickWorld, from_library: PartLibrary,
		scenery: Dictionary, title: String) -> bool:
	if not show_for(world, from_library, scenery, title):
		return false
	_scroll_to = -1
	_find.grab_focus()
	return true


func hide_list() -> void:
	_was_at = _scroll.scroll_vertical
	if _find.has_focus():
		_find.release_focus()
	visible = false
	closed.emit()


func _counts() -> String:
	return "%d pieces · %d lots · %s" % [_stock.pieces, _stock.lot_count(), _stock.weight()]


## Only the rows the find answers, in the list's own order.
func _filter() -> void:
	if _stock == null:
		return
	var said: String = _find.text.strip_edges()
	var colours: Dictionary = {}
	for pair: Array in _made:
		colours[(pair[0] as Inventory.Lot).color_code] = true
	var wanted: SelectBy.Wanted = SelectBy.wanted(library, said, colours)
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
	var lots: int = 0
	var pieces: int = 0
	for pair: Array in _made:
		var lot: Inventory.Lot = pair[0]
		if wanted.takes(lot.part_id, lot.color_code):
			_rows.add_child(pair[1])
			lots += 1
			pieces += lot.count
	_sight.forget()
	_scroll.scroll_vertical = 0
	if said.is_empty():
		_heading.text = _counts()
	elif lots == 0:
		_heading.text = "Nothing in this model answers “%s”" % said
	else:
		_heading.text = "%d piece%s in %d lot%s answer “%s”: Enter selects them" % [
			pieces, "" if pieces == 1 else "s", lots, "" if lots == 1 else "s", said]


## Enter in the find: every row it kept.
func _choose_shown() -> void:
	var said: String = _find.text.strip_edges()
	if said.is_empty() or _rows.get_child_count() == 0:
		return
	var ids := PackedInt64Array()
	for pair: Array in _made:
		if (pair[1] as Node).get_parent() == _rows:
			ids.append_array((pair[0] as Inventory.Lot).bricks)
	_choose(ids, "the parts that answer “%s”" % said)


func _choose(ids: PackedInt64Array, what: String) -> void:
	hide_list()
	chosen.emit(ids, what)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _scroll_to >= 0 and _rows.size.y > 0.0:
		_scroll.scroll_vertical = _scroll_to
		_scroll_to = -1
	if thumbnails == null or not _sight.changed():
		return
	thumbnails.watch(self, _sight.tiles())


## A row, which is a button: clicked, it selects its parts in the model.
func _row(lot: Inventory.Lot) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, ROW)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Select %s in the model" % (
		"it" if lot.count == 1 else "these %d" % lot.count)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["hover", "pressed"]:
		var lit := StyleBoxFlat.new()
		lit.bg_color = Color(1, 1, 1, 0.07 if state == "hover" else 0.12)
		lit.set_corner_radius_all(3)
		button.add_theme_stylebox_override(state, lit)
	var what: String = "%s in %s" % [lot.name, lot.color_name]
	var ids: PackedInt64Array = lot.bricks
	button.pressed.connect(func() -> void: _choose(ids, what))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var count := Label.new()
	count.text = "%d ×" % lot.count
	count.custom_minimum_size = Vector2(44, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 12)
	row.add_child(count)

	# Its picture, in its colour: the parts bin's, drawn when it comes
	# into sight.
	var tile := ThumbTile.new(lot.part_id, lot.color_code)
	tile.custom_minimum_size = Vector2(ROW, ROW)
	button.set_meta("tile", tile)
	if thumbnails != null:
		var ready_now: ImageTexture = thumbnails.peek(lot.part_id, lot.color_code)
		if ready_now != null:
			tile.show_picture(ready_now, false)
	row.add_child(tile)

	# The colour, as a colour. A transparent part gets a lighter border so
	# trans-clear and white are not the same square.
	var swatch := Panel.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(15, 15)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	var color: PartLibrary.BrickColor = library.color(lot.color_code)
	style.bg_color = color.shown if color != null else Color.MAGENTA
	style.set_corner_radius_all(3)
	if color != null and color.is_transparent():
		style.set_border_width_all(2)
		style.border_color = Color(color.rgb, 1.0).darkened(0.4)
	swatch.add_theme_stylebox_override("panel", style)
	row.add_child(swatch)

	var id := Label.new()
	id.text = lot.part_id
	id.custom_minimum_size = Vector2(74, 0)
	id.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id.add_theme_font_size_override("font_size", 12)
	id.modulate = Color(1, 1, 1, 0.55)
	row.add_child(id)

	var name := Label.new()
	name.text = lot.name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 12)
	row.add_child(name)

	var shade := Label.new()
	shade.text = lot.color_name
	shade.custom_minimum_size = Vector2(150, 0)
	shade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shade.add_theme_font_size_override("font_size", 12)
	shade.modulate = Color(1, 1, 1, 0.6)
	shade.clip_text = true
	row.add_child(shade)
	return button


func _on_csv() -> void:
	if _stock == null:
		return
	var file_name: String = _title.to_snake_case() + "_parts.csv"
	_heading.text = Download.give(_stock.to_csv(), file_name, "text/csv")
