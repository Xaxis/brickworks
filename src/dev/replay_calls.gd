## A design session's calls, made again on this checkout's check.
##
##   godot --headless --path . --script src/dev/replay_calls.gd -- --calls=FILE [--only=21,30,31] [--out=FILE]
##
## FILE is one JSON line a call, {n, name, input}, as a session's transcript
## has them (a bench run's design log says only "2 problems (collision 2)").
## The calls that change or check the model (submit_design, check_design,
## edit_model) are made in their order through Assistant.use_tool on an empty
## baseplate, those of --only alone when it is given, and what each came back
## with is printed: its first line, every collision said, and for a design each
## pair whose shapes collide with how far it reaches from the joint that joins
## it, if one does (ExactCheck.joint_reaches). With --out, one JSON line a call,
## {n, name, head, collisions (how many), said, jointed, text}. A tool for
## seeing a refusal again, not a check: it passes or fails nothing.
extends SceneTree

const MAKES: Array = ["submit_design", "check_design", "edit_model"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var calls_path: String = ""
	var out_path: String = ""
	var only: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--calls="):
			calls_path = argument.trim_prefix("--calls=")
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="):
			for n: String in argument.trim_prefix("--only=").split(","):
				only[int(n)] = true
	if calls_path.is_empty() or not FileAccess.file_exists(calls_path):
		print("replay: no --calls file")
		quit(1)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	await process_frame
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if not out_path.is_empty() else null
	var refused: int = 0
	var made: int = 0
	for line: String in FileAccess.get_file_as_string(calls_path).split("\n"):
		var call: Variant = JSON.parse_string(line) if not line.is_empty() else null
		if not call is Dictionary:
			continue
		var n: int = int(call.get("n", 0))
		var name: String = str(call.get("name", ""))
		if not MAKES.has(name) or (not only.is_empty() and not only.has(n)):
			continue
		var said: Variant = await assistant.use_tool(name, call.get("input", {}))
		var text: String = str(said)
		var collisions: Array = []
		var counted: int = 0
		var in_collisions: bool = false
		for row: String in text.split("\n"):
			if row.begins_with("collision ("):
				in_collisions = true
				counted = int(row.trim_prefix("collision (").split(")")[0])
				continue
			if in_collisions and row.begins_with("  - "):
				collisions.append(row.trim_prefix("  - "))
			elif in_collisions:
				in_collisions = false
		made += 1
		if counted > 0:
			refused += 1
		print("#%d %s: %s%s" % [n, name, text.split("\n")[0].left(160),
			" (%d collisions)" % counted if counted > 0 else ""])
		for one: String in collisions:
			print("    collision: %s" % one.left(400))
		var joints: Array = _jointed(assistant, library, call.get("input", {})) \
			if name != "edit_model" else []
		for one: Dictionary in joints:
			print("    jointed: %s" % JSON.stringify(one).left(600))
		if out != null:
			out.store_line(JSON.stringify({"n": n, "name": name, "head": text.split("\n")[0],
				"collisions": counted, "said": collisions, "jointed": joints,
				"text": text.left(4000)}))
	if out != null:
		out.close()
	print("replay: %d calls, %d said a collision" % [made, refused])
	quit(0)


## The design of a check_design or submit_design call, its parts placed as the
## check places them, and each pair whose exact shapes collide that a joint
## joins: {a, b, depth, at_joint, hits: [[depth, [kind, how far the overlap
## reaches from the joint]...]]} (ExactCheck.joint_reaches).
static func _jointed(assistant: Assistant, library: PartLibrary, input: Dictionary) -> Array:
	var model: Assistant.Model = assistant._read_model(input)
	var exact: ExactCheck = assistant._exact_check_for(model, true)
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part != null:
			exact.place(index, placement.part, placement.exact_at(
				assistant._joined_at(placement, part, model)))
	var out: Array = []
	for found: Dictionary in exact.collisions({}):
		var a: int = found["a"]
		var b: int = found["b"]
		var hits: Array = []
		for hit: Array in exact.joint_reaches(a, b):
			var row: Array = [snappedf(float(hit[0]), 0.01)]
			for joint: Array in hit[1]:
				row.append([joint[0], snappedf(float(joint[1]), 0.1)])
			hits.append(row)
		out.append({"a": "%d %s" % [a, model.placements[a].part],
			"b": "%d %s" % [b, model.placements[b].part],
			"depth": snappedf(float(found["depth"]), 0.01), "at_joint": exact.at_joint(a, b),
			"hits": hits})
	return out
