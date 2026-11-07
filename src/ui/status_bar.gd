## The line along the foot of the window.
##
## On the left, what just happened — or, when nothing has, what the tool
## in use does. On the right, while a part is in hand, where it goes if put
## down now, in studs and plates, as LeoCAD's says where its preview stands;
## then the model: how many parts and whether it stands up, what it weighs,
## how big it is (ModelSize: studs and plates, and centimetres), how many are
## selected and,
## while some are, how big they are; what a part snaps to and how far a turn
## goes, and how big a stud is on screen. The counts were a pill over
## the top of the model and the messages a line in the bar beside the
## buttons; every other program keeps both down here.
class_name StatusBar
extends PanelContainer

var shell: Shell

## What the model bar says (ModelBar.say): written there, shown here.
var message: Label
## The parts count and the stability, written by the app (main.gd).
var counts: Label
## What the model weighs, after its counts as one line with them ("61 bricks
## · stands up · 52 g"): the model as it is in this frame (ModelSize), every
## part in it, those on their way too. It was the stability check's sum, made
## at most once a second on a worker, so for a second after each change it
## was an earlier model's: the walk's eight 1 x 4s read 8 g just built, 13 g
## with the next part in hand, 12 g after one was turned and put back, then
## 13 g again (docs/APP_UX6.md, weighsure).
var _weight: Label
## The " · " before it.
var _weight_join: Label
## The world's generation it was said for: while a model is laid, the last
## weight said of it stays; a model just opened says none until it is down.
var _weighed_in: int = -1
var _hint: Label
## Where the part in hand goes, while one is (place_words).
var _place: Label
## Beside a line naming a file just written for the person (SaveTo): the
## file manager open on it.
var show_folder: Button
var _selected: Label
## How big the model is, after its counts; while parts are selected, how big
## they are, after "3 selected" (ModelSize).
var _size: Label
## What the size was worked out for: the model's revision and the selection.
var _size_key: Array = []
## How many times the selection changed, heard from the builder.
var _selection_moves: int = 0
var _hears_selection: bool = false
var _settings: Label
var _zoom: Label
var _looked_at: int = 0
## What the app is busy with, when it is: Working, in place of the line on
## the left while it lasts.
var working: Working
## Only the work, and only while there is some: the shared model's viewer,
## which hides the builder's bar but still has slow things to say.
var work_only: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.97)
	backing.border_color = Color(1, 1, 1, 0.08)
	backing.border_width_top = 1
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 3
	backing.content_margin_bottom = 4
	add_theme_stylebox_override("panel", backing)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	# One line on the left for both: what was just said, in full white, or
	# the tool's hint, dimmed, when nothing has been. The bar writes into
	# ``message``, which is held here and never drawn itself.
	message = Label.new()
	message.visible = false
	add_child(message)
	working = Working.new()
	working.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(working)
	_hint = _label(row, 1.0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.custom_minimum_size = Vector2(80, 0)
	# A live region: what the app says here is read out as it is said, by a
	# screen reader that is running, without the keys leaving the model.
	_hint.accessibility_name = "Status"
	_hint.accessibility_live = AccessibilityServer.LIVE_POLITE
	show_folder = Button.new()
	show_folder.text = "Show in folder"
	show_folder.tooltip_text = "Open the folder the file was saved in"
	show_folder.focus_mode = Control.FOCUS_NONE
	show_folder.visible = false
	show_folder.add_theme_font_size_override("font_size", 11)
	# As Working's Cancel, the bar's other button.
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(1, 1, 1, {"normal": 0.08, "hover": 0.16, "pressed": 0.24}[state])
		face.border_color = Color(1, 1, 1, 0.14)
		face.set_border_width_all(1)
		face.set_corner_radius_all(4)
		face.content_margin_left = 8
		face.content_margin_right = 8
		face.content_margin_top = 0
		face.content_margin_bottom = 0
		show_folder.add_theme_stylebox_override(state, face)
	show_folder.pressed.connect(func() -> void: SaveTo.show_in_folder(SaveTo.shown))
	row.add_child(show_folder)
	_place = _cell(row, "Where the part in hand goes if put down now: studs across (x) and back (z) "
		+ "from the middle of the floor, and plates up from the ground")
	_show_place("")
	counts = _cell(row, "How many parts the model has, and whether it would stand up as built")
	# Part of the counts' field: no line between, the join drawn as the
	# counts' own are.
	_weight_join = _label(row, 0.82)
	_weight_join.text = " · "
	_weight_join.visible = false
	_weight = _label(row, 0.82)
	_weight.tooltip_text = "What the model weighs, each part by its shape: within about 6% of " \
		+ "real bricks on a scale. The baseplate is left out"
	_weight.mouse_filter = Control.MOUSE_FILTER_PASS
	_weight.visible = false
	_size = _cell(row, "How big the model is, or the parts selected: studs across and deep, "
		+ "plates high without the studs on top, and centimetres each way with them")
	_selected = _cell(row, "How many parts are selected")
	_settings = _cell(row, "What a part snaps to, and how far a turn goes: both on the toolbar")
	_zoom = _cell(row, "How big one stud is on the screen at the middle of the view")


func _label(row: Container, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9 * alpha))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


## For the shared model's viewer: nothing but the work, and only while
## there is some.
func only_the_work() -> void:
	work_only = true
	for label: Label in [_place, counts, _size, _selected, _settings, _zoom]:
		label.visible = false
		(label.get_meta("line") as Control).visible = false
	_weight.visible = false
	_weight_join.visible = false
	visible = Working.is_busy()


## A field on the right, with a line before it and a tooltip saying what
## it is.
func _cell(row: Container, says: String) -> Label:
	var line := VSeparator.new()
	line.add_theme_constant_override("separation", 16)
	line.modulate = Color(1, 1, 1, 0.4)
	row.add_child(line)
	var label: Label = _label(row, 0.82)
	label.tooltip_text = says
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.set_meta("line", line)
	return label


## When the hint shown first differed from the one wanted, in microseconds.
var _hint_asked_us: int = -1


func _process(_delta: float) -> void:
	if shell == null:
		return
	# While something is being worked on, that is what the left says.
	var busy: bool = Working.is_busy()
	if _hint.visible == busy:
		_hint.visible = not busy
	if work_only:
		if visible != busy:
			visible = busy
		return
	# The line on the left at once, every frame: what was said, or the hint.
	var said: String = message.text
	# Or, while Check stability's marks are on the floor, its readout; or,
	# while View, Stress is on, what the part pointed at carries.
	if said.is_empty():
		said = shell.balance_line()
	if said.is_empty() and shell.stress != null:
		said = shell.stress.line()
	# Help, What's This?: the next click is a question.
	if WhatsThis.is_asking():
		said = WhatsThis.ASKING
	var line: String = said if not said.is_empty() else shell.verbs.hint()
	var showable: bool = not busy and SaveTo.names(said)
	if show_folder.visible != showable:
		show_folder.visible = showable
	# The hint says what a click does on what the pointer is over, so a step
	# onto a part or off one changes it: drawn at the pace the device draws,
	# as the outline round that part is (PointerPace). Anything said, at once.
	if _hint.text != line:
		if _hint_asked_us < 0:
			_hint_asked_us = Time.get_ticks_usec()
		if not said.is_empty() or PointerPace.now((Time.get_ticks_usec() - _hint_asked_us) / 1000.0):
			_hint.text = line
			_hint.tooltip_text = said
			_hint.modulate.a = 1.0 if not said.is_empty() else 0.62
			_hint_asked_us = -1
	else:
		_hint_asked_us = -1
	# Where the part in hand goes, as it moves: every frame, as the ghost is.
	_show_place(place_words())
	# How big, and how many selected, in the frame the model or the
	# selection changed: the two stand side by side and say one selection.
	var count: int = shell.builder.selection.size()
	_selected.text = "%d selected" % count if count > 0 else "nothing selected"
	_show_weight()
	_show_size()
	var now: int = Time.get_ticks_msec()
	if now - _looked_at >= 150:
		_looked_at = now
		var snap: String = {"stud": "stud", "half": "½ stud", "half_plate": "½ plate",
			"free": "free"}.get(shell.verbs.snap, shell.verbs.snap)
		_settings.text = "snap %s · turn %d°" % [snap, roundi(shell.verbs.turn_step)]
		_zoom.text = "1 stud ≈ %d px" % roundi(_stud_on_screen())
	_fit()


## Room the line on the left keeps, px, before a field on the right goes.
const HINT_ROOM := 160.0


## The fields on the right fitted to the bar, every frame, as what they say
## changes: where they would not all fit beside the line on the left, the
## least wanted goes first (how big a stud is on screen, then the snap and
## turn, then the size), so none runs past the window's edge. On a narrow
## screen the first two go whatever room is left, as before.
func _fit() -> void:
	var window: float = get_viewport().get_visible_rect().size.x
	var narrow: bool = window < 900.0
	# The bar's own width, or the window's past where it starts when the
	# fields have already pushed the bar wider than that.
	var room: float = minf(size.x, window - global_position.x)
	var shown: Dictionary = {_zoom: not narrow, _settings: not narrow,
		_size: not _size.text.is_empty()}
	var needed: float = get_theme_stylebox("panel").get_minimum_size().x + HINT_ROOM
	for label: Label in [_place, counts, _size, _selected, _settings, _zoom]:
		if bool(shown.get(label, label.visible)):
			needed += _width(label)
	if _weight.visible:
		needed += _weight_join.get_minimum_size().x + _weight.get_minimum_size().x
	if show_folder.visible:
		needed += show_folder.get_combined_minimum_size().x
	for least: Label in [_zoom, _settings, _size]:
		if needed > room and bool(shown[least]):
			shown[least] = false
			needed -= _width(least)
	for label: Label in shown:
		if label.visible != bool(shown[label]):
			label.visible = shown[label]
			(label.get_meta("line") as Control).visible = shown[label]


## A field's width and the line before it.
static func _width(label: Label) -> float:
	return label.get_minimum_size().x + (label.get_meta("line") as Control).get_minimum_size().x


## What the model weighs, beside its counts, every frame: worked out again
## in the frame the model changes (ModelSize.of_model keeps it for the
## revision), the parts on their way in. Not while a model is laid, part of
## it down: the weight said before stays, and a model just opened says none
## until it is all down, so its first number is its weight.
func _show_weight() -> void:
	var world: BrickWorld = shell.world
	var words: String = ""
	if world != null and shell.library != null and not counts.text.is_empty():
		if world.is_being_laid():
			if world.generation() == _weighed_in:
				return
		else:
			var store: ModelStore = shell.store
			var model: ModelSize = ModelSize.of_model(world, shell.library,
				store.scenery if store != null else {}, ModelSize.coming(store))
			if not model.is_empty():
				words = model.grams_words()
				_weighed_in = world.generation()
	if _weight.text != words:
		_weight.text = words
	var shown: bool = not words.is_empty() and counts.visible
	if _weight.visible != shown:
		_weight.visible = shown
		_weight_join.visible = shown


## The model's size beside its counts, or the selection's beside "3
## selected": worked out again in the frame either changes, and only then.
func _show_size() -> void:
	var builder: Builder = shell.builder
	var world: BrickWorld = shell.world
	if builder == null or world == null or shell.library == null:
		return
	if not _hears_selection:
		_hears_selection = true
		builder.selection_changed.connect(func(_count: int) -> void: _selection_moves += 1)
	var scenery: Dictionary = shell.store.scenery if shell.store != null else {}
	var picked: bool = not builder.selection.is_empty()
	var key: Array = [world.get_instance_id(), world.revision, world.generation(), scenery.size(),
		_selection_moves if picked else -1, builder.selection.size(),
		ModelSize.coming(shell.store).size()]
	if key == _size_key:
		return
	_size_key = key
	var measured: ModelSize
	if picked:
		var bricks: Array = []
		for brick_id: int in builder.selection:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			if brick != null:
				bricks.append(brick)
		measured = ModelSize.of_bricks(bricks, shell.library)
	else:
		measured = ModelSize.of_model(world, shell.library, scenery, ModelSize.coming(shell.store))
	_size.text = measured.words()
	# Beside what it measures: the model's after its counts and weight.
	var after: Label = _selected if picked else _weight
	var row: Node = _size.get_parent()
	var line: Control = _size.get_meta("line")
	if line.get_index() != after.get_index() + 1:
		row.remove_child(line)
		row.remove_child(_size)
		var at: int = after.get_index() + 1
		row.add_child(line)
		row.move_child(line, at)
		row.add_child(_size)
		row.move_child(_size, at + 1)


## Where the part in hand goes if put down now: "x 2½, z −1 studs · 3 plates
## up", its middle across and back from the middle of the floor, to the
## half stud, and its foot over the ground, to the quarter plate (a 2 LDU
## cell); a finer snap's places to the hundredth, the line's every number
## then (amounts). "" with nothing in hand, or in hand and aimed nowhere.
func place_words() -> String:
	var box: Variant = landing()
	if box == null:
		return ""
	var at: AABB = box
	var middle: Vector3 = at.get_center()
	var up: float = at.position.y / BrickLattice.PLATE
	var said: PackedStringArray = amounts([middle.x / BrickLattice.STUD,
		middle.z / BrickLattice.STUD, absf(up)])
	var height: String = "on the ground"
	if absf(up) >= 0.005:
		var plates: String = said[2]
		height = ("1 plate up" if plates == "1" else "%s plates up" % plates) if up > 0.0 \
			else ("1 plate down" if plates == "1" else "%s plates down" % plates)
	return "x %s, z %s studs · %s" % [said[0], said[1], height]


## Where what is in hand lands, in LDU: the box round it, its foot where
## the part's lowest point is; null with nothing in hand or aimed nowhere.
## Several parts in hand (Carry): the box round them all, worked out once
## for what is held and moved with the group's frame.
func landing() -> Variant:
	var builder: Builder = shell.builder if shell != null else null
	if builder == null:
		return null
	if builder.is_carrying():
		var carry: Carry = builder.carrying
		if not carry.is_aimed():
			return null
		var held: Variant = _carried_bounds(carry)
		if held == null:
			return null
		return Transform3D(Basis(Vector3.UP, carry.turns * PI * 0.5), carry.pivot()) * (held as AABB)
	if builder.ghost_place() == null:
		return null
	var part: Lbm.PartMesh = shell.library.mesh_for(builder.held_part)
	if part == null:
		return null
	var pose: Transform3D = builder.ghost_transform()
	var box: AABB = pose * part.bounds
	var low: float = part.lowest_at(pose)
	return AABB(Vector3(box.position.x, low, box.position.z),
		Vector3(box.size.x, box.end.y - low, box.size.z))


## The parts held, in the group's own frame: one box, kept while the same
## parts are in hand.
var _carried: Array = []
var _carried_box: AABB = AABB()


func _carried_bounds(carry: Carry) -> Variant:
	if is_same(carry.items, _carried) and not _carried.is_empty():
		return _carried_box
	var box := AABB()
	var first: bool = true
	for item: Dictionary in carry.items:
		var part: Lbm.PartMesh = shell.library.mesh_for(str(item["part"]))
		# A part still on its way has no shape yet: asked again next frame.
		if part == null:
			return null
		var here: AABB = (item["at"] as Transform3D) * part.bounds
		box = here if first else box.merge(here)
		first = false
	if first:
		return null
	_carried = carry.items
	_carried_box = box
	return box


## A number of studs or plates as the bar writes it: whole, or with ¼, ½
## or ¾, or to the hundredth; "−" before one below.
static func amount(value: float) -> String:
	return amounts([value])[0]


## Numbers of studs or plates said on one line, in one style: in quarters
## ("4½ × 8 studs") when every one is a whole quarter, and otherwise each to
## the hundredth ("4.5 × 10.8 studs, 15 plates high"). Each said alone, the
## car's size put a fraction beside a decimal: "4½ × 10.8 studs"
## (docs/APP_UX6.md, weighsure). "−" before one below.
static func amounts(values: Array) -> PackedStringArray:
	var quarters: bool = true
	for value: float in values:
		var size: float = absf(value)
		var part: float = size - floori(size + 0.005)
		quarters = quarters and (part < 0.005 or absf(part - 0.25) < 0.005
			or absf(part - 0.5) < 0.005 or absf(part - 0.75) < 0.005)
	var out := PackedStringArray()
	for value: float in values:
		var sign: String = "−" if value <= -0.005 else ""
		var size: float = absf(value)
		var whole: int = floori(size + 0.005)
		var part: float = size - whole
		if not quarters:
			out.append(sign + String.num(size, 2))
		elif part < 0.005:
			out.append(sign + str(whole))
		else:
			var mark: String = "¼" if part < 0.375 else ("½" if part < 0.625 else "¾")
			out.append(sign + ("" if whole == 0 else str(whole)) + mark)
	return out


func _show_place(words: String) -> void:
	var shown: bool = not words.is_empty() and not work_only
	if _place.text != words:
		_place.text = words
	if _place.visible != shown:
		_place.visible = shown
		(_place.get_meta("line") as Control).visible = shown


## A stud's width in interface units, at the distance the view turns about.
func _stud_on_screen() -> float:
	var camera: CadCamera = shell.camera
	if camera == null:
		return 0.0
	var per: float = camera._ldu_per_pixel()
	return BrickLattice.STUD / per if per > 0.0 else 0.0


## The fields, for a check to read.
func fields() -> Dictionary:
	return {"message": message.text, "hint": shell.verbs.hint(), "line": _hint.text,
		"place": _place.text if _place.visible else "",
		# As read: the weight is one line with them.
		"counts": counts.text + (_weight_join.text + _weight.text if _weight.visible else ""),
		"weight": _weight.text if _weight.visible else "",
		"size": _size.text if _size.visible else "",
		"size_after": "selected" if _size.get_index() > _selected.get_index() else "counts",
		"selected": _selected.text, "settings": _settings.text,
		"zoom": _zoom.text, "show_folder": show_folder.visible}
