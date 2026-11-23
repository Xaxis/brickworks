## The studio's first screen for somebody signed in (studiostart,
## src/ui/studio_start.gd): what it lists, and that each choice does what it
## says, in the app.
##
##   godot --path . --resolution 1280x800 --script src/dev/studio_start_probe.gd
##   ... -- --pictures=DIR   its pictures, windowed (studio_start_1280.png, or
##                           at another PROBE_SIZE that size's)
##
## No network: FakeShared answers as api/people.js ?op=studio_start and
## ?op=comments and api/share.js ?op=list do, and its pictures come from
## tests/fixtures/photos. Four models are saved here first, one of them
## shared under ID with a comment on one of its parts.
##
## (a) Signed in, it opens by itself, once: Continue lists the four saved
##     models newest first, the week's quick build, what came back (three,
##     the pin said as one) and the gallery's six; three real things or more.
## (b) The pin pressed opens the shared model and selects the part it is on,
##     framed, within a second of the press.
## (c) A pin written while the studio is open shows within a minute: the
##     notice counts it, unasked (Main.PINS_EVERY).
## (d) Escape puts it away; a gallery model pressed (shown again for it)
##     opens as a copy of the person's own, credited to its link.
##
## One PASS or FAIL line per check; it exits 1 on any FAIL.
extends SceneTree

const ID := "Pr0beStart"
const GALLERY := "Pr0beGal0%d"
const TOKEN := "probe.start.token"
const COMMENT := 4101
const PIN_COLOUR := 14
const PHOTOS: Array[String] = ["3001", "3039", "3062b", "3069b", "3700"]

var _failures: int = 0
var _main: Node
var _pictures: String = ""


class FakeShared extends SharedModels:
	var start: Dictionary = {}
	var comment_answer: Dictionary = {}
	var gallery_answer: Dictionary = {}
	var model_text: String = ""
	var asked_comments: int = 0
	var asked_start: int = 0

	func studio_start(_token: String) -> Dictionary:
		asked_start += 1
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": start.duplicate(true)}

	func gallery(_words: String, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": gallery_answer.duplicate(true)}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		asked_comments += 1
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": comment_answer.duplicate(true)}

	func fetch(id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"id": id, "name": "Gallery Tower", "author": "Probe Maker",
			"licence": "CC-BY-4.0", "parts": 6, "model": model_text, "version": 1}}

	func prompt_of(_template: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"prompt": null}}


## The pictures, from the fixtures' photos, as the gallery would send them.
class FakePictures extends ModelLibrary:
	func fetch(url: String, _most: int, _job: Working.Job = null, _headers := PackedStringArray()) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		var n: int = absi(url.hash()) % PHOTOS.size()
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/photos/%s.jpg" % PHOTOS[n])
		return {"code": 200 if not bytes.is_empty() else 404, "bytes": bytes}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--pictures="):
			_pictures = given.substr("--pictures=".length())
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_save_models()
	var fake := _fake()
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	_main.set("start_for_probe", true)
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	var account: Account = _main.get("_account")
	await account.deployment.wait()
	# Signed in now, as by the code: the first screen is due.
	account.email = "delivered+studiostart-app@resend.dev"
	account.user_id = "00000000-0000-4000-8000-0000005ad1a1"
	account._access = TOKEN
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	var signed_ms: int = Time.get_ticks_msec()
	account.changed.emit()
	var start: Control = null
	for _n: int in 600:
		await process_frame
		start = _main.get("_studio_start")
		if start != null and start.visible and int(start.get("filled_ms")) >= 0 \
				and str(start.get("asked")) == "ok" and (start.get("found") as Array).size() > 0:
			break
	if start == null:
		_check(false, "(a) the first screen opens for somebody signed in with saved models")
		_finish()
		return
	start.set("pictures", FakePictures.new())
	start.call("_fill_continue")
	start.call("_fill_came")
	start.call("_fill_found", true)
	await _settle()
	await _a_while(30)
	await _picture("studio_start_%d.png" % int(root.get_visible_rect().size.x))
	await _the_list(start, signed_ms)
	await _the_pin(start, fake)
	await _a_new_pin(fake)
	await _a_copy(start)
	_finish()


# -- what is set up -----------------------------------------------------------------

func _save_models() -> void:
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	var names: Array[String] = ["Harbour Tug", "Castle Gate", "Red Racer", "Pinned Tower"]
	for n: int in names.size():
		var text: String = _grid_text(names[n], 3 + n * 2, n == 3)
		var path: String = ModelStore.SAVE_DIR + names[n] + ".ldr"
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		# Newest last: Pinned Tower, saved last, is listed first.
		OS.delay_msec(1100)


func _grid_text(title: String, across: int, linked: bool) -> String:
	var lines := PackedStringArray(["0 " + title, "0 Name: %s.ldr" % title, "0 Author: Probe Builder"])
	if linked:
		lines.append(ModelStore.SHARE_META + ID)
	var colours: Array[int] = [4, 1, 2, PIN_COLOUR, 15, 0, 25, 27]
	for n: int in across:
		lines.append("1 %d %d 0 0 1 0 0 0 1 0 0 0 1 3001.dat" % [colours[n % colours.size()], (n - across / 2) * 80])
	return "\n".join(lines) + "\n"


func _fake() -> FakeShared:
	var fake := FakeShared.new()
	fake.model_text = _grid_text("Gallery Tower", 6, false)
	fake.start = {"ready": true, "prompt": {"id": 7, "title": "Tiny Lighthouse", "starts_on": "2026-11-23",
		"brief": "A lighthouse no taller than 12 bricks, with a light that turns.", "ends_on": "2026-11-29",
		"page": "/challenge?id=7", "start": "/app?copy=Pr0beTemp1", "entries": 14},
		"came": [
			{"kind": "comment", "model": ID, "name": "Pinned Tower", "picture": "/m/%s.webp" % ID,
				"line": "{who} commented on a part, step 1", "who": "Lia", "said": "This yellow brick wants a slope on top",
				"at": _iso_ago(600), "new": true, "link": "/m/%s#comment-%d" % [ID, COMMENT],
				"comment": COMMENT, "pinned": true},
			{"kind": "photo", "model": ID, "name": "Pinned Tower", "picture": "/m/%s.webp" % ID,
				"line": "{who} posted a photo of their build", "who": "Sam", "said": "Built it with my daughter",
				"at": _iso_ago(7200), "new": true, "link": "/m/%s#photo-abc" % ID, "comment": 0, "pinned": false},
			{"kind": "remix", "model": ID, "name": "Pinned Tower", "picture": "/m/%s.webp" % ID,
				"line": "{who} remixed it as “Tall Tower”", "who": "Bo", "said": "", "at": _iso_ago(90000),
				"new": false, "link": "/m/Pr0beRemx1", "comment": 0, "pinned": false}]}
	var models: Array = []
	var names: Array[String] = ["Gallery Tower", "Moon Base", "Steam Train", "Fire Station", "Mini Mech", "Bonsai"]
	for n: int in names.size():
		models.append({"id": GALLERY % n, "name": names[n], "author": "Builder %d" % (n + 1),
			"parts": 40 + n * 37, "licence": "CC-BY-4.0"})
	fake.gallery_answer = {"models": models, "more": false}
	fake.comment_answer = _comments([_a_pin(COMMENT, PIN_COLOUR)])
	return fake


func _comments(listed: Array) -> Dictionary:
	return {"model": ID, "ready": true, "version": 1, "newest": 1, "open": true, "replies": true, "pins": true,
		"count": listed.size(), "comments": listed,
		"you": {"signed_in": true, "may_write": true, "why_not": "", "owner": true}}


## A pin on the part of [param colour] in Pinned Tower as written (its
## place: the n-th brick at x = (n - across/2) * 80).
func _a_pin(id: int, colour: int) -> Dictionary:
	var colours: Array[int] = [4, 1, 2, PIN_COLOUR, 15, 0, 25, 27]
	var n: int = colours.find(colour)
	return {"id": id, "version": 1, "step": 1, "on_step": 1, "body": "pin %d" % id,
		"at": "2026-11-23T12:00:00+00:00", "edited_at": null, "by": "Lia", "handle": "lia", "by_owner": false,
		"mine": false, "hidden": false, "older": false, "said": "", "parent": null, "resolved": false,
		"resolved_at": null, "pin": {"part": "3001", "colour": colour, "at": [float((n - 9 / 2) * 80), 0.0, 0.0],
			"section": "", "line": 1, "near": [], "full": true}}


func _iso_ago(seconds: int) -> String:
	return Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - seconds) + "Z"


# -- (a) to (d) --------------------------------------------------------------------

func _the_list(start: Control, signed_ms: int) -> void:
	var state: Dictionary = start.call("page_state")
	print("     ", state)
	_check(bool(state["shown"]) and state["names"] == ["Pinned Tower", "Red Racer", "Castle Gate", "Harbour Tug"],
		"(a) opens by itself once signed in; Continue lists the saved models newest first (%s)" % [state["names"]])
	_check(str(state["prompt"]) == "Tiny Lighthouse" and start.call("controls_by_name").has("start_prompt"),
		"(a) this week's quick build, with Start from its template (%s)" % state["prompt"])
	_check(int(state["came"]) == 3 and int(state["pins"]) == 1 and int(state["found"]) == 6,
		"(a) what came back, 3 (1 on a part), and the gallery's 6 (%d, %d, %d)" % [
			state["came"], state["pins"], state["found"]])
	var filled: int = int(state["filled_ms"])
	_check(int(state["real"]) >= 3 and filled >= 0 and filled - signed_ms <= 1000,
		"(a) %d real things, three of them within %d ms of the sign-in" % [state["real"], filled - signed_ms])
	_check(bool(_main.get("_start_decided")), "(a) decided once a tab")


func _the_pin(start: Control, fake: FakeShared) -> void:
	var row: Control = (start.call("controls_by_name") as Dictionary).get("start_came_0")
	if row == null:
		_check(false, "(b) the pin's row is there to press")
		return
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var asked: int = fake.asked_comments
	var pressed_ms: int = Time.get_ticks_msec()
	_press_now(row)
	var meant: int = 0
	var pins: Control = null
	var lit_ms: int = -1
	while Time.get_ticks_msec() - pressed_ms < 5000:
		await process_frame
		pins = _main.get("_part_pins")
		meant = _brick_coloured(world, PIN_COLOUR) if store.share_id == ID else 0
		if pins != null and meant != 0 and int(pins.get("lit")) == meant:
			lit_ms = Time.get_ticks_msec() - pressed_ms
			break
	var builder: Builder = _main.get("_builder")
	_check(not start.visible and store.title == "Pinned Tower" and lit_ms >= 0 and lit_ms <= 1000
		and builder.selection.has(meant),
		"(b) the pin pressed opens Pinned Tower with its part selected in %d ms (asked %d more)" % [
			lit_ms, fake.asked_comments - asked])
	await _settle()
	await _picture("studio_start_pin_%d.png" % int(root.get_visible_rect().size.x))


func _a_new_pin(fake: FakeShared) -> void:
	var pins: Control = _main.get("_part_pins")
	if pins == null:
		_check(false, "(c) a pin written meanwhile shows within a minute (no pins shown)")
		return
	# Put away, as the person would once read: a new one brings it back.
	var notice: Control = pins.get("_notice")
	if notice != null:
		notice.call("dismiss")
	var asked: int = fake.asked_comments
	fake.comment_answer = _comments([_a_pin(COMMENT, PIN_COLOUR), _a_pin(COMMENT + 1, 2)])
	var since: int = Time.get_ticks_msec()
	var shown_ms: int = -1
	while Time.get_ticks_msec() - since < 65000:
		await _a_while(10)
		notice = pins.get("_notice")
		if notice != null and notice.visible and (pins.call("open_ones") as Array).size() == 2:
			shown_ms = Time.get_ticks_msec() - since
			break
	_check(shown_ms >= 0 and shown_ms <= 60000,
		"(c) a pin written while the studio is open shows within a minute, unasked: %d ms (%d asks)" % [
			shown_ms, fake.asked_comments - asked])


func _a_copy(start: Control) -> void:
	# Shown again (Escape put it away), as a check may: its gallery's first.
	start.call("open", (_main.get("_store") as ModelStore).list_saved())
	for _n: int in 30:
		await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await _a_while(5)
	_check(not start.visible, "(d) Escape puts it away")
	start.call("open", (_main.get("_store") as ModelStore).list_saved())
	for _n: int in 30:
		await process_frame
	var tile: Control = (start.call("controls_by_name") as Dictionary).get("start_found_0")
	if tile == null:
		_check(false, "(d) a gallery model to press")
		return
	_press_now(tile)
	var store: ModelStore = _main.get("_store")
	for _n: int in 600:
		await process_frame
		if store.remixed_from == GALLERY % 0 and store.awaited.is_empty():
			break
	_check(not start.visible and store.remixed_from == GALLERY % 0 and store.title.begins_with("Gallery Tower"),
		"(d) a gallery model pressed opens as their own copy: “%s”, from %s" % [store.title, store.remixed_from])


# -- helpers ------------------------------------------------------------------------

func _brick_coloured(world: BrickWorld, colour: int) -> int:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code == colour:
			return brick.id
	return 0


func _press_now(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _a_while(frames: int) -> void:
	for _n: int in frames:
		await process_frame


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


func _picture(name: String) -> void:
	if _pictures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_pictures)
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(_pictures.path_join(name))
		print("     picture: ", _pictures.path_join(name))


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "the studio's first screen: every check passed")
	quit(1 if _failures else 0)
