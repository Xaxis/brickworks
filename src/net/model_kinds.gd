## The kinds of model the gallery sorts shared models into, and a first
## guess at one from what a model is called and what is said of it.
##
## The gallery filters by kind (brickworks.diy/gallery, api/_directory.js
## KINDS, the same ids in the same order: tools/web/share_probe.mjs holds
## the two together). The Share panel guesses a model's kind from its name,
## its tags and its description, and its owner changes it if the guess is
## wrong — they know what they built.
##
## The guess reads the words with the vocabularies the design loop reads a
## brief with (Style.GROUP_WORDS, Style.TRAITS), as whole words with their
## plurals (SubjectWords), so an orrery is a mechanism and never a plane,
## and a shopkeeper's shop is a building and not a castle's keep.
class_name ModelKinds
extends RefCounted

## [id, what the gallery calls it].
const KINDS: Array = [
	["castle", "Castles and fantasy"],
	["space", "Space"],
	["vehicle", "Vehicles"],
	["town", "Town and buildings"],
	["architecture", "Architecture"],
	["mechanism", "Mechanisms"],
	["robot", "Robots and machines"],
	["nature", "Animals and nature"],
	["figure", "Figures and characters"],
	["art", "Art and mosaics"],
	["other", "Something else"],
]

## Words of the kinds the design loop has no vocabulary for.
const FIGURE_WORDS: Array = ["minifigure", "minifig", "figure", "character", "figurine",
	"bust", "portrait bust", "statue"]
const ART_WORDS: Array = ["mosaic", "portrait", "painting", "picture", "art", "artwork",
	"sculpture", "logo", "sign", "pixel art"]


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for kind: Array in KINDS:
		out.append(str(kind[0]))
	return out


static func label(id: String) -> String:
	for kind: Array in KINDS:
		if str(kind[0]) == id:
			return str(kind[1])
	return ""


## The words after which a model's name says what it has, not what it is:
## "a sports car, and its driver", "a house with a car", "a minifigure of a
## chef", "a ship carrying a flag". A mark ends the subject too
## (SubjectWords.phrases).
const JOINS: Array = ["with", "and", "of", "carrying", "holding", "plus", "featuring", "including",
	"beside", "on", "in", "at", "for", "from", "by", "under", "over", "riding", "driving", "inside"]


## The kind [param text] says, read as a model's name: [method guess_from].
static func guess(text: String) -> String:
	return guess_from(text)


## The kind a model is, from its [param name], its [param tags] and what its
## owner says [param about] it, or "" when nothing is said: what its name is
## about, its subject, the words before what it has ("a house" of "a house
## with a car"); else the subject of what is said about it; else the first
## kind any of it names. Each the first match in an order that puts the
## narrow before the broad: a gear train's orrery is a mechanism before it
## is space, a spaceship is space before it is a vehicle, a wizard's tower is
## fantasy before it is a building; and a figure and a piece of art last,
## which a model is as often of its own as it carries them, the driver of a
## car, the family of a house, the sign over a shop. Read as one text in an
## order with those first, a car tagged "minifigure" for its driver was filed
## under Figures and characters, a corner shop with its shopkeeper too, a
## house with a car under Vehicles and a cinema with a sign under Art (docs5,
## 2026-11-11).
static func guess_from(name: String, tags: String = "", about: String = "") -> String:
	var vocabulary: Array = _vocabulary()
	for said: String in [name, about]:
		var kind: String = _subject_kind(said, vocabulary)
		if not kind.is_empty():
			return kind
	var text: String = "%s %s %s" % [name, tags.replace(",", " "), about]
	if text.strip_edges().is_empty():
		return ""
	for pair: Array in vocabulary:
		if not SubjectWords.first_named(text, pair[1]).is_empty():
			return str(pair[0])
	return ""


## The kind [param said]'s subject is, its words before the first mark or
## JOINS word, or "" when they name none. As whole words and their forms
## (SubjectWords.forms), and not a word made of two by its first: a jetport is
## no jet, where the guess from all the words reads it as SubjectWords does.
static func _subject_kind(said: String, vocabulary: Array) -> String:
	var phrases: Array[PackedStringArray] = SubjectWords.phrases(said)
	if phrases.is_empty():
		return ""
	var read: Array = []
	for word: String in phrases[0]:
		if not read.is_empty() and word in JOINS:
			break
		var forms: PackedStringArray = SubjectWords.forms(word)
		var named: Dictionary = {}
		for form: String in forms:
			named[form] = true
		read.append([named, forms])
	for pair: Array in vocabulary:
		for one: Variant in pair[1]:
			var wanted: PackedStringArray = SubjectWords.of(str(one))
			for start: int in range(read.size() - wanted.size() + 1):
				if not wanted.is_empty() and SubjectWords.named_at(read, start, wanted):
					return str(pair[0])
	return ""


## The assistant's words for kinds of model (Style), read through Later: the
## Library's list of kinds, which is in the first screen's code, has no
## need of them.
static func _vocabulary() -> Array:
	var style: GDScript = Later.script(&"Style")
	var traits: Dictionary = style.TRAITS
	var groups: Dictionary = {}
	for pair: Array in style.GROUP_WORDS:
		groups[str(pair[1])] = pair[0]
	# A bust is a figure's, which Style reads as a living thing's shape.
	var living: Array = (traits["living"] as Array).filter(func(word: Variant) -> bool:
		return not FIGURE_WORDS.has(word))
	return [
		["mechanism", traits["mechanism"]],
		["space", groups.get("space", [])],
		["castle", groups.get("fantasy", [])],
		["vehicle", traits["vehicle"] + groups.get("vehicles", [])],
		["architecture", groups.get("architecture", [])],
		["town", groups.get("buildings_since_2010", [])],
		["robot", traits["machine"]],
		["nature", living],
		["figure", FIGURE_WORDS],
		["art", ART_WORDS],
	]
