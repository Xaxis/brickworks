## A part's picture in a grid, and what stands in its place until the
## picture is drawn.
##
## A grid of previews fills in over a second or two, and over much longer
## on the web, where most parts are a network fetch before they are a
## render. The tiles still waiting were empty squares, which look the same
## as a part with no picture at all, and a part that could not be drawn
## stayed one for ever. Now a tile that is waiting is a placeholder the
## size of the picture to come, with a band of light crossing it; the
## picture fades in over it when it lands; and a part that cannot be
## drawn says so.
##
## Nothing here runs per frame while waiting. The shimmer is one shader
## shared by every tile and driven by TIME, so a waiting tile costs a draw
## and no script. Only the fade processes, for a fifth of a second after a
## picture lands, and only on the tile it landed on.
##
## And only a tile in sight shimmers ([member in_sight]). A shader reading
## TIME has the whole window drawn again every frame it is on the window,
## and Godot culls a tile clipped out of a scrolled grid only once it is
## off the window too: in a 1280 x 860 browser the bin's first row out of
## sight sat inside the window, under the colours, and the page drew every
## frame standing still, a second of software rasterising each (2026-10-11).
##
## The tile never asks for its own picture. [PartThumbnails] is told which
## tiles are in sight (see [ThumbTile.Sight]) and draws those, nearest the
## eye first, and hands each its picture.
class_name ThumbTile
extends Control

enum State { LOADING, READY, FAILED }

const FADE_SECONDS := 0.2

static var _shimmer: ShaderMaterial

var part_id: String = ""
var color_code: int = 0
## Drawn with its print; see [method PartThumbnails.request].
var printed: bool = false
## Words on the placeholder, for a tile with no label of its own, so that
## a tile can be told from its neighbours while it waits.
var caption: String = ""

var state: State = State.LOADING
## The picture, or while it waits for one in another colour, the one it had.
var texture: Texture2D
## The picture a recoloured tile had, faded out as its new one fades in.
var _was: Texture2D
## How far the picture has faded in, 0 to 1.
var _shown: float = 1.0

## Whether the tile can be seen, which a grid's [ThumbTile.Sight] says;
## a tile outside a grid is taken to be. Waiting out of sight it is the
## placeholder alone, without the shimmer.
var in_sight: bool = true:
	set(value):
		if value == in_sight:
			return
		in_sight = value
		if state == State.LOADING:
			material = _shimmer_material() if in_sight and texture == null else null


func _init(part: String = "", colour: int = 0, with_print: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	show_part(part, colour, with_print)


## Point the tile at a part. A tile already showing that picture keeps it;
## any other goes back to waiting. An empty part shows nothing, at the
## same size, so whatever sits beside it does not move.
##
## With [param keep], the same part in another colour keeps the picture it
## has until the new one lands: a grid recoloured went blank, every tile at
## once, for the seconds its pictures took (walk180 A3).
func show_part(part: String, colour: int, with_print: bool = false, keep: bool = false) -> void:
	if part == part_id and colour == color_code and with_print == printed \
			and state == State.READY:
		return
	var kept: Texture2D = texture if keep and part == part_id and with_print == printed else null
	part_id = part
	color_code = colour
	printed = with_print
	texture = kept
	if part.is_empty():
		_settle(State.READY)
	else:
		_settle(State.LOADING)


func key() -> String:
	return PartThumbnails.key_for(part_id, color_code, printed)


## The picture has landed. Faded in over the placeholder, unless it was
## to hand when the tile was made: a grid redrawn for a new colour whose
## pictures are cached should not flash.
func show_picture(picture: Texture2D, fade: bool = true) -> void:
	var was: Texture2D = texture if state == State.LOADING else null
	texture = picture
	_settle(State.READY)
	_was = was if fade else null
	_shown = 0.0 if fade else 1.0
	set_process(fade)


## The part cannot be drawn: no geometry in this build, or the fetch for
## it failed. Said quietly, and the shimmer stops, because a placeholder
## that never resolves reads as a page that never finishes loading.
func show_failed() -> void:
	texture = null
	_settle(State.FAILED)


func _settle(now: State) -> void:
	state = now
	_shown = 1.0
	_was = null
	set_process(false)
	material = _shimmer_material() if now == State.LOADING and in_sight and texture == null else null
	queue_redraw()


func _process(delta: float) -> void:
	_shown = minf(1.0, _shown + delta / FADE_SECONDS)
	queue_redraw()
	if _shown >= 1.0:
		_was = null
		set_process(false)


static func _shimmer_material() -> ShaderMaterial:
	if _shimmer == null:
		_shimmer = ShaderMaterial.new()
		_shimmer.shader = preload("res://src/ui/shimmer.gdshader")
	return _shimmer


## The square the picture is drawn in: the previews are square, kept
## square and centred, as the TextureRect that used to hold them did.
func _square() -> Rect2:
	var side: float = minf(size.x, size.y)
	return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))


func _draw() -> void:
	match state:
		State.LOADING:
			# Another colour's picture, kept till this one's is drawn.
			if texture != null:
				draw_texture_rect(texture, _square(), false)
			else:
				_draw_placeholder(1.0)
		State.READY:
			if texture == null:
				return
			if _shown < 1.0:
				# Out as the picture comes in, so nothing blinks between them:
				# the placeholder, or the picture it had in another colour.
				if _was != null:
					draw_texture_rect(_was, _square(), false)
				else:
					_draw_placeholder(1.0 - _shown)
			var eased: float = 1.0 - (1.0 - _shown) * (1.0 - _shown)
			draw_texture_rect(texture, _square(), false, Color(1, 1, 1, eased))
		State.FAILED:
			_draw_failed()


## A rounded square of faint light where the picture will be, smaller
## than the picture so it reads as a stand-in rather than as a box. With
## a caption, the square is smaller still and the caption sits under it,
## where a label would: written across it, a long id ran off both sides.
func _draw_placeholder(strength: float) -> void:
	var square: Rect2 = _square()
	var block: Rect2 = square.grow(-square.size.x * 0.12)
	if not caption.is_empty():
		var side: float = square.size.x * 0.6
		block = Rect2(Vector2(square.get_center().x - side * 0.5,
			square.position.y + square.size.y * 0.08), Vector2(side, side))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.075 * strength)
	box.set_corner_radius_all(int(clampf(block.size.x * 0.12, 3.0, 8.0)))
	draw_style_box(box, block)
	if not caption.is_empty():
		draw_string(get_theme_default_font(), Vector2(0.0, block.end.y + 11.0), caption,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color(1, 1, 1, 0.4 * strength))


## A brick in outline with a stroke through it, and "no preview" under it
## where there is room. Dim: it is a fact about one part, not an alarm.
func _draw_failed() -> void:
	var square: Rect2 = _square()
	var ink := Color(1, 1, 1, 0.28)
	var roomy: bool = square.size.y >= 44.0
	var unit: float = square.size.x
	var body := Vector2(roundf(unit * 0.4), roundf(unit * 0.19))
	var stud := Vector2(roundf(body.x * 0.24), roundf(unit * 0.065))
	var middle: Vector2 = square.get_center() - Vector2(0.0, unit * 0.07 if roomy else 0.0)
	var outline := Rect2(middle - body * 0.5 + Vector2(0.0, stud.y * 0.5), body)
	# The brick's silhouette as one antialiased path, studs and all. Hard
	# one-pixel lines lost the brick's top edge entirely: the app is drawn
	# at 0.875 of its design size in a 1400-wide window, and a line that
	# thin can fall between two rows of pixels and cover neither.
	var top: float = outline.position.y
	var path := PackedVector2Array([outline.position + Vector2(0.0, body.y),
		outline.position])
	for along: float in [0.27, 0.73]:
		var left: float = outline.position.x + body.x * along - stud.x * 0.5
		path.append_array([Vector2(left, top), Vector2(left, top - stud.y),
			Vector2(left + stud.x, top - stud.y), Vector2(left + stud.x, top)])
	path.append_array([Vector2(outline.end.x, top), outline.end,
		outline.position + Vector2(0.0, body.y)])
	draw_polyline(path, ink, 1.25, true)
	# Corner to corner across the brick and its studs, and no further.
	draw_line(Vector2(outline.position.x - 2.0, outline.end.y + 2.0),
		Vector2(outline.end.x + 2.0, top - stud.y - 2.0), ink, 1.25, true)
	if roomy:
		draw_string(get_theme_default_font(), Vector2(0.0, outline.end.y + 14.0), "no preview",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color(1, 1, 1, 0.42))


## Which tiles of one scrolling grid are in sight, worked out again only
## when something that decides it has moved.
##
## Asked every frame by whoever owns the grid, and cheap when nothing has
## changed: a handful of numbers compared. When something has, the answer
## is the rows on screen top to bottom, then the next screenful below,
## then half a screenful above, nearest first: the order the pictures
## should be drawn in, so that the ones being looked at come first and a
## scroll finds the next ones already there.
class Sight extends RefCounted:
	var scroll: ScrollContainer
	var grid: GridContainer
	var _last: Array = []

	func _init(over: ScrollContainer, of: GridContainer) -> void:
		scroll = over
		grid = of

	## Forget what was last seen, so the next [method changed] says yes.
	func forget() -> void:
		_last = []

	## Whether what is in sight may have changed since this last said so.
	func changed() -> bool:
		var count: int = grid.get_child_count()
		var seen: Vector2 = _window()
		# The first and last cells by identity, because a grid rebuilt for
		# a new colour has the same number of cells in the same places and
		# none of the same tiles.
		var first: int = grid.get_child(0).get_instance_id() if count > 0 else 0
		var last: int = grid.get_child(count - 1).get_instance_id() if count > 0 else 0
		var height: float = (grid.get_child(0) as Control).size.y if count > 0 else 0.0
		var now: Array = [seen, count, grid.columns, first, last, height]
		if now == _last:
			return false
		_last = now
		return true

	## The tiles in the order they should be drawn. Cells whose tile is
	## not a ThumbTile (the minifigure grid's "none") are passed over.
	func tiles() -> Array[ThumbTile]:
		var out: Array[ThumbTile] = []
		var count: int = grid.get_child_count()
		if count == 0:
			return out
		var cell_height: float = (grid.get_child(0) as Control).size.y
		var seen: Vector2 = _window()
		# Not laid out yet. Asked again next frame, when it will have been.
		if cell_height <= 0.0:
			return out
		var columns: int = maxi(grid.columns, 1)
		# Nothing showing: a bin folded into its dock is still "visible".
		if seen.y <= seen.x:
			_mark_in_sight(0, 0, columns)
			return out
		var row_height: float = cell_height + grid.get_theme_constant("v_separation")
		var rows: int = ceili(float(count) / columns)
		var top: int = clampi(floori(seen.x / row_height), 0, rows)
		var bottom: int = clampi(ceili(seen.y / row_height), 0, rows)
		_mark_in_sight(top, bottom, columns)
		var screen: int = maxi(bottom - top, 1)
		var order: Array[int] = []
		for row: int in range(top, bottom):
			order.append(row)
		for row: int in range(bottom, mini(rows, bottom + screen)):
			order.append(row)
		for row: int in range(top - 1, maxi(-1, top - 1 - ceili(screen * 0.5)), -1):
			order.append(row)
		for row: int in order:
			for column: int in columns:
				var index: int = row * columns + column
				if index >= count:
					break
				# Asked first: Godot reports a missing key as an error even
				# with a default of null, once a frame for every such cell.
				var cell: Node = grid.get_child(index)
				var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
				if tile is ThumbTile:
					out.append(tile)
		return out

	## Tiles in the rows from [param top] up to [param bottom] are in sight,
	## and only they shimmer while they wait: see [member ThumbTile.in_sight].
	func _mark_in_sight(top: int, bottom: int, columns: int) -> void:
		for index: int in grid.get_child_count():
			var cell: Node = grid.get_child(index)
			var tile: Variant = cell.get_meta("tile") if cell.has_meta("tile") else null
			if tile is ThumbTile:
				var row: int = index / columns
				(tile as ThumbTile).in_sight = row >= top and row < bottom

	## The stretch of the grid that can be seen, top and bottom in the
	## grid's own coordinates, after every clipping parent has had its
	## say: a parts bin folded into its dock is still "visible", and
	## sits inside a holder zero pixels wide.
	func _window() -> Vector2:
		if not grid.is_visible_in_tree():
			return Vector2.ZERO
		var seen: Rect2 = scroll.get_global_rect()
		var above: Node = scroll.get_parent()
		while above is Control:
			var holder: Control = above
			if holder.clip_contents:
				seen = seen.intersection(holder.get_global_rect())
			above = holder.get_parent()
		seen = seen.intersection(scroll.get_viewport_rect())
		if not seen.has_area():
			return Vector2.ZERO
		var origin: float = grid.get_global_rect().position.y
		return Vector2(seen.position.y - origin, seen.end.y - origin)
