## Your bricks, signed in or not (APP_UX6 #8, localbricks): a collection
## kept on this device while nobody is signed in, and at a sign-in offered
## to the account, every lot and set of both kept.
##
##   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9961 &
##   BRICKWORKS_API=http://127.0.0.1:9961 \
##     godot --path . --resolution 1280x720 --script src/dev/localbricks_probe.gd
##   ... -- --shots=DIR   My collection signed out, the offer at a sign-in,
##                        a join with no answer, put together, pictured
##   (tools/relay_probe.sh localbricks runs it on a relay of its own;
##   PROBE_SIZE=1400x900 for the larger window)
##
## On the real scene, through api/collection.js on the relay and the real
## database, as a throwaway account at a Resend test address (made with a
## password, no code redeemed), deleted at the end:
##
##   1. signed out, My collection is this device's own: empty, said so, the
##      imports that need the account off and saying why
##   2. 2 sets typed and 12 of the car's lots added by hand in the Loose
##      parts row, kept on this device
##   3. kept over a restart, and read by another tab
##   4. What do I need? for the car falls by exactly those 12 lots
##   5. edit_collection signed out: read back, 3 lots added in 1 call, a
##      set's parts marked missing (missing=), Take back what Claude added
##      leaving the collection lot for lot as it was; Build from it leaves
##      out the parts marked missing
##   6. two tabs at once: a change each made before it saw the other's,
##      both kept; a count changed from a stale count refused, nothing lost
##   7. the account used on another device first: sets, marks and lots of
##      its own, some of the same part and colour as this device's
##   8. signed in here: asked first, nothing sent before the answer, every
##      control inside; Not now leaves both as they were and is not asked
##      again at the next sign-in; My collection still offers it
##   9. Put them together with no answer (the relay out of reach): kept here
##      as sent, said, offered to nobody; the answer lost after it was made;
##      Send again: made once, and the account has every lot and set of both
##      (each count the sum, 7140-1's two copies with both copies' marks)
##  10. two devices put theirs together at the same moment: both kept; two
##      tabs of one device at once: made once
##  11. signed out again: none of the account's lots shown or changed here,
##      the account's copy on this device untouched; signed in, asked again,
##      Put them together, told what came of it
##  12. Build from 7140-1 (two copies) leaves out what both are marked
##      missing; one copy of the two, its other copy making up the marks
##  13. every new line drawn reads in de, fr and es
##
## On pre261 a collection with nobody signed in is refused: 2 to 12 fail
## with words. Writes nothing in the app's own directory: the device's
## collection, the account's copy and the session go to the probe's own
## data folder (probe.sh's XDG_DATA_HOME).
extends SceneTree

## A chat's id, as the relay names one on every call (CommandSocket.CHAT_KEY).
const CHAT := "probe-localbricks-chat"
const HERE_SCRIPT := "res://src/collection/collection_here.gd"

var _failures: int = 0
var _main: Node
var _shots: String = ""
var _socket: CommandSocket
var _next: int = 0
var _account: Account
var _email: String = ""
var _password: String = ""
var _library: PartLibrary
## The dialog and the store, untyped: localbricks' calls are looked up as
## they are made, so pre261 fails a check rather than the script.
var _dialog: Node
var _store: Node
## CollectionHere, or null where there is none (pre261).
var _here: GDScript
## Every line drawn that this unit added, for the languages (13).
var _drawn: PackedStringArray = PackedStringArray()
## A set's or a part's number, kept in every language.
var _number: RegEx = RegEx.create_from_string("^[0-9][0-9a-z]*(-[0-9]+)?$")
var _named_set: RegEx = RegEx.create_from_string("^[0-9a-z]+-[0-9]+ \\S")


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
	for path: String in [_folder(), "user://probe_other_device.here", "user://probe_device_a.here",
			"user://probe_device_b.here", "user://probe_device_c.here"]:
		_wipe(path)
	DirAccess.remove_absolute(CollectionStore.where)
	_here = load(HERE_SCRIPT) if ResourceLoader.exists(HERE_SCRIPT) else null
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
	_email = SignInHelper.throwaway("localbricks")
	await _steps()
	var gone: int = await SignInHelper.delete_accounts(_email, root)
	_check("the throwaway account deleted, its collection with it: %d" % gone, gone == 1)
	for path: String in [_folder(), "user://probe_other_device.here", "user://probe_device_a.here",
			"user://probe_device_b.here", "user://probe_device_c.here"]:
		_wipe(path)
	print("\nlocalbricks probe: %s" % ("all good" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _steps() -> void:
	print("\n1. signed out, My collection is this device's own")
	_check("nobody is signed in", not _account.signed_in())
	_check("the store says the collection is this device's own: here=%s" % str(_store.get("here")),
		_store.get("here") == true and (_store.get("collection") as Collection).is_empty())
	_dialog.call("open", "own")
	await _settled()
	var summary: String = (_dialog.get("_summary") as Label).text
	_drawn.append(summary)
	_check("What I own says it is kept on this device: “%s”" % summary.left(110),
		summary.contains("kept on this device"))
	var off: PackedStringArray = PackedStringArray()
	for named: String in ["collection_csv", "collection_xml", "collection_rb_go"]:
		var button: Button = (_dialog.call("controls_by_name") as Dictionary).get(named)
		if button != null and button.disabled and button.tooltip_text.begins_with("Sign in to bring this in"):
			off.append(named)
			if _drawn.find(button.tooltip_text) < 0:
				_drawn.append(button.tooltip_text)
	_check("a Rebrickable account, a CSV and a BrickLink file wait for a sign-in, saying why: %d of 3" % off.size(),
		off.size() == 3)
	await _shot("localbricks_signed_out")
	_in_the_dialog("What I own signed out")

	print("\n2. 2 sets typed and 12 loose lots by hand, signed out")
	var typed: LineEdit = (_dialog.call("controls_by_name") as Dictionary)["collection_sets"]
	typed.text = "7140, 3931-1"
	((_dialog.call("controls_by_name") as Dictionary)["collection_add_sets"] as Button).pressed.emit()
	await _changed()
	await _settled()
	var sets: Array = _kept()["sets"]
	_check("7140 and 3931-1 typed: %s" % JSON.stringify(sets),
		sets.size() == 2 and _set_of(_kept(), "7140-1").get("qty", 0) == 1 and _set_of(_kept(), "3931-1").get("qty", 0) == 1)
	_main.call("clear_model")
	await _frames(10)
	var placed: int = (_main.get("_store") as ModelStore).open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(20)
	var needs: Dictionary = _needs()
	var short_before: Array = _short(needs)
	var twelve: Array = _twelve(needs)
	_check("the car is open (%d parts), %d pieces short in %d lots; 12 of its lots on hand not at all"
		% [placed, _pieces(short_before), short_before.size()], placed == 61 and twelve.size() == 12)
	_dialog.call("_show", "own")
	await _frames(5)
	var by_hand: int = 0
	for lot: Dictionary in twelve:
		if await _by_hand(lot):
			by_hand += 1
	await _settled()
	var device: Dictionary = _kept()
	_check("the 12 added in the Loose parts row, each at its count: %d of 12, %d lots kept" % [by_hand,
		(device["parts"] as Array).size()], by_hand == 12 and (device["parts"] as Array).size() == 12
		and _all_in(twelve, device["parts"]))
	var fold: Dictionary = _fold()
	_check("...kept in this window's own file on this device, the account's copy not written: %s"
		% ", ".join(DirAccess.get_files_at(_folder())),
		FileAccess.file_exists(_folder().path_join("probe.json")) and _same_kept(_shown(fold), device)
		and not FileAccess.file_exists(CollectionStore.where))
	summary = (_dialog.get("_summary") as Label).text
	_drawn.append(summary)
	_check("What I own says so: “%s”" % summary, summary.ends_with("kept on this device until you sign in"))
	await _shot("localbricks_device")

	print("\n3. kept over a restart, and read by another tab")
	var restarted := CollectionStore.new()
	restarted.library = _library
	restarted.account = _account
	root.add_child(restarted)
	await restarted.refresh_pool()
	_check("a restart reads the 12 lots and 2 sets back", _same_kept(_kept_of(restarted), device))
	restarted.queue_free()
	var tab_b := CollectionStore.new()
	tab_b.library = _library
	tab_b.account = _account
	tab_b.set("writer", "tab-b")
	root.add_child(tab_b)
	_check("...and another tab reads the same", _same_kept(_kept_of(tab_b), device))

	print("\n4. What do I need? uses them")
	var short_now: Array = _short(needs)
	var fell: int = _pieces(short_before) - _pieces(short_now)
	_check("What do I need? for the car falls by exactly the 12 lots: %d pieces in %d lots to %d in %d"
		% [_pieces(short_before), short_before.size(), _pieces(short_now), short_now.size()],
		fell == _pieces(twelve) and short_before.size() - short_now.size() == 12)
	_dialog.call("_show", "need")
	await _frames(10)
	var heading: String = (_dialog.get("_need_heading") as Label).text
	_check("...and its page says so: “%s”" % heading,
		heading.contains("Short: %s pieces in %d lots" % [CollectionDialog._comma(_pieces(short_now)), short_now.size()]))
	await _shot("localbricks_need")

	print("\n5. edit_collection signed out")
	var read: String = await _call("edit_collection", {})
	_check("read back, kept on this device: “%s”" % read.get_slice("\n", 0).left(150),
		read.contains("kept on this device") and read.contains("7140-1"))
	var three: Array = [{"part": "3001", "color": 4, "count": 2}, {"part": "3003", "color": 1, "count": 5},
		{"part": "3020", "color": 15, "count": 1}]
	var added: String = await _call("edit_collection", {"add": three})
	var claude: Array = (_kept()["parts"] as Array).filter(func(lot: Dictionary) -> bool:
		return str(lot.get("by", "")) == "Claude" and str(lot.get("chat", "")) == CHAT)
	_check("3 lots added in 1 call, each the chat's: “%s”" % added.get_slice("\n", 0).left(100),
		added.begins_with("Added 3 lots") and claude.size() == 3 and _same((_kept()["parts"] as Array).slice(0, 12), device["parts"]))
	var record: Dictionary = await _record("7140-1")
	var marks: Array = []
	for row: Variant in (record.get("p", []) as Array).slice(0, 3):
		marks.append({"part": str(row[0]), "color": int(row[1]), "count": 1})
	var pool_before: int = int(_store.call("pieces_on_hand"))
	var marked: String = await _call("edit_collection", {"missing": {"set": "7140-1", "lots": marks}})
	var seven: Dictionary = _set_of(_kept(), "7140-1")
	_check("7140-1 marked missing 3 lots in 1 call (missing=): “%s”" % marked.left(110),
		marked.begins_with("Marked 3 lots of 7140-1") and Collection.missing_lots(seven).size() == 3)
	_check("...the pool 3 pieces less: %d to %d" % [pool_before, int(_store.call("pieces_on_hand"))],
		int(_store.call("pieces_on_hand")) == pool_before - 3)
	var refused: String = await _call("edit_collection", {"missing": {"set": "7140-1",
		"lots": [{"part": "3001", "color": 4, "count": 99}]}})
	_check("...a mark past what the set has refused: “%s”" % refused.left(110), refused.begins_with("Nothing was changed"))
	_dialog.call("_show", "own")
	await _frames(10)
	var take: Variant = (_dialog.call("controls_by_name") as Dictionary).get("collection_take_back")
	var before_take: Dictionary = _kept()
	# The rows are drawn again once it is pressed, so the button is gone after.
	var had_take: bool = take is Button
	if had_take:
		(take as Button).pressed.emit()
		await _changed()
		await _settled()
	var after_take: Dictionary = _kept()
	_check("Take back what Claude added takes exactly the 3 out: lot for lot as before, 7140-1's marks kept",
		had_take and _same(after_take["parts"], device["parts"]) and _same(after_take["sets"], before_take["sets"]))
	await _shot("localbricks_taken_back")
	# Build from it, signed out: one copy of 7140-1, its 3 marked parts out.
	await _build_from(PackedStringArray(["7140-1"]), record, 3, "one copy of 7140-1 signed out")
	device = _kept()

	print("\n6. two tabs at once")
	if _here != null:
		var stale: Dictionary = _here.call("read", _folder())
		var lot := {"part": "3666", "colour": 11, "qty": 4}
		var a_next: Dictionary = _here.call("apply", stale["shown"], {"op": "lots", "add": [lot]}, _library)["next"]
		var b_next: Dictionary = _here.call("apply", stale["shown"], {"op": "lots", "add": [{"part": "3666", "colour": 11, "qty": 3}]}, _library)["next"]
		# Each written from the same read, as two tabs that had not seen each other's.
		_here.call("write", _folder(), "probe", stale["raw"], a_next)
		_here.call("write", _folder(), "tab-b", stale["raw"], b_next)
		var both: Dictionary = _shown(_fold())
		var got: Dictionary = _lot_in(both, "3666", 11)
		_check("4 added in this tab and 3 in another, each before it saw the other's: 7 kept (%d)" % int(got.get("qty", 0)),
			int(got.get("qty", 0)) == 7 and _same((both["parts"] as Array).slice(0, 12), device["parts"]))
		await _store.call("load_collection")
		# Named as a window names a lot it shows: the lot as kept, at a count.
		var seen: Dictionary = got.duplicate()
		seen["qty"] = 4
		seen["to"] = 1
		var conflict: Dictionary = await tab_b.set_counts([seen])
		_check("a count changed from 4 when it is 7 refused, nothing changed: %s, “%s”" % [conflict["kind"],
			str(conflict["said"]).left(90)], conflict["kind"] == CollectionStore.CONFLICT
			and str(conflict["said"]).contains("is 7 now, not the 4 shown")
			and int(_lot_in(_shown(_fold()), "3666", 11).get("qty", 0)) == 7)
		seen["qty"] = 7
		seen["to"] = 0
		var out: Dictionary = await tab_b.set_counts([seen])
		await _store.call("load_collection")
		_check("...taken out from 7 in the other tab: gone in this one, the 12 and 2 as they were (%s %s)"
			% [out["kind"], str(out["said"]).left(90)],
			out["kind"] == CollectionStore.DONE and _same_kept(_kept(), device))
		_check("a mark made in another tab is in this one", Collection.missing_lots(_set_of(_kept(), "7140-1")).size() == 3)
	else:
		_check("this build keeps a collection on this device (%s)" % HERE_SCRIPT, false)
	tab_b.queue_free()

	print("\n7. the account, used on another device first")
	var signed: String = await _sign_in_elsewhere()
	_check("an account of its own on another device: %s" % (signed if not signed.is_empty() else _email), signed.is_empty())
	var account_before: Dictionary = _account_copy_fetched
	_check("...its own: 6020-1, 7140-1 with 1 lot marked, and 3 loose lots (one the device's part and colour): %s"
		% JSON.stringify(account_before).left(160),
		(account_before.get("sets", []) as Array).size() == 2 and (account_before.get("parts", []) as Array).size() == 3)

	print("\n8. signed in here: asked first")
	var problem: String = await _sign_in(_account, _email, false)
	_check("signed in on this device: %s" % (problem if not problem.is_empty() else "yes"), problem.is_empty())
	await _offer_up()
	var offer: Window = _store.call("offer_window") if _store.has_method("offer_window") else null
	var asked: String = str(offer.get("dialog_text")) if offer != null else ""
	_check("asked at once, the two side by side: “%s”" % asked.get_slice("\n", 0),
		offer != null and offer.visible and asked.contains("this device kept 2 sets and 12 lots of loose parts (%d pieces)"
			% _pieces(device["parts"])) and asked.contains("Your account's collection has 2 sets and 3 lots"))
	if offer != null:
		_drawn.append_array([offer.title, asked, (offer as ConfirmationDialog).ok_button_text,
			(offer as ConfirmationDialog).cancel_button_text])
	var held: Dictionary = await _account_now(_account)
	_check("...and nothing sent before the answer: the account as it was", _same_kept(held, account_before))
	_check("...the window shows the account's collection, not this device's", _same_kept(_kept(), account_before))
	await _shot("localbricks_offer")
	_in_the_window(offer, "the offer")
	if offer != null:
		(offer as ConfirmationDialog).get_cancel_button().pressed.emit()
		await _frames(5)
	_check("Not now: the offer gone, both as they were", offer != null and not offer.visible
		and _same_kept(await _account_now(_account), account_before) and _same_kept(_offerable(), device))
	await _store.call("_after_sign_in", _account.user_id)
	await _frames(5)
	_check("...and not asked again at the next sign-in while this device keeps the same", offer != null and not offer.visible)
	_dialog.call("open", "own")
	await _settled()
	var row: Button = (_dialog.call("controls_by_name") as Dictionary).get("collection_join")
	var row_words: String = _text_of(_dialog.get("_own_rows"))
	_check("My collection still offers it, apart: “On this device only: …”", row != null
		and row_words.contains("On this device only: 2 sets and 12 lots of loose parts"))
	if row != null:
		_drawn.append_array([row.text, row.tooltip_text, row_words.get_slice("\n", 0)])
	await _shot("localbricks_on_this_device")
	_in_the_dialog("What I own with the device's own row")

	print("\n9. Put them together with no answer, then Send again")
	if row != null:
		row.pressed.emit()
		await _frames(5)
	_check("Put them in my collection… asks again", offer != null and offer.visible)
	var api: String = OS.get_environment("BRICKWORKS_API")
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	if offer != null:
		(offer as ConfirmationDialog).get_ok_button().pressed.emit()
		await _until(func() -> bool: return str(offer.get("state")) != "sending", 30000)
	OS.set_environment("BRICKWORKS_API", api)
	var told: String = str(offer.get("told")) if offer != null else ""
	_drawn.append(told)
	var pending: Array = _store.get("pending") if _store.get("pending") != null else []
	_check("no answer: said, nothing lost: “%s”" % told.left(120),
		told.begins_with("No answer came") and pending.size() == 1)
	_check("...kept on this device as sent, offered to nobody while it waits",
		_same_kept(_offerable(), {"sets": [], "parts": []}) and _same_kept(_shown(_fold()), device))
	if offer != null:
		await _shot("localbricks_no_answer")
		(offer as ConfirmationDialog).get_ok_button().pressed.emit()
		await _frames(5)
	_dialog.call("open", "own")
	await _settled()
	var again: Button = (_dialog.call("controls_by_name") as Dictionary).get("collection_join_again")
	var waiting: String = _text_of(_dialog.get("_own_rows"))
	_check("My collection says it waits, with Send again: “%s”" % waiting.get_slice("\n", 0),
		again != null and waiting.contains("14 lots and sets sent to your collection had no answer yet"))
	if again != null:
		_drawn.append_array([again.text, again.tooltip_text, waiting.get_slice("\n", 0)])
	await _shot("localbricks_send_again")
	_check("...and the account has none of it yet", _same_kept(await _account_now(_account), account_before))
	# The first send reached the account and only its answer was lost.
	var sent: Dictionary = pending[0] if not pending.is_empty() else {}
	var reached: Dictionary = await _post(_account, {"op": "join", "id": str(sent.get("id", "")),
		"sets": sent.get("sets", []), "parts": sent.get("parts", [])})
	var want: Dictionary = _summed(account_before, device)
	_check("the account made it as it came (its answer lost): %s" % JSON.stringify(reached.get("done", {})),
		_holds(reached, want).is_empty())
	if again != null:
		again.pressed.emit()
		await _until(func() -> bool: return (_store.get("pending") as Array).is_empty(), 20000)
		await _settled()
	var joined: Dictionary = await _account_now(_account)
	var wrong: PackedStringArray = _holds(joined, want)
	_check("Send again: made once, every lot and set of both (%s)" % ("; ".join(wrong) if not wrong.is_empty()
		else "%d lots, %d sets" % [(joined["parts"] as Array).size(), (joined["sets"] as Array).size()]), wrong.is_empty())
	var both_seven: Dictionary = _set_of(joined, "7140-1")
	_check("...7140-1 twice, both copies' marks kept: %s" % JSON.stringify(both_seven).left(160),
		int(both_seven.get("qty", 0)) == 2 and Collection.missing_lots(both_seven).size()
		== _marks_union(_set_of(account_before, "7140-1"), _set_of(device, "7140-1")))
	_check("...this device keeps nothing to offer now, and nothing waits",
		_same_kept(_offerable(), {"sets": [], "parts": []}) and (_store.get("pending") as Array).is_empty()
		and _same_kept(_shown(_fold()), {"sets": [], "parts": []}))
	_check("...the window shows the account's, every lot of both", _same_kept(_kept(), joined))
	var resent: Dictionary = await _post(_account, {"op": "join", "id": str(sent.get("id", "")),
		"sets": sent.get("sets", []), "parts": sent.get("parts", [])})
	_check("the same join sent once more is answered as it was, never made twice: %s"
		% JSON.stringify(resent.get("done", {})), (resent.get("done", {}) as Dictionary).get("again") == true
		and _holds(resent, want).is_empty())

	print("\n10. two devices put theirs together at the same moment")
	var after_one: Dictionary = joined
	var dev_a: Dictionary = {"parts": [{"part": "3024", "colour": 4, "qty": 6}, {"part": "3001", "colour": 4, "qty": 1}],
		"sets": []}
	var dev_b: Dictionary = {"parts": [{"part": "3024", "colour": 4, "qty": 2}, {"part": "3710", "colour": 0, "qty": 3}],
		"sets": [{"set": "6020-1", "qty": 1, "spares": false, "src": "hand"}]}
	var a: CollectionStore = await _device_with("user://probe_device_a.here", dev_a)
	var b: CollectionStore = await _device_with("user://probe_device_b.here", dev_b)
	var answers: Array = [null, null]
	var run_a := func() -> void: answers[0] = await a.call("join")
	var run_b := func() -> void: answers[1] = await b.call("join")
	run_a.call()
	run_b.call()
	await _until(func() -> bool: return answers[0] != null and answers[1] != null, 30000)
	var two: Dictionary = await _account_now(_account)
	var want_two: Dictionary = _summed(_summed_json(after_one, dev_a), dev_b)
	var wrong_two: PackedStringArray = _holds(two, want_two)
	_check("both made, each count the sum of all three (%s)" % ("; ".join(wrong_two) if not wrong_two.is_empty()
		else "3024 ×%d, 6020-1 ×%d" % [int(_lot_in(two, "3024", 4).get("qty", 0)), int(_set_of(two, "6020-1").get("qty", 0))]),
		answers[0] is Dictionary and answers[1] is Dictionary and str(answers[0]["kind"]) == CollectionStore.DONE
		and str(answers[1]["kind"]) == CollectionStore.DONE and wrong_two.is_empty())
	a.queue_free()
	b.queue_free()
	# Two tabs of one device, both pressing Put them together at once.
	var dev_c: Dictionary = {"parts": [{"part": "3068b", "colour": 14, "qty": 5}], "sets": []}
	var tab_x: CollectionStore = await _device_with("user://probe_device_c.here", dev_c)
	var tab_y := CollectionStore.new()
	tab_y.library = _library
	tab_y.account = _account
	tab_y.set("here_at", "user://probe_device_c.here")
	tab_y.set("writer", "tab-y")
	root.add_child(tab_y)
	var tabs: Array = [null, null]
	var run_x := func() -> void: tabs[0] = await tab_x.call("join")
	var run_y := func() -> void: tabs[1] = await tab_y.call("join")
	run_x.call()
	run_y.call()
	await _until(func() -> bool: return tabs[0] != null and tabs[1] != null, 30000)
	var after_tabs: Dictionary = await _account_now(_account)
	var c_left: Dictionary = _here.call("offerable", _here.call("read", "user://probe_device_c.here")) if _here != null else {}
	_check("two tabs of one device pressing Put them together at once: made once (3068b ×%d, the device's left %s)"
		% [int(_lot_in(after_tabs, "3068b", 14).get("qty", 0)), JSON.stringify(c_left)],
		_holds(after_tabs, _summed(_summed_json(_summed_json(after_one, dev_a), dev_b), dev_c)).is_empty()
		and _same_kept(c_left, {"sets": [], "parts": []}))
	tab_x.queue_free()
	tab_y.queue_free()
	two = after_tabs
	await _store.call("load_collection")

	print("\n11. signed out again")
	var copy_text: String = FileAccess.get_file_as_string(CollectionStore.where)
	await _account.sign_out()
	await _until(func() -> bool: return _store.get("here") == true, 10000)
	await _settled()
	_check("signed out: the window shows this device's own, none of the account's lots or sets",
		_store.get("here") == true and _same_kept(_kept(), {"sets": [], "parts": []}))
	var read_out: String = await _call("edit_collection", {})
	var bad_set: String = await _call("edit_collection", {"missing": {"set": "7140-1", "none": true}})
	_check("...and none of them can be read or changed here: “%s” / “%s”" % [read_out.get_slice("\n", 0).left(90),
		bad_set.left(70)], read_out.contains("kept on this device") and read_out.contains("0 sets")
		and bad_set.begins_with("Nothing was changed"))
	_dialog.call("open", "own")
	await _settled()
	var one: Dictionary = {"part": "3062b", "colour": 46, "qty": 2}
	var lone: bool = await _by_hand(one)
	_check("a lot added signed out goes to this device: %s" % JSON.stringify(_kept()["parts"]),
		lone and _same_kept(_kept(), {"sets": [], "parts": [one]}))
	_check("...the account's copy on this device untouched by it, byte for byte",
		FileAccess.get_file_as_string(CollectionStore.where) == copy_text)
	problem = await _sign_in(_account, _email, false)
	await _offer_up()
	asked = str(offer.get("dialog_text")) if offer != null else ""
	_check("signed in, asked again, what is here having changed: “%s”" % asked.get_slice("\n", 0).left(120),
		problem.is_empty() and offer != null and offer.visible and asked.contains("kept 0 sets and 1 lot of loose parts (2 pieces)"))
	_check("...the account as two devices left it, nothing of the signed-out lot in it yet",
		_same_kept(await _account_now(_account), two))
	if offer != null:
		(offer as ConfirmationDialog).get_ok_button().pressed.emit()
		await _until(func() -> bool: return str(offer.get("state")) != "sending", 30000)
		told = str(offer.get("told"))
		_drawn.append(told)
	var last: Dictionary = await _account_now(_account)
	_check("Put them together: told what came of it: “%s”" % told.left(140),
		told.begins_with("Put together: your account's collection has") and told.ends_with("nothing of either left out.")
		and _holds(last, _summed(two, {"sets": [], "parts": [one]})).is_empty())
	await _shot("localbricks_joined")
	if offer != null:
		(offer as ConfirmationDialog).get_ok_button().pressed.emit()
		await _frames(5)
	_check("...Done closes it", offer != null and not offer.visible)

	print("\n12. Build from it leaves out what is marked missing")
	await _settled()
	var seven_now: Dictionary = _set_of(_kept(), "7140-1")
	var gone: int = 0
	for lot: Dictionary in Collection.missing_lots(seven_now):
		gone += int(lot["qty"])
	await _build_from(PackedStringArray(["7140-1", "7140-1"]), record, gone, "both copies of 7140-1")
	# One copy of the two: the other copy makes up what is marked.
	await _build_from(PackedStringArray(["7140-1"]), record, 0, "one copy of the two")

	print("\n13. the words in de, fr and es")
	_languages()


# -- the steps' helpers -------------------------------------------------------------


## The account, made with a password, used on another device: 6020-1 and
## 7140-1 typed, one of 7140-1's lots marked missing, three loose lots (one
## of the first of this device's part and colour). Its collection as the
## account then has it in [member _account_copy_fetched]. Returns what went
## wrong, empty when nothing did.
func _sign_in_elsewhere() -> String:
	Account.where = "user://probe_other_session.json"
	var other := Account.new()
	other.deployment = _account.deployment
	root.add_child(other)
	while other.state == Account.State.CHECKING:
		await other.changed
	var problem: String = await _sign_in(other, _email, true)
	if not problem.is_empty():
		other.queue_free()
		Account.where = "user://probe_session.json"
		return problem
	# Three lots of its own, the first of the same part and colour as this
	# device's first, so a join must add the two counts.
	var own: Array = []
	var named: Dictionary = {}
	var first: Dictionary = (_kept()["parts"] as Array)[0] if not (_kept()["parts"] as Array).is_empty() else {}
	for lot: Dictionary in [{"part": str(first.get("part", "3001")), "colour": int(first.get("colour", 4)), "qty": 3},
			{"part": "3001", "colour": 4, "qty": 10}, {"part": "3023", "colour": 71, "qty": 4},
			{"part": "3004", "colour": 14, "qty": 6}]:
		var key: String = "%s/%d" % [lot["part"], int(lot["colour"])]
		if own.size() < 3 and not named.has(key):
			named[key] = true
			own.append(lot)
	var steps: Array = [{"from": "sets", "text": "6020-1, 7140-1", "id": "lb-own-%d" % Time.get_ticks_usec()},
		{"op": "lots", "id": "lb-own-lots-%d" % Time.get_ticks_usec(), "add": own}]
	for body: Dictionary in steps:
		var done: Dictionary = await _post(other, body)
		if done.is_empty() or done.has("error"):
			other.queue_free()
			Account.where = "user://probe_session.json"
			return "the account's own collection was not made: %s" % JSON.stringify(done)
	var record: Dictionary = await _record("7140-1")
	var row: Array = (record.get("p", []) as Array)[0] if not (record.get("p", []) as Array).is_empty() else []
	var mark: Dictionary = await _post(other, {"op": "missing", "id": "lb-own-mark-%d" % Time.get_ticks_usec(),
		"set": "7140-1", "src": "hand", "lots": [{"part": str(row[0]) if row.size() > 0 else "3001",
			"colour": int(row[1]) if row.size() > 1 else 4, "was": 0, "qty": 1}]})
	_account_copy_fetched = await _account_now(other)
	await other.sign_out()
	other.queue_free()
	Account.where = "user://probe_session.json"
	return "" if not mark.has("error") else "7140-1 was not marked: %s" % JSON.stringify(mark)


var _account_copy_fetched: Dictionary = {}


## A device with [param kept] in its own collection at [param folder], signed
## in as the window's account: a store of its own, as another machine's.
func _device_with(folder: String, kept: Dictionary) -> CollectionStore:
	_wipe(folder)
	if _here != null:
		var empty: Dictionary = _here.call("read", folder)
		_here.call("write", folder, "device", empty["raw"], {"sets": kept["sets"], "parts": kept["parts"]})
	var device := CollectionStore.new()
	device.library = _library
	device.account = _account
	device.set("here_at", folder)
	device.set("writer", "device")
	root.add_child(device)
	await device.load_collection()
	return device


## The offer, once the window's store has fetched the account's and asked.
func _offer_up() -> void:
	await _until(func() -> bool:
		var offer: Variant = _store.call("offer_window") if _store.has_method("offer_window") else null
		return offer is Window and (offer as Window).visible, 15000)
	await _frames(5)


## [param numbers] built from in My collection: the bin left out [param
## gone] pieces, and said so.
func _build_from(numbers: PackedStringArray, record: Dictionary, gone: int, what: String) -> void:
	_dialog.call("open", "own")
	await _settled()
	await _dialog.call("_build_from", numbers)
	await _frames(5)
	var bin: PartsBin = _main.get("_bin")
	var made: Variant = bin.get("_set_bin")
	var whole: int = 0
	for row: Variant in record.get("p", []):
		whole += int(row[2])
	whole *= numbers.size()
	var pieces: int = int(made.get("pieces")) if made is Object else -1
	var left: Variant = made.get("left_out") if made is Object else null
	var said: String = str((_main.get("_bar") as ModelBar).get("_status").text) if (_main.get("_bar") as ModelBar).get("_status") is Label else ""
	if gone > 0 and not said.is_empty():
		_drawn.append(said)
	_check("Build from %s: %d of %d pieces in the bin, %s left out as marked missing%s" % [what, pieces, whole,
		str(left), "" if said.is_empty() else ": “%s”" % said.left(110)],
		pieces == whole - gone and left != null and int(left) == gone
		and (gone == 0 or said.is_empty() or said.contains("less the %s marked missing" % Counted.of(gone, "piece"))))
	if bin.has_method("drop_set"):
		bin.call("drop_set")
	elif bin.has_method("_drop_set"):
		bin.call("_drop_set")


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
				# A set's number and its name ("7140-1 X-wing Fighter").
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
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty() and lines.size() >= 12)
	Language.apply("en")


# -- what is kept ---------------------------------------------------------------------


func _folder() -> String:
	return CollectionStore.where.get_basename() + ".here"


func _fold() -> Dictionary:
	return _here.call("read", _folder()) if _here != null else {"shown": {"sets": [], "parts": []}, "raw": {}}


static func _shown(read: Dictionary) -> Dictionary:
	var shown: Dictionary = read.get("shown", read)
	return {"sets": shown.get("sets", []), "parts": shown.get("parts", [])}


## What this device would offer now: {"sets", "parts"}.
func _offerable() -> Dictionary:
	if _here == null:
		return {}
	return _here.call("offerable", _fold())


func _kept() -> Dictionary:
	return _kept_of(_store)


static func _kept_of(store: Node) -> Dictionary:
	var json: Dictionary = (store.get("collection") as Collection).to_json()
	return {"sets": json["sets"], "parts": json["parts"]}


static func _set_of(collection: Dictionary, number: String) -> Dictionary:
	for entry: Dictionary in collection.get("sets", []):
		if str(entry["set"]) == number and not Collection.is_fig(entry):
			return entry
	return {}


static func _lot_in(collection: Dictionary, part: String, colour: int) -> Dictionary:
	for lot: Dictionary in collection.get("parts", []):
		if str(lot["part"]) == part and int(lot["colour"]) == colour and str(lot.get("by", "")).is_empty():
			return lot
	return {}


static func _lot_key(lot: Dictionary) -> String:
	return JSON.stringify([str(lot["part"]), int(lot["colour"]), str(lot.get("src", "")), str(lot.get("by", "")),
		str(lot.get("chat", ""))])


static func _set_key(entry: Dictionary) -> String:
	return JSON.stringify([str(entry["set"]), str(entry.get("src", ""))])


## [param a] and [param b] summed as a join must: every lot by its part,
## colour and whose, every set by its number and source, copies and marks
## added. {"lots": key -> qty, "sets": key -> {"qty", "missing": key -> qty}}.
static func _summed(a: Dictionary, b: Dictionary) -> Dictionary:
	var lots: Dictionary = {}
	var sets: Dictionary = {}
	for one: Dictionary in [a, b]:
		for lot: Dictionary in one.get("parts", []):
			lots[_lot_key(lot)] = mini(100000, int(lots.get(_lot_key(lot), 0)) + int(lot["qty"]))
		for entry: Dictionary in one.get("sets", []):
			var held: Dictionary = sets.get(_set_key(entry), {"qty": 0, "missing": {}})
			held["qty"] = int(held["qty"]) + int(entry["qty"])
			for mark: Dictionary in Collection.missing_lots(entry):
				var key: String = "%s/%d" % [mark["part"], int(mark["colour"])]
				held["missing"][key] = int(held["missing"].get(key, 0)) + int(mark["qty"])
			sets[_set_key(entry)] = held
	return {"lots": lots, "sets": sets}


## [param summed] as a collection's JSON again, for a sum of three.
static func _summed_json(a: Dictionary, b: Dictionary) -> Dictionary:
	var sum: Dictionary = _summed(a, b)
	var parts: Array = []
	for key: String in sum["lots"]:
		var named: Array = JSON.parse_string(key)
		var lot: Dictionary = {"part": named[0], "colour": int(named[1]), "qty": int(sum["lots"][key])}
		for n: int in [2, 3, 4]:
			if not str(named[n]).is_empty():
				lot[["src", "by", "chat"][n - 2]] = named[n]
		parts.append(lot)
	var sets: Array = []
	for key: String in sum["sets"]:
		var named: Array = JSON.parse_string(key)
		var entry: Dictionary = {"set": named[0], "qty": int(sum["sets"][key]["qty"])}
		if not str(named[1]).is_empty():
			entry["src"] = named[1]
		var missing: Array = []
		for mark: String in sum["sets"][key]["missing"]:
			missing.append({"part": mark.get_slice("/", 0), "colour": int(mark.get_slice("/", 1)),
				"qty": int(sum["sets"][key]["missing"][mark])})
		if not missing.is_empty():
			entry["missing"] = missing
		sets.append(entry)
	return {"sets": sets, "parts": parts}


## What of [param want] ([method _summed]) [param have] does not hold, count
## for count; empty when every lot and set is there and no other.
static func _holds(have: Dictionary, want: Dictionary) -> PackedStringArray:
	var wrong := PackedStringArray()
	var lots: Dictionary = {}
	for lot: Dictionary in have.get("parts", []):
		lots[_lot_key(lot)] = int(lot["qty"])
	for key: String in want["lots"]:
		if int(lots.get(key, 0)) != int(want["lots"][key]):
			wrong.append("lot %s: %d, not %d" % [key, int(lots.get(key, 0)), int(want["lots"][key])])
	if lots.size() != (want["lots"] as Dictionary).size():
		wrong.append("%d lots, not %d" % [lots.size(), (want["lots"] as Dictionary).size()])
	var sets: Dictionary = {}
	for entry: Dictionary in have.get("sets", []):
		sets[_set_key(entry)] = entry
	for key: String in want["sets"]:
		var entry: Dictionary = sets.get(key, {})
		if int(entry.get("qty", 0)) != int(want["sets"][key]["qty"]):
			wrong.append("set %s: %d, not %d" % [key, int(entry.get("qty", 0)), int(want["sets"][key]["qty"])])
			continue
		var marks: Dictionary = {}
		for mark: Dictionary in Collection.missing_lots(entry):
			marks["%s/%d" % [mark["part"], int(mark["colour"])]] = int(mark["qty"])
		if not _same_counts(marks, want["sets"][key]["missing"]):
			wrong.append("set %s's marks: %s, not %s" % [key, JSON.stringify(marks), JSON.stringify(want["sets"][key]["missing"])])
	if sets.size() != (want["sets"] as Dictionary).size():
		wrong.append("%d sets, not %d" % [sets.size(), (want["sets"] as Dictionary).size()])
	return wrong


static func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: String in a:
		if int(a[key]) != int(b.get(key, -1)):
			return false
	return true


## How many lots 7140-1's marks of both come to, each lot once.
static func _marks_union(a: Dictionary, b: Dictionary) -> int:
	var keys: Dictionary = {}
	for entry: Dictionary in [a, b]:
		for mark: Dictionary in Collection.missing_lots(entry):
			keys["%s/%d" % [mark["part"], int(mark["colour"])]] = true
	return keys.size()


static func _all_in(lots: Array, listed: Array) -> bool:
	for lot: Dictionary in lots:
		var found: bool = false
		for on: Dictionary in listed:
			found = found or (str(on["part"]) == str(lot["part"]) and int(on["colour"]) == int(lot["colour"])
				and int(on["qty"]) == int(lot["qty"]))
		if not found:
			return false
	return true


static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


## Whether two collections hold the same lots and sets, count for count and
## mark for mark, however each was read (the store's, the account's).
static func _same_kept(a: Dictionary, b: Dictionary) -> bool:
	return _holds(a, _summed(b, {})).is_empty()


static func _pieces(rows: Array) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get("short", row.get("qty", 0)))
	return total


func _record(number: String) -> Dictionary:
	var inventories: SetInventories = _store.get("inventories")
	return (await inventories.lookup(PackedStringArray([number]))).get(number, {})


func _wipe(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)


# -- the car's needs ------------------------------------------------------------------


func _needs() -> Dictionary:
	var stock: Inventory = Inventory.of(_main.get("_world"), _library, (_main.get("_store") as ModelStore).scenery)
	return Collection.needs_of(stock, _library)


func _short(needs: Dictionary) -> Array:
	return Collection.shortfall(needs, _store.get("on_hand"))


## 12 of the car's lots none of are on hand, at the count the car needs.
func _twelve(needs: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = needs.keys()
	keys.sort()
	var on_hand: Dictionary = _store.get("on_hand")
	for key: String in keys:
		if out.size() >= 12:
			break
		if int(on_hand.get(key, 0)) > 0 or Collection.colour_of(key) in [16, 24]:
			continue
		var part: String = Collection.part_of(key)
		if Collection.family_of(part) != part:
			continue
		out.append({"part": part, "colour": Collection.colour_of(key), "qty": int(needs[key])})
	return out


## [param lot] added in the Loose parts row as a person adds one: its colour
## and number typed, the part chosen if the first found is not it, its
## colour and count, and Add. Whether it was kept at its count.
func _by_hand(lot: Dictionary) -> bool:
	var controls: Dictionary = _dialog.call("controls_by_name")
	var field: LineEdit = controls.get("collection_loose_search")
	if field == null:
		return false
	var colour: String = _library.color(int(lot["colour"])).name.replace("_", " ")
	field.text = "%s %s" % [colour, str(lot["part"])]
	field.text_submitted.emit(field.text)
	await _frames(2)
	var chosen: Dictionary = _dialog.call("loose_chosen")
	if str(chosen["part"]) != str(lot["part"]):
		_dialog.call("choose_loose", str(lot["part"]), -1, false)
	if int((_dialog.call("loose_chosen") as Dictionary)["colour"]) != int(lot["colour"]):
		_dialog.call("_pick_colour", int(lot["colour"]))
	(controls["collection_loose_count"] as SpinBox).value = int(lot["qty"])
	var before: int = int(_lot_in(_kept(), str(lot["part"]), int(lot["colour"])).get("qty", 0))
	(controls["collection_loose_add"] as Button).pressed.emit()
	await _changed()
	await _settled()
	return int(_lot_in(_kept(), str(lot["part"]), int(lot["colour"])).get("qty", 0)) == before + int(lot["qty"])


# -- the account ----------------------------------------------------------------------


## [param account]'s collection as the account has it now: {"sets", "parts"}.
func _account_now(account: Account) -> Dictionary:
	var reply: Dictionary = await _ask(account, HTTPClient.METHOD_GET, null)
	return {"sets": reply.get("sets", []), "parts": reply.get("parts", [])} if reply.has("parts") else reply


## One change sent to [param account]'s collection as the app sends one.
func _post(account: Account, body: Dictionary) -> Dictionary:
	return await _ask(account, HTTPClient.METHOD_POST, body)


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


## Every button, field and count of the dialog in sight inside its sides.
func _in_the_dialog(what: String) -> void:
	var panel: Rect2 = (_dialog as Control).get_global_rect()
	var past := PackedStringArray()
	for found: Node in (_dialog as Node).find_children("*", "Control", true, false):
		if not (found is BaseButton or found is LineEdit or found is SpinBox or found is Label):
			continue
		var control := found as Control
		if not control.is_visible_in_tree() or control.get_parent() is SpinBox:
			continue
		var at: Rect2 = control.get_global_rect()
		if control is Label and not (control as Label).text.contains("this device"):
			continue
		if at.position.x < panel.position.x - 0.5 or at.end.x > panel.end.x + 0.5:
			past.append(str(control.get("text")).left(40) if not str(control.get("text")).is_empty() else str(control.name))
	_check("%s: every control inside the dialog's sides (%d wide)%s" % [what, roundi(panel.size.x),
		"" if past.is_empty() else ": past them " + ", ".join(past.slice(0, 6))], past.is_empty())


## [param window] inside the app's window, its buttons inside it.
func _in_the_window(window: Window, what: String) -> void:
	if window == null:
		_check("%s is shown" % what, false)
		return
	var screen := Rect2i(Vector2i.ZERO, root.size)
	var at := Rect2i(window.position, window.size)
	var ok: Button = (window as ConfirmationDialog).get_ok_button()
	var cancel: Button = (window as ConfirmationDialog).get_cancel_button()
	var inside: bool = screen.encloses(at) and Rect2(Vector2.ZERO, Vector2(window.size)).encloses(ok.get_global_rect()) \
		and Rect2(Vector2.ZERO, Vector2(window.size)).encloses(cancel.get_global_rect())
	_check("%s inside the window (%s in %s), both its buttons inside it" % [what, str(at), str(screen.size)], inside)


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
