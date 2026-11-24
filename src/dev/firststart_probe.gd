## A first visit to the studio, signed in, with no model here or in the
## account (appwalk's first-timer, 2026-11-24). On a phone, or in a window a
## phone's width, where Build your first model has no room (FirstBuild
## .fits_here), the studio's first screen comes up over the example car,
## welcoming: its title says so, Continue is empty, and New model is its one
## strong button; one press of it starts an empty baseplate, nothing asked.
## Up again, a model opened behind it (File, Open, a file dropped, a
## session's open_model) puts it away.
## A phone's first visit had had the car and nothing else, New three taps
## away in More, File. In a desktop's window, the car with no first screen,
## as before: Build your first model offers its steps there.
##
##   PROBE_SIZE=390x844 tools/probe.sh firststart_probe       a phone
##   PROBE_SIZE=1280x800 tools/probe.sh firststart_probe      a desktop's
##   godot --path . --resolution 390x844 --script src/dev/firststart_probe.gd -- --pictures=DIR
##
## No network: studio_start_probe's FakeShared answers. Its data folder must
## hold no saved model (tools/probe.sh gives each run its own).
## One PASS or FAIL line per check; it exits 1 on any FAIL.
extends "res://src/dev/studio_start_probe.gd"

## A small model opened while the first screen is up.
const OPENED := "res://src/dev/fixtures/orrery_two_planets.ldr"


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--pictures="):
			_pictures = given.substr("--pictures=".length())
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	var phone: bool = mini(window.x, window.y) < int(Phone.NARROW)
	Phone._on = 1 if phone else 0
	Phone._wide = false
	var size: String = "%dx%d" % [window.x, window.y]
	print("firststart_probe: a %s window, laid out for a %s" % [size, "phone" if phone else "desktop"])
	var saved_before: int = DirAccess.get_files_at(ModelStore.SAVE_DIR).size() \
		if DirAccess.dir_exists_absolute(ModelStore.SAVE_DIR) else 0
	if saved_before > 0:
		_check(false, "a data folder with no saved model (%d there): run it through tools/probe.sh" % saved_before)
		_finish()
		return
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", _fake())
	_main.set("start_for_probe", true)
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	var account: Account = _main.get("_account")
	await account.deployment.wait()
	# Signed in now, as by the code, as a person who has saved nothing.
	account.email = "delivered+firststart-app@resend.dev"
	account.user_id = "00000000-0000-4000-8000-0000005ad1f5"
	account._access = TOKEN
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	for _n: int in 600:
		await process_frame
		if bool(_main.get("_start_decided")):
			break
	await _a_while(60)
	await _settle()
	var state: Dictionary = _main.call("_start_state")
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var shell: Shell = _main.get("_shell")
	# Called by name, so the probe runs on a build from before fits_here too.
	var room: bool = bool(shell.first_build.call("fits_here")) if shell.first_build.has_method("fits_here") \
		else not phone
	var start: Control = _main.get("_studio_start")
	var shown: bool = start != null and start.visible
	await _picture("firststart_%s_first.png" % size)
	_check(bool(state.get("decided")) and bool(state.get("car")) and world.brick_count() > 30,
		"the account has nothing: the example car opened (%d parts, decided %s, car %s)"
		% [world.brick_count(), state.get("decided"), state.get("car")])
	if not phone:
		_check(room and not shown,
			"a desktop's window: Build your first model has room (%s) and no first screen covers the car (%s)"
			% [room, "shown" if shown else "none"])
		_finish()
		return
	_check(not room, "a phone: Build your first model has no room here (fits_here %s)" % room)
	_check(shown and bool(state.get("welcoming")) and str(state.get("title")) == "Welcome to Brickworks"
		and int(state.get("continue", -1)) == 0,
		"...so the first screen is over the car, welcoming: \"%s\", %d to continue"
		% [state.get("title", ""), int(state.get("continue", -1))])
	var named: Dictionary = start.call("controls_by_name") if shown else {}
	var new_button: Button = named.get("start_new") as Button
	var strong: bool = new_button != null and (new_button.get_theme_stylebox("normal") as StyleBoxFlat) != null \
		and (new_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(Look.STRONG)
	_check(strong, "...New model its strong button")
	if new_button == null:
		_finish()
		return
	await _into_sight(new_button)
	await _press_now(new_button)
	for _n: int in 120:
		await process_frame
		if not start.visible and world.brick_count() <= store.scenery.size():
			break
	await _settle()
	var asked: bool = false
	for node: Node in root.find_children("*", "AcceptDialog", true, false):
		asked = asked or (node as Window).visible
	await _picture("firststart_%s_new.png" % size)
	_check(not start.visible and world.brick_count() <= store.scenery.size() and not asked
		and store.title == ModelStore.UNTITLED,
		"...one press of New model: the screen gone (%s), an empty baseplate (%d parts), nothing asked (%s)"
		% ["gone" if not start.visible else "still up", world.brick_count() - store.scenery.size(), asked])
	# Up again, and a model opened behind it as File, Open, a file dropped
	# or a session's open_model opens one (the open, then the bar's opened):
	# what the person came to, so the screen goes. It stayed over the model,
	# still saying the example car was behind it (m338reds).
	start.call("open", [], false, true)
	await _settle()
	var bar: ModelBar = _main.get("_bar")
	var placed: int = await bar.open_with_progress(ProjectSettings.globalize_path(OPENED))
	if placed >= 0:
		bar.opened.emit(placed)
	for _n: int in 60:
		await process_frame
		if not start.visible:
			break
	await _settle()
	await _picture("firststart_%s_opened.png" % size)
	_check(placed > 0 and not start.visible,
		"...up again, a model opened behind it (%d parts): the screen goes (%s)"
		% [placed, "gone" if not start.visible else "still up"])
	_finish()
