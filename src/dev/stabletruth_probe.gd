## How often the stability check is right, by structures built for real and
## by a published force model's scores (docs/RESEARCH.md, unit 3).
##
##   godot --headless --path . --script src/dev/stabletruth_probe.gd
##
## StableLego (Liu et al., RA-L 2024) built its test structures and said
## which stood: stairs of 2 x 4 bricks, each two studs on, of 19 levels that
## stand and of 20 that come apart at the second brick, and of 20 braced; a
## stick of 1-wide bricks reaching 48 studs with two loads at its end that
## stands, with three that comes apart at its root, and with three braced;
## and 200 g on stairs of 3 levels, which hold it, and of 4, which come
## apart at the second brick. tools/stablelego_ldr.py turns them into LDraw
## (tests/fixtures/stability/stablelego), each on a 48 x 48 baseplate.
## Each is opened as a person opens a file (ModelStore.open_text) and weighed
## as the status bar weighs it (Main.weigh_joints): the floor the store's,
## every joint's margin with it.
##
## A structure comes apart, by the check, where a joint's moment is past
## what its studs hold where they let go (Balance.lets_go, the line Tested
## drops parts at), or where it tips, leans, stands top-heavy or a piece
## tips off a touch; what comes down is all that joint held up. Each must
## come out as it was built, brick by brick: one that came apart lost the
## brick it broke under and everything on it, and kept the rest. Past the
## working load and short of letting go is "weak": the status bar says so,
## and it is printed, but it is not a fall. The builds also bound where a
## stud lets go, into a part a stud wide and into a wider one: above what
## any standing one needs and below what a fallen one needed where it broke;
## the check's let-go must be inside each.
##
## Then StableText2Brick's sample (BrickGPT, ICCV 2025): 150 structures of
## its test split, 100 by a hash of their ids and the 50 most stressed, whose
## per-brick scores StableLego's analysis computed. Every one of them holds,
## so each brick the check says comes apart is a false alarm; at least 95%
## of the bricks must agree. Computed, not built: agreement, not truth.
##
## Exits non-zero when the bar is not met.
extends SceneTree

const BUILT := "res://tests/fixtures/stability/stablelego/"
const SAMPLE := "res://tests/fixtures/stability/stabletext2brick/"
const BUILT_FILES: Array[String] = ["stair_19", "stair_20", "stair_20_good", "stick_light",
	"stick_heavy", "stick_heavy_good", "external_weight_good", "external_weight_fail"]
## The baseplate both sources' structures stand on, 48 x 48.
const PLATE := "4186"
## The share of StableText2Brick's bricks that must agree.
const AGREE := 0.95
const CAR := "res://models/car.ldr"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
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
	await process_frame

	print("the clutch: %s N a stud where it lets go, %s N its working load"
		% [Balance.tidy(Balance.ULTIMATE_N), Balance.tidy(Balance.ALLOWABLE_N)])
	_built()
	_sample()
	_car()
	if _failures > 0:
		print("\n%d check(s) failed" % _failures)
	else:
		print("\nevery check passed")
	quit(1 if _failures > 0 else 0)


## StableLego's built structures, each judged as it really stood or fell,
## brick by brick: one that came apart at brick K lost K and all it held up,
## and kept the rest.
func _built() -> void:
	print("\nStableLego's structures, built for real:")
	var right: int = 0
	var bricks_right: int = 0
	var bricks: int = 0
	var stairs_right: int = 0
	var stairs: int = 0
	## By how wide the part the studs go into is ("a stud wide" or "wider"):
	## the most a stud of a standing structure needs to hold, the least one
	## needed where a structure broke, and where the check has it let go, N.
	var low: Dictionary = {}
	var high: Dictionary = {}
	var lets_go: Dictionary = {}
	for name: String in BUILT_FILES:
		var text: String = FileAccess.get_file_as_string(BUILT + name + ".ldr")
		var stood: bool = text.contains("0 // built: stands")
		var broke: String = ""
		for line: String in text.split("\n"):
			if line.begins_with("0 // breaks at: the joint under brick "):
				broke = line.trim_prefix("0 // breaks at: the joint under brick ").get_slice(" ", 0)
		var started: int = Time.get_ticks_usec()
		var report: Stability.Report = _weigh(text, name)
		var ms: float = (Time.get_ticks_usec() - started) / 1000.0
		if report == null:
			_check("%s opens and is weighed" % name, false)
			continue
		var keys: Dictionary = _keys(text)
		var judged: Dictionary = _judged(report)
		var falls: bool = bool(judged["falls"])
		# The worst joint, and what each stud of it needs to hold.
		var worst: Balance.JointLoad = judged["worst"]
		var where: String = str(keys.get(worst.beyond, "?")) if worst != null else ""
		print("  %-21s built: %-7s  check: %-12s status bar: %-28s %5.1f ms" % [name,
			"stands" if stood else "falls", "comes apart" if falls else "stands", report.summary(), ms])
		if worst != null:
			print("    worst joint: under brick %s, %d studs into a part %s, %s g past it, %s N·cm about "
				% [where, worst.studs, _width(worst), Balance.tidy(worst.grams), Balance.tidy(worst.moment)]
				+ "its edge: %.2f N a stud to hold; it lets go at %.2f" % [_needs(worst), _lets_go(worst)])
		for risk: Stability.Risk in report.risks:
			if risk.kind != "levered":
				print("    %s: %s" % [risk.kind, risk.message])
		# What really came down: the brick it broke under and all it held up.
		var came_down: Dictionary = {}
		var weighed: bool = true
		if not stood:
			var at: Variant = keys.find_key(broke)
			weighed = at != null and report.margins.has(at)
			if weighed:
				came_down = _past(report.margins[at])
			else:
				print("    the joint it broke at is not one the check weighs")
		var said: Dictionary = judged["down"]
		var own_right: int = 0
		var own: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			if keys.has(brick.id):
				own += 1
				if weighed and came_down.has(brick.id) == (bool(judged["all"]) or said.has(brick.id)):
					own_right += 1
		bricks += own
		bricks_right += own_right
		if name.begins_with("stair_") and not name.ends_with("_good"):
			stairs += own
			stairs_right += own_right
		print("    %d of %d bricks as built: %d came down, the check brings down %d" % [own_right, own,
			came_down.size(), own if bool(judged["all"]) else said.size()])
		for id: Variant in report.margins:
			var one: Balance.JointLoad = report.margins[id]
			if one.kind != "studs" or one.capacity <= 0.0:
				continue
			var wide: String = _width(one)
			if lets_go.has(wide) and absf(float(lets_go[wide]) - _lets_go(one)) > 0.001:
				_check("every joint into a part %s lets go at one load (%.2f N, %.2f N here)"
					% [wide, float(lets_go[wide]), _lets_go(one)], false)
			lets_go[wide] = _lets_go(one)
			if stood:
				low[wide] = maxf(float(low.get(wide, 0.0)), _needs(one))
			elif str(keys.get(one.beyond, "")) == broke:
				high[wide] = minf(float(high.get(wide, INF)), _needs(one))
		var ok: bool = falls == (not stood) and own_right == own
		if not stood:
			ok = ok and where == broke
		if ok:
			right += 1
		_check("%s judged as it was built (%s%s)" % [name, "stands" if stood else "falls",
			"" if stood else ", at the joint under brick %s; the check says under %s" % [broke, where]], ok)
	print("  %d of %d judged as built; %d of %d bricks; the stairs of 19 and 20, %d of %d bricks"
		% [right, BUILT_FILES.size(), bricks_right, bricks, stairs_right, stairs])
	for wide: String in ["wider", "a stud wide"]:
		if not lets_go.has(wide):
			continue
		var most: float = float(low.get(wide, 0.0))
		var least: float = float(high.get(wide, INF))
		print("  into a part %s, the builds allow a stud to let go at more than %.2f N (the most a "
			% [wide, most] + "standing one needs) and less than %.2f N (the least a fallen one needed "
			% least + "where it broke)")
		_check("into a part %s, the check lets go at %.2f N, between them" % [wide, float(lets_go[wide])],
			float(lets_go[wide]) > most and float(lets_go[wide]) < least)


## The car the app opens at its start: the status bar still says it stands
## up whatever the clutch where a stud lets go is (APP_UX8 #4's bar).
func _car() -> void:
	print("\nThe car:")
	var report: Stability.Report = _weigh(FileAccess.get_file_as_string(CAR), "car")
	var said: String = report.summary() if report != null else "(did not open)"
	_check("the status bar says the car %s" % said, said == "stands up")


## StableText2Brick's sample, brick by brick against its scores.
func _sample() -> void:
	print("\nStableText2Brick's sample, its scores computed by StableLego's analysis:")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE + "scores.json"))
	if not parsed is Dictionary:
		_check("the sample's scores read", false)
		return
	var structures: Dictionary = (parsed as Dictionary)["structures"]
	var ids: Array = structures.keys()
	ids.sort()
	var rows: Dictionary = {}     ## sample -> [structures, bricks, alarms, structures with any, weak]
	var stressed_bricks: int = 0  ## bricks scored under 0.5
	var stressed_weak: int = 0    ## of those, past the working load by the check
	var weak_bricks: int = 0      ## bricks past the working load by the check
	var weak_unstressed: int = 0  ## of those, scored 0.5 or more
	var slowest: float = 0.0
	var whole_alarms: Dictionary = {}  ## kind -> structures
	for id: String in ids:
		var entry: Dictionary = structures[id]
		var scores: Array = entry["scores"]
		var text: String = FileAccess.get_file_as_string(SAMPLE + id + ".ldr")
		var started: int = Time.get_ticks_usec()
		var report: Stability.Report = _weigh(text, id)
		slowest = maxf(slowest, (Time.get_ticks_usec() - started) / 1000.0)
		if report == null:
			_check("%s opens and is weighed" % id, false)
			continue
		var order: Dictionary = _order(text)
		var plate: Vector3 = _plate()
		var judged: Dictionary = _judged(report)
		var row: Array = rows.get(entry["sample"], [0, 0, 0, 0, 0])
		row[0] += 1
		var alarms: int = 0
		for brick: BrickWorld.Brick in _world.bricks():
			var place: String = _at(brick.transform.origin - plate)
			if not order.has(place):
				continue
			var n: int = order[place]
			if n < 0:
				continue
			var score: float = float(scores[n])
			row[1] += 1
			var flagged: bool = bool(judged["all"]) or (judged["down"] as Dictionary).has(brick.id)
			if flagged and score > 0.0:
				alarms += 1
			var weak: bool = (judged["weak"] as Dictionary).has(brick.id)
			if score < 0.5:
				stressed_bricks += 1
				if weak:
					stressed_weak += 1
			if weak:
				weak_bricks += 1
				if score >= 0.5:
					weak_unstressed += 1
		row[2] += alarms
		if alarms > 0:
			row[3] += 1
			for risk: Stability.Risk in report.risks:
				whole_alarms[risk.kind] = int(whole_alarms.get(risk.kind, 0)) + 1
		if not report.is_stable():
			row[4] += 1
		rows[entry["sample"]] = row
	var total: Array = [0, 0, 0, 0, 0]
	for sample: String in ["hashed", "stressed"]:
		var row: Array = rows.get(sample, [0, 0, 0, 0, 0])
		for k: int in 5:
			total[k] += row[k]
		_agreement(sample, row)
	_agreement("both", total)
	print("  false alarms by what the check said: %s" % str(whole_alarms))
	print("  bricks they score under 0.5 (half a contact's clutch used): %d; past the working load "
		% stressed_bricks + "by the check: %d. Bricks past the working load: %d, of them scored 0.5 or more: %d"
		% [stressed_weak, weak_bricks, weak_unstressed])
	print("  the slowest weighing: %.0f ms" % slowest)
	var agree: float = 1.0 - float(total[2]) / maxf(float(total[1]), 1.0)
	_check("%s of %d bricks agree with StableText2Brick's scores (%d false alarms), at least %d%%"
		% [_pct(agree), int(total[1]), int(total[2]), roundi(AGREE * 100.0)], agree >= AGREE)


func _agreement(sample: String, row: Array) -> void:
	var agree: float = 1.0 - float(row[2]) / maxf(float(row[1]), 1.0)
	print("  %-9s %3d structures, %5d bricks: %s agree, %d false alarms in %d structures; "
		% [sample, int(row[0]), int(row[1]), _pct(agree), int(row[2]), int(row[3])]
		+ "the status bar says weak joints on %d" % int(row[4]))


## The model in [param text] opened as a person opens a file, and weighed as
## the status bar weighs it (Main.weigh_joints). Null when it did not open.
func _weigh(text: String, name: String) -> Stability.Report:
	var opened: Dictionary = _store.open_text(text, name)
	if not str(opened.get("error", "")).is_empty() or int(opened.get("placed", 0)) <= 0:
		print("  %s did not open: %s" % [name, str(opened.get("error", ""))])
		return null
	var judge := Stability.new()
	judge.library = _library
	judge.with_margins = true
	judge.floor_ids = _store.scenery.duplicate()
	judge.lattice = _builder.lattice
	return judge.check(_world)


## What the check says of each brick: {"falls": whether anything comes apart,
## "all": a whole-model fall (every brick goes), "down": id -> true for each
## brick that comes down, past a joint that lets go or tipping off a touch,
## "weak": id -> true for each past its working load (the status bar's),
## "worst": the joint nearest letting go}.
func _judged(report: Stability.Report) -> Dictionary:
	var down: Dictionary = {}
	var weak: Dictionary = {}
	var all: bool = false
	var worst: Balance.JointLoad = null
	for id: Variant in report.margins:
		var one: Balance.JointLoad = report.margins[id]
		if one.ultimate > 0.0 and one.moment > one.ultimate:
			down.merge(_past(one))
		if worst == null or one.moment / maxf(one.ultimate, 0.000001) \
				> worst.moment / maxf(worst.ultimate, 0.000001):
			worst = one
	for piece: Dictionary in report.tipping:
		for id: Variant in piece.get("ids", []):
			down[int(id)] = true
	for risk: Stability.Risk in report.risks:
		match risk.kind:
			"levered":
				weak[risk.brick_id] = true
			"rests on a touch":
				down[risk.brick_id] = true
				weak[risk.brick_id] = true
			_:
				all = true
	return {"falls": all or not down.is_empty(), "all": all, "down": down, "weak": weak, "worst": worst}


## Everything that comes down when [param one] lets go: the part past it and
## all held to that by studs, short of the part it lets go of, the baseplate
## and the scenery (SelectBy.connected, as a person picks it up).
func _past(one: Balance.JointLoad) -> Dictionary:
	var stop: Dictionary = _store.scenery.duplicate()
	stop[one.held_by] = true
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == PLATE:
			stop[brick.id] = true
	var out: Dictionary = {}
	for id: Variant in SelectBy.connected(_world, _builder.lattice, [one.beyond], stop):
		out[int(id)] = true
	return out


## What each of a joint's studs must hold for it not to let go, N: its
## moment against their levers (the working load is ALLOWABLE_N a stud).
static func _needs(one: Balance.JointLoad) -> float:
	if one == null or one.capacity <= 0.0:
		return 0.0
	return one.moment / one.capacity * Balance.ALLOWABLE_N


## Where the check has each of a joint's studs let go, N.
static func _lets_go(one: Balance.JointLoad) -> float:
	if one == null or one.capacity <= 0.0:
		return 0.0
	return one.ultimate / one.capacity * Balance.ALLOWABLE_N


## How wide the part a joint's studs go into is, "a stud wide" or "wider":
## the part over a flat joint, or the one a part hangs from.
func _width(one: Balance.JointLoad) -> String:
	var into: BrickWorld.Brick = _world.get_brick(one.held_by if one.hangs else one.beyond)
	var mesh: Lbm.PartMesh = _library.mesh_for(into.part_id) if into != null else null
	if mesh != null and minf(mesh.bounds.size.x, mesh.bounds.size.z) < 30.0:
		return "a stud wide"
	return "wider"


## Each world brick's key in the source ("0 // brick K" before its line), by
## where it stands.
func _keys(text: String) -> Dictionary:
	var by_place: Dictionary = {}
	var key: String = ""
	var plate_line: Vector3 = _line_at(_plate_line(text))
	for line: String in text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("0 // brick "):
			key = line.trim_prefix("0 // brick ").get_slice(":", 0)
		elif line.begins_with("1 ") and not line.ends_with(PLATE + ".dat"):
			by_place[_at((_line_at(line) - plate_line) * LdrModel.FLIP)] = key
	var out: Dictionary = {}
	var plate: Vector3 = _plate()
	for brick: BrickWorld.Brick in _world.bricks():
		var place: String = _at(brick.transform.origin - plate)
		if by_place.has(place):
			out[brick.id] = by_place[place]
	return out


## Each brick line's place -> its index among the file's bricks; -1 for the
## baseplate.
func _order(text: String) -> Dictionary:
	var out: Dictionary = {}
	var n: int = 0
	var plate_line: Vector3 = _line_at(_plate_line(text))
	for line: String in text.split("\n"):
		line = line.strip_edges()
		if not line.begins_with("1 ") or line.ends_with(PLATE + ".dat"):
			continue
		out[_at((_line_at(line) - plate_line) * LdrModel.FLIP)] = n
		n += 1
	return out


## The baseplate's line in [param text].
static func _plate_line(text: String) -> String:
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("1 ") and line.strip_edges().ends_with(PLATE + ".dat"):
			return line.strip_edges()
	return "1 0 0 0 0"


## Where the baseplate stands in the world, model or scenery: each brick is
## found by where it stands from it, however the store laid the model down.
func _plate() -> Vector3:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == PLATE:
			return brick.transform.origin
	return Vector3.ZERO


static func _line_at(line: String) -> Vector3:
	var f: PackedStringArray = line.split(" ", false)
	return Vector3(float(f[2]), float(f[3]), float(f[4]))


static func _at(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 2.0), roundi(v.y * 2.0), roundi(v.z * 2.0)]


static func _pct(share: float) -> String:
	return "%.1f%%" % (share * 100.0)


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
