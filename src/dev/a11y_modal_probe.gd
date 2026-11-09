## Every dialog that holds the window is modal to a screen reader, and only
## those (APP_UX7 #15, a11ymodal).
##
##   godot --path . --resolution 1280x720 --script src/dev/a11y_modal_probe.gd
##   tools/probe.sh a11y_modal_probe
##   PROBE_SIZE=1400x900 tools/probe.sh a11y_modal_probe
##   ... -- --only=about,new    some ways only (a list, by commas)
##   ... -- --shots=DIR         a picture of each way, kept there
##
## Read as a screen reader reads it: the app is run again in a D-Bus
## session of its own, where tools/a11y_tree.py says a screen reader is on
## (as Orca does), so Godot's own "auto" accessibility comes on as it does
## for a person with one, and the tree is read back over AT-SPI as Orca
## finds a window: pointed at (the middle of its title bar and of its face)
## and read up through the parents of what is there, and from the element
## that took the focus: each window's role, name and its MODAL state.
## Not by listing the window's children: AccessKit cuts that list short in
## this app (tools/a11y_tree.py says where). Nothing on the person's own
## bus is touched.
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in (made with the
## admin key and a password, as mosaic_window_probe does), the screen gone;
## the account deleted at the end. Needs .env.
##
## Then each way a dialog comes up, one at a time, put away before the
## next: About; New over a part taken off ("Start a new model?"); Import's
## file chooser (Godot's own: this bus has no portal); Save as, and the
## "replace it?" its own chooser asks over a file already there; the
## Reference picture, left beside the model on purpose; and every dialog
## and panel the menus open (a11y_names_probe's OPENERS, and those that
## want a part selected). At each, every window over the app is judged:
## one ModalDialogs holds, or a dialog's own question, is MODAL in the
## tree; any other is not; and none holds the window without ModalDialogs
## (its close would be dropped). Where one is modal, the focus a screen
## reader reads is inside the top one. With About up, the keys are taken
## from the window and given back, as switching to another program and
## back does, and the focus is still inside it.
##
## On pre261 (2026-11-08) every dialog ModalDialogs held was a plain dialog
## to a screen reader, not modal: dialogclose made them not exclusive, and
## the engine says a window is modal by that flag.
extends SceneTree

const READER := "res://tools/a11y_tree.py"
const PROBE := "res://src/dev/a11y_modal_probe.gd"
## The commands that open a dialog or a panel, as a11y_names_probe opens them.
const NAMES := preload("res://src/dev/a11y_names_probe.gd")
## Each first, then NAMES' own.
const FIRST: Array[String] = ["about", "new", "import_ldraw", "save_as", "reference"]
## How long the reader may take over one read.
const READ_MS := 90000
## The roles a window has in the tree.
const WINDOWS: Array[String] = ["dialog", "frame", "window", "alert", "file chooser", "color chooser"]

var _failures: int = 0
var _main: Node
var _shell: Shell
var _holder: ModalDialogs
var _dir: String = ""
var _shots: String = ""
var _asked: int = 0
var _xid: int = 0
var _email: String = ""
var _password: String = ""
## Each dialog judged to hold the window, by its title: modal or not.
var _held_seen: Dictionary = {}
## Each window judged to be beside the model, not holding it: modal or not.
var _beside_seen: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
		elif argument.begins_with("--dir="):
			_dir = argument.trim_prefix("--dir=")
	if OS.get_cmdline_user_args().has("--child"):
		_child()
	else:
		_parent()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


# -- the parent: the app run again where a screen reader is on --------------


func _parent() -> void:
	if DisplayServer.get_name() != "X11":
		print("a11y_modal_probe: not run: a screen reader's tree is read over X11's AT-SPI "
			+ "(run it as its header says)")
		quit(3)
		return
	var folder: String = OS.get_user_data_dir().path_join("a11y_modal")
	DirAccess.make_dir_recursive_absolute(folder)
	for old: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(old))
	var size: Vector2i = DisplayServer.window_get_size()
	var arguments := PackedStringArray(["--", "python3", "-I",
		ProjectSettings.globalize_path(READER), folder, "--", OS.get_executable_path(),
		"--resolution", "%dx%d" % [size.x, size.y], "--path", ProjectSettings.globalize_path("res://"),
		"--script", PROBE, "--", "--child", "--dir=" + folder])
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only=") or argument.begins_with("--shots="):
			arguments.append(argument)
	print("a11y_modal: in a %d x %d window" % [size.x, size.y])
	var said: Array = []
	var code: int = OS.execute("dbus-run-session", arguments, said, true)
	var output: String = "".join(said)
	print(output)
	var failed: int = 0
	for line: String in output.split("\n"):
		if line.begins_with("  FAIL"):
			failed += 1
	_check("the app's tree was read where a screen reader is on, on a bus of the run's own",
		output.contains("a screen reader said to be on"))
	_check("the run came to its end and passed: exit %d, %d checks failed" % [code, failed],
		code == 0 and failed == 0 and output.contains("a11y_modal: every dialog"))
	if output.contains("SCRIPT ERROR") or output.contains("Parse Error"):
		_check("the run had no script error", false)
	print("a11y_modal: %s" % ("PASS" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the child: the app, as a person with a screen reader meets it ---------


func _child() -> void:
	Account.where = "user://probe_session.json"
	Account._clear()
	# Godot's own Save dialog: on this bus there is no portal to show one.
	SaveTo.native = false
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	_shell = _main.get("_shell")
	_holder = root.get_node_or_null("ModalDialogs")
	_check("ModalDialogs is on the window", _holder != null)
	_xid = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	print("    accessibility on in the app: %s" % is_accessibility_enabled())
	if _holder == null or not await _way_in():
		await _finish()
		return
	# The keys given to the window, as a click on it gives them on a
	# desktop: Xvfb has no window manager to.
	var first: Dictionary = await _ask({"do": "away", "xid": _xid})
	var frames: int = 0
	for node: Dictionary in first.get("windows", []):
		if node.get("role") == "frame":
			frames += 1
	_check("the app is in the tree a screen reader reads, its window a frame (%s, %d nodes read in %d ms)"
		% [first.get("app", first.get("error", "nothing")), int(first.get("nodes", 0)),
		int(first.get("ms", 0))], frames >= 1)

	var ways: Array[String] = FIRST.duplicate()
	for name: String in NAMES.OPENERS + NAMES.WITH_A_SELECTION:
		if not ways.has(name):
			ways.append(name)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			ways.assign(argument.trim_prefix("--only=").split(",", false))
	for way: String in ways:
		await _way(way)

	var held: Array = _held_seen.keys()
	var modal: int = 0
	for title: String in held:
		if _held_seen[title]:
			modal += 1
	var beside: int = 0
	for title: String in _beside_seen:
		if not _beside_seen[title]:
			beside += 1
	_check("every dialog that held the window was modal to a screen reader: %d of %d (%s)"
		% [modal, held.size(), ", ".join(held)], held.size() > 0 and modal == held.size())
	_check("every window beside the model was not: %d of %d (%s)" % [beside, _beside_seen.size(),
		", ".join(_beside_seen.keys())], beside == _beside_seen.size())
	if _failures == 0:
		print("a11y_modal: every dialog that holds the window is modal to a screen reader")
	await _finish()


## One way a dialog comes up: brought up, read, judged, put away.
func _way(way: String) -> void:
	var before: Dictionary = _shown()
	var builder: Builder = _main.get("_builder")
	var store: ModelStore = _main.get("_store")
	if way == "new" or way in NAMES.WITH_A_SELECTION:
		for brick: BrickWorld.Brick in (_main.get("_world") as BrickWorld).bricks():
			if not store.scenery.has(brick.id):
				builder.select_brick(brick.id, false)
				break
		await _frames(4)
		if way == "new":
			# A part taken off, so New asks first.
			builder.remove_selection()
			await _frames(4)
	if way == "reference":
		var reference: ReferenceImage = _main.get("_reference")
		reference.take(Image.load_from_file(
			ProjectSettings.globalize_path("res://tools/release/best_car.png")), "car")
	if not _shell.run(way):
		print("  (%s cannot be run now)" % way)
		return
	# Up, and settled: what it fills in drawn.
	var until: int = Time.get_ticks_msec() + 5000
	await _frames(12)
	while _shown().size() <= before.size() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(6)
	await _shot(way)
	await _look(way, {"do": "read"})
	if way == "about":
		await _look("about, the keys taken from the window and given back",
			{"do": "away", "xid": _xid})
	if way == "save_as" and SaveTo.showing != null and SaveTo.showing.visible:
		await _replace_question(SaveTo.showing)
	# Its work done before it is put away: a coroutine still waiting at quit
	# broke the heap on exit (a11y_names_probe).
	await _idle()
	await _put_away(before)


## Save as's own question over a file already there: "replace it?", a
## dialog of the chooser's, not the window's.
func _replace_question(chooser: FileDialog) -> void:
	var path: String = chooser.current_dir.path_join(chooser.current_file)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check("a file to save over at %s" % path, false)
		return
	file.store_string("0 a file already there\n")
	file.close()
	chooser.get_ok_button().pressed.emit()
	var until: int = Time.get_ticks_msec() + 3000
	var question: Window = null
	while question == null and Time.get_ticks_msec() < until:
		await process_frame
		for sub: Window in root.get_embedded_subwindows():
			if sub.visible and sub != chooser and chooser.is_ancestor_of(sub):
				question = sub
	_check("Save as asks before it writes over %s (%s)" % [path.get_file(),
		"“%s”" % question.title if question != null else "nothing asked"], question != null)
	if question == null:
		return
	await _frames(6)
	await _shot("save_as_replace")
	await _look("save_as, replace it?", {"do": "read"})
	if question is ConfirmationDialog:
		(question as ConfirmationDialog).get_cancel_button().pressed.emit()
	question.hide()
	await _frames(4)
	DirAccess.remove_absolute(path)


## Every window over the app, as a screen reader finds it: pointed at, the
## middle of its title bar and of its face, and read up through the parents
## of what is there (as Orca's mouse review does), and from the focus.
func _look(way: String, what: Dictionary) -> void:
	var over: Array[Window] = []
	for sub: Window in root.get_embedded_subwindows():
		if sub.visible and not sub.get_flag(Window.FLAG_POPUP) and sub.get_parent() != null:
			over.append(sub)
	# In the window's own pixels, as the reader points: the app's drawing is
	# scaled to the window (canvas_items stretch, the person's size).
	var to_pixels: Transform2D = root.get_final_transform()
	var points: Array = []
	for sub: Window in over:
		var bar: float = sub.get_theme_constant("title_height")
		var face := Rect2(Vector2(sub.position), Vector2(sub.size))
		for at: Vector2 in [face.position + Vector2(face.size.x / 2.0, -bar / 2.0), face.get_center()]:
			var pixel: Vector2 = to_pixels * at
			points.append([pixel.x, pixel.y])
	what["points"] = points
	_judge(way, await _ask(what), over)


func _judge(way: String, tree: Dictionary, over: Array[Window]) -> void:
	if tree.has("error"):
		_check("%s: the tree was read (%s)" % [way, tree["error"]], false)
		return
	var hits: Array = tree.get("hits", [])
	var focus: Variant = tree.get("focus")
	var focused: Array = focus if focus is Array else []
	var top: String = ""
	for n: int in over.size():
		var sub: Window = over[n]
		var title: String = _spoken(sub)
		var own_question: bool = sub.get_parent().get_window() != root
		var held: bool = _holder.get("_held").has(sub)
		var holds: bool = held or (own_question and sub.exclusive)
		if not own_question and not held and sub.exclusive and sub.transient:
			_check("%s: “%s” holds the window only as the engine does, so its close is dropped"
				% [way, title], false)
		var node: Dictionary = {}
		var found_there: PackedStringArray = []
		for k: int in [2 * n, 2 * n + 1]:
			var at: Array = (hits[k] as Dictionary).get("chain", []) if k < hits.size() else []
			found_there.append(_said(at))
			if node.is_empty():
				node = _window_named(at, title)
		# Pointed at, or else heard through the focus inside it: a panel put
		# away stays in the tree (Godot does not tell AccessKit a Control
		# was hidden), and over a dialog it is what the pointer finds.
		var found_by: String = "pointed at"
		if node.is_empty():
			node = _window_named(focused, title)
			found_by = "by its focus"
		if node.is_empty():
			_check("%s: “%s” (%s) is in the tree a screen reader reads (pointed at, found: %s; the focus: %s)"
				% [way, title, sub.get_class(), " / ".join(found_there), _said(focused)], false)
			continue
		var modal: bool = bool(node.get("modal"))
		_check("%s: “%s”, %s, %s, is %s to a screen reader (%s, %s, %s)" % [way, title,
			sub.get_class(), "a question of its dialog" if own_question else ("holding the window"
			if holds else "beside the model"), "modal" if holds else "not modal",
			node.get("role"), "MODAL" if modal else "not modal", found_by], modal == holds)
		var key: String = title if not own_question else "%s (its question)" % title
		if holds:
			_held_seen[key] = bool(_held_seen.get(key, true)) and modal
			top = title
		else:
			_beside_seen[key] = bool(_beside_seen.get(key, false)) or modal
	if over.is_empty():
		print("    %s: no window over the app (a panel of its own)" % way)
	if not top.is_empty():
		_check("%s: the focus a screen reader hears is inside “%s” (%s)" % [way, top,
			_said(focused) if not focused.is_empty() else "nothing focused"],
			not _window_named(focused, top).is_empty())


## The window's name in the tree: what Godot says it is called (Window's
## _get_accessibility_name: its accessibility name, else its title).
static func _spoken(window: Window) -> String:
	return window.accessibility_name if not window.accessibility_name.is_empty() \
		else window.tr(window.title)


## In an element's chain up through its parents, the window of that name.
static func _window_named(chain: Array, title: String) -> Dictionary:
	for node: Dictionary in chain:
		if str(node.get("role")) in WINDOWS and str(node.get("name")) == title:
			return node
	return {}


## A chain as a person would hear it, nearest first.
static func _said(chain: Array) -> String:
	var words: PackedStringArray = []
	for node: Dictionary in chain:
		words.append("%s “%s”%s" % [node.get("role"), str(node.get("name")).left(40),
			" MODAL" if bool(node.get("modal")) else ""])
	return " < ".join(words) if not words.is_empty() else "nothing"


## One ask of the reader, and its answer.
func _ask(what: Dictionary) -> Dictionary:
	_asked += 1
	var path: String = _dir.path_join("ask_%d.json" % _asked)
	var file: FileAccess = FileAccess.open(path + ".part", FileAccess.WRITE)
	file.store_string(JSON.stringify(what))
	file.close()
	DirAccess.rename_absolute(path + ".part", path)
	var answer: String = _dir.path_join("tree_%d.json" % _asked)
	var until: int = Time.get_ticks_msec() + READ_MS
	while not FileAccess.file_exists(answer) and Time.get_ticks_msec() < until:
		await process_frame
	if not FileAccess.file_exists(answer):
		return {"error": "the reader gave no answer in %d s" % (READ_MS / 1000)}
	var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(answer))
	if not read is Dictionary:
		return {"error": "the reader's answer did not read"}
	var tree: Dictionary = read
	var asked: Dictionary = tree.get("asked", {})
	if asked.has("away"):
		print("    %s" % asked["away"])
	return tree


## Put away: Escape first, as a person would; then anything still up that
## was not before, each dialog closed as its window's close button closes
## it, so whoever awaits its answer hears "cancelled" (a11y_names_probe).
func _put_away(before: Dictionary) -> void:
	_key(KEY_ESCAPE)
	await _frames(4)
	for id: int in _shown():
		if before.has(id):
			continue
		var thing: Object = instance_from_id(id)
		if thing is AcceptDialog and (thing as Window).visible:
			(thing as Window).close_requested.emit()
		if thing is Window and (thing as Window).visible:
			(thing as Window).hide()
		elif thing is CanvasItem:
			(thing as CanvasItem).visible = false
	await _frames(4)


## The windows and the panels of the shell that are showing, by id.
func _shown() -> Dictionary:
	var out: Dictionary = {}
	_gather_shown(root, out, 0)
	return out


func _gather_shown(node: Node, out: Dictionary, depth: int) -> void:
	if node is Window and node != root:
		if (node as Window).visible:
			out[node.get_instance_id()] = true
		return
	if depth > 6:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is CanvasItem:
		out[node.get_instance_id()] = true
	for child: Node in node.get_children(true):
		_gather_shown(child, out, depth + 1)


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("a11ymodal")
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
## token bucket, not a code's verify (mosaic_window_probe).
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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


## Until the app says it is busy with nothing (Working), and Colour the
## hidden parts has drawn its pictures, a minute at most.
func _idle() -> void:
	var hidden: Node = _main.get("_hidden_colours")
	for _n: int in 3600:
		if not Working.is_busy() and (hidden == null or not bool(hidden.get("_working"))):
			return
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_shots.path_join("a11y_modal_%s.png" % name))


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("a11y_modal: %s" % ("all checks passed" if _failures == 0 else "%d checks failed" % _failures))
	quit(1 if _failures > 0 else 0)
