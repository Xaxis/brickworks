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
## A word only the set inventories name a part by: matched, but not the builder's
## own word in its name, so of the parts that have every word, those whose LDraw
## name says them come first. "round brick 2 x 2" is 3941, Brick 2 x 2 Round,
## before 98100, a truncated cone the inventories call a round brick.
const ALSO_SHARE := 0.9

static var SIZE := RegEx.create_from_string(
	"(\\d+(?:\\.\\d+)?) x (\\d+(?:\\.\\d+)?)(?: x (\\d+(?:\\.\\d+)?))?")
static var MIXED := RegEx.create_from_string("(\\d+) (\\d+)/(\\d+)")
static var FRACTION := RegEx.create_from_string("(\\d+)/(\\d+)")
## Letters of any script are a word's: "Å" on 3005pwc, 忍者 in 57895p01's keywords.
static var NOT_A_WORD := RegEx.create_from_string("[^\\p{L}\\p{N}. ]+")
## A part number, or the start of one: 3001, 3023b, 30367.
static var PART_NUMBER := RegEx.create_from_string("^\\d{3,}[a-z0-9]*$")

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


func _init(parts: Dictionary, ids: PackedStringArray) -> void:
	for id: String in ids:
		var info: PartLibrary.PartInfo = parts[id]
		if info.is_redirect():
			continue
		var at: int = _infos.size()
		_infos.append(info)
		_at[info.id] = at
		# The number and the category say no size, so the name's is the first.
		var own: PackedStringArray = words_of(info.own_words())
		_index(_named, own, at)
		if not info.also_called.is_empty():
			_index(_also, words_of(info.also_called), at)
		if not info.keywords.is_empty():
			_index(_keyed, words_of(info.keyword_words()), at)
		var size: PackedStringArray = _size_key(own)
		if not size.is_empty():
			_index(_sized, PackedStringArray([size[0]]), at)
			if size.size() > 1:
				_index(_tall, PackedStringArray([size[1]]), at)


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
## A term is {"said": the query's words, "options": [PackedStringArray, ...]}
## (every word of one option on a part matches it), or a size's
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

	var phrases: Array = SAME_SHAPE.keys().filter(func(key: String) -> bool:
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
		if COLOUR_WORDS.has(word) and not decor_asked:
			colours.append(_term(word))
		else:
			terms.append(_term(word))
	# A colour is what a part is placed in, not which part: "slope 45 2x2
	# trans clear" is 3039, and a part with Trans Clear in its name is a
	# print or an assembly. Unless it is all that was asked.
	return terms if not terms.is_empty() else colours


static func _term(said: String) -> Dictionary:
	var options: Array = [said.split(" ", false)]
	for other: String in SAME_SHAPE.get(said, []):
		options.append(other.split(" ", false))
	if NUMBER_WORDS.has(said):
		options.append(PackedStringArray([NUMBER_WORDS[said]]))
	return {"said": said, "options": options}


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


## The parts that have [param word] in any of its forms, in [param index].
static func _having(index: Dictionary, word: String) -> Dictionary:
	var out: Dictionary = {}
	for form: String in _forms(word):
		for at: int in index.get(form, []):
			out[at] = true
	return out


## The parts one term matches in [param index], each -> how fully: any
## option, each with every word of it, the builder's own words in full and
## the catalogue's for them a little less ("tile 1 x 2 rounded ends" is
## 1126, Tile 1 x 2 with Rounded Ends, before 1748, Tile 1 x 2 Half Round).
func _matching(index: Dictionary, term: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var share: float = 1.0
	for option: PackedStringArray in term["options"]:
		var found: Dictionary = {}
		for n: int in option.size():
			var having: Dictionary = _having(index, option[n])
			if n == 0:
				found = having
				continue
			var both: Dictionary = {}
			var smaller: Dictionary = having if having.size() < found.size() else found
			var other: Dictionary = found if smaller == having else having
			for at: int in smaller:
				if other.has(at):
					both[at] = true
			found = both
			if found.is_empty():
				break
		for at: int in found:
			out[at] = maxf(float(out.get(at, 0.0)), share)
		share = OTHER_WORDS_SHARE
	return out


## The parts a number asked for names: 3023 asked, 3023b meant, and not
## 30236, a spider.
func _numbered(said: String) -> Dictionary:
	var out: Dictionary = {}
	if PART_NUMBER.search(said) == null:
		return out
	for at: int in _infos.size():
		var id: String = _infos[at].id.to_lower()
		if id.begins_with(said) and not id.substr(said.length(), 1).is_valid_int():
			out[at] = 1.0
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
## parts that have every one.
func find(asked: String, limit: int, every_word: bool = false) -> Array[PartLibrary.PartInfo]:
	var terms: Array[Dictionary] = terms_of(asked)
	var found: Array[PartLibrary.PartInfo] = []
	if terms.is_empty():
		return found
	var decor_asked: bool = false
	var score: Dictionary = {}      ## index -> what its matched words are worth
	var matched: Dictionary = {}    ## index -> terms matched
	var literal: Dictionary = {}    ## index -> terms matched in the builder's own words
	var numbered: Dictionary = {}   ## index -> asked for by its number
	var total: float = float(_infos.size() + 1)
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
		var by_name: Dictionary = {}
		var by_keyword: Dictionary = {}
		if term.has("sizes"):
			# A height asked and not the part's is the right footprint and
			# still not quite the part: 60032, Window 1 x 2 x 2, for "window
			# 1 x 2 x 2", before 60602, the glass of a 1 x 2 x 3.
			var share: float = 1.0 if (term["tall"] as Array).is_empty() else OTHER_WORDS_SHARE
			for key: String in term["sizes"]:
				for at: int in _sized.get(key, []):
					by_name[at] = share
			for key: String in term["tall"]:
				for at: int in _tall.get(key, []):
					by_name[at] = 1.0
			by_keyword = _matching(_keyed, term)
		else:
			decor_asked = decor_asked or said == "print" or said == "sticker"
			by_name = _matching(_named, term)
			for at: int in _matching(_also, term):
				if not by_name.has(at):
					by_name[at] = ALSO_SHARE
			if STUDLESS.has(said):
				for at: int in _infos.size():
					if _infos[at].stud_count == 0:
						by_name[at] = 1.0
			var by_number: Dictionary = _numbered(said)
			numbered.merge(by_number)
			by_name.merge(by_number, true)
			by_name.merge(joined[n], true)
			by_keyword = _matching(_keyed, term)
		var count: int = by_name.size()
		for at: int in by_keyword:
			if not by_name.has(at):
				count += 1
		if count == 0:
			continue
		# A word few parts have says more about which one: macaroni, ovoid,
		# a part number. "tile" or "brick" is said of thousands.
		var worth: float = log(total / float(count + 1))
		for at: int in by_name:
			# Its name or its keywords: either saying it says it, and both
			# say it more. 85080 is a corner round by name and macaroni by
			# its keywords, 67810 a curved corner only by name.
			var share: float = 1.0 - (1.0 - float(by_name[at])) \
				* (1.0 - float(by_keyword.get(at, 0.0)) * KEYWORD_SHARE)
			score[at] = float(score.get(at, 0.0)) + worth * share
			matched[at] = int(matched.get(at, 0)) + 1
			if by_name[at] >= 1.0 or float(by_keyword.get(at, 0.0)) >= 1.0:
				literal[at] = int(literal.get(at, 0)) + 1
		for at: int in by_keyword:
			if not by_name.has(at):
				score[at] = float(score.get(at, 0.0)) + worth * by_keyword[at] * KEYWORD_SHARE
				matched[at] = int(matched.get(at, 0)) + 1
				if by_keyword[at] >= 1.0:
					literal[at] = int(literal.get(at, 0)) + 1

	# A print has the words of what is printed on it as well as its shape's:
	# "round corner plate macaroni large" found 25269p04, a 1 x 1 tile with
	# a pattern that says plate and large. Asked for by shape, it has no
	# more of the words than the part it is a print of.
	if not decor_asked:
		for at: int in matched.keys():
			var plain_at: int = _at.get(_infos[at].print_of, -1)
			if plain_at >= 0:
				matched[at] = mini(int(matched[at]), int(matched.get(plain_at, 0)))
				literal[at] = mini(int(literal.get(at, 0)), int(literal.get(plain_at, 0)))
				score[at] = minf(float(score.get(at, 0.0)), float(score.get(plain_at, 0.0)))
	# Grouped by what decides the order: a part asked for by its number
	# ("2x2 bracket inverted 99207" is 99207, a 1 x 2 - 2 x 2 bracket LDraw
	# calls Up), then how many of the words it has, then plain before
	# prints, stickers and other systems' parts, then how many of the words
	# in the builder's own (85080, macaroni in its keywords, before 67810, a
	# curved corner). Within a group, by what its words are worth: parts
	# within a tenth of each other are ordered as the catalogue orders them
	# (PartsBin._sort_for), so 27925, the macaroni tile in a thousand sets,
	# is not put after 7836, its trans light blue variant with an understud,
	# for a share of one word. Only the groups that will be listed are sorted.
	var groups: Dictionary = {}     ## group -> {worth -> [PartInfo]}
	for at: int in matched:
		if every_word and int(matched[at]) < terms.size():
			continue
		var info: PartLibrary.PartInfo = _infos[at]
		var plain: int = 1 if (decor_asked or (info.decor() == 0
			and not info.name.begins_with("="))) and not _other_line(info) else 0
		var group: int = (1 if numbered.has(at) else 0) * 1000000 + int(matched[at]) * 10000 \
			+ plain * 1000 + int(literal.get(at, 0))
		var worth: int = roundi(float(score.get(at, 0.0)) * 1000.0)
		if not groups.has(group):
			groups[group] = {}
		var by_worth: Dictionary = groups[group]
		if not by_worth.has(worth):
			by_worth[worth] = []
		(by_worth[worth] as Array).append(info)
	var keys: Array = groups.keys()
	keys.sort()
	keys.reverse()
	for group: int in keys:
		var by_worth: Dictionary = groups[group]
		var worths: Array = by_worth.keys()
		worths.sort()
		worths.reverse()
		var n: int = 0
		while n < worths.size() and found.size() < limit:
			var near: Array[PartLibrary.PartInfo] = []
			var top: int = worths[n]
			while n < worths.size() and int(worths[n]) * 10 >= top * 9:
				near.append_array(by_worth[worths[n]])
				n += 1
			PartsBin._sort_for(near, asked)
			found.append_array(near)
		if found.size() >= limit:
			break
	if found.size() > limit:
		found.resize(limit)
	return found


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
