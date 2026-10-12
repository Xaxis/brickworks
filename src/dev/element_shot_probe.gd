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
## Then the families that came after: a brick with studs on its side, two
## brackets, a curved slope and a Technic brick, made through the same
## controls, each beside its cousin (30414, 99781, 99780, 93606, 3701) and
## each in use — round plates on the side studs, a tile on each upright, a
## pin through a hole — in white: shots/element_families.png.
##
## Then parts that exist, changed from their own geometry with "Change it":
## 98283 made four long beside 98283 and 15533 (the 1 x 4 LEGO made), 32000
## made four long beside 32000, 2877 made four long beside 2877, 3062b with
## its stud taken off and 3068bp04, a printed tile, with studs put on round
## its print, 3003 with a corner cut out beside 3003 and 2357 (LEGO's corner
## brick), and 3001 with a notch cut under its middle beside 3001, each
## beside the part it came from: shots/element_changed.png.
##
## A window is needed because the preview and the thumbnails are drawn by
## SubViewports. Run it on Xvfb, never on somebody's screen (tools/check.sh
## does that for you).
extends SceneTree

const SHOTS := "res://shots/"
const PROBE_DIR := "user://custom_parts_shot/"
const MADE := 4      ## red
const LIBRARY := 71  ## light bluish grey
const USED := 15     ## white: what is put on them

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
	# Nothing in hand: the app redraws the ghost of the held part under the
	# pointer every frame, and it stood in the picture as a green phantom.
	builder.held_part = ""
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
	await _families(button, dialog, library, world, builder, store, camera)
	await _changed(button, dialog, library, world, builder, store, camera)
	_finish()


## Parts that exist, changed through "Start from a part", beside what they
## came from.
func _changed(button: Button, dialog: ElementDialog, library: PartLibrary,
		world: BrickWorld, builder: Builder, store: ModelStore, camera: CadCamera) -> void:
	var changes: Array = [
		["98283", {"across": 4}, ["98283", "15533"]],
		["32000", {"across": 4}, ["32000"]],
		["2877", {"across": 4}, ["2877"]],
		["3062b", {"studs_top": "none"}, ["3062b"]],
		["3068bp04", {"studs_top": "fill"}, ["3068bp04"]],
		["3003", {"cut": [1, 0, 2, 1, 0, 3]}, ["3003", "2357"]],
		["3001", {"cut": [1, 0, 3, 2, 0, 1]}, ["3001"]],
	]
	var rows: Array = []
	for change: Array in changes:
		button.pressed.emit()
		var started: bool = dialog.change_part(str(change[0]))
		# Changed as itself, not redrawn as one of the families.
		var as_itself: bool = dialog.edit() != null
		for key: String in change[1]:
			dialog.set_field(key, change[1][key])
		var id: String = await _add(dialog, library)
		var info: PartLibrary.PartInfo = library.parts.get(id)
		_ok(started and as_itself and info != null,
			"changed %s into %s, \"%s\"" % [change[0], id, info.name if info != null else "nothing"])
		if info == null:
			return
		rows.append([id] + change[2])
	world.clear()
	builder.lattice.clear()
	store.scenery.clear()
	var placed: Array[int] = []
	for index: int in rows.size():
		var row: Array = rows[index]
		var cursor: float = 0.0
		for n: int in row.size():
			var part_id: String = row[n]
			var wide: float = library.mesh_for(part_id).bounds.size.x
			placed.append(_put(world, builder, library, part_id, MADE if n == 0 else LIBRARY,
				Vector3(cursor + wide * 0.5, 0.0, -index * 52.0)))
			cursor += wide + 16.0
	_main.call("_lay_baseplate")
	builder.held_part = ""
	builder.hide_preview()
	var box := AABB()
	for brick_id: int in placed:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var bounds: AABB = brick.transform * library.mesh_for(brick.part_id).bounds
		box = bounds if box.size == Vector3.ZERO else box.merge(bounds)
	for _n: int in 30:
		await process_frame
	camera.set("_target_yaw", deg_to_rad(-18.0))
	camera.set("_target_pitch", deg_to_rad(30.0))
	camera.frame(box.merge(AABB(box.position - Vector3(box.size.x * 0.45, 0.0, 0.0),
		Vector3.ONE)), 0.72)
	for _n: int in 180:
		await process_frame
	builder.hide_preview()
	await RenderingServer.frame_post_draw
	_save("element_changed.png")


## The families after the first five, made through the dialog, beside
## their cousins and in use.
func _families(button: Button, dialog: ElementDialog, library: PartLibrary,
		world: BrickWorld, builder: Builder, store: ModelStore, camera: CadCamera) -> void:
	var makes: Array = [
		[{"family": "brick", "across": 4, "deep": 1, "plates": 3, "sides": "f"},
			"30414", "Brick  1 x  4 with Studs on 1 Side"],
		[{"family": "bracket", "across": 2, "deep": 1, "rise": 1, "way": "down"},
			"99781", "Bracket  1 x  2 -  1 x  2 Down"],
		[{"family": "bracket", "across": 2, "deep": 1, "rise": 1, "way": "up"},
			"99780", "Bracket  1 x  2 -  1 x  2 Up"],
		[{"family": "curved", "across": 2, "deep": 4, "plates": 3, "run": 4},
			"93606", "Slope Brick Curved  4 x  2"],
		[{"family": "technic", "across": 4}, "3701", "Technic Brick  1 x  4 with Holes"],
	]
	var ids: Array[String] = []
	for entry: Array in makes:
		button.pressed.emit()
		var fields: Dictionary = entry[0]
		dialog.set_field("family", fields["family"])
		for key: String in fields:
			if key != "family":
				dialog.set_field(key, fields[key])
		var id: String = await _add(dialog, library)
		var info: PartLibrary.PartInfo = library.parts.get(id)
		_ok(info != null and info.name == str(entry[2]),
			"made %s, \"%s\"" % [id, info.name if info != null else "nothing"])
		ids.append(id)
	if ids.has(""):
		return
	world.clear()
	builder.lattice.clear()
	store.scenery.clear()
	var placed: Array[int] = []
	# Two rows, three pairs and two, so the picture is not a strip.
	var cursor: float = 0.0
	for index: int in makes.size():
		var row: int = 0 if index < 3 else 1
		if index == 3:
			cursor = 40.0
		for n: int in 2:
			var part_id: String = ids[index] if n == 0 else str(makes[index][1])
			var wide: float = library.mesh_for(part_id).bounds.size.x
			var brick: int = _put(world, builder, library, part_id,
				MADE if n == 0 else LIBRARY,
				Vector3(cursor + wide * 0.5, 0.0, -row * 110.0))
			placed.append(brick)
			placed.append_array(_in_use(world, builder, library, brick))
			cursor += wide + 16.0
		cursor += 30.0
	var used: int = placed.size() - makes.size() * 2
	# Four round plates on each brick's side, a tile on each upright, a pin
	# in each Technic brick: 4 + 4 + 1 + 1 + 1 + 1 + 1 + 1.
	_ok(used == 14, "and put to use: %d white parts on their studs and in their holes" % used)
	_main.call("_lay_baseplate")
	builder.held_part = ""
	builder.hide_preview()
	var box := AABB()
	for brick_id: int in placed:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var bounds: AABB = brick.transform * library.mesh_for(brick.part_id).bounds
		box = bounds if box.size == Vector3.ZERO else box.merge(bounds)
	for _n: int in 30:
		await process_frame
	# From the front and to the right, a little above: the side studs,
	# the uprights and the holes all face the front.
	camera.set("_target_yaw", deg_to_rad(-20.0))
	camera.set("_target_pitch", deg_to_rad(26.0))
	camera.frame(box.merge(AABB(box.position - Vector3(box.size.x * 0.45, 0.0, 0.0),
		Vector3.ONE)), 0.72)
	for _n: int in 180:
		await process_frame
	builder.hide_preview()
	await RenderingServer.frame_post_draw
	_save("element_families.png")


## Put things on a placed part the way it is used: a 1 x 1 round plate on
## every stud that does not point up, a 1 x 2 tile across a bracket's
## upright, a pin through a Technic brick's middle hole. Returns them.
func _in_use(world: BrickWorld, builder: Builder, library: PartLibrary,
		brick_id: int) -> Array[int]:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	var sideways: Array[Lbm.Connector] = []
	var holes: Array[Lbm.Connector] = []
	for c: Lbm.Connector in mesh.connectors:
		if c.kind == "stud" and absf(c.axis.y) < 0.5:
			sideways.append(c)
		elif c.kind == "pin_hole":
			holes.append(c)
	var out: Array[int] = []
	var bracket: bool = library.parts[brick.part_id].name.begins_with("Bracket")
	if bracket and sideways.size() == 2:
		var a: Vector3 = brick.transform * sideways[0].position
		var b: Vector3 = brick.transform * sideways[1].position
		var way: Vector3 = (brick.transform.basis * sideways[0].axis).normalized()
		out.append(_put_at(world, builder, "3069b",
			Transform3D(Basis(Quaternion(Vector3.UP, way)), (a + b) * 0.5 + way * 8.0)))
	elif not bracket:
		for c: Lbm.Connector in sideways:
			var way: Vector3 = (brick.transform.basis * c.axis).normalized()
			out.append(_put_at(world, builder, "4073",
				Transform3D(Basis(Quaternion(Vector3.UP, way)),
					brick.transform * c.position + way * 8.0)))
	if not holes.is_empty():
		var middle: Lbm.Connector = holes[holes.size() / 2]
		var along: Vector3 = (brick.transform.basis * middle.axis).normalized()
		out.append(_put_at(world, builder, "3673",
			Transform3D(Basis(Quaternion(Vector3.RIGHT, along)),
				brick.transform * middle.position)))
	return out


func _put_at(world: BrickWorld, builder: Builder, part_id: String,
		where: Transform3D) -> int:
	var id: int = world.add_brick(part_id, USED, where)
	builder.register(id, part_id, where)
	return id


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
