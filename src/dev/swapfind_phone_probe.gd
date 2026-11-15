## Find and replace by finger, on a phone (swapfind, APP_UX8 #9).
##
##   godot --path . --resolution 390x844 --script src/dev/swapfind_phone_probe.gd
##
## Laid out for a phone at a browser's scale (as smalls2_probe holds it),
## driven by fingers as the window hands them over (InputEventScreenTouch;
## the engine raises its own click from them). The car (swapfind_car.mpd)
## open: More, Edit, Find and replace… in taps, the bar inside the screen
## with every target in it 44 points or more each way, its rows too once a
## find fills them; 3023 typed on the keyboard, Black chosen from the find's
## colours and Dark Bluish Grey from the replace's, each list opened by a
## tap; Replace tapped, and the car's every Black 3023, its sub-models' too,
## Dark Bluish Grey in one undo step; Close tapped, the bar gone; the undo
## gives the file opened to the byte.
extends SceneTree

const CAR := "res://src/dev/fixtures/swapfind_car.mpd"
const LEAST := Phone.TARGET - 0.5
const BLACK := 0
const DARK_BLUISH_GREY := 72

var _failures: int = 0
var _main: Node
var _phone: Control
var _world: BrickWorld
var _builder: Builder
var _shell: Shell
var _store: ModelStore
var _presses: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("swapfind_phone_probe: needs a window")
		quit(1)
		return
	create_timer(900.0).timeout.connect(func() -> void:
		print("swapfind_phone_probe: not finished in time")
		quit(1))
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Phone._on = 1
	Phone._wide = false
	Input.emulate_touch_from_mouse = true
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_phone = _main.get("_phone")
	if _phone != null:
		_phone.set("holds_scale", true)
	for link: Dictionary in root.size_changed.get_connections():
		var call: Callable = link["callable"]
		if call.get_method() == &"_match_screen_density":
			root.size_changed.disconnect(call)
	var main_script: GDScript = _main.get_script()
	root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
		ShellPrefs.interface_size(), true)
	await _frames(20)
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	_store = _main.get("_store")
	_store.keeps = false
	print("swapfind_phone_probe: a %s window laid out for a phone, %.3f units to the point"
		% [DisplayServer.window_get_size(), _pt()])
	if not _check("the phone's layout is made", _phone != null):
		_finish()
		return
	var text: String = FileAccess.get_file_as_string(CAR)
	_main.call("clear_model")
	await _frames(4)
	var model_bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await model_bar.open_text_with_progress(text, "model")
	model_bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(20)
	_check("the car open (%d parts, %d Black 3023)" % [_world.brick_count(), _count(BLACK)],
		_count(BLACK) == 4)
	await _by_finger(text)
	_finish()


func _by_finger(text: String) -> void:
	_presses = 0
	await _tap(_middle(_named("phone_more")))
	await _frames(10)
	if not _check("More opens (%s)" % _sheet(), _sheet() == "More"):
		return
	await _tap(_middle(_named("phone_section_edit")))
	await _frames(10)
	var row: Control = _named("phone_row_find_replace")
	if not _check("More › Edit has Find and replace… (%s)" % (row.call("get_text")
			if row != null and row.has_method("get_text") else row), row != null):
		return
	var dragged: int = 0
	var list: ScrollContainer = _scroll_of(row)
	if list != null and not list.get_global_rect().grow(1.0).encloses(row.get_global_rect()):
		# A finger's drag up the list, as a person brings a row into sight.
		list.ensure_control_visible(row)
		dragged = 1
		await _frames(6)
	_check("its row a fingertip each way (%.0f x %.0f pt)" % [row.size.x / _pt(),
		row.size.y / _pt()], minf(row.size.x, row.size.y) / _pt() >= LEAST)
	await _tap(_middle(row))
	await _frames(20)
	var bar: PanelContainer = _main.get("_find_replace_made")
	if not _check("Find and replace… opens the bar in %d taps and %d drag (%s)" % [_presses, dragged,
			_sheet()], bar != null and bar.is_visible_in_tree() and _presses <= 3):
		return
	var screen: Rect2 = root.get_visible_rect()
	_check("the bar inside the screen (%s in %s)" % [bar.get_global_rect(), screen],
		screen.grow(1.0).encloses(bar.get_global_rect()))
	_check("every target in the bar 44 points or more (%s)" % _small_in(bar), _small_in(bar).is_empty())
	var find: LineEdit = bar.get("_find_part")
	await _tap(_middle(find))
	_check("a tap on Find puts the keyboard's words there", find.has_focus())
	await _type("3023")
	await create_timer(0.5).timeout
	await _frames(6)
	await _pick(bar.get("_find_colour"), BLACK)
	await _pick(bar.get("_into_colour"), DARK_BLUISH_GREY)
	await _frames(6)
	var asked: Dictionary = bar.call("asked")
	var into: Dictionary = bar.call("into")
	_check("3023 in Black to find, Dark Bluish Grey to put (%s; %s)" % [asked, into],
		str(asked["part"]) == "3023" and int(asked["color"]) == BLACK
		and int(into["color"]) == DARK_BLUISH_GREY)
	_check("its rows a fingertip too once filled (%s)" % _small_in(bar), _small_in(bar).is_empty())
	var replace: Button = bar.get("_replace")
	var depth: int = _builder.history_depth()
	await _tap(_middle(replace))
	await _frames(20)
	_check("Replace tapped: the car's every Black 3023 Dark Bluish Grey (%d left, %d made), one undo step (%d)"
		% [_count(BLACK), _count(DARK_BLUISH_GREY), _builder.history_depth() - depth],
		_count(BLACK) == 0 and _count(DARK_BLUISH_GREY) == 4 and _builder.history_depth() == depth + 1)
	await _tap(_middle(bar.get("_close")))
	await _frames(10)
	_check("Close tapped: the bar away", not bar.is_visible_in_tree())
	_shell.run("undo")
	await _frames(20)
	_check("its undo: the file opened, to the byte", _store.to_text(_store.title, true) == text)
	print("  presses in all: %d" % _presses)


## An OptionButton's list opened by a tap, and [param code]'s row chosen in
## it as a tap on the row chooses it.
func _pick(options: OptionButton, code: int) -> void:
	await _tap(_middle(options))
	await _frames(8)
	var popup: PopupMenu = options.get_popup()
	_check("a tap on %s opens its list" % options.accessibility_name, popup.visible)
	var index: int = -1
	for n: int in options.item_count:
		if int(options.get_item_metadata(n)) == code:
			index = n
	if index >= 0:
		popup.index_pressed.emit(index)
		popup.hide()
		await _frames(6)
	_check("%s: %s chosen" % [options.accessibility_name, options.get_item_text(maxi(index, 0))],
		index >= 0 and options.selected == index)


## The bar's targets under a fingertip each way, by name and size in points.
func _small_in(bar: Control) -> String:
	var small := PackedStringArray()
	for node: Node in bar.find_children("*", "", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (control is BaseButton or control is LineEdit):
			continue
		var r: Rect2 = control.get_global_rect()
		if minf(r.size.x, r.size.y) / _pt() < LEAST:
			var words: String = (control as Button).text if control is Button else control.name
			small.append("%s %.0f x %.0f" % [words.left(24), r.size.x / _pt(), r.size.y / _pt()])
	return ", ".join(small)


func _count(colour: int) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3023b" and brick.color_code == colour:
			count += 1
	return count


func _scroll_of(control: Control) -> ScrollContainer:
	var up: Node = control.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	return up as ScrollContainer


func _named(name: String) -> Control:
	return _phone.call("controls_by_name").get(name) as Control


func _sheet() -> String:
	return str((_phone.call("state") as Dictionary).get("sheet", "")) if _phone != null else ""


func _middle(control: Control) -> Vector2:
	return control.get_global_rect().get_center() if control != null else Vector2(-100, -100)


func _tap(at: Vector2) -> void:
	_presses += 1
	_touch(at, true)
	await _frames(2)
	_touch(at, false)
	await _frames(8)


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


## Keys of the on-screen keyboard, one press each.
func _type(text: String) -> void:
	for letter: String in text:
		for down: bool in [true, false]:
			var key := InputEventKey.new()
			key.pressed = down
			key.unicode = letter.unicode_at(0)
			key.keycode = OS.find_keycode_from_string(letter.to_upper())
			Input.parse_input_event(key)
			await _frames(2)
	await _frames(4)


func _pt() -> float:
	return Phone.per_point(root)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _finish() -> void:
	print("\nswapfind_phone_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	if _world != null:
		_world.clear()
	quit(1 if _failures > 0 else 0)
