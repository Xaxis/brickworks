## Does a tablet's layout keep inside its window with a tools' panel open
## beside the model, the browser's warning about keeping models up and the
## app busy, and does the panel's own way out put it away?
##
##   godot --path . --resolution 1024x768 --script src/dev/tablet_fit_probe.gd
##   ... -- --shots=DIR    the window at each step, to look at
##
## checkhealth (2026-10-31): dialogs_flow at 1024 x 768 on brickworks.diy
## found Colour the hidden parts open beside the model on a tablet with the
## warning's Download my models and This one for Studio, and the busy
## line's Cancel, run off the window's right edge, and the panel not put
## away by its Close, which was under the parts panel's Done. Here the
## window is laid out for a finger as a tablet held sideways is (Phone,
## wide), the warning shown with its words as the live site says them, a
## job begun so the busy line shows, the parts panel opened with its button
## in the foot row, and Colour the hidden parts opened as More opens it.
## Then:
##   the window's layout is no wider than the window, with the panel open
##   and after;
##   every button of the warning, the busy line and the panel is inside the
##   window's width;
##   the busy line shows, its Cancel under none of the phone's own controls
##   (it was under the foot's row of tools);
##   no line of the panel is narrower than its longest word (its heading
##   went one letter a line, the layout squeezed);
##   the parts panel is put away for the tools' column, the panel's Close is
##   under none of the phone's own controls, and a finger's tap on it puts
##   the panel away; the parts panel then comes back.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shots: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	Phone._on = 1
	Phone._wide = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(20)
	var window: Rect2 = root.get_visible_rect()
	print("\n  the window: %d x %d units, laid out for a tablet" % [roundi(window.size.x),
		roundi(window.size.y)])
	var phone: PhoneShell = _main.get("_phone")
	if not _check("the window is laid out for a tablet", phone != null and Phone.wide()):
		quit(1)
		return

	# The warning, as a browser that would not keep the models has it said.
	var offer: StorageOffer = _main.get("_storage_offer")
	(offer.get("_words") as Label).text = ("Your models are kept only in this browser, and it "
		+ "would not agree to keep them, so it may clear them when it runs short of space. Your "
		+ "account keeps no copy. Download your models to keep a copy of your own.")
	offer.visible = true
	# And the app busy, as Colour the hidden parts is while it looks.
	var job: Working.Job = Working.begin("Looking at Touch 1024x768 65215 again from every side…",
		0, true)
	await job.shown()
	# The parts out, by their button in the foot row.
	var parts: PhoneShell.Sheet = phone.get("_parts")
	await _tap((phone.get("_tool_buttons")["parts"] as Control).get_global_rect().get_center())
	await _frames(20)
	_check("the parts panel is out", parts.is_open())
	_measure("the parts out, the warning up and the app busy", offer)
	await _shot("1_before")

	var panel: HiddenColoursPanel = _main.get("_hidden_colours")
	_main.call("open_hidden_colours")
	await _frames(40)
	_check("Colour the hidden parts is open", panel.is_visible_in_tree())
	_measure("Colour the hidden parts open beside the model", offer)
	_lines_whole(panel)
	_check("the parts panel is put away for it", not parts.is_open())
	await _shot("2_open")

	# Its Close, pressed where it is drawn, as a finger does.
	var close: Button = panel.get("_close")
	var at: Vector2 = close.get_global_rect().get_center()
	_check("its Close is inside the window (%s)" % [close.get_global_rect()],
		window.encloses(close.get_global_rect()))
	_check("its Close is under none of the phone's own controls", not phone.covers(at))
	await _tap(at)
	await _frames(20)
	_check("a tap on its Close put it away", not panel.visible)
	_check("the parts panel came back", parts.is_open())
	_measure("after it was put away", offer)
	await _shot("3_closed")
	job.end()

	print("")
	if _failures == 0:
		print("a tablet's layout keeps inside its window with a tools' panel open, and Close puts it away")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## The layout and the buttons a person needs, against the window's width.
## The panel scrolls in its column, so only across is asked of it.
func _measure(when: String, offer: StorageOffer) -> void:
	var window: Rect2 = root.get_visible_rect()
	var row: Control = (_main.get("_tool_column") as Control).get_parent() as Control
	_check("%s: the layout is no wider than the window (%d of %d)" % [when, roundi(row.size.x),
		roundi(window.size.x)], row.get_global_rect().end.x <= window.end.x + 0.5)
	var off := PackedStringArray()
	var shell: Shell = _main.get("_shell")
	var holders: Array[Control] = [offer, shell.status]
	var panel: Control = _main.get("_hidden_colours")
	if panel.is_visible_in_tree():
		holders.append(panel)
	for holder: Control in holders:
		for found: Node in holder.find_children("*", "Button", true, false):
			var button: Button = found
			if not button.is_visible_in_tree():
				continue
			var rect: Rect2 = button.get_global_rect()
			if rect.position.x < window.position.x - 0.5 or rect.end.x > window.end.x + 0.5:
				off.append("%s's \"%s\" at %d..%d" % [holder.get_script().get_global_name(),
					button.text, roundi(rect.position.x), roundi(rect.end.x)])
	_check("%s: every button of the warning, the busy line and the panel inside the window's width%s"
		% [when, "" if off.is_empty() else ": " + "; ".join(off)], off.is_empty())
	# The busy line shown, and its Cancel where a finger can press it: not
	# under the phone's foot row.
	var cancel: Button = null
	for found: Node in shell.status.find_children("*", "Button", true, false):
		if (found as Button).text == "Cancel" and (found as Button).is_visible_in_tree():
			cancel = found
	_check("%s: the busy line shows, its Cancel inside the window (%s)" % [when,
		cancel.get_global_rect() if cancel != null else "none shown"],
		cancel != null and window.grow(0.5).encloses(cancel.get_global_rect()))
	var phone: PhoneShell = _main.get("_phone")
	_check("%s: the busy line's Cancel under none of the phone's own controls" % when,
		cancel != null and not phone.covers(cancel.get_global_rect().get_center()))


## No line of [param panel]'s wrapped narrower than its longest word.
func _lines_whole(panel: Control) -> void:
	var broken := PackedStringArray()
	for found: Node in panel.find_children("*", "Label", true, false):
		var label: Label = found
		if not label.is_visible_in_tree() or label.text.is_empty() \
				or label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			continue
		var font: Font = label.get_theme_font("font")
		var size: int = label.get_theme_font_size("font_size")
		var longest: float = 0.0
		for word: String in label.text.split(" ", false):
			longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if label.size.x + 0.5 < longest:
			broken.append("\"%s\" %d across, its longest word %d" % [label.text.substr(0, 24),
				roundi(label.size.x), roundi(longest)])
	_check("no line of the panel narrower than its longest word%s"
		% ("" if broken.is_empty() else ": " + "; ".join(broken)), broken.is_empty())


## A finger's tap at [param at], in the window's units: down, then up a
## moment later, as the screen gives it (the mouse's from it).
func _tap(at: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at * scale
		touch.pressed = down
		Input.parse_input_event(touch)
		await _frames(3)


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(_shots.path_join("%s.png" % name))
