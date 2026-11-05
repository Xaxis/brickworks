## A phone's or a tablet's parts list opens at its search, whatever it lists
## and however it was made (laidout2, listtop).
##
##   godot --path . --resolution 844x390 --script src/dev/bin_list_top_probe.gd -- --phone
##   tools/probe.sh bin_list_top_probe --phone
##
## By hand at the other sizes, upright and on its side, a tablet's laid out
## wide (its short side 600 points or more): PROBE_SIZE=390x844, 430x932,
## 768x1024 and 1024x768 tools/probe.sh bin_list_top_probe --phone.
##
## For a finger the rows over the parts (the head, the search, the chips)
## scroll away with them, and a new list is put at its search, so that a
## phone on its side shows parts and not only the rows over them
## (PartsBin._to_list_top).
##
## laidout2's version of this probe tapped each chip where it was laid out:
## the chips' own row scrolls, and from Tile on they are on its second line,
## out of its sight. The tap fell through to the part tile under it, took
## that part in hand, and the sheet went with it; every list after that was
## measured in a sheet put away, whose layout no longer runs, 7 units off,
## 13 checks in 37 (listtop). Here a chip is tapped only where a finger can
## see it, and the sheet must still be open each time.
##
## Here, at a browser's scale, the Parts sheet opened as a finger opens it:
## its first list, made while it was closed, at its search. 36 new lists
## made as a person makes them, a search typed (many parts, a few, one,
## none) or a chip tapped: each at its search once it has settled, and
## still there 600 ms later as the bin fills in. Upright, with a few parts
## listed, the sheet's handle swiped up to the whole screen: the list still
## at its search. And six lists made while the sheet was put away, as the
## app makes them (a category shown, a part made goes to Custom), then the
## sheet opened again: each at its search.
extends SceneTree

const SEARCHES: Array[String] = ["brick 2 x 4", "3001", "tile 1 x 2 grille", "slope", "zzqx",
	"plate 1 x 1 round", "technic pin", "arch 1 x 6", "wheel", "3024", "door", "minifig torso"]
const TRIES := 36
const SHUT_TRIES := 6

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _scroll: ScrollContainer
var _search: LineEdit
var _parts: Control
var _phone: PhoneShell
var _at := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	var window: Vector2i = DisplayServer.window_get_size()
	var wide: bool = mini(window.x, window.y) >= Phone.NARROW
	Phone._on = 1
	Phone._wide = wide
	Input.emulate_touch_from_mouse = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	_phone = _main.get("_phone")
	if not wide:
		# A phone draws at a browser's scale, as field_drag_probe holds it.
		_phone.set_process(false)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
	await _frames(20)
	_bin = _main.get("_bin")
	_scroll = _bin.get("_scroll")
	_search = _bin.get("_search")
	_parts = _phone.get("_parts")
	var parts_button: Control = _phone.get("_tool_buttons").get("parts")
	await _tap(parts_button)
	await _wait(600)
	print("  the window %s, %s units, laid out for a %s; the Parts sheet %s, %s" % [window,
		root.get_visible_rect().size, "tablet" if wide else "phone", _parts.get("state"),
		_parts.get_global_rect()])
	if not _check("the Parts sheet open, laid out for a finger, its search in the list",
			_bin.by_finger and _parts.visible and _scroll.is_ancestor_of(_search)):
		_finish()
		return
	_at_search("the sheet opened: its first list, made while it was closed, at its search")

	var chips: Array[Button] = []
	for child: Node in (_bin.get("_category_row") as Node).get_children():
		if child is Button and (child as Button).is_visible_in_tree():
			chips.append(child)
	var topped: int = 0
	for n: int in TRIES:
		var what: String
		if n % 3 == 2 and not chips.is_empty():
			var chip: Button = chips[floori(n / 3.0) % chips.size()]
			what = "the chip %s tapped" % chip.text
			if not _check("%d: the chip %s brought where a finger sees it" % [n + 1, chip.text],
					await _reach(chip)):
				continue
			await _tap(chip)
		else:
			var words: String = SEARCHES[n % SEARCHES.size()]
			what = "\"%s\" typed" % words
			_search.grab_focus()
			_search.text = words
			_search.text_changed.emit(words)
		await _wait(600)
		if not _check("%d: %s, the sheet still open" % [n + 1, what], _parts.visible):
			_finish()
			return
		var first: float = _off()
		await _wait(600)
		var ok: bool = absf(first) <= 1.5 and absf(_off()) <= 1.5
		topped += 1 if ok else 0
		_check("%d: %s, %d listed: at its search once settled and 600 ms on (%d off, then %d; scrolled %d of %d)"
			% [n + 1, what, (_bin.get("_grid") as Node).get_child_count(), first, _off(),
				_scroll.scroll_vertical, _scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page],
			ok)
	print("\n  a new list opened at its search %d times in %d" % [topped, TRIES])

	# Upright, a few parts listed and the sheet swiped up to the whole
	# screen: the list taller, and the room under the parts with it.
	if _parts.get("state") == "half":
		_search.text = "door"
		_search.text_changed.emit("door")
		await _wait(600)
		var was: float = _parts.size.y
		await _swipe_up()
		await _wait(600)
		_check("the sheet swiped up from half (%d) to the whole screen (%d), %d listed: still at its search (%d off)"
			% [was, _parts.size.y, (_bin.get("_grid") as Node).get_child_count(), _off()],
			_parts.get("state") == "full" and absf(_off()) <= 1.5)

	# Lists made while the sheet is put away, as the app makes them: a
	# category shown, a part just made shown under Custom.
	var categories: Array[String] = []
	for chip: Button in chips:
		var name: String = str(chip.get_meta("category", ""))
		if not name.is_empty():
			categories.append(name)
	for n: int in SHUT_TRIES:
		await _tap(_parts.get("done"))
		await _wait(300)
		if not _check("put away %d: the sheet closed" % (n + 1), not _parts.visible):
			break
		var name: String = categories[(n * 3 + 1) % categories.size()]
		_search.text = SEARCHES[n * 2 % SEARCHES.size()] if n % 2 == 0 else ""
		_bin.show_category(name)
		await _wait(300)
		await _tap(parts_button)
		await _wait(600)
		_at_search("put away %d: %s shown while it was, \"%s\" in the search, then opened: at its search"
			% [n + 1, name, _search.text])
	_finish()


## The search's top against the list's: 0 when the list is at its search.
func _off() -> float:
	return _search.get_global_rect().position.y - _scroll.get_global_rect().position.y


func _at_search(what: String) -> bool:
	return _check("%s (%d off, %d listed, scrolled %d of %d)" % [what, _off(),
		(_bin.get("_grid") as Node).get_child_count(), _scroll.scroll_vertical,
		_scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page], absf(_off()) <= 1.5)


func _finish() -> void:
	print("\n%s" % ("bin list top: a new list opens at its search, every time" if _failures == 0
		else "bin list top: %d FAILED" % _failures))
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## [param chip] where a finger sees it, as a finger's drags bring it: the
## list scrolled to the chips' row, and the row's own scroll to the chip.
## Whether its middle is then in sight in both.
func _reach(chip: Button) -> bool:
	var row: ScrollContainer = _bin.get("_category_scroll")
	var on_row: float = chip.get_global_rect().get_center().y - row.get_global_rect().position.y \
		+ row.scroll_vertical
	row.scroll_vertical = roundi(on_row - row.size.y * 0.5)
	var down: float = row.get_global_rect().get_center().y - _scroll.get_global_rect().position.y \
		+ _scroll.scroll_vertical
	_scroll.scroll_vertical = roundi(down - _scroll.size.y * 0.5)
	await _wait(100)
	var middle: Vector2 = chip.get_global_rect().get_center()
	return row.get_global_rect().has_point(middle) and _scroll.get_global_rect().has_point(middle)


## The sheet's handle dragged up to the top of the screen, as a finger does.
func _swipe_up() -> void:
	var handle: Control = _parts.get("handle")
	var from: Vector2 = root.get_final_transform() * (handle.get_screen_transform() * (handle.size * 0.5))
	_touch_at(from, true)
	await _frames(3)
	for step: int in 12:
		var to := Vector2(from.x, lerpf(from.y, 4.0, (step + 1) / 12.0))
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = to
		drag.relative = to - _at
		_at = to
		Input.parse_input_event(drag)
		await _frames(2)
	_touch_at(_at, false)
	await _frames(4)


## A finger's tap on [param control] where it is drawn.
func _tap(control: Control) -> void:
	_touch_at(root.get_final_transform() * (control.get_screen_transform() * (control.size * 0.5)), true)
	await _frames(3)
	_touch_at(_at, false)
	await _frames(2)


func _touch_at(at: Vector2, pressed: bool) -> void:
	_at = at
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Frames for [param ms] by the clock, ten at least.
func _wait(ms: float) -> void:
	var began: int = Time.get_ticks_msec()
	await _frames(10)
	while Time.get_ticks_msec() - began < ms:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
