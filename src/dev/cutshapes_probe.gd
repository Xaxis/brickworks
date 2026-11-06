## Cut away by a box, a sphere or a cylinder (APP_UX4 8), held to its bar.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1400x900 \
##     --script src/dev/cutshapes_probe.gd
##
## Run at 1280 x 720 too (PROBE_SIZE=1280x720 tools/probe.sh cutshapes).
##
## The sample car, looked into from in front and above. Its roof and
## windscreens are selected and View › Cut away by › A box goes round them;
## the box's lower knob is dragged down two plates as a hand drags it, so
## it goes through the doors and the seat's back, and its knobs are wheeled
## and Grow and Shrink pressed, each a plate. Then, against the car drawn
## whole from the same view:
##
##   (1) the seat is seen and clicked through the box, and the pixels that
##       change are inside the box's outline on the screen: none further
##       out than the ambient occlusion's reach changes;
##   (2) drawn with the cut's faces marked, a face the box goes through is a
##       cap (magenta) and no inside face of a part is drawn (green): none;
##   the same for a cylinder and a sphere, chosen in the strip;
##   each part is drawn as the shape says, worked out here from its box:
##       whole outside it, cut across it, not at all inside;
##   (3) Render and the booklet, made with the box on, are the ones made
##       with it off. Kept over a save and an open, and opened by an older
##       Brickworks, is cutshapes_kept_probe's (headless).
##
## On a Brickworks without the shapes it fails at once: View › Cut away by
## has no box.
##
## Pictures in shots/cutshapes/<width>x<height>/.
extends SceneTree

const BOX := 1
const SPHERE := 2
const CYLINDER := 3
const PLATE := 8.0
## A pixel is changed when a channel moved more than this; JPEG and
## MSAA's rounding move one far less, a cut wall far more.
const CHANGED := 0.1

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _shell: Node
var _verbs: EditVerbs
var _shots: String = ""
var _seat: int = 0
var _roof: int = 0
## The car drawn whole from the view the cuts are looked at from.
var _whole: Image


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
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	var window: Vector2i = DisplayServer.window_get_size()
	_shots = "res://shots/cutshapes/%dx%d/" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots))
	print("  in a %dx%d window, on %s" % [window.x, window.y,
		RenderingServer.get_current_rendering_method()])

	var see: Object = _see()
	var offered: bool = int(_shell.call("menu_id", "cut_box")) >= 0 \
		and see != null and see.has_method("cut_by")
	_check("View › Cut away by offers a box, a sphere and a cylinder", offered
		and int(_shell.call("menu_id", "cut_sphere")) >= 0
		and int(_shell.call("menu_id", "cut_cylinder")) >= 0)
	if not offered:
		print("\ncutshapes: a person cannot cut a model away by a box, a sphere or a cylinder here")
		quit(1)
		return

	await _the_car()
	await _a_box_through_the_cab()
	await _a_sphere_and_a_cylinder()
	await _render_and_booklet_whole()

	print("")
	if _failures == 0:
		print("cutshapes: a box, a sphere and a cylinder cut away only what is inside them, "
			+ "fill the faces they cut, and Render and the booklet never see them")
	else:
		print("cutshapes: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- the car ------------------------------------------------------------------


func _the_car() -> void:
	print("  the car")
	var placed: int = int(_main.call("_open", "res://models/car.ldr"))
	await _settled()
	_check("the sample car opens (%d parts)" % placed, placed > 50)
	_roof = _first("4213")
	_seat = _first("4079")
	_check("...with its roof and its seat", _roof != 0 and _seat != 0)
	_verbs.set_mode("select")
	# Looking into the cab, as a person turns to: from in front, above it,
	# a little to the left. The car's front is towards +Z.
	_camera.look_from(Vector3(-0.45, 1.05, 1.0))
	_camera.frame(_main.call("_built_bounds"))
	await _camera_still()
	_builder.clear_selection()
	_whole = await _picture("whole")


func _a_box_through_the_cab() -> void:
	print("  a box through the cab")
	var see: Object = _see()
	var seen_before: int = await _seen_of(_seat)
	var clicked_before: int = _seat_clicks()
	_check("drawn whole, the seat is clicked at %d of 10 points over it" % clicked_before,
		clicked_before == 0)
	# The roof clicked, as a hand picks it, and the windscreens added.
	await _click(_camera.unproject_position(_box_of(_roof).get_center()))
	_check("a click on the roof selects it", _builder.selection.has(_roof)
		and _builder.selection.size() == 1)
	for window: int in _all("3823"):
		_builder.select_brick(window, true)
	var around: AABB = AABB()
	for brick_id: int in _builder.selection:
		around = _box_of(brick_id) if around.size == Vector3.ZERO \
			else around.merge(_box_of(brick_id))
	_check("View › Cut away by › A box can be chosen", bool(_shell.call("can", "cut_box")))
	_shell.call("run", "cut_box")
	await _settled()
	var shape: Object = _world.call("cut_shape")
	var room: AABB = see.get("room")
	_check("it cuts the car away by a box", _world.is_cut() and shape != null
		and int(shape.get("kind")) == BOX)
	_check("...round the selection (%s round %s)" % [room, around],
		room.grow(0.01).encloses(around) and _faces_odd(room) and _plates(room))
	var told: String = _status()
	_check("...and says how to work it: \"%s\"" % told, told.contains("knob"))
	_builder.clear_selection()
	await _frames(3)

	# The lower knob dragged down two plates, as a hand drags it.
	var low: int = 2
	var at: Vector2 = see.call("knob_on_screen", low)
	_check("the box's lower knob is on the screen and under the pointer there",
		int(see.call("knob_at", at)) == low)
	var point: Vector3 = (see.call("knob_points") as Array)[low]
	var down: Vector2 = _camera.unproject_position(point + Vector3(0.0, -2.0 * PLATE, 0.0)) - at
	var was: AABB = see.get("room")
	await _drag(at, at + down * 1.1)
	room = see.get("room")
	_check("dragging it down two plates pulls the floor of the box down 16 LDU (%.0f to %.0f), the rest kept"
		% [was.position.y, room.position.y], is_equal_approx(room.position.y, was.position.y - 16.0)
		and is_equal_approx(room.end.y, was.end.y) and is_equal_approx(room.position.x, was.position.x)
		and is_equal_approx(room.size.x, was.size.x) and is_equal_approx(room.size.z, was.size.z))
	_check("...and the picture is cut there too", _shape_room().is_equal_approx(room))
	await _shot("box_dragged")

	# A drag put back with Esc.
	was = room
	var side: Vector2 = see.call("knob_on_screen", 1)
	_check("the right knob is under the pointer at it", int(see.call("knob_at", side)) == 1)
	await _move(side)
	_button(side, true)
	await _frames(2)
	await _move(side + Vector2(60, 0), true)
	_check("dragging a side knob moves its face", not (see.get("room") as AABB).is_equal_approx(was))
	await _key(KEY_ESCAPE)
	_button(side + Vector2(60, 0), false)
	await _frames(4)
	_check("...and Esc puts it back", (see.get("room") as AABB).is_equal_approx(was))

	# Shift drags the whole box, its size kept; a right click puts it back.
	await _move(side)
	_button(side, true, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	await _move(side + Vector2(60, 0), true)
	var slid: AABB = see.get("room")
	_check("Shift-dragging a knob slides the whole box, its size kept (%.0f to %.0f across)"
		% [was.position.x, slid.position.x], not is_equal_approx(slid.position.x, was.position.x)
		and slid.size.is_equal_approx(was.size)
		and is_equal_approx(fmod(slid.position.x - was.position.x, PLATE), 0.0))
	_button(side + Vector2(60, 0), true, MOUSE_BUTTON_RIGHT)
	await _frames(2)
	_button(side + Vector2(60, 0), false, MOUSE_BUTTON_RIGHT)
	_button(side + Vector2(60, 0), false)
	await _frames(4)
	_check("...and a right click puts it back", (see.get("room") as AABB).is_equal_approx(was))

	# The wheel over a knob, a plate a notch.
	await _wheel(side, true)
	room = see.get("room")
	_check("the wheel over the right knob pushes that face out a plate (%.0f to %.0f)"
		% [was.end.x, room.end.x], is_equal_approx(room.end.x, was.end.x + PLATE)
		and is_equal_approx(room.position.x, was.position.x))
	await _wheel(see.call("knob_on_screen", 1), false)
	_check("...and back a notch, back", (see.get("room") as AABB).is_equal_approx(was))

	# Grow and Shrink in the strip.
	var grow: Button = _control("cut_grow")
	var shrink: Button = _control("cut_shrink")
	_check("the strip has Grow and Shrink", grow != null and shrink != null
		and grow.is_visible_in_tree() and shrink.is_visible_in_tree())
	if grow != null and shrink != null:
		# A knob lit under the pointer goes out when the pointer leaves it for
		# the strip, as a hand reaches for Grow.
		await _move(see.call("knob_on_screen", 1))
		var lit_over: int = see.get("lit")
		await _move(grow.get_global_rect().get_center())
		_check("the pointer over the right knob lights it, and over the strip lights none (%d, %d)"
			% [lit_over, int(see.get("lit"))], lit_over == 1 and int(see.get("lit")) == -1)
		await _click(grow.get_global_rect().get_center())
		room = see.get("room")
		_check("Grow takes every face out a plate (%s)" % room.size,
			room.size.is_equal_approx(was.size + Vector3.ONE * 2.0 * PLATE)
			and room.get_center().is_equal_approx(was.get_center()))
		await _click(shrink.get_global_rect().get_center())
		_check("...and Shrink brings them back", (see.get("room") as AABB).is_equal_approx(was))
	await _settled()

	# (1) what it shows, and only there.
	room = see.get("room")
	var right: bool = _drawn_as_cut()
	_check("each part is drawn as the box says: %d whole, %d cut across it, %d not drawn"
		% _sides, right and _sides[1] > 0 and _sides[2] > 0)
	var clicked_after: int = _seat_clicks()
	_check("(1) the seat is clicked through the box at %d of 10 points over it" % clicked_after,
		clicked_after >= 3)
	var seen_after: int = await _seen_of(_seat)
	_check("(1) ...and seen: %d pixels of it, %d with the car whole" % [seen_after, seen_before],
		seen_after > seen_before)
	var cut: Image = await _picture("box")
	_inside_only(cut, _outline(BOX, room), "the box")
	# (2) the faces it leaves.
	await _marks("box", _outline(BOX, room))
	await _shot("box_with_its_strip")


func _a_sphere_and_a_cylinder() -> void:
	var see: Object = _see()
	var choice: OptionButton = _control("cut_shape")
	_check("the strip says what the cut is by", choice != null and choice.is_visible_in_tree()
		and choice.selected == BOX)
	if choice == null:
		return
	# The cylinder first, so it takes the box's room, a drum through the cab
	# whose walls it cuts; after the sphere it would keep the sphere's height
	# and take nearly the whole car, leaving few faces to count. The sphere
	# is the same ball from either.
	for kind: int in [CYLINDER, SPHERE]:
		var name: String = ["", "box", "sphere", "cylinder"][kind]
		print("  a %s" % name)
		choice.select(kind)
		choice.item_selected.emit(kind)
		await _settled()
		var shape: Object = _world.call("cut_shape")
		var room: AABB = see.get("room")
		_check("chosen in the strip, a %s cuts the car (%s)" % [name, room], shape != null
			and int(shape.get("kind")) == kind and _shape_room().is_equal_approx(room))
		_check("...round where it is round", is_equal_approx(room.size.x, room.size.z)
			and (kind != SPHERE or is_equal_approx(room.size.x, room.size.y)))
		var right: bool = _drawn_as_cut()
		_check("...each part drawn as the %s says: %d whole, %d cut across it, %d not drawn"
			% [name, _sides[0], _sides[1], _sides[2]], right and _sides[1] > 0)
		var cut: Image = await _picture(name)
		_inside_only(cut, _outline(kind, room), "the " + name)
		await _marks(name, _outline(kind, room))
		await _shot(name + "_with_its_strip")
	choice.select(BOX)
	choice.item_selected.emit(BOX)
	await _settled()


## (3) Render and the booklet draw worlds of their own: the cut is never in
## them.
func _render_and_booklet_whole() -> void:
	print("  Render and the booklet")
	_check("the box is on", _world.is_cut() and _world.call("cut_shape") != null)
	var render := StudioRender.new()
	render.library = _main.get("_library")
	render.scenery = _store.scenery
	render.eye = _camera
	render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(render)
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(640, 360)
	settings.view = "hero"
	var with: Image = await render.render(_world, settings)
	var with_booklet: String = ProjectSettings.globalize_path(_shots + "booklet_with.html")
	await _main.call("_export_booklet", with_booklet)

	await _key(KEY_K)
	await _settled()
	_check("K: the whole car again", not _world.is_cut())
	var without: Image = await render.render(_world, settings)
	var without_booklet: String = ProjectSettings.globalize_path(_shots + "booklet_without.html")
	await _main.call("_export_booklet", without_booklet)
	if with != null and without != null:
		with.save_png(ProjectSettings.globalize_path(_shots + "render_with_the_box.png"))
		without.save_png(ProjectSettings.globalize_path(_shots + "render_without.png"))
	var unlike: int = _unlike(with, without)
	_check("Render, with the box on, draws the car whole: %d pixels unlike the one without"
		% unlike, with != null and without != null and unlike == 0)
	var a: String = FileAccess.get_file_as_string(with_booklet)
	var b: String = FileAccess.get_file_as_string(without_booklet)
	var pictures := RegEx.create_from_string("data:image/jpeg;base64,([A-Za-z0-9+/=]+)")
	_check("the booklet made with the box on has the words of the one made without (%d bytes)"
		% a.length(), not a.is_empty() and pictures.sub(a, "IMG", true) == pictures.sub(b, "IMG", true))
	var seen_a: Array[RegExMatch] = pictures.search_all(a)
	var seen_b: Array[RegExMatch] = pictures.search_all(b)
	var differ: int = 0
	for n: int in mini(seen_a.size(), seen_b.size()):
		differ += _jpegs_unlike(seen_a[n].get_string(1), seen_b[n].get_string(1))
	_check("...and its %d pictures (%d pixels unlike)" % [seen_a.size(), differ],
		seen_a.size() > 0 and seen_a.size() == seen_b.size() and differ == 0)
	render.queue_free()


# -- what is drawn ------------------------------------------------------------


## Whether each part is drawn as the cut's shape says, worked out here from
## the part's own box: wholly outside by its batch with the plain shader,
## across by the batch's MultiMesh that cuts, wholly inside not at all; and
## every part across or inside casts its shadow whole. The counts go to
## [member _sides].
var _sides: Array = [0, 0, 0]


func _drawn_as_cut() -> bool:
	var shape: Object = _world.call("cut_shape")
	if shape == null:
		return false
	var kind: int = shape.get("kind")
	var room: AABB = shape.get("room")
	var batches: Dictionary = _world.get("_batches")
	var any: bool = false
	_sides = [0, 0, 0]
	for key: String in batches:
		var batch: Object = batches[key]
		var whole: int = 0
		var across: int = 0
		var in_it: int = 0
		for brick_id: int in batch.get("brick_ids"):
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick == null or brick.hidden:
				continue
			any = true
			var side: int = _side(kind, room, _box_of(brick_id))
			_sides[side + 1] += 1
			if side < 0:
				whole += 1
			elif side == 0:
				across += 1
			else:
				in_it += 1
		var through: Variant = batch.get("through")
		var shade: Variant = batch.get("shade")
		var drawn_across: int = (through as MultiMeshInstance3D).multimesh.instance_count \
			if through != null else 0
		var shadows: int = (shade as MultiMeshInstance3D).multimesh.instance_count \
			if shade != null else 0
		if (batch.get("multimesh") as MultiMesh).visible_instance_count != whole \
				or drawn_across != across or shadows != across + in_it:
			print("    %s: %d drawn whole (%d), %d cut (%d), %d casting shadows (%d)" % [key,
				(batch.get("multimesh") as MultiMesh).visible_instance_count, whole,
				drawn_across, across, shadows, across + in_it])
			return false
	return any


## Which side of the shape [param box] is, worked out here: -1 outside, 0
## across, 1 inside. The shape is convex, so a box with all eight corners in
## it is in it; one is clear of it when the point of the box nearest the
## shape's middle is outside it.
static func _side(kind: int, room: AABB, box: AABB) -> int:
	var middle: Vector3 = room.get_center()
	var half: Vector3 = room.size * 0.5
	var nearest := Vector3(clampf(middle.x, box.position.x, box.end.x),
		clampf(middle.y, box.position.y, box.end.y), clampf(middle.z, box.position.z, box.end.z))
	var corners_in: int = 0
	for n: int in 8:
		var corner := Vector3(box.end.x if n & 1 else box.position.x,
			box.end.y if n & 2 else box.position.y, box.end.z if n & 4 else box.position.z)
		corners_in += 1 if _in(kind, middle, half, corner) else 0
	if corners_in == 8:
		return 1
	match kind:
		BOX:
			return 0 if box.intersects(room) else -1
		SPHERE:
			return 0 if _in(kind, middle, half, nearest) else -1
	# A cylinder: the nearest across, and overlapping up and down.
	var flat := Vector3(nearest.x, middle.y, nearest.z)
	var overlaps: bool = box.position.y < room.end.y and box.end.y > room.position.y
	return 0 if overlaps and _in(kind, middle, half, flat) else -1


static func _in(kind: int, middle: Vector3, half: Vector3, point: Vector3) -> bool:
	var d: Vector3 = (point - middle) / half
	match kind:
		SPHERE:
			return d.length_squared() < 1.0
		CYLINDER:
			return d.x * d.x + d.z * d.z < 1.0 and absf(d.y) < 1.0
	return absf(d.x) < 1.0 and absf(d.y) < 1.0 and absf(d.z) < 1.0


## The shape's outline on the screen: the hull of points all over it.
func _outline(kind: int, room: AABB) -> PackedVector2Array:
	var middle: Vector3 = room.get_center()
	var half: Vector3 = room.size * 0.5
	var points := PackedVector2Array()
	if kind == BOX:
		for n: int in 8:
			points.append(_camera.unproject_position(middle + half * Vector3(
				1.0 if n & 1 else -1.0, 1.0 if n & 2 else -1.0, 1.0 if n & 4 else -1.0)))
		return Geometry2D.convex_hull(points)
	for i: int in 25:
		for j: int in 48:
			var up: float = lerpf(-PI * 0.5, PI * 0.5, i / 24.0)
			var turn: float = TAU * j / 48.0
			var d := Vector3(cos(turn), lerpf(-1.0, 1.0, i / 24.0), sin(turn))
			if kind == SPHERE:
				d = Vector3(cos(up) * cos(turn), sin(up), cos(up) * sin(turn))
			points.append(_camera.unproject_position(middle + d * half))
	return Geometry2D.convex_hull(points)


## (1): [param cut] against the car drawn whole, the pixels that changed
## are inside [param outline], or within the ambient occlusion's reach of
## it (12 LDU, measured on the screen at the shape's middle) plus MSAA's
## pixel. Leaves a picture of where they are.
func _inside_only(cut: Image, outline: PackedVector2Array, what: String) -> void:
	if cut == null or _whole == null or cut.get_size() != _whole.get_size():
		_check("pictures of %s and the car whole to compare" % what, false)
		return
	var middle: Vector3 = (_see().get("room") as AABB).get_center()
	var right: Vector3 = _camera.global_transform.basis.x
	var reach: float = _camera.unproject_position(middle + right * 12.0).distance_to(
		_camera.unproject_position(middle)) + 2.0
	# Window pixels to the viewport's, which the outline is in.
	var scale: Vector2 = root.get_visible_rect().size / Vector2(cut.get_size())
	var a: PackedByteArray = cut.get_data()
	var b: PackedByteArray = _whole.get_data()
	var width: int = cut.get_width()
	var step: int = 4 if cut.get_format() == Image.FORMAT_RGBA8 else 3
	var limit: int = int(CHANGED * 255.0)
	var inside: int = 0
	var near: int = 0
	var outside: int = 0
	var worst_out: int = 0
	var where := Image.create(cut.get_width(), cut.get_height(), false, Image.FORMAT_RGB8)
	where.blit_rect(_whole, Rect2i(Vector2i.ZERO, _whole.get_size()), Vector2i.ZERO)
	where.adjust_bcs(0.6, 1.0, 0.3)
	var inside_area: int = 0
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for corner: Vector2 in outline:
		bounds = bounds.expand(corner)
	for y: int in cut.get_height():
		for x: int in width:
			var at: int = (y * width + x) * step
			var most: int = maxi(absi(a[at] - b[at]), maxi(absi(a[at + 1] - b[at + 1]),
				absi(a[at + 2] - b[at + 2])))
			var point := Vector2(x + 0.5, y + 0.5) * scale
			var within: bool = bounds.has_point(point) \
				and Geometry2D.is_point_in_polygon(point, outline)
			inside_area += 1 if within else 0
			if most <= limit:
				continue
			if within:
				inside += 1
				where.set_pixel(x, y, Color(1.0, 0.85, 0.1))
			elif _distance_to(point, outline) <= reach:
				near += 1
				where.set_pixel(x, y, Color(0.2, 0.7, 1.0))
			else:
				outside += 1
				worst_out = maxi(worst_out, most)
				where.set_pixel(x, y, Color(1.0, 0.1, 0.1))
	for n: int in outline.size():
		var from: Vector2 = outline[n] / scale
		var to: Vector2 = outline[(n + 1) % outline.size()] / scale
		for k: int in 200:
			var p: Vector2 = from.lerp(to, k / 200.0)
			if p.x >= 0 and p.y >= 0 and p.x < cut.get_width() and p.y < cut.get_height():
				where.set_pixelv(Vector2i(p), Color(1, 1, 1))
	where.save_png(ProjectSettings.globalize_path(_shots + "changed_%s.png" % what.get_slice(" ", 1)))
	_check("(1) cut by %s, %d pixels inside its outline changed (of %d), %d within %.0f px of it, %d further out%s"
		% [what, inside, inside_area, near, reach, outside,
			(" (the most %d of 255)" % worst_out) if outside > 0 else ""],
		inside > 2000 and outside == 0)


static func _distance_to(point: Vector2, outline: PackedVector2Array) -> float:
	var least: float = INF
	for n: int in outline.size():
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, outline[n],
			outline[(n + 1) % outline.size()])
		least = minf(least, closest.distance_to(point))
	return least


## (2): drawn with its faces marked, the cut's faces magenta and any inside
## face of a part green: inside the outline, caps and no green.
func _marks(what: String, outline: PackedVector2Array) -> void:
	_world.call("set_cut_marks", true)
	var marked: Image = await _picture(what + "_marked")
	_world.call("set_cut_marks", false)
	await _frames(3)
	var scale: Vector2 = root.get_visible_rect().size / Vector2(marked.get_size())
	var caps: int = 0
	var insides: int = 0
	for y: int in marked.get_height():
		for x: int in marked.get_width():
			var c: Color = marked.get_pixel(x, y)
			var cap: bool = c.r > 0.75 and c.b > 0.75 and c.g < 0.35
			var inside_face: bool = c.g > 0.75 and c.r < 0.35 and c.b < 0.35
			if not cap and not inside_face:
				continue
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5) * scale, outline):
				continue
			caps += 1 if cap else 0
			insides += 1 if inside_face else 0
	_check("(2) cut by a %s, %d pixels are its faces filled, %d an inside face of a part"
		% [what, caps, insides], caps > 200 and insides == 0)


## How many pixels of [param brick_id] are seen: the view with it and
## without it, told apart.
func _seen_of(brick_id: int) -> int:
	var with: Image = await _picture("")
	_builder.clear_selection()
	_builder.select_brick(brick_id, false)
	_verbs.hide_selection()
	await _settled()
	var without: Image = await _picture("")
	_verbs.show_all()
	await _settled()
	return _unlike(with, without)


# -- reading the app ----------------------------------------------------------


func _see() -> Object:
	return _shell.get("see_inside") if _shell != null else null


func _control(name: String) -> Control:
	var named: Dictionary = _shell.call("controls_by_name")
	return named.get(name)


func _status() -> String:
	return (_shell.get("status") as StatusBar).message.text


func _shape_room() -> AABB:
	var shape: Object = _world.call("cut_shape")
	return shape.get("room") if shape != null else AABB()


func _first(part: String) -> int:
	var found: Array[int] = _all(part)
	return found[0] if not found.is_empty() else 0


func _all(part: String) -> Array[int]:
	var out: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and not _store.scenery.has(brick.id):
			out.append(brick.id)
	return out


## At how many of ten points over the seat a click takes the seat: the
## middle of its box, and a grid over its top.
func _seat_clicks() -> int:
	var box: AABB = _box_of(_seat)
	var points: Array[Vector3] = [box.get_center()]
	for i: int in 3:
		for j: int in 3:
			points.append(Vector3(lerpf(box.position.x, box.end.x, 0.2 + 0.3 * i), box.end.y - 2.0,
				lerpf(box.position.z, box.end.z, 0.2 + 0.3 * j)))
	var hits: int = 0
	for point: Vector3 in points:
		hits += 1 if _verbs.brick_at(_camera.unproject_position(point)) == _seat else 0
	return hits


func _box_of(brick_id: int) -> AABB:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _world.library.mesh_for(brick.part_id)
	return brick.transform * (mesh.bounds if mesh != null else AABB())


static func _faces_odd(box: AABB) -> bool:
	for n: int in 3:
		if absi(roundi(box.position[n])) % 2 != 1 or absi(roundi(box.end[n])) % 2 != 1:
			return false
	return true


static func _plates(box: AABB) -> bool:
	for n: int in 3:
		if absf(box.size[n] / PLATE - roundf(box.size[n] / PLATE)) > 0.001:
			return false
	return true


## Pixels further apart than JPEG's or a renderer's rounding.
static func _unlike(a: Image, b: Image) -> int:
	if a == null or b == null:
		return -1
	if a.get_size() != b.get_size():
		return a.get_width() * a.get_height()
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > 0.16:
				count += 1
	return count


static func _jpegs_unlike(a64: String, b64: String) -> int:
	if a64 == b64:
		return 0
	var a := Image.new()
	var b := Image.new()
	a.load_jpg_from_buffer(Marshalls.base64_to_raw(a64))
	b.load_jpg_from_buffer(Marshalls.base64_to_raw(b64))
	return _unlike(a, b)


## Until the world has drawn everything waiting to be drawn.
func _settled() -> void:
	for _n: int in 600:
		await process_frame
		if (_world.get("_dirty") as Dictionary).is_empty() and not bool(_world.get("_rebuild_queued")):
			break
	await _frames(3)


func _camera_still() -> void:
	var last: Transform3D = _camera.global_transform
	for _n: int in 600:
		await process_frame
		if _camera.global_transform.is_equal_approx(last):
			break
		last = _camera.global_transform
	await _frames(3)


# -- pictures -----------------------------------------------------------------


## The model as drawn, without the window's panels and the cut's outline
## and knobs over it, the pointer off it; kept as [param name] if named.
func _picture(name: String) -> Image:
	await _move(Vector2(4, 4))
	var frame: MeshInstance3D = _see().get("frame")
	var framed: bool = frame.visible
	frame.visible = false
	var viewport: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_disable_2d(viewport, true)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	RenderingServer.viewport_set_disable_2d(viewport, false)
	frame.visible = framed
	await _frames(3)
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	if not name.is_empty():
		image.save_png(ProjectSettings.globalize_path(_shots + name + ".png"))
		print("    picture: %s%s.png" % [_shots.trim_prefix("res://"), name])
	return image


## The window as a person sees it.
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_shots + name + ".png"))
	print("    picture: %s%s.png" % [_shots.trim_prefix("res://"), name])


# -- hands --------------------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool, which: MouseButton = MOUSE_BUTTON_LEFT,
		shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.shift_pressed = shift
	event.position = _as_event(at)
	event.global_position = event.position
	if down and which == MOUSE_BUTTON_LEFT:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _drag(from: Vector2, to: Vector2) -> void:
	await _move(from)
	_button(from, true)
	await _frames(2)
	for n: int in 10:
		await _move(from.lerp(to, float(n + 1) / 10.0), true)
	_button(to, false)
	await _frames(4)


func _wheel(at: Vector2, up: bool) -> void:
	await _move(at)
	var which: MouseButton = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	_button(at, true, which)
	await _frames(1)
	_button(at, false, which)
	await _frames(4)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)
