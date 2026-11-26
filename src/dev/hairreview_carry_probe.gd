## hairreview: does the studio send a mould to the account that is not this
## account's own? (review of sitehair, MouldsOnAccount.sweep).
##
##   BRICKWORKS_API=http://127.0.0.1:PORT BW_PROBE_TOKEN=T BW_PROBE_USER=U \
##   BW_PROBE_TOKEN2=T2 BW_PROBE_USER2=U2 BW_CARRIED=FILE \
##     godot --headless --path . --script src/dev/hairreview_carry_probe.gd
##
## PORT is a relay serving this checkout's api; T/U and T2/U2 two throwaway
## accounts (Ada and Cy); FILE a mould the app made for somebody else (Bo).
##
## 1. Ada opens a model Bo made, as a file: it carries Bo's mould. She makes
##    nothing. She opens the figure builder.
## 2. Ada signs out. Saved signed out, a mould of hers is kept on the device.
## 3. Cy signs in on the same device and opens the figure builder.
## Each step says what reached which account: FINDING lines are the harm.
extends SceneTree

const PROBE_DIR := "user://hairreview_probe/"

var _main: Node
var _figures: MinifigDialog
var _account: Account
var _findings: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var carried: String = FileAccess.get_file_as_string(OS.get_environment("BW_CARRIED"))
	var bo_id: String = ""
	for line: String in carried.split("\n"):
		if line.begins_with("0 Name: "):
			bo_id = line.trim_prefix("0 Name: ").trim_suffix(".dat").strip_edges()
	if carried.is_empty() or bo_id.is_empty() or OS.get_environment("BW_PROBE_TOKEN").is_empty():
		print("hairreview carry probe: SKIPPED (BW_CARRIED and BW_PROBE_TOKEN are wanted)")
		quit(3)
		return
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
	_sign_in("BW_PROBE_TOKEN", "BW_PROBE_USER")
	var ada: String = OS.get_environment("BW_PROBE_TOKEN")
	print("SEEN Ada's account lists %d moulds before" % (await _listed(ada)).size())

	print("\n1. Ada opens a model Bo made (a file that carries his mould), makes nothing, opens the figure builder")
	var model: String = "0 FILE bo_hair.ldr\n0 Bo's figure\n0 Name: bo_hair.ldr\n0 Author: Bo\n" \
		+ "1 16 0 0 0 1 0 0 0 1 0 0 0 1 %s.dat\n0 NOFILE\n0 FILE %s.dat\n%s0 NOFILE\n" % [bo_id, bo_id, carried]
	var path: String = ProjectSettings.globalize_path(PROBE_DIR + "bo_hair.mpd")
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(model)
	file.close()
	var bar: Node = _main.get("_bar")
	_main.call("clear_model")
	await _frames(4)
	var placed: int = await bar.open_with_progress(path)
	bar.opened.emit(placed)
	await _frames(30)
	print("SEEN the model opened with %d parts" % placed)
	var kept: bool = FileAccess.file_exists(CustomParts.dir + bo_id + ".dat")
	print("SEEN Bo's mould kept on Ada's device as one of hers: %s (kept_moulds %s)"
		% [kept, MouldsOnAccount.kept_moulds()])
	_main.call("_open_figures")
	var listed: Dictionary = await _wait_for(ada, bo_id, 40.0)
	_say(listed.has(bo_id), "Bo's mould, which Ada never made or chose, is now on Ada's account as her own (%d listed)"
		% listed.size(), "Bo's mould stayed off Ada's account")
	_figures = _main.get("_figures")
	_figures.close()
	await _frames(5)

	if OS.get_environment("BW_PROBE_TOKEN2").is_empty():
		_end()
		return
	print("\n2. Ada signs out; a mould saved signed out stays on the device")
	_account.state = Account.State.SIGNED_OUT
	_account.changed.emit()
	_main.call("_open_figures")
	await _frames(5)
	var hers: String = await _make_mould(7.0)
	print("SEEN saved signed out: %s" % hers)
	_figures.close()
	await _frames(5)

	print("\n3. Cy signs in on the same device and opens the figure builder")
	_sign_in("BW_PROBE_TOKEN2", "BW_PROBE_USER2")
	var cy: String = OS.get_environment("BW_PROBE_TOKEN2")
	_main.call("_open_figures")
	var cys: Dictionary = await _wait_for(cy, hers, 40.0)
	_say(cys.has(hers), "the mould Ada saved signed out is now on Cy's account (%d listed: %s)"
		% [cys.size(), cys.keys()], "Cy's account got nothing of Ada's")
	_say(cys.has(bo_id), "and Bo's carried mould is on Cy's account too", "Bo's mould is not on Cy's")
	_end()


func _end() -> void:
	_forget(PROBE_DIR)
	print("\nhairreview carry probe: %d FINDINGS" % _findings)
	quit(0)


func _say(harm: bool, finding: String, clean: String) -> void:
	if harm:
		_findings += 1
		print("FINDING " + finding)
	else:
		print("CLEAN " + clean)


func _sign_in(token_var: String, user_var: String) -> void:
	_account.email = "hairreview-probe@example.invalid"
	_account.user_id = OS.get_environment(user_var)
	_account._access = OS.get_environment(token_var)
	_account._expires_at = Time.get_unix_time_from_system() + 3000.0
	_account.state = Account.State.SIGNED_IN
	_account.changed.emit()


## A mould of 3901 made and saved in the builder's own editor: its id, or "".
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
	editor._name.text = "Ada's own %d" % int(radius)
	await editor._save_mould()
	await _frames(5)
	for id: String in MouldsOnAccount.kept_moulds():
		if not before.has(id):
			return id
	return ""


## The account's moulds once [param id] is listed, or after [param seconds].
func _wait_for(token: String, id: String, seconds: float) -> Dictionary:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var rows: Dictionary = {}
	while Time.get_ticks_msec() < until:
		rows = await _listed(token)
		if rows.has(id):
			return rows
		await _frames(30)
	return rows


func _listed(token: String) -> Dictionary:
	var reply: Dictionary = await _account._fetch(Deployment.api_base() + "/api/people?op=moulds",
		PackedStringArray(["authorization: Bearer " + token]), HTTPClient.METHOD_GET, "")
	var rows: Dictionary = {}
	var body: Variant = reply.get("body")
	if body is Dictionary:
		for one: Variant in (body as Dictionary).get("moulds", []):
			rows[str((one as Dictionary).get("id", ""))] = one
	return rows


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
