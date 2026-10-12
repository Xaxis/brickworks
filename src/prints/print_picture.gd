## A picture laid on a print: a photograph, a logo, a drawing brought in
## from a file, kept as itself and placed — moved, scaled, turned, cropped,
## made see-through — until it is where it should be.
##
## The source is never changed. What the layer shows is made from it in
## steps, each kept until something it depends on changes: the crop cut
## out and resized to its size on the canvas (the engine's own resize, so
## a photograph comes down cleanly), its background cleared, its colours
## mapped to LEGO's inks (a pad print is a few flat inks; a full-colour
## print is a choice too), and then put in place, turned if it is turned.
## Moving it only puts the prepared picture somewhere else, so dragging it
## keeps up with a hand.
class_name PrintPicture
extends RefCounted

## The largest a source is kept: a phone photograph is cut down to this on
## the way in, which is still four times the finest canvas.
const MOST_SOURCE := 2048
## How near a colour has to be to the corners' to count as background, in
## Oklab distance.
const BACKGROUND := 0.09

var source: Image
## Where its middle is on the canvas, in canvas pixels.
var centre := Vector2.ZERO
## Canvas pixels for each pixel of the source.
var scale: float = 1.0
## Turned clockwise, in degrees.
var angle: float = 0.0
## The part of the source that is used, as fractions of it.
var crop := Rect2(0, 0, 1, 1)
var opacity: float = 1.0
## Mapped to LEGO's inks: the palette's nearest colour for every pixel,
## and at most [member inks] of them (0: as many as it needs).
var lego: bool = false
var inks: int = 0
## Whatever is the colour of its corners made clear: a logo's white.
var clear_back: bool = false
## Mirrored left to right.
var flipped: bool = false

## The palette the inks come from, as colours.
var palette: Array[Color] = []

var _prepared: Image
var _prepared_key: String = ""
var _palette_lab: Array[Vector3] = []


func _init(picture: Image = null) -> void:
	if picture == null:
		return
	source = picture.duplicate()
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	var longest: int = maxi(source.get_width(), source.get_height())
	if longest > MOST_SOURCE:
		var shrink: float = float(MOST_SOURCE) / longest
		source.resize(maxi(1, int(source.get_width() * shrink)),
			maxi(1, int(source.get_height() * shrink)), Image.INTERPOLATE_LANCZOS)


## Everything that places it, for undo.
func params() -> Dictionary:
	return {"centre": centre, "scale": scale, "angle": angle, "crop": crop, "opacity": opacity,
		"lego": lego, "inks": inks, "clear_back": clear_back, "flipped": flipped}


func set_params(values: Dictionary) -> void:
	centre = values.get("centre", centre)
	scale = values.get("scale", scale)
	angle = values.get("angle", angle)
	crop = values.get("crop", crop)
	opacity = values.get("opacity", opacity)
	lego = values.get("lego", lego)
	inks = values.get("inks", inks)
	clear_back = values.get("clear_back", clear_back)
	flipped = values.get("flipped", flipped)


## The crop's size in source pixels.
func cropped_size() -> Vector2:
	return Vector2(maxf(1.0, crop.size.x * source.get_width()),
		maxf(1.0, crop.size.y * source.get_height()))


## Its size on the canvas, before it is turned.
func size_on_canvas() -> Vector2:
	return cropped_size() * scale


## Fit it into a box of the canvas — the face's extent — whole (or, with
## [param cover], covering it), centred.
func fit(box: Rect2, cover: bool = false) -> void:
	var size: Vector2 = cropped_size()
	var across: float = box.size.x / size.x
	var down: float = box.size.y / size.y
	scale = maxf(across, down) if cover else minf(across, down)
	centre = box.get_center()
	angle = 0.0


## The four corners on the canvas, turned: for drawing its outline.
func corners() -> PackedVector2Array:
	var half: Vector2 = size_on_canvas() * 0.5
	var out := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		out.append(centre + corner.rotated(deg_to_rad(angle)))
	return out


## Whether a canvas point is on it.
func covers(point: Vector2) -> bool:
	var local: Vector2 = (point - centre).rotated(-deg_to_rad(angle))
	var half: Vector2 = size_on_canvas() * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y


## The picture as the layer shows it, on a canvas this size.
func render(w: int, h: int) -> Image:
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	if source == null:
		return out
	var prepared: Image = _prepare()
	var size := Vector2i(prepared.get_width(), prepared.get_height())
	if absf(fposmod(angle, 360.0)) < 0.01 or absf(fposmod(angle, 360.0) - 360.0) < 0.01:
		var at := Vector2i((centre - Vector2(size) * 0.5).round())
		out.blit_rect(prepared, Rect2i(Vector2i.ZERO, size), at)
		return out
	# Turned: every canvas pixel in its reach looks back into the prepared
	# picture, the nearest pixel, on the raw bytes.
	var turn: float = deg_to_rad(angle)
	var reach: Rect2 = Rect2(corners()[0], Vector2.ZERO)
	for corner: Vector2 in corners():
		reach = reach.expand(corner)
	var x0: int = maxi(0, floori(reach.position.x))
	var y0: int = maxi(0, floori(reach.position.y))
	var x1: int = mini(w - 1, ceili(reach.end.x))
	var y1: int = mini(h - 1, ceili(reach.end.y))
	var from: PackedInt32Array = prepared.get_data().to_int32_array()
	var to: PackedInt32Array = PackedInt32Array()
	to.resize(w * h)
	var c: float = cos(-turn)
	var s: float = sin(-turn)
	var half: Vector2 = Vector2(size) * 0.5
	for y: int in range(y0, y1 + 1):
		var dy: float = float(y) + 0.5 - centre.y
		for x: int in range(x0, x1 + 1):
			var dx: float = float(x) + 0.5 - centre.x
			var u: int = floori(dx * c - dy * s + half.x)
			var v: int = floori(dx * s + dy * c + half.y)
			if u >= 0 and v >= 0 and u < size.x and v < size.y:
				to[y * w + x] = from[v * size.x + u]
	out.set_data(w, h, false, Image.FORMAT_RGBA8, to.to_byte_array())
	return out


## The crop, at its size on the canvas, its background cleared, its
## colours mapped, see-through as asked: kept until one of those changes.
func _prepare() -> Image:
	var target := Vector2i(clampi(roundi(size_on_canvas().x), 1, 4096),
		clampi(roundi(size_on_canvas().y), 1, 4096))
	var key: String = "%s|%s|%s|%s|%s|%s|%s|%d" % [crop, target, opacity, lego, inks,
		clear_back, flipped, palette.size()]
	if key == _prepared_key and _prepared != null:
		return _prepared
	var region := Rect2i(Vector2i((crop.position * Vector2(source.get_size())).round()),
		Vector2i((crop.size * Vector2(source.get_size())).round()))
	region = region.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	if region.size.x < 1 or region.size.y < 1:
		region = Rect2i(Vector2i.ZERO, source.get_size())
	var picture: Image = source.get_region(region)
	var background: Array[Vector3] = []
	if clear_back:
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(picture.get_width() - 1, 0),
				Vector2i(0, picture.get_height() - 1),
				Vector2i(picture.get_width() - 1, picture.get_height() - 1)]:
			background.append(Mosaic._oklab(picture.get_pixelv(corner)))
	var shrinking: bool = target.x < picture.get_width()
	picture.resize(target.x, target.y,
		Image.INTERPOLATE_LANCZOS if shrinking else Image.INTERPOLATE_BILINEAR)
	if flipped:
		picture.flip_x()
	_prepared = _treat(picture, background)
	_prepared_key = key
	return _prepared


## Clear the background, map to inks and apply the opacity, a pixel at a
## time on the raw bytes, each distinct colour worked out once.
func _treat(picture: Image, background: Array[Vector3]) -> Image:
	if background.is_empty() and not lego and opacity >= 1.0:
		return picture
	if lego and _palette_lab.size() != palette.size():
		_palette_lab.clear()
		for colour: Color in palette:
			_palette_lab.append(Mosaic._oklab(colour))
	var pixels: PackedByteArray = picture.get_data()
	var count: int = pixels.size() / 4
	# Colours in steps of 16 a channel: 4096 at most to work out, which a
	# palette of sixty spaced as LEGO's are does not notice, where a
	# photograph's tens of thousands of distinct colours took seconds.
	var mapped: Dictionary = {}          ## 12-bit colour -> palette index, -1 clear, -2 kept
	var index_of := PackedInt32Array()
	index_of.resize(count)
	var uses := PackedInt32Array()
	uses.resize(maxi(1, palette.size()))
	for n: int in count:
		var o: int = n * 4
		var alpha: int = pixels[o + 3]
		if alpha < 128 and (lego or alpha == 0):
			index_of[n] = -1
			continue
		var key: int = ((pixels[o] >> 4) << 8) | ((pixels[o + 1] >> 4) << 4) | (pixels[o + 2] >> 4)
		var found: Variant = mapped.get(key)
		if found == null:
			var colour := Color8(pixels[o], pixels[o + 1], pixels[o + 2])
			var lab: Vector3 = Mosaic._oklab(colour)
			var value: int = -2
			for b: Vector3 in background:
				if lab.distance_to(b) < BACKGROUND:
					value = -1
			if value == -2 and lego and not palette.is_empty():
				value = _nearest(lab, [])
			mapped[key] = value
			found = value
		index_of[n] = int(found)
		if int(found) >= 0:
			uses[int(found)] += 1
	# At most so many inks: the most used, and every other pixel the
	# nearest of those.
	var keep: Dictionary = {}
	if lego and inks > 0 and not palette.is_empty():
		var order: Array = range(palette.size())
		order.sort_custom(func(a: int, b: int) -> bool: return uses[a] > uses[b])
		var kept: Array = []
		for index: int in order.slice(0, inks):
			if uses[index] > 0:
				kept.append(index)
		for index: int in palette.size():
			keep[index] = index if kept.has(index) else _nearest(_palette_lab[index], kept)
	for n: int in count:
		var o: int = n * 4
		var index: int = index_of[n]
		if index == -1:
			pixels[o + 3] = 0
			continue
		if index >= 0:
			var ink: Color = palette[int(keep.get(index, index))]
			pixels[o] = ink.r8
			pixels[o + 1] = ink.g8
			pixels[o + 2] = ink.b8
			pixels[o + 3] = 255
		if opacity < 1.0:
			pixels[o + 3] = int(pixels[o + 3] * opacity)
	picture.set_data(picture.get_width(), picture.get_height(), false, Image.FORMAT_RGBA8, pixels)
	return picture


## The palette's nearest colour to an Oklab colour, among [param among]
## (indices) or all of it.
func _nearest(lab: Vector3, among: Array) -> int:
	var best: int = 0
	var nearest: float = INF
	var candidates: Array = among if not among.is_empty() else range(_palette_lab.size())
	for index: int in candidates:
		var d: float = lab.distance_squared_to(_palette_lab[index])
		if d < nearest:
			nearest = d
			best = index
	return best


## How many inks the treated picture has: for a check, and for the panel.
func inks_used() -> int:
	var prepared: Image = _prepare()
	var seen: Dictionary = {}
	var pixels: PackedInt32Array = prepared.get_data().to_int32_array()
	for value: int in pixels:
		if (value >> 24) & 0xff > 0:
			seen[value] = true
	return seen.size()
