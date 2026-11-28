## A newcomer's way into Simple and out of it with their model kept and
## shown (appwalk2, 2026-11-28). The walk at 390 x 844 found Simple only as
## a tile inside More, so the first-timer built in Full; at 820 and 1280,
## in Simple, a brick house could be neither saved under a name nor shared,
## Simple's header having no File, no name and no toolbar.
##
##   PROBE_SIZE=390x844 tools/probe.sh simplestart_probe                 a phone
##   PROBE_SIZE=820x1180 tools/probe.sh simplestart_probe -- --tablet    a tablet held upright
##   PROBE_SIZE=1280x800 tools/probe.sh simplestart_probe                a desktop's
##   godot --path . --resolution 390x844 --script src/dev/simplestart_probe.gd -- --pictures=DIR
##
## (a) A first visit on a phone or a tablet, signed in, nothing saved: the
##     first screen offers Start in Simple as its strong button, New model
##     beside it plain, and its line says what each gives. In a desktop's
##     window there is no first screen (Simple is in the header there).
## (b) One press of Start in Simple: the screen gone, Simple's controls up
##     and kept for next time, an empty baseplate, nothing asked. On a
##     desktop the header's switch and New stand for it.
## (c) In Simple, Save and Share are on the screen, each a fingertip tall,
##     inside the window and over none of Simple's other controls, the
##     header or the tray; and they wait, dimmed, while nothing is built.
## (d) Two bricks put down, Save pressed: the model's name is asked, and
##     answered it is saved under it, still in Simple.
## (e) Share pressed: the share panel opens over Simple's controls.
##
## No network: studio_start_probe's FakeShared answers. Its data folder must
## hold no saved model (tools/probe.sh gives each run its own).
## One PASS or FAIL line per check; it exits 1 on any FAIL.
extends "res://src/dev/firststart_probe.gd"

const CALLED := "Little house"


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var tablet: bool = false
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--pictures="):
			_pictures = given.substr("--pictures=".length())
		elif given == "--tablet":
			tablet = true
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	var touch: bool = tablet or mini(window.x, window.y) < int(Phone.NARROW)
	Phone._on = 1 if touch else 0
	Phone._wide = tablet
	var size: String = "%dx%d" % [window.x, window.y]
	print("simplestart_probe: a %s window, laid out for a %s"
		% [size, "tablet" if tablet else ("phone" if touch else "desktop")])
	var saved_before: int = _saved_count()
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
	account.email = "delivered+simplestart-app@resend.dev"
	account.user_id = "00000000-0000-4000-8000-0000005ad1f6"
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
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var bar: ModelBar = _main.get("_bar")
	var start: Control = _main.get("_studio_start")
	var shown: bool = start != null and start.visible
	var named: Dictionary = start.call("controls_by_name") if shown else {}
	var simple_button: Button = named.get("start_simple") as Button
	var new_button: Button = named.get("start_new") as Button
	await _picture("simplestart_%s_first.png" % size)

	# (a) and (b): the way into Simple.
	if touch:
		var lead: Label = start.get("_lead") as Label if shown else null
		_check(shown and simple_button != null and _strong(simple_button) and new_button != null
			and not _strong(new_button),
			"(a) a first visit on a %s: Start in Simple the strong button (%s), New model beside it plain (%s)"
			% ["tablet" if tablet else "phone", "yes" if _strong(simple_button) else "no",
			"no button" if new_button == null else ("strong" if _strong(new_button) else "plain")])
		_check(lead != null and lead.text.contains("Simple") and lead.text.contains("New model"),
			"...its line says what each gives: \"%s\"" % (lead.text if lead != null else ""))
		if simple_button == null:
			_finish()
			return
		await _into_sight(simple_button)
		await _press_now(simple_button)
		for _n: int in 180:
			await process_frame
			if not start.visible and StringName(_main.call("controls_layer")) == &"simple" \
					and world.brick_count() <= store.scenery.size():
				break
		await _settle()
		await _a_while(30)
		var asked: bool = false
		for node: Node in root.find_children("*", "AcceptDialog", true, false):
			asked = asked or (node as Window).visible
		_check(not start.visible and StringName(_main.call("controls_layer")) == &"simple"
			and str(ShellPrefs.value("controls")) == "simple"
			and world.brick_count() <= store.scenery.size() and store.scenery.size() > 0 and not asked,
			"(b) one press of Start in Simple: the screen %s, controls %s (kept: %s), %d parts on %d of baseplate, asked %s"
			% ["gone" if not start.visible else "still up", _main.call("controls_layer"),
			ShellPrefs.value("controls"), world.brick_count() - store.scenery.size(), store.scenery.size(), asked])
	else:
		_check(not shown or simple_button == null,
			"(a) a desktop's window: no Start in Simple on a first screen (%s)"
			% ("none shown" if not shown else "offered"))
		_main.call("use_controls", &"simple")
		await _a_while(10)
		bar.ask_for_new()
		for _n: int in 180:
			await process_frame
			if world.brick_count() <= store.scenery.size():
				break
		await _settle()
		_check(StringName(_main.call("controls_layer")) == &"simple" and world.brick_count() <= store.scenery.size(),
			"(b) the header's Simple and New: controls %s, %d parts on the baseplate"
			% [_main.call("controls_layer"), world.brick_count() - store.scenery.size()])
	var layer: Control = _main.get("_simple")
	if layer == null or not layer.is_visible_in_tree():
		_check(false, "Simple's controls are up")
		_finish()
		return
	await _a_while(10)
	await _picture("simplestart_%s_simple.png" % size)

	# (c) Save and Share on the screen, a fingertip tall, in nobody's way.
	var save: Button = layer.call("button", "save") as Button
	var share: Button = layer.call("button", "share") as Button
	if save == null or share == null:
		_check(false, "(c) Simple has a Save and a Share (save %s, share %s)" % [save != null, share != null])
		_finish()
		return
	var tall: float = float(layer.call("p", Phone.TARGET)) - 0.5
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var in_way: Array = []
	for other: String in ["fit", "undo", "redo", "turn", "copy", "delete"]:
		var control: Button = layer.call("button", other) as Button
		for mine: Button in [save, share]:
			if control != null and control.is_visible_in_tree() and control.get_global_rect().intersects(mine.get_global_rect()):
				in_way.append("%s over %s" % [mine.name, control.name])
	var foot: Control = (layer.call("controls_by_name") as Dictionary).get("simple_foot") as Control
	var top: float = float(layer.call("_header_foot"))
	for mine: Button in [save, share]:
		if foot != null and foot.get_global_rect().intersects(mine.get_global_rect()):
			in_way.append("%s over the tray" % mine.name)
		if mine.get_global_rect().position.y < top - 0.5:
			in_way.append("%s over the header" % mine.name)
	if save.get_global_rect().intersects(share.get_global_rect()):
		in_way.append("save over share")
	_check(save.is_visible_in_tree() and share.is_visible_in_tree()
		and save.size.y >= tall and share.size.y >= tall
		and screen.encloses(save.get_global_rect()) and screen.encloses(share.get_global_rect())
		and in_way.is_empty(),
		"(c) Save (%s, %d tall) and Share (%s, %d tall) shown, at least %d, inside the window, in nobody's way %s"
		% [_rect(save), roundi(save.size.y), _rect(share), roundi(share.size.y), ceili(tall), in_way])
	_check(save.disabled and share.disabled,
		"...and dimmed while nothing is built (save %s, share %s)"
		% ["dimmed" if save.disabled else "lit", "dimmed" if share.disabled else "lit"])

	# (d) Two bricks down, then Save: the name asked, and saved under it.
	var room: Rect2 = layer.call("model_room", root.get_visible_rect()) as Rect2
	var middle: Vector2 = room.get_center()
	for at: Vector2 in [middle, middle + Vector2(0.0, room.size.y * 0.08)]:
		layer.call("_take", "3001")
		layer.call("_place_at", at)
		layer.call("_put_hand_away")
		await _a_while(10)
	var built: int = world.brick_count() - store.scenery.size()
	await _a_while(5)
	_check(built >= 1 and not save.disabled and not share.disabled,
		"(d) %d bricks put down: Save and Share lit (save %s, share %s)"
		% [built, "lit" if not save.disabled else "dimmed", "lit" if not share.disabled else "dimmed"])
	await _press_now(save)
	var dialog: Window = bar.get("_ask_name") as Window
	for _n: int in 60:
		await process_frame
		if dialog != null and dialog.visible:
			break
	await _settle()
	await _picture("simplestart_%s_save_asks.png" % size)
	var asked_name: bool = dialog != null and dialog.visible
	_check(asked_name, "...Save pressed: the model's name asked (%s)" % ("asked" if asked_name else "not asked"))
	if asked_name:
		(bar.get("_ask_name_field") as LineEdit).text = CALLED
		bar.call("_take_name")
		for _n: int in 240:
			await process_frame
			if _saved_count() > 0 and bar.model_name() == CALLED:
				break
		await _settle()
	_check(bar.model_name() == CALLED and _saved_count() > 0
		and StringName(_main.call("controls_layer")) == &"simple",
		"...answered \"%s\": saved under \"%s\" (%d saved), still in %s"
		% [CALLED, bar.model_name(), _saved_count(), _main.call("controls_layer")])

	# (e) Share: the panel over Simple's controls.
	await _press_now(share)
	var panel: Control = null
	for _n: int in 240:
		await process_frame
		panel = _main.get("_share_panel_made") as Control
		if panel != null and panel.visible:
			break
	await _settle()
	await _a_while(20)
	await _picture("simplestart_%s_share.png" % size)
	var over: bool = panel != null and panel.visible and panel.get_parent() == layer.get_parent() \
		and panel.get_index() > layer.get_index()
	_check(over and screen.intersects(panel.get_global_rect()),
		"(e) Share pressed: the share panel open over Simple's controls (%s)"
		% ("open, in front" if over else ("open, behind" if panel != null and panel.visible else "not open")))
	_finish()


func _saved_count() -> int:
	if not DirAccess.dir_exists_absolute(ModelStore.SAVE_DIR):
		return 0
	var n: int = 0
	for file: String in DirAccess.get_files_at(ModelStore.SAVE_DIR):
		n += 1 if file.ends_with(".ldr") or file.ends_with(".mpd") or file.ends_with(".bwx") else 0
	return n


func _rect(control: Control) -> String:
	var rect: Rect2 = control.get_global_rect()
	return "%d,%d %dx%d" % [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)]
