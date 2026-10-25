## An SVG's words are drawn, so a sign prints its words, and print_part
## never says it printed a picture with nothing in it.
##
##   godot --headless --path . --script src/dev/svg_text_probe.gd
##
## walk239 (2026-10-24, M12): a session printed a menu board and a "TACOS"
## roof sign with print_part. Godot draws an SVG with ThorVG, built without
## a font loader, so every <text> fell away: a plain black board, a sign
## with no word, and the answer "Printed it where it stands". Here the
## pictures are read as print_part and a picture file read them
## (PictureFile.decode): a word in black is ink where its letters go,
## centred on its anchor and standing on its baseline; the board's white
## lines in tspans, bold and in a group's fill and transform, are white ink
## on the black; an SVG with no text comes back byte for byte. Then over
## the session's own tool call (print_part svg=): the board is printed and
## the answer names the words drawn; text on a path is refused, saying so;
## an SVG that draws nothing is refused, not "Printed it".
extends SceneTree

var _failures: int = 0
var _next: int = 0
var _socket: CommandSocket

const SIGN := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 60'><text x='100' y='45' font-size='40' text-anchor='middle' fill='#000'>TACOS</text></svg>"
const BOARD := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 120'><rect width='160' height='120' fill='#111'/><g fill='#fff' transform='translate(10 0)'><text x='70' y='30' font-family='Arial, sans-serif' font-size='22' font-weight='bold' text-anchor='middle'>MENU</text><text x='0' y='62' style='font-size:14px'><tspan>Taco al Pastor</tspan><tspan x='0' dy='22'>Carnitas &amp; Salsa $3</tspan></text></g></svg>"
const PLAIN := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 80 24'><rect width='80' height='24' fill='#c00'/></svg>"
const ON_A_PATH := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 60'><path id='arc' d='M10 50 Q100 0 190 50' fill='none'/><text font-size='20'><textPath href='#arc'>ROUND</textPath></text></svg>"
const NOTHING := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 80 24'><rect width='80' height='24' fill='none'/></svg>"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	print("the words in a picture")
	var sign: Image = PictureFile.decode(SIGN.to_utf8_buffer(), "svg")
	var ink: Dictionary = _ink(sign, func(c: Color) -> bool: return c.a > 0.5 and c.v < 0.3)
	_check("\"TACOS\" in black at 40 px: %d%% of the picture is ink" % roundi(float(ink["share"]) * 100.0),
		float(ink["share"]) > 0.08)
	var box: Rect2 = ink["box"]
	var w: float = sign.get_width()
	var h: float = sign.get_height()
	_check("...centred on its anchor (ink from %.2f to %.2f across)" % [box.position.x / w, box.end.x / w],
		absf((box.position.x + box.end.x) * 0.5 / w - 0.5) < 0.03 and box.size.x / w > 0.5)
	_check("...standing on its baseline at 45 of 60, its capitals 0.7 em tall (ink %.1f to %.1f)" % [
		box.position.y / h * 60.0, box.end.y / h * 60.0],
		absf(box.end.y / h * 60.0 - 45.0) < 1.5 and absf((box.end.y - box.position.y) / h * 60.0 - 28.5) < 3.0)

	var board: Image = PictureFile.decode(BOARD.to_utf8_buffer(), "svg")
	var white: Dictionary = _ink(board, func(c: Color) -> bool: return c.a > 0.5 and c.v > 0.8)
	var rows: Array = _rows_with(board, func(c: Color) -> bool: return c.a > 0.5 and c.v > 0.8)
	_check("the menu board: white words on the black, %d%% of it, in %d bands of rows (MENU, two lines)" % [
		roundi(float(white["share"]) * 100.0), rows.size()],
		float(white["share"]) > 0.04 and rows.size() == 3)
	var menu: Rect2 = white["box"]
	_check("...MENU centred on its anchor, the group's transform with it (left %.0f, right %.0f of 160)" % [
		_row_box(board, rows[0]).position.x / board.get_width() * 160.0 if not rows.is_empty() else -1.0,
		_row_box(board, rows[0]).end.x / board.get_width() * 160.0 if not rows.is_empty() else -1.0],
		not rows.is_empty() and absf((_row_box(board, rows[0]).position.x + _row_box(board, rows[0]).end.x)
			* 0.5 / board.get_width() * 160.0 - 80.0) < 3.0 and menu.size.x > 0.0)
	var outlined: Dictionary = SvgText.outline(BOARD)
	_check("...its words read back as written: %s" % [outlined["words"]],
		Array(outlined["words"]) == ["MENU", "Taco al Pastor Carnitas & Salsa $3"])
	_check("an svg with no text comes back as it was", str(SvgText.outline(PLAIN)["svg"]) == PLAIN)
	_check("text on a path is said not drawn (%s)" % [SvgText.outline(ON_A_PATH)["undrawn"]],
		not (SvgText.outline(ON_A_PATH)["undrawn"] as PackedStringArray).is_empty())

	print("print_part, as a session calls it")
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: Node = main.get("_playback")
	if playback != null:
		playback.call("stop")
	_socket = CommandSocket.new()
	_socket.assistant = main.get("_assistant")
	_socket.app = main
	main.add_child(_socket)
	main.call("clear_model")
	await process_frame
	var world: BrickWorld = main.get("_world")
	var panel: int = world.add_brick("3010", 4, Transform3D(Basis.IDENTITY, Vector3(0, 24, 10)))
	(main.get("_builder") as Builder).lattice.occupy_boxes(panel, (main.get("_builder") as Builder)
		.boxes_for((main.get("_library") as PartLibrary).mesh_for("3010"), world.get_brick(panel).transform))
	var said: String = await _say("print_part", {"brick": panel, "svg": BOARD, "name": "Menu board"})
	_check("the board is printed, and the answer names the words drawn: %s" % said.left(220),
		said.begins_with("Printed") and said.contains("\"MENU\"") and said.contains("outlines"))
	var printed: int = _last_part(world)
	said = await _say("print_part", {"brick": printed, "svg": ON_A_PATH, "name": "Round"})
	_check("text on a path is refused, saying why: %s" % said.left(200),
		said.begins_with("Not printed") and said.contains("textPath"))
	said = await _say("print_part", {"brick": printed, "svg": NOTHING, "name": "Nothing"})
	_check("an svg that draws nothing is refused, not printed: %s" % said.left(200),
		said.begins_with("Not printed") and said.contains("empty"))

	print("")
	print("svg_text: %s" % ("all checks passed" if _failures == 0 else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## How much of [param image] is ink by [param is_ink], and its bounding box.
func _ink(image: Image, is_ink: Callable) -> Dictionary:
	if image == null:
		return {"share": 0.0, "box": Rect2()}
	var count: int = 0
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if is_ink.call(image.get_pixel(x, y)):
				count += 1
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	return {"share": float(count) / float(image.get_width() * image.get_height()),
		"box": Rect2(low, high - low + Vector2i.ONE) if count > 0 else Rect2()}


## The bands of rows with ink in them, [first, last] each.
func _rows_with(image: Image, is_ink: Callable) -> Array:
	var bands: Array = []
	if image == null:
		return bands
	var open: int = -1
	for y: int in image.get_height():
		var any: bool = false
		for x: int in image.get_width():
			if is_ink.call(image.get_pixel(x, y)):
				any = true
				break
		if any and open < 0:
			open = y
		elif not any and open >= 0:
			# A gap of a few rows inside a line (an accent, a dollar's bar)
			# is the same line.
			if bands.is_empty() or open - int((bands.back() as Array)[1]) > 6:
				bands.append([open, y - 1])
			else:
				(bands.back() as Array)[1] = y - 1
			open = -1
	return bands


func _row_box(image: Image, band: Array) -> Rect2:
	var low: int = 1 << 20
	var high: int = -1
	for y: int in range(int(band[0]), int(band[1]) + 1):
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5 and c.v > 0.8:
				low = mini(low, x)
				high = maxi(high, x)
	return Rect2(low, band[0], high - low + 1, int(band[1]) - int(band[0]) + 1)


func _last_part(world: BrickWorld) -> int:
	var last: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		last = maxi(last, brick.id)
	return last


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var said: String = ""
	for block: Dictionary in (await _rpc("tools/call", {"name": tool, "arguments": arguments})) \
			.get("content", []):
		said += str(block.get("text", ""))
	return said
