## A change asked about a selection lands the first time: Claude is told
## where the selection can take a part, and a refusal says where instead.
##
##   godot --headless --path . --script src/dev/selection_fit_probe.gd
##   xvfb-run -a godot --path . --resolution 1200x800 --script src/dev/selection_fit_probe.gd
##     ...and the picture of the open points, numbered: shots/selection_fit/points.png
##
## The shipped Orthanc's west horn, as the first real request about a
## selection had it (22 edits refused while Claude looked for the studs of
## a horn laid turned 25 degrees): selection gives each part where
## edit_model reads it, in its section; where_to_attach lists the open
## studs and, given a tooth plate, placements that land as they are; a
## plate put inside another is refused with where it fits, and that lands;
## one put in the air likewise; check_only changes nothing. Then two copies
## of a sub-assembly: a change to one, about a selection, is followed by
## the other, and one undo takes back both.
extends SceneTree


var _failures: int = 0
const HORN := "4,15,235,300,22,34"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	var ldr: LdrModel = LdrModel.load_file("res://models/orthanc.ldr")
	for piece: LdrModel.Placement in ldr.flatten():
		var part_id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(part_id) == null:
			continue
		var id: int = world.add_brick(part_id, piece.color_code, piece.transform)
		if id != 0:
			builder.register(id, part_id, piece.transform)
	var sides: PackedFloat64Array = HORN.split_floats(",")
	var inside: AABB = Assistant._box_from({"x_from": sides[0], "x_to": sides[1],
		"y_from": sides[2], "y_to": sides[3], "z_from": sides[4], "z_to": sides[5]})
	for brick: BrickWorld.Brick in world.bricks():
		var at: AABB = SelectionScope.box_of(brick.part_id, brick.transform, library)
		if at.has_volume() and inside.has_point(at.get_center()):
			builder.selection[brick.id] = true
	_ok(builder.selection.size() > 100, "Orthanc stands, %d parts; its west horn is %d of them"
		% [world.brick_count(), builder.selection.size()])
	_ok(assistant.focus_on(builder.selection.keys(), true).is_empty(), "...asked about")

	print("\nselection says each part where edit_model reads it")
	var said: String = str(await assistant.use_tool("selection", {}))
	var turned: RegEx = RegEx.create_from_string("section='(turned [^']+)'")
	var section: RegExMatch = turned.search(said)
	_ok(section != null, "a turned part is given in its section: %s" % (
		section.get_string(0) if section != null else "none"))
	_ok(said.contains("Some are laid turned, in a section") and said.contains(
		"'%s' (" % (section.get_string(1) if section != null else "?")),
		"...and the section is said: where it stands and how it is turned")
	_ok(said.contains("Open connection points of the selection") and said.contains("free stud"),
		"...and its open connection points are counted: %s" % _line_with(said, "free stud"))

	print("\nwhere_to_attach lists the open points, and seats a tooth plate on them")
	var listed: String = _text(await assistant.use_tool("where_to_attach", {}))
	_ok(listed.contains("[1] ") and listed.contains(" free, "),
		"the free points, numbered: %s" % _line_with(listed, "[1] "))
	var started: int = Time.get_ticks_msec()
	var offered: String = _text(await assistant.use_tool("where_to_attach",
		{"part": "49668", "color": 0, "toward": "out", "limit": 3}))
	var fits: Array = _placements(offered)
	_ok(fits.size() >= 2, "%d placements of 49668 that fit, in %d ms: %s" % [fits.size(),
		Time.get_ticks_msec() - started, JSON.stringify(fits[0]) if not fits.is_empty() else offered.right(300)])
	var depth: int = builder.history_depth()
	var count: int = world.brick_count()
	if not fits.is_empty():
		var landed: String = _text(await assistant.use_tool("edit_selection", {"add": [fits[0]]}))
		_ok(landed.begins_with("Done."), "the first lands as it is: %s" % landed.get_slice("\n", 0).left(90))
		_ok(world.brick_count() == count + 1, "...one part put down")
	if fits.size() >= 3:
		# Offered together, they fit together.
		var two: String = _text(await assistant.use_tool("edit_selection", {"add": [fits[1], fits[2]]}))
		_ok(two.begins_with("Done.") and world.brick_count() == count + 3,
			"...and the next two, together: %s" % two.get_slice("\n", 0).left(60))

	print("\na plate put inside a part is refused with where it fits, and that lands")
	# A 1 x 1 plate seated on a free stud pointing up, then sunk a plate
	# into what that stud is on.
	var plate: Assistant.Placement = null
	var read: OpenPoints = OpenPoints.read(assistant)
	for point: OpenPoints.Point in read.points_of(assistant.focus.ids.keys()):
		if point.by == 0 and point.kind == "stud" and point.face == "up" and plate == null:
			var seated_on: Array[Assistant.Placement] = read.fits_on(point, "3024", 72, {},
				assistant.focus.region, 1)
			if not seated_on.is_empty():
				plate = seated_on[0]
	_ok(plate != null, "a 1 x 1 plate on a stud of the horn: %s" % (
		OpenPoints.as_json(plate) if plate != null else "none"))
	if plate != null:
		var sunk: Dictionary = {"part": "3024", "color": 72, "x": plate.x, "y": plate.y - 1,
			"z": plate.z, "face": plate.face, "section": plate.section}
		count = world.brick_count()
		var refused: String = _text(await assistant.use_tool("edit_selection", {"add": [sunk]}))
		_ok(refused.begins_with("Not applied") and refused.contains("runs into #"),
			"refused, saying what it runs into: %s" % _line_with(refused, "runs into"))
		var fix: Array = _placements(refused.substr(refused.find("Part by part")))
		_ok(not fix.is_empty() and refused.contains("It fits and holds"),
			"...and where it fits and holds: %s" % _line_with(refused, "It fits"))
		if not fix.is_empty():
			var again: String = _text(await assistant.use_tool("edit_selection", {"add": [fix[0]]}))
			_ok(again.begins_with("Done.") and world.brick_count() == count + 1,
				"...which lands: %s" % again.get_slice("\n", 0).left(60))

	print("\na plate put in the air is refused with the nearest stud it fits on")
	var room: AABB = assistant.focus.region
	var air: Dictionary = {"part": "3024", "color": 72,
		"x": snappedf((room.end.x - 30.0) / 20.0, 0.1), "y": snappedf((room.end.y - 12.0) / 8.0, 0.25),
		"z": snappedf((room.end.z - 30.0) / 20.0, 0.1)}
	count = world.brick_count()
	var afloat: String = _text(await assistant.use_tool("edit_selection", {"add": [air]}))
	_ok(afloat.begins_with("Not applied") and afloat.contains("nothing holds the 3024"),
		"refused, saying nothing holds it: %s" % _line_with(afloat, "nothing holds").left(120))
	var seated: Array = _placements(afloat.substr(maxi(0, afloat.find("Part by part"))))
	var where: String = _line_with(afloat, "nothing holds")
	_ok(not seated.is_empty(), "...and where it would: %s" % where.substr(where.find("; ") + 2))
	if not seated.is_empty():
		var again: String = _text(await assistant.use_tool("edit_selection", {"add": [seated[0]]}))
		_ok(again.begins_with("Done.") and world.brick_count() == count + 1,
			"...which lands: %s" % again.get_slice("\n", 0).left(60))

	print("\ncheck_only tries a change and makes none")
	var before: int = world.revision
	count = world.brick_count()
	var fresh: Array = _placements(_text(await assistant.use_tool("where_to_attach",
		{"part": "49668", "color": 0, "toward": "out", "limit": 1})))
	_ok(not fresh.is_empty(), "asked again, a place for one more: %s" % (
		JSON.stringify(fresh[0]) if not fresh.is_empty() else "none"))
	if not fresh.is_empty():
		var tried: String = _text(await assistant.use_tool("edit_selection",
			{"add": [fresh[0]], "check_only": true}))
		_ok(tried.begins_with("It would be applied") and world.brick_count() == count
			and world.revision == before, "it would be applied, and nothing changed: %s"
			% tried.left(80))
	var tried_bad: String = _text(await assistant.use_tool("edit_selection",
		{"add": [air], "check_only": true}))
	_ok(tried_bad.begins_with("Not applied") and world.brick_count() == count,
		"...and one that would not is refused the same way, nothing changed")
	_ok(builder.history_depth() == depth + 1, "every change landed is one undo step (%d)"
		% (builder.history_depth() - depth))

	if ModelShot.possible():
		var shot: Variant = await assistant.use_tool("where_to_attach", {"toward": "out"})
		var saved: bool = false
		if shot is Array:
			for block: Variant in shot:
				if block is Dictionary and (block as Dictionary).get("type", "") == "image":
					var data: String = (block as Dictionary)["source"]["data"]
					var image := Image.new()
					var bytes: PackedByteArray = Marshalls.base64_to_raw(data)
					if image.load_jpg_from_buffer(bytes) != OK:
						image.load_png_from_buffer(bytes)
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
						"res://shots/selection_fit"))
					saved = image.save_png("res://shots/selection_fit/points.png") == OK
		_ok(saved, "the picture of the open points, numbered: shots/selection_fit/points.png")

	await _copies(library)

	print("")
	if _failures == 0:
		print("a change about a selection lands the first time")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


## Two copies of one sub-assembly: Claude's change to one, about a
## selection, and the other follows it.
func _copies(library: PartLibrary) -> void:
	print("\nthe other copy of a sub-assembly follows a change to the selection")
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	var assemblies := Assemblies.new()
	assemblies.world = world
	assemblies.builder = builder
	assemblies.library = library
	assistant.assemblies = assemblies
	await process_frame
	# A wing each side: a 2 x 4 on the ground and a 2 x 2 on it, the second
	# copy the first moved ten studs along x.
	var copies: Dictionary = {"Wing#1": 0.0, "Wing#2": 200.0}
	for path: String in copies:
		var along: float = copies[path]
		for one: Array in [["3020", Vector3(along + 40.0, 8.0, 20.0)],
				["3022", Vector3(along + 20.0, 16.0, 20.0)]]:
			var at := Transform3D(Basis.IDENTITY, one[1])
			var id: int = world.add_brick(one[0], 4, at)
			builder.register(id, one[0], at)
			# As Builder.set_path puts it (by the class's name, Resource's answers).
			world.get_brick(id).unit = path
			world.get_brick(id).group = Assemblies.group_of(path)
	var first: Array = assemblies.ids_under("Wing#1")
	var second: int = assemblies.ids_under("Wing#2").size()
	for brick_id: int in first:
		builder.selection[brick_id] = true
	_ok(first.size() == 2 and second == 2 and assistant.focus_on(builder.selection.keys(),
		true).is_empty(), "two copies of Wing, the first selected")
	var offered: Array = _placements(_text(await assistant.use_tool("where_to_attach",
		{"part": "3024", "color": 1, "toward": "up", "limit": 1})))
	_ok(not offered.is_empty(), "a 1 x 1 plate that fits on it: %s" % (
		JSON.stringify(offered[0]) if not offered.is_empty() else "none"))
	if offered.is_empty():
		return
	var depth: int = builder.history_depth()
	var answer: String = _text(await assistant.use_tool("edit_selection", {"add": offered}))
	_ok(answer.contains("1 other copy of \"Wing\" followed it"),
		"put down, and said: %s" % answer.get_slice("\n", 0).left(120))
	_ok(assemblies.ids_under("Wing#1").size() == 3 and assemblies.ids_under("Wing#2").size() == 3,
		"...both copies have the plate (%d and %d parts)" % [assemblies.ids_under("Wing#1").size(),
			assemblies.ids_under("Wing#2").size()])
	var blue: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code == 1 and brick.unit == "Wing#2":
			blue = brick.id
	_ok(blue != 0 and absf(world.get_brick(blue).transform.origin.x
		- world.get_brick(_blue_in(world, "Wing#1")).transform.origin.x - 200.0) < 0.5,
		"...the second's ten studs along, where the first's is")
	_ok(builder.history_depth() == depth + 1, "...as one undo step")
	builder.undo()
	_ok(assemblies.ids_under("Wing#1").size() == 2 and assemblies.ids_under("Wing#2").size() == 2,
		"one undo takes back both")


func _blue_in(world: BrickWorld, unit: String) -> int:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code == 1 and brick.unit == unit:
			return brick.id
	return 0


## Every placement written as JSON in an answer, in order.
func _placements(text: String) -> Array:
	var out: Array = []
	var found: RegEx = RegEx.create_from_string("\\{[^{}]*\"part\":[^{}]*\\}")
	for one: RegExMatch in found.search_all(text):
		var parsed: Variant = JSON.parse_string(one.get_string(0))
		if parsed is Dictionary:
			out.append(parsed)
	return out


func _line_with(text: String, word: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(word):
			return line.strip_edges().left(160)
	return "(no line with \"%s\")" % word


func _text(answer: Variant) -> String:
	if answer is Array:
		var said := PackedStringArray()
		for block: Variant in answer:
			if block is Dictionary and (block as Dictionary).get("type", "") == "text":
				said.append(str((block as Dictionary)["text"]))
		return "\n".join(said)
	return str(answer)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
