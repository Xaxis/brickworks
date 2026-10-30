## Drawing a print — a face for a head, a design for a torso's front and
## back, the front of a pair of legs, a sign for a tile, a logo for a slope,
## a photograph for any face of any part — or a sticker.
##
## Pictures come in from files (PNG, JPEG, WebP, BMP, SVG; PictureFile) as
## layers of their own (PrintPicture), placed with "Move" and the picture
## panel: fit to the face or fill it, size, turn, crop, see-through, its
## background made clear, its colours kept or mapped to LEGO's inks (at
## most so many: a pad print is a few flat inks). Starters — a dial, a
## screen, a sign, a number plate, a control panel, a face — are drawn for
## the canvas they go on.
##
## A sticker (open_sticker) is drawn the same way on a canvas the size of
## the faces it is going on, and saved as a sticker (Stickers) rather than
## a printed part.
##
## The canvas is the part's printable area exactly (PartPrints.Area): a
## head's face unrolled from its cylinder, a torso's trapezoid, the hips
## and both legs as they stand side by side. Drawn with a brush, lines,
## boxes, ovals, a fill, words and an eraser, in LEGO's own colours, on
## layers, with undo — and the part turning beside it wears the picture as
## it is drawn. Start from nothing, from one of LEGO's own prints of the
## same mould, from a print made before, or from a picture of one's own.
##
## "Save print" makes the part (a pair of legs is three parts), keeps it
## with its pictures, and hands its id back to whoever opened this, which
## puts it on the figure. It is a made part from then on: in the parts
## bin under Custom, in every model that uses it, and in the slot's grid
## under "My prints and moulds".
class_name PrintEditor
extends PanelContainer

signal made(ids: Array, slot: String)
signal closed()

var library: PartLibrary

## What is being printed on: the slot it is for (or "" for a part on its
## own), the plain part, and the parts printed with it.
var slot: String = ""
var base: String = ""
var with: Dictionary = {}
var colour_code: int = 14

var _areas: Array[PartPrints.Area] = []
var _papers: Dictionary = {}          ## area key -> PrintPaint
var _area: int = 0
var _starts: Array = []               ## [label, part id] the Start from menu offers
var _waiting_for: String = ""         ## a part whose geometry is coming, and why
var _then: Callable

var _title: Label
var _name: LineEdit
## Another part to print on: a tile, a slope, any part by its number.
var _other: LineEdit
var _status: Label
var _tabs: TabBar
var _canvas: PrintCanvas
var _tools: Dictionary = {}           ## tool -> Button
var _size: HSlider
var _filled: CheckBox
var _mirror: CheckBox
var _words: LineEdit
var _word_size: SpinBox
var _text_row: Control
var _layers: VBoxContainer
var _start: OptionButton
var _palette: FlowContainer
var _ink: ColorRect
var _ink_name: Label
var _save: Button
var _files: PictureFile
## The picture panel, shown while the active layer is a picture.
var _picture_box: VBoxContainer
var _picture_scale: HSlider
var _picture_turn: HSlider
var _picture_crop: Array[HSlider] = []
var _picture_opacity: HSlider
var _picture_lego: CheckBox
var _picture_inks: SpinBox
var _picture_clear: CheckBox
var _picture_flip: CheckBox
var _picture_quiet: bool = false
## A sticker being drawn, for the face it goes on; null for a print.
var sticker_face: Stickers.Face = null
var _sticker_preview: MeshInstance3D
var _tab_markers: Dictionary = {}     ## tab index -> a control laid over it

var _viewport: SubViewport
var _camera: Camera3D
var _turntable: Node3D
var _turn: float = 0.0
var _tilt: float = 0.25
var _dragging: bool = false
var _textures: Dictionary = {}        ## area key -> ImageTexture on the preview
var _plain: ShaderMaterial


func _ready() -> void:
	visible = false
	_build()
	if library != null:
		library.fetched.connect(_on_fetched)


## Open on a part: [param part_id] is what the slot holds now — a plain
## part, one of LEGO's prints (started from), or a print made here
## (changed). [param with_parts] names what a pair of legs is printed
## with: {"hips", "left"}.
func open(part_id: String, for_slot: String, colour: int, with_parts: Dictionary = {}) -> void:
	sticker_face = null
	_save.text = "Save print"
	slot = for_slot
	colour_code = colour
	with = with_parts
	visible = true
	base = PartPrints.mould_of(library, part_id)
	_name.text = ""
	var needed: Array = [base]
	for other: Variant in with.values():
		if not str(other).is_empty():
			needed.append(str(PartPrints.base_of(str(other))))
	_after_fetching(needed, func() -> void: _begin(part_id))


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Draw a sticker for a face of the model: the canvas is the sticker, the
## face's rectangle less LEGO's 0.1 mm a side and a margin; the preview is
## the sticker itself. Saving makes it and hands its id back (slot
## "sticker"), for whoever opened this to stick it on.
func open_sticker(face: Stickers.Face, title: String = "") -> void:
	sticker_face = face
	slot = "sticker"
	base = ""
	with = {}
	colour_code = Stickers.FILM
	visible = true
	_name.text = title
	_save.text = "Save sticker"
	var size: Vector2 = face.sticker_size()
	var area := PartPrints.Area.new()
	area.key = "sticker"
	area.title = "Sticker %s x %s mm" % [Stickers._mm(size.x), Stickers._mm(size.y)]
	area.size = Stickers.canvas_for(size)
	area.mask = Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	area.mask.fill(Color.WHITE)
	area.guides = [[Vector2(area.size.x * 0.5, 0), Vector2(area.size.x * 0.5, area.size.y)]]
	_areas = [area]
	_papers = {"sticker": PrintPaint.new(area.size.x, area.size.y)}
	_title.text = "Draw a sticker, %s x %s mm, for %d part%s" % [Stickers._mm(size.x),
		Stickers._mm(size.y), face.bricks.size(), "" if face.bricks.size() == 1 else "s"]
	_save.disabled = false
	_status.text = ""
	_fill_tabs()
	_fill_starts()
	_build_preview()
	_choose_area(0)


## Print on another part by its number: the slot is kept only if the part
## goes in it, so a tile printed from the head slot is not worn as a head.
func _print_on(text: String) -> void:
	var wanted: String = text.strip_edges().to_lower()
	var info: PartLibrary.PartInfo = library.parts.get(wanted)
	if info == null:
		_status.text = "There is no part %s." % wanted
		return
	var keeps: String = slot if Minifig.slot_for(info) == slot else ""
	open(wanted, keeps, colour_code if not keeps.is_empty() else 15)


## Once the parts' geometry is here, do something: at once on the desktop,
## after a fetch in a browser.
func _after_fetching(ids: Array, then: Callable) -> void:
	var missing: Array = []
	for id: Variant in ids:
		if library.mesh_for(str(id)) == null and library.request_mesh(str(id), true):
			missing.append(str(id))
	if missing.is_empty():
		then.call()
		return
	_status.text = "Fetching %s…" % ", ".join(missing)
	_waiting_for = missing[0]
	_then = func() -> void: _after_fetching(ids, then)


func _on_fetched(part_id: String) -> void:
	if part_id == _waiting_for and _then.is_valid():
		_waiting_for = ""
		var next: Callable = _then
		_then = Callable()
		next.call()


func _begin(part_id: String) -> void:
	var with_bases: Dictionary = {}
	for key: String in with:
		with_bases[key] = PartPrints.mould_of(library, str(with[key]))
	_areas = PartPrints.areas_for(library, base, with_bases)
	_papers.clear()
	for area: PartPrints.Area in _areas:
		_papers[area.key] = PrintPaint.new(area.size.x, area.size.y)
	var info: PartLibrary.PartInfo = library.parts.get(base)
	_title.text = "Draw a print on %s" % (Minifig._plain(info.name) if info != null else base)
	if slot == "legs" and with.has("hips"):
		_title.text = "Draw a print on the hips and legs"
	if _areas.is_empty():
		_status.text = "%s has no face a print can go on." % base
		_save.disabled = true
		return
	_save.disabled = false
	_status.text = ""
	_fill_tabs()
	_fill_starts()
	_build_preview()
	_choose_area(0)
	# Changing a print made here, or starting from one of LEGO's.
	if PartPrints.bases.has(part_id):
		_load_made(part_id)
	elif part_id != base and library.parts.has(part_id):
		_load_lego(part_id)


# -- building the panel ------------------------------------------------------


func _build() -> void:
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
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_other = LineEdit.new()
	_other.placeholder_text = "or print on: 3068b…"
	_other.custom_minimum_size = Vector2(150, 0)
	_other.tooltip_text = ("Print on another part instead: a tile (3068b), a slope (3039), "
		+ "any part by its number. It goes in the parts bin under My prints")
	_other.text_submitted.connect(func(text: String) -> void: _print_on(text))
	header.add_child(_other)
	_button(header, "Print on it", func() -> void: _print_on(_other.text),
		"Draw on this part instead")
	var called := Label.new()
	called.text = "Name"
	called.add_theme_font_size_override("font_size", 12)
	called.modulate = Color(1, 1, 1, 0.7)
	header.add_child(called)
	_name = LineEdit.new()
	_name.placeholder_text = "Pirate captain"
	_name.custom_minimum_size = Vector2(170, 0)
	_name.tooltip_text = "What the print is called: it is in the part's name"
	header.add_child(_name)
	_save = _button(header, "Save print", _save_print,
		"Make the printed part, keep it, and put it on the figure")
	_save.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_button(header, "Close", close, "Back to the figure without saving (Escape)")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_tools())

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 6)
	body.add_child(middle)
	_tabs = TabBar.new()
	_tabs.focus_mode = Control.FOCUS_NONE
	_tabs.tab_changed.connect(_choose_area)
	middle.add_child(_tabs)
	_canvas = PrintCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size = Vector2(420, 300)
	_canvas.changed.connect(_on_drawn)
	_canvas.colour_picked.connect(func(found: Color) -> void: _set_ink(found, ""))
	_canvas.picture_moved.connect(_show_picture)
	middle.add_child(_canvas)
	var hint := Label.new()
	hint.text = ("Left button draws · right button or Space-drag pans · wheel zooms · Move drags a "
		+ "picture, Ctrl+wheel sizes it · the shaded part is not on the part")
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.clip_text = true
	middle.add_child(hint)
	var colours := HBoxContainer.new()
	colours.add_theme_constant_override("separation", 8)
	middle.add_child(colours)
	_ink = ColorRect.new()
	_ink.custom_minimum_size = Vector2(28, 28)
	colours.add_child(_ink)
	_ink_name = Label.new()
	_ink_name.custom_minimum_size = Vector2(110, 0)
	_ink_name.add_theme_font_size_override("font_size", 11)
	_ink_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colours.add_child(_ink_name)
	_palette = FlowContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette.add_theme_constant_override("h_separation", 2)
	_palette.add_theme_constant_override("v_separation", 2)
	colours.add_child(_palette)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1.0, 0.86, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	middle.add_child(_status)

	body.add_child(_build_side())
	_files = PictureFile.new()
	add_child(_files)
	_files.picked.connect(add_picture)
	_files.failed.connect(func(why: String) -> void: _status.text = why)


func _build_tools() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(176, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(160, 0)
	column.add_theme_constant_override("separation", 4)
	scroll.add_child(column)
	var group := ButtonGroup.new()
	var names: Dictionary = {"brush": "Brush", "eraser": "Eraser", "line": "Line",
		"box": "Box", "oval": "Oval", "fill": "Fill", "text": "Text", "pick": "Pick a colour",
		"move": "Move picture"}
	var tips: Dictionary = {
		"brush": "Paint, round and hard-edged, as a pad print is",
		"eraser": "Rub out on this layer",
		"line": "A straight line: press, drag, let go",
		"box": "A box between two corners",
		"oval": "An oval in a box between two corners",
		"fill": "Fill what is the colour you click, up to its edge",
		"text": "Words: type them below, click where they start",
		"pick": "Take the colour under the pointer",
		"move": "Drag the picture on this layer; it snaps to the face's edges and middle",
	}
	for tool: String in PrintCanvas.TOOLS:
		var button := Button.new()
		button.text = names[tool]
		button.tooltip_text = tips[tool]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_choose_tool.bind(tool))
		column.add_child(button)
		_tools[tool] = button
	(_tools["brush"] as Button).set_pressed_no_signal(true)
	column.add_child(HSeparator.new())
	var size_words := Label.new()
	size_words.text = "Size"
	size_words.add_theme_font_size_override("font_size", 11)
	column.add_child(size_words)
	_size = HSlider.new()
	_size.accessibility_name = "Brush size"
	_size.min_value = 1
	_size.max_value = 40
	_size.value = 6
	_size.focus_mode = Control.FOCUS_NONE
	_size.tooltip_text = "How wide the brush, the eraser and lines are, in pixels"
	_size.value_changed.connect(func(value: float) -> void: _canvas.radius = value)
	column.add_child(_size)
	_filled = CheckBox.new()
	_filled.text = "Filled"
	_filled.button_pressed = true
	_filled.focus_mode = Control.FOCUS_NONE
	_filled.tooltip_text = "Boxes and ovals filled, or only their outline"
	_filled.toggled.connect(func(on: bool) -> void: _canvas.filled = on)
	column.add_child(_filled)
	_mirror = CheckBox.new()
	_mirror.text = "Mirror"
	_mirror.focus_mode = Control.FOCUS_NONE
	_mirror.tooltip_text = "Draw everything twice, reflected about the middle: both eyes at once"
	_mirror.toggled.connect(func(on: bool) -> void:
		for key: String in _papers:
			(_papers[key] as PrintPaint).mirror = on)
	column.add_child(_mirror)
	_text_row = VBoxContainer.new()
	_text_row.visible = false
	column.add_child(_text_row)
	_words = LineEdit.new()
	_words.text = "Hello"
	_words.placeholder_text = "Words"
	_words.text_changed.connect(func(text: String) -> void: _canvas.words = text)
	_text_row.add_child(_words)
	_word_size = SpinBox.new()
	_word_size.min_value = 6
	_word_size.max_value = 160
	_word_size.value = 32
	_word_size.suffix = "px"
	_word_size.value_changed.connect(func(value: float) -> void: _canvas.word_size = int(value))
	_text_row.add_child(_word_size)
	column.add_child(HSeparator.new())
	var undo_row := HBoxContainer.new()
	column.add_child(undo_row)
	Keymap.tell(_button(undo_row, "Undo", _undo, ""), "Take the last change back ({undo})")
	Keymap.tell(_button(undo_row, "Redo", _redo, ""), "Put it back again ({redo})")
	column.add_child(_build_picture_panel())
	return scroll


## The picture panel: how the active layer's picture is placed and inked.
func _build_picture_panel() -> Control:
	_picture_box = VBoxContainer.new()
	_picture_box.add_theme_constant_override("separation", 3)
	_picture_box.visible = false
	_picture_box.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "Picture"
	heading.add_theme_font_size_override("font_size", 12)
	_picture_box.add_child(heading)
	var fits := HBoxContainer.new()
	_picture_box.add_child(fits)
	_button(fits, "Fit it", func() -> void: _fit_picture(false), "The whole picture on the face")
	_button(fits, "Cover", func() -> void: _fit_picture(true), "The face covered by the picture")
	_button(fits, "Middle", func() -> void:
		_change_picture({"centre": _face_box().get_center()}), "Put it in the middle of the face")
	_picture_scale = _slider(_picture_box, "Size", 5.0, 400.0, 100.0, "As large as it fits, in per cent")
	_picture_scale.value_changed.connect(func(value: float) -> void:
		if _picture_quiet or _paper() == null or _paper().layer().picture == null:
			return
		var picture: PrintPicture = _paper().layer().picture
		var fitted: float = minf(_face_box().size.x / picture.cropped_size().x,
			_face_box().size.y / picture.cropped_size().y)
		_change_picture({"scale": fitted * value / 100.0}))
	_picture_turn = _slider(_picture_box, "Turn", -180.0, 180.0, 0.0, "Turned, in degrees")
	_picture_turn.value_changed.connect(func(value: float) -> void:
		if not _picture_quiet:
			_change_picture({"angle": value}))
	for side: String in ["Crop left", "Crop right", "Crop top", "Crop bottom"]:
		var crop: HSlider = _slider(_picture_box, side, 0.0, 45.0, 0.0, "How much of that side is cut off, in per cent")
		crop.value_changed.connect(func(_value: float) -> void:
			if not _picture_quiet:
				_change_picture({"crop": _crop_rect()}))
		_picture_crop.append(crop)
	_picture_opacity = _slider(_picture_box, "Opacity", 5.0, 100.0, 100.0,
		"How much the plastic shows through, in per cent")
	_picture_opacity.value_changed.connect(func(value: float) -> void:
		if not _picture_quiet:
			_change_picture({"opacity": value / 100.0}))
	_picture_lego = CheckBox.new()
	_picture_lego.text = "LEGO® inks"
	_picture_lego.focus_mode = Control.FOCUS_NONE
	_picture_lego.tooltip_text = ("Every colour the nearest LEGO® ink, flat, as a pad print is; "
		+ "off, the picture's own colours")
	_picture_lego.toggled.connect(func(on: bool) -> void:
		if not _picture_quiet:
			_change_picture({"lego": on}))
	_picture_box.add_child(_picture_lego)
	var inks_row := HBoxContainer.new()
	_picture_box.add_child(inks_row)
	var inks_words := Label.new()
	inks_words.text = "at most"
	inks_words.add_theme_font_size_override("font_size", 11)
	inks_row.add_child(inks_words)
	_picture_inks = SpinBox.new()
	_picture_inks.min_value = 0
	_picture_inks.max_value = 16
	_picture_inks.value = 0
	_picture_inks.suffix = "inks"
	_picture_inks.tooltip_text = "0: as many as it needs"
	_picture_inks.value_changed.connect(func(value: float) -> void:
		if not _picture_quiet:
			_change_picture({"inks": int(value)}))
	inks_row.add_child(_picture_inks)
	_picture_clear = CheckBox.new()
	_picture_clear.text = "Clear its background"
	_picture_clear.focus_mode = Control.FOCUS_NONE
	_picture_clear.tooltip_text = "Whatever is the colour of its corners made clear: a logo's white"
	_picture_clear.toggled.connect(func(on: bool) -> void:
		if not _picture_quiet:
			_change_picture({"clear_back": on}))
	_picture_box.add_child(_picture_clear)
	_picture_flip = CheckBox.new()
	_picture_flip.text = "Mirror it"
	_picture_flip.focus_mode = Control.FOCUS_NONE
	_picture_flip.toggled.connect(func(on: bool) -> void:
		if not _picture_quiet:
			_change_picture({"flipped": on}))
	_picture_box.add_child(_picture_flip)
	_button(_picture_box, "Make it ink", func() -> void:
		if _paper() != null:
			_paper().bake_picture()
			_show_picture()
			_fill_layers(), "Make the picture pixels, to draw on")
	return _picture_box


func _slider(column: Container, words: String, low: float, high: float, value: float,
		tip: String) -> HSlider:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", 11)
	column.add_child(label)
	var slider := HSlider.new()
	slider.accessibility_name = words
	slider.min_value = low
	slider.max_value = high
	slider.step = 1.0
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = tip
	column.add_child(slider)
	return slider


## The face's extent on the canvas: where the mask is.
func _face_box() -> Rect2:
	var paper: PrintPaint = _paper()
	if paper == null:
		return Rect2()
	var area: PartPrints.Area = _areas[_area]
	if area.mask != null:
		var used: Rect2i = area.mask.get_used_rect()
		if used.size.x > 0:
			return Rect2(used)
	return Rect2(0, 0, paper.width, paper.height)


func _crop_rect() -> Rect2:
	var left: float = _picture_crop[0].value / 100.0
	var right: float = _picture_crop[1].value / 100.0
	var top: float = _picture_crop[2].value / 100.0
	var bottom: float = _picture_crop[3].value / 100.0
	return Rect2(left, top, maxf(0.05, 1.0 - left - right), maxf(0.05, 1.0 - top - bottom))


func _change_picture(values: Dictionary) -> void:
	var paper: PrintPaint = _paper()
	if paper == null or not paper.change_picture(values):
		return
	_canvas.refresh()
	_show_picture()


func _fit_picture(cover: bool) -> void:
	var paper: PrintPaint = _paper()
	if paper == null or paper.layer().picture == null:
		return
	var picture: PrintPicture = paper.layer().picture
	var size: Vector2 = picture.cropped_size()
	var box: Rect2 = _face_box()
	var across: float = box.size.x / size.x
	var down: float = box.size.y / size.y
	_change_picture({"scale": maxf(across, down) if cover else minf(across, down),
		"centre": box.get_center(), "angle": 0.0})


## The panel shows the active layer's picture, or hides.
func _show_picture() -> void:
	var paper: PrintPaint = _paper()
	var picture: PrintPicture = paper.layer().picture if paper != null else null
	_picture_box.visible = picture != null
	if picture == null:
		return
	_picture_quiet = true
	var fitted: float = minf(_face_box().size.x / picture.cropped_size().x,
		_face_box().size.y / picture.cropped_size().y)
	_picture_scale.value = picture.scale / maxf(fitted, 1e-6) * 100.0
	_picture_turn.value = picture.angle
	_picture_crop[0].value = picture.crop.position.x * 100.0
	_picture_crop[1].value = (1.0 - picture.crop.end.x) * 100.0
	_picture_crop[2].value = picture.crop.position.y * 100.0
	_picture_crop[3].value = (1.0 - picture.crop.end.y) * 100.0
	_picture_opacity.value = picture.opacity * 100.0
	_picture_lego.button_pressed = picture.lego
	_picture_inks.value = picture.inks
	_picture_clear.button_pressed = picture.clear_back
	_picture_flip.button_pressed = picture.flipped
	_picture_quiet = false


## A picture from a file onto the active area, on a layer of its own,
## fitted to the face, with Move in hand.
func add_picture(image: Image, called: String = "Picture") -> void:
	var paper: PrintPaint = _paper()
	if paper == null:
		return
	paper.add_picture(image, _face_box(), _inks(), called.get_basename() if not called.is_empty() else "Picture")
	_canvas.refresh()
	_fill_layers()
	_show_picture()
	_choose_tool("move")
	_status.text = "%s is on the face: Move drags it, the panel sizes, turns and inks it." % called


## LEGO's inks, as colours, in the palette's order.
func _inks() -> Array[Color]:
	var out: Array[Color] = []
	for swatch: Node in _palette.get_children():
		var colour: Color = (swatch as PartsBin.Swatch).color.rgb
		colour.a = 1.0
		out.append(colour)
	return out


func _build_side() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(270, 0)
	column.add_theme_constant_override("separation", 6)
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(270, 250)
	frame.tooltip_text = "The part wearing the print as it is drawn. Drag to turn it"
	frame.accessibility_name = "The part wearing the print"
	frame.gui_input.connect(_on_preview_input)
	column.add_child(frame)
	_viewport = SubViewport.new()
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.87, 0.87, 0.88)
	environment.ambient_light_energy = BrickWorld.light_energy(0.7)
	world.environment = environment
	_viewport.world_3d = world
	frame.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.near = 2.0
	_camera.far = 2000.0
	_viewport.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, -25.0, 0.0)
	key.light_energy = BrickWorld.light_energy(0.95)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, 160.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.4)
	_viewport.add_child(fill)
	_turntable = Node3D.new()
	_viewport.add_child(_turntable)
	_plain = ShaderMaterial.new()
	_plain.shader = BrickWorld.SHADERS["opaque"]
	_plain.set_shader_parameter("linearise", BrickWorld._linearise_colors())

	var start_words := Label.new()
	start_words.text = "Start from"
	start_words.add_theme_font_size_override("font_size", 12)
	start_words.modulate = Color(1, 1, 1, 0.7)
	column.add_child(start_words)
	_start = OptionButton.new()
	_start.focus_mode = Control.FOCUS_NONE
	_start.fit_to_longest_item = false
	_start.clip_text = true
	_start.add_theme_font_size_override("font_size", 12)
	_start.tooltip_text = "A clean sheet, a print the LEGO Group made for this part, or one made before"
	_start.item_selected.connect(_start_from)
	column.add_child(_start)
	_button(column, "Add a picture…", func() -> void: _files.ask(),
		"A photograph, a logo or a drawing (PNG, JPEG, WebP, BMP or SVG) on a layer of its own, "
			+ "to place on the face")

	var layer_row := HBoxContainer.new()
	layer_row.add_theme_constant_override("separation", 4)
	column.add_child(layer_row)
	var layer_words := Label.new()
	layer_words.text = "Layers"
	layer_words.add_theme_font_size_override("font_size", 12)
	layer_words.modulate = Color(1, 1, 1, 0.7)
	layer_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_row.add_child(layer_words)
	_button(layer_row, "+", func() -> void:
		if _paper() != null:
			_paper().add_layer()
			_fill_layers(), "A new layer above this one")
	_button(layer_row, "Up", func() -> void: _move_layer(1), "Move this layer up")
	_button(layer_row, "Down", func() -> void: _move_layer(-1), "Move this layer down")
	_button(layer_row, "×", func() -> void:
		if _paper() != null and _paper().remove_layer(_paper().active):
			_canvas.refresh()
			_fill_layers(), "Delete this layer")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 80)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_layers = VBoxContainer.new()
	_layers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layers.add_theme_constant_override("separation", 2)
	scroll.add_child(_layers)
	return column


func _button(row: Container, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	row.add_child(button)
	return button


# -- areas, layers, colours ------------------------------------------------------


func _paper() -> PrintPaint:
	if _area < 0 or _area >= _areas.size():
		return null
	return _papers.get(_areas[_area].key)


func _fill_tabs() -> void:
	_tabs.clear_tabs()
	for area: PartPrints.Area in _areas:
		_tabs.add_tab(area.title)
	_tabs.current_tab = 0


func _choose_area(index: int) -> void:
	_area = clampi(index, 0, _areas.size() - 1)
	if _areas.is_empty():
		return
	if _tabs.current_tab != _area:
		_tabs.set_current_tab(_area)
	var paper: PrintPaint = _paper()
	paper.mirror = _mirror.button_pressed
	_canvas.show_area(_areas[_area], paper)
	_fill_layers()
	_fill_palette()
	_face_area()
	_show_picture()


func _fill_layers() -> void:
	for child: Node in _layers.get_children():
		_layers.remove_child(child)
		child.queue_free()
	var paper: PrintPaint = _paper()
	if paper == null:
		return
	# Top of the stack first, as a list of layers reads.
	for n: int in range(paper.layers.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var shown := CheckBox.new()
		shown.button_pressed = paper.layers[n].visible
		shown.focus_mode = Control.FOCUS_NONE
		shown.tooltip_text = "Show this layer"
		shown.toggled.connect(func(on: bool) -> void:
			paper.set_visible(n, on)
			_canvas.refresh())
		row.add_child(shown)
		var pick := Button.new()
		pick.text = paper.layers[n].name + ("  (picture)" if paper.layers[n].picture != null else "")
		pick.toggle_mode = true
		pick.button_pressed = n == paper.active
		pick.focus_mode = Control.FOCUS_NONE
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.add_theme_font_size_override("font_size", 12)
		pick.pressed.connect(func() -> void:
			paper.active = n
			_fill_layers()
			_canvas.refresh())
		row.add_child(pick)
		_layers.add_child(row)
	_show_picture()


func _move_layer(by: int) -> void:
	var paper: PrintPaint = _paper()
	if paper != null and paper.move_layer(paper.active, by):
		_canvas.refresh()
		_fill_layers()


## LEGO's colours: the solid and metallic ones in sets today, which are
## what prints are inked in, black and white first.
func _fill_palette() -> void:
	if _palette.get_child_count() > 0:
		return
	var offered: Array[PartLibrary.BrickColor] = []
	for code: int in library.colors:
		var colour: PartLibrary.BrickColor = library.colors[code]
		if code in PartsBin.NOT_A_COLOUR or not colour.is_plastic() or colour.is_transparent():
			continue
		if not (colour.drawn_as in [PartLibrary.BrickColor.Finish.PLASTIC,
				PartLibrary.BrickColor.Finish.METAL, PartLibrary.BrickColor.Finish.PEARL]):
			continue
		if library.is_current(code) or code in [0, 15]:
			offered.append(colour)
	offered.sort_custom(PartsBin._in_palette_order)
	for colour: PartLibrary.BrickColor in offered:
		var swatch := PartsBin.Swatch.new(colour)
		swatch.tooltip_text = colour.name
		swatch.pressed.connect(func() -> void: _set_ink(colour.rgb, colour.name))
		_palette.add_child(swatch)
	_set_ink(library.color(0).rgb, library.color(0).name)


func _set_ink(ink: Color, called: String) -> void:
	ink.a = 1.0
	_canvas.colour = ink
	_ink.color = ink
	_ink_name.text = called if not called.is_empty() else "#" + ink.to_html(false)
	for swatch: Node in _palette.get_children():
		(swatch as Button).set_pressed_no_signal(
			(swatch as PartsBin.Swatch).color.rgb.is_equal_approx(ink))


func _choose_tool(tool: String) -> void:
	_canvas.tool = tool
	(_tools[tool] as Button).set_pressed_no_signal(true)
	_text_row.visible = tool == "text"


func _undo() -> void:
	if _paper() != null and _paper().undo():
		_canvas.refresh()
		_fill_layers()
		_show_picture()


func _redo() -> void:
	if _paper() != null and _paper().redo():
		_canvas.refresh()
		_fill_layers()
		_show_picture()


# -- starting points -----------------------------------------------------------


func _fill_starts() -> void:
	_start.clear()
	_starts = [["A clean sheet", ""]]
	for kind: String in Starters.KINDS:
		_starts.append(["Starter: " + kind, "starter:" + kind])
	for id: String in PartPrints.bases:
		if not base.is_empty() and PartPrints.bases[id] == base and library.parts.has(id):
			_starts.append(["Made here: " + _short(library.parts[id].name), id])
	if not base.is_empty():
		for info: PartLibrary.PartInfo in PartPrints.prints_of(library, base, 80):
			_starts.append(["%s %s" % [info.id, _short(info.name)], info.id])
	for entry: Array in _starts:
		_start.add_item(str(entry[0]))
	_start.select(0)


static func _short(full: String) -> String:
	var text: String = Minifig._plain(full)
	var cut: int = text.find(" with ")
	return text.substr(cut + 6) if cut > 0 else text


func _start_from(index: int) -> void:
	if index < 0 or index >= _starts.size():
		return
	var id: String = _starts[index][1]
	if id.begins_with("starter:"):
		# Drawn for this canvas, on the area being drawn on.
		var area: PartPrints.Area = _areas[_area]
		var drawn: Image = Starters.draw(id.substr(8), area.size.x, area.size.y, library)
		(_papers[area.key] as PrintPaint).load_image(drawn, id.substr(8).capitalize())
		_status.text = "Started from a %s." % id.substr(8)
		# Named for what it was started as, until someone names it: three
		# dials saved unnamed were three "My Print"s side by side.
		if _name.text.strip_edges().is_empty():
			_name.text = id.substr(8).capitalize()
		_canvas.refresh()
		_fill_layers()
	elif id.is_empty():
		for area: PartPrints.Area in _areas:
			(_papers[area.key] as PrintPaint).load_image(
				Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8))
		_canvas.refresh()
		_fill_layers()
	elif PartPrints.bases.has(id):
		_load_made(id)
	else:
		_load_lego(id)


## A print made here, back on its canvases to change.
func _load_made(id: String) -> void:
	var pictures: Dictionary = PartPrints.pictures_of(library, id)
	for area: PartPrints.Area in _areas:
		if pictures.has(area.key):
			(_papers[area.key] as PrintPaint).load_image(pictures[area.key], "Print")
	var info: PartLibrary.PartInfo = library.parts.get(id)
	if info != null and not PartPrints.given_name(info.name).is_empty():
		_name.text = PartPrints.given_name(info.name)
	_canvas.refresh()
	_fill_layers()


## One of LEGO's prints read off its part onto the canvases: the faces in
## the print's inks where they fall on each area. A pair of legs takes the
## print's left leg and hips too.
func _load_lego(id: String) -> void:
	var sources: Dictionary = {base: id}
	if with.has("left"):
		var left: String = Minifig.partner(library, id)
		if not left.is_empty():
			sources[str(PartPrints.base_of(str(with["left"])))] = left
	if with.has("hips"):
		var hips: Array = MinifigData.LEG_HIPS.get(id, [])
		if not hips.is_empty():
			sources[str(PartPrints.base_of(str(with["hips"])))] = str(hips[0])
	_after_fetching(sources.values(), func() -> void:
		for area: PartPrints.Area in _areas:
			var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
			for index: int in area.parts.size():
				var printed: String = str(sources.get(str(area.parts[index]["part"]), ""))
				if printed.is_empty():
					continue
				var piece: Image = PartPrints.picture_of(library, printed, area, index)
				picture.blend_rect(piece, Rect2i(Vector2i.ZERO, area.size), Vector2i.ZERO)
			(_papers[area.key] as PrintPaint).load_image(picture, id)
		_status.text = "Started from %s." % id
		_canvas.refresh()
		_fill_layers())


# -- the part, wearing it ----------------------------------------------------------


func _build_preview() -> void:
	for child: Node in _turntable.get_children():
		_turntable.remove_child(child)
		child.queue_free()
	_textures.clear()
	var tint: PartLibrary.BrickColor = library.color(colour_code)
	_plain.set_shader_parameter("tint_override", tint.shown)
	_plain.set_shader_parameter("finish_override", tint.instance_custom)
	for area: PartPrints.Area in _areas:
		_textures[area.key] = ImageTexture.create_from_image(
			(_papers[area.key] as PrintPaint).composite())
	var box := AABB()
	var first: bool = true
	var pieces: Array = PartPrints.preview_meshes(library, _areas) if sticker_face == null \
		else [_sticker_piece()]
	for piece: Dictionary in pieces:
		var holder := MeshInstance3D.new()
		holder.mesh = piece["mesh"]
		var material: ShaderMaterial = _plain
		var own: int = int(piece["colour"])
		if own != Lbm.COLOR_INHERIT:
			material = _plain.duplicate()
			material.set_shader_parameter("tint_override", library.color(own).shown)
		if not str(piece["area"]).is_empty():
			material = PartPrints.material_for(_plain, _textures[piece["area"]],
				bool(piece["two_sided"]))
		holder.material_override = material
		_turntable.add_child(holder)
		var aabb: AABB = (piece["mesh"] as ArrayMesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	_turntable.position = -box.get_center()
	_turntable.set_meta("reach", maxf(box.size.length() * 2.1, 40.0))
	_aim()


## A sticker, for the preview: its film, its top printed, facing +Z.
func _sticker_piece() -> Dictionary:
	var size: Vector2 = sticker_face.sticker_size()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var w: float = size.x * 0.5
	var h: float = size.y * 0.5
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w, h, 0), Vector3(w, h, 0),
		Vector3(w, -h, 0), Vector3(-w, h, 0), Vector3(w, -h, 0), Vector3(-w, -h, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK,
		Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
		Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
	var film := ArrayMesh.new()
	film.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"mesh": film, "area": "sticker", "part": "", "colour": Lbm.COLOR_INHERIT,
		"two_sided": true}


## Turn the part to face the area being drawn on.
func _face_area() -> void:
	if _areas.is_empty():
		return
	if sticker_face != null:
		_turn = 0.0
		_tilt = 0.0
		_aim()
		return
	var area: PartPrints.Area = _areas[_area]
	var facing := Vector3(0, 0, 1)
	if area.method == "CYLINDRICAL":
		var out: Vector3 = area.p3 - area.p1
		facing = Vector3(out.x, 0.0, -out.z).normalized()
	else:
		facing = Vector3(area.normal.x, -area.normal.y, -area.normal.z)
	# A face looking straight up or down is seen from the front: atan2 of
	# a -0.0 is half a turn, and showed a tile's top from behind.
	_turn = atan2(facing.x, facing.z) if Vector2(facing.x, facing.z).length() > 1e-3 else 0.0
	_tilt = clampf(asin(clampf(facing.y, -1.0, 1.0)), -1.2, 1.2) * 0.9 + 0.15
	_aim()


func _aim() -> void:
	if _camera == null or _turntable == null:
		return
	var reach: float = float(_turntable.get_meta("reach", 80.0))
	_camera.position = Vector3(sin(_turn) * cos(_tilt), sin(_tilt), cos(_turn) * cos(_tilt)) * reach
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_dragging = (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		_turn -= motion.relative.x * 0.01
		_tilt = clampf(_tilt + motion.relative.y * 0.01, -1.3, 1.3)
		_aim()


## Each change to the canvas, on the part.
func _on_drawn() -> void:
	if _areas.is_empty():
		return
	var key: String = _areas[_area].key
	var texture: ImageTexture = _textures.get(key)
	if texture != null:
		texture.update((_papers[key] as PrintPaint).composite())


# -- saving -----------------------------------------------------------------------


func _save_print() -> void:
	var drawn: Dictionary = {}
	for area: PartPrints.Area in _areas:
		drawn[area.key] = (_papers[area.key] as PrintPaint).composite()
	var title: String = _name.text.strip_edges()
	if title.is_empty():
		title = "My Sticker" if sticker_face != null else "My Print"
	if sticker_face != null:
		var picture: Image = drawn["sticker"]
		if picture.is_invisible():
			_status.text = "Not saved: nothing is drawn on it yet."
			return
		var stuck: Dictionary = Stickers.make(library, picture, sticker_face.sticker_size(), title)
		if not str(stuck["problem"]).is_empty():
			_status.text = "Not saved: %s." % stuck["problem"]
			return
		made.emit([stuck["id"]], "sticker")
		close()
		return
	var result: Dictionary = PartPrints.make(library, base, _areas, drawn, title)
	if not str(result["problem"]).is_empty():
		_status.text = "Not saved: %s." % result["problem"]
		return
	_status.text = "Saved as %s." % ", ".join(result["ids"])
	made.emit(result["ids"], slot)
	close()


## Escape closes, the keymap's Undo undoes; every other key stops here, as in the
## figure builder, so the model's shortcuts do not act on a model nobody
## can see.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed:
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif Keymap.action_of(Keymap.accel_of(key)) in ["undo", "redo"] \
			and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if Keymap.action_of(Keymap.accel_of(key)) == "redo":
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_Y and key.is_command_or_control_pressed() \
			and not (get_viewport().gui_get_focus_owner() is LineEdit):
		_redo()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


## The areas, the canvas and the tools, for a check to use as a person
## would.
func canvas() -> PrintCanvas:
	return _canvas


func areas() -> Array[PartPrints.Area]:
	return _areas


func paper(key: String) -> PrintPaint:
	return _papers.get(key)


func choose_area(key: String) -> void:
	for n: int in _areas.size():
		if _areas[n].key == key:
			_choose_area(n)


func choose_tool(tool: String) -> void:
	_choose_tool(tool)


func set_ink(code: int) -> void:
	var colour: PartLibrary.BrickColor = library.color(code)
	_set_ink(colour.rgb, colour.name)


func set_brush_size(pixels: float) -> void:
	_size.value = pixels


func set_mirror(on: bool) -> void:
	_mirror.button_pressed = on


func set_title(words: String) -> void:
	_name.text = words


func save() -> void:
	_save_print()


## Whether the part's geometry is still being fetched, so its areas are not
## laid out yet.
func fetching() -> bool:
	return _then.is_valid()


## The areas a print can go on now, by key: "sticker" for a sticker.
func area_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for area: PartPrints.Area in _areas:
		keys.append(area.key)
	return keys


## A session's picture (AppTools' print_part), put on [param key]'s area as
## a picture from a file is — fitted to the face, inked — named and saved,
## as Save print does. Why it was not saved, or "".
func draw_and_save(picture: Image, key: String, title: String) -> String:
	var at: int = area_keys().find(key) if not key.is_empty() else 0
	if at < 0:
		return "%s has no area called %s; it has %s" % [base, key, ", ".join(area_keys())]
	_choose_area(at)
	add_picture(picture, title)
	set_title(title)
	_save_print()
	if visible:
		var why: String = _status.text.trim_prefix("Not saved: ").trim_suffix(".")
		close()
		return why if not why.is_empty() else "it could not be saved"
	return ""


func start_from(id: String) -> void:
	for n: int in _starts.size():
		if str(_starts[n][1]) == id:
			_start.select(n)
			_start_from(n)
			return


## Its controls by name, for the page to tell a browser check where they
## are (main._tell_page, through the figure builder).
func controls_by_name() -> Dictionary:
	var named: Dictionary = {"print_canvas": _canvas, "print_name": _name, "print_other": _other,
		"print_start": _start, "print_add_picture": _find_button("Add a picture…"),
		"print_fit": _find_button("Fit it"), "print_fill": _find_button("Cover"),
		"print_lego": _picture_lego, "print_picture_size": _picture_scale,
		"print_picture_turn": _picture_turn, "print_clear_back": _picture_clear,
		"print_save": _save, "print_mirror": _mirror, "print_size": _size}
	for tool: String in _tools:
		named["print_tool_" + tool] = _tools[tool]
	for button: Node in find_children("*", "Button", true, false):
		if (button as Button).text == "Close":
			named["print_close"] = button
	for swatch: Node in _palette.get_children():
		named["print_ink_%d" % int(swatch.get_meta("code", -1))] = swatch
	named["print_on_it"] = _find_button("Print on it")
	# A tab is not a control; a marker laid over each, for the page to say
	# where it is.
	for n: int in _tabs.tab_count:
		if n >= _areas.size():
			break
		var marker: Control = _tab_markers.get(n)
		if marker == null:
			marker = Control.new()
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_tabs.add_child(marker)
			_tab_markers[n] = marker
		var rect: Rect2 = _tabs.get_tab_rect(n)
		marker.position = rect.position
		marker.size = rect.size
		named["print_area_" + _areas[n].key] = marker
	return named


func _find_button(words: String) -> Button:
	for button: Node in find_children("*", "Button", true, false):
		if (button as Button).text == words:
			return button
	return null
