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
##
## Each row is drawn the way the strip draws it — keys as keys, the mouse
## and fingers as pictures of themselves — with the pointer that control
## shows beside it, so the cursor seen over the model can be looked up
## here. Both follow the two settings below: change what the middle
## button does and its row changes picture and verb at once.
class_name ControlsDialog
extends PanelContainer

## How big it would like to be, before the window has its say.
const WIDE := 520.0
const TALL := 720.0

## Interface units: a key or a picture in a row, the column the keys are
## right-aligned in (wide enough for 1 to 7), and the pointer's column.
const KEY_TALL := 20.0
const KEYS_WIDE := 178.0
const POINTER_WIDE := 28.0
## The cursor's own picture is mostly air around a pointer, so it is
## drawn a little larger than a key to read at the same size.
const POINTER_TALL := 26.0

var _rows: VBoxContainer

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

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 5)
	scroll.add_child(_rows)
	_fill()

	column.add_child(HSeparator.new())

	_toggle(column, "Invert zoom direction",
		"Scroll away from you to zoom out instead of in.",
		ViewPrefs.invert_zoom,
		func(on: bool) -> void: ViewPrefs.invert_zoom = on)
	_presets(column)

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
		_rows.remove_child(child)
		child.queue_free()
	var density: float = Icons.density(self)
	var section: String = ""
	for binding: ControlsHint.Binding in ControlsHint.for_keyboard():
		if binding.section != section:
			section = binding.section
			_rows.add_child(_heading(section, _rows.get_child_count() > 0))
		_rows.add_child(_row(binding, density))


func _heading(text: String, after_something: bool) -> Control:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.56, 0.6, 0.68))
	# Room above every heading but the first, so a section reads as a
	# group rather than as one more row.
	if after_something:
		var spaced := MarginContainer.new()
		spaced.add_theme_constant_override("margin_top", 8)
		spaced.add_child(heading)
		return spaced
	return heading


## Keys, the pointer it shows, and what it does.
func _row(binding: ControlsHint.Binding, density: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.custom_minimum_size = Vector2(KEYS_WIDE, 0)
	keys.add_theme_constant_override("separation", 6)
	for key: String in binding.keys:
		var drawn: Control = ControlsHint.draw_key(key, KEY_TALL, 12, density)
		# The words are still there for anyone who wants them, under
		# the pointer: a picture of a mouse is quicker to read than
		# "middle-drag" and slower to be sure of.
		drawn.tooltip_text = key
		drawn.mouse_filter = Control.MOUSE_FILTER_PASS
		keys.add_child(drawn)
	row.add_child(keys)

	var pointer := CenterContainer.new()
	pointer.custom_minimum_size = Vector2(POINTER_WIDE, KEY_TALL)
	if not binding.cursor.is_empty() and Cursors.HOTSPOTS.has(binding.cursor):
		var picture: TextureRect = Icons.picture(
			Icons.CURSORS + binding.cursor + ".svg", POINTER_TALL, density)
		picture.tooltip_text = "the pointer that says so"
		picture.mouse_filter = Control.MOUSE_FILTER_PASS
		pointer.add_child(picture)
	row.add_child(pointer)

	var verb := Label.new()
	verb.text = binding.verb
	verb.add_theme_font_size_override("font_size", 12)
	verb.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	verb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	verb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(verb)
	return row


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


## The navigation preset: how the mouse looks round the model, after the
## program a person comes from (ViewPrefs). Studio's is the default.
var preset_choice: OptionButton


func _presets(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var words := Label.new()
	words.text = "Navigate like"
	words.add_theme_font_size_override("font_size", 12)
	row.add_child(words)
	preset_choice = OptionButton.new()
	preset_choice.focus_mode = Control.FOCUS_NONE
	preset_choice.add_theme_font_size_override("font_size", 12)
	for name: String in ViewPrefs.PRESETS:
		preset_choice.add_item(ViewPrefs.preset_name(name))
	preset_choice.select(ViewPrefs.PRESETS.find(ViewPrefs.preset))
	row.add_child(preset_choice)
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var say := func() -> void:
		note.text = {
			"studio": "BrickLink Studio: right-drag turns, middle-drag or shift and right-drag slides, the wheel zooms to the pointer.",
			"blender": "Blender: middle-drag turns, shift and middle-drag slides; the right button turns too.",
			"mecabricks": "Mecabricks: a left drag on empty space turns, right-drag slides, middle-drag zooms.",
		}[ViewPrefs.preset]
	say.call()
	preset_choice.item_selected.connect(func(index: int) -> void:
		ViewPrefs.use(ViewPrefs.PRESETS[index])
		ViewPrefs.keep()
		say.call()
		# The list above says what each button does, so it is wrong the
		# moment that changes.
		_fill()
		changed.emit())


var _version: Label


func _read_version() -> void:
	# Beside the build, which is not beside the page: brickworks.diy/app is
	# served from /b/<sha>/, and the page names the engine there. Resolved
	# against the page itself, this asked /version.json and found nothing.
	var where: Variant = JavaScriptBridge.eval(
		"new URL('version.json', new URL(GODOT_CONFIG.executable, location.href)).href")
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
