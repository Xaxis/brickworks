## Comments pinned to parts: a word on the part it is about, for whoever
## builds the model with you or after you (Edit, Comments…; PinsView draws
## them on the model; docs/TOGETHER.md).
##
## Kept in the model's file, a line each in the head of its main model, as
## its motions and its floor are, so a save, an open, the autosave and a
## shared link all keep them, and another program reads past them:
##
##   0 !BRICKWORKS PIN {"id":"k3f9a2","part":"3001","colour":4,"at":[0,-24,40],"text":"Roof here?","by":"Ann","tint":"#e8590c","when":"2026-10-30T12:00:00Z"}
##
## "at" is where its part stands in the file (LDraw's coordinates, LDU), as
## a motion names its joint (Motions.Joint.ref_words): the part is found
## again by its number, colour and place when the file opens, and the pin
## goes with it as it moves. A pin whose part was taken off stays where the
## part was. Resolved, a pin is kept with "resolved": true, out of the view
## and listed under Resolved, and can be opened again: nothing said is lost
## to a click.
##
## In a session each pin is a key of its own, "~pin:<id>" (Together), its
## part named by the session's uid, so two people pinning at once both keep
## theirs, and moving a pinned part changes nothing of its pin.
class_name PinnedComments
extends RefCounted

const META := "0 !BRICKWORKS PIN "
## How far a part may stand from where its pin says and still be its part
## (Motions' PLACE_SLACK).
const PLACE_SLACK := 2.0
const TEXT_MOST := 500
const NAME_MOST := 40
const ID_SHAPE := "^[a-z0-9]{1,16}$"
## How high over its part's top a pin stands, LDU.
const ABOVE := 6.0


class Pin extends RefCounted:
	var id: String = ""
	## Its part here; 0 before it is looked for, or when it is gone.
	var brick: int = 0
	var part: String = ""
	var colour: int = 0
	## Where its part stood in the file's coordinates, last it was seen.
	var at := Vector3.ZERO
	var text: String = ""
	## Who pinned it, as the others were shown them (Together's names), or "".
	var by: String = ""
	## Their colour, "#rrggbb", or "".
	var tint: String = ""
	## When, as ISO 8601 in UTC.
	var when: String = ""
	var resolved: bool = false

	func fields() -> Dictionary:
		var out: Dictionary = {"id": id, "part": part, "colour": colour,
			"at": [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)],
			"text": text, "by": by, "tint": tint, "when": when}
		if resolved:
			out["resolved"] = true
		return out

	func copy() -> Pin:
		var out := Pin.new()
		for field: String in ["id", "brick", "part", "colour", "at", "text", "by", "tint", "when",
				"resolved"]:
			out.set(field, get(field))
		return out


## In the order they were pinned (then by id), the same on every side and
## in the file whatever order two pinned at once arrived in.
var list: Array[Pin] = []


## A pin from its words, read at the edge: null for anything not a pin.
static func pin_from(given: Variant) -> Pin:
	if not given is Dictionary:
		return null
	var said: Dictionary = given
	var id: String = str(said.get("id", ""))
	var at: Variant = said.get("at", [0, 0, 0])
	if RegEx.create_from_string(ID_SHAPE).search(id) == null or not at is Array \
			or (at as Array).size() != 3:
		return null
	for number: Variant in at:
		if not (number is float or number is int) or not is_finite(float(number)) \
				or absf(float(number)) > 1e7:
			return null
	var text: String = str(said.get("text", "")).strip_edges()
	var colour: Variant = said.get("colour", 0)
	if text.is_empty() or not (colour is float or colour is int):
		return null
	var pin := Pin.new()
	pin.id = id
	pin.part = str(said.get("part", "")).left(64)
	pin.colour = int(colour)
	pin.at = Vector3(float(at[0]), float(at[1]), float(at[2]))
	pin.text = text.left(TEXT_MOST)
	pin.by = str(said.get("by", "")).strip_edges().left(NAME_MOST)
	var tint: String = str(said.get("tint", ""))
	pin.tint = tint if RegEx.create_from_string("^#[0-9a-fA-F]{6}$").search(tint) != null else ""
	pin.when = str(said.get("when", "")).left(40)
	pin.resolved = said.get("resolved", false) == true
	return pin


## The pins a model's text carries. On any thread.
static func read(text: String) -> PinnedComments:
	var out := PinnedComments.new()
	if not text.contains(META):
		return out
	var seen: Dictionary = {}
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if not line.begins_with(META.strip_edges()):
			continue
		var pin: Pin = pin_from(JSON.parse_string(line.substr(META.length() - 1).strip_edges()))
		if pin != null and not seen.has(pin.id):
			seen[pin.id] = true
			out.list.append(pin)
	out._order()
	return out


func _order() -> void:
	list.sort_custom(func(a: Pin, b: Pin) -> bool:
		return a.when < b.when or (a.when == b.when and a.id < b.id))


## The lines for the file, each pin where its part stands now.
func lines(world: BrickWorld, lift: Vector3) -> PackedStringArray:
	var out := PackedStringArray()
	for pin: Pin in list:
		find(pin, world, lift)
		out.append(META + JSON.stringify(pin.fields(), "", false))
	return out


## [param text] with [param pin_lines] in the head of its main model, after
## its motions and its floor where it has them, in place of any pin lines it
## had: written the same every time, so a model saved twice is one file.
static func written_into(text: String, pin_lines: PackedStringArray) -> String:
	if pin_lines.is_empty() and not text.contains(META):
		return text
	var kept := PackedStringArray()
	for line: String in text.split("\n"):
		if not line.begins_with(META):
			kept.append(line)
	if pin_lines.is_empty():
		return "\n".join(kept)
	var at: int = -1
	for n: int in kept.size():
		if kept[n].begins_with(Motions.META) or kept[n].begins_with(ModelFloor.META):
			at = n + 1
	if at < 0:
		at = kept.size()
		for n: int in kept.size():
			var line: String = kept[n].strip_edges()
			if n > 0 and (line.is_empty() or line.begins_with("1 ") or line.begins_with("0 FILE")
					or line == "0 STEP" or line.to_upper().begins_with("0 ROTSTEP")):
				at = n
				break
	var head: PackedStringArray = kept.slice(0, at)
	head.append_array(pin_lines)
	head.append_array(kept.slice(at))
	return "\n".join(head)


## [param pin]'s part here: the one it is on while that is still its part,
## else the part of its number and colour nearest where it says (a file
## opened, or the part put back by an undo as another number). Its place and
## colour brought up to the part's as found; 0 when none is.
static func find(pin: Pin, world: BrickWorld, lift: Vector3) -> int:
	var brick: BrickWorld.Brick = world.get_brick(pin.brick) if pin.brick != 0 else null
	if brick == null or brick.part_id != pin.part:
		brick = null
		pin.brick = 0
		var want: Vector3 = pin.at * LdrModel.FLIP + lift
		var nearest: float = PLACE_SLACK
		for one: BrickWorld.Brick in world.bricks():
			if one.part_id != pin.part or one.color_code != pin.colour:
				continue
			var off: float = one.transform.origin.distance_to(want)
			if off < nearest:
				nearest = off
				brick = one
	if brick == null:
		return 0
	pin.brick = brick.id
	var stands: Transform3D = brick.transform if world.broken_out.is_empty() else world.home_of(brick)
	pin.at = (stands.origin - lift) * LdrModel.FLIP
	pin.colour = brick.color_code
	return brick.id


## Where [param pin] is drawn in the world: over the top of its part, or
## where its part was.
static func point_of(pin: Pin, world: BrickWorld, lift: Vector3) -> Vector3:
	var brick: BrickWorld.Brick = world.get_brick(find(pin, world, lift))
	if brick == null:
		return pin.at * LdrModel.FLIP + lift
	var mesh: Lbm.PartMesh = world.library.mesh_for(brick.part_id) if world.library != null else null
	if mesh == null:
		return brick.transform.origin + Vector3(0, ABOVE, 0)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	return Vector3(box.get_center().x, box.end.y + ABOVE, box.get_center().z)


## A new pin on [param brick_id], said by [param by] in [param tint].
func add(brick_id: int, text: String, by: String, tint: String, world: BrickWorld,
		lift: Vector3) -> Pin:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null or text.strip_edges().is_empty():
		return null
	var pin := Pin.new()
	pin.id = new_id()
	pin.brick = brick_id
	pin.part = brick.part_id
	pin.text = text.strip_edges().left(TEXT_MOST)
	pin.by = by.strip_edges().left(NAME_MOST)
	pin.tint = tint
	pin.when = Time.get_datetime_string_from_system(true) + "Z"
	find(pin, world, lift)
	list.append(pin)
	_order()
	return pin


static func new_id() -> String:
	var out: String = ""
	for b: int in Crypto.new().generate_random_bytes(5):
		out += "%02x" % b
	return out


func named(id: String) -> Pin:
	for pin: Pin in list:
		if pin.id == id:
			return pin
	return null


## How many are not resolved.
func open_count() -> int:
	return list.filter(func(pin: Pin) -> bool: return not pin.resolved).size()


# -- the whole set as words, for undo ------------------------------------------

## Every pin as the file has it, one a line: what an undo puts back.
func words(world: BrickWorld, lift: Vector3) -> String:
	return "\n".join(lines(world, lift))


## The set [param said] (as [method words] gave it), in place of this one:
## each pin's part found again by its place.
func set_words(said: String) -> void:
	list = read(said).list


# -- in a session, a pin a key of its own ----------------------------------------

## [param pin] as the session carries it: its part by the session's uid
## ([param uid_of], brick id -> uid or ""), and where it stands only when
## its part has none, so moving a pinned part changes nothing of its pin.
static func session_words(pin: Pin, world: BrickWorld, lift: Vector3, uid_of: Callable) -> String:
	var said: Dictionary = pin.fields()
	var uid: String = str(uid_of.call(find(pin, world, lift)))
	if not uid.is_empty():
		said["uid"] = uid
		said.erase("at")
		said.erase("colour")
	return JSON.stringify(said, "", true)


## The pin [param id] set to [param said] from the session (its part by uid,
## [param brick_of] uid -> brick id or 0), or taken back when it is "".
func put_session_words(id: String, said: String, world: BrickWorld, lift: Vector3,
		brick_of: Callable) -> void:
	var at: int = list.find(named(id))
	if said.is_empty():
		if at >= 0:
			list.remove_at(at)
		return
	var given: Variant = JSON.parse_string(said)
	var pin: Pin = pin_from(given)
	if pin == null or pin.id != id:
		return
	var uid: String = str((given as Dictionary).get("uid", ""))
	if not uid.is_empty():
		var brick: BrickWorld.Brick = world.get_brick(int(brick_of.call(uid)))
		if brick != null:
			pin.brick = brick.id
			pin.part = brick.part_id
			find(pin, world, lift)
		elif at >= 0:
			# Its part not here yet: where it was last seen.
			pin.at = list[at].at
			pin.colour = list[at].colour
	if at >= 0:
		list[at] = pin
	else:
		list.append(pin)
		_order()
