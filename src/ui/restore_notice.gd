## Said above the model when the working model could not be opened at
## start-up: what happened, and where the model is kept (ModelStore.restore).
##
## The app opened the sample car in its place and then autosaved the car
## over it, so a model none of whose parts this build had went for good, and
## nothing said so. It is kept now, and this says where, until the person
## has read it.
class_name RestoreNotice
extends PanelContainer

var _words: Label
var _close: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.17, 0.13, 0.09, 0.97)
	backing.border_color = Color(1.0, 0.72, 0.36, 0.6)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 8
	backing.content_margin_bottom = 8
	add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(300, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88))
	row.add_child(_words)
	_close = ReloadOffer.button("Got it", false)
	_close.pressed.connect(dismiss)
	row.add_child(_close)


## Say [param said] (ModelStore.not_restored).
func tell(said: String) -> void:
	_words.text = said
	visible = true


func dismiss() -> void:
	visible = false


func words() -> String:
	return _words.text if visible else ""


func controls_by_name() -> Dictionary:
	return {"restore_got_it": _close} if visible else {}
