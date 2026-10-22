## What a model stands on: a baseplate of a size and colour, the grid
## floor, or nothing — chosen, saved, built on, counted and pictured.
##
##   godot --path . --resolution 1400x900 --script src/dev/floor_probe.gd
##
## Against the real scene. Placing is a click sent as an input event at
## where a spot on the ground is drawn, so the first part on each floor
## lands where a person's would. Pictures of each floor go to shots/floor/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _floor: FloorLayer


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
	_floor = _main.get("_floor")

	_cutting_plates()
	await _each_floor_round_trip()
	await _placing_on_each_floor()
	await _part_of_the_model()
	await _a_file_with_its_own_plate()
	await _the_designer_chooses()
	await _pictures()
	await _settings()

	print("")
	if _failures == 0:
		print("floor: every floor is chosen, saved, built on, counted and pictured as it says")
	else:
		print("floor: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Custom sizes cut into baseplates LDraw has, covering the size exactly.
func _cutting_plates() -> void:
	print("  baseplates of any size, in eights")
	for size: Vector2i in [Vector2i(16, 16), Vector2i(32, 32), Vector2i(48, 48),
			Vector2i(24, 24), Vector2i(40, 40), Vector2i(24, 56), Vector2i(8, 8),
			Vector2i(96, 64), Vector2i(50, 50), Vector2i(16, 32)]:
		var floor_of: ModelFloor = ModelFloor.make(ModelFloor.BASEPLATE, size.x, size.y)
		var plates: Array = floor_of.plates()
		var covered: float = 0.0
		var known: bool = true
		var box := AABB()
		var first: bool = true
		for plate: Array in plates:
			var info: PartLibrary.PartInfo = _library.parts.get(str(plate[0]))
			known = known and info != null
			if info == null:
				continue
			var turned: Basis = Basis(Vector3.UP, PI * 0.5) if bool(plate[2]) else Basis.IDENTITY
			var here: AABB = (Transform3D(turned, plate[1]) * info.bounds).abs()
			covered += here.size.x * here.size.z
			box = here if first else box.merge(here)
			first = false
		var wanted := Vector2(size.x * BrickLattice.STUD, size.y * BrickLattice.STUD)
		_check("%d x %d is %d plate%s LDraw has (%s), covering it exactly" % [size.x, size.y,
			plates.size(), "" if plates.size() == 1 else "s",
			", ".join(PackedStringArray(plates.map(func(p: Array) -> String: return str(p[0]))))],
			known and is_equal_approx(covered, wanted.x * wanted.y)
			and is_equal_approx(box.size.x, wanted.x) and is_equal_approx(box.size.z, wanted.y))
	_check("the three sizes the menu names are one baseplate each: %s" % str(ModelFloor.SIZES.map(
		func(n: int) -> String: return str(ModelFloor.make(ModelFloor.BASEPLATE, n, n).plates()[0][0]))),
		ModelFloor.SIZES.all(func(n: int) -> bool:
			return ModelFloor.make(ModelFloor.BASEPLATE, n, n).plates().size() == 1))
	_check("a meta line other programs ignore: %s" % ModelFloor.make("baseplate", 32, 32, 19).to_meta(),
		ModelFloor.make("baseplate", 32, 32, 19).to_meta() == "0 !BRICKWORKS FLOOR BASEPLATE 32 32 19")
	_check("...read back the same", ModelFloor.read("0 Model\n0 !BRICKWORKS FLOOR GRID\n").kind
		== ModelFloor.GRID and ModelFloor.read("0 !BRICKWORKS FLOOR BASEPLATE 24 40 378") \
		.same_as(ModelFloor.make("baseplate", 24, 40, 378)))
	_check("...and a line that says nothing sensible leaves the floor unsaid",
		ModelFloor.read("0 !BRICKWORKS FLOOR LAVA\n") == null and ModelFloor.read("0 Model\n") == null)


## Each floor chosen, saved and reopened: the same floor, laid the same.
## Switching is one step of the history and never moves the model.
func _each_floor_round_trip() -> void:
	print("  each floor saved and read back")
	_main.call("clear_model")
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3003", 1, Vector3(60, 24, 20))
	_main.call("_lay_baseplate")
	await _frames(3)
	var before: Array = _model_places()
	for chosen: ModelFloor in [ModelFloor.make("baseplate", 16, 16, 19),
			ModelFloor.make("baseplate", 48, 48, 72), ModelFloor.make("baseplate", 40, 24, 378),
			ModelFloor.make("grid"), ModelFloor.make("none"), ModelFloor.make("baseplate", 32, 32, 288)]:
		var depth: int = _builder.history_depth()
		_main.call("choose_floor", chosen)
		await _frames(2)
		_check("%s: one step of the history (%d -> %d)" % [chosen.words(), depth,
			_builder.history_depth()], _builder.history_depth() == depth + 1)
		_check("...nothing built moved", _model_places() == before)
		_check("...%s" % _laid_words(chosen), _laid_as(chosen))
		var text: String = _store.to_text("Floors", true)
		_check("...saved as %s" % chosen.to_meta(), text.contains(chosen.to_meta() + "\n"))
		var opened: Dictionary = _store.open_text(text, "floors.ldr")
		_main.call("_lay_baseplate")
		await _frames(2)
		_check("...and reopened on the same floor (%s), %d parts" % [
			_store.model_floor.words(), int(opened["placed"])],
			_store.model_floor.same_as(chosen) and int(opened["placed"]) == 2)
		_check("...laid the same", _laid_as(chosen))
		_check("...the model where it was", _model_places() == before)
		before = _model_places()
	# Undo goes back a floor; redo comes forward again.
	_main.call("choose_floor", ModelFloor.make("none"))
	await _frames(2)
	await _key(KEY_Z, true)
	_check("Ctrl-Z puts the baseplate back (%s, %d plates)" % [_store.model_floor.words(),
		_store.scenery.size()], _store.model_floor.is_plate() and _store.scenery.size() == 1)
	await _key(KEY_Z, true, true)
	_check("...and Ctrl-Shift-Z takes it away again (%s)" % _store.model_floor.words(),
		_store.model_floor.kind == ModelFloor.NONE and _store.scenery.is_empty())
	# A file from elsewhere says nothing, and gets the floor new models get.
	var plain: String = "0 Plain\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	_store.open_text(plain, "plain.ldr")
	_check("a file that says nothing stands on the floor new models start on (%s)"
		% _store.model_floor.words(), _store.model_floor.same_as(ModelFloor.preferred()))


## The first part on a grid floor and on none lands where it would on a
## baseplate, on the same studs; the next stacks on it; it stands up.
func _placing_on_each_floor() -> void:
	print("  placing on each floor, by a click")
	var landed: Dictionary = {}
	for kind: String in [ModelFloor.BASEPLATE, ModelFloor.GRID, ModelFloor.NONE]:
		_main.call("clear_model")
		_main.call("choose_floor", ModelFloor.make(kind))
		# A part in hand first: it brings the parts bin out, and the view
		# slides over to stay in the middle of what is left of the window.
		_main.call("_on_part_chosen", "3001")
		_camera.frame(AABB(Vector3(-200, 0, -200), Vector3(400, 60, 400)))
		await _settled()
		var spot: Vector2 = _screen(Vector3(30, 0, 50))
		await _move(spot)
		await _move(spot + Vector2(1, 0))
		_check("%s: the ghost is shown and may go down" % kind, _builder.can_place())
		await _click(spot + Vector2(1, 0))
		var mine: Array = _model()
		_check("...a click puts a brick down (%d)" % mine.size(), mine.size() == 1)
		if mine.is_empty():
			continue
		var at: Vector3 = (mine[0] as BrickWorld.Brick).transform.origin
		landed[kind] = at
		# A 2 x 4 is even both ways, so its middle is between studs: on a
		# whole stud pitch along both.
		_check("...on the ground, on the studs: %s" % str(at), is_equal_approx(at.y, 24.0)
			and is_zero_approx(fposmod(at.x, BrickLattice.STUD))
			and is_zero_approx(fposmod(at.z, BrickLattice.STUD)))
		# A second on top of the first: it stacks, rather than falling to
		# the ground through it.
		var top: Vector2 = _screen(at + Vector3(0, 0.5, 0))
		await _move(top)
		await _click(top + Vector2(1, 0))
		mine = _model()
		var heights: Array = mine.map(func(b: BrickWorld.Brick) -> float: return b.transform.origin.y)
		heights.sort()
		_check("...and the next stacks on it (%s)" % str(heights), heights == [24.0, 48.0])
		_main.set("_stability_at", 0)
		_main.set("_stability_revision", -1)
		_main.call("_weigh")
		await _frames(5)
		# Weighed on a worker (Main._weigh): its answer a few frames on.
		for _n: int in 600:
			if not bool(_main.get("_weighing")):
				break
			await process_frame
		var stands: String = str(_main.get("_stability_text"))
		_check("...and it stands up against the ground (%s)" % stands, stands.begins_with("stands up"))
		await _shot("placed_" + kind)
		if kind != ModelFloor.BASEPLATE:
			await _shadow_falls(kind)
		_builder.clear_selection()
		(_main.get("_verbs") as EditVerbs).set_mode("select")
	_check("the same click lands on the same studs on all three (%s)" % str(landed.values()),
		landed.size() == 3 and landed[ModelFloor.GRID] == landed[ModelFloor.BASEPLATE]
		and landed[ModelFloor.NONE] == landed[ModelFloor.BASEPLATE])
	# The stud grid, a box and the fit with no baseplate.
	var shell: Shell = _main.get("_shell")
	shell.set_grid(true)
	await _frames(3)
	var lines: ImmediateMesh = shell.grid.mesh as ImmediateMesh
	_check("with no floor, the stud grid is drawn over the ground round the model",
		lines != null and lines.get_surface_count() > 0 and shell.grid.get_aabb().size.x
		>= FloorLayer.LEAST_GROUND * BrickLattice.STUD - 1.0)
	shell.set_grid(false)
	var bounds: AABB = _main.call("_built_bounds")
	_check("Fit frames the model, not the ground (%s)" % str(bounds.size),
		bounds.size.x < 100.0 and bounds.size.y > 40.0)
	var verbs: EditVerbs = _main.get("_verbs")
	verbs.set_mode("select")
	# From the empty ground above and left of the two to below and right
	# of them, round everything they cover on the screen.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for n: int in 8:
		var point: Vector3 = bounds.position + bounds.size * Vector3(n & 1, (n >> 1) & 1, (n >> 2) & 1)
		var seen: Vector2 = _screen(point)
		low = Vector2(minf(low.x, seen.x), minf(low.y, seen.y))
		high = Vector2(maxf(high.x, seen.x), maxf(high.y, seen.y))
	await _drag(low - Vector2(50, 50), high + Vector2(50, 50), true)
	_check("a box drawn over empty ground takes both parts (%d)" % _builder.selection.size(),
		_builder.selection.size() == 2)
	_builder.clear_selection()
	var cut: SeeInside = shell.see_inside
	cut.set_cut(true)
	await _frames(5)
	_check("the cut-away opens with no baseplate", cut.cutting)
	cut.set_cut(false)
	await _frames(3)


## The baseplate made part of the model: counted, saved, step 1 of the
## booklet; and made the floor again, nothing moving either way.
func _part_of_the_model() -> void:
	print("  the baseplate as part of the model")
	_main.call("clear_model")
	_main.call("choose_floor", ModelFloor.make("baseplate", 32, 32, 10))
	_put("3001", 4, Vector3(-60, 24, 20))
	_put("3001", 1, Vector3(60, 24, 20))
	_put("3003", 14, Vector3(0, 48, 20))
	_main.call("_lay_baseplate")
	await _frames(3)
	var before: Array = _all_places()
	var pieces: int = Inventory.pieces_in(_world, _library, _store.scenery)
	_check("three parts, the plate not counted (%d)" % pieces, pieces == 3)
	var depth: int = _builder.history_depth()
	_main.call("floor_part_of_model", true)
	await _frames(2)
	_check("made part of the model in one step (%d -> %d)" % [depth, _builder.history_depth()],
		_builder.history_depth() == depth + 1)
	_check("...nothing moved", _all_places() == before)
	_check("...no plate is scenery now, and the model has its own",
		_store.scenery.is_empty() and _floor.has_own_plate())
	pieces = Inventory.pieces_in(_world, _library, _store.scenery)
	_check("...counted: %d pieces" % pieces, pieces == 4)
	_check("...and the status bar says so at once (%s)" % _main.get("_counts_base"),
		str(_main.get("_counts_base")) == "4 bricks")
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	var listed: bool = false
	for lot: Inventory.Lot in stock.lots:
		listed = listed or (lot.part_id == "3811" and lot.color_code == 10 and lot.count == 1)
	_check("...in the parts list and the shop lists: one Baseplate 32 x 32 in Bright Green",
		listed)
	var text: String = _store.to_text("On a plate", true)
	_check("...saved with the model (%d parts in the file)" % ModelStore.count_in(text),
		ModelStore.count_in(text) == 4 and text.contains("3811.dat"))
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery)
	var plate_id: int = _floor.own_plates()[0] if _floor.has_own_plate() else 0
	_check("...and the booklet's step 1 is laying it (%s)" % (str(steps[0].brick_ids) if not steps.is_empty() else "no steps"),
		not steps.is_empty() and steps[0].brick_ids.has(plate_id))
	# Reopened, it is the model's own plate and gets none laid under it.
	var opened: Dictionary = _store.open_text(text, "on a plate.ldr")
	_main.call("_lay_baseplate")
	await _frames(2)
	_check("reopened: %d parts, its own plate, none laid under it" % int(opened["placed"]),
		int(opened["placed"]) == 4 and _floor.has_own_plate() and _store.scenery.is_empty())
	_check("...and nothing came up off the ground", _all_places() == before)
	# And back again: the floor, a Bright Green 32 x 32, nothing moving.
	depth = _builder.history_depth()
	_main.call("floor_part_of_model", false)
	await _frames(2)
	_check("...the status bar back to 3 (%s)" % _main.get("_counts_base"),
		str(_main.get("_counts_base")) == "3 bricks")
	_check("made the floor again in one step: %s, %d pieces" % [_store.model_floor.words(),
		Inventory.pieces_in(_world, _library, _store.scenery)],
		_builder.history_depth() == depth + 1 and _store.scenery.size() == 1
		and _store.model_floor.same_as(ModelFloor.make("baseplate", 32, 32, 10))
		and Inventory.pieces_in(_world, _library, _store.scenery) == 3)
	_check("...nothing moved", _all_places() == before)
	await _key(KEY_Z, true)
	_check("Ctrl-Z makes it part of the model again (%d pieces)"
		% Inventory.pieces_in(_world, _library, _store.scenery),
		_floor.has_own_plate() and Inventory.pieces_in(_world, _library, _store.scenery) == 4)
	# Taken off by hand, the floor's plate comes back under the model;
	# put back by Undo, it goes again — never two.
	var own: int = _floor.own_plates()[0]
	_builder.clear_selection()
	_builder.selection[own] = true
	_builder.selection_changed.emit(1)
	await _key(KEY_DELETE)
	_check("its own plate deleted, the floor's is laid in its place (%d scenery)"
		% _store.scenery.size(), not _floor.has_own_plate() and _store.scenery.size() == 1)
	await _key(KEY_Z, true)
	_check("...and undone, there is one plate again, the model's (%d scenery, own %s)"
		% [_store.scenery.size(), _floor.has_own_plate()],
		_floor.has_own_plate() and _store.scenery.is_empty())
	# Made part of a model on no floor: a plate of the size and colour it
	# last had is laid and taken in, as one step.
	_main.call("floor_part_of_model", false)
	var none: ModelFloor = _store.model_floor.copy()
	none.kind = ModelFloor.NONE
	_main.call("choose_floor", none)
	await _frames(2)
	_check("on no floor, there is no plate (%d)" % _store.scenery.size(),
		_store.scenery.is_empty() and not _floor.has_own_plate())
	depth = _builder.history_depth()
	_main.call("floor_part_of_model", true)
	await _frames(2)
	var laid: BrickWorld.Brick = _world.get_brick(_floor.own_plates()[0]) \
		if _floor.has_own_plate() else null
	_check("...and made part of the model, a Bright Green plate is laid and taken in, one step "
		+ "(%s, colour %d, %d scenery, history %d -> %d)" % [laid.part_id if laid != null else "none",
		laid.color_code if laid != null else -1, _store.scenery.size(), depth,
		_builder.history_depth()], laid != null and _store.scenery.is_empty()
		and laid.color_code == 10 and _builder.history_depth() == depth + 1)
	await _key(KEY_Z, true)
	_check("...undone, no floor again (%s, %d scenery)" % [_store.model_floor.words(),
		_store.scenery.size()], _store.model_floor.kind == ModelFloor.NONE
		and not _floor.has_own_plate() and _store.scenery.is_empty())
	await _key(KEY_Z, true, true)
	_check("...and redone, the plate is the model's again",
		_floor.has_own_plate() and _store.scenery.is_empty())


## A file made elsewhere with a baseplate in it: no scenery plate is laid
## under it, and it is not lifted off the ground by its plate's thickness.
func _a_file_with_its_own_plate() -> void:
	print("  a file with its own baseplate")
	var text: String = ("0 Diorama\n0 Name: diorama.ldr\n0 Author: somebody\n\n"
		+ "1 2 0 0 0 1 0 0 0 1 0 0 0 1 3811.dat\n"
		+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	var opened: Dictionary = _store.open_text(text, "diorama.ldr")
	_main.call("_lay_baseplate")
	await _frames(2)
	var heights: Array = _model().map(func(b: BrickWorld.Brick) -> float: return b.transform.origin.y)
	heights.sort()
	_check("%d parts, its own plate at the ground and the brick on it (%s)"
		% [int(opened["placed"]), str(heights)], heights == [0.0, 24.0])
	_check("...and no second plate laid under it", _store.scenery.is_empty()
		and _floor.has_own_plate())


## The designer says what a model stands on (submit_design's floor), the
## way a session over MCP builds: a kart on no floor; a garden on a green
## baseplate sized to it, part of the build. Nothing spent: the tool's own
## implementation, called as the command socket calls it.
func _the_designer_chooses() -> void:
	print("  the designer chooses the floor")
	var assistant: Assistant = _main.get("_assistant")
	_main.call("clear_model")
	var kart: Variant = await assistant.use_tool("submit_design", {
		"name": "Kart", "description": "a kart, on no floor: a vehicle is picked up",
		"floor": "none",
		"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 4, "x": 0, "y": 3, "z": 0, "rot": 0}],
		"assemblies": []})
	await _frames(5)
	_check("a kart submitted with floor none stands on no floor (%s; %s)" % [
		_store.model_floor.words(), str(kart).substr(0, 60)],
		_store.model_floor.kind == ModelFloor.NONE and _store.scenery.is_empty()
		and _model().size() == 2)
	_main.call("clear_model")
	var garden: Variant = await assistant.use_tool("submit_design", {
		"name": "Garden", "description": "a garden on a green baseplate, part of the build",
		"floor": "baseplate", "floor_colour": "Bright Green",
		"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0},
			{"part": "3001", "color": 1, "x": 4, "y": 0, "z": 0, "rot": 0}],
		"assemblies": []})
	await _frames(5)
	var plate: BrickWorld.Brick = _world.get_brick(_floor.own_plates()[0]) \
		if _floor.has_own_plate() else null
	# Eight studs by two, with a stud to spare all round: 16 x 8, in eights
	# each way, and not rounded up to a square of empty field.
	_check("a garden with floor baseplate gets a Bright Green 16 x 8 as part of it (%s; %s)" % [
		plate.part_id if plate != null else "none", str(garden).substr(0, 60)],
		plate != null and plate.part_id == "3865" and plate.color_code == 10
		and _store.scenery.is_empty())
	_check("...counted with the garden (%d pieces)" % Inventory.pieces_in(_world, _library,
		_store.scenery), Inventory.pieces_in(_world, _library, _store.scenery) == 3)
	_check("...and the person can take it back with one undo",
		await _undo_until_scenery())


func _undo_until_scenery() -> bool:
	await _key(KEY_Z, true)
	return not _floor.has_own_plate() and _store.scenery.size() == 1


## Pictures are of the model: a render, Export picture, the share card and
## the Studio thumbnail show a baseplate only when it is part of the model,
## as Studio's and LEGO's own pictures do, and otherwise the studio's clean
## floor. A car on the default floor is a car, not a car parked on a lawn.
## The view keeps the floor as chosen. Drawn for the example car three ways.
func _pictures() -> void:
	print("  pictures")
	var studio: StudioRender = null
	for case: String in ["default floor", "plate in the model", "no floor"]:
		_store.open("res://models/car.ldr")
		_store.model_floor = ModelFloor.make(ModelFloor.BASEPLATE)
		_main.call("_lay_baseplate")
		if case == "plate in the model":
			_main.call("floor_part_of_model", true)
		elif case == "no floor":
			_main.call("choose_floor", ModelFloor.make(ModelFloor.NONE))
		var name: String = case.replace(" ", "_")
		_camera.frame(_main.call("_built_bounds"))
		await _frames(20)
		await _shot("view_" + name)
		var seen: float = _greenish(root.get_texture().get_image())
		_check("%s: the view shows the floor as chosen (%.1f%% green)" % [case, seen * 100.0],
			(seen > 0.05) == (case != "no floor"))
		var exports: Exports = _main.get("_exports")
		var image: Image = await exports.picture.take(Vector2i(600, 400))
		if image == null:
			_check("%s: a picture was taken" % case, false)
			continue
		image.save_png(ProjectSettings.globalize_path("res://shots/floor/picture_%s.png" % name))
		print("    picture: shots/floor/picture_%s.png" % name)
		var in_picture: float = _greenish(image)
		# And a render, Quick, with the renderer File, Render… uses, set up as
		# it sets it up.
		if studio == null:
			var dialog: RenderDialog = _main.get("_render")
			studio = StudioRender.new()
			studio.library = _library
			studio.scenery = _store.scenery
			studio.eye = _camera
			studio.look = dialog.look
			studio.rig_lights = dialog.rig_lights
			root.add_child(studio)
		var settings := RenderSettings.new()
		settings.quality = RenderSettings.Quality.QUICK
		settings.size = Vector2i(480, 270)
		settings.view = "hero"
		var render: Image = await studio.render(_world, settings)
		if render == null:
			_check("%s: a render was drawn" % case, false)
			continue
		render.save_png(ProjectSettings.globalize_path("res://shots/floor/render_%s.png" % name))
		print("    picture: shots/floor/render_%s.png" % name)
		var in_render: float = _greenish(render)
		if case == "plate in the model":
			_check("...the picture and the render stand it on its plate (%.1f%% and %.1f%% green)"
				% [in_picture * 100.0, in_render * 100.0], in_picture > 0.05 and in_render > 0.05)
		else:
			_check("...the picture and the render are of the car alone (%.1f%% and %.1f%% green)"
				% [in_picture * 100.0, in_render * 100.0], in_picture < 0.005 and in_render < 0.005)


## Settings says what a new model starts on, and New stands on it.
func _settings() -> void:
	print("  the floor for new models")
	var controls: ControlsDialog = _main.get("_controls")
	controls.open()
	await _frames(10)
	_check("Settings offers the floor new models start on (%s)"
		% controls.new_floor._kind.get_item_text(controls.new_floor._kind.selected),
		controls.new_floor.is_visible_in_tree())
	await _shot("settings")
	controls.new_floor._kind.select(5)
	controls.new_floor._kind.item_selected.emit(5)
	_check("...choosing No floor there keeps it for new models (%s)"
		% ModelFloor.preferred().words(), ModelFloor.preferred().kind == ModelFloor.NONE)
	controls.visible = false
	(_main.get("_bar") as ModelBar).started_new.emit()
	await _frames(5)
	_check("...and New stands on it (%s, %d plates)" % [_store.model_floor.words(),
		_store.scenery.size()], _store.model_floor.kind == ModelFloor.NONE
		and _store.scenery.is_empty())
	ModelFloor.prefer(ModelFloor.make(ModelFloor.BASEPLATE))


## With no plate the model still casts a shadow on the ground it stands
## on, and nothing else is drawn there: the same view with what takes the
## shadow taking it and not (the grid's ground, or on no floor the plane
## under the model), compared pixel by pixel away from the parts themselves.
func _shadow_falls(kind: String) -> void:
	_builder.hide_preview()
	var box: AABB = _main.call("_built_bounds")
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for n: int in 8:
		var seen: Vector2 = _screen(box.position + box.size * Vector3(n & 1, (n >> 1) & 1, (n >> 2) & 1))
		low = Vector2(minf(low.x, seen.x), minf(low.y, seen.y))
		high = Vector2(maxf(high.x, seen.x), maxf(high.y, seen.y))
	# The viewport's units into the picture's pixels: the window is drawn
	# scaled (canvas_items), and the picture is the window's.
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var parts := Rect2((low - Vector2(6, 6)) * scale, (high - low + Vector2(12, 12)) * scale)
	var view := Rect2(_camera.seen_rect().position * scale, _camera.seen_rect().size * scale)
	var takes: Callable
	if kind == ModelFloor.GRID:
		var ground: StandardMaterial3D = _floor.get("_ground_material")
		takes = func(on: bool) -> void: ground.disable_receive_shadows = not on
	else:
		var catcher: Node3D = _floor.shadow_node()
		takes = func(on: bool) -> void: catcher.visible = on
	takes.call(false)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var without: Image = root.get_texture().get_image()
	takes.call(true)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var with_shadow: Image = root.get_texture().get_image()
	# The two pictures compared, to look at when the count is wrong.
	for pair: Array in [["without", without], ["with", with_shadow]]:
		var path: String = ProjectSettings.globalize_path("res://shots/floor/shadow_%s_%s.png"
			% [kind, pair[0]])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		(pair[1] as Image).save_png(path)
	print("    pictures: shots/floor/shadow_%s_without.png and _with.png" % kind)
	var darker: int = 0
	var lighter: int = 0
	var x_end: int = mini(int(view.end.x), with_shadow.get_width())
	var y_end: int = mini(int(view.end.y), with_shadow.get_height())
	for y: int in range(maxi(int(view.position.y), 0), y_end, 2):
		for x: int in range(maxi(int(view.position.x), 0), x_end, 2):
			if parts.has_point(Vector2(x, y)):
				continue
			var change: float = without.get_pixel(x, y).get_luminance() \
				- with_shadow.get_pixel(x, y).get_luminance()
			if change > 0.04:
				darker += 1
			elif change < -0.02:
				lighter += 1
	_check("%s: the model's shadow falls on the ground round it (%d samples darker, %d lighter)"
		% [kind, darker, lighter], darker > 100 and lighter < 50)


# -- helpers ------------------------------------------------------------------


## How much of a picture is the dark green of the default baseplate, lit or
## in shadow: greener than it is red or blue by a margin, as nothing in the
## example car is. Its hue moves with the light and the picture's own
## colour handling (0.33 in a picture, 0.37 in the view, 0.40 in LDraw), so
## not a hue.
func _greenish(image: Image) -> float:
	var near: int = 0
	var seen: int = 0
	for y: int in range(0, image.get_height(), 3):
		for x: int in range(0, image.get_width(), 3):
			var c: Color = image.get_pixel(x, y)
			seen += 1
			if c.a > 0.5 and c.g > 0.08 and c.g > c.r * 1.4 and c.g > c.b * 1.15:
				near += 1
	return float(near) / float(maxi(seen, 1))


func _laid_words(chosen: ModelFloor) -> String:
	match chosen.kind:
		ModelFloor.GRID:
			return "a grid on the ground and no plate"
		ModelFloor.NONE:
			return "nothing under it"
	return "%d plate%s in %s" % [chosen.plates().size(), "" if chosen.plates().size() == 1 else "s",
		ModelFloor.colour_name(chosen.colour)]


func _laid_as(chosen: ModelFloor) -> bool:
	var grid: Node3D = _floor.grid_node()
	if not chosen.is_plate():
		return _store.scenery.is_empty() and grid.visible == (chosen.kind == ModelFloor.GRID)
	if grid.visible or _store.scenery.size() != chosen.plates().size():
		return false
	var parts: Array = chosen.plates().map(func(p: Array) -> String: return str(p[0]))
	for brick_id: int in _store.scenery:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null or brick.color_code != chosen.colour or not parts.has(brick.part_id) \
				or not is_zero_approx(brick.transform.origin.y):
			return false
	return true


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _model() -> Array:
	return _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))


## Where every part of the model is, sorted, as text.
func _model_places() -> Array:
	var places: Array = _model().map(func(b: BrickWorld.Brick) -> String:
		return "%s %s" % [b.part_id, str(b.transform.origin)])
	places.sort()
	return places


## And every brick in the world, the floor's plates too.
func _all_places() -> Array:
	var places: Array = _world.bricks().map(func(b: BrickWorld.Brick) -> String:
		return "%s %d %s" % [b.part_id, b.color_code, str(b.transform.origin)])
	places.sort()
	return places


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


## Until the view has stopped moving: a frame glides there over a few
## tenths of a second, and a click aimed while it glides lands elsewhere.
func _settled() -> void:
	var was: Vector2 = Vector2(-1, -1)
	var still: int = 0
	for _n: int in 900:
		await process_frame
		var now: Vector2 = _screen(Vector3(30, 0, 50))
		still = still + 1 if now.distance_to(was) < 0.05 else 0
		was = now
		if still >= 30:
			return


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


func _button(at: Vector2, down: bool, command: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.ctrl_pressed = command
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


## A drag from one point to another, with Ctrl held for a box.
func _drag(from: Vector2, to: Vector2, command: bool) -> void:
	await _move(from)
	_button(from, true, command)
	await _frames(2)
	for n: int in range(1, 9):
		var event := InputEventMouseMotion.new()
		event.position = _as_event(from.lerp(to, n / 8.0))
		event.global_position = event.position
		event.relative = _as_event((to - from) / 8.0)
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await _frames(2)
	_button(to, false, command)
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
	var path: String = ProjectSettings.globalize_path("res://shots/floor/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/floor/%s.png" % name)
