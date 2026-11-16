## The balls in sockets the stability reads in the real sets' files
## (Joints.balls, the catalogue's balls and sockets), as balljoints_probe
## seats them: every set in vendor/omr/files that names a part with a ball
## or a socket, opened, each pair read, and the two parts' ends as the hand
## reads them (JointSnap.ends_for), one line a kind of pose.
##
##   godot --headless --path . --script src/dev/balljoints_scan.gd -- src/dev/balljoints_real.json
##
## Each: {"set", "ball", "ball_at", "socket", "socket_at", "gap", "times"},
## the transforms as LDraw's matrix and place, "gap" how far apart the set
## has the two centres, "times" how many joints in all the sets are that
## pose. A pair whose parts the hand reads no ball and socket on is said and
## left out: a part the set draws as a sub-model (21325's "21325 - 15456"),
## or a ball beside a pin hole's rim that Joints.balls reads as in a socket.
extends SceneTree

const SETS := "res://vendor/omr/files"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if not args.is_empty() else "res://src/dev/balljoints_real.json"
	var library := PartLibrary.new()
	library.load_catalogue()
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
	# The parts with a ball or a socket, as either reads one.
	var balled: Dictionary = {}
	for id: String in library.parts:
		var mesh: Lbm.PartMesh = library.mesh_for(id)
		if mesh == null:
			continue
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "ball" or connector.kind == "socket" or (connector.kind == "bore"
					and absf(connector.radius - Joints.BALL_RADIUS) <= Joints.ROUND_FIT * 0.5):
				balled[id] = true
				break
	print("%d parts with a ball or a socket" % balled.size())
	# The catalogue's own parts: a set's sub-model drawn as a part is the
	# library's only while that set is open.
	var catalogued: Dictionary = {}
	for id: String in library.parts:
		catalogued[id] = true
	var files: PackedStringArray = DirAccess.get_files_at(SETS)
	var sets: int = 0
	var pairs: int = 0
	var unread: int = 0
	var unique: Dictionary = {}
	for file: String in files:
		if not (file.ends_with(".mpd") or file.ends_with(".ldr")):
			continue
		var text: String = FileAccess.get_file_as_string(SETS + "/" + file)
		if not _names_one(text, balled):
			continue
		world.clear()
		builder.lattice.clear()
		var opened: Dictionary = store.open_text(text, file)
		if not str(opened.get("error", "")).is_empty():
			continue
		sets += 1
		var entries: Array = []
		for brick: BrickWorld.Brick in world.bricks():
			var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
			if mesh != null:
				entries.append([brick.id, brick.transform, mesh, brick.part_id])
		var held: Dictionary = Joints.balls(entries)
		var seen: Dictionary = {}
		for a: Variant in held:
			for b: Variant in held[a]:
				var pair := Vector2i(mini(int(a), int(b)), maxi(int(a), int(b)))
				if seen.has(pair):
					continue
				seen[pair] = true
				pairs += 1
				var one: BrickWorld.Brick = world.get_brick(pair.x)
				var other: BrickWorld.Brick = world.get_brick(pair.y)
				if not catalogued.has(one.part_id) or not catalogued.has(other.part_id):
					unread += 1
					print("  %s: %s and %s, a sub-model drawn as a part" % [file, one.part_id, other.part_id])
					continue
				if not _add(unique, library, file, one, other):
					unread += 1
					print("  %s: no ball and socket the hand reads on %s and %s" % [file, one.part_id,
						other.part_id])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(unique.values()))
	f.close()
	print("%d sets, %d pairs, %d unread; %d kinds of pose, in %s" % [sets, pairs, unread, unique.size(),
		out_path])
	quit(0)


## Whether a set's text names one of [param balled] as a part.
static func _names_one(text: String, balled: Dictionary) -> bool:
	for line: String in text.split("\n"):
		var cut: String = line.strip_edges()
		if not cut.begins_with("1 "):
			continue
		var name: String = cut.get_slice(" ", cut.get_slice_count(" ") - 1).to_lower().trim_suffix(".dat")
		if balled.has(name):
			return true
	return false


## The pair's ball and socket as the hand reads them, the nearest two, kept
## once a pose. False when it reads none.
static func _add(unique: Dictionary, library: PartLibrary, file: String, one: BrickWorld.Brick,
		other: BrickWorld.Brick) -> bool:
	var best: float = INF
	var found: Array = []
	for pair: Array in [[one, other], [other, one]]:
		var a: BrickWorld.Brick = pair[0]
		var b: BrickWorld.Brick = pair[1]
		for x: JointSnap.End in JointSnap.ends_for(library, a.part_id):
			if x.kind != "ball":
				continue
			for y: JointSnap.End in JointSnap.ends_for(library, b.part_id):
				if y.kind != "socket" or not JointSnap.mates(x, y):
					continue
				var d: float = (a.transform * x.at).distance_to(b.transform * y.at)
				if d < best:
					best = d
					found = [a, b]
	if found.is_empty():
		return false
	var ball: BrickWorld.Brick = found[0]
	var socket: BrickWorld.Brick = found[1]
	var key: String = "%s|%s|%s|%s|%s" % [ball.part_id, socket.part_id, _rounded(ball.transform.basis),
		_rounded(socket.transform.basis), ((socket.transform.origin - ball.transform.origin) * 100.0).round()]
	if not unique.has(key):
		unique[key] = {"set": file, "ball": ball.part_id, "ball_at": _matrix(ball.transform),
			"socket": socket.part_id, "socket_at": _matrix(socket.transform), "gap": snappedf(best, 0.0001),
			"times": 0}
	unique[key]["times"] = int(unique[key]["times"]) + 1
	return true


static func _rounded(b: Basis) -> String:
	return "%s" % [[(b.x * 1000.0).round(), (b.y * 1000.0).round(), (b.z * 1000.0).round()]]


static func _matrix(t: Transform3D) -> Array:
	var b: Basis = t.basis
	var out: Array = []
	for v: float in [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]:
		out.append(snappedf(v, 0.000001))
	for v: float in [t.origin.x, t.origin.y, t.origin.z]:
		out.append(snappedf(v, 0.0001))
	return out
