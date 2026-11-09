## Joining the beta is a step of signing up (betajoin, 2026-11-09), in the
## app's own sign-in screen, against the deployment's real functions:
##
##   BRICKWORKS_API=http://127.0.0.1:9960 godot --path . --resolution 1400x900 --script src/dev/betajoin_probe.gd
##   BRICKWORKS_API=http://127.0.0.1:9961 godot --path . --resolution 1400x900 --script src/dev/betajoin_probe.gd -- off
##
## With tools/web/relay_server.mjs on that port and .env (the beta open:
## BRICKWORKS_BETA=open and --hold=feedback until supabase/beta_join.sql is
## applied; for off, a server without BRICKWORKS_BETA). Throwaway accounts
## at Resend test addresses, deleted at the end. Skipped without
## BRICKWORKS_API, which the suite does not give.
##
## Open: a new account signs in by the real form (its address typed, Email
## me a code, the code typed, Sign in), answers the age question, and the
## screen welcomes it to the beta with Join the beta testers and Not now,
## nothing chosen, the builder still behind it. Join, one press: the
## deployment says it is a tester (GET /api/plans?op=beta), the screen says
## thank you, and Start building lets it in. Account then says so and
## leaves the beta in one press, and joins again in one. A second new
## account says Not now: let in, not a tester, and signed in again it is
## never asked again; Account offers it Join.
##
## Off: a new account is let straight in, with no welcome, Account has no
## Beta row, and the deployment refuses op=beta_join (403).
##
## Pictures in shots/betajoin/<window size>/. A window is needed: the
## screen is drawn.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shots: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	var off: bool = OS.get_cmdline_user_args().has("off")
	if OS.get_environment("BRICKWORKS_API").is_empty():
		print("betajoin probe: SKIPPED: needs BRICKWORKS_API, a server with the beta's functions (see its header)")
		quit(3)
		return
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var size: Vector2i = DisplayServer.window_get_size()
	_shots = "res://shots/betajoin/%dx%d/" % [size.x, size.y]
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: Node = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	var account: Account = _main.get("_account")
	var gate: SignInGate = _main.get("_gate")
	_ok(gate != null and account != null, "the app made a sign-in screen")
	if gate == null:
		_finish()
		return
	while account.state == Account.State.CHECKING:
		await account.changed
	await _settle()
	print("betajoin, the beta %s, against %s, in a %dx%d window" % ["off" if off else "open",
		Deployment.api_base(), size.x, size.y])
	if off:
		await _beta_off(account, gate)
	else:
		await _new_account_joins(account, gate)
		await _new_account_not_now(account, gate)
	var gone: int = await SignInHelper.delete_accounts("delivered+bwbetajoin", root)
	print("  (removed %d throwaway account(s))" % gone)
	_finish()


func _new_account_joins(account: Account, gate: SignInGate) -> void:
	print("\na new account, by the real form, joins")
	var email: String = SignInHelper.throwaway("betajoin")
	var named: Dictionary = gate.controls_by_name()
	await _click_control(named["signin_email"])
	await _type(email)
	var code_field: LineEdit = named["signin_code"]
	# Pressed again once if the deployment could not send it, as a person
	# would: Supabase's admin API sometimes answers in more than the 10 s
	# api/otp.js waits (2026-11-09, "no answer in 10 s").
	for _try: int in 2:
		await _click_control(named["signin_send"])
		var asked: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - asked < 30000:
			await process_frame
			if code_field.is_visible_in_tree() or not (named["signin_send"] as Button).disabled:
				break
		if code_field.is_visible_in_tree():
			break
		print("  (the form said: %s)" % _text_on(gate).replace("\n", " / "))
	_ok(code_field.is_visible_in_tree(), "Email me a code moves on to the code")
	var code: String = await SignInHelper.mint(email, root)
	await _click_control(code_field)
	await _type(code)
	await _click_control(named["signin_go"])
	await _past_the_code(account, gate)
	_ok(account.signed_in() and account.email == email, "the code is accepted: %s" % account.email)
	await _settle()
	var welcome: Dictionary = gate.controls_by_name()
	var join: Button = welcome.get("beta_join")
	var later: Button = welcome.get("beta_not_now")
	_ok(gate.visible and join != null and later != null and join.is_visible_in_tree()
		and later.is_visible_in_tree(), "the welcome shows: Join the beta testers and Not now")
	if join == null or later == null:
		return
	_ok(_text_on(gate).contains("Welcome to Brickworks") and _text_on(gate).contains("open beta")
		and _text_on(gate).contains("month of Pro"),
		"...saying what Brickworks is, that it is in beta, and what a tester does and gets")
	_ok(join.text == "Join the beta testers" and join.theme_type_variation == &"DefaultButton"
		and later.text == "Not now" and later.theme_type_variation != &"DefaultButton",
		"...Join first, as the default, Not now beside it")
	_ok(gate.find_children("*", "CheckBox", true, false).filter(
		func(one: Node) -> bool: return (one as Control).is_visible_in_tree()).is_empty(),
		"...and nothing ticked or chosen for them")
	_ok(bool(_main.call("_gated")), "...the builder still behind it")
	_fits(gate, "the welcome")
	_save("1_welcome.png")

	var before: Dictionary = await _beta_said(account)
	_ok(before.get("tester") == false and before.get("welcome") == true,
		"GET op=beta before: tester %s, welcome %s" % [before.get("tester"), before.get("welcome")])
	await _click_control(join)
	var start: Button = null
	for _n: int in 900:
		await process_frame
		start = gate.controls_by_name().get("beta_start")
		if start != null and start.is_visible_in_tree():
			break
	await _settle()
	var after: Dictionary = await _beta_said(account)
	_ok(after.get("tester") == true and after.get("state") == "tester" and after.get("welcome") == false,
		"one press: GET op=beta says tester %s, %s" % [after.get("tester"), after.get("state")])
	_ok(start != null and _text_on(gate).contains("You are a beta tester") and _text_on(gate).contains("Report a bug"),
		"...and the screen says thank you, and where things are now")
	_fits(gate, "the thank-you")
	_save("2_joined.png")
	if start == null:
		return
	await _click_control(start)
	await _settle()
	_ok(not gate.visible and account.lets_in(), "Start building lets them in")

	print("\nAccount: leave, and join again, a press each")
	var panel: AccountPanel = await _open_account()
	var press: Button = panel.controls_by_name().get("account_beta")
	_ok(press != null and _text_on(panel).contains("You are a beta tester") and press.text == "Leave the beta",
		"Account says they are a tester, with Leave the beta")
	_save("3_account_tester.png")
	if press == null:
		return
	await _click_control(press)
	await _until(func() -> bool: return press.text == "Join the beta testers" and not press.disabled)
	var left: Dictionary = await _beta_said(account)
	_ok(left.get("tester") == false and left.get("state") == "left",
		"Leave the beta, one press: tester %s, %s" % [left.get("tester"), left.get("state")])
	await _settle()
	_save("4_account_left.png")
	await _click_control(press)
	await _until(func() -> bool: return press.text == "Leave the beta" and not press.disabled)
	var again: Dictionary = await _beta_said(account)
	_ok(again.get("tester") == true, "Join the beta testers, one press: tester %s" % again.get("tester"))
	panel.visible = false
	account.sign_out()
	await _settle()


func _new_account_not_now(account: Account, gate: SignInGate) -> void:
	print("\na second new account says Not now")
	var email: String = SignInHelper.throwaway("betajoinlater")
	var said: String = await SignInHelper.sign_in(account, email, root)
	_ok(said.is_empty(), "signed in %s %s" % [email, said])
	await _past_the_code(account, gate)
	await _settle()
	var later: Button = gate.controls_by_name().get("beta_not_now")
	_ok(later != null and later.is_visible_in_tree(), "the welcome shows")
	if later == null:
		return
	await _click_control(later)
	await _until(func() -> bool: return not gate.visible)
	await _settle()
	var now: Dictionary = await _beta_said(account)
	_ok(not gate.visible and account.lets_in(), "Not now lets them in")
	_ok(now.get("tester") == false and now.get("state") == "not_now" and now.get("welcome") == false,
		"...not a tester: tester %s, %s, welcome %s" % [now.get("tester"), now.get("state"), now.get("welcome")])
	account.sign_out()
	await _settle()
	said = await SignInHelper.sign_in(account, email, root)
	await _past_the_code(account, gate)
	for _n: int in 120:
		await process_frame
	await _settle()
	_ok(account.signed_in() and not gate.visible and not gate.controls_by_name().has("beta_join"),
		"signed in again, the welcome never shows again")
	_save("5_not_now_signed_in_again.png")
	var panel: AccountPanel = await _open_account()
	var press: Button = panel.controls_by_name().get("account_beta")
	_ok(press != null and press.text == "Join the beta testers", "Account offers them Join the beta testers")
	_save("6_account_not_tester.png")
	panel.visible = false
	account.sign_out()
	await _settle()


func _beta_off(account: Account, gate: SignInGate) -> void:
	print("\nthe beta off")
	var email: String = SignInHelper.throwaway("betajoinoff")
	var said: String = await SignInHelper.sign_in(account, email, root)
	_ok(said.is_empty(), "signed in %s %s" % [email, said])
	await _past_the_code(account, gate)
	for _n: int in 120:
		await process_frame
	await _settle()
	_ok(account.signed_in() and not gate.visible and not gate.controls_by_name().has("beta_join"),
		"a new account is let straight in: no welcome")
	var panel: AccountPanel = await _open_account()
	_ok(not panel.controls_by_name().has("account_beta") and not _text_on(panel).contains("open beta"),
		"Account has no Beta row")
	_save("off_account.png")
	panel.visible = false
	var token: String = await account.access_token()
	var refused: Dictionary = await _ask(HTTPClient.METHOD_POST, "/api/plans?op=beta_join", token, "{\"via\":\"app\"}")
	_ok(int(refused.get("code", 0)) == 403, "op=beta_join is refused: %d" % int(refused.get("code", 0)))
	account.sign_out()
	await _settle()


## Past the code: the age question answered 13 or over when it is asked,
## as gate_probe does (age_flow.mjs is about the question), and the
## deployment's word on who this is in.
func _past_the_code(account: Account, gate: SignInGate) -> void:
	for _n: int in 900:
		await process_frame
		if account.signed_in() and not account.asking_who:
			break
	if account.age_ask:
		var answered: String = await account.answer_age(3, int(Time.get_datetime_dict_from_system()["year"]) - 30)
		_ok(answered.is_empty(), "the age question is answered: %s" % answered)
	for _n: int in 300:
		await process_frame
		if not account.asking_who and not account.age_ask:
			break


## The deployment's word on this account and the beta (GET op=beta).
func _beta_said(account: Account) -> Dictionary:
	var token: String = await account.access_token()
	var reply: Dictionary = await _ask(HTTPClient.METHOD_GET, "/api/plans?op=beta", token, "")
	var body: Variant = reply.get("body")
	return body if body is Dictionary else {}


func _ask(method: int, path: String, token: String, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	var headers := PackedStringArray(["authorization: Bearer " + token, "content-type: application/json"])
	if http.request(Deployment.api_base() + path, headers, method, body) != OK:
		http.queue_free()
		return {}
	var got: Array = await http.request_completed
	http.queue_free()
	var text: String = (got[3] as PackedByteArray).get_string_from_utf8()
	return {"code": int(got[1]), "body": JSON.parse_string(text) if not text.is_empty() else null}


func _open_account() -> AccountPanel:
	var bar: Node = _main.get("_bar")
	await _click_control(bar.call("controls_by_name")["account"])
	var panel: AccountPanel = _main.get("_account_panel")
	await _settle()
	return panel


## Nothing of [param panel] past the window's edges.
func _fits(panel: Control, what: String) -> void:
	var window: Rect2 = root.get_visible_rect()
	var out: Array[String] = []
	for one: Node in panel.find_children("*", "Control", true, false):
		var control := one as Control
		if control.is_visible_in_tree() and (control is Button or control is Label) \
				and not window.encloses(control.get_global_rect().grow(-1)):
			out.append(control.name)
	_ok(out.is_empty(), "%s fits the window%s" % [what, (": " + ", ".join(out)) if not out.is_empty() else ""])


func _until(test: Callable) -> void:
	for _n: int in 900:
		await process_frame
		if test.call():
			return


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


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


## Viewport coordinates as the window's, which an event carries.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


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


## Everything a panel says in sight, for a check to look for words in.
func _text_on(node: Node) -> String:
	var said := PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		if (child as Label).is_visible_in_tree():
			said.append((child as Label).text)
	return "\n".join(said)


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots))
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_shots + name))
	print("  wrote %s%s" % [_shots.trim_prefix("res://"), name])


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "betajoin: joining the beta is a step of signing up")
	quit(1 if _failures else 0)
