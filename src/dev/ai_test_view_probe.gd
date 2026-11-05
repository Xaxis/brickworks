## What Test finds on Settings' AI page ends in view (laidout2).
##
##   godot --path . --resolution 1280x640 --script src/dev/ai_test_view_probe.gd
##   tools/probe.sh ai_test_view_probe
##
## The page scrolled Test's answer into view the moment it was put in
## (ControlsDialog, ai.tested), before the layout had given it its size or
## its place: in a short window, or on a phone, the answer was left below
## the view, wholly or by its last lines.
##
## Here, in a window short enough that the page scrolls, Settings, AI with
## a model on a server of the person's own: Test is scrolled to the foot of
## the view, as a person scrolls until they see it, and clicked as the mouse
## clicks it. The provider's answer comes in as an HTTPRequest's does, in a
## call deferred to the end of a frame, one to four frames after the click,
## each time with a detail of another length (what the provider said). 24
## times, and each time what Test found must end whole in view.
extends SceneTree

## The answer, when the probe says so: as ModelTest.run gives it.
class Answers extends ModelTest:
	signal came(found: Dictionary)

	func run(_provider: Provider) -> Dictionary:
		return await came


const TRIES := 24
const SAID := "One tool call, as asked: add_brick with part 3001 at the origin, in red. "

var _failures: int = 0
var _main: Node
var _controls: ControlsDialog
var _ai: AiSettings
var _page: ScrollContainer
var _answers: Answers


func _initialize() -> void:
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no window — this probe needs one")
		quit(1)
		return
	await process_frame
	# A model on a server of the person's own, which needs no key: nothing
	# is asked of it here, as the answers are the probe's.
	ProviderSettings.set_who(ProviderSettings.WHO_KEY)
	ProviderSettings.choose("custom", "probe-model", "http://127.0.0.1:9/v1")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	(_main.get("_store") as ModelStore).keeps = false
	_controls = _main.get("_controls")
	_ai = _controls.ai
	_page = _controls.get("_ai_page")
	var tester: ModelTest = _ai.get("_tester")
	_ai.remove_child(tester)
	tester.queue_free()
	_answers = Answers.new()
	_ai.add_child(_answers)
	_ai.set("_tester", _answers)

	(_main.get("_shell") as Shell).run("settings")
	await _frames(10)
	_controls.open_ai()
	await _frames(30)
	var bar: ScrollBar = _page.get_v_scroll_bar()
	print("  the window %s, the page %d tall in a view of %d"
		% [DisplayServer.window_get_size(), bar.max_value, bar.page])
	if not _check("the AI page is open, a key of your own chosen, and scrolls in this window",
			_page.is_visible_in_tree() and _ai.test_button.is_visible_in_tree()
			and bar.max_value > bar.page + 40.0):
		_finish()
		return

	var seen: int = 0
	for n: int in TRIES:
		# Test at the foot of the view, as a person scrolls until it shows.
		var foot: float = _ai.test_button.get_global_rect().end.y \
			- _page.get_global_rect().position.y + _page.scroll_vertical
		_page.scroll_vertical = roundi(foot - _page.size.y + 4.0)
		await _frames(4)
		await _click(_ai.test_button)
		await _frames(1 + n % 4)
		var lines: int = [2, 6, 3, 9, 1, 5, 8, 4][n % 8]
		_answers.came.emit.call_deferred({"ok": true, "tools": true, "pictures": true,
			"words": ModelTest.summary(true, true), "detail": SAID.repeat(lines).strip_edges()})
		await _frames(12)
		var shown: Control = _ai.get("_test_detail")
		if not shown.visible:
			shown = _ai.get("_test_said")
		var ok: bool = _whole_in_view(shown)
		seen += 1 if ok else 0
		_check("Test %d, its answer %d sentences long: in view (%s)" % [n + 1, lines, _where(shown)], ok)
	print("\n  what Test found ended whole in view %d times in %d" % [seen, TRIES])
	_finish()


func _finish() -> void:
	print("\n%s" % ("ai test view: what Test finds ends in view, every time" if _failures == 0
		else "ai test view: %d FAILED" % _failures))
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _whole_in_view(control: Control) -> bool:
	return _page.get_global_rect().grow(1.0).encloses(control.get_global_rect())


func _where(control: Control) -> String:
	var bar: ScrollBar = _page.get_v_scroll_bar()
	var view: Rect2 = _page.get_global_rect()
	var rect: Rect2 = control.get_global_rect()
	return "from %d to %d, the view from %d to %d; scrolled %d of %d" % [rect.position.y, rect.end.y,
		view.position.y, view.end.y, bar.value, bar.max_value - bar.page]


## A click on [param control] where it is drawn, as the mouse sends one.
func _click(control: Control) -> void:
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
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


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
