## Tools, Colour the hidden parts…: the parts nobody sees in the finished
## model, shown in the colours they would take, and given them in one step
## when the person says so.
##
## It measures first (SeenParts: the model drawn from 128 sides, every part
## its own number), works out the colours for the grouping chosen
## (HiddenColours), and shows the inside twice, cut open through the
## middle: as it is, and coloured. Nothing changes until Apply, which is
## one step to undo. A model opened from a real set says so, and Apply
## waits for a tick that the person means it.
##
## Over MCP, colour_hidden_parts (AppTools) runs the same code:
## [method for_session], which previews unless told the person agreed.
class_name HiddenColoursPanel
extends PanelContainer

const MODE_LABELS: Array[String] = ["By section", "By build stage", "Left and right",
	"Front and back"]
## The pictures' side, in pixels.
const PICTURE := 300
## Looking into the cut from the front, a little from the right and above.
const INTO := Vector3(0.45, 0.5, 1.0)

var world: BrickWorld
var builder: Builder
var library: PartLibrary
var store: ModelStore
var assemblies: Assemblies
var scenery: Dictionary = {}
## Main's: the model was changed by hand.
var edited: Callable = func() -> void: pass
var say: Callable = func(_line: String) -> void: pass

var mode: String = "sections"
var stages: int = 0
## Looked at from underneath too: a model picked up. Off for a model that
## stands on a shelf and is never turned over.
var from_below: bool = true
var plan: HiddenColours.Plan = null
var before: Image = null
var after: Image = null
## How it measures: sides, pictures a side and the most pixels across; -1
## for SeenParts' own. A probe drawing in software asks for less, to finish
## in the suite's time.
var views: int = -1
var samples: int = SeenParts.SAMPLES
var most_pixels: int = -1

var _seen: SeenParts
var _measured: SeenParts.Result = null
var _measured_key: String = ""
var _working: bool = false
var _again: bool = false

var _modes: OptionButton
var _stages: SpinBox
var _below: CheckBox
var _status: Label
var _before_rect: TextureRect
var _after_rect: TextureRect
var _legend: VBoxContainer
var _summary: Label
var _warning: Label
var _anyway: CheckBox
var _apply: Button
var _close: Button


func _ready() -> void:
	visible = false
	_seen = SeenParts.new()
	_seen.library = library
	add_child(_seen)
	_build()


# -- the work, for the panel and for a session ----------------------------------


## What is hidden, measured once for the model as it is.
func measured() -> SeenParts.Result:
	var key: String = "%d:%d:%d:%d:%d:%d" % [world.revision, world.brick_count(), scenery.size(),
		views, samples, most_pixels]
	if _measured != null and key == _measured_key:
		return _measured
	var job: Working.Job = Working.begin("Looking at %s from every side…" % _named(), 0, true)
	await job.shown()
	var cancel: Callable = func() -> void: _seen.cancelled = true
	job.cancel_wanted.connect(cancel)
	var count: int = views if views > 0 else (64 if OS.has_feature("web") else SeenParts.VIEWS)
	var heard: Callable = func(done: int, of: int) -> void: job.count(done, of)
	_seen.progressed.connect(heard)
	var result: SeenParts.Result = await _seen.measure(HiddenColours.bricks_of(world, scenery),
		count, SeenParts.FINEST, most_pixels, samples)
	_seen.progressed.disconnect(heard)
	job.end()
	if result.complete:
		_measured = result
		_measured_key = key
	return result


## The plan for [param how] ("sections", "stages", "left_right",
## "front_back"), worked out from the measure: null when the measure did
## not finish.
func work_out(how: String, stage_count: int = 0, below: bool = true) -> HiddenColours.Plan:
	var result: SeenParts.Result = await measured()
	if not result.complete:
		return null
	var steps: Array[Instructions.Step] = []
	if how == "sections" or how == "stages":
		var job: Working.Job = Working.begin("Following the build steps…")
		await job.shown()
		steps = await Instructions.plan_paced(world, library, scenery, {}, job, true)
		job.end()
	var made: HiddenColours.Plan = HiddenColours.plan(world, library, scenery,
		result.hidden(not below), how, steps, assemblies, builder.locked, stage_count)
	made.views = result.views
	made.pixel = result.coarsest
	made.ask_first = HiddenColours.ask_first(store)
	return made


## The inside, cut open where most of what would change is: as it is, and
## as [param made] would colour it. [before, after].
func pictures(made: HiddenColours.Plan, most: int = PICTURE) -> Array:
	var bricks: Array = HiddenColours.bricks_of(world, scenery)
	var frame: AABB = _frame(bricks)
	var cut: Array = cut_through(bricks, made.changes, library)
	return await _seen.pictures(bricks, made.changes, cut[1], frame, most, true, cut[0])


## Where to cut a model open to see [param changed] (brick id -> anything):
## [Plane, the side to look from]. Of cuts across x, y and z through each
## changed part's middle, the one that goes through the most of them; the
## part of the model on the side the plane faces is cut away, and the
## camera looks in from there. Through the middle from the front when
## nothing changes.
static func cut_through(bricks: Array, changed: Dictionary, library: PartLibrary) -> Array:
	var boxes: Array[AABB] = []
	var whole := AABB()
	var any: bool = false
	for entry: Array in bricks:
		var part: Lbm.PartMesh = library.mesh_for(str(entry[1]))
		if part == null:
			continue
		var box: AABB = (entry[3] as Transform3D) * part.bounds
		whole = box if not any else whole.merge(box)
		any = true
		if changed.has(int(entry[0])):
			boxes.append(box)
	var best: Array = [Plane(Vector3(0, 0, 1), whole.get_center().z), INTO]
	var most: int = 0
	# Front first: a tie is cut as a booklet looks, from the front.
	var ways: Array = [[2, Vector3(0, 0, 1), INTO], [0, Vector3(1, 0, 0), Vector3(1.0, 0.5, 0.45)],
		[1, Vector3(0, 1, 0), Vector3(0.35, 1.0, 0.5)]]
	var stride: int = maxi(1, boxes.size() / 150)
	for way: Array in ways:
		var axis: int = way[0]
		for at: int in range(0, boxes.size(), stride):
			var d: float = boxes[at].get_center()[axis]
			var through: int = 0
			for box: AABB in boxes:
				if box.position[axis] < d and box.end[axis] > d:
					through += 1
			if through > most:
				most = through
				best = [Plane(way[1], d), way[2]]
	return best


func _frame(bricks: Array) -> AABB:
	var whole := AABB()
	var any: bool = false
	for entry: Array in bricks:
		var part: Lbm.PartMesh = library.mesh_for(str(entry[1]))
		if part == null:
			continue
		var box: AABB = (entry[3] as Transform3D) * part.bounds
		whole = box if not any else whole.merge(box)
		any = true
	return whole


## Carry [param made] out, as one step, and keep its scheme with the model.
func apply_plan(made: HiddenColours.Plan) -> int:
	var changed: int = HiddenColours.apply(made, world, builder, assemblies)
	if changed > 0:
		store.hidden_scheme = made.scheme()
		edited.call()
	return changed


# -- the panel ----------------------------------------------------------------------


func open(how: String = "") -> void:
	if not how.is_empty() and how in HiddenColours.MODES:
		mode = how
		_modes.select(HiddenColours.MODES.find(mode))
	visible = true
	await refresh()


func close() -> void:
	_seen.cancelled = true
	visible = false
	plan = null


## Work it out again for what is chosen, and show it. Asked again while
## it works (another grouping chosen), it works it out once more after.
func refresh() -> void:
	if world == null:
		return
	if _working:
		_again = true
		return
	if world.brick_count() - scenery.size() <= 0:
		_status.text = "There is nothing on the baseplate yet."
		return
	if not SeenParts.possible():
		_status.text = "This needs the app in a window: what is hidden is measured from pictures."
		return
	_working = true
	_again = false
	_apply.disabled = true
	_stages.get_parent().visible = mode == "stages"
	_status.text = "Looking at it from every side…"
	plan = await work_out(mode, stages if mode == "stages" else 0, from_below)
	if plan == null:
		_status.text = "Stopped before it had looked from every side: nothing is known yet."
		_working = false
		_again = false
		return
	_status.text = "Drawing the inside…"
	var drawn: Array = await pictures(plan)
	before = drawn[0]
	after = drawn[1]
	_before_rect.texture = ImageTexture.create_from_image(before) if before != null else null
	_after_rect.texture = ImageTexture.create_from_image(after) if after != null else null
	_show(plan)
	_working = false
	if _again and visible:
		await refresh()


func _show(made: HiddenColours.Plan) -> void:
	for child: Node in _legend.get_children():
		child.queue_free()
	for group: HiddenColours.Group in made.groups:
		if group.recoloured == 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(16, 16)
		chip.color = library.color(group.colour).rgb
		row.add_child(chip)
		var words := Label.new()
		words.text = "%s — %s, %d %s" % [group.label, HiddenColours.colour_name(library,
			group.colour), group.recoloured, "part" if group.recoloured == 1 else "parts"]
		words.add_theme_font_size_override("font_size", 12)
		row.add_child(words)
		_legend.add_child(row)
	_status.text = ("The outside stays as it is: every part changed is seen from none of the "
		+ "%d sides it was looked at from.") % made.views if not made.changes.is_empty() \
		else ""
	_summary.text = made.summary(library)
	_warning.visible = not made.ask_first.is_empty()
	_anyway.visible = _warning.visible
	_warning.text = made.ask_first
	_anyway.button_pressed = false
	_apply.disabled = made.changes.is_empty() or _warning.visible
	_apply.text = "Colour %d %s" % [made.changes.size(),
		"part" if made.changes.size() == 1 else "parts"] if not made.changes.is_empty() \
		else "Nothing to colour"


func _on_apply() -> void:
	if plan == null or plan.changes.is_empty() or _working:
		return
	if not plan.ask_first.is_empty() and not _anyway.button_pressed:
		return
	var made: HiddenColours.Plan = plan
	var changed: int = apply_plan(made)
	close()
	say.call("coloured %d hidden %s %s — %s-Z puts them back" % [changed,
		"part" if changed == 1 else "parts", HiddenColours.MODE_WORDS.get(made.mode, ""),
		ControlsHint._hold()])


func _named() -> String:
	return store.title if store != null and not store.title.is_empty() else "the model"


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.96)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 14
	backing.content_margin_right = 14
	backing.content_margin_top = 11
	backing.content_margin_bottom = 12
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Colour the hidden parts"
	title.add_theme_font_size_override("font_size", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button(header, "Close", close, "Leave the model as it is")
	_words(column, 12, 0.75).text = ("Big sets colour the parts nobody sees once the model "
		+ "is finished, so you can tell where you are while you build: a colour for each "
		+ "section, stage or side. Only parts seen from no side change.")
	var choose := HBoxContainer.new()
	choose.add_theme_constant_override("separation", 8)
	column.add_child(choose)
	_modes = OptionButton.new()
	_modes.focus_mode = Control.FOCUS_NONE
	_modes.add_theme_font_size_override("font_size", 12)
	for label: String in MODE_LABELS:
		_modes.add_item(label)
	_modes.item_selected.connect(func(index: int) -> void:
		mode = HiddenColours.MODES[index]
		refresh())
	choose.add_child(_modes)
	var stage_row := HBoxContainer.new()
	stage_row.visible = false
	choose.add_child(stage_row)
	var stage_words := Label.new()
	stage_words.text = "stages"
	stage_words.add_theme_font_size_override("font_size", 12)
	_stages = SpinBox.new()
	_stages.min_value = 0
	_stages.max_value = HiddenColours.MOST_STAGES
	_stages.value = 0
	_stages.tooltip_text = "How many stages to colour: 0 lets the model's size decide"
	_stages.value_changed.connect(func(value: float) -> void:
		stages = int(value)
		refresh())
	stage_row.add_child(_stages)
	stage_row.add_child(stage_words)
	_below = CheckBox.new()
	_below.text = "Seen from underneath too"
	_below.button_pressed = true
	_below.add_theme_font_size_override("font_size", 12)
	_below.tooltip_text = ("On: a part seen from below keeps its colour, as for a model that is "
		+ "picked up. Off for one that stands on a shelf and is never turned over.")
	_below.toggled.connect(func(on: bool) -> void:
		from_below = on
		refresh())
	choose.add_child(_below)
	_status = _words(column, 12, 0.85)
	var pictures_row := HBoxContainer.new()
	pictures_row.add_theme_constant_override("separation", 10)
	column.add_child(pictures_row)
	_before_rect = _picture(pictures_row, "Inside now")
	_after_rect = _picture(pictures_row, "Inside, coloured")
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 3)
	column.add_child(_legend)
	_summary = _words(column, 11, 0.65)
	_warning = _words(column, 12, 1.0)
	_warning.add_theme_color_override("font_color", Color(1.0, 0.78, 0.5))
	_warning.visible = false
	_anyway = CheckBox.new()
	_anyway.text = "Recolour the set's hidden parts all the same"
	_anyway.add_theme_font_size_override("font_size", 12)
	_anyway.visible = false
	_anyway.toggled.connect(func(on: bool) -> void:
		_apply.disabled = plan == null or plan.changes.is_empty() or not on)
	column.add_child(_anyway)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	_apply = _button(buttons, "Colour them", _on_apply,
		"Give them these colours, as one step: %s-Z puts them back" % ControlsHint._hold())
	_apply.disabled = true
	_button(buttons, "Leave it", close, "Keep the model as it is")


func _picture(into: Control, caption: String) -> TextureRect:
	var box := VBoxContainer.new()
	into.add_child(box)
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(PICTURE, PICTURE * 0.75)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(rect)
	var words := Label.new()
	words.text = caption
	words.add_theme_font_size_override("font_size", 11)
	words.modulate = Color(1, 1, 1, 0.6)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(words)
	return rect


func _words(into: Control, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PICTURE * 2 + 10, 0)
	label.modulate = Color(1, 1, 1, alpha)
	into.add_child(label)
	return label


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


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"hidden_mode": _modes, "hidden_stages": _stages, "hidden_below": _below,
		"hidden_anyway": _anyway, "hidden_apply": _apply, "hidden_close": _close}


# -- over MCP -----------------------------------------------------------------------


## colour_hidden_parts, for a session: the plan said, with the inside
## pictured coloured; and with apply and agreed, done as one step.
func for_session(input: Dictionary, _work: Working.Job = null) -> Variant:
	if world == null:
		return "This app cannot do that from outside."
	if world.brick_count() - scenery.size() <= 0:
		return "There is nothing on the baseplate to colour."
	if not SeenParts.possible():
		return ("Finding the hidden parts needs the app in a window: they are measured from "
			+ "pictures. Start it in one (godot --path . -- --mcp).")
	var how: String = str(input.get("mode", "sections"))
	if not how in HiddenColours.MODES:
		return "mode= is one of %s." % ", ".join(HiddenColours.MODES)
	var below: bool = bool(input.get("from_below", true))
	var made: HiddenColours.Plan = await work_out(how, clampi(int(input.get("stages", 0)), 0,
		HiddenColours.MOST_STAGES), below)
	if made == null:
		return "Stopped before every side was looked at: nothing was changed."
	var said: String = made.summary(library)
	var applying: bool = bool(input.get("apply", false))
	if applying and made.changes.is_empty():
		return said + " Nothing was changed."
	if applying and not bool(input.get("agreed", false)):
		applying = false
		said += (" Not applied: this changes the person's model, so it is theirs to choose. "
			+ "Show them this and ask; call again with apply=true and agreed=true once they say yes.")
	if applying and not made.ask_first.is_empty() and not bool(input.get("set_agreed", false)):
		applying = false
		said += (" Not applied: %s Ask the person about that in so many words; "
			% made.ask_first + "set_agreed=true once they say to recolour the set.")
	if applying:
		var changed: int = apply_plan(made)
		return ("%s Done: %d parts coloured, one step to undo. The outside is unchanged. "
			% [said, changed] + "The booklet shows each colour where its %s starts."
			% ("section" if how == "sections" else "stage" if how == "stages" else "half"))
	if not made.ask_first.is_empty():
		said += " " + made.ask_first + " Ask before recolouring it."
	var drawn: Array = await pictures(made, 640)
	if drawn[1] == null:
		return said
	return [{"type": "text", "text": said + " The picture is the inside, cut open through "
		+ "the middle from the front, as it would be coloured; nothing has changed yet."},
		{"type": "image", "source": {"type": "base64", "media_type": "image/png",
			"data": Marshalls.raw_to_base64((drawn[1] as Image).save_png_to_buffer())}}]
