## Build, Booklet page, Page setup…: the booklet's paper and which way up,
## its margins, a colour or a picture behind every page, and how big the
## step numbers and the parts boxes' pictures are (BookletSheet); a style
## kept by a name and given to another model in one choice.
##
## Each change is made as it is chosen, one undo each (Shell.page_setup),
## as the timeline's Booklet row makes its changes: there is no OK to
## forget to press. A style chosen from Style gives the model that page
## whole: on another model, Page setup… and the style's name are two
## actions.
class_name PageSetupDialog
extends AcceptDialog

var shell: Shell

var _paper: OptionButton
var _orientation: OptionButton
var _margin: SpinBox
var _colour: ColorPickerButton
var _picture: Label
var _choose: Button
var _take_off: Button
var _number: SpinBox
var _parts: SpinBox
var _style: OptionButton
var _name: LineEdit
var _keep: Button
var _said: Label
var _picker: PickImage
## Filling the controls from the model: their signals change nothing.
var _filling: bool = false

const WIDTH := 440
const PAPERS: Array[String] = ["booklet", "a4", "letter", "a5"]


func _ready() -> void:
	title = "Page setup"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(column)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)

	_paper = OptionButton.new()
	for key: String in PAPERS:
		_paper.add_item(str(BookletSheet.PAPERS[key][1]))
	_paper.tooltip_text = "The paper the booklet is printed on, and its PDF's page"
	_paper.item_selected.connect(func(index: int) -> void: _apply({"paper": PAPERS[index]}))
	_row(grid, "Paper", _paper)
	_orientation = OptionButton.new()
	_orientation.add_item("Landscape")
	_orientation.add_item("Portrait")
	_orientation.tooltip_text = "On its side, or upright"
	_orientation.item_selected.connect(func(index: int) -> void: _apply({"portrait": index == 1}))
	_row(grid, "Orientation", _orientation)
	_margin = _spin(BookletSheet.MARGIN_RANGE, 0.5, " mm",
		"How far from the paper's edge the steps keep", "margin")
	_row(grid, "Margins", _margin)

	_colour = ColorPickerButton.new()
	_colour.edit_alpha = false
	_colour.custom_minimum_size = Vector2(0, 28)
	_colour.tooltip_text = "The colour of every page"
	# Set when the picker closes, not at every colour it passes through.
	_colour.popup_closed.connect(func() -> void:
		_apply({"colour": "#" + _colour.color.to_html(false)}))
	_row(grid, "Page colour", _colour)

	var behind := HBoxContainer.new()
	behind.add_theme_constant_override("separation", 6)
	_picture = Label.new()
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	behind.add_child(_picture)
	_choose = Button.new()
	_choose.text = "Choose…"
	_choose.tooltip_text = "A picture behind every page, covering it"
	_choose.pressed.connect(func() -> void: _picker.ask())
	behind.add_child(_choose)
	_take_off = Button.new()
	_take_off.text = "Take off"
	_take_off.tooltip_text = "The page's colour behind every page again"
	_take_off.pressed.connect(func() -> void: _apply({"picture": ""}))
	behind.add_child(_take_off)
	_row(grid, "Picture behind", behind)

	_number = _spin(BookletSheet.NUMBER_RANGE, 0.5, " mm", "How tall a step's number is printed",
		"number")
	_row(grid, "Step numbers", _number)
	_parts = _spin(Vector2(BookletSheet.PARTS_RANGE.x * 100.0, BookletSheet.PARTS_RANGE.y * 100.0),
		5.0, " %", "How big the parts are drawn in each step's parts box and the parts list", "parts")
	_row(grid, "Parts pictures", _parts)

	column.add_child(HSeparator.new())
	_style = OptionButton.new()
	_style.tooltip_text = "A page set up and kept by a name, given to this model whole"
	_style.item_selected.connect(_pick_style)
	var styles := GridContainer.new()
	styles.columns = 2
	styles.add_theme_constant_override("h_separation", 12)
	styles.add_theme_constant_override("v_separation", 6)
	column.add_child(styles)
	_row(styles, "Style", _style)
	var keep := HBoxContainer.new()
	keep.add_theme_constant_override("separation", 6)
	_name = LineEdit.new()
	_name.placeholder_text = "Name this page"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_submitted.connect(func(_text: String) -> void: _keep_style())
	keep.add_child(_name)
	_keep = Button.new()
	_keep.text = "Keep as a style"
	_keep.tooltip_text = "Keep this page by its name, to give another model in one choice"
	_keep.pressed.connect(_keep_style)
	keep.add_child(_keep)
	_row(styles, "", keep)

	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.custom_minimum_size = Vector2(WIDTH, 0)
	_said.add_theme_font_size_override("font_size", 12)
	column.add_child(_said)

	_picker = PickImage.new()
	add_child(_picker)
	_picker.picked.connect(_picture_picked)
	_picker.failed.connect(func(why: String) -> void: _said.text = why)


func _row(grid: GridContainer, words: String, control: Control) -> void:
	var label := Label.new()
	label.text = words
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _spin(bounds: Vector2, step: float, suffix: String, tip: String, field: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = bounds.x
	spin.max_value = bounds.y
	spin.step = step
	spin.suffix = suffix
	spin.tooltip_text = tip
	spin.value_changed.connect(func(value: float) -> void:
		_apply({field: value / 100.0 if field == "parts" else value}))
	return spin


## Open, showing the model's page as it is set up.
func open() -> void:
	fill()
	_said.text = ""
	popup_centered()


## The controls as the model's page is set up, and the styles kept.
func fill() -> void:
	_filling = true
	var sheet: BookletSheet = BookletSheet.of(shell.world)
	_paper.select(maxi(0, PAPERS.find(sheet.paper)))
	_orientation.select(1 if sheet.portrait else 0)
	_margin.value = sheet.margin
	_colour.color = sheet.colour
	_picture.text = "A picture" if not sheet.picture.is_empty() else "None"
	_take_off.disabled = sheet.picture.is_empty()
	_number.value = sheet.number
	_parts.value = sheet.parts * 100.0
	_style.clear()
	_style.add_item("Choose a style…")
	var names: Array = BookletSheet.styles().keys()
	names.sort()
	for name: String in names:
		_style.add_item(name)
	_style.select(0)
	_style.disabled = names.is_empty()
	_filling = false


func _apply(fields: Dictionary) -> void:
	if _filling:
		return
	_said.text = shell.page_setup(fields)
	shell.bar.say(_said.text)
	fill()


## A style chosen: the model's page set up as it was kept, whole.
func _pick_style(index: int) -> void:
	if _filling or index <= 0:
		return
	_apply({"style": _style.get_item_text(index)})


func _keep_style() -> void:
	var name: String = _name.text.strip_edges()
	if name.is_empty():
		_said.text = "Name the page first"
		return
	_apply({"save_as": name})
	_name.text = ""


func _picture_picked(image: Image) -> void:
	if image == null or image.get_width() < 1:
		return
	var kept: Array = BookletSheet.picture_of(image)
	_apply({"picture": kept[0], "picture_data": kept[1]})
