## The sign-in screen in the real window: nothing in the builder can be
## used until someone is signed in.
##
##   godot --path . --resolution 1400x900 --script src/dev/gate_probe.gd
##   BRICKWORKS_API=http://127.0.0.1:8790 \
##     godot --path . --resolution 1400x900 --script src/dev/gate_probe.gd -- live
##
## Offline (in the suite): the deployment is pointed at a port nobody
## answers, so there is nowhere to sign in. The screen is up and says it
## cannot reach Brickworks, with Try again; a click on the model places
## nothing and a key changes nothing. Then the account lets somebody in, as signing in
## does, and the screen goes: the same click places a brick, the same key
## picks the next colour.
##
## Live (by hand, with tools/web/relay_server.mjs running and .env): the
## real form against the real functions — an address typed, Email me a
## code pressed, the code (minted on this side, as a probe has no inbox)
## typed, Sign in pressed — then Account on the bar and Sign out, and the
## screen is back. A throwaway account at a Resend test address, deleted
## at the end.
##
## Signed out again, the form as a browser draws it (SignInForm's
## offers_orangecheck, set here before the app is made): Sign in with
## orangecheck under the email, offered as the deployment says, with
## orangecheck's mark before its words, drawn at the screen's pixels, and a
## 44 px target (2026-10-24), in orangecheck.png.
##
## Pictures in shots/signin/. A window is needed: the screen is drawn.
extends SceneTree

const SHOTS := "res://shots/signin/"

var _failures: int = 0
var _main: Node
var _live: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	_live = OS.get_cmdline_user_args().has("live")
	if not _live:
		OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# The browser's form, with Sign in with orangecheck (only ever drawn
	# there), so that it is looked at here too.
	SignInForm.offers_orangecheck = true
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var account: Account = _main.get("_account")
	var gate: SignInGate = _main.get("_gate")
	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	_ok(gate != null and account != null, "the app made a sign-in screen")
	if gate == null:
		_finish()
		return
	while account.state == Account.State.CHECKING:
		await account.changed
	await _settle()

	if _live:
		await _live_sign_in(account, gate, world, builder)
		_finish()
		return

	print("\nnowhere to sign in")
	_ok(account.state == Account.State.UNREACHABLE, "the deployment cannot be reached")
	_ok(gate.visible, "the sign-in screen is up")
	_ok(_text_on(gate).contains("Cannot reach Brickworks"),
		"...and says it cannot reach Brickworks")
	_ok(gate.controls_by_name().has("signin_retry"), "...with Try again")
	_save("offline.png")

	var before: int = world.brick_count()
	await _click_model(false)
	_ok(world.brick_count() == before,
		"a click on the model places nothing (%d bricks, %d before)" % [world.brick_count(), before])
	var colour: int = builder.held_color
	await _key(KEY_BRACKETRIGHT)
	_ok(builder.held_color == colour, "a key changes nothing: still colour %d" % colour)

	print("\nsigned in")
	# What a sign-in does to the account, without anywhere to sign in: an
	# address and a session that needs no renewing. Signing in asks the
	# deployment (a port nothing listens on, here) for the account's Claude
	# connections with that session; with none, the account took itself
	# for signed out again and the screen came back.
	account.email = "probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _settle()
	_ok(not gate.visible, "the screen goes once somebody is signed in")
	_save("let_in.png")
	await _click_model(true)
	_ok(world.brick_count() == before + 1,
		"the same click places a brick (%d, %d before)" % [world.brick_count(), before])
	await _key(KEY_BRACKETRIGHT)
	_ok(builder.held_color != colour, "the same key picks the next colour: %d" % builder.held_color)
	# As a deployment offering orangecheck to everybody says it.
	if account.deployment != null:
		account.deployment.orangecheck_for_everyone = true
	account.state = Account.State.SIGNED_OUT
	account.changed.emit()
	await _settle()
	_ok(gate.visible and _text_on(gate).contains("Your email address is your account"),
		"signed out, the screen is back, asking for an address")
	_save("signed_out.png")

	print("\nSign in with orangecheck, as a browser draws it")
	var named: Dictionary = gate.controls_by_name()
	var oc: Button = named.get("signin_orangecheck")
	_ok(oc != null and oc.is_visible_in_tree() and oc.text == "Sign in with orangecheck",
		"offered under the email, with its words")
	if oc != null:
		var send: Button = named["signin_send"]
		var density: float = Icons.density(oc)
		var icon: Texture2D = oc.icon
		var tall: int = icon.get_height() if icon != null else 0
		var wide: int = icon.get_width() if icon != null else 0
		_ok(icon != null and wide == 2 * tall and absi(tall - roundi(14.0 * density)) <= 1,
			"orangecheck's mark is on it, 2:1, drawn %dx%d for a density of %.2f" % [wide, tall, density])
		_ok(oc.get_theme_constant("icon_max_width") == 28 and oc.get_theme_constant("h_separation") >= 7,
			"...shown 28 units wide, a quarter of that clear of the words")
		_ok(oc.size.y >= 44.0, "its target is at least 44 px tall: %d" % roundi(oc.size.y))
		_ok(oc.global_position.y > send.global_position.y and absf(oc.size.x - send.size.x) < 1.0,
			"...under Email me a code, as wide")
	_save("orangecheck.png")
	_finish()


func _live_sign_in(account: Account, gate: SignInGate, world: BrickWorld,
		builder: Builder) -> void:
	print("\nthe real form, against %s" % Deployment.api_base())
	_ok(account.state == Account.State.SIGNED_OUT and gate.visible,
		"signed out, the screen is up with the form")
	_save("1_form.png")
	var email: String = SignInHelper.throwaway("gate")
	var named: Dictionary = gate.controls_by_name()
	await _click_control(named["signin_email"])
	await _type(email)
	_ok((named["signin_email"] as LineEdit).text == email, "the address is typed in")
	await _click_control(named["signin_send"])
	var code_field: LineEdit = named["signin_code"]
	for _n: int in 600:
		await process_frame
		if code_field.is_visible_in_tree():
			break
	_ok(code_field.is_visible_in_tree(), "Email me a code moves on to the code")
	_ok(_text_on(gate).contains("We sent a code to %s" % email), "...saying where it went")
	_save("2_code.png")
	await _click_control(code_field)
	await _type("000000")
	await _click_control(named["signin_go"])
	for _n: int in 600:
		await process_frame
		if _text_on(gate).contains("wrong or has expired"):
			break
	_ok(_text_on(gate).contains("wrong or has expired") and gate.visible,
		"a wrong code is refused in words, and nobody is let in")
	_save("3_wrong.png")
	var code: String = await SignInHelper.mint(email, root)
	code_field.text = ""
	await _click_control(code_field)
	await _type(code)
	await _click_control(named["signin_go"])
	for _n: int in 900:
		await process_frame
		if not gate.visible or account.age_ask:
			break
	# A new account is asked its age once (supabase/trust.sql, once applied):
	# answered 13 or over here; tools/web/age_flow.mjs is about the question.
	if account.age_ask:
		_ok((await account.answer_age(3, int(Time.get_datetime_dict_from_system()["year"]) - 30)).is_empty(),
			"a new account is asked its age, and the answer is taken")
		for _n: int in 300:
			await process_frame
			if not gate.visible:
				break
	await _settle()
	_ok(not gate.visible and account.signed_in() and account.email == email,
		"the right code signs in and the screen goes: %s" % account.email)
	_save("4_signed_in.png")
	var before: int = world.brick_count()
	await _click_model(true)
	_ok(world.brick_count() == before + 1, "...and the builder can be used")

	print("\nthe account panel")
	var bar: ModelBar = _main.get("_bar")
	await _click_control(bar.controls_by_name()["account"])
	var panel: AccountPanel = _main.get("_account_panel")
	await _settle()
	_ok(panel.visible and _text_on(panel).contains("Signed in as %s" % email),
		"Account on the bar says who is signed in")
	_save("5_account.png")
	await _click_control(panel.controls_by_name()["sign_out"])
	for _n: int in 600:
		await process_frame
		if gate.visible:
			break
	await _settle()
	_ok(gate.visible and not account.signed_in(), "Sign out brings the screen back")
	_save("6_signed_out.png")
	var gone: int = await SignInHelper.delete_accounts("delivered+bwgate", root)
	print("  (removed %d throwaway account(s))" % gone)
	_ok(builder.held_part != "", "(the builder was there throughout)")


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


## The middle of the model's part of the window, clicked as a hand does.
## [param aimed]: wait for the ghost brick to be aimed first, which it is
## not while the sign-in screen takes the pointer.
func _click_model(aimed: bool) -> void:
	var view: Control = (_main.get("_marquee") as Control).get_parent()
	var at: Vector2 = view.get_global_rect().get_center() + Vector2(0, 60)
	var builder: Builder = _main.get("_builder")
	# A part in hand, so a click on the model is one that would put it
	# down: Select, where the app rests, puts nothing down.
	(_main.get("_verbs") as EditVerbs).set_mode("place")
	builder.hide_preview()
	await process_frame
	_move(at)
	for _n: int in (600 if aimed else 30):
		await process_frame
		if aimed and builder.hovered_brick() != 0:
			break
	_button(at, true)
	_button(at, false)
	for _n: int in 20:
		await process_frame


func _click_control(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, true)
	await process_frame
	_button(at, false)
	for _n: int in 6:
		await process_frame


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


## Viewport coordinates as the window's, which an event carries: the
## interface is scaled, so the two differ (see feel_probe.gd).
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	for _n: int in 4:
		await process_frame


func _type(text: String) -> void:
	for character: String in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	for _n: int in 4:
		await process_frame


## Everything a panel says, visible or not, for a check to look for words in.
func _text_on(node: Node) -> String:
	var said := PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		if (child as Label).is_visible_in_tree():
			said.append((child as Label).text)
	return "\n".join(said)


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(SHOTS + name))
	print("  wrote shots/signin/%s" % name)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "the sign-in screen keeps the builder until someone is in")
	quit(1 if _failures else 0)
