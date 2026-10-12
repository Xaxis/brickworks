## A turntable as one animated WebP: every browser plays it, and a page,
## a chat or a forum post takes it as a picture.
##
## Godot writes a WebP of one picture and none of several, so each frame is
## encoded as a still (Image.save_webp_to_buffer, native and fast) and the
## stills' bitstreams are put into the animated container by hand: a VP8X
## header saying it is animated, an ANIM chunk saying it loops, and an ANMF
## chunk per frame holding that frame's own ALPH and VP8 or VP8L chunks.
## Byte layout from Google's WebP container specification.
class_name AnimatedWebP
extends RefCounted

var _frames: Array[PackedByteArray] = []
var _size: Vector2i = Vector2i.ZERO
var _alpha: bool = false
var _duration_ms: int = 42


func _init(frames_per_second: int = 24) -> void:
	_duration_ms = maxi(1, roundi(1000.0 / float(maxi(frames_per_second, 1))))


## One still's encoded frame, from Image.save_webp_to_buffer. Every frame
## must be the same size.
func add_encoded(still: PackedByteArray, size: Vector2i) -> bool:
	var chunks: PackedByteArray = _frame_chunks(still)
	if chunks.is_empty():
		return false
	if _frames.is_empty():
		_size = size
	elif size != _size:
		return false
	_frames.append(chunks)
	return true


func add(image: Image, lossy: bool = true, quality: float = 0.9) -> bool:
	if image.detect_alpha() != Image.ALPHA_NONE:
		_alpha = true
	return add_encoded(image.save_webp_to_buffer(lossy, quality),
		Vector2i(image.get_width(), image.get_height()))


func frame_count() -> int:
	return _frames.size()


## Say the frames carry alpha. A frame encoded elsewhere does not say.
func with_alpha(on: bool) -> void:
	_alpha = _alpha or on


## The whole file.
func bytes() -> PackedByteArray:
	var body := PackedByteArray()
	body.append_array("WEBP".to_ascii_buffer())
	var vp8x := PackedByteArray()
	vp8x.append(0x02 | (0x10 if _alpha else 0x00))
	vp8x.append_array([0, 0, 0])
	vp8x.append_array(_u24(_size.x - 1))
	vp8x.append_array(_u24(_size.y - 1))
	body.append_array(_chunk("VP8X", vp8x))
	var anim := PackedByteArray()
	# Background, blue green red alpha: clear, and loop for ever.
	anim.append_array([0, 0, 0, 0, 0, 0])
	body.append_array(_chunk("ANIM", anim))
	for frame: PackedByteArray in _frames:
		var anmf := PackedByteArray()
		anmf.append_array(_u24(0))
		anmf.append_array(_u24(0))
		anmf.append_array(_u24(_size.x - 1))
		anmf.append_array(_u24(_size.y - 1))
		anmf.append_array(_u24(_duration_ms))
		# Not blended over the last frame, not disposed: each frame whole.
		anmf.append(0x02)
		anmf.append_array(frame)
		body.append_array(_chunk("ANMF", anmf))
	var file := PackedByteArray()
	file.append_array("RIFF".to_ascii_buffer())
	file.append_array(_u32(body.size()))
	file.append_array(body)
	return file


## The chunks of a still that are its picture: ALPH, VP8 or VP8L. Empty if
## it is not a WebP.
static func _frame_chunks(still: PackedByteArray) -> PackedByteArray:
	if still.size() < 20 or still.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or still.slice(8, 12).get_string_from_ascii() != "WEBP":
		return PackedByteArray()
	var out := PackedByteArray()
	var at: int = 12
	while at + 8 <= still.size():
		var tag: String = still.slice(at, at + 4).get_string_from_ascii()
		var length: int = still.decode_u32(at + 4)
		var whole: int = 8 + length + (length & 1)
		if tag in ["ALPH", "VP8 ", "VP8L"]:
			out.append_array(still.slice(at, mini(at + whole, still.size())))
		at += whole
	return out


## Frame [param n] of an animated WebP as a WebP of its own, for something
## that reads stills only (Image.load_webp_from_buffer) to check it by.
static func still(file: PackedByteArray, n: int) -> PackedByteArray:
	var at: int = 12
	var seen: int = 0
	while at + 8 <= file.size():
		var tag: String = file.slice(at, at + 4).get_string_from_ascii()
		var length: int = file.decode_u32(at + 4)
		if tag == "ANMF":
			if seen == n:
				var frame: PackedByteArray = file.slice(at + 8 + 16, at + 8 + length)
				var body := PackedByteArray()
				body.append_array("WEBP".to_ascii_buffer())
				if _has_chunk(frame, "ALPH"):
					var vp8x := PackedByteArray([0x10, 0, 0, 0])
					vp8x.append_array(file.slice(at + 8 + 6, at + 8 + 12))
					body.append_array(_chunk("VP8X", vp8x))
				body.append_array(frame)
				var out := PackedByteArray()
				out.append_array("RIFF".to_ascii_buffer())
				out.append_array(_u32(body.size()))
				out.append_array(body)
				return out
			seen += 1
		at += 8 + length + (length & 1)
	return PackedByteArray()


static func _has_chunk(chunks: PackedByteArray, tag: String) -> bool:
	var at: int = 0
	while at + 8 <= chunks.size():
		if chunks.slice(at, at + 4).get_string_from_ascii() == tag:
			return true
		var length: int = chunks.decode_u32(at + 4)
		at += 8 + length + (length & 1)
	return false


## Every chunk in a WebP file, by tag, in order: for a probe to read back.
static func chunk_tags(file: PackedByteArray) -> PackedStringArray:
	var tags := PackedStringArray()
	if file.size() < 12:
		return tags
	var at: int = 12
	while at + 8 <= file.size():
		var tag: String = file.slice(at, at + 4).get_string_from_ascii()
		tags.append(tag)
		var length: int = file.decode_u32(at + 4)
		at += 8 + length + (length & 1)
	return tags


static func _chunk(tag: String, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(tag.to_ascii_buffer())
	out.append_array(_u32(payload.size()))
	out.append_array(payload)
	if payload.size() & 1:
		out.append(0)
	return out


static func _u24(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF])


static func _u32(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF,
		(value >> 24) & 0xFF])
