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

	func fetch(id: String) -> Dictionary:
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
		return {"code": 200 if body.has("id") else 201, "body": {"id": given,
			"url": "https://brickworks.diy/m/" + given, "embed": SharedModels.embed_for(given),
			"parts": 7, "updated": body.has("id")}}

	func unpublish(_token: String, id: String) -> Dictionary:
		unpublished.append(id)
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"id": id, "published": false}}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"shared": []}}


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
	await _settle()
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
	_ok(DirAccess.get_files_at(PARTS_DIR).is_empty(), "...and nothing was kept on disk (%s)"
		% [DirAccess.get_files_at(PARTS_DIR)])
	_ok(view.model_name == "Probe House" and view.author == "Probe Builder" and view.parts == count,
		"the bar names it, who made it and its part count (%s, %s, %d)" % [
			view.model_name, view.author, view.parts])
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
	# Back as a builder would be: the switches are the app's, not the probe's.
	ShellPrefs.frozen = false
	CustomParts.keeps = true

	await _the_panel(text)
	_forget(PARTS_DIR)
	_forget(OUT_DIR)
	_finish()


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
	await panel.publish()
	await _settle()
	var sent: Dictionary = fake.published[0] if not fake.published.is_empty() else {}
	_ok(panel.state == "published" and store.share_id == "NewL1nk001",
		"published, and the link is kept with the model (%s, %s)" % [panel.state, store.share_id])
	_ok(str(sent.get("name", "")) == "Probe House" and str(sent.get("author", "")) == "Probe Builder"
		and not sent.has("id"), "it sent the name and the author, and no link the first time")
	var model: String = str(sent.get("model", ""))
	_ok(model.contains(".dat") and model.contains("0 !DATA") and not model.contains("!BRICKWORKS SHARE"),
		"the model went as LDraw with its made part and print inside, and no link line")
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

	var kept: String = ModelStore.with_share(store.to_text("Probe House"), store.share_id)
	_ok(ModelStore.share_in(kept) == "NewL1nk001" and LdrModel.parse(kept, "x").main.title == "Probe House",
		"the working model carries the link on a line LDraw ignores, and keeps its title")

	panel._credit.button_pressed = false
	await panel.publish()
	var again: Dictionary = fake.published[-1]
	_ok(str(again.get("id", "")) == "NewL1nk001" and not again.has("author"),
		"publishing again sends the same link, and no author once unticked")
	await panel.unpublish()
	_ok(fake.unpublished == ["NewL1nk001"] and panel.state == "unpublished"
		and panel._publish.text == "Publish again", "Unpublish takes it down (%s)" % panel._publish.text)

	store.share_id = "Someb0dyEl"
	fake.not_ours = "Someb0dyEl"
	await panel.publish()
	_ok(store.share_id != "Someb0dyEl" and not fake.published[-1].has("id"),
		"a link of another account's is replaced by one of its own (%s)" % store.share_id)
	panel.visible = false
	bar._on_clear()
	_ok(store.share_id.is_empty(), "Clear forgets the link")
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
