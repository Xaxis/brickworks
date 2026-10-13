## Real sets read as mechanisms (docs/MECHANISMS.md, P1a): every body, joint
## and gear mesh of the OMR's gear-heaviest Technic sets, and whether any
## gear is left floating, turning on nothing the reading found.
##
##   godot --headless --path . --script src/dev/mechanism_sets.gd
##   godot --headless --path . --script src/dev/mechanism_sets.gd -- vendor/omr/files/42070-1.mpd
##
## A floating gear has to be one of two things the file itself says, and
## each is said:
##   - a near miss: the file stands the gear a little off its axle (more
##     than the reading's 1.5 LDU, less than 4), which the reading reports
##     rather than mends;
##   - apart: in a group of parts that touches no connector of the rest of
##     the model (a second model in the file, or a wheel carried round its
##     rim by rollers). The group is read again on its own, its largest
##     body its ground, and nothing with a gear in it may float there.
## Anything else is a failure, said with what stands on its axis and the
## holes its axles nearly turn in, so the reason can be read off.
##
## Needs vendor/omr (tools/omr.py fetch): skipped, and said, without it.
## The default sets are 42055 (140 gears) and 42082 (135), the two with the
## most. Not in the suite.
extends SceneTree

const DEFAULT := ["res://vendor/omr/files/42055-1.mpd", "res://vendor/omr/files/42082-1.mpd"]
## A file's gear stands off its axle by more than the reading allows and
## less than this: a near miss, LDU.
const NEAR := 4.0

var _library: PartLibrary
var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var files: Array = Array(OS.get_cmdline_user_args())
	if files.is_empty():
		files = DEFAULT
	var read: int = 0
	for path: String in files:
		if not FileAccess.file_exists(path):
			print("  (no %s: tools/omr.py fetch brings the sets; skipped)" % path)
			continue
		_read(path)
		read += 1
	print("")
	if _failures == 0:
		print("mechanism sets: %d read, every gear on what it turns on or said why not" % read)
	else:
		print("mechanism sets: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _read(path: String) -> void:
	print("  %s" % path.get_file())
	var started: int = Time.get_ticks_msec()
	var list: Array = []
	var unknown: Dictionary = {}
	for placement: LdrModel.Placement in LdrModel.load_file(path).flatten():
		var id: String = _part_id(placement.part_id)
		if not _library.parts.has(id):
			unknown[id] = int(unknown.get(id, 0)) + 1
		list.append({"part": id, "at": placement.transform, "mesh": _library.mesh_for(id)})
	var model: Mechanism = Mechanism.build(list)
	var took: int = Time.get_ticks_msec() - started
	print("    %s; read in %.1f s" % [model.summary(), float(took) / 1000.0])
	if not unknown.is_empty():
		print("    not in the catalogue, so not read: %s" % str(unknown))
	for one: Array in model.unseated:
		print("    unseated: %s" % one[1])
	var floating: Array = model.floating_gears()
	var near: int = 0
	var apart: int = 0
	var unexplained: int = 0
	var groups_read: Dictionary = {}
	for body: int in floating:
		var miss: String = _near_miss(model, body)
		if not miss.is_empty():
			near += 1
			print("    near miss: %s" % miss)
			continue
		var cluster: Array = _cluster(model, body)
		var touch: Dictionary = _touching(model, cluster)
		if not touch["ground"]:
			apart += 1
			var root: int = cluster.min()
			if not groups_read.has(root):
				groups_read[root] = true
				_read_apart(model, cluster, touch["bodies"])
			continue
		unexplained += 1
		print("    floating: body %d: %s" % [body, model.parts_said(body)])
		for line: String in touch["lines"]:
			print("      touches: " + line)
		for gear: Mechanism.Gear in model.gears:
			if gear.body == body:
				print("      %s on its axis: %s" % [gear.part, _on_axis(model, gear)])
		for line: String in _shafts_near(model, body):
			print("      " + line)
	_check("%s: %d gears, %d meshes; of %d floating, %d near misses the file draws and %d apart, "
		% [path.get_file(), model.gears.size(), model.couplings.size(), floating.size(), near, apart]
		+ "none unexplained (%d)" % unexplained, unexplained == 0)
	# Turn it from each turning body with a gear on it: a drivetrain read
	# whole goes round from its inputs, and nothing locks.
	var moved: int = 0
	var tried: int = 0
	var locked: Array = []
	for gear: Mechanism.Gear in model.gears:
		if model.joint_of(gear.body) == null or tried >= 12:
			continue
		tried += 1
		var result: Dictionary = model.solve({gear.body: 1.0})
		if result["locked"]:
			locked.append("%s: %s" % [gear.part, str(result["culprits"])])
			continue
		var turning: int = 0
		for joint: Mechanism.Joint in model.tree:
			if absf(joint.rate) > 1e-9:
				turning += 1
		moved = maxi(moved, turning)
	print("    from %d inputs: at most %d joints turn; locked from %d%s" % [tried, moved,
		locked.size(), (": " + "; ".join(locked.slice(0, 4))) if not locked.is_empty() else ""])


## A group that touches nothing of the rest, read on its own with what it
## touches (a tyre on its rim): its largest body the ground, and no gear
## in it floating.
func _read_apart(model: Mechanism, cluster: Array, touched: Array) -> void:
	var list: Array = []
	var gears: int = 0
	for body: int in cluster + touched:
		for key: int in model.bodies.get(body, []):
			var piece: Mechanism.Piece = model.parts[key]
			list.append({"key": key, "part": piece.part, "at": piece.at, "mesh": piece.mesh})
			if not Mechanism.spec_of(piece.part).is_empty():
				gears += 1
	var own: Mechanism = Mechanism.build(list)
	var biggest: String = own.parts_said(own.ground).left(160)
	_check("    apart: %d parts with %d gears touch no connector of the rest; read on their own "
		% [list.size(), gears] + "(the ground %s) %d meshes and %d gears floating" % [biggest,
		own.couplings.size(), own.floating_gears().size()], own.floating_gears().is_empty())
	for body: int in own.floating_gears():
		print("      floating there: %s" % own.parts_said(body))


## Whether a floating body's gear stands a little off an axle or pin that
## runs its way: said, or "".
func _near_miss(model: Mechanism, body: int) -> String:
	for gear: Mechanism.Gear in model.gears:
		if gear.body != body:
			continue
		for key: int in model.parts:
			if model.body_of(key) == body:
				continue
			var piece: Mechanism.Piece = model.parts[key]
			if piece.mesh == null:
				continue
			for bit: Array in Mechanism._shaft_of(piece.mesh):
				var origin: Vector3 = piece.at * (bit[1] as Vector3)
				var way: Vector3 = (piece.at.basis * (bit[2] as Vector3)).normalized()
				if absf(way.dot(gear.axis)) < 0.99:
					continue
				var gap: Vector3 = (model.parts[gear.key] as Mechanism.Piece).at.origin - origin
				var along: float = gap.dot(way)
				var off: float = (gap - way * along).length()
				if off > Mechanism.LINE_SLACK and off <= NEAR and along >= float(bit[3]) \
						and along <= float(bit[4]):
					return "%s stands %.1f LDU off the %s it is on, %s, in the file" % [gear.part, off,
						bit[0], piece.part]
	return ""


## Where a group's parts touch any other's: each pair of their connectors
## within 2 LDU, said once per pair of parts. {lines, ground (whether any
## is the ground's), bodies (the others touched)}.
func _touching(model: Mechanism, cluster: Array) -> Dictionary:
	var in_cluster: Dictionary = {}
	for body: int in cluster:
		in_cluster[body] = true
	var others: Dictionary = {}   ## cell -> [key, kind, at]
	for key: int in model.parts:
		if in_cluster.has(model.body_of(key)):
			continue
		var piece: Mechanism.Piece = model.parts[key]
		if piece.mesh == null:
			continue
		for connector: Lbm.Connector in piece.mesh.connectors:
			var at: Vector3 = piece.at * (connector.position + connector.axis * connector.length * 0.5)
			var cell := Vector3i(floori(at.x / 10.0), floori(at.y / 10.0), floori(at.z / 10.0))
			if not others.has(cell):
				others[cell] = []
			(others[cell] as Array).append([key, connector.kind, at])
	var lines := PackedStringArray()
	var seen: Dictionary = {}
	var ground: bool = false
	var bodies: Dictionary = {}
	for body: int in cluster:
		for key: int in model.bodies.get(body, []):
			var piece: Mechanism.Piece = model.parts[key]
			if piece.mesh == null:
				continue
			for connector: Lbm.Connector in piece.mesh.connectors:
				var at: Vector3 = piece.at * (connector.position + connector.axis * connector.length * 0.5)
				var cell := Vector3i(floori(at.x / 10.0), floori(at.y / 10.0), floori(at.z / 10.0))
				for dx: int in [-1, 0, 1]:
					for dy: int in [-1, 0, 1]:
						for dz: int in [-1, 0, 1]:
							for row: Array in others.get(cell + Vector3i(dx, dy, dz), []):
								if (row[2] as Vector3).distance_to(at) > 2.0:
									continue
								var theirs: int = model.body_of(row[0])
								ground = ground or theirs == model.ground
								bodies[theirs] = true
								var pair: String = "%s %s|%s %s" % [piece.part, connector.kind,
									(model.parts[row[0]] as Mechanism.Piece).part, row[1]]
								if seen.has(pair) or lines.size() >= 12:
									continue
								seen[pair] = true
								lines.append("%s's %s at %s, %s's %s (%s)" % [piece.part, connector.kind,
									at.snapped(Vector3.ONE), (model.parts[row[0]] as Mechanism.Piece).part,
									row[1], "the ground" if theirs == model.ground else "body %d" % theirs])
	return {"lines": lines, "ground": ground, "bodies": bodies.keys()}


## The bodies joints join [param body] to, it among them.
func _cluster(model: Mechanism, body: int) -> Array:
	var seen: Dictionary = {body: true}
	var frontier: Array = [body]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for joint: Mechanism.Joint in model.joints:
			var other: int = joint.b if joint.a == at else (joint.a if joint.b == at else -1)
			if other >= 0 and not seen.has(other):
				seen[other] = true
				frontier.append(other)
	return seen.keys()


## For each axle or pin in a floating body, the holes of other parts near
## its line: what it nearly turns in, and how far off it is.
func _shafts_near(model: Mechanism, body: int) -> PackedStringArray:
	var out := PackedStringArray()
	for key: int in model.bodies.get(body, []):
		var piece: Mechanism.Piece = model.parts[key]
		if piece.mesh == null:
			continue
		for bit: Array in Mechanism._shaft_of(piece.mesh):
			var origin: Vector3 = piece.at * (bit[1] as Vector3)
			var way: Vector3 = (piece.at.basis * (bit[2] as Vector3)).normalized()
			var near := PackedStringArray()
			for other: int in model.parts:
				if model.body_of(other) == body:
					continue
				var there: Mechanism.Piece = model.parts[other]
				if there.mesh == null or there.at.origin.distance_to(origin) > 200.0:
					continue
				for connector: Lbm.Connector in there.mesh.connectors:
					if connector.kind not in ["axle_hole", "pin_hole", "bore"] \
							or (connector.kind == "bore" and connector.radius > 9.0):
						continue
					var at: Vector3 = there.at * (connector.position + connector.axis * connector.length * 0.5)
					var gap: Vector3 = at - origin
					var along: float = gap.dot(way)
					var off: float = (gap - way * along).length()
					if off > NEAR or along < float(bit[3]) - 4.0 or along > float(bit[4]) + 4.0:
						continue
					var dot: float = absf((there.at.basis * connector.axis).normalized().dot(way))
					near.append("%s %s %.1f off, %.0f° across (body %d)" % [there.part, connector.kind,
						off, rad_to_deg(acos(clampf(dot, 0.0, 1.0))), model.body_of(other)])
			out.append("%s (%s): %s" % [piece.part, bit[0], ", ".join(near) if not near.is_empty()
				else "no hole near its line"])
	return out


## A part id as the catalogue has it: an OMR file carries parts that were
## unofficial when it was drawn as "42055 - 24121".
func _part_id(id: String) -> String:
	if _library.parts.has(id):
		return id
	var cut: int = id.find(" - ")
	if cut > 0 and _library.parts.has(id.substr(cut + 3)):
		return id.substr(cut + 3)
	return id


## What stands on a gear's axis within four studs: each part and how far
## along, so a floating gear says what it should have turned on.
func _on_axis(model: Mechanism, gear: Mechanism.Gear) -> String:
	var said: PackedStringArray = []
	for key: int in model.parts:
		if key == gear.key:
			continue
		var piece: Mechanism.Piece = model.parts[key]
		var gap: Vector3 = piece.at.origin - gear.centre
		var along: float = gap.dot(gear.axis)
		if absf(along) <= 80.0 and (gap - gear.axis * along).length() < 1.5:
			said.append("%s at %+.0f" % [piece.part, along])
	return ", ".join(said) if not said.is_empty() else "nothing"
