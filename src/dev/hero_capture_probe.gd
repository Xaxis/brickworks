## The home page's loop of the studio at work (herostudio, 2026-11-26), taken
## from the real app, so every release can take it again and it never shows a
## studio that is gone. tools/site/hero_capture.py runs this, then cuts and
## encodes what it writes into web/img/hero/studio-*.
##
##   tools/probe.sh hero_capture_probe -- --frames=DIR [--only=desktop,phone] [--plan=FILE]
##   godot --path . --resolution 1680x1400 --script src/dev/hero_capture_probe.gd -- --frames=DIR
##
## The owner, 26 Nov: the hero a signed-out visitor sees should be "an
## animated screenshot of the actual studio so people immediately know what
## brickworks is". So each cut of tools/site/hero_capture.json (a desktop
## window, 16:10, and a phone's layout, 9:16) is played in a Brickworks of
## its own, as docs_shots_probe takes a picture: let in offline, the steps of
## its segments done as a person's pointer, keys and the menus' commands do
## them, and every frame of a segment's recorded steps written as
## DIR/<cut>/<segment>/NNNNN.png. Its window runs at a fixed 30 frames a
## second of the app's own time (--fixed-fps), however long a frame takes to
## draw and write, so what moves by the clock moves smoothly in the loop.
##
## A window shows no pointer of its own in its pixels, and a loop of a studio
## with no hand in it shows things happening by themselves. So the pointer is
## drawn into each frame where the steps put it, with a ring where it
## clicks; a phone's cut draws a fingertip where it taps instead.
##
## Every word in sight at each recorded frame is kept too, once a segment
## (DIR/<cut>/texts.json): herostudio's first loop filmed its render's status
## line, a folder under /tmp of the session that took it, and the share
## form's placeholder. hero_capture.py refuses a cut whose words hold a path,
## the session's names or a word of work under way.
##
## A render is never filmed: {"picture": ...} draws it off camera as File,
## Render… would and writes its PNG beside the frames, and a segment that is
## a "still" records nothing; hero_capture.py shows the picture full-frame.
##
## The steps are docs_shots_probe's (this extends it), and these:
##   {"glide": TARGET, "frames": 12}   the pointer carried there, eased, as a hand moves
##   {"tap": TARGET, "frames": 12}     glided there and clicked
##   {"hold": true} / {"let_go": true} the left button pressed / released where it is
##   {"frame": [x0, y0, z0, x1, y1, z1], "margin": 1.2}   the view framed on a box
##   {"look": {"yaw": 0.6, "pitch": 0.45}}   the view turned to these (radians), kept framed
##   {"turn": [dx, dy], "frames": 30}  the view turned as a drag across it turns it
##   {"zoom": 0.8, "frames": 20}       the view nearer (under 1) or further, eased
##   {"until": "path.property", "is": v, "within": 600}   waits for it, at most so many frames
##   {"repeat": STEP, "times": 6, "every": 4}   a step again and again
##   {"floor": "grid"}                 the floor new models get (ModelFloor), before New
##   {"lay": FILE, "parts": 1}         a model file's first parts put down at once
##   {"frame_on": FILE, "margin": 1.2} the view framed on a model file, as it will stand built
##   {"fit": 1.1}                      the view framed on what is built, with this margin
##   {"recent": ["3001", ...]}         these parts on the bin's Recent shelf, the shelf shown
##   {"drop": FILE, "from": 1, "pace": {...}}   the file's parts from that one on, each
##                                     taken and dropped onto its studs by hand (see _drop)
##   {"picture": "render", "size": [w, h], "quality": "best", "look": "product",
##    "stage": "wood", "view": "hero"} the model rendered off camera, as DIR/<cut>/render.png
## TARGET: [x, y] in the window's pixels, {"xy": [fx, fy]} a share of the
## window, {"tile": "3001"} a part's tile in the bin, {"swatch": 4} a colour's
## swatch, {"button": "Next", "in": "_steps"} a button by its words, {"at":
## [x, y, z]} a point in the model, {"part": ...} the top of a part, or a path
## from Main (`_steps._done`).
extends "res://src/dev/docs_shots_probe.gd"

const Shots := preload("res://src/dev/docs_shots_probe.gd")
const PLAN := "res://tools/site/hero_capture.json"
const CUT := "BRICKWORKS_HERO_CUT"
const CUT_OUT := "BRICKWORKS_HERO_OUT"
const CUT_PLAN := "BRICKWORKS_HERO_PLAN"
## How long one cut's window may take, its start and its render included,
## by the wall's clock.
const SECONDS_A_CUT := 2400
const FPS := 30
## Frames handed to the writers and not yet written, at most.
const WRITES_WAITING := 12

var _plan_path: String = PLAN
var _frames_dir: String = ""
## This cut's folder of frames (DIR/<cut>).
var _cut_out: String = ""
## The segment being recorded (its folder), or "" between them.
var _recording: String = ""
var _segment: String = ""
var _recorded: int = 0
var _writes: Array[int] = []
var _scale: float = 1.0
var _phone_cut: bool = false
var _arrow: Image
## The left button held down now.
var _held: bool = false
## Where and when (the recorded frame) the last click or tap began.
var _tapped_at: Vector2 = Vector2.INF
var _tapped_frame: int = -100
var _drawn: int = 0
## The words in sight, by segment: [[frame, kind, words], ...], each the
## first frame it was seen in that segment.
var _texts: Dictionary = {}
var _seen: Dictionary = {}
## Model files read, by path: their parts placed.
var _files: Dictionary = {}


func _start() -> void:
	var cut: String = OS.get_environment(CUT)
	if not cut.is_empty():
		_frames_dir = OS.get_environment(CUT_OUT)
		_plan_path = OS.get_environment(CUT_PLAN)
		await _record_cut(cut)
		return
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames_dir = arg.substr(9)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",", false)
		elif arg.begins_with("--plan="):
			_plan_path = arg.substr(7)
	if _frames_dir.is_empty():
		print("hero capture probe FAIL: no --frames=DIR")
		quit(2)
		return
	if not _frames_dir.begins_with("/"):
		_frames_dir = ProjectSettings.globalize_path("res://").path_join(_frames_dir)
	if not _plan_path.begins_with("/") and not _plan_path.begins_with("res://"):
		_plan_path = ProjectSettings.globalize_path("res://").path_join(_plan_path)
	if DisplayServer.get_name() == "headless":
		print("  no rendering device: the loop needs a window")
		quit(1)
		return
	var plan: Dictionary = _plan()
	if plan.is_empty():
		quit(1)
		return
	await _every_cut(plan, only)


func _plan() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_plan_path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("cuts") is Dictionary:
		print("hero capture probe FAIL: %s is not a plan of cuts" % _plan_path)
		return {}
	return parsed


# -- the run: a window a cut -------------------------------------------------------


func _every_cut(plan: Dictionary, only: PackedStringArray) -> void:
	var engine: PackedStringArray = PackedStringArray()
	var given: PackedStringArray = OS.get_cmdline_args()
	for i: int in given.size():
		if given[i] in ["--rendering-method", "--rendering-driver"] and i + 1 < given.size():
			engine.append_array([given[i], given[i + 1]])
	var cuts: Dictionary = plan["cuts"]
	var bad: PackedStringArray = PackedStringArray()
	var made: int = 0
	for name: String in cuts:
		if not only.is_empty() and not only.has(name):
			continue
		var cut: Dictionary = cuts[name]
		var out: String = _frames_dir.path_join(name)
		_remove_tree(out)
		DirAccess.make_dir_recursive_absolute(out)
		var data: String = _frames_dir.path_join(".data").path_join(name)
		DirAccess.make_dir_recursive_absolute(data)
		OS.set_environment("XDG_DATA_HOME", data)
		OS.set_environment(CUT, name)
		OS.set_environment(CUT_OUT, _frames_dir)
		OS.set_environment(CUT_PLAN, _plan_path)
		var args: PackedStringArray = PackedStringArray(["--path", ProjectSettings.globalize_path("res://")])
		args.append_array(engine)
		args.append_array(["--resolution", str(cut.get("window", "1680x1050")), "--fixed-fps", str(FPS),
			"--script", "res://src/dev/hero_capture_probe.gd"])
		var began: int = Time.get_ticks_msec()
		var pid: int = OS.create_process(OS.get_executable_path(), args)
		if pid <= 0:
			bad.append(name)
			print("  FAIL  %s: its window would not start" % name)
			continue
		while OS.is_process_running(pid):
			if Time.get_ticks_msec() - began > SECONDS_A_CUT * 1000:
				OS.kill(pid)
				break
			OS.delay_msec(250)
		var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("cut.json")))
		if said is Dictionary and bool(said.get("ok", false)):
			made += 1
			var counts: PackedStringArray = PackedStringArray()
			for segment: Dictionary in said.get("segments", []):
				counts.append("%s %s" % [segment.get("name", "?"), segment.get("still", "")
					if segment.has("still") else str(int(segment.get("frames", 0)))])
			print("  ok    %s: %s, frames %s, in %.0f s" % [name, said.get("size", "?"), ", ".join(counts),
				(Time.get_ticks_msec() - began) / 1000.0])
		else:
			bad.append(name)
			print("  FAIL  %s: %s" % [name, str(said.get("why", "no frames")) if said is Dictionary
				else "its window ended without its frames"])
		_remove_tree(data)
	_remove_tree(_frames_dir.path_join(".data"))
	print("")
	print("hero capture probe: %d cut(s) recorded%s" % [made,
		"" if bad.is_empty() else ", %d FAILED: %s" % [bad.size(), ", ".join(bad)]])
	quit(0 if bad.is_empty() and made > 0 else 1)


# -- one window, one cut -----------------------------------------------------------


func _record_cut(name: String) -> void:
	var plan: Dictionary = _plan()
	var cut: Dictionary = (plan.get("cuts", {}) as Dictionary).get(name, {})
	var out: String = _frames_dir.path_join(name)
	_cut_out = out
	if cut.is_empty():
		_tell(out, {"ok": false, "why": "no cut %s in %s" % [name, _plan_path]})
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_phone_cut = bool(cut.get("phone", false))
	if _phone_cut:
		Phone._on = 1
		Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	if cut.has("answers"):
		var server: Variant = Shots.Answered.new()
		server.said = (cut["answers"] as Dictionary).duplicate(true)
		_main.set("_shared", server)
	root.add_child(_main)
	var world: BrickWorld = null
	for _n: int in 900:
		await process_frame
		world = _main.get("_world")
		_shell = _main.get("_shell")
		if world != null and world.brick_count() > 1 and _shell != null and _main.get("_bin") != null:
			break
	if world == null or world.brick_count() <= 1:
		_tell(out, {"ok": false, "why": "no model came up on the baseplate"})
		quit(1)
		return
	_stop_playback()
	if _phone_cut:
		_hold_phone_scale()
	_hold_scale(float(cut.get("scale", 1.0)))
	await _let_in()
	await _frames(20)
	if _shell != null and _shell.first_build != null:
		_press(_shell.first_build.get("_skip"))
	_press(_main.get("_offer_close"))
	await _frames(10)
	_away()
	_arrow = _make_arrow(_scale)
	RenderingServer.frame_post_draw.connect(_on_drawn)
	var told: Array = []
	for segment: Variant in cut.get("segments", []):
		if not segment is Dictionary:
			continue
		var one: Dictionary = segment
		var title: String = str(one.get("name", "segment%d" % told.size()))
		for step: Variant in one.get("setup", []):
			await _step(step)
		if not _failed.is_empty():
			break
		if one.has("still"):
			# A picture its setup made off camera, shown by hero_capture.py: no
			# frames of the window at all.
			if not FileAccess.file_exists(out.path_join(str(one["still"]))):
				_failed.append("%s: no %s was made" % [title, one["still"]])
				break
			told.append({"name": title, "still": str(one["still"]), "caption": str(one.get("caption", ""))})
			continue
		await _frames(int(one.get("settle", 20)))
		DirAccess.make_dir_recursive_absolute(out.path_join(title))
		_recorded = 0
		_tapped_frame = -100
		_seen = {}
		_segment = title
		_recording = out.path_join(title)
		for step: Variant in one.get("steps", []):
			await _step(step)
			if not _failed.is_empty():
				break
		await _frames(int(one.get("hold", 0)) if _failed.is_empty() else 0)
		_recording = ""
		told.append({"name": title, "frames": _recorded, "caption": str(one.get("caption", "")),
			"speed": float(one.get("speed", 1.0))})
		if not _failed.is_empty():
			break
	for task: int in _writes:
		WorkerThreadPool.wait_for_task_completion(task)
	_writes.clear()
	_write_texts(out)
	var size: Vector2i = root.size
	if not _failed.is_empty():
		_tell(out, {"ok": false, "why": "; ".join(_failed), "segments": told})
		quit(1)
		return
	_tell(out, {"ok": true, "size": "%dx%d" % [size.x, size.y], "fps": FPS, "scale": _scale,
		"segments": told})
	_main.queue_free()
	await process_frame
	quit(0)


## The window's scale held at [param factor], as a browser's would be: the
## app's own matching of the screen's density let go, as _hold_phone_scale does.
func _hold_scale(factor: float) -> void:
	_scale = factor
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	root.content_scale_factor = factor


func _tell(out: String, what: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("cut.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(what, "\t") + "\n")
		file.close()
	if not bool(what.get("ok", false)):
		print("hero capture probe FAIL: %s" % what.get("why", ""))


func _write_texts(out: String) -> void:
	var file := FileAccess.open(out.path_join("texts.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"segments": _texts}, "\t") + "\n")
		file.close()


# -- each frame drawn -----------------------------------------------------------------


func _on_drawn() -> void:
	_drawn += 1
	if _recording.is_empty():
		return
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty():
		return
	_note_texts()
	picture.convert(Image.FORMAT_RGBA8)
	_draw_hand(picture)
	picture.convert(Image.FORMAT_RGB8)
	var file: String = _recording.path_join("%05d.png" % _recorded)
	_recorded += 1
	_writes.append(WorkerThreadPool.add_task(func() -> void: picture.save_png(file)))
	# Never more than a few frames waiting to be written: a render's thousands
	# held at once took the whole 16 GB heavy gives a job (11-26). The app's
	# clock is fixed, so waiting here changes nothing in the loop.
	while _writes.size() > WRITES_WAITING:
		WorkerThreadPool.wait_for_task_completion(_writes.pop_front())


## The words in sight in this frame, each kept the first time this segment
## shows it: every Label, RichTextLabel, Button and LinkButton shown, a
## LineEdit's or TextEdit's text (its placeholder while it is empty), an
## ItemList's items and the title of each window or dialog up, and the items
## of a menu open. Shown means shown in the tree, so a word scrolled out of
## its box counts too: a refusal too many, never a path filmed unseen.
func _note_texts() -> void:
	var kept: Array = _texts.get(_segment, [])
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node
		if not control.is_visible_in_tree():
			continue
		if control is RichTextLabel:
			_note(kept, "RichTextLabel", (control as RichTextLabel).get_parsed_text())
		elif control is Label:
			_note(kept, "Label", (control as Label).text)
		elif control is LineEdit:
			var line: LineEdit = control
			if line.text.is_empty():
				_note(kept, "placeholder", line.placeholder_text)
			else:
				_note(kept, "LineEdit", line.text)
		elif control is TextEdit:
			var box: TextEdit = control
			if box.text.is_empty():
				_note(kept, "placeholder", box.placeholder_text)
			else:
				_note(kept, "TextEdit", box.text)
		elif control is Button:
			_note(kept, "Button", (control as Button).text)
		elif control is LinkButton:
			_note(kept, "LinkButton", (control as LinkButton).text)
		elif control is ItemList:
			var items: ItemList = control
			for n: int in items.item_count:
				_note(kept, "ItemList", items.get_item_text(n))
	for node: Node in root.find_children("*", "Window", true, false):
		var window: Window = node
		if not window.visible:
			continue
		_note(kept, "Window", window.title)
		if window is PopupMenu:
			var menu: PopupMenu = window
			for n: int in menu.item_count:
				_note(kept, "PopupMenu", menu.get_item_text(n))
	_texts[_segment] = kept


func _note(kept: Array, kind: String, words: String) -> void:
	words = words.strip_edges()
	if words.is_empty():
		return
	var key: String = kind + "\t" + words
	if _seen.has(key):
		return
	_seen[key] = true
	kept.append([_recorded, kind, words])


## The pointer, or a fingertip, drawn into [param picture] where the steps put it.
func _draw_hand(picture: Image) -> void:
	if not _pointer_at.is_finite():
		return
	var since: int = _recorded - _tapped_frame
	if _phone_cut:
		var touching: bool = _held or since < 9
		if touching:
			var fade: float = 1.0 if _held else 1.0 - since / 9.0
			_disc(picture, _pointer_at if _held else _tapped_at, 19.0 * _scale, fade)
		return
	if since >= 0 and since < 12 and _tapped_at.is_finite():
		_ring(picture, _tapped_at, (7.0 + since * 1.6) * _scale, 1.0 - since / 12.0)
	var at := Vector2i(roundi(_pointer_at.x), roundi(_pointer_at.y))
	picture.blend_rect(_arrow, Rect2i(Vector2i.ZERO, _arrow.get_size()), at - Vector2i(roundi(_scale), roundi(_scale)))


## A ring where a click landed, widening and fading.
func _ring(picture: Image, at: Vector2, radius: float, strength: float) -> void:
	var width: float = 2.2 * _scale
	var box := Rect2i(Vector2i(floori(at.x - radius - width), floori(at.y - radius - width)),
		Vector2i(ceili((radius + width) * 2.0) + 1, ceili((radius + width) * 2.0) + 1))
	box = box.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	var ink := Color(1.0, 0.8, 0.2)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var off: float = absf(Vector2(x + 0.5, y + 0.5).distance_to(at) - radius)
			if off < width:
				var a: float = clampf(width - off, 0.0, 1.0) * 0.9 * strength
				picture.set_pixel(x, y, picture.get_pixel(x, y).lerp(ink, a))


## A fingertip on the glass: a soft pale disc with a darker edge.
func _disc(picture: Image, at: Vector2, radius: float, strength: float) -> void:
	if not at.is_finite():
		return
	var box := Rect2i(Vector2i(floori(at.x - radius - 2.0), floori(at.y - radius - 2.0)),
		Vector2i(ceili(radius * 2.0) + 5, ceili(radius * 2.0) + 5))
	box = box.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(at)
			if d > radius + 1.0:
				continue
			var edge: float = clampf(radius + 1.0 - d, 0.0, 1.0)
			var ink: Color = Color(0.15, 0.15, 0.18) if d > radius - 2.0 * _scale else Color(1, 1, 1)
			var a: float = (0.55 if d > radius - 2.0 * _scale else 0.42) * edge * strength
			picture.set_pixel(x, y, picture.get_pixel(x, y).lerp(ink, a))


## The desktop's arrow, white with a dark edge, at [param scale], drawn once.
static func _make_arrow(scale: float) -> Image:
	var shape: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0, 16.5), Vector2(4, 12.6),
		Vector2(6.8, 19), Vector2(9.4, 17.9), Vector2(6.7, 11.7), Vector2(11.8, 11.7)])
	for n: int in shape.size():
		shape[n] = shape[n] * scale + Vector2(scale, scale)
	var size := Vector2i(ceili(14.0 * scale) + 2, ceili(22.0 * scale) + 2)
	var arrow: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var edge: float = 1.1 * scale
	for y: int in size.y:
		for x: int in size.x:
			var inside: int = 0
			var near: int = 0
			for sy: int in 4:
				for sx: int in 4:
					var p := Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0)
					if Geometry2D.is_point_in_polygon(p, shape):
						inside += 1
					if inside > 0 or _near_edge(p, shape, edge):
						near += 1
			var fill: float = inside / 16.0
			var outline: float = near / 16.0
			if outline <= 0.0:
				continue
			var white: Color = Color(1, 1, 1, 1)
			var dark: Color = Color(0.05, 0.05, 0.07, 1)
			var shrunk: bool = fill > 0.0 and not _near_edge(Vector2(x + 0.5, y + 0.5), shape, edge * 0.9)
			var colour: Color = white if shrunk else dark
			colour.a = outline
			arrow.set_pixel(x, y, colour)
	return arrow


static func _near_edge(p: Vector2, shape: PackedVector2Array, within: float) -> bool:
	for n: int in shape.size():
		var a: Vector2 = shape[n]
		var b: Vector2 = shape[(n + 1) % shape.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= within:
			return true
	return false


# -- steps --------------------------------------------------------------------------


func _step(step: Variant) -> void:
	if not step is Dictionary:
		_failed.append("a step that is not an object: %s" % str(step))
		return
	var one: Dictionary = step
	# First: a picture's own "look" and "view" are the render's, not a step's.
	if one.has("picture"):
		await _picture(one)
	elif one.has("repeat"):
		for _n: int in int(one.get("times", 1)):
			await _step(one["repeat"])
			await _frames(int(one.get("every", 0)))
	elif one.has("glide") or one.has("tap"):
		# Found twice, a frame apart: finding a tile can scroll the bin to it.
		var target: Variant = one.get("glide", one.get("tap"))
		var to: Variant = _target(target)
		await process_frame
		to = _target(target) if to != null else null
		if to != null:
			await _glide(to, int(one.get("frames", 12)))
			if one.has("tap"):
				await _frames(int(one.get("wait", 3)))
				await _tap()
	elif one.has("zoom"):
		# Nearer (under 1) or further, eased, as a wheel turned slowly does.
		var camera: CadCamera = _main.get("_camera")
		var count: int = maxi(1, int(one.get("frames", 20)))
		var whole: float = log(float(one["zoom"])) * 100.0
		for n: int in count:
			camera.zoom_by_drag(whole * (_ease((n + 1.0) / count) - _ease(float(n) / count)))
			await process_frame
	elif one.has("hold"):
		_button(true)
		await process_frame
	elif one.has("let_go"):
		_button(false)
		await process_frame
	elif one.has("frame"):
		var box: Array = one["frame"]
		var camera: CadCamera = _main.get("_camera")
		var from := Vector3(float(box[0]), float(box[1]), float(box[2]))
		var to := Vector3(float(box[3]), float(box[4]), float(box[5]))
		camera.frame(AABB(from, to - from).abs(), float(one.get("margin", 1.25)))
	elif one.has("frame_on"):
		var box: AABB = _file_box(str(one["frame_on"]))
		if box.size.length_squared() <= 0.0:
			_failed.append("nothing to frame in %s" % one["frame_on"])
		else:
			(_main.get("_camera") as CadCamera).frame(box, float(one.get("margin", 1.25)))
	elif one.has("fit"):
		var camera: CadCamera = _main.get("_camera")
		camera.frame(_main.call("_built_bounds"), float(one["fit"]))
	elif one.has("look"):
		var camera: CadCamera = _main.get("_camera")
		var aim: Dictionary = camera.aim()
		var look: Dictionary = one["look"]
		aim["yaw"] = float(look.get("yaw", aim["yaw"]))
		aim["pitch"] = float(look.get("pitch", aim["pitch"]))
		if look.has("distance"):
			aim["distance"] = float(look["distance"])
		camera.aim_at(aim)
	elif one.has("turn"):
		var camera: CadCamera = _main.get("_camera")
		var by: Array = one["turn"]
		var count: int = maxi(1, int(one.get("frames", 30)))
		# "drag": the hand drawn dragging across the view as it turns, pressed
		# where it starts; no button is sent, so nothing else hears a drag.
		var drag: bool = bool(one.get("drag", false)) and _pointer_at.is_finite()
		if drag:
			_held = true
			_tapped_at = _pointer_at
			_tapped_frame = _recorded
		for n: int in count:
			# Eased: slow in and out, as a hand turns it.
			var share: float = (_ease((n + 1.0) / count) - _ease(float(n) / count))
			camera.turn_by_drag(Vector2(float(by[0]), float(by[1])) * share)
			if drag:
				_pointer_at += Vector2(float(by[0]), float(by[1])) * share * _scale
			await process_frame
		_held = false
	elif one.has("until"):
		# docs_shots_probe's own, but bounded by "within": its "frames" is
		# a wait of its own, matched first.
		var path: String = one["until"]
		var waited: int = 0
		while waited < int(one.get("within", 600)):
			var at: Variant = _node(path.get_basename())
			if at != null and (at as Object).get(path.get_extension()) == one.get("is"):
				break
			await process_frame
			waited += 1
		if waited >= int(one.get("within", 600)):
			_failed.append("%s was never %s" % [path, str(one.get("is"))])
	elif one.has("floor"):
		# What New lays under a model, as Settings' choice of floor does.
		ModelFloor.prefer(ModelFloor.make(str(one["floor"])))
	elif one.has("lay"):
		var world: BrickWorld = _main.get("_world")
		var builder: Builder = _main.get("_builder")
		var parts: Array = _file_parts(str(one["lay"]))
		for n: int in mini(int(one.get("parts", parts.size())), parts.size()):
			var p: LdrModel.Placement = parts[n]
			builder.register(world.add_brick(p.part_id, p.color_code, p.transform), p.part_id, p.transform)
		for _n: int in 600:
			await process_frame
			if not _loading():
				break
	elif one.has("recent"):
		# The shelf a person's last parts are on, these first, and shown.
		var ids: Array = one["recent"]
		for n: int in range(ids.size() - 1, -1, -1):
			PartShelf.used(str(ids[n]))
		(_main.get("_bin") as PartsBin).show_category(PartsBin.RECENT)
	elif one.has("drop"):
		await _drop(one)
	else:
		await _do(one)
	await _frames(int(one.get("after", 0)))


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# -- building by hand ------------------------------------------------------------


## The parts of the model file at [param path], placed as it places them.
func _file_parts(path: String) -> Array:
	if not _files.has(path):
		var model: LdrModel = LdrModel.load_file(path)
		var library: PartLibrary = _main.get("_library")
		_files[path] = model.flatten(library.parts) if model != null else []
		if model == null:
			_failed.append("no model file %s" % path)
	return _files[path]


## What the model file at [param path] takes up, built.
func _file_box(path: String) -> AABB:
	var library: PartLibrary = _main.get("_library")
	var box := AABB()
	var first: bool = true
	for p: LdrModel.Placement in _file_parts(path):
		var mesh: Lbm.PartMesh = library.mesh_for(p.part_id)
		if mesh == null:
			continue
		var one: AABB = p.transform * mesh.bounds
		box = one if first else box.merge(one)
		first = false
	return box


## A model file's parts from the [code]from[/code]th to the
## [code]to[/code]th, each put on as a person does it. A part not already
## in hand in its colour is taken: on a computer its colour's swatch tapped
## if the bin is in another, then its tile; on a phone as the bin's sheet
## sends it. The pointer is carried over the model, the part turned with R
## to the file's turn while its ghost is in sight, and clicked down where
## the ghost then stands, which is the file's place for it, found before the
## pointer sets off (_aim_for). Each must land there, or the cut fails.
## [code]pace[/code]: frames for each move ({"swatch": 9, "tile": 10,
## "glide": 14, "turn": 5, "after": 4}).
func _drop(one: Dictionary) -> void:
	var parts: Array = _file_parts(str(one["drop"]))
	var pace: Dictionary = one.get("pace", {})
	var builder: Builder = _main.get("_builder")
	var bin: PartsBin = _main.get("_bin")
	var verbs: EditVerbs = _main.get("_verbs")
	var world: BrickWorld = _main.get("_world")
	for n: int in range(int(one.get("from", 0)), mini(int(one.get("to", parts.size())), parts.size())):
		var p: LdrModel.Placement = parts[n]
		var in_hand: bool = verbs.mode == "place" and builder.held_part == p.part_id \
			and builder.held_color == p.color_code
		if not in_hand:
			if _phone_cut:
				bin.color_chosen.emit(p.color_code)
				bin.part_chosen.emit(p.part_id)
				await _frames(int(pace.get("tile", 10)))
			else:
				if bin.selected_color() != p.color_code:
					await _step({"tap": {"swatch": p.color_code}, "frames": int(pace.get("swatch", 9))})
				await _step({"tap": {"tile": p.part_id}, "frames": int(pace.get("tile", 10))})
			for _n: int in 120:
				if builder.held_part == p.part_id and verbs.mode == "place":
					break
				await process_frame
		if builder.held_part != p.part_id or builder.held_color != p.color_code:
			_failed.append("part %d (%s in %d) never came to hand" % [n, p.part_id, p.color_code])
			return
		var aim: Array = _aim_for(p)
		if aim.is_empty():
			_failed.append("no point puts the ghost of part %d (%s) on its place" % [n, p.part_id])
			return
		await _glide(aim[1], int(pace.get("glide", 14)))
		# R a quarter turn at a time while the ghost is in sight, as a person
		# turns it; a phone has no key, and a key the window did not take is
		# turned as R turns it, so the ghost turns all the same.
		for _turn: int in 4:
			if builder.held_rotation == int(aim[0]):
				break
			var turned: int = builder.held_rotation
			if not _phone_cut:
				await _key("R")
			if builder.held_rotation == turned:
				builder.rotate_held(1)
				_main.call("_refresh_preview")
			await _frames(int(pace.get("turn", 5)))
		await _frames(int(pace.get("wait", 2)))
		var before: int = world.brick_count()
		await _tap()
		var landed: bool = false
		for brick: BrickWorld.Brick in world.bricks():
			if brick.part_id == p.part_id and brick.color_code == p.color_code \
					and _same_place(brick.transform, p.transform, _bounds_of(p.part_id)):
				landed = true
		if world.brick_count() != before + 1 or not landed:
			_failed.append("part %d (%s) did not land on its place" % [n, p.part_id])
			return
		await _frames(int(pace.get("after", 4)))


## Where in the window the pointer puts the ghost of the part in hand
## exactly on [param p]'s place, and with which of the hand's quarter turns:
## [turns, point], or [] when none does within a few tries. Asked of the
## builder as the pointer asks it, all inside one frame, so nothing of the
## asking is drawn; the ghost is aimed where the pointer is again after.
func _aim_for(p: LdrModel.Placement) -> Array:
	var builder: Builder = _main.get("_builder")
	var camera: CadCamera = _main.get("_camera")
	var local: AABB = _bounds_of(p.part_id)
	var want: AABB = p.transform * local
	var window: Transform2D = root.get_final_transform()
	var back: Transform2D = window.affine_inverse()
	var was: int = builder.held_rotation
	var found: Array = []
	for k: int in 4:
		var turns: int = posmod(was + k, 4)
		builder.held_rotation = turns
		# First the middle of its foot, on what it will stand on.
		var foot := Vector3(want.get_center().x, want.position.y, want.get_center().z)
		var at: Vector2 = window * camera.screen_of(foot)
		for _try: int in 8:
			var seen: Vector2 = back * at
			builder.update_preview(camera.ray_origin(seen), camera.ray_normal(seen))
			if not builder.has_preview():
				break
			var ghost: Transform3D = builder.ghost_transform()
			if _same_place(ghost, p.transform, local):
				found = [turns, at]
				break
			at += window.basis_xform(camera.screen_of(p.transform.origin) - camera.screen_of(ghost.origin))
		if not found.is_empty():
			break
	builder.held_rotation = was
	_main.call("_refresh_preview")
	return found


func _bounds_of(part_id: String) -> AABB:
	var mesh: Lbm.PartMesh = (_main.get("_library") as PartLibrary).mesh_for(part_id)
	return mesh.bounds if mesh != null else AABB(Vector3(-10, 0, -10), Vector3(20, 24, 20))


## Whether [param a] puts a part where [param b] does: the same origin, and
## the part's box turned the same way about it (a 2 x 4 brick turned half
## round is the same brick; a slope is not).
static func _same_place(a: Transform3D, b: Transform3D, local: AABB) -> bool:
	if a.origin.distance_to(b.origin) > 0.5:
		return false
	var one: AABB = Transform3D(a.basis, Vector3.ZERO) * local
	var two: AABB = Transform3D(b.basis, Vector3.ZERO) * local
	return one.position.distance_to(two.position) < 0.5 and one.size.distance_to(two.size) < 0.5


# -- the render, off camera ---------------------------------------------------------


## The model rendered as File, Render… renders it, without its panel: never
## a frame of the dialog, its bar, its status line or the folder it wrote to
## in the loop (herostudio's first loop filmed all four). The picture alone
## is written as DIR/<cut>/<name>.png. {"picture": NAME, "size": [w, h],
## "quality": "quick|good|best", "look": "window|product", "stage": one of
## StudioRender.STAGES, "view": one of StudioRender.VIEWS}.
func _picture(one: Dictionary) -> void:
	var dialog: RenderDialog = _main.get("_render")
	if dialog == null:
		_failed.append("no render dialog to render with")
		return
	var chosen: RenderSettings = dialog.settings.copy()
	var grades: Dictionary = {"quick": RenderSettings.Quality.QUICK, "good": RenderSettings.Quality.GOOD,
		"best": RenderSettings.Quality.BEST}
	chosen.quality = grades.get(str(one.get("quality", "best")), RenderSettings.Quality.BEST)
	chosen.look = str(one.get("look", "product"))
	var size: Array = one.get("size", [1920, 1200])
	chosen.size = Vector2i(int(size[0]), int(size[1]))
	chosen.view = str(one.get("view", "hero"))
	chosen.forget_eye()
	if one.has("stage"):
		var wrong: String = chosen.use_stage(str(one["stage"]), true)
		if not wrong.is_empty():
			_failed.append("render: %s" % wrong)
			return
	# Its file goes beside the data of this cut's window, never to Downloads.
	dialog.folder = OS.get_environment("XDG_DATA_HOME").path_join("render")
	DirAccess.make_dir_recursive_absolute(dialog.folder)
	var began: int = Time.get_ticks_msec()
	await dialog.render_for("picture", chosen)
	var image: Image = dialog.last_picture()
	if image == null or image.is_empty():
		_failed.append("the render made no picture")
		return
	image.convert(Image.FORMAT_RGB8)
	image.save_png(_cut_out.path_join(str(one["picture"]) + ".png"))
	print("  rendered %s at %dx%d in %.0f s" % [one["picture"], image.get_width(), image.get_height(),
		(Time.get_ticks_msec() - began) / 1000.0])


## Where a step's target is, in the window's pixels; null (and why, in
## _failed) when it is nowhere.
func _target(given: Variant) -> Variant:
	if given is Dictionary:
		var want: Dictionary = given
		if want.has("xy"):
			var share: Array = want["xy"]
			return Vector2(root.size) * Vector2(float(share[0]), float(share[1]))
		if want.has("tile"):
			return _tile(str(want["tile"]))
		if want.has("button"):
			# A button by its words, under a path from Main ("in"), in sight.
			var under: Variant = _node(str(want.get("in", "")))
			if under is Node:
				for button: Node in (under as Node).find_children("*", "BaseButton", true, false):
					if button is Button and (button as Button).text == str(want["button"]):
						var rect: Variant = _rect_of_node(button)
						if rect != null:
							return (rect as Rect2).get_center()
			_failed.append("no button %s in sight under %s" % [want["button"], want.get("in", "")])
			return null
		if want.has("swatch"):
			var bin: PartsBin = _main.get("_bin")
			var swatches: Dictionary = bin.get("_swatches")
			var swatch: Variant = swatches.get(int(want["swatch"]))
			# Scrolled into sight first, as a tile is: the palette shows two rows.
			var holder: Node = (swatch as Node).get_parent() if swatch is Node else null
			while holder != null and not holder is ScrollContainer:
				holder = holder.get_parent()
			if holder is ScrollContainer:
				(holder as ScrollContainer).ensure_control_visible(swatch as Control)
			var rect: Variant = _rect_of_node(swatch) if swatch is Node else null
			if rect == null:
				_failed.append("no swatch of colour %s in sight" % want["swatch"])
				return null
			return (rect as Rect2).get_center()
	return _point(given)


## The middle of a part's tile in the bin, scrolled into sight first.
func _tile(part: String) -> Variant:
	var bin: PartsBin = _main.get("_bin")
	var grid: Node = bin.get("_grid")
	for cell: Node in grid.get_children() if grid != null else []:
		if not cell.has_meta("part") or str(cell.get_meta("part")).get_basename() != part.get_basename():
			continue
		var scroll: Variant = bin.get("_scroll")
		if scroll is ScrollContainer and cell is Control:
			(scroll as ScrollContainer).ensure_control_visible(cell as Control)
		var rect: Variant = _rect_of_node(cell)
		if rect != null:
			return (rect as Rect2).get_center()
	_failed.append("no tile of %s in the bin" % part)
	return null


## The pointer carried to [param to] over [param count] frames, eased, the
## button held or not as it is.
func _glide(to: Vector2, count: int) -> void:
	var from: Vector2 = _pointer_at if _pointer_at.is_finite() else to + Vector2(-120, 90) * _scale
	for n: int in range(1, maxi(1, count) + 1):
		var at: Vector2 = from.lerp(to, _ease(float(n) / maxi(1, count)))
		_motion(at)
		await process_frame


func _motion(at: Vector2) -> void:
	var before: Vector2 = _pointer_at if _pointer_at.is_finite() else at
	_pointer_at = at
	_pointer_placed = true
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = at - before
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	Input.parse_input_event(motion)


func _button(down: bool) -> void:
	var at: Vector2 = _pointer_at
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_held = down
	if down:
		_tapped_at = at
		_tapped_frame = _recorded
	Input.parse_input_event(event)


## A click (or a tap) where the pointer is.
func _tap() -> void:
	_button(true)
	await _frames(2)
	_button(false)
	await _frames(2)
