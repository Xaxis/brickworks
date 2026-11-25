## sitehair: a mould saved in the minifig builder, signed in, is kept on the
## account, for the site's own minifig maker to wear (MouldsOnAccount,
## api/_moulds.js, supabase/own_moulds.sql).
##
##   BRICKWORKS_API=http://127.0.0.1:PORT BW_PROBE_TOKEN=T BW_PROBE_USER=U BW_MOULD_OUT=FILE \
##     godot --path . --resolution 1280x800 --script src/dev/sitehair_probe.gd -- --pictures=DIR
##
## --pictures: the builder with the figure wearing the first mould, as the
## studio shows it (studio_mould_<width>.png).
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
## 2. Signed out, a second mould saved is kept on the device only, and
##    nothing is sent.
## 3. Signed in again, the builder opened: the one the account lacked is
##    sent (the sweep), once, and the account lists both.
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
	var pictures: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			pictures = arg.trim_prefix("--pictures=")
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
	if not pictures.is_empty() and DisplayServer.get_name() != "headless":
		await _frames(90)
		DirAccess.make_dir_recursive_absolute(pictures)
		var image: Image = root.get_texture().get_image()
		var file_name: String = pictures.path_join("studio_mould_%d.png" % image.get_width())
		image.save_png(file_name)
		print("  the studio's picture: %s" % file_name)
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

	print("\n2. saved signed out: kept on the device only")
	_account.state = Account.State.SIGNED_OUT
	_figures.mould_on_account = null
	var second: String = await _make_mould(9.0)
	await _frames(60)
	_ok(not second.is_empty() and second != first, "  a second mould is saved as %s" % second)
	_ok(_figures.mould_on_account == null, "  nothing was sent")
	listed = await _listed()
	_ok(not listed.has(second), "  the account does not list it")

	print("\n3. signed in again: the builder sends what the account lacks")
	_signed_in()
	MouldsOnAccount.swept_for = ""
	var sent: Array[String] = await MouldsOnAccount.sweep(_account, _main.get("_library"))
	_ok(sent.size() == 1 and sent[0] == second, "  the sweep sent the one it lacked (%s)" % [sent])
	listed = await _listed()
	_ok(listed.has(first) and listed.has(second), "  the account lists both (%d)" % listed.size())
	var again: Array[String] = await MouldsOnAccount.sweep(_account, _main.get("_library"))
	_ok(again.is_empty(), "  a second sweep in the same run sends nothing")

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


## A mould of 3901 made and saved in the builder's own editor, a pull of
## [param radius] on its crown: its id, or "".
func _make_mould(radius: float) -> String:
	_figures._slot = "headwear"
	var editor: MouldEditor = _figures.mould_editor()
	editor.open("3901", "headwear", 70)
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
