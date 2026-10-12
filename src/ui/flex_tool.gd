## Build, Hose, tube or chain…: laying a flexible part by hand.
##
## BrickLink Studio's flex tools, the way a person uses them: choose what
## to lay and how long a part it is, click the connector it starts on and
## the one it ends on, and it is laid along a smooth curve of the real
## part's length (Flex). A chain or a tread: click the sprockets it goes
## round. Then drag the bend points to shape it, add one with Add a bend,
## and Done. The part is one item, a sub-assembly of its segments, so a
## click takes all of it, it saves as the segments any LDraw tool reads,
## and Edit, Reshape the hose or chain opens it again — after a reopen too,
## read off its own pieces.
##
## While it is out it has the left button and the pointer, as the ruler
## does (Main._unhandled_input asks [method takes] first); the view still
## turns with the other buttons.
class_name FlexTool
extends Node3D

## The model changed: something was laid or reshaped.
signal changed()

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var assemblies: Assemblies
var camera: Camera3D
## Where the status line is.
var say: Callable = func(_words: String) -> void: pass

## The panel: Main puts it over the model.
var panel: PanelContainer

var active: bool = false
var kind: String = "pneumatic_tube"
## Which of the kind's lengths: -1 for the shortest that fits.
var length_choice: int = -1
## "start", "end", "sprockets" or "shaping".
var stage: String = ""

## The ends picked, each {brick, kind, at, axis, reach, side} with at and
## axis in the brick's own frame, so an item follows a brick moved.
var _ends: Array = []
var _sprockets: Array[int] = []
var _controls: PackedVector3Array = PackedVector3Array()
var _colour: int = 0
## The item being shaped, by its path in the model tree.
var _item: String = ""
var _laid: Flex.Laid = null
var _real_id: String = ""
## Once a part is laid it keeps its length while it is bent: a real hose
## does. Until then the shortest that fits is chosen afresh.
var _length_kept: bool = false
var _hover: Flex.Anchor = null
var _hover_sprocket: Flex.Sprocket = null
var _anchors: Array = []
var _anchors_for: String = ""
var _drag: int = -1
var _before_drag: PackedVector3Array = PackedVector3Array()
var _pressed_at: Vector2 = Vector2.INF
var _laying: bool = false
var _preview: Flex.Laid = null
## Items laid this session, path -> what they were laid from, so a reshape
## starts from what the person chose rather than from the pieces.
var _items: Dictionary = {}

var _mesh: ImmediateMesh
var _lines: MeshInstance3D
## The bend points, as balls: a line one pixel wide is lost on a model.
var _balls: Array[MeshInstance3D] = []
## What to lay: kind -> its button.
var _kind_buttons: Dictionary = {}
var _length_picker: OptionButton
var _told: Label
var _status: Label
var _add_bend: Button
var _clear_bends: Button
var _again: Button
var _done: Button
var _told_page: String = ""
var _told_page_at: int = 0

const KIND_ORDER: Array[String] = ["pneumatic_tube", "ribbed_hose", "flex_hose", "flex_axle",
	"string", "chain", "tread"]
const HANDLE_PIXELS := 14.0


func _ready() -> void:
	_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.mesh = _mesh
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	_lines.material_override = material
	add_child(_lines)
	_build_panel()
	panel.visible = false


# -- in and out ---------------------------------------------------------------


## Out, for a new part: choose and click its first end.
func open() -> void:
	active = true
	_item = ""
	_laid = null
	_real_id = ""
	_length_kept = false
	_ends.clear()
	_sprockets.clear()
	_controls = PackedVector3Array()
	_colour = builder.held_color if builder != null else 0
	builder.clear_selection()
	builder.hide_preview()
	_begin()
	panel.visible = true
	_draw()


## Reshape the item at [param path]. False when it is not one.
func reshape(path: String) -> bool:
	var pieces: Array = _pieces_of(path)
	var found: String = Flex.kind_of(pieces.map(func(p: Dictionary) -> String:
		return str(p["part"])))
	if found.is_empty():
		return false
	active = true
	kind = found
	_item = path
	_laid = null
	builder.clear_selection()
	builder.hide_preview()
	_colour = int(pieces[0]["color"])
	_select_kind_quietly()
	length_choice = -1
	_length_kept = true
	# What it was laid from, if these are still the very pieces laid: an
	# undo, a reopen or another tool gives it new ones, and then it is read
	# off them.
	var known: Dictionary = _items.get(path, {})
	if not known.is_empty() and known["ids"] == _ids_of(path):
		_ends = (known["ends"] as Array).duplicate(true)
		_sprockets.assign(known["sprockets"])
		_controls = known["controls"]
		_real_id = str(known["real"])
	else:
		_recover(pieces)
	_fill_lengths()
	stage = "sprockets" if _is_chain() else "shaping"
	panel.visible = true
	_laid = _lay_now()
	_tell("Drag a bend point to reshape it; Add a bend for another. Done when it is right."
		if not _is_chain() else "Click a sprocket to put it in the loop or take it out.")
	_show_buttons()
	_show_result()
	_draw()
	return true


## Whether the selection is exactly one flexible item, and its path.
func selected_item() -> String:
	if builder == null or assemblies == null:
		return ""
	var path: String = assemblies.selected_assembly()
	if path.is_empty():
		return ""
	var parts: Array = assemblies.bricks_under(path).map(func(b: BrickWorld.Brick) -> String:
		return b.part_id)
	return path if not Flex.kind_of(parts).is_empty() else ""


func leave() -> void:
	if not active:
		return
	active = false
	stage = ""
	_drag = -1
	_hover = null
	_hover_sprocket = null
	panel.visible = false
	_draw()
	if not _item.is_empty():
		_select_item()
		say.call("%s laid — Edit, Reshape the hose or chain to change it" % Assemblies.label(_item))


func _begin() -> void:
	_ends.clear()
	_sprockets.clear()
	_controls = PackedVector3Array()
	_hover = null
	_fill_lengths()
	if _is_chain():
		stage = "sprockets"
		_tell("Click the sprockets or gears it goes round, two or more, all in one plane.")
	else:
		stage = "start"
		_tell("Click the %s it starts on." % _connector_words())
	_status.text = ""
	_show_buttons()


func _is_chain() -> bool:
	return str(Flex.KINDS[kind]["family"]) == "links"


func _connector_words() -> String:
	var takes: Array = Flex.KINDS[kind].get("takes", [])
	var words: PackedStringArray = PackedStringArray()
	for one: Variant in takes:
		words.append({"pin_hole": "pin hole", "axle_hole": "axle hole", "pin": "pin",
			"axle": "axle", "clip": "clip or hollow stud", "stud": "stud",
			"nozzle": "pneumatic outlet"}.get(str(one), str(one)))
	if words.size() <= 1:
		return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + " or " + words[words.size() - 1]


# -- the pointer -------------------------------------------------------------------


## Whether a pointer event is the tool's, handling it if so.
func takes(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		var moved: InputEventMouseMotion = event
		if _drag >= 0:
			_drag_to(moved.position)
		else:
			_aim(moved.position)
		return true
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button.pressed:
			_pressed_at = button.position
			if stage == "shaping":
				_before_drag = _controls.duplicate()
				_drag = _handle_at(button.position)
		else:
			if _drag >= 0:
				_drag = -1
				_let_go()
			elif _pressed_at.distance_to(button.position) < 6.0:
				click(button.position)
		return true
	return false


func _input(event: InputEvent) -> void:
	if not active or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if _drag >= 0:
			_drag = -1
			_preview = null
			_draw()
		else:
			leave()
		get_viewport().set_input_as_handled()


func _ray(at: Vector2) -> Array:
	return [camera.project_ray_origin(at), camera.project_ray_normal(at).normalized()]


func _aim(at: Vector2) -> void:
	var ray: Array = _ray(at)
	var hit: BrickLattice.Hit = builder.lattice.raycast(ray[0], ray[1])
	var before: float = hit.distance + BrickLattice.STUD * 1.2 if hit.is_valid() else INF
	_hover = null
	_hover_sprocket = null
	if stage == "start" or stage == "end":
		_hover = Flex.aimed(_anchors_now(), ray[0], ray[1], before)
	elif stage == "sprockets" and hit.is_valid():
		_hover_sprocket = Flex.sprocket_of(world.get_brick(hit.brick_id), library)
	_draw()


## A click: an end, a sprocket in or out of the loop.
func click(at: Vector2) -> void:
	_aim(at)
	match stage:
		"start", "end":
			if _hover == null:
				say.call("that is not a %s" % _connector_words())
				return
			_ends.append(_end_record(_hover, at))
			_hover = null
			if stage == "start":
				stage = "end"
				_tell("Now click the %s it ends on." % _connector_words())
				_draw()
				return
			stage = "shaping"
			_put()
		"sprockets":
			if _hover_sprocket == null:
				say.call("that is not a sprocket or a gear a chain goes on")
				return
			var brick_id: int = _hover_sprocket.brick
			if _sprockets.has(brick_id):
				_sprockets.erase(brick_id)
			else:
				_sprockets.append(brick_id)
			if _sprockets.size() >= 2:
				_put()
			else:
				_tell("Click another sprocket.")
				_draw()


## What is kept of an end picked: its connector in its brick's own frame,
## and the face of a hole to leave by — the one looking at the camera.
func _end_record(anchor: Flex.Anchor, _at: Vector2) -> Dictionary:
	var brick: BrickWorld.Brick = world.get_brick(anchor.brick)
	var back: Transform3D = brick.transform.affine_inverse()
	var toward_eye: int = 1
	if anchor.is_hole():
		toward_eye = 1 if anchor.axis.dot(camera.global_position - anchor.at) >= 0.0 else -1
	return {"brick": anchor.brick, "kind": anchor.kind, "at": back * anchor.at,
		"axis": (back.basis * anchor.axis).normalized(), "reach": anchor.reach,
		"eye": toward_eye}


## An end picked, where its brick is now.
func _anchor_of(record: Dictionary) -> Flex.Anchor:
	var anchor := Flex.Anchor.new()
	anchor.kind = str(record["kind"])
	anchor.reach = float(record["reach"])
	anchor.brick = int(record["brick"])
	var brick: BrickWorld.Brick = world.get_brick(anchor.brick)
	var at: Transform3D = brick.transform if brick != null else Transform3D.IDENTITY
	anchor.at = at * (record["at"] as Vector3)
	anchor.axis = (at.basis * (record["axis"] as Vector3)).normalized()
	return anchor


func _anchors_now() -> Array:
	var key: String = "%s|%d" % [kind, world.revision]
	if key != _anchors_for:
		_anchors = Flex.anchors_in(world, library, kind, _item_bricks())
		_anchors_for = key
	return _anchors


func _item_bricks() -> Dictionary:
	var out: Dictionary = {}
	if not _item.is_empty():
		for brick_id: int in assemblies.ids_under(_item):
			out[brick_id] = true
	return out


# -- handles ----------------------------------------------------------------------


## The bend points shown to be dragged.
func handles() -> PackedVector3Array:
	if _laid != null and Flex.KINDS[kind].get("hangs", false) and _controls.is_empty():
		return _laid.controls
	return _controls


func _handle_at(at: Vector2) -> int:
	var shown: PackedVector3Array = handles()
	var best: int = -1
	var nearest: float = HANDLE_PIXELS
	for n: int in shown.size():
		if camera.is_position_behind(shown[n]):
			continue
		var gap: float = camera.unproject_position(shown[n]).distance_to(at)
		if gap < nearest:
			nearest = gap
			best = n
	if best >= 0 and _controls.is_empty():
		# A string's hanging middle, taken in hand: it is a bend point now.
		_controls = shown.duplicate()
	return best


func _drag_to(at: Vector2) -> void:
	if _drag < 0 or _drag >= _controls.size():
		return
	var ray: Array = _ray(at)
	var facing := Plane(-camera.global_transform.basis.z, _controls[_drag])
	var landing: Variant = facing.intersects_ray(ray[0], ray[1])
	if landing == null:
		return
	_controls[_drag] = landing
	_preview = _compute()
	_show_result(_preview)
	_draw()


## A bend point let go: the part laid through it, unless that bends it
## tighter than the real part goes when it did not before. Then it stays
## as it was, and says why.
func _let_go() -> void:
	var trial: Flex.Laid = _compute()
	var least: float = float(Flex.KINDS[kind].get("bend", 0.0)) - 0.25
	if trial != null and trial.tightest < least and (_laid == null or _laid.tightest >= least):
		_controls = _before_drag
		_preview = null
		_show_result()
		_status.text = "That would bend it round %.0f LDU, and a %s goes no tighter than %.0f: it is left as it was." \
			% [trial.tightest, str(Flex.KINDS[kind]["label"]).to_lower(), least + 0.25]
		_status.modulate = Color(1.0, 0.78, 0.35)
		_draw()
		return
	_put()


## A bend point in the middle of the longest stretch between two, on the
## path as it lies.
func add_bend() -> void:
	if _laid == null or _laid.path == null or _is_chain():
		return
	if _controls.is_empty() and Flex.KINDS[kind].get("hangs", false):
		_controls = _laid.controls.duplicate()
	var path: Flex.Path = _laid.path
	var marks: Array[float] = [0.0]
	for control: Vector3 in _controls:
		marks.append(_along(path, control))
	marks.append(path.total())
	marks.sort()
	var widest: int = 0
	for n: int in marks.size() - 1:
		if marks[n + 1] - marks[n] > marks[widest + 1] - marks[widest]:
			widest = n
	var point: Vector3 = path.at((marks[widest] + marks[widest + 1]) * 0.5)
	var placed: PackedVector3Array = PackedVector3Array()
	var inserted: bool = false
	for control: Vector3 in _controls:
		if not inserted and _along(path, control) > _along(path, point):
			placed.append(point)
			inserted = true
		placed.append(control)
	if not inserted:
		placed.append(point)
	# On the path where it lies, so nothing moves until it is dragged.
	_controls = placed
	_show_buttons()
	_draw()


func clear_bends() -> void:
	if _controls.is_empty():
		return
	_controls = PackedVector3Array()
	_put()


static func _along(path: Flex.Path, point: Vector3) -> float:
	var best: float = 0.0
	var nearest: float = INF
	for n: int in path.points.size():
		var gap: float = path.points[n].distance_squared_to(point)
		if gap < nearest:
			nearest = gap
			best = path.along[n]
	return best


# -- laying ------------------------------------------------------------------------


## What the choices come to now, without putting anything down.
func _compute() -> Flex.Laid:
	if _is_chain():
		var sprockets: Array = []
		for brick_id: int in _sprockets:
			var sprocket: Flex.Sprocket = Flex.sprocket_of(world.get_brick(brick_id), library)
			if sprocket != null:
				sprockets.append(sprocket)
		if sprockets.size() < 2:
			return null
		return Flex.lay_chain(kind, sprockets)
	if _ends.size() < 2:
		return null
	var anchors: Array = [_anchor_of(_ends[0]), _anchor_of(_ends[1])]
	var ports: Array = []
	for n: int in 2:
		var anchor: Flex.Anchor = anchors[n]
		if str(_ends[n].get("free", "")) == "yes":
			ports.append(Flex.free_port(anchor.at, anchor.axis, float(_ends[n]["lead"])))
			continue
		var other: Flex.Anchor = anchors[1 - n]
		var side: int = Flex.side_toward(anchor, other.at, int(_ends[n].get("eye", 1)))
		if _ends[n].has("side"):
			side = int(_ends[n]["side"])
		ports.append(Flex.port_for(kind, anchor, side, n))
	var lengths: Array = Flex.lengths_of(library, kind)
	if lengths.is_empty():
		return null
	if length_choice >= 0 and length_choice < lengths.size():
		_real_id = str(lengths[length_choice]["id"])
		return Flex.lay_swept(kind, ports[0], ports[1], float(lengths[length_choice]["length"]),
			_controls)
	if not _real_id.is_empty() and _length_kept:
		for one: Dictionary in lengths:
			if str(one["id"]) == _real_id:
				return Flex.lay_swept(kind, ports[0], ports[1], float(one["length"]), _controls)
	# The shortest that fits: no warnings, else the one with fewest.
	var best: Flex.Laid = null
	for one: Dictionary in lengths:
		var trial: Flex.Laid = Flex.lay_swept(kind, ports[0], ports[1], float(one["length"]),
			_controls)
		if best == null or trial.warnings.size() < best.warnings.size():
			best = trial
			_real_id = str(one["id"])
		if trial.warnings.is_empty():
			break
	return best


func _lay_now() -> Flex.Laid:
	var laid: Flex.Laid = _compute()
	_preview = null
	return laid


## Lay the part as the choices say, in place of what was there: one step
## to undo.
func _put() -> void:
	if _laying:
		return
	var laid: Flex.Laid = _lay_now()
	if laid == null:
		_draw()
		return
	if laid.pieces.is_empty():
		_laid = laid
		_show_result()
		_draw()
		return
	_laying = true
	var wanted: Dictionary = {}
	for piece: Dictionary in laid.pieces:
		wanted[str(piece["part"])] = true
	if not await _fetch(wanted.keys()):
		_laying = false
		_status.text = "could not fetch the parts for it; try again"
		return
	var first: bool = _item.is_empty()
	if first:
		var name: String = Flex.item_name(kind, library, _real_id if not _is_chain()
			else str(Flex.KINDS[kind]["link"]))
		if _is_chain():
			name = str(Flex.KINDS[kind]["label"])
		_item = Assemblies.join(assemblies.entered, assemblies.unused_name(name) + "#1")
	var adds: Array = []
	for piece: Dictionary in laid.pieces:
		adds.append({"part": piece["part"], "color": _colour, "at": piece["at"], "path": _item})
	var steps: Array = builder.swap_bricks(assemblies.ids_under(_item), adds)
	builder.record(steps, ("laid %s" if first else "reshaped %s") % Assemblies.label(_item))
	_laid = laid
	_length_kept = true
	_items[_item] = {"kind": kind, "ends": _ends.duplicate(true), "sprockets": _sprockets.duplicate(),
		"controls": _controls.duplicate(), "real": _real_id, "ids": _ids_of(_item)}
	_laying = false
	if stage != "sprockets":
		stage = "shaping"
		_tell("Drag a bend point to reshape it, or Add a bend. Done when it is right.")
	else:
		_tell("Click a sprocket to put it in the loop or take it out; Done when it is right.")
	# Not selected while it is being shaped: the outline would hide it.
	builder.clear_selection()
	_show_result()
	_show_buttons()
	_draw()
	changed.emit()


func _fetch(parts: Array) -> bool:
	var waiting: Dictionary = {}
	for part: Variant in parts:
		var id: String = str(part)
		if library.mesh_for(id) == null and not library.is_resident(id):
			if library.request_mesh(id, true):
				waiting[id] = true
	var until: int = Time.get_ticks_msec() + 30000
	while not waiting.is_empty() and Time.get_ticks_msec() < until:
		if not _status.text.begins_with("fetching"):
			_status.text = "fetching %d parts…" % waiting.size()
		await get_tree().process_frame
		for id: String in waiting.keys():
			if library.is_resident(id):
				waiting.erase(id)
	return waiting.is_empty()


func _select_item() -> void:
	if _item.is_empty():
		return
	builder.selection.clear()
	for brick_id: int in assemblies.ids_under(_item):
		builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())


func _ids_of(path: String) -> PackedInt64Array:
	var ids: PackedInt64Array = assemblies.ids_under(path)
	ids.sort()
	return ids


## The pieces of an item, as Flex reads them.
func _pieces_of(path: String) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in assemblies.bricks_under(path):
		out.append({"part": brick.part_id, "at": brick.transform, "color": brick.color_code,
			"id": brick.id})
	return out


## What an item was laid from, read off its pieces: its ends on the
## connectors they are at, its bend from where it lies, its length the
## real part's nearest; a chain's sprockets, the ones its pins are on.
func _recover(pieces: Array) -> void:
	_ends.clear()
	_sprockets.clear()
	_controls = PackedVector3Array()
	_real_id = ""
	if _is_chain():
		for sprocket: Flex.Sprocket in Flex.sprockets_of_item(world, library, pieces):
			_sprockets.append(sprocket.brick)
		return
	var ports: Array = Flex.ends_of_item(kind, pieces)
	var skip: Dictionary = {}
	for piece: Dictionary in pieces:
		skip[int(piece["id"])] = true
	var anchors: Array = Flex.anchors_in(world, library, kind, skip)
	for n: int in ports.size():
		var port: Flex.Port = ports[n]
		var matched: Dictionary = {}
		for anchor: Flex.Anchor in anchors:
			for side: int in [1, -1]:
				var trial: Flex.Port = Flex.port_for(kind, anchor, side, n)
				if trial.tip.distance_to(port.tip) < 1.0 and trial.out.dot(port.out) > 0.99:
					matched = _end_record(anchor, Vector2.ZERO)
					matched["side"] = side
					break
			if not matched.is_empty():
				break
		if matched.is_empty():
			# On nothing the app knows: a free end where it is.
			matched = {"brick": 0, "kind": "free", "at": port.tip, "axis": port.out,
				"reach": 0.0, "free": "yes", "lead": port.lead}
		_ends.append(matched)
	var real: float = Flex.item_length(kind, pieces)
	var nearest: float = INF
	for one: Dictionary in Flex.lengths_of(library, kind):
		var off: float = absf(float(one["length"]) - real)
		if off < nearest:
			nearest = off
			_real_id = str(one["id"])
	# The bend: where it lies now, if laying it afresh would not put it
	# there. One point halfway along it, else two at the thirds, else
	# three: the fewest that lay it where it lies.
	if _ends.size() != 2 or ports.size() != 2:
		return
	var line := Flex.Path.new()
	line.points = Flex.centreline(kind, pieces, (ports[0] as Flex.Port).tip)
	line.measure()
	if line.points.size() < 3:
		return
	# Each way scored by how far it lies from where the item is, and a
	# bend tighter than the part goes counted against it: a fit that kinks
	# it would kink it again at the first drag.
	var best: PackedVector3Array = PackedVector3Array()
	var own: float = minf(line.tightest(2.0), float(Flex.KINDS[kind].get("bend", 0.0)))
	var best_score: float = _score(line, _compute(), own)
	for fractions: Array in [[0.5], [0.4], [0.6], [0.33, 0.67], [0.25, 0.75],
			[0.25, 0.5, 0.75]]:
		if best_score < 2.5:
			break
		_controls = PackedVector3Array()
		for fraction: float in fractions:
			_controls.append(line.at(line.total() * fraction))
		var score: float = _score(line, _compute(), own)
		if score < best_score:
			best_score = score
			best = _controls
	_controls = best


static func _score(line: Flex.Path, laid: Flex.Laid, own: float) -> float:
	if laid == null:
		return INF
	return _off(line, laid) + (50.0 if laid.tightest < own * 0.8 else 0.0)


## How far from a path the farthest point of a centreline is.
static func _off(line: Flex.Path, laid: Flex.Laid) -> float:
	if laid == null or laid.path == null:
		return INF
	var worst: float = 0.0
	for point: Vector3 in line.points:
		worst = maxf(worst, point.distance_to(laid.path.at(_along(laid.path, point))))
	return worst


# -- what is shown -------------------------------------------------------------------


func _show_result(laid: Flex.Laid = null) -> void:
	# The length the part is, once it is laid, in the picker.
	if _length_kept and not _is_chain() and _length_picker != null:
		var lengths: Array = Flex.lengths_of(library, kind)
		for n: int in lengths.size():
			if str(lengths[n]["id"]) == _real_id and _length_picker.selected != n + 1:
				_length_picker.select(n + 1)
	var shown: Flex.Laid = laid if laid != null else _laid
	if shown == null:
		_status.text = ""
		return
	var lines := PackedStringArray()
	if _is_chain():
		if shown.pieces.is_empty():
			lines.append_array(shown.warnings)
		else:
			lines.append("%d links round %d sprockets." % [shown.links, _sprockets.size()])
			lines.append_array(shown.notes)
	else:
		var name: String = Flex.item_name(kind, library, _real_id)
		lines.append("%s, %.0f LDU along it; it bends round %.0f LDU at the tightest." % [
			name, shown.length, minf(shown.tightest, 9999.0)])
		lines.append_array(shown.warnings)
	_status.text = "\n".join(lines)
	_status.modulate = Color(1.0, 0.78, 0.35) if not shown.warnings.is_empty() \
		else Color(1, 1, 1, 0.8)


func _tell(words: String) -> void:
	_told.text = words


func _show_buttons() -> void:
	var shaping: bool = stage == "shaping" and not _is_chain()
	_add_bend.visible = shaping
	_clear_bends.visible = shaping and not _controls.is_empty()
	_again.visible = stage != "start" and stage != "sprockets" or not _sprockets.is_empty()


func _draw() -> void:
	_mesh.clear_surfaces()
	if not active:
		for ball: MeshInstance3D in _balls:
			ball.visible = false
		return
	var any: bool = false
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var mark := func(at: Vector3, axis: Vector3, radius: float, colour: Color) -> void:
		var a: Vector3 = axis.normalized()
		var u: Vector3 = (Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT).cross(a).normalized()
		var v: Vector3 = a.cross(u)
		for n: int in 24:
			var t0: float = TAU * float(n) / 24.0
			var t1: float = TAU * float(n + 1) / 24.0
			_mesh.surface_set_color(colour)
			_mesh.surface_add_vertex(at + (u * cos(t0) + v * sin(t0)) * radius)
			_mesh.surface_set_color(colour)
			_mesh.surface_add_vertex(at + (u * cos(t1) + v * sin(t1)) * radius)
	if _hover != null:
		mark.call(_hover.middle(), _hover.axis, 8.0, Color(1.0, 0.85, 0.2))
		_mesh.surface_set_color(Color(1.0, 0.85, 0.2))
		_mesh.surface_add_vertex(_hover.middle())
		_mesh.surface_set_color(Color(1.0, 0.85, 0.2))
		_mesh.surface_add_vertex(_hover.middle() + _hover.axis * 16.0)
		any = true
	for record: Dictionary in _ends:
		if str(record.get("free", "")) == "yes":
			continue
		var anchor: Flex.Anchor = _anchor_of(record)
		mark.call(anchor.middle(), anchor.axis, 7.0, Color(0.35, 0.95, 0.5))
		any = true
	for brick_id: int in _sprockets:
		var sprocket: Flex.Sprocket = Flex.sprocket_of(world.get_brick(brick_id), library)
		if sprocket != null:
			mark.call(sprocket.centre, sprocket.axis, sprocket.radius, Color(0.35, 0.95, 0.5))
			any = true
	if _hover_sprocket != null:
		mark.call(_hover_sprocket.centre, _hover_sprocket.axis, _hover_sprocket.radius + 3.0,
			Color(1.0, 0.85, 0.2))
		any = true
	var shown: PackedVector3Array = handles() if stage == "shaping" else PackedVector3Array()
	while _balls.size() < shown.size():
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 3.5
		sphere.height = 7.0
		sphere.radial_segments = 16
		sphere.rings = 8
		ball.mesh = sphere
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var look := StandardMaterial3D.new()
		look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		look.no_depth_test = true
		look.render_priority = 11
		ball.material_override = look
		add_child(ball)
		_balls.append(ball)
	for n: int in _balls.size():
		var ball: MeshInstance3D = _balls[n]
		ball.visible = n < shown.size()
		if ball.visible:
			ball.position = shown[n]
			(ball.material_override as StandardMaterial3D).albedo_color = \
				Color(1, 1, 1) if n == _drag else Color(1.0, 0.55, 0.15)
			mark.call(shown[n], -camera.global_transform.basis.z, 6.5, Color(1.0, 0.55, 0.15))
			any = true
	if _preview != null and _preview.path != null:
		# Blue where it can go; amber where it would bend too tight or
		# not reach.
		var tint := Color(0.45, 0.75, 1.0) if _preview.warnings.is_empty() \
			else Color(1.0, 0.6, 0.2)
		var points: PackedVector3Array = _preview.path.points
		for n: int in range(1, points.size()):
			_mesh.surface_set_color(tint)
			_mesh.surface_add_vertex(points[n - 1])
			_mesh.surface_set_color(tint)
			_mesh.surface_add_vertex(points[n])
		any = true
	if not any:
		# An empty surface is refused; a point where nothing is.
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


# -- the panel -----------------------------------------------------------------------


func _build_panel() -> void:
	panel = PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", backing)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(300, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Hose, tube or chain"
	title.add_theme_font_size_override("font_size", 14)
	column.add_child(title)
	# What to lay, every choice in sight as a button: a list that has to be
	# opened hides six of seven, and a finger opens it with difficulty.
	var kinds := GridContainer.new()
	kinds.columns = 2
	kinds.add_theme_constant_override("h_separation", 4)
	kinds.add_theme_constant_override("v_separation", 4)
	column.add_child(kinds)
	var group := ButtonGroup.new()
	for key: String in KIND_ORDER:
		var button := Button.new()
		button.text = str(Flex.KINDS[key]["label"])
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var down := StyleBoxFlat.new()
		down.bg_color = Color(0.36, 0.6, 1.0, 0.38)
		down.set_corner_radius_all(3)
		down.content_margin_top = 3
		down.content_margin_bottom = 3
		button.add_theme_stylebox_override("pressed", down)
		var chosen: String = key
		button.pressed.connect(func() -> void: choose_kind(chosen))
		kinds.add_child(button)
		_kind_buttons[key] = button
	_length_picker = OptionButton.new()
	_length_picker.add_theme_font_size_override("font_size", 12)
	_length_picker.focus_mode = Control.FOCUS_NONE
	_length_picker.item_selected.connect(func(index: int) -> void:
		length_choice = index - 1
		if index == 0:
			_length_kept = false
		if stage == "shaping":
			_put())
	column.add_child(_length_picker)
	_told = Label.new()
	_told.add_theme_font_size_override("font_size", 12)
	_told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_told.custom_minimum_size = Vector2(280, 0)
	column.add_child(_told)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(280, 0)
	column.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	_add_bend = _button(row, "Add a bend", add_bend, "A point on the path to drag it by")
	_clear_bends = _button(row, "Straighten", clear_bends, "Take the bend points out")
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	column.add_child(row2)
	_again = _button(row2, "Start again", func() -> void:
		_item = ""
		_laid = null
		_real_id = ""
		_length_kept = false
		_begin()
		_draw(), "Pick the ends again for a new one; what is laid stays")
	_done = _button(row2, "Done", leave, "Finish (Escape)")
	_select_kind_quietly()
	_fill_lengths()


func _button(into: Control, words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


func _select_kind_quietly() -> void:
	for key: String in _kind_buttons:
		(_kind_buttons[key] as Button).set_pressed_no_signal(key == kind)


## Lay a [param chosen] next: the ends are picked again, and what is laid
## stays.
func choose_kind(chosen: String) -> void:
	if not Flex.KINDS.has(chosen):
		return
	kind = chosen
	length_choice = -1
	_real_id = ""
	_length_kept = false
	_item = ""
	_laid = null
	_select_kind_quietly()
	_begin()
	_draw()


func _fill_lengths() -> void:
	if _length_picker == null or library == null:
		return
	_length_picker.clear()
	_length_picker.visible = not _is_chain()
	if _is_chain():
		return
	_length_picker.add_item("The shortest that fits")
	for one: Dictionary in Flex.lengths_of(library, kind):
		_length_picker.add_item("%s — %.0f LDU" % [Flex.item_name(kind, library, str(one["id"])),
			float(one["length"])])
	_length_picker.select(clampi(length_choice + 1, 0, _length_picker.item_count - 1))


## Where each control is, for a browser test to press it.
func controls_by_name() -> Dictionary:
	if not active:
		return {}
	var out: Dictionary = {"flex_length": _length_picker,
		"flex_add_bend": _add_bend, "flex_straighten": _clear_bends, "flex_again": _again,
		"flex_done": _done}
	for key: String in _kind_buttons:
		out["flex_kind_" + key] = _kind_buttons[key]
	return out


func _process(_delta: float) -> void:
	_tell_page()


## What the tool is doing and where on the screen its targets are, for a
## browser test: window.brickworksFlex. Web builds only.
func _tell_page() -> void:
	if not OS.has_feature("web"):
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var per_css: float = float(ratio) if ratio != null and float(ratio) > 0.0 else 1.0
	var to_window: Transform2D = get_viewport().get_final_transform()
	var screen := func(point: Vector3) -> Dictionary:
		var at: Vector2 = to_window * camera.unproject_position(point) / per_css
		return {"x": roundi(at.x), "y": roundi(at.y)}
	var state: Dictionary = {"active": active, "stage": stage, "kind": kind, "item": _item,
		"status": _status.text, "told": _told.text}
	if _laid != null:
		state["pieces"] = _laid.pieces.size()
		state["length"] = snappedf(_laid.length, 0.1)
		state["links"] = _laid.links
		state["warnings"] = Array(_laid.warnings)
	if active:
		var targets: Array = []
		if stage == "start" or stage == "end":
			for anchor: Flex.Anchor in _anchors_now():
				if targets.size() >= 120 or camera.is_position_behind(anchor.middle()):
					continue
				var brick: BrickWorld.Brick = world.get_brick(anchor.brick)
				var spot: Dictionary = screen.call(anchor.middle())
				spot["brick"] = anchor.brick
				spot["kind"] = anchor.kind
				spot["part"] = brick.part_id if brick != null else ""
				targets.append(spot)
		elif stage == "sprockets":
			for brick: BrickWorld.Brick in world.bricks():
				var sprocket: Flex.Sprocket = Flex.sprocket_of(brick, library)
				if sprocket == null or camera.is_position_behind(sprocket.centre):
					continue
				# Aimed at its rim, which is plastic, not at the hole.
				var rim: Vector3 = sprocket.centre + (Vector3.UP - sprocket.axis
					* sprocket.axis.y).normalized() * sprocket.radius * 0.8
				var spot: Dictionary = screen.call(rim)
				spot["brick"] = brick.id
				spot["part"] = brick.part_id
				spot["chosen"] = _sprockets.has(brick.id)
				targets.append(spot)
		state["targets"] = targets
		var shown: Array = []
		for point: Vector3 in handles():
			if not camera.is_position_behind(point):
				shown.append(screen.call(point))
		state["handles"] = shown
	var said: String = JSON.stringify(state)
	if said == _told_page:
		return
	_told_page = said
	JavaScriptBridge.eval("window.brickworksFlex = %s" % said, true)
