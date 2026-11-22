## "Where does this go?": the part in a builder's hand, photographed, to the
## step that places it (APP_UX11 partstep).
##
## A builder at step 40 of a big set holds a part and cannot find its step.
## Photo search names a part (Brickognize, as the parts bin asks it), and
## the steps say which of them place it (stepsearch's step lots); the two
## were not joined. Here the photo's answer is read against the model's own
## steps: of Brickognize's guesses, the parts this model has come first (a
## part in hand at a table comes from the set's own pile), in the colour the
## model has nearest to the one the photo shows, and the first step not yet
## built that places it is the answer. Where it goes in more than one step,
## how many and which; where every step that places it is built, so it is
## said, and that a set comes with a spare or two.
##
## [method place] is the reading, the same for Build mode (BuildMode, its
## pages' own new parts) and a session's edit_steps find with a picture
## (AppTools, the model's steps): pure, so a probe reads it with no photo
## sent at all. The rest is the card Build mode shows the answer on, under
## its top bar: the part's picture, name and colour, where it goes, every
## step that places it as a button, and the other guesses one tap away
## ("Not it?"), as a photo's top three are the bar it is measured by.
##
## Only the photo the person chose is sent, never the model, and only once
## they have been told where it goes (BuildMode._ask_photo, the bin's words,
## Brickognize.TERMS).
class_name PartStep
extends PanelContainer

## A step chosen on the card, or the one an answer found: its place in the
## steps (from 0) and the bricks of the part there, to light.
signal place_wanted(index: int, bricks: Dictionary)
## The other guesses' number chosen ("Not it?"): its place in the answer's options.
signal option_wanted(option: int)
## Back to the page the builder asked from ([member home]).
signal back_wanted
signal closed

## How many of a photo's guesses are offered: the top three.
const SHOWN := 3
## How many steps the card lists as buttons, the rest counted.
const STEPS_SHOWN := 8
## How sure Brickognize must be of the colour for it to count (PartsBin.COLOUR_LEAST).
const COLOUR_LEAST := 0.3
## A part's picture on the card, in points.
const PICTURE := 56.0
## The least a target is, either way, in points (BuildMode.TARGET).
const TARGET := 44.0


# -- the reading -----------------------------------------------------------------


## What the model's steps say of a photo's answer. [param guesses] are
## Brickognize's, best first ({bricklink, name, score}); [param seen] the
## colour it saw ({bricklink, name, score}, or {}); [param steps] each step's
## bricks, as ids, in the steps' order; [param from] the first step not yet
## built, from 0. [param pick] chooses one of the options by its place, -1
## the first the model has. Returns:
## - "options": up to SHOWN guesses, the model's parts first, each {bricklink,
##   name, score, part (the part here, or ""), parts (the model's part ids it
##   is), in_model};
## - "picked": the option read, -1 for none the model has;
## - "parts": the model's part ids it is -> true; "colour": the colour read
##   (an LDraw code, -1 any of the model's); "colours": each colour the model
##   has it in -> how many;
## - "hits": each step that places it, [step, how many, brick id -> true], in
##   order; "step": the first of them at or after [param from], -1 for none;
##   "count": how many it places; "built": how many of the hits are before
##   [param from].
static func place(guesses: Array, seen: Dictionary, library: PartLibrary, world: BrickWorld,
		steps: Array, from: int, pick: int = -1, index: Dictionary = {}) -> Dictionary:
	if index.is_empty():
		index = index_of(library, world, steps)
	var colours_of: Dictionary = index["colours_of"]
	var by_key: Dictionary = index["by_key"]
	# The guesses, each as the model's parts it is. Matched by numbers alone,
	# never through PartLibrary.by_shop or current: the first call of either
	# reads the whole catalogue, 0.9 s of one frame on the box.
	var named: Array = []
	var seen_numbers: Dictionary = {}
	var seen_parts: Dictionary = {}
	for raw: Variant in guesses:
		if not raw is Dictionary:
			continue
		var guess: Dictionary = raw
		var number: String = str(guess.get("bricklink", "")).strip_edges()
		var key: String = number.to_lower()
		if number.is_empty() or seen_numbers.has(key):
			continue
		seen_numbers[key] = true
		# A number LDraw has as a part goes by that part's numbers too: 54657
		# moved to 44302.
		var parts: Dictionary = {}
		for one: String in numbers_of(library, key) if library.parts.has(key) else [key, _unlettered(key)]:
			parts.merge(by_key.get(one, {}))
		var ids: Array = parts.keys()
		ids.sort()
		# Two guesses that are the same parts here (3245c and 3245b, both the
		# castle's 3245a) are one choice.
		if not ids.is_empty() and seen_parts.has(str(ids)):
			continue
		seen_parts[str(ids)] = true
		var here: String = str(ids[0]) if not ids.is_empty() \
			else (library.resolve(key) if library.parts.has(key) else "")
		var info: PartLibrary.PartInfo = library.parts.get(here) if not here.is_empty() else null
		named.append({"bricklink": number,
			"name": info.name.strip_edges().replace("  ", " ") if info != null else str(guess.get("name", number)),
			"score": float(guess.get("score", 0.0)), "part": here, "parts": ids, "in_model": not ids.is_empty()})
	var options: Array = named.filter(func(one: Dictionary) -> bool: return bool(one["in_model"]))
	options.append_array(named.filter(func(one: Dictionary) -> bool: return not bool(one["in_model"])))
	options = options.slice(0, SHOWN)
	var picked: int = -1
	if pick >= 0 and pick < options.size() and bool(options[pick]["in_model"]):
		picked = pick
	elif pick < 0:
		for n: int in options.size():
			if bool(options[n]["in_model"]):
				picked = n
				break
	var out: Dictionary = {"options": options, "picked": picked, "parts": {}, "colour": -1,
		"colours": {}, "hits": [], "step": -1, "count": 0, "built": 0}
	if picked < 0:
		return out
	var wanted: Dictionary = {}
	var colours: Dictionary = {}
	for part_id: String in options[picked]["parts"]:
		wanted[part_id] = true
		for code: int in colours_of[part_id]:
			colours[code] = int(colours.get(code, 0)) + int(colours_of[part_id][code])
	var colour: int = colour_for(library, seen, colours)
	# Only the bricks of the part, from the index: 10179's every brick, read
	# again, was half a frame.
	var where: Dictionary = index["where"]
	var by_step: Dictionary = {}
	for part_id: String in wanted:
		var placed_at: PackedInt64Array = where.get(part_id, PackedInt64Array())
		for n: int in range(0, placed_at.size(), 3):
			if colour >= 0 and placed_at[n + 2] != colour:
				continue
			var at: int = placed_at[n]
			if not by_step.has(at):
				by_step[at] = [at, 0, {}]
			var hit: Array = by_step[at]
			hit[1] = int(hit[1]) + 1
			(hit[2] as Dictionary)[placed_at[n + 1]] = true
	var hits: Array = by_step.values()
	hits.sort_custom(func(one: Array, other: Array) -> bool: return int(one[0]) < int(other[0]))
	var step: int = -1
	var placed: int = 0
	var built: int = 0
	for hit: Array in hits:
		if int(hit[0]) < from:
			built += 1
		elif step < 0:
			step = int(hit[0])
			placed = int(hit[1])
	out.merge({"parts": wanted, "colour": colour, "colours": colours, "hits": hits, "step": step,
		"count": placed, "built": built}, true)
	return out


## The model's parts, for [method place] to read photos against: each
## part's colours ({"colours_of": part id -> {LDraw code -> how many}}), and
## its parts by every number they go by ({"by_key": number -> {part id ->
## true}}, numbers_of), and where each is placed ({"where": part id ->
## [step, brick id, LDraw code] after each other, from 0}). [param steps] as
## [method place] has them. Kept by a
## caller reading several photos against the same steps: on 10179 it is most
## of a frame.
static func index_of(library: PartLibrary, world: BrickWorld, steps: Array) -> Dictionary:
	var colours_of: Dictionary = {}
	var where: Dictionary = {}
	for at: int in steps.size():
		for brick_id: int in steps[at]:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick == null:
				continue
			if not colours_of.has(brick.part_id):
				colours_of[brick.part_id] = {}
				where[brick.part_id] = PackedInt64Array()
			var counted: Dictionary = colours_of[brick.part_id]
			counted[brick.color_code] = int(counted.get(brick.color_code, 0)) + 1
			var placed_at: PackedInt64Array = where[brick.part_id]
			placed_at.append(at)
			placed_at.append(brick_id)
			placed_at.append(brick.color_code)
			where[brick.part_id] = placed_at
	var by_key: Dictionary = {}
	for part_id: String in colours_of:
		for key: String in numbers_of(library, part_id):
			if not by_key.has(key):
				by_key[key] = {}
			(by_key[key] as Dictionary)[part_id] = true
	return {"colours_of": colours_of, "by_key": by_key, "where": where}


## The numbers a part of the model goes by, in lower case, for a photo's
## BrickLink number to meet it: its own, each BrickLink number LDraw records
## for it (6141 is BrickLink's 4073; 44302a is 54657 too), where it moved to,
## and the same of the plain part a print is a version of; each also without
## the letter a mould's version adds (3023b is BrickLink's 3023, and 3660a
## and 3660b are one part to a builder holding it).
static func numbers_of(library: PartLibrary, part_id: String) -> Array:
	var said: Array = []
	for one: String in [part_id, library.resolve(part_id), PartPrints.plain_of(library, part_id)]:
		said.append(one)
		var info: PartLibrary.PartInfo = library.parts.get(one)
		if info == null:
			continue
		for word: String in info.keywords:
			if word.to_lower().begins_with("bricklink ") and word.get_slice_count(" ") == 2:
				said.append(word.get_slice(" ", 1))
	var out: Array = []
	for one: String in said:
		for number: String in [one.to_lower(), _unlettered(one.to_lower())]:
			if not out.has(number):
				out.append(number)
	return out


## [param number] without a mould's one trailing letter after its digits
## ("3023b" 3023, "44302a" 44302); as it is otherwise.
static func _unlettered(number: String) -> String:
	if number.length() >= 2 and number[-1] >= "a" and number[-1] <= "z" and number[-2].is_valid_int():
		return number.left(-1)
	return number


## The colour a part in hand is read in, of the model's [param colours]
## (code -> how many): the one the photo shows where the model has it in
## that one; else the model's nearest to it, as a part from the set's own pile
## is in one of the set's colours and a photo's light shifts it; the one
## colour where the model has it in one; else -1, any of them.
static func colour_for(library: PartLibrary, seen: Dictionary, colours: Dictionary) -> int:
	if colours.size() == 1:
		return int(colours.keys()[0])
	var code: int = -1
	if not seen.is_empty() and float(seen.get("score", 0.0)) >= COLOUR_LEAST:
		code = int(PartLibrary.by_bricklink.get(int(seen.get("bricklink", -1)), -1))
	if code < 0 or colours.is_empty():
		return -1
	if colours.has(code):
		return code
	var shown: PartLibrary.BrickColor = library.color(code)
	if shown == null:
		return -1
	var nearest: int = -1
	var least: float = INF
	for own: int in colours:
		var theirs: PartLibrary.BrickColor = library.color(own)
		if theirs == null:
			continue
		var apart: float = Vector3(shown.color.r - theirs.color.r, shown.color.g - theirs.color.g,
			shown.color.b - theirs.color.b).length()
		if apart < least:
			least = apart
			nearest = own
	return nearest


## The answer's part in words: "Brick 2 x 4, Red", the colour left out where
## any of the model's is read.
static func part_words(library: PartLibrary, answer: Dictionary) -> String:
	if int(answer["picked"]) < 0:
		return ""
	var option: Dictionary = answer["options"][int(answer["picked"])]
	var colour: PartLibrary.BrickColor = library.color(int(answer["colour"])) \
		if int(answer["colour"]) >= 0 else null
	return str(option["name"]) if colour == null \
		else "%s, %s" % [option["name"], colour.name.replace("_", " ")]


## Where it goes, in words, [param name_of] naming a step by its place
## ("12", "12 · Wing 2/3"): the first step not yet built that places it,
## how many it places there, and how many other steps place it and which.
static func where_words(answer: Dictionary, name_of: Callable) -> String:
	var options: Array = answer["options"]
	if options.is_empty():
		return "Brickognize saw no part it knows in that photo: try another, the part alone on a plain background"
	if int(answer["picked"]) < 0:
		return "This model has none of the parts Brickognize sees in that photo"
	var hits: Array = answer["hits"]
	var step: int = int(answer["step"])
	if step < 0:
		var built := PackedStringArray()
		for hit: Array in hits:
			built.append(str(name_of.call(int(hit[0]))))
		return ("Every step that places it is built: %s. It may be a spare: a set comes "
			+ "with a few small ones") % _listed(built) if hits.size() > 1 \
			else ("The step that places it is built: %s. It may be a spare: a set comes with a "
			+ "few small ones") % _listed(built)
	var said: String = "It goes in at step %s" % name_of.call(step) if int(answer["count"]) == 1 \
		else "%d go in at step %s" % [int(answer["count"]), name_of.call(step)]
	if hits.size() <= 1:
		return said
	var others := PackedStringArray()
	for hit: Array in hits:
		if int(hit[0]) != step:
			others.append(str(name_of.call(int(hit[0]))))
	return "%s, the first of %d steps that place it; the others: %s" % [said, hits.size(),
		_listed(others, 6)]


## "4, 9, 12", or "4, 9, 12, …" past [param most]: commas alone, which every
## language reads as they are. Never "%s and %s" as words of their own: the
## app translates a line by its patterns, and that one matched every name
## with an "and" in it ("A sports car, and its driver" came out half German).
static func _listed(items: PackedStringArray, most: int = 12) -> String:
	if items.size() > most:
		return ", ".join(items.slice(0, most)) + ", …"
	return ", ".join(items)


# -- the card ---------------------------------------------------------------------

var thumbnails: PartThumbnails
var library: PartLibrary
## Names a step by its place in the steps ("12", "12 · Wing 2/3").
var name_of: Callable = func(index: int) -> String: return str(index + 1)
## The answer shown, as place gives it; {} while asking or after a failure.
var answer: Dictionary = {}
## The page the builder asked from (0 the cover), offered to go back to
## once the answer has gone elsewhere; -1 none.
var home: int = -1
var _pt: float = 1.0
var _back: Button
var _tile: ThumbTile
var _title: Label
var _where: Label
var _close: Button
var _steps_row: HFlowContainer
var _others_row: HFlowContainer
var _step_buttons: Array[Button] = []
var _other_buttons: Array[Button] = []


func _ready() -> void:
	name = "PartStep"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.name = "Column"
	add_child(column)
	var head := HBoxContainer.new()
	head.name = "Head"
	column.add_child(head)
	_tile = ThumbTile.new("", 0)
	_tile.visible = false
	_tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tile)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(words)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_title)
	_where = Label.new()
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_where.modulate = Color(1, 1, 1, 0.85)
	words.add_child(_where)
	_close = _button("×", "Close")
	_close.accessibility_name = "Close where the part goes"
	_close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_close.pressed.connect(func() -> void:
		hide_card()
		closed.emit())
	head.add_child(_close)
	_steps_row = HFlowContainer.new()
	_steps_row.name = "Steps"
	_steps_row.visible = false
	column.add_child(_steps_row)
	_others_row = HFlowContainer.new()
	_others_row.name = "Others"
	_others_row.visible = false
	column.add_child(_others_row)
	_back = _button("", "Back to the step you were on")
	_back.visible = false
	_back.size_flags_horizontal = Control.SIZE_SHRINK_END
	_back.pressed.connect(func() -> void: back_wanted.emit())
	column.add_child(_back)


func _button(words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


## Sized in points, as Build mode's bars are.
func fit(pt: float) -> void:
	_pt = pt
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0.13, 0.15, 0.19, 0.96)
	dark.border_color = Color(1.0, 0.80, 0.18, 0.9)
	dark.set_border_width_all(maxi(1, roundi(2.0 * pt)))
	dark.set_corner_radius_all(roundi(10.0 * pt))
	dark.set_content_margin_all(10.0 * pt)
	add_theme_stylebox_override("panel", dark)
	(get_node("Column") as VBoxContainer).add_theme_constant_override("separation", roundi(8.0 * pt))
	(get_node("Column/Head") as HBoxContainer).add_theme_constant_override("separation", roundi(10.0 * pt))
	_tile.custom_minimum_size = Vector2.ONE * PICTURE * pt
	_title.add_theme_font_size_override("font_size", roundi(18.0 * pt))
	_where.add_theme_font_size_override("font_size", roundi(15.0 * pt))
	for row: HFlowContainer in [_steps_row, _others_row]:
		row.add_theme_constant_override("h_separation", roundi(6.0 * pt))
		row.add_theme_constant_override("v_separation", roundi(6.0 * pt))
		for child: Node in row.get_children():
			_size_child(child)
	_size_child(_close)
	_size_child(_back)


func _size_child(child: Node) -> void:
	if child is Button:
		var button: Button = child
		button.add_theme_font_size_override("font_size", roundi(16.0 * _pt))
		button.custom_minimum_size = Vector2(TARGET * _pt, TARGET * _pt)
	elif child is Label:
		(child as Label).add_theme_font_size_override("font_size", roundi(15.0 * _pt))


## Asking: the card up with the words alone.
func asking(words: String) -> void:
	answer = {}
	_title.text = words
	_where.text = ""
	_where.visible = false
	_tile.visible = false
	_steps_row.visible = false
	_others_row.visible = false
	_back.visible = false
	visible = true


## Something went wrong, in words.
func failed(why: String) -> void:
	asking(why)


## [param read], as place gives it, on the card: the part, where it goes,
## each step that places it (the one gone to [param at], from 0, lit), and
## the other guesses.
func show_answer(read: Dictionary, at: int) -> void:
	answer = read
	visible = true
	var picked: int = int(read["picked"])
	var option: Dictionary = read["options"][picked] if picked >= 0 else {}
	_title.text = part_words(library, read) if picked >= 0 else (
		"Not in this model: %s" % ", ".join(PackedStringArray((read["options"] as Array).map(
			func(one: Dictionary) -> String: return str(one["name"])))) \
		if not (read["options"] as Array).is_empty() else "No part seen")
	Language.keep_name(_title.text)
	_where.text = where_words(read, name_of)
	_where.visible = true
	# The part's picture, in the colour read (the model's first, for any).
	var part_id: String = ""
	var colour: int = int(read["colour"])
	if picked >= 0 and not (option["parts"] as Array).is_empty():
		part_id = str(option["parts"][0])
		if colour < 0 and not (read["colours"] as Dictionary).is_empty():
			colour = int((read["colours"] as Dictionary).keys()[0])
	_tile.visible = not part_id.is_empty()
	if _tile.visible and (_tile.part_id != part_id or _tile.color_code != colour):
		var fresh := ThumbTile.new(part_id, colour)
		fresh.custom_minimum_size = _tile.custom_minimum_size
		fresh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tile.replace_by(fresh)
		_tile.queue_free()
		_tile = fresh
		var ready: Texture2D = thumbnails.peek(part_id, colour) if thumbnails != null else null
		if ready != null:
			_tile.show_picture(ready, false)
		elif thumbnails != null:
			thumbnails.watch(self, [_tile] as Array[ThumbTile])
	_lay_steps(read, at)
	_lay_others(read)
	_offer_back(at)


## Back to where the builder was, once a step elsewhere is shown.
func _offer_back(at: int) -> void:
	_back.visible = home >= 0 and at >= 0 and at + 1 != home
	_back.text = ("Back to step %d" % home) if home >= 1 else "Back to the start"


func _lay_steps(read: Dictionary, at: int) -> void:
	var hits: Array = read["hits"]
	_steps_row.visible = hits.size() > 1
	for child: Node in _steps_row.get_children():
		_steps_row.remove_child(child)
		child.queue_free()
	_step_buttons.clear()
	if hits.size() <= 1:
		return
	var said := Label.new()
	said.text = "Steps:"
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_steps_row.add_child(said)
	_size_child(said)
	for n: int in mini(hits.size(), STEPS_SHOWN):
		var hit: Array = hits[n]
		var index: int = int(hit[0])
		var button: Button = _button(str(name_of.call(index)) + (" ×%d" % int(hit[1]) if int(hit[1]) > 1 else ""),
			"Go to step %s" % name_of.call(index))
		button.toggle_mode = true
		button.button_pressed = index == at
		button.set_meta("step", index)
		# A step built already, dimmed: the others are still to come.
		if index < at or (int(read["step"]) >= 0 and index < int(read["step"])):
			button.modulate = Color(1, 1, 1, 0.55)
		var bricks: Dictionary = hit[2]
		button.pressed.connect(func() -> void:
			for other: Button in _step_buttons:
				other.set_pressed_no_signal(other == button)
			_offer_back(index)
			place_wanted.emit(index, bricks))
		_steps_row.add_child(button)
		_size_child(button)
		_step_buttons.append(button)
	if hits.size() > STEPS_SHOWN:
		var more := Label.new()
		more.text = "+%d" % (hits.size() - STEPS_SHOWN)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_steps_row.add_child(more)
		_size_child(more)


func _lay_others(read: Dictionary) -> void:
	var options: Array = read["options"]
	var picked: int = int(read["picked"])
	for child: Node in _others_row.get_children():
		_others_row.remove_child(child)
		child.queue_free()
	_other_buttons.clear()
	var offered: int = 0
	for n: int in options.size():
		if n != picked and bool(options[n]["in_model"]):
			offered += 1
	_others_row.visible = offered > 0
	if offered == 0:
		return
	var said := Label.new()
	said.text = "Not it?"
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_others_row.add_child(said)
	_size_child(said)
	for n: int in options.size():
		if n == picked or not bool(options[n]["in_model"]):
			continue
		var name_said: String = str(options[n]["name"])
		var button: Button = _button(name_said, "Brickognize is %d%% sure of it" % roundi(
			float(options[n]["score"]) * 100.0))
		Language.keep_name(name_said)
		var chosen: int = n
		button.pressed.connect(func() -> void: option_wanted.emit(chosen))
		_others_row.add_child(button)
		_size_child(button)
		_other_buttons.append(button)


func hide_card() -> void:
	visible = false
	if thumbnails != null:
		thumbnails.watch(self, [] as Array[ThumbTile])


## The card's buttons, for a check to press as a finger does.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = {"partstep_close": _close}
	if _back.visible:
		named["partstep_back"] = _back
	for n: int in _step_buttons.size():
		named["partstep_step_%d" % n] = _step_buttons[n]
	for n: int in _other_buttons.size():
		named["partstep_other_%d" % n] = _other_buttons[n]
	return named


## What the card says, for a check to read.
func card_state() -> Dictionary:
	var steps := PackedStringArray()
	for button: Button in _step_buttons:
		steps.append(button.text)
	var others := PackedStringArray()
	for button: Button in _other_buttons:
		others.append(button.text)
	return {"shown": visible, "title": _title.text, "where": _where.text if _where.visible else "",
		"steps": steps, "others": others, "back": _back.text if _back.visible else "", "step": int(answer.get("step", -1)) if not answer.is_empty() else -1,
		"part": str(answer["options"][int(answer["picked"])]["parts"][0]) if not answer.is_empty()
			and int(answer["picked"]) >= 0 else "",
		"colour": int(answer.get("colour", -1)) if not answer.is_empty() else -1,
		"options": (answer.get("options", []) as Array).map(func(one: Dictionary) -> String:
			return str(one["part"]) if not str(one["part"]).is_empty() else str(one["bricklink"]))}
