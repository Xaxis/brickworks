## Prints to start from, of the kinds LEGO prints most: a dial, a screen,
## a sign, a number plate, a control panel, a face. Each is drawn for the
## canvas it is wanted on, so it fills a 1 x 1 round tile and a 2 x 4
## slope alike, in LEGO's own inks.
class_name Starters
extends RefCounted

const KINDS: Array[String] = ["dial", "screen", "sign", "number plate", "control panel", "face"]

## LEGO inks by name, as LDraw's colour codes.
const BLACK := 0
const WHITE := 15
const RED := 4
const YELLOW := 14
const GREY := 71
const DARK_GREY := 72
const GREEN := 10
const BLUE := 1
const BROWN := 70


## A starter of [param kind] on a canvas [param w] x [param h], its inks
## from [param library] (or plain colours without one).
static func draw(kind: String, w: int, h: int, library: PartLibrary = null) -> Image:
	var ink := func(code: int) -> Color:
		if library == null:
			return {BLACK: Color(0.1, 0.1, 0.1), WHITE: Color.WHITE, RED: Color(0.7, 0.05, 0.05),
				YELLOW: Color(0.98, 0.78, 0.05), GREY: Color(0.63, 0.65, 0.64),
				DARK_GREY: Color(0.39, 0.37, 0.38), GREEN: Color(0.29, 0.62, 0.29),
				BLUE: Color(0.05, 0.34, 0.65), BROWN: Color(0.35, 0.16, 0.08)}.get(code, Color.BLACK)
		var colour: Color = library.color(code).rgb
		colour.a = 1.0
		return colour
	var paint := PrintPaint.new(w, h)
	var image: Image = paint.layer().image
	var middle := Vector2(w, h) * 0.5
	var small: float = minf(w, h)
	match kind:
		"dial":
			PrintPaint.draw_ellipse(image, middle - Vector2.ONE * small * 0.46,
				middle + Vector2.ONE * small * 0.46, 0.0, ink.call(WHITE), true)
			PrintPaint.draw_ellipse(image, middle - Vector2.ONE * small * 0.46,
				middle + Vector2.ONE * small * 0.46, small * 0.025, ink.call(BLACK), false)
			for n: int in 11:
				var turn: float = deg_to_rad(-225.0 + 27.0 * n)
				var out := Vector2(cos(turn), sin(turn))
				PrintPaint.stroke(image, middle + out * small * 0.32, middle + out * small * 0.4,
					small * 0.018, ink.call(BLACK))
			var needle: float = deg_to_rad(-60.0)
			PrintPaint.stroke(image, middle, middle + Vector2(cos(needle), sin(needle)) * small * 0.36,
				small * 0.025, ink.call(RED))
			PrintPaint.disc(image, middle, small * 0.05, ink.call(BLACK))
		"screen":
			image.fill_rect(Rect2i(Vector2i(Vector2(w, h) * 0.06), Vector2i(Vector2(w, h) * 0.88)),
				ink.call(DARK_GREY))
			image.fill_rect(Rect2i(Vector2i(Vector2(w, h) * 0.1), Vector2i(Vector2(w, h) * 0.8)),
				ink.call(BLACK))
			for n: int in 5:
				var bar: float = [0.5, 0.75, 0.35, 0.9, 0.6][n]
				var x: float = w * (0.16 + 0.1 * n)
				image.fill_rect(Rect2i(int(x), int(h * (0.82 - 0.4 * bar)), int(w * 0.06),
					int(h * 0.4 * bar)), ink.call(GREEN))
			PrintPaint.write(image, Vector2(w * 0.68, h * 0.42), "OK", maxi(6, int(h * 0.22)),
				ink.call(GREEN))
			PrintPaint.stroke(image, Vector2(w * 0.66, h * 0.62), Vector2(w * 0.86, h * 0.62),
				maxf(1.0, h * 0.02), ink.call(GREEN))
			PrintPaint.stroke(image, Vector2(w * 0.66, h * 0.72), Vector2(w * 0.8, h * 0.72),
				maxf(1.0, h * 0.02), ink.call(GREEN))
		"sign":
			image.fill_rect(Rect2i(0, 0, w, h), ink.call(WHITE))
			PrintPaint.draw_rectangle(image, Vector2(w, h) * 0.06, Vector2(w, h) * 0.94,
				small * 0.04, ink.call(RED), false)
			_words(image, "SHOP", Rect2(Vector2(w, h) * 0.14, Vector2(w, h) * 0.72), ink.call(BLACK))
		"number plate":
			image.fill_rect(Rect2i(Vector2i(Vector2(w, h) * Vector2(0.04, 0.2)),
				Vector2i(Vector2(w, h) * Vector2(0.92, 0.6))), ink.call(YELLOW))
			PrintPaint.draw_rectangle(image, Vector2(w, h) * Vector2(0.06, 0.24),
				Vector2(w, h) * Vector2(0.94, 0.76), small * 0.025, ink.call(BLACK), false)
			_words(image, "BW 26", Rect2(Vector2(w, h) * Vector2(0.12, 0.3),
				Vector2(w, h) * Vector2(0.76, 0.4)), ink.call(BLACK))
		"control panel":
			image.fill_rect(Rect2i(0, 0, w, h), ink.call(DARK_GREY))
			var codes: Array[int] = [RED, YELLOW, GREEN, BLUE]
			for n: int in 4:
				PrintPaint.disc(image, Vector2(w * (0.17 + 0.22 * n), h * 0.32), small * 0.11,
					ink.call(codes[n]))
			for n: int in 3:
				var x: float = w * (0.25 + 0.25 * n)
				PrintPaint.stroke(image, Vector2(x, h * 0.6), Vector2(x, h * 0.85),
					small * 0.04, ink.call(BLACK))
				PrintPaint.disc(image, Vector2(x, h * (0.66 + 0.08 * n)), small * 0.07,
					ink.call(WHITE))
		"face":
			var eye: float = small * 0.07
			for side: float in [-1.0, 1.0]:
				PrintPaint.disc(image, middle + Vector2(side * w * 0.1, -h * 0.12), eye,
					ink.call(BLACK))
				PrintPaint.disc(image, middle + Vector2(side * w * 0.1 - eye * 0.35, -h * 0.12 - eye * 0.35),
					eye * 0.3, ink.call(WHITE))
			var last := middle + Vector2(-w * 0.13, h * 0.1)
			for n: int in range(1, 17):
				var t: float = n / 16.0
				var here := middle + Vector2(-w * 0.13 + w * 0.26 * t, h * 0.1 + h * 0.14 * sin(PI * t))
				PrintPaint.stroke(image, last, here, small * 0.03, ink.call(BLACK))
				last = here
	return image


## Words as large as fit a box, centred in it.
static func _words(image: Image, words: String, box: Rect2, colour: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = maxi(6, int(box.size.y * 0.8))
	var wide: float = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if wide > box.size.x:
		size = maxi(6, int(size * box.size.x / wide))
		wide = font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ascent: float = font.get_ascent(size)
	var base: float = box.position.y + (box.size.y + ascent * 0.75) * 0.5
	PrintPaint.write(image, Vector2(box.position.x + (box.size.x - wide) * 0.5, base), words, size,
		colour, font)
