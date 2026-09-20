## Stepping through a model the way a booklet does.
##
## Shown only while playback is on, because it is a mode: while it is up
## the model on screen is not the whole model, and something has to say
## so plainly or the missing bricks read as a bug.
##
## The parts for the current step are named rather than only counted. A
## step that says "3 pieces" tells you nothing you cannot see; one that
## says "2 × Brick 2 x 4" is the line a real booklet prints beside the
## picture, and it is what lets someone follow along with bricks in front
## of them.
class_name StepsBar
extends PanelContainer

## Seconds a step is held during automatic playback. Slow enough to see
## what changed, brisk enough that a hundred-step model is watchable.
const DWELL := 0.8

var _slider: HSlider
var _caption: Label
var _pieces: Label
var _play: Button
var _steps: Array[Instructions.Step] = []
var _library: PartLibrary
var _scenery: Dictionary = {}
var _at: int = 0
var _playing: bool = false
var _clock: float = 0.0

## Which bricks should be on screen. Empty means the whole model.
signal reveal(brick_ids: Dictionary)
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var back := _button("❮", "Previous step")
	back.pressed.connect(func() -> void: _go(_at - 1))
	row.add_child(back)

	_play = _button("▶", "Play the build through")
	_play.pressed.connect(_toggle_play)
	row.add_child(_play)

	var forward := _button("❯", "Next step")
	forward.pressed.connect(func() -> void: _go(_at + 1))
	row.add_child(forward)

	_slider = HSlider.new()
	_slider.custom_minimum_size = Vector2(240, 0)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.min_value = 0
	_slider.step = 1
	# Dragging is a deliberate move; it should stop the playback rather
	# than fight it for the next frame.
	_slider.value_changed.connect(func(value: float) -> void:
		if int(value) != _at:
			_stop_play()
			_go(int(value)))
	row.add_child(_slider)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.custom_minimum_size = Vector2(110, 0)
	row.add_child(_caption)

	_pieces = Label.new()
	_pieces.add_theme_font_size_override("font_size", 12)
	_pieces.modulate = Color(1, 1, 1, 0.66)
	_pieces.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pieces.clip_text = true
	row.add_child(_pieces)

	var close := _button("✕", "Back to the whole model")
	close.pressed.connect(stop)
	row.add_child(close)


func _button(glyph: String, tip: String) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30, 0)
	return button


## Work out the booklet for what is in the world and show the first step.
## Returns false when there is nothing to step through.
func start(world: BrickWorld, library: PartLibrary,
		scenery: Dictionary = {}) -> bool:
	_library = library
	_scenery = scenery
	_steps = Instructions.plan(world, library, scenery)
	if _steps.is_empty():
		return false
	_slider.max_value = _steps.size() - 1
	visible = true
	_go(0)
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


func step_forward() -> void:
	_go(_at + 1)


func step_back() -> void:
	_go(_at - 1)


func _toggle_play() -> void:
	if _playing:
		_stop_play()
		return
	# Starting from the end would look like nothing happening, so a play
	# from the last step goes back to the beginning.
	if _at >= _steps.size() - 1:
		_go(0)
	_playing = true
	_clock = 0.0
	_play.text = "❚❚"
	_play.tooltip_text = "Pause"


func _stop_play() -> void:
	_playing = false
	_play.text = "▶"
	_play.tooltip_text = "Play the build through"


func _process(delta: float) -> void:
	if not _playing or not visible:
		return
	_clock += delta
	if _clock < DWELL:
		return
	_clock = 0.0
	if _at >= _steps.size() - 1:
		_stop_play()
		return
	_go(_at + 1)


func _go(to: int) -> void:
	if _steps.is_empty():
		return
	_at = clampi(to, 0, _steps.size() - 1)
	_slider.set_value_no_signal(_at)

	# Everything up to and including this step. Recomputed rather than
	# kept, so stepping backwards is the same code path as forwards and
	# cannot drift out of step with it.
	var showing: Dictionary = _scenery.duplicate()
	for index: int in _at + 1:
		for brick_id: int in _steps[index].brick_ids:
			showing[brick_id] = true

	var step: Instructions.Step = _steps[_at]
	_caption.text = "Step %d of %d" % [_at + 1, _steps.size()]
	_pieces.text = step.summary(_library)
	if step.unsupported:
		# Worth saying. The alternative is a step that looks wrong to
		# anyone following it with real bricks in their hands.
		_pieces.text += "  (hold this one in place)"
	_pieces.tooltip_text = _pieces.text
	reveal.emit(showing)
