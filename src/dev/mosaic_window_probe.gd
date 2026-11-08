## A mosaic cropped and coloured the person's way, in the app's own window
## (APP_UX6 #10, mosaic2): what mosaic_probe checks stud for stud, seen.
##
##   godot --path . --resolution 1280x720 --script src/dev/mosaic_window_probe.gd [-- --shots=DIR]
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in (made with the
## admin key and a password, as tools/web/session.mjs makes them, so no code
## is spent at the per-IP limit), the screen gone; the account deleted at
## the end. Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY).
##
## The car photo is given to the app as its picture chooser gives one, and
## the dialog then used as a person uses it: Crop pressed and a rectangle
## dragged on the picture, Done; Colours opened and A set's colours chosen
## from its list with the keys, 31197 typed; Classic pressed; Build it; P
## for the parts list, its LEGO® Pick a Brick button in sight and the file it
## writes adding up to every plate. At each, the dialog and every control a
## person needs inside the window, and a picture of the window. At 1280 x 720 the
## dialog is at its shortest (the window less its margins); PROBE_SIZE=
## 1400x900 runs it at the size most of the probes have. --shots=DIR keeps
## the pictures there (else user://mosaic_window).
extends SceneTree

var _failures: int = 0
var _main: Node
var _out: String = "user://mosaic_window"
var _email: String = ""
var _password: String = ""


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
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
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
	var window: Vector2 = root.get_visible_rect().size
	print("in a %d x %d window" % [window.x, window.y])
	if not await _way_in():
		_finish()
		return

	# The picture, as the chooser hands it over once one is picked.
	var car: Image = Image.load_from_file(ProjectSettings.globalize_path("res://tools/release/best_car.png"))
	(_main.get("_picker") as Node).emit_signal("picked", car)
	var dialog: MosaicDialog = _main.get("_mosaic_made")
	_check("the picture chosen opens the mosaic dialog", dialog != null and dialog.visible)
	if dialog == null:
		_finish()
		return
	await _settled(dialog)
	_fits(dialog, "as it opens")
	await _shot("opened")

	# Crop, then a rectangle dragged on the picture.
	await _click(_middle(dialog._cropping))
	_check("Crop shows the whole picture to drag on", dialog._cropping.button_pressed)
	await _drag(dialog, Vector2(0.18, 0.25), Vector2(0.82, 0.9))
	var crop: Rect2 = dialog.crop()
	_check("the rectangle dragged is the crop: %s" % str(crop),
		absf(crop.position.x - 0.18) < 0.02 and absf(crop.end.x - 0.82) < 0.02
		and absf(crop.position.y - 0.25) < 0.02 and absf(crop.end.y - 0.9) < 0.02)
	await _shot("cropping")
	await _click(_middle(dialog._cropping))
	await _settled(dialog)
	_check("Done shows what it comes to, from the crop: \"%s\"" % dialog._detail.text,
		not dialog._cropping.button_pressed and not dialog._whole.disabled
		and dialog.last_art != null and dialog.last_art.plan.want.size() > 0)
	_fits(dialog, "cropped")
	await _shot("cropped")

	# Colours: the list opened, A set's colours chosen from it with the keys.
	await _click(_middle(dialog._colours))
	var popup: PopupMenu = dialog._colours.get_popup()
	_check("Colours opens its list of three", popup.visible and popup.item_count == 3)
	await _shot("colours_list")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	if dialog._colours.selected != MosaicDialog.Colours.SET:
		_check("A set's colours chosen from the list with the keys (selected %d)" % dialog._colours.selected, false)
		popup.hide()
		dialog.set_colours("set")
	await _click(_middle(dialog._set_number))
	for digit: String in "31197":
		await _key(OS.find_keycode_from_string(digit), digit.unicode_at(0))
	var until: int = Time.get_ticks_msec() + 30000
	while not dialog._palette_said.text.contains("Andy Warhol") and Time.get_ticks_msec() < until:
		await process_frame
	await _settled(dialog)
	_check("31197 typed finds the set: \"%s\"" % dialog._palette_said.text,
		dialog._palette_said.text.contains("Andy Warhol") and dialog.palette.size() >= 5)
	_fits(dialog, "with a set's colours")
	await _shot("set_colours")

	# Classic, in mixed plate sizes, then built.
	await _click(_middle(dialog._classic_mode))
	await _settled(dialog)
	var laid: Mosaic.Laid = dialog.last_classic
	_check("Classic lays the cropped picture in the set's colours, mixed sizes: \"%s\"" % dialog._detail.text,
		laid != null and dialog._mixed.button_pressed and laid.plates.size() < laid.studs()
		and Array(laid.cells).all(func(code: int) -> bool: return code < 0 or dialog.palette.has(code)))
	_fits(dialog, "Classic")
	await _shot("classic")
	var world: BrickWorld = _main.get("_world")
	await _click(_middle(dialog._go))
	until = Time.get_ticks_msec() + 60000
	while (dialog.visible or world.brick_count() == 0) and Time.get_ticks_msec() < until:
		await process_frame
	for _n: int in 20:
		await process_frame
	_check("Build it puts down its %d plates: %d in the model" % [
		laid.plates.size() if laid != null else -1, world.brick_count()],
		laid != null and world.brick_count() == laid.plates.size())
	await _shot("built")
	await _key(KEY_P)
	for _n: int in 30:
		await process_frame
	var list: Variant = _main.get("_inventory_made")
	_check("P lists its parts", list != null and bool(list.call("is_showing")))
	var shop: Control = (list.call("controls_by_name") as Dictionary).get("parts_pickabrick") \
		if list != null else null
	_check("...with its LEGO® Pick a Brick button in sight (%s)" % (str(shop.get_global_rect())
		if shop != null else "none"), shop != null and shop.is_visible_in_tree()
		and root.get_visible_rect().encloses(shop.get_global_rect()))
	# What that button writes, for what was built.
	var stock: Inventory = Inventory.of(world, _main.get("_library"), {})
	var file: Dictionary = ShopLists.pick_a_brick(stock)
	var asked: int = 0
	for text: String in file["files"]:
		for line: String in text.split("\r\n").slice(1):
			asked += int(line.get_slice(",", 1))
	var missing: int = 0
	for lot: Inventory.Lot in file["missing"]:
		missing += lot.count
	_check("its Pick a Brick file asks for %d pieces, %d named as not on it, of the %d plates"
		% [asked, missing, stock.pieces], asked + missing == stock.pieces and asked > 0
		and laid != null and stock.pieces == laid.plates.size())
	await _shot("parts_list")
	_finish()


## The sign-in screen up, a throwaway account signed in, the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	await _shot("sign_in")
	_email = SignInHelper.throwaway("mosaic")
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
## token bucket, not a code's verify, which is 1 per 10 s for every agent.
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


## The dialog, and each of its controls a person needs here, inside the
## window and drawn.
func _fits(dialog: MosaicDialog, when: String) -> void:
	var window: Rect2 = root.get_visible_rect()
	var box: Rect2 = dialog.get_global_rect()
	var out: Array[String] = []
	for name: String in dialog.controls_by_name():
		var control: Control = dialog.controls_by_name()[name]
		if not control.is_visible_in_tree():
			continue
		var at: Rect2 = control.get_global_rect()
		if not window.encloses(at) or not box.grow(1.0).encloses(at):
			out.append(name)
	_check("%s: the dialog (%s) and its controls inside the window%s" % [when,
		str(box), "" if out.is_empty() else ", not: " + ", ".join(out)],
		window.encloses(box) and out.is_empty())


func _settled(dialog: MosaicDialog) -> void:
	await process_frame
	var until: int = Time.get_ticks_msec() + 20000
	while not dialog._later.is_stopped() and Time.get_ticks_msec() < until:
		await process_frame
	for _n: int in 3:
		await process_frame


func _middle(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## A point on the app's canvas in the window's pixels: the app draws its
## interface scaled (1391 x 782 of canvas in a 1280 x 720 window), and a
## pointer's events come in the window's.
func _px(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _click(at: Vector2) -> void:
	at = _px(at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move)
	await process_frame
	for down: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = at
		press.global_position = at
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(press)
		await process_frame


## A drag on the dialog's picture from [param from] to [param to], each a
## fraction of the picture as it is drawn, in eight steps.
func _drag(dialog: MosaicDialog, from: Vector2, to: Vector2) -> void:
	var shown: Rect2 = dialog.shown_rect()
	var origin: Vector2 = dialog._preview.get_global_rect().position + shown.position
	var last: Vector2 = _px(origin + from * shown.size)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = last
	press.global_position = last
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press)
	await process_frame
	for step: int in range(1, 9):
		var move := InputEventMouseMotion.new()
		move.position = _px(origin + from.lerp(to, step / 8.0) * shown.size)
		move.global_position = move.position
		move.relative = move.position - last
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		last = move.position
		root.push_input(move)
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = last
	release.global_position = last
	root.push_input(release)
	await process_frame


func _key(code: Key, unicode: int = 0) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.unicode = unicode if down else 0
		key.pressed = down
		root.push_input(key)
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, root.size.x, root.size.y])
	if image != null:
		image.save_png(path)
		print("    picture: %s" % ProjectSettings.globalize_path(path))


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("\n%s: %d failed" % ["FAIL" if _failures > 0 else "PASS", _failures])
	quit(1 if _failures > 0 else 0)
