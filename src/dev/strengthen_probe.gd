## View, Stress's Strengthen (APP_UX8 #8, strengthen): a weak joint fixed in
## one action, in the window, as a person does it, and by their Claude.
##
##   godot --path . --resolution 1400x900 --script src/dev/strengthen_probe.gd [-- --shots=DIR]
##
## Through the way in first: the sign-in screen up over the app
## (gate_for_probe), a throwaway account signed in by the admin key and a
## password, the screen gone; the account deleted at the end. Needs .env
## (SUPABASE_URL, SUPABASE_SECRET_KEY).
##
## Ten models with a weak joint each, worked out so: a 2x10 plate loaded on
## the top stud of a column of 1x1s; a one-wide wall in stack bond, its right
## half on the footing's last stud; a tower of 2x4s on one corner stud; a
## Technic 1 x 16 on one friction pin, loaded; a liftarm on one frictionless
## pin; a 2x16 loaded out from a column of 2x2s; a crane arm on one stud of a
## column; a wing on one row of two studs with tanks at its tip; a balcony on
## one stud of a wall's top; and a 2x4 resting half over a tile's edge. For
## each, Stress on, the weakest row pressed as a hand presses it; and the bar:
##   - Strengthen is offered, the fix drawn as a ghost where it would go;
##   - pressed, it adds 1 to 3 parts, each with room (nothing of the model in
##     its boxes, as a part put down by hand is checked), and Stress weighs
##     the joint above its working load: the part past it no longer red or
##     amber, or held more than one way; and no joint past its own that was not;
##   - one undo puts the model back to the byte;
##   - weakest_joints answers the joint with its fix as a filled-in edit_model
##     call, the same fix in the same words; that call made as given gives
##     the model Strengthen gave, to the byte, and one undo takes it off.
## Across the ten, a tie, a prop and a pin each. Then From my bricks: on the
## cantilever, with a collection that has the prop's part in red only, the
## fix is red and "All from your bricks", over MCP too (mine=true); with
## none of it, it says one is not theirs. A picture of each fix's ghost.
extends SceneTree

const SHOTS := "user://strengthen"
const UP := "1 0 0 0 1 0 0 0 1"
const TURN := "0 0 1 0 1 0 -1 0 0"
## View, Stress's red and amber (StressView.WEAK, CLOSE).
const WEAK := 1.0
const CLOSE := 2.0

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _store: ModelStore
var _socket: CommandSocket
var _out: String = SHOTS
var _email: String = ""
var _password: String = ""
var _size: String = ""
var _kinds: Dictionary = {}


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
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	ShellPrefs.kept_by_a_check = true
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	var window: Vector2i = root.get_window().size
	_size = "%dx%d" % [window.x, window.y]
	print("in a %s window" % _size)
	if not await _way_in():
		await _finish()
		return
	var models: Dictionary = _models()
	for name: String in models:
		await _model(name, models[name])
	_check("across the ten, a tie, a prop and a pin each: %s" % _kinds,
		_kinds.has("tie") and _kinds.has("prop") and _kinds.has("pin"))
	await _from_my_bricks(models["cantilever"])
	await _finish()


# -- the way in ---------------------------------------------------------------


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("strengthen")
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
## token bucket, not a code's verify.
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


# -- one model ------------------------------------------------------------------


func _model(name: String, text: String) -> void:
	print("\n  %s" % name.replace("_", " "))
	await _open(name, text)
	var stress: StressView = _shell.stress
	if not stress.on:
		_shell.run("stress")
	await _weighed()
	var panel: Variant = stress.get("panel")
	if panel == null or not (panel as Control).is_visible_in_tree():
		_check("with Stress on, its panel lists the weak joints (there is none)", false)
		return
	var entries: Array = panel.get("entries")
	var row: int = -1
	for n: int in entries.size():
		if float(entries[n].get("margin")) < CLOSE:
			row = n
			break
	if row < 0:
		_check("Stress lists a joint past its working load or near it: %s" % panel.call("fields")["count"],
			false)
		return
	var weak: Object = entries[row]
	var weak_id: int = int(weak.get("id"))
	var touch: bool = weak.get("joint") == null
	_check("Stress lists #%d %s, margin %.2f (%s)" % [weak_id, _part_of(weak_id),
		float(weak.get("margin")), panel.call("fields")["count"]], true)
	var reds_before: Dictionary = _reds()
	var before: String = _store.to_text(name, true)
	var count_before: int = _world.brick_count()
	var ids_before: Dictionary = _ids()
	# The row pressed as a hand presses it.
	await _click(panel.call("controls_by_name").get("stress_row_%d" % row))
	await _offered(panel)
	var shown: Dictionary = panel.call("fields")
	var fix: Variant = panel.get("fix")
	_check("Strengthen is offered: \"%s\"" % shown.get("offer", ""), fix != null
		and bool(shown.get("strengthen", false))
		and str(shown.get("offer", "")).begins_with("Strengthen adds "))
	if fix == null:
		return
	var parts: Array = fix.get("parts")
	_kinds[str(fix.get("kind"))] = int(_kinds.get(str(fix.get("kind")), 0)) + 1
	var ghost: Variant = panel.get("_ghost")
	var ghost_box: AABB = (ghost as MeshInstance3D).get_aabb() if ghost is MeshInstance3D else AABB()
	_check("...drawn as a ghost where it would go (%d part%s, a %s)" % [parts.size(),
		"" if parts.size() == 1 else "s", fix.get("kind")], ghost is MeshInstance3D
		and (ghost as MeshInstance3D).visible and ghost_box.size.length() > 1.0
		and ghost_box.grow(1.0).encloses(_parts_box(parts)))
	_camera.frame(_model_box().merge(ghost_box), 1.25)
	await _frames(20)
	await _shot("%s_%s" % [name, _size])
	# Strengthen pressed.
	await _click(panel.call("controls_by_name").get("stress_strengthen"))
	await _weighed()
	var made: Array = []
	for id: int in _ids():
		if not ids_before.has(id):
			made.append(id)
	var same: bool = made.size() == parts.size()
	for n: int in mini(made.size(), parts.size()):
		var brick: BrickWorld.Brick = _world.get_brick(made[n])
		same = same and brick.part_id == str(parts[n]["part"]) \
			and brick.transform.origin.is_equal_approx((parts[n]["at"] as Transform3D).origin)
	_check("pressed, it adds %d part%s, those shown: %s" % [made.size(), "" if made.size() == 1
		else "s", ", ".join(made.map(func(id: int) -> String: return _part_of(id)))],
		made.size() >= 1 and made.size() <= 3 and same)
	var in_way: Array = []
	for id: int in made:
		for other: int in _builder.lattice.blockers_boxes(_builder.lattice.boxes_of(id), id):
			in_way.append("#%d %s in #%d %s" % [id, _part_of(id), other, _part_of(other)])
	_check("...each with room: %s" % ("nothing in its way" if in_way.is_empty()
		else "; ".join(in_way)), in_way.is_empty() and not made.is_empty())
	var margin: float = stress.margin_of(weak_id)
	var report: Stability.Report = stress.report
	var tips: bool = false
	for piece: Dictionary in report.tipping:
		if (piece["ids"] as Array).has(weak_id):
			tips = true
	var reds: Dictionary = _reds()
	var new_reds: Array = reds.keys().filter(func(id: int) -> bool: return not reds_before.has(id))
	_check("...and Stress weighs it above its working load: %s; past their own %d before, %d now, %d not before" % [
		("it no longer tips off" if not tips else "it still tips off") if touch else (
			"held more than one way" if margin == INF else "margin %.2f" % margin),
		reds_before.size(), reds.size(), new_reds.size()], (not tips if touch else margin >= WEAK)
		and not reds.has(weak_id) and new_reds.is_empty())
	var after: String = _store.to_text(name, true)
	# One undo.
	_shell.run("undo")
	await _weighed()
	var undone: String = _store.to_text(name, true)
	_check("one undo puts the model back to the byte (%d parts, %d before)" % [_world.brick_count(),
		count_before], undone == before and _world.brick_count() == count_before)
	# The same over MCP: weakest_joints' filled-in call, made as given.
	var said: String = await _say("weakest_joints", {})
	var line: String = _line_for(said, weak_id)
	var call: Variant = JSON.parse_string(line.get_slice("Call edit_model ", 1)) \
		if line.contains("Call edit_model ") else null
	_check("weakest_joints answers #%d with its fix, as Strengthen says it: \"%s\"" % [weak_id,
		line.strip_edges()], call is Dictionary and line.contains(str(fix.get("what"))))
	if not call is Dictionary:
		return
	var answer: String = await _say("edit_model", call)
	await _weighed()
	var given: String = _store.to_text(name, true)
	_check("...that call made as given gives the model Strengthen gave, to the byte (%s)"
		% answer.get_slice("\n", 0).left(120), given == after)
	if given != after:
		_diff(after, given)
	_shell.run("undo")
	await _weighed()
	_check("...and one undo takes it off", _store.to_text(name, true) == before)


# -- From my bricks -------------------------------------------------------------


## The cantilever's prop with a collection that has it in red alone, then
## with a collection that has none of it.
func _from_my_bricks(text: String) -> void:
	print("\n  From my bricks, on the cantilever")
	await _open("cantilever", text)
	var store: CollectionStore = _shell.collection_store
	var kept: Dictionary = store.on_hand
	store.on_hand = {Collection.key_of("2453b", 4, _library): 2,
		Collection.key_of("3005", 71, _library): 5}
	var stress: StressView = _shell.stress
	if not stress.on:
		_shell.run("stress")
	await _weighed()
	var panel: Variant = stress.get("panel")
	await _click(panel.call("controls_by_name").get("stress_row_0"))
	await _offered(panel)
	var mine: Variant = panel.call("controls_by_name").get("stress_mine")
	_check("with a collection, From my bricks is offered beside Strengthen, off",
		mine is CheckBox and (mine as CheckBox).is_visible_in_tree()
		and not (mine as CheckBox).button_pressed)
	await _click(mine)
	await _offered(panel)
	var fix: Variant = panel.get("fix")
	var shown: Dictionary = panel.call("fields")
	shown.merge({"offer": "", "mine": false})
	var colours: Array = (fix.get("parts") as Array).map(func(item: Dictionary) -> int:
		return int(item["color"])) if fix != null else []
	_check("ticked, the fix is of their parts, red as they have it: \"%s\" (colours %s)" % [
		shown["offer"], colours], fix != null and bool(shown["mine"])
		and str(shown["offer"]).ends_with("All from your bricks.") and colours == [4])
	var said: String = await _say("weakest_joints", {"mine": true})
	var line: String = _line_for(said, int(fix.get("weak")) if fix != null else 0)
	_check("...and so over MCP, mine=true: \"%s\"" % line.strip_edges(),
		line.contains("All from your bricks.") and line.contains("\"color\":4"))
	store.on_hand = {Collection.key_of("3005", 4, _library): 10}
	await _click(mine)
	await _click(mine)
	await _offered(panel)
	shown = panel.call("fields")
	shown.merge({"offer": ""})
	_check("with none of it theirs, it says so: \"%s\"" % shown["offer"],
		str(shown["offer"]).ends_with("Not all from your bricks: you have none of one left."))
	await _shot("from_my_bricks_%s" % _size)
	store.on_hand = kept
	await _click(mine)


# -- the models -----------------------------------------------------------------


## An LDraw line: [param part] with its top's middle at x, z and its bottom
## [param bottom] LDU up, [param tall] high.
static func _line(colour: int, part: String, x: float, bottom: float, z: float, tall: float,
		turned: bool = false) -> String:
	return "1 %d %d %d %d %s %s.dat" % [colour, int(x), -int(bottom + tall), int(z),
		TURN if turned else UP, part]


static func _stack(colour: int, part: String, x: float, from: float, z: float, tall: float,
		count: int, turned: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	for n: int in count:
		out.append(_line(colour, part, x, from + n * tall, z, tall, turned))
	return out


static func _models() -> Dictionary:
	var out: Dictionary = {}
	var a := PackedStringArray()
	a.append_array(_stack(71, "3005", 0, 0, 0, 24, 5))
	a.append(_line(1, "3832", 90, 120, 10, 8))
	a.append_array(_stack(14, "3003", 170, 128, 10, 24, 6))
	out["cantilever"] = a
	var b := PackedStringArray([_line(71, "3009", 60, 0, 0, 24)])
	b.append_array(_stack(4, "3010", 60, 24, 0, 24, 8))
	b.append_array(_stack(4, "3008", 180, 24, 0, 24, 8))
	out["one_wide_wall"] = b
	var c := PackedStringArray([_line(15, "3001", 0, 0, 0, 24)])
	c.append_array(_stack(1, "3001", 60, 24, 20, 24, 16))
	out["tower_on_one_stud"] = c
	var d := PackedStringArray()
	d.append_array(_stack(71, "3010", 0, 0, -50, 24, 3))
	d.append(_line(71, "3701", 0, 72, -50, 24))
	d.append(_line(4, "3703", 120, 72, -70, 24))
	d.append("1 1 20 -86 -60 0 0 -1 0 1 0 1 0 0 2780.dat")
	d.append_array(_stack(14, "3004", 260, 96, -70, 24, 8))
	out["beam_on_one_pin"] = d
	var e := PackedStringArray()
	e.append_array(_stack(71, "3003", 0, 0, 0, 24, 5))
	e.append(_line(1, "4282", 140, 120, 0, 8))
	e.append_array(_stack(14, "3003", 280, 128, 0, 24, 14))
	out["long_cantilever"] = e
	var f := PackedStringArray()
	f.append_array(_stack(71, "3003", 0, 0, 0, 24, 4))
	f.append(_line(4, "3460", 80, 96, -10, 8))
	f.append_array(_stack(14, "3004", 140, 104, -10, 24, 8))
	out["crane_arm"] = f
	var g := PackedStringArray()
	g.append_array(_stack(15, "3001", 0, 0, 0, 24, 3))
	g.append(_line(15, "3035", 100, 72, 0, 8))
	g.append_array(_stack(0, "3001", 160, 80, 0, 24, 3, true))
	out["wing"] = g
	var h := PackedStringArray()
	h.append_array(_stack(71, "3010", 0, 0, 50, 24, 3))
	h.append(_line(71, "3701", 0, 72, 50, 24))
	h.append("1 0 20 -86 40 0 0 -1 0 1 0 1 0 0 3673.dat")
	h.append("1 4 120 -86 30 0 0 1 1 0 0 0 1 0 41239.dat")
	out["arm_on_free_pin"] = h
	var k := PackedStringArray()
	for course: int in 3:
		var shift: float = 40.0 if course % 2 == 1 else 0.0
		for n: int in 3:
			k.append(_line(71, "3001", shift + n * 80.0 - 80.0, course * 24, 0, 24))
	k.append(_line(4, "3795", 120, 72, 60, 8, true))
	k.append_array(_stack(14, "3003", 120, 80, 100, 24, 6))
	out["balcony"] = k
	var m := PackedStringArray()
	m.append_array(_stack(71, "3003", 0, 0, 0, 24, 2))
	m.append(_line(71, "3068b", 0, 48, 0, 8))
	m.append(_line(1, "3001", 30, 56, 0, 24))
	m.append_array(_stack(14, "3003", 50, 80, 0, 24, 2))
	out["tile_overhang"] = m
	var texts: Dictionary = {}
	for name: String in out:
		texts[name] = "0 %s\n0 Name: %s.ldr\n0 Author: Brickworks\n%s\n" % [name.replace("_", " "),
			name, "\n".join(out[name] as PackedStringArray)]
	return texts


# -- the app ----------------------------------------------------------------------


func _open(name: String, text: String) -> void:
	_main.call("clear_model")
	await _frames(10)
	var result: Dictionary = _store.open_text(text, name)
	(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
	await _frames(30)
	_camera.frame(_model_box(), 1.3)
	await _weighed()


## Until the model as it stands is weighed, and Stress has drawn it.
func _weighed() -> void:
	await _frames(4)
	for _n: int in 3000:
		await process_frame
		if int(_main.get("_stability_revision")) == _world.revision and not bool(_main.get("_weighing")) \
				and not Working.is_busy():
			break
	await _frames(10)


## Until the panel has looked for the chosen row's fix.
func _offered(panel: Variant) -> void:
	for _n: int in 1200:
		await process_frame
		if not bool(panel.call("fields").get("finding", false)):
			break
	await _frames(6)


func _say(tool: String, arguments: Dictionary) -> String:
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


## weakest_joints' line for the fix of the joint holding [param id].
static func _line_for(said: String, id: int) -> String:
	for line: String in said.split("\n"):
		if line.begins_with("  #%d: " % id):
			return line
	return ""


## A click on [param control] where it is on the screen, as a hand makes it.
func _click(control: Variant) -> void:
	if not control is Control or not (control as Control).is_visible_in_tree():
		print("    no such control to click")
		return
	var at: Vector2 = (control as Control).get_global_rect().get_center()
	var scale: float = root.get_final_transform().get_scale().x
	Input.warp_mouse(at * scale)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at * scale
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(10)


## The parts past a joint past its working load, and in a piece that falls,
## as Stress counts them: id -> true.
func _reds() -> Dictionary:
	var out: Dictionary = {}
	var report: Stability.Report = _shell.stress.report
	if report == null:
		return out
	for piece: Dictionary in report.tipping:
		out[int((piece["ids"] as Array)[0])] = true
	for id: Variant in report.margins:
		if not _store.scenery.has(int(id)) and (report.margins[id] as Balance.JointLoad).ratio > 1.0:
			out[int(id)] = true
	return out


func _ids() -> Dictionary:
	var out: Dictionary = {}
	for item: Variant in _world.bricks():
		out[(item as BrickWorld.Brick).id] = true
	return out


func _part_of(id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	return brick.part_id if brick != null else "?"


func _model_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if _store.scenery.has(brick.id):
			continue
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var one: AABB = (brick.transform * part.bounds).abs()
		box = one if first else box.merge(one)
		first = false
	return box


func _parts_box(parts: Array) -> AABB:
	var box := AABB()
	for n: int in parts.size():
		var part: Lbm.PartMesh = _library.mesh_for(str(parts[n]["part"]))
		var one: AABB = ((parts[n]["at"] as Transform3D) * part.bounds).abs()
		box = one if n == 0 else box.merge(one)
	return box


static func _diff(want: String, got: String) -> void:
	var a: PackedStringArray = want.split("\n")
	var b: PackedStringArray = got.split("\n")
	for n: int in maxi(a.size(), b.size()):
		var x: String = a[n] if n < a.size() else "<none>"
		var y: String = b[n] if n < b.size() else "<none>"
		if x != y:
			print("    line %d: Strengthen's \"%s\", the call's \"%s\"" % [n + 1, x, y])


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s.png" % [_out, name]
	image.save_png(ProjectSettings.globalize_path(path) if path.begins_with("user://")
		or path.begins_with("res://") else path)
	print("    picture: %s" % path)


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("\n%s: %d failed" % ["FAIL" if _failures > 0 else "PASS", _failures])
	if _world != null:
		_world.clear()
	await process_frame
	quit(1 if _failures > 0 else 0)
