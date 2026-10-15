## A working model that cannot be opened at start-up is never written over.
##
##   godot --headless --path . --script src/dev/unrestored_probe.gd
##
## At start-up the app opens the working model (ModelStore.restore), and
## when none of it comes back it opens the sample car (Main). The car's
## autosave then wrote over the working model a few seconds later: a model
## none of whose parts are in this build's catalogue went for good, and
## nothing said so. Here start-up is played as Main plays it, restore and
## then the sample, against a working model of parts no catalogue has.
## The model must be kept as it was, somewhere the person can find it (File,
## Open), and the window must say so and say where. A model whose parts are
## still on their way (on the web, not fetched yet) must not be replaced by
## the car at all. And a model that opens, or one of no parts, is as before.
extends SceneTree

const NAME := "Unrestored Probe House"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var store: ModelStore = main.get("_store")
	var library: PartLibrary = main.get("_library")
	# A probe keeps no working model unless it turns that on (Main).
	store.keeps = true
	var autosave: String = ModelStore.autosave()
	_forget_kept()

	print("\na working model none of whose parts are in the catalogue")
	var theirs: String = "0 %s\n0 Name: %s.ldr\n0 Author: Brickworks\n" % [NAME, NAME] \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 nosuchpart1.dat\n" \
		+ "1 1 40 0 0 1 0 0 0 1 0 0 0 1 nosuchpart2.dat\n" \
		+ "1 14 0 -24 0 1 0 0 0 1 0 0 0 1 nosuchpart1.dat\n"
	_write(autosave, theirs)
	var placed: int = await _start_up(main, store)
	_check("start-up opens the sample in its place (%d parts, \"%s\")" % [placed, store.title],
		placed > 0 and store.example)
	var kept: String = _kept_copy(theirs)
	_check("the working model is kept, as it was, among the saved models: %s"
		% (kept if not kept.is_empty() else "nowhere"), not kept.is_empty())
	var listed: bool = false
	for entry: ModelStore.Entry in store.list_saved():
		listed = listed or entry.path == kept
	_check("...listed in File, Open", listed)
	# The car's autosave, as it writes a few seconds after a change.
	store.touch()
	store.write_now()
	_check("the sample's autosave has written (%d parts in it)" % _parts(autosave),
		_parts(autosave) > 0 and _parts(autosave) != 3)
	_check("...and the person's model is still there, word for word, after it",
		not _kept_copy(theirs).is_empty())
	var notice: Control = main.get("_restore_notice")
	var words: String = notice.call("words") if notice != null else ""
	_check("the window says so, above the model: \"%s\"" % words,
		notice != null and notice.is_visible_in_tree() and words.contains(NAME)
		and words.contains("nosuchpart1"))
	_check("...and where it is", not kept.is_empty()
		and words.contains("“%s”" % kept.get_file().get_basename()) and words.contains("File › Open"))
	if notice != null:
		notice.call("dismiss")
	_check("...until the person has read it", notice != null and not notice.visible)

	print("\nthe next start-up opens the car, and keeps nothing more")
	var copies: int = _copies()
	placed = await _start_up(main, store)
	_check("the car comes back as the working model (%d parts)" % placed, placed > 0)
	_check("...and no second copy is kept (%d)" % _copies(), _copies() == copies)
	_check("...and nothing is said", notice == null or not notice.visible)

	print("\na working model whose parts are still on their way")
	var info := PartLibrary.PartInfo.new()
	info.id = "unrestoredprobe"
	info.name = "Brick 2 x 4 not fetched yet"
	info.category = "Brick"
	info.mesh_hash = "0000unrestoredprobe"
	info.size = Vector3(80, 24, 40)
	info.bounds = AABB(Vector3(-40, 0, -20), Vector3(80, 24, 40))
	info.packed = false
	library.parts[info.id] = info
	var coming: String = "0 Unrestored Probe Kart\n0 Author: Brickworks\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 unrestoredprobe.dat\n" \
		+ "1 1 0 -24 0 1 0 0 0 1 0 0 0 1 unrestoredprobe.dat\n"
	_write(autosave, coming)
	copies = _copies()
	placed = await _start_up(main, store)
	_check("start-up waits for it rather than putting the car out (%d to come, \"%s\")"
		% [store.awaited.size(), store.title], store.awaited.size() == 2 and not store.example
		and store.title == "Unrestored Probe Kart")
	store.touch()
	store.write_now()
	_check("...and its file is untouched while they come",
		FileAccess.get_file_as_string(autosave) == coming)
	_check("...nothing kept, and nothing said", _copies() == copies
		and (notice == null or not notice.visible))
	library.parts.erase(info.id)

	print("\na working model of no parts")
	_write(autosave, "0 Nothing Yet\n0 Author: Brickworks\n")
	placed = await _start_up(main, store)
	_check("the sample comes out, as on a first visit (%d parts)" % placed, placed > 0 and store.example)
	_check("...nothing kept, and nothing said", _copies() == copies
		and (notice == null or not notice.visible))

	print("\na working model that opens")
	_write(autosave, FileAccess.get_file_as_string("res://models/house.ldr"))
	placed = await _start_up(main, store)
	_check("it comes back (%d parts)" % placed, placed > 0 and not store.example)
	_check("...nothing kept, and nothing said", _copies() == copies
		and (notice == null or not notice.visible))

	_forget_kept()
	_done()


## What Main does at start-up with no --model: the working model, and the
## sample when none of it comes back.
func _start_up(main: Node, store: ModelStore) -> int:
	var placed: int = store.restore()
	if placed == 0:
		placed = main.call("_open", main.get_script().get_script_constant_map()["SAMPLE_MODEL"])
	for _n: int in 5:
		await process_frame
	return placed


## The saved model whose text is [param text], or "".
func _kept_copy(text: String) -> String:
	for file_name: String in DirAccess.get_files_at(ModelStore.SAVE_DIR):
		var path: String = ModelStore.SAVE_DIR + file_name
		if file_name.ends_with(".ldr") and FileAccess.get_file_as_string(path) == text:
			return path
	return ""


## How many saved models are named for this probe's.
func _copies() -> int:
	var count: int = 0
	for file_name: String in DirAccess.get_files_at(ModelStore.SAVE_DIR):
		if file_name.begins_with(NAME):
			count += 1
	return count


func _forget_kept() -> void:
	for file_name: String in DirAccess.get_files_at(ModelStore.SAVE_DIR):
		if file_name.begins_with(NAME):
			DirAccess.remove_absolute(ModelStore.SAVE_DIR + file_name)
	if DirAccess.dir_exists_absolute(ModelVersions.ROOT):
		for folder: String in DirAccess.get_directories_at(ModelVersions.ROOT):
			if folder.begins_with(NAME):
				for file_name: String in DirAccess.get_files_at(ModelVersions.folder(folder)):
					DirAccess.remove_absolute(ModelVersions.folder(folder) + file_name)
				DirAccess.remove_absolute(ModelVersions.folder(folder))


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _parts(path: String) -> int:
	return ModelStore.count_in(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else -1


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("a working model that cannot be opened is kept, and said to be")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
