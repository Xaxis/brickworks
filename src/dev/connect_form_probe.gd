## Connect Claude on the desktop opens claude.ai's Add custom connector with
## Brickworks filled in, always (connect3, 2026-10-31).
##
##   godot --path . --resolution 1280x720 --script src/dev/connect_form_probe.gd
##   ... -- --shots=DIR      the assistant's panel pictured at each step
##
## The owner: "in the app when user clicks the claude code connector it
## doesnt prepopulate the add custom connector field". An account that had
## ever had Claude connected was sent to Claude's bare list of connectors
## instead, and the owner's has. Here, in the real app's assistant panel,
## each step a click as a person makes it:
## - Connect Claude hands the system (Outside, which a probe's run keeps)
##   claude.ai's install link: modal=add-custom-connector,
##   connectorName=Brickworks and connectorUrl the app's deployment's
##   /api/mcp, percent-encoded; for an account that never had Claude, and
##   for one that has;
## - for the one that has, "Already in your Claude? Open your connectors"
##   beside it and the line saying why, which opens Claude's list;
## - Claude Code: one click puts `claude mcp add ...` on the clipboard and
##   says so under the link, with /mcp next.
## Signed in with a session that needs no renewing, to a deployment on a
## port this probe holds and never answers: nothing leaves the machine, and
## the panel waits as it does while the person is over in claude.ai.
## chat_probe proves the same link for brickworks.diy, the desktop's own.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _size: String = ""
var _held := TCPServer.new()


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	# Start-up's questions to the deployment fail at once; the connector's,
	# below, are taken by a port held here and never answered.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	ShellPrefs.put("assistant", "on")
	ShellPrefs.put("assistant_offered", true)
	ShellPrefs.put("first_build", "skipped")
	await process_frame
	_size = "%dx%d" % [root.size.x, root.size.y]
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	var account: Account
	for _n: int in 900:
		await process_frame
		account = _main.get("_account")
		if account != null and account.state != Account.State.CHECKING \
				and _main.get("_chat") != null:
			break
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	if _held.listen(0, "127.0.0.1") != OK:
		print("  could not hold a port")
		quit(1)
		return
	var connector: ClaudeConnector = _main.get("_connector")
	var deployment: String = "http://127.0.0.1:%d" % _held.get_local_port()
	connector.base_url = deployment
	account.keeps = false
	account.email = "probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var dock: SideDock = _main.get("_chat_dock")
	dock.set_open(true, false)
	await _frames(30)
	var form: ConnectorForm = (_main.get("_chat") as Node).get("_connector_form")
	_check(form != null and form.is_visible_in_tree(), "the assistant's panel offers Connect Claude")
	if form == null:
		quit(1)
		return
	var connect_button: Button = form.get("_connect")
	var already: Control = form.get("_already")
	await _shot("1_before", connect_button)
	_check(not already.visible, "an account that never had Claude is offered nothing beside it")

	var filled_in: String = ("https://claude.ai/customize/connectors?modal=add-custom-connector"
		+ "&connectorName=Brickworks&connectorUrl="
		+ deployment.replace(":", "%3A").replace("/", "%2F") + "%2Fapi%2Fmcp")
	print("\nan account that never had Claude")
	await _click(connect_button)
	_check(not Outside.opened.is_empty() and Outside.opened.back() == filled_in,
		"Connect Claude hands the system: %s" % _last())
	_check(connector.waiting_for_claude() and (form.get("_step_one") as Label).text
			== "1. Press Add, then Connect.",
		"...and the panel says what to press there: %s" % (form.get("_step_one") as Label).text)
	await _shot("2_connect", connect_button)

	print("\nan account that has had Claude, as the owner's has")
	connector._take_connections({"connections": [], "before": true})
	await _frames(6)
	var already_link: LinkButton = form.get("_already_link")
	var why: Label = already.get_child(1) as Label
	_check(already.is_visible_in_tree() and already_link.text == "Already in your Claude? Open your connectors"
			and why.text == ClaudeConnector.ALREADY,
		"the list offered beside Connect, and why: %s" % why.text)
	var before: int = Outside.opened.size()
	await _click(connect_button)
	_check(Outside.opened.size() == before + 1 and Outside.opened.back() == filled_in,
		"Connect Claude hands the system the form filled in still: %s" % _last())
	await _shot("3_had_claude", already_link)
	await _click(already_link)
	_check(Outside.opened.back() == ClaudeConnector.CONNECTORS
			and (form.get("_step_one") as Label).text.contains("select Brickworks and press Connect"),
		"Open your connectors hands it Claude's list, with the steps there: %s" % _last())
	await _shot("4_list", already_link)

	print("\nClaude Code")
	var code_link: LinkButton = form.get("_code_link")
	DisplayServer.clipboard_set("")
	await _click(code_link)
	var said: Label = form.get("_code_said")
	var command: String = "claude mcp add --transport http brickworks %s/api/mcp" % deployment
	_check(DisplayServer.clipboard_get() == command,
		"one click puts the command on the clipboard: %s" % DisplayServer.clipboard_get())
	_check(said.is_visible_in_tree() and said.text.begins_with("Copied. Run it in a terminal, then type /mcp")
			and _on_screen(said),
		"...and says so under the link, with what next, in view (%s in %s): %s"
			% [said.get_global_rect(), _seen(said), said.text])
	await _shot("5_claude_code", said)

	connector.stop()
	_held.stop()
	print("\n%s" % ("all checks passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _last() -> String:
	return Outside.opened.back() if not Outside.opened.is_empty() else "(nothing)"


## A click on [param control] where it is drawn, as the mouse sends one,
## scrolled into view first.
func _click(control: Control) -> void:
	_into_view(control)
	await _frames(4)
	# In the window's pixels, through Input as the system's events come.
	var at: Vector2 = control.get_global_rect().get_center() \
		* (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _frames(3)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await _frames(2)
	await _frames(4)


func _into_view(control: Control) -> void:
	var up: Node = control.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).ensure_control_visible(control)


## Whole in the window, and in the panel's view where the panel scrolls.
func _on_screen(control: Control) -> bool:
	return _seen(control).grow(1.0).encloses(control.get_global_rect())


func _seen(control: Control) -> Rect2:
	var seen: Rect2 = root.get_visible_rect()
	var up: Node = control.get_parent()
	while up != null:
		if up is ScrollContainer:
			seen = seen.intersection((up as ScrollContainer).get_global_rect())
		up = up.get_parent()
	return seen


func _shot(named: String, near: Control) -> void:
	if _shots.is_empty():
		return
	_into_view(near)
	await _frames(6)
	await RenderingServer.frame_post_draw
	var path: String = _shots.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
