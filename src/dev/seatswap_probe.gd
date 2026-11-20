## A part seated in a joint swapped for a part of its shape is laid
## (smalls10 item 1). A file seats a pin in a beam's hole, the hips under a
## leg, an axle through a brick: each meets what holds it where it stands.
## replace_parts 2780 for 4459 and 3815 for 3815b answered "1 has no room"
## (jlfix 11-19): the room test counted the part the old one was seated in
## against the new one. Now the new part, laid where the old one was, is
## held by the joint rule a part put down by hand is (Builder.room_for), as
## the old one was, and nothing else.
##
##   godot --headless --path . --script src/dev/seatswap_probe.gd
##
## Each case opens its model (a small one written here, or a real set from
## the OMR), says the cause (what the old part meets where it stands, what
## the new one would), then swaps every copy of the part by replace_parts:
## all laid, one undo step, and that undo saves the bytes saved before it
## (but the MCP's mark of the assistant's model, which an undo keeps). 3701
## for 3894 beside a wall still has no room. The hinge's pin is also swapped
## by the hand's Replace (Builder.replace_selection).
extends "res://src/dev/jointlock_probe.gd"

const OMR := "/mnt/Projects/brickworks/vendor/omr/files/"

## [what, model ("hinge", "knee", "slider", "wall" or "omr:<set>"), old part,
## new part, laid or refused, and why it is still refused if it is KNOWN].
const CASES := [
	["a pin in a brick's hole", "hinge", "2780", "4459", true],
	["minifig hips under a leg", "knee", "3815", "3815b", true],
	["an axle pin in a set", "omr:6507-1", "3749", "43093", true],
	["an axle with a stop in a set", "omr:4991-1", "32209", "59426", true,
		"59426's cover reaches 49 cells into the 32064a it turns in, which 32209's never met, and the joint rule (room_for) does not hold it there"],
	["a ball joint in a set", "omr:30201-1", "32474", "32474p02", true],
	["a hinge plate in a set", "omr:1887-1", "4275b", "4275a", true],
	["a clip in a set", "omr:6632-1", "4085b", "4085c", true],
	["a bar in a clip in a set", "omr:60065-1", "87994", "87994p01", true],
	["a turntable top in a set", "omr:6690-1", "3404", "3404b", true,
		"3404b, the dimpled generation's top, has another box than 3404: moved to sit its own way, it meets the 3403 base in 2982 cells, and only a part of the old one's box laid where it stood is excused what the old one met"],
	["a 1 x 4 brick for a 1 x 6 against a wall", "wall", "3701", "3894", false],
]


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and _main.get("_world") != null:
			break
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var account: Account = _main.get("_account")
	while account.state == Account.State.CHECKING:
		await account.changed
	account.email = "seatswap-probe@example.com"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	var laid: int = 0
	for case: Array in CASES:
		print("\n══ %s: %s for %s ══" % case.slice(0, 3))
		if await _case(case):
			laid += 1
	await _hand_replace()
	await _paced_replace()
	print("")
	print("seatswap: %d of %d as asked" % [laid, CASES.size()])
	print("seatswap: %d FAILED" % _failures if _failures > 0 else "seatswap: all held")
	quit(1 if _failures > 0 else 0)


func _open_case(model: String) -> bool:
	var path: String = MODELS + model.trim_prefix("omr:") + (".mpd" if model.begins_with("omr:") else ".ldr")
	if model.begins_with("omr:"):
		var text: String = FileAccess.get_file_as_string(OMR + model.trim_prefix("omr:") + ".mpd")
		if text.is_empty():
			print("    no such set file")
			return false
		_write(path, text)
	else:
		var texts: Dictionary = {"hinge": _hinge_ldr(), "knee": _knee_ldr(), "slider": _slider_ldr(),
			"wall": _wall_ldr()}
		_write(path, texts[model])
	await _open(path)
	return true


## A Technic brick 1 x 4 with a brick 1 x 2 against its end: a 1 x 6 laid
## centred where it is runs into the 1 x 2.
static func _wall_ldr() -> String:
	return "\n".join(PackedStringArray(["0 FILE wall.ldr", "0 A brick against a wall", "0 Name: wall.ldr",
		"0 !BRICKWORKS FLOOR NONE",
		"1 7 0 -24 0 1 0 0 0 1 0 0 0 1 3701.dat",
		"1 4 60 -24 0 1 0 0 0 1 0 0 0 1 3004.dat",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"])) + "\n"


func _ids_of(part: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			out.append(brick.id)
	return out


## What [param packed] meets, by part number, but [param own].
func _met(packed: PackedInt32Array, own: int) -> String:
	var parts: PackedStringArray = []
	for other: int in _builder.lattice.blockers_boxes(packed, own):
		parts.append("%s (%d cells)" % [_world.get_brick(other).part_id if _world.get_brick(other) != null
			else str(other), BrickLattice.shared_cells(packed, _builder.lattice.boxes_of(other))])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


func _case(case: Array) -> bool:
	var old: String = case[2]
	var new: String = case[3]
	var want_laid: bool = case[4]
	if not await _open_case(case[1]):
		_check("%s: its model opens" % case[0], false)
		return false
	var library: PartLibrary = _main.get("_library")
	if library.mesh_for(new) == null:
		_check("%s: %s is in the library" % [case[0], new], false)
		return false
	var olds: Array = _ids_of(old)
	var news_before: int = _ids_of(new).size()
	if olds.is_empty():
		_check("%s: the model has a %s" % [case[0], old], false)
		return false
	# The cause, asked of the lattice as the room test asks it.
	var seated: int = 0
	for id: int in olds.slice(0, 3):
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var was: PackedInt32Array = _builder.lattice.boxes_of(id)
		var shape: Lbm.PartMesh = library.mesh_for(new)
		var at: Transform3D = _builder._in_place_of(brick.transform, library.mesh_for(old), shape)
		var packed: PackedInt32Array = _builder.boxes_for(shape, at)
		print("    #%d %s meets %s where it stands; %s there would meet %s" % [id, old, _met(was, id),
			new, _met(packed, id)])
		if _builder.lattice.collides_boxes(was, id):
			seated += 1
	print("    %d of %d %s seated (meets what holds it)" % [seated, mini(olds.size(), 3), old])
	var before: String = await _save("seatswap_before.ldr")
	var depth: int = _builder.history_depth()
	var said: String = await _say("replace_parts", {"find": {"part": old}, "replace": {"part": new}})
	print("    said: %s" % said.replace("\n", " | ").left(300))
	var now_new: int = _ids_of(new).size() - news_before
	var left: int = _ids_of(old).size()
	var steps: int = _builder.history_depth() - depth
	var laid: bool = now_new == olds.size() and left == 0
	if want_laid and not laid and case.size() > 5:
		print("  KNOWN %s: %d of %d %s laid as %s: %s" % [case[0], now_new, olds.size(), old, new, case[5]])
		return false
	if want_laid:
		_check("%s: %d of %d %s laid as %s, one step (%d)" % [case[0], now_new, olds.size(), old, new, steps],
			laid and steps == 1 and not said.contains("no room"))
	else:
		_check("%s: no room, nothing changed (%d laid, %d steps): \"%s\"" % [case[0], now_new, steps,
			said.replace("\n", " | ").left(120)], now_new == 0 and steps == 0 and said.contains("no room"))
	if steps > 0:
		_builder.undo()
		await _settled()
		# The MCP marks the model as the assistant's (ModelStore.MADE_META),
		# which an undo does not take back: compared without it.
		var back: String = _without_made(await _save("seatswap_back.ldr"))
		_check("%s: one undo saves the bytes saved before (%s)" % [case[0],
			"same" if back == _without_made(before) else _first_difference(_without_made(before), back)],
			back == _without_made(before) and _builder.history_depth() == depth)
	return laid == want_laid


## The hand's Replace on the hinge's pin: selected, replaced, laid in one
## step, and undone byte for byte.
func _hand_replace() -> void:
	print("\n══ the hand's Replace: 2780 for 4459 ══")
	await _open_case("hinge")
	var pin: int = _id_of("2780")
	var before: String = await _save("seatswap_before.ldr")
	var depth: int = _builder.history_depth()
	# The pin alone, as inside its sub-model (a click outside takes the pin
	# and the beam on it, Assemblies.unit_of).
	var unit_of: Callable = _builder.unit_of
	_builder.unit_of = Callable()
	_select(pin)
	_builder.unit_of = unit_of
	var done: Vector2i = _builder.replace_selection("4459")
	await _settled()
	_check("the hand's Replace lays the pin (%d laid, %d no room; 4459s %d, 2780 gone %s, beam kept %s)"
		% [done.x, done.y, _ids_of("4459").size(), _id_of("2780") == 0, _id_of("32524") != 0],
		done == Vector2i(1, 0) and _ids_of("4459").size() == 1 and _id_of("2780") == 0
		and _id_of("32524") != 0 and _builder.history_depth() == depth + 1)
	if _builder.history_depth() > depth:
		_builder.undo()
		await _settled()
		var back: String = await _save("seatswap_back.ldr")
		_check("...undone byte for byte (%s)" % ("same" if back == before else _first_difference(before, back)),
			back == before)


## 300 pins, each in its beam, all selected (600 parts, Builder.
## REPLACE_ON_A_WORKER_FROM) and replaced with 4459 by the hand's Replace on
## a worker (replace_selection_paced): the same counts and the same save as
## the same Replace on the main thread (replace_selection), each one undo
## step undone byte for byte. The pins are asked again on the main thread
## (Builder._ASK); the beams, each laid as a pin at its middle, are asked of
## the lattice as it stands after them.
func _paced_replace() -> void:
	print("\n══ the hand's Replace of 600 parts, on a worker and not ══")
	var lines := PackedStringArray(["0 FILE pins.ldr", "0 Pins in beams", "0 Name: pins.ldr",
		"0 !BRICKWORKS FLOOR NONE"])
	for n: int in 300:
		var x: int = (n % 20) * 200
		var z: int = (n / 20) * 200
		lines.append("1 0 %d -302 %d 0 0 -1 0 1 0 1 0 0 2780.dat" % [x, z + 10])
		lines.append("1 14 %d -242 %d -1 0 0 0 0 1 0 1 0 32524.dat" % [x, z + 20])
	_write(MODELS + "pins.ldr", "\n".join(lines) + "\n")
	await _open(MODELS + "pins.ldr")
	var before: String = await _save("seatswap_before.ldr")
	var results: Array = []
	for paced: bool in [true, false]:
		var depth: int = _builder.history_depth()
		var unit_of: Callable = _builder.unit_of
		_builder.unit_of = Callable()
		_builder.clear_selection()
		for brick: BrickWorld.Brick in _world.bricks():
			_builder.select_brick(brick.id, true)
		_builder.unit_of = unit_of
		var done: Vector2i = await _builder.replace_selection_paced("4459") if paced \
			else _builder.replace_selection("4459")
		await _settled()
		var after: String = await _save("seatswap_after_%s.ldr" % ("paced" if paced else "main"))
		results.append([done, _ids_of("4459").size(), _ids_of("2780").size(), _ids_of("32524").size(), after])
		print("    %s: %d laid, %d no room; 4459 %d, 2780 %d, 32524 %d" % ["worker" if paced else "main thread",
			done.x, done.y, _ids_of("4459").size(), _ids_of("2780").size(), _ids_of("32524").size()])
		_check("%s: one undo step" % ("on a worker" if paced else "on the main thread"),
			_builder.history_depth() == depth + 1)
		if _builder.history_depth() > depth:
			_builder.undo()
			await _settled()
		var back: String = await _save("seatswap_back.ldr")
		_check("...undone byte for byte (%s)" % ("same" if back == before else _first_difference(before, back)),
			back == before)
	_check("on a worker as on the main thread: the same counts and the same save (%s)" % ("same"
		if results[0][4] == results[1][4] else _first_difference(results[1][4], results[0][4])),
		results[0].slice(0, 4) == results[1].slice(0, 4) and results[0][4] == results[1][4])
	_check("every pin laid (%d of 300 2780 left)" % results[0][2], results[0][2] == 0)
