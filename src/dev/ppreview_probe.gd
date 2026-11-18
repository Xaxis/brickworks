## ppreview: an independent review's attacks on partplaces (where each part
## and colour is kept).
##
##   BRICKWORKS_API=http://127.0.0.1:10621 \
##     godot --path . --resolution 1280x720 --script src/dev/ppreview_probe.gd -- --ppout=DIR
##
## Signed in as a throwaway account at a Resend test address through a
## relay on this machine (the real api/collection.js, the real database),
## deleted at the end. Prints one "R<n>" line a finding, with what it saw:
##   R1 values over MCP: each odd place set, read back exactly from the account
##   R2 the places CSV: written and read back, each odd place as it was
##   R3 a row's place typed and Enter, then the focus moved: what is sent and said
##   R4 a second row typed while the first is being kept: is it kept or lost?
##   R5 41 characters pasted into a row: cut, refused, or said?
##   R6 the last lot of a part and colour taken out: is its place shown, and can
##      the window take it off?
##   R7 MCP limits: 1,000 places, a bad colour, a part not held, an empty place
##   R8 op place and op built at once over HTTP: both kept?
##   R9 the booklet with 30 lots of 40-character places: does each parts box
##      stay in its panel and on its page; the PDF's and pictures' words
##
## Kept in src/dev by ppfix (2026-11-18), which fixed what it found: R1 a
## place of only U+200B or no-break spaces is none; R2 '=x reads back as
## '=x; R3 Enter sends once and the focus stays in the row; R4 the row
## being typed in keeps its words and the focus while another is kept; R5
## 41 characters are said, never cut; R6 a place on a part held no more is
## listed, and taken off from its row and by a CSV; R7 300 refusals come
## back as 10 and a count. Run on a relay: tools/relay_probe.sh ppreview.
extends SceneTree

const CHAT := "probe-ppreview-chat"
## 3001 in 20 colours: the loose lots, each to be given an odd place.
const COLOURS: Array = [1, 2, 4, 14, 15, 0, 71, 72, 19, 25, 28, 70, 320, 484, 27, 10, 85, 326, 5, 13]

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _out: String = ""
var _socket: CommandSocket
var _next: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
var _dialog: Node
var _store: CollectionStore
var _statuses: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _note(what: String) -> void:
	print("  note  %s" % what)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ppout="):
			_out = argument.trim_prefix("--ppout=")
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("ppreview_out")
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	var api: String = Deployment.api_base()
	if not api.begins_with("http://127.0.0.1"):
		print("ppreview probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % api)
		quit(1)
		return
	Account.where = "user://probe_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_collection.json"
	DirAccess.remove_absolute(CollectionStore.where)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_library = _main.get("_library")
	_dialog = (_main.get("_shell") as Shell).collection
	_store = _dialog.get("store")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_account = _main.get("_account")
	while _account.state == Account.State.CHECKING:
		await _account.changed
	await _frames(10)
	_email = SignInHelper.throwaway("ppreview")
	_dialog.connect("said", func(text: String) -> void: _statuses.append(text))
	await _steps()
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	print("\nppreview probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	root.push_input(down)
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	root.push_input(up)


func _field_of(key: String) -> LineEdit:
	var row: HBoxContainer = _row_of(key)
	return row.get_child(row.get_child_count() - 1) if row != null else null


func _key3001(colour: int) -> String:
	return Collection.key_of("3001", colour, _library)


func _steps() -> void:
	var problem: String = await _sign_in(_account, _email, true)
	_check("signed in: %s" % (problem if not problem.is_empty() else _account.email), problem.is_empty())
	if not problem.is_empty():
		return
	await _store.load_collection()
	var added: Dictionary = await _store.change_lots(COLOURS.map(func(c: int) -> Dictionary:
		return {"part": "3001", "colour": c, "qty": 3}))
	await _settled()
	_check("20 loose lots of 3001 added: %s" % added["kind"], added["kind"] == CollectionStore.DONE
		and _store.collection.parts.size() == 20)

	print("\nR1 values over MCP")
	# [colour, typed, expected as kept]
	var values: Array = [
		[1, "a".repeat(40), "a".repeat(40)],
		[2, "🧱".repeat(40), "🧱".repeat(40)],
		[4, "מגירה 3", "מגירה 3"],
		[14, "درج ٣ - الرف", "درج ٣ - الرف"],
		[15, "drawer\n3", "drawer 3"],
		[0, "tab\there", "tab here"],
		[71, "=SUM(A1)", "=SUM(A1)"],
		[72, "+1", "+1"],
		[19, "@cmd", "@cmd"],
		[25, "'=x", "'=x"],
		[28, "<b>x</b> & <script>alert(1)</script>", "<b>x</b> & <script>alert(1)</script>"],
		[70, "{\"a\": \"b\"}", "{\"a\": \"b\"}"],
		[320, "a,b \"q\"", "a,b \"q\""],
		[484, "\u202Eevil", "evil"],
		[27, "\u200B", ""],
		[10, "\u00A0\u00A0", ""],
		[85, "👨\u200D👩\u200D👧 box", "👨\u200D👩\u200D👧 box"],
	]
	var asked: Array = []
	var want: Dictionary = {}
	for one: Array in values:
		asked.append({"part": "3001", "color": one[0], "place": one[1]})
		want[_key3001(int(one[0]))] = one[2]
	var said: String = await _call("edit_collection", {"place": asked})
	var at_account: Dictionary = await _account_now()
	var kept: Dictionary = at_account["places"]
	var wrong := PackedStringArray()
	var placed: int = 0
	for key: String in want:
		if not str(want[key]).is_empty():
			placed += 1
		if str(kept.get(key, "")) != str(want[key]):
			wrong.append("%s: kept %s, want %s" % [key, JSON.stringify(kept.get(key, "<none>")), JSON.stringify(want[key])])
	_check("R1 all %d odd places kept exactly at the account, those that look blank as none (%s)" % [want.size(),
		"; ".join(wrong) if not wrong.is_empty() else "every one"], wrong.is_empty() and kept.size() == placed)
	_check("R1 ...and the window's copy the same", _same(_store.collection.places, kept)
		and _same(CollectionStore.places, kept))
	var blank := PackedStringArray()
	for key: String in kept:
		var place: String = str(kept[key])
		if place.strip_edges().is_empty() or place.replace("\u200B", "").is_empty():
			blank.append("%s = %s" % [key, JSON.stringify(place)])
	_check("R1 no place that shows as blank is kept (%s)" % ", ".join(blank), blank.is_empty())
	var long_said: String = await _call("edit_collection", {"place": [{"part": "3001", "color": 5, "place": "b".repeat(41)}]})
	_check("R1 41 characters over MCP refused with words: \"%s\"" % long_said.left(120), long_said.begins_with("Nothing was changed")
		and long_said.contains("40"))
	var spaces_said: String = await _call("edit_collection", {"place": [{"part": "3001", "color": 5, "place": "    "}]})
	_note("R1 only spaces for a lot with none: \"%s\"" % spaces_said.left(160).replace("\n", " | "))

	print("\nR2 the places CSV")
	var csv: String = _store.collection.places_csv(_library)
	FileAccess.open(_out.path_join("places.csv"), FileAccess.WRITE).store_string(csv)
	var read: Dictionary = Collection.read_places_csv(csv, _library)
	var back: Dictionary = {}
	for one: Dictionary in read["places"]:
		back[Collection.key_of(str(one["part"]), int(one["colour"]), _library)] = str(one["place"])
	wrong = PackedStringArray()
	for key: String in kept:
		if str(back.get(key, "<none>")) != str(kept[key]):
			wrong.append("%s: read %s, kept %s" % [key, JSON.stringify(back.get(key, "<none>")), JSON.stringify(kept[key])])
	_check("R2 every place read back from its own CSV as kept (%s; bad: %s)" % ["; ".join(wrong) if not wrong.is_empty()
		else "every one", ", ".join(read["bad"])], wrong.is_empty() and (read["bad"] as PackedStringArray).is_empty())

	print("\nR3 a row typed and Enter, then the focus moved")
	_dialog.call("open", "own")
	await _settled()
	_dialog.call("open_places")
	await _settled()
	var key3: String = _key3001(5)
	var field: LineEdit = _field_of(key3)
	_check("R3 3001 in colour 5 has its row", field != null)
	if field != null:
		var changes: Array = [0]
		var count := func() -> void: changes[0] += 1
		_store.changed.connect(count)
		_statuses.clear()
		field.grab_focus()
		await _frames(2)
		field.text = "drawer 7"
		field.text_changed.emit(field.text)
		_key(KEY_ENTER)
		await _changed()
		await _settled()
		var after_enter: String = str((_dialog.get("_status") as Label).text)
		var focus: Control = root.gui_get_focus_owner()
		var again: LineEdit = _field_of(key3)
		_check("R3 after Enter: the focus back in its row's field (%s), status \"%s\", %d change(s)" % [
			focus.get_class() if focus != null else "nothing", after_enter, changes[0]],
			focus != null and focus == again and again.text == "drawer 7" and changes[0] == 1)
		# The person moves on: clicks the find.
		var find: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_places_find"]
		find.grab_focus()
		await _frames(10)
		await _settled()
		await _frames(30)
		await _settled()
		var after_move: String = str((_dialog.get("_status") as Label).text)
		var place_now: String = str((await _account_now())["places"].get(key3, ""))
		_store.changed.disconnect(count)
		_check("R3 Enter then the focus moved: kept \"%s\", %d change(s), said %s" % [place_now, changes[0],
			JSON.stringify(_statuses)], place_now == "drawer 7" and not after_move.contains("as shown")
			and not after_move.contains("nothing was changed") and changes[0] == 1 and _statuses.size() == 1)

	print("\nR4 a second row typed while the first is kept")
	var key_a: String = _key3001(13)
	var key_b: String = _key3001(5)
	var a: LineEdit = _field_of(key_a)
	if a != null:
		_statuses.clear()
		a.grab_focus()
		await _frames(2)
		a.text = "drawer 8"
		_key(KEY_ENTER)
		await _frames(1)
		var b: LineEdit = _field_of(key_b)
		b.grab_focus()
		await _frames(1)
		b.text = "drawer 9"
		b.text_changed.emit(b.text)
		await _changed()
		await _settled()
		await _frames(20)
		await _settled()
		var now: Dictionary = (await _account_now())["places"]
		var b_again: LineEdit = _field_of(key_b)
		var focus_b: Control = root.gui_get_focus_owner()
		_check("R4 row A kept \"%s\"; row B, typed during it and never left, at the account \"%s\", its field now \"%s\", focus on %s, said %s"
			% [str(now.get(key_a, "")), str(now.get(key_b, "")), b_again.text if b_again != null else "(gone)",
			focus_b.get_class() if focus_b != null else "nothing", JSON.stringify(_statuses)],
			str(now.get(key_a, "")) == "drawer 8" and (str(now.get(key_b, "")) == "drawer 9"
			or (b_again != null and b_again.text == "drawer 9")) and focus_b == b_again
			and not ", ".join(_statuses).contains("nothing was changed"))
		# B left: kept now, once.
		_statuses.clear()
		var find4: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_places_find"]
		find4.grab_focus()
		await _changed()
		await _settled()
		var b_kept: String = str((await _account_now())["places"].get(key_b, ""))
		_check("R4 ...row B left: kept \"%s\", said %s" % [b_kept, JSON.stringify(_statuses)], b_kept == "drawer 9"
			and _statuses.size() == 1 and not str(_statuses[0]).contains("nothing was changed"))

	print("\nR5 41 characters pasted into a row")
	var key5: String = _key3001(326)
	var f5: LineEdit = _field_of(key5)
	if f5 != null:
		_statuses.clear()
		var rejected: Array = [""]
		f5.text_change_rejected.connect(func(text: String) -> void: rejected[0] = text)
		f5.grab_focus()
		await _frames(2)
		var pasted: String = "Technic case, left tray, compartment 12"  # 39
		pasted += "34"  # 41: "compartment 1234"
		f5.insert_text_at_caret(pasted)
		f5.text_changed.emit(f5.text)
		var in_field: String = f5.text
		_key(KEY_ENTER)
		await _changed()
		await _settled()
		var kept5: String = str((await _account_now())["places"].get(key5, ""))
		_check("R5 41 characters pasted (\"%s\"): the field holds %d (\"%s\"), rejected \"%s\"; kept \"%s\"; said %s" % [
			pasted, in_field.length(), in_field, rejected[0], kept5, JSON.stringify(_statuses)],
			in_field == pasted and kept5.is_empty() and _statuses.size() > 0 and str(_statuses[-1]).contains("at most 40")
			and str(_statuses[-1]).contains("41"))

	print("\nR6 the last lot of a part and colour taken out")
	var key6: String = _key3001(1)
	var key6b: String = _key3001(2)
	var lots6: Array = []
	for lot: Dictionary in _store.collection.parts:
		if Collection.key_of(str(lot["part"]), int(lot["colour"]), _library) in [key6, key6b]:
			lots6.append(lot.merged({"to": 0}))
	var gone6: Dictionary = await _store.set_counts(lots6)
	await _settled()
	var now6: Dictionary = await _account_now()
	_dialog.call("open_places")
	await _settled()
	var row6: HBoxContainer = _row_of(key6)
	var title6: String = (_dialog.get("_places_title") as Label).text
	_check("R6 3001 in Blue and Green taken out (%s): their places at the account %s, %s; Blue's row on Where it's kept: %s; \"%s\"" % [
		gone6["kind"], JSON.stringify(now6["places"].get(key6, "<none>")), JSON.stringify(now6["places"].get(key6b, "<none>")),
		"shown" if row6 != null else "none", title6],
		row6 != null and _row_of(key6b) != null and title6.contains("and 2 you own none of now"))
	# A new place on one held no more: said, nothing sent.
	var f6: LineEdit = _field_of(key6)
	if f6 != null:
		f6.grab_focus()
		await _frames(2)
		_statuses.clear()
		f6.text = "drawer 99"
		_key(KEY_ENTER)
		await _frames(5)
		var said6: String = ", ".join(_statuses)
		_check("R6 ...a new place typed in its row: \"%s\", nothing sent" % said6, said6.contains("you own none of it now")
			and str((await _account_now())["places"].get(key6, "")) == str(now6["places"].get(key6, "")))
		f6.text = ""
		_key(KEY_ENTER)
		await _changed()
		await _settled()
		var row_off: Dictionary = await _account_now()
		_check("R6 ...its place emptied and Enter: taken off at the account (%s)" % JSON.stringify(
			row_off["places"].get(key6, "<none>")), not (row_off["places"] as Dictionary).has(key6))
	var off: Dictionary = await _dialog.call("read_places", "Part,Colour,Place\r\n3001,2,\r\n")
	var after_off: Dictionary = await _account_now()
	_check("R6 ...a CSV taking Green's off (3001,2,\"\"): %s; at the account now %s" % [JSON.stringify(off.get("left", [])),
		JSON.stringify(after_off["places"].get(key6b, "<none>"))], not (after_off["places"] as Dictionary).has(key6b)
		and (off.get("left", []) as PackedStringArray).is_empty() and int(off.get("set", 0)) == 1)
	_dialog.call("open_places")
	await _settled()
	_check("R6 ...and neither listed any more", _row_of(key6) == null and _row_of(key6b) == null)
	var parts_list_place: String = Collection.place_in(CollectionStore.places, "3001", 1, _library)
	_note("R6 ...the parts list and booklet still name it for a model's 3001 in Blue: \"%s\"" % parts_list_place)

	print("\nR7 MCP limits")
	var thousand: Array = []
	for n: int in 1000:
		thousand.append({"part": "3001", "color": COLOURS[n % COLOURS.size()], "place": "bin %d" % n})
	var r7a: String = await _call("edit_collection", {"place": thousand})
	_check("R7 1,000 places: \"%s\"" % r7a.left(140), r7a.begins_with("At most") or r7a.begins_with("Nothing was changed"))
	var r7b: String = await _call("edit_collection", {"place": [{"part": "3001", "color": 9999, "place": "x"}]})
	_check("R7 colour 9999: \"%s\"" % r7b.left(160).replace("\n", " | "), r7b.begins_with("Nothing was changed"))
	var r7c: String = await _call("edit_collection", {"place": [{"part": "3001", "color": "Bright Light Orange", "place": "x"}]})
	_note("R7 a colour by a name not held: \"%s\"" % r7c.left(160).replace("\n", " | "))
	var many: Array = []
	for n: int in 300:
		many.append({"part": "300%d" % (n % 10) if n < 10 else "60%03d" % n, "color": 4, "place": "x"})
	var r7d: String = await _call("edit_collection", {"place": many})
	_check("R7 300 parts not held: %d characters back, 10 named and the rest counted, \"…%s\"" % [r7d.length(),
		r7d.right(60).replace("\n", " | ")], r7d.length() < 2500 and RegEx.create_from_string("; and [0-9]+ more").search(r7d) != null
		and r7d.begins_with("Nothing was changed"))
	var r7e: String = await _call("edit_collection", {"place": [{"part": "3002", "color": 4, "place": ""}]})
	_note("R7 an empty place for a part not held: \"%s\"" % r7e.left(200).replace("\n", " | "))
	var held7: Dictionary = await _account_now()
	_check("R7 ...none of them changed the account's places", _same(held7["places"], after_off["places"]))

	print("\nR8 op place and op built at once")
	# Not over sets (this collection has none): op lots and op place at once.
	var answers: Array = [null, null]
	var send := func(body: Dictionary, at: int) -> void:
		answers[at] = await _http(HTTPClient.METHOD_POST, body)
	var stamp: String = str(Time.get_ticks_usec())
	send.call({"op": "lots", "id": "pp-" + stamp + "-a", "add": [{"part": "3001", "colour": 4, "qty": 1}]}, 0)
	send.call({"op": "place", "id": "pp-" + stamp + "-b", "places": [{"part": "3001", "colour": 4,
		"was": str(after_off["places"].get(_key3001(4), "")), "place": "both at once"}]}, 1)
	await _until(func() -> bool: return answers[0] != null and answers[1] != null, 30000)
	var now8: Dictionary = await _account_now()
	var qty: int = 0
	for lot: Dictionary in now8["parts"]:
		if str(lot["part"]) == "3001" and int(lot["colour"]) == 4:
			qty += int(lot["qty"])
	_check("R8 a lot added and a place set at once: %d and %d; 3001 in Red %d (was 3), kept in \"%s\"" % [
		int(answers[0]["code"]) if answers[0] != null else -1, int(answers[1]["code"]) if answers[1] != null else -1, qty,
		str(now8["places"].get(_key3001(4), ""))], qty == 4 and str(now8["places"].get(_key3001(4), "")) == "both at once")

	print("\nR9 the booklet")
	await _store.load_collection()
	_dialog.call("hide")
	await _booklet_fit()


const PLATE_COLOURS: Array = [1, 2, 4, 14, 15, 0, 71, 72, 19, 25, 28, 70, 320, 484, 27, 10, 85, 326, 5, 13,
	7, 8, 6, 22, 26, 29, 31, 73, 191, 212]


## A flat 6 x 5 of 1 x 1 plates in 30 colours, one layer.
func _flat() -> Array:
	var out: Array = []
	for n: int in PLATE_COLOURS.size():
		out.append({"part": "3024", "color": PLATE_COLOURS[n], "x": (n % 6) * 20, "y": 0, "z": int(n / 6) * 20, "rot": 0})
	return out


func _make_booklet(name: String) -> Dictionary:
	var maker := BookletMaker.new()
	maker.library = _library
	maker.px_per_mm = 2.5
	root.add_child(maker)
	var html: String = await maker.make(_main.get("_world"), {}, name)
	var path: String = _out.path_join(name + ".html")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(html)
	file.close()
	var out: Dictionary = {"path": path, "html": html, "boxes": []}
	var sheet: Vector2 = maker.document.sheet.size() if maker.document.sheet != null else Booklet.PAGE
	for page: Booklet.Page in maker.document.pages:
		for entry: Booklet.Entry in page.entries:
			(out["boxes"] as Array).append({"page": page.number, "lots": entry.lots.size(),
				"placed": entry.lots.filter(func(lot: Booklet.Lot) -> bool: return not lot.place.is_empty()).size(),
				"parts": entry.parts_rect, "panel": entry.panel, "rect": entry.rect, "sheet": sheet,
				"callout": entry.in_callout})
	maker.queue_free()
	return out


func _booklet_fit() -> void:
	await _call("clear_model", {})
	var built: String = await _call("submit_design", {"name": "Fit", "description": "a test", "floor": "none",
		"bricks": _flat()})
	_check("R9 a flat of 30 plates in 30 colours built: \"%s\"" % built.get_slice("\n", 0).left(100), built.begins_with("Built"))
	ShellPrefs.put("booklet_places", true)
	# Each plate's place 40 characters, set as the window's store keeps them
	# (CollectionStore.places is what BookletMaker reads).
	var forty: Array = ["W".repeat(40), "Technic case, left tray, compartment 12a", "🧱".repeat(40),
		"drawer 3", "m".repeat(40)]
	var kept: Dictionary = {}
	for n: int in PLATE_COLOURS.size():
		kept[Collection.key_of("3024", PLATE_COLOURS[n], _library)] = forty[n % forty.size()]
	CollectionStore.places = kept
	var wide: Dictionary = await _make_booklet("fit_places")
	CollectionStore.places = {}
	var plain: Dictionary = await _make_booklet("fit_plain")
	for made: Dictionary in [plain, wide]:
		var outside := PackedStringArray()
		var most: int = 0
		for box: Dictionary in made["boxes"]:
			most = maxi(most, int(box["lots"]))
			var parts: Rect2 = box["parts"]
			if parts.size == Vector2.ZERO:
				continue
			var panel: Rect2 = box["panel"]
			var sheet: Vector2 = box["sheet"]
			var on_page: bool = parts.position.x >= -0.01 and parts.position.y >= -0.01 and parts.end.x <= sheet.x + 0.01 \
				and parts.end.y <= sheet.y + 0.01
			var in_panel: bool = panel.size == Vector2.ZERO or panel.grow(0.5).encloses(parts)
			print("    %s page %d: %d lots (%d placed), parts box %s in panel %s%s%s" % [str(made["path"]).get_file(),
				int(box["page"]), int(box["lots"]), int(box["placed"]), str(parts), str(panel),
				"" if in_panel else "  OUTSIDE ITS PANEL", "" if on_page else "  OFF THE PAGE"])
			if not in_panel or not on_page:
				outside.append("page %d: box %.0f x %.0f mm in a %.0f x %.0f panel" % [int(box["page"]), parts.size.x,
					parts.size.y, panel.size.x, panel.size.y])
		_check("R9 %s: most lots in a step %d, every parts box in its panel and on its page (%s)" % [
			str(made["path"]).get_file(), most, "; ".join(outside) if not outside.is_empty() else "all"], outside.is_empty())
	# The widest a part's cell gets, against the widest a box may be.
	var lot := Booklet.Lot.new()
	lot.size = Vector2(8, 6)
	for place: String in forty:
		lot.place = place
		_note("R9 a cell for \"%s\": %.1f mm wide" % [place.left(12), Booklet.cell_width(lot)])

	# The odd places in the booklet's page, its PDF and its pictures.
	var odd: Array = ["<b>x</b> & <script>alert(1)</script>", "מגירה 3", "درج ٣ - الرف", "🧱🧱 box", "=SUM(A1)",
		"{\"a\": \"b\"}", "a,b \"q\"", "'=x", "👨\u200D👩\u200D👧 box", "drawer 3"]
	kept = {}
	for n: int in PLATE_COLOURS.size():
		kept[Collection.key_of("3024", PLATE_COLOURS[n], _library)] = odd[n % odd.size()]
	CollectionStore.places = kept
	var shown: Dictionary = await _make_booklet("odd_places")
	CollectionStore.places = {}
	var html: String = shown["html"]
	_check("R9 the page escapes a place's markup: no <script> in it, \"&lt;script&gt;\" there",
		not html.contains("<script>alert(1)") and html.contains("from &lt;b&gt;x&lt;/b&gt; &amp; &lt;script&gt;"))
	var read := BookletRead.new()
	var pdf: String = ProjectSettings.globalize_path(_out.path_join("odd_places.pdf"))
	var writer := BookletPdf.new()
	writer.begin(pdf, read)
	var pages: int = await read.read_all(ProjectSettings.globalize_path(str(shown["path"])), writer.page)
	writer.finish(read.title)
	_check("R9 the PDF written: %d pages, ok %s" % [pages, str(writer.ok())], writer.ok() and pages > 0)
	var drawer := BookletPng.new()
	root.add_child(drawer)
	var zip: String = ProjectSettings.globalize_path(_out.path_join("odd_places_pages.zip"))
	var drawn: int = await drawer.write(ProjectSettings.globalize_path(str(shown["path"])), zip, "odd_places")
	drawer.queue_free()
	_check("R9 the pages drawn as pictures: %d" % drawn, drawn == pages)
	var text: Array = []
	OS.execute("pdftotext", ["-enc", "UTF-8", pdf, "-"], text, true)
	var words: String = "".join(text)
	FileAccess.open(_out.path_join("odd_places.txt"), FileAccess.WRITE).store_string(words)
	var missing := PackedStringArray()
	for place: String in odd:
		if not words.contains("from " + place):
			missing.append(place)
	_note("R9 the PDF's words (pdftotext) lack, as typed: %s" % JSON.stringify(missing))
	_check("R9 every Latin place reads back from the PDF as typed", not missing.has("=SUM(A1)") and not missing.has("drawer 3")
		and not missing.has("a,b \"q\"") and not missing.has("<b>x</b> & <script>alert(1)</script>"))
	await _call("clear_model", {})


func _row_of(key: String) -> HBoxContainer:
	for row: HBoxContainer in _dialog.call("place_rows"):
		if str((row.get_meta("place") as Dictionary)["key"]) == key:
			return row
	return null




static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _type_sets(text: String) -> void:
	var typed: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_sets"]
	typed.text = text
	((_dialog.call("controls_by_name") as Dictionary)["collection_add_sets"] as Button).pressed.emit()
	await _changed()
	await _settled()


# -- the account ----------------------------------------------------------------------


## The collection as the account has it now: {"sets", "parts", "places",
## "rev", "updated_at"}.
func _account_now() -> Dictionary:
	var reply: Dictionary = await _http(HTTPClient.METHOD_GET, null)
	var parsed: Variant = reply["body"]
	if not parsed is Dictionary:
		return {"sets": [], "parts": [], "places": {}, "rev": -1, "updated_at": ""}
	return {"sets": parsed.get("sets", []), "parts": parsed.get("parts", []), "places": parsed.get("places", {}),
		"rev": parsed.get("rev", -1), "updated_at": parsed.get("updated_at", "")}


## /api/collection asked as the account signed in: {"code", "body"}.
func _http(method: int, body: Variant) -> Dictionary:
	var token: String = await _account.access_token()
	var http := HTTPRequest.new()
	root.add_child(http)
	var headers := PackedStringArray(["authorization: Bearer " + token])
	if body != null:
		headers.append("content-type: application/json")
	http.request(Deployment.api_base() + "/api/collection", headers, method,
		JSON.stringify(body) if body != null else "")
	var result: Array = await http.request_completed
	http.queue_free()
	return {"code": int(result[1]), "body": JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())}


## [param account] signed in as [param email] with a password, the session
## taken as a code's verify is taken, the age question answered when asked:
## the account made first when [param make].
func _sign_in(account: Account, email: String, make: bool) -> String:
	if make:
		_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
		var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
			"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password, "email_confirm": true}))
		if int(made.get("code", 0)) != 200:
			return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._signed_in_with(reply["body"])
	await _until(func() -> bool: return not account.asking_who, 15000)
	if account.age_ask:
		var answered: String = await account.answer_age(3, int(Time.get_datetime_dict_from_system()["year"]) - 30)
		if not answered.is_empty():
			return "the age question: " + answered
	return "" if account.signed_in() else "signed out again"


# -- the session ----------------------------------------------------------------------


func _call(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments,
			"_meta": {CommandSocket.CHAT_KEY: {"chat": CHAT}}}})
	var text: String = ""
	for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str((block as Dictionary).get("text", ""))
	print("    %s said: %s" % [tool, text.left(300).replace("\n", " | ")])
	return text


# -- waiting --------------------------------------------------------------------------


func _settled() -> void:
	var waited: int = Time.get_ticks_msec()
	await _frames(3)
	while (bool(_dialog.get("_writing")) or not (_dialog.get("_counts_typed") as Dictionary).is_empty()) \
			and Time.get_ticks_msec() - waited < 30000:
		await process_frame
	await _frames(3)


## The store's next change, or 15 s.
func _changed() -> void:
	var done: Array = [false]
	var mark := func() -> void: done[0] = true
	_store.changed.connect(mark, CONNECT_ONE_SHOT)
	var waited: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - waited < 15000:
		await process_frame
	if _store.changed.is_connected(mark):
		_store.changed.disconnect(mark)
	await _frames(3)


func _until(ready: Callable, most_ms: int) -> void:
	var waited: int = Time.get_ticks_msec()
	while not ready.call() and Time.get_ticks_msec() - waited < most_ms:
		await process_frame
	await _frames(3)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_shots)
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _shots.path_join("%s_%dx%d.png" % [name, size.x, size.y])
	image.save_png(path)
	print("    picture: %s" % path)
