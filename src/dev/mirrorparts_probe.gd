## A mirrored part is its mirror image, or the mirror says it is not
## (mirrorfix). Mirror put a part with no other hand where its reflection
## is and turned it by its connectors: a headlight brick, whose face has
## none, read as the same front and back, and a cheese slope, whose slope
## has none, as the same both ways, so on a car's pod mirrored over MCP the
## headlight faced in, the slope fell the wrong way, and the tool said it
## had mirrored them (seeing2, 2026-11-06).
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/mirrorparts_probe.gd
##
## PROBE_SIZE=1280x720 tools/probe.sh mirrorparts runs it at a laptop's size.
## Keeps its pictures in MIRRORPARTS_SHOTS, or user://mirrorparts_probe.
## With `-- --library=DIR` every shape the parts bin offers is mirrored,
## not a sample, and the shapes with no mirror image are written to
## DIR/mirror_library.json (an hour on the GPU's box; headless is as good).
##
## Every check is by the parts' corners where they stand, the shape of each
## surface, not by part numbers:
##   1. the walk's pod (a 4 x 6 plate, a left wing plate, a 1 x 2 slope, a
##      headlight brick facing out, a cheese slope on it falling out), laid by
##      submit_design and mirrored by mirror_parts in 1 call as the walk
##      did: every part's corners lie on its source's reflected, to
##      APART_MOST, the headlight's face and the slope's fall point out on
##      both pods, and one undo takes it back;
##   2. shapes the bin offers, a sample spread through it, each mirrored on
##      its own in three poses and mirrored back: each the reflection of its
##      source (LIKE of its corners on it), its other hand where it has one,
##      or, a part made in one hand only and the same no way round, said to
##      have no mirror image (Builder.no_image), never silently wrong; and
##      back where it was, or, of two parts with one name whose other hand
##      the library makes once, back as the one that other hand is paired
##      with (listed);
##   3. the car's left half mirrored by the window's Mirror and by
##      mirror_parts: part for part alike, each its source's reflection; one
##      undo takes each back.
extends SceneTree

## The farthest a corner of a mirrored part may be from its source's
## reflected, LDU.
const APART_MOST := 0.01
## The same over the whole bin: a part's file keeps its corners to 1/64 LDU,
## and a few files' own two sides differ by that (3808, a Duplo half circle,
## by 0.016).
const APART_FILE := 0.02
## How near, LDU, a corner over the bin and the car must be to one of its
## source's reflected to lie on it: Mirror's own cell, an eighth of an LDU,
## a twentieth of a millimetre. A part's two sides are often that far apart
## in its file: 3003px1's print has 14% of its corners more than APART_FILE
## off its reflected and none a cell off, 57781's bucket 23%, and 71372-f2's
## formed tread has its corners' box 3/64 LDU off its middle, so every corner
## of its image is 0.09 off; 21 shapes over the bin lie 99.4% or more on
## their reflected within the cell and not within APART_FILE (mirrorfix). A
## part turned the wrong way is whole LDU off: the walk's headlight faced in.
const SEEN := 0.125
## The share of a part's corners, over the bin and the car, that must lie on
## its source's reflected for it to be that reflection: a part's file is not
## always its own mirror to the corner (2401's cut 0.16 LDU off its
## diagonal), and Mirror holds 98% in each colour; weighed over all colours
## and up to WEIGHED corners, 95% here. A part turned the wrong way lays a
## third or more off.
const LIKE := 0.95
const WEIGHED := 2000
## How many of the shapes the bin offers the sample mirrors, spread through
## them, besides NAMED.
const SAMPLE := 240
## Shapes always in the sample: the walk's, a corner the same only across
## its diagonal, round ones, a wheel, wedges made in two hands.
const NAMED: Array[String] = ["4070", "54200", "41769a", "41770a", "41769b", "41770b",
	"3040", "3032", "2357", "3001", "3005", "3062b", "4073", "6141", "3039", "3665", "2450",
	"43722", "43723", "55982", "56145", "3626b", "3815", "3816", "3818", "3819"]
## The walk's pod as its session laid it (seeing2's walk, s1).
const POD: Dictionary = {"name": "Side pod", "floor": "none", "bricks": [
	{"part": "3032", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 1},
	{"part": "41770", "color": 71, "x": 2, "y": 1, "z": 1},
	{"part": "3040", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1},
	{"part": "4070", "color": 4, "x": 3, "y": 1, "z": 5, "rot": 1},
	{"part": "54200", "color": 4, "x": 3, "y": 4, "z": 5, "rot": 1}],
	"description": "A little side pod on a red 4x6 plate: a left-hand wing plate along the "
		+ "right edge, a 1x2 slope at the back falling outwards, a headlight brick at the "
		+ "front facing outwards with a cheese slope on it."}

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _shell: Shell
var _camera: CadCamera
var _next: int = 0
var _shots: String = ""
var _whole: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	Engine.max_fps = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--library="):
			_whole = arg.trim_prefix("--library=")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_camera = _main.get("_camera")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	if DisplayServer.get_name() != "headless":
		_shots = OS.get_environment("MIRRORPARTS_SHOTS")
		if _shots.is_empty():
			_shots = OS.get_user_data_dir().path_join("mirrorparts_probe")
		DirAccess.make_dir_recursive_absolute(_shots)
	await process_frame

	if _whole.is_empty():
		await _pod()
		await _car()
	await _shapes()
	print("")
	print("mirrorparts: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	_main.queue_free()
	await _frames(5)
	quit(1 if _failures > 0 else 0)


# -- 1. the walk's pod ------------------------------------------------------------


func _pod() -> void:
	print("── the walk's pod, mirrored by mirror_parts ──")
	_main.call("clear_model")
	await _frames(5)
	var said: String = await _say("submit_design", POD)
	var pod: Array[int] = _model_ids()
	var parts: Array = pod.map(func(id: int) -> String: return _world.get_brick(id).part_id)
	_check("submit_design lays the walk's pod: %s" % ", ".join(parts), pod.size() == 5
		and parts.has("4070") and parts.has("54200"))
	if pod.size() != 5:
		print("    said: %s" % said.left(300))
		return
	var model: Array = _signature(pod)
	var depth: int = _builder.history_depth()
	var before: Dictionary = _ids_now()
	said = await _say("mirror_parts", {"bricks": pod, "axis": "x", "copy": true, "across": -1,
		"picture": false})
	print("    said: %s" % said)
	var made: Array = _made_since(before)
	_check("mirror_parts mirrors it in 1 call, one undo step (%d made)" % made.size(),
		made.size() == pod.size() and _builder.history_depth() == depth + 1)
	if made.size() != pod.size():
		return
	var plane: float = -1.0 * HandTools.STUD
	var worst: float = 0.0
	for n: int in pod.size():
		var from: BrickWorld.Brick = _world.get_brick(pod[n])
		var to: BrickWorld.Brick = _world.get_brick(made[n])
		var apart: float = _apart(_reflect(_corners(from.part_id, from.transform), plane),
			_corners(to.part_id, to.transform))
		worst = maxf(worst, apart)
		_check("%s %s → %s: on its reflection to %.4f LDU" % [from.part_id, _name(from.part_id),
			to.part_id, apart], apart <= APART_MOST)
	print("    the farthest any corner is from its reflection: %.4f LDU" % worst)
	# Out is +x on the pod, -x on its mirror beside it.
	for part: String in ["4070", "54200"]:
		var from: BrickWorld.Brick = _world.get_brick(pod[parts.find(part)])
		var to: BrickWorld.Brick = _world.get_brick(made[parts.find(part)])
		var faces: Vector3 = _faces(from.part_id, from.transform)
		var mirrored: Vector3 = _faces(to.part_id, to.transform)
		_check("the %s out on both pods: %s on the pod, %s on its mirror" % [
			"headlight's face points" if part == "4070" else "cheese slope falls",
			_way(faces), _way(mirrored)], faces.x > 0.5 and mirrored.x < -0.5)
	_check("...and it says no part was left without its mirror image",
		not said.contains("no mirror image"))
	await _shot("pod_front", "front")
	await _shot("pod_corner", "")
	said = await _say("undo", {})
	_check("one undo takes the mirror back: %s" % said.left(50), _signature(_model_ids()) == model)


## Which way a part's shape points, in the world, as a unit along x or z: a
## slope's fall (from its highest corners down), a part with no slope the
## side its corners lean to (a headlight brick's face, where its recess and
## stud are).
func _faces(part: String, at: Transform3D) -> Vector3:
	var corners: PackedVector3Array = _corners(part, Transform3D.IDENTITY)
	var low := Vector3.INF
	var high := -Vector3.INF
	var sum := Vector3.ZERO
	for corner: Vector3 in corners:
		low = low.min(corner)
		high = high.max(corner)
		sum += corner
	var middle: Vector3 = (low + high) * 0.5
	var lean: Vector3 = sum / maxf(corners.size(), 1.0) - middle
	var top := Vector3.ZERO
	var tops: int = 0
	for corner: Vector3 in corners:
		if corner.y > high.y - 0.5:
			top += corner
			tops += 1
	var fall: Vector3 = middle - top / maxf(tops, 1.0)
	var way: Vector3 = fall if Vector2(fall.x, fall.z).length() > 2.0 else lean
	way = at.basis * Vector3(way.x, 0.0, way.z)
	way.y = 0.0
	return Vector3(signf(way.x), 0.0, 0.0) if absf(way.x) >= absf(way.z) \
		else Vector3(0.0, 0.0, signf(way.z))


static func _way(way: Vector3) -> String:
	if way.x != 0.0:
		return "+x" if way.x > 0.0 else "−x"
	return "+z" if way.z > 0.0 else "−z"


# -- 3. the car's left half -------------------------------------------------------------


func _car() -> void:
	print("── the car's left half: the window's Mirror and mirror_parts ──")
	_main.call("clear_model")
	await _frames(5)
	var placed: int = _store.open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)
	var all: Array[int] = _model_ids()
	var middle: float = _box(all).get_center().x
	var left: Array[int] = []
	for brick_id: int in all:
		if _box([brick_id]).get_center().x < middle - 5.0:
			left.append(brick_id)
	var model: Array = _signature(all)
	_camera.set_view("front")
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.basis.x.x > 0.999:
			break
	var plane: float = snappedf(_box(left).get_center().x, BrickLattice.STUD * 0.5)
	var sources: Dictionary = {}
	for brick_id: int in left:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		sources[brick_id] = _reflect(_corners(brick.part_id, brick.transform), plane)
	_select(left)
	var before: Dictionary = _ids_now()
	var depth: int = _builder.history_depth()
	_shell.run("mirror")
	await _frames(5)
	var window_made: Array = _made_since(before)
	var window: Array = _signature(window_made)
	_check("the window's Mirror mirrors the car's %d left parts in one step (%d)" % [left.size(),
		window.size()], window.size() == left.size() and _builder.history_depth() == depth + 1)
	var worst: float = 0.0
	var off: int = 0
	var exact: int = 0
	var lone: PackedInt64Array = _lone()
	for n: int in mini(left.size(), window_made.size()):
		var to: BrickWorld.Brick = _world.get_brick(window_made[n])
		var corners: PackedVector3Array = _corners(to.part_id, to.transform)
		var away: float = _away(sources[left[n]], corners, WEIGHED)
		if lone.has(window_made[n]):
			continue
		if away > 1.0 - LIKE:
			off += 1
			print("    %s → %s has %.0f%% of its corners off its reflection" % [
				_world.get_brick(left[n]).part_id if _world.get_brick(left[n]) != null else "?",
				to.part_id, away * 100.0])
		worst = maxf(worst, away)
		exact += 1 if _apart(sources[left[n]], corners) <= APART_FILE else 0
	_check(("...each its source's reflection (%d to %.2f LDU, the most off %.1f%% of its "
		+ "corners), or said to have none (%d said, %d off)") % [exact, APART_FILE, worst * 100.0,
		lone.size(), off], off == 0)
	_builder.undo()
	await _frames(2)
	_check("...and one undo puts the car back", _signature(_model_ids()) == model)
	before = _ids_now()
	depth = _builder.history_depth()
	var said: String = await _say("mirror_parts", {"bricks": left, "picture": false})
	var session: Array = _signature(_made_since(before))
	_check("mirror_parts on the same parts: part for part what the window's Mirror gave (%d of %d)"
		% [_alike(session, window), window.size()], session == window
		and _builder.history_depth() == depth + 1)
	said = await _say("undo", {})
	_check("...and one undo puts the car back: %s" % said.left(50),
		_signature(_model_ids()) == model)


# -- 2. shapes the bin offers ------------------------------------------------------------------


func _shapes() -> void:
	print("── shapes the parts bin offers, each mirrored on its own and back ──")
	_main.call("clear_model")
	await _frames(5)
	var hashes: Dictionary = {}
	var offered: Array[String] = []
	for id: String in _library.ids():
		var info: PartLibrary.PartInfo = _library.parts[id]
		if info.is_redirect() or not info.reachable or hashes.has(info.mesh_hash):
			continue
		hashes[info.mesh_hash] = true
		offered.append(id)
	var chosen: Array[String] = []
	if _whole.is_empty():
		var stride: int = maxi(1, offered.size() / SAMPLE)
		for n: int in range(0, offered.size(), stride):
			chosen.append(offered[n])
		for named: String in NAMED:
			# A retired number as the part it became: the bin offers that.
			var id: String = _library.resolve(named)
			if _library.parts.has(id) and not chosen.has(id):
				chosen.append(id)
	else:
		chosen = offered
	print("    %d shapes in the bin, %d mirrored" % [offered.size(), chosen.size()])
	var poses: Array[Basis] = [Basis.IDENTITY, Basis(Vector3.UP, PI * 0.5),
		Basis(Vector3.BACK, PI * 0.5)]
	var counts: Dictionary = {"own": 0, "own_exact": 0, "hands": 0, "hands_exact": 0, "none": 0,
		"refused": 0, "missing": 0}
	var silent: Array = []
	var not_back: Array = []
	var one_for_two: Array[String] = []
	var lone_parts: Array = []
	var started: int = Time.get_ticks_msec()
	for n: int in chosen.size():
		var part: String = chosen[n]
		if _library.mesh_for(part) == null:
			counts["missing"] += 1
			continue
		var other: String = Mirror.counterpart(_library, part)
		var handed: bool = not other.is_empty() and _library.mesh_for(other) != null
		var said_none: bool = false
		var refused: bool = false
		var exact: bool = true
		var like: bool = true
		for pose: Basis in poses:
			var at := Transform3D(pose, Vector3(100, 400, 60))
			var source: PackedVector3Array = _corners(part, at)
			var brick_id: int = _world.add_brick(part, 4, at)
			_builder.register(brick_id, part, at)
			var made: PackedInt64Array = _builder.mirror_bricks(PackedInt64Array([brick_id]), 0,
				0.0)
			if made.is_empty():
				refused = true
				_drop(brick_id)
				continue
			var to: BrickWorld.Brick = _world.get_brick(made[0])
			var lone: bool = _lone().has(made[0])
			said_none = said_none or lone
			var mirrored: PackedVector3Array = _corners(to.part_id, to.transform)
			var away: float = _away(_reflect(source, 0.0), mirrored, WEIGHED)
			like = like and away <= 1.0 - LIKE
			exact = exact and away <= 1.0 - LIKE \
				and _apart(_reflect(source, 0.0), mirrored, 300) <= APART_FILE
			if handed and to.part_id != other:
				silent.append("%s %s (its other hand %s not taken, turned %s)" % [part, _name(part),
					other, _turn_words(pose)])
			elif away > 1.0 - LIKE and not lone and not handed:
				silent.append("%s %s (%.0f%% of its corners off, turned %s)" % [part, _name(part),
					away * 100.0, _turn_words(pose)])
			var back: PackedInt64Array = _builder.mirror_bricks(made, 0, 0.0)
			if back.is_empty():
				not_back.append("%s %s (refused back)" % [part, _name(part)])
				_drop(made[0])
				continue
			var again: BrickWorld.Brick = _world.get_brick(back[0])
			# Two parts of one name and one of its other hand's: that one is
			# the other hand of both, and its own other hand is one of them.
			var shared: bool = handed and again.part_id != part \
				and again.part_id == Mirror.counterpart(_library, other) \
				and _name(again.part_id) == _name(part)
			if shared:
				if not one_for_two.has(part):
					one_for_two.append(part)
			elif again.part_id != part or not (again.transform.origin.distance_to(at.origin)
					<= APART_MOST and again.transform.basis.is_equal_approx(at.basis)) \
					and _away(source, _corners(again.part_id, again.transform), WEIGHED) > 1.0 - LIKE:
				not_back.append("%s %s (turned %s)" % [part, _name(part), _turn_words(pose)])
			_drop(back[0])
		if refused:
			counts["refused"] += 1
		elif handed:
			counts["hands"] += 1
			counts["hands_exact"] += 1 if like else 0
		elif said_none:
			counts["none"] += 1
			lone_parts.append({"part": part, "name": _name(part)})
		else:
			counts["own"] += 1
			counts["own_exact"] += 1 if exact else 0
		if not _whole.is_empty():
			# Every shape the bin offers is more than memory holds at once.
			var cache: Dictionary = _library.get("_mesh_cache")
			cache.erase(_library.parts[part].mesh_hash)
			if not other.is_empty():
				cache.erase(_library.parts[other].mesh_hash)
			Later.script(&"Mirror").forget()
		if n % 500 == 499:
			print("    %d of %d, %d s" % [n + 1, chosen.size(),
				(Time.get_ticks_msec() - started) / 1000])
	print(("    %d its own mirror image (%d to %.2f LDU), %d made in a left and a right hand (%d "
		+ "the other's reflection, the rest a print or a half for each side), %d with no mirror "
		+ "image, %d refused, %d with no shape here") % [counts["own"], counts["own_exact"],
		APART_FILE, counts["hands"], counts["hands_exact"], counts["none"], counts["refused"],
		counts["missing"]])
	for row: Dictionary in lone_parts.slice(0, 12):
		print("      no mirror image, said: %s %s" % [row["part"], row["name"]])
	for row: String in silent.slice(0, 12):
		print("      SILENT: %s" % row)
	for row: String in not_back.slice(0, 12):
		print("      NOT BACK: %s" % row)
	_check("every shape mirrored is its reflection, or said to have none (%d silently wrong of %d)"
		% [silent.size(), chosen.size()], silent.is_empty() and counts["own"] + counts["hands"] > 0)
	_check(("...and mirrored back is where it was, in all three poses (%d not; %d whose other "
		+ "hand the library makes once for two parts of their name come back as the one paired "
		+ "with it: %s)") % [not_back.size(), one_for_two.size(), ", ".join(one_for_two.slice(0,
		6))], not_back.is_empty())
	_check(("...the walk's headlight brick and cheese slope are their own mirror images, the "
		+ "wing plates each other's"),
		not lone_parts.any(func(row: Dictionary) -> bool: return str(row["part"]) in ["4070",
			"54200", "41769a", "41770a"]))
	if not _whole.is_empty():
		DirAccess.make_dir_recursive_absolute(_whole)
		var file: FileAccess = FileAccess.open(_whole.path_join("mirror_library.json"),
			FileAccess.WRITE)
		file.store_string(JSON.stringify({"shapes": offered.size(), "mirrored": chosen.size(),
			"counts": counts, "no_mirror_image": lone_parts, "silent": silent,
			"not_back": not_back, "one_other_hand_for_two": one_for_two}, "  "))
		file.close()
		print("    written to %s" % _whole.path_join("mirror_library.json"))


func _drop(brick_id: int) -> void:
	_world.remove_brick(brick_id)
	_builder.lattice.release(brick_id)


func _lone() -> PackedInt64Array:
	var lone: Variant = _builder.get("no_image")
	return lone if lone is PackedInt64Array else PackedInt64Array()


static func _turn_words(pose: Basis) -> String:
	if pose.is_equal_approx(Basis.IDENTITY):
		return "as it is"
	return "a quarter round" if pose.y.is_equal_approx(Vector3.UP) else "on its side"


# -- geometry ------------------------------------------------------------------------------


## A part's corners where it stands: every surface's, in the world, once each.
func _corners(part: String, at: Transform3D) -> PackedVector3Array:
	var shape: Lbm.PartMesh = _library.mesh_for(part)
	var seen: Dictionary = {}
	var out := PackedVector3Array()
	if shape == null:
		return out
	var lists: Array = []
	for mesh: ArrayMesh in shape.surfaces:
		for n: int in mesh.get_surface_count():
			lists.append(mesh.surface_get_arrays(n))
	lists.append_array(shape.arrays)
	for arrays: Array in lists:
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var key := Vector3i((point * 64.0).round())
			if not seen.has(key):
				seen[key] = true
				out.append(at * point)
	return out


static func _reflect(points: PackedVector3Array, plane: float) -> PackedVector3Array:
	var out := PackedVector3Array(points)
	for n: int in out.size():
		var point: Vector3 = out[n]
		point.x = 2.0 * plane - point.x
		out[n] = point
	return out


## The farthest a point of either set is from the nearest of the other, LDU;
## 99 when one has a point with none of the other within a cell. With
## [param most], that many points of each spread through it are weighed.
static func _apart(one: PackedVector3Array, other: PackedVector3Array, most: int = 0) -> float:
	if one.is_empty() or other.is_empty():
		return 0.0 if one.size() == other.size() else 99.0
	return maxf(_farthest(one, other, most), _farthest(other, one, most))


## The larger share of either set's points with none of the other within
## SEEN, up to [param most] of each spread through it.
static func _away(one: PackedVector3Array, other: PackedVector3Array, most: int) -> float:
	if one.is_empty() or other.is_empty():
		return 0.0 if one.size() == other.size() else 1.0
	return maxf(_off(one, other, most), _off(other, one, most))


static func _off(from: PackedVector3Array, onto: PackedVector3Array, most: int) -> float:
	var grid: Dictionary = {}
	for point: Vector3 in onto:
		var cell := Vector3i(point.floor())
		var here: PackedVector3Array = grid.get(cell, PackedVector3Array())
		here.append(point)
		grid[cell] = here
	var stride: int = maxi(1, from.size() / most)
	var seen: int = 0
	var off: int = 0
	for n: int in range(0, from.size(), stride):
		var point: Vector3 = from[n]
		var cell := Vector3i(point.floor())
		var found: bool = false
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for there: Vector3 in grid.get(cell + Vector3i(dx, dy, dz),
							PackedVector3Array()) as PackedVector3Array:
						if point.distance_to(there) <= SEEN:
							found = true
							break
		seen += 1
		off += 0 if found else 1
	return float(off) / float(maxi(seen, 1))


static func _farthest(from: PackedVector3Array, onto: PackedVector3Array, most: int) -> float:
	var grid: Dictionary = {}
	for point: Vector3 in onto:
		var cell := Vector3i(point.floor())
		var here: PackedVector3Array = grid.get(cell, PackedVector3Array())
		here.append(point)
		grid[cell] = here
	var stride: int = 1 if most <= 0 else maxi(1, from.size() / most)
	var worst: float = 0.0
	for n: int in range(0, from.size(), stride):
		var point: Vector3 = from[n]
		var cell := Vector3i(point.floor())
		var nearest: float = 99.0
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var near: Variant = grid.get(cell + Vector3i(dx, dy, dz))
					if near == null:
						continue
					for there: Vector3 in near as PackedVector3Array:
						nearest = minf(nearest, point.distance_to(there))
		worst = maxf(worst, nearest)
	return worst


# -- the app -------------------------------------------------------------------------------


func _name(part: String) -> String:
	var info: PartLibrary.PartInfo = _library.parts.get(part)
	return Inventory._tidy(info.name) if info != null else part


func _select(ids: Array) -> void:
	_builder.selection.clear()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _model_ids() -> Array[int]:
	var ids: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


func _ids_now() -> Dictionary:
	var now: Dictionary = {}
	for brick_id: int in _model_ids():
		now[brick_id] = true
	return now


func _made_since(before: Dictionary) -> Array:
	return _model_ids().filter(func(brick_id: int) -> bool: return not before.has(brick_id))


func _box(ids: Array) -> AABB:
	return _builder._bounds_of(PackedInt64Array(ids), Transform3D.IDENTITY)


## Each part as what it is and where, sorted: two sets of parts alike when
## these are.
func _signature(ids: Array) -> Array:
	var rows: Array = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		var t: Transform3D = brick.transform
		var row := PackedStringArray([brick.part_id, str(brick.color_code)])
		for v: Vector3 in [t.origin, t.basis.x, t.basis.y, t.basis.z]:
			for n: int in 3:
				row.append(str(snappedf(v[n], 0.01) + 0.0))
		rows.append("|".join(row))
	rows.sort()
	return rows


static func _alike(one: Array, other: Array) -> int:
	var left: Array = other.duplicate()
	var count: int = 0
	for row: Variant in one:
		var at: int = left.find(row)
		if at >= 0:
			left.remove_at(at)
			count += 1
	return count


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## What the person sees from [param view] ("" for the view the app opens
## at), kept when there is a window to see it in.
func _shot(name: String, view: String) -> void:
	if _shots.is_empty():
		return
	_camera.set_view(view)
	await _frames(40)
	_camera.frame(_box(_model_ids()))
	await _frames(30)
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _shots.path_join("%s_%dx%d.png" % [name, size.x, size.y])
	root.get_viewport().get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
