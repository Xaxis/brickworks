## A set kept built on a shelf is not loose parts (APP_UX9 #6, keptbuilt).
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 10461 &
##   BRICKWORKS_API=http://127.0.0.1:10461 \
##     godot --path . --resolution 1280x720 --script src/dev/keptbuilt_probe.gd
##   ... -- --shots=DIR   What I own with 7140 marked Built, the bin, pictured
##   (tools/relay_probe.sh keptbuilt runs it on a relay of its own)
##
## On the real scene, through api/collection.js on the relay and the real
## database, signed in as a throwaway account at a Resend test address
## (made with a password, no code redeemed), deleted at the end:
##
##   1. 7140-1 typed in My collection and 12 loose lots added (the person's
##      own), kept at the account. The counts checked by hand: the pool, by
##      part and colour, is the loose lots plus 7140-1's inventory as read
##      here row by row, 341 pieces
##   2. its Built mark pressed, once: kept at the account (built 1); the
##      pool is the 12 lots alone, by hand, part for part (56 pieces); the
##      bin's My bricks the same, tile for tile; What can I build? ranks
##      every set as it ranks the 12 lots alone; submit_design mine=true of
##      a part only 7140-1 has names it 1 over; the summary says how many
##      pieces stand built
##   3. pressed again: taken apart, every count back as in 1, mine=true
##      every part theirs
##   4. over MCP, edit_collection {"built": ["7140-1"]} in 1 call: kept
##      built, said "was 0", the pool the 12 lots; {set, copies: 0} puts it
##      back; refused with words, nothing changed: a set not owned, copies
##      past those owned, built= with add=
##   5. kept: marked, a restart reads it from the copy on this device and
##      the account; another device signed in to the account has it
##   6. the files: Save sets as CSV and as XML (the dialog's own buttons,
##      into a folder of the probe's), each read back into an empty
##      collection through its import: 7140-1 built again, the counts as in 2
##   7. an older build (rel-m304's Collection and OwnCounts, live, read from
##      git and compiled) keeps 7140-1 and its copies and drops only the
##      mark, counting its 285 pieces, and its bin says every set counts,
##      built or not
##   8. two copies: the mark says "Built 1 of 2", then "Built 2 of 2", then
##      none, the pool 285 less a copy built
##   9. the new lines drawn read in de, fr and es
##  10. a built copy's spares still counted beside a part marked missing:
##      the mark is against the inventory's lots, so it comes off the
##      copies apart alone (the review's finding, 2026-11-16)
##
## On pre261 there is no Built mark, no op "built" and no built=: 2 to 8
## fail with words. Writes nothing in the app's own directory: the account's
## copy and the sessions go to the probe's own data folder (probe.sh's
## XDG_DATA_HOME).
extends SceneTree

const SET := "7140-1"
## Live's build when this was written (rel-m304): the build out there that
## knows no Built mark.
const OLDER := "c5571c305"
const CHAT := "probe-keptbuilt-chat"
## The 12 loose lots: part, LDraw colour, how many (ownlimit's).
const LOTS: Array = [
	["3001", 4, 12], ["3020", 0, 4], ["3021", 4, 4], ["4600", 0, 2], ["4624", 71, 4],
	["3641", 0, 4], ["3004", 15, 6], ["3023", 15, 6], ["3024", 47, 4], ["3069b", 0, 4],
	["3010", 1, 4], ["3062b", 14, 2],
]

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _socket: CommandSocket
var _next: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
## Untyped: keptbuilt's calls are looked up as they are made, so pre261
## fails a check rather than the script.
var _dialog: Node
var _store: CollectionStore
## Every line drawn that this unit added, for the languages (9).
var _drawn: PackedStringArray = PackedStringArray()
var _number: RegEx = RegEx.create_from_string("^[0-9][0-9a-z]*(-[0-9]+)?$")
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
		print("keptbuilt probe: FAIL  run it against a relay on this machine (BRICKWORKS_API), not %s" % api)
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
	_email = SignInHelper.throwaway("keptbuilt")
	await _steps()
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	print("\nkeptbuilt probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	var problem: String = await _sign_in(_account, _email, true)
	_check("signed in: %s" % (problem if not problem.is_empty() else _account.email), problem.is_empty())
	if not problem.is_empty():
		return
	await _store.load_collection()

	print("\n1. 7140-1 and 12 loose lots; the counts by hand")
	_dialog.call("open", "own")
	await _settled()
	await _type_sets("7140")
	var adding: Array = LOTS.map(func(lot: Array) -> Dictionary:
		return {"part": lot[0], "colour": lot[1], "qty": lot[2]})
	var added: Dictionary = await _store.change_lots(adding)
	await _settled()
	var record: Dictionary = await _record(SET)
	var by_hand_set: Dictionary = _by_hand_rows(record.get("p", []))
	var by_hand_loose: Dictionary = _by_hand_rows(LOTS)
	var by_hand_all: Dictionary = by_hand_loose.duplicate()
	for key: String in by_hand_set:
		by_hand_all[key] = int(by_hand_all.get(key, 0)) + int(by_hand_set[key])
	_check("7140-1 typed and 12 lots added, kept at the account (%s): %d sets, %d lots" % [added["kind"],
		(await _account_now())["sets"].size(), (await _account_now())["parts"].size()],
		added["kind"] == CollectionStore.DONE and _store.collection.copies_of(SET) == 1
		and _store.collection.parts.size() == 12)
	_check("by hand, 7140-1's inventory is 285 pieces and the lots 56: %d and %d" % [_sum(by_hand_set), _sum(by_hand_loose)],
		_sum(by_hand_set) == 285 and _sum(by_hand_loose) == 56)
	var wrong: Array = _differs(_store.on_hand, by_hand_all)
	_check("the pool is the lots plus 7140-1, part for part: %d pieces, %s" % [_store.pieces_on_hand(),
		"none differ" if wrong.is_empty() else ", ".join(wrong.slice(0, 4))], wrong.is_empty() and _store.pieces_on_hand() == 341)
	var shared: Array = by_hand_set.keys().filter(func(key: String) -> bool: return by_hand_loose.has(key))
	shared.sort()
	print("    by hand, the parts both have: %s" % ", ".join(shared.map(func(key: String) -> String:
		return "%s %d+%d" % [key, int(by_hand_loose[key]), int(by_hand_set[key])])))
	var ranking: SetRanking = await _store.inventories.ranking()
	var ranked_all: SetRanking.Ranked = ranking.rank(by_hand_all) if ranking != null else null
	var ranked_loose: SetRanking.Ranked = ranking.rank(by_hand_loose) if ranking != null else null
	var only_set: String = _only_in_set(by_hand_set, by_hand_loose)
	var tower: Array = _tower([[Collection.part_of(only_set), Collection.colour_of(only_set)], ["3001", 4]])
	var mine: String = await _mine(tower)
	_check("mine=true of %s (only 7140-1 has it) and a Red 2 x 4: every part theirs" % only_set,
		mine.contains("From the person's own parts (mine=true): every one of its 2 pieces"))

	print("\n2. its Built mark pressed")
	_dialog.call("open", "own")
	await _settled()
	var mark: Button = (_dialog.call("controls_by_name") as Dictionary).get("collection_built_" + SET)
	_check("7140-1's row has a Built mark, not pressed: \"%s\"" % (mark.text if mark != null else "none"),
		mark != null and mark.text == "Built" and not mark.button_pressed)
	if mark == null:
		return
	_drawn.append(mark.text)
	_drawn.append(mark.tooltip_text)
	mark.pressed.emit()
	await _changed()
	await _settled()
	var at_account: Dictionary = _set_of(await _account_now(), SET)
	_check("one press: kept at the account, built %d" % int(at_account.get("built", 0)), int(at_account.get("built", 0)) == 1)
	_drawn.append(str((_dialog.get("_status") as Label).text))
	wrong = _differs(_store.on_hand, by_hand_loose)
	_check("the pool is the 12 lots alone, part for part: %d pieces, %s" % [_store.pieces_on_hand(),
		"none differ" if wrong.is_empty() else ", ".join(wrong.slice(0, 4))], wrong.is_empty() and _store.pieces_on_hand() == 56)
	var summary: String = (_dialog.get("_summary") as Label).text
	_drawn.append(summary)
	_check("the summary says it: \"%s\"" % summary, summary.contains("56 pieces to build with, 285 more in 1 set kept built"))
	mark = (_dialog.call("controls_by_name") as Dictionary).get("collection_built_" + SET)
	_check("...and the mark shows pressed", mark != null and mark.button_pressed and mark.text == "Built")
	await _shot("keptbuilt_marked")
	await _bin_is(by_hand_loose, "the 12 lots alone")
	if ranking != null:
		var now_ranked: SetRanking.Ranked = ranking.rank(_store.on_hand)
		_check("What can I build? ranks every set as the 12 lots alone rank it (%d sets)" % now_ranked.owned.size(),
			now_ranked.owned == ranked_loose.owned and now_ranked.order == ranked_loose.order
			and now_ranked.owned != ranked_all.owned)
	mine = await _mine(tower)
	var over: String = ""
	for line: String in mine.split("\n"):
		if line.contains(Collection.part_of(only_set) + " ") and line.contains("they own"):
			over = line
	_check("mine=true names %s 1 over: \"%s\"" % [only_set, over.strip_edges().left(120)],
		over.contains("1 used, they own 0, 1 over"))

	print("\n3. pressed again: taken apart")
	mark.pressed.emit()
	await _changed()
	await _settled()
	_drawn.append(str((_dialog.get("_status") as Label).text))
	wrong = _differs(_store.on_hand, by_hand_all)
	_check("every count back as in 1: %d pieces, %s" % [_store.pieces_on_hand(),
		"none differ" if wrong.is_empty() else ", ".join(wrong.slice(0, 4))], wrong.is_empty() and _store.pieces_on_hand() == 341)
	_check("...not built at the account", not _set_of(await _account_now(), SET).has("built"))
	mine = await _mine(tower)
	_check("...mine=true every part theirs again", mine.contains("every one of its 2 pieces"))

	print("\n4. over MCP")
	var said: String = await _call("edit_collection", {"built": [SET]})
	_check("edit_collection {\"built\": [\"7140-1\"]} in 1 call: \"%s\"" % said.get_slice("\n", 1).strip_edges(),
		said.begins_with("Marked at the person's account") and said.contains("7140-1") and said.contains("kept built 1 of 1 (was 0)")
		and _store.pieces_on_hand() == 56 and int(_set_of(await _account_now(), SET).get("built", 0)) == 1)
	var read: String = await _call("edit_collection", {})
	_check("read back: \"%s\"" % read.get_slice("\n", 0).left(170), read.contains("7140-1") and read.contains("kept built"))
	var held: Dictionary = await _account_now()
	for refused: Array in [[{"built": ["6020-1"]}, "is not a set in the person's collection"],
			[{"built": [{"set": SET, "copies": 2}]}, "copies is a whole number from 0 to 1"],
			[{"built": [SET], "add": [{"part": "3001", "color": 4, "count": 1}]}, "one thing a call"],
			[{"built": [SET], "missing": {"set": SET, "none": true}}, "one thing a call"]]:
		var no: String = await _call("edit_collection", refused[0])
		_check("refused: \"%s\"" % no.left(130), no.begins_with("Nothing was changed") and no.contains(refused[1]))
	_check("...none of it changed anything at the account", _same(await _account_now(), held))
	said = await _call("edit_collection", {"built": [{"set": SET, "copies": 0}]})
	_check("{set, copies: 0} takes it apart: \"%s\"" % said.get_slice("\n", 1).strip_edges(),
		said.contains("kept built 0 of 1 (was 1), taken apart") and _store.pieces_on_hand() == 341)

	print("\n5. kept")
	await _call("edit_collection", {"built": [SET]})
	var restarted := CollectionStore.new()
	restarted.library = _library
	restarted.account = _account
	root.add_child(restarted)
	_check("a restart reads it from the copy on this device: built %d" % Collection.built_of(_set_of(_kept_of(restarted), SET)),
		Collection.built_of(_set_of(_kept_of(restarted), SET)) == 1)
	var fetched: String = await restarted.load_collection()
	_check("...and from the account: built %d, %d pieces to build with" % [Collection.built_of(_set_of(_kept_of(restarted), SET)),
		restarted.pieces_on_hand()], fetched.is_empty() and Collection.built_of(_set_of(_kept_of(restarted), SET)) == 1
		and restarted.pieces_on_hand() == 56)
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
	_check("another device signed in to the account: built %d, %d pieces to build with%s" % [
		Collection.built_of(_set_of(_kept_of(elsewhere), SET)), elsewhere.pieces_on_hand(),
		"" if problem.is_empty() else " (" + problem + ")"],
		problem.is_empty() and fetched.is_empty() and Collection.built_of(_set_of(_kept_of(elsewhere), SET)) == 1
		and elsewhere.pieces_on_hand() == 56)
	elsewhere.queue_free()
	await other.sign_out()
	other.queue_free()
	Account.where = "user://probe_session.json"

	print("\n6. the files")
	var folder: String = OS.get_user_data_dir().path_join("keptbuilt_files")
	DirAccess.make_dir_recursive_absolute(folder)
	Download.folder = folder
	for kind: String in ["csv", "xml"]:
		_dialog.call("open", "own")
		await _settled()
		var button: Button = (_dialog.call("controls_by_name") as Dictionary).get("collection_save_" + kind)
		if button == null:
			_check("Save sets as %s is on What I own" % kind.to_upper(), false)
			continue
		_drawn.append(button.text)
		_drawn.append(button.tooltip_text)
		button.pressed.emit()
		var path: String = folder.path_join("brickworks_my_sets." + kind)
		await _until(func() -> bool: return FileAccess.file_exists(path), 5000)
		var text: String = FileAccess.get_file_as_string(path)
		_check("Save sets as %s wrote %s: %s" % [kind.to_upper(), path.get_file(), text.replace("\n", " ").left(130)],
			text.contains("7140-1,1,False,1") if kind == "csv" else text.contains("<ITEMID>7140-1</ITEMID><QTY>1</QTY><REMARKS>Built</REMARKS>"))
		var kept_lots: Array = _store.collection.parts.duplicate(true)
		await _store.clear()
		var empty: bool = _store.collection.is_empty()
		var got: Dictionary = await _store.add({"from": "rebrickable_csv" if kind == "csv" else "bricklink_xml", "text": text,
			"mode": "add"})
		await _store.change_lots(LOTS.map(func(lot: Array) -> Dictionary:
			return {"part": lot[0], "colour": lot[1], "qty": lot[2]}))
		wrong = _differs(_store.on_hand, by_hand_loose)
		_check("...read back into an empty collection (%s%s): 7140-1 built %d of %d, the pool the 12 lots again%s" % [
			"emptied" if empty else "not emptied", "" if str(got["error"]).is_empty() else ", " + str(got["error"]),
			Collection.built_of(_set_of(_kept(), SET)), _store.collection.copies_of(SET),
			"" if wrong.is_empty() else ": " + ", ".join(wrong.slice(0, 3))],
			empty and str(got["error"]).is_empty() and Collection.built_of(_set_of(_kept(), SET)) == 1
			and _store.collection.copies_of(SET) == 1 and wrong.is_empty() and kept_lots.size() == 12)
	Download.folder = ""

	print("\n7. an older build")
	var old_code: GDScript = _older_build()
	_check("%s's Collection read from git and compiled" % OLDER, old_code != null)
	if old_code != null:
		var older: Object = (old_code.get("Collection266") as GDScript).call("from_json", _store.collection.to_json())
		var its: Array = (older.get("sets") as Array).filter(func(entry: Dictionary) -> bool: return str(entry["set"]) == SET)
		_check("it keeps 7140-1 and its copies, and drops only the mark: %s" % JSON.stringify(its),
			its.size() == 1 and int(its[0]["qty"]) == 1 and not (its[0] as Dictionary).has("built"))
		var older_pool: Dictionary = older.call("pool", _store.records, _library)
		var pieces: int = 0
		for key: String in older_pool:
			pieces += int(older_pool[key])
		_check("...and counts its 285 pieces as loose: %d, against our %d" % [pieces, _store.pieces_on_hand()],
			pieces == _store.pieces_on_hand() + 285)
		var words: Array = []
		OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "show", "%s:src/collection/own_counts.gd" % OLDER], words)
		_check("...and its bin says so: \"Every set you own counts, built or not\"",
			not words.is_empty() and str(words[0]).contains("Every set you own counts, built or not"))

	print("\n8. two copies")
	await _call("edit_collection", {"built": [{"set": SET, "copies": 0}]})
	_dialog.call("open", "own")
	await _settled()
	await _type_sets(SET)
	var steps: Array = []
	for n: int in 3:
		mark = (_dialog.call("controls_by_name") as Dictionary).get("collection_built_" + SET)
		if mark == null:
			break
		mark.pressed.emit()
		await _changed()
		await _settled()
		mark = (_dialog.call("controls_by_name") as Dictionary).get("collection_built_" + SET)
		steps.append([mark.text if mark != null else "none", _store.pieces_on_hand()])
		if n == 0:
			_drawn.append(mark.text)
			_drawn.append(mark.tooltip_text)
			_drawn.append(str((_dialog.get("_status") as Label).text))
			await _shot("keptbuilt_two_copies")
	_check("each press one more copy, then none: %s" % str(steps), steps == [["Built 1 of 2", 56 + 285],
		["Built 2 of 2", 56], ["Built", 56 + 570]])

	print("\n9. the words in de, fr and es")
	_languages()

	print("\n10. a built copy's spares beside a part marked missing")
	_spares_and_missing()


# -- the counts by hand ---------------------------------------------------------------


## Rows of [part, colour, how many] added up by part and colour, as the pool
## spells them: the sum done here, not by Collection.pool.
func _by_hand_rows(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for row: Variant in rows:
		var key: String = Collection.key_of(str(row[0]), int(row[1]), _library)
		out[key] = int(out.get(key, 0)) + int(row[2])
	return out


## Where [param pool] and [param by_hand] differ, as words; empty when they agree.
static func _differs(pool: Dictionary, by_hand: Dictionary) -> Array:
	var out: Array = []
	for key: String in pool:
		if int(pool[key]) != int(by_hand.get(key, 0)):
			out.append("%s %d, by hand %d" % [key, int(pool[key]), int(by_hand.get(key, 0))])
	for key: String in by_hand:
		if not pool.has(key) and int(by_hand[key]) != 0:
			out.append("%s none, by hand %d" % [key, int(by_hand[key])])
	return out


## A plain 2-wide brick or plate of an even length that 7140-1 has and the
## loose lots do not: a Red 2 x 4 stands on it stud for stud.
func _only_in_set(set_keys: Dictionary, loose: Dictionary) -> String:
	var keys: Array = set_keys.keys()
	keys.sort()
	var plain := RegEx.create_from_string("^(Brick|Plate) +2 +x +(2|4|6|8)$")
	for key: String in keys:
		var info: PartLibrary.PartInfo = _library.parts.get(Collection.part_of(key))
		if not loose.has(key) and info != null and plain.search(info.name.strip_edges()) != null:
			return key
	return keys[0] if not keys.is_empty() else "3001/0"


## A tower of [param bricks] ([part, colour] each), stacked from the ground.
func _tower(bricks: Array) -> Array:
	var out: Array = []
	var y: int = 0
	for one: Array in bricks:
		out.append({"part": one[0], "color": one[1], "x": 0, "y": y, "z": 0, "rot": 0})
		var info: PartLibrary.PartInfo = _library.parts.get(str(one[0]))
		y += 1 if info != null and info.name.begins_with("Plate") else 3
	return out


## Build from my bricks: the bin's My bricks holds [param want], tile for tile.
func _bin_is(want: Dictionary, what: String) -> void:
	await _dialog.call("_build_from", PackedStringArray([OwnCounts.WORD]))
	await _frames(5)
	var bin: PartsBin = _main.get("_bin")
	var made: Variant = bin.get("_set_bin")
	var have: Dictionary = made.get("have") if made is Object else {}
	var wrong: Array = _differs(have, want)
	var words: Variant = bin.controls_by_name().get("set words")
	if words is Label:
		_drawn.append((words as Label).tooltip_text)
	_check("the bin's My bricks is %s, tile for tile: %s" % [what, "none differ" if wrong.is_empty()
		else ", ".join(wrong.slice(0, 3))], made is Object and wrong.is_empty()
		and words is Label and (words as Label).tooltip_text.contains(OwnCounts.BUILT_WORDS))
	await _shot("keptbuilt_bin")
	bin.leave_set()
	await _frames(3)


## One set's pool, apart and then built, with a spare 6141 and one of its
## four 6141s marked missing: apart the mark comes off the lots (4 - 1, and
## the spare: 4); built, the lots are on the shelf and the spare is in hand
## (1), the mark not taken off it.
func _spares_and_missing() -> void:
	var record: Dictionary = {"n": "Test", "p": [["3001", 4, 2], ["6141", 7, 4]], "s": [["6141", 7, 1]]}
	var round: String = Collection.key_of("6141", 7, _library)
	var brick: String = Collection.key_of("3001", 4, _library)
	var seen: Array = []
	for built: int in [0, 1]:
		var entry: Dictionary = {"set": "9999-1", "qty": 1, "spares": true,
			"missing": [{"part": "6141", "colour": 7, "qty": 1}]}
		if built > 0:
			entry["built"] = built
		var one: Collection = Collection.from_json({"sets": [entry], "parts": []})
		var counted: Dictionary = one.pool({"9999-1": record}, _library)
		seen.append([int(counted.get(round, 0)), int(counted.get(brick, 0))])
	_check("apart, 6141 %d and 3001 %d (4 and 2); built, 6141 %d and 3001 %d (the spare, 1, and 0)"
		% [seen[0][0], seen[0][1], seen[1][0], seen[1][1]], seen == [[4, 2], [1, 0]])


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
## English but a set's or a part's number.
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
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty() and lines.size() >= 6)
	Language.apply("en")


# -- what is kept ---------------------------------------------------------------------


func _kept() -> Dictionary:
	return _kept_of(_store)


static func _kept_of(store: CollectionStore) -> Dictionary:
	var json: Dictionary = store.collection.to_json()
	return {"sets": json["sets"], "parts": json["parts"]}


static func _set_of(collection: Dictionary, number: String) -> Dictionary:
	for entry: Dictionary in collection.get("sets", []):
		if str(entry["set"]) == number and not Collection.is_fig(entry):
			return entry
	return {}


static func _sum(counts: Dictionary) -> int:
	var total: int = 0
	for key: Variant in counts:
		total += int(counts[key])
	return total


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _record(number: String) -> Dictionary:
	return (await _store.inventories.lookup(PackedStringArray([number]))).get(number, {})


func _type_sets(text: String) -> void:
	var typed: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_sets"]
	typed.text = text
	((_dialog.call("controls_by_name") as Dictionary)["collection_add_sets"] as Button).pressed.emit()
	await _changed()
	await _settled()


# -- the account ----------------------------------------------------------------------


## The collection as the account has it now: {"sets", "parts"}.
func _account_now() -> Dictionary:
	var token: String = await _account.access_token()
	var http := HTTPRequest.new()
	root.add_child(http)
	http.request(Deployment.api_base() + "/api/collection", PackedStringArray(["authorization: Bearer " + token]),
		HTTPClient.METHOD_GET)
	var result: Array = await http.request_completed
	http.queue_free()
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return {"sets": parsed.get("sets", []), "parts": parsed.get("parts", [])} if parsed is Dictionary \
		else {"sets": [], "parts": []}


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


## submit_design mine=true of [param bricks], as a session sends it; the
## model cleared after, so the next starts on an empty one.
func _mine(bricks: Array) -> String:
	var said: String = await _call("submit_design", {"name": "Kept", "description": "a test", "floor": "none",
		"bricks": bricks, "mine": true})
	await _call("clear_model", {})
	return said


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
