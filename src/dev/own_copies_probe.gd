## A model file's own copy of a part LEGO made is read as that part.
##
##   godot --headless --path . --script src/dev/own_copies_probe.gd
##
## Studio writes the parts it has versions of its own into the file (42125-1's
## 1 x 2 thick beams are "42125 - 60483.dat"), and the app read each as a part
## of the file's own: no joints, no exact shape. 42125-1 is opened as a file
## is, and its copies must be read as their parts (CustomParts.copy_of): the
## beams and the steering hubs joined and shaped as the library's, its tie
## rods held in the hubs by their balls, a copy drawn otherwise left the
## file's own, and every copy written back as the file had it.
##
## Survey mode (-- --survey [--shard=K/N] [--only=PREFIX]) counts the copies
## the OMR's sets carry and how many are drawn as their parts are.
extends SceneTree

const OMR := "res://vendor/omr/files/"
const SET := "res://vendor/omr/files/42125-1.mpd"

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _failures: int = 0
var _passed: int = 0


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("FAIL: no catalogue")
		quit(1)
		return
	CustomParts.keeps = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--survey"):
		_survey(args)
		quit(0)
		return
	_run.call_deferred()


func _run() -> void:
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	if not FileAccess.file_exists(SET):
		print("SKIPPED: no %s (tools/omr.py fetch brings the sets)" % SET)
		quit(3)
		return
	var text: String = FileAccess.get_file_as_string(SET)
	var opened: Dictionary = _store.open_text(text, "42125-1")
	print("42125-1: %d parts placed" % int(opened.get("placed", 0)))
	_copies(LdrModel.parse(text, "42125-1"))
	_tie_rods()
	_differs()
	_written_back(LdrModel.parse(text, "42125-1"))
	print("")
	print("own copies: %d passed, %d failed" % [_passed, _failures])
	quit(1 if _failures > 0 else 0)


## The beams and the steering hubs, read as the library's 60483 and 92909:
## its joints, its cover, its exact shape; drawn with their own triangles.
func _copies(model: LdrModel) -> void:
	print("\nthe file's copies, read as their parts")
	var read: int = 0
	var named: int = 0
	for file_name: String in model.embedded_parts:
		var id: String = file_name.get_basename()
		if CustomParts.named_for(_library, id).is_empty():
			continue
		named += 1
		if not (_library.parts[id] as PartLibrary.PartInfo).copy_of.is_empty():
			read += 1
	print("  %d of the %d copies of parts LEGO made read as their parts" % [read, named])
	_check(named == 25 and read == named, "42125-1's copies read as their parts: %d of %d" % [read, named])
	for pair: Array in [["42125 - 60483", "60483"], ["42125 - 92909", "92909"],
			["42125 - 23801", "23801"]]:
		var info: PartLibrary.PartInfo = _library.parts.get(pair[0])
		var mine: Lbm.PartMesh = _library.mesh_for(pair[0])
		var theirs: Lbm.PartMesh = _library.mesh_for(pair[1])
		_check(info != null and info.copy_of == pair[1],
			"%s is read as %s (%s)" % [pair[0], pair[1], info.name if info != null else "none"])
		_check(mine != null and theirs != null and not theirs.connectors.is_empty()
			and mine.connectors.size() == theirs.connectors.size()
			and mine.boxes.size() == theirs.boxes.size(),
			"%s has %s's %d connectors and %d cover boxes (it has %d and %d)" % [pair[0], pair[1],
				theirs.connectors.size() if theirs else 0, theirs.boxes.size() if theirs else 0,
				mine.connectors.size() if mine else 0, mine.boxes.size() if mine else 0])
		var shape: Exact.Shape = Exact.shape_for(_library, pair[0])
		_check(shape != null and shape == Exact.shape_for(_library, pair[1]),
			"%s has %s's exact shape" % [pair[0], pair[1]])
		_check(mine != null and theirs != null and mine.surfaces[0] != theirs.surfaces[0],
			"%s is drawn with its own triangles" % pair[0])


## The tie rods' towballs (2736) held in the steering knuckles' axle holes,
## the knuckles 42125-1's own copies of 23801: an axle in an axle hole, as
## Joints.through reads it, where before the knuckle had no such hole and
## the towball was only lodged in it (MECHANISMS §28). And each steering link
## (2739a) on a towball.
func _tie_rods() -> void:
	print("\nthe tie rods in the steering knuckles")
	var entries: Array = []
	var knuckles: Dictionary = {}
	var towballs: Dictionary = {}
	var links: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var into: Dictionary = {"42125 - 23801": knuckles, "2736": towballs, "2739a": links}.get(
			brick.part_id, {})
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null or not {"42125 - 23801": 1, "2736": 1, "2739a": 1}.has(brick.part_id):
			continue
		into[brick.id] = true
		entries.append([brick.id, brick.transform, mesh])
	var in_knuckle: Dictionary = {}
	for one: Array in Joints.through(entries):
		if towballs.has(int(one[0])) and knuckles.has(int(one[1])):
			in_knuckle[int(one[0])] = "%s #%d" % [one[2], int(one[1])]
	var on_ball: Dictionary = {}
	var balls: Dictionary = Joints.balls(entries)
	for link: int in links:
		for other: Variant in balls.get(link, {}):
			if towballs.has(int(other)):
				on_ball[link] = int(other)
	print("  %d knuckles, %d towballs, %d steering links; towballs in a knuckle: %s; links on a towball: %s"
		% [knuckles.size(), towballs.size(), links.size(), in_knuckle, on_ball])
	_check(knuckles.size() == 2 and (_library.parts["42125 - 23801"] as PartLibrary.PartInfo).copy_of == "23801",
		"the steering knuckles (#340, #344) are read as 23801")
	_check(not towballs.is_empty() and in_knuckle.size() == towballs.size(),
		"every towball (2736) is held in a knuckle's axle hole: %d of %d" % [in_knuckle.size(), towballs.size()])
	_check(not links.is_empty() and on_ball.size() == links.size(),
		"every steering link (2739a) is on a towball: %d of %d" % [on_ball.size(), links.size()])
	# As the file draws it, built again from its text and read as its own: its
	# slotted axle holes are named the file's way, so no hole a towball is in.
	var drawn: PartForge.Result = CustomParts._built(_library,
		_library.custom_source("42125 - 23801"), "42125 - 23801",
		CustomParts.drawn_from.get("42125 - 23801", {}))
	var before: Array = []
	for entry: Array in entries:
		before.append([entry[0], entry[1], drawn.mesh if knuckles.has(int(entry[0])) else entry[2]])
	var held_before: int = 0
	for one: Array in Joints.through(before):
		if towballs.has(int(one[0])) and knuckles.has(int(one[1])):
			held_before += 1
	print("  read as the file's own part, a knuckle has %d connectors, and %d towballs are in one"
		% [drawn.mesh.connectors.size(), held_before])
	_check(held_before == 0, "read as the file's own part, as before, no towball is in a knuckle")


## A copy drawn otherwise is the file's own part: the 60483 copy with one of
## its quads moved a stud out.
func _differs() -> void:
	print("\na copy that differs")
	var text: String = _library.custom_source("42125 - 60483")
	var moved: String = text.replace("4 16 9 10 0 9 10 20 9 -10 20 9 -10 0",
		"4 16 29 10 0 29 10 20 29 -10 20 29 -10 0")
	_check(moved != text, "the copy's quad is moved")
	var sources: Dictionary = CustomParts.drawn_from.get("42125 - 60483", {})
	var made: Dictionary = CustomParts.add(_library, moved, "probe - 60483", false, sources)
	var info: PartLibrary.PartInfo = _library.parts.get("probe - 60483")
	_check(str(made["problem"]).is_empty() and info != null and info.copy_of.is_empty()
		and Exact.shape_for(_library, "probe - 60483") == null,
		"a copy of 60483 with a quad a stud out stays the file's own part, with no exact shape (%s)"
			% made["problem"])
	var like: Dictionary = CustomParts.likeness(_library.mesh_for("probe - 60483"),
		_library.mesh_for("60483"))
	print("  its likeness to 60483: box %.2f LDU, %d corners further than %.2f" % [
		float(like["box"]), int(like["missed"]), CustomParts.COPY_WITHIN])


## Every copy written back as the file had it.
func _written_back(model: LdrModel) -> void:
	print("\nwritten back")
	var out: String = _store.to_text("42125-1").replace("\r\n", "\n")
	var kept: int = 0
	var named: int = 0
	for file_name: String in model.embedded_parts:
		if CustomParts.named_for(_library, file_name.get_basename()).is_empty():
			continue
		named += 1
		var body: String = str(model.embedded_parts[file_name])
		if _library.custom_source(file_name.get_basename()) == body and out.contains(body):
			kept += 1
	_check(named > 0 and kept == named, "every copy is written back as the file had it: %d of %d"
		% [kept, named])


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", what)
	else:
		_failures += 1
		print("FAIL: ", what)


## Every copy in every OMR file: how many, how many alike, and the likeness
## of those that are not, worst first.
func _survey(args: PackedStringArray) -> void:
	var only: String = ""
	var shard: Vector2i = Vector2i(0, 1)
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		if arg.begins_with("--shard="):
			var parts: PackedStringArray = arg.trim_prefix("--shard=").split("/")
			shard = Vector2i(int(parts[0]), int(parts[1]))
	var files: int = 0
	var with_copies: int = 0
	var copies: int = 0
	var alike: int = 0
	var unbuilt: int = 0
	var no_mesh: int = 0
	var moved: int = 0
	var rows: Array = []
	var named_parts: Dictionary = {}
	var began: int = Time.get_ticks_msec()
	var spread: Dictionary = {}
	var nth: int = -1
	for file_name: String in DirAccess.get_files_at(OMR):
		if not (file_name.ends_with(".mpd") or file_name.ends_with(".ldr")):
			continue
		nth += 1
		if nth % shard.y != shard.x:
			continue
		if not only.is_empty() and not file_name.begins_with(only):
			continue
		files += 1
		var model: LdrModel = LdrModel.parse(FileAccess.get_file_as_string(OMR + file_name),
			file_name)
		if model == null:
			continue
		var texts: Dictionary = {}
		for part_file: String in model.embedded_parts:
			if not CustomParts.named_for(_library, part_file.get_basename()).is_empty():
				texts[part_file] = model.embedded_parts[part_file]
		if texts.is_empty():
			continue
		with_copies += 1
		var carried: Dictionary = model.embedded_parts.duplicate()
		carried.merge(model.embedded_sources)
		carried.merge(model.embedded_data)
		var built: Dictionary = CustomParts._built_at_once(texts, carried)
		for part_file: String in texts:
			copies += 1
			var id: String = part_file.get_basename()
			var named: String = CustomParts.named_for(_library, id)
			named_parts[named] = true
			var result: PartForge.Result = built.get(part_file)
			if result == null:
				result = CustomParts._built(_library, texts[part_file], id, carried)
			if not result.problem.is_empty() or result.mesh == null:
				unbuilt += 1
				continue
			if _library.moved_by(named) != Transform3D.IDENTITY:
				moved += 1
				continue
			var theirs: Lbm.PartMesh = _library.mesh_for(_library.resolve(named))
			if theirs == null:
				no_mesh += 1
				continue
			var like: Dictionary = CustomParts.likeness(result.mesh, theirs)
			var far: float = maxf(float(like["far"]), float(like["box"]))
			var bucket: String = "0" if far == 0.0 else "<=0.1" if far <= 0.1 \
				else "<=0.25" if far <= 0.25 else "<=0.5" if far <= 0.5 \
				else "<=1" if far <= 1.0 else "<=2" if far <= 2.0 else ">2"
			spread[bucket] = int(spread.get(bucket, 0)) + 1
			if not CustomParts.copy_of(_library, id, result.mesh).is_empty():
				alike += 1
			else:
				rows.append([file_name, id, float(like["box"]), int(like["missed"]),
					int(like["of"]), float(like["far"])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[5]) < float(b[5]))
	print("SURVEY: %d files, %d carry copies of parts LEGO made: %d copies of %d parts"
		% [files, with_copies, copies, named_parts.size()])
	print("SURVEY: %d drawn as their parts are; %d otherwise; %d did not build; %d named for a part moved and turned; %d whose part has no geometry"
		% [alike, rows.size(), unbuilt, moved, no_mesh])
	print("SURVEY: in %.1f s" % ((Time.get_ticks_msec() - began) / 1000.0))
	for bucket: String in ["0", "<=0.1", "<=0.25", "<=0.5", "<=1", "<=2", ">2"]:
		print("SPREAD: furthest %s LDU: %d" % [bucket, int(spread.get(bucket, 0))])
	for row: Array in rows:
		print("  differs: %s %s box %.3f, %d of %d corners further than %.2f, the furthest %.3f"
			% [row[0], row[1], row[2], row[3], row[4], CustomParts.COPY_WITHIN, row[5]])
