## The kinds of model the gallery sorts shared models into, and a first
## guess at one from what a model is called.
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


## The kind [param text] says, first match in an order that puts the
## narrow before the broad: a gear train's orrery is a mechanism before it
## is space, a spaceship is space before it is a vehicle, a wizard's tower
## is fantasy before it is a building. "" when nothing is said.
static func guess(text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	for pair: Array in _vocabulary():
		if not SubjectWords.first_named(text, pair[1]).is_empty():
			return str(pair[0])
	return ""


static func _vocabulary() -> Array:
	var groups: Dictionary = {}
	for pair: Array in Style.GROUP_WORDS:
		groups[str(pair[1])] = pair[0]
	return [
		["mechanism", Style.TRAITS["mechanism"]],
		["space", groups.get("space", [])],
		["castle", groups.get("fantasy", [])],
		["figure", FIGURE_WORDS],
		["art", ART_WORDS],
		["vehicle", Style.TRAITS["vehicle"] + groups.get("vehicles", [])],
		["architecture", groups.get("architecture", [])],
		["town", groups.get("buildings_since_2010", [])],
		["robot", Style.TRAITS["machine"]],
		["nature", Style.TRAITS["living"]],
	]
