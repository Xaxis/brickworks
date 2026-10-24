## A design session's calls, made again on this checkout's check.
##
##   godot --headless --path . --script src/dev/replay_calls.gd -- --calls=FILE [--only=21,30,31] [--out=FILE]
##   godot --path . --resolution 1400x900 --script src/dev/replay_calls.gd -- --calls=FILE --open=LDR [--ids=FILE] [--answers=FILE] [--png=DIR]
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
##
## With --open, the session's model is opened first in the app's real scene
## and every call is made as the desktop's MCP port makes it (CommandSocket
## answer_rpc, tools/call), the window's tools too, so what comes back is what
## the session was given: each call's time and its blocks, the words and each
## picture's size (in a window; headless a look is letters), as --answers' line
## {n, name, ms, blocks: [{type, chars} or {type, width, height}], text}, and
## each picture written to --png. --ids maps the session's brick numbers to
## the opened model's ({"421": [part, colour, x, y, z]}, where look_at_model
## listed it), since a model opened is numbered afresh, and its parts are the
## session's own, as they were for the session that built it. (Not --model= and
## --out=: the app's own scene reads those, and wrote the model and quit.) How mcpcost215 measured
## what walk180's edit and its "what breaks first" were handed (2026-10-23).
extends SceneTree

const MAKES: Array = ["submit_design", "check_design", "edit_model"]

var _main: Node
var _socket: CommandSocket
var _next: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var calls_path: String = ""
	var out_path: String = ""
	var model_path: String = ""
	var ids_path: String = ""
	var png_dir: String = ""
	var only: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--calls="):
			calls_path = argument.trim_prefix("--calls=")
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--open="):
			model_path = argument.trim_prefix("--open=")
		elif argument.begins_with("--answers="):
			out_path = argument.trim_prefix("--answers=")
		elif argument.begins_with("--ids="):
			ids_path = argument.trim_prefix("--ids=")
		elif argument.begins_with("--png="):
			png_dir = argument.trim_prefix("--png=")
		elif argument.begins_with("--only="):
			for n: String in argument.trim_prefix("--only=").split(","):
				only[int(n)] = true
	if calls_path.is_empty() or not FileAccess.file_exists(calls_path):
		print("replay: no --calls file")
		quit(1)
		return
	if not model_path.is_empty():
		await _on_the_model(calls_path, model_path, ids_path, out_path, png_dir, only)
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


## Every call of [param calls_path] on the model at [param model_path], in the
## app's own scene, as the MCP port makes it.
func _on_the_model(calls_path: String, model_path: String, ids_path: String,
		out_path: String, png_dir: String, only: Dictionary) -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_main.call("clear_model")
	_main.call("_open", model_path)
	for _n: int in 10:
		await process_frame
	var world: BrickWorld = _main.get("_world")
	var assistant: Assistant = _main.get("_assistant")
	# As the session that built it had it: its own, not parts placed by hand,
	# which a check from outside weighs the trial among.
	var built: PackedInt64Array = PackedInt64Array()
	for brick: BrickWorld.Brick in world.bricks():
		if not assistant.scenery.has(brick.id):
			built.append(brick.id)
	assistant._placed_ids = built
	print("replay: %s opened, %d bricks" % [model_path.get_file(), world.brick_count()])
	var ids: Dictionary = _matched_ids(ids_path, world, assistant)
	if not png_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(png_dir)
	var out: FileAccess = FileAccess.open(out_path, FileAccess.WRITE) if not out_path.is_empty() else null
	var total_ms: int = 0
	for line: String in FileAccess.get_file_as_string(calls_path).split("\n"):
		var call: Variant = JSON.parse_string(line) if not line.is_empty() else null
		if not call is Dictionary:
			continue
		var n: int = int(call.get("n", 0))
		if not only.is_empty() and not only.has(n):
			continue
		var name: String = str(call.get("name", ""))
		var input: Variant = _renumbered(call.get("input", {}), ids, "")
		var began: int = Time.get_ticks_msec()
		_next += 1
		var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
			"method": "tools/call", "params": {"name": name, "arguments": input}})
		var ms: int = Time.get_ticks_msec() - began
		total_ms += ms
		var blocks: Array = []
		var text: PackedStringArray = PackedStringArray()
		var pictures: int = 0
		for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get(
				"content", []):
			if str(block.get("type", "")) == "image":
				var image := Image.new()
				var bytes: PackedByteArray = Marshalls.base64_to_raw(str(block.get("data", "")))
				image.load_png_from_buffer(bytes)
				blocks.append({"type": "image", "width": image.get_width(),
					"height": image.get_height(), "bytes": bytes.size()})
				if not png_dir.is_empty():
					pictures += 1
					image.save_png(png_dir.path_join("%02d_%s_%d.png" % [n, name, pictures]))
			else:
				var words: String = str(block.get("text", ""))
				blocks.append({"type": "text", "chars": words.length()})
				text.append(words)
		print("#%d %s: %d ms, %s" % [n, name, ms, JSON.stringify(blocks)])
		print("    " + "\n    ".join(text).replace("\n", "\n    ").left(6000))
		if out != null:
			out.store_line(JSON.stringify({"n": n, "name": name, "ms": ms, "blocks": blocks,
				"text": text}))
	if out != null:
		out.close()
	print("replay: calls took %d ms in all" % total_ms)
	_main.queue_free()
	await process_frame
	quit(0)


## The session's brick numbers, as this opening of its model numbers them:
## each found by its part, colour and where look_at_model said it was.
func _matched_ids(ids_path: String, world: BrickWorld, assistant: Assistant) -> Dictionary:
	var out: Dictionary = {}
	if ids_path.is_empty():
		return out
	var wanted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ids_path))
	var missing: PackedStringArray = PackedStringArray()
	for key: String in wanted:
		var said: Array = wanted[key]
		for brick: BrickWorld.Brick in world.bricks():
			if brick.part_id != str(said[0]) or brick.color_code != int(said[1]):
				continue
			var corners: Array = assistant._corners_in_studs(brick)
			if corners.is_empty():
				continue
			var at: Vector3 = corners[0]
			if at.distance_to(Vector3(float(said[2]), float(said[3]), float(said[4]))) < 0.06:
				out[int(key)] = brick.id
				break
		if not out.has(int(key)):
			missing.append(key)
	print("replay: %d of %d brick numbers found%s" % [out.size(), wanted.size(),
		"" if missing.is_empty() else ", not: " + ", ".join(missing)])
	return out


## [param input] with each brick number in it the opened model's: the numbers
## of "bricks", "remove" and "part", at any depth.
static func _renumbered(input: Variant, ids: Dictionary, key: String) -> Variant:
	if ids.is_empty():
		return input
	if input is Dictionary:
		var out: Dictionary = {}
		for inner: Variant in input:
			out[inner] = _renumbered(input[inner], ids, str(inner))
		return out
	if input is Array:
		var out: Array = []
		for one: Variant in input:
			out.append(_renumbered(one, ids, key))
		return out
	if key in ["bricks", "remove", "part"] and (input is int or input is float) \
			and ids.has(int(input)):
		return ids[int(input)]
	return input


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
