## A change sent back from a remix (suggestedit, PLAN row 5), as its
## designer meets it in the studio: Dee signed in, Ann sends the change of
## her remix of Dee's car, and Dee's Account lights within a minute; the
## notification's link (/app?suggestion=N) opens Dee's model as she
## published it with the change drawn on it in Compare: what it takes away
## red, what it moves amber with a ghost where it goes, what it paints
## violet, what it adds a green ghost, each change listed to tick. A row
## pressed frames it. The recolour unticked by its kind's box, Take the
## ticked opens her model with the rest taken in and Share open, its note
## and status saying whose change it is; published, the server marks it
## taken by her version 2. A second change, declined, leaves the model as it
## was. Every press is a click on the screen.
##
##   godot --path . --resolution 1280x800 --script src/dev/suggest_probe.gd -- --pictures=DIR
##   tools/probe.sh suggest_probe -- --pictures=DIR
##
## The server is the real api/share.js and api/people.js over a Supabase in
## memory (tests/fixtures/suggest/serve.mjs), on port 11791 (11792 for the
## phone's run, suggest_phone_probe).
extends SceneTree

const CAR_TAKEN := "res://tests/fixtures/suggest/car.theirs.ldr"
## The bell's bar: the change is on Account within this, seconds.
const BELL_WITHIN := 60.0

var _main: Node
var _store: ModelStore
var _shell: Shell
var _compare: Control
var _library: PartLibrary
var _account: Account
var _server: int = 0
var _port: int = 11791
var _base: String = ""
var _tokens: Dictionary = {}
var _pictures: String = ""
var _failures: int = 0


func _port_for() -> int:
	return 11791


func _finger() -> String:
	return "1280"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(n: int) -> void:
	for _k: int in n:
		await process_frame


func _run() -> void:
	await process_frame
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pictures="):
			_pictures = argument.substr("--pictures=".length())
	if not _pictures.is_empty():
		DirAccess.make_dir_recursive_absolute(_pictures)
	_port = _port_for()
	_base = "http://127.0.0.1:%d" % _port
	_server = OS.create_process("node", [ProjectSettings.globalize_path("res://tests/fixtures/suggest/serve.mjs"),
		str(_port)])
	for _k: int in 40:
		var asked: Dictionary = await _http(HTTPClient.METHOD_GET, "/probe/tokens", "", "")
		if int(asked["code"]) == 200:
			_tokens = asked["body"]
			break
		await create_timer(0.25).timeout
	if not _check("the stand-in answers on port %d" % _port, _tokens.has("dee")):
		await _done()
		return
	OS.set_environment("BRICKWORKS_API", _base)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback != null:
		(playback as BuildPlayback).stop()
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_library = _main.get("_library")
	_account = _main.get("_account")
	print("  a %d x %d window, %s" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
		"laid out for a phone" if _main.get("_phone") != null else "the desktop's layout"])
	await _account.deployment.wait()
	_account.email = "dee@example.com"
	_account._access = str(_tokens["dee"])
	_account._expires_at = Time.get_unix_time_from_system() + 3600.0
	_account.state = Account.State.SIGNED_IN
	_account.changed.emit()
	await _frames(20)

	var id: int = await _bell()
	if id > 0:
		await _opened(id)
		await _taken()
		await _declined()
	await _done()


## Ann sends her change; Dee's Account counts it within a minute, as the
## app asks for itself; her notifications' link is to /app?suggestion=N.
func _bell() -> int:
	var panel: AccountPanel = _main.get("_account_panel")
	panel.ask_feed(true)
	var since: int = Time.get_ticks_msec()
	while panel.get("_feed_asking") and Time.get_ticks_msec() - since < 10000:
		await process_frame
	_check("Dee's Account counts nothing before it is sent (%d)" % panel.feed_count, panel.feed_count == 0)
	var sent: Dictionary = await _http(HTTPClient.METHOD_POST, "/probe/send", "", "{}")
	_check("Ann's change is sent (%d)" % int(sent["code"]), int(sent["code"]) == 201)
	var sent_at: int = Time.get_ticks_msec()
	# Nothing here asks for it: the app's own timer does (FEED_EVERY).
	while panel.feed_count < 1 and Time.get_ticks_msec() - sent_at < int((BELL_WITHIN + 10.0) * 1000.0):
		await create_timer(0.5).timeout
	var waited: float = (Time.get_ticks_msec() - sent_at) / 1000.0
	_check("Dee's Account counts it %.1f s after it was sent, within %d s (%d)" % [waited, int(BELL_WITHIN),
		panel.feed_count], panel.feed_count >= 1 and waited <= BELL_WITHIN)
	var told: Dictionary = await _http(HTTPClient.METHOD_GET, "/api/people?op=notifications", str(_tokens["dee"]), "")
	var link: String = ""
	if told["body"] is Dictionary:
		for group: Variant in (told["body"] as Dictionary).get("groups", []):
			for row: Variant in (group as Dictionary).get("rows", []):
				if str((row as Dictionary).get("kind", "")) == "suggestion":
					link = str((row as Dictionary).get("link", ""))
	_check("her notification links to it (%s)" % link, link.begins_with("/app?suggestion="))
	return link.get_slice("=", 1).to_int() if link.begins_with("/app?suggestion=") else 0


## The link followed as the address does (--suggestion=N): her model opened
## as she published it, the change drawn on it and listed.
func _opened(id: int) -> void:
	_main.set("_suggesting", id)
	_main.set("_suggest_started", false)
	_main.call("_maybe_suggestion")
	_compare = _shell.compare
	var since: int = Time.get_ticks_msec()
	while not (_compare.is_open() and _compare.get("mode") == "suggest") and Time.get_ticks_msec() - since < 30000:
		await process_frame
	await _frames(30)
	var fields: Dictionary = _compare.call("fields")
	print("  %s" % JSON.stringify({"head": fields.get("head"), "kinds": fields.get("kinds"), "drawn": fields.get("drawn")}))
	_check("Compare opens on the change: %s" % str(fields.get("head", "")),
		bool(fields.get("open", false)) and str(fields.get("head", "")).begins_with("Ann's change from their remix “Red car, wider”"))
	_check("her model is open at its link, as she published it (%s, %s)" % [_store.title, _store.share_id],
		_store.share_id == "SuggestDee" and _parts_of("3024", 14) == 2 and _parts_of("3001", 4) == 2)
	var rows: Array = fields.get("rows", [])
	var texts: PackedStringArray = PackedStringArray()
	for row: Variant in rows:
		texts.append(str((row as Dictionary)["text"]))
	print("    " + "\n    ".join(texts))
	_check("each of its 7 changes is listed, ticked", rows.size() == 7
		and rows.all(func(row: Variant) -> bool: return bool((row as Dictionary)["ticked"])))
	_check("each kind is said: %s" % ", ".join((fields.get("kinds", {}) as Dictionary).keys()),
		(fields.get("kinds", {}) as Dictionary).size() == 6)
	_check("the note is shown: %s" % str(fields.get("note", "")), str(fields.get("note", "")) == "“Wider wheels, and a spoiler”")
	var drawn: Dictionary = fields.get("drawn", {})
	var tinted: Dictionary = drawn.get("tinted", {})
	var ghosts: Dictionary = drawn.get("ghosts", {})
	_check("drawn on the model: 2 taken away red, 1 moved amber, 1 recoloured violet (%s)" % JSON.stringify(tinted),
		int(tinted.get("removed", 0)) == 2 and int(tinted.get("moved", 0)) == 1 and int(tinted.get("recoloured", 0)) == 1)
	_check("and as ghosts: 3 added green, 1 where the moved one goes (%s)" % JSON.stringify(ghosts),
		int(ghosts.get("added", 0)) == 3 and int(ghosts.get("moved", 0)) == 1)
	_check("the words say what each is", "Taken away: Plate 1 x 1 in Yellow, step 3" in texts
		and "Recoloured Red to Blue: Brick 2 x 4, step 3" in texts
		and texts.has("Moved 1 stud: Plate 2 x 4 in Black, step 4")
		and texts.has("To step 3 from step 2: Brick 2 x 2 in Black"))
	await _shot("compare")
	# A row pressed: framed, and said.
	var named: Dictionary = _compare.call("controls_by_name")
	var moved_row: int = texts.find("Moved 1 stud: Plate 2 x 4 in Black, step 4")
	if moved_row >= 0:
		await _press(named["suggest_row_%d" % moved_row])
		fields = _compare.call("fields")
		_check("a row pressed says it: %s" % str(fields.get("what", "")), str(fields.get("what", "")).begins_with("Moved 1 stud"))
		await _shot("compare_row")


## The recolour unticked by its kind's box, the rest taken: her model with
## them in it, Share open to publish it; published, marked taken.
func _taken() -> void:
	var named: Dictionary = _compare.call("controls_by_name")
	if not _check("the recoloured kind has a box", named.has("suggest_kind_recoloured")):
		return
	await _press(named["suggest_kind_recoloured"])
	var fields: Dictionary = _compare.call("fields")
	var ticked: int = 0
	for row: Variant in fields.get("rows", []):
		ticked += 1 if bool((row as Dictionary)["ticked"]) else 0
	_check("its box unticks the recolour alone (%d of 7 ticked; %s)" % [ticked, fields.get("take_ticked", "")],
		ticked == 6 and str(fields.get("take_ticked", "")) == "Take the 6 ticked")
	await _press(named["suggest_take_ticked"])
	var since: int = Time.get_ticks_msec()
	while _compare.is_open() and Time.get_ticks_msec() - since < 30000:
		await process_frame
	await _frames(30)
	_check("taken: Compare closes on her model with it in (%s)" % _store.title, not _compare.is_open())
	_check("the rest is in: the roof moved, two white bricks, the round light, both plates gone, the rear brick still red",
		_parts_of("3020", 0) == 1 and _at("3020", 0).x == -80.0 and _parts_of("3004", 15) == 2
		and _parts_of("3062b", 14) == 1 and _parts_of("3024", 14) == 0 and _parts_of("3001", 4) == 2
		and _parts_of("3001", 1) == 0)
	_check("and the model knows whose change it takes in (%s)" % JSON.stringify(_store.suggestion),
		int(_store.suggestion.get("id", 0)) > 0 and not bool(_store.suggestion.get("whole", true)))
	var share: Control = _main.get("_share_panel_made")
	var said: Dictionary = share.call("page_state") if share != null else {}
	print("  share: %s" % JSON.stringify({"status": said.get("status"), "note": said.get("note")}))
	_check("Share opens, saying what publishing does", share != null and share.visible
		and str(said.get("status", "")).begins_with("Part of Ann's change is in this model: publish it as version 2"))
	_check("its note names it: %s" % str(said.get("note", "")),
		str(said.get("note", "")).begins_with("With part of Ann's change from their remix “Red car, wider”:"))
	await _shot("taken")
	if share == null:
		return
	await share.call("publish")
	said = share.call("page_state")
	print("  published: %s" % str(said.get("status", "")))
	var state: Dictionary = (await _http(HTTPClient.METHOD_GET, "/probe/state", "", ""))["body"]
	var row: Dictionary = (state.get("suggestions", []) as Array)[0] if not (state.get("suggestions", []) as Array).is_empty() else {}
	_check("published: the server marks it taken by her version 2 (%s, %s)" % [row.get("status"), row.get("taken_n")],
		str(row.get("status", "")) == "taken" and int(row.get("taken_n", 0)) == 2 and not bool(row.get("whole", true)))
	_check("Share says it credits her", str(said.get("status", "")).contains("It credits Ann on its page and in Versions."))
	_check("and the change is not named again by the next publish", _store.suggestion.is_empty())


## A second change (the rear brick green), opened and declined: closed, the
## model as it was.
func _declined() -> void:
	await _http(HTTPClient.METHOD_POST, "/probe/remix2", "", "{}")
	var sent: Dictionary = await _http(HTTPClient.METHOD_POST, "/probe/send", "", "{}")
	var id: int = int((sent["body"] as Dictionary).get("id", 0)) if sent["body"] is Dictionary else 0
	_check("a second change is sent (%d, %d)" % [int(sent["code"]), id], int(sent["code"]) == 201 and id == 2)
	var trouble: String = await _main.call("open_suggestion", id)
	await _frames(30)
	var fields: Dictionary = _compare.call("fields")
	_check("it opens with its one change (%s)" % trouble, trouble.is_empty() and (fields.get("rows", []) as Array).size() == 1)
	await _press(_compare.call("controls_by_name")["suggest_decline"])
	var since: int = Time.get_ticks_msec()
	while _compare.is_open() and Time.get_ticks_msec() - since < 15000:
		await process_frame
	var state: Dictionary = (await _http(HTTPClient.METHOD_GET, "/probe/state", "", ""))["body"]
	var rows: Array = state.get("suggestions", [])
	_check("declined: closed, and the server says so", not _compare.is_open() and rows.size() == 2
		and str((rows[1] as Dictionary).get("status", "")) == "declined")
	_check("and nothing of it is taken: the rear brick red", _parts_of("3001", 4) == 2 and _parts_of("3001", 2) == 0)


func _parts_of(part: String, colour: int) -> int:
	var n: int = 0
	for item: Variant in _main.get("_world").bricks():
		var brick: BrickWorld.Brick = item
		if brick.part_id == part and brick.color_code == colour and not _store.scenery.has(brick.id):
			n += 1
	return n


## Where the first [param part] in [param colour] stands, in the file's
## coordinates (LDraw's x).
func _at(part: String, colour: int) -> Vector3:
	var world: BrickWorld = _main.get("_world")
	for item: Variant in world.bricks():
		var brick: BrickWorld.Brick = item
		if brick.part_id == part and brick.color_code == colour:
			var at: Vector3 = world.home_of(brick).origin - _store.lift()
			return Vector3(roundf(at.x), roundf(at.y), roundf(at.z))
	return Vector3.INF


## A click at the middle of [param control], as a person's: it must be on
## the screen, and on top there.
func _press(control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		_check("%s is on the screen to press" % (control.name if control != null else "a control"), false)
		return
	var rect: Rect2 = control.get_global_rect()
	var at: Vector2 = rect.get_center()
	var seen: Rect2 = root.get_visible_rect()
	_check("%s (%s) is inside the window to press" % [control.get_class(), str(control.get("text"))],
		seen.has_point(at))
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(6)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _shot(name: String) -> void:
	if _pictures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _pictures.path_join("%s_%s.png" % [name, _finger()])
	image.save_png(path)
	print("  picture: %s" % path)


func _http(method: int, path: String, token: String, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 20.0
	root.add_child(request)
	var headers := PackedStringArray(["content-type: application/json"])
	if not token.is_empty():
		headers.append("authorization: Bearer " + token)
	if request.request(_base + path, headers, method, body) != OK:
		request.queue_free()
		return {"code": 0, "body": null}
	var result: Array = await request.request_completed
	request.queue_free()
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	var json := JSON.new()
	return {"code": int(result[1]), "body": json.data if json.parse(text) == OK else null}


func _done() -> void:
	if _server > 0:
		OS.kill(_server)
	print("suggest (%s): %s" % [_finger(), "all pass" if _failures == 0 else "%d FAILED" % _failures])
	if _main != null:
		_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)
