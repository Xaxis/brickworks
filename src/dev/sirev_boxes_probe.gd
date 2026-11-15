## sireview (2026-11-15), its finding 3 made a check (sifix): what CodeBoxes
## sends for a code that arrives with more digits than it has boxes, or
## fewer, or in the email's own words, by the two ways a whole code reaches
## it: a paste the box itself took (a fill, the browser's paste on the web, a
## phone's paste: _typed) and Ctrl+V on the desktop (paste()). One rule, the
## site's too (web/code-boxes.js readCode): an exact run of eight digits,
## one space or dash allowed inside, is sent; anything else is laid from the
## first box and not sent. And the last digit in: the one that fills the
## row, or one typed into its last box, sends; one changed in the middle of
## a full row waits.
##
##   godot --headless --path . --script src/dev/sirev_boxes_probe.gd
extends SceneTree

var _sent: Array[String] = []
var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# [text, sent, laid]: sent is what the row sends ("" for nothing), laid
	# what its boxes hold after.
	var cases: Array = [
		["Your Brickworks sign-in code is 12345678. It works once and expires in 10 minutes.", "12345678", "12345678"],
		["123456789", "", "12345678"],
		["12345678", "12345678", "12345678"],
		[" 1234 5678\n", "12345678", "12345678"],
		["1234-5678", "12345678", "12345678"],
		["Expires in 10 min. Code 12345678", "12345678", "12345678"],
		["123456", "", "123456"],
		["12 34 56 78 9", "", "12345678"],
		["abcdefgh", "", ""],
	]
	for one: Array in cases:
		for way: String in ["box's own paste (_typed)", "Ctrl+V (paste())"]:
			var row: CodeBoxes = await _row()
			if way.begins_with("box"):
				var box: LineEdit = row.first_box()
				box.text = one[0]
				box.text_changed.emit(one[0])
			else:
				row.paste(one[0])
			var want: Array[String] = []
			if not (one[1] as String).is_empty():
				want.append(one[1] as String)
			_ok(_sent == want and row.code() == one[2],
				"%s | %s -> sent %s, laid %s" % [way, JSON.stringify(one[0]), str(_sent), row.code()])
			row.queue_free()

	# A fill put after the box's own digit: what came is the code.
	var held: CodeBoxes = await _row()
	held.first_box().grab_focus()
	await _type(held, 0, "5")
	_sent.clear()
	held.box(0).text = "512345678"
	held.box(0).text_changed.emit("512345678")
	_ok(_sent == ["12345678"], "a fill of 12345678 after the box's own 5 sends 12345678 (%s)" % str(_sent))
	held.queue_free()

	# The last digit in.
	var row: CodeBoxes = await _row()
	for at: int in 7:
		await _type(row, at, str(at + 1))
	_ok(_sent.is_empty(), "seven digits send nothing (%s)" % str(_sent))
	await _type(row, 7, "8")
	_ok(_sent == ["12345678"], "the eighth digit, filling the row, sends (%s)" % str(_sent))
	_sent.clear()
	await _type(row, 2, "9")
	_ok(_sent.is_empty() and row.code() == "12945678",
		"a digit changed in the middle of a full row waits (%s, %s)" % [row.code(), str(_sent)])
	await _type(row, 7, "8")
	_ok(_sent == ["12945678"], "a digit typed into the last box of a full row sends (%s)" % str(_sent))
	row.queue_free()

	print("")
	print("%d FAILED" % _failures if _failures else "one rule for a code pasted or filled, and the last digit in sends")
	quit(1 if _failures else 0)


func _row() -> CodeBoxes:
	_sent.clear()
	var row := CodeBoxes.new()
	root.add_child(row)
	row.filled.connect(func(code: String) -> void: _sent.append(code))
	await process_frame
	return row


## A digit typed into box [param at] as a key reaches it.
func _type(row: CodeBoxes, at: int, digit: String) -> void:
	var box: LineEdit = row.box(at)
	box.grab_focus()
	var event := InputEventKey.new()
	event.unicode = digit.unicode_at(0)
	event.pressed = true
	box.gui_input.emit(event)
	await process_frame


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
