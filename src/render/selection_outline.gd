## A box drawn round every brick in the selection.
##
## A selection you cannot see is a trap: the next key press acts on
## whatever you last shift-clicked, which by then may be forty bricks
## ago and off screen. So the outline is not decoration — it is the only
## thing that makes the operations safe to offer.
##
## Drawn as lines rather than as a tinted copy of the bricks. Tinting
## would mean a second MultiMesh per part and colour combination in the
## selection, which for a mixed selection is most of the model again;
## twelve line segments per brick is the same cost whatever is selected.
class_name SelectionOutline
extends MeshInstance3D

## Nudged outward so the outline sits proud of the brick rather than
## fighting its surface for the same pixels.
const SWELL := 1.2

var library: PartLibrary
var world: BrickWorld

var _lines: ImmediateMesh


func _ready() -> void:
	_lines = ImmediateMesh.new()
	mesh = _lines
	# Drawn over whatever it surrounds: an outline hidden by the brick
	# it is outlining tells you nothing.
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color(1.0, 0.95, 0.25)
	paint.no_depth_test = true
	paint.render_priority = 8
	material_override = paint
	visible = false


func show_selection(selection: Dictionary) -> void:
	_lines.clear_surfaces()
	if selection.is_empty() or world == null or library == null:
		visible = false
		return

	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var drawn: int = 0
	for brick_id: int in selection:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		_box(brick.transform, part.bounds)
		drawn += 1
	_lines.surface_end()
	visible = drawn > 0


func _box(at: Transform3D, bounds: AABB) -> void:
	var lo: Vector3 = bounds.position - Vector3.ONE * SWELL
	var hi: Vector3 = bounds.end + Vector3.ONE * SWELL
	var corner := PackedVector3Array()
	for n: int in 8:
		corner.append(at * Vector3(
			hi.x if n & 1 else lo.x,
			hi.y if n & 2 else lo.y,
			hi.z if n & 4 else lo.z))
	# The twelve edges of a box, as pairs of corners that differ in
	# exactly one bit.
	for a: int in 8:
		for bit: int in [1, 2, 4]:
			var b: int = a | bit
			if b == a:
				continue
			_lines.surface_add_vertex(corner[a])
			_lines.surface_add_vertex(corner[b])
