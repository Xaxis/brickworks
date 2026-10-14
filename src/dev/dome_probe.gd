## A smooth dome as the owner's own session asked for one: four 87375 quarter
## domes, radius 8, a seamless 16-stud hemisphere, on a ring of four 58846
## tapered 10 x 10 corners.
##
##   godot --headless --path . --script src/dev/dome_probe.gd
##
## The session building an orrery was told 87375 had no connection points
## and that Brickworks had no clip joints, and gave the dome up as floating.
## Its handles are bars, and a bar is held in a clip. So, as a session builds
## it: each quarter's bottom handle in two 61252 clips standing outward on
## the corners' studs, under the shell, and its top handle in a 61252 on a
## 2 x 2 round plate inside the crown. The ring and the clips are read
## from LDraw lines the way joints_probe reads a design; the quarters are
## said by their bottom bar on the clips' line (axis and joint), as a
## session would put them from what attachment_points tells it. The check
## must call it buildable, in one piece, nothing floating; attachment_points
## must list both handles of 87375 as bars and the clip of 61252; and the
## same dome with a quarter a stud off its clips, or the quarters a plate
## above them, must not hold.
##
## Needs a catalogue built with tools/ldraw/occupancy.py's coarse covers
## (87375 and 58846 were solid bounding boxes, and the clips under the shell
## collided with them): said, and failed, without.
extends SceneTree

const PATH := "user://dome_probe.ldr"

## The ring and what holds the quarters, in LDraw: four 58846 about the
## origin, two 1 x 1 plates and two 61252 clips on the studs either side of
## each seam, 130 out, and the crown's plate and clips.
const BASE := """
1 15 -80 -24 -80 1 0 0 0 1 0 0 0 1 58846.dat
1 15 -80 -24 80 0 0 1 0 1 0 -1 0 0 58846.dat
1 15 80 -24 80 -1 0 0 0 1 0 0 0 -1 58846.dat
1 15 80 -24 -80 0 0 -1 0 1 0 1 0 0 58846.dat
1 15 -10 -32 -130 1 0 0 0 1 0 0 0 1 3024.dat
1 15 10 -32 -130 1 0 0 0 1 0 0 0 1 3024.dat
1 15 -10 -40 -130 1 0 0 0 1 0 0 0 1 61252.dat
1 15 10 -40 -130 1 0 0 0 1 0 0 0 1 61252.dat
1 15 -10 -32 130 1 0 0 0 1 0 0 0 1 3024.dat
1 15 10 -32 130 1 0 0 0 1 0 0 0 1 3024.dat
1 15 -10 -40 130 -1 0 0 0 1 0 0 0 -1 61252.dat
1 15 10 -40 130 -1 0 0 0 1 0 0 0 -1 61252.dat
1 15 -130 -32 -10 1 0 0 0 1 0 0 0 1 3024.dat
1 15 -130 -32 10 1 0 0 0 1 0 0 0 1 3024.dat
1 15 -130 -40 -10 0 0 1 0 1 0 -1 0 0 61252.dat
1 15 -130 -40 10 0 0 1 0 1 0 -1 0 0 61252.dat
1 15 130 -32 -10 1 0 0 0 1 0 0 0 1 3024.dat
1 15 130 -32 10 1 0 0 0 1 0 0 0 1 3024.dat
1 15 130 -40 -10 0 0 -1 0 1 0 1 0 0 61252.dat
1 15 130 -40 10 0 0 -1 0 1 0 1 0 0 61252.dat
"""
## The crown, inside the top: a 2 x 2 round plate with a 61252 on each of
## its studs, each clip turned out to a quarter's top handle, 30 from the
## middle, and a 2 x 2 round tile on the clips' studs closing the top.
const CROWN := """
1 15 0 -152 0 1 0 0 0 1 0 0 0 1 4032a.dat
1 15 -10 -160 -10 1 0 0 0 1 0 0 0 1 61252.dat
1 15 -10 -160 10 0 0 1 0 1 0 -1 0 0 61252.dat
1 15 10 -160 10 -1 0 0 0 1 0 0 0 -1 61252.dat
1 15 10 -160 -10 0 0 -1 0 1 0 1 0 0 61252.dat
1 47 0 -168 0 1 0 0 0 1 0 0 0 1 14769.dat
"""
## The quarters as LDraw has them, for reading the bars' lines off.
const QUARTERS := """
1 47 0 -158 -30 1 0 0 0 1 0 0 0 1 87375.dat
1 47 -30 -158 0 0 0 1 0 1 0 -1 0 0 87375.dat
1 47 0 -158 30 -1 0 0 0 1 0 0 0 -1 87375.dat
1 47 30 -158 0 0 0 -1 0 1 0 1 0 0 87375.dat
"""
## Which way each quarter's bottom handle runs, in the model's axes, in the
## order of QUARTERS.
const WAYS: Array[String] = ["x", "z", "-x", "-z"]
## A real set with both tapered quarter rings in it, and the rings.
const SLAVE_I := "res://vendor/omr/files/75060-1.mpd"
const RINGS: Array[String] = ["58846", "95188"]

var _failures: int = 0
var _assistant: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary


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

	print("\nthe parts say how they join")
	var dome: Lbm.PartMesh = _library.mesh_for("87375")
	var bars: Array = _bars(dome)
	_ok(bars.size() == 2, "87375 has two bars, its handles: %d" % bars.size())
	var told: String = _assistant._attachment_points({"part": "87375", "x": 0, "y": 0, "z": 0})
	_ok(told.count(": bar at") == 2, "attachment_points lists both handles as bars")
	var clip_told: String = _assistant._attachment_points({"part": "61252", "x": 0, "y": 0,
		"z": 0})
	_ok(clip_told.contains(": clip at"), "attachment_points lists 61252's clip")
	_ok(_box_count("87375") > 1 and _box_count("58846") > 8,
		"87375 and 58846 are covered as their shapes, not their boxes (%d and %d boxes)"
			% [_box_count("87375"), _box_count("58846")])

	print("\nthe dome as LDraw has it")
	var whole: Assistant.Model = await _design(BASE + CROWN + QUARTERS)
	var verdict: Dictionary = _assistant._check(whole, true)
	_ok(bool(verdict["ok"]) and int(verdict["pieces"]) == 1
		and (verdict["floating"] as Array).is_empty(),
		"%d parts: %s, %d piece%s" % [whole.placements.size(), verdict["summary"],
			int(verdict["pieces"]), "" if int(verdict["pieces"]) == 1 else "s"])
	if not bool(verdict["ok"]):
		print(str(verdict["feedback"]).left(1200))

	print("\nthe quarters said by their bars, as a session puts them")
	var clips: Array = _clip_lines(whole)
	var said: Array = []
	for n: int in 4:
		said.append(_quarter_on(clips, n))
	var bricks: Array = []
	for placement: Assistant.Placement in whole.placements:
		if placement.part != "87375":
			bricks.append({"part": placement.part, "color": placement.color, "x": placement.x,
				"y": placement.y, "z": placement.z, "face": placement.face,
				"rot": placement.rot})
	var answer: String = str(await _assistant.use_tool("check_design",
		{"bricks": bricks + said}))
	var first: String = answer.get_slice("\n", 0)
	_ok(first.contains("buildable"), "check_design: %s" % first)
	_ok(not answer.contains("floating") and not answer.contains("pieces that nothing joins"),
		"nothing floats and it is one piece")
	if not first.contains("buildable"):
		print(answer.left(1500))

	print("\nand what must not hold")
	var off: Array = said.duplicate(true)
	(off[0] as Dictionary)["z"] = float((off[0] as Dictionary)["z"]) + 1.0
	var moved: Dictionary = await _checked(bricks + off)
	_ok(not bool(moved["ok"]), "a quarter a stud off its clips: %s" % moved["summary"])
	# A plate up, the handles are over their clips and in neither: nothing
	# else holds a quarter, so all four float.
	var up: Array = said.duplicate(true)
	for one: Dictionary in up:
		one["y"] = float(one["y"]) + 1.0
	var lifted: Dictionary = await _checked(bricks + up)
	_ok((lifted["floating"] as Array).size() >= 4,
		"the quarters a plate above their clips float: %s" % lifted["summary"])

	print("\nquarter rings nest as a real set nests them")
	# 75060 Slave I, as LDraw's model repository has it: 58846 and 95188,
	# 10 x 10 and 6 x 6 tapered quarter rings, with the parts its builders
	# set into and against them (every part of the sub-model within 7 studs
	# of one). Each ring was its bounding box, a solid square, and nothing a
	# real set puts inside one fitted.
	if FileAccess.file_exists(SLAVE_I):
		var mpd: String = FileAccess.get_file_as_string(SLAVE_I)
		for ring: Array in [["58846", "75060 - bag4.ldr"], ["95188", "75060 - main.ldr"]]:
			var lines: String = _near(mpd, ring[1], ring[0], 140.0)
			var region: Assistant.Model = await _design_as_standing(lines)
			var seen: Dictionary = _assistant._check(region, true)
			var against := PackedStringArray()
			for pair: Array in seen.get("standing_overlaps", []):
				var one: String = region.placements[int(pair[0])].part
				var other: String = region.placements[int(pair[1])].part
				if one == ring[0] or other == ring[0]:
					against.append(one + " with " + other)
			var count: int = region.placements.filter(func(p: Assistant.Placement) -> bool:
				return p.part == ring[0]).size()
			_ok(count > 0 and against.is_empty(), "%s in %s, %d of them among %d parts: %s"
				% [ring[0], ring[1], count, region.placements.size(),
					"nothing overlaps" if against.is_empty() else ", ".join(against)])
		_clear()
	else:
		print("  (no %s: tools/omr.py fetch brings it; skipped)" % SLAVE_I)

	print("")
	if _failures == 0:
		print("dome: four quarter domes clipped on a ring of tapered corners hold as one")
	else:
		print("dome: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## A quarter said by its bottom handle on the line of the clips under it:
## axis the way the handle runs, joint its number, x, y, z the middle of the
## two clips' line.
func _quarter_on(clips: Array, n: int) -> Dictionary:
	var dome: Lbm.PartMesh = _library.mesh_for("87375")
	var lines: Array = Assistant._joint_lines(dome)
	var bottom: int = -1
	for k: int in lines.size():
		if lines[k][0] == "bar" and (bottom < 0
				or (lines[k][1] as Vector3).y < (lines[bottom][1] as Vector3).y):
			bottom = k
	var way: Vector3 = Assistant.AXES[WAYS[n]]
	# The clips whose line runs that way, on the quarter's side: a handle
	# along x is on the +z side of the dome, along z on the -x side.
	var side: Vector3 = Vector3(-way.z, 0.0, way.x)
	var pair: Array = clips.filter(func(c: Array) -> bool:
		return absf((c[1] as Vector3).dot(way)) > 0.99 and (c[0] as Vector3).dot(side) > 100.0)
	var middle := Vector3.ZERO
	for c: Array in pair:
		middle += c[0]
	middle /= maxf(1.0, float(pair.size()))
	return {"part": "87375", "color": 47, "axis": WAYS[n], "joint": bottom,
		"x": snappedf(middle.x / Assistant.STUD, 0.01),
		"y": snappedf(middle.y / Assistant.PLATE, 0.01),
		"z": snappedf(middle.z / Assistant.STUD, 0.01)}


## The clip lines of a model's 61252s, in the world: [middle, way].
func _clip_lines(model: Assistant.Model) -> Array:
	var out: Array = []
	for placement: Assistant.Placement in model.placements:
		if placement.part != "61252":
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		var at: Transform3D = _assistant._transform(placement, mesh)
		for line: Array in Assistant._joint_lines(mesh):
			if line[0] == "clip":
				out.append([at * (line[1] as Vector3), (at.basis * (line[2] as Vector3)).normalized()])
	return out


func _bars(mesh: Lbm.PartMesh) -> Array:
	return Assistant._joint_lines(mesh).filter(func(line: Array) -> bool:
		return line[0] == "bar")


func _box_count(part_id: String) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(part_id)
	return mesh.boxes.size() if mesh != null else 0


func _checked(bricks: Array) -> Dictionary:
	var model := Assistant.Model.new()
	for raw: Dictionary in bricks:
		model.placements.append(Assistant.Placement.from_dict(raw))
	_assistant._onto_lines(model)
	return _assistant._check(model, true)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


## LDraw lines, opened as a model and read back as the placements a design
## would write, then checked as a design on an empty baseplate.
func _design(ldraw: String) -> Assistant.Model:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("0 dome probe\n" + ldraw.strip_edges() + "\n")
	file.close()
	_clear()
	_store.open(PATH)
	for _n: int in 10:
		await process_frame
	var read: Assistant.Model = _assistant._model_from_world()
	_clear()
	var fresh := Assistant.Model.new()
	for put: Assistant.Placement in read.placements:
		fresh.placements.append(Assistant.Placement.from_dict({"part": put.part,
			"color": put.color, "x": put.x, "y": put.y, "z": put.z,
			"face": put.face, "rot": put.rot}))
	return fresh


## The part lines of one sub-model of an MPD within [param reach] LDU of
## any of its parts [param part_id]: a real set's construction round one
## part, without the rest of the set.
static func _near(mpd: String, submodel: String, part_id: String, reach: float) -> String:
	var lines: Array = []
	var inside: bool = false
	for line: String in mpd.split("\n"):
		var bare: String = line.strip_edges()
		if bare.to_lower().begins_with("0 file "):
			inside = bare.substr(7).strip_edges().to_lower() == submodel.to_lower()
			continue
		if inside and bare.begins_with("1 ") and bare.to_lower().ends_with(".dat"):
			lines.append(bare)
	var at := func(line: String) -> Vector3:
		var words: PackedStringArray = line.split(" ", false)
		return Vector3(float(words[2]), float(words[3]), float(words[4]))
	var anchors: Array = lines.filter(func(line: String) -> bool:
		return line.to_lower().ends_with(" " + part_id + ".dat")).map(at)
	var kept := PackedStringArray()
	for line: String in lines:
		var here: Vector3 = at.call(line)
		if anchors.any(func(anchor: Vector3) -> bool: return anchor.distance_to(here) <= reach):
			kept.append(line)
	return "\n".join(kept)


## LDraw lines opened and read back as the bricks of the world: standing,
## so the check keeps what overlaps among them rather than refusing it.
func _design_as_standing(ldraw: String) -> Assistant.Model:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("0 dome probe\n" + ldraw.strip_edges() + "\n")
	file.close()
	_clear()
	_store.open(PATH)
	for _n: int in 10:
		await process_frame
	return _assistant._model_from_world()


func _clear() -> void:
	for brick: BrickWorld.Brick in _world.bricks():
		_builder.lattice.release(brick.id)
	_world.clear()
