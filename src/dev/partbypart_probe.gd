## Build it a part at a time (docs/APP_UX4.md, unit 7 partbypart), on a phone.
##
##   godot --path . --resolution 390x844 --script src/dev/partbypart_probe.gd
##   tools/probe.sh partbypart_tablet_probe     the same on a tablet, 1024 x 768
##   PROBE_SIZE=1280x720 tools/probe.sh partbypart_probe     any other window
##
## Build it showed a whole step at a time; BUF3D, on a phone, shows the next
## part alone and counts them, which is how a child, or anyone at a busy
## step, builds. No network: api/share.js is played by a stand-in that
## answers with models/car.ldr (61 parts, its steps worked out), as
## viewer_steps_probe's does. Its step 1 is five parts; the racer it also
## serves (8808-1) has no step of five but one that puts a sub-assembly on. Everything is done as a finger does it, on
## the step player's own controls:
##
##   1. Build it opens on the whole step, as the booklet shows it (the
##      choice kept), with One part beside the step's words.
##   2. One part tapped; the step before a step of five parts finished.
##   3. Five taps of Next: each shows exactly one new part in full colour
##      (every other part on the baseplate faded, the step's parts still to
##      come not there), outlined, its picture on the card with "k of 5 in
##      this step" under it and its name beside, read back from what the
##      world draws: the part in its own colour, the one before it pale.
##   4. The last part's Next goes to the next step, at its first part.
##   5. Back undoes one part: a swipe across the parts takes the next
##      step's first part off, back to the five-part step's fifth; a tap
##      takes the fifth off.
##   6. Every target on the page, Close, Back, Next, One part, Whole step,
##      the comments and "Go to step", 44 points or more each way.
##   7. Whole step tapped: the step whole again, Next to the next step; the
##      choice kept on this device for the next Build it.
##
## Pictures in shots/partbypart/, named by the window's size.
extends SceneTree

const CAR := "res://models/car.ldr"
const SHOTS := "res://shots/partbypart/"
## The bar's step: this many parts, put down one by one.
const FIVE := 5
const TARGET := 44.0

var _failures: int = 0
var _size: String = ""


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
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	var text: String = FileAccess.get_file_as_string(CAR)
	if text.is_empty():
		print("partbypart_probe: SKIPPED, no %s" % CAR)
		quit(3)
		return
	print("partbypart_probe: a %s window" % _size)
	BuildSteps._kept.clear()

	print("\n1. Build it, as the booklet shows it")
	var main: Node = await _open("P4rtByP4rt", text, "the car")
	var mode: BuildMode = await _build_it(main)
	var pages: BuildSteps = main.get("_build_pages")
	_ok(mode.is_open() and pages != null, "Build it opens the step player")
	var target: int = _five_part_step(pages) if pages != null else -1
	_ok(target > 0, "a step of %d parts, none of them a sub-assembly put on: step %d" % [FIVE, target])
	if target <= 0:
		await _close(main)
		_finish()
		return
	var world: BrickWorld = main.get("_world")
	var named: Dictionary = mode.controls_by_name()
	var has_choice: bool = named.has("build_one_part") and named.has("build_whole_step")
	_ok(has_choice and not bool(mode.get("by_part")),
		"the step whole, as the booklet shows it, with One part and Whole step on the page (%s)"
			% ("there" if has_choice else "no such choice: Next only ever turns a whole step"))
	await _shot("1_cover")

	print("\n2. One part, at the step before step %d finished" % target)
	if has_choice:
		await _tap(named["build_one_part"])
		_ok(bool(mode.get("by_part")) and bool(mode.call("recall_by_part")),
			"One part tapped: a part at a time, kept on this device")
		# Setting up, not what is measured: the page before, finished, as a
		# person who built it would have it.
		main.call("_build_go", target - 1, false, -1)
	else:
		main.call("_build_go", target - 1)
	await _settle()

	print("\n3. five taps of Next, a part each")
	var shown_before: int = int(main.call("build_state")["shown"])
	# Before step 1 is the cover, the model whole; none of it on the baseplate.
	var standing_before: int = pages.standing(target - 1) if target > 1 else 0
	_ok(shown_before == pages.standing(target - 1), "step %d finished: %d parts on the baseplate" % [
		target - 1, shown_before])
	var added: Array = pages.fresh(target).keys()
	var lit_before: int = -1
	for k: int in range(1, FIVE + 1):
		await _tap(mode.controls_by_name()["build_next"])
		await _pictures(main)
		var said: Dictionary = main.call("build_state")
		var lit: Array = _in_full_colour(world, pages)
		var want: int = int(added[k - 1])
		_ok(int(said["page"]) == target and int(said.get("part", 0)) == k
				and int(said.get("parts", 0)) == FIVE,
			"tap %d: step %d, part %d of %d (step %d, part %s)" % [k, target, k, FIVE,
				int(said["page"]), str(said.get("part", "none"))])
		_ok(lit == [want],
			"...exactly one new part in full colour, the step's part %d (%d in full colour: %s)" % [
				k, lit.size(), _names(world, lit)])
		_ok(int(said["shown"]) == standing_before + k and _hidden_after(world, added, k),
			"...%d on the baseplate, the step's %d still to come not there" % [int(said["shown"]),
				FIVE - k])
		var own: Color = _own_colour(main, want)
		var drawn: Color = _drawn_colour(world, want)
		_ok(_near(drawn, own), "...drawn in its own colour (%s, its colour %s)" % [drawn, own])
		if lit_before >= 0:
			var pale: Color = BrickWorld.faded(_own_colour(main, lit_before))
			_ok(_near(_drawn_colour(world, lit_before), pale),
				"...and the part before it pale now, with what was built (%s)" % _drawn_colour(
					world, lit_before))
		_ok(_outlined(main, world, want), "...outlined")
		# Called by name: the pages before this unit have no part to ask for.
		var lots: Array = pages.call("lots", target, k) if has_choice else pages.lots(target)
		var count_words: String = "%d of %d in this step" % [k, FIVE]
		_ok(str(said.get("part_count", "")) == count_words and int(said["lots"]) == 1
				and int(said["pictures"]) == 1 and lots.size() == 1
				and str(said["told"]) == "%s, %s" % [lots[0]["name"], lots[0]["colour_name"]],
			"...its picture on the card, \"%s\" under it, \"%s\" beside (card: %d picture%s)" % [
				said.get("part_count", ""), said["told"], int(said["pictures"]),
				"" if int(said["pictures"]) == 1 else "s"])
		await _shot("3_tap%d" % k)
		lit_before = want

	print("\n4. the last part's Next")
	await _tap(mode.controls_by_name()["build_next"])
	var said: Dictionary = main.call("build_state")
	var after: Array = _in_full_colour(world, pages)
	_ok(int(said["page"]) == target + 1 and int(said.get("part", 0)) == 1
			and int(said["shown"]) == pages.standing(target) + 1 and after.size() == 1,
		"goes to step %d, its first part alone (step %d, part %s, %d on the baseplate)" % [
			target + 1, int(said["page"]), str(said.get("part", "none")), int(said["shown"])])
	await _shot("4_next_step")

	print("\n5. Back undoes one part")
	var card: Rect2 = (mode.controls_by_name()["build_parts"] as Control).get_global_rect()
	var reach: float = 70.0 * mode.points()
	await _swipe(card.get_center() - Vector2(reach, 0), card.get_center() + Vector2(reach, 0))
	said = main.call("build_state")
	_ok(int(said["page"]) == target and int(said.get("part", 0)) == FIVE
			and int(said["shown"]) == pages.standing(target) and _hidden(world, after)
			and _in_full_colour(world, pages) == [int(added[FIVE - 1])],
		"a swipe to the right takes step %d's first part off: step %d, part %s, the fifth alone in its colours" % [
			target + 1, int(said["page"]), str(said.get("part", "none"))])
	await _tap(mode.controls_by_name()["build_back"])
	said = main.call("build_state")
	_ok(int(said["page"]) == target and int(said.get("part", 0)) == FIVE - 1
			and int(said["shown"]) == standing_before + FIVE - 1
			and _hidden(world, [added[FIVE - 1]])
			and _in_full_colour(world, pages) == [int(added[FIVE - 2])],
		"Back tapped takes the fifth off: part %s, %d on the baseplate, the fourth alone in its colours" % [
			str(said.get("part", "none")), int(said["shown"])])
	await _shot("5_back")

	print("\n6. every target a fingertip")
	mode.tell_changed(target)
	await _settle()
	said = main.call("build_state")
	var targets: Dictionary = said.get("targets", {})
	var small := PackedStringArray()
	for name: String in targets:
		var each: Array = targets[name]
		if float(each[0]) < TARGET or float(each[1]) < TARGET:
			small.append("%s %s" % [name, each])
	var wanted: Array[String] = ["build_close", "build_back", "build_next", "build_one_part",
		"build_whole_step", "build_comments", "build_changed_go"]
	var missing: Array[String] = wanted.filter(func(name: String) -> bool:
		return not targets.has(name))
	_ok(small.is_empty() and missing.is_empty(),
		"%d targets, each %d points or more each way: %s%s" % [targets.size(), int(TARGET),
			targets, "" if small.is_empty() else "; under: " + ", ".join(small)]
			+ ("" if missing.is_empty() else "; not measured: %s" % [missing]))
	await _shot("6_targets")

	print("\n7. the step at a time, kept as a choice")
	if has_choice:
		await _tap(mode.controls_by_name()["build_whole_step"])
		said = main.call("build_state")
		_ok(not bool(mode.get("by_part")) and int(said["page"]) == target
				and int(said.get("part", -1)) == 0 and int(said["fresh"]) == FIVE
				and _in_full_colour(world, pages).size() == FIVE,
			"Whole step: step %d whole, its %d new parts in full colour" % [int(said["page"]),
				_in_full_colour(world, pages).size()])
		await _tap(mode.controls_by_name()["build_next"])
		said = main.call("build_state")
		_ok(int(said["page"]) == target + 1 and int(said["shown"]) == pages.standing(target + 1),
			"...and Next turns a whole step (step %d)" % int(said["page"]))
		await _tap(mode.controls_by_name()["build_one_part"])
		await _close(main)
		main = await _open("P4rtByP4rt2", text, "the car, again")
		mode = await _build_it(main)
		await _tap(mode.controls_by_name()["build_next"])
		said = main.call("build_state")
		_ok(bool(mode.get("by_part")) and int(said["page"]) == 1 and int(said.get("part", 0)) == 1,
			"One part is kept for the next Build it: Start puts step 1's first part down (step %d, part %s)"
				% [int(said["page"]), str(said.get("part", "none"))])
	await _close(main)
	_finish()


## The first step that adds exactly five parts, puts no sub-assembly on, and
## has a step after it; one with a step before it, so what was built is
## there faded, if the model has one, else step 1.
func _five_part_step(pages: BuildSteps) -> int:
	var later: int = _five_part_step_from(pages, 2)
	return later if later > 0 else _five_part_step_from(pages, 1)


func _five_part_step_from(pages: BuildSteps, first: int) -> int:
	var sizes := PackedStringArray()
	for page: int in range(first, pages.last()):
		var step: Instructions.Step = pages.step_of(page)
		var on: bool = step != null and step.attaches()
		sizes.append("%d%s" % [pages.fresh(page).size(), " (put on)" if on else ""])
		if step != null and not on and pages.fresh(page).size() == FIVE \
				and pages.lots(page).size() > 0 and pages.fresh(page + 1).size() > 0:
			return page
	if first == 1:
		print("  its steps' new parts: %s" % ", ".join(sizes))
	return -1


## The parts drawn in their own colours: on the baseplate, not faded, not the
## ground.
func _in_full_colour(world: BrickWorld, pages: BuildSteps) -> Array:
	var faded: Dictionary = world.faded_ids()
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if not brick.hidden and not faded.has(brick.id) and not pages.scenery.has(brick.id):
			out.append(brick.id)
	out.sort()
	return out


func _hidden_after(world: BrickWorld, added: Array, k: int) -> bool:
	return _hidden(world, added.slice(k))


func _hidden(world: BrickWorld, ids: Array) -> bool:
	for brick_id: Variant in ids:
		var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
		if brick != null and not brick.hidden:
			return false
	return true


func _names(world: BrickWorld, ids: Array) -> String:
	var out := PackedStringArray()
	for brick_id: Variant in ids.slice(0, 6):
		var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
		out.append(brick.part_id if brick != null else "?")
	return ", ".join(out) + (" ..." if ids.size() > 6 else "")


## The outline is round the part alone, as the world draws it.
func _outlined(main: Node, world: BrickWorld, brick_id: int) -> bool:
	var outline: SelectionOutline = main.get("_build_outline")
	var overlay: CanvasItem = outline.get("_overlay")
	if not outline.visible or overlay == null or not overlay.visible:
		return false
	var want: AABB = world.drawn_as({brick_id: true})[2]
	var got: AABB = outline.get("_bounds")
	return got.position.distance_to(want.position) < 0.5 and got.size.distance_to(want.size) < 0.5


func _own_colour(main: Node, brick_id: int) -> Color:
	var world: BrickWorld = main.get("_world")
	var library: PartLibrary = main.get("_library")
	return library.color(world.get_brick(brick_id).color_code).shown


## The colour a brick is drawn in, read back from its batch, as
## share_view_probe reads it.
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


## Read back as the renderer keeps them, in half floats: near, not equal.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func _open(id: String, text: String, called: String) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": "Probe Model", "author": "Probe Builder",
		"parts": 93, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", id)
	main.set("_shared", fake)
	root.add_child(main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "%s opened as a shared link (%s)" % [called,
		view.state if view != null else "no viewer"])
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


func _finish() -> void:
	print("\npartbypart_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## Every part's picture on the card drawn, or a few seconds gone by.
func _pictures(main: Node) -> void:
	for _n: int in 300:
		var said: Dictionary = main.call("build_state")
		if int(said["pictures"]) >= int(said["lots"]):
			break
		await process_frame
	await _settle()


## Build it tapped on the viewer's bar, and the step player up: taken up
## once the steps are worked out, if they still were (main._build_wanted).
## A minute at most, by the clock: a busy box draws frames fast or slow.
func _build_it(main: Node) -> BuildMode:
	var view: ShareView = main.get("_share_view")
	await _tap(view.controls_by_name()["view_build"])
	var mode: BuildMode = main.get("_build_mode")
	var since: int = Time.get_ticks_msec()
	while not mode.is_open() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	if not mode.is_open():
		var steps: StepsBar = main.get("_steps")
		var button: Control = view.controls_by_name().get("view_build")
		print("  Build it not open after %d ms: steps still starting %s, page wanted %s, its button at %s, visible %s" % [
			Time.get_ticks_msec() - since, steps.is_starting(), main.get("_build_wanted"),
			button.get_global_rect() if button != null else "none",
			button.is_visible_in_tree() if button != null else false])
	await _settle()
	return mode


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw


## A finger's tap on [param control]: down and up where it is, as a phone
## sends it (the click is emulated from it, project.godot).
func _tap(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await process_frame
	await _settle()


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


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	root.get_texture().get_image().save_png("%s%s_%s.png" % [SHOTS, _size, name])


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
