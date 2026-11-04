## A brief sent with a click ends with its card in view (layoutwait).
##
##   godot --path . --resolution 1280x720 --script src/dev/chat_follow_probe.gd
##
## The panel scrolled to its newest line one process frame after the line
## went in. A press is read before its frame's layout, and that frame's
## process_frame comes before the layout too: the line and its card had no
## size yet, the scroll went to the end as it was, and the card the brief
## opened was left below the view. The connector form did the same with the
## box a link opens (suitegrab).
##
## Here, in a window, the panel a column's height and its conversation long
## enough to scroll, Build it clicked as the mouse clicks it, five times
## with the conversation at its end and five scrolled back to its start,
## since a new line is followed from wherever the reader was. Each time the
## card must end whole in view. Then six steps Claude makes, each heard
## while a press is read, each growing Claude's card by a line: the card
## must end in view to its foot, as the panel follows it.
## The model's request is taken out, as chat_probe takes it.
extends SceneTree


class Offline extends Assistant:
	func _send() -> void:
		pass


const PROBE_KEY := "sk-ant-api03-probe-not-a-real-key-and-never-sent-anywhere"

var _failures: int = 0
var _panel: ChatPanel


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	# Nothing asked of a deployment leaves the machine.
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Offline.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	OwnKey._this_visit = PROBE_KEY
	_panel = ChatPanel.new()
	root.add_child(_panel)
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(380, 600)
	await process_frame
	_panel.bind(assistant)
	_panel._sketch_first.button_pressed = false
	for n: int in 24:
		_panel.note("Line %d of what went before, long enough to wrap across the panel's width." % n)
	await _frames(20)
	var bar: ScrollBar = _panel._scroll.get_v_scroll_bar()
	_check(bar.max_value > bar.page * 2.0 and _at_end(),
		"the conversation is longer than its view, and at its end (%d of %d, %d shown)"
			% [bar.value, bar.max_value, bar.page])

	for round: int in 10:
		var from_start: bool = round >= 5
		if from_start:
			_panel._scroll.scroll_vertical = 0
			await _frames(4)
		_panel._input.text = "a small red house, round %d" % round
		await _click(_panel._send)
		await _frames(12)
		var card: Control = _panel._run
		_check(card != null and _whole_in_view(card),
			"Build it clicked %s: the card it opened in view (%s)"
				% ["from the conversation's start" if from_start else "at its end", _where(card)])
		assistant._stop(true, "built 12 bricks")
		await _frames(6)

	print("\na step Claude makes, heard while a press is read")
	var connector := ClaudeConnector.new()
	root.add_child(connector)
	_panel.use_connector(connector)
	await _frames(4)
	var hears := Button.new()
	hears.text = "a press"
	hears.position = Vector2(700, 300)
	hears.size = Vector2(160, 40)
	root.add_child(hears)
	var steps: Array[int] = [0]
	hears.pressed.connect(func() -> void:
		steps[0] += 1
		_panel._on_claude_called("add_brick",
			{"part": "3001", "colour": 4, "why": "the wall's next course, step %d" % steps[0]}))
	for round: int in 6:
		await _click(hears)
		await _frames(12)
		var card: Control = _panel._run
		_check(card != null and _foot_in_view(card),
			"step %d: Claude's card, grown by it, in view to its foot (%s)" % [steps[0], _where(card)])
	connector.queue_free()

	print("\n%s" % ("all checks passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _at_end() -> bool:
	var bar: ScrollBar = _panel._scroll.get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 1.0


func _whole_in_view(control: Control) -> bool:
	return _panel._scroll.get_global_rect().grow(1.0).encloses(control.get_global_rect())


func _foot_in_view(control: Control) -> bool:
	var view: Rect2 = _panel._scroll.get_global_rect()
	var end: float = control.get_global_rect().end.y
	return end <= view.end.y + 1.0 and end > view.position.y


func _where(control: Control) -> String:
	var bar: ScrollBar = _panel._scroll.get_v_scroll_bar()
	if control == null:
		return "none"
	var view: Rect2 = _panel._scroll.get_global_rect()
	return "its foot at %d, the view's at %d; scrolled %d of %d" % [
		control.get_global_rect().end.y, view.end.y, bar.value, bar.max_value - bar.page]


## A click on [param control] where it is drawn, as the mouse sends one.
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center() \
		* (Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _frames(3)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await _frames(2)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
