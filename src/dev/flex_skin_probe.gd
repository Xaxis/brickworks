## Prove LDCad's flexible parts in a file are drawn (CustomParts.begin_skins).
##
##   godot --headless --path . --script src/dev/flex_skin_probe.gd [-- FILE ...]
##
## A file written as LDCad writes one: a band whose skin is primitives and
## nothing else, and a tube whose skin is a donor section bent twice and a
## polygon, between two parts at its ends. Then:
##
## - each skin is one piece, in its sub-model's copy, in the copy's colour,
##   where the file puts it, drawn with every face the file gives it; the
##   tube's ends are parts still; nothing is left out or said missing;
## - a piece is in the pointer's way where it is drawn, and not once hidden;
##   its copy is in the step the file places it in;
## - saved untouched, the file is the same, line for line;
## - a piece taken away, or moved, is written whole (one line cannot say
##   it), and opens again as edited: the piece gone, or where it was moved,
##   carried as a part of the file's;
## - opened again with no library to hand (as the web build is), the skin of
##   bundled primitives still builds.
##
## With FILE arguments (the repository's own files), each is opened: every
## copy of every sub-model LDCad generated a skin into must have its piece,
## nothing flexible may be said missing, and the file saved untouched must be
## itself. Fails on the first that is not.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore

const FILE := """0 FILE flexprobe - main.ldr
0 Flex probe
0 Name: flexprobe - main.ldr
0 Author: Somebody Else [someone]
0 !LDRAW_ORG Model
0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt

1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 71 0 -96 200 1 0 0 0 1 0 0 0 1 flexprobe - band.ldr
0 STEP
1 2 60 -48 0 1 0 0 0 1 0 0 0 1 flexprobe - tube.ldr
0 STEP
0 NOFILE
0 FILE flexprobe - band.ldr
0 Band
0 Name: flexprobe - band.ldr
0 Author: Somebody Else [someone]
0 !LDRAW_ORG Model
0 !LDCAD CONTENT [type=path] [addFallBack=default]
0 !LDCAD PATH_POINT [type=bezier] [posOri=0 0 0 1 0 0 0 1 0 0 0 1]
0 !LDCAD PATH_SKIN [donCol=16] [donPart=4-4cyli.dat]
0 !LDCAD GENERATED [generator=LDCad 1.6b]
0 // Do not edit, any changes will be lost upon regeneration.
0 UNOFFICIAL PART
0 BFC CERTIFY CCW
1 16 0 0 0 4 0 0 0 1 0 0 0 4 4-4cyli.dat
1 16 0 -1 0 4 0 0 0 1 0 0 0 4 4-4cyli.dat
1 16 0 -2 0 4 0 0 0 1 0 0 0 4 4-4cyli.dat
0 NOFILE
0 FILE flexprobe - tube.ldr
0 Tube
0 Name: flexprobe - tube.ldr
0 Author: Somebody Else [someone]
0 !LDRAW_ORG Model
0 !LDCAD CONTENT [type=path] [addFallBack=default]
0 !LDCAD PATH_SKIN [donCol=16] [donPart=flexprobe - donor.dat]
0 !LDCAD PATH_CAP [group=start] [color=16] [part=3062b.dat]
0 !LDCAD GENERATED [generator=LDCad 1.6b]
0 UNOFFICIAL PART
0 BFC CERTIFY CCW
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3062b.dat
1 16 0 -20 0 1 0 0 0 1 0 0 0 1 flexprobe - donor.dat
1 16 0 -40 0 1 0 0.25 0 1 0 0 0 1 flexprobe - donor.dat
4 16 -6 -60 -6 6 -60 -6 6 -60 6 -6 -60 6
1 16 0 -84 0 1 0 0 0 1 0 0 0 1 3062b.dat
0 NOFILE
0 FILE flexprobe - donor.dat
0 donor
0 Name: flexprobe - donor.dat
0 Author: LDCad
0 UNOFFICIAL PRIMITIVE
0 BFC CERTIFY CCW
1 16 0 0 0 6 0 0 0 20 0 0 0 6 4-4cyli.dat
0 NOFILE
"""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	CustomParts.dir = OS.get_user_data_dir().path_join("flex_skin_probe_parts/")
	CustomParts.keeps = false
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("flexskin: FAIL the catalogue does not load")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.builder = _builder
	_store.library = _library
	_store.keeps = false
	await process_frame

	_drawn()
	_taken_away()
	_moved()
	_without_library()
	for path: String in OS.get_cmdline_user_args():
		_repository(path)
	print("flexskin: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _expect(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _open(text: String, name: String = "flexprobe") -> Dictionary:
	_world.clear()
	return _store.open_text(text, name)


func _skins() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return CustomParts.is_skin_text(_library.custom_source(b.part_id)))


func _one(part_id: String) -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id:
			return brick
	return null


## What the app holds: "part colour x y z" a part, sorted.
func _model() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin
		out.append("%s %d %.1f %.1f %.1f" % [brick.part_id, brick.color_code,
			snappedf(at.x, 0.1) + 0.0, snappedf(at.y, 0.1) + 0.0, snappedf(at.z, 0.1) + 0.0])
	out.sort()
	return out


## The lines of [param after] that differ from [param before], the app's own
## meta lines left out.
static func _differ(before: String, after: String) -> Array:
	var kept := PackedStringArray()
	for line: String in after.split("\n"):
		if not line.begins_with("0 !BRICKWORKS "):
			kept.append(line)
	var a: PackedStringArray = before.split("\n")
	var out: Array = []
	for n: int in maxi(a.size(), kept.size()):
		var x: String = a[n] if n < a.size() else "<none>"
		var y: String = kept[n] if n < kept.size() else "<none>"
		if x != y:
			out.append("line %d: %s  =>  %s" % [n + 1, x, y])
	return out


func _drawn() -> void:
	print("flexskin: drawn as the file has them")
	var opened: Dictionary = _open(FILE)
	var lift: float = _store._lifted_by
	_expect(int(opened["missing"]) == 0 and (opened.get("unshown", {}) as Dictionary).is_empty(),
		"nothing missing, nothing said not shown: %s" % opened.get("unshown", {}))
	var band: BrickWorld.Brick = _one("flexprobe - band-flex")
	var tube: BrickWorld.Brick = _one("flexprobe - tube-flex")
	_expect(band != null and tube != null, "the band and the tube each a piece")
	_expect(_skins().size() == 2, "two pieces of skin, one a flexible part: %d" % _skins().size())
	if band == null or tube == null:
		return
	_expect(band.unit == "Band#1" and tube.unit == "Tube#1",
		"each in its sub-model's copy: %s, %s" % [band.unit, tube.unit])
	_expect(band.color_code == 71 and tube.color_code == 2,
		"each in its copy's colour: %d, %d" % [band.color_code, tube.color_code])
	_expect(band.transform.origin.is_equal_approx(Vector3(0, 96 + lift, -200)),
		"the band where the file puts it: %s" % band.transform.origin)
	var band_mesh: Lbm.PartMesh = _library.mesh_for(band.part_id)
	var tube_mesh: Lbm.PartMesh = _library.mesh_for(tube.part_id)
	_expect(_library.parts[band.part_id].triangles == 96,
		"the band's three cylinders, 32 faces each: %d" % _library.parts[band.part_id].triangles)
	_expect(_library.parts[tube.part_id].triangles == 66,
		"the tube's donor twice and its quad: %d faces" % _library.parts[tube.part_id].triangles)
	_expect(band_mesh != null and is_equal_approx(band_mesh.bounds.size.x, 8.0)
		and is_equal_approx(band_mesh.bounds.size.y, 3.0),
		"the band 8 across and 3 high, as its primitives are: %s" % (
			band_mesh.bounds if band_mesh != null else AABB()))
	_expect(tube_mesh != null and tube_mesh.bounds.size.y > 59.0,
		"the tube 60 high, the donor drawn twice and sheared once: %s" % (
			tube_mesh.bounds if tube_mesh != null else AABB()))
	var ends: int = _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3062b" and b.unit == "Tube#1").size()
	_expect(ends == 2, "the tube's ends parts still: %d" % ends)
	_expect(not _library.parts[band.part_id].reachable, "not a part the bin offers")
	# In the pointer's way where it is drawn, and not once hidden.
	var top := Vector3(0.0, 400.0, -200.0)
	var hit: BrickLattice.Hit = _builder.lattice.raycast(top, Vector3.DOWN)
	_expect(hit.is_valid() and hit.brick_id == band.id,
		"a click straight down onto the band selects the band (%d)" % hit.brick_id)
	_builder.lattice.unseen[band.id] = true
	hit = _builder.lattice.raycast(top, Vector3.DOWN)
	_expect(not hit.is_valid() or hit.brick_id != band.id, "hidden, the pointer passes it")
	_builder.lattice.unseen.clear()
	_expect(int(_world.unit_steps.get("Band#1", -1)) == 1
		and int(_world.unit_steps.get("Tube#1", -1)) == 2,
		"each copy in the step the file places it in: band %s, tube %s" % [
			_world.unit_steps.get("Band#1"), _world.unit_steps.get("Tube#1")])
	var saved: String = _store.to_text(_store.title, true)
	var differ: Array = _differ(FILE, saved)
	_expect(differ.is_empty(), "saved untouched, the same file line for line: %s"
		% "; ".join(differ))


func _taken_away() -> void:
	print("flexskin: a piece taken away")
	_open(FILE)
	var band: BrickWorld.Brick = _one("flexprobe - band-flex")
	if band == null:
		_expect(false, "no band to take away")
		return
	_builder.remove_brick_id(band.id)
	var model: PackedStringArray = _model()
	var saved: String = _store.to_text(_store.title, true)
	_expect(saved.contains("0 Author: Somebody Else [someone]"),
		"written whole, under its author's name")
	_open(saved)
	_expect(_model() == model, "opened again, the band gone and the rest as it was")
	_expect(_one("flexprobe - tube-flex") != null, "the tube still drawn")


func _moved() -> void:
	print("flexskin: a piece moved")
	_open(FILE)
	var tube: BrickWorld.Brick = _one("flexprobe - tube-flex")
	if tube == null:
		_expect(false, "no tube to move")
		return
	_builder.move_bricks({tube.id: tube.transform.translated(Vector3(40, 0, 0))})
	var model: PackedStringArray = _model()
	var saved: String = _store.to_text(_store.title, true)
	_expect(saved.contains("0 FILE flexprobe - tube-flex.dat")
		and saved.contains("0 FILE flexprobe - donor.dat"),
		"written whole, the skin carried as a part with the donor it is drawn from")
	_open(saved)
	_expect(_model() == model, "opened again, the tube where it was moved, its ends where they were")
	_expect(_skins().size() == 2, "and both drawn: %d" % _skins().size())


func _without_library() -> void:
	print("flexskin: the skin of bundled primitives, without the library")
	var built: PartForge.Result = PartForge.build_skin(
		"0 band\n0 !LDRAW_ORG Unofficial_Part\n%s\n1 16 0 0 0 4 0 0 0 1 0 0 0 4 4-4cyli.dat\n"
			% CustomParts.SKIN_MARK, "probe-band", {}, false)
	_expect(built.problem.is_empty() and built.triangles == 32,
		"built from what every build ships: %s (%d faces)" % [built.problem, built.triangles])


## Every copy of every sub-model LDCad generated a skin into, drawn.
func _repository(path: String) -> void:
	print("flexskin: %s" % path.get_file())
	var text: String = FileAccess.get_file_as_string(path)
	var model: LdrModel = LdrModel.parse(text, path.get_file())
	var began: int = Time.get_ticks_msec()
	var opened: Dictionary = _open(text, path.get_file().get_basename())
	var open_ms: int = Time.get_ticks_msec() - began
	# What should be drawn: every copy of a generated sub-model.
	var wanted: int = 0
	var flat: Array = model.flatten(_library.parts)
	for unit: String in model.unit_sections:
		if model.generated.has(str(model.unit_sections[unit])):
			wanted += 1
	var pieces: Array = _skins()
	var faces: int = 0
	var units: Dictionary = {}
	for brick: BrickWorld.Brick in pieces:
		faces += _library.parts[brick.part_id].triangles
		units[brick.unit] = true
	var flexible: Array = (opened.get("unshown", {}) as Dictionary).keys().filter(
		func(named: String) -> bool: return named.contains("(flexible)"))
	# A generated copy with nothing but parts in it has no skin to draw.
	var skinless: int = 0
	for unit: String in model.unit_sections:
		if model.generated.has(str(model.unit_sections[unit])) and not units.has(unit):
			skinless += 1
	print("  note %d pieces of skin, %d faces, in %d of %d generated copies (%d ms open, %d parts)"
		% [pieces.size(), faces, units.size(), wanted, open_ms, flat.size()])
	_expect(flexible.is_empty(), "no flexible part said not shown: %s" % [flexible])
	_expect(pieces.size() > 0, "its flexible parts drawn: %d pieces" % pieces.size())
	var differ: Array = _differ(text, _store.to_text(_store.title, true))
	_expect(differ.is_empty(), "saved untouched, the same file: %s"
		% "; ".join(differ.slice(0, 4)))
	if skinless > 0:
		print("  note %d generated copies draw only parts (a chain, a hose of segments)" % skinless)
