## What a person types into a field is kept, however busy the app is.
##
##   godot --path . --resolution 1400x900 --script src/dev/typing_probe.gd
##
## In a window, since a headless one has no pointer over it to click with.
##
## A release check (tools/web/tabs_flow.mjs, rename) clicked the model's
## name, pressed Ctrl+A, typed a name, pressed Enter, waited half a second
## and pressed Escape to give the keys back to the model. On a loaded
## machine, right after the tab had opened its model, the name stayed as it
## was. The engine hands the app every key that arrived since the last
## frame, in order, at the start of the next one; a busy tab's frame is
## longer than half a second, so Enter and Escape came in one frame. Enter's
## end of the typing (FocusGuard) waited for the end of that frame, and the
## Escape before it put back the name the typing began with: the name was
## typed, kept by Enter, and then thrown away. A person at a busy tab who
## types a name, presses Enter and then Escape loses it the same way.
##
## So here every key goes in before one frame, as a busy frame has them,
## and the name must be what was typed. Escape before Enter still puts the
## old name back, as it is meant to.
extends SceneTree

var _failures: int = 0
var _field: LineEdit
var _store: ModelStore
## What Enter was given, each time.
var _entered: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var bar: ModelBar = main.get("_bar")
	_store = main.get("_store")
	_field = bar._name
	_field.text_submitted.connect(func(text: String) -> void: _entered.append(text))
	_name_it("Typing Probe Before")

	print("\nclick, Ctrl+A, a name, Enter and Escape, all in one busy frame")
	_entered = []
	_click_now()
	_key_now(KEY_A, true)
	_type_now("Typing Probe Kart")
	_key_now(KEY_ENTER)
	_key_now(KEY_ESCAPE)
	await _frames(6)
	_check("every key arrived: Enter was given \"%s\"" % ", ".join(_entered),
		_entered == PackedStringArray(["Typing Probe Kart"]))
	_check("the name is what was typed: \"%s\"" % _field.text, _field.text == "Typing Probe Kart")
	_check("...and the model is called it: \"%s\"" % _store.title, _store.title == "Typing Probe Kart")
	_check("...and the field has given the keys back", not _field.has_focus())

	print("\nthe same, a frame for every key")
	_name_it("Typing Probe Before")
	_click_now()
	await _frames(2)
	_key_now(KEY_A, true)
	await _frames(2)
	for c: String in "Typing Probe Tree":
		_type_now(c)
		await _frames(1)
	_key_now(KEY_ENTER)
	await _frames(2)
	_key_now(KEY_ESCAPE)
	await _frames(6)
	_check("the name is what was typed: \"%s\"" % _field.text, _field.text == "Typing Probe Tree")

	print("\nEscape before Enter still puts the old name back, busy or not")
	_name_it("Typing Probe Before")
	_click_now()
	_key_now(KEY_A, true)
	_type_now("Thrown Away")
	_key_now(KEY_ESCAPE)
	await _frames(6)
	_check("in one frame: \"%s\"" % _field.text, _field.text == "Typing Probe Before"
		and _store.title == "Typing Probe Before" and not _field.has_focus())
	_click_now()
	await _frames(2)
	_type_now("Thrown Away")
	await _frames(2)
	_key_now(KEY_ESCAPE)
	await _frames(6)
	_check("a frame apart: \"%s\"" % _field.text, _field.text == "Typing Probe Before"
		and not _field.has_focus())

	print("\nEnter, more typing, then Escape: back to what Enter kept")
	_click_now()
	_key_now(KEY_A, true)
	_type_now("Typing Probe Kept")
	_key_now(KEY_ENTER)
	_click_now()
	_key_now(KEY_END)
	_type_now(" and more")
	_key_now(KEY_ESCAPE)
	await _frames(6)
	_check("in one frame: \"%s\"" % _field.text, _field.text == "Typing Probe Kept")

	_done()


func _name_it(name: String) -> void:
	_field.text = name
	_field.text_changed.emit(name)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## A press and release on the name field, queued for the next frame.
func _click_now() -> void:
	var at: Vector2 = _field.get_global_rect().get_center()
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	if window.x > 0.0 and window.y > 0.0:
		at *= window / rect
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)


func _key_now(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)


func _type_now(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper()) if c != " " else KEY_SPACE
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("what is typed into a field is kept, however busy the app is")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
