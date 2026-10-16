## What survives a real set's file opened, saved and opened again, in each
## format the app writes.
##
##   godot --headless --path . --script src/dev/roundtrip_probe.gd -- --out=FILE.jsonl PATH ...
##
## Each PATH (.mpd, .ldr, .io, .lxf) is read as File, Open reads it
## (ModelFilePicker.take), opened by ModelStore.open_text, then written as
## Save and Export write it: LDraw by ModelStore.to_text with its build
## steps, and a Studio .io by StudioIo.pack around that text, read back by
## StudioIo.read. Each written file is opened again by open_text. LDD's .lxf
## is read only: the app does not write it.
##
## For each file one JSON line goes to FILE: every part as the file means it
## (LdrModel.parse and flatten, the reader every format ends in), as the app
## placed it, as each written file means it, and as each reopened. A part is
## "id colour x y z a b c d e f g h i|step path|unit|group" in LDraw's
## coordinates. tools/cadtask.py compares them; nothing is judged here, so
## the measure is not the thing measured.
##
## Not in the suite: tools/cadtask.py roundtrip runs it on a sample.
extends SceneTree

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _picker: ModelFilePicker
var _picked: String = ""
var _failed: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var out_path: String = ""
	var paths: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--list="):
			for line: String in FileAccess.get_file_as_string(argument.trim_prefix("--list=")) \
					.split("\n", false):
				paths.append(line.strip_edges())
		else:
			paths.append(argument)
	if out_path.is_empty() or paths.is_empty():
		print("usage: roundtrip_probe.gd -- --out=FILE.jsonl PATH ... (or --list=FILE)")
		quit(2)
		return
	# A file's own parts are built and kept as a file's carried parts are:
	# here, never in the person's bin.
	CustomParts.dir = OS.get_user_data_dir().path_join("roundtrip_probe_parts/")
	CustomParts.keeps = false
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("roundtrip: FAIL the catalogue does not load")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.builder = _builder
	_store.library = _library
	_picker = ModelFilePicker.new()
	get_root().add_child(_picker)
	_picker.picked.connect(func(text: String, _name: String) -> void: _picked = text)
	_picker.failed.connect(func(why: String) -> void: _failed = why)
	await process_frame

	# Appended, so a run that dies part way keeps what it measured and the
	# runner starts again after the file it died on.
	var out: FileAccess = FileAccess.open(out_path,
		FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
	out.seek_end()
	var done: int = 0
	for path: String in paths:
		print("roundtrip: %s" % path.get_file())
		var row: Dictionary = _one(path)
		out.store_line(JSON.stringify(row))
		out.flush()
		done += 1
	out.close()
	print("roundtrip: %d files written to %s" % [done, out_path])
	quit(0)


func _one(path: String) -> Dictionary:
	var name: String = path.get_file().get_basename()
	var row: Dictionary = {"file": path.get_file(), "in": path.get_extension().to_lower()}
	var began: int = Time.get_ticks_msec()
	_picked = ""
	_failed = ""
	_picker.take(FileAccess.get_file_as_bytes(path), path.get_file())
	row["read_note"] = _picker.notes
	if not _failed.is_empty() or _picked.is_empty():
		row["error"] = "could not read: " + _failed
		return row
	var text: String = _picked
	row["truth"] = _as_file(text)

	_world.clear()
	var opened: Dictionary = _store.open_text(text, name)
	row["open"] = _opened(opened, began)
	if int(opened["placed"]) == 0 and _store.awaited.is_empty():
		row["error"] = "did not open: " + str(opened.get("error", ""))
		return row
	row["opened"] = _bricks()

	# Both written from the one model the file opened as, as Save and
	# Export → Studio write them.
	var began_save: int = Time.get_ticks_msec()
	var ldr: String = _store.to_text(_store.title, true)
	var save_ms: int = Time.get_ticks_msec() - began_save
	var packed: PackedByteArray = StudioIo.pack(ldr, PackedByteArray(), ModelStore.count_in(ldr),
		Exports.studio_parts(_world, _library))
	var io_read: Dictionary = StudioIo.read(packed)
	var outs: Dictionary = {}
	outs["ldr"] = _again(ldr, name, save_ms, "")
	outs["io"] = _again(str(io_read["text"]), name, save_ms, str(io_read["error"]),
		packed.size())
	row["out"] = outs
	row["seconds"] = (Time.get_ticks_msec() - began) / 1000.0
	return row


## A written file: what it says, and what it opens as.
func _again(text: String, name: String, save_ms: int, error: String, size: int = -1) -> Dictionary:
	var again: Dictionary = {"bytes": size if size >= 0 else text.to_utf8_buffer().size(),
		"save_ms": save_ms, "error": error}
	if not error.is_empty():
		return again
	again["file"] = _as_file(text)
	var began: int = Time.get_ticks_msec()
	_world.clear()
	var opened: Dictionary = _store.open_text(text, name)
	again["open"] = _opened(opened, began)
	again["reopened"] = _bricks()
	return again


func _opened(opened: Dictionary, began: int) -> Dictionary:
	return {"placed": int(opened.get("placed", 0)), "missing_ids": opened.get("missing_ids", {}),
		"waiting": int(opened.get("waiting", 0)), "awaited": _store.awaited.size(),
		"lifted_by": _store._lifted_by, "error": str(opened.get("error", "")),
		"title": _store.title, "ms": Time.get_ticks_msec() - began}


## What a file says, by the reader every format ends in.
func _as_file(text: String) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "model")
	var parts: Array = []
	for placement: LdrModel.Placement in model.flatten(_library.parts):
		parts.append(_line(placement.part_id, placement.color_code, placement.transform,
			_path(placement.unit, placement.step, model.unit_steps), placement.unit,
			placement.group))
	var files: int = 0
	# The meta commands the file has, by name, and how many of each: what a
	# round trip can drop without a part moving (ROTSTEP's view, LPub's
	# page setup, MLCad's groups, a ghost, a buffer exchange).
	var metas: Dictionary = {}
	var meta := RegEx.create_from_string("^!?[A-Z][A-Z_]*:?$")
	for line: String in text.split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() < 2 or words[0] != "0":
			continue
		if words[1].to_upper() == "FILE":
			files += 1
		var said: String = words[1]
		if meta.search(said) != null or said in ["Name:", "Author:"]:
			metas[said] = int(metas.get(said, 0)) + 1
	return {"parts": parts, "stepped": model.stepped, "authored": model.steps_are_authored(),
		"author": model.author, "submodels": model.submodels.size(), "files": files,
		"embedded_parts": model.embedded_parts.size(), "metas": metas}


## Every part on the baseplate, the model's own (not its floor).
func _bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		out.append(_line(brick.part_id, brick.color_code, brick.transform,
			_path(brick.unit, brick.step, _world.unit_steps), brick.unit, brick.group))
	return out


## The steps a part goes on in, outermost first: each copy of a sub-model's
## step in the one that places it, then the part's own.
static func _path(unit: String, step: int, unit_steps: Dictionary) -> String:
	var out := PackedStringArray()
	var prefix: String = ""
	if not unit.is_empty():
		for piece: String in unit.split("/"):
			prefix = piece if prefix.is_empty() else prefix + "/" + piece
			out.append(str(int(unit_steps.get(prefix, -1))))
	out.append(str(step))
	return ".".join(out)


static func _line(part_id: String, colour: int, at: Transform3D, steps: String, unit: String,
		group: String) -> String:
	var numbers := PackedStringArray()
	for v: float in LdrModel.from_transform(at):
		numbers.append(str(snappedf(v, 0.001)))
	return "%s %d %s|%s|%s|%s" % [part_id, colour, " ".join(numbers), steps, unit, group]
