## Find and Replace (Edit › Find and replace…; a session's replace_parts):
## a part, a colour or a part in a colour, found in the selection, in the
## sub-model being edited or everywhere, sub-models and all their copies
## included, said by where it is and in which colours, and replaced with
## another part, another colour or both as one undo step (swapfind, APP_UX8
## #9). StudWorx's, LeoCAD's and Studio's reach the whole model; the hand's
## Replace (EditVerbs.replace) reaches only the selection.
##
## A sub-model's copies are one definition, so a replace inside one changes
## every copy, as an edit by hand does (Assemblies.after_edit): each part
## found is changed where it stands, but those in a copy a mirror places,
## which follow their first copy and are given the other hand of the new
## part where it has one (Assemblies._laid). Any the follow does not reach
## (a copy placed in another colour, whose part did not answer the find)
## are then changed where they stand, in the same undo.
##
## A new part that will not sit as the old one did is said before: another
## footprint or other connection points (its studs, holes, pins and what
## takes a stud), at how many places, and where it would hold onto nothing.
## One with no room is left as it was, and said; a locked part is left too.
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
## "color": an LDraw code, or -1 for any}) in [param where] (WHERE): {
## "ids": each found, in the world's order; "mirrored": those in a copy a
## mirror places, id -> true; "part": the number asked, as the library has
## it; "parts": each number found -> how many (a part a mirror places counted
## as its copy's first has it); "colours": each colour found -> how many;
## "places": [{"name": a sub-model's, or "" for the model's own parts,
## "count", "copies": how many copies the model has of it}], the model first,
## then by name; "locked": how many found are locked, and left out; "where",
## "inside": the sub-model being edited ("" for the model)}.
func find(asked: Dictionary, where: String) -> Dictionary:
	var part: String = str(asked.get("part", "")).strip_edges()
	var colour: int = int(asked.get("color", -1))
	var inside: String = assemblies.entered if assemblies != null else ""
	var looked: Array = _looked_in(where, inside)
	var frames: Dictionary = _frames_for(looked)
	var out: Dictionary = {"ids": [], "mirrored": {}, "part": part, "parts": {}, "colours": {},
		"places": [], "locked": 0, "where": where, "inside": inside}
	var by_def: Dictionary = {}
	for brick: BrickWorld.Brick in looked:
		var path: String = Assemblies.path_of(brick)
		var mirrored: bool = _mirrored(path, frames)
		var as_defined: String = _as_defined(brick.part_id, mirrored)
		if colour >= 0 and brick.color_code != colour:
			continue
		if not part.is_empty() and not same_part(as_defined, part):
			continue
		if builder.is_locked(brick.id):
			out["locked"] = int(out["locked"]) + 1
			continue
		(out["ids"] as Array).append(brick.id)
		if mirrored:
			(out["mirrored"] as Dictionary)[brick.id] = true
		var parts: Dictionary = out["parts"]
		parts[as_defined] = int(parts.get(as_defined, 0)) + 1
		var colours: Dictionary = out["colours"]
		colours[brick.color_code] = int(colours.get(brick.color_code, 0)) + 1
		var def: String = "" if path.is_empty() else Assemblies.definition(Assemblies.leaf(path))
		by_def[def] = int(by_def.get(def, 0)) + 1
	var copies: Dictionary = _copies_by_definition()
	var names: Array = by_def.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return a.is_empty() or (not b.is_empty() and a.naturalnocasecmp_to(b) < 0))
	for def: String in names:
		(out["places"] as Array).append({"name": def, "count": int(by_def[def]),
			"copies": int(copies.get(def, 1))})
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


## Each copy as the save writes it (Assemblies.file_frames), where any of
## [param bricks] is in a copy of a sub-model the model has more than one
## of; {} otherwise, and for the selection, which is changed as a hand
## changes it.
func _frames_for(bricks: Array) -> Dictionary:
	if assemblies == null:
		return {}
	var copies: Dictionary = _copies_by_definition()
	for brick: BrickWorld.Brick in bricks:
		var path: String = Assemblies.path_of(brick)
		if path.is_empty():
			continue
		for segment: String in Assemblies.segments(path):
			if int(copies.get(Assemblies.definition(segment), 1)) > 1:
				return assemblies.file_frames()
	return {}


## Whether the copy at [param path] is placed by a mirror of its definition's
## first, as [param frames] (Assemblies.file_frames) writes it.
static func _mirrored(path: String, frames: Dictionary) -> bool:
	var entry: Variant = frames.get(path)
	return entry is Dictionary and ((entry as Dictionary).get("frame", Transform3D.IDENTITY)
		as Transform3D).basis.determinant() < 0.0


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
## number or "" for its own, "color": a code or -1 for its own}): {
## "changes": [{"brick", "part", "color", "at"}] for those changed where they
## stand; "follow": the ids left to follow their copy; "same": how many are
## that already; "room": the ids with no room for it; "otherwise": the ids
## where it will not sit as the old one did (another footprint, other
## connection points); "floats": of those, the ids where it would hold onto
## nothing that held the old one; "missing": the part's number when its
## shape is not here}.
func plan(found: Dictionary, into: Dictionary) -> Dictionary:
	var part: String = str(into.get("part", "")).strip_edges()
	var colour: int = int(into.get("color", -1))
	var out: Dictionary = {"changes": [], "follow": [], "same": 0, "room": [], "otherwise": [],
		"floats": [], "missing": ""}
	var mirrored: Dictionary = found["mirrored"]
	var sel: Variant = Later.script(&"SelectBy")
	for brick_id: int in found["ids"]:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var new_part: String = brick.part_id
		if not part.is_empty():
			new_part = _as_defined(part, mirrored.has(brick_id))
		var new_colour: int = brick.color_code if colour < 0 else colour
		if new_part == brick.part_id and new_colour == brick.color_code:
			out["same"] = int(out["same"]) + 1
			continue
		var at: Transform3D = brick.transform
		# One a mirror places follows its first copy, wherever that puts it.
		var follows: bool = mirrored.has(brick_id)
		if new_part != brick.part_id:
			var was: Lbm.PartMesh = library.mesh_for(brick.part_id)
			var shape: Lbm.PartMesh = library.mesh_for(new_part)
			if shape == null:
				out["missing"] = new_part
				continue
			at = _placed(brick.transform, was, shape)
			var packed: PackedInt32Array = builder.boxes_for(shape, at)
			if not follows and builder.lattice.collides_boxes(packed, brick_id):
				(out["room"] as Array).append(brick_id)
				continue
			if not _sits_alike(was, brick.transform, shape, at):
				(out["otherwise"] as Array).append(brick_id)
				var held: Array = sel._joined_to(world, builder.lattice, brick_id)
				if not held.is_empty() and _held_by(packed, brick_id, at, sel).is_empty():
					(out["floats"] as Array).append(brick_id)
		if follows:
			(out["follow"] as Array).append(brick_id)
		else:
			(out["changes"] as Array).append({"brick": brick_id, "part": new_part,
				"color": new_colour, "at": at})
	return out


## Where [param shape] goes to take the place of [param was] standing at
## [param at]: exactly there where the two have one footprint and height (a
## printed version of the same mould, whose print can reach a hair past the
## plain part's box, is not moved by it), else its middle on the stud grid
## for its own footprint and its bottom where the other's was
## (Builder._in_place_of).
func _placed(at: Transform3D, was: Lbm.PartMesh, shape: Lbm.PartMesh) -> Transform3D:
	if was == null:
		return at
	if was.bounds.size.distance_to(shape.bounds.size) < 1.0 \
			and was.bounds.get_center().distance_to(shape.bounds.get_center()) < 1.0:
		return at
	return builder._in_place_of(at, was, shape)


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
## following as an edit by hand makes it (see the class's words): {"changed":
## how many parts, "room": how many had no room and stand as they were,
## "words": the step's own}.
func replace(found: Dictionary, into: Dictionary) -> Dictionary:
	var made: Dictionary = plan(found, into)
	var words: String = step_words(found, into)
	var depth: int = builder.history_depth()
	var was: Dictionary = {}
	for brick_id: int in found["ids"]:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null:
			was[brick_id] = [brick.part_id, brick.color_code]
	var done: Vector2i = builder.replace_bricks(made["changes"], words)
	if done.x > 0:
		edited.call()
	# Those in a copy a mirror places that their copy's follow did not reach,
	# changed where they stand.
	var left := PackedInt64Array()
	for brick_id: int in made["follow"]:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick != null and was[brick_id] == [brick.part_id, brick.color_code]:
			left.append(brick_id)
	if not left.is_empty():
		var rest: Dictionary = found.duplicate()
		rest["ids"] = Array(left)
		rest["mirrored"] = {}
		var more: Vector2i = builder.replace_bricks(plan(rest, into)["changes"], words)
		done.y += more.y
		if more.x > 0:
			edited.call()
	builder.fold_since(depth, words)
	if assemblies != null:
		assemblies.no_copies_follow()
	var changed: int = 0
	for brick_id: int in was:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or was[brick_id] != [brick.part_id, brick.color_code]:
			changed += 1
	return {"changed": changed, "room": (made["room"] as Array).size() + done.y,
		"words": words}


# -- what is asked ------------------------------------------------------------------


## The colour [param asked] names: an LDraw code, or a name as the bin's
## colour find reads one ("Dark Bluish Grey", "dark bluish gray"); -1 for
## none asked, -2 for one there is no such colour.
func colour_of(asked: Variant) -> int:
	if asked == null:
		return -1
	if asked is int or asked is float:
		var code: int = int(asked)
		return code if code < 0 or library.colors.has(code) else -2
	var said: String = str(asked).strip_edges()
	if said.is_empty():
		return -1
	var named: Array = PartsBin.colours_named(library, said)
	return (named[0] as PartLibrary.BrickColor).code if not named.is_empty() else -2


## The part [param asked] names, as the library has it: its number, or the
## part a search of its words finds first; "" for none.
func part_of(asked: String) -> String:
	var said: String = asked.strip_edges().to_lower().trim_suffix(".dat")
	if said.is_empty():
		return ""
	if library.parts.has(said):
		return library.resolve(said)
	var found: Array = library.search(said, 1)
	return (found[0] as PartLibrary.PartInfo).id if not found.is_empty() else ""


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
## will not sit as the old one did, would hold onto nothing, or has no room
## ([method fit_words]); "" when it sits as the old one everywhere.
func ahead(found: Dictionary, into: Dictionary) -> String:
	var part: String = str(into.get("part", ""))
	if part.is_empty():
		return ""
	if await shape(part) == null:
		return "%s's shape could not be had, so nothing of it can be put down." % part
	var other: String = Later.script(&"Mirror").counterpart(library, part)
	if not (found["mirrored"] as Dictionary).is_empty() and not other.is_empty():
		await shape(other)
	var said: String = fit_words(found, plan(found, into))
	return "" if said.is_empty() else "It " + said + "."


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


## What [param made] (a [method plan]) says before a replace of a new part:
## "won't sit the same in 4 of 12 places (another footprint or other
## connection points); 1 would hold onto nothing; 2 have no room and stay
## as they are"; "" when every one sits as the old one did.
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
	var room: int = (made["room"] as Array).size()
	if room > 0:
		said.append("%d %s no room and stay as %s" % [room, "has" if room == 1 else "have",
			"it is" if room == 1 else "they are"])
	return "; ".join(said)
