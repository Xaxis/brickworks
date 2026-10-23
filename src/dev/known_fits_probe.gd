## The fits official sets are built with, forgiven, and nothing else
## (KnownFits, assets/ldraw/known_fits.json).
##
##   godot --headless --path . --script src/dev/known_fits_probe.gd
##
## Real sets whose only collisions were their figures' (a helmet against a
## roof, a backpack against a head, legs in a carriage's seat, a hand on a
## door) pass the collision part of Tested's whole test now, and fail it in
## a run kept to BrickBench's parts, whose verify.py forgives none of it. A
## brick pushed 2 LDU into a brick, from above or beside it, and a minifig
## torso pushed 6 LDU into a wall stay collisions. A wizard's long beard
## through his cape stays one: no official set wears one so. Gandalf as
## 71200-1 dresses him, his beard over a cloth cape, has none.
extends SceneTree

## Small sets that failed only on their figures, by the scan the table was
## learned from.
const SETS: Array[String] = ["1477-1.mpd", "6022-1.mpd", "6537-1.mpd", "6644-1.mpd",
	"6799-1_Carriage.mpd", "7306-1.mpd"]
const OMR := "res://vendor/omr/files/"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _store: ModelStore


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
	var builder := Builder.new()
	builder.world = _world
	builder.library = _library
	get_root().add_child(builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = builder
	_store.keeps = false
	await process_frame
	if Exact.shape_for(_library, "3001") == null:
		print("known_fits probe: SKIPPED, no exact shapes in this build")
		quit(3)
		return
	_ok(KnownFits.reach("3626b", "3838", Transform3D.IDENTITY) > Exact.TAU,
		"the table is read: a head and a backpack meet up to %.2f LDU" % KnownFits.reach(
		"3626b", "3838", Transform3D.IDENTITY))

	print("\nreal sets that failed only on their figures")
	for file: String in SETS:
		if not FileAccess.file_exists(OMR + file):
			_ok(false, "%s is in vendor/omr (tools/omr.py fetch)" % file)
			continue
		_store.open_text(FileAccess.get_file_as_string(OMR + file), file)
		var parts: Array = []
		for brick: BrickWorld.Brick in _world.bricks():
			parts.append([brick.part_id, brick.transform])
		var now: Array = _into(parts)
		PartsOnly.use(PackedStringArray(["3001"]), "a probe's list")
		var bench: Array = _into(parts)
		PartsOnly.use(PackedStringArray())
		_ok(now.is_empty() and not bench.is_empty(), "%s (%d parts): %s now, and %s kept to BrickBench's parts" % [
			file, parts.size(), _said(now), _said(bench)])

	print("\nwhat no set does")
	var on_top: Array = _into(_placed([["3001", 0, 0, 0], ["3001", 0, -22, 0]]))
	_ok(_has(on_top, "3001", "3001", 2.0), "a brick pushed 2 LDU down into the brick under it collides: %s" % _said(on_top))
	var beside: Array = _into(_placed([["3001", 0, 0, 0], ["3001", 78, 0, 0]]))
	_ok(_has(beside, "3001", "3001", 2.0), "...and one pushed 2 LDU into the brick beside it: %s" % _said(beside))
	# A wall of 1 x 4 bricks four high, and a torso in front of it at its
	# middle, moved into its face by 6 LDU and by 2.
	var wall: Array = _placed([["3010", 0, 0, 0], ["3010", 0, -24, 0], ["3010", 0, -48, 0],
		["3010", 0, -72, 0], ["973", 0, -60, 40]])
	var torso: Transform3D = wall.pop_back()[1]
	var face: Exact.Item = Exact.Item.new(Exact.shape_for(_library, "3010"), wall[0][1])
	var front: Exact.Item = Exact.Item.new(Exact.shape_for(_library, "973"), torso)
	# Which way the torso is from the wall, in the app's axes.
	var way: float = signf(front.lo.z + front.hi.z - face.lo.z - face.hi.z)
	var gap: float = front.lo.z - face.hi.z if way > 0.0 else face.lo.z - front.hi.z
	for depth: float in [6.0, 2.0]:
		var moved := Transform3D(torso.basis, torso.origin - Vector3(0, 0, way * (gap + depth)))
		var found: Array = _into(wall + [["973", moved]])
		if depth > 4.0:
			_ok(_has(found, "3010", "973", depth), "a minifig torso pushed %d LDU into a wall collides: %s" % [
				depth, _said(found)])
		else:
			_ok(found.is_empty(), "...where %d LDU into it is a figure against it, as sets have them: %s" % [
				depth, _said(found)])

	print("\na wizard's beard")
	# The grey wizard as orthanc177 dressed him before the cape came off:
	# a long forked beard over a plastic cape.
	var grey: Array = _into(_placed([["973psx", 0, -72, 1.25], ["4524", 0, -74, 1.25],
		["60750", 0, -72, 1.25], ["3626cpbb", 0, -99, 1.25], ["6131", 0, -99, 1.25]]))
	_ok(_has(grey, "4524", "60750", 2.0), "a long beard through a plastic cape still collides, as no set wears them: %s" % _said(grey))
	# Gandalf as 71200-1 dresses him: beard and cloth cape at the torso's
	# own place, his head and hat 24 LDU up.
	var gandalf: Array = _into(_placed([["973pm1", 0, 24, 0], ["10052", 0, 24, 0],
		["50231c01", 0, 24, 0], ["3626c", 0, 0, 0], ["6131", 0, 0, 0]]))
	_ok(gandalf.is_empty(), "Gandalf as 71200-1 dresses him, a beard over a cloth cape, passes: %s" % _said(gandalf))

	print("%d FAILED" % _failures if _failures else "official sets' fits are forgiven, and nothing else")
	quit(1 if _failures else 0)


## What the collision part of Tested's whole test refuses of these parts
## ([part, Transform3D] each): [part a, part b, how deep] each.
func _into(placed: Array) -> Array:
	var parts: Array = []
	var ids: Dictionary = {}
	for one: Array in placed:
		parts.append([one[0], one[1], _library.mesh_for(str(one[0]))])
		ids[one[0]] = true
	var shapes: Dictionary = Exact.shapes_for(_library, ids.keys())
	var found: Dictionary = Tested._exact_whole(parts, shapes, [], [], {})
	var out: Array = []
	for pair: Array in found["into"]:
		var a: int = pair[0]
		var b: int = pair[1]
		var deepest: float = 0.0
		for hit: Array in Exact.overlaps(Exact.Item.new(shapes[parts[a][0]], parts[a][1]),
				Exact.Item.new(shapes[parts[b][0]], parts[b][1])):
			deepest = maxf(deepest, float(hit[0]))
		out.append([parts[a][0], parts[b][0], deepest])
	return out


## Whether [param found] has parts [param a] and [param b] passing into each
## other by at least [param depth], LDU.
func _has(found: Array, a: String, b: String, depth: float) -> bool:
	for pair: Array in found:
		if ([pair[0], pair[1]] == [a, b] or [pair[0], pair[1]] == [b, a]) \
				and float(pair[2]) >= depth - 0.01:
			return true
	return false


func _said(found: Array) -> String:
	if found.is_empty():
		return "no collisions"
	var out := PackedStringArray()
	for pair: Array in found.slice(0, 4):
		out.append("%s in %s %.1f LDU" % [pair[0], pair[1], float(pair[2])])
	return "%d collisions (%s%s)" % [found.size(), ", ".join(out), ", ..." if found.size() > 4 else ""]


## Parts as an LDraw file puts them ([part, x, y, z] each, unturned), opened
## as File, Open opens one: [part, where the app has it] each.
func _placed(rows: Array) -> Array:
	var lines := PackedStringArray(["0 FILE placed.ldr", "0 placed", "0 Name: placed.ldr", ""])
	for row: Array in rows:
		lines.append("1 16 %s %s %s 1 0 0 0 1 0 0 0 1 %s.dat" % [row[1], row[2], row[3], row[0]])
	_store.open_text("\r\n".join(lines) + "\r\n", "placed.ldr")
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		out.append([brick.part_id, brick.transform])
	return out


func _ok(passed: bool, what: String) -> void:
	print(("ok   " if passed else "FAIL ") + what)
	if not passed:
		_failures += 1
