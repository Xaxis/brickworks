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
##
## And every minifigure part the catalogue has: each offered in some
## slot, each family of each slot put together without anything
## standing in the floor, and the parts the standard joints do not fit —
## a cape, a visor, a shield in the left hand, a battle droid, a hook, a
## wooden leg — where real sets and the library's own assemblies put
## them.
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
	print("  against the library's own assemblies")
	_against_the_library()
	print("")
	print("  cloth as figures wear it")
	_cloth()
	print("")
	print("  on footwear")
	_footwear()
	print("")
	print("  what each slot can be")
	_choices()
	print("")
	print("  every minifigure part")
	_every_part()
	print("")
	print("  every family put together")
	_every_family()
	print("")
	print("  one piece, as the design checker reads it")
	_one_piece()
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
	print("  a figure of the new slots, stood up, lifted and saved")
	await _new_slots_stand()
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


## Something a real figure holds in its left hand, against ours holding
## it in the left hand: where it sits in the hand, and which way.
func _held_left(label: String, set_file: String, model: String, part: String) -> void:
	var real: Array = _real(set_file, model)
	var held: Variant = null
	var hands: Array = []
	var torso := Transform3D.IDENTITY
	for item: Dictionary in real:
		if item["part"] == part:
			held = item["at"]
		elif item["part"] == Minifig.HAND:
			hands.append(item["at"])
		elif Minifig.role_of(item["part"]) == "torso":
			torso = item["at"]
	if held == null or hands.is_empty():
		_check("%s is in the real figure" % label, false)
		return
	var holder: Transform3D = hands[0]
	for hand: Transform3D in hands:
		if hand.origin.distance_to((held as Transform3D).origin) \
				< holder.origin.distance_to((held as Transform3D).origin):
			holder = hand
	var left: bool = (torso.affine_inverse() * holder).origin.x > 0
	var theirs: Transform3D = holder.affine_inverse() * (held as Transform3D)
	var figure := Minifig.new()
	figure.parts["accessory_left"] = part
	var hand_at := Transform3D.IDENTITY
	var held_at := Transform3D.IDENTITY
	for item: Dictionary in figure.assemble(library):
		if item["slot"] == "accessory_left":
			held_at = item["at"]
		elif item["slot"] == "hands" and (item["at"] as Transform3D).origin.x > 0:
			hand_at = item["at"]
	var mine: Transform3D = hand_at.affine_inverse() * held_at
	# Where the hand closes on it, in its own frame, ours and the real
	# figure's: on the same bar (off its line by less than 1 LDU) and
	# along it within 3, which is how well the grip rule does for the
	# right hand too (tools/minifig.py grips).
	var grip: Vector3 = Minifig.FLIP * Minifig.GRIP
	var ours_on_it: Vector3 = mine.affine_inverse() * grip
	var real_on_it: Vector3 = theirs.affine_inverse() * grip
	var axis: Vector3 = (theirs.affine_inverse().basis * (Minifig.FLIP.basis * Minifig.GRIP_AXIS)).normalized()
	var along: float = (ours_on_it - real_on_it).dot(axis)
	var off: float = ((ours_on_it - real_on_it) - axis * along).length()
	var angle: float = rad_to_deg(mine.basis.y.angle_to(theirs.basis.y))
	_check("%s in the left hand: held on the real one's bar (%.2f LDU off it), %.2f along it, %.1f degrees off (within 1, 3 and 5)"
		% [label, off, absf(along), angle], left and off <= 1.0 and absf(along) <= 3.0
		and angle <= 5.0)


## A file of the LDraw library itself, read the way the app reads any
## model, its parts in the app's axes.
func _library_file(name: String) -> Array:
	var path: String = "res://vendor/ldraw/parts/%s.dat" % name
	if not FileAccess.file_exists(path):
		path = "res://vendor/ldraw/unofficial/parts/%s.dat" % name
	if not FileAccess.file_exists(path):
		return []
	var model: LdrModel = LdrModel.parse(FileAccess.get_file_as_string(path), name)
	var out: Array = []
	for placement: LdrModel.Placement in model.flatten(library.parts):
		out.append({"part": placement.part_id, "at": placement.transform})
	return out


## Each part of ours against the same part in a library file, relative to
## a part both have: [worst distance, worst rotation entry, missing].
func _against_file(ours: Array[Dictionary], theirs: Array, anchor: String) -> Array:
	var mine_anchor: Variant = null
	var their_anchor: Variant = null
	for item: Dictionary in ours:
		if item["part"] == anchor:
			mine_anchor = item["at"]
	for item: Dictionary in theirs:
		if item["part"] == anchor:
			their_anchor = item["at"]
	if mine_anchor == null or their_anchor == null:
		return [INF, INF, ["%s itself" % anchor]]
	var worst: float = 0.0
	var spun: float = 0.0
	var missing: Array = []
	for item: Dictionary in theirs:
		var rel: Transform3D = (their_anchor as Transform3D).affine_inverse() * (item["at"] as Transform3D)
		var best: float = INF
		var best_spin: float = INF
		for mine: Dictionary in ours:
			if mine["part"] != item["part"]:
				continue
			var here: Transform3D = (mine_anchor as Transform3D).affine_inverse() * (mine["at"] as Transform3D)
			var d: float = here.origin.distance_to(rel.origin)
			if d < best:
				best = d
				best_spin = 0.0
				for n: int in 3:
					var diff: Vector3 = (here.basis[n] - rel.basis[n]).abs()
					best_spin = maxf(best_spin, maxf(diff.x, maxf(diff.y, diff.z)))
		if best == INF:
			missing.append(item["part"])
			continue
		worst = maxf(worst, best)
		spun = maxf(spun, best_spin)
	return [worst, spun, missing]


func _against_the_library() -> void:
	# The battle droid: choosing its torso brings its head, arms and legs,
	# and no hips or hands, all where 30375cs0.dat puts them.
	var droid := Minifig.new()
	droid.choose(library, "torso", "30375")
	_check("choosing a battle droid's torso brings its own parts: head %s, arms %s, legs %s, hips %s, hands %s"
		% [droid.part("head"), droid.part("arms"), droid.part("legs"),
			"none" if droid.part("hips").is_empty() else droid.part("hips"),
			"none" if droid.part("hands").is_empty() else droid.part("hands")],
		droid.part("head") == "30378" and droid.part("arms") == "30377"
		and droid.part("legs") == "30376" and droid.part("hips").is_empty()
		and droid.part("hands").is_empty())
	var against: Array = _against_file(droid.assemble(library), _library_file("30375cs0"),
		"30375")
	_check("and stands as 30375cs0.dat does: every part within %.3f LDU, turned %.3f, none missing %s"
		% [against[0], against[1], against[2]], float(against[0]) <= 0.01
		and float(against[1]) <= 0.01 and (against[2] as Array).is_empty())
	droid.choose(library, "torso", "973")
	_check("and the plain torso again gives the plain parts back",
		droid.part("head") == "3626cp01" and droid.part("legs") == Minifig.PLAIN_LEGS
		and droid.part("hips") == Minifig.PLAIN_HIPS and droid.part("hands") == Minifig.HAND)

	# A hook for the left hand, where 84638.dat (the torso with arms, a
	# right hand and a left hook) puts it; the right hand stays a hand.
	var pirate := Minifig.new()
	pirate.choose(library, "hands", "2531")
	against = _against_file(pirate.assemble(library), _library_file("84638"), "973")
	_check("a hook goes on the left as 84638.dat has it: within %.3f LDU, turned %.3f, none missing %s"
		% [against[0], against[1], against[2]], float(against[0]) <= 0.01
		and float(against[1]) <= 0.01 and (against[2] as Array).is_empty())
	var right_hand: int = 0
	for item: Dictionary in pirate.assemble(library):
		if item["part"] == Minifig.HAND and (item["at"] as Transform3D).origin.x < 0 \
				and int(item["color"]) == 14:
			right_hand += 1
	_check("and the right is still a yellow hand to hold things with", right_hand == 1)

	# A wooden leg for the right, the plain left leg with it: 84637b.dat.
	var peg := Minifig.new()
	peg.choose(library, "legs", "2532")
	against = _against_file(peg.assemble(library), _library_file("84637b"), "3815b")
	_check("a wooden leg goes on the right with the plain left leg, as 84637b.dat: within %.3f LDU, none missing %s"
		% [against[0], against[2]], float(against[0]) <= 0.01 and (against[2] as Array).is_empty())

	# A baby's arms, which hang closer in than a grown figure's: 15998.dat.
	var baby := Minifig.new()
	baby.choose(library, "torso", "15526")
	against = _against_file(baby.assemble(library), _library_file("15998"), "15526")
	_check("a baby's body takes its arms and hands where 15998.dat does: within %.3f LDU, turned %.3f, none missing %s"
		% [against[0], against[1], against[2]], float(against[0]) <= 0.01
		and float(against[1]) <= 0.01 and (against[2] as Array).is_empty())
	_check("and stands on its own feet, no hips or legs under it",
		baby.part("hips").is_empty() and baby.part("legs").is_empty())

	# Medium legs with their hips: 37364.dat is the library's.
	var medium := Minifig.new()
	medium.choose(library, "legs", "37365")
	against = _against_file(medium.assemble(library), _library_file("37364"), "3815b")
	_check("medium legs pair and hang from the hips as 37364.dat: within %.3f LDU, none missing %s"
		% [against[0], against[2]], float(against[0]) <= 0.01 and (against[2] as Array).is_empty())

	# The other way round: a part the library only ever attaches to
	# another brings it. A battle droid's head has no socket for a neck
	# post — it clips onto its own torso's bar — so it brings the droid.
	var droid_head := Minifig.new()
	droid_head.choose(library, "head", "30378")
	against = _against_file(droid_head.assemble(library), _library_file("30375cs0"), "30375")
	_check("a battle droid's head brings its body, torso %s, and stands as 30375cs0.dat: within %.3f LDU, none missing %s"
		% [droid_head.part("torso"), against[0], against[2]],
		droid_head.part("torso") == "30375" and float(against[0]) <= 0.01
		and (against[2] as Array).is_empty())
	# A head drawn as a brick is, hollow underneath round a tube for the
	# neck post — a Minion's, a pencil top — rests on the shoulders by
	# its rim; seated by the tube it sank over the torso.
	var sunk: Array[String] = []
	for head: String in ["67649", "67650", "67902", "29030"]:
		var figure := Minifig.new()
		figure.choose(library, "head", head)
		var top: float = NAN
		var bottom: float = NAN
		for item: Dictionary in figure.assemble(library):
			if item["slot"] == "torso":
				top = (item["at"] as Transform3D).origin.y
			elif item["slot"] == "head":
				bottom = ((item["at"] as Transform3D) * library.parts[head].bounds).position.y
		sunk.append("%s %.1f" % [head, bottom - top])
	_check("Minion heads and the pencil top rest on the shoulders by their rim, LDU over the torso's top: %s"
		% ", ".join(sunk), sunk.all(func(line: String) -> bool:
			return absf(float(line.split(" ")[1])) < 0.05))
	# Printed legs bring the hips printed to match, in the colour the
	# library's own hips-and-legs assembly gives them.
	var belted := Minifig.new()
	belted.choose(library, "legs", "3816cpx0")
	against = _against_file(belted.assemble(library), _library_file("73200bpx0"), "3815bpx0")
	_check("printed legs 3816cpx0 bring their hips, %s, as 73200bpx0.dat: within %.3f LDU, none missing %s"
		% [belted.part("hips"), against[0], against[2]], belted.part("hips") == "3815bpx0"
		and float(against[0]) <= 0.01 and (against[2] as Array).is_empty())
	var ragged := Minifig.new()
	ragged.choose(library, "legs", "3816cp30")
	_check("and 3816cp30's rags their reddish brown hips, as 73200bp30.dat: %s in %d"
		% [ragged.part("hips"), int(ragged.colours["hips"])],
		ragged.part("hips") == Minifig.PLAIN_HIPS and int(ragged.colours["hips"]) == 70)
	belted.choose(library, "legs", Minifig.PLAIN_LEGS)
	_check("and the plain legs again the plain hips (%s)" % belted.part("hips"),
		belted.part("hips") == Minifig.PLAIN_HIPS)
	# Springs go into the hips and legs 43743-f1 puts them in; alone they
	# stood the figure on two springs.
	var bouncy := Minifig.new()
	bouncy.choose(library, "legs", "43741-f1")
	against = _against_file(bouncy.assemble(library), _library_file("43743-f1"), "43221")
	_check("springs 43741-f1 go into hips %s and the legs under them, as 43743-f1.dat: within %.3f LDU, none missing %s"
		% [bouncy.part("hips"), against[0], against[2]], bouncy.part("hips") == "43221"
		and float(against[0]) <= 0.01 and (against[2] as Array).is_empty())
	var joined := Minifig.new()
	joined.choose(library, "legs", "43220")
	var once: int = joined.assemble(library).filter(func(item: Dictionary) -> bool:
		return item["part"] == "43220").size()
	against = _against_file(joined.assemble(library), _library_file("43743-f1"), "43221")
	_check("and legs 43220 are one part (%d), with their springs and hips: within %.3f LDU, none missing %s"
		% [once, against[0], against[2]], once == 1 and float(against[0]) <= 0.01
		and (against[2] as Array).is_empty())
	# The prosthetic hand goes on the stump, where 6828.dat's HELP line
	# says; on a plain arm it pointed back up it.
	var helper := Minifig.new()
	helper.choose(library, "hands", "5059")
	var stump: Variant = null
	var prosthetic: Variant = null
	for item: Dictionary in helper.assemble(library):
		if item["part"] == "6828":
			stump = item["at"]
		elif item["part"] == "5059":
			prosthetic = item["at"]
	var said: Variant = _help_line("6828", "5059")
	var off: float = INF
	if stump != null and prosthetic != null and said != null:
		var ours: Transform3D = (stump as Transform3D).affine_inverse() * (prosthetic as Transform3D)
		off = ours.origin.distance_to((said as Transform3D).origin)
		for n: int in 3:
			off = maxf(off, (ours.basis[n] - (said as Transform3D).basis[n]).length())
	_check("a prosthetic hand brings the stump arm (%s) and goes on it as 6828.dat says: %.3f off"
		% [helper.part("arms"), off], helper.part("arms") == "6828" and off <= 0.01)
	helper.choose(library, "hands", Minifig.HAND)
	_check("and the plain hand again the plain arm (%s)" % helper.part("arms"),
		helper.part("arms") == Minifig.ARM_RIGHT)


## Where a library file's HELP line puts a part, in the app's axes as
## LdrModel reads a placement: the library's word for how a part goes on
## another it does not include.
func _help_line(name: String, part: String) -> Variant:
	var path: String = "res://vendor/ldraw/parts/%s.dat" % name
	if not FileAccess.file_exists(path):
		path = "res://vendor/ldraw/unofficial/parts/%s.dat" % name
	if not FileAccess.file_exists(path):
		return null
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var words: PackedStringArray = line.strip_edges().split(" ", false)
		if words.size() == 17 and words[1] == "!HELP" and words[2] == "1" \
				and words[16].to_lower() == part + ".dat":
			var v: Array = []
			for n: int in range(4, 16):
				v.append(float(words[n]))
			var at := Transform3D(Basis(Vector3(v[3], v[6], v[9]), Vector3(v[4], v[7], v[10]),
				Vector3(v[5], v[8], v[11])), Vector3(v[0], v[1], v[2]))
			return Minifig.FLIP * at * Minifig.FLIP
	return null


## LDraw draws cloth flat, as it is sold, and again "(Formed)", as it is
## worn; every cloth cape on a figure in vendor/omr is a worn drawing
## (522 in 7150, 9469 and 10212; 50231c02 in 9471; 99464c01 in 9470).
## The Cape slot opens on one; a flat cloth on a figure is worn as its
## worn drawing; one with none hangs straight down against the back,
## never held out at an angle; and the worn drawing is the element its
## cloth is on the parts list.
func _cloth() -> void:
	var capes: Array[PartLibrary.PartInfo] = Minifig.choices(library, "cape")
	var last_worn: int = -1
	var first_flat: int = capes.size()
	var worn_drawings: int = 0
	for n: int in capes.size():
		if not _formed_of(capes[n]).is_empty() \
				and _fits_a_figure(capes[n]):
			last_worn = n
			worn_drawings += 1
		if _flat(capes[n]):
			first_flat = mini(first_flat, n)
	_check("the Cape slot opens on the cloth cape as figures wear it: %s %s, its %d worn drawings first (to %d) and cloth drawn flat last (from %d)"
		% [capes[0].id, capes[0].name, worn_drawings, last_worn, first_flat],
		capes[0].id == "50231c01" and last_worn + 1 == worn_drawings
		and worn_drawings > 10 and first_flat > last_worn
		and capes.slice(first_flat).all(func(info: PartLibrary.PartInfo) -> bool:
			return _flat(info)))
	# Every flat cloth in the slots that take cloth, on a plain figure.
	var worn: int = 0
	var hung: int = 0
	var wrong: Array[String] = []
	for slot: String in ["cape", "hipwear"]:
		for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
			if not _flat(info):
				continue
			var figure := Minifig.new()
			figure.choose(library, slot, info.id)
			var placed: Dictionary = {}
			for item: Dictionary in figure.assemble(library):
				if item["slot"] == slot:
					placed = item
			var twin: String = info.id + "c01"
			if library.parts.has(twin) and library.parts[twin].name.contains("(Formed") \
					and _fits_a_figure(library.parts[twin]):
				worn += 1
				# As real figures wear it: the worn drawing, square on the
				# figure.
				if placed.get("part") != twin \
						or not (placed["at"] as Transform3D).basis.is_equal_approx(Basis.IDENTITY):
					wrong.append("%s wears %s" % [info.id, placed.get("part")])
				continue
			hung += 1
			# Straight down: a quarter turn about X and nothing else, so the
			# sheet stands upright behind the figure; its hem above the ground.
			var at: Transform3D = placed["at"]
			var upright: bool = absf((at.basis * Vector3.UP).y) < 0.01 \
				and at.basis.x.is_equal_approx(Vector3.RIGHT)
			var low: float = Minifig._lowest(Minifig.FLIP * at * Minifig.FLIP, info.bounds)
			var behind: float = INF
			for n: int in 8:
				var corner: Vector3 = info.bounds.position + info.bounds.size * Vector3(
					n & 1, (n >> 1) & 1, (n >> 2) & 1)
				behind = minf(behind, -(at * corner).z)
			if not upright or low < BrickLattice.CELL - 0.01 or behind < 10.0:
				wrong.append("%s hangs %s, its hem %.1f up, %.1f behind" % [info.id,
					"upright" if upright else "at an angle", low, behind])
	for line: String in wrong.slice(0, 8):
		print("    %s" % line)
	_check("%d flat cloths are worn as their worn drawings, and %d with none (tuxedo tails, a short skirt) hang straight down against the back, clear of the ground%s"
		% [worn, hung, "" if wrong.is_empty() else ": %d not" % wrong.size()],
		wrong.is_empty() and worn >= 20 and hung >= 2)
	# And no cape is held out at an angle, on a grown figure or on a child
	# it is too long for: one that would reach the ground is worn higher.
	var tilted: Array[String] = []
	var tried: int = 0
	for legs: String in [Minifig.PLAIN_LEGS, "41879a"]:
		for info: PartLibrary.PartInfo in capes:
			var figure := Minifig.new()
			figure.choose(library, "legs", legs)
			figure.choose(library, "cape", info.id)
			tried += 1
			for item: Dictionary in figure.assemble(library):
				if item["slot"] != "cape":
					continue
				var at: Transform3D = item["at"]
				var part: PartLibrary.PartInfo = library.parts[str(item["part"])]
				var square: bool = at.basis.is_equal_approx(Basis.IDENTITY) \
					or at.basis.x.is_equal_approx(Vector3.RIGHT) \
					and absf((at.basis * Vector3.UP).y) < 0.01
				var low: float = Minifig._lowest(Minifig.FLIP * at * Minifig.FLIP, part.bounds)
				if not square or low < BrickLattice.CELL - 0.01:
					tilted.append("%s on %s%s, %.1f up" % [item["part"], legs,
						"" if square else " at an angle", low])
	for line: String in tilted.slice(0, 8):
		print("    %s" % line)
	_check("none of %d capes, on a grown figure and on a child, is held out at an angle or reaches the ground%s"
		% [tried, "" if tilted.is_empty() else ": %d are" % tilted.size()], tilted.is_empty())
	# What the parts list makes of it: the cloth's own element.
	var as_sold: String = library.element_for("50231", 0)
	var as_worn: String = library.element_for("50231c01", 0)
	_check("the worn drawing is the cloth's element on the parts list: 50231c01 in black %s, 50231 %s"
		% [as_worn, as_sold], not as_sold.is_empty() and as_worn == as_sold)
	var made_in: PartLibrary.PartInfo = Minifig.colours_of(library, "50231c01")
	_check("and comes in the cloth's colours (%d)" % (made_in.colors.size() if made_in != null else 0),
		made_in != null and made_in.colors.size() >= 10)


## Every footwear part in the library has the stud a foot goes on at its
## origin, the top it stands on at y 0: the feet on that, its sole on the
## plate under it, and the lattice taking it there.
func _footwear() -> void:
	var off: Array[String] = []
	var tried: int = 0
	for info: PartLibrary.PartInfo in Minifig.choices(library, "footwear"):
		var figure := Minifig.new()
		figure.choose(library, "footwear", info.id)
		tried += 1
		var feet: float = INF
		var sole: float = INF
		var top: float = INF
		for item: Dictionary in figure.assemble(library):
			var part: PartLibrary.PartInfo = library.parts[str(item["part"])]
			var box: AABB = (item["at"] as Transform3D) * part.bounds
			if item["slot"] == "legs":
				feet = minf(feet, box.position.y)
			elif item["slot"] == "footwear":
				sole = minf(sole, box.position.y)
				top = minf(top, (item["at"] as Transform3D).origin.y)
		if absf(sole) > 0.01 or absf(feet - top) > 0.01:
			off.append("%s: its sole %.2f over the plate, the feet %.2f over its top"
				% [info.id, sole, feet - top])
	for line: String in off.slice(0, 8):
		print("    %s" % line)
	_check("on each of %d kinds of footwear the feet are on its top and its sole on the plate%s"
		% [tried, "" if off.is_empty() else ": %d not" % off.size()],
		off.is_empty() and tried >= 10)
	# What lets it: a part off the lattice is reckoned as where it is, not
	# a cell lower. A flipper 3 LDU thick on a plate, its origin 3 LDU up:
	# clear of the plate; 1 LDU lower, into it.
	world.clear()
	builder.lattice.clear()
	var plate := Transform3D(Basis.IDENTITY, Vector3(10, 8, 10))
	builder.register(world.add_brick("3958", 7, plate), "3958", plate)
	var flipper: Lbm.PartMesh = library.mesh_for("10190")
	var on_it: bool = flipper != null and not builder.lattice.collides_boxes(builder.boxes_for(
		flipper, Transform3D(Basis.IDENTITY, Vector3(10, 8 + 3, 10))))
	var into_it: bool = flipper != null and builder.lattice.collides_boxes(builder.boxes_for(
		flipper, Transform3D(Basis.IDENTITY, Vector3(10, 8 + 2, 10))))
	_check("the lattice takes a flipper standing on a plate, origin 3 LDU up (%s), and not 1 LDU into it (%s)"
		% [on_it, into_it], on_it and into_it)
	world.clear()
	builder.lattice.clear()


## Cloth as LDraw draws it to be sold: a sheet less than a cell thick.
static func _flat(info: PartLibrary.PartInfo) -> bool:
	return info.bounds.size.y < 2.0


## The flat cloth a "(Formed)" drawing is of, 50231c01 -> 50231, or "".
static func _formed_of(info: PartLibrary.PartInfo) -> String:
	if not info.name.contains("(Formed"):
		return ""
	var found: RegExMatch = RegEx.create_from_string("^(.+)c\\d\\d$").search(info.id)
	return found.get_string(1) if found != null else ""


## A worn drawing a figure can wear: hanging no lower than a classic
## figure's feet, a cell clear, and not out in front of it (u9661c01 is
## drawn folded the way the flat sheet lies; 50231c03 is a curtain).
static func _fits_a_figure(info: PartLibrary.PartInfo) -> bool:
	return -info.bounds.position.y <= 70.0 \
		and info.bounds.end.z <= -info.bounds.position.z + 2.0


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
	diver.parts["back"] = "3838"
	diver.parts["headwear"] = ""
	_compare("6973 Deep Freeze Defender, minifig 1", diver,
		_real("6973-1", "6973 - minifig 1.ldr"), {
			"back": [0.01, 0.01], "head": [0.01, -1]})
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

	# 6067 King's Mountain Fortress: a cape (4524), worn on the shoulders
	# 2 LDU up, as all nine real figures wearing it have it, with the head
	# up on it. And 6061's archer's quiver, which every real figure wears
	# turned to its back.
	var caped := Minifig.new()
	caped.parts["cape"] = "4524"
	caped.parts["headwear"] = "4503"
	_compare("6067 King's Mountain Fortress, minifig 3, in a cape", caped,
		_real("6067-1", "6067 - minifig3.ldr"), {"cape": [0.01, 0.01],
			"arm right": [0.01, 0.01], "hips": [0.01, 0.01]})
	var archer := Minifig.new()
	archer.parts["back"] = "4498"
	_compare("6061 Siege Tower, minifig 3, with a quiver on its back", archer,
		_real("6061-1", "6061 - minifig3.ldr"), {"back": [0.01, 0.01]})

	# 10176 King's Castle: a soldier with a shield in his left hand, the
	# hand where the standard joints put it. Compared in the hand that
	# holds it, as the cutlass is.
	_held_left("10176 King's Castle, soldier 1: the shield", "10176-1",
		"10176 - soldier 1.ldr", "3846")
	_held_left("10176 King's Castle, soldier 2: the shield", "10176-1",
		"10176 - soldier 2.ldr", "3846")

	# A visor turns on its helmet: 2447b's pins at its origin, on 3842b's
	# dimples (5 LDU under the head's origin, measured off both parts).
	# 6208's B-wing pilot wears the old drawing of the same visor (2447)
	# on the old drawing of the helmet (2446), both turning 6.5 under the
	# head's origin: the two drawings of the helmet differ by 1.5 LDU,
	# and so do the visors.
	var pilot := Minifig.new()
	pilot.parts["headwear"] = "3842b"
	pilot.parts["hat_extra"] = "2447b"
	var visor_at := Transform3D.IDENTITY
	var head_at := Transform3D.IDENTITY
	for item: Dictionary in pilot.assemble(library):
		if item["slot"] == "hat_extra":
			visor_at = item["at"]
		elif item["slot"] == "head":
			head_at = item["at"]
	var pins: Vector3 = (Minifig.FLIP * head_at.affine_inverse() * visor_at * Minifig.FLIP).origin
	var dimples: Array = MinifigData.PIVOTS.get("3842b", [])
	_check("the classic visor 2447b turns on the classic helmet's dimples: its pins %s, the dimples at y %s"
		% [pins, dimples], dimples.size() == 2 and pins.distance_to(
			Vector3(0, float(dimples[0]), float(dimples[1]))) < 0.01)
	var b_wing: Array = _real("6208-1", "6208 - rebel pilot b-wing.ldr")
	var old_visor := Transform3D.IDENTITY
	var old_head := Transform3D.IDENTITY
	for item: Dictionary in b_wing:
		if item["part"] == "2447":
			old_visor = item["at"]
		elif str(item["part"]).begins_with("3626"):
			old_head = item["at"]
	# 2447.dat turns at y 6.5 of its own frame; where that is on the
	# real figure, against where ours turns.
	var real_pins: Vector3 = (Minifig.FLIP * old_head.affine_inverse() * old_visor
		* Minifig.FLIP) * Vector3(0, 6.5, 0)
	_check("and 6208's B-wing pilot turns the old drawing of it %.2f LDU from there (the helmets' drawings differ by 1.5)"
		% real_pins.distance_to(pins), not b_wing.is_empty()
		and real_pins.distance_to(pins) <= 1.51)

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
	var least: Dictionary = {"headwear": 700, "hat_extra": 30, "head": 700, "neck": 50,
		"back": 30, "cape": 40, "torso": 900, "arms": 50, "hands": 5, "hips": 100,
		"hipwear": 40, "legs": 250, "footwear": 10, "accessory": 800,
		"accessory_left": 800}
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
			var left: String = figure.left_leg(library)
			return library.parts.has(left) and left.begins_with("3817"))
	_check("every printed right leg has a left one", lefts)
	# The two halves of a print LDraw names differently pair by the print
	# they share: 3816cp30 "Rags" and 3817cp30 "Rags and Patch".
	var rags := Minifig.new()
	rags.parts["legs"] = "3816cp30"
	_check("and the halves of a print pair by its number: 3816cp30 with %s"
		% rags.left_leg(library), rags.left_leg(library) == "3817cp30")
	var dual := Minifig.new()
	dual.parts["legs"] = "20461bp00"
	_check("the dual-moulded legs pair by name: 20461bp00 with %s" % dual.left_leg(library),
		dual.left_leg(library) == "20460bp00")
	# Each slot opens on the classic figure's mould, then the others.
	var first: Dictionary = {"torso": "973", "head": "3626c", "legs": Minifig.PLAIN_LEGS,
		"hips": Minifig.PLAIN_HIPS, "arms": Minifig.ARM_RIGHT, "hands": Minifig.HAND}
	var opens: PackedStringArray = PackedStringArray()
	for slot: String in first:
		opens.append("%s %s" % [slot, Minifig.choices(library, slot)[0].id])
	_check("each slot opens on the classic mould: %s" % ", ".join(opens),
		first.keys().all(func(slot: String) -> bool:
			return Minifig.choices(library, slot)[0].id == first[slot]))
	var printed_first: int = Minifig.choices(library, "torso").find(
		library.parts["973p01"]) if library.parts.has("973p01") else -1
	var plain_moulds: int = Minifig.choices(library, "torso").filter(
		func(info: PartLibrary.PartInfo) -> bool:
			return Minifig._family(info.id) == info.id).size()
	_check("then the other plain moulds (%d) before the first print (at %d)"
		% [plain_moulds, printed_first], printed_first >= plain_moulds)
	# Large slots browse by mould or by kind.
	var head_moulds: Array[Dictionary] = Minifig.groups(library, "head")
	var held_kinds: Array[Dictionary] = Minifig.groups(library, "accessory")
	_check("heads come in %d moulds, the biggest %s (%d); things to hold in %d kinds, the biggest %s (%d)"
		% [head_moulds.size(), head_moulds[0]["label"], int(head_moulds[0]["count"]),
			held_kinds.size(), held_kinds[0]["label"], int(held_kinds[0]["count"])],
		head_moulds.size() >= 100 and held_kinds.size() >= 20
		and str(head_moulds[0]["key"]) in ["3626c", "3626b", "28621"])
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


## Every minifigure part the catalogue has — every real part in a
## "Minifig" category or named "Minifig ..." — is offered in some slot,
## or comes with one that is (a left leg with its right).
func _every_part() -> void:
	var universe: Array[PartLibrary.PartInfo] = []
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		var title: String = info.name.strip_edges()
		if (info.category.begins_with("Minifig") or title.begins_with("Minifig")) \
				and Minifig._real(info):
			universe.append(info)
	var offered: Dictionary = {}
	for slot: String in Minifig.SLOTS:
		for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
			offered[info.id] = slot
	var paired: Dictionary = {}
	for slot: String in ["arms", "legs", "hands"]:
		for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
			var other: String = Minifig.partner(library, info.id)
			if not other.is_empty() and not offered.has(other):
				paired[other] = slot
	var missing: Array[String] = []
	for info: PartLibrary.PartInfo in universe:
		if not offered.has(info.id) and not paired.has(info.id):
			missing.append("%s %s (%s)" % [info.id, info.name.strip_edges(), info.category])
	for line: String in missing.slice(0, 8):
		print("    not offered: %s" % line)
	_check("all %d minifigure parts in the catalogue are available: %d offered in a slot, %d as the pair of one, %d not"
		% [universe.size(), universe.size() - paired.size() - missing.size(), paired.size(),
			missing.size()], missing.is_empty() and universe.size() >= 4000)
	# The ones the builder had no slot for.
	var wanted: Dictionary = {"28621": "head", "65753": "hipwear", "36036": "legs",
		"2532": "legs", "4524": "cape", "50231c01": "cape", "2447b": "hat_extra",
		"87693": "hat_extra", "3838": "back", "4498": "back", "10190": "footwear",
		"30375": "torso", "16000p00": "arms", "2531": "hands", "43370": "torso"}
	var wrong: Array[String] = []
	for id: String in wanted:
		if str(offered.get(id, "")) != str(wanted[id]):
			wrong.append("%s in %s" % [id, offered.get(id, "nothing")])
	_check("new moulds and new slots each where they belong%s"
		% ("" if wrong.is_empty() else ": " + ", ".join(wrong)), wrong.is_empty())
	_check("the left hand is offered what the right is (%d)"
		% Minifig.choices(library, "accessory_left").size(),
		Minifig.choices(library, "accessory_left").size()
		== Minifig.choices(library, "accessory").size())


## Each family of each slot — every mould, every kind — put on the plain
## figure: real parts in real places, and nothing in the floor it
## stands on. A cape long enough to reach it is worn higher; a skirt,
## a tail, a long robe, a droid's legs all end above it.
func _every_family() -> void:
	var tried: int = 0
	var below: Array[String] = []
	var broken: Array[String] = []
	for slot: String in Minifig.SLOTS:
		var seen: Dictionary = {}
		for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
			var family: String = Minifig._family(info.id)
			if seen.has(family):
				continue
			seen[family] = true
			var figure := Minifig.new()
			figure.choose(library, slot, info.id)
			tried += 1
			var low: float = INF
			for item: Dictionary in figure.assemble(library):
				var part: PartLibrary.PartInfo = library.parts.get(str(item["part"]))
				if part == null or part.is_redirect():
					broken.append("%s %s: %s" % [slot, info.id, item["part"]])
					continue
				low = minf(low, Minifig._lowest(Minifig.FLIP * (item["at"] as Transform3D)
					* Minifig.FLIP, part.bounds))
			if low < -0.6:
				below.append("%s %s (%.1f)" % [slot, info.id, low])
	for line: String in below.slice(0, 10):
		print("    in the floor: %s" % line)
	for line: String in broken.slice(0, 10):
		print("    not a part: %s" % line)
	_check("%d families put together, every part a real one%s"
		% [tried, "" if broken.is_empty() else ": %d not" % broken.size()],
		broken.is_empty() and tried >= 500)
	_check("and none of them reaches into what it stands on%s"
		% ("" if below.is_empty() else ": %d do" % below.size()), below.is_empty())

	# And the same with the lattice, which is what refuses a figure that
	# would stand in something: every family of what decides where a
	# figure ends — legs, feet, a body, a skirt, a cape, back gear — stood
	# on a 6 x 6 plate, its every part to hand.
	world.clear()
	builder.lattice.clear()
	var floor_at := Transform3D(Basis.IDENTITY, Vector3(10, 8, 10))
	var floor_id: int = world.add_brick("3958", 7, floor_at)
	builder.register(floor_id, "3958", floor_at)
	var stood: int = 0
	var refused: Array[String] = []
	for slot: String in ["legs", "footwear", "torso", "hipwear", "cape", "back"]:
		var families: Dictionary = {}
		for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
			if families.has(Minifig._family(info.id)):
				continue
			families[Minifig._family(info.id)] = true
			var figure := Minifig.new()
			figure.choose(library, slot, info.id)
			var parts: Array[Dictionary] = figure.assemble(library)
			var at: Transform3D = builder.settle_figure(Vector3(10, 400, 10), 0)
			stood += 1
			if not builder.figure_fits(parts, at):
				refused.append("%s %s" % [slot, info.id])
	for line: String in refused.slice(0, 10):
		print("    refused on the plate: %s" % line)
	_check("%d families of legs, feet, bodies, skirts, capes and back gear stood on a plate, none refused%s"
		% [stood, "" if refused.is_empty() else ": %d were" % refused.size()],
		refused.is_empty() and stood >= 150)
	world.clear()
	builder.lattice.clear()


## Arms with no socket for a hand, which the builder leaves without one
## (Minifig._has_socket): a Bionicle Barraki's arm ends in a claw of its own,
## Dug's arm is what he walks on, and a mutant dog's is a leg, and a plain
## hand hung on any of them was held by nothing.
const NO_SOCKET: Dictionary = {"57588": "a Barraki's claw", "92754": "Dug's arm",
	"12613": "a mutant dog's leg"}

## The slots whose whole figures are asked to be one piece, part kind by
## part kind: a visor on its helmet, a cloth cape round the neck, a droid's
## or a skeleton's arm, a prosthetic hand on its stump, legs on springs and
## everything a hand holds.
const WHOLE: Array[String] = ["hat_extra", "cape", "arms", "hands", "legs",
	"accessory", "accessory_left"]

## Figures still in pieces, and why. A string has no bar: the builder
## holds it at its origin, the middle of it, crosswise in the grip, and
## slides it along the grip off the hand to keep its far end out of the
## floor. Held anywhere, the checker could not see it: the thread 56823,
## 1.5 LDU across, fills no cell of the lattice at all, and 71149's braid
## none either, its cover being its two end studs, 16 LDU across, which
## no hand closes on. The bent spring's top is never read in its hips'
## hole, and turned a quarter its foot's cells miss the middle of the
## legs' hole it is in.
const STILL_APART: Dictionary = {"56823": "a thread", "71149": "a braided string",
	"43741-f2": "the bent spring, turned a quarter"}

## Held by the bar of a hilt or a handle, which the builder used to slide
## through the hand like a spear's shaft until the hand was round the
## flat of the blade, or off the handle: four swords as long as a figure
## and a suitcase with its long handle out.
const BY_THE_HILT: Array[String] = ["59", "66964", "2674a", "2674b", "37178-f2"]


## A hand goes into its arm by a peg, and the design checker has to see the
## two as joined. It read a figure's parts at the nearest square turn,
## where a hand turned 45 degrees in its arm is nowhere near the arm's
## socket, so whether a figure was one piece came down to which cells the
## squared parts happened to share: on top of Orthanc, Saruman's raised
## right hand was a piece nothing joins. So every hand on every family of
## every slot is asked about with its arm alone, wherever a figure stands:
## at the origin, where run 4's Orthanc stood Saruman, half a stud over and a
## plate up, and turned a quarter where run 5's stands him. And the figures
## of every kind of hand whole, Saruman where Orthanc stands him, and a hand
## two studs from its arm, which is still a piece of its own.
func _one_piece() -> void:
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	var stands: Array[Transform3D] = [Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY, Vector3(460, 2008, 490)),
		Transform3D(Basis.IDENTITY, Vector3(10, 8, 10)),
		Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(430, 2008, 420))]
	var pieces := func(ids: Array) -> int:
		var model: Assistant.Model = assistant._model_from_world()
		model.placements = model.placements.filter(
			func(p: Assistant.Placement) -> bool: return ids.has(p.id))
		return int(assistant._check(model, true).get("pieces", 0))
	var pairs: int = 0
	var no_socket: Dictionary = {}
	var apart: Array[String] = []
	var whole: int = 0
	var broken: Array[String] = []
	var figures: Dictionary = {}   ## slot -> figures asked
	var in_pieces: Dictionary = {}   ## slot -> Array of what came apart
	var still: Dictionary = {}
	for slot: String in Minifig.SLOTS:
		var seen: Dictionary = {}
		for info: PartLibrary.PartInfo in Minifig.choices(library, slot):
			var family: String = Minifig._family(info.id)
			if seen.has(family):
				continue
			seen[family] = true
			var figure := Minifig.new()
			# A visor on the helmet it turns on: the one an assembly of the
			# library's puts it on, or the classic helmet's dimples.
			if slot == "hat_extra":
				var on: Array = MinifigData.EXTRAS.get(family, [])
				figure.choose(library, "headwear", str(on[0]) if on.size() == 13 else "3842b")
			figure.choose(library, slot, info.id)
			var parts: Array[Dictionary] = figure.assemble(library)
			# A hand on an arm with no socket for one.
			if NO_SOCKET.has(family) and slot == "arms":
				for item: Dictionary in parts:
					if str(item["slot"]) == "hands" and NO_SOCKET.has(
							Minifig._family(str(parts[parts.find(item) - 1]["part"]))):
						no_socket[family] = true
			for n: int in stands.size():
				world.clear()
				builder.lattice.clear()
				var ids: PackedInt64Array = builder.put_figure(parts, "Probe", stands[n])
				if ids.size() != parts.size():
					apart.append("%s %s: %d of %d parts went in" % [slot, info.id,
						ids.size(), parts.size()])
					continue
				# Each hand, and the arm it is on: the arm comes just before.
				var arm: int = 0
				for k: int in parts.size():
					if str(parts[k]["slot"]) == "arms":
						arm = ids[k]
					elif str(parts[k]["slot"]) == "hands" and arm != 0:
						pairs += 1
						if pieces.call([arm, ids[k]]) != 1:
							apart.append("%s %s at stand %d: %s off %s" % [slot, info.id, n,
								parts[k]["part"], world.get_brick(arm).part_id])
				if slot == "hands":
					whole += 1
					if pieces.call(Array(ids)) != 1:
						broken.append("%s at stand %d" % [info.id, n])
				# The whole figure, where it stands at the origin and turned a
				# quarter on top of Orthanc.
				if WHOLE.has(slot) and (n == 0 or n == 3):
					figures[slot] = int(figures.get(slot, 0)) + 1
					if pieces.call(Array(ids)) != 1:
						if STILL_APART.has(info.id):
							still[info.id] = true
						else:
							if not in_pieces.has(slot):
								in_pieces[slot] = []
							(in_pieces[slot] as Array).append("%s at stand %d" % [info.id, n])
	for line: String in apart.slice(0, 10):
		print("    apart: %s" % line)
	_check("each of %d hands on a figure of every family of every slot, at four places, is one piece with its arm%s, 5059 on its stump among them"
		% [pairs, "" if apart.is_empty() else ": %d are not" % apart.size()],
		apart.is_empty() and pairs >= 4000)
	_check("and no hand is hung on an arm with no socket for one (%s)%s"
		% [", ".join(PackedStringArray(NO_SOCKET.values())),
			"" if no_socket.is_empty() else ": on %s" % ", ".join(PackedStringArray(no_socket.keys()))],
		no_socket.is_empty())
	for line: String in broken.slice(0, 10):
		print("    in pieces: %s" % line)
	_check("and %d figures of every kind of hand, at the same four, are each one piece%s"
		% [whole, "" if broken.is_empty() else ": %d are not" % broken.size()],
		broken.is_empty() and whole >= 20)
	for slot: String in WHOLE:
		var said: Array = in_pieces.get(slot, [])
		for line: String in said.slice(0, 6):
			print("    in pieces: %s %s" % [slot, line])
		_check("%d whole figures of every family of %s, at the origin and turned on Orthanc, are each one piece%s"
			% [int(figures.get(slot, 0)), slot, "" if said.is_empty() else ": %d are not" % said.size()],
			said.is_empty() and int(figures.get(slot, 0)) >= 8)
	print("    still in pieces, as they are: %s" % ", ".join(PackedStringArray(
		still.keys().map(func(id: String) -> String: return "%s (%s)" % [id, STILL_APART[id]]))))

	# Each held by its hilt's or handle's bar (MinifigData.GRIPS, read off
	# the part's own cylinders): the hand's grip on that bar, between its
	# ends, and the figure one piece at the origin and a quarter turn on
	# Orthanc.
	var by_hilt: Array[String] = []
	for id: String in BY_THE_HILT:
		var figure := Minifig.new()
		figure.choose(library, "accessory", id)
		var parts: Array[Dictionary] = figure.assemble(library)
		var hand: Transform3D = (parts.filter(func(p: Dictionary) -> bool:
			return p["slot"] == "hands")[0] as Dictionary)["at"]
		var held: Transform3D = (parts.filter(func(p: Dictionary) -> bool:
			return p["slot"] == "accessory")[0] as Dictionary)["at"]
		var bar: Array = MinifigData.GRIPS.get(id, [])
		var flip := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
		var grip: Vector3 = held.affine_inverse() * (hand * (flip * Minifig.GRIP))
		var on: Vector3 = flip * Vector3(bar[0], bar[1], bar[2])
		var way: Vector3 = flip * Vector3(bar[3], bar[4], bar[5])
		var along: float = (grip - on).dot(way)
		var off: float = (grip - on - way * along).length()
		var in_one: Array[int] = []
		for n: int in [0, 3]:
			world.clear()
			builder.lattice.clear()
			in_one.append(pieces.call(Array(builder.put_figure(parts, "Probe", stands[n]))))
		if bar.size() < 8 or off > 0.5 or along < float(bar[6]) - 0.5 \
				or along > float(bar[7]) + 0.5 or in_one != [1, 1]:
			by_hilt.append("%s (%.1f LDU off its bar, %.1f along it, pieces %s)" % [id, off, along, in_one])
	_check("%d swords as long as a figure and a suitcase are held by the bar of the hilt or the handle, each figure one piece at the origin and turned on Orthanc%s"
		% [BY_THE_HILT.size(), "" if by_hilt.is_empty() else ": not %s" % ", ".join(PackedStringArray(by_hilt))],
		by_hilt.is_empty())

	# Saruman as run 5's Orthanc stands him, turned a quarter, his staff
	# raised in his right hand: cut out of models/orthanc.ldr as it was.
	world.clear()
	builder.lattice.clear()
	store.open("res://src/dev/fixtures/saruman_on_orthanc.ldr")
	var his: Array = []
	var held: bool = false
	for brick: BrickWorld.Brick in world.bricks():
		his.append(brick.id)
		held = held or brick.part_id == "51643"
	var whole_him: int = pieces.call(his)
	_check("Saruman where Orthanc stands him, %d parts with his staff, is one piece (%d)"
		% [his.size(), whole_him], his.size() == 12 and held and whole_him == 1)

	# And a hand that is not in an arm is not joined to it.
	world.clear()
	builder.lattice.clear()
	var plain: Array[Dictionary] = Minifig.new().assemble(library)
	var moved: bool = false
	for item: Dictionary in plain:
		if str(item["slot"]) == "hands" and not moved:
			item["at"] = (item["at"] as Transform3D).translated(Vector3(-40, 0, 0))
			moved = true
	var loose: PackedInt64Array = builder.put_figure(plain, "Probe", Transform3D.IDENTITY)
	var count: int = pieces.call(Array(loose))
	_check("a hand two studs out from its arm is a piece of its own (%d pieces)" % count,
		moved and count == 2)

	# Nor a sword out of the hand, nor a cape off the neck: what joins them
	# is being in the grip and round the post, not being near.
	for kept: Array in [["accessory", "3847", Vector3(-40, 0, 0), "a sword two studs out of the hand"],
			["cape", "65384", Vector3(0, 0, -40), "a cloth cape two studs off the neck"],
			["hat_extra", "2447b", Vector3(40, 0, 0), "a visor two studs off its helmet's pivots"]]:
		world.clear()
		builder.lattice.clear()
		var dressed := Minifig.new()
		if kept[0] == "hat_extra":
			dressed.choose(library, "headwear", "3842b")
		dressed.choose(library, kept[0], kept[1])
		var placed: Array[Dictionary] = dressed.assemble(library)
		var off: bool = false
		for item: Dictionary in placed:
			if str(item["slot"]) == kept[0] and not off:
				item["at"] = (item["at"] as Transform3D).translated(kept[2])
				off = true
		var in_place: Array[Dictionary] = dressed.assemble(library)
		var whole_ids: PackedInt64Array = builder.put_figure(in_place, "Probe", Transform3D.IDENTITY)
		var together: int = pieces.call(Array(whole_ids))
		world.clear()
		builder.lattice.clear()
		var apart_ids: PackedInt64Array = builder.put_figure(placed, "Probe", Transform3D.IDENTITY)
		var away: int = pieces.call(Array(apart_ids))
		_check("%s is a piece of its own (%d pieces), and in place one piece (%d)"
			% [kept[3], away, together], off and away == 2 and together == 1)

	# And the page's Orthanc, run 5, every figure on it whole.
	world.clear()
	builder.lattice.clear()
	store.open("res://models/orthanc.ldr")
	var tower: int = world.bricks().size()
	var report: Dictionary = assistant._check(assistant._model_from_world(), true)
	_check("the page's Orthanc, %d parts, is one piece as the checker reads it (%d)"
		% [tower, int(report.get("pieces", 0))],
		tower >= 9400 and int(report.get("pieces", 0)) == 1)
	world.clear()
	builder.lattice.clear()
	assistant.queue_free()


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


## A figure wearing something in every new slot: a visor on its helmet,
## airtanks, a cape, a skirt, flippers, a spear and a shield. Stood on a
## plate, it stands on its flippers on the plate; lifted with X and put
## down again it is the same figure; saved and reopened it is one figure
## in a sub-model of its own, the same parts in the same places.
func _new_slots_stand() -> void:
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	var plate := Transform3D(Basis.IDENTITY, Vector3(40, 8, 10))
	var plate_id: int = world.add_brick("3023", 15, plate)
	builder.register(plate_id, "3023", plate)
	var diver := Minifig.new()
	diver.name = "Frogman"
	for pair: Array in [["headwear", "3842b"], ["hat_extra", "2447b"], ["back", "3838"],
			["cape", "50231c01"], ["hipwear", "65753"], ["footwear", "10190"],
			["accessory", "4497"], ["accessory_left", "3846"]]:
		diver.choose(library, pair[0], pair[1])
	var parts: Array[Dictionary] = diver.assemble(library)
	for item: Dictionary in parts:
		library.request_mesh(str(item["part"]))
	builder.hold_figure(parts, diver.name)
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	var first: int = builder.place()
	builder.drop_figure()
	var ids: PackedInt64Array = builder.figure_of(first)
	_check("a frogman with a visor, airtanks, a cape, a skirt, flippers, a spear and a shield stands on a plate: %d parts as one figure"
		% ids.size(), first != 0 and ids.size() == parts.size())
	var low: float = INF
	var flipper_low: float = INF
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var box: AABB = brick.transform * library.parts[brick.part_id].bounds
		low = minf(low, box.position.y)
		if brick.part_id == "10190":
			flipper_low = minf(flipper_low, box.position.y)
	# Raised by the flippers' 3 LDU, and no more: on the plate's top.
	_check("on its flippers, on the plate's top (y 8): the flippers' undersides at %.2f, nothing lower (%.2f)"
		% [flipper_low, low], absf(flipper_low - 8.0) <= 0.01
		and is_equal_approx(low, flipper_low))
	var placed: Dictionary = _relative(ids)
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	var lifted: bool = builder.lift_hovered()
	_check("X lifts it whole, its frame found from its torso and flippers",
		lifted and builder.is_holding_figure() and world.brick_count() == 1)
	builder.update_preview(Vector3(40, 400, 10), Vector3.DOWN)
	var again: int = builder.place()
	builder.drop_figure()
	_check("and puts it back the same figure in the same place",
		again != 0 and _same_shape(_relative(builder.figure_of(again)), placed))
	var text: String = store.to_text("Reef")
	var opened: Dictionary = store.open_text(text, "reef.ldr")
	var back_ids: PackedInt64Array = PackedInt64Array()
	for brick: BrickWorld.Brick in world.bricks():
		if brick.group == "Frogman":
			back_ids.append(brick.id)
	_check("saved as a sub-model and reopened: %d parts, one figure, the same shape"
		% int(opened["placed"]), text.contains("0 FILE frogman.ldr")
		and back_ids.size() == parts.size()
		and Minifig.is_figure(world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
			return b.group == "Frogman"), library)
		and _same_shape(_relative(back_ids), placed))
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

	# The new slots by words: a knight with a visor, a cape, a shield in
	# his left hand and a spear in his right, on a floor of his own.
	var yard := Transform3D(Basis.IDENTITY, Vector3(200, 24, 40))
	var yard_id: int = world.add_brick("3001", 2, yard)
	builder.register(yard_id, "3001", yard)
	var knight: Variant = await assistant.use_tool("add_minifig", {
		"name": "Galahad", "x": 9, "z": 1, "headwear": "castle helmet chin guard",
		"hat_extra": "visor pointed", "cape": "cape", "accessory": "spear",
		"accessory_left": "shield triangular"})
	var galahad: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if brick.group == "Galahad":
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			galahad[Minifig.role_of(brick.part_id, info)] = brick.part_id
	print("    %s" % str(knight).substr(0, 300))
	_check("add_minifig dresses a knight in the new slots: visor %s, cape %s, shield %s"
		% [galahad.get("hat_extra", "none"), galahad.get("cape", "none"),
			"" if not str(knight).contains("accessory_left") else "in the left hand"],
		str(knight).begins_with("Placed Galahad") and galahad.has("hat_extra")
		and galahad.has("cape") and str(knight).contains("accessory_left 3846"))

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
