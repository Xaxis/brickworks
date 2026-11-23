## Comments on a part of a shared model, in the app (partpins, 2026-11-23):
## the viewer's menu on a part, what a pin sends, its line and its dot; the
## studio's notice and list of them, each pressed and resolved; and the
## rule that says which part a pin is on (PinPlace) against the page's.
##
##   godot --path . --resolution 1280x800 --script src/dev/partpins_probe.gd
##   ... -- --pictures=DIR   two pictures, windowed: the viewer's pins, the studio's list
##
## No network: FakeShared answers as api/people.js does (op=comments, op=pin,
## op=pin_resolve). The model is written here: 30 parts in a grid, each in a
## colour of its own, so the part a pin means is known from its colour,
## apart from anything the app works out.
##
## (a) In the viewer, 20 right clicks on 20 parts, each followed by Comment on
##     this part, a comment typed and Send: what the pin sends is the part the
##     viewer outlines and names under the pointer (its own pick), at the
##     place the file put it, 20 of 20. And a finger held on a part, and
##     Shift+F10, offer the same menu; a pinned comment's line lights and
##     frames its part; dots are drawn on the parts; a resolved pin is not
##     drawn and is folded under Resolved.
## (b) In the studio, signed in, the model with its link open: the notice
##     counts the open pins, Show lists the same pins as the answer, in its
##     order, and pressing each of 10 selects the right part and frames it,
##     10 of 10; a moved part's pin says so and selects it; a pin on a part
##     taken off is said on its version and not pressed; Resolve folds one
##     under Resolved and Reopen brings it back, each sent.
## (c) PinPlace on tests/fixtures/pins/pairs.json (version pairs, as
##     web/card.js pinPlace placed each pin): the same answer, case for case.
##
## One PASS or FAIL line per check; it exits 1 on any FAIL.
extends SceneTree

const ID := "Pr0bePinsX"
const FIXTURE := "res://tests/fixtures/pins/pairs.json"
const TOKEN := "probe.pins.token"
## One colour each, so a part is known by its colour.
const COLOURS: Array[int] = [0, 1, 2, 4, 5, 6, 14, 15, 19, 25, 26, 27, 28, 70, 71, 72, 73, 84, 85,
	191, 212, 226, 272, 288, 308, 320, 321, 322, 323, 326]
## The parts of each row, and their names as the line says them.
const ROWS: Array[String] = ["3001", "3003", "3020", "3022", "3068b"]

var _failures: int = 0
var _main: Node
var _pictures: String = ""
## Each colour's place in the file as written: [x, y, z].
var _placed: Dictionary = {}
var _part_of_colour: Dictionary = {}


class FakeShared extends SharedModels:
	var answer: Dictionary = {}
	## What ?op=comments answers: the server's list, which a pin joins.
	var comment_answer: Dictionary = {}
	var pinned: Array[Dictionary] = []
	var resolved_calls: Array = []
	var asked_comments: int = 0
	var next_id: int = 500

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		asked_comments += 1
		await (Engine.get_main_loop() as SceneTree).process_frame
		if comment_answer.is_empty():
			return {"code": 400, "body": {"error": "unknown op comments"}}
		return {"code": 200, "body": comment_answer.duplicate(true)}

	func pin(token: String, body: Dictionary) -> Dictionary:
		pinned.append(body.merged({"token": token}))
		await (Engine.get_main_loop() as SceneTree).process_frame
		next_id += 1
		var made: Dictionary = {"id": next_id, "version": body["version"], "step": body["step"],
			"on_step": body["step"], "body": body["body"], "at": "2026-11-23T12:00:00+00:00",
			"edited_at": null, "by": "Probe Reader", "handle": null, "by_owner": false, "mine": true,
			"hidden": false, "older": false, "said": "on version %d" % int(body["version"]),
			"parent": null, "resolved": false, "resolved_at": null,
			"pin": (body["part"] as Dictionary).merged({"section": "", "line": 1, "near": [], "full": true})}
		(comment_answer["comments"] as Array).append(made.duplicate(true))
		return {"code": 201, "body": {"comment": made}}

	func resolve_pin(_token: String, id: int, resolved: bool) -> Dictionary:
		resolved_calls.append([id, resolved])
		await (Engine.get_main_loop() as SceneTree).process_frame
		for one: Dictionary in comment_answer["comments"]:
			if int(one["id"]) == id:
				one["resolved"] = resolved
				one["resolved_at"] = "2026-11-23T13:00:00+00:00" if resolved else null
				return {"code": 200, "body": {"comment": one.duplicate(true)}}
		return {"code": 404, "body": {"error": "There is no such comment."}}


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
	var text: String = _model_text(false)
	print("\n(c) the rule, against the page's")
	_the_rule()
	print("\n(a) the viewer")
	await _the_viewer(text)
	print("\n(b) the studio")
	await _the_studio(_model_text(true))
	_finish()


# -- the model ---------------------------------------------------------------------

## 30 parts, 6 across and 5 deep, a row a step, each its own colour; with
## its link's meta line for the studio.
func _model_text(with_link: bool) -> String:
	var lines: PackedStringArray = PackedStringArray(["0 Probe Pins", "0 Name: probe_pins.ldr",
		"0 Author: Brickworks"])
	if with_link:
		lines.append(ModelStore.SHARE_META + ID)
	var n: int = 0
	for row: int in ROWS.size():
		for column: int in 6:
			var colour: int = COLOURS[n]
			var at := [float((column - 2) * 120 - 60), 0.0, float((row - 2) * 80)]
			_placed[colour] = at
			_part_of_colour[colour] = ROWS[row]
			lines.append("1 %d %d %d %d 1 0 0 0 1 0 0 0 1 %s.dat" % [colour, int(at[0]), int(at[1]),
				int(at[2]), ROWS[row]])
			n += 1
		lines.append("0 STEP")
	return "\n".join(lines) + "\n"


func _count() -> int:
	return COLOURS.size()


# -- (c) the rule -------------------------------------------------------------------

func _the_rule() -> void:
	if not FileAccess.file_exists(FIXTURE):
		_check(false, "(c) PinPlace matches the page's rule on every version pair (no %s)" % FIXTURE)
		return
	var cases: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not cases is Array or (cases as Array).is_empty():
		_check(false, "(c) PinPlace matches the page's rule on every version pair (%s holds no cases)" % FIXTURE)
		return
	var same: int = 0
	var wrong: Array[String] = []
	for one: Variant in cases:
		var case: Dictionary = one
		var got: Dictionary = PinPlace.place(case.get("pin"), case.get("bricks", []))
		var want: Variant = case.get("want")
		var agrees: bool = got.is_empty() if want == null else (not got.is_empty()
			and int(got["index"]) == int((want as Dictionary)["index"])
			and bool(got["moved"]) == bool((want as Dictionary)["moved"]))
		if agrees:
			same += 1
		elif wrong.size() < 5:
			wrong.append("%s: %s, not %s" % [case.get("name", "?"), got, want])
	print("     %d of %d cases as the page placed them" % [same, (cases as Array).size()])
	for line: String in wrong:
		print("       " + line)
	_check(same == (cases as Array).size(),
		"(c) PinPlace matches the page's rule on every version pair (%d of %d)" % [same, (cases as Array).size()])
	# And its words, as the page says them.
	var said: Array = [PinPlace.said("Brick  2 x  4", 12), PinPlace.said("Brick 2 x 4", 0),
		PinPlace.said("", 3), PinPlace.said("", 0), PinPlace.part_said("Plate 1 x 2 x 3"),
		PinPlace.where("Brick 2 x 4", 12, {"moved": true}, 1), PinPlace.where("Brick 2 x 4", 12, {}, 2)]
	_check(said == ["on the 2 × 4 brick, step 12", "on the 2 × 4 brick", "on a part, step 3", "on a part",
		"1 × 2 × 3 plate", "on the 2 × 4 brick, step 12, moved since", "on version 2"],
		"(c) the words where a pin is, as the page says them (%s)" % [said])


# -- (a) the viewer ---------------------------------------------------------------

func _the_viewer(text: String) -> void:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe Pins", "author": "Probe Builder",
		"parts": _count(), "url": "https://brickworks.diy/m/" + ID, "model": text, "version": 1}}
	fake.comment_answer = {"model": ID, "ready": true, "version": 1, "newest": 1, "open": true,
		"replies": true, "pins": true, "count": 0, "comments": [],
		"you": {"signed_in": true, "may_write": true, "why_not": "", "owner": false}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", ID)
	_main.set("_shared", fake)
	_main.set("comment_token_for_probe", TOKEN)
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	await _steps_worked_out()
	if view == null or view.state != "ready":
		_check(false, "(a) the shared model opened in the viewer (%s)" % (view.state if view != null else "none"))
		return
	for _n: int in 120:
		await process_frame
		if _main.get("_part_pins") != null:
			break
	var pins: Control = _main.get("_part_pins")
	if pins == null or not pins.pins_on():
		_check(false, "(a) the viewer knows the server keeps comments on parts (pins: true)")
		return
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var comments: StepComments = view.comments

	# Twenty right clicks, each a pin sent.
	var tried: int = 0
	var right: int = 0
	var wrong: Array[String] = []
	var words_seen: String = ""
	for brick: BrickWorld.Brick in world.bricks():
		if right + wrong.size() >= 20:
			break
		if store.scenery.has(brick.id):
			continue
		var at: Vector2 = _point_on(brick)
		if at.x < 0.0:
			continue
		tried += 1
		_move(at)
		for _n: int in 12:
			await process_frame
		var picked: int = int(_main.get("_hovered"))
		await _right_click(at)
		var item: Control = pins.controls_by_name().get("view_pin_comment")
		if item == null or picked == 0:
			wrong.append("#%d: %s" % [brick.id, "no menu" if item == null else "no part under the pointer"])
			pins.close_menu()
			continue
		await _press(item)
		var box: Control = comments.controls_by_name().get("view_comment_box")
		var send: Control = comments.controls_by_name().get("view_comment_send")
		if box == null or send == null or not comments.controls_by_name().has("view_pin_cancel"):
			wrong.append("#%d: no box on the part" % brick.id)
			comments.close()
			continue
		if words_seen.is_empty():
			words_seen = str(comments.page_state().get("comment_on_part", ""))
		(box as LineEdit).text = "About part %d" % brick.id
		var before: int = fake.pinned.size()
		await _press(send)
		for _n: int in 60:
			if fake.pinned.size() > before:
				break
			await process_frame
		if fake.pinned.size() <= before:
			wrong.append("#%d: nothing sent" % brick.id)
			comments.close()
			continue
		var sent: Dictionary = (fake.pinned[-1] as Dictionary).get("part", {})
		var shown: BrickWorld.Brick = world.get_brick(picked)
		var file_at: Array = _placed.get(shown.color_code, [])
		var same: bool = shown != null and str(sent.get("part", "")) == shown.part_id \
			and int(sent.get("colour", -1)) == shown.color_code and _near(sent.get("at"), file_at)
		if same:
			right += 1
		else:
			wrong.append("#%d: sent %s, the viewer picked %s %d at %s" % [brick.id, sent,
				shown.part_id if shown != null else "?", shown.color_code if shown != null else -1, file_at])
		if comments.controls_by_name().has("view_comment_close"):
			await _press(comments.controls_by_name()["view_comment_close"])
		else:
			comments.close()
			await _settle()
	for line: String in wrong.slice(0, 5):
		print("       " + line)
	_check(right == 20 and wrong.is_empty(),
		"(a) 20 right clicks on parts: each pin sends the part the viewer picked, where the file put it (%d of 20, %d tried)"
			% [right, tried])
	_check(words_seen.begins_with("On the ") and words_seen.contains(" × "),
		"(a) the box says which part it goes on (\"%s\")" % words_seen)
	await _settle()
	var said: Dictionary = pins.page_state()
	_check(int(said.get("dots", 0)) > 0 and int(said.get("open", 0)) == fake.pinned.size(),
		"(a) a numbered dot over pinned parts (%d drawn, %d open)" % [int(said.get("dots", 0)), int(said.get("open", 0))])

	# A finger held still on a part offers the same menu.
	var held: BrickWorld.Brick = _a_free_brick(world, store)
	var finger_at: Vector2 = _point_on(held) if held != null else Vector2(-1, -1)
	var by_finger: bool = false
	if finger_at.x >= 0.0:
		_touch(finger_at, true)
		var since: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - since < 2000 and not pins.menu_open():
			await process_frame
		by_finger = pins.menu_open()
		_touch(finger_at, false)
		await _settle()
		pins.close_menu()
	_check(by_finger, "(a) a finger held on a part offers Comment on this part")

	# Shift+F10, with nothing focused: the part in the middle of the model.
	if comments.is_open():
		comments.close()
	await _settle()
	await _key(KEY_F10, true)
	var by_keys: bool = pins.menu_open()
	var keyed: Dictionary = pins.page_state().get("offered", {})
	pins.close_menu()
	_check(by_keys and not str(keyed.get("part", "")).is_empty(),
		"(a) Shift+F10 offers it on the part in the middle (%s)" % [keyed])

	# A pinned comment's line lights and frames its part.
	var pill: Control = comments.controls_by_name().get("view_comments")
	if pill != null:
		await _press(pill)
	var line: Control = comments.controls_by_name().get("view_pin_1")
	var first: Dictionary = (fake.comment_answer["comments"] as Array)[0]
	var meant: int = _brick_coloured(world, int((first["pin"] as Dictionary)["colour"]))
	if line != null:
		await _into_view(line)
		await _press(line)
		await _camera_still()
	var outline: SelectionOutline = _main.get("_build_outline")
	_check(line != null and int(pins.get("lit")) == meant and meant != 0
		and not (outline._shared.is_empty() and outline._copied.is_empty()) and _framed(meant),
		"(a) its line (\"%s\") lights its part and frames it (#%d, lit #%d)" % [
			(line as Button).text if line != null else "none", meant, int(pins.get("lit"))])
	await _picture("1_viewer_pins.png")

	# Resolved: not drawn, folded under Resolved.
	var gone: Dictionary = (fake.comment_answer["comments"] as Array)[0]
	gone["resolved"] = true
	gone["resolved_at"] = "2026-11-23T13:00:00+00:00"
	await _main.call("_load_comments", TOKEN)
	await _settle()
	var dots: Dictionary = pins.get("_dots")
	var fold: Control = comments.controls_by_name().get("view_pins_resolved")
	_check(not dots.has(int(gone["id"])) and fold != null and (fold as Button).text == "Resolved (1)"
		and not comments.controls_by_name().has("view_pin_1"),
		"(a) a resolved pin is not drawn, and is folded under %s" % ((fold as Button).text if fold != null else "nothing"))
	_main.queue_free()
	for _n: int in 10:
		await process_frame


# -- (b) the studio ------------------------------------------------------------------

func _the_studio(text: String) -> void:
	var fake := FakeShared.new()
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	var account: Account = _main.get("_account")
	var store: ModelStore = _main.get("_store")
	var bar: ModelBar = _main.get("_bar")
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	await account.deployment.wait()
	account.email = "delivered+partpins-app@resend.dev"
	account._access = TOKEN
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	# Twelve pins: ten on parts as they stand, one on a part moved since, one
	# on a part taken off.
	var listed: Array = []
	var expected: Array = []
	for n: int in 10:
		var colour: int = COLOURS[n * 3]
		listed.append(_a_pin(100 + n, colour, _placed[colour]))
		expected.append(colour)
	var moved_colour: int = COLOURS[1]
	var was: Array = _placed[moved_colour]
	listed.append(_a_pin(110, moved_colour, [float(was[0]) + 10.0, float(was[1]), float(was[2])]))
	listed.append(_a_pin(111, 4, [1000.0, 0.0, 1000.0]))
	listed[11]["pin"]["part"] = "3001"
	fake.comment_answer = {"model": ID, "ready": true, "version": 1, "newest": 1, "open": true,
		"replies": true, "pins": true, "count": listed.size(), "comments": listed,
		"you": {"signed_in": true, "may_write": true, "why_not": "", "owner": true}}
	var opened: Dictionary = store.open_text(text, "probe_pins")
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty() and _main.get("_part_pins") != null:
			break
	await _settle()
	var pins: Control = _main.get("_part_pins")
	_check(store.share_id == ID and pins != null and fake.asked_comments > 0,
		"(b) opened with its link and signed in, its comments are asked for as its builder (%d asks)" % fake.asked_comments)
	if pins == null:
		return
	var named: Dictionary = pins.controls_by_name()
	var notice: String = str(pins.page_state().get("notice", ""))
	_check(named.has("pins_notice_show") and notice == "12 comments on parts of this model"
		and (_main.get("_notices") as Control).visible,
		"(b) the notice with the model's others: \"%s\"" % notice)
	if not named.has("pins_notice_show"):
		return
	await _press(named["pins_notice_show"])
	var listing: Dictionary = pins.page_state().get("list", {})
	var rows: Array = listing.get("rows", [])
	var bodies: Array = rows.map(func(row: Dictionary) -> String: return str(row["body"]))
	var answered: Array = listed.map(func(one: Dictionary) -> String: return str(one["body"]))
	var numbers: Array = rows.map(func(row: Dictionary) -> int: return int(row["number"]))
	_check(bool(listing.get("open", false)) and bodies == answered and numbers == range(1, 13),
		"(b) Show lists the same pins as the answer, in its order, numbered 1 to 12 (%d of %d)"
			% [bodies.size(), answered.size()])
	var moved_words: String = str((rows[10] as Dictionary).get("where", "")) if rows.size() > 10 else ""
	var gone_row: Dictionary = rows[11] if rows.size() > 11 else {}
	_check(moved_words.ends_with(", moved since") and str(gone_row.get("where", "")) == "On version 1"
		and not bool(gone_row.get("pressable", true)) and not pins.controls_by_name().has("part_pin_12"),
		"(b) a moved part's pin says \"%s\"; one on a part taken off \"%s\", not pressed" % [
			moved_words, gone_row.get("where", "")])

	# Pressing each of ten: its part selected and framed.
	var right: int = 0
	var wrong: Array[String] = []
	for n: int in 10:
		var press: Control = pins.controls_by_name().get("part_pin_%d" % (n + 1))
		var meant: int = _brick_coloured(world, int(expected[n]))
		if press == null:
			wrong.append("%d: no part_pin_%d" % [n + 1, n + 1])
			continue
		await _into_view(press)
		await _press(press)
		await _camera_still()
		var chosen: Array = builder.selection.keys()
		if chosen == [meant] and _framed(meant):
			right += 1
		else:
			wrong.append("%d: selected %s, meant #%d, framed %s" % [n + 1, chosen, meant, _framed(meant)])
	for line: String in wrong.slice(0, 5):
		print("       " + line)
	_check(right == 10, "(b) pressing each of 10 selects its part and frames it (%d of 10)" % right)
	var moved_press: Control = pins.controls_by_name().get("part_pin_11")
	if moved_press != null:
		await _into_view(moved_press)
		await _press(moved_press)
		await _camera_still()
	_check(moved_press != null and builder.selection.keys() == [_brick_coloured(world, moved_colour)],
		"(b) a moved part's pin selects the part where it is now")
	await _picture("2_studio_pins.png")

	# Resolve, folded; Reopen, back.
	var resolve: Control = pins.controls_by_name().get("part_pin_resolve_1")
	if resolve != null:
		await _into_view(resolve)
		await _press(resolve)
		for _n: int in 30:
			await process_frame
	var fold: Control = pins.controls_by_name().get("part_pins_resolved")
	var after: Dictionary = pins.page_state()
	_check(fake.resolved_calls == [[100, true]] and int(after.get("open", 0)) == 11
		and fold != null and (fold as Button).text == "Resolved (1)"
		and not (pins.get("_dots") as Dictionary).has(100) and int(after.get("resolves", 0)) == 1,
		"(b) Resolve sends it, folds it under %s and takes its dot away (%s)" % [
			(fold as Button).text if fold != null else "nothing", fake.resolved_calls])
	if fold != null:
		await _into_view(fold)
		await _press(fold)
	var reopen: Control = pins.controls_by_name().get("part_pin_reopen_1")
	if reopen != null:
		await _into_view(reopen)
		await _press(reopen)
		for _n: int in 30:
			await process_frame
	_check(reopen != null and fake.resolved_calls.size() == 2 and fake.resolved_calls[1] == [100, false]
		and int(pins.page_state().get("open", 0)) == 12,
		"(b) Reopen brings it back, sent (%s)" % [fake.resolved_calls])
	_main.queue_free()
	for _n: int in 10:
		await process_frame


func _a_pin(id: int, colour: int, at: Array) -> Dictionary:
	return {"id": id, "version": 1, "step": null, "on_step": null, "body": "Look at this one (%d)" % id,
		"at": "2026-11-2%dT10:00:00+00:00" % (id % 3), "edited_at": null, "by": "Probe Friend %d" % (id % 4),
		"handle": null, "by_owner": false, "mine": false, "hidden": false, "older": false,
		"said": "on version 1", "parent": null, "resolved": false, "resolved_at": null,
		"pin": {"part": _part_of_colour.get(colour, "3001"), "colour": colour, "at": at, "section": "",
			"line": 4, "near": [], "full": true}}


# -- helpers ---------------------------------------------------------------------

## The part's brick in [param world] by its colour (each its own), or 0.
func _brick_coloured(world: BrickWorld, colour: int) -> int:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.color_code == colour:
			return brick.id
	return 0


func _a_free_brick(world: BrickWorld, store: ModelStore) -> BrickWorld.Brick:
	var dots: Dictionary = (_main.get("_part_pins") as Control).get("_placed")
	var taken: Dictionary = {}
	for id: int in dots:
		taken[int((dots[id] as Dictionary).get("brick", 0))] = true
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id) and not taken.has(brick.id) and _point_on(brick).x >= 0.0:
			return brick
	return null


## A point on [param brick] where the viewer picks it, in the model's room
## and under no panel or dot: its top's middle, or near it. (-1, -1) for none.
func _point_on(brick: BrickWorld.Brick) -> Vector2:
	var camera: Camera3D = _main.get("_camera")
	var library: PartLibrary = _main.get("_library")
	var verbs: EditVerbs = _main.get("_verbs")
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	if mesh == null:
		return Vector2(-1, -1)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	var room: Rect2 = _main.call("_model_rect")
	var dots: Array[Rect2] = []
	var pins: Control = _main.get("_part_pins")
	if pins != null:
		for id: int in (pins.get("_dots") as Dictionary):
			dots.append(((pins.get("_dots") as Dictionary)[id] as Control).get_global_rect().grow(4.0))
	var view: ShareView = _main.get("_share_view")
	var steps: Control = _main.get("_steps")
	for along: Vector2 in [Vector2.ZERO, Vector2(0.25, 0.0), Vector2(-0.25, 0.0), Vector2(0.0, 0.25),
			Vector2(0.0, -0.25), Vector2(0.25, 0.25), Vector2(-0.25, -0.25)]:
		var point := Vector3(box.get_center().x + along.x * box.size.x, box.end.y - 0.5,
			box.get_center().z + along.y * box.size.z)
		if camera.is_position_behind(point):
			continue
		var at: Vector2 = camera.unproject_position(point)
		if not room.grow(-20.0).has_point(at) or bool(_main.call("_over_panel_at", at)) \
				or (view != null and view.covers(at)) \
				or (steps != null and steps.is_visible_in_tree() and steps.get_global_rect().has_point(at)):
			continue
		var under_dot: bool = false
		for rect: Rect2 in dots:
			under_dot = under_dot or rect.has_point(at)
		if under_dot or verbs.brick_at(at) != brick.id:
			continue
		return at
	return Vector2(-1, -1)


## Whether the view is on [param brick_id]: its middle well inside the
## model's room, and the part not lost in it.
func _framed(brick_id: int) -> bool:
	var world: BrickWorld = _main.get("_world")
	var camera: Camera3D = _main.get("_camera")
	var library: PartLibrary = _main.get("_library")
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return false
	var box: AABB = (brick.transform * library.mesh_for(brick.part_id).bounds).abs()
	if camera.is_position_behind(box.get_center()):
		return false
	var room: Rect2 = _main.call("_model_rect")
	var at: Vector2 = camera.unproject_position(box.get_center())
	var across: float = camera.unproject_position(box.position).distance_to(camera.unproject_position(box.end))
	return at.distance_to(room.get_center()) < minf(room.size.x, room.size.y) * 0.2 \
		and across > minf(room.size.x, room.size.y) * 0.04


static func _near(given: Variant, want: Array) -> bool:
	if not given is Array or (given as Array).size() != 3 or want.size() != 3:
		return false
	for i: int in 3:
		if absf(float(given[i]) - float(want[i])) > 0.01:
			return false
	return true


func _steps_worked_out() -> void:
	var steps: StepsBar = _main.get("_steps") if _main != null else null
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _settle()


## The view come to rest: unmoved for 300 ms (it eases by the clock, and
## the frames here are not paced), 5 s at the most.
func _camera_still() -> void:
	var camera: Camera3D = _main.get("_camera")
	var last: Transform3D = camera.global_transform
	var since: int = Time.get_ticks_msec()
	var still_since: int = since
	while Time.get_ticks_msec() - since < 5000:
		await process_frame
		var now: Transform3D = camera.global_transform
		if now.origin.distance_to(last.origin) > 0.001 or not now.basis.is_equal_approx(last.basis):
			still_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - still_since > 300:
			break
		last = now
	await _settle()


## [param control] scrolled into sight in the list it is in, as a person
## scrolls to it.
func _into_view(control: Control) -> void:
	var up: Node = control.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).ensure_control_visible(control)
		for _n: int in 3:
			await process_frame


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = Vector2(1, 0)
	Input.parse_input_event(event)


func _button(at: Vector2, which: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	var mask: int = MOUSE_BUTTON_MASK_LEFT if which == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	event.button_mask = mask if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right_click(at: Vector2) -> void:
	_move(at)
	await process_frame
	_button(at, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	_button(at, MOUSE_BUTTON_RIGHT, false)
	await _settle()


## Press a button where it is on screen, with the mouse.
func _press(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, MOUSE_BUTTON_LEFT, true)
	await process_frame
	_button(at, MOUSE_BUTTON_LEFT, false)
	await _settle()


func _touch(at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = down
	event.position = _as_event(at)
	Input.parse_input_event(event)


func _key(code: Key, shift: bool) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	for _n: int in 4:
		await process_frame


## Viewport coordinates as the window's, which an event carries: the
## interface is scaled, so the two differ (see feel_probe.gd).
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## A picture, windowed and asked for (--pictures=DIR).
func _picture(name: String) -> void:
	if _pictures.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_pictures)
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(_pictures.path_join(name))
		print("     wrote %s" % _pictures.path_join(name))


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "comments on parts: every check passed")
	quit(1 if _failures else 0)
