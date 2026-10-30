## View, Reference picture… (docs/APP_UX2.md, refimage): a picture to build
## over, driven as a person drives it, clicks and keys sent as input events
## against the real scene.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --resolution 1280x720 --script src/dev/refimage_probe.gd
##
## And at the larger window: PROBE_SIZE=1400x900 tools/probe.sh refimage_probe.
## Pictures go to shots/refimage/WxH/.
##
## The bar, each read off the scene or its pixels:
##   - added in 4 actions or fewer: View, Reference picture…, the file's name,
##     Open, and the picture is in the scene;
##   - its width typed in studs exact to 1 LDU: 32.35 typed is 647 LDU,
##     corner to corner;
##   - drawn at 40% opacity: 40 typed, the window's pixels over the picture
##     are 40% picture and 60% what is behind it, measured against the same
##     pixels with it hidden and with it at 100%, in the space the renderer
##     blends in (the tone curve set straight for the three pictures, as
##     the blend is what is measured);
##   - locked, a click through it selects the part behind; unlocked, the same
##     click picks the picture out and selects no part;
##   - saved and opened again the same: where it lies, its width, opacity,
##     lock, name and picture, and the pixels where it is drawn;
##   - absent from a render (Render…) and from the booklet (Instructions),
##     with it at 100% under the model where a person sees it; and from
##     Export's picture of the model.
## Also: a corner dragged sizes it from the corner across, keeping its shape;
## the picture dragged slides it in its plane; never in the model's exported
## or published text; and gone with a new model.
##
## And the app's baseline, each failing without its fix:
##   - every change one step of Edit › Undo, which puts it back as it was,
##     and Redo does it again: laid, the opacity slider dragged (a pause in
##     the drag and all), its width typed a figure at a time, slid, sized by
##     a corner, stood up, locked, another chosen, taken away;
##   - a change to the picture alone is unsaved work, so New asks first, and
##     Undo back to as saved is none; a picture laid on an empty baseplate is
##     unsaved work too, and the autosave keeps it: the app started again
##     brings it back.
extends SceneTree

const PART := "3001"
const RED := 4
const NAME := "Refimage probe"
## The picture: magenta, which no part in the scene is, with a white band
## across its top so it has a top.
const SIZE := Vector2i(400, 300)
const MAGENTA := Color(1, 0, 1)

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
var _reference: ReferenceImage
var _fields: Dictionary = {}
var _acts: int = 0
var _pointer := Vector2.ZERO
var _brick_id: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


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
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_reference = _main.get("_reference")
	print("  window %s, %s" % [DisplayServer.window_get_size(),
		RenderingServer.get_current_rendering_method()])
	_check("the app has a reference picture (Main._reference)", _reference != null)
	if _reference == null:
		_finish()
		return
	_fields = _reference.controls_by_name()
	await _model()
	await _shot("before")
	var file: String = _picture_file()
	await _add(file)
	if not _reference.has_picture():
		_finish()
		return
	await _width()
	await _opacity()
	await _corners()
	await _undo()
	await _lock()
	await _saved()
	await _absent()
	await _unsaved(file)
	_finish()


func _finish() -> void:
	print("")
	print("refimage: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- the model: one red 2 x 4 brick on the baseplate ------------------------------


func _model() -> void:
	_verbs.set_mode("select")
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(4)
	for _n: int in 600:
		if _library.mesh_for(PART) != null:
			break
		await process_frame
	var where := Transform3D(Basis.IDENTITY, Vector3(10, 24, 0))
	_brick_id = _world.add_brick(PART, RED, where)
	_builder.register(_brick_id, PART, where)
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-200, 0, -200), Vector3(400, 60, 400)))
	await _settle()


## A picture to choose, written where the probe keeps its files.
func _picture_file(called: String = "plan.png", colour: Color = MAGENTA) -> String:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	image.fill_rect(Rect2i(0, 0, SIZE.x, SIZE.y / 6), Color.WHITE)
	var folder: String = OS.get_user_data_dir().path_join("refimage_probe")
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join(called)
	image.save_png(path)
	return path


# -- added ----------------------------------------------------------------------


func _add(file: String) -> void:
	print("  -- added")
	var in_view: bool = false
	for menu: Array in Shell.MENUS:
		if menu[0] == "View" and "reference" in menu[1]:
			in_view = true
	_check("View holds Reference picture…", in_view)
	_check("Find a command finds it by \"reference\" (%s)" % str(_shell.palette.matches("reference")),
		_shell.palette != null and "reference" in _shell.palette.matches("reference"))
	_check("no picture before", not _reference.has_picture())
	var depth: int = _builder.history_depth()
	_acts = 0
	# 1: View.
	var view_menu: MenuButton = _shell.menu("View")
	await _act_click(view_menu.get_global_rect().get_center())
	var popup: PopupMenu = view_menu.get_popup()
	_check("...View opens", popup.visible)
	# 2: Reference picture…, its row.
	var id: int = _shell.menu_id("reference")
	_check("...with Reference picture… in it (%s)" % (
		popup.get_item_text(popup.get_item_index(id)) if id >= 0 else "none"),
		id >= 0 and popup.get_item_text(popup.get_item_index(id)) == "Reference picture…")
	await _shot("view_menu")
	_acts += 1
	popup.id_pressed.emit(id)
	popup.hide()
	await _frames(6)
	var chooser: FileDialog = (_fields["reference_files"] as PictureFile).get("_dialog")
	_check("...which asks for a picture", chooser != null and chooser.visible)
	if chooser == null:
		return
	# 3: the file's name; 4: Open.
	_acts += 1
	chooser.current_path = file
	await _frames(2)
	_acts += 1
	chooser.get_ok_button().pressed.emit()
	await _settle()
	print("    %d actions" % _acts)
	_check("the picture is in the scene (%s, %s)" % [_reference.picture_name,
		_reference.on], _reference.has_picture() and _mesh().visible
		and _reference.picture_name == "plan.png")
	_check("...added in 4 actions or fewer (%d)" % _acts, _acts <= 4)
	_check("...laid on the floor under the model, as wide as it or 16 studs (%.0f LDU)"
		% _reference.width, _reference.on == "floor" and _reference.width >= 320.0
		and absf(_reference.centre.y - ReferenceImage.ABOVE_FLOOR) < 0.01)
	_check("...picked out, its corners showing, and its settings open",
		_reference.selected and (_fields["reference_dialog"] as Window).visible)
	_check("...its shape the picture's (%.3f)" % (_reference.height() / _reference.width),
		absf(_reference.height() / _reference.width - 0.75) < 0.002)
	_check("...kept in the model for its next save", not _store.reference.is_empty())
	# Laid is one step of Undo, as every other change is (_undo).
	var laid: Dictionary = _reference.said()
	var steps: int = _builder.history_depth() - depth
	var named: String = _builder.history_words(1)[0] if steps > 0 else ""
	await _verbs.press("undo")
	await _frames(3)
	var taken: bool = not _reference.has_picture() and not _mesh().visible \
		and _store.reference.is_empty()
	await _verbs.press("redo")
	await _frames(3)
	_check("laid is one step of the history (%d, \"%s\"): Undo takes it away (%s), Redo lays it again, the same"
		% [steps, named, taken], steps == 1 and taken and _reference.has_picture()
		and ReferenceImage.same(_reference.said(), laid) and _mesh().visible)
	_reference.open()
	await _frames(3)
	_camera.set_view("top")
	_camera.frame(_picture_box())
	await _settle()
	await _shot("added")


# -- its width, typed ------------------------------------------------------------


func _width() -> void:
	print("  -- its width, typed")
	await _type_into(_fields["reference_width"], "32.35")
	var corners: Array[Vector3] = _reference.corners()
	var across: float = corners[0].distance_to(corners[1])
	var drawn: float = (_mesh().mesh as QuadMesh).size.x
	_check("32.35 studs typed is %.3f LDU wide, corner to corner (%.3f drawn)" % [across, drawn],
		absf(across - 647.0) <= 1.0 and absf(drawn - 647.0) <= 1.0)
	_check("...exactly 647 as kept (%s)" % str(_store.reference.get("width")),
		is_equal_approx(float(_store.reference.get("width", 0.0)), 647.0))


# -- drawn at 40% ------------------------------------------------------------------


func _opacity() -> void:
	print("  -- opacity")
	# Standing behind the model, seen from the front, against the sky.
	var plane: OptionButton = _fields["reference_plane"]
	plane.select(1)
	plane.item_selected.emit(1)
	await _frames(4)
	_check("standing behind the model, seen from the front (%s at z %.0f)" % [_reference.on,
		_reference.centre.z], _reference.on == "front"
		and _reference.centre.z < _box_of_brick().position.z
		and absf(_reference.centre.y - _reference.height() * 0.5) < 0.01)
	_camera.set_view("front")
	_camera.frame(_picture_box())
	await _settle()
	# A patch of it well clear of the brick: a third of the way in from its
	# top left.
	var corners: Array[Vector3] = _reference.corners()
	var at: Vector3 = corners[0].lerp(corners[1], 0.3).lerp(corners[3].lerp(corners[2], 0.3), 0.4)
	var where: Vector2 = _camera.screen_of(at)
	var hit: BrickLattice.Hit = _builder.lattice.raycast(_camera.ray_origin(where),
		_camera.ray_normal(where))
	_check("the patch measured is on the picture and on no part (%s)" % str(where.round()),
		_reference.meets(_camera.ray_origin(where), _camera.ray_normal(where)) > 0.0
		and (not hit.is_valid() or _store.scenery.has(hit.brick_id)))
	var environment: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var was: Array = [environment.tonemap_mode, environment.glow_enabled]
	await _type_into(_fields["reference_opacity"], "100")
	var whole: Color = await _patch(where, environment)
	_reference.visible = false
	var behind: Color = await _patch(where, environment)
	_reference.visible = true
	await _type_into(_fields["reference_opacity"], "40")
	var faded: Color = await _patch(where, environment)
	environment.tonemap_mode = was[0]
	environment.glow_enabled = was[1]
	_check("40 typed is kept as 40%% (%s), the slider with it (%.0f)" % [
		str(_store.reference.get("opacity")), (_fields["reference_fade"] as HSlider).value],
		is_equal_approx(float(_store.reference.get("opacity", 0.0)), 0.4)
		and is_equal_approx((_fields["reference_fade"] as HSlider).value, 40.0))
	# Green, which the picture has none of and the sky plenty of, and which
	# nothing clips.
	var linear: bool = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	var p: float = _channel(whole.g, linear)
	var b: float = _channel(behind.g, linear)
	var c: float = _channel(faded.g, linear)
	var alpha: float = (b - c) / maxf(b - p, 0.0001)
	print("    green, %s: behind %.4f, at 100%% %.4f, at 40%% %.4f" % [
		"linear" if linear else "sRGB", b, p, c])
	_check("drawn at 40%% opacity: %.1f%% picture, %.1f%% what is behind it" % [alpha * 100.0,
		(1.0 - alpha) * 100.0], b - p > 0.2 and absf(alpha - 0.4) <= 0.02)
	await _shot("front_40")


## The window's colour over a few pixels round [param at], the tone curve
## straight while it is read.
func _patch(at: Vector2, environment: Environment) -> Color:
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = false
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	var middle := Vector2i((at * scale).round())
	var sum := Color(0, 0, 0, 0)
	var count: int = 0
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var pixel: Vector2i = (middle + Vector2i(dx, dy)).clamp(Vector2i.ZERO,
				image.get_size() - Vector2i.ONE)
			sum += image.get_pixelv(pixel)
			count += 1
	return sum / float(count)


static func _channel(value: float, linear: bool) -> float:
	if not linear:
		return value
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


# -- its corners, and sliding it ---------------------------------------------------------


func _corners() -> void:
	print("  -- a corner dragged, the picture slid")
	_check("picked out (%s)" % _reference.selected, _reference.selected)
	var before: Array[Vector3] = _reference.corners()
	var was: float = _reference.width
	# A corner the settings are not over, dragged away from the one across.
	var corner: int = _free_corner(before)
	_check("a corner of it in sight, clear of its settings (%d)" % corner, corner >= 0)
	if corner < 0:
		return
	var across: int = (corner + 2) % 4
	var from: Vector2 = _camera.screen_of(before[corner])
	var away: Vector2 = (from - _camera.screen_of(before[across])).normalized()
	await _drag(from, from + away * 50.0)
	var after: Array[Vector3] = _reference.corners()
	_check("a corner dragged out sizes it (%.0f to %.0f LDU)" % [was, _reference.width],
		_reference.width > was + 10.0)
	_check("...from the corner across, which stays put (%.2f LDU off)"
		% before[across].distance_to(after[across]),
		before[across].distance_to(after[across]) <= 1.0)
	_check("...keeping its shape (%.3f)" % (_reference.height() / _reference.width),
		absf(_reference.height() / _reference.width - 0.75) < 0.002)
	var middle: Vector3 = _reference.centre
	var grip: Vector2 = _camera.screen_of(middle + Vector3(0, _reference.height() * 0.3, 0))
	await _drag(grip, grip + Vector2(-50, 0))
	_check("the picture dragged slides it in its plane (%s)" % str(
		(_reference.centre - middle).snappedf(0.1)), _reference.centre.x < middle.x - 5.0
		and is_equal_approx(_reference.centre.z, middle.z))
	await _type_into(_fields["reference_width"], "32.35")
	_check("...and its width typed again (%.0f)" % _reference.width,
		is_equal_approx(_reference.width, 647.0))


## A corner of [param points] in sight that the settings are not over, or -1.
func _free_corner(points: Array[Vector3]) -> int:
	var settings: Window = _fields["reference_dialog"]
	var covered := Rect2(Vector2(settings.position), Vector2(settings.size)).grow(12.0)
	for n: int in [3, 0, 2, 1]:
		var at: Vector2 = _camera.screen_of(points[n])
		if not (settings.visible and covered.has_point(at)) and _camera.seen_rect().has_point(at):
			return n
	return -1


# -- every change one step of Undo ---------------------------------------------------------


func _undo() -> void:
	print("  -- every change one step of Undo, and Redo")
	var settings: Window = _fields["reference_dialog"]
	var fade: HSlider = _fields["reference_fade"]
	_check("picked out, its settings open", _reference.selected and settings.visible)
	# The slider dragged as a hand drags it, with a pause longer than the
	# time that joins changes typed one after another.
	var drag_fade: Callable = func() -> void:
		var rect := Rect2(Vector2(settings.position) + fade.get_global_rect().position,
			fade.get_global_rect().size)
		var from := Vector2(rect.position.x + rect.size.x * fade.value / 100.0, rect.get_center().y)
		var to := Vector2(rect.position.x + rect.size.x * 0.85, from.y)
		await _move(from)
		_press(from, true)
		await _frames(2)
		for s: int in range(1, 9):
			await _move(from.lerp(to, s / 8.0), MOUSE_BUTTON_LEFT)
			if s == 4:
				await create_timer(ReferenceImage.ONE_STEP_MS / 1000.0 + 0.4).timeout
		_press(to, false)
		await _frames(4)
	await _one_step("the opacity slider dragged, a pause in it", drag_fade,
		func() -> String: return "%.0f%%" % (_reference.opacity * 100.0))
	var type_width: Callable = func() -> void:
		await _type_into(_fields["reference_width"], "20")
	await _one_step("its width typed, a figure at a time", type_width,
		func() -> String: return "%.0f LDU" % _reference.width)
	var slide: Callable = func() -> void:
		var grip: Vector2 = _camera.screen_of(_reference.centre
			+ Vector3(0, _reference.height() * 0.3, 0))
		await _drag(grip, grip + Vector2(-40, 0))
	await _one_step("slid", slide, func() -> String: return "x %.0f" % _reference.centre.x)
	var size_it: Callable = func() -> void:
		var points: Array[Vector3] = _reference.corners()
		var corner: int = _free_corner(points)
		if corner < 0:
			return
		var from: Vector2 = _camera.screen_of(points[corner])
		var away: Vector2 = (from - _camera.screen_of(points[(corner + 2) % 4])).normalized()
		await _drag(from, from + away * 40.0)
	await _one_step("sized by a corner", size_it,
		func() -> String: return "%.0f LDU" % _reference.width)
	var stand: Callable = func() -> void:
		var plane: OptionButton = _fields["reference_plane"]
		plane.select(2)
		plane.item_selected.emit(2)
		await _frames(3)
	await _one_step("stood seen from the side", stand, func() -> String: return _reference.on)
	var lock_it: Callable = func() -> void:
		(_fields["reference_lock"] as CheckBox).button_pressed = true
		await _frames(3)
	await _one_step("locked", lock_it, func() -> String: return str(_reference.locked))
	var other: String = _picture_file("other.png", Color(0.1, 0.6, 1.0))
	var another: Callable = func() -> void:
		var button: Button = _button_in(settings, "Choose another…")
		if button == null:
			return
		await _click(Vector2(settings.position) + button.get_global_rect().get_center())
		var chooser: FileDialog = (_fields["reference_files"] as PictureFile).get("_dialog")
		if chooser == null or not chooser.visible:
			return
		chooser.current_path = other
		await _frames(2)
		chooser.get_ok_button().pressed.emit()
		await _settle()
	await _one_step("another chosen", another, func() -> String: return _reference.picture_name)
	var take_away: Callable = func() -> void:
		var button: Button = _button_in(settings, "Remove")
		if button == null:
			return
		await _click(Vector2(settings.position) + button.get_global_rect().get_center())
		await _frames(3)
	await _one_step("taken away", take_away,
		func() -> String: return _reference.picture_name if _reference.has_picture() else "none")
	_reference.open()
	await _frames(3)
	await _shot("undone")


## [param change] made as a person makes it, then Edit › Undo, Redo and Undo
## again: one step more in the history, put back as it was, done again the
## same, and left as it was for what follows. [param shown] says it in words.
func _one_step(what: String, change: Callable, shown: Callable) -> void:
	var depth: int = _builder.history_depth()
	var before: String = _state()
	var was: String = str(shown.call())
	await change.call()
	var after: String = _state()
	var now: String = str(shown.call())
	var steps: int = _builder.history_depth() - depth
	var named: String = _builder.history_words(1)[0] if steps > 0 else ""
	await _verbs.press("undo")
	await _frames(3)
	var undone: bool = _state() == before
	var back: String = str(shown.call())
	await _verbs.press("redo")
	await _frames(3)
	var redone: bool = _state() == after
	await _verbs.press("undo")
	await _frames(3)
	_check("%s (%s to %s): one step (%d, \"%s\"), Undo puts it back (%s), Redo again (%s)" % [
		what, was, now, steps, named, back, redone], after != before and steps == 1 and undone
		and redone and _state() == before)


## The picture as the model keeps it, its pixels by their hash.
func _state() -> String:
	var kept: Dictionary = _reference.said()
	var picture: String = str(kept.get("picture", ""))
	kept.erase("picture")
	return "%s %d" % [JSON.stringify(kept), picture.hash()]


## The button saying [param words] in [param window], its own buttons too.
func _button_in(window: Window, words: String) -> Button:
	var buttons: Array = window.find_children("*", "Button", true, false)
	if window is AcceptDialog:
		buttons.append_array((window as AcceptDialog).get_ok_button().get_parent().get_children(true))
	for each: Variant in buttons:
		if each is Button and (each as Button).text == words and (each as Button).is_visible_in_tree():
			return each
	return null


# -- locked, a click through it ------------------------------------------------------------


func _lock() -> void:
	print("  -- locked")
	# From behind, the picture is between the eye and the brick.
	_camera.set_view("back")
	_camera.frame(_picture_box())
	await _settle()
	var brick: Vector3 = _box_of_brick().get_center()
	var at: Vector2 = _camera.screen_of(brick)
	var along: float = _reference.meets(_camera.ray_origin(at), _camera.ray_normal(at))
	var hit: BrickLattice.Hit = _builder.lattice.raycast(_camera.ray_origin(at), _camera.ray_normal(at))
	_check("from the back the picture is in front of the brick (%.0f, the brick %.0f)" % [along,
		hit.distance], along > 0.0 and hit.brick_id == _brick_id and along < hit.distance)
	_reference.set_selected(false)
	_builder.clear_selection()
	await _click(at)
	_check("unlocked, a click there picks the picture out (%s) and no part (%d selected)" % [
		_reference.selected, _builder.selection.size()], _reference.selected
		and _builder.selection.is_empty())
	await _shot("unlocked_click")
	var lock: CheckBox = _fields["reference_lock"]
	lock.button_pressed = true
	await _frames(3)
	_check("Locked ticked: kept locked, and put down", _reference.locked
		and bool(_store.reference.get("locked")) and not _reference.selected)
	await _click(at)
	_check("locked, a click through it selects the part behind (%s)" % str(
		_builder.selection.keys()), _builder.selection.has(_brick_id)
		and _builder.selection.size() == 1 and not _reference.selected)
	await _shot("locked_click")
	_builder.clear_selection()


# -- saved and opened again ------------------------------------------------------------------


func _saved() -> void:
	print("  -- saved and opened again")
	_camera.set_view("front")
	_camera.frame(_picture_box())
	await _settle()
	var corners: Array[Vector3] = _reference.corners()
	var where: Vector2 = _camera.screen_of(corners[0].lerp(corners[2], 0.3))
	var environment: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var was: Array = [environment.tonemap_mode, environment.glow_enabled]
	var drawn: Color = await _patch(where, environment)
	var said: Dictionary = _reference.said()
	var placed: Transform3D = _mesh().global_transform
	_check("saved", _store.save_as(NAME))
	var path: String = ModelStore.saved_path(NAME)
	var text: String = FileAccess.get_file_as_string(path)
	var lines := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("0 !BRICKWORKS REFERENCE"):
			lines.append(line)
	_check("its file keeps it on 2 lines LDraw readers ignore (%d, %d characters)" % [
		lines.size(), text.length()], lines.size() == 2
		and lines[0].begins_with(ReferenceImage.META)
		and lines[1].begins_with(ReferenceImage.PICTURE_META)
		and ModelStore.count_in(text) == 1)
	print("    %s" % lines[0] if not lines.is_empty() else "")
	var exported: String = _store.to_text("Exported", true)
	_check("...and the exported or published text keeps none", not exported.contains("REFERENCE")
		and ModelStore.count_in(exported) == 1)
	_store.begin("")
	await _frames(4)
	_check("a new model has no picture", not _reference.has_picture() and not _mesh().visible
		and _store.reference.is_empty())
	var placed_again: int = _store.open(path)
	await _settle()
	var again: Dictionary = _reference.said()
	var differs: Array = []
	for key: String in said:
		if str(said[key]) != str(again.get(key)):
			differs.append(key)
	_check("opened again (%d part): the same, where it lies, width, opacity, lock, name and picture%s"
		% [placed_again, "" if differs.is_empty() else " — not " + ", ".join(differs)],
		placed_again == 1 and differs.is_empty() and said.size() == again.size())
	_check("...drawn where it was (%s)" % str(_mesh().global_transform.origin),
		_mesh().global_transform.is_equal_approx(placed) and _mesh().visible)
	var drawn_again: Color = await _patch(where, environment)
	environment.tonemap_mode = was[0]
	environment.glow_enabled = was[1]
	_check("...and drawn the same (%s, was %s)" % [drawn_again.to_html(false), drawn.to_html(false)],
		Vector3(drawn.r - drawn_again.r, drawn.g - drawn_again.g, drawn.b - drawn_again.b).length()
			<= 3.0 / 255.0)
	_brick_id = _model_bricks()[0].id if not _model_bricks().is_empty() else 0
	await _shot("opened_again")


# -- never in a render, the booklet or Export's picture ------------------------------------------


func _absent() -> void:
	print("  -- never in a render or the booklet")
	_reference.open()
	await _frames(3)
	(_fields["reference_lock"] as CheckBox).button_pressed = false
	await _frames(2)
	var plane: OptionButton = _fields["reference_plane"]
	plane.select(0)
	plane.item_selected.emit(0)
	await _type_into(_fields["reference_opacity"], "100")
	(_fields["reference_dialog"] as Window).hide()
	_camera.set_view("default")
	_camera.frame(_picture_box())
	await _settle()
	await RenderingServer.frame_post_draw
	var window: Image = root.get_texture().get_image()
	var seen: int = _magenta(window)
	_check("in the window, at 100%% under the model: %d magenta pixels" % seen, seen > 2000)
	await _shot("floor_100")

	var render := StudioRender.new()
	render.library = _library
	render.scenery = _store.scenery
	render.eye = _camera
	render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(render)
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(480, 320)
	settings.view = "hero"
	var rendered: Image = await render.render(_world, settings)
	render.queue_free()
	_save(rendered, "render")
	var drawn: int = _drawn(rendered)
	var in_render: int = _magenta(rendered) if rendered != null else -1
	_check("Render: the model drawn (%d pixels) and none of the picture (%d magenta)" % [drawn,
		in_render], drawn > 500 and in_render == 0)

	BookletMaker.open_when_written = false
	var maker := BookletMaker.new()
	maker.library = _library
	maker.px_per_mm = 2.5
	root.add_child(maker)
	var html: String = await maker.make(_world, {}, NAME)
	maker.queue_free()
	var pictures: int = 0
	var in_booklet: int = 0
	var found: Array[RegExMatch] = RegEx.create_from_string(
		"data:image/(?:png|jpeg|webp);base64,([A-Za-z0-9+/=]+)").search_all(html)
	for each: RegExMatch in found:
		var image: Image = PictureFile.decode(Marshalls.base64_to_raw(each.get_string(1)))
		if image == null:
			continue
		pictures += 1
		in_booklet += _magenta(image)
		if pictures == 1:
			_save(image, "booklet_step")
	_check("the booklet: %d pictures, none of the picture in them (%d magenta)" % [pictures,
		in_booklet], pictures > 0 and in_booklet == 0)

	var exports: Exports = _main.get("_exports")
	var picture: Image = await exports.picture.take(Vector2i(600, 400))
	_save(picture, "export_picture")
	var in_picture: int = _magenta(picture) if picture != null else -1
	_check("Export's picture of the model: drawn (%d pixels), none of the picture (%d magenta)"
		% [_drawn(picture), in_picture], _drawn(picture) > 500 and in_picture == 0)
	await _frames(4)
	_check("...and in the window again after", _mesh().visible and _reference.is_visible_in_tree())


# -- unsaved, and kept by the autosave ----------------------------------------------------------


func _unsaved(file: String) -> void:
	print("  -- a change to the picture alone is unsaved, and the autosave keeps it")
	_check("saved again", _store.save_as(NAME))
	_check("...as saved, nothing unsaved", not _store.has_unsaved_work())
	_reference.open()
	await _frames(3)
	await _type_into(_fields["reference_opacity"], "70")
	(_fields["reference_dialog"] as Window).hide()
	_check("its opacity alone changed (%.0f%%, the parts as saved): unsaved work (%s)" % [
		_reference.opacity * 100.0, _store.has_unsaved_work()], _store.has_unsaved_work()
		and is_equal_approx(_reference.opacity, 0.7))
	var bar: ModelBar = _main.get("_bar")
	var confirm: ConfirmationDialog = bar.get("_confirm_new")
	await bar.ask_for_new()
	await _frames(3)
	_check("...so File › New asks first (%s)" % confirm.visible, confirm.visible)
	await _shot("new_asks")
	confirm.hide()
	await _frames(2)
	_check("...and nothing was begun (%d part, the picture there)" % _model_bricks().size(),
		_model_bricks().size() == 1 and _reference.has_picture())
	await _verbs.press("undo")
	await _frames(3)
	_check("Undo back to as saved: nothing unsaved (%s)" % _store.has_unsaved_work(),
		not _store.has_unsaved_work())
	# New, and only a picture laid on the empty baseplate.
	await bar.ask_for_new()
	await _frames(6)
	_check("New: an empty baseplate and no picture, nothing unsaved",
		_model_bricks().is_empty() and not _reference.has_picture() and not _store.has_unsaved_work())
	# The autosave, which Main leaves off for a probe unless it is about it:
	# this one is, in a data folder of its own (tools/probe.sh).
	_store.keeps = true
	_reference.open()
	await _frames(4)
	var chooser: FileDialog = (_fields["reference_files"] as PictureFile).get("_dialog")
	if chooser != null and chooser.visible:
		chooser.current_path = file
		await _frames(2)
		chooser.get_ok_button().pressed.emit()
		await _settle()
	_check("a picture laid on the empty baseplate (%s): unsaved work (%s)" % [
		_reference.picture_name, _store.has_unsaved_work()], _reference.has_picture()
		and _store.has_unsaved_work())
	var said: Dictionary = _reference.said()
	var kept: String = _store.write_now()
	var text: String = FileAccess.get_file_as_string(kept) if not kept.is_empty() else ""
	_check("the autosave keeps it (%d characters)" % text.length(),
		ReferenceImage.same(ReferenceImage.read(text), said))
	# What the app does as it starts.
	var placed: int = _store.restore()
	await _frames(4)
	_check("...and the app started again brings it back on the empty baseplate (%d parts, %s)" % [
		placed, _reference.picture_name], _reference.has_picture() and _mesh().visible
		and ReferenceImage.same(_reference.said(), said) and ReferenceImage.same(_store.reference, said))


## Pixels of [param image] that are the picture's magenta, at any opacity
## over anything a part here is: red and blue both well over green.
static func _magenta(image: Image) -> int:
	if image == null:
		return -1
	var small: Image = image.duplicate()
	if small.get_format() != Image.FORMAT_RGBA8:
		small.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = small.get_data()
	var count: int = 0
	for n: int in range(0, bytes.size(), 4):
		var r: int = bytes[n]
		var g: int = bytes[n + 1]
		var b: int = bytes[n + 2]
		if bytes[n + 3] > 128 and r - g > 70 and b - g > 70:
			count += 1
	return count


## Pixels of [param image] that are drawn at all.
static func _drawn(image: Image) -> int:
	if image == null:
		return 0
	var copy: Image = image.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = copy.get_data()
	var count: int = 0
	for n: int in range(3, bytes.size(), 4):
		if bytes[n] > 128:
			count += 1
	return count


# -- helpers ---------------------------------------------------------------------------


func _mesh() -> MeshInstance3D:
	return _reference.get_node("Picture")


func _box_of_brick() -> AABB:
	var brick: BrickWorld.Brick = _world.get_brick(_brick_id)
	return brick.transform * _library.mesh_for(brick.part_id).bounds


func _picture_box() -> AABB:
	var box := AABB(_reference.corners()[0], Vector3.ZERO)
	for corner: Vector3 in _reference.corners():
		box = box.expand(corner)
	return box.merge(_box_of_brick()) if _world.get_brick(_brick_id) != null else box


func _model_bricks() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


## [param words] typed into [param field] as a person types them: a click
## into it, what is there selected, each key, then Enter.
func _type_into(field: SpinBox, words: String) -> void:
	var line: LineEdit = field.get_line_edit()
	var settings: Window = _fields["reference_dialog"]
	await _click(Vector2(settings.position) + line.get_global_rect().get_center())
	line.select_all()
	await _frames(2)
	for character: String in words:
		var code: Key = KEY_PERIOD if character == "." else (KEY_0 + int(character)) as Key
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code
			event.physical_keycode = code
			event.unicode = character.unicode_at(0) if down else 0
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	for down: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = down
		Input.parse_input_event(enter)
		await process_frame
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	await create_timer(0.6).timeout
	await _frames(6)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, held: MouseButton = MOUSE_BUTTON_NONE) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _as_event(_pointer)
	event.button_mask = 0 if held == MOUSE_BUTTON_NONE else 1 << (held - 1)
	_pointer = at
	Input.parse_input_event(event)
	await _frames(3)


func _press(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_press(at, true)
	await _frames(2)
	_press(at, false)
	await _frames(4)


func _act_click(at: Vector2) -> void:
	_acts += 1
	await _click(at)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_press(from, true)
	await _frames(2)
	for s: int in range(1, 9):
		await _move(from.lerp(to, s / 8.0), MOUSE_BUTTON_LEFT)
	_press(to, false)
	await _frames(6)


func _save(image: Image, name: String) -> void:
	if image == null:
		return
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = ProjectSettings.globalize_path("res://shots/refimage/%dx%d/%s.png" % [
		size.x, size.y, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), name)
