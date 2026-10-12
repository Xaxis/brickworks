## Moulds of one's own: sculpted parts whose connection stays exactly as
## it was.
##
##   godot --headless --path . --script src/dev/mould_probe.gd
##
## The claim of Mould is that sculpting changes a part's shape and never
## what joins it to anything. So every brush and the lattice are run at
## full strength over a hair piece, a dome and a club, and the corners
## each locks are checked not to have moved by any amount at all; the
## socket a hair piece sits on the head's stud with, and the bar a hand
## closes on, are found locked; nothing free ends inside the head;
## symmetry moves the other side; finer corners keep the shape; undo puts
## every corner back. Then the part is made: its connectors are the
## original's to the bit, it builds, a figure wearing or holding it
## stands exactly as one with the original does, on a plate, stable, and
## the file carries it into a library that never saw it.
##
## Made parts go to user://mould_probe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary

const PROBE_DIR := "user://mould_probe_parts/"


func _initialize() -> void:
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("\na hair piece, as it comes")
	var hair: Mould = Mould.of_part(_library, "3901", "headwear")
	_ok(hair != null and hair.on_head and hair.triangle_count() > 600,
		"3901 welded into one surface of %d triangles, worn on the head"
			% (hair.triangle_count() if hair != null else 0))
	if hair == null:
		quit(1)
		return
	var locked: int = 0
	var free: int = 0
	var socket_locked: bool = true
	for v: int in hair.positions.size():
		if hair.locks[v] >= 1.0:
			locked += 1
		elif hair.locks[v] <= 0.0:
			free += 1
		# Round the head's stud, where the socket is.
		var p: Vector3 = hair.positions[v]
		if Vector2(p.x, p.z).length() < 7.0 and p.y > -1.0 and p.y < 5.0:
			socket_locked = socket_locked and hair.locks[v] >= 1.0
	_ok(locked > 50 and free > 100, "its inside, resting on the head, is locked (%d corners) "
		% locked + "and its outside free (%d)" % free)
	_ok(socket_locked, "every corner round the head's stud — the socket — is locked")
	var inside_head: int = 0
	for v: int in hair.positions.size():
		if Mould.head_depth(hair.positions[v]) > 0.3:
			inside_head += 1
	_ok(inside_head == 0, "and as LEGO made it, none of it is in the head by more than a "
		+ "drawing's 0.3 LDU (%d)" % inside_head)

	print("\nsculpted")
	var before: PackedVector3Array = hair.positions.duplicate()
	var triangles: int = hair.refine(Mould.FINEST * 2.0)
	var still: bool = true
	for v: int in before.size():
		still = still and hair.positions[v] == before[v]
	_ok(triangles > hair.triangle_count() - 1 and triangles <= Mould.MOST_TRIANGLES and still,
		"made finer, %d triangles, every corner it had where it was" % triangles)
	var original: PackedVector3Array = hair.positions.duplicate()
	var locks: PackedFloat32Array = hair.locks.duplicate()
	# A quiff: pull the front of the top up and forward, hard, both sides.
	var top: Dictionary = hair.pick(Vector3(14, 60, 12), Vector3(-6, -60, -12).normalized())
	_ok(not top.is_empty(), "a ray from above the front finds the hair at %s" % top.get("at"))
	var moved: int = 0
	if not top.is_empty():
		hair.begin()
		for n: int in 12:
			moved += hair.dab("pull", top["at"], top["normal"], 9.0, 1.0, true)
	var mirrored: bool = false
	var furthest: float = 0.0
	for v: int in hair.positions.size():
		var shift: float = hair.positions[v].distance_to(original[v])
		furthest = maxf(furthest, shift)
		if shift > 0.5 and hair.positions[v].x < -2.0 and not top.is_empty() \
				and (top["at"] as Vector3).x > 2.0:
			mirrored = true
	_ok(moved > 50 and furthest > 3.0, "pulled: %d corner moves, up to %.1f LDU" % [moved, furthest])
	_ok(mirrored, "with symmetry the other side came too")
	for tool: String in ["push", "inflate", "smooth", "pinch", "flatten"]:
		for at: Vector3 in [Vector3(14, -4, 0), Vector3(0, 6, 0), Vector3(-10, -10, -10)]:
			var hit: Dictionary = hair.pick(at * 4.0, -at.normalized())
			if not hit.is_empty():
				hair.begin()
				for n: int in 6:
					hair.dab(tool, hit["at"], hit["normal"], 10.0, 1.0, true)
	hair.lattice_begin()
	hair.lattice_move(26, hair.lattice_handles()[26] + Vector3(4, 6, 4), true)
	hair.lattice_move(0, hair.lattice_handles()[0] + Vector3(-3, -3, -3), true)
	hair.lattice_end()
	hair.grab(Vector3(0, 7, -10), 8.0, true)
	hair.drag(Vector3(0, 3, -4))
	hair.let_go()
	var locked_moved: float = 0.0
	var into_head: int = 0
	for v: int in hair.positions.size():
		if locks[v] >= 1.0:
			locked_moved = maxf(locked_moved, hair.positions[v].distance_to(original[v]))
		elif Mould.head_depth(hair.positions[v]) > maxf(-Mould.HEAD_MARGIN,
				Mould.head_depth(original[v])) + 1e-3:
			into_head += 1
	_ok(locked_moved == 0.0,
		"after every brush at full strength, the lattice and a grab: not one locked corner "
			+ "moved by any amount (%.6f)" % locked_moved)
	_ok(into_head == 0, "and nothing free was pushed nearer the head than an LDU (%d)" % into_head)
	var walls: Dictionary = hair.walls()
	_ok(float(walls["thinnest"]) > 0.0 and float(walls["thin"]) < 1.0,
		"its walls measured: thinnest %.1f mm, %.0f%% under 1 mm"
			% [float(walls["thinnest"]) * Lbm.LDU_MM, float(walls["thin"]) * 100.0])
	var sculpted: PackedVector3Array = hair.positions.duplicate()
	hair.undo()
	_ok(hair.positions != sculpted, "undo takes the last change back")
	hair.redo()
	_ok(hair.positions == sculpted, "and redo puts it back")

	print("\nmade into a part")
	var made: Dictionary = hair.make(_library, "Probe Quiff")
	var id: String = made["id"]
	_ok(str(made["problem"]).is_empty() and id.begins_with("bw-3901-m") and _library.parts.has(id),
		"made %s %s" % [id, made["problem"]])
	if not str(made["problem"]).is_empty():
		_finish()
		return
	_same_connectors(id, "3901")
	var text: String = _library.custom_source(id)
	_ok(text.length() < 700000 and PartPrints.base_in(text) == "3901",
		"its file is %d kB, made from 3901" % (text.length() / 1000))
	var built: Lbm.PartMesh = _library.mesh_for(id)
	_ok(built.boxes.size() > 0 and built.triangle_count == hair.triangle_count(),
		"built with a collision cover of %d boxes (3901 has %d) and its %d triangles"
			% [built.boxes.size(), _library.mesh_for("3901").boxes.size(), built.triangle_count])
	_ok(_library.parts[id].name.begins_with("Minifig Hair Male, Custom Mould")
			and Minifig.slot_for(_library.parts[id]) == "headwear",
		"it is offered as headgear: %s" % _library.parts[id].name)

	print("\na dome and a club, from nothing")
	var dome: Mould = Mould.dome()
	dome.refine(Mould.FINEST * 2.0)
	var dome_inside: int = 0
	var dome_socket: bool = true
	for v: int in dome.positions.size():
		if Mould.head_depth(dome.positions[v]) > 0.0:
			dome_inside += 1
		var p: Vector3 = dome.positions[v]
		if Vector2(p.x, p.z).length() < 6.5 and p.y > -0.5 and p.y < 4.5:
			dome_socket = dome_socket and dome.locks[v] >= 1.0
	_ok(dome_inside == 0 and dome_socket, "the dome clears the head and its socket is locked")
	var crown: Dictionary = dome.pick(Vector3(0, 80, 0), Vector3.DOWN)
	if not crown.is_empty():
		dome.begin()
		for n: int in 8:
			dome.dab("pull", crown["at"], crown["normal"], 6.0, 1.0, false)
	var dome_made: Dictionary = dome.make(_library, "Probe Topknot")
	_ok(str(dome_made["problem"]).is_empty(), "a dome with a topknot pulled up: %s" % dome_made)
	var club: Mould = Mould.club()
	club.refine(Mould.FINEST * 2.0)
	var bar_locked: bool = true
	for v: int in club.positions.size():
		var p: Vector3 = club.positions[v]
		if p.y < 1.0 and p.y > -17.0:
			bar_locked = bar_locked and club.locks[v] >= 1.0
	_ok(bar_locked, "the club's bar, where a hand closes on it, is locked")
	var head_of_club: Dictionary = club.pick(Vector3(40, 22, 0), Vector3.LEFT)
	if not head_of_club.is_empty():
		club.begin()
		for n: int in 6:
			club.dab("inflate", head_of_club["at"], head_of_club["normal"], 8.0, 1.0, true)
	var club_made: Dictionary = club.make(_library, "Probe Club")
	_ok(str(club_made["problem"]).is_empty(), "a club with a swollen head: %s" % club_made)
	var held: String = club_made["id"]
	if _library.parts.has(held):
		var bar: bool = false
		for c: Lbm.Connector in _library.mesh_for(held).connectors:
			bar = bar or (c.kind == "shaft" and is_equal_approx(c.radius, 4.0))
		_ok(bar, "its bar is a 4 LDU round, the 3.18 mm a hand holds")

	print("\non a figure")
	var plain := Minifig.new()
	plain.parts["headwear"] = "3901"
	plain.parts["accessory"] = "3847"
	var moulded := Minifig.new()
	moulded.parts["headwear"] = id
	moulded.parts["accessory"] = held
	var a: Array[Dictionary] = plain.assemble(_library)
	var b: Array[Dictionary] = moulded.assemble(_library)
	var same: bool = a.size() == b.size()
	var swapped: Dictionary = {}
	for n: int in mini(a.size(), b.size()):
		same = same and (a[n]["at"] as Transform3D).is_equal_approx(b[n]["at"])
		if a[n]["part"] != b[n]["part"]:
			swapped[a[n]["part"]] = b[n]["part"]
	_ok(same and swapped.size() == 2,
		"the hair sits where 3901 sits and the club is held where 3847 is (%s)" % swapped)
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	await process_frame
	var plate := Transform3D(Basis.IDENTITY, Vector3(40, 8, 10))
	builder.register(world.add_brick("3023", 15, plate), "3023", plate)
	builder.hold_figure(b, "Probe")
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	var first: int = builder.place()
	_ok(first != 0 and builder.figure_of(first).size() == b.size(),
		"placed on a 1 x 2 plate like any figure (%d parts)" % builder.figure_of(first).size())
	var stability := Stability.new()
	stability.library = _library
	stability.lattice = builder.lattice
	var report: Stability.Report = stability.check(world)
	_ok(report.is_stable(), "it stands: %s" % report.summary())

	print("\nin a model file")
	var placements: Array = []
	for item: Dictionary in b:
		placements.append(LdrModel.Placement.new(item["part"], item["color"], item["at"], 0))
	var used: Array = b.map(func(item: Dictionary) -> String: return str(item["part"]))
	var file: String = LdrModel.write_ldr(placements, "Probe", "Brickworks", {},
		CustomParts.sources_for(_library, used))
	var read: LdrModel = LdrModel.parse(file, "probe.mpd")
	CustomParts.dir = PROBE_DIR + "elsewhere/"
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var carried: Dictionary = CustomParts.take_from(fresh, read)
	_ok((carried["added"] as Array).size() == 2 and fresh.mesh_for(id) != null
			and fresh.mesh_for(id).triangle_count == built.triangle_count
			and fresh.mesh_for(id).boxes == built.boxes,
		"a library that never saw them builds both from the file, the same to the cell %s"
			% carried["added"])
	CustomParts.dir = PROBE_DIR
	world.queue_free()
	builder.queue_free()
	_finish()


## A made part's connectors are the original's: the same kinds, places
## and directions, to the float.
func _same_connectors(id: String, base: String) -> void:
	var made: Array = _library.mesh_for(id).connectors
	var plain: Array = _library.mesh_for(base).connectors
	var worst: float = 0.0
	var kinds: bool = made.size() == plain.size()
	for n: int in mini(made.size(), plain.size()):
		var c: Lbm.Connector = made[n]
		var o: Lbm.Connector = plain[n]
		kinds = kinds and c.kind == o.kind and c.gender == o.gender
		worst = maxf(worst, c.position.distance_to(o.position))
		worst = maxf(worst, c.axis.distance_to(o.axis))
	_ok(kinds and worst < 1e-4, "%s's %d connectors are %s's, kind for kind and place for place "
		% [id, made.size(), base] + "(worst %.6f)" % worst)


func _finish() -> void:
	_forget(PROBE_DIR + "elsewhere/")
	_forget(PROBE_DIR)
	if _failures == 0:
		print("\na mould sculpted here keeps its connection exactly, and stands, saves and travels")
	else:
		print("\n%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
