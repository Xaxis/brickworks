## Two dialogs in one panel, never both at once: the keys sheet (F1, Help,
## Keys and controls), which says what everything does, and Settings (",",
## Tools, Settings…), the things about it you can change: the wheel, the
## navigation preset, the floor new models start on, and whether the
## assistant is in the window at all.
##
## They were one sheet, the keys a scroller one row tall over the settings,
## and every key but the first was behind a 6 px scroll bar (APP_UX A1). The
## keys now have the panel to themselves, two columns of them as tall as the
## window, and a box that keeps only the rows that say what is typed.
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
## here. Both follow the two settings: change what the middle button does
## and its row changes picture and verb at once.
##
## The keys the menus show and that list does not name (Open, Save as, the
## steps, the cut-away) are on the sheet too, in the menus' own words and
## read from the menus' own table (Shell.key_text), so the sheet never
## leaves out a key a menu shows.
class_name ControlsDialog
extends PanelContainer

## How big Settings would like to be, before the window has its say.
const WIDE := 520.0
const TALL := 720.0
## And the keys sheet: two columns of keys, so that more than twenty show at
## once in a 1280 x 720 window, and as tall as the window.
const SHEET_WIDE := 960.0
const SHEET_TALL := 1400.0
## Narrower than this, the sheet's keys are one column.
const TWO_COLUMNS := 760.0

## Interface units: a key or a picture in a row, the column the keys are
## right-aligned in (wide enough for 1 to 7), and the pointer's column.
const KEY_TALL := 20.0
const KEYS_WIDE := 178.0
const POINTER_WIDE := 28.0
## The cursor's own picture is mostly air around a pointer, so it is
## drawn a little larger than a key to read at the same size.
const POINTER_TALL := 26.0

## The sheet's columns of keys, side by side.
var _rows: HBoxContainer
var _done: Button
## The menus' commands and their keys (Main gives it once the shell is made).
var shell: Shell

signal changed
## The keys sheet shown in place of Settings, or Settings in place of it:
## the two want different sizes (Main insets it again, at [method wide] and
## [method tall]).
signal face_changed
## Settings, Assistant (AI): shown, or building by hand only.
signal assistant_chosen(on: bool)
## Settings, Interface size: chosen, for the window to be drawn again at it.
signal interface_sized
## Settings, AI: who designs, or with what, changed (AiSettings).
signal ai_changed
## Settings, AI, Design with it: the assistant's brief is wanted.
signal ai_design_wanted
## The keys' preset chosen, or a key set (Keymap): for the account to have
## them too (KeymapSync).
signal keys_set


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
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)
	_title = title

	# The sheet's box: what is typed keeps the rows whose keys or words say
	# it, as Blender's F3 and Studio's shortcut page do. Focused as the sheet
	# opens, so the letters go here and not to the tools they are keys of.
	_find = LineEdit.new()
	_find.placeholder_text = "Find a key, or what it does"
	_find.accessibility_name = "Find a key"
	_find.clear_button_enabled = true
	_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find.add_theme_font_size_override("font_size", 12)
	_find.text_changed.connect(func(_typed: String) -> void: _fill())
	# Beside it, whose keys these are: the app's, or the program a person
	# comes from (Keymap), and a way back from keys of their own.
	_find_row = HBoxContainer.new()
	_find_row.add_theme_constant_override("separation", 10)
	_find_row.add_child(_find)
	keys_choice = _keys_like(_find_row)
	keys_reset = Look.link("Back to these keys", 12)
	keys_reset.accessibility_name = "Back to the preset's keys"
	keys_reset.tooltip_text = "Forget the keys set here, and have the preset's alone"
	keys_reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys_reset.pressed.connect(func() -> void:
		Keymap.reset()
		_say("every key is the preset's again")
		_keys_changed())
	_find_row.add_child(keys_reset)
	column.add_child(_find_row)
	# What setting a key did, or why it could not.
	_said = Label.new()
	_said.add_theme_font_size_override("font_size", 12)
	_said.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.text = HOW_TO_SET
	column.add_child(_said)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_keys = scroll

	_rows = HBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 24)
	scroll.add_child(_rows)
	_none = Label.new()
	_none.add_theme_font_size_override("font_size", 12)
	_none.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	_none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_none.visible = false
	column.add_child(_none)
	# Two columns or one, as the sheet is wide or narrow.
	scroll.resized.connect(func() -> void:
		if _keys.visible and _columns() != _rows.get_child_count():
			_fill())

	# The settings, where the window has room for them all; in a window too
	# short (a big Interface size on a laptop) they scroll, with Done below
	# (_fit_settings).
	_settings = ScrollContainer.new()
	_settings.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	# Settings, AI: a page of its own in the dialog, in place of the
	# settings, with the whole height.
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
	_show_face("settings")


## The settings: all their height, or what the dialog has left over its
## title and Done, scrolled.
var _settings: ScrollContainer


func _fit_settings() -> void:
	# Hidden, it is in no measure of the column's, and would be taken out of
	# one twice.
	if not _settings.visible:
		return
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


## The bindings, read from the one place they are written down, and those
## typed into the box: in their sections, each section whole in a column,
## the columns as near one height as whole sections let them be.
func _fill() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var density: float = Icons.density(self)
	var words: PackedStringArray = _find.text.to_lower().split(" ", false)
	var sections: Array[String] = []
	var in_section: Dictionary = {}   # section -> Array[Binding]
	for binding: ControlsHint.Binding in bindings():
		if not _says(binding, words):
			continue
		# A row with no key at all is for whoever looks for it by name, to
		# give it one: a hundred of them would bury the keys there are.
		# A favourite colour's row stays: its colour is chosen there,
		# whatever its key (none under Studio's).
		if words.is_empty() and Array(binding.keys).all(
				func(key: String) -> bool: return key == ControlsHint.NO_KEY) \
				and not str(binding.actions[0]).begins_with(ColourKeys.FAVOURITE):
			continue
		if not in_section.has(binding.section):
			sections.append(binding.section)
			in_section[binding.section] = []
		(in_section[binding.section] as Array).append(binding)
	var count: int = 0
	for section: String in sections:
		count += (in_section[section] as Array).size() + 1
	var columns: Array[VBoxContainer] = []
	for _n: int in _columns():
		var holder := VBoxContainer.new()
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_theme_constant_override("separation", 3)
		_rows.add_child(holder)
		columns.append(holder)
	var at: int = 0
	var placed: int = 0
	for section: String in sections:
		var these: Array = in_section[section]
		# On to the next column once this one holds its share.
		if placed > 0 and at < columns.size() - 1 \
				and placed + these.size() * 0.5 > count * float(at + 1) / columns.size():
			at += 1
		var holder: VBoxContainer = columns[at]
		holder.add_child(_heading(section, holder.get_child_count() > 0))
		for binding: ControlsHint.Binding in these:
			holder.add_child(_row(binding, density))
		placed += these.size() + 1
	_none.visible = sections.is_empty()
	_none.text = "No key says \"%s\". Every command, with or without a key, is in the menus." \
		% _find.text.strip_edges()


## Escape typed in the box closes the sheet, as it does anywhere else on
## it: the box would take it only to stop editing, and Main leaves a key
## typed into a box to the box.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not _setting.is_empty():
		get_viewport().set_input_as_handled()
		_take_key(key)
		return
	if visible and key != null and key.pressed and key.keycode == KEY_ESCAPE and _find.has_focus():
		visible = false
		get_viewport().set_input_as_handled()


## "Keys like": the app's own keys, or a program's a person comes from
## (Keymap.PRESETS), in [param row].
func _keys_like(row: HBoxContainer) -> OptionButton:
	var words := Label.new()
	words.text = "Keys like"
	words.add_theme_font_size_override("font_size", 12)
	row.add_child(words)
	var choice := OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	choice.accessibility_name = "Keys like"
	choice.add_theme_font_size_override("font_size", 12)
	for name: String in Keymap.PRESETS:
		choice.add_item(str(Keymap.PRESET_NAMES[name]))
	choice.select(Keymap.PRESETS.find(Keymap.preset()))
	choice.item_selected.connect(func(index: int) -> void:
		Keymap.use(Keymap.PRESETS[index])
		_say("keys like %s" % Keymap.PRESET_NAMES[Keymap.preset()])
		_keys_changed())
	row.add_child(choice)
	return choice


## The keys changed here: the sheet, both choices, the strip, the menus.
func _keys_changed() -> void:
	for choice: OptionButton in [keys_choice, keys_choice_settings]:
		if choice != null:
			choice.select(Keymap.PRESETS.find(Keymap.preset()))
	keys_reset.visible = not Keymap.own().is_empty()
	_fill()
	changed.emit()
	keys_set.emit()


func _say(text: String) -> void:
	_said.text = text[0].to_upper() + text.substr(1) + "."


## A key's chip on the sheet that a click (or Return, from the keys) sets:
## the next key pressed is [param action]'s.
func _settable(drawn: Control, action: String, key: String) -> Control:
	var chip := PanelContainer.new()
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0, 0, 0, 0)
	plain.set_corner_radius_all(5)
	plain.set_content_margin_all(1)
	var lit: StyleBoxFlat = plain.duplicate()
	lit.border_color = Color(0.45, 0.65, 1.0, 0.9)
	lit.set_border_width_all(1)
	chip.add_theme_stylebox_override("panel", plain)
	chip.add_child(drawn)
	chip.focus_mode = Control.FOCUS_ALL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.accessibility_name = "%s: %s. Set its key" % [Keymap.words(action),
		key if key != ControlsHint.NO_KEY else "no key"]
	chip.set_meta("action", action)
	chip.focus_entered.connect(func() -> void: chip.add_theme_stylebox_override("panel", lit))
	chip.focus_exited.connect(func() -> void:
		if _setting.get("chip") != chip:
			chip.add_theme_stylebox_override("panel", plain))
	chip.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		var key_press := event as InputEventKey
		if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) \
				or (key_press != null and key_press.pressed and not key_press.echo
					and key_press.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]):
			chip.accept_event()
			_start_setting(action, chip, lit))
	return chip


func _start_setting(action: String, chip: PanelContainer, lit: StyleBox) -> void:
	_setting = {"action": action, "chip": chip}
	chip.add_theme_stylebox_override("panel", lit)
	for child: Node in chip.get_children():
		chip.remove_child(child)
		child.queue_free()
	chip.add_child(ControlsHint.cap("press a key", KEY_TALL, 12))
	_say("press the key for %s; Esc keeps %s" % [Keymap.words(action),
		Keymap.listed(action) if Keymap.key_of(action) != 0 else "it with none"])


## The key pressed while one is being set: that action's, unless it is
## another's or not to be set, which is said and nothing changes.
func _take_key(key: InputEventKey) -> void:
	if key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT, KEY_CAPSLOCK]:
		return
	var action: String = _setting["action"]
	_setting = {}
	if key.keycode == KEY_ESCAPE:
		_say("%s kept" % Keymap.words(action))
		_fill()
		return
	var accel: int = 0 if key.keycode == KEY_BACKSPACE else Keymap.accel_of(key)
	var trouble: String = Keymap.bind(action, accel)
	if not trouble.is_empty():
		var kept: String = Keymap.listed(action)
		_say("%s keeps %s: %s" % [Keymap.words(action),
			kept if not kept.is_empty() else "no key", trouble])
		_fill()
		return
	_say("%s is now %s" % [Keymap.words(action),
		Keymap.listed_key(accel) if accel != 0 else "with no key"])
	_keys_changed()


## Two columns where the sheet is wide enough for them, else one.
func _columns() -> int:
	return 2 if size.x >= TWO_COLUMNS else 1


## Whether [param binding]'s keys, words or section say every one of
## [param words].
static func _says(binding: ControlsHint.Binding, words: PackedStringArray) -> bool:
	var said: String = (" ".join(binding.keys) + " " + binding.verb + " " + binding.section).to_lower()
	for word: String in words:
		if not said.contains(word):
			return false
	return true


## The list's own sections, for the keys the menus show that it does not
## name, by the menu they are in.
const MENU_SECTIONS: Dictionary = {"File": "Panels", "Edit": "Building", "View": "The view",
	"Build": "Building", "Make": "Building", "Tools": "Building", "Help": "Panels"}

## The colour keys' section (ColourKeys), last.
const COLOURS := "Colours: click a favourite's colour to change it"


## Every row the sheet has: the controls list (ControlsHint.for_keyboard),
## then each key a menu shows that the list does not name, in the menu's
## words, in the list's section for that menu.
func bindings() -> Array[ControlsHint.Binding]:
	var listed: Array[ControlsHint.Binding] = ControlsHint.for_keyboard()
	if shell == null:
		return listed
	var named: Dictionary = {}
	for binding: ControlsHint.Binding in listed:
		for n: int in binding.keys.size():
			named[binding.actions[n] if not binding.actions[n].is_empty()
				else binding.keys[n].to_lower()] = true
	var extra: Dictionary = {}   # section -> Array[Binding]
	for menu: Array in Shell.MENUS:
		for name: String in _commands_in(menu[1]):
			var command: Shell.Command = shell.command(name)
			if command == null or named.has(name):
				continue
			if not shell.assistant_shown and name in Shell.ASSISTANT_COMMANDS:
				continue
			named[name] = true
			var words: String = command.words.trim_suffix("…")
			var binding := ControlsHint.keyed([name], words[0].to_lower() + words.substr(1))
			binding.section = MENU_SECTIONS.get(menu[0], "Panels")
			if not extra.has(binding.section):
				extra[binding.section] = []
			(extra[binding.section] as Array).append(binding)
	# Each after the list's own rows of its section.
	var out: Array[ControlsHint.Binding] = []
	var section: String = ""
	for binding: ControlsHint.Binding in listed:
		if binding.section != section and extra.has(section):
			out.append_array(extra[section])
			extra.erase(section)
		section = binding.section
		out.append(binding)
	for rest: String in extra:
		out.append_array(extra[rest])
	for action: String in ColourKeys.ACTIONS:
		var binding := ControlsHint.keyed([action], colour_words(action))
		binding.section = COLOURS
		out.append(binding)
	return out


## What a colour key's row says: the colour it paints, and whose it is.
## "paint Black, favourite 1"; "paint Red, the model's most used (52)".
func colour_words(action: String) -> String:
	var n: int = ColourKeys.place(action) + 1
	if action.begins_with(ColourKeys.FAVOURITE):
		return "paint %s, favourite %d" % [_colour_name(ColourKeys.favourites()[n - 1]), n]
	if shell == null or shell.world == null:
		return ColourKeys.words(action)
	var used: Array = ColourKeys.most_used(shell.world, shell.store.scenery)
	if n > used.size():
		return "the model's %s colour: it has %d" % [ColourKeys.nth(n), used.size()]
	var whose: String = "the model's most used" if n == 1 else "its %s" % ColourKeys.nth(n)
	return "paint %s, %s (%d)" % [_colour_name(int(used[n - 1][0])), whose, int(used[n - 1][1])]


func _colour_name(code: int) -> String:
	if shell == null or shell.library == null or not shell.library.colors.has(code):
		return "colour %d" % code
	return shell.library.color(code).name


## The commands of a menu, its submenus' too.
static func _commands_in(items: Array) -> Array[String]:
	var out: Array[String] = []
	for item: String in items:
		if item == "-":
			continue
		if item.begins_with(">"):
			out.append_array(_commands_in(Shell.SUBMENUS.get(item.substr(1), [])))
		else:
			out.append(item)
	return out


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
	for n: int in binding.keys.size():
		var key: String = binding.keys[n]
		var action: String = binding.actions[n]
		var drawn: Control = ControlsHint.draw_key(key, KEY_TALL, 12, density)
		if not action.is_empty() and Keymap.settable(action):
			drawn = _settable(drawn, action, key)
		# The words are still there for anyone who wants them, under
		# the pointer: a picture of a mouse is quicker to read than
		# "middle-drag" and slower to be sure of.
		drawn.tooltip_text = key
		if drawn.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			drawn.mouse_filter = Control.MOUSE_FILTER_PASS
		keys.add_child(drawn)
	row.add_child(keys)

	var pointer := CenterContainer.new()
	pointer.custom_minimum_size = Vector2(POINTER_WIDE, KEY_TALL)
	var colour_key: String = binding.actions[0] if binding.actions.size() > 0 else ""
	if ColourKeys.owns(colour_key):
		var swatch: Control = _colour_swatch(colour_key)
		if swatch != null:
			pointer.add_child(swatch)
	elif not binding.cursor.is_empty() and Cursors.HOTSPOTS.has(binding.cursor):
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


## A colour key's colour, in the pointer's column: a favourite's a button
## that opens the colours to choose another from ([method _choose_colour]),
## the model's most used only shown. None for a place the model has no
## colour in.
func _colour_swatch(action: String) -> Control:
	if shell == null or shell.library == null:
		return null
	var code: int = ColourKeys.colour_of(action, shell.world, shell.store.scenery)
	if code < 0 or not shell.library.colors.has(code):
		return null
	var swatch := PartsBin.Swatch.new(shell.library.color(code))
	swatch.toggle_mode = false
	# Edged, or Black is lost on the sheet's own near-black.
	var edged := PanelContainer.new()
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0, 0, 0, 0)
	edge.border_color = Color(1, 1, 1, 0.35)
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(2)
	edged.add_theme_stylebox_override("panel", edge)
	edged.mouse_filter = Control.MOUSE_FILTER_PASS
	edged.add_child(swatch)
	var n: int = ColourKeys.place(action) + 1
	if not action.begins_with(ColourKeys.FAVOURITE):
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.disabled = true
		swatch.tooltip_text = "%s, the model's %s most used" % [_colour_name(code), ColourKeys.nth(n)]
		return edged
	swatch.name = "favourite_%d" % n
	swatch.tooltip_text = "%s: click to choose favourite %d's colour" % [_colour_name(code), n]
	swatch.accessibility_name = "Favourite %d, %s. Choose its colour" % [n, _colour_name(code)]
	swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	swatch.pressed.connect(func() -> void: _choose_colour(n - 1, swatch))
	return edged


## The colours made now (PartLibrary.is_current), as the palette orders
## them, for favourite [param n] (0 to 9): a click on one makes it that.
var _chooser: PopupPanel


func _choose_colour(n: int, beside: Control) -> void:
	if _chooser != null:
		_chooser.queue_free()
	_chooser = PopupPanel.new()
	_chooser.name = "favourite_chooser"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_chooser.add_child(column)
	var title := Label.new()
	title.text = "Favourite %d" % (n + 1)
	title.add_theme_font_size_override("font_size", 12)
	column.add_child(title)
	var flow := FlowContainer.new()
	flow.custom_minimum_size = Vector2(PartsBin.Swatch.SIZE * 16 + 2 * 15, 0)
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	column.add_child(flow)
	var chosen: int = ColourKeys.favourites()[n]
	var offered: Array[PartLibrary.BrickColor] = []
	for code: int in shell.library.colors:
		if code in ColourKeys.NOT_A_COLOUR or not (shell.library.is_current(code) or code == chosen):
			continue
		offered.append(shell.library.color(code))
	offered.sort_custom(PartsBin._in_palette_order)
	for color: PartLibrary.BrickColor in offered:
		var swatch := PartsBin.Swatch.new(color)
		swatch.set_pressed_no_signal(color.code == chosen)
		swatch.tooltip_text = color.name
		var code: int = color.code
		swatch.pressed.connect(func() -> void:
			_chooser.hide()
			ColourKeys.set_favourite(n, code)
			_say("favourite %d is now %s" % [n + 1, color.name])
			_keys_changed())
		flow.add_child(swatch)
	add_child(_chooser)
	var under: Vector2 = beside.get_screen_position() + Vector2(0.0, beside.size.y + 4.0)
	_chooser.popup(Rect2i(Vector2i(under), Vector2i.ZERO))
	# Its colours wrap once it has its width: then kept inside the window,
	# over the swatch where the window ends under it.
	await get_tree().process_frame
	if _chooser == null or not _chooser.visible:
		return
	_chooser.reset_size()
	var room: Vector2 = get_viewport().get_visible_rect().size
	var tall: Vector2 = Vector2(_chooser.size)
	var at: Vector2 = under
	at.x = clampf(at.x, 4.0, maxf(room.x - tall.x - 4.0, 4.0))
	if at.y + tall.y > room.y - 4.0:
		at.y = maxf(beside.get_screen_position().y - tall.y - 4.0, 4.0)
	_chooser.position = Vector2i(at)


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
	# And the keys, after the same programs (Keymap): the keys sheet has
	# the same choice, and sets single keys.
	var keys_row := HBoxContainer.new()
	keys_row.add_theme_constant_override("separation", 8)
	column.add_child(keys_row)
	keys_choice_settings = _keys_like(keys_row)


## Settings, Interface size and Reduce motion (ShellPrefs): for eyes that
## want the words bigger, and for anyone whom motion on a screen makes ill.
var interface_choice: OptionButton
var reduce_motion: CheckBox
## Settings, Language (Language): English, German, French or Spanish, each
## named in its own words, on Interface size's line.
var language_choice: OptionButton


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
	# On the same line: a line of its own cost the settings their fit at
	# 100% (a11y_size), as the AI page's link did.
	var gap := Control.new()
	gap.custom_minimum_size.x = 16.0
	row.add_child(gap)
	var language := Label.new()
	language.text = "Language"
	language.add_theme_font_size_override("font_size", 12)
	row.add_child(language)
	language_choice = OptionButton.new()
	language_choice.focus_mode = Control.FOCUS_NONE
	language_choice.add_theme_font_size_override("font_size", 12)
	language_choice.accessibility_name = "Language"
	# Each in its own words whatever the language in use, as a person
	# looking for theirs reads it.
	language_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for choice: Array in Language.CHOICES:
		language_choice.add_item(str(choice[1]))
	language_choice.select(Language.codes().find(Language.current()))
	row.add_child(language_choice)
	language_choice.item_selected.connect(func(index: int) -> void:
		Language.choose(Language.codes()[index])
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
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Who designs, and the way to the AI page, on the heading's own line:
	# a row of its own cost the settings their fit at 100% (a11y_size).
	var heading := HBoxContainer.new()
	heading.add_child(words)
	_ai(heading)
	column.add_child(heading)
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


## Settings, AI: the page, and the link to it, which says who designs now.
var ai: AiSettings
var ai_open: LinkButton
var _ai_page: ScrollContainer
var _back: LinkButton
var _title: Label
## The keys sheet: its box, its list, and what it says when nothing is found.
var _keys: ScrollContainer
var _find: LineEdit
## The box's row, with whose keys these are beside it, and what setting a
## key did.
var _find_row: HBoxContainer
var _said: Label
## The keys' preset (Keymap) on the sheet, and the way back to it alone.
var keys_choice: OptionButton
var keys_reset: LinkButton
## Settings' own, beside the navigation preset: the same choice.
var keys_choice_settings: OptionButton
## The action whose key is being set, and its chip: empty when none is.
var _setting: Dictionary = {}

const HOW_TO_SET := "Click a key to set your own; Esc keeps it, Backspace leaves it with none."
var _none: Label


func _ai(row: HBoxContainer) -> void:
	ai_open = Look.link("", 12)
	ai_open.accessibility_name = "AI: who designs, provider, model and key"
	ai_open.tooltip_text = "Claude, or another AI on your own API key: its provider, model and key"
	ai_open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ai_open.pressed.connect(func() -> void: _show_ai(true))
	row.add_child(ai_open)
	_show_designer()


## The link's words: AI, and who designs ("AI: Claude…", "AI: gpt-6.1-sol…").
func _show_designer() -> void:
	if ai_open == null:
		return
	var kept: Dictionary = ProviderSettings.chosen()
	ai_open.text = "AI: %s…" % ("Claude" if ProviderSettings.who() == ProviderSettings.WHO_CLAUDE
		else str(kept["model"]) if not str(kept["model"]).is_empty() else "no model chosen")


## The AI page in place of the settings, or back.
func _show_ai(on: bool) -> void:
	_ai_page.visible = on
	_settings.visible = not on
	_title.text = "Settings: AI" if on else "Settings"
	if on:
		ai.show_kept()
		(ai.who_key if ai.who_key.button_pressed else ai.who_claude).grab_focus.call_deferred()
	else:
		_show_designer()
		_fit_settings()


## Settings opened at its AI page.
func open_ai() -> void:
	open()
	_show_ai(true)


## "keys" (the sheet) or "settings".
var _face: String = "settings"


func _show_face(face: String) -> void:
	var keys: bool = face == "keys"
	_find_row.visible = keys
	_said.visible = keys
	_setting = {}
	_keys.visible = keys
	_none.visible = false
	_settings.visible = not keys
	_ai_page.visible = false
	_title.text = "Keys and controls" if keys else "Settings"
	if face == _face:
		return
	_face = face
	face_changed.emit()


## How wide and how tall the face showing would like to be (Main._inset).
func wide() -> float:
	return SHEET_WIDE if _face == "keys" else WIDE


func tall() -> float:
	return SHEET_TALL if _face == "keys" else TALL


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


## Settings.
func open() -> void:
	if keys_choice_settings != null:
		keys_choice_settings.select(Keymap.PRESETS.find(Keymap.preset()))
	if new_floor != null:
		new_floor.show_floor(ModelFloor.preferred(), false)
	if assistant_on != null:
		_show_assistant_choice()
	if interface_choice != null:
		interface_choice.select(_interface_index())
		reduce_motion.set_pressed_no_signal(ShellPrefs.reduce_motion())
		language_choice.select(Language.codes().find(Language.current()))
	_show_face("settings")
	_show_designer()
	_fill()
	visible = true
	_fit_settings.call_deferred()


## The keys sheet, its box empty and the letters typed going into it. Not
## on a touchscreen, where the box would bring up a keyboard over the keys.
func open_keys() -> void:
	_find.text = ""
	_show_face("keys")
	_find.visible = not TouchTools.wanted()
	keys_choice.select(Keymap.PRESETS.find(Keymap.preset()))
	keys_reset.visible = not Keymap.own().is_empty()
	_said.text = HOW_TO_SET
	_fill()
	visible = true
	if _find.visible:
		_find.grab_focus.call_deferred()


## Its controls, for the page to find (Main._tell_page).
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	if _face == "keys":
		var named: Dictionary = {"keys_find": _find, "settings_done": _done,
			"keys_like": keys_choice, "keys_reset": keys_reset}
		# Each key's chip by its action, for a flow to set one by clicking it.
		for chip: Node in _rows.find_children("*", "PanelContainer", true, false):
			if chip.has_meta("action") and (chip as Control).is_visible_in_tree():
				named["key_" + str(chip.get_meta("action"))] = chip
		# Each favourite's colour, and the colours to choose from while open,
		# by code: "colour_378".
		for swatch: Node in _rows.find_children("favourite_*", "Button", true, false):
			if (swatch as Control).is_visible_in_tree():
				named[str(swatch.name)] = swatch
		if _chooser != null and _chooser.visible:
			for swatch: Node in _chooser.find_children("*", "Button", true, false):
				named["colour_%d" % int(swatch.get_meta("code"))] = swatch
		return named
	var named: Dictionary = {"assistant_on": assistant_on, "assistant_off": assistant_off,
		"interface_size": interface_choice, "reduce_motion": reduce_motion,
		"language": language_choice, "settings_done": _done, "ai_settings": ai_open}
	if _ai_page.visible:
		named.merge(ai.controls_by_name())
		named["ai_back"] = _back
	return named
