## The model library, opened as the app will open it: its index and a few of
## its models fetched from where the store serves them, each opened with the
## app's own reader (ModelStore.open_text_fetched), its lots counted as
## "What can I build?" counts them (src/dev/collection_models.gd), which must
## be what models.json says, and its part count as its card says it
## (Inventory.count_of_text), which must be models.json's "c" and the index's.
##
##   godot --headless --path . --script src/dev/library_open_probe.gd -- --base=URL [ID ...]
##   godot --headless --path . --script src/dev/library_open_probe.gd -- --recount [--recount-out=FILE]
##
## With --recount, every model in vendor/omr is counted again as
## collection_models.gd counts it, its lots and its part count, and held to
## models.json, nothing opened:
## a model whose count moved since models.json was written is said (and
## written to FILE as JSON), and the fix is to run collection_models.gd again,
## then tools/library_build.py stage.
##
## URL is the store's root as the app has it (PARTS_URL): library/index.json
## is under it. A staged library served on a local port does
## (python3 -m http.server --directory bench/results/library-2026-10-26).
## Without IDs, three: a small model, a set's alternate build and the largest.
extends SceneTree

var _failures: int = 0
var _http: HTTPRequest


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _fetch(url: String) -> PackedByteArray:
	if _http.request(url) != OK:
		return PackedByteArray()
	var result: Array = await _http.request_completed
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		print("  %s: result %d, HTTP %d" % [url, int(result[0]), int(result[1])])
		return PackedByteArray()
	return result[3]


func _run() -> void:
	await process_frame
	var base: String = ""
	var ids: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--base="):
			base = a.substr(7)
		elif not a.begins_with("--"):
			ids.append(a)
	if OS.get_cmdline_user_args().has("--recount"):
		await _recount()
		return
	if base.is_empty():
		print("library_open_probe: give --base=URL, the store's root")
		quit(2)
		return
	if not base.ends_with("/"):
		base += "/"
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	_http.download_chunk_size = 1 << 20
	root.add_child(_http)
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("library_open_probe: no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	world.keeps_history = false
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame

	var said: Variant = JSON.parse_string((await _fetch(base + "library/index.json")).get_string_from_utf8())
	_check("the index arrives and reads as {version 1, models}", said is Dictionary
		and int((said as Dictionary).get("version", 0)) == 1)
	if not said is Dictionary:
		quit(1)
		return
	var models: Array = (said as Dictionary).get("models", [])
	print("  %d models in %slibrary/index.json" % [models.size(), base])
	var counted: Dictionary = {}
	var cards: Dictionary = {}
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SetInventories.ROOT + "models.json"))
	for entry: Variant in (listed as Dictionary).get("models", []):
		var total: int = 0
		for row: Variant in (entry as Dictionary).get("p", []):
			total += int((row as Array)[2])
		counted[str((entry as Dictionary).get("file", ""))] = total
		cards[str((entry as Dictionary).get("file", ""))] = int((entry as Dictionary).get("c", -1))
	var chosen: Array = []
	if ids.is_empty():
		var by_size: Array = models.duplicate()
		by_size.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["parts"]) < int(b["parts"]))
		chosen = [by_size[by_size.size() / 10]]
		for m: Dictionary in models:
			if m["alternate_of"] != null and int(m["parts"]) > 300:
				chosen.append(m)
				break
		chosen.append(by_size[-1])
	else:
		for m: Dictionary in models:
			if ids.has(str(m["id"])):
				chosen.append(m)
	var counter: GDScript = load("res://src/dev/collection_models.gd")
	# Each counted before any is opened: opening a file adds the parts it
	# carries to the library (CustomParts.take_from), and counting after that
	# counts parts models.json, made with none opened, did not (the Colosseum
	# after it opened: 9,028 against 8,968).
	var fetched: Array = []
	var totals: Array = []
	for m: Dictionary in chosen:
		var got: PackedByteArray = await _fetch(base + str(m["file"]))
		fetched.append(got)
		totals.append(_counted(got.get_string_from_utf8(), str(m["set"]), library, counter))
	# And each one's part count, which its card says: after every list, as
	# collection_models.gd counts them.
	var keeps: bool = CustomParts.keeps
	CustomParts.keeps = false
	var pieces: Array = []
	for got: PackedByteArray in fetched:
		pieces.append(Inventory.count_of_text(got.get_string_from_utf8(), library))
	CustomParts.keeps = keeps
	for n: int in chosen.size():
		var m: Dictionary = chosen[n]
		print("%s (%s, %s): %d parts in the index" % [m["id"], m["set"], m["name"], int(m["parts"])])
		var bytes: PackedByteArray = fetched[n]
		var text: String = bytes.get_string_from_utf8()
		# The file it was staged from: the id is "omr-" and its name, as a
		# store path can carry it (tools/library_build.py safe_stem).
		var vendor: String = "res://vendor/omr/files/"
		var unsafe: RegEx = RegEx.create_from_string("[^A-Za-z0-9._-]")
		var original: String = ""
		for file_name: String in DirAccess.get_files_at(vendor):
			if "omr-" + unsafe.sub(file_name.get_basename(), "", true) == str(m["id"]):
				original = file_name
		_check("%s arrives, %d bytes, the very file LDraw has (%s)" % [m["file"], bytes.size(), original],
			not original.is_empty() and bytes == FileAccess.get_file_as_bytes(vendor + original))
		_check("its licence line is kept: %s" % m["licence"], text.contains("0 !LICENSE"))
		var began: int = Time.get_ticks_msec()
		var opened: Dictionary = await store.open_text_fetched(text, str(m["name"]))
		# Placed counts what the file draws, stickers and primitives too; a part
		# the catalogue has not got is the file's, and is said, as the app says it.
		var missing: Dictionary = opened.get("missing_ids", {})
		_check("it opens with the app's reader: %d parts placed in %d ms%s" % [
			int(opened.get("placed", 0)), Time.get_ticks_msec() - began,
			"" if missing.is_empty() else ", and %d it names that no library has (%s)"
			% [missing.size(), ModelStore.named_counts(missing)]],
			int(opened.get("placed", 0)) > 0 and world.brick_count() == int(opened.get("placed", 0)))
		var total: int = totals[n]
		_check("its lots counted as What can I build? counts them: %d, models.json %d" % [
			total, int(counted.get(original, -1))], total == int(counted.get(original, -1)))
		var count: int = pieces[n]
		_check("its part count as its card says it: %d, models.json %d, the index %d" % [
			count, int(cards.get(original, -1)), int(m["parts"])],
			count == int(cards.get(original, -1)) and count == int(m["parts"]))
		var cover := Image.new()
		var picture: PackedByteArray = await _fetch(base + str(m["cover"]))
		var read: bool = cover.load_webp_from_buffer(picture) == OK
		_check("its cover arrives as a %dx%d WebP" % [cover.get_width(), cover.get_height()],
			read and cover.get_size() == Vector2i(512, 384))
	print("library_open_probe: %d models, %d failures" % [chosen.size(), _failures])
	quit(0 if _failures == 0 and chosen.size() >= 1 else 1)


## A file's parts as models.json counts them: its ownable parts, matched to
## its set (collection_models.gd's listed, from text rather than a path).
static func _counted(text: String, number: String, library: PartLibrary, counter: GDScript) -> int:
	var needs: Dictionary = Collection.needs_of_ldraw(text, library)
	var held: Dictionary = counter._held(number.to_lower(), library)
	if not needs.is_empty() and not held.is_empty():
		needs = Collection.as_its_set(needs, held, Callable(counter, "drawn_with"), library)
	var total: int = 0
	for key: String in needs:
		total += int(needs[key])
	return total


## Every model counted again, its lots and its part count, and held to models.json.
func _recount() -> void:
	var out: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--recount-out="):
			out = a.substr(14)
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("library_open_probe: no catalogue")
		quit(1)
		return
	var counter: GDScript = load("res://src/dev/collection_models.gd")
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SetInventories.ROOT + "models.json"))
	var models: Array = (listed as Dictionary).get("models", [])
	var moved: Array = []
	var began: int = Time.get_ticks_msec()
	for model: Dictionary in models:
		var file_name: String = str(model["file"])
		var was: int = 0
		for row: Variant in model.get("p", []):
			was += int((row as Array)[2])
		var needs: Dictionary = counter.listed(file_name, str(model["set"]), library)
		var now: int = 0
		for key: String in needs:
			now += int(needs[key])
		if now != was:
			moved.append({"file": file_name, "of": "lots", "models_json": was, "now": now})
	# And each one's part count, which its card says: after every list, as
	# collection_models.gd counts them.
	CustomParts.keeps = false
	for model: Dictionary in models:
		var file_name: String = str(model["file"])
		var now: int = Inventory.count_of_text(
			FileAccess.get_file_as_string("res://vendor/omr/files/" + file_name), library)
		if now != int(model.get("c", -1)):
			moved.append({"file": file_name, "of": "count", "models_json": int(model.get("c", -1)), "now": now})
	var files: Dictionary = {}
	for one: Dictionary in moved:
		files[one["file"]] = true
	print("library_open_probe: %d of %d models count as models.json says, %d moved, in %d s" % [
		models.size() - files.size(), models.size(), files.size(), (Time.get_ticks_msec() - began) / 1000])
	for one: Dictionary in moved.slice(0, 20):
		print("  %s, its %s: models.json %d, now %d" % [one["file"], one["of"], one["models_json"], one["now"]])
	if not out.is_empty():
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(moved, " "))
		file.close()
	quit(0)
