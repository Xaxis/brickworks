## A link that opens a model playing one of its motions (docs/APP_UX5.md,
## unit 10 playlink).
##
##   godot --path . --resolution 1280x720 --script src/dev/playlink_probe.gd
##   PROBE_SIZE=1400x900 tools/probe.sh playlink_probe     a bigger window
##   PROBE_SIZE=390x844 tools/probe.sh playlink_probe      a phone
##   PROBE_SIZE=1024x768 tools/probe.sh playlink_probe     a tablet
##
## Kinebrick Play's link opens its model playing; Brickworks' opened a
## model's motions only on a press. Here 4096-1's crane (vendor/omr/files)
## is given its boom's motion as the builder suggests it ("Lift the boom"),
## and shared from File › Share… (api/share.js played by a stand-in, as
## share_play_probe's): the panel's Opens offers each motion, and the link
## it gives for one ends ?motion=lift-the-boom. Then the link, opened as a
## visitor opens it (the viewer, read-only):
##
##   1. ?motion=boom: the boom moving within 2 s of the model shown (the
##      viewer ready, its parts all here), its angle changing every frame
##      the screen draws while it moves, up, back down and up again: played
##      over and over; its button lit and the pill saying how to stop it.
##   2. Its button pressed: the boom goes back from where it is to as built,
##      the button unlit, Reset gone, every part where it was built.
##   3. Nothing written: the store read-only, nothing published by the
##      viewer, nothing in the data folder.
##   4. ?motion=wings, a name the crane has no motion of: it opens still (no
##      part drawn anywhere but where it was built, for 3 s after what moves
##      is read) and the pill says so from the moment it is shown.
##   5. With Reduce motion on (Settings): the link's motion played once, the
##      boom left raised, its button lit, and nothing moving after.
##
## And the words a link may carry, before any of it: the motion's name in any
## case, as the panel writes it, or a word only its name has; not a word two
## names share, nor words on two lines.
##
## It loads on a build from before (what is new is asked for by name), so
## that build fails its checks rather than failing to load.
## Pictures in shots/playlink/, named by the window's size: share_opens,
## 1_playing, 2_stopped, 4_missing.
extends SceneTree

const SHOTS := "res://shots/playlink/"
const CRANE := "res://vendor/omr/files/4096-1_Crane.mpd"
const MOTION := "Lift the boom"
## The link's id. Not ID: inside FakeShared, SharedModels' own ID (the
## pattern an id matches) would be the one meant.
const LINK_ID := "Pl4yL1nk01"
const FIRST_MS := 2000

var _failures: int = 0
var _main: Node
var _size: String = ""


class FakeShared extends SharedModels:
	var answer: Dictionary = {}
	var published: Array[Dictionary] = []

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func publish(_token: String, body: Dictionary) -> Dictionary:
		published.append(body.duplicate())
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 201, "body": {"id": LINK_ID, "url": "https://brickworks.diy/m/" + LINK_ID,
			"parts": 0, "listed": false, "version": 1}}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"shared": []}}

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "can_write": false, "why_not": "signed out"}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# A screen's rate: "every frame the screen draws" is a frame at 60 a second.
	Engine.max_fps = 60
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	var text: String = FileAccess.get_file_as_string(CRANE)
	if text.is_empty():
		print("playlink_probe: SKIPPED, no %s (tools/fetch_data.sh)" % CRANE)
		quit(3)
		return
	var shared: String = await _share(text)
	if shared.is_empty():
		_finish()
		return
	var files_before: PackedStringArray = _files_under("user://")
	await _playing(shared, files_before)
	await _missing(shared)
	await _once(shared)
	_finish()


## The crane given its boom's motion and shared: Opens offers it, and the
## link for it ends ?motion=lift-the-boom. The text published, its motion in it.
func _share(text: String) -> String:
	print("\nthe crane, its boom's motion kept, shared from File › Share… (%s)" % _size)
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
	await account.deployment.wait()
	account.email = "probe.builder@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var opened: Dictionary = store.open_text(text, "Probe Crane")
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty():
			break
	await _settle()
	var panel: SharePanel = _main.get("_share_panel")
	# Run as a menu runs it (Shell.attend may put it off a frame).
	var ran: bool = shell.can("share") and shell.run("share")
	await _settle()
	_ok(ran and panel.visible, "File › Share… opens the panel")
	await panel.publish()
	await _settle()
	# A model with no motions of its own: no choice to make.
	_ok(panel.controls_by_name().has("share_copy_link") and not panel.page_state().get("opens", false)
		and not panel.controls_by_name().has("share_opens"),
		"published with no motion of its own, its link has no Opens: %s" % _link(panel))
	panel.visible = false
	var player: MotionPlayer = _main.get("_motions")
	var offered: Array = player.suggest()
	_words(offered)
	var boom: Motions.Motion = null
	for one: Motions.Motion in offered:
		if one.name == MOTION:
			boom = one
	_ok(boom != null, "the builder suggests “%s” (%s)" % [MOTION, ", ".join(offered.map(
		func(one: Motions.Motion) -> String: return one.name))])
	if boom == null:
		return ""
	player.motions().put(boom)
	ran = shell.run("share")
	await _settle()
	_ok(ran and panel.visible, "File › Share… again")
	await panel.publish()
	await _settle()
	var opens: OptionButton = panel.controls_by_name().get("share_opens")
	_ok(opens != null and opens.is_visible_in_tree() and opens.item_count == 2
		and opens.get_item_text(0) == "Still" and opens.get_item_text(1) == "Playing “%s”" % MOTION,
		"published, Opens offers Still and Playing “%s” (%s)" % [MOTION,
			[] if opens == null else range(opens.item_count).map(func(n: int) -> String: return opens.get_item_text(n))])
	_ok(panel.url.ends_with("/m/" + LINK_ID) and _link(panel) == panel.url, "the link opens still at first: %s" % _link(panel))
	if opens != null:
		opens.select(1)
		opens.item_selected.emit(1)
	await _settle()
	var link: String = _link(panel)
	_ok(link == panel.url + "?motion=lift-the-boom" and panel.page_state().get("playing", "") == MOTION,
		"Playing “%s” chosen, the link opens playing it: %s" % [MOTION, link])
	var shown: LineEdit = _find_line(panel, link)
	_ok(shown != null, "the panel shows that link")
	var copy: Button = panel.controls_by_name().get("share_copy_link")
	if copy != null:
		await _press(copy)
	_ok(DisplayServer.clipboard_get() == link, "Copy link copies it: %s" % DisplayServer.clipboard_get())
	await _save("share_opens")
	var sent: String = str(fake.published.back().get("model", "")) if not fake.published.is_empty() else ""
	_ok(sent.contains("0 !BRICKWORKS MOTION \"%s\"" % MOTION), "the published text carries the motion")
	panel.visible = false
	_main.queue_free()
	for _n: int in 10:
		await process_frame
	return sent


## Opened by its link: the viewer with the stand-in answering with [param
## text], asked to play [param asked].
func _open_link(text: String, asked: String) -> FakeShared:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": LINK_ID, "name": "Probe Crane", "author": "Probe Builder",
		"parts": 0, "url": "https://brickworks.diy/m/" + LINK_ID, "model": text}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", LINK_ID)
	_main.set("_shared", fake)
	# As main reads the link's ?motion= at the edge (Motions.link_words, which
	# _words checks; asked for by name here, as a build from before has none).
	_main.set("_viewing_motion", asked)
	root.add_child(_main)
	return fake


func _view() -> ShareView:
	return _main.get("_share_view")


func _playing(text: String, files_before: PackedStringArray) -> void:
	print("\n1. ?motion=boom opens it playing (%s)" % _size)
	var fake: FakeShared = _open_link(text, "boom")
	var world: BrickWorld = null
	var shown_at: int = 0
	var moved_at: int = 0
	var built: Dictionary = {}
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 180000:
		await process_frame
		var view: ShareView = _view()
		if view == null:
			continue
		if view.state in ["failed", "gone"]:
			break
		if shown_at == 0 and view.state == "ready":
			shown_at = Time.get_ticks_msec()
			world = _main.get("_world")
			built = _snapshot(world)
		if shown_at > 0 and _drawn_off(world, built) > 0:
			moved_at = Time.get_ticks_msec()
			break
		# Long past the bar's 2 s: it is not coming.
		if shown_at > 0 and Time.get_ticks_msec() - shown_at > 20000:
			break
	var view: ShareView = _view()
	_ok(shown_at > 0, "the link's model opened (%s)" % (view.state if view != null else "none"))
	if shown_at == 0:
		return
	var first: int = moved_at - shown_at if moved_at > 0 else -1
	_ok(moved_at > 0 and first <= FIRST_MS, "it moves %d ms after the model is shown (under %d)" % [first, FIRST_MS])
	print("     (the viewer's own phases: %s)" % [_main.get("_view_phases")])
	var store: ModelStore = _main.get("_store")
	var moving: Array = world.drawn_ids().keys()
	_ok(not moving.is_empty(), "%d parts drawn moving" % moving.size())
	if moving.is_empty():
		return
	# The part that turns furthest: the boom's end.
	var lead: int = int(moving[0])
	# Its angle from as built, every frame, for two of its round trips.
	var angles: PackedFloat32Array = PackedFloat32Array()
	var looping_said: bool = false
	var lit: bool = false
	since = Time.get_ticks_msec()
	var shot_taken: bool = false
	while Time.get_ticks_msec() - since < 8000:
		await process_frame
		var angle: float = _angle(world, lead, built)
		angles.append(angle)
		var said: Dictionary = view.page_state()["play"]
		looping_said = looping_said or str(said["says"]).begins_with("Playing “%s” over and over." % MOTION)
		lit = lit or (said["motions_out"] as Array).has(MOTION)
		if not shot_taken and angle > 10.0 and _main.get("_motion_loop") == MOTION:
			shot_taken = true
			await _save("1_playing")
	var most: float = 0.0
	for a: float in angles:
		most = maxf(most, a)
	# Up, down, up: past 90% of the most, under 10%, past 90% again.
	var phase: int = 0
	for a: float in angles:
		if phase % 2 == 0 and a >= most * 0.9:
			phase += 1
		elif phase % 2 == 1 and a <= most * 0.1:
			phase += 1
	_ok(most >= 10.0, "the boom turns %.1f° at the most" % most)
	_ok(phase >= 3, "up, back down and up again: played over and over (%d turns of the way in 8 s)" % phase)
	# Every frame the screen draws while it moves: the frames off its rests.
	var moving_frames: int = 0
	var changed: int = 0
	for n: int in range(1, angles.size()):
		var resting: bool = angles[n] >= most - 0.05 or angles[n] <= 0.05
		if resting and (angles[n - 1] >= most - 0.05 or angles[n - 1] <= 0.05):
			continue
		moving_frames += 1
		if absf(angles[n] - angles[n - 1]) > 0.001:
			changed += 1
	_ok(moving_frames > 60 and changed >= moving_frames * 0.95,
		"its angle changes frame to frame while it moves: %d of %d frames (%d frames in 8 s)" % [
			changed, moving_frames, angles.size()])
	_ok(lit, "its button is lit while it plays")
	_ok(looping_said, "the pill says so: %s" % view.page_state()["play"]["says"])
	var named: Dictionary = view.controls_by_name()
	_ok(named.has("view_motion_1") and (named["view_motion_1"] as Button).text == MOTION,
		"its button is on the viewer")

	print("\n2. its button pressed: it goes back, and stops")
	var at_press: float = _angle(world, lead, built)
	if named.has("view_motion_1"):
		var button: Button = named["view_motion_1"]
		var at: Vector2 = button.get_global_rect().get_center()
		_move(at, 0)
		await process_frame
		at_press = _angle(world, lead, built)
		_button(at, true)
		await process_frame
		_button(at, false)
	var back: PackedFloat32Array = PackedFloat32Array()
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 6000:
		await process_frame
		back.append(_angle(world, lead, built))
		if world.drawn_ids().is_empty() and back.size() > 2:
			break
	var went_back: bool = back.size() > 2
	for n: int in range(1, back.size()):
		went_back = went_back and back[n] <= back[n - 1] + 0.001
	_ok(went_back and back[back.size() - 1] <= 0.01, "the boom goes back from %.1f° to %.1f°, never up again (%d frames)"
		% [at_press, back[back.size() - 1] if not back.is_empty() else -1.0, back.size()])
	await _settle()
	for _n: int in 60:
		await process_frame
	var still: Dictionary = view.page_state()["play"]
	_ok(_main.get("_motion_loop") == "" and not (still["motions_out"] as Array).has(MOTION) and still.get("looping") == "",
		"no longer played or lit: %s" % still["says"])
	_ok(_differing(world, built) == 0 and _drawn_off(world, built) == 0 and not view.played,
		"every part where it was built, Reset gone (%d differ)" % _differing(world, built))
	await _save("2_stopped")

	print("\n3. nothing written")
	_ok(store.read_only and not store.keeps, "the store writes nothing")
	_ok(fake.published.is_empty(), "the viewer published nothing")
	var new_files: Array = []
	for file: String in _files_under("user://"):
		if not files_before.has(file) and not file.contains("shader_cache") and not file.contains("vulkan"):
			new_files.append(file)
	_ok(new_files.is_empty(), "nothing was written to the data folder (%s)" % [new_files])
	_main.queue_free()
	for _n: int in 10:
		await process_frame


func _missing(text: String) -> void:
	print("\n4. ?motion=wings, which it has no motion of (%s)" % _size)
	_open_link(text, "wings")
	var view: ShareView = null
	var said_at_ready: String = ""
	for _n: int in 4000:
		await process_frame
		view = _view()
		if view != null and view.state == "ready":
			await process_frame
			said_at_ready = str(view.page_state()["play"]["says"])
			break
	_ok(view != null and view.state == "ready", "it opened")
	if view == null or view.state != "ready":
		return
	var world: BrickWorld = _main.get("_world")
	var built: Dictionary = _snapshot(world)
	var shown: Dictionary = view.page_state()["play"]
	_ok(shown["shown"] and said_at_ready.begins_with("There is no motion called “wings” in this model, so it opened still."),
		"the pill says so as it is shown: %s / %s" % [shown["title"], said_at_ready])
	var since: int = Time.get_ticks_msec()
	while not view.play_ready and Time.get_ticks_msec() - since < 120000:
		await process_frame
	var off: int = 0
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 3000:
		await process_frame
		off = maxi(off, _drawn_off(world, built))
	var after: Dictionary = view.page_state()["play"]
	_ok(off == 0 and _differing(world, built) == 0 and _main.get("_motion_loop") == "",
		"it stands still: no part drawn off where it was built for 3 s after what moves is read (%d)" % off)
	_ok(str(after["says"]).begins_with("There is no motion called “wings”") and (after["motions"] as Array).has(MOTION),
		"and still says so beside its own: %s / %s %s" % [after["title"], after["says"], after["motions"]])
	await _save("4_missing")
	_main.queue_free()
	for _n: int in 10:
		await process_frame


func _once(text: String) -> void:
	print("\n5. with Reduce motion on, played once (%s)" % _size)
	ShellPrefs.put("reduce_motion", true)
	_open_link(text, "lift-the-boom")
	var view: ShareView = null
	for _n: int in 4000:
		await process_frame
		view = _view()
		if view != null and view.state == "ready":
			break
	if view == null or view.state != "ready":
		_ok(false, "it opened")
		ShellPrefs.put("reduce_motion", false)
		return
	var world: BrickWorld = _main.get("_world")
	var built: Dictionary = _snapshot(world)
	var since: int = Time.get_ticks_msec()
	var began: bool = false
	var raised: bool = false
	while Time.get_ticks_msec() - since < 20000:
		await process_frame
		var frames: Array = _main.get("_motion_frames")
		began = began or not frames.is_empty()
		if began and frames.is_empty():
			raised = _differing(world, built) > 0
			break
	var stood: Dictionary = _snapshot(world)
	var off: int = 0
	since = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 3000:
		await process_frame
		off = maxi(off, _drawn_off(world, stood))
	var said: Dictionary = view.page_state()["play"]
	_ok(raised and off == 0 and _main.get("_motion_loop") == "" and (said["motions_out"] as Array).has(MOTION),
		"played once and left raised, its button lit, nothing moving after (%d off): %s" % [off, said["says"]])
	ShellPrefs.put("reduce_motion", false)
	_main.queue_free()
	for _n: int in 10:
		await process_frame


## The words a link may carry (Motions.for_link, slug, link_words), on the
## crane's own motions as the builder suggests them: [param offered].
func _words(offered: Array) -> void:
	print("\nthe words a link may carry")
	var edge: Script = load("res://src/assembly/motions.gd")
	var list := Motions.new()
	for one: Motions.Motion in offered:
		list.put(one)
	if not list.has_method("for_link"):
		_ok(false, "a link's words find a motion (no Motions.for_link)")
		return
	var found := func(asked: String) -> String:
		var motion: Motions.Motion = list.call("for_link", asked)
		return "" if motion == null else motion.name
	for asked: String in [MOTION, MOTION.to_upper(), "lift-the-boom", "boom", " Boom "]:
		_ok(found.call(asked) == MOTION, "“%s” is “%s”" % [asked, found.call(asked)])
	# A word more than one of the crane's names has, and words none has.
	var counts: Dictionary = {}
	for one: Motions.Motion in offered:
		for word: String in edge.call("slug", one.name).split("-"):
			counts[word] = int(counts.get(word, 0)) + 1
	var shared: Array = counts.keys().filter(func(word: String) -> bool: return counts[word] > 1).slice(0, 1)
	for asked: String in shared + ["wings", "", "-"]:
		_ok(found.call(asked) == "", "“%s” is none (%s)" % [asked, found.call(asked)])
	_ok(edge.call("link_words", "  boom ") == "boom" and edge.call("link_words", "boom\nwings") == ""
		and edge.call("link_words", "x".repeat(400)).length() == 120,
		"at the edge, one line of words, cut at 120")


## How far [param key] is drawn turned from where it was built, degrees.
func _angle(world: BrickWorld, key: int, built: Dictionary) -> float:
	var brick: BrickWorld.Brick = world.get_brick(key)
	if brick == null or not built.has(key):
		return 0.0
	var was: Transform3D = built[key]
	return rad_to_deg((world.drawn_at(brick).basis * was.basis.inverse()).get_rotation_quaternion().get_angle())


## How many parts are drawn anywhere but where [param built] has them.
func _drawn_off(world: BrickWorld, built: Dictionary) -> int:
	var count: int = 0
	for key: Variant in world.drawn_ids():
		var brick: BrickWorld.Brick = world.get_brick(int(key))
		if brick == null or not built.has(int(key)):
			continue
		var was: Transform3D = built[int(key)]
		var drawn: Transform3D = world.drawn_at(brick)
		if drawn.origin.distance_to(was.origin) > 0.01 or not drawn.basis.is_equal_approx(was.basis):
			count += 1
	return count


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


## The link the panel gives, asked for by name (a build from before had
## only its url).
func _link(panel: SharePanel) -> String:
	return str(panel.call("link")) if panel.has_method("link") else panel.url


func _find_line(node: Node, text: String) -> LineEdit:
	if node is LineEdit and (node as LineEdit).text == text and (node as LineEdit).is_visible_in_tree():
		return node
	for child: Node in node.get_children():
		var found: LineEdit = _find_line(child, text)
		if found != null:
			return found
	return null


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


## Viewport coordinates as the window's, which an event carries.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _save(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		var file: String = "%s_%s.png" % [_size, name]
		image.save_png(ProjectSettings.globalize_path(SHOTS + file))
		print("  wrote shots/playlink/%s" % file)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("\nplaylink_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	for _n: int in 5:
		await process_frame
	quit(1 if _failures > 0 else 0)
