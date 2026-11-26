## Simple mode (SimpleLayer, simplep1 then simple1): a brick dragged from
## the tray onto the studs with one finger, the view with two, a placed
## brick moved, turned, copied and deleted, the header's Simple | Full, and
## three newcomers' walks.
##
##   godot --path . --resolution 390x844 --script src/dev/simplep1_probe.gd
##   PROBE_SIZE=430x932 tools/probe.sh simplep1_probe
##   PROBE_SIZE=820x1180 tools/probe.sh simplep1_probe -- --tablet
##   PROBE_SIZE=390x844 tools/probe.sh simplep1_probe -- --walks=0 --lifts=0,32,56,80
##   PROBE_SIZE=1280x800 tools/probe.sh simplep1_probe -- --desktop --walks=0
##   PROBE_SIZE=1280x800 tools/probe.sh simplep1_probe -- --full --desktop
##
## --checks=0 or --walks=0 leaves that half out; --lifts=... walks the
## careful newcomer once at each height of the ghost over the finger, in
## points; --pictures=DIR where the pictures go (res://shots/simplep1 unless
## said); --full: Full, the full studio pictured on a model for a
## byte-for-byte compare with another tree's, and nothing else; --desktop:
## no phone layout; --tablet: a tablet's.
##
## Checks, in Simple (as the header's switch leaves a device), by touch
## events as a finger sends them:
##   1. the layer is up in the phone's foot row's place: five groups of six
##      parts with pictures and twelve colours, every target a fingertip,
##      the foot under a third of the screen, the phone's row put away;
##   2. a brick dragged from the tray shows its ghost on the studs, over the
##      finger by its lift, and let go goes down there, one undo step, in
##      the colour chosen first, seated by a drawn drop;
##   3. let go over the tray, or a second finger down: nothing goes down;
##   4. Undo and Redo, big, take it back and put it back byte for byte;
##   5. one finger on empty space turns nothing and says how, a finger
##      within a fingertip of a part takes it, two fingers turn and zoom;
##      Fit frames;
##   6. a tap on a brick of the tray, then a tap on the model, shows its
##      ghost there; a tap elsewhere shows it there instead, a tap on it puts
##      it down, a drag from it carries it;
##   7. Simple | Full in the header: one tap each way, remembered, the
##      model byte for byte;
##   8. a new sketch on a 16 x 16 plate framed to fill the view, a stud
##      never under 12 points however far it is pinched out, Fit;
##   9. a placed brick: a tap selects, a drag moves it onto the studs, Turn
##      a quarter, Copy one beside it, Delete, a held finger deletes
##      nothing, the bin deletes, Undo;
##  10. two fingers tapped undo and three redo, the view still;
##  11. a model opened in Full shown whole in Simple, the parts it leaves
##      alone said once and left as they are.
##
## The walks: three newcomers, given no words, scripted as a person would go
## about it (WALKS.md says how each is modelled). Each builds the same ten
## bricks, a little house, moves the round brick, then turns, recolours,
## deletes and undoes; every touch is a real touch event through the app,
## and what each touch did is read from the app: where the brick went,
## whether the view moved. Seconds are modelled (Fitts's law and the
## keystroke-level model's operators), never the probe's own wall clock.
## Exits non-zero when a check fails.
extends SceneTree

var _failures: int = 0
var _main: Node
var _camera: CadCamera
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _store: ModelStore
var _library: PartLibrary
var _phone: Node
var _simple: Control
## The pictures' and results' word for Simple (one finger builds, two move
## the view: the one finger map since simple1).
const _map := "simple"
var _tablet: bool = false
var _desktop: bool = false
var _full: bool = false
var _do_checks: bool = true
var _do_walks: bool = true
## The round brick moved a stud and back after the ten (--moves=0: not).
var _moves: bool = true
var _lifts: Array = []
var _pictures: String = "res://shots/simplep1/"
var _size: String = ""
var _results: Dictionary = {}
var _shot_n: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--tablet":
			_tablet = true
		elif arg == "--desktop":
			_desktop = true
		elif arg == "--full":
			_full = true
		elif arg == "--checks=0":
			_do_checks = false
		elif arg == "--moves=0":
			_moves = false
		elif arg == "--walks=0":
			_do_walks = false
		elif arg.begins_with("--lifts="):
			for one: String in arg.get_slice("=", 1).split(",", false):
				_lifts.append(float(one))
		elif arg.begins_with("--pictures="):
			_pictures = arg.get_slice("=", 1).trim_suffix("/") + "/"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("simplep1_probe: needs a window")
		quit(1)
		return
	_args()
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Phone._on = 0 if _desktop else 1
	Phone._wide = _tablet
	# Simple from the start, as the header's Simple | Full leaves a device.
	ShellPrefs.put("controls", "full" if _full else "simple")
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
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_store.keeps = false
	_simple = _main.get("_simple")
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_pictures))
	print("simplep1_probe: a %s window, %s, %s" % [_size,
		"desktop" if _desktop else ("tablet" if _tablet else "phone"),
		"Full" if _full else "Simple"])

	if _full:
		await _full_pictures()
		_finish()
		return
	if not _check("Simple's layer is up over the studio", _simple != null and _simple.is_visible_in_tree()):
		quit(1)
		return
	if _do_checks:
		print("\n1. the layer")
		await _the_layer()
		print("\n2. a brick dragged from the tray onto the studs")
		await _drag_from_tray()
		print("\n3. nothing goes down: let go over the tray, a second finger")
		await _nothing_down()
		print("\n4. Undo and Redo, big")
		await _undo_redo()
		print("\n5. one finger builds, two move the view")
		await _finger_map()
		print("\n6. a tap on the tray, a tap on the model")
		await _tap_tap()
		print("\n7. the header's Simple | Full")
		await _the_switch()
		print("\n8. a new sketch, framed")
		await _the_sketch()
		print("\n9. a placed brick: tap, drag, Turn, Copy, Delete, the bin")
		await _a_placed_brick()
		print("\n10. two fingers tapped undo, three redo")
		await _finger_taps()
		print("\n11. a model from the full studio, whole")
		await _from_full()
	if _do_walks:
		print("\n12. three newcomers, no words")
		_results["walks"] = []
		for walker: Dictionary in WALKERS:
			(_results["walks"] as Array).append(await _walk(walker))
	if not _lifts.is_empty():
		_moves = false
		print("\n13. the ghost's height over the finger, the careful newcomer at each")
		_results["lifts"] = []
		for lift: float in _lifts:
			_simple.set("lift_points", lift)
			var one: Dictionary = await _walk(WALKERS[0], "lift%d" % int(lift))
			one["lift"] = lift
			(_results["lifts"] as Array).append(one)
		_simple.set("lift_points", 56.0)
	_finish()


func _finish() -> void:
	_results["size"] = _size
	_results["failures"] = _failures
	var path: String = ProjectSettings.globalize_path(_pictures) + "%s_%s%s.json" % [_size,
		"full" if _full else _map, "_tablet" if _tablet else ""]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
		file.close()
	print("\nsimplep1_probe: %s (%s)" % ["all passed" if _failures == 0 else "%d failed" % _failures, path])
	quit(1 if _failures else 0)


# -- the full studio, the switch off -----------------------------------------------


## The full studio on the car, as a first visit lays it out: a picture for a
## byte-for-byte compare with the same probe on another tree.
func _full_pictures() -> void:
	_check("no Simple layer with the switch off", _main.get("_simple") == null)
	if _phone != null:
		var row: Control = _phone.get("_row")
		_check("the phone's foot row is up", row != null and row.is_visible_in_tree())
	await _open("res://models/car.ldr")
	_camera.set_view("default")
	_camera.frame(_world.model_bounds())
	await _settle()
	await _frames(60)
	await _shot("full_car")
	_main.call("clear_model")
	await _frames(10)
	_camera.set_view("default")
	await _settle()
	await _frames(60)
	await _shot("full_new")


# -- 1. the layer --------------------------------------------------------------------


func _the_layer() -> void:
	var named: Dictionary = _simple.call("controls_by_name")
	var row: Control = _phone.get("_row") if _phone != null else null
	_check("the phone's foot row is put away", row == null or not row.is_visible_in_tree())
	var tiles: int = 0
	var swatches: int = 0
	var tabs: int = 0
	var small: Array = []
	var off: Array = []
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var finger: float = Phone.px(root, Phone.TARGET) - 0.5
	for key: String in named:
		var control: Control = named[key]
		if control == null or not control.is_visible_in_tree():
			continue
		if key.begins_with("simple_brick_"):
			tiles += 1
		elif key.begins_with("simple_colour_"):
			swatches += 1
		elif key.begins_with("simple_group_"):
			tabs += 1
		var rect: Rect2 = control.get_global_rect()
		if key != "simple_foot" and (rect.size.x < finger or rect.size.y < finger):
			small.append("%s %.0fx%.0f" % [key, rect.size.x / Phone.per_point(root), rect.size.y / Phone.per_point(root)])
		if not screen.encloses(rect.grow(-0.5)):
			off.append(key)
	_check("five groups of six bricks and twelve colours (%d groups, %d shown, %d colours)" % [tabs, tiles, swatches],
		tabs == 5 and tiles == 6 and swatches == 12)
	var parts: Array[String] = _simple.get_script().call("tray_parts")
	var drawn: int = 0
	for part: String in parts:
		if _library.parts.has(part) and _library.mesh_for(part) != null:
			drawn += 1
	_check("thirty parts in the tray, every one in the library with a shape (%d of %d)" % [drawn, parts.size()],
		parts.size() == 30 and drawn == 30)
	_check("every one a fingertip, 44 points or more (%s)" % ", ".join(small), small.is_empty())
	_check("nothing off the screen (%s)" % ", ".join(off), off.is_empty())
	var foot: float = float(_simple.call("foot_height"))
	print("  measure foot %.0f points of %.0f (%.0f%%)" % [foot / Phone.per_point(root),
		screen.size.y / Phone.per_point(root), 100.0 * foot / screen.size.y])
	_check("the tray under a third of the screen", foot < screen.size.y / 3.0)
	var room: Rect2 = _camera.seen_rect()
	_check("the model's room stops above the tray (%.0f, foot at %.0f)" % [room.end.y, screen.size.y - foot],
		room.end.y <= screen.size.y - foot + 1.0)
	# The pictures come.
	var pictured: int = 0
	for _n: int in 600:
		pictured = 0
		for picture: TextureRect in _simple.get("_pictures"):
			if picture.texture != null:
				pictured += 1
		if pictured == 6:
			break
		await process_frame
	_check("every brick of the group shown pictured (%d of 6)" % pictured, pictured == 6)
	await _fresh()
	await _shot("layer")


# -- 2. a brick dragged from the tray --------------------------------------------------


func _drag_from_tray() -> void:
	await _fresh()
	await _press_swatch(14)
	_check("a colour chosen first: yellow", int(_simple.call("chosen_colour")) == 14)
	var before: int = _world.brick_count()
	var depth: int = _builder.history_depth()
	var target: Vector2 = _base_point(0.0, 0.0)
	var lift: float = Phone.px(root, float(_simple.get("lift_points")))
	var tile: Control = _simple.call("tile_of", "3003")
	var from: Vector2 = tile.get_global_rect().get_center()
	var finger: Vector2 = target + Vector2(0, lift)
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, finger, 14)
	await _frames(3)
	var showing: bool = _builder.has_preview()
	var valid: bool = _builder.can_place()
	var ghost: Transform3D = _builder.ghost_transform()
	var ghost_at: Vector2 = _camera.unproject_position(ghost.origin)
	await _shot("ghost")
	_check("the ghost shows while dragged over the model, on legal studs", showing and valid)
	print("  measure ghost %.0f points over the finger" % ((finger.y - ghost_at.y) / Phone.per_point(root)))
	_check("...over the finger, not under it (%.0f points)" % ((finger.y - ghost_at.y) / Phone.per_point(root)),
		finger.y - ghost_at.y > lift * 0.6)
	var seated: int = int((_simple.get("counts") as Dictionary).get("seated", 0))
	_touch(0, finger, false)
	await process_frame
	var drawn: Dictionary = _world.drawn_ids()
	await process_frame
	var drop: Dictionary = _simple.get("last_drop")
	var put: Array = drop.get("put", [])
	_check("let go, it went down: one brick more, one undo step (%d, %d)" % [_world.brick_count() - before,
		_builder.history_depth() - depth], _world.brick_count() == before + 1 and _builder.history_depth() == depth + 1)
	var brick: BrickWorld.Brick = _world.get_brick(int(put[0])) if not put.is_empty() else null
	_check("...the brick dragged, in the colour chosen (%s, %s)" % [brick.part_id if brick else "?",
		brick.color_code if brick else -1], brick != null and brick.part_id == "3003" and brick.color_code == 14)
	_check("...where its ghost stood", brick != null and brick.transform.is_equal_approx(ghost))
	_check("...on the studs: square, its middle on the stud grid (%s)" % (brick.transform.origin if brick else Vector3.ZERO),
		brick != null and BrickLattice.is_square_to_grid(brick.transform.basis)
		and _on_grid(brick.transform.origin.x) and _on_grid(brick.transform.origin.z))
	var seating: bool = brick != null and int((_simple.get("counts") as Dictionary).get("seated", 0)) == seated + 1 \
		and (not drawn.has(brick.id) or (drawn[brick.id] as Transform3D).origin.y > brick.transform.origin.y)
	print("  measure seat drawn at the first frame: %s" % ("%.1f LDU over its studs" % ((drawn[brick.id] as Transform3D).origin.y
		- brick.transform.origin.y) if brick != null and drawn.has(brick.id) else "already down"))
	_check("...seated by a drop drawn onto its studs, the model's brick already where it stands", seating)
	var left: int = await _seat_done()
	_check("...and the drop is over in a moment, nothing left moved (%d ms after the checks above)" % left,
		_world.drawn_ids().is_empty() and left < 500)
	_check("nothing in hand after: no ghost, the tool Select's", not _builder.has_preview() and _verbs.mode == "select")
	await _shot("dropped")


# -- 3. nothing down -------------------------------------------------------------------


func _nothing_down() -> void:
	await _fresh()
	var before: int = _world.brick_count()
	var tile: Control = _simple.call("tile_of", "3001")
	var from: Vector2 = tile.get_global_rect().get_center()
	# Out over the model and back onto the tray.
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, _base_point(0.0, 0.0), 10)
	await _drag_along(0, _base_point(0.0, 0.0), from + Vector2(0, 4), 10)
	_touch(0, from + Vector2(0, 4), false)
	await _frames(3)
	_check("let go over the tray: nothing goes down (%d)" % (_world.brick_count() - before),
		_world.brick_count() == before and not _builder.has_preview())
	# A second finger mid-drag.
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, _base_point(0.0, 0.0), 10)
	_touch(1, _base_point(0.3, -0.3), true)
	await process_frame
	_touch(1, _base_point(0.3, -0.3), false)
	await process_frame
	_touch(0, _base_point(0.0, 0.0), false)
	await _frames(3)
	_check("a second finger mid-drag: nothing goes down (%d)" % (_world.brick_count() - before),
		_world.brick_count() == before)
	_check("...said as put back", str((_simple.get("last_drop") as Dictionary).get("why", "")) == "a second finger")


# -- 4. undo and redo ----------------------------------------------------------------


func _undo_redo() -> void:
	await _fresh()
	var empty: String = _store.to_text()
	await _put("3001", 4, _base_point(0.0, 0.0))
	var one: String = _store.to_text()
	var undo: Button = _simple.get("_undo")
	var redo: Button = _simple.get("_redo")
	_check("Undo and Redo are big: %.0f points" % (undo.size.x / Phone.per_point(root)),
		undo.size.x >= Phone.px(root, 56.0) - 0.5 and redo.size.x >= Phone.px(root, 56.0) - 0.5)
	await _tap_at(undo.get_global_rect().get_center())
	await _frames(4)
	_check("big Undo takes the brick back, byte for byte", _store.to_text() == empty)
	await _tap_at(redo.get_global_rect().get_center())
	await _frames(4)
	_check("big Redo puts it back, byte for byte", _store.to_text() == one)


# -- 5. the finger map ---------------------------------------------------------------


func _finger_map() -> void:
	await _fresh()
	var id: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	var empty_at: Vector2 = _empty_point()
	var view: Transform3D = _camera.global_transform
	var at_before: Transform3D = _world.get_brick(id).transform
	await _one_finger(empty_at, empty_at + Vector2(Phone.px(root, 90.0), 0.0))
	# What it said last, read before the view is waited on: at 1280 under a
	# loaded box the wait outlasted the words' 2.6 s on the line.
	var said: String = str(_simple.get("_said"))
	await _settle()
	var turned: bool = _view_moved(view)
	_check("one finger on empty space turns nothing", not turned)
	_check("...and says how: \"%s\"" % said, said.to_lower().contains("two fingers"))
	_check("...and moves no part", _world.get_brick(id).transform.is_equal_approx(at_before))
	await _press_fit()
	# A finger on the part moves it, in both.
	view = _camera.global_transform
	var on: Vector2 = _top_point(id)
	var to: Vector2 = _base_point(0.25, 0.25)
	await _one_finger(on, to + Vector2(0, Phone.px(root, float(_simple.get("lift_points")))))
	await _frames(4)
	var moved: bool = not _world.get_brick(id).transform.is_equal_approx(at_before) if _world.get_brick(id) else false
	_check("a finger on the part moves it (counts %s)" % str(_simple.get("counts")), moved)
	_check("...and the view stays (%.2f LDU, %.4f of a turn)" % [
		_camera.global_position.distance_to(view.origin),
		_camera.global_transform.basis.get_rotation_quaternion().angle_to(view.basis.get_rotation_quaternion()) / TAU],
		not _view_moved(view))
	await _seat_done()
	if true:
		# A finger beside a part, within a fingertip: the part's.
		# Seen first: the move above went to a point of the plate that a
		# Fit on two parts leaves off the screen (r3: no point of it seen).
		await _press_fit()
		var now: Transform3D = _world.get_brick(id).transform
		var beside: Vector2 = _beside(id, 14.0)
		var off_it: bool = beside.x < INF and _verbs.brick_at(beside) == 0
		print("  measure beside %s, on a part there: %d (the part %d, its picture %s)" % [beside,
			_verbs.brick_at(beside) if off_it else -1, id, _screen_box(_box_of(id))])
		if off_it:
			await _one_finger(beside, _base_point(-0.25, 0.2) + Vector2(0, Phone.px(root, float(_simple.get("lift_points")))))
			await _frames(4)
		_check("B: a finger 14 points beside a part, off it, takes it",
			off_it and not _world.get_brick(id).transform.is_equal_approx(now))
		await _seat_done()
		view = _camera.global_transform
		await _two_fingers(_base_point(-0.2, -0.3), _base_point(0.2, -0.3), Vector2(Phone.px(root, 80.0), 0.0), 1.0)
		await _settle()
		_check("B: two fingers turn the view", _view_moved(view))
		view = _camera.global_transform
		var distance: float = _camera.global_position.distance_to(_world.model_bounds().get_center())
		await _two_fingers(_base_point(-0.1, -0.2), _base_point(0.1, -0.2), Vector2.ZERO, 2.0)
		await _settle()
		var closer: float = _camera.global_position.distance_to(_world.model_bounds().get_center())
		_check("B: two fingers spread zoom in (%.0f to %.0f)" % [distance, closer], closer < distance * 0.9)
	await _press_fit()
	_check("Fit frames the model", _camera.seen_rect().has_point(_camera.unproject_position(
		_world.get_brick(id).transform.origin)))
	await _shot("map_" + _map)


# -- 6. tap, tap ---------------------------------------------------------------------


func _tap_tap() -> void:
	await _fresh()
	var before: int = _world.brick_count()
	var tile: Control = _simple.call("tile_of", "3004")
	await _tap_at(tile.get_global_rect().get_center())
	await _frames(3)
	_check("a tap on a brick of the tray chooses it", str(_simple.call("chosen_brick")) == "3004")
	# A finger hides where it lands: its tap shows the ghost there first.
	await _tap_at(_base_point(-0.3, 0.2))
	await _frames(3)
	_check("a tap on the model shows where it goes, nothing down yet (%d)" % (_world.brick_count() - before),
		_world.brick_count() == before and bool(_simple.call("ghost_waits")))
	_check("...and says how: \"%s\"" % _simple.call("hint"), str(_simple.call("hint")).contains("Tap it"))
	var first: Transform3D = _builder.ghost_transform()
	await _tap_at(_base_point(0.1, 0.0))
	await _frames(3)
	_check("a tap elsewhere shows it there instead, still nothing down",
		_world.brick_count() == before and bool(_simple.call("ghost_waits"))
		and not _builder.ghost_transform().origin.is_equal_approx(first.origin))
	var shown: Transform3D = _builder.ghost_transform()
	await _tap_at((_simple.call("ghost_rect") as Rect2).get_center())
	await _frames(3)
	var put: Array = (_simple.get("last_drop") as Dictionary).get("put", [])
	_check("a tap on the ghost puts it down where it showed (%d)" % (_world.brick_count() - before),
		_world.brick_count() == before + 1 and put.size() == 1
		and _world.get_brick(int(put[0])).transform.origin.is_equal_approx(shown.origin))
	# Shown again, and carried by a drag from it: down where it is let go.
	await _tap_at(_base_point(-0.3, -0.2))
	await _frames(3)
	var from: Vector2 = (_simple.call("ghost_rect") as Rect2).get_center()
	var lift: float = Phone.px(root, float(_simple.get("lift_points")))
	var to: Vector2 = from + Vector2(Phone.px(root, 60.0), lift)
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, to, 10)
	await _frames(2)
	var carried: Transform3D = _builder.ghost_transform()
	_touch(0, to, false)
	await _frames(3)
	put = (_simple.get("last_drop") as Dictionary).get("put", [])
	_check("a drag from the ghost carries it, down where let go (%d)" % (_world.brick_count() - before),
		_world.brick_count() == before + 2 and put.size() == 1
		and _world.get_brick(int(put[0])).transform.origin.is_equal_approx(carried.origin)
		and not carried.origin.is_equal_approx(shown.origin))
	await _tap_at(tile.get_global_rect().get_center())
	await _frames(3)
	_check("a tap on it again lets it go", str(_simple.call("chosen_brick")).is_empty())
	await _tap_at(_base_point(-0.2, 0.0))
	await _frames(3)
	_check("...and a tap on the model puts nothing down", _world.brick_count() == before + 1)


# -- 7. the header's switch -----------------------------------------------------------


func _header_controls() -> Dictionary:
	if _phone != null:
		return _phone.call("controls_by_name")
	return (_main.get("_bar") as Node).call("controls_by_name")


func _the_switch() -> void:
	await _fresh()
	await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	var text: String = _store.to_text()
	var named: Dictionary = _header_controls()
	var simple: Button = named.get("controls_simple")
	var full: Button = named.get("controls_full")
	var seen: bool = simple != null and full != null and simple.is_visible_in_tree() and full.is_visible_in_tree()
	_check("Simple | Full in the studio's header, Simple pressed", seen and simple.button_pressed
		and not full.button_pressed)
	if not seen:
		return
	var band := Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size.x, float(_simple.call("_header_foot"))))
	_check("...in the header's band (%s, %s; the band %s)" % [simple.get_global_rect(), full.get_global_rect(), band],
		band.grow(1.0).encloses(simple.get_global_rect()) and band.grow(1.0).encloses(full.get_global_rect()))
	var finger: float = Phone.px(root, 44.0 if _phone != null else 28.0) - 0.5
	_check("...each %s (%.0f, %.0f points tall)" % ["a fingertip" if _phone != null else "a button's height",
		simple.size.y / Phone.per_point(root), full.size.y / Phone.per_point(root)],
		simple.size.y >= finger and full.size.y >= finger)
	await _shot("switch_simple")
	await _tap_at(full.get_global_rect().get_center())
	await _frames(8)
	_check("one tap on Full: the full studio", StringName(_main.get("_layer")) == &"full"
		and not _simple.is_visible_in_tree())
	_check("...remembered on this device", str(ShellPrefs.value("controls")) == "full")
	_check("...the same model, byte for byte", _store.to_text() == text)
	_check("...Full pressed now", full.button_pressed and not simple.button_pressed)
	if _phone != null:
		var row: Control = _phone.get("_row")
		_check("...the phone's foot row back", row != null and row.is_visible_in_tree())
	await _settle()
	await _shot("switch_full")
	await _tap_at(simple.get_global_rect().get_center())
	await _frames(8)
	_check("one tap on Simple: Simple again, remembered", StringName(_main.get("_layer")) == &"simple"
		and _simple.is_visible_in_tree() and str(ShellPrefs.value("controls")) == "simple")
	_check("...the same model, byte for byte", _store.to_text() == text)


# -- 8. a new sketch ------------------------------------------------------------------


## A stud's width drawn at the plate's middle, in points.
func _stud_points() -> float:
	var middle: Vector3 = _floor_box().get_center()
	var right: Vector3 = _camera.global_transform.basis.x.normalized()
	var a: Vector2 = _camera.unproject_position(middle)
	var b: Vector2 = _camera.unproject_position(middle + right * BrickLattice.STUD)
	return a.distance_to(b) / Phone.per_point(root)


func _plate_fills() -> String:
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var plate: Rect2 = _screen_box(_floor_box())
	var fills: float = maxf(plate.size.x / room.size.x, plate.size.y / room.size.y)
	if not room.grow(Phone.px(root, 2.0)).encloses(plate):
		return "not all of it in the room (%s in %s)" % [plate, room]
	return "" if fills >= 0.8 else "%.0f%% of the room" % (fills * 100.0)


func _the_sketch() -> void:
	await _fresh()
	var floor: ModelFloor = _store.model_floor
	_check("a new sketch stands on a 16 x 16 plate (%s %d x %d)" % [floor.kind, floor.across, floor.deep],
		floor.kind == ModelFloor.BASEPLATE and floor.across == 16 and floor.deep == 16)
	var fills: String = _plate_fills()
	_check("...framed to fill the view, all of it seen (%s)" % fills, fills.is_empty())
	await _shot("sketch")
	var middle: Vector2 = _seen_middle()
	for _n: int in 5:
		await _two_fingers(middle - Vector2(Phone.px(root, 70.0), 0.0), middle + Vector2(Phone.px(root, 70.0), 0.0),
			Vector2.ZERO, 0.35)
	await _settle()
	var stud: float = _stud_points()
	print("  measure a stud pinched out as far as it goes: %.1f points (framed: %.1f)" % [stud,
		float(_simple.call("least_stud_points"))])
	_check("pinched out as far as it goes, a stud is still 12 points or more (%.1f)" % stud, stud >= 11.75)
	await _shot("far")
	await _press_fit()
	fills = _plate_fills()
	_check("Fit frames the plate again (%s)" % fills, fills.is_empty())


# -- 9. a placed brick ----------------------------------------------------------------


func _a_placed_brick() -> void:
	await _fresh()
	var id: int = await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	_builder.clear_selection()
	await _frames(2)
	var lift: float = Phone.px(root, float(_simple.get("lift_points")))
	await _tap_at(_top_point(id))
	await _frames(3)
	_check("a tap on a placed brick selects it", _builder.selection.size() == 1 and _builder.selection.has(id))
	var turn: Button = _simple.call("button", "turn")
	var copy: Button = _simple.call("button", "copy")
	var delete: Button = _simple.call("button", "delete")
	var shown: bool = true
	for one: Button in [turn, copy, delete]:
		shown = shown and one != null and one.is_visible_in_tree() and one.size.x >= Phone.px(root, 44.0) - 0.5
	_check("...and Turn, Copy and Delete come up, each a fingertip", shown)
	await _shot("selected")
	if not shown:
		return
	var was: Transform3D = _world.get_brick(id).transform
	var depth: int = _builder.history_depth()
	await _one_finger(_top_point(id), _base_point(0.35, 0.25) + Vector2(0, lift))
	await _frames(4)
	var brick: BrickWorld.Brick = _world.get_brick(id)
	_check("one finger drags it: it moved, one undo step (%d)" % (_builder.history_depth() - depth),
		brick != null and not brick.transform.is_equal_approx(was) and _builder.history_depth() == depth + 1)
	_check("...and snapped onto the studs (%s)" % (brick.transform.origin if brick != null else Vector3.ZERO),
		brick != null and BrickLattice.is_square_to_grid(brick.transform.basis)
		and _on_grid(brick.transform.origin.x) and _on_grid(brick.transform.origin.z))
	await _seat_done()
	if brick == null:
		return
	if not _builder.selection.has(id):
		await _tap_at(_top_point(id))
		await _frames(3)
	var facing: Vector3 = brick.transform.basis.x
	await _tap_at(turn.get_global_rect().get_center())
	await _frames(3)
	brick = _world.get_brick(id)
	var turned: float = rad_to_deg(facing.signed_angle_to(brick.transform.basis.x, Vector3.UP))
	_check("Turn turns it a quarter about up (%.0f degrees), upright" % turned,
		absf(absf(turned) - 90.0) < 0.5 and brick.transform.basis.y.dot(Vector3.UP) > 0.999)
	_check("...on the studs, still selected", _on_grid(brick.transform.origin.x) and _on_grid(brick.transform.origin.z)
		and _builder.selection.has(id))
	var before: int = _world.brick_count()
	await _tap_at(copy.get_global_rect().get_center())
	await _frames(4)
	var picked: Array = _builder.selection.keys()
	var made: BrickWorld.Brick = _world.get_brick(int(picked[0])) if picked.size() == 1 else null
	_check("Copy: one more, the same part and colour, selected to drag (%d more)" % (_world.brick_count() - before),
		_world.brick_count() == before + 1 and made != null and made.id != id and made.part_id == "3001"
		and made.color_code == 4 and not _builder.is_carrying())
	await _seat_done()
	await _shot("copied")
	if made == null:
		return
	await _tap_at(delete.get_global_rect().get_center())
	await _frames(3)
	_check("Delete takes the copy off", _world.brick_count() == before and _world.get_brick(made.id) == null)
	# A finger held still on a part a second and a half: nothing deleted.
	var at: Vector2 = _top_point(id)
	_touch(0, at, true)
	var from: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - from < 1500:
		await process_frame
	_touch(0, at, false)
	await _frames(3)
	_check("a finger held still on it a second and a half deletes nothing", _world.brick_count() == before
		and _world.get_brick(id) != null)
	was = _world.get_brick(id).transform
	at = _top_point(id)
	_touch(0, at, true)
	await process_frame
	await _drag_along(0, at, at + Vector2(0, -Phone.px(root, 30.0)), 6)
	await _frames(2)
	var bin: Button = _simple.call("button", "bin")
	_check("a part dragged: the bin is shown", bin != null and bin.is_visible_in_tree())
	if bin == null:
		_touch(0, at, false)
		return
	var bin_at: Vector2 = bin.get_global_rect().get_center()
	await _drag_along(0, at + Vector2(0, -Phone.px(root, 30.0)), bin_at, 12)
	await _frames(2)
	await _shot("bin")
	_touch(0, bin_at, false)
	await _frames(4)
	_check("let go over the bin: it is deleted (%d)" % (_world.brick_count() - before),
		_world.brick_count() == before - 1 and _world.get_brick(id) == null)
	_check("...said: \"%s\"" % _said(), _said().contains("Deleted"))
	var undo: Button = _simple.get("_undo")
	await _tap_at(undo.get_global_rect().get_center())
	await _frames(4)
	var back: bool = false
	for one: BrickWorld.Brick in _world.bricks():
		back = back or (one.part_id == "3001" and one.transform.is_equal_approx(was))
	_check("Undo puts it back where it stood", _world.brick_count() == before and back)


# -- 10. fingers tapped ----------------------------------------------------------------


## Fingers down at once and up at once, still: a tap of that many.
func _fingers_down_up(points: Array) -> void:
	for n: int in points.size():
		_touch(n, points[n], true)
	await _frames(3)
	for n: int in points.size():
		_touch(n, points[n], false)
	await _frames(4)


func _finger_taps() -> void:
	await _fresh()
	var empty: String = _store.to_text()
	await _put("3001", 4, _base_point(0.0, 0.0))
	await _seat_done()
	var one: String = _store.to_text()
	var at: Vector2 = _empty_point()
	var step := Vector2(Phone.px(root, 40.0), 0.0)
	var view: Transform3D = _camera.global_transform
	await _fingers_down_up([at, at + step])
	_check("two fingers tapped: undone, byte for byte", _store.to_text() == empty)
	await _fingers_down_up([at, at + step, at + step * 2.0])
	_check("three fingers tapped: redone, byte for byte", _store.to_text() == one)
	await _settle()
	_check("...and the view stayed", not _view_moved(view))


# -- 11. a model from the full studio ---------------------------------------------------


## A model with what Simple leaves alone: a brick turned 30 degrees and a
## sub-assembly of two, beside two plain bricks.
const FROM_FULL := """0 FILE simple_from_full.ldr
0 Simple's left-alone check
0 Name: simple_from_full.ldr
1 4 -40 -8 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 60 -8 40 1 0 0 0 1 0 0 0 1 3001.dat
1 14 40 -8 -60 0.866025 0 0.5 0 1 0 -0.5 0 0.866025 3001.dat
1 2 -60 -8 -60 1 0 0 0 1 0 0 0 1 simple_wing.ldr
0 NOFILE
0 FILE simple_wing.ldr
1 2 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 2 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat
0 NOFILE
"""


func _from_full() -> void:
	_main.call("use_controls", &"full")
	await _frames(6)
	var path: String = "user://simple_from_full.mpd"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FROM_FULL)
	file.close()
	var opened: bool = await _open(path)
	var text: String = _store.to_text()
	_check("opened in the full studio (%d parts)" % (_world.brick_count() - _store.scenery.size()), opened)
	_simple.set("_said_until", 0)
	_main.call("use_controls", &"simple")
	await _frames(4)
	await _settle()
	var room: Rect2 = _simple.call("model_room", root.get_visible_rect())
	var out: Array = []
	var alone: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		if not room.grow(Phone.px(root, 2.0)).encloses(_screen_box(_box_of(brick.id))):
			out.append(brick.part_id)
		if not str(_simple.call("left_alone", brick.id)).is_empty():
			alone.append(brick.id)
	_check("in Simple the whole model is seen (out of the room: %s)" % ", ".join(out), out.is_empty())
	_check("Simple leaves three parts alone: the turned one and the sub-assembly's two (%d)" % alone.size(),
		alone.size() == 3)
	var said: String = _said()
	_check("...said plainly once: \"%s\"" % said, said.contains("3"))
	await _shot("from_full")
	_simple.set("_said_until", 0)
	_main.call("use_controls", &"full")
	await _frames(2)
	_main.call("use_controls", &"simple")
	await _frames(4)
	_check("...and not again for the same model", _said().is_empty() or not _said().contains("3"))
	if alone.is_empty():
		return
	var tilted: int = 0
	for id: int in alone:
		if str(_simple.call("left_alone", id)) == "tilted":
			tilted = id
	if tilted == 0:
		_check("...one of them tilted", false)
		return
	var was: Transform3D = _world.get_brick(tilted).transform
	await _tap_at(_top_point(tilted))
	await _frames(3)
	_check("a tap on the turned brick says Simple leaves it (\"%s\")" % _said(), _said().contains("Full"))
	var at: Vector2 = _top_point(tilted)
	await _one_finger(at, at + Vector2(Phone.px(root, 60.0), Phone.px(root, 40.0)))
	await _frames(4)
	_check("...a drag on it moves nothing", _world.get_brick(tilted).transform.is_equal_approx(was))
	_check("...and the model is as it came, byte for byte", _store.to_text() == text)


# -- the walks ---------------------------------------------------------------------------

## Fitts's law for a fingertip (seconds): a + b log2(D / W + 1).
const FITTS_A := 0.10
const FITTS_B := 0.15
## The keystroke-level model's mental act, before each brick and after a surprise.
const MENTAL := 1.35
const TAP := 0.10
## Seeing that something went otherwise than meant.
const NOTICE := 0.6
## A look at the ghost before letting go, and each nudge after it.
const LOOK := 0.3
## One control looked at while searching for one.
const SCAN := 0.25
const ONE_FINGER_TURN := 1.0
const TWO_FINGER_GESTURE := 1.2
## The fingertip's cover, in points, and the finger below it.
const FINGERTIP := 22.0

## The house each walker builds: [part, colour, on (-1 the baseplate, else
## the brick put down at that index), dx, dz in studs].
const HOUSE: Array = [
	["3001", 4, -1, -4.0, 0.0], ["3001", 4, -1, 4.0, 0.0], ["3003", 14, 0, 0.0, 0.0],
	["3003", 14, 1, 0.0, 0.0], ["3010", 1, -1, 0.0, 4.0], ["3004", 1, 4, 0.0, 0.0],
	["3020", 2, -1, 0.0, -5.0], ["3022", 15, 6, 0.0, 0.0], ["3039", 4, 2, 0.0, 0.0],
	["3062b", 25, 3, 0.5, 0.5],
]

## Three newcomers. sigma: how far a fingertip lands from where it is meant,
## in points; edge: how often a drag out of the tray begins at a tile's top
## edge, where a hurried thumb starts it; nudges: how often the ghost is put
## right before letting go; fix: how a brick that landed wrong is put right;
## taps: how many bricks go down by a tap on the tray and a tap on the model
## before a drag is found; turn_after: the brick after which the view is
## wanted from another side; pinch: zooms in first; slip: the brick put
## down in the wrong colour, as a slip of attention.
const WALKERS: Array[Dictionary] = [
	{"name": "careful", "seed": 11, "sigma": 3.0, "edge": 0.0, "nudges": 3, "fix": "undo",
		"taps": 0, "turn_after": 5, "pinch": false, "slip": -1},
	{"name": "hurried", "seed": 23, "sigma": 6.5, "edge": 0.5, "nudges": 1, "fix": "drag",
		"taps": 0, "turn_after": -1, "pinch": false, "slip": -1},
	{"name": "tapper", "seed": 37, "sigma": 4.0, "edge": 0.0, "nudges": 2, "fix": "undo",
		"taps": 3, "turn_after": 6, "pinch": true, "slip": 7},
]

var _walk_log: Array = []
var _seconds: float = 0.0
var _rest: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _placed: Dictionary = {}
var _tag: String = ""


func _walk(walker: Dictionary, tag: String = "") -> Dictionary:
	_tag = str(walker["name"]) if tag.is_empty() else tag
	await _fresh()
	await _shot_walk("start")
	_seconds = 0.0
	_placed = {}
	_walk_log = []
	var out: Dictionary = {"walker": walker["name"], "wrong": 0, "refused": 0,
		"unwanted_camera": 0, "wanted_camera_tries": 0, "undo_found": null, "undo_looked": 0,
		"bricks": 0, "gave_up": 0, "touches": 0}
	_rest = _seen_middle() + Vector2(0, root.get_visible_rect().size.y * 0.2)
	if bool(walker["pinch"]):
		await _wanted_zoom(walker, out)
	for n: int in HOUSE.size():
		var done: bool = false
		for attempt: int in 4:
			_rng.seed = int(walker["seed"]) * 1000 + n * 10 + attempt
			var how: String = "tap" if n < int(walker["taps"]) else "drag"
			var slip: bool = n == int(walker["slip"]) and attempt == 0
			var result: Dictionary = await _place_one(walker, n, how, slip, out)
			if bool(result.get("ok", false)):
				done = true
				break
			if result.get("down", false):
				# Down but wrong: put right, by the walker's way.
				if not await _fix(walker, n, result, out):
					continue
				done = true
				break
		if done:
			out["bricks"] = int(out["bricks"]) + 1
		else:
			out["gave_up"] = int(out["gave_up"]) + 1
			_note("gave up on brick %d" % (n + 1))
		if n == 4:
			await _shot_walk("five")
		if n == int(walker["turn_after"]):
			await _wanted_turn(walker, out)
	await _seat_done()
	await _shot_walk("ten")
	out["seconds"] = snappedf(_seconds, 0.1)
	if _moves:
		await _move_task(walker, out)
		await _seat_done()
		await _shot_walk("moved")
		await _edit_task(walker, out)
		await _shot_walk("edited")
	# The house framed whole for the picture, after the clock stops.
	await _press_fit()
	await _shot_walk("house")
	out["log"] = _walk_log
	print("  measure walk %s: %.1f s to %d bricks, %d wrong, %d refused, %d unwanted camera moves, wanted camera tries %d, undo found %s (looked at %d), gave up %d; then %d of 2 moves of the round brick in %.1f s, %d unwanted camera moves"
		% [_tag, float(out["seconds"]), out["bricks"], out["wrong"], out["refused"],
			int(out["unwanted_camera"]) - int(out.get("move_unwanted_camera", 0)), out["wanted_camera_tries"],
			("not needed" if out["undo_found"] == null else str(out["undo_found"])), out["undo_looked"], out["gave_up"],
			int(out.get("moves", 0)), float(out.get("move_seconds", 0.0)), int(out.get("move_unwanted_camera", 0))])
	if out.has("edits"):
		print("  measure walk %s edits: %d of %d (turn, recolour, delete, undo) in %.1f s, %d wrong, %d unwanted camera moves, %d touches"
			% [_tag, int(out["edits"]), EDITS.size(), float(out["edit_seconds"]), int(out["edit_wrong"]),
				int(out["edit_unwanted_camera"]), int(out["edit_touches"])])
	return out


func _group_of(part: String) -> int:
	for n: int in SimpleLayer.GROUPS.size():
		if (SimpleLayer.GROUPS[n][1] as Array).has(part):
			return n
	return -1


## After the house, what a newcomer does next to it: the roof's slope
## turned, the blue brick recoloured orange, the round brick deleted and
## the delete undone. Each part found by a tap on it, then the button that
## says the act (the hurried walker deletes by the bin, dragging it there);
## Undo by the careful walker's button, the others' two-finger tap.
const EDITS: Array = [["turn", 8], ["paint", 5], ["delete", 9], ["undo", 9]]


func _edit_task(walker: Dictionary, out: Dictionary) -> void:
	var started: float = _seconds
	var touches: int = int(out["touches"])
	out["edits"] = 0
	out["edit_wrong"] = 0
	out["edit_unwanted_camera"] = 0
	var gone: Transform3D = Transform3D()
	for act: Array in EDITS:
		var what: String = act[0]
		var n: int = int(act[1])
		if not _placed.has(n):
			_note("%s: brick %d never went down" % [what, n + 1])
			continue
		var id: int = int(_placed[n])
		_seconds += MENTAL
		if what == "undo":
			var depth: int = _builder.history_depth()
			if str(walker["fix"]) == "undo":
				await _undo_by_button(walker, out)
			else:
				var at: Vector2 = _empty_point()
				_seconds += TWO_FINGER_GESTURE
				await _fingers_down_up([at, at + Vector2(Phone.px(root, 40.0), 0.0)])
				out["touches"] = int(out["touches"]) + 1
				_note("undo by two fingers tapped")
			var back: bool = false
			for brick: BrickWorld.Brick in _world.bricks():
				back = back or (brick.part_id == HOUSE[n][0] and brick.transform.is_equal_approx(gone))
			if back and _builder.history_depth() == depth - 1:
				out["edits"] = int(out["edits"]) + 1
				_note("undo: the round brick is back")
			else:
				out["edit_wrong"] = int(out["edit_wrong"]) + 1
				_note("undo: not back as it was")
			continue
		var brick_was: BrickWorld.Brick = _world.get_brick(id)
		if brick_was == null:
			continue
		var was: Transform3D = brick_was.transform
		var count_was: int = _world.brick_count()
		# The part found and tapped: up to three tries, as a person retries.
		var picked: bool = false
		for attempt: int in 3:
			_rng.seed = int(walker["seed"]) * 1000 + 800 + n * 10 + attempt
			var view: Transform3D = _camera.global_transform
			var counted: Dictionary = (_simple.get("counts") as Dictionary).duplicate()
			var target: Vector2 = _top_point(id)
			var at: Vector2 = _landed(target, float(walker["sigma"]))
			_seconds += _fitts(_rest, Rect2(target - Vector2.ONE * 15.0, Vector2.ONE * 30.0)) + TAP
			await _tap_at(at)
			_rest = at
			out["touches"] = int(out["touches"]) + 1
			await _frames(3)
			if _view_moved(view):
				out["edit_unwanted_camera"] = int(out["edit_unwanted_camera"]) + 1
				_note("%s: the tap on brick %d turned the view" % [what, n + 1])
				await _recover(out)
			if (_simple.get("counts") as Dictionary)["moved"] != counted["moved"]:
				out["edit_wrong"] = int(out["edit_wrong"]) + 1
				_note("%s: the tap moved a part" % what)
				await _undo_by_button(walker, out)
			if _builder.selection.size() == 1 and _builder.selection.has(id):
				picked = true
				break
			_seconds += NOTICE
			_note("%s: the tap on brick %d selected %s" % [what, n + 1, str(_builder.selection.keys())])
		if not picked:
			_note("%s: gave up finding brick %d" % [what, n + 1])
			continue
		var done: bool = false
		if what == "turn":
			var facing: Vector3 = was.basis.x
			await _press_named("turn", walker, out)
			var now: BrickWorld.Brick = _world.get_brick(id)
			done = now != null and absf(absf(rad_to_deg(facing.signed_angle_to(now.transform.basis.x, Vector3.UP))) - 90.0) < 0.5
		elif what == "paint":
			var swatch: Control = (_simple.call("controls_by_name") as Dictionary)["simple_colour_25"]
			var at: Vector2 = _landed(swatch.get_global_rect().get_center(), float(walker["sigma"]))
			_seconds += SCAN * 2.0 + _fitts(_rest, swatch.get_global_rect()) + TAP
			await _tap_at(at)
			_rest = at
			out["touches"] = int(out["touches"]) + 1
			await _frames(3)
			var now: BrickWorld.Brick = _world.get_brick(id)
			done = now != null and now.color_code == 25
		elif what == "delete":
			gone = was
			if str(walker["fix"]) == "drag":
				var from: Vector2 = _top_point(id)
				_touch(0, from, true)
				await process_frame
				await _drag_along(0, from, from + Vector2(0, -Phone.px(root, 24.0)), 4)
				await _frames(2)
				var bin: Button = _simple.call("button", "bin")
				var to: Vector2 = _landed(bin.get_global_rect().get_center(), float(walker["sigma"]))
				await _drag_along(0, from + Vector2(0, -Phone.px(root, 24.0)), to, 10)
				_seconds += LOOK + _fitts(from, bin.get_global_rect())
				_touch(0, to, false)
				_rest = to
				out["touches"] = int(out["touches"]) + 1
				await _frames(4)
				_note("delete: dragged to the bin")
			else:
				await _press_named("delete", walker, out)
			done = _world.get_brick(id) == null and _world.brick_count() == count_was - 1
		if done:
			out["edits"] = int(out["edits"]) + 1
			_note("%s: brick %d done" % [what, n + 1])
		else:
			out["edit_wrong"] = int(out["edit_wrong"]) + 1
			_note("%s: brick %d not done" % [what, n + 1])
		await _seat_done()
	out["edit_seconds"] = snappedf(_seconds - started, 0.1)
	out["edit_touches"] = int(out["touches"]) - touches


## A round button of Simple's found by a look and tapped as a finger lands.
func _press_named(what: String, walker: Dictionary, out: Dictionary) -> void:
	var button: Button = _simple.call("button", what)
	if button == null or not button.is_visible_in_tree():
		_note("%s: no %s button shown" % [what, what])
		return
	var at: Vector2 = _landed(button.get_global_rect().get_center(), float(walker["sigma"]))
	_seconds += SCAN * 3.0 + _fitts(_rest, button.get_global_rect()) + TAP
	await _tap_at(at)
	_rest = at
	out["touches"] = int(out["touches"]) + 1
	await _frames(3)
	_note("%s pressed" % what)


## After a tap on the model: its ghost, shown where the tap landed, looked
## at; right, a tap on it puts it down; off, a drag from it carries it there,
## put right while the finger is down as a drag out of the tray is, and let
## go. A tap that misses the ghost shows it where it landed instead, and it
## is looked at again.
func _tapped_ghost_down(walker: Dictionary, ideal: Variant, out: Dictionary) -> void:
	var sigma: float = float(walker["sigma"])
	var nudges: int = int(walker["nudges"])
	for look: int in nudges + 3:
		_seconds += LOOK
		if not bool(_simple.call("ghost_waits")):
			return
		var shown: Rect2 = _simple.call("ghost_rect")
		var off: Vector2 = _ghost_off(ideal)
		var on: Vector2 = _landed(shown.get_center(), sigma)
		_seconds += _fitts(_rest, shown)
		out["touches"] = int(out["touches"]) + 1
		if off == Vector2.ZERO or look > nudges:
			await _tap_at(on)
			_seconds += TAP
			_rest = on
			await _frames(2)
			continue
		var lift: float = Phone.px(root, float(_simple.get("lift_points")))
		var finger: Vector2 = on + off + Vector2(0, lift) + _noise(sigma * 0.5)
		_touch(0, on, true)
		await process_frame
		await _drag_along(0, on, finger, 8)
		await _frames(2)
		_seconds += FITTS_A + FITTS_B * log(off.length() / Phone.px(root, 8.0) + 1.0) / log(2.0)
		for nudge: int in nudges:
			_seconds += LOOK
			var still: Vector2 = _ghost_off(ideal)
			if still == Vector2.ZERO or _hidden_by_finger(finger):
				break
			var to: Vector2 = finger + still + _noise(sigma * 0.5)
			await _drag_along(0, finger, to, 4)
			_seconds += FITTS_A + FITTS_B * log(still.length() / Phone.px(root, 8.0) + 1.0) / log(2.0)
			finger = to
		_touch(0, finger, false)
		_rest = finger
		await _frames(3)
		return


func _note(words: String) -> void:
	_walk_log.append("%5.1f s  %s" % [_seconds, words])


## One brick of the house: chosen colour, out of the tray (by a drag, or a tap
## and a tap), aimed by the ghost, let go. {ok, down, id, ideal}.
func _place_one(walker: Dictionary, n: int, how: String, slip: bool, out: Dictionary) -> Dictionary:
	var plan: Array = HOUSE[n]
	var part: String = plan[0]
	var colour: int = plan[1]
	if slip:
		colour = 1 if colour != 1 else 4
	_seconds += MENTAL
	_simple.set("last_drop", {})
	var aim: Vector2 = _intent_point(plan)
	var ideal: Variant = _ideal(part, colour, aim)
	if ideal == null:
		# Where it goes is off the screen or behind the tray: the model
		# framed again by Fit, the one control that says it does that.
		_note("brick %d: its place is out of sight, Fit pressed" % (n + 1))
		await _recover(out)
		return {"ok": false}
	if int(_simple.call("chosen_colour")) != colour:
		var swatch: Control = (_simple.call("controls_by_name") as Dictionary)["simple_colour_%d" % colour]
		var at: Vector2 = _landed(swatch.get_global_rect().get_center(), float(walker["sigma"]))
		_seconds += _fitts(_rest, swatch.get_global_rect()) + TAP
		await _tap_at(at)
		_rest = at
		out["touches"] = int(out["touches"]) + 1
	var view: Transform3D = _camera.global_transform
	var before: int = _world.brick_count()
	# Its group's tab first, where another group is showing: found by a
	# look along the five, tapped as a finger lands.
	var group: int = _group_of(part)
	if group != int(_simple.call("shown_group")):
		var tab: Control = (_simple.call("controls_by_name") as Dictionary)[
			"simple_group_%s" % str(SimpleLayer.GROUPS[group][0]).to_lower()]
		var at: Vector2 = _landed(tab.get_global_rect().get_center(), float(walker["sigma"]))
		_seconds += SCAN * 2.0 + _fitts(_rest, tab.get_global_rect()) + TAP
		await _tap_at(at)
		_rest = at
		out["touches"] = int(out["touches"]) + 1
		if int(_simple.call("shown_group")) != group:
			_seconds += NOTICE
			_note("brick %d: the tap for %s missed its tab" % [n + 1, SimpleLayer.GROUPS[group][0]])
			return {"ok": false}
	var tile: Control = _simple.call("tile_of", part)
	var tile_rect: Rect2 = tile.get_global_rect()
	var start: Vector2
	if _rng.randf() < float(walker["edge"]):
		start = Vector2(tile_rect.get_center().x, tile_rect.position.y) + _noise(float(walker["sigma"]) * 1.4)
	else:
		start = _landed(tile_rect.get_center(), float(walker["sigma"]))
	_seconds += _fitts(_rest, tile_rect)
	out["touches"] = int(out["touches"]) + 1
	var on: String = _what_is_at(start)
	var lift: float = Phone.px(root, float(_simple.get("lift_points")))
	if how == "tap":
		await _tap_at(start)
		_seconds += TAP
		if str(_simple.call("chosen_brick")) != part:
			_seconds += NOTICE
			_note("brick %d: the tap on the tray landed on %s" % [n + 1, on])
			await _undo_tray_choice()
			return {"ok": false}
		var target: Vector2 = _landed(aim, float(walker["sigma"]))
		_seconds += _fitts(start, Rect2(aim - Vector2.ONE * _ghost_size(ideal) * 0.5, Vector2.ONE * _ghost_size(ideal))) + TAP
		await _tap_at(target)
		_rest = target
		out["touches"] = int(out["touches"]) + 1
		await _frames(2)
		await _tapped_ghost_down(walker, ideal, out)
		# A tapper tapped the tray again to let it go, once a brick is down.
		await _undo_tray_choice()
	else:
		var finger: Vector2 = aim + Vector2(0, lift)
		_touch(0, start, true)
		await process_frame
		await _drag_along(0, start, finger, 12)
		await _frames(2)
		if on != "tile " + part:
			# Not the brick meant: no ghost of it, or a ghost of another.
			_touch(0, finger, false)
			await _frames(3)
			var moved_view: bool = _view_moved(view)
			_seconds += _fitts(start, Rect2(finger, Vector2.ONE)) + NOTICE
			if moved_view:
				out["unwanted_camera"] = int(out["unwanted_camera"]) + 1
				_note("brick %d: the drag began on %s and turned the view" % [n + 1, on])
				await _shot_walk("unwanted_%d" % (n + 1))
				await _recover(out)
			else:
				_note("brick %d: the drag began on %s" % [n + 1, on])
			if _world.brick_count() > before:
				out["wrong"] = int(out["wrong"]) + 1
				_note("brick %d: %s went down instead" % [n + 1, on])
				await _undo_by_button(walker, out)
			return {"ok": false}
		_seconds += _fitts(start, Rect2(aim - Vector2.ONE * _ghost_size(ideal) * 0.5, Vector2.ONE * _ghost_size(ideal)))
		# The ghost, looked at and put right while the finger is down.
		for nudge: int in int(walker["nudges"]) + 1:
			_seconds += LOOK
			var off: Vector2 = _ghost_off(ideal)
			if off == Vector2.ZERO:
				break
			if _hidden_by_finger(finger) or nudge == int(walker["nudges"]):
				break
			var to: Vector2 = finger + off + _noise(float(walker["sigma"]) * 0.5)
			await _drag_along(0, finger, to, 4)
			_seconds += FITTS_A + FITTS_B * log(off.length() / Phone.px(root, 8.0) + 1.0) / log(2.0)
			finger = to
		if n == 0:
			await _shot_walk("ghost")
		_touch(0, finger, false)
		_rest = finger
		await _frames(3)
	var drop: Dictionary = _simple.get("last_drop")
	var put: Array = drop.get("put", [])
	if put.is_empty():
		out["refused"] = int(out["refused"]) + 1
		_seconds += NOTICE
		_note("brick %d: nothing went down (%s)" % [n + 1, drop.get("why", "?")])
		return {"ok": false}
	var id: int = int(put[0])
	var brick: BrickWorld.Brick = _world.get_brick(id)
	if brick == null:
		out["refused"] = int(out["refused"]) + 1
		_seconds += NOTICE
		_note("brick %d: nothing stayed down" % (n + 1))
		return {"ok": false}
	_placed[n] = id
	var right: bool = brick != null and brick.part_id == part and brick.color_code == int(plan[1]) \
		and brick.transform.origin.distance_to((ideal as Transform3D).origin) < 1.0
	if not right:
		out["wrong"] = int(out["wrong"]) + 1
		_seconds += NOTICE
		_note("brick %d (%s): landed wrong: %s" % [n + 1, part, _how_wrong(brick, ideal as Transform3D, int(plan[1]))])
		if how == "tap":
			# Where the tap was aimed and where the ghost stood, against
			# the place meant: whether the finger missed, or the tap put
			# it elsewhere than the same aim's ghost.
			var ghost: Variant = drop.get("ghost")
			_note("    the tap: meant at %s, aimed at %s; the ghost at %s, meant %s, turned %s" % [
				str(aim.round()), str((drop.get("aimed", Vector2.ZERO) as Vector2).round()),
				str((ghost as Transform3D).origin) if ghost is Transform3D else "none",
				str((ideal as Transform3D).origin),
				str(not brick.transform.basis.is_equal_approx((ideal as Transform3D).basis))])
		_placed.erase(n)
		return {"ok": false, "down": true, "id": id, "ideal": ideal, "colour": brick.color_code != int(plan[1])}
	_note("brick %d (%s) down" % [n + 1, part])
	return {"ok": true, "id": id}


## A brick down but wrong, put right by the walker's way: Undo found and
## pressed, or the brick dragged to where it was meant. Then placed again
## by the caller where Undo took it.
func _fix(walker: Dictionary, n: int, result: Dictionary, out: Dictionary) -> bool:
	if str(walker["fix"]) == "undo" or bool(result.get("colour", false)):
		await _undo_by_button(walker, out)
		return false
	# Dragged where it was meant.
	var id: int = int(result["id"])
	match await _drag_to(walker, "brick %d" % (n + 1), id, result["ideal"], out):
		"moved":
			_placed[n] = id
			return true
		"nothing":
			# Undo, then.
			await _undo_by_button(walker, out)
		"elsewhere":
			await _undo_by_button(walker, out)
			await _undo_by_button(walker, out)
	return false


## A brick on the model taken by a finger and dragged to [param ideal], the
## ghost watched and put right as a tray's brick's is: "moved" there,
## "nothing" moved, or moved "elsewhere". A grab that misses and turns the
## view is an unwanted camera move, and the model is framed again by Fit.
func _drag_to(walker: Dictionary, what: String, id: int, ideal: Transform3D, out: Dictionary) -> String:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	if brick == null:
		return "nothing"
	var others: Dictionary = {}
	for other: BrickWorld.Brick in _world.bricks():
		if other.id != id:
			others[other.id] = other.transform
	var view: Transform3D = _camera.global_transform
	var grab: Vector2 = _landed(_top_point(id), float(walker["sigma"]))
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var meant_box: AABB = ideal * part.bounds
	var meant: Vector2 = _camera.unproject_position(meant_box.get_center())
	var lift: float = Phone.px(root, float(_simple.get("lift_points")))
	var finger: Vector2 = meant + Vector2(0, lift)
	_seconds += MENTAL * 0.5 + _fitts(_rest, Rect2(grab - Vector2.ONE * 6, Vector2.ONE * 12))
	out["touches"] = int(out["touches"]) + 1
	var was: Transform3D = brick.transform
	_touch(0, grab, true)
	await process_frame
	await _drag_along(0, grab, finger, 14)
	await _frames(2)
	# Its ghost watched and put right, as a part from the tray is.
	for nudge: int in int(walker["nudges"]) + 1:
		_seconds += LOOK
		if not _builder.is_carrying() or nudge == int(walker["nudges"]):
			break
		var now: AABB = _builder.carrying.bounds_moved(Transform3D.IDENTITY)
		if now.get_center().distance_to(meant_box.get_center()) < 1.0 or _hidden_by_finger(finger, now):
			break
		var off: Vector2 = meant - _camera.unproject_position(now.get_center())
		var to: Vector2 = finger + off + _noise(float(walker["sigma"]) * 0.5)
		await _drag_along(0, finger, to, 4)
		_seconds += FITTS_A + FITTS_B * log(off.length() / Phone.px(root, 8.0) + 1.0) / log(2.0)
		finger = to
	_touch(0, finger, false)
	await _frames(2)
	_rest = finger
	await _frames(3)
	var turned: bool = _view_moved(view)
	if turned:
		out["unwanted_camera"] = int(out["unwanted_camera"]) + 1
		_note("%s: the grab missed it and turned the view" % what)
		await _shot_walk("unwanted_" + what.replace(" ", "_"))
		await _recover(out)
	brick = _world.get_brick(id)
	var moved_other: bool = false
	for other: int in others:
		var now: BrickWorld.Brick = _world.get_brick(other)
		if now == null or not now.transform.is_equal_approx(others[other]):
			moved_other = true
	if moved_other:
		_seconds += NOTICE
		_note("%s: the grab took the part beside it, moved instead" % what)
		return "elsewhere"
	if brick == null or brick.transform.is_equal_approx(was):
		_seconds += NOTICE
		if not turned:
			_note("%s: the drag moved nothing" % what)
		return "nothing"
	if brick.transform.origin.distance_to(ideal.origin) < 1.0:
		_note("%s: dragged where it was meant" % what)
		return "moved"
	_seconds += NOTICE
	_note("%s: dragged, not where meant" % what)
	return "elsewhere"


## The round brick on top moved a stud and back, as a newcomer puts right
## what is already down: the smallest part to take with a finger, where a
## miss is the view turned (A) or nothing, or the part under it (B).
const MOVES: Array = [[9, -1.0, 0.0], [9, 1.0, 0.0]]


func _move_task(walker: Dictionary, out: Dictionary) -> void:
	var started: float = _seconds
	var unwanted: int = int(out["unwanted_camera"])
	out["moves"] = 0
	for move: Array in MOVES:
		var n: int = int(move[0])
		if not _placed.has(n):
			continue
		var id: int = int(_placed[n])
		for attempt: int in 3:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick == null:
				break
			_rng.seed = int(walker["seed"]) * 1000 + 500 + n * 10 + attempt + 3 * int(out["moves"])
			_seconds += MENTAL
			var ideal: Transform3D = brick.transform.translated(Vector3(float(move[1]) * 20.0, 0.0,
				float(move[2]) * 20.0))
			var how: String = await _drag_to(walker, "move %d of brick %d" % [int(out["moves"]) + 1, n + 1],
				id, ideal, out)
			if how == "moved":
				out["moves"] = int(out["moves"]) + 1
				break
			if how == "elsewhere":
				await _undo_by_button(walker, out)
	out["move_seconds"] = snappedf(_seconds - started, 0.1)
	out["move_unwanted_camera"] = int(out["unwanted_camera"]) - unwanted


## Undo, found by looking from where the finger last was outward, control by
## control, and pressed.
func _undo_by_button(walker: Dictionary, out: Dictionary) -> void:
	var looked: int = 0
	var found: Button = null
	var controls: Array = _visible_buttons()
	controls.sort_custom(func(a: Control, b: Control) -> bool:
		return a.get_global_rect().get_center().distance_to(_rest) < b.get_global_rect().get_center().distance_to(_rest))
	for control: Control in controls:
		looked += 1
		if str(control.name).contains("undo") or str(control.accessibility_name) == "Undo":
			found = control
			break
		if looked >= 20:
			break
	if out["undo_found"] == null:
		out["undo_found"] = found != null
		out["undo_looked"] = looked
		out["undo_was"] = str(found.name) if found != null else ""
	_seconds += SCAN * looked
	if found == null:
		_note("looked for Undo at %d controls and found none" % looked)
		return
	var at: Vector2 = _landed(found.get_global_rect().get_center(), float(walker["sigma"]))
	_seconds += _fitts(_rest, found.get_global_rect()) + TAP
	await _tap_at(at)
	_rest = at
	out["touches"] = int(out["touches"]) + 1
	await _frames(4)
	_note("Undo (%s, the %d%s looked at)" % [found.name, looked, _nth(looked)])


## After the view moved unasked: seen, then Fit, then a moment to find the
## place again.
func _recover(out: Dictionary) -> void:
	var fit: Control = _simple.call("button", "fit")
	_seconds += NOTICE + _fitts(_rest, fit.get_global_rect()) + TAP + MENTAL
	await _press_fit()
	out["touches"] = int(out["touches"]) + 1
	_rest = fit.get_global_rect().get_center()


## The view wanted from another side: one finger dragged across empty space
## first, as everyone tries; where that turns nothing, two.
func _wanted_turn(walker: Dictionary, out: Dictionary) -> void:
	var view: Transform3D = _camera.global_transform
	var from: Vector2 = _empty_point()
	var by := Vector2(Phone.px(root, 110.0), 0.0)
	_seconds += MENTAL * 0.5 + _fitts(_rest, Rect2(from - Vector2.ONE * 30, Vector2.ONE * 60)) + ONE_FINGER_TURN
	out["wanted_camera_tries"] = int(out["wanted_camera_tries"]) + 1
	out["touches"] = int(out["touches"]) + 1
	var counted: Dictionary = (_simple.get("counts") as Dictionary).duplicate()
	await _one_finger(from, from + by)
	await _settle()
	if (_simple.get("counts") as Dictionary)["moved"] != counted["moved"]:
		_note("wanted the view turned: the finger moved a part instead")
		out["wrong"] = int(out["wrong"]) + 1
		await _undo_by_button(walker, out)
	if not _view_moved(view):
		_seconds += NOTICE + (LOOK * 2.0 if _said().to_lower().contains("two fingers") else MENTAL)
		_note("one finger did not turn the view (said \"%s\"); two" % _said())
		await _two_fingers(from, from + Vector2(Phone.px(root, 60.0), 0.0), by, 1.0)
		await _settle()
		_seconds += TWO_FINGER_GESTURE
		out["wanted_camera_tries"] = int(out["wanted_camera_tries"]) + 1
		out["touches"] = int(out["touches"]) + 1
	var turned: bool = _view_moved(view)
	_note("view turned to look from the side: %s" % ("yes" if turned else "no"))
	await _shot_walk("turned")


func _wanted_zoom(_walker: Dictionary, out: Dictionary) -> void:
	_seconds += MENTAL * 0.5 + TWO_FINGER_GESTURE
	out["touches"] = int(out["touches"]) + 1
	await _two_fingers(_base_point(-0.08, 0.0), _base_point(0.08, 0.0), Vector2.ZERO, 1.8)
	await _settle()
	_note("pinched in: the bricks looked small")


func _undo_tray_choice() -> void:
	var chosen: String = str(_simple.call("chosen_brick"))
	if chosen.is_empty():
		return
	var tile: Control = _simple.call("tile_of", chosen)
	await _tap_at(tile.get_global_rect().get_center())
	_seconds += TAP + FITTS_A


# -- what a walker sees and aims at --------------------------------------------------------


## Where the walker means the brick's ghost to stand, on the screen: the top
## of what it goes on, offset by the plan's studs.
func _intent_point(plan: Array) -> Vector2:
	var on: int = int(plan[2])
	var top: Vector3
	if on < 0:
		var floor: AABB = _floor_box()
		top = Vector3(floor.get_center().x, floor.end.y, floor.get_center().z)
	else:
		if not _placed.has(on):
			return _base_point(0.0, 0.0)
		var box: AABB = _box_of(int(_placed[on]))
		top = Vector3(box.get_center().x, box.end.y, box.get_center().z)
	top += Vector3(float(plan[3]) * 20.0, 0.0, float(plan[4]) * 20.0)
	return _camera.unproject_position(top)


## Where the ghost stands aimed exactly at [param at], the brick in hand:
## what a perfect finger would put down. Null where nothing could go.
func _ideal(part: String, colour: int, at: Vector2) -> Variant:
	var held: String = _builder.held_part
	var held_colour: int = _builder.held_color
	var mode: String = _verbs.mode
	# Taken as the tray takes it (SimpleLayer._take): a part chosen afresh
	# is held by its own point, and set by hand it kept the last one's.
	if _builder.held_part != part or _verbs.mode != "place":
		_main.call("_on_part_chosen", part)
	_builder.held_color = colour
	_main.call("_aim_at", at)
	var ideal: Variant = _builder.ghost_transform() if _builder.can_place() else null
	_builder.hide_preview()
	_builder.held_part = held
	_builder.held_color = held_colour
	_verbs.set_mode(mode)
	return ideal


## How far, on the screen, the ghost is from where it was meant: the nudge
## that puts it there. Zero when it is there.
func _ghost_off(ideal: Variant) -> Vector2:
	if not _builder.has_preview():
		return Vector2.ZERO
	var ghost: Transform3D = _builder.ghost_transform()
	var meant: Transform3D = ideal
	if ghost.origin.distance_to(meant.origin) < 1.0:
		return Vector2.ZERO
	return _camera.unproject_position(meant.origin) - _camera.unproject_position(ghost.origin)


## Whether the fingertip at [param finger] hides most of the ghost: the
## fingertip's disc and the finger below it, over the ghost's box on the
## screen, sampled.
func _hidden_by_finger(finger: Vector2, carried: AABB = AABB()) -> bool:
	if not _builder.has_preview():
		return true
	var box: Rect2 = _screen_box(_ghost_box() if carried.size == Vector3.ZERO else carried)
	var tip: float = Phone.px(root, FINGERTIP)
	var hidden: int = 0
	var all: int = 0
	for i: int in 6:
		for j: int in 6:
			var at: Vector2 = box.position + box.size * Vector2((i + 0.5) / 6.0, (j + 0.5) / 6.0)
			all += 1
			if at.distance_to(finger) < tip or (absf(at.x - finger.x) < tip * 0.8 and at.y > finger.y):
				hidden += 1
	return hidden * 2 > all


func _ghost_box() -> AABB:
	var part: Lbm.PartMesh = _library.mesh_for(_builder.held_part)
	return _builder.ghost_transform() * part.bounds if part != null else AABB()


func _ghost_size(ideal: Variant) -> float:
	var part: Lbm.PartMesh = _library.mesh_for(_builder.held_part)
	if part == null or ideal == null:
		return Phone.px(root, 20.0)
	var rect: Rect2 = _screen_box((ideal as Transform3D) * part.bounds)
	return maxf(minf(rect.size.x, rect.size.y), 4.0)


func _screen_box(box: AABB) -> Rect2:
	var rect := Rect2(_camera.unproject_position(box.position), Vector2.ZERO)
	for n: int in 8:
		rect = rect.expand(_camera.unproject_position(box.get_endpoint(n)))
	return rect


func _how_wrong(brick: BrickWorld.Brick, ideal: Transform3D, colour: int) -> String:
	if brick == null:
		return "nothing"
	var by: Vector3 = brick.transform.origin - ideal.origin
	var words: Array = []
	if brick.color_code != colour:
		words.append("colour %d, not %d" % [brick.color_code, colour])
	if by.length() >= 1.0:
		words.append("%.0f, %.0f, %.0f studs off" % [by.x / 20.0, by.y / 8.0, by.z / 20.0])
	return ", ".join(words) if not words.is_empty() else "another part"


func _what_is_at(at: Vector2) -> String:
	# A press in a gap or at the tray's edge is the nearest tile's.
	var tile: Control = _simple.call("tile_at", at)
	if tile != null:
		return "tile " + str(tile.get_meta("part"))
	if bool(_main.call("_over_panel_at", at)):
		return "the tray's edge"
	return "the model's room above the tray"


func _visible_buttons() -> Array:
	var out: Array = []
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for found: Node in root.find_children("*", "Button", true, false):
		var button: Button = found
		if button.is_visible_in_tree() and screen.intersects(button.get_global_rect()) \
				and button.get_global_rect().size.x > 4.0:
			out.append(button)
	# A tile of the tray is a control too, looked at as one.
	for tile: Control in _simple.get("_tiles"):
		out.append(tile)
	return out


static func _nth(n: int) -> String:
	return "st" if n % 10 == 1 and n != 11 else "nd" if n % 10 == 2 and n != 12 \
		else "rd" if n % 10 == 3 and n != 13 else "th"


static func _on_grid(ldu: float) -> bool:
	return absf(ldu / 10.0 - roundf(ldu / 10.0)) < 0.01


func _fitts(from: Vector2, target: Rect2) -> float:
	var width: float = maxf(minf(target.size.x, target.size.y), 1.0) / Phone.per_point(root)
	var distance: float = from.distance_to(target.get_center()) / Phone.per_point(root)
	return FITTS_A + FITTS_B * log(distance / width + 1.0) / log(2.0)


func _landed(at: Vector2, sigma: float) -> Vector2:
	return at + _noise(sigma)


func _noise(sigma: float) -> Vector2:
	return Vector2(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * Phone.px(root, sigma)


# -- the model and the view ------------------------------------------------------------------


## An empty baseplate, nothing to undo, nothing chosen, the view a first
## visit's.
func _fresh() -> void:
	_main.call("clear_model")
	await _frames(4)
	_builder.clear_selection()
	_builder.forget_history()
	_builder.locked.clear()
	# As New does in Simple: the sketch's plate (SimpleLayer.new_sketch).
	_simple.call("new_sketch")
	await _frames(4)
	if not str(_simple.call("chosen_brick")).is_empty():
		_simple.call("_tap_tile", str(_simple.call("chosen_brick")))
	_simple.call("_on_swatch", 4)
	_camera.set_view("default")
	await _settle()
	# Framed as a new model opens, not at the last check's zoom: the
	# tablet's walks began a stud's width from the plate (walk 2).
	await _press_fit()
	_say_nothing()


## A brick of the tray dragged to [param at] and let go: its id, 0 for none.
func _put(part: String, colour: int, at: Vector2) -> int:
	if int(_simple.call("chosen_colour")) != colour:
		await _press_swatch(colour)
	var tile: Control = _simple.call("tile_of", part)
	var from: Vector2 = tile.get_global_rect().get_center()
	var finger: Vector2 = at + Vector2(0, Phone.px(root, float(_simple.get("lift_points"))))
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, finger, 10)
	_touch(0, finger, false)
	await _frames(3)
	var put: Array = (_simple.get("last_drop") as Dictionary).get("put", [])
	return int(put[0]) if not put.is_empty() else 0


func _press_swatch(colour: int) -> void:
	var swatch: Control = (_simple.call("controls_by_name") as Dictionary)["simple_colour_%d" % colour]
	await _tap_at(swatch.get_global_rect().get_center())
	await _frames(2)


func _press_fit() -> void:
	var fit: Control = _simple.call("button", "fit")
	await _tap_at(fit.get_global_rect().get_center())
	await _settle()


func _floor_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for id: Variant in _store.scenery:
		var one: AABB = _box_of(int(id))
		box = one if first else box.merge(one)
		first = false
	return box if not first else AABB(Vector3(-320, -8, -320), Vector3(640, 8, 640))


func _box_of(id: int) -> AABB:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	if brick == null:
		return AABB()
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	return brick.transform * part.bounds if part != null else AABB(brick.transform.origin, Vector3.ONE)


func _height_of(part_id: String) -> float:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	return part.bounds.end.y if part != null else 24.0


## A point of the baseplate's top, [param x] and [param z] shares of the way
## from its middle to its edges, on the screen.
func _base_point(x: float, z: float) -> Vector2:
	var floor: AABB = _floor_box()
	var at := Vector3(floor.get_center().x + x * floor.size.x * 0.5, floor.end.y,
		floor.get_center().z + z * floor.size.z * 0.5)
	return _camera.unproject_position(at)


## The middle of a brick's top, on the screen.
func _top_point(id: int) -> Vector2:
	var box: AABB = _box_of(id)
	return _camera.unproject_position(Vector3(box.get_center().x, box.end.y, box.get_center().z))


## A point [param points] beside a brick's picture, off it.
func _beside(id: int, points: float) -> Vector2:
	var rect: Rect2 = _screen_box(_box_of(id))
	var room: Rect2 = _camera.seen_rect()
	# A point of its picture: sampled over its box until one is the part.
	var middle := Vector2.INF
	for step: int in 81:
		var at: Vector2 = rect.position + rect.size * Vector2((step % 9 + 0.5) / 9.0, (step / 9 + 0.5) / 9.0)
		if _verbs.brick_at(at) == id:
			middle = at
			if absf(at.x - rect.get_center().x) < rect.size.x * 0.2:
				break
	if not (middle.x < INF):
		return Vector2.INF
	# Out from there each way to its picture's edge, then the points beyond
	# it: the first side in the model's room.
	for way: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var at: Vector2 = middle
		for _n: int in 400:
			if _verbs.brick_at(at) != id:
				break
			at += way * 2.0
		at += way * Phone.px(root, points)
		if room.grow(-Phone.px(root, 8.0)).has_point(at) and _verbs.brick_at(at) == 0:
			return at
	return Vector2.INF


## Empty space in the model's room: away from every part, over the
## baseplate's far corner or the sky.
func _empty_point() -> Vector2:
	var room: Rect2 = _camera.seen_rect()
	for spot: Vector2 in [Vector2(0.18, 0.2), Vector2(0.82, 0.2), Vector2(0.18, 0.55), Vector2(0.82, 0.55)]:
		var at: Vector2 = room.position + room.size * spot
		var clear: bool = true
		for ring: float in [0.0, 30.0, 45.0]:
			for turn: int in 8:
				if _verbs.brick_at(at + Vector2.from_angle(TAU * turn / 8.0) * Phone.px(root, ring)) != 0:
					clear = false
		if clear:
			return at
	return room.position + room.size * Vector2(0.18, 0.2)


func _seen_middle() -> Vector2:
	return _camera.seen_rect().get_center()


func _open(path: String) -> bool:
	var real: String = ProjectSettings.globalize_path(path)
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", real)
	for _n: int in 900:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not _store.laying:
			break
	await _frames(30)
	_builder.clear_selection()
	return _world.brick_count() > 0


# -- fingers ---------------------------------------------------------------------------------


func _tap_at(at: Vector2) -> void:
	_touch(0, at, true)
	await process_frame
	_drag(0, at + Vector2(1.5, -1.0), Vector2(1.5, -1.0))
	await process_frame
	_touch(0, at + Vector2(1.5, -1.0), false)
	await process_frame
	await process_frame


func _one_finger(from: Vector2, to: Vector2) -> void:
	_touch(0, from, true)
	await process_frame
	await _drag_along(0, from, to, 14)
	await _frames(2)
	_touch(0, to, false)
	await _frames(2)


## Two fingers [param a] and [param b], moved together by [param by] and
## spread by [param spread] times, a frame at a time, and lifted.
func _two_fingers(a: Vector2, b: Vector2, by: Vector2, spread: float) -> void:
	_touch(0, a, true)
	_touch(1, b, true)
	await process_frame
	var middle: Vector2 = (a + b) * 0.5
	var was_a: Vector2 = a
	var was_b: Vector2 = b
	var steps: int = 14
	for n: int in steps:
		var t: float = smoothstep(0.0, 1.0, float(n + 1) / steps)
		var grow: float = lerpf(1.0, spread, t)
		var now_a: Vector2 = middle + (a - middle) * grow + by * t
		var now_b: Vector2 = middle + (b - middle) * grow + by * t
		_drag(0, now_a, now_a - was_a)
		_drag(1, now_b, now_b - was_b)
		was_a = now_a
		was_b = now_b
		await process_frame
	_touch(0, was_a, false)
	_touch(1, was_b, false)
	await _frames(2)


## One finger moved from [param from] to [param to] in [param steps] frames.
func _drag_along(index: int, from: Vector2, to: Vector2, steps: int) -> void:
	var was: Vector2 = from
	for n: int in steps:
		var now: Vector2 = from.lerp(to, smoothstep(0.0, 1.0, float(n + 1) / steps))
		_drag(index, now, now - was)
		was = now
		await process_frame


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _drag(index: int, at: Vector2, by: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _as_event(at)
	drag.relative = _as_event(by)
	Input.parse_input_event(drag)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _said() -> String:
	return str(_simple.get("_said")) if Time.get_ticks_msec() < int(_simple.get("_said_until")) else ""


func _say_nothing() -> void:
	_simple.set("_said", "")
	_simple.set("_said_until", 0)


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


## The seat's drop over: no part drawn away from where it stands, or a
## second gone. Waited by the clock, as the seat runs by it (SimpleLayer's
## SEAT_MS): a count of frames was over before it on a fast GPU (r4). Its
## milliseconds.
func _seat_done() -> int:
	var from: int = Time.get_ticks_msec()
	while not _world.drawn_ids().is_empty() and Time.get_ticks_msec() - from < 1000:
		await process_frame
	return Time.get_ticks_msec() - from


## Whether the view moved as a person sees it: over half an LDU, or a
## thousandth of a turn. Not the last of an ease settling, which an exact
## compare counted (r4: 0.00 LDU, 0.0000 of a turn, "moved").
func _view_moved(from: Transform3D) -> bool:
	var now: Transform3D = _camera.global_transform
	return now.origin.distance_to(from.origin) > 0.5 \
		or now.basis.get_rotation_quaternion().angle_to(from.basis.get_rotation_quaternion()) > TAU * 0.001


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var layout: String = "desktop" if _desktop else ("tablet" if _tablet else "phone")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_pictures)
		+ "%s_%s_%s_%s.png" % [_size, layout, "full" if _full else _map, name])


func _shot_walk(name: String) -> void:
	_shot_n += 1
	await _shot("walk_%s_%02d_%s" % [_tag, _shot_n, name])
