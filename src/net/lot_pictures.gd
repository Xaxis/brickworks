## Every lot's picture of a shared model, drawn once by the server
## (api/_lot_pictures.js, /m/<id>/v/<n>/parts.png) and taken into the
## pictures the app shows ([PartThumbnails]) as the model opens (partpics,
## 2026-11-24).
##
## A part's picture is otherwise drawn here: a little scene of its own, drawn
## in a frame of the whole window and read back once the card has drawn it. In
## a browser drawing in software that frame is the whole model too, and Build
## it's first step showed its parts as counts over empty boxes for 8.5 s
## (Survey Ship on a phone, billbuilds). The share answer names one file with
## every lot of the version drawn in it, in its colour; the page fetches it
## beside the model while the engine starts (src/boot/shell.html,
## window.brickworksLots), so by the first step it is here, and the step bar,
## Build it and the parts list show them as they are laid. What the file has
## not (a part it could not draw) is drawn here as before.
##
## The file is a PNG of TILE-pixel squares, ACROSS to a row, in the order of
## the index in its tEXt chunk "brickworks-lots": JSON {tile, across, of,
## lots: [[part, colour], ...]}.
class_name LotPictures
extends RefCounted

const INDEX := "brickworks-lots"
## The most a file may be, in bytes: 1,024 lots at most, far under this.
const MOST_BYTES := 16 * 1024 * 1024
## How long a file the page is still fetching is waited for, in ms, before
## it is asked for here.
const EARLY_WAIT_MS := 20000
## What the share answer's address must look like: this deployment's own
## /m/<id>/v/<n>/parts.png?f=<file>, nothing else fetched.
const PATH := "^/m/[A-Za-z0-9]{10}/v/[1-9][0-9]{0,5}/parts\\.png\\?f=[0-9a-f]{12}$"

## The last file taken, for a check to read: its address, how many lots, in
## ms how long from asking to taken, and from where ("page, read", "page",
## "asked"); "drawing" when the server had not drawn it yet.
static var said: Dictionary = {}

## The file the open model's share answer names, not asked for yet, and the
## pictures it is for. Asked for only when Build it or a part's card lays its
## tiles, or a step is taken in the step bar ([method want]): a model only
## looked at costs nothing.
static var _offered: String = ""
static var _offered_to: WeakRef = null


## The model [param body] (a share answer, SharedModels.fetch) is open: its
## lot pictures are to be asked for when someone builds it. Taken at
## once where the page fetched them already, which it does only for a link
## that opens Build it (src/boot/shell.html).
static func offer(body: Dictionary, thumbnails: PartThumbnails) -> void:
	var path: String = str(body.get("lot_pictures", ""))
	_offered = path if thumbnails != null and RegEx.create_from_string(PATH).search(path) != null else ""
	_offered_to = weakref(thumbnails) if not _offered.is_empty() else null
	said = {}
	if _offered.is_empty() or not OS.has_feature("web"):
		return
	if int(JavaScriptBridge.eval("(function(u){var l=window.brickworksLots;return l && l.url===u ? 1 : 0})(%s)"
			% JSON.stringify(_offered), true)) == 1:
		want()


## The offered file asked for and taken, once: called as Build it's tiles are
## laid, before they look for their pictures, and as a step is taken.
static func want() -> void:
	if _offered.is_empty() or _offered_to == null:
		return
	var thumbnails: PartThumbnails = _offered_to.get_ref() as PartThumbnails
	var path: String = _offered
	_offered = ""
	if thumbnails == null:
		return
	# Fetched and read by the page, on the browser's threads, where it can:
	# read here on a worker, a phone at load 119 had its first step 4.7 s
	# before the pictures came (bench/results/partpics-2026-11-24/tap).
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.brickworksLotsAsk && window.brickworksLotsAsk(%s)" % JSON.stringify(path), true)
	_take(path, thumbnails)


## [param path] fetched (or taken from the page) and handed to
## [param thumbnails]: true when it was.
static func _take(path: String, thumbnails: PartThumbnails) -> bool:
	var host: Node = (Engine.get_main_loop() as SceneTree).root
	var began: int = Time.get_ticks_msec()
	var from: String = "page"
	var early: Dictionary = await _early(path)
	var bytes: PackedByteArray = early.get("bytes", PackedByteArray())
	# Read by the page already: its pixels taken as they are, in this frame.
	var pixels: PackedByteArray = early.get("pixels", PackedByteArray())
	var width: int = int(early.get("width", 0))
	var height: int = int(early.get("height", 0))
	if not bytes.is_empty() and width > 0 and height > 0 and pixels.size() == width * height * 4:
		var lots_now: int = thumbnails.take_sheet_image(
			Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels), index_of(bytes))
		said = {"url": path, "lots": lots_now, "ms": Time.get_ticks_msec() - began, "from": "page, read"}
		if lots_now > 0:
			return true
	if bytes.is_empty() and early.has("status"):
		# The page asked already: not drawn yet (202) or not to be had. The
		# tiles keep their parts' shapes and are drawn here, as before.
		said = {"url": path, "lots": 0, "ms": Time.get_ticks_msec() - began,
			"from": "drawing" if int(early["status"]) == 202 else "failed"}
		return false
	if bytes.is_empty():
		from = "asked"
		var result: Array = await PageFetch.ask(host, Deployment.api_base() + path, PackedStringArray(),
			HTTPClient.METHOD_GET, "", 60.0, MOST_BYTES)
		if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
			said = {"url": path, "lots": 0, "ms": Time.get_ticks_msec() - began,
				"from": "drawing" if int(result[1]) == 202 else "failed"}
			return false
		bytes = result[3]
	# Read on a worker: Orthanc's 226 lots are a 1536 x 1440 picture, 28 ms
	# to read on a desktop and more in a browser, in the frame the model opens.
	var index: Dictionary = index_of(bytes)
	var image: Variant = await WorkerTasks.awaited(func() -> Variant:
		var read := Image.new()
		return read if read.load_png_from_buffer(bytes) == OK else null, "read the lot pictures")
	var lots: int = 0
	if image is Image and is_instance_valid(thumbnails):
		lots = thumbnails.take_sheet_image(image, index)
	said = {"url": path, "lots": lots, "ms": Time.get_ticks_msec() - began, "from": from}
	return lots > 0


## [param path] as the page fetched it (window.brickworksLots), waited for a
## frame at a time while it is on its way: {bytes, and where the page read
## it too, pixels (RGBA, a row after another), width, height}; {status}
## when the page asked and had no file (202 while the server draws it); {}
## when the page did not ask.
static func _early(path: String) -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var asked: String = ("(function(u){var l=window.brickworksLots;"
		+ "return l && l.url===u ? (l.done ? (l.status===200 && l.bytes ? 2 : 3) : 1) : 0})(%s)") % JSON.stringify(path)
	var until: int = Time.get_ticks_msec() + EARLY_WAIT_MS
	var state: Variant = JavaScriptBridge.eval(asked, true)
	while state != null and int(state) == 1 and Time.get_ticks_msec() < until:
		await tree.process_frame
		state = JavaScriptBridge.eval(asked, true)
	if state != null and int(state) == 3:
		var status: int = int(JavaScriptBridge.eval("window.brickworksLots.status", true))
		JavaScriptBridge.eval("window.brickworksLots=null", true)
		return {"status": status}
	if state == null or int(state) != 2:
		return {}
	var bytes: Variant = JavaScriptBridge.eval("window.brickworksLots.bytes", true)
	if not bytes is PackedByteArray or (bytes as PackedByteArray).size() > MOST_BYTES:
		JavaScriptBridge.eval("window.brickworksLots=null", true)
		return {}
	# Only numbers, words and buffers come back from the page: "width,height".
	var size: PackedStringArray = str(JavaScriptBridge.eval(
		"(function(l){return l.pixels ? l.width + ',' + l.height : ''})(window.brickworksLots)", true)).split(",")
	var width: int = int(size[0]) if size.size() == 2 else 0
	var height: int = int(size[1]) if size.size() == 2 else 0
	var pixels: Variant = PackedByteArray()
	if width > 0 and height > 0 and width * height * 4 <= 64 * 1024 * 1024:
		pixels = JavaScriptBridge.eval("window.brickworksLots.pixels", true)
	JavaScriptBridge.eval("window.brickworksLots=null", true)
	return {"bytes": bytes, "pixels": pixels if pixels is PackedByteArray else PackedByteArray(),
		"width": width, "height": height}


## The index a file carries (its "brickworks-lots" tEXt chunk), or {} when it
## has none or is not a PNG.
static func index_of(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8 or bytes.slice(1, 4).get_string_from_ascii() != "PNG":
		return {}
	var at: int = 8
	while at + 8 <= bytes.size():
		var length: int = (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]
		var type: String = bytes.slice(at + 4, at + 8).get_string_from_ascii()
		if length < 0 or at + 12 + length > bytes.size():
			return {}
		if type == "tEXt":
			var body: PackedByteArray = bytes.slice(at + 8, at + 8 + length)
			var zero: int = body.find(0)
			if zero > 0 and body.slice(0, zero).get_string_from_ascii() == INDEX:
				var read: Variant = JSON.parse_string(body.slice(zero + 1).get_string_from_utf8())
				return read if read is Dictionary else {}
		if type == "IDAT" or type == "IEND":
			return {}
		at += 12 + length
	return {}
