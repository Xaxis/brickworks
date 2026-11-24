## A part of one's own from a 3D file, the way a person does it, in the
## real app: Make a part…, From a 3D file…, the goblet beside a 1 x 1 brick,
## a bar put on its stem with a click, Add to parts, in hand; then the
## figure builder's Headgear, Your own…, a real hair piece seated on the
## head, Wear it, placed, saved, the model opened again and the hair still
## on the head.
##
##   godot --path . --resolution 1280x800 --script src/dev/mesh_part_ui_probe.gd -- --pictures=DIR
##   PROBE_SIZE=390x844 tools/probe.sh mesh_part_ui_probe -- --pictures=DIR   laid out for a phone, by touch
##   ... --files=DIR   the ponytail too (DIR/hair-ponytail/w-fit-trainer-hair.stl, not kept here)
##
## Each hair is pictured seated on the head before the wig is worn: the
## mohawk, the ponytail if given, the wig.
##
## The file chooser is the app's own (SaveTo.native off, as every probe has
## it: the platform's would open on the desktop its bus belongs to): it is
## seen to open on Make a part's press, filtered to STL and OBJ, and then
## answered with a file, as choosing it does (MeshFilePicker.open_path).
##
## Made parts go to user://mesh_part_ui_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://mesh_part_ui_probe/"
const FIXTURES := "res://tests/fixtures/own_parts/"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _pictures: String = ""
var _files: String = ""
var _phone: bool = false
var _shots: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_pictures = arg.trim_prefix("--pictures=")
		elif arg.begins_with("--files="):
			_files = arg.trim_prefix("--files=")
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	SaveTo.native = false
	Minifig.shelf_file = "user://mesh_part_ui_probe_shelf.json"
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	_phone = mini(window.x, window.y) < int(Phone.NARROW)
	if _phone:
		Phone._on = 1
		Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	if _phone and _main.get("_phone") != null:
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _frames(20)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_main.call("clear_model")
	await _frames(10)
	print("%s, %dx%d" % ["laid out for a phone, by touch" if _phone else "at a desk", window.x,
		window.y])

	print("\na goblet from Make a part…")
	var elements: Control = _main.get("_elements")
	elements.call("open", "")
	await _frames(20)
	var from_file: Button = elements.get("_from_file")
	_check("Make a part offers \"%s\"" % (from_file.text if from_file != null else ""),
		from_file != null and from_file.is_visible_in_tree())
	await _shot("make_a_part")
	await _press(from_file)
	var own: Control = elements.get("_own")
	var picker: MeshFilePicker = own.call("picker") if own != null else null
	var chooser: FileDialog = picker.get("_dialog") if picker != null else null
	_check("it opens the panel and the file chooser, for STL and OBJ: %s" % (
		chooser.filters if chooser != null else []), own != null and own.visible
		and chooser != null and chooser.visible and str(chooser.filters).contains("*.stl"))
	if own == null:
		_finish()
		return
	if chooser != null:
		chooser.hide()
	picker.open_path(ProjectSettings.globalize_path(FIXTURES + "lego-goblet.stl"))
	await _read_by(own)
	var part: MeshPart = own.get("part")
	_check("the goblet is in, upright, beside a 1 x 1 brick: %s" % (part.size_words()
		if part != null else own.get("_status").text), part != null
		and (own.get("_beside") as MeshInstance3D).visible)
	if part == null:
		_finish()
		return
	await _frames(30)
	await _shot("goblet")
	# A bar on its stem: Bar, then a click on the stem.
	await _press((own.get("_tools") as Dictionary)["bar"])
	var stem: Dictionary = part.pick(Vector3(100, -30, 0), Vector3.LEFT)
	own.call("turn_to", PI * 0.5, 0.15)
	await _frames(10)
	var view: Control = own.call("view")
	await _tap(view.get_global_rect().position + own.call("on_view", stem["at"]))
	var made: Dictionary = part.placed()
	var bar: Array = (made["connectors"] as Array)[0] if not (made["connectors"] as Array).is_empty() \
		else []
	_check("a click on the stem put a bar along it: %s" % [bar], not bar.is_empty()
		and bar[0] == "shaft" and absf(float(bar[6])) > 0.99)
	own.call("turn_to", 0.7, 0.4)
	await _frames(20)
	await _shot("goblet_bar")
	await _type_into(own.get("_name"), "Goblet")
	await _press(own.get("_add"))
	# Made on a worker: its file written and built while the window draws.
	await _read_by(own)
	var held: String = _builder.held_part
	_check("Add to parts: %s is in the hand and in the bin under Custom" % held,
		held.begins_with("bw-goblet-s") and _library.parts.has(held)
		and _library.parts[held].category == "Custom" and not own.visible)
	await _shot("goblet_in_hand")
	await _key(KEY_ESCAPE)
	await _unit_asked(elements, own)

	print("\nhair from the figure builder's Your own…")
	_main.call("_open_figures")
	await _frames(30)
	var figures: MinifigDialog = _main.get("_figures")
	await _press(figures._slot_buttons["headwear"])
	var yours: Button = figures.get("_own")
	_check("Headgear offers \"%s\"" % (yours.text if yours != null else ""),
		yours != null and yours.is_visible_in_tree())
	await _shot("your_own")
	await _press(yours)
	var hair_panel: Control = figures.get("_own_editor")
	var hair_picker: MeshFilePicker = hair_panel.call("picker") if hair_panel != null else null
	var hair_chooser: FileDialog = hair_picker.get("_dialog") if hair_picker != null else null
	_check("it opens the panel and the chooser, as hair", hair_panel != null and hair_panel.visible
		and hair_chooser != null and hair_chooser.visible and bool(hair_panel.get("for_hair")))
	if hair_panel == null:
		_finish()
		return
	if hair_chooser != null:
		hair_chooser.hide()
	var others: Array = [["mohawk", ProjectSettings.globalize_path(FIXTURES + "mohawk.stl")]]
	if not _files.is_empty():
		others.append(["ponytail", _files.path_join("hair-ponytail/w-fit-trainer-hair.stl")])
	for other: Array in others:
		hair_picker.open_path(other[1])
		await _read_by(hair_panel)
		var piece: MeshPart = hair_panel.get("part")
		_check("the %s is in and seated on the head: %s; %s" % [other[0],
			piece.size_words() if piece != null else "", hair_panel.get("_status").text],
			piece != null and piece.hair and piece.head_inside <= 0.05
			and piece.file == str(other[1]).get_file())
		await _hair_shots(hair_panel, other[0])
	hair_picker.open_path(ProjectSettings.globalize_path(FIXTURES + "wig_67.stl"))
	await _read_by(hair_panel)
	var hair: MeshPart = hair_panel.get("part")
	_check("the wig is in, simplified and seated on the head: %s; %s" % [
		hair.size_words() if hair != null else "", hair_panel.get("_status").text],
		hair != null and hair.hair and hair.head_inside <= 0.08)
	if hair == null:
		_finish()
		return
	await _hair_shots(hair_panel, "wig")
	await _press(hair_panel.get("_add"))
	await _read_by(hair_panel)
	var worn: String = figures.figure.part("headwear")
	_check("Wear it: the figure wears %s" % worn, worn.begins_with("bw-") and not hair_panel.visible
		and PartPrints.bases.get(worn, "") == "3901")
	await _shot("figure")

	print("\nin the model, saved and opened again")
	await _press(_find_button(figures, "Place in model"))
	var centre: Vector2 = root.get_visible_rect().size * 0.5
	await _tap(centre)
	await _frames(10)
	var standing: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.part_id == worn or brick.part_id.begins_with("3626"))
	# Where 3901 stands: at the head's own origin.
	var seat: Variant = _seat(standing, worn)
	_check("placed: the hair where 3901 stands on the head (%d of the figure's parts found)"
		% standing.size(), standing.size() == 2 and seat is Transform3D
		and (seat as Transform3D).is_equal_approx(Transform3D.IDENTITY))
	await _key(KEY_ESCAPE)
	await _look_at_figure(standing)
	await _shot("placed")
	var path: String = ProjectSettings.globalize_path(PROBE_DIR + "figure.mpd")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var saved: bool = _main.call("save_model", path)
	var text: String = FileAccess.get_file_as_string(path)
	_check("saved, carrying the hair as 0 FILE %s.dat" % worn, saved
		and text.contains("0 FILE %s.dat" % worn))
	if not _pictures.is_empty():
		DirAccess.make_dir_recursive_absolute(_pictures)
		DirAccess.copy_absolute(path, _pictures.path_join("figure%s.mpd" % ("_phone" if _phone else "")))
	_main.call("clear_model")
	await _frames(10)
	_main.call("_open", path)
	for _n: int in 60:
		await process_frame
	var again: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.part_id == worn or brick.part_id.begins_with("3626"))
	var seat_again: Variant = _seat(again, worn)
	_check("opened again, the hair is still seated on the head", again.size() == 2
		and seat_again is Transform3D and seat is Transform3D
		and (seat_again as Transform3D).is_equal_approx(seat))
	# Opened and saved with no edit: the same bytes (self_attack, saving).
	var path_again: String = ProjectSettings.globalize_path(PROBE_DIR + "figure_again.mpd")
	_main.call("save_model", path_again)
	var text_again: String = FileAccess.get_file_as_string(path_again)
	_check("saved again with no edit, the same %d bytes" % text_again.length(),
		not text_again.is_empty() and text_again == text)
	await _look_at_figure(again)
	await _shot("reopened")
	_finish()


## The hair on the head from the front (the face) and from the side.
## A file 1.5 across, which says nothing of its units (moulds2): asked, never
## read as metres unsaid; answered Metres it is refused in words before Add
## to parts can be pressed, answered Centimetres it is made.
func _unit_asked(elements: Control, own: Control) -> void:
	print("\na file 1.5 across, its units asked")
	var path: String = ProjectSettings.globalize_path(PROBE_DIR.path_join("small.stl"))
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(_small_stl(1.5))
	file.close()
	elements.call("open", "")
	await _frames(20)
	await _press(elements.get("_from_file"))
	var picker: MeshFilePicker = own.call("picker")
	var chooser: FileDialog = picker.get("_dialog")
	if chooser != null:
		chooser.hide()
	picker.open_path(path)
	await _read_by(own)
	var asks: Dictionary = own.get("_asks")
	var ask: Control = own.get("_ask")
	var add: Button = own.get("_add")
	var status: Label = own.get("_status")
	_check("it is asked what the file is measured in, and Add to parts waits: \"%s\"" % status.text,
		ask.is_visible_in_tree() and add.disabled and status.text.contains("What is it measured in?")
		and asks.size() == 4)
	await _shot("unit_asked")
	await _press(asks["m"])
	await _frames(10)
	var part: MeshPart = own.get("part")
	_check("Metres: 1.5 m is refused in words before any of it is made: \"%s\"" % status.text,
		not ask.is_visible_in_tree() and add.disabled and status.text.contains("at most 400 mm")
		and _builder.held_part.is_empty())
	await _shot("unit_metres_refused")
	# Answered; the same file read again is asked about again.
	picker.open_path(path)
	await _read_by(own)
	await _press(asks["cm"])
	await _frames(10)
	part = own.get("part")
	_check("Centimetres: %s, and it may be made" % part.size_words(),
		absf(part.longest("mm") - 15.0) < 0.5 and not add.disabled)
	await _press(add)
	await _read_by(own)
	_check("Add to parts: %s in the hand" % _builder.held_part,
		_builder.held_part.begins_with("bw-") and not own.visible)
	await _key(KEY_ESCAPE)


## A closed cube [param side] across in the file's own numbers, binary STL.
static func _small_stl(side: float) -> PackedByteArray:
	var h: float = side / 2.0
	var c: Array[Vector3] = []
	for n: int in 8:
		c.append(Vector3(h if n & 1 else -h, h if n & 2 else -h, h if n & 4 else -h))
	var quads: Array = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2],
		[1, 3, 7, 5]]
	var out := PackedByteArray()
	out.resize(84 + 50 * 12)
	out.encode_u32(80, 12)
	var t: int = 0
	for q: Array in quads:
		for three: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			for k: int in 3:
				var p: Vector3 = c[three[k]]
				var at: int = 84 + 50 * t + 12 + 12 * k
				out.encode_float(at, p.x)
				out.encode_float(at + 4, p.y)
				out.encode_float(at + 8, p.z)
			t += 1
	return out


func _hair_shots(panel: Control, what: String) -> void:
	panel.call("turn_to", 0.0, 0.25)
	await _frames(30)
	await _shot("hair_%s_front" % what)
	panel.call("turn_to", PI / 2.0, 0.25)
	await _frames(20)
	await _shot("hair_%s_side" % what)
	panel.call("turn_to", 0.7, 0.4)
	await _frames(5)


## The hair's place relative to the head's; null when either is missing.
func _seat(bricks: Array, hair: String) -> Variant:
	var head: BrickWorld.Brick = null
	var worn: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in bricks:
		if brick.part_id == hair:
			worn = brick
		else:
			head = brick
	if head == null or worn == null:
		return null
	return head.transform.affine_inverse() * worn.transform


func _look_at_figure(bricks: Array) -> void:
	if bricks.is_empty():
		return
	var at: Vector3 = (bricks[0] as BrickWorld.Brick).transform.origin
	_camera.frame(AABB(at - Vector3(30, 40, 30), Vector3(60, 60, 60)), 1.0)
	await _frames(60)


func _read_by(panel: Control) -> void:
	var since: int = Time.get_ticks_msec()
	await _frames(3)
	while bool(panel.call("reading")) and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(10)
	print("    read in %d ms" % (Time.get_ticks_msec() - since))


func _finish() -> void:
	if FileAccess.file_exists(Minifig.shelf_file):
		DirAccess.remove_absolute(Minifig.shelf_file)
	_forget(PROBE_DIR)
	print("")
	if _failures == 0:
		print("mesh part ui probe: a goblet and a hair piece were brought in from files, given a "
			+ "bar and a seat, kept, worn, placed, saved and opened again")
	else:
		print("mesh part ui probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


# -- driving it ----------------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## A finger's tap on a phone's layout, the mouse's click on a desktop's.
func _tap(at: Vector2) -> void:
	if _phone:
		for down: bool in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.pressed = down
			touch.position = _as_event(at)
			Input.parse_input_event(touch)
			await _frames(2)
		await _frames(6)
		return
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _frames(4)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(6)


func _press(control: Control) -> void:
	if control == null:
		_check("there is a control to press", false)
		return
	var up: Node = control.get_parent()
	while up != null and not (up is ScrollContainer):
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).ensure_control_visible(control)
		await _frames(3)
	await _tap(control.get_global_rect().get_center())


func _key(code: Key, text: String = "") -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		if not text.is_empty():
			event.unicode = text.unicode_at(0)
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type_into(line: LineEdit, text: String) -> void:
	await _press(line)
	line.grab_focus()
	line.select_all()
	await _key(KEY_BACKSPACE)
	for character: String in text:
		var code: Key = OS.find_keycode_from_string(character.to_upper())
		if character == " ":
			code = KEY_SPACE
		await _key(code, character)
	await _frames(4)
	line.release_focus()


func _find_button(under: Node, text: String) -> Button:
	for child: Node in under.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return child
	return null


func _shot(name: String) -> void:
	_shots += 1
	await RenderingServer.frame_post_draw
	if _pictures.is_empty():
		return
	var image: Image = root.get_texture().get_image()
	var path: String = _pictures.path_join("%s%02d_%s.png" % ["phone_" if _phone else "desk_",
		_shots, name])
	DirAccess.make_dir_recursive_absolute(_pictures)
	image.save_png(path)
	print("    picture: %s" % path)


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	DirAccess.remove_absolute(dir)
