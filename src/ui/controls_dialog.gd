## What everything does, and the two things about it you can change.
##
## The strip along the bottom is a reminder, not a reference: it wraps,
## it drops the tail when the window is narrow, and it is deliberately
## faint. Somebody who wants to know what the middle button does needs
## somewhere to look that is none of those things.
##
## The list here is the same list the strip draws, from the same
## function, so the two cannot drift apart. That has gone wrong before —
## the strip went on claiming shift-drag boxed a selection for a while
## after a plain drag started doing it.
class_name ControlsDialog
extends PanelContainer

var _rows: GridContainer

signal changed


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
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_rows = GridContainer.new()
	_rows.columns = 2
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("h_separation", 18)
	_rows.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_rows)
	_fill()

	column.add_child(HSeparator.new())

	_toggle(column, "Invert zoom direction",
		"Scroll away from you to zoom out instead of in.",
		ViewPrefs.invert_zoom,
		func(on: bool) -> void: ViewPrefs.invert_zoom = on)
	_toggle(column, "Middle button slides instead of turning",
		"Like Fusion and Onshape. Shift always does the other one.",
		ViewPrefs.middle_slides,
		func(on: bool) -> void: ViewPrefs.middle_slides = on)

	# Which build this is and when it went out. The owner, looking at the
	# live site, had no way to tell when it had last been deployed; the
	# deploy writes version.json beside the build, and this reads it. A
	# downloaded desktop build says its version and the release it came
	# from (BuildInfo), so a report about it can say which one.
	_version = Label.new()
	_version.add_theme_font_size_override("font_size", 11)
	_version.modulate = Color(1, 1, 1, 0.6)
	_version.text = BuildInfo.describe()
	column.add_child(_version)
	if OS.has_feature("web"):
		_read_version.call_deferred()

	var done := Button.new()
	done.text = "Done"
	# Or the next press of a letter runs whatever this button is,
	# because a focused button takes the space bar and the return key.
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(func() -> void: visible = false)
	column.add_child(done)


## The bindings, read from the one place they are written down.
func _fill() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	for binding: ControlsHint.Binding in ControlsHint.for_keyboard():
		var keys := Label.new()
		keys.text = " / ".join(binding.keys)
		keys.add_theme_font_size_override("font_size", 12)
		keys.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(keys)

		var verb := Label.new()
		verb.text = binding.verb
		verb.add_theme_font_size_override("font_size", 12)
		verb.add_theme_color_override("font_color", Color(0.62, 0.65, 0.72))
		verb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_child(verb)


func _toggle(column: VBoxContainer, text: String, why: String,
		on: bool, set_it: Callable) -> void:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", 12)
	box.toggled.connect(func(pressed: bool) -> void:
		set_it.call(pressed)
		ViewPrefs.keep()
		# The list above says what the middle button does, so it is
		# wrong the moment that changes.
		_fill()
		changed.emit())
	column.add_child(box)

	var note := Label.new()
	note.text = why
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)


var _version: Label


func _read_version() -> void:
	var where: Variant = JavaScriptBridge.eval(
		"new URL('version.json', location.href).href")
	if typeof(where) != TYPE_STRING:
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int,
			_headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			return
		# In the reader's own time zone, which only the browser knows.
		var when: Variant = JavaScriptBridge.eval(
			"new Date(%s).toLocaleString(undefined, {dateStyle: 'medium', timeStyle: 'short'})"
			% JSON.stringify(str(parsed.get("deployed", ""))))
		_version.text = "%s. This build: %s, updated %s" % [
			BuildInfo.describe(), str(parsed.get("commit", "?")),
			str(when) if typeof(when) == TYPE_STRING else str(parsed.get("deployed", "?"))])
	http.request(str(where))


func open() -> void:
	_fill()
	visible = true
