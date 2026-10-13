## Opening and saving BrickLink Studio's .io, the way a Studio builder
## brings a model in and takes it back out.
##
##   godot --headless --path . --script src/dev/io_probe.gd
##
## Read: tests/fixtures/studio/bay_2025.io and bay_2021.io, made by
## tests/fixtures/studio/make_fixtures.py in the shapes of two files Studio
## itself saved (2.25.2, not locked; 2.2.1, locked with Studio's password by
## the system's zip), and bay_aes.io, the 2021 one locked with WinZip's AES,
## which libarchive's own AES test file proves the reader against. Each holds the model twice, in LDraw's numbers
## (model.ldr) and in BrickLink's (model2.ldr), so the colours say which was
## read: every part has to come out in LDraw's colour, where Studio put it,
## in its sub-model and its step, and a part only Studio has is named.
##
## Write: a model exported as .io is a zip that the system's own unzip and
## Godot's own zip reader both open, holding model.ldr, .info,
## errorPartList.err (and the thumbnail, when there is a screen to draw it).
##
## The author's steps: tests/fixtures/steps/gatehouse.mpd (five steps, a base
## with two of its own, a window with three put on twice) and the same model
## as a Studio file, gatehouse_2025.io, each opened, saved, exported as .io and
## opened again: every section's steps as the author made them, and the
## timeline's steps the same each time. Then a part moved a step later, saved
## and reopened in its new step, and an undo putting it back. Before, the
## steps were read and dropped, and saving wrote Brickworks's own order.
##
## Round trip: the castle (2,438 parts in its sub-models, in steps) and the
## Studio bay, exported to .io and opened again: the .io carries the
## model's LDraw exactly, steps and all, and opens as the same parts in the
## same colours, places and sub-models. (Not the same text written a second
## time: the app works out the build order afresh for each file it writes,
## and an .ldr opened and written again comes out in another order too.)
##
## Refused, and said why: a damaged zip, a zip with no model in it, and a
## file that is not a zip at all.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore

const BAY_2025 := "res://tests/fixtures/studio/bay_2025.io"
const BAY_2021 := "res://tests/fixtures/studio/bay_2021.io"
const CUSTOM := "m1a2b3c4_2025408_163200"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		_check("the catalogue loads", false)
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
	await process_frame

	_read_2025()
	_read_2021()
	_read_aes()
	await _opened_by_the_picker()
	_written()
	_round_trip("res://models/castle.ldr")
	_round_trip_of(BAY_2025)
	_authored_steps()
	await _refused()
	print("")
	if _failures == 0:
		print("io: Studio's .io opens in LDraw's numbers with its sub-models and steps, "
			+ "an exported one is a zip that opens, the round trip is the same model, "
			+ "and an author's steps survive open, edit and save, step by step")
	else:
		print("io: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- read ---------------------------------------------------------------------


func _read_2025() -> void:
	print("  bay_2025.io, as Studio 2.25 writes one (not locked)")
	var read: Dictionary = StudioIo.read(FileAccess.get_file_as_bytes(BAY_2025))
	_check("it reads (%s)" % _said(read), str(read["error"]).is_empty())
	var text: String = str(read["text"])
	_check("model.ldr, not model2.ldr or modelv2.ldr, with Studio's byte-order mark gone: \"%s\""
		% text.substr(0, 20).c_escape(), text.begins_with("0 FILE bay_2025.io"))
	var model: LdrModel = LdrModel.parse(text, "bay_2025")
	var placed: Array[LdrModel.Placement] = model.flatten(_library.parts)
	var found: Dictionary = {}
	for placement: LdrModel.Placement in placed:
		found["%s/%d" % [placement.part_id, placement.color_code]] = placement
	_check("six parts, each in LDraw's colour — red 3001, white 3004, yellow 3022, blue 3001, "
		+ "black 3068b, and Studio's own part (%s)" % ", ".join(found.keys()),
		placed.size() == 6 and found.has("3001/4") and found.has("3004/15")
		and found.has("3022/14") and found.has("3001/1") and found.has("3068b/0")
		and found.has(CUSTOM + "/71"))
	if placed.size() != 6 or not found.has("3004/15") or not found.has("3068b/0"):
		return
	var white: LdrModel.Placement = found["3004/15"]
	var expected: Transform3D = LdrModel.to_transform(PackedFloat64Array(
		[-60, -48, -10, 0, 0, 1, 0, 1, 0, -1, 0, 0]))
	_check("the white 1 x 2 is where Studio put it, turned a quarter (%s)" % white.transform,
		white.transform.is_equal_approx(expected))
	_check("...in the build's second step (%d)" % white.step, white.step == 1)
	var tile: LdrModel.Placement = found["3068b/0"]
	_check("the black tile is in the sub-model, though Studio's FILE line says \"SubModel "
		+ "Group 1\" and its reference \"submodel group 1\" (group \"%s\")" % tile.group,
		tile.group == "SubModel Group 1")
	_check("...in that sub-model's second step (%d)" % tile.step, tile.step == 1)


func _read_2021() -> void:
	print("  bay_2021.io, as Studio 2.2.1 wrote one (locked with Studio's password)")
	var read: Dictionary = StudioIo.read(FileAccess.get_file_as_bytes(BAY_2021))
	_check("it reads (%s)" % _said(read), str(read["error"]).is_empty())
	var parts: Array = _parts_in(str(read["text"]))
	_check("three parts in LDraw's red, white and yellow, not BrickLink's 5, 1 and 3 (%s)"
		% str(parts), parts == ["3001/4", "3004/15", "3022/14"])


## WinZip's AES. libarchive's own AES-256 test file first, made by a tool
## that is not this one and opened with libarchive's password: it has to
## come out as the 6,818 bytes its directory states, its HMAC matching.
## Then the 2021 bay locked that way under Studio's password.
func _read_aes() -> void:
	print("  locked with AES")
	var vector: PackedByteArray = FileAccess.get_file_as_bytes(
		"res://tests/fixtures/studio/libarchive_aes256.zip")
	var entries: Dictionary = StudioIo._entries(vector)
	var entry: Dictionary = entries.get("readme", {})
	_check("libarchive's AES-256 file lists its README as AES-256, AE-2, deflated (%s)"
		% str(entry.get("aes", {})), entry.get("aes", {}) == {"version": 2, "strength": 3,
			"method": 8})
	if entry.is_empty():
		return
	var plain: PackedByteArray = StudioIo._unpack(vector, entry, "password")
	_check("...and opens with libarchive's password to its %d bytes: \"%s\"" % [plain.size(),
		plain.slice(0, 28).get_string_from_utf8()], plain.size() == 6818
		and plain.get_string_from_utf8().begins_with("README for libarchive bundle."))
	_check("...but not with Studio's", StudioIo._unpack(vector, entry).is_empty())
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"res://tests/fixtures/studio/bay_aes.io")
	var read: Dictionary = StudioIo.read(bytes)
	var parts: Array = _parts_in(str(read["text"]))
	_check("bay_aes.io, locked with AES-256 under Studio's password, reads in LDraw's colours "
		+ "(%s, %s)" % [_said(read), str(parts)], parts == ["3001/4", "3004/15", "3022/14"])
	var spoilt: PackedByteArray = bytes.duplicate()
	var model: Dictionary = StudioIo._entries(bytes)["model.ldr"]
	spoilt[int(model["at"]) + 40] = spoilt[int(model["at"]) + 40] ^ 0x01
	read = StudioIo.read(spoilt)
	_check("...and one bit changed in it is caught by its HMAC: \"%s\"" % read["error"],
		str(read["error"]).begins_with("could not unpack the model from that .io file"))


func _opened_by_the_picker() -> void:
	print("  opened through the file picker, as File, Open, From a file does")
	var picker := ModelFilePicker.new()
	get_root().add_child(picker)
	var got: Array = []
	picker.picked.connect(func(text: String, file_name: String) -> void:
		got.append([text, file_name]))
	picker.failed.connect(func(why: String) -> void: got.append(["", why]))
	picker.take(FileAccess.get_file_as_bytes(BAY_2025), "bay_2025.io")
	_check("the picker takes an .io and hands on its LDraw (%s)"
		% (got[0][1] if not got.is_empty() else "nothing"),
		got.size() == 1 and str(got[0][0]).begins_with("0 FILE bay_2025.io"))
	if got.is_empty() or str(got[0][0]).is_empty():
		picker.queue_free()
		return
	var result: Dictionary = _store.open_text(str(got[0][0]), "bay_2025")
	await process_frame
	var missing: Dictionary = result.get("missing_ids", {})
	_check("five placed, and the one only Studio has is named, not dropped in silence: "
		+ "%d placed, missing %s" % [int(result["placed"]), ModelStore.named_counts(missing)],
		int(result["placed"]) == 5 and missing == {CUSTOM: 1})
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
	_check("in the world in LDraw's colours (%s)" % colours,
		colours == {4: 1, 15: 1, 14: 1, 1: 1, 0: 1})
	_check("...under its file's name, not the \"Untitled Model\" Studio heads every model "
		+ "with (%s)" % _store.title, _store.title == "Bay 2025")
	picker.queue_free()


# -- write --------------------------------------------------------------------


func _written() -> void:
	print("  written: the house, as a Studio file")
	var opened: Dictionary = _store.open_text(
		FileAccess.get_file_as_string("res://models/house.ldr"), "house")
	var text: String = _store.to_text("House", true)
	var count: int = ModelStore.count_in(text)
	var picture := Image.create_empty(8, 6, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.8, 0.2, 0.2))
	var bytes: PackedByteArray = StudioIo.pack(text, picture.save_png_to_buffer(), count)
	var path: String = ProjectSettings.globalize_path("user://io_probe_house.io")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	_check("%d parts of the house opened and written: %d bytes" % [int(opened["placed"]),
		bytes.size()], int(opened["placed"]) > 50 and bytes.size() > 1000)

	var zip := ZIPReader.new()
	_check("Godot's own zip reader opens it", zip.open(path) == OK)
	var names: PackedStringArray = zip.get_files()
	_check("model.ldr, .info, errorPartList.err and the thumbnail in it (%s)" % ", ".join(names),
		Array(names) == ["model.ldr", ".info", "errorPartList.err", "thumbnail.png"])
	var ldr: String = zip.read_file("model.ldr").get_string_from_utf8()
	_check("model.ldr is the model's LDraw with Studio's Windows line ends, the build in steps "
		+ "(%d lines, %d steps)" % [ldr.count("\r\n"), ldr.count("0 STEP")],
		ldr == text.replace("\n", "\r\n") and ldr.count("0 STEP") > 3)
	var info: Variant = JSON.parse_string(zip.read_file(".info").get_string_from_utf8())
	_check(".info says how many parts, as Studio's does (%s)" % str(info),
		info is Dictionary and int(info.get("total_parts", 0)) == count
		and str(info.get("version", "")) == StudioIo.INFO_VERSION)
	_check("the thumbnail is a picture (%d bytes)" % zip.read_file("thumbnail.png").size(),
		Image.new().load_png_from_buffer(zip.read_file("thumbnail.png")) == OK)
	zip.close()
	var tested: Array = []
	if OS.execute("unzip", ["-t", path], tested, true) != -1 and not tested.is_empty():
		_check("the system's unzip tests it clean: \"%s\"" % str(tested[0]).strip_edges()
			.get_slice("\n", str(tested[0]).strip_edges().get_slice_count("\n") - 1),
			str(tested[0]).contains("No errors detected"))
	else:
		print("    (no unzip on this machine to test it with)")
	var read: Dictionary = StudioIo.read(bytes)
	_check("and it reads back here as the same text (%s)" % _said(read),
		str(read["error"]).is_empty() and str(read["text"]).replace("\r\n", "\n") == text)
	DirAccess.remove_absolute(path)


# -- round trip ---------------------------------------------------------------


## A model opened, exported as .io, and the .io opened again: the same
## LDraw comes out of the app both times.
func _round_trip(path: String) -> void:
	_round_trip_text(FileAccess.get_file_as_string(path), path.get_file().get_basename())


func _round_trip_of(io_path: String) -> void:
	var read: Dictionary = StudioIo.read(FileAccess.get_file_as_bytes(io_path))
	_round_trip_text(str(read["text"]), io_path.get_file().get_basename())


func _round_trip_text(source: String, name: String) -> void:
	print("  the round trip: %s, out to .io and back" % name)
	var first: Dictionary = _store.open_text(source, name)
	var before: String = _store.to_text(name, true)
	var bricks: Array = _bricks()
	var groups: Dictionary = _groups()
	var bytes: PackedByteArray = StudioIo.pack(before, PackedByteArray(),
		ModelStore.count_in(before))
	var read: Dictionary = StudioIo.read(bytes)
	var carried: String = str(read["text"]).replace("\r\n", "\n")
	# The steps are in the file and nowhere else: the app works the build
	# order out again when it writes one, so the file is where they have
	# to survive.
	_check("the .io carries the model's LDraw exactly, its %d steps and %d sub-models with it (%s)"
		% [before.count("0 STEP"), before.count("0 FILE") - 1, _said(read)], carried == before)
	var in_steps: Array = _steps_of(carried)
	_check("...and reads back as the same parts in the same steps (%d parts, last step %d)"
		% [in_steps.size(), int(in_steps.back().get_slice(" ", 0)) if not in_steps.is_empty()
			else -1], in_steps == _steps_of(before) and not in_steps.is_empty())
	_world.clear()
	_check("cleared between (%d bricks)" % _world.brick_count(), _world.brick_count() == 0)
	var again: Dictionary = _store.open_text(carried, name)
	_check("%d parts opened, %d back" % [int(first["placed"]), int(again["placed"])],
		int(first["placed"]) == int(again["placed"]) and int(again["placed"]) > 0)
	var after: Array = _bricks()
	var different: String = ""
	for n: int in mini(bricks.size(), after.size()):
		if bricks[n] != after[n]:
			different = " — \"%s\" became \"%s\"" % [bricks[n], after[n]]
			break
	_check("the same parts in the same colours in the same places%s" % different,
		bricks == after and not bricks.is_empty())
	_check("in the same sub-models (%s)" % _shown(groups), _groups() == groups)


## Every brick as "part colour group x y z" and its turn, rounded, sorted.
func _bricks() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var numbers := PackedStringArray()
		for v: float in LdrModel.from_transform(brick.transform):
			numbers.append(str(snappedf(v, 0.01)))
		out.append("%s %d %s %s" % [brick.part_id, brick.color_code, brick.group,
			" ".join(numbers)])
	out.sort()
	return out


## Every part of [param text] as "step part colour group", in the file's order.
func _steps_of(text: String) -> Array:
	var out: Array = []
	for placement: LdrModel.Placement in LdrModel.parse(text, "model").flatten(_library.parts):
		out.append("%d %s %d %s" % [placement.step, placement.part_id, placement.color_code,
			placement.group])
	return out


func _groups() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.group] = int(out.get(brick.group, 0)) + 1
	return out


func _shown(groups: Dictionary) -> String:
	var keys: Array = groups.keys()
	keys.sort()
	return ", ".join(keys.slice(0, 4).map(func(k: String) -> String:
		return "%s %d" % [k if not k.is_empty() else "(loose)", int(groups[k])])) \
		+ (", …" if keys.size() > 4 else "")


# -- the author's steps ---------------------------------------------------------


const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"
const GATEHOUSE_IO := "res://tests/fixtures/studio/gatehouse_2025.io"


func _authored_steps() -> void:
	var source: String = FileAccess.get_file_as_string(GATEHOUSE)
	_authored_round_trip(source, "gatehouse", "gatehouse.mpd")
	var read: Dictionary = StudioIo.read(FileAccess.get_file_as_bytes(GATEHOUSE_IO))
	_check("gatehouse_2025.io reads (%s)" % _said(read), str(read["error"]).is_empty())
	_authored_round_trip(str(read["text"]), "gatehouse_2025", "gatehouse_2025.io")
	_authored_edit(source)


## Opened, saved, packed as .io, read and opened again: the steps the file
## has each time, and the timeline's.
func _authored_round_trip(source: String, name: String, shown: String) -> void:
	print("  the author's steps: %s, opened, saved, out to .io and opened again" % shown)
	var expected: Dictionary = _file_steps(source)
	var opened: Dictionary = _store.open_text(source, name)
	_check("%d parts opened, every one with the author's step (%s)" % [int(opened["placed"]),
		_stepped()], int(opened["placed"]) == 14 and _stepped() == "14 of 14")
	var timeline: Array = _timeline()
	_check("the timeline is in the author's steps: %s" % " | ".join(timeline.slice(0, 7)),
		timeline.size() == 9 and str(timeline[0]).begins_with("1: 3001/4 3001/4")
		and str(timeline[2]).begins_with("3: 3003/14") and str(timeline[3]).begins_with("4: 3005/1")
		and str(timeline[4]).begins_with("5 Window 1/3: 3005/71 3005/71"))
	var saved: String = _store.to_text(name, true)
	var kept: Dictionary = _file_steps(saved)
	_check("saved, every sub-model's steps are the author's (%s)" % _shown_steps(kept),
		kept == expected and not kept.is_empty())
	_check("...and the file says they are, so they are kept again",
		saved.contains(LdrModel.AUTHORED_META))
	_check("the autosave keeps them too", _file_steps(_store.to_text(name)) == expected)
	var carried: String = str(StudioIo.read(StudioIo.pack(saved, PackedByteArray(),
		ModelStore.count_in(saved)))["text"]).replace("\r\n", "\n")
	_check("exported as .io, the same steps", _file_steps(carried) == expected)
	_world.clear()
	_store.open_text(carried, name)
	_check("opened again: the same timeline, step by step", _timeline() == timeline)


## A part moved a step later by the edit, then saved and reopened; undone.
func _authored_edit(source: String) -> void:
	print("  the author's steps, edited")
	_store.open_text(source, "gatehouse")
	var before: Array = _timeline()
	var yellow: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3003":
			yellow = brick.id
	var undo: Array = AuthorSteps.move(_world, [yellow], 1, "", _store.scenery)
	_builder.record(undo, "moved a part to the next step")
	var moved: Array = _timeline()
	_check("the yellow brick moved to the next step, with the blue one: %s"
		% " | ".join(moved.slice(1, 4)), moved.size() == before.size() - 1
		and str(moved[2]).begins_with("3: 3003/14 3005/1"))
	var saved: String = _store.to_text("gatehouse", true)
	var main: Array = (_file_steps(saved)["main"] as Array)
	_check("saved: the model's own steps are four, the yellow in the second with the blue (%s)"
		% " | ".join(main), main.size() == 4 and str(main[1]) == "3003/14 3005/1")
	_world.clear()
	_store.open_text(saved, "gatehouse")
	_check("opened again, it is still there", _timeline() == moved)
	_store.open_text(source, "gatehouse")
	_builder.record(AuthorSteps.move(_world, [_find("3003")], 1, "", _store.scenery), "moved")
	_check("one undo puts it back", _builder.undo() and _timeline() == before)


func _find(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.id
	return 0


func _stepped() -> String:
	var count: int = 0
	var all: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		all += 1
		count += 1 if brick.step >= 0 else 0
	return "%d of %d" % [count, all]


## The timeline in the author's steps: "number: parts" a step, a callout's
## "number name k/n: parts".
func _timeline() -> Array:
	var out: Array = []
	for step: Instructions.Step in Instructions.plan(_world, _library, _store.scenery, {}, true):
		var parts: Array = []
		for brick_id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			parts.append("%s/%d" % [brick.part_id, brick.color_code])
		parts.sort()
		var head: String = str(step.number)
		if step.in_callout():
			head += " %s %d/%d" % [step.assembly, step.callout_step, step.callout_steps]
		elif step.attaches():
			head += " %s on" % step.assembly
		out.append("%s: %s" % [head, " ".join(parts)])
	return out


## Every section of [param text] ("main", or a sub-model's title in lower
## case) -> its steps in order, each its parts and the sub-models it puts
## on, "part/colour" and "→name", sorted.
func _file_steps(text: String) -> Dictionary:
	var model: LdrModel = LdrModel.parse(text, "model")
	var out: Dictionary = {}
	for key: String in model.submodels:
		var sub: LdrModel.SubModel = model.submodels[key]
		var steps: Dictionary = {}
		for placement: LdrModel.Placement in sub.placements:
			var said: String = ("→" + LdrModel._key(placement.part_id)
				if model.submodels.has(LdrModel._key(placement.part_id))
				else "%s/%d" % [placement.part_id, placement.color_code])
			if not steps.has(placement.step):
				steps[placement.step] = []
			(steps[placement.step] as Array).append(said)
		var order: Array = steps.keys()
		order.sort()
		var listed: Array = []
		for at: int in order:
			var parts: Array = steps[at]
			parts.sort()
			listed.append(" ".join(parts))
		out["main" if sub == model.main else sub.title.to_lower()] = listed
	return out


func _shown_steps(steps: Dictionary) -> String:
	var said := PackedStringArray()
	for key: String in steps:
		said.append("%s %d" % [key, (steps[key] as Array).size()])
	return ", ".join(said)


# -- refused ------------------------------------------------------------------


func _refused() -> void:
	print("  refused, and said why")
	var good: PackedByteArray = FileAccess.get_file_as_bytes(BAY_2025)
	var cut: PackedByteArray = good.slice(0, good.size() / 2)
	var read: Dictionary = StudioIo.read(cut)
	_check("half an .io file: \"%s\"" % read["error"], str(read["error"]) == "that is not a Studio .io file"
		or str(read["error"]) == "that .io file is damaged")
	var spoilt: PackedByteArray = good.duplicate()
	for n: int in range(60, 120):
		spoilt[n] = spoilt[n] ^ 0x5A
	read = StudioIo.read(spoilt)
	_check("an .io file with its model spoilt: \"%s\"" % read["error"],
		str(read["error"]).begins_with("could not unpack the model from that .io file"))
	var picture := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	read = StudioIo.read(picture.save_png_to_buffer())
	_check("a picture called .io: \"%s\"" % read["error"],
		str(read["error"]) == "that is not a Studio .io file")
	read = StudioIo.read(StudioIo.zip([["notes.txt", "not a model".to_utf8_buffer()]]))
	_check("a zip with no model in it: \"%s\"" % read["error"],
		str(read["error"]) == "there is no model.ldr inside that .io file")
	# And through the picker, which is what a person sees: the status bar
	# says what the picker failed with.
	var picker := ModelFilePicker.new()
	get_root().add_child(picker)
	var said: Array = []
	picker.failed.connect(func(why: String) -> void: said.append(why))
	picker.picked.connect(func(_text: String, _name: String) -> void: said.append("opened"))
	picker.take(spoilt, "bay.io")
	picker.take(picture.save_png_to_buffer(), "holiday.io")
	_check("the picker says so instead of opening anything (%s)" % " / ".join(said),
		said.size() == 2 and not said.has("opened")
		and str(said[1]) == "that is not a Studio .io file")
	picker.queue_free()
	await process_frame


# -- helpers ------------------------------------------------------------------


func _said(read: Dictionary) -> String:
	return str(read["error"]) if not str(read["error"]).is_empty() else "no error"


## "part/colour" for each type-1 line of [param text], in order.
func _parts_in(text: String) -> Array:
	var out: Array = []
	for raw: String in text.split("\n"):
		var bits: PackedStringArray = raw.strip_edges().split(" ", false)
		if bits.size() >= 15 and bits[0] == "1":
			out.append("%s/%s" % [bits[14].get_basename().to_lower(), bits[1]])
	return out
