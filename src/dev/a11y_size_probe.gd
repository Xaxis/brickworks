## Settings, Interface size: the interface drawn smaller or bigger, and
## nothing of it off the window or cut off.
##
##   godot --path . --resolution 1280x800 --script src/dev/a11y_size_probe.gd
##
## Chosen in the Settings dialog as a person chooses it (the choice opened,
## the arrows, Return), at 85% and at 150% of what the window would draw,
## on a laptop's 1280 x 800. Each time the window's scale is the screen's
## factor times the choice, and every control a person can operate that is
## showing (the menus, the toolbar, the parts bin, the view cube, the
## status bar), and the Settings and Keys dialogs opened at that size, lie
## wholly inside the window: a control in a scrolled list is inside its
## list, and the list inside the window. A toolbar that does not fit folds
## its least used groups away whole (Toolbar._fit), so a button is either
## there or not, never cut. Pictures go to shots/a11y_size/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell


func _initialize() -> void:
	_run()


## Settings, Interface size's rows, top down (ShellPrefs.INTERFACE_SIZES).
const SIZES: Array[float] = [0.85, 1.0, 1.15, 1.3, 1.5]


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	(_main.get("_store") as ModelStore).keeps = false
	_main.call("clear_model")
	await _frames(10)

	var window := Vector2(DisplayServer.window_get_size())
	var screen: float = _main.call("screen_factor", window.x, window.y, false)
	print("  a %d x %d window; the screen's own factor %.3f" % [window.x, window.y, screen])
	await _within("100%", screen)
	for size: float in [0.85, 1.5]:
		await _choose(size)
		# All of it, or as much as leaves the frame its height (Main.LEAST_DOWN).
		var wanted: float = _main.call("sized_factor", window.x, window.y, false, size) \
			if _main.has_method("sized_factor") else screen * size
		_check("at %d%% the window is drawn at %.3f (%.3f x %.2f, %.0f%% of it%s)" % [
			roundi(size * 100.0), root.content_scale_factor, screen, size,
			100.0 * wanted / screen, "" if is_equal_approx(wanted, screen * size)
			else ": the frame needs its height"],
			absf(root.content_scale_factor - wanted) < 0.01
			and (size < 1.0 or wanted > screen))
		await _within("%d%%" % roundi(size * 100.0), screen * size)
	await _choose(1.0)
	_finish()


## Interface size chosen in Settings: the choice clicked open, the arrows
## to [param size], Return.
func _choose(size: float) -> void:
	_shell.run("settings")
	await _frames(10)
	var settings: ControlsDialog = _main.get("_controls")
	# Asked by name, so this runs on a build without it and fails there.
	var choice: OptionButton = settings.get("interface_choice") as OptionButton
	if not _check("Settings has Interface size", choice != null):
		settings.visible = false
		return
	await _click(choice.get_global_rect().get_center())
	await _frames(6)
	var menu: PopupMenu = choice.get_popup()
	# The list opens with no row lit; Down lights the first.
	var want: int = SIZES.find(size)
	for _n: int in want + 1:
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(20)
	_check("Interface size %d%% chosen from its list (%s, the list %s)" % [roundi(size * 100.0),
		choice.get_item_text(choice.selected), "shut" if not menu.visible else "open"],
		is_equal_approx(float(ShellPrefs.value("interface_size")), size) and not menu.visible)
	settings.visible = false
	await _frames(10)


## Everything showing inside the window, at [param named]; pictures of it,
## and of Settings and Keys open at that size.
func _within(named: String, factor: float) -> void:
	var room := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	print("  at %s: %d x %d units across the window" % [named, room.size.x, room.size.y])
	await _shot(named)
	var out: Array[String] = []
	var seen: int = _outside(root, room, out)
	_check("at %s, %d controls showing, none off the window or cut off%s" % [named, seen,
		"" if out.is_empty() else ": " + ", ".join(out.slice(0, 6))], seen > 20 and out.is_empty())
	var toolbar: Toolbar = _shell.toolbar
	var shown: int = 0
	for button: Control in toolbar.controls_by_name().values():
		if button.is_visible_in_tree():
			shown += 1
	print("    the toolbar shows %d of its controls" % shown)
	for opener: String in ["settings", "keys"]:
		_shell.run(opener)
		await _frames(12)
		await _shot("%s_%s" % [named, opener])
		if opener == "settings" and named == "100%":
			# Where it always fitted, all of it in sight: a flow clicks
			# Assistant (AI) at the foot by where it is drawn (fit_check).
			var held: ScrollContainer = (_main.get("_controls") as Node).get("_settings")
			_check("...at 100%, every setting in sight without scrolling",
				held == null or not held.get_v_scroll_bar().visible)
		var inside: Array[String] = []
		var count: int = _outside(root, room, inside)
		_check("...%s open: %d controls, none off the window or cut off%s" % [opener, count,
			"" if inside.is_empty() else ": " + ", ".join(inside.slice(0, 6))], inside.is_empty())
		await _key(KEY_ESCAPE)
		await _frames(6)
		var settings: ControlsDialog = _main.get("_controls")
		settings.visible = false
		await _frames(4)


## Counts the operable controls showing under [param node] and lists, in
## [param out], those not wholly inside [param room]. A list (a scroll) must
## be inside it; what is in the list is reached by scrolling it.
func _outside(node: Node, room: Rect2, out: Array[String], scrolled: bool = false) -> int:
	if node is Window and node != root:
		return 0
	if node is CanvasItem and not (node as CanvasItem).visible:
		return 0
	var count: int = 0
	var in_list: bool = scrolled
	if node is Control:
		var control: Control = node
		var rect: Rect2 = control.get_global_rect()
		if _operable(control) and rect.size.x >= 1.0 and rect.size.y >= 1.0:
			count += 1
			if not scrolled and not room.grow(1.0).encloses(rect):
				out.append("%s %s at %s" % [control.get_class(),
					control.accessibility_name if not control.accessibility_name.is_empty()
					else str(control.get("text")), rect])
		if control is ScrollContainer:
			if not scrolled and rect.size.y >= 1.0 and not room.grow(1.0).encloses(rect):
				out.append("a list at %s" % rect)
			in_list = true
	for child: Node in node.get_children():
		count += _outside(child, room, out, in_list)
	return count


static func _operable(control: Control) -> bool:
	if control is ScrollBar:
		return false
	return control is BaseButton or control is LineEdit or control is Slider \
		or control is SpinBox or control is Tree or control is ItemList


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/a11y_size/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/a11y_size/%s.png" % name)


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


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("a11y size probe: all checks passed")
	else:
		print("a11y size probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
