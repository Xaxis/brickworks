## Search in the library (File, Library…), as a person types it, in the
## real app in a window.
##
##   godot --path . --resolution 1400x900 --script src/dev/library_search_probe.gd
##
## The owner asked that a person can search in the library (2026-10-29). A
## stand-in store and gallery (tools/web/serve.py --library
## tests/fixtures/library, on port 8934: library_probe's is 8901, so the
## two can run at once) play eight sets and three community models, and
## BRICKWORKS_API points this app at it.
##
##   1. Opened with the field empty, the shelf is as it was: all eight sets,
##      newest first as ModelLibrary.search answers no words, "8 of 8
##      sets". The field is above the shelf's note, edged, with a magnifier
##      at its end and a name a screen reader says.
##   2. Ctrl+F gives it the keys. "6056", typed key by key, is asked once,
##      a moment after the last key, and finds the Dragon Wagon by its set
##      number. Escape clears it and keeps the keys there, and the shelf is
##      as it was, exactly.
##   3. A word finds a set by its name ("house": Weetabix Town House) and,
##      carried to Community, a model by its name (Stub Lighthouse); a
##      theme ("launch command") and a designer ("heidemann") find theirs.
##   4. Words and a filter: "town" finds three sets; with the Castle theme
##      chosen, none, said where the covers would be with the filter named
##      and "Any theme, year and size" offered, which brings the three back.
##   5. Words that find nothing: said, with Clear the search and the other
##      shelf offered; that shelf says so too; Clear the search there, and
##      back on the sets the list, its count and its page are as they were.
##   6. The field's own clear button (its ×), clicked, empties it, and the
##      shelf is as it was.
##   7. Enter: "106-1" typed and Enter pressed before the pause asks at once
##      and opens UNICEF Van as its Open does (a process of its own, with
##      --library=omr-106-1, stopped here at once). Enter on words that
##      find nothing opens nothing.
##   8. Paging keeps the words: with 50 more sets put in the index as read,
##      "probe" finds 50 over three pages, Next shows the second still
##      searched, and new words ask from the first page.
##
## With -- --phone, the layout for a finger as a phone in a browser has it,
## in a phone's window (PROBE_SIZE=390x844 tools/probe.sh
## library_search_probe --phone): the same, but Enter only asks there, as
## a screen's keyboard has an Enter for every field.
##
## Pictures: shots/library_search_*.png (library_search_phone_*.png with
## --phone). Look at them.
extends SceneTree

const PORT := 8934

var _failures: int = 0
var _main: Node
var _server: int = 0
var _phone: bool = false
var _dialog: LibraryDialog
var _field: LineEdit


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	_phone = OS.get_cmdline_user_args().has("--phone")
	if _phone:
		# The layout for a finger, as a phone's browser gets it.
		Phone._on = 1
		Phone._wide = false
	var fixture: String = ProjectSettings.globalize_path("res://tests/fixtures/library")
	_server = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/web/serve.py"),
		fixture, str(PORT), "--library", fixture, "--omr", ProjectSettings.globalize_path("res://vendor/omr/files")])
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:%d" % PORT)
	await create_timer(1.5).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var shell: Shell = _main.get("_shell")
	_dialog = shell.library_dialog
	_field = _dialog.get("_search")
	var books: ModelLibrary = _main.get("_model_library")
	var tag: String = "phone_" if _phone else ""
	print("library search, %s" % ("the layout for a phone" if _phone else "the desktop's"))

	print("\nopened, nothing typed")
	var menu: MenuButton = shell.menu("File")
	if menu != null:
		menu.get_popup().id_pressed.emit(shell.menu_id("library"))
	else:
		_dialog.open()
	_check("File, Library… opens it", _dialog.visible)
	await _until(func() -> bool: return int(_dialog.last.get("total", 0)) > 0, 30.0)
	var every: Array = await books.models()
	var plain: Dictionary = ModelLibrary.search(every, {"sort": "newest"})
	var expected: Array = (plain["models"] as Array).map(func(one: Dictionary) -> String: return str(one["id"]))
	var before: Dictionary = _state()
	_check("the shelf as no words ask it: %s" % str(before["shown"]),
		before["shown"] == expected and expected.size() == 8 and before["status"] == "8 of 8 sets"
		and before["page"] == "Page 1 of 1" and not before["none"])
	var note: Label = _dialog.get("_note")
	_check("the field is above the shelf's note: %d < %d" % [int(_field.get_global_rect().position.y),
		int(note.get_global_rect().position.y)],
		_field.get_global_rect().end.y <= note.get_global_rect().position.y)
	var edge: StyleBoxFlat = _field.get_theme_stylebox("normal") as StyleBoxFlat
	_check("...edged as the buttons beside it are",
		edge != null and edge.border_color == Look.OUTLINE and edge.border_width_left == 1)
	_check("...with a magnifier at its end while empty", _field.right_icon != null)
	_check("...named for a screen reader: \"%s\" (%s)" % [_field.accessibility_name,
		_field.accessibility_description],
		_field.accessibility_name == "Search the LDraw sets"
		and _field.accessibility_description.contains("Escape clears it"))
	_check("...and says what it searches: \"%s\"" % _field.placeholder_text,
		_field.placeholder_text == "Search sets by name, set number, theme or designer")
	await _until(func() -> bool: return _covers() == 8, 20.0)
	await _shot("library_search_%sopen" % tag)

	print("\nCtrl+F, typing, Escape")
	_field.release_focus()
	await _frames(2)
	await _key(KEY_F, true)
	_check("Ctrl+F gives the field the keys", _field.has_focus())
	var asked: int = int(_dialog.get("_asked"))
	await _type("6056")
	_check("typed key by key, nothing asked yet: %d" % (int(_dialog.get("_asked")) - asked),
		int(_dialog.get("_asked")) == asked)
	await _until(func() -> bool: return _dialog.last.get("shown") == ["omr-6056-1"], 5.0)
	_check("a moment after, once: %d asked, \"6056\" finds the Dragon Wagon by number: %s"
		% [int(_dialog.get("_asked")) - asked, str(_dialog.last["shown"])],
		_dialog.last["shown"] == ["omr-6056-1"] and int(_dialog.get("_asked")) == asked + 1
		and _dialog.last["status"] == "1 of 8 sets")
	await _key(KEY_ESCAPE)
	await _settled()
	_check("Escape clears it: \"%s\", the keys still there" % _field.text,
		_field.text.is_empty() and _field.has_focus())
	_check("...and the shelf is as it was: %s" % str(_state()), _state() == before)
	await _key(KEY_ESCAPE)
	_check("Escape again, the field empty, leaves it", not _field.has_focus())

	print("\nwhat the words match")
	await _search("house")
	_check("\"house\" finds a set by its name: %s" % str(_dialog.last["shown"]),
		_dialog.last["shown"] == ["omr-1484-1"])
	await _shelf("community")
	_check("...carried to Community: \"%s\", a model by its name: %s"
		% [_dialog.last["ask"]["q"], str(_dialog.last["shown"])],
		_dialog.last["ask"]["q"] == "house" and _dialog.last["shown"] == ["LibStubLgt"])
	_check("...the field named for the shelf: \"%s\"" % _field.accessibility_name,
		_field.accessibility_name == "Search the community's models")
	await _until(func() -> bool: return _covers() == 1, 20.0)
	await _shot("library_search_%scommunity" % tag)
	await _shelf("sets")
	await _search("launch command")
	_check("\"launch command\" finds a set by its theme: %s" % str(_dialog.last["shown"]),
		_dialog.last["shown"] == ["omr-6516-1"])
	await _search("heidemann")
	_check("\"heidemann\" finds a set by its designer: %s" % str(_dialog.last["shown"]),
		_dialog.last["shown"] == ["omr-106-1"])

	print("\nwords and a filter")
	await _search("town")
	_check("\"town\": %s" % str(_dialog.last["shown"]),
		_same(_dialog.last["shown"], ["omr-106-1", "omr-6516-1", "omr-1484-1"]))
	await _until(func() -> bool: return _covers() == 3, 20.0)
	await _shot("library_search_%styped" % tag)
	await _choose("_theme", "Castle")
	var none: VBoxContainer = _dialog.get("_none")
	var hint: Label = _dialog.get("_none_hint")
	var let_go: Button = _dialog.get("_let_go")
	_check("...in Castle, none, said where the covers were: \"%s\"" % _dialog.last["none"],
		none.is_visible_in_tree() and not (_dialog.get("_scroll") as Control).visible
		and _dialog.last["none"] == "No set matches “town”" and _dialog.last["shown"] == [])
	_check("...the filter named: \"%s\"" % hint.text, hint.text.ends_with("filters chosen: Castle."))
	_check("...and \"%s\" offered" % let_go.text,
		let_go.is_visible_in_tree() and let_go.text == "Any theme, year and size")
	await _press(let_go)
	_check("which brings the three back, Any theme: %s" % str(_dialog.last["shown"]),
		_same(_dialog.last["shown"], ["omr-106-1", "omr-6516-1", "omr-1484-1"])
		and _dialog.last["ask"]["theme"] == "" and not none.visible)

	print("\nwords that find nothing")
	await _search("zzqx")
	var elsewhere: Button = _dialog.get("_elsewhere")
	var clear: Button = _dialog.controls_by_name().get("library_clear_search")
	_check("\"zzqx\": \"%s\"" % _dialog.last["none"],
		none.is_visible_in_tree() and _dialog.last["none"] == "No set matches “zzqx”")
	_check("...how to find more: \"%s\"" % hint.text,
		hint.text.begins_with("Try fewer words or another spelling, or a set number"))
	_check("...\"%s\" and \"%s\" offered, not the filters (none chosen)" % [clear.text, elsewhere.text],
		clear.is_visible_in_tree() and elsewhere.text == "Search Community for “zzqx”"
		and not let_go.visible)
	await _shot("library_search_%snone" % tag)
	await _press(elsewhere)
	await _until(func() -> bool: return _dialog.last.get("source") == "community", 20.0)
	_check("the other shelf: \"%s\"" % _dialog.last["none"],
		_dialog.last["none"] == "Nothing in the gallery matches “zzqx”" and none.is_visible_in_tree())
	await _press(clear)
	await _settled()
	_check("Clear the search there: the field empty, three models: %s" % str(_dialog.last["shown"]),
		_field.text.is_empty() and int(_dialog.last["total"]) == 3 and not none.visible)
	await _shelf("sets")
	_check("back on the sets, as they were: %s" % str(_state()), _state() == before)

	print("\nthe field's own clear button")
	await _search("dragon")
	_check("\"dragon\": %s" % str(_dialog.last["shown"]), _dialog.last["shown"] == ["omr-6056-1"])
	await _click(_clear_button_at())
	await _settled()
	_check("its × clicked: \"%s\", as it was: %s" % [_field.text, str(_state())],
		_field.text.is_empty() and _state() == before)

	print("\nEnter")
	_field.grab_focus()
	asked = int(_dialog.get("_asked"))
	await _type("106-1")
	await _key(KEY_ENTER)
	await _until(func() -> bool: return _dialog.last.get("shown") == ["omr-106-1"], 10.0)
	_check("\"106-1\" and Enter before the pause: asked at once, %d time(s): %s"
		% [int(_dialog.get("_asked")) - asked, str(_dialog.last["shown"])],
		_dialog.last["shown"] == ["omr-106-1"] and int(_dialog.get("_asked")) == asked + 1)
	if _phone:
		await create_timer(2.0).timeout
		_check("on a phone, Enter only asks: nothing opened (%s)" % str(_windows()),
			not _dialog.last.has("opened") and _windows().is_empty())
	else:
		await _until(func() -> bool: return not _windows().is_empty(), 15.0)
		var started: PackedInt32Array = _windows()
		var argv: PackedStringArray = _cmdline(started[0]) if not started.is_empty() else PackedStringArray()
		_check("...and opens the first found as its Open does: \"%s\"" % _dialog.get("_status").text,
			_dialog.last.get("opened") == "omr-106-1"
			and str(_dialog.get("_status").text).begins_with("Opening 106-1 UNICEF Van in a new window"))
		_check("...a window of its own, %s, with --library=omr-106-1" % str(started),
			started.size() == 1 and argv.has("--library=omr-106-1"))
		for pid: int in started:
			OS.kill(pid)
		await _until(func() -> bool: return _windows().is_empty(), 10.0)
	await _search("zzqx")
	_field.grab_focus()
	await _key(KEY_ENTER)
	await create_timer(2.0).timeout
	_check("Enter on words that find nothing opens nothing: %s" % str(_windows()),
		not _dialog.last.has("opened") and _windows().is_empty() and none.visible)

	print("\npages")
	var synthetic: Array = []
	for n: int in 50:
		synthetic.append(ModelLibrary._entry({"id": "omr-%d-1" % (70000 + n), "set": "%d-1" % (70000 + n),
			"name": "Probe Hall %d" % n, "theme": "Town > Probe", "year": 1999, "parts": 100 + n,
			"file": "library/omr/%d-1.mpd" % (70000 + n), "cover": "", "author": "Probe", "licence": "CCAL 2.0"}))
	every.append_array(synthetic)
	await _search("probe")
	_check("\"probe\": %d over %d pages, the first 24 shown" % [int(_dialog.last["total"]),
		int(_dialog.get("_pages"))],
		int(_dialog.last["total"]) == 50 and int(_dialog.get("_pages")) == 3
		and (_dialog.last["shown"] as Array).size() == 24)
	var turned: int = int(_dialog.get("_asked"))
	await _press(_dialog.get("_next"))
	await _until(func() -> bool: return int(_dialog.last.get("asked", 0)) > turned, 10.0)
	_check("Next: page %d, still \"%s\", %d shown" % [int(_dialog.last["ask"]["page"]),
		_dialog.last["ask"]["q"], (_dialog.last["shown"] as Array).size()],
		int(_dialog.last["ask"]["page"]) == 2 and _dialog.last["ask"]["q"] == "probe"
		and (_dialog.last["shown"] as Array).size() == 24
		and (_dialog.get("_page_words") as Label).text == "Page 2 of 3")
	await _search("hall 49")
	_check("new words ask from the first page: page %d, %s" % [int(_dialog.last["ask"]["page"]),
		str(_dialog.last["shown"])],
		int(_dialog.last["ask"]["page"]) == 1 and _dialog.last["shown"] == ["omr-70049-1"])
	every.resize(every.size() - synthetic.size())
	_dialog.close()
	_done()


## What the shelf shows, to hold against what it showed before a search.
func _state() -> Dictionary:
	return {"shown": _dialog.last.get("shown", []), "total": int(_dialog.last.get("total", -1)),
		"status": str(_dialog.last.get("status", "")), "source": _dialog.last.get("source"),
		"page": (_dialog.get("_page_words") as Label).text,
		"none": (_dialog.get("_none") as Control).visible, "cards": (_dialog.get("_grid") as Node).get_child_count()}


## Words typed into the field as a person types them, and the pause the shelf
## waits for: then its answer.
func _search(words: String) -> void:
	if not _field.has_focus():
		_field.grab_focus()
	_field.select_all()
	var asked: int = int(_dialog.get("_asked"))
	if words.is_empty():
		await _key(KEY_BACKSPACE)
	else:
		await _type(words)
	await _until(func() -> bool: return (int(_dialog.last.get("asked", 0)) > asked
		and _dialog.get("_answered") == _dialog.get("_asked")
		and str(_dialog.last["ask"]["q"]) == words.strip_edges()), 10.0)
	await _frames(2)


## Until the shelf's last question has its answer.
func _settled() -> void:
	await _frames(2)
	await _until(func() -> bool: return (_dialog.get("_answered") == _dialog.get("_asked")
		and (_dialog.get("_typing") as Timer).is_stopped()), 10.0)
	await _frames(2)


func _shelf(source: String) -> void:
	var asked: int = int(_dialog.get("_asked"))
	(_dialog.controls_by_name()["library_tab_" + source] as Button).pressed.emit()
	await _until(func() -> bool: return (_dialog.last.get("source") == source
		and int(_dialog.last.get("asked", 0)) > asked), 20.0)
	await _frames(2)


## Choose the item of [param named] whose value is [param value] ("" for Any).
func _choose(named: String, value: String) -> void:
	var choice: OptionButton = _dialog.get(named)
	for n: int in choice.item_count:
		if str(choice.get_item_metadata(n)) == value:
			choice.select(n)
			var asked: int = int(_dialog.get("_asked"))
			choice.item_selected.emit(n)
			await _until(func() -> bool: return int(_dialog.last.get("asked", 0)) > asked, 20.0)
			await _frames(2)
			return
	_check("%s has %s" % [named, value], false)


## A button pressed by a click where it is, as a person presses it.
func _press(button: Button) -> void:
	var asked: int = int(_dialog.get("_asked"))
	await _click(button.get_global_rect().get_center())
	await _until(func() -> bool: return int(_dialog.last.get("asked", 0)) > asked, 20.0)
	await _settled()


## Where the field's clear button is: at its end, inside its edge.
func _clear_button_at() -> Vector2:
	var rect: Rect2 = _field.get_global_rect()
	var style: StyleBox = _field.get_theme_stylebox("normal")
	var icon: Texture2D = _field.get_theme_icon("clear")
	return Vector2(rect.end.x - style.get_margin(SIDE_RIGHT) - icon.get_width() * 0.5, rect.get_center().y)


func _type(text: String) -> void:
	for n: int in text.length():
		var letter: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(letter.to_upper())
			event.unicode = letter.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
		await process_frame


func _key(code: Key, held: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = held
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _click(at: Vector2) -> void:
	var window: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var move := InputEventMouseMotion.new()
	move.position = at * window
	move.global_position = move.position
	Input.parse_input_event(move)
	await _frames(2)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at * window
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)


func _covers() -> int:
	var count: int = 0
	for card: Node in (_dialog.get("_grid") as GridContainer).get_children():
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


## The windows Open started: this process's children started as a new
## window (TabSession.NEW_WINDOW). A child not yet past its exec, or gone
## and not yet reaped, is not one.
func _windows() -> PackedInt32Array:
	var said: Array = []
	OS.execute("pgrep", ["-P", str(OS.get_process_id())], said)
	var found := PackedInt32Array()
	for line: String in "".join(said).split("\n", false):
		var pid: int = line.strip_edges().to_int()
		if pid > 0 and pid != _server and _cmdline(pid).has(TabSession.NEW_WINDOW):
			found.append(pid)
	return found


func _cmdline(pid: int) -> PackedStringArray:
	if pid <= 0:
		return PackedStringArray()
	var said: Array = []
	OS.execute("sh", ["-c", "tr '\\0' '\\n' < /proc/%d/cmdline" % pid], said)
	return "".join(said).split("\n", false)


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


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)


func _done() -> void:
	# A window Open started that a failed check left running.
	for pid: int in _windows():
		OS.kill(pid)
	if _server > 0:
		OS.kill(_server)
	print("")
	if _failures == 0:
		print("The library is searched as a person types, by its keys too")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
