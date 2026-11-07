## Lights in the scene and colours that glow (APP_UX5 #7, lights).
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 \
##       --script src/dev/lights_probe.gd
##
## As a person lights the sample car: File, Render…, Lights in the model's
## Spot, its strength dragged, the Dark light chosen; the model keeps the
## light over every way it is written (saved where it was opened from,
## saved anew, Save as, the autosave, after a step edit) and it is back
## when the model is opened again, where it was over the car; Build
## together's words for it carried whole to another side and back, word for
## word, and words that are no lights changing nothing; a tool that only
## looks writes nothing; nothing changes on a model shared to look at.
## light_model over MCP lists, puts in, changes and takes out, in the file's
## coordinates.
##
## The bar: a spot over the car, drawn without it and with it, rasterised
## (Quick) and path traced (Best, where the card traces rays): every pixel
## whose surface is outside the spot's cone wherever along its ray it can be
## (the car's box and the floor, a pixel and more round it), 0 px changed;
## the lit side, the floor beside the car under it, brighter by a set
## amount ([constant BRIGHTER] of its light, and [constant LEVELS] levels);
## the two drawings' rises the same light within [constant SAME_LIGHT]. A 1 x 1 brick in Trans Neon Green on a
## white plate in the Dark light lights the plate round it ([constant
## GLOW_TIMES] as light as with a 1 x 1 in Trans Green, and green), both ways.
##
##   -- --keep=DIR    leaves the files it saved in DIR, with how many parts each has
##   -- --older=DIR   opens the files left there, to be run by an older
##                    Brickworks, which knows nothing of lights: each opens
##                    whole, and its light lines are as they were
##   -- --no-trace    the path-traced half left out (a second window size)
##   -- --means=FILE  under Forward+ the Dark light's means under the model's
##                    suns written there; under Compatibility (the web's,
##                    on the card through zink as look_probe runs it) read
##                    back and matched, each within 15%
##
## And what an independent review found (lreview, 2026-11-07): lines it
## cannot read carried word for word and said at the open; a sub-model's
## lights and views its own; a value rounded as a file keeps it before it is
## checked; at most four suns; light_model's words of the wrong kind answered
## in words; Render never changing a light it does not show; the designer's
## gate by the call; a file of 200,000 light lines that are no lights opened
## as quickly as one of comments. And on this renderer, the car under 0 to 4
## suns each adding light, and 8 bulbs over a grid of neon and of white
## bricks in the dark raising the floor.
##
## Leaves shots/lights/: Render with the spot, studio and dark; the spot's
## pictures and their maps (green changed inside, red changed outside, grey
## not certain); the glowing brick's pictures; each name ending in the size.
extends SceneTree

const OUT := "res://shots/lights/"
const META := "0 !BRICKWORKS LIGHT "
## The floor the spot lights beside the car: at least this much more light
## on it, and this many more levels of 255.
const BRIGHTER := 0.15
const LEVELS := 10.0
## The rasterised and the path traced rise, each a share of the floor's light
## without the spot: within this of each other.
const SAME_LIGHT := 0.35
## The plate round the glowing brick against one round a brick that does not.
const GLOW_TIMES := 3.0
const SIZE := Vector2i(960, 540)

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _store: ModelStore
var _shell: Node
var _camera: Camera3D
var _library: PartLibrary
var _size: String = ""
var _lights: GDScript
var _tools: AppTools
var _render: StudioRender
## file name -> parts, for --keep.
var _kept: Dictionary = {}
## The cone's map of each shot the spot was drawn from (_cone_map).
var _maps: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 90:
		await process_frame
	var playback: Node = _main.get("_playback")
	if playback != null:
		playback.call("stop")
	_world = _main.get("_world")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	var window := Vector2i(DisplayServer.window_get_size())
	_size = "%dx%d" % [window.x, window.y]
	print("  renderer: %s on %s (%s)" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), _size])

	var older: String = _argument("--older")
	if not older.is_empty():
		await _opened_by_an_older_one(older)
		_finish("lights: an older Brickworks opens each file whole, its light lines as they were")
		return
	if not ResourceLoader.exists("res://src/assembly/scene_lights.gd") \
			or not "scene_lights" in _world:
		_check("Render › Lights in the model places a light the model keeps", false)
		print("\nlights: no light can be placed in the model here")
		quit(1)
		return
	_lights = load("res://src/assembly/scene_lights.gd")
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	await _in_render()
	await _kept_everywhere()
	await _sessions()
	await _review()
	_render = StudioRender.new()
	_render.library = _library
	_render.scenery = _store.scenery
	_render.eye = _camera
	_render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)
	var traced: bool = not OS.get_cmdline_user_args().has("--no-trace") and PathTracer.available()
	if not traced:
		print("  path traced: %s" % ("left out (--no-trace)" if OS.get_cmdline_user_args().has(
			"--no-trace") else "not here: " + PathTracer.why_not()))
	await _spot(traced)
	await _glow(traced)
	await _measures(traced)
	var keep: String = _argument("--keep")
	if not keep.is_empty():
		_leave_in(keep)
	_finish("lights: a spot over the car lights only inside its cone, rasterised%s; a neon "
		% (" and path traced" if traced else "") + "1 x 1 lights the plate round it in the "
		+ "dark; the light kept over every save and back after an open, and over MCP (%s)" % _size)


func _finish(passed: String) -> void:
	print("")
	if _failures == 0:
		print(passed)
	else:
		print("lights: %d FAILED (%s)" % [_failures, _size])
	quit(1 if _failures > 0 else 0)


# -- Render's Lights in the model, as a person uses it ---------------------------


func _in_render() -> void:
	print("  Render, Lights in the model: a spot over the car (%s)" % _size)
	var placed: int = int(_main.call("_open", "res://models/car.ldr"))
	await _settled()
	_check("the sample car opens (%d parts)" % placed, placed > 50 and _parts() == placed)
	_check("it keeps no lights of its own", _scene().is_empty())
	_shell.call("run", "render")
	await _frames(6)
	var dialog: Node = _main.get("_render")
	var controls: Dictionary = dialog.call("controls_by_name")
	var add: Button = controls.get("render_lamp_add_spot")
	_check("Render has Lights in the model, with Add Spot, Bulb, Sun and Light panel",
		add != null and controls.get("render_lamp_add_point") != null
		and controls.get("render_lamp_add_directional") != null
		and controls.get("render_lamp_add_area") != null)
	if add == null:
		return
	await _drafted(dialog)
	await _shoot("render_none")
	add.pressed.emit()
	await _frames(3)
	var lights: Array = _scene()
	var box: AABB = _world.model_bounds()
	var light: Dictionary = lights[0] if lights.size() == 1 else {}
	var at: Vector3 = _at(light) if not light.is_empty() else Vector3.ZERO
	_check("Spot puts one spot over the car, shining down: at %s, the model's middle %s, its "
		% [at, box.get_center()] + "top %.0f" % box.end.y, lights.size() == 1
		and str(light.get("kind", "")) == "spot"
		and Vector2(at.x, at.z).distance_to(Vector2(box.get_center().x, box.get_center().z)) < 1.0
		and at.y > box.end.y + 50.0 and _aim(light).dot(Vector3.DOWN) > 0.999)
	var cone: float = float(light.get("cone", 0.0))
	_check("its cone just takes the car in: %.0f°" % cone, cone >= 15.0 and cone <= 90.0)
	var which: OptionButton = controls.get("render_lamp")
	_check("Which lists it: %s" % (which.get_item_text(0) if which != null and which.item_count > 0
		else "nothing"), which != null and which.item_count == 1
		and which.get_item_text(0) == "1. %s" % tr("Spot"))
	var strength: HSlider = controls.get("render_lamp_strength")
	strength.value = 2.5
	await _frames(2)
	_check("Strength dragged to 2.5: the light's %s" % _scene()[0].get("strength"),
		absf(float(_scene()[0].get("strength", 0.0)) - 2.5) < 0.01)
	_check("the change is work not saved", _store.has_unsaved_work())
	# The Dark light, as Light's list chooses it.
	var listed: OptionButton = controls.get("render_light")
	var dark: int = -1
	for n: int in listed.item_count:
		if str(listed.get_item_metadata(n)) == "dark":
			dark = n
	_check("Light offers Dark: “%s”" % (listed.get_item_text(dark) if dark >= 0 else ""), dark >= 0)
	if dark >= 0:
		listed.select(dark)
		listed.item_selected.emit(dark)
		await _drafted(dialog)
		_check("Render draws in the Dark light", str(dialog.get("settings").get("lighting")) == "dark")
		await _shoot("render_dark")
		listed.select(0)
		listed.item_selected.emit(0)
	await _drafted(dialog)
	await _shoot("render_studio")
	(controls["render_close"] as Button).pressed.emit()
	await _frames(3)


## Until the draft asked for is drawn and shown: Render asks for it a moment
## after a choice (RenderDialog._ask_preview) and draws it when nothing else
## is drawing. (Waiting until the renderer was idle, at 1280 x 720 the shot
## came before the draft was begun, and showed the one before.)
func _drafted(dialog: Node) -> void:
	for _n: int in 1800:
		await process_frame
		if int(dialog.get("_preview_due")) < 0 and str(dialog.get("_working")).is_empty():
			break
	await _frames(10)


# -- kept with the model: every way it is written -------------------------------


func _kept_everywhere() -> void:
	print("  the light kept over every save, and back after an open")
	var middle: Vector3 = _world.model_bounds().get_center()
	var wanted: Array = _in_file()
	var offset: Vector3 = _at(_scene()[0]) - middle
	# Saved where it was opened from: the car's own file written back.
	var path: String = ModelStore.SAVE_DIR + "lights_car.ldr"
	var saved: bool = bool(_main.call("save_model", path))
	_check("saved: %s" % _said_lines(path), saved and _same(_read(path), wanted))
	_check("saved, nothing is left unsaved", not _store.has_unsaved_work())
	# The autosave. A probe's store keeps none unless it asks (main), in
	# its own data folder.
	_scene_set([_lights.call("typed", _with(_scene()[0], {"colour": "#ffd27f"}))])
	_store.keeps = true
	_store.touch()
	wanted = _in_file()
	var auto: String = str(_store.call("write_now"))
	_store.keeps = false
	_check("the autosave: %s" % _said_lines(auto), not auto.is_empty()
		and _same(_read(auto), wanted))
	# A step edit, and saved again.
	var first: int = -1
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			first = brick.id
			break
	var stepped: String = str(await _tools.run("edit_steps", {"op": "next", "bricks": [first]}))
	await _frames(3)
	saved = bool(_main.call("save_model", path))
	_check("a step edit (%s), saved again: %s" % [stepped.left(60), _said_lines(path)],
		saved and _same(_read(path), wanted))
	_kept["lights_car.ldr"] = _parts()
	# Closed, and opened again.
	_main.call("clear_model")
	await _settled()
	_check("closed: nothing on the baseplate, no lights", _parts() == 0 and _scene().is_empty())
	_main.call("_open", path)
	await _settled()
	var back: Array = _scene()
	var moved: Vector3 = (_at(back[0]) - _world.model_bounds().get_center()) if back.size() == 1 \
		else Vector3.INF
	_check("opened again: %d parts, %d light, %.3f LDU from where it was over the car" % [_parts(),
		back.size(), moved.distance_to(offset)], _parts() == int(_kept["lights_car.ldr"])
		and back.size() == 1 and moved.distance_to(offset) < 0.01 and _same(_in_file(), wanted))
	_check("opened, nothing is left unsaved", not _store.has_unsaved_work())

	# A tool that only looks writes nothing.
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for tool: Array in [["light_model", {}], ["look_at_model", {}], ["in_view", {}]]:
		await _main.get("_assistant").use_tool(str(tool[0]), tool[1] as Dictionary)
	await _frames(200)
	_check("light_model, look_at_model and in_view change nothing: the file as it was, "
		+ "nothing unsaved", FileAccess.get_file_as_bytes(path) == before
		and not _store.has_unsaved_work())

	# A model made here, written whole rather than into a file it came from.
	_main.call("clear_model")
	await _settled()
	for n: int in 3:
		_world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(n * 80.0, 24.0, 0.0)))
	_store.touch()
	await _frames(3)
	var put: String = str(await _tools.run("light_model", {"op": "add", "kind": "point"}))
	_check("light_model puts a bulb in a model made here: %s" % put.get_slice("\n", 0),
		_scene().size() == 1 and str(_scene()[0]["kind"]) == "point")
	wanted = _in_file()
	var made: String = ModelStore.SAVE_DIR + "lights_made.ldr"
	saved = bool(_main.call("save_model", made))
	_check("saved: %s" % _said_lines(made), saved and _same(_read(made), wanted))
	var named: String = "lights save as"
	var as_saved: bool = bool(_store.call("save_as", named))
	var as_path: String = str(_store.call("saved_path", named))
	_check("Save as: %s" % _said_lines(as_path), as_saved and _same(_read(as_path), wanted))
	_kept["lights_made.ldr"] = _parts()
	_main.call("clear_model")
	await _settled()
	_main.call("_open", made)
	await _settled()
	_check("opened again: %d parts, its bulb where it was" % _parts(), _parts() == 3
		and _same(_in_file(), wanted))

	# Build together: this side's words for the lights, put on another side.
	var together: Node = _main.get("_together")
	if together == null:
		_check("Build together is there to carry them", false)
		return
	var words: String = str((together.call("_meta_now") as Dictionary).get("~lights", ""))
	_scene_set([])
	together.call("_put_meta", "~lights", words)
	var again: String = str((together.call("_meta_now") as Dictionary).get("~lights", ""))
	_check("Build together carries them whole, word for word back (%d characters)" % words.length(),
		not words.is_empty() and _same(_in_file(), wanted) and again == words)
	together.call("_put_meta", "~lights", "{\"kind\": \"spot\"}")
	together.call("_put_meta", "~lights", "[{\"kind\": \"laser\", \"at\": [0, 0, 0]}]")
	_check("words that are no lights: a list of none leaves none, no list changes nothing",
		_scene().is_empty())
	together.call("_put_meta", "~lights", words)
	together.call("_put_meta", "~lights", "not a list")
	_check("...and words that are no list leave the lights as they were", _same(_in_file(), wanted))


# -- over MCP -----------------------------------------------------------------------


func _sessions() -> void:
	print("  light_model over MCP")
	var listed: String = str(await _tools.run("light_model", {}))
	_check("with no op it lists them: %s" % listed.get_slice("\n", 1).left(110),
		listed.contains("1. bulb (point)"))
	var ids: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and ids.size() < 1:
			ids.append(brick.id)
	var said: String = str(await _tools.run("light_model", {"op": "add", "kind": "spot",
		"over": ids, "colour": "#80c0ff"}))
	var lights: Array = _in_file()
	var box: AABB = _main.call("_box_of", _world.get_brick(int(ids[0])))
	var spot_at: Vector3 = _at(_scene()[1]) if _scene().size() == 2 else Vector3.ZERO
	_check("op add, a spot over part %d: %s" % [int(ids[0]), said.get_slice("\n", 0)],
		lights.size() == 2 and str(lights[1]["kind"]) == "spot" and str(lights[1]["colour"]) == "#80c0ff"
		and Vector2(spot_at.x, spot_at.z).distance_to(Vector2(box.get_center().x,
			box.get_center().z)) < 1.0 and spot_at.y > box.end.y)
	said = str(await _tools.run("light_model", {"op": "change", "number": 2, "strength": 3,
		"at": [0, -400, 0], "aim": [0, 1, 0], "cone": 30}))
	lights = _in_file()
	_check("op change: strength 3 at [0, -400, 0] in the file's coordinates, shining down: %s"
		% str(lights[1] if lights.size() > 1 else {}), lights.size() == 2
		and is_equal_approx(float(lights[1]["strength"]), 3.0)
		and _at(lights[1]).distance_to(Vector3(0, -400, 0)) < 0.01
		and _aim(lights[1]).distance_to(Vector3(0, 1, 0)) < 0.0001
		and _aim(_scene()[1]).dot(Vector3.DOWN) > 0.9999)
	var wrong: String = str(await _tools.run("light_model", {"op": "add", "kind": "laser"}))
	var far: String = str(await _tools.run("light_model", {"op": "remove", "number": 9}))
	var bad: String = str(await _tools.run("light_model", {"op": "change", "number": 1,
		"strength": -2}))
	_check("refused, nothing changed: %s / %s / %s" % [wrong.left(50), far.left(50), bad.left(40)],
		wrong.begins_with("kind is") and far.begins_with("number is") and bad.begins_with("That is no light")
		and _in_file().size() == 2)
	said = str(await _tools.run("light_model", {"op": "remove", "number": 2}))
	_check("op remove takes light 2 out: %s" % said.get_slice("\n", 0), _in_file().size() == 1)
	# A model shared to look at: listed, never changed, here or in Render.
	_shell.set("read_only", true)
	var refused: String = _tools.refusal("light_model", {"op": "add"})
	var looked: String = _tools.refusal("light_model", {})
	_shell.call("run", "render")
	await _frames(6)
	var dialog: Node = _main.get("_render")
	var controls: Dictionary = dialog.call("controls_by_name")
	dialog.call("open")
	await _frames(3)
	_check("on a model shared to look at, op add is refused and the list is not, and Render's "
		+ "lights cannot be changed", not refused.is_empty() and looked.is_empty()
		and (controls["render_lamp_add_spot"] as Button).disabled
		and (controls["render_lamp_remove"] as Button).disabled)
	await _drafted(dialog)
	await _shoot("render_shared")
	_shell.set("read_only", false)
	(controls["render_close"] as Button).pressed.emit()
	await _frames(3)


# -- the bar: a spot over the car -----------------------------------------------------


func _spot(traced: bool) -> void:
	print("  a spot over the car: inside its cone brighter, outside it nothing changed")
	_main.call("clear_model")
	await _settled()
	_main.call("_open", "res://models/car.ldr")
	await _settled()
	(_main.get("_builder") as Builder).hide_preview()
	var box: AABB = _world.model_bounds()
	var spot: Dictionary = _lights.call("made", "spot", box, Vector3(-0.5, -0.6, -0.6))
	print("    the spot: %s" % JSON.stringify(spot))
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = SIZE
	settings.view = "hero"
	# On grey, where a floor lit more can show it: white is drawn near the
	# top of what a picture holds.
	settings.use_backdrop("grey")
	var quick: Array = await _with_and_without(spot, settings, "quick")
	var raster_rise: float = -1.0
	if not quick.is_empty():
		raster_rise = _judged(quick, spot, box, "rasterised (Quick)")
	if not traced:
		return
	var best: RenderSettings = settings.copy()
	best.quality = RenderSettings.Quality.BEST
	best.samples = 64
	best.seed = 1
	best.traced = true
	var both: Array = await _with_and_without(spot, best, "traced")
	if both.is_empty():
		return
	_check("Best is path traced", _render.traced_last())
	var traced_rise: float = _judged(both, spot, box, "path traced (Best, 64 samples)")
	_check("the same light both ways: the floor %.0f%% lighter rasterised, %.0f%% path traced"
		% [raster_rise * 100.0, traced_rise * 100.0], raster_rise > 0.0 and traced_rise > 0.0
		and absf(traced_rise - raster_rise) <= SAME_LIGHT * maxf(raster_rise, traced_rise))


## Drawn without the spot and with it: [without, with, the shot], or [].
func _with_and_without(spot: Dictionary, settings: RenderSettings, named: String) -> Array:
	# Each drawn once first, so neither is the first drawing of its set
	# (what the card builds for a new set of lights is built by then; the
	# tracer's first picture of a set came out a little apart from its
	# second, 573 px in all).
	_scene_set([spot])
	await _render.render(_world, settings)
	_scene_set([])
	var before: Image = await _render.render(_world, settings)
	var without: Image = await _render.render(_world, settings)
	_scene_set([spot])
	var with: Image = await _render.render(_world, settings)
	var shot: StudioRender.Shot = _render.last_shot
	_scene_set([])
	if before == null or without == null or with == null:
		_check("the car is drawn %s" % named, false)
		return []
	without.save_png(OUT + "spot_%s_off_%s.png" % [named, _size])
	with.save_png(OUT + "spot_%s_on_%s.png" % [named, _size])
	# What the renderer changes by itself, drawing the same twice: said, so
	# a pixel changed outside the cone can be told from it. (Rasterised, a
	# shadow's soft edge came out a level apart now and then, 3,250 px of
	# the car's own shadow, 2026-11-06.)
	before.convert(Image.FORMAT_RGB8)
	without.convert(Image.FORMAT_RGB8)
	var own: int = 0
	var a: PackedByteArray = before.get_data()
	var b: PackedByteArray = without.get_data()
	for n: int in a.size() / 3:
		if a[n * 3] != b[n * 3] or a[n * 3 + 1] != b[n * 3 + 1] or a[n * 3 + 2] != b[n * 3 + 2]:
			own += 1
	print("    %s: the same drawn twice without it, %d px apart" % [named, own])
	return [without, with, shot, named]


## The bar's two measures of one drawing; the floor's rise, a share of its light.
func _judged(drawn: Array, spot: Dictionary, box: AABB, words: String) -> float:
	var without: Image = drawn[0]
	var with: Image = drawn[1]
	var shot: StudioRender.Shot = drawn[2]
	without.convert(Image.FORMAT_RGB8)
	with.convert(Image.FORMAT_RGB8)
	var size: Vector2i = with.get_size()
	var key: String = "%s %s %s %s" % [shot.origin, shot.basis, shot.fov, size]
	if not _maps.has(key):
		_maps[key] = _cone_map(shot, size, spot, box.position.y - 1.0, box.end.y + 1.0)
	var where: PackedByteArray = _maps[key]
	var a: PackedByteArray = without.get_data()
	var b: PackedByteArray = with.get_data()
	var outside: int = 0
	var outside_changed: int = 0
	var changed: int = 0
	var unsure: int = 0
	var map := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	for y: int in size.y:
		for x: int in size.x:
			var at: int = (y * size.x + x) * 3
			var differs: bool = a[at] != b[at] or a[at + 1] != b[at + 1] or a[at + 2] != b[at + 2]
			var place: int = where[y * size.x + x]
			var grey: float = (a[at] + a[at + 1] + a[at + 2]) / 765.0 * 0.5
			var shown := Color(grey, grey, grey)
			if place == 0:
				outside += 1
				if differs:
					outside_changed += 1
					shown = Color(1, 0, 0)
			else:
				if place == 2:
					unsure += 1
					shown = Color(grey + 0.25, grey + 0.25, grey + 0.25)
				if differs:
					changed += 1
					shown = Color(0.1, 0.9, 0.2)
			map.set_pixel(x, y, shown)
	map.save_png(OUT + "spot_%s_map_%s.png" % [drawn[3], _size])
	# At least a fifth of the picture surely outside the cone, to judge by.
	_check("%s: outside the cone %d of %d px changed (%.0f%% of the picture; %d px not certain, "
		% [words, outside_changed, outside, 100.0 * outside / float(size.x * size.y), unsure]
		+ "left out)", outside > size.x * size.y / 5 and outside_changed == 0)
	# The lit side: the floor beside the car, inside the cone and out of
	# the car's shadow, seen from the camera's side of the car. (The car's
	# roof is black, and much of its bonnet is under the windscreen.)
	var points: Array[Vector3] = _lit_floor(shot, size, spot, box)
	var off := Color(0, 0, 0)
	var on := Color(0, 0, 0)
	for point: Vector3 in points:
		var at: Vector2 = _project(shot, point, size)
		off += _patch(without, at) / float(points.size())
		on += _patch(with, at) / float(points.size())
	var light_off: float = _linear(off)
	var light_on: float = _linear(on)
	var rise: float = (light_on - light_off) / maxf(light_off, 0.001)
	var levels: float = (on.get_luminance() - off.get_luminance()) * 255.0
	_check("%s: the floor it lights beside the car (%d places) %.0f%% lighter, %.1f levels "
		% [words, points.size(), rise * 100.0, levels] + "(%.0f to %.0f); %d px lit in all" % [
		off.get_luminance() * 255.0, on.get_luminance() * 255.0, changed], points.size() >= 3
		and rise >= BRIGHTER and levels >= LEVELS and changed > 500)
	return rise


## Places on the floor the spot lights that the camera sees: inside the
## inner part of its cone, beyond the car's box on the camera's side (so
## nothing of the car stands between them and the camera) and so far
## beyond it that the line to the spot clears the car's top too (so they
## are not in its shadow); well inside the picture. At most 9, spread out.
func _lit_floor(shot: StudioRender.Shot, size: Vector2i, spot: Dictionary,
		box: AABB) -> Array[Vector3]:
	var apex: Vector3 = _at(spot)
	var low: float = box.position.y
	var reach: float = (apex.y - low) * tan(deg_to_rad(float(spot["cone"]) * 0.5)) * 0.85
	var toward: Vector3 = shot.origin - box.get_center()
	var clear: float = 8.0
	var found: Array[Vector3] = []
	var step: float = 6.0
	var x: float = apex.x - reach
	while x <= apex.x + reach:
		var z: float = apex.z - reach
		while z <= apex.z + reach:
			var point := Vector3(x, low, z)
			z += step
			if Vector2(point.x - apex.x, point.z - apex.z).length() > reach:
				continue
			# Where the line to the spot crosses the car's top.
			var top: Vector3 = apex + (point - apex) * ((apex.y - box.end.y) / (apex.y - low))
			var beyond: bool = false
			for axis: int in [0, 2]:
				var past_end: bool = toward[axis] > 0.0
				var edge: float = (box.end[axis] + clear) if past_end else (box.position[axis] - clear)
				if (point[axis] > edge and top[axis] > edge) if past_end \
						else (point[axis] < edge and top[axis] < edge):
					beyond = true
			if not beyond:
				continue
			var seen: Vector2 = _project(shot, point, size)
			if seen.x < 12.0 or seen.y < 12.0 or seen.x > size.x - 12.0 or seen.y > size.y - 12.0:
				continue
			found.append(point)
		x += step
	# Spread out: every so many of them.
	var picked: Array[Vector3] = []
	var every: int = maxi(found.size() / 9, 1)
	for n: int in range(0, found.size(), every):
		picked.append(found[n])
	return picked


## Each pixel: 1 when whatever it shows is inside [param spot]'s cone, 0 when
## it is outside it wherever on the pixel's ray between heights [param low]
## and [param high] (the floor and the top of the car) it can be, a pixel
## and more round it too; 2 when it cannot be said. Rays that never come
## down that far end on the sweep far off, outside it.
func _cone_map(shot: StudioRender.Shot, size: Vector2i, spot: Dictionary, low: float,
		high: float) -> PackedByteArray:
	var apex: Vector3 = _at(spot)
	var slope: float = tan(deg_to_rad(float(spot["cone"]) * 0.5))
	var tan_half: float = tan(deg_to_rad(shot.fov) * 0.5)
	var aspect: float = float(size.x) / float(size.y)
	# A grid of every other pixel, each judged by its ray.
	var step: int = 2
	var wide: int = size.x / step + 2
	var tall: int = size.y / step + 2
	var coarse := PackedByteArray()
	coarse.resize(wide * tall)
	for gy: int in tall:
		for gx: int in wide:
			var px: float = gx * step + 0.5
			var py: float = gy * step + 0.5
			var local := Vector3((px / size.x * 2.0 - 1.0) * tan_half * aspect,
				(1.0 - py / size.y * 2.0) * tan_half, -1.0)
			var way: Vector3 = (shot.basis * local).normalized()
			coarse[gy * wide + gx] = _ray_place(shot.origin, way, apex, slope, low, high)
	# A pixel is outside only when the grid round it is: the drawings blend a
	# pixel and a half round each.
	var out := PackedByteArray()
	out.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			var gx: int = x / step
			var gy: int = y / step
			var all_out: bool = true
			var all_in: bool = true
			for dy: int in range(-1, 3):
				for dx: int in range(-1, 3):
					var cx: int = clampi(gx + dx, 0, wide - 1)
					var cy: int = clampi(gy + dy, 0, tall - 1)
					var p: int = coarse[cy * wide + cx]
					all_out = all_out and p == 0
					all_in = all_in and p == 1
			out[y * size.x + x] = 0 if all_out else (1 if all_in else 2)
	return out


## 0 outside the cone all along the ray's stretch between the heights, 1
## inside it all along, 2 either. Below the apex and shining straight down,
## how far a point is outside the cone (its distance from the axis less the
## cone's radius at its depth) is convex along a line: its least is found
## by halving, its most is at an end.
static func _ray_place(from: Vector3, way: Vector3, apex: Vector3, slope: float, low: float,
		high: float) -> int:
	if way.y > -0.0001:
		return 0
	var t_top: float = maxf((from.y - high) / -way.y, 0.0)
	var t_floor: float = (from.y - low) / -way.y
	if t_floor <= t_top:
		return 0
	var top: float = _past(from, way, apex, slope, t_top)
	var bottom: float = _past(from, way, apex, slope, t_floor)
	if maxf(top, bottom) < -1.0:
		return 1
	var a: float = t_top
	var b: float = t_floor
	for _n: int in 24:
		var m1: float = a + (b - a) * 0.382
		var m2: float = a + (b - a) * 0.618
		if _past(from, way, apex, slope, m1) < _past(from, way, apex, slope, m2):
			b = m2
		else:
			a = m1
	var least: float = minf(_past(from, way, apex, slope, (a + b) * 0.5), minf(top, bottom))
	return 0 if least > 1.0 else 2


## How far the point [param t] along the ray is outside the cone, in LDU:
## its distance from the axis less the cone's radius at its depth.
static func _past(from: Vector3, way: Vector3, apex: Vector3, slope: float, t: float) -> float:
	var p: Vector3 = from + way * t
	return Vector2(p.x - apex.x, p.z - apex.z).length() - (apex.y - p.y) * slope


# -- the bar: a glowing brick in the dark ---------------------------------------------


func _glow(traced: bool) -> void:
	print("  a 1 x 1 in Trans Neon Green on a white plate, in the Dark light")
	_main.call("clear_model")
	await _settled()
	_scene_set([])
	var plate: String = "3958" if _library.parts.has("3958") else "3036"
	_world.add_brick(plate, 15, Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
	var neon: int = _world.add_brick("3005", 42, Transform3D(Basis.IDENTITY, Vector3(0, 32, 0)))
	for x: float in [-40.0, 40.0]:
		_world.add_brick("3004", 15, Transform3D(Basis.IDENTITY, Vector3(x, 32, -40)))
	await _frames(3)
	var neon_colour: PartLibrary.BrickColor = _library.color(42)
	_check("Trans Neon Green is drawn as a plastic that glows (%s)" % neon_colour.name,
		neon_colour.drawn_as == PartLibrary.BrickColor.Finish.FLUORESCENT)
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = SIZE
	settings.view = "hero"
	settings.lighting = "dark"
	await _glowing(neon, settings, "quick", "rasterised (Quick)")
	if not traced:
		return
	var best: RenderSettings = settings.copy()
	best.quality = RenderSettings.Quality.BEST
	best.samples = 64
	best.seed = 1
	best.traced = true
	await _glowing(neon, best, "traced", "path traced (Best, 64 samples)")


func _glowing(neon: int, settings: RenderSettings, named: String, words: String) -> void:
	_world.recolor_brick(neon, 42)
	await _frames(2)
	var lit: Image = await _render.render(_world, settings)
	var shot: StudioRender.Shot = _render.last_shot
	_world.recolor_brick(neon, 34)
	await _frames(2)
	var plain: Image = await _render.render(_world, settings)
	_world.recolor_brick(neon, 42)
	if lit == null or plain == null:
		_check("the plate is drawn %s" % named, false)
		return
	lit.save_png(OUT + "glow_%s_neon_%s.png" % [named, _size])
	plain.save_png(OUT + "glow_%s_plain_%s.png" % [named, _size])
	# The plate's top round the brick, in front of it and to its sides.
	var glowing := Color(0, 0, 0)
	var dull := Color(0, 0, 0)
	for at: Vector3 in [Vector3(-24, 8, 0), Vector3(24, 8, 0), Vector3(0, 8, 24),
			Vector3(-18, 8, 18), Vector3(18, 8, 18)]:
		var spot: Vector2 = _project(shot, at, lit.get_size())
		glowing += _patch(lit, spot) / 5.0
		dull += _patch(plain, spot) / 5.0
	var times: float = _linear(glowing) / maxf(_linear(dull), 0.0005)
	_check("%s: the plate round the neon brick %.1f times as light as round a Trans Green one "
		% [words, times] + "(%.0f against %.0f levels), green (%s)" % [glowing.get_luminance() * 255.0,
		dull.get_luminance() * 255.0, glowing.to_html(false)], times >= GLOW_TIMES
		and glowing.g > glowing.b + 0.05 and (glowing.get_luminance() - dull.get_luminance()) * 255.0 >= 15.0)
	_check("%s: in the dark, the plate round a brick that does not glow is dark (%.0f levels)"
		% [words, dull.get_luminance() * 255.0], dull.get_luminance() * 255.0 < 40.0)


# -- an older Brickworks --------------------------------------------------------------


func _leave_in(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for file: String in _kept:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR + file),
			folder.path_join(file))
	var out: FileAccess = FileAccess.open(folder.path_join("parts.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(_kept, "\t"))
	out.close()
	print("  left %d files in %s" % [_kept.size(), folder])


func _opened_by_an_older_one(folder: String) -> void:
	print("  opened by this Brickworks")
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		folder.path_join("parts.json")))
	_check("the files a newer one saved are there", listed is Dictionary
		and not (listed as Dictionary).is_empty())
	if not listed is Dictionary:
		return
	for file: String in listed:
		var path: String = folder.path_join(file)
		var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var lines: int = _lines_of(FileAccess.get_file_as_string(path)).size()
		var placed: int = int(_main.call("_open", path))
		await _settled()
		_check("%s (its %d light line) opens whole: %d parts of %d" % [file, lines, _parts(),
			int(listed[file])], lines == 1 and placed == int(listed[file])
			and _parts() == int(listed[file]))
		_check("...and its light line is left alone: the file as it was",
			FileAccess.get_file_as_bytes(path) == before)


# -- reading the app ------------------------------------------------------------------


func _scene() -> Array:
	return _world.get("scene_lights") as Array


func _scene_set(lights: Array) -> void:
	_world.set("scene_lights", lights)


## The model's lights as its file keeps them.
func _in_file() -> Array:
	return _lights.call("in_file", _scene(), _store.lift())


func _read(path: String) -> Array:
	return _lights.call("read", FileAccess.get_file_as_string(path))


func _same(a: Array, b: Array) -> bool:
	return not a.is_empty() and bool(_lights.call("same", a, b))


func _said_lines(path: String) -> String:
	var lines: PackedStringArray = _lines_of(FileAccess.get_file_as_string(path))
	return "%d light line%s in %s" % [lines.size(), "" if lines.size() == 1 else "s",
		path.get_file()]


static func _with(light: Dictionary, changes: Dictionary) -> Dictionary:
	var out: Dictionary = light.duplicate(true)
	out.merge(changes, true)
	return out


static func _at(light: Dictionary) -> Vector3:
	var at: Array = light.get("at", [0, 0, 0])
	return Vector3(float(at[0]), float(at[1]), float(at[2]))


static func _aim(light: Dictionary) -> Vector3:
	var aim: Array = light.get("aim", [0, 0, 0])
	return Vector3(float(aim[0]), float(aim[1]), float(aim[2]))


static func _lines_of(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with(META):
			out.append(line.strip_edges())
	return out


func _parts() -> int:
	return _world.brick_count() - _store.scenery.size()


static func _project(shot: StudioRender.Shot, at: Vector3, size: Vector2i) -> Vector2:
	var local: Vector3 = shot.basis.inverse() * (at - shot.origin)
	if local.z >= -0.001:
		return Vector2(-1, -1)
	var tan_half: float = tan(deg_to_rad(shot.fov) * 0.5)
	var aspect: float = float(size.x) / float(size.y)
	var x: float = local.x / (-local.z * tan_half * aspect)
	var y: float = local.y / (-local.z * tan_half)
	return Vector2((x + 1.0) * 0.5 * size.x, (1.0 - y) * 0.5 * size.y)


## The mean colour of a 7 by 7 patch round [param at].
static func _patch(image: Image, at: Vector2) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count: int = 0
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var x: int = roundi(at.x) + dx
			var y: int = roundi(at.y) + dy
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				sum += image.get_pixel(x, y)
				count += 1
	return sum / maxf(count, 1.0)


## How much light a colour as drawn stands for: its luminance, linear.
static func _linear(colour: Color) -> float:
	return colour.srgb_to_linear().get_luminance()


func _argument(name: String) -> String:
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with(name + "="):
			return given.trim_prefix(name + "=")
	return ""


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settled() -> void:
	for _n: int in 600:
		await process_frame


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var file: String = "%s_%s.png" % [name, _size]
	image.save_png(OUT + file)
	print("    the window: %s" % file)


# -- what an independent review found (lreview, 2026-11-07) ----------------------------
# Each by what a person or a session does and what the file then holds, so the
# same checks run on the build reviewed and fail there.

const VIEW_META := "0 !BRICKWORKS VIEW "
## A file of 200,000 light lines that are no lights opens no slower than the
## same file of comments, by this much.
const JUNK_SLOWER := 1.2


func _review() -> void:
	print("  what the review found")
	await _r_unread()
	await _r_submodel()
	await _r_rounded()
	await _r_suns()
	await _r_types()
	await _r_dialog()
	await _r_gate()
	await _r_junk()


func _put(name: String, text: String) -> String:
	var path: String = ModelStore.SAVE_DIR + name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ModelStore.SAVE_DIR))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


## Opened as a person opens a file, and what the status bar said of it.
func _opened(path: String) -> String:
	_main.call("clear_model")
	await _frames(10)
	_main.call("_open", path)
	var said: String = (_main.get("_bar") as ModelBar).status_text()
	await _frames(120)
	return said


static func _light(kind: String, at: Array, more: Dictionary = {}) -> String:
	var light: Dictionary = {"kind": kind, "at": at, "aim": [0, 1, 0], "colour": "#ffffff",
		"strength": 1, "size": 4, "shadows": true}
	light.merge(more, true)
	return META + JSON.stringify(light)


## Lines this build cannot read are carried, word for word, by a save of
## someone else's file and of the app's own: nine good lights (one past the
## eight a model keeps), one of a kind there is not, one too strong.
func _r_unread() -> void:
	for own: bool in [false, true]:
		var text: String = "0 Many lights\n0 Name: many.ldr\n" + ("0 Author: Brickworks\n"
			if own else "")
		var lines := PackedStringArray()
		for n: int in 9:
			lines.append(_light("point", [n * 10, -100, 0]))
		lines.append(_light("laser", [0, -100, 0]))
		lines.append(_light("point", [0, -100, 0], {"strength": 60}))
		text += "\n".join(lines) + "\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
		var whose: String = "the app's own" if own else "someone else's"
		var said: String = await _opened(_put("unread_%s.ldr" % ("own" if own else "theirs"),
			text))
		var read: int = _scene().size()
		var saved: String = ModelStore.SAVE_DIR + "unread_saved_%s.ldr" % ("own" if own else "theirs")
		_main.call("save_model", saved)
		var after: String = FileAccess.get_file_as_string(saved)
		var carried: bool = true
		for line: String in lines.slice(8):
			carried = carried and line in _lines_of(after)
		_check("%s file of 11 light lines: %d read, %d kept at a save (11), the 3 it cannot read "
			% [whose, read, _lines_of(after).size()] + "word for word: %s" % carried,
			read == 8 and _lines_of(after).size() == 11 and carried)
		_check("...the open says so: %s" % said.get_slice(" — ", 1).left(80),
			said.contains("3 light lines not read, kept in the file as they are")
			and said.contains("a model keeps at most 8 lights") and said.contains("kind there is not"))
		await _opened(saved)
		var again: int = _scene().size()
		_main.call("save_model", saved)
		_check("...opened again, %d read, and saved again %d kept" % [again,
			_lines_of(FileAccess.get_file_as_string(saved)).size()], again == 8
			and _lines_of(FileAccess.get_file_as_string(saved)).size() == 11)


## A sub-model's light and view are its own: not read as the model's, and
## left in it at a save.
func _r_submodel() -> void:
	var view: String = VIEW_META + JSON.stringify({"name": "sub view", "yaw": 10, "pitch": -20,
		"distance": 300, "focus": [0, 0, 0]})
	var main_view: String = VIEW_META + JSON.stringify({"name": "main view", "yaw": 30,
		"pitch": -25, "distance": 400, "focus": [0, 0, 0]})
	var sub_light: String = _light("point", [0, -50, 0], {"colour": "#00ff00"})
	var text: String = "\n".join(PackedStringArray(["0 FILE main.ldr", "0 Main model",
		"0 Name: main.ldr", "0 Author: Someone", _light("spot", [0, -200, 0], {"cone": 30}),
		main_view, "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 16 100 0 0 1 0 0 0 1 0 0 0 1 sub.ldr", "0 STEP", "0 NOFILE", "0 FILE sub.ldr",
		"0 Sub", "0 Name: sub.ldr", sub_light, view, "1 14 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
		"0 NOFILE", ""]))
	await _opened(_put("submodel.mpd", text))
	var lights: int = _scene().size()
	var views: int = (_world.get("saved_views") as Array).size()
	var saved: String = ModelStore.SAVE_DIR + "submodel_saved.mpd"
	_main.call("save_model", saved)
	var after: String = FileAccess.get_file_as_string(saved)
	var sub: String = after.substr(after.find("0 FILE sub.ldr"))
	var main_part: String = after.left(after.find("0 FILE sub.ldr"))
	_check("an MPD's sub-model light and view are its own: the model reads %d light (1) and %d "
		% [lights, views] + "view (1); saved, the sub-model still has both (%s, %s), the main "
		% [sub.contains(sub_light), sub.contains(view)] + "model one light line (%d) and one view "
		% _lines_of(main_part).size() + "line (%d)" % main_part.count(VIEW_META), lights == 1
		and views == 1 and sub.contains(sub_light) and sub.contains(view)
		and _lines_of(main_part).size() == 1 and main_part.count(VIEW_META) == 1)
	await _opened(saved)
	_check("...opened again: %d light, %d view" % [_scene().size(),
		(_world.get("saved_views") as Array).size()], _scene().size() == 1
		and (_world.get("saved_views") as Array).size() == 1)


## A value is rounded as a file keeps it before it is checked: a strength or
## a panel's size that rounds to 0 is refused with why, and the two lights
## saved come back as two.
func _r_rounded() -> void:
	_main.call("clear_model")
	await _frames(10)
	for n: int in 3:
		_world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(n * 80.0, 24.0, 0.0)))
	_store.touch()
	await _frames(3)
	await _tools.run("light_model", {"op": "add", "kind": "spot"})
	var faint: String = str(await _tools.run("light_model", {"op": "change", "number": 1,
		"strength": 0.0004}))
	await _tools.run("light_model", {"op": "add", "kind": "area"})
	var thin: String = str(await _tools.run("light_model", {"op": "change", "number": 2,
		"size": 0.0004}))
	var kept: Array = _in_file()
	_check("strength 0.0004 and a panel 0.0004 across, which a file keeps as 0, are refused with "
		+ "why: %s / %s" % [faint.left(70), thin.left(60)], faint.begins_with("That is no light: its strength")
		and thin.begins_with("That is no light: its size") and kept.size() == 2
		and float(kept[0]["strength"]) > 0.0 and float(kept[1]["size"]) > 0.0)
	var saved: String = ModelStore.SAVE_DIR + "rounded.ldr"
	_main.call("save_model", saved)
	await _opened(saved)
	_check("...two lights saved come back as %d" % _scene().size(), _scene().size() == 2)


## At most four suns: a fifth refused with why, over MCP and in Render, and
## a file's fifth kept in it unread.
func _r_suns() -> void:
	_main.call("clear_model")
	await _frames(10)
	_world.add_brick("3001", 4, Transform3D(Basis.IDENTITY, Vector3(0.0, 24.0, 0.0)))
	_store.touch()
	await _frames(3)
	var said: Array = []
	for n: int in 5:
		said.append(str(await _tools.run("light_model", {"op": "add", "kind": "directional"})))
	var suns: int = _in_file().size()
	_check("over MCP, four suns put in and a fifth refused with why: %s" % str(said[4]).left(110),
		suns == 4 and str(said[4]).contains("at most 4 suns"))
	_shell.call("run", "render")
	await _frames(6)
	var dialog: Node = _main.get("_render")
	var controls: Dictionary = dialog.call("controls_by_name")
	dialog.call("open")
	await _frames(3)
	var sun: Button = controls.get("render_lamp_add_directional")
	var bulb: Button = controls.get("render_lamp_add_point")
	_check("in Render, Sun cannot be added past four, and says why: %s" % sun.tooltip_text.left(70),
		sun.disabled and sun.tooltip_text.contains("at most 4 suns") and not bulb.disabled)
	(controls["render_close"] as Button).pressed.emit()
	await _frames(3)
	var lines := PackedStringArray()
	for n: int in 5:
		lines.append(_light("directional", [0, -100, 0], {"aim": [cos(n), 1, sin(n)]}))
	var path: String = _put("suns.ldr", "0 Five suns\n0 Name: suns.ldr\n" + "\n".join(lines)
		+ "\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	var note: String = await _opened(path)
	var saved: String = ModelStore.SAVE_DIR + "suns_saved.ldr"
	_main.call("save_model", saved)
	_check("a file's five suns: %d read, the fifth kept (%d lines saved), and said: %s" % [
		_scene().size(), _lines_of(FileAccess.get_file_as_string(saved)).size(),
		note.get_slice(" — ", 2).left(40)], _scene().size() == 4
		and _lines_of(FileAccess.get_file_as_string(saved)).size() == 5
		and note.contains("at most 4 suns"))


## Words of the wrong kind over MCP: refused in words, never stopped by an
## error, nothing changed.
func _r_types() -> void:
	_scene_set([])
	await _tools.run("light_model", {"op": "add", "kind": "point"})
	var before: Array = _in_file()
	var said := PackedStringArray()
	var calls: Array = [{"op": "change", "number": [1]}, {"op": "change", "number": {}},
		{"op": "change", "number": null}, {"op": "change", "number": 1.5},
		{"op": "add", "over": [{}]}, {"op": "add", "over": [1e300]}, {"op": "add", "over": [null]},
		{"op": "remove", "number": "x"}]
	for input: Dictionary in calls:
		said.append(str(await _tools.run("light_model", input)))
	var worded: bool = true
	for words: String in said:
		worded = worded and words.length() > 10 and words.contains("nothing changed")
	_check("light_model given numbers of the wrong kind answers each in words: %s" % said[0].left(60)
		+ " / " + said[4].left(60), worded and _same(_in_file(), before))


## Render's Which never changes a light other than the one it shows: the
## lights changed elsewhere, it lists them again first.
func _r_dialog() -> void:
	_scene_set([])
	await _tools.run("light_model", {"op": "add", "kind": "point", "strength": 1})
	await _tools.run("light_model", {"op": "add", "kind": "spot", "strength": 2})
	_shell.call("run", "render")
	await _frames(6)
	var dialog: Node = _main.get("_render")
	dialog.call("open")
	await _frames(3)
	var which: OptionButton = dialog.get("_lamp")
	which.select(0)
	dialog.call("_show_lamp")
	await _frames(2)
	# The first taken out elsewhere while Render shows it (as light_model, an
	# undo or another side of Build together puts the model's lights), and a
	# drag in the same frame, before Render has drawn again.
	_scene_set(_scene().slice(1))
	dialog.call("_change_lamp", {"strength": 7.0})
	var left: Array = _in_file()
	await _frames(4)
	_check("a light taken out elsewhere while Render shows it: a drag at once changes no other "
		+ "light (the one left at strength %s, 2), and Which lists %d" % [
		str(left[0]["strength"]) if not left.is_empty() else "-", which.item_count],
		left.size() == 1 and is_equal_approx(float(left[0]["strength"]), 2.0)
		and which.item_count == 1)
	dialog.call("_change_lamp", {"strength": 3.0})
	_check("...and once listed again, a drag changes the light shown: %s" % str(
		_in_file()[0]["strength"]), is_equal_approx(float(_in_file()[0]["strength"]), 3.0))
	var controls: Dictionary = dialog.call("controls_by_name")
	(controls["render_close"] as Button).pressed.emit()
	await _frames(3)


## The designer at work refuses what changes the model, not what only reads it.
func _r_gate() -> void:
	var assistant: Node = _main.get("_assistant")
	assistant.set("_busy", true)
	var listing: String = _tools.refusal("light_model", {"op": "list"})
	var bare: String = _tools.refusal("light_model", {})
	var adding: String = _tools.refusal("light_model", {"op": "add"})
	assistant.set("_busy", false)
	_check("while the designer builds, light_model's list is let through and its add is not: "
		+ "\"%s\" / \"%s\"" % [listing.left(40), adding.left(40)], listing.is_empty()
		and bare.is_empty() and not adding.is_empty())


## 200,000 light lines that are no lights: opened no slower than 200,000
## comments ([constant JUNK_SLOWER]), and kept.
func _r_junk() -> void:
	var body: String = "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
	var junk := PackedStringArray(["0 Junk"])
	var comments := PackedStringArray(["0 Comments"])
	for n: int in 200000:
		junk.append(META + "x")
		comments.append("0 // x")
	var files: Dictionary = {"junk": _put("junk.ldr", "\n".join(junk) + "\n" + body),
		"comments": _put("comments.ldr", "\n".join(comments) + "\n" + body)}
	var took: Dictionary = {"junk": [], "comments": []}
	for which: String in ["comments", "junk", "junk", "comments", "comments", "junk"]:
		_main.call("clear_model")
		await _frames(10)
		var started: int = Time.get_ticks_msec()
		_main.call("_open", files[which])
		(took[which] as Array).append(Time.get_ticks_msec() - started)
		await _frames(30)
	var junk_ms: float = (took["junk"] as Array).reduce(func(a: float, b: int) -> float:
		return a + b, 0.0) / 3.0
	var comments_ms: float = (took["comments"] as Array).reduce(func(a: float, b: int) -> float:
		return a + b, 0.0) / 3.0
	var saved: String = ModelStore.SAVE_DIR + "junk_saved.ldr"
	_main.call("save_model", saved)
	var kept: int = FileAccess.get_file_as_string(saved).count("\n" + META + "x")
	_check("200,000 light lines that are no lights open in %.0f ms against %.0f ms for 200,000 "
		% [junk_ms, comments_ms] + "comments (%s and %s), %.2f times, at most %.1f; saved, %d kept"
		% [str(took["junk"]), str(took["comments"]), junk_ms / maxf(comments_ms, 1.0),
		JUNK_SLOWER, kept], junk_ms <= comments_ms * JUNK_SLOWER and kept == 200000)
	_main.call("clear_model")
	await _frames(10)


# -- the model's suns and bulbs, on this renderer -----------------------------------------
# lreview's measures: the car under 0 to 4 suns of strength 0.3 from round it,
# the picture's mean, in the studio's light and the Dark light; a grid of 576
# neon bricks, and of white ones, in the dark with and without 8 bulbs round
# it, the floor at its left.


func _measures(traced: bool) -> void:
	var method: String = RenderingServer.get_current_rendering_method()
	print("  the model's suns and bulbs (%s)" % method)
	_main.call("clear_model")
	await _frames(30)
	_main.call("_open", "res://models/car.ldr")
	await _frames(400)
	(_main.get("_builder") as Builder).hide_preview()
	var box: AABB = _world.model_bounds()
	var suns: Array = []
	for n: int in 4:
		var angle: float = TAU * n / 8.0
		var sun: Dictionary = _lights.call("made", "directional", box,
			Vector3(cos(angle), -0.6, sin(angle)))
		sun["strength"] = 0.3
		suns.append(sun)
	var means: Dictionary = {}
	for case: Array in [["studio", RenderSettings.Quality.QUICK], ["dark", RenderSettings.Quality.QUICK],
			["studio good", RenderSettings.Quality.GOOD]]:
		var line: Array = []
		for count: int in 5:
			_scene_set(suns.slice(0, count))
			var settings := _measure_settings(case[1], Vector2i(640, 360))
			settings.lighting = str(case[0]).get_slice(" ", 0)
			await _render.render(_world, settings)
			var image: Image = await _render.render(_world, settings)
			line.append(snappedf(_mean(image, 2), 0.1))
			if count == 4:
				image.save_png(OUT + "suns_%s_4_%s.png" % [str(case[0]).replace(" ", "_"), method])
		means[case[0]] = line
		var each: bool = true
		for n: int in range(1, 5):
			each = each and float(line[n]) > float(line[n - 1]) + 0.5
		_check("%s: the car's mean under 0 to 4 suns %s, each adding light" % [case[0], str(line)],
			each)
	_scene_set([])
	var against: String = _argument("--means")
	if method == "forward_plus" and not against.is_empty():
		var file: FileAccess = FileAccess.open(against, FileAccess.WRITE)
		file.store_string(JSON.stringify(means))
		file.close()
	elif method == "gl_compatibility" and not against.is_empty():
		var forward: Variant = JSON.parse_string(FileAccess.get_file_as_string(against))
		if not forward is Dictionary or not (forward as Dictionary).has("dark"):
			_check("Forward+'s means to match, from %s" % against, false)
		else:
			for count: int in [1, 4]:
				var here: float = float(means["dark"][count])
				var there: float = float(forward["dark"][count])
				_check("Dark, %d sun%s: %.1f here, %.1f under Forward+, %.0f%% apart (15%% at most)"
					% [count, "" if count == 1 else "s", here, there,
					absf(here - there) / there * 100.0], absf(here - there) <= 0.15 * there)
	for colour: int in [42, 15]:
		_main.call("clear_model")
		await _frames(30)
		for x: int in 24:
			for z: int in 24:
				_world.add_brick("3005", colour if colour != 42 else (42 if (x + z) % 2 == 0 else 38),
					Transform3D(Basis.IDENTITY, Vector3(x * 20.0, 24.0, z * 20.0)))
		await _frames(30)
		var grid: AABB = _world.model_bounds()
		var bulbs: Array = []
		for n: int in 8:
			var angle: float = TAU * n / 8.0
			bulbs.append(_lights.call("made", "point", AABB(grid.position + Vector3(cos(angle), 0,
				sin(angle)) * grid.size.x * 0.4, grid.size * 0.5)))
		var floors: Array = []
		for lit: Array in [[], bulbs]:
			_scene_set(lit)
			var settings := _measure_settings(RenderSettings.Quality.QUICK, Vector2i(1280, 720))
			settings.lighting = "dark"
			await _render.render(_world, settings)
			var image: Image = await _render.render(_world, settings)
			var floor_sum: float = 0.0
			for y: int in range(100, 480, 4):
				for x: int in range(0, 300, 4):
					floor_sum += image.get_pixel(x, y).get_luminance()
			floors.append(floor_sum / (75.0 * 95.0) * 255.0)
			image.save_png(OUT + "grid_%s_%s_%s.png" % ["neon" if colour == 42 else "white",
				"bulbs" if not lit.is_empty() else "dark", method])
		_check("%s grid in the dark: 8 bulbs raise the floor at its left from %.1f to %.1f" % [
			"a neon" if colour == 42 else "a white", floors[0], floors[1]],
			float(floors[1]) >= float(floors[0]) + 3.0)
	_scene_set([])


func _measure_settings(quality: int, size: Vector2i) -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = quality
	settings.size = size
	settings.view = "hero"
	settings.seed = 1
	return settings


## A picture's mean luminance, of 255, every [param step]th pixel each way.
static func _mean(image: Image, step: int) -> float:
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			sum += image.get_pixel(x, y).get_luminance()
			count += 1
	return sum / maxf(count, 1.0) * 255.0
