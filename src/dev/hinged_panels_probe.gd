## Can a model hold parts turned any way, each held by a real hinge?
##
##   godot --headless --path . --script src/dev/hinged_panels_probe.gd
##
## The owner's Claude, building over MCP, could not make a smooth
## hemisphere. A section turned about one axis only, so its dome panels
## faced four ways and made a pyramid; and a turned panel could not sit on
## studs, which is right — in plastic a turned panel is held by a hinge, a
## clip or a ball. Real sets build a big sphere as small flat panels on
## hinges, no two at the same angle (10143's shell; 21332), and a round band
## as skins built sideways on brackets (the BB-8 sets). This builds both as a
## design would say them and asks the check whether they hold.
##
## And whether the shell is closed. The first domes held, and from four sides
## read as a cage: daylight between the strips and a stud of it between the
## bands. So rays go out from the shell's centre every quarter degree, and
## the widest one that meets no part, across a band or between two, is the
## gap a person sees through. -- --measure=DESIGN.json,X,Y,Z,R measures a
## design written out by another build (its centre and radius in LDU);
## -- --shells lays and judges the shells alone.
extends SceneTree

## The widest see-through gap the probe lets pass, LDU, and the most of the
## shell open. The aim is half a plate (4 LDU), what a builder would let
## pass, and it is not met: slivers stay at the seams between bands and under
## the panels near the pole, a stud and a fifth at the widest, and this holds
## the shells there so they get no worse. 4042e8f's dome: 150.7 LDU, 19.9%.
const MOST_GAP := 24.0
const MOST_OPEN := 0.03

var _failures: int = 0
var _assistant: Assistant
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = world
	_assistant.builder = builder
	get_root().add_child(_assistant)
	await process_frame

	var only_shells: bool = false
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--measure="):
			_measure(one.trim_prefix("--measure="))
			quit(0)
			return
		only_shells = only_shells or one == "--shells"
	if only_shells:
		_dome()
	else:
		_turns()
		_hinges()
		_turned_on_studs()
		_dome()
		_band()
		await _edits(world)
		_window(world, builder)

	print("")
	print("%s: %d failure%s" % ["PASS" if _failures == 0 else "FAIL", _failures,
		"" if _failures == 1 else "s"])
	quit(0 if _failures == 0 else 1)


# -- turned any way --------------------------------------------------------


func _turns() -> void:
	print("  a section turned on two axes and three")
	for want: Vector3 in [Vector3(30, 20, 0), Vector3(-75, 41, 0), Vector3(110, -15, 25)]:
		var model: Assistant.Model = _assistant._read_model({
			"sections": [{"name": "panel", "x": 4, "y": 6, "z": 4, "yaw": want.x,
				"pitch": want.y, "roll": want.z}],
			"bricks": [{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0,
				"section": "panel"}]})
		var got: Vector3 = Assistant.Section.angles_of(_pose(model, 0).basis)
		_check("yaw %s, pitch %s, roll %s is what the brick is turned: %s" % [want.x, want.y,
			want.z, got], got.distance_to(want) < 0.01)
	# The nose is +z: yaw swings it towards +x, pitch lifts it.
	var nose: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "n", "x": 0, "y": 0, "z": 0, "yaw": 90, "pitch": 30}],
		"bricks": [{"part": "3024", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0,
			"section": "n"}]})
	var forward: Vector3 = nose.sections["n"].placed().basis * Vector3.BACK
	_check("yaw 90 points the nose along +x and pitch 30 lifts it: %s" % forward,
		forward.x > 0.85 and forward.y > 0.45)
	# An axis and an angle, as a direction.
	var line: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "l", "x": 0, "y": 0, "z": 0, "line": [1, 1, 0], "degrees": 40}],
		"bricks": [{"part": "3024", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0,
			"section": "l"}]})
	var turned: Basis = line.sections["l"].placed().basis
	_check("a turn about the direction [1, 1, 0] keeps that direction",
		(turned * Vector3(1, 1, 0).normalized()).distance_to(Vector3(1, 1, 0).normalized()) < 0.001)

	print("")
	print("  one part turned on its own")
	var single: Assistant.Model = _assistant._read_model({"bricks": [
		{"part": "3001", "color": 4, "x": 2, "y": 0, "z": 3, "rot": 0, "yaw": 25,
			"pitch": 10}]})
	var placement: Assistant.Placement = single.placements[0]
	_check("it becomes a section of one, '%s'" % placement.section,
		not placement.section.is_empty() and single.sections.has(placement.section))
	var alone: Assistant.Section = single.sections.get(placement.section)
	_check("turned as asked, about its corner: %s" % (alone.said() if alone != null else "none"),
		alone != null and Assistant.Section.angles_of(_pose(single, 0).basis).distance_to(
			Vector3(25, 10, 0)) < 0.01 and alone.placed().origin.is_equal_approx(Vector3(40, 0, 60))
			and is_zero_approx(placement.x) and is_zero_approx(placement.z))

	print("")
	print("  a section within a section")
	var nested: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "arm", "x": 0, "y": 0, "z": 0, "yaw": 45},
			{"name": "hand", "within": "arm", "x": 0, "y": 0, "z": 4, "pitch": 30}],
		"bricks": [{"part": "3024", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0,
			"section": "hand"}]})
	var hand: Vector3 = Assistant.Section.angles_of(_pose(nested, 0).basis)
	_check("goes where its parent goes and turns with it: %s" % hand,
		hand.distance_to(Vector3(45, 30, 0)) < 0.01)
	var origin: Vector3 = nested.sections["hand"].placed().origin
	var expect: Vector3 = Basis(Vector3.UP, deg_to_rad(45)) * Vector3(0, 0, 80)
	_check("its origin is in its parent's coordinates: %s" % origin,
		origin.distance_to(expect) < 0.01)

	print("")
	print("  a section repeated round a centre")
	var ring: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "spoke", "x": 10, "y": 0, "z": 16, "yaw": 0, "pitch": 15}],
		"bricks": [{"part": "3024", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0,
			"section": "spoke"}],
		"repeat_section": [{"from": "spoke", "times": 3, "around": {"x": 10, "z": 10},
			"yaw": 90}]})
	var radii := PackedFloat32Array()
	var yaws := PackedFloat32Array()
	for name: String in ["spoke", "spoke 2", "spoke 3", "spoke 4"]:
		var section: Assistant.Section = ring.sections.get(name)
		if section == null:
			continue
		var at: Vector3 = section.placed().origin
		radii.append(Vector2(at.x - 200.0, at.z - 200.0).length())
		yaws.append(Assistant.Section.angles_of(section.placed().basis).x)
	_check("four copies, each the same distance from the centre: %s" % radii,
		radii.size() == 4 and absf(radii[0] - radii[3]) < 0.01 and absf(radii[0] - 120.0) < 0.01)
	_check("each turned a quarter further, keeping its pitch: %s" % yaws,
		yaws.size() == 4 and absf(fposmod(yaws[1] - yaws[0], 360.0) - 90.0) < 0.01)


# -- held by a hinge -------------------------------------------------------


func _hinges() -> void:
	print("")
	print("  a panel turned two ways, held by its hinge")
	# The base on one round stud, as a part that swivels stands, so turned
	# any way round nothing is under the joint but air.
	for kind: String in Hinges.KINDS:
		if not Hinges.available(kind, _library):
			print("     (%s: this build's parts do not say where its joint is)" % kind)
			continue
		for angles: Vector2 in [Vector2(33, 40), Vector2(-120, 65), Vector2(200, 15)]:
			var model: Assistant.Model = _assistant._read_model({
				"sections": [{"name": "flap", "x": 6, "y": 4, "z": 6, "yaw": angles.x,
					"pitch": angles.y, "hinge": kind}],
				"bricks": [
					{"part": "3958", "color": 72, "x": 4, "y": 0, "z": 4, "rot": 0},
					{"part": "3062b", "color": 72, "x": 6, "y": 1, "z": 6, "rot": 0},
					{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 1,
						"section": "flap"},
					{"part": "3068b", "color": 15, "x": 0, "y": 1, "z": 0, "rot": 0,
						"section": "flap"}]})
			var verdict: Dictionary = _assistant._check(model, true)
			_check("on a %s hinge at yaw %d, pitch %d: %s" % [kind, int(angles.x),
				int(angles.y), verdict["summary"]], bool(verdict["ok"]))
			if not bool(verdict["ok"]):
				print("     %s" % str(verdict["feedback"]).replace("\n", " ").substr(0, 500))
	# Without the hinge the same panel sits at a slant on studs it cannot
	# take, and is refused for it.
	var bare: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "flap", "x": 6, "y": 1, "z": 6, "yaw": 33, "pitch": 40}],
		"bricks": [
			{"part": "3958", "color": 72, "x": 4, "y": 0, "z": 4, "rot": 0},
			{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 1,
				"section": "flap"}]})
	_check("and with no hinge it is refused as leaning on nothing",
		str(_assistant._check(bare, true)["feedback"]).contains("leaning on nothing"))
	# A one-line hinge tipped two ways is said, not quietly laid one way.
	var both: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "flap", "x": 6, "y": 1, "z": 6, "pitch": 20, "roll": 10,
			"hinge": Hinges.TILTING}],
		"bricks": [{"part": "3958", "color": 72, "x": 4, "y": 0, "z": 4, "rot": 0},
			{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 1, "section": "flap"}]})
	_check("a hinge asked for a pitch and a roll is told it turns one way",
		str(_assistant._check(both, true)["feedback"]).contains("turns about one line"))


# -- turned about the upright, on studs ---------------------------------------


## A part turned off the square about the upright grips by one stud with
## nothing else under it. Turning about the upright was let through as a part
## on one stud swivels, and a 2 x 4 turned thirty degrees on a plate was
## called buildable on studs that meet its tubes and walls.
func _turned_on_studs() -> void:
	print("")
	print("  a part turned about the upright, on studs")
	# Turned about its corner, so a 1 x 2's first socket lands on the stud at
	# (2.5, 2.5) when its corner is that less the turned half stud.
	var swing: Vector3 = Basis(Vector3.UP, deg_to_rad(30)) * Vector3(0.5, 0, 0.5)
	var on_one := Vector2(2.5 - swing.x, 2.5 - swing.z)
	var cases: Array = [
		["a 2 x 4 turned 30 degrees on a plate", false, [
			{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 2, "y": 1, "z": 2, "rot": 0, "yaw": 30}]],
		["a 1 x 2 turned 30 degrees about one of a plate's studs", false, [
			{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3023b", "color": 4, "x": on_one.x, "y": 1, "z": on_one.y, "rot": 0,
				"yaw": 30}]],
		["the same 1 x 2 on a round plate's one stud", true, [
			{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "6141", "color": 72, "x": 2, "y": 1, "z": 2, "rot": 0},
			{"part": "3023b", "color": 4, "x": on_one.x, "y": 2, "z": on_one.y, "rot": 0,
				"yaw": 30}]],
		["on a jumper's centre stud", true, [
			{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3794b", "color": 72, "x": 2, "y": 1, "z": 2, "rot": 0},
			{"part": "3023b", "color": 4, "x": on_one.x + 0.5, "y": 2, "z": on_one.y, "rot": 0,
				"yaw": 30}]],
		["hung under a round plate's one stud", true, [
			{"part": "3941", "color": 72, "x": 2, "y": 0, "z": 2, "rot": 0},
			{"part": "3958", "color": 72, "x": 0, "y": 3, "z": 0, "rot": 0},
			{"part": "6141", "color": 72, "x": 0, "y": 2, "z": 0, "rot": 0},
			{"part": "3023b", "color": 4, "x": on_one.x - 2, "y": 1, "z": on_one.y - 2,
				"rot": 0, "yaw": 30}]],
		["a 2 x 4 turned a quarter, square on its studs", true, [
			{"part": "3958", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 2, "y": 1, "z": 2, "rot": 0, "yaw": 90}]],
	]
	for one: Array in cases:
		var verdict: Dictionary = _assistant._check(_assistant._read_model({"bricks": one[2]}),
			true)
		var refused: bool = str(verdict["feedback"]).contains("grip nothing")
		_check("%s: %s" % [one[0], "holds" if bool(verdict["ok"]) else "refused"],
			bool(verdict["ok"]) if bool(one[1]) else refused)
		if bool(one[1]) != bool(verdict["ok"]):
			print("     %s" % str(verdict["feedback"]).replace("\n", " ").substr(0, 400))


# -- a dome of hinged panels -----------------------------------------------


## The kind the dome hangs on: click hinge plates where the parts have them,
## a clip on a bar otherwise.
func _dome_kind() -> String:
	return Hinges.CLICK if Hinges.available(Hinges.CLICK, _library) else Hinges.CLIP


func _dome() -> void:
	print("")
	print("  a hinged-panel dome 24 studs across, said as one shell")
	_judge({"pattern": "shell", "kind": "dome", "across": 24, "at": {"x": 20, "y": 0, "z": 20},
		"color": 71}, "--dome_ldr=", "Hinged dome")
	print("")
	print("  and one 32 across: more bands, every other strip stopping near the top")
	_judge({"pattern": "shell", "kind": "dome", "across": 32, "at": {"x": 30, "y": 0, "z": 30},
		"color": 15}, "--big_ldr=", "Hinged dome 32")
	print("")
	print("  and a ball 28 across on a stand: the same strips hung below the ring")
	_judge({"pattern": "shell", "kind": "ball", "across": 28, "at": {"x": 20, "y": 0, "z": 20},
		"color": 1}, "--ball_ldr=", "Hinged ball")
	var trouble: Array = []
	Shells.lay({"pattern": "shell", "kind": "ball", "across": 16}, _assistant._shell_hinge(),
		trouble)
	_check("a ball 16 across is refused, and pointed at skins: %s" % trouble,
		not trouble.is_empty() and str(trouble[0]).contains("skins"))
	trouble.clear()
	Shells.lay({"pattern": "shell", "kind": "dome", "across": 16}, _assistant._shell_hinge(),
		trouble)
	_check("a dome 16 across, where no band of twelve fits, is refused and pointed at the "
		+ "smooth dome: %s" % trouble, not trouble.is_empty()
		and str(trouble[0]).contains("smooth dome"))
	trouble.clear()
	Shells.lay({"pattern": "shell", "kind": "dome", "across": 40}, _assistant._shell_hinge(),
		trouble)
	_check("a dome 40 across, past what holds yet, is refused saying so: %s" % trouble,
		not trouble.is_empty() and str(trouble[0]).contains("not built yet"))


## A shell put to the check: every hinge's halves joined, the panels at many
## two-axis angles, held with nothing overlapping, and closed — no gap a
## person sees through wider than MOST_GAP, no more than MOST_OPEN of it.
## Written out where -- [param flag]PATH asks, and the design itself where
## --design=PATH does.
func _judge(pattern: Dictionary, flag: String, title: String) -> void:
	var trouble: Array = []
	var laid: Dictionary = Shells.lay(pattern, _assistant._shell_hinge(), trouble)
	_check("laid as asked: %s" % (str(laid.get("said", "")) if trouble.is_empty() else trouble),
		trouble.is_empty() and not laid.is_empty())
	if laid.is_empty():
		return
	var model: Assistant.Model = _assistant._read_model({"patterns": [pattern]})
	var verdict: Dictionary = _assistant._check(model, true)
	print("     %s" % str(verdict["feedback"]).replace("\n", " ").substr(0,
		600 if bool(verdict["ok"]) else 3000))
	for index: Variant in verdict.get("overlapping", {}):
		var placement: Assistant.Placement = model.placements[int(index)]
		var hit: int = int(verdict["overlapping"][index]) - 1
		var other: Assistant.Placement = model.placements[hit] if hit >= 0 \
			and hit < model.placements.size() else null
		print("       overlapping: %d %s in '%s' at %s, with %d %s in '%s' at %s" % [index,
			placement.part, placement.section, placement.where(), hit,
			other.part if other != null else "?", other.section if other != null else "?",
			other.where() if other != null else "?"])
	# Each hinge's two halves, joined by the check's own rule.
	var rounds: Dictionary = Joints.rounds(_assistant._mating_entries(model))
	var unjoined := PackedStringArray()
	var hinged: int = 0
	for name: String in model.sections:
		var section: Assistant.Section = model.sections[name]
		if not section.hinge:
			continue
		hinged += 1
		var held: bool = false
		for index: int in model.placements.size():
			if model.placements[index].section != name:
				continue
			for other: Variant in rounds.get(index, {}):
				if model.placements[int(other)].section != name:
					held = true
		if not held:
			unjoined.append(name)
	_check("all %d hinges' halves joined, %d not: %s" % [hinged, unjoined.size(),
		", ".join(unjoined)], unjoined.is_empty() and hinged >= 24)
	var angles: Dictionary = {}
	for index: int in model.placements.size():
		var section: Assistant.Section = model.section_for(model.placements[index])
		if section != null and section.hinge:
			var turn: Vector3 = Assistant.Section.angles_of(_pose(model, index).basis)
			angles["%d %d" % [roundi(fposmod(turn.x, 360.0)), roundi(turn.y)]] = true
	_check("panels at %d different two-axis angles" % angles.size(), angles.size() >= hinged)
	_check("every panel held by its hinge, nothing overlapping: %s" % verdict["summary"],
		bool(verdict["ok"]))
	var gaps: Dictionary = _gaps(model, laid["centre"], float(laid["radius"]),
		float(laid["open_below"]) + 2.0 if pattern["kind"] == "ball" else -4.0)
	_check("closed: the widest gap between panels in a band %.1f LDU (at %s), between "
		% [gaps["band"], gaps["band at"]] + "bands %.1f (at %s), %.2f%% open; at most %.0f, %.0f%%"
		% [gaps["bands"], gaps["bands at"], 100.0 * float(gaps["open"]), MOST_GAP,
			100.0 * MOST_OPEN], _closed(gaps))
	print("     open, every five degrees up from its foot: %s" % gaps["by latitude"])
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--design="):
			var file := FileAccess.open(one.trim_prefix("--design="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify({"patterns": [pattern]}, "\t"))
				file.close()
	_write_out(model, flag, title)


## A design written out by another build, measured as a shell: "path, x, y,
## z, radius", its centre and radius in LDU.
func _measure(said: String) -> void:
	var parts: PackedStringArray = said.split(",")
	var design: Variant = JSON.parse_string(FileAccess.get_file_as_string(parts[0]))
	if not design is Dictionary or parts.size() < 5:
		print("  cannot read %s" % said)
		return
	var model: Assistant.Model = _assistant._read_model(design)
	var gaps: Dictionary = _gaps(model, Vector3(float(parts[1]), float(parts[2]),
		float(parts[3])), float(parts[4]), -4.0)
	_check("%s: the widest gap between panels in a band %.1f LDU (at %s), between bands "
		% [parts[0].get_file(), gaps["band"], gaps["band at"]] + "%.1f (at %s), %.2f%% open"
		% [gaps["bands"], gaps["bands at"], 100.0 * float(gaps["open"])], _closed(gaps))


static func _closed(gaps: Dictionary) -> bool:
	return float(gaps["band"]) <= MOST_GAP and float(gaps["bands"]) <= MOST_GAP \
		and float(gaps["open"]) <= MOST_OPEN


## The see-through gaps in a shell round [param centre], [param radius] LDU
## out: a ray every quarter degree from latitude [param lat_from] (a dome's
## ring, the edge of a ball's opening round its stand) to the pole, each
## asked whether it meets a part's cover
## within the shell's thickness. Where one meets none, the gap there is as
## wide as the shorter of its open run along its latitude and along its
## meridian: a slit between two panels of a band is narrow across and long
## up, one between bands the other way. {band, bands: the widest of each, LDU,
## and where, as (latitude, longitude); open: the share of rays that meet
## nothing}.
func _gaps(model: Assistant.Model, centre: Vector3, radius: float, lat_from: float) -> Dictionary:
	var step: float = 0.25
	var lat_to: float = 89.0
	var rows: int = int((lat_to - lat_from) / step)
	var cols: int = int(360.0 / step)
	var hit := PackedByteArray()
	hit.resize(rows * cols)
	# Within the shell's thickness: inside its hinges, outside its high
	# panels' lips and a dome's drum.
	var inner: float = radius - 60.0
	var outer: float = radius + 80.0
	for index: int in model.placements.size():
		var mesh: Lbm.PartMesh = _library.mesh_for(model.placements[index].part)
		if mesh == null:
			continue
		var pose: Transform3D = _pose(model, index)
		var back: Transform3D = pose.affine_inverse()
		var from_here: Vector3 = back * centre
		var boxes: Array[AABB] = []
		for box: AABB in mesh.boxes:
			boxes.append(AABB(box.position * BrickLattice.CELL, box.size * BrickLattice.CELL))
		if boxes.is_empty():
			boxes.append(mesh.bounds)
		for box: AABB in boxes:
			var lo_lat: float = INF
			var hi_lat: float = -INF
			var lons: Array[float] = []
			var flat_lo := Vector2(INF, INF)
			var flat_hi := -Vector2(INF, INF)
			var near: bool = false
			for c: int in 8:
				var corner: Vector3 = pose * (box.position
					+ box.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))
				var rel: Vector3 = corner - centre
				var far: float = rel.length()
				near = near or (far > inner - 40.0 and far < outer + 40.0)
				var lat: float = rad_to_deg(asin(clampf(rel.y / maxf(far, 0.001), -1.0, 1.0)))
				lo_lat = minf(lo_lat, lat)
				hi_lat = maxf(hi_lat, lat)
				lons.append(rad_to_deg(atan2(rel.x, rel.z)))
				flat_lo = flat_lo.min(Vector2(corner.x, corner.z))
				flat_hi = flat_hi.max(Vector2(corner.x, corner.z))
			if not near:
				continue
			var lo_lon: float = lons.min()
			var hi_lon: float = lons.max()
			if hi_lon - lo_lon > 180.0:
				for i: int in lons.size():
					if lons[i] < 0.0:
						lons[i] += 360.0
				lo_lon = lons.min()
				hi_lon = lons.max()
			# A box over the axis spans every longitude, up to the pole.
			if centre.x > flat_lo.x and centre.x < flat_hi.x and centre.z > flat_lo.y \
					and centre.z < flat_hi.y:
				lo_lon = -180.0
				hi_lon = 180.0
				if hi_lat > 0.0:
					hi_lat = 90.0
				else:
					lo_lat = -90.0
			var r0: int = maxi(0, int(floor((lo_lat - lat_from) / step)) - 1)
			var r1: int = mini(rows - 1, int(ceil((hi_lat - lat_from) / step)) + 1)
			var c0: int = int(floor(lo_lon / step)) - 1
			var c1: int = int(ceil(hi_lon / step)) + 1
			for r: int in range(r0, r1 + 1):
				var lat: float = deg_to_rad(lat_from + (r + 0.5) * step)
				for c: int in range(c0, c1 + 1):
					var at: int = r * cols + posmod(c, cols)
					if hit[at] != 0:
						continue
					var lon: float = deg_to_rad((c + 0.5) * step)
					var way := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
					if _meets(from_here, back.basis * way, box, inner, outer):
						hit[at] = 1
	# Each open ray's run along its latitude, LDU, walked from a covered one so
	# a run across longitude 0 counts once.
	var across := PackedFloat32Array()
	across.resize(rows * cols)
	for r: int in rows:
		var each: float = deg_to_rad(step) * radius * cos(deg_to_rad(lat_from + (r + 0.5) * step))
		var start: int = -1
		for i: int in cols:
			if hit[r * cols + i] != 0:
				start = i
				break
		if start < 0:
			for i: int in cols:
				across[r * cols + i] = cols * each
			continue
		var i: int = 0
		while i < cols:
			if hit[r * cols + (start + i) % cols] != 0:
				i += 1
				continue
			var j: int = i
			while j < cols and hit[r * cols + (start + j) % cols] == 0:
				j += 1
			for k: int in range(i, j):
				across[r * cols + (start + k) % cols] = (j - i) * each
			i = j
	var out := {"band": 0.0, "band at": Vector2.ZERO, "bands": 0.0, "bands at": Vector2.ZERO,
		"open": 0.0}
	var open: int = 0
	var each_up: float = deg_to_rad(step) * radius
	for c: int in cols:
		var r: int = 0
		while r < rows:
			if hit[r * cols + c] != 0:
				r += 1
				continue
			var s: int = r
			while s < rows and hit[s * cols + c] == 0:
				s += 1
			var tall: float = (s - r) * each_up
			for k: int in range(r, s):
				open += 1
				var wide: float = across[k * cols + c]
				var gap: float = minf(wide, tall)
				var at := Vector2(snappedf(lat_from + (k + 0.5) * step, 0.01),
					snappedf((c + 0.5) * step, 0.01))
				var key: String = "band" if wide <= tall else "bands"
				if gap > float(out[key]):
					out[key] = snappedf(gap, 0.1)
					out[key + " at"] = at
			r = s
	out["open"] = float(open) / float(rows * cols)
	# Where it is open: the share of rays through, every five degrees up.
	var by_lat := PackedStringArray()
	var per: int = int(5.0 / step)
	for from_row: int in range(0, rows, per):
		var through: int = 0
		var all: int = 0
		for r: int in range(from_row, mini(rows, from_row + per)):
			for c: int in cols:
				all += 1
				through += 1 if hit[r * cols + c] == 0 else 0
		by_lat.append("%d: %.1f%%" % [roundi(lat_from + from_row * step),
			100.0 * through / maxf(all, 1)])
	out["by latitude"] = ", ".join(by_lat)
	return out


## Whether a ray from [param from] along [param way] meets [param box]
## between [param near] and [param far] along it.
static func _meets(from: Vector3, way: Vector3, box: AABB, near: float, far: float) -> bool:
	var t0: float = near
	var t1: float = far
	for axis: int in 3:
		var lo: float = box.position[axis]
		var hi: float = lo + box.size[axis]
		if absf(way[axis]) < 1e-9:
			if from[axis] < lo or from[axis] > hi:
				return false
			continue
		var a: float = (lo - from[axis]) / way[axis]
		var b: float = (hi - from[axis]) / way[axis]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
		if t0 > t1:
			return false
	return true


# -- a band of skins built sideways ----------------------------------------


## A round band the BB-8 way: a core with studs out on four sides, each
## side carrying a skin built flat — plates stepping in as they stack out,
## curved slopes at the rim — and turned to face out.
func _band() -> void:
	print("")
	print("  a band of skins built sideways on bricks with side studs")
	# The core, 4 x 4: a plate, a course of 2 x 2s to stand it up, then a
	# course with a 1 x 2 brick with studs on its side centred on each face,
	# 1 x 1s at the corners and a 2 x 2 in the middle, and a plate over it.
	var bricks: Array = [
		{"part": "3031", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3003", "color": 0, "x": 0, "y": 1, "z": 0, "rot": 0},
		{"part": "3003", "color": 0, "x": 2, "y": 1, "z": 0, "rot": 0},
		{"part": "3003", "color": 0, "x": 0, "y": 1, "z": 2, "rot": 0},
		{"part": "3003", "color": 0, "x": 2, "y": 1, "z": 2, "rot": 0},
		{"part": "3005", "color": 0, "x": 0, "y": 4, "z": 0, "rot": 0},
		{"part": "3005", "color": 0, "x": 3, "y": 4, "z": 0, "rot": 0},
		{"part": "3005", "color": 0, "x": 0, "y": 4, "z": 3, "rot": 0},
		{"part": "3005", "color": 0, "x": 3, "y": 4, "z": 3, "rot": 0},
		{"part": "3003", "color": 0, "x": 1, "y": 4, "z": 1, "rot": 0},
		{"part": "3031", "color": 0, "x": 0, "y": 7, "z": 0, "rot": 0},
	]
	var faces: Array = [[Vector3.FORWARD, Vector3(1, 4, 0)], [Vector3.BACK, Vector3(1, 4, 3)],
		[Vector3.LEFT, Vector3(0, 4, 1)], [Vector3.RIGHT, Vector3(3, 4, 1)]]
	var side: String = "11211"
	var sections: Array = []
	for n: int in faces.size():
		var out: Vector3 = faces[n][0]
		var at: Vector3 = faces[n][1]
		var rot: int = _rot_facing(side, out)
		var placed: Dictionary = {"part": side, "color": 0, "x": at.x, "y": at.y,
			"z": at.z, "rot": rot}
		bricks.append(placed)
		# Where its two side studs are: the skin's first row of sockets goes
		# on them.
		var mesh: Lbm.PartMesh = _library.mesh_for(side)
		var pose: Transform3D = _assistant._transform(Assistant.Placement.from_dict(placed), mesh)
		var middle := Vector3.ZERO
		var count: int = 0
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and absf(connector.axis.y) < 0.5:
				middle += pose * connector.position
				count += 1
		middle /= maxf(1.0, float(count))
		# Yaw turns the skin's nose round to the face; pitch -90 stands it
		# up with its studs facing its nose's way, so its underside meets
		# the side studs and its section z runs down.
		var yaw: float = rad_to_deg(atan2(out.x, out.z))
		var basis: Basis = Assistant.Section.turned(yaw, -90, 0)
		var origin: Vector3 = middle - basis * Vector3(40, 0, 10)
		sections.append({"name": "skin %d" % (n + 1), "x": origin.x / Assistant.STUD,
			"y": origin.y / Assistant.PLATE, "z": origin.z / Assistant.STUD, "yaw": yaw,
			"pitch": -90})
	# Each skin built flat: a plate the face's width, then curved slopes
	# falling away to its two ends, so four of them read as a round band.
	var skin: Array = [
		{"part": "3020", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "15068", "color": 4, "x": 0, "y": 1, "z": 0, "rot": 3},
		{"part": "15068", "color": 4, "x": 2, "y": 1, "z": 0, "rot": 1},
	]
	for section: Dictionary in sections:
		for brick: Dictionary in skin:
			var one: Dictionary = brick.duplicate()
			one["section"] = section["name"]
			bricks.append(one)
	for one: Dictionary in sections:
		print("     %s" % JSON.stringify(one))
	for one: Dictionary in bricks:
		if one["part"] == side:
			print("     %s" % JSON.stringify(one))
	var read: Assistant.Model = _assistant._read_model({"sections": sections, "bricks": bricks})
	var verdict: Dictionary = _assistant._check(read, true)
	print("     %s" % str(verdict["feedback"]).replace("\n", " ").substr(0, 600))
	_check("four skins standing out on four sides, on their studs, hold: %s"
		% verdict["summary"], bool(verdict["ok"]))
	_write_out(read, "--band_ldr=", "Band of skins")
	var outward: int = 0
	for section: Dictionary in sections:
		var turned: Basis = read.sections[section["name"]].placed().basis
		if absf((turned * Vector3.UP).y) < 0.01:
			outward += 1
	_check("each skin's studs face out sideways: %d of 4" % outward, outward == 4)


## The quarter turn that points a part's side studs along [param out].
func _rot_facing(part: String, out: Vector3) -> int:
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	for rot: int in 4:
		var basis: Basis = BrickLattice.basis_for("up", rot)
		for connector: Lbm.Connector in mesh.connectors:
			if connector.kind == "stud" and connector.gender == "male" \
					and (basis * connector.axis).normalized().dot(out) > 0.99:
				return rot
	return 0


# -- changed afterwards ----------------------------------------------------


func _edits(world: BrickWorld) -> void:
	print("")
	print("  turned again by an edit, saying only what changes")
	var model: Assistant.Model = _assistant._read_model({
		"sections": [{"name": "flap", "x": 6, "y": 4, "z": 6, "yaw": 30, "pitch": 30,
			"hinge": _dome_kind()}],
		"bricks": [
			{"part": "3958", "color": 72, "x": 4, "y": 0, "z": 4, "rot": 0},
			{"part": "3062b", "color": 72, "x": 6, "y": 1, "z": 6, "rot": 0},
			{"part": "3020", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 1,
				"section": "flap"}]})
	_assistant._apply(model, false)
	await process_frame
	var edited: Assistant.Model = _assistant._edit({"sections": [{"name": "flap", "pitch": 60}]})
	var flap: Assistant.Section = edited.sections["flap"]
	_check("a new pitch keeps its yaw, its place and its hinge: %s" % flap.said(),
		is_equal_approx(flap.yaw, 30.0) and is_equal_approx(flap.pitch, 60.0) and flap.hinge
			and is_equal_approx(flap.x, 6.0) and is_equal_approx(flap.y, 4.0))
	var halves: int = edited.placements.filter(func(p: Assistant.Placement) -> bool:
		return p.part == Hinges.KINDS[_dome_kind()][0]).size()
	_check("and it still has one base, not two: %d" % halves, halves == 1)
	var verdict: Dictionary = _assistant._check(edited)
	_check("and holds at the new angle: %s" % verdict["summary"], bool(verdict["ok"]))
	_assistant.forget_built()
	world.clear()


## The window's own turn: the inspector's tilt goes through the builder,
## and the turned part reads back turned, not square.
func _window(world: BrickWorld, builder: Builder) -> void:
	print("")
	print("  the window tips a part, and the design reads it back tipped")
	var id: int = world.add_brick("3020", 15, Transform3D(Basis.IDENTITY, Vector3(0, 80, 0)))
	builder.lattice.occupy_boxes(id, builder.boxes_for(_library.mesh_for("3020"),
		world.get_brick(id).transform))
	builder.select_brick(id, false)
	var turned: int = builder.turn_selection_basis(Assistant.Section.turned(20, 35, 0))
	var basis: Basis = world.get_brick(id).transform.basis
	_check("turned on two axes by the window: %d part, %s" % [turned,
		Assistant.Section.angles_of(basis)], turned == 1
			and Assistant.Section.angles_of(basis).distance_to(Vector3(20, 35, 0)) < 0.1)
	var read: Assistant.Model = _assistant._model_from_world()
	var placement: Assistant.Placement = read.placements[0] if not read.placements.is_empty() else null
	var back: Transform3D = Transform3D()
	if placement != null:
		back = _assistant._transform(placement, _library.mesh_for("3020"),
			read.section_for(placement))
	_check("read back in a section turned so, not square: %s" % (
		read.sections.get(placement.section).said() if placement != null
			and read.sections.has(placement.section) else "no section"),
		placement != null and back.basis.is_equal_approx(basis))
	world.clear()


# -- helpers ---------------------------------------------------------------


## The model as an LDraw file, where -- [param flag]PATH asks for one: to be
## opened and looked at from every side.
func _write_out(model: Assistant.Model, flag: String, title: String) -> void:
	for one: String in OS.get_cmdline_user_args():
		if not one.begins_with(flag):
			continue
		var placements: Array = []
		for index: int in model.placements.size():
			placements.append(LdrModel.Placement.new(model.placements[index].part,
				model.placements[index].color, _pose(model, index), 0))
		var file := FileAccess.open(one.trim_prefix(flag), FileAccess.WRITE)
		if file != null:
			file.store_string(LdrModel.write_ldr(placements, title))
			file.close()


func _pose(model: Assistant.Model, index: int) -> Transform3D:
	var placement: Assistant.Placement = model.placements[index]
	return _assistant._transform(placement, _library.mesh_for(placement.part),
		model.section_for(placement))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
