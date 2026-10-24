## Building without the mouse: from launch, F6 (Tab, with a screen reader
## running), Tab and the arrows reach the toolbar, the bin's parts, a colour
## and the view cube's buttons, and a part is taken from the bin and put
## down on the model with keys alone.
##
##   godot --path . --resolution 1400x900 --script src/dev/a11y_keys_probe.gd
##   BRICKWORKS_API=http://127.0.0.1:9091 \
##     godot --path . --resolution 1400x900 --script src/dev/a11y_keys_probe.gd -- live
##
## First the way in, the sign-in screen, as a screen reader's user meets it.
## Offline (in the suite: the deployment at a port nobody answers): Try
## again reached and pressed; then the form, the keys in its email field,
## Tab on to Email me a code and Sign in with orangecheck (the browser's
## form, drawn here too); the code's step, its field, Sign in, Send a new
## code and Use a different address; the age question, the keys on its first month,
## a month chosen with Return, the year typed, Carry on. Live (with
## tools/web/relay_server.mjs on 9091 and .env): signed in by keys alone, a
## throwaway address typed, Return, the code minted on this side (a probe
## has no inbox) typed, Tab to Sign in and Return, the age answered by keys
## if asked; the account deleted at the end.
##
## Every press is a key event sent to the real scene, as a keyboard sends
## it; nothing is clicked and nothing is called on the app to move the
## focus. The app's own key handler stands aside while the keys are on a
## control, so the arrows walking the toolbar must leave the view still.
## And a click on a tile after all that must leave the keys with the model,
## as it always has (the CAD task test, 2026-10-16).
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _camera: CadCamera
var _store: ModelStore


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var live: bool = OS.get_cmdline_user_args().has("live")
	if not live:
		OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	await _way_in(live)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_store.keeps = false
	_main.call("clear_model")
	await _frames(20)

	_check("from launch nothing has the keys", _focused() == null)

	# F6 goes into the interface (Tab does with a screen reader running; here
	# Tab is the app's own, the panels folded), and Tab along it to the
	# toolbar.
	await _key(KEY_F6)
	var first: Control = _focused()
	_check("F6 from the model goes into the interface (%s)" % _said(first), first != null)
	if first is LineEdit:
		# A field gives the keys back to the model on Tab, as the owner asked
		# (FocusGuard), and the next F6 goes on from it.
		await _key(KEY_TAB)
		_check("Tab from a field gives the keys back to the model", _focused() == null)
		await _key(KEY_F6)
		var after: Control = _focused()
		_check("...and F6 goes on past it (%s)" % _said(after),
			after != null and after != first)
	var tool: Control = await _tab_until(func(c: Control) -> bool:
		return _shell.toolbar.is_ancestor_of(c), 80)
	_check("Tab reaches the toolbar (%s)" % _said(tool), tool != null)
	if tool == null:
		_finish()
		return
	_check("...whose button says its words and its key (%s)" % tool.accessibility_name,
		tool.accessibility_name.contains(", Ctrl+") or tool.accessibility_name.contains(", "))
	var facing: Transform3D = _camera.global_transform
	await _key(KEY_RIGHT)
	await _frames(20)
	var next_tool: Control = _focused()
	_check("Right walks the toolbar (%s to %s)" % [_said(tool), _said(next_tool)],
		next_tool != null and next_tool != tool and _shell.toolbar.is_ancestor_of(next_tool))
	_check("...and the view stays still while it does",
		_camera.global_transform.is_equal_approx(facing))
	# A tool chosen from the keyboard: Select, by Return on it.
	var select: Control = await _tab_until(func(c: Control) -> bool:
		return c.accessibility_name == "Select, V", 40)
	_check("Tab reaches Select, V", select != null)

	# On to the parts: past the bin's buttons, its search and its tabs.
	var tile: Button = await _tab_until(func(c: Control) -> bool:
		return c is Button and c.has_meta("part") and _bin.is_ancestor_of(c), 200)
	_check("Tab reaches a part in the bin (%s)" % _said(tile), tile != null)
	if tile == null:
		_finish()
		return
	await _key(KEY_DOWN)
	var below: Control = _focused()
	_check("Down walks the grid to the part below (%s)" % _said(below),
		below != null and below != tile and below.has_meta("part")
		and below.global_position.y > tile.global_position.y)
	await _key(KEY_RIGHT)
	var part_tile: Button = _focused() as Button
	_check("Right to the part beside it (%s)" % _said(part_tile),
		part_tile != null and part_tile.has_meta("part") and part_tile != below)
	if part_tile == null or not part_tile.has_meta("part"):
		_finish()
		return
	var part: String = str(part_tile.get_meta("part"))

	# Return takes it into hand, and the keys go to the model.
	var count: int = _count()
	await _key(KEY_ENTER)
	await _wait_for(func() -> bool: return _builder.has_preview(), 240)
	_check("Return takes %s into hand (%s)" % [part, _builder.held_part],
		_builder.held_part == part)
	_check("...and gives the keys to the model", _focused() == null)
	_check("...its ghost on the model, at the middle of the view", _builder.has_preview())
	var aimed: Variant = _builder.ghost_place()
	# The view's keys move what it is aimed at: D slides the view right.
	await _key(KEY_D)
	await _frames(30)
	var moved: Variant = _builder.ghost_place()
	_check("D slides the view, and the ghost with its middle (%s to %s)" % [aimed, moved],
		aimed != null and moved != null and aimed != moved)
	await _key(KEY_ENTER)
	await _frames(6)
	_check("Return puts it down: %d parts, then %d" % [count, _count()], _count() == count + 1)
	var placed: BrickWorld.Brick = _last_brick()
	_check("...the part it was, where its ghost was",
		placed != null and placed.part_id == part)

	# A colour, from the keyboard: F6 back in, Tab on to the palette.
	await _key(KEY_F6)
	var swatch: Button = await _tab_until(func(c: Control) -> bool:
		return c is PartsBin.Swatch, 400)
	_check("Tab reaches a colour (%s)" % _said(swatch), swatch != null)
	if swatch != null:
		await _key(KEY_RIGHT)
		var other: PartsBin.Swatch = _focused() as PartsBin.Swatch
		_check("Right to the colour beside it (%s)" % _said(other), other != null)
		if other != null:
			await _key(KEY_ENTER)
			_check("Return chooses %s (%d in hand)" % [other.color.name, _builder.held_color],
				_bin.selected_color() == other.color.code)

	# The view cube's buttons: a turn from the keyboard.
	var turn: Control = await _tab_until(func(c: Control) -> bool:
		return c.accessibility_name == "Turn the view left", 400)
	_check("Tab reaches the view cube's Turn the view left", turn != null)
	if turn != null:
		var before: Basis = _camera.global_transform.basis
		await _key(KEY_ENTER)
		await _frames(40)
		_check("Return on it turns the view",
			not _camera.global_transform.basis.is_equal_approx(before))
		var fit: Control = await _tab_until(func(c: Control) -> bool:
			return c.accessibility_name == "Fit, F", 10)
		_check("...and Tab goes on to Fit, F", fit != null)

	# A click still leaves the keys with the model.
	await _key(KEY_ESCAPE)
	await _frames(4)
	var some_tile: Button = _first_tile()
	if some_tile != null:
		var clicked: String = str(some_tile.get_meta("part"))
		await _click(some_tile.get_global_rect().get_center())
		# A control that let go of the keys while the button was down had its
		# click cancelled: the bin's tabs did nothing (bin_techniques_probe).
		_check("a click on a part takes it (%s in hand)" % _builder.held_part,
			_builder.held_part == clicked)
		_check("...and leaves the keys with the model (%s)" % _said(_focused()),
			_focused() == null)
	_finish()


## The sign-in screen, by keys alone: offline its every control reached,
## live signed in through it.
func _way_in(live: bool) -> void:
	var account: Account = _main.get("_account")
	var gate: SignInGate = _main.get("_gate")
	_check("the app has its sign-in screen", gate != null and account != null)
	if gate == null:
		return
	while account.state == Account.State.CHECKING:
		await account.changed
	await _frames(10)
	if live:
		await _sign_in_live(account, gate)
		return
	print("  the way in, offline")
	var named: Dictionary = gate.controls_by_name()
	await _key(KEY_F6)
	var retry: Control = await _tab_until(func(c: Control) -> bool:
		return c == named.get("signin_retry"), 10)
	_check("nowhere to sign in: F6 reaches Try again (%s)" % _said(retry), retry != null)
	var asked: Array[int] = [0]
	var count: Callable = func() -> void: asked[0] += 1
	account.changed.connect(count)
	await _key(KEY_ENTER)
	await _frames(20)
	account.changed.disconnect(count)
	_check("...and Return on it asks again (%d answers)" % asked[0], asked[0] > 0)
	while account.state == Account.State.CHECKING:
		await account.changed

	# Signed out, with somewhere to sign in: the form.
	# As a deployment that offers orangecheck to everybody, and says where
	# the desktop opens it (oc237: the form asks the deployment now, where
	# this probe once set SignInForm.offers_orangecheck).
	if account.deployment != null:
		account.deployment.orangecheck_for_everyone = true
		account.deployment.orangecheck_native = {"project": "pk_test_a11y_keys",
			"auth": "https://ochk.io", "audience": "https://brickworks.diy"}
	account.state = Account.State.SIGNED_OUT
	account.changed.emit()
	await _frames(10)
	named = gate.controls_by_name()
	_check("the form shows with the keys in its email field (%s)" % _said(_focused()),
		_focused() == named["signin_email"])
	await _type("someone@example.com")
	_check("...an address typed there", (named["signin_email"] as LineEdit).text
		== "someone@example.com")
	for name: String in ["signin_send", "signin_orangecheck"]:
		var reached: Control = await _tab_until(func(c: Control) -> bool:
			return c == named[name], 12)
		_check("Tab reaches %s (%s)" % [name, _said(reached)], reached != null)
	# The code's step, as Email me a code leaves it.
	(gate.get("_form") as SignInForm)._show(1)
	await _frames(4)
	for name: String in ["signin_code", "signin_go"]:
		var reached: Control = await _tab_until(func(c: Control) -> bool:
			return c == named[name], 12)
		_check("...then %s (%s)" % [name, _said(reached)], reached != null)
	for words: String in ["Use a different address", "Send a new code"]:
		var reached: Control = await _tab_until(func(c: Control) -> bool:
			return c is BaseButton and str(c.get("text")).begins_with(words), 12)
		_check("...and %s" % words, reached != null)

	# Signed in, and asked its age once.
	account.email = "probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.age_ask = true
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(10)
	await _answer_age(gate, false)
	account.age_ask = false
	account.changed.emit()
	await _frames(10)
	_check("let in, the screen goes", not gate.visible)


## The age question by keys: the first month has them, Right to March and
## Return, Tab to the year typed, Tab to Carry on and Return when [param go].
func _answer_age(gate: SignInGate, go: bool) -> void:
	var named: Dictionary = gate.controls_by_name()
	_check("the age question shows with the keys on its first month (%s)" % _said(_focused()),
		_focused() == named.get("age_month_1"))
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _key(KEY_ENTER)
	_check("...Right to March and Return chooses it",
		(named["age_month_3"] as Button).button_pressed)
	var year: Control = await _tab_until(func(c: Control) -> bool:
		return c == named["age_year"], 12)
	_check("Tab reaches the year (%s)" % _said(year), year != null)
	await _type(str(int(Time.get_datetime_dict_from_system()["year"]) - 30))
	var carry: Control = await _tab_until(func(c: Control) -> bool:
		return c == named["age_go"], 6)
	_check("...and Carry on (%s)" % _said(carry), carry != null)
	if go and carry != null:
		await _key(KEY_ENTER)


## Signed in for real, by keys alone: the address, Return, the code minted
## here typed, Tab to Sign in, Return; the age by keys if asked.
func _sign_in_live(account: Account, gate: SignInGate) -> void:
	print("  the way in, against %s" % Deployment.api_base())
	var named: Dictionary = gate.controls_by_name()
	_check("signed out, the keys are in the email field (%s)" % _said(_focused()),
		account.state == Account.State.SIGNED_OUT and _focused() == named["signin_email"])
	var email: String = SignInHelper.throwaway("keys")
	await _type(email)
	await _key(KEY_ENTER)
	for _n: int in 900:
		await process_frame
		if (named["signin_code"] as Control).is_visible_in_tree():
			break
	_check("Return asks for a code, and the keys are in its field (%s)" % _said(_focused()),
		_focused() == named["signin_code"])
	var code: String = await SignInHelper.mint(email, root)
	_check("a code minted for it (%s)" % ("yes" if not code.begins_with("!") else code),
		not code.begins_with("!"))
	await _type(code)
	var go: Control = await _tab_until(func(c: Control) -> bool:
		return c == named["signin_go"], 6)
	_check("Tab reaches Sign in (%s)" % _said(go), go != null)
	await _key(KEY_ENTER)
	for _n: int in 900:
		await process_frame
		if not gate.visible or account.age_ask:
			break
	if account.age_ask and gate.visible:
		await _frames(10)
		await _answer_age(gate, true)
		for _n: int in 600:
			await process_frame
			if not gate.visible:
				break
	await _frames(20)
	_check("signed in by keys alone, and the screen goes (%s)" % account.email,
		account.signed_in() and account.email == email and not gate.visible)
	var gone: int = await SignInHelper.delete_accounts("delivered+bwkeys", root)
	print("    (removed %d throwaway account(s))" % gone)


## Tab, until the focus is on a control [param wanted] says yes to, or
## [param most] presses have found none. Tab in a field gives the keys back
## to the model (FocusGuard), and F6 goes on from it, as a person does.
func _tab_until(wanted: Callable, most: int) -> Control:
	for _n: int in most:
		var on: Control = _focused()
		if on != null and bool(wanted.call(on)):
			return on
		await _key(KEY_TAB if on != null else KEY_F6)
	var last: Control = _focused()
	return last if last != null and bool(wanted.call(last)) else null


func _focused() -> Control:
	return root.gui_get_focus_owner()


func _said(control: Control) -> String:
	if control == null:
		return "nothing"
	var name: String = control.accessibility_name
	if name.is_empty() and control is Button:
		name = (control as Button).text
	return "%s \"%s\"" % [control.get_class(), name]


func _first_tile() -> Button:
	for child: Node in _bin._grid.get_children():
		if child is Button and child.has_meta("part"):
			return child
	return null


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _last_brick() -> BrickWorld.Brick:
	var last: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if last == null or brick.id > last.id:
			last = brick
	return last


func _wait_for(done: Callable, most: int) -> void:
	for _n: int in most:
		if bool(done.call()):
			return
		await process_frame


func _type(text: String) -> void:
	for character: String in text:
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.unicode = character.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
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
	await _frames(4)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("a11y keys probe: all checks passed")
	else:
		print("a11y keys probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
