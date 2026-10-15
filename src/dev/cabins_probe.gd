extends SceneTree
## A vehicle's cabin, its couplings and the studs a joint leaves, as the
## shapes round's judge named them (docs/DESIGN_SCORES.md, 2026-10-14):
##
##   a cabin said by its side profile with "screen" is laid as a set's is: a
##   windscreen element at the rake where its front climbs to the roof,
##   standing on the plates at its foot, the roof on its top studs, and the
##   roof falling behind it in curved slopes, one piece; a cabin said with no
##   screen is told how to say one;
##   a part of a vehicle on wheels of its own, in line with it and coupled to
##   nothing (a tender, a trailer), is named by the check with how to couple
##   it, and coupled — a towball in its socket, magnets touching — is one
##   piece with it; a car and a sign beside it are not called uncoupled;
##   the studs a shape's joint leaves on its top, where a tile there joined
##   nothing and was laid again as a plate, are tiled by the surface pass.
##
##   godot --headless --path . --script src/dev/cabins_probe.gd [-- OUTDIR]
##
## With OUTDIR each car is saved there as cabin_<name>.ldr, to be looked at.

## The loop with the request taken out. Everything else is the real one.
class Offline extends Assistant:
	func _send() -> void:
		pass


var _failures: int = 0
var _library: PartLibrary
var assistant: Offline
var world: BrickWorld
var builder: Builder
var store: ModelStore

## The guide's car: its body a side profile, its cabin its own side profile
## on it, the front climbing to the roof as glass, the roof falling to the
## tail, a band of glass for the side windows.
const GUIDE_CAR: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"bands": [{"from": 12, "to": 15, "color": 40}],
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 7], [3, 9],
		[8, 10], [20, 10], [21, 9]], "under": [[0, 2], [21, 2]]}},
		{"extrude": {"along": "x", "from": 1, "width": 6, "round": 1, "profile": [[8, 10],
			[11, 18], [13, 18], [20, 11]], "screen": true}}], "wheels": [4, 16]}

## The shapes round's car (2026-10-14-shapes), its body as its session said
## it: the cabin a black loft, flat on top, and a red roof lofted on that.
## Judged "a boxy cabin with a flat roof and an upright windscreen".
const BENCH_CAR: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 5], [1, 6],
		[4, 7], [7, 8], [14, 8], [18, 8], [19, 7], [20, 6]], "under": [[0, 2], [20, 2]]}},
		{"loft": {"along": "x", "centre": 4, "color": 0, "sections": [{"at": 7, "width": 7,
			"height": 1, "bottom": 8}, {"at": 9.5, "width": 6, "height": 5, "bottom": 8, "round": 0.4},
			{"at": 12.5, "width": 6, "height": 5, "bottom": 8, "round": 0.4}, {"at": 16, "width": 6,
			"height": 2.5, "bottom": 8, "round": 0.4}, {"at": 18.5, "width": 6, "height": 0.5,
			"bottom": 8}]}},
		{"loft": {"along": "x", "centre": 4, "color": 4, "sections": [{"at": 9.5, "width": 5,
			"height": 1, "bottom": 12}, {"at": 12.5, "width": 5, "height": 1, "bottom": 12},
			{"at": 15, "width": 5, "height": 0.5, "bottom": 11}]}}], "wheels": [4, 15]}

## A truck's cab: a steep front over two studs, a short roof, a box behind.
const TRUCK_CAB: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"solids": [{"extrude": {"along": "x", "width": 6, "profile": [[0, 9], [24, 9]],
		"under": [[0, 2], [24, 2]]}},
		{"extrude": {"along": "x", "width": 6, "profile": [[0, 10], [1, 10], [3, 18], [7, 18]],
			"screen": true}}], "wheels": [4, 19]}


## An aircraft's fuselage, round, its nose climbing to the top of it: the
## cockpit's windscreen where it climbs.
const FUSELAGE: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
	"solids": [{"revolve": {"axis": "x", "centre": [0, 8.5, 4], "profile": [[0, 1.2], [2, 2.4],
		[4, 3.2], [6, 3.4], [26, 3.4], [30, 1.6]], "screen": true}}]}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var out_dir: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	world = BrickWorld.new()
	world.library = _library
	root.add_child(world)
	builder = Builder.new()
	builder.world = world
	builder.library = _library
	root.add_child(builder)
	assistant = Offline.new()
	assistant.library = _library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	store = ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	store.keeps = false
	await process_frame

	print("  the windscreens, read off their meshes")
	# Read through the script, so the probe runs (and fails) on code without them.
	var reads: Callable = Callable(Shapes, "screen_part")
	var readable: bool = _has_static(Shapes, "screen_part")
	for id: String in SCREENS:
		var s: Dictionary = reads.call(_library, id) if readable else {}
		_check("%s: %s across, %s along its rake, %s plates, top studs %s, grips %s" % [id,
			s.get("w", "?"), s.get("d", "?"), s.get("h", "?"), str(s.get("tops", [])),
			(s.get("grips", []) as Array).size()],
			not s.is_empty() and not (s["tops"] as Array).is_empty()
				and not (s["grips"] as Array).is_empty())

	await _cabins(out_dir)
	await _couplings()
	await _joint_studs()

	print("")
	if _failures == 0:
		print("cabins probe: all passed")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## Cabins said with a screen, and one said without.
func _cabins(out_dir: String) -> void:
	var screens: Dictionary = {}
	for id: String in SCREENS:
		screens[id] = true
	var said_screen: Dictionary = BENCH_CAR.duplicate(true)
	(((said_screen["solids"] as Array)[1] as Dictionary)["loft"] as Dictionary)["screen"] = true
	for one: Array in [["the guide's car", GUIDE_CAR, 2], ["the bench car's own cabin, its loft "
			+ "said with a screen", said_screen, 0], ["a truck's cab, its front steep", TRUCK_CAB, 0],
			["an aircraft's cockpit, where its nose climbs", FUSELAGE, 0]]:
		print("")
		print("  %s" % one[0])
		assistant._brief = "a vehicle"
		var model: Assistant.Model = assistant._read_model({"name": one[0], "floor": "none",
			"patterns": [one[1]]})
		await assistant._ensure_parts(model)
		var verdict: Dictionary = assistant._check(model, true)
		var glass: Array = []
		var curved_behind: int = 0
		var front: float = INF
		for placement: Assistant.Placement in model.placements:
			if screens.has(placement.part):
				glass.append(placement)
				front = minf(front, placement.x)
		# The roof's own, face up: a curved slope a side shell turned out at the
		# body's foot was counted with them, and went when the glass round kept
		# shells off the cabin's glass.
		for placement: Assistant.Placement in model.placements:
			if Style.kinds_of(placement.part).contains("c") and placement.x > front + 3.0 \
					and placement.y >= 8.0 and placement.face == "up":
				curved_behind += 1
		var advice: String = "\n".join(PackedStringArray(verdict.get("advice", [])))
		_check("laid without trouble: %s" % str(assistant._pattern_trouble),
			assistant._pattern_trouble.is_empty())
		var shown := PackedStringArray()
		for p: Assistant.Placement in glass:
			shown.append("%s colour %d at x %s y %s z %s rot %d" % [p.part, p.color, _num(p.x),
				_num(p.y), _num(p.z), p.rot])
		_check("a windscreen stands at its rake, in glass: %s" % ", ".join(shown),
			glass.size() == 1 and (glass[0] as Assistant.Placement).color in [40, 47])
		_check("the reply says where it stands: %s" % _line_of(advice, "is a windscreen"),
			advice.contains("is a windscreen"))
		_check("one piece on its wheels, nothing floating or overlapping: %s, %d pieces"
			% [verdict["summary"], int(verdict.get("pieces", 0))],
			bool(verdict["ok"]) and int(verdict.get("pieces", 0)) == 1)
		if not bool(verdict["ok"]):
			print(str(verdict["feedback"]).left(1500))
		_check("its roof falls behind it in curved slopes: %d" % curved_behind,
			curved_behind >= int(one[2]))
		var lopsided: bool = advice.contains("The model is a mirror of itself about")
		_check("a mirror of itself, part for part", not lopsided)
		if not out_dir.is_empty():
			world.clear()
			builder.lattice.clear()
			assistant._apply(model)
			for _n: int in 3:
				await process_frame
			var path: String = "%s/cabin_%s.ldr" % [out_dir, str(one[0]).split(" ")[1].replace("'s", "")]
			print("  saved %s: %s" % [path, store.export_to(path, "Model")])
			world.clear()
			builder.lattice.clear()

	print("")
	print("  a cabin said as a loft with a flat top and no screen")
	assistant._brief = "a sports car"
	var unsaid: Assistant.Model = assistant._read_model({"name": "car", "floor": "none",
		"patterns": [BENCH_CAR]})
	var unsaid_check: Dictionary = assistant._check(unsaid, true)
	var unsaid_advice: String = "\n".join(PackedStringArray(unsaid_check.get("advice", [])))
	_check("is told to say its screen: %s" % _line_of(unsaid_advice, "\"screen\": true"),
		unsaid_advice.contains("\"screen\": true") and unsaid_advice.contains("fastback"))


## Two vehicles end to end: uncoupled, named with the fix; coupled, one.
func _couplings() -> void:
	print("")
	print("  an engine and a tender on wheels of their own, end to end")
	var engine: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 2,
		"solids": [{"extrude": {"along": "x", "width": 6, "profile": [[0, 9], [12, 9]],
			"under": [[0, 2], [12, 2]]}}], "wheels": [3, 9]}
	var tender: Dictionary = engine.duplicate(true)
	tender["at"] = {"x": 13, "y": 0, "z": 0}
	tender["solids"] = [{"extrude": {"along": "x", "width": 6, "profile": [[0, 9], [8, 9]],
		"under": [[0, 2], [8, 2]]}}]
	tender["wheels"] = [2, 6]
	assistant._brief = "a locomotive and its tender"
	var apart: Assistant.Model = assistant._read_model({"name": "train", "floor": "none",
		"patterns": [engine, tender], "assemblies": [{"name": "tender", "x_from": 13,
			"x_to": 21, "z_from": 0, "z_to": 6}]})
	var verdict: Dictionary = assistant._check(apart, true)
	var feedback: String = str(verdict["feedback"])
	_check("two pieces: %d" % int(verdict.get("pieces", 0)), int(verdict.get("pieces", 0)) == 2)
	_check("the tender is named uncoupled, with where it is: %s" % _line_of(feedback, "couples it"),
		int(verdict.get("uncoupled", 0)) == 1 and feedback.contains("The tender")
		and feedback.contains("nothing couples it"))
	_check("...and how sets couple one: %s" % _line_of(feedback, "towball"),
		feedback.contains("towball hitch") and feedback.contains("magnet coupling"))

	print("")
	print("  a car and a sign beside it")
	var car: Dictionary = engine.duplicate(true)
	assistant._brief = "a car with a sign"
	var sign: Array = [{"part": "3001", "color": 15, "x": 3, "y": 0, "z": 9, "rot": 0},
		{"part": "3001", "color": 15, "x": 3, "y": 3, "z": 9, "rot": 0},
		{"part": "3001", "color": 15, "x": 3, "y": 6, "z": 9, "rot": 0},
		{"part": "3001", "color": 15, "x": 3, "y": 9, "z": 9, "rot": 0}]
	var scene: Assistant.Model = assistant._read_model({"name": "scene", "floor": "none",
		"bricks": sign, "patterns": [car]})
	var scene_check: Dictionary = assistant._check(scene, true)
	_check("the sign is not called uncoupled: %d" % int(scene_check.get("uncoupled", 0)),
		int(scene_check.get("uncoupled", 0)) == 0)

	for way: Array in _couplers():
		print("")
		print("  the same, coupled by %s" % way[0])
		var bricks: Array = way[1]
		var behind: Dictionary = tender.duplicate(true)
		behind["at"] = {"x": float(way[3]), "y": 0, "z": 0}
		var coupled: Assistant.Model = assistant._read_model({"name": "train", "floor": "none",
			"bricks": bricks, "patterns": [engine, behind]})
		await assistant._ensure_parts(coupled)
		var joined: Dictionary = assistant._check(coupled, true)
		_check("one piece, nothing uncoupled: %s, %d pieces, %d uncoupled" % [joined["summary"],
			int(joined.get("pieces", 0)), int(joined.get("uncoupled", 0))],
			bool(joined["ok"]) and int(joined.get("pieces", 0)) == 1
				and int(joined.get("uncoupled", 0)) == 0)
		if not bool(joined["ok"]) or int(joined.get("pieces", 0)) != 1:
			print(str(joined["feedback"]).left(1200))
		var technique: Dictionary = Techniques.named(str(way[2]))
		_check("show_technique \"%s\" is there" % way[2], not technique.is_empty())


## The coupling parts each way, at the engine's back (x 12) and the tender's
## front: [how, bricks, technique, where the tender's shape stands].
func _couplers() -> Array:
	return [
		# The ball a stud past its plate's studs, the socket a stud short of its
		# own: the tender's studs two on from the engine's last row.
		["a towball in its socket", [
			{"part": "14417", "color": 0, "x": 11, "y": 8.5, "z": 2, "rot": 1},
			{"part": "14704", "color": 0, "x": 12, "y": 8.5, "z": 2, "rot": 3}],
			"towball hitch", 13.0],
		# Each buffer beam's tongue on a 2 x 2 plate on its car's last two rows,
		# the beams hanging past the ends, their magnets touching between.
		["magnets touching", [
			{"part": "3022", "color": 0, "x": 10, "y": 9, "z": 2, "rot": 0},
			{"part": "64422", "color": 0, "x": 9.5, "y": 4.5, "z": -0.5, "rot": 1},
			{"part": "3022", "color": 0, "x": 17, "y": 9, "z": 2, "rot": 0},
			{"part": "64422", "color": 0, "x": 14.5, "y": 4.5, "z": -0.5, "rot": 3}],
			"magnet coupling", 17.0],
	]


## The studs a shape's joint leaves on its top, tiled by the surface pass:
## bodies as sessions said them, each built, the surface pass laid, and the
## few open studs set in a tiled top counted before and after.
func _joint_studs() -> void:
	print("")
	print("  the studs a joint leaves in a tiled top, tiled by the surface pass")
	var said: Dictionary = (load("res://src/dev/shapes_probe.gd") as GDScript) \
		.get_script_constant_map()
	var found: int = 0
	for one: Array in [["the guide's car", GUIDE_CAR], ["the bench car", BENCH_CAR],
			["the steps round's fastback", said["CAR_STEPS_FASTBACK"]],
			["a curved car's nose", said["CAR_CURVED_NOSE"]],
			["a curved car's tail", said["CAR_CURVED_TAIL"]],
			["a boiler", said["BOILER"]], ["a hull's bow", said["HULL_BOW"]]]:
		assistant._busy = false
		world.clear()
		builder.lattice.clear()
		assistant.surface_pass().reset()
		assistant._brief = "a vehicle"
		var built: Variant = await assistant.use_tool("submit_design", {"name": one[0],
			"description": "a fixture", "floor": "none", "bricks": [], "patterns": [one[1]],
			"features": []})
		if not str(built).begins_with("Built"):
			_check("%s builds: %s" % [one[0], str(built).left(200)], false)
			continue
		var before: Array = _joint_groups()
		await assistant.surface_review()
		var after: Array = _joint_groups()
		found += before.size()
		_check("%s: %d group%s of studs set in a tiled top before the pass (%s), %d after (%s)"
			% [one[0], before.size(), "" if before.size() == 1 else "s", ", ".join(before),
				after.size(), ", ".join(after)], after.is_empty())
	_check("...a joint left studs in a tiled top on %d of them" % found, found > 0)


## The groups of fewer than four open studs set in a tiled top, each said
## as its studs and where.
func _joint_groups() -> Array:
	var sp: SurfacePass = assistant.surface_pass()
	sp._read = null
	var tops: Dictionary = sp.open_tops()
	# The tiles lying face up, by the stud under each at the height of its
	# foot and of its top, as the pass keys a stud.
	var tiled: Dictionary = {}
	for raw: Variant in sp.tile_tops().values():
		var tile: Dictionary = raw
		var at: Vector3 = tile["at"]
		tiled[SurfacePass.key_of(at)] = true
		tiled[SurfacePass.key_of(Vector3(at.x, float(tile["top"]), at.z))] = true
	var out: Array = []
	var seen: Dictionary = {}
	for start: Variant in tops:
		if seen.has(start):
			continue
		var field: Array[Vector3i] = []
		var queue: Array[Vector3i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var key: Vector3i = queue.pop_back()
			field.append(key)
			for step: Vector3i in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2),
					Vector3i(0, 0, -2)]:
				if tops.has(key + step) and not seen.has(key + step):
					seen[key + step] = true
					queue.append(key + step)
		var set_in: bool = false
		for key: Vector3i in field:
			for step: Vector3i in [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2),
					Vector3i(0, 0, -2)]:
				set_in = set_in or (not field.has(key + step) and tiled.has(key + step))
		if field.size() < 4 and set_in:
			var at: Vector3 = (tops[field[0]] as Dictionary)["at"]
			out.append("%d at x %s, y %s, z %s" % [field.size(), _num(at.x / 20.0 - 0.5),
				_num(at.y / 8.0), _num(at.z / 20.0 - 0.5)])
	return out


## The windscreens a screen is laid in (Shapes.SCREENS).
const SCREENS: Array = ["92583", "4176", "3823", "57783"]


static func _has_static(script: GDScript, name: String) -> bool:
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == name:
			return true
	return false


func _line_of(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			var at: int = line.find(words)
			return line.substr(maxi(0, at - 120), 300)
	return "(not said)"


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.05))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
