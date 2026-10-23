## Does a body said as a solid come out round, whole and held?
##
##   godot --headless --path . --script src/dev/sculpt_probe.gd [-- OUTDIR]
##
## A design says a rounded body as solids ({"pattern": "sculpt"}: an
## ellipsoid, an egg, a capsule, a superellipsoid, or several joined) and
## Brickify lays it (Sculpt). Laid by hand course by course, bench164's potato
## and rabbit kept one width up 94% and 100% of their height and the judge
## read a can and a stack of drums. So for each body here: it is laid, it is
## one piece and passes the check (nothing only resting where no stud holds
## it, connect166's rule), it is where its solids say, and seen from the side
## it swells and narrows: the share of its height within a stud of its widest
## (taper165's measure) is a round's, under 0.75 both across and deep. With
## OUTDIR each is written there as NAME.ldr to look at.
extends SceneTree

const Side := preload("res://src/dev/side_profile.gd")

## Held-out bodies, none of them the bench's six: what each is, the sculpt.
const BODIES: Array = [
	["egg upright", {"pattern": "sculpt", "color": 70,
		"solids": [{"egg": {"centre": [6, 12, 6], "size": [10, 24, 9], "point": "+y"}}]}],
	["pig", {"pattern": "sculpt", "color": 29, "solids": [
		{"superellipsoid": {"centre": [8, 11, 6], "size": [15, 22, 11], "power": 2.6}},
		{"ellipsoid": {"centre": [16, 15, 6], "size": [7, 17, 8]}}]}],
	["small ball", {"pattern": "sculpt", "color": 4, "solids": [
		{"ellipsoid": {"centre": [4, 9, 4], "size": [8, 18, 7]}}]}],
	["pear", {"pattern": "sculpt", "color": 27, "solids": [
		{"ellipsoid": {"centre": [6, 11, 6], "size": [11, 22, 11]}},
		{"egg": {"centre": [6, 26, 6], "size": [7, 18, 7], "point": "+y"}}]}],
	["whale", {"pattern": "sculpt", "color": 272, "solids": [
		{"egg": {"centre": [11, 9, 6], "size": [22, 18, 11], "point": "-x"}}]}],
	["snowman", {"pattern": "sculpt", "color": 15, "solids": [
		{"ellipsoid": {"centre": [6, 10, 6], "size": [11, 20, 11]}},
		{"ellipsoid": {"centre": [6, 26, 6], "size": [8, 17, 8]}},
		{"ellipsoid": {"centre": [6, 38, 6], "size": [6, 13, 6]}}]}],
]

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _checker: Assistant
var _store: ModelStore


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else ""
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("FAIL: no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = _world
	_checker.builder = _builder
	root.add_child(_checker)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	for library_part: String in Brickify.parts_needed(_library):
		_library.mesh_for(library_part)
	for body: Array in BODIES:
		await _body(str(body[0]), body[1], out)
	print("")
	print("sculpt_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _body(name: String, raw: Dictionary, out: String) -> void:
	print("")
	print("  %s" % name)
	var trouble: Array = []
	var t0: int = Time.get_ticks_msec()
	var laid: Dictionary = Sculpt.lay(raw, _checker, trouble)
	var ms: int = Time.get_ticks_msec() - t0
	_check("laid, %d parts in %d ms%s" % [int(laid.get("parts", 0)), ms,
		"" if trouble.is_empty() else ": " + "; ".join(PackedStringArray(trouble))],
		not laid.is_empty() and trouble.is_empty())
	if laid.is_empty():
		return
	print("    %s" % laid["said"])
	var model := Assistant.Model.new()
	model.name = name
	for brick: Dictionary in laid["bricks"]:
		model.placements.append(Assistant.Placement.from_dict(brick))
	var report: Dictionary = _checker._check(model, true, true, true)
	_check("one piece and it passes the check (%s)" % _faults(report),
		bool(report.get("ok", false)) and int(report.get("pieces", 0)) <= 1)
	_check("nothing only rests where no stud holds it",
		(report.get("come_away", []) as Array).is_empty()
		and (report.get("unheld", []) as Array).is_empty())
	# Where its solids say: the box of the solids, a stud either way.
	var solids: Array = Sculpt.solids_of(raw, [])
	var want := AABB()
	for n: int in solids.size():
		var solid: Dictionary = solids[n]
		var box := AABB(solid["centre"] - solid["half"], solid["half"] * 2.0)
		want = box if n == 0 else want.merge(box)
	var got: AABB = laid["box"]
	_check("where its solids are: x %s-%s y %s-%s z %s-%s against %s-%s, %s-%s, %s-%s" % [
		_n(got.position.x), _n(got.end.x), _n(got.position.y), _n(got.end.y), _n(got.position.z),
		_n(got.end.z), _n(want.position.x), _n(want.end.x), _n(want.position.y), _n(want.end.y),
		_n(want.position.z), _n(want.end.z)],
		absf(got.get_center().x - want.get_center().x) <= 1.0
		and absf(got.get_center().z - want.get_center().z) <= 1.0
		and absf(got.position.y - want.position.y) <= 2.5)
	_checker._apply(model)
	for _n: int in 3:
		await process_frame
	var covers: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		covers.append(_builder.lattice.boxes_of(brick.id))
	var rows: Array = Side.courses(covers)
	for axis: int in 2:
		var share: Array = full_width_share(rows, axis)
		_check("%s: %s; widest %d for %d of %d courses (%d%%)" % ["across x" if axis == 0
			else "deep along z", share[3], int(share[0]), int(share[1]), int(share[2]),
			roundi(float(share[1]) * 100.0 / maxf(1.0, float(share[2])))],
			float(share[1]) < 0.75 * float(share[2]))
	var straight: String = Side.said(rows)
	_check("taper165's check is quiet on it", straight.is_empty())
	if not out.is_empty():
		_store.export_to(out.path_join(name.replace(" ", "_") + ".ldr"), name)
	_world.clear()
	_builder.lattice.clear()
	_checker.forget_built()


## The body's share of its height at full width, seen across (axis 0) or deep
## (1): [widest, courses within a stud of it, courses, widths by sixths]. The
## body is the tallest run of courses that continue one another.
static func full_width_share(rows: Array, axis: int) -> Array:
	var best := Vector2i(0, -1)
	var start: int = 0
	for n: int in range(1, rows.size() + 1):
		if n == rows.size() or not Side._continues(rows[n - 1], rows[n]):
			if n - start > best.y - best.x + 1:
				best = Vector2i(start, n - 1)
			start = n
	if best.y < best.x:
		return [0, 0, 0, ""]
	var held: Array = Side.held_widths(rows, axis)
	var widest: int = 0
	for n: int in range(best.x, best.y + 1):
		widest = maxi(widest, int(held[n]))
	var full: int = 0
	for n: int in range(best.x, best.y + 1):
		if int(held[n]) >= widest - 1:
			full += 1
	var sixths: Array = Side.widths_by_sixths(held, best.x, best.y)
	return [widest, full, best.y - best.x + 1, "by sixths %s" % ", ".join(PackedStringArray(
		sixths.map(func(v: Variant) -> String: return str(v))))]


func _faults(report: Dictionary) -> String:
	var kinds: Array = report.get("kinds", [])
	return "%d piece(s)%s" % [int(report.get("pieces", 0)),
		"" if kinds.is_empty() else ", " + ", ".join(PackedStringArray(kinds))]


static func _n(value: float) -> String:
	return Shapes._num(value)


func _check(what: String, ok: bool) -> void:
	print("    %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
