## A build video framed on what is built, and a GIF (docs/APP_UX6.md, unit
## 11, video2; gap 12: "the build video frames only the finished model, and
## there is no GIF").
##
##   godot --path . --resolution 1280x720 --script src/dev/video2_probe.gd
##   ... -- [OUT_DIR]   (the pictures to look at; the run's own data when not given)
##
## Through the way in first, as a person comes: the sign-in screen over the
## app (gate_for_probe), a throwaway account signed in with a password grant
## (SignInHelper, as mosaic_window_probe), deleted at the end. Needs .env.
##
## 1. By hand, on Pods (the MCP walk's model, src/dev/fixtures/mcp_walk_pods.ldr,
##    whose first step a session called "small, up in the top left corner"):
##    Render, Quick, 720p, no background (so a frame's alpha is its parts),
##    Building's 10 s, Return. In the frame where the first step's parts are
##    all down, just before the second's begin, they fill 40% or more of the
##    frame's height, read off the picture; the last frame is the whole
##    model, as a picture with the same choices draws it.
## 2. Over MCP, the same model as the walk drew it: render_model build with
##    view hero (turning), no backdrop and format gif. The first step 40% or
##    more of the height again; the last frame the same as render_model's
##    picture from that view; the GIF 8 MB or less and played by a browser.
## 3. The car's turntable as a GIF by hand: Render, a white backdrop, 36
##    frames, Kept as GIF, Return. A GIF89a with a global table of 256
##    colours that loops for ever, 36 frames, 8 MB or less; Chromium
##    (tools/web/gif_plays.mjs) decodes 36 frames of 640 x 360 that change
##    from one to the next, showing 1.5 s, and an <img> of it; its first
##    frame as the browser draws it within a few grey levels of the frame it
##    was made of. Over MCP, render_model turntable format gif the same; a
##    format it does not know is refused, saying which it knows.
## 4. Kept as is in sight and pressable in the window (1280 x 720 here;
##    PROBE_SIZE=1400x900 the other), WebP until GIF is chosen.
extends SceneTree

const PODS := "res://src/dev/fixtures/mcp_walk_pods.ldr"
const CAR := "res://models/car.ldr"
const SECONDS := 10
## The bar: the first step's parts fill this much of the frame's height.
const FILL := 0.40
const BUDGET := 8_000_000

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _dialog: RenderDialog
var _out: String = ""
var _next: int = 0
var _last_screen := Vector2.ZERO
var _email: String = ""
var _password: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("video2")
	DirAccess.make_dir_recursive_absolute(_out)
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	if not StudioRender.possible():
		print("video2 probe: needs a window (tools/probe.sh runs it in one)")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	var window: Vector2 = root.get_visible_rect().size
	print("in a %d x %d window" % [window.x, window.y])
	if await _way_in():
		_dialog = _main.get("_render")
		_socket = CommandSocket.new()
		_socket.assistant = _main.get("_assistant")
		_socket.app = _main
		_main.add_child(_socket)
		(_main.get("_store") as ModelStore).keeps = false
		if await _open(PODS):
			await _by_hand_build()
			await _over_mcp_build()
		if await _open(CAR):
			await _gif_by_hand()
			await _gif_over_mcp()
	await _finish()


# -- 1. by hand: Building, framed on what is built ----------------------------------


func _by_hand_build() -> void:
	print("\n── 1. by hand: Render, Quick, 720p, no background, Building %d s, Return ──" % SECONDS)
	_shell().run("render")
	await _frames(20)
	var kept_webp: Button = _named("render_kept_webp")
	_check("Kept as is WebP until GIF is chosen", kept_webp != null and kept_webp.button_pressed)
	await _click(_named("render_quick"))
	await _click(_named("render_size_720p"))
	await _click(_named("render_bg_none"))
	_dialog.settings.contact_shadow = false
	var choices: ScrollContainer = _named("render_choices")
	choices.ensure_control_visible(_named("render_length_%d" % SECONDS))
	await _frames(6)
	await _click(_named("render_length_%d" % SECONDS))
	await _key(KEY_ENTER)
	for _n: int in 200:
		await process_frame
		if _dialog.is_rendering():
			break
	await _rendered(900)
	var last: Dictionary = _dialog._last
	var built: BuildRender = last.get("build") as BuildRender
	var webp: String = _path_of(last.get("output"), ".webp")
	if not _check("a building of %d s drawn: %s" % [SECONDS, webp.get_file()],
			built != null and not webp.is_empty()):
		return
	await _shot("dialog_built")
	var dir: String = webp.get_basename()
	_first_step(built, dir, "by hand")
	var chosen: RenderSettings = _dialog.settings.copy()
	chosen.contact_shadow = false
	var said: String = await _dialog.render_for("picture", chosen)
	var picture: Image = _dialog.last_picture()
	_last_is_whole(built, dir, picture, "by hand, the picture: %s" % said.get_file())
	_dialog.close()
	await _frames(10)


## The first step's parts in the frame where they are all down: how much of
## the frame's height they fill, read off its alpha.
func _first_step(built: BuildRender, dir: String, how: String) -> void:
	var ends: PackedInt64Array = built._step_ends
	var first: int = int(ends[0]) if not ends.is_empty() else 0
	var at: int = 0
	while at + 1 < built.shown.size() and built.shown[at + 1] <= first:
		at += 1
	var frame: Image = Image.load_from_file(dir.path_join("frame_%04d.png" % (at + 1)))
	if not _check("%s: frame %d of %d, the first step's %d part%s all down" % [how, at + 1,
			built.frames, first, "" if first == 1 else "s"], frame != null and built.shown[at] == first):
		return
	var box: Rect2i = _alpha_box(frame)
	var tall: float = float(box.size.y) / float(frame.get_height())
	var wide: float = float(box.size.x) / float(frame.get_width())
	frame.save_png(_out.path_join("%s_first_step.png" % how.replace(" ", "_")))
	_check("%s: the first step's parts fill %.0f%% of the frame's height (%d of %d px), %.0f%% of its "
		% [how, tall * 100.0, box.size.y, frame.get_height(), wide * 100.0]
		+ "width, at %s: 40%% or more" % str(box.position), tall >= FILL)
	# And the camera eased back from there, never a jump: how much of the
	# height what is built fills, every 24th frame, for the pictures.
	var fills := PackedStringArray()
	for n: int in range(0, built.frames, 24):
		var each: Image = Image.load_from_file(dir.path_join("frame_%04d.png" % (n + 1)))
		if each != null:
			fills.append("%d%%" % roundi(100.0 * float(_alpha_box(each).size.y) / float(each.get_height())))
	print("    height filled, every 24th frame: %s" % ", ".join(fills))


## The last frame against a picture of the whole model drawn with the same
## choices.
func _last_is_whole(built: BuildRender, dir: String, picture: Image, how: String) -> void:
	var last: Image = Image.load_from_file(dir.path_join("frame_%04d.png" % built.frames))
	if not _check("%s" % how, picture != null and last != null):
		return
	last.save_png(_out.path_join("%s_last_frame.png" % how.get_slice(",", 0).replace(" ", "_")))
	picture.convert(last.get_format())
	var off: Vector2 = _difference(last, picture)
	var box: Rect2i = _alpha_box(last)
	_check("...the last frame is the whole model: %.2f levels from the picture on average, %.2f%% of "
		% [off.x, off.y * 100.0] + "pixels more than 16 off; the model %s, the picture's %s"
		% [str(box), str(_alpha_box(picture))], off.x < 1.5 and off.y < 0.005)


# -- 2. over MCP: the walk's call, as a GIF ------------------------------------------


func _over_mcp_build() -> void:
	print("\n── 2. over MCP: render_model build, view hero, no backdrop, format gif ──")
	_dialog.settings.contact_shadow = false
	var answer: String = _text(await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "build", "seconds": SECONDS, "backdrop": "none", "format": "gif"}})))
	_print(answer)
	var built: BuildRender = _dialog._last.get("build") as BuildRender
	var gif: String = _found(answer, "wrote (\\S+\\.gif)")
	if not _check("in 1 call and its job: a GIF of the build (%s)" % gif.get_file(),
			built != null and not gif.is_empty()):
		return
	var dir: String = gif.get_basename()
	var made: Dictionary = _made()
	_first_step(built, dir, "over MCP")
	var picture_said: String = _text(await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "picture", "quality": "quick", "size": "720p", "view": "hero",
			"backdrop": "none"}})))
	var png: String = _found(picture_said, "wrote (\\S+\\.png)")
	_last_is_whole(built, dir, Image.load_from_file(png) if not png.is_empty() else null,
		"over MCP, render_model's picture from the same view: %s" % png.get_file())
	await _gif_file(gif, -1, "the build's GIF, transparent", made)


# -- 3. a turntable as a GIF -------------------------------------------------------------


func _gif_by_hand() -> void:
	print("\n── 3. by hand: the car's turntable, white, 36 frames, Kept as GIF, Return ──")
	_shell().run("render")
	await _frames(20)
	await _click(_named("render_bg_white"))
	var choices: ScrollContainer = _named("render_choices")
	choices.ensure_control_visible(_named("render_frames_36"))
	await _frames(6)
	await _click(_named("render_frames_36"))
	var gif_button: Button = _named("render_kept_gif")
	if gif_button != null:
		choices.ensure_control_visible(gif_button)
		await _frames(6)
	await _in_sight(["render_kept_webp", "render_kept_gif"], "Kept as")
	await _click(gif_button)
	_check("Kept as GIF chosen, and the turntable's words say so: %s" % _note_of("_frames_note"),
		gif_button != null and gif_button.button_pressed and _note_of("_frames_note").contains("as a GIF"))
	await _shot("dialog_kept_as_gif")
	await _key(KEY_ENTER)
	for _n: int in 200:
		await process_frame
		if _dialog.is_rendering():
			break
	await _rendered(900)
	var output: RenderOutput = _dialog._last.get("output")
	var gif: String = _path_of(output, ".gif")
	_check("a turntable drawn and kept as a GIF: %s; the status: %s" % [gif.get_file(),
		_dialog._status.text.left(160)], not gif.is_empty() and _path_of(output, ".webp").is_empty())
	await _shot("dialog_gif_made")
	if gif.is_empty():
		return
	await _gif_file(gif, 36, "the turntable's GIF", _made(),
		gif.get_basename().path_join("frame_0001.png"))
	# Back to WebP for what comes after, as it was.
	await _click(_named("render_kept_webp"))
	_dialog.close()
	await _frames(10)


func _gif_over_mcp() -> void:
	print("\n── 3b. over MCP: render_model turntable, format gif ──")
	var answer: String = _text(await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "turntable", "format": "gif"}})))
	_print(answer)
	var gif: String = _found(answer, "wrote (\\S+\\.gif)")
	if _check("in 1 call and its job, a GIF: %s" % gif.get_file(), not gif.is_empty()):
		await _gif_file(gif, 36, "render_model's turntable GIF", _made())
	var refused: String = _text(await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "turntable", "format": "png"}})))
	_check("a format it does not keep is refused, saying which it does: %s" % refused.left(120),
		refused.contains("webp") and refused.contains("gif") and not refused.contains("wrote"))


## What the last render's GIF came to (RenderOutput.gif_made), read by name
## so the probe runs, and fails, on a build with none.
func _made() -> Dictionary:
	var output: Variant = _dialog._last.get("output")
	var made: Variant = (output as Object).get("gif_made") if output is Object else null
	return made if made is Dictionary else {}


## A GIF as the bar asks: GIF89a, a global table of 256 colours, looping for
## ever, [param frames] frames (any when -1), 8 MB or less; and a browser
## plays it. With [param made_of], its first frame as the browser draws it
## held against the frame it was made of.
func _gif_file(path: String, frames: int, what: String, made: Dictionary,
		made_of: String = "") -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var header: String = bytes.slice(0, 6).get_string_from_ascii() if bytes.size() > 13 else ""
	var packed: int = bytes[10] if bytes.size() > 13 else 0
	var colours: int = 1 << ((packed & 7) + 1) if packed & 0x80 else 0
	var palette := {}
	for n: int in colours:
		palette[bytes.slice(13 + n * 3, 16 + n * 3).hex_encode()] = true
	# NETSCAPE2.0's block right after the table, its count 0: for ever.
	var after: int = 13 + colours * 3
	var loops: bool = bytes.size() > after + 19 \
		and bytes.slice(after + 3, after + 14).get_string_from_ascii() == "NETSCAPE2.0" \
		and bytes.decode_u16(after + 16) == 0
	var count: int = _gif_frames(bytes, 13 + colours * 3)
	_check("%s: %s, %d x %d, a global table of %d colours (%d different), %s, %d frames%s, %.2f MB of 8"
		% [what, header, bytes.decode_u16(6) if bytes.size() > 9 else 0,
			bytes.decode_u16(8) if bytes.size() > 9 else 0, colours, palette.size(),
			"looping for ever" if loops else "NOT looping", count,
			"" if frames < 0 else " (%d drawn)" % frames, float(bytes.size()) / 1e6]
		+ "; made %s" % str(made),
		header == "GIF89a" and colours == 256 and loops and count > 0 and (frames < 0 or count == frames)
		and bytes.size() <= BUDGET)
	var browser: Dictionary = _plays(path, _out.path_join(path.get_file().get_basename() + "_frame0.png"))
	var shown: float = float(browser.get("seconds", 0.0))
	_check("...a browser plays it (Chromium's decoder): %s" % JSON.stringify(browser),
		bool(browser.get("ok", false)) and int(browser.get("frames", 0)) == count
		and int(browser.get("changed", 0)) >= count - 2 and str(browser.get("loops", "")) == "for ever"
		and (frames < 0 or absf(shown - float(frames) / 24.0) < 0.05))
	if made_of.is_empty():
		return
	var drawn: Image = Image.load_from_file(_out.path_join(path.get_file().get_basename() + "_frame0.png"))
	var source: Image = Image.load_from_file(made_of)
	if not _check("...its first frame as the browser drew it, and the frame it was made of",
			drawn != null and source != null):
		return
	source.convert(Image.FORMAT_RGBA8)
	source.resize(drawn.get_width(), drawn.get_height(), Image.INTERPOLATE_LANCZOS)
	drawn.convert(Image.FORMAT_RGBA8)
	var off: Vector2 = _difference(drawn, source)
	_check("...within a few levels of it: %.2f on average, %.2f%% of pixels more than 16 off"
		% [off.x, off.y * 100.0], off.x < 4.0 and off.y < 0.02)


## How many images a GIF holds, read block by block from [param at] (after
## its global table).
static func _gif_frames(bytes: PackedByteArray, at: int) -> int:
	var count: int = 0
	while at < bytes.size():
		var kind: int = bytes[at]
		if kind == 0x3B:
			return count
		if kind == 0x21:
			at += 2
		elif kind == 0x2C:
			count += 1
			var packed: int = bytes[at + 9]
			at += 10
			if packed & 0x80:
				at += 3 * (1 << ((packed & 7) + 1))
			at += 1
		else:
			return -1
		while at < bytes.size() and bytes[at] != 0:
			at += bytes[at] + 1
		at += 1
	return -1


## What Chromium makes of the GIF (tools/web/gif_plays.mjs).
func _plays(path: String, frame0: String) -> Dictionary:
	var said: Array = []
	var code: int = OS.execute("node", [ProjectSettings.globalize_path("res://tools/web/gif_plays.mjs"),
		path, "--frame0=" + frame0], said, true)
	var text: String = str(said[0]).strip_edges() if not said.is_empty() else ""
	var last_line: String = text.get_slice("\n", text.count("\n"))
	var parsed: Variant = JSON.parse_string(last_line)
	if parsed is Dictionary:
		return parsed
	return {"ok": false, "exit": code, "said": text.right(300)}


# -- the window --------------------------------------------------------------------


## Each named control inside the dialog's scroll, the dialog and the window, drawn.
func _in_sight(names: Array, what: String) -> void:
	await _frames(6)
	var window: Rect2 = root.get_visible_rect()
	var choices: ScrollContainer = _named("render_choices")
	var seen: Rect2 = choices.get_global_rect() if choices != null else Rect2()
	var out: Array[String] = []
	for name: String in names:
		var control: Control = _named(name)
		if control == null or not control.is_visible_in_tree() \
				or not window.encloses(control.get_global_rect()) \
				or not seen.grow(1.0).encloses(control.get_global_rect()):
			out.append(name)
	_check("%s in sight in the %d x %d window%s" % [what, window.size.x, window.size.y,
		"" if out.is_empty() else ", not: " + ", ".join(out)], out.is_empty())


func _note_of(field: String) -> String:
	var label: Label = _dialog.get(field) as Label
	return label.text if label != null else ""


# -- the way in --------------------------------------------------------------------------


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("video2")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify, which is 1 per 10 s for every agent.
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	print("video2: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the app ----------------------------------------------------------------------------


func _open(model: String) -> bool:
	var placed: int = await (_main.get("_bar") as ModelBar).open_with_progress(model)
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_builder") as Builder).forget_history()
	return _check("%s opened, %d parts" % [model.get_file(), placed], placed > 0)


func _shell() -> Shell:
	return _main.get("_shell")


func _named(key: String) -> Control:
	return _dialog.controls_by_name().get(key)


func _rendered(seconds: int) -> void:
	var until: int = Time.get_ticks_msec() + seconds * 1000
	while _dialog.is_rendering() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(5)


static func _path_of(output: Variant, extension: String) -> String:
	if not output is RenderOutput:
		return ""
	for path: String in (output as RenderOutput).paths:
		if path.ends_with(extension):
			return path
	return ""


static func _found(text: String, pattern: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(pattern).search(text)
	return found.get_string(1) if found != null else ""


## Where a picture has colour (alpha over a half), as a rectangle.
static func _alpha_box(image: Image) -> Rect2i:
	if image == null:
		return Rect2i()
	var low := Vector2i(image.get_width(), image.get_height())
	var high := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	if high.x < 0:
		return Rect2i()
	return Rect2i(low, high - low + Vector2i.ONE)


## The mean difference of two pictures in grey levels, alpha counted, and
## the share of pixels more than 16 levels off in any channel.
static func _difference(a: Image, b: Image) -> Vector2:
	if a == null or b == null or a.get_size() != b.get_size():
		return Vector2(255.0, 1.0)
	var total: float = 0.0
	var off: int = 0
	var count: int = 0
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			var most: float = maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)),
				maxf(absf(p.b - q.b), absf(p.a - q.a))) * 255.0
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a)) * 255.0 / 4.0
			if most > 16.0:
				off += 1
			count += 1
	return Vector2(total / float(count), float(off) / float(count))


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _out.path_join("%s_%dx%d.png" % [name, size.x, size.y])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _click(control: Control) -> void:
	await _frames(2)
	if control == null or not control.is_visible_in_tree():
		_check("the control to press shows (%s)" % (control.name if control != null else "none"), false)
		return
	var at: Vector2 = control.get_global_rect().get_center()
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


func _move(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = _as_event(at) - _as_event(_last_screen)
	Input.parse_input_event(move)
	_last_screen = at
	await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)


func _as_event(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


## [param result], or when it is a job, the job's answer once it ends.
func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	for _n: int in 900:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments":
			{"id": int(found.get_string(1))}})
		if not _text(polled).contains(" is still going"):
			return polled
	return {"content": [{"type": "text", "text": "the job never ended"}]}


func _print(said: String) -> void:
	print("    " + said.left(600).replace("\n", "\n    "))


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
