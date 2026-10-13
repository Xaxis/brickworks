## BrickLink Studio's model file (.io), read and written.
##
## An .io is a zip. Two saved by Studio itself were opened to learn what is
## in one (2.2.1 in 2021, password-locked; 2.25.2 in 2025, not locked):
##
##   model.ldr          the model in plain LDraw: LDraw's colour codes and
##                      part numbers, sub-models as 0 FILE sections, 0 STEP
##   model2.ldr         the same model in BrickLink's numbering (white is 1,
##                      not 15; a 2 x 2 tile 3068, not 3068b), carrying the
##                      geometry of every part it uses
##   modelv1.ldr /      Studio's own lines, "10 <colour> False 0 …" (2021)
##   modelv2.ldr        and "11 <colour> <id> False 0 …" (2025)
##   .info              {"version":"2.25.2_1","total_parts":1500,…}
##   thumbnail.png, errorPartList.err ("[]"), model.lxfml, CustomParts/
##
## So model.ldr is what opens here, through the LDraw reader, and needs no
## numbers changed. It read model2.ldr first, believing it the newer of
## the two, and a Studio model came in in BrickLink's colour numbers read
## as LDraw's: its white (BrickLink's 1) blue, its black (11) turquoise,
## and the pink elephant of 2021 in colours LDraw has no number for. Its
## own test file had been made by hand with LDraw's numbers in model2.ldr,
## so it passed.
##
## Studio locked the zip with a password until some version between those
## two, the same one in every file and published by everyone who has read
## one, with the old PKWARE cipher (and in some files, by another reader's
## account, WinZip's AES): Godot's zip reader takes no password, so the zip
## is read here by hand.
##
## Writing (``pack``) makes what Studio 2.25 writes, less what only Studio
## can make: model.ldr, the thumbnail, .info and an empty error list, not
## locked. Whether Studio opens it has not been seen — there is no Studio
## on this machine — so the model inside is standard LDraw, which Studio's
## own LDraw import reads, and nothing is guessed at in Studio's own lines.
class_name StudioIo
extends RefCounted

## Every Studio file's password.
const PASSWORD := "soho0909"
## What .info says made the file. A real Studio's (2.2.1, the older of the
## two read), so a Studio that reads it to decide how to open the file is
## told something it knows; see the class notes.
const INFO_VERSION := "2.2.1_1"

static var _crc_table: PackedInt64Array = PackedInt64Array()


## The LDraw text inside an .io file: {"text": ..., "error": ""}, or an
## error saying what was wrong.
static func read(bytes: PackedByteArray) -> Dictionary:
	var entries: Dictionary = _entries(bytes)
	if entries.has("error"):
		return {"text": "", "error": str(entries["error"])}
	if not entries.has("model.ldr"):
		return {"text": "", "error": "there is no model.ldr inside that .io file"}
	var entry: Dictionary = entries["model.ldr"]
	if entry.has("aes") and not int(entry["aes"]["strength"]) in [1, 3]:
		return {"text": "", "error": "that .io file is locked with AES-192, which Brickworks "
			+ "cannot open: saving it again in a current Studio writes one it can"}
	var data: PackedByteArray = _unpack(bytes, entry)
	if data.is_empty():
		return {"text": "", "error": "could not unpack the model from that .io file: "
			+ "it is damaged, or locked with a password that is not Studio's"}
	# Studio starts the text with a byte-order mark, which LDraw's line
	# types are not read through.
	if data.size() >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF:
		data = data.slice(3)
	return {"text": data.get_string_from_utf8(), "error": ""}


## An .io file holding [param text] as its model.ldr, with [param
## thumbnail] (PNG bytes, or none) and [param parts] counted in .info.
static func pack(text: String, thumbnail: PackedByteArray, parts: int) -> PackedByteArray:
	# Studio writes its LDraw with Windows line ends, as LDraw allows.
	var ldr: String = text.replace("\r\n", "\n").replace("\n", "\r\n")
	var members: Array = [
		["model.ldr", ldr.to_utf8_buffer()],
		[".info", JSON.stringify({"version": INFO_VERSION, "total_parts": parts}).to_utf8_buffer()],
		["errorPartList.err", "[]".to_utf8_buffer()],
	]
	if not thumbnail.is_empty():
		members.append(["thumbnail.png", thumbnail])
	return zip(members)


## A zip of [param members], [[name, bytes], …], each deflated.
##
## Godot's ZIPPacker writes only to a path, and in a browser the bytes are
## wanted, not a file. Deflate comes from Godot's gzip, which is raw
## deflate between a ten-byte header and the CRC-32 and length a zip
## states, so the CRC is not worked out here a byte at a time.
static func zip(members: Array) -> PackedByteArray:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var dos_time: int = (int(now["hour"]) << 11) | (int(now["minute"]) << 5) | (int(now["second"]) / 2)
	var dos_date: int = ((maxi(int(now["year"]), 1980) - 1980) << 9) | (int(now["month"]) << 5) \
		| int(now["day"])
	var out := PackedByteArray()
	var directory := PackedByteArray()
	for member: Array in members:
		var name: PackedByteArray = str(member[0]).to_utf8_buffer()
		var data: PackedByteArray = member[1]
		var method: int = 0
		var packed: PackedByteArray = data
		var crc: int = 0
		if not data.is_empty():
			var gz: PackedByteArray = data.compress(FileAccess.COMPRESSION_GZIP)
			crc = gz.decode_u32(gz.size() - 8)
			method = 8
			packed = gz.slice(10, gz.size() - 8)
		var header := PackedByteArray()
		header.resize(30)
		header.encode_u32(0, 0x04034b50)
		header.encode_u16(4, 20)
		header.encode_u16(6, 0)
		header.encode_u16(8, method)
		header.encode_u16(10, dos_time)
		header.encode_u16(12, dos_date)
		header.encode_u32(14, crc)
		header.encode_u32(18, packed.size())
		header.encode_u32(22, data.size())
		header.encode_u16(26, name.size())
		header.encode_u16(28, 0)
		var central := PackedByteArray()
		central.resize(46)
		central.encode_u32(0, 0x02014b50)
		central.encode_u16(4, 20)
		central.encode_u16(6, 20)
		central.encode_u16(8, 0)
		central.encode_u16(10, method)
		central.encode_u16(12, dos_time)
		central.encode_u16(14, dos_date)
		central.encode_u32(16, crc)
		central.encode_u32(20, packed.size())
		central.encode_u32(24, data.size())
		central.encode_u16(28, name.size())
		# Extra field, comment, disk, internal and external attributes: none.
		central.encode_u32(42, out.size())
		directory.append_array(central)
		directory.append_array(name)
		out.append_array(header)
		out.append_array(name)
		out.append_array(packed)
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, 0x06054b50)
	end.encode_u16(8, members.size())
	end.encode_u16(10, members.size())
	end.encode_u32(12, directory.size())
	end.encode_u32(16, out.size())
	out.append_array(directory)
	out.append_array(end)
	return out


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
		var time: int = bytes.decode_u16(at + 12)
		var crc: int = bytes.decode_u32(at + 16)
		var packed: int = bytes.decode_u32(at + 20)
		var size: int = bytes.decode_u32(at + 24)
		var name_length: int = bytes.decode_u16(at + 28)
		var extra_length: int = bytes.decode_u16(at + 30)
		var comment_length: int = bytes.decode_u16(at + 32)
		var local: int = bytes.decode_u32(at + 42)
		var name: String = bytes.slice(at + 46, at + 46 + name_length).get_string_from_utf8()
		var aes: Dictionary = _aes_field(bytes.slice(at + 46 + name_length,
			at + 46 + name_length + extra_length))
		at += 46 + name_length + extra_length + comment_length
		if local + 30 > bytes.size() or bytes.decode_u32(local) != 0x04034b50:
			return {"error": "that .io file is damaged"}
		var data: int = local + 30 + bytes.decode_u16(local + 26) + bytes.decode_u16(local + 28)
		if data + packed > bytes.size():
			return {"error": "that .io file is damaged"}
		# Studio's custom parts are in a folder of their own, under names a
		# model's own files could have; only the top level is the model's.
		if name.contains("/") or name.contains("\\"):
			continue
		out[name.to_lower()] = {"at": data, "packed": packed, "size": size,
			"method": method, "crc": crc, "encrypted": flags & 0x01 != 0,
			# What the cipher's twelfth byte must be: the CRC's top byte,
			# or the time's when the sizes and CRC follow the data.
			"check": (time >> 8) & 0xFF if flags & 0x08 != 0 else (crc >> 24) & 0xFF}
		if not aes.is_empty():
			out[name.to_lower()]["aes"] = aes
	if out.is_empty():
		return {"error": "that is not a Studio .io file"}
	return out


## WinZip's AES field (0x9901) of a member's extra data: {"version": 1 or
## 2, "strength": 1, 2 or 3 (AES-128, 192, 256), "method": how it is packed
## under the cipher}, or {} for a member not locked that way.
static func _aes_field(extra: PackedByteArray) -> Dictionary:
	var at: int = 0
	while at + 4 <= extra.size():
		var id: int = extra.decode_u16(at)
		var size: int = extra.decode_u16(at + 2)
		if id == 0x9901 and size >= 7 and at + 4 + size <= extra.size():
			return {"version": extra.decode_u16(at + 4), "strength": extra[at + 8],
				"method": extra.decode_u16(at + 9)}
		at += 4 + size
	return {}


static func _unpack(bytes: PackedByteArray, entry: Dictionary,
		password: String = PASSWORD) -> PackedByteArray:
	var data: PackedByteArray = bytes.slice(int(entry["at"]), int(entry["at"]) + int(entry["packed"]))
	var method: int = int(entry["method"])
	# AE-2 states no CRC: what vouches for the data is the cipher's own
	# check, which _aes has made.
	var checked: bool = true
	if entry.has("aes"):
		data = _aes(data, int(entry["aes"]["strength"]), password)
		if data.is_empty():
			return PackedByteArray()
		method = int(entry["aes"]["method"])
		checked = int(entry["aes"]["version"]) == 1
	elif bool(entry["encrypted"]):
		data = _decrypt(data, password)
		# A wrong password is known before anything is inflated.
		if data.size() < 12 or data[11] != int(entry["check"]):
			return PackedByteArray()
		data = data.slice(12)
	match method:
		0:
			return data
		8:
			if checked:
				return _inflate(data, int(entry["crc"]), int(entry["size"]))
			return _inflate_unchecked(data, int(entry["size"]))
	return PackedByteArray()


## WinZip's AES, undone: the salt, two bytes that say whether the password
## is right, the data in AES-CTR (a little-endian counter from 1), and ten
## bytes of HMAC-SHA1 over it, which are checked. The key, the HMAC's key
## and the two bytes are PBKDF2-HMAC-SHA1 of the password, 1,000 rounds.
## Some Studio files are locked this way (an early-access build's, by
## another reader's account); what proves this is libarchive's own AES-256
## test file, opened to the 6,818 bytes it says it holds (io_probe).
static func _aes(data: PackedByteArray, strength: int, password: String) -> PackedByteArray:
	var key_length: int = {1: 16, 3: 32}.get(strength, 0)
	var salt_length: int = key_length / 2
	if key_length == 0 or data.size() < salt_length + 2 + 10:
		return PackedByteArray()
	var salt: PackedByteArray = data.slice(0, salt_length)
	var made: PackedByteArray = _pbkdf2_sha1(password.to_utf8_buffer(), salt, 1000,
		2 * key_length + 2)
	if made.slice(2 * key_length) != data.slice(salt_length, salt_length + 2):
		return PackedByteArray()
	var locked: PackedByteArray = data.slice(salt_length + 2, data.size() - 10)
	var crypto := Crypto.new()
	var sealed: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA1,
		made.slice(key_length, 2 * key_length), locked)
	if sealed.slice(0, 10) != data.slice(data.size() - 10):
		return PackedByteArray()
	# The counter's blocks, enciphered in one go, are the stream the data
	# was mixed with.
	var blocks: int = (locked.size() + 15) / 16
	var counters := PackedByteArray()
	counters.resize(blocks * 16)
	for n: int in blocks:
		counters.encode_u64(n * 16, n + 1)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_ECB_ENCRYPT, made.slice(0, key_length)) != OK:
		return PackedByteArray()
	var stream: PackedByteArray = aes.update(counters)
	aes.finish()
	var plain := PackedByteArray()
	plain.resize(locked.size())
	var whole: int = locked.size() / 8 * 8
	for n: int in range(0, whole, 8):
		plain.encode_s64(n, locked.decode_s64(n) ^ stream.decode_s64(n))
	for n: int in range(whole, locked.size()):
		plain[n] = locked[n] ^ stream[n]
	return plain


static func _pbkdf2_sha1(password: PackedByteArray, salt: PackedByteArray, rounds: int,
		length: int) -> PackedByteArray:
	var crypto := Crypto.new()
	var out := PackedByteArray()
	var block: int = 1
	while out.size() < length:
		var first: PackedByteArray = salt.duplicate()
		first.append_array(PackedByteArray([(block >> 24) & 0xFF, (block >> 16) & 0xFF,
			(block >> 8) & 0xFF, block & 0xFF]))
		var u: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA1, password, first)
		var t: PackedByteArray = u.duplicate()
		for _round: int in rounds - 1:
			u = crypto.hmac_digest(HashingContext.HASH_SHA1, password, u)
			for n: int in t.size():
				t[n] ^= u[n]
		out.append_array(t)
		block += 1
	return out.slice(0, length)


## PKWARE's traditional encryption, undone.
static func _decrypt(data: PackedByteArray, password: String = PASSWORD) -> PackedByteArray:
	var keys: Array[int] = [305419896, 591751049, 878082192]
	for c: int in password.to_utf8_buffer():
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
## states — which the inflater then checks the data against.
static func _inflate(raw: PackedByteArray, crc: int, size: int) -> PackedByteArray:
	var wrapped := PackedByteArray([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff])
	wrapped.append_array(raw)
	var tail := PackedByteArray()
	tail.resize(8)
	tail.encode_u32(0, crc)
	tail.encode_u32(4, size)
	wrapped.append_array(tail)
	return wrapped.decompress(size, FileAccess.COMPRESSION_GZIP)


## Raw deflate whose CRC is not known (AE-2 states none), inflated by a
## stream, which hands over what it has inflated without waiting for a
## gzip trailer that would have to state one.
static func _inflate_unchecked(raw: PackedByteArray, size: int) -> PackedByteArray:
	var stream := StreamPeerGZIP.new()
	# Room for all of it: a buffer much smaller than what it inflates to
	# takes nothing in (put_partial_data says 0 sent).
	if stream.start_decompression(false, size + 65536) != OK:
		return PackedByteArray()
	var wrapped := PackedByteArray([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff])
	wrapped.append_array(raw)
	var out := PackedByteArray()
	var at: int = 0
	while at < wrapped.size():
		var sent: Array = stream.put_partial_data(wrapped.slice(at, at + 65536))
		if int(sent[0]) != OK:
			return PackedByteArray()
		at += int(sent[1])
		var waiting: int = stream.get_available_bytes()
		if waiting > 0:
			out.append_array(stream.get_partial_data(waiting)[1])
		if int(sent[1]) == 0 and waiting == 0:
			return PackedByteArray()
	var left: int = stream.get_available_bytes()
	if left > 0:
		out.append_array(stream.get_partial_data(left)[1])
	return out if out.size() == size else PackedByteArray()
