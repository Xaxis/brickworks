## A long job says when it is done (APP_UX7 #11, donenote).
##
##   godot --path . --resolution 1400x900 --script src/dev/donenote_probe.gd
##   tools/probe.sh donenote_probe        (and PROBE_SIZE=1280x720)
##   ... -- --shots=DIR    the pictures there, not in user://donenote
##
## A design, a Best render, the render queue or a build video ended while the
## person was in another window, and nothing said so: they kept coming back
## to look (Brickium says when its builds are done). Now, unless the window
## has the focus: on the desktop it asks for attention and its title starts
## "Done · "; on the web, one notification with the model's name and what
## finished. Settings turns it off, and the choice is kept.
##
## Through the way in first, as a person comes: the sign-in screen over the
## app (gate_for_probe), a throwaway account signed in with a password (as
## binrow_probe), removed at the end. Needs .env (SUPABASE_URL,
## SUPABASE_SECRET_KEY).
##
## The window's focus, its attention and the browser's Notification are a
## stand-in here (DoneNote.stand_in), put in before the app is made: the
## stand-in browser shows a notification only once the page may notify,
## and grants that when asked, as a person allowing it does. The four jobs
## are the app's own, started as a person starts them: a design asked in
## the assistant's panel (Anthropic's API a stand-in on this machine, as
## design_frame_probe's), Render's Render picture at Best, the render
## queue's Add this view, and Render's Render building, each run to its end.
## - On the desktop, each of the four finished unfocused: 1 attention
##   request each, the title "Done · …" until the window is looked at, then
##   as it was; finished focused: 0; turned off in Settings (the box clicked
##   as a person clicks it, and the choice written to the device): 0.
## - On the web: the page loaded and signed in asks nothing; turned off,
##   a job asks nothing; the first long job's start asks once, and never
##   again; each of the four finished unfocused: 1 notification, its title
##   the model's name and its words what finished; focused: 0; turned off: 0;
##   and where the person said no, none.
## Pictures of Settings with the row, at the window's size.
extends SceneTree


## The window and the browser, as the probe has them.
class StandIn extends RefCounted:
	var looks: bool = false
	var attentions: int = 0
	## The browser's Notification.permission.
	var granted: String = "default"
	var asks: int = 0
	## [title, body] of each notification the browser showed.
	var shown: Array = []

	func looking() -> bool:
		return looks

	func attention() -> void:
		attentions += 1

	func permission() -> String:
		return granted

	## The person allows it.
	func ask() -> void:
		asks += 1
		if granted == "default":
			granted = "granted"

	## As a browser: shown only where the page may notify.
	func notify(title: String, body: String) -> void:
		if granted == "granted":
			shown.append([title, body])


## A stand-in for the Messages API: each POST answered with the next reply
## written here, and "Done." once they run out (design_frame_probe's).
class _Api extends Node:
	var replies: Array = []
	var asked: int = 0
	var port: int = 0
	var _server := TCPServer.new()
	var _peers: Array = []

	func _init() -> void:
		for wanted: int in range(9031, 9110):
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
				held[1] = (held[1] as PackedByteArray) \
					+ (peer.get_data(peer.get_available_bytes())[1] as PackedByteArray)
			var got: PackedByteArray = held[1]
			var text: String = got.get_string_from_utf8()
			var cut: int = text.find("\r\n\r\n")
			if cut < 0:
				continue
			var length: RegExMatch = RegEx.create_from_string("(?i)content-length: *(\\d+)") \
				.search(text.left(cut))
			if length != null and got.size() < cut + 4 + int(length.get_string(1)):
				continue
			asked += 1
			var reply: Dictionary = replies.pop_front() if not replies.is_empty() \
				else {"content": [{"type": "text", "text": "Done."}], "stop_reason": "end_turn"}
			var bytes: PackedByteArray = JSON.stringify(reply).to_utf8_buffer()
			peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
				+ "Content-Length: %d\r\nConnection: close\r\n\r\n" % bytes.size()).to_utf8_buffer())
			peer.put_data(bytes)
			peer.disconnect_from_host()
			_peers.erase(held)

	func _exit_tree() -> void:
		_server.stop()


const NOTE_SCRIPT := "res://src/ui/done_note.gd"
const JOBS: Array[String] = ["design", "Best render", "render queue", "build video"]
## What the note says each finished with (DoneNote.DONE).
const WORDS: Dictionary = {"design": "Design done", "Best render": "Best render done",
	"render queue": "Render queue done", "build video": "Build video done"}
## A small picture, so each render is seconds.
const SIZE := Vector2i(320, 180)
const PROBE_KEY := "sk-ant-probe-donenote-00000000000000000000000000000000000000"

var _failures: int = 0
var _main: Node
var _shell: Shell
var _chat: Node
var _assistant: Node
var _api: _Api
var _stand := StandIn.new()
var _note: GDScript = null
var _ended: Array = []
var _out: String = "user://donenote"
var _size: String = ""
var _email: String = ""
var _password: String = ""
var _towers: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	# The setting written to this run's own data folder and read back.
	ShellPrefs.kept_by_a_check = _own_data_folder()
	# The stand-ins, before the app is made, and the web's way first: the
	# page is loaded and signed in as a browser would.
	if ResourceLoader.exists(NOTE_SCRIPT):
		_note = load(NOTE_SCRIPT) as GDScript
		_note.set("stand_in", _stand)
		_note.set("on_web", true)
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	print("in a %s window" % _size)
	if not await _way_in():
		await _finish()
		return
	_shell = _main.get("_shell")
	await _frames(120)
	_check("the page loaded and signed in has asked nothing (%d asks)" % _stand.asks,
		_stand.asks == 0)
	if not await _ready_for_jobs():
		await _finish()
		return

	print("\non the desktop")
	_web(false)
	await _desktop()
	print("\non the web")
	_web(true)
	await _browser()
	await _finish()


func _web(on: bool) -> void:
	if _note != null:
		_note.set("on_web", on)


# -- the desktop -----------------------------------------------------------------


func _desktop() -> void:
	_stand.looks = false
	for job: String in JOBS:
		var before: int = _stand.attentions
		var ran: bool = await _do(job)
		var title: String = root.title
		_check("%s finished unfocused: %d attention request(s) (want 1)%s" % [job,
			_stand.attentions - before, "" if ran else ", and it never ended"],
			ran and _stand.attentions - before == 1)
		_check("...the title says so: “%s”" % title, title.begins_with("Done · "))
		_stand.looks = true
		await _wait_ms(800)
		_check("...and once looked at, as it was: “%s”" % root.title,
			not root.title.begins_with("Done · ") and root.title.length() > 0)
		_stand.looks = false
	_check("the desktop asked the browser nothing (%d asks)" % _stand.asks, _stand.asks == 0)

	_stand.looks = true
	for job: String in JOBS:
		var before: int = _stand.attentions
		var ran: bool = await _do(job)
		_check("%s finished focused: %d attention request(s) (want 0)" % [job,
			_stand.attentions - before], ran and _stand.attentions == before
			and not root.title.begins_with("Done · "))

	await _turn(false, "desktop")
	_stand.looks = false
	for job: String in JOBS:
		var before: int = _stand.attentions
		var ran: bool = await _do(job)
		_check("turned off, %s finished unfocused: %d attention request(s) (want 0)" % [job,
			_stand.attentions - before], ran and _stand.attentions == before
			and not root.title.begins_with("Done · "))
	await _turn(true, "desktop")


# -- the web ---------------------------------------------------------------------


func _browser() -> void:
	_stand.looks = false
	# Turned off before any job: the first asks nothing, and says nothing.
	await _turn(false, "web")
	var ran: bool = await _do("design")
	_check("turned off, the first long job asks nothing (%d asks) and says nothing (%d)"
		% [_stand.asks, _stand.shown.size()],
		ran and _stand.asks == 0 and _stand.shown.is_empty())
	await _turn(true, "web")

	for job: String in JOBS:
		var asks: int = _stand.asks
		var before: int = _stand.shown.size()
		ran = await _do(job)
		var name: String = (_main.get("_bar") as ModelBar).model_name()
		var said: Array = _stand.shown.slice(before)
		_check("%s finished unfocused: %d notification(s) (want 1)%s" % [job, said.size(),
			"" if ran else ", and it never ended"], ran and said.size() == 1)
		if not said.is_empty():
			_check("...“%s”: “%s” (want “%s”: “%s”)" % [said[0][0], said[0][1], name, WORDS[job]],
				said[0][0] == name and said[0][1] == WORDS[job])
		if job == JOBS[0]:
			_check("...the first long job's start asked once (%d)" % (_stand.asks - asks),
				_stand.asks - asks == 1)
		var note: Node = _main.get("_done_note_made")
		var titled: String = str(note.call("titled", "Car — Brickworks")) if note != null else ""
		_check("...the tab's title says so: “%s”" % titled, titled.begins_with("Done · "))
		_stand.looks = true
		await _wait_ms(800)
		titled = str(note.call("titled", "Car — Brickworks")) if note != null else ""
		_check("...and once looked at, as it was: “%s”" % titled, titled == "Car — Brickworks")
		_stand.looks = false
	_check("asked once in all, on the first long job (%d asks)" % _stand.asks, _stand.asks == 1)

	_stand.looks = true
	for job: String in JOBS:
		var before: int = _stand.shown.size()
		ran = await _do(job)
		_check("%s finished focused: %d notification(s) (want 0)" % [job,
			_stand.shown.size() - before], ran and _stand.shown.size() == before)

	await _turn(false, "web")
	_stand.looks = false
	for job: String in JOBS:
		var before: int = _stand.shown.size()
		ran = await _do(job)
		_check("turned off, %s finished unfocused: %d notification(s) (want 0)" % [job,
			_stand.shown.size() - before], ran and _stand.shown.size() == before)
	await _turn(true, "web")

	# Where the person said no, the browser shows none, and is not asked again.
	_stand.granted = "denied"
	var before: int = _stand.shown.size()
	var asks: int = _stand.asks
	ran = await _do("design")
	_check("where the person said no: %d notification(s), %d more asks (want 0, 0)" % [
		_stand.shown.size() - before, _stand.asks - asks],
		ran and _stand.shown.size() == before and _stand.asks == asks)
	_stand.granted = "granted"


# -- Settings ----------------------------------------------------------------------


## Settings opened, Say when a long job is done clicked as a person clicks it
## until it is [param on], and the choice written to this device.
func _turn(on: bool, where: String) -> void:
	_shell.run("settings")
	await _frames(20)
	var settings: Node = _main.get("_controls")
	var box: CheckBox = settings.get("done_note") as CheckBox if settings != null else null
	if box == null:
		_check("Settings has Say when a long job is done", false)
		if settings != null:
			settings.visible = false
		return
	var held: ScrollContainer = settings.get("_settings") as ScrollContainer
	if held != null:
		held.ensure_control_visible(box)
		await _frames(6)
	var rect: Rect2 = box.get_global_rect()
	var room := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check("Settings shows Say when a long job is done, %s, in the window (%s)" % [
		"ticked" if box.button_pressed else "not ticked", _rect(rect)],
		box.is_visible_in_tree() and room.encloses(rect) and box.text == "Say when a long job is done")
	if not on:
		await _shot("settings_%s_%s" % [where, _size])
	if box.button_pressed != on:
		await _click(rect.get_center())
	var kept := ConfigFile.new()
	var read: int = kept.load(ShellPrefs.WHERE)
	_check("...clicked: it is %s, and the device keeps that (shell.cfg: %s)" % [
		"on" if on else "off", str(kept.get_value("shell", "done_note", "none"))
		if read == OK else "not written"],
		box.button_pressed == on and bool(ShellPrefs.value("done_note")) == on
		and (not ShellPrefs.keeps() or (read == OK and kept.get_value("shell", "done_note", null) == on)))
	await _key(KEY_ESCAPE)
	await _frames(6)
	settings.visible = false
	await _frames(4)


# -- the four jobs -------------------------------------------------------------------


## [param job] started as a person starts it and run to its end: whether it
## ended within its time.
func _do(job: String) -> bool:
	var ended: bool = false
	match job:
		"design":
			ended = await _design()
		"Best render":
			ended = await _render("picture")
		"render queue":
			ended = await _queue()
		"build video":
			ended = await _render("building")
	# The note is given as the job's end is heard, a frame or two after.
	await _frames(8)
	return ended


func _design() -> bool:
	_towers += 1
	_api.replies = [_reply("Tower %d" % _towers, _tower(4 + _towers % 3))]
	var was: int = _ended.size()
	_chat.get("_input").text = "a tower of red and yellow bricks, %d" % _towers
	var sketch: CheckBox = _chat.get("_sketch_first") as CheckBox
	if sketch != null:
		sketch.button_pressed = false
	_chat.call("_on_send")
	var until: int = Time.get_ticks_msec() + 120000
	while _ended.size() == was and Time.get_ticks_msec() < until:
		await process_frame
	if _ended.size() == was:
		print("    (the design never ended: %d requests)" % _api.asked)
		return false
	var playback: Variant = _main.get("_playback")
	if playback != null:
		(playback as BuildPlayback).stop()
	return bool(_ended.back()[0])


## Render's Render picture at Best, or Render building, clicked.
func _render(kind: String) -> bool:
	_main.call("open_render")
	await _frames(20)
	var dialog: Node = _main.get("_render_made")
	if dialog == null:
		print("    (no Render dialog)")
		return false
	var settings: RenderSettings = dialog.get("settings") as RenderSettings
	settings.size = SIZE
	settings.samples = 16
	settings.quality = RenderSettings.Quality.BEST if kind == "picture" \
		else RenderSettings.Quality.QUICK
	settings.fps = 6
	dialog.set("_build_seconds", 10)
	dialog.set("folder", ProjectSettings.globalize_path(_out.path_join("renders")))
	var button: Button = dialog.get("_picture_button" if kind == "picture"
		else "_building_button") as Button
	var before: Variant = dialog.get("_last")
	await _click(button.get_global_rect().get_center())
	var until: int = Time.get_ticks_msec() + 5000
	while not bool(dialog.call("is_rendering")) and Time.get_ticks_msec() < until:
		await process_frame
	until = Time.get_ticks_msec() + 240000
	while bool(dialog.call("is_rendering")) and Time.get_ticks_msec() < until:
		await process_frame
	var made: Variant = dialog.get("_last")
	var ok: bool = made is Dictionary and not is_same(made, before) \
		and str((made as Dictionary).get("kind", "")) == kind
	if not ok:
		print("    (Render %s made nothing: %s)" % [kind, str(dialog.get("_status").text)])
	await _frames(4)
	dialog.call("close")
	await _frames(6)
	return ok


## File, Render queue…, Add this view clicked, and the queue drawn empty.
func _queue() -> bool:
	_main.call("open_render")
	await _frames(10)
	var dialog: Node = _main.get("_render_made")
	var settings: RenderSettings = dialog.get("settings") as RenderSettings
	settings.size = SIZE
	settings.quality = RenderSettings.Quality.QUICK
	dialog.call("close")
	await _frames(6)
	_shell.run("render_queue")
	await _frames(20)
	var queue: RenderQueue = RenderQueue.of(_main)
	queue.folder = ProjectSettings.globalize_path(_out.path_join("queue"))
	var add: Button = queue.get("_add_button") as Button
	var count: int = queue.items.size()
	await _click(add.get_global_rect().get_center())
	var until: int = Time.get_ticks_msec() + 240000
	while (queue.items.size() == count or queue.is_drawing() or queue.waiting() > 0
			or bool(queue.get("_running"))) and Time.get_ticks_msec() < until:
		await process_frame
	var last: RenderQueue.Item = queue.items.back() if queue.items.size() > count else null
	var ok: bool = last != null and last.state == "done"
	if not ok:
		print("    (the queue drew nothing: %s)" % ("no item" if last == null else last.state))
	queue.close()
	await _frames(6)
	return ok


# -- the way in, and what the jobs need ------------------------------------------------


## The sign-in screen up, a throwaway account signed in, the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("donenote")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify (binrow_probe's).
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


## The assistant's panel answering from the stand-in API, on a key for this
## run only, written nowhere and sent nowhere but there.
func _ready_for_jobs() -> bool:
	_chat = _main.get("_chat")
	if _chat == null:
		_main.call("_make_chat")
		_chat = _main.get("_chat")
	_assistant = _main.get("_assistant")
	if _chat == null or _assistant == null or _shell == null:
		_check("the app has its assistant, its panel and its menus", false)
		return false
	_api = _Api.new()
	root.add_child(_api)
	_assistant.set("endpoint", "http://127.0.0.1:%d/v1/messages" % _api.port)
	_assistant.set("stream_replies", false)
	OwnKey._this_visit = PROBE_KEY
	var mine: CheckBox = _chat.get("_use_claude_code") as CheckBox
	if mine != null:
		mine.button_pressed = false
	_assistant.connect(&"finished", func(ok: bool, summary: String) -> void:
		_ended.append([ok, summary]))
	return true


func _tower(count: int) -> Array:
	var bricks: Array = []
	for n: int in count:
		bricks.append({"part": "3001", "color": 4 if n % 2 == 0 else 14,
			"x": 0, "y": 3 * n, "z": 0, "rot": 0})
	return bricks


func _reply(name: String, bricks: Array) -> Dictionary:
	return {"content": [{"type": "tool_use", "id": "toolu_probe_%d" % randi(),
		"name": "submit_design", "input": {"name": name, "description": name.to_lower(),
		"bricks": bricks}}], "stop_reason": "tool_use"}


# -- input and waiting -------------------------------------------------------------------


func _click(at: Vector2) -> void:
	var spot: Vector2 = _as_event(at)
	var motion := InputEventMouseMotion.new()
	motion.position = spot
	motion.global_position = spot
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = spot.floor()
		event.global_position = spot.floor()
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _wait_ms(ms: int) -> void:
	var until: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _rect(rect: Rect2) -> String:
	return "%d,%d %dx%d" % [roundi(rect.position.x), roundi(rect.position.y),
		roundi(rect.size.x), roundi(rect.size.y)]


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("    picture: %s" % path)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	if _note != null:
		_note.set("stand_in", null)
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	if _failures == 0:
		print("donenote probe: each long job finished unseen says so once, and seen or turned off says nothing")
	else:
		print("donenote probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
