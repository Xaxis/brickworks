## The one warning that this browser may clear the person's models, with
## the ways to keep a copy: shown above the model once, where the browser
## would not agree to keep them or is Safari (StorageKeep), and never again
## on this device once it has been seen.
##
## On the web a person's models are in the browser and nowhere else; the
## account keeps none, and this says so rather than offering one. What it
## offers is what there is: every saved model downloaded in one zip of
## LDraw files, and the model on the baseplate as a BrickLink Studio file.
class_name StorageOffer
extends PanelContainer

## Every saved model, downloaded (Exports.all_models).
var download_all: Callable = func() -> void: pass
## The model on the baseplate as a Studio file (Exports.studio_io).
var download_io: Callable = func() -> void: pass

var _words: Label
var _all: Button
var _io: Button
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
	_all = ReloadOffer.button("Download my models", true)
	_all.tooltip_text = "Every model you have saved here, as LDraw files in one .zip"
	_all.pressed.connect(func() -> void: download_all.call())
	row.add_child(_all)
	_io = ReloadOffer.button("This one for Studio", false)
	_io.tooltip_text = "The model on the baseplate as a BrickLink Studio .io file"
	_io.pressed.connect(func() -> void: download_io.call())
	row.add_child(_io)
	_close = ReloadOffer.button("Got it", false)
	_close.tooltip_text = "Not shown again on this device"
	_close.pressed.connect(func() -> void: visible = false)
	row.add_child(_close)


## Warn, if there is reason to and it has not been shown on this device.
## [param has_models]: the person has saved models, so there is something
## the browser could clear. True when it showed.
func offer_if_due(has_models: bool) -> bool:
	if visible or not has_models or bool(ShellPrefs.value("storage_warned")):
		return false
	var said: String = StorageKeep.warning()
	if said.is_empty():
		return false
	_words.text = said
	visible = true
	ShellPrefs.put("storage_warned", true)
	return true


func showing() -> bool:
	return visible


func words() -> String:
	return _words.text if visible else ""


func controls_by_name() -> Dictionary:
	return {"storage_download_all": _all, "storage_download_io": _io,
		"storage_got_it": _close} if visible else {}
