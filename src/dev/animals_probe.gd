## Every moulded animal in the library's sets goes on by hand where its set
## has it, and every saddle a set puts on its horse, written as a session
## writes it, is seated on the horse's studs to the LDU.
##
##   godot --headless --path . --script src/dev/animals_probe.gd
##
## By hand: each upright animal that takes a stud from underneath, standing in
## its set on a part with studs, is held turned as the set has it over that
## part alone and aimed straight down where it stood (Builder.update_preview,
## what a drag drives), as moulded_in_sets does. It goes on where the ghost
## can go down there, square as the set has it, and stands where the set has
## it, to an LDU. Where the set's own file has it off the studs under it (no
## hole or tube of it on a stud there, by BrickNet's labels, which are the
## part's and not the app's), a person building the set puts it on the studs it
## stands over, so there: every hole or tube the ghost puts on that part's
## studs, within half a stud of the set's place. 10176-1 stands its wolf
## (48812) 4 LDU off the studs of the brick under it, its holes drawn at 34 and
## -6 where the studs are at 30 and -10; 7637-1 stands the same wolf with its
## holes on its studs.
##
## Saddles: each saddle or barding whose holes are on a part's studs in its set
## (on its horse), taken with the parts round it, read back as a session reads
## the model and written as a session writes a part, in studs and plates to a
## hundredth with nothing past them, then checked (edit_model's check). A
## horse's back is an odd number of LDU up, which whole cells cannot say, so it
## is written an LDU low and the check's seat has to put it on the studs:
## seated where the set has it within SEATED, and refused for nothing the
## check does not refuse it for where its set has it (6379-1 sits its rider 8
## LDU down into the saddle; 6085-1's bardings overlap their horses' covers).
##
## On pre261 with the catalogue of 2026-10-23: by hand 60 of 63, the
## scorpion's three (30169) put 10 LDU off the stud its set puts in its tube;
## saddles 9 of 27 seated, 18 refused, each left an LDU low: the seat followed
## the sword's bar in the saddle's clip, or would not take a barding as far
## into its rider's leg as it was into its horse.
extends SceneTree

const SETS := "res://vendor/omr/files/"
## How far round an animal's box its neighbours are taken, in LDU.
const NEAR := 24.0
## How near the set's place the ghost has to stand, in LDU.
const AT_ITS_PLACE := 1.0
## How near a stud a hole or a tube of the animal has to be to be on it, LDU.
const ON_STUD := 1.0
## Where the set's file has an animal off its studs: how near its place,
## across, the ghost has to put it on the studs it stands over (half a stud).
const OVER := 10.0
## How near where the set has it a saddle has to be seated, in LDU.
const SEATED := 0.05
## Every one asked, and at least as many as there were when this was written:
## a library that lost some would otherwise pass with fewer.
const HAND_AT_LEAST := 63
const SADDLES_AT_LEAST := 27

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _failures: int = 0
var _hand: Array = [0, 0]
var _off_in_file: PackedStringArray = []
var _saddles: Array = [0, 0]
var _worst: float = 0.0
var _refused: int = 0
var _not_on: int = 0
var _missed: PackedStringArray = []
## Saddles the check refuses where their sets have them, and for what.
var _own_faults: PackedStringArray = []


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
	var began: int = Time.get_ticks_msec()
	var files: Array = _every_set_with_one()
	for file: String in files:
		_one_set(file)
	print("")
	print("animals in the library's sets: %d sets, %.0f s" % [files.size(),
		(Time.get_ticks_msec() - began) / 1000.0])
	print("  by hand: %d of %d placed on their studs where their sets have them" % [
		_hand[1], _hand[0]])
	for line: String in _off_in_file:
		print("    set's file off its studs, the ghost on them: " + line)
	print("  saddles on their horses: %d of %d seated where their sets have them, the worst "
		% [_saddles[1], _saddles[0]] + "%.2f LDU off; %d refused; %d not on studs in their set"
		% [_worst, _refused, _not_on])
	for line: String in _own_faults:
		print("    refused where its set has it too, the set's own: " + line)
	for line: String in _missed:
		print("    " + line)
	_check("by hand, every upright moulded animal that takes a stud from underneath goes on "
		+ "its studs where its set has it (%d of %d, at least %d)" % [_hand[1], _hand[0],
			HAND_AT_LEAST], _hand[1] == _hand[0] and _hand[0] >= HAND_AT_LEAST)
	_check("every saddle on its horse, written as a session writes it, is seated where its "
		+ "set has it to %.2f LDU (%d of %d, at least %d; the worst %.2f)" % [SEATED,
			_saddles[1], _saddles[0], SADDLES_AT_LEAST, _worst],
		_saddles[1] == _saddles[0] and _saddles[0] >= SADDLES_AT_LEAST)
	_check("and none of them is refused for more than it is where its set has it (%d)"
		% _refused, _refused == 0)
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


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


## A moulded animal, or a piece of one: a part the catalogue files under Animal.
func _animal(id: String) -> bool:
	var info: PartLibrary.PartInfo = _library.parts.get(_library.resolve(id))
	return info != null and info.family_category() == "Animal"


## What a horse wears on its back's studs: a saddle, or barding under one.
func _saddle(id: String) -> bool:
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	return info != null and _animal(id) \
		and (info.name.contains("Saddle") or info.name.contains("Barding"))


func _one_set(file: String) -> void:
	var ldr: LdrModel = LdrModel.load_file(SETS + file)
	if ldr == null:
		print("  %s: cannot be read" % file)
		return
	var pieces: Array = []
	var lowest: float = INF
	for piece: LdrModel.Placement in ldr.flatten():
		var id: String = _library.resolve(piece.part_id.to_lower().trim_suffix(".dat"))
		var mesh: Lbm.PartMesh = _library.mesh_for(id)
		if mesh != null:
			pieces.append([id, piece.color_code, piece.transform])
			lowest = minf(lowest, (piece.transform * mesh.bounds).position.y)
	# Onto the ground, as opening the set puts it (ModelStore._lift_from).
	var lift := Vector3(0.0, ModelStore._lift_from(lowest, true), 0.0)
	for piece: Array in pieces:
		piece[2] = (piece[2] as Transform3D).translated(lift)
	for n: int in pieces.size():
		var id: String = pieces[n][0]
		if not _animal(id):
			continue
		var animal: int = _with_neighbours(pieces, n)
		if animal == 0:
			continue
		var where: String = "%s %s at %s" % [file, id, _ldu(pieces[n][2].origin)]
		if _saddle(id):
			_seat_saddle(where, animal, id, pieces[n][2])
			animal = _with_neighbours(pieces, n)
		_by_hand(where, animal, id, pieces[n][2])


## The world as [param pieces] has it round piece [param n] (its box grown by
## NEAR): the brick id that piece got, or 0.
func _with_neighbours(pieces: Array, n: int) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(str(pieces[n][0]))
	var near: AABB = ((pieces[n][2] as Transform3D) * mesh.bounds).grow(NEAR)
	_world.clear()
	_builder.lattice.clear()
	var animal: int = 0
	for k: int in pieces.size():
		var other: Lbm.PartMesh = _library.mesh_for(str(pieces[k][0]))
		if k != n and not ((pieces[k][2] as Transform3D) * other.bounds).intersects(near):
			continue
		var brick: int = _world.add_brick(pieces[k][0], int(pieces[k][1]), pieces[k][2])
		if brick != 0:
			_builder.register(brick, pieces[k][0], pieces[k][2])
		if k == n:
			animal = brick
	return animal


## Taken out, held turned as the set has it, and aimed straight down where it
## stood over the part under its feet alone. Only one upright, taking a stud
## from underneath, on a part with studs (as moulded_in_sets asks).
func _by_hand(where: String, animal: int, id: String, at: Transform3D) -> void:
	var mesh: Lbm.PartMesh = _library.mesh_for(id)
	if not BrickLattice.is_square_to_grid(at.basis):
		return
	var basis: Basis = BrickLattice.snap_basis(at.basis)
	if (basis * Vector3.UP).y < 0.99 or not _takes_from_below(id, mesh):
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
	var ground: Array = [under.part_id, under.color_code, under.transform]
	_world.clear()
	_builder.lattice.clear()
	var alone: int = _world.add_brick(ground[0], ground[1], ground[2])
	_builder.register(alone, ground[0], ground[2])
	_builder.held_part = id
	_builder.held_face = BrickLattice.face_of(basis)
	_builder.held_rotation = BrickLattice.turns_about(basis, _builder.held_face)
	_builder.update_preview(from, Vector3.DOWN)
	_hand[0] += 1
	var ghost: Transform3D = _builder.ghost_transform()
	var off: float = ghost.origin.distance_to(at.origin)
	var square: bool = _builder.can_place() and ghost.basis.is_equal_approx(basis)
	var set_on: bool = _on_studs(id, at, ground[0], ground[2])
	var placed: bool = square and off <= AT_ITS_PLACE
	if square and not placed and not set_on:
		var across: float = Vector2(ghost.origin.x - at.origin.x,
			ghost.origin.z - at.origin.z).length()
		placed = across < OVER and absf(ghost.origin.y - at.origin.y) <= AT_ITS_PLACE \
			and _on_studs(id, ghost, ground[0], ground[2])
		if placed:
			_off_in_file.append("%s on %s: the ghost at %s, %.1f LDU across" % [where,
				ground[0], _ldu(ghost.origin), across])
	if placed:
		_hand[1] += 1
		return
	_missed.append("hand: %s on %s: the ghost %s at %s, %.1f LDU from the set's place (%s)"
		% [where, ground[0], "can go down" if _builder.can_place() else "is refused",
			_ldu(ghost.origin), off, "on its studs there" if set_on
				else "the set's file has it off its studs"])


## Whether a hole or a tube of [param id] at [param at] is on a stud of
## [param other] at [param other_at], by their exact shapes' labels: BrickNet's
## and the part's own, not the catalogue's sockets this measures.
func _on_studs(id: String, at: Transform3D, other: String, other_at: Transform3D) -> bool:
	var mine: Exact.Shape = Exact.shape_for(_library, id)
	var theirs: Exact.Shape = Exact.shape_for(_library, other)
	if mine == null or theirs == null:
		return false
	var a := Exact.Item.new(mine, at)
	var b := Exact.Item.new(theirs, other_at)
	for one: Array in a.world():
		if mine.kind[one[0]] != Exact.HOLE:
			continue
		for stud: Array in b.world():
			if theirs.kind[stud[0]] == Exact.STUD \
					and Exact._mates(Exact.STUD_MATES, mine.sub[one[0]], theirs.sub[stud[0]]) \
					and (one[2] as Vector3).dot(stud[2]) >= Exact.AXIS_THR \
					and (one[1] as Vector3).distance_to(stud[1]) <= ON_STUD:
				return true
	return false


## A saddle on its horse in its set, read back and written as a session writes
## it, checked: seated where the set has it, and refused for nothing.
func _seat_saddle(where: String, saddle: int, id: String, at: Transform3D) -> void:
	var held: bool = false
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.id != saddle and _seated_on(id, at, brick.part_id, brick.transform):
			held = true
			break
	if not held or not BrickLattice.is_square_to_grid(at.basis):
		_not_on += 1
		return
	var model: Assistant.Model = _assistant._model_from_world()
	var index: int = -1
	for k: int in model.placements.size():
		if model.placements[k].id == saddle:
			index = k
	if index < 0 or not model.placements[index].section.is_empty():
		_not_on += 1
		return
	# What the check says of it where its set has it: a fault there is the
	# set file's own, as 6379-1's rider sits 8 LDU down into its saddle, the
	# holes of its legs on the horse's studs where the saddle's are.
	var as_set: Assistant.Model = _assistant._model_from_world()
	as_set.placements[index].moved = true
	var own: Dictionary = {}
	for fault: String in _faults_naming(_assistant._check(as_set, true), index):
		own[_fault_key(fault)] = true
	var placement: Assistant.Placement = model.placements[index]
	var mesh: Lbm.PartMesh = _library.mesh_for(id)
	placement.x = snappedf(placement.x + placement.nudge.x / Assistant.STUD, 0.01)
	placement.y = snappedf(placement.y + placement.nudge.y / Assistant.PLATE, 0.01)
	placement.z = snappedf(placement.z + placement.nudge.z / Assistant.STUD, 0.01)
	placement.nudge = Vector3.ZERO
	placement.moved = true
	var written: Vector3 = _assistant._transform(placement, mesh).origin
	var report: Dictionary = _assistant._check(model, true)
	var after: Transform3D = _assistant._transform(placement, mesh)
	var off: float = after.origin.distance_to(at.origin)
	_saddles[0] += 1
	_worst = maxf(_worst, off)
	var faults: PackedStringArray = []
	for fault: String in _faults_naming(report, index):
		if not own.has(_fault_key(fault)):
			faults.append(fault)
	if not own.is_empty():
		_own_faults.append("%s: %s" % [where, " | ".join(own.keys())])
	if off <= SEATED and after.basis.is_equal_approx(at.basis):
		_saddles[1] += 1
	if not faults.is_empty():
		_refused += 1
	if off > SEATED or not faults.is_empty():
		_missed.append("saddle: %s: written at %s, seated at %s, %.2f LDU from the set's place%s"
			% [where, _ldu(written), _ldu(after.origin), off,
				"" if faults.is_empty() else "; " + " | ".join(faults).left(300)])


## Whether a hole of [param id] at [param at] meets a stud of [param other]
## exactly, as a saddle's meet its horse's in the set.
func _seated_on(id: String, at: Transform3D, other: String, other_at: Transform3D) -> bool:
	var mine: Exact.Shape = Exact.shape_for(_library, id)
	var theirs: Exact.Shape = Exact.shape_for(_library, other)
	if mine == null or theirs == null:
		return false
	var a := Exact.Item.new(mine, at)
	var b := Exact.Item.new(theirs, other_at)
	for one: Array in a.world():
		if mine.kind[one[0]] != Exact.HOLE:
			continue
		for stud: Array in b.world():
			if theirs.kind[stud[0]] == Exact.STUD \
					and (one[1] as Vector3).distance_to(stud[1]) <= SEATED:
				return true
	return false


## A fault line by its kind and the bricks it names, not where it says they
## are: the same fault of a part written elsewhere.
static func _fault_key(fault: String) -> String:
	var bricks: PackedStringArray = []
	for found: RegExMatch in RegEx.create_from_string("brick (\\d+)").search_all(fault):
		bricks.append(found.get_string(1))
	return "%s %s" % [fault.get_slice(":", 0), " ".join(bricks)]


## The fault lines of [param report] that name placement [param index], each
## "kind: line" (as moulded_in_sets reads them).
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


## Whether [param id] takes a stud from underneath: a receiver it draws
## pointing down, or a hole its exact shape has pointing up (as moulded_in_sets
## asks, so both ask the same animals).
func _takes_from_below(id: String, mesh: Lbm.PartMesh) -> bool:
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "tube" and connector.axis.y < -0.99:
			return true
	var shape: Exact.Shape = Exact.shape_for(_library, id)
	for k: int in shape.connector_count() if shape != null else 0:
		if shape.kind[k] == Exact.HOLE and (-shape.frames[k].basis.y).y > 0.99:
			return true
	return false


static func _ldu(v: Vector3) -> String:
	return "%.1f,%.1f,%.1f" % [v.x, v.y, v.z]
