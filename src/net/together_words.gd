## What the other side of a Build together session sends, read at the edge
## (src/net/together.gd): the model's own state besides its parts (the colours
## of hidden parts, the booklet's looks, the steps of sub-assembly copies,
## sections broken out), the files of a part made in the app, each part's
## state, and who is in it.
##
## The model's own state goes as Godot writes a value (var_to_str), and has
## since Together began: every copy of the app, old and new, writes the same
## words for the same model. Godot's own reader of those words (str_to_var)
## builds objects and loads resources by path from them, so the person you
## build with, or anything that can write to the session, could hand this app
## an object where it wants a dictionary. Here they are read by [method read]
## instead, which knows the plain values those words are made of
## (dictionaries, arrays, strings, numbers, true, false and null, vectors,
## transforms, colours and packed arrays) and nothing else: any other name in
## them refuses the whole, and nothing is ever constructed from a name the
## words give. Then each value is made precise, key by key; what is not of
## its kind is left out, with a word in the log.
class_name TogetherWords
extends RefCounted

## Longer words than any the relay keeps for one key (api/together.js).
const MOST := 4_000_000
## How deep a value's dictionaries and arrays may nest.
const DEEPEST := 24
## The plain values written as a name and numbers, and how many numbers each.
const NUMBERS: Dictionary = {"Vector2": 2, "Vector2i": 2, "Vector3": 3, "Vector3i": 3,
	"Vector4": 4, "Color": 4, "Quaternion": 4, "Rect2": 4, "Basis": 9, "Transform3D": 12}
## Packed arrays of numbers, and how many numbers make one element.
const PACKED_NUMBERS: Dictionary = {"PackedInt32Array": 1,
	"PackedInt64Array": 1, "PackedFloat32Array": 1, "PackedFloat64Array": 1,
	"PackedVector2Array": 2, "PackedVector3Array": 3, "PackedColorArray": 4}
## What a typed array or dictionary may be typed as: Godot's plain types.
const TYPES: Array[String] = ["bool", "int", "float", "String", "StringName", "Array",
	"Dictionary", "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Color", "Quaternion",
	"Rect2", "Basis", "Transform3D", "PackedByteArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array", "PackedStringArray", "PackedVector2Array",
	"PackedVector3Array", "PackedColorArray"]
## A part's id as the session gives it (api/together.js UID).
const UID := "^[a-z0-9]{1,16}\\.[0-9]{1,9}$"
## A person's id in the session (api/together.js WHO).
const WHO := "^[0-9a-f]{8}$"
## A part made in the app, by its id: the library's own form, lowercase, as
## the relay lets one through (api/together.js MADE_PART), no "..".
const MADE_ID := "^[a-z0-9][a-z0-9_.-]{0,79}$"
## The files that come with it: an LDraw file it is drawn from, by the name it
## is referred to by (in one folder at most, "s\\3001s01.dat"), and its
## print's pictures.
const MADE_SOURCE := "^(?:[A-Za-z0-9_-]{1,16}[/\\\\])?[A-Za-z0-9][A-Za-z0-9 _.()#+-]{0,99}\\.dat$"
const MADE_PICTURE := "^[A-Za-z0-9][A-Za-z0-9 _.()#+-]{0,99}\\.png$"
const MADE_TEXT_MOST := 1_000_000
const PNG_HEAD: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
## The most of anything a dictionary or array of the model's state is
## expected to hold, past which the rest is left out.
const ENTRIES_MOST := 50_000
## A number of the model's space, LDU: further than any model goes.
const FARTHEST := 1e7

var _words: String = ""
var _at: int = 0
var _why: String = ""


# -- reading the words ----------------------------------------------------------

## [param words] read as plain values: [true, the value] or [false, why not].
static func read(words: String) -> Array:
	if words.length() > MOST:
		return [false, "%d characters, more than any is" % words.length()]
	var reader := TogetherWords.new()
	reader._words = words
	var value: Variant = reader._value(0)
	if reader._why.is_empty():
		reader._space()
		if reader._at < words.length():
			reader._refuse("more after the value")
	if not reader._why.is_empty():
		return [false, reader._why]
	return [true, value]


## The dictionary [param words] are, or {}: for none ("" is a value taken
## back), and for words that are not plain values or not a dictionary, which
## are said in the log as the other side's [param what].
static func dictionary(words: String, what: String) -> Dictionary:
	if words.is_empty():
		return {}
	var got: Array = read(words)
	if not bool(got[0]):
		left_out(what, str(got[1]))
		return {}
	if not got[1] is Dictionary:
		left_out(what, "not a dictionary")
		return {}
	return got[1]


## Said in the log: the other side's [param what] was left out, and why.
static func left_out(what: String, why: String) -> void:
	var line: String = "Build together: left out the other side's %s: %s" % [what,
		why.c_escape().left(200)]
	# Once each: the same words are put again every few seconds (Together._heal).
	if _said.has(line):
		return
	if _said.size() >= 64:
		_said.clear()
	_said[line] = true
	push_warning(line)


static var _said: Dictionary = {}


## [method left_out] for each of [param dropped], in one line; nothing for none.
static func left_out_each(what: String, dropped: PackedStringArray) -> void:
	if dropped.is_empty():
		return
	left_out(what, ", ".join(dropped.slice(0, 6)) + (" and %d more" % (dropped.size() - 6)
		if dropped.size() > 6 else ""))


func _refuse(why: String) -> Variant:
	if _why.is_empty():
		_why = "%s at %d" % [why, _at]
	return null


func _space() -> void:
	while _at < _words.length():
		var c: int = _words.unicode_at(_at)
		if c != 32 and c != 9 and c != 10 and c != 13:
			return
		_at += 1


func _peek() -> String:
	_space()
	return _words[_at] if _at < _words.length() else ""


func _expect(what: String) -> bool:
	if _peek() != what:
		_refuse("%s expected" % what)
		return false
	_at += 1
	return true


func _value(depth: int) -> Variant:
	if depth > DEEPEST:
		return _refuse("nested deeper than %d" % DEEPEST)
	var c: String = _peek()
	if c.is_empty():
		return _refuse("the words end early")
	if c == "{":
		return _dictionary(depth)
	if c == "[":
		return _array(depth)
	if c == "\"":
		return _string()
	if c == "&":
		# A StringName, read as the words it names.
		_at += 1
		return _string() if _peek() == "\"" else _refuse("& without a string")
	if c == "-" or (c >= "0" and c <= "9"):
		return _number()
	var name: String = _name()
	match name:
		"true":
			return true
		"false":
			return false
		"null":
			return null
		"inf":
			return INF
		"inf_neg":
			return -INF
		"nan":
			return NAN
		"Array":
			return _typed_array(depth)
		"Dictionary":
			return _typed_dictionary(depth)
		"PackedStringArray":
			return _strings()
		"PackedByteArray":
			return _bytes()
	if NUMBERS.has(name):
		return _numbered(name)
	if PACKED_NUMBERS.has(name):
		return _packed(name)
	return _refuse("%s is not a plain value" % (name if not name.is_empty() else c).left(40))


func _name() -> String:
	var from: int = _at
	while _at < _words.length():
		var c: int = _words.unicode_at(_at)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
				or (_at > from and c >= 48 and c <= 57)):
			break
		_at += 1
	return _words.substr(from, _at - from)


func _dictionary(depth: int) -> Variant:
	_at += 1
	var out: Dictionary = {}
	if _peek() == "}":
		_at += 1
		return out
	while _why.is_empty():
		var key: Variant = _value(depth + 1)
		if not _why.is_empty() or not _expect(":"):
			return null
		if key is Dictionary or key is Array:
			return _refuse("a dictionary keyed by a dictionary or an array")
		var value: Variant = _value(depth + 1)
		if not _why.is_empty():
			return null
		out[key] = value
		if out.size() > ENTRIES_MOST:
			return _refuse("more than %d entries" % ENTRIES_MOST)
		var next: String = _peek()
		_at += 1
		if next == "}":
			return out
		if next != ",":
			return _refuse(", or } expected")
	return null


func _array(depth: int) -> Variant:
	_at += 1
	var out: Array = []
	if _peek() == "]":
		_at += 1
		return out
	while _why.is_empty():
		var value: Variant = _value(depth + 1)
		if not _why.is_empty():
			return null
		out.append(value)
		if out.size() > ENTRIES_MOST:
			return _refuse("more than %d entries" % ENTRIES_MOST)
		var next: String = _peek()
		_at += 1
		if next == "]":
			return out
		if next != ",":
			return _refuse(", or ] expected")
	return null


## Array[int]([1, 2]): an array of one of Godot's plain types, read as an
## array. Typed by a class's name (a resource's, a node's) is not plain.
func _typed_array(depth: int) -> Variant:
	if not _expect("["):
		return null
	_space()
	var type: String = _name()
	if not type in TYPES:
		return _refuse("an array of %s" % type.left(40))
	if not _expect("]") or not _expect("("):
		return null
	if _peek() != "[":
		return _refuse("[ expected")
	var out: Variant = _array(depth)
	return out if _expect(")") else null


func _typed_dictionary(depth: int) -> Variant:
	if not _expect("["):
		return null
	_space()
	var key_type: String = _name()
	if not _expect(","):
		return null
	_space()
	var value_type: String = _name()
	if not key_type in TYPES or not value_type in TYPES:
		return _refuse("a dictionary of %s and %s" % [key_type.left(40), value_type.left(40)])
	if not _expect("]") or not _expect("("):
		return null
	if _peek() != "{":
		return _refuse("{ expected")
	var out: Variant = _dictionary(depth)
	return out if _expect(")") else null


func _string() -> Variant:
	var from: int = _at + 1
	var end: int = from
	while true:
		end = _words.find("\"", end)
		if end < 0:
			return _refuse("a string that never ends")
		var slashes: int = 0
		while end - 1 - slashes >= from and _words.unicode_at(end - 1 - slashes) == 92:
			slashes += 1
		if slashes % 2 == 0:
			break
		end += 1
	var raw: String = _words.substr(from, end - from)
	_at = end + 1
	return raw if not raw.contains("\\") else _unescaped(raw)


## [param raw] with Godot's escapes read as its reader reads them: \n, \t,
## \r, \b, \f, \uXXXX, \UXXXXXX, and any other character as itself.
func _unescaped(raw: String) -> Variant:
	var out: String = ""
	var at: int = 0
	while at < raw.length():
		var slash: int = raw.find("\\", at)
		if slash < 0 or slash == raw.length() - 1:
			out += raw.substr(at)
			break
		out += raw.substr(at, slash - at)
		var what: String = raw[slash + 1]
		at = slash + 2
		match what:
			"n":
				out += "\n"
			"t":
				out += "\t"
			"r":
				out += "\r"
			"b":
				out += char(8)
			"f":
				out += char(12)
			"u", "U":
				var digits: int = 4 if what == "u" else 6
				var hex: String = raw.substr(at, digits)
				if hex.length() != digits or not hex.is_valid_hex_number():
					return _refuse("\\%s without its digits" % what)
				var code: int = hex.hex_to_int()
				at += digits
				# A pair of UTF-16 halves is one character.
				if code >= 0xD800 and code <= 0xDBFF and raw.substr(at, 2) == "\\u" \
						and raw.substr(at + 2, 4).is_valid_hex_number():
					var low: int = raw.substr(at + 2, 4).hex_to_int()
					if low >= 0xDC00 and low <= 0xDFFF:
						code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
						at += 6
				if code <= 0 or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
					return _refuse("\\%s that is no character" % what)
				out += char(code)
			_:
				out += what
	return out


static var _number_shape: RegEx = RegEx.create_from_string(
	"\\G-?[0-9]+(\\.[0-9]*)?([eE][+-]?[0-9]+)?")


func _number() -> Variant:
	var found: RegExMatch = _number_shape.search(_words, _at)
	if found == null:
		return _refuse("a number expected")
	var text: String = found.get_string()
	_at += text.length()
	if text.contains(".") or text.contains("e") or text.contains("E"):
		return text.to_float()
	if text.trim_prefix("-").length() > 18:
		return _refuse("a whole number too long")
	return text.to_int()


## The numbers between ( and ): [param count] of them, or any count with
## [param count] 0. Each a number as Godot writes one, inf and nan too.
func _numbers(count: int) -> Variant:
	if not _expect("("):
		return null
	var out: Array = []
	if _peek() == ")":
		_at += 1
	else:
		while _why.is_empty():
			var c: String = _peek()
			var number: Variant
			if c == "-" or (c >= "0" and c <= "9"):
				number = _number()
			else:
				match _name():
					"inf":
						number = INF
					"inf_neg":
						number = -INF
					"nan":
						number = NAN
					_:
						return _refuse("a number expected")
			if not _why.is_empty():
				return null
			out.append(number)
			if out.size() > MOST / 2:
				return _refuse("too many numbers")
			var next: String = _peek()
			_at += 1
			if next == ")":
				break
			if next != ",":
				return _refuse(", or ) expected")
	if count > 0 and out.size() != count:
		return _refuse("%d numbers where %d go" % [out.size(), count])
	return out


func _numbered(name: String) -> Variant:
	var n: Variant = _numbers(int(NUMBERS[name]))
	if n == null:
		return null
	match name:
		"Vector2":
			return Vector2(n[0], n[1])
		"Vector2i":
			return Vector2i(int(n[0]), int(n[1]))
		"Vector3":
			return Vector3(n[0], n[1], n[2])
		"Vector3i":
			return Vector3i(int(n[0]), int(n[1]), int(n[2]))
		"Vector4":
			return Vector4(n[0], n[1], n[2], n[3])
		"Color":
			return Color(n[0], n[1], n[2], n[3])
		"Quaternion":
			return Quaternion(n[0], n[1], n[2], n[3])
		"Rect2":
			return Rect2(n[0], n[1], n[2], n[3])
		"Basis":
			return _basis(n, 0)
		"Transform3D":
			return Transform3D(_basis(n, 0), Vector3(n[9], n[10], n[11]))
	return _refuse(name)


## The basis Godot writes row by row from [param at] in [param n].
static func _basis(n: Array, at: int) -> Basis:
	return Basis(Vector3(n[at], n[at + 3], n[at + 6]), Vector3(n[at + 1], n[at + 4], n[at + 7]),
		Vector3(n[at + 2], n[at + 5], n[at + 8]))


func _packed(name: String) -> Variant:
	var n: Variant = _numbers(0)
	if n == null:
		return null
	var numbers: Array = n
	var each: int = int(PACKED_NUMBERS[name])
	if numbers.size() % each != 0:
		return _refuse("%s of %d numbers" % [name, numbers.size()])
	match name:
		"PackedInt32Array":
			return PackedInt32Array(numbers)
		"PackedInt64Array":
			return PackedInt64Array(numbers)
		"PackedFloat32Array":
			return PackedFloat32Array(numbers)
		"PackedFloat64Array":
			return PackedFloat64Array(numbers)
	var out: Array = []
	for at: int in range(0, numbers.size(), each):
		match each:
			2:
				out.append(Vector2(numbers[at], numbers[at + 1]))
			3:
				out.append(Vector3(numbers[at], numbers[at + 1], numbers[at + 2]))
			4:
				out.append(Color(numbers[at], numbers[at + 1], numbers[at + 2], numbers[at + 3]))
	match name:
		"PackedVector2Array":
			return PackedVector2Array(out)
		"PackedVector3Array":
			return PackedVector3Array(out)
	return PackedColorArray(out)


static var _bytes_shape: RegEx = RegEx.create_from_string("^[0-9,\\s]*$")
static var _over_a_byte: RegEx = RegEx.create_from_string("[0-9]{4,}|2[6-9][0-9]|25[6-9]|[3-9][0-9]{2}")


## A picture's bytes, tens of thousands of them: read whole rather than a
## number at a time, which took a quarter of a second for one print.
func _bytes() -> Variant:
	if not _expect("("):
		return null
	var end: int = _words.find(")", _at)
	if end < 0:
		return _refuse("bytes that never end")
	var inside: String = _words.substr(_at, end - _at)
	if _bytes_shape.search(inside) == null or _over_a_byte.search(inside) != null:
		return _refuse("a byte that is not one")
	_at = end + 1
	return PackedByteArray(Array(inside.split_floats(",", false)))


func _strings() -> Variant:
	if not _expect("("):
		return null
	var out := PackedStringArray()
	if _peek() == ")":
		_at += 1
		return out
	while _why.is_empty():
		if _peek() != "\"":
			return _refuse("a string expected")
		var one: Variant = _string()
		if not _why.is_empty():
			return null
		out.append(one)
		var next: String = _peek()
		_at += 1
		if next == ")":
			return out
		if next != ",":
			return _refuse(", or ) expected")
	return null


# -- each kind of the model's state, made precise -------------------------------

## The steps of sub-assembly copies: {path: step}.
static func unit_steps(raw: Dictionary, dropped: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for path: Variant in raw:
		if path is String and (path as String).length() <= 400 and raw[path] is int:
			out[path] = raw[path]
		else:
			dropped.append("the step of %s" % str(path).left(40))
	return out


## Sections broken out: {path: {"offset": Vector3, "home": {uid: Transform3D},
## "touching": {number: true}}}, each as Sections.break_out keeps one, its
## parts by uid (Together._broken_words).
static func broken(raw: Dictionary, dropped: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for section: Variant in raw:
		var given: Variant = raw[section]
		if not section is String or (section as String).length() > 400 or not given is Dictionary \
				or not _place(given.get("offset")):
			dropped.append("section %s" % str(section).left(40))
			continue
		var record: Dictionary = {"offset": given["offset"]}
		if given.has("home"):
			var home: Dictionary = {}
			for uid: Variant in (given["home"] if given["home"] is Dictionary else {}):
				var at: Variant = given["home"][uid]
				if uid is String and (uid as String).length() <= 32 and at is Transform3D \
						and _place((at as Transform3D).origin) and (at as Transform3D).basis.x.is_finite() \
						and (at as Transform3D).basis.y.is_finite() and (at as Transform3D).basis.z.is_finite():
					home[uid] = at
				else:
					dropped.append("a part of section %s" % str(section).left(40))
			record["home"] = home
		if given.has("touching"):
			var touching: Dictionary = {}
			for id: Variant in (given["touching"] if given["touching"] is Dictionary else {}):
				if id is int:
					touching[id] = true
			record["touching"] = touching
		out[section] = record
	return out


static func _place(at: Variant) -> bool:
	return at is Vector3 and (at as Vector3).is_finite() and (at as Vector3).length() < FARTHEST


## The files of the part made in the app [param id] another side sent: its
## own LDraw file "<id>.dat", the files it is drawn from by the name each is
## referred to by, and its print's pictures as PNG bytes. {} when its id is
## not a part's or its own file is missing; any other file not of its kind
## is left out. None is ever a path here: the part is built from them in
## memory (CustomParts.add, kept nowhere).
static func made_part(id: String, raw: Dictionary, dropped: PackedStringArray) -> Dictionary:
	if RegEx.create_from_string(MADE_ID).search(id) == null or id.contains(".."):
		dropped.append("a made part's id")
		return {}
	var source := RegEx.create_from_string(MADE_SOURCE)
	var picture := RegEx.create_from_string(MADE_PICTURE)
	var out: Dictionary = {}
	for name: Variant in raw:
		var file: Variant = raw[name]
		if not name is String or (name as String).contains(".."):
			dropped.append("a file of %s" % id)
		elif source.search(name) != null and file is String \
				and (file as String).length() <= MADE_TEXT_MOST:
			out[name] = file
		elif picture.search(name) != null and file is PackedByteArray \
				and (file as PackedByteArray).slice(0, 8) == PNG_HEAD:
			out[name] = file
		else:
			dropped.append("%s of %s" % [str(name).left(40), id])
	if not out.get(id + ".dat") is String:
		dropped.append("%s's own file" % id)
		return {}
	return out


## A part's id as a state gives it: a name of the library's, no path.
static func part_named(id: Variant) -> bool:
	return id is String and not (id as String).is_empty() and (id as String).length() <= 64 \
		and id == (id as String).get_file() and not (id as String).contains("..") \
		and _control.search(id) == null


static var _control: RegEx = RegEx.create_from_string("[\\x00-\\x1f\\x7f]")


## Whether [param uid] is a part's id as the session gives one.
static func uid(given: Variant) -> bool:
	return given is String and _uid_shape.search(given) != null


static var _uid_shape: RegEx = RegEx.create_from_string(UID)


## A number as a JSON answer gives one: finite, within [param most].
static func number(given: Variant, most: float = FARTHEST) -> bool:
	return (given is float or given is int) and is_finite(float(given)) and absf(float(given)) <= most


## Who is in the session as the server said it, each made precise: {who,
## name, owner, me, here, at: [x, y, z] or null, sel: [uid], view: {yaw,
## pitch, distance, size, focus: [x, y, z], frame} or null}. One that is not
## a person is left out.
static func people(raw: Variant) -> Array:
	var out: Array = []
	var who_shape := RegEx.create_from_string(WHO)
	for item: Variant in (raw if raw is Array else []):
		if not item is Dictionary or not (item as Dictionary).get("who") is String \
				or who_shape.search((item as Dictionary)["who"]) == null or out.size() >= 64:
			continue
		var given: Dictionary = item
		var at: Variant = given.get("at")
		var sel: Array = []
		for one: Variant in (given.get("sel") if given.get("sel") is Array else []):
			if uid(one) and sel.size() < 500:
				sel.append(one)
		out.append({"who": given["who"], "name": str(given.get("name", "")).left(80),
			"owner": given.get("owner") == true, "me": given.get("me") == true,
			"here": given.get("here") == true,
			"at": [float(at[0]), float(at[1]), float(at[2])] if numbers(at, 3) else null,
			"sel": sel, "view": _view(given.get("view"))})
	return out


## [param given] when it is an array of [param count] numbers.
static func numbers(given: Variant, count: int) -> bool:
	return given is Array and (given as Array).size() == count and (given as Array).all(
		func(one: Variant) -> bool: return number(one))


static func _view(given: Variant) -> Variant:
	if not given is Dictionary:
		return null
	var view: Dictionary = given
	for key: String in ["yaw", "pitch", "distance", "size"]:
		if not number(view.get(key)):
			return null
	if not numbers(view.get("focus"), 3):
		return null
	var out: Dictionary = {"yaw": float(view["yaw"]), "pitch": float(view["pitch"]),
		"distance": float(view["distance"]), "size": float(view["size"]),
		"focus": (view["focus"] as Array).map(func(one: Variant) -> float: return float(one))}
	if numbers(view.get("frame"), 4):
		out["frame"] = (view["frame"] as Array).map(func(one: Variant) -> float: return float(one))
	return out
