## Can a session do what the person does from the menus?
##
##   godot --headless --path . --script src/dev/app_tools_probe.gd
##
## The window's other commands as MCP tools (src/net/app_tools.gd), each
## called the way the connector and the desktop's HTTP port call it —
## CommandSocket.answer_rpc, tools/call — on the real scene, and each read
## back off the model rather than off its answer: the floor it now stands
## on, the steps its parts are in, the hose's pieces, the arm's angle, the
## file on disk. One undo each, and a refusal that says what to fix.
##
## Rendering and the pictures need a window; here they are refused, and
## the probe checks that the refusal says so.
extends SceneTree

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _next: int = 0
## Where this probe's files go.
var _out: String = ""


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
	_store = _main.get("_store")
	_library = _main.get("_library")
	_main.call("clear_model")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	# Exports go where File, Export puts them; here, a folder of the probe's.
	var out: String = OS.get_user_data_dir().path_join("app_tools_probe")
	DirAccess.make_dir_recursive_absolute(out)
	(_main.get("_exports") as Exports).folder = out
	(_main.get("_render") as RenderDialog).folder = out
	(_main.get("_pose") as PosePanel).folder = out
	_out = out
	await process_frame

	var listed: Dictionary = await _rpc("tools/list", {})
	var names: Array = (listed.get("tools", []) as Array).map(
		func(tool: Dictionary) -> String: return str(tool["name"]))
	var wanted: Array[String] = ["set_floor", "edit_steps", "lay_flex", "pose_model", "animate_model", "undo",
		"open_model", "parts_list", "render_model", "export_model", "job"]
	_check("tools/list offers the window's commands too: %s" % ", ".join(wanted),
		wanted.all(func(name: String) -> bool: return names.has(name)))

	await _floor()
	await _steps()
	await _flex()
	await _pose()
	await _parts()
	await _exports(out)
	await _open()
	await _jobs(out)
	await _brickify()
	await _prints()
	await _unique()
	_done()


func _floor() -> void:
	print("── the floor ──")
	var floor_layer: FloorLayer = _main.get("_floor")
	_check("set_floor says what it stands on: %s" % await _say("set_floor", {}),
		(await _say("set_floor", {})).contains("stands on"))
	var before: String = _store.model_floor.to_meta()
	var said: String = await _say("set_floor", {"across": 30})
	_check("a size not in eights is refused with the nearest: %s" % said,
		said.contains("eights") and said.contains("32") and _store.model_floor.to_meta() == before)
	said = await _say("set_floor", {"colour": 4})
	_check("a colour baseplates are not made in is refused, with theirs: %s" % said.left(70),
		said.contains("not made in colour 4") and said.contains("19 Tan"))
	var depth: int = _builder.history_depth()
	said = await _say("set_floor", {"kind": "baseplate", "across": 48, "colour": 19,
		"part_of_model": true})
	_check("a tan 48 x 48 baseplate, part of the model: %s" % said,
		_store.model_floor.across == 48 and _store.model_floor.colour == 19
			and floor_layer.has_own_plate())
	_check("...in one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	said = await _say("undo", {})
	_check("undo takes it back: %s" % said.left(80),
		said.begins_with("Undid") and _store.model_floor.to_meta() == before
			and not floor_layer.has_own_plate())
	said = await _say("undo", {"redo": true})
	_check("...and redo puts it back", said.begins_with("Redid")
		and _store.model_floor.across == 48 and floor_layer.has_own_plate())
	said = await _say("set_floor", {"kind": "none"})
	_check("no floor, which takes the plate out of the model: %s" % said,
		_store.model_floor.kind == ModelFloor.NONE and not floor_layer.has_own_plate())
	_check("nothing to redo is said: %s" % await _say("undo", {"redo": true}),
		(await _say("undo", {"redo": true})).begins_with("Nothing to redo"))


func _steps() -> void:
	print("── the build steps ──")
	_main.call("clear_model")
	var built: String = await _say("submit_design", {"bricks": [
		{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0},
		{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0},
		{"part": "3001", "color": 1, "x": 0, "y": 6, "z": 0},
		{"part": "3001", "color": 1, "x": 0, "y": 9, "z": 0}]})
	var ids: Array[int] = _model_ids()
	_check("a four-brick tower to give steps to: %s" % built.left(40), ids.size() == 4)
	var said: String = await _say("edit_steps", {})
	_check("edit_steps lists them, worked out: %s" % said.get_slice("\n", 0),
		said.contains("worked out") and said.contains("#%d" % ids[0]))
	var depth: int = _builder.history_depth()
	said = await _say("edit_steps", {"op": "new", "bricks": [ids[3]]})
	_check("a new step of the top brick: %s" % said,
		said.contains("new step") and AuthorSteps.any(_world, _store.scenery))
	_check("...one undo step, the worked-out ones given first inside it",
		_builder.history_depth() == depth + 1)
	var top: int = _world.get_brick(ids[3]).step
	_check("...and the top brick is in a step of its own, after the rest (%d)" % top,
		top > _world.get_brick(ids[2]).step)
	said = await _say("edit_steps", {"op": "merge", "step": 1})
	_check("a step merged by its number: %s" % said, said.contains("merged step 1"))
	said = await _say("edit_steps", {"op": "later", "step": 99})
	_check("a step that is not there is refused: %s" % said, said.begins_with("There is no step 99"))
	said = await _say("edit_steps", {"op": "next", "bricks": [9999]})
	_check("a part that is not there is refused: %s" % said, said.contains("No part numbered 9999"))
	said = await _say("edit_steps", {"op": "next"})
	_check("no parts given is refused with what to give: %s" % said, said.contains("bricks="))
	# Asked about two selected parts (Ask Claude about this…): the rest stays.
	var assistant: Assistant = _main.get("_assistant")
	assistant.focus_on([ids[0], ids[1]], true)
	said = await _say("set_floor", {"kind": "grid"})
	_check("asked about a selection, the floor is not changed: %s" % said.left(60),
		said.begins_with("Not now") and _store.model_floor.kind != ModelFloor.GRID)
	assistant.unfocus()
	await _say("undo", {"steps": 2})
	_check("two undos take the model back to steps nobody gave it",
		not AuthorSteps.any(_world, _store.scenery))


func _flex() -> void:
	print("── a hose ──")
	_main.call("clear_model")
	var one: int = _put("3700", Vector3(0, 24, 0))
	var two: int = _put("3700", Vector3(80, 24, 0))
	var plain: int = _put("3001", Vector3(200, 24, 0))
	var before: int = _world.brick_count()
	var depth: int = _builder.history_depth()
	var said: String = await _say("lay_flex", {"kind": "pneumatic_tube",
		"from": {"brick": one}, "to": {"brick": two}, "color": 1})
	var items: Dictionary = Flex.items_in(_world)
	_check("a pneumatic tube between two Technic bricks' holes: %s" % said,
		said.begins_with("Laid") and items.size() == 1 and _world.brick_count() > before)
	_check("...one undo step", _builder.history_depth() == depth + 1)
	var path: String = items.keys()[0] if not items.is_empty() else ""
	said = await _say("lay_flex", {"kind": "pneumatic_tube", "item": Assemblies.label(path),
		"from": {"brick": one}, "to": {"brick": two, "x": 4, "y": 2, "z": 1}})
	_check("...laid again by its name, not a second one: %s" % said,
		said.begins_with("Laid") and Flex.items_in(_world).size() == 1)
	said = await _say("lay_flex", {"kind": "pneumatic_tube", "from": {"brick": one},
		"to": {"brick": plain}})
	_check("a brick with no hole is refused, saying what it takes: %s" % said,
		said.contains("has nothing") and said.contains("pin hole"))
	said = await _say("lay_flex", {"kind": "rope", "from": {"brick": one}, "to": {"brick": two}})
	_check("a kind there is not is refused with the kinds: %s" % said.left(60),
		said.begins_with("kind is one of") and said.contains("ribbed_hose"))
	await _say("undo", {"steps": 2})
	_check("undone, it is gone", Flex.items_in(_world).is_empty() and _world.brick_count() == before)


func _pose() -> void:
	print("── a pose ──")
	_main.call("clear_model")
	var said: String = await _say("pose_model", {})
	_check("nothing to pose is said, with what makes a joint: %s" % said.left(60),
		said.begins_with("Nothing here turns"))
	# The pose probe's crane: a turret on a turntable, an arm on a hinge.
	_put("3680", Vector3(0, 8, 0), Basis.IDENTITY, "")
	_put("3679", Vector3(0, 8, 0), Basis.IDENTITY, "Turret#1")
	_put("3937", Vector3(0, 32, 0), Basis.IDENTITY, "Turret#1")
	var top: int = _put("3938", Vector3(0, 32, 0), Basis.IDENTITY, "Turret#1/Arm#1")
	_put("3795", Vector3(0, 40, 50), Basis(Vector3.UP, PI * 0.5), "Turret#1/Arm#1")
	said = await _say("pose_model", {})
	_check("pose_model lists the turntable and the hinge: %s" % said.replace("\n", " ").left(120),
		said.contains("turntable") and said.contains("hinge"))
	var was: Transform3D = _world.get_brick(top).transform
	var depth: int = _builder.history_depth()
	said = await _say("pose_model", {"joint": "1", "degrees": 90})
	_check("the turret swung to 90°: %s" % said,
		said.ends_with("at 90°.") and not _world.get_brick(top).transform.is_equal_approx(was))
	_check("...one undo step", _builder.history_depth() == depth + 1)
	said = await _say("pose_model", {"joint": "9"})
	_check("a joint not in the list is refused: %s" % said, said.begins_with("No joint 9"))
	await _say("undo", {})
	_check("undone, it stands where it was", _world.get_brick(top).transform.is_equal_approx(was))
	# And animated: the turret round and the arm up, over a second.
	var panel: PosePanel = _main.get("_pose")
	said = await _say("animate_model", {"keys": [{"t": 0, "angles": {"1": 0, "2": 0}},
		{"t": 1, "angles": {"Turret": 90, "2": 30}}]})
	var keys: Array = panel.animation.keys
	_check("animate_model sets two keys, joints by number and by name: %s" % said.left(70),
		keys.size() == 2 and ((keys[1] as Dictionary)["angles"] as Dictionary).size() == 2)
	if DisplayServer.get_name() == "headless":
		_check("...and says rendering it needs a window", said.contains("without a window"))
	else:
		_check("...and renders it where Render saves: %s" % said,
			said.contains(".webp") and said.contains(_out))
	_check("...without moving the model", _world.get_brick(top).transform.is_equal_approx(was))
	said = await _say("animate_model", {"keys": [{"t": 0, "angles": {"9": 10}}]})
	_check("a key for a joint not there is refused: %s" % said, said.begins_with("No joint 9"))
	said = await _say("animate_model", {})
	_check("no keys is refused with what to give: %s" % said.left(50), said.begins_with("Give keys="))


func _parts() -> void:
	print("── the parts list ──")
	var said: String = await _say("parts_list", {})
	_check("the parts list counts the crane: %s" % said.get_slice("\n", 0),
		said.begins_with("5 pieces in 5 lots") and said.contains("3679"))
	said = await _say("parts_list", {"which": "need"})
	_check("with no collection it says where to add one: %s" % said.left(60),
		said.contains("collection is empty") and said.contains("My collection"))
	var mine: CollectionStore = (_main.get("_shell") as Shell).collection.store
	mine.on_hand = {Collection.key_of("3680", 7, _library): 1}
	said = await _say("parts_list", {"which": "need"})
	_check("against one part owned, it says what is owned and short: %s"
		% said.replace("\n", " ").left(90),
		said.contains("Of 5 pieces, they own 1 in the right colour") and said.contains("Short of 4 lots"))
	var saved: String = await _say("save_model", {"name": "app-tools-probe-crane"})
	said = await _say("parts_list", {"which": "buildable"})
	_check("which saved models it builds, the crane saved among them: %s"
		% said.replace("\n", " ").left(100),
		saved.begins_with("Written") and said.contains("app-tools-probe-crane: owns 1 of its 5 pieces"))
	DirAccess.remove_absolute(ModelStore.SAVE_DIR + "app-tools-probe-crane.ldr")
	mine.on_hand = {}


func _exports(out: String) -> void:
	print("── exporting ──")
	var said: String = await _say("export_model", {"format": "ldraw"})
	var written: String = said.trim_prefix("Wrote ").trim_suffix(".")
	_check("LDraw, where Export writes: %s" % said, said.begins_with("Wrote " + out)
		and FileAccess.get_file_as_string(written).count("\n1 ") >= 5)
	said = await _say("export_model", {"format": "bricklink"})
	_check("a BrickLink wanted list: %s" % said.left(80), said.begins_with("Wrote")
		and FileAccess.get_file_as_string(said.trim_prefix("Wrote ").get_slice(" —", 0)
			.trim_suffix(".")).contains("<INVENTORY>"))
	said = await _say("export_model", {"format": "rebrickable"})
	_check("a Rebrickable parts list: %s" % said.left(80), said.begins_with("Wrote")
		and said.contains(".csv"))
	said = await _say("export_model", {"format": "studio"})
	var io: String = said.trim_prefix("Wrote ").trim_suffix(".")
	_check("a Studio .io: %s" % said, said.ends_with(".io.")
		and FileAccess.get_file_as_bytes(io).size() > 100)
	if DisplayServer.get_name() == "headless":
		said = await _say("export_model", {"format": "picture"})
		_check("a picture headless is refused, saying why: %s" % said.left(60),
			said.contains("without a window"))
		said = await _say("render_model", {"kind": "picture"})
		_check("so is a render: %s" % said.left(70), said.contains("without a window"))
		said = await _say("export_model", {"format": "instructions"})
		_check("and the booklet: %s" % said.left(70), said.contains("without a window"))
	else:
		said = await _say("export_model", {"format": "picture"})
		_check("a picture of the model: %s" % said, said.contains(out) and said.contains(".png")
			and FileAccess.file_exists(said.trim_prefix("Wrote ").get_slice(" ", 0).trim_suffix(".")))
		var result: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_model",
			"arguments": {"kind": "picture", "quality": "quick", "size": "720p"}}))
		var kinds: Array = (result.get("content", []) as Array).map(
			func(block: Dictionary) -> String: return str(block.get("type", "")))
		var text: String = str(((result.get("content", []) as Array)[0] as Dictionary).get("text", ""))
		_check("a quick render, written where Render writes, and shown: %s %s" % [text, kinds],
			text.contains(out) and kinds.has("image"))
		said = await _say("export_model", {"format": "instructions"})
		_check("the building instructions as a booklet: %s" % said, said.contains("_instructions.html")
			and FileAccess.get_file_as_string(said.trim_prefix("Wrote ").get_slice(",", 0)).contains("<html"))
	said = await _say("export_model", {"format": "pdf"})
	_check("a format there is not is refused with the formats", said.begins_with("format is"))


func _open() -> void:
	print("── opening ──")
	var said: String = await _say("open_model", {})
	var examples: Array[ModelStore.Entry] = _store.list_examples()
	_check("open_model lists the examples: %s" % said.get_slice("\n", 2).left(80),
		not examples.is_empty() and said.contains(examples[0].name))
	said = await _say("open_model", {"name": examples[0].name})
	_check("the crane is not saved, so opening is refused: %s" % said.left(80),
		said.contains("not saved") and said.contains("discard_changes"))
	said = await _say("open_model", {"name": examples[0].name, "discard_changes": true})
	_check("...and opens with discard_changes: %s" % said.left(70),
		said.begins_with("Opened") and _model_ids().size() == examples[0].bricks)
	said = await _say("open_model", {"name": "no such model"})
	_check("a name not in the list is refused", said.begins_with("No model called"))
	# A model shared to look at (the /m/ link): what the window allows then.
	var shell: Shell = _main.get("_shell")
	shell.read_only = true
	said = await _say("set_floor", {"kind": "grid"})
	_check("a model shared to look at is not changed: %s" % said.left(60),
		said.begins_with("This tab shows a model shared to look at")
			and _store.model_floor.kind != ModelFloor.GRID)
	_check("...but its parts are listed",
		(await _say("parts_list", {})).contains(" pieces in "))
	shell.read_only = false


## Long work answers at once with a job, the one the window's bar shows, and
## job says how it goes, gives the answer and stops it (src/net/tool_jobs.gd).
func _jobs(out: String) -> void:
	print("── long work, as jobs ──")
	var asked_at: int = Time.get_ticks_msec()
	var first: Dictionary = await _rpc("tools/call", {"name": "export_model",
		"arguments": {"format": "studio"}})
	var waited: int = Time.get_ticks_msec() - asked_at
	var id: int = _job_of(first)
	_check("a Studio file is a job, answered at once (%d ms): %s" % [waited, _text(first).left(80)],
		id > 0 and waited < 2000 and _text(first).contains("job {\"id\": %d}" % id))
	var shown: Working.Job = Working.current()
	_check("...and the window's bar is that job: %s" % (shown.line() if shown != null else "none"),
		shown != null and shown.words.begins_with("Writing") and not shown.can_cancel)
	var meanwhile: String = await _say("parts_list", {})
	_check("a call meanwhile is told at once that the app is busy with it: %s" % meanwhile.left(60),
		meanwhile.begins_with("The app is busy with job %d" % id))
	var stop: String = await _say("job", {"id": id, "cancel": true})
	_check("...which cannot be stopped part way, and says so: %s" % stop.left(60),
		stop.contains("cannot be stopped part way"))
	var finished: Dictionary = await _finished(first)
	var said: String = _text(finished)
	var io: String = said.trim_prefix("Wrote ").trim_suffix(".")
	_check("job gives the answer once it is done: %s" % str(finished.get("job", "")).get_slice("\n", 0),
		str(finished.get("job", "")).contains("is done") and said.ends_with(".io.")
			and FileAccess.get_file_as_bytes(io).size() > 100)
	_check("...and the bar went with it", not Working.is_busy())
	said = await _say("job", {"id": id})
	_check("...and can be asked for again", said.contains("is done") and said.contains(".io"))
	said = await _say("job", {"id": 999})
	_check("a job that is not there is refused, naming those that are: %s" % said,
		said.begins_with("No job 999") and said.contains("%d (export_model, done)" % id))
	# Any other call still going after its time becomes a job where it stands.
	_socket.jobs.after_s = 0.0
	var examples: Array[ModelStore.Entry] = _store.list_examples()
	var opening: Dictionary = await _rpc("tools/call", {"name": "open_model",
		"arguments": {"name": examples[0].name, "discard_changes": true}})
	_socket.jobs.after_s = 20.0
	var opened: String = _text(await _finished(opening))
	_check("a call past its time becomes a job: %s" % _text(opening).left(60),
		_job_of(opening) > id and opened.begins_with("Opened"))
	if DisplayServer.get_name() == "headless":
		return
	# A turntable, stopped part way: by the job tool, as by the bar's Cancel.
	var turning: Dictionary = await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "turntable"}})
	var spin: int = _job_of(turning)
	_check("a turntable is a job that can be stopped: %s" % _text(turning).left(70),
		spin > 0 and _text(turning).contains("\"cancel\": true"))
	var bar: Working.Job = Working.current()
	while bar != null and not bar.ended and bar.done < 2:
		await process_frame
	_socket.jobs.wait_s = 0.0
	said = await _say("job", {"id": spin})
	_socket.jobs.wait_s = 10.0
	_check("job says how far it has got: %s" % said.left(110),
		said.contains("is still going") and said.contains(" of 36"))
	said = await _say("job", {"id": spin, "cancel": true})
	var renderer: StudioRender = (_main.get("_render") as RenderDialog).renderer
	_check("cancelled, it stops: %s" % said.left(80), said.contains("was cancelled")
		and not renderer.is_busy() and not Working.is_busy())
	var name: String = (_main.get("_bar") as ModelBar).model_name()
	_check("...and no turntable was written",
		not FileAccess.file_exists(out.path_join(RenderOutput.file_name(name, "_turntable", "webp"))))
	_check("...and the app is free again: %s" % (await _say("parts_list", {})).get_slice("\n", 0),
		(await _say("parts_list", {})).contains(" pieces in "))


## A 3D model laid in LEGO® bricks from a link the app fetches: here the probe's own
## tiny web server, which only a probe may fetch from (AppTools.fetch_near).
func _brickify() -> void:
	print("── brickify ──")
	_main.call("clear_model")
	var tools: AppTools = _socket._the_app_tools()
	var server := _Files.new()
	server.files = {"/bunny.obj": FileAccess.get_file_as_bytes("res://tests/fixtures/brickify/bunny.obj"),
		"/notes.txt": "not a model".to_utf8_buffer()}
	root.add_child(server)
	var at: String = "http://127.0.0.1:%d" % server.port
	var said: String = await _say("brickify", {"url": "ftp://example.com/bunny.obj"})
	_check("a link that is not http or https is refused: %s" % said.left(60),
		said.begins_with("Only an http or https link") and said.contains("file="))
	# A path on this computer is read only when it names a 3D model: a session
	# drives the app, not the person's files.
	said = await _say("brickify", {"url": "file:///etc/passwd"})
	_check("a file that is not a 3D model is not read: %s" % said.left(70),
		said.contains("is not an OBJ, STL, glTF or GLB file"))
	said = await _say("brickify", {"file": "/no/such/place/bunny.obj"})
	_check("...nor one that is not there: %s" % said.left(70), said.begins_with("There is no file"))
	said = await _say("brickify", {"url": at + "/bunny.obj"})
	_check("...and one to this computer: %s" % said.left(70), said.contains("this computer"))
	tools.fetch_near = true
	said = await _say("brickify", {"url": at + "/notes.txt"})
	_check("...and one that names no 3D model: %s" % said.left(60), said.contains("does not name"))
	var capped: Dictionary = await tools._fetch(at + "/bunny.obj", 1000)
	_check("the size is capped: %s" % str(capped.get("error", "")).left(60),
		str(capped.get("error", "")).contains("larger than"))
	said = await _say("brickify", {})
	_check("with nothing to lay it says what to give: %s" % said.left(50), said.begins_with("Give file="))
	var before: int = _model_ids().size()
	var depth: int = _builder.history_depth()
	var first: Dictionary = await _rpc("tools/call", {"name": "brickify",
		"arguments": {"url": at + "/bunny.obj", "studs": 12}})
	_check("a link to a model is a job: %s" % _text(first).left(60), _job_of(first) > 0)
	said = _text(await _finished(first))
	var added: Array[int] = _model_ids()
	var path: String = Assemblies.path_of(_world.get_brick(added[-1])) if added.size() > before else ""
	_check("the bunny is fetched and laid, as one sub-assembly: %s" % said.left(90),
		said.begins_with("Brickified bunny") and added.size() > before + 20 and path.begins_with("bunny"))
	_check("...with its steps and how to get its booklet and lists: %s" % said.get_slice("\n", 1).left(120),
		said.contains("steps by courses") and said.contains("format=instructions")
		and said.contains("format=bricklink") and said.contains("format=rebrickable"))
	_check("...one undo step", _builder.history_depth() == depth + 1)
	await _say("undo", {})
	_check("...and undone, it is gone", _model_ids().size() == before)
	# A path on this computer, as a person gives one. A session given one was
	# refused, and told the person to serve the folder on localhost, which is
	# refused too.
	var on_disk: String = ProjectSettings.globalize_path("res://tests/fixtures/brickify/bunny.obj")
	for given: Dictionary in [{"file": on_disk, "studs": 12}, {"url": on_disk, "studs": 12}]:
		var asked: Dictionary = await _rpc("tools/call", {"name": "brickify", "arguments": given})
		said = _text(await _finished(asked))
		added = _model_ids()
		path = Assemblies.path_of(_world.get_brick(added[-1])) if added.size() > before else ""
		_check("%s= a path on this computer lays it, as one sub-assembly: %s"
			% [given.keys()[0], said.left(70)],
			said.begins_with("Brickified bunny") and added.size() > before + 20 and path.begins_with("bunny"))
		await _say("undo", {})
	said = await _say("brickify", {"collection": true})
	_check("laid from a collection the person does not keep, it says so: %s" % said.left(70),
		said.contains("no collection to lay it from"))
	said = await _say("brickify", {"pick": true})
	if DisplayServer.get_name() == "headless":
		_check("headless, there is no file dialog to open: %s" % said.left(60),
			said.contains("without a window"))
	else:
		_check("pick opens the window's file dialog, and says so: %s" % said.left(60),
			said.begins_with("Opened the window's file dialog"))
		var picker: MeshFilePicker = (_main.get("_brickify") as BrickifyDialog)._picker
		_check("...which is open", picker._dialog != null and picker._dialog.visible)
		if picker._dialog != null:
			picker._dialog.hide()
	tools.fetch_near = false
	server.queue_free()


## A print on a part where it stands, and a sticker on a face, each read back
## off the model.
func _prints() -> void:
	print("── prints and stickers ──")
	_main.call("clear_model")
	var tile: int = _put("3068b", Vector3(10, 8, 10))
	var brick: int = _put("3004", Vector3(80, 24, 10))
	var was: Transform3D = _world.get_brick(tile).transform
	var svg: String = ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'>"
		+ "<rect width='64' height='64' fill='#ffffff'/><circle cx='32' cy='32' r='22' "
		+ "fill='#c91a09'/></svg>")
	var said: String = await _say("print_part", {"brick": tile})
	_check("no picture is refused, saying how to give one: %s" % said.left(50),
		said.begins_with("Give the picture"))
	said = await _say("print_part", {"brick": tile, "svg": "<svg"})
	_check("an svg that cannot be drawn is refused: %s" % said.left(50), said.contains("could not be drawn"))
	said = await _say("print_part", {"brick": tile, "svg": svg, "area": "nowhere"})
	_check("an area the part has not is refused, with its areas: %s" % said.left(80),
		said.contains("no area called nowhere"))
	var depth: int = _builder.history_depth()
	said = await _say("print_part", {"brick": tile, "svg": svg, "name": "Probe dot"})
	var printed: BrickWorld.Brick = null
	for one: BrickWorld.Brick in _world.bricks():
		if one.transform.is_equal_approx(was) and not _store.scenery.has(one.id):
			printed = one
	_check("a print on the tile, where it stands: %s" % said.left(100),
		printed != null and printed.id != tile and printed.part_id.begins_with("bw-")
			and PartPrints.mould_of(_library, printed.part_id) == PartPrints.mould_of(_library, "3068b")
			and printed.color_code == 7)
	_check("...one undo step", _builder.history_depth() == depth + 1)
	await _say("undo", {})
	var back: Array = _world.bricks().filter(func(one: BrickWorld.Brick) -> bool:
		return one.transform.is_equal_approx(was))
	_check("...and undone, the plain tile is back where it stood",
		back.size() == 1 and (back[0] as BrickWorld.Brick).part_id == "3068b")
	said = await _say("print_part", {"brick": brick, "sticker": true, "side": "-z", "svg": svg,
		"name": "Probe sticker"})
	var stuck: Dictionary = Stickers.in_model(_world, _library)
	var film: BrickWorld.Brick = null
	for ids: Variant in stuck.values():
		film = _world.get_brick((ids as PackedInt64Array)[0])
	_check("a sticker on the brick's -z face, facing -z: %s" % said.left(90),
		said.begins_with("Stuck") and stuck.size() == 1 and film != null
			and film.transform.basis.y.normalized().is_equal_approx(Vector3.FORWARD))
	said = await _say("print_part", {"brick": brick, "sticker": true, "side": "sideways", "svg": svg})
	_check("a side there is not is refused: %s" % said.left(60), said.begins_with("side is one of"))
	await _decor()


## A picture the person gave in the conversation, handed over as its own
## bytes; the LEGO Group's printed versions of a part; and one of LDraw's
## stickers stuck on a face: each read back off the model.
func _decor() -> void:
	print("── a picture as data, printed versions, LDraw's stickers ──")
	_main.call("clear_model")
	var tile: int = _put("3068b", Vector3(10, 8, 10))
	var was: Transform3D = _world.get_brick(tile).transform
	var photo := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	photo.fill(Color(0.1, 0.4, 0.8))
	photo.fill_rect(Rect2i(8, 8, 24, 48), Color(1.0, 0.85, 0.1))
	var data: String = Marshalls.raw_to_base64(photo.save_png_to_buffer())
	var depth: int = _builder.history_depth()
	var said: String = await _say("print_part", {"brick": tile, "picture_data": data,
		"name": "Probe photo"})
	var printed: BrickWorld.Brick = null
	for one: BrickWorld.Brick in _world.bricks():
		if one.transform.is_equal_approx(was) and not _store.scenery.has(one.id):
			printed = one
	var mesh: Lbm.PartMesh = _library.mesh_for(printed.part_id) if printed != null else null
	_check("picture_data, a PNG as base64, prints on the tile where it stands: %s" % said.left(90),
		printed != null and printed.part_id.begins_with("bw-3068b-p") and mesh != null
			and not mesh.print_files.is_empty() and _builder.history_depth() == depth + 1)
	said = await _say("print_part", {"brick": printed.id if printed != null else tile,
		"picture_data": "data:image/jpeg;base64," + Marshalls.raw_to_base64(
			photo.save_jpg_to_buffer(0.9)), "sticker": true, "side": "up", "name": "Probe jpeg"})
	_check("...and a JPEG as a data: URI, as a sticker on it: %s" % said.left(70),
		said.begins_with("Stuck") and Stickers.in_model(_world, _library).size() == 1)
	said = await _say("print_part", {"brick": printed.id if printed != null else tile,
		"picture_data": Marshalls.raw_to_base64("%PDF-1.7 not a picture".to_ascii_buffer())})
	_check("...a PDF given as data is refused, saying what it is: %s" % said.left(80),
		said.contains("is a PDF"))
	_main.call("clear_model")
	tile = _put("3068b", Vector3(10, 8, 10))
	was = _world.get_brick(tile).transform
	said = await _say("print_part", {"brick": tile})
	_check("no picture, and the answer names the part's printed versions: %s" % said.right(110),
		said.contains("version=") and said.contains("3068b"))
	said = await _say("print_part", {"brick": tile, "versions": "control"})
	var first: RegExMatch = RegEx.create_from_string("\\n  (3068b[a-z0-9]+):").search(said)
	_check("versions=\"control\" lists the control panels the LEGO Group printed on it: %s" % (
		said.split("\n")[0]), first != null and said.contains("version"))
	if first == null:
		return
	depth = _builder.history_depth()
	said = await _say("print_part", {"brick": tile, "version": first.get_string(1)})
	var swapped: BrickWorld.Brick = null
	for one: BrickWorld.Brick in _world.bricks():
		if one.transform.is_equal_approx(was) and not _store.scenery.has(one.id):
			swapped = one
	_check("version= swaps it for %s where it stands, in its colour, one undo: %s" % [
		first.get_string(1), said.left(70)], swapped != null
		and swapped.part_id == first.get_string(1) and swapped.color_code == 7
		and _builder.history_depth() == depth + 1 and said.contains("It is #%d" % swapped.id))
	said = await _say("print_part", {"brick": swapped.id if swapped != null else tile,
		"version": "3001"})
	_check("...a part that is no version of it is refused: %s" % said.left(60),
		said.contains("is not a version"))
	var brick: int = _put("3001", Vector3(100, 24, 10))
	said = await _say("print_part", {"brick": brick, "sticker_part": "003435c", "side": "-z"})
	var film: BrickWorld.Brick = _world.get_brick(_studio_placed())
	_check("sticker_part= sticks LDraw's 003435c on the brick's front, lying on it: %s" % said.left(80),
		film != null and film.part_id == "003435c" and film.color_code == Stickers.FILM
			and film.transform.basis.y.normalized().is_equal_approx(Vector3.FORWARD)
			and Stickers.stuck_to(_world, _library, film.id) == PackedInt64Array([brick]))


func _studio_placed() -> int:
	return (_main.get("_studio") as PrintStudio).last_placed


## One copy of a sub-assembly cut loose from the others.
func _unique() -> void:
	print("── a copy made unique ──")
	_main.call("clear_model")
	var one: int = _put("3001", Vector3(0, 24, 0), Basis.IDENTITY, "Wheel#1")
	var two: int = _put("3001", Vector3(80, 24, 0), Basis.IDENTITY, "Wheel#2")
	var said: String = await _say("make_unique", {"assembly": "Axle"})
	_check("an assembly there is not is refused, with those there are: %s" % said.left(60),
		said.begins_with("No sub-assembly Axle") and said.contains("Wheel#2"))
	var depth: int = _builder.history_depth()
	said = await _say("make_unique", {"assembly": "Wheel (copy 2)"})
	var fresh: String = Assemblies.path_of(_world.get_brick(two))
	var assemblies: Assemblies = (_main.get("_shell") as Shell).assemblies
	_check("copy 2 of the wheel is a sub-assembly of its own: %s" % said.left(90),
		said.contains("of its own now") and Assemblies.definition(Assemblies.leaf(fresh)) != "Wheel"
			and assemblies.copies_of(fresh).is_empty())
	_check("...the other copy as it was, and one undo step",
		Assemblies.path_of(_world.get_brick(one)) == "Wheel#1" and _builder.history_depth() == depth + 1)
	said = await _say("make_unique", {"brick": one})
	_check("a part in a copy with no others is refused: %s" % said.left(60),
		said.contains("no sub-assembly with other copies"))
	await _say("undo", {})
	_check("undone, they are copies again", Assemblies.path_of(_world.get_brick(two)) == "Wheel#2")
	said = await _say("make_unique", {"brick": two})
	_check("...and a copy named by a part in it: %s" % said.left(60), said.contains("of its own now"))


## A web server for one probe: GET a path in [member files], answered whole.
class _Files extends Node:
	var files: Dictionary = {}
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(8931, 8999):
			if _server.listen(wanted, "127.0.0.1") == OK:
				port = wanted
				return

	func _process(_delta: float) -> void:
		while _server.is_connection_available():
			_peers.append([_server.take_connection(), PackedByteArray()])
		for held: Array in _peers.duplicate():
			var peer: StreamPeerTCP = held[0]
			peer.poll()
			if peer.get_available_bytes() > 0:
				held[1] = (held[1] as PackedByteArray) + (peer.get_data(peer.get_available_bytes())[1] as PackedByteArray)
			var said: String = (held[1] as PackedByteArray).get_string_from_utf8()
			if not said.contains("\r\n\r\n"):
				continue
			var path: String = said.get_slice(" ", 1)
			var body: PackedByteArray = files.get(path, PackedByteArray())
			var head: String = "HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
				"200 OK" if files.has(path) else "404 Not Found", body.size()]
			peer.put_data(head.to_utf8_buffer())
			peer.put_data(body)
			peer.disconnect_from_host()
			_peers.erase(held)

	func _exit_tree() -> void:
		_server.stop()


# -- helpers ------------------------------------------------------------------------


func _put(part: String, at: Vector3, basis: Basis = Basis.IDENTITY, path: String = "") -> int:
	var where := Transform3D(basis, at)
	var brick_id: int = _world.add_brick(part, 7, where)
	_builder.register(brick_id, part, where)
	if not path.is_empty():
		_world.get_brick(brick_id).unit = path
		_world.get_brick(brick_id).group = Assemblies.group_of(path)
	return brick_id


func _model_ids() -> Array[int]:
	var ids: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


## A tool's answer as text, called as the connector calls it: a job's
## answer once it is done, when the call answered with a job.
func _say(tool: String, arguments: Dictionary) -> String:
	return _text(await _finished(await _rpc("tools/call", {"name": tool, "arguments": arguments})))


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


## The job number a call answered with, or 0 when it answered outright.
static func _job_of(result: Dictionary) -> int:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	return int(found.get_string(1)) if found != null else 0


## [param result], or when it is a job, the job's answer once it ends, polled
## as a session polls it, without the job's own first line. "job" holds
## what job last said.
func _finished(result: Dictionary) -> Dictionary:
	var id: int = _job_of(result)
	if id == 0:
		return result
	for _n: int in 90:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments": {"id": id}})
		var said: String = _text(polled)
		if said.contains(" is still going"):
			continue
		var blocks: Array = (polled.get("content", []) as Array).duplicate()
		# The job's own line, then the work's answer: in the same text, or
		# the blocks after it when the answer has a picture.
		var first: String = str((blocks[0] as Dictionary).get("text", ""))
		if blocks.size() > 1:
			blocks.pop_front()
		elif first.contains("\n"):
			blocks[0] = {"type": "text", "text": first.substr(first.find("\n") + 1)}
		return {"content": blocks, "job": said}
	return {"content": [{"type": "text", "text": "job %d never ended" % id}]}


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("a session can do what the person does from the menus")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
