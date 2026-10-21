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
## And a copy of a gear is a gear (Mechanism.reads_as): 42125-1's copied 20
## tooth double bevel has its teeth, and in 42121-1, 42083-1 and 42115-1 a
## copied gear meshing one of the library's turns it at the teeth's ratio,
## in Simulate and by Grab; 42054-1's copied turntable top, in Simulate.
##
## Survey mode (-- --survey [--shard=K/N] [--only=PREFIX]) counts the copies
## the OMR's sets carry and how many are drawn as their parts are. Gears mode
## (-- --gears [--only=PREFIX]) lists every copy of a part the gear table
## keys (a gear, a turntable, a driving ring, a rack, an actuator) and
## whether the table reads it as that part.
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
	if args.has("--gears"):
		_survey_gears(args)
		quit(1 if _failures > 0 else 0)
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
	_a_gear()
	for train: Array in TRAINS:
		await _train(train[0], train[1], train[2], train[3])
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


## 42125-1's copy of the 20 tooth double bevel is a gear, read as 18575 in
## the gear table; the copy that differs, read as its own, is no beam.
func _a_gear() -> void:
	print("\na copy of a gear")
	var spec: Dictionary = Mechanism.spec_of("42125 - 18575")
	_check(Mechanism.reads_as("42125 - 18575") == "18575" and not spec.is_empty()
		and spec == Mechanism.spec_of("18575") and int(spec.get("teeth", 0)) == 20,
		"42125 - 18575 is read as 18575 in the gear table: a %s gear of %d teeth" % [
			spec.get("kind", "no"), int(spec.get("teeth", 0))])
	_check(Mechanism.reads_as("probe - 60483") == "probe - 60483",
		"the copy that differs is read as itself")


## A copied gear meshing one of the library's: [set, the copy, the library's
## gear, whether Grab turns it too]. 42121-1's 20 tooth double bevel drives
## a 12; 42083-1's clutch gear drives the differential's 28 at right angles,
## and 42115-1's a 12; 42054-1's turntable top, its 60 teeth, is driven by a
## 12. Grab does not turn that one's train: the top is in a closed loop,
## moved as one (Grab.linkage), and a loop's move reads no gears.
const TRAINS := [["42121-1", "42121 - 18575", "32270", true],
	["42083-1", "42083 - 35185", "62821", true], ["42115-1", "42115 - 35185", "32270", true],
	["42054-1", "42054 - 18938", "32270", false]]


## Open [param set_name] and find where its copy [param copy] meshes a
## [param theirs]: in Simulate, the copy driven turns it at the teeth's
## ratio; with [param by_grab], the copy turned towards 20 degrees by Grab
## turns it as far as the teeth say, as far as the model lets it go.
func _train(set_name: String, copy: String, theirs: String, by_grab: bool) -> void:
	print("\n%s: %s meshing %s" % [set_name, copy, theirs])
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	store.keeps = false
	await process_frame
	var opened: Dictionary = store.open_text(FileAccess.get_file_as_string(OMR + set_name + ".mpd"),
		set_name)
	print("  %d parts placed" % int(opened.get("placed", 0)))
	var simulation: Simulation = Simulation.read(world.bricks(), _library, store.scenery)
	var model: Mechanism = simulation.model
	var mesh: Mechanism.Coupling = null
	for coupling: Mechanism.Coupling in model.couplings:
		var parts: Array = [coupling.one.part, coupling.other.part]
		if parts.has(copy) and parts.has(theirs):
			mesh = coupling
			break
	_check(mesh != null, "%s: the copy %s meshes a %s (%s)" % [set_name, copy, theirs,
		mesh.said() if mesh != null else "none of %d meshes" % model.couplings.size()])
	if mesh != null:
		var mine: Mechanism.Gear = mesh.one if mesh.one.part == copy else mesh.other
		var other: Mechanism.Gear = mesh.other if mine == mesh.one else mesh.one
		var ratio: float = float(mine.teeth) / float(other.teeth)
		simulation.drive(model.body_of(mine.key))
		var rate: float = float(simulation.rates.get(model.body_of(other.key), 0.0))
		_check(bool(simulation.solved.get("ok", false)) and absf(absf(rate) - ratio) < 1e-5,
			"%s: in Simulate, the copy #%d (%d teeth) driven turns the %s #%d (%d teeth) %.6f times as fast, the teeth's %.6f (%s)"
				% [set_name, mine.key, mine.teeth, theirs, other.key, other.teeth, absf(rate), ratio,
				simulation.solved.get("said", "")])
		if not by_grab:
			world.queue_free()
			builder.queue_free()
			await process_frame
			return
		var grab := Grab.new()
		grab.world = world
		grab.builder = builder
		grab.library = _library
		var state: String = grab.begin(mine.key, world.get_brick(mine.key).transform.origin)
		grab.turn_to(20.0)
		var turned: float = NAN
		if grab.placed.has(other.key) and grab.placed.has(mine.key):
			var driven: float = _turn_about((grab.placed[mine.key] as Transform3D).basis
				* (grab.rest[mine.key] as Transform3D).basis.inverse(), mine.axis)
			turned = _turn_about((grab.placed[other.key] as Transform3D).basis
				* (grab.rest[other.key] as Transform3D).basis.inverse(), other.axis)
			print("  Grab: the copy turned %.3f°, the %s %.3f°" % [driven, theirs, turned])
		_check(state == "moves" and grab.coupled.has(other.key) and absf(grab.angle) >= 1.0
			and absf(absf(turned) - absf(grab.angle) * ratio) < 0.05,
			"%s: by Grab, the copy turned %.2f° turns the %s %.3f°, the teeth's %.3f° (%s%s%s)" % [
				set_name, grab.angle, theirs, absf(turned), absf(grab.angle) * ratio, state,
				"" if grab.said.is_empty() or not grab.stopped else ", stopped: " + grab.said,
				"" if grab.gear_note.is_empty() else "; " + grab.gear_note])
	world.queue_free()
	builder.queue_free()
	await process_frame


static func _turn_about(turn: Basis, axis: Vector3) -> float:
	var across: Vector3 = (Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).cross(axis).normalized()
	var turned: Vector3 = turn * across
	return rad_to_deg(atan2(axis.dot(across.cross(turned)), across.dot(turned)))


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


## The gear table's sections of an entry per part (Mechanism.entry_of).
const ENTRIES := ["gears", "driving_rings", "ring_carriers", "clutch_gears", "racks", "actuators"]


## The parts the gear table keys, and how: part -> the sections, a
## turntable's base, an actuator's rod and input and a rack's housing among
## them.
static func _gear_table_parts() -> Dictionary:
	var out: Dictionary = {}
	var table: Dictionary = Mechanism.table()
	for section: String in ["gears", "turntables", "driving_rings", "ring_carriers", "clutch_gears",
			"racks", "actuators"]:
		var entries: Dictionary = table.get(section, {})
		for part: String in entries:
			out[part] = out.get(part, PackedStringArray()) + PackedStringArray([section])
			var entry: Variant = entries[part]
			var also: Dictionary = {}
			if section == "turntables":
				also["turntable base"] = entry
			elif entry is Dictionary:
				for field: String in ["rod", "input", "housing"]:
					if (entry as Dictionary).has(field):
						also[section.trim_suffix("s") + " " + field] = entry[field]
			for what: String in also:
				var other: String = str(also[what])
				out[other] = out.get(other, PackedStringArray()) + PackedStringArray([what])
	return out


## Every OMR file's copies of parts the gear table keys, built and added as
## a file's are when it opens (CustomParts.add): each read as its part by
## every lookup of the table it is keyed in, or drawn otherwise and read as
## its own.
func _survey_gears(args: PackedStringArray) -> void:
	var only: String = ""
	for arg: String in args:
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var keyed: Dictionary = _gear_table_parts()
	var files: int = 0
	var copies: int = 0
	var read: int = 0
	var as_gears: int = 0
	for file_name: String in DirAccess.get_files_at(OMR):
		if not (file_name.ends_with(".mpd") or file_name.ends_with(".ldr")) \
				or not file_name.begins_with(only):
			continue
		var model: LdrModel = LdrModel.parse(FileAccess.get_file_as_string(OMR + file_name),
			file_name)
		if model == null:
			continue
		var texts: Dictionary = {}
		for part_file: String in model.embedded_parts:
			var named: String = CustomParts.named_for(_library, part_file.get_basename())
			if not named.is_empty() and keyed.has(_library.resolve(named)):
				texts[part_file] = model.embedded_parts[part_file]
		if texts.is_empty():
			continue
		files += 1
		var carried: Dictionary = model.embedded_parts.duplicate()
		carried.merge(model.embedded_sources)
		carried.merge(model.embedded_data)
		# Built with what each draws on, as a file's parts are when it opens.
		var built: Dictionary = CustomParts._built_at_once(texts, carried)
		var said := PackedStringArray()
		for part_file: String in texts:
			copies += 1
			var id: String = part_file.get_basename()
			var made: String = _library.resolve(CustomParts.named_for(_library, id))
			var added: Dictionary = CustomParts.add(_library, texts[part_file], id, false, carried,
				built.get(part_file))
			var sections: PackedStringArray = keyed[made]
			var as_it: bool = Mechanism.reads_as(id) == made
			# Each section whose entries are its, as its part's are.
			for section: String in sections:
				if section in ENTRIES:
					as_it = as_it and not Mechanism.entry_of(section, id).is_empty() \
						and Mechanism.entry_of(section, id) == Mechanism.entry_of(section, made)
			var own: bool = (_library.parts.get(id) as PartLibrary.PartInfo).copy_of.is_empty() \
				if _library.parts.has(id) else true
			if as_it:
				read += 1
				if sections.has("gears"):
					as_gears += 1
			# One drawn otherwise is read as itself, and is no gear.
			_check(as_it != own and (as_it or Mechanism.reads_as(id) == id
				and Mechanism.spec_of(id).is_empty()),
				"%s %s: %s" % [file_name, id, "read as %s" % made if as_it else "its own (%s)"
					% str(added["problem"])])
			said.append("%s (%s, %s)" % [id, "/".join(sections), "read as %s" % made if as_it
				else "its own"])
		print("GEARS: %s: %s" % [file_name, "; ".join(said)])
	print("GEARS: %d files carry %d copies of parts the gear table keys; %d read as their parts, %d of them gears"
		% [files, copies, read, as_gears])


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
