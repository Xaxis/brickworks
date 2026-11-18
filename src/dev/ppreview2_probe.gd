## ppreview2: more of an independent review's attacks on partplaces (where each part
## and colour is kept): R10 Put them there with the find empty, R11 a step of
## 30 lots in the booklet.
##
## Kept in src/dev by ppfix (2026-11-18), which fixed R10: Put them there asks
## first when it would move parts kept somewhere else, naming how many, and
## can put only those kept nowhere; one row shown is put at once. Run on a
## relay: tools/relay_probe.sh ppreview2.
##
##   BRICKWORKS_API=http://127.0.0.1:10621 \
##     godot --path . --resolution 1280x720 --script src/dev/ppreview2_probe.gd -- --ppout=DIR
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
	_check("20 loose lots of 3001 added: %s" % added["kind"], added["kind"] == CollectionStore.DONE)

	print("\nR10 Put them there with nothing found: does it ask before moving parts already kept elsewhere?")
	var asked: Array = []
	for n: int in 6:
		asked.append({"part": "3001", "color": COLOURS[n], "place": "drawer %d" % (n + 1)})
	await _call("edit_collection", {"place": asked})
	var before: Dictionary = (await _account_now())["places"]
	_dialog.call("open", "own")
	await _settled()
	_dialog.call("open_places")
	await _settled()
	var controls: Dictionary = _dialog.call("controls_by_name")
	var put: LineEdit = controls["collection_places_put"]
	var go: Button = controls["collection_places_put_go"]
	put.text = "drawer 9"
	put.text_changed.emit(put.text)
	var button_words: String = go.text
	var rev: int = int((await _account_now())["rev"])
	go.pressed.emit()
	await _frames(5)
	var asking: ConfirmationDialog = _dialog.get("_confirm_move")
	var only: Button = _dialog.get("_move_only_unplaced")
	var asked_first: bool = asking != null and asking.visible
	var after: Dictionary = (await _account_now())["places"]
	var moved: int = 0
	for key: String in before:
		if str(after.get(key, "")) != str(before[key]):
			moved += 1
	_check("R10 \"%s\" with the find empty: asked first %s (\"%s\"; %s, %s); %d of the %d parts kept elsewhere moved meanwhile" % [
		button_words, str(asked_first), asking.dialog_text if asking != null else "", asking.ok_button_text
		if asking != null else "", only.text if only != null else "", moved, before.size()],
		asked_first and moved == 0 and int((await _account_now())["rev"]) == rev
		and asking.dialog_text.begins_with("6 of the 20 parts and colours shown") and asking.ok_button_text == "Move all 20"
		and only.visible and only.text == "Only the 14 kept nowhere")
	if asked_first:
		# Only those kept nowhere: the 14, in one change; the 6 stay put.
		only.pressed.emit()
		await _changed()
		await _settled()
		after = (await _account_now())["places"]
		var stayed: int = 0
		var there: int = 0
		for key: String in after:
			if before.has(key) and str(after[key]) == str(before[key]):
				stayed += 1
			elif str(after[key]) == "drawer 9":
				there += 1
		_check("R10 ...\"%s\": %d put in drawer 9, the %d kept elsewhere stayed, in one change (rev %d to %d), dialog %s" % [
			only.text, there, stayed, rev, int((await _account_now())["rev"]), "shut" if not asking.visible else "open"],
			there == 14 and stayed == 6 and int((await _account_now())["rev"]) == rev + 1 and not asking.visible)
		# Again: all 6 left are kept elsewhere, so no "only" this time; yes moves them.
		go.pressed.emit()
		await _frames(5)
		_check("R10 ...Put again: asked \"%s\", %s, the only-those button %s" % [asking.dialog_text.left(70),
			asking.ok_button_text, "shown" if only.visible else "hidden"], asking.visible and not only.visible
			and asking.ok_button_text == "Move all 6")
		asking.get_ok_button().pressed.emit()
		await _changed()
		await _settled()
		after = (await _account_now())["places"]
		var all_there: bool = after.size() == 20 and after.values().all(func(place: Variant) -> bool:
			return str(place) == "drawer 9")
		_check("R10 ...Move all 6 said yes to: all 20 in drawer 9", all_there)
	# One row shown, kept elsewhere: put at once, since it is all the change.
	var find: LineEdit = controls["collection_places_find"]
	find.text = "Blue"
	find.text_changed.emit(find.text)
	await _until(func() -> bool: return (_dialog.get("_places_shown") as Array).size() == 1, 3000)
	put.text = "drawer 1"
	put.text_changed.emit(put.text)
	go.pressed.emit()
	await _changed()
	await _settled()
	_check("R10 ...one row shown (find \"Blue\"), kept elsewhere: put at once, unasked: %s" % str((await _account_now())[
		"places"].get(Collection.key_of("3001", 1, _library), "")), not asking.visible and str((await _account_now())[
		"places"].get(Collection.key_of("3001", 1, _library), "")) == "drawer 1")
	_dialog.call("hide")

	print("\nR11 a step of 30 lots in the booklet")
	await _booklet_30()


func _booklet_30() -> void:
	var lines := PackedStringArray(["0 Thirty", "0 Name: thirty.ldr", "0 Author: ppreview"])
	for n: int in PLATE_COLOURS.size():
		lines.append("1 %d %d 0 %d 1 0 0 0 1 0 0 0 1 3024.dat" % [PLATE_COLOURS[n], (n % 6) * 20, int(n / 6) * 20])
	lines.append("0 STEP")
	var path: String = _out.path_join("thirty.ldr")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\r\n".join(lines) + "\r\n")
	file.close()
	_main.call("_open", ProjectSettings.globalize_path(path))
	await _frames(30)
	ShellPrefs.put("booklet_places", true)
	var sets: Array = [["none", ""], ["drawer N", "drawer %d"], ["40 characters", "Technic case, left tray, compartment %02d"]]
	for one: Array in sets:
		var kept: Dictionary = {}
		if not str(one[1]).is_empty():
			for n: int in PLATE_COLOURS.size():
				kept[Collection.key_of("3024", PLATE_COLOURS[n], _library)] = str(one[1]) % (n + 1) \
					if str(one[1]).contains("%") else str(one[1])
		CollectionStore.places = kept
		var made: Dictionary = await _make_booklet("thirty_" + str(one[0]).replace(" ", "_"))
		CollectionStore.places = {}
		var most: int = 0
		var outside := PackedStringArray()
		var pages: Dictionary = {}
		for box: Dictionary in made["boxes"]:
			pages[int(box["page"])] = true
			most = maxi(most, int(box["lots"]))
			var parts: Rect2 = box["parts"]
			if parts.size == Vector2.ZERO:
				continue
			var panel: Rect2 = box["panel"]
			var sheet: Vector2 = box["sheet"]
			var on_page: bool = parts.position.x >= -0.01 and parts.position.y >= -0.01 and parts.end.x <= sheet.x + 0.01 \
				and parts.end.y <= sheet.y + 0.01
			var in_panel: bool = panel.size == Vector2.ZERO or panel.grow(0.5).encloses(parts)
			print("    %s page %d: %d lots (%d placed), parts box %.1f x %.1f mm at %s in panel %s%s%s" % [one[0],
				int(box["page"]), int(box["lots"]), int(box["placed"]), parts.size.x, parts.size.y, str(parts.position),
				str(panel), "" if in_panel else "  OUTSIDE ITS PANEL", "" if on_page else "  OFF THE PAGE"])
			if not in_panel or not on_page:
				outside.append("page %d: box %.0f x %.0f mm in a %.0f x %.0f panel" % [int(box["page"]), parts.size.x,
					parts.size.y, panel.size.x, panel.size.y])
		_check("R11 %s: %d pages, most lots in a step %d, every parts box in its panel and on its page (%s)" % [one[0],
			pages.size(), most, "; ".join(outside) if not outside.is_empty() else "all"], outside.is_empty())
	await _call("clear_model", {})


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
