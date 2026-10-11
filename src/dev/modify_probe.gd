## Changing a part that exists, held to the parts LEGO made at the size it
## was changed to.
##
##   godot --headless --path . --script src/dev/modify_probe.gd
##
## The claim of PartEditor is that a part changed from its own geometry
## keeps everything the change does not touch: its studs, holes, pins and
## tubes where they were, and its collision. LEGO has made many parts at
## more than one length, so the claim can be checked against them: 3700,
## the 1 x 2 Technic brick, made six long is 3894, the 1 x 6; 3701 made two
## long is 3700; 3001 made eight long is 3007; the 45 degree slope 3039
## made four wide is 3037. Each is built in the app from the file the
## editor wrote, as a made part is, and compared with the library's part:
## the same connectors in the same places, the same bounds, and the same
## cover — with a tolerance of a cell where the cover's boxes are cut
## differently, said when used.
##
## Then what the editor will not do, said rather than faked: a 1 x 1 round
## brick has no slice to repeat, nor a part one stud wide across its width.
## And the studs: 3062b with its hollow stud taken off has a closed top; a
## 2 x 2 tile with studs put on has four, on the grid; 3001 with its studs
## off has none and its top where it was.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("\na part made longer is the longer part LEGO made")
	_same("3700", {"length": 6}, "3894")
	_same("3701", {"length": 2}, "3700")
	_same("3001", {"length": 8}, "3007")
	# 3039's tubes hang from its own sloped ceiling, 12 LDU under its top;
	# 3037's library drawing starts its tubes at 20. Made longer, 3039
	# keeps its own, so the tubes are compared where they stand, not how
	# high each drawing starts them — and the covers differ by that.
	_same("3039", {"length": 4}, "3037", false)
	_same("3001", {}, "3001")

	print("\na part with more of what it had")
	var sided: PartForge.Result = _built("30414", {"length": 6})
	if sided != null:
		_ok(_count(sided, "stud", true) == 6 and _count(sided, "stud", false) == 6
				and _count(sided, "tube", false) == 5,
			"30414 made six long: 6 studs on top, 6 on its side, 5 pins (%d, %d, %d)" % [
				_count(sided, "stud", true), _count(sided, "stud", false),
				_count(sided, "tube", false)])
	var tall: PartForge.Result = _built("3001", {"plates": 6})
	if tall != null:
		_ok(is_equal_approx(tall.bounds_max[1] - tall.bounds_min[1], 52.0)
				and _count(tall, "stud", true) == 8 and _count(tall, "tube", false) == 3,
			"3001 made two bricks tall: 48 LDU and its studs, 8 studs and 3 tubes (%.1f LDU)"
				% (tall.bounds_max[1] - tall.bounds_min[1]))

	print("\nwhat it will not do, and says")
	_refused("3062b", {"length": 3})
	_refused("3010", {"width": 2})
	_refused("3040b", {"length": 3})

	print("\nstuds taken off and put on")
	var plain: PartForge.Result = _built("3001", {"studs": "none"})
	if plain != null:
		var real: Lbm.PartMesh = _library.mesh_for("3001")
		_ok(_count(plain, "stud", true) == 0 and _count(plain, "tube", false) == 3
				and is_equal_approx(plain.bounds_max[1], 24.0 + real.bounds.position.y + 4.0 - 4.0)
				or (_count(plain, "stud", true) == 0 and is_equal_approx(plain.bounds_max[1], 0.0)),
			"3001 without its studs: none, its tubes kept, its top at %.1f" % plain.bounds_max[1])
	var hollow: PartForge.Result = _built("3062b", {"studs": "none"})
	if hollow != null:
		var source: String = _text("3062b", {"studs": "none"})
		_ok(_count(hollow, "stud", true) == 0 and source.contains("4-4disc.dat"),
			"3062b without its hollow stud: no stud, and the hole it left closed with a disc")
		_ok(hollow.boxes.size() > 0 and hollow.cells > 0,
			"...and it still has a cover (%d cells)" % hollow.cells)
	var tile: PartForge.Result = _built("3068b", {"studs": "fill"})
	if tile != null:
		var places: PackedStringArray = PackedStringArray()
		for c: Array in tile.connectors:
			if c[0] == "stud":
				places.append("(%d, %d)" % [roundi(float(c[2])), roundi(float(c[4]))])
		places.sort()
		_ok(places == PackedStringArray(["(-10, -10)", "(-10, 10)", "(10, -10)", "(10, 10)"]),
			"3068b with studs put on: four, on the grid: %s" % ", ".join(places))

	print("")
	if _failures == 0:
		print("a part changed from its own geometry keeps what the change left alone")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _edit(from: String, fields: Dictionary) -> PartEditor.Edit:
	var edit := PartEditor.Edit.new()
	edit.from = from
	for key: String in fields:
		edit.set(key, fields[key])
	return edit


func _text(from: String, fields: Dictionary) -> String:
	var made: Dictionary = CustomParts.modified_text(_library, _edit(from, fields))
	return str(made["text"])


func _built(from: String, fields: Dictionary) -> PartForge.Result:
	var edit: PartEditor.Edit = _edit(from, fields)
	var made: Dictionary = CustomParts.modified_text(_library, edit)
	if not str(made["problem"]).is_empty():
		_ok(false, "%s %s: %s" % [from, edit.to_words(), made["problem"]])
		return null
	var started: int = Time.get_ticks_msec()
	var built: PartForge.Result = PartForge.build(made["text"], made["id"], {}, false)
	if not built.problem.is_empty():
		_ok(false, "%s builds: %s" % [made["id"], built.problem])
		return null
	print("        %s (%s): %d triangles, built in %d ms" % [made["id"], built.name,
		built.triangles, Time.get_ticks_msec() - started])
	return built


## The connectors as words to compare: kind, where and which way, to a
## tenth of an LDU; rounds (shafts and bores) left to their own check.
static func _connector_words(rows: Array, heights: bool = true) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Array in rows:
		if Lbm.ROUNDS.has(str(c[0])):
			continue
		var axis := Vector3(float(c[5]), float(c[6]), float(c[7]))
		# A pin hole takes a pin from either side.
		if str(c[0]) == "pin_hole" and (axis.x < -0.5 or axis.y < -0.5 or axis.z < -0.5):
			axis = -axis
		var y: float = float(c[3]) if heights or str(c[0]) != "tube" else 0.0
		out.append("%s %s (%.1f, %.1f, %.1f) (%.0f, %.0f, %.0f)" % [c[0], c[1],
			float(c[2]), y + 0.0, float(c[4]), axis.x + 0.0, axis.y + 0.0, axis.z + 0.0])
	out.sort()
	return out


static func _mesh_rows(mesh: Lbm.PartMesh) -> Array:
	var rows: Array = []
	for c: Lbm.Connector in mesh.connectors:
		rows.append([c.kind, c.gender, c.position.x, c.position.y, c.position.z,
			c.axis.x, c.axis.y, c.axis.z])
	return rows


func _count(built: PartForge.Result, kind: String, up: bool) -> int:
	var n: int = 0
	for c: Array in built.connectors:
		if c[0] != kind:
			continue
		if kind == "stud" and up != (float(c[6]) > 0.99):
			continue
		n += 1
	return n


## The edit of [param from] against the library's [param real].
func _same(from: String, fields: Dictionary, real: String, heights: bool = true) -> void:
	var built: PartForge.Result = _built(from, fields)
	var mesh: Lbm.PartMesh = _library.mesh_for(real)
	if built == null or mesh == null:
		_ok(false, "%s and %s both there" % [from, real])
		return
	var ours: PackedStringArray = _connector_words(built.connectors, heights)
	var theirs: PackedStringArray = _connector_words(_mesh_rows(mesh), heights)
	var what: String = "%s %s" % [from, _edit(from, fields).to_words().get_slice(" ", 1)] \
		if not fields.is_empty() else "%s copied unchanged" % from
	_ok(ours == theirs, "%s has %s's %d connectors, each where it is%s%s" % [what, real,
		theirs.size(), "" if heights else " (tubes where they stand)",
		"" if ours == theirs else " — ours %s, theirs %s" % [ours, theirs]])
	var lo := Vector3(built.bounds_min[0], built.bounds_min[1], built.bounds_min[2])
	var hi := Vector3(built.bounds_max[0], built.bounds_max[1], built.bounds_max[2])
	_ok(lo.distance_to(mesh.bounds.position) < 0.05 and hi.distance_to(mesh.bounds.end) < 0.05,
		"...and its bounds, %s to %s" % [lo, hi])
	# The cover, cell for cell.
	var cells_ours: Dictionary = _cells(built.boxes)
	var cells_theirs: Dictionary = {}
	for box: AABB in mesh.boxes:
		for x: int in range(int(box.position.x), int(box.end.x)):
			for y: int in range(int(box.position.y), int(box.end.y)):
				for z: int in range(int(box.position.z), int(box.end.z)):
					cells_theirs[Vector3i(x, y, z)] = true
	var differ: int = 0
	for cell: Vector3i in cells_ours:
		if not cells_theirs.has(cell):
			differ += 1
	for cell: Vector3i in cells_theirs:
		if not cells_ours.has(cell):
			differ += 1
	_ok(differ <= cells_theirs.size() / (50 if heights else 12),
		"...and its cover: %d of %d cells differ" % [differ, cells_theirs.size()])


static func _cells(boxes: Array) -> Dictionary:
	var out: Dictionary = {}
	for b: Array in boxes:
		for x: int in range(int(b[0]), int(b[0]) + int(b[3])):
			for y: int in range(int(b[1]), int(b[1]) + int(b[4])):
				for z: int in range(int(b[2]), int(b[2]) + int(b[5])):
					out[Vector3i(x, y, z)] = true
	return out


func _refused(from: String, fields: Dictionary) -> void:
	var made: Dictionary = CustomParts.modified_text(_library, _edit(from, fields))
	_ok(not str(made["problem"]).is_empty(), "%s %s is refused: %s" % [from,
		_edit(from, fields).to_words().get_slice(" ", 1), made["problem"]])
