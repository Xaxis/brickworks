extends SceneTree
## A shaped vehicle's cabin, as the cabins round's judge and sessions found
## it (docs/DESIGN_SCORES.md, 2026-10-14-cabins). Both cars laid their
## windscreen and then built the car again by hand: the first called its
## shaped body "too blocky" — its cabin solid red, side studs standing open
## along it — and the second cut a seat into its cabin, and the windscreen
## read the roof off the cut and stood on its floor, leaning forward. The
## judge: "a tall, square-sided block". The screen hint was given to both
## ships, for a raised stern.
##
##   the glass   a cabin on wheels said with a screen is glazed behind it, in
##               the screen's glass, in parts LEGO made in it, one piece; a
##               fuselage's cockpit is not;
##   the studs   no side stud is left open on a shaped body by its side shells;
##   the roof    a seat cut into the cabin leaves its windscreen where it was:
##               the roof is read across the cabin's whole width;
##   the hint    "say a screen" is told to a shape on wheels or a solid said
##               in glass, and not to a ship's raised stern;
##   the words   a body the shape pattern laid is told to keep it, not to say
##               one, nor that its skinned flanks step in plates.
##
## Each body is as its session said it, read from the round's transcripts.
##
##   godot --headless --path . --script src/dev/cabin_glass_probe.gd [-- OUTDIR]
##
## With OUTDIR each body is saved there as glass_<name>.ldr, to be looked at.

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

## The cabins round's first car: an 8-wide body and a 6-wide cabin on it
## with a screen, both rounded across.
const CAR_ONE: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"bands": [{"from": 2, "to": 3, "color": 0}],
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 5], [1, 7],
		[3, 8], [7, 9], [16, 9], [18, 8], [19, 7]], "under": [[0, 2], [19, 2]]}},
		{"extrude": {"along": "x", "from": 1, "width": 6, "round": 1, "profile": [[7, 9],
			[10, 16], [12, 16], [17, 10]], "screen": true}}], "wheels": [4, 15], "wheel_color": 71}

## The second car, its body line raised, without and with the box it cut out
## of its cabin for the driver.
const CAR_TWO: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"bands": [{"from": 2, "to": 4, "color": 0}],
	"solids": [{"extrude": {"along": "x", "width": 8, "round": 1.5, "profile": [[0, 7], [1, 8],
		[3, 9], [7, 10], [16, 10], [18, 9], [19, 8]], "under": [[0, 2], [19, 2]]}},
		{"extrude": {"along": "x", "from": 1, "width": 6, "round": 1, "profile": [[7, 10],
			[9, 16], [12, 16], [16, 12], [18, 10]], "screen": true}}], "wheels": [4, 15],
	"wheel_color": 71}
const SEAT_CUT: Array = [{"box": {"from": [9, 3, 2], "size": [3, 13, 4]}, "keep": true}]

## The second fire truck's: a chassis-long body, a cab with a screen, the
## locker body a box behind it.
const TRUCK: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
	"solids": [{"extrude": {"along": "x", "width": 6, "profile": [[0, 8], [26, 8]],
		"under": [[0, 2], [26, 2]]}},
		{"extrude": {"along": "x", "width": 6, "round": 0.5, "profile": [[0, 8], [0.5, 10],
			[2.5, 17], [7, 17], [7, 8]], "screen": true}},
		{"box": {"from": [8, 8, 0], "size": [18, 5, 6]}}], "wheels": [4, 20]}

## An aircraft's round fuselage, its cockpit's screen where the nose climbs
## (cabins_probe's): its roof runs on to the tail, and is not glazed.
const FUSELAGE: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 15,
	"solids": [{"revolve": {"axis": "x", "centre": [0, 8.5, 4], "profile": [[0, 1.2], [2, 2.4],
		[4, 3.2], [6, 3.4], [26, 3.4], [30, 1.6]], "screen": true}}]}

## The first ship's hull and raised sterncastle, told three times to say its
## stern as a screen.
const SHIP: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 70,
	"bands": [{"from": 0, "to": 4, "color": 0}, {"from": 10, "to": 11, "color": 19}],
	"solids": [{"loft": {"along": "x", "centre": 6, "sections": [{"at": 0, "width": 10,
		"height": 15, "bottom": 4, "round": 0.4, "keel": 0.5}, {"at": 6, "width": 12,
		"height": 14, "bottom": 1, "round": 0.5, "keel": 0.6}, {"at": 24, "width": 12,
		"height": 14, "bottom": 0, "round": 0.5, "keel": 0.7}, {"at": 34, "width": 8,
		"height": 15, "bottom": 2, "round": 0.6, "keel": 0.7}, {"at": 40, "width": 0,
		"height": 17, "bottom": 6, "round": 0.5, "keel": 0.5}]}},
		{"box": {"from": [0, 14, 1], "size": [11, 7, 10], "color": 70}}],
	"cuts": [{"box": {"from": [11, 11, 1], "size": [25, 6, 10]}}]}

## A fighter's canopy said in glass on a hull with no wheels, its front
## climbing steeply and no screen said: a canopy is what a screen is for.
const CANOPY: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 71,
	"solids": [{"extrude": {"along": "x", "width": 6, "profile": [[0, 2], [24, 6]],
		"under": [[0, 0], [24, 0]]}},
		{"extrude": {"along": "x", "from": 1, "width": 4, "color": 40, "profile": [[8, 5],
			[10, 12], [14, 12], [17, 6]]}}]}

## The shapes round's car, its cabin a black loft said with no screen, on
## wheels (cabins_probe's BENCH_CAR): still told how to say one.
const LOFT_CAR: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
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

## The hint, as the shapes say it.
const HINT := "say \"screen\": true"


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

	var cut: Dictionary = CAR_TWO.duplicate(true)
	cut["cuts"] = SEAT_CUT.duplicate(true)
	var laid: Dictionary = {}
	for one: Array in [["car_one", CAR_ONE], ["car_two", CAR_TWO], ["car_two_cut", cut],
			["truck", TRUCK], ["fuselage", FUSELAGE], ["ship", SHIP], ["canopy", CANOPY],
			["loft_car", LOFT_CAR]]:
		laid[one[0]] = await _lay(str(one[0]), one[1], out_dir)

	print("")
	print("  the glass: a cabin on wheels glazed behind its screen")
	for name: String in ["car_one", "car_two", "car_two_cut", "truck"]:
		var found: Dictionary = laid[name]
		var sides: Dictionary = found["sides"]
		_check("%s: %d parts of glass behind its %s, %s; down the near side %d, the far %d"
			% [name, (found["glass"] as Array).size(), found["screen_part"],
				str(found["glass_parts"]), int(sides.get("near", 0)), int(sides.get("far", 0))],
			int(sides.get("near", 0)) >= 2 and int(sides.get("far", 0)) >= 2)
		_check("...said in the reply: %s" % _line_of(found["reply"], "glazed"),
			str(found["reply"]).contains("the cabin is glazed"))
		_check("...every part of it made in its glass: %s" % _line_of(found["reply"],
			"never moulded"), not str(found["reply"]).contains("never moulded"))
		_check("...one piece, nothing floating: %s, %d pieces" % [found["summary"],
			int(found["pieces"])], bool(found["ok"]) and int(found["pieces"]) == 1)
	var fuselage: Dictionary = laid["fuselage"]
	_check("a fuselage's cockpit has its screen and no more glass: %s, %d other parts of glass"
		% [fuselage["screen_part"], (fuselage["glass"] as Array).size()],
		not str(fuselage["screen_part"]).is_empty() and (fuselage["glass"] as Array).is_empty())

	print("")
	print("  the studs: none left open on a body's side by its shells")
	for name: String in ["car_one", "car_two", "car_two_cut", "truck", "loft_car"]:
		var found: Dictionary = laid[name]
		_check("%s: %d side stud%s open%s" % [name, (found["open"] as Array).size(),
			"" if (found["open"] as Array).size() == 1 else "s",
			(": " + ", ".join(PackedStringArray((found["open"] as Array).slice(0, 6))))
				if not (found["open"] as Array).is_empty() else ""],
			(found["open"] as Array).is_empty())

	print("")
	print("  the roof: a seat cut into the cabin leaves the windscreen where it was")
	var whole: Dictionary = laid["car_two"]
	var seated: Dictionary = laid["car_two_cut"]
	_check("without the cut: %s at %s" % [whole["screen_part"], whole["screen_at"]],
		not str(whole["screen_at"]).is_empty())
	_check("with it, the same: %s at %s" % [seated["screen_part"], seated["screen_at"]],
		not str(seated["screen_at"]).is_empty() and seated["screen_at"] == whole["screen_at"]
			and seated["screen_part"] == whole["screen_part"])
	_check("...leaning back, its foot before its top row: %s" % _line_of(seated["reply"],
		"its foot at"), _leans_back(str(seated["reply"])))

	print("")
	print("  the hint: only on wheels, or of a solid said in glass")
	_check("a ship's raised stern is not told to say a screen: %s"
		% _line_of(laid["ship"]["reply"], HINT), not str(laid["ship"]["reply"]).contains(HINT))
	_check("a canopy said in glass is: %s" % _line_of(laid["canopy"]["reply"], HINT),
		str(laid["canopy"]["reply"]).contains(HINT))
	_check("a car's cabin said with no screen is: %s" % _line_of(laid["loft_car"]["reply"], HINT),
		str(laid["loft_car"]["reply"]).contains(HINT))

	print("")
	print("  the words: a body the shape laid is told to keep it")
	for name: String in ["car_one", "truck"]:
		var reply: String = laid[name]["reply"]
		_check("%s is told to keep it: %s" % [name, _line_of(reply, "the body the shape laid")],
			reply.contains("the body the shape laid, kept"))
		_check("...and not to say a body with the shape pattern: %s" % _line_of(reply,
			"the shape pattern, for a body"), not reply.contains("the shape pattern, for a body"))
	_check("the first car, its flanks skinned by its shell, is not told it steps in plates: %s"
		% _line_of(laid["car_one"]["reply"], "rounded across"),
		not str(laid["car_one"]["reply"]).contains("rounded across as well as along it"))

	print("")
	if _failures == 0:
		print("cabin glass probe: all passed")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## One body submitted as a session submits it: what the reply says, its
## windscreen, the glass laid besides, the side studs left open, the check.
func _lay(name: String, pattern: Dictionary, out_dir: String) -> Dictionary:
	print("")
	print("  %s" % name)
	assistant._busy = false
	assistant._last_submitted = {}
	world.clear()
	builder.lattice.clear()
	assistant.surface_pass().reset()
	assistant._brief = "a vehicle"
	var reply: String = str(await assistant.use_tool("submit_design", {"name": name,
		"description": "a fixture", "floor": "none", "bricks": [], "patterns": [pattern],
		"features": []}))
	print("    %s" % reply.get_slice("\n", 0))
	var out: Dictionary = {"reply": reply, "glass": [], "sides": {}, "glass_parts": {},
		"open": [], "screen_part": "", "screen_at": ""}
	var middle: float = 0.0
	var count: int = 0
	for brick: BrickWorld.Brick in world.bricks():
		middle += brick.transform.origin.z / 20.0
		count += 1
		if Shapes.SCREENS.has(brick.part_id):
			var at: Vector3 = brick.transform.origin
			out["screen_part"] = "%s in colour %d" % [brick.part_id, brick.color_code]
			out["screen_at"] = "x %s y %s z %s" % [_num(at.x / 20.0), _num(-at.y / 8.0),
				_num(at.z / 20.0)]
	middle /= maxf(1.0, count)
	for brick: BrickWorld.Brick in world.bricks():
		var colour: PartLibrary.BrickColor = _library.colors.get(brick.color_code)
		if Shapes.SCREENS.has(brick.part_id) or colour == null or not colour.is_transparent():
			continue
		(out["glass"] as Array).append(brick)
		var key: String = "%s c%d" % [brick.part_id, brick.color_code]
		(out["glass_parts"] as Dictionary)[key] = int((out["glass_parts"] as Dictionary).get(key, 0)) + 1
		var side: String = "near" if brick.transform.origin.z / 20.0 < middle else "far"
		(out["sides"] as Dictionary)[side] = int((out["sides"] as Dictionary).get(side, 0)) + 1
	var ids: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		ids.append(brick.id)
	for point: OpenPoints.Point in OpenPoints.read(assistant).points_of(ids):
		if point.kind == "stud" and absf(point.way.y) < 0.3 and point.by == 0:
			(out["open"] as Array).append("%s at %s" % [point.part, OpenPoints.where_of(point)])
	var verdict: Dictionary = assistant._check(assistant._model_from_world(), true)
	out["ok"] = bool(verdict.get("ok", false))
	out["pieces"] = int(verdict.get("pieces", 0))
	out["summary"] = str(verdict.get("summary", ""))
	print("    screen %s at %s; glass %s; %d side studs open; %s, %d pieces" % [out["screen_part"],
		out["screen_at"], str(out["glass_parts"]), (out["open"] as Array).size(), out["summary"],
		out["pieces"]])
	if not out_dir.is_empty():
		var path: String = "%s/glass_%s.ldr" % [out_dir, name]
		print("    saved %s: %s" % [path, store.export_to(path, "Model")])
	return out


## Whether the screen the reply describes leans back: its foot nearer the
## nose (low x) than its top row, read off "its foot at x A standing ... to
## its top row at x B".
func _leans_back(reply: String) -> bool:
	var found: RegExMatch = RegEx.create_from_string(
		"its foot at x (-?[0-9.]+) standing.*?top row at x (-?[0-9.]+)").search(reply)
	return found != null and float(found.get_string(1)) < float(found.get_string(2))


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
