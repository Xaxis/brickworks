## A set's missing parts, kept with the account and left out of what is
## built from it (APP_UX6 #8, localbricks; rebuilt signed-in only after
## lbreview, 2026-11-08: everyone who uses Brickworks has an account, and
## the sign-in screen covers the app until they are signed in).
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9961 &
##   BRICKWORKS_API=http://127.0.0.1:9961 \
##     godot --path . --resolution 1280x720 --script src/dev/localbricks_probe.gd
##   ... -- --shots=DIR   the sign-in screen, My collection marked, the bin
##                        built from one copy and from two, pictured
##   (tools/relay_probe.sh localbricks runs it on a relay of its own;
##   PROBE_SIZE=1400x900 for the larger window)
##
## On the real scene with its sign-in screen up (Main.gate_for_probe),
## through api/collection.js on the relay and the real database, as a
## throwaway account at a Resend test address signed in with a password
## (Supabase's password grant, taken as a code's verify is taken), deleted
## at the end:
##
##   1. the sign-in screen covers the app; nothing of a collection here, and
##      edit_collection says to sign in
##   2. signed in through it (the age question answered if asked): it goes
##   3. 7140 and 3931-1 typed in My collection, kept at the account
##   4. edit_collection missing=: 3 of 7140-1's lots marked in 1 call, the
##      pool 3 less, read back; refused with words and nothing changed: a
##      part not in its inventory, a count past what it has; count 0
##      unmarks, none=true marks it whole, marked again
##   5. Build from it: 282 of 285 in the bin, 3 left out, the bar says so
##   6. kept over a restart: the copy on this device, then the account's
##   7. on another device signed in to the account: the same marks
##   8. two tabs marking one lot at once from the same count: one made, the
##      other refused (409) and shown the account as it is; the account
##      keeps the one made
##   9. a tab a newer build has followed (NewerBuild): its mark made at the
##      account, the copy on this device untouched byte for byte; written
##      again once nothing newer is live
##  10. a second copy of 7140-1, one lot marked past one copy: Build from
##      both 566 of 570 (4 out), from one copy of the two 284 of 285, only
##      what both copies lack left out
##  11. signed out: the sign-in screen back, nothing of the collection or
##      its marks held, edit_collection refused
##  12. the new line drawn reads in de, fr and es
##
## On pre261 missing= is not read and Build from leaves nothing out: 4, 5
## and 7 to 10 fail with words. Writes nothing in the app's own directory:
## the account's copy and the sessions go to the probe's own data folder
## (probe.sh's XDG_DATA_HOME), and no session is kept (gate_for_probe).
extends SceneTree

## A chat's id, as the relay names one on every call (CommandSocket.CHAT_KEY).
const CHAT := "probe-localbricks-chat"

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _socket: CommandSocket
var _next: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
var _gate: Control
## The dialog and the store, untyped: localbricks' calls are looked up as
## they are made, so pre261 fails a check rather than the script.
var _dialog: Node
var _store: Node
## Every line drawn that this unit added, for the languages (12).
var _drawn: PackedStringArray = PackedStringArray()
## A set's or a part's number, kept in every language.
var _number: RegEx = RegEx.create_from_string("^[0-9][0-9a-z]*(-[0-9]+)?$")
# A set's number and name ("7140-1 X-wing Fighter").
var _named_set: RegEx = RegEx.create_from_string("^([0-9]+ × )?[0-9a-z]+-[0-9]+ \\S")


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
		print("localbricks probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % api)
		quit(1)
		return
	Account.where = "user://probe_session.json"
	Account._clear()
	CollectionStore.where = "user://probe_collection.json"
	DirAccess.remove_absolute(CollectionStore.where)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen up, as a person meets it (a --script run has none).
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_library = _main.get("_library")
	_dialog = (_main.get("_shell") as Shell).collection
	_store = _dialog.get("store")
	_gate = _main.get("_gate")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_account = _main.get("_account")
	while _account.state == Account.State.CHECKING:
		await _account.changed
	await _frames(10)
	_email = SignInHelper.throwaway("localbricks")
	await _steps()
	NewerBuild.pretend("")
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	print("\nlocalbricks probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	print("\n1. the sign-in screen covers the app")
	_check("the sign-in screen is up, nobody signed in", _gate != null and _gate.visible and not _account.signed_in())
	_check("...and no collection is held: %d sets, %d lots, %d sets marked" % [_kept()["sets"].size(),
		_kept()["parts"].size(), CollectionStore.marks.size()],
		(_store.get("collection") as Collection).is_empty() and CollectionStore.marks.is_empty())
	var before: String = await _call("edit_collection", {"missing": {"set": "7140-1", "none": true}})
	_check("edit_collection says to sign in: “%s”" % before.left(100), before.contains("not signed in"))
	await _shot("localbricks_gate")

	print("\n2. signed in through it")
	var problem: String = await _sign_in(_account, _email, true)
	_check("signed in with a password, taken as a code's verify is: %s" % (problem if not problem.is_empty() else _account.email),
		problem.is_empty() and _account.signed_in())
	await _until(func() -> bool: return _gate == null or not _gate.visible, 15000)
	_check("...and the sign-in screen goes", _gate != null and not _gate.visible)
	var loaded: String = await _store.call("load_collection")
	_check("the window's collection is the account's, empty: %s" % (loaded if not loaded.is_empty() else "fetched"),
		loaded.is_empty() and not bool(_store.get("offline")) and (_store.get("collection") as Collection).is_empty())

	print("\n3. two sets typed in My collection")
	_dialog.call("open", "own")
	await _settled()
	await _type_sets("7140, 3931-1")
	var at_account: Dictionary = await _account_now(_account)
	_check("7140 and 3931-1 typed, kept at the account: %s" % JSON.stringify(at_account.get("sets", [])).left(160),
		_set_of(at_account, "7140-1").get("qty", 0) == 1 and _set_of(at_account, "3931-1").get("qty", 0) == 1
		and _set_of(_kept(), "7140-1").get("qty", 0) == 1)
	var record: Dictionary = await _record("7140-1")
	var one_copy: Dictionary = _per_copy(record)
	var whole: int = 0
	for key: String in one_copy:
		whole += int(one_copy[key]["qty"])
	_check("7140-1's inventory: %d pieces in %d lots" % [whole, one_copy.size()], whole == 285)
	# Three lots a copy has one of, and one it has more of (for the two tabs).
	var singles: Array = []
	var several: Dictionary = {}
	for key: String in one_copy:
		var lot: Dictionary = one_copy[key]
		if not _library.parts.has(str(lot["part"])):
			continue
		if int(lot["qty"]) == 1 and singles.size() < 3:
			singles.append(lot)
		elif int(lot["qty"]) >= 2 and several.is_empty():
			several = lot
	_check("...3 lots it has one of, and one it has %d of" % int(several.get("qty", 0)),
		singles.size() == 3 and not several.is_empty())
	if singles.size() < 3 or several.is_empty():
		return

	print("\n4. edit_collection missing=")
	var read: String = await _call("edit_collection", {})
	_check("read back: “%s”" % read.get_slice("\n", 0).left(150), read.contains("7140-1") and not read.contains("missing"))
	var pool_before: int = int(_store.call("pieces_on_hand"))
	var three: Array = singles.map(func(lot: Dictionary) -> Dictionary:
		return {"part": lot["part"], "color": lot["colour"], "count": 1})
	var marked: String = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": three}})
	_check("3 of 7140-1's lots marked missing in 1 call: “%s”" % marked.left(120),
		marked.begins_with("Marked 3 lots of 7140-1") and _missing_in(_set_of(_kept(), "7140-1")) == 3)
	_check("...the pool 3 pieces less: %d to %d" % [pool_before, int(_store.call("pieces_on_hand"))],
		int(_store.call("pieces_on_hand")) == pool_before - 3)
	_check("...kept at the account", _missing_in(_set_of(await _account_now(_account), "7140-1")) == 3)
	var marks: Dictionary = CollectionStore.marks
	_check("...and handed to what builds from it (CollectionStore.marks): %s" % JSON.stringify(marks).left(140),
		marks.has("7140-1") and int(marks["7140-1"].get("copies", 0)) == 1 and _sum(marks["7140-1"].get("missing", {})) == 3)
	read = await _call("edit_collection", {})
	_check("...read back with its marks: “%s”" % read.get_slice("\n", 0).left(150), read.contains("7140-1") and read.contains("3 missing"))
	var held: Dictionary = await _account_now(_account)
	var stranger: Dictionary = {}
	for one: Array in [["3001", 14], ["3001", 4], ["3003", 1], ["3020", 15], ["3024", 46]]:
		if not one_copy.has(Collection.key_of(str(one[0]), int(one[1]), _library)):
			stranger = {"part": one[0], "color": one[1], "count": 1}
			break
	var refused: String = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": [stranger]}})
	_check("a part not in its inventory refused: “%s”" % refused.left(130),
		refused.begins_with("Nothing was changed") and refused.contains("is not in 7140-1's inventory"))
	refused = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": [{"part": several["part"],
		"color": several["colour"], "count": int(several["qty"]) + 1}]}})
	_check("a count past what it has refused: “%s”" % refused.left(130),
		refused.begins_with("Nothing was changed") and refused.contains("from 0 to %d of it can be missing" % int(several["qty"])))
	_check("...neither changed anything at the account", _same(await _account_now(_account), held))
	var unmark: String = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": [{"part": singles[0]["part"],
		"color": singles[0]["colour"], "count": 0}]}})
	_check("count 0 unmarks one: “%s”" % unmark.left(110), unmark.begins_with("Marked 1 lot of 7140-1")
		and _missing_in(_set_of(_kept(), "7140-1")) == 2 and _sum(CollectionStore.marks["7140-1"].get("missing", {})) == 2)
	var none: String = await _call("edit_collection", {"missing": {"set": "7140-1", "none": true}})
	_check("none=true marks it whole: “%s”" % none.left(110), none.contains(": whole")
		and _missing_in(_set_of(_kept(), "7140-1")) == 0 and not CollectionStore.marks.has("7140-1"))
	marked = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": three}})
	_check("...and the 3 marked again", marked.begins_with("Marked 3 lots of 7140-1") and _missing_in(_set_of(_kept(), "7140-1")) == 3)
	_dialog.call("open", "own")
	await _settled()
	await _shot("localbricks_marked")

	print("\n5. Build from it")
	await _build_from(PackedStringArray(["7140-1"]), whole, 3, "7140-1")
	await _shot("localbricks_build")
	await _drop_set()

	print("\n6. kept over a restart")
	var restarted := CollectionStore.new()
	restarted.library = _library
	restarted.account = _account
	root.add_child(restarted)
	_check("a restart reads 7140-1's 3 marks from the copy on this device",
		_missing_in(_set_of(_kept_of(restarted), "7140-1")) == 3)
	var fetched: String = await restarted.load_collection()
	_check("...and from the account: %s" % (fetched if not fetched.is_empty() else "fetched"),
		fetched.is_empty() and not restarted.offline and _missing_in(_set_of(_kept_of(restarted), "7140-1")) == 3)
	restarted.queue_free()

	print("\n7. on another device")
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
	var there: Dictionary = elsewhere.call("_marks_of", elsewhere.collection) if elsewhere.has_method("_marks_of") else {}
	_check("signed in to the account on another device, the same marks: %s" % (problem if not problem.is_empty()
		else JSON.stringify(there).left(140)), problem.is_empty() and fetched.is_empty() and not elsewhere.offline
		and not there.is_empty() and _same(there, CollectionStore.marks))
	var answered: int = _missing_in(_set_of(await _account_now(other), "7140-1"))
	_check("...as the account answers that device: 7140-1 %d missing" % answered, answered == 3)
	elsewhere.queue_free()
	await other.sign_out()
	other.queue_free()
	Account.where = "user://probe_session.json"

	print("\n8. two tabs mark one lot at once")
	var tab_b := CollectionStore.new()
	tab_b.library = _library
	tab_b.account = _account
	root.add_child(tab_b)
	await tab_b.load_collection()
	await _store.call("load_collection")
	var src: String = str(_set_of(_kept(), "7140-1").get("src", ""))
	var body_a: Dictionary = {"op": "missing", "set": "7140-1", "lots": [{"part": several["part"], "colour": several["colour"],
		"was": 0, "qty": 1}]}
	var body_b: Dictionary = body_a.duplicate(true)
	body_b["lots"][0]["qty"] = 2
	if not src.is_empty():
		body_a["src"] = src
		body_b["src"] = src
	var answers: Array = [null, null]
	var in_a := func() -> void: answers[0] = await _store.call("change", body_a)
	var in_b := func() -> void: answers[1] = await tab_b.change(body_b)
	in_a.call()
	in_b.call()
	await _until(func() -> bool: return answers[0] != null and answers[1] != null, 30000)
	var kinds: Array = [str((answers[0] as Dictionary).get("kind", "none")) if answers[0] is Dictionary else "none",
		str((answers[1] as Dictionary).get("kind", "none")) if answers[1] is Dictionary else "none"]
	var made: int = kinds.find(CollectionStore.DONE)
	var lost: int = kinds.find(CollectionStore.CONFLICT)
	_check("both from the same count: one made, the other refused (409): %s" % str(kinds),
		made >= 0 and lost >= 0 and made != lost)
	if made >= 0 and lost >= 0 and made != lost:
		var kept_count: int = 1 if made == 0 else 2
		var now: Dictionary = await _account_now(_account)
		_check("...the account keeps the one made: %d missing" % _missing_of(_set_of(now, "7140-1"), several),
			_missing_of(_set_of(now, "7140-1"), several) == kept_count)
		var loser: Node = tab_b if lost == 1 else _store
		_check("...the refused tab shows the account as it is: “%s”" % str((answers[lost] as Dictionary)["said"]).left(110),
			_missing_of(_set_of(_kept_of(loser), "7140-1"), several) == kept_count)
		var key: String = Collection.key_of(str(several["part"]), int(several["colour"]), _library)
		_check("...and the window hands on that count to what builds",
			int((CollectionStore.marks.get("7140-1", {}).get("missing", {}) as Dictionary).get(key, 0)) == kept_count)
	tab_b.queue_free()

	print("\n9. a tab a newer build has followed")
	var copy_text: String = FileAccess.get_file_as_string(CollectionStore.where)
	_check("the copy on this device holds the lot both tabs marked",
		_missing_of(_set_of(_local_copy(), "7140-1"), several) > 0)
	NewerBuild.pretend("newer")
	var stale_tab: String = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": [{"part": several["part"],
		"color": several["colour"], "count": 0}]}})
	_check("its mark made all the same, at the account: “%s”" % stale_tab.left(100),
		stale_tab.begins_with("Marked 1 lot of 7140-1")
		and _missing_of(_set_of(await _account_now(_account), "7140-1"), several) == 0)
	_check("...and the copy on this device untouched, byte for byte (NewerBuild.may_write)",
		FileAccess.get_file_as_string(CollectionStore.where) == copy_text)
	NewerBuild.pretend("")
	await _store.call("load_collection")
	_check("...written again once nothing newer is live",
		_missing_of(_set_of(_local_copy(), "7140-1"), several) == 0 and _missing_in(_set_of(_local_copy(), "7140-1")) == 3)

	print("\n10. a second copy")
	_dialog.call("open", "own")
	await _settled()
	await _type_sets("7140")
	_check("7140 typed again: two copies, its 3 marks kept",
		int(_set_of(_kept(), "7140-1").get("qty", 0)) == 2 and _missing_in(_set_of(_kept(), "7140-1")) == 3)
	var past: String = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": [{"part": singles[1]["part"],
		"color": singles[1]["colour"], "count": 2}]}})
	_check("one lot marked 2, past what one copy has: “%s”" % past.left(110),
		past.begins_with("Marked 1 lot of 7140-1") and _missing_in(_set_of(_kept(), "7140-1")) == 4)
	await _build_from(PackedStringArray(["7140-1", "7140-1"]), whole * 2, 4, "both copies of 7140-1")
	await _shot("localbricks_two_copies")
	await _drop_set()
	# One copy of the two: the other makes up what only one of them lacks.
	await _build_from(PackedStringArray(["7140-1"]), whole, 1, "one copy of the two, only what both lack")
	await _drop_set()

	print("\n11. signed out")
	await _account.sign_out()
	await _until(func() -> bool: return _gate.visible, 10000)
	await _frames(10)
	_check("the sign-in screen is back", _gate.visible and not _account.signed_in())
	_check("...nothing of the collection or its marks held: %d sets, %d marked" % [_kept()["sets"].size(),
		CollectionStore.marks.size()], (_store.get("collection") as Collection).is_empty() and CollectionStore.marks.is_empty())
	var after: String = await _call("edit_collection", {"missing": {"set": "7140-1", "none": true}})
	_check("...and edit_collection refused: “%s”" % after.left(100), after.contains("not signed in"))
	await _shot("localbricks_signed_out")

	print("\n12. the words in de, fr and es")
	_languages()


# -- the steps' helpers -------------------------------------------------------------


## [param text] typed in What I own's sets field, and Add pressed.
func _type_sets(text: String) -> void:
	var typed: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_sets"]
	typed.text = text
	((_dialog.call("controls_by_name") as Dictionary)["collection_add_sets"] as Button).pressed.emit()
	await _changed()
	await _settled()


## One copy of a set's lots in the pool's spelling: key -> {part, colour, qty}.
func _per_copy(record: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row: Variant in record.get("p", []):
		if not row is Array or (row as Array).size() < 3:
			continue
		var key: String = Collection.key_of(str(row[0]), int(row[1]), _library)
		if out.has(key):
			out[key]["qty"] = int(out[key]["qty"]) + int(row[2])
		else:
			out[key] = {"part": str(row[0]), "colour": int(row[1]), "qty": int(row[2])}
	return out


## [param numbers] built from in My collection: [param pieces] in a whole
## bin, [param gone] of them left out, and said so.
func _build_from(numbers: PackedStringArray, pieces: int, gone: int, what: String) -> void:
	_dialog.call("open", "own")
	await _settled()
	await _dialog.call("_build_from", numbers)
	await _frames(5)
	var bin: PartsBin = _main.get("_bin")
	var made: Variant = bin.get("_set_bin")
	var held: int = int(made.get("pieces")) if made is Object else -1
	var left: Variant = made.get("left_out") if made is Object else null
	var status: Variant = (_main.get("_bar") as ModelBar).get("_status")
	var said: String = (status as Label).text if status is Label else ""
	if gone > 0 and not said.is_empty():
		_drawn.append(said)
	_check("Build from %s: %d of %d pieces in the bin, %s left out as marked missing%s" % [what, held, pieces,
		str(left), "" if said.is_empty() else ": “%s”" % said.left(110)],
		held == pieces - gone and left != null and int(left) == gone
		and (gone == 0 or said.contains("less the %s marked missing" % Counted.of(gone, "piece"))))


func _drop_set() -> void:
	var bin: PartsBin = _main.get("_bin")
	if bin.has_method("drop_set"):
		bin.call("drop_set")
	elif bin.has_method("_drop_set"):
		bin.call("_drop_set")
	await _frames(3)


## Every new line drawn, in de, fr and es: each found, nothing of it kept in
## English but a part's or a set's name or number.
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
			# A number, a set's or a part's, is kept as it is, and is no word.
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				var word: String = str(w).strip_edges()
				if _number.search(word) != null or _named_set.search(word) != null:
					return false
				var rest: String = word
				for mark: String in "0123456789½¼¾−-.,:×() ":
					rest = rest.replace(mark, "")
				return not rest.is_empty())
			if Language.says(english).is_empty() or not kept.is_empty():
				missing.append("\"%s\"%s" % [english.left(90), " (kept " + str(kept) + ")" if not kept.is_empty() else ""])
		print("  %s: %s" % [code, TranslationServer.translate(lines[0]) if not lines.is_empty() else ""])
		_check("%s: each of the %d lines reads in the language%s" % [code, lines.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty() and lines.size() >= 3)
	Language.apply("en")


# -- what is kept ---------------------------------------------------------------------


func _kept() -> Dictionary:
	return _kept_of(_store)


static func _kept_of(store: Node) -> Dictionary:
	var json: Dictionary = (store.get("collection") as Collection).to_json()
	return {"sets": json["sets"], "parts": json["parts"]}


## The copy of the account's collection on this device, as written.
static func _local_copy() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CollectionStore.where))
	return parsed if parsed is Dictionary else {}


static func _set_of(collection: Dictionary, number: String) -> Dictionary:
	for entry: Dictionary in collection.get("sets", []):
		if str(entry["set"]) == number and not Collection.is_fig(entry):
			return entry
	return {}


## How many pieces [param entry] is marked as missing.
static func _missing_in(entry: Dictionary) -> int:
	var total: int = 0
	for lot: Dictionary in Collection.missing_lots(entry):
		total += int(lot["qty"])
	return total


## How many of [param lot] [param entry] is marked as missing.
static func _missing_of(entry: Dictionary, lot: Dictionary) -> int:
	return Collection.missing_count(entry, str(lot["part"]), int(lot["colour"])) if not entry.is_empty() else -1


static func _sum(counts: Dictionary) -> int:
	var total: int = 0
	for key: Variant in counts:
		total += int(counts[key])
	return total


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


func _record(number: String) -> Dictionary:
	var inventories: SetInventories = _store.get("inventories")
	return (await inventories.lookup(PackedStringArray([number]))).get(number, {})


# -- the account ----------------------------------------------------------------------


## [param account]'s collection as the account has it now: {"sets", "parts"}.
func _account_now(account: Account) -> Dictionary:
	var reply: Dictionary = await _ask(account, HTTPClient.METHOD_GET, null)
	return {"sets": reply.get("sets", []), "parts": reply.get("parts", [])} if reply.has("parts") else reply


func _ask(account: Account, method: int, body: Variant) -> Dictionary:
	var token: String = await account.access_token()
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request(Deployment.api_base() + "/api/collection", PackedStringArray(["authorization: Bearer " + token,
		"content-type: application/json"]), method, JSON.stringify(body) if body != null else "")
	var result: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if int(result[1]) != 200:
		return {"error": "%d %s" % [int(result[1]), JSON.stringify(parsed).left(200)]}
	return parsed if parsed is Dictionary else {"error": "no JSON"}


## [param account] signed in as [param email] with a password, the session
## taken as a code's verify is taken (Account._signed_in_with), and the age
## question answered when it is asked: the account made first when
## [param make].
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
	return text


# -- the window -----------------------------------------------------------------------


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
	_store.connect("changed", mark, CONNECT_ONE_SHOT)
	var waited: int = Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - waited < 15000:
		await process_frame
	if _store.is_connected("changed", mark):
		_store.disconnect("changed", mark)
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
