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
##   As made       the order the bricks were placed: by hand, the order
##                 you placed them; by Claude, the order it thought of
##                 them, base first and detail last
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
## For the build order: where each step ends, as a count of bricks.
var _step_ends: Array[int] = []
## Bricks on screen, from 0 (an empty baseplate) to all of them.
var _shown: int = 0
## +1 playing forward, -1 backward, 0 stopped.
var _playing: int = 0
## Fractional bricks owed by the clock, so a slow speed still moves.
var _owed: float = 0.0
var _speed_at: int = 1
var _as_made: bool = false

## Which bricks should be on screen. Empty means the whole model.
signal reveal(brick_ids: Dictionary)
## Someone wants the booklet as a file. The bar does not write it: the
## pictures come from the main viewport, which the bar is sitting on.
signal export_wanted()
signal closed


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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	var start := _button("Start", "An empty baseplate (Home)")
	start.pressed.connect(to_start)
	row.add_child(start)
	var back := _button("Back", "The step before (left arrow)")
	back.pressed.connect(step_back)
	row.add_child(back)
	_reverse = _button("Reverse", "Play it coming apart, back to the start")
	_reverse.pressed.connect(func() -> void: _toggle(-1))
	row.add_child(_reverse)
	_play = _button("Play", "Play the build (space)")
	_play.pressed.connect(func() -> void: _toggle(1))
	row.add_child(_play)
	var forward := _button("Next", "The step after (right arrow)")
	forward.pressed.connect(step_forward)
	row.add_child(forward)
	var end := _button("End", "The finished model (End)")
	end.pressed.connect(to_end)
	row.add_child(end)
	_speed = _button("1x", "How fast it plays")
	_speed.pressed.connect(func() -> void:
		_speed_at = (_speed_at + 1) % SPEEDS.size()
		_speed.text = _speed_name())
	row.add_child(_speed)
	_order_button = _button("Build order", "Build order: how you would put it "
		+ "together. As made: the order it was placed in, by you or by Claude")
	_order_button.custom_minimum_size = Vector2(92, 0)
	_order_button.pressed.connect(func() -> void: set_as_made(not _as_made))
	row.add_child(_order_button)

	_pieces = Label.new()
	_pieces.add_theme_font_size_override("font_size", 12)
	_pieces.modulate = Color(1, 1, 1, 0.66)
	_pieces.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pieces.clip_text = true
	row.add_child(_pieces)

	var save := Button.new()
	save.text = "Save instructions"
	save.tooltip_text = "One printable page, pictures and parts included"
	save.focus_mode = Control.FOCUS_NONE
	save.add_theme_font_size_override("font_size", 11)
	save.pressed.connect(func() -> void: export_wanted.emit())
	row.add_child(save)

	var close := _button("Done", "Back to the whole model")
	close.pressed.connect(stop)
	row.add_child(close)


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
	return button


## Work out the build order for what is in the world and show the first
## step. Returns false when there is nothing to step through.
func start(world: BrickWorld, library: PartLibrary,
		scenery: Dictionary = {}) -> bool:
	_library = library
	_world = world
	_scenery = scenery
	_steps = Instructions.plan(world, library, scenery)
	if _steps.is_empty():
		return false
	visible = true
	_reorder()
	# The first step, as the booklet opens: an empty baseplate is a page
	# with nothing on it.
	_show(_step_ends[0] if not _as_made and not _step_ends.is_empty() else 1)
	return true


func stop() -> void:
	_stop_play()
	visible = false
	# An empty set means "all of it" — leaving playback has to put the
	# model back, or the bricks after the current step stay missing.
	reveal.emit({})
	closed.emit()


func is_playing_back() -> bool:
	return visible


## Which order the timeline runs in: as made, or the build order.
func set_as_made(yes: bool) -> void:
	if yes == _as_made:
		return
	_as_made = yes
	_order_button.text = "As made" if yes else "Build order"
	if visible:
		var share: float = float(_shown) / maxf(_order.size(), 1.0)
		_reorder()
		_show(int(round(share * _order.size())))


func _reorder() -> void:
	_order.clear()
	_step_ends.clear()
	if _as_made:
		# Brick numbers are handed out as bricks are placed, so in
		# number order is in the order they were placed.
		for step: Instructions.Step in _steps:
			for brick_id: int in step.brick_ids:
				_order.append(brick_id)
		_order.sort()
	else:
		for step: Instructions.Step in _steps:
			for brick_id: int in step.brick_ids:
				_order.append(brick_id)
			_step_ends.append(_order.size())
	_slider.max_value = _order.size()


## The next step's end in the build order; ten bricks on, as made.
func step_forward() -> void:
	_stop_play()
	_show(_next_stop(1))


func step_back() -> void:
	_stop_play()
	_show(_next_stop(-1))


func to_start() -> void:
	_stop_play()
	_show(0)


func to_end() -> void:
	_stop_play()
	_show(_order.size())


## Play, or pause if already playing.
func toggle_play() -> void:
	_toggle(1)


func _next_stop(direction: int) -> int:
	if _as_made or _step_ends.is_empty():
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
	if direction > 0 and _shown >= _order.size():
		_show(0)
	elif direction < 0 and _shown <= 0:
		_show(_order.size())
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
	var seconds: float = clampf(_order.size() * PER_BRICK, SHORTEST, LONGEST)
	return _order.size() / seconds * SPEEDS[_speed_at]


func _process(delta: float) -> void:
	if _playing == 0 or not visible:
		return
	_owed += delta * rate()
	var whole: int = int(_owed)
	if whole == 0:
		return
	_owed -= whole
	var to: int = _shown + whole * _playing
	if to >= _order.size() or to <= 0:
		_show(clampi(to, 0, _order.size()))
		_stop_play()
		return
	_show(to)


func shown() -> int:
	return _shown


func _show(count: int) -> void:
	if _order.is_empty():
		return
	_shown = clampi(count, 0, _order.size())
	_slider.set_value_no_signal(_shown)

	# Everything up to here. Recomputed rather than kept, so going
	# backwards is the same code path as forwards and cannot drift out of
	# step with it.
	var showing: Dictionary = _scenery.duplicate()
	for n: int in _shown:
		showing[_order[n]] = true

	var of: String = "%d of %d bricks" % [_shown, _order.size()]
	if _as_made or _step_ends.is_empty():
		_caption.text = of
		_pieces.text = "As made: the order the bricks were placed in" \
			if _as_made else ""
	else:
		var step: int = 0
		while step < _step_ends.size() - 1 and _step_ends[step] < _shown:
			step += 1
		_caption.text = "Step %d of %d · %s" % [step + 1, _steps.size(), of]
		if _shown == 0:
			_pieces.text = "An empty baseplate"
		else:
			var at: Instructions.Step = _steps[step]
			_pieces.text = at.summary(_library)
			if at.unsupported:
				# Worth saying. The alternative is a step that looks wrong
				# to anyone following it with real bricks in their hands.
				_pieces.text += "  (hold this one in place)"
	_pieces.tooltip_text = _pieces.text
	reveal.emit(showing)
