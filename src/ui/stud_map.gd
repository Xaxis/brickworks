## View, Stud directions: every part coloured by where its studs point, up,
## down or to one of the four sides, with a legend; and a session's
## view_board {"studs": true}, drawn the same (APP_UX5 seeing2).
##
## A session read one part's facing in words (attachment_points), and the
## design records say its misplacements sit "on real studs, wrong ones"
## (follower): what it lacked was which way the studs it built on point.
## ldraw-xray hands its agents a stud map for that, and Studio's builders
## turn on a stud view to find a SNOT brick's side studs.
##
## A part's studs are its male stud connectors (Lbm), each turned as the
## part is; a way is the nearest of the six. A part with studs one way is
## that way's colour; with studs up and one way more (a headlight brick, a
## brick with studs on a side) the other way's, since that is what tells it
## from a brick; with two ways or more besides up, black; with none, grey.
## Front is the side the front view looks at (+z), left the left view's.
##
## In the window the paint is BrickWorld's (set_painted), the picture only,
## as Stress's tints are: a part keeps its colour, the history no step. It
## follows the model as it changes, and gives way to View, Stress, which
## draws with the same layer.
class_name StudMap
extends Node

## The facings, in the legend's order.
const FACINGS: Array[String] = ["up", "down", "front", "back", "left", "right", "sides", "none"]
## Each facing's colour, sRGB as a part's own: six hues far apart for the
## six ways, black for studs two ways or more besides up, grey for none.
## None near magenta, which picks parts out (ModelShot.EDGE).
const COLOURS: Dictionary = {
	"up": Color(0.22, 0.66, 0.30),
	"down": Color(0.86, 0.16, 0.18),
	"front": Color(0.16, 0.40, 0.92),
	"back": Color(0.98, 0.82, 0.10),
	"left": Color(0.97, 0.50, 0.10),
	"right": Color(0.10, 0.80, 0.86),
	"sides": Color(0.13, 0.13, 0.14),
	"none": Color(0.64, 0.66, 0.69),
}
## Each colour's name, for a session reading the picture.
const COLOUR_NAMES: Dictionary = {"up": "green", "down": "red", "front": "blue",
	"back": "yellow", "left": "orange", "right": "cyan", "sides": "black", "none": "grey"}
## The six ways, in the world: front is +z, where the front view looks from.
const WAYS: Dictionary = {"up": Vector3.UP, "down": Vector3.DOWN, "front": Vector3.BACK,
	"back": Vector3.FORWARD, "left": Vector3.LEFT, "right": Vector3.RIGHT}
## The legend's words, a row each, in the window and the picture.
const WORDS: Dictionary = {"up": "Studs up", "down": "Studs down",
	"front": "Studs to the front", "back": "Studs to the back", "left": "Studs to the left",
	"right": "Studs to the right", "sides": "Studs on two sides or more", "none": "No studs"}

var world: BrickWorld
var library: PartLibrary
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass

var on: bool = false
## The legend over the model's top left corner while it is on (Shell puts it
## there): each facing the model has, its colour and how many parts.
var legend: PanelContainer
var _rows: VBoxContainer
## What the paint was worked out for: the world, its generation and revision.
var _painted_for: Array = []
## Each part's studs' ways in its own frame, by part id (see [method ways_of]).
var _ways: Dictionary = {}


func _init() -> void:
	legend = PanelContainer.new()
	legend.name = "StudMapLegend"
	legend.visible = false
	legend.mouse_filter = Control.MOUSE_FILTER_STOP
	legend.position = Vector2(12.0, 12.0)
	# Stress's panel's backing (StressPanel._build), so the two read as one
	# kind of thing.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.95)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 12
	backing.content_margin_right = 8
	backing.content_margin_top = 6
	backing.content_margin_bottom = 10
	legend.add_theme_stylebox_override("panel", backing)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	legend.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "Stud directions"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.tooltip_text = "Turn Stud directions off"
	close.pressed.connect(func() -> void: set_on(false))
	head.add_child(close)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	column.add_child(_rows)


## Turn the view on or off: on, every part painted at once and the legend
## shown; off, every part drawn in its own colour again.
func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	_painted_for = []
	if on:
		_paint()
		say.call("stud directions: each part coloured by where its studs point")
	else:
		world.set_painted({})
		say.call("stud directions off")
	legend.visible = on


func _process(_delta: float) -> void:
	if not on or world == null:
		return
	# Stress draws with the same layer: turned on, it takes the model over.
	if world.is_stressed():
		set_on(false)
		return
	if [world.get_instance_id(), world.generation(), world.revision] != _painted_for:
		_paint()


func _paint() -> void:
	_painted_for = [world.get_instance_id(), world.generation(), world.revision]
	var facing: Dictionary = facings(world, library, scenery, _ways)
	world.set_painted(paints(facing))
	_fill_legend(counts(facing))


func _fill_legend(counted: Dictionary) -> void:
	for row: Node in _rows.get_children():
		row.queue_free()
	for name: String in FACINGS:
		if int(counted.get(name, 0)) <= 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = COLOURS[name]
		swatch.custom_minimum_size = Vector2(16.0, 16.0)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var words := Label.new()
		words.text = WORDS[name]
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var count := Label.new()
		count.text = str(counted[name])
		count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.custom_minimum_size = Vector2(28.0, 0.0)
		row.add_child(count)
		_rows.add_child(row)
	legend.reset_size()


# -- where studs point ----------------------------------------------------------------


## Each part of [param world] but [param skip]'s: brick id -> its facing,
## one of [constant FACINGS]. [param cache] keeps each part's ways in its
## own frame between calls.
static func facings(world: BrickWorld, library: PartLibrary, skip: Dictionary,
		cache: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		if not skip.has(brick.id):
			out[brick.id] = facing_of(brick, library, cache)
	return out


## Where [param brick]'s studs point, one of [constant FACINGS].
static func facing_of(brick: BrickWorld.Brick, library: PartLibrary,
		cache: Dictionary = {}) -> String:
	var ways: Dictionary = {}
	for axis: Vector3 in ways_of(brick.part_id, library, cache):
		ways[way(brick.transform.basis * axis)] = true
	if ways.is_empty():
		return "none"
	if ways.size() == 1:
		return str(ways.keys()[0])
	if ways.size() == 2 and ways.has("up"):
		ways.erase("up")
		return str(ways.keys()[0])
	return "sides"


## The ways [param part_id]'s studs point in its own frame, each once.
static func ways_of(part_id: String, library: PartLibrary, cache: Dictionary = {}) -> PackedVector3Array:
	if cache.has(part_id):
		return cache[part_id]
	var out := PackedVector3Array()
	var part: Lbm.PartMesh = library.mesh_for(part_id) if library != null else null
	if part != null:
		for connector: Lbm.Connector in part.connectors:
			if connector.kind != "stud" or connector.gender != "male":
				continue
			var axis: Vector3 = connector.axis.normalized()
			var known: bool = false
			for seen: Vector3 in out:
				known = known or seen.dot(axis) > 0.99
			if not known:
				out.append(axis)
		cache[part_id] = out
	return out


## The nearest of the six ways to [param direction].
static func way(direction: Vector3) -> String:
	var best: String = "up"
	var most: float = -INF
	for name: String in WAYS:
		var along: float = direction.normalized().dot(WAYS[name])
		if along > most:
			most = along
			best = name
	return best


## [param facing]'s parts, each its facing's colour.
static func paints(facing: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in facing:
		out[brick_id] = COLOURS[facing[brick_id]]
	return out


## How many parts each facing has.
static func counts(facing: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for brick_id: int in facing:
		var name: String = facing[brick_id]
		out[name] = int(out.get(name, 0)) + 1
	return out


## What the map shows, in words for a session: each colour and its count,
## and the parts whose studs point anywhere but up, by number.
static func said(facing: Dictionary, world: BrickWorld, library: PartLibrary) -> String:
	var counted: Dictionary = counts(facing)
	var key := PackedStringArray()
	for name: String in FACINGS:
		if int(counted.get(name, 0)) > 0:
			key.append("%s %s (%d)" % [COLOUR_NAMES[name], _short(name), counted[name]])
	var lines := PackedStringArray([("Each part coloured by where its studs point, as View, Stud "
		+ "directions draws it: %s. Front is the side the front view looks at, left the left "
		+ "view's; a part with studs up and one way more is that way's colour.") % ", ".join(key)])
	var odd := PackedStringArray()
	var more: int = 0
	var ids: Array = facing.keys()
	ids.sort()
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = world.get_brick(brick_id)
		if facing[brick_id] in ["up", "none"] or brick == null:
			continue
		if odd.size() < 24:
			odd.append("#%d %s %s" % [brick_id, HandTools._part_name(library, brick.part_id),
				_short(facing[brick_id])])
		else:
			more += 1
	if not odd.is_empty():
		lines.append("Studs not up: %s%s." % [", ".join(odd),
			(", and %d more" % more) if more > 0 else ""])
	return "\n".join(lines)


static func _short(name: String) -> String:
	match name:
		"sides":
			return "two sides or more"
		"none":
			return "no studs"
	return name


# -- the legend in a picture ------------------------------------------------------------

const BAND_ROW := 34
const BAND_BACK := Color(1.0, 1.0, 1.0)
const BAND_INK := Color(0.09, 0.09, 0.10)


## [param picture] with the legend under it: a line saying what the colours
## are, then each facing [param counted] has, its colour, its words and how
## many, four to a row. Drawn by [param host], which is in the tree.
static func with_legend(host: Node, picture: Image, counted: Dictionary) -> Image:
	var shown: Array[String] = []
	for name: String in FACINGS:
		if int(counted.get(name, 0)) > 0:
			shown.append(name)
	var width: int = picture.get_width()
	var across: int = 4
	var rows: int = 1 + ceili(float(shown.size()) / float(across))
	var room := SubViewport.new()
	room.size = Vector2i(width, rows * BAND_ROW + 8)
	room.disable_3d = true
	room.transparent_bg = false
	room.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(room)
	var back := ColorRect.new()
	back.color = BAND_BACK
	back.size = Vector2(room.size)
	room.add_child(back)
	var rule := ColorRect.new()
	rule.color = Color(0.75, 0.77, 0.8)
	rule.size = Vector2(width, 1)
	room.add_child(rule)
	var title := Label.new()
	title.text = "Each part coloured by where its studs point (front: the side the front view sees)"
	title.position = Vector2(10, 4)
	title.size = Vector2(width - 20, BAND_ROW - 6)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", BAND_INK)
	title.clip_text = true
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room.add_child(title)
	var cell: float = float(width - 20) / float(across)
	for k: int in shown.size():
		var name: String = shown[k]
		var at := Vector2(10.0 + cell * float(k % across), 4.0 + BAND_ROW * float(1 + k / across))
		var swatch := ColorRect.new()
		swatch.color = COLOURS[name]
		swatch.position = at + Vector2(0, 5)
		swatch.size = Vector2(22, 22)
		room.add_child(swatch)
		var words := Label.new()
		words.text = "%s %d" % [_short(name), int(counted[name])]
		words.position = at + Vector2(30, 0)
		words.size = Vector2(cell - 36.0, BAND_ROW - 2)
		words.add_theme_font_size_override("font_size", 20)
		words.add_theme_color_override("font_color", BAND_INK)
		words.clip_text = true
		words.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		room.add_child(words)
	room.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawing: int = 1 if OS.has_feature("web") else 3
	for _n: int in drawing:
		await host.get_tree().process_frame
	await GpuFence.finished()
	var band: Image = room.get_texture().get_image()
	room.queue_free()
	if band == null or band.is_empty():
		return picture
	var out := Image.create(width, picture.get_height() + band.get_height(), false,
		Image.FORMAT_RGBA8)
	var top: Image = picture.duplicate() as Image
	top.convert(Image.FORMAT_RGBA8)
	band.convert(Image.FORMAT_RGBA8)
	out.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
	out.blit_rect(band, Rect2i(Vector2i.ZERO, band.get_size()), Vector2i(0, top.get_height()))
	return out
