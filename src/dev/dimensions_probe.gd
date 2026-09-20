## Measure the geometry that actually shipped, in millimetres.
##
##   godot --headless --path . --script src/dev/dimensions_probe.gd
##
## The claim this project is built on is that a part is the size a real
## part is. That claim was doubted, fairly, and answering it by quoting
## constants proves nothing: the constants are what the converter was
## *told*, and the question is what came out the other end. So this
## measures built meshes and connector positions and converts to
## millimetres, which is the unit the answer is checkable in — against a
## brick on the desk and a ruler.
##
## The figures are LDraw's nominal ones, which is what the library models:
## a 1 x 1 brick is exactly 8.0 mm square rather than the 7.8 mm a real
## one is moulded at. The 0.2 mm is clearance, deliberately left out so
## that parts meet exactly instead of leaving a gap that accumulates over
## a long wall. Stud height is the other known difference — LDraw draws
## 1.6 mm where LEGO moulds 1.8 mm — and it is listed here as a
## difference rather than hidden, because a check that quietly accepts
## what it finds is not a check.
extends SceneTree

const MM := 0.4          ## one LDU
const TOLERANCE := 0.001 ## mm; anything larger is a real discrepancy

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("  measured from the built geometry, in millimetres:")
	print("")

	_box(library, "3005", "1 x 1 brick", Vector3(8.0, 9.6, 8.0))
	_box(library, "3004", "1 x 2 brick", Vector3(16.0, 9.6, 8.0))
	# 2 x 4 studs is 16 x 32 mm. Writing 80 x 40 here — the LDU figures
	# with a millimetre label on them — is the mistake this whole probe
	# exists to catch, and it caught it in the probe first.
	_box(library, "3001", "2 x 4 brick", Vector3(32.0, 9.6, 16.0))
	_box(library, "3024", "1 x 1 plate", Vector3(8.0, 3.2, 8.0))
	_box(library, "3023b", "1 x 2 plate", Vector3(16.0, 3.2, 8.0))
	_box(library, "3070b", "1 x 1 tile", Vector3(8.0, 3.2, 8.0))

	print("")
	_studs(library, "3001", "2 x 4 brick")
	print("")
	_stud_size(library, "3005")

	print("")
	print("  three plates to a brick: %s"
		% ("yes" if is_equal_approx(3.2 * 3, 9.6) else "NO"))

	print("")
	print("%d measurement(s) off" % _failures if _failures
		else "every measured part is the nominal size, exactly")
	quit(1 if _failures else 0)


## The part's extent, less the studs on top — a brick is 9.6 mm tall and
## the studs stand proud of that.
func _box(library: PartLibrary, part_id: String, what: String,
		expected: Vector3) -> void:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null:
		_report(what, "no geometry", false)
		return

	var box: AABB = mesh.bounds
	# These meshes are +Y up: the conversion from LDraw already negated
	# Y and Z. So the underside is box.position.y and the tips of the
	# studs are box.end.y, and a brick's quoted height is the body alone
	# — the studs stand proud of it.
	var size := Vector3(
		box.size.x * MM,
		_body_height(mesh) * MM,
		box.size.z * MM)

	var ok: bool = (absf(size.x - expected.x) < TOLERANCE
		and absf(size.y - expected.y) < TOLERANCE
		and absf(size.z - expected.z) < TOLERANCE)
	_report("%-14s %6.2f x %5.2f x %6.2f mm" % [what, size.x, size.y, size.z],
		"expected %.2f x %.2f x %.2f" % [expected.x, expected.y, expected.z], ok)


## The body, not counting the studs on top of it, in LDU. A stud
## connector sits on the surface the studs rise from, which is exactly
## the top of the body.
func _body_height(mesh: Lbm.PartMesh) -> float:
	var surface: float = -INF
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "stud":
			surface = maxf(surface, connector.position.y)
	if is_inf(surface):
		return mesh.bounds.size.y
	return surface - mesh.bounds.position.y


## How far the studs stand above the body, in LDU.
func _stud_height(mesh: Lbm.PartMesh) -> float:
	return mesh.bounds.size.y - _body_height(mesh)


## Stud centres, which is what decides whether two parts line up.
func _studs(library: PartLibrary, part_id: String, what: String) -> void:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null:
		_report(what, "no geometry", false)
		return

	var xs: Array[float] = []
	for connector: Lbm.Connector in mesh.connectors:
		if connector.kind == "stud" and not xs.has(connector.position.x):
			xs.append(connector.position.x)
	xs.sort()
	if xs.size() < 2:
		_report("%s stud pitch" % what, "fewer than two studs across", false)
		return

	var gaps := PackedFloat32Array()
	for i: int in range(1, xs.size()):
		gaps.append((xs[i] - xs[i - 1]) * MM)
	var even: bool = true
	for gap: float in gaps:
		if absf(gap - 8.0) > TOLERANCE:
			even = false
	_report("stud pitch    %6.2f mm across %d studs" % [gaps[0], xs.size()],
		"expected 8.00 mm, evenly spaced", even)


func _stud_size(library: PartLibrary, part_id: String) -> void:
	var mesh: Lbm.PartMesh = library.mesh_for(part_id)
	if mesh == null:
		return
	var height: float = _stud_height(mesh) * MM
	# Stated, not asserted. LDraw draws a 1.6 mm stud where LEGO moulds
	# 1.8 mm, and the whole library is consistent with itself — changing
	# it here would put every part out of step with every other.
	print("  --   stud height  %6.2f mm   (LEGO moulds 1.8; LDraw draws "
		% height + "1.6 — a convention of the library, not an error)")


func _report(what: String, detail: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s  — %s" % [what, detail])
		_failures += 1
