## The joints a section can be hung on, with both halves laid by the app.
##
## A section turned off the square has to be held by something that turns,
## as it is in plastic: a hinge, a clip on a bar, a ball. Said as hinge:
## "<kind>" on the section, the app puts the joint's base where the section
## says, its top half in the section, and turns the section about the line
## the two share. Where that line is comes from the parts themselves (the
## records [Joints] pairs: a finger in a fork, a shaft in a bore), not from
## numbers kept here, so a kind is offered only where the parts this build
## carries say where their joint is.
##
## Every kind but the tilting hinge rests in line: at no angle the top half
## carries on from the base, nose forward, and pitch (or roll) lifts it. The
## tilting hinge brick rests closed, its top lying on its base, as it always
## has here.
class_name Hinges
extends RefCounted

const TILTING := "tilting"
const CLICK := "click"
const CLIP := "clip"
const BALL := "ball"

## kind -> [base part, top part, what it is]. Base outside the section, top
## in it.
const KINDS: Dictionary = {
	TILTING: ["3937", "3938", "a tilting hinge brick 1 x 2 (3937) with its top plate (3938)"],
	CLIP: ["60478", "63868", "a plate with a bar on its end (60478) and a plate with a "
		+ "clip on its end (63868)"],
	CLICK: ["44302a", "44301a", "click hinge plates 1 x 2, two fingers (44302) and one (44301)"],
}

## Other words a design may use for one.
const ALIASES: Dictionary = {
	"true": TILTING, "hinge brick": TILTING, "tilting hinge": TILTING, "tilt": TILTING,
	"3937": TILTING, "clip and bar": CLIP, "bar": CLIP, "clip on a bar": CLIP,
	"bar and clip": CLIP, "60478": CLIP, "click hinge": CLICK, "locking": CLICK,
	"locking hinge": CLICK, "44301": CLICK, "44302": CLICK, "finger": CLICK,
}

## A round of this radius, LDU, is a joint's pin or eye: a hinge brick's pin
## is 6, a hinge plate's and a bar's 4. Narrower is an axle, wider a turntable.
const LINE_RADII := Vector2(3.5, 6.5)


## The kind a word names, or "".
static func kind_named(said: String) -> String:
	var word: String = said.strip_edges().to_lower()
	if KINDS.has(word):
		return word
	return str(ALIASES.get(word, ""))


## The kinds, said for a design.
static func listing() -> String:
	var said := PackedStringArray()
	for kind: String in KINDS:
		said.append("\"%s\" (%s)" % [kind, KINDS[kind][2]])
	return ", ".join(said)


## The kinds this build's parts can lay, said for a design.
static func offered(library: PartLibrary) -> String:
	var said := PackedStringArray()
	for kind: String in KINDS:
		if available(kind, library):
			said.append("\"%s\" — %s" % [kind, KINDS[kind][2]])
	return "; ".join(said)


## Whether both halves of a kind are in this build and say where their
## joint is.
static func available(kind: String, library: PartLibrary) -> bool:
	if not KINDS.has(kind) or library == null:
		return false
	if kind == TILTING:
		return library.parts.has(KINDS[kind][0])
	for part: String in [KINDS[kind][0], KINDS[kind][1]]:
		var mesh: Lbm.PartMesh = library.mesh_for(part)
		if mesh == null or line_of(mesh).is_empty():
			return false
	return true


## Where a part's turning line is, in its own frame, as [point, way]: the
## middle of a finger or a fork, else of the longest pin or eye, else a
## ball's centre with no way. [] for a part with none.
static func line_of(mesh: Lbm.PartMesh) -> Array:
	var best: Array = []
	var longest: float = -1.0
	for want: Array in [["finger", "fork"], ["shaft", "bore"]]:
		for connector: Lbm.Connector in mesh.connectors:
			if not connector.kind in want:
				continue
			if connector.kind in ["shaft", "bore"] and (connector.radius < LINE_RADII.x
					or connector.radius > LINE_RADII.y):
				continue
			if connector.length > longest:
				longest = connector.length
				best = [connector.position + connector.axis * connector.length * 0.5,
					connector.axis.normalized()]
		if not best.is_empty():
			return best
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind in ["ball", "socket"]:
			return [connector.position, Vector3.ZERO]
	return []


## Lay a hinged section's joint: which way each half turns, where the line
## is from the base's corner and where the section's origin is from the
## line. [param place] is func(part, rot, Vector3 in studs and plates) ->
## Transform3D, the square transform of a part laid there. Returns why it
## could not be laid, or "".
static func fit(section: Assistant.Section, library: PartLibrary, place: Callable) -> String:
	var kind: Array = KINDS.get(section.hinge_kind, [])
	if kind.is_empty():
		return "there is no hinge called '%s'" % section.hinge_kind
	var base: Lbm.PartMesh = library.mesh_for(kind[0]) if library != null else null
	var top: Lbm.PartMesh = library.mesh_for(kind[1]) if library != null else null
	if base == null or top == null:
		return "the %s hinge's parts are not loaded" % section.hinge_kind
	var pin: Vector3 = Assistant.Section.pin_of(section.axis)
	if section.hinge_kind == TILTING:
		var rot: int = section.hinge_rot()
		section.base_rot = rot
		section.top_rot = rot
		section.top_at = Vector3(0, -2, 0)
		var at: Transform3D = place.call(kind[0], rot, Vector3.ZERO)
		for connector: Lbm.Connector in base.connectors:
			if connector.kind == "bore" and absf(connector.axis.y) < 0.5:
				section.pin_from_corner = at * connector.position
				break
		section.origin_from_pin = Vector3(0, 3 * Assistant.PLATE, 0) - section.pin_from_corner
		return ""
	var base_line: Array = line_of(base)
	var top_line: Array = line_of(top)
	if base_line.is_empty() or top_line.is_empty():
		return ("this build's %s and %s do not say where their joint is yet, so a "
			% [kind[0], kind[1]] + "%s hinge cannot be laid; use %s" % [section.hinge_kind,
				offered(library)])
	# The nose runs across the line: along z for a line along x.
	var forward: Vector3 = Vector3.BACK if section.axis == "x" else Vector3.RIGHT
	var best: Array = [_best_turn(base, base_line, kind[0], pin, forward, 1.0, place),
		_best_turn(top, top_line, kind[1], pin, forward, -1.0, place)]
	if best[0].is_empty() or best[1].is_empty():
		return ("the %s hinge's line does not lie across its nose at any quarter turn"
			% section.hinge_kind)
	section.base_rot = int(best[0][0])
	section.top_rot = int(best[1][0])
	section.pin_from_corner = best[0][1]
	# The top half where its first stud is the section's first: its cover's
	# corner is wherever its joint stands out to, which is not where the
	# bricks on it start.
	var square: Transform3D = place.call(kind[1], section.top_rot, Vector3.ZERO)
	var first := Vector3.INF
	for connector: Lbm.Connector in top.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and (square.basis * connector.axis).y > 0.99:
			var at: Vector3 = square * connector.position
			if at.x + at.z < first.x + first.z or first == Vector3.INF:
				first = at
	if first == Vector3.INF:
		return "the %s hinge's top half has no studs for a section to stand on" % section.hinge_kind
	var shift: Vector3 = Vector3(Assistant.STUD * 0.5, 0, Assistant.STUD * 0.5) - first
	section.top_at = Vector3(shift.x / Assistant.STUD, shift.y / Assistant.PLATE,
		shift.z / Assistant.STUD)
	section.origin_from_pin = -((best[1][1] as Vector3) + shift)
	return ""


## The quarter turn that puts a half's line across the nose, its body behind
## the line for the base ([param side] 1) or ahead of it for the top (-1),
## as [rot, where the line's middle is]. [] when none does.
static func _best_turn(mesh: Lbm.PartMesh, line: Array, part: String, pin: Vector3,
		forward: Vector3, side: float, place: Callable) -> Array:
	var best: Array = []
	var most: float = -INF
	for rot: int in 4:
		var placed: Transform3D = place.call(part, rot, Vector3.ZERO)
		var way: Vector3 = placed.basis * (line[1] as Vector3)
		if line[1] != Vector3.ZERO and absf(way.normalized().dot(pin)) < 0.99:
			continue
		var middle: Vector3 = placed * (line[0] as Vector3)
		var body: Vector3 = placed * mesh.bounds.get_center()
		var ahead: float = (middle - body).dot(forward) * side
		if ahead > most + 0.01:
			most = ahead
			best = [rot, middle]
	return best
