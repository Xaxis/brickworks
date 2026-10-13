## The offer to reload the model on the baseplate, made when another tab
## (or, on the desktop, another window) has saved it since this one opened
## it.
##
## Saved models are the person's, shared by every tab on purpose; the model
## each tab is working on is its own (TabSession). So when one tab saves a
## model another has open, the other is told and asked: reload it, and see
## what was saved, or keep its own, after which saving replaces the other's
## — never one over the other in silence (ModelStore.saved_elsewhere).
class_name ReloadOffer
extends PanelContainer

var store: ModelStore
## Opens a saved model as File › Open does (Main).
var reopen: Callable = func(_path: String) -> void: pass
var say: Callable = func(_line: String) -> void: pass

var _words: Label
var _reload: Button
var _keep: Button
var _name: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	backing.border_color = Color(0.56, 0.74, 1.0, 0.55)
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
	_words.custom_minimum_size = Vector2(240, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)

	_reload = _button("Reload it", true)
	_reload.tooltip_text = "Open the model as it was just saved, in place of this tab's"
	_reload.pressed.connect(reload)
	row.add_child(_reload)
	_keep = _button("Keep mine", false)
	_keep.tooltip_text = "Go on with this tab's model; saving it replaces the one saved elsewhere"
	_keep.pressed.connect(keep)
	row.add_child(_keep)


func _button(words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		var base: Color = Color(0.29, 0.5, 0.92) if main else Color(1, 1, 1, 0.08)
		face.bg_color = base.lightened(0.12) if state == "hover" else (
			base.darkened(0.12) if state == "pressed" else base)
		face.set_corner_radius_all(6)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 6
		face.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	return button


## Say that [param name] was saved elsewhere, and ask.
func offer(name: String) -> void:
	_name = name
	_words.text = ("“%s” was saved in %s. Reload it to work on that one, or keep "
		+ "yours — saving then replaces it.") % [name, TabSession.elsewhere()]
	visible = true


func showing() -> bool:
	return visible


func reload() -> void:
	visible = false
	reopen.call(ModelStore.saved_path(_name))
	say.call("reloaded “%s” as it was saved in %s" % [_name, TabSession.elsewhere()])


func keep() -> void:
	visible = false
	if store != null:
		store.know(ModelStore.saved_path(_name))
	say.call("kept yours — Save replaces “%s” as saved in %s" % [_name, TabSession.elsewhere()])


## The model has changed under the offer (opened, begun again): nothing to ask.
func dismiss() -> void:
	visible = false


func controls_by_name() -> Dictionary:
	return {"reload_model": _reload, "keep_mine": _keep} if visible else {}
