## The model's timeline: the whole build, from an empty baseplate to the
## finished model and back, brick by brick, to scrub through or play.
##
## It was a booklet stepper — Back, Play, Next and a slider over the
## steps, forward only, behind the B key — and the owner asked for what
## every CAD and animation tool has: a timeline to drag along and to play
## either way, "the entire history of the build from start to finish and
## back to start". So the slider is over bricks, not steps; it plays
## forwards and backwards at four speeds; and it shows either order the
## model has:
##
##   Build order   how you would put it together on a table — the order
##                 the printable booklet uses, bottom up, each brick on
##                 something already there (Instructions.plan)
##   As made       the order the bricks still standing were placed: by
##                 hand, the order you placed them; by Claude, the order it
##                 thought of them, base first and detail last
##   History       every change since the baseplate was last cleared,
##                 removals included: a design's first draft going up and
##                 being replaced, a wall taken down and built again. What
##                 is no longer there is put back for the timeline to show
##                 (BrickWorld.history) and taken away again after
##   Author's steps  the steps the model's author gave it, in Studio, LDCad
##                 or here (AuthorSteps): the order a model that has them
##                 opens in. Its own row of buttons changes them — a step
##                 earlier or later, merged with the next, taken out — and
##                 Edit's Move to previous/next step and New step from
##                 selection put the selected parts in another
##
## Shown only while it is on, because it is a mode: while it is up the
## model on screen is not the whole model, and something has to say so
## plainly or the missing bricks read as a bug.
##
## The parts for the current step are named rather than only counted. A
## step that says "3 pieces" tells you nothing you cannot see; one that
## says "2 × Brick 2 x 4" is the line a real booklet prints beside the
## picture, and it is what lets someone follow along with bricks in front
## of them.
class_name StepsBar
extends PanelContainer

## How long the whole build takes to play at 1x, in seconds, kept within
## these whatever its size: a six-brick model is not over before the eye
## finds it, and a four-thousand-brick one does not take a quarter hour.
const SHORTEST := 6.0
const LONGEST := 40.0
const PER_BRICK := 0.04
const SPEEDS: Array[float] = [0.5, 1.0, 2.0, 4.0]

var _slider: HSlider
var _caption: Label
var _pieces: Label
var _play: Button
var _reverse: Button
var _speed: Button
var _order_button: Button
var _steps: Array[Instructions.Step] = []
var _library: PartLibrary
var _world: BrickWorld
var _scenery: Dictionary = {}
## Every brick, in the order being shown.
var _order: Array[int] = []
## [member _order] as reveal_upto hands it out, and its key.
var _order_packed := PackedInt64Array()
var _order_key: int = 0
var _reshowing: bool = false
## For the build order: where each step ends, as a count of bricks.
var _step_ends: Array[int] = []
## Bricks on screen, from 0 (an empty baseplate) to all of them.
var _shown: int = 0
## +1 playing forward, -1 backward, 0 stopped.
var _playing: int = 0
## Fractional bricks owed by the clock, so a slow speed still moves.
var _owed: float = 0.0
var _speed_at: int = 1
## 0 the build order, 1 as made, 2 the history, 3 the author's steps.
var _mode: int = 0
const MODES: Array[String] = ["Build order", "As made", "History", "Author's steps"]
const AUTHORS := 3
## The model has steps its author gave it, so the fourth order is offered.
var _authored: bool = false
## The row of step edits, shown in the author's steps.
var _edits: HBoxContainer
## How the booklet prints the step showing (BookletLooks): its own row.
var _looks: HFlowContainer
var _look_said: Label
var _look_toggles: Dictionary = {}
var _per_page: Button
## Whether the steps may be changed here: not for a model shared by link
## and opened to look at.
var editable: bool = true
## History: the changes, each [add or remove, key], or ["clear", ""].
var _events: Array = []
## History: which brick in the world shows a key — the brick itself while
## it stands, or one put back for the timeline when it does not.
var _drawn_as: Dictionary = {}
var _ghosts: Array[int] = []
var _ghost_set: Dictionary = {}

## Which bricks should be on screen. Empty means the whole model.
signal reveal(brick_ids: Dictionary)
## In the orders that are a list of the bricks (the build order, as made,
## the author's steps): the first [param count] of [param order] on screen
## and the rest of it not, everything else as it is; [param key] is new
## each time the order is worked out (Main shows it by
## BrickWorld.reveal_upto, a count a batch). [signal reveal] says the
## history's and the end's.
signal reveal_upto(order: PackedInt64Array, count: int, key: int)
## Someone wants the booklet as a file. The bar does not write it: the
## pictures come from the main viewport, which the bar is sitting on.
signal export_wanted()
## A step edit pressed on the bar: "earlier", "later", "merge", "delete" or
## "new" (Shell.edit_steps does it, on the step showing).
signal edit_wanted(op: String)
## A Booklet page command for the step showing: "turn_left", "zoom_in",
## "new_page" ... (Shell.edit_look does it).
signal look_wanted(op: String)
signal closed
## Stepped forward onto the last step from the step before it (step_forward).
signal stepped_to_end
## Stepped forward or back, by Next, Back or the arrow keys.
signal stepped

## Its buttons and the slider by name, for the page to find (controls_by_name).
var _named: Dictionary = {}
## The steps being worked out (start), until they are.
var _job: Working.Job = null


func _ready() -> void:
	visible = false
	set_process(true)
	_build()


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.10, 0.12, 0.93)
	backing.border_color = Color(1, 1, 1, 0.12)
	backing.border_width_top = 1
	backing.content_margin_left = 12
	backing.content_margin_right = 12
	backing.content_margin_top = 7
	backing.content_margin_bottom = 7
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	# The timeline itself, the width of the window: what is being dragged
	# is the whole build, and a short slider makes a brick a pixel.
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	column.add_child(line)
	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.min_value = 0
	_slider.step = 1
	_slider.focus_mode = Control.FOCUS_NONE
	# Dragging is a deliberate move; it stops the playback rather than
	# fighting it for the next frame.
	_slider.value_changed.connect(func(value: float) -> void:
		if int(value) != _shown:
			_stop_play()
			_show(int(value)))
	line.add_child(_slider)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.custom_minimum_size = Vector2(190, 0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(_caption)

	# What the step adds, on a line of its own the width of the bar. It
	# sat between the buttons, where at 1600 wide it was cut off after
	# three parts ("1 × Plate 6 x 6, 1 × Brick 1 x 3, 1").
	_pieces = Label.new()
	_pieces.add_theme_font_size_override("font_size", 12)
	_pieces.modulate = Color(1, 1, 1, 0.72)
	_pieces.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pieces.clip_text = true
	_pieces.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pieces.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_pieces)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	var start := _button("Start", "An empty baseplate (Home)")
	start.pressed.connect(to_start)
	row.add_child(start)
	_named["steps_start"] = start
	var back := _button("Back", "The step before (left arrow)")
	back.pressed.connect(step_back)
	row.add_child(back)
	_named["steps_back"] = back
	_reverse = _button("Reverse", "Play it coming apart, back to the start")
	_reverse.pressed.connect(func() -> void: _toggle(-1))
	row.add_child(_reverse)
	_play = _button("Play", "Play the build (space)")
	_play.pressed.connect(func() -> void: _toggle(1))
	row.add_child(_play)
	_named["steps_play"] = _play
	var forward := _button("Next", "The step after (right arrow)")
	forward.pressed.connect(step_forward)
	row.add_child(forward)
	_named["steps_next"] = forward
	var end := _button("End", "The finished model (End)")
	end.pressed.connect(to_end)
	row.add_child(end)
	_named["steps_end"] = end
	_speed = _button("1x", "How fast it plays")
	_speed.pressed.connect(func() -> void:
		_speed_at = (_speed_at + 1) % SPEEDS.size()
		_speed.text = _speed_name())
	row.add_child(_speed)
	_order_button = _button("Build order", "Build order: how you would put it "
		+ "together. As made: the order what stands was placed in. History: "
		+ "every change, removals included — how it was really made. Author's "
		+ "steps: the steps the model came with, or that you gave it")
	_order_button.custom_minimum_size = Vector2(92, 0)
	_order_button.pressed.connect(func() -> void: set_mode(_next_mode()))
	row.add_child(_order_button)
	_named["steps_order"] = _order_button

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	var save := _button("Instructions",
		"These steps as a printable booklet, pictures and parts included")
	save.pressed.connect(func() -> void: export_wanted.emit())
	row.add_child(save)
	_named["steps_booklet"] = save

	var close := _button("Done", "Back to the whole model")
	close.pressed.connect(stop)
	row.add_child(close)
	_named["steps_done"] = close
	_named["steps_slider"] = _slider

	# Changing the author's steps, on the step showing: as LeoCAD and Studio
	# keep theirs beside the step list. Shown in the author's steps only.
	_edits = HBoxContainer.new()
	_edits.add_theme_constant_override("separation", 6)
	_edits.visible = false
	column.add_child(_edits)
	for edit: Array in [
			["earlier", "Earlier", "This step before the one ahead of it"],
			["later", "Later", "This step after the one that follows it"],
			["merge", "Merge with next", "This step and the next made one"],
			["delete", "Delete step", "Take this step out; its parts join the step before. "
				+ "No part is taken off"],
			["new", "New step from selection", "The selected parts in a step of their own, "
				+ "after this one (Shift-N)"]]:
		var op: String = edit[0]
		var made: Button = _button(edit[1], edit[2])
		made.pressed.connect(func() -> void: edit_wanted.emit(op))
		_edits.add_child(made)
		_named["steps_" + op] = made

	# How the booklet prints the step showing, as Studio's Instruction Maker
	# sets a step's view and page beside its step list: the step showing is
	# the one changed, and the line at the end says how it is set.
	# Wrapping onto a second line where the window is narrow: in one line it
	# was wider than the timeline at 1280 x 800, and pushed the bar's own
	# Instructions and Done off the window.
	_looks = HFlowContainer.new()
	_looks.add_theme_constant_override("h_separation", 6)
	_looks.add_theme_constant_override("v_separation", 4)
	_looks.visible = false
	column.add_child(_looks)
	var title := Label.new()
	title.text = "Booklet:"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1, 1, 1, 0.72)
	_looks.add_child(title)
	for look: Array in [
			["turn_left", "Turn left", "This step's picture with the model turned 45 degrees, and the steps after it until turned again"],
			["turn_right", "Turn right", "Turned 45 degrees the other way"],
			["tilt_up", "Higher", "Seen from 15 degrees higher"],
			["tilt_down", "Lower", "Seen from 15 degrees lower"],
			["this_view", "This view", "This step drawn from the angle the window looks from now"],
			["usual_view", "Usual view", "Back to the booklet's usual angle from this step"],
			["zoom_in", "Zoom in", "Closer in on what this step adds"],
			["zoom_out", "Zoom out", "Further out"],
			["bigger", "Bigger", "Drawn larger on the page, so fewer steps share it"],
			["smaller", "Smaller", "Drawn smaller on the page"],
			["new_page", "New page", "This step at the top of a new page"],
			["alone", "Alone", "This step on a page of its own"],
			["parts", "Parts list", "The box of the parts this step adds"],
			["callout", "Callout", "The sub-assembly this step puts on built in a box beside it; "
				+ "off, on pages of its own"],
			["highlight", "Outline new", "The parts each step adds outlined in orange, in the "
				+ "whole booklet"],
			["lay_out", "Lay out page…", "This step's page by hand: drag its picture, parts list, "
				+ "callout and number, and add words and pictures"]]:
		var op: String = look[0]
		var made: Button = _button(look[1], look[2])
		if op in ["new_page", "alone", "parts", "callout", "highlight"]:
			made.toggle_mode = true
			_look_toggles[op] = made
			made.toggled.connect(func(_on: bool) -> void: look_wanted.emit(op))
		else:
			made.pressed.connect(func() -> void: look_wanted.emit(op))
		_looks.add_child(made)
		_named["booklet_" + op] = made
	_per_page = _button("Per page: as fit", "At most this many steps on a page: as they fit, 1, 2 or 4")
	_per_page.pressed.connect(func() -> void: look_wanted.emit("per_page"))
	_looks.add_child(_per_page)
	_named["booklet_per_page"] = _per_page
	_look_said = Label.new()
	_look_said.add_theme_font_size_override("font_size", 11)
	_look_said.modulate = Color(1, 1, 1, 0.72)
	_look_said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_look_said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_look_said.custom_minimum_size = Vector2(160, 0)
	_look_said.clip_text = true
	_look_said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_looks.add_child(_look_said)
	_named["booklet_said"] = _look_said


## Words, not symbols.
##
## These were ❮ ▶ ❚❚ ✕, which the desktop found in a system font and the
## browser did not — there is no fallback there, so every one of them
## rendered as a missing-glyph box. A box reads as something broken; a
## word reads as what it does, and "Play" is not less clear than a
## triangle.
func _button(label: String, tip: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.custom_minimum_size = Vector2(52, 0)
	# A face of their own: drawn flat, the row read as a line of words,
	# and nothing said which of them could be pressed.
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.24}[state])
		face.border_color = Color(1, 1, 1, 0.14)
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		face.content_margin_left = 9
		face.content_margin_right = 9
		face.content_margin_top = 3
		face.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, face)
	return button


## Work out the build order for what is in the world and show the first
## step. Returns false when there is nothing to step through, or when it
## was cancelled or stopped before it was worked out.
##
## A slice at a time, with the status bar saying how far it has got
## (Working): on Orthanc the order is seconds of work in a browser, and it
## held the page on one frame with nothing on screen to say so.
func start(world: BrickWorld, library: PartLibrary,
		scenery: Dictionary = {}) -> bool:
	if _job != null:
		return false
	_library = library
	_world = world
	_scenery = scenery
	if not world.reveal_ended.is_connected(_on_reveal_ended):
		world.reveal_ended.connect(_on_reveal_ended)
	# A model with its author's steps opens in them; one without has none
	# to show.
	_authored = AuthorSteps.any(world, scenery)
	if _authored and _mode == 0:
		_set_mode_quietly(AUTHORS)
	elif not _authored and _mode == AUTHORS:
		_set_mode_quietly(0)
	var job: Working.Job = Working.begin("Laying out %s parts in steps…"
		% Working.comma(world.brick_count() - scenery.size()), 0, true)
	_job = job
	await job.shown()
	var steps: Array[Instructions.Step] = await Instructions.plan_paced(
		world, library, scenery, {}, job, _mode == AUTHORS)
	if not job.cancelled and not steps.is_empty():
		job.say("Showing the first step…")
		job.count(0, 0)
		# In a frame of its own: the last of the laying out and the first
		# step shown were one frame, 263 ms of a browser's on Orthanc, over
		# the 250 the progress check allows (2026-10-15).
		await job.next()
	_job = null
	if job.cancelled or steps.is_empty():
		job.end()
		return false
	_steps = steps
	visible = true
	_reorder()
	# The first step, as the booklet opens: an empty baseplate is a page
	# with nothing on it.
	_show(_step_ends[0] if (_mode == 0 or _mode == AUTHORS) and not _step_ends.is_empty()
		else 1)
	job.end()
	return true


## [method start] with the steps already worked out, by whoever shared the
## model (SharedPages): nothing worked out here, in [param mode].
func start_from(steps: Array[Instructions.Step], mode: int, world: BrickWorld,
		library: PartLibrary, scenery: Dictionary = {}) -> bool:
	if _job != null or steps.is_empty():
		return false
	_library = library
	_world = world
	_scenery = scenery
	if not world.reveal_ended.is_connected(_on_reveal_ended):
		world.reveal_ended.connect(_on_reveal_ended)
	_authored = mode == AUTHORS
	_set_mode_quietly(mode)
	_steps = steps
	visible = true
	_reorder()
	_show(_step_ends[0] if not _step_ends.is_empty() else 1)
	return true


## Whether the steps are being worked out: pressing Timeline again then
## cancels it.
func is_starting() -> bool:
	return _job != null


func cancel_start() -> void:
	if _job != null:
		_job.cancelled = true


func stop() -> void:
	cancel_start()
	_stop_play()
	_forget_ghosts()
	visible = false
	# An empty set means "all of it" — leaving playback has to put the
	# model back, or the bricks after the current step stay missing.
	reveal.emit({})
	closed.emit()


func is_playing_back() -> bool:
	return visible


## The steps worked out at [method start], in the build order: the step
## player (BuildSteps) builds from these, so it numbers them as this does.
func steps() -> Array[Instructions.Step]:
	return _steps


## Its controls, for the page to find, while it is up.
func controls_by_name() -> Dictionary:
	return _named.duplicate() if visible else {}


## What a person reads on it, for a browser check; nothing while it is down.
func page_state() -> Dictionary:
	if not visible:
		return {}
	return {"order": MODES[_mode], "caption": _caption.text, "pieces": _pieces.text,
		"at": [_shown, _length()],
		# How the booklet prints the step showing, as the Booklet row says.
		"look": _look_said.text if _looks != null and _looks.visible else ""}


## How many places along the timeline there are, and which is showing.
func timeline_at() -> Vector2i:
	return Vector2i(_shown, _length())


## Which order the timeline runs in: as made, or the build order.
func set_as_made(yes: bool) -> void:
	set_mode(1 if yes else 0)


## 0 the build order, 1 as made, 2 the history, 3 the author's steps.
func set_mode(mode: int) -> void:
	if mode == _mode:
		return
	var planned_by: bool = _mode == AUTHORS
	_set_mode_quietly(mode)
	if visible:
		_stop_play()
		var share: float = float(_shown) / maxf(_length(), 1.0)
		if planned_by != (mode == AUTHORS):
			_steps = _plan()
		_reorder()
		_show(int(round(share * _length())))


func _set_mode_quietly(mode: int) -> void:
	_mode = mode
	_order_button.text = MODES[mode]
	_edits.visible = mode == AUTHORS and editable
	# The booklet follows the build order or the author's steps, and an
	# edit of how a step is printed gives a model the worked-out steps
	# first, as a step edit does.
	_looks.visible = (mode == AUTHORS or mode == 0) and editable


## The order after this one, the author's steps only for a model that has them.
func _next_mode() -> int:
	var next: int = (_mode + 1) % MODES.size()
	if next == AUTHORS and not _authored:
		next = 0
	return next


func mode() -> int:
	return _mode


## The steps for the order showing.
func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _scenery, {}, _mode == AUTHORS)


## The step the timeline is on, in the build order or the author's steps:
## the one whose end it shows, or is past the start of. Null in the other
## orders, and at an empty baseplate.
func current_step() -> Instructions.Step:
	if not visible or _shown == 0 or _step_ends.is_empty() or not (_mode == 0 or _mode == AUTHORS):
		return null
	var step: int = 0
	while step < _step_ends.size() - 1 and _step_ends[step] < _shown:
		step += 1
	# A callout's last step and the step that puts it on end together when
	# that step has no parts of its own: it is the step of the model that an
	# edit of "this step" means.
	while step < _step_ends.size() - 1 and _step_ends[step + 1] == _step_ends[step]:
		step += 1
	return _steps[step]


## The step of the booklet's pages the timeline is on: the current step,
## or, inside a callout, the step that puts it on, whose page shows the
## callout and is the page a page break or a view is for.
func booklet_step() -> Instructions.Step:
	var at: Instructions.Step = current_step()
	if at == null or not at.in_callout():
		return at
	for step: Instructions.Step in _steps:
		if step.number == at.number and step.callout_step == 0:
			return step
	return at


## The step a part put down by hand goes in (Builder.place_step): the one
## showing, in the author's steps, when the part goes where that step is.
func place_step(path: String) -> int:
	if _mode != AUTHORS:
		return -1
	var at: Instructions.Step = current_step()
	if at == null or at.authored_step < 0 or at.authored_in != path:
		return -1
	return at.authored_step


## The steps worked out again after the model or its steps changed, in the
## author's steps when it now has them, showing the end of the main step
## numbered [param number] (the one showing, when -1).
func refresh(number: int = -1) -> void:
	if not visible:
		return
	var at: Instructions.Step = current_step()
	if number < 0:
		number = at.number if at != null else -1
	_authored = AuthorSteps.any(_world, _scenery)
	if _authored and _mode == 0:
		_set_mode_quietly(AUTHORS)
	_steps = _plan()
	if _steps.is_empty():
		stop()
		return
	_reorder()
	if _mode != 0 and _mode != AUTHORS:
		_show(_shown)
		return
	var end: int = -1
	for index: int in _steps.size():
		if _steps[index].number <= number:
			end = _step_ends[index]
	_show(end if end >= 0 else (_step_ends[0] if not _step_ends.is_empty() else 0))


## How many places there are along the timeline.
## The order the world is shown it in, a count at a time, and the key
## it is shown by (BrickWorld.reveal_upto): the step player turns its pages
## by the same order, so the world the timeline laid out is laid out for it.
func reveal_order() -> Array:
	return [_order_packed, _order_key]


func _length() -> int:
	return _events.size() if _mode == 2 else _order.size()


func _reorder() -> void:
	_order.clear()
	_step_ends.clear()
	_events.clear()
	_forget_ghosts()
	if _mode == 2:
		_read_history()
	elif _mode == 1:
		# Brick numbers are handed out as bricks are placed, so in
		# number order is in the order they were placed.
		for step: Instructions.Step in _steps:
			for brick_id: int in step.brick_ids:
				_order.append(brick_id)
		_order.sort()
	else:
		# The build order, or the author's steps.
		for step: Instructions.Step in _steps:
			for brick_id: int in step.brick_ids:
				_order.append(brick_id)
			_step_ends.append(_order.size())
	_order_packed = PackedInt64Array(_order)
	_order_key += 1
	_slider.max_value = _length()


## The changes since the baseplate was last cleared, and a brick for every
## one no longer standing, put back unseen for the timeline to show.
func _read_history() -> void:
	if _world == null:
		return
	var log: Array = _world.history
	var from: int = 0
	for n: int in log.size():
		if str((log[n] as Dictionary).get("op", "")) == "clear":
			from = n + 1
	# The baseplate is the ground, not part of the story.
	var ground_parts: Dictionary = {}
	for brick_id: int in _scenery:
		var one: BrickWorld.Brick = _world.get_brick(brick_id)
		if one != null:
			ground_parts[one.part_id] = true
	var standing: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		standing[_world.key_of(brick.id)] = brick.id
	var added: Dictionary = {}
	for n: int in range(from, log.size()):
		var event: Dictionary = log[n]
		var op: String = str(event.get("op", ""))
		if op == "add":
			if ground_parts.has(str(event["part"])):
				continue
			added[event["key"]] = event
			_events.append(["add", event["key"]])
		elif op == "remove" and added.has(event.get("key", "")):
			_events.append(["remove", event["key"]])
	for key: Variant in added:
		if standing.has(key):
			_drawn_as[key] = standing[key]
			continue
		var event: Dictionary = added[key]
		var ghost: int = _world.add_ghost(str(event["part"]), int(event["colour"]),
			event["at"])
		if ghost != 0:
			_ghosts.append(ghost)
			_ghost_set[ghost] = true
			_drawn_as[key] = ghost


## Take away the bricks put back for the history, and stop drawing them.
func _forget_ghosts() -> void:
	if _world != null:
		_world.clear_ghosts()
	_ghosts.clear()
	_ghost_set.clear()
	_drawn_as.clear()


## The next step's end in the build order; ten bricks on, as made.
func step_forward() -> void:
	_stop_play()
	var from: int = _shown
	_show(_next_stop(1))
	# The last step put on, a step forward from the step before it: the
	# model built to its end along its steps (Main counts it, for a link).
	# Never the timeline opening on the finished model, a jump to the end,
	# a drag or playback: those are looking, not building.
	if (_mode == 0 or _mode == AUTHORS) and not _step_ends.is_empty() \
			and _shown >= _length() and from < _length() \
			and from >= (_step_ends[-2] if _step_ends.size() >= 2 else 0):
		stepped_to_end.emit()
	stepped.emit()


func step_back() -> void:
	_stop_play()
	_show(_next_stop(-1))
	stepped.emit()


func to_start() -> void:
	_stop_play()
	_show(0)


func to_end() -> void:
	_stop_play()
	_show(_length())


## Play, or pause if already playing.
func toggle_play() -> void:
	_toggle(1)


func _next_stop(direction: int) -> int:
	if (_mode != 0 and _mode != AUTHORS) or _step_ends.is_empty():
		return _shown + 10 * direction
	if direction > 0:
		for end: int in _step_ends:
			if end > _shown:
				return end
		return _order.size()
	var stop_at: int = 0
	for end: int in _step_ends:
		if end >= _shown:
			break
		stop_at = end
	return stop_at


func _toggle(direction: int) -> void:
	if _playing == direction:
		_stop_play()
		return
	# Played from where it would have nothing to do, it starts from the
	# other end: forward from finished means from the start.
	if direction > 0 and _shown >= _length():
		_show(0)
	elif direction < 0 and _shown <= 0:
		_show(_length())
	_playing = direction
	_owed = 0.0
	_play.text = "Pause" if direction > 0 else "Play"
	_reverse.text = "Pause" if direction < 0 else "Reverse"


func _stop_play() -> void:
	_playing = 0
	if _play != null:
		_play.text = "Play"
		_reverse.text = "Reverse"


func is_playing() -> bool:
	return _playing != 0


func _speed_name() -> String:
	var speed: float = SPEEDS[_speed_at]
	return ("%dx" % int(speed)) if speed >= 1.0 else "%sx" % str(speed)


## Bricks a second at this speed.
func rate() -> float:
	var seconds: float = clampf(_length() * PER_BRICK, SHORTEST, LONGEST)
	return _length() / seconds * SPEEDS[_speed_at]


func _process(delta: float) -> void:
	if _playing == 0 or not visible:
		return
	_owed += delta * rate()
	var whole: int = int(_owed)
	if whole == 0:
		return
	_owed -= whole
	var to: int = _shown + whole * _playing
	if to >= _length() or to <= 0:
		_show(clampi(to, 0, _length()))
		_stop_play()
		return
	_show(to)


func shown() -> int:
	return _shown


func _show(count: int) -> void:
	if _mode == 2:
		_show_history(count)
		return
	if _order.is_empty():
		return
	_shown = clampi(count, 0, _order.size())
	_slider.set_value_no_signal(_shown)

	var of: String = "%d of %d bricks" % [_shown, _order.size()]
	if _mode == 1 or _step_ends.is_empty():
		_caption.text = of
		_pieces.text = "As made: the order the bricks standing were placed in" \
			if _mode == 1 else ""
	else:
		var step: int = 0
		while step < _step_ends.size() - 1 and _step_ends[step] < _shown:
			step += 1
		# Numbered as the booklet numbers them, so "step 12" here is step
		# 12 on the page: a callout's steps carry the number of the step
		# its assembly goes on in, and are counted inside it.
		var at: Instructions.Step = _steps[step]
		_caption.text = "%s · %s" % [at.caption(_steps[-1].number), of]
		if _shown == 0:
			_pieces.text = "An empty baseplate" + (": the steps are the author's"
				if _mode == AUTHORS else "")
		else:
			_pieces.text = at.summary(_library)
			# A callout is built on the side in the booklet; here it goes
			# up where it will stand, the only place the world can show it.
			if at.in_callout() and at.callout_step == at.callout_steps:
				_pieces.text += " — then put %s on" % ("them" if at.times > 1 else "it")
			if at.unsupported:
				# Worth saying. The alternative is a step that looks wrong
				# to anyone following it with real bricks in their hands.
				_pieces.text += "  (hold this one in place)"
	_pieces.tooltip_text = _pieces.text
	_show_look()
	# Everything up to here, as a count of the order: going backwards is the
	# same path as forwards. It was every brick up to here gathered again,
	# and every brick in the model asked whether it was among them.
	reveal_upto.emit(_order_packed, _shown, _order_key)


## How the booklet prints the step showing: the toggles as it is set, and
## a line saying so.
func _show_look() -> void:
	if _looks == null or not _looks.visible:
		return
	var at: Instructions.Step = booklet_step()
	var section: String = at.authored_in if at != null else ""
	var step: int = at.authored_step if at != null else -1
	var own: Dictionary = BookletLooks.of(_world, section, step) if step >= 0 else {}
	(_look_toggles["new_page"] as Button).set_pressed_no_signal(str(own.get("page", "")) == "new")
	(_look_toggles["alone"] as Button).set_pressed_no_signal(str(own.get("page", "")) == "alone")
	(_look_toggles["parts"] as Button).set_pressed_no_signal(bool(own.get("parts", true)))
	var unit: String = BookletLooks.attached(_world, at, section) if at != null else ""
	var callout: Button = _look_toggles["callout"]
	callout.disabled = unit.is_empty()
	callout.set_pressed_no_signal(not unit.is_empty() and BookletLooks.callout_on(_world, unit))
	(_look_toggles["highlight"] as Button).set_pressed_no_signal(BookletLooks.highlight_on(_world))
	var most: int = int(BookletLooks.booklet(_world).get("per_page", 0))
	_per_page.text = "Per page: %s" % ("as fit" if most == 0 else str(most))
	var said: String = BookletLooks.said(_world, section, step) if step >= 0 else ""
	_look_said.text = said if not said.is_empty() else "as the booklet chooses"
	_look_said.tooltip_text = _look_said.text


## The world stopped showing the order a count at a time: something changed
## a batch of it, or a cut or x-ray went on. Shown again as it was, once
## whatever changed it has finished.
func _on_reveal_ended() -> void:
	if visible and _mode != 2 and not _order.is_empty() and not _reshowing:
		_reshowing = true
		_reshow.call_deferred()


func _reshow() -> void:
	_reshowing = false
	if visible and _mode != 2 and not _order.is_empty():
		_show(_shown)


## The history up to the [param count]th change: what was standing then,
## including what has since been taken away.
func _show_history(count: int) -> void:
	if _events.is_empty():
		return
	_shown = clampi(count, 0, _events.size())
	_slider.set_value_no_signal(_shown)
	var alive: Dictionary = {}
	for n: int in _shown:
		var event: Array = _events[n]
		if event[0] == "add":
			alive[event[1]] = true
		else:
			alive.erase(event[1])
	var showing: Dictionary = _scenery.duplicate()
	var gone: int = 0
	for key: Variant in alive:
		if _drawn_as.has(key):
			showing[_drawn_as[key]] = true
			if _ghost_set.has(int(_drawn_as[key])):
				gone += 1
	_caption.text = "Change %d of %d · %d standing" % [_shown, _events.size(), alive.size()]
	_pieces.text = ("History: every change, removals included" + (
		" — %d of these were taken out later" % gone if gone > 0 else ""))
	_pieces.tooltip_text = _pieces.text
	reveal.emit(showing)
