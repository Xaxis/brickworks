## Reading a BrickLink Studio model (.io).
##
## An .io file is a zip around an LDraw model: model.ldr (or model2.ldr in
## newer saves), its thumbnail, a few lines of settings. Studio has written
## it with a password since 2.0 — the same one in every file, published by
## everyone who has read one — so the zip is opened here by hand: Godot's
## own reader takes no password, and the cipher is the old PKWARE one, a
## dozen lines of arithmetic. What comes out is LDraw, which the app reads.
##
## Studio's own parts that LDraw has not got come out as unknown parts and
## are counted as missing, as from any other LDraw file.
class_name StudioIo
extends RefCounted

## Every Studio file's password.
const PASSWORD := "soho0909"

static var _crc_table: PackedInt64Array = PackedInt64Array()


## The LDraw text inside an .io file: {"text": ..., "error": ""}, or an
## error saying what was wrong.
static func read(bytes: PackedByteArray) -> Dictionary:
	var entries: Dictionary = _entries(bytes)
	if entries.has("error"):
		return {"text": "", "error": str(entries["error"])}
	# The newer model first: model2.ldr is what Studio 2 writes, and
	# model.ldr beside it is kept for older readers.
	for name: String in ["model2.ldr", "model.ldr"]:
		if entries.has(name):
			var data: PackedByteArray = _unpack(bytes, entries[name])
			if data.is_empty():
				return {"text": "", "error": "could not unpack %s from the .io file" % name}
			return {"text": data.get_string_from_utf8(), "error": ""}
	return {"text": "", "error": "no model inside that .io file"}


## The zip's members by name: where each starts and how it is packed, read
## from the central directory at the end, which states every size even
## when a member's own header leaves them until after its data.
static func _entries(bytes: PackedByteArray) -> Dictionary:
	var end: int = -1
	var n: int = bytes.size() - 22
	while n >= maxi(0, bytes.size() - 22 - 65535):
		if bytes.decode_u32(n) == 0x06054b50:
			end = n
			break
		n -= 1
	if end < 0:
		return {"error": "that is not a Studio .io file"}
	var count: int = bytes.decode_u16(end + 10)
	var at: int = bytes.decode_u32(end + 16)
	var out: Dictionary = {}
	for _entry: int in count:
		if at + 46 > bytes.size() or bytes.decode_u32(at) != 0x02014b50:
			return {"error": "that .io file is damaged"}
		var flags: int = bytes.decode_u16(at + 8)
		var method: int = bytes.decode_u16(at + 10)
		var crc: int = bytes.decode_u32(at + 16)
		var packed: int = bytes.decode_u32(at + 20)
		var size: int = bytes.decode_u32(at + 24)
		var name_length: int = bytes.decode_u16(at + 28)
		var extra_length: int = bytes.decode_u16(at + 30)
		var comment_length: int = bytes.decode_u16(at + 32)
		var local: int = bytes.decode_u32(at + 42)
		var name: String = bytes.slice(at + 46, at + 46 + name_length).get_string_from_utf8()
		at += 46 + name_length + extra_length + comment_length
		if local + 30 > bytes.size():
			continue
		var data: int = local + 30 + bytes.decode_u16(local + 26) + bytes.decode_u16(local + 28)
		out[name.get_file().to_lower()] = {"at": data, "packed": packed, "size": size,
			"method": method, "crc": crc, "encrypted": flags & 0x01 != 0}
	if out.is_empty():
		return {"error": "that is not a Studio .io file"}
	return out


static func _unpack(bytes: PackedByteArray, entry: Dictionary) -> PackedByteArray:
	var data: PackedByteArray = bytes.slice(int(entry["at"]), int(entry["at"]) + int(entry["packed"]))
	if bool(entry["encrypted"]):
		data = _decrypt(data)
		if data.size() < 12:
			return PackedByteArray()
		data = data.slice(12)
	match int(entry["method"]):
		0:
			return data
		8:
			return _inflate(data, int(entry["crc"]), int(entry["size"]))
	return PackedByteArray()


## PKWARE's traditional encryption, undone.
static func _decrypt(data: PackedByteArray) -> PackedByteArray:
	var keys: Array[int] = [305419896, 591751049, 878082192]
	for c: int in PASSWORD.to_utf8_buffer():
		_update(keys, c)
	var out := PackedByteArray()
	out.resize(data.size())
	for n: int in data.size():
		var temp: int = (keys[2] | 2) & 0xFFFF
		var plain: int = data[n] ^ (((temp * (temp ^ 1)) >> 8) & 0xFF)
		out[n] = plain
		_update(keys, plain)
	return out


static func _update(keys: Array[int], c: int) -> void:
	keys[0] = _crc_byte(keys[0], c)
	keys[1] = ((keys[1] + (keys[0] & 0xFF)) * 134775813 + 1) & 0xFFFFFFFF
	keys[2] = _crc_byte(keys[2], (keys[1] >> 24) & 0xFF)


static func _crc_byte(crc: int, c: int) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n: int in 256:
			var value: int = n
			for _k: int in 8:
				value = (0xEDB88320 ^ (value >> 1)) if value & 1 else (value >> 1)
			_crc_table[n] = value
	return (_crc_table[(crc ^ c) & 0xFF] ^ (crc >> 8)) & 0xFFFFFFFF


## Raw deflate, inflated: Godot inflates gzip, and a gzip file is raw
## deflate between a fixed header and the CRC and size the zip already
## states.
static func _inflate(raw: PackedByteArray, crc: int, size: int) -> PackedByteArray:
	var wrapped := PackedByteArray([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff])
	wrapped.append_array(raw)
	var tail := PackedByteArray()
	tail.resize(8)
	tail.encode_u32(0, crc)
	tail.encode_u32(4, size)
	wrapped.append_array(tail)
	return wrapped.decompress(size, FileAccess.COMPRESSION_GZIP)
