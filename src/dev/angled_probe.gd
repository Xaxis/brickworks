## Can the system hold a part that is not square to the grid?
##
## Every placement this app makes is one of 24 axis-aligned
## orientations, but an .ldr written by somebody else can carry any
## rotation at all, and the reader parses the full matrix. So the
## question is what happens to one once it is in.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	await process_frame

	# A brick turned 30 degrees about the upright axis — the angle a
	# nacelle pylon or a hinged wing sits at, and one no placement in
	# this app can express.
	var angled := Transform3D(
		Basis(Vector3.UP, deg_to_rad(30.0)), Vector3(0, 24, 0))
	var id: int = world.add_brick("3001", 4, angled)
	if id == 0:
		print("  FAIL  could not place it at all")
		quit(1)
		return

	var kept: Basis = world.get_brick(id).transform.basis
	_check("an angled brick is stored at the angle it was given",
		_angle_of(kept) > 25.0 and _angle_of(kept) < 35.0)

	# Now turn the whole model a quarter, which is what Q and E do.
	world.rotate_model(1)
	await process_frame
	var after: Basis = world.get_brick(id).transform.basis
	var turned: float = _angle_of(after)
	_check("...and survives the model being turned, now %.0f deg off"
		% fmod(turned, 90.0),
		not is_equal_approx(fmod(turned + 360.0, 90.0), 0.0))

	# And the drift the old snap existed to prevent. Four quarter turns
	# must put an ordinary brick back exactly where it started, or a
	# model stops meeting the grid it was built on.
	var square := Transform3D(Basis.IDENTITY, Vector3(40, 24, 80))
	var plain: int = world.add_brick("3001", 1, square)
	for _n: int in 4:
		world.rotate_model(1)
		await process_frame
	var back: Transform3D = world.get_brick(plain).transform
	_check("four quarter turns leave an ordinary brick exactly as it was",
		back.origin.is_equal_approx(square.origin)
			and back.basis.is_equal_approx(Basis.IDENTITY))

	print("")
	if _failures == 0:
		print("angled geometry survives")
	else:
		print("%d FAILURE(S) — angled geometry is flattened" % _failures)
	quit(1 if _failures else 0)


## How far this orientation is from being square to the grid.
static func _angle_of(basis: Basis) -> float:
	var forward: Vector3 = (basis * Vector3.BACK).normalized()
	return rad_to_deg(absf(atan2(forward.x, forward.z)))


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
