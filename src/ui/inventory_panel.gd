## The parts list, on screen.
##
## Shown over the model rather than beside it, because it is something
## you consult and dismiss rather than work alongside — and because at
## four hundred pieces it wants the room.
##
## Every row carries its colour as a swatch. A list that says "Red" and
## "Dark Red" in the same typeface on the same page is a list that will
## get mis-ordered, and the colour is the half of a lot most easily got
## wrong.
class_name InventoryPanel
extends PanelContainer

var library: PartLibrary

var _rows: VBoxContainer
var _heading: Label
var _stock: Inventory
var _title: String = "Model"

signal closed


func _ready() -> void:
	visible = false
	_build()


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

	var csv := Button.new()
	csv.text = "Save as CSV"
	csv.tooltip_text = "A spreadsheet, or a shop's bulk-add box"
	csv.add_theme_font_size_override("font_size", 11)
	csv.pressed.connect(_on_csv)
	header.add_child(csv)

	var close := Button.new()
	close.text = "Done"
	close.add_theme_font_size_override("font_size", 11)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_list)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	scroll.add_child(_rows)


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

	_heading.text = "%d pieces · %d lots · %s" % [
		_stock.pieces, _stock.lot_count(), _stock.weight()]

	for child: Node in _rows.get_children():
		child.queue_free()
	for lot: Inventory.Lot in _stock.lots:
		_rows.add_child(_row(lot))

	visible = true
	return true


func hide_list() -> void:
	visible = false
	closed.emit()


func _row(lot: Inventory.Lot) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)

	var count := Label.new()
	count.text = "%d ×" % lot.count
	count.custom_minimum_size = Vector2(44, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 12)
	row.add_child(count)

	# The colour, as a colour. A transparent part gets a lighter border so
	# trans-clear and white are not the same square.
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(15, 15)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	var color: PartLibrary.BrickColor = library.color(lot.color_code)
	style.bg_color = color.rgb if color != null else Color.MAGENTA
	style.set_corner_radius_all(3)
	if color != null and color.is_transparent():
		style.set_border_width_all(2)
		style.border_color = Color(color.rgb, 1.0).darkened(0.4)
	swatch.add_theme_stylebox_override("panel", style)
	row.add_child(swatch)

	var id := Label.new()
	id.text = lot.part_id
	id.custom_minimum_size = Vector2(74, 0)
	id.add_theme_font_size_override("font_size", 12)
	id.modulate = Color(1, 1, 1, 0.55)
	row.add_child(id)

	var name := Label.new()
	name.text = lot.name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.add_theme_font_size_override("font_size", 12)
	row.add_child(name)

	var shade := Label.new()
	shade.text = lot.color_name
	shade.custom_minimum_size = Vector2(150, 0)
	shade.add_theme_font_size_override("font_size", 12)
	shade.modulate = Color(1, 1, 1, 0.6)
	shade.clip_text = true
	row.add_child(shade)
	return row


func _on_csv() -> void:
	if _stock == null:
		return
	var file_name: String = _title.to_snake_case() + "_parts.csv"
	_heading.text = Download.give(_stock.to_csv(), file_name, "text/csv")
