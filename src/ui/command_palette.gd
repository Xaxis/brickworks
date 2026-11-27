## Find a command by typing: Ctrl+/ (Ctrl+Shift+P on the desktop too), or
## the app's menu, Find a command…, opens a box over the model. What is
## typed filters every command by the words of its name and of the menu it
## is in, in English and in the interface's language (Language: "speichern"
## finds Save); each row says its key and where it lives, and Enter runs it as
## its menu row would (Shell.run). A command that cannot be used now is
## shown greyed with what it waits for, never left out. The ones run from
## here last come first. A part's number or name lists the part too, under
## the commands: "3001" and Return take a brick into the hand.
##
## Figma's Actions, Blender's F3 and Onshape's tool search do this. Here 71
## of the shell's 122 commands had no key, spread over six menus of up to
## 39 rows (appux371 A9).
##
## It opens where it is meant every time, wholly in the window under the
## menu bar, the toolbar and the model's banners, and stays there as rows
## come and go. Its first open in a browser stood at the window's top over
## the menu bar, as tall as the window (palfix, 2026-11-27): the foot's
## words wrapped at the width of a label never laid out, a letter to a
## line, and the engine moves a popup taller than the room under it up to
## the window's edge. Nothing in it now is taller for being narrow: the
## foot is two lines whatever it says, and the list as tall as the rows the
## room under the box holds. One row is lit, the one the keys or the
## pointer are on (VS Code's, Raycast's); a part is listed only where its
## name or number has the words typed, never a keyword alone ("mirror"
## listed a spoon); a name is cut only when the columns beside it have no
## room left to give.
class_name CommandPalette
extends PopupPanel

var shell: Shell
## How a chosen command is run: Shell.run, unless a probe stands in.
var run_command: Callable

## The box's width, and how many rows show at most before the list scrolls.
const WIDE := 600.0
const ROWS_SHOWN := 10
## Between the box and the window's edges, and under the top of the model's
## part of the window.
const MARGIN := 12.0
const UNDER := 24.0
## The words' sizes: a row's name, and what is beside it (its menu, why it
## is greyed, its key), at the desktop's size; a phone's sizing grows both.
const NAME_SIZE := 14
const BESIDE_SIZE := 12
## The foot says the lit row's tip in at most this many lines, always as
## tall as that: a foot one line for one row and two for the next moved
## the box's edge as the keys went down the rows.
const FOOT_LINES := 2
## The middle column (a row's menu, or why it is greyed) keeps at least this
## share of a row when the names want more than the key leaves them.
const MIDDLE_LEAST := 0.28
## The commands run from here that are kept, the latest first.
const RECENT_KEPT := 8
## Between a menu and its submenu, as the docs write it (Keymap's).
const INTO := Keymap.INTO
## A row that is a part, not a command: "part:3001". At most this many,
## once three letters are typed, of the best this many the part search
## ranks.
const PART := "part:"
const PARTS_SHOWN := 3
const PARTS_LOOKED_AT := 60

var _field: LineEdit
var _list: Tree
var _foot: Label
## The commands in the rows, top to bottom, and which row is lit.
var _names: Array[String] = []
var _lit: int = -1
## Where the box opens, its top left in the window, and how wide: kept
## while it is open, so rows coming and going never move it.
var _at := Vector2i.ZERO
var _wide: float = WIDE
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
	# The name takes what the menu and the key leave, and those are as wide
	# as their words (_fit_columns).
	for beside: int in [1, 2]:
		_list.set_column_expand(beside, false)
		_list.set_column_clip_content(beside, true)
	_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		var lit := StyleBoxFlat.new()
		lit.bg_color = Look.CHOSEN
		lit.set_corner_radius_all(4)
		_list.add_theme_stylebox_override(state, lit)
	# One lit row: the pointer lights the row it is on (_on_list_input)
	# rather than a grey one of its own beside the blue (the web's first
	# picture, 11-27), and no box round the row the keys are on.
	for state: String in ["hovered", "hovered_dimmed", "cursor", "cursor_unfocused"]:
		_list.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# Every row as tall as the next: what is beside a name is smaller than
	# it, and the spacing is the row's (the engine puts it above and below).
	_list.add_theme_constant_override("v_separation", 7)
	# A row's words in a tooltip sat over the rows under it: the foot says
	# the lit row's, and a part's whole name.
	_list.auto_tooltip = false
	_list.add_theme_constant_override("inner_item_margin_left", 8)
	_list.add_theme_constant_override("inner_item_margin_right", 8)
	_list.add_theme_constant_override("draw_guides", 0)
	_list.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_list.add_theme_color_override("font_selected_color", Color.WHITE)
	_list.add_theme_color_override("font_hovered_color", Color(1, 1, 1, 0.92))
	_list.add_theme_color_override("font_hovered_selected_color", Color.WHITE)
	_list.add_theme_font_size_override("font_size", NAME_SIZE)
	_list.item_mouse_selected.connect(func(_point: Vector2, button: int) -> void:
		if button == MOUSE_BUTTON_LEFT:
			var item: TreeItem = _list.get_selected()
			if item != null:
				choose(item.get_index()))
	_list.gui_input.connect(_on_list_input)
	column.add_child(_list)
	_foot = Label.new()
	_foot.name = "palette_foot"
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Never taller for being narrow: the box's height was measured with the
	# foot not yet laid out, and wrapped at no width its words were a
	# letter to a line (the header's first open).
	_foot.max_lines_visible = FOOT_LINES
	_foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_foot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_foot.add_theme_font_size_override("font_size", 13)
	_foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	column.add_child(_foot)
	# A phone's sizing (TouchSizing) grows the words, the field and the rows
	# once the box shows: laid out again for them, once it is done.
	for sized: Control in [_field, _list, _foot]:
		sized.theme_changed.connect(_lay_out_soon)
	if not run_command.is_valid():
		run_command = shell.run
	for named: Variant in ShellPrefs.value("palette_recent"):
		if shell.command(str(named)) != null:
			recent.append(str(named))
	_index()


## Open over the model, empty, the keys in the box: under the top of the
## model's part of the window (the menu bar, the toolbar and the banners
## over it are left in sight), in the middle of it across, and wholly in the
## window.
func open() -> void:
	var room: Rect2 = _room()
	var over: Rect2 = shell.model_area.get_global_rect() if shell.model_area != null else room
	_wide = minf(WIDE, room.size.x - 2.0 * MARGIN)
	(_field.get_parent() as Control).custom_minimum_size.x = _wide - _chrome().x
	var left: float = clampf(over.get_center().x - _wide / 2.0, room.position.x + MARGIN,
		room.end.x - _wide - MARGIN)
	_at = Vector2i(roundi(left), roundi(maxf(over.position.y + UNDER, room.position.y + MARGIN)))
	_field.text = ""
	_fill()
	# A window too short for even a row under the model's top: as low as
	# leaves the box whole.
	var bottom: float = room.end.y - MARGIN
	if _at.y + size.y > bottom:
		_at.y = roundi(maxf(room.position.y + MARGIN, bottom - size.y))
	popup(Rect2i(_at, Vector2i(roundi(_wide), size.y)))
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
## Only a part whose name or number has every word typed: the part search
## also finds parts by their keywords and builders' names for them, and
## "mirror" listed Minifig Cutlery Spoon, a keyword's alone. Of those, the
## ones with the most words whole: "mirror" lists Hand Mirror, not Thorn
## Mirrored, while "mirr" lists both.
func parts_for(asked: String) -> Array[String]:
	var out: Array[String] = []
	if asked.strip_edges().length() < 3 or shell.read_only or shell.store.laying \
			or not shell.library.search_ready():
		return out
	var typed: PackedStringArray = words_of(asked)
	var said: String = asked.strip_edges().to_lower()
	# A number LDraw keeps for an old part, or an element number as a
	# booklet prints it, names its part (PartLibrary.search).
	var numbered: String = ""
	if shell.library.superseded(said):
		numbered = shell.library.current(said)
	var element: Array = shell.library.part_of_element(said)
	if not element.is_empty():
		numbered = str(element[0])
	var kept: Array = []
	var best: int = -1
	for info: PartLibrary.PartInfo in shell.library.search(asked, PARTS_LOOKED_AT, true):
		if not info.reachable:
			continue
		var whole: int = typed.size() if info.id == numbered else named_by(typed, info.id, info.name)
		if whole < 0:
			continue
		kept.append([whole, info.id])
		best = maxi(best, whole)
	for row: Array in kept:
		if int(row[0]) == best and out.size() < PARTS_SHOWN:
			out.append(PART + str(row[1]))
	return out


## How many of [param typed] are whole words of a part's name or its number,
## each of the others beginning one; -1 when a word is in neither. A size
## typed as one ("2x4") is the name's "2 x 4", and two words a name runs
## together ("air tank") are LDraw's one ("Airtank").
static func named_by(typed: PackedStringArray, part_id: String, part_name: String) -> int:
	var own: PackedStringArray = words_of(part_name)
	var number: String = part_id.to_lower()
	var whole: int = 0
	for n: int in typed.size():
		var how: int = _word_in(typed[n], own, number)
		if how == 0 and n > 0:
			how = mini(_word_in(typed[n - 1] + typed[n], own, number), 1)
		if how == 0:
			return -1
		if how == 2:
			whole += 1
	return whole


## 2 when [param word] is a word of [param own] or the number whole, 1 when
## it begins one (or begins words of it run together), else 0.
static func _word_in(word: String, own: PackedStringArray, number: String) -> int:
	if word == number:
		return 2
	var how: int = 1 if number.begins_with(word) else 0
	for at: int in own.size():
		var run: String = ""
		for next: int in range(at, own.size()):
			run += own[next]
			if run == word:
				return 2
			if run.length() >= word.length():
				if run.begins_with(word):
					how = 1
				break
	return how


## What a browser check reads (Main's page state): whether it is open, what
## is typed, the first rows, and the lit one and why it is greyed, if it is;
## and where the box is (x, y, width, height), the window's size and the
## top of the model's part of it, all in the window's units: wholly in the
## window and under that top is where it is meant (palette_flow).
func page_state() -> Dictionary:
	var lit: String = _names[_lit] if _lit >= 0 and _lit < _names.size() else ""
	var room: Rect2 = _room() if is_inside_tree() else Rect2()
	var over: Rect2 = shell.model_area.get_global_rect() if shell.model_area != null else room
	return {"open": visible, "typed": _field.text if _field != null else "",
		"rows": _names.slice(0, 12), "lit": lit,
		"why": shell.why_not(lit) if not lit.is_empty() and not lit.begins_with(PART) else "",
		"rect": [position.x, position.y, size.x, size.y], "room": [room.size.x, room.size.y],
		"floor": roundi(over.position.y)}


## Its controls by name, for a browser check to press them as a person does:
## the field, and the rows (a check moves the pointer over them).
func controls_by_name() -> Dictionary:
	return {"palette_field": _field, "palette_rows": _list} if visible else {}


static func words_of(text: String) -> PackedStringArray:
	if _apart == null:
		# Letters of any language: "öffnen", "écran".
		_apart = RegEx.create_from_string("[^\\p{L}\\p{N}]+")
	return _apart.sub(text.to_lower(), " ", true).split(" ", false)


func _score(typed: PackedStringArray, named: String) -> int:
	var command: Shell.Command = shell.command(named)
	var score: int = _score_in(typed, command.words, where(named), command.tip)
	# And by the words the interface draws them with, in its language.
	if Language.current() != "en":
		var path := PackedStringArray()
		for menu: String in where(named).split(INTO):
			path.append(atr(menu))
		score = maxi(score, _score_in(typed, atr(command.words), INTO.join(path),
			atr(command.tip)))
	return score


func _score_in(typed: PackedStringArray, words: String, where_words: String,
		tip_words: String) -> int:
	var own: PackedStringArray = words_of(words)
	var menu: PackedStringArray = words_of(where_words)
	var tip: PackedStringArray = words_of(tip_words)
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
		for column: int in 3:
			item.set_text_overrun_behavior(column, TextServer.OVERRUN_TRIM_ELLIPSIS)
		if named.begins_with(PART):
			_part_row(item, named.trim_prefix(PART))
			continue
		var why: String = shell.why_not(named)
		item.set_text(0, row_words(named))
		item.set_text(1, why if not why.is_empty() else where(named))
		item.set_text(2, shell.key_words(named))
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)
		# Its tip is the foot's when it is lit, as the pointer lights it: a
		# tooltip too sat over the rows under it.
		if why.is_empty():
			item.set_custom_color(1, Color(1, 1, 1, 0.62))
			item.set_custom_color(2, Color(1, 1, 1, 0.72))
		else:
			# Greyed, and what it waits for in the colour of a note.
			item.set_custom_color(0, Color(1, 1, 1, 0.48))
			item.set_custom_color(1, Color(1.0, 0.84, 0.55, 0.9))
			item.set_custom_color(2, Color(1, 1, 1, 0.42))
	_lay_out()
	_lit = -1
	_light(0)
	if _names.is_empty():
		_foot.text = "No command or part has the words “%s”." % _field.text.strip_edges()


func _part_row(item: TreeItem, part_id: String) -> void:
	var info: PartLibrary.PartInfo = shell.library.parts.get(part_id)
	item.set_text(0, Inventory._tidy(info.name) if info != null else part_id)
	item.set_text(1, "Part %s" % part_id)
	item.set_custom_color(1, Color(1, 1, 1, 0.62))


## The rows' words at their sizes, the columns fitted to them, and the list
## as tall as its rows, up to ROWS_SHOWN and what the room under the box
## holds; then the box as tall as that, where it is. Again when a phone's
## sizing grows the words (theme_changed).
func _lay_out() -> void:
	if _list == null or _list.get_root() == null or _foot == null:
		return
	var beside: int = _beside_size()
	for item: TreeItem in _list.get_root().get_children():
		item.set_custom_font_size(1, beside)
		item.set_custom_font_size(2, beside)
	_fit_columns(beside)
	var line: float = _foot.get_theme_font("font").get_height(_foot.get_theme_font_size("font_size"))
	_foot.custom_minimum_size.y = ceilf(line * FOOT_LINES
		+ _foot.get_theme_constant("line_spacing") * (FOOT_LINES - 1))
	var rows: int = clampi(_names.size(), 1, _rows_room())
	_list.custom_minimum_size.y = _list_height(rows)
	reset_size()


## The list's height for [param rows] rows, no scroll bar while they are
## all it holds: its panel's edges, the rows, and one spacing the engine
## counts for the hidden root. Without that spacing one row as tall as the
## list had a scroll bar beside it.
func _list_height(rows: int) -> float:
	return ceilf(_list.get_theme_stylebox("panel").get_minimum_size().y
		+ _row_height(_list.get_root()) * rows + _list.get_theme_constant("v_separation"))


var _laying: bool = false


func _lay_out_soon() -> void:
	if not _laying:
		_laying = true
		(func() -> void:
			_laying = false
			_lay_out()).call_deferred()


## What is beside a row's name, as much smaller than it as on the desktop.
func _beside_size() -> int:
	return maxi(1, roundi(_list.get_theme_font_size("font_size") * float(BESIDE_SIZE) / NAME_SIZE))


## The key column as wide as the widest key; the names as wide as the
## widest of them, if the middle column keeps its least share; the middle
## one the rest, up to its widest words. Names were cut at half the row
## while "Part 96488" beside them had a third to itself, and then while a
## greyed row's reason far down the list kept the middle column wide.
func _fit_columns(beside: int) -> void:
	var font: Font = _list.get_theme_font("font")
	var name_size: int = _list.get_theme_font_size("font_size")
	var pad: float = _list.get_theme_constant("inner_item_margin_left") \
		+ _list.get_theme_constant("inner_item_margin_right") + _list.get_theme_constant("h_separation")
	var widest: Array[float] = [0.0, 0.0, 0.0]
	for item: TreeItem in _list.get_root().get_children():
		for column: int in 3:
			var words: String = item.get_text(column)
			if not words.is_empty():
				widest[column] = maxf(widest[column], font.get_string_size(_list.atr(words),
					HORIZONTAL_ALIGNMENT_LEFT, -1, name_size if column == 0 else beside).x + pad)
	# The rows' width: the box's, less its edges, the list's own, and a
	# scroll bar's when the rows are more than the room shows.
	var across: float = _wide - _chrome().x - _list.get_theme_stylebox("panel").get_minimum_size().x
	if _names.size() > _rows_room():
		for bar: Node in _list.get_children(true):
			if bar is VScrollBar:
				across -= (bar as VScrollBar).get_combined_minimum_size().x
	var keys: float = widest[2]
	var middle: float = minf(widest[1], maxf(across - keys - widest[0], across * MIDDLE_LEAST))
	_list.set_column_custom_minimum_width(2, ceili(keys))
	_list.set_column_custom_minimum_width(1, ceili(maxf(middle, 0.0)))


## How many rows the room under the box's top holds, up to ROWS_SHOWN.
func _rows_room() -> int:
	if not is_inside_tree() or _list.get_root() == null:
		return ROWS_SHOWN
	var room: float = _room().end.y - MARGIN - float(_at.y) - _height_but_list() - _list_height(0)
	return clampi(floori(room / maxf(_row_height(_list.get_root()), 1.0)), 1, ROWS_SHOWN)


## The box's height but its list's: its margins, the field, the foot.
func _height_but_list() -> float:
	var gap: float = float((_field.get_parent() as Control).get_theme_constant("separation"))
	return _chrome().y + _field.get_combined_minimum_size().y + gap * 2.0 \
		+ maxf(_foot.custom_minimum_size.y, _foot.get_minimum_size().y)


## The box's own margins round what it holds, across and down.
func _chrome() -> Vector2:
	var face: StyleBox = get_theme_stylebox("panel")
	return face.get_minimum_size() if face != null else Vector2.ZERO


## The window's part the box is drawn in.
func _room() -> Rect2:
	return get_parent().get_viewport().get_visible_rect()


## Light [param row]: the keys' row, scrolled into sight, or the pointer's
## ([param scroll] false: the list is not moved under the pointer).
func _light(row: int, scroll: bool = true) -> void:
	if _names.is_empty():
		_lit = -1
		return
	_lit = clampi(row, 0, _names.size() - 1)
	var item: TreeItem = _list.get_root().get_child(_lit)
	item.select(0)
	if scroll:
		_list.scroll_to_item(item)
	var named: String = _names[_lit]
	if named.begins_with(PART):
		# Its whole name here, where a name cut short in its row is read.
		_foot.text = "%s. %s" % [item.get_text(0), atr("Takes it into hand, to put down with a click.")]
		return
	var said: String = shell.command(named).tip
	var why: String = shell.why_not(named)
	if not why.is_empty():
		said = "%s.%s" % [why, (" " + said) if not said.is_empty() else ""]
	_foot.text = said if not said.is_empty() else where(named)


## The pointer over a row lights it: one lit row, which Return runs.
func _on_list_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	var item: TreeItem = _list.get_item_at_position(motion.position)
	if item != null and item.get_parent() == _list.get_root() and item.get_index() != _lit:
		_light(item.get_index(), false)


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


## A row's height, its spacing in, as the list lays its first out: right
## before the list has been drawn, as each row is one line at one size.
func _row_height(top: TreeItem) -> float:
	if top.get_child_count() > 0:
		return _list.get_item_area_rect(top.get_child(0)).size.y
	return _list.get_theme_font("font").get_height(_list.get_theme_font_size("font_size")) \
		+ 2.0 * _list.get_theme_constant("v_separation")


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
