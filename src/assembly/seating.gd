## Which parts of a model sit a fraction of a stud off their studs, and
## where they belong.
##
## Until 2026-10-10 a placement's corner was its cover's, and a part drawn
## inside its footprint — a wing plate's cut edge, a turntable's round top,
## a flag's narrow clip, plant leaves — landed that much off the studs it
## stood on whenever it was placed at whole studs: 2 to 4 LDU. Models
## designed then carry it in their LDraw, and open looking slightly wrong
## with nothing to say why.
##
## A part is moved only where both are true: it is off the half-stud grid
## now, and the old corner's error, undone, puts its studs on stud
## middles. A part placed off the grid on purpose, or by somebody else's
## rules, is left where it is. src/dev/reseat.gd does the same to files;
## the app offers it when such a model is opened (SeatOffer).
class_name Seating
extends RefCounted


## brick id -> the transform that seats it, for every brick that needs it.
static func misplaced(world: BrickWorld, builder: Builder, assistant: Assistant,
		scenery: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var covers: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var mesh: Lbm.PartMesh = builder.library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		var shift: Vector3 = shift_for(mesh, brick.part_id, brick.transform,
			builder, assistant, covers)
		if shift != Vector3.ZERO:
			out[brick.id] = brick.transform.translated(shift)
	return out


## How far a part placed at ``at`` is from where the footprint's corner
## would have put it, when undoing exactly that seats it; zero otherwise.
## In the app's own space: LDraw's z runs the other way.
static func shift_for(mesh: Lbm.PartMesh, part_id: String, at: Transform3D,
		builder: Builder, assistant: Assistant, covers: Dictionary = {}) -> Vector3:
	if not BrickLattice.is_square_to_grid(at.basis):
		return Vector3.ZERO
	var basis: Basis = BrickLattice.snap_basis(at.basis)
	if absf((basis * Vector3.UP).y) < 0.99:
		return Vector3.ZERO
	var key: String = "%s|%s" % [part_id, basis]
	var cover: Vector3i
	if covers.has(key):
		cover = covers[key]
	else:
		var span: Array = builder._cell_span(mesh, Transform3D(basis, Vector3.ZERO))
		cover = Vector3i(0x7FFFFFFF, 0, 0x7FFFFFFF) if span.is_empty() \
			else Vector3i((span[0] as Vector3i).x, 0, (span[0] as Vector3i).z)
		covers[key] = cover
	var footprint: Vector3i = assistant._corner_cell(mesh, part_id, basis)
	var shift := Vector3((cover.x - footprint.x) * BrickLattice.CELL, 0.0,
		(cover.z - footprint.z) * BrickLattice.CELL)
	if shift == Vector3.ZERO:
		return Vector3.ZERO
	if off_the_studs(mesh, at) <= 0.5:
		return Vector3.ZERO
	if off_the_studs(mesh, at.translated(shift)) > 0.5:
		return Vector3.ZERO
	return shift


## How far a part's upward studs stand from the middles of the grid's, in
## LDU, the worst of them; its tubes where it has no studs.
static func off_the_studs(mesh: Lbm.PartMesh, at: Transform3D) -> float:
	for kind: String in ["stud", "tube"]:
		var worst: float = -1.0
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind != kind \
					or absf((at.basis * connector.axis).normalized().y) < 0.99:
				continue
			var where: Vector3 = at * connector.position
			for v: float in [where.x - 10.0, where.z - 10.0]:
				var r: float = fposmod(v, 20.0)
				worst = maxf(worst, minf(r, 20.0 - r))
		if worst >= 0.0:
			return worst
	return 0.0
