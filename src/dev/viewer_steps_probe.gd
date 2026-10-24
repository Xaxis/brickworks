## A shared model's viewer as the expert review walked it (walk180, W3 to
## W5): Build it on the model's page, the viewer's own timeline stepped, and
## what the viewer offers to play with.
##
##   godot --path . --resolution 1280x800 --script src/dev/viewer_steps_probe.gd
##
## No network: api/share.js is played by a stand-in that answers with
## vendor/omr/files/8808-1.mpd (93 parts, a racer whose steering turns), or
## models/car.ldr (61 parts, wheels on their pins and nothing a card names
## as moving), as step_link_probe's does.
##
##   1. Build it on the model's page (?build, as --build): the step player
##      open at step 1, in one press: not the viewer on the finished model,
##      and not the cover. It was the viewer at Step 390 of 390 with Build it
##      on its bar, and then a cover with Start (W3).
##   2. The same, on a device that was building it at step 3: step 3.
##   3. The viewer's timeline (no ?build) stepped with Next, as a person
##      presses it: each step's new parts outlined and the view turned and
##      framed on them, as the step player frames that page (BuildSteps.view).
##      Back too. Played, or taken to its end, and the line goes. Step 248 of
##      the castle was six plates behind its walls, unlit (W4).
##   4. What moves: the racer's pill says its steering; the car, whose wheels
##      turn on their pins and whose card says nothing moves, says nothing
##      ("Parts of it move" on the castle, W5). A drag on one of its wheels
##      still turns it, and the pill then offers Reset.
extends SceneTree

const SET := "res://vendor/omr/files/8808-1.mpd"
const CAR := "res://models/car.ldr"

var _failures: int = 0


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var racer: String = FileAccess.get_file_as_string(SET)
	var car: String = FileAccess.get_file_as_string(CAR)
	if racer.is_empty() or car.is_empty():
		print("viewer_steps_probe: SKIPPED, no %s (tools/fetch_data.sh)" % SET)
		quit(3)
		return

	print("\n1. Build it on the model's page")
	var main: Node = await _open("V1ewSt3p01", racer, {"_viewing_build": true})
	var mode: BuildMode = main.get("_build_mode")
	await _until(func() -> bool: return mode.is_open() and int(main.get("_build_page")) >= 1, 600)
	var said: Dictionary = mode.page_state()
	_ok(mode.is_open() and int(main.get("_build_page")) == 1,
		"the step player is open at step 1 (%s, page %d: %s)" % ["open" if mode.is_open() else "not open",
			int(main.get("_build_page")), str(said.get("title", said.get("caption", "")))])
	await _close(main)

	print("\n2. Build it on the model's page, on a device that was building it at step 3")
	BuildSteps.remember("V1ewSt3p02", 3, true, 1)
	main = await _open("V1ewSt3p02", racer, {"_viewing_build": true})
	mode = main.get("_build_mode")
	await _until(func() -> bool: return mode.is_open() and int(main.get("_build_page")) >= 1, 600)
	_ok(mode.is_open() and int(main.get("_build_page")) == 3,
		"back where it was left: step 3 (page %d)" % int(main.get("_build_page")))
	await _close(main)

	print("\n3. the viewer's timeline, stepped")
	main = await _open("V1ewSt3p03", racer, {})
	mode = main.get("_build_mode")
	_ok(not mode.is_open(), "the link with no ?build opens the viewer, not the step player")
	var steps: StepsBar = main.get("_steps")
	var camera: CadCamera = main.get("_camera")
	var outline: SelectionOutline = main.get("_build_outline")
	var world: BrickWorld = main.get("_world")
	await _until(func() -> bool: return main.get("_build_pages") != null, 300)
	var named: Dictionary = steps.controls_by_name()
	# Turned and zoomed out first, as a person looking round it has.
	camera.turn_by_drag(Vector2(260, -60))
	camera.zoom_by_drag(80.0)
	await _frames(30)
	await _press(named["steps_start"])
	_ok(not _shown(outline), "at the start, nothing outlined")
	for _n: int in 3:
		await _press(named["steps_next"])
	await _lit_as_page(main, steps, camera, outline, world, "Next three times")
	# Looked round again, and the check above's own view put away.
	camera.turn_by_drag(Vector2(-300, 80))
	camera.zoom_by_drag(60.0)
	await _frames(30)
	await _press(named["steps_next"])
	await _press(named["steps_back"])
	await _lit_as_page(main, steps, camera, outline, world, "Next and Back")
	await _shot("viewer_steps_lit.png")
	var then: Vector3 = camera.get("_target_focus")
	await _press(named["steps_end"])
	_ok(not _shown(outline), "End: the finished model, nothing outlined")
	await _press(named["steps_start"])
	await _press(named["steps_next"])
	steps.toggle_play()
	await _frames(30)
	steps.toggle_play()
	_ok(not _shown(outline), "played: nothing outlined")
	_ok(then != Vector3.ZERO, "(the focus the step had: %s)" % then)
	await _close(main)

	print("\n4. what the viewer offers to play with")
	main = await _open("V1ewSt3p04", racer, {})
	var view: ShareView = main.get("_share_view")
	await _until(func() -> bool: return view.play_ready, 1200)
	await _frames(10)
	said = view.page_state()["play"]
	_ok(said["shown"] and str(said["title"]).begins_with("Moves: "),
		"the racer: the pill says what moves (%s / %s)" % [said["title"], said["says"]])
	await _close(main)
	main = await _open("V1ewSt3p05", car, {})
	view = main.get("_share_view")
	var grab_drag: GrabDrag = main.get("_grab_drag")
	await _until(func() -> bool: return grab_drag.is_ready() and view.play_ready, 1200)
	await _frames(30)
	said = view.page_state()["play"]
	print("     (the car's joints read: anything moves %s, named %s, motions %s)" % [
		grab_drag.anything_moves(), said["moves"], said["motions"]])
	_ok(grab_drag.anything_moves() and (said["moves"] as Array).is_empty(),
		"the car: its wheels turn on their pins, and nothing it has is named as moving")
	_ok(not said["shown"], "...and the pill says nothing (%s: %s / %s)" % [
		"shown" if said["shown"] else "not shown", said["title"], said["says"]])
	_ok(view.play_ready, "...though a part on a joint can still be taken hold of")
	await _shot("viewer_car_nothing_said.png")
	view.show_played(true)
	await _frames(5)
	said = view.page_state()["play"]
	_ok(said["shown"] and said["reset"], "moved by a drag, the pill offers Reset (%s, reset %s)" % [
		said["shown"], said["reset"]])
	await _close(main)

	print("\nviewer_steps_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## The timeline on a step: that step's new parts are what is outlined, and
## the view is the one the step player draws its page from.
func _lit_as_page(main: Node, steps: StepsBar, camera: CadCamera, outline: SelectionOutline,
		world: BrickWorld, how: String) -> void:
	var pages: BuildSteps = main.get("_build_pages")
	var at: Instructions.Step = steps.current_step()
	var page: int = pages.steps.find(at) + 1 if pages != null and at != null else 0
	_ok(page >= 1, "%s: the timeline is on step %d (%s)" % [how, page, steps.page_state().get("caption", "")])
	if page < 1:
		return
	var fresh: Dictionary = pages.fresh(page)
	var drawn: Array = world.drawn_as(fresh)
	var want: AABB = drawn[2]
	var got: AABB = outline.get("_bounds")
	_ok(_shown(outline) and not fresh.is_empty() and got.position.distance_to(want.position) < 0.5
			and got.size.distance_to(want.size) < 0.5,
		"%s: step %d's %d new parts outlined (%s, round %s; want %s)" % [how, page, fresh.size(),
			"shown" if _shown(outline) else "not shown", got, want])
	# The view as the timeline left it, against the step player's for the
	# page, put on the camera here.
	var had: Array = _aim(camera)
	var view: Dictionary = pages.view(page)
	camera.look_from(view["from"])
	camera.frame(view["box"], 1.0)
	var want_aim: Array = _aim(camera)
	_ok((had[0] as Vector3).distance_to(want_aim[0]) < 0.5 and absf(had[1] - want_aim[1]) < 0.5
			and absf(had[2] - want_aim[2]) < 0.001 and absf(had[3] - want_aim[3]) < 0.001,
		"%s: the view turned and framed on step %d as its page is (focus %s, %.0f away, yaw %.2f, pitch %.2f; its page's %s, %.0f, %.2f, %.2f)"
			% [how, page, had[0], had[1], had[2], had[3], want_aim[0], want_aim[1], want_aim[2], want_aim[3]])


## Whether the line is on screen: warmed, it is made and then put away.
func _shown(outline: SelectionOutline) -> bool:
	var overlay: CanvasItem = outline.get("_overlay")
	return outline.visible and overlay != null and overlay.visible


## Where the camera is going: its focus, distance, yaw and pitch.
func _aim(camera: CadCamera) -> Array:
	return [camera.get("_target_focus") as Vector3, float(camera.get("_target_distance")),
		float(camera.get("_target_yaw")), float(camera.get("_target_pitch"))]


func _open(id: String, text: String, set_up: Dictionary) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": "Probe Model", "author": "Probe Builder",
		"parts": 93, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", id)
	for key: String in set_up:
		main.set(key, set_up[key])
	main.set("_shared", fake)
	root.add_child(main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "the shared model opened (%s)" % (
		view.state if view != null else "no viewer"))
	var steps: StepsBar = main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(20)
	return main


func _close(main: Node) -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _until(test: Callable, frames: int) -> void:
	for _n: int in frames:
		if test.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _press(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, true)
	await process_frame
	_button(at, false)
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


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/viewer_steps/"))
	root.get_texture().get_image().save_png("res://shots/viewer_steps/" + name)


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
