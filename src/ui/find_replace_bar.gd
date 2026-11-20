## Edit › Find and replace… (Ctrl-Shift-H): a bar over the view that finds a
## part, a colour or a part in a colour in the selection, in the sub-model
## being edited and its copies, or everywhere, every sub-model too, and
## replaces it with another part, another colour or both in one undo step
## (FindReplace; swapfind, APP_UX8 #9).
##
## It lists, as it is typed, where it is found: the model's own parts and
## each sub-model, with counts and copies, each a row that selects them; and
## every colour the part is used in, flagged when more than one. Before the
## replace it says that every copy of a sub-model changes with it ("Changes
## all 4 copies of Wing"), and where the new part will not sit as the old
## one did (another footprint, other connection points), would hold onto
## nothing, or has no room and stays.
##
## A finger reaches all of it: the phone's layout sizes every target 44
## points or more (TouchSizing.place_panel), and More › Edit lists it.
class_name FindReplaceBar
extends PanelContainer

## main.gd: what the bar works on (FindReplace reads it).
var app: Node
## Says a line on the status bar.
var say: Callable = func(_line: String) -> void: pass

## The last find, and what the replace would do ({} for no new part).
var found: Dictionary = {}
var made: Dictionary = {}

var _finder: FindReplace
var _find_part: LineEdit
var _find_colour: OptionButton
var _into_part: LineEdit
var _into_colour: OptionButton
## The row under Replace with that names the part it puts in, its cells.
var _puts: Label
var _puts_row: Array[Control] = []
var _where: OptionButton
var _list: VBoxContainer
var _flag: Label
var _copies: Label
var _fit: Label
var _replace: Button
var _select: Button
var _close: Button
var _later: Timer
## The colours the find's list was made for, so typing keeps the one chosen.
var _find_colours_for: String = "-"


func _ready() -> void:
	visible = false
	_finder = FindReplace.new(app)
	_build()


# -- for the window and a probe -------------------------------------------------


## Shown, with what to find taken from the selection where it is one part
## and colour, the colour in hand to replace with ready, and everything
## said again.
func open() -> void:
	var picked: Array = _finder.builder.selection.keys()
	if not picked.is_empty():
		var brick: BrickWorld.Brick = _finder.world.get_brick(int(picked[0]))
		if brick != null:
			set_find(brick.part_id, brick.color_code)
	_fill_where()
	visible = true
	refresh()
	_find_part.grab_focus()


func close() -> void:
	visible = false


## What to find: a part's number ("" for any part) and an LDraw colour (-1
## for any).
func set_find(part: String, colour: int) -> void:
	_find_part.text = part
	_find_colours_for = "-"
	_fill_find_colours()
	_choose(_find_colour, colour)


## What to replace with: a part's number ("" for its own) and a colour (-1
## for its own).
func set_into(part: String, colour: int) -> void:
	_into_part.text = part
	_choose(_into_colour, colour)


## Where to look: "selection", "submodel" or "all".
func set_where(where: String) -> void:
	_fill_where()
	for n: int in _where.item_count:
		if str(_where.get_item_metadata(n)) == where:
			_where.select(n)


## What is asked of each side as FindReplace reads it.
func asked() -> Dictionary:
	return {"part": _part_asked(_find_part.text, false), "color": _picked(_find_colour)}


func into() -> Dictionary:
	return {"part": _part_asked(_into_part.text, true), "color": _picked(_into_colour)}


func where() -> String:
	return str(_where.get_item_metadata(_where.selected)) if _where.selected >= 0 else "all"


## Found again and said again, as everything stands now. Where the copies'
## frames are not to hand (a model with copies, opened or changed since),
## they are worked out first a slice of a frame at a time, the status bar
## saying so, and the find made once they are (FindReplace.frames_paced_for):
## on 10179 they were one frame of 0.96 s (osfix). A model they take less
## than a slice for is found at once, as before.
func refresh() -> void:
	if not visible or _finder.world == null:
		return
	_fill_find_colours()
	var finding: Dictionary = asked()
	if str(finding["part"]).is_empty() and int(finding["color"]) < 0:
		found = {}
		made = {}
		_show()
		return
	if not _finder.frames_ready(where()):
		# What was found was the model's before: nothing is shown found, or
		# replaced, until the find at the frames' end (in this call, where
		# they take less than a slice).
		found = {}
		made = {}
		_show_reading()
		_frames_then_refresh()
		return
	found = _finder.find(finding, where())
	var putting: Dictionary = into()
	made = {}
	if not (found["ids"] as Array).is_empty() and _changes(putting) and not _unknown():
		var part: String = putting["part"]
		var other: String = "" if part.is_empty() \
			else Later.script(&"Mirror").counterpart(_finder.library, part)
		if not part.is_empty() and (_finder.library.mesh_for(part) == null
				or not other.is_empty() and _finder.library.mesh_for(other) == null):
			# Its shape is on its way (the web fetches what it has not got),
			# and its other hand's, which a copy a mirror places is given:
			# said again once they are here.
			_fetch(part, other)
		else:
			made = _finder.plan(found, putting)
	_show()


## The copies' frames worked out across frames, then found again: one at a
## time, however often it is typed into meanwhile.
func _frames_then_refresh() -> void:
	if _framing:
		return
	_framing = true
	await _finder.frames_paced_for(_finder.looked_in(where()))
	_framing = false
	refresh()


var _framing: bool = false


## The replace, as the Replace button does it: {"changed", "room", "words"},
## {} when there was nothing to do.
func replace_now() -> Dictionary:
	if not _finder.frames_ready(where()):
		await _finder.frames_paced_for(_finder.looked_in(where()))
	refresh()
	var putting: Dictionary = into()
	if found.is_empty() or (found["ids"] as Array).is_empty() or not _changes(putting) \
			or _unknown() or _replace.disabled:
		return {}
	if not str(putting["part"]).is_empty() and await _finder.shape(str(putting["part"])) == null:
		say.call("the part's shape could not be had")
		return {}
	# The plan refresh made a moment ago, as the bar shows it.
	var done: Dictionary = _finder.replace(found, putting, made)
	var changed: int = int(done["changed"])
	var stayed: String = str(done.get("stayed", ""))
	if changed > 0:
		# What changed, and what stayed and why, each part said once.
		say.call(Keymap.filled("%s — {undo|takes it back}") % (str(done["words"])
			+ ("" if stayed.is_empty() else "; %d stayed: %s" % [int(done["room"])
				+ int(done["locked"]), stayed])))
	else:
		say.call("nothing replaced: " + (stayed if not stayed.is_empty() else "none had room for it"))
	refresh()
	return done


# -- what it shows ------------------------------------------------------------------


## While the copies' frames are worked out ([method refresh]): nothing to
## select or replace yet, and the list says why.
func _show_reading() -> void:
	_show()
	_select.disabled = true
	_replace.disabled = true
	for row: Node in _list.get_children():
		row.queue_free()
	_line(FindReplace.FRAMES_WORDS, 0.7)


func _show() -> void:
	for row: Node in _list.get_children():
		row.queue_free()
	_flag.visible = false
	_copies.visible = false
	_fit.visible = false
	_say_puts()
	var count: int = 0 if found.is_empty() else (found["ids"] as Array).size()
	_select.disabled = count == 0
	# Nothing to change: none found, nothing given, a part the library has
	# not got, or every one that already (swreview F6).
	_replace.disabled = count == 0 or not _changes(into()) or _unknown() \
		or (not made.is_empty() and int(made["same"]) == count)
	if found.is_empty():
		_line("Type a part's number or name, or choose a colour, to find it.", 0.7)
		return
	if count == 0:
		_line(_none_words(), 0.75)
		return
	_line(_count_words(count), 0.95)
	for place: Dictionary in found["places"]:
		_place_row(place)
	var colours: Dictionary = found["colours"]
	var codes: Array = colours.keys()
	codes.sort_custom(func(a: int, b: int) -> bool: return int(colours[a]) > int(colours[b]))
	for code: int in codes:
		_colour_row(code, int(colours[code]))
	if colours.size() > 1:
		_flag.text = ("Used in %d colours: each keeps its own" % colours.size()) \
			if int(into()["color"]) < 0 else ("Used in %d colours: all will be %s"
				% [colours.size(), _finder.colour_name(int(into()["color"]))])
		_flag.visible = true
	var copied := PackedStringArray()
	for place: Dictionary in found["places"]:
		if int(place["copies"]) > 1:
			copied.append("Changes all %d copies of %s" % [int(place["copies"]), place["name"]])
	if not copied.is_empty() and _changes(into()):
		_copies.text = "\n".join(copied)
		_copies.visible = true
	var lines := PackedStringArray()
	if not made.is_empty():
		var otherwise: int = (made["otherwise"] as Array).size()
		if otherwise > 0:
			lines.append("Won't sit the same in %d of %d places: another footprint or other connection points"
				% [otherwise, count])
		var floats: int = (made["floats"] as Array).size()
		if floats > 0:
			lines.append("%d would hold onto nothing" % floats)
	# What stays, and why: no room, a twin in another copy with none, a
	# lock, or each one that already; and those locked, before a replace
	# is chosen too.
	lines.append_array(FindReplace.stay_words(found, made))
	if not lines.is_empty():
		_fit.text = "\n".join(lines)
		_fit.visible = true


func _count_words(count: int) -> String:
	match where():
		"selection":
			return "%d found in the selection" % count
		"submodel":
			var inside: String = found.get("inside", "")
			return ("%d found in the model's own parts" % count) if inside.is_empty() \
				else ("%d found in %s and its copies" % [count,
					Assemblies.definition(Assemblies.leaf(inside))])
	return "%d found everywhere, every sub-model too" % count


func _none_words() -> String:
	var locked: int = int(found.get("locked", 0))
	if locked > 0:
		return "Only locked parts are like that: unlock them to change them"
	return "Nothing like that here"


## A row naming a place and its count, which selects the parts found there.
func _place_row(place: Dictionary) -> void:
	var name: String = place["name"]
	var count: int = int(place["count"])
	var copies: int = int(place["copies"])
	var words: String = ("The model's own parts: %d" % count) if name.is_empty() \
		else ("%s: %d" % [name, count]) if copies <= 1 \
		else ("%s: %d in each of %d copies" % [name, count / copies, copies]) \
			if count % copies == 0 else ("%s: %d in %d copies" % [name, count, copies])
	var row := _row_button(words, "Select the parts found here")
	row.pressed.connect(func() -> void: _select_in(name))
	_list.add_child(row)


func _colour_row(code: int, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var swatch := ColorRect.new()
	swatch.color = _finder.library.color(code).rgb
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var words := Label.new()
	words.text = "%s: %d" % [_finder.colour_name(code), count]
	words.add_theme_font_size_override("font_size", 12)
	row.add_child(words)
	_list.add_child(row)


func _line(text: String, alpha: float) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.modulate.a = alpha
	_list.add_child(label)


## The found parts in the sub-model named [param name] ("" for the model's
## own), selected.
func _select_in(name: String) -> void:
	var ids: Array = []
	for brick_id: int in found.get("ids", []):
		var brick: BrickWorld.Brick = _finder.world.get_brick(brick_id)
		if brick == null:
			continue
		var path: String = Assemblies.path_of(brick)
		var def: String = "" if path.is_empty() else Assemblies.definition(Assemblies.leaf(path))
		if def == name:
			ids.append(brick_id)
	_select_ids(ids)


func _select_ids(ids: Array) -> void:
	var verbs: EditVerbs = app.get("_verbs")
	var picked: int = verbs.select_found(ids)
	say.call("selected %d" % picked if picked > 0
		else "they are hidden or locked — show everything, or unlock them")


# -- what it reads --------------------------------------------------------------------


func _changes(putting: Dictionary) -> bool:
	return not str(putting["part"]).is_empty() or int(putting["color"]) >= 0


## Whether the part typed to replace with names none the library has.
func _unknown() -> bool:
	return not _into_part.text.strip_edges().is_empty() and str(into()["part"]).is_empty()


## The part Replace puts in, named under Replace with as the library has it:
## a number typed, a moved number's new one, or the part a name typed finds
## first ("brick" puts in a 3004): "Puts in: Brick 1 x 2 (3004)", or "No
## part 3023x", Replace then off (swreview F4).
func _say_puts() -> void:
	var typed: String = _into_part.text.strip_edges()
	var part: String = str(into()["part"])
	for cell: Control in _puts_row:
		cell.visible = not typed.is_empty()
	if typed.is_empty():
		_puts.text = ""
	elif part.is_empty():
		_puts.text = "No part %s" % typed
	else:
		_puts.text = "Puts in: %s (%s)" % [_finder.part_name(part), part]


## A part typed: its number as typed for a find (3023 finds every letter of
## it), or a known part for a replace; a name, the part a search finds
## first. "" for none.
func _part_asked(text: String, exact: bool) -> String:
	var said: String = text.strip_edges().to_lower().trim_suffix(".dat")
	if said.is_empty():
		return ""
	if not exact and said.is_valid_int():
		return said
	return _finder.part_of(said)


static func _picked(options: OptionButton) -> int:
	return int(options.get_item_metadata(options.selected)) if options.selected >= 0 else -1


static func _choose(options: OptionButton, code: int) -> void:
	for n: int in options.item_count:
		if int(options.get_item_metadata(n)) == code:
			options.select(n)
			return
	options.select(0)


## The find's colours: any, then those the part typed is used in, or every
## colour in the model while no part is typed.
func _fill_find_colours() -> void:
	var part: String = _part_asked(_find_part.text, false)
	if part == _find_colours_for:
		return
	_find_colours_for = part
	var keep: int = _picked(_find_colour) if _find_colour.item_count > 0 else -1
	_find_colour.clear()
	_find_colour.add_item("Any colour")
	_find_colour.set_item_metadata(0, -1)
	var counts: Dictionary = {}
	for brick: BrickWorld.Brick in _finder.world.bricks():
		if _finder.scenery.has(brick.id):
			continue
		if part.is_empty() or _finder.same_part(brick.part_id, part):
			counts[brick.color_code] = int(counts.get(brick.color_code, 0)) + 1
	var codes: Array = counts.keys()
	codes.sort_custom(func(a: int, b: int) -> bool:
		return _finder.colour_name(a).naturalnocasecmp_to(_finder.colour_name(b)) < 0)
	for code: int in codes:
		_find_colour.add_item(_finder.colour_name(code))
		_find_colour.set_item_metadata(_find_colour.item_count - 1, code)
	_choose(_find_colour, keep)


## The colours to replace with: its own, the colour in hand, then every
## colour the bin offers, by name.
func _fill_into_colours() -> void:
	_into_colour.clear()
	_into_colour.add_item("The same colour")
	_into_colour.set_item_metadata(0, -1)
	var codes: Array = []
	for code: int in _finder.library.colors:
		var colour: PartLibrary.BrickColor = _finder.library.colors[code]
		if code in PartsBin.NOT_A_COLOUR or not PartsBin._in_any_group(colour):
			continue
		codes.append(code)
	codes.sort_custom(func(a: int, b: int) -> bool:
		return _finder.colour_name(a).naturalnocasecmp_to(_finder.colour_name(b)) < 0)
	for code: int in codes:
		_into_colour.add_item(_finder.colour_name(code))
		_into_colour.set_item_metadata(_into_colour.item_count - 1, code)


## Where to look, the sub-model's own name in its row; the selection only
## with something selected.
func _fill_where() -> void:
	var keep: String = where() if _where.item_count > 0 else "all"
	_where.clear()
	var inside: String = _finder.assemblies.entered if _finder.assemblies != null else ""
	var rows: Array = [["all", "Everywhere, every sub-model too"],
		["submodel", "In the model's own parts" if inside.is_empty()
			else "In %s and its copies" % Assemblies.definition(Assemblies.leaf(inside))]]
	if not _finder.builder.selection.is_empty():
		rows.append(["selection", "In the selection"])
	for row: Array in rows:
		_where.add_item(str(row[1]))
		_where.set_item_metadata(_where.item_count - 1, row[0])
	set_where_quietly(keep)


func set_where_quietly(keep: String) -> void:
	_where.select(0)
	for n: int in _where.item_count:
		if str(_where.get_item_metadata(n)) == keep:
			_where.select(n)


## Said again once [param part]'s shape is here, and its other hand's
## ([param other], "" for none).
func _fetch(part: String, other: String) -> void:
	var shape: Lbm.PartMesh = await _finder.shape(part)
	if not other.is_empty():
		await _finder.shape(other)
	if shape != null and visible:
		refresh()


# -- made once ----------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.96)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 10
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Find and replace"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button(header, "Close", close, "Put the bar away")
	# On a phone held either way, each colour under its part: three across
	# were 467 points wide, past a phone's 390.
	var stacked: bool = Phone.on() and not Phone.wide()
	var grid := GridContainer.new()
	grid.columns = 2 if stacked else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	_label(grid, "Find")
	_find_part = _field(grid, "Any part: its number or name", "The part to find")
	if stacked:
		grid.add_child(Control.new())
	_find_colour = _options(grid, "The colour to find")
	_label(grid, "Replace with")
	_into_part = _field(grid, "The same part", "The part to put in its place")
	if stacked:
		grid.add_child(Control.new())
	_into_colour = _options(grid, "The colour to give it")
	_fill_into_colours()
	# Under it, the part Replace puts in, named: a row of its own, shown
	# while a part is typed (a grid's hidden cell would move the others).
	_puts_row.append(Control.new())
	grid.add_child(_puts_row[0])
	_puts = Label.new()
	_puts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_puts.add_theme_font_size_override("font_size", 12)
	_puts.add_theme_color_override("font_color", Color(0.62, 0.8, 1.0))
	_puts.custom_minimum_size = Vector2(150, 0)
	_puts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_puts)
	_puts_row.append(_puts)
	if not stacked:
		_puts_row.append(Control.new())
		grid.add_child(_puts_row[2])
	for cell: Control in _puts_row:
		cell.visible = false
	_label(grid, "Where")
	_where = _options(grid, "Where to look")
	_where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not stacked:
		grid.add_child(Control.new())
	_find_colour.item_selected.connect(func(_n: int) -> void: refresh())
	_into_colour.item_selected.connect(func(_n: int) -> void: refresh())
	_where.item_selected.connect(func(_n: int) -> void: refresh())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	_flag = _note(column, Color(1.0, 0.78, 0.35))
	_copies = _note(column, Color(0.62, 0.8, 1.0))
	_fit = _note(column, Color(1.0, 0.6, 0.5))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_select = _button(buttons, "Select them", func() -> void: _select_ids(found.get("ids", [])),
		"Select every part found")
	_replace = _button(buttons, "Replace", func() -> void: await replace_now(),
		"Replace every part found, as one undo step")
	_later = Timer.new()
	_later.one_shot = true
	_later.wait_time = 0.2
	_later.timeout.connect(refresh)
	add_child(_later)
	custom_minimum_size = Vector2(360, 0)


func _label(into: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	into.add_child(label)


func _field(into: Control, hint: String, name: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.accessibility_name = name
	field.custom_minimum_size = Vector2(190, 0)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 12)
	field.text_changed.connect(func(_text: String) -> void: _later.start())
	field.text_submitted.connect(func(_text: String) -> void: refresh())
	into.add_child(field)
	return field


func _options(into: Control, name: String) -> OptionButton:
	var options := OptionButton.new()
	options.accessibility_name = name
	options.fit_to_longest_item = false
	options.custom_minimum_size = Vector2(150, 0)
	options.add_theme_font_size_override("font_size", 12)
	into.add_child(options)
	return options


func _note(into: Control, colour: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", colour)
	label.visible = false
	into.add_child(label)
	return label


func _button(into: Control, text: String, run: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(run)
	into.add_child(button)
	return button


func _row_button(text: String, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12)
	return button


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if visible and key != null and key.pressed and key.keycode == KEY_ESCAPE \
			and get_viewport().gui_get_focus_owner() != null \
			and is_ancestor_of(get_viewport().gui_get_focus_owner()):
		close()
		get_viewport().set_input_as_handled()
