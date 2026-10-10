## Making a minifigure, slot by slot, and putting it in the model.
##
## Down the left, the figure's slots, each showing what is in it. In the
## middle, what the chosen slot can be — every real part the catalogue
## has for it, searchable, drawn with its print — and the colours, with a
## dot on the ones that part is really made in. On the right, the figure
## itself, turning, exactly as it will stand in the model; a name; and
## the figures kept so far.
##
## "Place in model" hands the figure to the builder, which holds it the
## way it holds a part: point at a stud, R to turn it, click to stand it
## there. Every figure placed is kept, under its name, in user:// — the
## browser's own storage on the web — so it can be placed again.
class_name MinifigDialog
extends PanelContainer

var library: PartLibrary
var thumbnails: PartThumbnails

signal place_wanted(figure: Minifig)
signal closed()

## What is on the bench.
var figure: Minifig = Minifig.new()

const CELL := 66
const MOST_SHOWN := 160

var _slot: String = "head"
var _slot_buttons: Dictionary = {}       ## slot -> Button
var _name: LineEdit
var _search: LineEdit
var _found: Label
var _grid: GridContainer
var _palette: FlowContainer
var _colour_note: Label
var _swatches: Dictionary = {}           ## code -> PartsBin.Swatch
var _shelf: VBoxContainer
var _summary: Label
var _rng := RandomNumberGenerator.new()

var _viewport: SubViewport
var _camera: Camera3D
var _stage: BrickWorld
var _waiting: Dictionary = {}            ## part id -> true, geometry on its way
var _turn: float = 0.45
var _dragging: bool = false


func _ready() -> void:
	visible = false
	_rng.randomize()
	_build()
	if library != null:
		library.fetched.connect(_on_geometry)
	if thumbnails != null:
		thumbnails.ready_for.connect(_on_thumbnail)


func open() -> void:
	visible = true
	_name.text = figure.name
	_refresh_all()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Escape closes it, even with the search box in hand — which is where
## the keyboard is most of the time this is open, and where the app's
## own Escape never sees the key.
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Every other key stops here while it is open: they are the model's
## shortcuts, and Delete or Q pressed while choosing a hat would delete
## or turn a model nobody can see. Typing into the search or the name
## is not affected; a focused line takes its keys before this.
func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _camera == null:
		return
	if not _dragging:
		_turn += delta * 0.35
	_aim()
	_since_asked += delta
	if _since_asked > 0.5:
		_since_asked = 0.0
		_fill_icons()


var _since_asked: float = 0.0


## Ask again for every picture still missing. A request made once can be
## lost two ways: the thumbnailer is shared with the parts bin, which
## empties its queue whenever it searches, and a part that has to come
## over the wire first is drawn only when somebody asks again after it
## lands. Asking twice a second covers both, and costs nothing for a
## picture already queued or already drawn.
func _fill_icons() -> void:
	var colour: int = int(figure.colours[_slot])
	for cell: Node in _grid.get_children():
		var part: String = str(cell.get_meta("part"))
		if not part.is_empty() and (cell as Button).icon == null:
			(cell as Button).icon = thumbnails.request(part, colour, true)
	for slot: String in Minifig.SLOTS:
		var button: Button = _slot_buttons[slot]
		var part: String = figure.part_for_colour(slot)
		if button.icon == null and not part.is_empty():
			button.icon = thumbnails.request(part, int(figure.colours[slot]), true)


# -- building the panel ------------------------------------------------------


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

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var title := Label.new()
	title.text = "Minifigure"
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	var called := Label.new()
	called.text = "Name"
	called.add_theme_font_size_override("font_size", 12)
	called.modulate = Color(1, 1, 1, 0.7)
	header.add_child(called)
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(170, 0)
	_name.placeholder_text = "Saruman"
	_name.tooltip_text = ("What the figure is called. It is the name of its "
		+ "sub-model in the saved file, and of the figure kept for next time")
	_name.text_changed.connect(func(text: String) -> void: figure.name = text)
	header.add_child(_name)
	_button(header, "Surprise me", _surprise,
		"A figure from real parts in colours they come in")
	_button(header, "Close", close, "Back to the model (Escape)")

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	body.add_child(_build_slots())
	body.add_child(_build_picker())
	body.add_child(_build_figure())


func _build_slots() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(200, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var group := ButtonGroup.new()
	for slot: String in Minifig.SLOTS:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = false
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("icon_max_width", 34)
		button.custom_minimum_size = Vector2(0, 40)
		button.clip_text = true
		button.pressed.connect(_choose_slot.bind(slot))
		list.add_child(button)
		_slot_buttons[slot] = button
	return scroll


func _build_picker() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_search = LineEdit.new()
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _fill_grid())
	row.add_child(_search)
	_found = Label.new()
	_found.add_theme_font_size_override("font_size", 11)
	_found.modulate = Color(1, 1, 1, 0.6)
	row.add_child(_found)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)
	scroll.resized.connect(func() -> void:
		_grid.columns = maxi(2, int((scroll.size.x - 14.0) / (CELL + 4))))

	_colour_note = Label.new()
	_colour_note.add_theme_font_size_override("font_size", 11)
	_colour_note.modulate = Color(1, 1, 1, 0.65)
	_colour_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_colour_note)
	_palette = FlowContainer.new()
	_palette.add_theme_constant_override("h_separation", 2)
	_palette.add_theme_constant_override("v_separation", 2)
	column.add_child(_palette)
	return column


func _build_figure() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(250, 0)

	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(250, 300)
	frame.tooltip_text = "Drag to turn it"
	frame.gui_input.connect(_on_preview_input)
	column.add_child(frame)
	_viewport = SubViewport.new()
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	# A world of its own, so the figure is not drawn into the model and
	# the model is not drawn behind the figure. Set before it enters the
	# tree, which is when the world is made.
	var world := World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.87, 0.87, 0.88)
	environment.ambient_light_energy = BrickWorld.light_energy(0.65)
	world.environment = environment
	_viewport.world_3d = world
	frame.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.near = 5.0
	_camera.far = 4000.0
	_viewport.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	key.light_energy = BrickWorld.light_energy(0.95)
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14.0, 150.0, 0.0)
	fill.light_energy = BrickWorld.light_energy(0.4)
	_viewport.add_child(fill)
	_stage = BrickWorld.new()
	_stage.library = library
	_viewport.add_child(_stage)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 11)
	_summary.modulate = Color(1, 1, 1, 0.65)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_button(buttons, "Keep", _keep, "Keep this figure to use again")
	var place: Button = _button(buttons, "Place in model", _place,
		"Stand it on a stud: point, R to turn it, click to put it down")
	place.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))

	var kept := Label.new()
	kept.text = "Kept"
	kept.add_theme_font_size_override("font_size", 12)
	kept.modulate = Color(1, 1, 1, 0.7)
	column.add_child(kept)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 60)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_shelf = VBoxContainer.new()
	_shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelf.add_theme_constant_override("separation", 2)
	scroll.add_child(_shelf)
	return column


func _button(row: Container, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	# Never keeps the keyboard, like every button in the app: a focused
	# button eats the keys the model wants.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	row.add_child(button)
	return button


# -- choosing ----------------------------------------------------------------


func _refresh_all() -> void:
	_refresh_slots()
	_choose_slot(_slot)
	_restage()
	_fill_shelf()


func _choose_slot(slot: String) -> void:
	_slot = slot
	(_slot_buttons[slot] as Button).set_pressed_no_signal(true)
	var noun: String = str(Minifig.TITLES[slot]).to_lower()
	_search.placeholder_text = "Search %s…" % noun
	_search.text = ""
	_search.editable = not Minifig.COLOUR_ONLY.has(slot)
	_fill_grid()
	_fill_palette()


func _refresh_slots() -> void:
	for slot: String in Minifig.SLOTS:
		var button: Button = _slot_buttons[slot]
		var part: String = figure.part_for_colour(slot)
		var what: String = "none"
		if not part.is_empty():
			var info: PartLibrary.PartInfo = library.parts.get(part)
			what = _short(info.name if info != null else part)
		if part in [Minifig.PLAIN_HIPS, Minifig.PLAIN_LEGS, "973", "3626c", "3626b"]:
			what = "plain"
		if Minifig.COLOUR_ONLY.has(slot) or what == "plain":
			what = "%s, %s" % [what, library.color(int(figure.colours[slot])).name] \
				if what == "plain" else library.color(int(figure.colours[slot])).name
		if slot == "hips" and figure.is_short():
			what = "one piece with the short legs"
		button.text = "%s\n%s" % [Minifig.TITLES[slot], what]
		button.tooltip_text = "%s: %s" % [Minifig.TITLES[slot], what]
		button.icon = null if part.is_empty() else thumbnails.request(
			part, int(figure.colours[slot]), true)


## A part's name without what every name in the slot says.
static func _short(full: String) -> String:
	var text: String = full.strip_edges().replace("  ", " ")
	for lead: String in ["Minifig Torso with ", "Minifig Head with ",
			"Minifig Hips and Legs ", "Minifig Hips with ", "Minifig Leg Right with ",
			"Minifig "]:
		if text.begins_with(lead):
			return text.substr(lead.length())
	return text


func _fill_grid() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	if Minifig.COLOUR_ONLY.has(_slot):
		_found.text = "the same moulding on every figure — choose a colour"
		return
	var words: PackedStringArray = _search.text.to_lower().split(" ", false)
	var all: Array[PartLibrary.PartInfo] = Minifig.choices(library, _slot)
	var shown: int = 0
	var matching: int = 0
	if Minifig.OPTIONAL.has(_slot) and words.is_empty():
		_grid.add_child(_cell(null))
	for info: PartLibrary.PartInfo in all:
		if not _matches(info, words):
			continue
		matching += 1
		if shown < MOST_SHOWN:
			_grid.add_child(_cell(info))
			shown += 1
	_found.text = ("%d" % matching) if matching <= MOST_SHOWN \
		else "%d of %d — search to narrow" % [MOST_SHOWN, matching]


static func _matches(info: PartLibrary.PartInfo, words: PackedStringArray) -> bool:
	if words.is_empty():
		return true
	var haystack: String = (info.id + " " + info.name).to_lower()
	for word: String in words:
		if not haystack.contains(word):
			return false
	return true


func _cell(info: PartLibrary.PartInfo) -> Button:
	var cell := Button.new()
	cell.toggle_mode = true
	cell.focus_mode = Control.FOCUS_NONE
	cell.custom_minimum_size = Vector2(CELL, CELL)
	# A shade lighter than the panel, so a black hat on it is a hat.
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.3, 0.32, 0.36) if state.begins_with("hover") \
			else Color(0.24, 0.26, 0.3)
		back.set_corner_radius_all(4)
		if state.ends_with("pressed"):
			back.border_color = Color(1.0, 0.92, 0.55)
			back.set_border_width_all(2)
		cell.add_theme_stylebox_override(state, back)
	cell.expand_icon = true
	cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var id: String = "" if info == null else info.id
	cell.set_meta("part", id)
	cell.set_pressed_no_signal(str(figure.parts.get(_slot, "")) == id)
	if info == null:
		cell.text = "none"
		cell.tooltip_text = "Nothing in this slot"
	else:
		cell.tooltip_text = "%s\n%s" % [info.id, info.name.strip_edges().replace("  ", " ")]
		cell.icon = thumbnails.request(info.id, int(figure.colours[_slot]), true)
	cell.pressed.connect(_choose_part.bind(id))
	return cell


func _choose_part(id: String) -> void:
	if _slot == "torso":
		figure.dress_torso(id)
	else:
		figure.parts[_slot] = id
	for cell: Node in _grid.get_children():
		(cell as Button).set_pressed_no_signal(str(cell.get_meta("part")) == id)
	_refresh_slots()
	_mark_swatches()
	_restage()


func _fill_palette() -> void:
	for child: Node in _palette.get_children():
		_palette.remove_child(child)
		child.queue_free()
	_swatches.clear()
	var offered: Array[PartLibrary.BrickColor] = []
	var shown: int = int(figure.colours[_slot])
	for code: int in library.colors:
		if code in PartsBin.NOT_A_COLOUR:
			continue
		if library.is_current(code) or code == shown:
			offered.append(library.colors[code])
	offered.sort_custom(PartsBin._in_palette_order)
	for colour: PartLibrary.BrickColor in offered:
		var swatch := PartsBin.Swatch.new(colour)
		swatch.set_pressed_no_signal(colour.code == shown)
		swatch.pressed.connect(_choose_colour.bind(colour.code))
		_swatches[colour.code] = swatch
		_palette.add_child(swatch)
	_mark_swatches()


## A dot on the colours the part in the slot is made in, from the
## inventories; for a print, those of the moulding it is printed on.
func _mark_swatches() -> void:
	var part: String = figure.part_for_colour(_slot)
	var info: PartLibrary.PartInfo = null if part.is_empty() \
		else Minifig.colours_of(library, part)
	for code: int in _swatches:
		var swatch: PartsBin.Swatch = _swatches[code]
		var made: int = 0
		if info != null and info.availability_known():
			if info.colors.has(code):
				made = 1
			elif info.never_made_in(code):
				made = -1
		swatch.made_in = made
		swatch.set_pressed_no_signal(code == int(figure.colours[_slot]))
		swatch.tooltip_text = library.color(code).name
		swatch.queue_redraw()
	var colour: PartLibrary.BrickColor = library.color(int(figure.colours[_slot]))
	var note: String = "%s: %s." % [Minifig.TITLES[_slot], colour.name]
	if info != null and info.availability_known():
		note += " A dot marks the %d colours %s%s comes in." % [info.colors.size(),
			info.id, "" if info.id == part else " (what %s is printed on)" % part]
	_colour_note.text = note


func _choose_colour(code: int) -> void:
	var was: int = int(figure.colours[_slot])
	figure.colours[_slot] = code
	# Plain arms are the torso's colour, and hips the legs', unless
	# somebody has made them otherwise.
	if _slot == "torso" and int(figure.colours["arms"]) == was:
		figure.colours["arms"] = code
	if _slot == "legs" and int(figure.colours["hips"]) == was:
		figure.colours["hips"] = code
	_mark_swatches()
	_refresh_slots()
	_fill_grid()
	_restage()


func _surprise() -> void:
	var called: String = _name.text
	figure = Minifig.surprise(library, _rng)
	figure.name = called
	_refresh_all()


func _keep() -> void:
	if _name.text.strip_edges().is_empty():
		_name.text = "Minifig"
	figure.name = _name.text.strip_edges()
	Minifig.keep(figure)
	_fill_shelf()


func _place() -> void:
	_keep()
	visible = false
	place_wanted.emit(figure.copy())


func _fill_shelf() -> void:
	for child: Node in _shelf.get_children():
		_shelf.remove_child(child)
		child.queue_free()
	var kept: Array[Minifig] = Minifig.shelf()
	if kept.is_empty():
		var none := Label.new()
		none.text = "Nothing kept yet. Keep or place a figure and it is here next time."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 11)
		none.modulate = Color(1, 1, 1, 0.5)
		_shelf.add_child(none)
	for one: Minifig in kept:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var open_it := Button.new()
		open_it.text = one.name
		open_it.focus_mode = Control.FOCUS_NONE
		open_it.alignment = HORIZONTAL_ALIGNMENT_LEFT
		open_it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_it.add_theme_font_size_override("font_size", 12)
		open_it.clip_text = true
		open_it.tooltip_text = "Put %s on the bench" % one.name
		open_it.pressed.connect(func() -> void:
			figure = one.copy()
			_name.text = figure.name
			_refresh_all())
		row.add_child(open_it)
		var forget := Button.new()
		forget.text = "×"
		forget.focus_mode = Control.FOCUS_NONE
		forget.tooltip_text = "Stop keeping %s" % one.name
		forget.pressed.connect(func() -> void:
			Minifig.forget(one.name)
			_fill_shelf())
		row.add_child(forget)
		_shelf.add_child(row)


# -- the figure, turning -----------------------------------------------------


func _restage() -> void:
	if _stage == null:
		return
	_stage.clear()
	var parts: Array[Dictionary] = figure.assemble(library)
	var missing: int = 0
	for item: Dictionary in parts:
		var part: String = str(item["part"])
		if _stage.add_brick(part, int(item["color"]), item["at"]) == 0:
			missing += 1
			if library.request_mesh(part, true):
				_waiting[part] = true
	var printed: int = 0
	for item: Dictionary in parts:
		if str(item["part"]).contains("p"):
			printed += 1
	_summary.text = "%d parts%s%s" % [parts.size(),
		", %d of them printed" % printed if printed > 0 else "",
		" — fetching %d…" % missing if missing > 0 else ""]


func _on_geometry(part_id: String) -> void:
	if _waiting.erase(part_id) and visible:
		_restage()


func _on_thumbnail(part_id: String, color_code: int, _texture: ImageTexture) -> void:
	if not visible:
		return
	# Printed previews are asked for under a key of their own, so the one
	# that has just landed may be the plain one; ask again for ours.
	for cell: Node in _grid.get_children():
		if str(cell.get_meta("part")) == part_id \
				and color_code == int(figure.colours[_slot]):
			var texture: ImageTexture = thumbnails.request(part_id, color_code, true)
			if texture != null:
				(cell as Button).icon = texture
	for slot: String in Minifig.SLOTS:
		if figure.part_for_colour(slot) == part_id \
				and int(figure.colours[slot]) == color_code:
			var texture: ImageTexture = thumbnails.request(part_id, color_code, true)
			if texture != null:
				(_slot_buttons[slot] as Button).icon = texture


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_dragging = (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventMouseMotion and _dragging:
		_turn -= (event as InputEventMouseMotion).relative.x * 0.01
		_aim()


## Round the figure at a third of its height, a little above it: the
## view a person holding one has.
func _aim() -> void:
	var centre := Vector3(0.0, 58.0, 0.0)
	var reach: float = 330.0
	_camera.position = centre + Vector3(sin(_turn) * reach, 70.0, cos(_turn) * reach)
	_camera.look_at(centre, Vector3.UP)


## Its controls by name, which the web build tells the page where to
## find (main._tell_page), so a browser check can press them.
func controls_by_name() -> Dictionary:
	var named: Dictionary = {}
	for button: Node in find_children("*", "Button", true, false):
		match (button as Button).text:
			"Surprise me": named["minifig_surprise"] = button
			"Place in model": named["minifig_place"] = button
			"Keep": named["minifig_keep"] = button
			"Close": named["minifig_close"] = button
	for slot: String in _slot_buttons:
		named["minifig_" + slot] = _slot_buttons[slot]
	named["minifig_search"] = _search
	return named
