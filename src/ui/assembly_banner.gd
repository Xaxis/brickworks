## Along the top of the model while a sub-assembly is being edited: which
## one, that what is put down goes into it and that its copies follow, and
## the way out. In the strip above the model (Main's notices), not over
## it: it sat over the model's top middle, where a click on a part landed
## on the banner.
class_name AssemblyBanner
extends PanelContainer

var assemblies: Assemblies

var _words: Label
var _done: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.13, 0.2, 0.33, 0.95)
	backing.border_color = Color(0.56, 0.74, 1.0, 0.8)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 12
	backing.content_margin_right = 8
	backing.content_margin_top = 5
	backing.content_margin_bottom = 5
	add_theme_stylebox_override("panel", backing)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_words = Label.new()
	_words.add_theme_font_size_override("font_size", 13)
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_words)
	_done = Button.new()
	_done.text = "Done"
	_done.tooltip_text = "Stop editing inside it   Esc"
	_done.focus_mode = Control.FOCUS_NONE
	_done.add_theme_font_size_override("font_size", 13)
	_done.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_done.pressed.connect(func() -> void: assemblies.leave())
	row.add_child(_done)
	assemblies.entered_changed.connect(_show)
	assemblies.changed.connect(func() -> void: _show(assemblies.entered))
	_show(assemblies.entered)


func _show(path: String) -> void:
	visible = not path.is_empty()
	if not visible:
		return
	var copies: int = assemblies.copies_of(path).size()
	_words.text = "Editing %s%s" % [Assemblies.label(path),
		"" if copies == 0 else "  ·  %s follow%s" % [
			"its copy" if copies == 1 else "%d copies" % copies, "s" if copies == 1 else ""]]
	_words.tooltip_text = ("What you put down goes into it, and a click takes one part of it. "
		+ "Every other copy is changed with it, mirrored where it is mirrored. "
		+ "Esc or Done when finished.")


func controls_by_name() -> Dictionary:
	return {"assembly_done": _done} if visible else {}
