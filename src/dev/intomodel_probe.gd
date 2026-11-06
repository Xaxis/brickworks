## A model into this one, in the real app, in a window (APP_UX4, intomodel).
##
##   godot --path . --resolution 1280x720 --script src/dev/intomodel_probe.gd
##
## A builder making a scene, a layout or a MOC from sub-models brings in a
## model they already made. LeoCAD lists the files beside the project in its
## parts bin and puts one in as a reference in 2 actions; here it was open,
## select all, copy, switch, paste, about 5, and the copy kept no steps. Now
## File, Import, Into this model… lists the saved models and the examples,
## with a file from this computer and the library; the one chosen is in hand
## whole, one sub-assembly with its author's steps, and a click puts it down.
##
## The bar, each line by its number, every act a menu row chosen or a click
## sent as an input event against the real scene:
##   1. a saved model (the gatehouse, tests/fixtures/steps/gatehouse.mpd: five
##      steps, a base of two of its own, a window of three put on twice) into
##      the car in 2 actions, its row chosen and a click beside the car: one
##      sub-assembly, every part at its place against the others to the LDU,
##      its author's steps kept as the sub-assembly's, each copy's too; the
##      car's steps as it was shown them, the gatehouse put on after them;
##   2. one Ctrl+Z takes it all out: the car's parts, places and steps as
##      they were;
##   3. over MCP, as the person's Claude calls it, open_model into=true in 1
##      call: the same, beside the car;
##   4. a Studio .io with Studio-only parts (whole_2025.io: a print only
##      BrickLink has, a Part Designer tile, two parts newer than the
##      library) comes in with them, every one drawn;
## and the library's Put in this model: LDraw's 106-1 from a stand-in store
## (tools/web/serve.py --library tests/fixtures/library, port 9801), in hand
## credited, put down as one sub-assembly named for the set; a gallery
## model whose maker kept every right greyed, saying why. Saved and opened
## again, the gatehouse and its steps are as they were put in.
##
## Pictures: shots/intomodel/<width>x<height>_*.png. Look at them.
extends SceneTree

const PORT := 9801
const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const WHOLE := "res://tests/fixtures/studio/whole_2025.io"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _bar: ModelBar
var _socket: Variant
var _rpc_id: int = 0
var _server: int = 0
var _size: String = ""
## Every status line and control word the probe saw, for the languages.
var _heard: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var fixture: String = ProjectSettings.globalize_path("res://tests/fixtures/library")
	_server = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/web/serve.py"),
		fixture, str(PORT), "--library", fixture, "--omr",
		ProjectSettings.globalize_path("res://vendor/omr/files")])
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:%d" % PORT)
	await create_timer(1.5).timeout
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
	_bar = _main.get("_bar")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	_store.keeps = false
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	print("in a window of %s" % _size)
	# The gatehouse, saved: one of the person's own models.
	var saved: String = ModelStore.saved_path("Gatehouse")
	DirAccess.make_dir_recursive_absolute(saved.get_base_dir())
	var file := FileAccess.open(saved, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(GATEHOUSE))
	file.close()
	CustomParts.dir = OS.get_user_data_dir().path_join("intomodel_probe_parts/")
	CustomParts.keeps = false

	await _by_hand()
	await _over_mcp()
	await _studio_parts()
	await _from_the_library()
	await _kept()
	_in_each_language()
	_done()


# -- 1 and 2: by hand ------------------------------------------------------------


func _by_hand() -> void:
	print("\n1. a saved model into the car in 2 actions")
	await _open_car()
	var before: Array = _snapshot()
	var shown: Dictionary = AuthorSteps.numbers_from_plan(_world, _library, _store.scenery)
	var units_before: Dictionary = _world.unit_steps.duplicate()
	var import_menu: PopupMenu = _shell.menu("File").get_popup().get_node("import")
	var row: int = import_menu.get_item_index(_shell.menu_id("import_into"))
	_check("File, Import's first row is \"%s\"" % (import_menu.get_item_text(row) if row >= 0 else ""),
		row == 0 and import_menu.get_item_text(row) == "Into this model…")
	import_menu.id_pressed.emit(_shell.menu_id("import_into"))
	await _frames(4)
	var into: PopupMenu = _bar.get("_into")
	var gatehouse: int = _row_of(into, "Gatehouse")
	_check("...which lists the saved Gatehouse (\"%s\"), the examples, a file and the library"
		% (into.get_item_text(gatehouse) if gatehouse >= 0 else ""), into != null and into.visible
		and gatehouse >= 0 and into.get_item_index(ModelBar.IMPORT) >= 0
		and into.get_item_index(ModelBar.LIBRARY) >= 0 and _row_of(into, "Car") >= 0)
	_check("...all of it in the window (%s in %s)" % [Rect2i(into.position, into.size), _size],
		Rect2i(Vector2i.ZERO, Vector2i(root.get_visible_rect().size)).encloses(
			Rect2i(into.position, into.size)))
	await _shot("menu")
	# Action 1: its row.
	into.id_pressed.emit(into.get_item_id(gatehouse))
	into.hide()
	await _until(func() -> bool: return _builder.is_carrying(), 20.0)
	_check("action 1, its row: all 14 of its parts in hand (%d)" % _builder.carrying.count(),
		_builder.is_carrying() and _builder.carrying.count() == 14)
	_check("...the status says so, its steps kept: \"%s\"" % _status(),
		_status().begins_with("holding Gatehouse, 14 parts — click where it goes")
		and _status().contains("its 5 steps kept"))
	var spot: Vector2 = await _beside_the_car()
	_check("...its ghost goes down beside the car", spot != Vector2.INF)
	await _shot("in_hand")
	# Action 2: the click.
	var start: int = _count()
	var known: int = _highest_id()
	await _click(spot)
	_check("action 2, a click: %d parts, 14 more, nothing in hand" % _count(),
		_count() == start + 14 and not _builder.is_carrying())
	await _shot("put_down")
	var brought: Array = _new_since(known)
	_whole_and_kept(brought, "Gatehouse", shown)

	print("\n2. one undo takes it all out")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z: the car's parts where they were (%d)" % _count(), _snapshot() == before)
	_check("...and says what it took out: \"%s\"" % _status(),
		_status() == "undid: put in Gatehouse, 14 parts")
	_check("...its steps as they were, none given (%s)" % _world.unit_steps,
		_world.unit_steps == units_before and not AuthorSteps.any(_world, _store.scenery))
	_check("...and the tree has no Gatehouse", not Array(_shell.assemblies.paths()).any(
		func(path: String) -> bool: return path.begins_with("Gatehouse")))


## [param brought], a model's parts just put in, checked against its file:
## one sub-assembly named [param named], every part where the file puts it
## against the others, and its author's steps; the car's steps as [param
## shown] says it was shown them, and the whole put on after its last.
func _whole_and_kept(brought: Array, named: String, shown: Dictionary) -> void:
	var roots: Dictionary = _roots(brought)
	var root: String = str(roots.keys()[0]) if roots.size() == 1 else ""
	_check("one sub-assembly, %s (%s)" % [root, ", ".join(PackedStringArray(roots.keys()))],
		roots.size() == 1 and Assemblies.definition(root) == named)
	var tree: Assemblies.Item = _shell.assemblies.tree()
	var node: Assemblies.Item = null
	for child: Assemblies.Item in tree.children:
		if child.path == root:
			node = child
	_check("...in the model's tree: %s, %d parts, inside it %s" % [root,
		node.total if node != null else 0, ", ".join(node.children.map(
			func(c: Assemblies.Item) -> String: return c.path)) if node != null else ""],
		node != null and node.total == brought.size() and node.children.size() == 3)
	# The file, read as the app reads one.
	var text: String = FileAccess.get_file_as_string(GATEHOUSE)
	var model: LdrModel = LdrModel.parse(text, "gatehouse.mpd")
	var placed: Array = model.flatten(_library.parts)
	ModelStore._as_placed(placed, _library, model.steps_are_authored())
	var same_parts: bool = placed.size() == brought.size()
	for n: int in mini(placed.size(), brought.size()):
		same_parts = same_parts and (placed[n] as LdrModel.Placement).part_id \
			== (brought[n] as BrickWorld.Brick).part_id
	_check("its %d parts, the file's %d, in its order" % [brought.size(), placed.size()], same_parts)
	if not same_parts:
		return
	var moved: Transform3D = (brought[0] as BrickWorld.Brick).transform \
		* (placed[0] as LdrModel.Placement).transform.affine_inverse()
	var off: float = 0.0
	var turned: float = 0.0
	for n: int in placed.size():
		var want: Transform3D = moved * (placed[n] as LdrModel.Placement).transform
		var have: Transform3D = (brought[n] as BrickWorld.Brick).transform
		off = maxf(off, want.origin.distance_to(have.origin))
		for axis: int in 3:
			turned = maxf(turned, (want.basis[axis] - have.basis[axis]).length())
	_check("every part at its place against the others to the LDU: %.4f LDU, turned %.5f off at most"
		% [off, turned], off < 0.01 and turned < 0.0001)
	var steps_kept: bool = true
	var paths: Dictionary = {}
	for n: int in placed.size():
		var placement: LdrModel.Placement = placed[n]
		var brick: BrickWorld.Brick = brought[n]
		steps_kept = steps_kept and brick.step == placement.step
		var inner: String = Assemblies.path_from(placement.group, placement.unit)
		var path: String = Assemblies.path_of(brick)
		if paths.has(inner) and paths[inner] != path:
			steps_kept = false
		paths[inner] = path
	_check("its author's steps kept, each part's in its own sub-model (%s)"
		% _steps_of(brought), steps_kept)
	var copies: PackedStringArray = PackedStringArray()
	var units_kept: bool = true
	for unit: String in model.unit_steps:
		var now: String = str(paths.get(unit, ""))
		copies.append("%s %d" % [now, int(_world.unit_steps.get(now, -9))])
		units_kept = units_kept and not now.is_empty() \
			and int(_world.unit_steps.get(now, -9)) == int(model.unit_steps[unit]) \
			and Assemblies.definition(Assemblies.leaf(now)) == Assemblies.definition(Assemblies.leaf(unit))
	_check("...and each copy's in the gatehouse, as its file has them: %s (file %s)"
		% [", ".join(copies), model.unit_steps], units_kept and model.unit_steps.size() == 3)
	_check("...the gatehouse's own 5 steps: %s" % str(AuthorSteps.steps_in(_world, root)),
		AuthorSteps.steps_in(_world, root) == [0, 1, 2, 3, 4])
	var car_kept: bool = true
	var last: int = -1
	var bricks: Dictionary = shown["bricks"]
	for brick_id: int in bricks:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		car_kept = car_kept and brick != null and brick.step == int(bricks[brick_id])
		last = maxi(last, int(bricks[brick_id]))
	_check("the car's %d parts in the steps it was shown them, 1 to %d" % [bricks.size(), last + 1],
		car_kept and not bricks.is_empty())
	_check("...and the gatehouse put on after them, in step %d"
		% (int(_world.unit_steps.get(root, -9)) + 1), int(_world.unit_steps.get(root, -9)) == last + 1)


# -- 3: over MCP ------------------------------------------------------------------


func _over_mcp() -> void:
	print("\n3. over MCP in 1 call")
	var before: Array = _snapshot()
	var shown: Dictionary = AuthorSteps.numbers_from_plan(_world, _library, _store.scenery)
	var known: int = _highest_id()
	var said: String = await _say("open_model", {"into": true, "name": "Gatehouse"})
	print("    " + said.replace("\n", "\n    "))
	var brought: Array = _new_since(known)
	_check("open_model into=true name=Gatehouse, 1 call: %d parts more" % brought.size(),
		brought.size() == 14 and said.begins_with("Put Gatehouse in the model as one sub-assembly"))
	_check("...beside the car, clear of it", _clear_of_car(brought))
	_check("...the answer says where and its steps: \"%s\"" % said.left(160),
		said.contains("low corner at x=") and said.contains("its 5 steps kept")
		and said.contains("undo takes it all out"))
	_whole_and_kept(brought, "Gatehouse", shown)
	await _shot("over_mcp")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z takes it out (%d)" % _count(), _snapshot() == before)
	var refused: String = await _say("open_model", {"into": true, "name": "No such model"})
	_check("a name it has not got is said: \"%s\"" % refused.left(90),
		refused.begins_with("No model called No such model."))


# -- 4: a Studio file with Studio's own parts ----------------------------------


func _studio_parts() -> void:
	print("\n4. an .io with Studio-only parts")
	var before: Array = _snapshot()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(WHOLE)
	var carried: PackedStringArray = StudioIo.read(bytes, _library).get("studio_parts",
		PackedStringArray())
	var import_menu: PopupMenu = _shell.menu("File").get_popup().get_node("import")
	import_menu.id_pressed.emit(_shell.menu_id("import_into"))
	await _frames(3)
	var into: PopupMenu = _bar.get("_into")
	into.id_pressed.emit(ModelBar.IMPORT)
	into.hide()
	await _frames(3)
	var picker: ModelFilePicker = _bar.get("_into_picker")
	_check("From a file on this computer… asks for one, .io among them",
		picker != null and picker._dialog != null and picker._dialog.visible
		and picker._dialog.filters[0].contains("*.io"))
	if picker == null:
		return
	if picker._dialog != null:
		picker._dialog.hide()
	# As the dialog hands over the file chosen (ModelFilePicker.ask).
	picker.take(bytes, "whole_2025.io")
	await _until(func() -> bool: return _builder.is_carrying(), 30.0)
	_check("whole_2025.io in hand, all 6 parts (%d): \"%s\"" % [_builder.carrying.count(), _status()],
		_builder.carrying.count() == 6 and not _status().contains("left out"))
	var spot: Vector2 = await _beside_the_car()
	var known: int = _highest_id()
	await _click(spot)
	var brought: Array = _new_since(known)
	var ids: Array = brought.map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	var drawn: bool = true
	for id: String in carried:
		drawn = drawn and ids.has(id) and _library.mesh_for(id) != null
	_check("a click puts all 6 down, the 4 only Studio has among them, each drawn: %s"
		% ", ".join(carried), brought.size() == 6 and carried.size() == 4 and drawn)
	_check("...as one sub-assembly, %s" % ", ".join(PackedStringArray(_roots(brought).keys())),
		_roots(brought).size() == 1)
	await _shot("studio_parts")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z takes them out", _snapshot() == before)


# -- the library's Put in this model ---------------------------------------------


func _from_the_library() -> void:
	print("\nthe library's Put in this model")
	var before: Array = _snapshot()
	var dialog: LibraryDialog = _shell.library_dialog
	dialog.open("sets")
	await _until(func() -> bool: return int(dialog.last.get("total", 0)) > 0, 30.0)
	await _search(dialog, "106-1")
	var put: Button = dialog.controls_by_name().get("library_put_first")
	_check("106-1's card has Put in this model beside Open: \"%s\"" % (put.text if put != null else ""),
		put != null and put.text == "Put in this model" and not put.disabled)
	await _frames(20)
	await _shot("library_card")
	if put == null:
		return
	var known: int = _highest_id()
	await _click(put.get_global_rect().get_center())
	await _until(func() -> bool: return _builder.is_carrying(), 60.0)
	_check("one click on it: the library closes and the set is in hand, %d parts" % (
		_builder.carrying.count() if _builder.is_carrying() else 0),
		not dialog.visible and _builder.is_carrying() and _builder.carrying.count() >= 57)
	_check("...credited: \"%s\"" % _status(), _status().contains("credit LDraw model by Michael Heidemann, CCAL 2.0"))
	var spot: Vector2 = await _beside_the_car()
	await _click(spot)
	var brought: Array = _new_since(known)
	_check("a click puts it down, %d parts, as one sub-assembly %s" % [brought.size(),
		", ".join(PackedStringArray(_roots(brought).keys()))],
		brought.size() >= 57 and _roots(brought).keys() == ["106-1 UNICEF Van#1"])
	await _shot("library_put")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z takes it out", _snapshot() == before)
	dialog.open("community")
	await _until(func() -> bool: return dialog.last.get("source") == "community", 30.0)
	await _search(dialog, "")
	await _until(func() -> bool: return _community_shown(dialog), 30.0)
	var greyed: PackedStringArray = PackedStringArray()
	var open: PackedStringArray = PackedStringArray()
	for card: Node in (dialog.get("_grid") as GridContainer).get_children():
		for button: Button in card.find_children("*", "Button", true, false):
			if button.text == "Put in this model":
				(greyed if button.disabled else open).append(button.tooltip_text.left(40))
	_check("the gallery's two built-on licences may go in, all rights reserved is greyed with why "
		+ "(%s)" % ", ".join(greyed), open.size() == 2 and greyed.size() == 1
		and greyed[0].begins_with("Its maker kept every right to it"))
	await _shot("library_community")
	dialog.close()
	await _frames(4)


func _community_shown(dialog: LibraryDialog) -> bool:
	return dialog.last.get("source") == "community" and int(dialog.last.get("total", 0)) == 3


# -- kept --------------------------------------------------------------------------


## Put in again, saved, and opened again: its parts and steps as they were.
func _kept() -> void:
	print("\nsaved and opened again")
	var said: String = await _say("open_model", {"into": true, "name": "Gatehouse"})
	_check("put in over MCP again", said.begins_with("Put Gatehouse in the model"))
	var steps: Array = _model().map(func(b: BrickWorld.Brick) -> String:
		return "%s %d %s %d" % [b.part_id, b.color_code, Assemblies.path_of(b), b.step])
	steps.sort()
	var units: Dictionary = _world.unit_steps.duplicate()
	_check("saved as Car and gatehouse", _store.save_as("Car and gatehouse"))
	var placed: int = await _bar.open_with_progress(ModelStore.saved_path("Car and gatehouse"))
	await _frames(10)
	var again: Array = _model().map(func(b: BrickWorld.Brick) -> String:
		return "%s %d %s %d" % [b.part_id, b.color_code, Assemblies.path_of(b), b.step])
	again.sort()
	_check("opened again: %d parts, each in its sub-assembly and step as put in" % placed,
		again == steps)
	_check("...each copy's step too (%s)" % _world.unit_steps, _world.unit_steps == units)


# -- the car -----------------------------------------------------------------------


func _open_car() -> void:
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await _bar.open_with_progress("res://models/car.ldr")
	_bar.opened.emit(placed)
	await _frames(10)
	_check("the car is open, %d parts, no steps of its own" % _count(),
		_count() == 61 and not AuthorSteps.any(_world, _store.scenery))
	_camera.frame(AABB(Vector3(-200, 0, -200), Vector3(560, 160, 400)))
	await _frames(20)


## The car's own box.
func _car_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _model():
		if not brick.unit.is_empty():
			continue
		var here: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return box


func _clear_of_car(bricks: Array) -> bool:
	var car: AABB = _car_box()
	for brick: BrickWorld.Brick in bricks:
		var here: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		if here.grow(-0.5).intersects(car):
			return false
	return true


## The pointer moved onto the ground beside the car until the ghost can go
## down there, as a person moves it. INF when nowhere does.
func _beside_the_car() -> Vector2:
	var car: AABB = _car_box()
	for dx: int in range(0, 200, 20):
		var at: Vector2 = _screen(Vector3(car.end.x + 120.0 + dx, 0.0, car.get_center().z))
		await _move(at)
		await _move(at + Vector2(1, 0))
		if _builder.can_place():
			return at + Vector2(1, 0)
	return Vector2.INF


# -- helpers -----------------------------------------------------------------------


## The outermost sub-assembly each of [param bricks] is in, "" for none.
func _roots(bricks: Array) -> Dictionary:
	var roots: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var path: String = Assemblies.path_of(brick)
		roots[Assemblies.segments(path)[0] if not path.is_empty() else ""] = true
	return roots


func _row_of(menu: PopupMenu, named: String) -> int:
	if menu == null:
		return -1
	for n: int in menu.item_count:
		if menu.get_item_text(n).begins_with(named + " — "):
			return n
	return -1


func _status() -> String:
	var said: String = str((_bar.get("_status") as Label).text) if _bar.get("_status") is Label else ""
	if not said.is_empty():
		_heard[said] = true
	return said


# -- in each language --------------------------------------------------------------


## Every word it showed said in German, French and Spanish: the menu's,
## the library's, and each status line, but for the models' and parts'
## names, its maker's and a key.
func _in_each_language() -> void:
	print("\nin each language")
	for word: String in ["Into this model…", "Put in this model",
			"Put in this model, then click where it goes",
			"From a file on this computer (LDraw, Studio .io, LDD .lxf)…",
			"From the library: real sets and the community's models…",
			"In your hand in this model as one sub-assembly with its steps, then a click where it goes; credit its maker",
			"Its maker kept every right to it: Open builds it, and it cannot go into another model without their leave"]:
		_heard[word] = true
	var names := RegEx.create_from_string(
		r"^(Gatehouse|Whole 2025|106-1 UNICEF Van|Car|Car and gatehouse|Michael Heidemann|CCAL 2\.0|[A-Z][a-z]?|Shift\+[A-Z]|Ctrl\+[A-Z])$")
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var lacking: Array[String] = []
		for english: String in _heard:
			if Language.says(english).is_empty():
				lacking.append(english.left(60))
				continue
			# A maker's credit is kept as it is: "Michael Heidemann, CCAL 2.0".
			for kept: Variant in Language.left_in_english(english):
				if not Array(str(kept).split(", ")).all(func(piece: String) -> bool:
						return names.search(piece.strip_edges()) != null):
					lacking.append("%s (in %s)" % [str(kept).left(50), english.left(40)])
		_check("%s: all %d of its words and lines said%s" % [code, _heard.size(),
			"" if lacking.is_empty() else "; not: " + " | ".join(lacking)], lacking.is_empty())
	Language.apply("en")


func _steps_of(bricks: Array) -> String:
	var said: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		var path: String = Assemblies.leaf(Assemblies.path_of(brick))
		said[path] = (said.get(path, []) as Array) + [brick.step]
	return str(said)


func _new_since(known: int) -> Array:
	var out: Array = _model().filter(func(b: BrickWorld.Brick) -> bool: return b.id > known)
	out.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	return out


func _highest_id() -> int:
	var most: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		most = maxi(most, brick.id)
	return most


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _snapshot() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		out.append("%s %d %s %s %d" % [brick.part_id, brick.color_code,
			LdrModel._line_numbers(brick.transform), Assemblies.path_of(brick), brick.step])
	out.sort()
	return out


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _search(dialog: LibraryDialog, words: String) -> void:
	var field: LineEdit = dialog.get("_search")
	field.text = words
	var asked: int = int(dialog.get("_asked"))
	field.text_changed.emit(words)
	await _until(func() -> bool: return int(dialog.last.get("asked", 0)) > asked, 20.0)
	await _frames(2)


func _until(test: Callable, seconds: float) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < seconds * 1000.0:
		if test.call():
			return true
		await process_frame
	return test.call()


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(6)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/intomodel/%s_%s.png" % [_size, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/intomodel/%s_%s.png" % [_size, name])


func _done() -> void:
	if _server > 0:
		OS.kill(_server)
	print("")
	if _failures == 0:
		print("intomodel: a model into this one in 2 actions, one sub-assembly with its steps, "
			+ "one undo; over MCP in 1 call; a Studio file's own parts; the library's, credited")
	else:
		print("intomodel: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
