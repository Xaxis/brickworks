## The library in the real app, in a window: any of LDraw's models of real
## sets, or a model the community shared, opened in a window of its own.
##
##   godot --path . --resolution 1400x900 --script src/dev/library_probe.gd
##
## The owner asked for exactly this: within the app, open a model from a
## library of every model there is. A stand-in store and gallery
## (tools/web/serve.py --library tests/fixtures/library, on port 8936) play
## the parts store's library/ (eight sets, their covers, the files from
## vendor/omr/files) and three gallery models, one of them all rights
## reserved; BRICKWORKS_API points this app and the windows it starts at it.
##
##   1. File, Open lists "From the library…" beside the file picker, and the
##      File menu has Library… after Open. Either opens the screen on the
##      LDraw sets: all eight, with covers.
##   2. A search by name ("dragon"), by set number ("106-1"); the theme,
##      decade and size filters, alone and together; the sorts. The pages.
##   3. Open on 106-1 starts the app again (a process of its own, with
##      --library=omr-106-1 and --new-session): its working model is the set,
##      57 parts, credited to its LDraw author under CCAL 2.0 with its page.
##   4. Community: the three stand-in models; a search and the kind filter.
##      Open on the all rights reserved bench starts another (--copy=): the
##      bench is copied into the person's models, as Open in Brickworks on
##      its page does, saying where it came from and whose it is.
##   5. This window's model is as it was: its name, its parts, no credit.
##   6. Opened here instead (?library= as Main reads it), a set's credit is
##      in Properties with nothing selected, with its LDraw page; a library id
##      the store has not got, and no connection at all, are each said.
##
## Real processes in this run's data folder (tools/probe.sh gives one),
## stopped by their ids at the end, with the stand-in server. Not in the
## suite: it starts two more copies of the app, each ~20 s to come up.
##
## Pictures: shots/library_sets.png, library_filtered.png,
## library_community.png, library_credit.png. Look at them.
extends SceneTree

const PORT := 8936
## How long a copy of the app has to come up and open what it was given.
const PATIENCE_S := 240.0

var _failures: int = 0
var _main: Node
var _server: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var fixture: String = ProjectSettings.globalize_path("res://tests/fixtures/library")
	_server = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/web/serve.py"),
		fixture, str(PORT), "--library", fixture, "--omr",
		ProjectSettings.globalize_path("res://vendor/omr/files")])
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:%d" % PORT)
	await create_timer(1.5).timeout
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var shell: Shell = _main.get("_shell")
	var bar: ModelBar = _main.get("_bar")
	var store: ModelStore = _main.get("_store")
	var world: BrickWorld = _main.get("_world")
	var dialog: LibraryDialog = shell.library_dialog
	var title: String = store.title
	var bricks: int = world.brick_count()
	_check("this window has a model: %s, %d parts" % [title, bricks], bricks > 0)

	print("\nreaching it")
	bar._on_open()
	var popup: PopupMenu = bar.get("_saves")
	var row: int = popup.get_item_index(ModelBar.LIBRARY)
	_check("File, Open lists \"%s\", beside the file picker"
		% (popup.get_item_text(row) if row >= 0 else ""),
		row == popup.get_item_index(ModelBar.IMPORT) + 1)
	popup.hide()
	var file: PopupMenu = shell.menu("File").get_popup()
	var at: int = file.get_item_index(shell.menu_id("library"))
	_check("the File menu has \"%s\" after Open" % (file.get_item_text(at) if at >= 0 else ""),
		at == file.get_item_index(shell.menu_id("open")) + 1 and file.get_item_text(at) == "Library…")
	popup.id_pressed.emit(ModelBar.LIBRARY)
	_check("From the library… opens the screen", dialog.visible)
	await _until(func() -> bool: return int(dialog.last.get("total", 0)) > 0, 30.0)
	_check("on the LDraw sets, all eight: %s" % str(dialog.last.get("shown", [])),
		dialog.last.get("source") == "sets" and int(dialog.last["total"]) == 8)
	await _until(func() -> bool: return _covers(dialog) == 8, 30.0)
	_check("...each with its cover: %d" % _covers(dialog), _covers(dialog) == 8)
	_check("...newest first: %s" % str(dialog.last["shown"]).left(80),
		(dialog.last["shown"] as Array)[0] == "omr-10179-1")
	await _shot("library_sets")

	print("\nsearching and filtering the sets")
	var search: LineEdit = dialog.get("_search")
	await _search(dialog, "dragon")
	_check("\"dragon\" finds the Dragon Wagon: %s" % str(dialog.last["shown"]),
		dialog.last["shown"] == ["omr-6056-1"])
	await _search(dialog, "106-1")
	_check("\"106-1\" finds the set by number: %s" % str(dialog.last["shown"]),
		dialog.last["shown"] == ["omr-106-1"])
	await _search(dialog, "")
	await _choose(dialog, "_theme", "Town")
	_check("Town: %s" % str(dialog.last["shown"]),
		_same(dialog.last["shown"], ["omr-6516-1", "omr-1484-1", "omr-106-1"]))
	await _choose(dialog, "_decade", "1980s")
	_check("Town in the 1980s: %s" % str(dialog.last["shown"]),
		_same(dialog.last["shown"], ["omr-1484-1", "omr-106-1"]))
	await _choose(dialog, "_size", "small")
	_check("...small: %s" % str(dialog.last["shown"]), _same(dialog.last["shown"], ["omr-106-1"]))
	await _choose(dialog, "_theme", "")
	await _choose(dialog, "_decade", "")
	await _choose(dialog, "_size", "large")
	await _choose(dialog, "_sort", "largest")
	_check("large, most parts first: %s" % str(dialog.last["shown"]),
		dialog.last["shown"] == ["omr-10179-1"])
	await _choose(dialog, "_size", "")
	await _choose(dialog, "_sort", "smallest")
	_check("fewest parts first: %s" % str(dialog.last["shown"]).left(60),
		(dialog.last["shown"] as Array)[0] == "omr-6516-1")
	_check("one page of eight: Next is off", (dialog.get("_next") as Button).disabled)
	await _choose(dialog, "_theme", "Castle")
	await _shot("library_filtered")
	await _choose(dialog, "_theme", "")

	print("\nopening a set")
	await _search(dialog, "106-1")
	var before: Dictionary = _sessions()
	(dialog.controls_by_name()["library_open_first"] as Button).pressed.emit()
	_check("it says so: %s" % dialog.get("_status").text,
		str(dialog.get("_status").text).begins_with("Opening 106-1 UNICEF Van in a new window"))
	var made: Dictionary = await _held_anew(before, func(text: String) -> bool:
		return ModelStore.count_in(text) >= 57 and text.contains(ModelStore.CREDIT_META))
	var set_pid: int = int(made.get("pid", 0))
	_check("a window of its own opened it: session %s by %d" % [made.get("id", ""), set_pid],
		set_pid > 0 and set_pid != OS.get_process_id())
	var argv: PackedStringArray = _cmdline(set_pid)
	_check("...started with --library=omr-106-1 and --new-session",
		argv.has("--library=omr-106-1") and argv.has(TabSession.NEW_WINDOW))
	var kept: String = str(made.get("text", ""))
	_check("...its working model is the set, %d parts" % ModelStore.count_in(kept),
		ModelStore.count_in(kept) == 57)
	var credit: Dictionary = ModelStore.credit_in(kept)
	_check("...credited: %s" % ModelBar.credit_words(credit),
		credit.get("by") == "Michael Heidemann" and credit.get("licence") == "CCAL 2.0"
		and credit.get("page") == "https://library.ldraw.org/omr/sets/561")

	print("\nthe community")
	(dialog.controls_by_name()["library_tab_community"] as Button).pressed.emit()
	await _until(func() -> bool: return dialog.last.get("source") == "community", 30.0)
	_check("three models shared in the gallery: %s" % str(dialog.last["shown"]),
		int(dialog.last["total"]) == 3)
	await _until(func() -> bool: return _covers(dialog) == 3, 30.0)
	_check("...each with its picture: %d" % _covers(dialog), _covers(dialog) == 3)
	await _shot("library_community")
	await _choose(dialog, "_kind", "vehicle")
	_check("Vehicles: %s" % str(dialog.last["shown"]), dialog.last["shown"] == ["LibStubKrt"])
	await _choose(dialog, "_kind", "")
	await _search(dialog, "bench")
	_check("\"bench\": %s" % str(dialog.last["shown"]), dialog.last["shown"] == ["LibStubBch"])
	before = _sessions()
	(dialog.controls_by_name()["library_open_first"] as Button).pressed.emit()
	made = await _held_anew(before, func(text: String) -> bool:
		return text.contains(ModelStore.REMIX_META + "LibStubBch"))
	var copy_pid: int = int(made.get("pid", 0))
	_check("a window of its own copied it: session %s by %d" % [made.get("id", ""), copy_pid],
		copy_pid > 0 and copy_pid != set_pid)
	_check("...started with --copy=LibStubBch", _cmdline(copy_pid).has("--copy=LibStubBch"))
	kept = str(made.get("text", ""))
	credit = ModelStore.credit_in(kept)
	_check("...the bench, %d parts, remixed from its link, credited: %s"
		% [ModelStore.count_in(kept), ModelBar.credit_words(credit)],
		ModelStore.count_in(kept) == 43 and credit.get("by") == "Cleo Plates"
		and credit.get("licence") == "All rights reserved")
	var saved: bool = await _until(func() -> bool:
		return FileAccess.file_exists(ModelStore.SAVE_DIR + "Stub Park Bench.ldr"), 60.0)
	_check("...and saved in the person's models, as Open in Brickworks does", saved)

	print("\nthis window")
	_check("its model is as it was: %s, %d parts, no credit" % [store.title, world.brick_count()],
		store.title == title and world.brick_count() == bricks and store.credit.is_empty())
	dialog.close()

	print("\nopened here, the credit in Properties")
	_main.set("_from_library", "omr-6516-1")
	await _main.call("_maybe_open_library")
	await _frames(30)
	_check("Moon Walker opened here: %s, %d parts" % [store.title, world.brick_count()],
		store.title == "6516-1 Moon Walker" and world.brick_count() - store.scenery.size() == 42)
	_check("the status bar says whose: %s" % bar.status_text(),
		bar.status_text() == "opened 6516-1 Moon Walker — LDraw model by Chris Böhnke, CC BY 4.0")
	var builder: Builder = _main.get("_builder")
	builder.selection.clear()
	await _frames(20)
	var words: Label = shell.inspector.get("_credit_words")
	var link: LinkButton = shell.inspector.get("_credit_link")
	_check("Properties, nothing selected: \"%s\" and \"%s\"" % [words.text, link.text],
		words.is_visible_in_tree() and words.text == "LDraw model by Chris Böhnke, CC BY 4.0"
		and link.is_visible_in_tree() and link.text == "Its LDraw page")
	await _shot("library_credit")
	store.write_now()
	_check("...and kept with the model: %s" % str(ModelStore.credit_in(
		FileAccess.get_file_as_string(TabSession.autosave()))),
		ModelStore.credit_in(FileAccess.get_file_as_string(TabSession.autosave())).get("page")
			== "https://library.ldraw.org/omr/sets/1468")

	print("\nwhen it cannot")
	_main.set("_from_library", "omr-99999-1")
	await _main.call("_maybe_open_library")
	_check("an id the library has not got: %s" % bar.status_text(),
		bar.status_text() == "could not open it: The library has no model omr-99999-1.")
	OS.kill(_server)
	_server = 0
	await create_timer(0.5).timeout
	DirAccess.remove_absolute(ModelLibrary.KEPT + "index.json")
	var cold := ModelLibrary.new()
	cold.parts = _main.get("_library")
	_main.add_child(cold)
	var none: Array = await cold.models()
	_check("no connection, nothing kept: %s" % cold.trouble, none.is_empty()
		and cold.trouble == ("Could not reach the library for the library's index. Check the "
			+ "connection and try again."))
	dialog.open("community")
	await _until(func() -> bool: return str(dialog.last.get("status", "")).begins_with("Could not"), 30.0)
	_check("the community shelf says so: %s" % dialog.last.get("status", ""),
		dialog.last.get("status") == "Could not reach Brickworks. Check the connection and try again.")
	_done([set_pid, copy_pid])


func _covers(dialog: LibraryDialog) -> int:
	var count: int = 0
	for card: Node in (dialog.get("_grid") as GridContainer).get_children():
		var rect: TextureRect = card.find_child("cover", true, false) as TextureRect
		if rect != null and rect.texture != null:
			count += 1
	return count


static func _same(a: Variant, b: Array) -> bool:
	var x: Array = (a as Array).duplicate()
	var y: Array = b.duplicate()
	x.sort()
	y.sort()
	return x == y


func _search(dialog: LibraryDialog, words: String) -> void:
	var field: LineEdit = dialog.get("_search")
	field.text = words
	var asked: int = int(dialog.get("_asked"))
	field.text_submitted.emit(words)
	await _until(func() -> bool:
		return int(dialog.get("_asked")) > asked and dialog.last.get("ask", {}).get("q", "") == words,
		20.0)
	await _frames(2)


## Choose the item of [param named] whose value is [param value] ("" for Any).
func _choose(dialog: LibraryDialog, named: String, value: String) -> void:
	var choice: OptionButton = dialog.get(named)
	for n: int in choice.item_count:
		if str(choice.get_item_metadata(n)) == value:
			choice.select(n)
			var asked: int = int(dialog.get("_asked"))
			choice.item_selected.emit(n)
			await _until(func() -> bool:
				return int(dialog.get("_asked")) > asked and str(dialog.last.get("status", "")) != "Looking…",
				20.0)
			await _frames(2)
			return
	_check("%s has %s" % [named, value], false)


func _until(test: Callable, seconds: float) -> bool:
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < seconds * 1000.0:
		if test.call():
			return true
		await process_frame
	return test.call()


func _frames(n: int) -> void:
	for _n: int in n:
		await process_frame


## The sessions held by a process that is running: id -> process id.
func _sessions() -> Dictionary:
	var held: Dictionary = {}
	for name: String in DirAccess.get_directories_at(TabSession.ROOT):
		var pid_file: String = TabSession.ROOT + name + "/held/pid"
		if not FileAccess.file_exists(pid_file):
			continue
		var pid: int = FileAccess.get_file_as_string(pid_file).strip_edges().to_int()
		if pid > 0 and DirAccess.dir_exists_absolute("/proc/%d" % pid):
			held[name] = pid
	return held


## The first session held that was not in [param before] whose working model
## [param shows]: {id, pid, text}, or what was held last when none did.
func _held_anew(before: Dictionary, shows: Callable) -> Dictionary:
	var since: int = Time.get_ticks_msec()
	var last: Dictionary = {}
	while Time.get_ticks_msec() - since < PATIENCE_S * 1000.0:
		var now: Dictionary = _sessions()
		for name: String in now:
			if before.has(name):
				continue
			var text: String = FileAccess.get_file_as_string(TabSession.ROOT + name + "/autosave.ldr")
			last = {"id": name, "pid": int(now[name]), "text": text}
			if shows.call(text):
				return last
		await create_timer(0.5).timeout
	return last


## What [param pid] was started with: its arguments, separated by NULs in
## /proc, which FileAccess reads as empty.
func _cmdline(pid: int) -> PackedStringArray:
	if pid <= 0:
		return PackedStringArray()
	var said: Array = []
	OS.execute("sh", ["-c", "tr '\\0' '\\n' < /proc/%d/cmdline" % pid], said)
	return "".join(said).split("\n", false)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)


func _done(started: Array) -> void:
	for pid: int in started:
		if pid > 0:
			OS.kill(pid)
	if _server > 0:
		OS.kill(_server)
	print("  stopped %s and the stand-in server" % str(started))
	print("")
	if _failures == 0:
		print("The library opens any set, or a community model, in a window of its own")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
