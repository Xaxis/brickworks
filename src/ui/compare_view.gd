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
## Its second mode, File, Compare two sets or models… (APP_UX6 #7,
## comparesets), compares the parts of any two of a set, a saved model and the
## model open now, as Rebrickable's set compare does: the parts in both and in
## only one, by part and colour, and the list to buy to build the second from
## the first, which goes to the parts list's shops. The sums are
## PartsCompare's; the panel is then a sheet over the model, as the parts list
## is, and draws nothing on it.
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
	if visible and mode == PARTS:
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
	chosen = -1
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
	return {"compare_close": _close, "compare_previous": _previous, "compare_next": _next}


# -- comparesets: two sets' or models' parts (APP_UX6 #7) ---------------------------

## Which the panel shows: one of the model's saves drawn on it ([constant
## SAVE]), or the parts of any two of a set, a saved model and the model open
## now ([constant PARTS]), a sheet over the model as the parts list is.
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


## File, Compare two sets or models…: the sheet, with what was compared last
## time, or a set to type for A and the model open now for B; compared at once
## when both are there.
func open_parts() -> void:
	if visible and mode == SAVE:
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
	if which == PARTS and _side_place.is_empty():
		_side_place = {"anchors": [anchor_left, anchor_top, anchor_right, anchor_bottom],
			"offsets": [offset_left, offset_top, offset_right, offset_bottom],
			"grow": grow_horizontal}
	mode = which
	_save_column.visible = which == SAVE
	if _parts_column != null:
		_parts_column.visible = which == PARTS
	if which == PARTS:
		_place_parts()
	elif not _side_place.is_empty():
		var anchors: Array = _side_place["anchors"]
		var offsets: Array = _side_place["offsets"]
		for side: int in 4:
			set_anchor(side, float(anchors[side]), false, false)
		for side: int in 4:
			set_offset(side, float(offsets[side]))
		grow_horizontal = _side_place["grow"]


## Centred over the model, as large as [constant PARTS_SIZE] where there is
## room and inset 14 px from its edges where there is not.
func _place_parts() -> void:
	var area: Vector2 = (get_parent() as Control).size if get_parent() is Control \
		else get_viewport_rect().size
	var room: Vector2 = (area - Vector2(28.0, 28.0)).max(Vector2(WIDE, 240.0))
	var wanted := Vector2(minf(PARTS_SIZE.x, room.x), minf(PARTS_SIZE.y, room.y))
	for side: int in 4:
		set_anchor(side, 0.5, false, false)
	offset_left = -wanted.x / 2.0
	offset_right = wanted.x / 2.0
	offset_top = -wanted.y / 2.0
	offset_bottom = wanted.y / 2.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


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
