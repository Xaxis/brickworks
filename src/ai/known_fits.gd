## Fits the LEGO Group's own sets are built with, which the exact check
## forgives: a minifigure's beard through its hair and cape, its hips in a
## seat, its hands round a steering wheel.
##
## A set sold is buildable, so where its parts' exact shapes pass into each
## other they meet that way in plastic: cloth, soft hair and a figure's grip
## give, and BrickNet's convex pieces fill what is hollow. Learned, not set by
## hand (tools/known_fits.py): every official set of the LDraw model
## repository judged as Tested judges collisions, each colliding pair keyed
## by what the two parts are (a minifigure's part by its kind, anything else
## by its mould, prints as their plain part), and, between two parts that are
## not a minifigure's, where the one is in the other's frame. A key that
## [code]sets_needed[/code] sets meet by is a fit, as deep as the deepest
## that many of them reach and a margin more; deeper, or a pair no two sets
## meet so, stays a collision.
class_name KnownFits
extends RefCounted

## The table tools/known_fits.py writes. Beside gears.json rather than in
## assets/knowledge, which the web build leaves out of its pack.
const TABLE := "res://assets/ldraw/known_fits.json"

## Read as the class loads (ExactCheck loads it on the main thread), never
## put again, so a check on a worker reads it as it is: {"plain": "a|b" ->
## depth, "posed": "a|b" -> [[place, turn, depth], ...], "kinds": part or
## mould -> kind ([method kind_for], "held" included), "place", "turn"}.
static var _table: Dictionary = _read()


static func _read() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(TABLE) if FileAccess.file_exists(TABLE) else ""
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	var plain: Dictionary = {}
	var posed: Dictionary = {}
	var out: Dictionary = {"plain": plain, "posed": posed, "kinds": {}, "place": 0.0, "turn": 0.0}
	if not parsed is Dictionary:
		return out
	var raw: Dictionary = parsed
	out["kinds"] = raw.get("kinds", {})
	out["place"] = float(raw.get("place", 0.0))
	out["turn"] = float(raw.get("turn", 0.0))
	for fit: Dictionary in raw.get("fits", []):
		var key: String = "%s|%s" % [fit["a"], fit["b"]]
		if not fit.has("at"):
			plain[key] = float(fit["depth"])
			continue
		var at: Array = fit["at"]
		var turn := Basis(Vector3(at[3], at[4], at[5]), Vector3(at[6], at[7], at[8]),
			Vector3(at[9], at[10], at[11]))
		if not posed.has(key):
			posed[key] = []
		(posed[key] as Array).append([Vector3(at[0], at[1], at[2]), turn, float(fit["depth"])])
	return out


## How deep parts [param a] and [param b] may pass into each other, b standing
## at [param rel] in a's frame, by the sets: 0 where no set meets so. A
## minifigure's part meets by its kind, against another's kind, a thing a
## figure holds or sits on by its mould, or any other part as "brick"; two
## parts that are not a minifigure's by their moulds, where the sets put
## the one in the other's frame.
static func reach(a: String, b: String, rel: Transform3D) -> float:
	var kinds: Dictionary = _table["kinds"]
	var ma: String = family(a)
	var mb: String = family(b)
	var ka: String = str(kinds.get(a, kinds.get(ma, "")))
	var kb: String = str(kinds.get(b, kinds.get(mb, "")))
	var body: bool = _body(ka) or _body(kb)
	ka = ka if _body(ka) else "brick" if body and ka != "held" else ma
	kb = kb if _body(kb) else "brick" if body and kb != "held" else mb
	if ka > kb:
		var was: String = ka
		ka = kb
		kb = was
		rel = rel.affine_inverse()
	var key: String = "%s|%s" % [ka, kb]
	if body:
		return float((_table["plain"] as Dictionary).get(key, 0.0))
	var most: float = 0.0
	for pose: Array in (_table["posed"] as Dictionary).get(key, []):
		if _near(rel, pose) or (ka == kb and _near(rel.affine_inverse(), pose)):
			most = maxf(most, float(pose[2]))
	return most


static func _body(kind: String) -> bool:
	return not kind.is_empty() and kind != "held"


static func _near(rel: Transform3D, pose: Array) -> bool:
	var place: float = _table["place"]
	var turn: float = _table["turn"]
	var off: Vector3 = (rel.origin - (pose[0] as Vector3)).abs()
	if off.x > place or off.y > place or off.z > place:
		return false
	var basis: Basis = pose[1]
	for column: int in 3:
		var miss: Vector3 = (rel.basis[column] - basis[column]).abs()
		if miss.x > turn or miss.y > turn or miss.z > turn:
			return false
	return true


## A printed part's plain mould: 3039pc4 -> 3039, 3626bp01 -> 3626b, 973p84
## -> 973; Minifig._family's rule, without a RegEx, for a worker.
static func family(part_id: String) -> String:
	var n: int = part_id.length()
	var i: int = 0
	if i < n and _lower(part_id.unicode_at(i)):
		i += 1
	var digits: int = i
	while i < n and _digit(part_id.unicode_at(i)):
		i += 1
	if i == digits:
		return part_id
	# A letter after the number is the mould's (3626b) where a print or
	# nothing follows it; otherwise it begins the print (973psx).
	if i < n and _lower(part_id.unicode_at(i)) and _printed(part_id.substr(i + 1)):
		return part_id.substr(0, i + 1)
	if _printed(part_id.substr(i)):
		return part_id.substr(0, i)
	return part_id


## Whether [param rest] is nothing or a print's suffix: "p" and letters or
## digits.
static func _printed(rest: String) -> bool:
	if rest.is_empty():
		return true
	if rest.length() < 2 or rest[0] != "p":
		return false
	for k: int in range(1, rest.length()):
		var c: int = rest.unicode_at(k)
		if not _lower(c) and not _digit(c):
			return false
	return true


static func _lower(c: int) -> bool:
	return c >= 97 and c <= 122


static func _digit(c: int) -> bool:
	return c >= 48 and c <= 57


## What a part is to a minifigure: "hair", "headgear", "head", "beard",
## "neckwear", "back", "cape", "torso", "arm", "hand", "hips", "hipwear",
## "legs", "footwear" or "held" (Minifig.slot_for, with hair and beards told
## apart from other headgear and neckwear); "" for a part that is not a
## minifigure's. Main thread: the table's "kinds" are these, for a check on
## any thread.
static func kind_for(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	if info != null and info.is_redirect():
		info = library.parts.get(info.moved_to)
	# An obsolete number, as old sets draw their figures: 3815 is
	# "~Minifig Hips (Obsolete)", filed under Obsolete.
	if info != null and info.name.begins_with("~Minifig "):
		var plain := PartLibrary.PartInfo.new()
		plain.name = info.name.trim_prefix("~").trim_suffix(" (Obsolete)")
		plain.category = "" if info.category == "Obsolete" else info.category
		info = plain
	var slot: String = Minifig.slot_for(info)
	if slot.is_empty():
		return ""
	var short: String = Minifig._short_name(info.name)
	match slot:
		"headwear":
			return "hair" if short.begins_with("Hair") else "headgear"
		"hat_extra":
			return "headgear"
		"neck":
			return "beard" if short.begins_with("Beard") else "neckwear"
		"arms":
			return "arm"
		"hands":
			return "hand"
		"accessory", "accessory_left":
			return "held"
	return slot
