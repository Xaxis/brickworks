## clickfast: a click on a part of a big model answers at once (clickfast,
## 2026-11-27). simple2b found Properties counting what the part is joined
## to (SelectBy.connected, up to 501) on the click itself: 2,027 ms a click
## on 10030-1, 138 ms on 6685-1, 92 ms on 5972-1, on pre261 and live. The
## count now runs a slice a frame from the frame after (Inspector
## ._count_joined), and the line says it is counting until then.
##
##   godot --headless --path . --script src/dev/clickfast_probe.gd
##   godot --headless --path . --script src/dev/clickfast_probe.gd -- --case=10030
##
## --case= 10030, stepped, flexible (all when not said). On each, at 1400 x
## 900 with the Select tool, parts on show picked by the camera's own ray
## (EditVerbs.click, as a press of the left button runs it):
##   clicks   the first click after the model opens (the instructions' steps
##            worked out then on a model of 600 parts or fewer) and four more,
##            each from nothing selected: the click and the rest of its frame,
##            to the start of the frame after, under a frame (16.7 ms; the
##            least of the warm ones, and the first on its own); Properties
##            name the part clicked at once; the line "Joined to N" reached
##            within 3,000 frames, the same words a whole look from the part
##            finds on the spot (SelectBy.connected, no limit), and the
##            longest frame while it counted said; on the two of 600 parts or
##            fewer, its step in the instructions, worked out a slice a frame
##            too, as the steps worked out on the spot after the clicks.
##   switch   a part clicked, a second one clicked two frames later while the
##            first's count is under way: every frame after, Properties name
##            the second and never say the first's count, and once the first's
##            would have been done they say the second's. Then the same with
##            nothing clicked second (the line not shown) and with Shift
##            adding the second (the pair's facts, no "Joined to").
##   pieces   what a click costs, taken apart: each listener of the
##            selection's change alone, and Properties' own lines.
## The same probe runs in a tree from pre261 at the same moment: there the
## line is there on the click, and the counts are the same.
## Exits non-zero when a check fails.
extends SceneTree

const MODELS: Array = [
	["10030", "res://vendor/omr/files/10030-1.mpd"],
	["stepped", "res://vendor/omr/files/6685-1.mpd"],
	["flexible", "res://vendor/omr/files/5972-1.mpd"],
]
const FRAME_MS := 1000.0 / 60.0
## The line while the count is under way (Inspector._count_joined).
const COUNTING := "Joined to … other parts, directly or through others"
const JOINED_MOST := 500

var _main: Node
var _shell: Shell
var _store: ModelStore
var _world: BrickWorld
var _builder: Builder
var _verbs: EditVerbs
var _camera: CadCamera
var _bar: ModelBar
var _inspector: Inspector
var _failures: int = 0
var _asked: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _note(what: String) -> void:
	print("  note  %s" % what)


func _run() -> void:
	var cases: String = "10030,stepped,flexible"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			cases = arg.trim_prefix("--case=")
	_asked = cases.split(",", false)
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Account.where = "user://probe_session.json"
	Account._clear()
	Phone._on = 0
	Phone._wide = false
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	root.size = Vector2i(1400, 900)
	await _frames(30)
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_store.keeps = false
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_verbs = _main.get("_verbs")
	_camera = _main.get("_camera")
	_bar = _main.get("_bar")
	_inspector = _shell.inspector
	if not _inspector.is_open():
		_inspector.set_open(true)
	print("clickfast_probe: %s, Properties %s" % [root.size,
		"compact" if _inspector.compact else "open in the column"])
	for model: Array in MODELS:
		if str(model[0]) in _asked:
			await _case_model(str(model[0]), str(model[1]))
	print("\nclickfast_probe: %d failed" % _failures)
	quit(1 if _failures > 0 else 0)


func _case_model(tag: String, path: String) -> void:
	print("\n%s: %s" % [tag, path.get_file()])
	await _open_text(FileAccess.get_file_as_string(path), path.get_file().get_basename())
	_verbs.set_mode("select")
	_builder.clear_selection()
	await _frames(10)
	_note("%s: %d parts, the camera at %s" % [tag, _world.brick_count(), _camera.global_position.round()])
	var parts: Array = await _clickable(tag)
	if not _check("%s: five parts on show picked out alone by a click (%d)" % [tag, parts.size()],
			parts.size() >= 5):
		return
	# The first click after the model opens, then the rest warm.
	var took: Array = []
	var warm: Array = []
	for n: int in 5:
		var part: Dictionary = parts[n]
		var got: Dictionary = await _click(part)
		took.append(got)
		if n > 0:
			warm.append(float(got["answer"]))
		print("    %s #%d (%s, %s): click %.1f ms, to the next frame %.1f ms; \"%s\" after %d frames, %.0f ms, the longest %.1f ms"
			% [tag, n + 1, part["id"], part["name"], got["click"], got["answer"], got["line"],
				got["frames"], got["counted"], got["longest"]])
		_check("%s #%d: Properties name the part at once (\"%s\")" % [tag, n + 1, got["title"]],
			got["title"] == part["name"] and got["selected"] == [part["id"]])
		_check("%s #%d: \"%s\", what a whole look on the spot finds (\"%s\")" % [tag, n + 1,
			got["line"], part["words"]], got["line"] == part["words"])
		# Joined, Lock and Hide where the pointer found them when a count of
		# several comes; a count of none or one is a line shorter, and on the
		# click or the frame after it.
		if str(part["words"]).contains("other parts"):
			_check("%s #%d: Joined, Lock and Hide stay put as the count comes (y %.0f, then %.0f)"
				% [tag, n + 1, got["buttons_at"], got["buttons_after"]],
				is_equal_approx(float(got["buttons_at"]), float(got["buttons_after"])))
	# The steps as the booklet numbers them, worked out on the spot after the
	# clicks, so the first click found them unread.
	if _world.brick_count() <= 600:
		var steps: Array = Instructions.plan(_world, _shell.library, _store.scenery, {}, true)
		var last: int = (steps.back() as Instructions.Step).number if not steps.is_empty() else 0
		var step_of: Dictionary = {}
		for step: Instructions.Step in steps:
			for id: int in step.brick_ids:
				step_of[id] = step.number
		for n: int in took.size():
			var id: int = int(parts[n]["id"])
			var want: String = "Step %d of %d in the instructions" % [step_of[id], last] \
				if step_of.has(id) else ""
			_check("%s #%d: \"%s\" %d frames after the count, as the steps worked out on the spot (\"%s\")"
				% [tag, n + 1, took[n]["step"], took[n]["step_frames"], want], took[n]["step"] == want)
	warm.sort()
	_check("%s: the first click to the next frame in %.1f ms, under a frame" % [tag,
		took[0]["answer"]], float(took[0]["answer"]) < FRAME_MS)
	_check("%s: a click to the next frame in %.1f ms, under a frame (the least of %s)" % [tag,
		warm[0], warm], warm[0] < FRAME_MS)
	var longest: Array = []
	for got: Dictionary in took:
		longest.append(snappedf(float(got["longest"]), 0.1))
	longest.sort()
	# Said, not held to a frame: one part's look is one piece, and on 10030
	# a 6 x 12 plate of 3,720 boxes is 130-220 ms of it (SelectBy._joined_to).
	_note("%s: the longest frame while it counted %.1f ms (the least of %s)" % [tag,
		longest[0], longest])
	await _switch(tag, parts, took)
	await _pieces(tag, parts[1])
	_builder.clear_selection()
	await _frames(10)


## The parts on show a click picks out alone, each with where to click it,
## its name as Properties give it and the words a whole look finds. Spread
## through the model, with as many different counts as there are.
func _clickable(tag: String) -> Array:
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			ids.append(brick.id)
	ids.sort()
	var tried: int = 0
	var found: Array = []
	var stride: int = maxi(1, ids.size() / 80)
	var n: int = 0
	var why: Dictionary = {"off the view": 0, "not alone": 0}
	while n < ids.size() and found.size() < 12:
		var brick_id: int = ids[n]
		n += stride
		tried += 1
		var part: Dictionary = _alone(brick_id)
		if part.has("why"):
			why[part["why"]] = int(why[part["why"]]) + 1
			continue
		found.append(part)
	_enter("")
	await _frames(4)
	# Different counts first, so the switch has two that differ.
	var by_words: Dictionary = {}
	var spread: Array = []
	var rest: Array = []
	for part: Dictionary in found:
		if by_words.has(part["words"]):
			rest.append(part)
		else:
			by_words[part["words"]] = true
			spread.append(part)
	spread.append_array(rest)
	var said := PackedStringArray()
	for part: Dictionary in spread:
		said.append("%d joined to %d (whole look %.0f ms)" % [part["id"], part["joined"], part["look"]])
	_note("%s: %d of %d tried picked out alone (%s): %s" % [tag, spread.size(), tried, why,
		", ".join(said)])
	return spread


## [param brick_id] as a click picks it out alone, inside the sub-model it
## is in as a double click enters it: where to click, its name as
## Properties give it, the words a whole look from it finds. With "why"
## when no click does.
func _alone(brick_id: int) -> Dictionary:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var path: String = Assemblies.path_of(brick)
	_enter(path)
	var at: Vector2 = _point_on(brick_id)
	if at == Vector2.INF:
		return {"why": "off the view"}
	# Nobody told: Properties' first part after the model opens is the
	# first click's.
	_builder.set_block_signals(true)
	_builder.select_brick(brick_id, false)
	var alone: bool = _builder.selection.size() == 1 and _builder.selection.has(brick_id) \
		and (_shell.assemblies == null or _shell.assemblies.selected_assembly().is_empty())
	_builder.clear_selection()
	_builder.set_block_signals(false)
	if not alone:
		return {"why": "not alone"}
	var info: PartLibrary.PartInfo = _shell.library.parts.get(brick.part_id)
	var t0: int = Time.get_ticks_usec()
	var whole: int = SelectBy.connected(_world, _builder.lattice, [brick_id], _store.scenery).size() - 1
	var look_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	return {"id": brick_id, "at": at, "path": path, "joined": whole, "words": _words(whole),
		"name": Inventory._tidy(info.name) if info != null else brick.part_id, "look": look_ms}


## Editing inside [param path], as a double click on it enters it; the
## model's top for "".
func _enter(path: String) -> void:
	var tree: Assemblies = _shell.assemblies
	if tree == null or tree.entered == path:
		return
	if path.is_empty():
		tree.leave_to("")
	else:
		tree.enter(path)


## Another part a click picks out alone in the sub-model [param first] is
## in, its count unlike the first's where one is.
func _partner(first: Dictionary) -> Dictionary:
	var same: Dictionary = {}
	var tries: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if tries >= 200:
			break
		if brick.id == first["id"] or _store.scenery.has(brick.id) \
				or Assemblies.path_of(brick) != first["path"]:
			continue
		tries += 1
		var part: Dictionary = _alone(brick.id)
		if part.has("why"):
			continue
		if part["words"] != first["words"]:
			return part
		if same.is_empty():
			same = part
	return same


## Where a click picks [param brick_id] out, or INF when nowhere near its
## middle does.
func _point_on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	if brick == null:
		return Vector2.INF
	var view: Rect2 = root.get_visible_rect()
	var centre: Vector2 = _camera.screen_of(brick.transform.origin + Vector3(0, -6, 0))
	for offset: Vector2 in [Vector2.ZERO, Vector2(0, 4), Vector2(0, -4), Vector2(4, 0),
			Vector2(-4, 0), Vector2(0, 8), Vector2(0, -8)]:
		var at: Vector2 = centre + offset
		if view.has_point(at) and _verbs.brick_at(at) == brick_id:
			return at
	return Vector2.INF


## One click from nothing selected: the click itself and the rest of its
## frame, to the start of the next; then each frame until the joined line
## is there.
func _click(part: Dictionary) -> Dictionary:
	_enter(part["path"])
	_builder.clear_selection()
	await _frames(8)
	# The next frame's start, marked before anything the click began goes on
	# in it: told in the order they were connected, so this comes before the
	# count's next slice.
	process_frame.connect(_mark_frame, CONNECT_ONE_SHOT)
	var t0: int = Time.get_ticks_usec()
	_verbs.click(part["at"], false)
	var t1: int = Time.get_ticks_usec()
	var title: String = _inspector._title.text
	await process_frame
	var t2: int = _frame_began
	var out: Dictionary = {"click": (t1 - t0) / 1000.0, "answer": (t2 - t0) / 1000.0,
		"selected": _builder.selection.keys(), "title": title}
	# Where the buttons under the facts are, laid out by the frame after.
	out["buttons_at"] = _inspector._actions.global_position.y
	var frames: int = 0
	var longest: float = 0.0
	var last: int = t2
	while not _counted() and frames < 3000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest = maxf(longest, (now - last) / 1000.0)
		last = now
		frames += 1
	out["frames"] = frames
	out["longest"] = longest
	out["counted"] = (last - t0) / 1000.0
	out["line"] = _first_line()
	await _frames(2)
	out["buttons_after"] = _inspector._actions.global_position.y
	# Its step in the instructions, on a model of 600 parts or fewer.
	var waited: int = 0
	while _world.brick_count() <= 600 and _step_line().is_empty() and waited < 900:
		await process_frame
		waited += 1
	out["step"] = _step_line()
	out["step_frames"] = waited
	return out


func _step_line() -> String:
	if not _inspector._facts.visible:
		return ""
	for line: String in _inspector._facts.text.split("\n"):
		if line.begins_with("Step "):
			return line
	return ""


## A part's count under way when another is clicked, or nothing, or one
## added: Properties never say the first's count once it is not the one
## shown, and say the second's.
func _switch(tag: String, parts: Array, took: Array) -> void:
	var first: Dictionary = parts[0]
	for part: Dictionary in parts:
		if int(part["joined"]) > int(first["joined"]):
			first = part
	var second: Dictionary = _partner(first)
	_enter(first["path"])
	if not _check("%s: a second part picked out alone beside part %d in \"%s\"" % [tag, first["id"],
			first["path"]], not second.is_empty()):
		return
	print("    %s: %d (\"%s\") and then %d (\"%s\")" % [tag, first["id"], first["words"], second["id"],
		second["words"]])
	if second["words"] == first["words"]:
		_note("%s: no part beside it differs in its count; the switch is judged by the name" % tag)
	# Long enough after for the first's count to have been done twice over.
	var most_frames: int = 0
	for got: Dictionary in took:
		most_frames = maxi(most_frames, int(got["frames"]))
	var wait: int = maxi(60, most_frames * 2 + 10)
	for how: String in ["another", "nothing", "shift"]:
		_builder.clear_selection()
		await _frames(8)
		_verbs.click(first["at"], false)
		await _frames(2)
		var under_way: bool = not _counted()
		if how == "another":
			_verbs.click(second["at"], false)
		elif how == "nothing":
			_builder.clear_selection()
		else:
			_verbs.click(second["at"], true)
		var stale: int = 0
		var wrong_name: int = 0
		var stale_line: String = ""
		for _n: int in wait:
			await process_frame
			var line: String = _first_line()
			if how == "another":
				if line == first["words"] and first["words"] != second["words"]:
					stale += 1
					stale_line = line
				if _inspector._title.text != second["name"]:
					wrong_name += 1
			elif line.begins_with("Joined to") and _inspector._facts.visible:
				stale += 1
				stale_line = line
		var said: String = "the first's count %s two frames in" % ("under way" if under_way else "done")
		if how == "another":
			_check("%s: %s, a second part clicked: for %d frames never the first's \"%s\" (%d), the second named (%d off), then \"%s\" (want \"%s\")"
				% [tag, said, wait, first["words"], stale, wrong_name, _first_line(), second["words"]],
				stale == 0 and wrong_name == 0 and _first_line() == second["words"]
				and _builder.selection.keys() == [second["id"]])
		elif how == "nothing":
			_check("%s: %s, nothing then selected: for %d frames no joined line shown (%d%s)"
				% [tag, said, wait, stale, "" if stale_line.is_empty() else ", \"%s\"" % stale_line],
				stale == 0 and _builder.selection.is_empty())
		else:
			_check("%s: %s, Shift adding a second: for %d frames the pair's facts, no joined line (%d%s; \"%s\")"
				% [tag, said, wait, stale, "" if stale_line.is_empty() else ", \"%s\"" % stale_line,
					_first_line()], stale == 0 and _builder.selection.size() == 2)
	_builder.clear_selection()
	await _frames(8)


## What a click on [param part] costs, taken apart: the listeners of the
## selection's change, each alone, and Properties' own pieces.
func _pieces(tag: String, part: Dictionary) -> void:
	_enter(part["path"])
	_builder.clear_selection()
	await _frames(8)
	_builder.set_block_signals(true)
	var q0: int = Time.get_ticks_usec()
	_builder.select_brick(int(part["id"]), false)
	var quiet: float = (Time.get_ticks_usec() - q0) / 1000.0
	_builder.set_block_signals(false)
	var said := PackedStringArray(["select_brick told nobody %.1f" % quiet])
	for link: Dictionary in _builder.selection_changed.get_connections():
		var call: Callable = link["callable"]
		var target: Object = call.get_object()
		var where: String = target.get_class() if target != null else "?"
		if target != null and target.get_script() != null:
			where = str((target.get_script() as Script).resource_path.get_file())
		var t0: int = Time.get_ticks_usec()
		call.call(_builder.selection.size())
		said.append("%s.%s %.1f" % [where, call.get_method(), (Time.get_ticks_usec() - t0) / 1000.0])
	_note("%s: the listeners, ms: %s" % [tag, ", ".join(said)])
	var props := PackedStringArray()
	var t: int = Time.get_ticks_usec()
	_inspector.set("_steps_for", "")
	var step: String = str(_inspector.call("_step_words", int(part["id"])))
	props.append("_step_words cold %.1f (\"%s\")" % [(Time.get_ticks_usec() - t) / 1000.0, step])
	t = Time.get_ticks_usec()
	_inspector.call("_step_words", int(part["id"]))
	props.append("_step_words warm %.1f" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	var hinge: Variant = _builder.hinge_angle()
	props.append("hinge_angle %.1f (%s)" % [(Time.get_ticks_usec() - t) / 1000.0, hinge])
	t = Time.get_ticks_usec()
	var capped: int = SelectBy.connected(_world, _builder.lattice, [int(part["id"])], _store.scenery,
		JOINED_MOST + 1).size() - 1
	props.append("connected to %d %.1f" % [JOINED_MOST + 1, (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	_inspector.set("_shown", "")
	_inspector.call("_refresh", true)
	props.append("_refresh whole %.1f" % ((Time.get_ticks_usec() - t) / 1000.0))
	_note("%s: Properties, ms: %s; capped look %d" % [tag, ", ".join(props), capped])
	_builder.clear_selection()
	await _frames(8)


var _frame_began: int = 0


func _mark_frame() -> void:
	_frame_began = Time.get_ticks_usec()


## Whether Properties have said what the part is joined to.
func _counted() -> bool:
	var line: String = _first_line()
	return line.begins_with("Joined to") and line != COUNTING


func _first_line() -> String:
	return _inspector._facts.text.get_slice("\n", 0) if _inspector._facts.visible else ""


## As Properties say it (Inspector._count_joined).
static func _words(joined: int) -> String:
	return "Joined to %s" % ("nothing" if joined <= 0 else ("1 other part" if joined == 1
		else ("%s other parts, directly or through others" % ("%d" % joined if joined < JOINED_MOST
			else "%d or more" % JOINED_MOST))))


func _open_text(text: String, name: String) -> void:
	_main.call("clear_model")
	await _frames(4)
	var opened: Dictionary = await _bar.open_text_with_progress(text, name)
	_bar.opened.emit(int(opened.get("placed", 0)))
	for _n: int in 3000:
		if not _store.laying:
			break
		await process_frame
	await _frames(30)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
