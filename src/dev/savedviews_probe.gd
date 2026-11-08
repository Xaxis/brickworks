## Views and render presets kept (APP_UX5 #8, savedviews).
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x720 \
##       --script src/dev/savedviews_probe.gd
##
## The sample car looked at from three places a person would keep: a
## three-quarter view close on its front, square on from above, and from
## low behind with the model turned on its side as Build it turns a step.
## Each saved as a person saves one, by its key and a name; the model saved,
## closed and opened again; then each saved view's own key looks from it
## again: the window's camera back within 0.1° and 0.1 LDU of where it was,
## its square-on size too. Each of the ten commands has a key under every
## preset, and none is a key another command has under any of them.
##
## The render queue's "Add each saved view" queues one of each, and each is
## the same picture as the window turned to that view and added as it looks
## (each differs from the others). Render's choices kept as a preset, changed,
## and chosen again in two actions: the list opened, the preset picked.
## view_model {"view": NAME} answers with the window's picture from there,
## and render_model {"view": NAME} with a render from there, each one call;
## a name the model does not keep is answered with those it does.
##
##   -- --keep=DIR    leaves the file it saved in DIR, with how many parts it has
##   -- --older=DIR   opens the file left there, to be run by an older
##                    Brickworks, which knows nothing of saved views: it
##                    opens whole, the views' lines still in the file
##
## Leaves shots/savedviews/: the window from each view after the model was
## opened again, the Save dialog, Render with the preset chosen, the queue,
## and the queue's six pictures, each name ending in the window's size.
extends SceneTree

const OUT := "res://shots/savedviews/"
const META := "0 !BRICKWORKS VIEW "
const MINE: Array[String] = ["save_view", "saved_view_1", "saved_view_2", "saved_view_3",
	"saved_view_4", "saved_view_5", "saved_view_6", "saved_view_7", "saved_view_8",
	"saved_view_9"]
## What is "back": the bar's.
const DEGREES := 0.1
const LDU := 0.1

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _shell: Node
var _camera: Camera3D
var _size: String = ""
## The three views: [name, the camera's transform at rest, square on, its size].
var _views: Array = []
var _kept: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 60:
		await process_frame
	var playback: Node = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	_world = _main.get("_world")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_camera = _main.get("_camera")
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]

	var older: String = _argument("--older")
	if not older.is_empty():
		await _opened_by_an_older_one(older)
	elif not ResourceLoader.exists("res://src/ui/saved_views.gd") \
			or int(_shell.call("menu_id", "save_view")) < 0:
		_check("View › Viewpoint › Save this view… keeps a view with the model", false)
		print("\nsavedviews: a person cannot keep a view with the model here")
		quit(1)
		return
	else:
		await _saved_and_opened()
		_keys()
		await _queued()
		await _sessions()
		await _preset()
		var keep: String = _argument("--keep")
		if not keep.is_empty():
			_leave_in(keep)
	print("")
	if _failures == 0:
		print("savedviews: an older Brickworks opens the file whole" if not older.is_empty()
			else "savedviews: three views kept with the model and back after it opened, a key "
				+ "each, each rendered from exactly there, a preset chosen again in two actions, "
				+ "and both tools in one call (%s)" % _size)
	else:
		print("savedviews: %d FAILED (%s)" % [_failures, _size])
	quit(1 if _failures > 0 else 0)


# -- saved, closed and opened ---------------------------------------------------------


func _saved_and_opened() -> void:
	print("  three views saved, the model closed and opened (%s)" % _size)
	var placed: int = int(_main.call("_open", "res://models/car.ldr"))
	await _settled()
	_check("the sample car opens (%d parts)" % placed, placed > 50 and _parts() == placed)
	var box: AABB = _world.model_bounds()
	var middle: Vector3 = box.get_center()
	var turned := Quaternion(Vector3(0, 0, 1), deg_to_rad(90.0))
	var aims: Array = [
		["Front door", false, {"yaw": 0.42, "pitch": 0.22, "distance": 230.0,
			"focus": [middle.x + 12.0, middle.y - 4.0, box.end.z - 20.0]}],
		["Plan", true, {"yaw": 0.0, "pitch": deg_to_rad(80.0), "distance": 600.0,
			"focus": [middle.x, middle.y, middle.z], "size": 310.0}],
		["Low behind, on its side", false, {"yaw": -2.3, "pitch": -0.18, "distance": 420.0,
			"focus": [middle.x - 6.0, middle.y + 8.0, middle.z],
			"frame": [turned.x, turned.y, turned.z, turned.w]}],
	]
	var dialog: Node = null
	for aim: Array in aims:
		_camera.call("square_on", bool(aim[1]))
		_camera.call("aim_at", aim[2])
		await _at_rest()
		# As a person keeps one: its key, a name typed, Enter.
		root.gui_release_focus()
		await _press(int(Keymap.key_of("save_view")))
		dialog = _shell.call("saved_views")
		var typed: LineEdit = dialog.get("_name") as LineEdit
		_check("%s opens Save this view, a name offered (“%s”)" % [Keymap.written("save_view"),
			typed.text if typed != null else ""], (dialog as Window).visible and typed != null
			and not typed.text.is_empty())
		if aim[0] == "Plan":
			await _shoot("save_dialog")
		typed.text = str(aim[0])
		typed.text_submitted.emit(typed.text)
		await _frames(3)
		_views.append([aim[0], _camera.global_transform, _camera.projection
			== Camera3D.PROJECTION_ORTHOGONAL, _camera.size])
	var kept: Array = _world.get("saved_views")
	_check("the model keeps three views (%s)" % ", ".join(PackedStringArray(kept.map(
		func(view: Dictionary) -> String: return str(view["name"])))), kept.size() == 3)
	var turned_kept: bool = kept.size() == 3 and (kept[2] as Dictionary).has("frame")
	_check("the third keeps the model's turn, the second its square-on size",
		turned_kept and bool((kept[1] as Dictionary).get("square", false))
		and absf(float((kept[1] as Dictionary).get("size", 0.0)) - 310.0) < 0.01)

	var path: String = ModelStore.SAVE_DIR + "savedviews.ldr"
	var saved: bool = bool(_main.call("save_model", path))
	var lines: PackedStringArray = _lines_of(FileAccess.get_file_as_string(path))
	_check("saved: %d view lines in the file" % lines.size(), saved and lines.size() == 3)
	_kept["savedviews.ldr"] = _parts()
	_main.call("clear_model")
	await _settled()
	_check("closed: nothing on the baseplate, no views kept", _parts() == 0
		and (_world.get("saved_views") as Array).is_empty())
	_camera.call("square_on", false)
	_camera.call("aim_at", {"yaw": 1.9, "pitch": 0.6, "distance": 900.0, "focus": [0, 0, 0]})
	await _at_rest()
	_main.call("_open", path)
	await _settled()
	var moved: Vector3 = _world.model_bounds().get_center() - middle
	_check("opened again: %d parts, %d views" % [_parts(), (_world.get("saved_views") as Array).size()],
		_parts() == int(_kept["savedviews.ldr"]) and (_world.get("saved_views") as Array).size() == 3)

	# Each by its own key, from wherever the window looked.
	for n: int in _views.size():
		var was: Array = _views[n]
		var key: int = int(Keymap.key_of("saved_view_%d" % (n + 1)))
		root.gui_release_focus()
		await _press(key)
		await _at_rest()
		var now: Transform3D = _camera.global_transform
		var off: float = (now.origin - moved).distance_to((was[1] as Transform3D).origin)
		var angle: float = rad_to_deg(Quaternion(now.basis.orthonormalized()).angle_to(
			Quaternion((was[1] as Transform3D).basis.orthonormalized())))
		var square: bool = _camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		var size_off: float = absf(_camera.size - float(was[3])) if square else 0.0
		_check("%s looks from “%s” again: %.4f LDU and %.4f° from where it was%s" % [
			Keymap.written("saved_view_%d" % (n + 1)), was[0], off, angle,
			(", square on, its size %.4f LDU off" % size_off) if square else ""],
			off <= LDU and angle <= DEGREES and square == bool(was[2]) and size_off <= LDU)
		await _shoot("view_%d" % (n + 1))
	# The rows of View › Viewpoint name them.
	var popup: PopupMenu = _viewpoint_menu()
	var rows := PackedStringArray()
	if popup != null:
		_shell.call("_refresh", popup)
		for n: int in 3:
			var at: int = int(_shell.call("item_index", popup, "saved_view_%d" % (n + 1)))
			rows.append(popup.get_item_text(at) if at >= 0 else "")
	_check("View › Viewpoint's rows name them: %s" % ", ".join(rows),
		rows.size() == 3 and rows[0] == "Front door" and rows[2] == "Low behind, on its side")


## The camera come to rest where it was sent.
func _at_rest() -> void:
	for _n: int in 900:
		await process_frame
		if is_equal_approx(float(_camera.get("_yaw")), float(_camera.get("_target_yaw"))) \
				and float(_camera.get("_pitch")) == float(_camera.get("_target_pitch")) \
				and float(_camera.get("distance")) == float(_camera.get("_target_distance")) \
				and (_camera.get("focus") as Vector3) == (_camera.get("_target_focus") as Vector3) \
				and (_camera.get("_frame") as Basis) == (_camera.get("_target_frame") as Basis):
			break
	await _frames(3)


func _viewpoint_menu() -> PopupMenu:
	var view: MenuButton = _shell.call("menu", "View")
	if view == null:
		return null
	for child: Node in view.get_popup().get_children(true):
		if child is PopupMenu and int(_shell.call("item_index", child, "save_view")) >= 0:
			return child
	return null


# -- a key each -----------------------------------------------------------------------


func _keys() -> void:
	print("  a key each, none another command's")
	var was: String = Keymap.preset()
	Keymap.key_of("save_view")
	var native: Dictionary = Keymap._native
	for preset: String in Keymap.PRESETS:
		Keymap.use(preset)
		var keys: Dictionary = {}
		for action: String in MINE:
			var key: int = Keymap.key_of(action)
			if key != 0:
				keys[key] = action
		# Any other command that would have one of them, here or out of the box.
		var wanting := PackedStringArray()
		var layers: Array = [Keymap._preset_layer(preset), Keymap._preset_layer("brickworks"),
			native]
		for layer: Dictionary in layers:
			for action: String in layer:
				if not action in MINE and keys.has(int(layer[action])):
					wanting.append("%s wants %s" % [action, Shell.key_text(int(layer[action]))])
		_check("%s: %d of %d have a key of their own (%s); %s" % [Keymap.PRESET_NAMES[preset],
			keys.size(), MINE.size(), ", ".join(PackedStringArray(keys.keys().map(
				func(key: int) -> String: return Shell.key_text(key)))),
			"no other command's" if wanting.is_empty() else ", ".join(wanting)],
			keys.size() == MINE.size() and wanting.is_empty())
	Keymap.use(was)


# -- the render queue -----------------------------------------------------------------


func _queued() -> void:
	print("  a queued render of each draws exactly that view")
	_shell.call("run", "render_queue")
	await _frames(3)
	var queue: RenderQueue = RenderQueue.of(_main)
	if queue == null:
		_check("File › Render queue… opens", false)
		return
	var folder: String = ProjectSettings.globalize_path(OUT + "queue_" + _size)
	DirAccess.make_dir_recursive_absolute(folder)
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	queue.folder = folder
	var dialog: RenderDialog = _main.get("_render")
	dialog.settings.quality = RenderSettings.Quality.QUICK
	dialog.settings.size = Vector2i(640, 360)
	dialog.settings.view = "current"
	dialog.settings.focal_mm = roundf(RenderSettings.focal_for(_camera.fov, dialog.settings.size))
	var controls: Dictionary = queue.controls_by_name()
	var add_views: Button = controls.get("queue_add_views")
	_check("the queue has Add each saved view", add_views != null and not add_views.disabled)
	if add_views == null:
		return
	add_views.pressed.emit()
	await _frames(2)
	_check("it queues one of each (%d)" % queue.items.size(), queue.items.size() == 3)
	# The window turned to each, by its key, and added as it looks.
	for n: int in 3:
		await _press(int(Keymap.key_of("saved_view_%d" % (n + 1))))
		await _at_rest()
		(controls["queue_add"] as Button).pressed.emit()
		await _frames(2)
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 240000:
		await process_frame
		if queue.items.all(func(item: RenderQueue.Item) -> bool: return item.finished()):
			break
	await _shoot("queue")
	var pictures: Array[Image] = []
	for item: RenderQueue.Item in queue.items:
		var image := Image.new()
		var ok: bool = not item.path.is_empty() and image.load(item.path) == OK
		pictures.append(image if ok else null)
		_check("%d %s: %s" % [item.number, item.what(), item.path.get_file()], ok)
	if pictures.size() != 6 or pictures.has(null):
		return
	for n: int in 3:
		var off: float = _rmse(pictures[n], pictures[n + 3])
		_check("“%s” queued is the window turned there: %.4f apart" % [_views[n][0], off],
			off <= 0.005)
	var apart: Array = [_rmse(pictures[0], pictures[1]), _rmse(pictures[1], pictures[2]),
		_rmse(pictures[0], pictures[2])]
	_check("each its own view (%.3f, %.3f, %.3f apart)" % apart, apart.min() > 0.03)
	queue.close()


# -- a session's one call -------------------------------------------------------------


func _sessions() -> void:
	print("  view_model and render_model by a view's name, one call each")
	var assistant: Variant = _main.get("_assistant")
	var looked: Variant = await assistant.use_tool("view_model", {"view": "Plan"})
	var picture: Image = _image_in(looked)
	_check("view_model {\"view\": \"Plan\"} answers with a picture (%s)" % (
		"%dx%d" % [picture.get_width(), picture.get_height()] if picture != null
		else str(looked).left(160)), picture != null)
	var dialog: RenderDialog = _main.get("_render")
	if picture != null:
		# The window's own picture from there, drawn as Render draws "as I see it".
		await _press(int(Keymap.key_of("saved_view_2")))
		await _at_rest()
		var chosen := RenderSettings.new()
		chosen.quality = RenderSettings.Quality.QUICK
		chosen.size = picture.get_size()
		chosen.focal_mm = RenderSettings.focal_for(_camera.fov, chosen.size)
		chosen.view = "current"
		chosen.keep_eye(_camera)
		while dialog.renderer.is_busy():
			await process_frame
		var window: Image = await dialog.renderer.render(_world, chosen)
		var off: float = _rmse(picture, window) if window != null else 1.0
		_check("...the window's from there: %.4f apart" % off, off <= 0.005)
		picture.save_png(OUT + "view_model_%s.png" % _size)
	var wrong: String = str(await assistant.use_tool("view_model", {"view": "Garage"}))
	_check("a name it does not keep names those it does: %s" % wrong.left(120),
		wrong.contains("Front door") and wrong.contains("Plan"))

	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = assistant
	var said: Variant = await tools.run("render_model", {"view": "Front door", "quality": "quick",
		"size": "720p"})
	var rendered: Image = dialog.last_picture()
	var text: String = str((said as Array)[0].get("text", "")) if said is Array else str(said)
	_check("render_model {\"view\": \"Front door\"} renders it: %s" % text.left(140),
		said is Array and rendered != null and rendered.get_size() == Vector2i(1280, 720))
	if rendered != null:
		await _press(int(Keymap.key_of("saved_view_1")))
		await _at_rest()
		var chosen: RenderSettings = dialog.settings.copy()
		chosen.quality = RenderSettings.Quality.QUICK
		chosen.size = Vector2i(1280, 720)
		chosen.look = "window"
		chosen.view = "current"
		chosen.call("forget_eye")
		chosen.keep_eye(_camera)
		while dialog.renderer.is_busy():
			await process_frame
		var window: Image = await dialog.renderer.render(_world, chosen)
		var off: float = _rmse(rendered, window) if window != null else 1.0
		_check("...from exactly there: %.4f from the window turned to it" % off, off <= 0.005)
		rendered.save_png(OUT + "render_model_%s.png" % _size)
	var refused: String = str(await tools.run("render_model", {"view": "Garage"}))
	_check("render_model of a view it does not keep says which it keeps: %s" % refused.left(120),
		refused.contains("Front door") and refused.contains("hero"))


static func _image_in(answer: Variant) -> Image:
	if not answer is Array:
		return null
	for block: Variant in answer:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "image":
			var data: PackedByteArray = Marshalls.base64_to_raw(str(block["source"]["data"]))
			var image := Image.new()
			if image.load_png_from_buffer(data) == OK:
				return image
	return null


# -- a render preset ------------------------------------------------------------------


func _preset() -> void:
	print("  a render preset saved, and chosen again in two actions")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://render_presets.cfg"))
	_shell.call("run", "render")
	await _frames(6)
	var dialog: RenderDialog = _main.get("_render")
	var controls: Dictionary = dialog.controls_by_name()
	var preset: OptionButton = controls.get("render_preset")
	_check("Render has a Preset list and Save…", preset != null
		and controls.get("render_preset_save") != null)
	if preset == null:
		return
	var camera: OptionButton = controls["render_view"]
	var listed := PackedStringArray()
	for n: int in camera.item_count:
		if camera.get_item_metadata(n) is Dictionary:
			listed.append(camera.get_item_text(n))
	_check("its Camera lists the model's views: %s" % ", ".join(listed), listed.size() == 3)
	# Good, square, dark, from the view square on from above.
	await _choose(controls["render_good"])
	await _choose(controls["render_size_square"])
	await _choose(controls["render_bg_dark"])
	for n: int in camera.item_count:
		if camera.get_item_metadata(n) is Dictionary and str(camera.get_item_metadata(n)["saved"]) == "Plan":
			camera.select(n)
			camera.item_selected.emit(n)
	await _frames(3)
	var wanted: Dictionary = dialog.settings.call("preset")
	(controls["render_preset_save"] as Button).pressed.emit()
	await _frames(3)
	var asking: ConfirmationDialog = dialog.get("_preset_ask")
	var named: LineEdit = dialog.get("_preset_name")
	_check("Save… asks for a name", asking != null and asking.visible and named != null)
	if named == null:
		return
	named.text = "Square plan"
	asking.get_ok_button().pressed.emit()
	await _frames(3)
	var file := ConfigFile.new()
	_check("kept for any model, in this computer's settings",
		file.load("user://render_presets.cfg") == OK and file.has_section("Square plan"))
	# Changed by hand: Quick, 720p, white, Render's three-quarter view.
	await _choose(controls["render_quick"])
	await _choose(controls["render_size_720p"])
	await _choose(controls["render_bg_white"])
	camera.select(0)
	camera.item_selected.emit(0)
	await _frames(3)
	_check("changed by hand, no preset is chosen", preset.selected == 0
		and dialog.settings.call("preset") != wanted)
	# The two actions: the list opened, the preset picked.
	var actions: int = 0
	preset.show_popup()
	actions += 1
	await _frames(3)
	var at: int = -1
	for n: int in preset.item_count:
		if preset.get_item_text(n) == "Square plan":
			at = n
	preset.get_popup().index_pressed.emit(at)
	preset.get_popup().hide()
	actions += 1
	await _frames(6)
	var now: Dictionary = dialog.settings.call("preset")
	var put: PackedStringArray = []
	for key: String in wanted:
		if str(now.get(key)) != str(wanted[key]):
			put.append("%s %s, not %s" % [key, now.get(key), wanted[key]])
	_check("chosen again in %d actions: every choice back (%s)" % [actions,
		"quality Good, square, dark, from “Plan”" if put.is_empty() else "; ".join(put)],
		actions == 2 and at >= 0 and put.is_empty() and preset.selected == at
		and (controls["render_good"] as Button).button_pressed
		and (controls["render_size_square"] as Button).button_pressed
		and (controls["render_bg_dark"] as Button).button_pressed
		and camera.get_item_text(camera.selected) == "“Plan”")
	# The draft drawn again with the preset's choices, for the picture.
	for _n: int in 600:
		await process_frame
		if not dialog.renderer.is_busy():
			break
	await _frames(10)
	await _shoot("render_preset")
	(controls["render_close"] as Button).pressed.emit()
	await _frames(3)


func _choose(button: Button) -> void:
	button.button_pressed = true
	button.pressed.emit()
	await _frames(2)


# -- an older Brickworks --------------------------------------------------------------


func _leave_in(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for file: String in _kept:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR + file),
			folder.path_join(file))
	var out: FileAccess = FileAccess.open(folder.path_join("parts.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(_kept, "\t"))
	out.close()
	print("  left %d files in %s" % [_kept.size(), folder])


func _opened_by_an_older_one(folder: String) -> void:
	print("  opened by this Brickworks")
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		folder.path_join("parts.json")))
	_check("the file a newer one saved is there", listed is Dictionary
		and not (listed as Dictionary).is_empty())
	if not listed is Dictionary:
		return
	for file: String in listed:
		var path: String = folder.path_join(file)
		var lines: int = _lines_of(FileAccess.get_file_as_string(path)).size()
		var placed: int = int(_main.call("_open", path))
		await _settled()
		_check("%s (its %d view lines) opens whole: %d parts of %d" % [file, lines, _parts(),
			int(listed[file])], lines == 3 and placed == int(listed[file])
			and _parts() == int(listed[file]))


# -- reading the app ------------------------------------------------------------------


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


static func _lines_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with(META):
			out.append(line.strip_edges())
	return out


## A key and its modifiers, down and up, as the window delivers them.
func _press(accel: int) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = Keymap.press_of(accel)
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settled() -> void:
	for _n: int in 600:
		await process_frame
		if (_world.get("_dirty") as Dictionary).is_empty() \
				and not bool(_world.get("_rebuild_queued")) and _store.awaited.is_empty():
			break
	for _n: int in 3:
		await process_frame


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _size]
	image.save_png(OUT + file)
	print("    the window: %s" % file)


static func _rmse(a: Image, b: Image) -> float:
	var first: Image = a.duplicate() as Image
	var second: Image = b.duplicate() as Image
	first.convert(Image.FORMAT_RGB8)
	second.convert(Image.FORMAT_RGB8)
	if first.get_size() != second.get_size():
		return 1.0
	var one: PackedByteArray = first.get_data()
	var two: PackedByteArray = second.get_data()
	var sum: float = 0.0
	for n: int in one.size():
		var d: float = float(one[n] - two[n])
		sum += d * d
	return sqrt(sum / float(maxi(one.size(), 1))) / 255.0


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.trim_prefix(prefix + "=")
	return ""
