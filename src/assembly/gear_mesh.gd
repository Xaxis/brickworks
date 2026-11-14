## Two gears put in mesh by hand, and why two side by side do not mesh.
##
## walk180 (2026-10-23): two 24s on axles three studs apart, each pointed
## onto its axle, went on wherever the pointer was along it, a stud apart in
## depth. Turning one did not turn the other, and nothing said why. Studio
## and LDCad put a gear on the Technic hole grid, so a pair lines up. Here a
## gear in hand on an axle seats where it meshes a gear beside it
## (Builder._into_mesh, from [method shifts]), a gear slid along its axle
## stops in mesh (Grab), and a gear beside one it does not mesh is told why
## ([method why_not]). Whether two gears mesh is Mechanism's alone
## ([method Mechanism.couple]): every place found here is checked by it.
class_name GearMesh
extends RefCounted

## A gear in hand on an axle seats in mesh when the pointer is this near
## where along the axle it meshes, LDU: a gear and a half's width.
const CAPTURE := 30.0
## Gears whose pitch circles come within this of meeting are beside each
## other, LDU: near enough that a builder meant them to mesh.
const BESIDE := 20.0
## A gear slid along its axle stops in mesh when it comes this near, LDU.
const SNAP := 4.0


## The gears of [param part_id] standing at [param at]: one for each entry
## of the table it has (a differential's casing has two).
static func gears_at(part_id: String, at: Transform3D, mesh: Lbm.PartMesh = null,
		key: int = 0) -> Array[Mechanism.Gear]:
	var out: Array[Mechanism.Gear] = []
	var spec: Dictionary = Mechanism.spec_of(part_id)
	if spec.is_empty():
		return out
	var piece := Mechanism.Piece.new()
	piece.key = key
	piece.part = part_id
	piece.reads = Mechanism.reads_as(part_id)
	piece.at = at
	piece.mesh = mesh
	var specs: Array = [spec]
	specs.append_array(spec.get("also", []))
	for one: Dictionary in specs:
		out.append(Mechanism.gear_of(piece, one))
	return out


## Which way along its own axis a gear's teeth face, in its own frame: +1,
## -1, or 0 for a gear that meshes either way (a spur, a double bevel). A
## bevel's or a crown's teeth stand on one face, and its box reaches out that
## way from its origin: measured in the OMR's sets, a 6589's crossing is on
## its -z (app axes) in all 319 pairs of two, a 4143's and an 87407's on
## their +z, a crown's on its -z.
static func facing(part_id: String, mesh: Lbm.PartMesh) -> float:
	var spec: Dictionary = Mechanism.spec_of(part_id)
	if mesh == null or not str(spec.get("kind", "")) in ["bevel", "crown"]:
		return 0.0
	var axis: Vector3 = Mechanism._axis_of(spec.get("axis", "z"))
	var middle: float = mesh.bounds.get_center().dot(axis)
	return 0.0 if absf(middle) < 0.25 else signf(middle)


## "the 24", "the 12 bevel", "the worm".
static func named(gear: Mechanism.Gear) -> String:
	match gear.kind:
		"worm":
			return "the worm"
		"ring":
			return "the ring of %d" % gear.teeth
		"bevel":
			return "the %d bevel" % gear.teeth
		"double":
			return "the %d double bevel" % gear.teeth
		"crown":
			return "the %d crown" % gear.teeth
	return "the %d" % gear.teeth


## [param gear] moved [param by] along the world.
static func moved(gear: Mechanism.Gear, by: Vector3) -> Mechanism.Gear:
	var out := Mechanism.Gear.new()
	out.key = gear.key
	out.part = gear.part
	out.kind = gear.kind
	out.teeth = gear.teeth
	out.radius = gear.radius
	out.face = gear.face
	out.centre = gear.centre + by
	out.axis = gear.axis
	out.length = gear.length
	out.arc_middle = gear.arc_middle
	out.arc_half = gear.arc_half
	out.links = gear.links
	out.body = gear.body
	return out


## Whether [param theirs] is beside [param mine] free to slide along its
## own axis: its middle no further from [param mine]'s axle than the two
## reach and [constant BESIDE] more, and not on the same axle.
static func beside(mine: Mechanism.Gear, theirs: Mechanism.Gear) -> bool:
	var gap: Vector3 = theirs.centre - mine.centre
	var across: float = (gap - mine.axis * gap.dot(mine.axis)).length()
	if absf(mine.axis.dot(theirs.axis)) > 0.999 and across < Mechanism.LINE_SLACK * 2.0:
		return false
	return across <= mine.radius + theirs.radius + BESIDE


## Where along [param way] (a unit, along [param mine]'s axis) [param mine]
## meshes [param theirs]: {"shifts": [LDU, ...]}, each a place Mechanism
## finds them in mesh, nearest first; or {"why": words} when no slide along
## its axle puts them in mesh. Where only [param theirs] stands wrong for a
## mesh (a bevel's partner too far from where the axles cross, a worm's
## gear out of its axle's plane), {"why": what is wrong with it, "seat":
## [LDU, ...]}: where mine stands right for its half, for the other to be
## slid to. [param faces]: [method facing] of mine, in the world (ZERO for
## either way).
static func shifts(mine: Mechanism.Gear, way: Vector3, theirs: Mechanism.Gear,
		faces: Vector3 = Vector3.ZERO) -> Dictionary:
	var along: float = way.dot(mine.axis)
	if absf(along) < 0.99:
		return {"why": "it does not slide along its own axle"}
	var dot: float = mine.axis.dot(theirs.axis)
	var gap: Vector3 = theirs.centre - mine.centre
	var wanted: Array = []   ## where mine's middle goes, along its axis from where it is
	var theirs_off: String = ""
	if mine.kind == "worm" or theirs.kind == "worm":
		if mine.kind == "worm" and theirs.kind == "worm":
			return {"why": "two worms do not mesh"}
		if absf(dot) > 0.02:
			return {"why": "a worm turns only a gear whose axle is square to its own"}
		var normal: Vector3 = mine.axis.cross(theirs.axis).normalized()
		var apart: float = absf(gap.dot(normal))
		var ideal: float = mine.radius + theirs.radius
		if absf(apart - ideal) > Mechanism.MESH_SLACK:
			return {"why": _spacing_words(mine, theirs, apart, ideal)}
		if mine.kind == "worm":
			# Its middle where its axle passes nearest the gear's.
			wanted.append(Mechanism._crossing(mine.centre, mine.axis, theirs.centre, theirs.axis))
			var out_of_plane: float = absf(gap.dot(theirs.axis))
			if out_of_plane > 3.0:
				theirs_off = "its teeth stand %s LDU along its axle from this one's" \
					% Mechanism._tidy(out_of_plane)
		else:
			# Its teeth's plane through the worm's axle.
			wanted.append(gap.dot(mine.axis))
			var t: float = Mechanism._crossing(theirs.centre, theirs.axis, mine.centre, mine.axis)
			if absf(t) > theirs.length * 0.5 + Mechanism.REACH_SLACK:
				theirs_off = "its middle stands %s LDU along its axle from this one's" % Mechanism._tidy(absf(t))
	elif absf(dot) > 0.999:
		if mine.kind == "bevel" or theirs.kind == "bevel":
			return {"why": "a bevel gear meshes only one square to it, and these are parallel"}
		var across: float = (gap - mine.axis * gap.dot(mine.axis)).length()
		var ideal: float = mine.radius + theirs.radius
		if mine.kind == "ring" or theirs.kind == "ring":
			ideal = absf(mine.radius - theirs.radius)
		if absf(across - ideal) > Mechanism.MESH_SLACK:
			return {"why": _spacing_words(mine, theirs, across, ideal)}
		wanted.append(gap.dot(mine.axis))
	elif absf(dot) < 0.02:
		var squares: bool = (mine.kind in ["bevel", "double"] and theirs.kind in ["bevel", "double"]) \
			or (mine.kind == "crown" and theirs.kind in ["spur", "double"]) \
			or (theirs.kind == "crown" and mine.kind in ["spur", "double"])
		if not squares:
			return {"why": ("its axle is square to this one's, and gears like these mesh only on parallel "
				+ "axles: at right angles it takes two bevels, or a crown and a spur")}
		var normal: Vector3 = mine.axis.cross(theirs.axis).normalized()
		var off: float = absf(gap.dot(normal))
		if off > Mechanism.LINE_SLACK:
			return {"why": "its axle passes %s LDU from this one's, and square gears mesh only where their axles cross" \
				% Mechanism._tidy(off)}
		var t: float = Mechanism._crossing(mine.centre, mine.axis, theirs.centre, theirs.axis)
		var face_mine: float = mine.face if mine.kind != "spur" else 0.0
		var face_theirs: float = theirs.face if theirs.kind != "spur" else 0.0
		var theirs_from: float = theirs.centre.distance_to(mine.centre + mine.axis * t)
		if absf(theirs_from - mine.radius - face_theirs) > Mechanism.LINE_SLACK:
			theirs_off = "it stands %s LDU from where the axles cross, and meshes this one at %s" % [
				Mechanism._tidy(theirs_from), Mechanism._tidy(mine.radius + face_theirs)]
		var from: float = theirs.radius + face_mine
		for side: float in [1.0, -1.0]:
			# A gear's teeth face where the axles cross.
			if faces != Vector3.ZERO and faces.dot(mine.axis * -side) < 0.5:
				continue
			wanted.append(t + side * from)
	else:
		return {"why": "its axle is neither parallel to this one's nor square to it"}
	var out: Array = []
	for to: float in wanted:
		var shift: float = to / along
		if not theirs_off.is_empty() or Mechanism.couple(moved(mine, way * shift), theirs) != null:
			out.append(shift)
	out.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b))
	if not theirs_off.is_empty():
		return {"why": theirs_off, "seat": out}
	if out.is_empty():
		return {"why": "no place along this one's axle meshes them"}
	return {"shifts": out}


## Why [param mine] and [param theirs], standing where they are and beside
## each other, do not mesh; "" when they do, or are not beside each other.
static func why_not(mine: Mechanism.Gear, theirs: Mechanism.Gear) -> String:
	if Mechanism.couple(mine, theirs) != null or not beside(mine, theirs):
		return ""
	var found: Dictionary = shifts(mine, mine.axis, theirs)
	if found.has("seat"):
		return "%s (drag it along its axle)" % found["why"]
	if found.has("why"):
		return str(found["why"])
	var shift: float = float((found["shifts"] as Array)[0])
	return "it stands %s LDU along the axle from where they mesh (drag one along its axle)" \
		% Mechanism._tidy(absf(shift))


## "their axles are 80 LDU apart where a 24 and a 24 mesh at 60, 20 LDU too
## far".
static func _spacing_words(mine: Mechanism.Gear, theirs: Mechanism.Gear, apart: float,
		ideal: float) -> String:
	return "their axles are %s LDU apart where %s and %s mesh at %s, %s LDU too %s" % [
		Mechanism._tidy(apart), _a(mine), _a(theirs), Mechanism._tidy(ideal),
		Mechanism._tidy(absf(apart - ideal)), "far" if apart > ideal else "close"]


## "a 24", "an 8", "a worm".
static func _a(gear: Mechanism.Gear) -> String:
	var said: String = named(gear).trim_prefix("the ")
	return ("an " if said.begins_with("8") or said.begins_with("11") or said.begins_with("18")
		else "a ") + said
