## A file written whole keeps what it was opened with: the ROTSTEP that ends
## a section's last step, and a mirrored copy's handed parts in their other
## hand, where the file names them by a number LDraw has since moved.
##
##   godot --headless --path . --script src/dev/whole_write_probe.gd
##
## im3check (2026-11-12, bench/results/im3check-2026-11-12/probes/ic3whole_probe.gd)
## wrote two small files whole, as a save that cannot patch writes them
## (ModelStore.patch_files off): the shed's main model ends on "0 ROTSTEP 30
## 45 0 ABS" after its last part, and the ROTSTEP was not in the file; the
## mirror's wing is put down once as it is and once reflected, and the
## reflected wing's 43722 (a right wing, "~Moved to 43722a") came out a
## turned 43722a, a right wing on the left, where 43723a goes, written as a
## sub-model of its own. Here each is
## opened, saved whole to a file, and that file opened again: what the
## world holds, read each time. The same files saved as patches (the usual
## save) are checked to keep the same. Exits non-zero on a failure.
extends SceneTree

const SHED := """0 FILE shed.ldr
0 Shed
0 Name: shed.ldr
0 Author: Brickworks
0 !BRICKWORKS AUTHORED_STEPS
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 2 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat
0 !BRICKWORKS STEP_NAME Lay the floor
0 STEP
1 16 80 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr
0 ROTSTEP 30 45 0 ABS
0 NOFILE
0 FILE roof.ldr
0 Roof
0 Name: roof.ldr
0 Author: Brickworks
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 ROTSTEP 0 90 0 REL
0 NOFILE
"""

const MIRROR := """0 FILE mirror.ldr
0 Mirror
0 Name: mirror.ldr
0 Author: Brickworks
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 16 100 -24 0 1 0 0 0 1 0 0 0 1 wing.ldr
1 16 -100 -24 0 -1 0 0 0 1 0 0 0 1 wing.ldr
1 7 0 -24 60 -1 0 0 0 1 0 0 0 1 3040.dat
0 STEP
0 NOFILE
0 FILE wing.ldr
0 Wing
0 Name: wing.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3040.dat
1 1 20 0 0 1 0 0 0 1 0 0 0 1 43722.dat
0 NOFILE
"""

var _failures: int = 0
var _world: BrickWorld
var _store: ModelStore
var _library: PartLibrary


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	CustomParts.dir = OS.get_user_data_dir().path_join("whole_write_parts/")
	CustomParts.keeps = false
	_library = PartLibrary.new()
	_library.load_catalogue()
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	var builder := Builder.new()
	builder.world = _world
	builder.library = _library
	get_root().add_child(builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.builder = builder
	_store.library = _library
	_store.keeps = false
	await process_frame
	var folder: String = OS.get_user_data_dir().path_join("whole_write")
	DirAccess.make_dir_recursive_absolute(folder)

	print("── the shed: a ROTSTEP ends the last step of the model and of its roof ──")
	var turns: Dictionary = {}
	for whole: bool in [true, false]:
		var how: String = "whole" if whole else "as a patch"
		var path: String = folder.path_join("shed_%s.ldr" % ("whole" if whole else "patch"))
		_open_file(folder.path_join("shed.ldr"), SHED)
		turns = _turns()
		_check("opened, the turns are read: %s" % JSON.stringify(turns),
			turns.get("|2") == [30.0, 45.0, 0.0, "ABS"] and turns.get("Roof|2") == [0.0, 90.0, 0.0, "REL"])
		var text: String = _saved(path, "shed", whole)
		print("    saved %s:\n%s" % [how, _indented(text)])
		_check("saved %s, the main model's last step still ends on its ROTSTEP" % how,
			_section_ends_on(text, "shed.ldr", "0 ROTSTEP 30 45 0 ABS"))
		_check("saved %s, so does the roof's" % how, _section_ends_on(text, "roof.ldr", "0 ROTSTEP 0 90 0 REL"))
		_open_file(path)
		var again: Dictionary = _turns()
		_check("saved %s and opened again, the same turns on the same steps (%s)" % [how,
			JSON.stringify(again)], again == turns)
		_check("...and the same 4 parts (%d)" % _world.brick_count(), _world.brick_count() == 4)
	# Its first step emptied, a step with no look of its own: the steps
	# written are numbered again from the roof's (BookletLooks.as_written),
	# and the turn after it goes with it.
	_open_file(folder.path_join("shed_plain.ldr"), SHED.replace("0 !BRICKWORKS STEP_NAME Lay the floor\n", ""))
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.unit.is_empty() and brick.group.is_empty():
			_world.remove_brick(brick.id)
	var emptied: String = _saved(folder.path_join("shed_emptied.ldr"), "shed", true)
	print("    its first step emptied, saved whole:\n%s" % _indented(emptied))
	_check("its first step emptied and saved whole, the main model still ends on its ROTSTEP",
		_section_ends_on(emptied, "shed.ldr", "0 ROTSTEP 30 45 0 ABS"))
	_open_file(folder.path_join("shed_emptied.ldr"))
	var emptied_turns: Dictionary = _turns()
	_check("...and opened again, it turns the step after the roof's (%s)" % JSON.stringify(emptied_turns),
		emptied_turns.get("|1") == [30.0, 45.0, 0.0, "ABS"] and _world.brick_count() == 2)

	print("── the mirror: a wing and its reflection, the wing's 43722 a moved number ──")
	var hands: Dictionary = {"43722a": 1, "43723a": 1}
	var reflected: String
	for whole: bool in [true, false]:
		var how: String = "whole" if whole else "as a patch"
		var path: String = folder.path_join("mirror_%s.ldr" % ("whole" if whole else "patch"))
		_open_file(folder.path_join("mirror.ldr"), MIRROR)
		var opened: Dictionary = _hands()
		_check("opened, the wing as it is has a right wing and its reflection the left (%s)"
			% JSON.stringify(opened), opened == hands)
		reflected = _reflected()
		_check("...where the right one's reflection is (%s)" % reflected, reflected.is_empty())
		var text: String = _saved(path, "mirror", whole)
		print("    saved %s:\n%s" % [how, _indented(text)])
		# The reflected copy written as a reflection of the wing (the left
		# wing read back from it), or as a section of its own with 43723a:
		# never 43722a turned, a right wing where the left goes, as it was.
		_check("saved %s, the right wing's 43722a written once, the reflected copy's not a turned 43722a"
			% how, text.count("43722a.dat") == 1)
		_open_file(path)
		var again: Dictionary = _hands()
		_check("saved %s and opened again, a right wing and a left (%s)" % [how, JSON.stringify(again)],
			again == hands)
		reflected = _reflected()
		_check("...the left where the right one's reflection is (%s)" % reflected, reflected.is_empty())

	print("\nwhole_write: %s" % ("%d FAILED" % _failures if _failures > 0 else "all passed"))
	quit(1 if _failures > 0 else 0)


## The file at [param path] opened, as the app opens one, so a save may
## patch it; written first with [param text] when one is given.
func _open_file(path: String, text: String = "") -> void:
	if not text.is_empty():
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	_world.clear()
	_store.open(path)


## The model saved to [param path], written whole or as a patch of the file
## it was opened from: the text written.
func _saved(path: String, title: String, whole: bool) -> String:
	ModelStore.patch_files = not whole
	var wrote: bool = _store.save_file(path, title)
	ModelStore.patch_files = true
	if not wrote:
		_check("saved to %s" % path, false)
		return ""
	return FileAccess.get_file_as_string(path)


## The world's turns by step: look key -> [x, y, z, how].
func _turns() -> Dictionary:
	var out: Dictionary = {}
	for name: String in _world.step_looks:
		var look: Variant = _world.step_looks[name]
		if look is Dictionary and (look as Dictionary).has("turn") and look["turn"] is Array:
			var turn: Array = (look["turn"] as Array).duplicate()
			turn.append(str(look.get("how", "REL")))
			out[name] = turn
	return out


## How many of each wing the world holds.
func _hands() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("4372"):
			out[brick.part_id] = int(out.get(brick.part_id, 0)) + 1
	return out


## "" when the left wing's shape lies where the right one's reflected across
## x = 0 lies, to a tenth of an LDU; else what is off.
func _reflected() -> String:
	var right: AABB
	var left: AABB
	for brick: BrickWorld.Brick in _world.bricks():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		if brick.part_id == "43722a":
			right = brick.transform * mesh.bounds
		elif brick.part_id == "43723a":
			left = brick.transform * mesh.bounds
	if right.size == Vector3.ZERO or left.size == Vector3.ZERO:
		return "a wing missing or without its shape"
	var image := AABB(Vector3(-right.end.x, right.position.y, right.position.z), right.size)
	if image.position.distance_to(left.position) > 0.1 or image.size.distance_to(left.size) > 0.1:
		return "the left wing's box %s, the right one's reflected %s" % [left, image]
	return ""


## Whether the section [param file] of [param text] has [param line] as its
## last line that is not blank, "0" alone or a NOFILE.
static func _section_ends_on(text: String, file: String, line: String) -> bool:
	var inside: bool = false
	var last: String = ""
	for raw: String in text.split("\n"):
		var said: String = raw.strip_edges()
		if said.begins_with("0 FILE "):
			if inside:
				break
			inside = said.substr(7).strip_edges().to_lower() == file
			continue
		if not inside or said.is_empty() or said == "0" or said == "0 NOFILE":
			continue
		last = said
	return last == line


static func _indented(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.strip_edges().split("\n"):
		out.append("      " + line)
	return "\n".join(out)
