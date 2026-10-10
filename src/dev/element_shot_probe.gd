## The element maker in the real window, and pictures of what it made.
##
##   godot --path . --resolution 1400x900 --script src/dev/element_shot_probe.gd
##
## Presses "Make a part…" in the parts bin, sets the dialog to a 2 x 7
## brick, waits for its preview to draw, and keeps the window as
## shots/element_dialog.png. Then adds it, makes a 1 x 5 plate, a
## 3 x 3 x 2/3 slope, an inverted slope and a 3 x 3 round brick the same
## way, and stands each beside the library part it is a cousin of — 3001,
## 3023b, 3039, 3660a, 3941 — with the 2 x 7 clutched between two 2 x 4s:
## shots/element_beside.png. Made parts are red, the library's grey.
##
## A window is needed because the preview and the thumbnails are drawn by
## SubViewports. Run it on Xvfb, never on somebody's screen (tools/check.sh
## does that for you).
extends SceneTree

const SHOTS := "res://shots/"
const PROBE_DIR := "user://custom_parts_shot/"
const MADE := 4      ## red
const LIBRARY := 71  ## light bluish grey

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	_forget_kept()
	# Before main starts, so it neither loads the person's own made parts
	# into these pictures nor keeps these in their bin.
	CustomParts.dir = PROBE_DIR
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var store: ModelStore = _main.get("_store")
	# A probe is not somebody's session: leave their working model alone.
	store.keeps = false
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()

	var bin: PartsBin = _main.get("_bin")
	var library: PartLibrary = _main.get("_library")
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var dialog: ElementDialog = _main.get("_elements")
	_ok(dialog != null and not dialog.visible, "the dialog is there, closed")

	# The button a person presses.
	bin._on_colour(MADE)
	var button: Button = _find_button(bin, "Make a part…")
	_ok(button != null, "the parts bin has a Make a part… button")
	if button == null or dialog == null:
		_finish()
		return
	builder.held_part = "3001"
	button.pressed.emit()
	await process_frame
	_ok(dialog.visible, "pressing it opens the dialog")
	_ok(dialog.spec().derived_from == "3001",
		"...starting from the part in hand, 3001, ready to resize")
	dialog.set_field("family", "brick")
	dialog.set_field("across", 7)
	dialog.set_field("deep", 2)
	dialog.set_field("plates", 3)
	for _n: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	_ok(dialog.built() != null and dialog.built().problem.is_empty(),
		"it previews a 2 x 7 brick")
	_ok(_preview_drew(dialog), "and the preview draws it")
	_save("element_dialog.png")

	var ids: Array[String] = []
	ids.append(await _add(dialog, library))
	var makes: Array = [
		{"family": "brick", "across": 5, "deep": 1, "plates": 1},
		{"family": "slope", "across": 3, "deep": 3, "run": 2, "plates": 2},
		{"family": "inverted", "across": 3, "deep": 3, "run": 2, "plates": 4},
		{"family": "round", "diameter": 3, "plates": 6},
	]
	for fields: Dictionary in makes:
		button.pressed.emit()
		for key: String in fields:
			dialog.set_field(key, fields[key])
		ids.append(await _add(dialog, library))
	_ok(not ids.has(""), "five parts made: %s" % ", ".join(ids))

	# In the bin, under Custom, with pictures.
	for _n: int in 60:
		await process_frame
	var thumbnails: PartThumbnails = _main.get("_thumbnails")
	var drawn: int = 0
	for id: String in ids:
		if thumbnails.request(id, MADE) != null:
			drawn += 1
	_ok(drawn == ids.size(), "the bin has drawn all %d in red (%d)" % [ids.size(), drawn])

	# Beside their cousins in the library.
	world.clear()
	builder.lattice.clear()
	store.scenery.clear()
	# Each made part, then its cousin in the library, left to right, in
	# two rows so the picture is not a strip.
	var pairs: Array = [
		[ids[0], "3001"], [ids[1], "3023b"], [ids[2], "3039"],
		[ids[3], "3660a"], [ids[4], "3941"],
	]
	var placed: Array[int] = []
	for index: int in pairs.size():
		var pair: Array = pairs[index]
		var row: int = 0 if index < 3 else 1
		var cursor: float = 0.0
		for earlier: int in range(0 if row == 0 else 3, index):
			for part: Variant in pairs[earlier]:
				cursor += library.mesh_for(str(part)).bounds.size.x + 12.0
			cursor += 32.0
		for n: int in 2:
			var part_id: String = str(pair[n])
			var wide: float = library.mesh_for(part_id).bounds.size.x
			placed.append(_put(world, builder, library, part_id,
				MADE if n == 0 else LIBRARY,
				Vector3(cursor + wide * 0.5, 0.0, row * 150.0)))
			cursor += wide + 12.0
	# And the 2 x 7, clutched between two 2 x 4s, at the end of the
	# second row.
	placed.append(_put(world, builder, library, "3001", LIBRARY, Vector3(390.0, 0.0, 150.0)))
	placed.append(_put(world, builder, library, ids[0], MADE, Vector3(400.0, 24.0, 150.0)))
	placed.append(_put(world, builder, library, "3001", LIBRARY, Vector3(410.0, 48.0, 150.0)))
	_main.call("_lay_baseplate")
	builder.hide_preview()
	# Framed on the parts, not the baseplate under them.
	var box := AABB()
	for brick_id: int in placed:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var bounds: AABB = brick.transform * library.mesh_for(brick.part_id).bounds
		box = bounds if box.size == Vector3.ZERO else box.merge(bounds)
	# The assistant's panel folded away, for a wider view, and the camera
	# square on to the rows and a little above them.
	var chat: SideDock = _main.get("_chat_dock")
	if chat != null:
		chat.set_open(false, false)
	bin.show_category("Custom")
	# After the app has had its own say about the view, which it does on
	# a model change.
	for _n: int in 30:
		await process_frame
	var camera: CadCamera = _main.get("_camera")
	camera.set("_target_yaw", 0.0)
	camera.set("_target_pitch", deg_to_rad(34.0))
	# The 3D view runs under the parts bin, so a box framed in the middle
	# of the window has its left end behind the panel: frame it as though
	# it reached further left, which moves it right on screen.
	camera.frame(box.merge(AABB(box.position - Vector3(box.size.x * 0.5, 0.0, 0.0),
		Vector3.ONE)), 0.72)
	for _n: int in 180:
		await process_frame
	builder.hide_preview()
	await RenderingServer.frame_post_draw
	_save("element_beside.png")
	_finish()


func _finish() -> void:
	_forget_kept()
	print("")
	if _failures == 0:
		print("the dialog makes parts in the window, and the pictures are in shots/")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget_kept() -> void:
	if not DirAccess.dir_exists_absolute(PROBE_DIR):
		return
	for name: String in DirAccess.get_files_at(PROBE_DIR):
		DirAccess.remove_absolute(PROBE_DIR + name)
	DirAccess.remove_absolute(PROBE_DIR)


func _find_button(under: Node, text: String) -> Button:
	for child: Node in under.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child
	return null


func _add(dialog: ElementDialog, library: PartLibrary) -> String:
	var made: Array = []
	dialog.made.connect(func(id: String) -> void: made.append(id), CONNECT_ONE_SHOT)
	dialog.press_add()
	await process_frame
	return made[0] if not made.is_empty() and library.parts.has(made[0]) else ""


## Stand a part with its underside at [param at].y, centred at x and z.
func _put(world: BrickWorld, builder: Builder, library: PartLibrary, part_id: String,
		color: int, at: Vector3) -> int:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null:
		_ok(false, "%s has geometry" % part_id)
		return 0
	var where := Transform3D(Basis.IDENTITY,
		Vector3(at.x - mesh.bounds.get_center().x, at.y - mesh.bounds.position.y,
			at.z - mesh.bounds.get_center().z))
	var id: int = world.add_brick(part_id, color, where)
	builder.register(id, part_id, where)
	return id


## Whether the preview's picture has the part in it: some of its pixels
## are far from the background.
func _preview_drew(dialog: ElementDialog) -> bool:
	var view: SubViewport = dialog.get("_view")
	var image: Image = view.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var differ: int = 0
	var back := Color(0.16, 0.17, 0.20)
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			var c: Color = image.get_pixel(x, y)
			if absf(c.r - back.r) + absf(c.g - back.g) + absf(c.b - back.b) > 0.25:
				differ += 1
	return differ > 20


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SHOTS + name)
	image.save_png(path)
	print("  wrote shots/%s (%d x %d)" % [name, image.get_width(), image.get_height()])
