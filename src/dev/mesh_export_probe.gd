## The model as a 3D file, read back the way a 3D program reads it.
##
##   godot --headless --path . --script src/dev/mesh_export_probe.gd
##   godot --headless --path . --script src/dev/mesh_export_probe.gd -- --orthanc
##
## On the real scene: the example car opened, then File, Export, 3D model…
## pressed (the dialog, GLB chosen, Export), and the GLB read back with
## Godot's own glTF reader, GLTFDocument: a mesh node for every part, under
## a node per sub-model, the bounds the window frames (main._built_bounds)
## to 1 LDU, each part's colour, see-through and finish as colors.json has
## them, and its faces facing out as they do in the app. Then over MCP, as a
## session asks (export_model): the same as text (.gltf, its data inside),
## OBJ with its MTL counted line by line, and STL read back triangle by
## triangle: one closed volume per part, facing out, at real size in
## millimetres standing on Z.
##
## With --orthanc, the 10,093-part tower too: the GLB whole, within the time
## and the frame it may hold, each of its shapes written once; the STL, which
## is under its cap; and the OBJ, which is over its and is refused saying so.
extends SceneTree

## How many parts models/orthanc.ldr has, every one of which it opens.
## Change it with the model: it said 9,429 long after the tower had 9,541.
const ORTHANC_PARTS := 10093

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _world: BrickWorld
var _store: ModelStore
var _library: PartLibrary
var _exports: Exports
var _next: int = 0
var _out: String = ""
## The longest the frame was held while an export ran, in microseconds.
var _held_us: int = 0
var _last_frame_us: int = 0
var _timing: bool = false


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_exports = _main.get("_exports")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	_out = OS.get_user_data_dir().path_join("mesh_export_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	for file_name: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(file_name))
	_exports.folder = _out
	process_frame.connect(_on_frame)

	var said: String = await _say("open_model", {"name": "Car", "discard_changes": true})
	_check("the example car opens: %s" % said.left(60), said.begins_with("Opened"))
	await _from_the_menu()
	await _as_text()
	await _as_obj()
	await _as_stl()
	await _sub_models()
	if "--orthanc" in OS.get_cmdline_user_args():
		await _orthanc()
	_done()


func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _timing and _last_frame_us > 0:
		_held_us = maxi(_held_us, now - _last_frame_us)
		if now - _last_frame_us > 150000:
			var job: Working.Job = Working.current()
			_long.append("%d ms at \"%s\"" % [(now - _last_frame_us) / 1000,
				job.line() if job != null else "-"])
	_last_frame_us = now


## Frames held past 150 ms while timing, and what the bar said then.
var _long: PackedStringArray = []


## Begin timing an export, from a frame the app has settled into.
func _time_from_here() -> void:
	for _n: int in 30:
		await process_frame
	_long.clear()
	_held_us = 0
	_timing = true


## The parts the file should hold: the model's, not the baseplate.
func _parts() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick)
	return out


# -- GLB from the menu ------------------------------------------------------------


func _from_the_menu() -> void:
	print("── File, Export, 3D model…, GLB ──")
	var shell: Shell = _main.get("_shell")
	_check("File, Export lists 3D model…", (Shell.SUBMENUS["export"] as Array).has("export_3d")
		and shell.command("export_3d").words.begins_with("3D model"))
	_check("...and it runs", shell.run("export_3d"))
	var dialog: ConfirmationDialog = _exports.get("_model_3d")
	var choice: OptionButton = _exports.get("_format_choice")
	var note: Label = _exports.get("_format_note")
	_check("the dialog is up with GLB chosen: \"%s\"" % choice.get_item_text(choice.selected),
		dialog.visible and MeshExport.FORMATS[choice.selected] == "glb")
	_check("...saying what it is for: \"%s\"" % note.text.left(70), note.text.contains("metres"))
	choice.select(3)
	choice.item_selected.emit(3)
	_check("STL says its cap and this model's count: \"%s\"" % note.text.right(60),
		note.text.contains("Up to 3,000,000 triangles; this model is"))
	choice.select(0)
	choice.item_selected.emit(0)
	var bar: ModelBar = _main.get("_bar")
	var path: String = _out.path_join(MeshExport._file_base(bar.model_name()) + ".glb")
	_timing = true
	_held_us = 0
	var began: int = Time.get_ticks_msec()
	dialog.get_ok_button().pressed.emit()
	var writing: bool = Exports._writing
	while Exports._writing and Time.get_ticks_msec() - began < 60000:
		await process_frame
	_timing = false
	var status: Label = bar.get("_status")
	_check("Export wrote %s in %d ms, the frame held at most %d ms: \"%s\"" % [path.get_file(),
		Time.get_ticks_msec() - began, _held_us / 1000, status.text],
		writing and FileAccess.file_exists(path) and status.text.begins_with("wrote " + path))
	await _read_gltf(path)


## A glTF read back with GLTFDocument and checked part by part.
func _read_gltf(path: String) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err: Error = document.append_from_file(path, state)
	_check("GLTFDocument reads %s (%s, %d bytes)" % [path.get_file(), error_string(err),
		FileAccess.get_file_as_bytes(path).size()], err == OK)
	if err != OK:
		return
	var scene: Node = document.generate_scene(state)
	root.add_child(scene)
	var meshes: Array = scene.find_children("*", "MeshInstance3D", true, false)
	var parts: Array = _parts()
	_check("a mesh node for every part: %d nodes, %d parts" % [meshes.size(), parts.size()],
		meshes.size() == parts.size())
	_check("...pointing at %d meshes, a shape in a colour each, not one a part"
		% state.get_meshes().size(), state.get_meshes().size() < parts.size())
	var bounds := AABB()
	for n: int in meshes.size():
		var node: MeshInstance3D = meshes[n]
		var box: AABB = node.global_transform * node.mesh.get_aabb()
		bounds = box if n == 0 else bounds.merge(box)
	var ldu: AABB = AABB(bounds.position / MeshExport.METRES, bounds.size / MeshExport.METRES)
	var framed: AABB = _main.call("_built_bounds")
	var off: float = _apart(ldu.position, framed.position, ldu.end, framed.end)
	_check("the bounds, in metres, are the window's to 1 LDU: %s against %s (%.3f LDU off)"
		% [_box(ldu), _box(framed), off], off <= 1.0)

	# Each part's colour: the brick at that place, in that part.
	var at: Dictionary = {}
	for brick: BrickWorld.Brick in parts:
		at[_place_key(brick.part_id, brick.transform.origin)] = brick
	var matched: int = 0
	var wrong: PackedStringArray = []
	var see_through: int = 0
	var facing: int = 0
	var facing_wrong: PackedStringArray = []
	for node: MeshInstance3D in meshes:
		var extras: Variant = node.get_meta("extras", {})
		var part_id: String = str((extras as Dictionary).get("ldraw_part", "")) \
			if extras is Dictionary else ""
		if part_id.is_empty():
			part_id = str(node.name).get_slice(" ", 0)
		var brick: BrickWorld.Brick = at.get(_place_key(part_id,
			node.global_transform.origin / MeshExport.METRES))
		if brick == null:
			wrong.append("%s: no part there" % node.name)
			continue
		matched += 1
		var colour: PartLibrary.BrickColor = _library.color(brick.color_code)
		var made: StandardMaterial3D = node.mesh.surface_get_material(0) as StandardMaterial3D
		if made == null:
			made = node.get_active_material(0) as StandardMaterial3D
		var meant: StandardMaterial3D = MeshExport.material_for(colour)
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		# The first surface follows the part's colour, unless it is moulded in one.
		if part.surface_colors[0] != Lbm.COLOR_INHERIT:
			meant = MeshExport.material_for(_library.color(part.surface_colors[0]))
		if made == null or not _same_colour(made.albedo_color, meant.albedo_color) \
				or absf(made.roughness - meant.roughness) > 0.01 \
				or absf(made.metallic - meant.metallic) > 0.01 \
				or (meant.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED) \
					!= (made.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			wrong.append("%s in %s: %s" % [brick.part_id, colour.name,
				"no material" if made == null else str(made.albedo_color)])
		elif meant.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			see_through += 1
		# Facing out: the read-back faces turn the way the app's own do.
		if _turning(node.mesh) * _turning(part.surfaces[0]) > 0.0:
			facing += 1
		else:
			facing_wrong.append(brick.part_id)
	_check("each part where it stands, in its colour, finish and alpha: %d of %d%s" % [
		matched - wrong.size(), parts.size(),
		"" if wrong.is_empty() else " — " + ", ".join(wrong.slice(0, 4))],
		wrong.is_empty() and matched == parts.size())
	_check("...the see-through ones see-through: %d" % see_through, see_through > 0)
	_check("faces face out, as they do in the app: %d of %d%s" % [facing, meshes.size(),
		"" if facing_wrong.is_empty() else " — " + ", ".join(facing_wrong.slice(0, 4))],
		facing == meshes.size())
	if path.get_extension() == "glb":
		var groups: Array = scene.find_children("*", "Node3D", true, false).filter(
			func(node: Node) -> bool: return not node is MeshInstance3D and node.get_child_count() > 0)
		print("  nodes that hold parts: %s" % ", ".join(groups.map(func(node: Node) -> String:
			return "%s (%d)" % [node.name, node.get_child_count()])))
	scene.queue_free()
	await process_frame


## How far apart two boxes are at the furthest, corner by corner.
static func _apart(low: Vector3, other_low: Vector3, high: Vector3, other_high: Vector3) -> float:
	var off: float = 0.0
	for axis: int in 3:
		off = maxf(off, maxf(absf(low[axis] - other_low[axis]), absf(high[axis] - other_high[axis])))
	return off


static func _place_key(part_id: String, origin: Vector3) -> String:
	return "%s@%d,%d,%d" % [part_id, roundi(origin.x), roundi(origin.y), roundi(origin.z)]


static func _same_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01 \
		and absf(a.a - b.a) < 0.01


## Which way a mesh's triangles turn against its normals, summed: the sign
## is what matters, the same for one drawn the same way round.
static func _turning(mesh: Mesh) -> float:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var sum: float = 0.0
	if index.is_empty():
		index.resize(v.size())
		for i: int in v.size():
			index[i] = i
	for i: int in range(0, index.size() - 2, 3):
		var a: Vector3 = v[index[i]]
		var face: Vector3 = (v[index[i + 1]] - a).cross(v[index[i + 2]] - a)
		sum += face.dot(n[index[i]] + n[index[i + 1]] + n[index[i + 2]])
	return sum


static func _box(box: AABB) -> String:
	return "(%.1f, %.1f, %.1f)-(%.1f, %.1f, %.1f)" % [box.position.x, box.position.y,
		box.position.z, box.end.x, box.end.y, box.end.z]


# -- over MCP ------------------------------------------------------------------------


func _as_text() -> void:
	print("── export_model gltf ──")
	var said: String = await _say("export_model", {"format": "gltf"})
	var path: String = _written(said)
	_check("a .gltf, its data inside: %s" % said, path.ends_with(".gltf")
		and FileAccess.get_file_as_string(path).contains("data:application/octet-stream;base64,"))
	await _read_gltf(path)


func _as_obj() -> void:
	print("── export_model obj ──")
	var said: String = await _say("export_model", {"format": "obj"})
	var path: String = _written(said)
	var mtl: String = path.get_basename() + ".mtl"
	_check("an OBJ and its MTL: %s" % said, path.ends_with(".obj") and FileAccess.file_exists(mtl))
	var text: String = FileAccess.get_file_as_string(path)
	var objects: int = 0
	var vertices: int = 0
	var faces: int = 0
	var used: Dictionary = {}
	var bad: int = 0
	for line: String in text.split("\n", false):
		if line.begins_with("o "):
			objects += 1
		elif line.begins_with("v "):
			vertices += 1
		elif line.begins_with("f "):
			faces += 1
			for corner: String in line.substr(2).split(" ", false):
				var index: int = corner.get_slice("/", 0).to_int()
				if index < 1 or index > vertices:
					bad += 1
		elif line.begins_with("usemtl "):
			used[line.substr(7)] = true
	var triangles: int = 0
	for brick: BrickWorld.Brick in _parts():
		triangles += _library.mesh_for(brick.part_id).triangle_count
	_check("an object a part, every triangle: %d objects, %d faces (%d triangles in the parts)"
		% [objects, faces, triangles], objects == _parts().size() and faces == triangles)
	_check("...every face naming vertices written before it (%d vertices)" % vertices, bad == 0)
	var defined: String = FileAccess.get_file_as_string(mtl)
	var missing: Array = used.keys().filter(func(name: String) -> bool:
		return not defined.contains("newmtl %s\n" % name))
	_check("every colour it uses is in the MTL: %d (%s)" % [used.size(), ", ".join(used.keys().slice(0, 4))],
		missing.is_empty() and not used.is_empty())
	_check("...with the see-through ones' alpha", defined.contains("d 0.")
		and text.begins_with("# ") and text.contains("mtllib %s" % mtl.get_file()))


func _as_stl() -> void:
	print("── export_model stl ──")
	_timing = true
	_held_us = 0
	var said: String = await _say("export_model", {"format": "stl"})
	_timing = false
	var path: String = _written(said)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var count: int = bytes.decode_u32(80) if bytes.size() >= 84 else -1
	_check("a binary STL: %s, the frame held at most %d ms" % [said, _held_us / 1000],
		path.ends_with(".stl") and bytes.size() == 84 + 50 * count
		and not bytes.slice(0, 5).get_string_from_ascii().begins_with("solid"))
	# The parts' spans, in the order written: every part's triangles.
	var spans: Array[int] = []
	var parts: Array = _parts()
	parts.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool: return a.id < b.id)
	var total: int = 0
	for brick: BrickWorld.Brick in parts:
		spans.append(_library.mesh_for(brick.part_id).triangle_count)
		total += spans[-1]
	_check("one mesh of every part's triangles: %d" % count, count == total)
	var low := Vector3.INF
	var high := -Vector3.INF
	var closed: int = 0
	var facing: int = 0
	var open: PackedStringArray = []
	var turned: PackedStringArray = []
	var own_gaps: Dictionary = {}
	var as_drawn: Dictionary = {}
	var normals_agree: bool = true
	var at: int = 84
	for n: int in spans.size():
		var corners := PackedVector3Array()
		corners.resize(spans[n] * 3)
		for t: int in spans[n]:
			var stated := Vector3(bytes.decode_float(at), bytes.decode_float(at + 4),
				bytes.decode_float(at + 8))
			for c: int in 3:
				var p := Vector3(bytes.decode_float(at + 12 + 12 * c),
					bytes.decode_float(at + 16 + 12 * c), bytes.decode_float(at + 20 + 12 * c))
				corners[t * 3 + c] = p
				low = low.min(p)
				high = high.max(p)
			var face: Vector3 = (corners[t * 3 + 1] - corners[t * 3]).cross(
				corners[t * 3 + 2] - corners[t * 3])
			if face.length() > 1e-6 and stated.dot(face.normalized()) < 0.99:
				normals_agree = false
			at += 50
		var verdict: Dictionary = _volume(corners)
		var part_id: String = parts[n].part_id
		if not own_gaps.has(part_id):
			own_gaps[part_id] = int(_volume(_own_corners(part_id))["open"])
		if verdict["closed"]:
			closed += 1
		elif int(verdict["open"]) == int(own_gaps[part_id]):
			as_drawn[part_id] = verdict["open"]
		else:
			open.append("%s (%d open edges, %d in LDraw's)" % [part_id, verdict["open"],
				own_gaps[part_id]])
		if verdict["out"]:
			facing += 1
		else:
			turned.append(part_id)
	_check("one closed volume per part: %d of %d, and %d whose LDraw shape has gaps of its own, written as LDraw draws them (%s)%s"
		% [closed, spans.size(), spans.size() - closed - open.size(),
		", ".join(as_drawn.keys().map(func(id: String) -> String: return "%s, %d edges" % [id, as_drawn[id]])),
		"" if open.is_empty() else " — opened in writing: " + ", ".join(open.slice(0, 5))],
		open.is_empty() and closed > spans.size() / 2)
	_check("...each facing out, the faces at its far side in every direction facing that way: %d of %d%s"
		% [facing, spans.size(), "" if turned.is_empty() else " — " + ", ".join(turned.slice(0, 5))],
		facing == spans.size())
	_check("...each triangle's stated normal its winding's", normals_agree)
	# Millimetres, standing on Z: the window's box turned up and scaled.
	var framed: AABB = _main.call("_built_bounds")
	var want_low := Vector3(framed.position.x, -framed.end.z, framed.position.y) * MeshExport.MILLIMETRES
	var want_high := Vector3(framed.end.x, -framed.position.z, framed.end.y) * MeshExport.MILLIMETRES
	var off: float = _apart(low, want_low, high, want_high) / MeshExport.MILLIMETRES
	_check("in millimetres, standing on Z: %.1f x %.1f x %.1f mm, %.3f LDU off the window's box"
		% [(high - low).x, (high - low).y, (high - low).z, off], off <= 1.0)


## A part's own triangles from the library, in millimetres and turned the
## way the export turns them, for what its LDraw shape is before writing.
func _own_corners(part_id: String) -> PackedVector3Array:
	var corners := PackedVector3Array()
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	for surface: ArrayMesh in part.surfaces:
		var arrays: Array = surface.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i: int in range(0, index.size() - 2, 3):
			for corner: int in [index[i], index[i + 2], index[i + 1]]:
				corners.append(v[corner] * MeshExport.MILLIMETRES)
	return corners


## Whether a part's triangles close round a volume, and face out of it.
##
## LDraw parts are closed but not stitched: a stud's wall stands on the top
## face, which runs on under it, so the stud's bottom edge belongs to one
## triangle. That edge is not a hole, because the face it stands on is there.
## So an edge only one triangle has (or three) must lie on another triangle
## of the part; an edge in the air is a hole. Some LDraw shapes have holes of
## their own (4600's underside is open by 0.8 mm), which the caller compares
## against. Facing out: in each of six directions, the faces that reach the
## part's far side that way face that way.
static func _volume(corners: PackedVector3Array) -> Dictionary:
	var edges: Dictionary = {}
	var owner: Dictionary = {}
	var keys := PackedStringArray()
	for p: Vector3 in corners:
		var q := Vector3i((p * 100.0).round())
		keys.append("%d,%d,%d" % [q.x, q.y, q.z])
	var triangles: int = corners.size() / 3
	for t: int in triangles:
		for e: int in 3:
			var a: String = keys[t * 3 + e]
			var b: String = keys[t * 3 + (e + 1) % 3]
			var key: String = a + "|" + b if a < b else b + "|" + a
			edges[key] = int(edges.get(key, 0)) + 1
			if not owner.has(key):
				owner[key] = Vector3i(t, t * 3 + e, t * 3 + (e + 1) % 3)
	var open: int = 0
	for key: String in edges:
		if int(edges[key]) % 2 == 0:
			continue
		var which: Vector3i = owner[key]
		var middle: Vector3 = (corners[which.y] + corners[which.z]) * 0.5
		var covered: bool = false
		for t: int in triangles:
			if t != which.x and _on_triangle(middle, corners[t * 3], corners[t * 3 + 1],
					corners[t * 3 + 2]):
				covered = true
				break
		if not covered:
			open += 1
	var out: bool = true
	for way: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.BACK]:
		var far: float = -INF
		for p: Vector3 in corners:
			far = maxf(far, p.dot(way))
		var facing: float = 0.0
		for t: int in triangles:
			var a: Vector3 = corners[t * 3]
			var b: Vector3 = corners[t * 3 + 1]
			var c: Vector3 = corners[t * 3 + 2]
			if maxf(a.dot(way), maxf(b.dot(way), c.dot(way))) > far - 0.01:
				facing += (b - a).cross(c - a).dot(way)
		out = out and facing > 0.0
	return {"closed": open == 0, "open": open, "out": out}


## Whether [param p] lies on the triangle, to a hundredth of a millimetre.
static func _on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var normal: Vector3 = (b - a).cross(c - a)
	var area: float = normal.length()
	if area < 1e-9:
		return false
	normal /= area
	if absf(normal.dot(p - a)) > 0.01:
		return false
	var u: float = (b - p).cross(c - p).dot(normal) / area
	var v: float = (c - p).cross(a - p).dot(normal) / area
	var w: float = 1.0 - u - v
	var slack: float = 0.01 / sqrt(area)
	return u >= -slack and v >= -slack and w >= -slack


# -- sub-models -----------------------------------------------------------------------


## Two copies of a wing and a part of the model's own: a node for each copy,
## named as the outliner names it, holding its own parts.
func _sub_models() -> void:
	print("── sub-models become nodes ──")
	_main.call("clear_model")
	var builder: Builder = _main.get("_builder")
	for placed: Array in [["3001", Vector3(0, 0, 0), "Wing#1"], ["3001", Vector3(0, -24, 0), "Wing#1"],
			["3001", Vector3(100, 0, 0), "Wing#2"], ["3001", Vector3(100, -24, 0), "Wing#2"],
			["3003", Vector3(50, 0, 60), ""]]:
		var at := Transform3D(Basis.IDENTITY, placed[1])
		var brick_id: int = _world.add_brick(placed[0], 4, at)
		builder.register(brick_id, placed[0], at)
		_world.get_brick(brick_id).unit = placed[2]
		_world.get_brick(brick_id).group = Assemblies.group_of(placed[2])
	await process_frame
	var said: String = await _say("export_model", {"format": "glb"})
	var path: String = _written(said)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		_check("the GLB with sub-models reads back: %s" % said, false)
		return
	var scene: Node = document.generate_scene(state)
	var holding: PackedStringArray = []
	for node: Node in scene.find_children("*", "Node3D", true, false):
		var parts: int = node.get_children().filter(func(child: Node) -> bool:
			return child is MeshInstance3D).size()
		if parts > 0:
			holding.append("%s: %d" % [node.name, parts])
	holding.sort()
	_check("a node for each copy of a sub-model, holding its parts: %s" % ", ".join(holding),
		holding.has("Wing: 2") and holding.has("Wing (copy 2): 2") and holding.size() == 3)
	scene.free()


# -- Orthanc --------------------------------------------------------------------------


func _orthanc() -> void:
	print("── the castle and Orthanc, every format, past the caps ──")
	var caps: Dictionary = MeshExport.most_triangles.duplicate()
	MeshExport.most_triangles = {"obj": 1 << 40, "stl": 1 << 40}
	for model: String in ["Castle", "Orthanc"]:
		var began: int = Time.get_ticks_msec()
		var said: String = await _say("open_model", {"name": model, "discard_changes": true})
		var parts: int = _parts().size()
		print("  %s in %d ms, %s triangles" % [said.left(40), Time.get_ticks_msec() - began,
			Working.comma(_triangles())])
		if model == "Orthanc":
			_check("Orthanc opens whole: %d parts" % parts, parts == ORTHANC_PARTS)
		# OBJ last: past its cap it is 273 MB, and the STL's one 123 MB buffer
		# taken just after it was freed once held the frame 709 ms (170 ms
		# otherwise), which is not what anyone exporting meets.
		for format: String in ["glb", "gltf", "stl", "obj"]:
			await _time_from_here()
			began = Time.get_ticks_msec()
			said = await _say("export_model", {"format": format})
			var took: int = Time.get_ticks_msec() - began
			_timing = false
			var path: String = _written(said)
			var size: int = FileAccess.get_file_as_bytes(path).size() if not path.is_empty() else 0
			print("  %s %s: %.1f s, %.1f MB, the frame held at most %d ms%s, memory peak %.0f MB" % [
				model, format, took / 1000.0, size / 1048576.0, _held_us / 1000,
				"" if _long.is_empty() else " (" + ", ".join(_long.slice(0, 4)) + ")",
				OS.get_static_memory_peak_usage() / 1048576.0])
			if model != "Orthanc":
				continue
			_check("Orthanc as %s: no frame held past 250 ms (%d)" % [format, _held_us / 1000],
				_held_us < 250000)
			match format:
				"glb":
					_check("Orthanc's GLB whole: %.1f s, %.1f MB" % [took / 1000.0, size / 1048576.0],
						said.contains(Working.comma(ORTHANC_PARTS) + " parts"))
					var document := GLTFDocument.new()
					var state := GLTFState.new()
					var read: Error = document.append_from_file(path, state)
					var scene: Node = document.generate_scene(state) if read == OK else null
					var meshes: int = scene.find_children("*", "MeshInstance3D", true, false).size() \
						if scene != null else -1
					_check("...read back by GLTFDocument: %d mesh nodes, from %d meshes" % [meshes,
						state.get_meshes().size()], meshes == ORTHANC_PARTS)
					if scene != null:
						scene.free()
				"stl":
					_check("Orthanc's STL: %.1f s, %.1f MB, every triangle" % [took / 1000.0,
						size / 1048576.0], said.contains(Working.comma(ORTHANC_PARTS) + " parts") and size == 84 + 50 * _triangles())
	MeshExport.most_triangles = caps
	var said: String = await _say("export_model", {"format": "obj"})
	_check("under its cap, Orthanc's OBJ is refused, pointing at GLB: %s" % said.left(140),
		said.contains("holds up to") and said.contains("GLB") and _written(said).is_empty())


# -- helpers --------------------------------------------------------------------------


func _triangles() -> int:
	var total: int = 0
	for brick: BrickWorld.Brick in _parts():
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		total += part.triangle_count if part != null else 0
	return total


static func _written(said: String) -> String:
	if not said.begins_with("Wrote "):
		return ""
	return said.trim_prefix("Wrote ").get_slice(" — ", 0).get_slice(" and ", 0).trim_suffix(".")


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    " + what)
	else:
		_failures += 1
		print("  FAIL  " + what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("the model comes out as a 3D file other programs read whole")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures > 0 else 0)
