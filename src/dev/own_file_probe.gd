## Save writes only into the saved model the working model is.
##
##   godot --headless --path . --script src/dev/own_file_probe.gd
##
## The working model knew its file by its name alone. A model called as a
## saved model is, that was never opened from it nor saved to it, wrote
## itself over that model on Save, and nothing asked: a link's copy brought
## back by a reload under the link's name went over the person's own model
## of that name (viewreview F1, 2026-11-24). Now the store keeps which saved
## model it is (ModelStore._known_path), carries it across a reload beside
## the autosave (ModelStore.OWN_FILE), and Save over any other asks
## (ModelBar.ask_name_taken).
##
## Here, with two stores standing for two tabs and then the app itself:
## every path that names, opens, copies, restores or renames a working model
## either Saves into its own file or is refused with the other model's parts
## left as they were; a save that changes the name writes the autosave again
## (the root of F1); a link none of whose parts can be shown is kept in the
## person's models as shared, and said (F2); the bar asks, and both of its
## answers do what they say.
extends SceneTree

const OWN := "Own File Probe"
const OTHER := "Own File Probe Other"

var _failures: int = 0
var _library: PartLibrary
var _save_result: Variant = null


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_clean()
	await _stores()
	await _app()
	_clean()
	if _failures == 0:
		print("\nevery save went into its own file, or asked")
	else:
		print("\n%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _stores() -> void:
	var own: String = ModelStore.saved_path(OWN)
	print("a saved model of the person's own, two parts")
	var a: ModelStore = _side()
	_brick(a, Vector3(0, 24, 0))
	_brick(a, Vector3(40, 24, 0))
	a.title = OWN
	_ok(a.save_as(OWN) and ModelStore._count_bricks(own) == 2, "saved as %s, 2 parts" % OWN)
	_ok(a.is_own_file(own), "...and it is that file")

	print("\na link's copy called as that model is (F1)")
	var b: ModelStore = _side()
	var link_text: String = _text(OWN, 3)
	_ok(str(b.open_text(link_text, "link.ldr")["error"]).is_empty() and b.title == OWN,
		"the copy opens, called %s" % b.title)
	_ok(not b.is_own_file(own), "...and is not the saved model of its name")
	_ok(not b.saved_elsewhere() and not b.is_own_file(own),
		"...nor taken for it by the watch for saves elsewhere")
	_ok(not b.save_as(OWN) and b.taken == OWN and ModelStore._count_bricks(own) == 2,
		"Save under that name is refused, asking (taken %s), the person's 2 parts kept" % b.taken)
	b.listen()
	b.touch()
	b.write_now()
	_ok(_said_title(ModelStore.autosave()) == OWN and _own_file()["file"] == "",
		"its autosave is called %s and is no saved model" % OWN)
	var kept: String = b.unused_name(OWN)
	_ok(b.save_as(kept) and ModelStore._count_bricks(own) == 2,
		"the copy is saved as %s, the person's model untouched" % kept)
	_ok(not b.written(), "...and the autosave is to be written again under that name (the root)")
	b.write_soon()
	b.tick()
	_ok(b.written() and _said_title(ModelStore.autosave()) == kept
		and _own_file()["file"] == ModelStore.saved_path(kept).get_file(),
		"...written at the next frame as %s, the file it is beside it: %s" % [kept, _own_file()])

	print("\nthe tab reloaded")
	var c: ModelStore = _side()
	_ok(c.restore() == 3 and c.title == kept and c.is_own_file(ModelStore.saved_path(kept)),
		"the copy comes back as %s, its own file" % c.title)
	_brick(c, Vector3(80, 24, 0))
	_ok(c.save_as(c.title) and ModelStore._count_bricks(ModelStore.saved_path(kept)) == 4
		and ModelStore._count_bricks(own) == 2, "Save writes the copy; the person's model keeps 2")

	print("\nan autosave under the link's name, the copy saved after it (no root fix)")
	var d: ModelStore = _side()
	d.open_text(link_text, "link.ldr")
	d.listen()
	d.touch()
	d.write_now()
	var e: ModelStore = _side()
	_ok(e.restore() == 3 and e.title == OWN and not e.is_own_file(own),
		"it comes back as %s, no saved model" % OWN)
	_ok(not e.save_as(OWN) and e.taken == OWN and ModelStore._count_bricks(own) == 2,
		"...and Save asks, the person's 2 parts kept")

	print("\nan autosave from before the file was kept beside it")
	DirAccess.remove_absolute(TabSession.path(ModelStore.OWN_FILE))
	var f: ModelStore = _side()
	_ok(f.restore() == 3 and f.is_own_file(own), "it is the saved model of its name, as before")
	print("...and one beside it written under another name")
	_write(TabSession.path(ModelStore.OWN_FILE), JSON.stringify({"title": "Another", "file": OWN + ".ldr"}))
	var g: ModelStore = _side()
	_ok(g.restore() == 3 and not g.is_own_file(own), "it is no saved model: Save asks")
	_write(TabSession.path(ModelStore.OWN_FILE), JSON.stringify({"title": OWN, "file": "../../x.ldr"}))
	var g2: ModelStore = _side()
	_ok(g2.restore() == 3 and not g2.is_own_file(own) and g2._known_path.is_empty(),
		"a file named out of the models' folder is not taken")

	print("\nopen, new, clear and its undo, an undone open, a version")
	var h: ModelStore = _side()
	_ok(h.open(own) == 2 and h.is_own_file(own), "opened from %s, it is that file" % OWN)
	var was: Dictionary = h.identity()
	h.begin(ModelStore.UNTITLED)
	_ok(not h.is_own_file(own), "begun anew (New, Clear), it is no saved model")
	h.put_identity(was)
	_ok(h.is_own_file(own), "the clear undone, it is the saved model again")
	h.open_text(_text(OTHER, 1), "other.ldr")
	_ok(not h.is_own_file(own) and h.can_reopen(), "a file opened over it is no saved model")
	var reopened: int = await h.reopen()
	_ok(reopened == 2 and h.title == OWN and h.is_own_file(own),
		"the open undone, the saved model is back, and is its file")
	var versions: Array[ModelVersions.Version] = h.versions()
	h.open_text(_text(OTHER, 1), "other.ldr")
	var from_version: int = await h.open_version(versions[0].path, OWN) if not versions.is_empty() else 0
	_ok(from_version > 0 and h.is_own_file(own),
		"a save of it opened from its versions Saves into its file")

	print("\na name typed in the field, a saved model's")
	var i: ModelStore = _side()
	_brick(i, Vector3(0, 24, 40))
	i.title = OTHER
	_ok(i.save_as(OTHER) and i.is_own_file(ModelStore.saved_path(OTHER)), "saved as %s" % OTHER)
	i.title = OWN
	i.touch()
	_ok(not i.save_as(OWN) and i.taken == OWN and ModelStore._count_bricks(own) == 2,
		"renamed %s in its field, Save asks and the other keeps its parts" % OWN)
	_ok(i.save_as(OWN, true) and ModelStore._count_bricks(own) == 1 and i.is_own_file(own),
		"...and replaces it when the person says so")
	# Kept as theirs (the reload offer's Keep mine), and saved back.
	a.know(own)
	_ok(a.save_as(OWN) and ModelStore._count_bricks(own) == 2, "(the person's own put back)")

	print("\na link none of whose parts can be shown, kept as shared (F2)")
	var unshown: String = "0 Own File Probe Unshown\n0 Name: unshown.ldr\n\n" \
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 zzownprobe1.dat\n1 1 40 0 0 1 0 0 0 1 0 0 0 1 zzownprobe2.dat\n"
	var j: ModelStore = _side()
	j.open(own)
	var result: Dictionary = j.open_text(unshown, "unshown.ldr")
	_ok(not str(result["error"]).is_empty() and not (result.get("missing_ids", {}) as Dictionary).is_empty(),
		"it does not open: %s" % result["error"])
	var copy: String = j.keep_unopened_copy(unshown, "Own File Probe Unshown", "AbCdEfGhIj", 2,
		{"by": "someone"})
	var copy_text: String = FileAccess.get_file_as_string(ModelStore.saved_path(copy))
	_ok(copy == "Own File Probe Unshown" and copy_text.contains("zzownprobe1.dat")
		and copy_text.contains("zzownprobe2.dat") and copy_text.contains(ModelStore.REMIX_META + "AbCdEfGhIj"),
		"kept in the models as %s, both parts and the link it came from" % copy)
	_ok(j.title == OWN and j.is_own_file(own), "...the model on the baseplate still its own file")
	var again: String = j.keep_unopened_copy(unshown, "Own File Probe Unshown", "AbCdEfGhIj", 2, {})
	var again_title: String = ModelStore.title_in(FileAccess.get_file_as_string(
		ModelStore.SAVE_DIR + again + ".ldr"), "")
	_ok(not again.is_empty() and again != copy and again_title == "Own File Probe Unshown (copy)",
		"kept again, as %s, called %s in its file" % [again, again_title])
	DirAccess.remove_absolute(ModelStore.SAVE_DIR + copy + ".ldr")
	DirAccess.remove_absolute(ModelStore.SAVE_DIR + again + ".ldr")


## The app: the bar asks, its answers do what they say; a rename elsewhere of
## a saved model the working model only shares a name with leaves it alone.
func _app() -> void:
	print("\nthe app's Save")
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var store: ModelStore = main.get("_store")
	var bar: ModelBar = main.get("_bar")
	var own: String = ModelStore.saved_path(OWN)
	store.keeps = true
	var result: Dictionary = await store.open_text_fetched(_text(OWN, 3), "link.ldr")
	_ok(str(result["error"]).is_empty() and store.title == OWN and not store.is_own_file(own),
		"a link's copy is on the baseplate, called %s, no saved model" % OWN)
	bar._name.text = OWN
	_press_save(bar)
	var asked: bool = await _until(func() -> bool: return bar._ask_name.visible)
	_ok(asked and bar._replace_button.visible and bar.controls_by_name().has("save_name_replace")
		and bar._ask_name_words.text.contains("is a saved model already"),
		"Save asks: %s" % bar._ask_name_words.text)
	var offered: String = bar._ask_name_field.text
	_ok(offered == store.unused_name(OWN), "...offering %s" % offered)
	bar._take_name()
	await _until(func() -> bool: return _save_result != null)
	_ok(_save_result == true and store.title == offered and store.is_own_file(ModelStore.saved_path(offered))
		and ModelStore._count_bricks(own) == 2,
		"its offered name taken, saved as %s; %s keeps its 2 parts" % [store.title, OWN])

	print("\n...and Replace it")
	bar._name.text = OWN
	bar._name.text_changed.emit(OWN)
	_press_save(bar)
	asked = await _until(func() -> bool: return bar._ask_name.visible)
	_ok(asked, "Save asks again")
	bar._ask_name.custom_action.emit(&"replace")
	await _until(func() -> bool: return _save_result != null)
	_ok(_save_result == true and store.is_own_file(own) and ModelStore._count_bricks(own) == 3
		and not bar._ask_name.visible, "Replace it writes over %s, which it is now" % OWN)
	_press_save(bar)
	await _until(func() -> bool: return _save_result != null or bar._ask_name.visible)
	_ok(_save_result == true and not bar._ask_name.visible, "...and the next Save asks nothing")

	print("\na rename elsewhere of a model it only shares a name with")
	await store.open_text_fetched(_text(OWN, 1), "link.ldr")
	main.call("_called_now", OWN, OWN + " Renamed")
	_ok(store.title == OWN and not store.is_own_file(ModelStore.saved_path(OWN + " Renamed")),
		"the working model keeps its name, and is not the renamed file")

	print("\na link none of whose parts can be shown (F2)")
	var unshown: String = "0 Own File Probe Link\n\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 zzownprobe1.dat\n"
	var opened: Dictionary = await store.open_text_fetched(unshown, "Own File Probe Link")
	main.set("_copying", "AbCdEfGhIj")
	main.call("_not_copied", {"model": unshown, "version": 1, "name": "Own File Probe Link"},
		"Own File Probe Link", opened)
	var notice: RestoreNotice = main.get("_restore_notice")
	var kept: String = ModelStore.saved_path("Own File Probe Link")
	_ok(notice.visible and notice._words.text.contains("kept as it was shared")
		and FileAccess.get_file_as_string(kept).contains("zzownprobe1.dat") and store.title == OWN,
		"kept and said above the model: %s" % notice._words.text)
	DirAccess.remove_absolute(kept)
	main.set("_copying", "")
	store.keeps = false
	main.queue_free()
	await process_frame


func _press_save(bar: ModelBar) -> void:
	_save_result = null
	_save_result = await bar._on_save()


func _until(test: Callable, frames: int = 600) -> bool:
	for _n: int in frames:
		if test.call():
			return true
		await process_frame
	return test.call()


## A store with a world of its own, as each tab has.
func _side() -> ModelStore:
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	return store


static func _brick(store: ModelStore, at: Vector3) -> void:
	var id: int = store.world.add_brick("3001", 4, Transform3D(Basis(), at))
	if id != 0:
		store.builder.register(id, "3001", Transform3D(Basis(), at))


## A model called [param name] of [param parts] bricks in a row, as a file.
static func _text(name: String, parts: int) -> String:
	var lines := PackedStringArray(["0 %s" % name, "0 Name: %s.ldr" % name.to_snake_case(), ""])
	for n: int in parts:
		lines.append("1 4 %d -24 0 1 0 0 0 1 0 0 0 1 3001.dat" % (n * 40))
	return "\n".join(lines) + "\n"


static func _said_title(path: String) -> String:
	return ModelStore.title_in(FileAccess.get_file_as_string(path), "")


static func _own_file() -> Dictionary:
	var reading := JSON.new()
	var path: String = TabSession.path(ModelStore.OWN_FILE)
	if not FileAccess.file_exists(path) or reading.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"file": "(none)"}
	return reading.data


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean() -> void:
	for name: String in [OWN, OTHER, OWN + " (copy)", OWN + " (copy 2)", OWN + " Renamed",
			"Own File Probe Unshown", "Own File Probe Unshown (copy)", "Own File Probe Link"]:
		DirAccess.remove_absolute(ModelStore.saved_path(name))
		var versions: String = ModelVersions.folder(name)
		if DirAccess.dir_exists_absolute(versions):
			for file: String in DirAccess.get_files_at(versions):
				DirAccess.remove_absolute(versions.path_join(file))
	DirAccess.remove_absolute(ModelStore.autosave())
	DirAccess.remove_absolute(TabSession.path(ModelStore.OWN_FILE))


func _ok(condition: bool, detail: String) -> void:
	if condition:
		print("  ok %s" % detail)
	else:
		_failures += 1
		print("  XX %s" % detail)
