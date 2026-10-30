## Find a command by typing: Ctrl+/ (Ctrl+Shift+P on the desktop too), or
## the app's menu, Find a command…, opens a box over the model. What is
## typed filters every command by the words of its name and of the menu it
## is in; each row says its key and where it lives, and Enter runs it as
## its menu row would (Shell.run). A command that cannot be used now is
## shown greyed with what it waits for, never left out. The ones run from
## here last come first. A part's number or name lists the part too, under
## the commands: "3001" and Return take a brick into the hand.
##
## Figma's Actions, Blender's F3 and Onshape's tool search do this. Here 71
## of the shell's 122 commands had no key, spread over six menus of up to
## 39 rows (appux371 A9).
class_name CommandPalette
extends PopupPanel

var shell: Shell
## How a chosen command is run: Shell.run, unless a probe stands in.
var run_command: Callable

## The box's width, and how many rows show before the list scrolls.
const WIDE := 600.0
const ROWS_SHOWN := 10
## The commands run from here that are kept, the latest first.
const RECENT_KEPT := 8
## Between a menu and its submenu, as the docs write it.
const INTO := " › "
## A row that is a part, not a command: "part:3001". At most this many,
## once three letters are typed.
const PART := "part:"
const PARTS_SHOWN := 3

var _field: LineEdit
var _list: Tree
var _foot: Label
## The commands in the rows, top to bottom, and which row is lit.
var _names: Array[String] = []
var _lit: int = -1
## Where each command lives in the menus ("Edit › Select by"), and every
## command in the order the menus have them: made once, the menus being
## fixed.
var _where: Dictionary = {}
var _order: Array[String] = []
## The commands run from here, the latest first.
var recent: Array[String] = []

static var _apart: RegEx


func _ready() -> void:
	name = "command_palette"
	transient = true
	var face := StyleBoxFlat.new()
	face.bg_color = Look.FACE
	face.border_color = Look.EDGE
	face.set_border_width_all(1)
	face.set_corner_radius_all(8)
	face.set_content_margin_all(10)
	add_theme_stylebox_override("panel", face)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_field = LineEdit.new()
	_field.name = "palette_field"
	_field.placeholder_text = "Find a command…"
	_field.accessibility_name = "Find a command"
	_field.clear_button_enabled = true
	_field.add_theme_font_size_override("font_size", 15)
	_field.text_changed.connect(func(_text: String) -> void: _fill())
	# Return on a greyed row leaves the box up with the words still being
	# typed: let go of, the field ended its typing and the box went with it
	# in a browser.
	_field.keep_editing_on_text_submit = true
	_field.text_submitted.connect(func(_text: String) -> void: choose(_lit))
	_field.gui_input.connect(_on_key)
	column.add_child(_field)
	_list = Tree.new()
	_list.name = "palette_rows"
	_list.accessibility_name = "Commands"
	_list.columns = 3
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	# The keys stay in the field; a click on a row runs it.
	_list.focus_mode = Control.FOCUS_NONE
	_list.scroll_horizontal_enabled = false
	_list.set_column_expand_ratio(0, 5)
	_list.set_column_expand_ratio(1, 3)
	_list.set_column_expand(2, false)
	_list.set_column_custom_minimum_width(2, 96)
	_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["selected", "selected_focus"]:
		var lit := StyleBoxFlat.new()
		lit.bg_color = Look.CHOSEN
		lit.set_corner_radius_all(4)
		_list.add_theme_stylebox_override(state, lit)
	_list.add_theme_constant_override("v_separation", 8)
	_list.add_theme_constant_override("inner_item_margin_left", 8)
	_list.add_theme_constant_override("inner_item_margin_right", 8)
	_list.add_theme_constant_override("draw_guides", 0)
	_list.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_list.add_theme_color_override("font_selected_color", Color.WHITE)
	_list.add_theme_font_size_override("font_size", 14)
	_list.item_mouse_selected.connect(func(_at: Vector2, button: int) -> void:
		if button == MOUSE_BUTTON_LEFT:
			var item: TreeItem = _list.get_selected()
			if item != null:
				choose(item.get_index()))
	column.add_child(_list)
	_foot = Label.new()
	_foot.name = "palette_foot"
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.add_theme_font_size_override("font_size", 13)
	_foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	column.add_child(_foot)
	if not run_command.is_valid():
		run_command = shell.run
	for named: Variant in ShellPrefs.value("palette_recent"):
		if shell.command(str(named)) != null:
			recent.append(str(named))
	_index()


## Open over the model, empty, the keys in the box.
func open() -> void:
	var room: Rect2 = get_parent().get_viewport().get_visible_rect()
	var over: Rect2 = shell.model_area.get_global_rect() if shell.model_area != null else room
	var wide: float = minf(WIDE, room.size.x - 24.0)
	(_field.get_parent() as Control).custom_minimum_size.x = wide - 20.0
	var left: float = clampf(over.get_center().x - wide / 2.0, 12.0, room.size.x - wide - 12.0)
	_field.text = ""
	_fill()
	popup(Rect2i(Vector2i(roundi(left), roundi(over.position.y + 24.0)), Vector2i(roundi(wide), 0)))
	_field.grab_focus()


## Run the command in row [param row], as its menu row does: one that
## cannot be used now says why there and keeps the box open.
func choose(row: int) -> void:
	if row < 0 or row >= _names.size():
		return
	var chosen: String = _names[row]
	_light(row)
	if chosen.begins_with(PART):
		hide()
		# As a click on its tile in the parts bin (Main._on_part_chosen).
		(shell.app.get("_bin") as PartsBin).part_chosen.emit(chosen.trim_prefix(PART))
		return
	if not shell.can(chosen):
		_foot.text = "%s: %s." % [_words(chosen), shell.why_not(chosen)]
		return
	recent.erase(chosen)
	recent.push_front(chosen)
	recent.resize(mini(recent.size(), RECENT_KEPT))
	ShellPrefs.put("palette_recent", recent.duplicate())
	hide()
	run_command.call(chosen)


## The commands for [param asked], best first: every word typed must begin
## a word of the command's name or of its menu's, or be inside its name, or
## at three letters begin a word of its tooltip. A name that begins with
## what was typed, and one that can be used now, go first; then the recent
## ones, then the menus' order.
func matches(asked: String) -> Array[String]:
	var typed: PackedStringArray = words_of(asked)
	var scored: Array = []
	for at: int in _order.size():
		var named: String = _order[at]
		if shell._shown([named]).is_empty():
			continue
		var was: int = recent.find(named)
		var lately: int = RECENT_KEPT - was if was >= 0 else 0
		# Nothing typed: the recent ones first, greyed or not.
		var score: int = 100 + lately if typed.is_empty() else _score(typed, named)
		if score <= 0:
			continue
		scored.append([score, shell.can(named), lately, -at, named])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		for n: int in 4:
			if a[n] != b[n]:
				return a[n] > b[n]
		return false)
	var out: Array[String] = []
	for row: Array in scored:
		out.append(str(row[4]))
	return out


## Where a command lives in the menus: "Edit › Select by", "Brickworks",
## "Menu on a part", or "" for one only a key reaches.
func where(named: String) -> String:
	return str(_where.get(named, ""))


## The words a command's row shows, a setting's state with them.
func row_words(named: String) -> String:
	var words: String = _words(named)
	return words + "  · on" if shell.ticked(named) == 1 else words


## The parts [param asked] names, by number or name, best first: none
## until three letters are typed, or while the model is not to be changed.
func parts_for(asked: String) -> Array[String]:
	var out: Array[String] = []
	if asked.strip_edges().length() < 3 or shell.read_only or shell.store.laying \
			or not shell.library.search_ready():
		return out
	for info: PartLibrary.PartInfo in shell.library.search(asked, PARTS_SHOWN * 4, true):
		if info.reachable and out.size() < PARTS_SHOWN:
			out.append(PART + info.id)
	return out


## What a browser check reads (Main's page state): whether it is open, what
## is typed, the first rows, and the lit one and why it is greyed, if it is.
func page_state() -> Dictionary:
	var lit: String = _names[_lit] if _lit >= 0 and _lit < _names.size() else ""
	return {"open": visible, "typed": _field.text if _field != null else "",
		"rows": _names.slice(0, 12), "lit": lit,
		"why": shell.why_not(lit) if not lit.is_empty() and not lit.begins_with(PART) else ""}


## Its controls by name, for a browser check to press them as a person does.
func controls_by_name() -> Dictionary:
	return {"palette_field": _field} if visible else {}


static func words_of(text: String) -> PackedStringArray:
	if _apart == null:
		_apart = RegEx.create_from_string("[^a-z0-9]+")
	return _apart.sub(text.to_lower(), " ", true).split(" ", false)


func _score(typed: PackedStringArray, named: String) -> int:
	var command: Shell.Command = shell.command(named)
	var own: PackedStringArray = words_of(command.words)
	var menu: PackedStringArray = words_of(where(named))
	var tip: PackedStringArray = words_of(command.tip)
	var squeezed: String = "".join(own)
	var total: int = 0
	for word: String in typed:
		var best: int = 0
		for n: int in own.size():
			if own[n].begins_with(word):
				best = maxi(best, (4 if n == 0 else 3) + (1 if own[n] == word else 0))
		if best == 0:
			for of_menu: String in menu:
				if of_menu.begins_with(word):
					best = 2
		# "xray" in X-ray, "lock" in Unlock everything.
		if best == 0 and squeezed.contains(word):
			best = 1
		if best == 0 and word.length() >= 3:
			for of_tip: String in tip:
				if of_tip.begins_with(word):
					best = 1
		if best == 0:
			return 0
		total += best
	if squeezed.begins_with("".join(typed)):
		total += 3
	return total


func _fill() -> void:
	_names = matches(_field.text) + parts_for(_field.text)
	_list.clear()
	var top: TreeItem = _list.create_item()
	for named: String in _names:
		var item: TreeItem = _list.create_item(top)
		if named.begins_with(PART):
			_part_row(item, named.trim_prefix(PART))
			continue
		var why: String = shell.why_not(named)
		item.set_text(0, row_words(named))
		item.set_text(1, why if not why.is_empty() else where(named))
		item.set_text(2, shell.key_words(named))
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
		for column: int in 3:
			item.set_text_overrun_behavior(column, TextServer.OVERRUN_TRIM_ELLIPSIS)
		item.set_custom_font_size(1, 12)
		item.set_custom_font_size(2, 12)
		item.set_tooltip_text(0, shell.command(named).tip)
		if why.is_empty():
			item.set_custom_color(1, Color(1, 1, 1, 0.62))
			item.set_custom_color(2, Color(1, 1, 1, 0.72))
		else:
			# Greyed, and what it waits for in the colour of a note.
			item.set_custom_color(0, Color(1, 1, 1, 0.48))
			item.set_custom_color(1, Color(1.0, 0.84, 0.55, 0.9))
			item.set_custom_color(2, Color(1, 1, 1, 0.42))
	# As tall as its rows, up to ROWS_SHOWN; the list scrolls past those.
	var rows: int = clampi(_names.size(), 1, ROWS_SHOWN)
	_list.custom_minimum_size.y = _row_height(top) * rows + _list.get_theme_constant("v_separation") + 2.0
	reset_size()
	_lit = -1
	_light(0)
	if _names.is_empty():
		_foot.text = "No command or part has the words “%s”." % _field.text.strip_edges()


func _part_row(item: TreeItem, part_id: String) -> void:
	var info: PartLibrary.PartInfo = shell.library.parts.get(part_id)
	item.set_text(0, Inventory._tidy(info.name) if info != null else part_id)
	item.set_text(1, "Part %s" % part_id)
	item.set_custom_font_size(1, 12)
	item.set_custom_color(1, Color(1, 1, 1, 0.62))
	for column: int in 2:
		item.set_text_overrun_behavior(column, TextServer.OVERRUN_TRIM_ELLIPSIS)


func _light(row: int) -> void:
	if _names.is_empty():
		_lit = -1
		return
	_lit = clampi(row, 0, _names.size() - 1)
	var item: TreeItem = _list.get_root().get_child(_lit)
	item.select(0)
	_list.scroll_to_item(item)
	var named: String = _names[_lit]
	if named.begins_with(PART):
		_foot.text = "Takes it into hand, to put down with a click."
		return
	var said: String = shell.command(named).tip
	var why: String = shell.why_not(named)
	if not why.is_empty():
		said = "%s.%s" % [why, (" " + said) if not said.is_empty() else ""]
	_foot.text = said if not said.is_empty() else where(named)


func _on_key(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	var by: int = {KEY_DOWN: 1, KEY_UP: -1, KEY_PAGEDOWN: ROWS_SHOWN,
		KEY_PAGEUP: -ROWS_SHOWN}.get(key.keycode, 0)
	if by != 0:
		_light(_lit + by)
		_field.accept_event()


func _words(named: String) -> String:
	var command: Shell.Command = shell.command(named)
	return command.words if command != null else named


## A row's height, its spacing in, as the list lays its first out.
func _row_height(top: TreeItem) -> float:
	if top.get_child_count() > 0:
		return _list.get_item_area_rect(top.get_child(0)).size.y
	return _list.get_theme_font("font").get_height(14) + 2.0 * _list.get_theme_constant("v_separation")


## Every command's home in the menus, the first that lists it: the menu
## bar's, then the app's menu, then the menu on a part.
func _index() -> void:
	for menu: Array in Shell.MENUS:
		_walk(menu[1], str(menu[0]))
	_walk(Shell.APP_MENU, ModelBar.NAME)
	_walk(Shell.ON_A_PART, "Menu on a part")
	var rest: Array = shell.get("_commands").keys()
	for named: String in rest:
		if not _order.has(named):
			_order.append(named)
	_order.erase("palette")


func _walk(items: Array, path: String) -> void:
	for item: String in items:
		if item == "-":
			continue
		if item.begins_with(">"):
			var kind: String = item.substr(1)
			if Shell.SUBMENUS.has(kind):
				_walk(Shell.SUBMENUS[kind], path + INTO + str(Shell.SUBMENU_WORDS[kind]))
			continue
		if not _where.has(item):
			_where[item] = path
			_order.append(item)
