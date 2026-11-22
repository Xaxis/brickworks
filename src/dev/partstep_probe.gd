## "Where does this go?" (APP_UX11 partstep), on a phone.
##
##   godot --path . --resolution 390x844 --script src/dev/partstep_probe.gd
##   tools/probe.sh partstep_probe
##   PROBE_SIZE=1024x768 tools/probe.sh partstep_probe      a tablet, the words on the button
##
## A builder at a step holds a part and cannot find its step. In Build mode,
## "Where does this go?" takes a photo of it, Brickognize names it, and the
## player goes to the first step not yet built that places it, the place lit.
## Brickognize is a stub here, on a port of the probe's own (10830), as
## photo_search_stub_probe's is; tools/partstep_bench.gd asks the real one with
## 30 photos. The car (models/car.ldr) as a shared link, as partbypart_probe
## opens it, and everything done as a finger does it:
##
##   1. Said first, in the parts bin's words: the photo goes to Brickognize,
##      a third party, only the photo and never the model. Cancelled, nothing
##      is sent; agreed, the picker opens and still nothing is sent; told once,
##      the next press opens the picker at once.
##   2. A photo of a part the car places in several steps, from step 1: the
##      photo sent once, a JPEG alone; the guesses the model has first (the
##      top guess, not in the car, third); the page the first step that
##      places it, its part outlined; the card says the part, its colour,
##      how many steps and which, each a button.
##   3. Another step tapped on the card: that page, its part outlined; Back to
##      step 1 goes back and puts the card away.
##   4. Further along, past the first: the next step that places it, the one
##      before counted built. At the last step, a part placed only before it:
##      every step built, said, and the page stays.
##   5. "Not it?": another guess tapped, its own first step.
##   6. A part at a time: the page at the part itself, it alone lit.
##   7. Nothing the car has; offline: said in words, the page stays.
##   8. Every target 44 points or more; the time from the photo to the step.
##   9. edit_steps over MCP with picture_data: refused, nothing sent, until
##      agreed=true (or agreed in the app); then in 1 call the same step and
##      the others.
##
## Pictures in shots/partstep/.
extends SceneTree

const CAR := "res://models/car.ldr"
const SHOTS := "res://shots/partstep/"
const STUB := 10830
const NOBODY := 10831
const TARGET := 44.0

var _failures: int = 0
var _size: String = ""
var _server := TCPServer.new()
var _reply: String = ""
var _asked: int = 0
var _bodies: Array[PackedByteArray] = []
var _peers: Array[StreamPeerTCP] = []
var _heard: Dictionary = {}
var _socket: CommandSocket
var _rpc_id: int = 0


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	var text: String = FileAccess.get_file_as_string(CAR)
	if text.is_empty():
		print("partstep_probe: SKIPPED, no %s" % CAR)
		quit(3)
		return
	if _server.listen(STUB, "127.0.0.1") != OK:
		print("partstep_probe: port %d is taken" % STUB)
		quit(1)
		return
	print("partstep_probe: a %s window" % _size)
	BuildSteps._kept.clear()
	var told_before: Variant = ShellPrefs.value("photo_told")
	ShellPrefs.put("photo_told", false)
	BuildMode.keep_by_part(false)

	var main: Node = await _open("P4rtSt3p01", text, "the car")
	var mode: BuildMode = await _build_it(main)
	var pages: BuildSteps = main.get("_build_pages")
	var world: BrickWorld = main.get("_world")
	var library: PartLibrary = main.get("_library")
	_ok(mode.is_open() and pages != null and mode.pages == pages,
		"Build it opens the step player, its pages the ones \"Where does this go?\" reads")
	if pages == null:
		_finish(told_before)
		return
	mode.photo_url = "http://127.0.0.1:%d/predict/parts/" % STUB
	# The part: the one the car places in the most steps, two or more, the
	# first of them after step 1; and another the car has, and one it has not.
	var target: Array = _most_placed(pages, world)
	_ok(target.size() == 3 and (target[2] as Array).size() >= 2,
		"the car places %s in %s %d steps: %s" % [target[0], _colour_name(library, int(target[1])),
			(target[2] as Array).size(), str(target[2])] if not target.is_empty() else "a part in 2 steps")
	if target.is_empty():
		_finish(told_before)
		return
	var part: String = target[0]
	var colour: int = target[1]
	var hits: Array = target[2]
	var other: String = _another_part(pages, world, part)
	var number: String = library.shop_part(part, "BrickLink")
	var other_number: String = library.shop_part(other, "BrickLink")
	var answer: String = _answer([["3001special", "Brick 2 x 4 with special print", 0.71],
		[number, "the part", 0.66], [other_number, "another", 0.42]], library.bricklink_colour(colour))

	print("\n1. said first, in the bin's words, and nothing sent")
	await _go(main, 1)
	var named: Dictionary = mode.controls_by_name()
	var where: Button = named.get("build_where")
	_ok(where != null and where.is_visible_in_tree(), "\"Where does this go?\" is on the page (%s)" % (
		"\"%s\"" % where.text if where != null and not where.text.is_empty() else "a camera"))
	await _tap(where)
	var telling: ConfirmationDialog = mode.get("_terms")
	_ok(telling != null and telling.visible and telling.dialog_text == Brickognize.TERMS,
		"the first press says where the photo goes, in the bin's words")
	_ok(Brickognize.TERMS.contains("third party") and Brickognize.TERMS.contains("never your model"),
		"...a third party, and only the photo, never the model")
	_ok(mode.get("_brickognize") == null and _asked == 0, "...and nothing is sent")
	await _shot("1_told")
	telling.get_cancel_button().pressed.emit()
	await _settle()
	_ok(mode.get("_brickognize") == null and not bool(ShellPrefs.value("photo_told")) and not _picker_open(mode),
		"cancelled: nothing asked for, nothing sent")
	await _tap(where)
	telling.get_ok_button().pressed.emit()
	await _settle()
	_ok(bool(ShellPrefs.value("photo_told")) and _picker_open(mode) and mode.get("_brickognize") == null,
		"\"Choose a photo\": the picker opens, and still nothing is sent")
	_hide_picker(mode)
	await _tap(where)
	_ok(_picker_open(mode) and not telling.visible, "told once, the next press opens the picker at once")
	_hide_picker(mode)

	print("\n2. a photo of %s, from step 1" % part)
	_reply = answer
	var photo: Image = _photo()
	var said: Dictionary = await _ask(main, mode, photo)
	var card: Dictionary = said["partstep"]
	var first: int = int(hits[0])
	_ok(_asked == 1, "the photo was sent once (%d)" % _asked)
	_ok(_only_a_photo(text), "...a JPEG alone, never the model (%d bytes)" % (_bodies[-1].size() if not _bodies.is_empty() else 0))
	_ok(card["options"] == [part, other, "3001special"],
		"the guesses the car has first, the top one it has not last: %s" % str(card["options"]))
	_ok(int(said["page"]) == first, "the page is step %d, the first that places it (page %d)" % [first, int(said["page"])])
	var lit: Dictionary = _bricks_of(pages, world, first, part, colour)
	_ok(_outlined(main, world, lit), "...its part's place outlined, %d of the step's %d new parts" % [
		lit.size(), pages.added(first).size()])
	_ok(str(card["title"]).contains(_name_of(library, part)) and str(card["title"]).contains(
		_colour_name(library, colour)), "the card names it: \"%s\"" % card["title"])
	_ok(str(card["where"]).contains("%d steps" % hits.size()) and (card["steps"] as PackedStringArray).size()
		== mini(hits.size(), PartStep.STEPS_SHOWN), "...and says how many steps and which: \"%s\" %s" % [
			card["where"], str(card["steps"])])
	_ok(int(card["photo_ms"]) >= 0 and int(card["photo_ms"]) <= 3000,
		"from the photo to the step in %d ms (the stub answers at once)" % int(card["photo_ms"]))
	await _shot("2_found")

	print("\n3. another step on the card, and back")
	named = mode.controls_by_name()
	var second: Button = named.get("partstep_step_1")
	await _tap(second)
	said = main.call("build_state")
	_ok(int(said["page"]) == int(hits[1]), "a tap on %s: step %d (page %d)" % [second.text if second != null else "none",
		int(hits[1]), int(said["page"])])
	_ok(_outlined(main, world, _bricks_of(pages, world, int(hits[1]), part, colour)),
		"...its part outlined")
	var back: Button = mode.controls_by_name().get("partstep_back")
	_ok(back != null and back.text == "Back to step 1", "\"%s\" on the card" % (back.text if back != null else "no way back"))
	if back != null:
		await _tap(back)
	said = main.call("build_state")
	_ok(int(said["page"]) == 1 and not bool(said["partstep"]["shown"]), "...back on step 1, the card put away")

	print("\n4. further along, and every step built")
	var between: int = first + 1
	await _go(main, between)
	said = await _ask(main, mode, photo)
	var next: int = -1
	for hit: Variant in hits:
		if int(hit) >= between:
			next = int(hit)
			break
	_ok(int(said["page"]) == next, "from step %d, the next that places it: step %d (page %d)" % [between, next,
		int(said["page"])])
	_ok(str(said["partstep"]["where"]).contains("the first of %d" % hits.size()),
		"...\"%s\"" % said["partstep"]["where"])
	_close_card(mode)
	await _go(main, pages.last())
	var last_hit: int = int(hits[-1])
	if last_hit < pages.last():
		said = await _ask(main, mode, photo)
		_ok(int(said["page"]) == pages.last() and str(said["partstep"]["where"]).begins_with("Every step that places it is built"),
			"at the last step: \"%s\", the page stays" % said["partstep"]["where"])
	else:
		print("  (the last step places it: skipped)")
	_close_card(mode)

	print("\n5. not it: another guess")
	await _go(main, 1)
	said = await _ask(main, mode, photo)
	var other_button: Button = mode.controls_by_name().get("partstep_other_0")
	_ok(other_button != null, "\"Not it?\" offers the other guess the car has (%s)" % (
		other_button.text if other_button != null else "none"))
	if other_button != null:
		await _tap(other_button)
		said = main.call("build_state")
		var other_first: int = _first_page_of(pages, world, other, 1)
		_ok(int(said["page"]) == other_first and str(said["partstep"]["part"]) == other,
			"...tapped: %s, its first step %d (page %d)" % [other, other_first, int(said["page"])])
	_close_card(mode)

	print("\n6. a part at a time")
	await _go(main, 1)
	await _tap(mode.controls_by_name()["build_one_part"])
	said = await _ask(main, mode, photo)
	var first_brick: int = -1
	for brick_id: int in pages.added(first):
		if lit.has(brick_id):
			first_brick = brick_id
			break
	var at_part: int = pages.part_of(first, first_brick)
	_ok(int(said["page"]) == first and int(said["part"]) == at_part,
		"step %d at part %d, the part itself (step %d, part %d)" % [first, at_part, int(said["page"]),
			int(said["part"])])
	_ok(_outlined(main, world, {first_brick: true}), "...it alone lit")
	await _shot("6_one_part")
	await _tap(mode.controls_by_name()["build_whole_step"])
	_close_card(mode)

	print("\n7. nothing the car has, and offline")
	await _go(main, 2)
	_reply = _answer([["3001special", "Brick 2 x 4 with special print", 0.71]], -1)
	said = await _ask(main, mode, photo)
	_ok(int(said["page"]) == 2 and str(said["partstep"]["where"]).begins_with("This model has none"),
		"a part the car has not: \"%s\", the page stays" % said["partstep"]["where"])
	mode.photo_url = "http://127.0.0.1:%d/predict/parts/" % NOBODY
	said = await _ask(main, mode, photo)
	_ok(int(said["page"]) == 2 and str(said["partstep"]["title"]) == Brickognize.OFFLINE,
		"offline: \"%s\"" % said["partstep"]["title"])
	mode.photo_url = "http://127.0.0.1:%d/predict/parts/" % STUB
	_reply = answer

	print("\n8. every target a fingertip")
	said = await _ask(main, mode, photo)
	var small := PackedStringArray()
	for name: String in mode.controls_by_name():
		var control: Control = mode.controls_by_name()[name]
		if name.begins_with("partstep_") or name == "build_where":
			var pt: float = mode.points()
			var rect: Rect2 = control.get_global_rect()
			if rect.size.x / pt < TARGET - 0.5 or rect.size.y / pt < TARGET - 0.5:
				small.append("%s %s" % [name, rect.size / pt])
	_ok(small.is_empty(), "\"Where does this go?\" and the card's buttons, 44 points or more (%s)" % (
		"all" if small.is_empty() else ", ".join(small)))
	var free: Rect2 = mode.free_rect()
	var card_rect: Rect2 = (mode.get("_card") as Control).get_global_rect()
	_ok(free.position.y >= card_rect.end.y, "the step framed below the card (%d below %d)" % [
		roundi(free.position.y), roundi(card_rect.end.y)])
	await _shot("8_card")
	_close_card(mode)

	print("\n9. edit_steps over MCP, with a picture")
	_socket = CommandSocket.new()
	_socket.assistant = main.get("_assistant")
	_socket.app = main
	main.add_child(_socket)
	var tools: AppTools = _socket.call("_the_app_tools")
	if tools != null:
		tools.photo_url = "http://127.0.0.1:%d/predict/parts/" % STUB
	_ok(tools != null, "the session's tools, their photos to the stub")
	ShellPrefs.put("photo_told", false)
	var data: String = Marshalls.raw_to_base64(photo.save_jpg_to_buffer(0.85))
	var asked_before: int = _asked
	var heard: String = await _say("edit_steps", {"picture_data": data})
	_ok(heard.begins_with("Not sent.") and heard.contains("agreed=true") and _asked == asked_before,
		"not agreed: refused, nothing sent (\"%s\")" % heard.left(90))
	# A shared link's viewer refuses any change first; the editor, the photo
	# with another op (AppTools._edit_steps). Either way, nothing is sent.
	heard = await _say("edit_steps", {"picture_data": data, "op": "to", "step": 2, "agreed": true})
	var own: String = await tools._edit_steps({"picture_data": data, "op": "to", "step": 2, "agreed": true})
	_ok(_asked == asked_before and own.begins_with("picture_data= or picture_url= finds"),
		"with another op: refused, nothing sent (\"%s\"; the viewer's socket: \"%s\")" % [own.left(70),
			heard.left(70)])
	asked_before = _asked
	var since: int = Time.get_ticks_msec()
	heard = await _say("edit_steps", {"picture_data": data, "agreed": true})
	var steps_said: Array = _steps_in(heard)
	_ok(_asked == asked_before + 1 and steps_said == hits.map(func(page: int) -> int:
			return pages.step_of(page).number),
		"agreed: 1 call, the photo sent once, every step that places it (%s) in %d ms" % [str(steps_said),
			Time.get_ticks_msec() - since])
	_ok(heard.contains("(the first from step 1)") and heard.contains("1. %s" % part),
		"...the first from step 1 marked, the car's part first")
	print("    edit_steps: %s" % heard.replace("\n", " / ").left(400))
	heard = await _say("edit_steps", {"picture_data": data, "agreed": true, "from": int(hits[1])})
	_ok(heard.contains("%d: " % pages.step_of(int(hits[1])).number) and heard.contains(
		"the first from step %d" % int(hits[1])), "from=%d: the first from there" % int(hits[1]))
	ShellPrefs.put("photo_told", true)
	asked_before = _asked
	heard = await _say("edit_steps", {"picture_data": data})
	_ok(_asked == asked_before + 1 and not heard.begins_with("Not sent."),
		"agreed in the app already: sent without agreed=")

	_server.stop()
	await _close(main)
	_finish(told_before)


## The part the car places in the most steps (two or more), in its colour,
## the first of them after step 1: [part, colour, pages].
func _most_placed(pages: BuildSteps, world: BrickWorld) -> Array:
	var placed: Dictionary = {}
	for page: int in range(1, pages.last() + 1):
		for brick_id: int in pages.added(page):
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			var key: String = "%s:%d" % [brick.part_id, brick.color_code]
			if not placed.has(key):
				placed[key] = []
			if not (placed[key] as Array).has(page):
				(placed[key] as Array).append(page)
	var best: Array = []
	for key: String in placed:
		var at: Array = placed[key]
		# The part alone in the car: no other colour of it to read wrong.
		var colours: int = 0
		for other: String in placed:
			if other.get_slice(":", 0) == key.get_slice(":", 0):
				colours += 1
		if at.size() >= 2 and int(at[0]) > 1 and colours == 1 and (best.is_empty() or at.size() > (best[2] as Array).size()):
			best = [key.get_slice(":", 0), int(key.get_slice(":", 1)), at]
	return best


func _another_part(pages: BuildSteps, world: BrickWorld, not_this: String) -> String:
	for page: int in range(1, pages.last() + 1):
		for brick_id: int in pages.added(page):
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick.part_id != not_this:
				return brick.part_id
	return ""


func _first_page_of(pages: BuildSteps, world: BrickWorld, part: String, from: int) -> int:
	for page: int in range(from, pages.last() + 1):
		for brick_id: int in pages.added(page):
			if world.get_brick(brick_id).part_id == part:
				return page
	return -1


func _bricks_of(pages: BuildSteps, world: BrickWorld, page: int, part: String, colour: int) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in pages.added(page):
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick.part_id == part and brick.color_code == colour:
			out[brick_id] = true
	return out


func _name_of(library: PartLibrary, part: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part)
	return info.name.strip_edges().replace("  ", " ") if info != null else part


func _colour_name(library: PartLibrary, code: int) -> String:
	var colour: PartLibrary.BrickColor = library.color(code)
	return colour.name.replace("_", " ") if colour != null else str(code)


## Each step's number edit_steps lists, in order.
func _steps_in(heard: String) -> Array:
	var out: Array = []
	for line: String in heard.split("\n"):
		var trimmed: String = line.strip_edges()
		if line.begins_with("  ") and not trimmed.begins_with("1.") and not trimmed.begins_with("2.") \
				and not trimmed.begins_with("3.") and trimmed.get_slice(":", 0).get_slice(" ", 0).is_valid_int():
			out.append(int(trimmed.get_slice(":", 0).get_slice(" ", 0)))
	return out


## A photo, as the picker hands one over: a phone's 12 megapixels' shape.
func _photo() -> Image:
	var photo := Image.create(1600, 1200, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.7, 0.62, 0.5))
	photo.fill_rect(Rect2i(600, 400, 400, 300), Color(0.8, 0.1, 0.1))
	return photo


## The photo through Build mode as the picker hands one over, the stub
## answering, until the card has its answer or its failure.
func _ask(main: Node, mode: BuildMode, photo: Image) -> Dictionary:
	mode.identify(photo)
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		_serve()
		await process_frame
		# Out of asking: an answer on the card, or why there is none.
		var card: Dictionary = mode.page_state()["partstep"]
		if bool(card["shown"]) and str(card["title"]) != "Asking Brickognize what part this is…":
			break
	await _settle()
	return main.call("build_state")


func _close_card(mode: BuildMode) -> void:
	var close: Button = mode.controls_by_name().get("partstep_close")
	if close != null:
		close.pressed.emit()


func _go(main: Node, page: int) -> void:
	main.call("_build_go", page)
	await _settle()


func _only_a_photo(model: String) -> bool:
	if _bodies.is_empty():
		return false
	var body: PackedByteArray = _bodies[-1]
	var text: String = body.get_string_from_ascii()
	var parts: int = text.count("Content-Disposition: form-data")
	# The model's own lines nowhere in it: a line of the car's, and its name.
	var line: String = ""
	for one: String in model.split("\n"):
		if one.begins_with("1 "):
			line = one.strip_edges()
			break
	return parts == 1 and text.contains("name=\"query_image\"") and text.contains("Content-Type: image/jpeg") \
		and not text.contains(line) and body.size() < 400 * 1024


func _picker_open(mode: BuildMode) -> bool:
	var picker: PickImage = mode.get("_picker")
	return picker != null and picker.get("_dialog") != null and (picker.get("_dialog") as Window).visible


func _hide_picker(mode: BuildMode) -> void:
	var picker: PickImage = mode.get("_picker")
	if picker != null and picker.get("_dialog") != null:
		(picker.get("_dialog") as Window).hide()


func _answer(items: Array, colour_bricklink: int) -> String:
	var listed: Array = []
	for item: Array in items:
		listed.append({"id": item[0], "name": item[1], "type": "part", "score": item[2],
			"external_sites": [{"name": "bricklink",
				"url": "https://www.bricklink.com/v2/catalog/catalogitem.page?P=%s" % item[0]}]})
	var body: Dictionary = {"listing_id": "x", "items": listed}
	if colour_bricklink >= 0:
		body["colors"] = [{"id": str(colour_bricklink), "name": "seen", "score": 0.8}]
	var text: String = JSON.stringify(body)
	return "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		text.to_utf8_buffer().size(), text]


## The stub: each request read whole, then answered with _reply.
func _serve() -> void:
	while _server.is_connection_available():
		var peer: StreamPeerTCP = _server.take_connection()
		_peers.append(peer)
		_heard[peer] = PackedByteArray()
	for peer: StreamPeerTCP in _peers.duplicate():
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.erase(peer)
			_heard.erase(peer)
			continue
		var heard: PackedByteArray = _heard[peer]
		var waiting: int = peer.get_available_bytes()
		if waiting > 0:
			heard.append_array(peer.get_data(waiting)[1])
			_heard[peer] = heard
		var text: String = heard.get_string_from_ascii()
		var head_end: int = text.find("\r\n\r\n")
		if head_end < 0:
			continue
		var length: int = 0
		for line: String in text.substr(0, head_end).split("\r\n"):
			if line.to_lower().begins_with("content-length:"):
				length = int(line.get_slice(":", 1).strip_edges())
		if heard.size() < head_end + 4 + length:
			continue
		_asked += 1
		_bodies.append(heard.slice(head_end + 4))
		peer.put_data(_reply.to_utf8_buffer())
		peer.disconnect_from_host()
		_peers.erase(peer)
		_heard.erase(peer)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var state: Dictionary = {"answer": null}
	var asking: Callable = func() -> void:
		state["answer"] = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
			"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	asking.call()
	var deadline: int = Time.get_ticks_msec() + 40000
	while state["answer"] == null and Time.get_ticks_msec() < deadline:
		_serve()
		await process_frame
	var text: String = ""
	if state["answer"] is Dictionary:
		for block: Dictionary in ((state["answer"] as Dictionary).get("result", {}) as Dictionary).get("content", []):
			text += str(block.get("text", ""))
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _outlined(main: Node, world: BrickWorld, bricks: Dictionary) -> bool:
	var outline: SelectionOutline = main.get("_build_outline")
	var overlay: CanvasItem = outline.get("_overlay")
	if bricks.is_empty() or not outline.visible or overlay == null or not overlay.visible:
		return false
	var want: AABB = world.drawn_as(bricks)[2]
	var got: AABB = outline.get("_bounds")
	return got.position.distance_to(want.position) < 0.5 and got.size.distance_to(want.size) < 0.5


func _open(id: String, text: String, called: String) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": "Probe Model", "author": "Probe Builder",
		"parts": 61, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", id)
	main.set("_shared", fake)
	root.add_child(main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "%s opened as a shared link (%s)" % [called,
		view.state if view != null else "no viewer"])
	var steps: StepsBar = main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(20)
	return main


func _build_it(main: Node) -> BuildMode:
	var view: ShareView = main.get("_share_view")
	await _tap(view.controls_by_name()["view_build"])
	var mode: BuildMode = main.get("_build_mode")
	var since: int = Time.get_ticks_msec()
	while not mode.is_open() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _settle()
	return mode


func _close(main: Node) -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _finish(told_before: Variant) -> void:
	ShellPrefs.put("photo_told", told_before if told_before is bool else false)
	print("\npartstep_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw


## A finger's tap on [param control]: down and up where it is.
func _tap(control: Control) -> void:
	if control == null:
		return
	var at: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await process_frame
	await _settle()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	root.get_texture().get_image().save_png("%s%s_%s.png" % [SHOTS, _size, name])


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
