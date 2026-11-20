## kbkfix: the kept text stands for one moment of the history, and a save
## writes it only at that moment (kbkreview2's kbx_probe, judged). Each base
## written as a saved model, opened by the bar, an act done, saved by the
## bar's Save; the file compared with the base and opened again.
## - none: byte for byte.
## - adopt_save_undo (H1): the baseplate made part of the model, saved, taken
##   back by Undo and saved: the file has no baseplate, and the Undo left work
##   unsaved. 11edff5b2 kept the 3811 plate (62 parts back of 61).
## - adopt_undo, colour_save_undo, name_save_undo, undo_redo: what the history
##   leaves is what is written.
## - renamed (M2): Save as another name unedited is the file but for its name
##   lines, its parts in its order. 11edff5b2 planned the kart again.
## - restore, restore_later, undo_open (M3): the working model restored, and
##   an open undone, save byte for byte; restore_edited: one restored with a
##   part recoloured saves the new colour.
## - clear_undo, simulate: a Clear undone, and Simulate run and stopped, save
##   byte for byte; peer_step: a part's step set past the history is written.
## KBX_ONLY=a,b runs those acts; KBX_OUT=DIR keeps each file.
##
##   godot --headless --path . --script src/dev/kbx_probe.gd
extends SceneTree

const T := "Kbx Probe"
const OTHER := "Kbx Other"
const ELSE := "Kbx Else"
var _main: Node
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _bar: ModelBar
var _verbs: EditVerbs
var _tools: AppTools
var _out: String = OS.get_environment("KBX_OUT")
var _only: String = OS.get_environment("KBX_ONLY")
var _failures: int = 0
var _passes: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_bar = _main.get("_bar")
	_verbs = _main.get("_verbs")
	# As the app runs: an open sets the model before it aside, for its Undo.
	_store.keeps = true
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	var bases: Array = [
		["car", FileAccess.get_file_as_bytes("res://src/dev/fixtures/swapfind_car.mpd")],
		["gears", FileAccess.get_file_as_bytes("res://src/dev/fixtures/gears_locked.ldr")],
		["m267w", FileAccess.get_file_as_bytes("res://src/dev/fixtures/mlattack/m267_own_worked.mpd")],
		# The app's own model the planner plans, which Save as reordered.
		["kart", FileAccess.get_file_as_bytes("res://models/kart.ldr")]]
	var acts: Array = [
		["none", _none],
		["adopt_save_undo", _adopt_save_undo],
		["adopt_undo", _adopt_undo],
		["colour_save_undo", _colour_save_undo],
		["name_save_undo", _name_save_undo],
		["undo_redo", _undo_redo],
		["renamed", _renamed],
		["restore", _restore],
		["restore_later", _restore_later],
		["restore_edited", _restore_edited],
		["undo_open", _undo_open],
		["clear_undo", _clear_undo],
		["simulate", _simulate],
		["peer_step", _peer_step]]
	for base: Array in bases:
		for act: Array in acts:
			if not _only.is_empty() and not (_only.split(",") as Array).has(act[0]):
				continue
			await _case(base[0], base[1], act[0], act[1])
	print("\nKBX DONE %d passed, %d failed" % [_passes, _failures])
	print("kbx probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures else 0)


var _base: PackedByteArray
var _tag: String = ""
var _saves: int = 0
var _parts_open: int = 0


func _case(base: String, bytes: PackedByteArray, act: String, run: Callable) -> void:
	_main.call("clear_model")
	await _frames(4)
	for name: String in [T, OTHER, ELSE]:
		if FileAccess.file_exists(ModelStore.saved_path(name)):
			DirAccess.remove_absolute(ModelStore.saved_path(name))
	var file := FileAccess.open(ModelStore.saved_path(T), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var placed: int = await _bar.open_with_progress(ModelStore.saved_path(T))
	_bar.opened.emit(placed)
	await _settle()
	_base = bytes
	_parts_open = _parts()
	_saves = 0
	_tag = "%s__%s" % [base, act]
	# [passed, what it says]
	var said: Array = await run.call()
	var ok: bool = bool(said[0])
	if ok:
		_passes += 1
	else:
		_failures += 1
	print("KBX %s %s %s" % ["PASS" if ok else "FAIL", _tag, said[1]])


## The bar's Save, and the file it wrote.
func _save() -> PackedByteArray:
	var ok: bool = await _bar._on_save()
	await _frames(4)
	_saves += 1
	var got: PackedByteArray = FileAccess.get_file_as_bytes(_file())
	if not ok:
		print("  not saved: %s" % _store.refused)
	if not _out.is_empty():
		var out := FileAccess.open(_out.path_join("%s.save%d" % [_tag, _saves]), FileAccess.WRITE)
		out.store_buffer(got)
		out.close()
	return got


func _file() -> String:
	return ModelStore.saved_path(_bar.model_name())


## How many parts the file has when opened again, what a person gets back.
func _reopened(path: String = "") -> int:
	var placed: int = await _bar.open_with_progress(path if not path.is_empty() else _file())
	_bar.opened.emit(placed)
	await _settle()
	return _parts()


func _none() -> Array:
	var got: PackedByteArray = await _save()
	return [got == _base, "same_as_base=%s" % (got == _base)]


## H1: the baseplate made part of the model, saved (it is written), taken back
## by Undo and saved again: the file must not have it.
func _adopt_save_undo() -> Array:
	_main.call("floor_part_of_model", true)
	await _frames(4)
	var mid: int = _parts()
	var first: PackedByteArray = await _save()
	await _verbs.press("undo")
	await _settle()
	var after: int = _parts()
	var unsaved: bool = _store.has_unsaved_work()
	var second: PackedByteArray = await _save()
	var back: int = await _reopened()
	var ok: bool = mid == _parts_open + 1 and _part_lines(first) == _part_lines(_base) + 1 \
		and after == _parts_open and unsaved and back == _parts_open \
		and _part_lines(second) == _part_lines(_base)
	return [ok, "adopted=%d first_lines=%d after_undo=%d unsaved_after_undo=%s second_lines=%d base_lines=%d reopened=%d of %d" % [
		mid, _part_lines(first), after, unsaved, _part_lines(second), _part_lines(_base), back, _parts_open]]


## The baseplate made part of the model and taken back, no save between:
## nothing of it written. Byte for byte said, not asked.
func _adopt_undo() -> Array:
	_main.call("floor_part_of_model", true)
	await _frames(4)
	await _verbs.press("undo")
	await _settle()
	var got: PackedByteArray = await _save()
	var back: int = await _reopened()
	return [back == _parts_open and _part_lines(got) == _part_lines(_base),
		"reopened=%d of %d same_as_base=%s said=“%s”" % [back, _parts_open, got == _base, _store.order_words]]


func _colour_save_undo() -> Array:
	var part: BrickWorld.Brick = _first_part()
	var was: int = part.color_code
	var to: int = 4 if was != 4 else 1
	var at: Transform3D = part.transform
	_builder.paint_brick(part.id, to)
	await _frames(4)
	var first: PackedByteArray = await _save()
	await _verbs.press("undo")
	await _settle()
	var second: PackedByteArray = await _save()
	await _reopened()
	var colour: int = _colour_at(at, part.part_id)
	return [first != _base and colour == was, "first_changed=%s colour_back=%s (%d, was %d) same_as_base=%s" % [
		first != _base, colour == was, colour, was, second == _base]]


func _name_save_undo() -> Array:
	var said: String = str(await _tools.run("edit_steps", {"op": "name", "step": 1, "name": "Kbx Named"})).left(60)
	await _settle()
	var first: PackedByteArray = await _save()
	await _verbs.press("undo")
	await _settle()
	var second: PackedByteArray = await _save()
	var had: bool = first.get_string_from_utf8().contains("Kbx Named")
	var has: bool = second.get_string_from_utf8().contains("Kbx Named")
	return [had and not has, "said(%s) name_in_first=%s name_in_second=%s" % [said.replace("\n", " "), had, has]]


## Saved with the baseplate adopted, undone, redone and saved: the redo's
## model, the plate in it, is written.
func _undo_redo() -> Array:
	_main.call("floor_part_of_model", true)
	await _frames(4)
	await _save()
	await _verbs.press("undo")
	await _settle()
	await _save()
	await _verbs.press("redo")
	await _settle()
	var now: int = _parts()
	var third: PackedByteArray = await _save()
	var back: int = await _reopened()
	return [now == _parts_open + 1 and back == now and _part_lines(third) == _part_lines(_base) + 1,
		"after_redo=%d reopened=%d third_lines=%d" % [now, back, _part_lines(third)]]


## M2: Save as another name with no edit: the file but for its name lines.
func _renamed() -> Array:
	var ok: bool = _store.save_as(OTHER)
	await _frames(4)
	var got: PackedByteArray = FileAccess.get_file_as_bytes(ModelStore.saved_path(OTHER))
	var a: PackedStringArray = _base.get_string_from_utf8().split("\n")
	var b: PackedStringArray = got.get_string_from_utf8().split("\n")
	var other := PackedStringArray()
	for n: int in mini(a.size(), b.size()):
		if a[n] != b[n]:
			other.append(b[n].strip_edges())
	var named: bool = true
	for line: String in other:
		named = named and line.begins_with("0 ") and not LdrModel.is_placing(line) \
			and (line.contains(OTHER) or line.contains(LdrModel.new_file_name(OTHER)))
	var moved: bool = ModelStore.order_moved(_base.get_string_from_utf8(), got.get_string_from_utf8())
	var back: int = await _reopened(ModelStore.saved_path(OTHER))
	var pass_: bool = ok and a.size() == b.size() and other.size() <= 2 and named and not moved \
		and back == _parts_open
	return [pass_, "saved=%s lines %d/%d other_lines=%s moved=%s reopened=%d of %d" % [ok, b.size(), a.size(),
		JSON.stringify(other).left(160), moved, back, _parts_open]]


## M3: saved, the autosave written at once, the working model restored as
## at start-up, saved: byte for byte.
func _restore() -> Array:
	var first: PackedByteArray = await _save()
	_store.call("_write", ModelStore.autosave(), _store.title)
	var back: int = _store.restore()
	_bar.opened.emit(back)
	await _settle()
	var got: PackedByteArray = await _save()
	return [first == _base and got == _base, "first_same=%s restored=%d same_as_base=%s said=“%s”" % [
		first == _base, back, got == _base, _store.order_words]]


## M3: opened and left a while, the autosave written then, restored, saved.
func _restore_later() -> Array:
	await _frames(20)
	_store.call("_write", ModelStore.autosave(), _store.title)
	var back: int = _store.restore()
	_bar.opened.emit(back)
	await _settle()
	var got: PackedByteArray = await _save()
	return [got == _base, "restored=%d same_as_base=%s said=“%s”" % [back, got == _base, _store.order_words]]


## A part recoloured, the autosave written then, restored, saved: the new
## colour is written, never the file it was opened from.
func _restore_edited() -> Array:
	var part: BrickWorld.Brick = _first_part()
	var was: int = part.color_code
	var to: int = 4 if was != 4 else 1
	var at: Transform3D = part.transform
	var id: String = part.part_id
	_builder.paint_brick(part.id, to)
	await _frames(4)
	_store.call("_write", ModelStore.autosave(), _store.title)
	var back: int = _store.restore()
	_bar.opened.emit(back)
	await _settle()
	var got: PackedByteArray = await _save()
	await _reopened()
	var colour: int = _colour_at(at, id)
	return [got != _base and colour == to, "restored=%d changed_written=%s colour=%d (to %d, was %d)" % [
		back, got != _base, colour, to, was]]


## M3: another model opened over it, the open undone, saved: byte for byte.
func _undo_open() -> Array:
	var text: String = FileAccess.get_file_as_string("res://src/dev/fixtures/house/robot.ldr")
	var file := FileAccess.open(ModelStore.saved_path(ELSE), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var placed: int = await _bar.open_with_progress(ModelStore.saved_path(ELSE))
	_bar.opened.emit(placed)
	await _settle()
	await _verbs.press("undo")
	await _settle()
	var got: PackedByteArray = await _save()
	return [got == _base, "title=%s same_as_base=%s said=“%s”" % [_store.title, got == _base, _store.order_words]]


## The baseplate cleared, the Clear undone: the model as it was, byte for byte.
func _clear_undo() -> Array:
	_main.call("clear_model", true, "cleared")
	await _settle()
	await _verbs.press("undo")
	await _settle()
	var got: PackedByteArray = await _save()
	return [got == _base and _parts() == _parts_open, "parts=%d of %d same_as_base=%s" % [
		_parts(), _parts_open, got == _base]]


## Simulate run a moment and stopped: nothing changed, byte for byte.
func _simulate() -> Array:
	await _main.call("open_simulate")
	await _frames(30)
	var sim: Node = _main.get("_simulate")
	if sim != null and sim.has_method("close"):
		sim.call("close")
	await _frames(6)
	var got: PackedByteArray = await _save()
	return [got == _base, "same_as_base=%s" % (got == _base)]


## A Build together room's edit that sets only a part's step, past the history
## (Together._put): written, not the file as it was.
func _peer_step() -> Array:
	var part: BrickWorld.Brick = _first_part()
	part.step += 1
	_store.touch()
	await _frames(4)
	var got: PackedByteArray = await _save()
	return [got != _base, "changed_written=%s" % (got != _base)]


static func _part_lines(bytes: PackedByteArray) -> int:
	var n: int = 0
	for line: String in bytes.get_string_from_utf8().split("\n"):
		if LdrModel.is_placing(line.strip_edges()):
			n += 1
	return n


func _colour_at(at: Transform3D, part_id: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part_id and brick.transform.origin.distance_to(at.origin) < 0.01:
			return brick.color_code
	return -1


func _first_part() -> BrickWorld.Brick:
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			return brick
	return null


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	for _n: int in 4000:
		if not _store.laying and _store.awaited.is_empty():
			break
		await process_frame
	for _n: int in 6:
		await process_frame
