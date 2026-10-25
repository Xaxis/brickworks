## Does the layout for a finger stop drawing when nothing changes?
##
##   godot --path . --resolution 768x1024 --script src/dev/phone_idle_probe.gd
##
## m174's tablet check died on its first picture: page.screenshot waited 30 s
## for a frame just after the layout for a finger showed (2026-10-25). The
## app drew the whole window every frame there, standing still: the foot
## row's colour in hand redrew itself every frame (PhoneShell.RowPicture),
## and the hint over the model was laid out again every frame, set to
## nothing and back. A frame drawn for nothing is the whole window drawn
## (IdleDraw), and a tablet in a browser drawing in software took 2 to 5 s a
## frame, so the app froze from the moment it showed; signed in behind the
## model since 8bf42944, that is the moment it is used. On a phone's own
## graphics it is a battery spent for nothing.
##
## The layout for a finger is made here in a window, as Phone.on() makes it
## on a touch screen in a browser (wide, for a tablet, then not, for a
## phone): once it has settled, standing still draws at most a frame a
## second, as idle_probe asks of the desktop's; the colour in hand changed is drawn, and its picture in the
## row is the new colour; something said over the model is drawn.
extends SceneTree

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var wide: bool = not OS.get_cmdline_user_args().has("--phone")
	# The layout for a finger, as a touch screen in a browser gets it.
	Phone._on = 1
	Phone._wide = wide
	OS.low_processor_usage_mode = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 30:
		await process_frame
	var phone: PhoneShell = _main.get("_phone")
	_ok(phone != null, "the layout for a finger is made (%s)" % ("a tablet's" if wide else "a phone's"))
	if phone == null:
		_finish()
		return
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	# Settled: whatever the start draws, drawn.
	await _quiet(2.0, 30.0)

	var drawn: int = await _drawn_in(2.0)
	_ok(drawn <= 2, "standing still, %d frames drawn in 2 s (one a second at most, as idle_probe has it)" % drawn)

	var builder: Builder = _main.get("_builder")
	var before: int = Engine.get_frames_drawn()
	builder.held_color = 1 if builder.held_color != 1 else 4
	for _n: int in 10:
		await process_frame
	var picture: Control = null
	for node: Node in phone.find_children("*", "", true, false):
		if node.get_script() != null and str(node.get("kind")) == "colour":
			picture = node as Control
	_ok(Engine.get_frames_drawn() > before, "the colour in hand changed is drawn")
	_ok(picture != null and picture.get("_drawn") == Color(
		(_main.get("_library") as PartLibrary).color(builder.held_color).shown, 1.0),
		"...the row's colour drawn as the new one")
	await _quiet(1.0, 10.0)
	before = Engine.get_frames_drawn()
	(_main.get("_bar") as ModelBar).say("a probe's words over the model")
	for _n: int in 10:
		await process_frame
	_ok(Engine.get_frames_drawn() > before, "something said over the model is drawn")
	await _quiet(1.0, 10.0)
	drawn = await _drawn_in(2.0)
	_ok(drawn <= 2, "...and then still again: %d frames drawn in 2 s" % drawn)
	_finish()


## Frames drawn in [param seconds] with nothing done.
func _drawn_in(seconds: float) -> int:
	var from: int = Engine.get_frames_drawn()
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
	return Engine.get_frames_drawn() - from


## Waits until [param still] seconds pass with no frame drawn, at most
## [param most]. Whether it got there.
func _quiet(still: float, most: float) -> bool:
	var began: int = Time.get_ticks_msec()
	var last: int = Engine.get_frames_drawn()
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < int(most * 1000.0):
		await process_frame
		if Engine.get_frames_drawn() != last:
			last = Engine.get_frames_drawn()
			since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - since >= int(still * 1000.0):
			return true
	return false


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failures += 1
		print("  FAIL ", what)


func _finish() -> void:
	print("\nphone idle probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures > 0 else 0)
