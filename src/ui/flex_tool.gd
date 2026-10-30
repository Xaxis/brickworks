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
var camera: CadCamera
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
## A band's round things in the order picked, each {brick, near} with near
## where it was clicked in the brick's own frame (where along an axle).
var _rounds: Array = []
var _hover_round: Bands.Round = null
## The band chosen ("" for the one that fits) and the band laid.
var _band: String = ""
## The spring or shock absorber, and the turns its coil was made with (0
## until it is laid: then as many as its length gives, kept as it moves).
var _spring: String = "70038"
var _turns: int = 0
## How deep the history was when this band or spring was first laid or
## opened to reshape: every laying since is one step (Builder.fold_since).
var _depth: int = -1
var _session_words: String = ""
## The history step [method follow_moved] looked at last.
var _followed: Dictionary = {}

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
	"string", "chain", "tread", "band", "spring"]
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


## Whether picking [param part_id] from the bin lays it with this tool: a
## rubber band, a spring or a 6.5L shock absorber.
static func lays_part(part_id: String) -> bool:
	return Bands.BANDS.has(part_id) or not Bands.spring_of(part_id).is_empty()


## Out with a band, a spring or a shock picked from the bin: the round
## things or the two ends it goes on are clicked next.
func open_with(part_id: String) -> void:
	if Bands.BANDS.has(part_id):
		kind = "band"
		_band = part_id
	elif not Bands.spring_of(part_id).is_empty():
		kind = "spring"
		_spring = part_id
	_select_kind_quietly()
	open()


## Out, for a new part: choose and click its first end.
func open() -> void:
	active = true
	_item = ""
	_laid = null
	_real_id = ""
	_length_kept = false
	_depth = -1
	_turns = 0
	_ends.clear()
	_sprockets.clear()
	_rounds.clear()
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
	_depth = builder.history_depth()
	builder.clear_selection()
	builder.hide_preview()
	_colour = int(pieces[0]["color"])
	for piece: Dictionary in pieces:
		# A spring's coil is spring steel and a shock's rod black: the
		# colour chosen is its cylinder's.
		if not str(piece["part"]).begins_with(Bands.COIL_PREFIX) and str(piece["part"]) != Bands.SHOCK_ROD:
			_colour = int(piece["color"])
			break
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
		_rounds = (known.get("rounds", []) as Array).duplicate(true)
		_band = str(known.get("band", _band))
		_spring = str(known.get("spring", _spring))
		_turns = int(known.get("turns", 0))
	else:
		_recover(pieces)
	_fill_lengths()
	stage = "sprockets" if _is_chain() else ("pulleys" if _is_band() else "shaping")
	panel.visible = true
	_laid = _lay_now()
	if _is_band():
		_tell("Click a round thing to put the band round it too, or take it off.")
	elif _is_spring():
		_tell("Move a part it is on and it follows; pick another spring or shock in the list.")
	else:
		_tell("Drag a bend point to reshape it; Add a bend for another. Done when it is right."
			if not _is_chain() else "Click a sprocket to put it in the loop or take it out.")
	_show_buttons()
	_show_result()
	_draw()
	return true


## Lay one without the panel, as two clicks and Done would: between two
## connectors ([param anchors], Flex.Anchor) or round [param sprockets]
## (brick ids), in [param colour]; in place of [param item]'s pieces when
## one is named. What a session over MCP asks for (AppTools). The laid
## result, or null when the ends make nothing; [method laid_item] is its
## path. One undo step, as a laying by hand is.
func lay(of_kind: String, anchors: Array, sprockets: Array, colour: int,
		item: String = "", part: String = "") -> Flex.Laid:
	if _laying or not Flex.KINDS.has(of_kind):
		return null
	var was_active: bool = active
	kind = of_kind
	_item = item
	_laid = null
	_real_id = ""
	_length_kept = false
	length_choice = -1
	_depth = -1
	_turns = 0
	_ends.clear()
	_sprockets.clear()
	_rounds.clear()
	_controls = PackedVector3Array()
	_colour = colour
	if of_kind == "band":
		_band = part if Bands.BANDS.has(part) else ""
	elif of_kind == "spring":
		_spring = part if not Bands.spring_of(part).is_empty() else "70038"
	for anchor: Flex.Anchor in anchors:
		var record: Dictionary = _end_record(anchor, Vector2.ZERO)
		# Out of the face toward the other end, not the one the person's
		# camera happens to look at.
		record.erase("eye")
		_ends.append(record)
	if of_kind == "band":
		# Round the round things named, in the order named.
		for brick_id: Variant in sprockets:
			var brick: BrickWorld.Brick = world.get_brick(int(brick_id))
			var round: Bands.Round = Bands.round_of(brick, library)
			if round != null:
				_rounds.append({"brick": round.brick, "near": brick.transform.affine_inverse() * round.centre})
	else:
		_sprockets.assign(sprockets)
	stage = "sprockets" if _is_chain() else ("pulleys" if _is_band() else "shaping")
	await _put()
	var laid: Flex.Laid = _laid
	if not was_active:
		active = false
		stage = ""
		panel.visible = false
		_draw()
	return laid


## The path of what was laid or reshaped last.
func laid_item() -> String:
	return _item


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
	_rounds.clear()
	_controls = PackedVector3Array()
	_hover = null
	_hover_round = null
	_turns = 0
	_depth = -1
	_fill_lengths()
	if _is_chain():
		stage = "sprockets"
		_tell("Click the sprockets or gears it goes round, two or more, all in one plane.")
	elif _is_band():
		stage = "pulleys"
		_tell("Click the pulleys, wheels, bushes or axles it goes round, in order round the loop.")
	else:
		stage = "start"
		_tell("Click the %s it starts on." % _connector_words())
	_status.text = ""
	_show_buttons()


func _is_chain() -> bool:
	return str(Flex.KINDS[kind]["family"]) == "links"


func _is_band() -> bool:
	return kind == "band"


func _is_spring() -> bool:
	return kind == "spring"


## The kinds laid as pieces of the app's making, every laying of one
## making or reshaping one undo step.
func _is_made() -> bool:
	return _is_band() or _is_spring()


func _connector_words() -> String:
	var takes: Array = Flex.KINDS[kind].get("takes", [])
	if _is_spring() and Bands.SHOCKS.has(_spring):
		takes = ["pin_hole", "pin"]
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
	# Through the lens the view is drawn with: it is shifted to the model's
	# column, and the engine's own rays would miss by the shift.
	return [camera.ray_origin(at), camera.ray_normal(at)]


func _aim(at: Vector2) -> void:
	var ray: Array = _ray(at)
	var hit: BrickLattice.Hit = builder.lattice.raycast(ray[0], ray[1])
	var before: float = hit.distance + BrickLattice.STUD * 1.2 if hit.is_valid() else INF
	_hover = null
	_hover_sprocket = null
	_hover_round = null
	if stage == "start" or stage == "end":
		_hover = Flex.aimed(_anchors_now(), ray[0], ray[1], before)
	elif stage == "sprockets" and hit.is_valid():
		_hover_sprocket = Flex.sprocket_of(world.get_brick(hit.brick_id), library)
	elif stage == "pulleys" and hit.is_valid():
		_hover_round = _round_near(ray[0] + ray[1] * hit.distance)
	_draw()


## The round thing a band would go round at [param point], where the
## pointer meets the model: a pulley, a bush or a wheel there before an
## axle, which a click on a bush's hole meets first, and before the band's
## own pieces.
func _round_near(point: Vector3) -> Bands.Round:
	var skip: Dictionary = _item_bricks()
	var cell: Vector3i = BrickLattice.to_cell(point)
	var seen: Dictionary = {}
	var best: Bands.Round = null
	var best_gap: float = INF
	for dx: int in range(-2, 3):
		for dy: int in range(-2, 3):
			for dz: int in range(-2, 3):
				for brick_id: int in builder.lattice.bricks_at(cell + Vector3i(dx, dy, dz)):
					if seen.has(brick_id) or skip.has(brick_id):
						continue
					seen[brick_id] = true
					var round: Bands.Round = Bands.round_of(world.get_brick(brick_id), library, point)
					if round == null:
						continue
					var gap: float = round.centre.distance_to(point) + (1000.0 if round.reach > 0.0 else 0.0)
					if gap < best_gap:
						best_gap = gap
						best = round
	return best


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
		"pulleys":
			if _hover_round == null:
				say.call("that is not round: a band goes round a pulley, a wheel, a bush or an axle")
				return
			pick_round(_hover_round)


## A round thing clicked: into the band's loop, after the last one picked,
## or out of it if it is in it already. Laid once there are two.
func pick_round(round: Bands.Round) -> void:
	var brick: BrickWorld.Brick = world.get_brick(round.brick)
	if brick == null:
		return
	var at: int = -1
	for n: int in _rounds.size():
		if int(_rounds[n]["brick"]) == round.brick:
			at = n
	if at >= 0:
		_rounds.remove_at(at)
	else:
		_rounds.append({"brick": round.brick, "near": brick.transform.affine_inverse() * round.centre})
	_hover_round = null
	if _rounds.size() >= 2:
		_put()
	else:
		_tell("Click the next one it goes round.")
		_draw()


## The round things picked, where their bricks are now.
func _rounds_now() -> Array:
	var out: Array = []
	for record: Dictionary in _rounds:
		var brick: BrickWorld.Brick = world.get_brick(int(record["brick"]))
		var round: Bands.Round = Bands.round_of(brick, library,
			brick.transform * (record["near"] as Vector3)) if brick != null else null
		if round != null:
			out.append(round)
	return out


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
	if _is_made():
		return PackedVector3Array()
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
		marks.append(Flex.along_of(path, control))
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
		if not inserted and Flex.along_of(path, control) > Flex.along_of(path, point):
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




# -- laying ------------------------------------------------------------------------


## What the choices come to now, without putting anything down.
func _compute() -> Flex.Laid:
	if _is_band():
		return _compute_band()
	if _is_spring():
		return _compute_spring()
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


## A band round the round things picked: the band chosen, or the one that
## fits the loop they make.
func _compute_band() -> Flex.Laid:
	var rounds: Array = _rounds_now()
	if rounds.size() < 2:
		return null
	var band: String = _band
	if band.is_empty():
		var trial: Dictionary = Bands.loop(rounds, float(Bands.BANDS["85543"]["half"]))
		band = Bands.band_for(float(trial.get("length", 0.0)))
	_real_id = band
	return Bands.lay_band(band, rounds, Bands.SEGMENT_PREFIX + band)


## A spring or a shock between the two ends picked, its coil the turns it
## was made with: as many as its length gives when it is first laid, or a
## shock's own spring's.
func _compute_spring() -> Flex.Laid:
	if _ends.size() < 2:
		return null
	var ends: Array = spring_ends()
	var spring: String = Bands.spring_of(_spring)
	var turns: int = _turns
	if turns <= 0:
		var length: float = (ends[0] as Vector3).distance_to(ends[1])
		if Bands.SHOCKS.has(_spring):
			length = Bands.SHOCK_LONGEST - Bands.SHOCK_SEAT - Bands.SHOCK_COLLAR
		turns = Bands.turns_for(spring, length)
	_real_id = _spring
	return Bands.lay_spring(_spring, ends[0], ends[1], ends[2], "%s%s-%d" % [Bands.COIL_PREFIX,
		spring, turns], turns)


## Where a spring's two ends go on the connectors picked, and the way a
## shock's pin holes run: [a, b, across]. A spring ends at a hole's face
## toward the other end, or round a pin's middle; a shock's pin hole goes on
## the same pin as a beam's hole, beside it on the side the first end was
## picked from, or round a pin.
func spring_ends() -> Array:
	var anchors: Array = [_anchor_of(_ends[0]), _anchor_of(_ends[1])]
	var shock: bool = Bands.SHOCKS.has(_spring)
	var out: Array = []
	var aside := Vector3.ZERO
	for n: int in 2:
		var anchor: Flex.Anchor = anchors[n]
		var other: Flex.Anchor = anchors[1 - n]
		if str(_ends[n].get("free", "")) == "yes":
			out.append(anchor.at)
		elif not anchor.is_hole():
			out.append(anchor.middle())
		elif shock:
			if aside == Vector3.ZERO:
				aside = anchor.axis * float(int(_ends[n].get("side", _ends[n].get("eye", 1))))
			out.append(anchor.at + (aside if aside.dot(anchor.axis) >= 0.0 else -aside).normalized()
				* Bands.SHOCK_ASIDE * absf(aside.normalized().dot(anchor.axis)))
		else:
			var side: int = int(_ends[n].get("side", Flex.side_toward(anchor, other.at,
				int(_ends[n].get("eye", 1)))))
			out.append(anchor.at + anchor.axis * float(side) * anchor.reach)
	out.append(anchors[0].axis)
	return out


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
	# A band's and a spring's pieces are of the app's making: made here.
	for part: Variant in wanted:
		if Bands.is_piece_id(str(part)) and not Bands.piece_part(library, str(part)):
			_laying = false
			_status.text = "could not make %s" % str(part)
			return
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
		adds.append({"part": piece["part"], "color": int(piece.get("color", _colour)), "at": piece["at"],
			"path": _item})
	var steps: Array = builder.swap_bricks(assemblies.ids_under(_item), adds)
	var depth: int = builder.history_depth()
	var words: String = ("laid %s" if first else "reshaped %s") % Assemblies.label(_item)
	builder.record(steps, words)
	if _is_made():
		# Made or reshaped in one go, however many clicks it took.
		if _depth < 0:
			_depth = depth
			_session_words = words
		else:
			builder.fold_since(_depth, _session_words)
		if _is_spring():
			_turns = laid.links
	_laid = laid
	_length_kept = true
	_items[_item] = {"kind": kind, "ends": _ends.duplicate(true), "sprockets": _sprockets.duplicate(),
		"controls": _controls.duplicate(), "real": _real_id, "ids": _ids_of(_item),
		"rounds": _rounds.duplicate(true), "band": _band, "spring": _spring, "turns": _turns}
	_laying = false
	if _is_band():
		_tell("Click another to put the band round it too, or one it is round to take it off. Done when it is right.")
	elif _is_spring():
		stage = "shaping"
		_tell("Move a part it is on and it follows. Done when it is right.")
	elif stage != "sprockets":
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
	if _is_band():
		_recover_band(pieces)
		return
	if _is_spring():
		_recover_spring(pieces)
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
	_real_id = Flex.real_part(library, kind, pieces)
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
	var own: float = minf(line.tightest(2.0), float(Flex.KINDS[kind].get("bend", 0.0)))
	_controls = Flex.fit_bend(func(controls: PackedVector3Array) -> Flex.Laid:
		_controls = controls
		return _compute(), line, own)


## A band's round things read off its pieces: every one whose groove its
## loop lies on, in the order the loop goes round them.
func _recover_band(pieces: Array) -> void:
	var read: Dictionary = _band_read(pieces)
	_band = str(read["band"])
	_real_id = _band
	_rounds = read["rounds"]


## What [method _recover_band] reads: {"band", "rounds" (each {brick,
## near}), "moved" (whether one of them is in [param moved])}. Each brick in
## [param moved] (id -> [where it was, where it is]) is read where it was:
## a band round a pulley a step moved is round it as it stood. Its pieces
## are put end to end (each runs from its origin to the next one's) for the
## order the loop goes round them.
func _band_read(pieces: Array, moved: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"band": "", "rounds": [], "moved": false}
	var starts: Dictionary = {}
	var skip: Dictionary = {}
	for piece: Dictionary in pieces:
		skip[int(piece["id"])] = true
		var its: String = Bands.band_of_piece(str(piece["part"]))
		if its.is_empty():
			continue
		out["band"] = its
		var at: Transform3D = piece["at"]
		starts[Vector3i((at.origin * 20.0).round())] = at
	if starts.is_empty() or not Bands.BANDS.has(str(out["band"])):
		return out
	var half: float = float((Bands.BANDS[str(out["band"])] as Dictionary)["half"])
	var chain := PackedVector3Array()
	var here: Transform3D = starts.values()[0]
	for _n: int in starts.size():
		chain.append(here.origin)
		var key := Vector3i(((here.origin - here.basis.y) * 20.0).round())
		if not starts.has(key) or chain.size() >= starts.size():
			break
		here = starts[key]
	var box := AABB(chain[0], Vector3.ZERO)
	for point: Vector3 in chain:
		box = box.expand(point)
	box = box.grow(half + 4.0)
	var found: Array = []
	for brick: BrickWorld.Brick in world.bricks():
		if skip.has(brick.id) or brick.hidden:
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		var was: Transform3D = (moved[brick.id] as Array)[0] if moved.has(brick.id) else brick.transform
		if mesh == null or not (was * mesh.bounds).intersects(box):
			continue
		var round: Bands.Round = Bands.round_of(brick, library, null, was)
		if round == null:
			continue
		var on: int = 0
		var first: int = -1
		var plane := Vector3.ZERO
		for n: int in chain.size():
			var gap: Vector3 = chain[n] - round.centre
			var along: float = gap.dot(round.axis)
			if absf(along) > round.reach + 1.0:
				continue
			if absf((gap - round.axis * along).length() - (round.radius + half)) < 0.75:
				on += 1
				if first < 0:
					first = n
					plane = round.centre + round.axis * along
		if on >= 2:
			found.append([first, {"brick": brick.id, "near": was.affine_inverse() * plane}])
			if moved.has(brick.id):
				out["moved"] = true
	found.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	for one: Array in found:
		(out["rounds"] as Array).append(one[1])
	return out


## A spring's ends read off its pieces, on the connectors they are at, and
## the turns its coil was made with.
func _recover_spring(pieces: Array) -> void:
	var read: Dictionary = Bands.spring_read(pieces)
	if read.is_empty():
		return
	_spring = str(read["part"])
	_turns = int(read["turns"])
	_real_id = _spring
	var shock: bool = Bands.SHOCKS.has(_spring)
	var skip: Dictionary = {}
	for piece: Dictionary in pieces:
		skip[int(piece["id"])] = true
	var anchors: Array = Flex.anchors_in(world, library, "spring", skip)
	for n: int in 2:
		var tip: Vector3 = read["a"] if n == 0 else read["b"]
		var matched: Dictionary = {}
		for anchor: Flex.Anchor in anchors:
			if not anchor.is_hole():
				if anchor.middle().distance_to(tip) < 0.5:
					matched = _end_record(anchor, Vector2.ZERO)
			else:
				for side: int in [1, -1]:
					var reach: float = Bands.SHOCK_ASIDE if shock else anchor.reach
					if (anchor.at + anchor.axis * float(side) * reach).distance_to(tip) < 0.5:
						matched = _end_record(anchor, Vector2.ZERO)
						matched["side"] = side
						break
			if not matched.is_empty():
				break
		if matched.is_empty():
			matched = {"brick": 0, "kind": "free", "at": tip, "axis": read["across"], "reach": 0.0,
				"free": "yes", "lead": 0.0}
		_ends.append(matched)


# -- following a part moved ----------------------------------------------------------


## Bands and springs on parts the newest step moved, laid again where those
## parts now stand, in the same undo step (Main, after every edit). A pulley
## moved takes its band with it; a beam moved stretches or squeezes the
## spring on it, its coil the turns it had. One whose own pieces the step
## moved or laid went with them, and an undo or a redo brings back pieces
## that followed already (Builder.settled). How many followed.
func follow_moved() -> int:
	if _laying or builder == null or assemblies == null:
		return 0
	var step: Dictionary = builder.last_step()
	if step.is_empty() or is_same(step, _followed) or is_same(step, builder.settled):
		return 0
	_followed = step
	var moved: Dictionary = {}
	var touched: Dictionary = {}
	_moves_in(step, moved, touched)
	if moved.is_empty():
		return 0
	var steps: Array = []
	var count: int = 0
	var items: Dictionary = Flex.items_in(world)
	for path: String in items:
		var item: Dictionary = items[path]
		var its: String = str(item["kind"])
		if its != "band" and its != "spring":
			continue
		var pieces: Array = []
		var still: bool = true
		for brick: BrickWorld.Brick in item["bricks"]:
			if touched.has(brick.id):
				still = false
				break
			pieces.append({"part": brick.part_id, "at": brick.transform, "color": brick.color_code,
				"id": brick.id})
		if not still or pieces.is_empty():
			continue
		var laid: Flex.Laid = _band_followed(pieces, moved) if its == "band" \
			else _spring_followed(pieces, moved)
		if laid == null:
			continue
		if laid.pieces.is_empty():
			say.call("%s stays where it was: %s" % [Assemblies.label(path), "; ".join(laid.warnings)])
			continue
		var colours: Dictionary = {}
		for piece: Dictionary in pieces:
			colours[str(piece["part"])] = int(piece["color"])
		var adds: Array = []
		for piece: Dictionary in laid.pieces:
			var part: String = str(piece["part"])
			adds.append({"part": part, "color": int(colours.get(part, piece.get("color", _colour))),
				"at": piece["at"], "path": path})
		steps.append_array(builder.swap_bricks(assemblies.ids_under(path), adds))
		_items.erase(path)
		count += 1
	if not steps.is_empty():
		builder.extend_last(steps)
		_followed = builder.last_step()
	return count


## The bricks a history step moved, id -> [where it was, where it is], and
## every brick it touched at all.
func _moves_in(step: Dictionary, moved: Dictionary, touched: Dictionary) -> void:
	if step.get("undo", "") == "group":
		for inner: Variant in step.get("steps", []):
			_moves_in(inner, moved, touched)
		return
	if not step.has("brick"):
		return
	var brick_id: int = builder._live(int(step["brick"]))
	touched[brick_id] = true
	if step.get("undo", "") != "move" or moved.has(brick_id):
		return
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick != null and not brick.transform.is_equal_approx(step["transform"]):
		moved[brick_id] = [step["transform"], brick.transform]


## A band laid again round its round things where they now stand, if a step
## moved one ([param moved], as [method _moves_in] gives); else null.
func _band_followed(pieces: Array, moved: Dictionary) -> Flex.Laid:
	# Only a band a moved part stood in the loop of is read: reading one
	# looks at every part near it.
	var box := AABB((pieces[0]["at"] as Transform3D).origin, Vector3.ZERO)
	for piece: Dictionary in pieces:
		box = box.expand((piece["at"] as Transform3D).origin)
	box = box.grow(4.0)
	var near: bool = false
	for brick_id: int in moved:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id) if brick != null else null
		if mesh != null and (((moved[brick_id] as Array)[0] as Transform3D) * mesh.bounds).intersects(box):
			near = true
			break
	if not near:
		return null
	var read: Dictionary = _band_read(pieces, moved)
	if not bool(read["moved"]) or (read["rounds"] as Array).size() < 2:
		return null
	var rounds: Array = []
	for one: Dictionary in read["rounds"]:
		var brick: BrickWorld.Brick = world.get_brick(int(one["brick"]))
		var round: Bands.Round = Bands.round_of(brick, library, brick.transform * (one["near"] as Vector3))
		if round == null:
			return null
		rounds.append(round)
	var band: String = str(read["band"])
	return Bands.lay_band(band, rounds, Bands.SEGMENT_PREFIX + band)


## A spring laid again between its ends where the parts holding them now
## stand, each end carried as its part moved, if a step moved one; else
## null. Its coil keeps its turns, squeezed or stretched.
func _spring_followed(pieces: Array, moved: Dictionary) -> Flex.Laid:
	var read: Dictionary = Bands.spring_read(pieces)
	if read.is_empty():
		return null
	var ends: Array = [read["a"], read["b"]]
	var across: Vector3 = read["across"]
	var shock: bool = Bands.SHOCKS.has(str(read["part"]))
	var any: bool = false
	for n: int in 2:
		var tip: Vector3 = ends[n]
		for brick_id: int in moved:
			var was: Transform3D = (moved[brick_id] as Array)[0]
			var now: Transform3D = (moved[brick_id] as Array)[1]
			if not _holds(brick_id, was, tip, shock):
				continue
			var carry: Transform3D = now * was.affine_inverse()
			ends[n] = carry * tip
			if n == 0:
				across = (carry.basis * across).normalized()
			any = true
			break
	if not any:
		return null
	var spring: String = str(read["spring"])
	var turns: int = int(read["turns"])
	return Bands.lay_spring(str(read["part"]), ends[0], ends[1], across,
		"%s%s-%d" % [Bands.COIL_PREFIX, spring, turns], turns)


## Whether the brick [param brick_id], standing at [param at], holds a
## spring's end at [param tip]: round one of its pins, at a face of one of
## its holes, or (a shock's) beside one.
func _holds(brick_id: int, at: Transform3D, tip: Vector3, shock: bool) -> bool:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	if brick == null:
		return false
	for anchor: Flex.Anchor in Flex.anchors_of(library.mesh_for(brick.part_id), at, brick_id):
		if anchor.is_male() and anchor.middle().distance_to(tip) < 0.5:
			return true
		if anchor.is_hole():
			var reach: float = Bands.SHOCK_ASIDE if shock else anchor.reach
			for side: int in [1, -1]:
				if (anchor.at + anchor.axis * float(side) * reach).distance_to(tip) < 0.5:
					return true
	return false


# -- what is shown -------------------------------------------------------------------


func _show_result(laid: Flex.Laid = null) -> void:
	# The length the part is, once it is laid, in the picker.
	if _length_kept and not _is_chain() and not _is_made() and _length_picker != null:
		var lengths: Array = Flex.lengths_of(library, kind)
		for n: int in lengths.size():
			if str(lengths[n]["id"]) == _real_id and _length_picker.selected != n + 1:
				_length_picker.select(n + 1)
	var shown: Flex.Laid = laid if laid != null else _laid
	if shown == null:
		_status.text = ""
		return
	var lines := PackedStringArray()
	if _is_made():
		var name: String = Flex.item_name(kind, library, _real_id) if library.parts.has(_real_id) \
			else str(Flex.KINDS[kind]["label"])
		if not shown.pieces.is_empty():
			lines.append("%s, %s." % [name, ", ".join(shown.notes)])
		lines.append_array(shown.warnings)
	elif _is_chain():
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
	var shaping: bool = stage == "shaping" and not _is_chain() and not _is_made()
	_add_bend.visible = shaping
	_clear_bends.visible = shaping and not _controls.is_empty()
	_again.visible = (stage != "start" and stage != "sprockets" and stage != "pulleys") \
		or not _sprockets.is_empty() or not _rounds.is_empty()


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
	if _hover_round != null:
		mark.call(_hover_round.centre, _hover_round.axis, _hover_round.radius + 3.0,
			Color(1.0, 0.85, 0.2))
		any = true
	if stage == "pulleys":
		for round: Bands.Round in _rounds_now():
			mark.call(round.centre, round.axis, round.radius + 1.5, Color(0.35, 0.95, 0.5))
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
		down.bg_color = Look.CHOSEN
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
	_length_picker.item_selected.connect(choose_length)
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


## The length picker's [param index] chosen: a hose's real part ("The
## shortest that fits" first), a band, or a spring or a shock. What is being
## laid is laid again with it.
func choose_length(index: int) -> void:
	if _is_band():
		var bands: Array = _band_choices()
		_band = "" if index <= 0 or index > bands.size() else str(bands[index - 1])
		if _rounds.size() >= 2:
			_put()
		return
	if _is_spring():
		var springs: Array = _spring_choices()
		if index >= 0 and index < springs.size() and str(springs[index]) != _spring:
			_spring = str(springs[index])
			_turns = 0
			if _ends.size() >= 2:
				_put()
		return
	length_choice = index - 1
	if index == 0:
		_length_kept = false
	if stage == "shaping":
		_put()


## The bands the library has, and the springs and shocks.
func _band_choices() -> Array:
	return Bands.BANDS.keys().filter(func(id: String) -> bool: return library.parts.has(id))


func _spring_choices() -> Array:
	return (Bands.SHOCKS.keys() + Bands.SPRINGS.keys()).filter(func(id: String) -> bool:
		return library.parts.has(id))


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
	_rounds.clear()
	_turns = 0
	_depth = -1
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
	if _is_band():
		_length_picker.add_item("The band that fits")
		var bands: Array = _band_choices()
		for band: String in bands:
			_length_picker.add_item("%s — %.0f LDU round" % [Flex.item_name(kind, library, band),
				Bands.natural_length(band)])
		_length_picker.select(bands.find(_band) + 1)
		return
	if _is_spring():
		var springs: Array = _spring_choices()
		for part: String in springs:
			_length_picker.add_item(Flex.item_name(kind, library, part))
		_length_picker.select(maxi(springs.find(_spring), 0))
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
