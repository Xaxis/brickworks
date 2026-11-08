## Choosing how a picture is to be built.
##
## Two ways. Art, the default, is how a modern LEGO Art set lays a picture
## (MosaicArt): 16 x 16 panels, round tiles for texture, quarter circles
## along the contours, merged tiles where it is flat, stars in accent
## finishes and the part that stands out raised on plates. Classic is plates
## (Mosaic): a 1 x 1 a stud, or each run of one colour in the largest plate
## it fills, the picture the same stud for stud in far fewer parts.
##
## Either way the person chooses what of the picture is built, by drawing
## a crop on it, and the colours it is laid in: all of them, a set's (its
## parts' colours, so a LEGO Art set they own can be built again as their
## own picture), or those they own the mosaic's own parts in (My
## collection). Every stud is one of the colours chosen.
##
## Size is the real decision either way, and a trade the person has to make
## rather than one to make for them: bigger is a better likeness and more to
## buy and lay. So the panel says both, live — the dimensions in studs and
## centimetres, because a picture is a physical object and "96 studs" means
## nothing until it is "77 cm", and what it comes to, element by element or
## plate by plate, with the picture it makes drawn above.
class_name MosaicDialog
extends PanelContainer

## Stud pitch in millimetres. The real one, which is the whole point.
const STUD_MM := 8.0
## The whole picture, as a crop.
const WHOLE := Rect2(0, 0, 1, 1)
## The smallest crop a drag draws, a fraction of the picture each way: less
## is a click.
const LEAST_CROP := 0.03

## Where the colours come from.
enum Colours { ALL, SET, OWNED }

## The part library, for the Art mode's live count and picture. Without it
## the Art mode still builds; it just cannot say what it comes to first.
var library: PartLibrary
## What the person owns, part and colour -> how many (CollectionStore.on_hand):
## the colours they own the mosaic's parts in, and how many of them they have.
var owned: Callable = func() -> Dictionary: return {}

var _preview: TextureRect
var _slider: HSlider
var _detail: Label
var _dither: CheckBox
var _mixed: CheckBox
var _image: Image

## The part of the picture built, as fractions of it from its top left: all
## of it until a crop is drawn on it.
var _crop: Rect2 = WHOLE
var _cropping: Button
var _whole: Button
## Over the picture while cropping: the crop drawn, and dragged.
var _frame: Control
## While a drag is on the picture: 1 drawing a crop, 2 moving it.
var _drag: int = 0
var _drag_from := Vector2.ZERO
var _drag_was: Rect2 = WHOLE

var _colours: OptionButton
var _palette_row: HBoxContainer
var _set_number: LineEdit
var _palette_said: Label
var _swatches: Control
var _look_up: Timer
var _books: SetInventories
## The colours chosen, as LDraw codes; empty for all of them.
var palette := PackedInt32Array()
## The set the colours were last taken from ("31197-1"), its name and its
## colours; empty while none is found.
var _set_found: String = ""
var _set_name: String = ""
var _set_colours := PackedInt32Array()

var _art_mode: Button
var _classic_mode: Button
var _classic_box: VBoxContainer
var _art_box: VBoxContainer
var _panels: HSlider
var _panels_said: Label
var _down: HSlider
var _down_said: Label
## Set once the person moves the panels down: from then on it is theirs,
## not the picture's proportions.
var _down_chosen: bool = false
var _depth: HSlider
var _depth_said: Label
var _round: CheckBox
var _quarters: CheckBox
var _smooth: CheckBox
var _accents: CheckBox
var _blend: CheckBox
var _brief: LineEdit
var _ask: Button
## The brief and Design with Claude: gone while the assistant is off
## (Settings, Assistant (AI)), which leaves the Art to the switches above.
var _claude_row: HBoxContainer
var claude_shown: bool = true
var _go: Button
var _later: Timer
## What the Art comes to as chosen, worked out after each change.
var last_art: MosaicArt.Art
## What the Classic mosaic comes to as chosen, likewise.
var last_classic: Mosaic.Laid

signal build_wanted(options: Mosaic.Options)
signal art_wanted(options: MosaicArt.Options)
## The picture to be planned by Claude, with what the person said of it.
signal claude_wanted(brief: String)
signal cancelled


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
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var title := Label.new()
	title.text = "Build this picture"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(300, 150)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_preview)
	# The crop is drawn on the picture itself, as every photo editor has it:
	# drag across it for a new one, from inside it to move it.
	_frame = Control.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_crop)
	_frame.gui_input.connect(_crop_input)
	_frame.resized.connect(_frame.queue_redraw)
	_preview.add_child(_frame)

	# What it comes to, under the picture of it. Worked out a moment after
	# each change, it goes from a line ("working it out…") to three or
	# four, and the picture gives way to it. Below the controls it pushed
	# everything above it up by those lines as the count arrived: a click
	# aimed at the brief landed on this text instead, and what was typed
	# next went to the model as shortcuts (tools/web/art_flow.mjs).
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 12)
	_detail.modulate = Color(1, 1, 1, 0.68)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(300, 0)
	column.add_child(_detail)

	# The crop and the colours: what of the picture, in what.
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	column.add_child(choices)
	_cropping = _small(choices, "Crop", "Drag on the picture to choose the part of it to build")
	_cropping.toggle_mode = true
	_cropping.toggled.connect(_show_cropping)
	_whole = _small(choices, "Whole picture", "Build all of the picture again")
	_whole.disabled = true
	_whole.pressed.connect(func() -> void: set_crop(WHOLE))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(gap)
	var named := Label.new()
	named.text = "Colours"
	named.add_theme_font_size_override("font_size", 12)
	choices.add_child(named)
	_colours = OptionButton.new()
	_colours.add_theme_font_size_override("font_size", 12)
	_colours.accessibility_name = "Colours"
	_colours.add_item("All colours", Colours.ALL)
	_colours.add_item("A set's colours", Colours.SET)
	_colours.add_item("What I own", Colours.OWNED)
	_colours.set_item_tooltip(Colours.ALL, "Every colour the parts are made in")
	_colours.set_item_tooltip(Colours.SET, "The colours of a set's parts: type its number")
	_colours.set_item_tooltip(Colours.OWNED,
		"The colours you own its parts in, from My collection")
	_colours.tooltip_text = "The colours it is laid in: every stud is one of them"
	_colours.item_selected.connect(func(_index: int) -> void: _choose_colours())
	choices.add_child(_colours)

	# A set's number, or what is owned: the colours that come to, drawn.
	_palette_row = HBoxContainer.new()
	_palette_row.add_theme_constant_override("separation", 8)
	_palette_row.visible = false
	column.add_child(_palette_row)
	_set_number = LineEdit.new()
	_set_number.placeholder_text = "Set number"
	_set_number.accessibility_name = "Set number"
	_set_number.custom_minimum_size = Vector2(96, 0)
	_set_number.add_theme_font_size_override("font_size", 12)
	_set_number.text_changed.connect(func(_text: String) -> void: _look_up.start())
	_set_number.text_submitted.connect(func(_text: String) -> void: find_set())
	_palette_row.add_child(_set_number)
	var said := VBoxContainer.new()
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	said.add_theme_constant_override("separation", 2)
	_palette_row.add_child(said)
	_palette_said = Label.new()
	_palette_said.add_theme_font_size_override("font_size", 12)
	_palette_said.modulate = Color(1, 1, 1, 0.68)
	_palette_said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_palette_said.custom_minimum_size = Vector2(120, 0)
	said.add_child(_palette_said)
	_swatches = Control.new()
	# Its tooltip is the colours' names, which are data, not the interface's.
	_swatches.set_meta(&"names", true)
	_swatches.custom_minimum_size = Vector2(0, 10)
	_swatches.draw.connect(_draw_swatches)
	_swatches.resized.connect(_swatches.queue_redraw)
	said.add_child(_swatches)
	_look_up = Timer.new()
	_look_up.one_shot = true
	_look_up.wait_time = 0.6
	_look_up.timeout.connect(find_set)
	add_child(_look_up)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	column.add_child(modes)
	var group := ButtonGroup.new()
	_art_mode = _mode(modes, group, "Brick Art",
		"Panels of round tiles, quarter circles, smooth tiles and raised relief, in the style of LEGO® Art sets")
	_classic_mode = _mode(modes, group, "Classic",
		"Plates, flat: a 1 × 1 a stud, or each run of one colour in larger plates")
	_art_mode.button_pressed = true

	# Classic: a width, the blend, and the plates' sizes.
	_classic_box = VBoxContainer.new()
	_classic_box.add_theme_constant_override("separation", 8)
	column.add_child(_classic_box)
	var row: HBoxContainer = _row(_classic_box, "Width")
	_slider = _range(row, Mosaic.MIN_WIDTH, Mosaic.MAX_WIDTH, 48)
	var switches := HBoxContainer.new()
	switches.add_theme_constant_override("separation", 12)
	_classic_box.add_child(switches)
	_dither = CheckBox.new()
	_dither.text = "Blend colours"
	_dither.button_pressed = true
	_dither.tooltip_text = ("Mix nearby plates to suggest a colour the "
		+ "palette does not have. Off gives flat bands.")
	_dither.add_theme_font_size_override("font_size", 12)
	_dither.toggled.connect(func(_on: bool) -> void: _describe())
	switches.add_child(_dither)
	_mixed = CheckBox.new()
	_mixed.text = "Mixed plate sizes"
	_mixed.button_pressed = true
	_mixed.tooltip_text = ("Each run of one colour in the largest plate it fills, up to 8 × 8: "
		+ "the same picture stud for stud, in far fewer parts to buy and lay. Off is a 1 × 1 a stud.")
	_mixed.add_theme_font_size_override("font_size", 12)
	_mixed.toggled.connect(func(_on: bool) -> void: _describe())
	switches.add_child(_mixed)

	# Art: panels across and down, depth, and the element styles.
	_art_box = VBoxContainer.new()
	_art_box.add_theme_constant_override("separation", 6)
	column.add_child(_art_box)
	var across_row: HBoxContainer = _row(_art_box, "Panels across")
	_panels = _range(across_row, 1, MosaicArt.MOST_PANELS, 3)
	_panels_said = _said(across_row)
	var down_row: HBoxContainer = _row(_art_box, "Panels down")
	_down = _range(down_row, 1, MosaicArt.MOST_PANELS, 3)
	_down_said = _said(down_row)
	_down.value_changed.connect(func(_v: float) -> void: _down_chosen = true)
	var depth_row: HBoxContainer = _row(_art_box, "Depth")
	_depth = _range(depth_row, 0, MosaicArt.MOST_DEPTH, 3)
	_depth.tooltip_text = "How many plates what stands out from the background is raised. 0 is flat."
	_depth_said = _said(depth_row)
	var styles := GridContainer.new()
	styles.columns = 2
	styles.add_theme_constant_override("h_separation", 12)
	styles.add_theme_constant_override("v_separation", 0)
	_art_box.add_child(styles)
	_round = _switch(styles, "Round texture", "1 × 1 round tiles, and round plates for points of light")
	_quarters = _switch(styles, "Contour quarters", "Quarter-circle tiles turned along a curved edge")
	_smooth = _switch(styles, "Smooth tiles", "Square tiles where it is flat, merged up to 2 × 4")
	_accents = _switch(styles, "Accent stars", "Stars in trans-clear, glow-in-the-dark and metallic where the part is made so")
	_blend = _switch(styles, "Blend colours", "Mix nearby elements to suggest a colour the palette does not have")

	# Or Claude decides it, as a LEGO Art designer would: what is raised,
	# where the round texture goes, which stars glow. The switches above
	# are the engine's own reading of the picture; this is a plan for it.
	var claude := HBoxContainer.new()
	claude.add_theme_constant_override("separation", 6)
	claude.visible = claude_shown
	_art_box.add_child(claude)
	_claude_row = claude
	_brief = LineEdit.new()
	_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brief.add_theme_font_size_override("font_size", 12)
	_brief.text_submitted.connect(func(_text: String) -> void: design_with_claude())
	claude.add_child(_brief)
	_ask = Button.new()
	_ask.add_theme_font_size_override("font_size", 12)
	_ask.pressed.connect(design_with_claude)
	claude.add_child(_ask)
	_name_designer()

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void:
		visible = false
		cancelled.emit())
	buttons.add_child(cancel)

	_go = Button.new()
	_go.text = "Build it"
	_go.pressed.connect(build)
	buttons.add_child(_go)

	_later = Timer.new()
	_later.one_shot = true
	_later.wait_time = 0.2
	_later.timeout.connect(_work_out)
	add_child(_later)
	_show_mode()


func _mode(parent: Control, group: ButtonGroup, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.toggle_mode = true
	button.button_group = group
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 12)
	button.toggled.connect(func(_on: bool) -> void: _show_mode())
	parent.add_child(button)
	return button


func _small(parent: Control, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	return button


func _row(parent: Control, words: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = words
	label.custom_minimum_size = Vector2(92, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	return row


func _range(row: HBoxContainer, least: int, most: int, value: int) -> HSlider:
	var slider := HSlider.new()
	# Said by the words beside it (_row).
	slider.accessibility_name = (row.get_child(0) as Label).text
	slider.min_value = least
	slider.max_value = most
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(_v: float) -> void: _describe())
	row.add_child(slider)
	return slider


func _said(row: HBoxContainer) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(1, 1, 1, 0.68)
	row.add_child(label)
	return label


func _switch(parent: Control, words: String, tip: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = words
	box.tooltip_text = tip
	box.button_pressed = true
	box.add_theme_font_size_override("font_size", 12)
	box.toggled.connect(func(_on: bool) -> void: _describe())
	parent.add_child(box)
	return box


## Settings, Assistant (AI): Claude's half of the Art shown, or none of it.
func show_claude(on: bool) -> void:
	claude_shown = on
	if _claude_row != null:
		_claude_row.visible = on


## Its controls, for the page to find (Main._tell_page): what
## tools/web/art_flow.mjs presses.
func controls_by_name() -> Dictionary:
	return {"mosaic_art": _art_mode, "mosaic_classic": _classic_mode,
		"mosaic_panels": _panels, "mosaic_brief": _brief, "mosaic_claude": _ask,
		"mosaic_build": _go, "mosaic_crop": _cropping, "mosaic_whole": _whole,
		"mosaic_colours": _colours, "mosaic_set": _set_number, "mosaic_mixed": _mixed}


func is_art() -> bool:
	return _art_mode.button_pressed


## The Art as chosen.
func options() -> MosaicArt.Options:
	var out := MosaicArt.Options.new()
	out.panels_across = int(_panels.value)
	out.panels_down = int(_down.value)
	out.depth = int(_depth.value)
	out.round_texture = _round.button_pressed
	out.contours = _quarters.button_pressed
	out.smooth_tiles = _smooth.button_pressed
	out.accents = _accents.button_pressed
	out.dither = _blend.button_pressed
	out.crop = _crop
	out.palette = palette
	return out


## The Classic mosaic as chosen.
func classic_options() -> Mosaic.Options:
	var out := Mosaic.Options.new()
	out.across = int(_slider.value)
	out.dither = _dither.button_pressed
	out.crop = _crop
	out.palette = palette
	out.mixed = _mixed.button_pressed
	return out


## Choose the mode, for a probe or a session: "art" or "classic".
func set_mode(mode: String) -> void:
	(_classic_mode if mode == "classic" else _art_mode).button_pressed = true


func build() -> void:
	visible = false
	if is_art():
		art_wanted.emit(options())
	else:
		build_wanted.emit(classic_options())


## The Art the dialog has already worked out for what is chosen now, or
## null when a change is still to be worked out: Build lays it as it is
## rather than working the same picture out again in the frame it was
## pressed in (half a second of a browser's page for a 48 x 32 picture).
func current_art() -> MosaicArt.Art:
	return last_art if _later != null and _later.is_stopped() and is_art() else null


## The Classic mosaic already worked out for what is chosen now, likewise.
func current_classic() -> Mosaic.Laid:
	return last_classic if _later != null and _later.is_stopped() and not is_art() else null


## Hand the picture to Claude to plan, with whatever the person typed, and
## the crop and colours they chose.
func design_with_claude() -> void:
	if not claude_shown:
		return
	visible = false
	claude_wanted.emit(_with_choices(_brief.text.strip_edges()))
	_brief.text = ""


## What the person typed, with the crop drawn and the colours chosen said in
## make_art's own terms, so Claude's plan keeps to them: its crop is the
## same fractions, and its palette the chosen colours an Art plan takes.
func _with_choices(said: String) -> String:
	var asks := PackedStringArray()
	if not said.is_empty():
		asks.append(said)
	if not _crop.is_equal_approx(WHOLE):
		asks.append("Keep to the part of the picture I chose: crop %s." % JSON.stringify({
			"x": snappedf(_crop.position.x, 0.001), "y": snappedf(_crop.position.y, 0.001),
			"w": snappedf(_crop.size.x, 0.001), "h": snappedf(_crop.size.y, 0.001)}))
	var kept: Array[int] = []
	for code: int in palette:
		if MosaicArt.SOLID.has(code) or MosaicArt.ACCENTS.has(code):
			kept.append(code)
	if not kept.is_empty():
		asks.append("Keep to the colours I chose: palette %s." % JSON.stringify(kept))
	return " ".join(asks)


## What a design run is asked when the dialog hands it the picture: on the
## panels the person chose, since the size is theirs to decide.
static func art_brief(said: String, panels: Vector2i) -> String:
	var ask: String = ("Make the picture I chose into Brick Art with make_art, "
		+ "%d x %d panels: look_at_picture first, then plan it as a designer of "
		% [panels.x, panels.y] + "LEGO® Art sets would.")
	return ask if said.is_empty() else "%s %s" % [ask, said]


## The panels across and down as the sliders stand.
func chosen_panels() -> Vector2i:
	return Vector2i(int(_panels.value), int(_down.value))


## Who designs (Settings, AI), named on the row that asks it: Claude, or the
## model on the person's key (ProviderSettings.designer_name).
func _name_designer() -> void:
	var who: String = ProviderSettings.designer_name()
	_brief.placeholder_text = "Tell %s: raise the core, make the stars glow…" % who
	_ask.text = "Design with %s" % who
	_ask.tooltip_text = ("%s looks at the picture and plans it as a designer of LEGO® Art "
		% who + "sets would — what stands out, the textures, the stars — "
		+ ("with your key or your own Claude, as the assistant designs" if who == "Claude"
			else "on your own key, as the assistant designs"))


func show_for(image: Image) -> void:
	if _ask != null:
		_name_designer()
	_image = image
	_down_chosen = false
	# A new picture is built whole until a crop is drawn on it.
	_crop = WHOLE
	_whole.disabled = true
	_cropping.button_pressed = false
	tell_owned()
	_preview.texture = ImageTexture.create_from_image(image)
	_describe()
	visible = true


func _show_mode() -> void:
	if _art_box == null:
		return
	_art_box.visible = is_art()
	_classic_box.visible = not is_art()
	# What is owned depends on the parts: plates, or tiles.
	if _colours.selected == Colours.OWNED:
		_choose_colours()
		return
	_describe()


# -- the crop ------------------------------------------------------------


## The part of the picture built, as fractions of it from its top left.
func crop() -> Rect2:
	return _crop


## The picture's own pixels the crop takes in.
func crop_pixels() -> Rect2i:
	return Mosaic.crop_rect(_image.get_size(), _crop) if _image != null else Rect2i()


## Build [param rect] of the picture, fractions of it; the whole of it for
## anything with no area on it.
func set_crop(rect: Rect2) -> void:
	var on: Rect2 = rect.intersection(WHOLE)
	_crop = on if on.size.x > 0.0 and on.size.y > 0.0 else WHOLE
	_whole.disabled = _crop.is_equal_approx(WHOLE)
	_frame.queue_redraw()
	_describe()


## Crop on: the picture itself shown, the crop drawn on it, a drag on it
## drawing or moving it. Off: the result again.
func _show_cropping(on: bool) -> void:
	_cropping.text = "Done" if on else "Crop"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_frame.mouse_default_cursor_shape = Control.CURSOR_CROSS if on else Control.CURSOR_ARROW
	_drag = 0
	if _image != null:
		if on:
			_preview.texture = ImageTexture.create_from_image(_image)
		else:
			_show_result()
	_frame.queue_redraw()


## Where the picture is drawn in the preview: kept to its proportions, in
## the middle (TextureRect.STRETCH_KEEP_ASPECT_CENTERED).
func shown_rect() -> Rect2:
	var texture: Texture2D = _preview.texture
	if texture == null or texture.get_width() == 0 or texture.get_height() == 0:
		return Rect2()
	var room: Vector2 = _preview.size
	var picture: Vector2 = Vector2(texture.get_size())
	var scale: float = minf(room.x / picture.x, room.y / picture.y)
	return Rect2((room - picture * scale) / 2.0, picture * scale)


func _crop_input(event: InputEvent) -> void:
	if not _cropping.button_pressed or _image == null:
		return
	var shown: Rect2 = shown_rect()
	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		return
	var mouse := event as InputEventMouse
	if mouse == null:
		return
	var at: Vector2 = ((mouse.position - shown.position) / shown.size).clamp(Vector2.ZERO, Vector2.ONE)
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			var cropped: bool = not _crop.is_equal_approx(WHOLE)
			_drag = 2 if cropped and _crop.has_point(at) else 1
			_drag_from = at
			_drag_was = _crop
		elif _drag != 0:
			_drag = 0
			_describe()
		_frame.accept_event()
		return
	if event is InputEventMouseMotion and _drag != 0:
		if _drag == 1:
			var drawn := Rect2(_drag_from, Vector2.ZERO).expand(at)
			if drawn.size.x >= LEAST_CROP and drawn.size.y >= LEAST_CROP:
				_crop = drawn
		else:
			var moved: Vector2 = (_drag_was.position + at - _drag_from).clamp(Vector2.ZERO,
				Vector2.ONE - _drag_was.size)
			_crop = Rect2(moved, _drag_was.size)
		_whole.disabled = _crop.is_equal_approx(WHOLE)
		# Only the frame while the drag is on: what it comes to is said once
		# it ends. Said at each move, the lines under the picture changed in
		# number, the picture grew and shrank under the pointer, and the crop
		# ended 10 pixels of 300 short of where it was let go.
		_frame.queue_redraw()
		_frame.accept_event()


## The crop on the picture: what is left out dimmed, the crop's edge drawn.
func _draw_crop() -> void:
	if not _cropping.button_pressed or _image == null:
		return
	var shown: Rect2 = shown_rect()
	var box := Rect2(shown.position + _crop.position * shown.size, _crop.size * shown.size)
	var dim := Color(0, 0, 0, 0.6)
	_frame.draw_rect(Rect2(shown.position, Vector2(shown.size.x, box.position.y - shown.position.y)), dim)
	_frame.draw_rect(Rect2(Vector2(shown.position.x, box.end.y),
		Vector2(shown.size.x, shown.end.y - box.end.y)), dim)
	_frame.draw_rect(Rect2(Vector2(shown.position.x, box.position.y),
		Vector2(box.position.x - shown.position.x, box.size.y)), dim)
	_frame.draw_rect(Rect2(Vector2(box.end.x, box.position.y),
		Vector2(shown.end.x - box.end.x, box.size.y)), dim)
	_frame.draw_rect(box, Color.WHITE, false, 2.0)


# -- the colours ---------------------------------------------------------


## The colours chosen as the list says: all, the set's found, or what is
## owned of this mode's parts.
func _choose_colours() -> void:
	match _colours.selected:
		Colours.SET:
			palette = _set_colours
		Colours.OWNED:
			palette = _owned_colours()
		_:
			palette = PackedInt32Array()
	_palette_row.visible = _colours.selected != Colours.ALL
	_set_number.visible = _colours.selected == Colours.SET
	_tell_palette()
	_describe()


## Choose where the colours come from, for a probe or a session: "all",
## "set" or "owned".
func set_colours(which: String) -> void:
	var index: int = {"set": Colours.SET, "owned": Colours.OWNED}.get(which, Colours.ALL)
	_colours.select(index)
	_choose_colours()


## The parts a mosaic of this mode is laid in, whose colours are what the
## person owns of it: plates for Classic, the tiles on top for the Art.
func _own_parts() -> PackedStringArray:
	if not is_art():
		return Mosaic.plate_parts()
	var out := PackedStringArray([MosaicArt.ROUND, MosaicArt.SQUARE, MosaicArt.QUARTER,
		MosaicArt.SPECK])
	for shape: Array in MosaicArt.TILES:
		out.append(str(shape[0]))
	return out


func _owned_colours() -> PackedInt32Array:
	if library == null:
		return PackedInt32Array()
	var chosen: PackedInt32Array = Mosaic.colours_in(owned.call(), library, _own_parts())
	var out := PackedInt32Array()
	for code: int in chosen:
		if Mosaic.paintable(code, library):
			out.append(code)
	return out


## The collection has come (or changed): What I own offered when there is
## something of it, and its colours taken again when it is the choice.
func tell_owned() -> void:
	if _colours == null:
		return
	var none: bool = _owned_colours().is_empty()
	_colours.set_item_disabled(Colours.OWNED, none)
	_colours.set_item_tooltip(Colours.OWNED, "The colours you own its parts in, from My collection"
		if not none else "Add your parts or sets in My collection to build from what you own")
	if _colours.selected == Colours.OWNED:
		if none:
			_colours.select(Colours.ALL)
		_choose_colours()


## Look up the set typed, and take its parts' colours.
func find_set() -> void:
	_look_up.stop()
	var number: String = SetInventories.normal(_set_number.text)
	if number.is_empty():
		_set_found = ""
		_set_colours = PackedInt32Array()
	elif number != _set_found:
		if _books == null:
			_books = SetInventories.new()
			add_child(_books)
		_palette_said.text = "looking up %s…" % number
		var found: Dictionary = await _books.lookup(PackedStringArray([number]))
		# Typed on since: that one is looked up in its turn.
		if SetInventories.normal(_set_number.text) != number:
			return
		var record: Variant = found.get(number)
		_set_found = number if record is Dictionary else ""
		_set_name = str((record as Dictionary).get("n", "")) if record is Dictionary else ""
		_set_colours = Mosaic.colours_in((record as Dictionary).get("p", []), library) \
			if record is Dictionary and library != null else PackedInt32Array()
		if record == null:
			_palette_said.text = ("no set %s is known" % number if _books.trouble.is_empty()
				else _books.trouble)
			_swatches.queue_redraw()
			if _colours.selected == Colours.SET:
				palette = PackedInt32Array()
				_describe()
			return
	if _colours.selected == Colours.SET:
		palette = _set_colours
		_describe()
	_tell_palette()


## The colours chosen, said and drawn.
func _tell_palette() -> void:
	var shown: PackedInt32Array = _paintable(palette)
	match _colours.selected:
		Colours.SET:
			_palette_said.text = ("%s “%s”: %d colours" % [_set_found.trim_suffix("-1"), _set_name,
				shown.size()] if not _set_found.is_empty() else "Type a set's number")
		Colours.OWNED:
			_palette_said.text = "%d colours you own its parts in" % shown.size()
		_:
			_palette_said.text = ""
	_palette_said.tooltip_text = _palette_said.text
	var names := PackedStringArray()
	for code: int in shown:
		var colour: PartLibrary.BrickColor = library.color(code) if library != null else null
		names.append(colour.name if colour != null else str(code))
	_swatches.tooltip_text = ", ".join(names)
	_swatches.queue_redraw()


## The chosen colours a stud can be.
func _paintable(codes: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if library == null:
		return out
	for code: int in codes:
		if Mosaic.paintable(code, library):
			out.append(code)
	return out


func _draw_swatches() -> void:
	if library == null or _colours.selected == Colours.ALL:
		return
	var codes: PackedInt32Array = _paintable(palette)
	if codes.is_empty():
		return
	var side: float = clampf((_swatches.size.x + 2.0) / codes.size() - 2.0, 3.0, 10.0)
	for k: int in codes.size():
		var colour: PartLibrary.BrickColor = library.color(codes[k])
		var box := Rect2(k * (side + 2.0), (_swatches.size.y - side) / 2.0, side, side)
		_swatches.draw_rect(box, colour.rgb if colour != null else Color.MAGENTA)
		_swatches.draw_rect(box, Color(1, 1, 1, 0.25), false, 1.0)


# -- what it comes to ----------------------------------------------------


func _describe() -> void:
	if _image == null or _detail == null:
		return
	var seen: Vector2i = crop_pixels().size
	if not is_art():
		var across: int = clampi(int(_slider.value), Mosaic.MIN_WIDTH, Mosaic.MAX_WIDTH)
		var down: int = maxi(1, roundi(float(across) * seen.y / maxf(seen.x, 1.0)))
		_detail.text = "%d × %d studs, %.0f × %.0f cm — working it out…" % [
			across, down, across * STUD_MM / 10.0, down * STUD_MM / 10.0]
		_later.start()
		return
	if not _down_chosen:
		var auto := MosaicArt.Options.new()
		auto.panels_across = int(_panels.value)
		auto.crop = _crop
		_down.set_value_no_signal(MosaicArt.size_for(_image, auto).y)
	_panels_said.text = "%d × %d" % [int(_panels.value), int(_down.value)]
	_down_said.text = ""
	_depth_said.text = "flat" if int(_depth.value) == 0 else "%d plate%s" % [
		int(_depth.value), "" if int(_depth.value) == 1 else "s"]
	var studs := Vector2i(int(_panels.value), int(_down.value)) * MosaicArt.PANEL
	_detail.text = "%d × %d studs, %.0f × %.0f cm — working it out…" % [
		studs.x, studs.y, studs.x * STUD_MM / 10.0, studs.y * STUD_MM / 10.0]
	_later.start()


## What is chosen worked out, its picture shown and its parts counted.
func _work_out() -> void:
	if _image == null or library == null:
		return
	# Not under a drag on the picture, which its lines would move: after it.
	if _drag != 0:
		_later.start()
		return
	if not is_art():
		var laid: Mosaic.Laid = Mosaic.make(_image, classic_options(), library)
		last_classic = laid
		_show_result()
		var sizes := PackedStringArray()
		for entry: Array in laid.by_size().slice(0, 4):
			sizes.append("%s %s" % [_comma(int(entry[1])), str(entry[0])])
		_detail.text = "%d × %d studs, %.0f × %.0f cm — %s plates for its %s studs, in %d colours: %s%s%s%s" % [
			laid.across, laid.down, laid.across * STUD_MM / 10.0, laid.down * STUD_MM / 10.0,
			_comma(laid.plates.size()), _comma(laid.studs()), laid.colours(), ", ".join(sizes),
			", …" if laid.by_size().size() > 4 else "", _have(laid.counts()),
			"" if laid.palette_kept else
				" — no 1 × 1 plate is made in the colours chosen, so it is laid in all of them"]
		return
	var art: MosaicArt.Art = MosaicArt.make(_image, options(), library)
	last_art = art
	_show_result()
	var studs := Vector2i(art.plan.across, art.plan.down)
	var said := PackedStringArray()
	for entry: Array in art.by_element():
		said.append("%s %s" % [_comma(int(entry[1])), str(entry[0])])
	var needs: Dictionary = {}
	for placement: Assistant.Placement in art.placements:
		var key: String = "%s/%d" % [placement.part, placement.color]
		needs[key] = int(needs.get(key, 0)) + 1
	# The kinds joined by " · ", which the languages find one by one ("%s
	# round tiles"); joined by commas, the list was one place no entry took.
	_detail.text = "%d × %d studs, %.0f × %.0f cm — %s parts — %s%s%s" % [
		studs.x, studs.y, studs.x * STUD_MM / 10.0, studs.y * STUD_MM / 10.0,
		_comma(art.placements.size()), " · ".join(said), _have(needs),
		"" if art.palette_kept else
			" — no round or square tile is made in the colours chosen, so it is laid in the Art's own"]


## The result drawn in the preview, unless the picture is being cropped.
func _show_result() -> void:
	if _cropping.button_pressed or _image == null:
		return
	if not is_art() and last_classic != null:
		_preview.texture = ImageTexture.create_from_image(Mosaic.picture_of(last_classic, library,
			clampi(480 / maxi(maxi(last_classic.across, last_classic.down), 1), 2, 8)))
	elif is_art() and last_art != null:
		var studs := Vector2i(last_art.plan.across, last_art.plan.down)
		_preview.texture = ImageTexture.create_from_image(MosaicArt.picture_of(last_art, library,
			clampi(480 / maxi(maxi(studs.x, studs.y), 1), 2, 8)))
	else:
		_preview.texture = ImageTexture.create_from_image(_image)


## How many of [param needs] ("part/colour" -> count) the person has, when
## they chose to build from what they own: " — you have 230 of them".
func _have(needs: Dictionary) -> String:
	if _colours.selected != Colours.OWNED or library == null:
		return ""
	var keyed: Dictionary = {}
	var pieces: int = 0
	for key: String in needs:
		var spelt: String = Collection.key_of(key.get_slice("/", 0), int(key.get_slice("/", 1)), library)
		keyed[spelt] = int(keyed.get(spelt, 0)) + int(needs[key])
		pieces += int(needs[key])
	var have: int = int(Collection.coverage(keyed, owned.call()).get("owned", 0))
	return " — you have %s of the %s" % [_comma(have), _comma(pieces)]


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out := ""
	for index: int in text.length():
		if index > 0 and (text.length() - index) % 3 == 0:
			out += ","
		out += text[index]
	return out
