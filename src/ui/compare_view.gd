## File, Versions…'s Compare, and File, Compare with…: the model on the
## baseplate drawn against one of its saves. What was added since is green,
## what was taken away a red ghost where it stood, what was moved or turned
## amber with a faint ghost where it was, what was painted another colour
## violet, and everything else faded. Its panel, over the model's right edge
## under the view cube where View, Stress's is, counts each kind and steps
## through the changes one by one, the view framing each.
##
## Studio and Mecabricks keep a model's saves and have nothing that says
## what changed between two; the gallery says it in words, by part and step
## (api/_versions.js). The matching is ModelDiff's: the fewest changes, so a
## part moved a stud is one part moved.
##
## Comparing changes nothing. The drawing is BrickWorld's stress layer, the
## picture alone (a brick keeps its paint, the history no step, the save its
## state), and View, Stress is turned off meanwhile; the ghosts are a world
## of their own drawn over the model, which nothing that reads the model
## sees. Close or Esc puts the view back as it was, Stress too. Inside a
## sub-assembly being edited only that is compared, and the panel says so.
## An edit while it is open is compared again a moment later; another
## model opened, or a new one, closes it.
class_name CompareView
extends PanelContainer

const ADDED := BalanceMark.GOOD
const REMOVED := BalanceMark.TIPS
const MOVED := BalanceMark.CLOSE
const RECOLOURED := Color(0.72, 0.52, 1.0)
const FADED := StressPanel.SAFE
## The colours the ghosts are drawn in: a part taken away as red glass, and
## where a moved one stood as an amber x-ray ghost, fainter.
const REMOVED_GHOST := 36    # Trans-Red
const MOVED_GHOST := 191     # Bright Light Orange, drawn see-through
const WIDE := 300.0
## How long after an edit the model is compared again, ms.
const AGAIN_AFTER_MS := 300

var world: BrickWorld
var library: PartLibrary
var store: ModelStore
var camera: CadCamera
var assemblies: Assemblies
var stress: StressView
var say: Callable = func(_line: String) -> void: pass

## The comparison drawn, the save it is with, and the change stepped to (-1
## for none yet).
var diff: ModelDiff = null
var version: ModelVersions.Version = null
var chosen: int = -1
## The sub-assembly compared inside, "" for the whole model.
var inside: String = ""

## The save's parts (ModelDiff.Part), read once for each save and inside.
var _was: Array = []
## As the view was before: the camera's aim and View, Stress.
var _aim: Dictionary = {}
var _stress_was: bool = false
## The ghosts' own world, and the ghost drawn for each change by its index.
var _ghosts: BrickWorld = null
var _ghost_of: Dictionary = {}
## The model's revision compared, and when an edit is to be compared again.
var _revision: int = -1
var _again_at: int = 0
## How many times the model has been compared since it opened, for a probe.
var compared: int = 0

var _close: Button
var _with: Label
var _inside: Label
var _counts: Dictionary = {}
var _none: Label
var _what: Label
var _previous: Button
var _next: Button
var _at: Label
var _chips: Dictionary = {}

signal closed


func _ready() -> void:
	visible = false
	set_process(false)
	_build()


func is_open() -> bool:
	return visible


## Compare the model on the baseplate with [param saved], one of its saves.
## False, with the reason said, when that save cannot be read.
func open_with(saved: ModelVersions.Version) -> bool:
	var text: String = ModelVersions.read(saved.path)
	if text.is_empty():
		say.call("could not read that save of %s" % store.title)
		return false
	if not visible:
		_aim = camera.aim() if camera != null else {}
		_stress_was = stress != null and stress.on
		if _stress_was:
			stress.set_on(false)
	version = saved
	compared = 0
	inside = assemblies.entered if assemblies != null else ""
	_was = ModelDiff.parts_of_text(text, library, inside)
	chosen = -1
	visible = true
	_compare()
	set_process(true)
	say.call("Compared with the save of %s: %s" % [saved.when(), diff.summary()])
	return true


## Stop comparing: every part drawn as it is, the ghosts gone, View, Stress
## back if it was on, and with [param restore_view] the camera where it was
## (not when another model has replaced this one).
func close(restore_view: bool = true) -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	world.set_stress(false)
	_drop_ghosts()
	if _stress_was and stress != null:
		stress.set_on(true)
	_stress_was = false
	if restore_view and camera != null and not _aim.is_empty():
		camera.aim_at(_aim)
	diff = null
	version = null
	_was = []
	chosen = -1
	closed.emit()


## Step to the next change ([param by] 1) or the one before (-1), from the
## first when none is chosen yet; the view framed on it.
func step(by: int) -> void:
	if diff == null or diff.changes.is_empty():
		return
	_choose(0 if chosen < 0 else posmod(chosen + by, diff.changes.size()))


func _process(_delta: float) -> void:
	if diff == null or store.laying:
		return
	var now: int = Time.get_ticks_msec()
	if world.revision != _revision:
		_revision = world.revision
		_again_at = now + AGAIN_AFTER_MS
	elif _again_at > 0 and now >= _again_at:
		_again_at = 0
		var was: ModelDiff.Change = _chosen_change()
		_compare()
		# The same change stepped to again, where it is still one.
		if was != null:
			for n: int in diff.changes.size():
				if _same_change(diff.changes[n], was):
					_choose(n, false)


## Esc closes it, as it closes every mode, before anything under it hears it.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or key.keycode != KEY_ESCAPE or not key.pressed or key.echo:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	close()
	get_viewport().set_input_as_handled()


func _compare() -> void:
	var now: Array = ModelDiff.parts_of_world(world, store.scenery, store.lift(), store.awaited,
		inside)
	diff = ModelDiff.between(_was, now)
	_revision = world.revision
	compared += 1
	_draw()
	_fill()


## Each change drawn in its colour, everything else faded, and the ghosts.
func _draw() -> void:
	var tints: Dictionary = {}
	for change: ModelDiff.Change in diff.changes:
		if change.now != null and change.now.id != 0:
			tints[change.now.id] = colour_of(change.kind)
	world.set_stress(true, tints)
	_drop_ghosts()
	_ghosts = BrickWorld.new()
	_ghosts.library = library
	_ghosts.keeps_history = false
	_ghosts.name = "compare_ghosts"
	world.add_child(_ghosts)
	var lift := Transform3D(Basis.IDENTITY, store.lift())
	var see_through: Dictionary = {}
	for n: int in diff.changes.size():
		var change: ModelDiff.Change = diff.changes[n]
		if change.kind != ModelDiff.REMOVED and change.kind != ModelDiff.MOVED:
			continue
		var ghost: int = _ghosts.add_brick(change.was.part_id,
			REMOVED_GHOST if change.kind == ModelDiff.REMOVED else MOVED_GHOST,
			lift * change.was.at)
		if ghost == 0:
			continue
		_ghost_of[n] = ghost
		if change.kind == ModelDiff.MOVED:
			see_through[ghost] = true
	_ghosts.set_xray(see_through)


func _drop_ghosts() -> void:
	if _ghosts != null:
		# Out of the tree at once, so the next is drawn alone and by its name.
		if _ghosts.get_parent() != null:
			_ghosts.get_parent().remove_child(_ghosts)
		_ghosts.queue_free()
		_ghosts = null
	_ghost_of.clear()


## The ghosts' world while it is open, for a probe; null when closed.
func ghosts() -> BrickWorld:
	return _ghosts


## The colour a change of [param kind] is drawn in.
static func colour_of(kind: String) -> Color:
	match kind:
		ModelDiff.ADDED:
			return ADDED
		ModelDiff.REMOVED:
			return REMOVED
		ModelDiff.MOVED:
			return MOVED
	return RECOLOURED


func _chosen_change() -> ModelDiff.Change:
	if diff == null or chosen < 0 or chosen >= diff.changes.size():
		return null
	return diff.changes[chosen]


static func _same_change(a: ModelDiff.Change, b: ModelDiff.Change) -> bool:
	if a.kind != b.kind:
		return false
	if a.now != null and b.now != null and a.now.id != 0:
		return a.now.id == b.now.id
	return a.was != null and b.was != null and a.was.part_id == b.was.part_id \
		and a.was.at.origin.is_equal_approx(b.was.at.origin)


func _choose(n: int, framed: bool = true) -> void:
	chosen = n
	_say_chosen()
	if framed:
		var box: AABB = bounds_of(diff.changes[n])
		if camera != null and box.size != Vector3.ZERO:
			camera.frame(box.grow(8.0), 1.6)


## Where a change is, in the world: the part now, where it was, or both.
func bounds_of(change: ModelDiff.Change) -> AABB:
	var box := AABB()
	var lift := Transform3D(Basis.IDENTITY, store.lift())
	for part: ModelDiff.Part in [change.now, change.was]:
		if part == null:
			continue
		var mesh: Lbm.PartMesh = library.mesh_for(part.part_id)
		if mesh == null:
			continue
		var at: Transform3D = lift * part.at
		if part == change.now and part.id != 0 and world.get_brick(part.id) != null:
			at = world.drawn_at(world.get_brick(part.id))
		var here: AABB = (at * mesh.bounds).abs()
		box = here if box.size == Vector3.ZERO else box.merge(here)
	return box


# -- what it says --------------------------------------------------------------


func _fill() -> void:
	var counted: Dictionary = diff.counts()
	_with.text = "With the save of %s, %d part%s; the model now has %d." % [version.when(),
		version.parts, "" if version.parts == 1 else "s", diff.parts_now]
	_inside.visible = not inside.is_empty()
	_inside.text = ("Inside %s only, the sub-assembly being edited: leave it to compare the "
		+ "whole model.") % Assemblies.label(inside) if not inside.is_empty() else ""
	for kind: String in ModelDiff.KINDS:
		(_counts[kind] as Label).text = _count_words(kind, int(counted[kind]))
	_none.visible = diff.changes.is_empty()
	if chosen >= diff.changes.size():
		chosen = -1
	_say_chosen()


static func _count_words(kind: String, n: int) -> String:
	match kind:
		ModelDiff.ADDED:
			return "%d added" % n
		ModelDiff.REMOVED:
			return "%d removed: a red ghost where %s" % [n, "it was" if n == 1 else "each was"]
		ModelDiff.MOVED:
			return "%d moved or turned: a faint ghost where %s" % [n,
				"it was" if n == 1 else "each was"]
	return "%d recoloured" % n


func _say_chosen() -> void:
	var count: int = diff.changes.size() if diff != null else 0
	_previous.disabled = count < 2
	_next.disabled = count == 0
	var change: ModelDiff.Change = _chosen_change()
	_at.text = "%d of %d" % [chosen + 1, count] if change != null \
		else ("%d change%s" % [count, "" if count == 1 else "s"] if count > 0 else "")
	_what.visible = change != null
	_what.text = words(change) if change != null else ""


## What a change is, as the panel and a session say it: "Moved 2 studs:
## Brick 1 x 2 in Red", "Recoloured Red to Blue: Brick 2 x 4".
func words(change: ModelDiff.Change) -> String:
	return change_words(change, library)


static func change_words(change: ModelDiff.Change, library: PartLibrary) -> String:
	var part: ModelDiff.Part = change.now if change.now != null else change.was
	var name: String = StressView._named(library, part.part_id)
	match change.kind:
		ModelDiff.ADDED:
			return "Added: %s in %s" % [name, _colour(library, part.colour)]
		ModelDiff.REMOVED:
			return "Removed: %s in %s" % [name, _colour(library, part.colour)]
		ModelDiff.MOVED:
			return "%s: %s in %s" % [moved_words(change), name, _colour(library, part.colour)]
	return "Recoloured %s to %s: %s" % [_colour(library, change.was.colour),
		_colour(library, change.now.colour), name]


## "Moved 2 studs", "Turned 90°", "Moved 1 plate and turned 180°".
static func moved_words(change: ModelDiff.Change) -> String:
	var said_now := PackedStringArray()
	if change.by >= ModelDiff.NEAR:
		var step: Vector3 = change.now.at.origin - change.was.at.origin
		said_now.append("Moved " + _distance(step))
	if change.turned:
		var turn: Basis = change.now.at.basis * change.was.at.basis.inverse()
		var angle: float = rad_to_deg(turn.get_rotation_quaternion().get_angle())
		said_now.append(("turned %d°" if not said_now.is_empty() else "Turned %d°") % roundi(angle))
	return " and ".join(said_now) if not said_now.is_empty() else "Moved"


## A step in studs and plates as a builder counts it: "2 studs", "3
## plates", "1 stud and 1 plate"; in LDU when it is neither.
static func _distance(step: Vector3) -> String:
	var across: float = Vector2(step.x, step.z).length() / 20.0
	var up: float = absf(step.y) / 8.0
	var said_now := PackedStringArray()
	for pair: Array in [[across, "stud"], [up, "plate"]]:
		var n: float = pair[0]
		if n < 0.05:
			continue
		var whole: bool = is_equal_approx(n, roundf(n))
		said_now.append("%s %s%s" % [str(roundi(n)) if whole else "%.1f" % n, pair[1],
			"" if whole and roundi(n) == 1 else "s"])
	return " and ".join(said_now) if not said_now.is_empty() else "%.1f LDU" % step.length()


static func _colour(library: PartLibrary, code: int) -> String:
	return library.color(code).name.replace("_", " ") if library != null else str(code)


## What the comparison drawn is, for a probe: as [method said_of] says it.
func said(most: int = 40) -> String:
	return said_of(diff, version, inside, library, most) if diff != null else ""


## What [param compared] is, for a session (open_model versions=true
## version=N): the counts, then every change, at most [param most], each
## part on the baseplate by its number.
static func said_of(compared: ModelDiff, saved: ModelVersions.Version, within: String,
		library: PartLibrary, most: int = 40) -> String:
	var lines := PackedStringArray()
	lines.append("Since the save of %s (%d parts; %d now): %s." % [saved.when(), saved.parts,
		compared.parts_now, compared.summary()])
	if not within.is_empty():
		lines.append("Inside %s only, the sub-assembly being edited." % Assemblies.label(within))
	for n: int in mini(compared.changes.size(), most):
		var change: ModelDiff.Change = compared.changes[n]
		var id: int = change.now.id if change.now != null else 0
		lines.append("  %s%s" % [change_words(change, library), " (#%d)" % id if id > 0 else ""])
	if compared.changes.size() > most:
		lines.append("  …and %d more." % (compared.changes.size() - most))
	return "\n".join(lines)


# -- the panel -----------------------------------------------------------------


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDE, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Compare"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button(header, "Close", func() -> void: close(),
		"Stop comparing: every part as it was, and the view too (Esc)")
	_with = _words(column, 12, 0.8)
	_inside = _words(column, 12, 1.0)
	_inside.add_theme_color_override("font_color", MOVED.lightened(0.2))
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 3)
	column.add_child(legend)
	for kind: String in ModelDiff.KINDS:
		_counts[kind] = _legend_row(legend, colour_of(kind), 13, 1.0)
	_legend_row(legend, FADED, 11, 0.7).text = "Unchanged: faded"
	_none = _words(column, 12, 0.9)
	_none.text = "Nothing has changed since that save."
	column.add_child(HSeparator.new())
	_what = _words(column, 12, 0.95)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 8)
	column.add_child(steps)
	_previous = _button(steps, "Previous", func() -> void: step(-1),
		"The change before this one, in view")
	_next = _button(steps, "Next", func() -> void: step(1), "The next change, in view")
	_at = Label.new()
	_at.add_theme_font_size_override("font_size", 11)
	_at.modulate = Color(1, 1, 1, 0.65)
	_at.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_at.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	steps.add_child(_at)


func _legend_row(into: Control, colour: Color, size: int, alpha: float) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	into.add_child(row)
	var chip := TextureRect.new()
	chip.texture = _chip(colour)
	chip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(chip)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDE - 46.0, 0)
	row.add_child(label)
	return label


## A square of [param colour], as the legend shows it.
func _chip(colour: Color) -> Texture2D:
	var key: String = colour.to_html()
	if not _chips.has(key):
		var image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
		image.fill(colour)
		_chips[key] = ImageTexture.create_from_image(image)
	return _chips[key]


func _words(into: Control, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDE - 28.0, 0)
	label.modulate = Color(1, 1, 1, alpha)
	into.add_child(label)
	return label


func _button(into: Control, words_on_it: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words_on_it
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	into.add_child(button)
	return button


## What it shows, for a probe to read as a person would.
func fields() -> Dictionary:
	var counts: Dictionary = {}
	for kind: String in _counts:
		counts[kind] = (_counts[kind] as Label).text
	return {"open": visible, "with": _with.text, "inside": _inside.text if _inside.visible else "",
		"counts": counts, "none": _none.visible, "what": _what.text if _what.visible else "",
		"at": _at.text}


## Where each control is, for a probe or a browser test to press.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"compare_close": _close, "compare_previous": _previous, "compare_next": _next}
