## A model shared by link, in the app: the read-only viewer that opens a
## link (/app?view=<id>), and the panel that shares a model (File › Share…).
##
##   godot --path . --resolution 1400x900 --script src/dev/share_view_probe.gd
##
## No network: api/share.js is played by FakeShared, which answers as the
## endpoint does (tools/web/share_probe.mjs proves the endpoint itself).
## The model is made here, in a library of its own, with a part made in
## the element maker and a printed tile, so both reach the viewer only
## inside the file, as they do from a link.
##
## The viewer: no sign-in screen; the account, the store, the layout and
## made parts all set to write nothing; the model open with its name,
## author and part count, the made part and the print built from the file
## and not kept; the builder's bars and panels gone; the timeline at the
## finished model and scrubbed back and forth; only looking commands
## allowed; Save refused with nothing on disk; a click, a drag and the
## editing keys changing nothing but the view; the part under the pointer
## outlined and named; the parts list with its BrickLink and Rebrickable
## lists; the booklet; a link taken down saying so.
##
## Versions: the viewer's line saying which version is open and what
## changed in it, or that it is an older one; a builder's place kept on
## version 1 still right on version 2 when it changed after their step, and
## when it changed at or before it, told so and offered the step, in the
## step player and on the viewer; the panel's What changed? for a model with
## a link, sent with its next version, and the version said after.
##
## Build it: the step player pressed on the bar, Next three times to step
## 3, what was built before drawn faded and the new parts in their own
## colours and outlined, their pictures along the bottom, a swipe, the
## arrow keys, a finger turning the model and two pinching it; the step
## kept for the link, and the link opened again straight on it; Close,
## Build it again, and Finish.
##
## Comments on a step: the count on the step the timeline is on and on the
## step player's page ("2 comments" on step 2, none on step 3, the model's
## own on the finished model and the cover); tapped, the step's comments,
## one from an older version saying so; nobody signed in and an account
## under 13 told why, with no box; somebody who may write typing in the box
## (a space in it turning no page) and sending, the comment then in the
## list and the count; a finger on the panel turning neither the page nor
## the model; a page turned closing it.
##
## The panel: Share on a signed-in model, what it sends (the LDraw with
## the made part and the print inside, no link line, the author only when
## ticked, a 1200 x 630 PNG), the link kept with the model and sent back on
## the next publish, Unpublish, a link of another account's replaced by a
## new one, and Clear forgetting it.
##
## Pictures in shots/share/. Made parts go to user://share_probe_parts/,
## lists and the booklet to user://share_probe_out/; both are removed.
extends SceneTree

const SHOTS := "res://shots/share/"
const PARTS_DIR := "user://share_probe_parts/"
const OUT_DIR := "user://share_probe_out/"
const ID := "Pr0beV1ewX"

var _failures: int = 0
var _main: Node


class FakeShared extends SharedModels:
	var answer: Dictionary = {}
	var asked: Array[String] = []
	var published: Array[Dictionary] = []
	var unpublished: Array[String] = []
	## An id the server says belongs to another account.
	var not_ours: String = ""
	## Each link's newest version, as the server counts them.
	var versions: Dictionary = {}
	## What ?op=comments answers (api/people.js), and the comments sent.
	var comment_answer: Dictionary = {}
	var posted: Array[Dictionary] = []

	func fetch(id: String, _version: int = 0) -> Dictionary:
		asked.append(id)
		while answer.is_empty():
			await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func publish(_token: String, body: Dictionary) -> Dictionary:
		published.append(body.duplicate())
		await (Engine.get_main_loop() as SceneTree).process_frame
		if str(body.get("id", "")) == not_ours and not not_ours.is_empty():
			return {"code": 403, "body": {"error": "that link is somebody else's model"}}
		var given: String = str(body.get("id", "NewL1nk%03d" % published.size()))
		var n: int = int(versions.get(given, 0)) + 1
		versions[given] = n
		return {"code": 200 if body.has("id") else 201, "body": {"id": given,
			"url": "https://brickworks.diy/m/" + given, "embed": SharedModels.embed_for(given),
			"parts": 7, "updated": body.has("id"), "listed": body.get("listed", false) == true,
			"version": n, "said": "Version %d: 1 part added in step 2." % n if n > 1 else ""}}

	func unpublish(_token: String, id: String) -> Dictionary:
		unpublished.append(id)
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"id": id, "published": false}}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"shared": []}}

	## No comments on the link unless the probe gave some: as a server
	## from before them answers.
	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		if comment_answer.is_empty():
			return {"code": 400, "body": {"error": "unknown op comments"}}
		return {"code": 200, "body": comment_answer.duplicate(true)}

	func comment(token: String, body: Dictionary) -> Dictionary:
		posted.append(body.merged({"token": token}))
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 201, "body": {"comment": {"id": 100 + posted.size(), "version": body["version"],
			"step": body["step"], "on_step": body["step"], "body": body["body"],
			"at": "2026-10-18T12:00:00+00:00", "edited_at": null, "by": "Probe Reader", "handle": null,
			"by_owner": false, "mine": true, "hidden": false, "older": false,
			"said": "on step %d of version %d" % [int(body["step"]), int(body["version"])]
				if body["step"] != null else "on version %d" % int(body["version"])}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_forget(PARTS_DIR)
	_forget(OUT_DIR)
	CustomParts.dir = PARTS_DIR
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	print("\na model with a made part and a print, made elsewhere")
	var made: Dictionary = _make_model()
	var text: String = made["text"]
	var count: int = made["count"]
	_ok(text.contains("0 FILE %s.dat" % made["brick"]) and text.contains("!DATA"),
		"the file carries the made part and the print's picture (%d parts)" % count)
	_forget(PARTS_DIR)

	print("\nthe viewer")
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe House",
		"author": "Probe Builder", "parts": count, "url": "https://brickworks.diy/m/" + ID,
		"remixed_from": {"id": "0r1g1nM0de", "name": "Probe Original",
			"url": "https://brickworks.diy/m/0r1g1nM0de"},
		"model": text}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", ID)
	_main.set("_shared", fake)
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	await _steps_worked_out()
	_ok(view != null and view.state == "ready", "the shared model opened (%s)" % (
		view.state if view != null else "no viewer"))
	if view == null or view.state != "ready":
		_finish()
		return
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var library: PartLibrary = _main.get("_library")
	var shell: Shell = _main.get("_shell")
	var steps: StepsBar = _main.get("_steps")
	var camera: CadCamera = _main.get("_camera")
	var account: Account = _main.get("_account")

	_ok(fake.asked == [ID], "it asked for the link's model, once (%s)" % [fake.asked])
	_ok(_main.get("_gate") == null, "no sign-in screen: a link is for anybody")
	_ok(not account.keeps and not account.signed_in(), "the account is neither read nor kept")
	_ok(store.read_only and not store.keeps, "the store writes nothing, the autosave included")
	_ok(ShellPrefs.frozen and not ShellPrefs.keeps(), "the layout is neither read nor written")
	_ok(not CustomParts.keeps, "parts the model carries are not kept")
	_ok(shell.read_only, "the shell runs looking commands only")
	var standing: int = world.brick_count() - store.scenery.size()
	_ok(standing == count, "every part of it is standing (%d of %d)" % [standing, count])
	_ok(_has_part(world, str(made["brick"])) and _has_part(world, str(made["tile"])),
		"the made part and the printed tile are in it, built from the file")
	_ok(library.parts.has(str(made["tile"])) and library.custom.has(str(made["tile"])),
		"the print joined this visit's library")
	var kept_parts: PackedStringArray = DirAccess.get_files_at(PARTS_DIR) \
		if DirAccess.dir_exists_absolute(PARTS_DIR) else PackedStringArray()
	_ok(kept_parts.is_empty(), "...and nothing was kept on disk (%s)" % [kept_parts])
	_ok(view.model_name == "Probe House" and view.author == "Probe Builder" and view.parts == count,
		"the bar names it, who made it and its part count (%s, %s, %d)" % [
			view.model_name, view.author, view.parts])
	var bar_said: Dictionary = view.page_state()
	_ok(str(bar_said["about"]).ends_with("· remixed from Probe Original")
		and view.controls_by_name().has("view_remixed_from"),
		"...and what it was remixed from, a line that opens that link (%s)" % bar_said["about"])
	var bar: ModelBar = _main.get("_bar")
	_ok(not bar.visible and not shell.toolbar.visible
		and not (_main.get("_bin_dock") as Control).visible
		and not (_main.get("_chat_dock") as Control).visible,
		"the builder's bar, toolbar, parts bin and assistant are gone")
	_ok(steps.is_playing_back() and steps.timeline_at().x == steps.timeline_at().y,
		"the timeline is up, at the finished model (%s)" % steps.timeline_at())
	_save("1_viewer.png")

	print("\nscrubbing the steps, by pressing the timeline's buttons")
	var on_timeline: Dictionary = steps.controls_by_name()
	await _press(on_timeline["steps_start"])
	var shown_at_start: int = _shown(world, store)
	await _press(on_timeline["steps_next"])
	await _press(on_timeline["steps_next"])
	var shown_two: int = _shown(world, store)
	_ok(shown_at_start == 0 and shown_two > 0 and shown_two < count,
		"back to an empty baseplate, then two steps on: %d, then %d of %d" % [
			shown_at_start, shown_two, count])
	_save("2_steps.png")
	await _press(on_timeline["steps_end"])
	_ok(_shown(world, store) == count, "and End is the whole model again")

	print("\nnothing that edits")
	for name: String in ["new", "open", "save", "save_as", "share", "clear", "account",
			"undo", "paste", "delete", "mirror", "mode_place", "mode_delete", "mode_paint",
			"export_ldraw", "minifig", "part_maker", "connector", "keys", "settings"]:
		if shell.can(name):
			_ok(false, "%s cannot be run" % name)
	_ok(not shell.run("clear") and not shell.run("new"), "no editing command runs (twenty asked)")
	for name: String in ["timeline", "parts_list", "instructions", "fit", "view_front"]:
		_ok(shell.can(name), "%s can" % name)
	_ok(not store.save_as("Probe copy") and not FileAccess.file_exists(
		ModelStore.SAVE_DIR + "Probe copy.ldr"), "Save is refused, and no file is written")
	# The store's one way to disk, asked directly: the autosave and every
	# save go through it. Asked for a file of the probe's own, so a guard
	# that failed would not write over this machine's autosave.
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_ok(not store._write(OUT_DIR + "written.ldr", "x") and not FileAccess.file_exists(
		OUT_DIR + "written.ldr"), "the store's writer refuses, so the autosave cannot be written")
	var kept_file: FileAccess = FileAccess.open(OUT_DIR + "kept.ldr", FileAccess.WRITE)
	kept_file.store_string("0 Kept\n")
	kept_file.close()
	_ok(not store.delete(OUT_DIR + "kept.ldr") and FileAccess.file_exists(OUT_DIR + "kept.ldr"),
		"and it deletes nothing either")

	var before: String = _fingerprint(world)
	var view_rect: Rect2 = (_main.get("_marquee") as Control).get_parent().get_global_rect()
	var middle: Vector2 = view_rect.get_center()
	_click(middle)
	await _settle()
	_ok(_fingerprint(world) == before and (_main.get("_builder") as Builder).selection.is_empty(),
		"a click on the model changes nothing and selects nothing")
	var yaw: float = camera.yaw_turned()
	await _drag(middle, middle + Vector2(160, 0))
	_ok(not is_equal_approx(camera.yaw_turned(), yaw) and _fingerprint(world) == before,
		"a drag turns the view (%.2f to %.2f) and moves no part" % [yaw, camera.yaw_turned()])
	for key: Array in [[KEY_DELETE, false], [KEY_BACKSPACE, false], [KEY_R, false],
			[KEY_X, false], [KEY_C, false], [KEY_Q, false], [KEY_M, false], [KEY_KP_PERIOD, false],
			[KEY_Z, true], [KEY_V, true], [KEY_D, true], [KEY_A, true], [KEY_S, true]]:
		await _key(key[0], key[1])
	_ok(_fingerprint(world) == before and world.brick_count() - store.scenery.size() == count,
		"Delete, R, X, C, Q, M, lift, and Ctrl Z, V, D, A, S change nothing")
	await _key(KEY_1, false)
	await _settle()
	_ok(_fingerprint(world) == before, "1 looks from the front, and nothing moves")

	print("\nthe part under the pointer")
	# The viewer tells the lattice of the parts once the model is up, a
	# slice a frame (ModelStore.lattice_later): what is under a pointer
	# is known a moment after the model is on screen.
	var told_from: int = Time.get_ticks_msec()
	while not (store.get("_unregistered") as Array).is_empty() \
			and Time.get_ticks_msec() - told_from < 30000:
		await process_frame
	_ok(store.lattice_later and (store.get("_unregistered") as Array).is_empty(),
		"the lattice is told of every part after the model is up (%.1f s)"
		% ((Time.get_ticks_msec() - told_from) / 1000.0))
	var target: BrickWorld.Brick = _a_visible_brick(world, store, library, camera, view_rect)
	_ok(target != null, "a part of the model is on screen")
	if target != null:
		var at: Vector2 = camera.unproject_position(_centre(target, library))
		_move(at)
		await _settle()
		await _settle()
		var hovered: int = _main.get("_hovered")
		var outline: SelectionOutline = _main.get("_hover_outline")
		var said: String = str(view.page_state()["hover"])
		_ok(hovered != 0 and outline.visible and not said.is_empty(),
			"it is outlined and named: %s" % said)
		var label: Rect2 = view._hover.get_global_rect()
		_ok(view._hover.visible and Rect2(Vector2.ZERO, view.size).encloses(label)
			and label.position.distance_to(at) < 80.0,
			"...beside the pointer, on screen (%s, pointer at %s)" % [label, at])
		_save("3_hover.png")
		_move(view_rect.position + Vector2(8, 8))
		await _settle()
		_ok(int(_main.get("_hovered")) == 0 or int(_main.get("_hovered")) != hovered,
			"and let go of off it")

	print("\nthe parts list")
	var exports: Exports = _main.get("_exports")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	exports.folder = ProjectSettings.globalize_path(OUT_DIR)
	# Pressed on the bar, as a person does: the cursor's sheet over the
	# window once took every click meant for the viewer's buttons.
	await _press(view.controls_by_name()["view_parts"])
	var inventory: InventoryPanel = _main.get("_inventory")
	_ok(inventory.is_showing() and inventory.controls_by_name().has("parts_bricklink")
		and inventory.controls_by_name().has("parts_rebrickable"),
		"it opens, with BrickLink and Rebrickable lists")
	_save("4_parts.png")
	inventory.shop_wanted.emit("bricklink")
	inventory.shop_wanted.emit("rebrickable")
	var wanted: String = FileAccess.get_file_as_string(OUT_DIR + "probe_house_bricklink.xml")
	var listed: String = FileAccess.get_file_as_string(OUT_DIR + "probe_house_rebrickable.csv")
	_ok(wanted.contains("<INVENTORY>") and wanted.contains("<ITEMID>"),
		"the BrickLink wanted list (%d bytes)" % wanted.length())
	_ok(listed.begins_with("Part,Color,Quantity") or listed.contains(","),
		"the Rebrickable list (%d bytes)" % listed.length())
	inventory.hide_list()

	print("\nthe booklet")
	var said_booklet: String = await _main.call("_export_booklet", OUT_DIR + "booklet.html")
	var booklet: String = FileAccess.get_file_as_string(OUT_DIR + "booklet.html")
	_ok(said_booklet.begins_with("wrote") and booklet.contains("Probe House"),
		"the booklet is made from the viewer: %s" % said_booklet)

	# New work's naming (ModelStore.begin) names and writes nothing: the
	# viewer's files are as they were after it.
	var files_before: PackedStringArray = DirAccess.get_files_at(ModelStore.SAVE_DIR)
	store.begin("Probe new work")
	_ok(store.title == "Probe new work" and DirAccess.get_files_at(ModelStore.SAVE_DIR) == files_before
		and not FileAccess.file_exists(ModelStore.SAVE_DIR + "Probe new work.ldr"),
		"new work's naming writes nothing")

	print("\na link taken down")
	fake.answer = {"code": 410, "body": {"error": "This model is no longer shared.", "unpublished": true}}
	await _main.call("_view_shared")
	await _settle()
	_ok(view.state == "gone" and str(view.page_state()["title"]) == "This model is no longer shared",
		"the viewer says so (%s)" % view.page_state()["title"])
	var card: Rect2 = view._card.get_global_rect()
	_ok(Rect2(Vector2.ZERO, view.size).encloses(card)
		and card.get_center().distance_to(view.size * 0.5) < 4.0,
		"...on a card in the middle of the window (%s in %s)" % [card, view.size])
	_ok(not view.controls_by_name()["view_copy"].visible, "...with nothing to step, read or copy")
	_save("5_gone.png")

	_main.queue_free()
	for _n: int in 10:
		await process_frame
	await _build_it(text, count)
	await _versions(text, count)
	await _comments(text, count)

	# Back as a builder would be: the switches are the app's, not the probe's.
	ShellPrefs.frozen = false
	CustomParts.keeps = true

	await _the_panel(text)
	_forget(PARTS_DIR)
	_forget(OUT_DIR)
	_finish()


## What the next viewer's link answers to ?op=comments, and the token it
## comments with: taken by _open_viewer.
var _next_comments: Dictionary = {}
var _next_token: String = ""
var _fake: FakeShared


## A viewer for the link, opened as a visitor's browser does, against the
## fake: ready to look at, or null.
func _open_viewer(text: String, count: int, more: Dictionary = {}) -> ShareView:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe House",
		"author": "Probe Builder", "parts": count, "url": "https://brickworks.diy/m/" + ID,
		"model": text}}
	(fake.answer["body"] as Dictionary).merge(more, true)
	fake.comment_answer = _next_comments
	_fake = fake
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", ID)
	_main.set("_shared", fake)
	_main.set("comment_token_for_probe", _next_token)
	_next_comments = {}
	_next_token = ""
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	await _steps_worked_out()
	return view if view != null and view.state == "ready" else null


func _close_viewer() -> void:
	_main.queue_free()
	for _n: int in 10:
		await process_frame


## Build it: the step player, pressed on the viewer's bar, stepped through
## with the buttons, a swipe and the arrow keys; what it draws faded and
## outlined; its parts; a finger on the model; and where it was left, kept
## for the link and come back to when the link is opened again.
func _build_it(text: String, count: int) -> void:
	print("\nbuild it: the step player")
	BuildSteps._kept.clear()
	var view: ShareView = await _open_viewer(text, count)
	_ok(view != null, "the link opens again to build from")
	if view == null:
		return
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var steps: StepsBar = _main.get("_steps")
	var camera: CadCamera = _main.get("_camera")
	var library: PartLibrary = _main.get("_library")
	_ok(view.controls_by_name().has("view_build"), "the bar has Build it")
	await _press(view.controls_by_name()["view_build"])
	await _settle()
	var mode: BuildMode = _main.get("_build_mode")
	var pages: BuildSteps = _main.get("_build_pages")
	_ok(mode != null and mode.is_open() and pages != null, "Build it opens the step player")
	if mode == null or not mode.is_open() or pages == null:
		await _close_viewer()
		return
	var said: Dictionary = _main.call("build_state")
	_ok(not view._bar.is_visible_in_tree() and not steps.is_playing_back()
		and not (_main.get("_gizmo") as Control).visible,
		"...over the whole window: the bar, the timeline and the view cube put away")
	_ok(said["page"] == 0 and said["caption"] == "Ready to build" and said["next"] == "Start"
		and not said["back_enabled"] and int(said["shown"]) == count and int(said["faded"]) == 0,
		"it opens on the finished model, Ready to build, Start, no Back (%s)" % said["note"])
	var sizes: Dictionary = said["points"]
	_ok((sizes["build_next"] as Array)[1] >= 46 and (sizes["build_back"] as Array)[1] >= 46
		and int(said["caption_points"]) >= 20,
		"Next and Back are a fingertip tall (%s, %s points) and the step is %d-point words"
		% [sizes["build_next"], sizes["build_back"], said["caption_points"]])
	_save("9_build_cover.png")

	var controls: Dictionary = mode.controls_by_name()
	for _n: int in 3:
		await _press(controls["build_next"])
	said = _main.call("build_state")
	var fresh: Dictionary = pages.fresh(3)
	var faded: Dictionary = pages.faded(3)
	_ok(said["page"] == 3 and str(said["caption"]).begins_with("Step 3 of %d" % pages.last()),
		"Next three times: %s" % said["caption"])
	_ok(world.faded_ids() == faded and not faded.is_empty() and world.xray_ids().is_empty(),
		"what steps 1 and 2 built is drawn faded (%d parts), solid, not as x-ray's ghosts"
		% faded.size())
	_ok(_shown(world, store) == faded.size() + fresh.size(),
		"...this step's %d new parts beside it, and nothing after (%d on the baseplate)" % [
			fresh.size(), _shown(world, store)])
	var a_faded: int = int(faded.keys()[0])
	var a_fresh: int = int(fresh.keys()[0])
	# Read back as the renderer keeps them, in half floats: near, not equal.
	var own: Color = library.color(world.get_brick(a_faded).color_code).shown
	var pale: Color = BrickWorld.faded(own)
	var drawn: Color = _drawn_colour(world, a_faded)
	_ok(_near(drawn, pale) and not _near(drawn, own),
		"a faded part is drawn washed pale (%s, its own colour %s)" % [drawn, own])
	own = library.color(world.get_brick(a_fresh).color_code).shown
	drawn = _drawn_colour(world, a_fresh)
	_ok(_near(drawn, own), "...and a new one in its own colour (%s)" % drawn)
	var outline: SelectionOutline = _main.get("_build_outline")
	_ok(outline.visible and not (outline._shared.is_empty() and outline._copied.is_empty()),
		"the new parts are outlined")
	var lots: Array[Dictionary] = pages.lots(3)
	var named := PackedStringArray()
	for lot: Dictionary in lots:
		named.append("%dx %s %s" % [int(lot["count"]), lot["name"], lot["colour_name"]])
	_ok(int(said["lots"]) == lots.size() and lots.size() > 0,
		"the parts for the step are along the bottom, a picture each: %s" % ", ".join(named))
	for _n: int in 300:
		said = _main.call("build_state")
		if int(said["pictures"]) == lots.size():
			break
		await process_frame
	_ok(int(said["pictures"]) == lots.size(), "...and every picture is drawn (%d of %d)" % [
		said["pictures"], lots.size()])
	var seen: Rect2 = camera.seen_rect()
	_ok(seen.position.y >= (controls["build_top"] as Control).get_global_rect().end.y - 1.0
		and seen.end.y <= (controls["build_bottom"] as Control).get_global_rect().position.y + 1.0,
		"the step is framed between the two bars (%s)" % seen)
	await _settle()
	_save("10_build_step3.png")

	print("\nturning the page with a finger, and the keys")
	var bottom: Rect2 = (controls["build_parts"] as Control).get_global_rect()
	var yaw: float = camera.yaw_turned()
	await _swipe(bottom.get_center() + Vector2(120, 0), bottom.get_center() - Vector2(120, 0))
	_ok(int(_main.call("build_state")["page"]) == 4, "a swipe to the left across the parts is Next")
	_ok(is_equal_approx(camera.yaw_turned(), yaw), "...and the model behind does not turn with it")
	await _swipe(bottom.get_center() - Vector2(120, 0), bottom.get_center() + Vector2(120, 0))
	_ok(int(_main.call("build_state")["page"]) == 3, "to the right is Back")
	await _key(KEY_RIGHT, false)
	_ok(int(_main.call("build_state")["page"]) == 4, "the right arrow is Next")
	await _key(KEY_LEFT, false)
	_ok(int(_main.call("build_state")["page"]) == 3, "the left arrow is Back")
	var middle: Vector2 = mode.free_rect().get_center()
	yaw = camera.yaw_turned()
	await _swipe(middle, middle + Vector2(150, 0))
	_ok(not is_equal_approx(camera.yaw_turned(), yaw) and int(_main.call("build_state")["page"]) == 3,
		"a finger on the model turns it (%.2f to %.2f) and stays on the page" % [yaw, camera.yaw_turned()])
	var far: float = camera.distance_now()
	await _pinch(middle, 60.0, 180.0)
	_ok(camera.distance_now() < far * 0.8, "two fingers spread zoom in (%.0f to %.0f)" % [
		far, camera.distance_now()])
	_ok(BuildSteps.recall(ID) == {"page": 3, "building": true, "version": 1}, "the page is kept for the link (%s)"
		% BuildSteps.recall(ID))

	print("\nopened again, as a phone that slept")
	await _close_viewer()
	view = await _open_viewer(text, count)
	mode = _main.get("_build_mode") if view != null else null
	for _n: int in 60:
		if mode != null and mode.is_open():
			break
		await process_frame
	await _settle()
	said = _main.call("build_state") if view != null else {}
	_ok(mode != null and mode.is_open() and said.get("page") == 3
		and str(said.get("caption", "")).begins_with("Step 3 of "),
		"the link opens straight on step 3, being built (%s)" % said.get("caption", "nothing"))
	world = _main.get("_world")
	pages = _main.get("_build_pages")
	_ok(pages != null and world.faded_ids() == pages.faded(3), "...faded as it was")
	_save("11_build_again.png")
	if mode == null or not mode.is_open():
		await _close_viewer()
		return
	await _press(mode.controls_by_name()["build_close"])
	steps = _main.get("_steps")
	store = _main.get("_store")
	view = _main.get("_share_view")
	_ok(not mode.is_open() and view._bar.is_visible_in_tree() and world.faded_ids().is_empty()
		and steps.is_playing_back() and steps.timeline_at().x == steps.timeline_at().y
		and _shown(world, store) == count,
		"Close: the whole model again, the bar and the timeline back, nothing faded")
	_ok(BuildSteps.recall(ID) == {"page": 3, "building": false, "version": 1},
		"...the page still kept, not being built")
	await _press(view.controls_by_name()["view_build"])
	await _settle()
	said = _main.call("build_state")
	_ok(mode.is_open() and said["page"] == 3, "Build it again comes back to step 3")
	for _n: int in pages.last():
		await _key(KEY_RIGHT, false)
	_ok(not mode.is_open() and _shown(world, store) == count,
		"past the last step, Finish puts the whole model back")
	await _close_viewer()
	BuildSteps._kept.clear()


## Versions of the link: the viewer's version line, and a builder's place
## kept on version 1 as the link opens on version 2, whose first changed
## step is 3.
func _versions(text: String, count: int) -> void:
	print("\nversions: what the viewer says, and a builder's place")
	var second: Dictionary = {"version": 2, "newest": 2, "versions": [
		{"n": 2, "said": "Version 2: 2 parts added and 2 removed in step 3.", "first_changed": 3,
			"note": "Step 3 in blue"},
		{"n": 1, "said": "", "first_changed": null}]}
	BuildSteps._kept.clear()
	var view: ShareView = await _open_viewer(text, count, second)
	_ok(view != null and str(view.page_state()["version_line"]) == "Version 2: 2 parts added and 2 removed in step 3."
		and not view.controls_by_name().has("view_newest"),
		"the viewer says which version it is and what changed in it (%s)"
		% (view.page_state()["version_line"] if view != null else "no viewer"))
	_ok(str(_main.call("_view_address")) == "/m/" + ID, "...at the link's own address")
	_save("12_version_line.png")
	await _close_viewer()

	print("\na builder on step 2 of version 1: nothing they built changed")
	BuildSteps.remember(ID, 2, true, 1)
	view = await _open_viewer(text, count, second)
	var mode: BuildMode = _main.get("_build_mode") if view != null else null
	await _until_building(mode)
	var said: Dictionary = _main.call("build_state") if view != null else {}
	_ok(mode != null and mode.is_open() and said.get("page") == 2 and int(said.get("changed_from", -1)) == 0
		and str(said.get("changed", "?")) == "",
		"the link opens on step 2, with nothing to tell (%s, %s)" % [said.get("caption", ""), said.get("changed", "")])
	_ok(BuildSteps.recall(ID) == {"page": 2, "building": true, "version": 2},
		"...and the place is kept on version 2 now (%s)" % BuildSteps.recall(ID))
	await _close_viewer()

	print("\na builder on step 5 of version 1: the model changed from step 3")
	BuildSteps.remember(ID, 5, true, 1)
	view = await _open_viewer(text, count, second)
	mode = _main.get("_build_mode") if view != null else null
	await _until_building(mode)
	said = _main.call("build_state") if view != null else {}
	_ok(mode != null and mode.is_open() and said.get("page") == 5
		and str(said.get("changed", "")) == "This model changed from step 3."
		and mode.controls_by_name().has("build_changed_go"),
		"the link opens where they were, step 5, and says the model changed from step 3 (%s)"
		% said.get("changed", ""))
	_save("13_changed_from.png")
	if mode != null and mode.controls_by_name().has("build_changed_go"):
		await _press(mode.controls_by_name()["build_changed_go"])
		await _settle()
	said = _main.call("build_state") if view != null else {}
	_ok(said.get("page") == 3 and str(said.get("changed", "?")) == "",
		"Go to step 3 goes there, and the notice goes (%s)" % said.get("caption", ""))
	_ok(BuildSteps.recall(ID) == {"page": 3, "building": true, "version": 2},
		"...kept as step 3 of version 2 (%s)" % BuildSteps.recall(ID))
	await _close_viewer()

	print("\nthe same on the viewer, for a builder who closed the step player")
	BuildSteps.remember(ID, 5, false, 1)
	view = await _open_viewer(text, count, second)
	await _settle()
	var state: Dictionary = view.page_state() if view != null else {}
	_ok(str(state.get("place_says", "")) == "This model changed from step 3 since you were on step 5."
		and view.controls_by_name().has("view_build_from") and view.controls_by_name().has("view_keep_place"),
		"the viewer says so and offers step 3, or their own (%s)" % state.get("place_says", ""))
	_save("14_viewer_changed.png")
	if view != null and view.controls_by_name().has("view_build_from"):
		await _press(view.controls_by_name()["view_build_from"])
	mode = _main.get("_build_mode") if view != null else null
	await _until_building(mode)
	said = _main.call("build_state") if view != null else {}
	_ok(mode != null and mode.is_open() and said.get("page") == 3 and str(view.page_state()["place_says"]) == "",
		"Build from step 3 opens the step player there (%s)" % said.get("caption", ""))
	await _close_viewer()

	print("\nan older version")
	BuildSteps._kept.clear()
	view = await _open_viewer(text, count, {"version": 1, "newest": 2, "versions": second["versions"]})
	_ok(view != null and str(view.page_state()["version_line"]) == "Version 1 of 2, an older one. Open the newest"
		and view.controls_by_name().has("view_newest"),
		"the viewer says it is an older one, with the newest a click away (%s)"
		% (view.page_state()["version_line"] if view != null else "no viewer"))
	_ok(str(_main.call("_view_address")) == "/m/%s/v/1" % ID, "...at its own address (%s)" % _main.call("_view_address"))
	await _close_viewer()

	print("\nwhether a place holds (BuildSteps.changed_since)")
	var rows: Array = second["versions"]
	for case: Array in [[1, 2, 2, 0], [1, 2, 3, 3], [1, 2, 9, 3], [2, 2, 9, 0], [2, 1, 4, 3],
			[1, 3, 1, 1], [1, 2, 0, 0]]:
		var got: int = BuildSteps.changed_since(rows, case[0], case[1], case[2])
		_ok(got == case[3], "kept on version %d at step %d, opened on version %d: %d (%d)" % [
			case[0], case[2], case[1], case[3], got])
	BuildSteps._kept.clear()


const NOBODY := "Sign in to add a comment: we email you a code, no password. Anyone can read them."
const UNDER_13 := "Comments are for people 13 and over, so you can read them here but not add one. Building, your models and sharing by link are all yours."


func _comments(text: String, count: int) -> void:
	print("\ncomments on a step")
	var second: Dictionary = {"version": 2, "newest": 2, "versions": [
		{"n": 2, "said": "Version 2: 1 part added in step 4.", "first_changed": 4},
		{"n": 1, "said": "", "first_changed": null}]}
	var made: Array = [
		{"id": 1, "version": 2, "step": 2, "on_step": 2, "body": "This part goes under, not over.",
			"at": "2026-10-18T10:00:00+00:00", "edited_at": null, "by": "Ann", "handle": "ann",
			"by_owner": false, "mine": false, "hidden": false, "older": false, "said": "on step 2 of version 2"},
		{"id": 2, "version": 1, "step": 2, "on_step": 2, "body": "Lovely tower, thank you.",
			"at": "2026-10-17T09:00:00+00:00", "edited_at": null, "by": "Bo", "handle": null,
			"by_owner": false, "mine": false, "hidden": false, "older": true, "said": "on step 2 of version 1"},
		{"id": 3, "version": 2, "step": null, "on_step": null, "body": "Built it with my daughter.",
			"at": "2026-10-18T11:00:00+00:00", "edited_at": null, "by": "Probe Builder", "handle": null,
			"by_owner": true, "mine": false, "hidden": false, "older": false, "said": "on version 2"}]
	var answer := func(you: Dictionary) -> Dictionary:
		return {"model": ID, "version": 2, "newest": 2, "open": true, "comments": made.duplicate(true),
			"you": you}

	print("\non the viewer, with nobody signed in")
	BuildSteps._kept.clear()
	_next_comments = answer.call({"signed_in": false, "may_write": false, "why_not": NOBODY, "owner": false})
	var view: ShareView = await _open_viewer(text, count, second)
	_ok(view != null, "the link opens with its comments")
	if view == null:
		return
	for _n: int in 60:
		if view.comments.known:
			break
		await process_frame
	await _settle()
	var said: Dictionary = view.page_state()
	_ok(int(said["comments"]) == 1 and said["comment_step"] == 0 and said["comment_pill"] == "1 comment",
		"at the finished model, the whole model's: %s (step %d)" % [said["comment_pill"], said["comment_step"]])
	var steps: StepsBar = _main.get("_steps")
	var on_timeline: Dictionary = steps.controls_by_name()
	await _press(on_timeline["steps_start"])
	await _press(on_timeline["steps_next"])
	await _press(on_timeline["steps_next"])
	said = view.page_state()
	_ok(said["comment_step"] == 2 and int(said["comments"]) == 2 and said["comment_pill"] == "2 comments",
		"two steps on, step 2's: %s (step %d)" % [said["comment_pill"], said["comment_step"]])
	_ok(view.controls_by_name().has("view_comments"), "...a count to tap, above the timeline")
	_save("16_viewer_comment_count.png")
	await _press(view.controls_by_name()["view_comments"])
	said = view.page_state()
	_ok(bool(said["comments_open"]) and said["comments_shown"] == ["This part goes under, not over.",
		"Lovely tower, thank you."], "tapped, step 2's two comments, in the order they came (%s)"
		% [said["comments_shown"]])
	_ok((said["comments_where"] as Array).has("On step 2 of version 1, an older one"),
		"...the older version's saying so (%s)" % [said["comments_where"]])
	var named: Dictionary = view.controls_by_name()
	_ok(not bool(said["comment_can_write"]) and not named.has("view_comment_box")
		and said["comment_why_not"] == NOBODY and named.has("view_comment_sign_in"),
		"nobody signed in: no box, told why (%s), and a way to sign in on its page" % said["comment_why_not"])
	_save("17_viewer_comments.png")
	await _press(on_timeline["steps_next"])
	said = view.page_state()
	_ok(said["comment_step"] == 3 and int(said["comments"]) == 0 and said["comment_pill"] == "Comment"
		and not bool(said["comments_open"]),
		"step 3 has none (%s), and moving on closed step 2's" % said["comment_pill"])
	await _close_viewer()

	print("\nin the step player, somebody who may write")
	_next_comments = answer.call({"signed_in": true, "may_write": true, "why_not": "", "owner": false})
	_next_token = "probe.comment.token"
	BuildSteps._kept.clear()
	view = await _open_viewer(text, count, second)
	if view == null:
		_ok(false, "the link opens again")
		return
	var fake: FakeShared = _fake
	for _n: int in 60:
		if view.comments.known:
			break
		await process_frame
	await _press(view.controls_by_name()["view_build"])
	await _settle()
	var mode: BuildMode = _main.get("_build_mode")
	said = _main.call("build_state")
	_ok(mode.is_open() and said["page"] == 0 and int(said["comments"]) == 1,
		"the cover counts the whole model's (%s)" % said["comment_pill"])
	var controls: Dictionary = mode.controls_by_name()
	for _n: int in 2:
		await _press(controls["build_next"])
	said = _main.call("build_state")
	_ok(said["page"] == 2 and int(said["comments"]) == 2 and said["comment_pill"] == "2 comments"
		and mode.controls_by_name().has("build_comments"),
		"step 2 says %s, in the top bar" % said["comment_pill"])
	var pill: Control = mode.controls_by_name()["build_comments"]
	var top: Control = mode.controls_by_name()["build_top"]
	var pt: float = mode.points()
	_ok(pill.get_global_rect().size.y >= 34.0 * pt and top.get_global_rect().encloses(pill.get_global_rect()),
		"...a fingertip to tap (%.0f points tall)" % (pill.get_global_rect().size.y / pt))
	await _press(controls["build_next"])
	said = _main.call("build_state")
	_ok(said["page"] == 3 and int(said["comments"]) == 0, "step 3, none (%s)" % said["comment_pill"])
	await _press(controls["build_back"])
	await _press(mode.controls_by_name()["build_comments"])
	said = _main.call("build_state")
	named = mode.controls_by_name()
	_ok(bool(said["comments_open"]) and (said["comments_shown"] as Array).size() == 2
		and bool(said["comment_can_write"]) and named.has("build_comment_box") and named.has("build_comment_send")
		and said["comment_why_not"] == "", "tapped: both, and a box to add one")
	_save("18_build_comments.png")
	var panel_at: Vector2 = (named["build_comment_box"] as Control).get_global_rect().get_center() \
		- Vector2(0, 60.0 * pt)
	var camera: CadCamera = _main.get("_camera")
	var yaw: float = camera.yaw_turned()
	await _swipe(panel_at + Vector2(100, 0), panel_at - Vector2(100, 0))
	said = _main.call("build_state")
	_ok(said["page"] == 2 and bool(said["comments_open"]) and is_equal_approx(camera.yaw_turned(), yaw),
		"a finger across the panel turns neither the page nor the model")
	await _press(named["build_comment_box"])
	await _type("Goes under it")
	var box: LineEdit = named["build_comment_box"]
	said = _main.call("build_state")
	_ok(box.text == "Goes under it" and said["page"] == 2,
		"typed in the box (%s), its spaces turning no page (step %d)" % [box.text, said["page"]])
	await _press(named["build_comment_send"])
	for _n: int in 30:
		if not fake.posted.is_empty():
			break
		await process_frame
	await _settle()
	said = _main.call("build_state")
	var sent: Dictionary = fake.posted[0] if not fake.posted.is_empty() else {}
	_ok(sent.get("model") == ID and sent.get("version") == 2 and sent.get("step") == 2
		and sent.get("body") == "Goes under it" and sent.get("token") == "probe.comment.token",
		"Send: on step 2 of version 2, as the person here (%s)" % [sent])
	_ok(int(said["comments"]) == 3 and said["comment_pill"] == "3 comments"
		and not (said["comments_shown"] as Array).is_empty()
		and (said["comments_shown"] as Array).back() == "Goes under it" and box.text == "",
		"...in the list, newest last, the count %s, the box empty" % said["comment_pill"])
	_save("19_build_comment_sent.png")
	await _press(mode.controls_by_name()["build_next"])
	said = _main.call("build_state")
	_ok(said["page"] == 3 and not bool(said["comments_open"]), "a page turned closes them")
	await _close_viewer()

	print("\nan account under 13")
	_next_comments = answer.call({"signed_in": true, "may_write": false, "why_not": UNDER_13, "owner": false})
	_next_token = "probe.young.token"
	# Opened on the cover, not on the page the last builder left.
	BuildSteps._kept.clear()
	view = await _open_viewer(text, count, second)
	if view == null:
		_ok(false, "the link opens again")
		return
	for _n: int in 60:
		if view.comments.known:
			break
		await process_frame
	await _press(view.controls_by_name()["view_build"])
	await _settle()
	mode = _main.get("_build_mode")
	for _n: int in 2:
		await _press(mode.controls_by_name()["build_next"])
	await _press(mode.controls_by_name()["build_comments"])
	said = _main.call("build_state")
	named = mode.controls_by_name()
	_ok(bool(said["comments_open"]) and (said["comments_shown"] as Array).size() == 2
		and not bool(said["comment_can_write"]) and not named.has("build_comment_box")
		and not named.has("build_comment_sign_in") and said["comment_why_not"] == UNDER_13,
		"reads both, has no box, and is told why: %s" % said["comment_why_not"])
	_save("20_build_comments_under_13.png")
	await _close_viewer()
	BuildSteps._kept.clear()


## Typed, a key at a time, as a keyboard does.
func _type(words: String) -> void:
	for at: int in words.length():
		var c: String = words[at]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_SPACE if c == " " else OS.find_keycode_from_string(c.to_upper())
			event.physical_keycode = event.keycode
			event.unicode = c.unicode_at(0)
			event.shift_pressed = c != c.to_lower()
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _settle()

## The step player up, or a few seconds gone by.
func _until_building(mode: BuildMode) -> void:
	for _n: int in 120:
		if mode != null and mode.is_open() and int(mode.page) > 0:
			break
		await process_frame
	await _settle()


## The colour a brick is drawn in, read back from its batch.
func _drawn_colour(world: BrickWorld, brick_id: int) -> Color:
	for key: String in world._brick_batches.get(brick_id, PackedStringArray()):
		var batch: BrickWorld.Batch = world._batches[key]
		if world._surface_colour(batch, key.split(":")[1].to_int()) != Lbm.COLOR_INHERIT:
			continue
		var slot: int = 0
		for one: int in batch.brick_ids:
			if one == brick_id:
				return batch.multimesh.get_instance_color(slot)
			if not world.get_brick(one).hidden:
				slot += 1
	return Color(0, 0, 0, 0)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004


## A finger drawn from one point to another.
func _swipe(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _as_event(from)
	Input.parse_input_event(down)
	await process_frame
	for n: int in 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _as_event(from.lerp(to, float(n + 1) / 8.0))
		drag.relative = _as_event((to - from) / 8.0)
		Input.parse_input_event(drag)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _as_event(to)
	Input.parse_input_event(up)
	await _settle()


## Two fingers about [param at], from [param from] apart to [param to].
func _pinch(at: Vector2, from: float, to: float) -> void:
	for index: int in 2:
		var down := InputEventScreenTouch.new()
		down.index = index
		down.pressed = true
		down.position = _as_event(at + Vector2(from * (0.5 if index == 0 else -0.5), 0))
		Input.parse_input_event(down)
	await process_frame
	for n: int in 8:
		var apart: float = lerpf(from, to, float(n + 1) / 8.0)
		for index: int in 2:
			var drag := InputEventScreenDrag.new()
			drag.index = index
			var side: float = 0.5 if index == 0 else -0.5
			drag.position = _as_event(at + Vector2(apart * side, 0))
			drag.relative = _as_event(Vector2((to - from) / 8.0 * side, 0))
			Input.parse_input_event(drag)
		await process_frame
	for index: int in 2:
		var up := InputEventScreenTouch.new()
		up.index = index
		up.pressed = false
		up.position = _as_event(at + Vector2(to * (0.5 if index == 0 else -0.5), 0))
		Input.parse_input_event(up)
	await _settle()


## File › Share… in the builder, signed in, against the fake.
func _the_panel(text: String) -> void:
	print("\nthe panel")
	var fake := FakeShared.new()
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	var account: Account = _main.get("_account")
	var store: ModelStore = _main.get("_store")
	var shell: Shell = _main.get("_shell")
	var bar: ModelBar = _main.get("_bar")
	account.email = "probe.builder@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var opened: Dictionary = store.open_text(text, "probe")
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty():
			break
	await _settle()
	var panel: SharePanel = _main.get("_share_panel")
	_ok(shell.can("share") and shell.run("share") and panel.visible,
		"File › Share… opens the panel")
	_ok(panel.controls_by_name().has("share_publish"), "...with Publish")
	_ok(panel._name.text == "Probe House", "...and the model's name (%s)" % panel._name.text)
	panel._credit.button_pressed = true
	_ok(panel._author.visible and panel._author.text == "Probe Builder",
		"ticking Show who made it offers a name from the account (%s)" % panel._author.text)
	await _settle()
	_save("6_panel.png")
	_ok(not panel.controls_by_name().has("share_note"),
		"no What changed? for a model with no link yet: there is nothing it changed from")
	await panel.publish()
	await _settle()
	var sent: Dictionary = fake.published[0] if not fake.published.is_empty() else {}
	_ok(panel.state == "published" and store.share_id == "NewL1nk001",
		"published, and the link is kept with the model (%s, %s)" % [panel.state, store.share_id])
	_ok(str(sent.get("name", "")) == "Probe House" and str(sent.get("author", "")) == "Probe Builder"
		and not sent.has("id"), "it sent the name and the author, and no link the first time")
	_ok(sent.get("listed") == false and not panel._list.button_pressed and not sent.has("remixed_from"),
		"not listed in the gallery unless ticked, and remixed from nothing")
	var model: String = str(sent.get("model", ""))
	_ok(model.contains(".dat") and model.contains("0 !DATA") and not model.contains("!BRICKWORKS SHARE"),
		"the model went as LDraw with its made part and print inside, and no link line")
	_ok(model.count(SharedPages.HEAD) == 1 and model.contains(SharedPages.PAGE),
		"...and with its build steps, worked out once for the link (SharedPages), %d of them"
		% model.count(SharedPages.PAGE))
	var picture := Image.new()
	var png: PackedByteArray = Marshalls.base64_to_raw(str(sent.get("image", "")))
	var read: int = picture.load_png_from_buffer(png) if not png.is_empty() else ERR_FILE_EOF
	_ok(read == OK and (picture.get_size() == Vector2i(1200, 630) or picture.get_size() == Vector2i(800, 420))
		and png.size() <= SharePanel.MOST_PNG,
		"with a picture for the link's preview: %s, %d KB" % [picture.get_size(), png.size() / 1024])
	if read == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
		picture.save_png(ProjectSettings.globalize_path(SHOTS + "7_og_image.png"))
	_ok(panel.url == "https://brickworks.diy/m/NewL1nk001" and panel.embed.begins_with("<iframe"),
		"the panel shows the link and the embed code")
	_save("8_published.png")

	print("\nwhat its page and the gallery say about it")
	var small := Image.new()
	var webp: PackedByteArray = Marshalls.base64_to_raw(str(sent.get("thumb", "")))
	var small_read: int = small.load_webp_from_buffer(webp) if not webp.is_empty() else ERR_FILE_EOF
	_ok(small_read == OK and small.get_size() == SharePanel.THUMB and webp.size() <= SharePanel.MOST_THUMB,
		"and a small WebP for the gallery's cards: %s, %d KB" % [small.get_size(), webp.size() / 1024])
	_ok(str(sent.get("description", "?")) == "" and str(sent.get("tags", "?")) == ""
		and str(sent.get("kind", "")) == "town" and str(sent.get("licence", "")) == "cc-by-4.0",
		"said the first time: no words, no tags, the kind its name says (a house: %s), CC BY (%s)"
		% [sent.get("kind"), sent.get("licence")])
	for named: String in ["share_about", "share_tags", "share_kind", "share_licence"]:
		_ok(panel.controls_by_name().has(named), "the panel has %s" % named)
	panel._about.text = "A small house.\nTwo windows and a door."
	panel._tags.text = "house, town"
	panel._tags.text_changed.emit(panel._tags.text)
	panel._licence.select(1)
	panel._licence.item_selected.emit(1)
	await panel.publish()
	var words: Dictionary = fake.published[-1]
	_ok(str(words.get("description", "")) == "A small house.\nTwo windows and a door."
		and str(words.get("tags", "")) == "house, town" and str(words.get("licence", "")) == "cc-by-sa-4.0"
		and str(words.get("kind", "")) == "town",
		"what is typed is sent: the description with its lines, the tags, the licence chosen (%s)" % words.get("licence"))
	_ok(panel._licence_says.text.contains("shared the same way"), "...and the panel says what that licence allows")
	panel._kind.select(ModelKinds.ids().find("art") + 1)
	panel._kind.item_selected.emit(panel._kind.selected)
	panel._name.text = "Probe Castle"
	panel._name.text_changed.emit(panel._name.text)
	_ok(panel.page_state()["kind"] == "art", "a kind chosen stays chosen when the name changes (%s)" % panel.page_state()["kind"])
	var big := "x".repeat(1200)
	panel._about.text = big
	panel._about.text_changed.emit()
	_ok(panel._about.text.length() == SharePanel.MOST_ABOUT, "the description is kept to %d characters as it is typed" % SharePanel.MOST_ABOUT)
	panel._about.text = "A small house.\nTwo windows and a door."
	panel._name.text = "Probe House"
	panel.visible = false
	panel.open()
	_ok(panel._about.text == "A small house.\nTwo windows and a door." and panel._tags.text == "house, town",
		"closed and opened again, what was said is still there")
	for pair: Array in [["An orrery with nine planets", "mechanism"], ["A barn owl", "nature"],
			["Wizard's Tower", "castle"], ["A sports car, and its driver", "vehicle"],
			["A three-core heavy-lift rocket", "space"], ["A small modular corner shop", "town"],
			["A minifigure of a chef", "figure"], ["A mosaic of a sunflower", "art"], ["", ""]]:
		_ok(ModelKinds.guess(str(pair[0])) == str(pair[1]),
			"the kind of \"%s\": %s (%s)" % [pair[0], pair[1], ModelKinds.guess(str(pair[0]))])

	var kept: String = ModelStore.with_share(store.to_text("Probe House"), store.share_id)
	_ok(ModelStore.share_in(kept) == "NewL1nk001" and LdrModel.parse(kept, "x").main.title == "Probe House",
		"the working model carries the link on a line LDraw ignores, and keeps its title")

	panel._credit.button_pressed = false
	await panel.publish()
	var again: Dictionary = fake.published[-1]
	_ok(str(again.get("id", "")) == "NewL1nk001" and not again.has("author"),
		"publishing again sends the same link, and no author once unticked")

	print("\nwhat changed, said with the next version")
	_ok(panel.controls_by_name().has("share_note") and not again.has("note"),
		"a model with a link has What changed?, and nothing is sent when it is empty")
	panel._note.text = "  Moved the door to the left  "
	await panel.publish()
	var noted: Dictionary = fake.published[-1]
	var now: Dictionary = panel.page_state()
	_ok(str(noted.get("note", "")) == "Moved the door to the left",
		"what is typed in it goes with the next version, trimmed (%s)" % noted.get("note", ""))
	_ok(int(now["version"]) == int(fake.versions["NewL1nk001"]) and int(now["version"]) > 1
		and str(panel._status.text).begins_with("Version %d is up at this link" % int(now["version"]))
		and str(panel._status.text).contains("version %d is kept" % (int(now["version"]) - 1))
		and str(panel._status.text).contains(str(now["said"])) and not str(now["said"]).is_empty(),
		"the panel says which version is up, that the one before is kept, and what changed (%s)"
		% panel._status.text)
	_ok(panel._note.text.is_empty(), "...and the box is empty for the next one")
	await _settle()
	_save("8a_new_version.png")

	print("\nthe gallery, and a remix")
	_ok(panel.controls_by_name().has("share_list") and panel._list.text == "List it in the gallery",
		"the panel has List it in the gallery")
	panel._list.button_pressed = true
	await _settle()
	_save("8b_list_ticked.png")
	await panel.publish()
	var listing: Dictionary = fake.published[-1]
	_ok(listing.get("listed") == true and panel.page_state()["listed"] == true
		and str(panel._status.text).contains("listed in the gallery"),
		"ticked, it is published as listed, and the panel says so (%s)" % panel._status.text)
	panel._list.button_pressed = false
	await panel.publish()
	_ok(fake.published[-1].get("listed") == false and not str(panel._status.text).contains("gallery"),
		"unticked and published again: not listed (%s)" % panel._status.text)
	store.remixed_from = "0r1g1nM0de"
	await panel.publish()
	_ok(str(fake.published[-1].get("remixed_from", "")) == "0r1g1nM0de",
		"a copy of somebody's link says which one when it is published")
	var with_both: String = ModelStore.with_share(store.to_text("Probe House"), store.share_id, store.remixed_from)
	_ok(ModelStore.share_in(with_both) == "NewL1nk001" and ModelStore.remix_in(with_both) == "0r1g1nM0de"
		and LdrModel.parse(with_both, "x").main.title == "Probe House",
		"its saves carry both links on lines LDraw ignores, and keep the title")
	var copy: Dictionary = store.open_text(ModelStore.with_share(store.to_text("Probe House"), "",
		"0r1g1nM0de"), "probe")
	_ok(int(copy["placed"]) > 0 and store.remixed_from == "0r1g1nM0de" and store.share_id.is_empty(),
		"opened again, it still knows where it came from (%s)" % store.remixed_from)
	store.share_id = "NewL1nk001"
	await panel.unpublish()
	_ok(fake.unpublished == ["NewL1nk001"] and panel.state == "unpublished"
		and panel._publish.text == "Publish again", "Unpublish takes it down (%s)" % panel._publish.text)

	store.share_id = "Someb0dyEl"
	fake.not_ours = "Someb0dyEl"
	await panel.publish()
	_ok(store.share_id != "Someb0dyEl" and not fake.published[-1].has("id"),
		"a link of another account's is replaced by one of its own (%s)" % store.share_id)
	panel.visible = false
	store.remixed_from = "0r1g1nM0de"
	bar._on_clear()
	_ok(store.share_id.is_empty() and store.remixed_from.is_empty(),
		"Clear forgets the link, and where it came from")
	store.share_id = "NewL1nk001"
	store.remixed_from = "0r1g1nM0de"
	store.begin("Probe Tower")
	_ok(store.share_id.is_empty() and store.remixed_from.is_empty(),
		"and so does new work (ModelStore.begin)")
	_main.queue_free()
	for _n: int in 10:
		await process_frame


func _make_model() -> Dictionary:
	var lib := PartLibrary.new()
	lib.load_catalogue()
	var spec := ElementMaker.Spec.new()
	spec.across = 7
	spec.deep = 2
	spec.plates = 3
	var brick: Dictionary = CustomParts.make(lib, spec, false)
	var tile_areas: Array[PartPrints.Area] = PartPrints.areas_for(lib, "3068b")
	var picture := Image.create_empty(tile_areas[0].size.x, tile_areas[0].size.y, false, Image.FORMAT_RGBA8)
	PrintPaint.draw_rectangle(picture, Vector2(40, 40), Vector2(370, 370), 0.0, Color.BLACK, true)
	var tile: Dictionary = PartPrints.make(lib, "3068b", tile_areas.slice(0, 1), {"top": picture},
		"Probe Sign", false)
	var tile_id: String = str((tile["ids"] as Array)[0]) if not (tile["ids"] as Array).is_empty() else ""
	var house: LdrModel = LdrModel.parse(FileAccess.get_file_as_string("res://models/house.ldr"), "house")
	var placements: Array = house.flatten(lib.parts)
	var first: Transform3D = (placements[0] as LdrModel.Placement).transform
	placements.append(LdrModel.Placement.new(str(brick["id"]), 4,
		first.translated(Vector3(0, 0, 120)), 0))
	placements.append(LdrModel.Placement.new(tile_id, 15,
		first.translated(Vector3(80, 0, 120)), 0))
	var used: Array = []
	for item: Variant in placements:
		used.append((item as LdrModel.Placement).part_id)
	var text: String = LdrModel.write_ldr(placements, "Probe House", "Brickworks", {},
		CustomParts.sources_for(lib, used))
	return {"text": text, "count": placements.size(), "brick": brick["id"], "tile": tile_id}


func _has_part(world: BrickWorld, part_id: String) -> bool:
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == part_id:
			return true
	return false


func _shown(world: BrickWorld, store: ModelStore) -> int:
	var n: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id) and not brick.hidden:
			n += 1
	return n


## Every part, where it stands and in what colour.
func _fingerprint(world: BrickWorld) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for brick: BrickWorld.Brick in world.bricks():
		lines.append("%s %d %s" % [brick.part_id, brick.color_code, brick.transform])
	lines.sort()
	return "\n".join(lines)


func _centre(brick: BrickWorld.Brick, library: PartLibrary) -> Vector3:
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	return (brick.transform * mesh.bounds).get_center() if mesh != null else brick.transform.origin


## A part whose middle is in the model's part of the window and is the
## first thing a ray from there meets.
func _a_visible_brick(world: BrickWorld, store: ModelStore, library: PartLibrary,
		camera: CadCamera, rect: Rect2) -> BrickWorld.Brick:
	var verbs: EditVerbs = _main.get("_verbs")
	for brick: BrickWorld.Brick in world.bricks():
		if store.scenery.has(brick.id):
			continue
		var at: Vector2 = camera.unproject_position(_centre(brick, library))
		if rect.grow(-40).has_point(at) and verbs.brick_at(at) == brick.id:
			return brick
	return null


## The viewer is up as soon as its model is, and works the steps out
## after it, a slice at a time with the status bar saying so (Main.
## _view_shared): the timeline, and a page kept for the link, come when
## that is done. Twenty frames were the wait once, and on a machine at a
## load of forty a 73-part house takes longer than that, so the timeline
## was read before it was up (2026-10-16). Waited for by what the bar
## says, bounded, and the time it took printed.
func _steps_worked_out() -> void:
	var steps: StepsBar = _main.get("_steps") if _main != null else null
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	print("     (its steps were worked out %.1f s after the model was up)"
		% ((Time.get_ticks_msec() - since) / 1000.0))
	await _settle()


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


## Press a button where it is on screen, with the mouse.
func _press(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, true)
	await process_frame
	_button(at, false)
	await _settle()


func _click(at: Vector2) -> void:
	_move(at)
	_button(at, true)
	_button(at, false)


func _drag(from: Vector2, to: Vector2) -> void:
	_move(from)
	await process_frame
	_button(from, true)
	await process_frame
	for n: int in 8:
		var event := InputEventMouseMotion.new()
		var at: Vector2 = from.lerp(to, float(n + 1) / 8.0)
		event.position = _as_event(at)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.relative = _as_event((to - from) / 8.0)
		Input.parse_input_event(event)
		await process_frame
	_button(to, false)
	await _settle()


## Viewport coordinates as the window's, which an event carries: the
## interface is scaled, so the two differ (see feel_probe.gd).
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _key(code: Key, ctrl: bool) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	for _n: int in 4:
		await process_frame


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SHOTS + name))
		print("  wrote shots/share/%s" % name)


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file_name)
	DirAccess.remove_absolute(dir)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else
		"a shared model opens to look at and nothing else, and the panel shares one")
	quit(1 if _failures else 0)
