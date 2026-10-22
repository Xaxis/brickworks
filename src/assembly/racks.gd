## Gear racks and the pinions in them: a rack slides a tooth for every tooth
## of its pinion that passes. Read off where the parts stand, for [Linkage]
## to hold a loop by (a steering's track rod on its arms, pushed by the
## pinion on its column) and for a grab to drive (Grab).
##
## Every rack the library draws from a tooth primitive has its teeth 8 LDU
## apart: ten to the four studs of a 1 x 4 (3743), so racks laid end to end
## keep their pitch. A pinion's pitch circle is 1.25 LDU a tooth (section 2
## of docs/MECHANISMS.md), 7.854 LDU of arc a tooth. Teeth do not slip: a
## turn of an 8 tooth pinion moves its rack 8 teeth, 64 LDU, and the pitch
## circle would say 62.83; the 1.9% between them is taken up in the teeth's
## play. So the rack moves 8 LDU a tooth, as the parts are drawn.
##
## Where a pinion stands against its rack was measured on the OMR's sets,
## per part, as the gear table has it ("racks"): 3743's pitch line is 4 LDU
## above its origin for an 8 (50 pairs at 14, 26 more 2 LDU either side), a
## 1 x 7 or 1 x 13 steering rack's 5 for a 12 (55 pairs at 20).
class_name Racks
extends RefCounted

## A pinion's centre within this of its rack's pitch line plus its pitch
## radius meshes, LDU: 3743's eights stand 12 to 16 above it, 8849-1's at 11.
const PITCH_SLACK := 3.0
## Its teeth's plane within the rack's teeth across it, give or take this.
const ACROSS_SLACK := 1.0
## Its centre within this past the first or last tooth's middle, LDU.
const ALONG_SLACK := 4.0
## Its axis square to the rack's teeth and along their width, to this.
const SQUARE := 0.99


## A pinion in a rack: where each stands, and how far the rack goes for a
## radian of the pinion's turn against it.
class Pinion extends RefCounted:
	var rack: int = 0     ## brick id
	var gear: int = 0     ## brick id
	var teeth: int = 0
	## The pinion's centre and axis, and the rack's teeth's line, where they
	## stood: world, unit ways.
	var centre := Vector3.ZERO
	var axis := Vector3.ZERO
	var line := Vector3.ZERO
	## LDU along [member line] the rack goes for a radian the pinion turns
	## about [member axis], against the rack: signed.
	var rate: float = 0.0
	## How far the pinion's centre stands from where the table puts it, LDU.
	var off: float = 0.0
	## A linear actuator's screw: [member gear] its input, [member rack] its
	## rod, [member body] its body (brick id).
	var screw: bool = false
	var body: int = 0

	## "an 8 tooth pinion in a 1 x 4 rack".
	func said(world: BrickWorld) -> String:
		if screw:
			return "the screw of linear actuator %s" % (world.get_brick(body).part_id
				if world.get_brick(body) != null else "?")
		var rack_part: String = world.get_brick(rack).part_id if world.get_brick(rack) != null else "?"
		return "%s %d tooth pinion in rack %s" % ["an" if teeth in [8, 11, 18] or (teeth >= 80 and teeth < 90) else "a",
			teeth, rack_part]


static func pitch() -> float:
	return float(Mechanism.table().get("rack_pitch", 8.0))


static func is_rack(part_id: String) -> bool:
	return not spec_of(part_id).is_empty()


## One part's entry in the rack table ({teeth, from, to, pitch_line, z}), as
## the part it reads as (Mechanism.reads_as); empty for a part that is not a
## rack.
static func spec_of(part_id: String) -> Dictionary:
	return Mechanism.entry_of("racks", part_id)


## Each linear actuator's screw whose input is a part of its own (the gear
## table's actuators: input, turns), among [param entries] ([brick id, part
## id, Transform3D]) and the actuator joints [param links] (Bodies.Link, kind
## "actuator", pairs [body, rod]): read as a pinion whose rack is the rod, on
## the actuator's axis. The rod goes the stroke over the input's turns, as
## builders counted them (docs/MECHANISMS.md, section 13); which way round
## extends it is not read from the parts.
static func screws(entries: Array, links: Array) -> Array[Pinion]:
	var out: Array[Pinion] = []
	var part_of: Dictionary = {}
	for entry: Array in entries:
		part_of[int(entry[0])] = entry
	for link: Variant in links:
		if str(link.kind) != "actuator" or (link.pairs as Array).is_empty():
			continue
		var pair: Array = link.pairs[0]
		var body_entry: Variant = part_of.get(int(pair[0]))
		if body_entry == null:
			continue
		var spec: Dictionary = Mechanism.entry_of("actuators", str(body_entry[1]))
		if not spec.has("input") or float(spec.get("turns", 0.0)) <= 0.0:
			continue
		var way: Vector3 = (link.axis as Vector3).normalized()
		var point: Vector3 = link.point
		for entry: Array in entries:
			if Mechanism.reads_as(str(entry[1])) != str(spec["input"]):
				continue
			var gap: Vector3 = (entry[2] as Transform3D).origin - point
			if (gap - way * gap.dot(way)).length() > Mechanism.LINE_SLACK:
				continue
			var mesh := Pinion.new()
			mesh.screw = true
			mesh.body = int(pair[0])
			mesh.rack = int(pair[1])
			mesh.gear = int(entry[0])
			mesh.centre = (entry[2] as Transform3D).origin
			mesh.axis = way
			mesh.line = way
			# Seen from the rod, the input goes back as far as the rod goes out.
			mesh.rate = absf(float(spec["to"]) - float(spec["from"])) / (float(spec["turns"]) * TAU)
			out.append(mesh)
			break
	return out


## How far [param mesh]'s pinion may go along its rack's line from where it
## stands and still be read in a rack ([method find]): its own, or another
## its teeth run on into, end to end on one line ([param racks]: each
## [Transform3D, part id], the racks of the body its rack is in; 3743s laid
## end to end keep their pitch). Vector2(back, on), LDU along
## [member Pinion.line]; INF both ways for a screw.
static func room_along(mesh: Pinion, racks: Array) -> Vector2:
	if mesh.screw:
		return Vector2(-INF, INF)
	var spans: Array = []
	for one: Array in racks:
		var spec: Dictionary = spec_of(str(one[1]))
		var at: Transform3D = one[0]
		var fit: Array = [] if spec.is_empty() else _fit(spec, at, mesh.centre, mesh.axis, mesh.teeth)
		if fit.is_empty():
			continue
		var x: float = (fit[0] as Vector3).x
		var way: Vector3 = at.basis * Vector3.RIGHT
		var span := Vector2(float(spec["from"]) - ALONG_SLACK - x, float(spec["to"]) + ALONG_SLACK - x) * way.length()
		if way.dot(mesh.line) < 0.0:
			span = Vector2(-span.y, -span.x)
		spans.append(span)
	# From the span the pinion stands in, on through each that meets it.
	var room := Vector2(INF, -INF)
	for span: Vector2 in spans:
		if span.x <= 0.0 and span.y >= 0.0:
			room = Vector2(minf(room.x, span.x), maxf(room.y, span.y))
	if room.x > room.y:
		return Vector2(-INF, INF)
	var grew: bool = true
	while grew:
		grew = false
		for span: Vector2 in spans:
			if span.x < room.x and span.y >= room.x or span.y > room.y and span.x <= room.y:
				room = Vector2(minf(room.x, span.x), maxf(room.y, span.y))
				grew = true
	return room


## Every pinion standing in a rack among [param entries], each [brick id,
## part id, Transform3D].
static func find(entries: Array) -> Array[Pinion]:
	var out: Array[Pinion] = []
	var racks: Array = []
	var gears: Array = []
	for entry: Array in entries:
		var part: String = entry[1]
		if is_rack(part):
			racks.append(entry)
			continue
		var spec: Dictionary = Mechanism.spec_of(part)
		if not spec.is_empty() and str(spec.get("kind", "")) in ["spur", "double"] \
				and str(spec.get("axis", "z")) == "z" and int(spec.get("teeth", 0)) > 0:
			gears.append([entry, spec])
	if racks.is_empty() or gears.is_empty():
		return out
	for rack: Array in racks:
		var spec: Dictionary = spec_of(rack[1])
		var at: Transform3D = rack[2]
		for pair: Array in gears:
			var gear: Array = pair[0]
			var gear_spec: Dictionary = pair[1]
			var gear_at: Transform3D = gear[2]
			var centre: Vector3 = gear_at * (Vector3.BACK * float(gear_spec.get("plane", 0.0)))
			var axis: Vector3 = (gear_at.basis * Vector3.BACK).normalized()
			var teeth: int = int(gear_spec["teeth"])
			var fit: Array = _fit(spec, at, centre, axis, teeth)
			if fit.is_empty():
				continue
			var local: Vector3 = fit[0]
			if local.x < float(spec["from"]) - ALONG_SLACK or local.x > float(spec["to"]) + ALONG_SLACK:
				continue
			var mesh := Pinion.new()
			mesh.rack = int(rack[0])
			mesh.gear = int(gear[0])
			mesh.teeth = teeth
			mesh.centre = centre
			mesh.axis = axis
			mesh.line = (at.basis * Vector3.RIGHT).normalized()
			mesh.off = fit[2]
			# The pinion's tooth where it meets the rack, below its centre on
			# the rack's side, goes this way as the pinion turns about its
			# axis; the rack goes with it a tooth for a tooth.
			var down: Vector3 = -(at.basis * (fit[1] as Vector3)).normalized()
			var sense: float = signf(mesh.line.dot(axis.cross(down)))
			mesh.rate = sense * pitch() * float(teeth) / TAU
			out.append(mesh)
	return out


## Whether a pinion of [param teeth] at [param centre] on [param axis] stands
## in the teeth of a rack ([param spec], at [param rack_at]), wherever along
## them: [its centre in the rack's frame, the way from the teeth to it there,
## how far off the pitch it stands], or empty.
static func _fit(spec: Dictionary, rack_at: Transform3D, centre: Vector3, axis: Vector3, teeth: int) -> Array:
	var inverse: Transform3D = rack_at.affine_inverse()
	var local: Vector3 = inverse * centre
	var local_axis: Vector3 = (inverse.basis * axis).normalized()
	var radius: float = float(Mechanism.table().get("ldu_per_tooth", 1.25)) * teeth
	# The way from the rack's teeth to the pinion's centre, in the rack's
	# frame: up, or for a round rack (2790a, a rod ringed with teeth)
	# straight out from its line, whichever side the pinion is.
	var out_way := Vector3.UP
	var off: float = 0.0
	if bool(spec.get("round", false)):
		var across := Vector2(local.y, local.z)
		if across.length() < 0.001:
			return []
		out_way = Vector3(0.0, across.x, across.y).normalized()
		# Square to the rod and to the way out to its centre.
		var skew: float = sqrt(1.0 - SQUARE * SQUARE)
		if absf(local_axis.x) > skew or absf(local_axis.dot(out_way)) > skew:
			return []
		off = across.length() - (float(spec["pitch_line"]) + radius)
	else:
		if absf(local_axis.z) < SQUARE:
			return []
		off = local.y - (float(spec["pitch_line"]) + radius)
		var z: Array = spec.get("z", [-10.0, 10.0])
		if local.z < float(z[0]) - ACROSS_SLACK or local.z > float(z[1]) + ACROSS_SLACK:
			return []
	if absf(off) > PITCH_SLACK:
		return []
	return [local, out_way, off]
