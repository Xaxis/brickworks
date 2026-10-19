## A shared model's build steps, carried with it: worked out once, by the
## person sharing it, so the phone that opens the link to build from never
## works them out. On a phone slowed four times that was 5 to 10 s for
## 1,000 parts and over a minute for 4,000, before the first step.
##
## Written at the end of the model's text, as LDraw meta lines any other
## tool reads past:
##
##   0 !BRICKWORKS PAGES {"v":1,"model":<sha256>,"order":<sha256>,"parts":N,"mode":0,"steps":M}
##   0 !BRICKWORKS PAGE {"n":1,"b":[0,1,2],...}      one line a step
##
## "model" is the model's own text, lines trimmed, blank lines and these
## lines left out (so a server or an editor that changes line endings does
## not lose them); "order" is the parts and colours in the order the viewer
## puts them down (ModelStore.open_text: the file flattened, each known
## part in turn), which is what a step's "b" counts in. The viewer uses them
## only when both match what it opened, and works the steps out as before
## otherwise: an old link, a model edited since, a catalogue that differs.
##
## The steps are worked out on a world of their own, put down exactly as
## the viewer puts the text down, by the same Instructions.plan_paced the
## viewer's timeline runs, so a page is the page the phone would have made.
class_name SharedPages
extends RefCounted

const VERSION := 1
const HEAD := "0 !BRICKWORKS PAGES "
const PAGE := "0 !BRICKWORKS PAGE "
## Past this the model goes without them (api/share.js takes 2 MB).
const MOST_BYTES := 1900000


## [param text] with its steps at its end (any carried before taken off),
## or as it was when they cannot be worked out.
static func attach(text: String, library: PartLibrary, store: ModelStore,
		job: Working.Job = null) -> String:
	return str((await attach_tested(text, library, store, job, false))["text"])


## [param text] with its steps at its end, as [method attach], and what the
## Tested mark found of the model built by those very steps (Tested.check),
## worked out on the same world: {"text", "tested"}, "tested" {} when there
## are no steps to carry, or [param test] is false. The finding names the
## text it is of (Tested.fingerprint), so it goes with this text alone.
static func attach_tested(text: String, library: PartLibrary, store: ModelStore,
		job: Working.Job = null, test: bool = true) -> Dictionary:
	var bare: String = strip(text)
	var made: Dictionary = await pages_for(bare, library, store, job, test)
	if made.is_empty():
		return {"text": bare, "tested": {}}
	var lines := PackedStringArray()
	lines.append(HEAD + JSON.stringify(made["head"]))
	for step: Dictionary in made["steps"]:
		lines.append(PAGE + JSON.stringify(step))
	var out: String = bare.strip_edges(false, true) + "\r\n" + "\r\n".join(lines) + "\r\n"
	if out.to_utf8_buffer().size() > MOST_BYTES:
		return {"text": bare, "tested": {}}
	var tested: Dictionary = made.get("tested", {})
	if tested.has("tests"):
		tested["model"] = Tested.fingerprint(out)
	return {"text": out, "tested": tested}


## [param text] without carried steps.
static func strip(text: String) -> String:
	if text.find("0 !BRICKWORKS PAGE") < 0:
		return text
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.strip_edges().begins_with("0 !BRICKWORKS PAGE"):
			kept.append(line)
	return "\n".join(kept)


## The model's text as the steps are matched to it.
static func fingerprint(text: String) -> String:
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("0 !BRICKWORKS PAGE"):
			continue
		kept.append(trimmed)
	return "\n".join(kept).sha256_text()


## The parts in the order they are put down, as the steps count them.
static func order_of(world: BrickWorld, scenery: Dictionary) -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not scenery.has(brick.id):
			ids.append(brick.id)
	# In the order they were put down: ids are handed out in turn.
	ids.sort()
	var named := PackedStringArray()
	for id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(id)
		named.append("%s:%d" % [brick.part_id, brick.color_code])
	return [ids, "|".join(named).sha256_text()]


## {"head", "steps"} for [param text], or {} when it has nothing to build.
static func pages_for(text: String, library: PartLibrary, store: ModelStore,
		job: Working.Job = null, test: bool = false) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "model")
	if model == null:
		return {}
	var world := BrickWorld.new()
	world.library = library
	# Never drawn: nothing in it is written to the graphics card.
	world.hold_drawing()
	var authored: bool = model.steps_are_authored()
	var known: Array = []
	# As ModelStore.open_text puts a file down: flattened, a Studio part by
	# its LDraw number, a mirrored copy unmirrored, a retired number as the
	# part it became, the parts the library knows in turn, lifted as it lifts
	# them.
	for item: Variant in model.flatten(library.parts):
		var placement: LdrModel.Placement = item
		if not authored:
			placement.step = -1
		placement.part_id = store.studio_part(placement.part_id)
		if placement.mirrored:
			Assemblies.unmirror(placement, library)
		var real: String = library.resolve(placement.part_id)
		if real != placement.part_id:
			placement.transform = placement.transform * library.moved_by(placement.part_id)
			placement.part_id = real
		if library.parts.has(placement.part_id):
			known.append(placement)
	if known.is_empty():
		_let_go(world)
		return {}
	var pairs: Array = []
	for placement: LdrModel.Placement in known:
		pairs.append([placement.part_id, placement.transform])
	var up := Vector3(0.0, ModelStore._lift_from(store.lowest_of(pairs),
		model.author.strip_edges() != "Brickworks"), 0.0)
	if authored:
		world.unit_steps = model.unit_steps.duplicate()
	for placement: LdrModel.Placement in known:
		var at: Transform3D = placement.transform
		at.origin += up
		var brick_id: int = world.add_brick(placement.part_id, placement.color_code, at)
		if brick_id == 0:
			# A part with no geometry here: the viewer would put it down
			# when it arrives, out of turn. Not carried.
			_let_go(world)
			return {}
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		brick.group = placement.group
		brick.unit = placement.unit
		brick.step = placement.step
	var mode: int = StepsBar.AUTHORS if AuthorSteps.any(world) else 0
	var asked: Working.Job = job if job != null else Working.Job.new()
	var steps: Array[Instructions.Step] = await Instructions.plan_paced(
		world, library, {}, {}, asked, mode == StepsBar.AUTHORS)
	var order: Array = order_of(world, {})
	# The Tested mark, on the world the steps were worked out on: its parts'
	# covers in a lattice of its own, as the builder makes them.
	var tested: Dictionary = {}
	if test and not steps.is_empty() and not asked.cancelled and store.builder != null:
		var lattice := BrickLattice.new()
		lattice.keeps_columns = false
		for brick: BrickWorld.Brick in world.bricks():
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh != null:
				lattice.occupy_boxes(brick.id, store.builder.boxes_for(mesh, brick.transform))
		tested = await Tested.check(world, lattice, library, steps, {}, asked)
	_let_go(world)
	if steps.is_empty() or asked.cancelled:
		return {}
	var index: Dictionary = {}
	for n: int in (order[0] as Array).size():
		index[order[0][n]] = n
	var out: Array = []
	for step: Instructions.Step in steps:
		out.append(_step_to(step, index))
	return {"head": {"v": VERSION, "model": fingerprint(text), "order": order[1],
		"parts": (order[0] as Array).size(), "mode": mode, "steps": steps.size()},
		"steps": out, "tested": tested}


## The steps carried in [param text], for the bricks of [param world] as the
## viewer put the text down, or none when they are not there or do not
## match: then the steps are worked out as before. {"mode", "steps"}.
static func read(text: String, world: BrickWorld, scenery: Dictionary) -> Dictionary:
	var at: int = text.find(HEAD)
	if at < 0:
		return {}
	var lines: PackedStringArray = text.substr(at).split("\n")
	var head: Variant = JSON.parse_string(lines[0].strip_edges().trim_prefix(HEAD.strip_edges()).strip_edges())
	if not (head is Dictionary) or int((head as Dictionary).get("v", 0)) != VERSION:
		return {}
	if str(head.get("model", "")) != fingerprint(text):
		return {}
	var order: Array = order_of(world, scenery)
	var ids: Array = order[0]
	if int(head.get("parts", -1)) != ids.size() or str(head.get("order", "")) != order[1]:
		return {}
	var steps: Array[Instructions.Step] = []
	for n: int in range(1, lines.size()):
		var line: String = lines[n].strip_edges()
		if not line.begins_with(PAGE.strip_edges()):
			continue
		var said: Variant = JSON.parse_string(line.trim_prefix(PAGE.strip_edges()).strip_edges())
		if not (said is Dictionary):
			return {}
		var step: Instructions.Step = _step_from(said, ids)
		if step == null:
			return {}
		steps.append(step)
	if steps.size() != int(head.get("steps", -1)):
		return {}
	return {"mode": int(head.get("mode", 0)), "steps": steps}


## A world never drawn, let go once its deferred rebuild has been and gone.
static func _let_go(world: BrickWorld) -> void:
	world.queue_free()


static func _step_to(step: Instructions.Step, index: Dictionary) -> Dictionary:
	var out: Dictionary = {"i": step.index, "n": step.number, "b": _indices(step.brick_ids, index)}
	if not step.parts.is_empty():
		out["p"] = step.parts
	if step.unsupported:
		out["u"] = 1
	if not step.section.is_empty():
		out["s"] = step.section
	if not step.assembly.is_empty():
		out["a"] = step.assembly
	if step.callout != 0:
		out["c"] = [step.callout, step.callout_step, step.callout_steps]
	if step.times != 1:
		out["t"] = step.times
	if step.figure:
		out["f"] = 1
	if not step.shown_ids.is_empty():
		out["w"] = _indices(step.shown_ids, index)
	if not step.copies.is_empty():
		out["k"] = step.copies.map(func(copy: PackedInt64Array) -> Array:
			return _indices(copy, index))
	if not step.authored_in.is_empty() or step.authored_step != -1:
		out["ai"] = [step.authored_in, step.authored_step]
	return out


static func _indices(ids: PackedInt64Array, index: Dictionary) -> Array:
	var out: Array = []
	for id: int in ids:
		out.append(int(index.get(id, -1)))
	return out


static func _ids(said: Variant, ids: Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	if not (said is Array):
		return out
	for n: Variant in said:
		var k: int = int(n)
		out.append(int(ids[k]) if k >= 0 and k < ids.size() else -1)
	return out


static func _step_from(said: Dictionary, ids: Array) -> Instructions.Step:
	var step := Instructions.Step.new()
	step.index = int(said.get("i", 0))
	step.number = int(said.get("n", 0))
	step.brick_ids = _ids(said.get("b", []), ids)
	if step.brick_ids.has(-1):
		return null
	var parts: Variant = said.get("p", {})
	if parts is Dictionary:
		for part: Variant in parts:
			step.parts[str(part)] = int(parts[part])
	step.unsupported = int(said.get("u", 0)) == 1
	step.section = str(said.get("s", ""))
	step.assembly = str(said.get("a", ""))
	var callout: Variant = said.get("c", [])
	if callout is Array and (callout as Array).size() == 3:
		step.callout = int(callout[0])
		step.callout_step = int(callout[1])
		step.callout_steps = int(callout[2])
	step.times = int(said.get("t", 1))
	step.figure = int(said.get("f", 0)) == 1
	step.shown_ids = _ids(said.get("w", []), ids)
	var copies: Variant = said.get("k", [])
	if copies is Array:
		for copy: Variant in copies:
			step.copies.append(_ids(copy, ids))
	var authored: Variant = said.get("ai", [])
	if authored is Array and (authored as Array).size() == 2:
		step.authored_in = str(authored[0])
		step.authored_step = int(authored[1])
	return step
