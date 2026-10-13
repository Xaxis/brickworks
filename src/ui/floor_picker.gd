## What a model stands on, to choose: a baseplate of a size and a colour,
## the grid floor, or nothing (ModelFloor). Two rows, small enough for the
## properties with nothing selected (the model's own properties, Inspector)
## and for Settings, where it chooses what new models start on.
class_name FloorPicker
extends VBoxContainer

## The kinds and sizes, in the order the list shows them. "custom" is a
## baseplate of the size typed beside it.
const CHOICES: Array = [
	["Baseplate 16 × 16", ModelFloor.BASEPLATE, 16],
	["Baseplate 32 × 32", ModelFloor.BASEPLATE, 32],
	["Baseplate 48 × 48", ModelFloor.BASEPLATE, 48],
	["Baseplate, other size", "custom", 0],
	["Grid floor", ModelFloor.GRID, 0],
	["No floor", ModelFloor.NONE, 0],
]

## A floor was chosen.
signal picked(chosen: ModelFloor)
## "Part of the model" was ticked or unticked.
signal part_toggled(on: bool)

## Whether to offer making the baseplate part of the model: not for the
## floor new models start on, which have no parts yet.
var with_part: bool = true

var _kind: OptionButton
var _colour: OptionButton
var _wide: SpinBox
var _deep: SpinBox
var _sizes: HBoxContainer
var _part: CheckBox
var _plate_row: HBoxContainer
var _shown: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE)
## Set while the controls are being filled in, so filling them is not
## taken for a choice.
var _filling: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var words := Label.new()
	words.text = "Floor"
	words.add_theme_font_size_override("font_size", 12)
	words.modulate = Color(1, 1, 1, 0.7)
	words.tooltip_text = "What the model stands on"
	words.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(words)
	_kind = _option("What the model stands on: a baseplate, a grid on the ground, or nothing")
	_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice: Array in CHOICES:
		_kind.add_item(str(choice[0]))
	_kind.item_selected.connect(func(_index: int) -> void: _changed())
	row.add_child(_kind)

	_sizes = HBoxContainer.new()
	_sizes.add_theme_constant_override("separation", 4)
	add_child(_sizes)
	_wide = _spin("Studs across")
	_sizes.add_child(_wide)
	var by := Label.new()
	by.text = "×"
	by.add_theme_font_size_override("font_size", 12)
	_sizes.add_child(by)
	_deep = _spin("Studs deep")
	_sizes.add_child(_deep)
	var studs := Label.new()
	studs.text = "studs"
	studs.add_theme_font_size_override("font_size", 12)
	studs.modulate = Color(1, 1, 1, 0.7)
	_sizes.add_child(studs)

	_plate_row = HBoxContainer.new()
	_plate_row.add_theme_constant_override("separation", 6)
	add_child(_plate_row)
	_colour = _option("The baseplate's colour: the colours baseplates are made in")
	_colour.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair: Array in ModelFloor.COLOURS:
		_colour.add_item(str(pair[1]), int(pair[0]))
	_colour.item_selected.connect(func(_index: int) -> void: _changed())
	_plate_row.add_child(_colour)
	_part = CheckBox.new()
	_part.text = "Part of the model"
	_part.tooltip_text = ("Counted in the parts list and the shop lists, saved with the "
		+ "model and the first step of the booklet")
	_part.focus_mode = Control.FOCUS_NONE
	_part.add_theme_font_size_override("font_size", 12)
	_part.toggled.connect(func(on: bool) -> void:
		if not _filling:
			part_toggled.emit(on))
	_part.visible = with_part
	_plate_row.add_child(_part)
	show_floor(_shown, false)


func _option(says: String) -> OptionButton:
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.tooltip_text = says
	option.add_theme_font_size_override("font_size", 12)
	option.fit_to_longest_item = false
	option.clip_text = true
	return option


func _spin(says: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = ModelFloor.LEAST
	spin.max_value = ModelFloor.MOST
	spin.step = 8
	spin.tooltip_text = says + ", in eights: baseplates are cut in eights"
	spin.custom_minimum_size = Vector2(64, 0)
	spin.add_theme_font_size_override("font_size", 12)
	spin.get_line_edit().add_theme_font_size_override("font_size", 12)
	spin.value_changed.connect(func(_value: float) -> void: _changed())
	return spin


## Show [param chosen], and whether the model has its own baseplate.
func show_floor(chosen: ModelFloor, own_plate: bool) -> void:
	_shown = chosen.copy()
	if _kind == null:
		return
	_filling = true
	_kind.select(_index_of(chosen))
	_colour.select(maxi(_colour.get_item_index(chosen.colour), 0))
	_wide.value = chosen.across
	_deep.value = chosen.deep
	_part.button_pressed = own_plate
	_part.visible = with_part
	_sizes.visible = chosen.is_plate() and _kind.selected == 3
	_plate_row.visible = chosen.is_plate()
	_filling = false


static func _index_of(chosen: ModelFloor) -> int:
	match chosen.kind:
		ModelFloor.GRID:
			return 4
		ModelFloor.NONE:
			return 5
	if chosen.across == chosen.deep:
		var at: int = ModelFloor.SIZES.find(chosen.across)
		if at >= 0:
			return at
	return 3


func _changed() -> void:
	if _filling:
		return
	var choice: Array = CHOICES[_kind.selected]
	var made: ModelFloor = _shown.copy()
	match str(choice[1]):
		ModelFloor.GRID, ModelFloor.NONE:
			made.kind = str(choice[1])
		"custom":
			made.kind = ModelFloor.BASEPLATE
			if _sizes.visible:
				made.across = int(_wide.value)
				made.deep = int(_deep.value)
		_:
			made.kind = ModelFloor.BASEPLATE
			made.across = int(choice[2])
			made.deep = int(choice[2])
	made.colour = _colour.get_item_id(maxi(_colour.selected, 0))
	_sizes.visible = made.is_plate() and _kind.selected == 3
	_plate_row.visible = made.is_plate()
	if made.same_as(_shown):
		return
	_shown = made
	picked.emit(made.copy())
