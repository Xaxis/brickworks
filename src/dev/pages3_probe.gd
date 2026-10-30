## What pages2 left of Studio's page objects (docs/APP_UX2.md, gap 10): a
## callout's step posed apart from the callout, a Claude session doing all
## of the page's objects, and words or a picture turned beside another
## kept off it by their turned outline.
##
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a \
##     --server-args="-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
##     --script src/dev/pages3_probe.gd -- [--into=DIR]
##
## Windowed, on the GPU: the booklet's pictures are drawn. On 10183-1's
## tank car, whose tank middle is built in a callout box of three steps.
##
## A callout's step posed apart: on the timeline, Next to the callout's
## second step and the Booklet row's Turn right, one undo step and a
## ROTSTEP in the sub-model's file; the booklet draws that step's picture
## from 45° round the callout's facing and its first step still from the
## facing, the picture framed whole in its cell, and the PDF holds that
## picture; the file opened again draws it so. Ctrl+Z gives the file back
## and the callout's facing. edit_booklet's callout_step= does the same, and
## booklet_layout says it.
##
## Over MCP (CommandSocket, as the mcp probes call it): edit_booklet turns a
## picture the person added 30°, puts words on the page and fades them to
## 50%, draws an arrow and bends it through two points, and lays a guide
## each way; one undo step each, and booklet_layout reads each back. The
## page's PDF and 300 dpi PNG show them as booklet_edit_probe --only=objects
## reads them, and Lay out the page shows the guides.
##
## Two pictures side by side, the first turned 30° over MCP so that its
## corner reaches the second: the booklet moves the second off, and the
## page's PNG has none of either's colour inside the other.
##
## Each part ends undone, the file as it was. --into=DIR keeps the pages,
## the PDF and the screenshots there.
extends SceneTree

const SET := "res://vendor/omr/files/10183-1_Tank-car.mpd"
## booklet_edit_probe's readers of a PDF and of a page's pixels.
const EditProbe := preload("res://src/dev/booklet_edit_probe.gd")
const GREEN := Color(0.15, 0.7, 0.25)
const BLUE := Color(0.15, 0.3, 0.85)
const RED := Color(0.85, 0.2, 0.15)

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _steps: StepsBar
var _library: PartLibrary
var _socket: CommandSocket
var _out: String = ""
var _next: int = 0
var _name: String = "tank car"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## A click where a person clicks, in the window's own pixels.
func _click(at: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var moved := InputEventMouseMotion.new()
	moved.position = at * scale
	moved.global_position = moved.position
	Input.parse_input_event(moved)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at * scale
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(3)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


func _shot(name: String) -> void:
	await _frames(4)
	var shot: Image = root.get_texture().get_image()
	if shot != null:
		shot.save_png(_out.path_join("%s_%dx%d.png" % [name, shot.get_width(), shot.get_height()]))


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.substr(7)
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("sessions/probe/pages3")
	DirAccess.make_dir_recursive_absolute(_out)
	Download.folder = _out
	BookletMaker.open_when_written = false
	if not FileAccess.file_exists(SET):
		print("pages3 probe: SKIPPED, vendor/omr is not in this checkout")
		quit(0)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	_library = _main.get("_library")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await _open(SET)
	await _timeline()
	var base: String = _save()
	await _callout_posed(base)
	await _open(SET)
	await _timeline()
	base = _save()
	var used: int = await _over_mcp(base)
	await _turned_beside(base, used)
	print("")
	print("pages3: a callout's step posed apart, the page's objects over MCP, a turned picture settled by its outline"
		if _failures == 0 else "pages3: %d FAILED" % _failures)
	print("  pictures in %s" % _out)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- a callout's step posed apart --------------------------------------------------


func _callout_posed(base: String) -> void:
	print("")
	print("A callout's step posed apart, on 10183-1's tank car")
	# The first callout of two steps or more built in a box beside its step.
	var number: int = -1
	var name: String = ""
	for page: Booklet.Page in await _laid():
		for entry: Booklet.Entry in page.entries if page.kind == "steps" else []:
			if number < 0 and entry.callout != null and entry.callout.inline \
					and entry.callout.steps.size() >= 2:
				number = entry.number
				name = entry.callout.name
	_check("step %d puts on the %s, built in a callout box" % [number, name], number > 0)
	if number < 0:
		return
	var before: Dictionary = await _drawn(number)
	# Next along the timeline, as a person goes, to the callout's step 2.
	_steps.refresh(number - 1)
	await _frames(4)
	for _n: int in 12:
		var at: Instructions.Step = _steps.current_step()
		if at != null and at.number == number and at.callout_step == 2:
			break
		await _click((_steps.controls_by_name()["steps_next"] as Control).get_global_rect().get_center())
	var on: Instructions.Step = _steps.current_step()
	_check("Next to the %s's step 2: the timeline on \"%s\"" % [name,
		str(_steps.page_state().get("caption", ""))],
		on != null and on.number == number and on.callout_step == 2)
	await _shot("callout_timeline_before")
	var history: int = _history()
	await _click((_steps.controls_by_name()["booklet_turn_right"] as Control).get_global_rect().get_center())
	await _frames(6)
	var posed: String = _save()
	var diff: Array = EditProbe._diff(base, posed)
	var rotstep: String = ""
	for line: Variant in diff[1]:
		if str(line).strip_edges().begins_with("0 ROTSTEP"):
			rotstep = str(line).strip_edges()
	var looked: String = str(_steps.page_state().get("look", ""))
	var still: Instructions.Step = _steps.current_step()
	_check("Booklet row, Turn right: one undo step (%d), the timeline still on step %d's callout step %d, the row saying \"%s\""
		% [_history() - history, still.number if still != null else -1,
			still.callout_step if still != null else -1, looked],
		_history() == history + 1 and still != null and still.number == number and still.callout_step == 2
		and looked.contains("step 2 turned 45°"))
	_check("...in the file as a ROTSTEP in the %s's own file: %s (out %s, in %s)" % [name, rotstep,
		EditProbe._few(diff[0]), EditProbe._few(diff[1])],
		rotstep.begins_with("0 ROTSTEP 0 45 0") and _file_of(posed, rotstep).contains(name)
		and (diff[1] as Array).size() == 1)
	await _shot("callout_timeline_after")
	var after: Dictionary = await _drawn(number)
	var callout: Booklet.Callout = (after["entry"] as Booklet.Entry).callout \
		if not after.is_empty() else null
	if callout == null or before.is_empty():
		_check("the booklet drew step %d with its callout" % number, false)
		return
	var facing: Vector3 = callout.from
	var first: Vector3 = callout.steps[0].from
	var second: Vector3 = callout.steps[1].from
	var round: float = rad_to_deg(Vector2(facing.x, facing.z).angle_to(Vector2(second.x, second.z)))
	var up: float = rad_to_deg(asin(clampf(second.normalized().y, -1.0, 1.0))
		- asin(clampf(facing.normalized().y, -1.0, 1.0)))
	_check("the booklet draws the %s's step 2 from %.1f° round and %.1f° up from the callout's facing, step 1 from the facing (%.3f off)"
		% [name, absf(round), up, first.distance_to(facing)],
		absf(absf(round) - 45.0) < 0.5 and absf(up) < 0.5 and first.distance_to(facing) < 0.001)
	var was: Array = before["images"]
	var now: Array = after["images"]
	# Step 1 is judged by its facing above: the cells share one scale, so a
	# posed step that reaches wider redraws every cell a little smaller.
	var moved: float = _differ(_jpeg(was[1]), _jpeg(now[1]))
	var framed: float = _border_clear(_jpeg(now[1]), BookletMaker.CALLOUT_COLOUR)
	_check("...its cell's picture drawn again (%.0f%% of its pixels changed), the turned %s whole in its cell (%.1f%% of the cell's edge clear)"
		% [moved * 100.0, name, framed * 100.0], moved > 0.05 and framed > 0.98)
	# The PDF holds the posed picture as the booklet drew it, not the one before.
	var pdf: PackedByteArray = await _pdf_of(after, "callout_page")
	var holds: bool = _holds(pdf, _jpeg_bytes(now[1]))
	var holds_old: bool = _holds(pdf, _jpeg_bytes(was[1]))
	_check("the PDF of page %d holds the posed step's picture (%s) and not the one before it (%s), %d bytes"
		% [(after["page"] as Booklet.Page).number, holds, holds_old, pdf.size()], holds and not holds_old)
	await _png_of(before, "callout_page_before")
	await _png_of(after, "callout_page_after")
	# Undone by the person's Ctrl+Z: the file and the callout's facing back.
	history = _history()
	await _key(KEY_Z, true)
	await _frames(4)
	var undone: Dictionary = await _laid_callout(number)
	_check("Ctrl+Z: one undo step back (%d), the file as it was (%s), step 2 drawn from the callout's facing again (%s)"
		% [history - _history(), _save() == base, str(undone.get("faces", false))],
		_history() == history - 1 and _save() == base and bool(undone.get("faces", false)))
	# The same over MCP.
	var said: String = _text(await _call("edit_booklet", {"step": number, "callout_step": 2,
		"turn": 45}))
	_check("edit_booklet {step %d, callout_step 2, turn 45}: \"%s\"; one undo step; the file as the Booklet row left it"
		% [number, said.left(120)], _history() == history and _save() == posed
		and said.contains("callout step 2 is now: turned 45°"))
	var read: String = _text(await _call("booklet_layout", {}))
	_check("booklet_layout says it: \"%s\"" % EditProbe._line_with(read, "its step 2").strip_edges().left(160),
		read.contains("(its step 2 turned 45°, its step 3 turned 45° (from before))"))
	said = _text(await _call("edit_booklet", {"step": number, "callout_step": 2, "zoom": 2}))
	_check("...a zoom on a callout's step refused, nothing changed: \"%s\"" % said.left(90),
		said.contains("callout's own") and _save() == posed)
	said = _text(await _call("undo", {}))
	_check("undo over MCP: the file as it was (\"%s\")" % said.left(70), _save() == base)
	# Kept in the file: opened again from it, the step drawn posed.
	var file: String = _out.path_join("callout_posed.mpd")
	var writing: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	writing.store_string(posed)
	writing.close()
	await _open(file)
	await _timeline()
	var reopened: Dictionary = await _laid_callout(number)
	_check("opened again from the file it saved: step 2 drawn %.3f from where it was posed, saved again the same"
		% float(reopened.get("off", INF)), float(reopened.get("off", INF)) < 0.001 and _save() == posed)


## The callout of step [param number] laid out without pictures: whether its
## step 2 faces as the callout does ("faces") and how far it is drawn from
## 45° round the facing ("off").
func _laid_callout(number: int) -> Dictionary:
	for page: Booklet.Page in await _laid():
		for entry: Booklet.Entry in page.entries if page.kind == "steps" else []:
			if entry.number == number and entry.callout != null and entry.callout.steps.size() >= 2:
				var facing: Vector3 = entry.callout.from
				var second: Vector3 = entry.callout.steps[1].from
				# 45° round the facing, at its height: Turn right's.
				return {"faces": second.distance_to(facing) < 0.001,
					"off": second.distance_to(facing.normalized().rotated(Vector3.UP, deg_to_rad(45.0)))}
	return {}


## Step [param number]'s page as the booklet draws it, its pictures only:
## {document, page, entry, images (its callout's, as data URIs)}.
func _drawn(number: int) -> Dictionary:
	var maker := BookletMaker.new()
	maker.library = _library
	maker.only = {number: true}
	_main.add_child(maker)
	await maker.make(_world, _store.scenery, "Posed apart")
	var document: Booklet.Document = maker.document
	maker.queue_free()
	for page: Booklet.Page in document.pages if document != null else []:
		for entry: Booklet.Entry in page.entries if page.kind == "steps" else []:
			if entry.number == number:
				return {"document": document, "page": page, "entry": entry,
					"images": Array(entry.callout.images) if entry.callout != null else []}
	return {}


## The sub-model's FILE line that [param line] of [param text] is under.
static func _file_of(text: String, line: String) -> String:
	var file: String = ""
	for one: String in text.split("\n"):
		if one.begins_with("0 FILE "):
			file = one
		if one.strip_edges() == line:
			return file
	return ""


static func _jpeg_bytes(uri: Variant) -> PackedByteArray:
	var said: String = str(uri)
	var comma: int = said.find(",")
	return Marshalls.base64_to_raw(said.substr(comma + 1)) if comma > 0 else PackedByteArray()


static func _jpeg(uri: Variant) -> Image:
	var image := Image.new()
	if image.load_jpg_from_buffer(_jpeg_bytes(uri)) != OK:
		return null
	return image


## The share of two pictures' pixels that differ by more than a little.
static func _differ(a: Image, b: Image) -> float:
	if a == null or b == null or a.get_size() != b.get_size():
		return 1.0
	var changed: int = 0
	for y: int in range(0, a.get_height(), 2):
		for x: int in range(0, a.get_width(), 2):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.15:
				changed += 1
	return float(changed) / float(maxi(1, ((a.get_width() + 1) / 2) * ((a.get_height() + 1) / 2)))


## The share of [param image]'s edge pixels that are [param ground]: the
## model drawn whole inside it, not cut by its edge.
static func _border_clear(image: Image, ground: Color) -> float:
	if image == null:
		return 0.0
	var clear: int = 0
	var count: int = 0
	var w: int = image.get_width()
	var h: int = image.get_height()
	for x: int in w:
		for y: int in [0, 1, h - 2, h - 1]:
			count += 1
			if EditProbe._like(image.get_pixel(x, y), ground):
				clear += 1
	for y: int in h:
		for x: int in [0, 1, w - 2, w - 1]:
			count += 1
			if EditProbe._like(image.get_pixel(x, y), ground):
				clear += 1
	return float(clear) / float(maxi(1, count))


static func _holds(bytes: PackedByteArray, part: PackedByteArray) -> bool:
	if part.size() < 64:
		return false
	var hex: String = bytes.hex_encode()
	var key: String = part.hex_encode()
	var at: int = hex.find(key)
	while at >= 0 and at % 2 == 1:
		at = hex.find(key, at + 1)
	return at >= 0


# -- the page's objects over MCP ---------------------------------------------------


## Returns the page used, for the next part to use another.
func _over_mcp(base: String) -> int:
	print("")
	print("The page's objects over MCP, on 10183-1's tank car")
	var found: Array = await _page_with([Vector2(46, 38), Vector2(80, 22), Vector2(64, 40)])
	if found.is_empty():
		_check("a page with room for a picture, words and an arrow", false)
		return -1
	var page: int = found[0]
	var number: int = found[1]
	var free: Array = found[2]
	_check("page %d, its first step %d, room at %s" % [page, number, ", ".join(PackedStringArray(
		free.map(func(box: Rect2) -> String: return _mm(box))))], true)
	# The person adds a picture, as Lay out the page's Add a picture… does.
	var picture := Image.create(64, 48, false, Image.FORMAT_RGB8)
	picture.fill(RED)
	picture.fill_rect(Rect2i(8, 8, 24, 24), Color(1, 1, 1))
	var start: int = _history()
	await _add_pictures(number, [[picture, Rect2((free[0] as Rect2).position + Vector2(3, 3),
		Vector2(40, 30))]])
	var mine: String = _save()
	var mine_at: int = _history()
	var history: int = _history()
	var read: String = _text(await _call("booklet_layout", {"from": page}))
	_check("booklet_layout: the person's picture on page %d: \"%s\"" % [page,
		EditProbe._line_with(read, "page %d:" % page).strip_edges().left(140)],
		EditProbe._line_with(read, "page %d:" % page).contains("a picture at"))
	# A picture turned 30°.
	var said: String = _text(await _call("edit_booklet", {"step": number,
		"place": {"item": "note", "index": 0, "turn": 30}}))
	_check("edit_booklet place {note 0, turn 30}: \"%s\"; one undo step (%d); the file: %s"
		% [said.left(70), _history() - history, EditProbe._line_with(_save(), "NOTE TURN").strip_edges()],
		_history() == history + 1
		and EditProbe._line_with(_save(), "NOTE TURN").strip_edges() == "0 !BRICKWORKS NOTE TURN 30")
	# Words put on, then faded to 50%.
	var words_at: Vector2 = (free[1] as Rect2).position + Vector2(2, 2)
	history = _history()
	said = _text(await _call("edit_booklet", {"step": number, "text": {"words": "Half seen",
		"x": words_at.x, "y": words_at.y, "w": 70, "h": 12, "size": 5}}))
	_check("edit_booklet text \"Half seen\": \"%s\"; one undo step (%d)" % [said.left(70),
		_history() - history], _history() == history + 1)
	history = _history()
	said = _text(await _call("edit_booklet", {"step": number,
		"place": {"item": "note", "index": 1, "opacity": 50}}))
	_check("edit_booklet place {note 1, opacity 50}: \"%s\"; one undo step (%d); the file: %s"
		% [said.left(70), _history() - history, EditProbe._line_with(_save(), "NOTE OPACITY").strip_edges()],
		_history() == history + 1
		and EditProbe._line_with(_save(), "NOTE OPACITY").strip_edges() == "0 !BRICKWORKS NOTE OPACITY 50")
	said = _text(await _call("edit_booklet", {"step": number,
		"place": {"item": "note", "index": 1, "opacity": 0.5}}))
	_check("...opacity 0.5 refused as not a percent, nothing changed: \"%s\"" % said.left(70),
		said.contains("percent") and _history() == history + 1)
	# An arrow drawn, then bent through two points, its ends kept.
	var box: Rect2 = free[2]
	var ends: Array = [box.position.x + 4, box.position.y + 36, box.position.x + 60, box.position.y + 4]
	history = _history()
	said = _text(await _call("edit_booklet", {"step": number, "arrow": {"x1": ends[0], "y1": ends[1],
		"x2": ends[2], "y2": ends[3]}}))
	_check("edit_booklet arrow: \"%s\"; one undo step (%d)" % [said.left(70), _history() - history],
		_history() == history + 1)
	var bends: Array = [box.position + Vector2(18, 8), box.position + Vector2(44, 34)]
	history = _history()
	said = _text(await _call("edit_booklet", {"step": number, "arrow": {"index": 0,
		"bends": bends.map(func(bend: Vector2) -> Array: return [bend.x, bend.y])}}))
	var line: String = EditProbe._line_with(_save(), "!BRICKWORKS ARROW").strip_edges()
	var words: PackedStringArray = line.split(" ")
	var kept: bool = words.size() == 13 and absf(words[5].to_float() - float(ends[0])) < 0.2 \
		and absf(words[8].to_float() - float(ends[3])) < 0.2 \
		and Vector2(words[9].to_float(), words[10].to_float()).distance_to(bends[0]) < 0.2 \
		and Vector2(words[11].to_float(), words[12].to_float()).distance_to(bends[1]) < 0.2
	_check("edit_booklet arrow {index 0, bends two}: \"%s\"; one undo step (%d); the file: %s"
		% [said.left(80), _history() - history, line], _history() == history + 1 and kept)
	# A guide each way.
	var guides := Vector2(snappedf(words_at.x, 0.1), snappedf(words_at.y + 6.0, 0.1))
	history = _history()
	said = _text(await _call("edit_booklet", {"step": number, "guide": {"axis": "x", "at": guides.x}}))
	var also: String = _text(await _call("edit_booklet", {"step": number,
		"guide": {"axis": "y", "at": guides.y}}))
	var saved: String = _save()
	_check("edit_booklet guide x %s and y %s: \"%s\", \"%s\"; one undo step each (%d); the file: %s, %s"
		% [BookletLooks._number(guides.x), BookletLooks._number(guides.y), said.left(50), also.left(50),
			_history() - history, EditProbe._line_with(saved, "GUIDE X").strip_edges(),
			EditProbe._line_with(saved, "GUIDE Y").strip_edges()],
		_history() == history + 2
		and EditProbe._line_with(saved, "GUIDE X").strip_edges() == "0 !BRICKWORKS GUIDE X " + BookletLooks._number(guides.x)
		and EditProbe._line_with(saved, "GUIDE Y").strip_edges() == "0 !BRICKWORKS GUIDE Y " + BookletLooks._number(guides.y))
	# Read back.
	read = _text(await _call("booklet_layout", {"from": page}))
	var on_page: String = EditProbe._line_with(read, "page %d:" % page, 2000)
	var bent: String = "bent through %s, %s and %s, %s" % [BookletLooks._number(snappedf(bends[0].x, 0.1)),
		BookletLooks._number(snappedf(bends[0].y, 0.1)), BookletLooks._number(snappedf(bends[1].x, 0.1)),
		BookletLooks._number(snappedf(bends[1].y, 0.1))]
	var laid_guides: String = "upright at %s mm, across at %s mm" % [BookletLooks._number(guides.x),
		BookletLooks._number(guides.y)]
	_check("booklet_layout reads each back: picture turned 30° %s, words 50%% opaque %s, %s %s, guides %s"
		% [on_page.contains("40 x 30, turned 30°"), on_page.contains("\"Half seen\" at %s, %s mm, 50%% opaque"
			% [BookletLooks._number(snappedf(words_at.x, 0.1)), BookletLooks._number(snappedf(words_at.y, 0.1))]),
			bent, on_page.contains(bent), read.contains(laid_guides)],
		on_page.contains("40 x 30, turned 30°") and on_page.contains("50% opaque")
		and on_page.contains(bent) and read.contains("Guides on every page, never printed: " + laid_guides))
	# Undo, as a session takes its own back: the last guide, and again.
	said = _text(await _call("undo", {}))
	var without: String = _save()
	var redone: String = _text(await _call("undo", {"redo": true}))
	_check("undo over MCP takes the across guide off (\"%s\"), redo puts it back"
		% said.left(60), EditProbe._line_with(without, "GUIDE Y").is_empty()
		and not EditProbe._line_with(without, "GUIDE X").is_empty() and _save() == saved
		and not redone.is_empty())
	# The page printed: its HTML, PDF and PNG.
	await _printed(number, guides, bends, "mcp")
	# The person's Lay out the page shows what the session did.
	var editor: PageEditor = _main.get("_page_editor")
	_steps.refresh(number)
	await editor.open()
	await _until_laid(editor)
	var state: Dictionary = editor.page_state()
	var notes: Dictionary = state.get("notes", {})
	var turns: Array = notes.values().map(func(one: Dictionary) -> float: return float(one["turn"]))
	var fades: Array = notes.values().map(func(one: Dictionary) -> float: return float(one["opacity"]))
	var shown: Dictionary = state.get("ruler_guides", {})
	for _n: int in 3000:
		if not (editor.page_state().get("drawn", []) as Array).is_empty():
			break
		await process_frame
	await _shot("mcp_page_editor")
	_check("Lay out the page on page %d: turns %s, opacities %s, %d arrow, guides %s"
		% [int(state.get("page", 0)), str(turns), str(fades), (state.get("arrows", {}) as Dictionary).size(),
			str(shown)], 30.0 in turns and 0.5 in fades
		and (state.get("arrows", {}) as Dictionary).size() == 1
		and (shown.get("x", []) as Array).size() == 1 and is_equal_approx(float(shown["x"][0]), guides.x)
		and (shown.get("y", []) as Array).size() == 1 and is_equal_approx(float(shown["y"][0]), guides.y))
	editor.close()
	# Every one of the session's back, then the person's picture.
	var count: int = _history() - mine_at
	said = _text(await _call("undo", {"steps": count}))
	_check("undo over MCP, %d steps: the file as it was with only the person's picture (%s)"
		% [count, said.left(60)], _save() == mine)
	while _history() > start:
		_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("...and its picture undone, the file as it was", _save() == base)
	return page


## Step [param number]'s page printed: its HTML, then its PDF and its PNG
## made from it as Save as PDF and Save pages as PNG make them, each judged
## as booklet_edit_probe --only=objects judges them: the picture turned 30°,
## the words at 50%, red ink through [param bends]; and no guide printed.
func _printed(number: int, guides: Vector2, bends: Array, name: String) -> void:
	var drawn: Dictionary = await _drawn(number)
	if drawn.is_empty():
		_check("the booklet drew step %d" % number, false)
		return
	var html: String = _html_of(drawn, name + "_page")
	var written: String = FileAccess.get_file_as_string(html)
	_check("the page's HTML: the picture turned 30° (%s), the words at 50%% (%s), the arrow a curve (%s), no guide in it (%s)"
		% [written.contains("transform:rotate(30deg)"), written.contains("opacity:0.5"),
			written.contains("class=\"drawn-arrow\" d=\"M"), not written.to_lower().contains("guide")],
		written.contains("transform:rotate(30deg)") and written.contains("opacity:0.5")
		and written.contains("class=\"drawn-arrow\" d=\"M") and not written.to_lower().contains("guide"))
	var read := BookletRead.new()
	var read_pages: Array = []
	await read.read_all(html, func(one: BookletRead.Page) -> void: read_pages.append(one))
	var picture_op: Dictionary = {}
	var words_op: Dictionary = {}
	for op: Dictionary in (read_pages[0] as BookletRead.Page).ops if not read_pages.is_empty() else []:
		if op["k"] == "image" and op.has("turn"):
			picture_op = op
		if op["k"] == "text" and str(op.get("text", "")).begins_with("Half"):
			words_op = op
	var bytes: PackedByteArray = await _pdf_of(drawn, name + "_page")
	var content: String = EditProbe._pdf_content(bytes)
	var dictionary: bool = EditProbe._bytes_find(bytes, "/A50 << /ca 0.5 /CA 0.5 >>") >= 0
	var turn_at: int = content.find("0.866 0.5 -0.5 0.866 ")
	var fade_at: int = content.find("/A50 gs")
	var red: PackedVector2Array = EditProbe._pdf_red_line(content)
	var off: Array = bends.map(func(bend: Vector2) -> float: return EditProbe._off_line(red, bend))
	_check("the PDF: the picture drawn turned 30° (cm, then Do: %s), the words under a 50%% graphics state (%s, /ca 0.5: %s), red ink %s mm from each bend"
		% [turn_at >= 0 and content.find(" Do", turn_at) - turn_at < 120,
			fade_at >= 0 and content.find("BT", fade_at) > fade_at, dictionary,
			", ".join(PackedStringArray(off.map(func(d: float) -> String: return "%.2f" % d)))],
		turn_at >= 0 and content.find(" Do", turn_at) - turn_at < 120 and fade_at >= 0
		and dictionary and off.size() == 2 and off.all(func(d: float) -> bool: return d < 0.3))
	var png: Dictionary = await _png_of(drawn, name + "_page")
	var image: Image = png.get("image")
	var px: float = float(png.get("px", 0.0))
	if image == null or picture_op.is_empty() or words_op.is_empty():
		_check("the PNG of the page, and the picture and words on it", false)
		return
	var at: Rect2 = picture_op["at"]
	var pivot: Vector2 = picture_op["pivot"]
	var on := func(u: float, v: float, turn: bool) -> Color:
		var mm: Vector2 = at.position + at.size * Vector2(u, v)
		if turn:
			mm = pivot + (mm - pivot).rotated(deg_to_rad(30.0))
		return image.get_pixelv(Vector2i((mm * px).round()))
	var red_in: Color = on.call(0.78, 0.5, true)
	var white_in: Color = on.call(0.31, 0.42, true)
	var corner: Color = on.call(0.03, 0.04, false)
	var turned_ok: bool = EditProbe._like(red_in, RED) and EditProbe._like(white_in, Color.WHITE) \
		and not EditProbe._like(corner, RED)
	var words_box := Rect2((words_op["at"] as Vector2) - Vector2(0.0, 5.0), Vector2(30, 6.5))
	var darkest: float = 1.0
	for y: int in range(int(words_box.position.y * px), int(words_box.end.y * px)):
		for x: int in range(int(words_box.position.x * px), int(words_box.end.x * px)):
			darkest = minf(darkest, image.get_pixel(x, y).get_luminance())
	var reds: Array = bends.map(func(bend: Vector2) -> bool:
		return EditProbe._red_near(image, bend * px, 0.5 * px))
	_check("the PNG at %.0f dpi: the picture turned (red %s and white %s where it is turned to, %s at its corner unturned), the words' darkest %.2f, red ink at both bends %s"
		% [px * 25.4, red_in.to_html(false), white_in.to_html(false), corner.to_html(false), darkest,
			str(reds)],
		turned_ok and darkest > 0.35 and darkest < 0.65 and reds.all(func(one: bool) -> bool: return one))


# -- a turned picture beside another ---------------------------------------------


func _turned_beside(base: String, used: int) -> void:
	print("")
	print("A picture turned 30° beside another, on 10183-1's tank car")
	var found: Array = await _page_with([Vector2(60, 38)], used)
	if found.is_empty():
		_check("a page with room for two pictures side by side", false)
		return
	var page: int = found[0]
	var number: int = found[1]
	var room: Rect2 = found[2][0]
	# Unturned, half a millimetre apart; the first turned 30° reaches 2.5 mm
	# into the second.
	var first := Rect2(room.position + Vector2(4, 9), Vector2(30, 20))
	var second := Rect2(Vector2(first.end.x + 0.5, first.position.y), Vector2(20, 20))
	var green := Image.create(60, 40, false, Image.FORMAT_RGB8)
	green.fill(GREEN)
	var blue := Image.create(40, 40, false, Image.FORMAT_RGB8)
	blue.fill(BLUE)
	var start: int = _history()
	await _add_pictures(number, [[green, first], [blue, second]])
	var laid: Booklet.Page = await _laid_page(page)
	var notes: Array = _notes_of(laid, number)
	_check("page %d, step %d: a green picture at %s and a blue one 0.5 mm right of it at %s, neither moved"
		% [page, number, _mm(first), _mm(second)], notes.size() == 2
		and BookletLooks.rect_of(notes[0]["at"]).position.distance_to(first.position) < 0.2
		and BookletLooks.rect_of(notes[1]["at"]).position.distance_to(second.position) < 0.2)
	var history: int = _history()
	var said: String = _text(await _call("edit_booklet", {"step": number,
		"place": {"item": "note", "index": 0, "turn": 30}}))
	laid = await _laid_page(page)
	notes = _notes_of(laid, number)
	var a: Rect2 = BookletLooks.rect_of(notes[0]["at"]) if notes.size() == 2 else Rect2()
	var b: Rect2 = BookletLooks.rect_of(notes[1]["at"]) if notes.size() == 2 else Rect2()
	# Held to the booklet's own tolerance, the one unturned pictures get: no
	# deeper than OVERLAP mm one way or the other.
	var deep: float = _shared_depth(_outline(a, 30.0), _outline(b, 0.0))
	_check("edit_booklet turns the green one 30° (\"%s\", %d undo step): the blue one %s, at %s; the green one's corner %.2f mm into it (%.1f allowed), the page says \"%s\""
		% [said.left(50), _history() - history, "moved" if b.position.distance_to(second.position) > 0.2
			else "left where it was", _mm(b), deep, Booklet.OVERLAP,
			Booklet.overlaps_said(laid) if laid != null else "?"],
		_history() == history + 1 and deep <= Booklet.OVERLAP and b.position.distance_to(second.position) > 0.2
		and laid != null and Booklet.overlaps_said(laid).contains(
			"added picture was on step %d's added picture: moved off it" % number))
	# Measured on the page as printed.
	var drawn: Dictionary = await _drawn(number)
	var png: Dictionary = await _png_of(drawn, "turned_beside_page") if not drawn.is_empty() else {}
	var image: Image = png.get("image")
	var px: float = float(png.get("px", 0.0))
	var printed: Array = _notes_of(drawn.get("page"), number) if not drawn.is_empty() else []
	if image == null or printed.size() != 2:
		_check("the page printed with both pictures on it", false)
	else:
		var pa: Rect2 = BookletLooks.rect_of(printed[0]["at"])
		var pb: Rect2 = BookletLooks.rect_of(printed[1]["at"])
		var blue_in_green: int = 0
		var green_in_blue: int = 0
		var seen: Array = [0, 0]
		for i: int in 41:
			for j: int in 41:
				var u: float = lerpf(0.04, 0.96, i / 40.0)
				var v: float = lerpf(0.04, 0.96, j / 40.0)
				var in_a: Vector2 = pa.get_center() + (pa.position + pa.size * Vector2(u, v)
					- pa.get_center()).rotated(deg_to_rad(30.0))
				var colour: Color = image.get_pixelv(Vector2i((in_a * px).round()))
				blue_in_green += int(EditProbe._like(colour, BLUE))
				seen[0] += int(EditProbe._like(colour, GREEN))
				colour = image.get_pixelv(Vector2i(((pb.position + pb.size * Vector2(u, v)) * px).round()))
				green_in_blue += int(EditProbe._like(colour, GREEN))
				seen[1] += int(EditProbe._like(colour, BLUE))
		_check("the page's PNG at %.0f dpi: inside the green one's turned outline %d of 1681 points blue (%d green); inside the blue one %d green (%d blue)"
			% [px * 25.4, blue_in_green, seen[0], green_in_blue, seen[1]],
			blue_in_green == 0 and green_in_blue == 0 and seen[0] > 1600 and seen[1] > 1600)
	while _history() > start:
		_builder.undo()
	await _frames(2)
	_steps.refresh()
	_check("undone, the file as it was", _save() == base)


static func _notes_of(page: Variant, number: int) -> Array:
	if not (page is Booklet.Page):
		return []
	for entry: Booklet.Entry in (page as Booklet.Page).entries:
		if entry.number == number:
			return entry.notes.filter(func(note: Variant) -> bool:
				return note is Dictionary and (note as Dictionary).has("image"))
	return []


## [param rect]'s corners turned clockwise about its middle, as the page's
## CSS turns a picture.
static func _outline(rect: Rect2, turn: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		out.append(rect.get_center() + (corner - rect.get_center()).rotated(deg_to_rad(turn)))
	return out


## How far [param a] and [param b] reach into each other, in mm: the
## shorter side of the box round what they share, 0 where they share nothing.
static func _shared_depth(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var deep: float = 0.0
	for part: PackedVector2Array in Geometry2D.intersect_polygons(a, b):
		var box := Rect2(part[0], Vector2.ZERO)
		for point: Vector2 in part:
			box = box.expand(point)
		deep = maxf(deep, minf(box.size.x, box.size.y))
	return deep


# -- pages, and the person's pictures on them --------------------------------------


## The first page of steps (not [param skip]) whose first step is the
## model's own and that has room clear of everything on it for boxes of
## [param sizes] (mm): [page, step, [Rect2 each]], or [].
func _page_with(sizes: Array, skip: int = -1) -> Array:
	for page: Booklet.Page in await _laid():
		if page.kind != "steps" or page.number == skip or page.entries.is_empty() \
				or page.entries[0].in_callout or page.entries[0].callout != null:
			continue
		var taken: Array = Booklet.things_on(page).map(func(thing: Dictionary) -> Rect2:
			return (thing["rect"] as Rect2).grow(3.0))
		var out: Array = []
		var area: Rect2 = Booklet.content()
		for size: Vector2 in sizes:
			var found: bool = false
			var y: float = area.position.y
			while not found and y + size.y <= area.end.y:
				var x: float = area.position.x
				while not found and x + size.x <= area.end.x:
					var spot := Rect2(Vector2(x, y), size)
					if taken.all(func(rect: Rect2) -> bool: return not rect.intersects(spot)):
						out.append(spot)
						taken.append(spot.grow(3.0))
						found = true
					x += 2.0
				y += 2.0
		if out.size() == sizes.size():
			return [page.number, page.entries[0].number, out]
	return []


## Pictures put on step [param number]'s page by Lay out the page, as a
## person adds one, then dragged to where each goes: [[Image, Rect2], ...].
func _add_pictures(number: int, pictures: Array) -> void:
	var editor: PageEditor = _main.get("_page_editor")
	_steps.refresh(number)
	await editor.open()
	await _until_laid(editor)
	for index: int in pictures.size():
		await editor.add_image(pictures[index][0])
		await _until_laid(editor)
		var at: int = editor.item_named("page_image_%d_%d" % [number, index])
		if at >= 0:
			await editor.place(at, pictures[index][1])
			await _until_laid(editor)
	editor.close()
	await _frames(2)


func _until_laid(editor: PageEditor) -> void:
	for _n: int in 600:
		if not bool(editor.page_state().get("laying", false)):
			break
		await process_frame
	await _frames(3)


func _html_of(drawn: Dictionary, name: String) -> String:
	var html: String = _out.path_join(name + ".html")
	var writing: FileAccess = FileAccess.open(html, FileAccess.WRITE)
	writing.store_string("\n".join([Booklet.head(drawn["document"]),
		Booklet.page_html(drawn["page"], drawn["document"]), Booklet.TAIL]))
	writing.close()
	return html


## The page of [param drawn] as Save as PDF writes it: its bytes.
func _pdf_of(drawn: Dictionary, name: String) -> PackedByteArray:
	if drawn.is_empty():
		return PackedByteArray()
	var html: String = _html_of(drawn, name)
	var pdf: String = _out.path_join(name + ".pdf")
	var writer := BookletPdf.new()
	var read := BookletRead.new()
	writer.begin(pdf, read)
	await read.read_all(html, writer.page)
	writer.finish("pages3")
	return FileAccess.get_file_as_bytes(pdf)


## The page of [param drawn] as Save pages as PNG writes it, at 300 dpi,
## kept as NAME.png: {image, px (a millimetre)}.
func _png_of(drawn: Dictionary, name: String) -> Dictionary:
	if drawn.is_empty():
		return {}
	var html: String = _html_of(drawn, name)
	var zip: String = _out.path_join(name + ".zip")
	var drawer := BookletPng.new()
	root.add_child(drawer)
	await drawer.write(html, zip, name)
	var px: float = drawer.px_per_mm
	drawer.queue_free()
	var reader := ZIPReader.new()
	var image := Image.new()
	if reader.open(zip) == OK:
		for file: String in reader.get_files():
			if file.ends_with(".png"):
				image.load_png_from_buffer(reader.read_file(file))
		reader.close()
	if image.is_empty():
		return {}
	image.save_png(_out.path_join(name + ".png"))
	return {"image": image, "px": px}


# -- the model, the timeline, the socket -------------------------------------------


func _open(path: String) -> void:
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)
	_check("opened %s: %d parts" % [path.get_file(), _world.brick_count()],
		_world.brick_count() > 10 and _store.awaited.is_empty())


func _timeline() -> void:
	if not _steps.visible:
		await _steps.start(_world, _library, _store.scenery)
	await _frames(4)


func _save() -> String:
	return _store.to_text(_name, true)


func _history() -> int:
	return _builder._history.size()


func _laid() -> Array[Booklet.Page]:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, _name)
	maker.queue_free()
	return pages


func _laid_page(number: int) -> Booklet.Page:
	for page: Booklet.Page in await _laid():
		if page.number == number:
			return page
	return null


func _call(tool: String, arguments: Dictionary) -> Array:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	return ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []) as Array


static func _text(blocks: Array) -> String:
	var out := PackedStringArray()
	for block: Dictionary in blocks:
		if str(block.get("type", "")) == "text":
			out.append(str(block.get("text", "")))
	return "\n".join(out)


static func _mm(rect: Rect2) -> String:
	return "%s, %s mm, %s x %s" % [BookletLooks._number(snappedf(rect.position.x, 0.1)),
		BookletLooks._number(snappedf(rect.position.y, 0.1)), BookletLooks._number(snappedf(rect.size.x, 0.1)),
		BookletLooks._number(snappedf(rect.size.y, 0.1))]
