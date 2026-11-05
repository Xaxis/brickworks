## Every moulded animal the library's own sets use, put where the set has it,
## the two ways a model is built: by an edit, as Claude puts a part down
## (edit_model's check), and by hand, as the part in hand lands where the
## pointer aims (Builder.update_preview, what a drag drives).
##
##   godot --headless --path . --script src/dev/moulded_in_sets_probe.gd [-- all]
##
## design16's Gandalf sessions both chose the set's own horse, 10509p02, and
## neither could stand it on a plate: the check seated its hooves on the studs
## and then called it off them, "its tubes land between that part's studs",
## at every place they tried. A real set's animal stands where the set has it,
## so every one refused here is the app's to answer for.
##
## Each animal is taken with the parts round it (its box grown by NEAR), as
## they stand in the set's file. By edit: read back as a session reads the
## baseplate (Assistant._model_from_world), the animal marked as put there by
## this edit, and checked: placed if no fault names it. By hand: taken out,
## held turned as the set has it, and aimed straight down where it stood:
## placed if the ghost can go down there and stands where the set has it, to
## half an LDU. Asked only of one upright on something with studs, which is
## what a drag on studs is for: a bird on a bar or a fish in a hand is put on
## its joint, which other probes drive.
##
## The files are the fewest that hold every moulded animal the library's
## sets use (82 parts); `-- all` reads every set in vendor/omr/files and puts
## every one of them (458 in 134 sets), which is a measure and not a probe.
extends SceneTree

const SETS := "res://vendor/omr/files/"
## The fewest files that hold every moulded animal the sets use.
const FILES: Array = [
	"6056-1.mpd", "6718-1.mpd", "7637-1.mpd", "75953-1.mpd", "6010-1.mpd", "9471-1.mpd",
	"9469-1.mpd", "6490-1.mpd", "41071-1.mpd", "40351-1.mpd", "3063-1.mpd", "6765-1.mpd",
	"7161-1.mpd", "6085-1.mpd", "6599-1.mpd", "30571-1.mpd", "60066-1.mpd", "40350-1.mpd",
	"5934-1.mpd", "31088-1_Angler-Fish.mpd", "7410-1.mpd", "3188-1.mpd", "40380-1.mpd",
	"6334-1.mpd", "40141-1.mpd", "7325-1.mpd", "41072-1.mpd", "41073-1.mpd", "7326-1.mpd",
	"3189-1.mpd", "10218-1.mpd", "6279-1.mpd", "6286-1.mpd", "10176-1.mpd", "7784-1.mpd",
	"75980-1.mpd", "10359-1.mpd", "10278-1.mpd", "10267-1.mpd", "21325-1.mpd",
	"10185-1.mpd", "10297-1.mpd", "6285-1.mpd", "42129-1.mpd",
]
## How far round an animal's box its neighbours are taken, in LDU.
const NEAR := 24.0
## How near the set's place the ghost has to stand, in LDU.
const AT_ITS_PLACE := 0.5

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _failures: int = 0
## What each way found: "edit" and "hand" -> [asked, placed].
var _tally: Dictionary = {"edit": [0, 0], "hand": [0, 0]}
## Fault kind -> how many animals an edit was refused by it.
var _kinds: Dictionary = {}
var _parts: Dictionary = {}
var _refused: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
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
	if not DirAccess.dir_exists_absolute(SETS):
		print("no %s: tools/omr.py fetch brings the sets" % SETS)
		quit(1)
		return
	var files: Array = FILES
	if OS.get_cmdline_user_args().has("all"):
		files = _every_set_with_one()
	var began: int = Time.get_ticks_msec()
	for file: String in files:
		_one_set(file)
	print("")
	print("moulded animals in the library's sets: %d parts, %d placed in %d sets, %.0f s"
		% [_parts.size(), _tally["edit"][0], files.size(),
			(Time.get_ticks_msec() - began) / 1000.0])
	print("  by edit: %d of %d placed where the set has them" % [_tally["edit"][1],
		_tally["edit"][0]])
	print("  by hand: %d of %d standing on studs placed where the set has them"
		% [_tally["hand"][1], _tally["hand"][0]])
	print("  refused by edit, by fault: %s" % _kinds)
	for line: String in _refused:
		print("    " + line)
	quit(1 if _failures > 0 else 0)


## Every set in the library with a moulded animal in it, by reading each file.
func _every_set_with_one() -> Array:
	var out: Array = []
	var names: Array = Array(DirAccess.get_files_at(SETS))
	names.sort()
	for file: String in names:
		if not (file.ends_with(".mpd") or file.ends_with(".ldr")):
			continue
		for line: String in FileAccess.get_file_as_string(SETS + file).split("\n"):
			var words: PackedStringArray = line.strip_edges().split(" ", false)
			if words.size() >= 15 and words[0] == "1" \
					and _animal(words[14].to_lower().trim_suffix(".dat")):
				out.append(file)
				break
	return out


## A moulded animal: a part the catalogue files under Animal.
func _animal(id: String) -> bool:
	var info: PartLibrary.PartInfo = _library.parts.get(_library.resolve(id))
	return info != null and info.family_category() == "Animal"


func _one_set(file: String) -> void:
	var ldr: LdrModel = LdrModel.load_file(SETS + file)
	if ldr == null:
		print("  %s: cannot be read" % file)
		return
	var pieces: Array = []
	for piece: LdrModel.Placement in ldr.flatten():
		var id: String = _library.resolve(piece.part_id.to_lower().trim_suffix(".dat"))
		if _library.mesh_for(id) != null:
			pieces.append([id, piece.color_code, piece.transform])
	for n: int in pieces.size():
		if _animal(str(pieces[n][0])):
			_one_animal(file, pieces, n)


## The animal [param n] of [param pieces] ([id, colour, transform] each) with
## the parts round it, put down by edit and by hand.
func _one_animal(file: String, pieces: Array, n: int) -> void:
	var id: String = pieces[n][0]
	var at: Transform3D = pieces[n][2]
	var mesh: Lbm.PartMesh = _library.mesh_for(id)
	var near: AABB = (at * mesh.bounds).grow(NEAR)
	_parts[id] = true
	_world.clear()
	_builder.lattice.clear()
	var animal: int = 0
	for k: int in pieces.size():
		var other: Lbm.PartMesh = _library.mesh_for(str(pieces[k][0]))
		if k != n and not (pieces[k][2] as Transform3D * other.bounds).intersects(near):
			continue
		var brick: int = _world.add_brick(pieces[k][0], int(pieces[k][1]), pieces[k][2])
		if brick != 0:
			_builder.register(brick, pieces[k][0], pieces[k][2])
		if k == n:
			animal = brick
	if animal == 0:
		return
	var where: String = "%s %s at %s" % [file, id, _ldu(at.origin)]
	_by_edit(where, animal)
	_by_hand(where, animal, id, at, mesh)


## Read back as a session reads it, the animal put there by this edit, and
## checked: placed if no fault names it.
func _by_edit(where: String, animal: int) -> void:
	var model: Assistant.Model = _assistant._model_from_world()
	var index: int = -1
	for k: int in model.placements.size():
		if model.placements[k].id == animal:
			index = k
	if index < 0:
		return
	model.placements[index].moved = true
	var report: Dictionary = _assistant._check(model, true)
	(_tally["edit"] as Array)[0] += 1
	var faults: PackedStringArray = _faults_naming(report, index)
	if faults.is_empty():
		(_tally["edit"] as Array)[1] += 1
		return
	for kind: String in _kinds_of(faults):
		_kinds[kind] = int(_kinds.get(kind, 0)) + 1
	_refused.append("edit: %s: %s" % [where, " | ".join(faults).left(400)])


## The fault lines of [param report] that name placement [param index], each
## "kind: line".
static func _faults_naming(report: Dictionary, index: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var kinds: Array = report.get("kinds", [])
	var kind: String = ""
	for line: String in str(report.get("feedback", "")).split("\n"):
		if line.is_empty():
			kind = ""
			continue
		var header: RegExMatch = RegEx.create_from_string("^(.+) \\(\\d+\\):$").search(line)
		if header != null and kinds.has(header.get_string(1)):
			kind = header.get_string(1)
			continue
		if not kind.is_empty() and line.begins_with("  - ") \
				and line.contains("brick %d (" % index):
			out.append("%s: %s" % [kind, line.substr(4)])
	return out


static func _kinds_of(faults: PackedStringArray) -> Array:
	var out: Array = []
	for fault: String in faults:
		var kind: String = fault.get_slice(":", 0)
		if not out.has(kind):
			out.append(kind)
	return out


## Taken out, held turned as the set has it, and aimed straight down where it
## stood: placed if the ghost can go down and stands where the set has it.
## Only one upright on a part with studs under its feet.
func _by_hand(where: String, animal: int, id: String, at: Transform3D,
		mesh: Lbm.PartMesh) -> void:
	if not BrickLattice.is_square_to_grid(at.basis):
		return
	var basis: Basis = BrickLattice.snap_basis(at.basis)
	if (basis * Vector3.UP).y < 0.99 or mesh.sockets.is_empty():
		return
	_world.remove_brick(animal)
	_builder.lattice.release(animal)
	var low: float = (at * mesh.bounds).position.y
	var from := Vector3(at.origin.x, low + 6.0, at.origin.z)
	var hit: BrickLattice.Hit = _builder.lattice.raycast(from, Vector3.DOWN)
	var under: BrickWorld.Brick = _world.get_brick(hit.brick_id) if hit.is_valid() else null
	if under == null or not _library.parts.has(under.part_id) \
			or (_library.parts[under.part_id] as PartLibrary.PartInfo).stud_count == 0 \
			or absf(hit.cell.y * BrickLattice.CELL + BrickLattice.CELL - low) > 4.0:
		return
	_builder.held_part = id
	_builder.held_face = BrickLattice.face_of(basis)
	_builder.held_rotation = BrickLattice.turns_about(basis, _builder.held_face)
	_builder.update_preview(from, Vector3.DOWN)
	(_tally["hand"] as Array)[0] += 1
	var ghost: Transform3D = _builder.ghost_transform()
	var off: float = ghost.origin.distance_to(at.origin)
	if _builder.can_place() and off <= AT_ITS_PLACE and ghost.basis.is_equal_approx(basis):
		(_tally["hand"] as Array)[1] += 1
		return
	_refused.append("hand: %s: the ghost %s at %s, %.1f LDU from the set's place" % [where,
		"can go down" if _builder.can_place() else "is refused", _ldu(ghost.origin), off])


static func _ldu(v: Vector3) -> String:
	return "%.1f,%.1f,%.1f" % [v.x, v.y, v.z]
