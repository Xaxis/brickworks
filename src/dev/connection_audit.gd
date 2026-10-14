## Which parts of real sets the build check holds, and why not the rest.
##
##   godot --headless --path . --script src/dev/connection_audit.gd -- [--shard=K/N] [--out=FILE] [FILE.mpd ...]
##
## Every set in the LDraw model repository (vendor/omr/files, tools/omr.py
## fetch) holds together in reality, so every part the check calls
## floating in one is a gap in the connection data or the joint types:
## a clip on a bar it cannot see, a hinge it does not know, a part it
## cannot read where the file puts it. Each file is opened as File, Open
## opens it, read back as a session reads the baseplate
## (Assistant._model_from_world), and checked as an edit checks what it
## leaves hanging (only the ground holds, Assistant._ground_only). One line
## a file goes to the out file (JSON):
##   {file, parts, missing, floating, kinds, misread, overlaps, overlap_pairs,
##    seconds, clusters}
## where each cluster is floating parts touching each other, with the held
## parts it touches — where the missing joint is — and the connectors of
## each side that lie at the contact. Real sets do not overlap either, so
## each pair of parts the check would refuse as overlapping is a cover
## wrong (tools/ldraw/occupancy.py), counted by pair of part ids.
## tools/connection_audit.py runs the shards under heavy and writes
## docs/CONNECTIONS.md from the lines.
##
## A line {file, begin} goes out before each file, so a shard that dies
## names the file it died on, and a rerun with the same out file carries on
## after the files already done. Not in the suite: hours over the whole
## repository.
extends SceneTree

const SETS := "res://vendor/omr/files"
## How far a connector may stand from the other part's cover and still be
## at the contact, in cells (2 LDU each).
const AT_CONTACT := 2
## Distinct pairs of parts said per cluster.
const EDGES := 10
## How far the reading may put a part from where the file has it before it
## is misread, in LDU: a square part is read to the nearest cell.
const MISREAD_LDU := 2.5

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	var shard: int = 0
	var shards: int = 1
	var out_path: String = "user://connection_audit.jsonl"
	var named: Array = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shard="):
			var said: PackedStringArray = argument.trim_prefix("--shard=").split("/")
			shard = int(said[0])
			shards = maxi(1, int(said[1]))
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		else:
			named.append(argument)
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame

	var files: Array = named
	if files.is_empty():
		if not DirAccess.dir_exists_absolute(SETS):
			print("no %s: tools/omr.py fetch brings the sets" % SETS)
			quit(1)
			return
		var all: Array = Array(DirAccess.get_files_at(SETS)).filter(
			func(f: String) -> bool: return f.ends_with(".mpd") or f.ends_with(".ldr"))
		all.sort()
		for n: int in all.size():
			if n % shards == shard:
				files.append(SETS.path_join(all[n]))

	var done: Dictionary = {}
	if FileAccess.file_exists(out_path):
		for line: String in FileAccess.get_file_as_string(out_path).split("\n"):
			var row: Variant = JSON.parse_string(line) if not line.is_empty() else null
			if row is Dictionary and not (row as Dictionary).has("begin"):
				done[str(row["file"])] = true
	var out := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path)
		else FileAccess.WRITE)
	if out == null:
		# Said and stopped: a script error leaves a SceneTree running for
		# ever, holding its slot (an absolute path is what it wants).
		print("cannot write %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		quit(1)
		return
	out.seek_end()
	var parts: int = 0
	var floating: int = 0
	for path: String in files:
		if done.has(path.get_file()):
			continue
		out.store_line(JSON.stringify({"file": path.get_file(), "begin": true}))
		out.flush()
		var row: Dictionary = _audit(path)
		out.store_line(JSON.stringify(row))
		out.flush()
		parts += int(row.get("parts", 0))
		floating += int(row.get("floating", 0))
		print("  %s: %d parts, %d floating, %d overlapping pairs, %.1f s" % [path.get_file(),
			int(row.get("parts", 0)), int(row.get("floating", 0)), int(row.get("overlaps", 0)),
			float(row.get("seconds", 0.0))])
	out.close()
	print("connection audit: %d parts, %d floating (%.2f%% held)" % [parts, floating,
		100.0 * float(parts - floating) / maxf(1.0, float(parts))])
	quit(0)


func _audit(path: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var opened: Dictionary = _store.open_text(FileAccess.get_file_as_string(path), path.get_file())
	var model: Assistant.Model = _assistant._model_from_world()
	var row: Dictionary = {"file": path.get_file(), "parts": model.placements.size(),
		"missing": int(opened.get("missing", 0)), "unplaced": _store.awaited.size()}
	if model.placements.is_empty():
		row["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
		row["error"] = str(opened.get("error", "nothing placed"))
		return row
	_assistant._ground_only = true
	var report: Dictionary = _assistant._check(model, true)
	_assistant._ground_only = false
	var checked: int = Time.get_ticks_msec()

	var floating: Dictionary = {}
	for index: Variant in report.get("floating", []):
		floating[int(index)] = true
	row["floating"] = floating.size()
	row["kinds"] = _kinds(str(report.get("summary", "")))

	# Brick id -> placement index, and whether the reading puts each part
	# where the file has it (counted, for what a session reads back), and
	# whether the check does (what a cluster is put down to: a part nobody
	# moved is checked where it stands, Assistant._joined_at).
	var index_of: Dictionary = {}
	var misread: Dictionary = {}
	var checked_off: Dictionary = {}
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		index_of[placement.id] = index
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		var brick: BrickWorld.Brick = _world.get_brick(placement.id)
		if mesh == null or brick == null:
			continue
		var read: Transform3D = _assistant._transform(placement, mesh, model.section_for(placement))
		if not _same(read, brick.transform):
			misread[index] = true
		if not _same(_assistant._joined_at(placement, mesh, model), brick.transform):
			checked_off[index] = true
	row["misread"] = misread.size()
	row["misread_floating"] = floating.keys().filter(func(i: int) -> bool:
		return misread.has(i)).size()

	# And what overlaps: a real set's parts do not, so each pair the check
	# would refuse is a cover wrong. Excused between standing bricks, and
	# kept by the check for this (Assistant._standing_overlaps). By pair of
	# part ids, how many and how many of those with a part misread.
	var overlaps: Dictionary = {}
	var overlapping: int = 0
	for pair: Array in report.get("standing_overlaps", []):
		var a: Assistant.Placement = model.placements[int(pair[0])]
		var b: Assistant.Placement = model.placements[int(pair[1])]
		var key: String = a.part + "|" + b.part if a.part <= b.part else b.part + "|" + a.part
		if not overlaps.has(key):
			overlaps[key] = [0, 0]
		(overlaps[key] as Array)[0] += 1
		if misread.has(int(pair[0])) or misread.has(int(pair[1])):
			(overlaps[key] as Array)[1] += 1
		overlapping += 1
	row["overlaps"] = overlapping
	row["overlap_pairs"] = overlaps

	# Floating parts that touch, by their real covers (the builder's
	# lattice has each where the file puts it).
	var touching: Dictionary = {}   ## index -> Array of indices it touches
	for index: int in floating:
		touching[index] = _touches(model.placements[index].id, index_of)
	var cluster_of: Dictionary = {}
	var clusters: Array = []
	for start: int in floating:
		if cluster_of.has(start):
			continue
		var members: Array = [start]
		cluster_of[start] = clusters.size()
		var stack: Array = [start]
		while not stack.is_empty():
			var here: int = stack.pop_back()
			for other: int in touching[here]:
				if floating.has(other) and not cluster_of.has(other):
					cluster_of[other] = clusters.size()
					members.append(other)
					stack.append(other)
		clusters.append(members)
	var said: Array = []
	for members: Array in clusters:
		said.append(_cluster(model, members, floating, touching, checked_off))
	said.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["size"]) > int(b["size"]))
	row["clusters"] = said
	row["check_seconds"] = float(checked - started) / 1000.0
	row["seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
	return row


## A cluster said: its size, its parts by id, how many the check puts off
## their place ([param misread]), and each held part it touches with the
## connectors at the contact.
func _cluster(model: Assistant.Model, members: Array, floating: Dictionary,
		touching: Dictionary, misread: Dictionary) -> Dictionary:
	var parts: Dictionary = {}
	var wrong: int = 0
	var edges: Array = []
	var seen: Dictionary = {}
	var held_touched: Dictionary = {}
	for index: int in members:
		var placement: Assistant.Placement = model.placements[index]
		parts[placement.part] = int(parts.get(placement.part, 0)) + 1
		if misread.has(index):
			wrong += 1
		for other: int in touching[index]:
			if floating.has(other):
				continue
			held_touched[other] = true
			var mate: Assistant.Placement = model.placements[other]
			var pair: String = placement.part + "|" + mate.part
			if seen.has(pair) or seen.size() >= EDGES * 4:
				continue
			seen[pair] = true
			edges.append([placement.part, mate.part,
				_at_contact(placement.id, mate.id), _at_contact(mate.id, placement.id),
				misread.has(index), misread.has(other)])
	# The joints worth reading first: a pin, a bar or a clip at the contact
	# before a stud, and a stud before nothing at all.
	edges.sort_custom(func(a: Array, b: Array) -> bool:
		return _interest(a) > _interest(b))
	return {"size": members.size(), "parts": parts, "misread": wrong,
		"held_touched": held_touched.size(), "edges": edges.slice(0, EDGES),
		"lowest": _lowest(model, members)}


## The parts a cluster stands lowest on, by their drawn shape: [part, where
## its shape stops, where its cover stops], y in LDU, a few of them. A
## cluster that touches nothing held is a model the check cannot stand on
## the ground, and these say why: a wheel whose cover stops above its
## tyre, or a model drawn a little off the ground.
func _lowest(model: Assistant.Model, members: Array) -> Array:
	var rows: Array = []
	for index: int in members:
		var placement: Assistant.Placement = model.placements[index]
		var brick: BrickWorld.Brick = _world.get_brick(placement.id)
		var mesh: Lbm.PartMesh = _library.mesh_for(placement.part)
		if brick == null or mesh == null:
			continue
		# By its shape: a turned part's box hangs below it (Lbm.PartMesh.lowest_at).
		var shape: float = mesh.lowest_at(brick.transform)
		var cover: PackedInt32Array = _builder.lattice.boxes_of(brick.id)
		var low: int = 0x7FFFFFFF
		for n: int in range(1, cover.size(), 6):
			low = mini(low, cover[n])
		rows.append([placement.part, snappedf(shape, 0.1),
			snappedf(float(low) * BrickLattice.CELL, 0.1) if low != 0x7FFFFFFF else null])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	return rows.slice(0, 4)


static func _interest(edge: Array) -> int:
	var score: int = 0
	for kind: String in (edge[2] as Array) + (edge[3] as Array):
		score = maxi(score, 1 if kind in ["stud", "tube", "ridge"] else 2)
	return score


## The placements whose real covers touch or overlap this brick's, grown
## a cell.
func _touches(brick_id: int, index_of: Dictionary) -> Array:
	var grown: PackedInt32Array = _grown(_builder.lattice.boxes_of(brick_id), 1)
	var out: Array = []
	for other: int in _builder.lattice.blockers_boxes(grown, brick_id):
		if index_of.has(other):
			out.append(index_of[other])
	return out


## The connectors of one brick that lie at another's cover: "stud", "pin",
## "shaft r4", "bore r4 arc"... once each.
func _at_contact(brick_id: int, other_id: int) -> Array:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id) if brick != null else null
	if mesh == null:
		return []
	var theirs: PackedInt32Array = _builder.lattice.boxes_of(other_id)
	var kinds: Dictionary = {}
	for connector: Lbm.Connector in mesh.connectors:
		var middle: Vector3 = brick.transform * (connector.position
			+ connector.axis * connector.length * 0.5)
		var cell: Vector3i = BrickLattice.to_cell(middle)
		var box := PackedInt32Array([cell.x - AT_CONTACT, cell.y - AT_CONTACT, cell.z - AT_CONTACT,
			cell.x + AT_CONTACT + 1, cell.y + AT_CONTACT + 1, cell.z + AT_CONTACT + 1])
		if not _boxes_meet(box, theirs):
			continue
		var kind: String = connector.kind
		if kind == "shaft" or kind == "bore":
			kind += " r%s" % str(snappedf(connector.radius, 0.5))
		kinds[kind] = true
	return kinds.keys()


static func _boxes_meet(one: PackedInt32Array, other: PackedInt32Array) -> bool:
	var i: int = 0
	while i < one.size():
		var j: int = 0
		while j < other.size():
			if one[i] < other[j + 3] and other[j] < one[i + 3] \
					and one[i + 1] < other[j + 4] and other[j + 1] < one[i + 4] \
					and one[i + 2] < other[j + 5] and other[j + 2] < one[i + 5]:
				return true
			j += 6
		i += 6
	return false


static func _grown(packed: PackedInt32Array, by: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(packed.size())
	for n: int in range(0, packed.size(), 6):
		for k: int in 3:
			out[n + k] = packed[n + k] - by
			out[n + 3 + k] = packed[n + 3 + k] + by
	return out


## Whether the reading puts a part where the file has it.
static func _same(read: Transform3D, real: Transform3D) -> bool:
	if read.origin.distance_to(real.origin) > MISREAD_LDU:
		return false
	for k: int in 3:
		if read.basis[k].normalized().dot(real.basis[k].normalized()) < 0.999:
			return false
	return true


## "12 problems (floating 9, overlap 3)" -> {floating: 9, overlap: 3}.
static func _kinds(summary: String) -> Dictionary:
	var out: Dictionary = {}
	var open: int = summary.find("(")
	if open < 0:
		return out
	for part: String in summary.substr(open + 1).trim_suffix(")").split(", "):
		var cut: int = part.rfind(" ")
		if cut > 0:
			out[part.substr(0, cut)] = int(part.substr(cut + 1))
	return out
