## Letting the designer see the thing it has been asked to build.
##
## A LEGO designer given "the USS Voyager" has the ship in front of them:
## photographs, orthographic views, a hull they can measure proportions
## off. The designer here had the two words and whatever it could recall,
## and no way to check either against anything. It built a saucer with a
## hull behind it because that is what the words mean, not because it had
## looked at one — and the difference between those two is most of the
## distance between this and a set somebody would buy.
##
## So: fetch pictures of the subject and put them in front of it.
##
## Wikimedia Commons, because it is free, needs no key, carries
## photographs and diagrams of almost any real subject, and licenses them
## for reuse. What comes back is handed to the model as a picture and
## never written anywhere: it is reference, in the sense a designer means
## — something to look at while working.
class_name ReferenceFinder
extends Node

## Found pictures, as [code]{bytes, title, credit}[/code].
signal found(pictures: Array)
## Nothing came back, and why.
signal missed(why: String)

## The search endpoint. generator=search finds pages, and the imageinfo
## property on the same call returns the file URL and its licence, so one
## request answers "what is there" and "where is it".
const SEARCH := "https://commons.wikimedia.org/w/api.php"
## Wide enough to read a shape off, small enough not to spend a tenth of
## a context window on one picture.
const WIDTH := 900
## More than three and the model is reading pictures instead of building.
const MOST := 3
## Somebody has to be able to say who is asking.
const AGENT := "Brickworks/1 (https://brickworks.diy; a CAD application for building bricks)"

## The colours a picture may be read as, [code, Color] each — the plastic
## colours sets are made in now, from whoever asks. Empty, and nothing is
## read: the pictures still come.
var swatches: Array = []

var _host: Node = null
var _pending: Array = []
var _pictures: Array = []
var _asked: String = ""


func _init(host: Node = null) -> void:
	_host = host


## Look for pictures of [param subject]. Answers with [signal found] or
## [signal missed].
func look_for(subject: String) -> void:
	_asked = subject.strip_edges()
	_pictures = []
	_pending = []
	if _asked.is_empty():
		missed.emit("no subject given")
		return

	var query: String = SEARCH + "?" + "&".join([
		"action=query", "format=json", "formatversion=2",
		"generator=search", "gsrnamespace=6",
		# Ask for plenty and choose from them. Scanned books, sound
		# files and slideshows all match words, and filtering a short
		# list leaves one picture where three were wanted.
		"gsrsearch=" + _escaped(_asked), "gsrlimit=%d" % (MOST * 12),
		"prop=imageinfo", "iiprop=url|extmetadata",
		"iiurlwidth=%d" % WIDTH,
	])
	var request := HTTPRequest.new()
	_owner().add_child(request)
	request.request_completed.connect(_on_searched.bind(request))
	if request.request(query, ["User-Agent: " + AGENT]) != OK:
		request.queue_free()
		missed.emit("could not reach Wikimedia Commons")


func _owner() -> Node:
	return _host if _host != null else self


static func _escaped(text: String) -> String:
	return text.uri_encode()


func _on_searched(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if code != 200:
		missed.emit("Wikimedia Commons answered %d" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		missed.emit("Wikimedia Commons sent something that is not JSON")
		return
	var pages: Array = ((parsed as Dictionary).get("query", {}) as Dictionary) \
		.get("pages", [])
	if pages.is_empty():
		missed.emit("nothing on Wikimedia Commons matches \"%s\"" % _asked)
		return

	for page: Variant in pages:
		var one: Dictionary = page
		var info: Array = one.get("imageinfo", [])
		if info.is_empty():
			continue
		var first: Dictionary = info[0]
		var url: String = str(first.get("thumburl", first.get("url", "")))
		var title: String = str(one.get("title", "")).trim_prefix("File:")
		# Drawings and photographs, not sound files or video that happen
		# to match the words.
		if not _is_a_picture(url):
			continue
		# And not a page out of a scanned book. Commons renders those as
		# jpg thumbnails, so the url says picture while the file is a
		# four hundred page PDF — two of the first three answers for a
		# lighthouse were Victorian title pages.
		if _is_a_document(title):
			continue
		_pending.append({
			"url": url,
			"title": title,
			"credit": _credit(first),
		})
		if _pending.size() >= MOST:
			break
	if _pending.is_empty():
		missed.emit("nothing on Wikimedia Commons matches \"%s\"" % _asked)
		return
	_fetch_next()


static func _is_a_picture(url: String) -> bool:
	var lowered: String = url.to_lower()
	for suffix: String in [".jpg", ".jpeg", ".png", ".gif", ".webp"]:
		if lowered.contains(suffix):
			return true
	return false


## A scanned book or a slideshow rather than a picture of the thing.
static func _is_a_document(title: String) -> bool:
	var lowered: String = title.to_lower()
	for suffix: String in [".pdf", ".djvu", ".tif", ".tiff"]:
		if lowered.ends_with(suffix):
			return true
	return false


## Who made it and under what, as Commons records it.
static func _credit(info: Dictionary) -> String:
	var extra: Dictionary = info.get("extmetadata", {}) as Dictionary
	var by: String = str((extra.get("Artist", {}) as Dictionary).get("value", ""))
	var licence: String = str(
		(extra.get("LicenseShortName", {}) as Dictionary).get("value", ""))
	# Commons puts HTML in that field.
	var plain := RegEx.create_from_string("<[^>]+>")
	by = plain.sub(by, "", true).strip_edges()
	if by.is_empty() and licence.is_empty():
		return "Wikimedia Commons"
	if by.is_empty():
		return "Wikimedia Commons, %s" % licence
	return "%s, %s" % [by, licence if not licence.is_empty() else "Wikimedia Commons"]


func _fetch_next() -> void:
	if _pending.is_empty():
		if _pictures.is_empty():
			missed.emit("the pictures could not be fetched")
		else:
			found.emit(_pictures)
		return
	var next: Dictionary = _pending.pop_front()
	var request := HTTPRequest.new()
	_owner().add_child(request)
	request.request_completed.connect(_on_fetched.bind(request, next))
	if request.request(str(next["url"]), ["User-Agent: " + AGENT]) != OK:
		request.queue_free()
		_fetch_next()


func _on_fetched(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, request: HTTPRequest, about: Dictionary) -> void:
	request.queue_free()
	if code == 200 and not body.is_empty():
		var image := Image.new()
		# What it is, read off its first bytes.
		#
		# The extension says what it should be and a thumbnail URL may
		# serve something else, so this used to try each decoder in
		# turn and keep whichever worked. That is right and it is loud:
		# a decoder handed the wrong format prints an engine error
		# before returning its failure, so an ordinary PNG produced two
		# of them in the middle of a design run, and engine errors are
		# what this project treats as a broken build. Every one of
		# these formats says what it is in its first four bytes.
		var ok: bool = false
		match _format_of(body):
			"jpg":
				ok = image.load_jpg_from_buffer(body) == OK
			"png":
				ok = image.load_png_from_buffer(body) == OK
			"webp":
				ok = image.load_webp_from_buffer(body) == OK
		if ok and image.get_width() > 0:
			if image.get_width() > WIDTH:
				image.resize(WIDTH,
					int(float(image.get_height()) * WIDTH / image.get_width()),
					Image.INTERPOLATE_LANCZOS)
			_pictures.append({
				"bytes": image.save_png_to_buffer(),
				"title": about["title"],
				"credit": about["credit"],
				"colours": colours_in(image, swatches),
			})
	_fetch_next()


## What a picture's subject is coloured, as LEGO colours: [param swatches]
## code -> share of the subject, the background left out.
##
## A design given a Falcon Heavy chose its colours from memory and the
## owner's came out in three greys, where the rocket is white with black
## interstages. The picture was in front of it; what was not was the
## number. So the picture is read here, pixel by pixel, into the plastic
## colours sets are made in: the frame's own colours are taken to be the
## background (a sky, a wall, a backdrop), and what is left counts more
## the nearer it is to the middle, where a photograph puts its subject.
## Light matters and is not undone: a white body in shadow reads partly as
## a light grey, and the answer says so rather than pretend.
static func colours_in(image: Image, swatches: Array) -> Dictionary:
	if image == null or swatches.is_empty() or image.get_width() < 8:
		return {}
	var small: Image = image.duplicate()
	if small.is_compressed():
		return {}
	# With its alpha: a drawing on a transparent ground has black there in
	# its colour channels, and read without it the ground is the subject.
	small.convert(Image.FORMAT_RGBA8)
	var wide: int = SAMPLE
	var high: int = maxi(8, int(float(image.get_height()) * SAMPLE / image.get_width()))
	small.resize(wide, high, Image.INTERPOLATE_BILINEAR)
	# The frame: whatever covers much of the outermost pixels is backdrop.
	var frame: Dictionary = {}
	var framed: int = 0
	for y: int in high:
		for x: int in wide:
			if x >= EDGE and x < wide - EDGE and y >= EDGE and y < high - EDGE:
				continue
			if small.get_pixel(x, y).a < 0.5:
				continue
			var bin: int = _bin(small.get_pixel(x, y))
			frame[bin] = int(frame.get(bin, 0)) + 1
			framed += 1
	# A picture with a transparent ground has its backdrop already taken
	# out, and its subject may run to the frame: a rocket drawn the height
	# of its picture had its own white read as the sky.
	var clear: int = 0
	for y: int in high:
		for x: int in wide:
			if small.get_pixel(x, y).a < 0.5:
				clear += 1
	var backdrop: Array[Vector3] = []
	if clear < CUT_OUT * wide * high:
		for bin: int in frame:
			if float(frame[bin]) >= BACKDROP * framed:
				backdrop.append(_lab(_unbin(bin)))
	var labs: Array = []
	for one: Variant in swatches:
		labs.append([int((one as Array)[0]), _lab((one as Array)[1] as Color)])
	var weights: Dictionary = {}
	var total: float = 0.0
	for y: int in high:
		for x: int in wide:
			if small.get_pixel(x, y).a < 0.5:
				continue
			var pixel: Vector3 = _lab(small.get_pixel(x, y))
			var behind: bool = false
			for back: Vector3 in backdrop:
				if pixel.distance_to(back) < NEAR_BACKDROP:
					behind = true
					break
			if behind:
				continue
			var best: int = -1
			var nearest: float = INF
			for one: Array in labs:
				var gap: float = pixel.distance_to(one[1] as Vector3)
				if gap < nearest:
					nearest = gap
					best = int(one[0])
			var across: float = (float(x) + 0.5) / wide - 0.5
			var weight: float = exp(-across * across / 0.045)
			weights[best] = float(weights.get(best, 0.0)) + weight
			total += weight
	if total <= 0.0:
		return {}
	var shares: Dictionary = {}
	for code: int in weights:
		shares[code] = float(weights[code]) / total
	return shares


## How many pixels across a picture is read at: enough for a stripe on a
## rocket, few enough to be quick.
const SAMPLE := 72
## The frame's depth, in those pixels.
const EDGE := 3
## A colour taking this share of the frame is backdrop.
const BACKDROP := 0.06
## A picture this much transparent is a cut-out: the transparency is its
## backdrop.
const CUT_OUT := 0.15
## And a pixel this near one, in CIELAB, is backdrop too.
const NEAR_BACKDROP := 9.0


static func _bin(colour: Color) -> int:
	return (int(colour.r * 15.0) << 8) | (int(colour.g * 15.0) << 4) | int(colour.b * 15.0)


static func _unbin(bin: int) -> Color:
	return Color(((bin >> 8) & 15) / 15.0, ((bin >> 4) & 15) / 15.0, (bin & 15) / 15.0)


## A colour in CIELAB (D65), where distance is close to how different two
## colours look.
static func _lab(colour: Color) -> Vector3:
	var lin := Vector3(_linear(colour.r), _linear(colour.g), _linear(colour.b))
	var x: float = (0.4124 * lin.x + 0.3576 * lin.y + 0.1805 * lin.z) / 0.95047
	var y: float = 0.2126 * lin.x + 0.7152 * lin.y + 0.0722 * lin.z
	var z: float = (0.0193 * lin.x + 0.1192 * lin.y + 0.9505 * lin.z) / 1.08883
	var fx: float = _f(x)
	var fy: float = _f(y)
	var fz: float = _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


## Which picture format a body holds, by its first bytes, or "".
static func _format_of(body: PackedByteArray) -> String:
	if body.size() < 12:
		return ""
	if body[0] == 0xFF and body[1] == 0xD8 and body[2] == 0xFF:
		return "jpg"
	if body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E \
			and body[3] == 0x47:
		return "png"
	if body.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and body.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""
