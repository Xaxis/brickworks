## The lock's work a frame on the largest model (APP_UX10 jointlock): on
## Orthanc (models/orthanc.ldr, 10,119 parts) with a joint locked, the whole
## model dragged (Builder.drag_room's lock check each frame), a part pressed
## on (Grab's check at the press), Motions' rows asked whether each joint is
## locked, and the file's lock lines written: each timed, none over 16 ms.
##
##   godot --headless --path . --script src/dev/jointlock_time_probe.gd
extends SceneTree

const BIG := "res://models/orthanc.ldr"
const FRAME_MS := 16.0

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 600:
		await process_frame
		if main.get("_shell") != null and main.get("_world") != null:
			break
	for _n: int in 60:
		await process_frame
	var playback: Variant = main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	var store: ModelStore = main.get("_store")
	store.keeps = false
	main.call("_open", BIG)
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty() and not Working.is_busy():
			break
	print("  Orthanc open: %d parts" % world.brick_count())
	# A joint locked: two parts that touch, the first pair found.
	var ids: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		ids.append(brick.id)
	var lock: Motions.Lock = Motions.lock_of(int(ids[ids.size() / 2]), int(ids[ids.size() / 2 + 1]), world,
		store.lift())
	world.motions.locks.append(lock)
	# The whole model dragged: each frame's lock check (drag_room's first piece).
	# Everything selected at once, as Select all does (one by one is a
	# selection change a part: minutes on Orthanc, and no person's act).
	builder.clear_selection()
	for id: int in ids:
		builder.selection[id] = true
	builder.selection_changed.emit(builder.selection.size())
	await process_frame
	var began_hold: int = Time.get_ticks_usec()
	builder.drag_begin()
	print("  drag_begin of all of it: %.0f ms (the drag's own, before the lock's)" % (
		(Time.get_ticks_usec() - began_hold) / 1000.0))
	var worst: float = 0.0
	for n: int in 20:
		var by := Transform3D(Basis.IDENTITY, Vector3(20.0 * (n + 1), 0, 0))
		var began: int = Time.get_ticks_usec()
		builder.drag_room(by, 0, Time.get_ticks_usec() + 1)
		worst = maxf(worst, (Time.get_ticks_usec() - began) / 1000.0)
	builder.drag_end(Transform3D.IDENTITY)
	_check(("the whole model dragged (%d parts), a frame's room test with the lock's check first (its "
		+ "first piece only): worst %.2f ms") % [ids.size(), worst], worst < FRAME_MS)
	# One part dragged by itself: the check that refuses it.
	# That part alone (a click would take its whole sub-assembly, both sides).
	builder.clear_selection()
	builder.selection[int(ids[ids.size() / 2])] = true
	builder.selection_changed.emit(1)
	builder.drag_begin()
	var began_one: int = Time.get_ticks_usec()
	var fits: bool = builder.drag_fits(Transform3D(Basis.IDENTITY, Vector3(20, 0, 0)))
	var one_ms: float = (Time.get_ticks_usec() - began_one) / 1000.0
	builder.drag_end(Transform3D.IDENTITY)
	_check("a locked part dragged alone is refused (%s) in %.2f ms" % [builder.refused_lock.left(60), one_ms],
		not fits and not builder.refused_lock.is_empty() and one_ms < FRAME_MS)
	builder.clear_selection()
	# Grab's check at a press: the lock's split asked of what would move.
	var moving: Dictionary = {}
	for id: int in ids:
		moving[id] = true
	var began_split: int = Time.get_ticks_usec()
	for _n: int in 10:
		world.motions.lock_split(moving, world, builder)
	var split_ms: float = (Time.get_ticks_usec() - began_split) / 10000.0
	_check("Grab's lock check at a press, all %d parts moving: %.3f ms" % [ids.size(), split_ms], split_ms < FRAME_MS)
	# Motions' rows: whether each joint is locked (its sides picked, the split).
	var pose: PosePanel = main.get("_pose")
	var player: MotionPlayer = main.get("_motions")
	var joints: Array = player.movable()
	var row_worst: float = 0.0
	var began_rows: int = Time.get_ticks_usec()
	for joint: Motions.Joint in joints:
		var began_row: int = Time.get_ticks_usec()
		pose.lock_said(joint)
		row_worst = maxf(row_worst, (Time.get_ticks_usec() - began_row) / 1000.0)
	var rows_ms: float = (Time.get_ticks_usec() - began_rows) / 1000.0
	_check(("Motions' rows asked whether each of %d joints is locked, as one fill of the editor: %.2f ms "
		+ "(worst row %.2f ms)") % [joints.size(), rows_ms, row_worst], rows_ms < FRAME_MS)
	# The file's lock lines, as a save writes them.
	var began_lines: int = Time.get_ticks_usec()
	var lines: PackedStringArray = store._lock_lines()
	var lines_ms: float = (Time.get_ticks_usec() - began_lines) / 1000.0
	_check("the lock line written (%s) in %.2f ms" % [lines[0].left(70) if not lines.is_empty() else "none",
		lines_ms], lines.size() == 1 and lines_ms < FRAME_MS)
	print("")
	if _failures == 0:
		print("jointlock_time: on Orthanc no frame does more than 16 ms of the lock's work")
	else:
		print("jointlock_time: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
