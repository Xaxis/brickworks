## Choosing how a picture is to be built.
##
## Two ways. Art, the default, is how a modern LEGO Art set lays a picture
## (MosaicArt): 16 x 16 panels, round tiles for texture, quarter circles
## along the contours, merged tiles where it is flat, stars in accent
## finishes and the part that stands out raised on plates. Classic is one
## 1 x 1 plate a pixel (Mosaic).
##
## Size is the real decision either way, and a trade the person has to make
## rather than one to make for them: bigger is a better likeness and more to
## buy and lay. So the panel says both, live — the dimensions in studs and
## centimetres, because a picture is a physical object and "96 studs" means
## nothing until it is "77 cm", and for Art what it comes to, element by
## element, with the picture it makes drawn above.
class_name MosaicDialog
extends PanelContainer

## Stud pitch in millimetres. The real one, which is the whole point.
const STUD_MM := 8.0

## The part library, for the Art mode's live count and picture. Without it
## the Art mode still builds; it just cannot say what it comes to first.
var library: PartLibrary

var _preview: TextureRect
var _slider: HSlider
var _detail: Label
var _dither: CheckBox
var _image: Image

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
var _go: Button
var _later: Timer
## What the Art comes to as chosen, worked out after each change.
var last_art: MosaicArt.Art

signal build_wanted(across: int, dither: bool)
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
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "Build this picture"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(300, 220)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_preview)

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

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	column.add_child(modes)
	var group := ButtonGroup.new()
	_art_mode = _mode(modes, group, "LEGO Art",
		"Panels of round tiles, quarter circles, smooth tiles and raised relief, as a LEGO Art set is built")
	_classic_mode = _mode(modes, group, "Classic",
		"One 1 × 1 plate a pixel, flat")
	_art_mode.button_pressed = true

	# Classic: a width and the blend.
	_classic_box = VBoxContainer.new()
	_classic_box.add_theme_constant_override("separation", 8)
	column.add_child(_classic_box)
	var row: HBoxContainer = _row(_classic_box, "Width")
	_slider = _range(row, Mosaic.MIN_WIDTH, Mosaic.MAX_WIDTH, 48)
	_dither = CheckBox.new()
	_dither.text = "Blend colours"
	_dither.button_pressed = true
	_dither.tooltip_text = ("Mix nearby plates to suggest a colour the "
		+ "palette does not have. Off gives flat bands.")
	_dither.add_theme_font_size_override("font_size", 12)
	_dither.toggled.connect(func(_on: bool) -> void: _describe())
	_classic_box.add_child(_dither)

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
	_art_box.add_child(claude)
	_brief = LineEdit.new()
	_brief.placeholder_text = "Tell Claude: raise the core, make the stars glow…"
	_brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brief.add_theme_font_size_override("font_size", 12)
	_brief.text_submitted.connect(func(_text: String) -> void: design_with_claude())
	claude.add_child(_brief)
	_ask = Button.new()
	_ask.text = "Design with Claude"
	_ask.tooltip_text = ("Claude looks at the picture and plans it as a LEGO Art "
		+ "designer would — what stands out, the textures, the stars — with your "
		+ "key or your own Claude, as the assistant designs")
	_ask.add_theme_font_size_override("font_size", 12)
	_ask.pressed.connect(design_with_claude)
	claude.add_child(_ask)

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


## Its controls, for the page to find (Main._tell_page): what
## tools/web/art_flow.mjs presses.
func controls_by_name() -> Dictionary:
	return {"mosaic_art": _art_mode, "mosaic_classic": _classic_mode,
		"mosaic_panels": _panels, "mosaic_brief": _brief, "mosaic_claude": _ask,
		"mosaic_build": _go}


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
	return out


## Choose the mode, for a probe or a session: "art" or "classic".
func set_mode(mode: String) -> void:
	(_classic_mode if mode == "classic" else _art_mode).button_pressed = true


func build() -> void:
	visible = false
	if is_art():
		art_wanted.emit(options())
	else:
		build_wanted.emit(int(_slider.value), _dither.button_pressed)


## The Art the dialog has already worked out for what is chosen now, or
## null when a change is still to be worked out: Build lays it as it is
## rather than working the same picture out again in the frame it was
## pressed in (half a second of a browser's page for a 48 x 32 picture).
func current_art() -> MosaicArt.Art:
	return last_art if _later != null and _later.is_stopped() and is_art() else null


## Hand the picture to Claude to plan, with whatever the person typed.
func design_with_claude() -> void:
	visible = false
	claude_wanted.emit(_brief.text.strip_edges())
	_brief.text = ""


## What a design run is asked when the dialog hands it the picture: on the
## panels the person chose, since the size is theirs to decide.
static func art_brief(said: String, panels: Vector2i) -> String:
	var ask: String = ("Make the picture I chose into a LEGO Art set with make_art, "
		+ "%d x %d panels: look_at_picture first, then plan it as a LEGO Art "
		% [panels.x, panels.y] + "designer would.")
	return ask if said.is_empty() else "%s %s" % [ask, said]


## The panels across and down as the sliders stand.
func chosen_panels() -> Vector2i:
	return Vector2i(int(_panels.value), int(_down.value))


func show_for(image: Image) -> void:
	_image = image
	_down_chosen = false
	_preview.texture = ImageTexture.create_from_image(image)
	_describe()
	visible = true


func _show_mode() -> void:
	if _art_box == null:
		return
	_art_box.visible = is_art()
	_classic_box.visible = not is_art()
	_describe()


func _describe() -> void:
	if _image == null or _detail == null:
		return
	if not is_art():
		_preview.texture = ImageTexture.create_from_image(_image)
		var across: int = int(_slider.value)
		var down: int = maxi(1, int(round(float(across)
			* float(_image.get_height()) / float(_image.get_width()))))
		# The count is an upper bound: transparent pixels are left out, and
		# how many those are is not known until it is laid out.
		_detail.text = "%d × %d studs — up to %s plates, %.0f × %.0f cm" % [
			across, down, _comma(across * down),
			across * STUD_MM / 10.0, down * STUD_MM / 10.0]
		return
	if not _down_chosen:
		var auto := MosaicArt.Options.new()
		auto.panels_across = int(_panels.value)
		_down.set_value_no_signal(MosaicArt.size_for(_image, auto).y)
	_panels_said.text = "%d × %d" % [int(_panels.value), int(_down.value)]
	_down_said.text = ""
	_depth_said.text = "flat" if int(_depth.value) == 0 else "%d plate%s" % [
		int(_depth.value), "" if int(_depth.value) == 1 else "s"]
	var studs := Vector2i(int(_panels.value), int(_down.value)) * MosaicArt.PANEL
	_detail.text = "%d × %d studs, %.0f × %.0f cm — working it out…" % [
		studs.x, studs.y, studs.x * STUD_MM / 10.0, studs.y * STUD_MM / 10.0]
	_later.start()


## The Art worked out as chosen, its picture shown and its parts counted.
func _work_out() -> void:
	if _image == null or not is_art() or library == null:
		return
	var art: MosaicArt.Art = MosaicArt.make(_image, options(), library)
	last_art = art
	var studs := Vector2i(art.plan.across, art.plan.down)
	_preview.texture = ImageTexture.create_from_image(MosaicArt.picture_of(art, library,
		clampi(480 / maxi(studs.x, studs.y), 2, 8)))
	var said := PackedStringArray()
	for entry: Array in art.by_element():
		said.append("%s %s" % [_comma(int(entry[1])), str(entry[0])])
	_detail.text = "%d × %d studs, %.0f × %.0f cm — %s parts: %s" % [
		studs.x, studs.y, studs.x * STUD_MM / 10.0, studs.y * STUD_MM / 10.0,
		_comma(art.placements.size()), ", ".join(said)]


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out := ""
	for index: int in text.length():
		if index > 0 and (text.length() - index) % 3 == 0:
			out += ","
		out += text[index]
	return out
