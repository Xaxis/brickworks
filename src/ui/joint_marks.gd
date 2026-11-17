## View, Connection points (APP_UX9 jointmarks): where a part connects,
## marked in the window. A builder aiming a pin at the third hole of a beam
## counted holes; StudWorx marks every opening (11-12 to 11-14), and
## Brickworks had the points only as a numbered picture for a session
## (where_to_attach).
##
## On out of the box while a part is in hand, and for the part under the
## pointer; View, Connection points turns it off (ShellPrefs "joint_marks").
## Each kind at its own size, read from the part as the hand seats it
## (JointSnap.ends_for, the catalogue's studs and anti-studs): what goes in
## is filled, a stud, a pin, an axle (its cross), a bar, a ball; what takes
## one is hollow, a ring whose inside is the size of what goes in it, an
## anti-stud, a pin hole, an axle hole (a cross), a clip, a socket. So a
## pin seated in a hole shows its filled end inside the hole's ring.
##
## Beyond StudWorx's:
## - The end of the part in hand that goes onto the joint it is aimed at is
##   amber, drawn over everything, so the end that leads is never in doubt
##   (an axle-pin, a beam onto two pins).
## - With a part in hand, what it can take is blue and what it cannot is
##   faint grey: a pin over a brick sees the brick's holes blue and its studs
##   grey (JointSnap.mates, the hand's studs and anti-studs).
## - A mark is blue in a dark edge a pixel and a quarter wide, whatever the
##   zoom: the blue reads on a dark part and a dark backdrop, the edge on a
##   white part and the light studio backdrop (Look's).
## - It lies on its face, square to its joint, so a side hole reads as a
##   side's; it fades as its face turns edge on and is gone from behind, and
##   what is in front of it hides it. Balls and sockets face the eye, bars
##   and clips lie along their length.
##
## How many: the marks of the parts within REACH of the hand (four studs
## past the part in hand), nearest first, MOST at most; a part with more
## than BIG (a baseplate in the model) only those within REACH of where it
## is pointed at. Drawn as one batch of flat quads (a MultiMesh, the shapes
## worked out in the shader), worked out again only when the hand moves two
## studs or the model changes: a frame's own cost is the drawing, measured
## in jointmarks_probe on the car and on Orthanc.
##
## Nothing written: the marks are drawn in the builder (Shell), which a
## picture puts aside (Picture.aside); a session's picture has them only
## when view_model asks for marks (for_picture). No mark is saved, rendered
## or drawn in a booklet, which draw worlds of their own.
class_name JointMarks
extends Node3D

## What a mark is drawn as, in the shader.
enum Shape { DISC, RING, CROSS, CROSS_RING, BAR, BAR_RING }
## How it faces: flat on its face, square to its joint's axis (gone from
## behind); toward the eye (a ball); toward the eye but gone from behind its
## mouth (a socket); along its length, its width toward the eye (a bar, a
## clip); flat, seen from either side (the hand's, over everything).
enum Facing { FLAT, EYE, EYE_MOUTH, ALONG, FLAT_BOTH }
## Whom it is for: a point the hand can take (or every point, with nothing
## in hand), one it cannot, the hand's own end.
enum Role { TAKES, NOT_TAKEN, HAND }

## A stud's radius (4.8 mm across), and the inside of what takes one; a
## pin's and a pin hole's are JointSnap.PIN_ROUND, the same.
const STUD_R := 6.0
## How far a stud stands over its base: its mark is on its top.
const STUD_TALL := 4.0
## How wide a hollow mark's ring is, LDU: a Technic hole's counterbore past
## its bore (6.2 mm across against 4.8).
const BAND := 1.75
## A hinge's mark, LDU: a hinge pin is a bar's size (3.2 mm).
const HINGE_R := 4.0
## How far toward the eye a mark on a face is drawn, LDU, so the face never
## covers it; along the eye's own line, so it stays where it is on screen.
const PULL := 1.5
## Round the part in hand, LDU (four studs): the parts whose marks are drawn.
const REACH := 80.0
## The most marks drawn round the hand; nearest parts first.
const MOST := 2000
## A part with more marks than this has only those within REACH of where it
## is pointed at drawn: a baseplate in the model has 2,048.
const BIG := 96
## How far the hand moves before the parts round it are found again, LDU.
const STEP := 40.0
## The most marks a session's picture draws (view_model marks=true).
const PICTURE_MOST := 30000
## The most marks worked out afresh in a frame: the hand moving fast over a
## big model meets new parts every frame, and the nearest are marked at once,
## the rest over the next frames.
const BUDGET := 400

## How many times the model's marks were worked out, and how long that took
## in all and at the longest, microseconds (jointmarks_probe).
static var worked: int = 0
static var work_usec: int = 0
static var most_usec: int = 0

## The shader, its render mode filled in: the hand's draws over everything.
const CODE := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform,
	fog_disabled, shadows_disabled%s;

// A mark is a quad round its shape: [margin] times its round's radius on
// each side and its straight part's half length past that along it.
uniform vec4 takes : source_color = vec4(0.12, 0.58, 1.0, 0.92);
uniform vec4 not_taken : source_color = vec4(0.6, 0.64, 0.7, 0.6);
uniform vec4 hand : source_color = vec4(1.0, 0.72, 0.12, 1.0);
uniform vec4 edge : source_color = vec4(0.03, 0.05, 0.11, 0.92);
uniform float band = 1.75;
uniform float arm = 0.375;
uniform float margin = 1.5;
uniform float edge_px = 1.25;

varying flat vec4 v_kind;
varying flat vec2 v_half;
varying flat float v_fade;
varying vec2 v_at;

void vertex() {
	vec3 sx = MODEL_MATRIX[0].xyz;
	vec3 sy = MODEL_MATRIX[1].xyz;
	float hx = length(sx);
	float hy = length(sy);
	mat3 turn = mat3(VIEW_MATRIX);
	vec3 centre = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	bool square = PROJECTION_MATRIX[3][3] != 0.0;
	vec3 eye = square ? vec3(0.0, 0.0, 1.0) : normalize(-centre);
	float facing = dot(normalize(turn * MODEL_MATRIX[2].xyz), eye);
	int way = int(INSTANCE_CUSTOM.z + 0.5);
	float straight = max(hx - hy, 0.0);
	vec3 at;
	if (way == 0 || way == 4) {
		at = centre + turn * (sx * VERTEX.x + sy * VERTEX.y);
		v_fade = smoothstep(0.06, 0.3, way == 4 ? abs(facing) : facing);
	} else if (way == 3) {
		// Along its length, foreshortened as the eye sees it, its width to the eye.
		vec3 along = normalize(turn * sx);
		vec3 seen = along - eye * dot(along, eye);
		float s = length(seen);
		seen = s > 0.001 ? seen / s : vec3(1.0, 0.0, 0.0);
		vec3 across = normalize(cross(seen, eye));
		straight *= s;
		at = centre + seen * VERTEX.x * (straight + hy) + across * VERTEX.y * hy;
		v_fade = 1.0;
	} else {
		at = centre + vec3(VERTEX.x * hx, VERTEX.y * hy, 0.0);
		v_fade = way == 2 ? smoothstep(-0.35, 0.05, facing) : 1.0;
	}
	v_at = VERTEX.xy * vec2(straight + hy, hy);
	v_half = vec2(straight, hy / margin);
	v_kind = INSTANCE_CUSTOM;
	vec3 toward = square ? vec3(0.0, 0.0, 1.0) : normalize(-at);
	VERTEX = at + toward * INSTANCE_CUSTOM.w;
}

float box_sd(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float cross_sd(vec2 p, float l, float w) {
	return min(box_sd(p, vec2(l, w)), box_sd(p, vec2(w, l)));
}

float bar_sd(vec2 p, float a, float r) {
	return length(vec2(max(abs(p.x) - a, 0.0), p.y)) - r;
}

// A band [band] wide outside the shape whose distance is [d].
float hollow(float d) {
	return abs(d - band * 0.5) - band * 0.5;
}

void fragment() {
	int shape = int(v_kind.x + 0.5);
	float a = v_half.x;
	float r = v_half.y;
	vec2 p = v_at;
	float d;
	if (shape == 0) {
		d = length(p) - r;
	} else if (shape == 1) {
		d = hollow(length(p) - (r - band));
	} else if (shape == 2) {
		d = cross_sd(p, r, r * arm);
	} else if (shape == 3) {
		float inner = r - band;
		d = hollow(cross_sd(p, inner, inner * arm));
	} else if (shape == 4) {
		d = bar_sd(p, a, r);
	} else {
		d = hollow(bar_sd(p, a, r - band));
	}
	// Its fill, and round it an edge [edge_px] wide at any zoom.
	float px = max(fwidth(d), 0.0001);
	float fill_in = clamp(0.5 - d / px, 0.0, 1.0);
	float edge_in = clamp(0.5 - (d - edge_px * px) / px, 0.0, 1.0);
	if (edge_in <= 0.001 || v_fade <= 0.001) {
		discard;
	}
	int role = int(v_kind.y + 0.5);
	vec4 fill = role == 0 ? takes : (role == 1 ? not_taken : hand);
	float faint = role == 1 ? not_taken.a : 1.0;
	float share = fill_in / edge_in;
	ALBEDO = mix(edge.rgb, fill.rgb, share);
	ALPHA = edge_in * mix(edge.a * faint, fill.a, share) * v_fade;
}
"""

## The quad a mark's shape is drawn in, round its round's radius each side.
const MARGIN := 1.5

var builder: Builder
var world: BrickWorld
var library: PartLibrary
## The model's floor and what else is not the model (ModelStore.scenery).
var scenery: Dictionary = {}
## The part under the pointer with nothing in hand (Main's select hover).
var hovered: Callable = func() -> int: return 0
## The view, to find where a big part is pointed at.
var camera: CadCamera

var on: bool = true

var _model: MultiMeshInstance3D
var _hand: MultiMeshInstance3D
## What the model's marks were last worked out for, and the hand's.
var _model_for: Array = []
var _hand_for: Array = []
## Each brick's marks in the world, as a buffer's rows, by brick id:
## [part, where, the hand's kinds' key, PackedFloat32Array].
var _rows: Dictionary = {}
## Whether the last working out stopped at BUDGET with parts still to mark.
var _short: bool = false

## Each part's marks in its own frame, by part id (see [method marks_of]).
static var _local: Dictionary = {}
## A big part's marks by where they are (see [method _near_marks]).
static var _cells: Dictionary = {}
static var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_model = _batch(false)
	_hand = _batch(true)
	add_child(_model)
	add_child(_hand)
	if library != null and not library.exact_fetched.is_connected(_on_exact):
		library.exact_fetched.connect(_on_exact)


## A part's exact shape come in a browser: its hinges and balls are marks
## now (JointSnap.ends_for reads them from it).
func _on_exact(part_id: String) -> void:
	_local.erase(part_id)
	_cells.erase(part_id)
	_rows.clear()
	_model_for = []


func set_on(value: bool) -> void:
	on = value
	_model_for = []
	_hand_for = []
	set_process(value)
	if not value:
		_fill(_model, PackedFloat32Array())
		_fill(_hand, PackedFloat32Array())


func _process(_delta: float) -> void:
	if builder == null or world == null or library == null:
		return
	_follow_model()
	_follow_hand()


# -- what is marked --------------------------------------------------------------


## The part in hand while its ghost shows, "" when there is none: one part,
## not a figure, a sticker or several carried.
func _held() -> String:
	if not on or not builder.has_preview() or builder.is_carrying() \
			or not builder.held_figure.is_empty() or library.sticks(builder.held_part):
		return ""
	return builder.held_part


## The model's marks: round the hand, or the part under the pointer.
func _follow_model() -> void:
	var held: String = _held()
	var focus := Vector3.ZERO
	var under: int = 0
	var near: bool = false
	if not on:
		pass
	elif not held.is_empty():
		var part: Lbm.PartMesh = library.mesh_for(held)
		focus = builder.ghost_transform() * (part.bounds.get_center() if part != null else Vector3.ZERO)
		under = builder.hovered_brick()
		near = true
	elif builder.is_carrying() and builder.has_preview():
		focus = builder.carrying.pivot()
		under = builder.hovered_brick()
		held = "*"
		near = true
	else:
		under = maxi(int(hovered.call()), 0)
		var brick: BrickWorld.Brick = world.get_brick(under) if under > 0 else null
		# A big part's marks round where the pointer is on it.
		if brick != null and marks_of(library, brick.part_id).size() > BIG:
			focus = _pointed_at(under)
			near = true
	var wanted: Array = [on, held, under, Vector3i((focus / STEP).floor()) if near else Vector3i.ZERO,
		world.get_instance_id(), world.generation(), world.revision, builder.lattice.revision]
	if wanted == _model_for:
		return
	var began: int = Time.get_ticks_usec()
	_model_for = wanted
	var ids: Array = []
	if held.is_empty():
		if under > 0:
			ids = [under]
	else:
		ids = _round(focus, under, held)
	_fill(_model, _rows_for(ids, held if held != "*" else "", focus))
	# The rest of what is round the hand next frame, nearest first now.
	if _short:
		_model_for = []
	var took: int = Time.get_ticks_usec() - began
	worked += 1
	work_usec += took
	most_usec = maxi(most_usec, took)


## The parts within REACH of the part in hand at [param focus], and the one
## it is aimed at, nearest first.
func _round(focus: Vector3, under: int, held: String) -> Array:
	var box := AABB(focus, Vector3.ZERO)
	var part: Lbm.PartMesh = library.mesh_for(held) if held != "*" else null
	if part != null:
		box = builder.ghost_transform() * part.bounds
	box = box.grow(REACH)
	var lo: Vector3i = BrickLattice.to_cell(box.position)
	var hi: Vector3i = BrickLattice.to_cell(box.end) + Vector3i.ONE
	var found: Array = []
	var seen: Dictionary = {}
	for raw: int in builder.lattice.near_bounds(PackedInt32Array([lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])):
		if not seen.has(raw):
			seen[raw] = true
			found.append(raw)
	if under > 0 and not seen.has(under):
		found.append(under)
	# Nearest first, sorted natively: each key its distance, a sixteenth of
	# an LDU at a time, over its place in the list (Orthanc has hundreds of
	# parts round the hand; a sort by a lambda was most of a frame's work).
	var keys := PackedInt64Array()
	keys.resize(found.size())
	for n: int in found.size():
		var brick: BrickWorld.Brick = world.get_brick(found[n])
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		var far: float = 0.0 if found[n] == under else (1.0e6 if mesh == null
			else (brick.transform * mesh.bounds.get_center()).distance_to(focus))
		keys[n] = (int(far * 16.0) << 24) | n
	keys.sort()
	var out: Array = []
	out.resize(found.size())
	for n: int in keys.size():
		out[n] = found[keys[n] & 0xFFFFFF]
	return out


## Where the pointer meets [param under], for a big part's marks round it; the
## part's middle when it cannot be found.
func _pointed_at(under: int) -> Vector3:
	var brick: BrickWorld.Brick = world.get_brick(under) if under > 0 else null
	if brick == null:
		return Vector3.ZERO
	if camera != null:
		var at: Vector2 = get_viewport().get_mouse_position()
		var from: Vector3 = camera.ray_origin(at)
		var way: Vector3 = camera.ray_normal(at)
		var hit: BrickLattice.Hit = builder.lattice.raycast(from, way)
		if hit.is_valid() and hit.brick_id == under:
			return from + way * hit.distance
	var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
	return brick.transform * (mesh.bounds.get_center() if mesh != null else Vector3.ZERO)


## The marks of [param ids], in turn, MOST at most, each blue where the part
## [param held] takes it and grey where it does not (blue for all with
## nothing held); a big part's within REACH of [param focus] alone.
func _rows_for(ids: Array, held: String, focus: Vector3) -> PackedFloat32Array:
	var takes: Callable = _takes_of(held)
	var key: String = held
	var out := PackedFloat32Array()
	var count: int = 0
	var fresh: int = 0
	_short = false
	if _rows.size() > 4096:
		_rows.clear()
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if brick == null or brick.hidden or scenery.has(brick_id) \
				or builder.lattice.unseen.has(brick_id) or builder.lattice.see_through.has(brick_id) \
				or builder.lattice.ahead.has(brick_id):
			continue
		# A part's first marks work out its joints (JointSnap.ends_for), up to
		# 30 ms on the car's first frame with the hand: two a frame past the
		# first, the rest on the frames after.
		var cold: bool = not _local.has(brick.part_id)
		if cold and fresh >= BUDGET / 2:
			_short = true
			break
		var marks: Array = marks_of(library, brick.part_id)
		if cold:
			fresh += BUDGET / 4
		if marks.is_empty():
			continue
		var rows: PackedFloat32Array
		if marks.size() > BIG:
			rows = _rows_of(_near_marks(brick.part_id, marks, brick.transform.affine_inverse() * focus),
				brick.transform, takes, focus)
		else:
			var kept: Array = _rows.get(brick_id, [])
			if kept.size() == 4 and kept[0] == brick.part_id and kept[1] == brick.transform \
					and kept[2] == key:
				rows = kept[3]
			elif fresh + marks.size() > BUDGET and fresh > 0:
				_short = true
				break
			else:
				rows = _rows_of(marks, brick.transform, takes)
				_rows[brick_id] = [brick.part_id, brick.transform, key, rows]
				fresh += marks.size()
		var more: int = rows.size() / 16
		if count + more > MOST:
			break
		out.append_array(rows)
		count += more
	return out


## Whether the part [param held] takes a mark: a mark -> bool. Every mark
## with nothing held.
func _takes_of(held: String) -> Callable:
	if held.is_empty():
		return func(_mark: Array) -> bool: return true
	var ends: Array = JointSnap.ends_for(library, held)
	var part: Lbm.PartMesh = library.mesh_for(held)
	var has_studs: bool = false
	if part != null:
		for connector: Lbm.Connector in part.connectors:
			has_studs = has_studs or (connector.kind == "stud" and connector.gender == "male")
	var has_anti: bool = part != null and not part.sockets.is_empty()
	return func(mark: Array) -> bool:
		match str(mark[4]):
			"stud":
				return has_anti
			"anti-stud":
				return has_studs
		if mark[7] and has_studs:
			return true
		var site: JointSnap.End = mark[5]
		if site == null:
			return false
		for end: JointSnap.End in ends:
			if JointSnap.mates(end, site):
				return true
		return false


# -- the hand's own end ------------------------------------------------------------


## The end of the part in hand on the joint it is aimed at, amber, over
## everything.
func _follow_hand() -> void:
	var end: JointSnap.End = builder.joint_end() if not _held().is_empty() else null
	var at: Transform3D = builder.ghost_transform()
	var wanted: Array = [on, end.kind, end.at, end.axis, at] if end != null else [on]
	if wanted == _hand_for:
		return
	_hand_for = wanted
	if end == null:
		_fill(_hand, PackedFloat32Array())
		return
	var marks: Array = []
	_end_marks(end, marks, true)
	var rows := PackedFloat32Array()
	for mark: Array in marks:
		_row(rows, at * (mark[3] as Transform3D), mark, Role.HAND)
	_fill(_hand, rows)


# -- a part's marks ------------------------------------------------------------------


## Every mark of [param part_id] in its own frame, worked out once: each
## [shape, facing, pull, where (its basis the shape's half sizes across, its
## z the joint's axis), kind, the JointSnap end or null, its middle, whether
## it is an anti-stud as well (a Technic hole's mouth underneath)].
static func marks_of(library: PartLibrary, part_id: String) -> Array:
	var known: Variant = _local.get(part_id)
	if known != null:
		return known
	var part: Lbm.PartMesh = library.mesh_for(part_id)
	if part == null:
		return []
	var out: Array = []
	for connector: Lbm.Connector in part.connectors:
		if connector.kind != "stud" or connector.gender != "male":
			continue
		var axis: Vector3 = connector.axis.normalized()
		out.append(_mark("stud", null, Shape.DISC, Facing.FLAT, PULL,
			connector.position + axis * STUD_TALL, axis, STUD_R))
	# The hollows underneath that take a stud: the part's own record of them,
	# as the builder seats a part by them (OpenPoints reads them so).
	var bottom: float = part.bounds.position.y
	for socket: Vector2 in part.sockets:
		out.append(_mark("anti-stud", null, Shape.RING, Facing.FLAT, PULL,
			Vector3(socket.x, bottom, socket.y), Vector3.DOWN, STUD_R + BAND))
	var ends: Array = JointSnap.ends_for(library, part_id)
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	var clip: bool = info != null and info.name.to_lower().contains("clip")
	for end: JointSnap.End in ends:
		if end.kind == "bore" and not clip:
			continue
		_end_marks(end, out, false)
	# A Technic hole's mouth underneath is an anti-stud too (a stud fits it):
	# one mark, the hole's, taken by a pin or by a stud, at the hole's own
	# middle (the part's record of its anti-studs is to the lattice's 2 LDU,
	# on each way: a 32524's are 2 LDU along from its holes, a 15100's 2
	# across and 2 along).
	var anti: Array = []
	for mark: Array in out:
		if mark[4] == "anti-stud":
			anti.append(mark)
	for mark: Array in out:
		if mark[4] != "pin_hole":
			continue
		for under: Array in anti:
			if (under[6] as Vector3).distance_to(mark[6]) < BrickLattice.CELL * 1.5 + 0.5 \
					and (under[3] as Transform3D).basis.z.dot((mark[3] as Transform3D).basis.z) > 0.9:
				mark[7] = true
				out.erase(under)
				anti.erase(under)
				break
	# Where a pin or an axle would lie between studs, the part's record has
	# anti-studs along its round's side: marked, they stood off a pin put
	# upright as rings in the air, and the MCP walk's session took them for
	# a fault. A pin or an axle is marked by its ends.
	for under: Array in anti:
		if on_round(ends, under[6]):
			out.erase(under)
	# A bore on a part that is not a clip is a hollow a bar goes into by its
	# end (a hollow stud's, a pin's middle): a ring at each open mouth, on
	# the part's face, but where a stud, a pin or an axle ends there, whose
	# mark it is already.
	if not clip:
		for end: JointSnap.End in ends:
			if end.kind != "bore":
				continue
			for side: float in [0.0, 1.0]:
				var mouth: Vector3 = end.at + end.axis * end.reach * side
				var out_of: Vector3 = -end.axis if side == 0.0 else end.axis
				if not _on_face(part.bounds, mouth, out_of) or _male_at(out, mouth):
					continue
				out.append(_mark("hollow", end, Shape.RING, Facing.FLAT, PULL, mouth, out_of,
					end.radius + BAND))
	_local[part_id] = out
	return out


## Whether [param at] lies along the side of one of [param ends]' pins or
## axles, within a pin's round and a lattice step of its shaft.
static func on_round(ends: Array, at: Vector3) -> bool:
	for end: JointSnap.End in ends:
		if not end.is_male():
			continue
		var from: Vector3 = end.at - end.axis * end.back
		var to: Vector3 = end.at + end.axis * end.reach
		var run: Vector3 = to - from
		var along: float = 0.0 if run.length_squared() < 0.001 \
			else clampf((at - from).dot(run) / run.length_squared(), 0.0, 1.0)
		if at.distance_to(from + run * along) < JointSnap.PIN_ROUND + BrickLattice.CELL + 0.5:
			return true
	return false


## Whether [param at] is on [param box]'s face that [param way] looks out of.
static func _on_face(box: AABB, at: Vector3, way: Vector3) -> bool:
	var reach: float = -INF
	for corner: int in 8:
		reach = maxf(reach, box.get_endpoint(corner).dot(way))
	return absf(at.dot(way) - reach) < BrickLattice.CELL * 0.75


## Whether one of [param marks] is a stud, a pin or an axle ending at [param at].
static func _male_at(marks: Array, at: Vector3) -> bool:
	for mark: Array in marks:
		if mark[4] in ["stud", "pin", "axle"] and (mark[6] as Vector3).distance_to(at) \
				< BrickLattice.CELL + 0.5:
			return true
	return false


## [param end]'s marks onto [param out]: a hole at each of its mouths, a pin
## or an axle at its tip, a bar or a clip along it, a ball or a socket at its
## middle. The hand's ([param held]) where it goes onto the joint: a pin's
## collar, at the hole's mouth once seated, seen from either side.
static func _end_marks(end: JointSnap.End, out: Array, held: bool) -> void:
	var flat: int = Facing.FLAT_BOTH if held else Facing.FLAT
	match end.kind:
		"pin_hole", "axle_hole":
			var shape: int = Shape.RING if end.kind == "pin_hole" else Shape.CROSS_RING
			if held:
				out.append(_mark(end.kind, end, shape, flat, PULL, end.at, end.axis,
					JointSnap.PIN_ROUND + BAND))
				return
			for side: float in [1.0, -1.0]:
				out.append(_mark(end.kind, end, shape, flat, PULL, end.at + end.axis * end.reach * side,
					end.axis * side, JointSnap.PIN_ROUND + BAND))
		"pin", "axle":
			var shape: int = Shape.DISC if end.kind == "pin" else Shape.CROSS
			var tip: Vector3 = end.at if held else end.at + end.axis * maxf(end.reach, 0.0)
			out.append(_mark(end.kind, end, shape, flat, PULL, tip, end.axis, JointSnap.PIN_ROUND))
		"shaft", "bore":
			var filled: bool = end.kind == "shaft"
			var width: float = end.radius + (0.0 if filled else BAND)
			out.append(_mark("bar" if filled else "clip", end, Shape.BAR if filled else Shape.BAR_RING,
				Facing.ALONG, width + PULL, end.at + end.axis * end.reach * 0.5, end.axis, width,
				end.reach * 0.5))
		"ball":
			out.append(_mark("ball", end, Shape.DISC, Facing.EYE, end.radius + PULL, end.at, end.axis,
				end.radius))
		"socket":
			out.append(_mark("socket", end, Shape.RING, Facing.EYE_MOUTH, end.radius + PULL, end.at,
				end.axis, end.radius + BAND))
		"hinge":
			var filled: bool = end.pol == 0
			out.append(_mark("hinge", end, Shape.DISC if filled else Shape.RING, Facing.EYE,
				HINGE_R + PULL, end.at, end.axis, HINGE_R + (0.0 if filled else BAND)))
		"tyre", "rim":
			for side: float in [1.0, -1.0]:
				out.append(_mark(end.kind, end, Shape.RING, flat, PULL,
					end.at + end.axis * end.reach * side, end.axis * side, end.radius + BAND))


## One mark: its shape's round [param radius] (its outside) and, for a bar or
## a clip, its straight part's half length [param half], at [param at],
## square to [param axis].
static func _mark(kind: String, end: JointSnap.End, shape: int, facing: int, pull: float,
		at: Vector3, axis: Vector3, radius: float, half: float = 0.0) -> Array:
	var normal: Vector3 = axis.normalized()
	# A cross square to the part, as LDraw's axles and axle holes are drawn.
	var across: Vector3 = Vector3.RIGHT
	var least: float = INF
	for way: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		if absf(way.dot(normal)) < least - 0.001:
			least = absf(way.dot(normal))
			across = way
	across = (across - normal * across.dot(normal)).normalized()
	var round: float = radius * MARGIN
	var basis: Basis
	if facing == Facing.ALONG:
		basis = Basis(normal * (half + round), across * round, normal.cross(across))
	else:
		basis = Basis(across * round, normal.cross(across) * round, normal)
	return [shape, facing, pull, Transform3D(basis, at), kind, end, at, false]


## Of a big part's [param marks], those whose REACH-sized box of the part's
## own is next to [param local]'s (a 48 x 48 baseplate has 4,608): found by
## the box, not by looking at each.
static func _near_marks(part_id: String, marks: Array, local: Vector3) -> Array:
	var grid: Dictionary = _cells.get(part_id, {})
	if grid.is_empty():
		for n: int in marks.size():
			var cell := Vector3i(((marks[n][6] as Vector3) / REACH).floor())
			if not grid.has(cell):
				grid[cell] = []
			(grid[cell] as Array).append(n)
		_cells[part_id] = grid
	var out: Array = []
	var at := Vector3i((local / REACH).floor())
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			for z: int in range(-1, 2):
				for n: int in grid.get(at + Vector3i(x, y, z), []):
					out.append(marks[n])
	return out


## [param marks] placed at [param where], as a buffer's rows; with
## [param near] given, only those within REACH of it.
static func _rows_of(marks: Array, where: Transform3D, takes: Callable,
		near: Variant = null) -> PackedFloat32Array:
	var rows := PackedFloat32Array()
	for mark: Array in marks:
		if near != null and (where * (mark[6] as Vector3)).distance_to(near) > REACH:
			continue
		_row(rows, where * (mark[3] as Transform3D), mark,
			Role.TAKES if takes.call(mark) else Role.NOT_TAKEN)
	return rows


## One mark's row of a MultiMesh's buffer: its transform, three rows of
## four, then its custom data (shape, role, facing, pull).
static func _row(rows: PackedFloat32Array, at: Transform3D, mark: Array, role: int) -> void:
	var b: Basis = at.basis
	rows.append_array([b.x.x, b.y.x, b.z.x, at.origin.x, b.x.y, b.y.y, b.z.y, at.origin.y,
		b.x.z, b.y.z, b.z.z, at.origin.z, float(mark[0]), float(role), float(mark[1]), float(mark[2])])


# -- drawn ---------------------------------------------------------------------------


## A batch of marks; [param over] draws over everything (the hand's).
static func _batch(over: bool) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.name = "HandMarks" if over else "JointMarks"
	var marks := MultiMesh.new()
	marks.transform_format = MultiMesh.TRANSFORM_3D
	marks.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	marks.mesh = quad
	batch.multimesh = marks
	batch.material_override = _material(over)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Turned to the eye and drawn toward it past the quad's own box.
	batch.extra_cull_margin = 24.0
	batch.visible = false
	return batch


static func _material(over: bool) -> ShaderMaterial:
	if _materials.is_empty():
		for hand: bool in [false, true]:
			var shader := Shader.new()
			shader.code = CODE % (", depth_test_disabled" if hand else "")
			var made := ShaderMaterial.new()
			made.shader = shader
			# After the ghost, which draws see-through at 0, so a mark on the
			# part it is aimed at shows through it.
			made.render_priority = 3 if hand else 2
			_materials.append(made)
	return _materials[1 if over else 0]


## [param batch] drawing [param rows], written only when they changed: a
## value written again unchanged draws a frame (IdleDraw).
static func _fill(batch: MultiMeshInstance3D, rows: PackedFloat32Array) -> void:
	var count: int = rows.size() / 16
	if count == 0:
		if batch.visible:
			batch.visible = false
		return
	var marks: MultiMesh = batch.multimesh
	if marks.instance_count != count:
		marks.instance_count = count
	elif marks.buffer == rows:
		if not batch.visible:
			batch.visible = true
		return
	marks.buffer = rows
	if not batch.visible:
		batch.visible = true


# -- read back, for a probe and a session ---------------------------------------------


## How many marks are drawn of the model and of the hand.
func drawn() -> Vector2i:
	return Vector2i(_model.multimesh.instance_count if _model.visible else 0,
		_hand.multimesh.instance_count if _hand.visible else 0)


## The marks drawn, each {kind, shape, role, at, radius} in the world, the
## model's then the hand's.
func shown() -> Array:
	var out: Array = []
	for batch: MultiMeshInstance3D in [_model, _hand]:
		if not batch.visible:
			continue
		var rows: PackedFloat32Array = batch.multimesh.buffer
		for n: int in batch.multimesh.instance_count:
			var o: int = n * 16
			var x := Vector3(rows[o], rows[o + 4], rows[o + 8])
			var y := Vector3(rows[o + 1], rows[o + 5], rows[o + 9])
			var z := Vector3(rows[o + 2], rows[o + 6], rows[o + 10])
			out.append({"shape": int(rows[o + 12]), "role": int(rows[o + 13]),
				"facing": int(rows[o + 14]), "at": Vector3(rows[o + 3], rows[o + 7], rows[o + 11]),
				"radius": y.length() / MARGIN, "half": maxf(x.length() - y.length(), 0.0),
				"axis": z.normalized() if int(rows[o + 14]) != Facing.ALONG else x.normalized()})
	return out


## Every mark of the model's parts but [param skip]'s, within [param only]
## when it has a size, drawn as the window draws them with nothing in hand,
## PICTURE_MOST at most: for a session's picture (view_model marks=true,
## ModelShot.drawn_with). The caller frees it.
static func for_picture(world: BrickWorld, library: PartLibrary, skip: Dictionary,
		only: AABB = AABB()) -> MultiMeshInstance3D:
	var batch: MultiMeshInstance3D = _batch(false)
	var rows := PackedFloat32Array()
	var every: Callable = func(_mark: Array) -> bool: return true
	var wide: AABB = only.grow(BrickLattice.STUD)
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id) or brick.hidden:
			continue
		var marks: Array = marks_of(library, brick.part_id)
		if marks.is_empty():
			continue
		if only.size.length() > 0.0:
			var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if part == null or not wide.intersects(brick.transform * part.bounds):
				continue
		if rows.size() / 16 + marks.size() > PICTURE_MOST:
			break
		rows.append_array(_rows_of(marks, brick.transform, every))
	_fill(batch, rows)
	return batch


## What the marks are, in words, for a session reading the picture.
static func said(count: int) -> String:
	return ("Connection points marked, %d, as View › Connection points draws them: filled blue "
		+ "for what goes in (studs, pins, axles as a cross, bars, balls), hollow blue for what "
		+ "takes one (anti-studs, pin holes, axle holes as a cross, clips, a hollow's mouth, "
		+ "sockets), each at its "
		+ "own size; a hollow ring's inside is the size of what goes in it.") % count
