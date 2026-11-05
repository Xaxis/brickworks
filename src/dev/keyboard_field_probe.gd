## The field typed in on a phone ends above the on-screen keyboard (laidout2).
##
##   godot --path . --resolution 390x844 --script src/dev/keyboard_field_probe.gd -- --phone
##   tools/probe.sh keyboard_field_probe --phone
##
## The keyboard coming up lays the dialog out again in the room above it
## (TouchSizing._place), and the field being typed in was scrolled into view
## right then (_show_focus), before the layout had made what scrolls round
## it any shorter: measured against the room the keyboard had not yet taken,
## a field low in the dialog was left where it was, under the keyboard.
##
## Here, in a phone's layout at a browser's scale, Settings, AI with a model
## on a server of the person's own, its fields low in the page, Model and
## Max output: each in turn put low in the view, where the keyboard will
## come up over it, tapped as a finger taps it, and the keyboard brought up
## as a browser tells the app of it (the visual viewport 40% shorter, read
## in TouchSizing's frame), then put away. 24 times, and each time the
## field must end in the page's view and above the keyboard.
extends SceneTree

const TRIES := 24

var _failures: int = 0
var _main: Node
var _touch: TouchSizing
var _controls: ControlsDialog
var _page: ScrollContainer
var _at := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	Phone._on = 1
	Phone._wide = false
	# A touch screen's: the app hears its touches as a browser's.
	Input.emulate_touch_from_mouse = true
	ProviderSettings.set_who(ProviderSettings.WHO_KEY)
	ProviderSettings.choose("custom", "probe-model", "http://127.0.0.1:9/v1")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	# A phone draws at a browser's scale, as field_drag_probe holds it.
	(_main.get("_phone") as Node).set_process(false)
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
		ShellPrefs.interface_size(), true)
	await _frames(20)
	_touch = _main.get("_touch")
	_controls = _main.get("_controls")
	_page = _controls.get("_ai_page")
	(_main.get("_shell") as Shell).run("settings")
	await _frames(10)
	_controls.open_ai()
	await _frames(30)
	var ai: AiSettings = _controls.ai
	var fields: Array[LineEdit] = [ai.model_filter, ai.max_out.get_line_edit()]
	var bar: ScrollBar = _page.get_v_scroll_bar()
	print("  the window %s, %s units; the page %d tall in a view of %d" % [
		DisplayServer.window_get_size(), root.get_visible_rect().size, bar.max_value, bar.page])
	if not _check("a phone's layout, Settings' AI page open over the model, scrolling, its fields shown",
			_touch != null and _page.is_visible_in_tree() and bar.max_value > bar.page
			and fields.all(func(field: LineEdit) -> bool: return field.is_visible_in_tree())):
		_finish()
		return

	# In points, as dialogs_flow's keyboard is: 40% of a phone's height.
	var keys: float = roundf(root.get_visible_rect().size.y / Phone.per_point(root) * 0.4)
	var above: int = 0
	var tapped: int = 0
	var lows: int = 0
	for n: int in TRIES:
		var field: LineEdit = fields[n % fields.size()]
		# Low in the view, where the keyboard will come up over it.
		var low: float = [0.94, 0.8, 0.7, 0.86][n % 4]
		var down: float = field.get_global_rect().end.y - _page.get_global_rect().position.y \
			+ _page.scroll_vertical
		_page.scroll_vertical = roundi(down - _page.size.y * low)
		await _frames(4)
		var name: String = "Model" if field == ai.model_filter else "Max output"
		var under: bool = field.get_global_rect().end.y > root.get_visible_rect().size.y \
			- keys * Phone.per_point(root)
		_touch_at(_window_at(field, field.size * 0.5), true)
		await _frames(3)
		_touch_at(_at, false)
		await _frames(8)
		if not _check("%d: %s tapped is typed in" % [n + 1, name], field.has_focus()
				and _touch.typing() == field):
			continue
		tapped += 1
		# The keyboard up, heard in TouchSizing's frame as a browser tells it.
		await process_frame
		_touch.keyboard = keys
		_touch.call("_place_all")
		await _frames(12)
		var rect: Rect2 = field.get_global_rect()
		var room: Rect2 = _touch.room(_controls)
		var view: Rect2 = _page.get_global_rect()
		var ok: bool = view.grow(1.0).encloses(rect) and rect.end.y <= room.end.y + 1.0
		above += 1 if ok else 0
		_check("%d: %s, %d%% down the view%s, ends above the keyboard (its foot at %d, the keyboard's top at %d, the view's foot at %d)"
			% [n + 1, name, roundi(low * 100.0), ", where the keyboard comes up" if under else "",
				rect.end.y, room.end.y, view.end.y], ok)
		lows += 1 if under else 0
		# Put away: the field let go, and the keyboard down with it.
		field.release_focus()
		await process_frame
		_touch.keyboard = 0.0
		_touch.call("_place_all")
		await _frames(8)
	print("\n  the field typed in ended above the keyboard %d times in %d (%d tapped)" % [above, TRIES, tapped])
	_check("each field tapped was typed in, and %d of them sat where the keyboard came up" % lows,
		tapped == TRIES and lows >= TRIES / 2)
	_finish()


func _finish() -> void:
	print("\n%s" % ("keyboard field: the field typed in ends above the keyboard, every time" if _failures == 0
		else "keyboard field: %d FAILED" % _failures))
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## A finger down or up at [param at], in the window's input.
func _touch_at(at: Vector2, pressed: bool) -> void:
	_at = at
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)


## [param local] in [param control] in the window's input.
func _window_at(control: Control, local: Vector2) -> Vector2:
	return root.get_final_transform() * (control.get_screen_transform() * local)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
