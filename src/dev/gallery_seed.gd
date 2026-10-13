## The gallery's first models: what the share panel would send for each.
##
##   godot --path . --resolution 1400x900 --script src/dev/gallery_seed.gd -- \
##       --seed-list=SEEDS.json --seed-out=DIR
##
## SEEDS.json is a list of {"file", "name", "author"}: an LDraw file on disk
## and the title it is shared under. Each is opened in the real app, framed
## as opening frames it, and published through the real Share panel, with
## List it in the gallery and Show who made it ticked, into a SharedModels
## that keeps what it was sent instead of sending it. So each body in DIR
## (<n>.json: name, author, model, image, listed) is byte for byte what the
## app publishes, its picture taken by the panel itself;
## tools/web/gallery_seed.mjs then publishes them as the project's account.
##
## Needs a display (xvfb under heavy): the picture is drawn. Writes nothing
## but DIR. Not --out: the app itself takes that (export a model and quit).
extends SceneTree

var _failures: int = 0


class Keeping extends SharedModels:
	var sent: Array[Dictionary] = []

	func publish(_token: String, body: Dictionary) -> Dictionary:
		sent.append(body.duplicate())
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 201, "body": {"id": "Seed%06d" % sent.size(), "url": "", "embed": "",
			"parts": 0, "updated": false, "listed": body.get("listed", false) == true}}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"shared": []}}


func _initialize() -> void:
	_run()


func _arg(name: String) -> String:
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--%s=" % name):
			return given.substr(name.length() + 3)
	return ""


func _run() -> void:
	# Nothing goes to any server from here.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var seeds_at: String = _arg("seed-list")
	var out: String = _arg("seed-out")
	var seeds: Variant = JSON.parse_string(FileAccess.get_file_as_string(seeds_at)) if not seeds_at.is_empty() else null
	if not seeds is Array or out.is_empty():
		push_error("gallery_seed: --seed-list=SEEDS.json --seed-out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame

	var keeping := Keeping.new()
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_shared", keeping)
	root.add_child(main)
	for _n: int in 240:
		await process_frame
	var account: Account = main.get("_account")
	var store: ModelStore = main.get("_store")
	var bar: ModelBar = main.get("_bar")
	var panel: SharePanel = main.get("_share_panel")
	# Signed in as far as the panel can tell; the token goes nowhere.
	account.email = "gallery@brickworks.diy"
	account._access = "seed.not.sent"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()

	var n: int = 0
	for seed: Variant in seeds:
		n += 1
		var file: String = str((seed as Dictionary).get("file", ""))
		var name: String = str((seed as Dictionary).get("name", ""))
		var author: String = str((seed as Dictionary).get("author", "Brickworks"))
		var text: String = FileAccess.get_file_as_string(file)
		if text.is_empty() or name.is_empty():
			_ok(false, "%s: nothing to read, or no name" % file)
			continue
		var opened: Dictionary = store.open_text(text, name)
		if not str(opened["error"]).is_empty():
			_ok(false, "%s: %s" % [file, opened["error"]])
			continue
		store.title = name
		bar.opened.emit(int(opened["placed"]))
		for _n: int in 3600:
			await process_frame
			if store.awaited.is_empty():
				break
		await _settle()
		if panel.visible:
			panel.visible = false
		panel.open()
		panel._name.text = name
		panel._credit.button_pressed = true
		panel._author.text = author
		panel._list.button_pressed = true
		var before: int = keeping.sent.size()
		await panel.publish()
		if keeping.sent.size() == before:
			_ok(false, "%s: the panel sent nothing (%s)" % [name, panel._status.text])
			continue
		var body: Dictionary = keeping.sent[-1]
		var png: PackedByteArray = Marshalls.base64_to_raw(str(body.get("image", "")))
		var picture := Image.new()
		var read: int = picture.load_png_from_buffer(png) if not png.is_empty() else ERR_FILE_EOF
		var kept := FileAccess.open(out.path_join("%d.json" % n), FileAccess.WRITE)
		kept.store_string(JSON.stringify(body))
		kept.close()
		if read == OK:
			picture.save_png(out.path_join("%d.png" % n))
		_ok(read == OK and body.get("listed") == true and str(body.get("author", "")) == author
			and str(body.get("name", "")) == name,
			"%s: %d parts, a %s picture of %d KB, listed, credited to %s" % [name, int(opened["placed"]),
				picture.get_size() if read == OK else Vector2i.ZERO, png.size() / 1024, author])
		panel.visible = false
		# The next one is new work, not a republish of this one.
		store.share_id = ""
		await _settle()

	print("")
	print("%d FAILED" % _failures if _failures else "the gallery's models, as the app shares them, in %s" % out)
	quit(1 if _failures else 0)


func _settle() -> void:
	for _n: int in 30:
		await process_frame
	await RenderingServer.frame_post_draw


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
