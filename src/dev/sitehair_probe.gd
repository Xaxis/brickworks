## sitehair: a mould saved in the minifig builder, signed in, is kept on the
## account, for the site's own minifig maker to wear (MouldsOnAccount,
## api/_moulds.js, supabase/own_moulds.sql).
##
##   BRICKWORKS_API=http://127.0.0.1:PORT BW_PROBE_TOKEN=T BW_PROBE_USER=U BW_MOULD_OUT=FILE \
##     godot --headless --path . --script src/dev/sitehair_probe.gd
##
## PORT is a relay serving this checkout's api (tools/web/relay_server.mjs),
## T and U a throwaway account's access token and id
## (tools/web/sitehair_flow.mjs mints them and runs this). Without them the
## mould is made and written to FILE, and the account's part is SKIPPED.
##
## 1. The studio as a person opens it: the builder, Headgear, Make a mould…
##    on 3901, a pull on its crown, Save. Signed in, the account has it at
##    once, under its own id, for the headwear slot, with as many triangles,
##    and the builder says so; the text written to FILE is the part's own.
## 2. Signed out, a second mould saved is kept on the device only, nothing
##    is sent, and the builder says why.
## 3. Signed in again, the builder opened (hairfix, hairreview H1): the one
##    made signed out is not sent by itself; the builder asks whether it is
##    hers, and once she says so it is sent, and the account lists both.
## 4. A mould a model brought (in the folder, in no ledger) is never sent.
## 5. Shaped further from her own and saved (H2): the new one takes the
##    old one's place on the account.
## 6. A mould the account refused for what it is is not sent again (L3).
## 7. Her account full (L2): the studio's own words, in de, fr and es.
##
## Made parts and drafts go to user://sitehair_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://sitehair_probe/"

var _failures: int = 0
var _main: Node
var _figures: MinifigDialog
var _account: Account
var _token: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	_token = OS.get_environment("BW_PROBE_TOKEN")
	var out: String = OS.get_environment("BW_MOULD_OUT")
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR + "parts/"
	MouldEditor.drafts = PROBE_DIR + "drafts/"
	Minifig.shelf_file = PROBE_DIR + "shelf.json"
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	_account = _main.get("_account")
	_figures = _main.get("_figures")
	if _token.is_empty():
		_signed_out()
	else:
		_signed_in()
	_ok(_figures.account == _account, "the builder has the app's account")
	_main.call("_open_figures")
	await _frames(10)

	print("\n1. saved signed in: kept on the account")
	var first: String = await _make_mould(6.0)
	_ok(not first.is_empty(), "  the mould is saved as %s" % first)
	var text: String = FileAccess.get_file_as_string(CustomParts.dir + first + ".dat")
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		print("  its text, %d bytes, written to %s" % [text.to_utf8_buffer().size(), out])
	_ok(_figures.figure.part("headwear") == first, "  the figure wears it (%s)" % _figures.figure.part("headwear"))
	if _token.is_empty():
		print("\nsitehair probe: SKIPPED (no BW_PROBE_TOKEN: the mould was made, nothing was sent)")
		_forget(PROBE_DIR)
		quit(0 if _failures == 0 else 1)
		return
	var said: Variant = await _answer()
	_ok(said is String and str(said).is_empty(), "  the account kept it (said: %s)" % [said])
	_ok(_figures._summary.text.contains(MouldsOnAccount.KEPT), "  the builder says so: \"%s\"" % _figures._summary.text)
	var listed: Dictionary = await _listed()
	var row: Dictionary = listed.get(first, {})
	_ok(not row.is_empty(), "  the account lists %s" % first)
	_ok(str(row.get("slot", "")) == "headwear" and str(row.get("base", "")) == "3901",
		"  for the headwear slot, shaped from 3901 (%s, %s)" % [row.get("slot"), row.get("base")])
	var triangles: int = text.count("\n3 ") + (1 if text.begins_with("3 ") else 0)
	_ok(int(row.get("triangles", -1)) == triangles and int(row.get("bytes", -1)) == text.to_utf8_buffer().size(),
		"  with its %d triangles and %d bytes (%s, %s)" % [triangles, text.to_utf8_buffer().size(),
			row.get("triangles"), row.get("bytes")])
	var back: Dictionary = await _fetch("/api/people?op=mould&id=" + first)
	_ok(int(back.get("code", 0)) == 200 and back.get("body") is Dictionary
		and str((back["body"] as Dictionary).get("text", "")) == text, "  its text comes back exactly")

	var entry: Dictionary = _entry(first)
	_ok(str(entry.get("by", "")) == _account.user_id and bool(entry.get("sent", false)),
		"  the device's ledger has it as hers, sent (%s)" % [entry])

	print("\n2. saved signed out: kept on the device only")
	_account.state = Account.State.SIGNED_OUT
	_figures.mould_on_account = null
	var sends: int = MouldsOnAccount.sends
	var second: String = await _make_mould(9.0)
	await _frames(60)
	_ok(not second.is_empty() and second != first, "  a second mould is saved as %s" % second)
	_ok(_figures.mould_on_account == null and MouldsOnAccount.sends == sends, "  nothing was sent")
	_ok(_figures._summary.text.contains(MouldsOnAccount.NOT_KEPT % MouldsOnAccount.SIGNED_OUT),
		"  the builder says why: \"%s\"" % _figures._summary.text)
	_ok(str(_entry(second).get("by", "?")) == "", "  the ledger has it as made by nobody signed in")
	listed = await _listed()
	_ok(not listed.has(second), "  the account does not list it")

	print("\n3. signed in again: the builder asks before it sends one made signed out")
	_figures.close()
	await _frames(5)
	_signed_in()
	MouldsOnAccount.swept_for = ""
	sends = MouldsOnAccount.sends
	_main.call("_open_figures")
	var asked: bool = await _until(func() -> bool: return _figures._claim.visible, 30.0)
	_ok(MouldsOnAccount.sends == sends, "  opening the builder sent nothing (%d sends)" % (MouldsOnAccount.sends - sends))
	_ok(asked and _figures._claim_words.text == MouldsOnAccount.ASK_ONE,
		"  it asks: \"%s\"" % _figures._claim_words.text)
	listed = await _listed()
	_ok(not listed.has(second), "  the account still does not list it")
	await _figures._claim_them()
	listed = await _listed()
	_ok(listed.has(first) and listed.has(second), "  said to be hers, it is sent: the account lists both (%d)" % listed.size())
	_ok(_figures._summary.text.contains(MouldsOnAccount.CLAIMED % 1), "  and the builder says so: \"%s\""
		% _figures._summary.text)
	_ok(MouldsOnAccount.unclaimed(_account).is_empty(), "  and asks no more")
	MouldsOnAccount.swept_for = ""
	sends = MouldsOnAccount.sends
	var again: Array[String] = await MouldsOnAccount.sweep(_account, _main.get("_library"))
	_ok(again.is_empty() and MouldsOnAccount.sends == sends, "  a sweep after sends nothing")

	print("\n4. a mould a model brought is never sent")
	var carried: String = second.left(second.length() - 6) + "abcdef"
	var copy := FileAccess.open(CustomParts.dir + carried + ".dat", FileAccess.WRITE)
	copy.store_string(text.replace(first, carried))
	copy.close()
	_ok(MouldsOnAccount.kept_moulds().has(carried), "  it is in the device's folder (%s)" % carried)
	MouldsOnAccount.swept_for = ""
	sends = MouldsOnAccount.sends
	again = await MouldsOnAccount.sweep(_account, _main.get("_library"))
	_ok(again.is_empty() and MouldsOnAccount.sends == sends and not MouldsOnAccount.unclaimed(_account).has(carried),
		"  the sweep sends nothing and the builder asks nothing of it")

	print("\n5. shaped further from her own: the new one takes its place")
	var third: String = await _make_mould(5.0, second)
	_ok(not third.is_empty() and third != second, "  saved as %s" % third)
	_ok(str(_entry(third).get("replaces", "")) == second, "  the ledger says it replaces %s" % second)
	await _answer()
	listed = await _listed()
	_ok(listed.has(third) and not listed.has(second) and listed.has(first),
		"  the account lists it in place of the one before (%s)" % [listed.keys()])
	_ok(FileAccess.file_exists(CustomParts.dir + second + ".dat"), "  the studio keeps the one before")

	print("\n6. refused for what it is: not sent again")
	var broken: String = first.left(first.length() - 6) + "fedcba"
	var bad := FileAccess.open(CustomParts.dir + broken + ".dat", FileAccess.WRITE)
	bad.store_string(text.replace(first, broken))
	bad.close()
	MouldsOnAccount.made(broken, "headwear", _account)
	MouldsOnAccount.swept_for = ""
	sends = MouldsOnAccount.sends
	await MouldsOnAccount.sweep(_account, _main.get("_library"))
	var refused: Dictionary = _entry(broken).get("refused", {})
	_ok(MouldsOnAccount.sends == sends + 1 and int(refused.get("status", 0)) == 400,
		"  sent once and refused (%s)" % [refused])
	MouldsOnAccount.swept_for = ""
	sends = MouldsOnAccount.sends
	await MouldsOnAccount.sweep(_account, _main.get("_library"))
	_ok(MouldsOnAccount.sends == sends, "  the next sweep does not send it again")

	print("\n7. the studio's own words for a refusal, in each language")
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		for why: String in [MouldsOnAccount.NO_ROOM, MouldsOnAccount.TOO_BIG, MouldsOnAccount.NOT_A_MOULD,
				MouldsOnAccount.TOO_MANY, MouldsOnAccount.NOT_OPEN]:
			var whole: String = MouldsOnAccount.NOT_KEPT % why
			_ok(not Language.says(whole).is_empty() and Language.left_in_english(whole).is_empty(),
				"  %s: \"%s\"" % [code, Language.says(whole)])
		_ok(not Language.says(MouldsOnAccount.ASK_MANY % 3).is_empty(), "  %s: \"%s\""
			% [code, Language.says(MouldsOnAccount.ASK_MANY % 3)])
	Language.apply("en")

	_forget(PROBE_DIR)
	print("\nsitehair probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _signed_in() -> void:
	_account.email = "sitehair-probe@example.invalid"
	_account.user_id = OS.get_environment("BW_PROBE_USER")
	_account._access = _token
	_account._expires_at = Time.get_unix_time_from_system() + 3000.0
	_account.state = Account.State.SIGNED_IN
	_account.changed.emit()


func _signed_out() -> void:
	_account.state = Account.State.SIGNED_OUT


## The ledger's entry for [param id], made by whoever is signed in now
## (by nobody, signed out): {} for none.
func _entry(id: String) -> Dictionary:
	var by: String = _account.user_id if _account.signed_in() else ""
	for one: Dictionary in MouldsOnAccount.ledger():
		if str(one.get("id", "")) == id and (str(one.get("by", "")) == by or not _account.signed_in()):
			return one
	return {}


## Whether [param test] came true within [param seconds].
func _until(test: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if test.call():
			return true
		await process_frame
	return bool(test.call())


## A mould of [param from] (3901, or a mould of hers to shape further)
## made and saved in the builder's own editor, a pull of [param radius] on
## its crown: its id, or "".
func _make_mould(radius: float, from: String = "3901") -> String:
	_figures._slot = "headwear"
	_figures.mould_on_account = null
	var editor: MouldEditor = _figures.mould_editor()
	editor.open(from, "headwear", 70)
	await _frames(5)
	var mould: Mould = editor.mould
	if mould == null:
		return ""
	var crown: int = -1
	for v: int in mould.positions.size():
		if mould.locks[v] == 0.0 and (crown < 0 or mould.positions[v].y > mould.positions[crown].y):
			crown = v
	editor._begin_step()
	mould.dab("pull", mould.positions[crown], mould.normals[crown], radius, 0.8, true)
	editor._release()
	var before: Array[String] = MouldsOnAccount.kept_moulds()
	editor._name.text = "Quiff %d" % int(radius)
	await editor._save_mould()
	await _frames(5)
	for id: String in MouldsOnAccount.kept_moulds():
		if not before.has(id):
			return id
	return ""


## What the account said of the last mould sent, once it has: "" kept, or
## why not; null after 30 s.
func _answer() -> Variant:
	var until: int = Time.get_ticks_msec() + 30000
	while _figures.mould_on_account == null and Time.get_ticks_msec() < until:
		await process_frame
	return _figures.mould_on_account


## The account's moulds: {id: row}.
func _listed() -> Dictionary:
	var reply: Dictionary = await _fetch("/api/people?op=moulds")
	var rows: Dictionary = {}
	var body: Variant = reply.get("body")
	if body is Dictionary:
		for one: Variant in (body as Dictionary).get("moulds", []):
			rows[str((one as Dictionary).get("id", ""))] = one
	return rows


func _fetch(path: String) -> Dictionary:
	return await _account._fetch(Deployment.api_base() + path,
		PackedStringArray(["authorization: Bearer " + _token]), HTTPClient.METHOD_GET, "")


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _ok(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
