## finishpass (APP_UX10 #9): Edit › Finish the surfaces…, a set designer's
## finishing pass for a person (FinishBar, over SurfacePass).
##
## On 10 hand-built models, through the window's own command: what the pass
## will lay is shown first (a count and a ghost per kind) with nothing
## changed; Lay puts it down as one undo step, and Undo puts the file back
## byte for byte; each kind left out by its tick lays none of its parts;
## check_design finds no part floating or overlapping that it did not find
## before; whatever stood on a part the pass took off still stands. A
## selection limits the pass to what is on it. On Orthanc and 10179 the
## reading is spread over frames, no frame over 100 ms of its own, the
## status bar saying so, and it finds what the AI's reading (find() on the
## main thread) finds, to the placement.
##
##   godot --headless --path . --script src/dev/finishpass_probe.gd
##   ... -- --phone        the bar by a finger at 390 x 844 (by hand);
##                         FP_PHONE=430x932 at that size
##   FP_SHOTS=DIR          windowed: before, shown and after pictures of the 10
##   FP_IDENTITY=1         the two speedups read against the old reading
extends "res://src/dev/copyfaults_probe.gd"

const MODELS: Array = ["walk wall", "stepped roof", "car bonnet", "g3 house", "speeder hull",
	"res://models/house.ldr", "res://models/car.ldr", "res://models/corner_shop.ldr",
	"res://models/kart.ldr", "res://models/lighthouse.ldr"]
const BIG: Array = ["res://models/orthanc.ldr", "res://vendor/omr/files/10179-1.mpd"]

## The MCP walk's g3: a small brick house with a stepped roof, as its session
## submitted it (uxplan10-2026-11-19/mcp/run/g3.jsonl).
const G3: Array = [{"part": "3008", "color": 19, "x": 0, "y": 0, "z": 0},
	{"part": "3622", "color": 19, "x": 0, "y": 0, "z": 5}, {"part": "3622", "color": 19, "x": 5, "y": 0, "z": 5},
	{"part": "3010", "color": 19, "x": 0, "y": 0, "z": 1, "rot": 1},
	{"part": "3010", "color": 19, "x": 7, "y": 0, "z": 1, "rot": 1},
	{"part": "3009", "color": 19, "x": 0, "y": 3, "z": 0, "rot": 1},
	{"part": "3009", "color": 19, "x": 7, "y": 3, "z": 0, "rot": 1},
	{"part": "3009", "color": 19, "x": 1, "y": 3, "z": 0}, {"part": "3004", "color": 19, "x": 1, "y": 3, "z": 5},
	{"part": "3004", "color": 19, "x": 5, "y": 3, "z": 5}, {"part": "3008", "color": 19, "x": 0, "y": 6, "z": 0},
	{"part": "3008", "color": 19, "x": 0, "y": 6, "z": 5},
	{"part": "3010", "color": 19, "x": 0, "y": 6, "z": 1, "rot": 1},
	{"part": "3010", "color": 19, "x": 7, "y": 6, "z": 1, "rot": 1},
	{"part": "3009", "color": 19, "x": 0, "y": 9, "z": 0, "rot": 1},
	{"part": "3009", "color": 19, "x": 7, "y": 9, "z": 0, "rot": 1},
	{"part": "3009", "color": 19, "x": 1, "y": 9, "z": 0}, {"part": "3009", "color": 19, "x": 1, "y": 9, "z": 5},
	{"part": "3001", "color": 320, "x": 0, "y": 12, "z": 0}, {"part": "3001", "color": 320, "x": 4, "y": 12, "z": 0},
	{"part": "3001", "color": 320, "x": 0, "y": 12, "z": 2}, {"part": "3001", "color": 320, "x": 4, "y": 12, "z": 2},
	{"part": "3001", "color": 320, "x": 0, "y": 12, "z": 4}, {"part": "3001", "color": 320, "x": 4, "y": 12, "z": 4},
	{"part": "3003", "color": 320, "x": 0, "y": 15, "z": 1}, {"part": "3001", "color": 320, "x": 2, "y": 15, "z": 1},
	{"part": "3003", "color": 320, "x": 6, "y": 15, "z": 1}, {"part": "3003", "color": 320, "x": 0, "y": 15, "z": 3},
	{"part": "3001", "color": 320, "x": 2, "y": 15, "z": 3}, {"part": "3003", "color": 320, "x": 6, "y": 15, "z": 3},
	{"part": "3007", "color": 320, "x": 0, "y": 18, "z": 2}]

var _finger: bool = false
var _shots: String = ""
var _summary: PackedStringArray = PackedStringArray()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_finger = args.has("--phone")
	if _finger:
		Phone._on = 1
		Phone._wide = false
	_shots = OS.get_environment("FP_SHOTS") if DisplayServer.get_name() != "headless" else ""
	if not _shots.is_empty():
		DirAccess.make_dir_recursive_absolute(_shots)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	if _finger:
		await _as_finger()
		await _case_phone()
	elif OS.get_environment("FP_IDENTITY") == "1":
		for path: String in BIG:
			await _case_identity(path)
	else:
		for model: String in MODELS:
			await _case_model(model)
		await _case_selection()
		await _case_registry()
		# Pictures are of the 10; a window's frames are not the bar's time.
		if _shots.is_empty():
			for path: String in BIG:
				await _case_time(path)
	print("\n".join(_summary))
	print("finishpass: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the cases ------------------------------------------------------------------------


func _case_model(model: String) -> void:
	await _make(model)
	var name: String = model.get_file().get_basename()
	var before: String = _store.saved_text()
	var depth: int = _builder.history_depth()
	var ids_before: Dictionary = _ids()
	var check_before: String = await _check_now()
	await _shot(name + "_before")
	var bar: FinishBar = await _open_bar()
	if not _check("%s: the bar read the model" % name, bar != null and not bar.busy):
		return
	var counted: Dictionary = bar.counts()
	_check("%s: shown first, nothing changed (kinds %s, %d ghosts)" % [name, str(counted),
		bar._ghosts.size()], not counted.is_empty() and _store.saved_text() == before
		and _builder.history_depth() == depth and bar._ghosts.size() == counted.size()
		and _ghosts_drawn(bar))
	await _shot(name + "_shown")
	var found: Dictionary = bar.found.duplicate()
	var sitters: Dictionary = _sitters(bar, found)
	var laid: Dictionary = await bar.lay_now()
	await _frames(6)
	var check_after: String = await _check_now()
	var gone: Array = ids_before.keys().filter(func(id: Variant) -> bool:
		return _world.get_brick(int(id)) == null)
	var still: bool = sitters.keys().all(func(id: Variant) -> bool:
		return _world.get_brick(int(id)) != null)
	_check("%s: laid %d parts in %d places as one undo step (%d left: %s)" % [name,
		int(laid.get("parts", 0)), int(laid.get("laid", 0)), (laid.get("left", []) as Array).size(),
		"; ".join(laid.get("left", []))], int(laid.get("parts", 0)) > 0
		and _builder.history_depth() == depth + 1)
	_check("%s: check_design finds nothing floating or overlapping it did not before (%d -> %d)"
		% [name, _faults(check_before), _faults(check_after)],
		_faults(check_after) <= _faults(check_before))
	_check("%s: whatever stood on the %d parts taken off still stands (%d)" % [name, gone.size(),
		sitters.size()], still and gone.size() == int(laid.get("taken", 0)))
	await _shot(name + "_after")
	await _undo()
	var back: bool = _store.saved_text() == before and _builder.history_depth() == depth
	_check("%s: one Undo puts the file back byte for byte" % name, back)
	if not back:
		_first_diff(before, _store.saved_text())
	# Each kind left out by its tick.
	var left_out: PackedStringArray = PackedStringArray()
	for kind: String in found:
		bar = await _open_bar()
		if bar == null or not bar.found.has(kind):
			_check("%s: %s shown again" % [name, kind], false)
			continue
		# Every other kind laid, those that start unticked too.
		for other: String in found:
			bar.set_kind(other, other != kind)
		var without: Dictionary = await bar.lay_now()
		await _frames(4)
		var placed: int = 0
		for one: SurfacePass.Finding in found[kind]:
			for raw: Variant in one.add:
				if _placed_at(str(raw["part"]), bar._at(raw), ids_before):
					placed += 1
		var others: int = 0
		for other: String in found:
			if other != kind and bool(bar.ticked.get(other, false)):
				others += 1
		_check("%s: %s left out, none of its parts laid (%d laid of the rest)" % [name, kind,
			int(without.get("parts", 0))], placed == 0
			and (int(without.get("parts", 0)) > 0 or others == 0))
		if _builder.history_depth() > depth:
			await _undo()
		_check("%s: %s left out, Undo puts it back byte for byte" % [name, kind],
			_store.saved_text() == before and _builder.history_depth() == depth)
		left_out.append(kind)
	if bar != null:
		# The ticks kept as they start, for the next model's first lay.
		for kind: String in FinishBar.KINDS:
			bar.set_kind(kind, not FinishBar.OFF_AT_FIRST.has(kind))
		bar.close()
	_summary.append("SUMMARY %s: kinds %s, laid %d parts in %d places, left out %s, floats/overlaps %d -> %d"
		% [name, str(counted), int(laid.get("parts", 0)), int(laid.get("laid", 0)),
		",".join(left_out), _faults(check_before), _faults(check_after)])


## A selection limits the pass to what is on it.
func _case_selection() -> void:
	await _make("g3 house")
	var bar: FinishBar = await _open_bar()
	if bar == null:
		return
	var all: Dictionary = _signatures(bar)
	bar.close()
	# The roof's top course and the course under it on the -z side.
	var picked: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.color_code == 320 and brick.transform.origin.z < 30.0:
			picked.append(brick.id)
	_pick(picked)
	bar = await _open_bar()
	var some: Dictionary = _signatures(bar)
	var inside: bool = some.keys().all(func(key: Variant) -> bool: return all.has(key))
	var removes_picked: bool = true
	for kind: String in bar.found:
		for one: SurfacePass.Finding in bar.found[kind]:
			for id: int in one.remove:
				removes_picked = removes_picked and picked.has(id)
	_check("selection: only what is on the %d selected parts (%d of %d placements)" % [picked.size(),
		some.size(), all.size()], not some.is_empty() and some.size() < all.size() and inside
		and removes_picked)
	bar.close()
	_builder.clear_selection()


## Edit › Finish the surfaces… is a command of the registry, in Edit, and
## the person's Claude is told it is review_model's surface pass.
func _case_registry() -> void:
	var command: Variant = _shell.get("_commands").get("finish_surfaces")
	var in_edit: bool = false
	for menu: Array in Shell.MENUS:
		if menu[0] == "Edit":
			in_edit = (menu[1] as Array).has("finish_surfaces")
	_check("registry: Edit › Finish the surfaces… (%s)" % ("there" if command != null else "missing"),
		command != null and in_edit and str(AppTools.COMMANDS.get("finish_surfaces", "")) == "review_model")


## The reading spread over frames on a big model, no frame over 100 ms of its
## own, and what it finds what the AI's reading finds.
func _case_time(path: String) -> void:
	var name: String = path.get_file().get_basename()
	await _open(FileAccess.get_file_as_string(path))
	_set_name(name)
	await _frames(10)
	var frames := ProbeTime.Frames.new()
	frames.label = func() -> String:
		var job: Working.Job = Working.current()
		var made: Node = _main.get("_finish_made") if _main != null else null
		return (job.words if job != null else "") + " | " + (str(made.get("phase")) if made != null else "")
	root.add_child(frames)
	Fiber.long_stretches = []
	var began: int = Time.get_ticks_msec()
	var bar: FinishBar = await _open_bar()
	var clock: int = Time.get_ticks_msec() - began
	if not _check("time %s: the bar read the model" % name, bar != null):
		frames.queue_free()
		return
	var longest: float = 0.0
	var over: int = 0
	var said: bool = false
	for frame: Array in frames.work:
		var own: float = float(frame[1]) - float(frame[2])
		if own > longest:
			longest = own
		if own > 100.0:
			over += 1
			print("    over 100 ms: %.1f ms own, at %s" % [own, str(frame[3])])
		said = said or str(frame[3]).begins_with("Reading the model")
	for stretch: Array in Fiber.long_stretches:
		print("    a stretch of %.1f ms with no pause, from %s to %s" % stretch)
	frames.queue_free()
	var fibered: Dictionary = _signatures(bar)
	# The AI's own reading, on the main thread, of the same model.
	var reader: Assistant = Assistant.new()
	reader.library = _library
	reader.world = _world
	reader.builder = _builder
	reader.scenery = _store.scenery
	reader._named_as = name
	var straight: Array = SurfacePass.new(reader).find()
	var plain: Dictionary = {}
	for one: SurfacePass.Finding in straight:
		for raw: Variant in one.add:
			plain[_signature(raw)] = true
	reader.free()
	var same: bool = plain.size() == fibered.size() and plain.keys().all(
		func(key: Variant) -> bool: return fibered.has(key))
	_check("time %s: read in %d ms over %d frames, the longest %.1f ms of its own (%d over 100 ms), the status bar saying so"
		% [name, clock, frames.work.size(), longest, over], over == 0 and said and bar.read_at >= 0)
	_check("time %s: the window finds what the AI's reading finds (%d placements, %d)" % [name,
		fibered.size(), plain.size()], same)
	_summary.append("SUMMARY time %s: %d ms, %d frames, longest %.1f ms own, %d over 100 ms, %d placements, same as find(): %s"
		% [name, clock, frames.work.size(), longest, over, fibered.size(), str(same)])
	# Laying it: one undo, back byte for byte.
	var before: String = _store.saved_text()
	var depth: int = _builder.history_depth()
	var lay_frames := ProbeTime.Frames.new()
	root.add_child(lay_frames)
	var laid: Dictionary = await bar.lay_now()
	await _frames(4)
	var lay_longest: float = 0.0
	for frame: Array in lay_frames.work:
		lay_longest = maxf(lay_longest, float(frame[1]) - float(frame[2]))
	lay_frames.queue_free()
	print("  KNOWN time %s: laid %d parts in %d places, the longest frame %.1f ms of its own"
		% [name, int(laid.get("parts", 0)), int(laid.get("laid", 0)), lay_longest])
	if _builder.history_depth() > depth:
		await _undo()
	_check("time %s: laid as one undo step, Undo puts it back byte for byte" % name,
		_store.saved_text() == before and _builder.history_depth() == depth)


## The bar by a finger: it fits 390 x 844, Lay and each tick a finger's size.
func _case_phone() -> void:
	await _make("g3 house")
	var before: String = _store.saved_text()
	var depth: int = _builder.history_depth()
	var bar: FinishBar = await _open_bar()
	if not _check("phone: the bar read the model", bar != null):
		return
	await _frames(20)
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var shown: Rect2 = bar.get_global_rect()
	_check("phone: the bar fits the screen (%s in %s, %s)" % [shown, screen, root.size],
		screen.grow(0.5).encloses(shown))
	var small: PackedStringArray = PackedStringArray()
	var targets: Array = [bar._lay, bar._close]
	for kind: String in bar._ticks:
		if (bar._ticks[kind] as CheckBox).visible:
			targets.append(bar._ticks[kind])
	for target: Control in targets:
		if target.size.y < FinishBar.FINGER - 0.5 or target.size.x < FinishBar.FINGER - 0.5:
			small.append("%s %s" % [target.name, target.size])
	_check("phone: Lay, Close and %d ticks a finger's size (%s)" % [targets.size() - 2,
		", ".join(small) if not small.is_empty() else "all 44 points or more"], small.is_empty())
	await _shot("phone_shown")
	bar._lay.pressed.emit()
	await _until(func() -> bool: return not bar.busy and not bar.visible, 60000)
	_check("phone: Lay pressed lays it as one undo step", _builder.history_depth() == depth + 1)
	await _shot("phone_after")
	await _undo()
	_check("phone: Undo puts the file back byte for byte",
		_store.saved_text() == before and _builder.history_depth() == depth)


## The two speedups (sections from their own points; round ones matched by
## the squares near them) read against the reading they replace.
func _case_identity(path: String) -> void:
	await _open(FileAccess.get_file_as_string(path))
	var reader: Assistant = Assistant.new()
	reader.library = _library
	reader.world = _world
	reader.builder = _builder
	reader.scenery = _store.scenery
	var read: OpenPoints = OpenPoints.read(reader)
	var ids: Array = []
	for brick: BrickWorld.Brick in reader._bricks_inside({}):
		ids.append(brick.id)
	var points: Array = read.points_of(ids)
	var old_by: Array = _old_mates(read, points)
	var again: Array = read.points_of(ids)
	var old_again: Array = _old_mates(read, points)
	var differ: int = 0
	var round_ones: int = 0
	var unsteady: int = 0
	var old_unsteady: int = 0
	for n: int in points.size():
		var point: OpenPoints.Point = points[n]
		if old_by[n] == null:
			continue
		round_ones += 1
		if n < again.size() and (again[n] as OpenPoints.Point).by != point.by:
			unsteady += 1
		if old_again[n] != old_by[n]:
			old_unsteady += 1
		if int(old_by[n]) != point.by:
			differ += 1
			if differ <= 6:
				print("    differs: %s of %d (%s) at %s way %s: before %d, now %d" % [point.kind, point.brick,
					point.part, str(point.at), str(point.way), int(old_by[n]), point.by])
	print("    read twice: %d differ now, %d before" % [unsteady, old_unsteady])
	_check("identity %s: %d round points matched as before (%d differ)" % [path.get_file(),
		round_ones, differ], differ == 0 and round_ones > 0)
	var sp := SurfacePass.new(reader)
	sp._read = read
	var box: AABB = reader._bounds_of(reader._bricks_inside({}))
	var by_section: Dictionary = {}
	for raw: Variant in points:
		var point: OpenPoints.Point = raw
		if not point.section.is_empty():
			if not by_section.has(point.section):
				by_section[point.section] = []
			(by_section[point.section] as Array).append(point)
	var sections: int = 0
	var unlike: int = 0
	for name: Variant in read.model.sections.keys():
		var old: Dictionary = sp.open_tops(str(name), points)
		var new: Dictionary = sp.open_tops(str(name), by_section[str(name)], box) \
			if by_section.has(str(name)) else {}
		sections += 1
		if old != new:
			unlike += 1
	_check("identity %s: %d sections' open tops as before (%d unlike)" % [path.get_file(),
		sections, unlike], unlike == 0)
	reader.free()


## The round ones matched as they were before finishpass: each against every
## one near the model, first that lines up. null for a point not round.
func _old_mates(read: OpenPoints, points: Array) -> Array:
	var out: Array = []
	out.resize(points.size())
	var box := AABB()
	var any: bool = false
	for point: OpenPoints.Point in points:
		if OpenPoints.MATES.has(point.kind):
			box = AABB(point.at, Vector3.ZERO) if not any else box.expand(point.at)
			any = true
	if not any:
		return out
	var near: Array = []
	var lattice: BrickLattice = _builder.lattice
	for other: int in lattice.near_bounds(OpenPoints._box_cells(box.grow(OpenPoints.STUD * 2.0))):
		var brick: BrickWorld.Brick = _world.get_brick(other)
		if brick == null:
			continue
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		for connector: Lbm.Connector in mesh.connectors:
			var kind: String = "bar" if connector.kind == "shaft" else connector.kind
			if OpenPoints.MATES.has(kind):
				near.append([brick.id, kind, brick.transform * connector.position,
					(brick.transform.basis * connector.axis).normalized()])
	for n: int in points.size():
		var point: OpenPoints.Point = points[n]
		if not OpenPoints.MATES.has(point.kind):
			continue
		var by: int = 0
		var takes: Array = OpenPoints.MATES[point.kind]
		for other: Array in near:
			if int(other[0]) == point.brick or not takes.has(other[1]):
				continue
			if Joints.lines_up(point.at, point.way, other[2], other[3]) \
					or Joints.lines_up(other[2], other[3], point.at, point.way):
				by = int(other[0])
				break
		if by == 0 and point.way.y < -0.7 and (point.at + point.way * OpenPoints.UNDER).y < 0.0:
			by = OpenPoints.GROUND
		out[n] = by
	return out


# -- helpers --------------------------------------------------------------------------


## Each kind's ghost has pieces, and each piece a mesh.
func _ghosts_drawn(bar: FinishBar) -> bool:
	for raw: Variant in bar._ghosts.values():
		var holder: Node3D = raw
		if holder == null or holder.get_child_count() == 0:
			return false
		for piece: Node in holder.get_children():
			if not piece is MeshInstance3D or (piece as MeshInstance3D).mesh == null:
				return false
	return true


func _make(model: String) -> void:
	if model.begins_with("res://"):
		await _open(FileAccess.get_file_as_string(model))
		_set_name(model.get_file().get_basename().replace("_", " "))
		return
	_main.call("clear_model")
	await _frames(4)
	var assistant: Assistant = _main.get("_assistant")
	assistant._busy = false
	var bricks: Array = []
	match model:
		"walk wall":
			bricks = _walk_wall()
		"stepped roof":
			bricks = _stepped_roof()
		"car bonnet":
			bricks = _car_bonnet()
		"g3 house":
			bricks = G3
		"speeder hull":
			bricks = _flank()
	var built: Variant = await assistant.use_tool("submit_design", {"name": model,
		"description": "a fixture", "bricks": bricks, "features": []})
	if not str(built).begins_with("Built"):
		print("    could not build the %s: %s" % [model, str(built).substr(0, 300)])
	await _frames(10)
	_set_name("Small brick house" if model == "g3 house" else model)


func _set_name(name: String) -> void:
	var bar: ModelBar = _main.get("_bar")
	(bar.get("_name") as LineEdit).text = name


## The walk's wall: eight 1 x 4s, bonded in four courses.
func _walk_wall() -> Array:
	var out: Array = []
	for course: int in 4:
		for x: int in ([0, 4] if course % 2 == 0 else [2, 6]):
			out.append({"part": "3010", "color": 71, "x": x, "y": course * 3, "z": 0, "rot": 0})
	return out


## A white course 4 x 6 and a red roof stepping in a stud each side a course.
func _stepped_roof() -> Array:
	var out: Array = []
	for z: int in [0, 2, 4]:
		out.append({"part": "3001", "color": 15, "x": 0, "y": 0, "z": z, "rot": 0})
		out.append({"part": "3001", "color": 4, "x": 0, "y": 3, "z": z, "rot": 0})
	for z: int in [1, 3]:
		out.append({"part": "3001", "color": 4, "x": 0, "y": 6, "z": z, "rot": 0})
	out.append({"part": "3001", "color": 4, "x": 0, "y": 9, "z": 2, "rot": 0})
	return out


## A red car 10 long and 4 wide: its cabin a course taller than its bonnet.
func _car_bonnet() -> Array:
	var out: Array = []
	for z: int in [0, 2]:
		out.append({"part": "3001", "color": 4, "x": 0, "y": 0, "z": z, "rot": 0})
		out.append({"part": "3001", "color": 4, "x": 4, "y": 0, "z": z, "rot": 0})
		out.append({"part": "3003", "color": 4, "x": 8, "y": 0, "z": z, "rot": 0})
		out.append({"part": "3001", "color": 4, "x": 1, "y": 3, "z": z, "rot": 0})
	return out


## surface_probe's speeder hull: a red body with flanks of 1 x 4s.
func _flank() -> Array:
	var out: Array = []
	for course: int in 3:
		for x: int in [0, 4]:
			for z: int in [0, 3]:
				out.append({"part": "3010", "color": 15 if course == 2 and z == 3 else 4,
					"x": x, "y": course * 3, "z": z, "rot": 0})
		if course % 2 == 0:
			for x: int in [0, 4]:
				out.append({"part": "3001", "color": 4, "x": x, "y": course * 3, "z": 1, "rot": 0})
		else:
			out.append({"part": "3003", "color": 4, "x": 0, "y": course * 3, "z": 1, "rot": 0})
			out.append({"part": "3001", "color": 4, "x": 2, "y": course * 3, "z": 1, "rot": 0})
			out.append({"part": "3003", "color": 4, "x": 6, "y": course * 3, "z": 1, "rot": 0})
	out.append({"part": "3035", "color": 4, "x": 0, "y": 9, "z": 0, "rot": 0})
	return out


## Edit › Finish the surfaces… run as the menu runs it, until the bar has
## read the model.
func _open_bar() -> FinishBar:
	_shell.run("finish_surfaces")
	await _frames(2)
	var bar: FinishBar = _main.get("_finish_made")
	if bar == null:
		return null
	await _until(func() -> bool: return not bar.busy and bar.visible, 300000)
	await _frames(2)
	return bar if not bar.busy else null


func _until(done: Callable, most_ms: int) -> void:
	var until: int = Time.get_ticks_msec() + most_ms
	while Time.get_ticks_msec() < until and not done.call():
		await process_frame


func _undo() -> void:
	await _shell.verbs.press("undo")
	await _frames(8)


func _check_now() -> String:
	var assistant: Assistant = _main.get("_assistant")
	assistant._busy = false
	return str(await assistant.use_tool("check_design", {"edit": {}}))


static func _faults(text: String) -> int:
	var found := RegEx.create_from_string("(?i)overlaps|floats|floating")
	return found.search_all(text).size()


func _ids() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = true
	return out


## What stands on a stud of a part some finding takes off, and is not taken
## off itself: brick id -> true.
func _sitters(bar: FinishBar, found: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var removed: Dictionary = {}
	var ids: Array = []
	for kind: String in found:
		for one: SurfacePass.Finding in found[kind]:
			for id: int in one.remove:
				removed[id] = true
				ids.append(id)
	for raw: Variant in bar._pass._read.points_of(ids):
		var point: OpenPoints.Point = raw
		if point.kind == "stud" and point.by > 0 and not removed.has(point.by):
			out[point.by] = true
	return out


## Whether a brick not there before is [param part] at [param at].
func _placed_at(part: String, at: Transform3D, before: Dictionary) -> bool:
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id) and brick.part_id == part \
				and brick.transform.origin.distance_to(at.origin) < 0.5:
			return true
	return false


func _signatures(bar: FinishBar) -> Dictionary:
	var out: Dictionary = {}
	if bar == null:
		return out
	for kind: String in bar.found:
		for one: SurfacePass.Finding in bar.found[kind]:
			for raw: Variant in one.add:
				out[_signature(raw)] = true
	return out


static func _signature(placed: Dictionary) -> String:
	return "%s %s %s %s %s %s %s" % [placed.get("part"), placed.get("color"), placed.get("x"),
		placed.get("y"), placed.get("z"), placed.get("rot", 0), placed.get("section", "")]


func _first_diff(want: String, got: String) -> void:
	var a: PackedStringArray = want.split("\n")
	var b: PackedStringArray = got.split("\n")
	for n: int in mini(a.size(), b.size()):
		if a[n] != b[n]:
			print("    line %d: want %s\n    got  %s" % [n + 1, a[n], b[n]])
			return
	print("    lines %d, %d" % [a.size(), b.size()])


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	_shell.run("fit_model")
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join(name.replace(" ", "_") + ".png"))


## At 390 x 844, or FP_PHONE's size ("430x932", self_attack's Phone).
func _as_finger() -> void:
	var wide: int = 390
	var high: int = 844
	var asked: PackedStringArray = OS.get_environment("FP_PHONE").split("x")
	if asked.size() == 2 and asked[0].is_valid_int() and asked[1].is_valid_int():
		wide = int(asked[0])
		high = int(asked[1])
	root.size = Vector2i(wide, high)
	await _frames(10)
	var phone: Variant = _main.get("_phone")
	if phone is Node:
		(phone as Node).set_process(false)
	root.content_scale_factor = (_main.get_script() as GDScript).sized_factor(float(wide),
		float(high), true, ShellPrefs.interface_size(), true)
	await _frames(30)
