## Parts found the way a builder asks for them (PartLibrary.search).
##
## Every word used to have to be in a part's name or keywords, as text
## anywhere in them. So one word the catalogue does not use hid the part a
## builder meant: "tile 2x2 macaroni curved" said No parts match, where
## "tile 2 x 2 corner round" finds 27925, and BrickBench's m147 designs built
## a potato of plates 1 x 1 and a balloon dog of round bricks, told the
## curved parts did not exist (docs/BRICKBENCH.md, 2026-10-22). And "4" was
## found in "LegoID 6410654", "one" in "Cone", so prints led.
##
## Now a part is ranked by how many of the words asked it has, and then by
## what they are worth: a word counts for more the fewer parts have it, so an
## extra word lowers a part and never hides it. Plain parts come before their
## prints. Words match whole, with their plurals; a size is the part's own
## (its name's first "N x M"); a builder's words for a shape (macaroni,
## quarter, dome bottom, spiky) are read as the catalogue's as well as their
## own; and the words set inventories name a part by are read beside its
## name (PartInfo.also_called).
##
## And then by how much real sets use it (PartInfo.commonness), within the
## parts that answer equally well: "door frame" led with 80400a, a 2 x 8 x 6
## frame in 24 sets, for its name beginning with the words, over 60596, the
## 1 x 4 x 6 in 850 (walk239 A13, 2026-10-24). A word as it is being typed is
## the start of the part's ("doo"), one a letter off is the word it misses
## ("tyle", "hindge", "axel"), and two run together are both ("doorframe"):
## each answers a little less than the word itself.
##
## And in the names builders use, which are BrickLink's and Rebrickable's
## more than LDraw's (names248, 2026-10-24): "liftarm 5" missed 32316, LDraw's
## Technic Beam 5 and BrickLink's Liftarm Thick 1 x 5. A word of theirs for
## LDraw's (SAME_WORD), Rebrickable's words and size for a part (also_called,
## also_size) and a length or a gear's teeth as builders write them (3L, 24t)
## are the part's own name, matched as fully as LDraw's: two names for one
## part, and how much sets use it decides between the parts either answers.
## In the bin, where every word must be there, the words a name puts in
## brackets and its "Modified" tell versions apart and are not required:
## "Technic, Gear 24 Tooth (2nd Version - 1 Axle Hole)" is 3648b.
class_name PartSearch
extends RefCounted

## A builder's word or phrase -> the catalogue's words for the same shape,
## each a phrase every word of which a part must have. The builder's own
## words count too: 27925 says macaroni in its keywords.
const SAME_SHAPE: Dictionary = {
	# A corner round, a quarter circle: what sets call macaroni. LDraw files
	# them "Corner Round", or "Round Corner" on a plate.
	"macaroni": ["corner round", "round corner"],
	"quarter": ["corner round", "round corner", "quarter circle"],
	"quarter circle": ["corner round", "round corner"],
	"quarter round": ["corner round", "round corner", "quarter circle"],
	"round corner": ["corner round", "rounded corner"],
	"rounded corner": ["corner round", "round corner"],
	"rounded corners": ["corner round", "round corner"],
	# A half circle is a rounded end: 24246, Tile 1 x 1 with Rounded End.
	"half circle": ["rounded end", "half round", "round end"],
	"half round": ["rounded end", "half circle", "round end"],
	"rounded end": ["round end", "half round"],
	"rounded ends": ["round ends", "half round"],
	# What a dome under a body is called: inverted. 24947, the ovoid every
	# segment of BrickAgent's balloon dog tapers on, is Dome 2 x 2 Inverted.
	"dome bottom": ["dome inverted", "hemisphere bottom"],
	"bottom dome": ["dome inverted", "hemisphere bottom"],
	"inverted dome": ["dome bottom", "hemisphere bottom"],
	"bottom": ["inverted"],
	"underside": ["inverted", "bottom"],
	"upside down": ["inverted"],
	"egg": ["ovoid"],
	"oval": ["ovoid"],
	"dome": ["hemisphere", "domed"],
	"hemisphere": ["dome"],
	"bowl": ["dish"],
	# Spiky hair and spines are pyramids: 22388, Slope 1 x 1 x 0.667
	# Quadruple, which BrickAgent's boy wears seventeen of. Asked for as
	# hair, a figure's hair is as likely as a minifigure's.
	"spiky hair": ["hair spiked", "quadruple"],
	"spiked hair": ["hair spiky", "quadruple"],
	"hair spikes": ["hair spiky", "hair spiked", "quadruple"],
	"spiky": ["quadruple", "spike", "spiked"],
	"spikey": ["spiky", "quadruple", "spike", "spiked"],
	"spikes": ["quadruple", "spiky", "spiked"],
	"pyramid": ["quadruple"],
	"pointy": ["quadruple", "spike", "cone"],
	"curvy": ["curved"],
	"curve": ["curved"],
	"circular": ["round"],
	"circle": ["round"],
	"no studs": ["without studs", "smooth"],
	"without studs": ["no studs", "smooth"],
	"studless": ["without studs", "smooth"],
	"teeth": ["tooth"],
	"moustache": ["mustache"],
	"mustache": ["moustache"],
}

## A word of BrickLink's or a builder's -> LDraw's or Rebrickable's for the
## same thing, matched as fully as the word itself (SAME_SHAPE's count a
## little less): one part with two names. BrickLink's liftarm is LDraw's and
## Rebrickable's beam, its Modified Rebrickable's Special, its connector
## LDraw's joiner; a 3L pin is LDraw's Pin Long and a half bush its Bush 1/2.
const SAME_WORD: Dictionary = {
	"liftarm": ["beam"], "liftarms": ["beam"], "lift arm": ["liftarm", "beam"],
	"lift arms": ["liftarm", "beam"],
	"modified": ["special"], "special": ["modified"],
	"connector": ["joiner"], "connectors": ["joiner"], "joiner": ["connector"],
	"bushing": ["bush"], "bushings": ["bush"],
	"half bush": ["bush 1/2"], "half bushing": ["bush 1/2"], "half pin": ["pin 1/2"],
	"3l pin": ["pin long"], "pin 3l": ["pin long"], "3l pins": ["pin long"],
}
## Words that tell a part's versions apart, which rank it and which the bin,
## where every word must be there, does not require: BrickLink's "Plate,
## Modified" is a plate with something on it, and its "Liftarm, Modified
## Bent" a beam LDraw names Bent.
const QUALIFIERS: Dictionary = {"modified": true, "special": true}

## Words that say nothing about which part.
const STOP_WORDS: Dictionary = {"with": true, "and": true, "or": true, "on": true, "of": true,
	"the": true, "a": true, "an": true, "for": true, "in": true, "to": true, "x": true,
	"piece": true, "pieces": true, "part": true, "parts": true, "lego": true, "shaped": true,
	"shape": true, "like": true, "at": true, "by": true, "its": true, "that": true}
## Colour words, which say what a part is placed in rather than which part.
const COLOUR_WORDS: Dictionary = {"white": true, "black": true, "red": true, "blue": true,
	"yellow": true, "green": true, "grey": true, "gray": true, "brown": true, "tan": true,
	"orange": true, "pink": true, "purple": true, "lime": true, "trans": true,
	"transparent": true, "clear": true, "dark": true, "bluish": true, "reddish": true,
	"sand": true, "medium": true, "bright": true, "nougat": true, "azure": true,
	"lavender": true, "magenta": true, "olive": true, "metallic": true, "pearl": true,
	"silver": true, "gold": true, "chrome": true, "neon": true, "glitter": true,
	"coral": true, "teal": true, "turquoise": true, "beige": true, "violet": true}
## A number said in words, and as the catalogue writes it.
const NUMBER_WORDS: Dictionary = {"one": "1", "two": "2", "three": "3", "four": "4",
	"five": "5", "six": "6", "eight": "8", "1": "one", "2": "two", "3": "three", "4": "four"}
## Phrases that ask for a part with no studs, which most names do not say:
## 11477, the curved slope 2 x 1 sets call "No Studs", is Slope Brick
## Curved 2 x 1. Its own geometry says it.
const STUDLESS: Array[String] = ["no studs", "without studs", "studless"]
## A word found only in a part's keywords counts for this much of one in its name.
const KEYWORD_SHARE := 0.5
## The catalogue's words for a builder's count for this much of the builder's own.
const OTHER_WORDS_SHARE := 0.8
## A word a part's has only the start of, as one being typed: "doo" in Door.
const PREFIX_SHARE := 0.85
## A word one letter off a word the catalogue has, which it is taken for:
## "tyle" a tile, "hindge" a hinge, "axel" an axle. Only a word no part has.
const FUZZY_SHARE := 0.6
## How much each set a part is in, and each piece, counts towards how much it
## is used (PartInfo.commonness), as a whole number in a sort key.
const USAGE_SCALE := 150.0

static var SIZE := RegEx.create_from_string(
	"(\\d+(?:\\.\\d+)?) x (\\d+(?:\\.\\d+)?)(?: x (\\d+(?:\\.\\d+)?))?")
static var MIXED := RegEx.create_from_string("(\\d+) (\\d+)/(\\d+)")
static var FRACTION := RegEx.create_from_string("(\\d+)/(\\d+)")
## Letters of any script are a word's: "Å" on 3005pwc, 忍者 in 57895p01's keywords.
static var NOT_A_WORD := RegEx.create_from_string("[^\\p{L}\\p{N}. ]+")
## A part number, or the start of one: 3001, 3023b, 30367.
static var PART_NUMBER := RegEx.create_from_string("^\\d{3,}[a-z0-9]*$")
## A Technic length as builders write it, 3L, which LDraw writes 3; and a
## gear's teeth, 24t or z24, which it writes 24 Tooth.
static var LENGTH := RegEx.create_from_string("^(\\d+)l$")
static var TEETH := RegEx.create_from_string("^(?:(\\d+)t|z(\\d+))$")
## What a name puts in brackets: "(2nd Version - 1 Axle Hole)", "[Slotted]".
static var BRACKETED := RegEx.create_from_string("[(\\[][^)\\]]*[)\\]]?")

var _infos: Array[PartLibrary.PartInfo] = []
var _at: Dictionary = {}        ## part number -> its index in _infos
## word -> indexes into _infos of the parts whose name, number and category
## have it; the same for the words sets name it by, and for keywords; a
## footprint, smaller side first ("1x4") -> the parts of that size; and the
## same with a height ("1x2x2") -> the parts that say one.
var _named: Dictionary = {}
var _also: Dictionary = {}
var _keyed: Dictionary = {}
var _sized: Dictionary = {}
var _tall: Dictionary = {}
## Each index's words in order, for the words a typed start begins.
var _named_words := PackedStringArray()
var _also_words := PackedStringArray()
var _keyed_words := PackedStringArray()
## Per part: how much real sets use it, and how plain its name is (fewer
## words), each as a sort key's whole number.
var _usage := PackedInt32Array()
var _plainness := PackedInt32Array()
## Per part: 1 for a plain part, not a print, a sticker, an alias or another
## system's; and the index of the part it is a print of, or -1.
var _plain := PackedByteArray()
var _print_of := PackedInt32Array()
## Per part: the first word of its category, what kind of part it is: a
## name says what it has, and "Technic Wedge Belt Wheel" is filed a Technic
## part, where Wedge 4 x 2 is a wedge.
var _lead := PackedStringArray()
## The families that are a height, and how tall each is in plates, its body
## without a stud: what "wedge brick" or "round plate" asks of a part filed in
## another family. A tile is a plate with nothing on top.
const HEIGHTS: Dictionary = {"brick": 3, "plate": 1, "tile": 1}
## A height word -> the parts of another family that are that tall.
var _by_height: Dictionary = {}
## A first letter -> the parts with a word of their names that it begins.
var _by_letter: Dictionary = {}
## Every part's number in lower case, in order, and the part each is.
var _numbers := PackedStringArray()
var _number_at := PackedInt32Array()


func _init(parts: Dictionary, ids: PackedStringArray) -> void:
	for id: String in ids:
		var info: PartLibrary.PartInfo = parts[id]
		if info.is_redirect():
			continue
		var at: int = _infos.size()
		_infos.append(info)
		_at[info.id] = at
		# The number and the category say no size, so the name's is the first.
		# Read, never written: the index may be made on a thread of its own
		# (PartLibrary.prepare_search), so the parts' kept words are not
		# filled in from here.
		var own: PackedStringArray = words_of(info.own_words_now())
		_index(_named, own, at)
		if not info.also_called.is_empty():
			_index(_also, words_of(info.also_called), at)
		if not info.keywords.is_empty():
			_index(_keyed, words_of(info.keyword_words_now()), at)
		var size: PackedStringArray = _size_key(own)
		if not size.is_empty():
			_index(_sized, PackedStringArray([size[0]]), at)
			if size.size() > 1:
				_index(_tall, PackedStringArray([size[1]]), at)
		# And the size Rebrickable names it by where LDraw's name gives none
		# or another, as fully: 32316, Technic Beam 5, is a 1 x 5 there.
		var theirs: PackedStringArray = _size_key(words_of(info.also_size))
		if not theirs.is_empty():
			_index(_sized, PackedStringArray([theirs[0]]), at)
			if theirs.size() > 1:
				_index(_tall, PackedStringArray([theirs[1]]), at)
		_usage.append(mini(4095, roundi(info.commonness() * USAGE_SCALE)))
		_plainness.append(15 - mini(15, own.size()))
		var kind: PackedStringArray = words_of(info.family_category())
		_lead.append(kind[0] if not kind.is_empty() else "")
		# What BrickLink files as a brick, plate or tile Modified (Rebrickable,
		# Special): one with something on it, LDraw's "with", and not a round
		# one, nor a tile with only the groove every tile has. 15573, the
		# jumper, for "plate modified"; 4070, the headlight brick, for "brick
		# modified".
		if not kind.is_empty() and HEIGHTS.has(kind[0]) \
				and PartLibrary.decor_of(info.name, info.category) == 0:
			var named: String = info.name.to_lower().replace("with groove", "")
			if named.contains(" with ") and not named.contains("round"):
				_index(_also, PackedStringArray(["modified", "special"]), at)
		# Brick, plate and tile are each a family and a height. A part of
		# another family is the height it is: 6564, Wedge 3 x 2 Right, is a
		# wedge brick; 45677, Wedge 4 x 4 x 0.667 Curved, is not.
		if not kind.is_empty() and not HEIGHTS.has(kind[0]):
			var plates: int = roundi((info.size.y - (4.0 if info.stud_count > 0 else 0.0)) / 8.0)
			for word: String in HEIGHTS:
				if plates == int(HEIGHTS[word]) and (word == "tile") == (info.stud_count == 0):
					if not _by_height.has(word):
						_by_height[word] = PackedInt32Array()
					var tall: PackedInt32Array = _by_height[word]
					tall.append(at)
					_by_height[word] = tall
		_plain.append(1 if PartLibrary.decor_of(info.name, info.category) == 0
			and not info.name.begins_with("=") and not _other_line(info) else 0)
	_named_words = _in_order(_named)
	_also_words = _in_order(_also)
	_keyed_words = _in_order(_keyed)
	# The parts with a word of their names begun by each first letter: what
	# a first key typed asks, and the start of thousands of words.
	var seen := PackedInt32Array()
	seen.resize(_infos.size())
	for word: String in _named_words:
		if word.is_valid_float():
			continue
		var letter: String = word[0]
		if not _by_letter.has(letter):
			_by_letter[letter] = PackedInt32Array()
		var into: PackedInt32Array = _by_letter[letter]
		var mark: int = letter.unicode_at(0) + 1
		for at: int in _named[word]:
			if seen[at] != mark:
				seen[at] = mark
				into.append(at)
		_by_letter[letter] = into
	_print_of.resize(_infos.size())
	var numbers := PackedStringArray()
	for at: int in _infos.size():
		_print_of[at] = int(_at.get(_infos[at].print_of, -1))
		numbers.append("%s %d" % [_infos[at].id.to_lower(), at])
	numbers.sort()
	for entry: String in numbers:
		_numbers.append(entry.get_slice(" ", 0))
		_number_at.append(int(entry.get_slice(" ", 1)))


static func _in_order(index: Dictionary) -> PackedStringArray:
	var words := PackedStringArray(index.keys())
	words.sort()
	return words


func _words_of_index(index: Dictionary) -> PackedStringArray:
	if is_same(index, _named):
		return _named_words
	if is_same(index, _also):
		return _also_words
	return _keyed_words


## A part under each of its words. A word twice in a name is listed twice,
## which no lookup minds; the words no query keeps (STOP_WORDS) are not.
static func _index(into: Dictionary, words: PackedStringArray, at: int) -> void:
	for word: String in words:
		if STOP_WORDS.has(word):
			continue
		var parts: Variant = into.get(word)
		if parts == null:
			parts = []
			into[word] = parts
		(parts as Array).append(at)


## The words of a name or a query: lower case, punctuation a space, a full
## stop kept inside a number (0.667) and dropped at the end of a word.
static func words_of(text: String) -> PackedStringArray:
	text = text.to_lower()
	# "Technic Pin 1/2" is asked for as 1/2 and found as 0.5, which is how
	# the query is read; LDraw writes most heights 0.667, a few 2/3.
	if text.contains("/"):
		text = _decimals(text)
	var words: PackedStringArray = NOT_A_WORD.sub(text, " ", true).split(" ", false)
	if text.contains(". ") or text.ends_with("."):
		for n: int in words.size():
			if words[n].ends_with("."):
				words[n] = words[n].trim_suffix(".")
	return words


## The first "N x M" of a name's words, the smaller side first, and with
## its height if it gives one ("1x2", "1x2x2"), or nothing.
static func _size_key(words: PackedStringArray) -> PackedStringArray:
	for n: int in range(1, words.size() - 1):
		if words[n] == "x" and words[n - 1].is_valid_float() and words[n + 1].is_valid_float():
			var key: String = _sides(words[n - 1], words[n + 1])
			if n + 3 < words.size() and words[n + 2] == "x" and words[n + 3].is_valid_float():
				return PackedStringArray([key, "%sx%s" % [key, _number(words[n + 3])]])
			return PackedStringArray([key])
	return PackedStringArray()


static func _sides(a: String, b: String) -> String:
	var low: String = a if a.to_float() <= b.to_float() else b
	var high: String = b if low == a else a
	return "%sx%s" % [_number(low), _number(high)]


## 2.0 and 2 are one size, 0.667 and .667 one height.
static func _number(text: String) -> String:
	var value: float = text.to_float()
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.3f" % value


## A fraction as LDraw writes it: 2/3 -> 0.667, 1 1/3 -> 1.333.
static func _decimals(text: String) -> String:
	for found: RegExMatch in MIXED.search_all(text):
		var value: float = found.get_string(1).to_float() \
			+ found.get_string(2).to_float() / maxf(1.0, found.get_string(3).to_float())
		text = text.replace(found.get_string(), _number(str(value)))
	for found: RegExMatch in FRACTION.search_all(text):
		var value: float = found.get_string(1).to_float() / maxf(1.0, found.get_string(2).to_float())
		text = text.replace(found.get_string(), _number(str(value)))
	return text


## What a query asks for: its sizes, as one term any of which will do, and
## each other word or phrase, with the catalogue's words for it.
##
## A term is {"said": the query's words, "options": [PackedStringArray, ...]
## (every word of one option on a part matches it), "full": how many of the
## options are the part's own words (the rest count OTHER_WORDS_SHARE), and
## "optional" for a word that tells versions apart (QUALIFIERS, or one in
## brackets) and that the bin does not require}, or a size's
## {"said": "2 x 4", "sizes": ["2x4", ...], "tall": ["2x4x3"] when a height
## is asked, "options": its numbers, which a wheel's keywords say}.
static func terms_of(asked: String) -> Array[Dictionary]:
	var text: String = " %s " % _decimals(asked.to_lower())
	var terms: Array[Dictionary] = []
	var sizes: PackedStringArray = PackedStringArray()
	var tall: PackedStringArray = PackedStringArray()
	var numbers: Array = []
	var said_sizes: PackedStringArray = PackedStringArray()
	for found: RegExMatch in SIZE.search_all(text):
		var key: String = _sides(found.get_string(1), found.get_string(2))
		if not sizes.has(key):
			sizes.append(key)
			said_sizes.append(found.get_string().strip_edges())
			# A wheel's size in millimetres is in its keywords, "30.4 x 20".
			numbers.append(PackedStringArray([found.get_string(1), found.get_string(2)]))
		if not found.get_string(3).is_empty():
			tall.append("%sx%s" % [key, _number(found.get_string(3))])
		text = text.replace(found.get_string(), " ")
	if not sizes.is_empty():
		terms.append({"said": " or ".join(said_sizes), "sizes": sizes, "tall": tall,
			"options": numbers})

	# What a name puts in brackets tells its versions apart, as do the
	# words of QUALIFIERS: they rank a part, and the bin does not require
	# them. Not a word said outside them too.
	var bracketed: Dictionary = {}
	if text.contains("(") or text.contains("["):
		for found: RegExMatch in BRACKETED.search_all(text):
			for word: String in words_of(found.get_string()):
				bracketed[word] = true
		for word: String in words_of(BRACKETED.sub(text, " ", true)):
			bracketed.erase(word)
	var phrases: Array = (SAME_SHAPE.keys() + SAME_WORD.keys()).filter(func(key: String) -> bool:
		return key.contains(" "))
	phrases.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for phrase: String in phrases:
		if text.contains(" %s " % phrase):
			text = text.replace(" %s " % phrase, " ")
			terms.append(_term(phrase))
	var seen: Dictionary = {}
	var colours: Array[Dictionary] = []
	var decor_asked: bool = text.contains(" print ") or text.contains(" sticker ")
	for word: String in words_of(text):
		if STOP_WORDS.has(word) or seen.has(word):
			continue
		seen[word] = true
		var term: Dictionary = _term(word)
		if bracketed.has(word) or QUALIFIERS.has(word):
			term["optional"] = true
		if COLOUR_WORDS.has(word) and not decor_asked:
			colours.append(term)
		else:
			terms.append(term)
	# A colour is what a part is placed in, not which part: "slope 45 2x2
	# trans clear" is 3039, and a part with Trans Clear in its name is a
	# print or an assembly. Unless it is all that was asked.
	return terms if not terms.is_empty() else colours


static func _term(said: String) -> Dictionary:
	var options: Array = [said.split(" ", false)]
	# In the index's words: 1/2 as LDraw's 1/2 is read, 0.500.
	for other: String in SAME_WORD.get(said, []):
		options.append(words_of(other))
	var length: RegExMatch = LENGTH.search(said)
	if length != null:
		options.append(PackedStringArray([length.get_string(1)]))
	var teeth: RegExMatch = TEETH.search(said)
	if teeth != null:
		options.append(PackedStringArray([teeth.get_string(1) + teeth.get_string(2), "tooth"]))
	var full: int = options.size()
	for other: String in SAME_SHAPE.get(said, []):
		options.append(other.split(" ", false))
	if NUMBER_WORDS.has(said):
		options.append(PackedStringArray([NUMBER_WORDS[said]]))
	return {"said": said, "options": options, "full": full}


## A word and the forms of it a name may use: stud, studs; curve, curved;
## rounded, round.
static func _forms(word: String) -> PackedStringArray:
	var forms := PackedStringArray([word])
	if word.length() < 3 or word.is_valid_float():
		return forms
	if word.ends_with("ies"):
		forms.append(word.trim_suffix("ies") + "y")
	elif word.ends_with("es") and word.length() > 4:
		forms.append_array([word.trim_suffix("es"), word.trim_suffix("s")])
	elif word.ends_with("s") and not word.ends_with("ss"):
		forms.append(word.trim_suffix("s"))
	else:
		forms.append(word + "s")
	if word.ends_with("ed") and word.length() > 4:
		forms.append_array([word.trim_suffix("ed"), word.trim_suffix("d")])
	elif word.ends_with("e"):
		forms.append(word + "d")
	elif not word.ends_with("s") and not word.ends_with("y"):
		forms.append(word + "ed")
	return forms


## The parts that have [param word] in any of its forms, in [param index],
## each -> how fully: 1 for the word itself; and [param loose], for the
## start of a longer word (PREFIX_SHARE) and for a word one letter off it
## when no part has it (FUZZY_SHARE).
func _having(index: Dictionary, word: String, loose: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for form: String in _forms(word):
		for at: int in index.get(form, []):
			out[at] = 1.0
	if not loose or word.is_valid_float():
		return out
	var words: PackedStringArray = _words_of_index(index)
	var n: int = words.bsearch(word)
	while n < words.size() and words[n].begins_with(word):
		for at: int in index[words[n]]:
			if not out.has(at):
				out[at] = PREFIX_SHARE
		n += 1
	if word.length() >= 3 and not named(word):
		for near: String in _near(word):
			for at: int in index.get(near, []):
				if not out.has(at):
					out[at] = FUZZY_SHARE
	return out


## Whether some part has [param word], in any of its forms, by name or by the
## words sets name it by. Keywords are not asked: they hold misspellings of
## their own ("axel"), and a word only they have is one a builder misspelt.
func named(word: String) -> bool:
	for form: String in _forms(word):
		if _named.has(form) or _also.has(form):
			return true
	return false


const LETTERS := "abcdefghijklmnopqrstuvwxyz"


## The words of the catalogue's names one letter off [param word]: a letter
## left out, one too many, one wrong or two swapped. Only words of letters.
func _near(word: String) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	var tries := PackedStringArray()
	for n: int in word.length():
		tries.append(word.substr(0, n) + word.substr(n + 1))
		if n + 1 < word.length():
			tries.append(word.substr(0, n) + word[n + 1] + word[n] + word.substr(n + 2))
		for letter: String in LETTERS:
			tries.append(word.substr(0, n) + letter + word.substr(n + 1))
	for n: int in word.length() + 1:
		for letter: String in LETTERS:
			tries.append(word.substr(0, n) + letter + word.substr(n))
	for near: String in tries:
		if near != word and not seen.has(near) and (_named.has(near) or _also.has(near)):
			seen[near] = true
			out.append(near)
	return out


## A word no part has that is two a part has, run together: "doorframe" is
## door and frame. Each half three letters at the least.
func _apart(word: String) -> Array:
	var out: Array = []
	if word.length() < 6 or word.is_valid_float() or named(word):
		return out
	for n: int in range(3, word.length() - 2):
		var first: String = word.substr(0, n)
		var second: String = word.substr(n)
		if _named.has(first) and _named.has(second):
			out.append(PackedStringArray([first, second]))
	return out


## The parts one term matches in [param index], each -> how fully: any
## option, each with every word of it, the builder's own words in full and
## the catalogue's for them a little less ("tile 1 x 2 rounded ends" is
## 1126, Tile 1 x 2 with Rounded Ends, before 1748, Tile 1 x 2 Half Round).
func _matching(index: Dictionary, term: Dictionary, loose: bool = false) -> Dictionary:
	var out: Dictionary = {}
	var options: Array = term["options"]
	for k: int in options.size():
		var option: PackedStringArray = options[k]
		var share: float = 1.0 if k < int(term.get("full", 1)) else OTHER_WORDS_SHARE
		var found: Dictionary = {}
		for n: int in option.size():
			var having: Dictionary = _having(index, option[n], loose)
			if n == 0:
				found = having
				continue
			var both: Dictionary = {}
			var smaller: Dictionary = having if having.size() < found.size() else found
			var other: Dictionary = found if smaller == having else having
			for at: int in smaller:
				if other.has(at):
					both[at] = minf(float(smaller[at]), float(other[at]))
			found = both
			if found.is_empty():
				break
		for at: int in found:
			out[at] = maxf(float(out.get(at, 0.0)), share * float(found[at]))
	return out


## [method _matching] into [param out], a share a part, for the parts
## [param touched] lists: the same answer, without a dictionary entry a part,
## since a first letter typed is the start of words thousands of parts have.
func _matching_into(index: Dictionary, term: Dictionary, loose: bool,
		out: PackedFloat32Array, touched: PackedInt32Array) -> void:
	var options: Array = term["options"]
	for k: int in options.size():
		var option: PackedStringArray = options[k]
		var share: float = 1.0 if k < int(term.get("full", 1)) else OTHER_WORDS_SHARE
		if option.size() == 1:
			_having_into(index, option[0], loose, share, out, touched)
		else:
			var found: Dictionary = _matching(index, {"options": [option]}, loose)
			for at: int in found:
				_raise(out, touched, at, share * float(found[at]))


## [method _having] into [param out], each share times [param share].
func _having_into(index: Dictionary, word: String, loose: bool, share: float,
		out: PackedFloat32Array, touched: PackedInt32Array) -> void:
	for form: String in _forms(word):
		for at: int in index.get(form, []):
			_raise(out, touched, at, share)
	# A word begun is looked for by its start; one or two letters only in
	# the names, where they are what is being typed and keywords are noise.
	if not loose or word.is_valid_float() or (word.length() < 3 and not is_same(index, _named)):
		return
	var begun: float = share * PREFIX_SHARE
	if word.length() == 1 and is_same(index, _named):
		for at: int in _by_letter.get(word, PackedInt32Array()):
			if out[at] < begun:
				if out[at] == 0.0:
					touched.append(at)
				out[at] = begun
		return
	var words: PackedStringArray = _words_of_index(index)
	var n: int = words.bsearch(word)
	while n < words.size() and words[n].begins_with(word):
		for at: int in index[words[n]]:
			if out[at] < begun:
				if out[at] == 0.0:
					touched.append(at)
				out[at] = begun
		n += 1
	if word.length() >= 3 and not named(word):
		for near: String in _near(word):
			for at: int in index.get(near, []):
				_raise(out, touched, at, share * FUZZY_SHARE)


static func _raise(out: PackedFloat32Array, touched: PackedInt32Array, at: int,
		share: float) -> void:
	if out[at] < share:
		if out[at] == 0.0:
			touched.append(at)
		out[at] = share


## The parts a number asked for names: 3023 asked, 3023b meant, and not
## 30236, a spider.
func _numbered(said: String) -> Dictionary:
	var out: Dictionary = {}
	if PART_NUMBER.search(said) == null:
		return out
	var n: int = _numbers.bsearch(said)
	while n < _numbers.size() and _numbers[n].begins_with(said):
		if not _numbers[n].substr(said.length(), 1).is_valid_int():
			out[_number_at[n]] = 1.0
		n += 1
	return out


## The words of [param asked] that no part has, as they were asked.
func unknown(asked: String) -> PackedStringArray:
	var out := PackedStringArray()
	for term: Dictionary in terms_of(asked):
		if term.has("options") and _matching(_named, term).is_empty() \
				and _matching(_also, term).is_empty() and _matching(_keyed, term).is_empty() \
				and _numbered(term["said"]).is_empty():
			out.append(term["said"])
	return out


## The parts that answer [param asked] (in PartLibrary.in_ldraw_words'
## words), best first, at most [param limit]. With [param every_word], only
## parts that have every one; with [param loose], a word's start, a word a
## letter off and two run together answer it too.
func find(asked: String, limit: int, every_word: bool = false,
		loose: bool = true) -> Array[PartLibrary.PartInfo]:
	var found: Array[PartLibrary.PartInfo] = []
	for at: int in ranked(asked, limit, every_word, loose):
		found.append(_infos[at])
	return found


## [method find]'s parts as indexes into the index's own list, best first.
## With [param every_word], every word but a version's (a term's "optional").
func ranked(asked: String, limit: int, every_word: bool = false,
		loose: bool = true) -> PackedInt32Array:
	var terms: Array[Dictionary] = terms_of(asked)
	# A word being typed that reads as one that says nothing yet ("a", on
	# its way to arch) is looked for as itself.
	if terms.is_empty() and loose and not asked.strip_edges().is_empty():
		var typed: PackedStringArray = words_of(asked)
		if not typed.is_empty():
			terms.append(_term(typed[typed.size() - 1]))
	if terms.is_empty():
		return PackedInt32Array()
	if loose:
		for term: Dictionary in terms:
			if not term.has("sizes"):
				(term["options"] as Array).append_array(_apart(str(term["said"])))
	var count_of: int = _infos.size()
	var decor_asked: bool = false
	var score := PackedFloat32Array()   ## what its matched words are worth
	var shares := PackedFloat32Array()  ## its terms' shares multiplied
	var matched := PackedInt32Array()   ## terms matched
	var literal := PackedInt32Array()   ## terms matched in the builder's own words
	var flags := PackedByteArray()      ## 1 asked for by its number, 2 its number typed
	var required := PackedInt32Array()  ## terms matched that every_word requires
	score.resize(count_of)
	required.resize(count_of)
	shares.resize(count_of)
	shares.fill(1.0)
	matched.resize(count_of)
	literal.resize(count_of)
	flags.resize(count_of)
	var touched := PackedInt32Array()   ## every part a term matched
	var possible: float = 0.0           ## what every word asked is worth
	var total: float = float(count_of + 1)
	# Two words a name runs together: "air tank" is LDraw's Airtank, "lift
	# arm" its Liftarm, which the words matched whole no longer find inside.
	var joined: Array[Dictionary] = []
	for n: int in terms.size():
		joined.append({})
		if n > 0 and terms[n].has("options") and terms[n - 1].has("options") \
				and not terms[n].has("sizes") and not terms[n - 1].has("sizes"):
			var together: String = str(terms[n - 1]["said"]) + str(terms[n]["said"])
			for at: int in _named.get(together, []):
				joined[n][at] = 1.0
				joined[n - 1][at] = 1.0
	for n: int in terms.size():
		var term: Dictionary = terms[n]
		var said: String = term["said"]
		var by_name := PackedFloat32Array()
		var by_keyword := PackedFloat32Array()
		by_name.resize(count_of)
		by_keyword.resize(count_of)
		var named_list := PackedInt32Array()
		var keyed_list := PackedInt32Array()
		if term.has("sizes"):
			# A height asked and not the part's is the right footprint and
			# still not quite the part: 60032, Window 1 x 2 x 2, for "window
			# 1 x 2 x 2", before 60602, the glass of a 1 x 2 x 3.
			var share: float = 1.0 if (term["tall"] as Array).is_empty() else OTHER_WORDS_SHARE
			for key: String in term["sizes"]:
				for at: int in _sized.get(key, []):
					_raise(by_name, named_list, at, share)
			for key: String in term["tall"]:
				for at: int in _tall.get(key, []):
					_raise(by_name, named_list, at, 1.0)
			_matching_into(_keyed, term, false, by_keyword, keyed_list)
		else:
			decor_asked = decor_asked or said == "print" or said == "sticker"
			_matching_into(_named, term, loose, by_name, named_list)
			var by_also := PackedFloat32Array()
			by_also.resize(count_of)
			var also_list := PackedInt32Array()
			_matching_into(_also, term, loose, by_also, also_list)
			# The words the set inventories name it by are its name as much as
			# LDraw's: Rebrickable's, and BrickLink's with them.
			for at: int in also_list:
				_raise(by_name, named_list, at, by_also[at])
			if STUDLESS.has(said):
				for at: int in count_of:
					if _infos[at].stud_count == 0:
						_raise(by_name, named_list, at, 1.0)
			# A family that is a height, asked of a part of another family:
			# answered by how tall it is, as fully as by its name.
			for form: String in _forms(said):
				for at: int in _by_height.get(form, PackedInt32Array()):
					_raise(by_name, named_list, at, 1.0)
			var by_number: Dictionary = _numbered(said)
			for at: int in by_number:
				_raise(by_name, named_list, at, 1.0)
				flags[at] |= 1
				if _infos[at].id.to_lower() == said:
					flags[at] |= 2
			for at: int in joined[n]:
				_raise(by_name, named_list, at, 1.0)
			_matching_into(_keyed, term, loose, by_keyword, keyed_list)
		var count: int = named_list.size()
		for at: int in keyed_list:
			if by_name[at] == 0.0:
				count += 1
		if count == 0:
			continue
		# A word few parts have says more about which one: macaroni, ovoid,
		# a part number. "tile" or "brick" is said of thousands.
		var worth: float = log(total / float(count + 1))
		possible += worth
		var needs: int = 0 if term.get("optional", false) else 1
		for at: int in named_list:
			# Its name or its keywords: either saying it says it, and both
			# say it more. 85080 is a corner round by name and macaroni by
			# its keywords, 67810 a curved corner only by name.
			var share: float = 1.0 - (1.0 - by_name[at]) * (1.0 - by_keyword[at] * KEYWORD_SHARE)
			if matched[at] == 0:
				touched.append(at)
			score[at] += worth * share
			matched[at] += 1
			required[at] += needs
			shares[at] *= share
			if by_name[at] >= 1.0:
				literal[at] += 1
		for at: int in keyed_list:
			if by_name[at] == 0.0:
				if matched[at] == 0:
					touched.append(at)
				score[at] += worth * by_keyword[at] * KEYWORD_SHARE
				matched[at] += 1
				required[at] += needs
				shares[at] *= by_keyword[at] * KEYWORD_SHARE

	# A print has the words of what is printed on it as well as its shape's:
	# "round corner plate macaroni large" found 25269p04, a 1 x 1 tile with
	# a pattern that says plate and large. Asked for by shape, it has no
	# more of the words than the part it is a print of. One its part has none
	# of is found by what is printed on it: "Å" is 3005pwc.
	if not decor_asked:
		for at: int in touched:
			var plain_at: int = _print_of[at]
			if plain_at >= 0 and matched[plain_at] > 0:
				matched[at] = mini(matched[at], matched[plain_at])
				required[at] = mini(required[at], required[plain_at])
				literal[at] = mini(literal[at], literal[plain_at])
				score[at] = minf(score[at], score[plain_at])
	# One key a part, the larger the better, in fields that decide the order
	# one after another: a part asked for by its number ("2x2 bracket
	# inverted 99207" is 99207, a 1 x 2 - 2 x 2 bracket LDraw calls Up), then
	# how many of the words it has, then the number typed itself (3001 before
	# 3001b, and "3623 print" its prints), then plain before
	# prints, stickers and other systems' parts, then how well it has them:
	# all in the builder's own words in its own name (a wedge brick for
	# "wedge" before a wing that says it only in its keywords), then by its
	# words' shares multiplied, in three
	# bands: as good as a word begun, as one a letter off, and less; then a
	# part filed under a word asked, the thing itself. Then, among the
	# parts that answer as well, how much real sets use it: 60596,
	# the door frame in 850 sets, before 80400a, in 24. Then the plainer name,
	# what its words are worth, and the catalogue's order. Sorted as numbers.
	# The words a category may begin with for the part to be the thing asked
	# for, and not a part that has it ("wedge" is Wedge 4 x 2, not Technic
	# Wedge Belt Wheel, in more sets): each word asked, its forms and the
	# words one letter off it, and the start of any word asked, as typed.
	var leads: Dictionary = {}
	var begun := PackedStringArray()
	for term: Dictionary in terms:
		if term.has("sizes"):
			continue
		for option: PackedStringArray in term["options"]:
			for word: String in option:
				for form: String in _forms(word):
					leads[form] = true
				if loose and not word.is_valid_float():
					begun.append(word)
					if word.length() >= 3 and not named(word):
						for near: String in _near(word):
							leads[near] = true
	var keys := PackedInt64Array()
	var needed: int = 0
	for term: Dictionary in terms:
		if not term.get("optional", false):
			needed += 1
	for at: int in touched:
		var has: int = matched[at]
		if has == 0 or (every_word and required[at] < needed):
			continue
		var tier: int = 3
		if literal[at] < has:
			var product: float = shares[at]
			tier = 2 if product >= PREFIX_SHARE - 0.01 else (1 if product >= FUZZY_SHARE - 0.01 else 0)
		var worth: int = mini(1023, roundi(1023.0 * score[at] / maxf(possible, 0.001)))
		var lead: String = _lead[at]
		var named_for: int = 1 if leads.has(lead) else 0
		if named_for == 0:
			for start: String in begun:
				if lead.begins_with(start):
					named_for = 1
					break
		var key: int = flags[at] & 1
		key = key * 16 + mini(15, has)
		key = key * 2 + ((flags[at] >> 1) & 1)
		# A print or a sticker asked for is a part with it on: a sticker
		# itself, off its sheet, after them.
		key = key * 2 + ((0 if _infos[at].category == "Sticker" else 1) if decor_asked
			else _plain[at])
		key = key * 4 + tier
		key = key * 2 + named_for
		key = key * 4096 + _usage[at]
		key = key * 16 + _plainness[at]
		key = key * 1024 + worth
		key = key * 65536 + (65535 - at)
		keys.append(key)
	keys.sort()
	var out := PackedInt32Array()
	var n: int = keys.size() - 1
	while n >= 0 and (limit < 0 or out.size() < limit):
		out.append(65535 - int(keys[n] % 65536))
		n -= 1
	return out


## The part at [param at] of [method ranked]'s list.
func info_at(at: int) -> PartLibrary.PartInfo:
	return _infos[at]


## Duplo, Modulex and the other systems filed in the same library, which
## nobody building with LEGO bricks means: "antenna 1 x 4" led with a Duplo
## flagpole 1 x 9, for its size in its name.
static func _other_line(info: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.to_lower()
	for line: String in OTHER_LINES:
		if name.begins_with(line):
			return true
	return false


const OTHER_LINES: Array[String] = ["duplo", "modulex", "primo", "quatro", "fabuland",
	"znap", "galidor", "scala"]
