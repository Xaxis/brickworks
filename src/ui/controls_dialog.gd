## What everything does, and the things about it you can change: the
## wheel, the navigation preset, the floor new models start on, and
## whether the assistant is in the window at all.
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
var _done: Button

signal changed
## Settings, Assistant (AI): shown, or building by hand only.
signal assistant_chosen(on: bool)
## Settings, Interface size: chosen, for the window to be drawn again at it.
signal interface_sized
## Settings, AI: who designs, or with what, changed (AiSettings).
signal ai_changed
## Settings, AI, Design with it: the assistant's brief is wanted.
signal ai_design_wanted


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
	_title = title

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_keys = scroll

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 5)
	scroll.add_child(_rows)
	_fill()

	_rule = HSeparator.new()
	column.add_child(_rule)

	# The settings, as they were, where the window has room for them all; in
	# a window too short (a big Interface size on a laptop) they scroll,
	# with Done below (_fit_settings).
	_settings = ScrollContainer.new()
	_settings.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_settings)
	var lower := VBoxContainer.new()
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 12)
	_settings.add_child(lower)
	lower.minimum_size_changed.connect(_fit_settings)
	resized.connect(_fit_settings)
	# And when the window's scale changes, after Main has inset it again.
	get_viewport().size_changed.connect(_fit_settings, CONNECT_DEFERRED)

	_toggle(lower, "Invert zoom direction",
		"Scroll away from you to zoom out instead of in.",
		ViewPrefs.invert_zoom,
		func(on: bool) -> void: ViewPrefs.invert_zoom = on)
	_presets(lower)
	_interface(lower)
	_new_floor(lower)
	_assistant(lower)
	_ai(lower)

	# Which build this is and when it went out. The owner, looking at the
	# live site, had no way to tell when it had last been deployed; the
	# deploy writes version.json beside the build, and this reads it. A
	# downloaded desktop build says its version and the release it came
	# from (BuildInfo), so a report about it can say which one.
	_version = Label.new()
	_version.add_theme_font_size_override("font_size", 11)
	_version.modulate = Color(1, 1, 1, 0.6)
	_version.text = BuildInfo.describe()
	lower.add_child(_version)
	if OS.has_feature("web"):
		_read_version.call_deferred()

	# Settings, AI: a page of its own in the dialog, over the keys and the
	# settings, with the whole height: its form is taller than the room the
	# settings leave the keys (_fit_settings).
	_ai_page = ScrollContainer.new()
	_ai_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ai_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ai_page.visible = false
	column.add_child(_ai_page)
	# Clear of the scroll bar on the right.
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override("margin_right", 14)
	_ai_page.add_child(inset)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	inset.add_child(page)
	_back = Look.link("‹ Back to Settings", 12)
	_back.accessibility_name = "Back to Settings"
	_back.pressed.connect(func() -> void: _show_ai(false))
	page.add_child(_back)
	ai = AiSettings.new()
	ai.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ai.changed.connect(func() -> void:
		_show_designer()
		ai_changed.emit())
	# What Test found, scrolled into sight: below the fold in a short window.
	ai.tested.connect(func(said: Control) -> void: _ai_page.ensure_control_visible(said))
	ai.design_wanted.connect(func() -> void:
		visible = false
		ai_design_wanted.emit())
	page.add_child(ai)

	var done := Button.new()
	done.text = "Done"
	# Or the next press of a letter runs whatever this button is,
	# because a focused button takes the space bar and the return key.
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(func() -> void: visible = false)
	column.add_child(done)
	_done = done


## The settings under the keys: all their height, or what the dialog has
## left over its title and Done. The keys' list has what is left after them,
## as it always had (at 1100 x 700 that is a few rows): a row of keys kept
## for it pushed Assistant (AI) out of sight there (fit_check, 2026-10-24).
var _settings: ScrollContainer


func _fit_settings() -> void:
	var lower: Control = _settings.get_child(0)
	var wants: float = lower.get_combined_minimum_size().y
	var panel: StyleBox = get_theme_stylebox("panel")
	var column: Control = _settings.get_parent()
	var others: float = column.get_combined_minimum_size().y - _settings.custom_minimum_size.y
	# The height Main._inset gave it, not the height it grew to: a panel is
	# never smaller than what it holds, so asked of its size this kept the
	# room it had at 100% when the window's scale went up.
	var tall: float = offset_bottom - offset_top \
		if is_equal_approx(anchor_top, anchor_bottom) else size.y
	var room: float = tall - panel.get_minimum_size().y - others
	# In whole units, so the panel is never a fraction taller than its inset:
	# grown by one, Done moved a unit when Assistant (AI) was chosen, and a
	# check waiting for it to stand still never pressed it (fit_check).
	var fits: float = clampf(floorf(room), 0.0, wants)
	if not is_equal_approx(_settings.custom_minimum_size.y, fits):
		_settings.custom_minimum_size.y = fits


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
		on: bool, set_it: Callable) -> CheckBox:
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
	return box


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
	preset_choice.accessibility_name = "Navigate like"
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


## Settings, Interface size and Reduce motion (ShellPrefs): for eyes that
## want the words bigger, and for anyone whom motion on a screen makes ill.
var interface_choice: OptionButton
var reduce_motion: CheckBox


func _interface(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var words := Label.new()
	words.text = "Interface size"
	words.add_theme_font_size_override("font_size", 12)
	row.add_child(words)
	interface_choice = OptionButton.new()
	interface_choice.focus_mode = Control.FOCUS_NONE
	interface_choice.add_theme_font_size_override("font_size", 12)
	interface_choice.accessibility_name = "Interface size"
	for size: float in ShellPrefs.INTERFACE_SIZES:
		interface_choice.add_item("%d%%" % roundi(size * 100.0))
	interface_choice.select(_interface_index())
	row.add_child(interface_choice)
	interface_choice.item_selected.connect(func(index: int) -> void:
		ShellPrefs.put("interface_size", ShellPrefs.INTERFACE_SIZES[index])
		interface_sized.emit()
		changed.emit())

	reduce_motion = _toggle(column, "Reduce motion",
		"No build animation, no shimmer, and the view moves without gliding.",
		ShellPrefs.reduce_motion(),
		func(on: bool) -> void: ShellPrefs.put("reduce_motion", on))


func _interface_index() -> int:
	var at: float = ShellPrefs.interface_size()
	var best: int = 0
	for index: int in ShellPrefs.INTERFACE_SIZES.size():
		if absf(ShellPrefs.INTERFACE_SIZES[index] - at) \
				< absf(ShellPrefs.INTERFACE_SIZES[best] - at):
			best = index
	return best


## What a new model stands on (ModelFloor.preferred): New, and a file
## opened that does not say. Each model's own floor is View, Floor.
var new_floor: FloorPicker


func _new_floor(column: VBoxContainer) -> void:
	var words := Label.new()
	words.text = "New models start on"
	words.add_theme_font_size_override("font_size", 12)
	column.add_child(words)
	new_floor = FloorPicker.new()
	new_floor.with_part = false
	column.add_child(new_floor)
	new_floor.show_floor(ModelFloor.preferred(), false)
	new_floor.picked.connect(func(chosen: ModelFloor) -> void:
		ModelFloor.prefer(chosen)
		changed.emit())
	var note := Label.new()
	note.text = ("A baseplate, a grid on the ground like Studio's, or nothing, as a car "
		+ "stands on a table. Each model keeps its own: View, Floor.")
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)


## Settings, Assistant (AI): a plain choice of two, kept on this device
## (ShellPrefs.assistant_shown). Off, nothing of AI is anywhere in the
## window but this choice, and the connector is off with it.
var assistant_on: CheckBox
var assistant_off: CheckBox
var _assistant_note: Label


func _assistant(column: VBoxContainer) -> void:
	var words := Label.new()
	words.text = "Assistant (AI)"
	words.add_theme_font_size_override("font_size", 12)
	column.add_child(words)
	var choice := ButtonGroup.new()
	assistant_off = _choice(column, "Build by hand only", choice)
	assistant_on = _choice(column, "Show the assistant: Claude designs and changes parts when you ask",
		choice)
	_assistant_note = Label.new()
	_assistant_note.add_theme_font_size_override("font_size", 11)
	_assistant_note.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	_assistant_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_assistant_note)
	_show_assistant_choice()
	assistant_on.toggled.connect(func(on: bool) -> void:
		if on != ShellPrefs.assistant_shown():
			assistant_chosen.emit(on)
		_show_assistant_choice())


func _choice(column: VBoxContainer, text: String, group: ButtonGroup) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_group = group
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_size_override("font_size", 12)
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(box)
	return box


func _show_assistant_choice() -> void:
	var on: bool = ShellPrefs.assistant_shown()
	assistant_on.set_pressed_no_signal(on)
	assistant_off.set_pressed_no_signal(not on)
	_assistant_note.text = ("Its column is on the right, on your own Claude plan or API key; "
		+ "Brickworks bills nothing." if on
		else "No assistant, no Claude and no AI anywhere in the window. "
			+ "Claude connections are off while the assistant is off.")


## Settings, AI: who designs now, and the way to the page that changes it.
var ai: AiSettings
var ai_open: Button
var _designer_words: Label
var _ai_page: ScrollContainer
var _back: LinkButton
var _title: Label
var _keys: ScrollContainer
var _rule: HSeparator


func _ai(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_designer_words = Label.new()
	_designer_words.add_theme_font_size_override("font_size", 12)
	_designer_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_designer_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_designer_words)
	ai_open = Button.new()
	ai_open.text = "AI…"
	ai_open.accessibility_name = "AI: who designs, provider, model and key"
	ai_open.tooltip_text = "Claude, or another AI on your own API key: its provider, model and key"
	ai_open.add_theme_font_size_override("font_size", 12)
	ai_open.pressed.connect(func() -> void: _show_ai(true))
	row.add_child(ai_open)
	_show_designer()


func _show_designer() -> void:
	if _designer_words == null:
		return
	var kept: Dictionary = ProviderSettings.chosen()
	_designer_words.text = "Designs with: " + ("Claude" if ProviderSettings.who()
		== ProviderSettings.WHO_CLAUDE else "%s, %s" % [str(ProviderSettings.PRESETS[
			kept["provider"]]["name"]), str(kept["model"]) if not str(kept["model"]).is_empty()
			else "no model chosen"])


## The AI page in place of the keys and the settings, or back.
func _show_ai(on: bool) -> void:
	_ai_page.visible = on
	_keys.visible = not on
	_rule.visible = not on
	_settings.visible = not on
	_title.text = "Settings: AI" if on else "Controls"
	if on:
		ai.show_kept()
		(ai.who_key if ai.who_key.button_pressed else ai.who_claude).grab_focus.call_deferred()
	else:
		_show_designer()


## Settings opened at its AI page.
func open_ai() -> void:
	open()
	_show_ai(true)


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
	if new_floor != null:
		new_floor.show_floor(ModelFloor.preferred(), false)
	if assistant_on != null:
		_show_assistant_choice()
	if interface_choice != null:
		interface_choice.select(_interface_index())
		reduce_motion.set_pressed_no_signal(ShellPrefs.reduce_motion())
	if _ai_page != null and _ai_page.visible:
		_show_ai(false)
	_show_designer()
	visible = true


## Its controls, for the page to find (Main._tell_page).
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = {"assistant_on": assistant_on, "assistant_off": assistant_off,
		"interface_size": interface_choice, "reduce_motion": reduce_motion,
		"settings_done": _done, "ai_settings": ai_open}
	if _ai_page.visible:
		named.merge(ai.controls_by_name())
		named["ai_back"] = _back
	return named
