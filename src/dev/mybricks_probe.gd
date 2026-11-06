## My collection takes the bricks a person owns loose: by hand, by a part's
## photo, and over MCP from a photo of a pile (APP_UX5 #2, mybricks).
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9911 &
##   BRICKWORKS_API=http://127.0.0.1:9911 \
##     godot --path . --resolution 1280x720 --script src/dev/mybricks_probe.gd
##   ... -- --shots=DIR   the row, the lots, What do I need?, What can I build?
##                        and what a session added, pictured there
##   (tools/relay_probe.sh mybricks runs it on a relay of its own;
##   PROBE_SIZE=1400x900 for the larger window)
##
## On the real scene, signed in as a throwaway account at a Resend test
## address (made with a password, no code redeemed), through
## api/collection.js on the relay and the real database, deleted at the end:
##
##   1. a collection made the old ways: a set typed, a Rebrickable parts
##      CSV, a BrickLink XML
##   2. 12 loose lots of the sports car's added by hand on What I own, each
##      in 3 actions or fewer: a search (its number or its words, with its
##      colour's name) or a photo (Brickognize's answer, given here), a
##      count, Add; listed under Loose parts. A part chosen in the bin
##      fills the row; Like this lists parts like the chosen one.
##   3. What do I need? for the car falls by exactly those lots; What can I
##      build? puts a model made only of them at 100%
##   4. each lot changed, and taken out, by itself; all twelve out again,
##      the old collection lot for lot as it was
##   5. over MCP (edit_collection, through CommandSocket as a chat calls it)
##      the same 12 in 1 call, marked as the chat's; read back by
##      parts_list which="need" in 1 call, the car short by exactly as much
##      less; listed for the person under Added by Claude
##   6. kept over a restart (the copy on this device, then the account's
##      with the kept session) and over a sign-in on another device
##   7. Take back what Claude added: exactly those 12 gone, the old
##      collection lot for lot as it was; Start over still asks first
##   8. nothing lost as a person uses it (mybricks2): a count typed then
##      Remove pressed at once takes the lot out; a session's count typed
##      then Keep pressed at once keeps the count typed; a reply that comes
##      for an account no longer signed in is dropped; two MCP sessions that
##      name no chat (the desktop's port, by their Mcp-Session-Id) each keep
##      their own lots; the old collection lot for lot as it was after
##   9. the build before (rel-m266, its own Collection and CollectionStore
##      read from git at a209f558) against this server: it reads every lot,
##      its import adds to its own source's lot, and its set Remove (a PUT
##      of the whole collection as it keeps it, every lot's source and
##      session dropped) is refused with words to update: no lot lost, no
##      mark stripped
##
## On pre261 there is no row to add a loose lot in, no "lots" at the
## account and no edit_collection: 2 to 9 fail with words. Writes nothing in
## the app's own directory: the copy on this device and the session go to
## the probe's own data folder (probe.sh's XDG_DATA_HOME).
extends SceneTree

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _socket: CommandSocket
var _next: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
## The dialog, untyped: its loose-part calls are looked up as they are made,
## so a build without them fails a check rather than the script.
var _dialog: Node
var _store: CollectionStore
## A chat's id, as the relay names one on every call (CommandSocket.CHAT_KEY).
const CHAT := "probe-mybricks-chat"


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
		print("mybricks probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % api)
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
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_account = _main.get("_account")
	while _account.state == Account.State.CHECKING:
		await _account.changed
	_email = SignInHelper.throwaway("mybricks")
	var problem: String = await _sign_in(_account, _email, true)
	_check("signed in as a throwaway account: %s" % (problem if not problem.is_empty() else _email),
		problem.is_empty() and _account.signed_in())
	if not _account.signed_in():
		quit(1)
		return
	await _loaded()
	await _steps()
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	print("\nmybricks probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	print("\n1. a collection made the old ways")
	var old: Array = [
		{"from": "sets", "text": "6020-1"},
		{"from": "rebrickable_csv", "text": "Part,Color,Quantity\n3001,4,10\n3641,0,2\n"},
		{"from": "bricklink_xml", "text": "<INVENTORY><ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>4624</ITEMID>"
			+ "<COLOR>9</COLOR><MINQTY>4</MINQTY></ITEM></INVENTORY>"},
	]
	for one: Dictionary in old:
		var got: Dictionary = await _store.add(one)
		_check("%s imported%s" % [one["from"], "" if str(got["error"]).is_empty() else ": " + str(got["error"])],
			str(got["error"]).is_empty())
	var before: Dictionary = _kept()
	_check("one set and three loose lots: %s" % JSON.stringify(before["parts"]),
		(before["sets"] as Array).size() == 1 and (before["parts"] as Array).size() == 3)

	_main.call("clear_model")
	await _frames(10)
	var placed: int = (_main.get("_store") as ModelStore).open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)
	var needs: Dictionary = _needs()
	var short_before: Array = _short(needs)
	var twelve: Array = _twelve(needs)
	_check("the car is open (%d parts), %d pieces short in %d lots; 12 of its lots owned not at all"
		% [placed, _pieces(short_before), short_before.size()], placed == 61 and twelve.size() == 12)
	var made: String = _made_of(twelve)

	print("\n2. 12 loose lots by hand, on What I own")
	_dialog.call("open", "own")
	# Opened, it reads the account's afresh (mybricks2).
	await _changed()
	var row: bool = _dialog.has_method("search_loose") and _dialog.has_method("add_loose")
	_check("What I own has a row to add a loose part in", row)
	if row:
		await _by_hand(twelve)
	var after_hand: Dictionary = _kept()
	var listed: Array = _own_listed()
	_check("the 12 are listed under Loose parts, each at its count: %d rows of 15" % listed.size(),
		listed.size() == 15 and _all_in(twelve, listed))
	_check("...after the old lots, which are as they were",
		_same((after_hand["parts"] as Array).slice(0, 3), before["parts"]) and _same(after_hand["sets"], before["sets"]))

	print("\n3. What do I need? and What can I build?")
	var short_hand: Array = _short(needs)
	var fell: int = _pieces(short_before) - _pieces(short_hand)
	_check("What do I need? for the car falls by exactly the 12 lots: %d pieces in %d lots to %d in %d (%d fewer, the lots %d)"
		% [_pieces(short_before), short_before.size(), _pieces(short_hand), short_hand.size(), fell, _pieces(twelve)],
		fell == _pieces(twelve) and short_before.size() - short_hand.size() == 12)
	_dialog.call("_show", "need")
	await _frames(10)
	var heading: String = (_dialog.get("_need_heading") as Label).text
	_check("...and its page says so: “%s”" % heading,
		heading.contains("Short: %s pieces in %d lots" % [CollectionDialog._comma(_pieces(short_hand)), short_hand.size()]))
	await _shot("mybricks_need")
	_dialog.call("_show", "build")
	var ranked: Array = await _ranked()
	var at: int = ranked.find_custom(func(one: Dictionary) -> bool: return str(one.get("path", "")) == made)
	var cover: float = float(ranked[at]["cover"]["exact"]) if at >= 0 else 0.0
	_check("What can I build? puts the model made only of them at %d%%, ranked %d of %d"
		% [roundi(cover * 100.0), at + 1, ranked.size()], at >= 0 and is_equal_approx(cover, 1.0)
		and float(ranked[0]["cover"]["exact"]) <= 1.0 and at < 5)
	await _shot("mybricks_build")

	print("\n4. each lot changed, and taken out, by itself")
	_dialog.call("_show", "own")
	await _frames(5)
	if row:
		var first: Dictionary = _lot(twelve[0])
		var trouble: String = await _dialog.call("set_lot_count", first, int(first["qty"]) + 5)
		var changed: Dictionary = _kept()
		_check("%s's count changed to %d, by itself%s" % [first["part"], int(first["qty"]) + 5,
			"" if trouble.is_empty() else ": " + trouble],
			int(_lot(twelve[0]).get("qty", 0)) == int(first["qty"]) + 5
			and _same(_without(changed["parts"], first), _without(after_hand["parts"], first)))
		await _dialog.call("set_lot_count", _lot(twelve[0]), int(first["qty"]))
		var out_one: int = 0
		for lot: Dictionary in twelve:
			var held: Dictionary = _lot(lot)
			var before_out: Array = _kept()["parts"]
			await _dialog.call("remove_lot", held)
			var after_out: Array = _kept()["parts"]
			if after_out.size() == before_out.size() - 1 and _same(after_out, _without(before_out, held)):
				out_one += 1
		_check("each of the 12 taken out by itself, nothing else moving: %d of 12" % out_one, out_one == 12)
	_check("...and the old collection is lot for lot as it was", _same(_kept(), before))

	print("\n5. over MCP: the same 12 in 1 call")
	var adding: Array = twelve.map(func(lot: Dictionary) -> Dictionary:
		return {"part": lot["part"], "color": lot["colour"], "count": lot["qty"]})
	var said: String = await _call("edit_collection", {"add": adding})
	print("     %s" % said.get_slice("\n", 0))
	var added: Array = _store.collection.call("added_lots") if _store.collection.has_method("added_lots") else []
	var marked: int = added.filter(func(lot: Dictionary) -> bool:
		return str(lot.get("by", "")) == "Claude" and str(lot.get("chat", "")) == CHAT).size()
	_check("edit_collection added the 12 in 1 call, each marked as the chat's (%d of %d)" % [marked, added.size()],
		said.begins_with("Added 12 lots") and added.size() == 12 and marked == 12)
	_check("...the old collection's own lots as they were",
		_same(_store.collection.call("own_lots") if _store.collection.has_method("own_lots") else [], before["parts"]))
	var need: String = await _call("parts_list", {"which": "need", "limit": 100})
	var short_mcp: int = _short_said(need)
	_check("parts_list which=need in 1 call: short of %d lots, %d fewer than before (%d)"
		% [short_mcp, short_before.size() - short_mcp, short_before.size()],
		short_mcp == short_hand.size() and _pieces(_short(needs)) == _pieces(short_hand))
	var read: String = await _call("edit_collection", {})
	_check("edit_collection with nothing reads it back, the chat's 12 apart: “%s”" % read.get_slice("\n", 0),
		read.contains("12 lots this chat added") and read.contains("This chat added"))
	var refused: String = await _call("edit_collection", {"remove": [{"part": "3001", "color": 4}]})
	_check("...and refuses to take off the person's own lot: “%s”" % refused.left(120),
		refused.begins_with("Nothing was changed") and _same(_kept()["parts"].slice(0, 3), before["parts"]))
	_dialog.call("_show", "own")
	await _frames(10)
	var take: Variant = (_dialog.call("controls_by_name") as Dictionary).get("collection_take_back")
	_check("What I own lists them for the person, under Added by Claude, with Take back",
		take is Button and (take as Button).text == "Take back what Claude added"
		and _text_of(_dialog.get("_own_rows")).contains("Added by Claude"))
	await _shot("mybricks_claude")
	_in_the_dialog("Keep them, Take back and the lots Claude added")

	print("\n6. kept over a restart, and over a sign-in on another device")
	var kept_now: Dictionary = _kept()
	# As the app starts: the copy on this device first, then the account's
	# with the session kept (the same session: a second renewal of one
	# refresh token would end the first's).
	var restarted := CollectionStore.new()
	restarted.library = _library
	root.add_child(restarted)
	_check("a restart reads the copy on this device: the 12 marked lots in it",
		_same(_marks(restarted.collection.to_json()), _marks(kept_now)) and _marks(kept_now).size() == 12)
	restarted.account = _account
	var trouble_restart: String = await restarted.load_collection()
	_check("...and the kept session fetches the account's, the same lot for lot%s"
		% ("" if trouble_restart.is_empty() else ": " + trouble_restart),
		trouble_restart.is_empty() and _same(_kept_of(restarted), kept_now))
	restarted.queue_free()
	var elsewhere_where: String = CollectionStore.where
	CollectionStore.where = "user://probe_other_device.json"
	Account.where = "user://probe_other_session.json"
	var device := Account.new()
	device.deployment = _account.deployment
	root.add_child(device)
	while device.state == Account.State.CHECKING:
		await device.changed
	var signed: String = await _sign_in(device, _email, false)
	var other := CollectionStore.new()
	other.library = _library
	other.account = device
	root.add_child(other)
	_check("another device starts with nothing of this account's on it",
		other.collection.is_empty())
	var trouble_other: String = await other.load_collection()
	_check("...and signed in there (%s), it has the same collection, the chat's marks and all"
		% ("a session of its own" if signed.is_empty() else signed),
		signed.is_empty() and trouble_other.is_empty() and _same(_kept_of(other), kept_now))
	other.queue_free()
	device.queue_free()
	CollectionStore.where = elsewhere_where
	Account.where = "user://probe_session.json"

	print("\n7. Take back what Claude added")
	if take is Button:
		(take as Button).pressed.emit()
		await _changed()
	_check("Take back takes exactly the 12 out: the collection lot for lot as it was",
		_same(_kept(), before))
	var need_back: String = await _call("parts_list", {"which": "need", "limit": 100})
	_check("...and the car is short as before: %d lots" % _short_said(need_back),
		_short_said(need_back) == short_before.size())
	await _shot("mybricks_taken_back")
	var start: Button = (_dialog.call("controls_by_name") as Dictionary).get("collection_clear")
	start.pressed.emit()
	await _frames(5)
	var asking: ConfirmationDialog = _dialog.get("_confirm_clear")
	_check("Start over still asks first, and nothing is forgotten while it asks",
		asking.visible and _same(_kept(), before))
	asking.get_cancel_button().pressed.emit()
	await _frames(5)
	_check("...and cancelled, nothing is", not asking.visible and _same(_kept(), before))
	await _lossless(before)
	await _older_app(before)
	_dialog.call("close")


## mbreview's findings as a person meets them, in the window (mybricks2).
func _lossless(before: Dictionary) -> void:
	print("\n8. nothing lost as a person uses it")
	_dialog.call("_show", "own")
	# A count typed into a row, then its Remove pressed before the count
	# is sent (finding 5, R6): the count goes first, then the lot out.
	await _store.change_lots([{"part": "3005", "colour": 1, "qty": 5}])
	await _frames(5)
	var row: HBoxContainer = _row_of("3005", 1, "")
	# Found now: the row is freed when the page is drawn again, and a freed
	# row reads as null after.
	var found: bool = row != null
	if found:
		(row.get_child(0) as SpinBox).value = 6
		(row.get_child(row.get_child_count() - 1) as Button).pressed.emit()
		await _settled()
	_check("a count typed (5 -> 6), then Remove pressed at once: the lot is out%s"
		% ("" if found else " (no row for it)"),
		found and _store.collection.lot_of("3005", 1).is_empty() and _same(_kept(), before))
	# A session's lot's count typed, then Keep pressed before it is sent
	# (finding 5, R11): kept at the count typed.
	await _call("edit_collection", {"add": [{"part": "3005", "color": 1, "count": 5}]})
	await _frames(5)
	var theirs: HBoxContainer = _row_of("3005", 1, "Claude")
	found = theirs != null
	if found:
		(theirs.get_child(0) as SpinBox).value = 3
		((_dialog.call("controls_by_name") as Dictionary)["collection_keep_added"] as Button).pressed.emit()
		await _settled()
	var kept: Dictionary = _store.collection.lot_of("3005", 1, "", "", "hand")
	_check("a session's count typed (5 -> 3), then Keep pressed at once: 3 kept as the person's own, none left marked: %s%s"
		% [JSON.stringify(_store.collection.parts.filter(func(lot: Dictionary) -> bool: return str(lot["part"]) == "3005")),
			"" if found else " (no row for it)"],
		found and int(kept.get("qty", 0)) == 3 and _store.collection.added_lots().is_empty())
	if not kept.is_empty():
		var asked: Dictionary = kept.duplicate()
		asked["to"] = 0
		await _store.set_counts([asked])
	# A reply that comes back after the account changed (finding 13): the
	# last person's, dropped, never put in the next person's copy.
	var mine_id: String = _account.user_id
	var heard: Array = [0]
	var hear := func() -> void: heard[0] += 1
	_store.changed.connect(hear)
	var reading: Array = [true]
	var read := func() -> void:
		await _store.load_collection()
		reading[0] = false
	read.call()
	await process_frame
	_account.user_id = "00000000-0000-4000-8000-00000000d1ff"
	var waited: int = Time.get_ticks_msec()
	while reading[0] and Time.get_ticks_msec() - waited < 15000:
		await process_frame
	_account.user_id = mine_id
	_store.changed.disconnect(hear)
	_check("a reply for an account no longer signed in is dropped: nothing taken, nothing said (%d changes)" % heard[0],
		not reading[0] and heard[0] == 0 and _same(_kept(), before))
	# Two sessions on the desktop's MCP port that name no chat (finding 8):
	# each by its Mcp-Session-Id, so one's lots are not the other's.
	var listening: bool = _socket.listen(MCP_PORT)
	var one: String = await _over_http("sessionone.x", {"add": [{"part": "3005", "color": 1, "count": 2}]})
	var two: String = await _over_http("sessiontwo.x", {"add": [{"part": "3005", "color": 1, "count": 4}]})
	var chats: Array = _store.collection.added_lots().map(func(lot: Dictionary) -> String:
		return "%s:%d" % [str(lot.get("chat", "")), int(lot["qty"])])
	_check("two MCP sessions naming no chat keep their lots apart (port %d %s): %s"
		% [MCP_PORT, "listening" if listening else "taken", ", ".join(chats)],
		listening and one.begins_with("Added 1 lot") and two.begins_with("Added 1 lot")
		and chats == ["mcp-sessionone:2", "mcp-sessiontwo:4"])
	var took: String = await _over_http("sessiontwo.x", {"remove": [{"part": "3005", "color": 1}]})
	chats = _store.collection.added_lots().map(func(lot: Dictionary) -> String:
		return "%s:%d" % [str(lot.get("chat", "")), int(lot["qty"])])
	_check("...and one's remove takes down its own lot, not the other's: %s" % ", ".join(chats),
		took.begins_with("Took down") and chats == ["mcp-sessionone:2"])
	_socket.stop()
	await _store.take_back()
	_check("...the old collection lot for lot as it was after all of it", _same(_kept(), before))


## The build before this one, whose collection code is still out there
## (rel-m266; desktop 0.17.0 is older still and the same here).
const OLD_BUILD := "a209f558"


## The build before's collection code against this server (mybricks2).
func _older_app(before: Dictionary) -> void:
	print("\n9. the build before (rel-m266's own collection code) against this server")
	var old_code: GDScript = _old_build()
	_check("rel-m266's Collection and CollectionStore, read from git (%s) and compiled" % OLD_BUILD, old_code != null)
	if old_code == null:
		return
	# A lot by hand and a session's, so there are marks to strip.
	await _store.change_lots([{"part": "3005", "colour": 1, "qty": 2}])
	await _call("edit_collection", {"add": [{"part": "3005", "color": 1, "count": 4}]})
	await _store.load_collection()
	var marked: Dictionary = _kept()
	var store_class: GDScript = old_code.get("Store266")
	store_class.set("where", "user://probe_old_collection.json")
	var old: Node = store_class.new()
	old.set("account", _account)
	old.set("library", _library)
	root.add_child(old)
	var said: String = str(await old.call("load_collection"))
	var read: Array = (old.get("collection") as Object).get("parts")
	_check("it reads every lot (%d of %d)%s" % [read.size(), (marked["parts"] as Array).size(),
		"" if said.is_empty() else ": " + said], said.is_empty() and read.size() == (marked["parts"] as Array).size())
	# Its import, as its dialog sends one: adds to that source's lot only.
	var got: Dictionary = await old.call("add", {"from": "rebrickable_csv", "text": "Part,Color,Quantity\n3001,4,2\n",
		"mode": "add"})
	await _store.load_collection()
	var grown: Dictionary = marked.duplicate(true)
	for lot: Dictionary in grown["parts"]:
		if str(lot["part"]) == "3001" and int(lot["colour"]) == 4 and str(lot.get("src", "")) == "rebrickable_csv":
			lot["qty"] = int(lot["qty"]) + 2
	_check("its import adds 2 to the CSV's lot, nothing else moved, every mark kept%s"
		% ("" if str(got["error"]).is_empty() else ": " + str(got["error"])),
		str(got["error"]).is_empty() and _same(_kept(), grown))
	# Its set Remove, as its dialog makes one (a209f558 collection_dialog.gd
	# _remove_set): the whole collection as it keeps it, PUT.
	var collection_class: GDScript = old_code.get("Collection266")
	var next: Object = collection_class.call("from_json", (old.get("collection") as Object).call("to_json"))
	var sets: Array = []
	for entry: Dictionary in next.get("sets"):
		if str(entry["set"]) != "6020-1":
			sets.append(entry)
	next.set("sets", sets)
	var stripped: bool = (next.get("parts") as Array).all(func(lot: Dictionary) -> bool:
		return not lot.has("src") and not lot.has("by"))
	var trouble: String = str(await old.call("put", next))
	await _store.load_collection()
	_check("its set Remove (every lot's source and session dropped: %s) refused with words: \"%s\"; nothing changed"
		% [stripped, trouble], stripped and trouble.contains("Update Brickworks") and _same(_kept(), grown))
	old.queue_free()
	# Back as it was.
	var csv: Dictionary = _store.collection.lot_of("3001", 4, "", "", "rebrickable_csv")
	var hand: Dictionary = _store.collection.lot_of("3005", 1, "", "", "hand")
	var back: Array = []
	for lot: Dictionary in [csv, hand]:
		if not lot.is_empty():
			var asked: Dictionary = lot.duplicate()
			asked["to"] = int(lot["qty"]) - (2 if lot == csv else int(lot["qty"]))
			back.append(asked)
	await _store.set_counts(back)
	await _store.take_back()
	_check("...the old collection lot for lot as it was after", _same(_kept(), before))


## The build before's Collection and CollectionStore as it has them, read
## from git and compiled as two inner classes of one script (Collection266,
## Store266), so neither takes a global class's name.
func _old_build() -> GDScript:
	var text: String = "extends RefCounted\n"
	var renamed := RegEx.create_from_string("\\bCollection\\b")
	for pair: Array in [["src/collection/collection.gd", "Collection266"], ["src/collection/collection_store.gd", "Store266"]]:
		var out: Array = []
		if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "show",
				"%s:%s" % [OLD_BUILD, pair[0]]], out) != 0 or out.is_empty():
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


## The port a session reaches the app's MCP on, in this probe: one of the
## unit's own (9910-9919).
const MCP_PORT := 9913


## edit_collection over HTTP as an MCP client calls it on the desktop's
## port: a session id of its own, no chat named.
func _over_http(session: String, arguments: Dictionary) -> String:
	_next += 1
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request("http://127.0.0.1:%d/mcp" % MCP_PORT, PackedStringArray(["content-type: application/json",
		"accept: application/json", "mcp-session-id: " + session]), HTTPClient.METHOD_POST,
		JSON.stringify({"jsonrpc": "2.0", "id": _next, "method": "tools/call",
			"params": {"name": "edit_collection", "arguments": arguments}}))
	var got: Array = await http.request_completed
	http.queue_free()
	var answer: Variant = JSON.parse_string((got[3] as PackedByteArray).get_string_from_utf8())
	var text: String = ""
	if answer is Dictionary:
		for block: Variant in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
			text += str((block as Dictionary).get("text", ""))
	return text


## The row of the lot [param part] in [param colour] of [param by]'s (the
## person's own when empty) on What I own, or null.
func _row_of(part: String, colour: int, by: String) -> HBoxContainer:
	for row: HBoxContainer in _dialog.call("lot_rows"):
		var lot: Dictionary = row.get_meta("lot")
		if str(lot["part"]) == part and int(lot["colour"]) == colour and str(lot.get("by", "")) == by:
			return row
	return null


## Every change the window has in hand made: none being written, none typed.
func _settled() -> void:
	var waited: int = Time.get_ticks_msec()
	await _frames(3)
	while (bool(_dialog.get("_writing")) or not (_dialog.get("_counts_typed") as Dictionary).is_empty()) \
			and Time.get_ticks_msec() - waited < 30000:
		await process_frame
	await _frames(3)


## 12 lots by hand, each counted in actions as a person makes them: the
## search typed and Enter (or a photo), a chip pressed when the first found
## is not the part, the colour chosen when the words did not name it, the
## count typed when it is not 1, and Add.
func _by_hand(twelve: Array) -> void:
	var most: int = 0
	var all_right: bool = true
	var lines := PackedStringArray()
	for n: int in twelve.size():
		var lot: Dictionary = twelve[n]
		var info: PartLibrary.PartInfo = _library.parts.get(str(lot["part"]))
		var colour: String = _library.color(int(lot["colour"])).name.replace("_", " ")
		var actions: int = 0
		var how: String
		if n >= 10:
			# A photo of the part: Brickognize's answer, as its API gives it,
			# in BrickLink's numbers, its colour sure.
			how = "photo"
			_dialog.call("show_guesses", [
				{"bricklink": _library.shop_part(str(lot["part"]), "BrickLink"), "score": 0.93},
				{"bricklink": "3001", "score": 0.31}],
				{"bricklink": _library.bricklink_colour(int(lot["colour"])), "score": 0.88})
			actions += 1
		else:
			# By its number, or by its words, with its colour's name.
			how = "%s %s" % [colour, str(lot["part"])] if n < 5 \
				else "%s %s" % [colour.to_lower(), Inventory._tidy(info.name).to_lower()]
			var field: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_loose_search"]
			field.text = how
			field.text_submitted.emit(how)
			actions += 1
		await _frames(2)
		var chosen: Dictionary = _dialog.call("loose_chosen")
		if str(chosen["part"]) != str(lot["part"]):
			var listed: Array = chosen["listed"]
			if listed.has(str(lot["part"])):
				_dialog.call("choose_loose", str(lot["part"]), -1, false)
				actions += 1
			else:
				all_right = false
		chosen = _dialog.call("loose_chosen")
		if int(chosen["colour"]) != int(lot["colour"]):
			_dialog.call("_pick_colour", int(lot["colour"]))
			actions += 1
		if int(lot["qty"]) != 1:
			((_dialog.call("controls_by_name") as Dictionary)["collection_loose_count"] as SpinBox).value = int(lot["qty"])
			actions += 1
		if n == 0:
			await _shot("mybricks_row")
			_in_the_dialog("the row, its part and the parts found beside it")
		var add: Button = (_dialog.call("controls_by_name") as Dictionary)["collection_loose_add"]
		add.pressed.emit()
		actions += 1
		await _changed()
		var held: Dictionary = _lot(lot)
		all_right = all_right and int(held.get("qty", 0)) == int(lot["qty"])
		most = maxi(most, actions)
		lines.append("%s x%d %s by “%s”: %d actions" % [lot["part"], int(lot["qty"]), colour, how, actions])
	for line: String in lines:
		print("     " + line)
	await _shot("mybricks_loose")
	_check("12 lots added by hand, each in 3 actions or fewer (search or a photo, a count, Add): most %d" % most,
		all_right and most <= 3)
	# The bin's own choosing fills the row, and Like this lists parts like it.
	var bin: PartsBin = _main.get("_bin")
	bin.part_chosen.emit("3005")
	await _frames(2)
	_check("a part chosen in the parts bin is the row's part: %s" % str((_dialog.call("loose_chosen") as Dictionary)["part"]),
		str((_dialog.call("loose_chosen") as Dictionary)["part"]) == "3005")
	await _dialog.call("like_loose")
	var like: Array = (_dialog.call("loose_chosen") as Dictionary)["listed"]
	_check("Like this lists parts like it to choose from: %s" % ", ".join(like),
		like.size() >= 4 and like[0] == "3005")
	_dialog.call("choose_loose", str(like[1]), -1, false)
	_check("...and one of them chosen is the row's part: %s" % str((_dialog.call("loose_chosen") as Dictionary)["part"]),
		like.size() > 1 and str((_dialog.call("loose_chosen") as Dictionary)["part"]) == str(like[1]))
	await _shot("mybricks_like")
	_in_the_dialog("Like this's parts")
	(_dialog.call("controls_by_name")["collection_loose_search"] as LineEdit).text = ""


# -- what is kept -------------------------------------------------------------------


## Every button, field and count on the page in sight inside the dialog's
## sides: in one row, the parts found beside the row's part pushed Add, Add
## sets and every Remove past its right edge at 1280 x 720 (the first run).
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


## The collection as the account last sent it: {"sets", "parts"}.
func _kept() -> Dictionary:
	return _kept_of(_store)


static func _kept_of(store: CollectionStore) -> Dictionary:
	var json: Dictionary = store.collection.to_json()
	return {"sets": json["sets"], "parts": json["parts"]}


## The lots a session added, as kept.
static func _marks(collection: Dictionary) -> Array:
	return (collection.get("parts", []) as Array).filter(func(lot: Dictionary) -> bool:
		return not str(lot.get("by", "")).is_empty())


## [param lot] as kept now: the person's own lot of its part and colour.
func _lot(lot: Dictionary) -> Dictionary:
	for held: Dictionary in _store.collection.parts:
		if str(held["part"]) == str(lot["part"]) and int(held["colour"]) == int(lot["colour"]) \
				and str(held.get("by", "")).is_empty():
			return held
	return {}


## Whether every lot of [param lots] is in [param listed], at its count.
static func _all_in(lots: Array, listed: Array) -> bool:
	for lot: Dictionary in lots:
		var found: bool = false
		for on: Dictionary in listed:
			found = found or (str(on["part"]) == str(lot["part"]) and int(on["colour"]) == int(lot["colour"])
				and int(on["qty"]) == int(lot["qty"]))
		if not found:
			return false
	return true


static func _without(lots: Array, lot: Dictionary) -> Array:
	return lots.filter(func(held: Dictionary) -> bool:
		return not (str(held["part"]) == str(lot["part"]) and int(held["colour"]) == int(lot["colour"])
			and str(held.get("by", "")) == str(lot.get("by", ""))))


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


## The lots the dialog lists under Loose parts, the person's own.
func _own_listed() -> Array:
	var out: Array = []
	if not _dialog.has_method("lot_rows"):
		return out
	for row: HBoxContainer in _dialog.call("lot_rows"):
		var lot: Dictionary = row.get_meta("lot")
		if str(lot.get("by", "")).is_empty():
			out.append(lot)
	return out


# -- the car's needs ------------------------------------------------------------------


func _needs() -> Dictionary:
	var stock: Inventory = Inventory.of(_main.get("_world"), _library, (_main.get("_store") as ModelStore).scenery)
	return Collection.needs_of(stock, _library)


func _short(needs: Dictionary) -> Array:
	return Collection.shortfall(needs, _store.on_hand)


static func _pieces(rows: Array) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get("short", row.get("qty", 0)))
	return total


## 12 of the car's lots the collection has none of, at the count the car
## needs, in the colour codes the car's parts are in.
func _twelve(needs: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = needs.keys()
	keys.sort()
	for key: String in keys:
		if out.size() >= 12:
			break
		if int(_store.on_hand.get(key, 0)) > 0 or Collection.colour_of(key) in [16, 24]:
			continue
		var part: String = Collection.part_of(key)
		if Collection.family_of(part) != part:
			continue   # a mould letter: kept as written, but searched as its family
		out.append({"part": part, "colour": Collection.colour_of(key), "qty": int(needs[key])})
	return out


## A saved model made of exactly [param lots]: its path.
func _made_of(lots: Array) -> String:
	var text: String = "0 Twelve Loose Lots\n0 Name: Twelve Loose Lots.ldr\n"
	var x: int = 0
	for lot: Dictionary in lots:
		for _n: int in int(lot["qty"]):
			text += "1 %d %d 0 0 1 0 0 0 1 0 0 0 1 %s.dat\n" % [int(lot["colour"]), x, lot["part"]]
			x += 80
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	var path: String = ModelStore.SAVE_DIR + "Twelve Loose Lots.ldr"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _ranked() -> Array:
	for _n: int in 1200:
		if not bool(_dialog.get("_busy")) and not (_dialog.get("_ranked") as Array).is_empty():
			break
		await process_frame
	await _frames(5)
	return _dialog.get("_ranked")


## How many lots parts_list which=need says are short.
static func _short_said(text: String) -> int:
	var found: RegExMatch = RegEx.create_from_string("Short of (\\d+) lots?").search(text)
	return int(found.get_string(1)) if found != null else (0 if text.contains("They own every piece") else -1)


# -- the session ----------------------------------------------------------------------


## A tool called as a chat calls it over the relay: tools/call, its chat
## named in the call's _meta.
func _call(tool: String, arguments: Dictionary) -> String:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments,
			"_meta": {CommandSocket.CHAT_KEY: {"chat": CHAT}}}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	return text


## [param account] signed in as [param email] with a password: the account
## made with one first when [param make].
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
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


## The collection fetched for the account just signed in (My collection
## fetches it on the account's change).
func _loaded() -> void:
	await _changed()


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


# -- pictures ---------------------------------------------------------------------------


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
