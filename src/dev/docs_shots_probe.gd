## The documentation's pictures of the app, taken off the real window as
## docs-site/pictures/<page>.json sets each one up, for tools/docs_shots.py to make
## docs-site/img/ of. Every picture is taken in a Brickworks of its own:
## this run starts one window a picture (the same engine, the same
## display, the GPU lease it holds), with an app data folder of its own,
## so a picture is the same whatever is taken before it or beside it, and
## one taken alone (--only) is the one the whole run takes.
##
##   tools/probe.sh docs_shots_probe -- --out=DIR [--only=ID,ID] [--manifest=FILE]
##   godot --path . --resolution 1400x900 --script src/dev/docs_shots_probe.gd -- --out=DIR
##
## In each window: the app as a person meets it, through the sign-in screen
## (gate_for_probe) and let in as an account with a fixed address, offline
## (the deployment a port nobody answers, as gate_probe's first half), the
## example car on the baseplate and its build stopped; then the picture's
## steps, as a person's keys, clicks and the menus' commands; then the
## window read until two reads a few frames apart are the same pixels (a
## field's caret held still, the pointer off everything), cut to what the
## picture shows, marked where it says, and written as DIR/<id>.png, with
## DIR/<id>.json saying what was taken.
##
## A step names what it acts on by a path from the app (Main): `_bin`, a
## member; `_shell.bar`, a member's member; `#Search`, a node of that name
## under it; `@focus`, the control with the keyboard. Steps:
##   {"open": "res://models/car.ldr"}       a model, opened as File, Open does
##   {"run": "settings"}                    a menu command, by its name
##   {"key": "Ctrl+Shift+Z"}                a key, as a person presses it
##   {"type": "hinge"}                      words typed into whatever has the keys
##   {"mouse": [x, y]} / {"click": [x, y]}  the pointer, in the window's pixels;
##   {"click": "path"}                      or the middle of a control,
##   {"click": {"part": "3001"}}            or the top of a part
##   {"right_click": ...}                   the same with the other button
##   {"drag": "path", "from": [0.2, 0.3], "to": [0.6, 0.7]}  the left button held
##                                          from one point to another of a control,
##                                          each a share of its width and height
##   {"over": {"part": "3001", "nth": 0, "lift": 1}}  the pointer over a part
##                                          (lift: plates above its top),
##   {"over": {"at": [0, 0, 0]}}            or a point in the model (LDU)
##   {"select": {"part": "3001", "colour": 4} | "all" | [n, ...]}
##   {"call": "path.method", "args": [...]} {"set": "path.property", "value": v}
##                                          ("optional": true: passed over where the
##                                          path names nothing, as My Claude, there
##                                          only where Claude Code is installed)
##   {"take": {"part": "3001", "colour": 4}} a part into hand, as its tile in the bin
##   {"assistant": true}                    the assistant shown (Settings)
##   {"saved": [{"name": "Red car", "from": "res://models/car.ldr",
##     "at": "2026-10-04T10:12:00", "versions": [{"at": "...", "parts": 20}]}]}
##                                          models saved here before, at fixed
##                                          times (_seed_saved)
##   {"frames": 30}
##   {"until": "path.property", "is": v, "frames": 600}   waits for it, at most so long
## What the server answers, the app's own code drawing it as the site's
## pictures are their pages with their server's answers: "answers"
## ({"fetch": {"code": 200, "body": {...}}, "publish": {...}}; a fetch's
## "model_file" is read into its body's model), and "view": an id, the app
## opened as that link (/app?view=<id>), its model the answer to fetch.
## Each starts as someone who has been here before (Build your first model
## skipped, the offer of the assistant closed) unless "first_visit": true.
## And the picture: "crop" ("window", a path, "@opened" for the panel or
## window the setup put in sight, "@pointer" for where a step left the
## pointer (with "pad", a square round it), [x, y, w, h], or a list of
## those, joined), "pad" (pixels round a crop), "tooltip" (true: a tooltip
## up is the point; otherwise one fails the picture), "marks" ([{"at": path,
## "n": 1}]: an outline and a numbered disc drawn over the window, in the
## app's own font), "width" (made smaller to at most this), "window"
## ("390x844": the window's size), "phone" (true: the phone's layout, as a
## browser that small has it, at a browser's scale, as --phone probes do).
## Or, in place of the window, what an assistant is shown: "tool"
## ({"name": "view_board", "arguments": {...}}) is that call made once the
## setup is done, as the connector makes it (CommandSocket.answer_rpc), and
## the picture it answers with is the picture ("crop" then cuts that). The
## pages about AI say what the AI sees, and this is it, not a copy of it.
extends SceneTree

## A page's pictures are a file of their own: docs-site/pictures/<page>.json.
const MANIFEST := "res://docs-site/pictures"
## How long one window may take, its start included, before it is ended.
const SECONDS_A_PICTURE := 180
## The pixels two reads must agree on, at most this many reads.
const SETTLE_READS := 12
## What a picture's own window is told, in its environment.
const ONE := "BRICKWORKS_DOCS_SHOT"
const ONE_OUT := "BRICKWORKS_DOCS_SHOT_OUT"
const ONE_MANIFEST := "BRICKWORKS_DOCS_SHOT_MANIFEST"

var _out: String = ""
var _manifest: String = MANIFEST
var _main: Node
var _shell: Shell


## The server, as the picture's "answers" say: what a link opens with and
## what Publish is told; the rest as nobody's server would answer.
class Answered extends SharedModels:
	var said: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return said.get("fetch", {"code": 404, "body": {"error": "no such link"}})

	func publish(_token: String, _body: Dictionary) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return said.get("publish", {"code": 503, "body": {"error": "no answer given"}})

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": true}}}
var _failed: PackedStringArray = PackedStringArray()
## The panels and windows in sight before the setup (the "@opened" crop).
var _shown_before: Dictionary = {}
## A step put the pointer where the picture wants it (a part in hand follows it).
var _pointer_placed: bool = false
## Where, in the window's pixels (the "@pointer" crop).
var _pointer_at: Vector2 = Vector2.INF


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	# A picture's own window is told which picture by its environment, not
	# its arguments: the app reads its own (--out= is its export), and a
	# window here must start as a person's does, with none.
	var one: String = OS.get_environment(ONE)
	if not one.is_empty():
		_out = OS.get_environment(ONE_OUT)
		_manifest = OS.get_environment(ONE_MANIFEST)
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args() if one.is_empty() else PackedStringArray():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",", false)
		elif arg.begins_with("--manifest="):
			_manifest = arg.substr(11)
	if _out.is_empty():
		print("docs shots probe FAIL: no --out=DIR")
		quit(2)
		return
	if not _out.begins_with("/"):
		_out = ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(_out)
	if DisplayServer.get_name() == "headless":
		print("  no rendering device: these pictures need a window")
		quit(1)
		return
	var shots: Array = _shots()
	if shots.is_empty():
		print("docs shots probe FAIL: %s names no picture of the app" % _manifest)
		quit(1)
		return
	if one.is_empty():
		await _every(shots, only)
	else:
		var found: Array = shots.filter(func(s: Dictionary) -> bool: return s["id"] == one)
		if found.is_empty():
			print("docs shots probe FAIL: no picture %s in %s" % [one, _manifest])
			quit(1)
			return
		await _take(found[0])


## The manifest's pictures of the app: every page's file in a folder, or one file.
func _shots() -> Array:
	var path: String = _manifest if _manifest.begins_with("/") or _manifest.begins_with("res://") \
		else ProjectSettings.globalize_path("res://").path_join(_manifest)
	var files: PackedStringArray = PackedStringArray()
	if DirAccess.dir_exists_absolute(path):
		var names: PackedStringArray = DirAccess.get_files_at(path)
		names.sort()
		for name: String in names:
			if name.ends_with(".json"):
				files.append(path.path_join(name))
	else:
		files.append(path)
	var out: Array = []
	for file: String in files:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary:
			print("docs shots probe FAIL: %s is not a manifest" % file)
			continue
		for shot: Variant in (parsed as Dictionary).get("shots", []):
			if shot is Dictionary and str(shot.get("source", "")) == "app":
				out.append(shot)
	return out


# -- the run: a window a picture -------------------------------------------------


func _every(shots: Array, only: PackedStringArray) -> void:
	var engine: PackedStringArray = PackedStringArray()
	var given: PackedStringArray = OS.get_cmdline_args()
	for i: int in given.size():
		if given[i] in ["--rendering-method", "--rendering-driver"] and i + 1 < given.size():
			engine.append_array([given[i], given[i + 1]])
	var size: Vector2i = DisplayServer.window_get_size()
	var taken: int = 0
	var bad: PackedStringArray = PackedStringArray()
	var started: int = Time.get_ticks_msec()
	for shot: Dictionary in shots:
		var id: String = shot["id"]
		if not only.is_empty() and not only.has(id):
			continue
		var at: Vector2i = _size_of(shot, size)
		var data: String = _out.path_join(".data").path_join(id)
		DirAccess.make_dir_recursive_absolute(data)
		OS.set_environment("XDG_DATA_HOME", data)
		OS.set_environment(ONE, id)
		OS.set_environment(ONE_OUT, _out)
		OS.set_environment(ONE_MANIFEST, _manifest)
		DirAccess.remove_absolute(_out.path_join(id + ".json"))
		var args: PackedStringArray = PackedStringArray(["--path", ProjectSettings.globalize_path("res://")])
		args.append_array(engine)
		args.append_array(["--resolution", "%dx%d" % [at.x, at.y],
			"--script", "res://src/dev/docs_shots_probe.gd"])
		var began: int = Time.get_ticks_msec()
		var pid: int = OS.create_process(OS.get_executable_path(), args)
		if pid <= 0:
			bad.append(id)
			print("  FAIL  %s: its window would not start" % id)
			continue
		while OS.is_process_running(pid):
			if Time.get_ticks_msec() - began > (SECONDS_A_PICTURE + 30) * 1000:
				OS.kill(pid)
				break
			OS.delay_msec(250)
		var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(_out.path_join(id + ".json")))
		if said is Dictionary and bool(said.get("ok", false)):
			taken += 1
			print("  ok    %s: %dx%d, %s, in %.1f s%s" % [id, int(said["width"]), int(said["height"]),
				str(said["sha256"]).left(12), (Time.get_ticks_msec() - began) / 1000.0,
				"" if bool(said.get("settled", false)) else " (never read the same twice: it moves)"])
		else:
			bad.append(id)
			print("  FAIL  %s: %s" % [id, str(said.get("why", "no picture")) if said is Dictionary
				else "its window ended without a picture"])
		_remove_tree(data)
	_remove_tree(_out.path_join(".data"))
	print("")
	print("docs shots probe: %d picture(s) taken in %.0f s%s" % [taken, (Time.get_ticks_msec() - started) / 1000.0,
		"" if bad.is_empty() else ", %d FAILED: %s" % [bad.size(), ", ".join(bad)]])
	quit(0 if bad.is_empty() and taken > 0 else 1)


func _size_of(shot: Dictionary, fallback: Vector2i) -> Vector2i:
	var words: String = str(shot.get("window", ""))
	var parts: PackedStringArray = words.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return fallback


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for name: String in dir.get_directories():
		_remove_tree(path.path_join(name))
	for name: String in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(path)


# -- one window, one picture ------------------------------------------------------


func _take(shot: Dictionary) -> void:
	var id: String = shot["id"]
	create_timer(SECONDS_A_PICTURE).timeout.connect(func() -> void:
		_say(id, {"ok": false, "why": "not taken in %d s" % SECONDS_A_PICTURE})
		quit(1))
	# Frames at a person's pace, so a step's frames are its time too: what
	# fades or slides in by the clock has done so when the picture is read.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	# Offline, as gate_probe's first half: nothing in a picture is the day's.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	# The phone's layout is a browser's alone (Phone._wanted); a desktop
	# window as small as a phone is laid out for one only when told, as
	# open_menu_reach_probe's --phone does.
	var phone: bool = bool(shot.get("phone", false))
	if phone:
		Phone._on = 1
		Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	var viewing: String = str(shot.get("view", ""))
	if shot.has("answers") or not viewing.is_empty():
		var server := Answered.new()
		server.said = (shot.get("answers", {}) as Dictionary).duplicate(true)
		var fetched: Variant = server.said.get("fetch")
		if fetched is Dictionary and (fetched as Dictionary).has("model_file"):
			var body: Dictionary = (fetched as Dictionary).get("body", {})
			body["model"] = FileAccess.get_file_as_string(str(fetched["model_file"]))
			fetched["body"] = body
		_main.set("_shared", server)
	if not viewing.is_empty():
		_main.set("_viewing", viewing)
	root.add_child(_main)
	var world: BrickWorld = null
	for _n: int in 1800 if not viewing.is_empty() else 900:
		await process_frame
		world = _main.get("_world")
		_shell = _main.get("_shell")
		var view: Variant = _main.get("_share_view")
		if not viewing.is_empty():
			if view != null and str((view as Object).get("state")) in ["ready", "failed", "gone"]:
				break
		elif world != null and world.brick_count() > 1 and _shell != null and _main.get("_bin") != null:
			break
	if not viewing.is_empty():
		var view: Variant = _main.get("_share_view")
		if view == null or str((view as Object).get("state")) != "ready":
			_say(id, {"ok": false, "why": "the link %s did not open (%s)" % [viewing,
				str((view as Object).get("state")) if view != null else "no viewer"]})
			quit(1)
			return
	elif world == null or world.brick_count() <= 1:
		_say(id, {"ok": false, "why": "no model came up on the baseplate"})
		quit(1)
		return
	_stop_playback()
	if phone:
		_hold_phone_scale()
	await _let_in()
	await _frames(20)
	# Someone who has been here before: Build your first model skipped and
	# the offer of the assistant closed, as their buttons do, unless the
	# picture is of a first visit.
	if not bool(shot.get("first_visit", false)):
		if _shell != null and _shell.first_build != null:
			_press(_shell.first_build.get("_skip"))
		_press(_main.get("_offer_close"))
		await _frames(10)
	# The pointer off the window, as a person's is while the window is read:
	# nothing hovered unless a step puts it there.
	_away()
	await _frames(4)
	_shown_before = _panels_shown()
	for step: Variant in shot.get("setup", []):
		if not step is Dictionary:
			_failed.append("a step that is not an object: %s" % str(step))
			continue
		await _do(step)
		await _frames(int(step.get("after", 6)))
	await _frames(int(shot.get("settle", 30)))
	# The pointer off everything again, unless a step put it somewhere to be
	# seen (a part in hand follows it): parts-bin-shelves had the search's
	# tooltip over its shelves, from a pointer the setup never moved. And a
	# tooltip still up is a failure, never a picture, unless it is the point.
	var tooltip: bool = bool(shot.get("tooltip", false))
	if not _pointer_placed and not tooltip:
		_away()
		await _frames(6)
	var tip: String = _tooltip_up(root)
	if not tip.is_empty() and not tooltip:
		_failed.append("a tooltip was up: %s" % tip.left(80))
	var gate: Variant = _main.get("_gate")
	if gate is CanvasItem and (gate as CanvasItem).is_visible_in_tree():
		_failed.append("the sign-in screen was over the window when it was to be read")
	if not _failed.is_empty():
		_say(id, {"ok": false, "why": "; ".join(_failed)})
		quit(1)
		return
	_hold_still()
	await _frames(4)
	var picture: Image = null
	var settled: bool = false
	var reads: int = 0
	var last: PackedByteArray = PackedByteArray()
	if shot.has("tool"):
		picture = await _answered_with(shot["tool"])
		if picture == null:
			_say(id, {"ok": false, "why": "; ".join(_failed)})
			quit(1)
			return
		settled = true
		reads = SETTLE_READS
	while reads < SETTLE_READS:
		reads += 1
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
		var now: PackedByteArray = picture.get_data()
		if now == last:
			settled = true
			break
		last = now
		await _frames(6)
	var marks: Array = shot.get("marks", [])
	if not marks.is_empty():
		_mark(marks)
		await _frames(3)
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
	var rect: Variant = _crop(shot.get("crop", "window"), int(shot.get("pad", 0)), picture.get_size())
	if rect == null:
		_say(id, {"ok": false, "why": "; ".join(_failed)})
		quit(1)
		return
	var cut: Image = picture.get_region(rect as Rect2i)
	cut.convert(Image.FORMAT_RGB8)
	var widest: int = int(shot.get("width", 0))
	if widest > 0 and cut.get_width() > widest:
		cut.resize(widest, roundi(cut.get_height() * float(widest) / cut.get_width()), Image.INTERPOLATE_LANCZOS)
	var file: String = _out.path_join(id + ".png")
	if cut.save_png(file) != OK:
		_say(id, {"ok": false, "why": "could not write %s" % file})
		quit(1)
		return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(cut.get_data())
	_say(id, {"ok": true, "width": cut.get_width(), "height": cut.get_height(), "settled": settled,
		"reads": reads, "sha256": hash.finish().hex_encode(), "crop": [rect.position.x, rect.position.y,
		rect.size.x, rect.size.y]})
	_main.queue_free()
	await process_frame
	quit(0)


## A phone draws at a browser's scale (Main.screen_factor, web), where a
## desktop window draws its layout half as big, which no phone does: held
## there, with the phone layout's own look at the window's density stopped
## (open_menu_reach_probe).
func _hold_phone_scale() -> void:
	var layout: Variant = _main.get("_phone")
	if layout is Node:
		(layout as Node).set_process(false)
	else:
		_failed.append("the phone's layout was asked for and is not in the window")
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
		ShellPrefs.interface_size(), true)


## The picture [param call] ({"name", "arguments"}) is answered with, made
## as the connector makes a session's call; null, and why in _failed, when
## it answers without one. Waited for whole: a call slower than a job's
## threshold would answer "Started job N" in place of its picture.
func _answered_with(call: Variant) -> Image:
	var asked: Dictionary = call if call is Dictionary else {"name": str(call)}
	var connector: Variant = _main.get("_connector")
	var rpc: Node = (connector as Object).get("rpc") if connector is Object else null
	if rpc == null:
		_failed.append("no session's call is answered here: a step {\"assistant\": true} first")
		return null
	var jobs: Variant = rpc.get("jobs")
	if jobs is Object:
		(jobs as Object).set("after_s", float(SECONDS_A_PICTURE))
	var got: Variant = await rpc.answer_rpc({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
		"params": {"name": str(asked.get("name", "")), "arguments": asked.get("arguments", {})}})
	var result: Dictionary = (got as Dictionary).get("result", {}) if got is Dictionary else {}
	var said := PackedStringArray()
	for block: Variant in result.get("content", []):
		var one: Dictionary = block if block is Dictionary else {}
		if str(one.get("type", "")) != "image":
			said.append(str(one.get("text", "")).left(160))
			continue
		var bytes: PackedByteArray = Marshalls.base64_to_raw(str(one.get("data", "")))
		var picture := Image.new()
		var kind: String = str(one.get("mimeType", "image/png"))
		var loaded: int = picture.load_jpg_from_buffer(bytes) if kind == "image/jpeg" \
			else picture.load_webp_from_buffer(bytes) if kind == "image/webp" \
			else picture.load_png_from_buffer(bytes)
		if loaded == OK and not picture.is_empty():
			return picture
		_failed.append("%s answered with a %s picture that would not load" % [asked.get("name", ""), kind])
		return null
	_failed.append("%s answered with no picture: %s" % [asked.get("name", ""), " / ".join(said)])
	return null


## What a click on a button in sight does.
func _press(button: Variant) -> void:
	if button is BaseButton and (button as BaseButton).is_visible_in_tree():
		(button as BaseButton).pressed.emit()


func _say(id: String, what: Dictionary) -> void:
	what["id"] = id
	var file := FileAccess.open(_out.path_join(id + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(what, "\t") + "\n")
		file.close()
	if not bool(what.get("ok", false)):
		print("docs shots probe FAIL: %s: %s" % [id, what.get("why", "")])


func _stop_playback() -> void:
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()


## Through the sign-in screen as somebody is let in (gate_probe): an account
## with a fixed address and a session that needs no renewing. Only once the
## account has its answer from the deployment nobody answers (three tries,
## about 20 s, as gate_probe waits): let in before, its start-up check ended
## after and put the sign-in screen back over the window, so a picture taken
## late in its window came out dimmed under it (connect-your-ai, 11-09).
func _let_in() -> void:
	var account: Account = _main.get("_account")
	if account == null:
		return
	if account.deployment != null and not account.deployment.finished:
		await account.deployment.wait()
	for _n: int in 600:
		if account.state != Account.State.CHECKING and not account.renewing:
			break
		await process_frame
	if account.state == Account.State.CHECKING:
		_failed.append("the account was still asking who is here after 10 s")
	account.email = "you@example.com"
	account._access = "docs.shots.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 36000.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(10)
	var gate: Variant = _main.get("_gate")
	if gate is CanvasItem and (gate as CanvasItem).visible:
		_failed.append("the sign-in screen stayed up once signed in")


# -- steps ---------------------------------------------------------------------------


func _do(step: Dictionary) -> void:
	if step.has("open"):
		var placed: int = int(_main.call("_open", str(step["open"])))
		if placed <= 0:
			_failed.append("%s opened no parts" % step["open"])
		for _n: int in 600:
			await process_frame
			if not _loading():
				break
		_stop_playback()
	elif step.has("run"):
		var name: String = step["run"]
		if _shell.command(name) == null:
			_failed.append("no command %s" % name)
		elif not _shell.run(name):
			_failed.append("%s cannot be run now: %s" % [name, _shell.why_not(name)])
		await _frames(10)
	elif step.has("key"):
		await _key(str(step["key"]))
	elif step.has("type"):
		for c: String in str(step["type"]):
			var down := InputEventKey.new()
			down.pressed = true
			down.unicode = c.unicode_at(0)
			down.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			Input.parse_input_event(down)
			await process_frame
			var up: InputEventKey = down.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			await process_frame
	elif step.has("mouse"):
		var at: Variant = _point(step["mouse"])
		if at != null:
			_move(at)
			_pointer_placed = true
	elif step.has("click") or step.has("right_click"):
		var right: bool = step.has("right_click")
		var at: Variant = _point(step["right_click"] if right else step["click"])
		if at != null:
			await _click(at, MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT, int(step.get("times", 1)))
	elif step.has("drag"):
		var rect: Variant = _rect_of(str(step["drag"]))
		if rect != null:
			var box: Rect2 = rect
			var from: Array = step.get("from", [0.25, 0.25])
			var to: Array = step.get("to", [0.75, 0.75])
			await _drag(box.position + box.size * Vector2(float(from[0]), float(from[1])),
				box.position + box.size * Vector2(float(to[0]), float(to[1])))
	elif step.has("over"):
		var at: Variant = _over(step["over"])
		if at != null:
			_move(at)
			_pointer_placed = true
	elif step.has("select"):
		_select(step["select"])
	elif step.has("call"):
		var path: String = step["call"]
		var target: Variant = _node(path.get_basename()) if path.contains(".") else _main
		var method: String = path.get_extension() if path.contains(".") else path
		if target == null or not (target as Object).has_method(method):
			_failed.append("nothing to call at %s" % path)
		else:
			var result: Variant = (target as Object).callv(method, step.get("args", []))
			if result is Signal:
				await result
	elif step.has("set"):
		var path: String = step["set"]
		var target: Variant = _node(path.get_basename())
		if target == null and not bool(step.get("optional", false)):
			_failed.append("nothing at %s" % path.get_basename())
		elif target != null:
			(target as Object).set(path.get_extension(), step["value"])
	elif step.has("take"):
		# What a click on the part's tile in the bin sends, in its colour.
		var bin: PartsBin = _main.get("_bin")
		var taken: Dictionary = step["take"] if step["take"] is Dictionary else {"part": str(step["take"])}
		if taken.has("colour"):
			bin.color_chosen.emit(int(taken["colour"]))
		bin.part_chosen.emit(str(taken["part"]))
	elif step.has("assistant"):
		# As Settings' "Show the assistant" does: on, remembered, its column open.
		_main.call("set_assistant", bool(step["assistant"]))
	elif step.has("saved"):
		_seed_saved(step["saved"])
	elif step.has("frames"):
		await _frames(int(step["frames"]))
	elif step.has("until"):
		var path: String = step["until"]
		var waited: int = 0
		while waited < int(step.get("frames", 600)):
			var target: Variant = _node(path.get_basename())
			if target != null and (target as Object).get(path.get_extension()) == step.get("is"):
				break
			await process_frame
			waited += 1
		var at: Variant = _node(path.get_basename())
		if at == null or (at as Object).get(path.get_extension()) != step.get("is"):
			_failed.append("%s was never %s" % [path, str(step.get("is"))])
	else:
		_failed.append("a step this probe does not know: %s" % JSON.stringify(step))


## Whether the model is still coming in: parts still being drawn in.
func _loading() -> bool:
	var world: BrickWorld = _main.get("_world")
	return world != null and world.has_method("loading") and bool(world.call("loading"))


## Models saved here before the picture, each at a fixed time. File, Open
## and File, Versions… say when each was saved ("today at 14:05:09"), so a
## save made by a step would put the clock in the picture, and every run
## would make it again. Each is written as Save leaves one: its file in
## ModelStore.SAVE_DIR, last changed at "at" (as this computer's clock says
## it), and its saves kept as ModelVersions keeps them, named for their
## times: each of "versions" with the model's first "parts" parts, older
## first, then the model whole at "at", its last save.
func _seed_saved(models: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	for model: Dictionary in models:
		var name: String = str(model.get("name", ""))
		var text: String = FileAccess.get_file_as_string(str(model.get("from", "")))
		if name.is_empty() or text.is_empty():
			_failed.append("no model to save as %s from %s" % [name, model.get("from", "")])
			continue
		# Called by its name, as Save writes it: its first line, then Name:.
		var lines: PackedStringArray = text.split("\n")
		for n: int in mini(lines.size(), 2):
			if lines[n].begins_with("0 Name:"):
				lines[n] = "0 Name: %s.ldr" % name
			elif n == 0 and lines[n].begins_with("0 ") and not lines[n].contains(":"):
				lines[n] = "0 " + name
		text = "\n".join(lines)
		var saves: Array = []
		for version: Dictionary in model.get("versions", []):
			saves.append([_clock(str(version.get("at", ""))), _first_parts(text, int(version.get("parts", 0)))])
		saves.append([_clock(str(model.get("at", ""))), text])
		DirAccess.make_dir_recursive_absolute(ModelVersions.folder(name))
		for save: Array in saves:
			if int(save[0]) <= 0:
				_failed.append("%s: a save's time is not a date and time" % name)
				return
			var packed: PackedByteArray = str(save[1]).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
			var kept := FileAccess.open(ModelVersions.folder(name) + "%013d-%d-%d.ldr.gz" % [
				int(save[0]) * 1000, ModelStore.count_in(str(save[1])), packed.size()], FileAccess.WRITE)
			kept.store_buffer(packed)
			kept.close()
		var path: String = ModelStore.SAVE_DIR + name + ".ldr"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		# Godot sets no file's time; the system's touch does (a probe runs on Linux).
		if OS.execute("touch", ["-m", "-d", "@%d" % int(saves[-1][0]), ProjectSettings.globalize_path(path)]) != 0:
			_failed.append("could not date %s" % path)


## [param at], "2026-10-04T10:12:00", as the Unix seconds this computer's
## clock says it at (ModelVersions.when_saved adds the zone back); 0 when
## it is not a date and time.
func _clock(at: String) -> int:
	if at.length() < 19:
		return 0
	return Time.get_unix_time_from_datetime_string(at) \
		- int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## [param text] with only its first [param count] parts (its other lines
## kept): an earlier save of the model.
func _first_parts(text: String, count: int) -> String:
	var out: PackedStringArray = []
	var parts: int = 0
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("1 "):
			parts += 1
			if parts > count:
				continue
		out.append(line)
	return "\n".join(out)


## [param words] as a key: "Ctrl+Shift+Z", "F1", "Escape", "[".
func _key(words: String) -> void:
	var event := InputEventKey.new()
	var parts: PackedStringArray = words.split("+", false) if words.length() > 1 else PackedStringArray([words])
	if words.ends_with("++"):
		parts.append("+")
	for part: String in parts.slice(0, parts.size() - 1):
		match part.to_lower():
			"ctrl": event.ctrl_pressed = true
			"shift": event.shift_pressed = true
			"alt": event.alt_pressed = true
			"meta", "cmd": event.meta_pressed = true
	var last: String = parts[parts.size() - 1]
	var code: Key = OS.find_keycode_from_string(last)
	if code == KEY_NONE and last.length() == 1:
		code = OS.find_keycode_from_string(last.to_upper())
	if code == KEY_NONE:
		_failed.append("no key %s" % words)
		return
	event.keycode = code
	event.physical_keycode = code
	if last.length() == 1 and not event.ctrl_pressed and not event.alt_pressed:
		event.unicode = (last.to_upper() if event.shift_pressed else last.to_lower()).unicode_at(0)
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var up: InputEventKey = event.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)


## A point in the window's pixels: [x, y], or the middle of what a path names.
func _point(given: Variant) -> Variant:
	if given is Array and (given as Array).size() == 2:
		return Vector2(float(given[0]), float(given[1]))
	if given is String:
		var rect: Variant = _rect_of(given)
		if rect != null:
			return (rect as Rect2).get_center()
	if given is Dictionary:
		return _over(given)
	_failed.append("no point at %s" % str(given))
	return null


func _move(at: Vector2) -> void:
	_pointer_at = at
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)


func _click(at: Vector2, button: MouseButton, times: int) -> void:
	_move(at)
	await _frames(3)
	for n: int in times:
		var press := InputEventMouseButton.new()
		press.button_index = button
		press.position = at
		press.global_position = at
		press.pressed = true
		press.double_click = n == 1
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(press)
		await process_frame
		var release: InputEventMouseButton = press.duplicate()
		release.pressed = false
		release.button_mask = 0
		Input.parse_input_event(release)
		await _frames(2)
	await _frames(4)


## The left button pressed at [param from], the pointer carried to [param to]
## in a few moves, as a hand does, and let go there.
func _drag(from: Vector2, to: Vector2) -> void:
	_move(from)
	await _frames(3)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = from
	press.global_position = from
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(press)
	await process_frame
	for n: int in range(1, 9):
		var at: Vector2 = from.lerp(to, n / 8.0)
		_pointer_at = at
		Input.warp_mouse(at)
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await process_frame
	var release: InputEventMouseButton = press.duplicate()
	release.position = to
	release.global_position = to
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	await _frames(4)


## The window's pixel over a part of the model ({"part", "colour", "nth",
## "lift": plates over its top}).
func _over(given: Variant) -> Variant:
	var camera: CadCamera = _main.get("_camera")
	if given is Dictionary and (given as Dictionary).has("at"):
		# A point in the model, in LDraw units (-Y up): the floor's middle is [0, 0, 0].
		var at: Array = given["at"]
		return root.get_final_transform() * camera.screen_of(Vector3(float(at[0]), float(at[1]), float(at[2])))
	var found: Array = _bricks(given)
	if found.is_empty():
		_failed.append("no part like %s to point at" % JSON.stringify(given))
		return null
	var brick: BrickWorld.Brick = found[0]
	var world: BrickWorld = _main.get("_world")
	var box: AABB = (world.library.parts[brick.part_id] as PartLibrary.PartInfo).bounds \
		if world.library.parts.has(brick.part_id) else AABB()
	# LDraw's up is -Y: the top of a part is its bounds' least Y.
	var top: Vector3 = brick.transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var lift: float = float((given as Dictionary).get("lift", 0)) if given is Dictionary else 0.0
	top.y -= lift * 8.0
	return root.get_final_transform() * camera.screen_of(top)


## The model's parts a step names, in the model's own order.
func _bricks(given: Variant) -> Array:
	var world: BrickWorld = _main.get("_world")
	var all: Array = world.bricks()
	all.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	if given is String and given == "all":
		return all
	if given is Array:
		var picked: Array = []
		for n: Variant in given:
			if int(n) >= 0 and int(n) < all.size():
				picked.append(all[int(n)])
		return picked
	if given is Dictionary:
		var want: Dictionary = given
		var out: Array = all.filter(func(b: BrickWorld.Brick) -> bool:
			return (not want.has("part") or b.part_id.get_basename() == str(want["part"]).get_basename()) \
				and (not want.has("colour") or b.color_code == int(want["colour"])))
		if want.has("nth"):
			var n: int = int(want["nth"])
			return [out[n]] if n >= 0 and n < out.size() else []
		return out
	return []


func _select(given: Variant) -> void:
	var found: Array = _bricks(given)
	if found.is_empty():
		_failed.append("nothing to select like %s" % JSON.stringify(given))
		return
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.select_found(found.map(func(b: BrickWorld.Brick) -> int: return b.id))


## What a path names, from the app: `_bin`, `_shell.bar`, `#Name` (a node of
## that name under what came before), `@focus`.
func _node(path: String) -> Variant:
	var at: Variant = _main
	for part: String in path.split(".", false):
		if at == null:
			return null
		if part == "@focus":
			at = root.gui_get_focus_owner()
		elif part.begins_with("#"):
			at = (at as Node).find_child(part.substr(1), true, false) if at is Node else null
		elif part.is_valid_int() and at is Array:
			var n: int = part.to_int()
			at = (at as Array)[n] if n >= 0 and n < (at as Array).size() else null
		elif at is Object:
			at = (at as Object).get(part)
		else:
			return null
	return at


## Where a path's control or window is, in the window's pixels.
func _rect_of(path: String) -> Variant:
	var found: Variant = _node(path)
	if not (found is Control or found is Window):
		_failed.append("nothing to frame at %s" % path)
		return null
	var rect: Variant = _rect_of_node(found)
	if rect == null:
		_failed.append("%s is not shown" % path)
	return rect


## A control's or a window's rectangle in the window's pixels; null when it
## is not in sight. A control's own canvas layer, the window it is in (an
## embedded dialog) and the window's stretch are all taken into account.
func _rect_of_node(node: Node) -> Variant:
	if node is Control:
		var control: Control = node
		if not control.is_visible_in_tree():
			return null
		var box := Rect2(Vector2.ZERO, control.size)
		return _to_window(control.get_viewport(), control.get_global_transform_with_canvas()) * box
	if node is Window:
		var window: Window = node
		if not window.visible:
			return null
		var box := Rect2(Vector2(window.position), Vector2(window.size))
		var host: Viewport = window.get_parent().get_viewport() if window.get_parent() != null else root
		return _to_window(host, Transform2D.IDENTITY) * box
	return null


## From [param viewport]'s canvas, through [param inner], to the window's pixels.
func _to_window(viewport: Viewport, inner: Transform2D) -> Transform2D:
	var at: Transform2D = viewport.get_final_transform() * inner
	while viewport is Window and viewport != root and (viewport as Window).is_embedded():
		var window: Window = viewport
		at = Transform2D(0.0, Vector2(window.position)) * at
		viewport = window.get_parent().get_viewport() if window.get_parent() != null else root
		at = viewport.get_final_transform() * at
	return at


## The part of the window a picture shows, padded and kept inside it.
func _crop(given: Variant, pad: int, size: Vector2i) -> Variant:
	var whole := Rect2i(Vector2i.ZERO, size)
	if given is String and given == "window":
		return whole
	var parts: Array = given if given is Array and not (given as Array).is_empty() \
		and not ((given as Array)[0] is float or (given as Array)[0] is int) else [given]
	var joined: Variant = null
	for one: Variant in parts:
		var rect: Variant = null
		if one is Array and (one as Array).size() == 4:
			rect = Rect2(float(one[0]), float(one[1]), float(one[2]), float(one[3]))
		elif one is String and one == "@opened":
			rect = _opened()
		elif one is String and one == "@pointer":
			if _pointer_at.is_finite():
				rect = Rect2(_pointer_at, Vector2.ZERO)
			else:
				_failed.append("no step put the pointer anywhere (@pointer)")
		elif one is String:
			rect = _rect_of(one)
		if rect == null:
			if _failed.is_empty():
				_failed.append("no crop at %s" % str(one))
			return null
		joined = rect if joined == null else (joined as Rect2).merge(rect)
	var box: Rect2 = (joined as Rect2).grow(pad)
	var cut := Rect2i(Vector2i(floori(box.position.x), floori(box.position.y)),
		Vector2i(ceili(box.size.x), ceili(box.size.y))).intersection(whole)
	if cut.size.x < 8 or cut.size.y < 8:
		_failed.append("the crop %s is outside the window" % str(given))
		return null
	return cut


## Every panel and window in sight now, by instance id.
func _panels_shown() -> Dictionary:
	var shown: Dictionary = {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			continue
		if node is Window and node != root and not (node as Window).visible:
			continue
		if (node is PanelContainer or node is Window or node is Popup) and node != root:
			shown[node.get_instance_id()] = node
		for child: Node in node.get_children(true):
			stack.append(child)
	return shown


## The outermost panel or window the setup put in sight (a dialog, a menu, a
## panel opened by a command), whatever the app calls it: the largest of
## those now in sight that were not before, with none of them round it.
func _opened() -> Variant:
	var best: Variant = null
	var area: float = 0.0
	var now: Dictionary = _panels_shown()
	for id: int in now:
		if _shown_before.has(id):
			continue
		var node: Node = now[id]
		var up: Node = node.get_parent()
		var inside: bool = false
		while up != null:
			if now.has(up.get_instance_id()) and not _shown_before.has(up.get_instance_id()):
				inside = true
				break
			up = up.get_parent()
		if inside:
			continue
		var rect: Variant = _rect_of_node(node)
		if rect != null and (rect as Rect2).get_area() > area:
			area = (rect as Rect2).get_area()
			best = rect
	if best == null:
		_failed.append("the setup put no panel or window in sight to crop to (@opened)")
	return best


## Nothing that moves by itself in the picture: the pointer off everything,
## a field's caret held on, nothing hovered.
## The pointer off the window, as a person's is while the window is read.
func _away() -> void:
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-40, -40)
	away.global_position = away.position
	Input.parse_input_event(away)


## What a tooltip up in the window says, or nothing.
func _tooltip_up(under: Node) -> String:
	for child: Node in under.get_children(true):
		if child.get_class() == "TooltipPanel" and child is Window and (child as Window).visible:
			var words: Array[String] = []
			for label: Node in child.find_children("*", "Label", true, false):
				words.append((label as Label).text)
			for rich: Node in child.find_children("*", "RichTextLabel", true, false):
				words.append((rich as RichTextLabel).get_parsed_text())
			return " ".join(words).strip_edges() if not words.is_empty() else "(a tooltip)"
		var found: String = _tooltip_up(child)
		if not found.is_empty():
			return found
	return ""


func _hold_still() -> void:
	var focus: Control = root.gui_get_focus_owner()
	if focus is LineEdit:
		(focus as LineEdit).caret_blink = false
	elif focus is TextEdit:
		(focus as TextEdit).caret_blink = false


## Outlines and numbered discs over what [param marks] name, drawn in the
## window by the app's own drawing, so they are in the picture as it is.
func _mark(marks: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	var sheet := _Marks.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sheet)
	var to_canvas: Transform2D = root.get_final_transform().affine_inverse()
	for mark: Variant in marks:
		if not mark is Dictionary:
			continue
		var rect: Variant = _rect_of(str(mark.get("at", ""))) if mark.has("at") \
			else Rect2(float(mark["rect"][0]), float(mark["rect"][1]), float(mark["rect"][2]), float(mark["rect"][3]))
		if rect != null:
			sheet.marks.append([to_canvas * (rect as Rect2), str(mark.get("n", "")), str(mark.get("side", "left"))])
	sheet.queue_redraw()


class _Marks extends Control:
	var marks: Array = []
	const INK := Color(1.0, 0.78, 0.18)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		for mark: Array in marks:
			var box: Rect2 = (mark[0] as Rect2).grow(2)
			draw_rect(box, Color(0, 0, 0, 0.55), false, 5.0)
			draw_rect(box, INK, false, 2.5)
			var words: String = mark[1]
			if words.is_empty():
				continue
			var r: float = 13.0
			var at := Vector2(box.position.x + r + 4, box.position.y + r + 4)
			if mark[2] == "right":
				at.x = box.end.x - r - 4
			draw_circle(at, r + 2, Color(0, 0, 0, 0.6))
			draw_circle(at, r, INK)
			var line: Vector2 = font.get_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			draw_string(font, at + Vector2(-line.x * 0.5, 6), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Color(0.08, 0.08, 0.1))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
