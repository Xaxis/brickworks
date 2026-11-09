## A panel you open comes to the front (the hudfront unit, 2026-11-09).
##
##   godot --path . --resolution 1400x900 --script src/dev/hudfront_probe.gd
##   tools/probe.sh hudfront_probe        (and PROBE_SIZE=1280x720)
##   ... -- --shots=DIR    the pictures there, not in user://hudfront
##
## typingkeys's walk (2026-11-08): with Find open, its list saying nothing
## in the model answers "87087", F1's keys sheet and F9's Render opened
## beneath Find's list. The HUD's panels stayed in the order they were made,
## and Find's list had been made last.
##
## Through the way in first, as a person comes: the sign-in screen over the
## app (gate_for_probe), a throwaway account signed in with a password (as
## typingkeys_probe does), removed at the end. Needs .env (SUPABASE_URL,
## SUPABASE_SECRET_KEY).
##
## Each panel of the HUD made once, in the order [constant PANELS] names
## them, Find's list last, as in the walk. Then:
## - the walk's: Ctrl+F, "87087" typed, F1, and F9 from there, keys a person
##   presses: the keys sheet, then Render, takes a click at the middle of
##   what it shares with Find's list;
## - every pair of panels, each way round, opened as a person opens them (a
##   menu's command; the mosaic from the file chooser's picture, Brickify
##   from a model a session hands it over MCP, Account from the bar's
##   button, the sticker sheet from the bin's): the one opened last takes a
##   click at the middle of the area they share, by hit-test (the window's
##   order: by canvas layer, then the tree) and by the window's own hover
##   there; then a click on the first where the second leaves it in sight
##   brings it forward (that middle is the first's now), and the second
##   asked for again comes forward again (or closes, where its command
##   opens and closes it: Account, Share);
## - every panel open at once and the sign-in screen up (signed out): the
##   screen takes a click at the middle of each, and a panel asked for
##   while it is up, and clicked, stays under it.
## Pictures in user://hudfront (or --shots=DIR): the walk's two, a click
## bringing one forward, the sign-in screen over every panel.
extends SceneTree

const CTRL := KEY_MASK_CMD_OR_CTRL
const TYPED := "87087"
## Each panel of the HUD a person opens, Find's list last (made last, as in
## the walk).
const PANELS: Array[String] = ["the keys sheet", "Render", "the minifigure builder", "the mosaic",
	"Brickify", "the part maker", "Share", "Account", "My collection", "the Library",
	"Print on a part", "the sticker sheet", "the page laid out", "Find's list"]
## Those whose command opens them and, open, closes them.
const TOGGLES: Array[String] = ["Share", "Account"]
## A box, for Brickify to open on as a session hands it one.
const CUBE_OBJ := "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nv 0 0 1\nv 1 0 1\nv 1 1 1\nv 0 1 1\n" \
	+ "f 1 2 3 4\nf 5 8 7 6\nf 1 5 6 2\nf 2 6 7 3\nf 3 7 8 4\nf 4 8 5 1\n"

var _failures: int = 0
var _main: Node
var _shell: Shell
var _hud: CanvasLayer
var _out: String = "user://hudfront"
var _size: String = ""
var _email: String = ""
var _password: String = ""
var _pairs: int = 0
var _pairs_ok: int = 0
var _clicked: int = 0
var _again: int = 0
var _apart: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	ShellPrefs.kept_by_a_check = _own_data_folder()
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("in a %s window" % _size)
	_hud = _main.get_node("HUD")
	if not await _way_in():
		await _finish()
		return
	var world: BrickWorld = _main.get("_world")
	for _n: int in 900:
		if world != null and world.brick_count() > 1 and _main.get("_shell") != null:
			break
		await process_frame
	_shell = _main.get("_shell")
	if _shell == null:
		_check("the app up to open panels in", false)
		await _finish()
		return
	(_main.get("_store") as ModelStore).keeps = false
	Keymap.reset()

	print("\neach panel made, in this order")
	for panel: String in PANELS:
		var ok: bool = await _open(panel)
		var node: Control = _node(panel)
		_check("%s opens (%s)" % [panel, node.get_path() if node != null else "nothing"], ok)
		await _put_away()

	await _walk()

	print("\nevery pair, each way round")
	for i: int in PANELS.size():
		for j: int in range(i + 1, PANELS.size()):
			await _pair(PANELS[i], PANELS[j])
			await _pair(PANELS[j], PANELS[i])
	print("  %d of %d orders right; %d clicked forward; %d asked for again came forward; apart: %s" % [
		_pairs_ok, _pairs, _clicked, _again, ", ".join(_apart) if not _apart.is_empty() else "none"])

	await _gate_over_all()
	await _finish()


# -- the way in ------------------------------------------------------------------

func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("hudfront")
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


# -- the walk's ------------------------------------------------------------------

## Ctrl+F, "87087" typed in Find's field, then F1, and F9: keys a person
## presses, as the walk pressed them.
func _walk() -> void:
	print("\nthe walk's: Ctrl+F, \"%s\", then F1, then F9" % TYPED)
	for second: String in ["the keys sheet", "Render"]:
		await _put_away()
		await _press(Keymap.key_of("select_find"))
		var list: Control = await _shown("Find's list")
		if list == null:
			_check("%s opens Find's list" % Keymap.listed("select_find"), false)
			continue
		for character: String in TYPED:
			await _type(character)
		await _frames(10)
		var heading: String = str((list.get("_heading") as Label).text)
		await _press(Keymap.key_of("keys" if second == "the keys sheet" else "render"))
		var opened: Control = await _shown(second)
		if opened == null:
			_check("%s from Find's field opens %s" % [Keymap.listed("keys" if second == "the keys sheet"
				else "render"), second], false)
			continue
		await _frames(6)
		var took: Array = await _takes(list, opened)
		_check("Find's list (\"%s\"), then %s by its key: %s takes a click at %s, the middle of what they share (the window's own hover: %s)"
			% [heading, second, took[0], _point(took[2]), took[1]],
			took[0] == second and took[1] == second)
		await _shot("walk_find_then_%s" % second.trim_prefix("the ").replace(" ", "_"))


# -- a pair ----------------------------------------------------------------------

## [param first] opened, then [param second]: the second takes a click at
## the middle of what they share; a click on the first where it is in sight
## brings it forward; the second asked for again comes forward again.
func _pair(first: String, second: String) -> void:
	await _put_away()
	_pairs += 1
	var said: String = "%s then %s" % [first, second]
	if not await _open(first) or not await _open(second):
		_check("%s: both open (%s %s, %s %s)" % [said, first, _up(first), second, _up(second)], false)
		return
	await _frames(4)
	var a: Control = _node(first)
	var b: Control = _node(second)
	if not a.is_visible_in_tree():
		# The two are never up at once: the second puts the first away.
		_apart.append("%s (%s closes %s)" % [said, second, first])
		_pairs_ok += 1
		return
	var shared: Rect2 = a.get_global_rect().intersection(b.get_global_rect())
	if not shared.has_area():
		_apart.append(said)
		_pairs_ok += 1
		return
	var took: Array = await _takes(a, b)
	var right: bool = took[0] == second and took[1] == second
	var words: String = "%s: %s takes a click at %s (hover: %s)" % [said, took[0], _point(took[2]), took[1]]
	if not right:
		_check(words, false)
		return
	# A click on the first where the second leaves it in sight.
	var spot: Variant = _clear_spot(a, b)
	if spot == null:
		words += "; %s is wholly under it" % first
	else:
		await _click(spot)
		await _frames(4)
		var after: Array = await _takes(b, a)
		var forward: bool = after[0] == first and after[1] == first
		words += "; a click on %s at %s brings it forward (%s takes the middle; hover: %s)" % [first,
			_point(spot), after[0], after[1]]
		if not forward:
			_check(words, false)
			return
		_clicked += 1
		if first == "Find's list" and second == "the keys sheet":
			await _shot("clicked_forward_find_over_keys")
		# The second asked for again, from its menu, its key or its button.
		await _open(second, true)
		await _frames(6)
		if second in TOGGLES:
			words += "; %s asked for again closes (%s)" % [second, "closed" if not b.visible else "still open"]
			if b.visible:
				_check(words, false)
				return
		else:
			var again: Array = await _takes(a, b)
			words += "; asked for again, %s takes it (hover: %s)" % [again[0], again[1]]
			if not (again[0] == second and again[1] == second):
				_check(words, false)
				return
			_again += 1
	_pairs_ok += 1
	_check(words, true)


## The panel's name that takes a click at the middle of what [param under]
## and [param over] share: [by hit-test, by the window's own hover, the
## point].
func _takes(under: Control, over: Control) -> Array:
	var shared: Rect2 = under.get_global_rect().intersection(over.get_global_rect())
	var at: Vector2 = shared.get_center()
	var hit: String = _name_of(_control_at(at))
	await _move(at)
	await _frames(2)
	var hover: String = _name_of(root.gui_get_hovered_control())
	return [hit, hover, at]


## A point of [param panel] outside [param over] that a click reaches the
## panel at, on nothing a click there would change (its backing, a label, a
## picture): or null when none is in sight.
func _clear_spot(panel: Control, over: Control) -> Variant:
	var rect: Rect2 = panel.get_global_rect().grow(-3.0)
	var covered: Rect2 = over.get_global_rect()
	var points: Array[Vector2] = []
	# Its edge first, where its backing is, then across it.
	for inset: float in [0.0, 6.0]:
		var edge: Rect2 = rect.grow(-inset)
		for n: int in 64:
			var t: float = float(n) / 64.0
			points.append(edge.position + Vector2(edge.size.x * t, 0.0))
			points.append(edge.position + Vector2(edge.size.x * t, edge.size.y))
			points.append(edge.position + Vector2(0.0, edge.size.y * t))
			points.append(edge.position + Vector2(edge.size.x, edge.size.y * t))
	for y: int in 24:
		for x: int in 24:
			points.append(rect.position + rect.size * Vector2((x + 0.5) / 24.0, (y + 0.5) / 24.0))
	for at: Vector2 in points:
		if covered.has_point(at) or not root.get_visible_rect().has_point(at):
			continue
		var hit: Control = _control_at(at)
		if hit == null or _top_of(hit) != panel or not _harmless(hit):
			continue
		return at
	return null


static func _harmless(control: Control) -> bool:
	return not (control is BaseButton or control is LineEdit or control is TextEdit
		or control is Range or control is ItemList or control is Tree or control is TabBar
		or control is SubViewportContainer or control is GraphEdit or control is RichTextLabel)


# -- the sign-in screen ------------------------------------------------------------

## Every panel open at once, then the account signed out: the sign-in
## screen takes a click at the middle of each, and a panel asked for and
## clicked while it is up stays under it.
func _gate_over_all() -> void:
	print("\nevery panel open, then signed out")
	await _put_away()
	var open: Array[String] = []
	for panel: String in PANELS:
		if panel in TOGGLES and _node(panel) != null and _node(panel).visible:
			continue
		if await _open(panel):
			open.append(panel)
	await _frames(6)
	var still: Array[String] = []
	for panel: String in open:
		if _node(panel).visible:
			still.append(panel)
	print("    open together: %s" % ", ".join(still))
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	await account.sign_out()
	for _n: int in 300:
		if gate.visible:
			break
		await process_frame
	await _frames(10)
	if not _check("signed out: the sign-in screen is up", gate.visible):
		return
	var under: Array = []
	var over: Array = []
	for panel: String in still:
		var node: Control = _node(panel)
		if node == null or not node.is_visible_in_tree():
			continue
		var at: Vector2 = node.get_global_rect().get_center()
		var hit: String = _name_of(_control_at(at))
		(under if hit == "the sign-in screen" else over).append("%s (%s)" % [panel, hit])
	_check("the sign-in screen takes a click at the middle of each panel still open: %d under it%s"
		% [under.size(), "" if over.is_empty() else "; over it: " + ", ".join(over)],
		over.is_empty() and not under.is_empty())
	await _shot("signed_out_over_every_panel")
	# Asked for while it is up (a session's command, say), and clicked.
	var sheet: Control = _main.get("_controls")
	sheet.call("open_keys")
	await _frames(6)
	var middle: Vector2 = sheet.get_global_rect().get_center()
	var before: String = _name_of(_control_at(middle))
	await _click(middle)
	await _frames(6)
	var after: String = _name_of(_control_at(middle))
	await _move(middle)
	await _frames(2)
	var hover: String = _name_of(root.gui_get_hovered_control())
	_check("the keys sheet asked for while it is up, then clicked: %s takes the click, then %s (hover: %s)"
		% [before, after, hover], before == "the sign-in screen" and after == "the sign-in screen"
		and hover == "the sign-in screen")


# -- the panels ------------------------------------------------------------------

## Opens [param panel] as a person does; whether it showed. [param again]:
## asked for while it is open (its command's way, whatever that does).
func _open(panel: String, again: bool = false) -> bool:
	match panel:
		"the keys sheet":
			_shell.run("keys")
		"Render":
			_shell.run("render")
		"the minifigure builder":
			_shell.run("minifig")
		"the mosaic":
			# The file chooser's answer (Mosaic from a picture… asks for one).
			var image := Image.create(48, 32, false, Image.FORMAT_RGBA8)
			for y: int in 32:
				for x: int in 48:
					image.set_pixel(x, y, Color(x / 48.0, y / 32.0, 0.4))
			_main.set("_picking_reference", false)
			(_main.get("_picker") as Node).emit_signal(&"picked", image)
		"Brickify":
			# A model a session hands it over MCP (AppTools' brickify).
			var brickify: Node = _main.get("_brickify")
			await brickify.call("take", CUBE_OBJ.to_utf8_buffer(), "box.obj")
		"the part maker":
			_shell.run("part_maker")
		"Share":
			_shell.run("share")
		"Account":
			# The bar's Account button.
			(_main.get("_bar") as ModelBar).account_wanted.emit()
		"My collection":
			_shell.run("collection")
		"the Library":
			_shell.run("library")
		"Print on a part":
			_shell.run("print_part")
		"the sticker sheet":
			# The bin's Stickers.
			(_main.get("_bin") as PartsBin).stickers_wanted.emit()
		"the page laid out":
			# The timeline on a step first, as a person clicks one: the page
			# laid out is that step's.
			var steps: StepsBar = _main.get("_steps")
			if steps.current_step() == null:
				steps.refresh(1)
				await _frames(4)
			_shell.run("booklet_lay_out")
		"Find's list":
			_shell.run("select_find")
	if again:
		return true
	return await _shown(panel) != null


## [param panel] once it shows, waited for (a panel's first opening makes
## it); null if it does not.
func _shown(panel: String) -> Control:
	for _n: int in 600:
		var node: Control = _node(panel)
		if node != null and node.is_visible_in_tree():
			await _frames(3)
			return node
		await process_frame
	return null


func _node(panel: String) -> Control:
	match panel:
		"the keys sheet":
			return _main.get("_controls_made")
		"Render":
			return _main.get("_render_made")
		"the minifigure builder":
			return _main.get("_figures_made")
		"the mosaic":
			return _main.get("_mosaic_made")
		"Brickify":
			return _main.get("_brickify_made")
		"the part maker":
			return _main.get("_elements_made")
		"Share":
			return _main.get("_share_panel_made")
		"Account":
			return _main.get("_account_panel")
		"My collection":
			return _shell.get("_collection") if _shell != null else null
		"the Library":
			return _shell.get("_library_dialog") if _shell != null else null
		"Print on a part":
			var studio: Node = _main.get("_studio_made")
			return studio.get("editor") if studio != null else null
		"the sticker sheet":
			var studio: Node = _main.get("_studio_made")
			return studio.get("sheet") if studio != null else null
		"the page laid out":
			return _main.get("_page_editor_made")
		"Find's list":
			return _main.get("_inventory_made")
	return null


func _up(panel: String) -> String:
	var node: Control = _node(panel)
	return "not made" if node == null else ("open" if node.is_visible_in_tree() else "closed")


## Every panel closed, as its own close does.
func _put_away() -> void:
	root.gui_release_focus()
	for panel: String in PANELS:
		var node: Control = _node(panel)
		if node == null or not node.visible:
			continue
		match panel:
			"Find's list":
				node.call("hide_list")
			"the keys sheet", "the mosaic", "the part maker", "Share", "Account":
				node.visible = false
			_:
				node.call("close")
	await _frames(6)


# -- what is where ---------------------------------------------------------------

## The control a click at [param at] reaches, as the window finds it: the
## last drawn first, by canvas layer and then by the tree (Main._control_at
## within each).
func _control_at(at: Vector2) -> Control:
	var layers: Array = []
	for node: Node in root.find_children("*", "CanvasLayer", true, false):
		var layer: CanvasLayer = node as CanvasLayer
		if layer.visible and layer.get_viewport() == root:
			layers.append(layer)
	# Drawn in order of layer, then of the tree: the last drawn is on top.
	var order: Array = range(layers.size())
	order.sort_custom(func(x: int, y: int) -> bool:
		var lx: int = (layers[x] as CanvasLayer).layer
		var ly: int = (layers[y] as CanvasLayer).layer
		return lx > ly if lx != ly else x > y)
	for n: int in order:
		var layer: CanvasLayer = layers[n]
		var found: Control = _main.call("_control_at", layer, layer.get_final_transform().affine_inverse() * at)
		if found != null:
			return found
	return null


## The child of the HUD [param control] is in.
func _top_of(control: Node) -> Node:
	var node: Node = control
	while node != null and node.get_parent() != _hud:
		node = node.get_parent()
	return node


## What a click on [param control] reaches, by the panel's name: one of
## [constant PANELS], the sign-in screen, Render's veil, or what else.
func _name_of(control: Control) -> String:
	if control == null:
		return "nothing (the model)"
	var top: Node = _top_of(control)
	if top == null:
		return "%s, outside the HUD" % control.name
	if top == _main.get("_gate"):
		return "the sign-in screen"
	for panel: String in PANELS:
		if top == _node(panel):
			return panel
	if top.has_meta(&"hud_front_under") or (top is ColorRect and top.get_index() + 1 < _hud.get_child_count()
			and _hud.get_child(top.get_index() + 1) == _node("Render")):
		return "Render's veil"
	return "%s (%s)" % [top.name, top.get_class()]


func _point(at: Vector2) -> String:
	return "(%d, %d)" % [roundi(at.x), roundi(at.y)]


# -- helpers ---------------------------------------------------------------------

func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


## A character typed as the window delivers it.
func _type(character: String) -> void:
	var code: int = character.to_upper().unicode_at(0)
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code as Key
		event.physical_keycode = code as Key
		event.unicode = character.unicode_at(0) if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


## A point on the app's canvas in the window's pixels.
func _px(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


## On Xvfb the system's pointer too, before each event (mosaic_window_probe).
func _warp(at: Vector2) -> void:
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(at)


func _move(at: Vector2) -> void:
	at = _px(at)
	_warp(at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await process_frame


func _click(at: Vector2) -> void:
	await _move(at)
	at = _px(at)
	for down: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = at
		press.global_position = at
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(press)
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(named: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % ProjectSettings.globalize_path(path))


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	if _failures == 0:
		print("hudfront probe: all checks passed")
	else:
		print("hudfront probe: %d check(s) FAILED" % _failures)
	var world: Variant = _main.get("_world") if _main != null else null
	if world != null:
		(world as BrickWorld).clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)
