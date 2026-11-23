## File, Versions…'s Compare, and File, Compare, Compare with…: the model on the
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
## Its second mode, File, Compare, Compare two sets or models… (APP_UX6 #7,
## comparesets), compares the parts of any two of a set, a saved model and the
## model open now, as Rebrickable's set compare does: the parts in both and in
## only one, by part and colour, and the list to buy to build the second from
## the first, which goes to the parts list's shops. The sums are
## PartsCompare's; the panel is then a sheet over the model, as the parts list
## is, and draws nothing on it.
##
## Its third, File, Compare, Compare with the set… (setcheck, APP_UX10 #4),
## checks the model against a real set's own model from the library
## (SetCheck): each part taken away, added, swapped, recoloured, moved or put
## in another sub-model, listed under the set's own step it is in, with where
## it is in the model (its sub-model and the line of its file). A row clicked
## selects that part and frames it; a set the model is says it matches. What
## changed is drawn on the model as a save's comparison draws it.
##
## Its fourth (suggestedit, PLAN row 5) is a change a remixer sent back from
## their remix, opened from the designer's notification: drawn on their model
## as they last published it, and taken whole or a change at a time by their
## ticks (Main.open_suggestion).
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
	if visible and mode != SAVE:
		close()
	_show_mode(SAVE)
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
	if mode == PARTS:
		if thumbnails != null:
			thumbnails.watch(self, [])
		_asked += 1
		closed.emit()
		return
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
	checked = null
	suggestion = {}
	suggest_diff = null
	_suggest_ghosts.clear()
	taking = false
	chosen = -1
	# A check still on its way is dropped (_asked), so nothing waits on it.
	_asked += 1
	checking = false
	if _set_go != null:
		_set_go.disabled = false
	closed.emit()


## Step to the next change ([param by] 1) or the one before (-1), from the
## first when none is chosen yet; the view framed on it.
func step(by: int) -> void:
	if diff == null or diff.changes.is_empty():
		return
	_choose(0 if chosen < 0 else posmod(chosen + by, diff.changes.size()))


func _process(_delta: float) -> void:
	if mode == PARTS:
		_parts_pictures()
		return
	if mode == SET:
		_set_again()
		return
	if mode == SUGGEST:
		return
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
	var now: Array = ModelDiff.parts_of_world(world, store.scenery, store.lift(), store.awaited_now(),
		inside)
	diff = ModelDiff.between(_was, now)
	_revision = world.revision
	compared += 1
	_draw_changes()
	_fill()


## Each change drawn in its colour, everything else faded, and the ghosts.
## (Not _draw: the engine calls that on every redraw of the panel.)
func _draw_changes() -> void:
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
	_save_column = column
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


## What it shows, for a probe to read as a person would: in Parts, as
## [method parts_fields] reads it.
func fields() -> Dictionary:
	if mode == PARTS:
		return parts_fields()
	if mode == SET:
		return set_fields()
	if mode == SUGGEST:
		return suggest_fields()
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
	if mode == PARTS:
		return _parts_controls()
	if mode == SET:
		return _set_controls()
	if mode == SUGGEST:
		return _suggest_controls()
	return {"compare_close": _close, "compare_previous": _previous, "compare_next": _next}


# -- comparesets: two sets' or models' parts (APP_UX6 #7) ---------------------------

## Which the panel shows: one of the model's saves drawn on it ([constant
## SAVE]), or the parts of any two of a set, a saved model and the model open
## now ([constant PARTS]), a sheet over the model as the parts list is; or the
## model against a set's own ([constant SET]), or a change a remixer sent
## back ([constant SUGGEST]), each a side panel where the save's is.
const SAVE := "save"
const PARTS := "parts"
## The parts sheet's largest size; inset 14 px in a smaller model area.
const PARTS_SIZE := Vector2(780, 620)
## A row's height, its picture's side, as the parts list's.
const ROW := 30
## What each list is, by its tab.
const BOTH := 0
const ONLY_A := 1
const ONLY_B := 2

var mode: String = SAVE
## Set by Shell for the parts sheet: the set inventories (CollectionStore's),
## the parts' pictures, and the shops' writer for the list to buy
## (Exports.stock_list): shop, the list, its file's name -> what it wrote.
var inventories: SetInventories
var thumbnails: PartThumbnails
var write_list: Callable = func(_shop: String, _stock: Inventory, _named: String) -> String:
	return ""
## The comparison shown, null before one; its lists by tab (Inventory), the
## last of them the list to buy to build B from A.
var parts: PartsCompare = null
var lists: Array = []

var _save_column: VBoxContainer
var _parts_column: VBoxContainer = null
## Where Shell put the panel for a save, put back when one is compared again.
var _side_place: Dictionary = {}
var _parts_close: Button
var _swap: Button
var _go: Button
var _pick: Array[OptionButton] = []
var _number: Array[LineEdit] = []
## Each picker's rows by item index: [kind, path, name], null for a separator.
var _choices: Array = []
var _sides: Label
var _tabs: TabBar
var _list_scroll: ScrollContainer
var _list_rows: GridContainer
var _list_sight: ThumbTile.Sight
var _buy: Label
var _shops: Dictionary = {}
var _buy_note: Label
## Counts each comparison asked for, so a slower set lookup never replaces a
## newer one, nor fills a sheet closed meanwhile.
var _asked: int = 0
## Whether a comparison is being read, for a probe.
var comparing: bool = false


## File, Compare, Compare two sets or models…: the sheet, with what was compared last
## time, or a set to type for A and the model open now for B; compared at once
## when both are there.
func open_parts() -> void:
	if visible and mode != PARTS:
		close()
	_show_mode(PARTS)
	_fill_picks()
	_buy_note.visible = false
	comparing = false
	_go.disabled = false
	visible = true
	set_process(true)
	if thumbnails != null:
		_list_sight.forget()
	for n: int in 2:
		_number[n].visible = _kind(n) == PartsCompare.SET
	if _ready_to_compare():
		compare_parts()
		return
	for n: int in 2:
		if _number[n].visible and _number[n].text.strip_edges().is_empty():
			_number[n].grab_focus()
			break


## Compare what the two pickers name: the counts, each list by part and
## colour, and what to buy to build B from A.
func compare_parts() -> void:
	if not _ready_to_compare():
		_sides.text = "Choose A and B: a set by its number, a saved model or the model open now."
		return
	_asked += 1
	var asked: int = _asked
	comparing = true
	_go.disabled = true
	_sides.text = "Comparing…"
	var from: PartsCompare.Pile = await _side_of(0)
	var to: PartsCompare.Pile = await _side_of(1)
	# A newer comparison, or the sheet closed meanwhile: theirs now.
	if asked != _asked:
		return
	comparing = false
	_go.disabled = false
	for side: PartsCompare.Pile in [from, to]:
		if not side.ok():
			parts = null
			lists = []
			_sides.text = side.trouble.left(1).to_upper() + side.trouble.substr(1) + "."
			_fill_lists()
			return
	parts = PartsCompare.between(from, to)
	lists = [Inventory.of_counts(parts.both, library), Inventory.of_counts(parts.only_a, library),
		Inventory.of_counts(parts.only_b, library)]
	_fill_lists()
	say.call("Compared %s with %s: %s" % [from.short, to.short, parts.summary()])


## The list to buy to build B from A, written for [param shop] ("bricklink",
## "rebrickable" or "pickabrick") as the parts list's own buttons write the
## model's: what was written, said under the buttons too.
func buy_from(shop: String) -> String:
	if parts == null or lists.size() < 3 or (lists[ONLY_B] as Inventory).lots.is_empty():
		return ""
	var line: String = await write_list.call(shop, lists[ONLY_B], parts.file_name())
	_buy_note.text = line
	_buy_note.visible = not line.is_empty()
	return line


func _show_mode(which: String) -> void:
	if which == PARTS and _parts_column == null:
		_build_parts()
	if which == SET and _set_column == null:
		_build_set()
	if which == SUGGEST and _suggest_column == null:
		_build_suggest()
	if which != SAVE and _side_place.is_empty():
		_side_place = {"anchors": [anchor_left, anchor_top, anchor_right, anchor_bottom],
			"offsets": [offset_left, offset_top, offset_right, offset_bottom],
			"grow": [grow_horizontal, grow_vertical]}
	mode = which
	_save_column.visible = which == SAVE
	if _parts_column != null:
		_parts_column.visible = which == PARTS
	if _set_column != null:
		_set_column.visible = which == SET
	if _suggest_column != null:
		_suggest_column.visible = which == SUGGEST
	custom_minimum_size.x = SET_WIDE if which == SET else WIDE
	if which == PARTS:
		_place_parts()
	elif not _side_place.is_empty():
		_set_place(_side_place["anchors"], _side_place["offsets"])
		grow_horizontal = _side_place["grow"][0]
		grow_vertical = _side_place["grow"][1]
		if which == SET:
			# Wider, by its left edge: its right stays where the save's is.
			offset_left = offset_right - SET_WIDE
			_place_set()
		elif which == SUGGEST:
			_place_suggest()


## Each edge's anchor, then its offset. Left and top first, each pushing the
## edge opposite along when it passes it: an anchor kept from crossing its
## opposite stays where it was (the side panel's top at 0, under a centred
## sheet's bottom at 0.5, made the sheet as tall as half the model area and
## more).
func _set_place(anchors: Array, offsets: Array) -> void:
	for side: int in 4:
		set_anchor(side, float(anchors[side]), true, true)
	for side: int in 4:
		set_offset(side, float(offsets[side]))


## Centred over the model, as large as [constant PARTS_SIZE] where there is
## room and inset 14 px from its edges where there is not.
func _place_parts() -> void:
	var area: Vector2 = (get_parent() as Control).size if get_parent() is Control \
		else get_viewport_rect().size
	var room: Vector2 = (area - Vector2(28.0, 28.0)).max(Vector2(WIDE, 240.0))
	var wanted := Vector2(minf(PARTS_SIZE.x, room.x), minf(PARTS_SIZE.y, room.y))
	_set_place([0.5, 0.5, 0.5, 0.5], [-wanted.x / 2.0, -wanted.y / 2.0, wanted.x / 2.0,
		wanted.y / 2.0])
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	# A wrapping label is as tall as its words at the width it has, and before
	# its first layout it has none: one word a line, a sheet taller than the
	# window. Each is given the width it will have.
	var inside: float = wanted.x - get_theme_stylebox("panel").get_minimum_size().x
	_sides.custom_minimum_size.x = maxf(120.0, inside - _go.get_combined_minimum_size().x - 8.0)
	_buy.custom_minimum_size.x = inside
	_buy_note.custom_minimum_size.x = inside


func _build_parts() -> void:
	_parts_column = VBoxContainer.new()
	_parts_column.add_theme_constant_override("separation", 8)
	_parts_column.visible = false
	add_child(_parts_column)
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(func() -> void:
			if visible and mode == PARTS:
				_place_parts())
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_parts_column.add_child(header)
	var title := Label.new()
	title.text = "Compare two sets or models"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	header.add_child(title)
	_swap = _button(header, "Swap", _swap_sides,
		"A in B's place and B in A's: what to buy to build the other")
	_parts_close = _button(header, "Close", func() -> void: close(), "Stop comparing (Esc)")
	for n: int in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_parts_column.add_child(row)
		var letter := Label.new()
		letter.text = ["A", "B"][n]
		letter.custom_minimum_size = Vector2(14, 0)
		letter.add_theme_font_size_override("font_size", 13)
		row.add_child(letter)
		var pick := OptionButton.new()
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.clip_text = true
		pick.add_theme_font_size_override("font_size", 12)
		pick.tooltip_text = ["What you have: a set, a saved model or the model open now",
			"What you want to build: a set, a saved model or the model open now"][n]
		pick.item_selected.connect(func(_index: int) -> void: _picked(n))
		row.add_child(pick)
		var number := LineEdit.new()
		number.placeholder_text = "Set number, as 7140"
		number.custom_minimum_size = Vector2(150, 0)
		number.add_theme_font_size_override("font_size", 12)
		number.tooltip_text = "A set's number, as on its box: 7140 or 7140-1"
		number.text_submitted.connect(func(_text: String) -> void: compare_parts())
		row.add_child(number)
		_pick.append(pick)
		_number.append(number)
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 8)
	_parts_column.add_child(summary)
	_sides = Label.new()
	_sides.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sides.add_theme_font_size_override("font_size", 12)
	_sides.modulate = Color(1, 1, 1, 0.85)
	summary.add_child(_sides)
	_go = _button(summary, "Compare", compare_parts,
		"The parts in both, in only one, and what to buy to build B from A")
	_go.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tabs = TabBar.new()
	_tabs.clip_tabs = true
	_tabs.add_theme_font_size_override("font_size", 12)
	for words: String in ["In both", "Only in A", "Only in B"]:
		_tabs.add_tab(words)
	_tabs.tab_changed.connect(func(_tab: int) -> void: _show_list())
	_parts_column.add_child(_tabs)
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_parts_column.add_child(_list_scroll)
	_list_rows = GridContainer.new()
	_list_rows.columns = 1
	_list_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_rows.add_theme_constant_override("v_separation", 2)
	_list_scroll.add_child(_list_rows)
	_list_sight = ThumbTile.Sight.new(_list_scroll, _list_rows)
	_parts_column.add_child(HSeparator.new())
	_buy = Label.new()
	_buy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buy.add_theme_font_size_override("font_size", 12)
	_parts_column.add_child(_buy)
	# The parts list's three shops, as its own buttons offer the model's.
	var shops := HFlowContainer.new()
	shops.add_theme_constant_override("h_separation", 8)
	shops.add_theme_constant_override("v_separation", 6)
	_parts_column.add_child(shops)
	for shop: Array in [
			["bricklink", "BrickLink", "A BrickLink wanted list (.xml) of these, to upload under Wanted › Upload"],
			["rebrickable", "Rebrickable", "A Rebrickable parts list (.csv) of these, to import into a list of your own"],
			["pickabrick", "LEGO® Pick a Brick",
				"A list of LEGO® element numbers (.csv) of these, to upload at LEGO® Pick a Brick: the parts it has no number for are named"]]:
		var kind: String = shop[0]
		_shops[kind] = _button(shops, shop[1], func() -> void: await buy_from(kind), shop[2])
	_buy_note = _words(_parts_column, 12, 0.8)
	_buy_note.visible = false
	_fill_lists()


## Each picker's rows: the model open now, a set by its number, then the
## person's saved models and the examples. What each chose before is chosen
## again where it is still there; the first time, a set for A and the model
## open now for B (a set for both on an empty baseplate).
func _fill_picks() -> void:
	var was: Array = []
	for n: int in 2:
		var at: int = _pick[n].selected
		was.append(_choices[at] if at >= 0 and at < _choices.size() else null)
	_choices = []
	var words: Array = []
	var built: bool = world.brick_count() > store.scenery.size()
	var title: String = store.title if store.title != ModelStore.UNTITLED else ""
	_choices.append([PartsCompare.OPEN, "", title])
	words.append("The model open now" + (": " + title if not title.is_empty() else ""))
	_choices.append([PartsCompare.SET, "", ""])
	words.append("A set, by its number")
	var saved: Array[ModelStore.Entry] = store.list_saved()
	var examples: Array[ModelStore.Entry] = store.list_examples()
	for group: Array in [[saved, "Saved: %s"], [examples, "Example: %s"]]:
		if (group[0] as Array).is_empty():
			continue
		_choices.append(null)
		words.append("")
		for entry: ModelStore.Entry in group[0]:
			_choices.append([PartsCompare.MODEL, entry.path, entry.name])
			words.append(group[1] % entry.name)
	for n: int in 2:
		var pick: OptionButton = _pick[n]
		pick.clear()
		for at: int in _choices.size():
			if _choices[at] == null:
				pick.add_separator()
			else:
				pick.add_item(words[at])
		pick.set_item_disabled(0, not built)
		var again: int = -1
		var before: Variant = was[n]
		if before != null:
			for at: int in _choices.size():
				if _choices[at] != null and _choices[at][0] == before[0] \
						and _choices[at][1] == before[1] and (at != 0 or built):
					again = at
		if again < 0:
			again = 0 if n == 1 and built else 1
		pick.select(again)


func _kind(n: int) -> String:
	var at: int = _pick[n].selected
	return str(_choices[at][0]) if at >= 0 and at < _choices.size() and _choices[at] != null else ""


func _ready_to_compare() -> bool:
	for n: int in 2:
		var kind: String = _kind(n)
		if kind.is_empty() or (kind == PartsCompare.SET and _number[n].text.strip_edges().is_empty()):
			return false
	return true


## A picker's row chosen: a set asks for its number, anything else is
## compared at once.
func _picked(n: int) -> void:
	var set_wanted: bool = _kind(n) == PartsCompare.SET
	_number[n].visible = set_wanted
	if set_wanted and _number[n].text.strip_edges().is_empty():
		_number[n].grab_focus()
		return
	if _ready_to_compare():
		compare_parts()


func _side_of(n: int) -> PartsCompare.Pile:
	var choice: Array = _choices[_pick[n].selected]
	match str(choice[0]):
		PartsCompare.OPEN:
			return PartsCompare.of_open(world, library, store.scenery, str(choice[2]))
		PartsCompare.SET:
			return await PartsCompare.of_set(_number[n].text, inventories, library)
	return PartsCompare.of_file(str(choice[1]), str(choice[2]), library)


func _swap_sides() -> void:
	var picked: Array = [_pick[0].selected, _pick[1].selected]
	var typed: Array = [_number[0].text, _number[1].text]
	for n: int in 2:
		_pick[n].select(picked[1 - n])
		_number[n].text = typed[1 - n]
		_number[n].visible = _kind(n) == PartsCompare.SET
	if _ready_to_compare():
		compare_parts()


## The counts, the tabs' words, the list shown and what to buy.
func _fill_lists() -> void:
	var counted: Array = [0, 0, 0]
	var a_name: String = "A"
	var b_name: String = "B"
	if parts != null:
		counted = [PartsCompare.total(parts.both), PartsCompare.total(parts.only_a),
			PartsCompare.total(parts.only_b)]
		a_name = parts.a.short
		b_name = parts.b.short
		_sides.text = PartsCompare.side_line("A", parts.a) + "\n" + PartsCompare.side_line("B", parts.b)
	elif _sides.text.is_empty():
		_sides.text = "Choose A and B: a set by its number, a saved model or the model open now."
	var titles: Array = ["In both", "Only in %s" % a_name, "Only in %s" % b_name]
	for tab: int in 3:
		_tabs.set_tab_title(tab, titles[tab] + (" · %d" % counted[tab] if parts != null else ""))
	var buying: Inventory = lists[ONLY_B] if lists.size() == 3 else null
	if parts == null:
		_buy.text = "To build B from A, the parts to buy are listed here, for the shops."
	elif buying.lots.is_empty():
		_buy.text = "%s has every piece %s needs: nothing to buy." % [a_name, b_name]
	else:
		_buy.text = "To build %s from %s, buy these %s in %s:" % [b_name, a_name,
			Counted.of(buying.pieces, "piece"), Counted.of(buying.lots.size(), "lot")]
	for shop: String in _shops:
		(_shops[shop] as Button).disabled = buying == null or buying.lots.is_empty()
	_buy_note.visible = false
	_show_list()


## The rows of the tab chosen, each a lot: how many, its picture, its colour,
## its number, name and colour's name, as the parts list's rows are.
func _show_list() -> void:
	for child: Node in _list_rows.get_children():
		_list_rows.remove_child(child)
		child.queue_free()
	_list_sight.forget()
	_list_scroll.scroll_vertical = 0
	var tab: int = _tabs.current_tab
	if parts == null or lists.size() < 3:
		return
	var stock: Inventory = lists[tab]
	if stock.lots.is_empty():
		var none := Label.new()
		none.text = ["Nothing in both.", "Nothing only in %s." % parts.a.short,
			"Nothing only in %s." % parts.b.short][tab]
		none.add_theme_font_size_override("font_size", 12)
		none.modulate = Color(1, 1, 1, 0.7)
		_list_rows.add_child(none)
		return
	for lot: Inventory.Lot in stock.lots:
		_list_rows.add_child(_lot_row(lot, parts.mould_words(Collection.key_of(lot.part_id,
			lot.color_code)) if tab == BOTH else ""))


func _lot_row(lot: Inventory.Lot, note: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 9)
	var count := Label.new()
	count.text = "%d ×" % lot.count
	count.custom_minimum_size = Vector2(44, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 12)
	row.add_child(count)
	var tile := ThumbTile.new(lot.part_id, lot.color_code)
	tile.custom_minimum_size = Vector2(ROW, ROW)
	row.set_meta("tile", tile)
	if thumbnails != null:
		var ready_now: ImageTexture = thumbnails.peek(lot.part_id, lot.color_code)
		if ready_now != null:
			tile.show_picture(ready_now, false)
	row.add_child(tile)
	var swatch := Panel.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(15, 15)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	var colour: PartLibrary.BrickColor = library.color(lot.color_code)
	style.bg_color = colour.shown
	style.set_corner_radius_all(3)
	if colour.is_transparent():
		style.set_border_width_all(2)
		style.border_color = Color(colour.rgb, 1.0).darkened(0.4)
	swatch.add_theme_stylebox_override("panel", style)
	row.add_child(swatch)
	for cell: Array in [[lot.part_id, 74.0, 0.55, false], [lot.name + note, 0.0, 1.0, true],
			[lot.color_name, 150.0, 0.6, false]]:
		var label := Label.new()
		label.text = cell[0]
		label.custom_minimum_size = Vector2(cell[1], 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if cell[3] else Control.SIZE_FILL
		label.clip_text = true
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(1, 1, 1, cell[2])
		row.add_child(label)
	return row


func _parts_pictures() -> void:
	if thumbnails == null or _list_sight == null or not _list_sight.changed():
		return
	thumbnails.watch(self, _list_sight.tiles())


## What the parts sheet shows, for a probe to read as a person would.
func parts_fields() -> Dictionary:
	if _parts_column == null:
		return {"open": false, "mode": mode}
	var tabs: Array = []
	for tab: int in _tabs.tab_count:
		tabs.append(_tabs.get_tab_title(tab))
	var rows: Array = []
	for row: Node in _list_rows.get_children():
		if row is Label:
			rows.append((row as Label).text)
			continue
		var said := PackedStringArray()
		for cell: Node in row.get_children():
			if cell is Label:
				said.append((cell as Label).text)
		rows.append(" ".join(said))
	var picked: Array = []
	for n: int in 2:
		picked.append(_pick[n].get_item_text(_pick[n].selected) + (" " + _number[n].text
			if _number[n].visible else ""))
	return {"open": visible and mode == PARTS, "mode": mode, "a": picked[0], "b": picked[1],
		"sides": _sides.text, "tabs": tabs, "tab": _tabs.current_tab, "rows": rows,
		"buy": _buy.text, "note": _buy_note.text if _buy_note.visible else "",
		"comparing": comparing}


func _parts_controls() -> Dictionary:
	var named: Dictionary = {"compare_close": _parts_close, "compare_swap": _swap,
		"compare_go": _go, "compare_a": _pick[0], "compare_b": _pick[1], "compare_tabs": _tabs,
		"compare_list": _list_scroll}
	for n: int in 2:
		if _number[n].visible:
			named["compare_%s_number" % ["a", "b"][n]] = _number[n]
	for shop: String in _shops:
		named["compare_" + shop] = _shops[shop]
	return named


# -- setcheck (APP_UX10 #4): the model against its set's own -----------------------

## The third mode: the model checked against a library set's own model
## (SetCheck), a side panel where the save's is, wider for its rows.
const SET := "set"
const SET_WIDE := 400.0
## Most changes listed and drawn as ghosts: a model with more is not a
## build of the set, and 7,000 ghosts built in a frame held it 1.5 s.
const SET_SHOWN := 400
## Set by Shell: the model library the set's file comes from, and the
## builder whose selection a row's click sets.
var models: ModelLibrary
var builder: Builder
## The check shown, null before one; whether one is being read.
var checked: SetCheck = null
var checking: bool = false
var _set_column: VBoxContainer = null
var _set_close: Button
var _set_number: LineEdit
var _set_go: Button
var _set_head: Label
var _set_notes: Label
var _set_scroll: ScrollContainer
var _set_rows: VBoxContainer
var _set_what: Label
## The set's model read, and its entry in the library's index.
var _set_side: SetCheck.Reading = null
var _set_entry: Dictionary = {}
## The model ([method BrickWorld.generation]) the field's number was
## checked for: opened again on another, a number typed is not kept.
var _set_typed_in: int = -1
## Each change's row, by its index in the check.
var _set_buttons: Array[Button] = []


## File, Compare, Compare with the set…: the model checked against the set
## [param number] names, or against the set it was opened from, or the one
## typed last. Checked at once when there is one; else its number is asked.
func open_set(number: String = "") -> void:
	if visible and mode != SET:
		close()
	_show_mode(SET)
	if not visible:
		_aim = camera.aim() if camera != null else {}
		_stress_was = stress != null and stress.on
		if _stress_was:
			stress.set_on(false)
	visible = true
	set_process(true)
	var asked: String = number.strip_edges()
	if asked.is_empty():
		asked = SetCheck.own_set(store)
	# A number typed for another model is not this one's set.
	if asked.is_empty() and world != null and world.generation() != _set_typed_in:
		_set_number.text = ""
	if not asked.is_empty():
		_set_number.text = asked
	if _set_number.text.strip_edges().is_empty():
		checked = null
		_set_head.text = "Type the set's number, as on its box: 7140 or 7140-1."
		_fill_set()
		_set_number.grab_focus()
		return
	await check_set()


## Check the model against the set the field names: its file fetched from
## the library (once), read on a worker when it is big with the status bar
## saying so, and every change listed by the set's steps.
func check_set() -> void:
	_asked += 1
	var asked: int = _asked
	checking = true
	_set_go.disabled = true
	_set_typed_in = world.generation()
	_set_head.text = "Checking against %s…" % _set_number.text.strip_edges()
	var got: Dictionary = await SetCheck.run(_set_number.text, models, world, store, library)
	if asked != _asked or not visible or mode != SET:
		return
	checking = false
	_set_go.disabled = false
	if got["check"] == null:
		checked = null
		world.set_stress(false)
		_drop_ghosts()
		_set_head.text = str(got["error"])
		_fill_set()
		return
	_set_side = got["side"]
	_set_entry = got["entry"]
	checked = got["check"]
	chosen = -1
	_revision = world.revision
	compared += 1
	_draw_set()
	_fill_set()
	say.call("Checked against %s: %s" % [checked.set_name, checked.summary()])


## The model checked again, as it is now: drawn and listed. A coroutine.
func _check_now() -> void:
	_asked += 1
	var asked: int = _asked
	checking = true
	var revision: int = world.revision
	var again: SetCheck = await SetCheck.of_model(_set_side, _set_entry, world, store, library)
	if asked != _asked or not visible or mode != SET:
		return
	checking = false
	checked = again
	_revision = revision
	compared += 1
	chosen = -1
	_draw_set()
	_fill_set()


## An edit while it is open is checked again a moment later, longer on a
## big model.
func _set_again() -> void:
	if checked == null or _set_side == null or checking or store.laying:
		return
	var now: int = Time.get_ticks_msec()
	if world.revision != _revision:
		_revision = world.revision
		_again_at = now + maxi(AGAIN_AFTER_MS, roundi(checked.matched_ms * 4.0))
	elif _again_at > 0 and now >= _again_at:
		_again_at = 0
		_check_now()


## Each change drawn on the model in its colour, the rest faded; a part taken
## away a red ghost where the set has it, one moved a faint one where it was.
func _draw_set() -> void:
	var tints: Dictionary = {}
	for change: SetCheck.Change in checked.changes:
		if change.now != null and change.now.id != 0:
			tints[change.now.id] = set_colour_of(change.kind)
	world.set_stress(true, tints)
	_drop_ghosts()
	_ghosts = BrickWorld.new()
	_ghosts.library = library
	_ghosts.keeps_history = false
	_ghosts.name = "compare_ghosts"
	world.add_child(_ghosts)
	var see_through: Dictionary = {}
	for n: int in mini(checked.changes.size(), SET_SHOWN):
		var change: SetCheck.Change = checked.changes[n]
		if change.kind != SetCheck.TAKEN and change.kind != SetCheck.MOVED:
			continue
		var ghost: int = _ghosts.add_brick(change.was.part_id,
			REMOVED_GHOST if change.kind == SetCheck.TAKEN else MOVED_GHOST, _set_place_of(change.was))
		if ghost == 0:
			continue
		_ghost_of[n] = ghost
		if change.kind == SetCheck.MOVED:
			see_through[ghost] = true
	_ghosts.set_xray(see_through)


## Where a part of the set's stands on the baseplate: the model's lift, and
## the shift it was found standing at (SetCheck.shifted).
func _set_place_of(part: SetCheck.Part) -> Transform3D:
	return Transform3D(Basis.IDENTITY, store.lift() + checked.shifted) * part.at


## The colour a change of [param kind] is drawn and listed in.
static func set_colour_of(kind: String) -> Color:
	match kind:
		SetCheck.ADDED:
			return ADDED
		SetCheck.TAKEN:
			return REMOVED
		SetCheck.MOVED:
			return MOVED
		SetCheck.REGROUPED:
			return Color(0.45, 0.75, 1.0)
	return RECOLOURED


## A row clicked: its part selected and framed (a part taken away, the ghost
## where the set has it), and what it is said.
func choose_set(n: int) -> void:
	if checked == null or n < 0 or n >= checked.changes.size():
		return
	chosen = n
	var change: SetCheck.Change = checked.changes[n]
	for k: int in _set_buttons.size():
		_set_buttons[k].button_pressed = k == n
	var box := AABB()
	var brick: BrickWorld.Brick = world.get_brick(change.now.id) \
		if change.now != null and change.now.id != 0 else null
	if brick != null:
		if builder != null and not builder.locked.has(brick.id):
			# At the level where it is one thing to pick, as the outliner does.
			if assemblies != null and not Assemblies.within(Assemblies.path_of(brick), assemblies.entered):
				assemblies.enter("")
			builder.selection.clear()
			builder.selection[brick.id] = true
			builder.selection_changed.emit(builder.selection.size())
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if mesh != null:
			box = (world.drawn_at(brick) * mesh.bounds).abs()
	elif change.was != null:
		var mesh: Lbm.PartMesh = library.mesh_for(change.was.part_id)
		if mesh != null:
			box = (_set_place_of(change.was) * mesh.bounds).abs()
	if camera != null and box.size != Vector3.ZERO:
		camera.frame(box.grow(8.0), 1.6)
	_set_what.text = "%s, %s." % [checked.line_words(change, library), checked.step_of(change)]
	_set_what.visible = true
	say.call(checked.words(change, library))


func _build_set() -> void:
	_set_column = VBoxContainer.new()
	_set_column.add_theme_constant_override("separation", 7)
	_set_column.visible = false
	add_child(_set_column)
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(func() -> void:
			if visible and mode == SET:
				_place_set())
	var header := HBoxContainer.new()
	_set_column.add_child(header)
	var title := Label.new()
	title.text = "Compare with the set"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_set_close = _button(header, "Close", func() -> void: close(),
		"Stop comparing: every part as it was, and the view too (Esc)")
	var ask := HBoxContainer.new()
	ask.add_theme_constant_override("separation", 8)
	_set_column.add_child(ask)
	_set_number = LineEdit.new()
	_set_number.placeholder_text = "Set number, as 7140"
	_set_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_number.add_theme_font_size_override("font_size", 12)
	_set_number.tooltip_text = "The set's number, as on its box (7140 or 7140-1): its model from the library is what the model is checked against"
	_set_number.text_submitted.connect(func(_text: String) -> void: await check_set())
	ask.add_child(_set_number)
	_set_go = _button(ask, "Check", func() -> void: await check_set(),
		"Every part taken away, added, swapped, recoloured, moved or in another sub-model, by the set's own steps")
	_set_head = _words(_set_column, 12, 0.9)
	_set_head.custom_minimum_size.x = SET_WIDE - 28.0
	_set_notes = _words(_set_column, 11, 0.7)
	_set_notes.custom_minimum_size.x = SET_WIDE - 28.0
	_set_scroll = ScrollContainer.new()
	_set_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_set_scroll.custom_minimum_size = Vector2(SET_WIDE - 28.0, 320)
	_set_column.add_child(_set_scroll)
	_set_rows = VBoxContainer.new()
	_set_rows.add_theme_constant_override("separation", 2)
	_set_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_scroll.add_child(_set_rows)
	_set_column.add_child(HSeparator.new())
	_set_what = _words(_set_column, 12, 0.95)
	_set_what.custom_minimum_size.x = SET_WIDE - 28.0
	_set_what.visible = false


## The list as tall as the model area leaves room for under the panel's top.
func _place_set() -> void:
	var area: float = (get_parent() as Control).size.y if get_parent() is Control \
		else get_viewport_rect().size.y
	_set_scroll.custom_minimum_size.y = clampf(area - offset_top - 260.0, 140.0, 520.0)


## The heading, what was not compared, and a row a change under its step.
func _fill_set() -> void:
	for child: Node in _set_rows.get_children():
		_set_rows.remove_child(child)
		child.queue_free()
	_set_buttons.clear()
	_set_what.visible = false
	if checked == null:
		_set_notes.visible = false
		return
	_set_head.text = checked.heading()
	var notes: PackedStringArray = checked.notes()
	_set_notes.text = " ".join(notes)
	_set_notes.visible = not notes.is_empty()
	if checked.changes.is_empty():
		var none := Label.new()
		none.text = "Every part is as the set has it, in its place, colour and sub-model."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = SET_WIDE - 40.0
		none.add_theme_font_size_override("font_size", 12)
		none.modulate = Color(1, 1, 1, 0.8)
		_set_rows.add_child(none)
		return
	var index: Dictionary = {}
	for n: int in checked.changes.size():
		index[checked.changes[n]] = n
	for group: Array in checked.by_step():
		var step := Label.new()
		var said: String = str(group[0])
		step.text = said.left(1).to_upper() + said.substr(1)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		step.custom_minimum_size.x = SET_WIDE - 40.0
		step.add_theme_font_size_override("font_size", 11)
		step.modulate = Color(1, 1, 1, 0.6)
		_set_rows.add_child(step)
		for change: SetCheck.Change in group[1]:
			var n: int = index[change]
			var row := Button.new()
			row.flat = true
			row.toggle_mode = true
			row.focus_mode = Control.FOCUS_NONE
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.custom_minimum_size.x = SET_WIDE - 40.0
			row.add_theme_font_size_override("font_size", 12)
			row.icon = _chip(set_colour_of(change.kind))
			row.text = checked.line_words(change, library)
			row.tooltip_text = "Select it and frame it in the view"
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			row.pressed.connect(func() -> void: choose_set(n))
			_set_rows.add_child(row)
			_set_buttons.append(row)
		if _set_buttons.size() >= SET_SHOWN:
			var more := Label.new()
			more.text = "…and %d more changes." % (checked.changes.size() - _set_buttons.size())
			more.add_theme_font_size_override("font_size", 11)
			_set_rows.add_child(more)
			break


## What the set panel shows, for a probe to read as a person would.
func set_fields() -> Dictionary:
	if _set_column == null:
		return {"open": false, "mode": mode}
	var rows: Array = []
	var steps: Array = []
	for child: Node in _set_rows.get_children():
		if child is Button:
			rows.append((child as Button).text)
		elif child is Label:
			steps.append((child as Label).text)
	return {"open": visible and mode == SET, "mode": mode, "number": _set_number.text,
		"head": _set_head.text, "notes": _set_notes.text if _set_notes.visible else "",
		"steps": steps, "rows": rows, "what": _set_what.text if _set_what.visible else "",
		"checking": checking}


func _set_controls() -> Dictionary:
	var named: Dictionary = {"compare_close": _set_close, "compare_set_number": _set_number,
		"compare_set_go": _set_go, "compare_set_list": _set_scroll}
	for n: int in _set_buttons.size():
		named["compare_set_row_%d" % n] = _set_buttons[n]
	return named


# -- suggestedit: a remixer's change sent back (PLAN row 5) ---------------------

## The fourth mode: a change a remixer sent back from their remix (api/
## _suggestions.js), drawn on the designer's model as they last published it,
## which Main opened for it. On the model: a part the change takes away red,
## one it moves amber with a faint ghost where it goes, one it paints
## violet, and what it adds a green ghost where it goes (a part swapped for
## another is both); what it only puts in another step is listed. Each
## change ticked to take, by itself or by its kind, all ticked to begin
## with; a row pressed frames it. Nothing is taken but by Take all or Take
## the ticked, and Decline says no to all of it.
const SUGGEST := "suggest"
const SUGGEST_WIDE := 400.0
## What a part the change adds is drawn as: Trans-Bright Green glass.
const ADDED_GHOST := 35
const RESTEPPED := Color(0.45, 0.75, 1.0)
## Most rows listed: a change past it is still taken by Take all.
const SUGGEST_SHOWN := 400

## The change shown, as the server said it, or {} before one.
var suggestion: Dictionary = {}
## Each change's id -> whether it is ticked to take.
var ticked: Dictionary = {}
## Whether a take or a decline is on its way, for a probe.
var taking: bool = false
## What the drawing is: the model on the baseplate against the remix's parts.
var suggest_diff: ModelDiff = null
var _take: Callable
var _decline: Callable
var _suggest_column: VBoxContainer = null
var _suggest_close: Button
var _suggest_head: Label
var _suggest_note: Label
var _suggest_kinds: HFlowContainer
var _suggest_kind_boxes: Dictionary = {}
var _suggest_scroll: ScrollContainer
var _suggest_rows: VBoxContainer
var _suggest_what: Label
var _suggest_all: Button
var _suggest_ticked: Button
var _suggest_decline: Button
var _suggest_said: Label
var _suggest_boxes: Array[CheckBox] = []
var _suggest_buttons: Array[Button] = []
var _suggest_ghosts: Dictionary = {}


## The change [param got] (api/_suggestions.js suggestionAnswer, the
## designer's), drawn on the model open now, which is its designer's version
## got.model.n. [param take] is called with "all" or the ids ticked and
## answers "" or what went wrong; [param decline] the same with nothing.
func open_suggestion(got: Dictionary, take: Callable, decline: Callable) -> void:
	if visible and mode != SUGGEST:
		close()
	_show_mode(SUGGEST)
	if not visible:
		_aim = camera.aim() if camera != null else {}
		_stress_was = stress != null and stress.on
		if _stress_was:
			stress.set_on(false)
	suggestion = got
	_take = take
	_decline = decline
	taking = false
	ticked.clear()
	for change: Variant in got.get("changes", []):
		ticked[str((change as Dictionary)["id"])] = true
	chosen = -1
	visible = true
	set_process(true)
	_draw_suggestion()
	_fill_suggestion()
	_suggest_said.text = ""
	# Placed again once its words are laid out, for the list's height.
	_place_suggest.call_deferred()
	compared += 1
	say.call("%s: %s" % [SharedModels.suggestion_heading(got), SharedModels.suggestion_counts(got.get("counts", {}))])


## The model on the baseplate drawn against the remix's parts, by Compare's
## matching: what the change takes away, moves and paints tinted on the
## model, and what it adds and where it moves to as ghosts.
func _draw_suggestion() -> void:
	var theirs: Array = ModelDiff.parts_of_text(str(suggestion.get("theirs", "")), library)
	var mine: Array = ModelDiff.parts_of_world(world, store.scenery, store.lift(), store.awaited_now())
	suggest_diff = ModelDiff.between(mine, theirs)
	_revision = world.revision
	var tints: Dictionary = {}
	for change: ModelDiff.Change in suggest_diff.changes:
		if change.was != null and change.was.id != 0:
			tints[change.was.id] = colour_of(change.kind)
	world.set_stress(true, tints)
	_drop_ghosts()
	_suggest_ghosts.clear()
	_ghosts = BrickWorld.new()
	_ghosts.library = library
	_ghosts.keeps_history = false
	_ghosts.name = "compare_ghosts"
	world.add_child(_ghosts)
	var lift := Transform3D(Basis.IDENTITY, store.lift())
	var see_through: Dictionary = {}
	for n: int in suggest_diff.changes.size():
		var change: ModelDiff.Change = suggest_diff.changes[n]
		if change.kind != ModelDiff.ADDED and change.kind != ModelDiff.MOVED:
			continue
		var ghost: int = _ghosts.add_brick(change.now.part_id,
			ADDED_GHOST if change.kind == ModelDiff.ADDED else MOVED_GHOST, lift * change.now.at)
		if ghost == 0:
			continue
		_ghost_of[n] = ghost
		_suggest_ghosts[ghost] = change.kind
		if change.kind == ModelDiff.MOVED:
			see_through[ghost] = true
	_ghosts.set_xray(see_through)


## What is drawn, for a probe: the parts tinted on the model and the ghosts,
## each counted by the kind of change it shows.
func drawn_suggestion() -> Dictionary:
	var tinted: Dictionary = {}
	var ghosts_of: Dictionary = {}
	if suggest_diff != null:
		for change: ModelDiff.Change in suggest_diff.changes:
			if change.was != null and change.was.id != 0 and world.get_brick(change.was.id) != null:
				tinted[change.kind] = int(tinted.get(change.kind, 0)) + 1
	for ghost: int in _suggest_ghosts:
		if _ghosts != null and _ghosts.get_brick(ghost) != null:
			var kind: String = _suggest_ghosts[ghost]
			ghosts_of[kind] = int(ghosts_of.get(kind, 0)) + 1
	return {"tinted": tinted, "ghosts": ghosts_of}


## The colour a sent change of [param kind] is listed in.
static func suggest_colour_of(kind: String) -> Color:
	match kind:
		"added", "swapped":
			return ADDED
		"removed":
			return REMOVED
		"moved":
			return MOVED
		"restepped":
			return RESTEPPED
	return RECOLOURED


## What one sent change is, as its row says it: "Added: Brick 2 x 4 in Red,
## step 3", "Swapped Brick 1 x 2 for Brick 1 x 4 in Red, step 2".
static func suggestion_words(change: Dictionary, library: PartLibrary) -> String:
	var name: String = StressView._named(library, str(change.get("part", "")))
	var colour: String = _colour(library, int(change.get("colour", 0)))
	var was: Dictionary = change.get("was") if change.get("was") is Dictionary else {}
	var now: Dictionary = change.get("now") if change.get("now") is Dictionary else {}
	var said: String
	match str(change.get("kind", "")):
		"added":
			said = "Added: %s in %s, step %d" % [name, colour, int(now.get("step", 0))]
		"removed":
			said = "Taken away: %s in %s, step %d" % [name, colour, int(was.get("step", 0))]
		"moved":
			said = "%s: %s in %s, step %d" % [_moved_said(change), name, colour, int(now.get("step", 0))]
			if bool(change.get("restepped", false)):
				said += " (from step %d)" % int(was.get("step", 0))
		"recoloured":
			said = "Recoloured %s to %s: %s, step %d" % [_colour(library, int(change.get("from_colour", 0))),
				colour, name, int(now.get("step", 0))]
		"swapped":
			said = "Swapped %s for %s in %s, step %d" % [StressView._named(library,
				str(change.get("from_part", ""))), name, colour, int(now.get("step", 0))]
		_:
			said = "To step %d from step %d: %s in %s" % [int(now.get("step", 0)),
				int(was.get("step", 0)), name, colour]
	var section: String = str(change.get("section", ""))
	# A part of its own ("; "), which Language translates by itself.
	if not section.is_empty():
		said += "; in sub-model “%s”" % section
	return said


## "Moved 2 studs", "Turned", "Moved 1 plate and turned": from where it is
## said to stand first, before and after.
static func _moved_said(change: Dictionary) -> String:
	var said := PackedStringArray()
	var from: Vector3 = _point(change.get("was"))
	var to: Vector3 = _point(change.get("now"))
	if from.distance_to(to) >= ModelDiff.NEAR:
		said.append("Moved " + _distance(to - from))
	if bool(change.get("turned", false)):
		said.append("turned" if not said.is_empty() else "Turned")
	return " and ".join(said) if not said.is_empty() else "Moved"


## The first place [param side] ({at: [[x, y, z], ...]}) is said to stand.
static func _point(side: Variant) -> Vector3:
	if side is Dictionary and (side as Dictionary).get("at") is Array \
			and not ((side as Dictionary)["at"] as Array).is_empty():
		var at: Variant = ((side as Dictionary)["at"] as Array)[0]
		if at is Array and (at as Array).size() == 3:
			return Vector3(float(at[0]), float(at[1]), float(at[2]))
	return Vector3.ZERO


## A row pressed: the view framed on where the change is, before and after.
func choose_suggested(n: int) -> void:
	var changes: Array = suggestion.get("changes", [])
	if n < 0 or n >= changes.size():
		return
	chosen = n
	var change: Dictionary = changes[n]
	for k: int in _suggest_buttons.size():
		_suggest_buttons[k].button_pressed = k == n
	var box := AABB()
	var first := true
	for side: String in ["was", "now"]:
		var placed: Variant = (change.get(side) as Dictionary).get("at") if change.get(side) is Dictionary else null
		if not placed is Array:
			continue
		for at: Variant in placed:
			if not at is Array or (at as Array).size() != 3:
				continue
			var point: Vector3 = store.lift() + Vector3(float(at[0]), float(at[1]), float(at[2]))
			box = AABB(point, Vector3.ZERO) if first else box.expand(point)
			first = false
	if camera != null and not first:
		camera.frame(box.grow(24.0), 1.6)
	_suggest_what.text = suggestion_words(change, library) + "."
	_suggest_what.visible = true


func _ticked_ids() -> Array:
	var out: Array = []
	for change: Variant in suggestion.get("changes", []):
		var id: String = str((change as Dictionary)["id"])
		if bool(ticked.get(id, false)):
			out.append(id)
	return out


## Tick or untick change [param n], or every change of [param kind].
func tick(n: int, on: bool) -> void:
	var changes: Array = suggestion.get("changes", [])
	if n >= 0 and n < changes.size():
		ticked[str((changes[n] as Dictionary)["id"])] = on
	_say_ticked()


func tick_kind(kind: String, on: bool) -> void:
	var changes: Array = suggestion.get("changes", [])
	for n: int in changes.size():
		if str((changes[n] as Dictionary).get("kind", "")) == kind:
			ticked[str((changes[n] as Dictionary)["id"])] = on
			if n < _suggest_boxes.size():
				_suggest_boxes[n].set_pressed_no_signal(on)
	_say_ticked()


## The buttons and each kind's box as the ticks now are.
func _say_ticked() -> void:
	var changes: Array = suggestion.get("changes", [])
	var picked: int = _ticked_ids().size()
	_suggest_ticked.text = "Take the %d ticked" % picked if picked != 1 else "Take the 1 ticked"
	_suggest_ticked.disabled = picked == 0 or taking
	_suggest_all.disabled = changes.is_empty() or taking
	_suggest_decline.disabled = taking
	for kind: String in _suggest_kind_boxes:
		var all_on := true
		for change: Variant in changes:
			if str((change as Dictionary).get("kind", "")) == kind \
					and not bool(ticked.get(str((change as Dictionary)["id"]), false)):
				all_on = false
		(_suggest_kind_boxes[kind] as CheckBox).set_pressed_no_signal(all_on)


## Take all of it ([param whole]) or the changes ticked: Main asks for the
## model with them taken in and opens it, which closes this.
func take_suggested(whole: bool) -> void:
	if taking or not _take.is_valid():
		return
	var take: Variant = "all" if whole else _ticked_ids()
	if take is Array and (take as Array).is_empty():
		return
	# Every change ticked, when every one is listed, is all of it.
	if take is Array and (take as Array).size() == (suggestion.get("changes", []) as Array).size() \
			and bool(suggestion.get("listed", true)):
		take = "all"
	taking = true
	_say_ticked()
	_suggest_said.text = "Taking it into your model…"
	var trouble: String = await _take.call(take)
	taking = false
	if visible and mode == SUGGEST:
		_say_ticked()
		_suggest_said.text = trouble


func decline_suggested() -> void:
	if taking or not _decline.is_valid():
		return
	taking = true
	_say_ticked()
	_suggest_said.text = "Saying no to it…"
	var trouble: String = await _decline.call()
	taking = false
	if trouble.is_empty():
		close()
		return
	if visible and mode == SUGGEST:
		_say_ticked()
		_suggest_said.text = trouble


func _suggest_wide() -> float:
	var area: float = (get_parent() as Control).size.x if get_parent() is Control \
		else get_viewport_rect().size.x
	return clampf(area - 28.0, WIDE, SUGGEST_WIDE) if area > 0.0 else SUGGEST_WIDE


func _build_suggest() -> void:
	_suggest_column = VBoxContainer.new()
	_suggest_column.add_theme_constant_override("separation", 7)
	_suggest_column.visible = false
	add_child(_suggest_column)
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(func() -> void:
			if visible and mode == SUGGEST:
				_place_suggest())
	var header := HBoxContainer.new()
	_suggest_column.add_child(header)
	var title := Label.new()
	title.text = "Compare: a change sent to you"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_suggest_close = _button(header, "Close", func() -> void: close(),
		"Stop comparing: your model as it was, the change still waiting for you (Esc)")
	_suggest_head = _words(_suggest_column, 12, 0.9)
	_suggest_note = _words(_suggest_column, 12, 1.0)
	_suggest_note.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 3)
	_suggest_column.add_child(legend)
	_legend_row(legend, ADDED, 11, 0.8).text = "Added: a green ghost where it goes"
	_legend_row(legend, REMOVED, 11, 0.8).text = "Taken away: red"
	_legend_row(legend, MOVED, 11, 0.8).text = "Moved: amber, a faint ghost where it goes"
	_legend_row(legend, RECOLOURED, 11, 0.8).text = "Recoloured: violet"
	_suggest_kinds = HFlowContainer.new()
	_suggest_kinds.add_theme_constant_override("h_separation", 8)
	_suggest_column.add_child(_suggest_kinds)
	_suggest_scroll = ScrollContainer.new()
	_suggest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_suggest_scroll.custom_minimum_size = Vector2(SUGGEST_WIDE - 28.0, 220)
	_suggest_column.add_child(_suggest_scroll)
	_suggest_rows = VBoxContainer.new()
	_suggest_rows.add_theme_constant_override("separation", 2)
	_suggest_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suggest_scroll.add_child(_suggest_rows)
	_suggest_column.add_child(HSeparator.new())
	_suggest_what = _words(_suggest_column, 12, 0.95)
	_suggest_what.visible = false
	var act := HFlowContainer.new()
	act.add_theme_constant_override("h_separation", 8)
	act.add_theme_constant_override("v_separation", 6)
	_suggest_column.add_child(act)
	_suggest_all = _button(act, "Take all", func() -> void: await take_suggested(true),
		"All of the change taken into your model, opened for you to look at and publish as its next version")
	_suggest_ticked = _button(act, "Take the ticked", func() -> void: await take_suggested(false),
		"Only the changes ticked taken into your model, opened for you to look at and publish as its next version")
	_suggest_decline = _button(act, "Decline", func() -> void: await decline_suggested(),
		"Say no to this change: nothing of it is taken, and it leaves your notifications")
	_suggest_said = _words(_suggest_column, 12, 0.9)
	_suggest_said.add_theme_color_override("font_color", MOVED.lightened(0.2))


## The list as tall as the model area leaves room for, and the panel as wide
## as a phone has room for.
func _place_suggest() -> void:
	var wide: float = _suggest_wide()
	custom_minimum_size.x = wide
	offset_left = offset_right - wide
	for label: Label in [_suggest_head, _suggest_note, _suggest_what, _suggest_said]:
		label.custom_minimum_size.x = wide - 28.0
	_suggest_scroll.custom_minimum_size.x = wide - 28.0
	var area: float = (get_parent() as Control).size.y if get_parent() is Control \
		else get_viewport_rect().size.y
	# The list takes what the rest of the panel leaves of the model area: it
	# showed four rows at 1280 x 800 with room for eight under it.
	var rest: float = _suggest_column.get_combined_minimum_size().y - _suggest_scroll.custom_minimum_size.y
	_suggest_scroll.custom_minimum_size.y = clampf(area - offset_top - rest - 48.0, 110.0, 420.0)
	for row: Button in _suggest_buttons:
		row.custom_minimum_size.x = wide - 76.0


func _fill_suggestion() -> void:
	for child: Node in _suggest_rows.get_children():
		_suggest_rows.remove_child(child)
		child.queue_free()
	for child: Node in _suggest_kinds.get_children():
		_suggest_kinds.remove_child(child)
		child.queue_free()
	_suggest_boxes.clear()
	_suggest_buttons.clear()
	_suggest_kind_boxes.clear()
	_suggest_what.visible = false
	var got: Dictionary = suggestion
	var model: Dictionary = got.get("model") if got.get("model") is Dictionary else {}
	_suggest_head.text = "%s, against your version %d." % [SharedModels.suggestion_heading(got), int(model.get("n", 0))]
	var note: String = str(got.get("note", "")) if got.get("note") is String else ""
	_suggest_note.text = "“%s”" % note
	_suggest_note.visible = not note.is_empty()
	var counts: Dictionary = got.get("counts") if got.get("counts") is Dictionary else {}
	for kind: String in SharedModels.SUGGEST_KINDS:
		var n: int = int(counts.get(kind, 0))
		if n == 0:
			continue
		var box := CheckBox.new()
		box.text = SharedModels.kind_count(kind, n)
		box.button_pressed = true
		box.focus_mode = Control.FOCUS_NONE
		box.add_theme_font_size_override("font_size", 12)
		box.tooltip_text = "Tick or untick every change of this kind"
		box.icon = _chip(suggest_colour_of(kind))
		box.toggled.connect(func(on: bool) -> void: tick_kind(kind, on))
		_suggest_kinds.add_child(box)
		_suggest_kind_boxes[kind] = box
	var changes: Array = got.get("changes", [])
	for n: int in mini(changes.size(), SUGGEST_SHOWN):
		var change: Dictionary = changes[n]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		_suggest_rows.add_child(row)
		var box := CheckBox.new()
		box.button_pressed = bool(ticked.get(str(change["id"]), true))
		box.focus_mode = Control.FOCUS_NONE
		box.tooltip_text = "Take this change, or leave it"
		box.toggled.connect(func(on: bool) -> void: tick(n, on))
		row.add_child(box)
		_suggest_boxes.append(box)
		var words := Button.new()
		words.flat = true
		words.toggle_mode = true
		words.focus_mode = Control.FOCUS_NONE
		words.alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_theme_font_size_override("font_size", 12)
		words.icon = _chip(suggest_colour_of(str(change.get("kind", ""))))
		words.text = suggestion_words(change, library)
		words.tooltip_text = "Frame it in the view"
		words.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.pressed.connect(func() -> void: choose_suggested(n))
		row.add_child(words)
		_suggest_buttons.append(words)
	if changes.size() > SUGGEST_SHOWN or int(got.get("total", 0)) > changes.size():
		var more := Label.new()
		more.text = "…and %d more changes, which Take all takes." % (maxi(int(got.get("total", 0)),
			changes.size()) - mini(changes.size(), SUGGEST_SHOWN))
		more.add_theme_font_size_override("font_size", 11)
		_suggest_rows.add_child(more)
	if changes.is_empty() and int(got.get("total", 0)) == 0:
		var none := Label.new()
		none.text = "Your model is already as the remix has it."
		none.add_theme_font_size_override("font_size", 12)
		_suggest_rows.add_child(none)
	_place_suggest()
	_say_ticked()


## What the panel shows, for a probe to read as a person would.
func suggest_fields() -> Dictionary:
	if _suggest_column == null:
		return {"open": false, "mode": mode}
	var rows: Array = []
	for n: int in _suggest_buttons.size():
		rows.append({"text": _suggest_buttons[n].text, "ticked": _suggest_boxes[n].button_pressed})
	var kinds: Dictionary = {}
	for kind: String in _suggest_kind_boxes:
		kinds[kind] = {"text": (_suggest_kind_boxes[kind] as CheckBox).text,
			"ticked": (_suggest_kind_boxes[kind] as CheckBox).button_pressed}
	return {"open": visible and mode == SUGGEST, "mode": mode, "head": _suggest_head.text,
		"note": _suggest_note.text if _suggest_note.visible else "", "kinds": kinds, "rows": rows,
		"what": _suggest_what.text if _suggest_what.visible else "", "said": _suggest_said.text,
		"take_ticked": _suggest_ticked.text, "taking": taking, "drawn": drawn_suggestion()}


func _suggest_controls() -> Dictionary:
	var named: Dictionary = {"compare_close": _suggest_close, "suggest_take_all": _suggest_all,
		"suggest_take_ticked": _suggest_ticked, "suggest_decline": _suggest_decline,
		"suggest_list": _suggest_scroll}
	for kind: String in _suggest_kind_boxes:
		named["suggest_kind_" + kind] = _suggest_kind_boxes[kind]
	for n: int in _suggest_buttons.size():
		named["suggest_tick_%d" % n] = _suggest_boxes[n]
		named["suggest_row_%d" % n] = _suggest_buttons[n]
	return named
