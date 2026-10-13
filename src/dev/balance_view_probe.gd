## Tools, Check stability's Balance readout in the real scene, as a person
## sees it: an arm reaching far past a small base, held by one stud, checked.
## The status bar says it tips and what to add, the support polygon and the
## centre of mass are drawn on the floor, and the overloaded joint is red.
## Then the counterweight it asks for is put on, checked again, and it
## stands. And an arm on a turntable over a narrow base, which stands as
## built, is swept round and reported at the pose where it tips.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 \
##     --script src/dev/balance_view_probe.gd
##
## Pictures in shots/balance/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_main.call("clear_model")
	await _frames(10)

	print("  an arm 18 studs past a 6x6 base, on one stud")
	var base: int = _put("3958", 0, 0, 0)
	var top: float = _top(base)
	var post: int = 0
	for _n: int in 4:
		post = _put("3005", 50, top, 0)
		top = _top(post)
	_put("3034", 120, top, 0)
	_put("3034", 280, top, 0)
	_put("3034", 200, top + 8.0, 0)
	_put("3034", 340, top + 8.0, 0)
	await _frames(5)
	_camera.frame(AABB(Vector3(-80, 0, -80), Vector3(520, 160, 160)), 1.15)
	await _frames(30)

	_check("Tools has Check stability", _shell.can("stability"))
	_shell.run("stability")
	_check("...and the Working line is up while it weighs (%s)" % (
		Working.current().words if Working.current() != null else "nothing"), Working.is_busy())
	await _weighed()
	var report: Balance.Report = _shell.balance_shown
	var line: String = (_shell.status.fields() as Dictionary)["line"]
	print("    status: %s" % line)
	_check("the status bar says it tips, by how much and what to add",
		line.contains("Tips over") and line.contains("past the right edge") and line.contains(" g ("))
	var mark: BalanceMark = _shell._balance_mark
	_check("the support polygon and the centre of mass are on the floor, in red",
		mark != null and mark.visible and mark.colour() == BalanceMark.TIPS
		and report.support.size() >= 4)
	var tinted: Dictionary = _world.tinted_ids()
	_check("...and the joint on one stud is tinted (%d parts)" % tinted.size(),
		report.over >= 1 and not tinted.is_empty())
	await _shot("1_tips")
	# The words stay while the marks do, after the message itself has gone.
	await create_timer(4.5).timeout
	line = (_shell.status.fields() as Dictionary)["line"]
	_check("four seconds on, the line still reads the balance", line.begins_with("Tips over"))

	print("  the counterweight it asks for, put on")
	var each: float = Stability.grams(_library.parts.get("3001"))
	var bricks: int = ceili(report.counterweight / each)
	var at: Vector2 = report.counterweight_at
	var stack: float = _top(base)
	for _n: int in bricks:
		stack = _top(_put("3001", roundf(at.x / 20.0) * 20.0, stack, roundf(at.y / 20.0) * 20.0))
	await _frames(5)
	_check("the change takes the marks and the tint away", not mark.visible
		and _world.tinted_ids().is_empty())
	_camera.frame(AABB(Vector3(-80, 0, -80), Vector3(520, 260, 160)), 1.15)
	await _frames(20)
	_shell.run("stability")
	await _weighed()
	report = _shell.balance_shown
	line = (_shell.status.fields() as Dictionary)["line"]
	print("    status: %s" % line)
	_check("with %d 2x4 bricks there it stands, and says so in green" % bricks,
		report.stands() and line.contains("Stands") and mark.visible
		and mark.colour() == BalanceMark.GOOD)
	await _shot("2_stands")

	print("  an arm on a turntable over a narrow base, swept round")
	_main.call("clear_model")
	await _frames(10)
	var narrow: int = _put("3034", 0, 0, 0)
	_put("3680", 0, _top(narrow), 0)
	var turn: int = _put("3679", 0, _top(narrow), 0, "Arm#1")
	var arm: int = _put("3034", 60, _top(turn), 0, "Arm#1")
	_put("3003", 120, _top(arm), 0, "Arm#1")
	var rest: Transform3D = _world.get_brick(arm).transform
	_camera.frame(AABB(Vector3(-100, 0, -160), Vector3(260, 80, 320)), 1.1)
	await _frames(20)
	_shell.run("stability")
	await _weighed()
	report = _shell.balance_shown
	line = (_shell.status.fields() as Dictionary)["line"]
	print("    status: %s" % line)
	_check("it stands as built and tips swung across its base, and says at which pose",
		report.rest_margin > 0.0 and not report.stands() and line.contains("with Arm at ")
		and line.contains("of 24 poses"))
	_check("...the model itself not moved by the sweep",
		_world.get_brick(arm).transform.is_equal_approx(rest))
	await _shot("3_swept")

	print("")
	if _failures == 0:
		print("balance view: the readout, the polygon and the centre of mass on the floor, "
			+ "the overloaded joint in red, the counterweight it asked for holds it up, and "
			+ "the worst pose of a sweep is found")
	else:
		print("balance view: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _weighed() -> void:
	for _n: int in 600:
		await process_frame
		if not Working.is_busy() and _shell.balance_shown != null:
			break
	await _frames(5)


## As balance_probe puts a part: its footprint's middle at x, z, its body's
## bottom at [param bottom].
func _put(part_id: String, x: float, bottom: float, z: float, unit: String = "") -> int:
	var part: Lbm.PartMesh = _library.mesh_for(part_id)
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	var basis := Basis.IDENTITY
	if info.size.x < info.size.z:
		basis = Basis(Vector3.UP, PI * 0.5)
	var box: AABB = (Transform3D(basis, Vector3.ZERO) * part.bounds).abs()
	var middle: Vector3 = box.get_center()
	var at := Transform3D(basis, Vector3(roundf(x - middle.x), roundf(bottom - box.position.y),
		roundf(z - middle.z)))
	var id: int = _world.add_brick(part_id, 4 if part_id == "3034" else 72, at)
	_builder.register(id, part_id, at)
	if not unit.is_empty():
		_world.get_brick(id).unit = unit
		_world.get_brick(id).group = Assemblies.group_of(unit)
	return id


func _top(id: int) -> float:
	var brick: BrickWorld.Brick = _world.get_brick(id)
	var box: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
	return box.end.y - (4.0 if _library.parts[brick.part_id].stud_count > 0 else 0.0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/balance"))
	var path: String = "res://shots/balance/%s.png" % name
	image.save_png(ProjectSettings.globalize_path(path))
	print("    picture: shots/balance/%s.png" % name)
