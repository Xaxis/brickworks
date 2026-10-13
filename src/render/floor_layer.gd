## What the model stands on, put down under it: the baseplate, the grid on
## the ground, or nothing (ModelFloor), as the model's floor says.
##
## A baseplate is real bricks in the world, registered in the lattice like
## any other so a part lands on its studs and a ray stops on it, and kept
## in ModelStore.scenery so it is not saved, counted or selected. The grid
## and the empty floor are not bricks at all: a part aimed at nothing falls
## to the ground plane at y = 0 (Builder.update_preview) and settles on the
## same stud lattice a baseplate's studs are on, so the first part lands
## exactly where it would on a plate.
##
## Changing the floor is one step of the history (Builder "floor"), and so
## is making the baseplate part of the model and back (Builder "scenery"):
## neither moves anything that was built.
class_name FloorLayer
extends Node3D

## How far a stud stands above the top of a plate, in LDU. A baseplate's
## origin is its top; its bounds reach this far above it.
const STUD_HIGH := 4.0
## Studs of ground round a model with no baseplate, each way: the grid's
## extent, and the stud grid's.
const MARGIN := 8
## The least ground there is with no baseplate, in studs a side.
const LEAST_GROUND := 48
const SHADOW_SHADER := preload("res://src/render/floor_shadow.gdshader")
## The render layer the shadow's ground is on, and that only the sun
## lights: the fill and the rim cast no shadows, and lighting it they
## would light the shadow away. Main keeps them off this layer.
const SHADOW_LAYER := 1 << 19
## How long a shadow is against how tall the model is: the sun stands
## about forty degrees up (main.tscn), with some to spare.
const SHADOW_LENGTH := 1.4

var world: BrickWorld
var builder: Builder
var store: ModelStore
var library: PartLibrary
## What is built, without the floor (Main._model_bounds): what an undo of a
## change of floor, or a plate arriving, centres the plates on.
var model_bounds: Callable = Callable()

## The ground laid down, flattened: x and z only, at y = 0 — the plates'
## tops, the model's own baseplate, or the square the grid covers. What
## the stud grid is drawn over, and what a model outgrows (Main
## _ground_for_the_model).
var area: AABB = AABB()

## The floor was put down again: the menus, the properties and the stud
## grid say so.
signal changed

var _grid: MeshInstance3D
## With no plate, the ground is not drawn but the model's shadow is
## (floor_shadow.gdshader), so a part on nothing stands on something rather
## than floating in grey, as Studio's floor and the render's sweep have it.
var _shadow: MeshInstance3D
var _shadow_material: ShaderMaterial
var _ground_material: StandardMaterial3D
var _line_material: StandardMaterial3D
## What the model's bounds were when the floor was last laid.
var _model: AABB = AABB()
## Plates whose geometry has been asked for: laid when it comes.
var _waiting: Dictionary = {}
## A plate taken up, by what it was (part, colour, place), and its number:
## laid again the same, it is the same brick to the history (Builder
## .renumber), so a step that made it part of the model still names it.
var _gone: Dictionary = {}
var _gone_in: int = -1
## The model's own baseplates, and the world they were read from.
var _own: Array[int] = []
var _own_at: Array = []


func _ready() -> void:
	# Lit, so the model's shadow falls on it: by the sun alone, on the
	# shadow's layer, or the fill and rim would light the shadow away.
	_ground_material = StandardMaterial3D.new()
	_ground_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_material.albedo_color = Color(0.97, 0.97, 0.98, 0.55)
	_ground_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.vertex_color_use_as_albedo = true
	_grid = MeshInstance3D.new()
	_grid.name = "GridFloor"
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.layers = SHADOW_LAYER
	_grid.visible = false
	add_child(_grid)
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = SHADOW_SHADER
	_shadow = MeshInstance3D.new()
	_shadow.name = "FloorShadow"
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.material_override = _shadow_material
	_shadow.layers = SHADOW_LAYER
	_shadow.visible = false
	add_child(_shadow)
	if library != null:
		library.fetched.connect(_on_fetched)


## The grid floor's mesh, for a picture to leave out (Picture.aside).
func grid_node() -> Node3D:
	return _grid


## The shadow on the ground with no plate, for a picture to leave out too.
func shadow_node() -> Node3D:
	return _shadow


static func is_upright(at: Transform3D) -> bool:
	return at.basis.orthonormalized().y.dot(Vector3.UP) > 0.999


## Whether this brick is a baseplate lying flat with its top on the ground:
## what a model that carries its own baseplate has at its bottom.
func is_ground_plate(brick: BrickWorld.Brick) -> bool:
	if brick == null:
		return false
	var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
	return info != null and info.category == "Baseplate" \
		and is_upright(brick.transform) and absf(brick.transform.origin.y) < 0.5


## The baseplates the model carries itself, at its bottom: a set's own
## plate, or the scenery plate made part of the model. While there is one
## no scenery plate is laid under it, so a model that came with its plate
## never stands on two.
func own_plates() -> Array[int]:
	var at: Array = [world.generation(), world.revision, store.scenery.size()]
	if at == _own_at:
		return _own
	_own_at = at
	_own = []
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id) and is_ground_plate(brick):
			_own.append(brick.id)
	return _own


func has_own_plate() -> bool:
	return not own_plates().is_empty()


## Put the model's floor down under [param model], the bounds of what is
## built: plates centred on it, as many as cover it, or the grid round it.
## What is built never moves.
func lay(model: AABB) -> void:
	_model = model
	var chosen: ModelFloor = store.model_floor
	var own: Array[int] = own_plates()
	var wanted: Array = []
	if chosen.is_plate() and own.is_empty():
		wanted = _plates_for(chosen, model)
	_put_plates(wanted)
	if not own.is_empty():
		area = _flat_bounds(own)
	elif not chosen.is_plate():
		area = _ground_round(model)
	_draw_grid(chosen.kind == ModelFloor.GRID)
	_catch_shadow(chosen.kind == ModelFloor.NONE)
	changed.emit()


## The shadow's ground kept round [param model] as it is built: with no
## plate nothing else is laid again when a model grows, and its shadow
## would fall off the edge of what catches it.
func follow(model: AABB) -> void:
	if store.model_floor.kind != ModelFloor.NONE or model == _model:
		return
	_model = model
	_catch_shadow(true)


## Whether the floor laid still fits [param model]: a model built past the
## edge of its baseplate or its grid gets more (Main._ground_for_the_model);
## one on its own baseplate, or on nothing, never needs any.
func covers(model: AABB) -> bool:
	if store.model_floor.kind == ModelFloor.NONE or has_own_plate():
		return true
	if area.size.length_squared() <= 0.0:
		return false
	return area.encloses(AABB(Vector3(model.position.x, 0.0, model.position.z),
		Vector3(model.size.x, 0.0, model.size.z)))


## Whether what is laid is what the floor says should be: a scenery plate
## where the model has its own (an undo brought it back), or none where
## the model's own was taken off.
func is_stale() -> bool:
	if not _waiting.is_empty():
		return false
	var wants_plate: bool = store.model_floor.is_plate() and not has_own_plate()
	return wants_plate == store.scenery.is_empty()


## The floor as the history keeps it: every word of it, so that undoing
## No floor puts back the baseplate's size and colour too.
func state() -> String:
	return store.model_floor.whole_words()


## Put this floor down and return the one it replaced: Builder.floor_hook,
## what an undo of a change of floor calls.
func put(words: Variant) -> Variant:
	var was: String = state()
	var chosen: ModelFloor = ModelFloor.parse(str(words))
	if chosen != null:
		store.model_floor = chosen
	lay(_now())
	return was


## What is built now, or what it was when last laid when nobody says.
func _now() -> AABB:
	return model_bounds.call() if model_bounds.is_valid() else _model


## Change what the model stands on, as one step of the history, the plates
## centred on what is built. Returns false when it is already on that floor.
func choose(chosen: ModelFloor) -> bool:
	if chosen == null or chosen.same_as(store.model_floor):
		return false
	var was: Variant = put(chosen.whole_words())
	builder.record([{"undo": "floor", "floor": was}], "floor: %s" % chosen.words().to_lower())
	return true


## Make the baseplate part of the model: the plates under it become parts
## of it, counted in the parts list and the shop lists, the first step of
## the booklet, and saved with it. One step of the history. Laid first
## when the floor was not a baseplate. Returns how many plates it took in.
func adopt() -> int:
	if has_own_plate():
		return 0
	var steps: Array = []
	if not store.model_floor.is_plate():
		# The size and colour it last had, or the dark green 32 x 32.
		var plate: ModelFloor = store.model_floor.copy()
		plate.kind = ModelFloor.BASEPLATE
		steps.append({"undo": "floor", "floor": put(plate.whole_words())})
	var taken: Array[int] = []
	for brick_id: int in store.scenery.keys():
		if world.get_brick(brick_id) == null:
			continue
		store.scenery.erase(brick_id)
		taken.append(brick_id)
		steps.push_front({"undo": "scenery", "brick": brick_id, "scenery": true})
	if taken.is_empty():
		return 0
	_own_at = []
	builder.record(steps, "made the baseplate part of the model")
	changed.emit()
	return taken.size()


## The other way: the model's own baseplates become the floor again, not
## counted and not saved, and the floor a baseplate of their size and
## colour. Nothing moves. One step of the history.
func release() -> int:
	var own: Array[int] = own_plates()
	if own.is_empty():
		return 0
	var first: BrickWorld.Brick = world.get_brick(own[0])
	var steps: Array = []
	for brick_id: int in own:
		store.scenery[brick_id] = true
		builder.selection.erase(brick_id)
		steps.append({"undo": "scenery", "brick": brick_id, "scenery": false})
	var size: Vector2i = ModelFloor.size_of(library.parts.get(first.part_id), first.transform.basis)
	var plate: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE,
		size.x if own.size() == 1 else store.model_floor.across,
		size.y if own.size() == 1 else store.model_floor.deep, first.color_code)
	_own_at = []
	area = _flat_bounds(own)
	steps.append({"undo": "floor", "floor": state()})
	# The floor's words only: these plates are the floor now, and laying it
	# again would take them up for fresh ones.
	store.model_floor = plate
	builder.record(steps, "made the baseplate the floor again")
	builder.selection_changed.emit(builder.selection.size())
	changed.emit()
	return own.size()


## The plates a baseplate floor is, centred on the model and repeated to
## cover it: [[part, colour, transform]].
func _plates_for(chosen: ModelFloor, model: AABB) -> Array:
	var size: Vector2i = chosen.laid_size()
	var tile := Vector2(size.x * BrickLattice.STUD, size.y * BrickLattice.STUD)
	var wide: int = 1
	var deep: int = 1
	if model.size.x > 0.0 or model.size.z > 0.0:
		wide = maxi(int(ceil(model.size.x / tile.x)), 1)
		deep = maxi(int(ceil(model.size.z / tile.y)), 1)
	# Centred on the model rather than on the origin, snapped to whole
	# studs so the plates meet the grid; neighbours are a whole plate
	# apart, so snapping the first snaps them all.
	var middle: Vector3 = model.get_center()
	var first_x: float = snappedf(middle.x - float(wide - 1) * tile.x * 0.5, BrickLattice.STUD)
	var first_z: float = snappedf(middle.z - float(deep - 1) * tile.y * 0.5, BrickLattice.STUD)
	area = AABB(Vector3(first_x - tile.x * 0.5, 0.0, first_z - tile.y * 0.5),
		Vector3(float(wide) * tile.x, 0.0, float(deep) * tile.y))
	var pieces: Array = chosen.plates()
	var out: Array = []
	for column: int in wide:
		for row: int in deep:
			var centre := Vector3(first_x + float(column) * tile.x, 0.0,
				first_z + float(row) * tile.y)
			for piece: Array in pieces:
				var turned: Basis = Basis(Vector3.UP, PI * 0.5) if bool(piece[2]) else Basis.IDENTITY
				out.append([str(piece[0]), chosen.colour,
					Transform3D(turned, centre + (piece[1] as Vector3))])
	return out


## Make the scenery these plates and no others. A plate already down
## where one is wanted stays, under its number.
func _put_plates(wanted: Array) -> void:
	if _gone_in != world.generation():
		_gone.clear()
		_gone_in = world.generation()
	var standing: Dictionary = {}  ## key -> brick id
	for brick_id: int in store.scenery.keys():
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null:
			store.scenery.erase(brick_id)
			continue
		var key: String = _key(brick.part_id, brick.color_code, brick.transform)
		if standing.has(key):
			_take_up(brick_id, "")
			continue
		standing[key] = brick_id
	var adding: Array = []
	for plate: Array in wanted:
		var key: String = _key(plate[0], plate[1], plate[2])
		if standing.has(key):
			standing.erase(key)
		else:
			adding.append(plate)
	# The ground that was here goes, brick and record together. A plate
	# dropped from the set alone becomes an ordinary brick under
	# everything, in the way of every edit: two designs reported "a stray
	# baseplate part sitting below ground level", and were right. And
	# BrickWorld numbers from one again after a clear, so an id left in
	# the set names a brick placed later, which is then left out of Save,
	# the parts list and the booklet, silently.
	for key: String in standing:
		_take_up(int(standing[key]), key)
	for plate: Array in adding:
		var part_id: String = plate[0]
		var at: Transform3D = plate[2]
		var brick_id: int = world.add_brick(part_id, int(plate[1]), at)
		if brick_id == 0:
			# Not to hand yet, which on the web is most parts: laid when
			# it comes.
			_waiting[part_id] = true
			library.request_mesh(part_id, true)
			continue
		builder.register(brick_id, part_id, at)
		store.scenery[brick_id] = true
		var key: String = _key(part_id, int(plate[1]), at)
		if _gone.has(key):
			builder.renumber(int(_gone[key]), brick_id)
			_gone.erase(key)
	_own_at = []


func _take_up(brick_id: int, key: String) -> void:
	builder.lattice.release(brick_id)
	world.remove_brick(brick_id)
	store.scenery.erase(brick_id)
	builder.selection.erase(brick_id)
	if not key.is_empty():
		_gone[key] = brick_id


static func _key(part_id: String, colour: int, at: Transform3D) -> String:
	return "%s|%d|%.1f %.1f %.1f|%.2f %.2f" % [part_id, colour,
		at.origin.x, at.origin.y, at.origin.z, at.basis.x.x, at.basis.x.z]


func _on_fetched(part_id: String) -> void:
	if not _waiting.has(part_id):
		return
	_waiting.erase(part_id)
	if store.model_floor.is_plate():
		lay(_now())


## The tops of these bricks, flattened.
func _flat_bounds(ids: Array[int]) -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id) if brick != null else null
		if info == null:
			continue
		var here: AABB = (brick.transform * info.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return AABB(Vector3(box.position.x, 0.0, box.position.z), Vector3(box.size.x, 0.0, box.size.z))


## The ground round a model with no baseplate: its footprint and a margin,
## never less than LEAST_GROUND studs a side, on whole groups of four
## studs so the brighter lines of the grid land where they always do.
func _ground_round(model: AABB) -> AABB:
	var four: float = BrickLattice.STUD * 4.0
	var least: float = LEAST_GROUND * BrickLattice.STUD
	var middle := Vector3(model.get_center().x, 0.0, model.get_center().z) \
		if model.size.length_squared() > 0.0 else Vector3.ZERO
	var half_x: float = maxf(model.size.x * 0.5 + MARGIN * BrickLattice.STUD, least * 0.5)
	var half_z: float = maxf(model.size.z * 0.5 + MARGIN * BrickLattice.STUD, least * 0.5)
	var x0: float = floorf((middle.x - half_x) / four) * four
	var z0: float = floorf((middle.z - half_z) / four) * four
	var x1: float = ceilf((middle.x + half_x) / four) * four
	var z1: float = ceilf((middle.z + half_z) / four) * four
	return AABB(Vector3(x0, 0.0, z0), Vector3(x1 - x0, 0.0, z1 - z0))


## The ground the shadow falls on, under a model on no floor: round the
## model and as far out as its shadow reaches, fading to nothing there.
## Just under the parts' undersides at zero. (On the grid floor the grid's
## own ground takes the shadow.) One quad, drawn only when the view is.
func _catch_shadow(on: bool) -> void:
	_shadow.visible = on
	if not on:
		return
	var middle := Vector2(_model.get_center().x, _model.get_center().z) \
		if _model.size.length_squared() > 0.0 else Vector2(area.get_center().x, area.get_center().z)
	var near: float = Vector2(_model.size.x, _model.size.z).length() * 0.5 + BrickLattice.STUD * 2.0
	var far: float = near + maxf(_model.size.y * SHADOW_LENGTH, BrickLattice.STUD * 6.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(far * 2.0, far * 2.0)
	_shadow.mesh = plane
	_shadow.position = Vector3(middle.x, -0.3, middle.y)
	_shadow_material.set_shader_parameter("middle", middle)
	_shadow_material.set_shader_parameter("near_radius", near)
	_shadow_material.set_shader_parameter("far_radius", far)


## The grid floor: a faint ground with a line between every pair of
## studs, every fourth brighter, as the stud grid draws them.
func _draw_grid(on: bool) -> void:
	_grid.visible = on
	if not on:
		_grid.mesh = null
		return
	var mesh := ImmediateMesh.new()
	var x0: float = area.position.x
	var z0: float = area.position.z
	var x1: float = area.end.x
	var z1: float = area.end.z
	# Under the parts' undersides, which rest at zero, so the two never
	# fight over the same depth.
	var low: float = -0.6
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ground_material)
	for corner: Vector3 in [Vector3(x0, low, z0), Vector3(x1, low, z0), Vector3(x1, low, z1),
			Vector3(x0, low, z0), Vector3(x1, low, z1), Vector3(x0, low, z1)]:
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_add_vertex(corner)
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_material)
	var y: float = low + 0.2
	var step: float = BrickLattice.STUD
	var x: float = x0
	while x <= x1 + 0.01:
		_line(mesh, Vector3(x, y, z0), Vector3(x, y, z1), x)
		x += step
	var z: float = z0
	while z <= z1 + 0.01:
		_line(mesh, Vector3(x0, y, z), Vector3(x1, y, z), z)
		z += step
	mesh.surface_end()
	_grid.mesh = mesh


static func _line(mesh: ImmediateMesh, from: Vector3, to: Vector3, at: float) -> void:
	var major: bool = is_zero_approx(fposmod(at, BrickLattice.STUD * 4.0))
	var colour := Color(0.22, 0.26, 0.33, 0.42 if major else 0.16)
	mesh.surface_set_color(colour)
	mesh.surface_add_vertex(from)
	mesh.surface_set_color(colour)
	mesh.surface_add_vertex(to)
