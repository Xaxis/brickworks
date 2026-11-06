## Edit, Pattern…'s grid for a session (APP_UX4, grid): copies of the parts a
## session names, in columns along x, rows along z and levels up, in one
## call, as the window's In a grid lays them.
##
## A session laid a block of copies a part at a time: 23 copies of a 2 x 2
## brick were 23 places worked out by hand, or a row of rows of rows. The
## person does it in one dialog (PatternDialog), and the owner builds through
## their own Claude, so a session gets the same: the same layout
## (Pattern.grid over Pattern.grid_places), each copy checked for room by the
## same rule (Pattern.check, Builder.room_for), put down as one undo step
## (Pattern.put), and a copy with no room said by its column, row and level,
## as the dialog says it, with the number of the part in its way. The
## person's selection is left as it was, as the window's other hand tools
## leave it for a session (HandTools). A row is a grid of one row and one
## level.
##
## A tool of AppTools, served wherever the app's tools are: the desktop's MCP
## port, My Claude and the connector.
class_name PatternTool
extends RefCounted

const NAME := "pattern_parts"
const STUD := 20.0
const PLATE := 8.0

var app: Node
## The copies the last call put down, for its answer's picture
## (SeeTools.pictured); empty when it put none.
var changed: PackedInt64Array = PackedInt64Array()


static func definition() -> Dictionary:
	return {
		"name": NAME,
		"description": ("Lay copies of parts in a grid, as the window's Edit, Pattern…, In "
			+ "a grid does: columns along x, rows along z and levels up, each count with the "
			+ "parts given as the first (columns=4 rows=3 levels=2 is 24 in all, 23 copies). "
			+ "column_studs= and row_studs= how far apart, in studs (a whole or half number), "
			+ "and level_plates= in plates (9 is 3 bricks); each, when not given, the parts' "
			+ "own size that way, so copies touch (a 2 x 2 brick: 2, 2 and 3). Negative goes "
			+ "the other way. A row is one row and one level. Every copy is checked for room "
			+ "against the model and the copies before it; all or nothing, one undo step, "
			+ "and a copy with no room is said by its column, row and level and what is in "
			+ "its way. bricks= the parts, by their numbers in look_at_model."),
		"input_schema": {"type": "object", "additionalProperties": false,
			"required": ["bricks"], "properties": {
				"bricks": {"type": "array", "items": {"type": "integer"},
					"description": "the parts, by their numbers in look_at_model"},
				"columns": {"type": "integer",
					"description": "along x, counting the parts given; 1 when not given"},
				"rows": {"type": "integer",
					"description": "along z, counting the parts given; 1 when not given"},
				"levels": {"type": "integer",
					"description": "up, counting the parts given; 1 when not given"},
				"column_studs": {"type": "number", "description": "studs between columns"},
				"row_studs": {"type": "number", "description": "studs between rows"},
				"level_plates": {"type": "integer", "description": "plates between levels"},
				"picture": {"type": "boolean", "description": ("unset: a close look at the "
					+ "copies, edged in magenta; true: the whole model so; false: words alone")},
			}},
	}


## A coroutine-free call: what was put down, or why nothing was.
func run(input: Dictionary) -> String:
	changed = PackedInt64Array()
	var shell: Shell = app.get("_shell")
	var pattern: Pattern = shell.pattern_dialog.pattern \
		if shell != null and shell.pattern_dialog != null else null
	if pattern == null:
		return "This app has no Pattern."
	var builder: Builder = app.get("_builder")
	var world: BrickWorld = app.get("_world")
	var ids: Variant = _named(input)
	if ids is String:
		return ids
	var counts: Array[int] = []
	for key: String in ["columns", "rows", "levels"]:
		var raw: Variant = input.get(key, 1)
		if not (raw is int or raw is float) or float(raw) != floorf(float(raw)) or int(raw) < 1:
			return "%s= is a whole number, 1 or more, counting the parts given; nothing changed." \
				% key
		counts.append(int(raw))
	if counts[0] * counts[1] * counts[2] < 2:
		return ("Give columns=, rows= or levels= more than 1: 1 of each is the parts alone. "
			+ "Nothing changed.")
	var box: AABB = builder._bounds_of(PackedInt64Array(ids), Transform3D.IDENTITY)
	var apart: Array[float] = []
	for way: int in 3:
		var key: String = ["column_studs", "row_studs", "level_plates"][way]
		var value: float = float(input.get(key, Pattern.own_spacing(box, way)))
		if way < 2 and not is_equal_approx(value * 2.0, roundf(value * 2.0)):
			return ("%s= is in studs, a whole or half number, so studs land on studs: %s is "
				% [key, _n(value)] + "neither. Nothing changed.")
		if way == 2 and not is_equal_approx(value, roundf(value)):
			return ("level_plates= is a whole number of plates (3 a brick): %s is not. "
				% _n(value) + "Nothing changed.")
		apart.append(value)
	var places: Array[Vector3i] = Pattern.grid_places(counts[0], counts[1], counts[2])
	var moves: Array[Transform3D] = Pattern.grid(Vector3(apart[0] * STUD, 0, 0),
		Vector3(0, 0, apart[1] * STUD), Vector3(0, apart[2] * PLATE, 0), places)
	var laid: String = _laid(counts, apart)
	# Put down as the window puts it, the person's selection kept: Pattern.put
	# selects the copies, as a person who just made them wants.
	var theirs: Dictionary = builder.selection.duplicate()
	var made: PackedInt64Array = pattern.put(ids, moves, "a grid of %d copies" % moves.size())
	builder.selection.clear()
	for brick_id: Variant in theirs:
		builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	if made.is_empty():
		var why: String = pattern.refusal(ids, moves, places)
		var blocker: BrickWorld.Brick = world.get_brick(pattern.blocker) \
			if pattern.blocker > 0 else null
		if blocker != null:
			why += " (#%d)" % blocker.id
		return ("Not put down (%s): %s. Nothing changed: give a wider spacing, fewer copies, or "
			% [laid, why] + "move what is in the way.")
	changed = made
	var verbs: EditVerbs = app.get("_verbs")
	if verbs != null and verbs.edited.is_valid():
		verbs.edited.call()
	var copied: int = (ids as Array).size()
	return ("Put down a grid of %d in all, %s: %d copies of %s, %s. One undo step."
		% [counts[0] * counts[1] * counts[2], laid, moves.size(),
			"1 part" if copied == 1 else "%d parts" % copied, HandTools._numbers(made)])


## The grid in words: "4 columns 3 studs apart, 3 rows 3 studs apart, 2 levels
## 9 plates (3 bricks) apart".
static func _laid(counts: Array[int], apart: Array[float]) -> String:
	var said := PackedStringArray()
	var named: Array = [["column", "studs"], ["row", "studs"], ["level", "plates"]]
	for way: int in 3:
		if counts[way] == 1:
			said.append("1 %s" % named[way][0])
			continue
		var gap: String = "%s %s" % [_n(apart[way]), named[way][1]]
		if way == 2 and roundi(apart[2]) % 3 == 0 and roundi(apart[2]) != 0:
			gap += " (%d brick%s)" % [roundi(apart[2]) / 3, "" if absi(roundi(apart[2])) == 3 else "s"]
		said.append("%d %ss %s apart" % [counts[way], named[way][0], gap])
	return ", ".join(said)


func _named(input: Dictionary) -> Variant:
	var given: Variant = input.get("bricks", [])
	if not given is Array or (given as Array).is_empty():
		return "Give bricks= the parts' numbers, from look_at_model."
	var world: BrickWorld = app.get("_world")
	var store: ModelStore = app.get("_store")
	var ids: Array = []
	var unknown := PackedStringArray()
	for raw: Variant in given:
		var number: int = int(raw)
		if store.scenery.has(number) or world.get_brick(number) == null:
			unknown.append(str(number))
		elif not ids.has(number):
			ids.append(number)
	if not unknown.is_empty():
		return "No part numbered %s (look_at_model numbers them); nothing changed." \
			% ", ".join(unknown)
	return ids


static func _n(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
