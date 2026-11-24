## A part put down inside a sub-assembly being edited goes into it, and its
## copies follow, as a person does it: a double-click into the wing, a part
## taken from the bin by its tile, and a click on the wing. Fresh, and on the
## same model saved and opened again (the web's assembly_flow, which placed
## nothing there from rel-m324: wingplace).
##
##   godot --path . --resolution 1100x700 --script src/dev/wingplace_probe.gd
##
## Every gesture is a click or a key sent as an input event against the real
## scene, as assembly_probe's.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _verbs: EditVerbs
var _shell: Shell
var _tree: Assemblies
var _bin: PartsBin
var _wedge: String = ""


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
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	_tree = _shell.assemblies
	_main.call("clear_model")
	Carry.clipboard = []

	await _make_plane()
	await _put_inside("as made")
	await _key(KEY_Z, true)
	_check("saved as Kit car", _store.save_as("Kit car"))
	var placed: int = _store.open(ModelStore.saved_path("Kit car"))
	await _frames(10)
	_check("...and opened again (%d parts; tree %s)" % [placed, str(_tree.paths())],
		placed == _count() and _tree.ids_under("Wing#1").size() == 3)
	_frame_view()
	await _frames(40)
	var before_plate: Dictionary = _parts_now()
	await _put_inside("saved and opened again")
	# Saved with the plate and opened again, part by part: the plate in Wing#1
	# and its twin in Wing#2 are all that is new, and nothing else moved.
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	var with_plate: Dictionary = _parts_now()
	_check("saved with the plate", _store.save_as("Kit car plate"))
	_store.open(ModelStore.saved_path("Kit car plate"))
	await _frames(10)
	var reopened: Dictionary = _parts_now()
	var added: Array = []
	for key: String in with_plate:
		if int(with_plate[key]) != int(before_plate.get(key, 0)):
			added.append(key)
	var gone: int = 0
	for key: String in before_plate:
		if int(with_plate.get(key, 0)) < int(before_plate[key]):
			gone += 1
	_check("...opened again part by part as saved (%d kinds, %d back)" % [with_plate.size(), reopened.size()],
		reopened == with_plate)
	_check("...the plate in Wing#1 and its twin in Wing#2 the only parts new, nothing moved (%s; %d moved or gone)"
		% [str(added), gone], added.size() == 2 and gone == 0
		and added.any(func(k: String) -> bool: return k.begins_with("Wing#1 "))
		and added.any(func(k: String) -> bool: return k.begins_with("Wing#2 ")))
	_frame_view()
	await _frames(20)
	await _beside()
	await _big()

	print("")
	if _failures == 0:
		print("wingplace: a part put down inside an edited sub-assembly goes into it, fresh and reopened")
	else:
		print("wingplace: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## The plane of assembly_probe: a body of two bricks, and a wing on the left
## (a plate, a brick on it, a wedge plate) made the sub-assembly Wing, copied
## and mirrored to the right.
func _make_plane() -> void:
	_wedge = _library.resolve("41769")
	_put("3001", 1, Vector3(0, 24, 0))
	_put("3001", 1, Vector3(0, 24, -80))
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	_put(_wedge, 14, Vector3(-120, 16, 40))
	await _frames(3)
	_frame_view()
	await _frames(40)
	var wing: Array = _model().filter(func(b: BrickWorld.Brick) -> bool:
		return b.transform.origin.x < -50.0).map(func(b: BrickWorld.Brick) -> int: return b.id)
	_select_only(wing)
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_check("the three wing parts are the sub-assembly Wing",
		wing.all(func(b: int) -> bool: return Assemblies.path_of(_world.get_brick(b)) == "Wing#1"))
	_select_only(Array(_tree.ids_under("Wing#1")))
	_verbs.duplicate_selection()
	var spot: Vector2 = _clear_spot([Vector3(120, 0, -40), Vector3(120, 0, 40),
		Vector3(160, 0, -40), Vector3(0, 0, 180), Vector3(80, 0, 200)])
	await _move(spot)
	await _move(spot + Vector2(1, 0))
	await _click(spot + Vector2(1, 0))
	await _key(KEY_ESCAPE)
	var copy: PackedInt64Array = _tree.ids_under("Wing#2")
	_select_only(Array(copy))
	_camera.set_view("top")
	await _frames(30)
	await _key(KEY_M, false, true)
	_camera.set_view("default")
	_frame_view()
	await _frames(40)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	_check("a second Wing, mirrored (%s)" % str(_tree.paths()),
		_tree.ids_under("Wing#2").size() == 3)


## Edit inside the left wing by a double-click, take a 1 x 2 plate from the
## bin by its tile, and click it down on the wing's plate.
func _put_inside(label: String) -> void:
	print("  a plate put down inside the wing, %s" % label)
	await _click_tool("mode_select")
	var left_plate: int = _of_part("Wing#1", "3034")
	await _double_click(_on(left_plate))
	_check("a double-click edits inside the wing (%s)" % _tree.entered, _tree.entered == "Wing#1")
	_bin._on_part("3023")
	await _frames(5)
	var on_plate: Vector2 = _clear_spot([Vector3(-60, 8, -40), Vector3(-60, 8, 40),
		Vector3(-160, 8, -40)])
	await _move(on_plate)
	await _move(on_plate + Vector2(1, 0))
	var count: int = _count()
	print("    before the click: mode %s, holding %s, carrying %s, ghost %s %s, into \"%s\", editing \"%s\""
		% [_verbs.mode, _builder.held_part, _builder.is_carrying(), _builder.has_preview(),
		_builder.get("_ghost_valid"), _builder.place_group, _tree.entered])
	await _click(on_plate + Vector2(1, 0))
	await _frames(5)
	print("    after: %d parts (were %d), said \"%s\"" % [_count(), count,
		_shell.status.fields()["message"]])
	_check("a plate put down while editing goes into the wing (%d in Wing#1)"
		% _tree.ids_under("Wing#1").size(), _tree.ids_under("Wing#1").size() == 4)
	_check("...and the right wing follows with its own (%d in Wing#2, %d parts, were %d)"
		% [_tree.ids_under("Wing#2").size(), _count(), count],
		_tree.ids_under("Wing#2").size() == 4 and _count() == count + 2)
	await _shot("put_inside_%s" % label.replace(" ", "_"))
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)


## The web's assembly_flow since ux14: Ctrl+D puts the copy down at once
## beside the wing, and Shift-M mirrors it where it stands, so the two wings
## stand side by side. Edited inside the first, a plate is aimed at the ground
## all round it; each place whose ghost says it fits is clicked.
func _beside() -> void:
	print("  the copy put beside by Ctrl+D and mirrored there")
	_main.call("clear_model")
	await _frames(3)
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	_put(_wedge, 14, Vector3(-120, 16, 40))
	await _frames(3)
	_frame_view()
	await _frames(30)
	_select_only(_model().map(func(b: BrickWorld.Brick) -> int: return b.id))
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_select_only(Array(_tree.ids_under("Wing#1")))
	await _key(KEY_D, true)
	await _frames(3)
	_check("Ctrl+D puts a second Wing beside it (%s, %d selected)" % [str(_tree.paths()),
		_builder.selection.size()], _tree.ids_under("Wing#2").size() == 3)
	_select_only(Array(_tree.ids_under("Wing#2")))
	await _key(KEY_M, false, true)
	await _frames(3)
	for path: String in ["Wing#1", "Wing#2"]:
		for brick_id: int in _tree.ids_under(path):
			var b: BrickWorld.Brick = _world.get_brick(brick_id)
			print("    %s %s at %s, mirrored %s" % [path, b.part_id, str(b.transform.origin),
				b.transform.basis.determinant() < 0.0])
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	await _click_tool("mode_select")
	await _double_click(_on(_of_part("Wing#1", "3034")))
	_check("a double-click edits inside the wing (%s)" % _tree.entered, _tree.entered == "Wing#1")
	_bin._on_part("3023")
	await _frames(5)
	await _sweep("a plate from the bin", 2)
	await _key(KEY_ESCAPE)
	# The same from the clipboard: the wing's brick copied inside it, pasted,
	# and aimed all round (a paste goes into the wing being edited).
	_select_only([_of_part("Wing#1", "3004")])
	await _key(KEY_C, true)
	await _key(KEY_V, true)
	await _frames(3)
	_check("Ctrl+V holds a copy of the brick (%s)" % _builder.is_carrying(), _builder.is_carrying())
	# A paste is put down once: pasted again for the next place.
	await _sweep("a brick pasted", 2, func() -> void:
		await _key(KEY_V, true)
		await _frames(2))
	await _key(KEY_ESCAPE)
	# Dragged inside the wing being edited, and picked out of it from outside
	# (a part's row in the tree selects it alone): either way it goes back
	# into its own wing, and the twin follows.
	_tree.enter("Wing#1")
	await _frames(2)
	await _drag_sweep("a brick dragged inside the wing", "Wing#1")
	_tree.enter("")
	await _frames(2)
	await _drag_sweep("a brick of the wing picked out from outside it and dragged", "")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)


## An ask cut short goes on where it stopped, and gives what an ask in one
## go gives, never "room" for having been cut: four more of what is in hand
## far off on the ground, asked first, and then it where the ghost said
## [param words], a microsecond at a time.
func _cut_short(words: String) -> void:
	if not _tree.has_method("room_in_copies"):
		return
	var item: Array = (_builder.call("_going_down") as Array)[0]
	var items: Array = []
	for n: int in 4:
		items.append([item[0], (item[1] as Transform3D).translated(Vector3(2000.0 + 200.0 * n, 0.0, 0.0))])
	items.append(item)
	var ask: Dictionary = {"items": items}
	var calls: int = 0
	var answer: Variant = null
	while answer == null and calls < 100:
		answer = _tree.call("room_in_copies", ask, 1)
		calls += 1
	_check("an ask cut short goes on where it stopped and says the same (%d calls: \"%s\")"
		% [calls, answer], calls > 1 and answer != null and str(answer) == words)


## What the ask costs a frame on a big set: the Millennium Falcon (10179)
## opened, the copied sub-assembly of most parts edited, a plate aimed at
## points all over it. The copies' fits are read once a model (what the
## follow reads for every click there), timed and said; each aim after asks
## for 4 ms at most, and one not done goes on next frame.
func _big() -> void:
	if not _tree.has_method("room_in_copies"):
		return
	var placed: int = _store.open(ProjectSettings.globalize_path("res://vendor/omr/files/10179-1.mpd"))
	await _frames(20)
	var most: String = ""
	var size: int = 0
	for path: String in _tree.paths():
		var copies: int = _tree.copies_of(path).size()
		var parts: int = _tree.ids_under(path).size()
		if copies > 0 and parts > size:
			most = path
			size = parts
	_check("10179 opened with a copied sub-assembly (%d parts; %s, %d parts, %d other copies)"
		% [placed, most, size, _tree.copies_of(most).size() if not most.is_empty() else 0],
		placed > 1000 and not most.is_empty())
	if most.is_empty():
		return
	_tree.enter(most)
	await _frames(3)
	_bin._on_part("3023")
	await _frames(5)
	var box := AABB()
	var first: bool = true
	for brick_id: int in _tree.ids_under(most):
		var b: BrickWorld.Brick = _world.get_brick(brick_id)
		var mesh: Lbm.PartMesh = _library.mesh_for(b.part_id)
		if mesh == null:
			continue
		var one: AABB = (b.transform * mesh.bounds).abs()
		box = one if first else box.merge(one)
		first = false
	_camera.frame(box, 1.4)
	await _frames(10)
	# The fits read afresh, as after an edit: timed alone.
	var began: int = 0
	var fits_us: int = 1 << 40
	for _try: int in 3:
		_tree.set("_copies_key", [])
		began = Time.get_ticks_usec()
		_tree.call("_copies_laid", most)
		fits_us = mini(fits_us, Time.get_ticks_usec() - began)
	var slowest: int = 0
	var slowest_alone: int = 0
	var aims: int = 0
	var reds: int = 0
	var greens: int = 0
	var told_wrong: Array = []
	var twins: int = _tree.copies_of(most).size()
	var size_px: Vector2 = Vector2(root.size)
	for i: int in 6:
		for j: int in 6:
			var at := Vector2(size_px.x * (0.2 + 0.12 * i), size_px.y * (0.2 + 0.12 * j))
			if not _clickable(at):
				continue
			# The pointer moved there, and the aim timed as the app makes it at
			# the pointer (Main._refresh_preview): alone first, the copies not
			# asked, then again with them; what the ask adds is the difference.
			await _move(at)
			await _frames(2)
			# The least of three tries each: on a box at load 90 one try is
			# preempted now and then (a 3-part wing's ask "took" 20 ms). The
			# fits, read once after each edit, are timed apart (fits_us).
			var room: Callable = _builder.copies_room
			_tree.call("_copies_laid", most)
			var alone: int = 1 << 40
			var with_ask: int = 1 << 40
			for _try: int in 3:
				_builder.copies_room = Callable()
				began = Time.get_ticks_usec()
				_main.call("_refresh_preview")
				alone = mini(alone, Time.get_ticks_usec() - began)
				_builder.copies_room = room
				began = Time.get_ticks_usec()
				_main.call("_refresh_preview")
				with_ask = mini(with_ask, Time.get_ticks_usec() - began)
			slowest = maxi(slowest, with_ask - alone)
			slowest_alone = maxi(slowest_alone, alone)
			await _asked()
			# Read as the click finds it: the pointer moved there again first, as
			# _click moves it, and what the ghost says then is what is judged.
			await _move(at)
			await _asked()
			var words: String = _builder.copies_refuse
			var fits: bool = _builder.can_place()
			if not fits and words.is_empty():
				continue
			aims += 1
			# ...and clicked, as a person would: the follow judges it on the set.
			var count: int = _count()
			var told: String = _told(false)
			var others: Dictionary = {}
			for other: String in Array(_tree.copies_of(most)) + [most]:
				for brick_id: int in _tree.ids_under(other):
					others[brick_id] = true
			# The press and release of _click, the pointer already there.
			var pressed_on: Vector3 = (_builder.get("_ghost_transform") as Transform3D).origin
			_button(at, true)
			await _frames(2)
			_button(at, false)
			await _frames(7)
			var put: int = _count() - count
			# Where the click and the follow put them, beside where the ask laid them.
			var laid_words: String = " (ghost at the press %s)" % str(pressed_on.snappedf(0.1))
			for other: String in Array(_tree.copies_of(most)) + [most]:
				for brick_id: int in _tree.ids_under(other):
					if not others.has(brick_id):
						var b: BrickWorld.Brick = _world.get_brick(brick_id)
						laid_words += " %s %s at %s;" % [other, b.part_id, str(b.transform.origin.snappedf(0.1))]
			if fits:
				greens += 1
				if put != 1 + twins and told_wrong.size() < 6:
					told_wrong.append("green took %d (\"%s\")\n        %s\n        the click:%s"
						% [put, _tree.refused, told, laid_words])
			else:
				reds += 1
				if (put != 0 or _tree.refused != words) and told_wrong.size() < 6:
					told_wrong.append("red took %d, refused \"%s\", said \"%s\"\n        %s\n        the follow laid:%s"
						% [put, _tree.refused, words, told, laid_words])
			if put > 0:
				await _key(KEY_Z, true)
				await _frames(2)
	print("    10179's %s: its copies' fits read in %d us; the most an ask added to an aim %d us (the aim alone at most %d us, each after an edit's undo); %d places clicked, %d green, %d red for a copy"
		% [most, fits_us, slowest, slowest_alone, aims, greens, reds])
	for one: String in told_wrong:
		print("      " + one)
	_check("...what the ask adds to an aim within a frame's 16 ms, the least of three tries (%d us)" % slowest,
		slowest < 16000)
	_check("...and the copies' fits, read once after an edit, within one too (%d us)" % fits_us, fits_us < 16000)
	_check("...and on the set the ghost says what the click does: each green put down with its twin, each red refused in its words (%d wrong of %d)"
		% [told_wrong.size(), aims], aims > 0 and told_wrong.is_empty())
	await _key(KEY_ESCAPE)
	_tree.enter("")


## What the ask saw, for a run read back: the hand, the copies it fits and
## where it lays each twin, and its answer asked afresh in one go.
func _told(carried: bool) -> String:
	if not _tree.has_method("room_in_copies"):
		return ""
	var going: Array = _builder.call("_going_down")
	var words: String = "lifted %s on top %s aimed %s valid %s ask pending %s; hand %s; " % [
		_builder.carrying.lifted if carried else false, _builder.call("_lift_on_top"),
		_builder.carrying.is_aimed() if carried else _builder.has_preview(),
		_builder.carrying.get("_valid") if carried else _builder.get("_ghost_valid"),
		not (_builder.get("_copies_ask") as Dictionary).is_empty(),
		str(going.map(func(i: Array) -> String: return "%s at %s" % [i[0],
			str((i[1] as Transform3D).origin.snappedf(0.1))]))]
	var into: String = _builder.call("_copies_path")
	var copies: Array = _tree.call("_copies_laid", into)
	words += "into \"%s\" (editing \"%s\"), %d copies fit:" % [into, _tree.entered, copies.size()]
	if copies.is_empty():
		# Why none: each copy as _copies_laid reads it.
		var then: Dictionary = _tree.get("_copies_then")
		var source: Array = _tree.call("_read_then", into)
		words += " (%d then [%s], %d parts:" % [then.size(),
			", ".join(then.keys().map(func(k: int) -> String: return "%d %s" % [k,
				"null" if then[k] == null else str((then[k] as Dictionary).get("group", "?"))])),
			source.size()]
		for other: String in _tree.copies_of(into):
			var twin: Array = _tree.call("_read_then", other)
			var fit: Dictionary = _tree.best_match(source, twin) if not twin.is_empty() else {"score": -1}
			words += " %s %d parts score %s laid on %d;" % [other, twin.size(), fit["score"],
				(_tree.call("_laid_on", source, twin, fit) as Dictionary).size() if fit.has("at") else -1]
		words += ")"
	for copy: Array in copies:
		var fit: Dictionary = copy[1]
		words += " %s (mirrored %s, round %s)" % [copy[0], fit.get("mirrored", "?"), copy[3]]
		for item: Array in going:
			var laid: Array = _tree.call("_laid", fit, library_id(str(item[0])), item[1])
			words += " twin %s at %s" % [laid[0], str((laid[1] as Transform3D).origin.snappedf(0.1))]
	words += "; asked again: \"%s\"" % str(_tree.call("room_in_copies", {"items": going, "path": into}, 0))
	return words


## Frames until an ask the aim began is answered (30 at most), as a person's
## pointer rests a moment before the click.
func _asked() -> void:
	for _n: int in 30:
		var pending: Variant = _builder.get("_copies_ask")
		if pending == null or (pending as Dictionary).is_empty():
			return
		await _frames(1)


func library_id(part: String) -> String:
	return _library.resolve(part)


## Every part of the model by where it is in the tree, its number, colour and
## place to a tenth of an LDU: key -> how many.
func _parts_now() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _model():
		var at: Transform3D = brick.transform
		var key: String = "%s %s %d %s %s" % [Assemblies.path_of(brick), brick.part_id, brick.color_code,
			str(at.origin.snappedf(0.1)), str([at.basis.x.snappedf(0.01), at.basis.y.snappedf(0.01),
			at.basis.z.snappedf(0.01)])]
		out[key] = int(out.get(key, 0)) + 1
	return out


## The box round the wing being edited, on the ground.
func _wing_box() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in _tree.ids_under("Wing#1"):
		var b: BrickWorld.Brick = _world.get_brick(brick_id)
		var mesh_box: AABB = (b.transform * _library.mesh_for(b.part_id).bounds).abs()
		box = mesh_box if first else box.merge(mesh_box)
		first = false
	return box


## Whether what is in hand is drawn as fitting: the ghost's or the carry's
## "valid".
func _drawn_fits() -> bool:
	var materials: Array = _builder.carrying.get("_materials") if _builder.is_carrying() \
		else [_builder.get("_ghost_material")]
	if materials.is_empty() or materials[0] == null:
		return false
	return bool((materials[0] as ShaderMaterial).get_shader_parameter("valid"))


## The wing's brick dragged inside it, by the Select tool, to the ground all
## round it two studs apart, and let go of there: its lift is one step with
## its put, and the follow pairs the copies by what they were before the lift
## (the twin taken off as it was picked up). Where the ghost is green the
## brick and its twin move; where red for the copy, nothing does. [param what]
## names the sweep; [param editing], the sub-assembly entered for it.
func _drag_sweep(what: String, editing: String) -> void:
	_check("%s: entered \"%s\" (%s)" % [what, editing, _tree.entered], _tree.entered == editing)
	var box: AABB = _wing_box()
	var green: int = 0
	var green_put: int = 0
	var red: int = 0
	var red_put: int = 0
	var red_said: int = 0
	var drawn_wrong: int = 0
	var wrong: Array = []
	for x: int in range(int(box.position.x) - 60, int(box.end.x) + 61, 40):
		for z: int in range(int(box.position.z) - 60, int(box.end.z) + 61, 40):
			var target: Vector2 = _screen(Vector3(float(x), 0.0, float(z)))
			var brick: int = _of_part("Wing#1", "3004")
			if brick == 0 or not _clickable(target):
				continue
			var from: Vector2 = _on(brick)
			var depth: int = _builder.history_depth()
			_select_only([brick])
			await _move(from)
			_button(from, true)
			await _frames(2)
			var last: Vector2 = from
			for k: int in range(1, 7):
				var next: Vector2 = from.lerp(target, float(k) / 6.0)
				await _drag_move(last, next)
				last = next
			await _drag_move(last, target + Vector2(1, 0))
			await _asked()
			var asked: Variant = _builder.get("copies_refuse")
			var predicted: String = "" if asked == null else str(asked)
			var fits: bool = _builder.can_place()
			var carried: bool = _builder.is_carrying()
			var heard: String = _shell.status.fields()["message"]
			if carried and (fits or not predicted.is_empty()) and _drawn_fits() != fits:
				drawn_wrong += 1
			var told: String = _told(carried)
			await _button(target + Vector2(1, 0), false)
			await _frames(3)
			var put: bool = _builder.history_depth() > depth
			if carried and fits:
				green += 1
				if put and _tree.ids_under("Wing#2").size() == 3:
					green_put += 1
				elif wrong.size() < 6:
					wrong.append("green drag to %s: %s (\"%s\")\n        %s" % [str(Vector3(x, 0, z)),
						"moved" if put else "not moved", _tree.refused, told])
			elif carried and not predicted.is_empty():
				red += 1
				red_put += 1 if put else 0
				red_said += 1 if heard == predicted else 0
				if put and wrong.size() < 6:
					wrong.append("red drag to %s moved it (\"%s\")" % [str(Vector3(x, 0, z)), predicted])
			if put:
				await _key(KEY_Z, true)
				await _frames(2)
			if _builder.is_carrying():
				await _key(KEY_ESCAPE)
	print("    %s: %d places green, %d moved with its twin; %d red for the copy, %d moved, %d said; %d drawn otherwise"
		% [what, green, green_put, red, red_put, red_said, drawn_wrong])
	for one: String in wrong:
		print("      " + one)
	_check("%s: every green ghost moves it and its twin (%d of %d)"
		% [what, green_put, green], green > 0 and green_put == green)
	_check("...every ghost red for the copy moves nothing, and says why (%d red, %d moved, %d said)"
		% [red, red_put, red_said], red > 0 and red_put == 0 and red_said == red)
	_check("...each drawn as it is (%d not)" % drawn_wrong, drawn_wrong == 0)


## What is in hand aimed at the ground all round the wing being edited, a
## stud apart, and clicked wherever its ghost stands: each ghost that says it
## fits takes the part, and its copy's twin [param twins] parts in all; each
## red only for the copy (Builder.copies_refuse) is said as it turns red and
## takes nothing, the click's refusal in the same words.
func _sweep(what: String, twins: int, again: Callable = Callable()) -> void:
	var box: AABB = _wing_box()
	var drawn_wrong: int = 0
	var cut_asked: bool = false
	var green: int = 0
	var green_put: int = 0
	var red: int = 0
	var red_put: int = 0
	var red_said: int = 0
	var same_words: int = 0
	var wrong: Array = []
	var shown: Array = []
	var slowest: int = 0
	for x: int in range(int(box.position.x) - 60, int(box.end.x) + 61, 20):
		for z: int in range(int(box.position.z) - 60, int(box.end.z) + 61, 20):
			var at: Vector2 = _screen(Vector3(float(x), 0.0, float(z)))
			if not _clickable(at):
				continue
			if again.is_valid() and not _builder.is_carrying():
				await again.call()
			await _move(at)
			await _move(at + Vector2(1, 0))
			# By name: a build from before wingplace has none, and is run to
			# show its green ghosts refused.
			var asked: Variant = _builder.get("copies_refuse")
			var predicted: String = "" if asked == null else str(asked)
			var fits: bool = _builder.can_place()
			if not fits and predicted.is_empty():
				continue
			# What one aim's ask costs, unbounded, here.
			if _tree.has_method("room_in_copies"):
				var began: int = Time.get_ticks_usec()
				_tree.call("room_in_copies", {"items": _builder.call("_going_down")}, 0)
				slowest = maxi(slowest, Time.get_ticks_usec() - began)
			if _drawn_fits() != fits:
				drawn_wrong += 1
			# Before the click: a paste refused is let go of.
			if not fits and not cut_asked:
				cut_asked = true
				_cut_short(predicted)
			var heard: String = _shell.status.fields()["message"]
			var count: int = _count()
			await _click(at + Vector2(1, 0))
			await _frames(3)
			var put: bool = _count() > count
			if fits:
				green += 1
				if put and _count() == count + twins:
					green_put += 1
				elif wrong.size() < 6:
					wrong.append("green at %s took %d (\"%s\")" % [str(Vector3(x, 0, z)), _count() - count,
						_tree.refused])
			else:
				red += 1
				red_put += 1 if put else 0
				red_said += 1 if heard == predicted else 0
				same_words += 1 if _tree.refused == predicted else 0
				if (heard != predicted or _tree.refused != predicted) and wrong.size() < 6:
					wrong.append("red at %s: said \"%s\", refused \"%s\"" % [str(Vector3(x, 0, z)),
						heard, _tree.refused])
				if put and wrong.size() < 6:
					wrong.append("red at %s took %d (\"%s\")" % [str(Vector3(x, 0, z)), _count() - count,
						predicted])
				if shown.is_empty():
					shown.append(predicted)
					await _shot("red_%s" % what.replace(" ", "_"))
			if put:
				await _key(KEY_Z, true)
				await _frames(2)
	print("    %s: %d places green, %d of them put down with the twin; %d red for the copy, %d put down, %d said as it turned red, %d refused in the same words; the slowest ask %d us"
		% [what, green, green_put, red, red_put, red_said, same_words, slowest])
	for one: String in wrong:
		print("      " + one)
	for one: String in shown:
		print("      red says: " + one)
	_check("%s: every green ghost takes the part and the copy its twin (%d of %d)" % [what, green_put,
		green], green > 0 and green_put == green)
	_check("...every ghost red for the copy takes nothing (%d red, %d put)" % [red, red_put],
		red > 0 and red_put == 0)
	_check("...and says why as it turns red, in the words the click's refusal says (%d, %d of %d)"
		% [red_said, same_words, red], red_said == red and same_words == red)
	_check("...each ghost drawn as it is, green where it fits and red where not (%d not)" % drawn_wrong,
		drawn_wrong == 0)


func _frame_view() -> void:
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)


func _of_part(path: String, part: String) -> int:
	for brick_id: int in _tree.ids_under(path):
		if _world.get_brick(brick_id).part_id.begins_with(part):
			return brick_id
	return 0


func _on(brick_id: int) -> Vector2:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	var box: AABB = (brick.transform * mesh.bounds).abs()
	var top: float = box.end.y - 4.0
	for share: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3),
			Vector2(0.3, -0.3), Vector2(-0.3, -0.3), Vector2(0.4, 0), Vector2(-0.4, 0)]:
		var at: Vector2 = _screen(Vector3(box.get_center().x + box.size.x * share.x, top,
			box.get_center().z + box.size.z * share.y))
		if _clickable(at) and _verbs.brick_at(at) == brick_id:
			return at
	print("    (no point of %s is clear of the panels to click)" % brick.part_id)
	return _screen(Vector3(box.get_center().x, top, box.get_center().z))


func _clickable(at: Vector2) -> bool:
	return root.get_visible_rect().grow(-4.0).has_point(at) and not _main.call("_over_panel_at", at)


func _clear_spot(places: Array) -> Vector2:
	for place: Vector3 in places:
		var at: Vector2 = _screen(place)
		if _clickable(at):
			return at
	print("    (none of %s is clear of the panels)" % str(places))
	return _screen(places[0])


func _click_tool(name: String) -> void:
	var button: Button = _shell.toolbar._buttons[name]
	await _click(button.get_global_rect().get_center())


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


## A move with the left button held, from [param from]: a drag, as the
## window hands it over.
func _drag_move(from: Vector2, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = _as_event(at) - _as_event(from)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool, twice: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.double_click = twice and down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _double_click(at: Vector2) -> void:
	await _click(at)
	_button(at, true, true)
	await _frames(2)
	_button(at, false)
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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/wingplace"))
	image.save_png(ProjectSettings.globalize_path("res://shots/wingplace/%s.png" % name))
	print("    picture: shots/wingplace/%s.png" % name)
