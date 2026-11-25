## room_steady_probe at an interface size and in a language (wingreview3):
## the status bar fits the window, nothing cut mid-word or past its edge, and
## the model's room holds still through puts and undos.
##
##   godot --path . --resolution 390x844 --script src/dev/wr3_room_probe.gd -- --lang=de --wr3size=1.5
##
## --lang= is the app's own (Language.start); --wr3size= is Settings,
## Interface size, set before the app's first frame.
extends "res://src/dev/room_steady_probe.gd"


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--wr3size="):
			ShellPrefs.put("interface_size", float(argument.trim_prefix("--wr3size=")))
	print("  wr3_room: interface size %s, language %s" % [ShellPrefs.interface_size(), Language.current()])
	await super._run()


## room_steady_probe's own, but each line measured as it is drawn: a Label
## holds the English and draws its translation (Language's _get_message), so
## measuring label.text reads "5 bricks · stands up" (111) where the bar says
## "5 Steine · steht" (86), a cut that is not there, and misses one that is.
func _status_fits(when: String) -> void:
	var window: Vector2 = root.get_visible_rect().size
	if not (_shell.status as Control).is_visible_in_tree():
		print("    (the status bar is put away %s: a phone's shows only while the app works)" % when)
		return
	var bar: Rect2 = (_shell.status as Control).get_global_rect()
	var past: Array = []
	for found: Node in (_shell.status as Node).find_children("*", "Control", true, false):
		var c: Control = found as Control
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		if r.end.x > window.x + 0.5:
			past.append("%s %s" % [c.get_class(), str(r)])
	var cut: Array = []
	for found: Node in (_shell.status as Node).find_children("*", "Label", true, false):
		var label: Label = found as Label
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		var drawn: String = label.atr(label.text)
		var whole: float = label.get_theme_font("font").get_string_size(drawn,
			HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		var room: float = label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x
		# A line past the window's edge is cut there, whatever its own size.
		room = minf(room, window.x - label.get_global_rect().position.x)
		if whole > room + 0.5 and label.text_overrun_behavior != TextServer.OVERRUN_TRIM_WORD_ELLIPSIS \
				and label.text_overrun_behavior != TextServer.OVERRUN_TRIM_WORD:
			cut.append("\"%s\" (%.0f in %.0f)" % [drawn.left(30), whole, room])
	_check("the status bar fits the window %s (%s in %.0f; past the edge %s; cut mid-word %s)"
		% [when, str(bar), window.x, str(past), str(cut)],
		bar.end.x <= window.x + 0.5 and past.is_empty() and cut.is_empty())
