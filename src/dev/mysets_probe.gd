## The sets a person owns, as they really are (APP_UX6 #6, mysets): a set
## added from a photo of its box, a set kept with its missing parts, and a
## minifigure from its photo.
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9961 &
##   BRICKWORKS_API=http://127.0.0.1:9961 \
##     godot --path . --resolution 1280x720 --script src/dev/mysets_probe.gd
##   ... -- --shots=DIR   the photo's answers, the set's missing parts, Closest
##                        to whole, What do I need? for the set and the
##                        minifigures, pictured there
##   (tools/relay_probe.sh mysets runs it on a relay of its own;
##   PROBE_SIZE=1400x900 for the larger window)
##
## On the real scene, signed in as a throwaway account at a Resend test
## address (made with a password, no code redeemed), through
## api/collection.js on the relay and the real database, deleted at the end.
## Brickognize is a stand-in on a port of this probe's own (9962), answering
## /predict/sets/ and /predict/figs/ as the real one does. The real one was
## asked with ten box photos from Wikimedia Commons, nobody's own
## (bench/results/mysets-2026-11-07/live_photos.py: 7 of the 8 cropped to
## the box found, each first; 2 of 10 whole scenes of box, bags and parts).
##
##   1. an older collection, made the old ways: a set typed, a Rebrickable
##      parts CSV, a BrickLink XML and a session's lot
##   2. a box photo's set added in 3 actions: Photo… beside Add sets, the
##      photo chosen, the set pressed among the top three offered (said
##      first, once, as the bin's camera is: a fourth press the first time
##      ever); asked of /predict/sets/ and /predict/figs/ at once, as a
##      JPEG, the top three; 7140-1 named as its inventory names it
##   3. 7140-1 marked with 12 parts missing on its own page, a count typed
##      in each row: kept on 7140-1 alone; the pool 12 pieces less, those
##      12 lots one less each; the open 7140-1 model's What do I need? 12
##      pieces more, exactly those
##   4. What do I need? for 7140-1 (Closest to whole's What it needs) lists
##      exactly those 12, and its wanted list is those 12
##   5. 5 of them added as loose parts in the Loose parts row: What do I
##      need? for 7140-1 lists the other 7, Closest to whole says 7 of 285
##   6. Closest to whole by how much is missing: 6020-1 with 3 missing
##      before 7140-1's 7; All missing puts it after; None missing takes it
##      off the list, kept as a set with nothing marked
##   7. a minifigure's photo: offered as a minifigure, kept by BrickLink's
##      number and name under Minifigures, the pool unchanged; Remove
##   8. kept over a restart (the copy on this device)
##   9. the builds out there (rel-m268's collection code, live on the web,
##      and desktop 0.19.0's) read every set and lot, and their Remove a
##      set (a PUT of the whole collection) keeps 7140-1's marks
##  10. None missing, 7140-1 and the 5 lots taken out: the older collection
##      lot for lot as it was
##
## Every control of the photo's row, the set's page and What do I need?
## inside the dialog's sides. On pre261 there is no Photo… for sets, no
## marks and no "missing" at the account: 2 to 10 fail with words. Writes
## nothing in the app's own directory: the copy on this device and the
## session go to the probe's own data folder (probe.sh's XDG_DATA_HOME).
extends SceneTree

## The stand-in Brickognize's port: one of the unit's own (9960-9969).
const STUB := 9962

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
## The dialog, untyped: its calls are looked up as they are made, so a build
## without them fails a check rather than the script.
var _dialog: Node
var _store: CollectionStore
var _server := TCPServer.new()
var _peers: Array[StreamPeerTCP] = []
var _heard: Dictionary = {}
## What the stand-in answers, by kind ("sets", "figs"): its items.
var _answers: Dictionary = {"sets": [], "figs": []}
## What it was asked: [{"kind", "query", "jpeg"}].
var _asked: Array = []
var _photo_path: String = ""


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
		print("mysets probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % api)
		quit(1)
		return
	if _server.listen(STUB, "127.0.0.1") != OK:
		print("mysets probe: FAIL  port %d is taken" % STUB)
		quit(1)
		return
	Account.where = "user://probe_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_collection.json"
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
	_account = _main.get("_account")
	while _account.state == Account.State.CHECKING:
		await _account.changed
	_email = SignInHelper.throwaway("mysets")
	var problem: String = await _sign_in(_account, _email)
	_check("signed in as a throwaway account: %s" % (problem if not problem.is_empty() else _email),
		problem.is_empty() and _account.signed_in())
	if not _account.signed_in():
		quit(1)
		return
	await _changed()
	# A photo as the chooser hands one over: a box's worth of colour.
	var photo := Image.create(800, 560, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.1, 0.2, 0.6))
	photo.fill_rect(Rect2i(80, 60, 640, 440), Color(0.9, 0.85, 0.2))
	_photo_path = ProjectSettings.globalize_path("user://mysets_box.jpg")
	photo.save_jpg(_photo_path)
	await _steps()
	_server.stop()
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	print("\nmysets probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	print("\n1. an older collection, made the old ways")
	for one: Dictionary in [
			{"from": "sets", "text": "6020-1"},
			{"from": "rebrickable_csv", "text": "Part,Color,Quantity\n3001,4,10\n3641,0,2\n"},
			{"from": "bricklink_xml", "text": "<INVENTORY><ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>4624</ITEMID>"
				+ "<COLOR>9</COLOR><MINQTY>4</MINQTY></ITEM></INVENTORY>"}]:
		var got: Dictionary = await _store.add(one)
		_check("%s imported%s" % [one["from"], "" if str(got["error"]).is_empty() else ": " + str(got["error"])],
			str(got["error"]).is_empty())
	await _store.change_lots([{"part": "3005", "colour": 1, "qty": 4, "by": "Claude", "chat": "probe-mysets"}])
	var before: Dictionary = _kept()
	_check("one set and four lots, one a session's: %s" % JSON.stringify(before["parts"]),
		(before["sets"] as Array).size() == 1 and (before["parts"] as Array).size() == 4)

	print("\n2. a box photo's set added in 3 actions")
	var made: bool = _dialog.has_method("ask_set_photo") and _dialog.has_method("set_eyes")
	_dialog.call("open", "own")
	await _changed()
	var controls: Dictionary = _dialog.call("controls_by_name")
	var camera: Button = controls.get("collection_sets_photo")
	_check("What I own has Photo… beside Add sets", made and camera != null
		and camera.get_parent() == (controls["collection_add_sets"] as Button).get_parent())
	if not made or camera == null:
		_check("nothing more can be checked without it", false)
		return
	var eyes: Dictionary = _dialog.call("set_eyes")
	for kind: String in eyes:
		(eyes[kind] as Brickognize).url = "http://127.0.0.1:%d/predict/%s/" % [STUB, kind]
	_answers = {"sets": [_item("set", "7140-1", "X-wing", 0.83), _item("set", "9493-1", "X-wing Starfighter", 0.52),
		_item("set", "6823-1", "Surface Transport", 0.37)], "figs": [_item("fig", "cty0001", "Police officer", 0.31)]}
	ShellPrefs.put("photo_told", false)
	camera.pressed.emit()
	await _frames(3)
	var telling: ConfirmationDialog = _dialog.get("_set_telling")
	_check("the first press ever says the photo goes to Brickognize, a third party, and sends nothing",
		telling != null and telling.visible and telling.dialog_text.contains("Brickognize")
		and telling.dialog_text.contains("third party") and _asked.is_empty())
	if telling != null:
		telling.get_cancel_button().pressed.emit()
	await _frames(3)
	_check("...cancelled, nothing is asked for and nothing sent", not _picker_open() and _asked.is_empty())
	# Told once, as anyone who has used the bin's camera has been: the rest
	# is counted from here.
	ShellPrefs.put("photo_told", true)
	var actions: int = 0
	camera.pressed.emit()
	actions += 1
	await _frames(3)
	_check("Photo… opens the chooser at once", _picker_open())
	await _choose_photo()
	actions += 1
	var offered: Array = await _offered()
	var shown: String = ", ".join(offered.map(func(one: Dictionary) -> String:
		return "%s %s %d%%" % [one["number"], one["name"], roundi(100.0 * float(one["score"]))]))
	var kinds: Array = _asked.map(func(one: Dictionary) -> String: return str(one["kind"]))
	kinds.sort()
	var asked_right: bool = kinds == ["figs", "sets"]
	for one: Dictionary in _asked:
		asked_right = asked_right and bool(one["jpeg"]) and str(one["query"]).contains("top_k_items=3") \
			and not str(one["query"]).contains("predict_color")
	_check("asked of /predict/sets/ and /predict/figs/ at once, each once, as a JPEG, the top 3, no colour: %s"
		% JSON.stringify(_asked), asked_right)
	_check("the top three offered, most likely first, named as the set's inventory names it (a stray minifigure "
		+ "at 31%% passed over): %s" % shown,
		offered.size() == 3 and str(offered[0]["number"]) == "7140-1"
		and str(offered[0]["name"]) == "X-wing Fighter (1999)" and int(offered[0]["pieces"]) == 285
		and str(offered[1]["number"]) == "9493-1" and str(offered[2]["number"]) == "6823-1")
	controls = _dialog.call("controls_by_name")
	var first: Button = controls.get("collection_sets_found_0")
	_check("...each a button on What I own: “%s”" % (first.text if first != null else ""),
		first != null and first.is_visible_in_tree() and first.text.begins_with("7140-1 X-wing Fighter (1999)")
		and first.text.ends_with("83%"))
	_in_the_dialog("the photo's answers")
	await _shot("mysets_photo")
	if first != null:
		first.pressed.emit()
		actions += 1
	await _settled()
	var with_set: Dictionary = _kept()
	var added: Dictionary = _set_of(with_set, "7140-1")
	_check("7140-1 added in %d actions (a press, the photo, the set), the person's own" % actions,
		actions == 3 and str(added.get("src", "")) == "hand" and int(added.get("qty", 0)) == 1)
	_check("...the older collection's set and lots as they were",
		_same(with_set["parts"], before["parts"]) and _same(_without_set(with_set, "7140-1"), before["sets"]))
	_check("...and the answers put away", (_dialog.call("offered") as Array).is_empty())

	print("\n3. 7140-1 marked with 12 parts missing")
	var models: ModelStore = _main.get("_store")
	_main.call("clear_model")
	await _frames(10)
	var opened: Dictionary = await models.open_text_fetched(
		FileAccess.get_file_as_string("res://vendor/omr/files/7140-1.mpd"), "7140-1 X-wing Fighter")
	(_main.get("_bar") as ModelBar).opened.emit(int(opened["placed"]))
	await _frames(20)
	var model_needs: Dictionary = _needs()
	var whole_pool: Dictionary = _store.on_hand.duplicate()
	var whole_short: Dictionary = _short_by_key(model_needs)
	var twelve: Array = _twelve(model_needs, whole_pool)
	_check("the 7140-1 model is open (%d parts); 12 of the set's lots that it uses every piece of, held nowhere "
		% int(opened["placed"]) + "else: %s" % _named(twelve), int(opened["placed"]) > 200 and twelve.size() == 12)
	_dialog.call("_show", "own")
	await _frames(5)
	controls = _dialog.call("controls_by_name")
	var mark: Button = controls.get("collection_mark_7140-1")
	_check("7140-1's row has Missing parts…: “%s”" % (mark.text if mark != null else ""),
		mark != null and mark.text == "Missing parts…")
	if mark == null:
		return
	mark.pressed.emit()
	await _frames(5)
	var rows: Array = _dialog.call("mark_rows")
	_check("its page lists the set's 124 lots, each with how many are missing (%d)" % rows.size(), rows.size() == 124)
	var typed: int = 0
	for lot: Dictionary in twelve:
		var row: HBoxContainer = _mark_row(lot)
		if row != null:
			(row.get_child(0) as SpinBox).value = 1
			typed += 1
	await _marks_sent()
	var marked: Dictionary = _kept()
	var missing: Array = _set_of(marked, "7140-1").get("missing", [])
	var ones: bool = missing.all(func(held: Dictionary) -> bool: return int(held["qty"]) == 1)
	_check("12 counts typed (%d), kept on 7140-1 as 12 lots of 1: %s" % [typed, JSON.stringify(missing)],
		typed == 12 and missing.size() == 12 and ones and _same_keys(missing, twelve))
	_check("...nothing else in the collection moved", _same(marked["parts"], with_set["parts"])
		and _same(_without_set(marked, "7140-1"), _without_set(with_set, "7140-1")))
	var title: String = (_dialog.get("_set_title") as Label).text
	_check("...and its page says so: “%s”" % title, title == "7140-1 X-wing Fighter: 12 of 285 pieces missing")
	_in_the_dialog("the set's page")
	await _shot("mysets_marked")
	var fewer: int = _pieces_of(whole_pool) - _pieces_of(_store.on_hand)
	var each: bool = true
	for lot: Dictionary in twelve:
		var key: String = Collection.key_of(str(lot["part"]), int(lot["colour"]), _library)
		each = each and int(_store.on_hand.get(key, 0)) == int(whole_pool.get(key, 0)) - 1
	_check("only what is there is counted: the pool %d pieces less, each of the 12 lots one less" % fewer,
		fewer == 12 and each)
	var marked_short: Dictionary = _short_by_key(model_needs)
	var grew: Array = _grown(whole_short, marked_short)
	_check("What do I need? for the open 7140-1 model: %d pieces more, in exactly the 12 lots"
		% (_pieces_of(marked_short) - _pieces_of(whole_short)),
		_pieces_of(marked_short) - _pieces_of(whole_short) == 12 and _same_keys(grew, twelve))

	print("\n4. What do I need? for 7140-1")
	_dialog.call("_show", "own")
	await _frames(5)
	_check("Closest to whole lists it: %s" % str(_dialog.call("closest_listed")),
		_dialog.call("closest_listed") == PackedStringArray(["7140-1"]))
	controls = _dialog.call("controls_by_name")
	var needs_button: Button = controls.get("collection_needs_7140-1")
	if needs_button != null:
		needs_button.pressed.emit()
	await _frames(10)
	var listed: Dictionary = _dialog.call("need_listed")
	_check("What it needs: What do I need? for 7140-1 lists exactly those 12, 1 of each: %s"
		% JSON.stringify(listed), str(listed["set"]) == "7140-1" and (listed["rows"] as Array).size() == 12
		and _same_keys(listed["rows"], twelve)
		and (listed["rows"] as Array).all(func(row: Dictionary) -> bool: return int(row["short"]) == 1))
	var heading: String = (_dialog.get("_need_heading") as Label).text
	_check("...and says so: “%s”" % heading, heading.contains("Missing: 12 pieces in 12 lots"))
	var wanted: Inventory = Collection.shortfall_stock(_dialog.get("_need_stock"), _dialog.get("_need_plan"), _library)
	_check("...its wanted list is those 12 pieces in 12 lots (%d in %d)" % [wanted.pieces, wanted.lots.size()],
		wanted.pieces == 12 and wanted.lots.size() == 12)
	_in_the_dialog("What do I need? for a set")
	await _shot("mysets_need")

	print("\n5. 5 of them found in the tub, added as loose parts")
	_dialog.call("_show", "own")
	await _frames(5)
	var five: Array = []
	for lot: Dictionary in twelve:
		if five.size() >= 5:
			break
		# Its number typed in the row's search, its colour chosen, Add.
		var field: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_loose_search"]
		field.text = str(lot["part"])
		field.text_submitted.emit(field.text)
		await _frames(2)
		var part: String = _library.resolve(str(lot["part"]))
		if str((_dialog.call("loose_chosen") as Dictionary)["part"]) != part:
			_dialog.call("choose_loose", part, -1, false)
		_dialog.call("_pick_colour", int(lot["colour"]))
		var chosen: Dictionary = _dialog.call("loose_chosen")
		if str(chosen["part"]) != part or int(chosen["colour"]) != int(lot["colour"]):
			print("     %s/%d: the row has %s/%d" % [lot["part"], lot["colour"], chosen["part"], chosen["colour"]])
			continue
		((_dialog.call("controls_by_name") as Dictionary)["collection_loose_add"] as Button).pressed.emit()
		await _changed()
		await _settled()
		five.append(lot)
	var loose_ones: bool = true
	for lot: Dictionary in five:
		var held: Dictionary = _store.collection.lot_of(_library.resolve(str(lot["part"])), int(lot["colour"]), "", "", "hand")
		loose_ones = loose_ones and int(held.get("qty", 0)) == 1
	_check("5 of the 12 added in the Loose parts row, each 1 in its colour: %s" % _named(five),
		five.size() == 5 and loose_ones)
	_dialog.call("need_for_set", _set_of(_kept(), "7140-1"))
	await _frames(10)
	listed = _dialog.call("need_listed")
	var seven: Array = twelve.filter(func(lot: Dictionary) -> bool: return not five.has(lot))
	_check("What do I need? for 7140-1 now lists the other 7, none of the 5: %s" % JSON.stringify(listed["rows"]),
		(listed["rows"] as Array).size() == 7 and _same_keys(listed["rows"], seven))
	heading = (_dialog.get("_need_heading") as Label).text
	_check("...and says the loose parts make up 5 of the 12: “%s”" % heading,
		heading.contains("Missing: 7 pieces in 7 lots") and heading.contains("make up 5 of the 12 marked"))
	var loose_short: Dictionary = _short_by_key(model_needs)
	_check("...and the open model's What do I need? 5 pieces fewer (%d to %d)"
		% [_pieces_of(marked_short), _pieces_of(loose_short)], _pieces_of(marked_short) - _pieces_of(loose_short) == 5)
	await _shot("mysets_need_seven")

	print("\n6. Closest to whole, by how much is missing")
	_dialog.call("_show", "own")
	await _frames(5)
	controls = _dialog.call("controls_by_name")
	var shop: Button = controls.get("collection_mark_6020-1")
	if shop != null:
		shop.pressed.emit()
	await _frames(5)
	var three: int = 0
	for row: HBoxContainer in _dialog.call("mark_rows"):
		var lot: Dictionary = row.get_meta("mark")
		var key: String = Collection.key_of(str(lot["part"]), int(lot["colour"]), _library)
		# Three no loose lot makes up.
		if three < 3 and not _loose_has(key):
			(row.get_child(0) as SpinBox).value = 1
			three += 1
	await _marks_sent()
	_dialog.call("_show", "own")
	await _frames(5)
	var order: PackedStringArray = _dialog.call("closest_listed")
	_check("6020-1 with 3 missing comes before 7140-1 with 7: %s" % str(order),
		three == 3 and order == PackedStringArray(["6020-1", "7140-1"]))
	await _shot("mysets_closest")
	(_dialog.call("controls_by_name")["collection_mark_6020-1"] as Button).pressed.emit()
	await _frames(5)
	await _dialog.call("mark_all", true)
	await _settled()
	_dialog.call("_show", "own")
	await _frames(5)
	var shop_whole: Dictionary = _store.collection.wholeness(_set_of(_kept(), "6020-1"), _store.records["6020-1"], _library)
	order = _dialog.call("closest_listed")
	_check("All missing: 6020-1 short %d of %d, after 7140-1: %s" % [int(shop_whole["short"]), int(shop_whole["pieces"]), str(order)],
		int(shop_whole["marked"]) == int(shop_whole["pieces"]) and order == PackedStringArray(["7140-1", "6020-1"]))
	(_dialog.call("controls_by_name")["collection_mark_6020-1"] as Button).pressed.emit()
	await _frames(5)
	await _dialog.call("mark_all", false)
	await _settled()
	_dialog.call("_show", "own")
	await _frames(5)
	order = _dialog.call("closest_listed")
	_check("None missing: off the list (%s), kept as a set with nothing marked: %s" % [str(order),
		JSON.stringify(_set_of(_kept(), "6020-1"))], order == PackedStringArray(["7140-1"])
		and _same(_set_of(_kept(), "6020-1"), _set_of(before, "6020-1")))

	print("\n7. a minifigure from its photo")
	var pool_before: int = _store.pieces_on_hand()
	_answers = {"sets": [_item("set", "10179-1", "Millennium Falcon", 0.31)],
		"figs": [_item("fig", "sw0001a", "Luke Skywalker (Tatooine)", 0.71), _item("fig", "sw0002", "Darth Vader", 0.44)]}
	_asked = []
	camera.pressed.emit()
	await _frames(3)
	await _choose_photo()
	offered = await _offered()
	_check("a minifigure's photo offers it first, as a minifigure: %s" % JSON.stringify(offered.map(
		func(one: Dictionary) -> String: return "%s %s %s" % [one["kind"], one["number"], one["name"]])),
		offered.size() == 3 and offered[0]["kind"] == "fig" and str(offered[0]["number"]) == "sw0001a"
		and offered[2]["kind"] == "set")
	controls = _dialog.call("controls_by_name")
	first = controls.get("collection_sets_found_0")
	_check("...“%s”" % (first.text if first != null else ""), first != null
		and first.text.begins_with("Minifigure sw0001a Luke Skywalker (Tatooine)"))
	if first != null:
		first.pressed.emit()
	await _settled()
	var fig: Dictionary = _set_of(_kept(), "sw0001a")
	_check("kept by BrickLink's number and name, as a minifigure: %s" % JSON.stringify(fig),
		fig.get("fig") == true and str(fig.get("name", "")) == "Luke Skywalker (Tatooine)")
	_dialog.call("_show", "own")
	await _frames(5)
	var fig_row: HBoxContainer = null
	for child: Node in (_dialog.get("_own_rows") as Node).get_children():
		if child.has_meta("fig"):
			fig_row = child
	_check("...listed under Minifigures, the pool unchanged (%d pieces)" % _store.pieces_on_hand(),
		fig_row != null and _text_of(_dialog.get("_own_rows")).contains("Minifigures")
		and _store.pieces_on_hand() == pool_before and not _store.collection.unknown_sets.has("sw0001a"))
	await _shot("mysets_minifigure")
	if fig_row != null:
		(fig_row.get_child(fig_row.get_child_count() - 1) as Button).pressed.emit()
	await _settled()
	_check("...Remove takes it out, nothing else moving", _set_of(_kept(), "sw0001a").is_empty()
		and _store.pieces_on_hand() == pool_before)

	print("\n8. kept over a restart")
	var restarted := CollectionStore.new()
	restarted.library = _library
	root.add_child(restarted)
	await restarted.refresh_pool()
	_check("a restart reads the copy on this device: 7140-1's 12 marks, the same pool (%d pieces)"
		% restarted.pieces_on_hand(), (_set_of(_kept_of(restarted), "7140-1").get("missing", []) as Array).size() == 12
		and restarted.pieces_on_hand() == _store.pieces_on_hand())
	restarted.queue_free()

	print("\n9. the builds out there")
	for build: String in OLD_BUILDS:
		await _older_build(build)

	print("\n10. back to the older collection")
	_dialog.call("mark_set", _set_of(_kept(), "7140-1"))
	await _frames(5)
	await _dialog.call("mark_all", false)
	await _settled()
	_check("None missing: 7140-1 kept with nothing marked: %s" % JSON.stringify(_set_of(_kept(), "7140-1")),
		not _set_of(_kept(), "7140-1").has("missing"))
	await _dialog.call("_remove_set", _set_of(_kept(), "7140-1"))
	for lot: Dictionary in five:
		var held: Dictionary = _store.collection.lot_of(_library.resolve(str(lot["part"])), int(lot["colour"]), "", "", "hand")
		if not held.is_empty():
			await _dialog.call("remove_lot", held)
	await _settled()
	_check("7140-1 and the 5 lots taken out: the older collection lot for lot as it was", _same(_kept(), before))


# -- the builds out there -----------------------------------------------------------

## The builds whose collection code is still out there: the web's live one
## (rel-m268) and the desktop's (0.19.0). Each Removes a set by a PUT of the
## whole collection as it keeps it.
const OLD_BUILDS := ["e309dec8", "v0.19.0"]


func _older_build(build: String) -> void:
	var old_code: GDScript = _old_build(build)
	_check("%s's Collection and CollectionStore, read from git and compiled" % build, old_code != null)
	if old_code == null:
		return
	var marked: Dictionary = _kept()
	var store_class: GDScript = old_code.get("Store266")
	store_class.set("where", "user://probe_old_collection.json")
	var old: Node = store_class.new()
	old.set("account", _account)
	old.set("library", _library)
	root.add_child(old)
	var said: String = str(await old.call("load_collection"))
	var sets: Array = (old.get("collection") as Object).get("sets")
	var parts: Array = (old.get("collection") as Object).get("parts")
	_check("%s reads every set and lot (%d of %d, %d of %d)%s" % [build, sets.size(), (marked["sets"] as Array).size(),
		parts.size(), (marked["parts"] as Array).size(), "" if said.is_empty() else ": " + said],
		said.is_empty() and sets.size() == (marked["sets"] as Array).size() and parts.size() == (marked["parts"] as Array).size())
	# Its set Remove, as its dialog makes one: the whole collection as it
	# keeps it, PUT, from a copy read now.
	var next: Object = (old_code.get("Collection266") as GDScript).call("from_json",
		(old.get("collection") as Object).call("to_json"))
	next.set("sets", (next.get("sets") as Array).filter(func(entry: Dictionary) -> bool: return str(entry["set"]) != "6020-1"))
	var trouble: String = str(await old.call("put", next))
	await _store.load_collection()
	var less: Dictionary = marked.duplicate(true)
	less["sets"] = (less["sets"] as Array).filter(func(entry: Dictionary) -> bool: return str(entry["set"]) != "6020-1")
	_check("its Remove of 6020-1 takes that set out%s, 7140-1's 12 marks and every lot kept"
		% ("" if trouble.is_empty() else ": " + trouble), trouble.is_empty() and _same(_kept(), less))
	old.queue_free()
	# Back as it was: 6020-1 typed again, at the end, as the person's own.
	await _store.add({"from": "sets", "text": "6020-1", "mode": "add"})
	var back: Dictionary = _kept()
	_check("...6020-1 typed again: the collection as before it, but for where 6020-1 is listed",
		_same(back["parts"], marked["parts"]) and _same(_set_of(back, "6020-1"), _set_of(marked, "6020-1"))
		and _same(_set_of(back, "7140-1"), _set_of(marked, "7140-1")))


## The build's Collection and CollectionStore as it has them, read from git
## and compiled as two inner classes of one script (Collection266, Store266),
## so neither takes a global class's name (mybricks_probe's way).
func _old_build(build: String) -> GDScript:
	var text: String = "extends RefCounted\n"
	var renamed := RegEx.create_from_string("\\bCollection\\b")
	for pair: Array in [["src/collection/collection.gd", "Collection266"], ["src/collection/collection_store.gd", "Store266"]]:
		var out: Array = []
		if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "show",
				"%s:%s" % [build, pair[0]]], out) != 0 or out.is_empty():
			return null
		var head: String = ""
		var body: PackedStringArray = []
		for line: String in renamed.sub(str(out[0]), "Collection266", true).split("\n"):
			if line.begins_with("class_name "):
				continue
			if line.begins_with("extends "):
				head = "class %s %s:" % [pair[1], line]
				continue
			body.append("\t" + line if not line.is_empty() else "")
		text += head + "\n" + "\n".join(body) + "\n"
	var script := GDScript.new()
	script.source_code = text
	return script if script.reload() == OK else null


# -- the photo --------------------------------------------------------------------------

func _picker_open() -> bool:
	var picker: Variant = _dialog.get("_set_photo")
	return picker != null and picker.get("_dialog") != null and (picker.get("_dialog") as FileDialog).visible


## The box photo chosen in the chooser, as a person picks a file.
func _choose_photo() -> void:
	var picker: Variant = _dialog.get("_set_photo")
	if picker == null or picker.get("_dialog") == null:
		return
	var chooser: FileDialog = picker.get("_dialog")
	chooser.hide()
	chooser.file_selected.emit(_photo_path)
	await _frames(2)


## The answers offered once both kinds are in, the stand-in serving.
func _offered() -> Array:
	var waited: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited < 15000:
		_serve()
		var heard: Dictionary = _dialog.get("_set_heard")
		if heard.size() >= 2 and not (_dialog.call("offered") as Array).is_empty():
			break
		await process_frame
	await _frames(3)
	return _dialog.call("offered")


static func _item(type: String, number: String, name: String, score: float) -> Dictionary:
	var named: String = {"set": "S", "fig": "M"}[type]
	return {"id": number, "name": name, "type": type, "score": score, "category": "",
		"img_url": "https://storage.googleapis.com/brickognize-static/thumbnails/v4.0/%s/%s/0.webp" % [type, number],
		"external_sites": [{"name": "bricklink",
			"url": "https://www.bricklink.com/v2/catalog/catalogitem.page?%s=%s" % [named, number]}]}


## The stand-in: each request read whole, then answered with the items of
## the kind its path asks for.
func _serve() -> void:
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		_peers.append(peer)
		_heard[peer] = PackedByteArray()
	for peer: StreamPeerTCP in _peers.duplicate():
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(peer)
			_heard.erase(peer)
			continue
		var heard: PackedByteArray = _heard[peer]
		var waiting: int = peer.get_available_bytes()
		if waiting > 0:
			heard.append_array(peer.get_data(waiting)[1])
			_heard[peer] = heard
		var text: String = heard.get_string_from_ascii()
		var head_end: int = text.find("\r\n\r\n")
		if head_end < 0:
			continue
		var length: int = 0
		for line: String in text.substr(0, head_end).split("\r\n"):
			if line.to_lower().begins_with("content-length:"):
				length = int(line.get_slice(":", 1).strip_edges())
		if heard.size() < head_end + 4 + length:
			continue
		var request: String = text.substr(0, text.find("\r\n"))
		var kind: String = "sets" if request.contains("/predict/sets/") else "figs" if request.contains("/predict/figs/") else ""
		# A JPEG starts FF D8 FF.
		var body: PackedByteArray = heard.slice(head_end + 4)
		var jpeg: bool = false
		for at: int in body.size() - 2:
			if body[at] == 0xFF and body[at + 1] == 0xD8 and body[at + 2] == 0xFF:
				jpeg = true
				break
		_asked.append({"kind": kind, "query": request.get_slice(" ", 1).get_slice("?", 1), "jpeg": jpeg})
		var answer: String = JSON.stringify({"listing_id": "probe", "bounding_box": {}, "items": _answers.get(kind, [])})
		peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\n"
			% answer.to_utf8_buffer().size() + "Connection: close\r\n\r\n" + answer).to_utf8_buffer())
		peer.disconnect_from_host()
		_peers.erase(peer)
		_heard.erase(peer)


# -- the sums -----------------------------------------------------------------------------

func _needs() -> Dictionary:
	var stock: Inventory = Inventory.of(_main.get("_world"), _library, (_main.get("_store") as ModelStore).scenery)
	return Collection.needs_of(stock, _library)


## What is short of the open model now: key -> pieces.
func _short_by_key(needs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in Collection.shortfall(needs, _store.on_hand):
		out[str(row["key"])] = int(row["short"])
	return out


static func _pieces_of(counts: Dictionary) -> int:
	var total: int = 0
	for key: String in counts:
		total += int(counts[key])
	return total


## The keys short by more in [param after] than in [param before], each once
## a piece: [{"part", "colour"}].
static func _grown(before: Dictionary, after: Dictionary) -> Array:
	var out: Array = []
	for key: String in after:
		for _n: int in int(after[key]) - int(before.get(key, 0)):
			out.append({"part": Collection.part_of(key), "colour": Collection.colour_of(key)})
	return out


## Whether [param rows] are [param lots], part and colour, one each, as keys.
func _same_keys(rows: Array, lots: Array) -> bool:
	var a: Array = rows.map(func(row: Dictionary) -> String:
		return Collection.key_of(str(row["part"]), int(row["colour"]), _library))
	var b: Array = lots.map(func(lot: Dictionary) -> String:
		return Collection.key_of(str(lot["part"]), int(lot["colour"]), _library))
	a.sort()
	b.sort()
	return a == b


## 12 of 7140-1's lots the open model uses every piece of, held nowhere else,
## in parts the library has: marking one missing makes the model one short.
func _twelve(needs: Dictionary, pool: Dictionary) -> Array:
	var out: Array = []
	var record: Dictionary = _store.records.get("7140-1", {})
	for row: Variant in record.get("p", []):
		if out.size() >= 12:
			break
		var lot: Array = row
		var key: String = Collection.key_of(str(lot[0]), int(lot[1]), _library)
		var info: PartLibrary.PartInfo = _library.parts.get(_library.resolve(str(lot[0])))
		if info == null or not Collection.ownable(info.id, _library) or Collection.colour_of(key) in [16, 24]:
			continue
		if int(pool.get(key, 0)) != int(lot[2]) or int(needs.get(key, 0)) < int(lot[2]):
			continue
		out.append({"part": str(lot[0]), "colour": int(lot[1])})
	return out


static func _named(lots: Array) -> String:
	var out := PackedStringArray()
	for lot: Dictionary in lots:
		out.append("%s/%d" % [lot["part"], int(lot["colour"])])
	return ", ".join(out)


func _mark_row(lot: Dictionary) -> HBoxContainer:
	for row: HBoxContainer in _dialog.call("mark_rows"):
		var held: Dictionary = row.get_meta("mark")
		if str(held["part"]) == str(lot["part"]) and int(held["colour"]) == int(lot["colour"]):
			return row
	return null


func _loose_has(key: String) -> bool:
	for lot: Dictionary in _store.collection.parts:
		if Collection.key_of(str(lot["part"]), int(lot["colour"]), _library) == key:
			return true
	return false


# -- the collection as kept -----------------------------------------------------------

func _kept() -> Dictionary:
	return _kept_of(_store)


static func _kept_of(store: CollectionStore) -> Dictionary:
	var json: Dictionary = store.collection.to_json()
	return {"sets": json["sets"], "parts": json["parts"]}


static func _set_of(collection: Dictionary, number: String) -> Dictionary:
	for entry: Dictionary in collection.get("sets", []):
		if str(entry["set"]) == number:
			return entry
	return {}


static func _without_set(collection: Dictionary, number: String) -> Array:
	return (collection.get("sets", []) as Array).filter(func(entry: Dictionary) -> bool:
		return str(entry["set"]) != number)


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


## Every change the window has in hand made: none being written, none typed.
func _settled() -> void:
	var waited: int = Time.get_ticks_msec()
	await _frames(3)
	while (bool(_dialog.get("_writing")) or not (_dialog.get("_counts_typed") as Dictionary).is_empty()
			or not (_dialog.get("_marks_typed") as Dictionary).is_empty()) and Time.get_ticks_msec() - waited < 30000:
		await process_frame
	await _frames(3)


## The missing counts typed, sent as a person's are: 0.6 s after the last.
func _marks_sent() -> void:
	var waited: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited < 1500:
		await process_frame
	await _settled()


func _in_the_dialog(what: String) -> void:
	var panel: Rect2 = (_dialog as Control).get_global_rect()
	var past := PackedStringArray()
	for found: Node in (_dialog as Node).find_children("*", "Control", true, false):
		if not (found is BaseButton or found is LineEdit or found is SpinBox):
			continue
		var control := found as Control
		if not control.is_visible_in_tree() or control.get_parent() is SpinBox:
			continue
		var at: Rect2 = control.get_global_rect()
		if at.position.x < panel.position.x - 0.5 or at.end.x > panel.end.x + 0.5:
			past.append(str(control.get("text")) if not str(control.get("text")).is_empty()
				else str(control.get("placeholder_text")) if control is LineEdit else str(control.name))
	_check("%s and every control beside it inside the dialog's sides (%d wide)%s"
		% [what, roundi(panel.size.x), "" if past.is_empty() else ": past them " + ", ".join(past.slice(0, 6))],
		past.is_empty())


func _sign_in(account: Account, email: String) -> String:
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
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


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


func _text_of(node: Node) -> String:
	var out: String = ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	for child: Node in node.get_children():
		out += _text_of(child)
	return out


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
