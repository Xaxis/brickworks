## A design's massing, planned before its first brick, and its builds held
## to it.
##
## The judge's commonest cause against our designs on likeness and overall
## is a generic or boxy shape, and it is chosen when the design is planned:
## told after its first build that the model filled more of its box than
## real sets of its kind (design15, DESIGN_SCORES.md), 9 of 20 sessions
## re-planned and won overall 5 -> 8 of 18, where the rest went on to the
## detail inside what the plan had chosen. So the plan names its volumes
## before any brick (plan_massing): each a footprint in studs and a height in
## plates, round or square, its top the same footprint or a narrower one (a
## roof falling to its eaves, a taper, a wedge). It is measured as a build
## is (Massing): how much of its box it fills, against real sets of the
## theme and size. Each build of the design is then read against it: every
## volume there at its height, and the setbacks, the gaps and the space
## under an overhang left open where the plan left them open.
class_name MassingPlan
extends RefCounted

## Volumes a plan may have, and how big one may be, in studs and plates.
const MOST := 24
const WIDEST := 200.0
const TALLEST := 600.0
## How far a column's top may be off its plan and not be said: a brick.
const SLACK := 3
## The fewest voxel columns (a quarter of a square stud each) a difference
## covers to be said: four square studs, more than a mast, a lamp or a
## figure. And the share of what it is measured over.
const LEAST := 16
const SHARE := 0.2
## A volume less of which is built is not there.
const PRESENT := 0.5
## Columns of the side views drawn, at most, and rows.
const DRAWN_ACROSS := 40
const DRAWN_UP := 16

## What a build is told when no massing was planned for it.
const NO_PLAN := ("Massing: no plan was given before this build. plan_massing names the "
	+ "subject's main volumes (each a footprint, a height and its setback or "
	+ "overhang, and what you would know it by from the front and the side), "
	+ "measures how much of its box they fill against real sets of its kind, and "
	+ "holds the next build to them. The detail goes inside what the massing "
	+ "chooses, so it is worth settling before the detail.")


## [param volumes] as plan_massing takes them, read: {"volumes": [{"name",
## "x", "z": Vector2 from and to in studs, "y": Vector2 in plates, "top":
## Rect2 of x and z, its footprint at its top, "round": bool}]}, or
## {"error": what to give instead}.
static func parse(volumes: Variant) -> Dictionary:
	if not volumes is Array or (volumes as Array).is_empty():
		return {"error": "Give volumes: the subject's main masses, each {\"name\", "
			+ "\"x_from\", \"x_to\", \"z_from\", \"z_to\" in studs, \"y_from\", \"y_to\" in "
			+ "plates up}, in the coordinates the design will be built in."}
	if (volumes as Array).size() > MOST:
		return {"error": "%d volumes: the massing is the main masses, %d at most, "
			% [(volumes as Array).size(), MOST] + "and the detail comes after it."}
	var out: Array = []
	for raw: Variant in volumes:
		if not raw is Dictionary:
			return {"error": "Each volume is an object: {\"name\", \"x_from\", \"x_to\", "
				+ "\"z_from\", \"z_to\", \"y_from\", \"y_to\"}."}
		var one: Dictionary = raw
		var name: String = str(one.get("name", "")).strip_edges()
		if name.is_empty():
			return {"error": "Each volume needs a name: what a person would call it "
				+ "(the tower, the cab, the east wing)."}
		for key: String in ["x_from", "x_to", "z_from", "z_to", "y_to"]:
			var value: Variant = one.get(key)
			if not (value is float or value is int):
				return {"error": "%s needs %s, a number." % [name, key]}
		var x := Vector2(float(one["x_from"]), float(one["x_to"]))
		var z := Vector2(float(one["z_from"]), float(one["z_to"]))
		var y := Vector2(float(one.get("y_from", 0.0)), float(one["y_to"]))
		if x.y <= x.x or z.y <= z.x or y.y <= y.x:
			return {"error": "%s: each _to is past its _from (x %s to %s, z %s to %s, y %s to %s)."
				% [name, _num(x.x), _num(x.y), _num(z.x), _num(z.y), _num(y.x), _num(y.y)]}
		if x.y - x.x > WIDEST or z.y - z.x > WIDEST or y.y - y.x > TALLEST:
			return {"error": "%s is bigger than a model is: %s studs across or deep at most, "
				% [name, _num(WIDEST)] + "%s plates tall." % _num(TALLEST)}
		var top := Rect2(x.x, z.x, x.y - x.x, z.y - z.x)
		if one.get("top") is Dictionary:
			var at: Dictionary = one["top"]
			var tx := Vector2(float(at.get("x_from", x.x)), float(at.get("x_to", x.y)))
			var tz := Vector2(float(at.get("z_from", z.x)), float(at.get("z_to", z.y)))
			if tx.y < tx.x or tz.y < tz.x:
				return {"error": "%s's top: each _to is at or past its _from (the same "
					% name + "for a ridge or a point)."}
			top = Rect2(tx.x, tz.x, tx.y - tx.x, tz.y - tz.x)
		out.append({"name": name, "x": x, "z": z, "y": y, "top": top,
			"round": bool(one.get("round", false))})
	return {"volumes": out}


## Voxel -> the index of the volume filling it, of every voxel the plan's
## volumes fill (Massing.voxels: half a stud across, a plate tall), a later
## volume's where two share one. A layer's footprint runs from the volume's
## bottom footprint to its top one, each layer the footprint at its own
## bottom, so a roof's first layer reaches its eaves; a round volume's is the
## ellipse in it.
static func voxels(volumes: Array) -> Dictionary:
	var filled: Dictionary = {}
	for n: int in volumes.size():
		var one: Dictionary = volumes[n]
		var x: Vector2 = one["x"]
		var z: Vector2 = one["z"]
		var y: Vector2 = one["y"]
		var top: Rect2 = one["top"]
		var round: bool = one["round"]
		for layer: int in range(floori(y.x), ceili(y.y)):
			var mid: float = layer + 0.5
			if mid <= y.x or mid >= y.y:
				continue
			var t: float = maxf(0.0, layer - y.x) / (y.y - y.x)
			var x0: float = lerpf(x.x, top.position.x, t)
			var x1: float = lerpf(x.y, top.end.x, t)
			var z0: float = lerpf(z.x, top.position.y, t)
			var z1: float = lerpf(z.y, top.end.y, t)
			for vx: int in range(floori(x0 * 2.0), ceili(x1 * 2.0)):
				var cx: float = (vx + 0.5) / 2.0
				if cx < x0 or cx >= x1:
					continue
				for vz: int in range(floori(z0 * 2.0), ceili(z1 * 2.0)):
					var cz: float = (vz + 0.5) / 2.0
					if cz < z0 or cz >= z1:
						continue
					if round and pow((cx - (x0 + x1) / 2.0) / ((x1 - x0) / 2.0), 2.0) \
							+ pow((cz - (z0 + z1) / 2.0) / ((z1 - z0) / 2.0), 2.0) > 1.0:
						continue
					filled[Vector3i(vx, layer, vz)] = n
	return filled


## The plan measured (Massing.measure_filled), with "voxels" (voxels()) for
## the side views. Reads only its argument, so it runs on a worker.
static func measured(volumes: Array) -> Dictionary:
	var filled: Dictionary = voxels(volumes)
	var found: Dictionary = Massing.measure_filled(filled)
	found["voxels"] = filled
	return found


## What plan_massing answers: how much of its box the plan fills against the
## real sets [param ref] (Massing.sets_like) first, then its volumes as
## read, how each stands on the one under it, and its outline from the
## front and the side. [param found] is measured().
static func said_plan(volumes: Array, found: Dictionary, ref: Dictionary) -> String:
	var said := PackedStringArray()
	var box: Array = found.get("box", [0, 0, 0])
	var lead: String = "Massing planned: %d volume%s, %s x %s studs and %s plates over all%s. " % [
		volumes.size(), "" if volumes.size() == 1 else "s", _num(_span(volumes, "x")),
		_num(_span(volumes, "z")), _num(_span(volumes, "y")),
		" (%s x %s and %d above the ground)" % [_num(float(box[0])), _num(float(box[1])), int(box[2])]
			if int(found.get("ground", 0)) > 0 else ""]
	var fill: int = roundi(float(found.get("fill", 0.0)) * 100.0)
	lead += "Seen from above, every column counted from its top down, it fills %d%% of its box. " % fill
	if ref.is_empty():
		lead += ("Too few real sets of its theme or kind near its size are known to "
			+ "measure it by, so that is for you to judge: a full box reads as a "
			+ "generic block.")
	else:
		lead += ("%s of %d to %d parts fill %d%% to %d%%, most often %d%% (%d sets, none "
			% [ref["by"], ref["low"], ref["high"], roundi(float(ref["q1"]) * 100.0),
				roundi(float(ref["q3"]) * 100.0), roundi(float(ref["median"]) * 100.0),
				int(ref["sets"])] + "under test): ")
		if float(found.get("fill", 0.0)) > float(ref["q3"]):
			lead += ("fuller than three in four of them. Of two designs of one subject, "
				+ "the fuller loses on likeness more often: a full box reads as a generic "
				+ "block. Sets break their massing into the volumes the subject is known "
				+ "by, each at its own height and set back from the next; leave open the "
				+ "gaps it has (between wings, under an overhang, between a cab and what it "
				+ "carries, round the wheels); and bring a roof or a top down to its edges "
				+ "(a volume's top). Plan it that way now, while it costs nothing. If this "
				+ "subject is a block, keep it and say why.")
		elif float(found.get("fill", 0.0)) < float(ref["q1"]):
			lead += ("leaner than three in four of them. Good where the subject is spare; "
				+ "check nothing it is known by is left out.")
		else:
			lead += "within what most of them fill."
	said.append(lead)
	var rows := PackedStringArray()
	for one: Dictionary in volumes:
		rows.append("  " + _volume_said(one, volumes))
	said.append("The volumes, as read (x across, z deep with the front at +z, y in "
		+ "plates up):\n" + "\n".join(rows))
	var filled: Dictionary = found.get("voxels", {})
	if not filled.is_empty():
		said.append("From the front:\n" + _drawn(filled, true))
		said.append("From the side, its front to the right:\n" + _drawn(filled, false))
	said.append("Each build is read against these volumes: each there at its height, and "
		+ "the setbacks, the gaps and the space under an overhang left open. plan_massing "
		+ "again replaces the plan.")
	return "\n\n".join(said)


## A volume as read: where it is, how big, its shape, and how it stands on
## the volume under it.
static func _volume_said(one: Dictionary, volumes: Array) -> String:
	var x: Vector2 = one["x"]
	var z: Vector2 = one["z"]
	var y: Vector2 = one["y"]
	var top: Rect2 = one["top"]
	var said: String = "%s: %s x %s studs%s, %s to %s plates (x %s to %s, z %s to %s)" % [
		one["name"], _num(x.y - x.x), _num(z.y - z.x), ", round" if one["round"] else "",
		_num(y.x), _num(y.y), _num(x.x), _num(x.y), _num(z.x), _num(z.y)]
	var bottom := Rect2(x.x, z.x, x.y - x.x, z.y - z.x)
	if not top.is_equal_approx(bottom):
		if is_zero_approx(top.size.x) and is_zero_approx(top.size.y):
			said += ", rising to a point"
		elif is_zero_approx(top.size.x) or is_zero_approx(top.size.y):
			said += ", rising to a ridge along %s" % ("z" if is_zero_approx(top.size.x) else "x")
		else:
			said += ", %s to %s x %s at its top" % ["narrowing" if top.get_area() < bottom.get_area()
				else "widening", _num(top.size.x), _num(top.size.y)]
	var under: Dictionary = _under(one, volumes)
	if under.is_empty():
		return said
	var ux: Vector2 = under["x"]
	var uz: Vector2 = under["z"]
	# Set back is positive, an overhang negative: front +z, back -z, sides x.
	var sides: Array = [["the front", uz.y - z.y], ["the back", z.x - uz.x],
		["the left", x.x - ux.x], ["the right", ux.y - x.y]]
	var back := PackedStringArray()
	var over := PackedStringArray()
	for side: Array in sides:
		if float(side[1]) >= 0.5:
			back.append("%s at %s" % [_num(float(side[1])), side[0]])
		elif float(side[1]) <= -0.5:
			over.append("%s at %s" % [_num(-float(side[1])), side[0]])
	said += ", on the %s" % under["name"]
	if not back.is_empty():
		said += ": set back %s" % ", ".join(back)
	if not over.is_empty():
		said += "%s overhanging it %s" % [";" if not back.is_empty() else ":", ", ".join(over)]
	if back.is_empty() and over.is_empty():
		said += ", flush with it"
	return said


## The volume [param one] stands on: the one whose top is where it begins,
## within a plate, that it most overlaps. {} for none.
static func _under(one: Dictionary, volumes: Array) -> Dictionary:
	var best: Dictionary = {}
	var most: float = 0.0
	var mine := Rect2((one["x"] as Vector2).x, (one["z"] as Vector2).x,
		(one["x"] as Vector2).y - (one["x"] as Vector2).x,
		(one["z"] as Vector2).y - (one["z"] as Vector2).x)
	for other: Dictionary in volumes:
		if is_same(other, one) or absf((other["y"] as Vector2).y - (one["y"] as Vector2).x) > 1.0:
			continue
		var theirs: Rect2 = other["top"]
		var shared: float = mine.intersection(theirs).get_area()
		if shared > most:
			most = shared
			best = other
	return best


## The plan's outline from the front (x across, y up) or from the side (z
## across, the front +z at the right), a character a cell: "#" where half or
## more of the cell is filled.
static func _drawn(filled: Dictionary, front: bool) -> String:
	var seen: Dictionary = {}
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for cell: Vector3i in filled:
		var at := Vector2i(cell.x if front else cell.z, cell.y)
		seen[at] = true
		low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
		high = Vector2i(maxi(high.x, at.x), maxi(high.y, at.y))
	# A cell is whole studs across, whole bricks up, so the drawing fits.
	var across: int = maxi(2, ceili((high.x - low.x + 1) / float(DRAWN_ACROSS) / 2.0) * 2)
	var up: int = maxi(SLACK, ceili((high.y - low.y + 1) / float(DRAWN_UP) / SLACK) * SLACK)
	var rows := PackedStringArray()
	var count: int = ceili((high.y - low.y + 1) / float(up))
	for r: int in count:
		var y: int = low.y + (count - 1 - r) * up
		var row: String = ""
		for x: int in range(low.x, high.x + 1, across):
			var hits: int = 0
			for dx: int in across:
				for dy: int in up:
					if seen.has(Vector2i(x + dx, y + dy)):
						hits += 1
			row += "#" if hits * 2 >= across * up else "."
		rows.append("  " + row + (" top %d plates" % (high.y + 1) if r == 0 else ""))
	rows.append("  (a character is %d stud%s across, %d plates up)" % [across / 2,
		"" if across == 2 else "s", up])
	return "\n".join(rows)


## The build [param built] (Massing.voxels of its bricks) read against the
## plan [param volumes] (parse): {"lines": what moved off the plan, a line
## each, "kept": the volumes built as planned, "moved": Vector2 the plan was
## read moved by, in studs, to meet the build, "box", "planned_box": [width,
## depth in studs, height in plates], "fill", "planned_fill"}. Reads only its
## arguments.
static func check(volumes: Array, built: Dictionary) -> Dictionary:
	var plan: Dictionary = voxels(volumes)
	var planned: Dictionary = {}   # Vector2i column -> [bottom, one past top, top's volume]
	var spans: Array = []          # per volume: Vector2i column -> Vector2i(bottom, one past top)
	for _n: int in volumes.size():
		spans.append({})
	var floor_at: int = 1 << 30
	for cell: Vector3i in plan:
		var n: int = plan[cell]
		var column := Vector2i(cell.x, cell.z)
		var was: Array = planned.get(column, [cell.y, cell.y + 1, n])
		planned[column] = [mini(int(was[0]), cell.y), maxi(int(was[1]), cell.y + 1),
			n if cell.y + 1 >= int(was[1]) else int(was[2])]
		var mine: Dictionary = spans[n]
		var span: Vector2i = mine.get(column, Vector2i(cell.y, cell.y + 1))
		mine[column] = Vector2i(mini(span.x, cell.y), maxi(span.y, cell.y + 1))
		floor_at = mini(floor_at, cell.y)
	var stacks: Dictionary = {}    # Vector2i column -> Array[int] of filled layers
	for cell: Vector3i in built:
		var column := Vector2i(cell.x, cell.z)
		if not stacks.has(column):
			stacks[column] = []
		(stacks[column] as Array).append(cell.y)
	var shift: Vector2i = _meeting(planned, stacks, floor_at)
	var tops: Dictionary = {}      # build column, in the plan's place -> one past its top
	var standing: Dictionary = {}  # those above the ground
	for column: Vector2i in stacks:
		var at: Vector2i = column - shift
		var top: int = int((stacks[column] as Array).max()) + 1
		tops[at] = top
		if top > floor_at + 1:
			standing[at] = true
	var lines := PackedStringArray()
	var kept := PackedStringArray()
	for n: int in volumes.size():
		var one: Dictionary = volumes[n]
		var said: PackedStringArray = _volume_checked(n, one, volumes, spans[n], planned,
			stacks, tops, shift, floor_at)
		if said.is_empty():
			kept.append(str(one["name"]))
		lines.append_array(said)
	lines.append_array(_gaps_checked(volumes, planned, tops, floor_at))
	var outside: String = _outside_checked(planned, standing)
	if not outside.is_empty():
		lines.append(outside)
	var plan_found: Dictionary = Massing.measure_filled(plan)
	var build_found: Dictionary = Massing.measure_filled(built)
	return {"lines": lines, "kept": kept, "moved": Vector2(shift) / 2.0,
		"box": _box_of(standing, tops, floor_at), "planned_box": [_span(volumes, "x"),
			_span(volumes, "z"), _span(volumes, "y")],
		"fill": float(build_found.get("fill", 0.0)), "planned_fill": float(plan_found.get("fill", 0.0))}


## How far, in voxels, the plan is read moved to meet the build: not at all
## when the two footprints mostly meet where they are, else their boxes'
## centres or corners put together, whichever meets more.
static func _meeting(planned: Dictionary, stacks: Dictionary, floor_at: int) -> Vector2i:
	var standing: Dictionary = {}
	for column: Vector2i in stacks:
		if int((stacks[column] as Array).max()) + 1 > floor_at + 1:
			standing[column] = true
	if standing.is_empty():
		return Vector2i.ZERO
	var here: float = _meet(planned, standing, Vector2i.ZERO)
	if here >= 0.5:
		return Vector2i.ZERO
	var a: Rect2i = _bounds(planned)
	var b: Rect2i = _bounds(standing)
	var best := Vector2i.ZERO
	var most: float = here
	# Whole studs: a design is laid on them.
	var centred: Vector2i = (b.get_center() - a.get_center()) / 2 * 2
	for shift: Vector2i in [centred, (b.position - a.position) / 2 * 2]:
		var met: float = _meet(planned, standing, shift)
		if met > most + 0.15:
			most = met
			best = shift
	return best


## Of the plan's columns moved by [param shift] and the build's, the share
## both have.
static func _meet(planned: Dictionary, standing: Dictionary, shift: Vector2i) -> float:
	var both: int = 0
	for column: Vector2i in planned:
		if standing.has(column + shift):
			both += 1
	return both / float(planned.size() + standing.size() - both)


static func _bounds(columns: Dictionary) -> Rect2i:
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for column: Vector2i in columns:
		low = Vector2i(mini(low.x, column.x), mini(low.y, column.y))
		high = Vector2i(maxi(high.x, column.x), maxi(high.y, column.y))
	return Rect2i(low, high - low + Vector2i.ONE)


## What of volume [param n] the build moved off the plan, a line each.
static func _volume_checked(n: int, one: Dictionary, volumes: Array, mine: Dictionary,
		planned: Dictionary, stacks: Dictionary, tops: Dictionary, shift: Vector2i,
		floor_at: int) -> PackedStringArray:
	var said := PackedStringArray()
	var name: String = one["name"]
	if mine.is_empty():
		return said
	# There: built anywhere in its height, along its edges, where a shell
	# is built as much as a solid is.
	var edge: Dictionary = _edge(mine)
	var met: int = 0
	for column: Vector2i in edge:
		var span: Vector2i = mine[column]
		for layer: int in stacks.get(column + shift, []):
			if layer >= span.x and layer < span.y:
				met += 1
				break
	var present: float = met / float(edge.size())
	if present < PRESENT:
		said.append("%s: only %d%% of it is built where it was planned (x %s to %s, z %s to %s, "
			% [name, roundi(present * 100.0), _num((one["x"] as Vector2).x),
				_num((one["x"] as Vector2).y), _num((one["z"] as Vector2).x),
				_num((one["z"] as Vector2).y)]
			+ "%s to %s plates)." % [_num((one["y"] as Vector2).x), _num((one["y"] as Vector2).y)])
		return said
	# Its top, where it is the plan's top.
	var own: Array[Vector2i] = []
	for column: Vector2i in mine:
		if int((planned[column] as Array)[2]) == n:
			own.append(column)
	if not own.is_empty():
		var planned_at: Array[int] = []
		var over: int = 0
		var over_to: Array[int] = []
		for column: Vector2i in own:
			var top: int = maxi(int(tops.get(column, floor_at)), floor_at)
			var want: int = int((planned[column] as Array)[1])
			planned_at.append(want)
			if top - want > SLACK:
				over += 1
				over_to.append(top)
		planned_at.sort()
		var height: float = (one["y"] as Vector2).y - (one["y"] as Vector2).x
		var middle: Vector2i = _middle_at(own, edge, tops, planned, floor_at)
		if middle.x - middle.y < -maxf(SLACK, height * 0.2):
			said.append("%s: short, its top at about %d plates where %d was planned."
				% [name, middle.x, middle.y])
		elif over >= maxi(LEAST, ceili(own.size() * SHARE)):
			over_to.sort()
			var to: int = over_to[over_to.size() / 2]
			var above: String = _above(one, volumes)
			var bottom: Vector2 = Vector2((one["x"] as Vector2).y - (one["x"] as Vector2).x,
				(one["z"] as Vector2).y - (one["z"] as Vector2).x)
			var top_rect: Rect2 = one["top"]
			if not above.is_empty():
				said.append("%s: the setback round %s is built up, %s square studs of it to "
					% [name, above, _num(over / 4.0)]
					+ "about %d plates, where its top was planned at %d." % [to,
						planned_at[planned_at.size() / 2]])
			elif top_rect.get_area() < bottom.x * bottom.y - 0.25:
				said.append("%s: built up past its slope over %s square studs, to about %d "
					% [name, _num(over / 4.0), to] + "plates: its top was to come down to "
					+ "its edges.")
			else:
				said.append("%s: taller than planned over %s square studs, to about %d plates "
					% [name, _num(over / 4.0), to] + "where %d was planned."
					% planned_at[planned_at.size() / 2])
	# The space under it, where the plan has nothing under it.
	var bottom_at: int = floori((one["y"] as Vector2).x)
	if bottom_at >= floor_at + 2 * SLACK:
		var open: int = 0
		var filled_under: int = 0
		for column: Vector2i in mine:
			if int((planned[column] as Array)[0]) < bottom_at:
				continue
			open += 1
			var under: int = 0
			for layer: int in stacks.get(column + shift, []):
				if layer >= floor_at + 2 and layer < bottom_at - 1:
					under += 1
			if under >= SLACK:
				filled_under += 1
		if open > 0 and filled_under >= maxi(LEAST, ceili(open * SHARE)):
			said.append("%s: the space under it, planned open below %d plates, is filled under "
				% [name, bottom_at] + "%s square studs of it." % _num(filled_under / 4.0))
	return said


## A volume's columns within a stud of its outline: its walls, where a shell
## has them.
static func _edge(mine: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for column: Vector2i in mine:
		for dx: int in range(-2, 3):
			for dz: int in range(-2, 3):
				if not mine.has(column + Vector2i(dx, dz)):
					out[column] = true
					break
			if out.has(column):
				break
	return out


## The build's top and the plan's, each the middle of [param own]'s columns
## along the edge (all of them where none are): a shell's middle is open
## whatever its height.
static func _middle_at(own: Array[Vector2i], edge: Dictionary, tops: Dictionary,
		planned: Dictionary, floor_at: int) -> Vector2i:
	var along: Array[Vector2i] = []
	for column: Vector2i in own:
		if edge.has(column):
			along.append(column)
	if along.is_empty():
		along = own
	var built: Array[int] = []
	var wanted: Array[int] = []
	for column: Vector2i in along:
		built.append(maxi(int(tops.get(column, floor_at)), floor_at))
		wanted.append(int((planned[column] as Array)[1]))
	built.sort()
	wanted.sort()
	return Vector2i(built[built.size() / 2], wanted[wanted.size() / 2])


## The volumes standing on [param one], said: "the tower", "the tower and the
## spire", "" for none.
static func _above(one: Dictionary, volumes: Array) -> String:
	var names := PackedStringArray()
	for other: Dictionary in volumes:
		if not is_same(other, one) and is_same(_under(other, volumes), one):
			names.append("the " + str(other["name"]))
	if names.size() > 2:
		return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]
	return " and ".join(names)


## The plan's gaps the build filled: the columns inside the plan's box it
## leaves open, each run of them a gap, named by the volumes beside it; the
## gaps of one name (a round volume's four corners) said together.
static func _gaps_checked(volumes: Array, planned: Dictionary, tops: Dictionary,
		floor_at: int) -> PackedStringArray:
	var box: Rect2i = _bounds(planned)
	var seen: Dictionary = {}
	var named: Dictionary = {}   # name -> {"gaps": [Array[Vector2i]], "up": int, "to": Array[int]}
	for gx: int in range(box.position.x, box.end.x):
		for gz: int in range(box.position.y, box.end.y):
			var start := Vector2i(gx, gz)
			if planned.has(start) or seen.has(start):
				continue
			# One gap: every open column joined to this one, inside the box.
			var gap: Array[Vector2i] = [start]
			seen[start] = true
			var at: int = 0
			while at < gap.size():
				var here: Vector2i = gap[at]
				at += 1
				for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = here + step
					if box.has_point(next) and not planned.has(next) and not seen.has(next):
						seen[next] = true
						gap.append(next)
			if gap.size() < LEAST:
				continue
			var name: String = _beside(gap, volumes, planned)
			if not named.has(name):
				named[name] = {"gaps": [], "up": 0, "to": []}
			var these: Dictionary = named[name]
			(these["gaps"] as Array).append(gap)
			for column: Vector2i in gap:
				var top: int = int(tops.get(column, floor_at))
				if top - floor_at > SLACK:
					these["up"] = int(these["up"]) + 1
					(these["to"] as Array).append(top)
	var said := PackedStringArray()
	for name: String in named:
		var these: Dictionary = named[name]
		var gaps: Array = these["gaps"]
		var open: int = 0
		for gap: Array[Vector2i] in gaps:
			open += gap.size()
		var up: int = these["up"]
		if up < maxi(LEAST, ceili(open * SHARE)):
			continue
		var to: Array = these["to"]
		to.sort()
		var size: String = "%s square studs in %d places" % [_num(open / 4.0), gaps.size()]
		if gaps.size() == 1:
			var where: Rect2i = _bounds(_as_keys(gaps[0]))
			size = "%s x %s studs" % [_num(where.size.x / 2.0), _num(where.size.y / 2.0)]
		said.append("%s (planned open, %s): built up over %d%% of it, to about %d plates."
			% [name, size, roundi(100.0 * up / open), int(to[to.size() / 2])])
	return said


static func _as_keys(columns: Array[Vector2i]) -> Dictionary:
	var out: Dictionary = {}
	for column: Vector2i in columns:
		out[column] = true
	return out


## A gap named by the volumes whose columns touch it: "between the cab and
## the hopper", "beside the tower", "round the rotunda" for the corners a
## round volume leaves in its own box.
static func _beside(gap: Array[Vector2i], volumes: Array, planned: Dictionary) -> String:
	var near: Dictionary = {}
	for column: Vector2i in gap:
		for step: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
			var other: Vector2i = column + step
			if planned.has(other):
				var name: String = volumes[int((planned[other] as Array)[2])]["name"]
				near[name] = int(near.get(name, 0)) + 1
	var order: Dictionary = {}
	for n: int in volumes.size():
		order[str(volumes[n]["name"])] = n
	var names: Array = near.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(near[a]) > int(near[b]) or (int(near[a]) == int(near[b])
			and int(order.get(a, 0)) < int(order.get(b, 0))))
	if names.size() == 1:
		for one: Dictionary in volumes:
			if one["name"] == names[0] and one["round"]:
				return "round the %s" % names[0]
		return "beside the %s" % names[0]
	if names.size() >= 2:
		return "between the %s and the %s" % [names[0], names[1]]
	return "inside the plan"


## The build standing past the plan's box, when it is more than a figure or
## a lamp beside it: how much, and to which side.
static func _outside_checked(planned: Dictionary, standing: Dictionary) -> String:
	var box: Rect2i = _bounds(planned).grow(2)
	var out: Array[Vector2i] = []
	for column: Vector2i in standing:
		if not box.has_point(column):
			out.append(column)
	if out.size() < maxi(LEAST * 2, ceili(planned.size() * SHARE)):
		return ""
	var sides := {"the front": 0, "the back": 0, "the left": 0, "the right": 0}
	for column: Vector2i in out:
		if column.y >= box.end.y:
			sides["the front"] += 1
		elif column.y < box.position.y:
			sides["the back"] += 1
		elif column.x < box.position.x:
			sides["the left"] += 1
		else:
			sides["the right"] += 1
	var most: String = "the front"
	for side: String in sides:
		if int(sides[side]) > int(sides[most]):
			most = side
	return ("The build reaches past the plan: %s square studs of it stand outside the "
		% _num(out.size() / 4.0) + "planned volumes' box, most at %s." % most)


## How big the build stands: [width, depth in studs, height in plates].
static func _box_of(standing: Dictionary, tops: Dictionary, floor_at: int) -> Array:
	if standing.is_empty():
		return [0.0, 0.0, 0.0]
	var box: Rect2i = _bounds(standing)
	var high: int = floor_at
	for column: Vector2i in standing:
		high = maxi(high, int(tops[column]))
	return [box.size.x / 2.0, box.size.y / 2.0, float(high - floor_at)]


## What a build is told of its massing against the plan [param plan]
## ({"volumes", "front", "side"}) given what check() found.
static func said_check(plan: Dictionary, found: Dictionary) -> String:
	var volumes: Array = plan.get("volumes", [])
	var lines: PackedStringArray = found.get("lines", PackedStringArray())
	var box: Array = found.get("box", [0, 0, 0])
	var planned: Array = found.get("planned_box", [0, 0, 0])
	var moved: Vector2 = found.get("moved", Vector2.ZERO)
	var said := PackedStringArray()
	var sizes: String = ("Built %s x %s studs and %s plates; planned %s x %s and %s. It fills %d%% of "
		% [_num(float(box[0])), _num(float(box[1])), _num(float(box[2])), _num(float(planned[0])),
			_num(float(planned[1])), _num(float(planned[2])),
			roundi(float(found.get("fill", 0.0)) * 100.0)]
		+ "its box; the plan, %d%%." % roundi(float(found.get("planned_fill", 0.0)) * 100.0))
	var where: String = "" if moved == Vector2.ZERO else (" (read with the plan moved %s studs "
		% _num(moved.x) + "across and %s deep, to where the build stands)" % _num(moved.y))
	if lines.is_empty():
		said.append("Massing: built as planned%s: the %s, each there at its height, and the " % [
			where, _listed(found.get("kept", PackedStringArray()))]
			+ "setbacks, the gaps and the space under an overhang left open. " + sizes)
	else:
		var kept: PackedStringArray = found.get("kept", PackedStringArray())
		said.append("Massing, against the plan%s: %d of %d volumes as planned%s.\n  - %s\n%s" % [
			where, kept.size(), volumes.size(), " (the %s)" % _listed(kept) if not kept.is_empty()
				else "", "\n  - ".join(lines), sizes]
			+ "\nSettle each before the detail, which goes inside the massing: bring the build "
			+ "back to the plan (edit_model, or submit_design again), or keep it and say why, "
			+ "and plan_massing the volumes as they now are, so the next build is read "
			+ "against those.")
	var views := PackedStringArray()
	for view: Array in [["from the front", plan.get("front", "")], ["from the side", plan.get("side", "")]]:
		if not str(view[1]).strip_edges().is_empty():
			views.append("%s as: %s" % [view[0], str(view[1]).strip_edges()])
	if not views.is_empty():
		said.append("You planned it to read %s. view_model \"front\" and \"side\" show whether "
			% "; and ".join(views) + "it does.")
	return "\n".join(said)


static func _listed(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## The plan's span along [param axis] ("x", "z" or "y") over all its volumes.
static func _span(volumes: Array, axis: String) -> float:
	var low: float = INF
	var high: float = -INF
	for one: Dictionary in volumes:
		var along: Vector2 = one[axis]
		low = minf(low, along.x)
		high = maxf(high, along.y)
	return high - low if high > low else 0.0


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, 0.1))
