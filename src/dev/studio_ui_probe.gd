## Printed parts and stickers for any part of a model, used the way a
## person uses them.
##
##   godot --path . --resolution 1400x900 --script src/dev/studio_ui_probe.gd
##
## Opens the real app and builds a little scene: a 2 x 2 tile, a 2 x 4
## slope and two 1 x 4 tiles side by side on the baseplate. Then, with the
## mouse: holds a 2 x 2 tile, presses the bin's "Print…", brings in a
## photograph (the file a dialog would hand over), makes it fill the tile
## and moves it, saves it and clicks it down on the baseplate; holds the
## slope, prints the Brickworks logo (an SVG) on its slope face with its
## background cleared and LEGO's inks; presses "Stickers…", "New
## sticker…", clicks one of the two tiles, starts a street sign from a
## starter, writes on it, saves it — stuck across both tiles; opens the
## sheet; saves the model and opens it again. Pictures go to
## shots/studio_*.png: look at them.
##
## Made parts go to user://studio_ui_probe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _studio: PrintStudio
var _editor: PrintEditor

const PROBE_DIR := "user://studio_ui_probe_parts/"
const PHOTO := "/usr/share/backgrounds/Monument_valley_by_orbitelambda.jpg"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
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
	_studio = _main.get("_studio")
	_editor = _studio.editor
	_main.call("clear_model")
	await _frames(10)
	for item: Array in [["3068b", 15, Vector3(-70, 8, 10)], ["3037", 72, Vector3(0, 24, 10)],
			["2431", 4, Vector3(80, 8, 0)], ["2431", 4, Vector3(80, 8, 20)]]:
		_builder.put_part(item[0], item[1], Transform3D(Basis.IDENTITY, item[2]))
	_builder.forget_history()
	var scene := AABB(Vector3(-110, 0, -40), Vector3(240, 40, 100))
	_camera.frame(scene, 1.0)
	_camera.set_view("default")
	await _frames(30)

	print("  a photograph on a 2 x 2 tile")
	_main.call("_on_part_chosen", "3068b")
	await _frames(4)
	var bin: PartsBin = _main.get("_bin")
	await _click_control(bin.controls_by_name()["print part"])
	await _frames(10)
	_check("the bin's Print… opens the designer on the 2 x 2 tile: %s" % _keys(),
		_editor.visible and _editor.base == "3068b" and _keys().begins_with("top"))
	var photo: String = PHOTO if FileAccess.file_exists(PHOTO) else ""
	if photo.is_empty():
		var made := Image.create_empty(320, 240, false, Image.FORMAT_RGBA8)
		made.fill(Color(0.3, 0.5, 0.9))
		photo = ProjectSettings.globalize_path("res://shots/studio_photo.png")
		made.save_png(photo)
	_editor._files.read(photo)
	await _frames(10)
	var paper: PrintPaint = _editor.paper("top")
	_check("a photograph brought in on a layer of its own, Move in hand (%s)" % photo.get_file(),
		paper.layer().picture != null and _editor.canvas().tool == "move")
	await _click_control(_editor.controls_by_name()["print_fill"])
	var centre: Vector2 = paper.layer().picture.centre
	var on_canvas: Vector2 = _editor.canvas().get_global_rect().position \
		+ _editor.canvas().to_screen(centre)
	await _drag([on_canvas, on_canvas + Vector2(-30, 0), on_canvas + Vector2(-60, 4)])
	_check("dragged with the mouse, it moved (%s to %s)" % [centre, paper.layer().picture.centre],
		paper.layer().picture.centre.x < centre.x - 10.0)
	await _frames(20)
	await _shot("studio_photo_editor")
	await _type_into(_editor._name, "Monument Valley")
	await _click_control(_editor._save)
	await _frames(10)
	var photo_tile: String = _builder.held_part
	_check("saved as a part of its own, under My prints, and in hand: %s" % photo_tile,
		photo_tile.begins_with("bw-3068b-p") and _library.parts[photo_tile].category == PartPrints.MY_PRINTS)
	var cells: Dictionary = bin.get("_cells")
	var cell_name: String = ""
	if cells.has(photo_tile):
		for child: Node in (cells[photo_tile] as Control).get_parent().get_children():
			if child is Label:
				cell_name = (child as Label).text
	_check("the bin shows it by its name: \"%s\"" % cell_name, cell_name == "Monument Valley")
	# And by its picture: its top is a surface of its own, which a plain
	# picture left out, a red frame round a hole.
	var thumb: ThumbTile = cells.get(photo_tile)
	for _n: int in 240:
		if thumb == null or thumb.state != ThumbTile.State.LOADING:
			break
		await process_frame
	# Against the same tile drawn as the bin drew it before: only its
	# moulded surface, the hole where the print is.
	var unprinted: ImageTexture = null
	for _n: int in 240:
		unprinted = bin.thumbnails.request(photo_tile, thumb.color_code, false) if thumb != null else null
		if unprinted != null:
			break
		await process_frame
	var changed: int = 0
	if thumb != null and thumb.texture != null and unprinted != null:
		var drawn: Image = thumb.texture.get_image()
		var hole: Image = unprinted.get_image()
		for y: int in mini(drawn.get_height(), hole.get_height()):
			for x: int in mini(drawn.get_width(), hole.get_width()):
				var a: Color = drawn.get_pixel(x, y)
				var b: Color = hole.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.3:
					changed += 1
	_check("and by its picture: %d pixels where the photograph is, not a hole" % changed,
		thumb != null and thumb.printed and changed > 400)
	var spot: Vector2 = _camera.unproject_position(Vector3(-70, 0, 60))
	var before: int = _world.brick_count()
	await _click_at(spot)
	_check("clicked down on the baseplate like any part", _world.brick_count() == before + 1)
	await _key(KEY_ESCAPE)

	print("  a logo on a 2 x 4 slope")
	_main.call("_on_part_chosen", "3037")
	await _frames(4)
	await _click_control(bin.controls_by_name()["print part"])
	await _frames(10)
	var tabs: TabBar = _editor._tabs
	for n: int in tabs.tab_count:
		if tabs.get_tab_title(n) == "Slope":
			await _click_at(tabs.get_global_rect().position + tabs.get_tab_rect(n).get_center())
	_check("its Slope tab: %s" % _editor.areas()[_editor._area].key,
		_editor.areas()[_editor._area].key == "slope")
	_editor._files.read(ProjectSettings.globalize_path("res://web/icon.svg"))
	await _frames(6)
	await _click_control(_editor.controls_by_name()["print_clear_back"])
	await _click_control(_editor.controls_by_name()["print_lego"])
	await _click_control(_editor.controls_by_name()["print_fit"])
	var logo: PrintPicture = _editor.paper("slope").layer().picture
	_check("the logo fitted, its background clear, in LEGO inks: %d" % logo.inks_used(),
		logo.clear_back and logo.lego and logo.inks_used() <= 16)
	await _frames(20)
	await _shot("studio_slope_editor")
	await _type_into(_editor._name, "Brickworks Logo")
	await _click_control(_editor._save)
	await _frames(10)
	var logo_slope: String = _builder.held_part
	_check("saved: %s" % logo_slope, logo_slope.begins_with("bw-3037-p"))
	# The plain slope in the scene swapped for the printed one, as a person
	# would: take it off, put the printed one where it was.
	for item: Variant in _world.bricks():
		var brick: BrickWorld.Brick = item
		if brick.part_id == "3037":
			var at: Transform3D = brick.transform
			_builder.take_off(brick.id)
			_builder.put_part(logo_slope, 72, at)
	await _key(KEY_ESCAPE)

	print("  a dial printed on a tile where it stands")
	# The hand always holds a part in the app, and the part under the
	# pointer is found by aiming it; Shift-click picks that part out.
	_main.call("_on_part_chosen", "3068b")
	await _frames(4)
	var plain_at: Vector2 = _camera.unproject_position(Vector3(-70, 8, 10))
	await _shift_click(plain_at)
	var picked: Array = _builder.selection.keys().map(func(id: int) -> String:
		return _world.get_brick(id).part_id)
	_check("Shift-click picks out the plain tile in the model: %s" % [picked],
		picked == ["3068b"])
	await _click_control(bin.controls_by_name()["print part"])
	await _frames(10)
	_check("Print… opens on the part picked out: %s" % _editor.base,
		_editor.visible and _editor.base == "3068b")
	_editor.start_from("starter:dial")
	await _frames(4)
	await _click_control(_editor._save)
	await _frames(10)
	var there: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.transform.origin.is_equal_approx(Vector3(-70, 8, 10)))
	_check("the dial tile stands where the plain one stood, in its colour: %s" % (
		(there[0] as BrickWorld.Brick).part_id if there.size() == 1 else str(there.size())),
		there.size() == 1 and (there[0] as BrickWorld.Brick).part_id.begins_with("bw-3068b-p")
		and (there[0] as BrickWorld.Brick).color_code == 15)
	var dial_name: String = PartPrints.given_name(_library.parts[(there[0] as BrickWorld.Brick).part_id].name) \
		if there.size() == 1 else ""
	_check("named for its starter: \"%s\"" % dial_name, dial_name == "Dial")
	# The plain tile went out of the selection as it went out of the model;
	# its yellow outline once stayed round the print that took its place.
	var outline: SelectionOutline = _main.get("_outline")
	_check("and nothing is left picked out, nor outlined: %d picked, outline %s" % [
		_builder.selection.size(), "shown" if outline.visible else "gone"],
		_builder.selection.is_empty() and not outline.visible)
	await _key(KEY_ESCAPE)

	print("  a sticker across two 1 x 4 tiles")
	await _click_control(bin.controls_by_name()["stickers"])
	await _frames(6)
	_check("Stickers… opens the sheet", _studio.sheet.visible)
	await _click_control(_studio.sheet.controls_by_name()["sheet_new"])
	await _frames(4)
	var tile_top: Vector2 = _camera.unproject_position(Vector3(80, 8, 0))
	var seen: Stickers.Face = Stickers.face_at(_world, _library, _camera.project_ray_origin(tile_top),
		_camera.project_ray_normal(tile_top), true, _camera.global_transform.basis.y)
	_check("seen from the corner, the face under the pointer is both tiles, square to them: %s"
		% (seen.size if seen != null else Vector2.ZERO), seen != null
		and (seen.size.is_equal_approx(Vector2(80, 40)) or seen.size.is_equal_approx(Vector2(40, 80))))
	await _click_at(tile_top)
	await _frames(10)
	_check("a click on one tile opens a sticker as big as both: %s" % _editor._title.text,
		_editor.visible and _editor.sticker_face != null and _editor.sticker_face.bricks.size() == 2)
	# A street sign: the film white, a blue border, words.
	var sticker_paper: PrintPaint = _editor.paper("sticker")
	var canvas_box: Rect2 = _editor.canvas().get_global_rect()
	var at := func(x: float, y: float) -> Vector2:
		return canvas_box.position + _editor.canvas().to_screen(
			Vector2(sticker_paper.width * x, sticker_paper.height * y))
	await _click_control(_editor._tools["fill"])
	await _click_control(_editor.controls_by_name()["print_ink_1"])
	await _click_at(at.call(0.5, 0.5))
	await _click_control(_editor._tools["box"])
	await _click_control(_editor.controls_by_name()["print_ink_15"])
	await _drag([at.call(0.05, 0.1), at.call(0.5, 0.5), at.call(0.95, 0.9)])
	await _click_control(_editor._tools["text"])
	await _click_control(_editor.controls_by_name()["print_ink_0"])
	_editor.canvas().words = "BRICK ST"
	_editor.canvas().word_size = 84
	await _click_at(at.call(0.15, 0.66))
	await _frames(20)
	await _shot("studio_sticker_editor")
	await _type_into(_editor._name, "Brick Street")
	await _click_control(_editor._save)
	await _frames(10)
	var stickers: Dictionary = Stickers.in_model(_world, _library)
	var sticker_id: String = stickers.keys()[0] if not stickers.is_empty() else ""
	_check("saved and stuck on: %s" % sticker_id, sticker_id.begins_with("bw-st-"))
	if not sticker_id.is_empty():
		var on: PackedInt64Array = Stickers.stuck_to(_world, _library,
			(stickers[sticker_id] as PackedInt64Array)[0])
		_check("on both tiles: %d" % on.size(), on.size() == 2)
	await _key(KEY_ESCAPE)
	_clear_hand()
	_camera.frame(scene, 1.0)
	_camera.set_view("default")
	await _frames(90)
	await _shot("studio_model")
	_camera.frame(AABB(Vector3(30, 0, -20), Vector3(100, 20, 60)), 1.0)
	_camera.set_view("top")
	await _frames(90)
	await _shot("studio_sticker_top")

	print("  the sheet")
	await _click_control(bin.controls_by_name()["stickers"])
	await _frames(10)
	await _shot("studio_sheet")
	var pdf: PackedByteArray = _studio.sheet.sheet_bytes("pdf")
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path("res://shots/studio_stickers.pdf"),
		FileAccess.WRITE)
	file.store_buffer(pdf)
	file.close()
	_check("the sheet's PDF: %d bytes" % pdf.size(), pdf.size() > 1000)
	await _click_control(_studio.sheet.controls_by_name()["sheet_close"])

	print("  saved and opened again")
	var saved: String = "user://studio_ui_probe.mpd"
	_check("saved", bool(_main.call("save_model", saved)))
	var text: String = FileAccess.get_file_as_string(saved)
	_check("the file carries %d pictures as !DATA and %d made parts" % [text.count("0 !DATA "),
		text.count("0 FILE bw-")], text.count("0 !DATA ") == 4 and text.count("0 FILE bw-") == 4)
	_main.call("clear_model")
	await _frames(10)
	# Opened as a person opens a file: Open…, "From a file on this
	# computer…", the file chosen in the dialog that comes up. The menu's
	# first line once opened the first model listed under it instead.
	# Open… is the toolbar's now, with the bar's choices behind it: found
	# where the page finds it, in the shell's controls, then the bar's.
	var bar: Node = _main.get("_bar")
	var shell: Node = _main.get("_shell")
	var named: Dictionary = shell.controls_by_name() if shell != null else {}
	named.merge(bar.controls_by_name())
	await _click_control(named["open"])
	await _frames(10)
	var menu: PopupMenu = bar.get("_saves")
	await _click_at(Vector2(menu.position) + Vector2(60, 14))
	await _frames(10)
	var picker: Node = bar.get("_picker")
	var dialog: FileDialog = picker.get("_dialog") if picker != null else null
	_check("Open… > From a file on this computer… brings up a file dialog: %s" % (
		"up" if dialog != null and dialog.visible else "none"), dialog != null and dialog.visible)
	if dialog != null:
		dialog.hide()
		dialog.file_selected.emit(ProjectSettings.globalize_path(saved))
	await _frames(30)
	var placed: int = _world.brick_count()
	_clear_hand()
	_camera.frame(scene, 1.0)
	_camera.set_view("default")
	await _frames(90)
	await _shot("studio_reopened")
	var printed: int = 0
	for item: Variant in _world.bricks():
		if (item as BrickWorld.Brick).part_id.begins_with("bw-"):
			printed += 1
	_check("opened again: %d bricks, %d of them prints and stickers" % [placed, printed],
		printed == 4)
	DirAccess.remove_absolute(saved)
	_forget(PROBE_DIR)
	print("")
	if _failures == 0:
		print("studio ui probe: a photo, a logo and a sticker were put on a model by hand, saved and opened")
	else:
		print("studio ui probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


## Nothing in hand and the pointer off the model, so no ghost of the last
## part hangs over the pictures.
func _clear_hand() -> void:
	_builder.held_part = ""
	_builder.hide_preview()
	_move(Vector2(root.get_visible_rect().size.x - 60, 120))


func _keys() -> String:
	return ",".join(_editor.areas().map(func(a: PartPrints.Area) -> String: return a.key))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = mask
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)


func _drag(points: Array) -> void:
	_move(points[0])
	await _frames(2)
	_button(points[0], true)
	await _frames(2)
	for n: int in range(1, points.size()):
		_move(points[n], MOUSE_BUTTON_MASK_LEFT)
		await _frames(2)
	_button(points[points.size() - 1], false)
	await _frames(3)


func _shift_click(at: Vector2) -> void:
	_move(at)
	await _frames(6)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.shift_pressed = true
		event.position = _as_event(at)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(6)


func _click_at(at: Vector2) -> void:
	_move(at)
	await _frames(6)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(6)


func _click_control(control: Control) -> void:
	if control == null:
		_check("there is a control to click", false)
		return
	var scroll: Node = control.get_parent()
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).ensure_control_visible(control)
		await _frames(3)
	await _click_at(control.get_global_rect().get_center())


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
	await _click_control(line)
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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	DirAccess.remove_absolute(dir)
