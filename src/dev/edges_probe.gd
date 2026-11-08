## View › Edges and studs (APP_UX6 #19, edges): the seam along every part's
## edges, and the studs, each drawn in the window or not.
##
##   godot --path . --resolution 1400x900 --script src/dev/edges_probe.gd [-- --shots=DIR]
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in (made with the
## admin key and a password, so no code is spent at the per-IP limit), the
## screen gone; the account deleted at the end. Needs .env (SUPABASE_URL,
## SUPABASE_SECRET_KEY).
##
## The bar, each measured on the window's own drawing of the model (its 3D
## alone, the interface's 2D left out of the picture):
##   - the default view: the example car as the app opens on it, framed by
##     View › Viewpoint › Default view, kept as default_view_WxH.png to be
##     compared byte for byte with an older build's (the same probe run
##     there); and the same again after Edges and Studs are each turned off
##     and on: every pixel the same;
##   - Edges: a wall of red and one of black 1 x 2 bricks in running bond,
##     square on: inside each wall's face, the pixels off its face's own
##     colour by more than [constant SEAM_LEVELS] of 255 — the seam. Drawn,
##     many; Edges off, 0;
##   - Studs: parts of every kind of stud (a brick, plates, a round plate's
##     ring, a hollow stud, an open stud, a jumper, a slope, studs on a side
##     and on four sides, a Technic brick's, a head's, a clear brick's) laid
##     in rows square on, each stud seen from its side: in the round each
##     stud stands in, the pixels unlike the same picture with no part in it.
##     Drawn, most of them; Studs off, 0. And every part in its place: each
##     brick where it stood, and outside the studs' rounds (and a few pixels
##     round them) no pixel changed;
##   - kept: both off by the View's rows, chosen from the menu with the keys
##     as a person does; then the app started again on the same data folder
##     (a headless run of this probe, --after-restart), which finds both off,
##     its rows unticked and its world drawing that way, and turns both on
##     again.
## And at each, a picture to look at: the car with each off.
extends SceneTree

const SEAM_LEVELS := 10
## What differs from the empty picture in a stud's round, levels of 255.
const DRAWN_LEVELS := 6
## Pixels kept off the edge of a stud's round and of a wall's face: FXAA
## and multisampling blend a pixel or two over every edge.
const INSET := 2.0

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _shell: Shell
var _out: String = "user://edges"
var _email: String = ""
var _password: String = ""
var _size: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
	if OS.get_cmdline_user_args().has("--after-restart"):
		await _after_restart()
		return
	var own_folder: bool = _own_data_folder()
	ShellPrefs.kept_by_a_check = own_folder
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_shell = _main.get("_shell")
	var window: Vector2i = root.get_window().size
	_size = "%dx%d" % [window.x, window.y]
	print("in a %s window" % _size)
	if not await _way_in():
		_finish()
		return

	await _default_view()
	await _edges()
	await _studs()
	await _the_car()
	await _kept(own_folder)
	_finish()


# -- the way in ---------------------------------------------------------------


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("edges")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify.
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- the default view -----------------------------------------------------------


## The example car as the app opens on it, the default view: the picture
## kept for an older build's to be laid beside, and the same picture after
## each of the View's rows is turned off and on again.
func _default_view() -> void:
	print("\n  the default view, as the app opens on the example car")
	_check("the example car is on the baseplate (%d parts)" % _world.brick_count(),
		_world.brick_count() > 20)
	_main.call("default_view")
	await _still()
	var first: Image = await _picture("default_view_" + _size)
	if _shell.command("edges") == null or _shell.command("studs") == null:
		_check("View › Edges and studs has its rows, Edges and Studs", false)
		return
	_check("Edges and Studs start ticked, the plastic as it is moulded",
		_ticked("edges") and _ticked("studs") and _shown(&"edges_shown") and _shown(&"studs_shown"))
	_shell.run("edges")
	await _frames(4)
	var no_edges: Image = await _picture("")
	_shell.run("edges")
	await _frames(4)
	var edges_back: Image = await _picture("")
	_shell.run("studs")
	await _drawn()
	var no_studs: Image = await _picture("")
	_shell.run("studs")
	await _drawn()
	var studs_back: Image = await _picture("")
	_check("Edges off changes the picture (%d px), and on again it is the first to the pixel (%d px differ)"
		% [_differing(first, no_edges, 0), _differing(first, edges_back, 0)],
		_differing(first, no_edges, 0) > 0 and _differing(first, edges_back, 0) == 0)
	_check("Studs off changes the picture (%d px), and on again it is the first to the pixel (%d px differ)"
		% [_differing(first, no_studs, 0), _differing(first, studs_back, 0)],
		_differing(first, no_studs, 0) > 0 and _differing(first, studs_back, 0) == 0)


# -- edges --------------------------------------------------------------------


## A red wall and a black one, square on: the seam inside each face, drawn
## and not.
func _edges() -> void:
	print("\n  Edges: two walls of 1 x 2 bricks in running bond, square on")
	await _empty_scene()
	var walls: Array[AABB] = []
	for wall: Array in [[4, 0.0], [0, 240.0]]:
		var colour: int = wall[0]
		var left: float = wall[1]
		for course: int in 6:
			var at: float = left
			var offset: bool = course % 2 == 1
			var pieces: Array = ["3005", "3004", "3004", "3004", "3004", "3005"] if offset \
				else ["3004", "3004", "3004", "3004", "3004"]
			for part: String in pieces:
				var wide: float = 20.0 if part == "3005" else 40.0
				_put(part, colour, Vector3(at + wide * 0.5, 24.0 * (course + 1), 0.0))
				at += wide
		walls.append(AABB(Vector3(left, 0.0, -10.0), Vector3(200.0, 144.0, 20.0)))
	await _square_on(AABB(Vector3(-10.0, -10.0, -10.0), Vector3(460.0, 170.0, 20.0)))
	var drawn: Image = await _picture("walls_edges_" + _size)
	await _choose("Edges")
	_check("View › Edges and studs › Edges, from the keys, turns the seam off (ticked: %s)"
		% _ticked("edges"), not _shown(&"edges_shown") and not _ticked("edges"))
	await _frames(4)
	var off: Image = await _picture("walls_no_edges_" + _size)
	for n: int in walls.size():
		var face: Rect2 = _inset(_face_rect(walls[n]), INSET + 2.0)
		var with_seam: int = _off_face(drawn, face)
		var without: int = _off_face(off, face)
		_check("the %s wall's face (%d x %d px): %d px of seam drawn, %d with Edges off"
			% [["red", "black"][n], face.size.x, face.size.y, with_seam, without],
			with_seam > 200 and without == 0)
	await _choose("Edges")
	_check("...and Edges again draws it (ticked: %s)" % _ticked("edges"),
		_shown(&"edges_shown") and _ticked("edges"))
	await _frames(4)
	var again: Image = await _picture("")
	_check("the walls drawn again as they were, to the pixel (%d px differ)"
		% _differing(drawn, again, 0), _differing(drawn, again, 0) == 0)


# -- studs --------------------------------------------------------------------


## Every kind of stud, seen from its side; each stud's round, with and
## without.
const STUD_PARTS: Array = [
	["3001", 4, 0], ["3024", 14, 0], ["6141", 1, 0], ["3062b", 2, 0], ["85861", 25, 0],
	["3794b", 71, 0], ["3039", 15, 0], ["87087", 4, 1], ["4733", 72, 1], ["30414", 1, 1],
	["3700", 0, 0], ["3626c", 14, 0], ["3065", 47, 0], ["3068b", 4, 0], ["3795", 2, 0],
]


func _studs() -> void:
	print("\n  Studs: every kind of stud, square on, each seen from its side")
	await _empty_scene()
	var placed: Array[int] = []
	var x: float = 0.0
	var y: float = 0.0
	for entry: Array in STUD_PARTS:
		var part: String = entry[0]
		var info: PartLibrary.PartInfo = _library().parts.get(part)
		if info == null:
			_check("%s is in the library" % part, false)
			continue
		var turn := Basis(Vector3.UP, PI * 0.5 * int(entry[2]))
		var box: AABB = Transform3D(turn, Vector3.ZERO) * info.bounds
		if x > 0.0 and x + box.size.x > 260.0:
			x = 0.0
			y += 50.0
		var at := Vector3(x - box.position.x, y - box.position.y, 0.0)
		var brick_id: int = _put(part, int(entry[1]), at, turn)
		if brick_id > 0:
			placed.append(brick_id)
		x += box.size.x + 30.0
	var everything: AABB = _world.model_bounds()
	await _square_on(everything.grow(12.0))
	var where: Dictionary = {}
	for brick_id: int in placed:
		where[brick_id] = _world.get_brick(brick_id).transform
	var bounds_before: AABB = _world.model_bounds()

	var drawn: Image = await _picture("studs_drawn_" + _size)
	var drawn_flat: Image = await _flat_picture("studs_drawn_flat_" + _size)
	_world.show_only({-1: true})
	await _frames(4)
	var empty: Image = await _picture("studs_none_" + _size)
	var empty_flat: Image = await _flat_picture("")
	_world.show_only({})
	await _frames(4)
	await _choose("Studs")
	_check("View › Edges and studs › Studs, from the keys, turns the studs off (ticked: %s)"
		% _ticked("studs"), not _shown(&"studs_shown") and not _ticked("studs"))
	await _drawn()
	var off: Image = await _picture("studs_off_" + _size)
	var off_flat: Image = await _flat_picture("studs_off_flat_" + _size)

	# Each stud seen from its side, its round on the screen.
	var view: Vector3 = -_camera.global_transform.basis.z
	var rounds: Array[PackedVector2Array] = []
	var kinds: Dictionary = {}
	var hidden_studs: int = 0
	# A stud facing the eye is seen as its end, over its part's face: gone,
	# that face is drawn there, and its shadow on the face goes with it. Its
	# end's round and a stud's height round it are left out of what is
	# measured as the part's body.
	var facing: Array[PackedVector2Array] = []
	for brick_id: int in placed:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var mesh: Lbm.PartMesh = _library().mesh_for(brick.part_id)
		var found: Array = _studs_of(mesh)
		for s: int in (found[0] as PackedVector3Array).size():
			var foot: Vector3 = brick.transform * (found[0] as PackedVector3Array)[s]
			var axis: Vector3 = (brick.transform.basis * (found[1] as PackedVector3Array)[s]).normalized()
			if absf(axis.dot(view)) > 0.1:
				hidden_studs += 1
				facing.append(_end_round(foot, axis, 11.0))
				continue
			rounds.append(_stud_round(foot, axis))
			kinds[brick.part_id] = int(kinds.get(brick.part_id, 0)) + 1
	var stud_px: int = 0
	var on_px: int = 0
	var off_px: int = 0
	for outline: PackedVector2Array in rounds:
		var counts: Vector3i = _in_round(outline, drawn, off, empty)
		stud_px += counts.x
		on_px += counts.y
		off_px += counts.z
	_check("%d studs seen from their side, of %d parts (%s); %d facing the eye left out"
		% [rounds.size(), kinds.size(), ", ".join(PackedStringArray(kinds.keys())), hidden_studs],
		rounds.size() >= 40 and kinds.size() >= 12)
	_check("drawn, %d of the %d px in their rounds are stud (%.0f%%); Studs off, %d"
		% [on_px, stud_px, 100.0 * on_px / maxf(1.0, stud_px), off_px],
		stud_px > 0 and on_px > stud_px * 0.6 and off_px == 0)

	# Every part in its place.
	var moved: int = 0
	for brick_id: int in where:
		if not _world.get_brick(brick_id).transform.is_equal_approx(where[brick_id]):
			moved += 1
	_check("every part where it stood (%d of %d moved), the model's box the same (%s)"
		% [moved, where.size(), str(_world.model_bounds())],
		moved == 0 and _world.model_bounds().is_equal_approx(bounds_before))
	var left_out: Array[PackedVector2Array] = rounds.duplicate()
	left_out.append_array(facing)
	# Where a part is drawn, read off pictures with no smoothing of edges and
	# no glow (_flat_picture): a smoothed edge is blended along its length,
	# so a stud standing on it changes the blend of pixels well away from it.
	var outside: Vector3i = _outside_rounds(drawn_flat, off_flat, empty_flat, left_out, 3.0,
		"studs_outside_" + _size)
	_check("outside the studs' rounds and 3 px round them, every part drawn where it was: %d px of %d covered by a part with the studs and not without, or the other way (%d px lit differently, the studs' own shadows)"
		% [outside.x, outside.z, outside.y], outside.x == 0)
	var ends: Vector3i = Vector3i.ZERO
	for outline: PackedVector2Array in facing:
		ends += _in_round(outline, drawn, off, drawn)
	print("    the %d studs facing the eye: %d px of their ends' rounds changed with Studs off"
		% [facing.size(), ends.z])
	var marked: Image = off.duplicate()
	for outline: PackedVector2Array in rounds:
		_outline(marked, outline, Color(1.0, 0.85, 0.1))
	marked.save_png(ProjectSettings.globalize_path(_out.path_join("studs_rounds_%s.png" % _size)))
	print("    picture: %s" % ProjectSettings.globalize_path(_out.path_join("studs_rounds_%s.png" % _size)))
	await _choose("Studs")
	_check("...and Studs again draws them (ticked: %s)" % _ticked("studs"),
		_shown(&"studs_shown") and _ticked("studs"))
	await _drawn()
	var again: Image = await _picture("")
	_check("the parts drawn again as they were, to the pixel (%d px differ)"
		% _differing(drawn, again, 0), _differing(drawn, again, 0) == 0)


## A stud's round as the screen has it: its sides and its top, from its foot
## along its axis, in the window's pixels.
func _stud_round(foot: Vector3, axis: Vector3) -> PackedVector2Array:
	var side: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = axis.cross(side).normalized()
	var points := PackedVector2Array()
	for n: int in 24:
		var turn: float = TAU * n / 24.0
		var out: Vector3 = (side * cos(turn) + other * sin(turn)) * 6.0
		for h: float in [0.2, 4.0]:
			points.append(_window_px(_camera.unproject_position(foot + out + axis * h)))
	return Geometry2D.convex_hull(points)


## The round a stud's end makes facing the eye, [param radius] LDU across
## its half, half way up the stud.
func _end_round(foot: Vector3, axis: Vector3, radius: float) -> PackedVector2Array:
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var other: Vector3 = axis.cross(side).normalized()
	var points := PackedVector2Array()
	for n: int in 24:
		var turn: float = TAU * n / 24.0
		points.append(_window_px(_camera.unproject_position(foot + axis * 2.0
			+ (side * cos(turn) + other * sin(turn)) * radius)))
	return Geometry2D.convex_hull(points)


## In [param outline] shrunk by [constant INSET]: its pixels, those of
## [param on] unlike [param empty], and those of [param off] unlike it.
func _in_round(outline: PackedVector2Array, on: Image, off: Image, empty: Image) -> Vector3i:
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(outline, -INSET)
	if inner.is_empty():
		return Vector3i.ZERO
	var shape: PackedVector2Array = inner[0]
	var box := Rect2(shape[0], Vector2.ZERO)
	for corner: Vector2 in shape:
		box = box.expand(corner)
	var counts := Vector3i.ZERO
	for py: int in range(maxi(0, floori(box.position.y)), mini(on.get_height(), ceili(box.end.y))):
		for px: int in range(maxi(0, floori(box.position.x)), mini(on.get_width(), ceili(box.end.x))):
			if not Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), shape):
				continue
			counts.x += 1
			if _most(on.get_pixel(px, py), empty.get_pixel(px, py)) > DRAWN_LEVELS:
				counts.y += 1
			if _most(off.get_pixel(px, py), empty.get_pixel(px, py)) > DRAWN_LEVELS:
				counts.z += 1
	return counts


## Outside every outline grown by [param margin], where [param a] and
## [param b] draw a part: [pixels a part covers in one and not the other,
## pixels lit differently, pixels looked at]. Whether a part covers a pixel
## is whether it is unlike [param empty] there at all, so the three are
## pictures drawn the same way with nothing that blends (_flat_picture). What is lit differently is
## the light the studs took: their shadows, their glow. A map of both is kept
## as [param map] (magenta covered or not, cyan lit), to look at.
func _outside_rounds(a: Image, b: Image, empty: Image, outlines: Array[PackedVector2Array],
		margin: float, map: String) -> Vector3i:
	var mask := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_L8)
	for outline: PackedVector2Array in outlines:
		var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(outline, margin)
		var shape: PackedVector2Array = grown[0] if not grown.is_empty() else outline
		var box := Rect2(shape[0], Vector2.ZERO)
		for corner: Vector2 in shape:
			box = box.expand(corner)
		for py: int in range(maxi(0, floori(box.position.y)), mini(a.get_height(), ceili(box.end.y))):
			for px: int in range(maxi(0, floori(box.position.x)), mini(a.get_width(), ceili(box.end.x))):
				if Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), shape):
					mask.set_pixel(px, py, Color.WHITE)
	var counts := Vector3i.ZERO
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	var de: PackedByteArray = empty.get_data()
	var dm: PackedByteArray = mask.get_data()
	var marked: Image = b.duplicate()
	for n: int in dm.size():
		if dm[n] > 0:
			continue
		counts.z += 1
		var at: int = n * 3
		var in_a: bool = _bytes_apart(da, de, at) > 0
		var in_b: bool = _bytes_apart(db, de, at) > 0
		if in_a != in_b:
			counts.x += 1
			marked.set_pixel(n % a.get_width(), n / a.get_width(), Color.MAGENTA)
		elif _bytes_apart(da, db, at) > DRAWN_LEVELS:
			counts.y += 1
			marked.set_pixel(n % a.get_width(), n / a.get_width(), Color.CYAN)
	for outline: PackedVector2Array in outlines:
		_outline(marked, outline, Color(1.0, 0.85, 0.1))
	var path: String = ProjectSettings.globalize_path(_out.path_join(map + ".png"))
	marked.save_png(path)
	print("    picture: %s" % path)
	return counts


func _bytes_apart(a: PackedByteArray, b: PackedByteArray, at: int) -> int:
	return maxi(absi(a[at] - b[at]), maxi(absi(a[at + 1] - b[at + 1]), absi(a[at + 2] - b[at + 2])))


# -- the car ------------------------------------------------------------------


## The example car with each off, to look at, and how long Studs off took on
## it the first time.
func _the_car() -> void:
	print("\n  the example car, each off, to look at")
	await _empty_scene()
	_main.call("_open", "res://models/car.ldr")
	for _n: int in 600:
		if _world.brick_count() >= 20 and not _world.is_being_laid():
			break
		await process_frame
	_main.call("default_view")
	await _still()
	await _picture("car_%s" % _size)
	var triangles_on: int = _triangles()
	var began: int = Time.get_ticks_msec()
	_shell.run("studs")
	await _drawn()
	var took: int = Time.get_ticks_msec() - began
	await _picture("car_no_studs_%s" % _size)
	var triangles_off: int = _triangles()
	_check("Studs off on the car (%d parts): %d triangles drawn to %d (%.0f%% fewer), in %d ms with the frames"
		% [_world.brick_count(), triangles_on, triangles_off,
			100.0 * (1.0 - float(triangles_off) / maxf(1.0, triangles_on)), took],
		triangles_off < triangles_on)
	_shell.run("edges")
	await _frames(4)
	await _picture("car_neither_%s" % _size)
	_shell.run("studs")
	await _drawn()
	await _picture("car_no_edges_%s" % _size)
	_shell.run("edges")
	await _frames(4)


func _triangles() -> int:
	var count: int = 0
	for child: Node in _world.get_children():
		var batch := child as MultiMeshInstance3D
		if batch != null and batch.multimesh != null and batch.multimesh.mesh != null:
			var mesh: Mesh = batch.multimesh.mesh
			if mesh.get_surface_count() > 0:
				count += mesh.surface_get_array_index_len(0) / 3 * maxi(0,
					batch.multimesh.visible_instance_count if batch.multimesh.visible_instance_count >= 0
					else batch.multimesh.instance_count)
	return count


# -- kept ---------------------------------------------------------------------


## Both off by the View's rows, then the app started again on this run's data
## folder: a run of its own finds them off and turns them on.
func _kept(own_folder: bool) -> void:
	print("\n  kept: both off, and the app started again")
	if not own_folder:
		_check("a data folder of this run's own to keep them in (run by tools/probe.sh)", false)
		return
	await _choose("Edges")
	await _choose("Studs")
	_check("both off by the View's rows (Edges %s, Studs %s)" % [_shown(&"edges_shown"),
		_shown(&"studs_shown")], not _shown(&"edges_shown") and not _shown(&"studs_shown"))
	var file := ConfigFile.new()
	var read: int = file.load(ViewPrefs.WHERE)
	_check("written to this machine's controls (%s): edges %s, studs %s" % [ViewPrefs.WHERE,
		file.get_value("view", "edges", "none"), file.get_value("view", "studs", "none")],
		read == OK and file.get_value("view", "edges", true) == false
		and file.get_value("view", "studs", true) == false)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", "res://src/dev/edges_probe.gd",
		"--", "--after-restart"], output, true)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("a run of its own, on the same data folder, passed (exit %d)" % code, code == 0)


## The run after the restart: both found off, then turned on again.
func _after_restart() -> void:
	ShellPrefs.kept_by_a_check = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	_world = _main.get("_world")
	_shell = _main.get("_shell")
	for _n: int in 30:
		await process_frame
	var file := ConfigFile.new()
	file.load(ViewPrefs.WHERE)
	_check("the app started again finds Edges and Studs off as they were left (edges %s, studs %s in %s)"
		% [file.get_value("view", "edges", "none"), file.get_value("view", "studs", "none"),
			ViewPrefs.WHERE], file.get_value("view", "edges", true) == false
		and file.get_value("view", "studs", true) == false)
	_check("...its world drawing that way, and the View's rows unticked",
		not _shown(&"edges_shown") and not _shown(&"studs_shown") and _shell.command("edges") != null
		and not _ticked("edges") and not _ticked("studs"))
	_shell.run("edges")
	_shell.run("studs")
	for _n: int in 10:
		await process_frame
	file = ConfigFile.new()
	file.load(ViewPrefs.WHERE)
	_check("turned on again, and kept so", _shown(&"edges_shown") and _shown(&"studs_shown")
		and file.get_value("view", "edges", false) == true
		and file.get_value("view", "studs", false) == true)
	_world.clear()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the View's rows, from the keys --------------------------------------------------


## View › Edges and studs › [param row], as a person chooses it from the
## keyboard: the View menu opened with a click, Down to Edges and studs,
## Right into it, Down to the row, Return.
func _choose(row: String) -> void:
	var view: MenuButton = null
	for button: MenuButton in _shell.get("_menus"):
		if button.text == "View":
			view = button
	if view == null:
		_check("the View menu", false)
		return
	await _click(view.get_global_rect().get_center())
	await _frames(6)
	var popup: PopupMenu = view.get_popup()
	if not popup.visible:
		view.show_popup()
		await _frames(6)
	var at: int = _row_of(popup, "Edges and studs")
	if at < 0:
		_check("View has a row Edges and studs", false)
		popup.hide()
		return
	for _n: int in 40:
		if popup.get_focused_item() == at:
			break
		await _key(KEY_DOWN)
	await _key(KEY_RIGHT)
	await _frames(4)
	var sub: PopupMenu = null
	for child: Node in popup.get_children():
		if child is PopupMenu and (child as PopupMenu).visible:
			sub = child
	if sub == null:
		_check("Edges and studs opens with Right", false)
		popup.hide()
		return
	await _shot_window("menu_%s_%s" % [row.to_lower(), _size])
	var target: int = _row_of(sub, row)
	for _n: int in 10:
		if sub.get_focused_item() == target:
			break
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	await _frames(4)
	if popup.visible:
		popup.hide()


func _row_of(popup: PopupMenu, words: String) -> int:
	for n: int in popup.item_count:
		if popup.get_item_text(n) == words:
			return n
	return -1


## Whether the window's world draws [param what] (BrickWorld.edges_shown,
## .studs_shown); false on a build without them, which this probe runs on to
## fail (red) and to keep its default view to be laid beside.
func _shown(what: StringName) -> bool:
	return _world != null and _world.get(what) == true


## [param part]'s male studs as its connectors say: [feet, axes], part-local.
func _studs_of(part: Lbm.PartMesh) -> Array:
	var feet := PackedVector3Array()
	var axes := PackedVector3Array()
	for connector: Lbm.Connector in part.connectors:
		if connector.kind == "stud" and connector.gender == "male" \
				and connector.axis.length_squared() > 0.5:
			feet.append(connector.position)
			axes.append(connector.axis.normalized())
	return [feet, axes]


func _ticked(name: String) -> bool:
	var command: Shell.Command = _shell.command(name)
	return command != null and command.ticked.is_valid() and bool(command.ticked.call())


# -- the scene ----------------------------------------------------------------


func _library() -> PartLibrary:
	return _main.get("_library")


## Nothing on the model and nothing under it.
func _empty_scene() -> void:
	_main.call("clear_model")
	var none: ModelFloor = ModelFloor.preferred().copy()
	none.kind = ModelFloor.NONE
	_main.call("choose_floor", none)
	await _frames(6)


func _put(part: String, colour: int, at: Vector3, turn: Basis = Basis.IDENTITY) -> int:
	var where := Transform3D(turn, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	if brick_id > 0:
		_builder.register(brick_id, part, where)
	return brick_id


## Square on from the front, orthographic, framed on [param box].
func _square_on(box: AABB) -> void:
	_camera.set_view("front")
	_camera.square_on(true)
	_camera.frame(box, 1.1)
	await _still()
	# Framed to its front alone, as large as the room the model is seen in
	# allows: frame() fits the ball round the box, a third again as much.
	var seen: Vector2 = _camera.seen_rect().size
	var tall: float = root.get_visible_rect().size.y
	_camera.size = maxf(box.size.y * tall / seen.y, box.size.x * tall / seen.x) * 1.06
	await _still()


## The camera come to rest, and the world drawn.
func _still() -> void:
	await _drawn()
	var last: Transform3D = _camera.global_transform
	var same: int = 0
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			same += 1
			if same >= 8:
				break
		else:
			same = 0
		last = _camera.global_transform
	await _frames(6)


## Every batch written, slices and all.
func _drawn() -> void:
	for _n: int in 600:
		await process_frame
		if not _world.is_being_laid() and not bool(_world.get("_rebuild_queued")):
			break
	await _frames(4)


func _face_rect(wall: AABB) -> Rect2:
	var toward: float = wall.end.z if -_camera.global_transform.basis.z.z < 0.0 else wall.position.z
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(wall.position.x, wall.position.y), Vector2(wall.end.x, wall.position.y),
			Vector2(wall.position.x, wall.end.y), Vector2(wall.end.x, wall.end.y)]:
		points.append(_window_px(_camera.unproject_position(Vector3(corner.x, corner.y, toward))))
	var rect := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		rect = rect.expand(p)
	return rect


func _inset(rect: Rect2, by: float) -> Rect2:
	return rect.grow(-by)


## Pixels inside [param face] off its own colour (the median of each channel)
## by more than [constant SEAM_LEVELS].
func _off_face(image: Image, face: Rect2) -> int:
	var reds := PackedInt32Array()
	var greens := PackedInt32Array()
	var blues := PackedInt32Array()
	var x0: int = maxi(0, ceili(face.position.x))
	var y0: int = maxi(0, ceili(face.position.y))
	var x1: int = mini(image.get_width(), floori(face.end.x))
	var y1: int = mini(image.get_height(), floori(face.end.y))
	for py: int in range(y0, y1):
		for px: int in range(x0, x1):
			var c: Color = image.get_pixel(px, py)
			reds.append(c.r8)
			greens.append(c.g8)
			blues.append(c.b8)
	if reds.is_empty():
		return -1
	var middle := Vector3i(_median(reds), _median(greens), _median(blues))
	var off: int = 0
	for n: int in reds.size():
		if maxi(absi(reds[n] - middle.x), maxi(absi(greens[n] - middle.y),
				absi(blues[n] - middle.z))) > SEAM_LEVELS:
			off += 1
	return off


func _median(values: PackedInt32Array) -> int:
	var sorted: PackedInt32Array = values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


# -- pictures -----------------------------------------------------------------


## The window's 3D alone, as drawn: the interface's 2D left out, the pointer
## off the model.
func _picture(name: String) -> Image:
	await _move(Vector2(2, 2))
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_disable_2d(viewport, true)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	RenderingServer.viewport_set_disable_2d(viewport, false)
	await _frames(3)
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	if not name.is_empty():
		var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
		image.save_png(path)
		print("    picture: %s" % path)
	return image


## The window's 3D as [method _picture] takes it, with nothing that blends
## one pixel with its neighbours or with the light of another part: no
## multisampling, no smoothed edges, no glow, no ambient occlusion. A pixel a
## part covers is then its own, and one it does not is the sky's to the bit.
func _flat_picture(name: String) -> Image:
	var environment: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var was: Array = [root.msaa_3d, root.screen_space_aa, root.use_taa, environment.glow_enabled,
		environment.ssao_enabled, environment.ssil_enabled, environment.ssr_enabled]
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.use_taa = false
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.ssr_enabled = false
	await _frames(4)
	var image: Image = await _picture(name)
	root.msaa_3d = was[0]
	root.screen_space_aa = was[1]
	root.use_taa = was[2]
	environment.glow_enabled = was[3]
	environment.ssao_enabled = was[4]
	environment.ssil_enabled = was[5]
	environment.ssr_enabled = was[6]
	await _frames(4)
	return image


func _shot_window(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	image.save_png(path)
	print("    picture: %s" % path)


## Pixels of [param a] and [param b] unlike by more than [param levels].
func _differing(a: Image, b: Image, levels: int) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	var count: int = 0
	for n: int in range(0, da.size(), 3):
		if maxi(absi(da[n] - db[n]), maxi(absi(da[n + 1] - db[n + 1]),
				absi(da[n + 2] - db[n + 2]))) > levels:
			count += 1
	return count


func _most(a: Color, b: Color) -> int:
	return maxi(absi(a.r8 - b.r8), maxi(absi(a.g8 - b.g8), absi(a.b8 - b.b8)))


func _outline(image: Image, outline: PackedVector2Array, colour: Color) -> void:
	for n: int in outline.size():
		var from: Vector2 = outline[n]
		var to: Vector2 = outline[(n + 1) % outline.size()]
		for k: int in 60:
			var p: Vector2 = from.lerp(to, k / 60.0)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				image.set_pixelv(Vector2i(p), colour)


## A point of the viewport (unproject_position's) in the window's pixels,
## which the pictures are in.
func _window_px(at: Vector2) -> Vector2:
	return at * Vector2(root.get_window().size) / root.get_visible_rect().size


# -- hands --------------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _px(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _warp(at: Vector2) -> void:
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(at)


func _move(at: Vector2) -> void:
	_warp(at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move)
	await process_frame


func _click(at: Vector2) -> void:
	at = _px(at)
	_warp(at)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move)
	await process_frame
	for down: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = at
		press.global_position = at
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(press)
		await process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		root.push_input(key)
		await process_frame


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("\n%s: %d failed" % ["FAIL" if _failures > 0 else "PASS", _failures])
	if _world != null:
		_world.clear()
	await process_frame
	quit(1 if _failures > 0 else 0)
