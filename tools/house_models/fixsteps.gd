## The step fixer: a model's build steps put in an order the Tested mark passes.
##
##   godot --headless --path . --script tools/house_models/fixsteps.gd -- FLAT.ldr OUT.ldr
##
## FLAT is one file (flatten.py), with its author's steps (flatten.py --steps)
## or none (the app works them out). Its steps are read as the Tested mark reads
## them (src/assembly/tested.gd), and put right in rounds: a part put down before
## what holds it is carried to the first step where, with that step's parts, it
## is held by something that stands; a part hanging past what its studs hold,
## and a step the build so far tips over at, wait for the step that relieves
## them; a part hidden behind what is built goes in with the part that holds it,
## and when it is hidden even there, the parts in front of it wait for it.
## OUT is flat, its steps the author's (AUTHORED_STEPS), and the run ends with
## the Tested mark's own four findings on it, each part still named with its
## line in OUT, the "whole" test's too (each pair that passes into the other,
## each loose piece with all its parts). What it cannot mend (a part still
## hidden, a joint over its load, a part held by nothing in the finished model)
## is said, for a hand to settle.
##
## Used by seed211 (2026-10-24) on the twelve house models designed for the
## gallery: every design but the cactus failed "steps" as designed (the fox
## put 122 parts in the air), and each passed all four tests after it. Used by
## house227 (2026-10-24) on the older house models: the corner shop's wall
## studs were hidden until what stood in front of them waited. The
## Tested check is not copied here: an id-reporting copy is made from
## src/assembly/tested.gd as it stands when this runs ([method _tested_copy]).
extends SceneTree

var library: PartLibrary
var world: BrickWorld
var builder: Builder
var raw: Array = []
var head: Array = []
var line_of: Dictionary = {}
var by_id: Dictionary = {}
var near: Dictionary = {}
var bottom: Dictionary = {}
var piece: Dictionary = {}
var lattice: BrickLattice
var T: GDScript

func _initialize() -> void:
	_run()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("fixsteps: FLAT.ldr OUT.ldr"); quit(2); return
	T = _tested_copy()
	if T == null:
		quit(1); return
	library = PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue"); quit(1); return
	var text: String = FileAccess.get_file_as_string(args[0])
	for line: String in text.replace("\r\n", "\n").split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("1 "):
			raw.append(t)
		elif t.begins_with("0 !BRICKWORKS FLOOR") or t.begins_with("0 !BRICKWORKS MOTION"):
			head.append(t)
	var store := ModelStore.new()
	store.library = library
	world = BrickWorld.new()
	world.library = library
	world.hold_drawing()
	get_root().add_child(world)
	store.world = world
	builder = Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	store.builder = builder
	var model: LdrModel = LdrModel.parse(text, "model")
	var authored: bool = model.steps_are_authored()
	var n: int = -1
	var pairs: Array = []
	var known: Array = []
	for item: Variant in model.flatten(library.parts):
		n += 1
		var placement: LdrModel.Placement = item
		if not authored:
			placement.step = -1
		var real: String = library.resolve(placement.part_id)
		if real != placement.part_id:
			placement.transform = placement.transform * library.moved_by(placement.part_id)
			placement.part_id = real
		if library.parts.has(placement.part_id):
			known.append([placement, n])
			pairs.append([placement.part_id, placement.transform])
		else:
			print("  unknown part on line %d: %s" % [n, raw[n]])
	var up := Vector3(0.0, ModelStore._lift_from(store.lowest_of(pairs), false), 0.0)
	for one: Array in known:
		var placement: LdrModel.Placement = one[0]
		var at: Transform3D = placement.transform
		at.origin += up
		var id: int = world.add_brick(placement.part_id, placement.color_code, at)
		if id == 0:
			print("  no geometry: %s" % raw[one[1]]); continue
		world.get_brick(id).step = placement.step
		line_of[id] = one[1]
	var job := Working.Job.new()
	var steps: Array[Instructions.Step] = await Instructions.plan_paced(world, library, {}, {}, job, AuthorSteps.any(world))
	var seq: Array = _seq_of(steps)
	print("  %d parts in %d steps (%s)" % [line_of.size(), seq.size(), "authored" if authored else "worked out"])
	_graph()
	var after: Dictionary = {}   # id -> ids it must not go in before
	var early: Dictionary = {}   # id -> true: goes in with what holds it
	var out_seq: Array = seq
	var found: Dictionary = {}
	for round: int in 8:
		out_seq = _early(_carry(seq, after), early)
		for i: int in out_seq.size():
			for id: int in out_seq[i]:
				world.get_brick(id).step = i
		steps = await Instructions.plan_paced(world, library, {}, {}, Working.Job.new(), true)
		T.found_ids = {}
		found = await T.check(world, lattice, library, steps, {}, Working.Job.new())
		var tips: Array = T.found_ids.get("tips", [])
		var number: Dictionary = {}
		var main_steps: Array = []
		for step: Instructions.Step in steps:
			number[step.number] = step
			if not step.in_callout() and not step.brick_ids.is_empty():
				main_steps.append(step)
		var later := func(n: int) -> Instructions.Step:
			for step: Instructions.Step in main_steps:
				if step.number > n:
					return step
			return null
		var last: Dictionary = {}   # beyond id -> last failing step
		for one: Array in tips:
			last[int(one[1])] = maxi(int(last.get(int(one[1]), 0)), int(one[0]))
		print("  round %d: %d steps, %d floating, %d hidden, %d steps over a joint, %d tipping" % [round, out_seq.size(),
			T.found_ids.get("floating", []).size(), T.found_ids.get("hidden", []).size(), tips.size(),
			T.found_ids.get("tipsover", []).size()])
		var tipping: Dictionary = {}
		for one: Array in T.found_ids.get("tipsover", []):
			tipping[int(one[0])] = true
		var added: int = 0
		# Hidden even beside what holds it: what hides it waits for it.
		var hiders: Dictionary = T.found_ids.get("hidden_by", {})
		for one: Array in T.found_ids.get("hidden", []):
			var h: int = int(one[1])
			if not early.has(h):
				early[h] = true
				added += 1
				continue
			for o: Variant in hiders.get(h, []):
				if int(o) != h and line_of.has(int(o)) and not (after.get(int(o), []) as Array).has(h):
					after.get_or_add(int(o), []).append(h)
					added += 1
		if last.is_empty() and tipping.is_empty() and added == 0:
			break
		# A step the build so far tips over at goes in with the first step after it that stands.
		for s: int in tipping:
			var next: int = s
			var relief_step: Instructions.Step = later.call(next)
			while relief_step != null and tipping.has(relief_step.number):
				relief_step = later.call(relief_step.number)
			if relief_step == null or relief_step.brick_ids.is_empty():
				continue
			var r: int = int(relief_step.brick_ids[0])
			for id: int in (number[s] as Instructions.Step).brick_ids:
				if id != r and not (after.get(id, []) as Array).has(r):
					after.get_or_add(id, []).append(r)
					added += 1
		for b: int in last:
			var relief: Instructions.Step = later.call(int(last[b]))
			if relief == null or relief.brick_ids.is_empty():
				continue
			var r: int = int(relief.brick_ids[0])
			if not (after.get(b, []) as Array).has(r):
				after.get_or_add(b, []).append(r)
				added += 1
		if added == 0:
			print("  nothing more to carry: %s" % str(last))
			break
	# Written out, flat, the author's steps.
	var lines: Array = ["0 model", "0 Name: model.ldr", "0 Author: Brickworks", LdrModel.AUTHORED_META] + head + [""]
	var new_line: Dictionary = {}
	var written: Dictionary = {}
	for i: int in out_seq.size():
		for id: int in out_seq[i]:
			lines.append(raw[line_of[id]])
			new_line[id] = lines.size()
			written[line_of[id]] = true
		lines.append("0 STEP")
	for i: int in raw.size():
		if not written.has(i):
			lines.insert(lines.size() - 1, raw[i])
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	if f == null:
		print("fixsteps: cannot write %s" % args[1]); quit(1); return
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()
	print("  written %s" % args[1])
	if found.has("tests"):
		for test: String in ["stands", "steps", "parts", "whole"]:
			var t: Dictionary = found["tests"][test]
			print("  %s %s: %s" % [test, "ok" if bool(t.get("ok")) else "FAILS", str(t.get("why", "")).left(600)])
	for kind: String in ["floating", "hidden", "tips"]:
		for one: Array in T.found_ids.get(kind, []):
			var id: int = int(one[1])
			print("    %s at step %d: line %d %s" % [kind, int(one[0]), int(new_line.get(id, -1)), raw[line_of[id]]])
	# The whole test's pairs and loose pieces, every part by its line.
	var bricks: Array = T.found_ids.get("bricks", [])
	var at_line := func(k: int) -> String:
		var id: int = (bricks[k] as BrickWorld.Brick).id
		return "line %d %s" % [int(new_line.get(id, -1)), raw[line_of[id]]]
	for one: Array in (T.found_ids.get("whole", {}) as Dictionary).get("into", []):
		print("    into by %.1f LDU: %s\n                   into %s" % [float(one[2]), at_line.call(int(one[0])),
			at_line.call(int(one[1]))])
	for one: Dictionary in (T.found_ids.get("whole", {}) as Dictionary).get("apart", []):
		print("    apart, %s, %d parts:" % [str(one["kind"]), int(one["size"])])
		for k: Variant in (one["all"] as Array).slice(0, 40):
			print("      %s" % at_line.call(int(k)))
	quit(0)


func _seq_of(steps: Array[Instructions.Step]) -> Array:
	var seq: Array = []
	var seen: Dictionary = {}
	for step: Instructions.Step in steps:
		var ids: Array = []
		for id: int in step.brick_ids:
			if line_of.has(id) and not seen.has(id):
				ids.append(id); seen[id] = true
		for copy: PackedInt64Array in step.copies:
			for id: int in copy:
				if line_of.has(id) and not seen.has(id):
					ids.append(id); seen[id] = true
		if not ids.is_empty():
			seq.append(ids)
	return seq


func _graph() -> void:
	var bricks: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if line_of.has(brick.id) and library.mesh_for(brick.part_id) != null:
			bricks.append(brick)
			by_id[brick.id] = brick
	lattice = BrickLattice.new()
	lattice.keeps_columns = false
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			lattice.occupy_boxes(brick.id, builder.boxes_for(mesh, brick.transform))
	var judge := Stability.new()
	judge.library = library
	judge.lattice = lattice
	var contacts: Dictionary = judge.contacts(bricks)
	var boxes: Dictionary = contacts["boxes"]
	for id: int in by_id:
		var low: int = 0x7FFFFFFF
		var packed: PackedInt32Array = boxes.get(id, PackedInt32Array())
		for at: int in range(1, packed.size(), 6):
			low = mini(low, packed[at])
		bottom[id] = low
	for id: int in by_id:
		near[id] = {}
	var link := func(a: Variant, b: Variant) -> void:
		if a == b or not by_id.has(a) or not by_id.has(b):
			return
		(near[a] as Dictionary)[b] = true
		(near[b] as Dictionary)[a] = true
	var joints: Dictionary = Stability.stud_joints(contacts, library, lattice)
	for held: Dictionary in [joints["studs"], joints["seated"]]:
		for key: int in held:
			link.call(key >> 32, key & 0xFFFFFFFF)
	var entries: Array = []
	var with_paths: Array = []
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		entries.append([brick.id, brick.transform, mesh])
		with_paths.append([brick.id, brick.transform, mesh, brick.part_id, Assemblies.path_of(brick)])
	for held: Dictionary in [Joints.both_ways(entries), Joints.rounds(entries), Joints.held_otherwise(with_paths, library)]:
		for one: Variant in held:
			for other: Variant in (held[one] as Dictionary):
				link.call(one, other)
	var balls: Dictionary = Joints.balls(entries)
	for one: Variant in balls:
		for other: Variant in (balls[one] as Dictionary):
			link.call(one, other)
	for pair: Array in Joints.through(entries):
		link.call(pair[0], pair[1])
	var pieces: int = 0
	for start: int in by_id:
		if piece.has(start):
			continue
		piece[start] = pieces
		var pending: Array[int] = [start]
		while not pending.is_empty():
			var here: int = pending.pop_back()
			for next: int in (near[here] as Dictionary):
				if not piece.has(next):
					piece[next] = pieces
					pending.append(next)
		pieces += 1


## Each of [param early] moved into the step of the part that holds it: the latest of what it
## touches put down before it.
func _early(seq: Array, early: Dictionary) -> Array:
	var step_of: Dictionary = {}
	for i: int in seq.size():
		for id: int in seq[i]:
			step_of[id] = i
	for id: int in early:
		if not step_of.has(id):
			continue
		var here: int = int(step_of[id])
		var best: int = -1
		for other: int in (near.get(id, {}) as Dictionary):
			if step_of.has(other) and int(step_of[other]) < here:
				best = maxi(best, int(step_of[other]))
		if best < 0:
			continue
		(seq[here] as Array).erase(id)
		(seq[best] as Array).append(id)
		step_of[id] = best
	var out: Array = []
	for ids: Array in seq:
		if not ids.is_empty():
			out.append(ids)
	return out


## Each part in at the first step where, with that step's parts, it is held by what stands, and
## not before the parts it must follow.
func _carry(seq: Array, after: Dictionary) -> Array:
	var placed: Dictionary = {}
	var roots: Dictionary = {}
	var begun: Dictionary = {}
	var lowest: int = 0x7FFFFFFF
	var carried: Array = []
	var out_seq: Array = []
	var k: int = 0
	while k < seq.size() or not carried.is_empty():
		var trying: Array = carried + ((seq[k] as Array) if k < seq.size() else [])
		carried = []
		if trying.is_empty():
			k += 1
			continue
		# Not before what it must follow: those wait until it is placed or comes in with this step.
		var coming: Dictionary = {}
		for id: int in trying:
			coming[id] = true
		var now: Array = []
		for id: int in trying:
			var ready: bool = true
			for r: int in after.get(id, []):
				if not placed.has(r) and not coming.has(r):
					ready = false
			if ready:
				now.append(id)
			else:
				carried.append(id)
		for id: int in now:
			placed[id] = true
			if by_id.has(id):
				lowest = mini(lowest, int(bottom[id]))
		if out_seq.is_empty():
			for id: int in now:
				roots[id] = true
		for id: int in now:
			if by_id.has(id) and not begun.has(piece[id]):
				begun[piece[id]] = true
				roots[id] = true
		var stands: Dictionary = {}
		var queue: Array = []
		for id: int in placed:
			if roots.has(id) or (by_id.has(id) and int(bottom[id]) <= lowest + Balance.ON_FLOOR):
				stands[id] = true
				queue.append(id)
		while not queue.is_empty():
			var here: int = queue.pop_back()
			for next: int in (near.get(here, {}) as Dictionary):
				if placed.has(next) and not stands.has(next):
					stands[next] = true
					queue.append(next)
		var kept: Array = []
		for id: int in now:
			if stands.has(id) or not by_id.has(id):
				kept.append(id)
			else:
				placed.erase(id)
				carried.append(id)
		if k >= seq.size() and kept.is_empty():
			kept = carried
			carried = []
		if not kept.is_empty():
			out_seq.append(kept)
		k += 1
	return out_seq



## Tested's own check, made to say which parts it found: the class as it is in
## src/assembly/tested.gd, without its class_name, naming every failure rather
## than three, and keeping the ids of what floats, hides and hangs in
## found_ids. Null, and says why, when tested.gd no longer reads as expected.
func _tested_copy() -> GDScript:
	var s: String = FileAccess.get_file_as_string("res://src/assembly/tested.gd")
	var edits: Array = [
		["class_name Tested\n", ""],
		["const NAMED := 3", "const NAMED := 100000"],
		["static var laps: Dictionary = {}", "static var laps: Dictionary = {}\nstatic var found_ids: Dictionary = {}"],
		["\tlaps[\"hidden\"] = test.hidden_us",
			"\tlaps[\"hidden\"] = test.hidden_us\n\tfound_ids[\"floating\"] = test.floating\n\tfound_ids[\"hidden\"] = test.hidden"],
		["\t\t\t\ttips.append([step.number, \"%s %s %s on",
			"\t\t\t\tfound_ids.get_or_add(\"tips\", []).append([step.number, one.beyond, one.held_by])\n\t\t\t\ttips.append([step.number, \"%s %s %s on"],
		["\t\t\ttips.append([step.number, \"it tips over",
			"\t\t\tfound_ids.get_or_add(\"tipsover\", []).append([step.number])\n\t\t\ttips.append([step.number, \"it tips over"],
		["\"size\": (members[key] as Array).size(), \"key\": key})",
			"\"size\": (members[key] as Array).size(), \"key\": key, \"all\": members[key]})"],
		["\t\tif float(open.size()) / float(mine.size()) >= SEEN:\n\t\t\treturn false\n\treturn true",
			"\t\tif float(open.size()) / float(mine.size()) >= SEEN:\n\t\t\treturn false\n\t\tfound_ids.get_or_add(\"hidden_by\", {})[thing[0]] = before.keys()\n\treturn true"],
		["\ttests[\"whole\"] = _whole_said(whole, bricks, library)",
			"\tfound_ids[\"whole\"] = whole\n\tfound_ids[\"bricks\"] = bricks\n\ttests[\"whole\"] = _whole_said(whole, bricks, library)"],
	]
	for edit: Array in edits:
		if s.find(str(edit[0])) < 0:
			print("fixsteps: src/assembly/tested.gd no longer has \"%s\"; bring this copy up to date" % str(edit[0]).strip_edges().left(60))
			return null
		s = s.replace(str(edit[0]), str(edit[1]))
	var script := GDScript.new()
	script.source_code = s
	if script.reload() != OK:
		print("fixsteps: the copy of the Tested check did not compile")
		return null
	return script
