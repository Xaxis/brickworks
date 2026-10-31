## File, Render queue…: pictures lined up and drawn one after the other
## while the window goes on being used, as a renderer's queue does
## (APP_UX3 pathtrace).
##
## Each is added as the window is then: the view looked from, Render's
## settings (File, Render…, RenderDialog), and the model as it stood, kept
## in a world of its own that draws nothing, so building on meanwhile
## changes none of them. They are drawn by a renderer of the queue's own
## (StudioRender: Best path traced where the graphics card traces rays),
## saved where Render saves, numbered so none is written over, and said
## in the status bar (Working), whose Cancel stops the one being drawn
## and pauses the rest.
##
## Over MCP, render_queue (AppTools) adds, lists and pauses the same queue.
## Opened by name ([method of]) so the shell and main need not load it
## before it is first asked for.
class_name RenderQueue
extends PanelContainer

## The panel's width, its words wrapped inside it.
const WIDE := 380.0
## Rows shown before the list scrolls.
const MOST_ROWS := 5
const ROW_TALL := 46.0
## The picture kept with a finished render, for render_queue to show, at
## most this wide.
const KEPT_WIDE := 800

## One picture asked for.
class Item extends RefCounted:
	var number: int = 0
	var settings: RenderSettings
	## The model as it stood when added; freed once drawn.
	var model: BrickWorld
	var named: String = ""
	## waiting, drawing, saving, done, failed or cancelled.
	var state: String = "waiting"
	var fraction: float = 0.0
	var words: String = ""
	## Where it was written, or downloaded as.
	var path: String = ""
	var took_ms: int = 0
	var samples: int = 0
	var traced: bool = false
	## The finished picture, at most KEPT_WIDE across.
	var picture: Image = null

	## What it is, in a row's words: "car, 1280×720, Best".
	func what() -> String:
		var grade: String = ["Quick", "Good", "Best"][settings.quality]
		return "%s, %d×%d, %s" % [named, settings.size.x, settings.size.y, grade]

	func finished() -> bool:
		return state in ["done", "failed", "cancelled"]

signal changed

var items: Array[Item] = []
## Where pictures go: Render's own folder when empty.
var folder: String = ""
## Held after the one being drawn: Pause, or Cancel in the status bar.
var paused: bool = false

var _app: Node
var _renderer: StudioRender
var _running: bool = false
var _current: Item = null
## The one being drawn was stopped by the person, not by a failure.
var _stopped: bool = false
var _job: Working.Job = null
var _next_number: int = 1
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _note: Label
var _status: Label
var _add_button: Button
var _pause_button: Button
var _finish_button: Button
var _clear_button: Button
var _close_button: Button
var _placed_in := Rect2()


## The app's queue, made the first time it is asked for: the shell's
## command and render_queue reach it by name through this.
static func of(app: Node) -> RenderQueue:
	var hud: Node = app.get_node_or_null("HUD")
	var holder: Node = hud if hud != null else app
	var found: RenderQueue = holder.get_node_or_null("RenderQueue") as RenderQueue
	if found != null:
		return found
	var queue := RenderQueue.new()
	queue.name = "RenderQueue"
	queue._app = app
	holder.add_child(queue)
	return queue


func _ready() -> void:
	visible = false
	_renderer = StudioRender.new()
	add_child(_renderer)
	_renderer.progress.connect(_on_progress)
	_build()
	get_viewport().size_changed.connect(_place)


func open() -> void:
	visible = true
	_refresh()
	_place()


func close() -> void:
	visible = false


# -- the queue ------------------------------------------------------------------


## Add the window's view now, with Render's settings or [param chosen]'s,
## and begin drawing unless paused. Null when there is nothing to draw,
## with why in [member last_refusal].
func add(chosen: RenderSettings = null) -> Item:
	last_refusal = ""
	var dialog: Node = _app.get("_render") if _app != null else null
	var world: BrickWorld = _app.get("_world") if _app != null else null
	var store: ModelStore = _app.get("_store") if _app != null else null
	var scenery: Dictionary = store.scenery if store != null else {}
	if world == null or world.brick_count() - scenery.size() <= 0:
		last_refusal = "There is nothing on the baseplate to render yet."
		return null
	if not StudioRender.possible():
		last_refusal = "Rendering needs a window to draw in."
		return null
	var item := Item.new()
	item.number = _next_number
	_next_number += 1
	var given: RenderSettings = chosen
	if given == null:
		given = dialog.get("settings") as RenderSettings if dialog != null else null
	if given == null:
		given = RenderSettings.new()
		given.view = "current"
	item.settings = given.copy()
	var eye: Camera3D = _app.get("_camera") as Camera3D
	if eye != null:
		item.settings.keep_eye(eye)
	item.model = _model_now(world, scenery)
	var bar: ModelBar = _app.get("_bar") as ModelBar
	item.named = bar.model_name() if bar != null else "Model"
	items.append(item)
	_refresh()
	if not paused:
		_run()
	return item


## Why the last [method add] added nothing.
var last_refusal: String = ""


## The model as it stands, in a world of its own: what is hidden, and the
## scenery, is left hidden there.
func _model_now(world: BrickWorld, scenery: Dictionary) -> BrickWorld:
	var copy: BrickWorld = world.copy_for_reading()
	for brick: BrickWorld.Brick in copy.bricks():
		var own: BrickWorld.Brick = world.get_brick(brick.id)
		brick.hidden = own == null or own.hidden or scenery.has(brick.id)
	return copy


## Hold the rest after the one being drawn, or go on.
func pause(held: bool) -> void:
	paused = held
	_refresh()
	if not paused:
		_run()


## Keep the one being drawn as it is now: a path-traced picture is as
## clean as its samples so far.
func finish_now() -> bool:
	if _current == null or not _current.settings.traced_here():
		return false
	_renderer.finish_now()
	return true


## Take a waiting one out, or stop the one being drawn. False when there
## is no such one still to finish.
func cancel(number: int) -> bool:
	for item: Item in items:
		if item.number != number or item.finished():
			continue
		if item == _current:
			_stopped = true
			_renderer.cancel()
		else:
			_drop(item, "cancelled")
		_refresh()
		return true
	return false


## Forget the finished ones.
func clear_finished() -> void:
	var left: Array[Item] = []
	for item: Item in items:
		if not item.finished():
			left.append(item)
	items = left
	_refresh()


func waiting() -> int:
	var count: int = 0
	for item: Item in items:
		if item.state == "waiting":
			count += 1
	return count


func is_drawing() -> bool:
	return _current != null


func find(number: int) -> Item:
	for item: Item in items:
		if item.number == number:
			return item
	return null


func _drop(item: Item, state: String) -> void:
	item.state = state
	if item.model != null:
		item.model.free()
		item.model = null


func _run() -> void:
	if _running:
		return
	_running = true
	while not paused:
		var next: Item = null
		for item: Item in items:
			if item.state == "waiting":
				next = item
				break
		if next == null:
			break
		await _render_one(next)
	_running = false
	if _job != null:
		_job.end()
		_job = null
	_refresh()


func _render_one(item: Item) -> void:
	_current = item
	item.state = "drawing"
	item.fraction = 0.0
	if _job == null:
		_job = Working.begin("", 100, true)
		_job.percent = true
		_job.cancel_wanted.connect(func() -> void:
			paused = true
			_stopped = true
			_renderer.cancel())
	_job.say(_job_words(item))
	_job.count(0)
	_refresh()
	_renderer.library = (_app.get("_library") as PartLibrary) if _app != null else null
	_renderer.scenery = {}
	var dialog: Node = _app.get("_render") if _app != null else null
	if dialog != null:
		_renderer.look = dialog.get("look") as Environment
		var lights: Array = dialog.get("rig_lights")
		_renderer.rig_lights.assign(lights)
	var started: int = Time.get_ticks_msec()
	_stopped = false
	var image: Image = await _renderer.render(item.model, item.settings)
	item.took_ms = Time.get_ticks_msec() - started
	item.traced = _renderer.traced_last() and item.settings.traced_here()
	item.samples = _renderer.last_samples
	_drop(item, "saving" if image != null else ("cancelled" if _stopped else "failed"))
	if image != null:
		_refresh()
		item.words = await _keep(image, item)
		item.state = "done" if item.words.begins_with("wrote") \
			or item.words.begins_with("downloaded") else "failed"
		var kept: Image = image.duplicate() as Image
		if kept.get_width() > KEPT_WIDE:
			kept.resize(KEPT_WIDE, maxi(roundi(float(KEPT_WIDE) * kept.get_height()
				/ kept.get_width()), 1), Image.INTERPOLATE_BILINEAR)
		item.picture = kept
	_current = null
	_refresh()


func _job_words(item: Item) -> String:
	var left: int = waiting()
	return "Rendering %s%s…" % [item.what(),
		" (%d more queued)" % left if left > 0 else ""]


func _on_progress(fraction: float, words: String) -> void:
	if _current == null:
		return
	_current.fraction = fraction
	_current.words = words
	if _job != null:
		_job.count(roundi(fraction * 100.0))
	_refresh_current()


## Write it as Render does, under a name no other picture has there.
func _keep(image: Image, item: Item) -> String:
	var output := RenderOutput.new()
	var dialog: Node = _app.get("_render") if _app != null else null
	output.folder = folder if not folder.is_empty() \
		else (str(dialog.get("folder")) if dialog != null else "")
	var name: String = RenderOutput.file_name(item.named, "_render_%d" % item.number, "png")
	if not OS.has_feature("web"):
		var n: int = item.number
		while FileAccess.file_exists(output.where().path_join(name)):
			n += 1
			name = RenderOutput.file_name(item.named, "_render_%d" % n, "png")
	var bytes: Array = [PackedByteArray()]
	var work := func() -> void: bytes[0] = image.save_png_to_buffer()
	if OS.has_feature("nothreads"):
		work.call()
	else:
		var task: int = WorkerTasks.add(work, false, "encode a queued render")
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerTasks.collect(task)
	var line: String = output.give(bytes[0], name, "image/png")
	item.path = output.paths[0] if not output.paths.is_empty() else ""
	return line


## As the app closes: what was still to draw is said, not lost without a
## word, and the models kept for it are freed.
func _exit_tree() -> void:
	var left: PackedStringArray = PackedStringArray()
	for item: Item in items:
		if not item.finished() and item.state != "saving":
			left.append(item.what())
		if item.model != null:
			item.model.free()
			item.model = null
	if not left.is_empty():
		print("render queue, as the app closed: not drawn: %s" % "; ".join(left))


# -- what it says, for the panel and for a session ------------------------------------


## A line for each, as render_queue lists them.
func lines() -> PackedStringArray:
	var said := PackedStringArray()
	for item: Item in items:
		said.append("%d. %s: %s" % [item.number, item.what(), state_words(item)])
	return said


func state_words(item: Item) -> String:
	match item.state:
		"waiting":
			return "waiting" + (", paused" if paused else "")
		"drawing":
			return "%d%%, %s" % [roundi(item.fraction * 100.0), item.words] \
				if not item.words.is_empty() else "starting"
		"saving":
			return "saving"
		"done":
			var how: String = ("path traced, %d samples" % item.samples) if item.traced \
				else ("%d frames averaged" % item.samples if item.settings.quality
					== RenderSettings.Quality.BEST else "")
			return "%s in %.1f s%s" % [item.words, float(item.took_ms) / 1000.0,
				" (%s)" % how if not how.is_empty() else ""]
		"failed":
			return item.words if not item.words.is_empty() else "could not be drawn"
	return "cancelled"


## How Best is drawn here, in a line.
static func best_here() -> String:
	if PathTracer.available():
		return "Best is path traced on this graphics card."
	return "Best is frames averaged here. " + PathTracer.why_not()


# -- the panel --------------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.96)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDE, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Render queue"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = _button(header, "Close", close,
		"Put the panel away; what is queued goes on being drawn")
	_note = _words(column, 12, 0.75)
	_note.text = ("Pictures drawn one after another with Render's settings, while you go "
		+ "on building. Each is of the view and the model as they were when added.")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	_status = _words(column, 11, 0.65)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	_add_button = _button(buttons, "Add this view", func() -> void:
		if add() == null:
			_status.text = last_refusal,
		"Queue a picture of the model as you see it now, with Render's settings")
	_pause_button = _button(buttons, "Pause", func() -> void: pause(not paused),
		"Hold the rest after the one being drawn")
	_finish_button = _button(buttons, "Finish now", func() -> void: finish_now(),
		"Keep the picture being drawn as clean as it is now")
	_clear_button = _button(buttons, "Clear finished", clear_finished,
		"Take the finished ones off the list; their files stay")


func _words(into: Control, font_size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDE - 28.0, 0)
	label.modulate = Color(1, 1, 1, alpha)
	into.add_child(label)
	return label


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


## The rows again, and the buttons as they now apply.
func _refresh() -> void:
	changed.emit()
	if _rows == null or not visible:
		return
	for child: Node in _rows.get_children():
		child.queue_free()
	for item: Item in items:
		_rows.add_child(_row(item))
	_scroll.custom_minimum_size = Vector2(0, minf(float(items.size()), float(MOST_ROWS))
		* ROW_TALL)
	_scroll.visible = not items.is_empty()
	_pause_button.text = "Go on" if paused else "Pause"
	_pause_button.disabled = not paused and waiting() == 0
	_finish_button.disabled = _current == null or not _current.settings.traced_here()
	var finished: int = 0
	for item: Item in items:
		if item.finished():
			finished += 1
	_clear_button.disabled = finished == 0
	_status.text = best_here() if items.is_empty() else ("%d waiting%s. %s" % [waiting(),
		", paused" if paused else "", best_here()])
	reset_size()
	_place()


func _row(item: Item) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, ROW_TALL - 4.0)
	row.set_meta("number", item.number)
	var number := Label.new()
	number.text = "%d" % item.number
	number.add_theme_font_size_override("font_size", 12)
	number.modulate = Color(1, 1, 1, 0.55)
	row.add_child(number)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var what := Label.new()
	what.text = item.what()
	what.add_theme_font_size_override("font_size", 12)
	what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	what.clip_text = true
	words.add_child(what)
	if item.state == "drawing":
		var bar := ProgressBar.new()
		bar.name = "Progress"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = 1.0
		bar.value = item.fraction
		words.add_child(bar)
	var state := Label.new()
	state.name = "State"
	state.text = state_words(item)
	state.add_theme_font_size_override("font_size", 11)
	state.modulate = Color(1, 1, 1, 0.6)
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.clip_text = true
	words.add_child(state)
	if item.state == "done" and not item.path.is_empty() and not OS.has_feature("web"):
		_button(row, "Show", func() -> void: Outside.show_in_folder(item.path),
			"Show the picture in its folder")
	elif not item.finished() and item.state != "saving":
		_button(row, "Stop" if item.state == "drawing" else "Remove",
			func() -> void: cancel(item.number),
			"Stop drawing this one" if item.state == "drawing" else "Take it out of the queue")
	return row


## Only the row being drawn, as it goes: a row each time would be a
## frame's worth of labels made and freed for every pass of the tracer.
func _refresh_current() -> void:
	if not visible or _rows == null or _current == null:
		return
	for row: Node in _rows.get_children():
		if int(row.get_meta("number", -1)) != _current.number:
			continue
		var bar: ProgressBar = row.find_child("Progress", true, false) as ProgressBar
		if bar != null:
			bar.value = _current.fraction
		var state: Label = row.find_child("State", true, false) as Label
		if state != null:
			state.text = state_words(_current)


## In the bottom right corner of the model's room, clear of the status bar.
func _place() -> void:
	if not visible or _app == null:
		return
	var room: Rect2 = _app.call("_model_rect") if _app.has_method("_model_rect") \
		else get_viewport().get_visible_rect()
	var wide: float = minf(WIDE, room.size.x - 24.0)
	custom_minimum_size.x = wide
	size = Vector2(wide, get_combined_minimum_size().y)
	position = Vector2(room.end.x - size.x - 12.0, room.end.y - size.y - 12.0)
	_placed_in = room


func _process(_delta: float) -> void:
	# The model's room changes as the side panels open and close.
	if visible and _app != null and _app.has_method("_model_rect"):
		var room: Rect2 = _app.call("_model_rect")
		if room != _placed_in:
			_place()


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"queue_add": _add_button, "queue_pause": _pause_button,
		"queue_finish": _finish_button, "queue_clear": _clear_button,
		"queue_close": _close_button}
