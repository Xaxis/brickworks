## Where daylight shows straight through a building.
##
##   godot --headless --path . --script src/dev/daylight_probe.gd -- FILE.ldr \
##       X_FROM X_TO Z_FROM Z_TO Y_FROM Y_TO
##
## Every part in the box is laid flat as the outline of its box in plan, and
## a horizontal sightline at a height is seen through where it meets none of
## them between the first part and the last across the view. The sixteenth
## Orthanc's front showed a white slit up its core: a prism face's inner
## corner stops short of its neighbour's, a channel narrower than a lattice
## cell, and the open back put the sky behind it. The check cannot see it (a
## turned part claims every cell it touches), so it is measured off the
## parts' own boxes, the way the picture is drawn.
##
## Headings are where the eye is: 0 is in front (+z) looking back, 90 is to
## the right (+x). Prints how many sightlines pass at each height and heading.
## The patterns probe calls the same functions on the clusters it lays.
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 7:
		print("give a model and the box to look through, after --: "
			+ "FILE X_FROM X_TO Z_FROM Z_TO Y_FROM Y_TO")
		quit(2)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame
	var placed: int = store.open(args[0])
	for _n: int in 30:
		await process_frame
	var box := {"x_from": float(args[1]), "x_to": float(args[2]),
		"z_from": float(args[3]), "z_to": float(args[4])}
	var parts: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			parts.append([brick.transform, mesh.bounds])
	var prints: Array = footprints(parts, box)
	print("%s: %d parts, %d in the box" % [args[0].get_file(), placed, prints.size()])
	var low: float = float(args[5])
	var high: float = float(args[6])
	var total: int = 0
	for heading: float in HEADINGS:
		var line := PackedStringArray()
		var count: int = 0
		for n: int in LEVELS:
			var y: float = low + (high - low) * (n + 1) / (LEVELS + 1)
			var found: Array = gaps(prints, y, heading)
			count += found.size()
			line.append("%d" % found.size())
		total += count
		print("  from %4d degrees: %3d sightlines through (%s at %d heights)"
			% [int(heading), count, " ".join(line), LEVELS])
		# Where they are, for one heading if asked: an eighth argument.
		if args.size() > 7 and is_equal_approx(float(args[7]), heading):
			for n: int in LEVELS:
				var y: float = low + (high - low) * (n + 1) / (LEVELS + 1)
				for gap: Array in gaps(prints, y, heading):
					print("      at y %.1f: %.2f to %.2f studs across (%.1f LDU)"
						% [y, gap[0], gap[1], (float(gap[1]) - float(gap[0])) * 20.0])
	print("%d sightlines through, all told" % total)
	quit(0)


## The headings looked from, and how many heights between the box's floor
## and its top.
const HEADINGS: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
const LEVELS := 9
## Narrower than this is a seam between two parts, not daylight: half an LDU.
const SEAM := 0.025


## Each part, from [transform, its own box in LDU], as [its corners in plan in
## studs, its bottom and top in plates], kept only where its middle is inside
## [param box] (x_from, x_to, z_from, z_to in studs; a side left out is open).
static func footprints(parts: Array, box: Dictionary = {}) -> Array:
	var out: Array = []
	for entry: Array in parts:
		var at: Transform3D = entry[0]
		var own: AABB = entry[1]
		var corners := PackedVector2Array()
		var low: float = INF
		var high: float = -INF
		for k: int in 8:
			var point: Vector3 = at * own.get_endpoint(k)
			corners.append(Vector2(point.x / 20.0, point.z / 20.0))
			low = minf(low, point.y / 8.0)
			high = maxf(high, point.y / 8.0)
		var middle := Vector2.ZERO
		for corner: Vector2 in corners:
			middle += corner / 8.0
		if middle.x < float(box.get("x_from", -INF)) or middle.x > float(box.get("x_to", INF)) \
				or middle.y < float(box.get("z_from", -INF)) or middle.y > float(box.get("z_to", INF)):
			continue
		out.append([corners, low, high])
	return out


## The sightlines at [param y] plates seen from [param heading] that meet no
## part, between the first part across the view and the last: each [from, to]
## in studs across the view. A part counts at a height strictly inside it.
static func gaps(prints: Array, y: float, heading: float) -> Array:
	var across := Vector2(cos(deg_to_rad(heading)), -sin(deg_to_rad(heading)))
	var spans: Array = []
	for one: Array in prints:
		if y <= float(one[1]) + 0.01 or y >= float(one[2]) - 0.01:
			continue
		var lo: float = INF
		var hi: float = -INF
		for corner: Vector2 in one[0]:
			var along: float = corner.dot(across)
			lo = minf(lo, along)
			hi = maxf(hi, along)
		spans.append([lo, hi])
	if spans.is_empty():
		return []
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var found: Array = []
	var reach: float = spans[0][1]
	for span: Array in spans:
		if float(span[0]) > reach + SEAM:
			found.append([reach, float(span[0])])
		reach = maxf(reach, float(span[1]))
	return found
