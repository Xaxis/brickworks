## A part clicked onto a stud seats on that stud whichever way it is turned,
## and a part a real set puts on a stud is seated exactly there (seatfix,
## docs/APP_UX7.md #9).
##
##   godot --headless --path . --script src/dev/seatfix_probe.gd
##
## By hand: a 4740 dish held at each quarter turn and clicked onto a lone 6141
## round plate's stud, as a person puts one from the bin (the pointer's line
## aimed at the stud, Builder.update_preview, Builder.place). Said, not yet
## a check ("open"): the hand takes a part's stud places from its shape's
## holes pointing down (Builder._takes_studs), and the dish's only one is a
## tube, so it goes by the catalogue's corner sockets, 14 LDU off the stud,
## where the check refuses it. The line turns "ok" when the hand reads the
## tube; that change is Builder's, and with it this line becomes a check.
##
## Over MCP: the same dish sent at each quarter turn, by number where 31038-1,
## 41015-1 and 42022-1 put it (4 LDU over the plate), and attached by its
## tube to the plate's stud (submit_design): on the stud's line, the one at
## the sets' height, and each built and passed.
##
## Real sub-models: 42088-1's rear lights, 42105-1's cabin, 6542-1's road
## lights and 10297-1's desk and chair, read from the sets' own files
## (vendor/omr/files) and written as a session writes them, as harvest_probe
## does: every part by the 2 LDU cell its corner is in, in studs and plates.
## Checked like a design, each builds, and the check's seat leaves every part
## where its set has it, to 0.005 LDU.
extends SceneTree

const SETS := "res://vendor/omr/files/"
## [set file, sub-model] each, as tools/omr.py harvest takes them.
const SUBMODELS: Array = [
	["42088-1_Tow-Truck.mpd", "42088 - Rear Lights.ldr"],
	["42105-1_Race-Power-Boat.mpd", "42105 - cabin.ldr"],
	["6542-1.mpd", "6542 - road lights.ldr"],
	["10297-1.mpd", "10297 - desk2.ldr"],
	["10297-1.mpd", "10297 - chair2.ldr"],
]
## How near where its set has it a part has to be, in LDU.
const AT_ITS_PLACE := 0.005
## Where the sets put a 4740 over a 6141: its origin 4 LDU over the plate's.
const DISH_UP := 4.0

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore
var _failures: int = 0


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	_dish_by_hand()
	await _dish_over_mcp()
	if not DirAccess.dir_exists_absolute(SETS):
		print("no %s: tools/omr.py fetch brings the sets" % SETS)
		quit(1)
		return
	for one: Array in SUBMODELS:
		await _submodel(str(one[0]), str(one[1]))
	print("")
	print("%s" % ("every check passed" if _failures == 0 else "%d check%s failed" % [
		_failures, "" if _failures == 1 else "s"]))
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _clear() -> void:
	for brick: BrickWorld.Brick in _world.bricks():
		_builder.lattice.release(brick.id)
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()


## What check_design says of the model as it stands, every brick counted as
## new, so nothing is excused as already standing.
func _design_says() -> String:
	var model: Assistant.Model = _assistant._model_from_world()
	for placement: Assistant.Placement in model.placements:
		placement.id = 0
	return str(_assistant._check(model, true).get("feedback", "")).replace("\n", " / ")


func _brick_of(part: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick
	return null


## A 6141 on the floor and a 4740 held at each quarter turn, aimed straight
## down at the plate's stud and clicked: on the stud's line, and passed.
func _dish_by_hand() -> void:
	print("\na 4740 dish clicked onto a 6141 round plate's stud, at each quarter turn")
	var under: Lbm.PartMesh = _library.mesh_for("6141")
	var at := Transform3D(Basis.IDENTITY, -under.bounds.position)
	for turn: int in 4:
		_clear()
		_builder.put_part("6141", 4, at)
		var aim: Vector3 = at.origin + Vector3(0, under.bounds.end.y, 0)
		var from: Vector3 = aim + Vector3(0, 300, 0)
		_builder.held_part = "4740"
		_builder.held_color = 15
		_builder.held_face = "up"
		_builder.held_rotation = turn
		_builder.update_preview(from, (aim - from).normalized())
		var put: int = _builder.place()
		var dish: BrickWorld.Brick = _world.get_brick(put) if put != 0 else null
		var off: Vector3 = dish.transform.origin - at.origin if dish != null else Vector3.INF
		var across: float = Vector2(off.x, off.z).length()
		var said: String = _design_says()
		var seated: bool = dish != null and across <= AT_ITS_PLACE \
			and said.begins_with("2 bricks, buildable")
		print("  %s  turned %d: %s, %.2f LDU off the stud's line, %.2f LDU up: %s" % [
			"ok  " if seated else "open", turn, "placed" if dish != null else "not placed",
			across, off.y, said.left(140)])


## The dish sent by a session at each quarter turn: by number where the sets
## put it, and attached by its tube to the plate's stud.
func _dish_over_mcp() -> void:
	print("\nthe same over MCP (submit_design), by number where the sets put it and attached")
	for turn: int in 4:
		for how: String in ["by number", "attached"]:
			_clear()
			_assistant.forget_built()
			var dish: Dictionary = {"part": "4740", "color": 15, "rot": turn}
			if how == "attached":
				dish["attach"] = {"to": "base.stud[0]", "by": "tube[0]", "yaw": 90 * turn}
			else:
				dish.merge({"x": -0.5, "y": DISH_UP / Assistant.PLATE, "z": -0.5})
			var sent: Variant = await _assistant.use_tool("submit_design", {"name": "dish",
				"bricks": [{"part": "6141", "color": 4, "x": 0, "y": 0, "z": 0, "name": "base"},
					dish]})
			var text: String = (str(sent) if sent is String else JSON.stringify(sent)) \
				.replace("\n", " / ")
			var base: BrickWorld.Brick = _brick_of("6141")
			var top: BrickWorld.Brick = _brick_of("4740")
			var off: Vector3 = top.transform.origin - base.transform.origin \
				if base != null and top != null else Vector3.INF
			var across: float = Vector2(off.x, off.z).length()
			var said: String = _design_says()
			var height: bool = how == "attached" or absf(off.y - DISH_UP) <= AT_ITS_PLACE
			_ok(across <= AT_ITS_PLACE and height and said.begins_with("2 bricks, buildable")
				and not text.contains("overlap") and not text.contains("passes")
				and not text.contains("not held") and not text.contains("float"),
				"turned %d, %s: %.2f LDU off the stud's line, %.2f LDU up%s; %s; %s" % [turn,
					how, across, off.y, " (the sets' %.0f)" % DISH_UP if how == "by number"
						else "", said.left(80), text.left(120)])


## A real sub-model, written as a session writes it and checked: it builds,
## and every part is where its set has it.
func _submodel(file: String, name: String) -> void:
	var lines: PackedStringArray = _block(SETS + file, name)
	var path: String = "user://seatfix_submodel.ldr"
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string("0 %s\n%s\n" % [name, "\n".join(lines)])
	out.close()
	_clear()
	var placed: int = _store.open(path)
	for _n: int in 30:
		await process_frame
	# Read back as a design would write it, as harvest_probe does, and where
	# each part stands as its set has it.
	var bricks: Array = []
	var spots: Array = []
	for put: Assistant.Placement in _assistant._model_from_world().placements:
		bricks.append({"part": put.part, "color": put.color, "x": snappedf(put.x, 0.01),
			"y": snappedf(put.y, 0.01), "z": snappedf(put.z, 0.01), "face": put.face,
			"rot": put.rot})
		spots.append(_world.get_brick(put.id).transform)
	var lowest: float = INF
	for raw: Dictionary in bricks:
		lowest = minf(lowest, float(raw["y"]))
	for raw: Dictionary in bricks:
		raw["y"] = snappedf(float(raw["y"]) - lowest, 0.01)
	_clear()
	var model := Assistant.Model.new()
	for raw: Dictionary in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	var written: Array = []
	for placement: Assistant.Placement in model.placements:
		written.append(_assistant._transform(placement, _library.mesh_for(placement.part)).origin)
	var verdict: Dictionary = _assistant._check(model)
	# Where the set has each part, the model moved as a whole as the write
	# moved most of it: a sub-model stood on its lowest cell is written that
	# much under its set's own height, every part alike (42105-1's cabin, 0.909
	# LDU).
	var shifts: Dictionary = {}
	for k: int in model.placements.size():
		var set_at: Vector3 = (spots[k] as Transform3D).origin
		var shift: Vector3 = ((written[k] as Vector3) - set_at).snappedf(0.001)
		shifts[shift] = int(shifts.get(shift, 0)) + 1
	var whole := Vector3.ZERO
	for shift: Vector3 in shifts:
		if int(shifts[shift]) > int(shifts.get(whole, 0)):
			whole = shift
	# Every part written where its set has it stays there; every part the
	# seat moves goes there; none goes further from it than it was written. A
	# part the write puts off its set's place by the cell its corner is in (a
	# bushing an LDU along its axle) and nothing seats is the write's, said.
	# And a part its set's own file stands off the line of the stud it takes,
	# further than BrickNet takes a hole to a stud (Exact.SUNK_ACROSS), goes
	# onto that stud, said: 6542-1 stands its two 6141s 11 and 12 LDU down its
	# 4070 headlight bricks, whose side stud 4070.dat draws 10 down.
	var after_items: Array = []
	var set_items: Array = []
	for k: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[k]
		var shape: Exact.Shape = Exact.shape_for(_library, placement.part)
		after_items.append(Exact.Item.new(shape, _assistant._transform(placement,
			_library.mesh_for(placement.part))) if shape != null else null)
		set_items.append(Exact.Item.new(shape, (spots[k] as Transform3D).translated(whole))
			if shape != null else null)
	var worst: float = 0.0
	var worst_at: String = ""
	var moved: int = 0
	var off_written: PackedStringArray = []
	var off_its_stud: PackedStringArray = []
	for k: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[k]
		var after: Vector3 = (after_items[k] as Exact.Item).at.origin if after_items[k] != null \
			else _assistant._transform(placement, _library.mesh_for(placement.part)).origin
		var set_at: Vector3 = (spots[k] as Transform3D).origin + whole
		var was: float = (written[k] as Vector3).distance_to(set_at)
		var off: float = after.distance_to(set_at)
		var seated: bool = after.distance_to(written[k]) > AT_ITS_PLACE
		if seated:
			moved += 1
		if not seated and was > AT_ITS_PLACE:
			off_written.append("%s %.2f" % [placement.part, was])
			continue
		if seated and off > AT_ITS_PLACE:
			var in_set: Vector2 = _from_a_stud(set_items, k)
			var now: Vector2 = _from_a_stud(after_items, k)
			if in_set.y > Exact.SUNK_ACROSS and now.x <= AT_ITS_PLACE:
				off_its_stud.append("%s (brick %d) %.2f LDU off its stud's line in its set, "
					% [placement.part, k, in_set.y] + "on the stud now (%.2f)" % now.x)
				continue
		if off > worst:
			worst = off
			worst_at = "%s (brick %d) %s from it, written %.2f from it" % [placement.part, k,
				_ldu(after - set_at), was]
	_ok(placed == bricks.size() and bool(verdict["ok"]) and worst <= AT_ITS_PLACE,
		"%s from %s: %s; %d parts, %d seated by the check, the worst %.2f LDU from where its "
			% [name, file, str(verdict["summary"]), bricks.size(), moved, worst]
		+ "set has it%s%s%s" % [": " + worst_at if worst > AT_ITS_PLACE else "",
			"; written off it and left: " + ", ".join(off_written) if not off_written.is_empty()
				else "", "; its set's own off its stud: " + ", ".join(off_its_stud)
				if not off_its_stud.is_empty() else ""])


## How far a hole or tube of item [param i] of [param items] stands from the
## nearest stud of another it could take (pointing the same way, near): [from
## the stud's frame, from the stud's line], LDU; INF for none.
static func _from_a_stud(items: Array, i: int) -> Vector2:
	var best := Vector2(INF, INF)
	var mine: Exact.Item = items[i]
	if mine == null:
		return best
	for one: Array in mine.world():
		if not Exact.takes_on_top(mine.shape, int(one[0])):
			continue
		for j: int in items.size():
			var other: Exact.Item = items[j]
			if j == i or other == null or other.at.origin.distance_to(mine.at.origin) > 120.0:
				continue
			for stud: Array in other.world():
				if other.shape.kind[int(stud[0])] != Exact.STUD \
						or (one[2] as Vector3).dot(stud[2]) < Exact.AXIS_THR:
					continue
				var gap: Vector3 = (one[1] as Vector3) - (stud[1] as Vector3)
				var way: Vector3 = (stud[2] as Vector3).normalized()
				best.x = minf(best.x, gap.length())
				if absf(gap.dot(way)) <= Exact.SUNK_REACH:
					best.y = minf(best.y, (gap - way * gap.dot(way)).length())
	return best


## The part lines of sub-model [param name] in set file [param path].
static func _block(path: String, name: String) -> PackedStringArray:
	var out := PackedStringArray()
	var inside: bool = false
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() >= 2 and words[0] == "0" and words[1] == "FILE":
			if inside:
				break
			inside = " ".join(words.slice(2)) == name
			continue
		if inside and words.size() >= 15 and words[0] == "1":
			out.append(line.strip_edges())
	return out


static func _ldu(v: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [v.x, v.y, v.z]
