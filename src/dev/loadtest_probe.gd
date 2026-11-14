## View, Stress's Lift (APP_UX8 #13, loadtest): a model lifted by a part, as
## a person does it in the window, and by their Claude.
##
##   godot --path . --resolution 1400x900 --script src/dev/loadtest_probe.gd [-- --shots=DIR]
##
## (and at 1280 x 720: PROBE_SIZE=1280x720 tools/probe.sh loadtest_probe.)
## Through the way in first: the sign-in screen up over the app
## (gate_for_probe), a throwaway account signed in by the admin key and a
## password, the screen gone; the account deleted at the end. Needs .env
## (SUPABASE_URL, SUPABASE_SECRET_KEY).
##
## Each lift is made as a hand makes it: Stress on, Lift pressed, then a click
## on the part where the view shows it. Worked out by hand from the clutch
## (Balance: a stud lets go at 1.92 N into a part two studs wide, 3.07 N into
## one a stud wide, levered about the edge it would turn on, M = Σ F·dᵢ, the
## pull added where a part hangs) and the parts' weights (Stability.grams):
## 1. a wall of eight 1 x 4 bricks, two courses running bond a stud apart,
##    lifted by its top brick at one end: each course's next brick stands on
##    one stud of the brick under it, and the first of those carries the six
##    bricks past it, 0.35 of what lets it go by hand. It holds: nothing
##    comes away, said in the panel, the joint's number the hand's to 1%.
##    No wall of eight 1 x 4 bricks lets go: the most any can put on one
##    stud is under what lets it go;
## 2. the same wall of sixteen: by hand that one-stud joint carries fourteen
##    bricks at 2.02 times what lets it go, and lets go first; the brick in
##    the hand holds the one under it. The panel names it first, red, and
##    the fourteen that come away are exactly the hand's, tinted red, the
##    part lifted blue; its row pressed selects them and keeps the lift; the
##    same over MCP in 1 call (weakest_joints lift_by=). Then the far half
##    taken off over MCP: lifted again by itself, it holds; one undo, and
##    the fourteen come away again;
## 3. the car (models/car.ldr) lifted by its roof: its 52 g hang on the
##    windscreen's studs and the roof's hinge, and nothing comes away, said in
##    the panel and over MCP in 1 call, the same; by a headlight's 1 x 1 round
##    plate instead, the car hangs on one stud and comes away whole: the 60
##    parts named, the same over MCP;
## 4. Lift pressed again: the model stands, Stress's own colours and list
##    back; over MCP with Stress off the lift changes nothing in the window.
## Pictures in --shots=DIR (else user://loadtest). Exits non-zero when a
## check fails.
extends SceneTree

const SHOTS := "user://loadtest"
const UP := "1 0 0 0 1 0 0 0 1"
## The gravity Balance weighs with, and its LDU in cm.
const GRAVITY := 9.81
const TO_CM := 0.04
## How near the hand's number the app's must be.
const WITHIN := 0.01

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
var _size: String = ""


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
	await _wall_of_eight()
	await _wall_of_sixteen()
	await _car()
	await _set_down()
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
	_email = SignInHelper.throwaway("loadtest")
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
	var password: String = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- 1. a wall of eight ---------------------------------------------------------------


func _wall_of_eight() -> void:
	print("\n1. a wall of eight 1 x 4 bricks, lifted by its top brick at one end")
	await _open("wall_of_eight", _wall(4))
	var courses: Array = _courses()
	var top: Array = courses[0]
	var under: Array = courses[1]
	var hand: Dictionary = _hand(4)
	if not await _lift_by_hand(int(top[0])):
		return
	var lifted: RefCounted = _lift()
	var fields: Dictionary = _panel().call("fields")
	var one: Balance.JointLoad = lifted.call("joint_of", int(top[1]))
	var give: float = _give_of(one) if one != null else -1.0
	_check("by hand, the second top brick stands on 1 stud of the first under it, carrying %d bricks, %.2f g, %.3f N·cm against %.3f where it lets go: %.3f" % [
		hand["bricks"], hand["grams"], hand["moment"], hand["ultimate"], hand["give"]], true)
	_check("the app weighs that joint at %.3f of what lets it go, the hand's within 1%%: %s" % [give,
		"#%d on #%d on %d stud" % [one.beyond, one.held_by, one.studs] if one != null else "no such joint"],
		one != null and one.held_by == int(under[0]) and one.studs == 1
		and absf(give - float(hand["give"])) <= WITHIN * float(hand["give"]))
	_check("so it holds, and nothing comes away: \"%s\"" % fields.get("count", ""),
		(lifted.get("gone") as Dictionary).is_empty()
		and str(fields.get("count", "")).contains("everything comes with it"))
	_check("the brick lifted by is blue, nothing red: %s" % _tint_counts(),
		_tint_of(int(top[0])) == _held_tint() and _tinted(StressView.RED).is_empty())
	await _shot("wall_of_eight_%s" % _size)


# -- 2. a wall of sixteen ------------------------------------------------------------


func _wall_of_sixteen() -> void:
	print("\n2. the same wall of sixteen, lifted the same way")
	var name: String = "wall_of_sixteen"
	await _open(name, _wall(8))
	var courses: Array = _courses()
	var top: Array = courses[0]
	var under: Array = courses[1]
	var hand: Dictionary = _hand(8)
	_check("by hand, the one-stud joint under the second top brick carries %d bricks, %.2f g, %.3f N·cm against %.3f where it lets go: %.3f, so it lets go" % [
		hand["bricks"], hand["grams"], hand["moment"], hand["ultimate"], hand["give"]],
		float(hand["give"]) > 1.0)
	# The fourteen past it, by hand: every brick but the one lifted and the
	# one it holds.
	var want: Dictionary = {}
	for id: Variant in top.slice(1) + under.slice(1):
		want[int(id)] = true
	var by_hand: bool = await _lift_by_hand(int(top[0]))
	if by_hand:
		var lifted: RefCounted = _lift()
		var fields: Dictionary = _panel().call("fields")
		var away: Array = lifted.get("away")
		var first: RefCounted = away[0] if not away.is_empty() else null
		var joint: Balance.JointLoad = first.get("joint") if first != null else null
		_check("the app lets that joint go first, at %.3f, the hand's within 1%%" % (
			float(first.get("give")) if first != null else -1.0), joint != null
			and joint.beyond == int(top[1]) and joint.held_by == int(under[0]) and joint.studs == 1
			and absf(float(first.get("give")) - float(hand["give"])) <= WITHIN * float(hand["give"]))
		var gone: Dictionary = lifted.get("gone")
		_check("the %d that come away are the hand's %d: every brick but the one in the hand and the one under it"
			% [gone.size(), want.size()], _same_keys(gone, want))
		_check("the panel heads with it: \"%s\"" % fields.get("count", ""),
			str(fields.get("count", "")) == "Lifted by Brick 1 x 4: 14 parts come away, 23 g of 27")
		var rows: Array = fields.get("rows", [])
		_check("and names it first, red: \"%s\"" % (rows[0] if not rows.is_empty() else ""),
			not rows.is_empty() and str(rows[0]) == "lets go · Brick 1 x 4 and 13 more"
			and (fields.get("kinds", []) as Array).slice(0, 1) == ["lets go"])
		var reds: Dictionary = _tinted(StressView.RED)
		_check("the fourteen are tinted red, the brick lifted blue, the one it holds faded: %s"
			% _tint_counts(), _same_keys(reds, want) and _tint_of(int(top[0])) == _held_tint()
			and not _world.stressed_ids().has(int(under[0])))
		await _shot("%s_%s" % [name, _size])
		# Its row pressed: the parts selected and framed, the lift kept.
		await _click(_panel().call("controls_by_name").get("stress_row_0"))
		fields = _panel().call("fields")
		_check("its row pressed says why: \"%s\"" % fields.get("why", ""), str(fields.get("why", "")).begins_with(
			"Brick 1 x 4 lets go of Brick 1 x 4; 23 g is levered off it on 1 stud; 2.02 times what lets it go"))
		_check("...and selects the %d that come away, the lift kept by the brick in the hand"
			% _builder.selection.size(), _same_keys(_builder.selection, want)
			and _lift() != null and int(_lift().get("by")) == int(top[0]))
		await _shot("%s_row_%s" % [name, _size])
	# Over MCP, in one call.
	var said: String = await _say("weakest_joints", {"lift_by": int(top[0])})
	var listed: Dictionary = _ids_listed(said, "14 parts come away with it")
	_check("over MCP, weakest_joints lift_by=%d: \"%s\"" % [int(top[0]), said.get_slice("\n", 0)],
		said.begins_with("Lifted by #%d Brick 1 x 4: 14 parts come away, 23 g of 27." % int(top[0])))
	_check("...naming the same %d parts" % listed.size(), _same_keys(listed, want))
	if not by_hand:
		return
	# The far half taken off over MCP: lifted again, it holds; undone, it
	# lets go again.
	var far: Array = top.slice(4) + under.slice(4)
	await _say("edit_model", {"remove": far})
	await _weighed()
	await _lifted_again()
	var fields: Dictionary = _panel().call("fields")
	_check("the far half taken off (%d parts), it is lifted again by itself and holds: \"%s\""
		% [far.size(), fields.get("count", "")], str(fields.get("count", "")).contains(
		"everything comes with it") and _tinted(StressView.RED).is_empty())
	_shell.run("undo")
	await _weighed()
	await _lifted_again()
	fields = _panel().call("fields")
	_check("one undo, and the fourteen come away again: \"%s\"" % fields.get("count", ""),
		str(fields.get("count", "")) == "Lifted by Brick 1 x 4: 14 parts come away, 23 g of 27"
		and _same_keys(_tinted(StressView.RED), want))


# -- 3. the car ------------------------------------------------------------------


func _car() -> void:
	print("\n3. the car, lifted by its roof, then by a headlight's round plate")
	await _open("car", FileAccess.get_file_as_string("res://models/car.ldr"))
	var roof: int = _part("4213")
	if await _lift_by_hand(roof):
		var fields: Dictionary = _panel().call("fields")
		_check("by its roof, nothing comes away: \"%s\"" % fields.get("count", ""),
			(_lift().get("gone") as Dictionary).is_empty()
			and str(fields.get("count", "")) == "Lifted by Hinge Car Roof 4 x 4: everything comes with it, 52 g")
		await _shot("car_by_its_roof_%s" % _size)
	var said: String = await _say("weakest_joints", {"lift_by": roof})
	_check("over MCP in 1 call, the same: \"%s\"" % said.get_slice("\n", 0),
		said.begins_with("Lifted by #%d Hinge Car Roof 4 x 4: everything comes with it, 52 g." % roof))
	var plate: int = _headlight_plate()
	var want: Dictionary = {}
	for item: Variant in _world.bricks():
		var id: int = (item as BrickWorld.Brick).id
		if id != plate and not _store.scenery.has(id):
			want[id] = true
	_camera.frame(_box_of(plate).grow(60.0), 1.4)
	await _settled()
	if await _lift_by_hand(plate, false):
		var fields: Dictionary = _panel().call("fields")
		_check("by a headlight's 1 x 1 round plate, the car hangs on its one stud and comes away whole: \"%s\""
			% fields.get("count", ""), _same_keys(_lift().get("gone"), want)
			and str(fields.get("count", "")) == "Lifted by Plate 1 x 1 Round: 60 parts come away, 52 g of 52")
		_camera.frame(_model_box(), 1.3)
		await _settled()
		await _shot("car_by_a_headlight_%s" % _size)
	said = await _say("weakest_joints", {"lift_by": plate})
	var listed: Dictionary = _ids_listed(said, "60 parts come away with it")
	_check("over MCP in 1 call, the same %d parts named: \"%s\"" % [listed.size(),
		said.get_slice("\n", 0)], _same_keys(listed, want) and said.begins_with(
		"Lifted by #%d Plate 1 x 1 Round: 60 parts come away, 52 g of 52." % plate))


# -- 4. set down ------------------------------------------------------------------


func _set_down() -> void:
	print("\n4. Lift pressed again, and a lift over MCP with Stress off")
	await _click(_panel().call("controls_by_name").get("stress_lift"))
	await _weighed()
	var fields: Dictionary = _panel().call("fields")
	_check("Lift off: the model stands, Stress's own list back: \"%s\"" % fields.get("count", ""),
		not _lifting() and not bool(fields.get("lift", true))
		and not bool(fields.get("lifted", true)) and str(fields.get("count", "")).contains("past working load")
		and _tinted(_held_tint()).is_empty())
	_shell.run("stress")
	await _weighed()
	var before: Dictionary = _builder.selection.duplicate()
	var said: String = await _say("weakest_joints", {"lift_by": _part("4213")})
	_check("with Stress off, a lift over MCP answers (\"%s\") and changes nothing in the window"
		% said.get_slice("\n", 0), said.contains("everything comes with it") and not _shell.stress.on
		and not _world.is_stressed() and _same_keys(_builder.selection, before))


# -- the hand ----------------------------------------------------------------------


## The wall: two courses of [param count] 1 x 4 bricks, the lower a stud
## along, on the ground; grey on tan, so no brick's own colour reads as
## Stress's red or blue.
static func _wall(count: int) -> String:
	var lines := PackedStringArray(["0 wall", "0 Name: wall.ldr", "0 Author: Brickworks"])
	for k: int in count:
		lines.append("1 71 %d -48 0 %s 3010.dat" % [80 * k + 40, UP])
	for k: int in count:
		lines.append("1 19 %d -24 0 %s 3010.dat" % [80 * k + 60, UP])
	return "\n".join(lines) + "\n"


## The joint under the second top brick of [method _wall]'s wall of
## [param count] a course, lifted by the first, worked out by hand. The
## second top brick stands on one stud of the first brick under, [80, 100)
## LDU along, its middle at 90; past it hang every brick but the first two.
## A stud there is a stud's square, so the edge it would turn on is half a
## stud from its middle and its one stud levers 10 LDU about it. Pressed down
## onto that stud, the bricks past it lever it by their weight's reach past
## its middle, less the 10 LDU their pressing holds: M = w (d - 10). The
## studs go into the top brick, a stud wide: 3.07 N a stud where they let
## go, so it lets go at 3.07 N x 10 LDU.
func _hand(count: int) -> Dictionary:
	var grams_each: float = Stability.grams(_library.parts["3010"])
	var bricks: int = 2 * count - 2
	var along: float = 0.0
	for k: int in range(1, count):
		along += 80.0 * k + 40.0 + 80.0 * k + 60.0
	along /= bricks
	var weight: float = bricks * grams_each / 1000.0 * GRAVITY
	var moment: float = weight * (along - 90.0 - 10.0) * TO_CM
	var ultimate: float = Balance.ULTIMATE_ONE_WIDE_N * 10.0 * TO_CM
	return {"bricks": bricks, "grams": bricks * grams_each, "moment": moment, "ultimate": ultimate,
		"give": moment / ultimate}


# -- the app ----------------------------------------------------------------------


func _panel() -> Variant:
	return _shell.stress.get("panel")


# What Lift has, read by name: a checkout without Lift (the red run) reads
# nothing, and fails each check rather than the probe's compile.
func _lifting() -> bool:
	return _shell.stress.get("lifting") == true


func _lift() -> RefCounted:
	return _shell.stress.get("lift")


## The tint of the part lifted by (StressView.LIFTED).
func _held_tint() -> Color:
	return (load("res://src/ui/stress_view.gd") as Script).get_script_constant_map().get("LIFTED",
		Color.TRANSPARENT)


## How near letting go a joint is, as the panel says it (LiftTest.give_of).
func _give_of(one: Balance.JointLoad) -> float:
	var lifter: Variant = Later.PATHS.get(&"LiftTest")
	return load(str(lifter)).give_of(one) if lifter != null else -1.0


func _open(name: String, text: String) -> void:
	_main.call("clear_model")
	await _frames(10)
	var result: Dictionary = _store.open_text(text, name)
	(_main.get("_bar") as ModelBar).opened.emit(int(result["placed"]))
	await _frames(30)
	await _weighed()
	_camera.frame(_model_box(), 1.3)
	await _settled()


## Stress on, Lift pressed when it is not, and a click on part [param id]
## where the view shows it: until the lift by it has come in. With [param
## press] false, Lift is on already.
func _lift_by_hand(id: int, press: bool = true) -> bool:
	if not _shell.stress.on:
		_shell.run("stress")
		await _weighed()
	if press and not _lifting():
		await _click(_panel().call("controls_by_name").get("stress_lift"))
	_check("Lift is on, the panel asking for the part: \"%s\"" % _panel().call("fields").get("count", ""),
		_lifting() and bool(_panel().call("fields").get("lift", false)))
	if not _lifting():
		return false
	await _click_part(id)
	for _n: int in 600:
		var lifted: RefCounted = _lift()
		if lifted != null and int(lifted.get("by")) == id:
			break
		await process_frame
	await _frames(6)
	var lifted: RefCounted = _lift()
	_check("a click on #%d %s lifts the model by it" % [id, _part_of(id)], lifted != null
		and int(lifted.get("by")) == id and bool(_panel().call("fields").get("lifted", false)))
	return lifted != null and int(lifted.get("by")) == id


## Until a change has been lifted again.
func _lifted_again() -> void:
	for _n: int in 600:
		if _lift() != null and _shell.stress.get("_lift_revision") == _world.revision:
			break
		await process_frame
	await _frames(6)


## Until the model as it stands is weighed, and Stress has drawn it.
func _weighed() -> void:
	await _frames(4)
	for _n: int in 3000:
		await process_frame
		if int(_main.get("_stability_revision")) == _world.revision and not bool(_main.get("_weighing")) \
				and not Working.is_busy():
			break
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": 1,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


## The part numbers a session's answer lists after [param after]: "...: #2
## Brick 1 x 4, #10 Brick 1 x 4, ..." to the line's end.
static func _ids_listed(said: String, after: String) -> Dictionary:
	var out: Dictionary = {}
	for line: String in said.split("\n"):
		var at: int = line.find(after)
		if at < 0:
			continue
		var tail: String = line.substr(at + after.length())
		tail = tail.substr(tail.find(": ") + 2)
		for part: String in tail.split(", "):
			if part.begins_with("#"):
				out[part.trim_prefix("#").get_slice(" ", 0).to_int()] = true
	return out


## The non-floor bricks by course, top first, each along x.
func _courses() -> Array:
	var by_y: Dictionary = {}
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if _store.scenery.has(brick.id):
			continue
		var y: int = roundi(brick.transform.origin.y)
		if not by_y.has(y):
			by_y[y] = []
		(by_y[y] as Array).append(brick)
	var heights: Array = by_y.keys()
	heights.sort()
	heights.reverse()
	var out: Array = []
	for y: Variant in heights:
		var row: Array = by_y[y]
		row.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
			return a.transform.origin.x < b.transform.origin.x)
		out.append(row.map(func(brick: BrickWorld.Brick) -> int: return brick.id))
	return out


func _part(part_id: String) -> int:
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if brick.part_id.get_basename() == part_id and not _store.scenery.has(brick.id):
			return brick.id
	return 0


## A headlight brick's 1 x 1 round plate: the car's first, a 6141 (4073's
## other number) on the side stud of a 4070.
func _headlight_plate() -> int:
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if brick.part_id.get_basename() in ["6141", "4073"] and not _store.scenery.has(brick.id):
			return brick.id
	return 0


func _part_of(id: int) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	return brick.part_id if brick != null else "?"


func _tint_of(id: int) -> Variant:
	return _world.stressed_ids().get(id)


func _tinted(colour: Color) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in _world.stressed_ids():
		if _world.stressed_ids()[id] == colour:
			out[int(id)] = true
	return out


func _tint_counts() -> String:
	return "%d red, %d amber, %d blue" % [_tinted(StressView.RED).size(),
		_tinted(StressView.AMBER).size(), _tinted(_held_tint()).size()]


static func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if not b.has(int(key)):
			return false
	return true


## A click on the part where the view shows it: the first of a few points
## on its top the pointer finds it at, as a person aims at what they see.
func _click_part(id: int) -> void:
	var box: AABB = _box_of(id)
	var at: Vector2 = _camera.unproject_position(box.get_center())
	var found: bool = false
	for along: float in [0.0, -0.3, 0.3, -0.15, 0.15]:
		for deep: float in [0.0, -0.25, 0.25]:
			var point := Vector3(lerpf(box.position.x, box.end.x, 0.5 + along), box.end.y - 2.0,
				lerpf(box.position.z, box.end.z, 0.5 + deep))
			var screen: Vector2 = _camera.unproject_position(point)
			if not found and _shell.verbs.brick_at(screen) == id:
				at = screen
				found = true
	if not found:
		print("    #%d not under the pointer at %s (#%d is)" % [id, at, _shell.verbs.brick_at(at)])
	await _click_at(at)


func _box_of(id: int) -> AABB:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	return (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()


func _model_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if _store.scenery.has(brick.id) or _library.mesh_for(brick.part_id) == null:
			continue
		var one: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		box = one if first else box.merge(one)
		first = false
	return box


## A click on [param control] where it is on the screen, as a hand makes it.
func _click(control: Variant) -> void:
	if not control is Control or not (control as Control).is_visible_in_tree():
		print("    no such control to click")
		_failures += 1
		return
	await _click_at((control as Control).get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	var scale: float = root.get_final_transform().get_scale().x
	var motion := InputEventMouseMotion.new()
	motion.position = at * scale
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = (at * scale).floor()
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(10)


## The view eased to where it was sent.
func _settled() -> void:
	await create_timer(1.2).timeout
	await _frames(10)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
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
