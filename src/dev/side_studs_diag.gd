extends SceneTree
## A laid build weighed as the check weighs it, and for each joint past its
## working load what is beyond it and every stud between that and the rest:
## whose, which way it points, what its tip is in, and what the joints made
## of the pair (Stability.stud_joints). For finding why a shell on side studs
## reads as hung from one joint (snot6, 2026-11-25).
##
##   godot --headless --path . --script src/dev/side_studs_diag.gd -- --ldr=FILE [--most=N]

var _library: PartLibrary
var _checker: Assistant
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _arg(name: String, fallback: String = "") -> String:
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--%s=" % name):
			return one.substr(name.length() + 3)
	return fallback


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = _world
	_checker.builder = _builder
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	var text: String = FileAccess.get_file_as_string(_arg("ldr"))
	_store.open_text(text, "diag")
	for _n: int in 3:
		await process_frame
	var model: Assistant.Model = _checker._model_from_world()
	_world.clear()
	_builder.lattice.clear()
	_checker.forget_built()
	print("parts %d" % model.placements.size())
	var report: Dictionary = _checker._check(model, true, true)
	var balance: Balance.Report = report.get("balance")
	print("check: ok %s pieces %d over %d" % [report.get("ok"), int(report.get("pieces", 0)),
		balance.over if balance != null else -1])
	if balance != null:
		for one: Balance.JointLoad in balance.joints:
			if one.ratio > 1.0:
				print("  over: %s (#%d) on %s (#%d) by %d stud(s), %.0f g, %.1fx" % [one.beyond_part,
					one.beyond, one.held_part, one.held_by, one.studs, one.grams, one.ratio])

	# Weighed again here, to read the tree.
	var bricks: Array = []
	var lattice := BrickLattice.new()
	var at_of: Dictionary = {}
	for index: int in model.placements.size():
		var p: Assistant.Placement = model.placements[index]
		var part: Lbm.PartMesh = _library.mesh_for(p.part)
		if part == null:
			continue
		var at: Transform3D = _checker._transform(p, part)
		at_of[index + 1] = at
		bricks.append(BrickWorld.Brick.new(index + 1, p.part, p.color, at))
		lattice.occupy_boxes(index + 1, _builder.boxes_for(part, at))
	var judge := Balance.new()
	judge.library = _library
	judge.lattice = lattice
	var weighed: Balance.Report = judge.measure(bricks)
	print("here: over %d, %d bridges" % [weighed.over, weighed.joints.size()])
	var shapes := Stability.new()
	shapes.library = _library
	shapes.lattice = lattice
	var graph: Dictionary = shapes.contacts(bricks)
	var joints: Dictionary = Stability.stud_joints(graph, _library, lattice)
	var part_of: Dictionary = {}
	for brick: BrickWorld.Brick in bricks:
		part_of[brick.id] = brick.part_id
	var most: int = int(_arg("most", "60"))
	var pieces: Array = []
	for one: Balance.JointLoad in weighed.joints:
		if one.ratio <= 1.0:
			continue
		print("")
		print("over: %s #%d on %s #%d by %d stud(s), %.0f g, %.1fx at %s" % [one.beyond_part, one.beyond,
			one.held_part, one.held_by, one.studs, one.grams, one.ratio, one.at])
		var child: int = judge._index_of[one.beyond]
		var inside: Dictionary = {}
		for v: int in judge._reached:
			var p: int = judge._parent[v]
			if v == child or (p >= 0 and inside.has(p)):
				inside[v] = true
		var ids: Dictionary = {}
		var kinds: Dictionary = {}
		var box := AABB()
		var first: bool = true
		for v: Variant in inside:
			var id: int = judge._ids[int(v)]
			ids[id] = true
			var placement: Assistant.Placement = model.placements[id - 1]
			var key: String = "%s %s" % [placement.part, placement.face]
			kinds[key] = int(kinds.get(key, 0)) + 1
			var at: Transform3D = at_of[id]
			var b: AABB = at * _library.mesh_for(placement.part).bounds
			box = b if first else box.merge(b)
			first = false
		print("  beyond: %d parts, box %s .. %s" % [ids.size(), box.position, box.end])
		print("  kinds: %s" % str(kinds))
		pieces.append({"beyond": one.beyond, "held_by": one.held_by, "ratio": one.ratio,
			"at": [one.at.x, one.at.y, one.at.z], "ids": ids.keys()})
		# Every stud between the piece beyond and the rest, both ways.
		var seen: int = 0
		for brick: BrickWorld.Brick in bricks:
			var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
			for connector: Lbm.Connector in mesh.connectors:
				if connector.kind != "stud" or connector.gender != "male":
					continue
				var tip: Vector3 = brick.transform * (connector.position
					+ connector.axis.normalized() * Joints.STUD_REACH)
				var foot: Vector3 = brick.transform * connector.position
				var way: Vector3 = (brick.transform.basis * connector.axis).normalized()
				var owners: Array = lattice.bricks_at(BrickLattice.to_cell(tip), brick.id)
				for other: Variant in owners:
					var o: int = int(other)
					if ids.has(brick.id) == ids.has(o):
						continue
					var key: int = Stability.pair_of(brick.id, o)
					var said: PackedStringArray = []
					for name: String in ["studs", "sideways", "seated", "beside", "overlapped", "resting",
							"pivots"]:
						if (joints[name] as Dictionary).has(key):
							said.append(name if name != "studs" else "studs %d" % int(joints["studs"][key]))
					var into: BrickWorld.Brick = null
					for b: BrickWorld.Brick in bricks:
						if b.id == o:
							into = b
							break
					var socket: bool = Joints.socket_at(into.transform, _library.mesh_for(into.part_id), foot,
						way)
					seen += 1
					if seen <= most:
						print("  stud of %s #%d (%s) way %s at %s into %s #%d (%s): socket %s; joints: %s" % [
							brick.part_id, brick.id, "beyond" if ids.has(brick.id) else "rest", way.snapped(
							Vector3.ONE * 0.01), foot.snapped(Vector3.ONE * 0.1), into.part_id, o,
							"beyond" if ids.has(o) else "rest", socket, ", ".join(said)])
		print("  %d studs between the piece and the rest" % seen)
		# And what only touches across: pairs the joints read between them.
		var across: Dictionary = {}
		for name: String in ["studs", "seated", "beside", "resting"]:
			for key: Variant in joints[name]:
				var a: int = int(key) >> 32
				var b: int = int(key) & 0xFFFFFFFF
				if ids.has(a) != ids.has(b):
					across[name] = int(across.get(name, 0)) + 1
		print("  pairs across, by what the joints say: %s" % str(across))
		# By the parts' own shapes, not the lattice: every stud whose foot is
		# at a socket of a part on the other side, and every pair whose boxes
		# touch across, by the way they touch.
		var boxes: Dictionary = {}
		for brick: BrickWorld.Brick in bricks:
			boxes[brick.id] = brick.transform * _library.mesh_for(brick.part_id).bounds
		var sockets: int = 0
		for brick: BrickWorld.Brick in bricks:
			var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
			for connector: Lbm.Connector in mesh.connectors:
				if connector.kind != "stud" or connector.gender != "male":
					continue
				var foot: Vector3 = brick.transform * connector.position
				var way: Vector3 = (brick.transform.basis * connector.axis).normalized()
				var tip: Vector3 = foot + way * Joints.STUD_REACH
				for other: BrickWorld.Brick in bricks:
					if other.id == brick.id or ids.has(brick.id) == ids.has(other.id):
						continue
					if not (boxes[other.id] as AABB).grow(2.0).has_point(tip):
						continue
					if Joints.socket_at(other.transform, _library.mesh_for(other.part_id), foot, way):
						sockets += 1
						print("  by shape: stud of %s #%d way %s into %s #%d" % [brick.part_id, brick.id,
							way.snapped(Vector3.ONE * 0.01), other.part_id, other.id])
		print("  %d studs in a socket across, by the parts' shapes" % sockets)
		var touching: Dictionary = {}
		for a: Variant in ids:
			var box_a: AABB = boxes[a]
			for b: Variant in boxes:
				if ids.has(b):
					continue
				var box_b: AABB = boxes[b]
				if not box_a.grow(0.6).intersects(box_b):
					continue
				var overlap: AABB = box_a.grow(0.6).intersection(box_b)
				var thin: int = overlap.size.min_axis_index()
				var way: String = ["x", "y", "z"][thin]
				touching[way] = int(touching.get(way, 0)) + 1
		print("  boxes touching across, by the axis they meet on: %s" % str(touching))
	# With --plane=AXIS:LDU (z:280), the parts across that plane (their box on
	# both sides of it) and, by the parts' own shapes, how many studs each has
	# in a socket of a part wholly on either side, or one of theirs in it: what
	# ties the two sides together there (snot7).
	if _arg("plane") != "":
		var axis: int = "xyz".find(_arg("plane").get_slice(":", 0))
		var at_ldu: float = float(_arg("plane").get_slice(":", 1))
		var near: float = float(_arg("near", "100"))
		var boxes_of: Dictionary = {}
		for brick: BrickWorld.Brick in bricks:
			boxes_of[brick.id] = brick.transform * _library.mesh_for(brick.part_id).bounds
		var side := func(id: int) -> int:
			var b: AABB = boxes_of[id]
			if b.end[axis] <= at_ldu + 0.5:
				return 0
			if b.position[axis] >= at_ldu - 0.5:
				return 1
			return -1
		var ties: int = 0
		var plain: int = 0
		for brick: BrickWorld.Brick in bricks:
			if side.call(brick.id) != -1:
				continue
			var studs := Vector2i.ZERO
			for other: BrickWorld.Brick in bricks:
				var s: int = side.call(other.id)
				if s < 0 or not (boxes_of[brick.id] as AABB).grow(8.0).intersects(boxes_of[other.id]):
					continue
				for pair: Array in [[brick, other], [other, brick]]:
					var whose: BrickWorld.Brick = pair[0]
					var into: BrickWorld.Brick = pair[1]
					for connector: Lbm.Connector in _library.mesh_for(whose.part_id).connectors:
						if connector.kind != "stud" or connector.gender != "male":
							continue
						if Joints.socket_at(into.transform, _library.mesh_for(into.part_id),
								whose.transform * connector.position,
								(whose.transform.basis * connector.axis).normalized()):
							studs[s] += 1
			var b: AABB = boxes_of[brick.id]
			if (b.get_center() - Vector3(b.get_center()[0] if axis != 0 else at_ldu, b.get_center().y,
					b.get_center()[2] if axis != 2 else at_ldu)).length() > near:
				continue
			if studs.x > 0 and studs.y > 0:
				ties += 1
			plain += 1
			print("  across %s = %.0f: %s #%d at %s, studs into each side %d and %d" % [_arg("plane").get_slice(
				":", 0), at_ldu, brick.part_id, brick.id, b.position.snapped(Vector3.ONE * 0.1), studs.x, studs.y])
		print("plane %s: %d parts across, %d of them with studs into both sides" % [_arg("plane"), plain, ties])
	# With --dump=FILE, every part (its id, part, face, colour, box in LDU, y
	# down) and each piece beyond a joint past its load, as JSON, for reading
	# the plane a piece meets the rest on (snot7).
	if _arg("dump") != "":
		var parts: Array = []
		for brick: BrickWorld.Brick in bricks:
			var placement: Assistant.Placement = model.placements[brick.id - 1]
			var b: AABB = brick.transform * _library.mesh_for(brick.part_id).bounds
			parts.append({"id": brick.id, "part": brick.part_id, "face": placement.face,
				"color": placement.color, "box": [b.position.x, b.position.y, b.position.z, b.end.x, b.end.y,
				b.end.z]})
		var file := FileAccess.open(_arg("dump"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"parts": parts, "pieces": pieces}))
		file.close()
	quit(0)
