## The gallery's first models: what the share panel would send for each.
##
##   godot --path . --resolution 1400x900 --script src/dev/gallery_seed.gd -- \
##       --seed-list=SEEDS.json --seed-out=DIR
##
## SEEDS.json is a list of {"file", "name", "author", "about", "tags",
## "kind", "licence", "turn", "note", "credit"}: an LDraw file (a path from the
## project's folder, or absolute), the title it is shared under, and what its
## page and the gallery say about it; "turn" is [yaw, pitch] in degrees, the
## way the view is turned before its picture is taken (the app's own opening
## view when not said); "note" is what changed, as the panel's What changed?
## box says it for a link already up, sent only when the model is published
## again at its link (gallery_seed.mjs); "credit" is {"by", "licence",
## "page"} for a model somebody else made, from LDraw's Official Model
## Repository: kept in its file as the library's credit is
## (ModelStore.credit), which the site credits it by, and its licence then
## may be one the panel's menu does not offer (cc-by-2.0).
## tools/web/gallery_seeds/seeds.json is the project's list,
## tools/web/gallery_seeds/ldraw_library.json the shelf from the LDraw
## library (tools/house_models/ldraw_shelf.py). Each is opened in the real app, framed as opening
## frames it, and published through the real Share panel — its words typed
## into the panel's boxes, its kind and licence chosen in its menus, List it
## in the gallery and Show who made it ticked — into a SharedModels that
## keeps what it was sent instead of sending it. So each body in DIR
## (<n>.json: name, author, model, image, thumb, description, tags, kind,
## licence, listed, tested, and the note) is byte for byte what the app
## publishes, its pictures taken and its tests run by the panel itself;
## tools/web/gallery_seed.mjs then publishes them as the project's account.
## A list of some of them republishes only those.
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
	var camera: CadCamera = main.get("_camera")
	# Signed in as far as the panel can tell; the token goes nowhere. Only
	# once the app has given up asking the unreachable server who is here:
	# it asks again since 2026-10-20, and its answer, signed out, came in
	# after the first model and signed the rest out of the panel.
	var asking_until: float = Time.get_ticks_msec() + 120000.0
	while account.state == Account.State.CHECKING and Time.get_ticks_msec() < asking_until:
		await process_frame
	account.email = "gallery@brickworks.diy"
	account._access = "seed.not.sent"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()

	var n: int = 0
	for seed: Variant in seeds:
		n += 1
		var said: Dictionary = seed
		var file: String = str(said.get("file", ""))
		if file.is_relative_path():
			file = ProjectSettings.globalize_path("res://").path_join(file)
		var name: String = str(said.get("name", ""))
		var author: String = str(said.get("author", "Brickworks"))
		var about: String = str(said.get("about", "")).strip_edges()
		var tags: String = ", ".join(PackedStringArray(said.get("tags", [])))
		var kind: String = str(said.get("kind", ""))
		var licence: String = str(said.get("licence", "cc-by-4.0"))
		var kind_at: int = ModelKinds.ids().find(kind) + 1 if not kind.is_empty() else 0
		var licence_at: int = -1
		for at: int in SharePanel.LICENCES.size():
			if str(SharePanel.LICENCES[at][0]) == licence:
				licence_at = at
		# Someone else's model from the library: its credit as the app keeps
		# it when the library opens it (ModelLibrary.credit_of), and its own
		# licence, which the panel's menu may not offer (CC BY 2.0, LDraw's
		# CCAL 2.0): said for it, as the note is.
		var credit: Dictionary = said.get("credit", {}) if said.get("credit") is Dictionary else {}
		var licence_said: bool = licence_at < 0 and not credit.is_empty()
		if licence_said:
			licence_at = 0
		var text: String = FileAccess.get_file_as_string(file)
		if text.is_empty() or name.is_empty() or (not kind.is_empty() and kind_at == 0) or licence_at < 0:
			_ok(false, "%s: nothing to read, no name, or a kind or licence the panel does not offer" % file)
			continue
		var opened: Dictionary = store.open_text(text, name)
		if not str(opened["error"]).is_empty():
			_ok(false, "%s: %s" % [file, opened["error"]])
			continue
		store.title = name
		if not credit.is_empty():
			store.credit = {"by": str(credit.get("by", "")), "licence": str(credit.get("licence", "")),
				"page": str(credit.get("page", "")), "from": ModelLibrary.FROM}
		bar.opened.emit(int(opened["placed"]))
		for _n: int in 3600:
			await process_frame
			if store.awaited.is_empty():
				break
		# The way the view is turned, as the view cube or a drag turns it:
		# the picture is taken from where the view looks.
		camera.set_view("")
		var turn: Variant = said.get("turn")
		if turn is Array and (turn as Array).size() == 2:
			var yaw: float = deg_to_rad(float(turn[0]))
			var pitch: float = deg_to_rad(float(turn[1]))
			camera.look_from(Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)))
		await _settle()
		await _settle()
		if panel.visible:
			panel.visible = false
		panel.open()
		panel._name.text = name
		panel._credit.button_pressed = true
		panel._author.text = author
		panel._about.text = about
		panel._tags.text = tags
		panel._tags.text_changed.emit(tags)
		if kind_at > 0:
			panel._kind.select(kind_at)
			panel._kind.item_selected.emit(kind_at)
		panel._licence.select(licence_at)
		panel._licence.item_selected.emit(licence_at)
		panel._list.button_pressed = true
		var before: int = keeping.sent.size()
		await panel.publish()
		if keeping.sent.size() == before:
			_ok(false, "%s: the panel sent nothing (%s)" % [name, panel._status.text])
			continue
		var body: Dictionary = keeping.sent[-1]
		# The panel shows What changed? only for a link it already has,
		# which here it never does: said for it, as that box sends it.
		var note: String = str(said.get("note", "")).strip_edges()
		if not note.is_empty():
			body["note"] = note
		if licence_said:
			body["licence"] = licence
		var png: PackedByteArray = Marshalls.base64_to_raw(str(body.get("image", "")))
		var picture := Image.new()
		var read: int = picture.load_png_from_buffer(png) if not png.is_empty() else ERR_FILE_EOF
		var webp: PackedByteArray = Marshalls.base64_to_raw(str(body.get("thumb", "")))
		var small := Image.new()
		var read_small: int = small.load_webp_from_buffer(webp) if not webp.is_empty() else ERR_FILE_EOF
		var kept := FileAccess.open(out.path_join("%d.json" % n), FileAccess.WRITE)
		kept.store_string(JSON.stringify(body))
		kept.close()
		if read == OK:
			picture.save_png(out.path_join("%d.png" % n))
		if read_small == OK:
			small.save_png(out.path_join("%d-thumb.png" % n))
		_ok(read == OK and body.get("listed") == true and str(body.get("author", "")) == author
			and str(body.get("name", "")) == name,
			"%s: %d parts, a %s picture of %d KB, listed, credited to %s" % [name, int(opened["placed"]),
				picture.get_size() if read == OK else Vector2i.ZERO, png.size() / 1024, author])
		_ok(read_small == OK and small.get_size() == SharePanel.THUMB,
			"%s: a %s card picture of %d KB" % [name, small.get_size() if read_small == OK else Vector2i.ZERO,
				webp.size() / 1024])
		_ok(str(body.get("description", "")) == about and str(body.get("tags", "")) == tags
			and str(body.get("kind", "")) == kind and str(body.get("licence", "")) == licence,
			"%s: about it \"%s\", tags \"%s\", kind %s, %s" % [name, about.left(60), tags,
				str(body.get("kind", "")), str(body.get("licence", ""))])
		if not credit.is_empty():
			var carried: Dictionary = ModelStore.credit_in(str(body.get("model", "")))
			_ok(str(carried.get("by", "")) == str(credit.get("by", "")) and carried.get("page") == credit.get("page"),
				"%s: its file credits %s (%s)" % [name, str(carried.get("by", "nobody")), str(carried.get("page", ""))])
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
