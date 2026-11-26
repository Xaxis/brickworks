## handkeep2: every path in or out of the hand goes through the hand. What
## figreview3's probe does not drive, on the same models: a part lifted by X
## turned with the model, let go of by a part from the bin, by the person's
## Undo and kept through a session's; the cells of what is in hand still in
## the way of everything but the hand; and the run-time guard
## (BrickWorld.round_the_hand) at nought after all of it, and counting a write
## made round the hand on purpose.
##
##   godot --path . --resolution 1280x720 --script src/dev/handkeep2_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh handkeep2_probe                every case
##   PROBE_SIZE=1280x720 tools/probe.sh handkeep2_probe --case=xturn   one case
##
## --case= xturn, xbin, xundo, cells, guard (all when not said).
##   xturn  X over one plain part, the model turned (Shift+E), Escape pressed:
##          where it stands against the rest, and what the lattice holds there.
##   xbin   X over one plain part, then a figure lifted, each let go of by a
##          part chosen from the bin.
##   xundo  X over one plain part: the person's Undo puts it back, recording
##          nothing; after a session's paint, the session's undo takes the
##          paint back and leaves the part in hand.
##   cells  a figure in hand: where it stood is in the way of a part, not of
##          the figure's own ghost.
##   guard  BrickWorld.round_the_hand is nought after every case, and a write
##          to a held part's place made round the hand counts one.
## Exits non-zero when a check fails.
extends "res://src/dev/figreview3_probe.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("handkeep2_probe: needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.substr(7)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	_layout = "phone" if mini(window.x, window.y) < int(Phone.NARROW) else "desktop"
	Phone._on = 0 if _layout == "desktop" else 1
	Phone._wide = false
	Keymap.reset()
	Keymap.use("brickworks")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	_store = _main.get("_store")
	_store.keeps = false
	_camera = _main.get("_camera")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_steps = _main.get("_steps")
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_socket2 = CommandSocket.new()
	_socket2.assistant = _main.get("_assistant")
	_socket2.app = _main
	_main.add_child(_socket2)
	_gate = _builder.has_method("holds_lifted_figure")
	_code = "handkeep2" if _builder.has_method("holds_lifted_part") else "handkeep"
	print("handkeep2_probe: a %s window, case %s, code %s" % [_size, _case, _code])
	var wants: PackedStringArray = _case.split(",")
	var every: bool = wants.has("all")
	if every or wants.has("xturn"):
		await _case_xturn()
	if every or wants.has("xbin"):
		await _case_xbin()
	if every or wants.has("xundo"):
		await _case_xundo()
	if every or wants.has("cells"):
		await _case_cells()
	if every or wants.has("guard"):
		await _case_guard()
	print("\nhandkeep2_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## BrickWorld.round_the_hand, read by name so the probe also loads on code
## without it (handkeep), where it is -1.
func _round() -> int:
	return int((_world.get_script() as GDScript).get("round_the_hand")) if _code == "handkeep2" else -1


func _key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


## What X does over [param brick_id] (Main, KEY_X).
func _x(brick_id: int) -> bool:
	_builder.clear_selection()
	var lifted: bool = _builder.lift_brick(brick_id)
	_verbs.set_mode("place")
	await _frames(4)
	return lifted


func _lifted() -> bool:
	return _builder.has_method("holds_lifted_part") and bool(_builder.call("holds_lifted_part"))


func _lattice_matches(brick_id: int) -> bool:
	return _world.get_brick(brick_id) != null and _builder.lattice.boxes_of(brick_id) == _boxes_of(brick_id)


# -- xturn: a part lifted by X turned with the model ---------------------------------


func _case_xturn() -> void:
	print("\nXT. X over one plain part, the model turned (Shift+E), Escape")
	var path: String = _fixture2("hk2_xturn", REPLAN)
	if not await _to_step(path, "last"):
		_check("xturn: opens", false)
		return
	var name: String = "handkeep2 xturn"
	var depth: int = _builder.history_depth()
	var ref: int = _ref_brick()
	var wall: int = int(_walls()[0])
	var d0: float = _world.get_brick(ref).transform.origin.distance_to(_world.get_brick(wall).transform.origin)
	var full0: int = _full().size()
	var round0: int = _round()
	var lifted: bool = await _x(ref)
	_main.call("_turn_model", 1)
	await _frames(6)
	await _key(KEY_ESCAPE)
	var brick: BrickWorld.Brick = _world.get_brick(ref)
	var d1: float = brick.transform.origin.distance_to(_world.get_brick(wall).transform.origin) \
		if brick != null else -1.0
	var text: String = _text(name)
	_result("xturn", "lifted %s; turned, Escape: on the model %s, in hand %s, mode %s; to the wall %.1f (was %.1f); lattice where it stands %s; parts %d (were %d); red 3003s in the file %d; round the hand %d"
		% [lifted, brick != null, _held_count(), _verbs.mode, d1, d0, _lattice_matches(ref), _full().size(), full0,
			_count_in_colour(text, "3003", 2), _round() - round0])
	_check("xturn: lifted by X, the model turned, Escape: it stands where the turn took it against the rest (%.1f from a wall, was %.1f)"
		% [d1, d0], lifted and brick != null and absf(d1 - d0) < 0.5)
	_check("xturn: the lattice holds it where it stands, nothing in hand (%d)" % _held_count(),
		_lattice_matches(ref) and _held_count() == 0)
	_check("xturn: the file has it, every part kept (%d of %d)" % [_full().size(), full0],
		_full().size() == full0 and _count_in_colour(text, "3003", 2) == 1)
	_check("xturn: no write went round the hand (%d)" % (_round() - round0), _round() == round0)
	await _drop_all()
	_verbs.set_mode("select")
	await _back_to(depth)


# -- xbin: a part from the bin lets go of what is in hand -----------------------------


func _case_xbin() -> void:
	print("\nXB. X over one plain part, then a figure lifted, each let go of by a part from the bin")
	var path: String = _fixture2("hk2_xbin", REPLAN)
	for what: String in ["part", "figure"]:
		if not await _to_step(path, "last"):
			_check("xbin %s: opens" % what, false)
			continue
		var name: String = "handkeep2 xbin " + what
		var t0: String = _text(name)
		var full0: Array = _full()
		var depth: int = _builder.history_depth()
		var round0: int = _round()
		var mover: int = _ref_brick() if what == "part" else int(_torsos()[0])
		var lifted: bool = await _x(mover)
		var held: int = _held_count()
		_main.call("_on_part_chosen", "3001.dat")
		await _frames(6)
		var t1: String = _text(name)
		_result("xbin.%s" % what, "lifted %s (%d in hand); 3001 chosen: in hand %d, held part %s, mode %s, figure held %s; parts %d (were %d); lattice where it stood %s; file as opened %s; depth %d (was %d)"
			% [lifted, held, _held_count(), _builder.held_part, _verbs.mode, _builder.is_holding_figure(),
				_full().size(), full0.size(), _lattice_matches(mover), t1 == t0, _builder.history_depth(), depth])
		_check("xbin %s: a part chosen from the bin puts what was lifted back where it stood (in hand %d, %d parts, were %d)"
			% [what, _held_count(), _full().size(), full0.size()],
			lifted and held > 0 and _held_count() == 0 and _full() == full0 and _lattice_matches(mover))
		_check("xbin %s: the bin's part is the one in hand to put down (%s), the file as opened" % [what, _builder.held_part],
			_builder.held_part.begins_with("3001") and not _builder.is_holding_figure() and t1 == t0)
		_check("xbin %s: no write went round the hand (%d)" % [what, _round() - round0], _round() == round0)
		await _drop_all()
		_verbs.set_mode("select")
		await _back_to(depth)


# -- xundo: Undo per actor with a part lifted by X ------------------------------------


func _case_xundo() -> void:
	print("\nXU. X over one plain part: the person's Undo, then a session's")
	var path: String = _fixture2("hk2_xundo", REPLAN)
	if not await _to_step(path, "last"):
		_check("xundo: opens", false)
		return
	var name: String = "handkeep2 xundo"
	var t0: String = _text(name)
	var full0: Array = _full()
	var depth: int = _builder.history_depth()
	var round0: int = _round()
	var ref: int = _ref_brick()
	var lifted: bool = await _x(ref)
	await _verbs.press("undo")
	await _frames(6)
	var t1: String = _text(name)
	_result("xundo.person", "lifted %s; the person's Undo: in hand %d, depth %d (was %d), parts %d (were %d), lattice %s, file as opened %s"
		% [lifted, _held_count(), _builder.history_depth(), depth, _full().size(), full0.size(),
			_lattice_matches(ref), t1 == t0])
	_check("xundo person: Undo puts the lifted part back, undoing nothing else (depth %d, was %d; in hand %d)"
		% [_builder.history_depth(), depth, _held_count()],
		lifted and _held_count() == 0 and _builder.history_depth() == depth and _full() == full0 and t1 == t0)
	_verbs.set_mode("select")
	var wall: int = int(_walls()[0])
	var colour0: int = _world.get_brick(wall).color_code
	var said1: String = await _call("edit_model", {"recolor": [{"bricks": [wall], "color": 14}], "picture": false})
	var painted: bool = _world.get_brick(wall).color_code == 14
	lifted = await _x(ref)
	var said2: String = await _call("undo", {})
	await _frames(6)
	var colour: int = _world.get_brick(wall).color_code
	var still: bool = _lifted() and _held_count() == 1
	_result("xundo.session", "session painted %s (%s); X; session undo '%s': wall colour %d (was %d), part still in hand %s"
		% [painted, said1.left(50).replace("\n", " / "), said2.left(140).replace("\n", " / "), colour, colour0, still])
	_check("xundo session: the session's undo takes back its paint (colour %d, was %d) and names it, not the lift"
		% [colour, colour0], painted and colour == colour0 and not said2.contains("lifted"))
	_check("xundo session: and leaves the person's part in hand (%s)" % still, lifted and still)
	await _key(KEY_ESCAPE)
	_check("xundo: Escape then puts it back, nothing in hand, every part kept (%d)" % _held_count(),
		_held_count() == 0 and _full() == full0)
	_check("xundo: no write went round the hand (%d)" % (_round() - round0), _round() == round0)
	await _drop_all()
	_verbs.set_mode("select")
	await _back_to(depth)


# -- cells: where what is in hand stood stays in the way -----------------------------


func _case_cells() -> void:
	print("\nCE. a figure in hand: where it stood is in the way of a part, not of its own ghost")
	var path: String = _fixture2("hk2_cells", REPLAN)
	if not await _to_step(path, "last"):
		_check("cells: opens", false)
		return
	var depth: int = _builder.history_depth()
	var torso: int = int(_torsos()[0])
	var at: Transform3D = _world.get_brick(torso).transform
	var boxes: PackedInt32Array = _boxes_of(torso)
	_builder.clear_selection()
	var held: bool = _builder.lift_brick(torso) and _builder.is_holding_figure()
	await _frames(4)
	var blocks: bool = _builder.lattice.collides_boxes(boxes)
	var blockers: Array = Array(_builder.lattice.blockers_boxes(boxes))
	var ghost_at: Transform3D = await _aim(Vector3(at.origin.x, 0, at.origin.z))
	var fits: bool = bool(_builder.get("_ghost_valid"))
	var put: int = _builder.place()
	await _frames(6)
	_result("cells", "figure in hand %s; a part where the torso stood: collides %s, blockers %s; the figure's own ghost there %s at %s; put #%d; in hand %d"
		% [held, blocks, blockers.slice(0, 4), fits, ghost_at.origin.snapped(Vector3.ONE * 0.1), put, _held_count()])
	_check("cells: with the figure in hand, where its torso stood is in the way of anything else (%s)" % blocks,
		held and blocks and blockers.has(torso))
	_check("cells: and not of the figure's own ghost, put down where it stood (fits %s, put #%d)" % [fits, put],
		fits and put != 0 and _held_count() == 0)
	_check("cells: put down, the lattice holds the torso where it stands", _lattice_matches(torso))
	await _drop_all()
	_verbs.set_mode("select")
	await _back_to(depth)


# -- guard: the run-time count of writes made round the hand -------------------------


func _case_guard() -> void:
	print("\nGU. the run-time guard: nought after every case, one for a write made round the hand")
	if _code != "handkeep2":
		_check("guard: BrickWorld.round_the_hand exists", false)
		return
	var before: int = _round()
	_check("guard: no write went round the hand in any case run (%d)" % before, before == 0)
	var path: String = _fixture2("hk2_guard", REPLAN)
	if not await _to_step(path, "last"):
		_check("guard: opens", false)
		return
	var depth: int = _builder.history_depth()
	var ref: int = _ref_brick()
	await _x(ref)
	# What a new path round the hand would do: write a held part's place.
	var brick: BrickWorld.Brick = _world.get_brick(ref)
	brick.transform = brick.transform.translated(Vector3(0, -24, 0))
	var counted: int = _round() - before
	_check("guard: a held part's place written round the hand counts one (%d)" % counted, counted == 1)
	# Put back, it stands where it was lifted from, the stray write undone.
	_builder.put_hand_back()
	await _frames(4)
	_check("guard: put back where it stood (%s)" % _lattice_matches(ref), _lattice_matches(ref)
		and _held_count() == 0)
	await _drop_all()
	_verbs.set_mode("select")
	await _back_to(depth)
