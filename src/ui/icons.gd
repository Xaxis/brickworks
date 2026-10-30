## Pictures drawn from SVG, at the size they will actually be shown.
##
## Every picture is one SVG file under assets/ui, and nothing else: the
## pointer's cursors in assets/ui/cursors and the gestures the controls
## list draws in assets/ui/controls. They are kept as source (their
## .import files say "keep") and drawn here, at run time, at whatever
## density they are needed.
##
## Not imported as textures, because a texture is one picture at one
## size. A cursor is wanted at 32 pixels and at 64 for a screen with
## twice the density, and the interface is drawn at the canvas stretch
## times the browser's device ratio, which is 0.875 in the default
## window and 2 on a laptop's screen. An imported icon is soft at every
## one of those but the one it was imported at, and the same file has to
## serve the cursor and the picture of that cursor in the controls list.
class_name Icons
extends RefCounted

const CURSORS := "res://assets/ui/cursors/"
const CONTROLS := "res://assets/ui/controls/"

static var _sources: Dictionary = {}    ## path -> SVG text
static var _textures: Dictionary = {}   ## "path@height" -> ImageTexture


## The SVG itself, read once.
static func source(path: String) -> String:
	if not _sources.has(path):
		_sources[path] = FileAccess.get_file_as_string(path)
	return _sources[path]


## The picture drawn at a multiple of the size its SVG gives, or null if
## there is no such picture.
static func image(path: String, scale: float) -> Image:
	var svg: String = source(path)
	if svg.is_empty():
		return null
	var drawn := Image.new()
	if drawn.load_svg_from_string(svg, scale) != OK:
		return null
	drawn.convert(Image.FORMAT_RGBA8)
	return drawn


## How many screen pixels one unit of interface is drawn with, here.
##
## The canvas stretch and, in a browser, the device ratio (see
## main._match_screen_density) multiplied together: the number that turns
## an icon's size in the layout into its size in pixels.
static func density(of: CanvasItem) -> float:
	if of == null or not of.is_inside_tree():
		return 1.0
	var scale: Vector2 = of.get_viewport().get_final_transform().get_scale()
	return maxf(absf(scale.y), 0.25)


## A picture as a control, so many units tall, drawn at this density.
##
## The texture is made at the pixel size it will be shown at and the
## control sized to exactly that many pixels, then filtered by nearest:
## one texel to a pixel, so nothing is resampled. A linear filter at a
## fractional position — which is where a container puts things once the
## canvas is scaled — smeared every edge across two pixels.
static func picture(path: String, tall: float, at_density: float) -> TextureRect:
	var shown := TextureRect.new()
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var texture: ImageTexture = texture_for(path, tall, at_density)
	if texture == null:
		shown.custom_minimum_size = Vector2(tall, tall)
		return shown
	shown.texture = texture
	shown.custom_minimum_size = Vector2(texture.get_size()) / at_density
	return shown


## A control's icon so many units tall at this density: the picture drawn
## at the pixels it is shown at, and said to be [param tall] units, so a
## Button, a menu or a tree shows it that tall at any density. They draw an
## icon a texel to a unit, and icon_max_width only shrinks one: where a unit
## is less than a pixel the icons came out that much smaller, half size at
## a phone's size and one pixel to the point (0.54; phone, 2026-10-30).
static func icon_for(path: String, tall: float, at_density: float) -> ImageTexture:
	var drawn: ImageTexture = texture_for(path, tall, at_density)
	if drawn == null:
		return null
	var key: String = "%s@%d=%d" % [path, drawn.get_height(), roundi(tall)]
	if not _textures.has(key):
		var sized := ImageTexture.create_from_image(drawn.get_image())
		sized.set_size_override(Vector2i(maxi(roundi(tall * drawn.get_width() / drawn.get_height()), 1),
			maxi(roundi(tall), 1)))
		_textures[key] = sized
	return _textures[key]


## The texture for a picture so many units tall at this density, made
## once and kept.
static func texture_for(path: String, tall: float, at_density: float) -> ImageTexture:
	var pixels: int = maxi(roundi(tall * at_density), 1)
	var key: String = "%s@%d" % [path, pixels]
	if _textures.has(key):
		return _textures[key]
	var natural: Image = image(path, 1.0)
	if natural == null or natural.get_height() <= 0:
		return null
	var drawn: Image = image(path, float(pixels) / float(natural.get_height()))
	if drawn == null:
		return null
	var texture := ImageTexture.create_from_image(drawn)
	_textures[key] = texture
	return texture
