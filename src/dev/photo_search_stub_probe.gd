## Finding a part from a photo, with Brickognize stood in for: what is said
## before a photo goes, and every way an answer can fail.
##
##   godot --headless --path . --script src/dev/photo_search_stub_probe.gd
##
## The parts bin's camera sends a photo the person chose to Brickognize, a
## third party (src/net/brickognize.gd). Nothing may go before the bin has
## said so, once; and offline, refused, garbled or empty, the answer has to
## be said in words rather than leave the bin waiting. And answered, its
## part comes in the colour the photo shows when Brickognize is sure of it
## (walk256 S3: a black slope came back in the red in hand), and a part made
## in one colour is said to come in one. Brickognize itself is
## a stub here, on a port of this probe's own, and offline is a port with
## nobody on it: photo_search_probe asks the real one.
extends SceneTree

## The stub's port, and one with nobody listening.
const STUB := 9061
const NOBODY := 9062

var _failures: int = 0
var _bin: PartsBin
var _server := TCPServer.new()
## What the stub answers next: a whole HTTP response.
var _reply: String = ""
var _asked: int = 0
## The request line of the last photo asked about.
var _request_line: String = ""
var _peers: Array[StreamPeerTCP] = []
var _heard: Dictionary = {}   ## peer -> bytes read so far


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("photo search probe: no catalogue")
		quit(1)
		return
	_bin = PartsBin.new()
	_bin.library = library
	root.add_child(_bin)
	await process_frame
	_bin.populate()
	await process_frame

	print("  the BrickLink numbers Brickognize answers in, as parts here")
	for pair: Array in [["3001", "3001"], ["3062", "3062b"], ["3069", "3069b"],
			["4073", "6141"], ["3023", "3023b"], ["3040", "3040b"], ["no-such-part", ""]]:
		_check("BrickLink %s is %s here (%s)" % [pair[0], pair[1] if pair[1] != "" else "nothing",
			library.by_shop(pair[0])], library.by_shop(pair[0]) == pair[1])

	print("  said before the first photo, and nothing sent without one")
	var camera: Button = _bin.controls_by_name()["photo search"]
	_check("the search field has a camera in it", camera != null
		and camera.get_parent() == _bin.controls_by_name()["part search"])
	camera.pressed.emit()
	await _frames(2)
	_check("the first press says the photo goes to Brickognize, a third party",
		_bin._telling != null and _bin._telling.visible
		and _bin._telling.dialog_text.contains("Brickognize")
		and _bin._telling.dialog_text.contains("third party"))
	_check("...and nothing is sent", _bin._brickognize._http == null)
	_bin._telling.get_cancel_button().pressed.emit()
	await _frames(2)
	_check("cancelled, nothing is asked for and nothing sent", not _picker_open()
		and _bin._brickognize._http == null and not bool(ShellPrefs.value("photo_told")))
	camera.pressed.emit()
	await _frames(2)
	_bin._telling.get_ok_button().pressed.emit()
	await _frames(2)
	_check("\"Choose a photo\" opens the picker, and still nothing is sent",
		_picker_open() and _bin._brickognize._http == null)
	_bin._picker._dialog.hide()
	camera.pressed.emit()
	await _frames(2)
	_check("told once, the next press opens the picker at once",
		_picker_open() and not _bin._telling.visible)
	_bin._picker._dialog.hide()

	if _server.listen(STUB, "127.0.0.1") != OK:
		print("photo search probe: port %d is taken" % STUB)
		quit(1)
		return
	var photo := Image.create(640, 480, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.8, 0.1, 0.1))

	print("  every way the answer can fail, said plainly")
	_bin._brickognize.url = "http://127.0.0.1:%d/predict/parts/" % NOBODY
	await _ask(photo)
	_check("offline: \"%s\"" % _bin._status.text, _bin._status.text == Brickognize.OFFLINE)
	_bin._brickognize.url = "http://127.0.0.1:%d/predict/parts/" % STUB
	for case: Array in [
			[_http(503, "text/plain", "busy"), "is not answering just now (HTTP 503)"],
			[_http(429, "text/plain", "slow down"), "too many photos from here"],
			[_http(422, "application/json", "{}"), "could not take that photo (HTTP 422)"],
			[_http(200, "text/html", "<html>gateway</html>"), "not an answer"],
			[_http(200, "application/json", "{\"listing_id\": \"x\", \"items\": []}"),
				"saw no part it knows"]]:
		_reply = case[0]
		await _ask(photo)
		_check("%s: \"%s\"" % [case[1], _bin._status.text], _bin._status.text.contains(case[1]))

	print("  an answer, as the bin's results")
	var asked_before: int = _asked
	_reply = _http(200, "application/json", JSON.stringify({"listing_id": "x", "items": [
		_item("3062", "Brick, Round 1 x 1", 0.41),
		_item("3001", "Brick 2 x 4", 0.72),
		_item("bogus-77", "A part nobody has", 0.35)]}))
	await _ask(photo)
	_check("the photo was sent once (%d)" % (_asked - asked_before), _asked - asked_before == 1)
	_check("its guesses are the results, most likely first (%s)" % str(_bin.first_found()),
		_bin.first_found() == PackedStringArray(["3001", "3062b"]))
	var label: String = ""
	if _bin._grid.get_child_count() > 0:
		for node: Node in _bin._grid.get_child(0).find_children("*", "Label", true, false):
			label = (node as Label).text
	# The name, then how sure: on the name's line when it fits, else under it.
	var words: String = " ".join(label.replace("\n", " ").split(" ", false))
	_check("each names its part and says how sure Brickognize is (\"%s\")" % words,
		words == "%s 72%%" % PartsBin.tile_name(_bin.library.parts["3001"]))
	_check("what has no part here is said (\"%s\")" % _bin._status.tooltip_text,
		_bin._status.tooltip_text.contains("bogus-77"))

	print("  in the colour the photo shows")
	# walk256 (S3): a black slope's photo was shown in red, the colour in hand.
	_bin.choose_colour(4)
	_reply = _http(200, "application/json", JSON.stringify({"listing_id": "x",
		"items": [_item("3039", "Slope 45 2 x 2", 0.83)],
		"colors": [{"id": "11", "name": "Black", "score": 0.81}]}))
	await _ask(photo)
	_check("the photo's colour is asked for (%s)" % _request_line,
		_request_line.contains("predict_color=true"))
	_check("its part comes in the photo's colour, Black, not the red in hand (%s)"
		% library.color(_bin.selected_color()).name, _bin.selected_color() == 0
		and _bin.first_found() == PackedStringArray(["3039"]))
	_check("and the line says so: \"%s\"" % _bin._status.text, _bin._status.text.ends_with("in Black"))
	_bin.choose_colour(4)
	_reply = _http(200, "application/json", JSON.stringify({"listing_id": "x",
		"items": [_item("3039", "Slope 45 2 x 2", 0.83)],
		"colors": [{"id": "11", "name": "Black", "score": 0.12}]}))
	await _ask(photo)
	_check("a colour Brickognize is not sure of leaves the one in hand (%s)"
		% library.color(_bin.selected_color()).name, _bin.selected_color() == 4)
	_reply = _http(200, "application/json", JSON.stringify({"listing_id": "x",
		"items": [_item("3039", "Slope 45 2 x 2", 0.83)]}))
	await _ask(photo)
	_check("and so does an answer with none (%s)" % library.color(_bin.selected_color()).name,
		_bin.selected_color() == 4 and not _bin._status.text.contains(" in "))
	# And what the palette says of a part made in one colour (walk256 S3: "A
	# dot marks the 1 colours 3648a comes in").
	var gear: PartLibrary.PartInfo = library.parts.get("3648a")
	if gear != null and gear.availability_known() and gear.colors.size() == 1:
		_bin.show_held("3648a", int(gear.colors[0]))
		_bin._say_colour()
		_check("a part made in one colour is said so: \"%s\"" % _bin._colour_note.text,
			_bin._colour_note.text.contains("the 1 colour 3648a comes in"))
	else:
		_check("3648a is known in one colour", false)
	_bin._search.text = "plate"
	_bin._run_search("plate")
	_check("typing a search puts the photo's results away",
		_bin._guesses.is_empty() and not _bin.first_found().has("3062b"))

	_server.stop()
	_bin.queue_free()
	await _frames(2)
	print("")
	if _failures == 0:
		print("photo search, stubbed: said before the first photo, nothing sent without one, "
			+ "and every failure said in words")
	else:
		print("photo search, stubbed: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _picker_open() -> bool:
	return _bin._picker._dialog != null and _bin._picker._dialog.visible


## A photo through the bin, as the picker hands one over, and its answer
## waited for while the stub answers.
func _ask(photo: Image) -> void:
	var done: Array = [false]
	var finish: Callable = func(_any: Variant = null) -> void: done[0] = true
	_bin._brickognize.answered.connect(finish, CONNECT_ONE_SHOT)
	_bin._brickognize.failed.connect(finish, CONNECT_ONE_SHOT)
	_bin._identify(photo)
	var deadline: int = Time.get_ticks_msec() + 15000
	while not done[0] and Time.get_ticks_msec() < deadline:
		_serve()
		await process_frame
	for signal_of: Signal in [_bin._brickognize.answered, _bin._brickognize.failed]:
		if signal_of.is_connected(finish):
			signal_of.disconnect(finish)
	await _frames(2)


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
		# A packed array is a value: what is read is put back.
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
		_request_line = text.substr(0, text.find("\r\n"))
		peer.put_data(_reply.to_utf8_buffer())
		peer.disconnect_from_host()
		_peers.erase(peer)
		_heard.erase(peer)


static func _http(code: int, kind: String, body: String) -> String:
	return "HTTP/1.1 %d X\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [
		code, kind, body.to_utf8_buffer().size(), body]


static func _item(bricklink: String, name: String, score: float) -> Dictionary:
	return {"id": bricklink, "name": name, "type": "part", "score": score,
		"external_sites": [{"name": "bricklink",
			"url": "https://www.bricklink.com/v2/catalog/catalogitem.page?P=%s" % bricklink}]}


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
