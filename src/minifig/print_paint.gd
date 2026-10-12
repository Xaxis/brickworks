## A print being drawn: layers of pixels, the tools that draw on them, and
## undo.
##
## Nothing here knows about parts. A print is drawn on a flat canvas whose
## pixels [PartPrints] maps onto the part's surface, so the painting is plain
## 2D work on [Image]s, done with the engine's own rectangle fills and blends
## wherever it can be, because GDScript touching pixels one at a time is the
## slow way and a stroke has to keep up with a hand.
##
## LEGO prints are flat colours with hard edges, pad-printed one ink at a
## time, so the brush, the shapes and the fill draw hard-edged in one colour
## each. Text is the exception: its edges keep the font's smoothing, which is
## what printed lettering looks like at the size it is read.
##
## A mirror is a drawing aid, not a layer property: with [member mirror] on,
## every mark is made again reflected about the canvas's middle, which is the
## middle of a face, a torso or a pair of legs.
class_name PrintPaint
extends RefCounted

## Most undo steps kept. A step holds a copy of one layer, about half a
## megabyte for a torso, so forty is twenty megabytes at worst.
const MOST_UNDO := 40
const CLEAR := Color(0, 0, 0, 0)


class Layer extends RefCounted:
	var name: String = "Layer"
	var image: Image
	var visible: bool = true

	func _init(called: String, w: int, h: int) -> void:
		name = called
		image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


var width: int = 0
var height: int = 0
var layers: Array[Layer] = []
var active: int = 0
## Every mark drawn twice, the second reflected left to right.
var mirror: bool = false

var _undo: Array = []
var _redo: Array = []
## The open stroke's undo step has been taken: a drag is one step however
## many stamps it makes.
var _stroking: bool = false
var _last := Vector2(-1, -1)


func _init(w: int = 256, h: int = 256) -> void:
	width = maxi(1, w)
	height = maxi(1, h)
	layers.append(Layer.new("Ink", width, height))


func layer() -> Layer:
	return layers[clampi(active, 0, layers.size() - 1)]


# -- layers -------------------------------------------------------------------


func add_layer(called: String = "") -> Layer:
	_remember_layers()
	var made := Layer.new(called if not called.is_empty() else "Layer %d" % (layers.size() + 1),
		width, height)
	layers.insert(active + 1, made)
	active += 1
	return made


func remove_layer(index: int) -> bool:
	if layers.size() <= 1 or index < 0 or index >= layers.size():
		return false
	_remember_layers()
	layers.remove_at(index)
	active = clampi(active if active < index else active - 1, 0, layers.size() - 1)
	return true


## Move a layer up (towards the top of the stack, +1) or down.
func move_layer(index: int, by: int) -> bool:
	var to: int = index + by
	if index < 0 or index >= layers.size() or to < 0 or to >= layers.size():
		return false
	_remember_layers()
	var moving: Layer = layers[index]
	layers.remove_at(index)
	layers.insert(to, moving)
	active = to
	return true


func set_visible(index: int, shown: bool) -> void:
	if index >= 0 and index < layers.size():
		layers[index].visible = shown


## Every visible layer, bottom first, flattened.
func composite() -> Image:
	var out := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var whole := Rect2i(0, 0, width, height)
	for each: Layer in layers:
		if each.visible:
			out.blend_rect(each.image, whole, Vector2i.ZERO)
	return out


## Start again from a picture, on one layer: a template, a print read off a
## real part, or one made before. Scaled to the canvas.
func load_image(picture: Image, called: String = "Ink") -> void:
	_remember_layers()
	var copy: Image = picture.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	if copy.get_width() != width or copy.get_height() != height:
		copy.resize(width, height, Image.INTERPOLATE_NEAREST)
	var made := Layer.new(called, width, height)
	made.image = copy
	layers = [made]
	active = 0


## A picture onto a new layer of its own, fitted inside the canvas and
## centred: an imported drawing or photograph to trace or keep.
func place_image(picture: Image, called: String = "Picture") -> void:
	var copy: Image = picture.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	var scale: float = minf(float(width) / copy.get_width(), float(height) / copy.get_height())
	var w: int = maxi(1, int(copy.get_width() * scale))
	var h: int = maxi(1, int(copy.get_height() * scale))
	copy.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var made: Layer = add_layer(called)
	made.image.blit_rect(copy, Rect2i(0, 0, w, h), Vector2i((width - w) / 2, (height - h) / 2))


# -- undo ---------------------------------------------------------------------


func _remember(index: int) -> void:
	_push({"layer": index, "image": layers[index].image.duplicate(),
		"target": layers[index]})


func _remember_layers() -> void:
	_push({"layers": layers.duplicate(), "active": active})


func _push(step: Dictionary) -> void:
	_undo.append(step)
	if _undo.size() > MOST_UNDO:
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	return _swap(_undo, _redo)


func redo() -> bool:
	return _swap(_redo, _undo)


func _swap(from: Array, to: Array) -> bool:
	if from.is_empty():
		return false
	var step: Dictionary = from.pop_back()
	if step.has("layers"):
		to.append({"layers": layers.duplicate(), "active": active})
		layers.assign(step["layers"])
		active = clampi(int(step["active"]), 0, layers.size() - 1)
		return true
	var target: Layer = step["target"]
	to.append({"layer": step["layer"], "image": target.image.duplicate(), "target": target})
	target.image = step["image"]
	return true


# -- drawing ------------------------------------------------------------------


## Begin a mark on the active layer: one undo step from here to [method end].
func begin() -> void:
	if not _stroking:
		_remember(clampi(active, 0, layers.size() - 1))
		_stroking = true
	_last = Vector2(-1, -1)


func end() -> void:
	_stroking = false
	_last = Vector2(-1, -1)


## A brush mark from where the last one was to [param at]: round, hard,
## [param radius] pixels. [param color] with no alpha rubs out.
func brush_to(at: Vector2, radius: float, color: Color) -> void:
	var image: Image = layer().image
	var from: Vector2 = at if _last.x < 0.0 else _last
	_twice(func(a: Vector2, b: Vector2) -> void: stroke(image, a, b, radius, color),
		from, at)
	_last = at


## A straight line, square-ended with round joints, [param radius] thick.
func line(a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	begin()
	var image: Image = layer().image
	_twice(func(p: Vector2, q: Vector2) -> void: stroke(image, p, q, radius, color), a, b)
	end()


## A rectangle between two corners, filled or [param radius] thick.
func rectangle(a: Vector2, b: Vector2, radius: float, color: Color, filled: bool) -> void:
	begin()
	var image: Image = layer().image
	_twice(func(p: Vector2, q: Vector2) -> void:
		draw_rectangle(image, p, q, radius, color, filled), a, b)
	end()


## An ellipse in the box between two corners, filled or [param radius] thick.
func ellipse(a: Vector2, b: Vector2, radius: float, color: Color, filled: bool) -> void:
	begin()
	var image: Image = layer().image
	_twice(func(p: Vector2, q: Vector2) -> void:
		draw_ellipse(image, p, q, radius, color, filled), a, b)
	end()


## Fill the region of like colour round [param at] on the active layer.
func fill(at: Vector2i, color: Color) -> void:
	begin()
	var image: Image = layer().image
	flood(image, at, color)
	if mirror:
		flood(image, Vector2i(width - 1 - at.x, at.y), color)
	end()


## Words, their baseline's left end at [param at], [param size] pixels.
## Mirrored, they are drawn again centred on the reflected point rather
## than written backwards.
func text(at: Vector2, words: String, size: int, color: Color, font: Font = null) -> void:
	begin()
	var image: Image = layer().image
	var wide: float = write(image, at, words, size, color, font)
	if mirror:
		write(image, Vector2(width - at.x - wide, at.y), words, size, color, font)
	end()


## The colour under a point, from everything shown.
func colour_at(at: Vector2i) -> Color:
	if at.x < 0 or at.y < 0 or at.x >= width or at.y >= height:
		return CLEAR
	return composite().get_pixelv(at)


## Run a mark, and with the mirror on run it again reflected.
func _twice(mark: Callable, a: Vector2, b: Vector2) -> void:
	mark.call(a, b)
	if mirror:
		mark.call(_reflect(a), _reflect(b))


func _reflect(p: Vector2) -> Vector2:
	return Vector2(float(width) - p.x, p.y)


# -- pixels -------------------------------------------------------------------


## A filled disc, as one rectangle a row.
static func disc(image: Image, centre: Vector2, radius: float, color: Color) -> void:
	var r: float = maxf(radius, 0.5)
	var w: int = image.get_width()
	var h: int = image.get_height()
	var top: int = maxi(0, floori(centre.y - r))
	var bottom: int = mini(h - 1, ceili(centre.y + r))
	for y: int in range(top, bottom + 1):
		var dy: float = float(y) + 0.5 - centre.y
		if absf(dy) > r:
			continue
		var half: float = sqrt(r * r - dy * dy)
		var x0: int = maxi(0, roundi(centre.x - half))
		var x1: int = mini(w, roundi(centre.x + half))
		if x1 > x0:
			image.fill_rect(Rect2i(x0, y, x1 - x0, 1), color)


## Discs along a segment, close enough that the edge does not scallop.
static func stroke(image: Image, a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	var length: float = a.distance_to(b)
	var step: float = maxf(0.5, radius * 0.35)
	var count: int = maxi(1, ceili(length / step))
	for n: int in count + 1:
		disc(image, a.lerp(b, float(n) / count), radius, color)


static func draw_rectangle(image: Image, a: Vector2, b: Vector2, radius: float, color: Color,
		filled: bool) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	if filled:
		var rect := Rect2i(Vector2i(lo.round()), Vector2i((hi - lo).round()) + Vector2i.ONE)
		image.fill_rect(rect.intersection(Rect2i(0, 0, image.get_width(), image.get_height())),
			color)
		return
	var corners: Array[Vector2] = [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
	for n: int in 4:
		stroke(image, corners[n], corners[(n + 1) % 4], radius, color)


static func draw_ellipse(image: Image, a: Vector2, b: Vector2, radius: float, color: Color,
		filled: bool) -> void:
	var centre: Vector2 = (a + b) * 0.5
	var half := Vector2(absf(b.x - a.x), absf(b.y - a.y)) * 0.5
	if half.x < 0.5 or half.y < 0.5:
		stroke(image, a, b, radius, color)
		return
	if filled:
		var w: int = image.get_width()
		for y: int in range(maxi(0, floori(centre.y - half.y)),
				mini(image.get_height(), ceili(centre.y + half.y) + 1)):
			var dy: float = (float(y) + 0.5 - centre.y) / half.y
			if absf(dy) > 1.0:
				continue
			var across: float = half.x * sqrt(1.0 - dy * dy)
			var x0: int = maxi(0, roundi(centre.x - across))
			var x1: int = mini(w, roundi(centre.x + across))
			if x1 > x0:
				image.fill_rect(Rect2i(x0, y, x1 - x0, 1), color)
		return
	# Round it in steps no longer than a couple of pixels.
	var steps: int = clampi(ceili(PI * (half.x + half.y) / 2.0), 12, 720)
	var last: Vector2 = centre + Vector2(half.x, 0.0)
	for n: int in range(1, steps + 1):
		var angle: float = TAU * n / steps
		var here: Vector2 = centre + Vector2(cos(angle) * half.x, sin(angle) * half.y)
		stroke(image, last, here, radius, color)
		last = here


## Fill the run of pixels connected to [param at] that are the colour it
## is, a row at a time. On the raw bytes: a 400 x 320 canvas is 128,000
## pixels and get_pixel per pixel would take a second.
static func flood(image: Image, at: Vector2i, color: Color) -> int:
	var w: int = image.get_width()
	var h: int = image.get_height()
	if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h:
		return 0
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	# A pixel a number: R, G, B and A little-endian in one int, so a pixel
	# is compared in one step.
	var pixels: PackedInt32Array = image.get_data().to_int32_array()
	var target: int = pixels[at.y * w + at.x]
	var ink: int = color.r8 | (color.g8 << 8) | (color.b8 << 16) | (color.a8 << 24)
	# Clear pixels all count as clear, whatever colour they keep: what an
	# eraser leaves behind is not a colour anybody can see to aim at.
	var clear: bool = (target >> 24) & 0xff == 0
	if (clear and color.a8 == 0) or target == ink:
		return 0
	var filled: int = 0
	var stack: PackedInt32Array = PackedInt32Array([at.y * w + at.x])
	while not stack.is_empty():
		var index: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var here: int = pixels[index]
		if (((here >> 24) & 0xff == 0) if clear else here == target) == false:
			continue
		var y: int = index / w
		var row: int = y * w
		var x0: int = index - row
		while x0 > 0:
			var left: int = pixels[row + x0 - 1]
			if (((left >> 24) & 0xff == 0) if clear else left == target) == false:
				break
			x0 -= 1
		var x1: int = index - row
		while x1 < w - 1:
			var right: int = pixels[row + x1 + 1]
			if (((right >> 24) & 0xff == 0) if clear else right == target) == false:
				break
			x1 += 1
		var up_open: bool = false
		var down_open: bool = false
		for x: int in range(x0, x1 + 1):
			pixels[row + x] = ink
			filled += 1
			# One seed per run above and below, not one per pixel.
			if y > 0:
				var above: int = pixels[row - w + x]
				var fits: bool = ((above >> 24) & 0xff == 0) if clear else above == target
				if fits and not up_open:
					stack.append(row - w + x)
				up_open = fits
			if y < h - 1:
				var below: int = pixels[row + w + x]
				var fits_below: bool = ((below >> 24) & 0xff == 0) if clear else below == target
				if fits_below and not down_open:
					stack.append(row + w + x)
				down_open = fits_below
	image.set_data(w, h, false, Image.FORMAT_RGBA8, pixels.to_byte_array())
	return filled


## Words in a colour, from the font's own rendered glyphs: the text server
## draws them on the CPU, so this works the same headless, on the desktop
## and in a browser. Returns how wide they came out.
static func write(image: Image, at: Vector2, words: String, size: int, color: Color,
		font: Font = null) -> float:
	if words.is_empty():
		return 0.0
	if font == null:
		font = ThemeDB.fallback_font
	var server: TextServer = TextServerManager.get_primary_interface()
	var shaped: RID = server.create_shaped_text()
	server.shaped_text_add_string(shaped, words, font.get_rids(), size)
	var glyphs: Array = server.shaped_text_get_glyphs(shaped)
	var pen: float = at.x
	for glyph: Dictionary in glyphs:
		var face: RID = glyph["font_rid"]
		var index: int = int(glyph["index"])
		var at_size := Vector2i(int(glyph["font_size"]), 0)
		if face.is_valid() and index != 0:
			var sheet: int = server.font_get_glyph_texture_idx(face, at_size, index)
			if sheet >= 0:
				var atlas: Image = server.font_get_texture_image(face, at_size, sheet)
				var uv: Rect2 = server.font_get_glyph_uv_rect(face, at_size, index)
				var offset: Vector2 = server.font_get_glyph_offset(face, at_size, index)
				_blit_glyph(image, atlas, Rect2i(uv), Vector2(pen, at.y) + offset
					+ Vector2(float(glyph.get("x_off", 0.0)), float(glyph.get("y_off", 0.0))),
					color)
		pen += float(glyph["advance"]) * int(glyph.get("repeat", 1))
	server.free_rid(shaped)
	return pen - at.x


## One glyph's coverage, from the font's atlas, laid onto the image in a
## colour: the coverage is the ink's alpha.
static func _blit_glyph(image: Image, atlas: Image, from: Rect2i, to: Vector2,
		color: Color) -> void:
	if atlas == null or from.size.x <= 0 or from.size.y <= 0:
		return
	var piece: Image = atlas.get_region(from)
	piece.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = piece.get_data()
	for n: int in data.size() / 4:
		# LA8 converted: coverage is in alpha.
		var cover: int = data[n * 4 + 3]
		data[n * 4] = color.r8
		data[n * 4 + 1] = color.g8
		data[n * 4 + 2] = color.b8
		data[n * 4 + 3] = int(cover * color.a)
	piece.set_data(from.size.x, from.size.y, false, Image.FORMAT_RGBA8, data)
	image.blend_rect(piece, Rect2i(Vector2i.ZERO, from.size), Vector2i(to.round()))
