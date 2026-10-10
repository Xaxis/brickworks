## A made part, used the way a designer uses one.
##
##   godot --headless --path . --script src/dev/element_probe.gd
##
## The three the owner asked for — a 2 x 7 brick, a 1 x 5 plate and a
## 3 x 3 x 2/3 slope — made through the dialog's own controls, and a 2 x 7
## made again by resizing 3001. Then each is:
##
##   in the library and the parts bin, under Custom
##   placed by hand on a baseplate, through the ray the mouse casts
##   clutched by a standard 2 x 4 below it — that brick's studs reach into
##   it, at the made part's own sockets — and clutching one above it
##   exactly as big as it says: a neighbour touching any side is fine and
##   one lattice cell closer is refused; on a slope, the space over the
##   face is free and under it is not
##   checked by the same design checker the assistant is, which finds
##   nothing floating, nothing loose and nothing overlapping
##   in the parts list, marked as a custom element
##   saved, and opened again into a library that has never seen it: the
##   model file carries the part, and the part comes back with it
##
## Made parts go to user://custom_parts_probe/, never the person's own.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _assistant: Assistant
var _base: int = 0

const PROBE_DIR := "user://custom_parts_probe/"


func _initialize() -> void:
	_forget_kept()
	CustomParts.dir = PROBE_DIR
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
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	get_root().add_child(_assistant)
	var dialog := ElementDialog.new()
	dialog.library = _library
	get_root().add_child(dialog)
	await process_frame

	print("\nmade through the dialog, as a person would")
	var brick: String = await _make(dialog, "brick", {"across": 7, "deep": 2, "plates": 3},
		"Brick  2 x  7")
	var plate: String = await _make(dialog, "brick", {"across": 5, "deep": 1, "plates": 1},
		"Plate  1 x  5")
	var slope: String = await _make(dialog, "slope",
		{"across": 3, "deep": 3, "run": 2, "plates": 2}, "Slope Brick 17  3 x  3 x   2/3")
	_resized(dialog)
	if brick.is_empty() or plate.is_empty() or slope.is_empty():
		_finish()
		return

	print("\nin the library and the parts bin")
	_in_the_bin([brick, plate, slope])

	_base = _lay_baseplate()
	print("\nthe 2 x 7 brick, on a 2 x 4 on the baseplate, under a 2 x 4")
	_stack(brick, Vector3(0, 0, 0))
	print("\nthe 1 x 5 plate")
	_stack(plate, Vector3(200, 0, 0))
	print("\nthe 3 x 3 x 2/3 slope")
	_stack(slope, Vector3(-200, 0, 0))
	_slope_face(slope)

	print("\nwhat the assistant's checker makes of all of it")
	_checker()

	print("\nin the parts list")
	_parts_list([brick, plate, slope])

	print("\nsaved, and opened where the parts were never made")
	await _round_trip([brick, plate, slope])
	_finish()


func _finish() -> void:
	_forget_kept()
	print("")
	if _failures == 0:
		print("a made part is placed, clutched, checked, listed and saved like any other")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget_kept() -> void:
	if not DirAccess.dir_exists_absolute(PROBE_DIR):
		return
	for name: String in DirAccess.get_files_at(PROBE_DIR):
		DirAccess.remove_absolute(PROBE_DIR + name)
	DirAccess.remove_absolute(PROBE_DIR)


## Set the dialog's controls, press Add, and take the part it made.
func _make(dialog: ElementDialog, family: String, fields: Dictionary,
		title: String) -> String:
	dialog.open()
	dialog.set_field("family", family)
	for field: String in fields:
		dialog.set_field(field, fields[field])
	var built: PartForge.Result = dialog.built()
	_ok(built != null and built.problem.is_empty(),
		"%s: the preview built (%s)" % [title.strip_edges(), "" if built == null
			else ElementDialog.describe(dialog.spec(), built)])
	var made: Array = []
	dialog.made.connect(func(id: String) -> void: made.append(id), CONNECT_ONE_SHOT)
	dialog.press_add()
	await process_frame
	var id: String = made[0] if not made.is_empty() else ""
	var info: PartLibrary.PartInfo = _library.parts.get(id)
	_ok(info != null and info.name == title,
		"Add made %s, \"%s\"" % [id, info.name if info != null else "nothing"])
	_ok(FileAccess.file_exists(PROBE_DIR + id + ".dat"), "and kept it as %s.dat" % id)
	return id if info != null else ""


## The resize path: start from 3001, make it seven long.
func _resized(dialog: ElementDialog) -> void:
	dialog.open()
	_ok(dialog.start_from("3001"), "3001 can be started from")
	var from: ElementMaker.Spec = dialog.spec()
	_ok(from.family == "brick" and from.across == 4 and from.deep == 2
		and from.plates == 3, "...and reads as a brick 4 x 2, 3 plates")
	dialog.set_field("across", 7)
	var made: Array = []
	dialog.made.connect(func(id: String) -> void: made.append(id), CONNECT_ONE_SHOT)
	dialog.press_add()
	var id: String = made[0] if not made.is_empty() else ""
	var source: String = _library.custom_source(id)
	_ok(source.contains("0 // Resized from 3001.dat"),
		"resized to 7 long it is %s, and says it came from 3001" % id)
	_ok(not dialog.start_from("3001p01"),
		"a printed part is not offered for resizing")


func _in_the_bin(ids: Array) -> void:
	var bin := PartsBin.new()
	bin.library = _library
	get_root().add_child(bin)
	bin.populate()
	var listed: Array[PartLibrary.PartInfo] = bin._find("", "Custom")
	var found: PackedStringArray = PackedStringArray()
	for info: PartLibrary.PartInfo in listed:
		found.append(info.id)
	for id: String in ids:
		_ok(found.has(id), "%s is in the bin's Custom category" % id)
	_ok(bin._categories.has("Custom"), "Custom has its own button")
	var searched: Array[PartLibrary.PartInfo] = bin._find("brick 2 x 7", "All")
	_ok(not searched.is_empty() and searched[0].custom,
		"searching \"brick 2 x 7\" leads with the made one: %s" % [
			searched[0].id if not searched.is_empty() else "nothing"])
	bin.queue_free()


func _lay_baseplate() -> int:
	var at := Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var id: int = _world.add_brick("3811", 2, at)
	_builder.register(id, "3811", at)
	_store.scenery[id] = true
	_assistant.scenery[id] = true
	return id


## Put [param part_id] on a 2 x 4 on the baseplate and a 2 x 4 on it,
## each by the ray the mouse casts, and check the clutch both ways.
func _stack(part_id: String, near: Vector3) -> void:
	var below: int = _hand("3001", near)
	var made: int = _hand(part_id, near)
	# Over its studs, which on a slope are the flat rows at the back and
	# not the middle of it.
	var above: int = _hand("3001", _studs_middle(made)) if made != 0 else 0
	if below == 0 or made == 0 or above == 0:
		_ok(false, "the three could be placed by hand (%d, %d, %d)" % [below, made, above])
		return
	var under: BrickWorld.Brick = _world.get_brick(below)
	var it: BrickWorld.Brick = _world.get_brick(made)
	var over: BrickWorld.Brick = _world.get_brick(above)
	# Each rests on what is under it: its underside on the top of the one
	# below, to the LDU.
	var mesh: Lbm.PartMesh = _library.mesh_for(part_id)
	var base_of_it: float = it.transform.origin.y + mesh.bounds.position.y
	var top_of_under: float = under.transform.origin.y
	_ok(is_equal_approx(base_of_it, top_of_under),
		"placed by hand, it rests on the 2 x 4 at y = %.0f LDU" % base_of_it)
	var reach_up: Dictionary = _studs_into(under)
	_ok(int(reach_up.get(made, 0)) >= 2,
		"the 2 x 4 below clutches it: %d of its studs reach inside" % int(reach_up.get(made, 0)))
	_ok(_on_sockets(under, it, mesh),
		"...each at one of %s's sockets, the places a stud goes in" % part_id)
	var reach_over: Dictionary = _studs_into(it)
	_ok(int(reach_over.get(above, 0)) >= 2,
		"it clutches the 2 x 4 above: %d of its studs reach inside" % int(reach_over.get(above, 0)))
	print("        (2 x 4 below at %s, %s at %s, 2 x 4 above at %s)" % [
		under.transform.origin, part_id, it.transform.origin, over.transform.origin])
	_exact(it, mesh)


## Where a placed brick's studs are, on average, in the world.
func _studs_middle(brick_id: int) -> Vector3:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var sum := Vector3.ZERO
	var count: int = 0
	for c: Lbm.Connector in mesh.connectors:
		if c.kind == "stud":
			sum += brick.transform * c.position
			count += 1
	return Vector3(sum.x / count, 0.0, sum.z / count) if count > 0 else brick.transform.origin


## Place a part with the mouse's ray straight down at [param near].
func _hand(part_id: String, near: Vector3) -> int:
	_builder.held_part = part_id
	_builder.held_rotation = 0
	_builder.held_face = "up"
	_builder.update_preview(near + Vector3(0.3, 2000, 0.3), Vector3.DOWN)
	return _builder.place()


## Brick id -> how many of [param brick]'s studs reach into it: the
## sample the app's own clutch test takes, five LDU past each tip.
func _studs_into(brick: BrickWorld.Brick) -> Dictionary:
	var counts: Dictionary = {}
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	for c: Lbm.Connector in mesh.connectors:
		if c.kind != "stud" or c.gender != "male":
			continue
		var tip: Vector3 = brick.transform * (c.position + c.axis.normalized() * 5.0)
		var owner: int = _builder.lattice.brick_at(BrickLattice.to_cell(tip))
		if owner != 0 and owner != brick.id:
			counts[owner] = int(counts.get(owner, 0)) + 1
	return counts


## Whether every stud of [param lower] that reaches into [param upper]
## stands where [param upper] has a socket.
func _on_sockets(lower: BrickWorld.Brick, upper: BrickWorld.Brick,
		mesh: Lbm.PartMesh) -> bool:
	var sockets: Array[Vector2] = []
	for s: Vector2 in mesh.sockets:
		var at: Vector3 = upper.transform * Vector3(s.x, 0.0, s.y)
		sockets.append(Vector2(at.x, at.z))
	var lower_mesh: Lbm.PartMesh = _library.mesh_for(lower.part_id)
	var checked: int = 0
	for c: Lbm.Connector in lower_mesh.connectors:
		if c.kind != "stud":
			continue
		var tip: Vector3 = lower.transform * (c.position + c.axis * 5.0)
		if _builder.lattice.brick_at(BrickLattice.to_cell(tip)) != upper.id:
			continue
		checked += 1
		var hit: bool = false
		for s: Vector2 in sockets:
			if s.distance_to(Vector2(tip.x, tip.z)) < 0.01:
				hit = true
		if not hit:
			return false
	return checked > 0


## Touching on every side is allowed; a cell closer is not.
func _exact(it: BrickWorld.Brick, mesh: Lbm.PartMesh) -> void:
	var box: AABB = mesh.bounds
	# A 1 x 1 plate, so it stands level with the part's bottom and clear of
	# the 2 x 4s above and below, which overhang a part narrower than they
	# are.
	var probe: Lbm.PartMesh = _library.mesh_for("3024")
	var refused: int = 0
	var allowed: int = 0
	var wrong := PackedStringArray()
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		# Against this side, halfway along it.
		var reach: float = (box.size.x if side.x != 0.0 else box.size.z) * 0.5 + 10.0
		var centre: Vector3 = it.transform.origin + Vector3(
			box.get_center().x, 0.0, box.get_center().z)
		var touching := Transform3D(Basis.IDENTITY, Vector3(
			snappedf(centre.x + side.x * reach, 2.0), it.transform.origin.y + box.position.y + 8.0,
			snappedf(centre.z + side.z * reach, 2.0)))
		var closer := Transform3D(Basis.IDENTITY, touching.origin - side * BrickLattice.CELL)
		if not _builder.lattice.collides_boxes(_builder.boxes_for(probe, touching)):
			allowed += 1
		else:
			wrong.append("touching %s is refused" % side)
		if _builder.lattice.collides_boxes(_builder.boxes_for(probe, closer)):
			refused += 1
		else:
			wrong.append("a cell into %s is allowed" % side)
	_ok(allowed == 4 and refused == 4,
		"a 1 x 1 plate touching each of its four sides fits (%d of 4); a cell closer, it is refused (%d of 4)%s"
		% [allowed, refused, "" if wrong.is_empty() else " — " + ", ".join(wrong)])


## A slope's collision is the slope: over the face is free, under it is not.
func _slope_face(slope: String) -> void:
	var it: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == slope:
			it = brick
	if it == null:
		return
	var spec := ElementMaker.from_words("family=slope across=3 deep=3 plates=2 run=2")
	var h: float = spec.plates * ElementMaker.PLATE
	# In the part's own LDraw terms: the face falls from y = 0 at z = edge
	# to y = h - 4 at the front; the app has z the other way.
	var front: float = -spec.deep * 10.0
	var edge: float = front + spec.run * 20.0
	var free_over: int = 0
	var solid_under: int = 0
	for step: int in 4:
		var z: float = front + 5.0 + step * 9.0
		var face_y: float = (h - 4.0) * (edge - z) / (edge - front)
		for offset: float in [-3.0, 3.0]:
			var ldraw := Vector3(5.0, face_y + offset, z)
			var app: Vector3 = it.transform * Vector3(ldraw.x, -ldraw.y, -ldraw.z)
			var owner: int = _builder.lattice.brick_at(BrickLattice.to_cell(app))
			if offset < 0.0 and owner != it.id:
				free_over += 1
			if offset > 0.0 and owner == it.id:
				solid_under += 1
	_ok(free_over == 4 and solid_under == 4,
		"3 LDU over the face is free (%d of 4) and 3 under it is the slope (%d of 4)"
		% [free_over, solid_under])


func _checker() -> void:
	var model: Assistant.Model = _assistant._model_from_world()
	var report: Dictionary = _assistant._check(model, true)
	var said: String = str(report.get("feedback", ""))
	_ok(bool(report.get("ok", false)), "the design passes")
	for complaint: String in ["floating", "nothing holding", "overlap", "no stud anywhere",
			"no stud can reach", "collide"]:
		_ok(not said.to_lower().contains(complaint), "it says nothing about \"%s\"" % complaint)
	# Three stacks on the baseplate, and the checker finds three pieces:
	# each made part is joined to the 2 x 4 under it and the one over it,
	# or a stack would come apart into more.
	_ok(said.contains("in 3 pieces"),
		"it finds three pieces, one per stack: each made part joins both its 2 x 4s")
	if not said.is_empty():
		print("        (it said: %s)" % said.left(400).replace("\n", " / "))


func _parts_list(ids: Array) -> void:
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	for id: String in ids:
		var lot: Inventory.Lot = null
		for each: Inventory.Lot in stock.lots:
			if each.part_id == id:
				lot = each
		_ok(lot != null and lot.custom and lot.name.ends_with("(custom element)")
			and lot.element.is_empty(),
			"%s is listed as \"%s\", with no element number" % [id,
				lot.name if lot != null else "nothing"])
	_ok(stock.to_csv().contains("(custom element)"), "and the CSV says so too")


func _round_trip(ids: Array) -> void:
	var text: String = _store.to_text("made parts", true)
	for id: String in ids:
		_ok(text.contains("0 FILE %s.dat" % id), "the file carries %s.dat" % id)
	_ok(text.contains("0 !LDRAW_ORG Unofficial_Part"),
		"...as the unofficial part it is, header and all")
	var parsed: LdrModel = LdrModel.parse(text, "made.mpd")
	_ok(parsed.embedded_parts.size() == ids.size(),
		"read back, the file has %d parts in it, not sub-models" % parsed.embedded_parts.size())
	# And a sub-model that happens to be called door.dat, as older files
	# call theirs, is still a sub-model: no part header, no part.
	var older: LdrModel = LdrModel.parse("0 FILE house.ldr\n0 House\n"
		+ "1 16 0 0 0 1 0 0 0 1 0 0 0 1 door.dat\n0 NOFILE\n"
		+ "0 FILE door.dat\n0 Door\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
		+ "1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n", "house.mpd")
	_ok(older.embedded_parts.is_empty() and older.flatten(_library.parts).size() == 2,
		"a sub-model named door.dat still opens as its two bricks")
	var saved := "user://element_probe.mpd"
	var file: FileAccess = FileAccess.open(saved, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var bricks: int = _world.brick_count() - _store.scenery.size()
	_ok(ModelStore._count_bricks(saved) == bricks,
		"the Open menu counts %d bricks, not the studs inside the parts" % ModelStore._count_bricks(saved))
	_other_reader(ProjectSettings.globalize_path(saved), ids.size())
	DirAccess.remove_absolute(saved)

	# A library that has never seen these parts, and nowhere to find them
	# but the file.
	CustomParts.dir = PROBE_DIR + "elsewhere/"
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	for id: String in ids:
		_ok(not fresh.parts.has(id), "a fresh library does not have %s" % id)
	var world := BrickWorld.new()
	world.library = fresh
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = fresh
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = fresh
	store.builder = builder
	store.keeps = false
	var opened: Dictionary = store.open_text(text, "made.mpd")
	_ok(int(opened["placed"]) == bricks and int(opened["missing"]) == 0,
		"it opens whole: %d of %d bricks, %d missing" % [int(opened["placed"]), bricks,
			int(opened["missing"])])
	for id: String in ids:
		var info: PartLibrary.PartInfo = fresh.parts.get(id)
		_ok(info != null and info.custom and info.category == "Custom",
			"%s came with it, into the Custom category" % id)
	var same: int = 0
	var moved: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		var match_found: bool = false
		for was: BrickWorld.Brick in _world.bricks():
			if was.part_id == brick.part_id and was.color_code == brick.color_code \
					and was.transform.origin.is_equal_approx(brick.transform.origin) \
					and not _store.scenery.has(was.id):
				match_found = true
		if match_found:
			same += 1
		else:
			moved += 1
	_ok(same == bricks and moved == 0,
		"every brick is back where it was, in its colour (%d of %d)" % [same, bricks])
	var again: String = store.to_text("made parts", true)
	_ok(again.count("0 FILE bw-") == ids.size(),
		"and saved again from there, it still carries all %d" % ids.size())
	await process_frame


## The file read by a reader that is not this app's: tools/ldraw, the
## Python the mesh build uses, which shares no code with LdrModel. Every
## line has to parse strictly, the carried parts have to come out of it,
## and each has to resolve completely against the LDraw library.
func _other_reader(path: String, parts: int) -> void:
	if not DirAccess.dir_exists_absolute("res://vendor/ldraw/parts"):
		print("  --    no vendor/ldraw here, so another reader is not tried")
		return
	var tool: String = ProjectSettings.globalize_path("res://tools/build_custom.py")
	var out: Array = []
	var status: int = OS.execute("python3", [tool, path, "--check"], out, true)
	var said: String = "".join(out).strip_edges()
	var last: String = said.get_slice("\n", said.count("\n"))
	_ok(status == 0 and last.ends_with("%d parts, all complete" % parts),
		"tools/ldraw reads the file strictly and finds the %d parts complete (%s)"
		% [parts, last if status == 0 else said.right(300)])
