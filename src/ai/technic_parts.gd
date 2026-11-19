## What a LEGO® Technic set shows on its surface, read from real sets, and how
## each of those parts is held where it meets a studded body.
##
## The nine Technic subjects of the bench's 44 lost every verdict in both of
## design24's arms, on parts, not form; in October four studless levers lifted
## technique and lost likeness, 38% to 19% (docs/DESIGN_SCORES.md). design25's
## parts, laid at a feature's close look, were kept in 71 spots: a part reaches
## the design only when the session lays it in the build it keeps. So a
## subject said to be in the style of Technic sets keeps the studded body the
## session builds well, and its first build is told what a Technic set shows
## on its surface and how each is held there: the answer to
## how_real_sets_build_this, the method's first answer on the connector, and
## a first submission with none of it sent back once (Assistant.technic_*).
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
## The roles a first build is told to lay, in the order a builder thinks of
## them: what covers the body, the frame lines, what turns, what it runs on.
const TOLD: Array = ["curved_panel", "flat_panel", "beam", "bent_liftarm", "gear", "wheel"]
## The roles that are a Technic set's look on a body, as against what it
## runs on: a design with none of the panels and too few of the frame lines
## shows nothing of one.
const PANELS: Array = ["curved_panel", "flat_panel", "mudguard"]
const FRAME: Array = ["beam", "bent_liftarm", "thin_liftarm"]
## How many beams and liftarms make the frame lines seen on a body's flanks
## and top: two a side and two over it.
const FRAME_FROM := 4
## How many of each role's parts are named.
const NAMED := 6

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
static var _said_of: RegEx = RegEx.create_from_string(
	"(?i)\\btechnic\\b(?![\\s-]+(?:%s)\\b)" % PART_WORDS)
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


## How many of [param parts] (part ids) are of each role.
static func roles_in(parts: Array, library: PartLibrary) -> Dictionary:
	var counts: Dictionary = {}
	for part: Variant in parts:
		var info: PartLibrary.PartInfo = library.parts.get(str(part)) if library != null else null
		if info == null:
			continue
		var role: String = role_of(info.name)
		if not role.is_empty():
			counts[role] = int(counts.get(role, 0)) + 1
	return counts


static func _count(counts: Dictionary, roles: Array) -> int:
	var n: int = 0
	for role: String in roles:
		n += int(counts.get(role, 0))
	return n


## Whether a design with these role counts shows a Technic set's surface:
## panels on it, and the frame lines.
static func shows_it(counts: Dictionary) -> bool:
	return _count(counts, PANELS) > 0 and _count(counts, FRAME) >= FRAME_FROM


static func _percent(share: float) -> String:
	return "%d%%" % roundi(100.0 * share)


## A role's parts, said: "11946 / 11947 Panel Fairing Smooth #21 / #22 (Thin
## Short)". A left and a right of one, listed one after the other, are said
## once.
static func _parts_said(role: Dictionary, most: int = NAMED) -> String:
	var said := PackedStringArray()
	var listed: Array = role.get("parts", [])
	var k: int = 0
	while k < listed.size() and said.size() < most:
		var one: Dictionary = listed[k]
		var name: String = str(one.get("name", "")).trim_prefix("Technic ")
		var pair: Dictionary = listed[k + 1] if k + 1 < listed.size() else {}
		var other: String = str(pair.get("name", "")).trim_prefix("Technic ")
		var mark: RegEx = RegEx.create_from_string("#(\\d+)")
		var first: RegExMatch = mark.search(name)
		var second: RegExMatch = mark.search(other)
		if first != null and second != null and name.replace(first.get_string(0), "") \
				== other.replace(second.get_string(0), ""):
			said.append("%s / %s %s" % [one["part"], pair["part"], name.replace(
				first.get_string(0), "#%s / #%s" % [first.get_string(1), second.get_string(1)])])
			k += 2
			continue
		said.append("%s %s" % [one["part"], name])
		k += 1
	return ", ".join(said)


## Where a role shows most, said: "most on its top and sides".
static func _sides_said(role: Dictionary) -> String:
	var sides: Dictionary = role.get("sides", {})
	var top: float = float(sides.get("top", 0.0))
	var flanks: float = float(sides.get("left", 0.0)) + float(sides.get("right", 0.0))
	var ends: float = float(sides.get("front", 0.0)) + float(sides.get("back", 0.0))
	if flanks >= top and flanks >= ends:
		return "most on its flanks" if top < 0.2 else "most on its flanks and top"
	if top >= ends:
		return "most on its top and flanks"
	return "most at its ends"


## Where each role goes on a studded body, as a Technic builder lays it.
const WHERE: Dictionary = {
	"curved_panel": "over the nose, the flanks, the wheel arches and the engine cover, in left "
		+ "and right pairs, each pinned at two holes",
	"flat_panel": "the large flat faces: a door, a side, a bonnet, the cab's back",
	"beam": "the frame lines: along the flanks at the wheels' height, round the cab, the top "
		+ "edges, a boom or an arm",
	"bent_liftarm": "the corners where a frame line turns, a fender's edge, an arm's elbow",
	"gear": "where a mechanism would show: a turntable under a cab or a crane, a gear on the "
		+ "flank beside the part it drives",
	"wheel": "on axles through the body, the hub's holes out",
}


## A role's line: what it is, how much of a set's surface it is, its parts
## and where they go.
static func _role_said(name: String) -> String:
	var role: Dictionary = table().get("roles", {}).get(name, {})
	if role.is_empty():
		return ""
	var where: String = str(WHERE.get(name, ""))
	return "  - %s: %s of what shows on the median set (to %s), %s, in %d of %d sets: %s. %s." % [
		role.get("called", name), _percent(float(role.get("median", 0.0))),
		_percent(float(role.get("upper", 0.0))), _sides_said(role), int(role.get("in_sets", 0)),
		(table().get("read", []) as Array).size(), _parts_said(role),
		where.left(1).to_upper() + where.substr(1)]


## The ways the table's roles are held on a studded body, the most used first,
## each with how many of the told roles' parts it holds.
static func _holds_said() -> String:
	var parts: Dictionary = {}
	var said: Dictionary = {}
	var lines: Dictionary = {}
	for name: String in TOLD:
		for way: Variant in (table().get("roles", {}).get(name, {}) as Dictionary).get("holds", []):
			var kind: String = str((way as Dictionary).get("way", ""))
			parts[kind] = int(parts.get(kind, 0)) + int((way as Dictionary).get("parts", 0))
			said[kind] = str((way as Dictionary).get("said", ""))
			for line: Variant in (way as Dictionary).get("lines", []):
				var id: String = str((line as Dictionary).get("part", ""))
				if not id.contains(" "):
					var by: Dictionary = lines.get(kind, {})
					by[id] = int(by.get(id, 0)) + int((line as Dictionary).get("uses", 0))
					lines[kind] = by
	var kinds: Array = parts.keys()
	kinds.sort_custom(func(one: String, other: String) -> bool:
		return int(parts[one]) > int(parts[other]))
	var total: int = 0
	for kind: String in kinds:
		total += int(parts[kind])
	var out := PackedStringArray()
	for kind: String in kinds.slice(0, 4):
		out.append("  - %s (%s of them)" % [said[kind], _percent(float(parts[kind]) / maxf(total, 1))])
	return "\n".join(out)


## What a Technic subject's first build is told: what a Technic set shows on
## its surface, the parts, where each goes and how it is held on a studded
## body, in submit_design's own words. "" without the table.
static func surface_said() -> String:
	if not available():
		return ""
	var roles := PackedStringArray()
	for name: String in TOLD:
		var line: String = _role_said(name)
		if not line.is_empty():
			roles.append(line)
	return ("A LEGO® TECHNIC SET'S SURFACE, read from %d Technic sets since %d by what shows "
		% [(table().get("read", []) as Array).size(), int(table().get("since", 2000))]
		+ "from their four sides and above (none of them a set this is measured against). A set "
		+ "reads as Technic by the parts on its surface:\n%s\n" % "\n".join(roles)
		+ "Build the body as a studded build — bricks, plates and slopes for its masses and "
		+ "silhouette, which is where its likeness is; a bare beam frame was judged less like "
		+ "the thing every time — and lay these on its surface in the same submission, as the "
		+ "sets do on a studded body:\n%s\n" % _holds_said()
		+ "In submit_design: a Technic brick with holes laid in the wall course and named, a pin "
		+ "attached in its hole, the part attached on the pin's other end:\n"
		+ "  {\"part\": \"3701\", \"color\": 0, \"name\": \"flank1\", \"x\": 2, \"y\": 4, \"z\": 9},\n"
		+ "  {\"part\": \"2780\", \"color\": 0, \"name\": \"pin1\", \"attach\": {\"to\": "
		+ "\"flank1.socket[0]\", \"by\": \"pin[0]\", \"flip\": true}},\n"
		+ "  {\"part\": \"11946\", \"color\": 15, \"attach\": {\"to\": \"pin1.pin[1]\", \"by\": "
		+ "\"socket[0]\", \"flip\": true, \"align\": [\"-z\", \"+x\"]}}\n"
		+ "flip turns the pin out of the wall when it points in; align lays the part's length "
		+ "along the wall, and attachment_points says each part's sockets and the way they run. "
		+ "A beam or a liftarm laid flat on studs needs no pin, a stud in each hole: "
		+ "{\"part\": \"32524\", \"color\": 0, \"x\": 0, \"y\": 7, \"z\": 0}. A gear or a wheel "
		+ "goes on an axle through a Technic brick's hole, a bush (3713) outside. Wheels alone "
		+ "do not make it Technic: the panels and the frame lines do.")


## The method's word for a Technic subject, said with it once on the
## connector: what its first build lays, and where the parts are told.
const METHOD_SAID := """A LEGO® TECHNIC SUBJECT: keep the studded body you \
would build for any set (its masses are its likeness; a bare beam frame loses \
it) and, in the same first submission, lay on its surface what a Technic set \
shows there: curved panels and fairings over the nose, flanks and arches, \
beams and liftarms as the frame lines, gears where a mechanism would show, \
wheels on axles. Each is held on the body by a pin in a Technic brick with \
holes laid in the wall course, or laid flat on studs. \
how_real_sets_build_this says which parts real Technic sets use and how each \
is held, in submit_design's own words."""


## A first submission of a Technic subject that shows none of a Technic set's
## surface, sent back once: what it lacks and how to lay it. "" when it shows
## it, or without the table.
static func sent_back(counts: Dictionary) -> String:
	if not available() or shows_it(counts):
		return ""
	var lacks := PackedStringArray()
	if _count(counts, PANELS) == 0:
		lacks.append("no panel or fairing")
	var frame: int = _count(counts, FRAME)
	if frame < FRAME_FROM:
		lacks.append("%s" % ("no beam or liftarm" if frame == 0 else "%d beam%s or liftarm%s"
			% [frame, "" if frame == 1 else "s", "" if frame == 1 else "s"]))
	return ("Not applied, this once: it is in the style of LEGO® Technic sets, and it has %s "
		% " and ".join(lacks) + "on its surface, which is what a Technic set shows there. Keep "
		+ "the body of this design as it is — its masses are its likeness — and add to it, "
		+ "in this submission, the parts below where they show: panels over its nose, "
		+ "flanks and arches, beams as its frame lines.\n\n" + surface_said()
		+ "\n\nSubmitted again as it is, it is built.")
