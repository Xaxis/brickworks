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
extends SceneTree

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

	_turns()
	_hinges()
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


# -- a dome of hinged panels -----------------------------------------------


## The kind the dome hangs on: click hinge plates where the parts have them,
## a clip on a bar otherwise.
func _dome_kind() -> String:
	return Hinges.CLICK if Hinges.available(Hinges.CLICK, _library) else Hinges.CLIP


## A hemisphere of flat panels, as a design says one: a ring of plates for
## the equator, then two meridian strips — a panel hinged on the ring, and
## each panel above hinged within the one below at the next band's angle —
## each repeated round the centre, the second between the first's copies,
## its panels raised three plates on a spacer and wider, so it laps over
## its neighbours' edges as scales do and no gap shows between strips; a
## dish on a column for the crown. [param strips] round in all, [param
## bands] from the equator to the top, of which the lowest [param built]
## are panels, each [param length] studs from hinge line to hinge line;
## [param widths] the inner strips' panels band by band, [param over] the
## outer ones'.
func _dome_args(strips: int, bands: int, built: int, length: int,
		widths: Array, over: Array) -> Dictionary:
	var kind: String = _dome_kind()
	var fit := Assistant.Section.from_dict({"name": "fit", "hinge": kind, "pitch": 1})
	_assistant._fit_hinge(fit)
	var pin: Vector3 = fit.pin_from_corner          ## the line from the base's corner
	var line_in_top: Vector3 = -fit.origin_from_pin  ## the line in the panel's own frame
	var step: float = 90.0 / float(bands)
	# The line round the equator, where a chord of this length spans a band.
	var radius: float = length * Assistant.STUD / (2.0 * sin(deg_to_rad(step * 0.5)))
	var centre := Vector2(20, 20)    ## studs
	# The ring the strips stand on: plates in two crossed layers, the upper
	# outside the lines only, the lower a whole disc for the crown's column.
	var bricks: Array = []
	var ring_out: float = radius / Assistant.STUD + 4.0
	var ring_in: float = radius / Assistant.STUD + 0.6
	for layer: int in 2:
		var cells: Dictionary = {}
		for x: int in range(int(floor(centre.x - ring_out)), int(ceil(centre.x + ring_out))):
			for z: int in range(int(floor(centre.y - ring_out)), int(ceil(centre.y + ring_out))):
				var far: float = Vector2(x + 0.5 - centre.x, z + 0.5 - centre.y).length()
				if far <= ring_out and (layer == 0 or far >= ring_in):
					cells[Vector2i(x, z)] = true
		# Rows along x below, columns along z above: each plate crosses the
		# joints of the layer under it, so the ring is one piece.
		for line_at: int in range(int(floor(centre.y - ring_out)) - 1, int(ceil(centre.y + ring_out)) + 1):
			var run: Array[int] = []
			for along: int in range(int(floor(centre.x - ring_out)) - 1,
					int(ceil(centre.x + ring_out)) + 2):
				var cell := Vector2i(along, line_at) if layer == 0 else Vector2i(line_at, along)
				if cells.has(cell):
					run.append(along)
					continue
				if not run.is_empty():
					_lay_run(bricks, layer, line_at, run[0], run[-1] + 1, layer == 0)
					run.clear()
	var sections: Array = []
	var repeats: Array = []
	for strip: int in 2:
		var first: String = "band 1" if strip == 0 else "over 1"
		# The strip's base: on the ring's top, at the far side from the
		# centre, turned round it by this strip's share, nose to the centre,
		# so pitch lifts the panel up and in and its studs face out.
		var yaw: float = 180.0 + strip * 360.0 / strips
		var away: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw - 180.0)) * Vector3(0, 0, radius)
		var line := Vector3(centre.x * Assistant.STUD + away.x, 2.0 * Assistant.PLATE + pin.y,
			centre.y * Assistant.STUD + away.z)
		var stud := Vector3(10, 0, 10)
		var corner: Vector3 = line - stud - Basis(Vector3.UP, deg_to_rad(yaw)) * (pin - stud)
		# On whole studs: the base swivels on the stud under its first one.
		corner = Vector3(roundf(corner.x / Assistant.STUD) * Assistant.STUD, corner.y,
			roundf(corner.z / Assistant.STUD) * Assistant.STUD)
		sections.append({"name": first, "x": corner.x / Assistant.STUD, "y": 2,
			"z": corner.z / Assistant.STUD, "yaw": yaw, "pitch": 90.0 - step * 0.5,
			"hinge": kind, "hinge_color": 72})
		# Each next panel's base at the far end of the one below, in its
		# frame: the line [param length] studs on from this one's.
		var next: Vector3 = line_in_top + Vector3(0, 0, length * Assistant.STUD) - pin
		var stem: String = first.trim_suffix(" 1")
		for band: int in range(1, built):
			sections.append({"name": "%s %d" % [stem, band + 1],
				"within": "%s %d" % [stem, band], "x": next.x / Assistant.STUD,
				"y": next.y / Assistant.PLATE, "z": next.z / Assistant.STUD, "pitch": -step,
				"hinge": kind, "hinge_color": 72})
		var rise: int = 0 if strip == 0 else 3
		for band: int in built:
			# Plates the panel's width over both hinge halves, centred on
			# them (x 0..1), and tiles on them: L - 1 studs long, the top half
			# under its first two and the next panel's base under its last
			# two. The outer strip's stand on a spacer a stud wide.
			var width: int = int((widths if strip == 0 else over)[mini(band,
				(widths if strip == 0 else over).size() - 1)])
			var name: String = "%s %d" % [stem, band + 1]
			var far: int = length - 1
			for z: int in range(0, far, 2):
				var deep: int = mini(2, far - z)
				for y: int in rise:
					var part: String = _plate(1, deep)
					bricks.append({"part": part, "color": 72, "x": 0, "y": y, "z": z,
						"rot": _rot_across(part, 1), "section": name})
				# The tiles split the other way from the plates, so each one
				# ties two plates across the seam between them.
				for layer: int in 2:
					for piece: Vector2i in _pieces(width, layer == 1):
						var part: String = _plate(piece.y, deep) if layer == 0 \
							else _tile(piece.y, deep)
						bricks.append({"part": part, "color": 71, "x": piece.x,
							"y": layer + rise, "z": z, "rot": _rot_across(part, piece.y),
							"section": name})
		repeats.append({"from": first, "times": strips / 2 - 1,
			"around": {"x": centre.x, "z": centre.y}, "yaw": 720.0 / strips})
	# The crown: a dish over the top band, on a column of round bricks
	# standing on the ring's lower layer.
	var top: float = radius * sin(deg_to_rad(step * built)) / Assistant.PLATE + 2.0
	var lift: int = int(ceil(top)) + 5
	var y: int = 1
	while y + 3 <= lift:
		bricks.append({"part": "3941", "color": 72, "x": centre.x - 1, "y": y,
			"z": centre.y - 1, "rot": 0})
		y += 3
	while y < lift:
		bricks.append({"part": "4032a", "color": 72, "x": centre.x - 1, "y": y,
			"z": centre.y - 1, "rot": 0})
		y += 1
	bricks.append({"part": "50990b", "color": 71, "x": centre.x - 5, "y": lift,
		"z": centre.y - 5, "rot": 0})
	return {"name": "hinged dome", "sections": sections, "bricks": bricks,
		"repeat_section": repeats, "radius": radius}


func _dome() -> void:
	print("")
	print("  a hinged-panel dome")
	var args: Dictionary = _dome_args(12, 4, 3, 5, [5, 5, 3], [9, 7, 5])
	var radius: float = float(args["radius"])
	args.erase("radius")
	# Written out on request, to be put to another build's check as it
	# stands: -- --dump=PATH.
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with("--dump="):
			var file := FileAccess.open(one.trim_prefix("--dump="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(args, "\t"))
				file.close()
	var model: Assistant.Model = _assistant._read_model(args)
	var verdict: Dictionary = _assistant._check(model, true)
	print("     %s" % str(verdict["feedback"]).replace("\n", " ").substr(0, 900))
	var adrift: Dictionary = {}
	for index: Variant in verdict.get("floating", []):
		var placement: Assistant.Placement = model.placements[int(index)]
		adrift[placement.section] = int(adrift.get(placement.section, 0)) + 1
	for name: String in adrift:
		print("       floating in %s: %d" % [name, adrift[name]])
	# Each hinge's two halves, joined by the check's own rule.
	var rounds: Dictionary = Joints.rounds(_assistant._mating_entries(model))
	var unjoined := PackedStringArray()
	for name: String in model.sections:
		var section: Assistant.Section = model.sections[name]
		if not section.hinge:
			continue
		var held: bool = false
		for index: int in model.placements.size():
			if model.placements[index].section != name:
				continue
			for other: Variant in rounds.get(index, {}):
				if model.placements[int(other)].section != name:
					held = true
		if not held:
			unjoined.append(name)
	_check("every hinge's halves joined, %d of %d not: %s" % [unjoined.size(), 36,
		", ".join(unjoined)], unjoined.is_empty())
	var panels: int = 0
	var angles: Dictionary = {}
	var low := Vector3.INF
	var high := -Vector3.INF
	for index: int in model.placements.size():
		var placement: Assistant.Placement = model.placements[index]
		var at: Transform3D = _pose(model, index)
		low = low.min(at.origin)
		high = high.max(at.origin)
		if not (placement.section.begins_with("band") or placement.section.begins_with("over")) \
				or placement.section.ends_with("hinge"):
			continue
		panels += 1
		var turn: Vector3 = Assistant.Section.angles_of(at.basis)
		angles["%d %d" % [roundi(fposmod(turn.x, 360.0)), roundi(turn.y)]] = true
	var across: float = (high.x - low.x) / Assistant.STUD
	_check("%d panel parts at %d different two-axis angles, %.1f studs across"
		% [panels, angles.size(), across], angles.size() >= 36 and across >= 20.0)
	_check("every panel held by its hinge, nothing overlapping: %s" % verdict["summary"],
		bool(verdict["ok"]))
	_check("and the line it stands on is %.1f studs from the centre" % (radius / Assistant.STUD),
		radius > 150.0)
	_write_out(model, "--dome_ldr=", "Hinged dome")


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


## Plates 1 x n laid end to end from [param from] to [param to] along a
## row (z = [param at], along x) or a column (x = [param at], along z), on
## [param layer].
func _lay_run(bricks: Array, layer: int, at: int, from: int, to: int, along_x: bool) -> void:
	var here: int = from
	while here < to:
		var run: int = mini(8, to - here)
		var used: int = {1: 1, 2: 2, 3: 3, 4: 4, 5: 4, 6: 6, 7: 6, 8: 8}[run]
		var part: String = {1: "3024", 2: "3023", 3: "3623", 4: "3710", 6: "3666",
			8: "3460"}[used]
		bricks.append({"part": part, "color": 72, "x": here if along_x else at, "y": layer,
			"z": at if along_x else here, "rot": 0 if along_x else 1})
		here += used


## The quarter turn that lays a part [param across] studs along x.
func _rot_across(part: String, across: int) -> int:
	var info: PartLibrary.PartInfo = _library.parts.get(part)
	if info == null:
		return 0
	return 0 if roundi(info.size.x / Assistant.STUD) == across else 1


## A panel's width as plates side by side, centred on its hinge's x 0..1:
## [x, width] each, split the other way round when [param over].
func _pieces(width: int, over: bool) -> Array[Vector2i]:
	match width:
		1:
			return [Vector2i(0, 1)]
		3:
			return [Vector2i(-1, 3)]
		5:
			return [Vector2i(-2, 3), Vector2i(1, 2)] if over \
				else [Vector2i(-2, 2), Vector2i(0, 3)]
		7:
			return [Vector2i(-3, 3), Vector2i(0, 4)] if over \
				else [Vector2i(-3, 4), Vector2i(1, 3)]
		9:
			return [Vector2i(-4, 3), Vector2i(-1, 6)] if over \
				else [Vector2i(-4, 6), Vector2i(2, 3)]
	return [Vector2i(-(width - 1) / 2, width)]


func _plate(width: int, deep: int) -> String:
	var key: Vector2i = Vector2i(maxi(width, deep), mini(width, deep))
	return str({Vector2i(1, 1): "3024", Vector2i(2, 1): "3023", Vector2i(2, 2): "3022",
		Vector2i(3, 1): "3623", Vector2i(3, 2): "3021", Vector2i(4, 1): "3710",
		Vector2i(4, 2): "3020", Vector2i(6, 2): "3795"}[key])


func _tile(width: int, deep: int) -> String:
	var key: Vector2i = Vector2i(maxi(width, deep), mini(width, deep))
	return str({Vector2i(1, 1): "3070b", Vector2i(2, 1): "3069b", Vector2i(2, 2): "3068b",
		Vector2i(3, 1): "63864", Vector2i(3, 2): "26603", Vector2i(4, 1): "2431",
		Vector2i(4, 2): "87079", Vector2i(6, 2): "69729"}[key])


func _pose(model: Assistant.Model, index: int) -> Transform3D:
	var placement: Assistant.Placement = model.placements[index]
	return _assistant._transform(placement, _library.mesh_for(placement.part),
		model.section_for(placement))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
