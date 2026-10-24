## Making a mould: sculpting a hair piece, a helmet or something to hold
## into a shape of one's own, its connection to the figure left exactly as
## it was (see [Mould]).
##
## The part in the middle, big: drag on it to sculpt, drag off it (or with
## the right button) to turn it, the wheel to come closer. Brushes down
## the left — pull, push, inflate, smooth, pinch, flatten, grab — with a
## size in LDU and a strength; symmetry makes every stroke on both sides;
## the lattice puts 27 handles round the part to bend all of it at once;
## "Finer" gives the surface more corners where it is coarse. What is
## locked is tinted blue — the inside that rests on the head, a socket, a
## bar — and no brush moves it. "Check walls" marks in red where the part
## is thinner than a millimetre.
##
## Start from the part in the slot, any part by number, or a dome (to wear)
## or a club (to hold). "Save mould" makes the part, keeps it, and puts it
## on the figure.
class_name MouldEditor
extends PanelContainer

signal made(ids: Array, slot: String)
signal closed()

var library: PartLibrary
var slot: String = ""
var colour_code: int = 70

var mould: Mould

var _title: Label
var _name: LineEdit
var _from: LineEdit
var _status: Label
var _counts: Label
var _tools: Dictionary = {}
var _tool: String = "pull"
var _size: HSlider
var _strength: HSlider
var _symmetry: CheckBox
var _lattice: CheckBox
var _walls: CheckBox
var _save: Button
var _waiting_for: String = ""

var _viewport: SubViewport
var _frame: SubViewportContainer
var _camera: Camera3D
var _body: MeshInstance3D
var _head: MeshInstance3D
var _ring: MeshInstance3D
var _handles: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _turn: float = 0.6
var _tilt: float = 0.35
var _reach: float = 110.0
var _centre := Vector3.ZERO

var _sculpting: bool = false
var _turning: bool = false
var _handle: int = -1
var _grab_at := Vector3.ZERO
var _grab_plane := Plane()
var _last_dab := Vector3(INF, INF, INF)
var _as_made: Dictionary = {}         ## part id -> its share under 1 mm


func _ready() -> void:
	visible = false
	_build()
	if library != null:
		library.fetched.connect(_on_fetched)


## Open on a part: what the slot holds, or the part to start from.
func open(part_id: String, for_slot: String, colour: int) -> void:
	slot = for_slot
	colour_code = colour
	visible = true
	_name.text = ""
	_start_from(part_id)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _start_from(part_id: String) -> void:
	var wanted: String = part_id.strip_edges()
	match wanted.to_lower():
		"dome":
			_take(Mould.dome())
			return
		"club":
			_take(Mould.club())
			return
	if not library.parts.has(wanted):
		_status.text = "There is no part %s." % wanted
		return
	wanted = PartPrints.mould_of(library, wanted)
	_from.text = wanted
	if library.mesh_for(wanted) == null and library.request_mesh(wanted, true):
		_status.text = "Fetching %s's geometry…" % wanted
		_waiting_for = wanted
		return
	_take(Mould.of_part(library, wanted, slot))


func _on_fetched(part_id: String) -> void:
	if part_id == _waiting_for:
		_waiting_for = ""
		_take(Mould.of_part(library, part_id, slot))


func _take(made: Mould) -> void:
	if made == null:
		_status.text = "That part has no geometry to sculpt."
		return
	mould = made
	# Corners enough for a brush to shape, where it is free to.
	mould.refine(Mould.FINEST * 2.0)
	mould._undo.clear()
	_title.text = "Make a mould from %s" % mould.name
	_from.text = mould.base if not mould.name.ends_with("Dome") and not mould.name.ends_with("Club") \
		else mould.name.get_slice(" ", mould.name.get_slice_count(" ") - 1).to_lower()
	_lattice.button_pressed = false
	_walls.button_pressed = false
	_status.text = ""
	var box := AABB(mould.positions[0], Vector3.ZERO)
	for p: Vector3 in mould.positions:
		box = box.expand(p)
	_centre = box.get_center()
	_reach = maxf(box.size.length() * 2.2, 60.0)
	_head.visible = mould.on_head
	_show()
	_aim()


# -- building the panel --------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.99)
	backing.border_color = Color(1, 1, 1, 0.16)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	for side: String in ["left", "right", "top", "bottom"]:
		backing.set("content_margin_" + side, 14)
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var from_words := Label.new()
	from_words.text = "Start from"
	from_words.add_theme_font_size_override("font_size", 12)
	from_words.modulate = Color(1, 1, 1, 0.7)
	header.add_child(from_words)
	_from = LineEdit.new()
	_from.custom_minimum_size = Vector2(110, 0)
	_from.placeholder_text = "3901, dome, club"
	_from.tooltip_text = "A part number, or dome (to wear) or club (to hold)"
	_from.text_submitted.connect(func(text: String) -> void: _start_from(text))
	header.add_child(_from)
	_button(header, "Start", func() -> void: _start_from(_from.text),
		"Start again from this part")
	_button(header, "Dome", func() -> void: _start_from("dome"),
		"A plain cap to wear, with a hair piece's socket")
	_button(header, "Club", func() -> void: _start_from("club"),
		"A plain bar to hold with a ball on the end, held where a sword is")
	var called := Label.new()
	called.text = "Name"
	called.add_theme_font_size_override("font_size", 12)
	called.modulate = Color(1, 1, 1, 0.7)
	header.add_child(called)
	_name = LineEdit.new()
	_name.placeholder_text = "Quiff"
	_name.custom_minimum_size = Vector2(140, 0)
	header.add_child(_name)
	_save = _button(header, "Save mould", _save_mould,
		"Make the part, keep it, and put it on the figure")
	_save.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_button(header, "Close", close, "Back to the figure without saving (Escape)")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_tools())
	_frame = SubViewportContainer.new()
	_frame.accessibility_name = "The part being shaped"
	_frame.stretch = true
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.custom_minimum_size = Vector2(480, 380)
	_frame.gui_input.connect(_on_view_input)
	body.add_child(_frame)
	_build_view()
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1.0, 0.86, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _build_tools() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 0)
	column.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	var names: Dictionary = {"pull": "Pull", "push": "Push", "inflate": "Inflate",
		"smooth": "Smooth", "pinch": "Pinch", "flatten": "Flatten", "grab": "Grab"}
	var tips: Dictionary = {
		"pull": "Draw the surface out towards you",
		"push": "Press the surface in",
		"inflate": "Swell it, each point straight out",
		"smooth": "Even out bumps and ridges",
		"pinch": "Draw the surface together into a crease or a ridge",
		"flatten": "Flatten it to the plane under the brush",
		"grab": "Take hold of it and drag it about",
	}
	for tool: String in Mould.TOOLS:
		var button := Button.new()
		button.text = names[tool]
		button.tooltip_text = tips[tool]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_choose_tool.bind(tool))
		column.add_child(button)
		_tools[tool] = button
	(_tools["pull"] as Button).set_pressed_no_signal(true)
	column.add_child(HSeparator.new())
	column.add_child(_words("Size (LDU)"))
	_size = HSlider.new()
	_size.min_value = 2
	_size.max_value = 24
	_size.value = 7
	_size.focus_mode = Control.FOCUS_NONE
	_size.tooltip_text = "How far the brush reaches, in LDU (2.5 to a millimetre)"
	column.add_child(_size)
	column.add_child(_words("Strength"))
	_strength = HSlider.new()
	_strength.min_value = 0.05
	_strength.max_value = 1.0
	_strength.step = 0.05
	_strength.value = 0.5
	_strength.focus_mode = Control.FOCUS_NONE
	column.add_child(_strength)
	_symmetry = CheckBox.new()
	_symmetry.text = "Symmetry"
	_symmetry.button_pressed = true
	_symmetry.focus_mode = Control.FOCUS_NONE
	_symmetry.tooltip_text = "Every stroke on both sides of the part's middle"
	column.add_child(_symmetry)
	_lattice = CheckBox.new()
	_lattice.text = "Lattice"
	_lattice.focus_mode = Control.FOCUS_NONE
	_lattice.tooltip_text = "27 handles round the part: drag one to bend the whole part"
	_lattice.toggled.connect(_on_lattice)
	column.add_child(_lattice)
	_walls = CheckBox.new()
	_walls.text = "Check walls"
	_walls.focus_mode = Control.FOCUS_NONE
	_walls.tooltip_text = "Mark in red where the part is thinner than 1 mm"
	_walls.toggled.connect(func(on: bool) -> void:
		if mould == null:
			return
		if on:
			var found: Dictionary = mould.walls()
			_status.text = "Thinnest wall %.1f mm; %.0f%% of the surface under 1 mm (red)." % [
				float(found["thinnest"]) * Lbm.LDU_MM, float(found["thin"]) * 100.0]
			# Beside what LEGO made: hair is moulded thin, and 3901 as it
			# comes is mostly under a millimetre itself.
			var as_made: float = _as_made_thin()
			if as_made >= 0.0:
				_status.text += " %s as the LEGO Group made it: %.0f%%." % [mould.base, as_made * 100.0]
		else:
			mould.thickness = PackedFloat32Array()
		_show())
	column.add_child(_walls)
	_button(column, "Finer", func() -> void:
		if mould != null:
			mould.refine(Mould.FINEST)
			_show(), "More corners where the surface is coarse, for finer detail")
	var undo_row := HBoxContainer.new()
	column.add_child(undo_row)
	_button(undo_row, "Undo", _undo, "Take the last stroke back (Ctrl+Z)")
	_button(undo_row, "Redo", _redo, "Put it back (Ctrl+Shift+Z)")
	_counts = Label.new()
	_counts.add_theme_font_size_override("font_size", 11)
	_counts.modulate = Color(1, 1, 1, 0.6)
	_counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_counts)
	var hint := Label.new()
	hint.text = ("Drag on the part to sculpt, off it to turn it; wheel to come closer. "
		+ "Blue is its connection, which stays as it is.")
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	return column


## The share of the part as LEGO made it under 1 mm thick, or -1 for a
## mould from nothing. Worked out once a part.
func _as_made_thin() -> float:
	if mould == null or not library.parts.has(mould.base) or mould.name.ends_with("Dome") \
			or mould.name.ends_with("Club"):
		return -1.0
	if not _as_made.has(mould.base):
		var plain: Mould = Mould.of_part(library, mould.base, slot)
		_as_made[mould.base] = float(plain.walls()["thin"]) if plain != null else -1.0
	return float(_as_made[mould.base])


func _words(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	return label


func _button(row: Container, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	row.add_child(button)
	return button


func _build_view() -> void:
	_viewport = SubViewport.new()
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.86, 0.9)
	environment.ambient_light_energy = BrickWorld.light_energy(0.55)
	world.environment = environment
	_viewport.world_3d = world
	_frame.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.near = 1.0
	_camera.far = 3000.0
	_viewport.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = BrickWorld.light_energy(1.0)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, 150.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.45)
	_viewport.add_child(fill)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 0.35
	_body = MeshInstance3D.new()
	_body.material_override = _material
	_viewport.add_child(_body)
	# The head it is worn on, faint, so the fit can be seen.
	_head = MeshInstance3D.new()
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.95, 0.8, 0.2, 0.35)
	head_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_head.material_override = head_material
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 12.6
	head_mesh.bottom_radius = 13.0
	head_mesh.height = 24.0
	_head.mesh = head_mesh
	_head.position = Vector3(0, -12.0, 0)
	_head.visible = false
	_viewport.add_child(_head)
	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.92
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.92, 0.55)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.no_depth_test = true
	_ring.material_override = ring_material
	_ring.visible = false
	_viewport.add_child(_ring)


# -- showing it ---------------------------------------------------------------------


func _show() -> void:
	if mould == null:
		return
	_body.mesh = mould.mesh()
	var colour: PartLibrary.BrickColor = library.color(colour_code)
	_material.albedo_color = Color(colour.rgb, 1.0)
	_counts.text = "%d triangles · about %d kB in a file" % [mould.triangle_count(),
		mould.triangle_count() * 70 / 1000]
	_place_handles()


func _aim() -> void:
	_camera.position = _centre + Vector3(sin(_turn) * cos(_tilt), sin(_tilt),
		cos(_turn) * cos(_tilt)) * _reach
	_camera.look_at(_centre, Vector3.UP)


func _choose_tool(tool: String) -> void:
	_tool = tool
	(_tools[tool] as Button).set_pressed_no_signal(true)


func _undo() -> void:
	if mould != null and mould.undo():
		_show()


func _redo() -> void:
	if mould != null and mould.redo():
		_show()


func _on_lattice(on: bool) -> void:
	for handle: MeshInstance3D in _handles:
		handle.queue_free()
	_handles.clear()
	if mould == null:
		return
	if on:
		mould.lattice_begin()
		var ball := SphereMesh.new()
		ball.radius = 1.4
		ball.height = 2.8
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color(1.0, 0.6, 0.15)
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.no_depth_test = true
		for n: int in 27:
			var handle := MeshInstance3D.new()
			handle.mesh = ball
			handle.material_override = ink
			_viewport.add_child(handle)
			_handles.append(handle)
		_place_handles()
	else:
		mould.lattice_end()


func _place_handles() -> void:
	if _handles.is_empty() or mould == null:
		return
	var at: PackedVector3Array = mould.lattice_handles()
	for n: int in mini(at.size(), _handles.size()):
		_handles[n].position = at[n]


# -- sculpting with the mouse -----------------------------------------------------------


## The ray under a point of the view.
func _ray(at: Vector2) -> Array:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	var inside: Vector2 = at * scale
	return [_camera.project_ray_origin(inside), _camera.project_ray_normal(inside)]


func _on_view_input(event: InputEvent) -> void:
	if mould == null:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_reach = maxf(20.0, _reach / 1.12)
			_aim()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_reach = minf(800.0, _reach * 1.12)
			_aim()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_turning = button.pressed
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_press(button.position)
			else:
				_release()
		accept_event()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _turning:
			_turn -= motion.relative.x * 0.01
			_tilt = clampf(_tilt + motion.relative.y * 0.01, -1.4, 1.4)
			_aim()
		elif _sculpting or _handle >= 0:
			_move(motion.position)
		else:
			_hover(motion.position)
		accept_event()


func _press(at: Vector2) -> void:
	var ray: Array = _ray(at)
	if _lattice.button_pressed:
		_handle = _handle_under(at)
		if _handle >= 0:
			_grab_plane = Plane(-_camera.global_transform.basis.z,
				mould.lattice_handles()[_handle])
			return
	var hit: Dictionary = mould.pick(ray[0], ray[1])
	if hit.is_empty():
		_turning = true
		return
	_sculpting = true
	if _tool == "grab":
		_grab_at = hit["at"]
		_grab_plane = Plane(-_camera.global_transform.basis.z, _grab_at)
		mould.grab(_grab_at, _size.value, _symmetry.button_pressed)
		return
	mould.begin()
	_last_dab = Vector3(INF, INF, INF)
	_dab(hit)


func _move(at: Vector2) -> void:
	var ray: Array = _ray(at)
	if _handle >= 0:
		var to: Variant = _grab_plane.intersects_ray(ray[0], ray[1])
		if to != null:
			mould.lattice_move(_handle, to, _symmetry.button_pressed)
			_show()
		return
	if _tool == "grab":
		var to: Variant = _grab_plane.intersects_ray(ray[0], ray[1])
		if to != null:
			mould.drag((to as Vector3) - _grab_at)
			_show()
		return
	var hit: Dictionary = mould.pick(ray[0], ray[1])
	if not hit.is_empty():
		_dab(hit)
	_hover(at)


## A dab where the brush is, once it has moved a quarter of its size.
func _dab(hit: Dictionary) -> void:
	var at: Vector3 = hit["at"]
	if at.distance_to(_last_dab) < _size.value * 0.25:
		return
	_last_dab = at
	mould.dab(_tool, at, hit["normal"], _size.value, _strength.value, _symmetry.button_pressed)
	_show()


func _release() -> void:
	_sculpting = false
	_turning = false
	_handle = -1
	mould.let_go()
	if _walls.button_pressed:
		mould.walls()
		_show()


func _hover(at: Vector2) -> void:
	var ray: Array = _ray(at)
	var hit: Dictionary = mould.pick(ray[0], ray[1])
	_ring.visible = not hit.is_empty() and not _lattice.button_pressed
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(normal, up).rotated(Basis.looking_at(normal, up).x, PI * 0.5)
	_ring.transform = Transform3D(basis.scaled(Vector3.ONE * _size.value), hit["at"])


func _handle_under(at: Vector2) -> int:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	var best: int = -1
	var nearest: float = 16.0
	var handles: PackedVector3Array = mould.lattice_handles()
	for n: int in handles.size():
		var seen: Vector2 = _camera.unproject_position(handles[n]) / scale
		if seen.distance_to(at) < nearest:
			nearest = seen.distance_to(at)
			best = n
	return best


# -- saving --------------------------------------------------------------------------


func _save_mould() -> void:
	if mould == null:
		return
	_lattice.button_pressed = false
	var title: String = _name.text.strip_edges()
	if title.is_empty():
		title = "My Mould"
	_status.text = "Building the mould…"
	_save.disabled = true
	# Said before the build starts, which in a browser takes a few seconds.
	await get_tree().process_frame
	await get_tree().process_frame
	var result: Dictionary = mould.make(library, title)
	_save.disabled = false
	if not str(result["problem"]).is_empty():
		_status.text = "Not saved: %s." % result["problem"]
		return
	_status.text = "Saved as %s." % result["id"]
	made.emit([result["id"]], slot)
	close()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed:
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_Z and key.is_command_or_control_pressed() \
			and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if key.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


# -- for a check to use as a person would ------------------------------------------------


func view() -> SubViewportContainer:
	return _frame


## Where on the view a point of the part is seen.
func on_view(point: Vector3) -> Vector2:
	var scale: Vector2 = Vector2(_viewport.size) / _frame.size
	return _camera.unproject_position(point) / scale


func turn_to(turn: float, tilt: float, reach: float = -1.0) -> void:
	_turn = turn
	_tilt = tilt
	if reach > 0.0:
		_reach = reach
	_aim()


func choose_tool(tool: String) -> void:
	_choose_tool(tool)


func set_brush(size: float, strength: float) -> void:
	_size.value = size
	_strength.value = strength


func controls_by_name() -> Dictionary:
	var named: Dictionary = {"mould_view": _frame, "mould_name": _name, "mould_save": _save,
		"mould_from": _from, "mould_symmetry": _symmetry, "mould_lattice": _lattice,
		"mould_walls": _walls}
	for tool: String in _tools:
		named["mould_tool_" + tool] = _tools[tool]
	for button: Node in find_children("*", "Button", true, false):
		match (button as Button).text:
			"Close": named["mould_close"] = button
			"Dome": named["mould_dome"] = button
			"Club": named["mould_club"] = button
			"Finer": named["mould_finer"] = button
	return named
