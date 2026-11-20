## What a LEGO® Technic set shows on its surface, read from real sets, and how
## each of those parts is held where it meets a studded body.
##
## The nine Technic subjects of the bench's 44 lost every verdict in both of
## design24's arms, on parts, not form; in October four studless levers lifted
## technique and lost likeness, 38% to 19% (docs/DESIGN_SCORES.md). design26
## told a Technic subject's first build these parts, and the sessions dropped
## the panels the room around refused. So the app lays them (TechnicLay, in
## the surface pass), and this says which subjects are Technic and which
## panels real Technic sets show most.
##
## tools/technic_parts.py reads it from the LDraw model repository: each
## Technic set's main model since 2000 drawn as boxes from its four sides and
## from above, each part counting where it is the nearest thing, and how each
## part is held read from where its pins and axles go, over every set since
## 2000. Every set of the bench's two halves is held out by number and by name
## before any file is read (src/dev/technic_parts_probe.gd).
##
## The desktop reads the table from its own files; the web build fetches it
## from beside the build (knowledge/, tools/export.sh) the first time a Technic
## subject asks, as RealSnippets does.
class_name TechnicParts
extends RefCounted

const TABLE := "res://assets/knowledge/technic_parts.json.gz"
## The roles a Technic set's surface is made of, as the table has them.
const ROLES: Array = ["curved_panel", "flat_panel", "mudguard", "beam", "bent_liftarm",
	"thin_liftarm", "gear", "wheel", "mechanism", "connector"]

## A part's role by its LDraw name, first match wins, as tools/technic_parts.py
## ROLES reads it (the probe holds the two to the same answer for every part
## the table lists).
const BY_NAME: Array = [
	["mudguard", "\\bmudguard\\b|\\bwheel arch\\b|\\bwheel well\\b"],
	["curved_panel", "^technic panel\\b.*\\b(fairing|curved|bent|smooth|car|hood|cylinder|wedge"
		+ "|dome|windscreen)\\b|^technic panel fairing"],
	["flat_panel", "^technic panel\\b|^technic plate panel\\b"],
	["thin_liftarm", "^technic beam\\b.*\\bx +0\\.5\\b|^technic liftarm\\b.*\\bthin\\b"],
	["bent_liftarm", "^technic beam\\b.*\\b(bent|frame|triangle|double|angle|90|curved"
		+ "|quarter ellipse)\\b|^technic beam \\d+ x +\\d+"],
	["beam", "^technic beam\\b|^technic liftarm\\b"],
	["gear", "^technic (gear|worm|turntable|differential)\\b|^technic .*\\bgear\\b"
		+ "|^technic wedge belt wheel\\b"],
	["wheel", "^(wheel|tyre|tire)\\b(?!.*\\bholder\\b)|^technic (wheel|tyre)\\b"],
	["mechanism", "^technic (shock|pneumatic|linear|engine|steering|suspension|chain|tread"
		+ "|universal|gearbox|transmission|link|rotor|changeover|driving ring|clutch|piston"
		+ "|cylinder|excavator|crane)\\b|^electric\\b|^technic power functions\\b"],
	["connector", "^technic (axle|pin|bush|connector|cross|angle connector|axle and pin"
		+ "|beam connector|knob|ball|disc|tooth|rotation|toggle|joint)\\b"],
]

## "Technic" said of the subject, not of a part: "a Technic-style forklift",
## "in the style of LEGO® Technic sets", "technic motorcycle", but not "Technic
## bricks", "Technic link tracks" or "Technic lift arms", which a System set's
## session says of the parts it builds with. Over 832 realset sessions of
## 2026-10-26 to 11-19, this read 126 of the 147 Technic subjects as Technic,
## and none of the 685 others.
const PART_WORDS := ("bricks?|pins?|beams?|axles?|liftarms?|lift|panels?|gears?|plates?"
	+ "|connectors?|bush(?:es)?|holes?|parts?|pieces?|elements?|bits?|frames?|wheels?|tyres?"
	+ "|tires?|hubs?|links?|tracks?|treads?|arms?|push|chains?|turntables?|motors?|cylinders?"
	+ "|joints?|hinges?|rods?|studs?")

static var _table: Dictionary = {}
static var _tried: bool = false
static var _fetching: bool = false
## "Technic" as the style, not a part's name ("Technic bricks"); said with
## LEGO, studded or studless before it, it is the style whatever follows: "a
## studded Technic wheel loader".
static var _said_of: RegEx = RegEx.create_from_string(
	("(?i)\\b(?:lego\\W*|studded[\\s-]+|studless[\\s-]+)technic\\b"
	+ "|\\btechnic\\b(?![\\s-]+(?:%s)\\b)") % PART_WORDS)
static var _rules: Array = _made_rules()


static func _made_rules() -> Array:
	var rules: Array = []
	for row: Array in BY_NAME:
		rules.append([row[0], RegEx.create_from_string(row[1])])
	return rules


## The table, read from this build's own files the first time anything asks.
static func table() -> Dictionary:
	if not _tried and (not OS.has_feature("web") or FileAccess.file_exists(TABLE)):
		_tried = true
		_table = RealSnippets.read(TABLE)
	return _table


## The table, wherever this build keeps it. True when there is one. Awaited.
static func ensure(host: Node) -> bool:
	if not _tried and OS.has_feature("web") and not FileAccess.file_exists(TABLE):
		while _fetching:
			await host.get_tree().process_frame
		if not _tried:
			_fetching = true
			_table = RealSnippets.parse(await RealSnippets.fetch(host, TABLE.get_file()))
			_tried = true
			_fetching = false
	return available()


static func available() -> bool:
	return not table().get("roles", {}).is_empty()


## Whether [param words] say the subject is in the style of LEGO Technic sets.
static func of_technic(words: String) -> bool:
	return _said_of.search(words) != null


## A part's role on a Technic set's surface, "" for none of them. Its name is
## read as tools/style.py reads one: no ~ before it, no "(Obsolete)".
static func role_of(name: String) -> String:
	var said: String = " ".join(name.to_lower().replace("(obsolete)", "").lstrip("~_=| ").split(
		" ", false))
	for rule: Array in _rules:
		if (rule[1] as RegEx).search(said) != null:
			return rule[0]
	return ""
