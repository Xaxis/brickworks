## Is a dark wall dressed as one structure, never a part at a time?
##
##   godot --headless --path . --script src/dev/dress_probe.gd
##
## The Orthanc on the landing page (run 4) was told by the app's own check
## that 58% of it was plain black, which reads as a hole, and that 559 of its
## 593 pieces of dressing were scattered one by one. The finishing pass had
## turned out the few bricks that started on a column, each carrying its own
## tile, and the check had read the file's prism faces at the nearest square
## turn, every face in one wall. Here: restyle_model lays each wall as one
## structure (panels, ribs, bands, a grid, recessed courses), a dark one in
## panels unasked; an edit that sprinkles dressing over a dark wall is refused
## and told how; a tower written to a file and opened again is read as it
## stands; and the shipped Orthanc, dressed again, is mostly texture.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
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
	await process_frame
	await _panels()
	await _styles()
	await _sprinkled()
	await _read_back()
	await _orthanc()
	print("")
	print("dress probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## A black wall two studs thick, 16 long and 12 courses, bonded as a design
## writes one: courses of 1 x 4s over two rows, then of 2 x 4s.
func _wall(colour: int = 0, long: int = 16, courses: int = 12) -> Array:
	var bricks: Array = []
	for course: int in courses:
		var y: int = 3 * course
		if course % 2 == 0:
			for x: int in range(0, long, 4):
				bricks.append({"part": "3001", "color": colour, "x": x, "y": y, "z": 10,
					"rot": 0})
		else:
			for row: int in 2:
				var x: int = 0 if row == 0 else 2
				if row == 1:
					bricks.append({"part": "3004", "color": colour, "x": 0, "y": y,
						"z": 10 + row, "rot": 0})
				while x + 4 <= long:
					bricks.append({"part": "3010", "color": colour, "x": x, "y": y,
						"z": 10 + row, "rot": 0})
					x += 4
				if row == 1 and x < long:
					bricks.append({"part": "3004", "color": colour, "x": x, "y": y,
						"z": 10 + row, "rot": 0})
	return bricks


func _stand(bricks: Array, name: String = "A wall") -> bool:
	_assistant.forget_built()
	_world.clear()
	_builder.lattice.clear()
	var said: String = _text(await _assistant.use_tool("submit_design", {"name": name,
		"description": "a black wall", "bricks": bricks, "assemblies": []}))
	if said.begins_with("Not applied"):
		print("  could not stand it: %s" % said.substr(0, 300))
		return false
	return true


## What the front of the wall (z 12 and out, looking +z) is made of.
func _front() -> Dictionary:
	var found := {"plain": 0, "texture": 0, "rib": 0, "plates": 0, "round": 0, "other": 0,
		"columns": {}, "rows": {}}
	for placement: Assistant.Placement in _assistant._model_from_world().placements:
		if placement.face != "up":
			if placement.part in ["4073", "6141"] and placement.face == "+z":
				found["plates"] += 1
			continue
		# The outer row: z 11 for a one-wide brick, z 10 for a two-wide one.
		var outer: bool = placement.z >= 10.95 \
			or (Assistant.TWO_WIDE.has(placement.part) and placement.z >= 9.95)
		if not outer:
			continue
		var long: int = int(Patterns.ONE_WIDE.get(placement.part,
			Assistant.TWO_WIDE.get(placement.part, 1)))
		var kind: String = "other"
		if Style.kinds_of(placement.part).contains("p"):
			kind = "plain"
		elif placement.part in ["2877", "98283", "4070", "15533"]:
			kind = "texture"
		elif placement.part == "87087":
			kind = "rib"
			(found["columns"] as Dictionary)[placement.x] = int(
				(found["columns"] as Dictionary).get(placement.x, 0)) + 1
		elif placement.part == "3062b":
			kind = "round"
			(found["rows"] as Dictionary)[placement.y] = int(
				(found["rows"] as Dictionary).get(placement.y, 0)) + 1
		found[kind] += long if kind == "plain" else (2 if placement.part in ["2877", "98283"]
			else 1)
	return found


func _advice() -> String:
	return "\n".join(PackedStringArray(_assistant._check(_assistant._model_from_world(),
		true).get("advice", [])))


## restyle_model on a black wall, told nothing: panels of grille between ribs,
## framed plain, most of its face texture, the check passing it whole.
func _panels() -> void:
	print("  a black wall, restyled unasked")
	if not await _stand(_wall()):
		_check("the wall stands", false)
		return
	var said: String = _text(await _assistant.use_tool("restyle_model", {}))
	var front: Dictionary = _front()
	var studs: int = int(front["plain"]) + int(front["texture"]) + int(front["rib"])
	print("    %s" % said.get_slice("\n", 0))
	print("    its face: %s" % str(front))
	_check("restyle_model lays it in panels: %s" % said.get_slice("\n", 0),
		said.begins_with("Restyled") and said.contains("in panels"))
	_check("...most of its face texture in its own colour: %d of %d studs"
		% [front["texture"], studs], studs > 0 and int(front["texture"]) * 2 > studs)
	var columns: Dictionary = front["columns"]
	# A rib stands in each course of one-wide bricks between the whole courses
	# that tie the face to its back row (course 0, 4 and the top, 11): 1, 3, 5,
	# 7 and 9. In the courses of two-wide bricks it would cut them in two.
	_check("...with ribs up it, in every course of one-wide bricks its panels have: %s"
		% str(columns), columns.size() >= 2 and columns.values().all(
			func(n: int) -> bool: return n == 5))
	_check("...a round plate on each rib stud, %d on %d" % [front["plates"], front["rib"]],
		int(front["plates"]) == int(front["rib"]))
	var advice: String = _advice()
	var report: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_check("...and it holds in one piece: %s, %d" % [report["summary"], report["pieces"]],
		bool(report["ok"]) and int(report.get("pieces", 0)) == 1)
	if int(report.get("pieces", 0)) != 1:
		print(str(report["feedback"]).substr(0, 1500))
	_check("...not called a hole, nor speckle", not advice.contains("reads as a hole")
		and not advice.contains("speckle"))


## Each style on the same wall.
func _styles() -> void:
	print("  each style")
	for style: String in ["ribs", "bands", "grid", "courses"]:
		if not await _stand(_wall()):
			_check("the wall stands", false)
			return
		var said: String = _text(await _assistant.use_tool("restyle_model",
			{"style": style, "face_color": 72}))
		var front: Dictionary = _front()
		var report: Dictionary = _assistant._check(_assistant._model_from_world(), true)
		var ok: bool = bool(report["ok"]) and int(report.get("pieces", 0)) == 1
		match style:
			"ribs":
				var columns: Dictionary = front["columns"]
				ok = ok and columns.size() >= 2 and int(front["texture"]) == 0 \
					and columns.values().all(func(n: int) -> bool: return n == 6)
			"bands":
				ok = ok and int(front["texture"]) > 0 and int(front["rib"]) == 0
			"grid":
				ok = ok and int(front["texture"]) > 0 and int(front["rib"]) > 0
			"courses":
				var rows: Dictionary = front["rows"]
				ok = ok and rows.size() >= 2 \
					and rows.values().all(func(n: int) -> bool: return n >= 14)
		_check("%s: %s; %s, %d piece%s; its face %s" % [style, said.get_slice("\n", 0),
			report["summary"], int(report.get("pieces", 0)),
			"" if int(report.get("pieces", 0)) == 1 else "s", str(front)], ok)
		_check("...and not speckle", not _advice().contains("speckle"))
	_check("a style it has not got is said so",
		_text(await _assistant.use_tool("restyle_model", {"style": "dots"})).begins_with(
			"No style called dots"))


## Dressing laid a part at a time over a dark wall is refused, and told the
## call that lays it as one structure; laid as a column, it is not.
func _sprinkled() -> void:
	print("  dressing a part at a time")
	var bricks: Array = []
	for course: int in 12:
		for x: int in 16:
			# None behind the two ribs stood against the wall below: a side stud
			# there runs 4 LDU into the rib's brick, by the parts' real shapes.
			var side: bool = posmod(x * 5 + course * 3, 7) == 0 and x != 3 and x != 11
			bricks.append({"part": "87087" if side else "3005", "color": 0, "x": x,
				"y": 3 * course, "z": 10, "rot": 0})
	if not await _stand(bricks, "A black wall with side studs"):
		_check("the wall stands", false)
		return
	# A grey tile on each side stud, one at a time, as a detail pass places them.
	var tiles: Array = []
	for placement: Assistant.Placement in _assistant._model_from_world().placements:
		if placement.part != "87087":
			continue
		var stud := {"part": "87087", "color": 0, "x": placement.x, "y": placement.y,
			"z": placement.z, "rot": 0}
		var tile: Dictionary = _assistant._dress(stud, "+z", 72, ["3070b"])
		tile.erase("dressing")
		tiles.append(tile)
	var said: String = _text(await _assistant.use_tool("edit_model", {"add": tiles}))
	print("    %d tiles: %s" % [tiles.size(), said.substr(0, 160)])
	_check("%d grey tiles laid one by one over a black wall are refused" % tiles.size(),
		tiles.size() >= 20 and said.begins_with("Not applied"))
	_check("...and told the call that lays them as one structure",
		said.contains("restyle_model") and said.contains("\"style\""))
	# The same tiles in two columns are ribs.
	var column: Array = []
	for course: int in 12:
		for x: int in [3, 11]:
			column.append({"part": "87087", "color": 0, "x": x, "y": 3 * course, "z": 11,
				"rot": 0})
	for one: Dictionary in column.duplicate():
		var tile: Dictionary = _assistant._dress(one, "+z", 72, ["4073"])
		tile.erase("dressing")
		column.append(tile)
	said = _text(await _assistant.use_tool("edit_model", {"add": column}))
	_check("...but a column of them up the wall is a rib, and laid: %s" % said.substr(0, 80),
		said.begins_with("Done"))


## A tower written to a file and opened again: its sections are gone from the
## file, and it is read as it stands, not at the nearest square turn.
func _read_back() -> void:
	print("  a tower read back from a file")
	var guidance := {"pattern": "prism", "at": {"x": 24, "y": 0, "z": 24}, "sides": 8,
		"radius": 7, "color": 0, "piers": {"count": 4},
		"storeys": {"count": 3, "in": 1}, "plinth": {"steps": 2, "out": 2}}
	_assistant.forget_built()
	_world.clear()
	_builder.lattice.clear()
	var built: String = _text(await _assistant.use_tool("submit_design", {"name": "Orthanc",
		"description": "a tower", "patterns": [guidance], "assemblies": []}))
	if built.begins_with("Not applied"):
		_check("the guidance's tower stands: %s" % built.substr(0, 200), false)
		return
	var live: String = _advice()
	var store := ModelStore.new()
	store.world = _world
	store.builder = _builder
	store.library = _library
	store.keeps = false
	var path: String = OS.get_cache_dir().path_join("brickworks-dress-probe.ldr")
	store.export_to(path, "Orthanc")
	_assistant.forget_built()
	_world.clear()
	_builder.lattice.clear()
	var opened: int = store.open(path)
	var model: Assistant.Model = _assistant._model_from_world()
	var turned: int = 0
	for placement: Assistant.Placement in model.placements:
		if placement.section.begins_with("turned"):
			turned += 1
	var report: Dictionary = _assistant._check(model, true)
	var advice: String = "\n".join(PackedStringArray(report.get("advice", [])))
	_check("opened again, %d parts, its turned faces read in sections of their own: %d"
		% [opened, turned], turned > 500)
	_check("...it holds in one piece as it did: %s" % report["summary"],
		bool(report["ok"]) and int(report.get("pieces", 0)) == 1)
	_check("...and is told of no speckle and no sky it was not told of standing",
		not advice.contains("speckle") and not advice.contains("Sky shows through")
			and not live.contains("speckle"))
	DirAccess.remove_absolute(path)


## The Orthanc on the landing page, read from its file and dressed again
## through the call. Run 4 was there when this was written: 99 of its 1,078
## marks scattered read as it stands, 559 as read before; dressed again, 58% to
## 46% plain black, and its weak joint underpinned. Run 5 replaced it, dressed
## in panels by its own run and made to stand: dressed again it is left as it
## is. Either way, read right it is not speckle, and dressing it again never
## makes it plainer, more scattered, more pieces, or weaker.
func _orthanc() -> void:
	print("  the landing page's Orthanc, dressed again")
	var store := ModelStore.new()
	store.world = _world
	store.builder = _builder
	store.library = _library
	store.keeps = false
	_assistant.forget_built()
	_world.clear()
	_builder.lattice.clear()
	store.open("res://models/orthanc.ldr")
	var before: Dictionary = _measure()
	var said: String = _text(await _assistant.use_tool("restyle_model", {}))
	var after: Dictionary = _measure()
	var redress: GDScript = preload("res://src/dev/redress.gd")
	var underpinned: String = await redress.underpin(_assistant)
	var stands: String = redress.stands(_assistant)
	print("    %s" % said.get_slice("\n", 0))
	print("    before %s" % str(before))
	print("    after  %s" % str(after))
	_check("read from its file, its ribs are ribs: %d of %d marks scattered"
		% [before["scattered"], before["marks"]],
		int(before["marks"]) > 100 and int(before["scattered"]) * 5 < int(before["marks"]))
	_check("dressed again, no plainer: %d%% plain black, %d%% before" % [after["plain"],
		before["plain"]], int(after["plain"]) <= int(before["plain"]))
	_check("...no more scattered: %d of %d marks, %d before"
		% [after["scattered"], after["marks"], before["scattered"]],
		int(after["scattered"]) <= int(before["scattered"])
			and int(after["scattered"]) * 10 < int(after["marks"]))
	_check("...in no more pieces: %s, %d, %d before" % [after["summary"], after["pieces"],
		before["pieces"]], bool(after["ok"]) and int(after["pieces"]) <= int(before["pieces"]))
	_check("...and it stands up, underpinned where it would not (%s): %s"
		% [underpinned.get_slice(":", 0), stands], stands.begins_with("stands up"))


func _measure() -> Dictionary:
	var model: Assistant.Model = _assistant._model_from_world()
	var black: int = 0
	for placement: Assistant.Placement in model.placements:
		if placement.color == 0 and Style.kinds_of(placement.part).contains("p"):
			black += 1
	# Called by name, so the probe runs on the code before this measure and fails
	# there rather than not compiling.
	var marks: Dictionary = _assistant.call("_speckle_marks", model) \
		if _assistant.has_method("_speckle_marks") else {"marks": [], "scattered": []}
	var report: Dictionary = _assistant._check(model, true)
	return {"parts": model.placements.size(),
		"plain": roundi(100.0 * black / maxf(1.0, model.placements.size())),
		"marks": (marks["marks"] as Array).size(),
		"scattered": (marks["scattered"] as Array).count(true),
		"ok": report["ok"], "summary": report["summary"], "pieces": int(report.get("pieces", 0))}


static func _text(said: Variant) -> String:
	if said is String:
		return said
	var text: String = ""
	for block: Variant in said:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			text += str(block["text"]) + "\n"
	return text


func _check(what: String, ok: bool) -> void:
	if ok:
		print("    ok    " + what)
	else:
		_failures += 1
		print("    FAIL  " + what)
