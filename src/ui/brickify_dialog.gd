## Bringing in a 3D model and laying it in LEGO: the model turning in a
## picture, the choices, and what they come to before anything is laid.
##
## The size is the decision that matters, and it is a trade: bigger is a
## better likeness and more bricks. So the panel says what it comes to as
## it is changed — studs across, bricks tall, centimetres — the way the
## mosaic says it, because "32 studs" means nothing until it is "26 cm".
## Then the rest: which way is up (a printer's STL has Z up), hollow or
## solid, smooth or plain, and whose colours.
##
## Brickify works it out on a worker (Brickify.build), so the page keeps
## drawing and the panel keeps saying what it is doing, and what comes back
## goes down as one sub-assembly named after the file: one undo takes it
## back, and it can be moved, turned and edited inside like any other.
class_name BrickifyDialog
extends PanelContainer

## Stud pitch and plate height in millimetres.
const STUD_MM := 8.0
const PLATE_MM := 3.2

var library: PartLibrary
var world: BrickWorld
var builder: Builder
var assemblies: Assemblies
## The baseplate's bricks: never in the way, never counted as the model.
var scenery: Dictionary = {}

## Just before the bricks go down, for the example car to be taken away
## and the model named after the file they came from.
signal placing(name: String)
## Down, selected, with what to say about it.
signal brickified(ids: PackedInt64Array, summary: String)
## Something for the status line: a file that could not be read.
signal said(text: String)

var _mesh: MeshFile
var _picker: MeshFilePicker
var _checker: Assistant
var _busy: bool = false
var _stopped: bool = false
## A model's bounds in its own units, stood up as chosen, and its longest side.
var _box := AABB()
var _longest: float = 1.0

var _title: Label
var _about: Label
var _view: SubViewportContainer
var _port: SubViewport
var _turntable: Node3D
var _shown: MeshInstance3D
var _camera: Camera3D
var _size: HSlider
var _studs: SpinBox
var _scale: SpinBox
var _up: OptionButton
var _detail: Label
var _hollow: CheckBox
var _surface: OptionButton
var _colours: OptionButton
var _one: OptionButton
var _limit: SpinBox
var _status: Label
var _go: Button
var _cancel: Button
var _syncing: bool = false
## What the last one came to, as the status line said it.
var last_summary: String = ""


func _ready() -> void:
	visible = false
	_picker = MeshFilePicker.new()
	add_child(_picker)
	_picker.picked.connect(_on_picked)
	_picker.failed.connect(func(why: String) -> void: said.emit(why))
	_build()


func _exit_tree() -> void:
	if _checker != null:
		_checker.free()
		_checker = null


## Ask for a model: straight from the press that wanted it, since a
## browser opens its file chooser only then.
func ask() -> void:
	if _busy:
		return
	_picker.ask()


func is_busy() -> bool:
	return _busy


## A model a session fetched (AppTools' brickify), read as one the person
## picked: the panel opens on it. Why it could not be read, or "".
func take(bytes: PackedByteArray, file_name: String, extras: Dictionary = {}) -> String:
	if _busy:
		return "a model is being brickified already"
	_mesh = null
	var why: Array = [""]
	var heard := func(text: String) -> void: why[0] = text
	said.connect(heard)
	await _on_picked(bytes, file_name, extras)
	said.disconnect(heard)
	if _mesh == null:
		return str(why[0]) if not str(why[0]).is_empty() else "could not read %s" % file_name
	return ""


## The model the panel holds, or null.
func model() -> MeshFile:
	return _mesh


## What the last Brickify came to, or why it did not go.
func outcome() -> String:
	if not last_summary.is_empty():
		return last_summary
	return "stopped: nothing was laid" if _stopped else _status.text


## Set the panel's choices from a session's (AppTools' brickify), as the
## person would set them, so the panel shows what is laid. Why one of
## them cannot be, or "".
func choose(asked: Dictionary) -> String:
	if asked.has("up"):
		var up: int = Brickify.UPS.find(str(asked["up"]).to_upper())
		if up < 0:
			return "up is one of %s" % ", ".join(Brickify.UPS)
		_up.select(up)
		_on_up_changed()
	if asked.has("studs"):
		var studs: int = int(asked["studs"])
		if studs < Brickify.LEAST_STUDS or studs > Brickify.MOST_STUDS:
			return "studs is %d to %d along its longest side" % [Brickify.LEAST_STUDS,
				Brickify.MOST_STUDS]
		set_studs(studs)
	if asked.has("hollow"):
		_hollow.button_pressed = bool(asked["hollow"])
	if asked.has("smooth"):
		_surface.select(0 if bool(asked["smooth"]) else 1)
	if asked.has("colour"):
		var at: int = _one.get_item_index(int(asked["colour"]))
		if at < 0:
			return "a one-colour model is laid in one of %s" % ", ".join(
				PackedStringArray(Brickify.PALETTE.map(func(code: int) -> String: return str(code))))
		_one.select(at)
		_colours.select(1)
	if asked.has("colours"):
		var kinds: Array = ["model", "one", "limit"]
		if not str(asked["colours"]) in kinds:
			return "colours is model (its own), one (all colour=) or limit (its own, at most limit=)"
		_colours.select(kinds.find(str(asked["colours"])))
	if asked.has("limit"):
		_limit.value = clampi(int(asked["limit"]), int(_limit.min_value), int(_limit.max_value))
		if not asked.has("colours"):
			_colours.select(2)
	_on_colours_changed()
	return ""


func _on_picked(bytes: PackedByteArray, file_name: String, extras: Dictionary) -> void:
	said.emit("reading %s…" % file_name.get_file())
	var mesh: MeshFile = null
	# An OBJ or STL is read here a line or a triangle at a time, which for a
	# scan is seconds: on a worker, so the page keeps drawing. glTF is read
	# by the engine, which makes nodes and textures, and stays here.
	if file_name.get_extension().to_lower() in ["gltf", "glb"] or OS.has_feature("nothreads"):
		await get_tree().process_frame
		mesh = MeshFile.read(bytes, file_name, extras)
	else:
		var read: Array = [null]
		var task: int = WorkerThreadPool.add_task(func() -> void:
			read[0] = MeshFile.read(bytes, file_name, extras), false, "read a 3D model")
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		mesh = read[0]
	if mesh == null or not mesh.error.is_empty():
		said.emit(mesh.error if mesh != null else "could not read %s" % file_name.get_file())
		return
	said.emit("")
	show_for(mesh)


## Show the panel for a model read already.
func show_for(mesh: MeshFile) -> void:
	_mesh = mesh
	_title.text = "Brickify “%s”" % mesh.name
	_about.text = "%s triangles%s" % [Brickify._comma(mesh.triangle_count()),
		", in colour" if mesh.coloured else ", no colour of its own"]
	_syncing = true
	_up.select(maxi(0, Brickify.UPS.find(mesh.up)))
	_colours.select(0 if mesh.coloured else 1)
	_syncing = false
	_status.text = ""
	_set_enabled(true)
	_show_model()
	_on_up_changed()
	_on_colours_changed()
	visible = true
	# While the size is chosen, the parts are on their way.
	_fetch_parts()


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_title)
	_about = _faint(column)

	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.custom_minimum_size = Vector2(330, 210)
	column.add_child(_view)
	_port = SubViewport.new()
	_port.own_world_3d = true
	_port.transparent_bg = false
	_port.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.add_child(_port)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	var sky := WorldEnvironment.new()
	sky.environment = environment
	_port.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	_port.add_child(sun)
	_turntable = Node3D.new()
	_port.add_child(_turntable)
	_shown = MeshInstance3D.new()
	_turntable.add_child(_shown)
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.9, 3.2)
	_camera.rotation = Vector3(-0.27, 0, 0)
	_camera.fov = 40.0
	_port.add_child(_camera)

	var size_row := _row(column, "Size")
	_size = HSlider.new()
	_size.min_value = Brickify.LEAST_STUDS
	_size.max_value = Brickify.MOST_STUDS
	_size.step = 1
	_size.value = 24
	_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size.tooltip_text = "Studs along its longest side, its height counted in studs too"
	size_row.add_child(_size)
	_studs = SpinBox.new()
	_studs.min_value = Brickify.LEAST_STUDS
	_studs.max_value = Brickify.MOST_STUDS
	_studs.value = 24
	_studs.suffix = "studs"
	_studs.custom_minimum_size = Vector2(104, 0)
	size_row.add_child(_studs)
	_size.value_changed.connect(func(value: float) -> void: _set_studs(int(value)))
	_studs.value_changed.connect(func(value: float) -> void: _set_studs(int(value)))

	var scale_row := _row(column, "Scale")
	_scale = SpinBox.new()
	_scale.min_value = 0.01
	_scale.max_value = 100000.0
	_scale.step = 0.01
	_scale.custom_arrow_step = 0.5
	_scale.suffix = "mm a unit"
	_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale.tooltip_text = ("How big one unit of the file comes out. A model in metres at "
		+ "1:40 is 25 mm a unit")
	_scale.value_changed.connect(_on_scale_changed)
	scale_row.add_child(_scale)

	var up_row := _row(column, "Up")
	_up = OptionButton.new()
	for words: String in ["Y is up (glTF, OBJ)", "Z is up (STL, CAD)", "Z is down",
			"X is up", "X is down", "Y is down"]:
		_up.add_item(words)
	_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_up.item_selected.connect(func(_n: int) -> void: _on_up_changed())
	up_row.add_child(_up)

	_detail = _faint(column)

	_hollow = CheckBox.new()
	_hollow.text = "Hollow"
	_hollow.tooltip_text = ("Walls two studs thick and the inside left empty: the same "
		+ "outside in much less plastic")
	_hollow.add_theme_font_size_override("font_size", 12)
	column.add_child(_hollow)

	var surface_row := _row(column, "Surface")
	_surface = OptionButton.new()
	_surface.add_item("Smooth: slopes, curves, tiles and SNOT")
	_surface.add_item("Plain bricks and plates")
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.tooltip_text = ("Smooth lays slopes and curved slopes where it falls away, "
		+ "wedges on a diagonal, tiles on top and studs-sideways tiles on a flat side")
	surface_row.add_child(_surface)

	var colour_row := _row(column, "Colour")
	_colours = OptionButton.new()
	_colours.add_item("Its own colours")
	_colours.add_item("One colour")
	_colours.add_item("Its own, at most")
	_colours.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colours.item_selected.connect(func(_n: int) -> void: _on_colours_changed())
	colour_row.add_child(_colours)
	_limit = SpinBox.new()
	_limit.min_value = 1
	_limit.max_value = 12
	_limit.value = 4
	_limit.suffix = "colours"
	colour_row.add_child(_limit)
	_one = OptionButton.new()
	_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colour_row.add_child(_one)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(300, 0)
	column.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.pressed.connect(close)
	buttons.add_child(_cancel)
	_go = Button.new()
	_go.text = "Brickify"
	_go.pressed.connect(func() -> void: brickify())
	buttons.add_child(_go)


func _row(column: Control, words: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var label := Label.new()
	label.text = words
	label.custom_minimum_size = Vector2(58, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	return row


func _faint(column: Control) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(1, 1, 1, 0.68)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label


## The status bar's line while the parts go down (Working).
var _put_job: Working.Job = null


## Put away, or stop: a run in progress is left to finish on its worker and
## its result dropped.
func close() -> void:
	if _busy:
		_stopped = true
	visible = false


## The controls a browser test presses, by name.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"brickify_studs": _studs.get_line_edit(), "brickify_go": _go,
		"brickify_hollow": _hollow, "brickify_cancel": _cancel}


## The fence behind the last turn of the preview drawn (GpuFence).
var _turned: int = 0


func _process(delta: float) -> void:
	# Still while it works, and on the web turned again only once the card
	# has drawn the last turn: spun every frame, a browser drawing in
	# software queued frame after frame of it, and the status bar's line
	# saying Brickify had started was drawn 1.6 s after the press, behind
	# them (2026-10-12).
	if not visible or _turntable == null or _busy:
		return
	if not GpuFence.passed(_turned):
		return
	_turntable.rotate_y(delta * 0.5)
	_turned = GpuFence.put()


# -- the choices --------------------------------------------------------------


func options() -> Brickify.Options:
	var out := Brickify.Options.new()
	out.studs = int(_studs.value)
	out.up = Brickify.UPS[maxi(0, _up.selected)]
	out.hollow = _hollow.button_pressed
	out.smooth = _surface.selected == 0
	out.colours = ["model", "one", "limit"][maxi(0, _colours.selected)]
	out.colour = _one.get_item_id(maxi(0, _one.selected)) if _one.item_count > 0 else 71
	out.limit = int(_limit.value)
	return out


## Set the size in studs, from the slider, the box, or a probe.
func set_studs(studs: int) -> void:
	_set_studs(studs)


func _set_studs(studs: int) -> void:
	if _syncing:
		return
	_syncing = true
	_size.value = studs
	_studs.value = studs
	_scale.value = float(studs) * STUD_MM / maxf(_longest, 0.000001)
	_syncing = false
	_describe()


func _on_scale_changed(mm: float) -> void:
	if _syncing:
		return
	var studs: int = clampi(roundi(mm * _longest / STUD_MM), Brickify.LEAST_STUDS,
		Brickify.MOST_STUDS)
	_syncing = true
	_size.value = studs
	_studs.value = studs
	_syncing = false
	_describe()


func _on_up_changed() -> void:
	if _mesh == null:
		return
	var turn: Basis = Brickify.turn_for(Brickify.UPS[maxi(0, _up.selected)])
	_box = Brickify._turned_bounds(_mesh, turn)
	_longest = maxf(_box.size.x, maxf(_box.size.y, _box.size.z))
	_place_model(turn, _box)
	_set_studs(int(_studs.value))


func _on_colours_changed() -> void:
	if _one.item_count == 0 and library != null:
		for code: int in Brickify.PALETTE:
			var colour: PartLibrary.BrickColor = library.color(code)
			if colour == null:
				continue
			var swatch := Image.create(14, 14, false, Image.FORMAT_RGBA8)
			swatch.fill(colour.rgb)
			_one.add_icon_item(ImageTexture.create_from_image(swatch), colour.name, code)
		_one.select(maxi(0, Brickify.PALETTE.find(71)))
	_limit.visible = _colours.selected == 2
	_one.visible = _colours.selected == 1


func _describe() -> void:
	if _mesh == null:
		return
	var size: Vector3i = Brickify.size_in(_box, int(_studs.value))
	_detail.text = "%d × %d studs and %d bricks tall (%d plates) — about %.0f × %.0f × %.0f cm" % [
		size.x, size.z, ceili(size.y / 3.0), size.y, size.x * STUD_MM / 10.0,
		size.z * STUD_MM / 10.0, size.y * PLATE_MM / 10.0]


# -- the picture --------------------------------------------------------------


## The model as a picture: every triangle, or for a scan of millions every
## so many of them — a picture to recognise it by, not to measure.
const MOST_SHOWN := 150000


func _show_model() -> void:
	var step: int = maxi(1, ceili(float(_mesh.triangle_count()) / MOST_SHOWN))
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var grey := Color(0.75, 0.76, 0.78)
	for t: int in range(0, _mesh.triangle_count(), step):
		for corner: int in 3:
			var b := Vector3.ZERO
			b[corner] = 1.0
			points.append(_mesh.positions[3 * t + corner])
			normals.append(_mesh.normals[3 * t + corner])
			tints.append(_mesh.colour_at(t, b) if _mesh.coloured else grey)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	# Either way round: a file's faces are wound as its maker's program
	# winds them.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.6
	mesh.surface_set_material(0, material)
	_shown.mesh = mesh


## Stood up as chosen, on the turntable, its longest side two units long.
func _place_model(turn: Basis, box: AABB) -> void:
	var fit: float = 2.0 / maxf(_longest, 0.000001)
	_turntable.rotation = Vector3.ZERO
	_shown.transform = Transform3D(Basis.from_scale(Vector3.ONE * fit) * turn,
		-box.get_center() * fit)


# -- laying it ----------------------------------------------------------------


## Work it out and put it down. Returns when it is down, or did not go.
## [param job] is a session's (ToolJobs): the same bar, handed in.
func brickify(job: Working.Job = null) -> void:
	if _busy or _mesh == null or library == null:
		return
	_busy = true
	_stopped = false
	last_summary = ""
	_set_enabled(false)
	var choice: Brickify.Options = options()
	var began: int = Time.get_ticks_msec()
	# Said in the status bar too, as every slow thing is (Working), with its
	# Cancel the same as the panel's.
	if job == null:
		job = Working.begin("Brickifying %s…" % _mesh.name, 0, true)
	else:
		job.say("Brickifying %s…" % _mesh.name)
		job.can_cancel = true
	job.cancel_wanted.connect(func() -> void: _stopped = true)
	_status.text = "getting the parts ready…"
	await job.shown()
	var missing: PackedStringArray = await _ensure_parts()
	if _checker == null:
		_checker = Assistant.new()
	_checker.library = library
	_checker.builder = builder
	_checker.world = world
	job.say("Brickifying %s: getting its shapes ready…" % _mesh.name)
	await _warm(job)
	var progress := Brickify.Progress.new()
	var result: Dictionary = {}
	var mesh: MeshFile = _mesh
	var checker: Assistant = _checker
	if OS.has_feature("nothreads"):
		await get_tree().process_frame
		result = Brickify.build(mesh, choice, checker, progress)
	else:
		# A worker never loads a part, and the library keeps new arrivals
		# aside while one reads it (PartLibrary.begin_reading).
		library.begin_reading()
		var task: int = WorkerThreadPool.add_task(func() -> void:
			result.merge(Brickify.build(mesh, choice, checker, progress)), false, "brickify")
		library.reading_in(task)
		while not WorkerThreadPool.is_task_completed(task):
			_status.text = "%s… %d s" % [progress.said(), (Time.get_ticks_msec() - began) / 1000]
			job.say("Brickifying %s: %s…" % [mesh.name, progress.said()])
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		library.end_reading(task)
	if _stopped:
		_busy = false
		_set_enabled(true)
		job.end()
		said.emit("brickifying %s stopped" % mesh.name)
		return
	if result.has("error") or not result.has("model"):
		_busy = false
		_set_enabled(true)
		job.end()
		_status.text = str(result.get("error", "it could not be laid"))
		return
	_status.text = "putting %s parts down…" % Brickify._comma(
		(result["model"] as Assistant.Model).placements.size())
	# Past stopping: what is going down goes down whole, as one undo.
	job.can_cancel = false
	job.say("Putting %s parts down…" % Brickify._comma(
		(result["model"] as Assistant.Model).placements.size()))
	_put_job = job
	var ids: PackedInt64Array = await _put_down(result, mesh.name)
	_put_job = null
	job.end()
	_busy = false
	_set_enabled(true)
	visible = false
	last_summary = _summary(result, mesh.name, Time.get_ticks_msec() - began, missing)
	brickified.emit(ids, last_summary)


func _set_enabled(on: bool) -> void:
	for control: Control in [_size, _studs, _scale, _up, _hollow, _surface, _colours, _one,
			_limit, _go]:
		if control is BaseButton:
			(control as BaseButton).disabled = not on
		elif control is Range:
			(control as Range).editable = on
	_go.text = "Brickify" if on else "Working…"


## Every part Brickify may lay, here before the worker starts: on the web
## most are fetched rather than shipped, and a worker cannot fetch. The ones
## that never came, which it then lays without.
##
## Asked for as urgent, and first as soon as the panel opens: the same
## bunny at the same size came out 1,057 parts in one browser and 1,004 in
## the next, twenty-two of its parts still queued behind the thumbnails the
## parts bin had asked for, two minutes after.
func _ensure_parts() -> PackedStringArray:
	var waiting: Dictionary = {}
	for id: String in _fetch_parts():
		waiting[id] = true
	var deadline: int = Time.get_ticks_msec() + 120000
	while not waiting.is_empty() and Time.get_ticks_msec() < deadline:
		_status.text = "fetching %d parts…" % waiting.size()
		await get_tree().process_frame
		for id: String in waiting.keys():
			if library.is_resident(id):
				waiting.erase(id)
	return PackedStringArray(waiting.keys())


## Ask for every part Brickify may lay that is not here, ahead of anything
## else waiting. The ones still on their way.
func _fetch_parts() -> PackedStringArray:
	var out := PackedStringArray()
	if library == null:
		return out
	for id: String in Brickify.parts_needed():
		if not library.is_resident(id):
			library.mesh_for(id)
		if not library.is_resident(id) and library.parts.has(id):
			library.request_mesh(id, true)
			out.append(id)
	return out


## The tables filled on first use, filled here rather than by the worker.
## A part that had not arrived when one was filled is not in it, and would
## never be laid: those are filled again now it may be here.
##
## A frame given back between each table and each part: filled in one go,
## on a browser's first Brickify, they held the page for two seconds
## before anything else happened.
func _warm(job: Working.Job = null) -> void:
	for key: Variant in Shapes._parts.keys():
		if (Shapes._parts[key] as Dictionary).is_empty():
			Shapes._parts.erase(key)
	for key: Variant in Shapes._plans.keys():
		if str(Shapes._plans[key]).is_empty():
			Shapes._plans.erase(key)
	if Patterns._wedge_shapes.size() < 4 * Patterns.WEDGES.size():
		Patterns._wedge_shapes.clear()
		Patterns._wedge_prints.clear()
	Shapes._edge_parts.clear()
	Style.norms()
	if job != null:
		await job.next()
	Patterns.wedge_shapes(library)
	if job != null:
		await job.next()
	Shapes.edge_parts(library, 1)
	if job != null:
		await job.next()
	Shapes.edge_parts(library, 3)
	for table: Array in [Shapes.Plan.SLOPES, Shapes.Plan.INVERTED]:
		for entry: Array in table:
			for id: Variant in [entry[3], entry[4]]:
				if job != null and job.due():
					await job.next()
				if not str(id).is_empty():
					Shapes.part(library, str(id), table == Shapes.Plan.INVERTED)
	for id: String in Brickify.parts_needed():
		Minifig.slot_for(library.parts.get(id))


## Into the world as one sub-assembly, beside what is there already, as one
## step to undo, and selected. A slice at a time, so a few thousand parts do
## not hold the page.
func _put_down(result: Dictionary, name: String) -> PackedInt64Array:
	placing.emit(name)
	var model: Assistant.Model = result["model"]
	var grid: Brickify.Grid = result["grid"]
	var path: String = (assemblies.unused_name(name) if assemblies != null else name) + "#1"
	var corner: Vector2i = _clear_spot(grid)
	var adds: Array = []
	for placement: Assistant.Placement in model.placements:
		var part: Lbm.PartMesh = library.mesh_for(placement.part)
		if part == null:
			continue
		placement.x += corner.x
		placement.z += corner.y
		adds.append({"part": placement.part, "color": placement.color,
			"at": _checker._transform(placement, part), "path": path})
	world.hold_drawing()
	var steps: Array = []
	var pace := FramePace.new()
	var from: int = 0
	if _put_job != null:
		_put_job.count(0, adds.size())
	for n: int in adds.size():
		if pace.due() and _put_job != null:
			_put_job.count(n)
		if pace.due() or n == adds.size() - 1:
			steps.append_array(builder.swap_bricks(PackedInt64Array(), adds.slice(from, n + 1)))
			from = n + 1
			if n < adds.size() - 1:
				await pace.next()
	world.release_drawing()
	var ids := PackedInt64Array()
	for step: Dictionary in steps:
		ids.append(int(step["brick"]))
	builder._history.append({"undo": "group", "steps": steps,
		"words": "brickified %s" % Assemblies.definition(path)})
	builder._redo.clear()
	builder.clear_selection()
	for brick_id: int in ids:
		builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())
	if assemblies != null:
		assemblies.changed.emit()
	return ids


## Where its corner goes, in studs: in the middle of an empty baseplate, or
## beside what is built, two studs clear of it.
func _clear_spot(grid: Brickify.Grid) -> Vector2i:
	var built := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = brick.transform * part.bounds
		built = box if first else built.merge(box)
		first = false
	if first:
		return Vector2i(-grid.across / 2, -grid.deep / 2)
	return Vector2i(ceili(built.end.x / BrickLattice.STUD) + 2,
		roundi(built.get_center().z / BrickLattice.STUD) - grid.deep / 2)


func _summary(result: Dictionary, name: String, ms: int,
		missing: PackedStringArray = PackedStringArray()) -> String:
	var model: Assistant.Model = result["model"]
	var report: Dictionary = result["report"]
	var colours: Dictionary = {}
	for placement: Assistant.Placement in model.placements:
		colours[placement.color] = true
	var words: String = "brickified %s: %s parts in %d colour%s" % [name,
		Brickify._comma(model.placements.size()), colours.size(),
		"" if colours.size() == 1 else "s"]
	if bool(report["ok"]) and int(report["pieces"]) <= 1:
		words += ", buildable in one piece"
	else:
		words += " — %s" % str(report["summary"])
	if not missing.is_empty():
		words += " — laid without %s, which never arrived" % ", ".join(missing)
	return "%s, in %.1f s" % [words, ms / 1000.0]
