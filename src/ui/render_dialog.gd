## File, Render…: a picture of the model worth keeping, a turntable, an
## animation of one of its motions (docs/MOTIONS.md, "Render"), or the model
## built up step by step (BuildRender).
##
## Studio's Eyesight asks for a quality, a size and a background and then
## shows nothing until it has finished; Mecabricks sends the model to a
## workshop. Here the picture on the left is the render, drawn quickly
## every time a choice changes — the framing, the backdrop, the light, the
## lens — so what comes out is what was looked at, and pressing Render
## only makes it better. The choices are a photographer's: how good, how
## big, on what, lit how, from where and through what lens.
##
## A render runs in pieces a frame at a time (StudioRender), so the app and
## a browser tab answer throughout; the bar says how far it has got, Cancel
## or Escape stops it, and when it is done the picture is downloaded, or
## on the desktop written to Downloads.
##
## Animation plays one of the model's motions, or all of them in order,
## through Grab (MotionRender, the path the Motions panel's Render
## animation and render_motion take too) and keeps every frame, at the
## quality, size, light and lens chosen for a picture: the camera as the
## picture is ("As I see it") or fitted to what the parts sweep through
## the whole motion ("Framed on what moves").
##
## Building is the timeline's steps, each step's parts coming down into
## place, the camera turning slowly round, over 10 to 60 seconds: Studio's
## building animation. Return renders what the choices last touched were
## for, the button drawn strong: a picture until a turntable's frames, a
## motion or a building's length is chosen, so Render, a length and Return
## is a building video.
class_name RenderDialog
extends PanelContainer

signal closed()

var world: BrickWorld
var library: PartLibrary
var scenery: Dictionary = {}
var eye: Camera3D
var look: Environment
var rig_lights: Array[DirectionalLight3D] = []
## The model's name, for the file's.
var named: Callable = func() -> String: return "Model"
## Where desktop files go; Downloads when empty. A probe points it elsewhere.
var folder: String = ""
## The model's motions, played through Grab (main's), for Animation.
var player: MotionPlayer

var settings := RenderSettings.new()
var renderer: StudioRender

const WIDE := 1080.0
const TALL := 680.0
const PREVIEW := Vector2i(600, 400)

const SIZES: Array = [["720p", Vector2i(1280, 720)], ["1080p", Vector2i(1920, 1080)],
	["4K", Vector2i(3840, 2160)], ["Square", Vector2i(1080, 1080)], ["Custom", Vector2i.ZERO]]
## Name, and which of RenderSettings.BACKDROPS: "Colour" takes the
## picker's, "None" is transparent.
const BACKGROUNDS: Array = [["White", "white"], ["Gradient", "gradient"], ["Grey", "grey"],
	["Dark", "dark"], ["Colour", ""], ["None", ""]]
const COLOUR := Color(0.24, 0.42, 0.72)
const STOPS: Array = [["Off", 0.0], ["f/16", 16.0], ["f/8", 8.0], ["f/4", 4.0], ["f/2", 2.0]]
const FRAMES: Array = [24, 36, 48, 72]
## Animation's camera: [words, framed on what moves].
const CAMERAS: Array = [["As I see it", false], ["Framed on what moves", true]]
const SAMPLES: Array = [16, 32, 64, 128]

var _preview: TextureRect
var _shown: Image
var _progress: ProgressBar
var _status: Label
var _quality: Array[Button] = []
var _quality_note: Label
var _looks: Array[Button] = []
var _look_note: Label
var _sizes: Array[Button] = []
var _custom: HBoxContainer
var _width: SpinBox
var _height: SpinBox
var _backgrounds: Array[Button] = []
var _picker: ColorPickerButton
var _light: OptionButton
var _turn: HSlider
var _contact: CheckBox
var _view: OptionButton
var _focal: HSlider
var _focal_words: Label
var _stop: OptionButton
var _focus: HSlider
var _lens_note: Label
var _samples: OptionButton
## A preset: these choices kept by a name, for any model (RenderSettings.presets).
var _preset: OptionButton
var _preset_save: Button
var _preset_remove: Button
var _preset_ask: ConfirmationDialog
var _preset_name: LineEdit
## The preset chosen, as it put these choices: changed since, it is chosen no more.
var _preset_put: Dictionary = {}
## The choices, which scroll: a browser test scrolls one into view as a person does.
var _choices: ScrollContainer
var _frames: Array[Button] = []
var _frames_note: Label
var _motion: OptionButton
var _cameras: Array[Button] = []
var _animation_note: Label
var _lengths: Array[Button] = []
var _building_note: Label
var _picture_button: Button
var _turntable_button: Button
var _animation_button: Button
var _building_button: Button
var _cancel_button: Button
var _again_button: Button
var _close_button: Button

var _background: int = 0
## Animation's camera: fitted to what the parts sweep (RenderSettings.on_what_moves).
var _on_what_moves: bool = false
## Building's length, in seconds.
var _build_seconds: int = 20
## What Return renders: the kind whose choices were touched last.
var _default: String = "picture"
## The steps being worked out for a building, until they are: Cancel stops it.
var _planning: Working.Job = null
## How many of a building's frames the panel plays back when it is done, at
## most, and how fast: its 480 frames at the panel's size would be gigabytes.
const LOOP_MOST := 48
const LOOP_FPS := 12
var _loop_fps: int = 24
var _preview_due: int = -1
var _working: String = ""
var _last: Dictionary = {}
var _loop: Array[ImageTexture] = []
var _loop_at: float = 0.0
var _told_page: String = ""
var _fraction: float = 0.0
var _words: String = ""


func _ready() -> void:
	visible = false
	settings.view = "current"
	_build()
	_add_scrim.call_deferred()
	get_tree().root.window_input.connect(func(_event: InputEvent) -> void:
		_touched_ms = Time.get_ticks_msec())


## When anything last reached the window, and when it last drew a frame: the
## renderer is made ready ahead of time once both are WARM_IDLE_MS ago (see
## [method _warm_when_idle]).
var _touched_ms: int = 0
var _drawn_ms: int = 0
var _drawn_frames: int = -1
var _warm_asked: bool = false
const WARM_IDLE_MS := 3000
## Whether that is done at all: as the app runs, but not in a probe that did
## not ask for it, as IdleDraw leaves a probe be. A probe that counts the
## frames drawn standing still would count its few frames, once.
static var warms_when_idle: bool = not OS.get_cmdline_args().has("--script")


## The renderer made ready the first time nobody has touched the window for a
## few seconds and nothing on it has changed (StudioRender.warm_up): the
## set's viewports, and its two shaders of its own, the sweep's and the
## contact shadow's, drawn once. In a browser their first draw built six
## programs and five in a frame each of Render's first open. Nothing on the
## screen moves while it goes on, anyone who starts using the window
## meanwhile has it wait for them, and it is never done while nobody can see
## the window.
func _warm_when_idle() -> void:
	if _warm_asked or not warms_when_idle:
		return
	var now: int = Time.get_ticks_msec()
	if Engine.get_frames_drawn() != _drawn_frames:
		_drawn_frames = Engine.get_frames_drawn()
		_drawn_ms = now
	if now - _drawn_ms < WARM_IDLE_MS or now - _touched_ms < WARM_IDLE_MS:
		return
	if not StudioRender.possible() or world == null or _nobody_looking():
		return
	_warm_asked = true
	_make_renderer()
	renderer.warm_up(func() -> bool: return Time.get_ticks_msec() - _touched_ms >= WARM_IDLE_MS)


## A dark veil over the window behind the panel, which stops clicks reaching
## the model and lets the window stop drawing it (see [method open]).
var _scrim: ColorRect


func _add_scrim() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	_scrim = ColorRect.new()
	_scrim.color = Color(0.0, 0.0, 0.0, 0.6)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.visible = visible
	parent.add_child(_scrim)
	parent.move_child(_scrim, get_index())


## Whether nobody can see the window, as Main decides it (Main._watch_view):
## its 3D drawing is left off when the panel closes then.
static func _nobody_looking() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("document.hidden", true))
	return DisplayServer.get_name() != "headless" \
		and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED


func open() -> void:
	_make_renderer()
	# The lens the window has, so the view looked at comes out as it is.
	if eye != null and settings.view == "current" and _last.is_empty():
		settings.focal_mm = roundf(RenderSettings.focal_for(eye.fov, settings.size))
		_focal.set_value_no_signal(settings.focal_mm)
	_list_motions()
	# The model's own views, as it keeps them now: another model open, or a
	# view saved again, since the camera was chosen (SavedViews).
	var gone: String = _use_saved_view(settings.saved_view) \
		if not settings.saved_view.is_empty() else ""
	_list_views()
	_list_presets(_chosen_preset())
	# lights (APP_UX5 #7): the model's lights as it keeps them now.
	_list_lamps(0)
	_describe()
	visible = true
	if _scrim != null:
		_scrim.visible = true
	# The window's own model is behind the veil: not drawing it while the
	# panel is up gives the render the whole graphics card. In a browser
	# drawing in software a frame of the window is seconds, and every
	# picture read back waited for it.
	get_viewport().disable_3d = true
	_loop.clear()
	_status.text = "Choose how it should look; the picture is a quick draft of it." \
		if gone.is_empty() else gone
	_progress.value = 0.0
	_ask_preview(0)


func _make_renderer() -> void:
	if renderer == null:
		renderer = StudioRender.new()
		add_child(renderer)
		renderer.progress.connect(_on_progress)
		renderer.piece_done.connect(_on_piece)
	renderer.library = library
	renderer.scenery = scenery
	renderer.eye = eye
	renderer.look = look
	renderer.rig_lights = rig_lights


## Render as Picture or Turntable would, with [param chosen] and without
## the panel: what a session over MCP asks for (AppTools). What was
## written, or why nothing was; [method last_picture] is a picture's image.
## [param job] is the bar along the foot of the window (Working) that says
## how far it has got, in place of the panel's, and whose Cancel stops it:
## the session's job (ToolJobs) reads the same one.
func render_for(kind: String, chosen: RenderSettings, job: Working.Job = null) -> String:
	if is_rendering():
		return "a render is already being drawn"
	_make_renderer()
	_job = job
	if job != null:
		job.cancel_wanted.connect(_cancel)
	var lines: PackedStringArray = await _start(kind, chosen)
	if job != null:
		job.cancel_wanted.disconnect(_cancel)
	_job = null
	return "; ".join(lines) if not lines.is_empty() else _status.text


## The Working job a render from outside reports to, while it lasts.
var _job: Working.Job = null


func last_picture() -> Image:
	return _last.get("image") as Image if _last.get("kind", "") == "picture" else null


func close() -> void:
	if not visible:
		return
	if renderer != null and renderer.is_busy():
		renderer.cancel()
	visible = false
	if _scrim != null:
		_scrim.visible = false
	get_viewport().disable_3d = _nobody_looking()
	_loop.clear()
	closed.emit()


func is_rendering() -> bool:
	return _working in ["picture", "turntable", "animation", "building"]


## Where the render being drawn goes, while it is.
var _output: RenderOutput = null


## The app closing mid-render: a picture already drawn and being encoded is
## written now, the frames of a turntable already drawn are kept, and what
## was not finished is said, in the app's log, rather than lost without a
## word: the render's coroutines go with the scene tree and never come back
## to write anything.
func _exit_tree() -> void:
	if not is_rendering():
		return
	var lines: PackedStringArray = _output.close_now() if _output != null else PackedStringArray()
	if lines.is_empty():
		lines.append("the %s was not finished, so nothing was written" % _working)
	for line: String in lines:
		print("render, as the app closed: %s" % line)


## Escape cancels a render, or closes; every other key stops here while it
## is open, so the model's shortcuts do nothing to a model nobody can see.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if is_rendering():
			_cancel()
		else:
			close()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	# Return after the controls have had it: a size typed into Custom's
	# fields is theirs.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER] \
			and not is_rendering():
		_start(_default)


func _process(delta: float) -> void:
	if not visible:
		_warm_when_idle()
		return
	# Main turns the window's drawing back on when the tab comes back into
	# view, which it does not know is behind the panel.
	if not get_viewport().disable_3d:
		get_viewport().disable_3d = true
	if _preview_due >= 0 and Time.get_ticks_msec() >= _preview_due and _working.is_empty():
		_preview_due = -1
		_draft()
	if not _loop.is_empty() and _working.is_empty():
		_loop_at += delta
		var frame: int = int(_loop_at * float(_loop_fps)) % _loop.size()
		_preview.texture = _loop[frame]
	_tell_page()


# -- building ------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Render"
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	_close_button = _button(header, "Close", close, "Back to the model (Escape)")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	# The picture, and what is happening to it.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var frame := PanelContainer.new()
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.05, 0.055, 0.065)
	well.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", well)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(frame)
	# A checkerboard under the picture, so a transparent one shows as such.
	var checks := TextureRect.new()
	checks.texture = _checkerboard()
	checks.stretch_mode = TextureRect.STRETCH_TILE
	checks.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	checks.modulate = Color(1, 1, 1, 0.0)
	frame.add_child(checks)
	checks.set_meta("checks", true)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(PREVIEW)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_preview)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 6)
	left.add_child(_progress)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.75)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 34)
	left.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	left.add_child(actions)
	_picture_button = _button(actions, "Render picture", func() -> void: _start("picture"),
		"Draw it at the size and quality chosen, and keep it", true)
	_turntable_button = _button(actions, "Render turntable", func() -> void: _start("turntable"),
		"Turn the model round once and keep every frame as an animation")
	_animation_button = _button(actions, "Render animation", func() -> void: _start("animation"),
		"Play the motion chosen under Animation and keep every frame")
	_building_button = _button(actions, "Render building", func() -> void: _start("building"),
		"The model built up step by step, as the timeline builds it, kept as a video")
	_cancel_button = _button(actions, "Cancel", _cancel, "Stop rendering (Escape)")
	_cancel_button.visible = false
	_again_button = _button(actions, "Download again", _again, "")
	_again_button.visible = false

	# The choices.
	var scroll := ScrollContainer.new()
	_choices = scroll
	scroll.custom_minimum_size = Vector2(360, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)

	# savedviews: these choices kept by a name and chosen again in two
	# actions, the list and the name, on any model (RenderSettings.presets).
	_heading(right, "Preset")
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	right.add_child(preset_row)
	_preset = OptionButton.new()
	_preset.add_theme_font_size_override("font_size", 12)
	_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset.tooltip_text = "Choices kept by a name, for any model: choose one to use them all again"
	_preset.item_selected.connect(_choose_preset)
	preset_row.add_child(_preset)
	_preset_save = _button(preset_row, "Save…", _ask_preset_name,
		"Keep these choices by a name, to choose again on any model")
	_preset_remove = _button(preset_row, "Remove", _remove_preset, "Forget the preset chosen")

	_heading(right, "Quality")
	_quality = _segments(right, ["Quick", "Good", "Best"], settings.quality,
		func(n: int) -> void:
			settings.quality = n
			_describe()
			_ask_preview())
	_quality_note = _note(right)
	# Two lines whatever it says, so the rows under it stay put as the
	# grade changes: a browser check clicked where "24" had just been.
	_quality_note.custom_minimum_size.y = 30

	_heading(right, "Look")
	_looks = _segments(right, RenderSettings.LOOKS.values(),
		RenderSettings.LOOKS.keys().find(settings.look), func(n: int) -> void:
			settings.look = str(RenderSettings.LOOKS.keys()[n])
			_describe()
			_ask_preview())
	_look_note = _note(right)
	_look_note.custom_minimum_size.y = 30

	_heading(right, "Size")
	var size_names: Array = []
	for choice: Array in SIZES:
		size_names.append(choice[0])
	_sizes = _segments(right, size_names, 1, _pick_size)
	_custom = HBoxContainer.new()
	_custom.add_theme_constant_override("separation", 6)
	right.add_child(_custom)
	_width = _spin(_custom, 1920)
	var by := Label.new()
	by.text = "×"
	_custom.add_child(by)
	_height = _spin(_custom, 1080)
	_custom.visible = false

	_heading(right, "Background")
	var background_names: Array = []
	for choice: Array in BACKGROUNDS:
		background_names.append(choice[0])
	_backgrounds = _segments(right, background_names, 0, _pick_background)
	_say_white()
	_picker = ColorPickerButton.new()
	_picker.color = COLOUR
	_picker.edit_alpha = false
	_picker.custom_minimum_size = Vector2(0, 26)
	_picker.tooltip_text = "The backdrop's colour"
	_picker.visible = false
	_picker.color_changed.connect(func(colour: Color) -> void:
		settings.backdrop = colour
		_ask_preview())
	right.add_child(_picker)
	_contact = CheckBox.new()
	_contact.text = "Contact shadow under the model"
	_contact.button_pressed = settings.contact_shadow
	_contact.add_theme_font_size_override("font_size", 12)
	_contact.toggled.connect(func(on: bool) -> void:
		settings.contact_shadow = on
		_ask_preview())
	right.add_child(_contact)

	_heading(right, "Light")
	_light = OptionButton.new()
	_light.add_theme_font_size_override("font_size", 12)
	_light.add_item("Three lights, as in the window")
	_light.set_item_metadata(0, "studio")
	for key: String in StudioRender.HDRIS:
		_light.add_item(str(StudioRender.HDRIS[key][0]) + " (photographed)")
		_light.set_item_metadata(_light.item_count - 1, key)
	# lights (APP_UX5 #7): the studio put out, the model's own lights and its
	# glowing plastics all there is.
	_light.add_item("Dark: only the model's own lights")
	_light.set_item_metadata(_light.item_count - 1, "dark")
	_light.item_selected.connect(func(index: int) -> void:
		settings.lighting = str(_light.get_item_metadata(index))
		_show_lamp()
		_ask_preview())
	right.add_child(_light)
	_turn = _slider(right, "Light from", -180.0, 180.0, 0.0, 5.0, func(value: float) -> void:
		settings.light_turn = value
		_ask_preview())
	# lights (APP_UX5 #7): the lights kept with the model.
	_build_lamps(right)

	_heading(right, "Camera")
	_view = OptionButton.new()
	_view.add_theme_font_size_override("font_size", 12)
	_list_views()
	# A view saved with the model (SavedViews) is drawn from exactly there.
	_view.item_selected.connect(func(index: int) -> void:
		var chosen: Variant = _view.get_item_metadata(index)
		if chosen is Dictionary:
			var gone: String = _use_saved_view(str(chosen["saved"]))
			if not gone.is_empty():
				_status.text = gone
				_list_views()
		else:
			settings.forget_eye()
			settings.view = str(chosen)
		_ask_preview())
	right.add_child(_view)
	_focal = _slider(right, "Lens", 18.0, 200.0, settings.focal_mm, 1.0, func(value: float) -> void:
		settings.focal_mm = value
		_describe()
		_ask_preview())
	_focal_words = _note(right)

	_heading(right, "Depth of field")
	var lens_row := HBoxContainer.new()
	lens_row.add_theme_constant_override("separation", 8)
	right.add_child(lens_row)
	_stop = OptionButton.new()
	_stop.add_theme_font_size_override("font_size", 12)
	for choice: Array in STOPS:
		_stop.add_item(str(choice[0]))
	_stop.item_selected.connect(func(index: int) -> void:
		settings.f_stop = float(STOPS[index][1])
		_describe())
	lens_row.add_child(_stop)
	_focus = _slider(right, "Focus, near to far", 0.0, 1.0, settings.focus, 0.01,
		func(value: float) -> void:
			settings.focus = value
			_describe())
	_lens_note = _note(right)

	_heading(right, "Best's frames")
	_samples = OptionButton.new()
	_samples.add_theme_font_size_override("font_size", 12)
	_samples.add_item("As this device does best (%d)" % _platform_samples())
	_samples.set_item_metadata(0, 0)
	for count: int in SAMPLES:
		_samples.add_item("%d frames" % count)
		_samples.set_item_metadata(_samples.item_count - 1, count)
	_samples.item_selected.connect(func(index: int) -> void:
		settings.samples = int(_samples.get_item_metadata(index))
		_describe())
	right.add_child(_samples)

	_heading(right, "Turntable")
	var frame_names: Array = []
	for count: int in FRAMES:
		frame_names.append("%d" % count)
	_frames = _segments(right, frame_names, 1, func(n: int) -> void:
		settings.frames = int(FRAMES[n])
		_make_default("turntable")
		_describe())
	_frames_note = _note(right)

	_heading(right, "Animation")
	_motion = OptionButton.new()
	_motion.add_theme_font_size_override("font_size", 12)
	_motion.item_selected.connect(func(_index: int) -> void:
		_make_default("animation")
		_describe())
	right.add_child(_motion)
	var camera_names: Array = []
	for choice: Array in CAMERAS:
		camera_names.append(choice[0])
	_cameras = _segments(right, camera_names, 0, func(n: int) -> void:
		_on_what_moves = bool(CAMERAS[n][1])
		_make_default("animation")
		_describe())
	_animation_note = _note(right)

	_heading(right, "Building")
	var length_names: Array = []
	for seconds: int in BuildRender.LENGTHS:
		length_names.append("%d s" % seconds)
	_lengths = _segments(right, length_names, BuildRender.LENGTHS.find(_build_seconds),
		func(n: int) -> void:
			_build_seconds = BuildRender.LENGTHS[n]
			_make_default("building")
			_describe())
	_building_note = _note(right)
	_list_presets()


static func _platform_samples() -> int:
	return RenderSettings.best_samples()


func _heading(into: Control, words: String) -> void:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(1, 1, 1, 0.55)
	into.add_child(label)


func _note(into: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.62)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(330, 0)
	into.add_child(label)
	return label


func _button(into: Control, words: String, action: Callable, tip: String,
		strong: bool = false) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_strong(button, strong)
	button.pressed.connect(action)
	into.add_child(button)
	return button


## [param button] drawn as the one Return presses, or as the others.
static func _strong(button: Button, strong: bool) -> void:
	button.add_theme_font_size_override("font_size", 13 if strong else 12)
	if not strong:
		for item: String in ["normal", "hover"]:
			button.remove_theme_stylebox_override(item)
		for item: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.remove_theme_color_override(item)
		return
	var face := StyleBoxFlat.new()
	face.bg_color = Look.STRONG
	face.set_corner_radius_all(4)
	face.content_margin_left = 12
	face.content_margin_right = 12
	face.content_margin_top = 5
	face.content_margin_bottom = 5
	button.add_theme_stylebox_override("normal", face)
	var hover: StyleBoxFlat = face.duplicate()
	hover.bg_color = Look.STRONG_HOVER
	button.add_theme_stylebox_override("hover", hover)
	for item: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(item, Color(1, 1, 1))


## Return renders [param kind] from now on, its button drawn strong.
func _make_default(kind: String) -> void:
	if kind == _default:
		return
	_default = kind
	var buttons: Dictionary = {"picture": _picture_button, "turntable": _turntable_button,
		"animation": _animation_button, "building": _building_button}
	for each: String in buttons:
		_strong(buttons[each], each == kind)


## "White" as a backdrop, in its own words: not LDraw's colour of that
## name, which every language keeps as it is (Language).
func _say_white() -> void:
	var white: Button = _backgrounds[0]
	white.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	white.text = tr("White", "backdrop")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _backgrounds.is_empty():
		_say_white()
	# lights (APP_UX5 #7): Which's rows are words made through tr().
	if what == NOTIFICATION_TRANSLATION_CHANGED and _lamp != null:
		_list_lamps(_lamp.selected)


## A row of buttons of which one is down.
func _segments(into: Control, names: Array, chosen: int, picked: Callable) -> Array[Button]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	into.add_child(row)
	var group := ButtonGroup.new()
	var out: Array[Button] = []
	for n: int in names.size():
		var button := Button.new()
		button.text = str(names[n])
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = n == chosen
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var down := StyleBoxFlat.new()
		down.bg_color = Look.CHOSEN
		down.set_corner_radius_all(3)
		down.content_margin_top = 3
		down.content_margin_bottom = 3
		button.add_theme_stylebox_override("pressed", down)
		button.pressed.connect(func() -> void: picked.call(n))
		row.add_child(button)
		out.append(button)
	return out


func _slider(into: Control, words: String, low: float, high: float, value: float,
		step: float, moved: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	into.add_child(row)
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", 12)
	label.custom_minimum_size = Vector2(118, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.accessibility_name = words
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	# The whole track, not only the part left of the handle: on this dark
	# panel the rest was invisible, and a slider at its middle read as one
	# at its end.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)
	slider.value_changed.connect(moved)
	row.add_child(slider)
	return slider


func _spin(into: Control, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 64
	spin.max_value = 8192
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size = Vector2(96, 0)
	spin.value_changed.connect(func(_v: float) -> void:
		settings.size = Vector2i(int(_width.value), int(_height.value))
		_describe()
		_ask_preview())
	into.add_child(spin)
	return spin


static func _checkerboard() -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y: int in 16:
		for x: int in 16:
			var light: bool = (x < 8) == (y < 8)
			image.set_pixel(x, y, Color(0.42, 0.42, 0.44) if light else Color(0.3, 0.3, 0.32))
	return ImageTexture.create_from_image(image)


# -- choices -------------------------------------------------------------------


func _pick_size(n: int) -> void:
	var wanted: Vector2i = SIZES[n][1]
	_custom.visible = wanted == Vector2i.ZERO
	if wanted == Vector2i.ZERO:
		wanted = Vector2i(int(_width.value), int(_height.value))
	else:
		_width.set_value_no_signal(wanted.x)
		_height.set_value_no_signal(wanted.y)
	settings.size = wanted
	_describe()
	_ask_preview()


func _pick_background(n: int) -> void:
	_background = n
	_picker.visible = BACKGROUNDS[n][0] == "Colour"
	if not settings.use_backdrop(str(BACKGROUNDS[n][1])):
		settings.backdrop = _picker.color if _picker.visible else Color(1, 1, 1)
		settings.backdrop_gradient = false
	settings.transparent = BACKGROUNDS[n][0] == "None"
	for child: Node in _preview.get_parent().get_children():
		if child.has_meta("checks"):
			(child as CanvasItem).modulate = Color(1, 1, 1, 1.0 if settings.transparent else 0.0)
	_ask_preview()


## The model's motions to choose from, the one chosen kept when it is still
## there; "All, in order" when there are two or more.
func _list_motions() -> void:
	var was: String = chosen_motion()
	_motion.clear()
	var motions: Motions = player.motions() if player != null and world != null else null
	var names: Array = []
	for motion: Motions.Motion in motions.list if motions != null else []:
		names.append(motion.name)
	if names.size() > 1:
		names.append(MotionRender.ALL)
	for name: String in names:
		_motion.add_item(name)
		_motion.set_item_metadata(_motion.item_count - 1, name)
		if name == was:
			_motion.select(_motion.item_count - 1)
	if names.is_empty():
		_motion.add_item("No motions yet: Build, Motions… makes them")
		_motion.set_item_metadata(0, "")
	_motion.disabled = names.is_empty() or is_rendering()
	_animation_button.disabled = names.is_empty() or is_rendering()


## The motion Animation draws, by name: MotionRender.ALL for every one in
## order, "" for none.
func chosen_motion() -> String:
	if _motion == null or _motion.selected < 0:
		return ""
	return str(_motion.get_item_metadata(_motion.selected))


## What the choices come to, in words: what each grade does here, what the
## lens is, what the turntable and the animation are.
func _describe() -> void:
	_preset_kept()
	var full: bool = StudioRender.full_renderer()
	match settings.quality:
		RenderSettings.Quality.QUICK:
			_quality_note.text = "The window's own look, at the size you ask for. A moment."
		RenderSettings.Quality.GOOD:
			if full:
				_quality_note.text = ("Light bounced off the backdrop and between the parts, "
					+ "shading in every corner, and a soft shadow that widens with distance.")
			elif GraphicsMode.simpler():
				_quality_note.text = ("Soft shadows and smooth edges, from 8 frames averaged. "
					+ "Light bouncing between the parts needs the full graphics mode.")
			else:
				_quality_note.text = ("Soft shadows and smooth edges, from 8 frames averaged. "
					+ "Light bouncing between the parts needs the desktop app.")
		_:
			_quality_note.text = settings.best_words()
	_look_note.text = ("Glossy plastic with rounded edges, clear parts that bend the light, "
		+ "and a studio's key, fill and rim, as a set's own pictures are."
		if settings.look == "product" else "The plastic and the light as the window draws them.")
	var fov: float = settings.fov_degrees()
	var kind: String = "wide" if settings.focal_mm < 35.0 else (
		"normal" if settings.focal_mm < 70.0 else "long, flattening")
	_focal_words.text = "%d mm on a full-frame camera: %s, %.0f° tall." % [
		roundi(settings.focal_mm), kind, fov]
	if settings.f_stop <= 0.0:
		_lens_note.text = "Everything sharp."
	elif settings.quality != RenderSettings.Quality.BEST:
		_lens_note.text = "Blur comes with Best, which looks through every part of the lens."
	else:
		_lens_note.text = "At f/%d, sharp %d%% of the way back, and softer either side." % [
			roundi(settings.f_stop), roundi(settings.focus * 100.0)]
	var seconds: float = float(settings.frames) / float(settings.fps)
	_frames_note.text = "%d frames, %.1f s at %d a second, as an animated WebP%s." % [
		settings.frames, seconds, settings.fps,
		"" if OS.has_feature("web") else ", the frames, and an MP4 where ffmpeg is installed"]
	var parts: int = world.brick_count() - scenery.size() if world != null else 0
	_building_note.text = ("%s parts as the timeline builds them, step by step, over %d s at %d a "
		+ "second, the camera turning %d° round, as an animated WebP%s.") % [Working.comma(parts),
		_build_seconds, settings.fps, roundi(_build_seconds * BuildRender.TURNING),
		"" if OS.has_feature("web") else ", the frames, and an MP4 where ffmpeg is installed"]
	var order: Array = _order_of(chosen_motion())
	if order.is_empty():
		_animation_note.text = "A motion is a named movement of the model's joints: Build, Motions… keeps them."
		return
	var length: float = 0.0
	for motion: Motions.Motion in order:
		length += motion.length()
	_animation_note.text = "%s: %.1f s at %d a second, %s, as an animated WebP%s." % [
		chosen_motion(), length, settings.fps,
		"framed on what its parts sweep through" if _on_what_moves else "the camera as the picture is",
		"" if OS.has_feature("web") else ", the frames, and an MP4 where ffmpeg is installed"]


## The motions [param name] plays, in order.
func _order_of(name: String) -> Array:
	if player == null or world == null or name.is_empty():
		return []
	var motions: Motions = player.motions()
	if name == MotionRender.ALL:
		return motions.in_order()
	return [motions.named(name)] if motions.named(name) != null else []


# -- the camera from a saved view, and presets (savedviews, APP_UX5 #8) ------------


## The Camera's rows: Render's own views, then the model's saved ones by name
## (SavedViews), the one these settings name chosen.
func _list_views() -> void:
	_view.clear()
	for key: String in StudioRender.VIEWS:
		_view.add_item(str(StudioRender.VIEWS[key][0]))
		_view.set_item_metadata(_view.item_count - 1, key)
	var views: Array = world.saved_views if world != null else []
	if not views.is_empty():
		_view.add_separator("Saved with the model")
	for name: String in SavedViews.names(views):
		_view.add_item("“%s”" % name)
		_view.set_item_metadata(_view.item_count - 1, {"saved": name})
	var wanted: Variant = {"saved": settings.saved_view} if not settings.saved_view.is_empty() \
		else settings.view
	for n: int in _view.item_count:
		# Render's own views are words, the model's a {"saved": name}: two
		# kinds, which == will not compare.
		var meta: Variant = _view.get_item_metadata(n)
		if not _view.is_item_separator(n) and typeof(meta) == typeof(wanted) and meta == wanted:
			_view.select(n)


## Draw from the view saved with the model as [param name], as the window
## looks from it now. Why not, in words, when the model keeps none of that
## name: the camera is then Render's three-quarter view again.
func _use_saved_view(name: String) -> String:
	var views: Array = world.saved_views if world != null else []
	var at: int = SavedViews.index_of(views, name)
	if at >= 0:
		settings.keep_view(views[at], eye)
		return ""
	settings.forget_eye()
	settings.view = "hero"
	return "This model keeps no view called “%s”, so the camera is Three-quarter, like the box." % name


## A picture from the view saved with the model as [param name] (SavedViews),
## as the window draws it, at [param size], kept nowhere: view_model's view=
## (Assistant). Why not, in words, when there is none to draw.
func picture_of_view(name: String, size: Vector2i) -> Variant:
	var views: Array = world.saved_views if world != null else []
	var at: int = SavedViews.index_of(views, name)
	if at < 0:
		return SavedViews.not_kept(views, name)
	if world.brick_count() - scenery.size() <= 0:
		return "There is nothing on the baseplate to look at yet."
	if not StudioRender.possible():
		return ("Looking from a saved view needs something to draw with, and this app is "
			+ "running without a window. Start it in one (godot --path . -- --mcp).")
	if is_rendering():
		return "Render is drawing; ask again once it has finished."
	_make_renderer()
	while renderer.is_busy():
		await get_tree().process_frame
	var chosen := RenderSettings.new()
	chosen.quality = RenderSettings.Quality.QUICK
	chosen.size = size
	# The window's own lens, so the picture is the window's from there.
	chosen.focal_mm = RenderSettings.focal_for(eye.fov, size) if eye != null else 50.0
	chosen.keep_view(views[at], eye)
	return await renderer.render(world, chosen)


## The Preset's rows: none chosen, then each kept, [param chosen] chosen.
func _list_presets(chosen: String = "") -> void:
	_preset.clear()
	_preset.add_item("Your own choices")
	_preset.set_item_metadata(0, "")
	var kept: Dictionary = RenderSettings.presets()
	for name: String in kept:
		Language.keep_name(name)
		_preset.add_item(name)
		_preset.set_item_metadata(_preset.item_count - 1, name)
		if name == chosen:
			_preset.select(_preset.item_count - 1)
	if chosen.is_empty() or not kept.has(chosen):
		_preset.select(0)
		_preset_put = {}
	_preset_remove.disabled = _preset.selected <= 0


func _chosen_preset() -> String:
	return str(_preset.get_item_metadata(_preset.selected)) if _preset.selected >= 0 else ""


## Every choice the preset [param index] keeps, put on these settings and
## shown: the second of the two actions that choose one again.
func _choose_preset(index: int) -> void:
	var name: String = str(_preset.get_item_metadata(index))
	_preset_remove.disabled = name.is_empty()
	if name.is_empty():
		_preset_put = {}
		return
	var kept: Dictionary = RenderSettings.presets()
	if not kept.has(name):
		_list_presets()
		return
	settings.use_preset(kept[name])
	var gone: String = _use_saved_view(settings.saved_view) \
		if not settings.saved_view.is_empty() else ""
	_show_choices()
	_preset_put = settings.preset()
	_describe()
	_ask_preview(0)
	_status.text = "The preset “%s”.%s" % [name, "" if gone.is_empty() else " " + gone]


## A choice changed by hand since the preset was chosen: none is chosen now.
func _preset_kept() -> void:
	if _preset == null or _preset_put.is_empty() or settings.preset() == _preset_put:
		return
	_preset_put = {}
	_preset.select(0)
	_preset_remove.disabled = true


func _ask_preset_name() -> void:
	if _preset_ask == null:
		_preset_ask = ConfirmationDialog.new()
		_preset_ask.title = "Save the preset"
		_preset_ask.ok_button_text = "Save"
		var column := VBoxContainer.new()
		var asking := Label.new()
		asking.text = "What should these choices be called?"
		column.add_child(asking)
		_preset_name = LineEdit.new()
		_preset_name.accessibility_name = "Name of the preset"
		_preset_name.custom_minimum_size = Vector2(320, 0)
		_preset_name.max_length = SavedViews.LONGEST
		_preset_name.text_submitted.connect(func(_text: String) -> void:
			_preset_ask.hide()
			save_preset(_preset_name.text))
		column.add_child(_preset_name)
		_preset_ask.add_child(column)
		_preset_ask.confirmed.connect(func() -> void: save_preset(_preset_name.text))
		add_child(_preset_ask)
	var chosen: String = _chosen_preset()
	_preset_name.text = chosen if not chosen.is_empty() \
		else tr("Preset %d") % (RenderSettings.presets().size() + 1)
	_preset_ask.popup_centered()
	_preset_name.grab_focus()
	_preset_name.select_all()


## These choices kept as the preset [param name], over one of that name, and
## chosen. What was said.
func save_preset(name: String) -> String:
	var called: String = SavedViews.clean_name(name)
	var wrong: String = RenderSettings.save_preset(called, settings)
	if not wrong.is_empty():
		_status.text = wrong.left(1).to_upper() + wrong.substr(1) + "."
		return _status.text
	_list_presets(called)
	_preset_put = settings.preset()
	_status.text = "Kept these choices as the preset “%s”, for any model." % called
	return _status.text


func _remove_preset() -> void:
	var name: String = _chosen_preset()
	if name.is_empty():
		return
	RenderSettings.forget_preset(name)
	_list_presets()
	_status.text = "Forgot the preset “%s”." % name


## Every control as these settings have it, as a preset leaves them.
func _show_choices() -> void:
	for n: int in _quality.size():
		_quality[n].set_pressed_no_signal(n == settings.quality)
	var look_at: int = RenderSettings.LOOKS.keys().find(settings.look)
	for n: int in _looks.size():
		_looks[n].set_pressed_no_signal(n == look_at)
	var size_at: int = SIZES.size() - 1
	for n: int in SIZES.size() - 1:
		if SIZES[n][1] == settings.size:
			size_at = n
	for n: int in _sizes.size():
		_sizes[n].set_pressed_no_signal(n == size_at)
	_custom.visible = size_at == SIZES.size() - 1
	_width.set_value_no_signal(settings.size.x)
	_height.set_value_no_signal(settings.size.y)
	# The backdrop: one of those named, a colour of its own, or none.
	var background: int = 4
	if settings.transparent:
		background = 5
	else:
		for n: int in 4:
			var named: Array = RenderSettings.BACKDROPS[str(BACKGROUNDS[n][1])]
			if settings.backdrop.is_equal_approx(named[0]) \
					and settings.backdrop_gradient == bool(named[1]):
				background = n
				break
	_background = background
	for n: int in _backgrounds.size():
		_backgrounds[n].set_pressed_no_signal(n == background)
	_picker.visible = background == 4
	if background == 4:
		_picker.color = settings.backdrop
	for child: Node in _preview.get_parent().get_children():
		if child.has_meta("checks"):
			(child as CanvasItem).modulate = Color(1, 1, 1, 1.0 if settings.transparent else 0.0)
	_contact.set_pressed_no_signal(settings.contact_shadow)
	for n: int in _light.item_count:
		if str(_light.get_item_metadata(n)) == settings.lighting:
			_light.select(n)
	_turn.set_value_no_signal(settings.light_turn)
	_show_lamp()
	_list_views()
	_focal.set_value_no_signal(settings.focal_mm)
	var stop_at: int = 0
	for n: int in STOPS.size():
		if absf(float(STOPS[n][1]) - settings.f_stop) \
				< absf(float(STOPS[stop_at][1]) - settings.f_stop):
			stop_at = n
	_stop.select(stop_at)
	_focus.set_value_no_signal(settings.focus)
	var samples_at: int = -1
	for n: int in _samples.item_count:
		if int(_samples.get_item_metadata(n)) == settings.samples:
			samples_at = n
	if samples_at < 0:
		_samples.add_item("%d frames" % settings.samples)
		samples_at = _samples.item_count - 1
		_samples.set_item_metadata(samples_at, settings.samples)
	_samples.select(samples_at)
	var frames_at: int = FRAMES.find(settings.frames)
	for n: int in _frames.size():
		_frames[n].set_pressed_no_signal(n == frames_at)


# -- drawing ---------------------------------------------------------------------


## Draw the draft again, in a moment: choices come in runs (a slider
## dragged), and only the last is worth drawing.
func _ask_preview(after_ms: int = 220) -> void:
	_preset_kept()
	_loop.clear()
	_preview_due = Time.get_ticks_msec() + after_ms


func _draft() -> void:
	if world == null or renderer == null or not visible:
		return
	if world.brick_count() - scenery.size() <= 0:
		_status.text = "There is nothing on the baseplate to render yet."
		return
	_working = "draft"
	var draft: RenderSettings = settings.copy()
	draft.quality = RenderSettings.Quality.QUICK
	var aspect: float = float(settings.size.x) / float(maxi(settings.size.y, 1))
	var wide: int = PREVIEW.x
	var tall: int = roundi(float(wide) / aspect)
	if tall > PREVIEW.y:
		tall = PREVIEW.y
		wide = roundi(float(tall) * aspect)
	draft.size = Vector2i(maxi(wide, 16), maxi(tall, 16))
	var image: Image = await renderer.render(world, draft)
	_working = ""
	if image != null and visible:
		_show(image)
		if _status.text.begins_with("setting up") or _status.text.is_empty():
			_status.text = "A quick draft. Render draws it properly."
	_progress.value = 0.0


func _show(image: Image) -> void:
	_shown = image
	_preview.texture = ImageTexture.create_from_image(image)


func _start(kind: String, given: RenderSettings = null) -> PackedStringArray:
	if world == null or is_rendering():
		return PackedStringArray()
	if world.brick_count() - scenery.size() <= 0:
		_status.text = "There is nothing on the baseplate to render yet."
		return PackedStringArray()
	if kind == "animation":
		_list_motions()
	if kind == "animation" and _order_of(chosen_motion()).is_empty():
		_status.text = "Keep a motion first: Build, Motions… makes them."
		return PackedStringArray()
	if renderer.is_busy():
		renderer.cancel()
		while renderer.is_busy():
			await get_tree().process_frame
	# Cancelled from outside while the draft stopped: the renderer, not yet
	# busy with this, would not have heard it.
	if _job != null and _job.cancelled:
		return PackedStringArray()
	_working = kind
	_preview_due = -1
	_loop.clear()
	_loop_fps = settings.fps
	_set_working(true)
	var started: int = Time.get_ticks_msec()
	var chosen: RenderSettings = given if given != null else settings.copy()
	var output := RenderOutput.new()
	output.folder = folder
	_output = output
	var model: String = str(named.call())
	var lines := PackedStringArray()
	if kind == "animation":
		lines = await _animate(chosen, output, model)
	elif kind == "building":
		if given == null:
			chosen.frames = _build_seconds * chosen.fps
		lines = await _building(chosen, output, model)
	elif kind == "picture":
		_shown = null
		var image: Image = await renderer.render(world, chosen)
		if image != null:
			_show_scaled(image)
			_status.text = "Saving…"
			lines.append(await output.keep_picture(image, model))
			_last = {"kind": "picture", "width": image.get_width(),
				"height": image.get_height(), "bytes": output.last_bytes,
				"name": RenderOutput.file_name(model, "_render", "png"), "output": output,
				"image": image}
	else:
		output.begin_turntable(model, chosen)
		var looped: Array[ImageTexture] = []
		if _job != null:
			_job.count(0, chosen.frames)
		var done: int = await renderer.turntable(world, chosen,
			func(n: int, image: Image) -> void:
				_show_scaled(image)
				looped.append(_preview.texture as ImageTexture)
				if _job != null:
					_job.count(n + 1)
				await output.add_frame(n, image))
		await output.settle()
		if done == chosen.frames:
			_status.text = "Putting the frames together…"
			if _job != null:
				_job.say(_status.text)
				_job.count(0, 0)
			lines.append_array(await output.finish_turntable())
			_loop = looped
			_loop_at = 0.0
			_last = {"kind": "turntable", "frames": done, "bytes": output.last_bytes,
				"width": chosen.size.x, "height": chosen.size.y,
				"name": RenderOutput.file_name(model, "_turntable", "webp"), "output": output}
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	_working = ""
	_output = null
	_set_working(false)
	if lines.is_empty():
		_status.text = "Cancelled." if not (_status.text.begins_with("could not")
			or _status.text.begins_with("Nothing to draw")) else _status.text
		_progress.value = 0.0
		return lines
	_progress.value = 1.0
	_status.text = "%s — %.0f s." % ["; ".join(lines), seconds]
	_again_button.visible = true
	_again_button.text = "Download again" if OS.has_feature("web") else "Show in folder"
	return lines


## Animation: the chosen motion, or all in order, played through Grab and
## drawn a frame at a time as [param chosen] says, kept by [param output]
## (MotionRender, as the Motions panel and render_motion draw one). The
## lines to show; none when cancelled or there was nothing to play.
func _animate(chosen: RenderSettings, output: RenderOutput, model: String) -> PackedStringArray:
	var name: String = chosen_motion()
	var order: Array = _order_of(name)
	var drawn: MotionRender = MotionRender.frames_of(player, order, false, chosen.fps)
	if drawn.poses.is_empty():
		_status.text = "Nothing to draw: %s" % "; ".join(drawn.lines)
		return PackedStringArray()
	chosen.frames = drawn.poses.size()
	chosen.on_what_moves = _on_what_moves
	output.begin_animation(model, "all in order" if name == MotionRender.ALL else name, chosen)
	var looped: Array[ImageTexture] = []
	if _job != null:
		_job.count(0, chosen.frames)
	var done: int = await MotionRender.draw(renderer, world, chosen, drawn.poses,
		func(_n: int) -> float: return 0.0, output,
		func(n: int, image: Image) -> void:
			_show_scaled(image)
			looped.append(_preview.texture as ImageTexture)
			if _job != null:
				_job.count(n + 1))
	if done < chosen.frames:
		return PackedStringArray()
	_status.text = "Putting the frames together…"
	if _job != null:
		_job.say(_status.text)
		_job.count(0, 0)
	var lines: PackedStringArray = await output.finish_turntable()
	_loop = looped
	_loop_at = 0.0
	_last = {"kind": "animation", "frames": done, "bytes": output.last_bytes,
		"width": chosen.size.x, "height": chosen.size.y, "motion": name,
		"name": output.base_name() + ".webp", "output": output}
	return lines


## Building: the timeline's steps worked out (BuildRender), then drawn a
## frame at a time as [param chosen] says, its frames' count the length,
## kept by [param output]. The lines to show; none when cancelled.
func _building(chosen: RenderSettings, output: RenderOutput, model: String) -> PackedStringArray:
	_status.text = "Laying out the steps…"
	var planning: Working.Job = _job if _job != null else Working.Job.new()
	_planning = planning
	planning.can_cancel = true
	planning.say(_status.text)
	var built: BuildRender = await BuildRender.planned(world, library, scenery, planning)
	_planning = null
	if built == null:
		return PackedStringArray()
	built.lay_out(float(chosen.frames) / float(maxi(chosen.fps, 1)), chosen.fps,
		BuildRender.height_of(world, library, built.order))
	chosen.frames = built.frames
	# The contact shadow is the finished model's: under a model half built
	# it is the shadow of what is not there yet.
	chosen.contact_shadow = false
	output.begin_turntable(model, chosen, "_building")
	var looped: Array[ImageTexture] = []
	var every: int = ceili(float(built.frames) / float(LOOP_MOST))
	if _job != null:
		_job.say("Rendering the building")
		_job.count(0, built.frames)
	var done: int = await built.draw(renderer, world, chosen, output,
		func(n: int, image: Image) -> void:
			_show_scaled(image)
			if n % every == 0 or n == built.frames - 1:
				var small: Image = image.duplicate() as Image
				small.resize(PREVIEW.x, maxi(roundi(float(PREVIEW.x) * image.get_height() / image.get_width()), 1),
					Image.INTERPOLATE_BILINEAR)
				looped.append(ImageTexture.create_from_image(small))
			if _job != null:
				_job.count(n + 1))
	if done < built.frames:
		return PackedStringArray()
	_status.text = "Putting the frames together…"
	if _job != null:
		_job.say(_status.text)
		_job.count(0, 0)
	var lines: PackedStringArray = [built.said(chosen.fps)]
	lines.append_array(await output.finish_turntable())
	_loop = looped
	_loop_at = 0.0
	_loop_fps = LOOP_FPS
	_last = {"kind": "building", "frames": done, "bytes": output.last_bytes,
		"width": chosen.size.x, "height": chosen.size.y, "parts": built.order.size(),
		"steps": built.steps, "name": output.base_name() + ".webp", "output": output,
		"build": built}
	return lines


## A picture far bigger than the panel, shrunk to it: an 8-megapixel
## texture for a 600-pixel panel is memory and an upload for nothing.
func _show_scaled(image: Image) -> void:
	var copy: Image = image
	if image.get_width() > PREVIEW.x * 2:
		copy = image.duplicate() as Image
		var scale: float = float(PREVIEW.x * 2) / float(image.get_width())
		copy.resize(PREVIEW.x * 2, maxi(roundi(float(image.get_height()) * scale), 1),
			Image.INTERPOLATE_BILINEAR)
	_show(copy)


func _set_working(on: bool) -> void:
	_picture_button.disabled = on
	_turntable_button.disabled = on
	_building_button.disabled = on
	_cancel_button.visible = on
	_again_button.visible = false if on else _again_button.visible
	for button: Button in _quality + _sizes + _backgrounds + _frames + _cameras + _lengths:
		button.disabled = on
	_list_motions()


func _cancel() -> void:
	if _planning != null:
		_planning.cancelled = true
		_status.text = "Cancelling…"
	if renderer != null and renderer.is_busy():
		renderer.cancel()
		_status.text = "Cancelling…"


func _again() -> void:
	if _last.is_empty():
		return
	var output: RenderOutput = _last.get("output")
	if OS.has_feature("web"):
		if _last["kind"] == "picture":
			_status.text = await output.keep_picture(_last["image"], str(named.call()))
		else:
			_status.text = "The %s was downloaded as %s." % [_last["kind"], _last["name"]]
		return
	if output != null and not output.paths.is_empty():
		Outside.show_in_folder(output.paths[output.paths.size() - 1])


func _on_progress(fraction: float, words: String) -> void:
	if not is_rendering():
		if words.begins_with("setting up"):
			_status.text = "%s…" % words
		return
	_fraction = fraction
	_words = words
	_progress.value = fraction
	# A picture from outside is counted on the bar in per cent; a turntable
	# in frames, as each is kept (_start).
	if _job != null and _working == "picture":
		_job.percent = true
		_job.count(roundi(fraction * 100.0), 100)
	var said: String = words.substr(0, 1).to_upper() + words.substr(1)
	_status.text = "%s… %d%%" % [said, roundi(fraction * 100.0)]


## A finished piece of a picture drawn in pieces, shown as it comes.
func _on_piece(piece: Image, at: Vector2i) -> void:
	if _working != "picture" or (piece.get_width() >= settings.size.x
			and piece.get_height() >= settings.size.y):
		return
	var scale: float = float(PREVIEW.x * 2) / float(maxi(settings.size.x, 1))
	if _shown == null or _shown.get_width() != PREVIEW.x * 2:
		_shown = Image.create(PREVIEW.x * 2, maxi(roundi(float(settings.size.y) * scale), 1),
			false, Image.FORMAT_RGBA8)
	var small: Image = piece.duplicate() as Image
	small.convert(Image.FORMAT_RGBA8)
	small.resize(maxi(roundi(float(piece.get_width()) * scale), 1),
		maxi(roundi(float(piece.get_height()) * scale), 1), Image.INTERPOLATE_BILINEAR)
	_shown.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()),
		Vector2i(roundi(float(at.x) * scale), roundi(float(at.y) * scale)))
	_preview.texture = ImageTexture.create_from_image(_shown)


# -- for a browser test ------------------------------------------------------------


## Where each control is, for a browser test to press it as a person does.
func controls_by_name() -> Dictionary:
	var named_controls: Dictionary = {}
	for n: int in _quality.size():
		named_controls["render_" + _quality[n].text.to_lower()] = _quality[n]
	for n: int in _sizes.size():
		named_controls["render_size_" + _sizes[n].text.to_lower()] = _sizes[n]
	for n: int in _backgrounds.size():
		named_controls["render_bg_" + str(BACKGROUNDS[n][0]).to_lower()] = _backgrounds[n]
	for n: int in _looks.size():
		named_controls["render_look_" + str(RenderSettings.LOOKS.keys()[n])] = _looks[n]
	for n: int in _frames.size():
		named_controls["render_frames_" + _frames[n].text] = _frames[n]
	for n: int in _lengths.size():
		named_controls["render_length_%d" % BuildRender.LENGTHS[n]] = _lengths[n]
	named_controls["render_building"] = _building_button
	named_controls["render_camera_seen"] = _cameras[0]
	named_controls["render_camera_moves"] = _cameras[1]
	named_controls["render_picture"] = _picture_button
	named_controls["render_turntable"] = _turntable_button
	named_controls["render_animation"] = _animation_button
	named_controls["render_motion"] = _motion
	named_controls["render_cancel"] = _cancel_button
	named_controls["render_again"] = _again_button
	named_controls["render_close"] = _close_button
	named_controls["render_light"] = _light
	named_controls["render_view"] = _view
	named_controls["render_preset"] = _preset
	named_controls["render_preset_save"] = _preset_save
	named_controls["render_preset_remove"] = _preset_remove
	named_controls["render_choices"] = _choices
	# lights (APP_UX5 #7).
	named_controls["render_lamp"] = _lamp
	named_controls["render_lamp_colour"] = _lamp_colour
	named_controls["render_lamp_remove"] = _lamp_remove
	named_controls["render_lamp_strength"] = _lamp_strength
	named_controls["render_lamp_cone"] = _lamp_cone
	named_controls["render_lamp_size"] = _lamp_size
	named_controls["render_lamp_shadows"] = _lamp_shadows
	named_controls["render_lamp_from_eye"] = _lamp_from_eye
	named_controls["render_lamp_over"] = _lamp_over
	for n: int in SceneLights.KINDS.size():
		named_controls["render_lamp_add_" + SceneLights.KINDS[n]] = _lamp_adds[n]
	return named_controls


## What the render is doing, for a browser test to wait on:
## window.brickworksRender. Web builds only, when it changes.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var state: Dictionary = {"open": visible, "working": _working,
		"fraction": snappedf(_fraction, 0.01), "words": _words,
		"status": _status.text}
	if renderer != null:
		state["worst_frame_ms"] = roundi(renderer.worst_frame_ms)
		state["worst_step"] = renderer.worst_step
	for key: String in ["kind", "width", "height", "bytes", "name", "frames", "motion", "parts", "steps"]:
		if _last.has(key):
			state[key] = _last[key]
	var said: String = JSON.stringify(state)
	if said == _told_page:
		return
	_told_page = said
	JavaScriptBridge.eval("window.brickworksRender = %s" % said, true)


# -- the model's own lights (lights, APP_UX5 #7) ---------------------------------

## What Render's Lights in the model changes the model through, main's: a
## change to be kept (ModelStore.touch, which the autosave and the title's
## dot hear), whether the model may be changed now (not one shared to look
## at), and the box a new light is set over: the selection's, or what is
## built when nothing is selected.
var lights_changed: Callable = func() -> void: pass
var may_change: Callable = func() -> bool: return true
var chosen_box: Callable = func() -> AABB: return AABB()
var _lamp: OptionButton
var _lamp_colour: ColorPickerButton
var _lamp_remove: Button
var _lamp_rows: VBoxContainer
var _lamp_strength: HSlider
var _lamp_cone: HSlider
var _lamp_size: HSlider
var _lamp_shadows: CheckBox
var _lamp_from_eye: Button
var _lamp_over: Button
var _lamp_adds: Array[Button] = []
var _lamp_note: Label


## Lights in the model: which light, its colour and Remove; its strength,
## a spot's cone and a bulb's or a panel's size; its shadows, and where it
## is: from where the window looks, or hung over the selection; and Add, a
## light of each kind set over the selection as a photographer first sets
## one (SceneLights.made). Every change is the model's, kept with it.
func _build_lamps(into: Control) -> void:
	_heading(into, "Lights in the model")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	into.add_child(row)
	_lamp = OptionButton.new()
	_lamp.add_theme_font_size_override("font_size", 12)
	_lamp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lamp.tooltip_text = "Which of the model's lights to change"
	# Its rows are numbered words made here, each through tr().
	_lamp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_lamp.item_selected.connect(func(_index: int) -> void: _show_lamp())
	row.add_child(_lamp)
	_lamp_colour = ColorPickerButton.new()
	_lamp_colour.edit_alpha = false
	_lamp_colour.custom_minimum_size = Vector2(36, 26)
	_lamp_colour.tooltip_text = "The light's colour"
	_lamp_colour.color_changed.connect(func(colour: Color) -> void:
		_change_lamp({"colour": "#" + colour.to_html(false)}))
	row.add_child(_lamp_colour)
	_lamp_remove = _button(row, "Remove", _remove_lamp, "Take this light out of the model")
	_lamp_rows = VBoxContainer.new()
	_lamp_rows.add_theme_constant_override("separation", 6)
	into.add_child(_lamp_rows)
	_lamp_strength = _slider(_lamp_rows, "Strength", 0.05, SceneLights.STRONGEST, 1.0, 0.01,
		func(value: float) -> void: _change_lamp({"strength": snappedf(value, 0.01)}))
	# Each step along it the same share brighter, from a glimmer to fifty
	# times the window's key.
	_lamp_strength.exp_edit = true
	_lamp_cone = _slider(_lamp_rows, "Cone", SceneLights.NARROWEST, SceneLights.WIDEST, 40.0, 1.0,
		func(value: float) -> void: _change_lamp({"cone": value}))
	_lamp_size = _slider(_lamp_rows, "Size", 1.0, 2000.0, 4.0, 1.0,
		func(value: float) -> void: _change_lamp({"size": value}))
	_lamp_size.exp_edit = true
	var placing := HBoxContainer.new()
	placing.add_theme_constant_override("separation", 6)
	_lamp_rows.add_child(placing)
	_lamp_shadows = CheckBox.new()
	_lamp_shadows.text = "Shadows"
	_lamp_shadows.add_theme_font_size_override("font_size", 12)
	_lamp_shadows.tooltip_text = "Whether what this light lights casts a shadow"
	_lamp_shadows.toggled.connect(func(on: bool) -> void: _change_lamp({"shadows": on}))
	placing.add_child(_lamp_shadows)
	_lamp_from_eye = _button(placing, "From where I look", _lamp_to_eye,
		"Put the light where the window's camera is, shining the way it looks")
	_lamp_over = _button(placing, "Over the selection", _lamp_to_selection,
		"Hang the light over the selected parts, or over the model, shining down on them")
	var adding := HBoxContainer.new()
	adding.add_theme_constant_override("separation", 4)
	into.add_child(adding)
	var add_words := Label.new()
	add_words.text = "Add"
	add_words.add_theme_font_size_override("font_size", 12)
	adding.add_child(add_words)
	var tips: Dictionary = {
		"point": "A bulb over the selection, lighting every way",
		"spot": "A spot over the selection, its cone just taking it in",
		"directional": "A sun from the way the window looks, the same light everywhere",
		"area": "A panel of light over the selection, its shadows soft",
	}
	for kind: String in SceneLights.KINDS:
		var add: Button = _button(adding, SceneLights.kind_words(kind),
			func() -> void: _add_lamp(kind), str(tips[kind]))
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lamp_adds.append(add)
	_lamp_note = _note(into)


## The model's lights in Which, numbered, [param chosen] chosen, and the
## rest of Lights in the model shown for it.
func _list_lamps(chosen: int) -> void:
	if _lamp == null:
		return
	var lights: Array = world.scene_lights if world != null else []
	_lamp.clear()
	for n: int in lights.size():
		_lamp.add_item("%d. %s" % [n + 1, tr(SceneLights.kind_words(str(lights[n]["kind"])))])
	if lights.is_empty():
		_lamp.add_item(tr("No lights yet"))
		_lamp.set_item_disabled(0, true)
	_lamp.select(clampi(chosen, 0, maxi(lights.size() - 1, 0)))
	_show_lamp()


## Which light Lights in the model is changing, from 0, or -1 for none.
func _lamp_at() -> int:
	var lights: Array = world.scene_lights if world != null else []
	if _lamp == null or lights.is_empty():
		return -1
	return clampi(_lamp.selected, 0, lights.size() - 1)


## The chosen light's colour, strength, cone and size shown, each only for
## a kind that has it; nothing to change while the model is one shared to
## look at, and nothing past the most a model keeps to add.
func _show_lamp() -> void:
	if _lamp == null:
		return
	var lights: Array = world.scene_lights if world != null else []
	var at: int = _lamp_at()
	var allowed: bool = bool(may_change.call())
	var light: Dictionary = lights[at] if at >= 0 else {}
	var kind: String = str(light.get("kind", ""))
	_lamp.disabled = at < 0
	_lamp_colour.visible = at >= 0
	_lamp_remove.visible = at >= 0
	_lamp_rows.visible = at >= 0
	_lamp_cone.get_parent().visible = kind == "spot"
	_lamp_size.get_parent().visible = kind in ["point", "spot", "area"]
	for control: BaseButton in [_lamp_remove, _lamp_shadows, _lamp_from_eye, _lamp_over]:
		control.disabled = not allowed
	_lamp_colour.disabled = not allowed
	for slider: HSlider in [_lamp_strength, _lamp_cone, _lamp_size]:
		slider.editable = allowed
	for add: Button in _lamp_adds:
		add.disabled = not allowed or lights.size() >= SceneLights.MOST
	if at >= 0:
		_lamp_colour.color = SceneLights.colour_of(light)
		_lamp_strength.set_value_no_signal(float(light.get("strength", 1.0)))
		_lamp_cone.set_value_no_signal(float(light.get("cone", 40.0)))
		_lamp_size.set_value_no_signal(maxf(float(light.get("size", 4.0)), 1.0))
		_lamp_shadows.set_pressed_no_signal(bool(light.get("shadows", true)))
	if not allowed:
		_lamp_note.text = "This model is shared to look at: its lights are drawn, not changed."
	elif lights.is_empty():
		_lamp_note.text = ("Lights the model keeps, drawn in every quality: Add sets one over "
			+ "the selection, or over the model when nothing is selected.")
	elif lights.size() >= SceneLights.MOST:
		_lamp_note.text = "A model keeps at most %d lights." % SceneLights.MOST
	elif settings.lighting == "dark":
		_lamp_note.text = "In the Dark light these are all there is, with the plastics that glow."
	else:
		_lamp_note.text = ("Over the studio's light. Dark, in Light, puts the studio out and "
			+ "lights the plastics that glow.")


## [param fields] changed in the chosen light, each checked as a file's
## line is (SceneLights.typed), and kept with the model.
func _change_lamp(fields: Dictionary) -> void:
	var at: int = _lamp_at()
	if at < 0 or not bool(may_change.call()):
		return
	var lights: Array = world.scene_lights.duplicate()
	var light: Dictionary = (lights[at] as Dictionary).duplicate()
	light.merge(fields, true)
	var checked: Dictionary = SceneLights.typed(light)
	if checked.is_empty() or SceneLights.same([checked], [lights[at]]):
		return
	lights[at] = checked
	_keep_lamps(lights, at)


## [param lights] as the model's, [param chosen] chosen: a new array each
## time, as the saved views are, since the autosave may be reading the one
## before.
func _keep_lamps(lights: Array, chosen: int) -> void:
	world.scene_lights = lights
	lights_changed.call()
	_list_lamps(chosen)
	_ask_preview()


func _add_lamp(kind: String) -> void:
	if world == null or not bool(may_change.call()):
		return
	if world.scene_lights.size() >= SceneLights.MOST:
		_status.text = "A model keeps at most %d lights." % SceneLights.MOST
		return
	var box: AABB = chosen_box.call()
	if box.size.length() <= 0.0:
		box = world.model_bounds()
	var way: Vector3 = box.get_center() - eye.global_position if eye != null \
		else Vector3(-0.5, -0.6, -0.6)
	var light: Dictionary = SceneLights.made(kind, box, way)
	if light.is_empty():
		return
	var lights: Array = world.scene_lights.duplicate()
	lights.append(light)
	_keep_lamps(lights, lights.size() - 1)
	_status.text = "Added a light: the model keeps it, and every render draws it."


func _remove_lamp() -> void:
	var at: int = _lamp_at()
	if at < 0 or not bool(may_change.call()):
		return
	var lights: Array = world.scene_lights.duplicate()
	lights.remove_at(at)
	_keep_lamps(lights, at - 1 if at > 0 else 0)


func _lamp_to_eye() -> void:
	var at: int = _lamp_at()
	if at < 0 or eye == null or not bool(may_change.call()):
		return
	var lights: Array = world.scene_lights.duplicate()
	lights[at] = SceneLights.from_eye(lights[at], eye.global_transform)
	_keep_lamps(lights, at)


func _lamp_to_selection() -> void:
	var at: int = _lamp_at()
	if at < 0 or not bool(may_change.call()):
		return
	var box: AABB = chosen_box.call()
	if box.size.length() <= 0.0:
		box = world.model_bounds()
	var lights: Array = world.scene_lights.duplicate()
	lights[at] = SceneLights.over(lights[at], box)
	_keep_lamps(lights, at)
