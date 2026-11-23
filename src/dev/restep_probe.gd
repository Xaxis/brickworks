## restep: the app's own shipped models given saved steps that put no part in
## the air, by moving their lines, never writing them again (stepkeep2,
## 2026-11-22).
##
## Since stepkeep2 a file the app saved opens in the steps its 0 STEP lines
## say. The castle's were an older planner's, and 48 of its parts went down
## in the air; the gallery's potted cactus 1, its sports car 25. Plan steps
## and Save fix them, but write the file whole: its sub-models built in the
## model's steps as IN lines, its comment gone, 6,170 lines changed. Here
## each file stays itself: the same FILE sections, the same lines byte for
## byte, every comment and meta. Only where a part line stands among its
## own section's 0 STEP lines changes, and the STEP lines with it. Each part
## (or a sub-model's placing line, the copy it puts on) the steps test puts
## down in the air goes later in its own section: to the first later step
## that puts down a part it is joined to (Tested's studs and joints), or
## one step later where none is, until none is in the air:
## the model's placements as units, each sub-model's parts in its own file,
## as an LDraw booklet builds them. One that is in the air even after the
## last of its section's parts is left where it was: only building it in
## another section's steps (a flattening) could hold it, and that is said.
##
## The steps test is the share's (SharedPages.pages_for, then Tested.check's
## steps), read here part by part. For each file: the parts in the air and
## hidden before and after, each line moved, a check that every other line
## is the file's (the same lines in each section, only the STEP lines and
## the order changed); then the file written, opened as File > Open opens
## it: its steps its own, the steps read the ones measured, the share's
## steps test saying the same count, and saved unedited byte for byte.
##
##   RESTEP_OUT=DIR godot --headless --path . --script src/dev/restep_probe.gd
##   RESTEP_FILES=res://a.ldr,res://b.ldr  those, not the three
extends SceneTree

const FILES: Array = ["res://models/castle.ldr", "res://tools/web/gallery_seeds/potted_cactus.ldr",
	"res://tools/web/gallery_seeds/sports_car.ldr"]
const COPY_META := "0 !BRICKWORKS COPY"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _library: PartLibrary
var _bar: ModelBar


func _initialize() -> void:
	_run()


func _run() -> void:
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
	for _n: int in 30:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_library = _world.library
	_bar = _main.get("_bar")
	_store.keeps = true
	var out: String = OS.get_environment("RESTEP_OUT")
	if out.is_empty():
		out = "user://restep"
	DirAccess.make_dir_recursive_absolute(out)
	var files: Array = Array(OS.get_environment("RESTEP_FILES").split(",", false))
	for path: String in (files if not files.is_empty() else FILES):
		await _restep(path, out.path_join(path.get_file()))
	print("")
	print("every file's steps put no part in the air, by moves alone" if _failures == 0
		else "%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


# -- one file ------------------------------------------------------------------------


func _restep(path: String, into: String) -> void:
	print("\n== %s" % path)
	var text: String = FileAccess.get_file_as_string(path)
	var file := Restepped.new(text)
	var first: Dictionary = await _measure(text)
	var shared: Array = await _shared_count(text)
	_check("%s: measured as the share measures it (%d in the air, %d hidden; the share says %d, %d)"
		% [path, first["floats"].size(), first["hidden"].size(), shared[0], shared[1]],
		first["floats"].size() == shared[0] and first["hidden"].size() == shared[1])
	var now: Dictionary = first
	var left: Dictionary = {}           # line -> why it stays where it was
	var passes: int = 0
	while passes < 200:
		var moving: Dictionary = {}
		for float_at: Array in now["floats"]:
			var found: Array = _line_of(now, int(float_at[0]), int(float_at[1]), file)
			var line: int = int(found[0])
			if line < 0 or not file.block.has(line):
				_check("%s: step %d's part in the air read back to its line" % [path, float_at[0]], false)
				continue
			if left.has(line):
				continue
			if file.past_last(line):
				left[line] = "in the air after every part of its section"
				continue
			moving[line] = maxi(int(moving.get(line, 0)), int(found[1]))
		if moving.is_empty():
			break
		for line: int in moving:
			file.later(line, int(moving[line]))
		passes += 1
		now = await _measure(file.text())
		print("  pass %d: %d lines moved, now %d in the air, %d hidden" % [passes, moving.size(),
			now["floats"].size(), now["hidden"].size()])
	# What only a flattening could hold, back where the file had it.
	for line: int in left:
		file.back(line)
	var made: String = file.text()
	if not left.is_empty():
		now = await _measure(made)
	print("  %d passes; %d lines moved, %d STEP lines before, %d after" % [passes,
		file.moved().size(), text.count("\n0 STEP"), made.count("\n0 STEP")])
	for line: int in file.moved():
		print("    line %d (%s) from step %d of %s to %d" % [line + 1, file.lines[line].strip_edges().get_slice(" ", 14),
			file.was[line] + 1, file.section_name(line), int(file.block[line]) + 1])
	for line: int in left:
		print("    once in the air past every part of its section: line %d (%s)" % [line + 1,
			file.lines[line].strip_edges()])
	# Left: those still in the air at the end, which no later step of their
	# own section holds.
	var still: int = 0
	for float_at: Array in now["floats"]:
		if left.has(int(_line_of(now, int(float_at[0]), int(float_at[1]), file)[0])):
			still += 1
	_check("%s: in the air %d (was %d; %d only a flattening could hold); hidden %d (was %d)"
		% [path, now["floats"].size(), first["floats"].size(), still, now["hidden"].size(),
		first["hidden"].size()], now["floats"].size() == still)
	var others: Array = Restepped.other_changes(text, made)
	_check("%s: every other line the file's, in its section (%d changed: %s)" % [path, others.size(),
		others.slice(0, 3)], others.is_empty())
	var written: FileAccess = FileAccess.open(into, FileAccess.WRITE)
	written.store_string(made)
	written.close()
	await _reopened(path, into, made, now)


## Opened as File > Open opens it: its steps its own (BrickWorld.steps_own),
## the steps read the ones measured, part for part; the share's steps test
## the same count; saved unedited, byte for byte.
func _reopened(path: String, into: String, made: String, measured: Dictionary) -> void:
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress(into)
	_bar.opened.emit(placed)
	await _frames(10)
	var opened: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		opened.append(_origins(step, func(id: int) -> String:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			return brick.origin if brick != null else "?"))
	var same: int = 0
	for n: int in mini(opened.size(), (measured["plan"] as Array).size()):
		same += 1 if opened[n] == measured["plan"][n] else 0
	_check("%s: opened, its steps its own (%s), %d of %d steps the ones measured (%d)"
		% [path, _world.steps_own, same, opened.size(), (measured["plan"] as Array).size()],
		_world.steps_own and same == opened.size() and opened.size() == (measured["plan"] as Array).size())
	var shared: Array = await _shared_count(made)
	_check("%s: the share's steps test, %d in the air, %d hidden" % [path, shared[0], shared[1]],
		shared[0] == (measured["floats"] as Array).size())
	var again: String = _store.to_text(_store.title, true)
	_check("%s: saved unedited, byte for byte (%d bytes)" % [path, made.length()], again == made)
	_main.call("clear_model")
	await _frames(4)


# -- the steps test, part by part ---------------------------------------------------


## [param text] put down as a share puts it (SharedPages.pages_for), its steps
## planned and built as the steps test builds them (Tested.check): {"floats",
## "hidden": [step number, id], "origin": id -> the lines placing it
## (Placement.origin), "took": step number -> [[section, ids]...], "plan":
## each step's origins}.
func _measure(text: String) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "model")
	var world := BrickWorld.new()
	world.library = _library
	world.hold_drawing()
	var authored: bool = model.steps_are_kept()
	var known: Array = []
	for item: Variant in model.flatten(_library.parts):
		var placement: LdrModel.Placement = item
		if not authored:
			placement.step = -1
		placement.part_id = ModelStore.studio_part(placement.part_id, _library)
		if placement.mirrored:
			Assemblies.unmirror(placement, _library)
		ModelStore.as_moved(placement, _library)
		if _library.parts.has(placement.part_id):
			known.append(placement)
	var pairs: Array = []
	for placement: LdrModel.Placement in known:
		pairs.append([placement.part_id, placement.transform])
	var up := Vector3(0.0, ModelStore._lift_from(_store.lowest_of(pairs),
		model.author.strip_edges() != "Brickworks"), 0.0)
	if authored:
		world.unit_steps = model.unit_steps.duplicate()
	world.steps_own = model.steps_are_saved()
	var origin: Dictionary = {}
	for placement: LdrModel.Placement in known:
		var at: Transform3D = placement.transform
		at.origin += up
		var id: int = world.add_brick(placement.part_id, placement.color_code, at)
		if id == 0:
			continue
		var brick: BrickWorld.Brick = world.get_brick(id)
		brick.group = placement.group
		brick.unit = placement.unit
		brick.step = placement.step
		origin[id] = placement.origin
	var job := Working.Job.new()
	var steps: Array[Instructions.Step] = await Instructions.plan_paced(world, _library, {}, {},
		job, AuthorSteps.any(world))
	var lattice := BrickLattice.new()
	lattice.keeps_columns = false
	var bricks: Array = []
	var by_id: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh != null:
			lattice.occupy_boxes(brick.id, _store.builder.boxes_for(mesh, brick.transform))
			bricks.append(brick)
			by_id[brick.id] = brick
	var holding: Dictionary = {}
	await Tested.holds_into(holding, bricks, lattice, _library, job)
	var test := Tested.Steps.new(by_id, holding, _library)
	var took: Dictionary = {}
	var plan: Array = []
	for step: Instructions.Step in steps:
		plan.append(_origins(step, func(id: int) -> String: return str(origin.get(id, "?"))))
		var things: Array = test.things_of(step)
		if things.is_empty():
			continue
		var section: String = step.authored_in if step.authored_step >= 0 else ""
		if not took.has(step.number):
			took[step.number] = []
		for thing: PackedInt64Array in things:
			(took[step.number] as Array).append([section, thing])
		test.take(step, things)
	test.finish()
	world.queue_free()
	return {"floats": test.floating, "hidden": test.hidden, "origin": origin, "took": took,
		"plan": plan, "near": holding["near"]}


## The line in the file of what step [param number] put down in the air
## whose first part is [param id], and the step of its section it goes to:
## [line, step]. Its line is that section's placing it (the part's own, or
## the copy's); its step the first later one that puts down a part it is
## joined to (Tested's near), or the next where none is. [-1, -1] for none.
func _line_of(measured: Dictionary, number: int, id: int, file: Restepped) -> Array:
	for entry: Array in measured["took"].get(number, []):
		var thing: PackedInt64Array = entry[1]
		if not thing.has(id):
			continue
		var section: String = entry[0]
		var depth: int = 0 if section.is_empty() else section.split("/").size()
		var line: int = _at_depth(measured, id, depth)
		if line < 0 or not file.block.has(line):
			return [-1, -1]
		var now: int = int(file.block[line])
		var to: int = -1
		for part: int in thing:
			for other: Variant in (measured["near"] as Dictionary).get(part, {}):
				if thing.has(int(other)):
					continue
				var held_by: int = _at_depth(measured, int(other), depth)
				if held_by < 0 or not file.block.has(held_by) \
						or file.section_of[held_by] != file.section_of[line]:
					continue
				var step: int = int(file.block[held_by])
				if step > now and (to < 0 or step < to):
					to = step
		return [line, to if to > now else now + 1]
	return [-1, -1]


## The line of [param id]'s placing at [param depth] (0 the model's own).
static func _at_depth(measured: Dictionary, id: int, depth: int) -> int:
	var lines: PackedStringArray = str(measured["origin"].get(id, "")).split("/")
	return int(lines[depth]) if depth < lines.size() and not lines[depth].is_empty() else -1


static func _origins(step: Instructions.Step, origin_of: Callable) -> Array:
	var out: Array = []
	for id: int in step.brick_ids:
		out.append(origin_of.call(id))
	for copy: PackedInt64Array in step.copies:
		for id: int in copy:
			out.append(origin_of.call(id))
	out.sort()
	return out


## How many parts the share's own steps test puts in the air and hides.
func _shared_count(text: String) -> Array:
	var tested: Dictionary = (await SharedPages.attach_tested(text, _library, _store))["tested"]
	var tests: Dictionary = tested.get("tests", {})
	if not tests.has("steps"):
		return [-1, -1]
	if bool((tests["steps"] as Dictionary).get("ok", false)):
		return [0, 0]
	var said: Array = Tested.said_all.get("steps", [])
	var air: int = said.filter(func(line: Variant) -> bool: return str(line).ends_with("in the air")).size()
	return [air, said.size() - air]


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


# -- the file's lines, moved ----------------------------------------------------------


## A file's lines, each part line in a step of its section (its block: the
## lines between two 0 STEP lines), moved only to a later one of the same
## section. Written: every line but a part's and a STEP line where it was; a
## part moved in at the start of the step it went to, with the COPY line
## that says which copy it places; a STEP line only between two steps that
## have parts; a step after the section's last, before its last lines.
class Restepped extends RefCounted:
	var lines: PackedStringArray
	var section_of: PackedInt32Array = PackedInt32Array()
	var block: Dictionary = {}          ## part line -> its step in its section, now
	var was: Dictionary = {}            ## part line -> the file's
	var blocks: PackedInt32Array = PackedInt32Array()  ## section -> its file's steps
	var names: PackedStringArray = PackedStringArray()

	func _init(text: String) -> void:
		lines = text.split("\n")
		var section: int = -1
		var at: int = 0
		for n: int in lines.size():
			var line: String = lines[n].strip_edges()
			if line.begins_with("0 FILE ") or section < 0:
				section += 1
				at = 0
				blocks.append(1)
				names.append(line.substr(7) if line.begins_with("0 FILE ") else "")
			section_of.append(section)
			if line == "0 STEP":
				at += 1
				blocks[section] = at + 1
			elif line.begins_with("1 "):
				block[n] = at
				was[n] = at

	func section_name(line: int) -> String:
		return names[section_of[line]]

	## Whether no part of [param line]'s section is put down after it: a step
	## later, nothing more of its section could hold it.
	func past_last(line: int) -> bool:
		var section: int = section_of[line]
		for other: int in block:
			if section_of[other] == section and other != line and int(block[other]) > int(block[line]):
				return false
		return true

	func later(line: int, to: int) -> void:
		block[line] = maxi(int(block[line]) + 1, to)
		blocks[section_of[line]] = maxi(blocks[section_of[line]], int(block[line]) + 1)

	func back(line: int) -> void:
		block[line] = was[line]

	func moved() -> Array:
		var out: Array = []
		for line: int in block:
			if int(block[line]) != int(was[line]):
				out.append(line)
		out.sort()
		return out

	## A COPY line saying which copy the reference after it places goes with it.
	func _attached(n: int) -> bool:
		return lines[n].strip_edges().begins_with(COPY_META) and n + 1 < lines.size() \
			and block.has(n + 1)

	func text() -> String:
		var out := PackedStringArray()
		var n: int = 0
		while n < lines.size():
			var section: int = section_of[n]
			var end: int = n
			while end < lines.size() and section_of[end] == section:
				end += 1
			out.append_array(_section(n, end))
			n = end
		return "\n".join(out)

	func _section(from: int, to: int) -> PackedStringArray:
		# Its last lines: those after its last part or STEP line, as they are.
		var tail: int = to
		while tail > from and not lines[tail - 1].strip_edges().begins_with("1 ") \
				and lines[tail - 1].strip_edges() != "0 STEP":
			tail -= 1
		var count: int = blocks[section_of[from]]
		var parts_in: Array = []
		# Each step's lines in an Array: a PackedStringArray read out of an
		# Array is a copy, and what was appended to it went nowhere.
		var kept: Array = []
		for _b: int in count:
			parts_in.append(0)
			kept.append([])
		var moved_in: Array = []
		for _b: int in count:
			moved_in.append([])
		var at: int = 0
		var steps_at: Array = []        # the file's STEP lines, by the step they open
		for n: int in range(from, tail):
			var line: String = lines[n].strip_edges()
			if line == "0 STEP":
				at += 1
				steps_at.append(lines[n])
				continue
			if block.has(n):
				parts_in[int(block[n])] += 1
				if int(block[n]) == at:
					(kept[at] as Array).append(lines[n])
				else:
					if n > from and _attached(n - 1):
						(moved_in[int(block[n])] as Array).append(lines[n - 1])
					(moved_in[int(block[n])] as Array).append(lines[n])
				continue
			if _attached(n) and int(block[n + 1]) != at:
				continue
			(kept[at] as Array).append(lines[n])
		var out := PackedStringArray()
		var any_before: bool = false
		for b: int in count:
			var has_parts: bool = int(parts_in[b]) > 0
			if b > 0 and has_parts and any_before:
				out.append(steps_at[b - 1] if b - 1 < steps_at.size() else "0 STEP")
			out.append_array(PackedStringArray(moved_in[b]))
			out.append_array(PackedStringArray(kept[b]))
			any_before = any_before or has_parts
		for n: int in range(tail, to):
			out.append(lines[n])
		return out

	## The lines of [param after] that are not [param before]'s in the same
	## section, or the other way, besides STEP lines: "section: line".
	static func other_changes(before: String, after: String) -> Array:
		var a: Dictionary = _counted(before)
		var b: Dictionary = _counted(after)
		var out: Array = []
		for key: String in a:
			if int(b.get(key, 0)) != int(a[key]):
				out.append(key)
		for key: String in b:
			if not a.has(key):
				out.append(key)
		return out

	static func _counted(text: String) -> Dictionary:
		var out: Dictionary = {}
		var section: String = ""
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("0 FILE "):
				section = line.strip_edges()
			if line.strip_edges() == "0 STEP":
				continue
			var key: String = section + ": " + line
			out[key] = int(out.get(key, 0)) + 1
		return out
