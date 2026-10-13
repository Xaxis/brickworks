## The selection drawn as an outline round what is selected, as CAD draws it.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##       --resolution 1400x900 --script src/dev/outline_probe.gd
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 2800x1800x24" godot --path . \
##       --resolution 2800x1800 --script src/dev/outline_probe.gd -- --tag=2x
##
## The second is twice the pixels, as a 2x screen draws the app. On Xvfb
## always: it moves the system's pointer.
##
## A chain of 29 links selected was drawn as a box round every link, yellow
## lines over the links' own faces: a scribble, and any big selection the
## same (seen live, 2026-10-12). Studio, Fusion and Onshape draw one clean
## line round the selection's silhouette instead.
##
## So this asks the picture, for one brick, a chain round two gears and a
## sub-assembly of Orthanc: what selecting changed (the outline), against
## where the selected parts are drawn (found by drawing them once in another
## colour). The outline must lie round them, not over them; it must go all
## the way round; and nothing else may change. Then all of Orthanc selected,
## timed, with nothing drawn while nothing moves; and the outline kept
## through the cut-away and x-ray.
##
## Pictures go to shots/outline/<tag>/.
extends SceneTree

## Two picture colours differing by more than this, in any channel, differ.
const CHANGED := 0.06

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Node
var _verbs: EditVerbs
var _tag: String = "1x"
## Window pixels to the interface's points.
var _scale: float = 1.0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
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
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_scale = float(root.size.x) / root.get_visible_rect().size.x
	print("  window %s, %.2f pixels to the point" % [root.size, _scale])
	# The pointer on the rail at the left, off the model: Xvfb starts it in
	# the middle of the screen, where the model is, and it would be hovered.
	_move(Vector2(8, 400))
	_main.call("clear_model")
	await _frames(4)

	await _one_brick()
	await _a_chain()
	await _orthanc()

	print("")
	if _failures == 0:
		print("outline: a selection is drawn as a line round its silhouette, never over "
			+ "it, for one part and for 9,000, and nothing is drawn standing still")
	else:
		print("outline: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# -- one brick ----------------------------------------------------------------


func _one_brick() -> void:
	print("\none brick")
	var turned := Basis(Vector3.UP, 0.0)
	var brick: int = _put("3001", 4, Transform3D(turned, Vector3(0, 24, 0)))
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-60, 0, -40), Vector3(120, 40, 80)), 1.6)
	await _frames(60)
	await _judge("brick", [brick], 1, true)
	_builder.clear_selection()
	await _frames(4)

	# The pointer on it, with Select in hand: a paler, finer line round what
	# a click would take; gone when it is taken, and when the pointer leaves.
	var middle: Vector2 = _camera.unproject_position(Vector3(0, 12, 0))
	_near = _region([brick])
	_move(middle)
	await _frames(6)
	var hovered: Image = await _picture()
	_save(hovered, "brick_hover")
	_check("the pointer on it outlines it faintly (%d pale blue pixels)" % _pale(hovered),
		_pale(hovered) > 100)
	_builder.select_brick(brick, false)
	await _frames(6)
	var taken: Image = await _picture()
	_check("...and clicked, it has the selection's line instead (%d pale, %d yellow)"
		% [_pale(taken), _coloured(taken)], _pale(taken) < 20 and _coloured(taken) > 100)
	_builder.clear_selection()
	_move(Vector2(8, 400))
	await _frames(6)
	_check("off it, nothing is outlined (%d pale pixels)" % _pale(await _picture()),
		_pale(await _picture()) < 20)
	_main.call("clear_model")
	await _frames(4)


# -- a chain ------------------------------------------------------------------


func _a_chain() -> void:
	print("\na chain round two gears")
	_put("3700", 71, Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
	_put("3700", 71, Transform3D(Basis.IDENTITY, Vector3(80, 24, 0)))
	var gears: Array = [
		_put("3648b", 71, Transform3D(Basis.IDENTITY, Vector3(-20, 110, 0))),
		_put("3648b", 71, Transform3D(Basis.IDENTITY, Vector3(110, 110, 0)))]
	var sprockets: Array = []
	for gear: int in gears:
		sprockets.append(Flex.sprocket_of(_world.get_brick(gear), _library))
	var laid: Flex.Laid = Flex.lay_chain("chain", sprockets)
	var links: Array = []
	for piece: Dictionary in laid.pieces:
		links.append(_put(str(piece["part"]), 4, piece["at"] as Transform3D))
	_check("a chain of %d links laid round two gears" % links.size(), links.size() > 20)
	_camera.set_view("default")
	_camera.frame(AABB(Vector3(-80, 0, -40), Vector3(240, 180, 100)), 1.3)
	await _frames(60)
	# On its gears, as it was seen live: the gears' teeth come in front of
	# links, and the line goes round the chain behind them.
	await _judge("chain_on_gears", links, 1, false)
	# ...and alone, so every edge of it on screen is the chain's own.
	_builder.clear_selection()
	for brick_id: int in gears:
		_builder.lattice.release(brick_id)
		_world.remove_brick(brick_id)
	await _drawn_now()
	await _judge("chain", links, 1, true)
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(4)


# -- Orthanc ------------------------------------------------------------------


func _orthanc() -> void:
	print("\nOrthanc")
	var placed: int = int(_main.call("_open", "res://models/orthanc.ldr"))
	await _frames(30)
	_check("Orthanc opens (%d parts)" % placed, placed > 8000)
	var whole: AABB = _main.call("_built_bounds")
	# The grey wizard on the roof, behind a pinnacle from the front.
	var gandalf: Array = _group("grey_wizard")
	var guard: Array = _group("tower_guard_2")
	_check("The grey wizard is a sub-assembly of %d parts, a guard one of %d" % [gandalf.size(),
		guard.size()], gandalf.size() > 5 and guard.size() > 5)
	if gandalf.is_empty() or guard.is_empty():
		return

	# The whole tower in view: a click on the grey wizard takes the sub-assembly, as
	# it does by hand.
	_camera.set_view("default")
	_camera.frame(whole)
	await _still()
	_builder.select_brick(gandalf[0], false)
	await _frames(2)
	_check("a click on the grey wizard selects all of him (%d of %d)" % [_builder.selection.size(),
		gandalf.size()], _builder.selection.size() == gandalf.size())
	await _judge("orthanc_gandalf", gandalf, 22, false)
	# The white wizard beside him, in the open.
	var saruman: Array = _group("white_wizard")
	_builder.select_brick(saruman[0], false)
	await _frames(2)
	await _judge("orthanc_saruman", saruman, 22, false)
	# ...and close to.
	_camera.frame(_bounds(gandalf), 4.0)
	await _still()
	await _judge("orthanc_gandalf_close", gandalf, 22, false)

	# All of it: 9,000 parts.
	_camera.frame(whole)
	await _still()
	_builder.clear_selection()
	await _frames(4)
	var bare_ms: float = await _frame_ms(6)
	var began: int = Time.get_ticks_usec()
	_verbs.select_by("all")
	var took_ms: float = float(Time.get_ticks_usec() - began) / 1000.0
	await _frames(4)
	var all_ms: float = await _frame_ms(6)
	print("    all %d selected in %.0f ms; a frame %.0f ms selected, %.0f ms not" % [
		_builder.selection.size(), took_ms, all_ms, bare_ms])
	_check("all %d parts selected in %.0f ms" % [_builder.selection.size(), took_ms],
		_builder.selection.size() > 8000 and took_ms < 3000.0)
	_check("a frame with all of them outlined costs %.0f ms against %.0f ms bare"
		% [all_ms, bare_ms], all_ms < bare_ms * 2.0 + 40.0)
	var everything: Image = await _picture()
	_save(everything, "orthanc_all")
	_check("...and the outline is round the tower: %d pixels of the selection's colour"
		% _coloured(everything), _coloured(everything) > 200)

	# Nothing drawn standing still, with all of it outlined.
	IdleDraw.begin()
	await _frames(20)
	var drawn: int = Engine.get_frames_drawn()
	await _frames(40)
	var idle: int = Engine.get_frames_drawn() - drawn
	IdleDraw.end()
	_check("standing still with 9,000 parts outlined, %d frames drawn in 40" % idle, idle == 0)
	_builder.clear_selection()
	await _frames(4)

	# Through the cut-away and x-ray, a guard at the foot of the tower.
	_camera.frame(_bounds(guard), 6.0)
	await _still()
	_builder.select_brick(guard[0], false)
	await _frames(4)
	var whole_guard: int = _coloured(await _picture())
	# The plane through his middle: the line goes round what is left of him.
	var see: Object = _shell.get("see_inside")
	see.call("set_cut", true)
	see.call("move_to", roundf(_bounds(guard).get_center().y * 0.5) * 2.0 + 1.0)
	await _settled()
	var cut: Image = await _picture()
	_save(cut, "orthanc_cut")
	_check("cut through the selected guard, what is left of him is outlined (%d pixels, %d whole)"
		% [_coloured(cut), whole_guard], bool(_world.call("is_cut")) and _coloured(cut) > 40
		and _coloured(cut) < whole_guard)
	see.call("set_cut", false)
	await _settled()
	see.call("set_xray", true)
	await _settled()
	var xray: Image = await _picture()
	_save(xray, "orthanc_xray")
	_check("in x-ray, the guard everything else is seen through is outlined (%d pixels)"
		% _coloured(xray), not (_world.call("xray_ids") as Dictionary).is_empty()
		and _coloured(xray) > 40)
	see.call("set_xray", false)
	await _settled()
	_builder.clear_selection()
	await _frames(4)


# -- judging a picture --------------------------------------------------------


## Pictures of [param ids] unselected, drawn in [param other] colour, and
## selected; what selecting changed is held against where they are drawn.
## [param whole] for parts nothing hides, whose outline must also keep to
## their silhouette all the way round.
func _judge(name: String, ids: Array, other: int, whole: bool) -> void:
	_builder.clear_selection()
	await _frames(6)
	var none: Image = await _picture()
	var was: Dictionary = {}
	for brick_id: int in ids:
		was[brick_id] = _world.get_brick(brick_id).color_code
		_world.recolor_brick(brick_id, other)
	await _drawn_now()
	var tinted: Image = await _picture()
	for brick_id: int in ids:
		_world.recolor_brick(brick_id, int(was[brick_id]))
	await _drawn_now()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())
	await _frames(6)
	var chosen: Image = await _picture()
	_save(none, name + "_none")
	_save(chosen, name)

	var region: Rect2i = _region(ids)
	var drawn: PackedByteArray = _differs(none, tinted, region)
	var outline: PackedByteArray = _differs(none, chosen, region)
	var w: int = region.size.x
	var h: int = region.size.y
	var inner: PackedByteArray = _eroded(drawn, w, h, 2)
	var to_drawn: PackedFloat32Array = _distance(drawn, w, h)
	var to_outline: PackedFloat32Array = _distance(outline, w, h)
	var drawn_n: int = 0
	var inner_n: int = 0
	var outline_n: int = 0
	var over: int = 0
	var stray: int = 0
	var edge_n: int = 0
	var edge_met: int = 0
	var reach: float = 3.0 * _scale + 4.0
	for n: int in w * h:
		drawn_n += drawn[n]
		inner_n += inner[n]
		if outline[n] == 1:
			outline_n += 1
			if inner[n] == 1:
				over += 1
			if to_drawn[n] > reach:
				stray += 1
		if drawn[n] == 1 and _on_edge(drawn, w, h, n):
			edge_n += 1
			# The baseplate's studs hide the foot of a brick standing on it
			# from the eye, and not from the mask: a strip a few pixels high,
			# twice as many at 2x, between the brick seen and its line.
			if to_outline[n] <= 2.5 * maxf(_scale, 1.0):
				edge_met += 1
	print("    %s: drawn %d px, %d inside; outline %d px, %d over the parts, %d away from them; "
		% [name, drawn_n, inner_n, outline_n, over, stray]
		+ "%d of %d edge pixels outlined" % [edge_met, edge_n])
	_check("%s: the selection is outlined (%d pixels changed)" % [name, outline_n],
		outline_n > 20)
	# A part hidden behind others has no inside on screen; its outline is
	# drawn over what hides it, which is what makes it findable.
	_check("%s: ...round the parts, not over them (%d of %d inside pixels changed)"
		% [name, over, inner_n], over <= inner_n / 200)
	if whole:
		_check("%s: ...close round them (%d of %d changed pixels more than %.0f px off)"
			% [name, stray, outline_n, reach], stray <= outline_n / 50)
		_check("%s: ...all the way round (%d of %d edge pixels)" % [name, edge_met, edge_n],
			edge_n > 0 and edge_met >= edge_n * 9 / 10)


## The selected parts' rectangle on screen, grown for the outline and clipped
## to the window.
func _region(ids: Array) -> Rect2i:
	var box: AABB = _bounds(ids)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = box.position + box.size * Vector3(n & 1, (n >> 1) & 1, (n >> 2) & 1)
		var at: Vector2 = _camera.unproject_position(corner) * _scale
		lo = lo.min(at)
		hi = hi.max(at)
	var grown: float = 24.0 * _scale
	var window := Rect2i(Vector2i.ZERO, root.size)
	var rect := Rect2i(Vector2i(lo - Vector2(grown, grown)), Vector2i(hi - lo + Vector2(grown, grown) * 2))
	return rect.intersection(window)


func _differs(a: Image, b: Image, region: Rect2i) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(region.size.x * region.size.y)
	for y: int in region.size.y:
		for x: int in region.size.x:
			var p: Color = a.get_pixel(region.position.x + x, region.position.y + y)
			var q: Color = b.get_pixel(region.position.x + x, region.position.y + y)
			var d: float = maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b)))
			out[y * region.size.x + x] = 1 if d > CHANGED else 0
	return out


func _eroded(mask: PackedByteArray, w: int, h: int, by: int) -> PackedByteArray:
	var out: PackedByteArray = mask.duplicate()
	var to_outside: PackedFloat32Array = _distance(_inverse(mask), w, h)
	for n: int in w * h:
		if mask[n] == 1 and to_outside[n] <= float(by):
			out[n] = 0
	return out


func _inverse(mask: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(mask.size())
	for n: int in mask.size():
		out[n] = 1 - mask[n]
	return out


## How far each pixel is from the nearest set one: a two-pass chamfer.
func _distance(mask: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	for n: int in w * h:
		d[n] = 0.0 if mask[n] == 1 else 1.0e6
	var s: float = sqrt(2.0)
	for y: int in h:
		for x: int in w:
			var n: int = y * w + x
			var v: float = d[n]
			if x > 0:
				v = minf(v, d[n - 1] + 1.0)
			if y > 0:
				v = minf(v, d[n - w] + 1.0)
				if x > 0:
					v = minf(v, d[n - w - 1] + s)
				if x < w - 1:
					v = minf(v, d[n - w + 1] + s)
			d[n] = v
	for y: int in range(h - 1, -1, -1):
		for x: int in range(w - 1, -1, -1):
			var n: int = y * w + x
			var v: float = d[n]
			if x < w - 1:
				v = minf(v, d[n + 1] + 1.0)
			if y < h - 1:
				v = minf(v, d[n + w] + 1.0)
				if x < w - 1:
					v = minf(v, d[n + w + 1] + s)
				if x > 0:
					v = minf(v, d[n + w - 1] + s)
			d[n] = v
	return d


func _on_edge(mask: PackedByteArray, w: int, h: int, n: int) -> bool:
	var x: int = n % w
	var y: int = n / w
	if x == 0 or y == 0 or x == w - 1 or y == h - 1:
		return false
	return mask[n - 1] == 0 or mask[n + 1] == 0 or mask[n - w] == 0 or mask[n + w] == 0


## Pixels of the picture in the selection's colour: yellow, lit.
func _coloured(image: Image) -> int:
	var count: int = 0
	for y: int in range(0, image.get_height()):
		for x: int in range(0, image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.r > 0.85 and c.g > 0.75 and c.b < 0.45:
				count += 1
	return count


## Pixels of the hover's pale blue, in [member _near]: the panels have
## links in a blue like it.
var _near: Rect2i = Rect2i()


func _pale(image: Image) -> int:
	var count: int = 0
	for y: int in range(_near.position.y, _near.end.y):
		for x: int in range(_near.position.x, _near.end.x):
			var c: Color = image.get_pixel(x, y)
			if c.b > 0.7 and c.b - c.r > 0.2 and c.g > 0.6:
				count += 1
	return count


## The pointer moved, the system's own: what is under it is read from where
## the system says it is (Viewport.get_mouse_position). On Xvfb, as the
## cursor probe is, since on a desktop that pointer is whoever's hand.
func _move(at: Vector2) -> void:
	Input.warp_mouse(at * _scale)
	var event := InputEventMouseMotion.new()
	event.position = at * _scale
	event.global_position = event.position
	Input.parse_input_event(event)


# -- the model ----------------------------------------------------------------


func _put(part: String, colour: int, where: Transform3D) -> int:
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _group(called: String) -> Array:
	var out: Array = []
	var plain := RegEx.create_from_string("[^a-z0-9]+")
	for brick: BrickWorld.Brick in _world.bricks():
		if plain.sub(brick.group.to_lower(), "_", true).begins_with(called):
			out.append(brick.id)
	return out


func _bounds(ids: Array) -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		var one: AABB = brick.transform * part.bounds
		box = one if first else box.merge(one)
		first = false
	return box


# -- frames and pictures ------------------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## Until the camera has come to rest: a frame of Orthanc on a software
## renderer is most of a second, and the camera's easing is by the clock.
func _still() -> void:
	var was: Transform3D = _camera.global_transform
	for _n: int in 120:
		await _frames(2)
		if _camera.global_transform.is_equal_approx(was):
			return
		was = _camera.global_transform


func _settled() -> void:
	await _frames(4)
	while _world.call("is_revealing") or _world.is_drawing_held():
		await process_frame
	await _frames(8)


## The world's changes written now, not a slice a frame (FramePace).
func _drawn_now() -> void:
	await process_frame
	_world.call("_flush")
	await _frames(3)


func _frame_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var began: int = Time.get_ticks_usec()
	for _n: int in count:
		await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - began) / 1000.0 / count


func _picture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save(image: Image, name: String) -> void:
	var path: String = ProjectSettings.globalize_path("res://shots/outline/%s/%s.png" % [_tag, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/outline/%s/%s.png" % [_tag, name])
