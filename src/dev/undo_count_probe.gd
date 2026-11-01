## Undo and redo put back exactly what was taken, and nothing more.
##
##   godot --headless --path . --script src/dev/undo_count_probe.gd
##
## Models opened as a person opens them (Open, then its floor laid): the
## house on a scenery baseplate, a model on its own baseplate, and Orthanc
## on four. Parts are taken off one at a time and five at once, and a
## sub-assembly, and the floor is changed and made part of the model; each
## is undone, redone and undone again. After every undo the world holds
## what it held: as many bricks, the same scenery, the model's parts in the
## same order with the same everything, and a save writes the same bytes.
##
## It began as four bricks more on Orthanc after one undo (10,105 for
## 10,101, see_inside_probe). Those were the floor: see_inside opened
## Orthanc by Main._open alone, which lays no floor, and the first edit
## laid the four baseplates a person's Open lays at once. brick_count()
## counts scenery, which is never saved; here they are there from the
## start and never change. What was wrong was quieter: a part put back
## went last in the world's order, and the build steps worked out from
## that order were saved differently, the house's 18 steps as 20.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _floor: FloorLayer
var _verbs: EditVerbs
var _bar: ModelBar
var _saves: int = 0

## A model that carries its own baseplate, as a set does.
const ON_ITS_OWN_PLATE := """0 On its own plate
0 Name: own_plate.ldr
0 Author: Brickworks

1 2 0 0 0 1 0 0 0 1 0 0 0 1 3811.dat
1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 1 40 -24 80 1 0 0 0 1 0 0 0 1 3001.dat
1 14 -60 -24 -60 1 0 0 0 1 0 0 0 1 3003.dat
1 15 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat
"""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_floor = _main.get("_floor")
	_verbs = _main.get("_verbs")
	_bar = _main.get("_bar")
	_main.call("clear_model")
	await _frames(4)

	print("the house, on a baseplate of scenery")
	await _open("res://models/house.ldr")
	await _takings_off()
	await _floor_steps()

	print("\na model on its own baseplate")
	var result: Dictionary = await _bar.open_text_with_progress(ON_ITS_OWN_PLATE, "own plate")
	_bar.opened.emit(int(result.get("placed", 0)))
	await _frames(10)
	await _its_own_plate()

	print("\nOrthanc, on four")
	await _open("res://models/orthanc.ldr")
	await _takings_off()

	print("")
	if _failures == 0:
		print("undo count: every undo puts back what was taken and nothing more, "
			+ "and a save after it is the file before")
	else:
		print("undo count: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Open as the model bar's Open does: the file, then the floor laid under
## it (Main's opened). Main._open alone lays none.
func _open(path: String) -> void:
	var placed: int = await _bar.open_with_progress(path)
	_bar.opened.emit(placed)
	await _frames(10)


func _takings_off() -> void:
	var began: Dictionary = _now(true)
	var ids: Array = _model_ids()
	print("    %d bricks: %d of the model, %d of scenery" % [began["count"], began["parts"],
		(began["scenery"] as PackedStringArray).size()])
	_check("it stands on its floor from the start (%d plates of scenery)"
		% (began["scenery"] as PackedStringArray).size(),
		not (began["scenery"] as PackedStringArray).is_empty())
	# Off and back, five times, a part each.
	for n: int in 5:
		await _take_off([ids[n * 7 + 1]])
		await _press("undo")
	_same("five parts each taken off and put back", began, _now(true))
	# Five off, five undone, five redone, five undone.
	for n: int in 5:
		await _take_off([ids[n * 11 + 3]])
	var off: Dictionary = _now(true)
	for n: int in 5:
		await _press("undo")
	_same("five taken off, then five undone", began, _now(true))
	for n: int in 5:
		await _press("redo")
	_same("...five redone, the five off again", off, _now(true))
	for n: int in 5:
		await _press("undo")
	_same("...and undone again", began, _now(true))
	# A sub-assembly, as a click takes one.
	_builder.select_brick(ids[0], false)
	var taken: int = _builder.selection.size()
	await _press("delete")
	await _press("undo")
	_same("a sub-assembly of %d taken off and put back" % taken, began, _now(true))


## A change of floor, and the baseplate made part of the model, undone.
func _floor_steps() -> void:
	var began: Dictionary = _now(true)
	var grid: ModelFloor = _store.model_floor.copy()
	grid.kind = ModelFloor.GRID
	_main.call("choose_floor", grid)
	await _frames(4)
	var on_grid: Dictionary = _now(false)
	_check("on the grid no plate is laid (%d bricks)" % on_grid["count"],
		(on_grid["scenery"] as PackedStringArray).is_empty())
	await _press("undo")
	_same("the grid undone, the baseplate back", began, _now(true))
	await _press("redo")
	_same("...redone, the grid again", on_grid, _now(false))
	await _press("undo")
	_same("...and undone again", began, _now(true))
	_main.call("floor_part_of_model", true)
	await _frames(4)
	var adopted: Dictionary = _now(true)
	_check("the baseplate made part of the model is a part of it (%d, was %d)"
		% [adopted["parts"], began["parts"]], adopted["parts"] == began["parts"] + 1
		and adopted["count"] == began["count"])
	await _press("undo")
	_same("that undone, the baseplate scenery again", began, _now(true))
	await _press("redo")
	_same("...redone", adopted, _now(true))
	await _press("undo")
	_same("...and undone again", began, _now(true))


## The model's own baseplate taken off: the floor's goes under it, and
## comes away when the undo brings the model's back.
func _its_own_plate() -> void:
	var began: Dictionary = _now(true)
	var own: Array[int] = _floor.own_plates()
	_check("the model's own plate is its floor (%d own, %d of scenery)"
		% [own.size(), (began["scenery"] as PackedStringArray).size()],
		own.size() == 1 and (began["scenery"] as PackedStringArray).is_empty())
	if own.is_empty():
		return
	await _take_off([own[0]])
	var off: Dictionary = _now(true)
	_check("taken off, the floor's plate is laid in its place (%d of scenery)"
		% (off["scenery"] as PackedStringArray).size(),
		(off["scenery"] as PackedStringArray).size() == 1 and off["parts"] == began["parts"] - 1)
	await _press("undo")
	_same("put back, the floor's plate comes away", began, _now(true))
	await _press("redo")
	_same("...redone, laid again", off, _now(true))
	await _press("undo")
	_same("...and undone again", began, _now(true))
	await _takings_off_here()


## A part of the model on its own plate, off and back.
func _takings_off_here() -> void:
	var began: Dictionary = _now(true)
	var ids: Array = _model_ids()
	for n: int in 3:
		await _take_off([ids[ids.size() - 1 - n]])
		await _press("undo")
	_same("three of its parts each taken off and put back", began, _now(true))


func _model_ids() -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	return ids


func _take_off(ids: Array) -> void:
	_verbs.select_found(ids)
	await _press("delete")


func _press(name: String) -> void:
	await _verbs.press(name)
	await _frames(4)


## The world as a person's work is made of it: how many bricks it holds,
## the model's parts in the world's order with everything each carries,
## the scenery by what and where (a plate laid again is a new number), and
## with [param saved], the bytes a save writes.
func _now(saved: bool) -> Dictionary:
	var parts := PackedStringArray()
	var scenery := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		var line: String = "%d %s %d %s %s %s %d %s" % [brick.id, brick.part_id,
			brick.color_code, str(brick.transform), brick.group, brick.unit, brick.step,
			brick.hidden]
		if _store.scenery.has(brick.id):
			scenery.append(line.substr(line.find(" ") + 1))
		else:
			parts.append(line)
	scenery.sort()
	var now: Dictionary = {"count": _world.brick_count(), "parts": parts.size(),
		"order": parts, "scenery": scenery, "floor": _store.model_floor.whole_words()}
	if saved:
		_saves += 1
		var path: String = "user://undo_count_%d.ldr" % _saves
		_store.save_file(path, "undo count")
		now["saved"] = FileAccess.get_file_as_bytes(path)
	return now


func _same(what: String, was: Dictionary, now: Dictionary) -> void:
	var differ := PackedStringArray()
	for key: String in was:
		if now.get(key) != was[key]:
			differ.append(key)
	var said: String = "%d bricks, %d parts, %d of scenery" % [now["count"], now["parts"],
		(now["scenery"] as PackedStringArray).size()]
	if was.has("saved") and now.has("saved"):
		said += ", saved %d bytes" % (now["saved"] as PackedByteArray).size()
	if not differ.is_empty():
		said += "; NOT the same %s (was %d bricks, %d parts%s)" % [", ".join(differ),
			was["count"], was["parts"], (", saved %d bytes" % (was["saved"] as PackedByteArray)
			.size()) if was.has("saved") else ""]
		if differ.has("order"):
			said += ", " + _first_moved(was["order"], now["order"])
	_check("%s: %s" % [what, said], differ.is_empty())


func _first_moved(was: PackedStringArray, now: PackedStringArray) -> String:
	for at: int in mini(was.size(), now.size()):
		if was[at] != now[at]:
			return "at %d of the order %s where %s stood" % [at, now[at].get_slice(" ", 0),
				was[at].get_slice(" ", 0)]
	return "of %d parts, %d" % [was.size(), now.size()]


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame
