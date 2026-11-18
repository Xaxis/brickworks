## Where each part is kept, and the booklet saying it (APP_UX9 #14,
## partplaces).
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 10551 &
##   BRICKWORKS_API=http://127.0.0.1:10551 \
##     godot --path . --resolution 1280x720 --script src/dev/partplaces_probe.gd
##   ... -- --shots=DIR   Where it's kept, the parts list by place, pictured
##   (tools/relay_probe.sh partplaces runs it on a relay of its own)
##
## On the real scene, through api/collection.js on the relay and the real
## database (supabase/partplaces.sql applied), signed in as a throwaway
## account at a Resend test address (made with a password, no code
## redeemed), deleted at the end:
##
##   1. 7140-1 typed in My collection and 12 loose lots added; the sets and
##      lots as the account and this device keep them, byte for byte
##   2. over MCP, edit_collection place= on 12 lots in 1 call (8 loose, 4
##      only 7140-1 holds): kept at the account, each said "was nowhere";
##      refused with words, nothing changed: a part not held, a place over
##      40 characters, a place that is no words, place= with add=; read
##      back with each lot's place
##   3. the window's Where it's kept: a part only 7140-1 holds typed in its
##      row, kept; a find and Put them there, every part shown in one change
##      (the rev one on); sorted by place, as a walk round them takes
##   4. kept: the sets and lots as in 1, byte for byte at the account and on
##      this device, and the time the counts were kept; a restart reads the
##      places from this device and the account; another device signed in
##      to the account (a fresh profile) has every one
##   5. sorted: a model of 9 of the parts, its parts list by where each is
##      kept ("drawer 2" before "drawer 10", none last), each row naming it
##   6. in the booklet: each step's parts box names each part's place,
##      "from drawer 3"; with Say where each is kept turned off, none does
##   7. an older build (rel-m308's Collection, live, from git, compiled)
##      reading the account's copy keeps every set and lot byte for byte and
##      drops only the places; the copy it writes on this device, read here
##      with the account out of reach, is said to lack them, and they come
##      back from the account; its whole copy PUT (an older app's Remove a
##      set) leaves every place at the account
##   8. two tabs at once: two parts placed from two tabs together, both
##      kept; one part from both, from the same place shown: one kept, the
##      other told, shown it as it is now
##   9. the CSV: Save places as CSV, every place taken off, Places CSV…
##      read back, every place as it was; a CSV with a part not held, a
##      colour that is none and a place a spreadsheet takes for a formula:
##      the first two said and left out, the third kept as words
##  10. a place on a lot the collection doesn't own: the store's change is
##      refused (conflict), nothing kept
##  11. Start over forgets every place
##  12. the new lines drawn read in de, fr and es
##
## Before supabase/partplaces.sql is applied, 2 on fail with the account's
## words ("places cannot be kept with your account yet"). Writes nothing in
## the app's own directory: the account's copy and the sessions go to the
## probe's own data folder (probe.sh's XDG_DATA_HOME).
extends SceneTree

const SET := "7140-1"
## Live's build when this was written (rel-m308): the build out there that
## knows no places.
const OLDER := "b3ad541f7"
const CHAT := "probe-partplaces-chat"
## The 12 loose lots: part, LDraw colour, how many (keptbuilt's).
const LOTS: Array = [
	["3001", 4, 12], ["3020", 0, 4], ["3021", 4, 4], ["4600", 0, 2], ["4624", 71, 4],
	["3641", 0, 4], ["3004", 15, 6], ["3023", 15, 6], ["3024", 47, 4], ["3069b", 0, 4],
	["3010", 1, 4], ["3062b", 14, 2],
]
## The loose lots placed over MCP, by their index in LOTS, and where.
const PLACED: Array = [[0, "drawer 3"], [1, "drawer 10"], [2, "drawer 2"], [6, "B3"], [7, "b12"],
	[8, "drawer 3"], [9, "Drawer 1"], [10, "tray"]]
## Where the 4 parts only 7140-1 holds go.
const SET_PLACES: Array = ["box 7", "box 10", "drawer 2", "shelf"]

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _socket: CommandSocket
var _next: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
## Untyped: partplaces' calls are looked up as they are made, so pre261
## fails a check rather than the script.
var _dialog: Node
var _store: CollectionStore
## Every line drawn that this unit added, for the languages (12).
var _drawn: PackedStringArray = PackedStringArray()
var _number: RegEx = RegEx.create_from_string("^[0-9][0-9a-z]*(-[0-9]+)?$")


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots = argument.trim_prefix("--shots=")
	await process_frame
	var api: String = Deployment.api_base()
	if not api.begins_with("http://127.0.0.1"):
		print("partplaces probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % api)
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
	_email = SignInHelper.throwaway("partplaces")
	await _steps()
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	print("\npartplaces probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	var problem: String = await _sign_in(_account, _email, true)
	_check("signed in: %s" % (problem if not problem.is_empty() else _account.email), problem.is_empty())
	if not problem.is_empty():
		return
	await _store.load_collection()

	print("\n1. 7140-1 and 12 loose lots")
	_dialog.call("open", "own")
	await _settled()
	await _type_sets("7140")
	var added: Dictionary = await _store.change_lots(LOTS.map(func(lot: Array) -> Dictionary:
		return {"part": lot[0], "colour": lot[1], "qty": lot[2]}))
	await _settled()
	var before: Dictionary = await _account_now()
	var device_before: String = _device_rest()
	_check("7140-1 typed and 12 lots added (%s): %d sets, %d lots, no places" % [added["kind"],
		(before["sets"] as Array).size(), (before["parts"] as Array).size()], added["kind"] == CollectionStore.DONE
		and (before["sets"] as Array).size() == 1 and (before["parts"] as Array).size() == 12
		and (before["places"] as Dictionary).is_empty())
	var record: Dictionary = (await _store.inventories.lookup(PackedStringArray([SET]))).get(SET, {})
	var loose: Dictionary = {}
	for lot: Array in LOTS:
		loose[Collection.key_of(lot[0], lot[1], _library)] = true
	var only_set: Array = []
	for row: Array in record.get("p", []):
		var key: String = Collection.key_of(str(row[0]), int(row[1]), _library)
		if not loose.has(key) and not only_set.has(key):
			only_set.append(key)
	only_set.sort()
	_check("7140-1's inventory read: %d parts and colours none of the loose lots is" % only_set.size(), only_set.size() >= 6)
	if only_set.size() < 6:
		return

	print("\n2. over MCP, 12 in 1 call")
	var asked: Array = []
	var want: Dictionary = {}
	for one: Array in PLACED:
		var lot: Array = LOTS[int(one[0])]
		asked.append({"part": lot[0], "color": lot[1], "place": one[1]})
		want[Collection.key_of(lot[0], lot[1], _library)] = one[1]
	for n: int in SET_PLACES.size():
		var key: String = only_set[n]
		asked.append({"part": Collection.part_of(key), "color": Collection.colour_of(key), "place": SET_PLACES[n]})
		want[key] = SET_PLACES[n]
	var calls_before: int = _next
	var said: String = await _call("edit_collection", {"place": asked})
	var at_account: Dictionary = await _account_now()
	_check("edit_collection place= on 12 lots, in %d call: \"%s\"" % [_next - calls_before, said.get_slice("\n", 0)],
		_next - calls_before == 1 and said.begins_with("Kept at the person's account") and said.count("(was nowhere)") == 12
		and _same(at_account["places"], want))
	_check("...the window's copy the same: %d places" % _store.collection.places.size(),
		_same(_store.collection.places, want) and _same(CollectionStore.places, want))
	var held: Dictionary = at_account
	var refusals: Array = [
		[{"place": [{"part": "3001", "color": 1, "place": "drawer 9"}]}, "is not in the person's collection"],
		[{"place": [{"part": "3001", "color": 4, "place": "x".repeat(41)}]}, "at most 40 characters"],
		[{"place": [{"part": "3001", "color": 4, "place": 3}]}, "place is words"],
		[{"place": [{"part": "3001", "color": 4, "place": "a"}], "add": [{"part": "3001", "color": 4, "count": 1}]},
			"one thing a call"],
	]
	for refused: Array in refusals:
		var no: String = await _call("edit_collection", refused[0])
		_check("refused: \"%s\"" % no.left(140), no.begins_with("Nothing was changed") and no.contains(refused[1]))
	_check("...none of it changed anything at the account", _same(await _account_now(), held))
	var read: String = await _call("edit_collection", {})
	_check("read back: \"%s\"" % _line_with(read, "kept in drawer 3").strip_edges().left(140),
		_line_with(read, "3001 ").contains("kept in drawer 3") and read.contains("Where they keep parts")
		and _line_with(read, "drawer 2:").contains(Collection.part_of(only_set[2])))

	print("\n3. the window's Where it's kept")
	_dialog.call("open", "own")
	await _settled()
	var opener: Button = (_dialog.call("controls_by_name") as Dictionary).get("collection_places")
	_check("What I own has Where it's kept…: \"%s\"" % (opener.text if opener != null else "none"),
		opener != null and opener.visible)
	if opener == null:
		return
	_drawn.append(opener.text)
	_drawn.append(opener.tooltip_text)
	opener.pressed.emit()
	await _settled()
	var listed: Array = _dialog.call("places_listed")
	var holds: Dictionary = _store.collection.held_keys(_store.records, _library)
	var title: String = (_dialog.get("_places_title") as Label).text
	_check("it lists every part and colour held, the sets' too: %d of %d, \"%s\"" % [listed.size(), holds.size(), title],
		listed.size() == holds.size() and title.contains("12 of %d" % holds.size()))
	_drawn_page()
	await _shot("partplaces_page")
	var row_key: String = only_set[4]
	var row: HBoxContainer = _row_of(row_key)
	var field: LineEdit = row.get_child(row.get_child_count() - 1) if row != null else null
	_check("a part only 7140-1 holds has its row: %s" % row_key, field != null)
	if field == null:
		return
	field.text = "  shelf \n 2 "
	field.text_submitted.emit(field.text)
	await _changed()
	await _settled()
	want[row_key] = "shelf 2"
	_drawn.append(str((_dialog.get("_status") as Label).text))
	_check("typed in its row and Enter: kept at the account as \"shelf 2\", made one line",
		_same((await _account_now())["places"], want))
	var find: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_places_find"]
	find.text = "3023"
	find.text_changed.emit(find.text)
	await _until(func() -> bool: return (_dialog.get("_places_shown") as Array).size() < listed.size(), 3000)
	var shown: Array = _dialog.get("_places_shown")
	var put: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_places_put"]
	put.text = "drawer 4"
	put.text_changed.emit(put.text)
	var go: Button = (_dialog.call("controls_by_name") as Dictionary)["collection_places_put_go"]
	_drawn.append(go.text)
	_drawn.append(go.tooltip_text)
	var rev: int = int((await _account_now())["rev"])
	go.pressed.emit()
	await _changed()
	await _settled()
	for one: Dictionary in shown:
		want[str(one["key"])] = "drawer 4"
	var after_put: Dictionary = await _account_now()
	_drawn.append(str((_dialog.get("_status") as Label).text))
	_check("find \"3023\" and Put the %d shown there (\"%s\"): each kept in drawer 4, in one change (rev %d to %d)" % [
		shown.size(), go.text, rev, int(after_put["rev"])], shown.size() >= 2 and _same(after_put["places"], want)
		and int(after_put["rev"]) == rev + 1)
	find.text = ""
	find.text_changed.emit("")
	var sort: OptionButton = (_dialog.call("controls_by_name") as Dictionary)["collection_places_sort"]
	sort.select(1)
	sort.item_selected.emit(1)
	await _settled()
	var order: Array = (_dialog.call("places_listed") as Array).map(func(one: Dictionary) -> String: return str(one["place"]))
	_check("By place: %s" % ", ".join(_runs(order)), _in_place_order(order))
	await _shot("partplaces_by_place")
	sort.select(0)
	sort.item_selected.emit(0)

	print("\n4. kept")
	var now: Dictionary = await _account_now()
	_check("the sets and lots at the account as in 1, byte for byte, and the time the counts were kept",
		_same(now["sets"], before["sets"]) and _same(now["parts"], before["parts"]) and now["updated_at"] == before["updated_at"])
	_check("...and on this device, byte for byte", _device_rest() == device_before)
	var restarted := CollectionStore.new()
	restarted.library = _library
	restarted.account = _account
	root.add_child(restarted)
	_check("a restart reads every place from the copy on this device: %d" % restarted.collection.places.size(),
		_same(restarted.collection.places, want))
	var fetched: String = await restarted.load_collection()
	_check("...and from the account", fetched.is_empty() and _same(restarted.collection.places, want))
	restarted.queue_free()
	Account.where = "user://probe_other_session.json"
	var other := Account.new()
	other.keeps = false
	other.deployment = _account.deployment
	root.add_child(other)
	while other.state == Account.State.CHECKING:
		await other.changed
	problem = await _sign_in(other, _email, false)
	var elsewhere := CollectionStore.new()
	elsewhere.library = _library
	elsewhere.account = other
	root.add_child(elsewhere)
	fetched = await elsewhere.load_collection()
	_check("another device signed in to the account (a fresh profile): every one of the %d places%s" % [
		elsewhere.collection.places.size(), "" if problem.is_empty() else " (" + problem + ")"],
		problem.is_empty() and fetched.is_empty() and _same(elsewhere.collection.places, want))
	elsewhere.queue_free()
	await other.sign_out()
	other.queue_free()
	Account.where = "user://probe_session.json"

	print("\n5. sorted")
	_dialog.call("hide")
	var model: Array = _tower([["3020", 0], ["3001", 4], ["3021", 4], ["3010", 1], ["3004", 15], ["3023", 15],
		["3024", 47], ["3062b", 14], ["3069b", 0]])
	var built: String = await _call("submit_design", {"name": "Placed", "description": "a test", "floor": "none",
		"bricks": model})
	_check("a model of 9 of the parts built: \"%s\"" % built.get_slice("\n", 0).left(120), built.begins_with("Built"))
	_main.call("_toggle_parts")
	await _frames(5)
	var parts_list: InventoryPanel = _main.get("_inventory")
	var by: OptionButton = parts_list.controls_by_name().get("parts_sort")
	_check("the parts list offers By where it's kept", by != null and by.visible)
	if by != null:
		_drawn.append(by.get_item_text(0))
		_drawn.append(by.get_item_text(1))
		_drawn.append(by.tooltip_text)
		by.select(1)
		by.item_selected.emit(1)
		await _frames(3)
		var rows: Array = parts_list.rows_listed()
		var places: Array = rows.map(func(one: Dictionary) -> String: return str(one["place"]))
		var named: int = 0
		for child: Node in (parts_list.get("_rows") as Node).get_children():
			for label: Node in child.find_children("*", "Label", true, false):
				if (label as Label).tooltip_text.begins_with("Kept in"):
					named += 1
					if _drawn.find((label as Label).tooltip_text) < 0 and named == 1:
						_drawn.append((label as Label).tooltip_text)
		_check("by place: %s; %d rows name their place" % [", ".join(places.map(func(p: String) -> String:
			return p if not p.is_empty() else "none")), named], rows.size() == 9 and _in_place_order(places)
			and places == ["B3", "Drawer 1", "drawer 2", "drawer 3", "drawer 3", "drawer 4", "drawer 10", "tray", ""]
			and named == 8)
		await _shot("partplaces_parts_list")
		by.select(0)
		by.item_selected.emit(0)
	_main.call("_toggle_parts")

	print("\n6. in the booklet")
	var html: String = await _booklet()
	var maker_lots: Array = _last_lots
	var said_places: int = 0
	var wrong_places: Array = []
	for lot: Booklet.Lot in maker_lots:
		var expect: String = str(want.get(Collection.key_of(lot.part_id, _code_of(lot), _library), ""))
		if lot.place != expect:
			wrong_places.append("%s %s: %s" % [lot.part_id, lot.colour, lot.place])
		if not lot.place.is_empty():
			said_places += 1
	_check("each step's parts box names each part's place: %d of %d lots%s, \"from drawer 3\" drawn" % [said_places,
		maker_lots.size(), "" if wrong_places.is_empty() else " (wrong: " + ", ".join(wrong_places) + ")"],
		wrong_places.is_empty() and said_places == 8 and maker_lots.size() == 9 and html.contains(">from drawer 3</div>")
		and html.count("class=\"t e pl\"") == 8)
	_dialog.call("open", "own")
	await _settled()
	_dialog.call("open_places")
	await _settled()
	var telling: CheckBox = (_dialog.call("controls_by_name") as Dictionary)["collection_places_booklet"]
	telling.button_pressed = false
	_dialog.call("hide")
	html = await _booklet()
	_check("Say where each is kept turned off: no part's place in it", not html.contains("class=\"t e pl\"")
		and _last_lots.all(func(lot: Booklet.Lot) -> bool: return lot.place.is_empty()))
	telling.button_pressed = true
	await _call("clear_model", {})

	print("\n7. an older build")
	var old_code: GDScript = _older_build()
	_check("%s's Collection read from git and compiled" % OLDER, old_code != null)
	if old_code != null:
		var reply: Dictionary = await _http(HTTPClient.METHOD_GET, null)
		var older: Object = (old_code.get("Collection266") as GDScript).call("from_json", reply["body"])
		var its: Dictionary = older.call("to_json")
		var ours: Dictionary = Collection.from_json(reply["body"]).to_json()
		_check("it keeps every set and lot byte for byte, and drops only the places: %s" % ", ".join(its.keys()),
			_same(its["sets"], ours["sets"]) and _same(its["parts"], ours["parts"]) and not its.has("places")
			and ours.has("places"))
		# The copy it writes on this device (CollectionStore._take's way:
		# its to_json and the owner), read here with the account out of reach.
		var kept: Collection = _store.collection
		var written: Dictionary = its.duplicate(true)
		written["owner"] = _store.call("_who")
		var file := FileAccess.open(CollectionStore.where, FileAccess.WRITE)
		file.store_string(JSON.stringify(written))
		file.close()
		var api: String = OS.get_environment("BRICKWORKS_API")
		OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
		var why: String = await _store.load_collection()
		_dialog.call("open", "own")
		await _settled()
		_dialog.call("open_places")
		await _settled()
		var note: String = (_dialog.get("_places_note") as Label).text
		_drawn.append(note)
		_check("...its copy on this device, read with the account out of reach (\"%s\"), is said to lack them: \"%s\"" % [
			why.left(60), note.left(90)], _store.offline and note.contains("not in the copy on this device")
			and _store.collection.places.is_empty() and _same(_store.collection.parts, kept.parts)
			and _same(_store.collection.sets, kept.sets) and CollectionStore.places.is_empty())
		await _shot("partplaces_older_copy")
		OS.set_environment("BRICKWORKS_API", api)
		await _store.load_collection()
		await _settled()
		_check("...and they come back from the account: %d" % _store.collection.places.size(),
			not _store.offline and _same(_store.collection.places, want))
		var put_reply: Dictionary = await _http(HTTPClient.METHOD_PUT, {"sets": its["sets"], "parts": its["parts"]})
		var after_old: Dictionary = await _account_now()
		_check("its whole copy PUT (an older app's Remove a set): %d, every place kept" % int(put_reply["code"]),
			int(put_reply["code"]) == 200 and _same(after_old["places"], want))

	print("\n8. two tabs at once")
	var tab := CollectionStore.new()
	tab.library = _library
	tab.account = _account
	root.add_child(tab)
	await tab.load_collection()
	await _store.load_collection()
	var a: String = only_set[5]
	var b: String = Collection.key_of("3020", 0, _library)
	var results: Array = await _together(_store, [_asked(a, "", "tab A")], tab, [_asked(b, "drawer 10", "tab B")])
	want[a] = "tab A"
	want[b] = "tab B"
	_check("two parts from two tabs, together: %s and %s, both kept" % [results[0]["kind"], results[1]["kind"]],
		results[0]["kind"] == CollectionStore.DONE and results[1]["kind"] == CollectionStore.DONE
		and _same((await _account_now())["places"], want))
	await tab.load_collection()
	await _store.load_collection()
	var c: String = Collection.key_of("3001", 4, _library)
	results = await _together(_store, [_asked(c, "drawer 3", "tab C")], tab, [_asked(c, "drawer 3", "tab D")])
	var kept_c: String = str((await _account_now())["places"].get(c, ""))
	var kinds: Array = [results[0]["kind"], results[1]["kind"]]
	kinds.sort()
	var lost: CollectionStore = _store if results[0]["kind"] == CollectionStore.CONFLICT else tab
	_check("one part from both, from drawer 3: \"%s\" kept, the other told (%s), shown it as it is now" % [kept_c,
		", ".join(kinds)], kinds == [CollectionStore.CONFLICT, CollectionStore.DONE] and kept_c in ["tab C", "tab D"]
		and str(lost.collection.places.get(c, "")) == kept_c)
	want[c] = kept_c
	tab.queue_free()
	await _store.load_collection()

	print("\n9. the CSV")
	var folder: String = OS.get_user_data_dir().path_join("partplaces_files")
	DirAccess.make_dir_recursive_absolute(folder)
	Download.folder = folder
	_dialog.call("open", "own")
	await _settled()
	_dialog.call("open_places")
	await _settled()
	var save: Button = (_dialog.call("controls_by_name") as Dictionary)["collection_places_save"]
	_drawn.append(save.text)
	_drawn.append(save.tooltip_text)
	save.pressed.emit()
	var path: String = folder.path_join("brickworks_places.csv")
	await _until(func() -> bool: return FileAccess.file_exists(path), 5000)
	var text: String = FileAccess.get_file_as_string(path)
	_check("Save places as CSV wrote %s: %d lines, \"%s\"" % [path.get_file(), text.split("\r\n", false).size(),
		text.get_slice("\r\n", 1)], text.begins_with("Part,Colour,Colour name,Place\r\n")
		and text.split("\r\n", false).size() == want.size() + 1 and text.contains("3001,4,Red,%s\r\n" % want[c]))
	put = (_dialog.call("controls_by_name") as Dictionary)["collection_places_put"]
	put.text = ""
	put.text_changed.emit("")
	go = (_dialog.call("controls_by_name") as Dictionary)["collection_places_put_go"]
	_drawn.append(go.text)
	go.pressed.emit()
	await _changed()
	await _settled()
	_drawn.append(str((_dialog.get("_status") as Label).text))
	_check("Take the %d shown off their places: none left at the account" % want.size(),
		((await _account_now())["places"] as Dictionary).is_empty())
	var back: Dictionary = await _dialog.call("read_places", text)
	await _settled()
	_drawn.append(str((_dialog.get("_status") as Label).text))
	_check("Places CSV… read back: %d set, every place as it was" % int(back.get("set", 0)),
		_same((await _account_now())["places"], want) and (back.get("left", []) as PackedStringArray).is_empty())
	var odd: String = "Part,Color,Location\n3001,1,drawer 9\n3020,banana,x\n3020,0,=SUM(A1)\n"
	back = await _dialog.call("read_places", odd)
	await _settled()
	var line: String = str((_dialog.get("_status") as Label).text)
	_drawn.append(line)
	want[Collection.key_of("3020", 0, _library)] = "=SUM(A1)"
	_check("a CSV with a part not held, a colour that is none, a formula: \"%s\"" % line.left(170),
		_same((await _account_now())["places"], want) and line.contains("1 part not in your collection")
		and line.contains("line 3") and int(back.get("set", 0)) == 1)
	_store.collection.places = (await _account_now())["places"]
	var again: String = _store.collection.places_csv(_library)
	_check("...written again as '=SUM(A1), so no spreadsheet runs it, and read as it was",
		again.contains(",'=SUM(A1)\r\n") and (Collection.read_places_csv(again, _library)["places"] as Array).any(
			func(one: Dictionary) -> bool: return one["place"] == "=SUM(A1)"))
	Download.folder = ""
	await _store.load_collection()

	print("\n10. a place on a lot the collection doesn't own")
	var refused: Dictionary = await _store.set_places([{"part": "3001", "colour": 1, "was": "", "place": "drawer 9"}])
	_check("the store's change: %s, \"%s\"" % [refused["kind"], str(refused["said"]).left(120)],
		refused["kind"] == CollectionStore.CONFLICT and str(refused["said"]).contains("not in your collection")
		and _same((await _account_now())["places"], want))

	print("\n11. Start over")
	var cleared: Dictionary = await _store.clear()
	_check("Start over: %s, every place forgotten" % cleared["kind"], cleared["kind"] == CollectionStore.DONE
		and ((await _account_now())["places"] as Dictionary).is_empty() and CollectionStore.places.is_empty())

	print("\n12. the words in de, fr and es")
	_languages()


# -- the window -----------------------------------------------------------------------


## The page's own lines, for the languages.
func _drawn_page() -> void:
	var page: Dictionary = _dialog.call("controls_by_name")
	for name: String in ["collection_places_back", "collection_places_put_go", "collection_places_save",
			"collection_places_read", "collection_places_booklet"]:
		var control: Variant = page.get(name)
		if control is Button:
			_drawn.append((control as Button).text)
			_drawn.append((control as Button).tooltip_text)
	var sort: OptionButton = page.get("collection_places_sort")
	if sort != null:
		_drawn.append(sort.get_item_text(0))
		_drawn.append(sort.get_item_text(1))
		_drawn.append(sort.tooltip_text)
	var find: LineEdit = page.get("collection_places_find")
	if find != null:
		_drawn.append(find.placeholder_text)
	_drawn.append((_dialog.get("_places_title") as Label).text)
	_drawn.append((_dialog.get("_places_note") as Label).text)
	var rows: Array = _dialog.call("place_rows")
	if not rows.is_empty():
		var field: Control = (rows[0] as HBoxContainer).get_child((rows[0] as HBoxContainer).get_child_count() - 1)
		_drawn.append(field.tooltip_text)
	_drawn.append("kept in")


## The row of [param key] on Where it's kept, or null.
func _row_of(key: String) -> HBoxContainer:
	for row: HBoxContainer in _dialog.call("place_rows"):
		if str((row.get_meta("place") as Dictionary)["key"]) == key:
			return row
	return null


## Whether [param order] is as a walk round the places takes them.
static func _in_place_order(order: Array) -> bool:
	for n: int in range(1, order.size()):
		if Collection.place_less(str(order[n]), str(order[n - 1])):
			return false
	return not order.is_empty()


## [param order]'s places, each run said once with its count.
static func _runs(order: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var at: int = 0
	while at < order.size():
		var to: int = at
		while to < order.size() and order[to] == order[at]:
			to += 1
		out.append("%s x%d" % [str(order[at]) if not str(order[at]).is_empty() else "none", to - at])
		at = to
	return out


## {part, colour, was, place} for [param key].
static func _asked(key: String, was: String, place: String) -> Dictionary:
	return {"part": Collection.part_of(key), "colour": Collection.colour_of(key), "was": was, "place": place}


## [param first]'s places from [param one] and [param second]'s from
## [param two], sent together, as two tabs would: both answers.
func _together(one: CollectionStore, first: Array, two: CollectionStore, second: Array) -> Array:
	var answers: Array = [null, null]
	var send := func(store: CollectionStore, asked: Array, at: int) -> void:
		answers[at] = await store.set_places(asked)
	send.call(one, first, 0)
	send.call(two, second, 1)
	await _until(func() -> bool: return answers[0] != null and answers[1] != null, 30000)
	return answers.map(func(answer: Variant) -> Dictionary:
		return answer if answer is Dictionary else {"kind": "none", "said": "no answer in 30 s"})


## The booklet of the model in the window, as Make instructions makes it.
var _last_lots: Array = []


func _booklet() -> String:
	var maker := BookletMaker.new()
	maker.library = _library
	maker.px_per_mm = 2.5
	root.add_child(maker)
	var html: String = await maker.make(_main.get("_world"), {}, "Placed")
	_last_lots = []
	for page: Booklet.Page in maker.document.pages:
		for entry: Booklet.Entry in page.entries:
			_last_lots.append_array(entry.lots)
	maker.queue_free()
	return html


## A booklet lot's LDraw colour, from its key ("3001:4").
static func _code_of(lot: Booklet.Lot) -> int:
	return int(lot.key.get_slice(":", 1))


## A tower of [param bricks] ([part, colour] each), stacked from one corner.
func _tower(bricks: Array) -> Array:
	var out: Array = []
	var y: int = 0
	for one: Array in bricks:
		out.append({"part": one[0], "color": one[1], "x": 0, "y": y, "z": 0, "rot": 0})
		var info: PartLibrary.PartInfo = _library.parts.get(str(one[0]))
		y += 1 if info != null and (info.name.begins_with("Plate") or info.name.begins_with("Tile")) else 3
	return out


# -- an older build -------------------------------------------------------------------


## The build out there's Collection, read from git and compiled as an inner
## class (Collection266), so it takes no global class's name.
func _older_build() -> GDScript:
	var out: Array = []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "show",
			"%s:src/collection/collection.gd" % OLDER], out) != 0 or out.is_empty():
		return null
	var renamed := RegEx.create_from_string("\\bCollection\\b")
	var body: PackedStringArray = []
	var head: String = ""
	for line: String in renamed.sub(str(out[0]), "Collection266", true).split("\n"):
		if line.begins_with("class_name "):
			continue
		if line.begins_with("extends "):
			head = "class Collection266 %s:" % line
			continue
		body.append("\t" + line if not line.is_empty() else "")
	var script := GDScript.new()
	script.source_code = "extends RefCounted\n" + head + "\n" + "\n".join(body) + "\n"
	return script if script.reload() == OK else null


# -- the words ------------------------------------------------------------------------


## Every new line drawn, in de, fr and es: each found, nothing of it kept in
## English but a part's number and a place as the person typed it (in “”).
func _languages() -> void:
	var lines := PackedStringArray()
	for text: String in _drawn:
		for line: String in text.split("\n", false):
			if not line.strip_edges().is_empty() and lines.find(line) < 0:
				lines.append(line)
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var missing: Array = []
		for english: String in lines:
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				var word: String = str(w).strip_edges()
				if _number.search(word) != null:
					return false
				var rest: String = word
				for mark: String in "0123456789½¼¾−-.,:×() ":
					rest = rest.replace(mark, "")
				return not rest.is_empty())
			if Language.says(english).is_empty() or not kept.is_empty():
				missing.append("\"%s\"%s" % [english.left(90), " (kept " + str(kept) + ")" if not kept.is_empty() else ""])
		print("  %s: %s" % [code, TranslationServer.translate(lines[0]) if not lines.is_empty() else ""])
		_check("%s: each of the %d lines reads in the language%s" % [code, lines.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty() and lines.size() >= 20)
	Language.apply("en")


# -- what is kept ---------------------------------------------------------------------


## This device's copy's sets and lots, as text.
func _device_rest() -> String:
	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(CollectionStore.where))
	if not kept is Dictionary:
		return ""
	return JSON.stringify({"sets": kept.get("sets", []), "parts": kept.get("parts", [])}, "", true)


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
