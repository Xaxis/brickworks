## Edit, Pattern…: copies of the selection in a row along an axis, round
## what it stands on or hangs from, or along a hose, shown where they will
## go as the numbers change, each checked for room, and put down as one
## step to undo (Pattern; docs/APP_UX.md, B6). Fusion's and Onshape's
## linear and circular patterns; a row is also "5x" typed after a copy
## (EditVerbs).
##
## "In all" counts the selection: a fence of 12 posts is 12, from one post.
## A ring's turn is the whole way round shared out, until one is typed.
class_name PatternDialog
extends AcceptDialog

var builder: Builder
var world: BrickWorld
var library: PartLibrary
var say: Callable = func(_line: String) -> void: pass
var edited: Callable = func() -> void: pass

## Lays the copies out and shows them: Shell puts it in the model's world.
var pattern := Pattern.new()
## "row", "round" or "path".
var kind: String = "row"

const KINDS: Array = [["row", "In a row"], ["round", "Round"], ["path", "Along a hose"]]
const AXES: Array = [["x", Vector3.RIGHT], ["z", Vector3.BACK], ["up", Vector3.UP]]
const MOST := Pattern.MOST_COPIES + 1

var _ids: Array = []
var _kinds: Dictionary = {}
var _count: SpinBox
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
	column.add_child(_line("In all", _count, "counting the selection"))

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

	for field: SpinBox in [_count, _every, _degrees, _spacing]:
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
		else "Lay a hose first: Build, Hose, tube or chain…"
	if kind == "path" and not hoses:
		kind = "row"
	_every.value = _own_size()
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
	_round.visible = which == "round"
	_path.visible = which == "path"
	reset_size()
	_refresh()
	# The count next: a kind chosen, then its number typed.
	_count.get_line_edit().grab_focus()
	_count.get_line_edit().select_all()


func _turn_round() -> void:
	var was: bool = _filling
	_filling = true
	_degrees.value = 360.0 / maxf(_count.value, 1.0)
	_filling = was


## The selection's size along the chosen axis: studs, or plates up.
func _own_size() -> float:
	var box: AABB = _box()
	var axis: int = _axis.selected
	if axis == 2:
		return maxf(1.0, roundf(box.size.y / BrickLattice.PLATE))
	var wide: float = box.size.x if axis == 0 else box.size.z
	return maxf(1.0, snappedf(wide / BrickLattice.STUD, 0.5))


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


## What they are, in words.
func words() -> String:
	var copies: int = int(_count.value) - 1
	match kind:
		"round":
			return "%d copies, each %s° further round %s" % [copies, _num(_degrees.value),
				_centre.get_item_text(_centre.selected)]
		"path":
			return "%d copies, %s studs apart along %s" % [copies, _num(_spacing.value),
				_hose.get_item_text(_hose.selected)]
	return "%d copies, each %s %s along %s" % [copies, _num(absf(_every.value)),
		_unit.text, AXES[_axis.selected][0] + (" back" if _every.value < 0 else "")]


## 2, not 2.0; 22.5 and 13.85 as they are.
static func _num(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) \
		else String.num(snappedf(value, 0.01), 2)


func _refresh() -> void:
	if _filling or _ids.is_empty():
		return
	_unit.text = "plates" if _axis.selected == 2 else "studs"
	var laid: Array[Transform3D] = moves()
	var copies: int = int(_count.value) - 1
	var why: String = pattern.show_copies(_ids, laid)
	if why.is_empty() and laid.size() < copies:
		why = "only %d fit along it" % laid.size()
	get_ok_button().disabled = not why.is_empty()
	_said.text = words() + (" — " + why if not why.is_empty() else ": each has room")
	_said.add_theme_color_override("font_color", TypedEntry.REFUSED if not why.is_empty()
		else TypedEntry.SAID)


func _put() -> void:
	var laid: Array[Transform3D] = moves()
	var said: String = words()
	var made: PackedInt64Array = pattern.put(_ids, laid, "a pattern of %d copies" % laid.size())
	if made.is_empty():
		say.call("no room for them all: %s" % pattern.refusal(_ids, laid))
		return
	edited.call()
	say.call("%s — one Ctrl+Z takes them all back" % said)


## What a probe reads: the kind, the count, the words said, and whether OK
## may be pressed.
func page_state() -> Dictionary:
	return {"open": visible, "kind": kind, "in_all": int(_count.value),
		"said": _said.text if _said != null else "",
		"can_put": not get_ok_button().disabled, "copies": moves().size()}


## The controls a probe presses: each kind's button, the count's field, OK.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {"pattern_count": _count.get_line_edit(), "pattern_ok": get_ok_button()}
	for each: String in _kinds:
		out["pattern_" + each] = _kinds[each]
	return out
