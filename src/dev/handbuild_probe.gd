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
	# `-- only=<section>` runs one section of this probe on its own, after
	# the same start: `-- only=first_timer`.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			_main.call("clear_model")
			await call("_" + arg.substr(5))
			print("")
			print("by hand, %s only: %s" % [arg.substr(5),
				"every check passed" if _failures == 0 else "%d FAILED" % _failures])
			quit(1 if _failures > 0 else 0)
			return
	await _one_column_at_a_time()
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
	await _the_shell()
	await _palette_paints_the_selection()
	await _text_fields_give_keys_back()
	await _seat_an_old_model()
	await _replace_and_history()
	await _the_parts_shelf()
	await _prints_by_their_print()
	await _exports()
	await _under_a_part()
	await _onto_side_studs()
	await _mirrored()
	await _studio_file()
	await _author_steps()
	await _build_from_a_booklet()
	await _swing_on_a_hinge()
	await _a_submodel()
	await _the_ruler()
	await _a_small_laptop()
	await _floor_menu()
	await _first_timer()
	await _patterns()

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
	_check("...and another copy stays in hand for the next, turned as this one",
		_builder.is_carrying() and _builder.carrying.repeats and _builder.carrying.turns == 1)
	await _key(KEY_ESCAPE)
	_check("Esc lets go of it", not _builder.is_carrying() and _count() == 9)


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
	# A part in hand, as choosing one in the bin puts it.
	(_main.get("_verbs") as EditVerbs).set_mode("place")
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
	# From the toolbar's Select by menu, the way a person reaches it.
	var shell: Shell = _main.get("_shell")
	_select_only([first])
	var menu_button: MenuButton = shell.toolbar._buttons["select"]
	await _click(menu_button.get_global_rect().get_center())
	_check("the Select by button opens its menu", menu_button.get_popup().visible)
	var popup: PopupMenu = menu_button.get_popup()
	_check("...under the button, all of it inside the window (%d + %d of %d)" % [
		popup.position.x, popup.size.x, DisplayServer.window_get_size().x],
		popup.position.x + popup.size.x <= DisplayServer.window_get_size().x + 1
		and popup.position.y >= int(menu_button.get_screen_position().y))
	await _shot("select_menu")
	popup.id_pressed.emit(shell.menu_id("select_colour"))
	popup.hide()
	await _frames(3)
	_check("...whose Same colour takes the three reds", _builder.selection.size() == 3)


func _hide_and_isolate() -> void:
	print("  hiding and showing only")
	var pair: Array = _bricks_near(Vector3(-60, 0, 20))
	_select_only(pair)
	await _frames(2)
	await _key(KEY_H, true)
	var hidden: bool = pair.all(func(b: int) -> bool: return _world.get_brick(b).hidden)
	_check("Ctrl-H hides the selection", hidden and _builder.selection.is_empty())
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
	await _key(KEY_H, true)
	_check("Ctrl-H with nothing selected shows everything again",
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


func _the_shell() -> void:
	print("  the menus, the toolbar and its tools, the properties, the status bar")
	var shell: Shell = _main.get("_shell")
	var bar: ModelBar = _main.get("_bar")
	var verbs: EditVerbs = _main.get("_verbs")
	var tools: Toolbar = shell.toolbar
	var titles: Array = bar.menus.get_children().map(func(m: MenuButton) -> String: return m.text)
	_check("the menus are along the top: %s" % ", ".join(titles),
		titles == ["File", "Edit", "View", "Build", "Tools", "Help"])
	_check("the toolbar is under them", tools.is_visible_in_tree()
		and tools.get_global_rect().position.y >= bar.get_global_rect().end.y - 1.0)
	_check("the status bar is along the foot of the window",
		shell.status.get_global_rect().end.y >= root.get_visible_rect().size.y - 1.0)
	var buttons: Dictionary = tools._buttons
	var said: bool = true
	for name: String in buttons:
		said = said and (buttons[name] as Control).tooltip_text.strip_edges().length() > 4
	_check("every toolbar button says what it does (%d)" % buttons.size(),
		said and buttons.size() >= 30)
	_check("...and its key: %s" % (buttons["undo"] as Button).tooltip_text.get_slice("\n", 0),
		(buttons["undo"] as Button).tooltip_text.begins_with("Undo   Ctrl+Z"))

	# A fresh pair to work on: a red 2 x 4, and a blue one four studs away.
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3001", 1, Vector3(60, 24, 20))
	await _frames(3)
	var red: int = _bricks_near(Vector3(-60, 0, 20))[0]
	var blue: int = _bricks_near(Vector3(60, 0, 20))[0]
	var on_red: Vector2 = _screen(Vector3(-60, 24, 20))
	var on_blue: Vector2 = _screen(Vector3(60, 24, 20))
	var empty: Vector2 = _screen(Vector3(0, 0, -160))

	# The Edit menu: opened by a click, every item with its key, greyed
	# where it would do nothing.
	_builder.clear_selection()
	var edit: MenuButton = shell.menu("Edit")
	await _click(edit.get_global_rect().get_center())
	var popup: PopupMenu = edit.get_popup()
	var copy_at: int = popup.get_item_index(shell.menu_id("copy"))
	_check("Edit opens its menu", popup.visible)
	_check("...with Copy and its key beside it (%s)" % OS.get_keycode_string(
		popup.get_item_accelerator(copy_at)), popup.get_item_text(copy_at) == "Copy"
		and popup.get_item_accelerator(copy_at) == (KEY_MASK_CMD_OR_CTRL | KEY_C))
	_check("...greyed with nothing selected", popup.is_item_disabled(copy_at))
	await _shot("edit_menu")
	popup.hide()
	await _frames(3)
	_select_only([red])
	await _click(edit.get_global_rect().get_center())
	_check("...and not with something selected", not popup.is_item_disabled(copy_at))
	Carry.clipboard = []
	popup.id_pressed.emit(shell.menu_id("copy"))
	popup.hide()
	await _frames(3)
	_check("choosing Copy copies it (%d)" % Carry.clipboard.size(), Carry.clipboard.size() == 1)

	# The tools.
	_builder.clear_selection()
	await _click((buttons["mode_select"] as Button).get_global_rect().get_center())
	_check("the Select tool lights and Place goes dark",
		(buttons["mode_select"] as Button).button_pressed
		and not (buttons["mode_place"] as Button).button_pressed and verbs.mode == "select")
	await _move(on_red)
	await _move(on_red + Vector2(1, 0))
	_check("...and no part in hand follows the pointer", not _builder.has_preview())
	await _click(on_red + Vector2(1, 0))
	_check("a click picks the red one out (%s)" % str(_builder.selection.keys()),
		_builder.selection.keys() == [red])
	await _shift_click(on_blue)
	_check("Shift-click adds the blue one", _builder.selection.size() == 2)
	_check("...and nothing was put down (%d parts)" % _count(), _count() == 2)
	await _click(empty)
	_check("a click on nothing lets go of both", _builder.selection.is_empty())
	await _frames(8)
	_check("the status bar says what the tool does (%s)" % shell.status.fields()["hint"],
		str(shell.status.fields()["hint"]).begins_with("Select:"))
	await _shot("select_tool")

	await _click((buttons["mode_rotate"] as Button).get_global_rect().get_center())
	var facing: Basis = _world.get_brick(red).transform.basis
	await _click(on_red)
	var turned: Basis = _world.get_brick(red).transform.basis
	_check("the Rotate tool turns a part a quarter where it stands",
		turned.is_equal_approx(Basis(Vector3.UP, PI * 0.5) * facing)
		or turned.is_equal_approx(Basis(Vector3.UP, -PI * 0.5) * facing))
	tools._turn.select(1)
	tools._turn.item_selected.emit(1)
	_check("the turn step goes to 45° (%d)" % roundi(verbs.turn_step),
		is_equal_approx(verbs.turn_step, 45.0))
	await _click(on_red)
	_check("...and the next click turns it 45°, off the grid",
		not BrickLattice.is_square_to_grid(_world.get_brick(red).transform.basis))
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	_check("two undos put it back as it was",
		_world.get_brick(red).transform.basis.is_equal_approx(facing))
	tools._turn.select(0)
	tools._turn.item_selected.emit(0)

	await _click((buttons["mode_paint"] as Button).get_global_rect().get_center())
	_builder.held_color = 2
	await _click(on_blue)
	_check("the Paint tool paints the part clicked (%d)" % _world.get_brick(blue).color_code,
		_world.get_brick(blue).color_code == 2)

	await _click((buttons["mode_clone"] as Button).get_global_rect().get_center())
	await _click(on_blue)
	_check("the Clone tool puts a copy of the part clicked in hand", _builder.is_carrying())
	var spot: Vector2 = _screen(Vector3(-60, 0, -100))
	await _move(spot)
	await _click(spot + Vector2(1, 0))
	_check("...and a click puts the copy down (%d parts)" % _count(), _count() == 3)
	_check("...and another copy stays in hand for the next", _builder.is_carrying())

	await _click((buttons["mode_move"] as Button).get_global_rect().get_center())
	var was: Vector3 = _world.get_brick(blue).transform.origin
	await _click(on_blue)
	_check("the Move tool picks the part clicked up", _builder.is_carrying())
	var there: Vector2 = _screen(Vector3(140, 0, -100))
	await _move(there)
	await _click(there + Vector2(1, 0))
	var moved_to: int = _bricks_near(Vector3(140, 0, -100)).size()
	_check("...and a click puts it down somewhere else (%s)" % str(was), moved_to == 1
		and not _builder.is_carrying() and _count() == 3)
	blue = _bricks_near(Vector3(140, 0, -100))[0]
	on_blue = _screen(_world.get_brick(blue).transform.origin)

	await _click((buttons["mode_hide"] as Button).get_global_rect().get_center())
	await _click(on_red)
	_check("the Hide tool hides the part clicked", _world.get_brick(red).hidden)
	await _key_alt(KEY_H)
	_check("...and Alt-H shows it again", not _world.get_brick(red).hidden)

	_select_only([red])
	await _key(KEY_L)
	_check("L locks the selection", _builder.is_locked(red))
	await _click((buttons["mode_delete"] as Button).get_global_rect().get_center())
	await _click(on_red)
	_check("the Delete tool leaves a locked part alone (%d parts)" % _count(), _count() == 3)
	_check("...and says so (%s)" % shell.status.fields()["message"],
		str(shell.status.fields()["message"]).contains("locked"))
	await _key(KEY_L, false, true)
	_check("Shift-L unlocks it", not _builder.is_locked(red))
	await _click(on_red)
	_check("then the Delete tool takes the part clicked off (%d parts)" % _count(), _count() == 2)
	await _key(KEY_Z, true)
	_check("...and undo puts it back (%d parts)" % _count(), _count() == 3)
	red = _bricks_near(Vector3(-60, 0, 20))[0]

	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check("Escape goes back to the Select tool, lit, with nothing in hand",
		verbs.mode == "select" and (buttons["mode_select"] as Button).button_pressed
		and not _builder.is_carrying())
	await _key(KEY_Q)
	_check("Q puts the last part back in hand, Place lit", verbs.mode == "place"
		and (buttons["mode_place"] as Button).button_pressed)
	await _key(KEY_V)
	_check("V is the Select tool", verbs.mode == "select")
	var tools_menu: MenuButton = shell.menu("Tools")
	await _click(tools_menu.get_global_rect().get_center())
	var listed: PopupMenu = tools_menu.get_popup()
	_check("...ticked in the Tools menu too",
		listed.is_item_checked(listed.get_item_index(shell.menu_id("mode_select")))
		and not listed.is_item_checked(listed.get_item_index(shell.menu_id("mode_place"))))
	await _shot("tools_menu")
	listed.hide()
	await _key(KEY_Q)
	await _key(KEY_ESCAPE)
	_check("...and Escape lets go of the part again", verbs.mode == "select")

	# What a part snaps to, and how far the arrows move it.
	tools._snap.select(1)
	tools._snap.item_selected.emit(1)
	_check("½ stud on the snap chooser snaps to half a stud (%.0f LDU)" % _builder.snap_across,
		is_equal_approx(_builder.snap_across, 10.0))
	_select_only([red])
	var before: Vector3 = _world.get_brick(red).transform.origin
	await _key(KEY_RIGHT)
	var step: Vector3 = _world.get_brick(red).transform.origin - before
	_check("...and an arrow moves the selection half a stud (%s)" % str(step),
		is_equal_approx(absf(step.x) + absf(step.z), 10.0))
	await _key(KEY_Z, true)
	tools._snap.select(0)
	tools._snap.item_selected.emit(0)
	_check("Stud snaps to whole studs again", is_equal_approx(_builder.snap_across, 20.0))

	# The properties of what is selected.
	var inspector: Inspector = shell.inspector
	_select_only([red])
	await _frames(20)
	_check("the properties name the part (%s)" % inspector._title.text,
		inspector._title.text == "Brick 2 x 4")
	_check("...by LDraw's number and BrickLink's (%s)" % inspector._ids.text,
		inspector._ids.text.contains("LDraw 3001") and inspector._ids.text.contains("BrickLink 3001"))
	_check("...and its colour by every name it has (%s)" % inspector._colour.text.replace("\n", " / "),
		inspector._colour.text.begins_with("Red (4)") and inspector._colour.text.contains("LEGO")
		and inspector._colour.text.contains("BrickLink 5"))
	_check("...where it stands (%d, %d, %d)" % [inspector._x.value, inspector._y.value,
		inspector._z.value], is_equal_approx(inspector._x.value, -60.0)
		and is_equal_approx(inspector._z.value, 20.0))
	_check("...and what it is joined to (%s)" % inspector._facts.text.get_slice("\n", 0),
		inspector._facts.text.begins_with("Joined to nothing"))
	# A part at a place a turn or a file leaves a hair off a whole number:
	# the boxes read "0.999999818" until they had a step.
	var was_at: Vector3 = inspector._at
	var was_facing: float = inspector._facing
	inspector._set_place(Vector3(0.99999982, 8.0000002, -19.9999997), 89.99999)
	# And as a box is left by an arrow step or a sum, unrounded: each must
	# show what a person would read, whatever float it holds.
	var unrounded: Array = [0.9999998211860657, 8.000000189989805, -19.999999701976776, 89.99999]
	for n: int in 4:
		([inspector._x, inspector._y, inspector._z, inspector._yaw][n] as SpinBox).set_value_no_signal(unrounded[n])
	await _frames(2)
	var shown := PackedStringArray()
	var clean := RegEx.create_from_string("^-?\\d+(\\.\\d{1,2})?$")
	var all_clean: bool = true
	for spin: SpinBox in [inspector._x, inspector._y, inspector._z, inspector._yaw]:
		var text: String = spin.get_line_edit().text
		shown.append(text)
		if clean.search(text) == null:
			all_clean = false
	_check("...in plain numbers, no float noise (%s)" % ", ".join(shown), all_clean)
	inspector._set_place(was_at, was_facing)
	await _frames(2)
	await _shot("properties")
	var field: LineEdit = inspector._x.get_line_edit()
	field.text = "-100"
	field.text_submitted.emit("-100")
	await _frames(5)
	_check("typing -100 for X moves it two studs (%s)" % str(_world.get_brick(red).transform.origin),
		is_equal_approx(_world.get_brick(red).transform.origin.x, -100.0))
	_check("...and gives the keys back to the model",
		root.gui_get_focus_owner() == null)
	var turn_field: LineEdit = inspector._yaw.get_line_edit()
	var yaw_was: float = inspector._yaw.value
	turn_field.text = str(roundi(yaw_was + 90.0))
	turn_field.text_submitted.emit(turn_field.text)
	await _frames(5)
	_check("typing a turn 90° on turns it a quarter (%.0f° to %.0f°)" % [yaw_was,
		inspector._yaw.value], is_equal_approx(fposmod(inspector._yaw.value - yaw_was, 360.0), 90.0))
	# Tilt and roll beside the turn: tipped about its middle, off the grid,
	# as a hinged panel is. Lifted first, so tipping it does not put a
	# corner through the baseplate.
	var lift_field: LineEdit = inspector._y.get_line_edit()
	lift_field.text = str(roundi(inspector._y.value + 48.0))
	lift_field.text_submitted.emit(lift_field.text)
	await _frames(5)
	var tilt_field: LineEdit = inspector._tilt.get_line_edit()
	tilt_field.text = "30"
	tilt_field.text_submitted.emit("30")
	await _frames(5)
	var tipped: Vector2 = Inspector._tilt_of(_world.get_brick(red).transform.basis)
	_check("typing a tilt of 30° tips it 30° off the grid (%.1f°, the box %.1f°)" % [tipped.x,
		inspector._tilt.value], absf(tipped.x - 30.0) < 0.5
		and absf(inspector._tilt.value - 30.0) < 0.5)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	_select_only([red, blue])
	await _frames(20)
	_check("two selected: how many of what (%s)" % inspector._title.text.replace("\n", " / "),
		inspector._title.text == "2 parts selected" and inspector._ids.text.begins_with("2 × Brick 2 x 4"))

	# The status bar.
	var fields: Dictionary = shell.status.fields()
	_check("the status bar counts the parts (%s)" % fields["counts"],
		str(fields["counts"]).begins_with("3 bricks"))
	_check("...what is selected (%s)" % fields["selected"], fields["selected"] == "2 selected")
	_check("...the snap and the turn step (%s)" % fields["settings"],
		fields["settings"] == "snap stud · turn 90°")
	_check("...and how big a stud is on screen (%s)" % fields["zoom"],
		str(fields["zoom"]).begins_with("1 stud ≈ ") and not str(fields["zoom"]).ends_with(" 0 px"))

	# The view and the panels, from the menus.
	shell.run("grid")
	await _frames(3)
	_check("View, Stud grid lays lines over the baseplate", shell.grid.visible
		and shell.grid.mesh != null and shell.grid.mesh.get_surface_count() == 1)
	await _shot("grid")
	shell.run("grid")
	_check("...and takes them away", not shell.grid.visible)
	# The properties are down the right, under the model tree, the parts bin
	# having the left to itself (docs/APP_UX.md A10).
	var column: SideDock = _main.get("_props_dock")
	_check("the properties are in the right-hand column, the parts bin's on the left (%s in %s)"
		% [str(inspector.get_global_rect()), str(column.get_global_rect())],
		SideDock.of(inspector) == column and column.get_global_rect().position.x
		> (_main.get("_bin_dock") as SideDock).get_global_rect().end.x
		and (not column.is_open() or column.get_global_rect().encloses(inspector.get_global_rect())))
	if not column.is_open():
		shell.run("panel_properties")
		await _frames(30)
		_check("View, Properties opens the column they are in, with them open",
			column.is_open() and inspector.is_open() and inspector.is_visible_in_tree())
	shell.run("panel_properties")
	_check("View, Properties folds the properties away", not inspector.is_open())
	shell.run("panel_properties")
	_check("...and opens them", inspector.is_open())
	shell.run("panel_keys")
	_check("View, Key strip hides the strip of keys", not shell.key_strip_shown())
	shell.run("panel_keys")
	_check("...and shows it", shell.key_strip_shown())
	_check("a probe keeps no layout on this machine", not ShellPrefs.keeps())

	# Help, Take the tour.
	shell.run("tour")
	await _frames(5)
	_check("Help, Take the tour starts it", shell.tour.visible)
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	await _frames(5)
	_check("...Next goes on, lighting the toolbar (%s)" % shell.tour._heading.text,
		shell.tour._heading.text.begins_with("The toolbar")
		and shell.tour._lit.encloses(tools.get_global_rect()))
	await _shot("tour")
	await _key(KEY_ESCAPE)
	_check("...and Escape leaves it", not shell.tour.visible)
	_builder.clear_selection()
	await _frames(3)
	await _shot("shell")


## Choose a command from a menu on the bar, opening it with a click first
## the way a person does.
func _from_menu(title: String, command: String) -> void:
	var shell: Shell = _main.get("_shell")
	var menu: MenuButton = shell.menu(title)
	await _click(menu.get_global_rect().get_center())
	var popup: PopupMenu = menu.get_popup()
	_check("%s opens, with %s in it" % [title, command],
		popup.visible and popup.get_item_index(shell.menu_id(command)) >= 0)
	popup.id_pressed.emit(shell.menu_id(command))
	popup.hide()
	await _frames(4)


func _shift_click(at: Vector2) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.shift_pressed = true
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(2)


## A colour clicked in the palette with a part selected paints it, as in
## Studio. It only changed the colour in hand, and the brick a person had
## selected stayed red (brickworks.diy at dd5c10c, 2026-10-12).
func _palette_paints_the_selection() -> void:
	print("  a colour clicked in the palette")
	var bin: PartsBin = _main.get("_bin")
	var verbs: EditVerbs = _main.get("_verbs")
	await _key(KEY_ESCAPE)
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3001", 4, Vector3(60, 24, 20))
	await _frames(3)
	var picked: int = _bricks_near(Vector3(-60, 0, 20))[0]
	var other: int = _bricks_near(Vector3(60, 0, 20))[0]
	await _show_column("_bin_dock")
	await _frames(10)
	# Two swatches in sight in the palette's window, the way a person sees
	# them: neither red nor the colour in hand.
	var window: Rect2 = bin._palette_scroll.get_global_rect()
	var seen: Array[Control] = []
	for code: int in bin._swatches:
		var here: Control = bin._swatches[code]
		if code != 4 and code != bin.selected_color() and here.is_visible_in_tree() \
				and window.encloses(here.get_global_rect()):
			seen.append(here)
	if seen.size() < 2:
		_check("two swatches are in sight in the palette (%d)" % seen.size(), false)
		return
	var swatch: Control = seen[0]
	var colour: int = int(swatch.get_meta("code"))
	_select_only([picked])
	await _click(swatch.get_global_rect().get_center())
	_check("a colour clicked with a part selected paints it (%d, wanted %d)"
		% [_world.get_brick(picked).color_code, colour],
		_world.get_brick(picked).color_code == colour)
	_check("...and nothing else (%d)" % _world.get_brick(other).color_code,
		_world.get_brick(other).color_code == 4)
	_check("...and it is the colour in hand now", _builder.held_color == colour)
	await _key(KEY_Z, true)
	_check("one undo puts its colour back (%d)" % _world.get_brick(picked).color_code,
		_world.get_brick(picked).color_code == 4)
	# With a part in hand the colour is for what goes down next, not a paint.
	_select_only([picked])
	await _key(KEY_Q)
	_check("Q takes a part into hand, the selection still there (%s, %d selected)"
		% [verbs.mode, _builder.selection.size()],
		verbs.mode == "place" and _builder.selection.has(picked))
	var next: int = int(seen[1].get_meta("code"))
	await _click(seen[1].get_global_rect().get_center())
	_check("...and a colour clicked then is the part's in hand (%d), painting nothing (%d)"
		% [_builder.held_color, _world.get_brick(picked).color_code],
		_builder.held_color == next and _world.get_brick(picked).color_code == 4)
	await _key(KEY_ESCAPE)
	_builder.clear_selection()


## The owner: "When the user names a build (renames it), the text input
## never loses focus and can't control the CAD controls." Each way out of
## a field, and then a view key that must act at once.
func _text_fields_give_keys_back() -> void:
	print("  text fields give the keys back")
	var bar: ModelBar = _main.get("_bar")
	var shell: Shell = _main.get("_shell")
	var field: LineEdit = bar._name
	_builder.clear_selection()
	await _key(KEY_0)
	await _click(field.get_global_rect().get_center())
	_check("a click on the model's name puts the caret in it", field.has_focus())
	await _type("Renamed")
	await _key(KEY_ENTER)
	# The field lets go after it has done what Enter does there, a frame
	# or so later on a loaded machine.
	for _n: int in 30:
		if not field.has_focus():
			break
		await process_frame
	_check("Enter ends the typing (%s)" % field.text, not field.has_focus()
		and field.text.contains("Renamed"))
	# The click took the whole name: it was "UntitledRenamed", which the
	# check above passed (brickworks.diy at dd5c10c, 2026-10-12).
	_check("...and what was typed is the name, not added to the old one (%s)" % field.text,
		field.text == "Renamed")
	await _key(KEY_1)
	_check("...and 1 looks from the front at once", is_zero_approx(_camera._target_yaw)
		and is_zero_approx(_camera._target_pitch))
	await _key(KEY_0)
	var named: String = field.text
	await _click(field.get_global_rect().get_center())
	await _type(" more")
	await _click(shell.status.get_global_rect().get_center())
	_check("a click on a panel ends it", not field.has_focus())
	await _key(KEY_1)
	_check("...and 1 acts at once", is_zero_approx(_camera._target_yaw))
	await _key(KEY_0)
	named = field.text
	await _click(field.get_global_rect().get_center())
	await _type(" thrown away")
	await _key(KEY_ESCAPE)
	_check("Escape ends it and puts the name back (%s)" % field.text,
		not field.has_focus() and field.text == named)
	await _click(field.get_global_rect().get_center())
	await _key(KEY_TAB)
	_check("so does Tab", not field.has_focus())
	var yaw: float = _camera._target_yaw
	await _key(KEY_LEFT)
	_check("...and an arrow turns the view at once", not is_equal_approx(_camera._target_yaw, yaw))
	# The part search, and the properties' numbers.
	var bin: PartsBin = _main.get("_bin")
	var search: LineEdit = bin.get("_search")
	await _show_column("_bin_dock")
	await _click(search.get_global_rect().get_center())
	await _type("plate")
	await _key(KEY_ESCAPE)
	_check("Escape ends a search", not search.has_focus())
	search.text = ""
	search.text_changed.emit("")
	var any: Array = _model()
	if not any.is_empty():
		_select_only([(any[0] as BrickWorld.Brick).id])
		await _frames(20)
		# The properties' column, as a person opens it by its rail.
		await _show_column(_column_of(shell.inspector))
		var x_field: LineEdit = shell.inspector._x.get_line_edit()
		var was_x: float = (any[0] as BrickWorld.Brick).transform.origin.x
		await _click(x_field.get_global_rect().get_center())
		await _key(KEY_A, true)
		await _type(str(roundi(was_x + 40.0)))
		await _key(KEY_ENTER)
		_check("a number typed and entered in the properties moves the part and lets go (%s)"
			% str((any[0] as BrickWorld.Brick).transform.origin), not x_field.has_focus()
			and is_equal_approx((any[0] as BrickWorld.Brick).transform.origin.x, was_x + 40.0))
		var after: Vector3 = (any[0] as BrickWorld.Brick).transform.origin
		await _key(KEY_LEFT)
		_check("...and an arrow nudges it at once",
			not (any[0] as BrickWorld.Brick).transform.origin.is_equal_approx(after))
		await _key(KEY_Z, true)
		await _key(KEY_Z, true)
	_builder.clear_selection()


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


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
	var shell: Shell = _main.get("_shell")
	await _from_menu("Edit", "replace")
	var parts: Array = _model().map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	_check("Replace swaps both 2 x 4s for the 2 x 3 in hand (%s)" % str(parts),
		parts == ["3002", "3002"])
	_check("...each keeping its colour", _colours() == {1: 2})
	_check("...on its studs", _all_on_studs())
	var words: PackedStringArray = _builder.history_words()
	_check("the history says what was done, newest first (%s)" % str(words),
		words.size() >= 2 and words[0].begins_with("swapped 2 parts for Brick 2 x 3")
		and words[1] == "painted 2 parts")
	var menu: MenuButton = shell.toolbar._buttons["history"]
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
	await _show_column("_bin_dock")
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
	# A size typed without its spaces, into the field, key by key. LDraw
	# says "Brick  2 x  4" and the words were matched as typed, so
	# "brick 2x4" found nothing (brickworks.diy at dd5c10c, 2026-10-12);
	# and the builder's words the assistant's search knows ("cheese
	# slope") the bin did not.
	for asked: Array in [["brick 2x4", "3001"], ["plate 2x8", "3034"],
			["2X4 brick", "3001"], ["cheese slope", "54200"]]:
		await _click(bin._search.get_global_rect().get_center())
		await _key(KEY_A, true)
		await _type(str(asked[0]))
		await create_timer(0.4).timeout
		await _frames(3)
		var led: String = bin._results[0].id if not bin._results.is_empty() else "nothing"
		_check("typing \"%s\" in the search leads with %s (%s, %d found)"
			% [asked[0], asked[1], led, bin._results.size()], led == str(asked[1]))
		await _key(KEY_ESCAPE)
	bin._search.text = ""
	bin._run_search("")
	PartShelf.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PartShelf.file))
	PartShelf.keeps = false


## A print found by what is printed on it, typed into the bin's field.
## "porsche print" found nothing: LDraw names a print a Pattern, and no
## name has the word print in it (2026-10-13). print_search_probe holds
## the words; this is the bin a person types them into.
func _prints_by_their_print() -> void:
	print("  a print found by what is printed on it")
	var bin: PartsBin = _main.get("_bin")
	await _show_column("_bin_dock")
	bin.show_category("All")
	await _frames(4)
	for asked: Array in [["porsche print", "3623pt1"], ["turbo print", "15068pt2"]]:
		await _click(bin._search.get_global_rect().get_center())
		await _key(KEY_A, true)
		await _type(str(asked[0]))
		await create_timer(0.4).timeout
		await _frames(3)
		var first: Array = []
		for n: int in mini(8, bin._results.size()):
			first.append(bin._results[n].id)
		var plain: Array = first.filter(func(id: String) -> bool:
			return _library.parts[id].decor() == 0)
		_check("typing \"%s\" shows %s in the first two rows, and only prints (%s)"
			% [asked[0], asked[1], str(first)],
			first.has(asked[1]) and plain.is_empty())
		await _key(KEY_ESCAPE)
	# The pictures drawn, for a person to look at: 3623pt1 with PORSCHE on.
	await _click(bin._search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type("porsche print")
	await create_timer(0.4).timeout
	for _n: int in 40:
		await _frames(6)
	await _shot("prints_by_their_print")
	await _key(KEY_ESCAPE)
	await _click(bin._search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type("plate 1x3")
	await create_timer(0.4).timeout
	await _frames(3)
	var led: String = bin._results[0].id if not bin._results.is_empty() else "nothing"
	_check("and \"plate 1x3\" still leads with the plain 3623 (%s)" % led, led == "3623")
	await _key(KEY_ESCAPE)
	bin._search.text = ""
	bin._run_search("")


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
	_check("Ctrl-G asks what the sub-assembly is called (%s)" % (
		verbs._name_field.text if dialog != null else "no dialog"),
		dialog != null and dialog.visible and verbs._name_field.text == "Sub-assembly")
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


func _the_ruler() -> void:
	print("  measuring")
	_main.call("clear_model")
	_put("3001", 4, Vector3(0, 24, 20))
	_camera.set_view("top")
	_camera.frame(AABB(Vector3(-120, 0, -60), Vector3(240, 30, 140)))
	for _n: int in 40:
		await process_frame
	var measure: Measure = _main.get("_measure")
	await _key(KEY_U)
	_check("U takes the ruler out", measure.active and measure.label.visible)
	var before: int = _count()
	await _click(_screen(Vector3(-60, 0, -40)))
	await _click(_screen(Vector3(60, 0, -40)))
	var said: String = measure.words()
	_check("two clicks on the baseplate six studs apart say so (%s)" % said,
		said.contains("6 studs across") and said.begins_with("48 mm"))
	_check("...and put nothing down (%d parts)" % _count(), _count() == before)
	await _shot("ruler")
	await _key(KEY_ESCAPE)
	_check("Esc puts the ruler away", not measure.active and not measure.label.visible)
	_camera.set_view("default")


func _studio_file() -> void:
	print("  opening a BrickLink Studio .io file")
	var bar: ModelBar = _main.get("_bar")
	var shell: Shell = _main.get("_shell")
	# In the shape Studio 2.25 saves one, made by
	# tests/fixtures/studio/make_fixtures.py, not by this app: the model in
	# LDraw's numbers in model.ldr, and again in BrickLink's in model2.ldr.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/studio/bay_2025.io")
	_check("the Studio file is there to open (%d bytes)" % bytes.size(), bytes.size() > 100)
	# File, Import, BrickLink Studio model (.io)… is the way in, as Open's
	# From a file is: the same picker.
	var import_menu: PopupMenu = shell.menu("File").get_popup().get_node("import")
	_check("File, Import offers a BrickLink Studio model (%s)" % import_menu.get_item_text(
		import_menu.get_item_index(shell.menu_id("import_io"))),
		import_menu.get_item_text(import_menu.get_item_index(shell.menu_id("import_io")))
			.begins_with("BrickLink Studio model (.io)"))
	import_menu.id_pressed.emit(shell.menu_id("import_io"))
	await _frames(3)
	var picker: ModelFilePicker = bar._picker
	_check("...and pressing it asks for a file", picker != null and picker._dialog != null
		and picker._dialog.visible and picker._dialog.filters[0].contains("*.io"))
	if picker == null:
		return
	if picker._dialog != null:
		picker._dialog.hide()
	# The file's Part Designer part comes in with it (StudioDecor.carried),
	# kept here and not in the person's bin; it is built where its 3001.dat
	# can be read, a checkout with the LDraw library, and named as left out
	# where it cannot (the web build).
	var kept_in: String = CustomParts.dir
	var keeping: bool = CustomParts.keeps
	CustomParts.dir = OS.get_user_data_dir().path_join("handbuild_probe_parts/")
	CustomParts.keeps = false
	picker.take(bytes, "bay_2025.io")
	await _frames(1)
	# Over the parts built by hand so far, none of them saved, it asks first
	# (ModelBar.ask_to_replace, e84e1141, 2026-10-23), and a person opening
	# the file says Don't save. Unanswered, the file never opened, and the
	# question still up stopped the next open as well.
	var asked: Dictionary = bar.controls_by_name()
	_check("...and over parts not saved, asks first: Save, Don't save or Cancel",
		asked.has("replace_save") and asked.has("replace_discard") and asked.has("replace_cancel"))
	if asked.has("replace_discard"):
		(asked["replace_discard"] as Button).pressed.emit()
	await _frames(10)
	CustomParts.dir = kept_in
	CustomParts.keeps = keeping
	var whole: bool = not PartForge._read_library("3001.dat").is_empty()
	var parts: Array = _model().map(func(b: BrickWorld.Brick) -> String: return b.part_id)
	parts.sort()
	var wanted: Array = ["3001", "3001", "3004", "3022", "3068b"]
	var colours: Dictionary = {4: 1, 15: 1, 14: 1, 1: 1, 0: 1}
	if whole:
		wanted.append("m1a2b3c4_2025408_163200")
		colours[71] = 1
	_check("a Studio .io opens its model, sub-model and all (%s)" % str(parts), parts == wanted)
	_check("...in LDraw's colours, not BrickLink's (%s)" % _colours(), _colours() == colours)
	_check("...under its file's name (%s)" % bar.model_name(), bar.model_name() == "Bay 2025")
	if whole:
		_check("...its Part Designer part among them, from the file: \"%s\"" % bar._status.text,
			bar._status.text.begins_with("opened 6 parts") and not bar._status.text.contains("left out"))
	else:
		_check("...and the part only Studio has is named in the status bar: \"%s\"" % bar._status.text,
			bar._status.text.contains("1 not shown, kept in the file (m1a2b3c4_2025408_163200)"))


## A model with its author's steps, opened, and its steps changed the ways
## Studio, LeoCAD and LDCad change theirs: from the keys, the Edit menu and
## the timeline's own buttons, each one undo.
func _author_steps() -> void:
	print("  the author's steps: shown, and changed by hand")
	var bar: ModelBar = _main.get("_bar")
	var shell: Shell = _main.get("_shell")
	var steps: StepsBar = _main.get("_steps")
	var import_menu: PopupMenu = shell.menu("File").get_popup().get_node("import")
	import_menu.id_pressed.emit(shell.menu_id("import_ldraw"))
	await _frames(3)
	var picker: ModelFilePicker = bar._picker
	if picker == null:
		_check("File, Import, LDraw model asks for a file", false)
		return
	if picker._dialog != null:
		picker._dialog.hide()
	picker.take(FileAccess.get_file_as_bytes("res://tests/fixtures/steps/gatehouse.mpd"),
		"gatehouse.mpd")
	await _frames(10)
	_check("gatehouse.mpd opens, 14 parts, every one in the author's step (%d)" % _count(),
		_count() == 14 and _model().all(func(b: BrickWorld.Brick) -> bool: return b.step >= 0))
	var yellow: int = _part_id("3003")
	var blue: int = _part_id("3005", 1)
	var white: int = _part_id("3004")
	var green: int = _part_id("3022")

	await _key(KEY_B)
	# The author's steps are read over frames, as the worked-out ones are
	# (13fa0aae, 2026-10-24): five frames after the key, it was still reading.
	var since: int = Time.get_ticks_msec()
	while steps.is_starting() and Time.get_ticks_msec() - since < 30000:
		await process_frame
	_check("B opens the timeline in the author's steps (%s), at \"%s\"" % [
		steps._order_button.text, steps._caption.text], steps.is_playing_back()
		and steps.mode() == StepsBar.AUTHORS and steps._caption.text.begins_with("Step 1 of 6"))
	var named: Dictionary = steps.controls_by_name()
	_check("...with its step edits on the bar (%s)" % ", ".join(["earlier", "later", "merge",
		"delete", "new"].filter(func(op: String) -> bool:
			return named.has("steps_" + op) and (named["steps_" + op] as Button).is_visible_in_tree())),
		["earlier", "later", "merge", "delete", "new"].all(func(op: String) -> bool:
			return named.has("steps_" + op) and (named["steps_" + op] as Button).is_visible_in_tree()))
	for _n: int in 2:
		await _click((named["steps_next"] as Button).get_global_rect().get_center())
	_check("Next twice: step 3, the yellow brick (\"%s\")" % steps._caption.text,
		steps._caption.text.begins_with("Step 3 of 6"))
	await _shot("author_steps_3")

	# A click on the yellow brick, under the white one the timeline has not
	# put on yet: the pointer passes through what is not drawn. It took the
	# white brick, and Shift-] moved that.
	_builder.clear_selection()
	var under_white: Vector2 = _screen(Vector3(-20, 72, -10))
	await _move(under_white)
	await _click(under_white)
	_check("a click on the yellow brick takes it, not the white one above it still to come "
		+ "(%s)" % str(_builder.selection.keys()), _builder.selection.keys() == [yellow])
	# Shift-] with the yellow brick selected: into the next step, the blue one's.
	_select_only([yellow])
	await _frames(2)
	await _key(KEY_BRACKETRIGHT, false, true)
	_check("Shift-] puts the selected part in the next step, with the blue brick "
		+ "(yellow %d, blue %d; \"%s\")" % [_step(yellow), _step(blue), bar._status.text],
		_step(yellow) == _step(blue) and _step(yellow) == 1
		and bar._status.text.contains("moved 1 part to the next step"))
	_check("...and the timeline follows: \"%s\"" % steps._caption.text,
		steps._caption.text.begins_with("Step 3 of 5"))
	await _key(KEY_Z, true)
	_check("Ctrl-Z takes it back (yellow %d, blue %d; \"%s\")" % [_step(yellow), _step(blue),
		steps._caption.text], _step(yellow) == 1 and _step(blue) == 2
		and steps._caption.text.contains("of 6"))
	await _key(KEY_BRACKETLEFT, false, true)
	await _key(KEY_BRACKETLEFT, false, true)
	_check("Shift-[ twice puts it in the first step, and no further (yellow %d)" % _step(yellow),
		_step(yellow) == 0)
	await _key(KEY_Z, true)
	_check("...one undo for each press that changed it (yellow %d)" % _step(yellow),
		_step(yellow) == 1)

	# Build, Build steps, New step from selection: the white brick out of the
	# step that puts the windows on, into one of its own.
	var edit_menu: PopupMenu = shell.menu("Build").get_popup().get_node("steps")
	var texts := PackedStringArray()
	for index: int in edit_menu.item_count:
		texts.append(edit_menu.get_item_text(index))
	# The menu cannot write "[" as a key (Shell.UNDRAWN), so the line says it.
	_check("Build, Build steps lists the step edits, with their keys (%s)" % ", ".join(texts),
		"Move to previous step    Shift+[" in texts and "Move to next step    Shift+]" in texts
		and "New step from selection" in texts and "Merge with the next step" in texts
		and edit_menu.get_item_accelerator(edit_menu.get_item_index(shell.menu_id("step_new")))
			== KEY_MASK_SHIFT | KEY_N)
	await _to_step(steps, "Step 5 of 6 · Window (2x), put on")
	_check("Next to step 5, where the windows go on: \"%s\"" % steps._caption.text,
		steps._caption.text.begins_with("Step 5 of 6 · Window (2x), put on"))
	_select_only([white])
	edit_menu.id_pressed.emit(shell.menu_id("step_new"))
	await _frames(3)
	_check("New step from selection: the white brick has a step of its own after the windows "
		+ "(white %d, green %d; \"%s\")" % [_step(white), _step(green), steps._caption.text],
		_step(white) == 4 and _step(green) == 5 and steps._caption.text.begins_with("Step 6 of 7"))
	await _shot("author_steps_new")

	# The timeline's own buttons, on the step showing.
	_builder.clear_selection()
	await _click((named["steps_back"] as Button).get_global_rect().get_center())
	await _click((named["steps_merge"] as Button).get_global_rect().get_center())
	_check("Back, then Merge with next: the white brick back with the windows (white %d, "
		% _step(white) + "green %d; \"%s\")" % [_step(green), steps._caption.text],
		_step(white) == 3 and _step(green) == 4 and steps._caption.text.contains("of 6"))
	await _to_step(steps, "Step 4 of 6")
	await _click((named["steps_earlier"] as Button).get_global_rect().get_center())
	_check("Earlier on step 4: the blue brick before the yellow (blue %d, yellow %d; \"%s\")"
		% [_step(blue), _step(yellow), steps._caption.text], _step(blue) == 1
		and _step(yellow) == 2 and steps._caption.text.begins_with("Step 3 of 6"))
	await _click((named["steps_delete"] as Button).get_global_rect().get_center())
	_check("Delete step: its part joins the step before and the rest close up, nothing taken "
		+ "off (blue %d, yellow %d, %d parts)" % [_step(blue), _step(yellow), _count()],
		_step(blue) == 0 and _step(yellow) == 1 and _count() == 14)
	await _key(KEY_Z, true)
	await _key(KEY_Z, true)
	_check("two undos, and the steps are the author's again (blue %d, yellow %d)"
		% [_step(blue), _step(yellow)], _step(blue) == 2 and _step(yellow) == 1)

	# A copy pasted while the timeline is on a step goes in that step.
	await _to_step(steps, "Step 3 of 6")
	_select_only([yellow])
	await _key(KEY_C, true)
	await _key(KEY_ESCAPE)
	await _key(KEY_V, true)
	var spot: Vector2 = _screen(Vector3(90, 0, 40))
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _click(spot + Vector2(1, 0))
	var pasted: int = 0
	for brick: BrickWorld.Brick in _model():
		if brick.part_id == "3003" and brick.id != yellow:
			pasted = brick.id
	_check("a copy put down while the timeline is on step 3 goes in it (step %d; \"%s\")"
		% [_step(pasted), steps._caption.text], pasted != 0 and _step(pasted) == 1
		and steps._caption.text.begins_with("Step 3 of 6"))
	await _key(KEY_Z, true)
	steps.stop()
	await _frames(2)
	# With nothing selected [ and ] still change the colour in hand.
	_builder.clear_selection()
	var colour: int = _builder.held_color
	await _key(KEY_BRACKETRIGHT)
	_check("with nothing selected, ] still changes the colour in hand (%d to %d)"
		% [colour, _builder.held_color], _builder.held_color != colour)


## A real set built from its booklet with only what a person has, as the
## CAD task test builds 5762-1's plane (docs/CADTASK.md): a part number
## typed brings that part first, a colour is taken by its name, E ends each
## step as it is built, the plane's clip plates go where the set has them,
## and Right steps the timeline after a part was taken by a click on its
## tile. Each was a gap the test met on 2026-10-16.
func _build_from_a_booklet() -> void:
	print("  building from a booklet: numbers, colours by name, clip plates, steps, the keys")
	var bin: PartsBin = _main.get("_bin")
	var shell: Shell = _main.get("_shell")
	var steps: StepsBar = _main.get("_steps")
	var bar: ModelBar = _main.get("_bar")
	steps.stop()
	_main.call("clear_model")
	await _show_column("_bin_dock")
	bin.show_category("All")
	await _frames(6)

	# The numbers off a parts list, each the first tile. "6157" listed a
	# minifigure leg first, whose shop number 761579 has it in it.
	for number: String in ["6157", "4081b", "3795", "32028", "3034"]:
		await _take_by_number(bin, number)
		_check("%s typed in the search, the first tile puts %s in hand (%s)"
			% [number, number, _builder.held_part], _builder.held_part == number)

	# A colour by its name: Shift-C, the name, Enter. The old greys are not
	# in the palette until All, and look like the bluish greys beside them.
	for asked: Array in [["light grey", 7], ["dark gray", 8], ["71", 71], ["Light Bluish", 71],
			["light grey", 7]]:
		await _key(KEY_C, false, true)
		var field: LineEdit = bin._colour_find
		_check("Shift-C puts the keys in the colour's name", field.has_focus())
		await _type(str(asked[0]))
		_check("...\"%s\" names %d first over the palette (%d)" % [asked[0], asked[1],
			bin.colour_first()], bin.colour_first() == int(asked[1]))
		await _key(KEY_ENTER)
		_check("\"%s\" and Enter: %d in hand (%d), the field let go" % [asked[0], asked[1],
			_builder.held_color], _builder.held_color == int(asked[1]) and not field.has_focus()
			and field.text.is_empty())
	_check("...and its swatch shows, chosen (%s)" % str(bin._swatches.has(7)),
		bin._swatches.has(7) and (bin._swatches[7] as Button).button_pressed)

	# The plane's first two steps as its file has them, a plate up so the
	# first stands on the baseplate rather than in it, then E: one step of
	# the two plates, numbered as the timeline counts.
	_put_ldr("3034", 7, [0, -8, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_put_ldr("3022", 15, [0, -16, -60, 0, 0, 1, 0, 1, 0, -1, 0, 0])
	_camera.frame(AABB(Vector3(-100, 0, -100), Vector3(200, 40, 200)))
	await _frames(40)
	var plates: Array = _model().map(func(b: BrickWorld.Brick) -> int: return b.id)
	await _key(KEY_E)
	_check("E with two parts down and no steps: they are step 1 (%s; \"%s\")"
		% [str(plates.map(_step)), bar._status.text],
		plates.all(func(id: int) -> bool: return _step(id) == 0)
		and bar._status.text.contains("step 1: 2 parts"))

	# The two clip plates of its step 4, each turned a quarter, the clip
	# over the edge of the plate under it. The ghost stood 10 LDU high and
	# half a stud aside: the part was snapped by its box, clip included.
	await _take_by_number(bin, "4081b")
	await _key(KEY_C, false, true)
	await _type("light grey")
	await _key(KEY_ENTER)
	var clips: Array = []
	for want: Array in [[-10, -24, -50, 0, 0, 1, 0, 1, 0, -1, 0, 0],
			[10, -24, -50, 0, 0, -1, 0, 1, 0, 1, 0, 0]]:
		var at: Transform3D = _ldr(want)
		# Studs up first: an earlier section may have left the hand tipped
		# over (T), as a person may.
		for _n: int in 6:
			if _builder.held_face == "up":
				break
			await _key(KEY_T)
		for _n: int in 4:
			if BrickLattice.basis_for(_builder.held_face, _builder.held_rotation) \
					.is_equal_approx(at.basis):
				break
			await _key(KEY_R)
		# On the plate it stands on, under the middle of its own: where a
		# person points to put a plate down.
		var under: Vector2 = _screen(at.origin - Vector3(0, 8, 0))
		await _move(under + Vector2(0, 1))
		await _move(under)
		var ghost: Variant = _builder.ghost_place()
		var over: BrickWorld.Brick = _world.get_brick(_builder.hovered_brick())
		_check("the clip plate's ghost stands where the plane has it (%s, wanted %s, %s; over %s, snap %s, %s)"
			% [str(ghost), str(at.origin), "may go" if _builder.can_place() else "red",
				over.part_id if over != null else "nothing", _builder.snap_across,
				_store.model_floor.to_meta()],
			ghost != null and (ghost as Vector3).is_equal_approx(at.origin) and _builder.can_place())
		await _click(under)
		var made: int = 0
		for brick: BrickWorld.Brick in _model():
			if brick.part_id == "4081b" and not clips.has(brick.id):
				made = brick.id
		clips.append(made)
		var put: Transform3D = _world.get_brick(made).transform if made != 0 else Transform3D()
		_check("...a click puts it there, turned as the file has it, light grey (%s)"
			% str(put.origin), made != 0 and put.origin.is_equal_approx(at.origin)
			and put.basis.is_equal_approx(at.basis) and _world.get_brick(made).color_code == 7)
	_phases_as_the_sets_have_them()
	await _key(KEY_E)
	_check("E again: the clips are step 2, the plates still step 1 (%s, %s)"
		% [str(clips.map(_step)), str(plates.map(_step))],
		clips.all(func(id: int) -> bool: return _step(id) == 1)
		and plates.all(func(id: int) -> bool: return _step(id) == 0))
	await _key(KEY_Z, true)
	_check("Ctrl-Z takes the step back and leaves the parts (%s, %d parts)"
		% [str(clips.map(_step)), _count()],
		clips.all(func(id: int) -> bool: return _step(id) == -1) and _count() == 4)
	await _key(KEY_Z, true, true)
	_check("...and redo makes it again (%s)" % str(clips.map(_step)),
		clips.all(func(id: int) -> bool: return _step(id) == 1))
	await _key(KEY_E)
	_check("E with nothing put down since says so, and makes no empty step (\"%s\")"
		% bar._status.text, bar._status.text.contains("step 2 is done")
		and AuthorSteps.steps_in(_world, "", _store.scenery).size() == 2)
	# By its words: a command in two menus has a row, and an id, in each.
	var build_menu: PopupMenu = shell.menu("Build").get_popup()
	var index: int = -1
	for row: int in build_menu.item_count:
		if build_menu.get_item_text(row) == "Next step":
			index = row
	_check("Build lists Next step, with its key E (%s)" % (build_menu.get_item_text(index)
		if index >= 0 else "not there"), index >= 0
		and build_menu.get_item_accelerator(index) == KEY_E)

	# The last part was taken by a click on its tile. The tile kept the keys,
	# and Right walked the focus round the bin instead of the timeline.
	var owner: Control = root.gui_get_focus_owner()
	_check("a tile clicked does not keep the keys (%s)" % (owner.get_class() if owner else "none"),
		owner == null or not bin.is_ancestor_of(owner))
	await _key(KEY_ESCAPE)
	await _key(KEY_B)
	await _frames(20)
	_check("B opens the timeline in the steps just made (\"%s\")" % steps._caption.text,
		steps.is_playing_back() and steps._caption.text.begins_with("Step 1 of 2"))
	await _key(KEY_RIGHT)
	_check("Right steps it on (\"%s\")" % steps._caption.text,
		steps._caption.text.begins_with("Step 2 of 2"))
	await _key(KEY_LEFT)
	_check("...and Left back (\"%s\")" % steps._caption.text,
		steps._caption.text.begins_with("Step 1 of 2"))
	await _shot("booklet_steps")
	steps.stop()
	await _key(KEY_ESCAPE)
	_main.call("clear_model")
	await _frames(4)


## Where across the stud grid each upright part of the CAD task's three sets
## goes, by the rule the ghost uses, against where its file has it: the
## sockets' rule (Builder._socket_phase) must agree wherever the box's did,
## and more. A first version took a wedge plate's off-grid sockets at their
## word and put 51739 2 LDU off its studs (the build flow, 2026-10-16).
func _phases_as_the_sets_have_them() -> void:
	var by_box: int = 0
	var by_rule: int = 0
	var parts: int = 0
	var worse := PackedStringArray()
	for name: String in ["5762-1_Plane.mpd", "8643-1_Combination-with-8644.mpd",
			"8841-1_Balance.mpd"]:
		var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/" + name)
		for line: String in text.split("\n"):
			var w: PackedStringArray = line.strip_edges().split(" ", false)
			if w.size() < 15 or w[0] != "1":
				continue
			var id: String = " ".join(w.slice(14)).to_lower().trim_suffix(".dat")
			var mesh: Lbm.PartMesh = _library.mesh_for(_library.resolve(id))
			if mesh == null:
				continue
			var at: Transform3D = _ldr(Array(w.slice(2, 14)).map(func(v: String) -> float:
				return v.to_float())) * _library.moved_by(id)
			if absf((at.basis * Vector3.UP).y) < 0.99 \
					or not BrickLattice.is_square_to_grid(at.basis):
				continue
			parts += 1
			var box: AABB = _builder._rotated_bounds(mesh, at.basis)
			var footprint := Vector2i(int(round(box.size.x / 20.0)), int(round(box.size.z / 20.0)))
			var boxed: Vector3 = BrickLattice.snap_to_studs(at.origin, footprint)
			var phase: Variant = _builder._socket_phase(mesh, at.basis, footprint)
			var ruled: Vector3 = boxed if phase == null else Vector3(
				round((at.origin.x - (phase as Vector2).x) / 20.0) * 20.0 + (phase as Vector2).x,
				at.origin.y,
				round((at.origin.z - (phase as Vector2).y) / 20.0) * 20.0 + (phase as Vector2).y)
			var box_ok: bool = absf(boxed.x - at.origin.x) < 0.6 and absf(boxed.z - at.origin.z) < 0.6
			var rule_ok: bool = absf(ruled.x - at.origin.x) < 0.6 and absf(ruled.z - at.origin.z) < 0.6
			by_box += 1 if box_ok else 0
			by_rule += 1 if rule_ok else 0
			if box_ok and not rule_ok:
				worse.append(id)
	_check("across the stud grid as the three sets' files have them: %d of %d upright parts by "
		% [by_rule, parts] + "the sockets' rule, %d by the box alone; worse for none (%s)"
		% [by_box, ", ".join(worse)], parts > 100 and worse.is_empty() and by_rule > by_box)


## A part by its number, as a person takes one: a click in the search, the
## old text selected, the number typed, a click on the first tile.
func _take_by_number(bin: PartsBin, number: String) -> void:
	await _click(bin._search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type(number)
	await create_timer(0.4).timeout
	await _frames(4)
	if bin._grid.get_child_count() == 0:
		return
	await _click((bin._grid.get_child(0) as Control).get_global_rect().get_center())
	await _frames(4)


func _ldr(v: Array) -> Transform3D:
	var packed := PackedFloat64Array()
	for x: Variant in v:
		packed.append(float(x))
	return LdrModel.to_transform(packed)


func _put_ldr(part: String, colour: int, v: Array) -> void:
	var where: Transform3D = _ldr(v)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


## The timeline at the step whose caption begins [param caption], by its
## Start and Next buttons.
func _to_step(steps: StepsBar, caption: String) -> void:
	var named: Dictionary = steps.controls_by_name()
	await _click((named["steps_start"] as Button).get_global_rect().get_center())
	for _n: int in 14:
		if steps._caption.text.begins_with(caption):
			return
		await _click((named["steps_next"] as Button).get_global_rect().get_center())


func _part_id(part: String, colour: int = -1) -> int:
	for brick: BrickWorld.Brick in _model():
		if brick.part_id == part and (colour < 0 or brick.color_code == colour):
			return brick.id
	return 0


func _step(brick_id: int) -> int:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return brick.step if brick != null else -99


func _exports() -> void:
	print("  Export: a picture, and parts lists for BrickLink and Rebrickable")
	var exports: Exports = _main.get("_exports")
	var into: String = ProjectSettings.globalize_path("res://shots/handbuild/exports")
	DirAccess.make_dir_recursive_absolute(into)
	exports.folder = into
	var bar: ModelBar = _main.get("_bar")
	var shell: Shell = _main.get("_shell")
	bar._name.text = "Probe Bay"
	var file_menu: MenuButton = shell.menu("File")
	await _click(file_menu.get_global_rect().get_center())
	var menu: PopupMenu = file_menu.get_popup().get_node("export")
	_check("File, Export holds what it can write (%d), a Studio model among them" % menu.item_count,
		file_menu.get_popup().visible and menu.item_count >= 5
		and menu.get_item_text(menu.get_item_index(shell.menu_id("export_io")))
			== "BrickLink Studio model (.io)")
	await _shot("export_menu")
	file_menu.get_popup().hide()
	for name: String in ["probe_bay.png", "probe_bay_bricklink.xml", "probe_bay_rebrickable.csv",
			"probe_bay.io"]:
		DirAccess.remove_absolute(into.path_join(name))
	menu.id_pressed.emit(shell.menu_id("export_picture"))
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
	menu.id_pressed.emit(shell.menu_id("export_bricklink"))
	await _frames(3)
	var xml: String = FileAccess.get_file_as_string(into.path_join("probe_bay_bricklink.xml"))
	_check("the BrickLink wanted list names 3002 in BrickLink's blue, 2 of them",
		xml.contains("<ITEMID>3002</ITEMID>") and xml.contains("<COLOR>7</COLOR>")
		and xml.contains("<MINQTY>2</MINQTY>") and xml.begins_with("<INVENTORY>"))
	menu.id_pressed.emit(shell.menu_id("export_rebrickable"))
	await _frames(3)
	var csv: String = FileAccess.get_file_as_string(into.path_join("probe_bay_rebrickable.csv"))
	_check("the Rebrickable list is Part,Color,Quantity (%s)" % csv.strip_edges().replace("\n", " / "),
		csv.begins_with("Part,Color,Quantity\n3002,1,2"))
	# A Studio file: the model, a picture of it, and what Studio reads
	# about it, in a zip that opens here again as the same model.
	var bricks: Array = _model().map(func(b: BrickWorld.Brick) -> String:
		return "%s/%d" % [b.part_id, b.color_code])
	bricks.sort()
	menu.id_pressed.emit(shell.menu_id("export_io"))
	var io: String = into.path_join("probe_bay.io")
	for _n: int in 300:
		if FileAccess.file_exists(io):
			break
		await process_frame
	var zip := ZIPReader.new()
	var opened: bool = FileAccess.file_exists(io) and zip.open(io) == OK
	var members: PackedStringArray = zip.get_files() if opened else PackedStringArray()
	_check("BrickLink Studio model writes probe_bay.io, a zip of %s" % ", ".join(members),
		Array(members) == ["model.ldr", ".info", "errorPartList.err", "thumbnail.png"])
	if opened:
		var thumbnail := Image.new()
		_check("...its thumbnail a picture of the model (%s)" % (
			str(thumbnail.get_size()) if thumbnail.load_png_from_buffer(
				zip.read_file("thumbnail.png")) == OK else "not a picture"),
			thumbnail.get_size() == Exports.STUDIO_THUMBNAIL and thumbnail.get_pixel(2, 2).a < 0.05)
		zip.close()
	var read: Dictionary = StudioIo.read(FileAccess.get_file_as_bytes(io))
	var back: Array = LdrModel.parse(str(read["text"]), "probe_bay").flatten(_library.parts) \
		.map(func(p: LdrModel.Placement) -> String: return "%s/%d" % [p.part_id, p.color_code])
	back.sort()
	_check("...and its model.ldr is the model on the baseplate (%d parts)" % back.size(),
		back == bricks and not back.is_empty())
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
	var shell: Shell = _main.get("_shell")
	# One column beside the model, docked: nothing over the model, and the
	# model keeps most of the width (Main.MODEL_SHARE). The model tree and
	# the properties lay over its top corners, beside both columns, and it
	# had 53%; both columns open, with the tree and the properties down the
	# right, it had 41% of 1400 x 900.
	var cover: Dictionary = _main.call("model_cover")
	var across: float = root.get_visible_rect().size.x
	var model: Rect2 = cover["view"]
	_check("at this size nothing but the view cube is over the model (%d of %d points covered)"
		% [(cover["covered"] as Array).size(), int(cover["samples"])],
		(cover["covered"] as Array).is_empty())
	if DisplayServer.window_get_size() == Vector2i(1280, 720):
		_check("...and the model keeps %.0f%% of the width (columns %s)" % [
			100.0 * model.size.x / across, _main.get("_columns")], model.size.x >= across * 0.6)
	await _shot("laptop_1280x720")
	await _key(KEY_COMMA)
	var controls: ControlsDialog = _main.get("_controls")
	_check(", opens the controls list", controls.visible)
	await _shot("controls_1280x720")
	await _key(KEY_ESCAPE)
	_check("Escape closes it", not controls.visible)
	DisplayServer.window_set_size(was)
	await _frames(20)
	# Opened with the pointer resting on a button, its tooltip up: the
	# tooltip took the first Escape for itself on the web. (After the window
	# is put back: a display that will not resize the window still reports
	# the size asked for, and every click aimed by it lands short.)
	await _move((shell.toolbar._buttons["undo"] as Control).get_global_rect().get_center())
	await _key(KEY_F1)
	for _n: int in 90:
		await process_frame
	_check("F1 opens the controls list", controls.visible)
	await _key(KEY_ESCAPE)
	_check("...and Escape closes it with a tooltip up", not controls.visible)
	await _from_menu("Help", "keys")
	_check("Help, Keys and controls opens it too", controls.visible)
	await _key(KEY_ESCAPE)
	# The toolbar in views of its own the width of a laptop at 1280 x 720
	# (1391 units at 0.92) and of a phone (about 720): all of it on the
	# laptop, and on the phone the groups the menus also hold fold away and
	# the tools stay.
	for wide: int in [1391, 720]:
		var narrow := SubViewport.new()
		narrow.size = Vector2i(wide, 120)
		root.add_child(narrow)
		var small := Toolbar.new()
		small.shell = shell
		small.set_anchors_preset(Control.PRESET_TOP_WIDE)
		narrow.add_child(small)
		for _n: int in 10:
			await process_frame
		var shown: Array = small._buttons.keys().filter(func(n: String) -> bool:
			return (small._buttons[n] as Control).visible)
		var fits: bool = small._row.get_combined_minimum_size().x <= wide
		var tools: bool = shown.has("mode_select") and shown.has("mode_delete") \
			and shown.has("save")
		if wide > 1000:
			_check("at 1280 x 720 the whole toolbar is there (%d of %d buttons, %.0f of %d)" % [
				shown.size(), small._buttons.size(), small._row.get_combined_minimum_size().x,
				wide], fits and shown.size() == small._buttons.size())
		else:
			_check("on a phone the toolbar fits (%.0f of %d) with every tool on it (%d buttons)" % [
				small._row.get_combined_minimum_size().x, wide, shown.size()], fits and tools)
		narrow.queue_free()
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


## What a first-time builder hit on brickworks.diy, the second round
## (2026-10-12): each check here failed there.
## View, Floor, as a person uses it: a submenu with the sizes, the grid
## floor, no floor and the colours, ticked where the model is; each choice
## one undo, the model never moving; and the same in the properties with
## nothing selected.
func _floor_menu() -> void:
	print("  View, Floor")
	var shell: Shell = _main.get("_shell")
	var floor_layer: FloorLayer = _main.get("_floor")
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	await _frames(3)
	var view: MenuButton = shell.menu("View")
	await _click(view.get_global_rect().get_center())
	var popup: PopupMenu = view.get_popup()
	var sub: PopupMenu = popup.find_child("floor", false, false) as PopupMenu
	_check("View opens, with a Floor submenu", popup.visible and sub != null)
	if sub == null:
		popup.hide()
		return
	var names: Array = []
	for index: int in sub.item_count:
		names.append(sub.get_item_text(index))
	_check("...offering %s" % ", ".join(PackedStringArray(names)),
		names.has("Baseplate 16 × 16") and names.has("Baseplate 48 × 48")
		and names.has("Grid floor") and names.has("No floor")
		and names.has("Baseplate colour") and names.has("The baseplate is part of the model"))
	sub.about_to_popup.emit()
	var at_32: int = sub.get_item_index(shell.menu_id("floor_32"))
	_check("...with the 32 x 32 ticked, as the model stands", sub.is_item_checked(at_32))
	await _shot("floor_menu")
	var before: String = str((_model()[0] as BrickWorld.Brick).transform)
	var depth: int = _builder.history_depth()
	sub.id_pressed.emit(shell.menu_id("floor_none"))
	popup.hide()
	await _frames(5)
	_check("No floor takes the baseplate away (%s, %d plates)" % [_store.model_floor.words(),
		_store.scenery.size()], _store.model_floor.kind == ModelFloor.NONE
		and _store.scenery.is_empty())
	_check("...in one step of the history, the model where it was",
		_builder.history_depth() == depth + 1
		and str((_model()[0] as BrickWorld.Brick).transform) == before)
	await _shot("floor_none")
	sub.id_pressed.emit(shell.menu_id("floor_48"))
	await _frames(3)
	var colours: PopupMenu = sub.find_child("floor_colour", false, false) as PopupMenu
	_check("Baseplate colour is its own submenu", colours != null)
	if colours != null:
		colours.id_pressed.emit(shell.menu_id("floor_colour_19"))
		await _frames(3)
	var plate: BrickWorld.Brick = _world.get_brick(_store.scenery.keys()[0]) \
		if not _store.scenery.is_empty() else null
	_check("48 x 48, then Tan: one Tan Baseplate 48 x 48 under it (%s)" % _store.model_floor.words(),
		plate != null and plate.part_id == "4186" and plate.color_code == 19)
	await _shot("floor_tan_48")
	await _key(KEY_Z, true)
	_check("Ctrl-Z takes back the colour alone (%s)" % _store.model_floor.words(),
		_store.model_floor.is_plate() and _store.model_floor.across == 48
		and _store.model_floor.colour != 19)
	await _key(KEY_Z, true)
	_check("...and again, back to no floor", _store.model_floor.kind == ModelFloor.NONE)
	# The model's own properties: nothing selected, the floor and its
	# colour under the header, and "Part of the model".
	_builder.clear_selection()
	await _show_column(_column_of(shell.inspector))
	await _frames(10)
	var picker: FloorPicker = shell.inspector.floor_picker
	_check("with nothing selected, the properties say what the model stands on",
		picker.is_visible_in_tree() or not shell.inspector.is_open())
	picker.show_floor(_store.model_floor, false)
	var choose: OptionButton = picker._kind
	choose.select(1)
	choose.item_selected.emit(1)
	await _frames(5)
	_check("...and choosing Baseplate 32 x 32 there lays it (%d plate)" % _store.scenery.size(),
		_store.model_floor.is_plate() and _store.scenery.size() == 1)
	picker._part.button_pressed = true
	await _frames(5)
	_check("...and Part of the model makes it a part (%d scenery, own %s)" % [
		_store.scenery.size(), floor_layer.has_own_plate()],
		_store.scenery.is_empty() and floor_layer.has_own_plate())
	_check("...which View, Floor ticks", shell.ticked("floor_part") == 1)
	await _key(KEY_Z, true)
	_check("...and Ctrl-Z makes it the floor again", not floor_layer.has_own_plate()
		and _store.scenery.size() == 1)


func _first_timer() -> void:
	print("  what a first-time builder hit, round two")
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3001", 1, Vector3(60, 24, 20))
	_put("3003", 14, Vector3(0, 24, -100))
	await _frames(3)
	_camera.frame(AABB(Vector3(-200, 0, -200), Vector3(400, 80, 400)))
	await _frames(20)

	await _edit_cut()
	await _hide_says_its_keys()
	await _menus_show_the_real_keys()
	await _the_palette_stays_put()
	await _the_note_says_the_selection()
	await _undo_says_what()
	await _right_click_a_part()
	await _ask_claude_about_a_part()
	await _drag_from_the_bin()
	await _the_grid_has_room()
	await _an_untouched_example()


## Patterns (docs/APP_UX.md, B6): a fence of 12 posts in 5 actions, from
## one post: a click on it, Ctrl-D, a click two studs over, "11x" and Enter.
## A ring of 16 on turntables in 6, from one wall piece on a turntable: a
## click, a Shift-click, Ctrl+Shift+D, Round, "16" and Enter. Each counted
## as typed_moves_probe counts (a click, a key, a number typed); each copy
## where it should be, none in another's room, the whole one Ctrl+Z.
func _patterns() -> void:
	print("  patterns: a fence of posts, a ring on turntables")
	var shell: Shell = _main.get("_shell")
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.set_mode("select")
	_main.call("clear_model")
	await _frames(4)
	# One post, five bricks tall, on the ground.
	_put("2453b", 4, Vector3(-210, 120, 10))
	await _frames(3)
	_camera.frame(AABB(Vector3(-240, 0, -80), Vector3(500, 140, 160)))
	await _frames(30)
	await _shot("pattern_fence_before")
	var acts: int = 0
	await _click(_screen(Vector3(-210, 100, 10)))
	acts += 1
	_check("a click selects the post", _builder.selection.size() == 1)
	await _key(KEY_D, true)
	acts += 1
	_check("Ctrl-D holds a copy", _builder.is_carrying())
	await _click(_screen(Vector3(-170, 0, 10)))
	acts += 1
	_check("a click two studs over puts it down (%d posts), another in hand" % _count(),
		_count() == 2 and _builder.is_carrying())
	var depth: int = _builder.history_depth()
	await _type("11x")
	acts += 1
	var meaning: Label = verbs.typed.find_child("Meaning", true, false)
	_check("“11x” reads as the row: %s" % meaning.text,
		verbs.typed.is_open() and meaning.text.contains("11 in the row"))
	await _shot("pattern_fence_typed")
	await _key(KEY_ENTER)
	acts += 1
	await _frames(4)
	var posts: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "2453b")
	var xs: Array = posts.map(func(b: BrickWorld.Brick) -> float: return b.transform.origin.x)
	xs.sort()
	var spaced: bool = xs.size() == 12
	for n: int in xs.size():
		spaced = spaced and absf(float(xs[n]) - (-210.0 + 40.0 * n)) < 0.01
	_check("a fence of 12 posts two studs apart (%s)" % str(xs), spaced)
	_check("...in %d actions (bar: 5)" % acts, acts <= 5)
	_check("...none in another's room", _none_overlap(posts))
	_check("...the whole one step to undo (%d steps since the copy)" % (_builder.history_depth()
		- depth + 1), _builder.history_depth() == depth)
	await _shot("pattern_fence_after")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z takes every copy back (%d posts)" % _count(), _count() == 1)
	await _key(KEY_Z, true, true)
	_check("...and redo puts all 11 back (%d posts)" % _count(), _count() == 12)
	if _builder.is_carrying():
		verbs.put_away()

	# "/4": the gap cut in four.
	_main.call("clear_model")
	_put("2453b", 4, Vector3(-210, 120, 10))
	await _frames(3)
	await _click(_screen(Vector3(-210, 100, 10)))
	await _key(KEY_D, true)
	await _click(_screen(Vector3(-90, 0, 10)))
	await _type("/4")
	await _key(KEY_ENTER)
	var between: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "2453b").map(func(b: BrickWorld.Brick) -> float:
			return b.transform.origin.x)
	between.sort()
	_check("“/4” puts three between, the gap cut in four (%s)" % str(between),
		between.size() == 5 and absf(float(between[1]) + 180.0) < 0.01
		and absf(float(between[3]) + 120.0) < 0.01)
	if _builder.is_carrying():
		verbs.put_away()

	# A row through a brick: the copy with no room said red, and none put.
	_main.call("clear_model")
	_put("2453b", 4, Vector3(-210, 120, 10))
	_put("3005", 1, Vector3(110, 24, 10))
	await _frames(3)
	await _click(_screen(Vector3(-210, 100, 10)))
	await _key(KEY_D, true)
	await _click(_screen(Vector3(-170, 0, 10)))
	var before: int = _count()
	await _type("11x")
	_check("a row through a brick is said red: %s" % meaning.text,
		meaning.text.contains("no room"))
	await _key(KEY_ENTER)
	_check("...and Enter puts none of it down (%d parts, %d before)" % [_count(), before],
		_count() == before and verbs.typed.is_open())
	await _key(KEY_ESCAPE)
	if _builder.is_carrying():
		verbs.put_away()

	# A ring of 16: a 1 x 2 brick on a 2 x 2 turntable, on a 16 x 16 plate.
	_main.call("clear_model")
	await _frames(3)
	var plate: int = await _drop("91405", 71, Vector3(0, 0, 0), 0)
	var turntable: int = await _drop("3680c02", 0, Vector3(140, 0, 0), 0)
	var wall: int = await _drop("3004", 4, Vector3(150, 0, 0), 1)
	_check("a plate, a turntable on it and a brick on that (%d, %d, %d)" % [plate, turntable,
		wall], plate != 0 and turntable != 0 and wall != 0)
	_camera.frame(AABB(Vector3(-200, 0, -200), Vector3(400, 80, 400)))
	await _frames(30)
	await _shot("pattern_ring_before")
	acts = 0
	var on_wall: Vector2 = _screen(_world.get_brick(wall).transform.origin + Vector3(0, -6, 0))
	await _click(on_wall)
	acts += 1
	var on_turntable: Vector2 = _screen(_world.get_brick(turntable).transform.origin
		+ Vector3(-10, -4, 10))
	await _shift_click(on_turntable)
	acts += 1
	_check("a click and a Shift-click select the brick and its turntable (%s)"
		% str(_builder.selection.keys()), _builder.selection.has(wall)
		and _builder.selection.has(turntable) and _builder.selection.size() == 2)
	await _key(KEY_D, true, true)
	acts += 1
	var dialog: PatternDialog = shell.pattern_dialog
	_check("Ctrl+Shift+D opens Pattern", dialog.is_open())
	var round_button: Button = dialog.controls_by_name()["pattern_round"]
	await _click(Vector2(dialog.position) + round_button.get_global_rect().get_center())
	acts += 1
	_check("Round is chosen (%s), round %s" % [dialog.kind, dialog.page_state()["said"]],
		dialog.kind == "round" and str(dialog.page_state()["said"]).contains("stands on"))
	await _type("16")
	acts += 1
	await _frames(4)
	_check("16 in all, shown first: %s" % dialog.page_state()["said"],
		int(dialog.page_state()["in_all"]) == 16 and bool(dialog.page_state()["can_put"]))
	await _shot("pattern_ring_dialog")
	var parts_before: int = _count()
	depth = _builder.history_depth()
	await _key(KEY_ENTER)
	acts += 1
	await _frames(4)
	var rings: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.part_id == "3680c02")
	var round_ok: bool = rings.size() == 16
	var angles: Array = []
	for brick: BrickWorld.Brick in rings:
		var at: Vector3 = brick.transform.origin
		round_ok = round_ok and absf(Vector2(at.x, at.z).length() - 140.0) < 0.05
		angles.append(snappedf(fposmod(rad_to_deg(atan2(-at.z, at.x)), 360.0), 0.01))
	angles.sort()
	for n: int in angles.size():
		round_ok = round_ok and absf(float(angles[n]) - 22.5 * n) < 0.05
	_check("a ring of 16 turntables, each with its brick, 22.5° apart (%d parts, %s)"
		% [_count(), str(angles)], round_ok and _count() == parts_before + 30)
	_check("...in %d actions (bar: 6)" % acts, acts <= 6)
	_check("...none in another's room", _none_overlap(_model()))
	_check("...one step to undo", _builder.history_depth() == depth + 1)
	await _shot("pattern_ring_after")
	await _key(KEY_Z, true)
	_check("one Ctrl+Z takes the ring back (%d parts)" % _count(), _count() == parts_before)
	_check("Edit has Pattern… with its key (%s)" % shell.key_words("pattern"),
		shell.menu("Edit").get_popup().get_item_index(shell.menu_id("pattern")) >= 0)

	# Along a hose: a tube laid between two Technic bricks, and a 1 x 1
	# brick over its start copied along it, two studs apart.
	_main.call("clear_model")
	_put("3700", 15, Vector3(-150, 24, 10))
	_put("3700", 15, Vector3(150, 24, 10))
	await _frames(3)
	var holes: Array = []
	for anchor: Flex.Anchor in Flex.anchors_in(_world, _library, "pneumatic_tube"):
		if not holes.any(func(a: Flex.Anchor) -> bool: return a.brick == anchor.brick):
			holes.append(anchor)
	var flex_tool: FlexTool = _main.get("_flex")
	var laid: Flex.Laid = await flex_tool.lay("pneumatic_tube", holes, [], 0) \
		if holes.size() == 2 else null
	var items: Dictionary = Flex.items_in(_world)
	var line := PackedVector3Array()
	for path: String in items:
		var pieces: Array = (items[path]["bricks"] as Array).map(
			func(b: BrickWorld.Brick) -> Dictionary: return {"part": b.part_id, "at": b.transform})
		line = Flex.centreline(str(items[path]["kind"]), pieces, Vector3(-150, 24, 10))
	_check("a tube is laid between them (%d points along it)" % line.size(),
		laid != null and line.size() >= 2)
	if line.size() < 2:
		return
	_put("3005", 14, line[0] + Vector3(0, 40, 0))
	await _frames(3)
	_select_only([_part_id("3005")])
	_camera.frame(AABB(Vector3(-200, 0, -120), Vector3(400, 120, 240)))
	await _frames(20)
	await _key(KEY_D, true, true)
	var hose_button: Button = dialog.controls_by_name()["pattern_path"]
	await _click(Vector2(dialog.position) + hose_button.get_global_rect().get_center())
	await _type("4")
	await _frames(4)
	_check("Along a hose: %s" % dialog.page_state()["said"], dialog.kind == "path"
		and bool(dialog.page_state()["can_put"]))
	await _shot("pattern_hose_dialog")
	await _key(KEY_ENTER)
	await _frames(4)
	var along: Array = []
	var off: Array = []
	for brick: BrickWorld.Brick in _model():
		if brick.part_id != "3005":
			continue
		var nearest: float = INF
		var at: float = 0.0
		var run: float = 0.0
		for n: int in line.size() - 1:
			var span: Vector3 = line[n + 1] - line[n]
			var t: float = clampf((brick.transform.origin - line[n]).dot(span)
				/ maxf(span.length_squared(), 1e-9), 0.0, 1.0)
			var gap: float = (line[n] + span * t).distance_to(brick.transform.origin)
			if gap < nearest:
				nearest = gap
				at = run + span.length() * t
			run += span.length()
		along.append(snappedf(at, 0.1))
		off.append(snappedf(nearest, 0.1))
	along.sort()
	var even: bool = along.size() == 4
	for n: int in range(1, along.size()):
		even = even and absf(float(along[n]) - float(along[n - 1]) - 40.0) < 2.0
	for gap: float in off:
		even = even and absf(gap - 40.0) < 2.0
	_check("...four bricks, two studs apart along the tube and as far off it (%s, %s)"
		% [str(along), str(off)], even)
	await _shot("pattern_hose_after")


## A part dropped from above at [param at] (x and z), turned
## [param turns] quarters, onto whatever is under it, as a click there puts
## it: its id, or 0.
func _drop(part: String, colour: int, at: Vector3, turns: int) -> int:
	_main.call("_on_part_chosen", part)
	for _n: int in 600:
		if _library.mesh_for(part) != null:
			break
		await process_frame
	_builder.held_color = colour
	_builder.held_rotation = turns
	_builder.update_preview(at + Vector3(0, 2000, 0), Vector3.DOWN)
	var made: int = _builder.place()
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.set_mode("select")
	_builder.hide_preview()
	await _frames(3)
	return made


## Whether every part has room where it stands, by the rule a part put
## down meets: each taken out of the lattice and asked again.
func _none_overlap(bricks: Array) -> bool:
	for brick: BrickWorld.Brick in bricks:
		_builder.lattice.release(brick.id)
		var fits: bool = _builder.room_for(brick.part_id, brick.transform, false)
		_builder.register(brick.id, brick.part_id, brick.transform)
		if not fits:
			print("    %s at %s has no room: %d in the way" % [brick.part_id,
				str(brick.transform.origin), _builder.room_blocker])
			return false
	return true


## Edit, Cut takes the selection off the model. Two commands shared the
## name "cut" and the cut-away's replaced it, so Edit, Cut sliced the model
## open with a plane instead.
func _edit_cut() -> void:
	var shell: Shell = _main.get("_shell")
	var red: int = _bricks_near(Vector3(-60, 0, 20))[0]
	_select_only([red])
	await _frames(2)
	var edit: MenuButton = shell.menu("Edit")
	await _click(edit.get_global_rect().get_center())
	var popup: PopupMenu = edit.get_popup()
	var cut_at: int = -1
	for index: int in popup.item_count:
		if popup.get_item_text(index) == "Cut":
			cut_at = index
	_check("Edit has Cut, by Ctrl+X (%s)" % (OS.get_keycode_string(
		popup.get_item_accelerator(cut_at)) if cut_at >= 0 else "none"), cut_at >= 0
		and popup.get_item_accelerator(cut_at) == (KEY_MASK_CMD_OR_CTRL | KEY_X))
	Carry.clipboard = []
	if cut_at >= 0:
		popup.id_pressed.emit(popup.get_item_id(cut_at))
	popup.hide()
	await _frames(4)
	_check("Edit, Cut takes the selection off the model (%d parts)" % _count(), _count() == 2)
	_check("...onto the clipboard (%d)" % Carry.clipboard.size(), Carry.clipboard.size() == 1)
	_check("...and does not cut the model away", not _world.is_cut())
	if _world.is_cut():
		shell.see_inside.set_cut(false)
	await _key(KEY_Z, true)


## Hiding says the keys that bring it back. "H with nothing selected" was
## the Pan tool.
func _hide_says_its_keys() -> void:
	var shell: Shell = _main.get("_shell")
	var verbs: EditVerbs = _main.get("_verbs")
	_select_only(_bricks_near(Vector3(60, 0, 20)))
	await _frames(2)
	await _key(KEY_H, true)
	var said: String = str(shell.status.fields()["message"])
	_check("Ctrl-H says what shows it again (%s)" % said, said.contains(Keymap.listed("show_all"))
		and said.contains(Keymap.listed("hide") + " with nothing selected") and not said.contains(" H with"))
	await _key(KEY_H)
	_check("...and H, the Pan tool, is not one of them", verbs.mode == "pan"
		and _model().any(func(b: BrickWorld.Brick) -> bool: return b.hidden))
	await _key(KEY_ESCAPE)
	await _key_alt(KEY_H)


## The keys the menus show are the keys that do it, written as a person
## writes them. View said Q and E turn the model (Shift-Q and Shift-E do; Q
## takes the last part) and that orthographic is "QuoteLeft".
func _menus_show_the_real_keys() -> void:
	var shell: Shell = _main.get("_shell")
	var verbs: EditVerbs = _main.get("_verbs")
	var engine_names: PackedStringArray = []
	var wrong: PackedStringArray = []
	var allowed := RegEx.create_from_string("^(F[0-9]+|Enter|Delete|Ctrl|Shift|Alt|Command|Cmd|.)$")
	for menu: MenuButton in (_main.get("_bar") as ModelBar).menus.get_children():
		var list: PopupMenu = menu.get_popup()
		for index: int in list.item_count:
			var accel: int = list.get_item_accelerator(index)
			if accel == 0:
				continue
			var shown: String = OS.get_keycode_string(accel)
			for part: String in shown.split("+"):
				if allowed.search(part) == null:
					engine_names.append("%s: %s" % [list.get_item_text(index), shown])
			var id: int = list.get_item_id(index)
			var name: String = shell._ids[id] if id >= 0 and id < shell._ids.size() else ""
			# The key that does it is the keymap's (Keymap.key_of): the tools'
			# keys are there, not in the command table (APP_UX A11).
			var bound: int = Keymap.key_of(name) if not name.is_empty() else accel
			if (accel & ~KEY_CODE_MASK) != (bound & ~KEY_CODE_MASK):
				wrong.append("%s: %s" % [list.get_item_text(index), shown])
	_check("no menu writes a key by the engine's name for it (%s)" % ", ".join(engine_names),
		engine_names.is_empty())
	_check("...and every key shown has the modifiers it is pressed with (%s)" % ", ".join(wrong),
		wrong.is_empty())
	var view: PopupMenu = shell.menu("View").get_popup()
	var left_at: int = view.get_item_index(shell.menu_id("turn_left"))
	_check("View says Shift+Q turns the model left (%s)" % OS.get_keycode_string(
		view.get_item_accelerator(left_at)),
		OS.get_keycode_string(view.get_item_accelerator(left_at)) == "Shift+Q")
	var ortho_at: int = view.get_item_index(shell.menu_id("ortho"))
	_check("...and orthographic is ` (%s), as the toolbar's tip writes it (%s)" % [
		OS.get_keycode_string(view.get_item_accelerator(ortho_at)), shell.key_words("ortho")],
		shell.key_words("ortho") == "`" and OS.get_keycode_string(
			view.get_item_accelerator(ortho_at)).length() == 1)
	var turned: int = _bricks_near(Vector3(-60, 0, 20))[0]
	var facing: Basis = _world.get_brick(turned).transform.basis
	await _key(KEY_Q, false, true)
	_check("...and Shift+Q does turn it, and puts no part in hand", verbs.mode != "place"
		and _world.get_brick(turned) != null
		and not _world.get_brick(turned).transform.basis.is_equal_approx(facing))
	await _key(KEY_E, false, true)
	var was_square: bool = _camera.is_square_on()
	await _key(KEY_QUOTELEFT)
	_check("...and ` puts the view square on", _camera.is_square_on() != was_square)
	await _key(KEY_QUOTELEFT)
	await _click(shell.menu("View").get_global_rect().get_center())
	await _frames(4)
	await _shot("first_timer_view_menu")
	view.hide()
	await _frames(3)


## Dragging a part from the bin onto the model did nothing, and the part's
## tooltip followed the pointer. Now the part is picked up and put down
## where it is let go, as in Studio and Mecabricks.
func _drag_from_the_bin() -> void:
	var bin: PartsBin = _main.get("_bin")
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	bin._search.text = "3003"
	bin._run_search("3003")
	await _frames(10)
	var cell: Button = null
	for child: Node in bin._grid.get_children():
		if str(child.get_meta("part", "")) == "3003":
			cell = child
	_check("the bin offers Brick 2 x 2 to drag", cell != null)
	if cell == null:
		return
	var tip: String = cell.tooltip_text
	var from: Vector2 = cell.get_global_rect().get_center()
	var to: Vector2 = _screen(Vector3(-100, 0, -140))
	var before: int = _count()
	await _move(from)
	_button(from, true)
	await _frames(2)
	var tip_during: String = "unread"
	for step: int in range(1, 13):
		var event := InputEventMouseMotion.new()
		event.position = _as_event(from.lerp(to, step / 12.0))
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		await _frames(2)
		if step == 6:
			tip_during = cell.tooltip_text
	await _frames(3)
	_check("dragged over the model, its ghost follows the pointer (%s)" % _builder.held_part,
		_builder.held_part == "3003" and _builder.has_preview())
	_check("...with no tooltip along with it (\"%s\")" % tip_during, tip_during.is_empty())
	await _shot("first_timer_bin_drag")
	_button(to, false)
	await _frames(6)
	var landed: Array = _bricks_near(Vector3(-100, 0, -140)).filter(func(b: int) -> bool:
		return _world.get_brick(b).part_id == "3003")
	_check("let go, it is put down there (%d parts, was %d)" % [_count(), before],
		_count() == before + 1 and landed.size() == 1)
	_check("...and the part keeps its tooltip", cell.tooltip_text == tip)
	await _key(KEY_ESCAPE)


## A right click on a part did nothing. Now a menu of what a person
## reaches for, each the command Edit or Build has.
func _right_click_a_part() -> void:
	var shell: Shell = _main.get("_shell")
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	var blue: int = _bricks_near(Vector3(60, 0, 20))[0]
	var on_blue: Vector2 = _screen(Vector3(60, 24, 20))
	await _move(on_blue)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		event.position = _as_event(on_blue)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)
	var menu: PopupMenu = shell.get("context")
	var words: PackedStringArray = []
	if menu != null:
		for index: int in menu.item_count:
			if not menu.is_item_separator(index):
				words.append(menu.get_item_text(index))
	_check("a right click on a part opens its menu (%s)" % ", ".join(words),
		menu != null and menu.visible)
	_check("...on that part, selected", _builder.selection.keys() == [blue])
	_check("...with the verbs a person reaches for", ", ".join(words).begins_with(
		"Ask Claude about this…, Select everything joined to it, Select the same part, "
		+ "Select the same colour, Hide, Show only the selection, Copy, Duplicate, Delete, "
		+ "Paint with")
		and words.has("Copy") and words.has("Delete") and words.has("Make a sub-assembly…")
		and words.has("Properties"))
	await _shot("first_timer_part_menu")
	if menu == null:
		return
	var hide_id: int = menu.get_item_id(int(shell.call("item_index", menu, "hide")))
	menu.id_pressed.emit(hide_id)
	menu.hide()
	await _frames(4)
	_check("...and Hide there hides it", _world.get_brick(blue).hidden)
	await _key_alt(KEY_H)


## Ask Claude about this…, on the menu of a part and on Ctrl+K: the
## assistant's panel opens with a chip saying what the next request is about,
## and the chip's cross takes it back to the whole model.
func _ask_claude_about_a_part() -> void:
	var shell: Shell = _main.get("_shell")
	var chat: ChatPanel = _main.get("_chat")
	var dock: SideDock = _main.get("_chat_dock")
	var assistant: Assistant = _main.get("_assistant")
	# The parts bin as it was: a narrow window folds one dock for the other.
	var bin_dock: SideDock = _main.get("_bin_dock")
	var bin_was: bool = bin_dock.is_open()
	dock.set_open(false)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	var blue: int = _bricks_near(Vector3(60, 0, 20))[0]
	var on_blue: Vector2 = _screen(Vector3(60, 24, 20))
	await _move(on_blue)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = down
		event.position = _as_event(on_blue)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)
	var menu: PopupMenu = shell.get("context")
	_check("the menu on a part offers Ask Claude about this…", menu != null and menu.visible
		and menu.get_item_text(0) == "Ask Claude about this…"
		and not menu.is_item_disabled(0))
	if menu == null:
		return
	menu.id_pressed.emit(menu.get_item_id(int(shell.call("item_index", menu, "ask_claude"))))
	menu.hide()
	await _frames(6)
	_check("...which opens the assistant's panel", dock.is_open())
	_check("...with a chip saying what the next request is about (\"%s\")"
		% chat._chip_words.text, chat._chip.visible
		and chat._chip_words.text == "About 1 selected part")
	_check("...and the assistant is asked about that part, its room round it",
		assistant.focus != null and assistant.focus.ids.keys() == [blue]
		and assistant.focus.region.encloses(assistant.focus.box))
	_check("...and the brief box says what to ask", chat._input.placeholder_text
		== ChatPanel.ABOUT_PLACEHOLDER)
	await _shot("ask_claude_chip")
	# Two parts, and the key instead of the menu.
	var red: int = _bricks_near(Vector3(-60, 0, 20))[0]
	# Picked in the model, which takes the keys back from the brief box.
	chat.get_viewport().gui_release_focus()
	_select_only([blue, red])
	await _frames(2)
	_check("Tools has it, with its key, %s" % shell.key_words("ask_claude"),
		shell.key_words("ask_claude") == "Ctrl+K")
	await _key(KEY_K, true)
	await _frames(4)
	_check("Ctrl+K asks about the two (\"%s\")" % chat._chip_words.text,
		chat._chip_words.text == "About 2 selected parts" and assistant.focus != null
		and assistant.focus.ids.size() == 2)
	# A change to them lands as a card with the two of them before and after.
	var painted: Variant = await assistant.use_tool("edit_selection", {
		"recolor": [{"bricks": [blue, red], "color": 14}]})
	await _frames(6)
	var card: Node = null
	for child: Node in chat._log.get_children():
		if child.name == "changed":
			card = child
	_check("a change to them is one undo step and a card, Before and After: %s"
		% str(painted).substr(0, 60), card != null
		and card.find_child("Before", true, false) is TextureRect
		and card.find_child("After", true, false) is TextureRect
		and _world.get_brick(blue).color_code == 14
		and _builder.history_words(1)[0].begins_with("Claude's change to the selection"))
	await _shot("ask_claude_before_after")
	_builder.undo()
	await _frames(2)
	_check("...and one undo takes it back", _world.get_brick(blue).color_code == 1
		and _world.get_brick(red).color_code == 4)
	chat._chip_clear.pressed.emit()
	await _frames(2)
	_check("...and the chip's cross takes it back to the whole model",
		not chat._chip.visible and assistant.focus == null)
	_builder.clear_selection()
	dock.set_open(false)
	bin_dock.set_open(bin_was)
	await _key(KEY_ESCAPE)


## Choosing a part moved the palette 19 px (its note wrapped to a second
## line), so the next colour clicked was a row off.
func _the_palette_stays_put() -> void:
	var bin: PartsBin = _main.get("_bin")
	var dock: SideDock = _main.get("_bin_dock")
	dock.set_open(true)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	# A colour in hand and no part: the note one line long, as it was
	# before a part was chosen.
	bin._selected_part = ""
	bin._on_colour(15)
	bin._mark_swatches()
	# Slope 45 2 x 4, whose colours are all known: its note ran to two
	# lines, as it did on the site.
	bin._search.text = "3037"
	bin._run_search("3037")
	await _frames(10)
	var white: Control = bin._swatches.get(15)
	var cell: Button = null
	for child: Node in bin._grid.get_children():
		if str(child.get_meta("part", "")) == "3037":
			cell = child
	_check("the bin shows a white swatch and Slope 45 2 x 4 to choose",
		white != null and cell != null)
	if white == null or cell == null:
		return
	var was: float = white.get_global_rect().position.y
	var note_was: String = bin._colour_note.text
	await _click(cell.get_global_rect().get_center())
	await _frames(10)
	_check("choosing a part leaves the palette where it was (%.0f to %.0f px; \"%s\" to \"%s\")"
		% [was, white.get_global_rect().position.y, note_was, bin._colour_note.text],
		is_equal_approx(white.get_global_rect().position.y, was))
	await _shot("first_timer_part_chosen")
	await _key(KEY_ESCAPE)


## With a brick selected the note under the palette described the part in
## hand, while a colour clicked painted the brick.
func _the_note_says_the_selection() -> void:
	var bin: PartsBin = _main.get("_bin")
	(_main.get("_bin_dock") as SideDock).set_open(true)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	await _frames(4)
	var white: Control = bin._swatches.get(15)
	var was: float = white.get_global_rect().position.y
	var red: int = _bricks_near(Vector3(-60, 0, 20))[0]
	await _click(_screen(Vector3(-60, 24, 20)))
	await _frames(6)
	_check("a brick selected: the note under the palette describes it (%s)" % bin._colour_note.text,
		_builder.selection.keys() == [red]
		and bin._colour_note.text.begins_with("Brick 2 x 4 in Red, selected"))
	_check("...and the palette has not moved (%.0f px)" % white.get_global_rect().position.y,
		is_equal_approx(white.get_global_rect().position.y, was))
	await _click(white.get_global_rect().get_center())
	await _frames(6)
	_check("...and the colour clicked paints it, and the note says so (%s)" % bin._colour_note.text,
		_world.get_brick(red).color_code == 15
		and bin._colour_note.text.begins_with("Brick 2 x 4 in White, selected"))
	await _shot("first_timer_selection_note")
	await _key(KEY_Z, true)
	await _key(KEY_ESCAPE)
	_check("nothing selected, it is the colour in hand again (%s)" % bin._colour_note.text,
		not bin._colour_note.text.contains("selected"))


## Undo said nothing, and undoing a sub-assembly made changed nothing a
## person could see either.
func _undo_says_what() -> void:
	var shell: Shell = _main.get("_shell")
	var verbs: EditVerbs = _main.get("_verbs")
	_select_only(_bricks_near(Vector3(-60, 0, 20)) + _bricks_near(Vector3(60, 0, 20)))
	await _frames(2)
	verbs.name_submodel("Body")
	await _frames(3)
	await _key(KEY_Z, true)
	var said: String = str(shell.status.fields()["message"])
	_check("Ctrl-Z says what it undid (%s)" % said,
		said.begins_with("undid: ") and said.contains("Body"))
	await _key(KEY_Z, true, true)
	said = str(shell.status.fields()["message"])
	_check("...and Ctrl-Shift-Z what it put back (%s)" % said,
		said.begins_with("redid: ") and said.contains("Body"))
	shell.run("undo")
	said = str(shell.status.fields()["message"])
	_check("...and so does Edit, Undo (%s)" % said, said.begins_with("undid: "))


## The parts grid had room for about two rows at 1440 x 900: the palette,
## the model tree and an empty Properties took the column. And whatever
## moves to make room, the palette must not: a part taken into hand, a brick
## selected or the model tree opened left it where it was, so a colour is
## clicked where it was seen.
func _the_grid_has_room() -> void:
	var bin: PartsBin = _main.get("_bin")
	var shell: Shell = _main.get("_shell")
	var dock: SideDock = _main.get("_bin_dock")
	var named: String = "%dx%d" % [DisplayServer.window_get_size().x,
		DisplayServer.window_get_size().y]
	if _bricks_near(Vector3(-60, 0, 20)).is_empty():
		_put("3001", 4, Vector3(-60, 24, 20))
	dock.set_open(true)
	# The properties are down the right, a tab beside the assistant's,
	# which the step before left showing: brought back by their rail where
	# both columns show. Where they take turns, the bin keeps its column.
	var both: bool = _main.get("_columns") == "wide"
	if both and _main.get("_props_dock") != null:
		await _show_column("_props_dock")
	shell.outliner.set_open(false)
	shell.inspector.set_open(true)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	bin._search.text = ""
	bin.show_category("All")
	await _frames(20)
	# A cell and the space under it.
	var rows: float = bin._scroll.size.y / 88.0
	# Four rows and more at 1440 x 900, where it had two; at 1920 x 1080
	# the window draws everything a fifth larger, and at 1280 x 720 there
	# is less column to share.
	var wanted: float = 4.0 if named == "1440x900" else 2.5
	_check("at %s the parts grid shows %.1f rows of parts, nothing selected (%.0f px)"
		% [named, rows, bin._scroll.size.y], rows >= wanted)
	await _shot("first_timer_grid_" + named)
	var white: Control = bin._swatches.get(15)
	var was: Vector2 = white.get_global_rect().position
	var cell: Button = bin._grid.get_child(1)
	await _click(cell.get_global_rect().get_center())
	await _frames(8)
	_check("...a part taken into hand leaves the palette where it was (%s, %s)"
		% [was, white.get_global_rect().position], white.get_global_rect().position == was)
	await _key(KEY_ESCAPE)
	var red: int = _bricks_near(Vector3(-60, 0, 20))[0]
	_select_only([red])
	await _frames(12)
	_check("...and so does a brick selected, %s (%s)" % ["its properties open" if both
		else "the bin still open", white.get_global_rect().position],
		white.get_global_rect().position == was and dock.is_open()
		and (not both or shell.inspector._title.is_visible_in_tree()))
	await _shot("first_timer_grid_selected_" + named)
	shell.outliner.set_open(true)
	await _frames(12)
	_check("...and the model tree opened (%s)" % white.get_global_rect().position,
		white.get_global_rect().position == was and shell.outliner.is_open())
	_check("...with the parts grid still there to browse (%.1f rows)"
		% (bin._scroll.size.y / 88.0), bin._scroll.size.y >= 88.0)
	await _shot("first_timer_grid_tree_" + named)
	shell.outliner.set_open(false)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	await _frames(8)
	_check("...and nothing selected again, the room goes back to the grid (%.1f rows)"
		% (bin._scroll.size.y / 88.0), bin._scroll.size.y / 88.0 >= wanted)


## New on the first visit's example car, untouched, asked whether to save
## it: an example as it shipped is nobody's unsaved work.
func _an_untouched_example() -> void:
	var shell: Shell = _main.get("_shell")
	var bar: ModelBar = _main.get("_bar")
	var placed: int = _main.call("_open", "res://models/car.ldr")
	bar.opened.emit(placed)
	await _frames(5)
	shell.run("new")
	await _frames(3)
	_check("New on the example car, untouched, asks nothing (%d parts were there)" % placed,
		placed > 0 and not bar._confirm_new.visible and _count() == 0)
	bar._confirm_new.hide()
	placed = _main.call("_open", "res://models/car.ldr")
	bar.opened.emit(placed)
	await _frames(5)
	# Painted, it is somebody's work, and New asks.
	_select_only([_model()[0].id])
	_builder.held_color = 2 if _model()[0].color_code != 2 else 4
	shell.run("paint")
	_builder.clear_selection()
	await _frames(3)
	shell.run("new")
	await _frames(3)
	_check("...and once painted, New asks first", bar._confirm_new.visible and _count() > 0)
	bar._confirm_new.hide()
	_main.call("clear_model")
	await _frames(3)


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


## A laptop's window has room beside the model for one column. A first
## visit opens on the parts bin, with no assistant (src/dev/noai_probe.gd);
## turned on in Settings, its column opens and the bin folds to its rail. A
## part put in hand brings the bin out, and a click on a rail switches.
func _one_column_at_a_time() -> void:
	var bin: SideDock = _main.get("_bin_dock")
	var chat: SideDock = _main.get("_chat_dock")
	_check("a first visit opens on the parts bin, with no assistant",
		bin.is_open() and not chat.visible)
	# The rest of this probe has the assistant, as a person who turns it on.
	_main.call("set_assistant", true)
	await _frames(30)
	if str(_main.get("_columns")) != "turns":
		print("    (this window has room for both columns, so they do not take turns here)")
		return
	print("  one column at a time beside the model")
	_check("the assistant turned on opens its column, the parts bin folded to its rail",
		chat.is_open() and not bin.is_open())
	var verbs: EditVerbs = _main.get("_verbs")
	await _key(KEY_Q)
	await _frames(30)
	_check("Q puts the last part in hand and brings the parts bin out (%s)" % verbs.mode,
		verbs.mode == "place" and bin.is_open() and bin.content.is_visible_in_tree())
	_check("...and the assistant folds to its rail to make room", not chat.is_open())
	await _key(KEY_ESCAPE)
	await _click(chat.rail().get_global_rect().get_center())
	await _frames(30)
	_check("one click on the assistant's rail switches back",
		chat.is_open() and not bin.is_open())
	await _click(bin.rail().get_global_rect().get_center())
	await _frames(30)
	_check("...and one on the parts rail switches again", bin.is_open() and not chat.is_open())
	_check("...and is kept as this person's choice (%s)" % ShellPrefs.value("narrow_side"),
		str(ShellPrefs.value("narrow_side")) == "parts")


## Open a side column by its rail, as a person does, if it is folded: a
## window with room for one column beside the model shows one at a time.
## The name of the column a panel is in, for _show_column: the properties'
## and the model tree's are down the right, or a phone's drawer.
func _column_of(panel: Control) -> String:
	var dock: SideDock = SideDock.of(panel)
	for named: String in ["_bin_dock", "_props_dock", "_chat_dock"]:
		if _main.get(named) == dock:
			return named
	return "_bin_dock"


func _show_column(dock_name: String) -> void:
	var dock: SideDock = _main.get(dock_name)
	if dock.is_open():
		return
	await _click(dock.rail().get_global_rect().get_center())
	await _frames(30)
	_check("its rail opens the %s" % {"_bin_dock": "parts bin",
		"_props_dock": "model tree and the properties"}.get(dock_name, "assistant"), dock.is_open())


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
