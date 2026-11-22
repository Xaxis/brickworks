## ptreview G, static: a step's PAGE NEW and PAGE LOCK/FREEZE lines as an
## older build writes a model whole (they are its unread lines, kept above
## PAGE NEW) and as this build writes them, and each file saved unedited by
## this build's writer (ModelStore._looks_into, the save's own path for an
## authored model). Seconds; no app, no library. (ptfix F5: both builds
## write one order; at 8835f52aa this build wrote them below PAGE NEW.)
##
##   godot --headless --path . --script src/dev/ptreview_order_check.gd
extends SceneTree

var _failures: int = 0


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _initialize() -> void:
	var head: Array = ["0 FILE main.ldr", "0 Name: main.ldr", "0 Author: someone",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP"]
	var tail: Array = ["1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 4 0 -72 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", ""]
	var ours: Array = ["0 !BRICKWORKS PAGE LOCK 2", "0 !BRICKWORKS PAGE FREEZE MARGIN 12",
		"0 !BRICKWORKS PAGE FREEZE_TEXT HEADER Left side"]
	# What an older build's _step_lines gives that step, written whole: the
	# lines it cannot read kept where it keeps such lines.
	var older := PackedStringArray()
	BookletLooks._step_lines(older, {"|2": {"page": "new", "unread": ours}}, "", 2, true, "", {})
	print("an older build writes the step's lines: %s" % str(older))
	# What this build writes for the same step, read from that, written whole.
	var looks: Dictionary = BookletLooks.read("\n".join(head + Array(older) + tail), {}, "main.ldr")
	var mine := PackedStringArray()
	BookletLooks._step_lines(mine, looks, "", 2, true, "", {})
	print("this build writes them:                 %s" % str(mine))
	_check("both builds write the step's lines in one order", Array(mine) == Array(older))
	_check("...and this build read the lock and the freeze (lock %s, freeze %s)" % [
		str((looks.get("|2", {}) as Dictionary).get("lock")), str((looks.get("|2", {}) as Dictionary).get("freeze"))],
		int((looks.get("|2", {}) as Dictionary).get("lock", 0)) == 2
		and (looks.get("|2", {}) as Dictionary).get("freeze") is Dictionary)
	for order: Array in [["this build's order", Array(mine)], ["an older build's order", Array(older)]]:
		var text: String = "\n".join(head + order[1] + tail)
		var read: Dictionary = BookletLooks.read(text, {}, "main.ldr")
		var saved: String = ModelStore._looks_into(text, read, true)
		var same: bool = saved == text
		_check("%s: unedited save byte for byte" % order[0], same)
		if not same:
			for line: String in saved.split("\n"):
				if line.begins_with("0 !BRICKWORKS"):
					print("        saved: %s" % line)
	print("ptreview_order_check: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
