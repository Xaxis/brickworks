## Choosing how big a mosaic should be.
##
## Width is the only real decision, and it is a trade the person has to
## make rather than one to make for them: wider is a better likeness and
## more plates to buy and lay. So the panel says both, live — the
## dimensions in studs, the piece count, and how wide it comes out in
## centimetres, because a mosaic is a physical object and "96 studs"
## means nothing until it is "77 cm".
class_name MosaicDialog
extends PanelContainer

## Stud pitch in millimetres. The real one, which is the whole point.
const STUD_MM := 8.0

var _preview: TextureRect
var _slider: HSlider
var _detail: Label
var _dither: CheckBox
var _image: Image

signal build_wanted(across: int, dither: bool)
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
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var title := Label.new()
	title.text = "Build this as a mosaic"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(300, 220)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_preview)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	var wide := Label.new()
	wide.text = "Width"
	wide.add_theme_font_size_override("font_size", 12)
	row.add_child(wide)

	_slider = HSlider.new()
	_slider.min_value = Mosaic.MIN_WIDTH
	_slider.max_value = Mosaic.MAX_WIDTH
	_slider.step = 1
	_slider.value = 48
	_slider.custom_minimum_size = Vector2(190, 0)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.value_changed.connect(func(_v: float) -> void: _describe())
	row.add_child(_slider)

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 12)
	_detail.modulate = Color(1, 1, 1, 0.68)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)

	_dither = CheckBox.new()
	_dither.text = "Blend colours"
	_dither.button_pressed = true
	_dither.tooltip_text = ("Mix nearby plates to suggest a colour the "
		+ "palette does not have. Off gives flat bands.")
	_dither.add_theme_font_size_override("font_size", 12)
	column.add_child(_dither)

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

	var go := Button.new()
	go.text = "Build it"
	go.pressed.connect(func() -> void:
		visible = false
		build_wanted.emit(int(_slider.value), _dither.button_pressed))
	buttons.add_child(go)


func show_for(image: Image) -> void:
	_image = image
	_preview.texture = ImageTexture.create_from_image(image)
	_describe()
	visible = true


func _describe() -> void:
	if _image == null:
		return
	var across: int = int(_slider.value)
	var down: int = maxi(1, int(round(float(across)
		* float(_image.get_height()) / float(_image.get_width()))))
	# The count is an upper bound: transparent pixels are left out, and
	# how many those are is not known until it is laid out.
	_detail.text = "%d × %d studs — up to %s plates, %.0f × %.0f cm" % [
		across, down, _comma(across * down),
		across * STUD_MM / 10.0, down * STUD_MM / 10.0]


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out := ""
	for index: int in text.length():
		if index > 0 and (text.length() - index) % 3 == 0:
			out += ","
		out += text[index]
	return out
