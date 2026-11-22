## Can a photo of a build be read to its step, with the fault named? The render
## half of the bench (photostep, APP_UX11 past parity 3): tools/bench/photostep.py
## dresses these renders as phone photos, asks the session and scores it.
##
##   gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a -s '-screen 0 1400x1000x24' godot --path . --resolution 1280x960 \
##     --script src/dev/photostep_bench.gd -- --pictures=DIR [--sets=7638-1,...] [--samples=N] [--zoom=F]
##
## For each set (a library set's own steps, as Build mode pages them), three
## step pages chosen by rule (the first main-line page at or after 35%, 60% and
## 85% of the way with three or more new parts, no figure, the page before it
## main-line too). For each page N, five builds, each drawn at Best, Product
## look, from one hand-held camera that is never the booklet's (a yaw at least
## 25 degrees off it, looked down on at 32 to 60 degrees, rolled a little, a
## phone's 26 mm lens): step N done right; one of its new parts missing; one
## moved one stud (20 LDU) across; one the wrong colour; and step N-1. The
## three faulty parts are the page's new parts the camera sees most of
## (measured: the picture with and without each), distinct where the page has
## three. Each photo also drawn at Good with nothing behind (its mask, for
## the table the dresser lays under it). And the step pictures the session is
## given: steps N-1, N and N+1 at Good, the window's look, from four corners
## and the top, each step from one camera so their difference is the step.
##
## --zoom=F stands the phone F times closer than its own framing, the yaw, pitch
## and roll the same (the build filled 29 to 62% of the frame's width at 1).
## DIR/cases.json says what each picture is: the truth the score reads.
## The argument is --pictures=, never --out (main.gd's export).
extends SceneTree

const SETS: Array = ["7638-1", "42004-1", "31009-1", "10179-1"]
const FRACTIONS: Array = [0.35, 0.6, 0.85]
const PHOTO := Vector2i(1280, 960)
const REF := Vector2i(800, 600)
const SEE := Vector2i(320, 240)
const STUD := 20.0
const SIDES: Dictionary = {
	"front-left": Vector3(-0.62, 0.68, 1.0),
	"front-right": Vector3(0.62, 0.68, 1.0),
	"back-left": Vector3(-0.62, 0.68, -1.0),
	"back-right": Vector3(0.62, 0.68, -1.0),
	"top": Vector3(0.0, 1.0, 0.02),
}
## The shade a builder takes for another (LDraw codes).
const NEAR_SHADES: Dictionary = {
	0: 72, 72: 0, 71: 72, 15: 71, 4: 320, 320: 4, 1: 272, 272: 1, 14: 191, 191: 14,
	19: 28, 28: 19, 70: 308, 308: 70, 2: 288, 288: 2, 25: 4, 85: 272, 378: 2,
}
const CLEAR_SWAPS: Array = [4, 1, 14, 15, 0, 2]

var _dir: String = ""
var _samples: int = 256
## How much closer than the bench's own hand-held framing (--zoom=, 1 its own).
var _zoom: float = 1.0
var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _library: PartLibrary
var _store: ModelStore
var _render: StudioRender
var _see: SubViewport
var _see_eye: Camera3D


func _initialize() -> void:
	_run()


func _arg(name: String, fallback: String) -> String:
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--%s=" % name):
			return given.trim_prefix("--%s=" % name)
	return fallback


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _fail(words: String) -> void:
	print("  FAIL  %s" % words)
	_failures += 1


func _run() -> void:
	_dir = _arg("pictures", "")
	if _dir.is_empty():
		print("photostep_bench: give --pictures=DIR")
		quit(2)
		return
	_samples = int(_arg("samples", "256"))
	_zoom = float(_arg("zoom", "1.0"))
	var sets: PackedStringArray = _arg("sets", ",".join(SETS)).split(",", false)
	DirAccess.make_dir_recursive_absolute(_dir + "/raw")
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_store = _main.get("_store")
	_store.keeps = false
	_world = _main.get("_world")
	_library = _main.get("_library")
	(_main.get("_builder") as Builder).hide_preview()
	print("  renderer: %s on %s; path traced: %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), PathTracer.available()])
	_render = StudioRender.new()
	_render.library = _library
	_render.scenery = _store.scenery
	_render.eye = _main.get("_camera")
	_render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)
	# A small eye on the world itself, to measure how much of a part a camera sees.
	_see = SubViewport.new()
	_see.size = SEE
	_see.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_main.add_child(_see)
	_see_eye = Camera3D.new()
	_see.add_child(_see_eye)
	_see_eye.current = true
	var groups: Array = []
	var kept := FileAccess.get_file_as_string(_dir + "/cases.json")
	if not kept.is_empty():
		var said: Variant = JSON.parse_string(kept)
		if said is Dictionary:
			groups = (said as Dictionary).get("groups", [])
	for number: String in sets:
		var done: bool = false
		for group: Dictionary in groups:
			done = done or str(group.get("set", "")) == number
		if done:
			print("%s: drawn already" % number)
			continue
		groups.append_array(await _one_set(number, sets.find(number)))
		_write(groups)
	_write(groups)
	print("")
	print("%d failed" % _failures if _failures else "photostep_bench: %d groups in %s" % [groups.size(), _dir])
	quit(1 if _failures else 0)


func _write(groups: Array) -> void:
	var file := FileAccess.open(_dir + "/cases.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"groups": groups, "photo": [PHOTO.x, PHOTO.y],
		"reference": [REF.x, REF.y], "samples": _samples}, "  "))
	file.close()


## One set: opened as File, Library opens it, paged as Build mode pages it, and
## its three pages drawn.
func _one_set(number: String, which: int) -> Array:
	var out: Array = []
	var path: String = "res://vendor/omr/files/%s.mpd" % number
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail("%s: no %s" % [number, path])
		return out
	_main.call("clear_model")
	await _frames(4)
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(text, number)
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(20)
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {}, true)
	var pages: BuildSteps = BuildSteps.of(_world, _library, steps, _store.scenery)
	var name: String = str(opened.get("name", number))
	var main_steps: int = 0
	for step: Instructions.Step in steps:
		if not step.in_callout():
			main_steps = maxi(main_steps, step.number)
	print("%s: %d parts, %d pages, %d main steps" % [number, _world.brick_count(), pages.last(), main_steps])
	var chosen: Array[int] = []
	for fraction: float in FRACTIONS:
		var page: int = _page_at(pages, fraction, chosen)
		if page > 0:
			chosen.append(page)
	if chosen.size() < FRACTIONS.size():
		_fail("%s: only %d pages fit the rule" % [number, chosen.size()])
	for g: int in chosen.size():
		var group: Dictionary = await _group(number, pages, chosen[g], which * 10 + g, main_steps)
		if not group.is_empty():
			group["name"] = _set_name(number)
			out.append(group)
	_world.show_only({})
	return out


func _set_name(number: String) -> String:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://vendor/omr/index.json"))
	if index is Array:
		for row: Variant in index:
			if row is Dictionary and str(row.get("number", "")) == number:
				return str(row.get("name", number))
	return number


## The first page at or after [param fraction] of the way (then before it) that
## a photo can check: main-line, not a figure, not putting a sub-assembly on, three
## new parts or more, the page before it main-line too, and a page after it.
func _page_at(pages: BuildSteps, fraction: float, taken: Array[int]) -> int:
	var last: int = pages.last()
	var start: int = clampi(int(round(fraction * last)), 2, last - 1)
	for offset: int in last:
		for page: int in [start + offset, start - offset]:
			if page < 2 or page > last - 1 or taken.has(page) or taken.has(page - 1) or taken.has(page + 1):
				continue
			if _checkable(pages, page):
				return page
	return 0


func _checkable(pages: BuildSteps, page: int) -> bool:
	var step: Instructions.Step = pages.step_of(page)
	var before: Instructions.Step = pages.step_of(page - 1)
	if step == null or before == null or step.in_callout() or step.attaches() or step.figure:
		return false
	if before.in_callout() or before.figure:
		return false
	var fresh: Dictionary = pages.fresh(page)
	var real: int = 0
	for brick_id: int in fresh:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and not _library.sticks(brick.part_id) and _library.parts.has(brick.part_id):
			real += 1
	return real >= 3


## One page's five photos, their masks and the step pictures.
func _group(number: String, pages: BuildSteps, page: int, seed: int, main_steps: int) -> Dictionary:
	var step: Instructions.Step = pages.step_of(page)
	var shown: Dictionary = pages.shown(page)
	var before: Dictionary = pages.shown(page - 1)
	var after: Dictionary = pages.shown(page + 1)
	var key: String = "%s_p%d" % [number.split("-")[0], page]
	var folder: String = "%s/raw/%s" % [_dir, key]
	DirAccess.make_dir_recursive_absolute(folder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (seed + 1)
	# The camera that sees the page's new parts best, of six hand-held ones.
	var fresh: Array = []
	for brick_id: int in pages.fresh(page):
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick != null and not _library.sticks(brick.part_id) and _library.parts.has(brick.part_id):
			fresh.append(brick_id)
	fresh.sort_custom(func(a: int, b: int) -> bool: return _box(a).get_volume() > _box(b).get_volume())
	fresh = fresh.slice(0, 12)
	var bounds: AABB = _bounds(shown)
	var best: Dictionary = {}
	for attempt: int in 6:
		var camera: Dictionary = _hand_held(rng, bounds, pages.view(page))
		var seen: Array = await _seen_parts(shown, fresh, camera)
		var third: float = float(seen[mini(2, seen.size() - 1)][1]) if not seen.is_empty() else 0.0
		if best.is_empty() or third > float(best["third"]):
			best = {"camera": camera, "seen": seen, "third": third}
		if third >= 0.004:
			break
	var camera: Dictionary = best["camera"]
	var seen: Array = best["seen"]
	if seen.is_empty() or float(seen[0][1]) <= 0.0005:
		_fail("%s page %d: no new part seen from any camera" % [number, page])
		return {}
	# The faulty parts: missing the most seen, moved the next, recoloured the third.
	var picks: Array = []
	for row: Array in seen:
		if float(row[1]) >= 0.0008:
			picks.append(int(row[0]))
	if picks.is_empty():
		picks.append(int(seen[0][0]))
	var missing_id: int = picks[0]
	var moved_id: int = picks[mini(1, picks.size() - 1)]
	var colour_id: int = picks[mini(2, picks.size() - 1)]
	var move: Vector3 = _move_for(moved_id, shown, camera)
	var moved_brick: BrickWorld.Brick = _world.get_brick(moved_id)
	var moved_from: Transform3D = moved_brick.transform
	var colour_brick: BrickWorld.Brick = _world.get_brick(colour_id)
	var colour_was: int = colour_brick.color_code
	var near: bool = seed % 10 != 1
	var colour_to: int = _wrong_colour(colour_was, near)
	var light: String = "daylight" if seed % 3 == 2 else "window"
	var light_turn: float = rng.randf_range(0.0, 360.0)
	var kinds: Array = ["right", "missing", "moved", "colour", "behind"]
	var faults: Dictionary = {
		"missing": _fault(missing_id, camera, "missing"),
		"moved": _fault(moved_id, camera, "moved"),
		"colour": _fault(colour_id, camera, "colour"),
	}
	faults["moved"]["move_ldu"] = [move.x, move.y, move.z]
	faults["moved"]["toward"] = _toward(move, camera)
	faults["colour"]["colour_to"] = colour_to
	faults["colour"]["colour_to_name"] = _library.color(colour_to).name if _library.color(colour_to) else ""
	faults["colour"]["near_shade"] = near
	# How much of the picture each fault changes, at the measuring size.
	var right_image: Image = await _look(shown, camera)
	var without: Dictionary = shown.duplicate()
	without.erase(missing_id)
	faults["missing"]["changed"] = _changed(right_image, await _look(without, camera))
	_world.move_brick(moved_id, Transform3D(moved_from.basis, moved_from.origin + move))
	faults["moved"]["changed"] = _changed(right_image, await _look(shown, camera))
	faults["moved"]["box_after"] = _screen_box(moved_id, camera)
	_world.move_brick(moved_id, moved_from)
	_world.recolor_brick(colour_id, colour_to)
	faults["colour"]["changed"] = _changed(right_image, await _look(shown, camera))
	_world.recolor_brick(colour_id, colour_was)
	await _frames(2)
	# The five photos and their masks.
	for kind: String in kinds:
		var showing: Dictionary = before if kind == "behind" else shown
		if kind == "missing":
			showing = without
		if kind == "moved":
			_world.move_brick(moved_id, Transform3D(moved_from.basis, moved_from.origin + move))
		if kind == "colour":
			_world.recolor_brick(colour_id, colour_to)
		_world.show_only(showing)
		await _frames(2)
		var photo: Image = await _draw(_photo_settings(camera, light, light_turn, seed, false))
		var mask: Image = await _draw(_photo_settings(camera, light, light_turn, seed, true))
		if photo == null or mask == null:
			_fail("%s page %d: the %s photo not drawn" % [number, page, kind])
		else:
			photo.save_png("%s/photo_%s.png" % [folder, kind])
			mask.save_png("%s/mask_%s.png" % [folder, kind])
			print("  %s %s: %s" % [key, kind, "path traced" if _render.traced_last() else "frames averaged"])
		if kind == "moved":
			_world.move_brick(moved_id, moved_from)
		if kind == "colour":
			_world.recolor_brick(colour_id, colour_was)
	# The step pictures: N-1, N and N+1 from each side, each side one camera.
	var whole: AABB = _bounds(after)
	var refs: Dictionary = {}
	for at: Array in [[page - 1, before], [page, shown], [page + 1, after]]:
		_world.show_only(at[1])
		await _frames(2)
		for side: String in SIDES:
			var settings: RenderSettings = _side_settings(side, whole)
			var picture: Image = await _draw(settings)
			if picture == null:
				_fail("%s page %d: step picture %d %s not drawn" % [number, page, at[0], side])
				continue
			var file: String = "ref_%d_%s.png" % [_number_of(pages, int(at[0])), side]
			picture.save_png("%s/%s" % [folder, file])
			refs["%d %s" % [int(at[0]), side]] = file
	_world.show_only({})
	var lots: Dictionary = {}
	for at: int in [page - 1, page, page + 1]:
		lots[str(_number_of(pages, at))] = pages.lots(at)
	print("  %s: step %d of %d, faults seen %.4f / %.4f / %.4f of the picture" % [key, step.number, main_steps,
		float(faults["missing"]["changed"]), float(faults["moved"]["changed"]), float(faults["colour"]["changed"])])
	return {"set": number, "key": key, "page": page, "step": step.number, "steps": main_steps,
		"before": _number_of(pages, page - 1), "after": _number_of(pages, page + 1),
		"caption": pages.caption(page), "camera": camera, "light": light, "light_turn": light_turn,
		"faults": faults, "lots": lots, "references": refs, "parts_shown": shown.size(),
		"seen": seen.slice(0, 6)}


## A page's step number as the booklet prints it (a callout's step: the main step it is in).
func _number_of(pages: BuildSteps, page: int) -> int:
	var step: Instructions.Step = pages.step_of(page)
	return step.number if step != null else 0


func _box(brick_id: int) -> AABB:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	if mesh != null:
		return brick.transform * mesh.bounds
	return AABB(brick.transform.origin - Vector3(10, 10, 10), Vector3(20, 20, 20))


func _bounds(ids: Dictionary) -> AABB:
	var out := AABB()
	var any: bool = false
	for brick_id: int in ids:
		if _store.scenery.has(brick_id) or _world.get_brick(brick_id) == null:
			continue
		var box: AABB = _box(brick_id)
		out = box if not any else out.merge(box)
		any = true
	return out


## A phone held over a table: never the booklet's direction, looked down on,
## a little rolled, a 26 mm lens, the build filling most of the frame off its
## middle.
func _hand_held(rng: RandomNumberGenerator, bounds: AABB, view: Dictionary) -> Dictionary:
	var booklet: Vector3 = Vector3(view.get("from", BookletStudio.FRONT)).normalized()
	var booklet_yaw: float = rad_to_deg(atan2(booklet.x, booklet.z))
	var yaw: float = 0.0
	for _try: int in 50:
		yaw = rng.randf_range(-170.0, 170.0)
		if absf(wrapf(yaw - booklet_yaw, -180.0, 180.0)) >= 25.0:
			break
	var pitch: float = rng.randf_range(32.0, 60.0)
	var roll: float = rng.randf_range(1.5, 5.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var focal: float = 26.0
	var zoom: float = rng.randf_range(0.78, 0.92) * _zoom
	var shift := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1))
	var direction := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)),
		cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	var basis: Basis = StudioRender._looking_from(direction.normalized())
	basis = Basis(basis.z, deg_to_rad(roll)) * basis
	var fov: float = rad_to_deg(atan(12.0 / focal) * 2.0)
	var aspect: float = float(PHOTO.x) / float(PHOTO.y)
	var origin: Vector3 = StudioRender._fit(basis, bounds, fov, aspect)
	var forward: Vector3 = -basis.z
	var centre: Vector3 = bounds.get_center()
	var depth: float = (centre - origin).dot(forward)
	origin += forward * depth * (1.0 - 1.0 / zoom)
	depth /= zoom
	var half_up: float = tan(deg_to_rad(fov) * 0.5) * depth
	origin -= basis.x * shift.x * half_up * aspect + basis.y * shift.y * half_up
	return {"origin": [origin.x, origin.y, origin.z], "x": [basis.x.x, basis.x.y, basis.x.z],
		"y": [basis.y.x, basis.y.y, basis.y.z], "z": [basis.z.x, basis.z.y, basis.z.z], "fov": fov,
		"focal_mm": focal, "yaw": yaw, "pitch": pitch, "roll": roll, "booklet_yaw": booklet_yaw,
		"focus": [centre.x, centre.y, centre.z], "floor_y": bounds.position.y,
		"size": [PHOTO.x, PHOTO.y]}


func _transform(camera: Dictionary) -> Transform3D:
	var x: Array = camera["x"]
	var y: Array = camera["y"]
	var z: Array = camera["z"]
	var o: Array = camera["origin"]
	return Transform3D(Basis(Vector3(x[0], x[1], x[2]), Vector3(y[0], y[1], y[2]), Vector3(z[0], z[1], z[2])),
		Vector3(o[0], o[1], o[2]))


## Each new part with how much of the measuring picture goes when it does,
## most first: [[id, share], ...].
func _seen_parts(shown: Dictionary, fresh: Array, camera: Dictionary) -> Array:
	var whole: Image = await _look(shown, camera)
	var out: Array = []
	for brick_id: int in fresh:
		var less: Dictionary = shown.duplicate()
		less.erase(brick_id)
		out.append([brick_id, _changed(whole, await _look(less, camera))])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	_world.show_only(shown)
	return out


## The world as [param camera] sees it with only [param ids] shown, small.
func _look(ids: Dictionary, camera: Dictionary) -> Image:
	_world.show_only(ids)
	_see_eye.global_transform = _transform(camera)
	_see_eye.fov = float(camera["fov"])
	_see_eye.near = 1.0
	_see_eye.far = 100000.0
	await process_frame
	_see.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image: Image = _see.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	return image


## The share of pixels that differ by more than a little between two pictures.
func _changed(a: Image, b: Image) -> float:
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	if da.size() != db.size() or da.is_empty():
		return 0.0
	var differ: int = 0
	var n: int = 0
	while n < da.size():
		if absi(da[n] - db[n]) + absi(da[n + 1] - db[n + 1]) + absi(da[n + 2] - db[n + 2]) > 18:
			differ += 1
		n += 3
	return float(differ) / float(da.size() / 3)


## Where a brick is in the photo: its box's corners projected, as fractions of
## the frame from the top left [left, top, right, bottom].
func _screen_box(brick_id: int, camera: Dictionary) -> Array:
	var box: AABB = _box(brick_id)
	var eye: Transform3D = _transform(camera)
	var tan_up: float = tan(deg_to_rad(float(camera["fov"])) * 0.5)
	var aspect: float = float(PHOTO.x) / float(PHOTO.y)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = StudioRender._corner(box, n)
		var seen: Vector3 = eye.affine_inverse() * corner
		var depth: float = maxf(-seen.z, 0.001)
		var at := Vector2(0.5 + seen.x / depth / tan_up / aspect * 0.5, 0.5 - seen.y / depth / tan_up * 0.5)
		low = low.min(at)
		high = high.max(at)
	return [low.x, low.y, high.x, high.y]


func _fault(brick_id: int, camera: Dictionary, kind: String) -> Dictionary:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
	var colour: PartLibrary.BrickColor = _library.color(brick.color_code)
	return {"kind": kind, "brick": brick_id, "part": brick.part_id,
		"part_name": info.name.strip_edges() if info != null else brick.part_id,
		"colour": brick.color_code, "colour_name": colour.name if colour != null else str(brick.color_code),
		"box": _screen_box(brick_id, camera)}


## One stud across, the way that runs into the fewest other parts, and of
## those the way the photo shows most.
func _move_for(brick_id: int, shown: Dictionary, camera: Dictionary) -> Vector3:
	var box: AABB = _box(brick_id)
	var right: Vector3 = _transform(camera).basis.x
	var best := Vector3(STUD, 0, 0)
	var best_cost: float = INF
	for way: Vector3 in [Vector3(STUD, 0, 0), Vector3(-STUD, 0, 0), Vector3(0, 0, STUD), Vector3(0, 0, -STUD)]:
		var cost: float = 0.0
		var there := AABB(box.position + way, box.size)
		for other: int in shown:
			if other == brick_id or _store.scenery.has(other) or _world.get_brick(other) == null:
				continue
			var theirs: AABB = _box(other).grow(-1.0)
			cost += _overlap(there, theirs) - _overlap(box, theirs)
		# Seen across the frame reads as a move; along the line of sight less so.
		cost -= absf(way.normalized().dot(right)) * 0.01 * box.get_volume()
		if cost < best_cost:
			best_cost = cost
			best = way
	return best


func _overlap(a: AABB, b: AABB) -> float:
	var both: AABB = a.intersection(b)
	return both.get_volume() if both.has_volume() else 0.0


## Which ways a move reads in the photo: each of left/right and nearer/farther
## that carries a third of it or more.
func _toward(move: Vector3, camera: Dictionary) -> Array:
	var eye: Transform3D = _transform(camera)
	var right: Vector3 = eye.basis.x
	var ahead: Vector3 = -eye.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	right.y = 0.0
	right = right.normalized()
	var out: Array = []
	var across: float = move.dot(right) / move.length()
	var along: float = move.dot(ahead) / move.length()
	if absf(across) >= 0.33:
		out.append("right" if across > 0.0 else "left")
	if absf(along) >= 0.33:
		out.append("farther" if along > 0.0 else "nearer")
	return out


func _wrong_colour(code: int, near: bool) -> int:
	if near and NEAR_SHADES.has(code):
		return int(NEAR_SHADES[code])
	var was: PartLibrary.BrickColor = _library.color(code)
	var best: int = 4
	var far: float = -1.0
	for other: int in CLEAR_SWAPS:
		if other == code:
			continue
		var it: PartLibrary.BrickColor = _library.color(other)
		if it == null or was == null:
			continue
		var d: float = Vector3(it.rgb.r - was.rgb.r, it.rgb.g - was.rgb.g, it.rgb.b - was.rgb.b).length()
		if d > far:
			far = d
			best = other
	return best


func _photo_settings(camera: Dictionary, light: String, light_turn: float, seed: int,
		mask: bool) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.GOOD if mask else RenderSettings.Quality.BEST
	settings.look = "product"
	settings.size = PHOTO
	settings.samples = 0 if mask else _samples
	settings.seed = seed + 1
	settings.transparent = mask
	settings.backdrop = Color(0.62, 0.62, 0.62)
	settings.backdrop_gradient = false
	settings.lighting = light
	settings.light_turn = light_turn
	settings.focal_mm = float(camera["focal_mm"])
	settings.view = "current"
	settings.eye_transform = _transform(camera)
	settings.eye_fov = float(camera["fov"])
	settings.eye_orthogonal = false
	var focus: Array = camera["focus"]
	settings.eye_focus = Vector3(focus[0], focus[1], focus[2])
	return settings


## A step picture: Good, the window's look, on white, from [param side],
## framed on [param whole] (the next step's build) so N-1, N and N+1 line up.
func _side_settings(side: String, whole: AABB) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.GOOD
	settings.look = "window"
	settings.size = REF
	settings.backdrop = Color(1, 1, 1)
	settings.backdrop_gradient = true
	settings.lighting = "studio"
	settings.focal_mm = 50.0
	var basis: Basis = StudioRender._looking_from(Vector3(SIDES[side]).normalized())
	var fov: float = settings.fov_degrees()
	var origin: Vector3 = StudioRender._fit(basis, whole, fov, float(REF.x) / float(REF.y))
	settings.view = "current"
	settings.eye_transform = Transform3D(basis, origin)
	settings.eye_fov = fov
	settings.eye_orthogonal = false
	settings.eye_focus = whole.get_center()
	return settings


func _draw(settings: RenderSettings) -> Image:
	var picture: Image = await _render.render(_world, settings)
	return picture
