## Building by hand, the way a person does it with Studio or Mecabricks.
##
##   godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd
##
## Every step is a key or a click sent as an input event, against the real
## scene, aimed at where a brick is drawn on screen. Pictures of each step
## go to shots/handbuild/ for a person to look at.
##
## Copy, paste, duplicate, cut; picking a selection up to move it and
## putting it back with Escape; turning a selection where it stands; and
## what each of them leaves for undo. None of these existed: a window was
## built again brick by brick, and a wall could only be nudged.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore


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
	_main.call("clear_model")
	# A clipboard from nobody: a probe must not paste whatever the person
	# at this machine last copied. What was on the system clipboard is put
	# back at the end, since copying here writes to it.
	Carry.clipboard = []
	var theirs: String = DisplayServer.clipboard_get() \
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) else ""

	# A small bay to copy: a 2 x 4 brick, a 1 x 2 on it, a 2 x 2 plate on
	# that. On the stud grid, where a hand would put them.
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3004", 1, Vector3(-60, 48, 10))
	_put("3022", 14, Vector3(-60, 56, 20))
	await _frames(4)
	_camera.frame(AABB(Vector3(-260, 0, -200), Vector3(520, 80, 400)))
	await _frames(40)
	var start: int = _count()
	_check("three parts to start with", start == 3)

	await _copy_and_paste()
	await _duplicate_and_turn()
	await _turn_in_place()
	await _move_and_put_back()
	await _cut_and_clipboard()
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(theirs)
	await _ghost_in_its_colour()
	await _select_by()
	await _hide_and_isolate()
	await _the_edit_bar()
	await _seat_an_old_model()
	await _replace_and_history()
	await _the_parts_shelf()
	await _exports()
	await _under_a_part()
	await _onto_side_studs()
	await _mirrored()
	await _studio_file()
	await _swing_on_a_hinge()
	await _a_submodel()
	await _a_small_laptop()

	print("")
	if _failures == 0:
		print("by hand: every verb here works as a person uses it, from the keys "
			+ "and the buttons")
	else:
		print("by hand: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the checks -------------------------------------------------------------


func _copy_and_paste() -> void:
	print("  copy and paste")
	await _key(KEY_A, true)
	_check("Ctrl-A selects the three", _builder.selection.size() == 3)
	await _key(KEY_C, true)
	_check("Ctrl-C copies them (%d on the clipboard)" % Carry.clipboard.size(),
		Carry.clipboard.size() == 3)
	_check("...and does not paint them", _colours() == {4: 1, 1: 1, 14: 1})
	await _key(KEY_ESCAPE)
	var spot: Vector2 = _screen(Vector3(110, 0, 30))
	await _move(spot)
	await _key(KEY_V, true)
	_check("Ctrl-V puts a copy in hand", _builder.is_carrying()
		and _builder.carrying.count() == 3)
	await _move(spot + Vector2(2, 0))
	_check("its ghost is aimed and can go down there", _builder.can_place())
	await _shot("paste_ghost")
	await _click(spot + Vector2(2, 0))
	_check("a click puts all three down (%d parts)" % _count(), _count() == 6)
	_check("...and lets go of them", not _builder.is_carrying())
	_check("...and selects what it put down", _builder.selection.size() == 3)
	_check("the copy is the same shape, moved by whole studs", _same_shape())
	_check("every part of it is on the studs", _all_on_studs())
	await _shot("pasted")
	await _key(KEY_Z, true)
	_check("one undo takes the whole paste back (%d)" % _count(), _count() == 3)
	await _key(KEY_Z, true, true)
	_check("one redo puts it back (%d)" % _count(), _count() == 6)

	# Onto bricks already there: refused, red, and a click does nothing.
	await _key(KEY_V, true)
	var taken: Vector2 = _screen(Vector3(-60, 0, 20))
	await _move(taken)
	await _move(taken + Vector2(1, 1))
	var landed: Vector3 = _builder.carrying._frame.origin
	_check("aimed at the bay, the copy goes on it or beside it, never into it (%s)"
		% landed, _builder.can_place() and (landed.y >= 56.0
		or Vector2(landed.x + 70.0, landed.z - 30.0).length() >= 20.0))
	await _key(KEY_ESCAPE)
	_check("Escape puts the copy away", not _builder.is_carrying()
		and _count() == 6)


func _duplicate_and_turn() -> void:
	print("  duplicate and turn")
	_select_only(_bricks_near(Vector3(-60, 0, 20)))
	await _frames(2)
	await _key(KEY_D, true)
	_check("Ctrl-D holds a copy of the selection", _builder.is_carrying()
		and _builder.carrying.count() == 3)
	_check("...and leaves the clipboard alone", Carry.clipboard.size() == 3)
	await _key(KEY_R)
	_check("R turns what is held a quarter", _builder.carrying.turns == 1)
	var spot: Vector2 = _screen(Vector3(-70, 0, -130))
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _shot("duplicate_turned")
	await _click(spot + Vector2(1, 0))
	_check("a click puts the turned copy down (%d)" % _count(), _count() == 9)
	var long_way: Vector3 = _long_axis_of_new("3001")
	_check("its 2 x 4 now runs the other way (%s)" % long_way,
		absf(long_way.z) > 0.9)
	_check("and every part is still on the studs", _all_on_studs())


func _turn_in_place() -> void:
	print("  turning a selection where it stands")
	var one: Array = _bricks_near(Vector3(110, 0, 30))
	_select_only(one)
	await _frames(2)
	var before: Dictionary = _places(one)
	await _key(KEY_R)
	var after: Dictionary = _places(one)
	var turned: bool = true
	for brick_id: int in one:
		turned = turned and not (before[brick_id] as Transform3D).basis.is_equal_approx(
			(after[brick_id] as Transform3D).basis)
	_check("R turns the selected bay where it stands", turned)
	_check("still on the studs", _all_on_studs())
	_check("still three selected", _builder.selection.size() == 3)
	await _shot("turned_in_place")
	await _key(KEY_Z, true)
	var back: Dictionary = _places(one)
	var same: bool = true
	for brick_id: int in one:
		same = same and (before[brick_id] as Transform3D).is_equal_approx(back[brick_id])
	_check("one undo turns it back", same)
	await _key(KEY_R)
	await _key(KEY_R)
	await _key(KEY_R)
	await _key(KEY_R)
	var round: Dictionary = _places(one)
	var home: bool = true
	for brick_id: int in one:
		home = home and (before[brick_id] as Transform3D).is_equal_approx(round[brick_id])
	_check("four turns bring it back exactly where it was", home)


func _move_and_put_back() -> void:
	print("  moving a selection")
	var bay: Array = _bricks_near(Vector3(-60, 0, 20))
	_select_only(bay)
	await _frames(2)
	var before: Array = _snapshot()
	await _key(KEY_X)
	_check("X picks the selection up (%d left standing)" % _count(),
		_builder.is_carrying() and _builder.carrying.lifted and _count() == 6)
	var spot: Vector2 = _screen(Vector3(210, 0, -130))
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _shot("moving")
	await _key(KEY_ESCAPE)
	_check("Escape puts it back where it was", not _builder.is_carrying()
		and _snapshot() == before)
	_check("...still selected", _builder.selection.size() == 3)
	await _key(KEY_X)
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _click(spot + Vector2(1, 0))
	_check("a click puts it down somewhere else (%d)" % _count(),
		_count() == 9 and _snapshot() != before)
	await _key(KEY_Z, true)
	_check("one undo moves it back", _snapshot() == before)


func _cut_and_clipboard() -> void:
	print("  cut, and the clipboard as LDraw")
	var bay: Array = _bricks_near(Vector3(-70, 0, -130))
	_select_only(bay)
	await _frames(2)
	await _key(KEY_X, true)
	_check("Ctrl-X takes the selection off (%d)" % _count(), _count() == 6)
	_check("...onto the clipboard", Carry.clipboard.size() == 3)
	var text: String = Carry.as_ldraw(Carry.clipboard)
	var read: Array = Carry.from_ldraw(text, _library)
	var same: bool = read.size() == Carry.clipboard.size()
	for n: int in mini(read.size(), Carry.clipboard.size()):
		same = same and str(read[n]["part"]) == str(Carry.clipboard[n]["part"]) \
			and (read[n]["at"] as Transform3D).is_equal_approx(Carry.clipboard[n]["at"])
	_check("as LDraw lines it reads back as the same parts in the same places", same)
	# What another program put on the clipboard is pasted in its place.
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set("0 from LDCad\n1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\n")
		await _key(KEY_V, true)
		_check("LDraw from another program pastes (%s)" % (
			_builder.carrying.items[0]["part"] if _builder.is_carrying() else "nothing"),
			_builder.is_carrying() and _builder.carrying.count() == 1
			and str(_builder.carrying.items[0]["part"]) == "3003")
		await _key(KEY_ESCAPE)


func _ghost_in_its_colour() -> void:
	print("  the ghost in its own colour")
	_builder.clear_selection()
	_builder.held_part = "3001"
	_builder.held_face = "up"
	_builder.held_rotation = 0
	var spot: Vector2 = _screen(Vector3(-170, 0, -110))
	var tints: Dictionary = {}
	for colour: int in [15, 4, 2]:
		_builder.held_color = colour
		await _move(spot)
		await _move(spot + Vector2(1, 0))
		await _frames(3)
		var centre: Vector2 = _screen(_builder._ghost_transform.origin + Vector3(0, -12, 0))
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var pixel: Color = image.get_pixelv(Vector2i(_as_event(centre)))
		tints[colour] = pixel
		if colour == 15:
			await _shot("ghost_white")
	var white: Color = tints[15]
	var red: Color = tints[4]
	_check("a white brick's ghost reads white, not green (%s)" % white.to_html(false),
		white.g / maxf(white.r, 0.01) < 1.35 and white.r > 0.4)
	_check("a red brick's ghost reads red (%s)" % red.to_html(false),
		red.r > red.g * 1.4)
	_builder.held_color = 4


func _select_by() -> void:
	print("  selecting by colour, part, connection")
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))   # red 2 x 4
	_put("3004", 1, Vector3(-60, 48, 10))   # blue 1 x 2 on it
	_put("3001", 4, Vector3(20, 24, 20))    # red 2 x 4 beside it, touching
	_put("3005", 4, Vector3(30, 48, 10))    # red 1 x 1 on that
	await _frames(4)
	var first: int = _bricks_near(Vector3(-60, 0, 20)).filter(
		func(b: int) -> bool: return _world.get_brick(b).part_id == "3001")[0]
	var verbs: EditVerbs = _main.get("_verbs")
	_select_only([first])
	_check("same colour takes the three reds", verbs.select_by("colour") == 3)
	_select_only([first])
	_check("same part takes both 2 x 4s", verbs.select_by("part") == 2)
	_select_only([first])
	_check("same part and colour takes both red 2 x 4s", verbs.select_by("alike") == 2)
	_select_only([first])
	var joined: int = verbs.select_by("connected")
	var blue_in: bool = _builder.selection.keys().any(
		func(b: int) -> bool: return _world.get_brick(b).part_id == "3004")
	_check("connected takes the brick on top and not the one beside it (%d)" % joined,
		joined == 2 and blue_in)
	_check("the opposite takes the other two", verbs.select_by("inverse") == 2)
	# From the edit bar's menu, the way a person reaches it.
	var bar: EditBar = _main.get("_edit_bar")
	_select_only([first])
	var menu_button: MenuButton = bar._select_menu
	await _click(menu_button.get_global_rect().get_center())
	_check("the Select button opens its menu", menu_button.get_popup().visible)
	var popup: PopupMenu = menu_button.get_popup()
	_check("...beside the bar, all of it inside the window (%d + %d of %d)" % [
		popup.position.y, popup.size.y, DisplayServer.window_get_size().y],
		popup.position.y + popup.size.y <= DisplayServer.window_get_size().y + 1
		and popup.position.x >= int(menu_button.get_screen_position().x
			+ menu_button.size.x * menu_button.get_global_transform_with_canvas().get_scale().x))
	await _shot("select_menu")
	menu_button.get_popup().id_pressed.emit(0)
	menu_button.get_popup().hide()
	await _frames(3)
	_check("...whose Same colour takes the three reds", _builder.selection.size() == 3)


func _hide_and_isolate() -> void:
	print("  hiding and showing only")
	var pair: Array = _bricks_near(Vector3(-60, 0, 20))
	_select_only(pair)
	await _frames(2)
	await _key(KEY_H)
	var hidden: bool = pair.all(func(b: int) -> bool: return _world.get_brick(b).hidden)
	_check("H hides the selection", hidden and _builder.selection.is_empty())
	_check("...without taking it off the model (%d parts)" % _count(), _count() == 4)
	# The ground under the hidden pair: the pointer reaches it through them.
	var where: Vector2 = _screen(Vector3(-60, 0, 20))
	await _move(where)
	await _move(where + Vector2(1, 0))
	_check("the pointer passes through what is hidden",
		not pair.has(_builder.hovered_brick()))
	_check("...and a part aimed there still stands on it, not in it (y %.0f)"
		% _builder._ghost_transform.origin.y, _builder._ghost_transform.origin.y >= 48.0)
	await _key(KEY_A, true)
	_check("Ctrl-A takes only what can be seen (%d)" % _builder.selection.size(),
		_builder.selection.size() == 2)
	await _key(KEY_ESCAPE)
	await _key(KEY_H)
	_check("H with nothing selected shows everything again",
		_model().all(func(b: BrickWorld.Brick) -> bool: return not b.hidden))
	var other: Array = _bricks_near(Vector3(20, 0, 20))
	_select_only(other)
	await _frames(2)
	await _key(KEY_H, false, true)
	var shown: Array = _model().filter(func(b: BrickWorld.Brick) -> bool: return not b.hidden)
	_check("Shift-H shows only the selection (%d shown)" % shown.size(), shown.size() == 2)
	await _shot("isolated")
	await _key_alt(KEY_H)
	_check("Alt-H shows everything", _model().all(
		func(b: BrickWorld.Brick) -> bool: return not b.hidden))


func _the_edit_bar() -> void:
	print("  the edit bar")
	var bar: EditBar = _main.get("_edit_bar")
	_check("the edit bar is on screen", bar != null and bar.is_visible_in_tree())
	if bar == null:
		return
	var buttons: Dictionary = bar._buttons
	var said: bool = true
	for name: String in buttons:
		said = said and not (buttons[name] as Button).tooltip_text.strip_edges().is_empty()
	_check("every button says what it does (%d)" % buttons.size(), said and buttons.size() >= 14)
	_builder.clear_selection()
	await _frames(3)
	_check("with nothing selected, Copy is faint and does nothing",
		(buttons["copy"] as Button).disabled)
	var pair: Array = _bricks_near(Vector3(-60, 0, 20))
	_select_only(pair)
	await _frames(3)
	_check("with a selection it is not", not (buttons["copy"] as Button).disabled)
	Carry.clipboard = []
	await _click((buttons["copy"] as Button).get_global_rect().get_center())
	_check("clicking Copy copies the selection (%d)" % Carry.clipboard.size(),
		Carry.clipboard.size() == 2)
	await _click((buttons["paste"] as Button).get_global_rect().get_center())
	_check("clicking Paste puts a copy in hand", _builder.is_carrying())
	await _key(KEY_ESCAPE)
	_select_only(pair)
	await _frames(3)
	var before: Dictionary = _places(pair)
	await _click((buttons["rotate"] as Button).get_global_rect().get_center())
	var after: Dictionary = _places(pair)
	_check("clicking Rotate turns the selection",
		not (before[pair[0]] as Transform3D).basis.is_equal_approx(
			(after[pair[0]] as Transform3D).basis))
	_check("...and puts nothing on the model behind the button (%d)" % _count(),
		_count() == 4)
	await _click((buttons["hide"] as Button).get_global_rect().get_center())
	_check("clicking Hide hides it", _world.get_brick(pair[0]).hidden)
	await _frames(3)
	await _click((buttons["show_all"] as Button).get_global_rect().get_center())
	_check("clicking Show everything brings it back", not _world.get_brick(pair[0]).hidden)
	_select_only(pair)
	await _move((buttons["move"] as Button).get_global_rect().get_center())
	await _frames(30)
	await _shot("edit_bar")


func _seat_an_old_model() -> void:
	print("  seating an old model's parts")
	var assistant: Assistant = _main.get("_assistant")
	var offer: SeatOffer = _main.get("_seat_offer")
	# Parts drawn inside their footprint, put where the old corner put
	# them: a good placement, moved by exactly the old error.
	var lines := PackedStringArray(["0 Old model", "0 Name: old.ldr"])
	var off: int = 0
	var x: float = -100.0
	for part: String in ["30503", "2417", "3680", "2335", "6064", "4495"]:
		var mesh: Lbm.PartMesh = _library.mesh_for(part)
		if mesh == null:
			continue
		var error: Vector3 = _old_error(mesh, part, assistant)
		if error == Vector3.ZERO:
			continue
		var good: Variant = _seated_near(mesh, Vector3(x, 8, 60))
		if good == null:
			continue
		var old: Transform3D = (good as Transform3D).translated(-error)
		lines.append("1 7 %s %s.dat" % [LdrModel._line_numbers(old), part])
		off += 1
		x += 120.0
	lines.append("1 4 %s 3001.dat" % LdrModel._line_numbers(
		Transform3D(Basis.IDENTITY, Vector3(-100, 24, -60))))
	_check("an old model with parts off their studs (%d of them)" % off, off >= 2)
	var store: ModelStore = _store
	var result: Dictionary = store.open_text("\n".join(lines), "old")
	var bar: ModelBar = _main.get("_bar")
	bar.opened.emit(int(result["placed"]))
	await _frames(10)
	_check("opening it offers to seat them", offer.visible)
	_check("...saying how many (%s)" % offer._words.text,
		offer._words.text.begins_with("%d parts" % off))
	_camera.frame(_main.call("_built_bounds"))
	await _frames(30)
	await _shot("seat_offer")
	var before: Array = _snapshot()
	await _click(offer._seat.get_global_rect().get_center())
	_check("one click seats them and the offer goes", not offer.visible
		and _snapshot() != before)
	var seated: bool = true
	for brick: BrickWorld.Brick in _model():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		seated = seated and Seating.off_the_studs(mesh, brick.transform) <= 0.5
	_check("every part now stands on stud middles", seated)
	await _key(KEY_Z, true)
	_check("one undo puts them back as they were saved", _snapshot() == before)
	# A model that needs nothing is offered nothing.
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	_check("a model on its studs is offered nothing", offer.check() == 0
		and not offer.visible)


func _replace_and_history() -> void:
	print("  replacing parts, and the history")
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3001", 4, Vector3(60, 24, 20))
	await _frames(3)
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.select_by("all")
	await _frames(2)
	_builder.held_color = 1
	await _key(KEY_C)
	_builder.held_part = "3002"
	var bar: EditBar = _main.get("_edit_bar")
	await _click((bar._buttons["replace"] as Button).get_global_rect().get_center())
	var parts: Array = _model().map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	_check("Replace swaps both 2 x 4s for the 2 x 3 in hand (%s)" % str(parts),
		parts == ["3002", "3002"])
	_check("...each keeping its colour", _colours() == {1: 2})
	_check("...on its studs", _all_on_studs())
	var words: PackedStringArray = _builder.history_words()
	_check("the history says what was done, newest first (%s)" % str(words),
		words.size() >= 2 and words[0].begins_with("swapped 2 parts for Brick 2 x 3")
		and words[1] == "painted 2 parts")
	var menu: MenuButton = bar._history_menu
	await _click(menu.get_global_rect().get_center())
	_check("the History button lists them (%d)" % menu.get_popup().item_count,
		menu.get_popup().visible and menu.get_popup().item_count >= 2)
	await _shot("history")
	menu.get_popup().id_pressed.emit(1)
	menu.get_popup().hide()
	await _frames(3)
	parts = _model().map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	_check("choosing the second goes back to before both (%s, %s)" % [str(parts), str(_colours())],
		parts == ["3001", "3001"] and _colours() == {4: 2})
	await _key(KEY_Z, true, true)
	await _key(KEY_Z, true, true)
	_check("and redo comes forward through both", _colours() == {1: 2})


func _the_parts_shelf() -> void:
	print("  recent and favourite parts, and finding a part by number")
	PartShelf.file = "user://handbuild_probe_shelf.cfg"
	PartShelf.keeps = true
	PartShelf.clear()
	var bin: PartsBin = _main.get("_bin")
	bin.show_category("All")
	await _frames(4)
	var cell: Button = bin._grid.get_child(2)
	var chosen: String = str(cell.get_meta("part"))
	await _click(cell.get_global_rect().get_center())
	_check("choosing a part puts it in Recent (%s)" % str(PartShelf.recent()),
		PartShelf.recent().size() >= 1 and PartShelf.recent()[0] == chosen)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = _as_event(cell.get_global_rect().get_center())
	right.global_position = right.position
	Input.parse_input_event(right)
	await _frames(2)
	right = right.duplicate()
	right.pressed = false
	Input.parse_input_event(right)
	await _frames(3)
	_check("right-clicking it keeps it in Favourites", PartShelf.is_favourite(chosen))
	_check("...and marks it with a star", (cell.get_meta("star") as Control).visible)
	_check("...and puts nothing on the model behind the bin (%d)" % _count(), _count() == 2)
	bin.show_category("Favourites")
	await _frames(4)
	_check("Favourites shows it", bin._grid.get_child_count() == 1
		and str(bin._grid.get_child(0).get_meta("part")) == chosen)
	await _shot("favourites")
	bin.show_category("Recent")
	await _frames(4)
	_check("Recent shows it", bin._grid.get_child_count() >= 1
		and str(bin._grid.get_child(0).get_meta("part")) == chosen)
	bin.show_category("All")
	bin._search.text = "3023"
	bin._run_search("3023")
	await _frames(4)
	var first: Array = []
	for n: int in mini(6, bin._results.size()):
		first.append(bin._results[n].id)
	var family: bool = first.all(func(id: String) -> bool:
		return id.begins_with("3023") and not id.substr(4, 1).is_valid_int())
	_check("searching 3023 lists the 3023 family first, not 30236 or the spider (%s)"
		% str(first), first.size() >= 3 and first[0] == "3023b" and family)
	bin._search.text = ""
	bin._run_search("")
	PartShelf.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PartShelf.file))
	PartShelf.keeps = false


func _under_a_part() -> void:
	print("  placing under a part")
	_main.call("clear_model")
	_put("3001", 4, Vector3(0, 24, 20))
	_put("3034", 1, Vector3(0, 32, 20))
	await _frames(3)
	_builder.held_part = "3024"
	_builder.held_face = "up"
	_builder.held_rotation = 0
	# Up at the overhang's underside, from below it.
	_builder.update_preview(Vector3(70, 4, 30), Vector3.UP)
	var at: Vector3 = _builder._ghost_transform.origin
	_check("aimed at an overhang's underside, the part hangs under it (top at %.0f)" % at.y,
		is_equal_approx(at.y, 24.0) and _builder.can_place())
	var made: int = _builder.place()
	_check("...and goes there", made != 0 and is_equal_approx(
		_world.get_brick(made).transform.origin.y, 24.0))
	# The baseplate's underside is not somewhere to hang a part.
	_builder.update_preview(Vector3(200, -60, 200), Vector3.UP)
	_check("under the baseplate it does not hang below the ground (y %.0f)"
		% _builder._ghost_transform.origin.y, _builder._ghost_transform.origin.y >= 0.0)


func _onto_side_studs() -> void:
	print("  a plate on side studs")
	_main.call("clear_model")
	_put("87087", 15, Vector3(10, 24, 10))
	await _frames(3)
	var brick: BrickWorld.Brick = _model()[0]
	var mesh: Lbm.PartMesh = _library.mesh_for("87087")
	var stud: Variant = null
	var out := Vector3.ZERO
	for connector: Lbm.Connector in mesh.connectors:
		var axis: Vector3 = (brick.transform.basis * connector.axis).normalized()
		if connector.kind == "stud" and absf(axis.y) < 0.1:
			stud = brick.transform * connector.position
			out = axis
	_check("the brick with a stud on its side has one (%s, facing %s)" % [str(stud), out],
		stud != null)
	if stud == null:
		return
	_builder.held_part = "3023"
	_builder.held_rotation = 0
	for face: String in BrickLattice.FACES:
		if (BrickLattice.basis_for(face, 0) * Vector3.UP).dot(out) > 0.99:
			_builder.held_face = face
	var aim: Vector3 = (stud as Vector3) + out * 60.0 + Vector3(0, 3, 0)
	_builder.update_preview(aim, -out)
	var placed: Transform3D = _builder._ghost_transform
	var plate: Lbm.PartMesh = _library.mesh_for("3023")
	var on_stud: bool = false
	for socket: Vector2 in plate.sockets:
		var under: Vector3 = placed * Vector3(socket.x, plate.bounds.position.y, socket.y)
		var off: Vector3 = under - (stud as Vector3)
		off -= out * off.dot(out)
		if off.length() < 0.5:
			on_stud = true
	_check("a plate laid on its side, aimed at the side stud, has a socket on it", on_stud)
	_check("...and fits there", _builder.can_place())
	_check("...flat against the face", absf((placed * Vector3(0, plate.bounds.position.y, 0)
		- (stud as Vector3)).dot(out)) < 4.5)
	var made: int = _builder.place()
	_check("...and goes there", made != 0)
	_camera.frame(AABB(Vector3(-40, 0, -40), Vector3(100, 60, 100)))
	await _frames(30)
	await _shot("side_stud")


func _mirrored() -> void:
	print("  mirroring a selection")
	_main.call("clear_model")
	# An L of three bricks, and a right-hand wedge plate on one end.
	_put("3001", 4, Vector3(-40, 24, 20))
	_put("3004", 1, Vector3(20, 24, 10))
	# 41769 is a moved number now; the world keeps what it means.
	var wedge: String = _library.resolve("41769")
	var other: String = Mirror.counterpart(_library, wedge)
	_check("the right-hand wedge plate (%s)'s other hand is found by name (%s)" % [wedge, other],
		other == _library.resolve("41770"))
	_put(wedge, 14, Vector3(-40, 32, 20))
	await _frames(3)
	_camera.set_view("front")
	await _frames(20)
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.select_by("all")
	var before: Array = _snapshot()
	var xs_before: Array = _model().map(func(b: BrickWorld.Brick) -> float:
		return b.transform.origin.x)
	await _key(KEY_M, false, true)
	var after: Array = _model()
	var parts: Array = after.map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	_check("Shift-M mirrors the selection, swapping the wedge for its other hand (%s)" % str(parts),
		after.size() == 3 and parts.has(other) and not parts.has(wedge))
	var xs_after: Array = after.map(func(b: BrickWorld.Brick) -> float: return b.transform.origin.x)
	xs_before.sort()
	xs_after.sort()
	_check("left and right have swapped (%s -> %s)" % [str(xs_before), str(xs_after)],
		not is_equal_approx(float(xs_before[0]), float(xs_after[0])))
	_check("every part still on the studs", _all_on_studs())
	await _shot("mirrored")
	await _key(KEY_Z, true)
	_check("one undo brings back the original", _snapshot() == before)
	_camera.set_view("default")


func _swing_on_a_hinge() -> void:
	print("  swinging a part on its hinge")
	_main.call("clear_model")
	# A hinge brick's base and its top, closed: in LDraw the top sits at
	# the base's own place (10176's are, opened 57 degrees about the pin
	# 10 LDU under the base's top). A 1 x 2 plate on the top, to swing too.
	_put("3004", 4, Vector3(0, 24, 10))
	_put("3937", 7, Vector3(0, 48, 10))
	_put("3938", 7, Vector3(0, 48, 10))
	await _frames(3)
	var top: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3938").map(func(b: BrickWorld.Brick) -> int: return b.id)
	_select_only(top)
	await _frames(2)
	var before: Array = _snapshot()
	var was: Transform3D = _world.get_brick(top[0]).transform
	await _key(KEY_J)
	var now: Transform3D = _world.get_brick(top[0]).transform
	var angle: float = rad_to_deg(was.basis.get_rotation_quaternion().angle_to(
		now.basis.get_rotation_quaternion()))
	_check("J swings the hinge's top 15 degrees about its pin (%.1f)" % angle,
		absf(angle - 15.0) < 0.5)
	await _key(KEY_J)
	await _key(KEY_J)
	now = _world.get_brick(top[0]).transform
	angle = rad_to_deg(was.basis.get_rotation_quaternion().angle_to(
		now.basis.get_rotation_quaternion()))
	_check("...and again, to 45 (%.1f)" % angle, absf(angle - 45.0) < 0.5)
	_camera.frame(AABB(Vector3(-40, 0, -30), Vector3(80, 80, 80)))
	await _frames(30)
	await _shot("hinge_45")
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	_check("three undos close it again", _snapshot() == before)
	# A plain brick on studs has no joint to swing on.
	_select_only(_model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3004").map(func(b: BrickWorld.Brick) -> int: return b.id))
	await _frames(2)
	var plain: Array = _snapshot()
	await _key(KEY_J)
	_check("a brick on studs alone does not swing", _snapshot() == plain)


func _a_submodel() -> void:
	print("  making a sub-model by hand")
	_main.call("clear_model")
	_put("3001", 4, Vector3(-40, 24, 20))
	_put("3001", 4, Vector3(-40, 48, 20))
	_put("3001", 1, Vector3(60, 24, 20))
	await _frames(3)
	var tower: Array = _bricks_near(Vector3(-40, 0, 20))
	_select_only(tower)
	await _frames(2)
	await _key(KEY_G, true)
	var verbs: EditVerbs = _main.get("_verbs")
	var dialog: ConfirmationDialog = verbs._naming
	_check("Ctrl-G asks what the sub-model is called (%s)" % (
		verbs._name_field.text if dialog != null else "no dialog"),
		dialog != null and dialog.visible and verbs._name_field.text == "Sub-model")
	if dialog == null:
		return
	verbs._name_field.text = "Tower"
	await _shot("submodel_name")
	await _click(dialog.get_ok_button().get_global_rect().get_center()
		+ Vector2(dialog.position))
	if dialog.visible:
		# Clicking a window's button through the embedded subwindow is
		# what a person does; if the window would not take the click,
		# say so and press it the way its keyboard does.
		print("    (the dialog did not take the click; confirming it)")
		dialog.get_ok_button().pressed.emit()
	await _frames(3)
	var groups: Array = _model().map(func(b: BrickWorld.Brick) -> String: return b.group)
	groups.sort()
	_check("the two become the sub-model Tower (%s)" % str(groups),
		groups == ["", "Tower", "Tower"])
	var text: String = _store.to_text("Probe")
	_check("...which saves as a sub-model of its own", text.contains("0 FILE tower.ldr"))
	_select_only([tower[0]])
	verbs.select_by("submodel")
	_check("Same sub-model takes the whole tower from one brick",
		_builder.selection.size() == 2)
	await _key(KEY_Z, true)
	groups = _model().map(func(b: BrickWorld.Brick) -> String: return b.group)
	_check("one undo takes it back out", groups.all(func(g: String) -> bool: return g.is_empty()))


func _studio_file() -> void:
	print("  opening a BrickLink Studio .io file")
	var bar: ModelBar = _main.get("_bar")
	# A zip with Studio's password around an LDraw model, made by the
	# system's own zip (tests/fixtures/studio_bay.io), not by this app.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/studio_bay.io")
	_check("the Studio file is there to open (%d bytes)" % bytes.size(), bytes.size() > 100)
	var read: Dictionary = StudioIo.read(bytes)
	_check("its password-protected zip opens to LDraw (%s)" % str(read["error"]),
		str(read["error"]).is_empty() and str(read["text"]).contains("3001.dat"))
	bar._import()
	await _frames(3)
	var picker: ModelFilePicker = bar._picker
	if picker._dialog != null:
		picker._dialog.hide()
	picker.take(bytes, "studio_bay.io")
	await _frames(10)
	var parts: Array = _model().map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	parts.sort()
	_check("Open → From a file takes a Studio .io and opens its model (%s)" % str(parts),
		parts == ["3001", "3004", "3022"])
	_check("...in its colours", _colours() == {4: 1, 1: 1, 14: 1})
	_check("...under its own name (%s)" % bar.model_name(), bar.model_name() == "Bay from Studio")


func _exports() -> void:
	print("  Export: a picture, and parts lists for BrickLink and Rebrickable")
	var exports: Exports = _main.get("_exports")
	var into: String = ProjectSettings.globalize_path("res://shots/handbuild/exports")
	DirAccess.make_dir_recursive_absolute(into)
	exports.folder = into
	var bar: ModelBar = _main.get("_bar")
	bar._name.text = "Probe Bay"
	await _click((bar._export as Button).get_global_rect().get_center())
	var menu: PopupMenu = bar._exports
	_check("Export opens a menu of what it can write (%d)" % menu.item_count,
		menu.visible and menu.item_count >= 5)
	await _shot("export_menu")
	menu.hide()
	for name: String in ["probe_bay.png", "probe_bay_bricklink.xml", "probe_bay_rebrickable.csv"]:
		DirAccess.remove_absolute(into.path_join(name))
	menu.id_pressed.emit(1)
	var png: String = into.path_join("probe_bay.png")
	for _n: int in 300:
		if FileAccess.file_exists(png):
			break
		await process_frame
	var picture: Image = Image.load_from_file(png) if FileAccess.file_exists(png) else null
	_check("Picture writes a %s png" % (str(picture.get_size()) if picture != null else "missing"),
		picture != null and picture.get_size() == Picture.SIZE)
	if picture != null:
		var corner: Color = picture.get_pixel(2, 2)
		var opaque: int = 0
		for x: int in range(0, picture.get_width(), 40):
			for y: int in range(0, picture.get_height(), 40):
				if picture.get_pixel(x, y).a > 0.9:
					opaque += 1
		_check("...on a clear background, the model filling it (corner alpha %.2f, %d of %d samples solid)"
			% [corner.a, opaque, (picture.get_width() / 40) * (picture.get_height() / 40)],
			corner.a < 0.05 and opaque > 40)
	_check("...and the baseplate is back after it", _store.scenery.keys().all(
		func(b: int) -> bool: return _world.get_brick(b) != null and not _world.get_brick(b).hidden))
	menu.id_pressed.emit(2)
	await _frames(3)
	var xml: String = FileAccess.get_file_as_string(into.path_join("probe_bay_bricklink.xml"))
	_check("the BrickLink wanted list names 3002 in BrickLink's blue, 2 of them",
		xml.contains("<ITEMID>3002</ITEMID>") and xml.contains("<COLOR>7</COLOR>")
		and xml.contains("<MINQTY>2</MINQTY>") and xml.begins_with("<INVENTORY>"))
	menu.id_pressed.emit(3)
	await _frames(3)
	var csv: String = FileAccess.get_file_as_string(into.path_join("probe_bay_rebrickable.csv"))
	_check("the Rebrickable list is Part,Color,Quantity (%s)" % csv.strip_edges().replace("\n", " / "),
		csv.begins_with("Part,Color,Quantity\n3002,1,2"))
	exports.folder = ""


func _a_small_laptop() -> void:
	print("  a small laptop's window, and a phone's")
	var main_script: GDScript = _main.get_script()
	# The scale the app chooses is a function of the window alone, so it is
	# asked about the sizes that matter whatever window this probe has.
	for size: Vector2 in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1440, 900)]:
		var stretched: float = minf(size.x / 1600.0, size.y / 900.0)
		var drawn: float = stretched * main_script.screen_factor(size.x, size.y, false)
		_check("at %d x %d the interface is drawn at %.2f, not %.2f" % [size.x, size.y,
			drawn, stretched], drawn >= 0.9 - 0.001)
		_check("...so a part's number is %.1f pixels high" % (drawn * 11.0), drawn * 11.0 >= 9.9)
	var was: Vector2i = DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(30)
	if DisplayServer.window_get_size() != Vector2i(1280, 720):
		print("    (this display will not resize the window, so the rest is at %s)"
			% str(DisplayServer.window_get_size()))
	var scale: float = root.get_final_transform().get_scale().y
	_check("this window is drawn at %.2f" % scale, scale >= 0.9 - 0.001)
	var bar: EditBar = _main.get("_edit_bar")
	var spacer: Control = bar.get_parent()
	_check("the edit bar fits the room beside the model",
		bar.get_global_rect().end.y <= spacer.get_global_rect().end.y + 1.0)
	await _shot("laptop_1280x720")
	await _key(KEY_COMMA)
	var controls: ControlsDialog = _main.get("_controls")
	_check(", opens the controls list", controls.visible)
	await _shot("controls_1280x720")
	await _key(KEY_ESCAPE)
	_check("Escape closes it", not controls.visible)
	DisplayServer.window_set_size(was)
	await _frames(20)
	# A view the shape of a phone held upright: the model framed to fit
	# across it, not just up it. A viewport of its own, with a camera of
	# the app's own kind, so the shape does not depend on the display.
	var bounds: AABB = AABB(Vector3(-80, 0, -40), Vector3(160, 48, 80))
	var upright := SubViewport.new()
	upright.size = Vector2i(400, 860)
	upright.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(upright)
	var lens := CadCamera.new()
	upright.add_child(lens)
	await _frames(3)
	lens.frame(bounds)
	for _n: int in 120:
		await process_frame
	var inside: bool = true
	for n: int in 8:
		var corner: Vector3 = bounds.position + Vector3(
			bounds.size.x if n & 1 else 0.0, bounds.size.y if n & 2 else 0.0,
			bounds.size.z if n & 4 else 0.0)
		var at: Vector2 = lens.unproject_position(corner)
		inside = inside and at.x >= 0.0 and at.x <= 400.0
	_check("in a view the shape of a phone held upright, framing fits the model across it",
		inside)
	upright.queue_free()


## The old corner's error for a part standing upright: its cover's corner
## less its footprint's, as Seating measures it.
func _old_error(mesh: Lbm.PartMesh, part: String, assistant: Assistant) -> Vector3:
	var cover := Vector3i(0x7FFFFFFF, 0, 0x7FFFFFFF)
	for cell: Vector3i in _builder._cells_for(mesh, Transform3D.IDENTITY):
		cover = Vector3i(mini(cover.x, cell.x), 0, mini(cover.z, cell.z))
	var footprint: Vector3i = assistant._corner_cell(mesh, part, Basis.IDENTITY)
	return Vector3((cover.x - footprint.x) * BrickLattice.CELL, 0.0,
		(cover.z - footprint.z) * BrickLattice.CELL)


## A place near a point where the part's studs are on stud middles.
func _seated_near(mesh: Lbm.PartMesh, near: Vector3) -> Variant:
	for i: int in 10:
		for k: int in 10:
			var at := Transform3D(Basis.IDENTITY, near + Vector3(i * 2.0, 0, k * 2.0))
			if Seating.off_the_studs(mesh, at) <= 0.01:
				return at
	return null


# -- helpers ------------------------------------------------------------------


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _colours() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		out[brick.color_code] = int(out.get(brick.color_code, 0)) + 1
	return out


func _places(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null:
			out[brick_id] = brick.transform
	return out


## Every part, by what it is and where, so two states compare by value.
func _snapshot() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		out.append("%s %d %s" % [brick.part_id, brick.color_code,
			LdrModel._line_numbers(brick.transform)])
	out.sort()
	return out


## The bricks whose middle is within two studs of a point on the ground.
func _bricks_near(point: Vector3) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _model():
		var at: Vector3 = brick.transform.origin
		if absf(at.x - point.x) <= 40.0 and absf(at.z - point.z) <= 40.0:
			out.append(brick.id)
	return out


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


## The pasted bay is the original moved by whole studs: the same parts,
## turned the same way, the same distances apart.
func _same_shape() -> bool:
	var first: Array = []
	var second: Array = []
	for brick: BrickWorld.Brick in _model():
		if _builder.selection.has(brick.id):
			second.append(brick)
		else:
			first.append(brick)
	if first.size() != 3 or second.size() != 3:
		return false
	var by_part := func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.part_id < b.part_id
	first.sort_custom(by_part)
	second.sort_custom(by_part)
	var shift: Vector3 = (second[0] as BrickWorld.Brick).transform.origin \
		- (first[0] as BrickWorld.Brick).transform.origin
	if not is_zero_approx(fmod(absf(shift.x), BrickLattice.STUD)) \
			or not is_zero_approx(fmod(absf(shift.z), BrickLattice.STUD)):
		return false
	for n: int in 3:
		var a: BrickWorld.Brick = first[n]
		var b: BrickWorld.Brick = second[n]
		if a.part_id != b.part_id or a.color_code != b.color_code:
			return false
		if not (a.transform.origin + shift).is_equal_approx(b.transform.origin):
			return false
		if not a.transform.basis.is_equal_approx(b.transform.basis):
			return false
	return true


## Whether every part sits where snapping would have put it: its middle on
## the stud grid for its own footprint, the way a hand-placed part is.
func _all_on_studs() -> bool:
	for brick: BrickWorld.Brick in _model():
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var box: AABB = (Transform3D(brick.transform.basis, Vector3.ZERO) * part.bounds).abs()
		var footprint := Vector2i(roundi(box.size.x / BrickLattice.STUD),
			roundi(box.size.z / BrickLattice.STUD))
		var snapped: Vector3 = BrickLattice.snap_to_studs(brick.transform.origin, footprint)
		if not snapped.is_equal_approx(brick.transform.origin):
			print("    off the studs: %s at %s" % [brick.part_id, brick.transform.origin])
			return false
	return true


func _long_axis_of_new(part: String) -> Vector3:
	for brick_id: int in _builder.selection:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and brick.part_id == part:
			return (brick.transform.basis * Vector3.RIGHT).normalized()
	return Vector3.ZERO


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
	await _frames(4)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _key_alt(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.alt_pressed = true
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/handbuild/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/handbuild/%s.png" % name)
