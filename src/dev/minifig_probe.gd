## Minifigures: against real ones, and as part of a model.
##
##   godot --headless --path . --script src/dev/minifig_probe.gd
##
## A figure's parts sit at offsets nobody can eyeball — an arm 15.552
## LDU out and turned 9.782 degrees — so they are checked against real
## figures, modelled part by part in real sets of LDraw's model
## repository: each part's place relative to the torso, ours against
## theirs, to a hundredth of an LDU where the set used the library's own
## numbers. Then the figure as a person uses one: stood on a stud and
## held by it, picked out and moved and turned as one thing, saved as a
## sub-model of its own and reopened the same, counted in the parts list
## part by part, and kept out of the measures real sets are counted
## without. And the design assistant's add_minifig.
extends SceneTree

const OMR := "res://vendor/omr/files/"

var _failures: int = 0
var library: PartLibrary
var world: BrickWorld
var builder: Builder
var store: ModelStore


func _initialize() -> void:
	library = PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	world = BrickWorld.new()
	world.library = library
	root.add_child(world)
	builder = Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	store = ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	# add_minifig keeps what it makes; not on the shelf of whoever is at
	# this machine.
	Minifig.shelf_file = "user://minifig_probe_assistant_shelf.json"
	# The builder makes its ghost when it enters the tree, a frame on.
	await process_frame

	print("")
	print("  against real figures")
	_against_real_figures()
	print("")
	print("  what each slot can be")
	_choices()
	print("")
	print("  on a stud")
	await _on_a_stud()
	print("")
	print("  saved and reopened")
	_saved_and_reopened()
	print("")
	print("  the parts list")
	_parts_list()
	print("")
	print("  the measures real sets are counted by")
	_measures()
	print("")
	print("  the design assistant")
	await _the_assistant_adds_one()
	print("")
	print("  kept for next time")
	_kept()

	if FileAccess.file_exists(Minifig.shelf_file):
		DirAccess.remove_absolute(Minifig.shelf_file)
	print("")
	if _failures == 0:
		print("minifig probe: every figure sat where real sets put its parts, stood, saved and counted")
	else:
		print("minifig probe: %d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


# -- against real figures ----------------------------------------------------


## A real figure's parts, read out of a set's file the way the app reads
## any model, in the app's axes.
func _real(set_file: String, sub_model: String) -> Array:
	var path: String = OMR + set_file + ".mpd"
	if not FileAccess.file_exists(path):
		return []
	var model: LdrModel = LdrModel.parse(FileAccess.get_file_as_string(path), set_file)
	var found: LdrModel.SubModel = model.submodels.get(LdrModel._key(sub_model))
	if found == null:
		return []
	model.main = found
	var out: Array = []
	for placement: LdrModel.Placement in model.flatten(library.parts):
		out.append({"part": placement.part_id, "at": placement.transform})
	return out


## Which joint a part is, telling left from right: arms and legs by their
## mouldings, hands by the side of the torso they are on.
func _joint(part: String, torso_relative: Transform3D) -> String:
	var role: String = Minifig.role_of(part, library.parts.get(part))
	match role:
		"arms": return "arm right" if part.begins_with(Minifig.ARM_RIGHT) else "arm left"
		"legs":
			if Minifig.is_short_legs(part):
				return "short legs"
			return "leg right" if part.begins_with("3816") else "leg left"
		"hands": return "hand right" if torso_relative.origin.x < 0 else "hand left"
	return role


## Each joint of a real figure and of ours, relative to the torso,
## compared: position to [param near] LDU, rotation entries to [param
## turned]. [param only_where] lists joints whose rotation is a pose in
## the real figure (a turned head), compared by position alone.
func _compare(label: String, ours: Minifig, real: Array, joints: Dictionary) -> void:
	if real.is_empty():
		_check("%s: the real figure is in vendor/omr" % label, false)
		return
	var real_torso: Variant = null
	for item: Dictionary in real:
		if Minifig.role_of(item["part"]) == "torso":
			real_torso = item["at"]
	var theirs: Dictionary = {}
	for item: Dictionary in real:
		var relative: Transform3D = (real_torso as Transform3D).affine_inverse() * item["at"]
		var info: PartLibrary.PartInfo = library.parts.get(item["part"])
		var joint: String = _joint(item["part"], relative)
		if joint.is_empty() and info != null and info.category.begins_with("Minifig"):
			joint = Minifig.role_of(item["part"], info)
		theirs[joint] = relative
	var torso: Transform3D = ours.torso_local()
	var mine: Dictionary = {}
	for item: Dictionary in ours.assemble(library):
		var relative: Transform3D = torso.affine_inverse() * (item["at"] as Transform3D)
		var joint: String = _joint(item["part"], relative)
		if joint.is_empty():
			joint = str(item["slot"])
		mine[joint] = relative
	for joint: String in joints:
		var limits: Array = joints[joint]
		if not theirs.has(joint) or not mine.has(joint):
			_check("%s: %s is in both figures" % [label, joint], false)
			continue
		var a: Transform3D = mine[joint]
		var b: Transform3D = theirs[joint]
		var moved: float = a.origin.distance_to(b.origin)
		# The largest difference in any entry of the rotation, which is
		# what a line of an LDraw file would show.
		var spun: float = 0.0
		for n: int in 3:
			var d: Vector3 = (a.basis[n] - b.basis[n]).abs()
			spun = maxf(spun, maxf(d.x, maxf(d.y, d.z)))
		var by_turn: bool = float(limits[1]) >= 0.0
		var ok: bool = moved <= float(limits[0]) and (not by_turn or spun <= float(limits[1]))
		_check("%s: %s %.3f LDU from the real one%s (within %s%s)" % [label, joint, moved,
			", turned %.3f" % spun if by_turn else "", limits[0],
			", %s" % limits[1] if by_turn else ""], ok)


func _against_real_figures() -> void:
	# 10218 Pet Shop: a figure modelled with the library's own torso
	# assembly numbers. Its head is turned and its left hand posed, so
	# those are compared by where they are, not how they are turned.
	var plain := Minifig.new()
	plain.parts["headwear"] = ""
	_compare("10218 Pet Shop, minifig 1", plain, _real("10218-1", "10218 - MiniFig1.ldr"), {
		"arm right": [0.01, 0.01], "arm left": [0.01, 0.01],
		"hand right": [0.05, 0.01], "hand left": [0.05, -1],
		"head": [0.01, -1], "hips": [0.01, 0.01]})
	# 10184 Town Plan: a hat, loose hips and legs. Its modeller's hands are
	# half an LDU from the library's (tools/minifig.py measure: the most
	# common way after the library's own).
	var hat := Minifig.new()
	hat.parts["headwear"] = "3624"
	_compare("10184 Town Plan, minifig 1", hat, _real("10184-1", "10184 - Minifig1.ldr"), {
		"head": [0.01, 0.01], "headwear": [0.01, 0.01],
		"arm right": [0.01, 0.01], "arm left": [0.01, 0.01],
		"hand right": [0.6, 0.02], "hand left": [0.6, 0.02],
		"hips": [0.01, 0.01], "leg right": [0.01, 0.01], "leg left": [0.01, 0.01]})
	# 10176 King's Castle: short legs, and a helmet.
	var dwarf := Minifig.new()
	dwarf.parts["legs"] = "41879a"
	dwarf.parts["headwear"] = "3844"
	_compare("10176 King's Castle, dwarf", dwarf, _real("10176-1", "10176 - dwarf.ldr"), {
		"short legs": [0.01, 0.01], "headwear": [0.01, 0.01], "head": [0.01, 0.01],
		"arm right": [0.01, 0.01]})
	# 6973 Deep Freeze Defender: airtanks at the neck lift the head by
	# their collar, which real sets do by 3 LDU for this part.
	var diver := Minifig.new()
	diver.parts["neck"] = "3838"
	diver.parts["headwear"] = ""
	_compare("6973 Deep Freeze Defender, minifig 1", diver,
		_real("6973-1", "6973 - minifig 1.ldr"), {
			"neck": [0.01, 0.01], "head": [0.01, -1]})
	_check("airtanks lift the head 3 LDU, as 29 of the 38 real figures wearing them do",
		int(MinifigData.NECK_LIFT.get("3838", 0)) == 3)

	# 6285 Black Seas Barracuda: a pirate with a cutlass. The hand's grip
	# and the blade's bar, compared in the hand that holds it.
	var real: Array = _real("6285-1", "6285 - pirate4.ldr")
	var blade: Variant = null
	var hands: Array = []
	for item: Dictionary in real:
		if item["part"] == "2530":
			blade = item["at"]
		elif item["part"] == Minifig.HAND:
			hands.append(item["at"])
	if blade == null or hands.is_empty():
		_check("6285's pirate holds a cutlass", false)
	else:
		var holder: Transform3D = hands[0]
		for hand: Transform3D in hands:
			if hand.origin.distance_to((blade as Transform3D).origin) \
					< holder.origin.distance_to((blade as Transform3D).origin):
				holder = hand
		var theirs: Transform3D = holder.affine_inverse() * (blade as Transform3D)
		var pirate := Minifig.new()
		pirate.parts["accessory"] = "2530"
		var hand_at: Transform3D = Transform3D.IDENTITY
		var held_at: Transform3D = Transform3D.IDENTITY
		for item: Dictionary in pirate.assemble(library):
			if item["slot"] == "accessory":
				held_at = item["at"]
			elif item["slot"] == "hands" and (item["at"] as Transform3D).origin.x < 0:
				hand_at = item["at"]
		var mine: Transform3D = hand_at.affine_inverse() * held_at
		var apart: float = mine.origin.distance_to(theirs.origin)
		var angle: float = rad_to_deg(mine.basis.y.angle_to(theirs.basis.y))
		_check("6285 pirate: the cutlass sits %.2f LDU from where the real hand holds it, its blade %.1f degrees off (within 1.5 and 5)"
			% [apart, angle], apart <= 1.5 and angle <= 5.0)

	# 6059 Knight's Stronghold: a soldier with a spear, held the way real
	# figures hold anything long — forearm level, shaft upright, its end
	# on the ground.
	var soldier := Minifig.new()
	soldier.parts["headwear"] = "3844"
	soldier.parts["accessory"] = "4497"
	var knight: Array = _real("6059-1", "6059 - MiniFig1.ldr")
	_compare("6059 Knight's Stronghold, minifig 1 with a spear", soldier, knight, {
		"arm right": [0.01, 0.01], "hand right": [0.3, -1], "arm left": [0.01, 0.01]})
	var spear := Transform3D.IDENTITY
	var spear_hand := Transform3D.IDENTITY
	for item: Dictionary in soldier.assemble(library):
		if item["slot"] == "accessory":
			spear = item["at"]
		elif item["slot"] == "hands" and (item["at"] as Transform3D).origin.x < 0:
			spear_hand = item["at"]
	var shaft: AABB = library.parts["4497"].bounds
	var low: float = INF
	for n: int in 8:
		var corner: Vector3 = shaft.position + Vector3(shaft.size.x if n & 1 else 0.0,
			shaft.size.y if n & 2 else 0.0, shaft.size.z if n & 4 else 0.0)
		low = minf(low, (spear * corner).y)
	var lean: float = rad_to_deg(spear.basis.y.angle_to(Vector3.UP))
	# Its end a lattice cell off the ground: see Minifig._held.
	_check("its spear stands %.0f degrees off upright with its end %.2f LDU off the ground (6059's: 15 and 0.6)"
		% [lean, low], lean < 20.0 and low >= 0.0 and low <= BrickLattice.CELL + 0.01)
	var grip_world: Vector3 = spear_hand * (Minifig.FLIP * Minifig.GRIP)
	var on_bar: Vector3 = (spear.affine_inverse() * grip_world)
	_check("and the hand closes on its shaft, %.2f LDU from the shaft's line"
		% Vector2(on_bar.x, on_bar.z).length(), Vector2(on_bar.x, on_bar.z).length() < 1.0)

	# The legs stand where the library says on the stud grid: 3816c.dat
	# "1 16 0 0 1.25 ... 3816c.dat" over "1 16 0 28 0 ... stug-1x2.dat".
	var help: String = FileAccess.get_file_as_string("res://vendor/ldraw/parts/3816c.dat")
	var leg_line: String = ""
	var stud_line: String = ""
	for raw: String in help.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("0 !HELP 1 16") and line.ends_with("3816c.dat"):
			leg_line = line
		elif line.begins_with("0 !HELP 1 16") and line.contains("stug"):
			stud_line = line
	if leg_line.is_empty() or stud_line.is_empty():
		_check("3816c.dat says where the leg goes over the studs", false)
	else:
		var leg: PackedStringArray = leg_line.split(" ", false)
		var studs: PackedStringArray = stud_line.split(" ", false)
		var said := Vector3(float(leg[4]) - float(studs[4]), float(leg[5]) - float(studs[5]),
			float(leg[6]) - float(studs[6]))
		var ours := Minifig.new()
		var leg_at: Transform3D = Transform3D.IDENTITY
		for item: Dictionary in ours.assemble(library):
			if item["part"] == "3816c":
				leg_at = item["at"]
		# In LDraw's axes, relative to the studs the figure stands on.
		var flip := Vector3(1, -1, -1)
		var mine: Vector3 = leg_at.origin * flip
		_check("the legs stand where 3816c.dat says over the studs, %s against its %s"
			% [mine, said], mine.is_equal_approx(said))


# -- the slots ----------------------------------------------------------------


func _choices() -> void:
	var least: Dictionary = {"headwear": 300, "head": 300, "neck": 50, "torso": 500,
		"hips": 50, "legs": 60, "accessory": 300}
	for slot: String in least:
		var found: Array[PartLibrary.PartInfo] = Minifig.choices(library, slot)
		var real: bool = found.all(func(info: PartLibrary.PartInfo) -> bool:
			return (not info.is_redirect() and not info.kind.contains("Shortcut")
				and not info.name.begins_with("~")))
		_check("%s: %d real parts to choose from, none a redirect or an assembly"
			% [slot, found.size()], found.size() >= int(least[slot]) and real)
	var heads: Array[PartLibrary.PartInfo] = Minifig.choices(library, "head")
	var printed: int = heads.filter(func(info: PartLibrary.PartInfo) -> bool:
		return info.id.contains("p")).size()
	_check("printed heads are there too (%d)" % printed, printed > 200)
	var shorts: int = Minifig.choices(library, "legs").filter(
		func(info: PartLibrary.PartInfo) -> bool:
			return Minifig.is_short_legs(info.id)).size()
	_check("and short legs (%d)" % shorts, shorts >= 5)
	var lefts: bool = Minifig.choices(library, "legs").all(
		func(info: PartLibrary.PartInfo) -> bool:
			if not info.id.begins_with("3816"):
				return true
			var figure := Minifig.new()
			figure.parts["legs"] = info.id
			return library.parts.has(figure.left_leg()))
	_check("every printed right leg has its left one", lefts)
	var colours: PartLibrary.PartInfo = Minifig.colours_of(library, "3626cp01")
	_check("a printed head's colours are its moulding's (%s, %d known)"
		% [colours.id if colours != null else "none",
			colours.colors.size() if colours != null else 0],
		colours != null and colours.id == "3626c" and colours.colors.has(14))

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	var whole: int = 0
	var made: int = 25
	for n: int in made:
		var figure: Minifig = Minifig.surprise(library, rng)
		var fine: bool = true
		for item: Dictionary in figure.assemble(library):
			var info: PartLibrary.PartInfo = library.parts.get(item["part"])
			var good: bool = info != null and not info.is_redirect() \
				and library.colors.has(int(item["color"]))
			if not good:
				print("    surprise %d: %s %s in %d" % [n, item["slot"], item["part"],
					int(item["color"])])
			fine = fine and good
		if fine and figure.assemble(library).size() >= 7:
			whole += 1
	_check("%d of %d surprise figures are real parts in real colours" % [whole, made],
		whole == made)


# -- standing in a model ------------------------------------------------------


func _relative(ids: PackedInt64Array) -> Dictionary:
	var torso := Transform3D.IDENTITY
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if Minifig.role_of(brick.part_id) == "torso":
			torso = brick.transform
	var out: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var key: String = "%s@%s" % [brick.part_id,
			(torso.affine_inverse() * brick.transform).origin.snapped(Vector3.ONE * 0.01)]
		out[key] = torso.affine_inverse() * brick.transform
	return out


func _same_shape(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: String in a:
		if not b.has(key):
			return false
		var x: Transform3D = a[key]
		var y: Transform3D = b[key]
		if x.origin.distance_to(y.origin) > 0.001:
			return false
		for n: int in 3:
			if (x.basis[n] - y.basis[n]).length() > 0.001:
				return false
	return true


var _saruman := Minifig.new()


func _on_a_stud() -> void:
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	# A 1 x 2 plate on the stud grid, which in this app is at odd tens.
	var plate := Transform3D(Basis.IDENTITY, Vector3(40, 8, 10))
	var plate_id: int = world.add_brick("3023", 15, plate)
	builder.register(plate_id, "3023", plate)

	_saruman.name = "Saruman"
	_saruman.parts["headwear"] = "3901"
	_saruman.parts["accessory"] = "2530"
	_saruman.colours["torso"] = 15
	_saruman.colours["arms"] = 15
	builder.hold_figure(_saruman.assemble(library), _saruman.name)
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	var first: int = builder.place()
	_check("pointed at a 1 x 2 plate, the held figure goes down", first != 0)
	var ids: PackedInt64Array = builder.figure_of(first)
	_check("all %d parts went in, as one figure called Saruman"
		% ids.size(), ids.size() == _saruman.assemble(library).size()
		and world.get_brick(first).group == "Saruman")

	# Its feet on the two studs: each leg's hole, where 3816c.dat puts it
	# (x 10, 28 down, 1.25 forward, in LDraw's axes), on a stud's centre.
	var on_studs: int = 0
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if not (brick.part_id == "3816c" or brick.part_id == "3817c"):
			continue
		var side: float = -10.0 if brick.part_id == "3816c" else 10.0
		var hole: Vector3 = brick.transform * Vector3(side, -28.0, 1.25)
		var stud: Vector3 = plate * Vector3(side, 0.0, 0.0)
		if hole.distance_to(stud) < 0.01:
			on_studs += 1
	_check("each leg's hole is on a stud of the plate (%d of 2)" % on_studs, on_studs == 2)
	var stability := Stability.new()
	stability.library = library
	stability.lattice = builder.lattice
	var report: Stability.Report = stability.check(world)
	_check("it stands: %s" % report.summary(), report.is_stable())
	var placed: Dictionary = _relative(ids)

	builder.undo()
	_check("one undo takes the whole figure off (%d bricks left)" % world.brick_count(),
		world.brick_count() == 1)
	builder.redo()
	ids = builder.figure_of(world.bricks()[world.bricks().size() - 1].id)
	_check("and redo puts it back whole, %d parts" % ids.size(),
		ids.size() == placed.size() and _same_shape(_relative(ids), placed))

	# Picked out by pointing at its hand, it is all picked out.
	builder.drop_figure()
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	builder.toggle_hovered()
	_check("shift-clicking any part of it picks out the whole figure (%d)"
		% builder.selection.size(), builder.selection.size() == ids.size())
	var moved: int = builder.move_selection(Vector3i(BrickLattice.CELLS_PER_STUD * 2, 0, 0))
	_check("arrows move it whole, keeping its shape",
		moved == ids.size() and _same_shape(_relative(ids), placed))
	builder.move_selection(Vector3i(-BrickLattice.CELLS_PER_STUD * 2, 0, 0))
	builder.clear_selection()

	# Q and E turn the model; a figure has to come round in one piece.
	var before: Array = []
	for brick_id: int in ids:
		before.append(world.get_brick(brick_id).transform)
	world.rotate_model(1)
	_check("turning the model a quarter keeps the figure's shape",
		_same_shape(_relative(ids), placed))
	for _n: int in 3:
		world.rotate_model(1)
	var back: bool = true
	for n: int in ids.size():
		var now: Transform3D = world.get_brick(ids[n]).transform
		back = back and now.origin.distance_to((before[n] as Transform3D).origin) < 0.001
	_check("and four quarters put every part back where it was", back)
	builder.lattice.clear()
	for brick: BrickWorld.Brick in world.bricks():
		builder.register(brick.id, brick.part_id, brick.transform)

	# X lifts it whole, facing as it faced; the next click stands it on
	# another plate.
	var other := Transform3D(Basis.IDENTITY, Vector3(-60, 8, 50))
	var other_id: int = world.add_brick("3023", 1, other)
	builder.register(other_id, "3023", other)
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	builder.rotate_held(0)
	var lifted: bool = builder.lift_hovered()
	_check("X lifts the whole figure off (%d bricks left)" % world.brick_count(),
		lifted and builder.is_holding_figure() and world.brick_count() == 2)
	builder.update_preview(Vector3(-60, 400, 50), Vector3.DOWN)
	var again: int = builder.place()
	var moved_ids: PackedInt64Array = builder.figure_of(again)
	_check("and puts it down on the other plate, the same figure, still Saruman",
		again != 0 and _same_shape(_relative(moved_ids), placed)
		and world.get_brick(again).group == "Saruman")
	builder.drop_figure()
	builder.update_preview(Vector3(-60, 400, 50), Vector3.DOWN)
	builder.lift_hovered()
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	builder.place()
	builder.drop_figure()

	# A second figure of the same name is a second figure.
	var guard := Minifig.new()
	guard.name = "Saruman"
	builder.hold_figure(guard.assemble(library), guard.name)
	builder.update_preview(Vector3(-60, 400, 50), Vector3.DOWN)
	var second: int = builder.place()
	builder.drop_figure()
	_check("a second figure with the same name is kept apart, as %s"
		% (world.get_brick(second).group if second != 0 else "nothing"),
		second != 0 and world.get_brick(second).group == "Saruman 2")
	await process_frame


func _snapshot() -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		out.append([brick.group, brick.part_id, brick.color_code, brick.transform])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return "%s %s %s" % [a[0], a[1], (a[3] as Transform3D).origin] \
			< "%s %s %s" % [b[0], b[1], (b[3] as Transform3D).origin])
	return out


func _saved_and_reopened() -> void:
	var text: String = store.to_text("Isengard")
	_check("saved as a document with Saruman as a sub-model of his own",
		text.contains("0 FILE saruman.ldr") and text.contains("0 FILE saruman_2.ldr"))
	# Written standing at the sub-model's origin, the way a real set's
	# file keeps a figure: torso 72 above the studs and 1.25 behind them.
	var lines: PackedStringArray = text.split("\n")
	var torso_line: String = ""
	var in_saruman: bool = false
	for line: String in lines:
		if line.begins_with("0 FILE"):
			in_saruman = line == "0 FILE saruman.ldr"
		if in_saruman and line.ends_with(" 973.dat"):
			torso_line = line
	_check("inside it the torso stands at its origin's 0 -72 1.25: %s" % torso_line,
		torso_line == "1 15 0 -72 1.25 1 0 0 0 1 0 0 0 1 973.dat")
	var placed_by: bool = false
	for line: String in lines:
		if line.ends_with(" saruman.ldr") and line.begins_with("1 16 40 -8 -10 "):
			placed_by = true
	_check("and the model places it on its plate, at 40 -8 -10", placed_by)

	var before: Array = _snapshot()
	var opened: Dictionary = store.open_text(text, "isengard.ldr")
	var after: Array = _snapshot()
	var same: bool = before.size() == after.size()
	var worst: float = 0.0
	for n: int in mini(before.size(), after.size()):
		same = same and before[n][0] == after[n][0] and before[n][1] == after[n][1] \
			and before[n][2] == after[n][2]
		var a: Transform3D = before[n][3]
		var b: Transform3D = after[n][3]
		worst = maxf(worst, a.origin.distance_to(b.origin))
		for k: int in 3:
			worst = maxf(worst, (a.basis[k] - b.basis[k]).length())
	_check("reopened, %d parts in the same groups, parts and colours, %.5f LDU at worst"
		% [int(opened["placed"]), worst], same and worst < 0.001)
	var resaved: String = store.to_text("Isengard")
	if resaved != text:
		var was: PackedStringArray = text.split("\n")
		var now: PackedStringArray = resaved.split("\n")
		for n: int in mini(was.size(), now.size()):
			if was[n] != now[n]:
				print("    first difference, line %d:\n      %s\n      %s" % [n, was[n], now[n]])
				break
	_check("and saved again, the file is identical", resaved == text)


func _parts_list() -> void:
	var stock: Inventory = Inventory.of(world, library)
	var by_part: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		by_part[lot.part_id] = int(by_part.get(lot.part_id, 0)) + lot.count
	_check("every part of both figures is on the list as its own piece (%d pieces)"
		% stock.pieces, stock.pieces == world.brick_count())
	_check("two hands each: %d of 3820" % int(by_part.get("3820", 0)),
		int(by_part.get("3820", 0)) == 4)
	_check("an arm of each side each: %d of 3818, %d of 3819"
		% [int(by_part.get("3818", 0)), int(by_part.get("3819", 0))],
		int(by_part.get("3818", 0)) == 2 and int(by_part.get("3819", 0)) == 2)
	_check("the torsos, heads, hips and legs are there: 973 %d, 3626cp01 %d, 3815b %d, 3816c %d, 3817c %d"
		% [int(by_part.get("973", 0)), int(by_part.get("3626cp01", 0)),
			int(by_part.get("3815b", 0)), int(by_part.get("3816c", 0)),
			int(by_part.get("3817c", 0))],
		int(by_part.get("973", 0)) == 2 and int(by_part.get("3815b", 0)) == 2
		and int(by_part.get("3816c", 0)) == 2 and int(by_part.get("3817c", 0)) == 2)
	var hand_element: String = ""
	for lot: Inventory.Lot in stock.lots:
		if lot.part_id == "3820" and lot.color_code == 14:
			hand_element = lot.element
	_check("a yellow hand is an element you can order: %s" % hand_element,
		not hand_element.is_empty()
		and hand_element == library.element_for("3820", 14))


func _measures() -> void:
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	var figure: Array[Dictionary] = _saruman.assemble(library)
	var sized: bool = true
	var styled: bool = true
	for item: Dictionary in figure:
		sized = sized and assistant._piece_size(str(item["part"])) < 0.0
		styled = styled and Style.kinds_of(str(item["part"])).is_empty()
	_check("no part of a figure counts as a building piece's size", sized)
	_check("nor in the style measures", styled)

	# A wall of three hundred 1 x 2 bricks, with and without a dozen
	# figures standing on it: the same advice either way.
	var wall := Assistant.Model.new()
	for n: int in 300:
		var brick := Assistant.Placement.new()
		brick.part = "3004"
		brick.color = 71
		brick.x = (n % 30) * 2
		brick.y = (n / 30) * 3
		wall.placements.append(brick)
	var alone: String = assistant._variety(wall)
	var peopled := Assistant.Model.new()
	peopled.placements = wall.placements.duplicate()
	for n: int in 12:
		for item: Dictionary in figure:
			if str(item["slot"]) == "accessory":
				continue
			var part := Assistant.Placement.new()
			part.part = str(item["part"])
			part.color = int(item["color"])
			peopled.placements.append(part)
	var with_them: String = assistant._variety(peopled)
	_check("a wall reads as thin as it is with a dozen figures on it (%d parts more, the same advice)"
		% (peopled.placements.size() - wall.placements.size()),
		not alone.is_empty() and alone == with_them)
	var held: PartLibrary.PartInfo = library.parts.get("2530")
	_check("what a figure holds is a set part, as Rebrickable counts it",
		not Minifig.is_body_part(held) and Minifig.is_body_part(library.parts.get("973")))
	assistant.queue_free()


func _the_assistant_adds_one() -> void:
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	var floor_at := Transform3D(Basis.IDENTITY, Vector3(80, 24, 40))
	var floor_id: int = world.add_brick("3001", 72, floor_at)
	builder.register(floor_id, "3001", floor_at)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	var names: Array = assistant.tool_catalogue().map(func(tool: Dictionary) -> String:
		return str(tool["name"]))
	_check("add_minifig is in the design's tools, and so on MCP", names.has("add_minifig"))

	# A 2 x 4 brick from x 3 to 5 (studs), z 1 to 2; Saruman on its far end.
	var said: Variant = await assistant.use_tool("add_minifig", {
		"name": "Saruman", "x": 3, "z": 1, "facing": "+z",
		"headwear": "hair long", "head": "beard", "torso": "robe",
		"accessory": "staff",
		"colors": {"headwear": 15, "torso": 15, "arms": 15, "legs": 15, "hips": 15}})
	var text: String = str(said)
	var stood: Array = world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.group == "Saruman")
	print("    %s" % text.substr(0, 400))
	_check("add_minifig stands him in the model: %d parts called Saruman" % stood.size(),
		text.begins_with("Placed Saruman") and stood.size() >= 10)
	var lowest: float = INF
	for brick: BrickWorld.Brick in stood:
		if brick.part_id.begins_with("3816") or brick.part_id.begins_with("3817"):
			lowest = minf(lowest, brick.transform.origin.y - 28.0)
	_check("on top of the brick he was put on, feet at %.1f LDU" % lowest,
		is_equal_approx(lowest, 24.0))
	var dressed: bool = false
	for brick: BrickWorld.Brick in stood:
		if brick.part_id == "973" or brick.part_id.begins_with("973p"):
			dressed = brick.color_code == 15
	_check("in the white he was asked for", dressed)
	_check("and counted as the design's own, so a new design replaces him",
		assistant.built_count() == stood.size())

	# Under a roof: a floor at x -6 to -2, z 1 to 2, and a plate seven
	# bricks over it. Given the floor's height he stands on the floor;
	# the highest thing there is the roof.
	var room_floor := Transform3D(Basis.IDENTITY, Vector3(-80, 24, 40))
	var room_floor_id: int = world.add_brick("3001", 19, room_floor)
	builder.register(room_floor_id, "3001", room_floor)
	var roof := Transform3D(Basis.IDENTITY, Vector3(-80, 24 + 7 * 24, 40))
	var roof_id: int = world.add_brick("3031", 4, roof)
	builder.register(roof_id, "3031", roof)
	var inside: Variant = await assistant.use_tool("add_minifig", {
		"name": "Radagast", "x": -5, "z": 1, "y": 3, "colors": {"torso": 70}})
	var radagast: Array = world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return brick.group == "Radagast")
	var radagast_feet: float = INF
	for brick: BrickWorld.Brick in radagast:
		if brick.part_id == "3816c":
			radagast_feet = brick.transform.origin.y - 28.0
	_check("given a floor's height, he stands on it under the roof, feet at %.1f: %s"
		% [radagast_feet, str(inside).substr(0, 60)],
		radagast.size() >= 10 and is_equal_approx(radagast_feet, 24.0))

	var floating: Variant = await assistant.use_tool("add_minifig", {
		"name": "Gandalf", "x": 10, "z": 10, "y": 30})
	_check("asked to stand in the air, it refuses: %s" % str(floating).substr(0, 90),
		str(floating).begins_with("Not placed"))
	var crowded: Variant = await assistant.use_tool("add_minifig", {
		"name": "Wormtongue", "x": 3, "z": 1})
	_check("and where somebody already stands: %s" % str(crowded).substr(0, 90),
		str(crowded).begins_with("Not placed"))
	assistant.queue_free()
	await process_frame


func _kept() -> void:
	var path: String = "user://minifig_probe_shelf.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var figure := Minifig.new()
	figure.name = "Radagast"
	figure.colours["torso"] = 70
	figure.parts["headwear"] = "3624"
	Minifig.keep(figure, path)
	var other := Minifig.new()
	other.name = "Elrond"
	Minifig.keep(other, path)
	var kept: Array[Minifig] = Minifig.shelf(path)
	_check("kept figures come back, newest first: %s"
		% ", ".join(kept.map(func(f: Minifig) -> String: return f.name)),
		kept.size() == 2 and kept[0].name == "Elrond" and kept[1].name == "Radagast"
		and kept[1].parts["headwear"] == "3624" and int(kept[1].colours["torso"]) == 70)
	Minifig.forget("Elrond", path)
	_check("and one forgotten is gone", Minifig.shelf(path).size() == 1)
	DirAccess.remove_absolute(path)
