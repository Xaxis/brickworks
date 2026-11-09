## The documentation's pictures of the app, taken off the real window as
## docs-site/shots.json sets each one up, for tools/docs_shots.py to make
## docs-site/img/ of. Every picture is taken in a Brickworks of its own:
## this run starts one window a picture (the same engine, the same
## display, the GPU lease it holds), with an app data folder of its own,
## so a picture is the same whatever is taken before it or beside it, and
## one taken alone (--only) is the one the whole run takes.
##
##   tools/probe.sh docs_shots_probe -- --out=DIR [--only=ID,ID] [--manifest=FILE]
##   godot --path . --resolution 1400x900 --script src/dev/docs_shots_probe.gd -- --out=DIR
##
## In each window: the app as a person meets it, through the sign-in screen
## (gate_for_probe) and let in as an account with a fixed address, offline
## (the deployment a port nobody answers, as gate_probe's first half), the
## example car on the baseplate and its build stopped; then the picture's
## steps, as a person's keys, clicks and the menus' commands; then the
## window read until two reads a few frames apart are the same pixels (a
## field's caret held still, the pointer off everything), cut to what the
## picture shows, marked where it says, and written as DIR/<id>.png, with
## DIR/<id>.json saying what was taken.
##
## A step names what it acts on by a path from the app (Main): `_bin`, a
## member; `_shell.bar`, a member's member; `#Search`, a node of that name
## under it; `@focus`, the control with the keyboard. Steps:
##   {"open": "res://models/car.ldr"}       a model, opened as File, Open does
##   {"run": "settings"}                    a menu command, by its name
##   {"key": "Ctrl+Shift+Z"}                a key, as a person presses it
##   {"type": "hinge"}                      words typed into whatever has the keys
##   {"mouse": [x, y]} / {"click": [x, y]}  the pointer, in the window's pixels;
##   {"click": "path"}                      or the middle of a control
##   {"right_click": ...}                   the same with the other button
##   {"over": {"part": "3001", "nth": 0, "lift": 1}}  the pointer over a part
##                                          (lift: plates above its top)
##   {"select": {"part": "3001", "colour": 4} | "all" | [n, ...]}
##   {"call": "path.method", "args": [...]} {"set": "path.property", "value": v}
##   {"assistant": true}                    the assistant shown (Settings)
##   {"frames": 30}
## And the picture: "crop" ("window", a path, [x, y, w, h], or a list of
## those, joined), "pad" (pixels round a crop), "marks" ([{"at": path,
## "n": 1}]: an outline and a numbered disc drawn over the window, in the
## app's own font), "width" (made smaller to at most this).
extends SceneTree

const MANIFEST := "res://docs-site/shots.json"
## How long one window may take, its start included, before it is ended.
const SECONDS_A_PICTURE := 180
## The pixels two reads must agree on, at most this many reads.
const SETTLE_READS := 12

var _out: String = ""
var _manifest: String = MANIFEST
var _main: Node
var _shell: Shell
var _failed: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var one: String = ""
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--only="):
			only = arg.substr(7).split(",", false)
		elif arg.begins_with("--one="):
			one = arg.substr(6)
		elif arg.begins_with("--manifest="):
			_manifest = arg.substr(11)
	if _out.is_empty():
		print("docs shots probe FAIL: no --out=DIR")
		quit(2)
		return
	if not _out.begins_with("/"):
		_out = ProjectSettings.globalize_path("res://").path_join(_out)
	DirAccess.make_dir_recursive_absolute(_out)
	if DisplayServer.get_name() == "headless":
		print("  no rendering device: these pictures need a window")
		quit(1)
		return
	var shots: Array = _shots()
	if shots.is_empty():
		print("docs shots probe FAIL: %s names no picture of the app" % _manifest)
		quit(1)
		return
	if one.is_empty():
		await _every(shots, only)
	else:
		var found: Array = shots.filter(func(s: Dictionary) -> bool: return s["id"] == one)
		if found.is_empty():
			print("docs shots probe FAIL: no picture %s in %s" % [one, _manifest])
			quit(1)
			return
		await _take(found[0])


## The manifest's pictures of the app.
func _shots() -> Array:
	var path: String = _manifest if _manifest.begins_with("/") or _manifest.begins_with("res://") \
		else ProjectSettings.globalize_path("res://").path_join(_manifest)
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return []
	var out: Array = []
	for shot: Variant in (parsed as Dictionary).get("shots", []):
		if shot is Dictionary and str(shot.get("source", "")) == "app":
			out.append(shot)
	return out


# -- the run: a window a picture -------------------------------------------------


func _every(shots: Array, only: PackedStringArray) -> void:
	var engine: PackedStringArray = PackedStringArray()
	var given: PackedStringArray = OS.get_cmdline_args()
	for i: int in given.size():
		if given[i] in ["--rendering-method", "--rendering-driver"] and i + 1 < given.size():
			engine.append_array([given[i], given[i + 1]])
	var size: Vector2i = DisplayServer.window_get_size()
	var taken: int = 0
	var bad: PackedStringArray = PackedStringArray()
	var started: int = Time.get_ticks_msec()
	for shot: Dictionary in shots:
		var id: String = shot["id"]
		if not only.is_empty() and not only.has(id):
			continue
		var at: Vector2i = _size_of(shot, size)
		var data: String = _out.path_join(".data").path_join(id)
		DirAccess.make_dir_recursive_absolute(data)
		OS.set_environment("XDG_DATA_HOME", data)
		DirAccess.remove_absolute(_out.path_join(id + ".json"))
		var args: PackedStringArray = PackedStringArray(["--path", ProjectSettings.globalize_path("res://")])
		args.append_array(engine)
		args.append_array(["--resolution", "%dx%d" % [at.x, at.y],
			"--script", "res://src/dev/docs_shots_probe.gd", "--",
			"--one=" + id, "--out=" + _out, "--manifest=" + _manifest])
		var began: int = Time.get_ticks_msec()
		var pid: int = OS.create_process(OS.get_executable_path(), args)
		if pid <= 0:
			bad.append(id)
			print("  FAIL  %s: its window would not start" % id)
			continue
		while OS.is_process_running(pid):
			if Time.get_ticks_msec() - began > (SECONDS_A_PICTURE + 30) * 1000:
				OS.kill(pid)
				break
			OS.delay_msec(250)
		var said: Variant = JSON.parse_string(FileAccess.get_file_as_string(_out.path_join(id + ".json")))
		if said is Dictionary and bool(said.get("ok", false)):
			taken += 1
			print("  ok    %s: %dx%d, %s, in %.1f s%s" % [id, int(said["width"]), int(said["height"]),
				str(said["sha256"]).left(12), (Time.get_ticks_msec() - began) / 1000.0,
				"" if bool(said.get("settled", false)) else " (never read the same twice: it moves)"])
		else:
			bad.append(id)
			print("  FAIL  %s: %s" % [id, str(said.get("why", "no picture")) if said is Dictionary
				else "its window ended without a picture"])
		_remove_tree(data)
	_remove_tree(_out.path_join(".data"))
	print("")
	print("docs shots probe: %d picture(s) taken in %.0f s%s" % [taken, (Time.get_ticks_msec() - started) / 1000.0,
		"" if bad.is_empty() else ", %d FAILED: %s" % [bad.size(), ", ".join(bad)]])
	quit(0 if bad.is_empty() and taken > 0 else 1)


func _size_of(shot: Dictionary, fallback: Vector2i) -> Vector2i:
	var words: String = str(shot.get("window", ""))
	var parts: PackedStringArray = words.split("x")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	return fallback


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for name: String in dir.get_directories():
		_remove_tree(path.path_join(name))
	for name: String in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(path)


# -- one window, one picture ------------------------------------------------------


func _take(shot: Dictionary) -> void:
	var id: String = shot["id"]
	create_timer(SECONDS_A_PICTURE).timeout.connect(func() -> void:
		_say(id, {"ok": false, "why": "not taken in %d s" % SECONDS_A_PICTURE})
		quit(1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Offline, as gate_probe's first half: nothing in a picture is the day's.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	var world: BrickWorld = null
	for _n: int in 900:
		await process_frame
		world = _main.get("_world")
		_shell = _main.get("_shell")
		if world != null and world.brick_count() > 1 and _shell != null and _main.get("_bin") != null:
			break
	if world == null or world.brick_count() <= 1:
		_say(id, {"ok": false, "why": "no model came up on the baseplate"})
		quit(1)
		return
	_stop_playback()
	await _let_in()
	await _frames(20)
	for step: Variant in shot.get("setup", []):
		if not step is Dictionary:
			_failed.append("a step that is not an object: %s" % str(step))
			continue
		await _do(step)
		await _frames(int(step.get("after", 6)))
	await _frames(int(shot.get("settle", 30)))
	if not _failed.is_empty():
		_say(id, {"ok": false, "why": "; ".join(_failed)})
		quit(1)
		return
	_hold_still()
	await _frames(4)
	var picture: Image = null
	var settled: bool = false
	var reads: int = 0
	var last: PackedByteArray = PackedByteArray()
	while reads < SETTLE_READS:
		reads += 1
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
		var now: PackedByteArray = picture.get_data()
		if now == last:
			settled = true
			break
		last = now
		await _frames(6)
	var marks: Array = shot.get("marks", [])
	if not marks.is_empty():
		_mark(marks)
		await _frames(3)
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
	var rect: Variant = _crop(shot.get("crop", "window"), int(shot.get("pad", 0)), picture.get_size())
	if rect == null:
		_say(id, {"ok": false, "why": "; ".join(_failed)})
		quit(1)
		return
	var cut: Image = picture.get_region(rect as Rect2i)
	cut.convert(Image.FORMAT_RGB8)
	var widest: int = int(shot.get("width", 0))
	if widest > 0 and cut.get_width() > widest:
		cut.resize(widest, roundi(cut.get_height() * float(widest) / cut.get_width()), Image.INTERPOLATE_LANCZOS)
	var file: String = _out.path_join(id + ".png")
	if cut.save_png(file) != OK:
		_say(id, {"ok": false, "why": "could not write %s" % file})
		quit(1)
		return
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(cut.get_data())
	_say(id, {"ok": true, "width": cut.get_width(), "height": cut.get_height(), "settled": settled,
		"reads": reads, "sha256": hash.finish().hex_encode(), "crop": [rect.position.x, rect.position.y,
		rect.size.x, rect.size.y]})
	_main.queue_free()
	await process_frame
	quit(0)


func _say(id: String, what: Dictionary) -> void:
	what["id"] = id
	var file := FileAccess.open(_out.path_join(id + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(what, "\t") + "\n")
		file.close()
	if not bool(what.get("ok", false)):
		print("docs shots probe FAIL: %s: %s" % [id, what.get("why", "")])


func _stop_playback() -> void:
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()


## Through the sign-in screen as somebody is let in (gate_probe): an account
## with a fixed address and a session that needs no renewing.
func _let_in() -> void:
	var account: Account = _main.get("_account")
	if account == null:
		return
	for _n: int in 300:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	account.email = "you@example.com"
	account._access = "docs.shots.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 36000.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(10)
	var gate: Variant = _main.get("_gate")
	if gate is CanvasItem and (gate as CanvasItem).visible:
		_failed.append("the sign-in screen stayed up once signed in")


# -- steps ---------------------------------------------------------------------------


func _do(step: Dictionary) -> void:
	if step.has("open"):
		var placed: int = int(_main.call("_open", str(step["open"])))
		if placed <= 0:
			_failed.append("%s opened no parts" % step["open"])
		for _n: int in 600:
			await process_frame
			if not _loading():
				break
		_stop_playback()
	elif step.has("run"):
		var name: String = step["run"]
		if _shell.command(name) == null:
			_failed.append("no command %s" % name)
		elif not _shell.run(name):
			_failed.append("%s cannot be run now: %s" % [name, _shell.why_not(name)])
		await _frames(10)
	elif step.has("key"):
		await _key(str(step["key"]))
	elif step.has("type"):
		for c: String in str(step["type"]):
			var down := InputEventKey.new()
			down.pressed = true
			down.unicode = c.unicode_at(0)
			down.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			Input.parse_input_event(down)
			await process_frame
			var up: InputEventKey = down.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
			await process_frame
	elif step.has("mouse"):
		var at: Variant = _point(step["mouse"])
		if at != null:
			_move(at)
	elif step.has("click") or step.has("right_click"):
		var right: bool = step.has("right_click")
		var at: Variant = _point(step["right_click"] if right else step["click"])
		if at != null:
			await _click(at, MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT, int(step.get("times", 1)))
	elif step.has("over"):
		var at: Variant = _over(step["over"])
		if at != null:
			_move(at)
	elif step.has("select"):
		_select(step["select"])
	elif step.has("call"):
		var path: String = step["call"]
		var target: Variant = _node(path.get_basename()) if path.contains(".") else _main
		var method: String = path.get_extension() if path.contains(".") else path
		if target == null or not (target as Object).has_method(method):
			_failed.append("nothing to call at %s" % path)
		else:
			var result: Variant = (target as Object).callv(method, step.get("args", []))
			if result is Signal:
				await result
	elif step.has("set"):
		var path: String = step["set"]
		var target: Variant = _node(path.get_basename())
		if target == null:
			_failed.append("nothing at %s" % path.get_basename())
		else:
			(target as Object).set(path.get_extension(), step["value"])
	elif step.has("assistant"):
		_shell.set_assistant(bool(step["assistant"]))
	elif step.has("frames"):
		await _frames(int(step["frames"]))
	else:
		_failed.append("a step this probe does not know: %s" % JSON.stringify(step))


## Whether the model is still coming in: parts still being drawn in.
func _loading() -> bool:
	var world: BrickWorld = _main.get("_world")
	return world != null and world.has_method("loading") and bool(world.call("loading"))


## [param words] as a key: "Ctrl+Shift+Z", "F1", "Escape", "[".
func _key(words: String) -> void:
	var event := InputEventKey.new()
	var parts: PackedStringArray = words.split("+", false) if words.length() > 1 else PackedStringArray([words])
	if words.ends_with("++"):
		parts.append("+")
	for part: String in parts.slice(0, parts.size() - 1):
		match part.to_lower():
			"ctrl": event.ctrl_pressed = true
			"shift": event.shift_pressed = true
			"alt": event.alt_pressed = true
			"meta", "cmd": event.meta_pressed = true
	var last: String = parts[parts.size() - 1]
	var code: Key = OS.find_keycode_from_string(last)
	if code == KEY_NONE and last.length() == 1:
		code = OS.find_keycode_from_string(last.to_upper())
	if code == KEY_NONE:
		_failed.append("no key %s" % words)
		return
	event.keycode = code
	event.physical_keycode = code
	if last.length() == 1 and not event.ctrl_pressed and not event.alt_pressed:
		event.unicode = (last.to_upper() if event.shift_pressed else last.to_lower()).unicode_at(0)
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var up: InputEventKey = event.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)


## A point in the window's pixels: [x, y], or the middle of what a path names.
func _point(given: Variant) -> Variant:
	if given is Array and (given as Array).size() == 2:
		return Vector2(float(given[0]), float(given[1]))
	if given is String:
		var rect: Variant = _rect_of(given)
		if rect != null:
			return (rect as Rect2).get_center()
	_failed.append("no point at %s" % str(given))
	return null


func _move(at: Vector2) -> void:
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)


func _click(at: Vector2, button: MouseButton, times: int) -> void:
	_move(at)
	await _frames(3)
	for n: int in times:
		var press := InputEventMouseButton.new()
		press.button_index = button
		press.position = at
		press.global_position = at
		press.pressed = true
		press.double_click = n == 1
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(press)
		await process_frame
		var release: InputEventMouseButton = press.duplicate()
		release.pressed = false
		release.button_mask = 0
		Input.parse_input_event(release)
		await _frames(2)
	await _frames(4)


## The window's pixel over a part of the model ({"part", "colour", "nth",
## "lift": plates over its top}).
func _over(given: Variant) -> Variant:
	var found: Array = _bricks(given)
	if found.is_empty():
		_failed.append("no part like %s to point at" % JSON.stringify(given))
		return null
	var brick: BrickWorld.Brick = found[0]
	var world: BrickWorld = _main.get("_world")
	var camera: CadCamera = _main.get("_camera")
	var box: AABB = (world.library.parts[brick.part_id] as PartLibrary.PartInfo).bounds \
		if world.library.parts.has(brick.part_id) else AABB()
	# LDraw's up is -Y: the top of a part is its bounds' least Y.
	var top: Vector3 = brick.transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var lift: float = float((given as Dictionary).get("lift", 0)) if given is Dictionary else 0.0
	top.y -= lift * 8.0
	return root.get_final_transform() * camera.screen_of(top)


## The model's parts a step names, in the model's own order.
func _bricks(given: Variant) -> Array:
	var world: BrickWorld = _main.get("_world")
	var all: Array = world.bricks()
	all.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	if given is String and given == "all":
		return all
	if given is Array:
		var picked: Array = []
		for n: Variant in given:
			if int(n) >= 0 and int(n) < all.size():
				picked.append(all[int(n)])
		return picked
	if given is Dictionary:
		var want: Dictionary = given
		var out: Array = all.filter(func(b: BrickWorld.Brick) -> bool:
			return (not want.has("part") or b.part_id.get_basename() == str(want["part"]).get_basename()) \
				and (not want.has("colour") or b.color_code == int(want["colour"])))
		if want.has("nth"):
			var n: int = int(want["nth"])
			return [out[n]] if n >= 0 and n < out.size() else []
		return out
	return []


func _select(given: Variant) -> void:
	var found: Array = _bricks(given)
	if found.is_empty():
		_failed.append("nothing to select like %s" % JSON.stringify(given))
		return
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.select_found(found.map(func(b: BrickWorld.Brick) -> int: return b.id))


## What a path names, from the app: `_bin`, `_shell.bar`, `#Name` (a node of
## that name under what came before), `@focus`.
func _node(path: String) -> Variant:
	var at: Variant = _main
	for part: String in path.split(".", false):
		if at == null:
			return null
		if part == "@focus":
			at = root.gui_get_focus_owner()
		elif part.begins_with("#"):
			at = (at as Node).find_child(part.substr(1), true, false) if at is Node else null
		elif part.is_valid_int() and at is Array:
			var n: int = part.to_int()
			at = (at as Array)[n] if n >= 0 and n < (at as Array).size() else null
		elif at is Object:
			at = (at as Object).get(part)
		else:
			return null
	return at


## Where a path's control or window is, in the window's pixels.
func _rect_of(path: String) -> Variant:
	var found: Variant = _node(path)
	if found is Control:
		var control: Control = found
		if not control.is_visible_in_tree():
			_failed.append("%s is not shown" % path)
			return null
		var box: Rect2 = control.get_global_rect()
		var to_window: Transform2D = control.get_viewport().get_final_transform() \
			* control.get_viewport().get_canvas_transform()
		return to_window * box
	if found is Window:
		var window: Window = found
		if not window.visible:
			_failed.append("%s is not shown" % path)
			return null
		var box := Rect2(Vector2(window.position), Vector2(window.size))
		return root.get_final_transform() * box
	_failed.append("nothing to frame at %s" % path)
	return null


## The part of the window a picture shows, padded and kept inside it.
func _crop(given: Variant, pad: int, size: Vector2i) -> Variant:
	var whole := Rect2i(Vector2i.ZERO, size)
	if given is String and given == "window":
		return whole
	var parts: Array = given if given is Array and not (given as Array).is_empty() \
		and not ((given as Array)[0] is float or (given as Array)[0] is int) else [given]
	var joined: Variant = null
	for one: Variant in parts:
		var rect: Variant = null
		if one is Array and (one as Array).size() == 4:
			rect = Rect2(float(one[0]), float(one[1]), float(one[2]), float(one[3]))
		elif one is String:
			rect = _rect_of(one)
		if rect == null:
			if _failed.is_empty():
				_failed.append("no crop at %s" % str(one))
			return null
		joined = rect if joined == null else (joined as Rect2).merge(rect)
	var box: Rect2 = (joined as Rect2).grow(pad)
	var cut := Rect2i(Vector2i(floori(box.position.x), floori(box.position.y)),
		Vector2i(ceili(box.size.x), ceili(box.size.y))).intersection(whole)
	if cut.size.x < 8 or cut.size.y < 8:
		_failed.append("the crop %s is outside the window" % str(given))
		return null
	return cut


## Nothing that moves by itself in the picture: the pointer off everything,
## a field's caret held on, nothing hovered.
func _hold_still() -> void:
	var focus: Control = root.gui_get_focus_owner()
	if focus is LineEdit:
		(focus as LineEdit).caret_blink = false
	elif focus is TextEdit:
		(focus as TextEdit).caret_blink = false


## Outlines and numbered discs over what [param marks] name, drawn in the
## window by the app's own drawing, so they are in the picture as it is.
func _mark(marks: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	var sheet := _Marks.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sheet)
	var to_canvas: Transform2D = root.get_final_transform().affine_inverse()
	for mark: Variant in marks:
		if not mark is Dictionary:
			continue
		var rect: Variant = _rect_of(str(mark.get("at", ""))) if mark.has("at") \
			else Rect2(float(mark["rect"][0]), float(mark["rect"][1]), float(mark["rect"][2]), float(mark["rect"][3]))
		if rect != null:
			sheet.marks.append([to_canvas * (rect as Rect2), str(mark.get("n", "")), str(mark.get("side", "left"))])
	sheet.queue_redraw()


class _Marks extends Control:
	var marks: Array = []
	const INK := Color(1.0, 0.78, 0.18)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		for mark: Array in marks:
			var box: Rect2 = (mark[0] as Rect2).grow(2)
			draw_rect(box, Color(0, 0, 0, 0.55), false, 5.0)
			draw_rect(box, INK, false, 2.5)
			var words: String = mark[1]
			if words.is_empty():
				continue
			var r: float = 13.0
			var at := Vector2(box.position.x + r + 4, box.position.y + r + 4)
			if mark[2] == "right":
				at.x = box.end.x - r - 4
			draw_circle(at, r + 2, Color(0, 0, 0, 0.6))
			draw_circle(at, r, INK)
			var line: Vector2 = font.get_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			draw_string(font, at + Vector2(-line.x * 0.5, 6), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Color(0.08, 0.08, 0.1))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
