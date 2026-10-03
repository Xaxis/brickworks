## The workbench: the scene you build in.
##
## For now this is the proof that the pipeline holds end to end — LDraw
## source converted offline, loaded as quantised geometry, batched by shape
## and drawn with per-instance colour — with a real published model opened
## as the test. Everything it does by hand here becomes a tool later.
extends Node3D

## Shipped with the build. It used to be read out of vendor/, which the
## export excludes, so the web build silently fell back to the demo wall.
const SAMPLE_MODEL := "res://models/car.ldr"

@onready var _camera: CadCamera = $CadCamera
@onready var _world: BrickWorld = $BrickWorld
@onready var _builder: Builder = $Builder
@onready var _status: Label = $HUD/Status
@onready var _title: Label = $HUD/Title

var _catalogue_ms: int = 0
var _stability: Stability
var _stability_text: String = ""
var _counts_base: String = ""
var _stability_at: int = 0
var _counts: Label
var _bin_dock: SideDock
var _chat_dock: SideDock
var _store: ModelStore
var _bar: ModelBar
var _bin: PartsBin
var _chat: ChatPanel
var _account: Account
var _steps: StepsBar
var _inventory: InventoryPanel
var _mosaic: MosaicDialog
var _controls: ControlsDialog
## Whether --ask finished with a design rather than an apology. Read by
## the exit status, so a script can tell.
var _ask_went_well: bool = true
## Whether a left press this handler saw started the box being drawn.
## The watchdog below will not finish one it never saw begin.
var _box_began: bool = false
## Which of the two things that want a picture opened the file dialog.
var _picking_reference: bool = false
var _hint: ControlsHint
var _picker: PickImage
var _mosaic_source: Image
var _playback: BuildPlayback
var _outline: SelectionOutline
var _gizmo: AxisGizmo
var _turning: PivotMark
var _tools: TouchTools
var _marquee: Marquee
var _thumbnails: PartThumbnails
var _assistant: Assistant
## Open only when --mcp asked for it. See src/net/command_socket.gd.
var _commands: CommandSocket = null
## Designing on the person's own Claude subscription, by starting the
## Claude Code they already have and pointing it back at this app.
var _claude_code: ClaudeCode = null

var _library: PartLibrary


## Screen-space antialiasing, where there is any.
##
## It was a project setting, which the web build could not honour:
## FXAA exists only on Forward+ and Mobile, and the browser runs
## Compatibility. Godot does not fall back quietly — it warns on every
## load, which is a line in everyone's console about a setting they
## cannot change.
## Make a pixel of interface the size a person expects.
##
## A phone reports a 390 point wide screen and draws it with three
## device pixels to the point. Godot is handed the device pixels, so
## without this the interface is laid out as if on a 1170 pixel display
## and then shown at a third of the size: legible on a desktop monitor,
## about two millimetres tall in the hand.
##
## Scaling by the ratio the browser reports puts it back. The 3D is
## unaffected — it still renders at full device resolution, which is
## what makes it look sharp.
func _match_screen_density() -> void:
	if not OS.has_feature("web"):
		return
	var reported: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var ratio: float = float(reported) if reported != null else 1.0
	if ratio <= 0.0:
		return
	# Capped: a 4x display would otherwise leave room for almost nothing,
	# and past about two the gain in legibility is small.
	get_window().content_scale_factor = clampf(ratio, 1.0, 2.0)


func _enable_antialiasing() -> void:
	var method: String = RenderingServer.get_current_rendering_method()
	if method == "forward_plus" or method == "mobile":
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


func _ready() -> void:
	# Before anything draws: the controls strip reads these to say what
	# the middle button does, and a strip built from the defaults and
	# never rebuilt would be wrong for everyone who has changed them.
	ViewPrefs.load_them()
	_enable_antialiasing()
	_match_screen_density()
	_library = PartLibrary.new()
	var started: int = Time.get_ticks_msec()
	if not _library.load_catalogue():
		_title.text = "No catalogue"
		_status.text = "Run tools/build_meshes.py to generate assets/generated/."
		return
	_catalogue_ms = Time.get_ticks_msec() - started

	_world.library = _library
	_world.rebuilt.connect(_on_rebuilt)
	_builder.world = _world
	_builder.library = _library
	_build_ui()

	var stress: String = _argument("--stress")
	var wanted: String = _argument("--model")
	var placed: int = 0
	if not stress.is_empty():
		placed = _build_stress(stress.to_int())
	elif not wanted.is_empty():
		placed = _open(wanted)
		if placed == 0:
			push_error("could not open %s" % wanted)
	else:
		# Whatever was on screen last time comes back first; the sample
		# model is only for a first visit.
		placed = _store.restore()
		if placed == 0:
			placed = _open(SAMPLE_MODEL)
		if placed == 0:
			placed = _build_demo()
	_lay_baseplate()


	# Wait a frame so the deferred batch rebuild has run and the bounds are
	# real before framing them.
	await get_tree().process_frame
	_camera.frame(_built_bounds())

	_unthrottle_if_nobody_is_watching()

	var mcp: String = _argument("--mcp")
	# Present with no value is the common case: --mcp, not --mcp=8787.
	if not mcp.is_empty() or _has_argument("--mcp"):
		_open_commands(CommandSocket.PORT if mcp.is_empty() else mcp.to_int())

	var autobuild: String = _argument("--autobuild")
	if not autobuild.is_empty():
		_autobuild(autobuild.to_int())

	# The same brief, designed by the Claude Code on this machine rather
	# than by the loop inside the app. No API key and no account: it is
	# the person's own subscription doing the thinking.
	var local: String = _argument("--ask-claude-code")
	if not local.is_empty():
		await _ask_claude_code(local)

	var ask: String = _argument("--ask")
	if not ask.is_empty():
		# For this run, not for the person's settings.
		Brain.use_model(_argument("--model"))
		Brain.use_effort(_argument("--effort"))
		await _ask(ask)

	if not _argument("--showcase").is_empty():
		_showcase()

	var bench: String = _argument("--bench")
	if not bench.is_empty():
		await _benchmark(bench.to_int())

	# Whatever ended up on the baseplate, written out and done.
	#
	# --ask runs the assistant the application itself uses: the one that
	# can turn a part on its side, look at what it built and revise it.
	# Until now it could only print, so anything wanting a file went
	# through the second designer in brain/, which has no notion of a
	# face at all — its rot is quarter turns about the vertical axis and
	# nothing else. A sail, a tiled wall, lettering, a grille: all of it
	# is out of reach there, and a brief asking for one comes back as a
	# stack of bricks with no way to tell why.
	var out: String = _argument("--out")
	if not out.is_empty():
		var written: int = _world.brick_count() - _store.scenery.size()
		if not _store.export_to(out, "Model"):
			get_tree().quit(1)
			return
		print("wrote %s (%d parts)" % [out, written])
		# The file is written either way — a design that failed at the
		# last revision still leaves the last version that held
		# together, and throwing it away would be the worse answer. The
		# status is how a script finds out.
		get_tree().quit(0 if _ask_went_well else 1)
		return

	var shot: String = _argument("--shot")
	if not shot.is_empty():
		await _capture(shot)


## A few parts, close up, for judging how they look rather than whether
## they are in the right place.
func _showcase() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	var wanted: String = _argument("--showcase")
	var row: Array = [
		["3001", 4], ["3003", 14], ["3024", 15], ["3062b", 1],
		["3040b", 2], ["3941", 25], ["4073", 47], ["3005", 0],
	]
	if wanted != "1" and not wanted.is_empty():
		row = [[wanted, 4]]
	var x: float = 0.0
	for entry: Array in row:
		var at := Transform3D(Basis.IDENTITY, Vector3(x, 24.0, 0.0))
		var id: int = _world.add_brick(entry[0], entry[1], at)
		if id != 0:
			_builder.register(id, entry[0], at)
		x += 60.0
	await get_tree().process_frame
	_camera.frame(_built_bounds(), 1.05)
	_camera.set_view("default")


## Run one design through the assistant and report, for checking the
## whole loop without a person having to type into the panel.
func _ask(brief: String) -> void:
	# Start from a bare baseplate, so what appears is what was asked for
	# and not a sample model with something new beside it.
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_lay_baseplate()

	var started: int = Time.get_ticks_msec()
	_assistant.progress.connect(func(note: String) -> void:
		print("  [%5.1fs] %s" % [(Time.get_ticks_msec() - started) / 1000.0, note]))
	_assistant.said.connect(func(text: String) -> void:
		print("  said: %s" % text.substr(0, 300)))

	_assistant.design(brief)
	var outcome: Array = await _assistant.finished
	_ask_went_well = bool(outcome[0])
	print("ask ok=%s bricks=%d  %s  (%.0fs)" % [
		outcome[0], _assistant._placed_ids.size(), outcome[1],
		(Time.get_ticks_msec() - started) / 1000.0])
	_camera.frame(_built_bounds())
	await get_tree().process_frame


## Drive a local Claude Code session and print what it does.
func _ask_claude_code(brief: String) -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_lay_baseplate()
	if not design_with_claude_code(brief):
		print("claude code: could not start")
		_ask_went_well = false
		return
	var started: int = Time.get_ticks_msec()
	var session: ClaudeCode = claude_code()
	session.progress.connect(func(note: String) -> void:
		print("  [%5.1fs] %s" % [
			(Time.get_ticks_msec() - started) / 1000.0, note]))
	session.said.connect(func(text: String) -> void:
		print("  said: %s" % text.substr(0, 300)))
	var outcome: Array = await session.finished
	_ask_went_well = bool(outcome[0])
	print("claude code ok=%s bricks=%d  (%.0fs)\n  %s" % [
		outcome[0], _world.brick_count() - _store.scenery.size(),
		(Time.get_ticks_msec() - started) / 1000.0,
		str(outcome[1]).substr(0, 600)])
	_camera.frame(_built_bounds())
	await get_tree().process_frame


## Run at full speed when the window is a formality.
##
## A window nothing is looking at gets one frame a second on this
## machine — measured, 989 ms a frame — because that is how long the
## compositor takes to accept one. For somebody using the app that is
## correct and invisible: their window is in front of them at sixty.
## For a run driven from the command line it is a disaster, because
## everything the app does between calls is measured in frames. The
## command socket polls in _process, so a tool call waits up to a second
## each way; a picture is six frames, so it took six seconds at every
## model size; and a design makes hundreds of calls. A real Voyager run
## spent its last ten minutes reporting "the renderer keeps timing out".
##
## So: if the app was started to be driven rather than used, vsync comes
## off for the whole run. Nothing else changes, and an interactive
## window is left exactly as it was — a CAD program spinning at four
## hundred frames a second is a laptop fan and nothing else.
func _unthrottle_if_nobody_is_watching() -> void:
	var driven: bool = false
	for flag: String in ["--mcp", "--ask", "--ask-claude-code", "--bench",
			"--shot", "--autobuild", "--showcase", "--out"]:
		if _has_argument(flag) or not _argument(flag).is_empty():
			driven = true
			break
	if not driven:
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("driven from the command line, so vsync is off for this run")


## Measure a settled frame rate and print it, then quit.
func _benchmark(frames: int) -> void:
	# Without this the number is the monitor's refresh rate, not the
	# renderer's: a 120 Hz panel reports 120 fps however little work it is.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	# Discard the first second: shader compilation, the shadow atlas and
	# the camera easing all land in it and none of them recur.
	for _warm: int in 60:
		await get_tree().process_frame

	var started: int = Time.get_ticks_usec()
	for _n: int in frames:
		await get_tree().process_frame
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1_000_000.0

	# The engine's own counters, so the claim can be checked rather than
	# inferred from a frame time that might be capped by something else.
	var draw_calls: int = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var video_mb: float = Performance.get_monitor(
		Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

	print("bench bricks=%d batches=%d  %.2f ms/frame  %.0f fps  draws=%d  prims=%d  vram=%.0fMB" % [
		_world.brick_count(), _world.get_child_count(),
		elapsed / float(frames) * 1000.0, float(frames) / elapsed,
		draw_calls, primitives, video_mb])
	get_tree().quit()


## Save a frame and quit. Used by tools/shot.sh so a change to how parts
## look can be checked without a person having to look at it.
func _capture(path: String) -> void:
	# Several frames, not one: the camera eases towards its framing and the
	# shadow atlas fills over a few frames, so the first frame is neither
	# framed nor lit the way a real one is.
	#
	# The frames are forced, not awaited. A process frame is not a drawn
	# frame: when the window is in the background — which it is whenever
	# this runs unattended — the OS stops asking for redraws entirely, so
	# awaiting frame_post_draw waits forever and the captured texture is
	# whatever was last drawn.
	#
	# That cost most of an afternoon. Bricks added after a long wait were
	# absent from every screenshot while the scene tree, the batches, the
	# instance transforms and the instance colours all insisted they were
	# there. They were. The picture was old.
	# Anything that has to come off the network before the picture is
	# worth taking — whether this build has accounts, for one — needs
	# longer than a dozen frames. --settle buys that time in frames
	# rather than in a sleep, so the scene keeps drawing while it waits.
	var settle: float = maxf(_argument("--settle").to_float(), 0.0)
	for _n: int in 12 + int(settle * 60.0):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(path)
	if error != OK:
		push_error("shot: could not write %s (%d)" % [path, error])
	else:
		print("shot %s  %dx%d" % [path, image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""


## A switch with no value, which _argument cannot report: it returns the
## empty string both for --mcp and for no --mcp at all.
static func _has_argument(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)


## Design on the person's Claude subscription instead of ours.
##
## Opens the port if it is not already open, so this works from a plain
## double-click and not only from a command line that remembered --mcp.
## Returns false, having said why, when it cannot start.
func design_with_claude_code(brief: String) -> bool:
	if ClaudeCode.found().is_empty():
		push_warning("claude code: not installed on this machine")
		return false
	if _commands == null:
		_open_commands(CommandSocket.PORT)
	if _commands == null:
		push_warning("claude code: no port to talk to the app on")
		return false
	if _claude_code == null:
		_claude_code = ClaudeCode.new()
		add_child(_claude_code)
	if _claude_code.busy():
		return false
	_claude_code.design(brief, _commands.port(), _commands.tool_names())
	return true


## The one running, if one is.
func claude_code() -> ClaudeCode:
	return _claude_code


## Empty the baseplate, as starting a design does.
##
## Public for the command socket. A session driving from outside has no
## moment of its own where the board is cleared — asked for a lighthouse
## it would build one into whatever was standing — and the design loop
## clears the board itself, so it never needed this.
func clear_model() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.clear_selection()
	_builder.forget_history()
	_assistant.forget_built()
	_lay_baseplate()


## Write what is on the baseplate to a file. Returns false if it could not.
func save_model(path: String) -> bool:
	return _store.export_to(path, "Model")


## Open the local port that lets a session outside the app drive it.
##
## Off unless asked for, and 127.0.0.1 only. See
## src/net/command_socket.gd for why this exists at all.
func _open_commands(port: int) -> void:
	_commands = CommandSocket.new()
	_commands.assistant = _assistant
	_commands.app = self
	add_child(_commands)
	if not _commands.listen(port):
		_commands.queue_free()
		_commands = null
		return
	# What it does is narrated already: every tool emits the assistant's
	# own progress signal, which the chat panel is bound to, so the
	# window says "looking up \"wedge\"" while an outside session works.
	# Only who is connected needs saying here.
	_commands.attached.connect(func(how_many: int) -> void:
		print("command socket: %d session(s) attached" % how_many))


## The panels either side of the viewport: the parts bin on the left, the
## design assistant on the right. Both are built in code rather than in
## the scene because they are data-driven — 24,731 parts and 322 colours
## are not things to lay out by hand.
func _build_ui() -> void:
	# The library has no scene tree of its own, so it borrows this one to
	# park its HTTP requests on.
	_library.set_fetch_host(self)
	_library.fetched.connect(_on_part_fetched)
	_library.fetch_failed.connect(func(part_id: String, why: String) -> void:
		push_warning("could not fetch %s: %s" % [part_id, why])
		# Said out loud when it is the part someone is holding, because
		# otherwise clicking does nothing and nothing explains why.
		if _bar != null and _builder != null and _builder.held_part == part_id:
			_bar.say("could not load %s — %s" % [part_id, why]))

	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder

	_stability = Stability.new()
	_stability.library = _library
	_stability.lattice = _builder.lattice

	_thumbnails = PartThumbnails.new()
	_thumbnails.library = _library
	add_child(_thumbnails)

	# Accounts exist for one reason: the assistant spends money per
	# request. Everything the builder does is already running by the time
	# this finishes probing, and none of it waits on the answer.
	_account = Account.new()
	# The geometry this build did not ship may not live beside it, and
	# only the deployment knows where it does. Whatever the probe says —
	# including that it failed — something has to be set here, because
	# requests that arrive before it answers are held until it does, and
	# a deployment that serves its own parts would otherwise hold them
	# for ever waiting on a URL that was never going to come.
	_account.changed.connect(func() -> void:
		if not _account.parts_url.is_empty():
			# The real answer, which replaces anything guessed before
			# it arrived. A probe that fails — offline for a moment at
			# startup — used to pin the guess for the rest of the
			# session, and the guess is this deployment, which carries
			# only the parts it shipped with. Every other part then
			# fetched a web page and was reported as broken geometry.
			_library.remote_parts = _account.parts_url
		elif _account.answered and _library.remote_parts.is_empty():
			# Only once the deployment has actually said so.
			#
			# This fired whenever the probe finished, including when it
			# failed — pinning "next to the app" for the rest of the
			# session. This deployment serves no geometry at all, so
			# every part outside the pack it ships with was then
			# fetched from somewhere that 404s, and the browser console
			# filled up with parts that do exist, at an address that
			# was never going to have them.
			_library.remote_parts = Origin.here() + "/parts/")
	add_child(_account)

	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	# On desktop there is no proxy in front of us, so talk to the model
	# directly when a key is around — that is a developer running with
	# their own key, and there is nobody to bill. Otherwise the desktop
	# build talks to the same hosted function the web build does, which
	# means the same sign-in and the same monthly budget.
	# A key from the environment is a developer running with their own;
	# a key the person pasted in is handled by the assistant itself. The
	# proxy is still wired up either way, because it is what answers for
	# the one account this deployment spends its own key on.
	var key: String = "" if OS.has_feature("web") else _anthropic_key()
	if not key.is_empty():
		_assistant.direct_key = key
	_assistant.endpoint = _account.api_base() + Assistant.DEFAULT_ENDPOINT
	_assistant.account = _account
	add_child(_assistant)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(column)

	_bar = ModelBar.new()
	_bar.world = _world
	_bar.builder = _builder
	column.add_child(_bar)
	_bar.bind(_store)
	# The assistant remembers which bricks were its own by id, and
	# BrickWorld numbers from one again after a clear — so without this
	# those ids name the new model's bricks and the next design deletes
	# them. Same family as the undo bug, through a different door.
	# Forget, not clear. By the time either of these fires the world has
	# already been replaced, and the ids the assistant is holding name
	# bricks of the new model — so clearing removes the first few bricks
	# of whatever was just opened.
	_bar.cleared.connect(func() -> void:
		_assistant.forget_built()
		_lay_baseplate()
		_on_model_changed())
	_bar.opened.connect(func(_bricks: int) -> void:
		_assistant.forget_built()
		_lay_baseplate()
		_on_model_changed()
		_camera.frame(_built_bounds()))

	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(layout)

	_bin = PartsBin.new()
	_bin.library = _library
	_bin.thumbnails = _thumbnails
	# The eyedropper changes what is held, so the bin and the palette have
	# to follow — a swatch that still shows red after picking up a blue
	# brick is a swatch that is lying.
	_builder.picked.connect(func(part_id: String, color_code: int) -> void:
		_bin.show_held(part_id, color_code)
		_refresh_preview()
		_bar.say("picked %s" % part_id))

	_bin.part_chosen.connect(_on_part_chosen)
	_bin.color_chosen.connect(_on_color_chosen)
	_thumbnails.ready_for.connect(_bin.on_thumbnail)
	_thumbnails.geometry_arrived.connect(_bin.on_geometry_arrived)

	_bin_dock = SideDock.new()
	_bin_dock.setup(_bin, SideDock.Edge.LEFT, 336.0)
	layout.add_child(_bin_dock)

	# The middle column is the viewport. Nothing is drawn into it, but the
	# counters and the key list live at its top and bottom so they cannot
	# end up underneath a panel.
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 0)
	layout.add_child(middle)

	_counts = _viewport_label(12)
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(_counts)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(spacer)

	# In the viewport column, at the top, which is where every other 3D
	# tool puts a view cube.
	#
	# It was anchored to the bottom right of the whole window, which
	# meant two collisions rather than none: its square lay over the
	# assistant panel and swallowed clicks meant for the buttons
	# underneath, and on a tall screen it sat on top of the key strip.
	# Anchoring it inside this column makes both impossible rather than
	# unlikely.
	_gizmo = AxisGizmo.new()
	_gizmo.camera = _camera
	_gizmo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gizmo.offset_left = -AxisGizmo.size_for() - 14.0
	_gizmo.offset_top = 14.0
	_gizmo.offset_right = -14.0
	_gizmo.offset_bottom = AxisGizmo.size_for() + 14.0
	spacer.add_child(_gizmo)

	# The hint is wide, and a container asks its children how narrow they
	# can get. Left to itself the strip set the middle column's minimum
	# width and squeezed the assistant off the right edge, so it lives in
	# a clipping wrapper that claims no width of its own.
	# Above the key strip, so the strip stays where it always is rather
	# than jumping down the screen when playback starts.
	_steps = StepsBar.new()
	_steps.reveal.connect(func(ids: Dictionary) -> void: _world.show_only(ids))
	_steps.export_wanted.connect(_export_booklet)
	middle.add_child(_steps)

	# Room for two lines. The strip wraps rather than truncating when the
	# window is narrow, and a clipped area would put the wrapped line
	# behind the viewport edge instead of showing it.
	# Tall enough for the rows it actually needs.
	#
	# It was a fixed 48 pixels with clipping on, and twenty bindings
	# wrap to three rows at this app's own default window size — so the
	# strip that exists precisely so the controls cannot go unsaid cut
	# its own last row off.
	var hint_area := Control.new()
	hint_area.custom_minimum_size = Vector2(0, 48)
	hint_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(hint_area)

	# Bottom right, above the hint strip: out of the way of the model,
	# and where every other 3D tool puts it.
	_marquee = Marquee.new()
	spacer.add_child(_marquee)

	_turning = PivotMark.new()
	_turning.camera = _camera
	add_child(_turning)


	# The editing verbs, for a screen with no keyboard to press.
	if TouchTools.wanted():
		_tools = TouchTools.new()
		_tools.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		_tools.anchor_top = 0.5
		_tools.anchor_bottom = 0.5
		_tools.offset_left = 12.0
		_tools.offset_top = -TouchTools.TARGET * 2.2
		_tools.offset_bottom = TouchTools.TARGET * 2.2
		spacer.add_child(_tools)
		_tools.chose.connect(_on_touch_tool)

	var hint := ControlsHint.new()
	_hint = hint
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -46.0
	hint.offset_bottom = 0.0
	hint.alignment = FlowContainer.ALIGNMENT_CENTER
	hint_area.add_child(hint)
	# The box grows to whatever the strip needs, however it wraps.
	hint.resized.connect(func() -> void:
		var wants: float = maxf(hint.get_combined_minimum_size().y, 46.0)
		hint_area.custom_minimum_size = Vector2(0, wants + 4.0)
		hint.offset_top = -wants)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(pad)

	_chat = ChatPanel.new()
	# Decided before the panel is built, because it decides whether the
	# choice appears in the composer at all.
	_chat.claude_code_here = not ClaudeCode.found().is_empty()
	_chat_dock = SideDock.new()
	_chat_dock.setup(_chat, SideDock.Edge.RIGHT, 340.0)
	layout.add_child(_chat_dock)
	_chat.bind(_assistant)
	_chat.watch(_account)
	# Designing on the person's own Claude subscription, when this
	# machine has the Claude Code to do it with. The panel offers the
	# choice only then.
	_chat.design_locally.connect(func(brief: String) -> void:
		if not design_with_claude_code(brief):
			_chat.gave_up("Could not start Claude Code.")
			return
		_chat.follow(claude_code()))

	# Across the window rather than inside a column: a parts list is
	# consulted and dismissed, and at four hundred pieces it wants the
	# room. Added to the HUD directly so no dock resizes around it.
	# Inset from the edges rather than a fixed 860 by 600.
	#
	# A fixed size centred on the screen is off the screen as soon as
	# the screen is smaller than the size: on a phone held sideways the
	# list overflowed top and bottom, taking its header with it — and
	# the header holds the only Done button, so the way out was a key
	# nobody has. It is now as big as there is room for, up to the size
	# it used to be.
	_inventory = InventoryPanel.new()
	_inventory.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(_inventory)
	_inset(_inventory, 860.0, 600.0)
	get_viewport().size_changed.connect(func() -> void:
		_inset(_inventory, 860.0, 600.0)
		_inset(_controls, 460.0, 560.0)
		_inset(_mosaic, 380.0, 460.0))
	_bar.parts_wanted.connect(_toggle_parts)

	_controls = ControlsDialog.new()
	$HUD.add_child(_controls)
	_inset(_controls, 460.0, 560.0)
	_bar.controls_wanted.connect(_controls.open)
	# The strip along the bottom names what the middle button does, so
	# it is wrong the moment somebody changes it.
	_controls.changed.connect(func() -> void:
		if _hint != null:
			_hint.rebuild())

	_picker = PickImage.new()
	add_child(_picker)
	_mosaic = MosaicDialog.new()
	$HUD.add_child(_mosaic)
	_inset(_mosaic, 380.0, 460.0)

	# Straight from the button press into the file dialog, with nothing
	# awaited between. A browser only opens a file picker while it is
	# still handling a real click, so anything deferred here would be
	# silently ignored on the web and work perfectly on the desktop.
	# One picker, two things that want a picture, so which one asked has
	# to be remembered — the file dialog answers long after the click
	# that opened it.
	_bar.mosaic_wanted.connect(func() -> void:
		_picking_reference = false
		_picker.ask())
	_chat.reference_wanted.connect(func() -> void:
		_picking_reference = true
		_picker.ask())
	_picker.failed.connect(func(why: String) -> void: _bar.say(why))
	_picker.picked.connect(func(image: Image) -> void:
		if _picking_reference:
			if _assistant.remember_reference(image):
				_chat.references_are(_assistant.references.size())
				_bar.say("kept — the proportions will be measured off it")
			else:
				_bar.say("could not read that picture")
			return
		_mosaic_source = image
		_mosaic.show_for(image))
	_mosaic.build_wanted.connect(_build_mosaic)

	# Panels sized to the window, and folded away when there is no room
	# for them beside the model. On a phone a panel that takes its
	# design width would leave about fifty pixels of viewport, so it
	# becomes a drawer: most of the screen while you are using it, gone
	# the moment you are not.
	get_tree().root.size_changed.connect(_fit_panels)
	_fit_panels()

	_bin.populate()
	_builder.held_color = _bin.selected_color()

	# Anything that changes the model marks it for saving. Placing and
	# removing are somebody's own doing, so they also settle the
	# question of whether the model on screen is the one to keep.
	_builder.placed.connect(func(_id: int, _part: String) -> void:
		_on_model_edited())
	_builder.removed.connect(func(_id: int) -> void: _on_model_edited())
	# Watch it go up, in the order it would be built, rather than find
	# it already there.
	_playback = BuildPlayback.new()
	_playback.world = _world
	_playback.library = _library
	add_child(_playback)

	# What the camera turns around. Without this it orbits the middle of
	# whatever was last framed, so grabbing a chimney and dragging swings
	# the chimney out of shot.
	_camera.pick = func(at: Vector2) -> Variant:
		var from: Vector3 = _camera.project_ray_origin(at)
		var towards: Vector3 = _camera.project_ray_normal(at)
		var hit: BrickLattice.Hit = _builder.lattice.raycast(from, towards)
		if hit.is_valid():
			return from + towards * hit.distance
		# Nothing under the pointer, but there is still a baseplate to
		# turn around: where the ray meets the ground reads as the place
		# you pointed at far better than the middle of the model does.
		var ground := Plane(Vector3.UP, 0.0)
		var landing: Variant = ground.intersects_ray(from, towards)
		return landing if landing != null else null

	_outline = SelectionOutline.new()
	_outline.world = _world
	_outline.library = _library
	add_child(_outline)
	_builder.selection_changed.connect(func(count: int) -> void:
		_outline.show_selection(_builder.selection)
		if count == 0:
			_bar.say("")
		else:
			_bar.say("%d selected — Delete, C to paint, arrows to move"
				% count))
	# The world is redrawn whenever anything in it changes, which
	# includes a selected brick being removed by undo or replaced by the
	# assistant. Without redrawing the outline then, it is a box round
	# nothing.
	_world.rebuilt.connect(func(_bricks: int, _batches: int, _tris: int) -> void:
		if not _builder.selection.is_empty():
			_outline.show_selection(_builder.selection))
	# So a snapshot does not carry the baseplate off with it.
	_assistant.scenery = _store.scenery

	_assistant.built.connect(func(_n: int) -> void:
		# A design can be bigger than the ground it was given.
		#
		# The baseplate is laid when a model is opened and when the
		# board is cleared, and never after something is built on it —
		# so a ship the assistant designs larger than thirty-two studs
		# hangs off the edge into nothing, which reads as the model
		# being broken rather than the ground being small.
		# Next frame, not inside the signal.
		#
		# built is emitted from the middle of applying a design, and
		# laying fresh ground removes the old plates from the world and
		# the lattice. Doing that while the apply is still walking its
		# own placements is how a run reaches the last critique and
		# then simply stops, with no error and nothing written.
		_ground_for_the_model.call_deferred()
		_on_model_changed()
		if _playback.play(_store.scenery):
			_bar.say("building…"))
	# A draft appears as it is; it is about to be replaced, so animating
	# it would be an assembly that never finishes.
	_assistant.sketched.connect(func(count: int) -> void:
		if _playback.is_playing():
			_playback.stop()
		_on_model_changed()
		_bar.say("working — %d bricks so far" % count))


## A label that reads over the 3D behind it, whatever colour that is.
static func _viewport_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The key for a direct desktop call, from the environment or a .env
## beside the project. Never compiled in, and never used on the web.
static func _anthropic_key() -> String:
	var from_env: String = OS.get_environment("ANTHROPIC_API_KEY")
	if not from_env.is_empty():
		return from_env
	var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		for prefix: String in ["ANTHROPIC_API_KEY=", "AI__ANTHROPIC_API_KEY="]:
			if line.begins_with(prefix):
				return line.substr(prefix.length()).strip_edges().lstrip("\"'").rstrip("\"'")
	return ""


## The working model is written a couple of seconds after the last
## change, so closing the tab costs seconds rather than an afternoon.
## Turn the whole build on the baseplate, keeping the lattice exact.
func _turn_model(quarter_turns: int) -> void:
	var moved: Array = _world.rotate_model(quarter_turns, _store.scenery)
	if moved.is_empty():
		return
	for entry: Dictionary in moved:
		_builder.lattice.release(entry["id"])
	for entry: Dictionary in moved:
		_builder.register(entry["id"], entry["part"], entry["at"])
	_on_model_changed()


## Write the booklet out as one printable file.
##
## Every step is photographed from the same place. A booklet whose camera
## moves between steps is unreadable — the whole way you see what a step
## added is that everything else stayed where it was — so the framing is
## taken once, from the finished model, and held.
func _export_booklet() -> void:
	var steps: Array[Instructions.Step] = Instructions.plan(
		_world, _library, _store.scenery)
	if steps.is_empty():
		_bar.say("nothing to write instructions for")
		return

	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	var title: String = _bar.model_name()
	_bar.say("drawing %d steps…" % steps.size())
	await get_tree().process_frame

	# The UI is not part of the picture, and the camera has to come back
	# to where the person left it.
	var was_playing: bool = _steps.is_playing_back()
	if was_playing:
		_steps.stop()
	var had_hud: bool = $HUD.visible
	var camera_was: Transform3D = _camera.global_transform
	$HUD.visible = false
	# Framed on the model, not on what it is standing on. A 32 x 32
	# baseplate is four times the width of most things built on it, so
	# framing the lot leaves the subject a thumbnail in the middle of a
	# green field.
	# A margin above 1 leaves air around the subject; below 1 crops into
	# it. 0.78 cropped, so the finished model ran off the bottom of the
	# last few pictures — the steps where it is tallest and matters most.
	_camera.frame(_built_bounds(), 1.12)
	for _n: int in 8:
		await get_tree().process_frame
		RenderingServer.force_draw(false)

	var pages: Array[Booklet.Page] = []
	var showing: Dictionary = _store.scenery.duplicate()
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			showing[brick_id] = true
		_world.show_only(showing)

		# Forced, not awaited. A process frame is not a drawn frame, and
		# an unattended window stops being asked to redraw — which is how
		# every picture ends up being of the step before.
		for _n: int in 4:
			await get_tree().process_frame
			RenderingServer.force_draw(false)

		var page := Booklet.Page.new()
		page.index = step.index
		page.awkward = step.unsupported
		page.image = _snapshot()
		page.adds = _step_parts(step)
		pages.append(page)

	_world.show_only({})
	$HUD.visible = had_hud
	_camera.global_transform = camera_was
	# Back where you were. Saving the instructions from inside the
	# booklet stopped the playback to take its pictures and then never
	# started it again, so asking for a copy of what you were reading
	# closed what you were reading. The flag was recorded and never
	# looked at.
	if was_playing:
		_steps.start(_world, _library, _store.scenery)

	var file_name: String = title.to_snake_case() + "_instructions.html"
	var note: String = Download.give(
		Booklet.html(title, pages, stock), file_name, "text/html")
	_bar.say(note)


## What was built, without the baseplate it was built on. Falls back to
## everything when the model *is* scenery, so a picture of a bare plate
## still gets framed rather than pointing at nothing.
func _built_bounds() -> AABB:
	var bounds := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = brick.transform * part.bounds
		bounds = box if first else bounds.merge(box)
		first = false
	# Everything, including the scenery, when nothing has been built —
	# a box round nothing frames nothing, and the baseplate is at least
	# somewhere to stand. Not _built_bounds(), which is this function.
	return _world.model_bounds() if first else bounds


## The viewport as a data: URI.
##
## JPEG, not PNG. Thirty steps of a lossless 1600-wide render comes to
## tens of megabytes inside a single file, and the subject is smooth
## plastic against a flat background — the one thing JPEG does well.
func _snapshot() -> String:
	var image: Image = get_viewport().get_texture().get_image()
	# Halved first: the page is 860 wide and a 1600-wide picture in it is
	# three times the bytes for no more detail on paper.
	var wide: int = 900
	if image.get_width() > wide:
		var tall: int = int(round(float(image.get_height())
			* float(wide) / float(image.get_width())))
		image.resize(wide, tall, Image.INTERPOLATE_LANCZOS)
	var bytes: PackedByteArray = image.save_jpg_to_buffer(0.84)
	return "data:image/jpeg;base64," + Marshalls.raw_to_base64(bytes)


## What a step adds, with the colours it adds them in.
func _step_parts(step: Instructions.Step) -> Array:
	var tally: Dictionary = {}
	for brick_id: int in step.brick_ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		var key: String = "%s:%d" % [brick.part_id, brick.color_code]
		if tally.has(key):
			tally[key]["count"] = int(tally[key]["count"]) + 1
			continue
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		var color: PartLibrary.BrickColor = _library.color(brick.color_code)
		var name: String = info.name.strip_edges() if info != null else brick.part_id
		while name.contains("  "):
			name = name.replace("  ", " ")
		tally[key] = {
			"count": 1,
			"part": brick.part_id,
			"name": name,
			"colour": color.name if color != null else "",
			"rgb": "#%02x%02x%02x" % [
				int(color.rgb.r * 255.0), int(color.rgb.g * 255.0),
				int(color.rgb.b * 255.0)] if color != null else "#888888",
		}

	var adds: Array = tally.values()
	adds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["count"]) > int(b["count"]))
	return adds


## Lay the chosen picture out in plates.
##
## The mosaic replaces whatever was there, because a picture is a whole
## model rather than an addition to one — and it goes through the
## ordinary placement path, so it is undoable, saveable, counted by the
## parts list and walked by the booklet like anything else.
func _build_mosaic(across: int, dither: bool) -> void:
	if _mosaic_source == null:
		return
	_bar.say("laying it out…")
	await get_tree().process_frame

	var pixels: Array[Mosaic.Pixel] = Mosaic.lay_out(
		_mosaic_source, across, PackedInt32Array(PartsBin.SWATCHES),
		_library, dither)
	if pixels.is_empty():
		_bar.say("nothing to lay out")
		return

	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_assistant.forget_built()
	_store.scenery.clear()

	var part: Lbm.PartMesh = _library.mesh_for(Mosaic.PIXEL_PART)
	for pixel: Mosaic.Pixel in pixels:
		# A 1 x 1 plate sits centred on its stud, and the mosaic is laid
		# on the ground, so y is the plate height and nothing else.
		var at := Transform3D(Basis.IDENTITY, Vector3(
			pixel.x * BrickLattice.STUD + BrickLattice.STUD * 0.5,
			part.bounds.size.y,
			pixel.z * BrickLattice.STUD + BrickLattice.STUD * 0.5))
		var brick_id: int = _world.add_brick(
			Mosaic.PIXEL_PART, pixel.color_code, at)
		if brick_id != 0:
			_builder.register(brick_id, Mosaic.PIXEL_PART, at)

	_camera.frame(_built_bounds(), 1.1)
	_camera.set_view("top")
	_on_model_changed()
	_bar.say("%d plates — press P for what to buy" % pixels.size())


## Width below which the two panels cannot both sit beside the model.
## Their design widths plus something worth looking at between them.
const ROOMY := 1040.0


## Fit the panels to the window, and decide whether they are drawers.
func _fit_panels() -> void:
	if _bin_dock == null or _chat_dock == null:
		return
	# The real window, in points, not the viewport and not in pixels.
	#
	# With canvas_items stretch the visible rect is the design size —
	# 1600 wide whatever the window is — so asking it how much room
	# there is always answers "plenty". Dividing the canvas by the
	# app's own content scale was the next attempt and is wrong above
	# two device pixels to the point, which is every modern phone: an
	# eight-hundred-point phone held sideways measured as roomier than
	# the threshold and kept both panels open across a screen with room
	# for neither.
	var across: float = Room.across()
	var cramped: bool = across < ROOMY

	# A drawer leaves the far rail showing, so the way out is visible
	# from inside it.
	var drawer: float = maxf(across - SideDock.RAIL_WIDTH * 2.0 - 16.0, 220.0)
	_bin_dock.set_open_width(minf(336.0, drawer) if cramped else 336.0)
	_chat_dock.set_open_width(minf(340.0, drawer) if cramped else 340.0)

	if cramped and not _folded_for_room:
		# Only once. Folding them on every resize would fight anyone
		# dragging a window edge with a panel deliberately open.
		_folded_for_room = true
		_bin_dock.set_open(false, false)
		_chat_dock.set_open(false, false)
	elif not cramped and _folded_for_room:
		_folded_for_room = false
		_bin_dock.set_open(true, false)
		_chat_dock.set_open(true, false)


var _folded_for_room: bool = false


## Show or hide the parts list. Worked out on opening rather than kept
## up to date: it is a snapshot of a finished model, and recomputing it
## on every brick placed would be work for a panel nobody is looking at.
func _toggle_parts() -> void:
	if _inventory.is_showing():
		_inventory.hide_list()
		return
	if not _inventory.show_for(_world, _library, _store.scenery, _bar.model_name()):
		_bar.say("nothing to list yet")


## Start or leave the booklet. Editing while playback is on would place
## bricks into a model that is only half on screen, so the build steps
## are worked out once, on entry, from whatever is there.
func _toggle_steps() -> void:
	if _playback != null and _playback.is_playing():
		_playback.stop()
	if _steps.is_playing_back():
		_steps.stop()
		return
	if _world.brick_count() == 0:
		return
	_steps.start(_world, _library, _store.scenery)


func _on_model_changed() -> void:
	if _store != null:
		_store.touch()


## Somebody changed the model by hand, so it is theirs now.
##
## Kept apart from _on_model_changed, which also fires for things the
## app did to itself — opening, clearing, the assistant rebuilding. Only
## a deliberate change should let the autosave write over a file that
## opened short of parts.
func _on_model_edited() -> void:
	if _store != null:
		_store.adopt()
		_store.touch()


func _on_part_chosen(part_id: String) -> void:
	_builder.held_part = part_id
	# On the web most parts are a request away rather than resident. Ask
	# for it as soon as it is picked, so it is usually there by the time
	# the cursor reaches the model.
	if not _library.is_resident(part_id):
		_library.request_mesh(part_id, true)
		# And say so. Until the bytes land there is no ghost and a click
		# does nothing, which reads as the app being broken rather than
		# as the app waiting — and on a slow connection that is several
		# seconds of it.
		_bar.say("fetching %s…" % part_id)
	_refresh_preview()


func _on_part_fetched(part_id: String) -> void:
	_place_awaited(part_id)
	if _builder.held_part == part_id:
		_refresh_preview()
		_bar.say("%s ready" % part_id)


func _on_color_chosen(color_code: int) -> void:
	_builder.held_color = color_code
	_refresh_preview()


## Open an LDraw model and place every part of it. Returns how many landed.
func _open(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var model: LdrModel = LdrModel.load_file(path)
	if model == null:
		return 0

	var placed: int = 0
	var missing: Dictionary = {}
	for item: Variant in model.flatten(_library.parts):
		var placement: LdrModel.Placement = item
		var brick_id: int = _world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id != 0:
			_builder.register(brick_id, placement.part_id, placement.transform)
			placed += 1
			continue

		# Not there *yet* is not the same as not there. The web build
		# ships a few hundred parts and fetches the rest, so opening a
		# model used to drop every part outside the pack and say so only
		# in a warning nobody sees — you opened a lighthouse and got
		# most of a lighthouse.
		if _library.request_mesh(placement.part_id):
			_awaited.append(placement)
			missing[placement.part_id] = true
		else:
			_unavailable[placement.part_id] = true

	if not _awaited.is_empty():
		_bar.say("%d bricks — fetching %d more part(s)…" % [
			placed, missing.size()])
	if not _unavailable.is_empty():
		push_warning("model %s: %d part(s) unavailable: %s" % [
			path.get_file(), _unavailable.size(),
			", ".join(PackedStringArray(_unavailable.keys()).slice(0, 8))])
	return placed


## Placements waiting on geometry that is on its way, and parts that are
## not coming at all.
var _awaited: Array[LdrModel.Placement] = []
var _unavailable: Dictionary = {}


## Geometry arrived: put down anything that was waiting for it.
func _place_awaited(part_id: String) -> void:
	if _awaited.is_empty():
		return
	var still: Array[LdrModel.Placement] = []
	var landed: int = 0
	for placement: LdrModel.Placement in _awaited:
		if placement.part_id != part_id:
			still.append(placement)
			continue
		var brick_id: int = _world.add_brick(
			placement.part_id, placement.color_code, placement.transform)
		if brick_id != 0:
			_builder.register(brick_id, placement.part_id, placement.transform)
			landed += 1
	_awaited = still
	if landed == 0:
		return
	_on_model_changed()
	if _awaited.is_empty():
		_bar.say("%d bricks" % _world.brick_count())


## A fallback when no sample model is around: a wall that exercises the
## batching, the palette and the lattice all at once.
func _build_demo() -> int:
	const BRICK := "3001"          # Brick 2 x 4
	const COURSE_HEIGHT := 24      # one brick
	const STUD := 20
	var palette: PackedInt32Array = PackedInt32Array([4, 14, 2, 1, 26, 25, 15, 0])

	var placed: int = 0
	for course: int in 10:
		# Offset alternate courses by two studs, the way a real wall is laid.
		var offset: int = (course % 2) * STUD * 2
		for column: int in 6:
			# Courses go up. The negated height was left over from thinking
			# in LDraw's axes, where -Y is up, and built the whole wall
			# downward through the baseplate.
			var at := Transform3D(
				Basis.IDENTITY,
				Vector3(column * STUD * 4 + offset, course * COURSE_HEIGHT, 0))
			if _world.add_brick(BRICK, palette[course % palette.size()], at) != 0:
				placed += 1
	return placed


## Build something by driving the placement path rather than the model, so
## the whole chain gets exercised: a ray is cast, the lattice is marched,
## the hit face decides a target, the target is snapped to the stud grid
## and dropped onto whatever is below, the result is collision checked, and
## only then is a brick placed.
##
## A brick that lands half a plate low, or one that is allowed to overlap
## its neighbour, shows up here and nowhere else — placing bricks by
## writing transforms directly would prove nothing about any of it.
func _autobuild(courses: int) -> void:
	var palette: Array[int] = [4, 14, 2, 1, 26, 25, 15, 191]
	const BRICK := "3001"      # Brick 2 x 4: 80 x 40 LDU
	const LONG := 80.0
	const SHORT := 40.0
	# A hollow square, four bricks to a side. The long walls take the full
	# span and the short walls fit between them, which is what stops the
	# corners overlapping; the pair swaps every course, so the courses bond
	# the way a real wall does instead of stacking four separate columns.
	const REACH := 2.0 * LONG          # 160: half the outer span
	var placed: int = 0
	var refused: int = 0

	for course: int in courses:
		_builder.held_color = palette[course % palette.size()]
		var swap: bool = course % 2 == 1

		for side: int in 4:
			var full: bool = (side < 2) != swap
			var offset: float = REACH - SHORT * 0.5    # 140
			for n: int in (4 if full else 3):
				var along: float
				var target: Vector3
				if full:
					along = -1.5 * LONG + n * LONG     # -120 -40 40 120
				else:
					along = -LONG + n * LONG           # -80 0 80

				match side:
					0:
						target = Vector3(along, 0.0, -offset)
						_builder.held_rotation = 0
					1:
						target = Vector3(along, 0.0, offset)
						_builder.held_rotation = 0
					2:
						target = Vector3(-offset, 0.0, along)
						_builder.held_rotation = 1
					_:
						target = Vector3(offset, 0.0, along)
						_builder.held_rotation = 1

				# Aim straight down from well above, the way a cursor would.
				_builder.update_preview(
					target + Vector3(0.0, 2000.0, 0.0), Vector3.DOWN)
				if _builder.place() != 0:
					placed += 1
				else:
					refused += 1

	# Collision has to be shown firing, not merely never asked. Every brick
	# above sat on a clear column, so nothing was refused; put one exactly
	# where another already is and it must be.
	var overlap_refused: bool = false
	var sample: BrickWorld.Brick = null
	for brick: Variant in _world.bricks():
		sample = brick
		break
	if sample != null:
		var cells: Array[Vector3i] = _builder._cells_for(
			_library.mesh_for(sample.part_id), sample.transform)
		overlap_refused = _builder.lattice.collides(cells)

	print("autobuild placed=%d refused=%d cells=%d overlap_detected=%s" % [
		placed, refused, _builder.lattice.occupied_cells(), overlap_refused])


## Fill a cube with bricks to find where the frame time goes.
##
## Deliberately uses a handful of part types rather than one: a single part
## would collapse into one batch and flatter the numbers, whereas a real
## model spreads over dozens.
func _build_stress(target: int) -> int:
	var kinds: PackedStringArray = PackedStringArray([
		"3001", "3003", "3004", "3005", "3020", "3024", "3068b", "3062b"])
	var palette: PackedInt32Array = PackedInt32Array([
		4, 14, 2, 1, 26, 25, 15, 0, 70, 72, 191, 308])

	# A roughly cubic arrangement on the real lattice, so the spatial
	# spread matches what a big model actually looks like.
	var side: int = int(ceil(pow(float(target), 1.0 / 3.0)))
	var placed: int = 0
	var n: int = 0
	for y: int in side:
		for z: int in side:
			for x: int in side:
				if placed >= target:
					return placed
				var at := Transform3D(Basis.IDENTITY,
					Vector3(x * 80.0, y * 24.0, z * 40.0))
				if _world.add_brick(
						kinds[n % kinds.size()], palette[(n / 7) % palette.size()], at) != 0:
					placed += 1
				n += 1
	return placed


## Something to build on. A model opened from a file floats in space
## otherwise, and there is nothing for a first brick to rest against.
## Lay more ground if what is built has outgrown it.
##
## Only when it has: re-laying on every change would rebuild the plates
## each time a brick is put down by hand, for nothing.
func _ground_for_the_model() -> void:
	var box: AABB = _built_bounds()
	if box.size.length_squared() <= 0.0:
		return
	if _ground.size.length_squared() > 0.0 \
			and _ground.encloses(AABB(
				Vector3(box.position.x, 0.0, box.position.z),
				Vector3(box.size.x, 0.0, box.size.z))):
		return
	_lay_baseplate()


## The ground laid down, flattened: x and z only, since the plates are
## all at y=0 and a model's height has nothing to do with whether it
## fits on them.
var _ground: AABB = AABB()


func _lay_baseplate() -> void:
	const PLATE := "3811"   # Baseplate 32 x 32
	# The ground that was here goes, brick and record together.
	#
	# Clearing the record alone was harmless while this only ran just
	# after the world was emptied — there was nothing left to be stale.
	# Laying fresh ground under a model that has outgrown its plate
	# runs it with the old plate still in the world, and dropping it
	# from the set does not remove it: it becomes an ordinary brick,
	# sitting under everything, in the way of every edit. Two designs
	# reported exactly that — "a stray baseplate part sitting below
	# ground level" — and I read the code that skips scenery, decided
	# they had misdiagnosed it, and moved on. They had not.
	#
	# A stale id matters the other way too. BrickWorld numbers from one
	# again after a clear, so an id left in this set names an ordinary
	# brick somebody places later — and a brick marked as scenery is
	# left out of Save, Export, the parts list and the booklet,
	# silently.
	if _store != null:
		for old_id: int in _store.scenery.keys():
			_builder.lattice.release(old_id)
			_world.remove_brick(old_id)
		_store.scenery.clear()
	# At zero, not a plate below it. A part's origin sits at the top of
	# its body, and bricks rest with their undersides on the plane that
	# GROUND_CELL names — which is zero. Laying the baseplate at -8 put
	# its surface a full plate under them, so everything on it floated
	# three millimetres clear of the studs it was supposed to be on.
	# Measured: the gap was 8 LDU, and closing it moves the baseplate
	# rather than anything built on it.
	# Enough ground to stand the model on.
	#
	# One plate is thirty-two studs across, which was the whole world
	# back when a model was fifty bricks. A set-sized one runs off the
	# edge and hangs in the air — the first thing anyone sees of a big
	# model is half of it over nothing, which reads as the model being
	# broken rather than the ground being small. Tiled to cover what is
	# actually there, and still a single plate when there is nothing.
	const ACROSS := 32.0 * BrickLattice.STUD
	var box: AABB = _built_bounds()
	var wide: int = 1
	var deep: int = 1
	if box.size.x > 0.0 or box.size.z > 0.0:
		wide = maxi(int(ceil(box.size.x / ACROSS)), 1)
		deep = maxi(int(ceil(box.size.z / ACROSS)), 1)
	# Centred on the model rather than on the origin.
	#
	# A baseplate's origin is its middle, not a corner, so one laid at
	# zero covers sixteen studs each way — and a model built outward
	# from the origin, which is where designs start, hung off two
	# edges of it from the beginning.
	#
	# Snapped to whole studs so the plates meet the grid; neighbours
	# are a whole plate apart, so snapping the first snaps them all.
	var middle: Vector3 = box.get_center()
	var first_x: float = snappedf(
		middle.x - float(wide - 1) * ACROSS * 0.5, BrickLattice.STUD)
	var first_z: float = snappedf(
		middle.z - float(deep - 1) * ACROSS * 0.5, BrickLattice.STUD)
	_ground = AABB(
		Vector3(first_x - ACROSS * 0.5, 0.0, first_z - ACROSS * 0.5),
		Vector3(float(wide) * ACROSS, 0.0, float(deep) * ACROSS))
	for column: int in wide:
		for row: int in deep:
			var at := Transform3D(Basis.IDENTITY, Vector3(
				first_x + float(column) * ACROSS, 0.0,
				first_z + float(row) * ACROSS))
			var brick_id: int = _world.add_brick(PLATE, 288, at)  # Dark Green
			if brick_id == 0:
				continue
			_builder.register(brick_id, PLATE, at)
			if _store != null:
				_store.scenery[brick_id] = true


## Counted once. Walking 29,479 entries on every rebuild would be work
## done for a number that cannot change while the app is running.
var _placeable: int = -1


func _placeable_parts() -> int:
	if _placeable >= 0:
		return _placeable
	_placeable = 0
	for id: String in _library.ids():
		var info: PartLibrary.PartInfo = _library.parts[id]
		if not info.is_redirect() and info.reachable:
			_placeable += 1
	return _placeable


func _on_rebuilt(brick_count: int, batch_count: int, triangle_count: int) -> void:
	if _counts == null:
		return
	# The count of parts you can place, which is not the size of the
	# catalogue: 1,160 of its entries are redirect stubs forwarding to
	# whatever replaced them. The bin says 28,319 and this said 29,479,
	# and two numbers for the same thing on one screen is how the app
	# looked like it was hiding parts.
	_counts_base = "%s bricks · %d batches · %s triangles · %s parts" % [
		_comma(brick_count), batch_count, _comma(triangle_count),
		_comma(_placeable_parts())]
	# Stability is cheap but not free, and a rebuild can fire several
	# times while a model is being dropped in. Once a second is plenty
	# for something a person reads.
	var now: int = Time.get_ticks_msec()
	if _stability != null and now - _stability_at > 900:
		_stability_at = now
		_stability_text = _stability.check(_world).summary()


func _process(_delta: float) -> void:
	# A box whose ending went somewhere else.
	#
	# Letting go over a button hands the release to that button, which
	# handles it and stops it there — so the guard above never runs and
	# the box is still being drawn with nothing holding it. The camera
	# keeps the same watch over its own drags, after the same bug.
	# Only a box this handler saw begin.
	#
	# Asking the marquee alone was enough to select an entire model on
	# startup: a motion event arriving with a stale left-button mask
	# puts it into drawing without any press ever reaching here, and the
	# watchdog then dutifully finished a box nobody drew. Everything
	# selected, "took 50" in the bar, and one keypress from deleting the
	# lot.
	if _box_began and _marquee != null and _marquee.is_drawing() \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box(Input.is_key_pressed(KEY_SHIFT))
	if _store != null:
		_store.tick()
	if _counts == null:
		return
	# Frame time belongs beside the counts: the whole point of batching is
	# that the counts can grow without it moving.
	# The counts line is rebuilt from its parts rather than patched, so
	# repeated frames cannot accrete suffixes.
	var fps: float = Engine.get_frames_per_second()
	var line: String = "%s · fps %.0f" % [_counts_base, fps]
	if not _stability_text.is_empty():
		line += " · " + _stability_text
	_counts.text = line


## The palette the number keys reach for: a readable spread rather than
## the first twelve codes, which are mostly greys and browns.
const QUICK_COLORS: Array[int] = [4, 14, 2, 1, 26, 25, 15, 0, 70, 191]

## Parts the bracket keys cycle. A starter bin, not the catalogue — the
## catalogue has 24,731 entries and needs a search box, which is next.
const QUICK_PARTS: Array[String] = [
	"3005", "3004", "3622", "3009", "3003", "3001", "3007",
	"3024", "3023", "3020", "3031", "3068b", "3040b", "3298", "4070", "3062b"]

var _part_index: int = 5
var _color_index: int = 0


## How long a finger must stay down to mean "take this one off"
## rather than "put one here", in milliseconds.
const HOLD_MS := 480


var _touch_down_at: int = 0
var _touch_index: int = -1


func _unhandled_input(event: InputEvent) -> void:
	# Touch handles only what a mouse has no gesture for: holding a
	# finger down to take a brick off, which is what a second button
	# would have been. Placing is left to the click that emulation
	# raises from the same tap, because emulation has to stay on — no
	# text field in the app can be focused without it.
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _over_panel_at(touch.position):
				return
			# The first finger only. A second is a pinch, which belongs
			# to the camera and must not remove anything.
			if _touch_index == -1:
				_touch_index = touch.index
				_touch_down_at = Time.get_ticks_msec()
			return

		if touch.index != _touch_index:
			return
		# Cleared wherever the finger comes up, including over a panel.
		#
		# The panel test used to come first and return, so a finger that
		# started on the model and ended on a panel left this set and
		# left its press time behind — and the next tap, measured
		# against a timestamp from minutes ago, read as a hold and took
		# a brick off instead of putting one on.
		_touch_index = -1
		if _over_panel_at(touch.position):
			return
		# The camera saw the same finger and knows whether it travelled.
		# A gesture that moved has already asked for its click to be
		# swallowed, and is not a hold either.
		if not _camera.last_touch_was_a_tap():
			return
		if Time.get_ticks_msec() - _touch_down_at < HOLD_MS:
			return

		_builder.update_preview(
			_camera.project_ray_origin(touch.position),
			_camera.project_ray_normal(touch.position))
		_builder.remove_hovered()
		_builder.hide_preview()
		# The hold raises a click too, and it would put back what was
		# just taken off.
		_camera.swallow_next_click()
		return

	if event is InputEventMouseMotion:
		var moved: InputEventMouseMotion = event
		# Drawing a box, which is not aiming the ghost. Any left drag,
		# with or without shift — shift only decides whether what it
		# catches is added to the selection or replaces it.
		if (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if _marquee.drag_to(moved.position):
				_builder.hide_preview()
				return
		if _over_panel_at(moved.position):
			_builder.hide_preview()
			return
		_refresh_preview(moved.position)
		return

	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	if button.alt_pressed:
		return
	# A press that lands on a panel belongs to the panel. A release does
	# not always: if a box is being drawn, that drag started out here
	# and owns its own ending, wherever the pointer has got to by then.
	#
	# Dropping it lost the selection without saying so. Drag a box
	# rightwards and let go over the parts bin — which is where the
	# pointer naturally ends up — and the release never arrived, so
	# nothing was ever selected. The rectangle sat there until the next
	# press cleared it. You drew a box round six bricks and got
	# nothing, with no way to tell that from having missed them.
	#
	# Asked of the event's own position, not of the pointer.
	#
	# This used to ask where the system says the mouse is now, which
	# during a drag is not where the button was let go — and on the web,
	# where the pointer can be locked or a frame behind, is not reliably
	# anywhere in particular. An event should be judged by where it says
	# it happened. The helper that asked the other way is gone rather
	# than merely unused, because it is an easy thing to reach for
	# again.
	var ending_a_box: bool = (button.button_index == MOUSE_BUTTON_LEFT
		and not button.pressed and _marquee.is_drawing())
	if _over_panel_at(button.position) and not ending_a_box:
		return

	# The right button acts on release, not on press.
	#
	# Right-drag turns the model — which it has to, since a trackpad has
	# no middle button and orbiting is not an advanced feature. Acting
	# on the press would take a brick off at the start of every turn.
	# The camera decides which it was by whether the pointer moved, and
	# says so through swallowing_click.
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			return
		if _camera.turned_rather_than_clicked():
			return
		_aim_at(button.position)
		_builder.remove_hovered()
		_refresh_preview()
		return

	if button.button_index != MOUSE_BUTTON_LEFT:
		return

	# Shift picks bricks out instead of placing them, on the press —
	# where a double click is reported. Placing is the verb this app is
	# mostly about, so it keeps the plain click.
	# Every left press might become a box.
	#
	# Which it is depends on whether the pointer moves, so nothing is
	# decided here. A drag draws a box; a click without one places, or
	# picks a brick out when shift is held.
	if button.pressed:
		_marquee.begin(button.position)
		_box_began = true
		if button.shift_pressed and button.double_click:
			_aim_at(button.position)
			_builder.select_alike()
		return

	# A drag is a box, not a placement.
	#
	# This is the gesture everyone tries first, because it is how every
	# other 3D viewport turns the model — and here it used to place a
	# brick wherever the pointer happened to stop. Somebody reaching for
	# the obvious thing was building with it, one brick per attempt,
	# with nothing to say why. Dragging selects now, which is what the
	# left button is for: select, place, box-select, and nothing else.
	if _marquee.is_drawing():
		_finish_box(button.shift_pressed)
		return
	_marquee.finish()

	if button.shift_pressed:
		_aim_at(button.position)
		_builder.toggle_hovered()
		return

	# Placing goes on the release, not the press.
	#
	# A finger raises an emulated press the instant it lands, so placing
	# on the press dropped a brick before the finger had moved — and
	# then the drag turned the model, leaving the brick wherever the
	# finger first touched. Waiting for the release gives the camera
	# time to see the drag and ask for the click to be thrown away.

	if _playback != null and _playback.is_playing():
		# Reaching for the model ends the animation, and this click is
		# what ended it rather than a placement.
		_playback.stop()
		return
	# A finger that turned the model raises a click on release just as a
	# tap does; without this a drag leaves a brick wherever it ended.
	if _camera.swallowing_click():
		return

	# Aimed before it is placed.
	#
	# A mouse moves before it clicks, so the ghost is already where the
	# pointer is and placing first was harmless. A finger does not: it
	# arrives, and the only position anything knows is wherever the
	# pointer was last left. So every tap placed its brick where the
	# previous tap had been.
	_aim_at(button.position)
	_builder.place()
	_refresh_preview()


## Where a brick lands on the screen, as a rectangle.
##
## Its eight corners projected and bounded, which is close enough for
## deciding whether a box covers it and far cheaper than anything
## exact. A corner behind the camera projects to nonsense, so a brick
## with any corner behind it is left out rather than guessed at.
func _brick_on_screen(brick: BrickWorld.Brick) -> Variant:
	if _store != null and _store.scenery.has(brick.id):
		return null
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	if part == null:
		return null
	var box: AABB = part.bounds
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = brick.transform * (box.position + Vector3(
			box.size.x if n & 1 else 0.0,
			box.size.y if n & 2 else 0.0,
			box.size.z if n & 4 else 0.0))
		if _camera.is_position_behind(corner):
			return null
		var at: Vector2 = _camera.unproject_position(corner)
		lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.y))
		hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.y))
	return Rect2(lo, hi - lo)


## Point the ghost at a place on the screen, whatever the pointer is
## doing. A finger raises no motion to do it for us.
func _aim_at(point: Vector2) -> void:
	_builder.update_preview(
		_camera.project_ray_origin(point),
		_camera.project_ray_normal(point))


## Centre a panel, no larger than it wants and no larger than the room
## there is.
##
## The margin is what keeps the way out reachable: a dialog that runs to
## the edges has its close button under the notch, the rounded corner,
## or nothing at all.
func _inset(panel: Control, wants_wide: float, wants_tall: float) -> void:
	if panel == null:
		return
	const MARGIN := 24.0
	var room: Vector2 = get_viewport().get_visible_rect().size
	var wide: float = minf(wants_wide, room.x - MARGIN * 2.0)
	var tall: float = minf(wants_tall, room.y - MARGIN * 2.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -wide * 0.5
	panel.offset_right = wide * 0.5
	panel.offset_top = -tall * 0.5
	panel.offset_bottom = tall * 0.5


## One of the round buttons a finger can reach.
func _on_touch_tool(what: String) -> void:
	match what:
		"rotate":
			_builder.rotate_held(1)
			_refresh_preview()
			_bar.say("turned a quarter")
		"tip":
			_builder.tip_held(1)
			_refresh_preview()
			_bar.say("on its %s" % _builder.held_face)
		"undo":
			if _builder.undo():
				_refresh_preview()
				_on_model_edited()
			else:
				_bar.say("nothing to undo")
		"redo":
			if _builder.redo():
				_refresh_preview()
				_on_model_edited()
			else:
				_bar.say("nothing to redo")


## A box around everything selected, for framing it.
func _selection_bounds() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in _builder.selection:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return _built_bounds() if first else box


## Move the selection one stud in a direction named on the screen
## rather than in the world.
##
## Pressing left should move things left as they look, not along
## whichever world axis happens to be called x. The model can be turned
## to any angle, so "left" is worked out from where the camera is
## standing and snapped to the nearest axis of the lattice.
func _nudge(screen_way: Vector3) -> void:
	var basis: Basis = _camera.global_transform.basis
	var world_way: Vector3 = basis * screen_way
	world_way.y = 0.0
	if world_way.length_squared() < 0.0001:
		return
	# The nearest of the four ground directions.
	var axis: Vector3 = (Vector3(signf(world_way.x), 0.0, 0.0)
		if absf(world_way.x) >= absf(world_way.z)
		else Vector3(0.0, 0.0, signf(world_way.z)))
	_nudge_by(Vector3i(axis * BrickLattice.CELLS_PER_STUD))


func _nudge_by(cells: Vector3i) -> void:
	if _builder.move_selection(cells) > 0:
		_on_model_edited()
	else:
		_bar.say("no room that way")


## True when the cursor is over a panel rather than the model.
##
## Without this, clicking a part in the bin also drops a brick behind it,
## and moving the mouse across the assistant leaves a ghost following the
## cursor over the text.
## Whether a point is over one of the panels rather than the model.
## The existing test asks where the mouse is, which on a touch screen is
## wherever it was last left — usually nowhere near the finger.
## Is this point over something other than the model?
##
## One list, used by both the touch path and the mouse path. They used
## to have a list each and the mouse one was shorter — it did not know
## about the parts list, so with that open the ghost still followed the
## cursor and a click beside the panel dropped a brick into the model
## behind it. Nor about the axis gizmo, whose square swallows clicks
## wherever it sits.
## Take whatever the box caught and put it away.
##
## One function because two callers need it to do the same thing: the
## release that ends the drag, and the watchdog for when that release
## goes somewhere this handler never sees.
func _finish_box(add: bool) -> void:
	_box_began = false
	if not _marquee.is_drawing():
		_marquee.finish()
		return
	var took: int = _builder.select_in(_marquee.box(),
		_brick_on_screen, _marquee.takes_touching(), add)
	_marquee.finish()
	_bar.say("took %d" % took if took > 0
		else "nothing in there — right-drag turns the view")


func _over_panel_at(point: Vector2) -> bool:
	for panel: Control in [_bin_dock, _chat_dock, _bar, _gizmo]:
		if panel != null and panel.visible \
				and panel.get_global_rect().has_point(point):
			return true
	# These cover the model rather than sitting beside it, so anywhere
	# is over them.
	if _inventory != null and _inventory.is_showing():
		return true
	if _mosaic != null and _mosaic.visible:
		return true
	return false


## Aim the ghost brick.
##
## ``at`` is where the pointer actually is for this event. Without it
## the ghost is aimed wherever the system says the mouse is now, which
## during a drag is not where the event happened, and on the web, with
## the pointer locked or a frame behind, is not reliably anywhere. It
## is the same fault that was fixed for deciding whether a click landed
## on a panel, left in the one place that decides what the click is
## aimed AT.
##
## Callers with no event — after an undo, after a key — pass nothing
## and get the live pointer, which for them is right.
func _refresh_preview(at: Vector2 = Vector2.INF) -> void:
	var mouse: Vector2 = at
	if not (mouse.x < INF):
		mouse = get_viewport().get_mouse_position()
	_builder.update_preview(
		_camera.project_ray_origin(mouse),
		_camera.project_ray_normal(mouse))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed():
		return
	# Whoever is pressing keys has stopped watching.
	if _playback != null and _playback.is_playing():
		_playback.stop()
	# A single-letter shortcut must never fire while someone is typing a
	# part name or a brief.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	var key: InputEventKey = event
	match key.keycode:
		KEY_F:
			# The selection if there is one, everything with shift —
			# which is what "zoom to fit" means in every tool that has
			# both.
			if key.shift_pressed or _builder.selection.is_empty():
				_camera.frame(_built_bounds())
			else:
				_camera.frame(_selection_bounds())
		KEY_HOME:
			_camera.frame(_built_bounds())
		KEY_6:
			_camera.set_view("bottom")
		KEY_7:
			_camera.set_view("isometric")
		KEY_O:
			# Straight-on and back. A CAD drawing is read square on;
			# a model on a table is seen in perspective.
			_camera.square_on(not _camera.is_square_on())
			_bar.say("square on" if _camera.is_square_on()
				else "in perspective")
		KEY_1: _camera.set_view("front")
		KEY_2: _camera.set_view("back")
		KEY_3: _camera.set_view("left")
		KEY_4: _camera.set_view("right")
		KEY_5: _camera.set_view("top")
		KEY_0: _camera.set_view("default")
		KEY_R:
			_builder.rotate_held(-1 if key.shift_pressed else 1)
			_refresh_preview()
		KEY_T:
			_builder.tip_held(-1 if key.shift_pressed else 1)
			_refresh_preview()
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step: int = 1 if key.keycode == KEY_BRACKETRIGHT else -1
			_color_index = posmod(_color_index + step, QUICK_COLORS.size())
			_builder.held_color = QUICK_COLORS[_color_index]
			_bin._on_colour(QUICK_COLORS[_color_index])
			_refresh_preview()
		KEY_Q, KEY_E:
			_turn_model(1 if key.keycode == KEY_E else -1)
		KEY_B:
			_toggle_steps()
		KEY_P:
			_toggle_parts()
		KEY_C:
			# Paint the selection if there is one, or what is under the
			# cursor if there is not.
			if not _builder.selection.is_empty():
				var painted: int = _builder.paint_selection(_builder.held_color)
				if painted > 0:
					_on_model_edited()
					_bar.say("painted %d" % painted)
			elif _builder.paint_hovered(_builder.held_color):
				_on_model_changed()
		KEY_DELETE, KEY_BACKSPACE:
			var gone: int = _builder.remove_selection()
			if gone > 0:
				_on_model_edited()
				_bar.say("removed %d" % gone)
		KEY_A:
			# Everything the assistant built, in one go, so that
			# "start again from mine" is one key rather than a hunt.
			if key.meta_pressed or key.ctrl_pressed:
				_builder.clear_selection()
				for brick: BrickWorld.Brick in _world.bricks():
					if not _store.scenery.has(brick.id):
						_builder.selection[brick.id] = true
				_builder.selection_changed.emit(_builder.selection.size())
		KEY_G:
			# And take a colour and part back off the model.
			_builder.pick_hovered()
		KEY_X:
			# Lift a brick off to move it. The next click puts it down.
			if _builder.lift_hovered():
				_on_model_changed()
				_bar.say("lifted — click to put it down")
		KEY_LEFT, KEY_RIGHT:
			# Three claims on these keys, in order. A booklet being read
			# owns them; then a selection being nudged; then whatever
			# has focus, because stealing them unconditionally breaks
			# the search box and the brief.
			if _steps.is_playing_back():
				if key.keycode == KEY_RIGHT:
					_steps.step_forward()
				else:
					_steps.step_back()
			elif not _builder.selection.is_empty():
				_nudge(Vector3.RIGHT if key.keycode == KEY_RIGHT
					else Vector3.LEFT)
		KEY_UP, KEY_DOWN:
			if not _builder.selection.is_empty():
				# Along the ground with no modifier; up and down with
				# shift, which is the axis you want far less often.
				if key.shift_pressed:
					_nudge_by(Vector3i(0,
						BrickLattice.CELLS_PER_PLATE
						* (1 if key.keycode == KEY_UP else -1), 0))
				else:
					_nudge(Vector3.FORWARD if key.keycode == KEY_UP
						else Vector3.BACK)
		KEY_TAB:
			# Both panels away, for looking at the model.
			var showing: bool = _bin_dock.is_open() or _chat_dock.is_open()
			_bin_dock.set_open(not showing)
			_chat_dock.set_open(not showing)
		KEY_Z:
			if key.ctrl_pressed or key.meta_pressed:
				if key.shift_pressed:
					_builder.redo()
				else:
					_builder.undo()
				_refresh_preview()
		KEY_COMMA:
			# Where a preferences panel lives in every app on this
			# machine.
			_controls.open()
		KEY_SLASH:
			if _bin:
				_bin.focus_search()
		KEY_S:
			if (key.ctrl_pressed or key.meta_pressed) and _bar:
				_bar._on_save()
		KEY_ESCAPE:
			# Leaving playback first. Escape reads as "out of this mode",
			# and quitting the app because someone wanted the whole model
			# back would be a bad surprise.
			#
			# A selection is the innermost of these modes and so goes
			# first. Adding it as a second arm of the same match was the
			# obvious way and silently took the whole ladder over: one
			# match statement runs one arm, so leaving the booklet
			# stopped working and nobody would find out until they
			# tried it.
			# Everything that is up, innermost first. A ladder that
			# does not know about a dialog falls through to the bottom
			# rung, and the bottom rung on the desktop is quit — so
			# Escape with the mosaic dialog open closed the whole app.
			if _mosaic != null and _mosaic.visible:
				_mosaic.visible = false
				return
			if not _builder.selection.is_empty():
				_builder.clear_selection()
				return
			if _inventory.is_showing():
				_inventory.hide_list()
				return
			if _steps.is_playing_back():
				_steps.stop()
				return
			if OS.has_feature("web"):
				return
			get_tree().quit()


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	var count: int = 0
	for n: int in range(text.length() - 1, -1, -1):
		out = text[n] + out
		count += 1
		if count % 3 == 0 and n > 0:
			out = "," + out
	return out
