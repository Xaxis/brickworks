## Seeing inside a model: the cut-away and x-ray.
##
## A tower's rooms, a car's seats, the stairs inside a castle wall: built by
## hand, the inside of a model is where most of the work is, and the outside
## is in the way. Hiding (H) takes parts away one by one. These see past them
## all at once, as Studio and Mecabricks do.
##
##   The cut-away (K) is a plane across the model along X, Y or Z, dragged
##   through it with the slider in the strip it puts over the model. What is
##   on the eye's side of the plane is not drawn; the faces it cuts through
##   are drawn as faces, hatched, so a wall cut through reads as a wall.
##   Optionally what is cut away stays as a faint ghost.
##
##   X-ray (I) draws everything but the selection — or the sub-assembly being
##   edited inside — see-through, so what is inside can be seen.
##
## Both are the picture only: the model, its history and its saves are
## untouched, and the booklet, drawn from a world of its own, never sees
## them. The pointer goes where the eye does — past the cut and through the
## ghosts to what is drawn solid — because the lattice it is marched through
## is told the same (BrickLattice.cut, see_through). The drawing is
## BrickWorld's (set_cut, set_xray).
class_name SeeInside
extends Node

const AXES := ["X", "Y", "Z"]
## The plane sits on odd whole LDU, between the even ones nearly every face
## of a part is on, so it never lies in a face and flickers.
const STEP := 2.0

var world: BrickWorld
var builder: Builder
var assemblies: Assemblies
var camera: Camera3D
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass
## The model's bounds without the baseplate (main's _built_bounds).
var bounds_of_model: Callable = func() -> AABB: return AABB()

## The strip over the model while a cut is on.
var bar: PanelContainer
## What runs along the foot of the model — the key strip, the timeline —
## which the strip sits above: the top of the model is the model tree's, the
## properties' and the view cube's.
var below: Array[Control] = []
## Where the plane is, outlined, so it can be found when it cuts nothing.
var frame: MeshInstance3D

var cutting: bool = false
## 0, 1, 2 for X, Y, Z.
var axis: int = 1
## Where the plane is along the axis, in LDU in the world.
var at: float = 0.0
## Whether what is cut away is on the axis's positive side.
var cuts_positive: bool = true
var leaves_ghosts: bool = false

var seeing_through: bool = false
## What x-ray keeps solid: the sub-assembly entered when it was turned on,
## or "" for the selection it was turned on with.
var _xray_path: String = ""
var _generation: int = -1

var _bounds: AABB = AABB()
var _slider: HSlider
var _reading: Label
var _axis_buttons: Array[Button] = []
var _ghost_box: CheckBox
var _setting: bool = false


func _ready() -> void:
	_build_bar()
	frame = MeshInstance3D.new()
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.visible = false
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(0.4, 0.66, 1.0, 0.9)
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.no_depth_test = true
	frame.material_override = ink
	add_child(frame)
	if assemblies != null:
		assemblies.entered_changed.connect(_on_entered)
	world.rebuilt.connect(func(_b: int, _n: int, _t: int) -> void: _check_model())


# -- the cut ------------------------------------------------------------------


## Turn the cut on or off. On, it starts across the middle of the model,
## along the axis last used, taking off the side the eye is on.
func set_cut(on: bool) -> void:
	if on == cutting:
		return
	if on and _model_box().size == Vector3.ZERO:
		say.call("there is nothing to cut through yet")
		return
	cutting = on
	if on:
		_generation = world.generation()
		cut_along(axis)
		say.call("cut along %s — drag the slider to move it, K puts the model back" % AXES[axis])
	else:
		world.set_cut(false)
		builder.lattice.cut = Plane()
		bar.visible = false
		frame.visible = false
		say.call("the whole model again")


## Cut along an axis, through the middle of the model, from the eye's side.
func cut_along(which: int) -> void:
	axis = clampi(which, 0, 2)
	if not cutting:
		set_cut(true)
		return
	_bounds = _model_box()
	var middle: float = _bounds.get_center()[axis]
	cuts_positive = camera == null or camera.global_position[axis] > middle
	_setting = true
	_slider.min_value = _odd(_bounds.position[axis] - STEP)
	_slider.max_value = _odd(_bounds.end[axis] + STEP)
	_slider.step = STEP
	_setting = false
	for n: int in 3:
		_axis_buttons[n].set_pressed_no_signal(n == axis)
	bar.visible = true
	move_to(_odd(middle))


## Move the plane to [param position] along the axis, in LDU.
func move_to(position: float) -> void:
	at = position
	if _slider.value != position:
		_setting = true
		_slider.value = position
		_setting = false
	_apply_cut()


## Cut away the other side instead.
func flip() -> void:
	if not cutting:
		set_cut(true)
		return
	cuts_positive = not cuts_positive
	_apply_cut()
	say.call("cutting away the other side")


## Leave what is cut away as a faint ghost of itself, or take it away.
func set_ghosts(on: bool) -> void:
	leaves_ghosts = on
	_ghost_box.set_pressed_no_signal(on)
	if cutting:
		_apply_cut()


## The plane as BrickWorld and the lattice take it: its normal points to
## the side that is cut away.
func plane() -> Plane:
	var normal := Vector3.ZERO
	normal[axis] = 1.0 if cuts_positive else -1.0
	return Plane(normal, at if cuts_positive else -at)


func _apply_cut() -> void:
	var cut: Plane = plane()
	world.set_cut(true, cut, leaves_ghosts)
	builder.lattice.cut = cut
	_reading.text = _words_for(at)
	_draw_frame()


## Where the plane is, as a person would say it.
func _words_for(position: float) -> String:
	if axis == 1:
		return "%.1f bricks up" % (position / BrickLattice.BRICK)
	var from: float = position - _bounds.position[axis]
	return "%.1f studs in" % (from / BrickLattice.STUD)


## An outline round the model's section at the plane.
func _draw_frame() -> void:
	var box: AABB = _bounds.grow(BrickLattice.STUD * 0.5)
	var u: int = (axis + 1) % 3
	var v: int = (axis + 2) % 3
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
			Vector2(0, 0)]:
		var point := Vector3.ZERO
		point[axis] = at
		point[u] = box.position[u] + box.size[u] * corner.x
		point[v] = box.position[v] + box.size[v] * corner.y
		corners.append(point)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point: Vector3 in corners:
		lines.surface_add_vertex(point)
	lines.surface_end()
	frame.mesh = lines
	frame.visible = true


static func _odd(value: float) -> float:
	return floorf(value / STEP) * STEP + 1.0


func _model_box() -> AABB:
	var box: AABB = bounds_of_model.call()
	return box


# -- x-ray --------------------------------------------------------------------


## Turn x-ray on or off. On, what stays solid is the sub-assembly being
## edited, or else the selection; with neither there is nothing to see
## through to, and it says so.
func set_xray(on: bool) -> bool:
	if not on:
		if seeing_through:
			seeing_through = false
			world.set_xray({})
			builder.lattice.see_through = {}
			say.call("x-ray off")
		return true
	var keep: Dictionary = {}
	if assemblies != null and not assemblies.entered.is_empty():
		_xray_path = assemblies.entered
		for brick_id: int in assemblies.ids_under(_xray_path):
			keep[brick_id] = true
	elif not builder.selection.is_empty():
		_xray_path = ""
		keep = builder.selection.duplicate()
	else:
		say.call("select what to see, or edit inside a sub-assembly, then x-ray (I)")
		return false
	seeing_through = true
	_generation = world.generation()
	_see_through_all_but(keep)
	say.call("x-ray: everything but %s is see-through — I again to end it" % (
		"the sub-assembly" if not _xray_path.is_empty() else "the selection"))
	return true


func _see_through_all_but(keep: Dictionary) -> void:
	var ghosts: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		# The baseplate stays solid: it is where a part is put down.
		if not keep.has(brick.id) and not scenery.has(brick.id):
			ghosts[brick.id] = true
	world.set_xray(ghosts)
	builder.lattice.see_through = ghosts


## Editing inside another sub-assembly while x-ray is on sees through to
## that one instead; leaving the one x-ray was showing ends it.
func _on_entered(path: String) -> void:
	if not seeing_through or _xray_path.is_empty():
		return
	if path.is_empty():
		set_xray(false)
		return
	_xray_path = path
	var keep: Dictionary = {}
	for brick_id: int in assemblies.ids_under(path):
		keep[brick_id] = true
	_see_through_all_but(keep)


## A model replaced — opened, cleared, designed afresh — ends both: they
## were about the model that was there.
func _check_model() -> void:
	if (cutting or seeing_through) and world.generation() != _generation:
		set_xray(false)
		set_cut(false)


# -- the strip ----------------------------------------------------------------


func _process(_delta: float) -> void:
	if bar == null or not bar.visible:
		return
	# Above the key strip and the timeline when they are up, however many
	# rows they wrap to.
	var lift: float = 12.0
	var area: Rect2 = (bar.get_parent() as Control).get_global_rect()
	for under: Control in below:
		if under != null and under.is_visible_in_tree():
			lift = maxf(lift, area.end.y - under.get_global_rect().position.y + 8.0)
	if not is_equal_approx(bar.offset_bottom, -lift):
		bar.offset_bottom = -lift
		bar.offset_top = -lift - bar.get_combined_minimum_size().y


func _build_bar() -> void:
	bar = PanelContainer.new()
	bar.visible = false
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.94)
	backing.border_color = Color(0.4, 0.66, 1.0, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 12
	backing.content_margin_right = 8
	backing.content_margin_top = 5
	backing.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", backing)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -12.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	var title := Label.new()
	title.text = "Cut along"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(title)
	var group := ButtonGroup.new()
	for n: int in 3:
		var button: Button = _button(AXES[n])
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = "Cut across the model along %s" % (
			["X, left to right", "Y, bottom to top", "Z, front to back"][n])
		var which: int = n
		button.pressed.connect(func() -> void: cut_along(which))
		row.add_child(button)
		_axis_buttons.append(button)

	_slider = HSlider.new()
	_slider.accessibility_name = "Where the cut is"
	_slider.custom_minimum_size = Vector2(240, 0)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_slider.tooltip_text = "Drag to move the cut through the model (the wheel moves it too)"
	_slider.value_changed.connect(func(value: float) -> void:
		if not _setting:
			move_to(value))
	row.add_child(_slider)

	_reading = Label.new()
	_reading.custom_minimum_size = Vector2(92, 0)
	_reading.add_theme_font_size_override("font_size", 12)
	_reading.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	row.add_child(_reading)

	var other: Button = _button("Flip")
	other.tooltip_text = "Cut away the other side   Shift+K"
	other.pressed.connect(flip)
	row.add_child(other)

	_ghost_box = CheckBox.new()
	_ghost_box.text = "Ghost"
	_ghost_box.focus_mode = Control.FOCUS_NONE
	_ghost_box.add_theme_font_size_override("font_size", 12)
	_ghost_box.tooltip_text = "Leave what is cut away as a faint ghost of itself"
	_ghost_box.toggled.connect(set_ghosts)
	row.add_child(_ghost_box)

	var close: Button = _button("×")
	close.tooltip_text = "The whole model again   K"
	close.pressed.connect(func() -> void: set_cut(false))
	row.add_child(close)


func _button(words: String) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size = Vector2(28, 26)
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = {"normal": Color(1, 1, 1, 0.07), "hover": Color(1, 1, 1, 0.14),
			"pressed": Color(0.36, 0.6, 1.0, 0.45),
			"hover_pressed": Color(0.36, 0.6, 1.0, 0.55)}[state]
		face.set_corner_radius_all(5)
		face.content_margin_left = 8
		face.content_margin_right = 8
		button.add_theme_stylebox_override(state, face)
	return button


## The strip's controls, for a probe or a browser test to press.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {"cut_slider": _slider, "cut_ghosts": _ghost_box}
	for n: int in 3:
		out["cut_" + AXES[n].to_lower()] = _axis_buttons[n]
	return out
