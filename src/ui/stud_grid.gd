## Lines between the studs of the baseplate, for counting them: View, Stud
## grid, or the grid button on the toolbar. Every fourth line is brighter,
## so a wall eight studs long reads at a glance as two squares of four.
##
## Drawn on top of the baseplate rather than the ground under it, which a
## baseplate hides, and over the ground the floor covers where there is no
## baseplate: the model's own plate, or the grid floor's square.
class_name StudGrid
extends MeshInstance3D

var world: BrickWorld
var library: PartLibrary
## The baseplate's bricks: id -> true.
var scenery: Dictionary = {}
## What the model stands on, for the ground when there is no baseplate.
var floor_layer: FloorLayer

var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _material
	visibility_changed.connect(func() -> void:
		if visible:
			redraw())
	if world != null:
		world.rebuilt.connect(func(_b: int, _c: int, _t: int) -> void:
			if visible:
				redraw())
	if floor_layer != null:
		floor_layer.changed.connect(func() -> void:
			if visible:
				redraw())
	if visible:
		redraw()


## Lay the lines over whatever the baseplate covers now.
func redraw() -> void:
	var area: AABB = _ground()
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var step: float = BrickLattice.STUD
	var y: float = area.end.y + 0.15
	var x0: float = floorf(area.position.x / step) * step
	var z0: float = floorf(area.position.z / step) * step
	var x1: float = ceilf(area.end.x / step) * step
	var z1: float = ceilf(area.end.z / step) * step
	var x: float = x0
	while x <= x1 + 0.01:
		_line(lines, Vector3(x, y, z0), Vector3(x, y, z1), x)
		x += step
	var z: float = z0
	while z <= z1 + 0.01:
		_line(lines, Vector3(x0, y, z), Vector3(x1, y, z), z)
		z += step
	lines.surface_end()
	mesh = lines


func _line(lines: ImmediateMesh, from: Vector3, to: Vector3, at: float) -> void:
	var major: bool = is_zero_approx(fposmod(at, BrickLattice.STUD * 4.0))
	var colour := Color(1, 1, 1, 0.5 if major else 0.2)
	lines.surface_set_color(colour)
	lines.surface_add_vertex(from)
	lines.surface_set_color(colour)
	lines.surface_add_vertex(to)


## The top of the baseplate, the ground the floor covers when there is
## none, or a square of 32 studs on the ground when there is neither.
func _ground() -> AABB:
	var box := AABB()
	var first: bool = true
	if world != null and library != null:
		for brick_id: int in scenery:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick == null:
				continue
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh == null:
				continue
			var here: AABB = (brick.transform * mesh.bounds).abs()
			box = here if first else box.merge(here)
			first = false
	if first and floor_layer != null and floor_layer.area.size.length_squared() > 0.0:
		# Just over the top of the model's own plate, or on the ground.
		var lift: float = 0.0 if floor_layer.has_own_plate() else -0.15
		return AABB(floor_layer.area.position + Vector3(0.0, lift, 0.0), floor_layer.area.size)
	if first:
		return AABB(Vector3(-320, -0.15, -320), Vector3(640, 0, 640))
	# The plate's own top, below its studs: a baseplate's bounds include
	# the studs, four LDU proud of the plate.
	box.size.y = maxf(box.size.y - 4.0, 0.0)
	return box
