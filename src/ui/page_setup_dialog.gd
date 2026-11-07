## Build, Booklet page, Page setup…: the booklet's paper and which way up,
## its margins, a colour or a picture behind every page, and how big the
## step numbers and the parts boxes' pictures are (BookletSheet); a style
## kept by a name and given to another model in one choice, or taken away.
##
## Each change is made as it is chosen, one undo each (Shell.page_setup),
## as the timeline's Booklet row makes its changes: there is no OK to
## forget to press. A style chosen from Style gives the model that page
## whole: on another model, Page setup… and the style's name are two
## actions.
##
## In three tabs (booklook), as Studio's Page Setup has its own: the Page
## (its paper, margins, what is behind it, and the designer's words at the
## head and foot of every page), the Cover (its title, the line under it, a
## picture of the model or of their own, a line of their words) and the
## Steps (the step numbers' size and colour, the parts pictures, the parts
## box's frame, fill and corners, the colour round the new parts). A word
## typed is set as it is entered or left; a colour as its picker closes.
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
var _remove: MenuButton
var _confirm: ConfirmationDialog
## The style Remove… asks about.
var _removing: String = ""
var _name: LineEdit
var _keep: Button
var _said: Label
var _picker: PickImage
## Filling the controls from the model: their signals change nothing.
var _filling: bool = false
## booklook: the tabs, and in them the designer's words, the cover's
## picture, and the colours.
var _tabs: TabContainer
var _header: LineEdit
var _footer: LineEdit
var _title: LineEdit
var _subtitle: LineEdit
var _cover_line: LineEdit
var _cover: Label
var _cover_choose: Button
var _cover_model: Button
var _number_colour: ColorPickerButton
var _box_frame: ColorPickerButton
var _box_fill: ColorPickerButton
var _box_corners: SpinBox
var _outline: ColorPickerButton
var _usual_colours: Button
## Which picture the picker is choosing: "behind" or "cover".
var _picking: String = "behind"
## The words' fields by what each sets ([constant BookletSheet.TEXTS]).
var _texts: Dictionary = {}
## The colours' buttons by what each sets ([constant BookletSheet.COLOURS]).
var _colours: Dictionary = {}

const WIDTH := 440
const PAPERS: Array[String] = ["booklet", "a4", "letter", "a5"]


func _ready() -> void:
	title = "Page setup"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(column)
	_tabs = TabContainer.new()
	column.add_child(_tabs)
	var grid: GridContainer = _tab("Page")
	var cover: GridContainer = _tab("Cover")
	var steps: GridContainer = _tab("Steps")

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
	_choose.pressed.connect(func() -> void:
		_picking = "behind"
		_picker.ask())
	behind.add_child(_choose)
	_take_off = Button.new()
	_take_off.text = "Take off"
	_take_off.tooltip_text = "The page's colour behind every page again"
	_take_off.pressed.connect(func() -> void: _apply({"picture": ""}))
	behind.add_child(_take_off)
	_row(grid, "Picture behind", behind)
	_header = _text_field("header", "None", "Your words at the head of every page but the cover")
	_row(grid, "Header", _header)
	_footer = _text_field("footer", "None", "Your words at the foot of every page, the cover too")
	_row(grid, "Footer", _footer)

	# The cover, as its designer makes it.
	_title = _text_field("title", "The model's name", "The title across the top of the cover")
	_row(cover, "Title", _title)
	_subtitle = _text_field("subtitle", "None", "A line under the title")
	_row(cover, "Under the title", _subtitle)
	var picture := HBoxContainer.new()
	picture.add_theme_constant_override("separation", 6)
	_cover = Label.new()
	_cover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.add_child(_cover)
	_cover_choose = Button.new()
	_cover_choose.text = "Choose…"
	_cover_choose.tooltip_text = "A picture of your own on the cover, shown whole"
	_cover_choose.pressed.connect(func() -> void:
		_picking = "cover"
		_picker.ask())
	picture.add_child(_cover_choose)
	_cover_model = Button.new()
	_cover_model.text = "The model"
	_cover_model.tooltip_text = "The finished model drawn on the cover again"
	_cover_model.pressed.connect(func() -> void: _apply({"cover_picture": ""}))
	picture.add_child(_cover_model)
	_row(cover, "Picture", picture)
	_cover_line = _text_field("cover_line", "None", "A line of your words on the cover, over its count of pieces")
	_row(cover, "Line", _cover_line)

	var number := HBoxContainer.new()
	number.add_theme_constant_override("separation", 6)
	_number = _spin(BookletSheet.NUMBER_RANGE, 0.5, " mm", "How tall a step's number is printed",
		"number")
	_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.add_child(_number)
	_number_colour = _colour_field("number_colour", "The colour of every step's number")
	number.add_child(_number_colour)
	_row(steps, "Step numbers", number)
	_parts = _spin(Vector2(BookletSheet.PARTS_RANGE.x * 100.0, BookletSheet.PARTS_RANGE.y * 100.0),
		5.0, " %", "How big the parts are drawn in each step's parts box and the parts list", "parts")
	_row(steps, "Parts pictures", _parts)
	_box_frame = _colour_field("box_frame", "The colour of the parts box's frame, and of the boxes beside it")
	_row(steps, "Parts box frame", _box_frame)
	_box_fill = _colour_field("box_fill", "The colour inside the parts box")
	_row(steps, "Parts box fill", _box_fill)
	_box_corners = _spin(BookletSheet.CORNERS_RANGE, 0.2, " mm",
		"How round the parts box's corners are: 0 for square", "box_corners")
	_row(steps, "Parts box corners", _box_corners)
	_outline = _colour_field("outline_colour", "The colour round the parts each step adds")
	_row(steps, "New parts outline", _outline)
	_usual_colours = Button.new()
	_usual_colours.text = "Usual colours"
	_usual_colours.tooltip_text = "The booklet's own parts box, step numbers and outline again"
	_usual_colours.pressed.connect(func() -> void:
		_apply({"box_frame": "usual", "box_fill": "usual", "box_corners": BookletSheet.BOX_CORNERS,
			"number_colour": "usual", "outline_colour": "usual"}))
	_row(steps, "", _usual_colours)

	column.add_child(HSeparator.new())
	_style = OptionButton.new()
	_style.tooltip_text = "A page set up and kept by a name, given to this model whole"
	_style.item_selected.connect(_pick_style)
	var styles := GridContainer.new()
	styles.columns = 2
	styles.add_theme_constant_override("h_separation", 12)
	styles.add_theme_constant_override("v_separation", 6)
	column.add_child(styles)
	var chosen := HBoxContainer.new()
	chosen.add_theme_constant_override("separation", 6)
	_style.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chosen.add_child(_style)
	# A list of its own, not the style chosen: choosing one in Style gives
	# it to this model, which taking one away must not do.
	_remove = MenuButton.new()
	_remove.text = "Remove…"
	_remove.flat = false
	_remove.tooltip_text = "Take a kept style away; the models given it keep their page"
	_remove.get_popup().index_pressed.connect(func(index: int) -> void:
		_ask_remove(_remove.get_popup().get_item_text(index)))
	chosen.add_child(_remove)
	_row(styles, "Style", chosen)
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

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Remove a page style?"
	_confirm.ok_button_text = "Remove"
	_confirm.confirmed.connect(func() -> void: _apply({"remove_style": _removing}))
	add_child(_confirm)

	_picker = PickImage.new()
	add_child(_picker)
	_picker.picked.connect(_picture_picked)
	_picker.failed.connect(func(why: String) -> void: _said.text = why)
	# Words typed and not entered are set as the dialog closes.
	visibility_changed.connect(func() -> void:
		if not visible:
			_set_texts())


## A tab of rows, titled [param words].
func _tab(words: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.add_child(grid)
	_tabs.add_child(margin)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, words)
	return grid


## A line of the designer's words, set as it is entered or left.
func _text_field(field: String, empty: String, tip: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.max_length = BookletSheet.TEXT_MOST
	edit.placeholder_text = empty
	edit.tooltip_text = tip
	edit.text_submitted.connect(func(_text: String) -> void: _set_texts())
	edit.focus_exited.connect(_set_texts)
	_texts[field] = edit
	return edit


## Each line of words that differs from the page's, set: one undo for them.
func _set_texts() -> void:
	if _filling or shell == null or shell.world == null:
		return
	var sheet: BookletSheet = BookletSheet.of(shell.world)
	var changed: Dictionary = {}
	for field: String in _texts:
		if BookletSheet.one_line((_texts[field] as LineEdit).text) != str(sheet.get(field)):
			changed[field] = (_texts[field] as LineEdit).text
	if not changed.is_empty():
		_apply(changed)


## A colour of the booklet's, set as its picker closes.
func _colour_field(field: String, tip: String) -> ColorPickerButton:
	var button := ColorPickerButton.new()
	button.edit_alpha = false
	button.custom_minimum_size = Vector2(56, 28)
	button.tooltip_text = tip
	button.popup_closed.connect(func() -> void:
		_apply({field: "#" + button.color.to_html(false)}))
	_colours[field] = button
	return button


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
	# What is behind the pages, and how much of the model's file it is; a
	# picture the file names and does not carry, said (BookletSheet.missing).
	if sheet.missing:
		_picture.text = "Missing from the file"
		_picture.tooltip_text = tr("The file names %s but does not carry it: another program saved it without it, or it was not a PNG or a JPEG. Choose it again, or take it off.") \
			% sheet.picture
	elif not sheet.picture_uri.is_empty():
		var data: String = sheet.picture_uri.substr(sheet.picture_uri.find(",") + 1)
		_picture.text = tr("%s, %d KB in the file") % [tr("A PNG") if BookletLooks.picture_kind(data)
			== "png" else tr("A JPEG"), BookletSheet.picture_kb(data)]
		_picture.tooltip_text = ""
	else:
		_picture.text = "None"
		_picture.tooltip_text = ""
	_take_off.disabled = sheet.picture.is_empty()
	_number.value = sheet.number
	_parts.value = sheet.parts * 100.0
	# booklook: the words, the cover's picture and the colours.
	for field: String in _texts:
		(_texts[field] as LineEdit).text = str(sheet.get(field))
	var model: String = shell.bar.model_name() if shell.bar != null else ""
	_title.placeholder_text = model if not model.is_empty() else "The model's name"
	if sheet.cover_missing:
		_cover.text = "Missing from the file"
		_cover.tooltip_text = tr("The file names %s but does not carry it: another program saved it without it, or it was not a PNG or a JPEG. Choose it again, or take it off.") \
			% sheet.cover_picture
	elif not sheet.cover_uri.is_empty():
		var data: String = sheet.cover_uri.substr(sheet.cover_uri.find(",") + 1)
		_cover.text = tr("%s, %d KB in the file") % [tr("A PNG") if BookletLooks.picture_kind(data)
			== "png" else tr("A JPEG"), BookletSheet.picture_kb(data)]
		_cover.tooltip_text = ""
	else:
		_cover.text = "The model, drawn"
		_cover.tooltip_text = ""
	_cover_model.disabled = sheet.cover_picture.is_empty()
	for field: String in _colours:
		(_colours[field] as ColorPickerButton).color = sheet.get(field)
	_box_corners.value = sheet.box_corners
	_style.clear()
	_style.add_item("Choose a style…")
	var names: Array = BookletSheet.styles().keys()
	names.sort()
	for name: String in names:
		_style.add_item(name)
	_style.select(0)
	_style.disabled = names.is_empty()
	var popup: PopupMenu = _remove.get_popup()
	popup.clear()
	for name: String in names:
		popup.add_item(name)
	_remove.disabled = names.is_empty()
	_filling = false


func _apply(fields: Dictionary) -> void:
	if _filling:
		return
	var said: String = shell.page_setup(fields)
	shell.bar.say(said)
	_said.text = said.left(1).to_upper() + said.substr(1)
	fill()


## A style chosen: the model's page set up as it was kept, whole.
func _pick_style(index: int) -> void:
	if _filling or index <= 0:
		return
	_apply({"style": _style.get_item_text(index)})


## Remove… on [param name]: asked first, since a style taken away is not
## undone.
func _ask_remove(name: String) -> void:
	_removing = name
	_confirm.dialog_text = tr("Remove the page style “%s”? The models given it keep their page.") % name
	_confirm.popup_centered()


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
	if _picking == "cover":
		var cover: Array = BookletSheet.cover_of(image)
		_apply({"cover_picture": cover[0], "cover_picture_data": cover[1]})
		return
	var kept: Array = BookletSheet.picture_of(image)
	_apply({"picture": kept[0], "picture_data": kept[1]})
