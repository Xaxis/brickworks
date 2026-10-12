## An HDR panorama a render is lit by (StudioRender.HDRIS), and what is
## learnt from it to light by: where its brightest light is and how much
## of all its light that is, its average brightness and colour, and a table
## for picking directions in proportion to their light, which is how Best
## casts shadows from all over a photographed place.
##
## Read from a small copy, 64 by 32: enough to find a window or the sun,
## and a few thousand pixels to walk in GDScript once per place.
class_name StudioPanorama
extends RefCounted

var texture: Texture2D
## Towards its brightest light, in its own frame, above the horizon.
var key: Vector3 = Vector3.UP
## The share of all its light within 25 degrees of that.
var key_share: float = 0.0
## Its light summed over the sphere (luminance times solid angle).
var total: float = 1.0
## Its average luminance, for setting its brightness.
var average: float = 1.0
## Its average colour, and its key's, at a luminance of one.
var tint: Color = Color(1, 1, 1)
var key_tint: Color = Color(1, 1, 1)
## The small copy, and the cumulative table over it.
var small: Image
var cdf: PackedFloat32Array = PackedFloat32Array()


## Read a panorama and learn it; null if it will not load.
static func read(path: String) -> StudioPanorama:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return null
	var made := StudioPanorama.new()
	made.texture = texture
	var image: Image = texture.get_image()
	if image == null:
		return made
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBF)
	image.resize(64, 32, Image.INTERPOLATE_LANCZOS)
	made.small = image
	made._learn()
	return made


func _learn() -> void:
	var wide: int = small.get_width()
	var tall: int = small.get_height()
	var sum: float = 0.0
	var weights: float = 0.0
	var brightest: float = -1.0
	cdf = PackedFloat32Array()
	cdf.resize(wide * tall)
	for y: int in tall:
		var down: float = PI * (float(y) + 0.5) / float(tall)
		var solid: float = sin(down) * (TAU / float(wide)) * (PI / float(tall))
		for x: int in wide:
			var level: float = small.get_pixel(x, y).get_luminance()
			sum += level * solid
			weights += solid
			cdf[y * wide + x] = sum
			# Above the horizon only: a key from under the floor lights
			# nothing anybody can see.
			if level > brightest and down < PI * 0.5:
				brightest = level
				key = direction(Vector2((float(x) + 0.5) / float(wide),
					(float(y) + 0.5) / float(tall)))
	total = maxf(sum, 0.0001)
	average = total / maxf(weights, 0.0001)
	for n: int in cdf.size():
		cdf[n] /= total
	var near_key: float = 0.0
	var colours := Color(0, 0, 0)
	var key_colours := Color(0, 0, 0)
	for y: int in tall:
		var down: float = PI * (float(y) + 0.5) / float(tall)
		var solid: float = sin(down) * (TAU / float(wide)) * (PI / float(tall))
		for x: int in wide:
			var way: Vector3 = direction(Vector2((float(x) + 0.5) / float(wide),
				(float(y) + 0.5) / float(tall)))
			var here: Color = small.get_pixel(x, y)
			colours += here * solid
			if way.dot(key) > cos(deg_to_rad(25.0)):
				near_key += here.get_luminance() * solid
				key_colours += here * solid
	key_share = clampf(near_key / total, 0.0, 1.0)
	tint = _level_of(colours)
	key_tint = _level_of(key_colours)


## A colour brought to a luminance of one.
static func _level_of(colour: Color) -> Color:
	var level: float = maxf(colour.get_luminance(), 0.0001)
	return Color(colour.r / level, colour.g / level, colour.b / level).clamp(
		Color(0, 0, 0), Color(2, 2, 2))


## A direction from a point of a panorama, as Godot's sky reads one: across
## is atan2(x, -z) from 0 to 1, down is acos(y) from 0 to 1.
static func direction(at: Vector2) -> Vector3:
	var around: float = at.x * TAU
	var down: float = at.y * PI
	return Vector3(sin(around) * sin(down), cos(down), -cos(around) * sin(down))


## The small copy's pixel a world direction falls on, the panorama turned
## [param turn] about the vertical.
func cell(way: Vector3, turn: float) -> Vector2i:
	var own: Vector3 = Basis(Vector3.UP, -turn) * way
	var around: float = atan2(own.x, -own.z)
	if around < 0.0:
		around += TAU
	var across: int = clampi(int(around / TAU * float(small.get_width())), 0,
		small.get_width() - 1)
	var down: int = clampi(int(acos(clampf(own.y, -1.0, 1.0)) / PI
		* float(small.get_height())), 0, small.get_height() - 1)
	return Vector2i(across, down)


## A direction picked in proportion to the panorama's light, from a point
## of the unit square.
func pick(at: Vector2) -> Vector3:
	var wide: int = small.get_width()
	var tall: int = small.get_height()
	var index: int = mini(cdf.bsearch(at.x), cdf.size() - 1)
	var x: int = index % wide
	var y: int = index / wide
	# Anywhere in the cell, not its middle: fewer, sharper copies of the
	# same shadow otherwise.
	var within := Vector2(at.y, fposmod(at.y * 7.31 + at.x * 3.17, 1.0))
	return direction(Vector2((float(x) + within.x) / float(wide),
		(float(y) + within.y) / float(tall)))
