## A model opened again saves what it saved (wirekeep, 2026-11-22).
##
##   godot --headless --path . --script src/dev/wirekeep_probe.gd
##   godot --headless --path . --script src/dev/wirekeep_probe.gd -- --files=DIR
##     (each file it writes copied into DIR too, for a review)
##
## A model whose lowest part is below the ground opens stood on it
## (ModelStore.lift_for), every part that much higher in the window, and a
## save takes it off again. Each sub-model's first copy was written at the
## window's origin, so the save after a reopen wrote every sub-model anew:
## its reference that much lower, its parts that much higher in it. wires
## found it as a laid cable's (wires_probe 2.); it is any sub-model's.
##   1. A sub-model made here, in a model with a battery box set 70 LDU into
##      the ground: saved, opened and saved, opened and saved again, the
##      three files byte for byte, its reference where the first had it, and
##      every part where it stood before the first save.
##   2. Made into another sub-model while it stands lifted: saved, opened and
##      saved, byte for byte.
##   3. 42042's L motor cable as LDCad laid it (its path, its pieces), in a
##      model of this app's own that it hangs below the ground: opened and
##      saved, the cable's reference as the file had it, every part where the
##      file had it; opened and saved again, byte for byte.
extends SceneTree

const MODELS := "user://wirekeep_probe/"
const SET_42042 := "/mnt/Projects/brickworks/bench/data/kinebrick/omr/42042-1 Crawler Crane.mpd"
const CABLE_FILE := "42042 - powerFuncMotorL-1.ldr"
const WATCHDOG := 1800.0

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _assemblies: Assemblies
var _files: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--files="):
			_files = arg.trim_prefix("--files=")
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("wirekeep_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await _start()
	print("\n1. a sub-model made here, a battery box set into the ground")
	await _made_here()
	print("\n2. another sub-model made while the model stands lifted")
	await _made_lifted()
	print("\n3. 42042's LDCad cable in a model of this app's own, below the ground")
	await _ldcad_cable()
	print("\nwirekeep_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _start() -> void:
	Account.where = "user://wirekeep_probe_session.json"
	Account._clear()
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
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_assemblies = (_main.get("_shell") as Object).get("assemblies")
	DirAccess.make_dir_recursive_absolute(MODELS)
	if not _files.is_empty():
		DirAccess.make_dir_recursive_absolute(_files)


# -- 1. and 2. --------------------------------------------------------------------------


func _made_here() -> void:
	_main.call("clear_model")
	await _frames(5)
	_place("58119", Vector3(0, 0, 0), 0)
	var left: int = _place("3001", Vector3(200, 0, 0), 4)
	var right: int = _place("3001", Vector3(200, 24, 0), 1)
	_place("3001", Vector3(-200, 0, 0), 14)
	_builder.clear_selection()
	_builder.select_brick(left, false)
	_builder.select_brick(right, true)
	var wing: String = _assemblies.make("Wing")
	_builder.clear_selection()
	await _frames(5)
	_check("two bricks made the sub-model Wing (%s), the model not lifted as it was made (%s)" % [
		wing, _store.lift()], not wing.is_empty() and _store.lift() == Vector3.ZERO)
	var made: Array = _parts_in_file()
	var first: String = await _save("made.ldr")
	await _open(MODELS + "made.ldr")
	_check("opened again: stood %s up on the ground, the box 70 LDU into it" % _store.lift(),
		_store.lift().y > 0.0)
	var opened: Array = _parts_in_file()
	var second: String = await _save("made_2.ldr")
	await _open(MODELS + "made_2.ldr")
	var third: String = await _save("made_3.ldr")
	print("    Wing's reference: %s, then %s, then %s" % [_ref_to(first, "wing.ldr"),
		_ref_to(second, "wing.ldr"), _ref_to(third, "wing.ldr")])
	_check("every part where it stood before the first save (%d parts)" % made.size(),
		_same_parts(made, opened))
	if not _check("saved, opened and saved: byte for byte (%d bytes)" % first.length(),
			not first.is_empty() and first == second):
		print(_difference(first, second))
	if not _check("opened and saved again: byte for byte", not second.is_empty() and second == third):
		print(_difference(second, third))


func _made_lifted() -> void:
	await _open(MODELS + "made.ldr")
	var loose: int = -1
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001" and Assemblies.path_of(brick).is_empty():
			loose = brick.id
	_builder.clear_selection()
	_builder.select_brick(loose, false)
	var tail: String = _assemblies.make("Tail")
	_builder.clear_selection()
	await _frames(5)
	_check("made the sub-model Tail with the model stood %s up (%s)" % [_store.lift(), tail],
		not tail.is_empty() and _store.lift().y > 0.0)
	var made: Array = _parts_in_file()
	var first: String = await _save("lifted.ldr")
	await _open(MODELS + "lifted.ldr")
	var second: String = await _save("lifted_2.ldr")
	print("    Tail's reference: %s, then %s" % [_ref_to(first, "tail.ldr"), _ref_to(second, "tail.ldr")])
	_check("every part where it stood (%d parts)" % made.size(), _same_parts(made, _parts_in_file()))
	if not _check("saved, opened and saved: byte for byte (%d bytes)" % first.length(),
			not first.is_empty() and first == second):
		print(_difference(first, second))


# -- 3. ------------------------------------------------------------------------------------


func _ldcad_cable() -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(SET_42042).replace("\r\n", "\n").split("\n")
	var from: int = lines.find("0 FILE " + CABLE_FILE)
	var to: int = from + 1
	while to < lines.size() and not (lines[to].begins_with("0 FILE ")
			and not lines[to].contains("powerFuncMotorL-1")):
		to += 1
	if not _check("42042's L motor cable read from the set's file (%d lines)" % (to - from), from >= 0 and to - from > 40):
		return
	var text: String = "\n".join(PackedStringArray([
		"0 FILE cable_box.ldr", "0 Cable on a box", "0 Name: cable_box.ldr", "0 Author: Brickworks", "",
		"1 0 0 0 0 1 0 0 0 1 0 0 0 1 58119.dat",
		"1 16 0 0 0 1 0 0 0 1 0 0 0 1 " + CABLE_FILE, ""])) + "\n" \
		+ "\n".join(lines.slice(from, to)) + "\n"
	var file: FileAccess = FileAccess.open(MODELS + "cable_box.ldr", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_keep("cable_box.ldr", text)
	await _open(MODELS + "cable_box.ldr")
	var lift: Vector3 = _store.lift()
	var cable: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not Assemblies.path_of(brick).is_empty():
			cable += 1
	_check("opened: %d parts of the cable in its sub-model, the model stood %s up on the ground" % [
		cable, lift], cable > 2 and lift.y > 0.0)
	var opened: Array = _parts_in_file()
	var first: String = await _save("cable_box_2.ldr")
	var ref: String = _ref_to(first, "powerfuncmotorl-1.ldr")
	print("    the cable's reference: %s, then %s" % [_ref_to(text, "powerfuncmotorl-1.ldr"), ref])
	_check("saved: the cable's reference as the file had it (%s)" % ref,
		ref.begins_with("1 16 0 0 0 1 0 0 0 1 0 0 0 1 "))
	await _open(MODELS + "cable_box_2.ldr")
	_check("opened again: every part where the file had it (%d parts)" % opened.size(),
		_same_parts(opened, _parts_in_file()))
	var second: String = await _save("cable_box_3.ldr")
	if not _check("saved again: byte for byte (%d bytes)" % first.length(),
			not first.is_empty() and first == second):
		print(_difference(first, second))


# -- what is where --------------------------------------------------------------------------


## Each part of the model where its file has it (the model's lift taken off),
## part, colour, place and turn to the hundredth, sorted.
func _parts_in_file() -> Array:
	var back := Transform3D(Basis.IDENTITY, -_store.lift())
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: Transform3D = back * brick.transform
		var numbers := PackedStringArray()
		for value: float in [at.origin.x, at.origin.y, at.origin.z, at.basis.x.x, at.basis.x.y, at.basis.x.z,
				at.basis.y.x, at.basis.y.y, at.basis.y.z, at.basis.z.x, at.basis.z.y, at.basis.z.z]:
			numbers.append("%.2f" % (0.0 if absf(value) < 0.005 else value))
		out.append("%s %d %s" % [brick.part_id, brick.color_code, " ".join(numbers)])
	out.sort()
	return out


func _same_parts(a: Array, b: Array) -> bool:
	if a == b:
		return true
	var shown: int = 0
	for n: int in mini(a.size(), b.size()):
		if a[n] != b[n] and shown < 4:
			print("      was %s\n      now %s" % [a[n], b[n]])
			shown += 1
	if a.size() != b.size():
		print("      %d parts, then %d" % [a.size(), b.size()])
	return false


## The line of [param text] placing the sub-model whose file name ends in
## [param named] (any case), or "(none)".
static func _ref_to(text: String, named: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("1 ") and line.strip_edges().to_lower().ends_with(named):
			return line.strip_edges()
	return "(none)"


static func _difference(a: String, b: String) -> String:
	var one: PackedStringArray = a.split("\n")
	var two: PackedStringArray = b.split("\n")
	var out := PackedStringArray(["    %d bytes, %d lines; then %d bytes, %d lines" % [
		a.length(), one.size(), b.length(), two.size()]])
	var shown: int = 0
	for n: int in maxi(one.size(), two.size()):
		var x: String = one[n] if n < one.size() else "(none)"
		var y: String = two[n] if n < two.size() else "(none)"
		if x != y and shown < 8:
			out.append("    - %d: %s\n    + %d: %s" % [n + 1, x.left(140), n + 1, y.left(140)])
			shown += 1
	return "\n".join(out)


# -- the app ----------------------------------------------------------------------------------


func _place(part_id: String, at: Vector3, colour: int) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var id: int = _world.add_brick(part_id, colour, where)
	_builder.register(id, part_id, where)
	return id


func _save(file: String) -> String:
	if not bool(_main.call("save_model", MODELS + file)):
		print("    could not write %s" % file)
		return ""
	await _frames(5)
	var text: String = FileAccess.get_file_as_string(MODELS + file)
	_keep(file, text)
	return text


func _keep(file: String, text: String) -> void:
	if _files.is_empty():
		return
	var out: FileAccess = FileAccess.open(_files.path_join(file), FileAccess.WRITE)
	if out != null:
		out.store_string(text)
		out.close()


func _open(path: String) -> void:
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", path)
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 300000:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0 and not Working.is_busy():
			break
	await _frames(10)
	var playback: Variant = _main.get("_playback")
	if playback != null and (playback as BuildPlayback).is_playing():
		(playback as BuildPlayback).stop()
		await _frames(3)
	_builder.forget_history()


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
