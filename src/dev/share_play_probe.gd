## Play in a shared model's viewer: a real set's steering turned as a
## visitor turns it, and put back.
##
##   godot --path . --resolution 1280x800 --script src/dev/share_play_probe.gd
##
## No network: api/share.js is played by a stand-in that answers with
## vendor/omr/files/8808-1.mpd (93 parts: a racer whose steering wheel turns
## a pinion in the track rod's rack, the front wheels on their arms), as
## share_view_probe's FakeShared does. The viewer opens it read-only; once
## its joints are read, it says what moves ("Moves: steering" and "Drag a
## part that moves"). Then, by the mouse, as a person does:
##
##   1. The steering wheel taken by its rim and turned 30 degrees on its
##      column: the grab takes the loop and the rack, the rack slides, both
##      steering arms turn on their kingpins (the front wheels steer), the
##      pill says what is turning, and the drag's own frames are timed.
##   2. Let go: kept where it was turned, Reset offered; nothing written to
##      the link, the store or the data folder, nothing published, the text
##      the link served unchanged, the store still read-only.
##   3. Reset: every part back exactly where it was built, Reset gone.
##   4. A finger: the same steering turned by a touch drawn round the wheel,
##      the camera not turned with it; Reset again.
##   5. A drag on the chassis, which does not move: the view turns, no part
##      moves.
##   6. Build it after a play: the step player shows the model as built.
##   7. Published from the builder, what moves goes with it.
##   8. A model with motions of its own (docs/MOTIONS.md): 1484-1 with
##      tests/fixtures/motions/1484-1.motions written into it, "Open the
##      gates" and "Open the mailbox", opened by its link. A button for each
##      in the pill; each pressed as a person presses it plays through Grab,
##      its frames drawn as it goes, and the model stands where it ends with
##      the button lit; pressed again it plays backwards and the parts are
##      back where they were built; Reset puts everything back. Nothing is
##      written, nothing published, the link's text unchanged.
##
## Pictures in shots/play/: 1_ready.png, 2_turned.png, 3_reset.png,
## 4_finger.png, 5_motions.png, 6_played.png, 7_motions_reset.png.
extends SceneTree

const SHOTS := "res://shots/play/"
const ID := "Pl4yVi3w01"
const SET := "res://vendor/omr/files/8808-1.mpd"
## The house with its gates and mailbox, and the motions written into it.
const HOUSE := "res://vendor/omr/files/1484-1.mpd"
const HOUSE_MOTIONS := "res://tests/fixtures/motions/1484-1.motions"
const HOUSE_ID := "M0ti0nsVw1"

var _failures: int = 0
var _main: Node
var _windowed: bool = false


class FakeShared extends SharedModels:
	var answer: Dictionary = {}
	var asked: Array[String] = []
	var published: Array[Dictionary] = []
	var built_calls: Array = []

	func fetch(id: String, _version: int = 0) -> Dictionary:
		asked.append(id)
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func publish(_token: String, body: Dictionary) -> Dictionary:
		published.append(body.duplicate())
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 201, "body": {"id": "NewPl4y001", "url": "https://brickworks.diy/m/NewPl4y001",
			"parts": 93, "listed": false, "version": 1, "moves": body.get("moves")}}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"shared": []}}

	func built(id: String, device: String, version: int = 1) -> Dictionary:
		built_calls.append([id, device, version])
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "can_write": false, "why_not": "signed out"}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_windowed = DisplayServer.get_name() != "headless"
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var text: String = FileAccess.get_file_as_string(SET)
	if text.is_empty():
		print("share_play_probe: SKIPPED, no %s (tools/fetch_data.sh)" % SET)
		quit(0)
		return
	var served: String = text.sha256_text()
	var files_before: PackedStringArray = _files_under("user://")

	print("\na shared racer, %s, opened by its link" % SET.get_file())
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe Racer", "author": "Probe Builder",
		"parts": 93, "url": "https://brickworks.diy/m/" + ID, "model": text}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", ID)
	_main.set("_shared", fake)
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 2400:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "the shared model opened (%s)" % (view.state if view != null else "none"))
	if view == null or view.state != "ready":
		_finish()
		return
	var steps: StepsBar = _main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	since = Time.get_ticks_msec()
	while not view.play_ready and Time.get_ticks_msec() - since < 120000:
		await process_frame
	print("     (what moves was said %.1f s after the steps)" % ((Time.get_ticks_msec() - since) / 1000.0))
	await _settle()
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var library: PartLibrary = _main.get("_library")
	var camera: CadCamera = _main.get("_camera")
	var builder: Builder = _main.get("_builder")
	var grab_drag: GrabDrag = _main.get("_grab_drag")
	var said: Dictionary = view.page_state()["play"]
	_ok(view.play_ready and said["shown"], "the viewer says something moves: %s / %s" % [said["title"], said["says"]])
	_ok(str(said["title"]).begins_with("Moves: ") and (said["moves"] as Array).has("steering"),
		"what moves is named: %s" % said["title"])
	_ok(str(said["says"]).begins_with("Drag a part that moves"), "and how to move it: %s" % said["says"])
	_ok((said["motions"] as Array).is_empty() and not view.controls_by_name().has("view_motion_1"),
		"a model without motions of its own has no motion buttons: Play as it was")
	_ok(store.read_only and not store.keeps, "the store writes nothing")
	var found: Dictionary = _main.get("play_found")
	var steering: Array = found.get("steering", [])
	var wheel: int = int(steering[0]) if not steering.is_empty() else 0
	var wheel_brick: BrickWorld.Brick = world.get_brick(wheel)
	var wheel_info: PartLibrary.PartInfo = library.parts.get(wheel_brick.part_id) if wheel_brick != null else null
	_ok(wheel_info != null and wheel_info.name.contains("Steering Wheel"),
		"the steering is taken by its steering wheel (%s)" % (wheel_info.name if wheel_info != null else "none"))
	if wheel_info == null:
		_finish()
		return
	# The steering arms: what turns the front wheels on their kingpins.
	var bodies: Bodies = grab_drag.read_bodies()
	var arms: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		if info != null and Playable.steering_arm(info.name):
			arms.append(brick.id)
	_ok(arms.size() == 2, "it has two steering arms (%d)" % arms.size())
	var before: Dictionary = _snapshot(world)
	await _save("1_ready.png")

	print("\n1. the steering wheel turned by the mouse")
	var spot: Dictionary = _spot(grab_drag, bodies, wheel, camera)
	for side: Vector3 in [Vector3(0.3, 1.0, 0.6), Vector3(-0.6, 0.8, 0.6), Vector3(0.6, 0.8, -0.6)]:
		if not spot.is_empty():
			break
		camera.look_from(side.normalized())
		await _settle()
		spot = _spot(grab_drag, bodies, wheel, camera)
	_ok(not spot.is_empty(), "the steering wheel is under the pointer somewhere (%s)" % spot)
	if spot.is_empty():
		_finish()
		return
	var at: Vector2 = spot["screen"]
	var turned_view: Transform3D = camera.global_transform
	_move(at, 0)
	await process_frame
	_button(at, true)
	await process_frame
	var tangent: Vector2 = (at - spot["pivot"]).orthogonal().normalized() * 8.0 \
		if spot.has("pivot") and (at - (spot["pivot"] as Vector2)).length() > 3.0 else Vector2(8, 0)
	_move(at + tangent, MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	var grab: Grab = grab_drag.grab
	_ok(grab != null and grab.state == "moves" and grab.linkage != null and not grab.linkage.racks.is_empty(),
		"a drag on it takes the loop and the rack: %s" % (grab.said if grab != null else grab_drag.last_words))
	if grab == null or grab.state != "moves":
		_button(at, false)
		_finish()
		return
	var frame_us: Array = []
	for degrees: float in [6.0, 12.0, 18.0, 24.0, 30.0]:
		var to: Vector3 = _about(grab.pivot, grab.axis, degrees) * grab._hold
		var began: int = Time.get_ticks_usec()
		_move(camera.unproject_position(to), MOUSE_BUTTON_MASK_LEFT)
		await process_frame
		frame_us.append(Time.get_ticks_usec() - began)
	await _settle()
	var mid: Dictionary = view.page_state()["play"]
	_ok(absf(grab.angle) >= 15.0, "the steering wheel turned %.1f° on its column" % grab.angle)
	_ok(str(mid["says"]).length() > 0 and str(mid["says"]) != str(said["says"]),
		"the pill says what is turning: %s" % mid["says"])
	_ok(_main.get("_grabbing") == true and camera.global_transform.is_equal_approx(turned_view),
		"the drag is the part's, and the view did not turn")
	var mark: Node3D = grab_drag.get("_mark")
	_ok((mark == null or not mark.visible) and not grab_drag.is_leaning(),
		"no balance marks drawn over the model, and it does not lean")
	await _save("2_turned.png")
	_button(camera.unproject_position(_about(grab.pivot, grab.axis, 30.0) * grab._hold), false)
	for _n: int in 240:
		await process_frame
		if not grab_drag.is_settling():
			break
	await _settle()
	var worst_frame: float = 0.0
	for us: int in frame_us:
		worst_frame = maxf(worst_frame, us / 1000.0)
	print("    drag frames: the grab's own work %.2f ms worst, %.2f ms mean over %d moves; whole frames %.1f ms worst"
		% [grab_drag.worst_ms, grab_drag.mean_ms, grab_drag.frames, worst_frame])
	_ok(grab_drag.worst_ms < 33.0, "each drag frame's own work is under 33 ms (%.2f ms worst)" % grab_drag.worst_ms)

	print("\n2. let go: kept for this visit, nothing written")
	var arm_turns: Array = []
	for arm: int in arms:
		var was: Transform3D = before[arm]
		var now: Transform3D = world.get_brick(arm).transform
		arm_turns.append(rad_to_deg((now.basis * was.basis.inverse()).get_rotation_quaternion().get_angle()))
	_ok(arm_turns.size() == 2 and float(arm_turns[0]) >= 3.0 and float(arm_turns[1]) >= 3.0,
		"both steering arms turned on their kingpins: the front wheels steer (%s°)" % ", ".join(
			arm_turns.map(func(d: float) -> String: return "%.1f" % d)))
	var moved: int = _differing(world, before)
	_ok(moved > 0, "%d parts stand where the turn left them" % moved)
	var after: Dictionary = view.page_state()["play"]
	_ok(view.played and after["reset"], "Reset is offered (%s)" % after["says"])
	_ok(fake.published.is_empty(), "nothing was published")
	_ok(fake.asked == [ID], "the link was asked for once, and never written to (%s)" % [fake.asked])
	_ok(str(fake.answer["body"]["model"]).sha256_text() == served, "the text the link served is unchanged")
	_ok(store.read_only and not store.keeps and store.share_id.is_empty(), "the store is still read-only, with no link of its own")
	var files_now: PackedStringArray = _files_under("user://")
	var new_files: Array = []
	for file: String in files_now:
		if not files_before.has(file) and not file.contains("shader_cache") and not file.contains("vulkan"):
			new_files.append(file)
	_ok(new_files.is_empty(), "nothing was written to the data folder, no model and no autosave (%s)" % [new_files])

	print("\n3. Reset")
	var named: Dictionary = view.controls_by_name()
	_ok(named.has("view_reset"), "Reset is on the viewer")
	if named.has("view_reset"):
		await _press(named["view_reset"])
	await _settle()
	_ok(_differing(world, before) == 0, "every part is back where it was built (%d differ)" % _differing(world, before))
	var reset: Dictionary = view.page_state()["play"]
	_ok(not view.played and not reset["reset"], "Reset is gone: %s" % reset["says"])
	await _save("3_reset.png")

	print("\n4. a finger")
	for _n: int in 240:
		await process_frame
		if grab_drag.is_ready():
			break
	bodies = grab_drag.read_bodies()
	spot = _spot(grab_drag, bodies, wheel, camera)
	_ok(not spot.is_empty(), "the steering wheel is under a finger")
	if not spot.is_empty():
		var start_view: Transform3D = camera.global_transform
		var finger: Vector2 = spot["screen"]
		# A fingertip beside the wheel's thin rim, on the part behind it, as
		# play_flow's finger came down: the wheel within a fingertip is meant.
		var verbs: EditVerbs = _main.get("_verbs")
		for step: int in 24:
			var beside: Vector2 = finger + Vector2.from_angle(TAU * float(step % 12) / 12.0) * (3.0 if step < 12 else 6.0)
			var there: int = verbs.brick_at(beside)
			if there != 0 and there != wheel and not (_main.get("_store") as ModelStore).scenery.has(there):
				finger = beside
				break
		var meant: Array = _main.call("_play_brick_near", finger)
		_ok(verbs.brick_at(finger) == wheel or int(meant[0]) == wheel,
			"a fingertip on #%d beside the wheel's rim means the wheel (#%d)" % [verbs.brick_at(finger), int(meant[0])])
		# Index 1, as a browser numbers a finger that follows another gesture.
		_touch(finger, FINGER, true)
		await process_frame
		_drag_finger(finger + tangent * 2.5)
		await process_frame
		var held: Grab = grab_drag.grab
		_ok(held != null and held.state == "moves", "the finger takes hold of the steering wheel")
		if held != null and held.state == "moves":
			for degrees: float in [-6.0, -12.0, -18.0, -24.0]:
				_drag_finger(camera.unproject_position(_about(held.pivot, held.axis, degrees) * held._hold))
				await process_frame
			await _settle()
			_ok(absf(held.angle) >= 12.0, "turned %.1f° by the finger" % held.angle)
			_ok(camera.global_transform.is_equal_approx(start_view), "the camera did not turn with the finger")
			await _save("4_finger.png")
			_touch(camera.unproject_position(_about(held.pivot, held.axis, -24.0) * held._hold), FINGER, false)
		for _n: int in 240:
			await process_frame
			if not grab_drag.is_settling():
				break
		await _settle()
		_ok(_differing(world, before) > 0 and view.played, "let go, the steering stays turned, Reset offered")
		named = view.controls_by_name()
		if named.has("view_reset"):
			await _press(named["view_reset"])
		await _settle()
		_ok(_differing(world, before) == 0, "Reset puts it back again")

	print("\n5. a drag on what does not move turns the view")
	var chassis: int = 0
	for key: Variant in bodies.anchors:
		var members: PackedInt64Array = bodies.members.get(int(key), PackedInt64Array())
		if members.size() > 10:
			chassis = int(members[0])
	var chassis_at: Dictionary = {}
	if chassis != 0:
		var members: PackedInt64Array = bodies.members[int(bodies.body_of[chassis])]
		for key: int in members:
			var brick: BrickWorld.Brick = world.get_brick(key)
			var screen: Vector2 = camera.unproject_position(brick.transform.origin)
			if root.get_visible_rect().grow(-40.0).has_point(screen) and _main.get("_verbs").brick_at(screen) == key \
					and not bool(_main.call("_over_panel_at", screen)) and not view.covers(screen):
				chassis_at = {"screen": screen, "brick": key}
				break
	_ok(not chassis_at.is_empty(), "a part of the chassis is under the pointer")
	if not chassis_at.is_empty():
		var view_was: Transform3D = camera.global_transform
		await _drag(chassis_at["screen"], chassis_at["screen"] + Vector2(120, 30))
		_ok(not camera.global_transform.is_equal_approx(view_was), "the view turned")
		_ok(_differing(world, before) == 0 and not view.played, "and nothing moved")

	print("\n6. Build it after a play shows the model as built")
	spot = _spot(grab_drag, grab_drag.read_bodies() if grab_drag.is_ready() else bodies, wheel, camera)
	if not spot.is_empty():
		await _drag(spot["screen"], spot["screen"] + tangent * 4.0)
		for _n: int in 240:
			await process_frame
			if not grab_drag.is_settling():
				break
	var moved_before_build: int = _differing(world, before)
	named = view.controls_by_name()
	if named.has("view_build"):
		await _press(named["view_build"])
	for _n: int in 120:
		await process_frame
	var mode: BuildMode = _main.get("_build_mode")
	_ok(moved_before_build > 0 and mode.is_open() and _differing(world, before) == 0,
		"a play's %d parts moved are put back as Build it opens" % moved_before_build)
	_ok(fake.published.is_empty(), "and the viewer published nothing, start to end")
	_main.queue_free()
	for _n: int in 10:
		await process_frame
	await _published_moves(text)
	_main.queue_free()
	for _n: int in 10:
		await process_frame
	await _motions_link()
	_finish()


## 7. Published from the builder: what moves goes with it, worked out from
## the joints the app finds, for its gallery card.
func _published_moves(text: String) -> void:
	print("\n7. published from the builder, what moves goes with it")
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
	var opened: Dictionary = store.open_text(text, "Probe Racer")
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty():
			break
	await _settle()
	var panel: SharePanel = _main.get("_share_panel")
	_ok(shell.can("share") and shell.run("share") and panel.visible, "File › Share… opens the panel")
	await panel.publish()
	await _settle()
	var sent: Dictionary = fake.published[0] if not fake.published.is_empty() else {}
	var moves: Array = sent.get("moves", []) if sent.get("moves") is Array else []
	_ok(moves.has("steering") and moves.all(func(word: Variant) -> bool: return Playable.KINDS.has(str(word))),
		"it sent what moves, from its joints: %s" % [moves])
	_ok(Playable.words(PackedStringArray(moves)).begins_with("Moves: steering"),
		"which its card says: %s" % Playable.words(PackedStringArray(moves)))


## 8. A model with motions of its own, opened by its link: a button each,
## played and taken back, and Reset.
func _motions_link() -> void:
	print("\n8. a model with motions of its own, opened by its link")
	var house: String = FileAccess.get_file_as_string(HOUSE)
	var lines: PackedStringArray = FileAccess.get_file_as_string(HOUSE_MOTIONS).strip_edges().split("\n")
	_ok(not house.is_empty() and lines.size() == 11, "1484-1 and its motions' %d lines" % lines.size())
	if house.is_empty():
		return
	# And a sequence of the two (unit 5): a button like any motion.
	lines.append('0 !BRICKWORKS MOTION "Open it all" SEQUENCE "Open the gates" "Open the mailbox"')
	var text: String = Motions.written_into(house, lines)
	var served: String = text.sha256_text()
	var files_before: PackedStringArray = _files_under("user://")
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": HOUSE_ID, "name": "Probe House", "author": "Probe Builder",
		"parts": 211, "url": "https://brickworks.diy/m/" + HOUSE_ID, "model": text}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", HOUSE_ID)
	_main.set("_shared", fake)
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 2400:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "the house opened (%s)" % (view.state if view != null else "none"))
	if view == null or view.state != "ready":
		return
	var steps: StepsBar = _main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	since = Time.get_ticks_msec()
	while view.play_motions.is_empty() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _settle()
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var said: Dictionary = view.page_state()["play"]
	_ok(said["shown"] and said["motions"] == ["Open the gates", "Open the mailbox", "Open it all"],
		"the pill has its motions, the sequence among them: %s" % [said["motions"]])
	_ok(said["title"] == "Play its motions" and str(said["says"]).begins_with("Press one to play it"),
		"and says how: %s / %s" % [said["title"], said["says"]])
	var named: Dictionary = view.controls_by_name()
	_ok(named.has("view_motion_1") and named.has("view_motion_2")
		and (named["view_motion_1"] as Button).text == "Open the gates",
		"a button each, in Reset's face, on the viewer")
	_ok(store.read_only and not store.keeps, "the store writes nothing")
	var gates: Array = []
	var mailbox: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		if brick.part_id == "3186":
			gates.append(brick.id)
		elif brick.part_id == "4346p03":
			mailbox = brick.id
	_ok(gates.size() == 2 and mailbox != 0, "it has two gates and a mailbox (%d, #%d)" % [gates.size(), mailbox])
	var before: Dictionary = _snapshot(world)
	await _save("5_motions.png")

	print("\n  Open the gates, pressed")
	var drawn_most: int = 0
	await _press(named["view_motion_1"])
	var playing: Dictionary = view.page_state()["play"]
	_ok(str(playing["says"]).begins_with("Playing “Open the gates”"), "it says it is playing: %s" % playing["says"])
	since = Time.get_ticks_msec()
	while not (_main.get("_motion_frames") as Array).is_empty() and Time.get_ticks_msec() - since < 10000:
		drawn_most = maxi(drawn_most, world.drawn_ids().size())
		await process_frame
	var took: int = Time.get_ticks_msec() - since
	_ok(drawn_most >= 2 and world.drawn_ids().is_empty(),
		"its frames were drawn as it went (%d parts drawn moving, %.1f s), then put away" % [drawn_most, took / 1000.0])
	var turned: Array = gates.map(func(id: int) -> float: return _turned(world, before, id))
	_ok(turned.all(func(d: float) -> bool: return absf(d - 90.0) < 2.0),
		"both gates swung open, %s°" % ", ".join(turned.map(func(d: float) -> String: return "%.1f" % d)))
	_ok(absf(_turned(world, before, mailbox)) < 0.1, "the mailbox did not move")
	var after: Dictionary = view.page_state()["play"]
	_ok(after["motions_out"] == ["Open the gates"] and (named["view_motion_1"] as Button).button_pressed,
		"its button is lit while the gates stand open")
	_ok(after["reset"] and str(after["says"]).contains("Press it again to put it back"),
		"Reset offered, and it says: %s" % after["says"])
	await _save("6_played.png")

	print("\n  Open the mailbox, pressed")
	await _press(named["view_motion_2"])
	await _played_out()
	_ok(absf(_turned(world, before, mailbox) - 90.0) < 2.0, "the mailbox opened, %.1f°" % _turned(world, before, mailbox))
	_ok(view.page_state()["play"]["motions_out"] == ["Open the gates", "Open the mailbox"], "both lit")

	print("\n  Open the gates, pressed again")
	await _press(named["view_motion_1"])
	await _played_out()
	var gates_off: int = gates.filter(func(id: int) -> bool: return absf(_turned(world, before, id)) > 0.1).size()
	_ok(gates_off == 0, "pressed again it plays backwards: both gates back where they were built (%d off)" % gates_off)
	_ok(absf(_turned(world, before, mailbox) - 90.0) < 2.0, "the mailbox still open")
	var back: Dictionary = view.page_state()["play"]
	_ok(back["motions_out"] == ["Open the mailbox"] and not (named["view_motion_1"] as Button).button_pressed,
		"the gates' button is not lit: %s" % back["says"])

	print("\n  Reset")
	named = view.controls_by_name()
	_ok(named.has("view_reset"), "Reset is on the viewer")
	if named.has("view_reset"):
		await _press(named["view_reset"])
	await _settle()
	_ok(_differing(world, before) == 0, "every part back where it was built (%d differ)" % _differing(world, before))
	var reset: Dictionary = view.page_state()["play"]
	_ok((reset["motions_out"] as Array).is_empty() and not reset["reset"] and not view.played,
		"no button lit, Reset gone: %s" % reset["says"])
	await _save("7_motions_reset.png")

	print("\n  Open it all, a sequence, pressed")
	named = view.controls_by_name()
	_ok(named.has("view_motion_3") and (named["view_motion_3"] as Button).text == "Open it all",
		"the sequence is a button like any motion")
	await _press(named["view_motion_3"])
	drawn_most = 0
	since = Time.get_ticks_msec()
	while not (_main.get("_motion_frames") as Array).is_empty() and Time.get_ticks_msec() - since < 10000:
		drawn_most = maxi(drawn_most, world.drawn_ids().size())
		await process_frame
	turned = gates.map(func(id: int) -> float: return _turned(world, before, id))
	var last: Dictionary = _main.get("_motion_last")
	_ok(turned.all(func(d: float) -> bool: return absf(d - 90.0) < 2.0)
		and absf(_turned(world, before, mailbox) - 90.0) < 2.0 and drawn_most >= 3,
		"the gates, then the mailbox, each from where the last left it: %s° and %.1f° (%d frames, %d parts drawn moving)"
		% [", ".join(turned.map(func(d: float) -> String: return "%.1f" % d)), _turned(world, before, mailbox),
		int(last.get("frames", 0)), drawn_most])
	_ok(view.page_state()["play"]["motions_out"] == ["Open it all"] and (named["view_motion_3"] as Button).button_pressed,
		"its button lit: %s" % view.page_state()["play"]["says"])
	await _press(named["view_motion_3"])
	await _played_out()
	_ok(_differing(world, before) == 0 and (view.page_state()["play"]["motions_out"] as Array).is_empty(),
		"pressed again, backwards in reverse order, every part as built (%d differ)" % _differing(world, before))
	named = view.controls_by_name()
	if named.has("view_reset"):
		await _press(named["view_reset"])
	await _settle()

	# What a press costs the app: the motion's frames worked out at once
	# (MotionPlayer.play), on this machine.
	var began: int = Time.get_ticks_usec()
	_main.call("_play_motion", "Open the gates")
	var cost_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	print("    a press of Open the gates (2 s, two gates) costs %.1f ms of one frame here" % cost_ms)
	await _played_out()
	named = view.controls_by_name()
	if named.has("view_reset"):
		await _press(named["view_reset"])
	await _settle()
	_ok(_differing(world, before) == 0, "Reset again: as built")
	_ok(fake.published.is_empty() and fake.asked == [HOUSE_ID], "nothing published; the link asked for once")
	_ok(str(fake.answer["body"]["model"]).sha256_text() == served, "the text the link served is unchanged")
	var new_files: Array = []
	for file: String in _files_under("user://"):
		if not files_before.has(file) and not file.contains("shader_cache") and not file.contains("vulkan"):
			new_files.append(file)
	_ok(new_files.is_empty() and store.read_only, "nothing was written to the data folder (%s)" % [new_files])


## Until the playing motion's frames are drawn and put away.
func _played_out() -> void:
	var since: int = Time.get_ticks_msec()
	while not (_main.get("_motion_frames") as Array).is_empty() and Time.get_ticks_msec() - since < 10000:
		await process_frame
	await _settle()


## How far [param id] has turned since [param before], degrees.
func _turned(world: BrickWorld, before: Dictionary, id: int) -> float:
	var was: Transform3D = before[id]
	var now: Transform3D = world.get_brick(id).transform
	return rad_to_deg((now.basis.orthonormalized() * was.basis.orthonormalized().inverse()).get_rotation_quaternion()
		.get_angle())


## A spot over [param key] on the screen and its joint's line there:
## {screen, pivot}, or {} when it does not show.
func _spot(grab_drag: GrabDrag, bodies: Bodies, key: int, camera: CadCamera) -> Dictionary:
	if bodies == null or not bodies.body_of.has(key):
		return {}
	var body: int = int(bodies.body_of[key])
	if not bodies.parent_link.has(body):
		return {}
	var found: Variant = grab_drag.handle_on(body, bodies.parent_link[body], PackedInt64Array([key]))
	if found == null:
		return {}
	var screen: Vector2 = found["screen"]
	var view: ShareView = _main.get("_share_view")
	if not root.get_visible_rect().grow(-8.0).has_point(screen) or bool(_main.call("_over_panel_at", screen)) \
			or view.covers(screen):
		return {}
	return {"screen": screen, "pivot": found.get("pivot", screen)}


static func _about(pivot: Vector3, axis: Vector3, degrees: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot) \
		* Transform3D(Basis(axis.normalized(), deg_to_rad(degrees)), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)


func _snapshot(world: BrickWorld) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		out[brick.id] = brick.transform
	return out


func _differing(world: BrickWorld, before: Dictionary) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		var was: Variant = before.get(brick.id)
		if was == null:
			count += 1
			continue
		var then: Transform3D = was
		if brick.transform.origin.distance_to(then.origin) > 0.01 \
				or not brick.transform.basis.is_equal_approx(then.basis):
			count += 1
	return count


func _files_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var access := DirAccess.open(dir)
	if access == null:
		return out
	for file: String in access.get_files():
		out.append(dir.path_join(file))
	for sub: String in access.get_directories():
		out.append_array(_files_under(dir.path_join(sub)))
	return out


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


## Where the mouse was last moved to: a move says how far it went
## (relative), which is what turns the view.
var _mouse_at := Vector2.ZERO


func _move(at: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = _as_event(at - _mouse_at)
	event.button_mask = mask
	_mouse_at = at
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _press(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at, 0)
	await process_frame
	_button(at, true)
	await process_frame
	_button(at, false)
	await _settle()


func _drag(from: Vector2, to: Vector2) -> void:
	_move(from, 0)
	await process_frame
	_button(from, true)
	await process_frame
	for n: int in 8:
		_move(from.lerp(to, float(n + 1) / 8.0), MOUSE_BUTTON_MASK_LEFT)
		await process_frame
	_button(to, false)
	await _settle()


var _finger_at := Vector2.ZERO
## The finger's index: not 0, as Chrome numbers a touch after earlier ones
## (play_flow's was 1, and a finger taken only at index 0 never played).
const FINGER := 1


func _touch(at: Vector2, index: int, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	event.position = _as_event(at)
	_finger_at = at
	Input.parse_input_event(event)


func _drag_finger(to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = FINGER
	event.position = _as_event(to)
	event.relative = _as_event(to - _finger_at)
	_finger_at = to
	Input.parse_input_event(event)


## Viewport coordinates as the window's, which an event carries.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _save(name: String) -> void:
	if not _windowed:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SHOTS + name))
		print("  wrote shots/play/%s" % name)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else
		"a shared model's steering turns by its wheel, nothing is kept, and Reset puts it back")
	quit(1 if _failures else 0)
