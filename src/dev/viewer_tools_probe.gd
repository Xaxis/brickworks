## Does the tab give the card in Claude what it draws and asks for?
##
##   godot --headless --path . --script src/dev/viewer_tools_probe.gd
##   godot --headless --path . --script src/dev/viewer_tools_probe.gd -- --sizes   # and pack 400 and 4,000 parts
##
## The card (api/_viewer.js, from tools/viewer/) draws the model in 3D from
## the model packed by the tab (ModelScene) and calls the tab back through
## the host for the rest (ViewerTools). Called here as the relay calls them,
## CommandSocket.answer_rpc, on the real scene, and each read back off the
## model: the bricks unpacked are the model's bricks, number for number and
## place for place; the check names the model's own parts; the steps put on
## every part once; the parts list counts what is there; a pick selects the
## brick and only while the card's model is the tab's. None of them changes
## the model, and none is in the tool list Claude reads.
##
## Writes the packed scene to user://viewer_tools_probe/scene.json, which
## tools/viewer/scene_check.mjs unpacks as the card does.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _assistant: Assistant
var _next: int = 0

## A tower, an arm held on one stud (a 1 x 1 plate), and a weight at its far
## end; as tools/web/app_host_check.mjs builds it.
const CRANE: Array = [
	{"part": "3001", "color": 1, "x": 10, "y": 0, "z": 10},
	{"part": "3001", "color": 15, "x": 10, "y": 3, "z": 10},
	{"part": "3001", "color": 1, "x": 10, "y": 6, "z": 10},
	{"part": "3024", "color": 72, "x": 13, "y": 9, "z": 10},
	{"part": "3034", "color": 72, "x": 13, "y": 10, "z": 10},
	{"part": "3001", "color": 0, "x": 17, "y": 11, "z": 10},
	{"part": "3001", "color": 0, "x": 17, "y": 14, "z": 10},
	{"part": "3003", "color": 2, "x": 17, "y": 17, "z": 10, "rot": 1},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_assistant = _main.get("_assistant")
	_main.call("clear_model")
	_socket = CommandSocket.new()
	_socket.assistant = _assistant
	_socket.app = _main
	_main.add_child(_socket)
	await process_frame

	var listed: Dictionary = await _rpc("tools/list", {})
	var names: Array = (listed.get("tools", []) as Array).map(
		func(tool: Dictionary) -> String: return str(tool["name"]))
	_check("the tool list Claude reads has none of the viewer's (%d tools)" % names.size(),
		not names.any(func(n: String) -> bool: return n.begins_with("viewer_")))

	# A tower with an arm held out on one stud, a weight at its end, and one
	# part turned: something for the check to find, and a turn to unpack.
	var built: String = await _say("submit_design", {"name": "Viewer probe", "bricks": CRANE})
	_check("a small model built: %s" % built.left(60), built.contains("Built"))
	# The app settles a model after a build (its floor, its reveal): what is
	# measured here is the model once that is done.
	var settled: int = _world.revision
	for _n: int in 240:
		await process_frame
		if _n % 30 == 29:
			if _world.revision == settled:
				break
			settled = _world.revision
	var revision: int = _world.revision
	var depth: int = _builder.history_depth()
	print("  (settled at revision %d, %d frames on; a job running: %s, in hand: %d)" % [revision, 240,
		str(_socket.jobs.running() != null), int(_socket.get("_in_hand"))])

	print("── viewer_scene ──")
	var scene_answer: Dictionary = await _call("viewer_scene", {})
	var data: Dictionary = scene_answer.get("structuredContent", {})
	var scene: Dictionary = data.get("scene", {})
	var bricks: Array = _world.bricks()
	bricks.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	_check("it answers with the model packed, v1, %d bricks, of %s" % [int(scene.get("count", -1)),
		str(scene.get("of", ""))], int(scene.get("v", 0)) == 1 and int(scene.get("count", -1)) == bricks.size()
		and str(scene.get("of", "")) == ModelScene.of(_world) and str(data.get("of", "")) == ModelScene.of(_world))
	_check("...and the parts count, %d" % int(data.get("parts", -1)),
		int(data.get("parts", -1)) == _world.brick_count() - _assistant.scenery.size())
	_check("...where the geometry is: %s" % str(scene.get("root", "")),
		str(scene.get("root", "")).ends_with("/") and not str(scene.get("root", "")).is_empty())
	var meshes: Array = scene.get("meshes", [])
	var info: PartLibrary.PartInfo = _library.parts.get("3001")
	var row: Array = meshes.filter(func(m: Array) -> bool: return str(m[0]) == "3001").front() \
		if meshes.any(func(m: Array) -> bool: return str(m[0]) == "3001") else []
	_check("each part named once, by its geometry's hash: 3001 is %s" % (str(row[1]) if row.size() > 1 else "?"),
		row.size() == 9 and str(row[1]) == info.mesh_hash and meshes.size() == _parts_in(bricks))
	var colours: Array = scene.get("colours", [])
	var red: Array = colours.filter(func(c: Array) -> bool: return int(c[0]) == 1).front() \
		if colours.any(func(c: Array) -> bool: return int(c[0]) == 1) else []
	_check("each colour once, as the app draws it: 1 is %s, %s" % [str(red[1]) if red.size() > 1 else "?",
		str(red[2]) if red.size() > 2 else "?"],
		red.size() == 4 and str(red[2]) == _library.color(1).shown.to_html(false) and int(red[3]) == 255)
	var unpacked: Array = _unpack(scene)
	var same: bool = unpacked.size() == bricks.size()
	var worst: float = 0.0
	for k: int in mini(unpacked.size(), bricks.size()):
		var brick: BrickWorld.Brick = bricks[k]
		var got: Dictionary = unpacked[k]
		same = same and int(got["id"]) == brick.id and str(meshes[int(got["mesh"])][0]) == brick.part_id \
			and int(colours[int(got["colour"])][0]) == brick.color_code
		worst = maxf(worst, (got["at"] as Vector3).distance_to(brick.transform.origin))
		var turned: Basis = Basis(got["turn"] as Quaternion)
		worst = maxf(worst, (turned.x - brick.transform.basis.x).length() * 100.0)
	_check("unpacked, the bricks are the model's: number, part, colour (%d)" % unpacked.size(), same)
	_check("...and where and how each is turned, to %.3f LDU" % worst, same and worst < 0.2)
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir().path_join("viewer_tools_probe"))
	var file := FileAccess.open(OS.get_user_data_dir().path_join("viewer_tools_probe/scene.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene": scene, "bricks": bricks.map(func(b: BrickWorld.Brick) -> Array:
		return [b.id, b.part_id, b.color_code, b.transform.origin.x, b.transform.origin.y, b.transform.origin.z])}))
	file.close()
	var again: Dictionary = (await _call("viewer_scene", {})).get("structuredContent", {})
	_check("asked again with nothing changed, it is the same packing",
		JSON.stringify(again.get("scene", {})) == JSON.stringify(scene))

	print("── viewer_check ──")
	var checked: Dictionary = (await _call("viewer_check", {})).get("structuredContent", {})
	_check("the check answers in words: \"%s\"" % str(checked.get("words", "")).left(70),
		not str(checked.get("words", "")).is_empty() and checked.get("weak") is Array and checked.get("stress") is Array)
	var known: bool = true
	for one: Variant in (checked.get("weak", []) as Array) + (checked.get("stress", []) as Array):
		var id: int = int((one as Dictionary)["id"]) if one is Dictionary else int((one as Array)[0])
		known = known and _world.get_brick(id) != null
	var named: int = (checked.get("weak", []) as Array).size() + (checked.get("stress", []) as Array).size()
	_check("...and every part it names is the model's (%d weak, %d strained)" % [
		(checked.get("weak", []) as Array).size(), (checked.get("stress", []) as Array).size()], known)
	_check("...which, for an arm held out on one stud, are some", named > 0)

	print("── viewer_steps ──")
	var planned: Dictionary = (await _call("viewer_steps", {})).get("structuredContent", {})
	var steps: Array = planned.get("steps", [])
	var seen: Dictionary = {}
	var once: bool = true
	var rising: bool = true
	var last: int = 0
	for step: Dictionary in steps:
		rising = rising and int(step["number"]) >= last
		last = int(step["number"])
		for id: Variant in step["ids"]:
			once = once and not seen.has(int(id))
			seen[int(id)] = true
	var wanted: int = _world.brick_count() - _assistant.scenery.size()
	var booklet: Array[Instructions.Step] = Instructions.plan(_world, _library, _assistant.scenery, {}, true)
	_check("the steps put on every part once: %d steps, %d of %d parts" % [steps.size(), seen.size(), wanted],
		steps.size() > 0 and once and seen.size() == wanted)
	_check("...numbered as the booklet numbers them", rising and not steps.is_empty()
		and steps.size() == booklet.size() and int(steps[-1]["number"]) == booklet[-1].number)

	print("── viewer_parts ──")
	var parts: Dictionary = (await _call("viewer_parts", {})).get("structuredContent", {})
	var lots: Array = parts.get("lots", [])
	var counted: int = 0
	for lot: Dictionary in lots:
		counted += int(lot["count"])
	_check("the parts list counts what is there: %d pieces in %d lots" % [int(parts.get("pieces", 0)), lots.size()],
		counted == int(parts.get("pieces", -1)) and counted == wanted and lots.size() == 6)
	var xml: String = str((parts.get("bricklink", {}) as Dictionary).get("text", ""))
	_check("...and the BrickLink wanted list, %d characters, as %s" % [xml.length(), str(parts.get("file", ""))],
		xml.begins_with("<INVENTORY>") and xml.contains("<ITEMID>3001</ITEMID>") and str(parts.get("file", "")).ends_with(".xml"))

	print("── viewer_pick ──")
	var target: int = 0
	for brick: BrickWorld.Brick in bricks:
		if not _assistant.scenery.has(brick.id):
			target = brick.id
			break
	var picked: Dictionary = (await _call("viewer_pick", {"brick": target, "of": ModelScene.of(_world)})).get("structuredContent", {})
	_check("a pick selects that brick in the tab: #%d, %s" % [target, JSON.stringify(picked)],
		bool(picked.get("selected", false)) and _builder.selection.size() == 1 and _builder.selection.has(target))
	var selection_said: String = await _say("selection", {})
	_check("...which Claude's selection tool reads: %s" % selection_said.left(80).replace("\n", " "),
		selection_said.contains("#%d" % target) or selection_said.contains(str(target)))
	var stale: Dictionary = (await _call("viewer_pick", {"brick": (bricks[0] as BrickWorld.Brick).id,
		"of": "1:2:3"})).get("structuredContent", {})
	_check("a card of a model that has changed since selects nothing",
		bool(stale.get("changed", false)) and _builder.selection.has(target) and _builder.selection.size() == 1)
	await _call("viewer_pick", {"brick": 0, "of": ModelScene.of(_world)})
	_check("...and letting go clears it", _builder.selection.is_empty())

	_check("none of it changed the model, or made a step to undo (%d, %d)" % [_world.revision - revision,
		_builder.history_depth() - depth], _world.revision == revision and _builder.history_depth() == depth)

	print("── an answer, with the viewer's share asked for, and without ──")
	var asked: Dictionary = await _rpc("tools/call", {"name": "look_at_model", "arguments": {},
		"_meta": {ModelViews.ASKED: true}})
	var shown: Dictionary = (asked.get("_meta", {}) as Dictionary).get(ModelViews.KEY, {})
	_check("asked, look_at_model's _meta carries the model packed and the count",
		(shown.get("scene", {}) as Dictionary).get("of", "") == ModelScene.of(_world)
			and int(shown.get("parts", -1)) == wanted)
	var plain: Dictionary = await _rpc("tools/call", {"name": "look_at_model", "arguments": {}})
	_check("not asked, it carries nothing more, and its words are the same",
		not plain.has("_meta") and _text(plain) == _text(asked))

	var unknown: Dictionary = await _call("viewer_nothing", {})
	_check("a name that is not the viewer's goes to the app as before: %s" % _text(unknown).left(60),
		not unknown.has("structuredContent"))

	if "--sizes" in OS.get_cmdline_user_args():
		await _sizes()
	_done()


## The model packed at 400 and 4,000 parts, of a real model: how big, and
## how long it takes.
func _sizes() -> void:
	print("── sizes ──")
	await _say("open_model", {"name": "orthanc", "discard_changes": true})
	for _n: int in 30:
		await process_frame
	var all: Array = _world.bricks()
	all.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	print("  orthanc: %d bricks" % all.size())
	for wanted: int in [400, 4000]:
		if wanted != 400:
			await _say("open_model", {"name": "orthanc", "discard_changes": true})
			for _n: int in 10:
				await process_frame
		var kept: int = 0
		for brick: BrickWorld.Brick in all:
			if _world.get_brick(brick.id) == null:
				continue
			kept += 1
			if kept > wanted:
				_world.remove_brick(brick.id)
		var t0: int = Time.get_ticks_usec()
		var packed: Dictionary = ModelScene.packed(_world, _library, _assistant.scenery)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		var text: String = JSON.stringify(packed)
		# For tools/viewer/first_paint.mjs: the card drawing this, in a browser.
		var kept_file := FileAccess.open(OS.get_user_data_dir().path_join(
			"viewer_tools_probe/scene_%d.json" % wanted), FileAccess.WRITE)
		kept_file.store_string(JSON.stringify({"scene": packed}))
		kept_file.close()
		print("  %5d parts, %3d shapes: %6d characters packed (%d of them the bricks), in %.0f ms" % [
			int(packed["count"]), (packed["meshes"] as Array).size(), text.length(),
			str(packed["bricks"]).length(), ms])
	# Off the baseplate before quitting: the engine shut down with
	# thousands of parts left standing and aborted on the way out.
	_main.call("clear_model")
	for _n: int in 30:
		await process_frame


## How many different parts [param bricks] are of.
static func _parts_in(bricks: Array) -> int:
	var seen: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		seen[brick.part_id] = true
	return seen.size()


## The columns, read back as the card reads them (tools/viewer/scene.js).
func _unpack(scene: Dictionary) -> Array:
	var n: int = int(scene.get("count", 0))
	var size: int = n * 4 + n * 2 + n * 2 + n + (n % 2) + n * 6 + n * 8
	var raw: PackedByteArray = Marshalls.base64_to_raw(str(scene.get("bricks", ""))).decompress(size,
		FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size:
		return []
	var origin := Vector3(scene["origin"][0], scene["origin"][1], scene["origin"][2])
	var step: float = float(scene["step"])
	var out: Array = []
	var id: int = 0
	var at_place: int = n * 9 + (n % 2)
	var at_turn: int = at_place + n * 6
	for k: int in n:
		id += raw.decode_u32(k * 4)
		var at := Vector3(raw.decode_s16(at_place + k * 2), raw.decode_s16(at_place + (n + k) * 2),
			raw.decode_s16(at_place + (2 * n + k) * 2)) * step + origin
		var q := Quaternion(raw.decode_s16(at_turn + k * 2) / 32767.0, raw.decode_s16(at_turn + (n + k) * 2) / 32767.0,
			raw.decode_s16(at_turn + (2 * n + k) * 2) / 32767.0, raw.decode_s16(at_turn + (3 * n + k) * 2) / 32767.0).normalized()
		out.append({"id": id, "mesh": raw.decode_u16(n * 4 + k * 2), "colour": raw.decode_u16(n * 6 + k * 2),
			"at": at, "turn": q})
	return out


func _call(tool: String, arguments: Dictionary) -> Dictionary:
	return await _rpc("tools/call", {"name": tool, "arguments": arguments})


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _call(tool, arguments))


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("the card in Claude is given the model, and what it asks for")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
