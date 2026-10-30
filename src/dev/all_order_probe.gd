## Is All's order as the web export writes it the bin's own, and is it set
## aside whenever it might not be?
##
##   godot --headless --path . --script src/dev/all_order_probe.gd
##
## A first visit to the web app spent most of a second of its start working
## out the parts bin's All with nothing typed: sorting twenty thousand parts
## and waiting for the parts LDraw keeps only for old files (webload,
## 2026-10-30). The web export now works it out once (src/dev/all_order.gd)
## and the bin reads it (PartsBin.all_as_packed). Read back here, the order
## must be the one the bin works out itself, part for part, with as many set
## aside; and it must not be read for a catalogue of another size, one that
## lacks a part it names, or a library holding parts made in the app, whose
## made parts it does not list. Reading it must cost less than working it out.
extends SceneTree

var _failed: int = 0
var _passed: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FAIL  ", what)


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("all_order probe: FAIL, no catalogue")
		quit(1)
		return
	var path: String = OS.get_user_data_dir().path_join("all_order_probe.txt")
	var began: int = Time.get_ticks_usec()
	var made: Array = PartsBin.write_all_order(library, path)
	var worked_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	_check(not made.is_empty(), "the order is written")
	if made.is_empty():
		quit(1)
		return
	var computed: Array = made[0]
	began = Time.get_ticks_usec()
	var read: Array = PartsBin.all_as_packed(library, path)
	var read_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	_check(not read.is_empty(), "the order is read back")
	if read.is_empty():
		quit(1)
		return
	var listed: Array = read[0]
	var same: bool = listed.size() == computed.size()
	var first_off: int = -1
	for n: int in mini(listed.size(), computed.size()):
		if listed[n] != computed[n]:
			same = false
			first_off = n
			break
	_check(same and listed.size() > 10000, "read back, All is the bin's own order, part for part (%d parts%s)"
		% [listed.size(), "" if first_off < 0 else ", first apart at %d" % first_off])
	_check(int(read[1]) == int(made[1]) and int(made[1]) > 0,
		"as many set aside (%d against %d)" % [int(read[1]), int(made[1])])
	_check(read_ms < worked_ms, "reading it costs less than working it out (%.0f ms against %.0f)"
		% [read_ms, worked_ms])
	# The bin's own path, as the app fills it: with nothing typed, All's
	# first tiles are the order's first parts.
	var first: Array[String] = []
	for n: int in 5:
		first.append((computed[n] as PartLibrary.PartInfo).id)
	print("  All begins ", ", ".join(first))

	# Another catalogue's: its count is not this one's.
	var text: String = FileAccess.get_file_as_string(path)
	var lines: PackedStringArray = text.split("\n", false)
	var head: PackedStringArray = lines[0].split(" ")
	var other: String = OS.get_user_data_dir().path_join("all_order_probe_other.txt")
	_write(other, "%d %s\n%s" % [head[0].to_int() + 1, head[1], "\n".join(lines.slice(1))])
	_check(PartsBin.all_as_packed(library, other).is_empty(), "not read for a catalogue of another size")
	# One naming a part this catalogue lacks.
	_write(other, "%s\n%s\nnot-a-part-7x\n" % [lines[0], "\n".join(lines.slice(1, 50))])
	_check(PartsBin.all_as_packed(library, other).is_empty(), "not read when it names a part the catalogue lacks")
	# Nothing there.
	_check(PartsBin.all_as_packed(library, other + ".none").is_empty(), "not read when there is none")
	# A part made in the app: the order does not hold it.
	library.custom["probe-made-1"] = "0 a part made here\n"
	_check(PartsBin.all_as_packed(library, path).is_empty(), "not read with a part made in the app")
	library.custom.erase("probe-made-1")
	_check(not PartsBin.all_as_packed(library, path).is_empty(), "read again once there is none")

	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(other)
	print("all_order probe: %d ok, %d FAIL" % [_passed, _failed])
	print("all_order probe: all passed" if _failed == 0 else "all_order probe: FAILED")
	quit(1 if _failed else 0)


func _write(path: String, text: String) -> void:
	var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	out.store_string(text)
	out.close()
