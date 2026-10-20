## Build, Pose and animate…: a slider for every joint a sub-assembly turns
## on, keys at moments, and the animation those keys make, rendered.
##
## The sliders are the pose (Poser): drag one and the sub-assembly swings
## about its real hinge or turntable as the slider goes, and letting go
## keeps it there as one step to undo — as far as it has room for, and the
## panel says where it stopped. Add key keeps every joint's angle at the
## time beside it; two or three keys are an animation (PoseAnimation),
## eased in and out, that Play runs in the window and Render animation
## draws off screen in pieces a frame at a time (StudioRender.animate), so
## the window and a browser tab keep answering. In a browser it downloads
## as an animated WebP; on the desktop the frames, the WebP and, where
## ffmpeg is installed, an MP4 go to Downloads (RenderOutput).
class_name PosePanel
extends PanelContainer

## The model changed: a joint was set.
signal changed()

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var assemblies: Assemblies
var scenery: Dictionary = {}
var eye: Camera3D
var look: Environment
var rig_lights: Array[DirectionalLight3D] = []
var named: Callable = func() -> String: return "Model"
## Where desktop files go; Downloads when empty. A probe points it elsewhere.
var folder: String = ""

var poser := Poser.new()
var animation := PoseAnimation.new()
var renderer: StudioRender
var settings := RenderSettings.new()

const SIZES: Array = [["480 × 300", Vector2i(480, 300)], ["720p", Vector2i(1280, 720)]]
const RATES: Array = [12, 24]

var _rows: VBoxContainer
var _sliders: Array[HSlider] = []
var _readouts: Array[Label] = []
var _empty: Label
var _rest: Button
var _key_time: SpinBox
var _add_key: Button
var _keys_box: VBoxContainer
var _play: Button
var _turntable: CheckBox
var _rate: OptionButton
var _size: OptionButton
var _render: Button
var _cancel: Button
var _close: Button
var _progress: ProgressBar
var _status: Label
var _frame: TextureRect

var _dragging: String = ""
var _drag_from: float = 0.0
var _quiet: bool = false
var _playing: bool = false
var _play_at: float = 0.0
var _working: bool = false
var _fraction: float = 0.0
var _last: Dictionary = {}
var _seen_revision: int = -1
var _told_page: String = ""
var _told_page_at: int = 0


func _ready() -> void:
	visible = false
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = SIZES[0][1]
	settings.contact_shadow = false
	settings.view = "current"
	_build()


func open() -> void:
	poser.world = world
	poser.builder = builder
	poser.library = library
	poser.assemblies = assemblies
	_read_pose()
	visible = true
	_status.text = "Drag a slider to swing that part about its joint." if not poser.joints.is_empty() \
		else ""


## The joints as the model stands, without the panel: for a session over
## MCP (AppTools), which then swings one with [method set_angle].
func joints_now() -> Array[Poser.Joint]:
	poser.world = world
	poser.builder = builder
	poser.library = library
	poser.assemblies = assemblies
	if poser.joints.is_empty() or _seen_revision != world.revision:
		_read_pose()
	return poser.joints


func close() -> void:
	if _playing:
		_stop()
	if renderer != null and renderer.is_busy():
		renderer.cancel()
	visible = false


## The joints as the model stands: the angles kept if the parts still stand
## as they say, read back off the parts after an undo, found afresh
## otherwise (the model changed, or this is the first time).
func _read_pose() -> void:
	if poser.joints.is_empty() or not (poser.holds() or poser.read_back()):
		poser.find()
	_seen_revision = world.revision
	_fill_joints()


# -- the sliders -----------------------------------------------------------------


func _fill_joints() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_sliders.clear()
	_readouts.clear()
	_empty.visible = poser.joints.is_empty()
	_rest.visible = not poser.joints.is_empty()
	for one: Poser.Joint in poser.joints:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		_rows.add_child(row)
		var top := HBoxContainer.new()
		row.add_child(top)
		var called := Label.new()
		called.text = "%s, on its %s" % [Assemblies.label(one.path), one.kind()]
		called.add_theme_font_size_override("font_size", 12)
		called.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		called.clip_text = true
		top.add_child(called)
		var readout := Label.new()
		readout.add_theme_font_size_override("font_size", 12)
		readout.text = "%d°" % roundi(one.angle)
		top.add_child(readout)
		var slider := HSlider.new()
		slider.min_value = -180.0
		slider.max_value = 180.0
		slider.step = 1.0
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(260, 18)
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.16)
		track.set_corner_radius_all(2)
		track.content_margin_top = 2
		track.content_margin_bottom = 2
		slider.add_theme_stylebox_override("slider", track)
		slider.set_value_no_signal(one.angle)
		var path: String = one.path
		slider.drag_started.connect(func() -> void:
			_dragging = path
			_drag_from = poser.joint(path).angle)
		slider.drag_ended.connect(func(_changed: bool) -> void:
			var from: float = _drag_from
			_dragging = ""
			_settle(path, slider.value, from))
		slider.value_changed.connect(func(value: float) -> void:
			if _quiet:
				return
			readout.text = "%d°" % roundi(value)
			if _dragging == path:
				var wanted: Dictionary = poser.angles()
				wanted[path] = value
				poser.stand(wanted)
			else:
				# A click on the track: there at once.
				_settle(path, value, poser.joint(path).angle))
		row.add_child(slider)
		_sliders.append(slider)
		_readouts.append(readout)


## A joint let go at [param value]: as far as it has room for.
func _settle(path: String, value: float, from: float) -> void:
	var reached: float = poser.settle(path, value, from)
	_seen_revision = world.revision
	_show_angles()
	if absf(reached - value) > 0.5:
		_status.text = "%s stops at %d°: any further and it runs into something." % [
			Assemblies.label(path), roundi(reached)]
	else:
		_status.text = "%s at %d°." % [Assemblies.label(path), roundi(reached)]
	changed.emit()


func _show_angles() -> void:
	_quiet = true
	for n: int in mini(_sliders.size(), poser.joints.size()):
		_sliders[n].set_value_no_signal(poser.joints[n].angle)
		_readouts[n].text = "%d°" % roundi(poser.joints[n].angle)
	_quiet = false


func at_rest() -> void:
	for one: Poser.Joint in poser.joints:
		if not is_zero_approx(one.angle):
			poser.settle(one.path, 0.0, one.angle)
	_seen_revision = world.revision
	_show_angles()
	_status.text = "Every joint back where it was when posing began."
	changed.emit()


## Set a joint as a slider let go there does. For a probe and a browser
## check that cannot drag.
func set_angle(path: String, value: float) -> float:
	var one: Poser.Joint = poser.joint(path)
	if one == null:
		return 0.0
	_settle(path, value, one.angle)
	return poser.joint(path).angle


# -- keys and the animation ----------------------------------------------------------


func add_key() -> void:
	if poser.joints.is_empty():
		_status.text = "There is no joint to key: nothing here turns on a hinge or a turntable."
		return
	var t: float = _key_time.value
	animation.add_key(t, poser.angles())
	_key_time.value = t + 1.0
	_fill_keys()
	_status.text = "Key %d at %.1f s. Pose the next one, then Add key again." % [
		animation.keys.size(), t]


func _fill_keys() -> void:
	for child: Node in _keys_box.get_children():
		child.queue_free()
	for n: int in animation.keys.size():
		var key: Dictionary = animation.keys[n]
		var row := HBoxContainer.new()
		_keys_box.add_child(row)
		var words := PackedStringArray()
		var angles: Dictionary = key["angles"]
		for path: Variant in angles:
			words.append("%s %d°" % [Assemblies.label(str(path)), roundi(float(angles[path]))])
		var label := Label.new()
		label.text = "%.1f s — %s" % [float(key["t"]), ", ".join(words)]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		var index: int = n
		var drop := _button(row, "×", func() -> void:
			animation.remove_key(index)
			_fill_keys(), "Take this key out")
		drop.custom_minimum_size = Vector2(24, 0)


func play() -> void:
	if _playing:
		_stop()
		return
	if animation.keys.is_empty():
		_status.text = "Add a key or two first: pose, Add key, pose again, Add key."
		return
	_playing = true
	_play_at = 0.0
	_play.text = "Stop"
	_played = _turnings()
	_played_from = {}


func _stop() -> void:
	_playing = false
	_play.text = "Play"
	# Back as the pose stands: playing moved only what is drawn.
	for brick_id: Variant in _played_from:
		if world.get_brick(int(brick_id)) != null:
			world.move_brick(int(brick_id), _played_from[brick_id])
	_played = {}
	_played_from = {}
	poser.stand(poser.angles())
	_seen_revision = world.revision


## A part on its joint that is not a pose joint, as move_part names it
## ("#14": a steering on its pins, a wheel), keyed by a session: its name ->
## a GrabDrag.Turning, or a String saying why it cannot turn
## (GrabDrag.turning_for_session; main sets it).
var turning_for: Callable
## What Play turns of those, and where each part they moved stood before.
var _played: Dictionary = {}
var _played_from: Dictionary = {}
## What the last render's parts on their joints stopped short of: lines.
var _short: PackedStringArray = PackedStringArray()


## The keys' parts on their joints (not pose joints): name -> Turning.
## Taken afresh each time, on the model as it stands. Kept only for the one
## render, a session's keys stayed in the panel, and Play and Render
## animation then drew a steering keyed to turn standing still.
func _turnings() -> Dictionary:
	var out: Dictionary = {}
	if not turning_for.is_valid():
		return out
	for path: String in animation.paths():
		if poser.joint(path) != null:
			continue
		var turning: Variant = turning_for.call(path)
		if turning is GrabDrag.Turning:
			out[path] = turning
	return out


## Stand the parts as the keys say at [param t]: the pose joints, then the
## parts on their joints Play turns.
func _stand_at(t: float) -> void:
	var angles: Dictionary = animation.angles_at(t)
	poser.stand(angles)
	for path: String in _played:
		var placed: Dictionary = (_played[path] as GrabDrag.Turning).placed_at(
			float(angles.get(path, 0.0)))
		for brick_id: Variant in placed:
			var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
			if brick == null:
				continue
			if not _played_from.has(brick_id):
				_played_from[brick_id] = brick.transform
			world.move_brick(int(brick_id), placed[brick_id])


## What the last render's parts on their joints stopped short of, for a
## session: "#14 stops at 12° of the 30° asked: … meets …".
func short_words() -> PackedStringArray:
	return _short


## Draw every frame and keep them. Returns how many were drawn.
## [param job], from a session (ToolJobs), is the bar along the foot of the
## window that counts the frames, and whose Cancel stops it. [param view] is
## RenderSettings.view: the person's own camera when empty; a session's is
## "hero", framed on the model and what it sweeps, since it cannot see the
## window (SimulatePanel.record_of). Through the window's camera, a session's
## render drew 8808-1 30% of the picture wide, and 2% once the window had
## been zoomed out.
func render_animation(job: Working.Job = null, view: String = "") -> int:
	if _working or world == null:
		return 0
	if animation.keys.is_empty() and not animation.turntable:
		_status.text = "Add a key or two, or tick Turn the model round once, first."
		return 0
	if _playing:
		_stop()
	if renderer == null:
		renderer = StudioRender.new()
		add_child(renderer)
		renderer.progress.connect(func(fraction: float, words: String) -> void:
			_fraction = fraction
			_progress.value = fraction
			if _working:
				_status.text = "%s… %d%%" % [words.substr(0, 1).to_upper() + words.substr(1),
					roundi(fraction * 100.0)])
	renderer.library = library
	renderer.scenery = scenery
	renderer.eye = eye
	renderer.look = look
	renderer.rig_lights = rig_lights
	_working = true
	_set_working(true)
	_last = {}
	var started: int = Time.get_ticks_msec()
	var frames: int = animation.frame_count()
	var poses: Array = []
	var carried: Dictionary = _turnings()
	for n: int in frames:
		var angles: Dictionary = animation.angles_at(animation.time_of(n))
		var placed: Dictionary = poser.transforms_for(angles)
		for path: String in carried:
			placed.merge((carried[path] as GrabDrag.Turning).placed_at(
				float(angles.get(path, 0.0))), true)
		poses.append(placed)
	_short = PackedStringArray()
	for path: String in carried:
		var turning: GrabDrag.Turning = carried[path]
		if not turning.short_words.is_empty():
			_short.append("%s %s" % [path, turning.short_words])
	var chosen: RenderSettings = settings.copy()
	chosen.fps = animation.fps
	chosen.frames = frames
	if not view.is_empty():
		chosen.view = view
	var output := RenderOutput.new()
	output.folder = folder
	var model: String = str(named.call())
	output.begin_turntable(model, chosen, "_animation")
	_sheet = {}
	var sheet_at: Array = _sheet_frames(frames)
	var stop: Callable = renderer.cancel
	if job != null:
		job.count(0, frames)
		job.cancel_wanted.connect(stop)
	var done: int = await renderer.animate(world, chosen, frames,
		func(n: int) -> Dictionary: return poses[n],
		func(n: int) -> float: return animation.turn_at(animation.time_of(n)),
		poser.reach(poses),
		func(n: int, image: Image) -> void:
			_frame.texture = ImageTexture.create_from_image(image)
			_frame.visible = true
			if sheet_at.has(n):
				_sheet[n] = image
			if job != null:
				job.count(n + 1)
			await output.add_frame(n, image))
	await output.settle()
	if job != null:
		job.cancel_wanted.disconnect(stop)
	var lines := PackedStringArray()
	if done == frames:
		_status.text = "Putting the frames together…"
		if job != null:
			job.say(_status.text)
			job.count(0, 0)
		lines = await output.finish_turntable()
	_working = false
	_set_working(false)
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	if lines.is_empty():
		_status.text = "Cancelled." if done < frames else "Nothing was kept."
		_progress.value = 0.0
		return done
	_progress.value = 1.0
	_last = {"frames": done, "bytes": output.last_bytes,
		"name": RenderOutput.file_name(model, "_animation", "webp"),
		"paths": Array(output.paths), "kept": "; ".join(lines), "seconds": roundi(seconds)}
	_status.text = "%d frames — %s — %.0f s." % [done, "; ".join(lines), seconds]
	return done


## A few frames of the last render, frame number -> Image: at its keys, or
## spread over it. A session cannot see the window or play a file, and the
## first that animated 8808-1's steering said it had not watched it.
var _sheet: Dictionary = {}
const SHEET_MOST := 4
const SHEET_WIDE := 480
const SHEET_GAP := 4


## Which frames go in the sheet: each key's, or four spread out when there
## are more keys or none.
func _sheet_frames(frames: int) -> Array:
	var out: Array = []
	if animation.keys.size() >= 2 and animation.keys.size() <= SHEET_MOST:
		for key: Dictionary in animation.keys:
			out.append(clampi(roundi(float(key["t"]) * animation.fps), 0, frames - 1))
	else:
		for n: int in SHEET_MOST:
			out.append(roundi(float(n) * float(frames - 1) / float(SHEET_MOST - 1)))
	return out


## The last render's sheet as one picture, two frames to a row, each at
## most SHEET_WIDE across; null when nothing was drawn. [param times] is
## filled with each frame's time, in order. At half of 480 × 300 a session
## found them "too small to judge", and posed the model again to look.
func sheet(times: Array = []) -> Image:
	if _sheet.is_empty():
		return null
	var numbers: Array = _sheet.keys()
	numbers.sort()
	var first: Image = _sheet[numbers[0]]
	var scale: float = minf(1.0, float(SHEET_WIDE) / float(maxi(first.get_width(), 1)))
	var cell := Vector2i(maxi(roundi(first.get_width() * scale), 1),
		maxi(roundi(first.get_height() * scale), 1))
	var across: int = mini(numbers.size(), 2)
	var rows: int = ceili(float(numbers.size()) / 2.0)
	# A line between the frames: without one, a session read the crane in
	# four frames as one picture of it moving about the frame.
	var step: Vector2i = cell + Vector2i(SHEET_GAP, SHEET_GAP)
	var out := Image.create(step.x * across - SHEET_GAP, step.y * rows - SHEET_GAP, false,
		Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.35, 0.38))
	for k: int in numbers.size():
		var frame: Image = (_sheet[numbers[k]] as Image).duplicate()
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(frame, Rect2i(Vector2i.ZERO, cell), Vector2i((k % 2) * step.x, (k / 2) * step.y))
		times.append(animation.time_of(int(numbers[k])))
	return out


func is_rendering() -> bool:
	return _working


## What the last render said: where it was written, or why nothing was.
func rendered_words() -> String:
	return _status.text


func _set_working(on: bool) -> void:
	_render.disabled = on
	_play.disabled = on
	_add_key.disabled = on
	_cancel.visible = on
	for slider: HSlider in _sliders:
		slider.editable = not on


func _process(delta: float) -> void:
	if not visible:
		return
	# Something else moved the parts — an undo, an edit: read the pose again.
	if not _playing and not _working and _dragging.is_empty() \
			and world.revision != _seen_revision:
		_seen_revision = world.revision
		if not poser.holds():
			var kept: int = poser.joints.size()
			if not poser.read_back():
				poser.find()
			if poser.joints.size() != kept or _sliders.size() != poser.joints.size():
				_fill_joints()
			else:
				_show_angles()
	if _playing:
		_play_at += delta
		_stand_at(minf(_play_at, animation.length()))
		if _play_at >= animation.length() + 0.5:
			_stop()
	_tell_page()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if _working:
			renderer.cancel()
		else:
			close()
		get_viewport().set_input_as_handled()


# -- building ------------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Pose and animate"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button(header, "Close", close, "Back to building (Escape)")
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)
	_empty = Label.new()
	_empty.text = ("Nothing here turns on a joint yet. Make the part that should turn a "
		+ "sub-assembly (Edit, Make sub-assembly), standing on a hinge, a clip or a turntable.")
	_empty.add_theme_font_size_override("font_size", 12)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size = Vector2(280, 0)
	column.add_child(_empty)
	_rest = _button(column, "At rest", at_rest, "Every joint back where it was when posing began")
	column.add_child(HSeparator.new())
	var heading := Label.new()
	heading.text = "Animation"
	heading.add_theme_font_size_override("font_size", 12)
	heading.modulate = Color(1, 1, 1, 0.55)
	column.add_child(heading)
	var keyed := HBoxContainer.new()
	keyed.add_theme_constant_override("separation", 6)
	column.add_child(keyed)
	var at := Label.new()
	at.text = "Key at"
	at.add_theme_font_size_override("font_size", 12)
	keyed.add_child(at)
	_key_time = SpinBox.new()
	_key_time.min_value = 0.0
	_key_time.max_value = 60.0
	_key_time.step = 0.5
	_key_time.suffix = "s"
	_key_time.custom_minimum_size = Vector2(84, 0)
	keyed.add_child(_key_time)
	_add_key = _button(keyed, "Add key", add_key, "Keep every joint's angle at this moment")
	_keys_box = VBoxContainer.new()
	_keys_box.add_theme_constant_override("separation", 2)
	column.add_child(_keys_box)
	var playing := HBoxContainer.new()
	playing.add_theme_constant_override("separation", 6)
	column.add_child(playing)
	_play = _button(playing, "Play", play, "Run it in the window")
	_turntable = CheckBox.new()
	_turntable.text = "Turn the model round once"
	_turntable.add_theme_font_size_override("font_size", 12)
	_turntable.focus_mode = Control.FOCUS_NONE
	_turntable.toggled.connect(func(on: bool) -> void: animation.turntable = on)
	playing.add_child(_turntable)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	column.add_child(choices)
	_rate = OptionButton.new()
	_rate.add_theme_font_size_override("font_size", 12)
	_rate.focus_mode = Control.FOCUS_NONE
	for rate: int in RATES:
		_rate.add_item("%d frames a second" % rate)
	_rate.item_selected.connect(func(index: int) -> void: animation.fps = int(RATES[index]))
	choices.add_child(_rate)
	_size = OptionButton.new()
	_size.add_theme_font_size_override("font_size", 12)
	_size.focus_mode = Control.FOCUS_NONE
	for size: Array in SIZES:
		_size.add_item(str(size[0]))
	_size.item_selected.connect(func(index: int) -> void:
		settings.size = SIZES[index][1])
	choices.add_child(_size)
	var rendering := HBoxContainer.new()
	rendering.add_theme_constant_override("separation", 6)
	column.add_child(rendering)
	_render = _button(rendering, "Render animation", render_animation,
		"Draw every frame and keep them: an animated WebP, and on the desktop the frames and an MP4")
	_cancel = _button(rendering, "Cancel", func() -> void:
		if renderer != null:
			renderer.cancel(), "Stop rendering (Escape)")
	_cancel.visible = false
	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 5)
	column.add_child(_progress)
	_frame = TextureRect.new()
	_frame.custom_minimum_size = Vector2(280, 120)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_frame)
	# The last frame drawn, once a render has drawn one.
	_frame.visible = false
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(280, 0)
	_status.modulate = Color(1, 1, 1, 0.8)
	column.add_child(_status)


func _button(into: Control, words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


# -- for a browser test ---------------------------------------------------------------


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"pose_rest": _rest, "pose_add_key": _add_key, "pose_key_time": _key_time,
		"pose_play": _play, "pose_turntable": _turntable, "pose_rate": _rate, "pose_size": _size,
		"pose_render": _render, "pose_cancel": _cancel, "pose_close": _close}
	for n: int in _sliders.size():
		out["pose_slider_%d" % n] = _sliders[n]
	return out


## What the panel is doing, for a browser test: window.brickworksPose, with
## each slider's ends on the page so a click can set an angle as a person's
## would. Web builds only.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var per_css: float = float(ratio) if ratio != null and float(ratio) > 0.0 else 1.0
	var to_window: Transform2D = get_viewport().get_final_transform()
	var joints: Array = []
	for n: int in poser.joints.size():
		var one: Poser.Joint = poser.joints[n]
		var entry: Dictionary = {"path": one.path, "angle": roundi(one.angle), "kind": one.kind()}
		if n < _sliders.size() and _sliders[n].is_visible_in_tree():
			var rect: Rect2 = to_window * _sliders[n].get_global_rect()
			entry["x0"] = roundi(rect.position.x / per_css)
			entry["x1"] = roundi(rect.end.x / per_css)
			entry["y"] = roundi(rect.get_center().y / per_css)
		joints.append(entry)
	var state: Dictionary = {"open": visible, "joints": joints, "keys": animation.keys.size(),
		"playing": _playing, "working": _working, "fraction": snappedf(_fraction, 0.01),
		"status": _status.text, "frames_planned": animation.frame_count()}
	if renderer != null:
		state["worst_frame_ms"] = roundi(renderer.worst_frame_ms)
		state["worst_step"] = renderer.worst_step
	for key: String in _last:
		state[key] = _last[key]
	var said: String = JSON.stringify(state)
	if said == _told_page:
		return
	_told_page = said
	JavaScriptBridge.eval("window.brickworksPose = %s" % said, true)
