## Find and Replace (Edit › Find and replace…; a session's replace_parts):
## a part, a colour or a part in a colour, found in the selection, in the
## sub-model being edited or everywhere, sub-models and all their copies
## included, said by where it is and in which colours, and replaced with
## another part, another colour or both as one undo step (swapfind, APP_UX8
## #9). StudWorx's, LeoCAD's and Studio's reach the whole model; the hand's
## Replace (EditVerbs.replace) reaches only the selection.
##
## A part is found as it is seen: a copy placed by a mirror shows the other
## hand of a handed part (a left door where its first copy has a right
## one), and that is what it is found as. A sub-model's copies are one
## definition, so a replace inside one changes every copy, as an edit by
## hand does (Assemblies.after_edit): each part found is changed where it
## stands, and the copies follow it, a mirrored one given the other hand of
## the new part where it has one (Assemblies._laid). A part found in a
## mirrored copy whose twin in a copy placed as its definition is (no
## mirror) is found too follows that twin's change rather than taking the
## new part as it is, so the copies stay mirror images. Any the follow does
## not reach are then changed where they stand, in the same undo.
##
## A new part that will not sit as the old one did is said before: another
## footprint or other connection points (its studs, holes, pins and what
## takes a stud), at how many places, and where it would hold onto nothing.
## One with no room is left as it was, and said; a locked part is left too.
## A part in a copy of a sub-model goes with its twin in every other copy,
## each laid where the copies' follow lays it: where one of them has no room
## for the new part, or is locked, all of them stay, and that is said ("Pl
## has no room in 1 of its 2 copies, so all 2 stay"). A follow that some copy
## cannot take takes back the whole edit (Assemblies.copies_follow, by the
## same lock rule, Assemblies.locked_twins), so a replace leaves out ahead
## of it each part it cannot change in all of its copies, and changes the
## rest (swreview F1, F3).
class_name FindReplace
extends RefCounted

## Where to look: the selection, the sub-model being edited with every copy
## of it, or the whole model.
const WHERE: Array[String] = ["selection", "submodel", "all"]

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var assemblies: Assemblies
var scenery: Dictionary = {}
## An edit by hand made: what the app does after one, the copies following
## among it (Main._on_model_edited).
var edited: Callable = func() -> void: pass


func _init(app: Node = null) -> void:
	if app == null:
		return
	world = app.get("_world")
	builder = app.get("_builder")
	library = app.get("_library")
	var store: ModelStore = app.get("_store")
	scenery = store.scenery if store != null else {}
	var verbs: EditVerbs = app.get("_verbs")
	assemblies = verbs.assemblies if verbs != null else null
	edited = Callable(app, &"_on_model_edited")


# -- finding ------------------------------------------------------------------


## Every part [param asked] names ({"part": a number, or "" for any;
## "color": an LDraw code, or -1 for any}) in [param where] (WHERE), as it
## is seen: {"ids": each found, in the world's order; "mirrored": those in a
## copy a mirror places, id -> true; "follow": of those, the ones whose twin
## in a copy placed as its definition is was found too, id -> true; "part":
## the number asked; "parts": each number found -> how many; "colours": each
## colour found -> how many; "places": [{"name": a sub-model's, or "" for
## the model's own parts, "count", "copies": how many copies the model has
## of it}], the model first, then by name; "locked": how many found are
## locked, and left out, "locked_ids" which; "where", "inside": the
## sub-model being edited ("" for the model)}.
func find(asked: Dictionary, where: String) -> Dictionary:
	var looked: Array = looked_in(where)
	return find_among(looked, asked, where, _frames_for(looked))


## The parts [method find] looks among in [param where], as it stands now.
func looked_in(where: String) -> Array:
	return _looked_in(where, assemblies.entered if assemblies != null else "")


## [method find]'s answer over [param looked] (bricks) alone, its copies'
## frames [param frames] ([method _frames_for] of them, or of more): what a
## caller that knows its parts asks, with no look over the whole model
## (OwnSwap's lots, osreview H3: two looks a lot were 220 + 254 ms on
## Orthanc).
## [param copies] is [method _copies_by_definition]'s where the caller has it
## (it reads every part of the model: 20 ms a lot on Orthanc).
func find_among(looked: Array, asked: Dictionary, where: String, frames: Dictionary,
		copies: Variant = null) -> Dictionary:
	var part: String = str(asked.get("part", "")).strip_edges()
	var colour: int = int(asked.get("color", -1))
	var inside: String = assemblies.entered if assemblies != null else ""
	var out: Dictionary = {"ids": [], "mirrored": {}, "follow": {}, "part": part, "parts": {},
		"colours": {}, "places": [], "locked": 0, "locked_ids": [], "where": where,
		"inside": inside}
	var by_def: Dictionary = {}
	for brick: BrickWorld.Brick in looked:
		var path: String = Assemblies.path_of(brick)
		if colour >= 0 and brick.color_code != colour:
			continue
		if not part.is_empty() and not same_part(brick.part_id, part):
			continue
		if builder.is_locked(brick.id):
			out["locked"] = int(out["locked"]) + 1
			(out["locked_ids"] as Array).append(brick.id)
			continue
		# Not on at the step the timeline shows: left out and counted, as
		# every edit there reaches only what is on show (Builder.shown_only).
		if builder.is_ahead(brick.id):
			out["later"] = int(out.get("later", 0)) + 1
			continue
		(out["ids"] as Array).append(brick.id)
		if not _mirror_of(path, frames).is_empty():
			(out["mirrored"] as Dictionary)[brick.id] = true
		var parts: Dictionary = out["parts"]
		parts[brick.part_id] = int(parts.get(brick.part_id, 0)) + 1
		var colours: Dictionary = out["colours"]
		colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
		var def: String = "" if path.is_empty() else Assemblies.definition(Assemblies.leaf(path))
		by_def[def] = int(by_def.get(def, 0)) + 1
	out["follow"] = _twins_found(out["mirrored"], out["ids"], frames)
	var counted: Dictionary = {} if by_def.keys().all(func(def: String) -> bool: return def.is_empty()) \
		else copies if copies is Dictionary else _copies_by_definition()
	var names: Array = by_def.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return a.is_empty() or (not b.is_empty() and a.naturalnocasecmp_to(b) < 0))
	for def: String in names:
		(out["places"] as Array).append({"name": def, "count": int(by_def[def]),
			"copies": int(counted.get(def, 1))})
	return out


## The parts [param where] covers, scenery left out: the selection's; the
## sub-model at [param inside] and every copy of it, all inside them too, or
## for the model itself its own parts, none in a sub-model; or every part.
func _looked_in(where: String, inside: String) -> Array:
	var out: Array = []
	match where:
		"selection":
			for brick_id: int in builder.selection:
				var brick: BrickWorld.Brick = world.get_brick(brick_id)
				if brick != null and not scenery.has(brick_id):
					out.append(brick)
		"submodel":
			if inside.is_empty():
				for brick: BrickWorld.Brick in world.bricks():
					if not scenery.has(brick.id) and Assemblies.path_of(brick).is_empty():
						out.append(brick)
			else:
				var paths: Array = [inside]
				paths.append_array(Array(assemblies.copies_of(inside)))
				for path: String in paths:
					out.append_array(assemblies.bricks_under(path))
		_:
			for brick: BrickWorld.Brick in world.bricks():
				if not scenery.has(brick.id):
					out.append(brick)
	return out


## Whether part [param found] is the part [param asked] names: the same
## number, as the library has it (a number moved, as the one it moved to),
## or [param asked] a mould's number and [param found] a letter after it
## (3023 finds 3023a and 3023b, as BrickLink lists them one part).
func same_part(found: String, asked: String) -> bool:
	var a: String = asked.to_lower()
	if found == a or library.resolve(found) == library.resolve(a):
		return true
	return found.length() == a.length() + 1 and found.begins_with(a) \
		and found.right(1) >= "a" and found.right(1) <= "z" and a.right(1) >= "0" \
		and a.right(1) <= "9"


## The part [param part_id] stands for in its definition: the other hand of
## the one a mirror placed, where it has one.
func _as_defined(part_id: String, mirrored: bool) -> String:
	if not mirrored:
		return part_id
	var other: String = Later.script(&"Mirror").counterpart(library, part_id)
	return part_id if other.is_empty() else other


## Each copy as the save writes it (Assemblies.file_frames, kept until the
## model changes: Assemblies.frames_now), where any of [param bricks] is in a
## copy of a sub-model the model has more than one of; {} otherwise, and for
## the selection, which is changed as a hand changes it.
func _frames_for(bricks: Array, counted: Variant = null) -> Dictionary:
	return assemblies.frames_now() if _wants_frames(bricks, counted) else {}


## [method _frames_for], worked out a slice of a frame at a time where they
## are not kept already (Assemblies.frames_paced), the status bar saying so.
func frames_paced_for(bricks: Array, counted: Variant = null) -> Dictionary:
	if not _wants_frames(bricks, counted):
		return {}
	return await assemblies.frames_paced(FRAMES_WORDS)


## Whether [method find] in [param where] has its copies' frames to hand, or
## needs none: when not, [method frames_paced_for] of [method looked_in]
## makes them so.
func frames_ready(where: String) -> bool:
	return assemblies == null or assemblies.frames_current() or not _wants_frames(looked_in(where))


const FRAMES_WORDS := "Reading how the model's copies are placed…"


func _wants_frames(bricks: Array, counted: Variant = null) -> bool:
	if assemblies == null:
		return false
	var copies: Dictionary = counted if counted is Dictionary else _copies_by_definition()
	for brick: BrickWorld.Brick in bricks:
		var path: String = Assemblies.path_of(brick)
		if path.is_empty():
			continue
		for segment: String in Assemblies.segments(path):
			if int(copies.get(Assemblies.definition(segment), 1)) > 1:
				return true
	return false


## The copy that mirrors a part at [param path]: the innermost of it and the
## copies round it whose frame, as [param frames] (Assemblies.file_frames)
## writes it, is a mirror, when an odd number of them are; "" when the part
## stands as its definition has it (a mirror inside a mirror is none). A
## Sill inside the Side a mirror places is mirrored by that Side's frame.
static func _mirror_of(path: String, frames: Dictionary) -> String:
	if path.is_empty() or frames.is_empty():
		return ""
	var at: String = ""
	var innermost: String = ""
	var odd: bool = false
	for segment: String in Assemblies.segments(path):
		at = Assemblies.join(at, segment)
		var entry: Variant = frames.get(at)
		if entry is Dictionary and ((entry as Dictionary).get("frame", Transform3D.IDENTITY)
				as Transform3D).basis.determinant() < 0.0:
			odd = not odd
			innermost = at
	return innermost if odd else ""


## Of the [param mirrored] parts found, those whose twin in a copy placed
## as its definition is (Assemblies.counterparts) is among [param ids] too:
## id -> the twin's. Each follows its twin's change. One whose twin was not
## found is changed itself, and the twin follows it.
func _twins_found(mirrored: Dictionary, ids: Array, frames: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if mirrored.is_empty():
		return out
	var wanted: Dictionary = {}
	for brick_id: int in ids:
		wanted[brick_id] = true
	var maps: Dictionary = {}
	for brick_id: int in mirrored:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var copy: String = _mirror_of(Assemblies.path_of(brick), frames)
		if not maps.has(copy):
			var twins: Array = []
			for other: String in assemblies.copies_of(copy):
				if _mirror_of(other, frames).is_empty():
					twins.append(assemblies.counterparts(copy, other))
			maps[copy] = twins
		for twins: Dictionary in maps[copy]:
			if wanted.has(int(twins.get(brick_id, -1))):
				out[brick_id] = int(twins[brick_id])
				break
	return out


## How many copies the model has of each sub-model, by its name.
func _copies_by_definition() -> Dictionary:
	var out: Dictionary = {}
	if assemblies == null:
		return out
	for path: String in assemblies.paths():
		var def: String = Assemblies.definition(Assemblies.leaf(path))
		out[def] = int(out.get(def, 0)) + 1
	return out


# -- what it would be -----------------------------------------------------------


## What each part of [param found] would be given [param into] ({"part": a
## number or "" for its own, "color": a code or -1 for its own}), each with
## its twins in every other copy of its sub-model, laid where the copies'
## follow lays them ([method _twins]): all of them change, or all stay. {
## "changes": [{"brick", "part", "color", "at"}] for those changed where they
## stand; "follow": the ids found left to follow their copy; "followers":
## the ids not found that change as their copy follows; "same": how many
## found are that already; "room": the ids found with no room for it;
## "held": the ids found with room that stay with a twin that has none;
## "locked": the ids found that stay with a twin that is locked; "stays":
## each part with copies that stays, {"name": its sub-model's, "copies": how
## many parts it and its twins are, "room": how many of them have no room,
## "locked": how many are locked, "ids": them all}; "otherwise": the ids
## found where it will not sit as the old one did (another footprint, other
## connection points); "floats": of those, the ids where it would hold onto
## nothing that held the old one; "missing": the part's number when its
## shape is not here}. Each found part is counted once: changed (with
## "follow"), "same", "room", "held" or "locked". [param cache] keeps the
## copies and how they lie on each other across plans of one model as it
## stands (OwnSwap plans each lot, and each copy group, of one model).
func plan(found: Dictionary, into: Dictionary, cache: Dictionary = {}) -> Dictionary:
	var part: String = str(into.get("part", "")).strip_edges()
	var colour: int = int(into.get("color", -1))
	var out: Dictionary = {"changes": [], "follow": [], "followers": [], "same": 0, "room": [],
		"held": [], "locked": [], "stays": [], "otherwise": [], "floats": [], "missing": ""}
	var following: Dictionary = found.get("follow", {})
	# Each found part that changes, as it would be where it stands.
	var moving: Dictionary = {}      ## id -> {"part", "color", "at", "follows"}
	var order: Array = []
	for brick_id: int in found["ids"]:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		# One a mirror places whose twin changes too follows the twin,
		# wherever that puts it, given the other hand of the new part.
		var follows: bool = following.has(brick_id)
		var new_part: String = brick.part_id
		if not part.is_empty():
			new_part = _as_defined(part, follows)
		var new_colour: int = brick.color_code if colour < 0 else colour
		if new_part == brick.part_id and new_colour == brick.color_code:
			out["same"] = int(out["same"]) + 1
			continue
		var at: Transform3D = brick.transform
		if new_part != brick.part_id:
			var shape: Lbm.PartMesh = library.mesh_for(new_part)
			if shape == null:
				out["missing"] = new_part
				continue
			at = builder.swap_place(brick, new_part, shape)
		moving[brick_id] = {"part": new_part, "color": new_colour, "at": at, "follows": follows}
		order.append(brick_id)
	# Each with its twins: those found, and those its copies' follow reaches.
	var joined: Dictionary = {}      ## id -> the id it is grouped under
	var reached: Dictionary = {}     ## a twin -> [the found part it follows, the copies' fit]
	if assemblies != null and not order.is_empty():
		if not cache.has("copies"):
			cache["copies"] = _copies_by_definition()
			cache["matches"] = {}
			cache["copied"] = {}
		var copies: Dictionary = cache["copies"]
		var matches: Dictionary = cache["matches"]
		var copied: Dictionary = cache["copied"]
		assemblies._begin_pass()
		for brick_id: int in order:
			if bool(moving[brick_id]["follows"]):
				_join(joined, brick_id, int(following[brick_id]))
				continue
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			var swaps: bool = str(moving[brick_id]["part"]) != brick.part_id
			for twin: Array in _twins(brick, copies, copied, matches):
				var other: BrickWorld.Brick = world.get_brick(int(twin[0]))
				if other == null:
					continue
				var direct: bool = moving.has(other.id) and not bool(moving[other.id]["follows"])
				# A paint follows only into a part the colour it was (a copy
				# placed in another colour keeps its own); a swap, into each.
				if not direct and not swaps and other.color_code != brick.color_code:
					continue
				_join(joined, brick_id, other.id)
				if not direct and not reached.has(other.id):
					reached[other.id] = [brick_id, twin[1]]
		assemblies._end_pass()
	var members: Dictionary = {}     ## the id grouped under -> every id in the group
	var groups: Array = []
	for brick_id: int in order + reached.keys():
		var root: int = _root(joined, brick_id)
		if not members.has(root):
			members[root] = []
			groups.append(root)
		if not (members[root] as Array).has(brick_id):
			(members[root] as Array).append(brick_id)
	# Each group as a whole: locked, without room, or changed.
	var sel: Variant = Later.script(&"SelectBy")
	var taken: Dictionary = {}       ## the new parts' places so far, by bucket
	for root: int in groups:
		var group: Array = members[root]
		# One rule with the copies' follow (Assemblies.locked_twins): a part
		# locked in one copy holds its twins in every other.
		var locked: int = assemblies.locked_twins(group).size() if assemblies != null \
			else group.filter(func(brick_id: int) -> bool: return builder.is_locked(brick_id)).size()
		var laid: Dictionary = {}    ## id -> [its new part, where]
		for brick_id: int in group:
			laid[brick_id] = _laid_as(brick_id, moving, reached)
		var no_room: Array = []
		var boxes: Dictionary = {}
		if locked == 0:
			for brick_id: int in group:
				var brick: BrickWorld.Brick = world.get_brick(brick_id)
				var new: Array = laid[brick_id]
				if brick == null or str(new[0]) == brick.part_id:
					continue
				var shape: Lbm.PartMesh = library.mesh_for(str(new[0]))
				if shape == null:
					out["missing"] = str(new[0])
					no_room.append(brick_id)
					continue
				var packed: PackedInt32Array = builder.boxes_for(shape, new[1])
				boxes[brick_id] = packed
				if not builder.has_room_swapped(brick, str(new[0]), new[1], packed) \
						or _meets_taken(packed, taken, brick_id, builder.lattice):
					no_room.append(brick_id)
		if locked > 0 or not no_room.is_empty():
			for brick_id: int in group:
				if not moving.has(brick_id):
					continue
				var why: String = "locked" if locked > 0 else ("room" if no_room.has(brick_id)
					else "held")
				(out[why] as Array).append(brick_id)
			if group.size() > 1:
				(out["stays"] as Array).append({"name": _sub_model_of(group[0]),
					"copies": group.size(), "room": no_room.size(), "locked": locked,
					"ids": group})
			continue
		for brick_id: int in boxes:
			_take(boxes[brick_id], taken, brick_id)
		for brick_id: int in group:
			if not moving.has(brick_id):
				(out["followers"] as Array).append(brick_id)
				continue
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			var new: Array = laid[brick_id]
			if str(new[0]) != brick.part_id:
				var was: Lbm.PartMesh = library.mesh_for(brick.part_id)
				var shape: Lbm.PartMesh = library.mesh_for(str(new[0]))
				if not _sits_alike(was, brick.transform, shape, new[1]):
					(out["otherwise"] as Array).append(brick_id)
					var held: Array = sel._joined_to(world, builder.lattice, brick_id)
					if not held.is_empty() \
							and _held_by(boxes[brick_id], brick_id, new[1], sel).is_empty():
						(out["floats"] as Array).append(brick_id)
			if bool(moving[brick_id]["follows"]):
				(out["follow"] as Array).append(brick_id)
			else:
				(out["changes"] as Array).append({"brick": brick_id,
					"part": moving[brick_id]["part"], "color": moving[brick_id]["color"],
					"at": moving[brick_id]["at"]})
	# In the order found, as the hand's Replace lays them.
	var at_found: Dictionary = {}
	for n: int in order.size():
		at_found[order[n]] = n
	(out["changes"] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(at_found[int(a["brick"])]) < int(at_found[int(b["brick"])]))
	return out


## [param brick_id]'s new part and place: where it stands for a part found
## and changed there, else where the copies' follow lays it from the twin it
## follows ([param reached]), as Assemblies._laid lays it.
func _laid_as(brick_id: int, moving: Dictionary, reached: Dictionary) -> Array:
	var source: Array = reached.get(brick_id, [])
	if source.is_empty() or not moving.has(int(source[0])):
		if moving.has(brick_id):
			return [str(moving[brick_id]["part"]), moving[brick_id]["at"]]
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		return [brick.part_id, brick.transform] if brick != null else ["", Transform3D.IDENTITY]
	var from: Dictionary = moving[int(source[0])]
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var from_brick: BrickWorld.Brick = world.get_brick(int(source[0]))
	if brick != null and from_brick != null and str(from["part"]) == from_brick.part_id:
		return [brick.part_id, brick.transform]
	return assemblies._laid(source[1], str(from["part"]), from["at"])


## The parts every other copy holds of [param brick], each of which the
## copies' follow changes as it is changed (Assemblies.copies_follow): for
## each copy round it, innermost first, every other copy of that sub-model
## that lies on it part for part, and the part there that lies on this one,
## [[its id, how the copy lies on the other (Assemblies.best_match)]].
## [param copied] keeps each copy's others, [param matches] each pair of
## copies laid on each other once ({} where they do not lie part for part).
func _twins(brick: BrickWorld.Brick, copies: Dictionary, copied: Dictionary,
		matches: Dictionary) -> Array:
	var out: Array = []
	var path: String = Assemblies.path_of(brick)
	if path.is_empty():
		return out
	var rounds: Array = []
	var at: String = ""
	for segment: String in Assemblies.segments(path):
		at = Assemblies.join(at, segment)
		rounds.push_front(at)
	for copy: String in rounds:
		if int(copies.get(Assemblies.definition(Assemblies.leaf(copy)), 1)) < 2:
			continue
		if not copied.has(copy):
			copied[copy] = assemblies.copies_of(copy)
		for other: String in copied[copy]:
			var key: String = copy + "|" + other
			if not matches.has(key):
				matches[key] = _copy_on(copy, other)
			var lain: Dictionary = matches[key]
			if not lain.is_empty() and (lain["pairs"] as Dictionary).has(brick.id):
				out.append([int((lain["pairs"] as Dictionary)[brick.id]), lain["fit"]])
	return out


## How the copy at [param copy] lies on the one at [param other], part for
## part, as the copies' follow lays one on the other: {"fit", "pairs": each
## part of the one -> the part of the other it lies on}, {} where they do
## not lie on each other part for part (the follow passes them by).
func _copy_on(copy: String, other: String) -> Dictionary:
	var was: Array = assemblies.content(copy)
	var twin: Array = assemblies.content(other)
	if was.is_empty() or twin.size() != was.size():
		return {}
	var fit: Dictionary = assemblies.best_match(was, twin)
	if int(fit["score"]) != was.size():
		return {}
	var pairs: Dictionary = assemblies._laid_on(was, twin, fit)
	return {"fit": fit, "pairs": pairs} if pairs.size() == was.size() else {}


## [param a] and [param b] put in one group of [param joined].
static func _join(joined: Dictionary, a: int, b: int) -> void:
	var one: int = _root(joined, a)
	var two: int = _root(joined, b)
	if one != two:
		joined[two] = one


static func _root(joined: Dictionary, brick_id: int) -> int:
	var at: int = brick_id
	while joined.has(at) and int(joined[at]) != at:
		at = int(joined[at])
	if at != brick_id:
		joined[brick_id] = at
	return at


## The sub-model [param brick_id] is in, by its name.
func _sub_model_of(brick_id: int) -> String:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	var path: String = Assemblies.path_of(brick) if brick != null else ""
	return "" if path.is_empty() else Assemblies.definition(Assemblies.leaf(path))


## Whether [param packed], the new part for [param brick_id], meets a new
## part's place kept in [param taken]: two parts a replace puts down that
## would run into each other, though each has room as the model stands.
## With [param lattice], not where the two old parts meet each other where
## they stand, as the room test excuses what the old part met
## (Builder.has_room_swapped): 6632's two clips back to back, each swapped
## for a newer clip.
static func _meets_taken(packed: PackedInt32Array, taken: Dictionary, brick_id: int = 0,
		lattice: BrickLattice = null) -> bool:
	for key: Vector3i in _buckets(packed):
		for other: Array in taken.get(key, []):
			if BrickLattice.shared_cells(packed, other[0]) <= 0:
				continue
			if lattice == null or lattice.meeting_of(lattice.boxes_of(brick_id), [other[1]],
					brick_id).is_empty():
				return true
	return false


static func _take(packed: PackedInt32Array, taken: Dictionary, brick_id: int = 0) -> void:
	for key: Vector3i in _buckets(packed):
		if not taken.has(key):
			taken[key] = []
		(taken[key] as Array).append([packed, brick_id])


## The buckets of 20 cells each way [param packed]'s bound reaches.
static func _buckets(packed: PackedInt32Array) -> Array:
	var out: Array = []
	if packed.is_empty():
		return out
	var bound: PackedInt32Array = BrickLattice._bound_of(packed)
	for x: int in range(floori(bound[0] / 20.0), floori((bound[3] - 1) / 20.0) + 1):
		for y: int in range(floori(bound[1] / 20.0), floori((bound[4] - 1) / 20.0) + 1):
			for z: int in range(floori(bound[2] / 20.0), floori((bound[5] - 1) / 20.0) + 1):
				out.append(Vector3i(x, y, z))
	return out


## Whether [param shape] at [param to] sits as [param was] at [param at]
## does: the same box and the same connection points, each of its kind and
## way, to a tenth of an LDU.
func _sits_alike(was: Lbm.PartMesh, at: Transform3D, shape: Lbm.PartMesh,
		to: Transform3D) -> bool:
	if was == null or (at * was.bounds).abs().position.distance_to((to * shape.bounds).abs().position) > 1.0 \
			or (at * was.bounds).abs().size.distance_to((to * shape.bounds).abs().size) > 1.0:
		return false
	return _points(was, at) == _points(shape, to)


## A part's connection points standing at [param at], each its kind, its
## gender, where and which way, sorted: what another part holds it by.
static func _points(shape: Lbm.PartMesh, at: Transform3D) -> PackedStringArray:
	var out := PackedStringArray()
	for point: Lbm.Connector in shape.connectors:
		var where: Vector3 = (at * point.position).snapped(Vector3.ONE * 0.1)
		var way: Vector3 = (at.basis * point.axis).snapped(Vector3.ONE * 0.01)
		out.append("%s|%s|%s|%s" % [point.kind, point.gender, where, way])
	for socket: Vector2 in shape.sockets:
		out.append("socket|%s" % (at * Vector3(socket.x, 0.0, socket.y)).snapped(Vector3.ONE * 0.1))
	out.sort()
	return out


## What a part covering [param packed] at [param at] would be held to, as
## SelectBy._joined_to asks of a part down: what rests on it or carries it,
## and across a side its studs point through, or another part's do.
func _held_by(packed: PackedInt32Array, self_id: int, at: Transform3D, sel: Variant) -> Array:
	var out: Dictionary = {}
	for other: int in builder.lattice.blockers_boxes(sel._shell(packed, 1), self_id):
		out[other] = true
	var face: String = BrickLattice.face_of(at.basis)
	var own: int = 0 if face in ["+x", "-x"] else (2 if face in ["+z", "-z"] else -1)
	for axis: int in [0, 2]:
		for other: int in builder.lattice.blockers_boxes(sel._shell(packed, axis), self_id):
			if own == axis or sel._stud_axis(world, other) == axis:
				out[other] = true
	return out.keys()


# -- replacing ------------------------------------------------------------------


## [param found] made [param into] as one undo step, each copy of a sub-model
## following as an edit by hand makes it (see the class's words), the step
## said by what changed once the copies have followed: {"changed": how many
## parts changed, those the copies' follow changed too; "followed": how many
## of them were not found, changed as their copy followed; "room": how many
## found stay for want of room, in their own copy or a twin's; "locked": how
## many found stay with a locked twin; "same": how many found were that
## already; "words": the step's own; "stayed": what stayed, said
## ([method stay_words])}. Each found part is counted once. [param made]: its
## [method plan] made as the model stands now (the bar's, made as it showed
## it), else made here; on 10179 a plan is 0.4 s.
func replace(found: Dictionary, into: Dictionary, made: Dictionary = {}) -> Dictionary:
	return replace_all([{"found": found, "into": into, "made": made}])[0]


## [method replace] for each of [param jobs] ({"found", "into", "made": its
## plan, or {} to make it here}) at once: one change of the model and one
## undo step, the copies following it once, where a replace a job was one
## each (OwnSwap's lots, osreview H3: each lot's own replace held a frame
## for 254 ms on Orthanc). Every plan is made as the model stands before
## any of them changes it, so no two jobs may change one part. Each job's
## answer as replace's, in their order; the step said by [param words], or
## for one job by what it changed.
func replace_all(jobs: Array, words: String = "") -> Array:
	var out: Array = []
	# A part lifted and still in hand goes back where it was first (rsfix,
	# rsreview F5): this step laid over its lift left Escape nothing to put
	# it back from, and it was lost, live since swapfind.
	if put_back_held() < 0:
		for _job: Dictionary in jobs:
			out.append({"changed": 0, "followed": 0, "room": 0, "locked": 0, "same": 0,
				"words": "", "stayed": HELD_WORDS})
		return out
	var changes: Array = []
	var was: Array = []              ## a job's: id -> [its part, its colour] before
	var paths: Dictionary = {}       ## a follower -> its copy's path
	for job: Dictionary in jobs:
		if (job.get("made", {}) as Dictionary).is_empty():
			job["made"] = plan(job["found"], job["into"])
		var before: Dictionary = {}
		for brick_id: int in job["found"]["ids"] + job["made"]["followers"]:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null:
				before[brick_id] = [brick.part_id, brick.color_code]
				paths[brick_id] = Assemblies.path_of(brick)
		was.append(before)
		changes.append_array(job["made"]["changes"])
	if jobs.is_empty():
		return out
	var depth: int = builder.history_depth()
	var step: String = words if not words.is_empty() else step_words(jobs[0]["found"], jobs[0]["into"])
	var done: Vector2i = builder.replace_bricks(changes, step)
	if done.x > 0:
		edited.call()
	# Those in a copy a mirror places that their twin's follow did not reach,
	# changed where they stand.
	var more: Array = []
	for n: int in jobs.size():
		var found: Dictionary = jobs[n]["found"]
		var left := PackedInt64Array()
		var twin_of: Dictionary = found.get("follow", {})
		for brick_id: int in jobs[n]["made"]["follow"]:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			var twin: BrickWorld.Brick = world.get_brick(int(twin_of.get(brick_id, -1)))
			var twin_changed: bool = twin == null or not was[n].has(twin.id) \
				or was[n][twin.id] != [twin.part_id, twin.color_code]
			if brick != null and twin_changed and was[n][brick_id] == [brick.part_id, brick.color_code]:
				left.append(brick_id)
		if left.is_empty():
			continue
		var rest: Dictionary = found.duplicate()
		rest["ids"] = Array(left)
		rest["follow"] = {}
		var mirrored_into: Dictionary = (jobs[n]["into"] as Dictionary).duplicate()
		if not str(mirrored_into.get("part", "")).is_empty():
			mirrored_into["part"] = _as_defined(str(mirrored_into["part"]), true)
		more.append_array(plan(rest, mirrored_into)["changes"])
	if not more.is_empty() and builder.replace_bricks(more, step).x > 0:
		edited.call()
	builder.fold_since(depth)
	if assemblies != null:
		assemblies.no_copies_follow()
	# What changed, each part once, the copies' follow included.
	for n: int in jobs.size():
		var found: Dictionary = jobs[n]["found"]
		var made: Dictionary = jobs[n]["made"]
		var found_ids: Dictionary = {}
		for brick_id: int in found["ids"]:
			found_ids[brick_id] = true
		var gone: Array = []             ## [its part, its colour, found] of each changed
		var followed: Dictionary = {}    ## a sub-model -> how many changed in its copies, not found
		for brick_id: int in was[n]:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null and was[n][brick_id] == [brick.part_id, brick.color_code]:
				continue
			gone.append(was[n][brick_id])
			if not found_ids.has(brick_id):
				var name: String = Assemblies.definition(Assemblies.leaf(str(paths[brick_id])))
				followed[name] = int(followed.get(name, 0)) + 1
		var stayed: int = (found["ids"] as Array).size() - int(made["same"]) \
			- (made["locked"] as Array).size() - gone.size() + _sum(followed)
		out.append({"changed": gone.size(), "followed": _sum(followed),
			"room": maxi(stayed, 0), "locked": (made["locked"] as Array).size(),
			"same": int(made["same"]), "words": changed_words(found, jobs[n]["into"], gone, followed),
			"stayed": "; ".join(stay_words(found, made))})
	if builder.history_depth() > depth:
		builder.name_newest(words if not words.is_empty() else str(out[0]["words"]))
	return out


## Why nothing is replaced while a part is in hand that cannot go back.
const HELD_WORDS := "a part is in hand and cannot go back where it was: put it down or press Escape first"


## The parts lifted off the model and still in hand put back where they were,
## as Escape puts them, before a replace: how many went back, 0 for none in
## hand (a part from the bin or a paste stays in hand, as the model has not
## got it), -1 for a lift another step has been laid over since, which
## Escape would put away rather than back.
func put_back_held() -> int:
	if builder == null or not builder.is_carrying() or not builder.carrying.lifted:
		return 0
	if not builder._lift_on_top():
		return -1
	var count: int = builder.carrying.items.size()
	builder.cancel_carry()
	return count


static func _sum(counts: Dictionary) -> int:
	var total: int = 0
	for key: Variant in counts:
		total += int(counts[key])
	return total


# -- what is asked ------------------------------------------------------------------


## The colour [param asked] names: an LDraw code, a direct colour as a file
## writes one (0x2RRGGBB, LdrModel.is_direct_colour), as a number or in
## those words, or a name as the bin's colour find reads one ("Dark Bluish
## Grey", "dark bluish gray"); -1 for none asked, -2 for one there is no
## such colour (-5 among them).
func colour_of(asked: Variant) -> int:
	if asked == null:
		return -1
	var code: int = -2
	if asked is int or asked is float:
		code = int(asked)
	else:
		var said: String = str(asked).strip_edges()
		if said.is_empty():
			return -1
		if said.to_lower().begins_with("0x") and said.substr(2).is_valid_hex_number():
			code = said.substr(2).hex_to_int()
		elif said.is_valid_int():
			code = said.to_int()
		else:
			var named: Array = PartsBin.colours_named(library, said)
			return (named[0] as PartLibrary.BrickColor).code if not named.is_empty() else -2
	if code == -1:
		return -1
	return code if library.colors.has(code) or LdrModel.is_direct_colour(code) else -2


## Why [param code] cannot be given to a part, in words a session acts on;
## "" when it can. 16 and 24 are no colour of a part's own: 16 is the colour
## a sub-model is placed in, which its parts of 16 take, and 24 the colour
## of a part's edges (swreview F5).
static func not_a_part_colour(code: int) -> String:
	var instead: String = "give a part's own colour code (0 Black, 72 Dark Bluish Grey), " \
		+ "or leave color out to keep each part's own."
	match code:
		16:
			return "Colour 16 is no colour of a part's own: it is the colour a sub-model is " \
				+ "placed in. Instead, " + instead
		24:
			return "Colour 24 is the colour of a part's edges, not of a part. Instead, " + instead
	return ""


## The part [param asked] names, as the library has it: its number, or the
## part a search of its words finds first; "" for none. The bar says which
## before it puts one in ("Puts in: Brick 1 x 2 (3004)").
func part_of(asked: String) -> String:
	var said: String = asked.strip_edges().to_lower().trim_suffix(".dat")
	if said.is_empty():
		return ""
	if library.parts.has(said):
		return library.resolve(said)
	var found: Array = library.search(said, 1)
	return (found[0] as PartLibrary.PartInfo).id if not found.is_empty() else ""


## The part [param asked] is by its number alone, as the library has it
## (3069 is 3069b, where the library moved it); "" where it has no part of
## that number. A session's replace_parts takes only this: a search's
## guess put a part in it never asked for ("3023x" made 3023b, swreview F4).
func known_part(asked: String) -> String:
	var said: String = asked.strip_edges().to_lower().trim_suffix(".dat")
	return library.resolve(said) if not said.is_empty() and library.parts.has(said) else ""


## The shape of [param part_id], fetched first where it is not here (the
## web fetches what it has not got); null when it cannot be had in 20 s.
func shape(part_id: String) -> Lbm.PartMesh:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh != null or not library.parts.has(part_id):
		return mesh
	library.want([part_id], true)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var until: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until:
		await tree.process_frame
		mesh = library.mesh_for(part_id)
		if mesh != null:
			return mesh
	return null


## What a replace of [param found] with [param into] will do that the
## person should hear first, once the new part's shape is here: where it
## will not sit as the old one did, would hold onto nothing, has no room, or
## stays with a twin in another copy ([method fit_words]); "" when every one
## changes and sits as the old one did.
func ahead(found: Dictionary, into: Dictionary) -> String:
	var part: String = str(into.get("part", ""))
	if not part.is_empty():
		if await shape(part) == null:
			return "%s's shape could not be had, so nothing of it can be put down." % part
		# Its other hand too, which a copy a mirror places is given.
		var other: String = Later.script(&"Mirror").counterpart(library, part)
		if not other.is_empty():
			await shape(other)
	var made: Dictionary = plan(found, into)
	var fit: String = fit_words(found, made)
	var said := PackedStringArray()
	if not fit.is_empty():
		said.append("It " + fit + ".")
	for line: String in stay_words(found, made, false):
		said.append(line + ".")
	return " ".join(said)


# -- words ------------------------------------------------------------------------


## What [param found] is, as the bar and a session read it: "Found 4 Black
## Plate 1 x 2 (3023b) everywhere: 2 in the model's own parts; 2 in Sill (2
## copies, 1 each)." with its colours and the flag for more than one.
func listed(found: Dictionary) -> String:
	var count: int = (found["ids"] as Array).size()
	if count == 0:
		var none: String = "Found nothing like that %s." % where_words(found)
		if int(found["locked"]) > 0:
			none += " %d locked %s left out: unlock to change them." % [int(found["locked"]),
				"part is" if int(found["locked"]) == 1 else "parts are"]
		if int(found.get("later", 0)) > 0:
			none += " %d in later steps left out." % int(found["later"])
		return none
	var places := PackedStringArray()
	for place: Dictionary in found["places"]:
		places.append(place_words(place))
	var numbers := PackedStringArray()
	for part: String in found["parts"]:
		numbers.append(part)
	var said: String = "Found %s (%s) %s: %s." % [found_words(found), ", ".join(numbers),
		where_words(found), "; ".join(places)]
	var flag: String = colours_flag(found)
	if not flag.is_empty():
		said += " It is " + flag + "."
	elif not (found["colours"] as Dictionary).is_empty():
		said += " All in %s." % colour_name(int((found["colours"] as Dictionary).keys()[0]))
	if int(found["locked"]) > 0:
		said += " %d locked left out." % int(found["locked"])
	if int(found.get("later", 0)) > 0:
		said += " %d in later steps left out." % int(found["later"])
	return said


## "2 in the model's own parts", "4 in Wheel (4 copies, 1 each)".
static func place_words(place: Dictionary) -> String:
	var count: int = int(place["count"])
	var copies: int = int(place["copies"])
	var name: String = str(place["name"])
	var where: String = "the model's own parts" if name.is_empty() else name
	if copies <= 1:
		return "%d in %s" % [count, where]
	return "%d in %s (%d copies%s)" % [count, where, copies,
		", %d each" % (count / copies) if count % copies == 0 else ""]


## What the undo step says: "replaced 12 Black Plate 1 x 2 with Dark Bluish
## Grey everywhere".
func step_words(found: Dictionary, into: Dictionary) -> String:
	return "replaced %s with %s %s" % [found_words(found), into_words(into),
		where_words(found)]


## "12 Black Plate 1 x 2", "12 Plate 1 x 2", "12 Black parts".
func found_words(found: Dictionary) -> String:
	var count: int = (found["ids"] as Array).size()
	var colours: Dictionary = found["colours"]
	var colour: String = colour_name(int(colours.keys()[0])) + " " \
		if colours.size() == 1 else ""
	var part: String = str(found["part"])
	if part.is_empty():
		return "%d %s%s" % [count, colour, "part" if count == 1 else "parts"]
	return "%d %s%s" % [count, colour, part_name(_first_found(found))]


func _first_found(found: Dictionary) -> String:
	var parts: Dictionary = found["parts"]
	return str(parts.keys()[0]) if not parts.is_empty() else str(found["part"])


## "Dark Bluish Grey Plate 1 x 2", "Dark Bluish Grey", "Plate 1 x 3".
func into_words(into: Dictionary) -> String:
	var said := PackedStringArray()
	if int(into.get("color", -1)) >= 0:
		said.append(colour_name(int(into["color"])))
	if not str(into.get("part", "")).is_empty():
		said.append(part_name(str(into["part"])))
	return " ".join(said)


## "everywhere", "in the selection", "in Wing", "in the model's own parts".
static func where_words(found: Dictionary) -> String:
	match str(found["where"]):
		"selection":
			return "in the selection"
		"submodel":
			var inside: String = found["inside"]
			return "in the model's own parts" if inside.is_empty() \
				else "in %s" % Assemblies.definition(Assemblies.leaf(inside))
	return "everywhere"


func part_name(part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	return Inventory._tidy(info.name) if info != null else part_id


func colour_name(code: int) -> String:
	return library.color(code).name.replace("_", " ")


## The copies a replace of [param found] changes beyond those found in:
## "changes all 4 copies of Wing" for each sub-model the model has more than
## one of, "" when none.
static func copies_words(found: Dictionary) -> String:
	var said := PackedStringArray()
	for place: Dictionary in found["places"]:
		if int(place["copies"]) > 1:
			said.append("all %d copies of %s" % [int(place["copies"]), place["name"]])
	return "" if said.is_empty() else "changes " + ", ".join(said)


## "used in 2 colours: Black ×12, Red ×4" for a part found in more than one
## colour, its colours most used first; "" otherwise.
func colours_flag(found: Dictionary) -> String:
	var colours: Dictionary = found["colours"]
	if colours.size() < 2:
		return ""
	var codes: Array = colours.keys()
	codes.sort_custom(func(a: int, b: int) -> bool:
		return int(colours[a]) > int(colours[b]) or (int(colours[a]) == int(colours[b]) and a < b))
	var said := PackedStringArray()
	for code: int in codes:
		said.append("%s ×%d" % [colour_name(code), int(colours[code])])
	return "used in %d colours: %s" % [codes.size(), ", ".join(said)]


## What [param made] (a [method plan]) says before a replace of where the
## new part goes: "won't sit the same in 4 of 12 places (another footprint
## or other connection points); 1 would hold onto nothing"; "" when every
## one sits as the old one did. What stays is [method stay_words].
static func fit_words(found: Dictionary, made: Dictionary) -> String:
	var said := PackedStringArray()
	var count: int = (found["ids"] as Array).size()
	var otherwise: int = (made["otherwise"] as Array).size()
	if otherwise > 0:
		said.append("won't sit the same in %d of %d %s (another footprint or other connection points)"
			% [otherwise, count, "place" if count == 1 else "places"])
	var floats: int = (made["floats"] as Array).size()
	if floats > 0:
		said.append("%d would hold onto nothing" % floats)
	return "; ".join(said)


## What [param made] leaves as it is, each part said once, as the bar shows
## it a line each and a session reads it: "1 has no room and stays as it
## is"; "Pl has no room in 1 of its 2 copies, so all 2 stay"; "1 left out:
## locked in one copy of Sill, so its 2 copies stay"; with [param singles]
## those locked with no copy, "1 locked, left out: unlock it to change it";
## and "All 4 are that already" where every one found is. [param made] {}
## says only those locked.
static func stay_words(found: Dictionary, made: Dictionary, singles: bool = true) -> PackedStringArray:
	var said := PackedStringArray()
	var count: int = (found.get("ids", []) as Array).size()
	if count > 0 and int(made.get("same", 0)) == count:
		said.append("All %d are that already" % count)
		return said
	var in_copies: Dictionary = {}
	var by_name: Dictionary = {}     ## "room" or "locked" + name -> {"name", "parts", "copies", "stay", "locked"}
	for stay: Dictionary in made.get("stays", []):
		for brick_id: int in stay["ids"]:
			in_copies[brick_id] = true
		var key: String = ("locked|" if int(stay["locked"]) > 0 else "room|") + str(stay["name"])
		if not by_name.has(key):
			by_name[key] = {"name": stay["name"], "parts": 0, "copies": 0, "stay": 0, "room": 0,
				"locked": 0}
		var each: Dictionary = by_name[key]
		each["parts"] = int(each["parts"]) + 1
		each["copies"] = maxi(int(each["copies"]), int(stay["copies"]))
		each["stay"] = int(each["stay"]) + int(stay["copies"])
		each["room"] = int(each["room"]) + int(stay["room"])
		each["locked"] = int(each["locked"]) + int(stay["locked"])
	var room: int = 0
	for brick_id: int in made.get("room", []):
		if not in_copies.has(brick_id):
			room += 1
	if room == 1:
		said.append("1 has no room and stays as it is")
	elif room > 1:
		said.append("%d have no room and stay as they are" % room)
	var keys: Array = by_name.keys()
	keys.sort()
	for key: String in keys:
		var each: Dictionary = by_name[key]
		if key.begins_with("room|"):
			if int(each["parts"]) == 1:
				said.append("%s has no room in %d of its %d copies, so all %d stay" % [each["name"],
					int(each["room"]), int(each["copies"]), int(each["stay"])])
			else:
				said.append("%s has no room for %d of its parts in some of its %d copies, so all %d stay"
					% [each["name"], int(each["parts"]), int(each["copies"]), int(each["stay"])])
		elif int(each["locked"]) == 1:
			said.append("1 left out: locked in one copy of %s, so its %d copies stay"
				% [each["name"], int(each["copies"])])
		else:
			said.append("%d left out: locked in copies of %s, so all %d of them stay"
				% [int(each["locked"]), each["name"], int(each["stay"])])
	if singles:
		var locked: int = 0
		for brick_id: int in found.get("locked_ids", []):
			if not in_copies.has(brick_id):
				locked += 1
		if locked == 1:
			said.append("1 locked, left out: unlock it to change it")
		elif locked > 1:
			said.append("%d locked, left out: unlock them to change them" % locked)
	return said


## What the undo step says once the copies have followed, from what changed
## ([param gone], [its part, its colour] before, of each): "replaced 12 Black
## Plate 1 x 2 with Dark Bluish Grey everywhere", and ", 2 of them in other
## copies of Sill" for those changed as their copy followed, not found
## ([param followed], a sub-model's name -> how many).
func changed_words(found: Dictionary, into: Dictionary, gone: Array,
		followed: Dictionary) -> String:
	var count: int = gone.size()
	if count == 0:
		return step_words(found, into)
	var colours: Dictionary = {}
	for one: Array in gone:
		colours[int(one[1])] = true
	var colour: String = colour_name(int(colours.keys()[0])) + " " if colours.size() == 1 else ""
	var what: String = "%d %s%s" % [count, colour, "part" if count == 1 else "parts"] \
		if str(found["part"]).is_empty() else "%d %s%s" % [count, colour, part_name(_first_found(found))]
	var said: String = "replaced %s with %s %s" % [what, into_words(into), where_words(found)]
	if not followed.is_empty():
		var names: Array = followed.keys()
		names.sort()
		said += ", %d of them in other copies of %s" % [_sum(followed), " and ".join(names)]
	return said
