## How close the booklet's worked-out steps come to the steps real set
## authors chose, and whether a builder could follow each.
##
##   godot --headless --path . --script src/dev/steps_score.gd -- [--out=FILE] [--seed=N] FILE.mpd ...
##   godot --headless --path . --script src/dev/steps_score.gd -- --selftest
##
## The LDraw model repository's files carry their authors' 0 STEP lines,
## which the repository asks to follow the printed instructions. Each file
## is opened as File, Open opens it, and six builds of it are scored:
##
##   author   the author's steps as LDraw means them: every sub-model built
##            apart in its own steps, on its own table, then put on whole in
##            the step its parent places it in; copies of one placed in one
##            step built once
##   drawn    the author's steps as the booklet draws them (Instructions'
##            authored plan), which builds a big sub-model where it stands
##   ours     Instructions.plan on the model with every step taken away
##            and its parts in a shuffled order, so nothing of the author's
##            order reaches the planner through the order of the file;
##            its sub-models are kept, as a file without steps has them
##   flat     the same with the sub-models taken away too: a model built
##            by hand, with nothing to say what is built on the side
##   file     the parts in the order the file lists them, cut into steps
##            of the size ours takes
##   height   bottom up: the lowest first, then by x and z, cut the same
##
## For each, one JSON line a file goes to the out file with each part's
## step (tools/steps_score.py works out Kendall's tau and the rest from
## them) and four things a builder meets on the page:
##
##   hidden    a new thing that shows less than SEEN of itself from the
##             front and from the back, the two ways a booklet looks
##             (BookletMaker._choose_views), with everything placed by the
##             end of its step in front of it. Agrawala et al.: "all the
##             new parts added in each step ... must be visible"
##   blocked   a thing put in under a part placed in an earlier step, which
##             rests on it: it cannot be pressed on from above
##   floating  a thing held to nothing that reaches the ground at the end
##             of its step (built on the side, the table it is built on)
##   sizes     how many things each step adds, and of how many kinds
##
## A thing is a part, or a copy of a sub-assembly put on whole. "Held" is
## decided here and not by the planner, so the planner is not marked by its
## own rules: what rests on what by the parts' covers (Stability.contacts)
## and every joint the build check reads (pins and axles, rounds, balls,
## axles through holes, what is held otherwise). A thing that graph does
## not hold even when its build is finished is not counted either way.
##
## Every run first builds models whose answers are known and checks the
## measures against them, and refuses to score if one is wrong
## (--selftest does only that). Not in the suite: tools/steps_score.py runs
## it in shards.
extends SceneTree

const SETS := "res://vendor/omr/files"
## How much of a new thing has to show, from one side or the other, for it
## to count as seen.
const SEEN := 0.1
## The visibility pictures' pixel, and the spacing of the points sampled
## on each face of a cover, in LDU.
const PIXEL := 4.0
## A cover's cells are 2 LDU; within this many of the lowest a part stands
## on the ground, or on the table a sub-assembly is built on.
const ON_THE_GROUND := 1
const SEED := 20261015

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
## The model again, stepless and shuffled, for the planner.
var _other: BrickWorld
## The design check, for --check (Assistant._check, only the ground holding).
var _assistant: Assistant
var _checking: bool = false
## --explain: say, for ours, what each floating, hidden and blocked thing is,
## what the planner had it need, and what the measure's graph holds it to.
var _explaining: bool = false
var _failures: int = 0


## What a model's parts are, where, and what holds what, by index: the
## order the file lists them in.
class Geometry extends RefCounted:
	var count: int = 0
	var part: PackedStringArray = PackedStringArray()
	var bottom: PackedInt32Array = PackedInt32Array()
	var floor_cell: int = 0
	## index -> the parts it is held to, either way round.
	var near: Array = []
	## index -> the parts resting on it, not joined to it by a pin, an axle,
	## a clip or a hinge: those go in along their line, not from above.
	var above: Array = []
	## Whether the finished model holds it to the ground.
	var held: PackedByteArray = PackedByteArray()
	## Which piece of the finished model it is in: the parts it is held to,
	## any way round, by any route. A second vehicle standing beside the
	## first is a piece of its own.
	var piece: PackedInt32Array = PackedInt32Array()
	var piece_size: PackedInt32Array = PackedInt32Array()
	## Per view: index -> the pixels it covers and how near each is.
	var pixels: Array = []
	var depths: Array = []
	var area: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_path: String = "user://steps_score.jsonl"
	var shuffle_seed: int = SEED
	var selftest: bool = false
	var named: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--seed="):
			shuffle_seed = int(argument.trim_prefix("--seed="))
		elif argument == "--check":
			_checking = true
		elif argument == "--explain":
			_explaining = true
		elif argument == "--selftest":
			selftest = true
		else:
			named.append(argument)
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_other = BrickWorld.new()
	_other.library = _library
	get_root().add_child(_other)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	await process_frame

	# The measures checked on models whose answers are known, every run:
	# a score from a measure that is wrong is worse than none.
	_selftest()
	if _failures > 0:
		print("steps score: %d self-test failures, nothing scored" % _failures)
		quit(1)
		return
	if selftest:
		print("steps score: the measures give the known answers")
		quit(0)
		return

	var done: Dictionary = {}
	if FileAccess.file_exists(out_path):
		for line: String in FileAccess.get_file_as_string(out_path).split("\n"):
			var row: Variant = JSON.parse_string(line) if not line.is_empty() else null
			if row is Dictionary and not (row as Dictionary).has("begin"):
				done[str(row["file"])] = true
	var out := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path)
		else FileAccess.WRITE)
	if out == null:
		print("cannot write %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	out.seek_end()
	for path: String in named:
		if done.has(path.get_file()):
			continue
		out.store_line(JSON.stringify({"file": path.get_file(), "begin": true}))
		out.flush()
		var row: Dictionary = _score(path, shuffle_seed)
		out.store_line(JSON.stringify(row))
		out.flush()
		print("  %s: %d parts, %.1f s%s" % [path.get_file(), int(row.get("parts", 0)),
			float(row.get("seconds", 0.0)),
			"" if not row.has("error") else " (%s)" % row["error"]])
	out.close()
	quit(0)


# -- one file ------------------------------------------------------------------


func _score(path: String, shuffle_seed: int) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var opened: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	var row: Dictionary = {"file": path.get_file()}
	var bricks: Array = _world.bricks()
	bricks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	row["parts"] = bricks.size()
	if bricks.is_empty():
		row["error"] = str(opened.get("error", "nothing placed"))
		return row
	if not AuthorSteps.any(_world):
		row["error"] = "no author's steps"
		return row
	var index_of: Dictionary = {}
	for index: int in bricks.size():
		index_of[(bricks[index] as BrickWorld.Brick).id] = index
	var geometry: Geometry = _geometry(bricks, index_of)
	var laps: Dictionary = {"geometry": Time.get_ticks_msec() - started}

	var plans: Dictionary = {}
	var clock: int = Time.get_ticks_msec()
	plans["author"] = _authors(bricks)
	plans["drawn"] = _from_plan(Instructions.plan(_world, _library, {}, {}, true), index_of,
		bricks.size())
	laps["author"] = Time.get_ticks_msec() - clock

	# Shuffled, so a tie the planner breaks by the order bricks were added
	# in is not broken by the author's order.
	var rng := RandomNumberGenerator.new()
	rng.seed = shuffle_seed ^ hash(path.get_file())
	var shuffled: Array = range(bricks.size())
	for at: int in range(shuffled.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, at)
		var kept: int = shuffled[at]
		shuffled[at] = shuffled[other]
		shuffled[other] = kept
	for variant: String in ["ours", "flat"]:
		clock = Time.get_ticks_msec()
		var back: Dictionary = _restaged(bricks, shuffled, variant == "ours")
		plans[variant] = _from_plan(Instructions.plan(_other, _library), back, bricks.size())
		laps[variant] = Time.get_ticks_msec() - clock
		if _explaining and variant == "ours":
			_explain(plans[variant], back, bricks, geometry)
		_other.clear()

	var per: int = Instructions._per_step(bricks.size())
	plans["file"] = _chunked(range(bricks.size()), per)
	var by_height: Array = range(bricks.size())
	var boxes: Array = []
	for brick: BrickWorld.Brick in bricks:
		boxes.append(brick.transform * _library.mesh_for(brick.part_id).bounds)
	by_height.sort_custom(func(a: int, b: int) -> bool:
		var one: AABB = boxes[a]
		var two: AABB = boxes[b]
		if absf(one.position.y - two.position.y) > 0.5:
			return one.position.y < two.position.y
		if absf(one.position.x - two.position.x) > 0.5:
			return one.position.x < two.position.x
		if absf(one.position.z - two.position.z) > 0.5:
			return one.position.z < two.position.z
		return a < b)
	plans["height"] = _chunked(by_height, per)

	var scored: Dictionary = {}
	for name: String in plans:
		clock = Time.get_ticks_msec()
		scored[name] = _measure(plans[name], geometry)
		laps["measure " + name] = Time.get_ticks_msec() - clock
	row["orders"] = scored
	if _checking and bricks.size() <= CHECKED_MOST:
		row["checked"] = _build_check(plans, bricks)
	row["units"] = _units(bricks)
	row["held"] = Array(geometry.held).count(1)
	row["part_ids"] = geometry.part
	row["per_step"] = per
	row["laps"] = laps
	row["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
	return row


## What the planner believed of each thing ours leaves floating, hidden or
## put in under, against what the measure's graph holds it to: printed.
func _explain(build: Dictionary, back: Dictionary, bricks: Array, g: Geometry) -> void:
	var scored: Dictionary = _measure(build, g)
	var rank: PackedInt32Array = scored["rank"]
	var id_of: Dictionary = {}
	for id: int in back:
		id_of[int(back[id])] = id
	var nodes: Array[Instructions.Node2] = Instructions._survey(_other, _library, {})
	Instructions._find_supports(nodes, _other, _library)
	Instructions._find_joints(nodes, _other, _library)
	Instructions._tidy_needs(nodes)
	Instructions._find_hangers(nodes)
	var node_of: Dictionary = {}
	for node: Instructions.Node2 in nodes:
		node_of[int(back.get(node.id, -1))] = node
	var types: String = scored["types"]
	var name_of := func(index: int) -> String:
		var info: PartLibrary.PartInfo = _library.parts.get(g.part[index])
		return "%s %s" % [g.part[index], info.name.strip_edges().replace("  ", " ") if info else "?"]
	var steps_of := func(ids: PackedInt64Array) -> String:
		var out := PackedStringArray()
		for id: int in ids:
			var index: int = int(back.get(id, -1))
			out.append("%d@%d" % [index, rank[index] if index >= 0 else -9])
		return ",".join(out)
	for what: String in ["floating_pieces", "hidden", "blocked"]:
		print("== %s %d" % [what, (scored["which"][what] as Array).size()])
		for entry: Array in scored["which"][what]:
			var k: int = entry[0]
			var index: int = entry[1]
			if int(entry[2]) > 1:
				print("  step %d (%s) a sub-assembly of %d from %d" % [k, types[k], int(entry[2]), index])
				continue
			var node: Instructions.Node2 = node_of.get(index)
			var near := PackedStringArray()
			for other: int in g.near[index]:
				near.append("%d@%d" % [other, rank[other]])
			if what == "floating_pieces":
				var root: bool = true
				for other: int in g.near[index]:
					if rank[other] >= 0 and rank[other] <= k:
						root = false
				var cls: String = "no node"
				if node != null:
					var touching: bool = false
					for need: int in node.needs:
						if g.near[index].has(int(back.get(need, -1))):
							touching = true
					if node.needs.is_empty():
						cls = "needs nothing"
					elif touching:
						cls = "a need touches it"
					elif node.seated:
						cls = "seated, needs do not touch"
					elif not node.boxed.is_empty():
						cls = "boxed, needs do not touch"
					elif not node.weak.is_empty():
						cls = "hung, needs do not touch"
					elif not node.held_by.is_empty():
						cls = "side stud, needs do not touch"
					else:
						cls = "joint, needs do not touch"
				print("CLASS %s %s %s" % [types[k], "root" if root else "cascade", cls])
			var said: String = "  step %d (%s) #%d %s at %s" % [k, types[k], index, name_of.call(index),
				str((bricks[index] as BrickWorld.Brick).transform.origin.round())]
			if entry.size() > 3:
				said += " extra=%d" % int(entry[3])
			print(said)
			print("      measure holds it to: %s" % ",".join(near))
			if node != null:
				print("      planner needs %s boxed %s weak %s held_by %s seated=%s under %s" % [
					steps_of.call(node.needs), steps_of.call(node.boxed), steps_of.call(node.weak),
					steps_of.call(node.held_by), node.seated, steps_of.call(node.under)])


## Files up to this size get --check: a check of a few hundred parts is a
## second or so, and each build is checked at CUTS steps.
const CHECKED_MOST := 300
const CUTS := 5


## The build check the app gives a design (Assistant._check, only the
## ground holding, as an edit is checked for what it leaves hanging) on the
## model as it stands after a few steps of each build, evenly through the
## steps on the model: how many of the parts each such step added does it
## call floating. Not the probe's graph and not the planner's: a third
## opinion. Only parts the check holds in the finished model are counted,
## and only steps on the model (a sub-assembly in the hand is not on it).
func _build_check(plans: Dictionary, bricks: Array) -> Dictionary:
	var out: Dictionary = {}
	_assistant._ground_only = true
	var whole: Assistant.Model = _assistant._model_from_world()
	var floating_whole: Dictionary = {}
	for at: Variant in _assistant._check(whole, true).get("floating", []):
		floating_whole[whole.placements[int(at)].id] = true
	for name: String in plans:
		if name in ["file", "height"] or name.begins_with("drawn"):
			continue
		var build: Dictionary = plans[name]
		var contexts: Array = build["contexts"]
		var on_model: Array = []    ## [step, parts it adds to the model]
		for step: Dictionary in build["steps"]:
			if int(step["context"]) != 0:
				continue
			var adds := PackedInt32Array(step["parts"])
			for child: int in step["attach"]:
				adds.append_array(contexts[child])
			on_model.append(adds)
		var cuts: Dictionary = {}
		for n: int in CUTS:
			cuts[int(float(n + 1) * on_model.size() / float(CUTS + 1))] = true
		var placed: Dictionary = {}
		var counted: int = 0
		var floating: int = 0
		var steps_floating: int = 0
		for k: int in on_model.size():
			for index: int in on_model[k]:
				placed[(bricks[index] as BrickWorld.Brick).id] = true
			if not cuts.has(k):
				continue
			var model: Assistant.Model = _assistant._model_from_world()
			var kept: Array[Assistant.Placement] = []
			for placement: Assistant.Placement in model.placements:
				if placed.has(placement.id):
					kept.append(placement)
			model.placements = kept
			var said: Dictionary = {}
			for at: Variant in _assistant._check(model, true).get("floating", []):
				said[model.placements[int(at)].id] = true
			var here: int = 0
			for index: int in on_model[k]:
				var id: int = (bricks[index] as BrickWorld.Brick).id
				if floating_whole.has(id):
					continue
				counted += 1
				if said.has(id):
					here += 1
			floating += here
			steps_floating += 1 if here > 0 else 0
		out[name] = {"cuts": cuts.size(), "parts": counted, "floating": floating,
			"steps_floating": steps_floating}
	_assistant._ground_only = false
	return out


## The model again in [member _other], its parts added in [param order],
## with no steps, and with its sub-models when [param structure]. Returns
## each new brick id's index in the file.
func _restaged(bricks: Array, order: Array, structure: bool) -> Dictionary:
	_other.clear()
	var back: Dictionary = {}
	for index: int in order:
		var brick: BrickWorld.Brick = bricks[index]
		var id: int = _other.add_brick(brick.part_id, brick.color_code, brick.transform)
		if id == 0:
			continue
		if structure:
			_other.get_brick(id).group = brick.group
			_other.get_brick(id).unit = brick.unit
		back[id] = index
	return back


## The author's sub-assemblies: every copy of a sub-model at every depth,
## by the parts in it. Not one part alone, and not the whole model.
func _units(bricks: Array) -> Array:
	var members: Dictionary = {}
	for index: int in bricks.size():
		var brick: BrickWorld.Brick = bricks[index]
		var path: String = ""
		for segment: String in Assemblies.segments(Assemblies.path_of(brick)):
			path = Assemblies.join(path, segment)
			if not members.has(path):
				members[path] = []
			(members[path] as Array).append(index)
	var out: Array = []
	for path: String in members:
		var parts: Array = members[path]
		if parts.size() >= 2 and parts.size() * 10 < bricks.size() * 9:
			out.append(parts)
	return out


# -- builds, as the measures read them ----------------------------------------
#
# A build is {"steps", "contexts"}. A context is somewhere things are built:
# 0 is the model, on the ground; any other is a copy of a sub-assembly built
# on its own table, by its parts (contexts[n], every part in it at any
# depth). A step is {"context", "parts": what it adds there, by index, the
# ones its picture shows; "also": [[context, parts]] built at the same time
# and not shown, the other copies of a "2x"; "attach": the contexts it puts
# on whole}.


## The author's steps as LDraw means them. A sub-model is built in its own
## steps, before the step of its parent that places it; the copies of one
## placed in one step are built once, the first copy shown and the others
## in step with it.
func _authors(bricks: Array) -> Dictionary:
	var lowest: Dictionary = AuthorSteps.lowest_under(_world)
	var own: Dictionary = {}        ## path -> {step -> [index]}
	var children: Dictionary = {}   ## path -> [child path]
	var members: Dictionary = {"": []}  ## path -> every index in it
	for index: int in bricks.size():
		var brick: BrickWorld.Brick = bricks[index]
		var path: String = Assemblies.path_of(brick)
		if not own.has(path):
			own[path] = {}
		var step: int = maxi(brick.step, 0)
		if not (own[path] as Dictionary).has(step):
			own[path][step] = []
		(own[path][step] as Array).append(index)
		(members[""] as Array).append(index)
		var at: String = ""
		for segment: String in Assemblies.segments(path):
			var inside: String = Assemblies.join(at, segment)
			if not members.has(inside):
				members[inside] = []
				if not children.has(at):
					children[at] = []
				(children[at] as Array).append(inside)
			(members[inside] as Array).append(index)
			at = inside
	var context_of: Dictionary = {"": 0}
	var contexts: Array = [PackedInt32Array(members[""])]
	var paths: Array = members.keys()
	paths.sort()
	for path: String in paths:
		if not path.is_empty():
			context_of[path] = contexts.size()
			contexts.append(PackedInt32Array(members[path]))
	# Copies placed in one step are built in the order the step places
	# them, as LPub builds them: by the first part of each in the file.
	var first_of: Dictionary = {}
	for path: String in members:
		first_of[path] = int((members[path] as Array)[0]) if not (members[path] as Array).is_empty() \
			else 0
	var steps: Array = []
	var built_at: Dictionary = {}   ## index -> the step that built it
	_author_steps("", own, children, context_of, lowest, first_of, steps, built_at)
	# The copies built in step with a first: each part beside its twin.
	for step: Dictionary in steps:
		for twin: Array in step["twins"]:
			var first: PackedInt32Array = contexts[context_of[twin[0]]]
			var other: PackedInt32Array = contexts[context_of[twin[1]]]
			var into: int = context_of[twin[1]]
			var by_step: Dictionary = {}
			for n: int in other.size():
				var k: int = int(built_at.get(first[n], -1)) if first.size() == other.size() \
					else -1
				if k < 0:
					k = int(twin[2])
				if not by_step.has(k):
					by_step[k] = PackedInt32Array()
				(by_step[k] as PackedInt32Array).append(other[n])
			for k: int in by_step:
				(steps[k]["also"] as Array).append([into, by_step[k]])
	for step: Dictionary in steps:
		step.erase("twins")
	return {"steps": steps, "contexts": contexts}


func _author_steps(path: String, own: Dictionary, children: Dictionary, context_of: Dictionary,
		lowest: Dictionary, first_of: Dictionary, steps: Array, built_at: Dictionary) -> void:
	var by_step: Dictionary = {}    ## step -> [own parts, child paths]
	var mine: Dictionary = own.get(path, {})
	for step: int in mine:
		by_step[step] = [mine[step], []]
	for child: String in children.get(path, []):
		var at: int = maxi(AuthorSteps.unit_step(_world, child, lowest), 0)
		if not by_step.has(at):
			by_step[at] = [[], []]
		(by_step[at][1] as Array).append(child)
	var order: Array = by_step.keys()
	order.sort()
	for at: int in order:
		var kids: Array = by_step[at][1]
		kids.sort_custom(func(a: String, b: String) -> bool: return int(first_of[a]) < int(first_of[b]))
		var kinds: Dictionary = {}
		for kid: String in kids:
			var kind: String = Assemblies.definition(Assemblies.segments(kid)[-1])
			if not kinds.has(kind):
				kinds[kind] = []
			(kinds[kind] as Array).append(kid)
		var twins: Array = []
		for kind: String in kinds:
			var copies: Array = kinds[kind]
			_author_steps(copies[0], own, children, context_of, lowest, first_of, steps, built_at)
			for other: int in range(1, copies.size()):
				twins.append([copies[0], copies[other], steps.size() - 1])
		var parts: Array = by_step[at][0]
		parts.sort()
		var attach := PackedInt32Array()
		for kid: String in kids:
			attach.append(context_of[kid])
		for index: int in parts:
			built_at[index] = steps.size()
		steps.append({"context": context_of[path], "parts": PackedInt32Array(parts),
			"also": [], "attach": attach, "twins": twins})


## A plan of Instructions' as the measures read it.
static func _from_plan(steps: Array[Instructions.Step], index_of: Dictionary,
		count: int) -> Dictionary:
	var all := PackedInt32Array()
	for index: int in count:
		all.append(index)
	var contexts: Array = [all]
	# Each copy a callout builds is a context, numbered as its attach step
	# lists them.
	var copy_contexts: Dictionary = {}   ## callout -> [context of each copy]
	var context_of := PackedInt32Array()
	context_of.resize(count)
	context_of.fill(0)
	for step: Instructions.Step in steps:
		if not step.attaches():
			continue
		var made: Array = []
		for copy: PackedInt64Array in step.copies:
			var parts: PackedInt32Array = _indices(copy, index_of)
			for index: int in parts:
				context_of[index] = contexts.size()
			made.append(contexts.size())
			contexts.append(parts)
		copy_contexts[step.callout] = made
	var out: Array = []
	for step: Instructions.Step in steps:
		if step.in_callout():
			var shown: int = (copy_contexts[step.callout] as Array)[0]
			var others: Dictionary = {}
			for index: int in _indices(step.brick_ids, index_of):
				if context_of[index] == shown:
					continue
				if not others.has(context_of[index]):
					others[context_of[index]] = PackedInt32Array()
				(others[context_of[index]] as PackedInt32Array).append(index)
			var also: Array = []
			for context: int in others:
				also.append([context, others[context]])
			out.append({"context": shown, "parts": _indices(step.shown_ids, index_of),
				"also": also, "attach": PackedInt32Array()})
		elif step.attaches():
			out.append({"context": 0, "parts": _indices(step.brick_ids, index_of), "also": [],
				"attach": PackedInt32Array(copy_contexts[step.callout])})
		else:
			out.append({"context": 0, "parts": _indices(step.brick_ids, index_of), "also": [],
				"attach": PackedInt32Array()})
	return {"steps": out, "contexts": contexts}


static func _indices(ids: PackedInt64Array, index_of: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id: int in ids:
		if index_of.has(id):
			out.append(int(index_of[id]))
	return out


static func _chunked(order: Array, per: int) -> Dictionary:
	var out: Array = []
	for start: int in range(0, order.size(), per):
		out.append({"context": 0, "parts": PackedInt32Array(order.slice(start, start + per)),
			"also": [], "attach": PackedInt32Array()})
	var all: Array = order.duplicate()
	all.sort()
	return {"steps": out, "contexts": [PackedInt32Array(all)]}


# -- what holds what, and what can be seen ------------------------------------


func _geometry(bricks: Array, index_of: Dictionary) -> Geometry:
	var g := Geometry.new()
	g.count = bricks.size()
	var covers: Array = []
	var parts := PackedStringArray()
	var bottom := PackedInt32Array()
	var floor_cell: int = 0x7FFFFFFF
	for brick: BrickWorld.Brick in bricks:
		parts.append(brick.part_id)
		var cover: PackedInt32Array = _builder.lattice.boxes_of(brick.id)
		covers.append(cover)
		var low: int = 0x7FFFFFFF
		for at: int in range(1, cover.size(), 6):
			low = mini(low, cover[at])
		bottom.append(low)
		floor_cell = mini(floor_cell, low)
	g.part = parts
	g.bottom = bottom
	g.floor_cell = floor_cell
	var near: Array = []
	var above: Array = []
	var joined: Array = []
	for index: int in g.count:
		near.append({})
		above.append({})
		joined.append({})
	var link := func(one: Variant, other: Variant) -> void:
		if not index_of.has(one) or not index_of.has(other) or one == other:
			return
		(near[index_of[one]] as Dictionary)[index_of[other]] = true
		(near[index_of[other]] as Dictionary)[index_of[one]] = true
	var join := func(one: Variant, other: Variant) -> void:
		link.call(one, other)
		if index_of.has(one) and index_of.has(other) and one != other:
			(joined[index_of[one]] as Dictionary)[index_of[other]] = true
			(joined[index_of[other]] as Dictionary)[index_of[one]] = true

	var stability := Stability.new()
	stability.library = _library
	stability.lattice = _builder.lattice
	var on: Dictionary = stability.contacts(bricks)["above"]
	for under: Variant in on:
		for over: Variant in (on[under] as Dictionary):
			link.call(under, over)
			if index_of.has(under) and index_of.has(over) and under != over:
				(above[index_of[under]] as Dictionary)[index_of[over]] = true

	var entries: Array = []
	var with_paths: Array = []
	for brick: BrickWorld.Brick in bricks:
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		entries.append([brick.id, brick.transform, mesh])
		with_paths.append([brick.id, brick.transform, mesh, brick.part_id,
			Assemblies.path_of(brick)])
	for held: Dictionary in [Joints.both_ways(entries), Joints.balls(entries),
			Joints.rounds(entries)]:
		for one: Variant in held:
			for other: Variant in (held[one] as Dictionary):
				join.call(one, other)
	for one: Array in Joints.through(entries):
		join.call(one[0], one[1])
	var otherwise: Dictionary = Joints.held_otherwise(with_paths, _library)
	for one: Variant in otherwise:
		for other: Variant in (otherwise[one] as Dictionary):
			link.call(one, other)

	for index: int in g.count:
		g.near.append(PackedInt32Array((near[index] as Dictionary).keys()))
		var resting := PackedInt32Array()
		for over: int in (above[index] as Dictionary):
			if not (joined[index] as Dictionary).has(over):
				resting.append(over)
		g.above.append(resting)

	# Held in the finished model: out from the ground.
	var held := PackedByteArray()
	held.resize(g.count)
	var queue: Array[int] = []
	for index: int in g.count:
		if _grounded(g, index, g.floor_cell):
			held[index] = 1
			queue.append(index)
	while not queue.is_empty():
		var here: int = queue.pop_back()
		for next: int in g.near[here]:
			if held[next] == 0:
				held[next] = 1
				queue.append(next)
	g.held = held

	# The finished model's pieces, through what holds what.
	var piece := PackedInt32Array()
	piece.resize(g.count)
	piece.fill(-1)
	var sizes := PackedInt32Array()
	for start: int in g.count:
		if piece[start] >= 0:
			continue
		var label: int = sizes.size()
		sizes.append(0)
		piece[start] = label
		var pending: Array[int] = [start]
		while not pending.is_empty():
			var here: int = pending.pop_back()
			sizes[label] += 1
			for next: int in g.near[here]:
				if piece[next] < 0:
					piece[next] = label
					pending.append(next)
	g.piece = piece
	g.piece_size = sizes

	_pictures(g, covers)
	return g


static func _grounded(g: Geometry, index: int, floor_cell: int) -> bool:
	return g.bottom[index] != 0x7FFFFFFF and g.bottom[index] <= floor_cell + ON_THE_GROUND


## Each part's picture from the front and from the back: the pixels its
## cover's faces land on, and how near the eye each is. A cover's boxes
## are drawn as points on their faces that look towards the eye, a PIXEL
## apart, which a straight-on view never spreads further than a pixel.
func _pictures(g: Geometry, covers: Array) -> void:
	g.pixels = [[], []]
	g.depths = [[], []]
	var views: Array[Vector3] = [BookletStudio.FRONT.normalized(), BookletStudio.BACK.normalized()]
	var frames: Array = []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for view: Vector3 in views:
		var right: Vector3 = Vector3.UP.cross(view).normalized()
		var up: Vector3 = view.cross(right).normalized()
		frames.append([view, right, up])
	# One picture size for both, over every corner of every box.
	for cover: PackedInt32Array in covers:
		for at: int in range(0, cover.size(), 6):
			for corner: int in 8:
				var point := Vector3(
					cover[at + (3 if corner & 1 else 0)] * BrickLattice.CELL,
					cover[at + 1 + (3 if corner & 2 else 0)] * BrickLattice.CELL,
					cover[at + 2 + (3 if corner & 4 else 0)] * BrickLattice.CELL)
				for frame: Array in frames:
					var flat := Vector2(point.dot(frame[1]), point.dot(frame[2]))
					low = low.min(flat)
					high = high.max(flat)
	if low.x == INF:
		low = Vector2.ZERO
		high = Vector2.ZERO
	var width: int = int(ceil((high.x - low.x) / PIXEL)) + 2
	var height: int = int(ceil((high.y - low.y) / PIXEL)) + 2
	g.area = width * height
	for v: int in frames.size():
		var view: Vector3 = frames[v][0]
		var right: Vector3 = frames[v][1]
		var up: Vector3 = frames[v][2]
		for cover: PackedInt32Array in covers:
			var nearest: Dictionary = {}
			for at: int in range(0, cover.size(), 6):
				var from := Vector3(cover[at], cover[at + 1], cover[at + 2]) * BrickLattice.CELL
				var to := Vector3(cover[at + 3], cover[at + 4], cover[at + 5]) * BrickLattice.CELL
				for axis: int in 3:
					if absf(view[axis]) < 0.001:
						continue
					var a: int = (axis + 1) % 3
					var b: int = (axis + 2) % 3
					var span_a: float = to[a] - from[a]
					var span_b: float = to[b] - from[b]
					var count_a: int = maxi(1, int(ceil(span_a / PIXEL)))
					var count_b: int = maxi(1, int(ceil(span_b / PIXEL)))
					var point := Vector3()
					point[axis] = to[axis] if view[axis] > 0.0 else from[axis]
					for i: int in count_a:
						point[a] = from[a] + (i + 0.5) * span_a / count_a
						for j: int in count_b:
							point[b] = from[b] + (j + 0.5) * span_b / count_b
							var x: int = int((point.dot(right) - low.x) / PIXEL)
							var y: int = int((point.dot(up) - low.y) / PIXEL)
							var pixel: int = y * width + x
							var depth: float = point.dot(view)
							if depth > float(nearest.get(pixel, -INF)):
								nearest[pixel] = depth
			var pixels := PackedInt32Array(nearest.keys())
			var depths := PackedFloat32Array()
			for pixel: int in pixels:
				depths.append(nearest[pixel])
			(g.pixels[v] as Array).append(pixels)
			(g.depths[v] as Array).append(depths)




# -- the measures ---------------------------------------------------------------


## Union-find over parts, a root knowing whether what it joins reaches
## the ground (or the table a sub-assembly is built on).
##
## [member apart] is the same with a second rule for the table: a step that
## begins a piece of the finished model on it (a second vehicle, a cart
## beside the house) begins it on the table, as the model's first parts do.
class Pieces extends RefCounted:
	var parent: PackedInt32Array = PackedInt32Array()
	var grounded: PackedByteArray = PackedByteArray()
	var apart: PackedByteArray = PackedByteArray()

	func _init(count: int) -> void:
		parent.resize(count)
		grounded.resize(count)
		apart.resize(count)
		for index: int in count:
			parent[index] = index

	func root(index: int) -> int:
		var at: int = index
		while parent[at] != at:
			parent[at] = parent[parent[at]]
			at = parent[at]
		return at

	func ground(index: int) -> void:
		grounded[root(index)] = 1
		apart[root(index)] = 1

	func ground_apart(index: int) -> void:
		apart[root(index)] = 1

	func reaches(index: int) -> bool:
		return grounded[root(index)] == 1

	func reaches_apart(index: int) -> bool:
		return apart[root(index)] == 1

	func join(one: int, other: int) -> void:
		var a: int = root(one)
		var b: int = root(other)
		if a == b:
			return
		parent[b] = a
		grounded[a] = grounded[a] | grounded[b]
		apart[a] = apart[a] | apart[b]


## What can be seen from one side: the nearest thing at each pixel, and
## whose it is. Kept in an object: a packed array taken out of an array
## and written to is a copy, and the write is lost.
class Sight extends RefCounted:
	var depth: PackedFloat32Array = PackedFloat32Array()
	var owner: PackedInt32Array = PackedInt32Array()
	## Sparse instead, for a sub-assembly's: pixel -> [depth, owner].
	var sparse: Dictionary = {}
	var dense: bool = true

	func _init(area: int, is_dense: bool) -> void:
		dense = is_dense
		if dense:
			depth.resize(area)
			depth.fill(-INF)
			owner.resize(area)
			owner.fill(-1)

	func draw(pixels: PackedInt32Array, depths: PackedFloat32Array, index: int) -> void:
		if dense:
			for n: int in pixels.size():
				if depths[n] > depth[pixels[n]]:
					depth[pixels[n]] = depths[n]
					owner[pixels[n]] = index
			return
		for n: int in pixels.size():
			var was: Array = sparse.get(pixels[n], [-INF, -1])
			if depths[n] > float(was[0]):
				sparse[pixels[n]] = [depths[n], index]

	func whose(pixel: int) -> int:
		if dense:
			return owner[pixel]
		return int((sparse.get(pixel, [0.0, -1]) as Array)[1])

	func depth_at(pixel: int) -> float:
		if dense:
			return depth[pixel]
		return float((sparse.get(pixel, [-INF, -1]) as Array)[0])


## Somewhere things are built, as the build goes: the step each part was
## put there in, what holds what, and what can be seen from each side.
##
## The model is built on the table, which holds what stands on it, and
## its first parts: a car's chassis goes down first and rests on the table,
## though the model's lowest point is under its tyres. A sub-assembly is
## built in the hand, any way up: an author's sub-model has a frame of its
## own, and a roof drawn in it upside down and turned over to go on stood on
## nothing in the world's terms. So its first parts are the piece. Every
## part after has to stand on the ground, on the model, or join the piece.
class Place extends RefCounted:
	var at: PackedInt32Array = PackedInt32Array()
	var pieces: Pieces
	var sights: Array[Sight] = []
	var floor_cell: int = 0
	var in_hand: bool = false
	var begun: bool = false
	## The pieces of the finished model begun here: piece -> true.
	var pieces_begun: Dictionary = {}

	func _init(count: int, area: int, on_the_ground: bool, lowest: int) -> void:
		at.resize(count)
		at.fill(-1)
		pieces = Pieces.new(count)
		sights = [Sight.new(area, on_the_ground), Sight.new(area, on_the_ground)]
		floor_cell = lowest
		in_hand = not on_the_ground


func _place_of(places: Dictionary, context: int, g: Geometry) -> Place:
	if not places.has(context):
		places[context] = Place.new(g.count, g.area, context == 0, g.floor_cell)
	return places[context]


## Put [param parts] in [param place] at step [param k]: on the ground, or
## the start of the piece, or held to what is there.
static func _put(place: Place, parts: PackedInt32Array, k: int, g: Geometry) -> void:
	var first: bool = not place.begun and not parts.is_empty()
	place.begun = place.begun or not parts.is_empty()
	# Only a piece the finished model holds: one the graph does not hold is
	# not counted either way, as before.
	var fresh: Dictionary = {}
	if not place.in_hand:
		for index: int in parts:
			if g.held[index] == 1 and not place.pieces_begun.has(g.piece[index]):
				fresh[g.piece[index]] = true
	for index: int in parts:
		place.at[index] = k
		if first or not place.in_hand and g.bottom[index] != 0x7FFFFFFF \
				and g.bottom[index] <= place.floor_cell + ON_THE_GROUND:
			place.pieces.ground(index)
		elif fresh.has(g.piece[index]):
			place.pieces.ground_apart(index)
	place.pieces_begun.merge(fresh)
	for index: int in parts:
		for other: int in g.near[index]:
			if place.at[other] >= 0:
				place.pieces.join(index, other)


## Score one build. Returns each part's step, the steps' sizes and kinds,
## the copies built on the side, and how many of its new things were
## hidden, blocked and floating.
func _measure(build: Dictionary, g: Geometry) -> Dictionary:
	var steps: Array = build["steps"]
	var contexts: Array = build["contexts"]
	var rank := PackedInt32Array()
	rank.resize(g.count)
	rank.fill(-1)
	var places: Dictionary = {}
	var sizes := PackedInt32Array()
	var kinds := PackedInt32Array()
	var types: String = ""
	var copies_out: Array = []
	var items: int = 0
	var hidden_items: int = 0
	var hidden_steps: int = 0
	var blocked_items: int = 0
	var blocked_steps: int = 0
	## Which: [step, the thing's first part, its size], to say what they are.
	var said: Dictionary = {"hidden": [], "blocked": [], "floating": []}
	## Each thing found floating at its step: [place, the thing, step]; and
	## by the second rule for the table (Pieces.apart).
	var floating: Array = []
	var floating_apart: Array = []
	## How each piece of the finished model the graph holds is begun on the
	## model: built in the hand and put on whole, in the model's first step,
	## on the ground, or in the air. All pieces, and those of ten parts or
	## more.
	var starts: Dictionary = {"first": 0, "hand": 0, "ground": 0, "air": 0}
	var starts_big: Dictionary = {"first": 0, "hand": 0, "ground": 0, "air": 0}
	## Every thing, with where it is built, to count those the graph holds.
	var all_things: Array = []
	## Floating things not yet held, by their place in floating_apart, and
	## the steps each waited (-1, never in its build).
	var pending_float: Array[int] = []
	var float_delay: Dictionary = {}

	for k: int in steps.size():
		var step: Dictionary = steps[k]
		var context: int = step["context"]
		var place: Place = _place_of(places, context, g)
		var attach: PackedInt32Array = step["attach"]
		types += ("a" if not attach.is_empty() else ("m" if context == 0 else "c"))
		var things: Array = []
		var placed := PackedInt32Array()
		for child: int in attach:
			var parts: PackedInt32Array = contexts[child]
			# A copy never built step by step is there whole by now.
			var made: Place = _place_of(places, child, g)
			var missing := PackedInt32Array()
			for index: int in parts:
				if made.at[index] < 0:
					missing.append(index)
			if not missing.is_empty():
				_put(made, missing, k, g)
			things.append(parts)
			placed.append_array(parts)
			copies_out.append(parts)
		for index: int in step["parts"]:
			things.append(PackedInt32Array([index]))
			placed.append(index)
		for index: int in placed:
			if rank[index] < 0:
				rank[index] = k
		for also: Array in step["also"]:
			var parts: PackedInt32Array = also[1]
			_put(_place_of(places, int(also[0]), g), parts, k, g)
			for index: int in parts:
				if rank[index] < 0:
					rank[index] = k
		sizes.append(things.size())
		var kind_of: Dictionary = {}
		for thing: PackedInt32Array in things:
			kind_of[("sub-assembly %d" % thing.size()) if thing.size() > 1 else g.part[thing[0]]] = true
		kinds.append(kind_of.size())
		if things.is_empty():
			continue

		# Blocked: put in under something placed in an earlier step. On the
		# model, where up is up; in the hand it is whichever way it is held.
		var blocked_here: bool = false
		for thing: PackedInt32Array in things if not place.in_hand else []:
			var own: Dictionary = {}
			for index: int in thing:
				own[index] = true
			var blocked: bool = false
			for index: int in thing:
				for over: int in g.above[index]:
					if not own.has(over) and place.at[over] >= 0 and place.at[over] < k:
						blocked = true
						break
				if blocked:
					break
			if blocked:
				blocked_items += 1
				(said["blocked"] as Array).append([k, thing[0], thing.size()])
				blocked_here = true
		if blocked_here:
			blocked_steps += 1

		# How a piece of the finished model is begun on the model.
		if not place.in_hand:
			var now: Dictionary = {}
			for thing: PackedInt32Array in things:
				var which: int = g.piece[thing[0]]
				if place.pieces_begun.has(which) or now.has(which) or g.held[thing[0]] == 0:
					continue
				now[which] = true
				var how: String = "air"
				if thing.size() > 1:
					how = "hand"
				elif not place.begun:
					how = "first"
				elif Array(thing).any(func(index: int) -> bool:
						return g.bottom[index] != 0x7FFFFFFF \
							and g.bottom[index] <= place.floor_cell + ON_THE_GROUND):
					how = "ground"
				starts[how] = int(starts[how]) + 1
				if g.piece_size[which] >= 10:
					starts_big[how] = int(starts_big[how]) + 1

		# Whether each new thing could be seen against what earlier steps
		# built alone, before this step's own parts are drawn: hidden by
		# those, or only by parts of its own step. Said with each hidden one.
		var by_earlier: Array = []
		for thing: PackedInt32Array in things:
			var seen_before: float = 0.0
			for v: int in 2:
				var mine: Dictionary = {}
				for index: int in thing:
					var pixels: PackedInt32Array = (g.pixels[v] as Array)[index]
					var depths: PackedFloat32Array = (g.depths[v] as Array)[index]
					for n: int in pixels.size():
						mine[pixels[n]] = maxf(float(mine.get(pixels[n], -INF)), depths[n])
				if mine.is_empty():
					seen_before = 1.0
					break
				var clear: int = 0
				for pixel: int in mine:
					if float(mine[pixel]) >= place.sights[v].depth_at(pixel):
						clear += 1
				seen_before = maxf(seen_before, float(clear) / float(mine.size()))
			by_earlier.append(seen_before < SEEN)

		# Placed, and joined to what is there.
		_put(place, placed, k, g)
		for thing: PackedInt32Array in things:
			all_things.append([place, thing])
			if not Array(thing).any(func(index: int) -> bool: return place.pieces.reaches(index)):
				floating.append([place, thing, k])
			if not Array(thing).any(func(index: int) -> bool:
					return place.pieces.reaches_apart(index)):
				floating_apart.append([place, thing, k])
				pending_float.append(floating_apart.size() - 1)
		# How many steps each floating thing waits to be held.
		for n: int in range(pending_float.size() - 1, -1, -1):
			var entry: Array = floating_apart[pending_float[n]]
			if (entry[0] as Place).pieces.reaches_apart((entry[1] as PackedInt32Array)[0]):
				float_delay[pending_float[n]] = k - int(entry[2])
				pending_float.remove_at(n)

		# Seen: drawn into the picture so far, then how much of each new
		# thing is its own.
		for v: int in 2:
			var pixels_of: Array = g.pixels[v]
			var depths_of: Array = g.depths[v]
			for index: int in placed:
				place.sights[v].draw(pixels_of[index], depths_of[index], index)
		var hidden_here: bool = false
		for at_thing: int in things.size():
			var thing: PackedInt32Array = things[at_thing]
			var own: Dictionary = {}
			for index: int in thing:
				own[index] = true
			var best: float = 0.0
			for v: int in 2:
				var alone: Dictionary = {}
				for index: int in thing:
					for pixel: int in (g.pixels[v] as Array)[index]:
						alone[pixel] = true
				if alone.is_empty():
					best = 1.0
					break
				var shown: int = 0
				for pixel: int in alone:
					if own.has(place.sights[v].whose(pixel)):
						shown += 1
				best = maxf(best, float(shown) / float(alone.size()))
			items += 1
			if best < SEEN:
				hidden_items += 1
				(said["hidden"] as Array).append([k, thing[0], thing.size(),
					1 if by_earlier[at_thing] else 0])
				hidden_here = true
		if hidden_here:
			hidden_steps += 1

	# A thing counts as floating at its step only if, once its build is
	# done, what it is in reaches the ground: the rest the graph cannot hold.
	var held_at_end := func(entry: Array) -> bool:
		var where: Place = entry[0]
		return Array(entry[1]).any(func(index: int) -> bool: return where.pieces.reaches(index))
	var floating_items: int = 0
	var floating_steps: Dictionary = {}
	for entry: Array in floating:
		if held_at_end.call(entry):
			floating_items += 1
			(said["floating"] as Array).append([int(entry[2]), (entry[1] as PackedInt32Array)[0],
				(entry[1] as PackedInt32Array).size()])
			floating_steps[int(entry[2])] = true
	var measured: int = all_things.filter(held_at_end).size()
	var held_apart := func(entry: Array) -> bool:
		var where: Place = entry[0]
		return Array(entry[1]).any(func(index: int) -> bool: return where.pieces.reaches_apart(index))
	var apart_items: int = 0
	var apart_steps: Dictionary = {}
	said["floating_pieces"] = []
	for at_entry: int in floating_apart.size():
		var entry: Array = floating_apart[at_entry]
		if held_apart.call(entry):
			apart_items += 1
			(said["floating_pieces"] as Array).append([int(entry[2]),
				(entry[1] as PackedInt32Array)[0], (entry[1] as PackedInt32Array).size(),
				int(float_delay.get(at_entry, -1))])
			apart_steps[int(entry[2])] = true
	return {"rank": rank, "sizes": sizes, "kinds": kinds, "types": types,
		"copies": copies_out, "items": items, "hidden": hidden_items,
		"hidden_steps": hidden_steps, "blocked": blocked_items,
		"blocked_steps": blocked_steps, "floating": floating_items,
		"floating_steps": floating_steps.size(), "measured": measured,
		"floating_pieces": apart_items, "floating_pieces_steps": apart_steps.size(),
		"measured_pieces": all_things.filter(held_apart).size(),
		"starts": starts, "starts_big": starts_big, "which": said}


# -- the measures on models whose answers are known ---------------------------


func _selftest() -> void:
	print("steps score: self-test")
	# Three 2 x 4 bricks in a stack. Built from the top, the top one is the
	# first part on the table, and the middle and bottom ones each go in
	# under a brick already there. Bottom, top, middle: the top one hangs in
	# the air at step 2, and the middle one goes in under it. Built from the
	# bottom, nothing is wrong.
	var g: Geometry = _toy_stack()
	var down: Dictionary = _measure(_steps_of([[2], [1], [0]], 3), g)
	var gap: Dictionary = _measure(_steps_of([[0], [2], [1]], 3), g)
	var up: Dictionary = _measure(_steps_of([[0], [1], [2]], 3), g)
	_assert("a stack is held to the ground (%d of 3)" % Array(g.held).count(1),
		Array(g.held).count(1) == 3)
	_assert("built from the top, two go in under a brick already there (%d)"
		% int(down["blocked"]), int(down["blocked"]) == 2)
	_assert("...and none floats: the first stands on the table (%d)" % int(down["floating"]),
		int(down["floating"]) == 0)
	_assert("bottom, top, middle: the top floats and the middle goes in under it (%d, %d)"
		% [int(gap["floating"]), int(gap["blocked"])],
		int(gap["floating"]) == 1 and int(gap["blocked"]) == 1)
	_assert("built from the bottom, none floats or is blocked (%d, %d)" % [
		int(up["floating"]), int(up["blocked"])],
		int(up["floating"]) == 0 and int(up["blocked"]) == 0)
	_assert("...and every step is seen (%d hidden)" % int(up["hidden"]), int(up["hidden"]) == 0)
	_assert("each part's step is where it was placed (%s)" % str(Array(down["rank"])),
		Array(down["rank"]) == [2, 1, 0])

	# The stack's top two bricks built on the side and put on the bottom
	# one: in the hand the middle brick is the piece, the top one joins it,
	# and the two go on whole.
	var side: Dictionary = {"contexts": [PackedInt32Array([0, 1, 2]), PackedInt32Array([1, 2])],
		"steps": [
			{"context": 0, "parts": PackedInt32Array([0]), "also": [], "attach": PackedInt32Array()},
			{"context": 1, "parts": PackedInt32Array([1]), "also": [], "attach": PackedInt32Array()},
			{"context": 1, "parts": PackedInt32Array([2]), "also": [], "attach": PackedInt32Array()},
			{"context": 0, "parts": PackedInt32Array(), "also": [], "attach": PackedInt32Array([1])},
		]}
	var built: Dictionary = _measure(side, g)
	_assert("a sub-assembly's parts stand on its table (%d floating)" % int(built["floating"]),
		int(built["floating"]) == 0)
	_assert("...and it is a thing built on the side (%d)" % (built["copies"] as Array).size(),
		(built["copies"] as Array).size() == 1)
	_assert("...and four steps add four things (%s)" % str(Array(built["sizes"])),
		Array(built["sizes"]) == [1, 1, 1, 1])
	# In the hand, the whole stack: the bottom brick, then the top one,
	# which touches nothing in the hand until the middle one joins them.
	var apart: Dictionary = {"contexts": [PackedInt32Array([0, 1, 2]),
		PackedInt32Array([0, 1, 2])], "steps": [
			{"context": 1, "parts": PackedInt32Array([0]), "also": [], "attach": PackedInt32Array()},
			{"context": 1, "parts": PackedInt32Array([2]), "also": [], "attach": PackedInt32Array()},
			{"context": 1, "parts": PackedInt32Array([1]), "also": [], "attach": PackedInt32Array()},
			{"context": 0, "parts": PackedInt32Array(), "also": [], "attach": PackedInt32Array([1])},
		]}
	var wrong: Dictionary = _measure(apart, g)
	_assert("...and in the hand a part that joins nothing floats (%d)" % int(wrong["floating"]),
		int(wrong["floating"]) == 1)
	_assert("...though nothing is put in under anything there (%d)" % int(wrong["blocked"]),
		int(wrong["blocked"]) == 0)

	# Two pieces: a brick alone, then a tower of four beside it begun from
	# its top. By the model's first parts alone, the top floats, and so does
	# the second, which joins nothing there yet. Begun on the table as the
	# piece it starts, the top stands, and only the second floats.
	g = _toy_two()
	var two: Dictionary = _measure(_steps_of([[0], [4], [2], [1], [3]], 5), g)
	_assert("a second piece is a piece of its own (%d pieces)" % g.piece_size.size(),
		g.piece_size.size() == 2)
	_assert("begun from its top, two float by the model's first parts (%d)"
		% int(two["floating"]), int(two["floating"]) == 2)
	_assert("...and one when a piece is begun on the table (%d)" % int(two["floating_pieces"]),
		int(two["floating_pieces"]) == 1)
	_assert("...and the second piece is begun in the air (%s)" % str(two["starts"]),
		int(two["starts"]["first"]) == 1 and int(two["starts"]["air"]) == 1)
	var stood: Dictionary = _measure(_steps_of([[0], [1], [2], [3], [4]], 5), g)
	_assert("built from the bottom, neither rule finds one floating (%d, %d)" % [
		int(stood["floating"]), int(stood["floating_pieces"])],
		int(stood["floating"]) == 0 and int(stood["floating_pieces"]) == 0)

	# A 1 x 1 plate in a well: a ring of 1 x 1 bricks four high round a
	# square two studs across. Put in after the ring, it cannot be seen
	# from the front or the back; put in first, it can.
	var well: Array = _toy_well()
	g = well[0]
	var plate: int = well[1]
	var ring: Array = []
	for index: int in g.count:
		if index != plate:
			ring.append(index)
	var late: Dictionary = _measure(_steps_of([ring, [plate]], g.count), g)
	var early: Dictionary = _measure(_steps_of([[plate], ring], g.count), g)
	_assert("a plate put in a deep well is hidden (%d of %d hidden)" % [
		int(late["hidden"]), int(late["items"])], int(late["hidden"]) == 1)
	_assert("...and put in first it is not (%d)" % int(early["hidden"]),
		int(early["hidden"]) == 0)
	_assert("...nor is it blocked or floating (%d, %d)" % [int(late["blocked"]),
		int(late["floating"])], int(late["blocked"]) == 0 and int(late["floating"]) == 0)


func _toy_stack() -> Geometry:
	_world.clear()
	_builder.lattice.clear()
	var bricks: Array = []
	var index_of: Dictionary = {}
	for level: int in 3:
		var at := Transform3D(Basis.IDENTITY, Vector3(0, level * 24.0, 0))
		var id: int = _world.add_brick("3001", 4, at)
		_builder.register(id, "3001", at)
		index_of[id] = bricks.size()
		bricks.append(_world.get_brick(id))
	return _geometry(bricks, index_of)


## A 2 x 4 brick alone, then a tower of four ten studs from it.
func _toy_two() -> Geometry:
	_world.clear()
	_builder.lattice.clear()
	var bricks: Array = []
	var index_of: Dictionary = {}
	var places: Array = [Vector3.ZERO]
	for level: int in 4:
		places.append(Vector3(200, level * 24.0, 0))
	for where: Vector3 in places:
		var at := Transform3D(Basis.IDENTITY, where)
		var id: int = _world.add_brick("3001", 4, at)
		_builder.register(id, "3001", at)
		index_of[id] = bricks.size()
		bricks.append(_world.get_brick(id))
	return _geometry(bricks, index_of)


func _toy_well() -> Array:
	_world.clear()
	_builder.lattice.clear()
	var bricks: Array = []
	var index_of: Dictionary = {}
	var brick_low: float = _library.mesh_for("3005").bounds.position.y
	for level: int in 4:
		for x: int in [-30, -10, 10, 30]:
			for z: int in [-30, -10, 10, 30]:
				if absi(x) == 10 and absi(z) == 10:
					continue
				var at := Transform3D(Basis.IDENTITY, Vector3(x, level * 24.0, z))
				var id: int = _world.add_brick("3005", 4, at)
				_builder.register(id, "3005", at)
				index_of[id] = bricks.size()
				bricks.append(_world.get_brick(id))
	var plate_low: float = _library.mesh_for("3024").bounds.position.y
	var at := Transform3D(Basis.IDENTITY, Vector3(-10, brick_low - plate_low, -10))
	var id: int = _world.add_brick("3024", 14, at)
	_builder.register(id, "3024", at)
	index_of[id] = bricks.size()
	bricks.append(_world.get_brick(id))
	return [_geometry(bricks, index_of), bricks.size() - 1]


static func _steps_of(groups: Array, count: int) -> Dictionary:
	var out: Array = []
	for group: Array in groups:
		out.append({"context": 0, "parts": PackedInt32Array(group), "also": [],
			"attach": PackedInt32Array()})
	return {"steps": out, "contexts": [PackedInt32Array(range(count))]}


func _assert(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
