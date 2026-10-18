extends SceneTree
## Brickify's unit 7: buy it, or build it from what you own
## (docs/BRICKIFY.md). A model brickified gets steps of its own, the file's
## "0 STEP" lines: a course a step bottom up, SNOT panels built on the side,
## and every step's partial build standing (Balance), so the booklet follows
## them. The panel offers the booklet, the BrickLink wanted list and the
## Rebrickable list once it is down. And laid from a collection (set
## 10698's 790 parts, never the person's own): parts and colours on hand
## first, stand-ins by colour and then by size, the shortfall said, with
## the share drawn from it and what that costs in colour.
##
##   XDG_DATA_HOME=<scratch> godot --headless --path . --script src/dev/brickify_buy_probe.gd \
##       [-- --models=FILE@STUDS@UP,... | --models-file=LIST --out=DIR --steps-only]
##
## With --out, each build is saved there as <name>_<studs>.ldr with its steps,
## and the numbers as buy.json. --steps-only lays each model and weighs its
## steps, and no more: the bench's fourteen at two sizes.

var _failures: int = 0
var _library: PartLibrary
var _checker: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _exports: Exports
var _out: String = ""
var _numbers: Dictionary = {}
var _steps_only: bool = false
## Where the lists are written: never the person's Downloads.
var _lists: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var models: Array = [["res://tests/fixtures/brickify/bunny.obj", 24, "+Y"],
		["res://tests/fixtures/brickify/fox.obj", 24, "+Y"]]
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--steps-only":
			_steps_only = true
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--models=") or arg.begins_with("--models-file="):
			var listed: String = arg.trim_prefix("--models=") if arg.begins_with("--models=") \
				else FileAccess.get_file_as_string(arg.trim_prefix("--models-file=")).strip_edges()
			models = []
			for one: String in listed.split(","):
				var bits: PackedStringArray = one.split("@")
				models.append([bits[0], int(bits[1]) if bits.size() > 1 else 24,
					bits[2] if bits.size() > 2 else "+Y"])
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = _world
	_checker.builder = _builder
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	_lists = OS.get_user_data_dir().path_join("sessions/probe/brickify_buy")
	DirAccess.make_dir_recursive_absolute(_lists)
	Download.folder = _lists
	_exports = Exports.new()
	_exports.world = _world
	_exports.library = _library
	_exports.store = _store
	_exports.folder = _lists
	root.add_child(_exports)
	await process_frame
	for id: String in Brickify.parts_needed(_library):
		_library.mesh_for(id)

	var first: bool = true
	for entry: Array in models:
		await _steps_for(str(entry[0]), int(entry[1]), str(entry[2]), first)
		first = false
	if not _steps_only:
		await _from_collection(str(models[0][0]), int(models[0][1]), str(models[0][2]))

	_save_numbers()
	print("")
	print("brickify_buy_probe: %s" % ("ok" if _failures == 0 else "%d FAIL" % _failures))
	quit(1 if _failures > 0 else 0)


## A model laid, its steps worked out, put down as the panel puts it down,
## and the booklet's plan read back. [param lists]: its BrickLink and
## Rebrickable lists written too, of it alone.
func _steps_for(path: String, studs: int, up: String, lists: bool = false) -> void:
	var name: String = path.get_file().get_basename().to_snake_case()
	print("")
	print("  %s at %d studs" % [name, studs])
	var mesh: MeshFile = _read(path)
	if mesh == null or not mesh.error.is_empty():
		_check("%s reads: %s" % [path, mesh.error if mesh != null else "no file"], false)
		return
	var options := Brickify.Options.new()
	options.studs = studs
	options.up = up
	var began: int = Time.get_ticks_msec()
	var laid: Dictionary = Brickify.build(mesh, options, _checker)
	var build_ms: int = Time.get_ticks_msec() - began
	if not laid.has("model"):
		_check("%s is laid: %s" % [name, laid.get("error", "")], false)
		return
	var model: Assistant.Model = laid["model"]
	var plan: BrickifySteps.Plan = BrickifySteps.of(model, _checker)
	var record: Dictionary = {"parts": model.placements.size(), "build_ms": build_ms,
		"steps": plan.steps, "courses": plan.courses, "panels": plan.panel_name.size(),
		"weighed": plan.weighed, "stood": plan.stood, "merged": plan.merged,
		"why_merged": Array(plan.why_merged), "later": plan.later, "unheld": plan.unheld,
		"least_margin": plan.least_margin, "steps_ms": plan.ms,
		"said": Brickify.said(laid)}
	_numbers["%s_%d" % [name, studs]] = record
	print("    %d parts in %.1f s; %s, in %.1f s" % [model.placements.size(), build_ms / 1000.0,
		plan.said(), plan.ms / 1000.0])
	_check("%s: %d steps from %d courses, %d panels on the side" % [name, plan.steps,
		plan.courses, plan.panel_name.size()], plan.steps >= 4 and plan.steps <= plan.courses)
	# The last step's build is the whole of it, which stands or not as it was
	# laid: the order cannot change that, and Brickify's own line says so.
	var whole: Balance.Report = (laid["report"] as Dictionary).get("balance")
	var as_laid: int = whole.over if whole != null else 0
	_check("every step's partial build stands, weighed: %d of the %d before the last (%d courses weighed, %d put in with the next: %s), least margin %s studs; the whole build %s"
		% [plan.stood, plan.steps - 1, plan.weighed, plan.merged, ", ".join(plan.why_merged),
			Balance.studs(plan.least_margin), "stands" if plan.whole_stands else
			"with %d stud joints past their load, as laid (Brickify's check: %d)" % [plan.whole_over,
			as_laid]], plan.weighed >= plan.steps and plan.stood == plan.steps - 1)
	record["whole_stands"] = plan.whole_stands
	record["whole_over"] = plan.whole_over
	if _steps_only:
		_save_numbers()
		return
	_check("every part has a step and none is held by nothing: %d unheld, %d put after their course"
		% [plan.unheld, plan.later], plan.unheld == 0)
	laid["steps"] = plan

	# Down as the panel puts it down, beside a brick of somebody else's.
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	var own: int = _builder.swap_bricks(PackedInt64Array(), [{"part": "3001", "color": 4,
		"at": Transform3D(Basis.IDENTITY, Vector3(-400, 0, -400))}])[0]["brick"]
	var dialog := BrickifyDialog.new()
	dialog.library = _library
	dialog.world = _world
	dialog.builder = _builder
	root.add_child(dialog)
	dialog._checker = _checker
	var ids: PackedInt64Array = await dialog._put_down(laid, name)
	var top: String = dialog.last_path
	var stepped: int = 0
	var paths: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick.step >= 0:
			stepped += 1
		paths[Assemblies.path_of(brick)] = true
	var panels: int = 0
	for unit: String in _world.unit_steps:
		if Assemblies.parent_of(unit) == top:
			panels += 1
	_check("down as %s, every part with the file's own step (%d of %d), each panel a sub-assembly put on in a step of it (%d)"
		% [top, stepped, ids.size(), panels], stepped == ids.size() and ids.size() == model.placements.size()
		and panels == plan.panel_name.size() and paths.size() == plan.panel_name.size() + 1)

	# The booklet follows them: the author's steps, read back.
	var booklet: Array[Instructions.Step] = Instructions.plan(_world, _library, {}, {}, true)
	var numbers: Dictionary = {}
	var callouts: Dictionary = {}
	var main_steps: Array = []
	for step: Instructions.Step in booklet:
		if step.in_callout():
			callouts[step.callout] = true
			continue
		if step.authored_in == top:
			main_steps.append(step)
		numbers[step.number] = true
	var ours: Dictionary = {}
	for step: Instructions.Step in main_steps:
		if step.authored_step >= 0:
			ours[step.number] = true
	var from_ours: int = ours.size()
	_check("the booklet follows them: %d of its %d steps are the build's own (%d callouts for %d panels), and the brick of somebody else's after them"
		% [from_ours, numbers.size(), callouts.size(), plan.panel_name.size()],
		from_ours == plan.steps and numbers.size() == plan.steps + 1
		and callouts.size() <= plan.panel_name.size() and _world.get_brick(own).step < 0)
	# Each step the next course: its highest part's foot no lower than the
	# last step's (the parts hung under a course go in with it).
	var rises: int = 0
	var falls: Array = []
	var last_middle: float = -INF
	for step: Instructions.Step in main_steps:
		var heights: Array = []
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
			if Assemblies.path_of(brick) == top and part != null:
				heights.append((brick.transform * part.bounds).position.y)
		if heights.is_empty():
			continue
		heights.sort()
		var middle: float = float(heights[heights.size() - 1])
		if middle + 1.0 >= last_middle:
			rises += 1
		else:
			falls.append(step.number)
		last_middle = maxf(last_middle, middle)
	_check("each step reads as the next course up: %d rise, steps %s do not" % [rises, falls],
		falls.is_empty())

	# Every partial build in the booklet's order, by the design check itself:
	# one piece, nothing floating, and standing (Balance), the panels on once
	# they are put on.
	var index_of: Dictionary = {}
	for n: int in ids.size():
		index_of[ids[n]] = n
	var have: Dictionary = {}
	var failed: Array = []
	var checked: int = 0
	var grounds: int = 0
	var every: int = maxi(1, plan.steps / 12)
	for at: int in main_steps.size():
		var step: Instructions.Step = main_steps[at]
		for brick_id: int in step.brick_ids:
			have[brick_id] = true
		for copy: PackedInt64Array in step.copies:
			for brick_id: int in copy:
				have[brick_id] = true
		# At the end of a step: its panels and its own parts both on.
		if at + 1 < main_steps.size() and (main_steps[at + 1] as Instructions.Step).number \
				== step.number:
			continue
		if step.number % every != 0 and at != main_steps.size() - 1:
			continue
		var partial := Assistant.Model.new()
		for brick_id: int in have:
			if index_of.has(brick_id):
				partial.placements.append(model.placements[int(index_of[brick_id])])
		var report: Dictionary = _checker._check(partial, true, false, true, false)
		var balance: Balance.Report = report.get("balance")
		checked += 1
		var floats: int = (report.get("floating", []) as Array).size()
		# In pieces only as feet are before the body joins them: each piece on
		# the ground (weighed as one when it is one piece, by the steps'
		# own weighing when not).
		var pieces: int = int(report.get("pieces", 0))
		var grounded: bool = _each_on_the_ground(partial, report.get("each_piece", []))
		var stands: bool = balance != null and not balance.empty and balance.margin >= 0.0 \
			and balance.over == 0
		if pieces > 1 and grounded:
			grounds += 1
		# The last is the whole build: its joints are as it was laid.
		var last: bool = at == main_steps.size() - 1
		if last and balance != null and not plan.whole_stands and balance.margin >= 0.0:
			stands = true
		if not bool(report.get("ok", false)) or floats > 0 or (pieces == 1 and not stands) \
				or (pieces > 1 and not grounded):
			failed.append("%d (%d pieces, %d floating, %s: %s)" % [step.number,
				int(report.get("pieces", 0)), floats, balance.words() if balance != null
				else "not weighed", str(report.get("summary", "")), ])
			if failed.size() == 1:
				print(str(report.get("feedback", "")).left(1500))
				_beside(report.get("floating", []), partial, ids, index_of, plan, model)
	record["checked_by_check"] = checked
	record["in_pieces_on_the_ground"] = grounds
	record["failed_by_check"] = failed
	_check("and by the design check, %s step's build in the booklet's order passes, nothing floating, standing (or in pieces each on the ground, %d): %d checked, %s"
		% ["every" if every == 1 else "every %d" % every, grounds, checked,
			failed if not failed.is_empty() else "all"], failed.is_empty())

	if lists:
		# Its lists, through the app's own exporters, of it alone.
		var skip: Dictionary = {own: true}
		var said: String = _exports.shop_list("bricklink", skip)
		var xml: String = FileAccess.get_file_as_string(_lists.path_join("model_bricklink.xml"))
		var wanted: int = 0
		for found: RegExMatch in RegEx.create_from_string("<MINQTY>(\\d+)</MINQTY>").search_all(xml):
			wanted += found.get_string(1).to_int()
		_check("its BrickLink wanted list, of it alone: %d pieces wanted for its %d (%s)"
			% [wanted, ids.size(), said], wanted == ids.size())
		said = _exports.shop_list("rebrickable", skip)
		var rows: PackedStringArray = FileAccess.get_file_as_string(
			_lists.path_join("model_rebrickable.csv")).strip_edges().split("\n")
		var listed: int = 0
		for row: String in rows.slice(1):
			listed += row.get_slice(",", 2).to_int()
		_check("its Rebrickable list: %d rows, %d pieces (%s)" % [rows.size() - 1, listed, said],
			listed == ids.size())

	if not _out.is_empty():
		_builder.swap_bricks(PackedInt64Array([own]), [])
		var file: String = _out.path_join("%s_%d.ldr" % [name, studs])
		print("    saved %s: %s" % [file, _store.export_to(file, name)])
	# The checker is the probe's: the panel frees its own as it goes.
	dialog._checker = null
	dialog.queue_free()
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()


## Laid from a collection: set 10698's parts, a collection of the probe's
## own (the person's is never read). The share of the build drawn from it,
## and what that costs in colour against the build laid without it.
func _from_collection(path: String, studs: int, up: String) -> void:
	print("")
	print("  laid from a collection of set 10698's parts")
	var sets := SetInventories.new()
	root.add_child(sets)
	var records: Dictionary = await sets.lookup(PackedStringArray(["10698-1"]))
	var collection := Collection.new()
	collection.sets = [{"set": "10698-1", "qty": 1, "spares": false}]
	var on_hand: Dictionary = collection.pool(records, _library)
	var pieces: int = 0
	for key: String in on_hand:
		pieces += int(on_hand[key])
	_check("the collection: set 10698, %d pieces in %d lots" % [pieces, on_hand.size()],
		pieces >= 780 and pieces <= 800)
	var mesh: MeshFile = _read(path)
	var options := Brickify.Options.new()
	options.studs = studs
	options.up = up
	var plain: Dictionary = Brickify.build(mesh, options, _checker)
	var laid: Dictionary = Brickify.build(mesh, options, _checker)
	if not plain.has("model") or not laid.has("model"):
		_check("laid twice", false)
		return
	var before: Assistant.Model = plain["model"]
	var model: Assistant.Model = laid["model"]
	_check("laid the same twice, to compare: %d and %d parts" % [before.placements.size(),
		model.placements.size()], before.placements.size() == model.placements.size())
	BrickifyDialog.finish(laid, on_hand, _checker)
	var stock: Dictionary = laid.get("stock", {})
	var plan: BrickifySteps.Plan = laid.get("steps")
	print("    %s; %d splits taken back" % [BrickifyStock.said(stock), int(stock.get("splits_undone", 0))])
	_numbers["collection_10698"] = stock.duplicate()
	(_numbers["collection_10698"] as Dictionary)["short"] = (stock.get("short", []) as Array).slice(0, 12)
	var parts: int = int(stock.get("parts", 0))
	var drawn: int = int(stock.get("drawn", 0))
	_check("some of it drawn from the collection: %d of %d parts (%.1f%%): %d as they are, %d in another colour, %d as two smaller"
		% [drawn, parts, 100.0 * drawn / maxf(parts, 1), int(stock["as_it_is"]),
			int(stock["by_colour"]), int(stock["by_size"])], drawn > 0
		and drawn == int(stock["as_it_is"]) + int(stock["by_colour"]) + int(stock["by_size"]))
	# Never more of a part and colour than is on hand.
	var used: Dictionary = {}
	var over: Array = []
	var short: Dictionary = {}
	for row: Array in stock.get("short", []):
		short[Collection.key_of(str(row[0]), int(row[1]), _library)] = int(row[2])
	for placement: Assistant.Placement in model.placements:
		var key: String = Collection.key_of(placement.part, placement.color, _library)
		used[key] = int(used.get(key, 0)) + 1
	for key: String in used:
		var from_it: int = int(used[key]) - int(short.get(key, 0))
		if from_it > int(on_hand.get(key, 0)):
			var family_has: int = 0
			for other: String in on_hand:
				if Collection.family_of(Collection.part_of(other)) == Collection.family_of(
						Collection.part_of(key)) and Collection.colour_of(other) == Collection.colour_of(key):
					family_has += int(on_hand[other])
			if from_it > family_has:
				over.append("%s: %d of %d" % [key, from_it, family_has])
	_check("never more of a part and colour than is on hand: %s" % (over if not over.is_empty()
		else "none over"), over.is_empty())
	_check("the shortfall said: %d parts in %d lots, the biggest %s" % [int(stock["short_pieces"]),
		int(stock["short_lots"]), (stock["short"] as Array).slice(0, 3)],
		int(stock["short_pieces"]) == parts - drawn)
	# What it costs in colour: CIEDE2000 against the build laid without it,
	# part for part where it shows.
	var cost: float = float(stock.get("de_shown", 0.0))
	_check("what that costs in colour where it shows: %.2f (CIEDE2000, %d of %d parts that show changed, %.1f each)"
		% [cost, int(stock["changed_shown"]), int(stock["shown"]), float(stock["de_changed"])],
		int(stock["shown"]) > 0 and cost >= 0.0)
	var report: Dictionary = _checker._check(model, true, false, true, false)
	_check("and still one piece, passing the check: %s" % report.get("summary", ""),
		bool(report.get("ok", false)) and int(report.get("pieces", 0)) == 1)
	_check("with its steps, every one standing: %s" % (plan.said() if plan != null else "none"),
		plan != null and plan.stood == plan.steps - 1)
	# And taking any colour on hand where it shows: more of it drawn, at what cost.
	var held: float = BrickifyStock.shown_most
	BrickifyStock.shown_most = INF
	var any: Dictionary = Brickify.build(mesh, options, _checker)
	var loose: Dictionary = BrickifyStock.draw(any["model"], on_hand, _checker)
	BrickifyStock.shown_most = held
	print("    any colour where it shows: %s" % BrickifyStock.said(loose))
	_numbers["collection_10698_any_colour"] = loose.duplicate()
	(_numbers["collection_10698_any_colour"] as Dictionary)["short"] = (loose.get("short", []) as Array).slice(0, 12)
	_check("taking any colour where it shows draws more, %d against %d, and costs more in colour, %.2f against %.2f"
		% [int(loose["drawn"]), drawn, float(loose["de_shown"]), cost],
		int(loose["drawn"]) >= drawn and float(loose["de_shown"]) >= cost)
	sets.queue_free()


## What touches each floating part of a partial build, and its step: what
## the steps took to hold it.
func _beside(floating: Array, partial: Assistant.Model, ids: PackedInt64Array,
		index_of: Dictionary, plan: BrickifySteps.Plan, model: Assistant.Model) -> void:
	for at: Variant in floating:
		var placement: Assistant.Placement = partial.placements[int(at)]
		var index: int = model.placements.find(placement)
		var brick: BrickWorld.Brick = _world.get_brick(ids[index])
		var box: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
		var near := PackedStringArray()
		for other: int in ids.size():
			if other == index:
				continue
			var them: BrickWorld.Brick = _world.get_brick(ids[other])
			var their: AABB = them.transform * _library.mesh_for(them.part_id).bounds
			if box.grow(2.0).intersects(their):
				near.append("%s step %d panel %d%s" % [them.part_id, plan.step[other],
					plan.panel[other], " in" if partial.placements.has(model.placements[other]) else ""])
		print("    floating %s (step %d, panel %d, face %s): beside %s" % [brick.part_id,
			plan.step[index], plan.panel[index], placement.face, ", ".join(near)])


## Whether every piece of [param partial] stands on the ground: has a part
## as low as the lowest of all of them.
func _each_on_the_ground(partial: Assistant.Model, pieces: Array) -> bool:
	var lowest: float = INF
	for placement: Assistant.Placement in partial.placements:
		lowest = minf(lowest, placement.y)
	for piece: Array in pieces:
		var low: float = INF
		for index: Variant in piece:
			low = minf(low, (partial.placements[int(index)] as Assistant.Placement).y)
		if low > lowest + 0.01:
			return false
	return true


## The numbers so far, as buy.json in --out: kept as each model is done.
func _save_numbers() -> void:
	if _out.is_empty():
		return
	var file := FileAccess.open(_out.path_join("buy.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_numbers, "  "))
	file.close()


## A model file read as a picked one is, with what it names beside it (an
## OBJ's .mtl and its picture, a .gltf's .bin).
func _read(path: String) -> MeshFile:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var extras: Dictionary = {}
	for _round: int in 2:
		for wanted: String in MeshFile.companions(bytes, path.get_file(), extras):
			var beside: String = path.get_base_dir().path_join(wanted)
			if not extras.has(wanted) and FileAccess.file_exists(beside):
				extras[wanted] = FileAccess.get_file_as_bytes(beside)
	return MeshFile.read(bytes, path.get_file(), extras)
