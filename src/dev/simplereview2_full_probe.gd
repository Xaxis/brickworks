## simplereview2_full: the studio in Full as everyone has it today, pictured
## and its header listed, so a tree with Simple's switch (simple1) can be held
## to one without it (pre261 b74893382) byte for byte. Names nothing of
## Simple's, so it runs in both trees.
##
##   PROBE_SIZE=1280x800 tools/probe.sh simplereview2_full_probe -- --desktop --pictures=DIR
##   PROBE_SIZE=390x844 tools/probe.sh simplereview2_full_probe -- --pictures=DIR
##
## Pictures (DIR/<size>_<what>.png): a new model with the status line waited
## out; the car framed; on a phone the parts sheet and More open. Lists each
## header control's name and rectangle, and on a phone whether Redo is on the
## top bar or in More. Exits 0 unless the app did not come up.
##
## godot --path . --resolution 390x844 --script src/dev/simplereview2_full_probe.gd
extends SceneTree

var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _store: ModelStore
var _phone: Node
var _desktop: bool = false
var _pictures: String = "user://sr2full/"
var _size: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--desktop":
			_desktop = true
		elif arg.begins_with("--pictures="):
			_pictures = arg.get_slice("=", 1).trim_suffix("/") + "/"
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Phone._on = 0 if _desktop else 1
	Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_phone = _main.get("_phone")
	if _phone != null:
		_phone.set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_store = _main.get("_store")
	_store.keeps = false
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_pictures))
	print("simplereview2_full_probe: a %s window, %s, controls %s" % [_size, "desktop" if _desktop else "phone",
		str(_main.call("controls_layer")) if _main.has_method("controls_layer") else "(none: no switch)"])
	_main.call("clear_model")
	await _frames(10)
	_camera.set_view("default")
	await _settle()
	await _frames(60)
	await create_timer(4.5).timeout
	await _frames(4)
	_header("new")
	await _shot("new")
	_main.call("_open", ProjectSettings.globalize_path("res://models/car.ldr"))
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(30)
	(_main.get("_builder") as Builder).clear_selection()
	_camera.set_view("default")
	_camera.frame(_world.model_bounds())
	await _settle()
	await _frames(60)
	await create_timer(4.5).timeout
	await _frames(4)
	_header("car")
	await _shot("car")
	if _phone != null:
		for sheet: String in ["parts", "more"]:
			_phone.call("_chose", sheet)
			await _frames(30)
			await create_timer(1.0).timeout
			await _shot("car_sheet_" + sheet)
			_phone.call("_chose", sheet)
			await _frames(30)
		var state: Dictionary = _phone.call("state") if _phone.has_method("state") else {}
		print("  phone: redo on the top bar %s, in More %s" % [state.get("redo_on_top", "?"),
			state.get("more_redo", "?")])
	print("simplereview2_full_probe: done")
	quit(0)


## Each header control by name with its rectangle, and the desktop's menus
## shown on the bar.
func _header(what: String) -> void:
	var named: Dictionary = {}
	if _phone != null:
		named = _phone.call("controls_by_name")
	else:
		named = (_main.get("_bar") as Control).call("controls_by_name")
	var keys: Array = named.keys()
	keys.sort()
	var lines := PackedStringArray()
	for key: Variant in keys:
		var control: Control = named[key] as Control
		if control != null and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			lines.append("%s@%d,%d %dx%d" % [key, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	print("  header (%s): %s" % [what, " ".join(lines)])
	if _phone == null:
		var bar: Node = _main.get("_bar")
		print("  menus shown on the bar: %s" % str(bar.get("menus_shown")))


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_pictures) + "%s_%s.png" % [_size, name])


func _settle() -> void:
	var last := Transform3D()
	var still: int = 0
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			still += 1
			if still >= 3:
				break
		else:
			still = 0
		last = _camera.global_transform
	await RenderingServer.frame_post_draw


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
