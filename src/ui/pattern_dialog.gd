## Edit, Pattern…: copies of the selection in a row along an axis, in a grid
## of columns, rows and levels, round what it stands on or hangs from, or
## along a hose, shown where they will go as the numbers change, each checked
## for room, and put down as one step to undo (Pattern; docs/APP_UX.md, B6).
## Fusion's and Onshape's linear and circular patterns, and LeoCAD's Array
## for the grid (docs/APP_UX4.md, grid): a block of 4 by 3 by 2 is one
## dialog, not a row copied in a row; a row is also "5x" typed after a copy
## (EditVerbs).
##
## "In all" counts the selection: a fence of 12 posts is 12, from one post,
## and a grid's columns, rows and levels count the column, row and level it
## stands in. A ring's turn is the whole way round shared out, until one is
## typed.
class_name PatternDialog
extends AcceptDialog

var builder: Builder
var world: BrickWorld
var library: PartLibrary
var say: Callable = func(_line: String) -> void: pass
var edited: Callable = func() -> void: pass

## Lays the copies out and shows them: Shell puts it in the model's world.
var pattern := Pattern.new()
## "row", "grid", "round" or "path".
var kind: String = "row"

const KINDS: Array = [["row", "In a row"], ["grid", "In a grid"], ["round", "Round"],
	["path", "Along a hose"]]
## A grid's three ways: [its count's words, the unit after its spacing, the
## way it goes, whether it is up (plates) rather than across (studs)].
const GRID_WAYS: Array = [["Columns", "studs along x", Vector3.RIGHT, false],
	["Rows", "studs along z", Vector3.BACK, false], ["Levels", "plates up", Vector3.UP, true]]
const AXES: Array = [["x", Vector3.RIGHT], ["z", Vector3.BACK], ["up", Vector3.UP]]
const MOST := Pattern.MOST_COPIES + 1

var _ids: Array = []
var _kinds: Dictionary = {}
var _count: SpinBox
## The "In all" line, which a grid's own counts stand in for.
var _in_all: Control
var _row: Control
var _axis: OptionButton
var _every: SpinBox
var _unit: Label
var _round: Control
var _centre: OptionButton
var _degrees: SpinBox
## Whether the turn is the whole way round shared out, kept so as the count
## changes: until a turn is typed.
var _all_round: bool = true
var _path: Control
var _hose: OptionButton
var _spacing: SpinBox
## A grid's counts and spacings, a pair a way (GRID_WAYS).
var _grid: Control
var _grid_counts: Array[SpinBox] = []
var _grid_every: Array[SpinBox] = []
var _said: Label
var _centres: Array = []
var _hoses: Array = []
var _filling: bool = false


func _init() -> void:
	title = "Pattern"
	ok_button_text = "Put them down"
	add_cancel_button("Cancel")
	pattern.keep = func() -> bool: return visible
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(400, 0)
	add_child(column)

	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for each: Array in KINDS:
		var button := Button.new()
		button.text = each[1]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_choose.bind(str(each[0])))
		kinds.add_child(button)
		_kinds[each[0]] = button
	column.add_child(kinds)

	# From 1, so a count typed over the last starts as it is typed: "16"
	# went in as 2 then 26, the 1 held up to a least of 2.
	_count = _spin(1, MOST, 1, "In all, the selection counted")
	_count.value = 4
	_in_all = _line("In all", _count, "counting the selection")
	column.add_child(_in_all)

	_axis = OptionButton.new()
	_axis.accessibility_name = "Along"
	for each: Array in AXES:
		_axis.add_item(str(each[0]))
	_axis.item_selected.connect(func(_n: int) -> void:
		_every.value = _own_size()
		_refresh())
	_every = _spin(-100, 100, 0.5, "Every")
	_unit = Label.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label("Along"))
	row.add_child(_axis)
	row.add_child(_label("every"))
	row.add_child(_every)
	row.add_child(_unit)
	_row = row
	column.add_child(row)

	_centre = OptionButton.new()
	_centre.accessibility_name = "Round"
	_centre.item_selected.connect(func(_n: int) -> void: _refresh())
	_degrees = _spin(0.01, 360, 0.01, "Each turn, degrees")
	_degrees.value_changed.connect(func(_v: float) -> void:
		if not _filling:
			_all_round = false)
	var round_box := VBoxContainer.new()
	round_box.add_child(_line("Round", _centre, ""))
	round_box.add_child(_line("Each turn", _degrees, "degrees"))
	_round = round_box
	column.add_child(round_box)

	# Columns along x, rows along z, levels up: each a count, from the one
	# the selection stands in, and how far apart, as the row has it.
	var grid_box := VBoxContainer.new()
	for way: Array in GRID_WAYS:
		var count: SpinBox = _spin(1, MOST, 1, str(way[0]))
		count.value = 2
		var every: SpinBox = _spin(-100, 100, 1.0 if bool(way[3]) else 0.5,
			"%s, every so many %s" % [way[0], way[1]])
		var line: HBoxContainer = _line(str(way[0]), count, "")
		line.add_child(_label("every"))
		line.add_child(every)
		line.add_child(_label(str(way[1])))
		grid_box.add_child(line)
		_grid_counts.append(count)
		_grid_every.append(every)
	_grid = grid_box
	column.add_child(grid_box)

	_hose = OptionButton.new()
	_hose.accessibility_name = "Hose"
	_hose.item_selected.connect(func(_n: int) -> void: _refresh())
	_spacing = _spin(0.5, 100, 0.5, "Every, studs along the hose")
	_spacing.value = 2
	var path_box := VBoxContainer.new()
	path_box.add_child(_line("Along", _hose, ""))
	path_box.add_child(_line("Every", _spacing, "studs"))
	_path = path_box
	column.add_child(path_box)

	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.custom_minimum_size = Vector2(400, 0)
	column.add_child(_said)

	for field: SpinBox in [_count, _every, _degrees, _spacing] + _grid_counts + _grid_every:
		register_text_enter(field.get_line_edit())
		field.value_changed.connect(func(_v: float) -> void:
			if not _filling:
				if field == _count and _all_round:
					_turn_round()
				_refresh())
	confirmed.connect(_put)
	visibility_changed.connect(func() -> void:
		if not visible:
			pattern.hide_copies())


func _spin(least: float, most: float, step: float, named: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = least
	spin.max_value = most
	spin.step = step
	spin.allow_greater = false
	spin.update_on_text_changed = true
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(96, 0)
	spin.accessibility_name = named
	return spin


func _label(words: String) -> Label:
	var label := Label.new()
	label.text = words
	return label


func _line(words: String, field: Control, after: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var label: Label = _label(words)
	label.custom_minimum_size = Vector2(76, 0)
	line.add_child(label)
	line.add_child(field)
	if not after.is_empty():
		line.add_child(_label(after))
	return line


## Copies of these parts: the dialog filled for them, shown, and the copies
## drawn where they will go.
func open(ids: Array) -> void:
	_ids = ids.duplicate()
	_filling = true
	_centres = pattern.centres(_ids)
	_centre.clear()
	for each: Dictionary in _centres:
		_centre.add_item(str(each["words"]))
	_hoses = _hoses_in()
	_hose.clear()
	for each: Dictionary in _hoses:
		_hose.add_item(str(each["words"]))
	var hoses: bool = not _hoses.is_empty()
	(_kinds["path"] as Button).disabled = not hoses
	(_kinds["path"] as Button).tooltip_text = "" if hoses \
		else Keymap.filled("Lay a hose first: {flex}")
	if kind == "path" and not hoses:
		kind = "row"
	_every.value = _own_size()
	for way: int in GRID_WAYS.size():
		_grid_every[way].value = _size_along(way)
	_all_round = true
	_turn_round()
	_filling = false
	popup_centered()
	# Over the right-hand column rather than the model's middle, where the
	# copies are drawn as the numbers change.
	var room: Vector2 = get_parent().get_viewport().get_visible_rect().size
	position = Vector2i(maxi(0, int(room.x) - size.x - 16), mini(72, maxi(0, int(room.y) - size.y)))
	_choose(kind)


## Whether a probe or a person can see it.
func is_open() -> bool:
	return visible


func _choose(which: String) -> void:
	kind = which
	(_kinds[which] as Button).set_pressed_no_signal(true)
	_row.visible = which == "row"
	_grid.visible = which == "grid"
	_in_all.visible = which != "grid"
	_round.visible = which == "round"
	_path.visible = which == "path"
	reset_size()
	_refresh()
	# The count next: a kind chosen, then its number typed; a grid's
	# columns first, then Tab to each field after.
	var first: SpinBox = _grid_counts[0] if which == "grid" else _count
	first.get_line_edit().grab_focus()
	first.get_line_edit().select_all()


func _turn_round() -> void:
	var was: bool = _filling
	_filling = true
	_degrees.value = 360.0 / maxf(_count.value, 1.0)
	_filling = was


## The selection's size along the chosen axis: studs, or plates up.
func _own_size() -> float:
	return _size_along(_axis.selected)


## The selection's size along x (0), z (1) or up (2): studs, or plates up.
## A grid's copies start this far apart, touching, as a row's do.
func _size_along(axis: int) -> float:
	return Pattern.own_spacing(_box(), axis)


func _box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in _ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return box


## Each hose, tube or chain in the model: {words, points} along its middle.
func _hoses_in() -> Array:
	var out: Array = []
	var middle: Vector3 = _box().get_center()
	var items: Dictionary = Flex.items_in(world)
	for path: String in items:
		var item: Dictionary = items[path]
		var pieces: Array = []
		for brick: BrickWorld.Brick in item["bricks"]:
			pieces.append({"part": brick.part_id, "at": brick.transform})
		var line: PackedVector3Array = Flex.centreline(str(item["kind"]), pieces, middle)
		if line.size() < 2:
			continue
		var spec: Dictionary = Flex.KINDS.get(str(item["kind"]), {})
		out.append({"words": path.get_slice("#", 0) if not path.is_empty()
			else str(spec.get("label", "the hose")), "points": line})
	return out


## The copies, as moves: one fewer than "In all".
func moves() -> Array[Transform3D]:
	var copies: int = int(_count.value) - 1
	match kind:
		"grid":
			var by: Array[Vector3] = []
			for way: int in GRID_WAYS.size():
				by.append(GRID_WAYS[way][2] * _grid_every[way].value
					* (BrickLattice.PLATE if bool(GRID_WAYS[way][3]) else BrickLattice.STUD))
			return Pattern.grid(by[0], by[1], by[2], places())
		"round":
			if _centre.selected < 0 or _centre.selected >= _centres.size():
				return []
			var about: Dictionary = _centres[_centre.selected]
			return Pattern.ring(about["point"], about["axis"], _degrees.value, copies)
		"path":
			if _hose.selected < 0 or _hose.selected >= _hoses.size():
				return []
			return Pattern.along(_hoses[_hose.selected]["points"], _box().get_center(),
				_spacing.value * BrickLattice.STUD, copies)
	var unit: float = BrickLattice.PLATE if _axis.selected == 2 else BrickLattice.STUD
	return Pattern.row(AXES[_axis.selected][1] * _every.value * unit, copies)


## A grid's places, one a copy (Pattern.grid_places); none for another kind.
func places() -> Array[Vector3i]:
	if kind != "grid":
		return []
	return Pattern.grid_places(int(_grid_counts[0].value), int(_grid_counts[1].value),
		int(_grid_counts[2].value))


## How many there are to be, the selection counted: "In all", or a grid's
## columns by rows by levels.
func in_all() -> int:
	if kind == "grid":
		return int(_grid_counts[0].value) * int(_grid_counts[1].value) \
			* int(_grid_counts[2].value)
	return int(_count.value)


## What they are, in words.
func words() -> String:
	var copies: int = in_all() - 1
	match kind:
		"grid":
			# A part a way, joined by " · " so each is found in a language's
			# words on its own: "23 copies · 4 columns 3 studs apart · ...".
			var said := PackedStringArray(["1 copy" if copies == 1 else "%d copies" % copies])
			var named: Array = [["1 column", "%d columns %s apart"], ["1 row", "%d rows %s apart"],
				["1 level", "%d levels %s apart"]]
			for way: int in GRID_WAYS.size():
				var count: int = int(_grid_counts[way].value)
				said.append(str(named[way][0]) if count == 1 else str(named[way][1]) % [count,
					_apart(_grid_every[way].value, bool(GRID_WAYS[way][3]))])
			return " · ".join(said)
		"round":
			return "%d copies, each %s° further round %s" % [copies, _num(_degrees.value),
				_centre.get_item_text(_centre.selected)]
		"path":
			return "%d copies, %s studs apart along %s" % [copies, _num(_spacing.value),
				_hose.get_item_text(_hose.selected)]
	return "%d copies, each %s %s along %s" % [copies, _num(absf(_every.value)),
		_unit.text, AXES[_axis.selected][0] + (" back" if _every.value < 0 else "")]


## A grid's spacing in a builder's words: "3 studs", "1 stud"; up, "3
## bricks" for 9 plates, "1 plate", "4 plates".
static func _apart(value: float, up: bool) -> String:
	if up:
		var plates: int = roundi(value)
		if plates != 0 and plates % 3 == 0:
			return "1 brick" if plates == 3 else "%d bricks" % (plates / 3)
		return "1 plate" if plates == 1 else "%d plates" % plates
	return "1 stud" if is_equal_approx(value, 1.0) else "%s studs" % _num(value)


## 2, not 2.0; 22.5 and 13.85 as they are.
static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) \
		else String.num(snappedf(value, 0.01), 2)


func _refresh() -> void:
	if _filling or _ids.is_empty():
		return
	_unit.text = "plates" if _axis.selected == 2 else "studs"
	var laid: Array[Transform3D] = moves()
	var copies: int = in_all() - 1
	var why: String = pattern.show_copies(_ids, laid, places())
	if why.is_empty() and laid.size() < copies and kind != "grid":
		why = "only %d fit along it" % laid.size()
	get_ok_button().disabled = not why.is_empty()
	# A grid's words are parts joined by " · ", and its room one more.
	var room: String = " · each has room" if kind == "grid" else ": each has room"
	_said.text = words() + (" — " + why if not why.is_empty() else room)
	_said.add_theme_color_override("font_color", TypedEntry.REFUSED if not why.is_empty()
		else TypedEntry.SAID)


func _put() -> void:
	var laid: Array[Transform3D] = moves()
	var said: String = words()
	var made: PackedInt64Array = pattern.put(_ids, laid, ("a grid of %d copies" if kind == "grid"
		else "a pattern of %d copies") % laid.size())
	if made.is_empty():
		say.call("no room for them all: %s" % pattern.refusal(_ids, laid, places()))
		return
	edited.call()
	say.call(Keymap.filled("%s — one {undo} takes them all back") % said)


## What a probe reads: the kind, the count, the words said, and whether OK
## may be pressed.
func page_state() -> Dictionary:
	return {"open": visible, "kind": kind, "in_all": in_all(),
		"said": _said.text if _said != null else "",
		"can_put": not get_ok_button().disabled, "copies": moves().size()}


## The controls a probe presses: each kind's button, the count's field, a
## grid's fields (pattern_columns, pattern_columns_every, ...), OK.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {"pattern_count": _count.get_line_edit(), "pattern_ok": get_ok_button()}
	for each: String in _kinds:
		out["pattern_" + each] = _kinds[each]
	for way: int in GRID_WAYS.size():
		var named: String = "pattern_" + str(GRID_WAYS[way][0]).to_lower()
		out[named] = _grid_counts[way].get_line_edit()
		out[named + "_every"] = _grid_every[way].get_line_edit()
	return out
