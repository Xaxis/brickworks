## Does the web's catalogue read from its columns (catalogue.bin) give every
## part as the JSON gives it, in less memory and no more time?
##
##   godot --headless --path . --script src/dev/catalogue_columns_probe.gd -- [--catalogue=PATH]
##
## The catalogue (default: the web pack's, else the full library's) is read
## twice, as the app reads it: from its JSON, and from the columns made of
## it (PartLibrary.columns_of) and written out as the export writes them.
## Every field of every part must be the same, and the order of the parts,
## the set norms, the kinds and where availability comes from.
##
## The bar (webstart11, 2026-11-18): no field of any part differs; the
## columns' height of memory over the start is under half the JSON's; and
## the read is no slower. Memory is the engine's own count, which a debug
## build keeps (OS.get_static_memory_usage): what a web page's Wasm memory
## grows to hold, a web page never gives back.
extends SceneTree


## What a part works out on first asking and keeps (a search, the bin's
## sort, the export's All order), by the method that fills it: compared by
## that method, since one library may have been asked and the other not.
const LAZY := {"_decor": "decor", "_printed": "printed", "_own": "own_words", "_keyed": "keyword_words"}


## Each difference between [param a] and [param b], read from the same
## catalogue, as words; the first [param most] of them.
static func differences(a: PartLibrary, b: PartLibrary, most: int = 20) -> PackedStringArray:
	var said := PackedStringArray()
	if a._ordered_ids != b._ordered_ids:
		said.append("the parts' order differs (%d against %d)" % [a._ordered_ids.size(), b._ordered_ids.size()])
	for field: String in ["set_norms", "kinds", "kinds_measured_over", "recent_since", "availability_source"]:
		if a.get(field) != b.get(field):
			said.append("the catalogue's %s differs" % field)
	var names: Array[String] = []
	for property: Dictionary in PartLibrary.PartInfo.new().get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and not LAZY.has(str(property.name)):
			names.append(str(property.name))
	var asked: Array[String] = []
	for method: String in LAZY.values():
		asked.append(method)
	for id: String in a.parts:
		if said.size() >= most:
			break
		if not b.parts.has(id):
			said.append("%s is missing" % id)
			continue
		var one: Object = a.parts[id]
		var two: Object = b.parts[id]
		for name: String in names + asked:
			var x: Variant = one.call(name) if asked.has(name) else one.get(name)
			var y: Variant = two.call(name) if asked.has(name) else two.get(name)
			if x is Object or y is Object:
				x = (x as PartLibrary.PartInfo).id if x != null else ""
				y = (y as PartLibrary.PartInfo).id if y != null else ""
			if typeof(x) != typeof(y) or x != y:
				said.append("%s's %s: %s against %s" % [id, name, str(x).left(80), str(y).left(80)])
	if b.parts.size() != a.parts.size():
		said.append("%d parts against %d" % [a.parts.size(), b.parts.size()])
	return said


func _initialize() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--catalogue="):
			path = argument.trim_prefix("--catalogue=")
	if path.is_empty():
		path = PartLibrary.PACK_ROOT + "catalogue.json"
		if not FileAccess.file_exists(path):
			path = PartLibrary.FULL_ROOT + "catalogue.json"
	var fails: int = 0
	# The JSON, as every build but the web's reads it.
	var base: int = OS.get_static_memory_usage()
	_watch()
	var started: int = Time.get_ticks_usec()
	var from_json := PartLibrary.new()
	from_json._root = path.get_base_dir() + "/"
	if not from_json.load_catalogue(path):
		print("FAIL: no catalogue at %s" % path)
		quit(1)
		return
	var json_us: int = Time.get_ticks_usec() - started
	var json_height: int = _watched() - base
	var json_kept: int = OS.get_static_memory_usage() - base
	# The columns, made and written as the export makes them.
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bytes: PackedByteArray = var_to_bytes(PartLibrary.columns_of(document))
	document = {}
	var bin: String = "user://catalogue_columns_probe/" + PartLibrary.COLUMNS
	DirAccess.make_dir_recursive_absolute(bin.get_base_dir())
	var out: FileAccess = FileAccess.open(bin, FileAccess.WRITE)
	out.store_buffer(bytes)
	out.close()
	bytes = PackedByteArray()
	# Read as the web reads it, the JSON's library still held.
	base = OS.get_static_memory_usage()
	_watch()
	started = Time.get_ticks_usec()
	var from_columns := PartLibrary.new()
	from_columns._root = path.get_base_dir() + "/"
	var read: bool = from_columns.load_catalogue(bin)
	var columns_us: int = Time.get_ticks_usec() - started
	var columns_height: int = _watched() - base
	var columns_kept: int = OS.get_static_memory_usage() - base
	if not read:
		print("FAIL: the columns did not read")
		quit(1)
		return
	var said: PackedStringArray = differences(from_json, from_columns)
	print("catalogue %s: %d parts; columns %.1f MB" % [path, from_json.parts.size(),
		FileAccess.get_file_as_bytes(bin).size() / 1e6])
	print("  JSON:    %4d ms, memory at its height +%.1f MB, kept +%.1f MB" % [json_us / 1000, json_height / 1e6, json_kept / 1e6])
	print("  columns: %4d ms, memory at its height +%.1f MB, kept +%.1f MB" % [columns_us / 1000, columns_height / 1e6, columns_kept / 1e6])
	if not said.is_empty():
		fails += 1
		print("FAIL: the columns read differently:\n  " + "\n  ".join(said))
	else:
		print("ok: every field of every part the same")
	if columns_height * 2 > json_height:
		fails += 1
		print("FAIL: the columns' height is not under half the JSON's")
	else:
		print("ok: the columns' height under half the JSON's")
	# The JSON was read first, so it paid for the scripts' first calls too:
	# a tenth over it is still no slower.
	if columns_us > json_us * 1.1:
		fails += 1
		print("FAIL: the columns read slower")
	else:
		print("ok: the columns read no slower")
	# A file of another format is refused, not read wrong.
	var wrong := PartLibrary.new()
	var bad: FileAccess = FileAccess.open(bin, FileAccess.WRITE)
	bad.store_buffer(var_to_bytes({"format": PartLibrary.COLUMNS_FORMAT + 1}))
	bad.close()
	if wrong.load_catalogue(bin) or not wrong.parts.is_empty():
		fails += 1
		print("FAIL: a catalogue.bin of another format was read")
	else:
		print("ok: a catalogue.bin of another format is refused")
	DirAccess.remove_absolute(bin)
	print("catalogue_columns: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(0 if fails == 0 else 1)


# The height of the memory while a read runs, watched from a thread of its
# own: the engine's own peak is a whole run's, and compiling the app's
# scripts at load set it higher than either read.
var _watcher: Thread
var _lock := Mutex.new()
var _most: int = 0
var _watching: bool = false


func _watch() -> void:
	_lock.lock()
	_most = OS.get_static_memory_usage()
	_watching = true
	_lock.unlock()
	_watcher = Thread.new()
	_watcher.start(_sample)


func _sample() -> void:
	while true:
		var now: int = OS.get_static_memory_usage()
		_lock.lock()
		_most = maxi(_most, now)
		var going: bool = _watching
		_lock.unlock()
		if not going:
			return
		OS.delay_usec(200)


func _watched() -> int:
	_lock.lock()
	_watching = false
	_lock.unlock()
	_watcher.wait_to_finish()
	return maxi(_most, OS.get_static_memory_usage())
