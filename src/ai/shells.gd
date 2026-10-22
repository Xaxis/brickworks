## A round shell said once — a dome, or a ball on a stand — laid as hinged
## panels the way 10143's shell is: strips of flat panels from the equator
## up, each panel sized to the round it is on, tapered toward the pole with
## wedge plates, lapped over its neighbours and the band above, under a dish.
##
## The guide gave the strips as a recipe a session worked through by hand,
## and real sessions followed it: twelve strips of panels the same width
## from equator to crown, every panel's tiles stopping half a stud short of
## its hinge line, the crown a flat dish on a column. From four sides it
## read as a cage: daylight between the strips, a stud of it between the
## bands, the dish floating over the top. So the shell is one call, and the
## arithmetic that closes it is done here:
##
##   the ring    twelve strip bases thirty degrees apart, each swivelling on
##               one stud (a jumper's or a round plate's) so it grips by that
##               stud alone, at a radius where all twelve land on the half-
##               stud grid to a twentieth of a stud (RINGS)
##   a band      a panel's width read off where its plane meets its
##               neighbours' at both its ends: the strips take turns, the
##               low ones inside that line, the high ones two plates up and
##               reaching past it over the low ones' edges, short of where
##               they would meet the next high one
##   the taper   wedge plates in left and right pairs, a stud in each side
##               over the panel's length (2 x 4) or two (2 x 2 twice)
##   the seam    each band's last row raised a plate, its tiles reaching two
##               studs on over the band above, which folds in under them
##   the crown   a dish over the top band's end, held up into its middle,
##               on discs of plates stepping in as the sphere does when
##               the end is wider
##   the foot    a course of bricks round the ring's edge, as tall as the
##               slot between the ring and the panels
##
## A ball is the same strips hung under the ring as well, the ring its
## equator with a second course hung under it, and a column through the
## opening the lower strips leave to a plate on the ground.
##
## Why widths come from the planes: near the pole a panel tips toward the
## level, and two neighbours thirty degrees apart round the axis meet at a
## dihedral of a dozen degrees. Shared out round the band's circumference
## instead, panels two studs too wide met their neighbours' wedges there.
##
## What comes back is the design itself — sections, bricks — for the reader
## to take as a session's own: nothing here is checked, the check is.
class_name Shells
extends RefCounted

const STUD := 20.0
const PLATE := 8.0

## Strips round the ring. Twelve bases thirty degrees apart can each stand
## on a stud or a jumper's centre stud, to within 0.08 of a stud, at every
## radius in RINGS; sixteen cannot at any radius under forty.
const STRIPS := 12

## Hinge line to hinge line along a panel, in studs: under its plates sit
## its own hinge's top half (two studs) and the next one's base (two).
const LENGTH := 5

## [radius of the bases' swivel studs from the centre, in studs; the first
## strip's turn, degrees]: where all twelve land on the half-stud grid
## (a stud, a 1 x 2 jumper's stud, a 2 x 2 jumper's) within 0.08 of a stud.
## A ball's lower strips swivel four studs further in at the same turn, so
## its rings are those with a ring four in at the same turn as well.
const RINGS: Array = [
	[4.0, 0.0], [7.0, 0.0], [7.75, 15.0], [8.0, 0.0], [9.0, 3.5], [11.0, 0.0],
	[13.0, 2.25], [13.5, 15.0], [15.0, 0.0], [15.5, 15.0], [17.0, 1.75], [19.0, 0.0],
	[21.25, 15.0], [22.0, 0.0], [24.25, 8.25], [26.0, 0.0], [29.0, 15.0], [30.0, 0.0],
	[34.0, 0.0], [36.75, 15.0], [37.0, 0.0],
]

## The dishes a crown is made of, [part, radius in studs, plates from its
## rim up to the 2 x 2 under its middle], smallest first. Each is hollow
## out to its rim, and that 2 x 2 is all that holds it: set down on studs,
## its rim sits on them and nothing joins it. The 4 x 4 (3960) is solid
## underneath but for one hole at its middle, off the column's studs.
const CROWNS: Array = [["44375b", 3.0, 1], ["3961", 4.0, 2], ["50990b", 5.0, 2]]

## Runs of plates, bricks and tiles a stud wide, by length in studs.
const PLATES: Dictionary = {1: "3024", 2: "3023b", 3: "3623", 4: "3710", 6: "3666", 8: "3460"}
const BRICKS: Dictionary = {1: "3005", 2: "3004", 3: "3622", 4: "3010", 6: "3009", 8: "3008"}
const TILES: Dictionary = {1: "3070b", 2: "3069b", 3: "63864", 4: "2431", 6: "6636", 8: "4162"}

## Wedge plates, as [the panel's left side, its right] for each length
## along the panel: square, each one's straight edge against the plates
## between them and its wide end at the panel's foot. LDraw's "right" wing
## is the one for a panel's left edge. The 2 x 4s without the chamfer, which
## have BrickNet shapes: on 41769b, which has none, the check fell back on
## the lattice for the 1 x 1 tile on its last stud, and the lattice let one
## of a ball's twelve fall (the strip turned 210 degrees under the ring).
const WINGS: Dictionary = {2: ["24307", "24299"], 4: ["41769a", "41770a"]}

## How far a high strip stands over its low neighbours, in plates: as far
## as a low panel's plates and tiles are thick, so a low panel inside the
## line where its plane meets its neighbour's has its edges under the high
## panel's plates. A plate was tried: a low panel then had to be narrower
## than its share by a stud and a half at fifty degrees, and still met its
## neighbour's wedge.
const HIGH := 2

## How far a lip's corner keeps from another panel's plane, square to it,
## LDU: two turned parts' covers, each rounded out a lattice cell.
const CLEAR := 4.0

## The least a shell can be across, studs. Under 20 no band of twelve
## panels fits a dome's first round; a ball's lower strips hang four studs
## inside its upper ones, round a stand, and under 24 run into it.
const SMALLEST_DOME := 20.0
const SMALLEST_BALL := 24.0

## The most, so far, studs. Bigger is not yet shown to hold: built with
## every other strip stopping near the pole, a dome 40 across and a ball 36
## ran into themselves there.
const LARGEST := 32.0

## Clear of where two panels' planes meet, LDU: a turned part's cover
## reaches a cell past it all round, and its neighbour's the same.
const MARGIN := 7.0

## How far past a low panel's edge a high one reaches, LDU.
const OVER := 8.0

## A shell's design, or {} with why in [param trouble]. [param hinge] is
## the joint the strips hang on, as the reader fits it: {"kind", "pin" (its
## line from the base's corner, LDU), "line" (the line in the panel's own
## frame, LDU)}.
static func lay(pattern: Dictionary, hinge: Dictionary, trouble: Array) -> Dictionary:
	var kind: String = str(pattern.get("kind", "dome")).to_lower()
	if kind in ["sphere", "globe"]:
		kind = "ball"
	if not kind in ["dome", "ball"]:
		trouble.append("shell: kind is \"dome\" or \"ball\", not \"%s\"" % kind)
		return {}
	var across: float = float(pattern.get("across", 24.0))
	var least: float = SMALLEST_BALL if kind == "ball" else SMALLEST_DOME
	if across < least or across > LARGEST + 1.0:
		var instead: String = "bigger is not built yet: say %d, or build it as skins on a core " \
			% roundi(LARGEST) + "with studs out on every side (read_guide \"round\")"
		if across < least:
			instead = ("smaller, four quarter domes (show_technique \"smooth dome\", 16 "
				+ "across), a dish or round parts" if kind == "dome"
				else "smaller, build it as skins on a core with studs out on every side "
				+ "(read_guide \"round\"), or as round parts")
		trouble.append("shell: a %s of hinged panels is %d to %d studs across, not %s: %s"
			% [kind, roundi(least), roundi(LARGEST), across, instead])
		return {}
	var at: Dictionary = pattern.get("at", {}) if pattern.get("at") is Dictionary else {}
	var name: String = str(pattern.get("name", "shell")).strip_edges()
	if name.is_empty():
		name = "shell"
	var plan := Plan.new()
	plan.name = name
	plan.colour = int(pattern.get("color", pattern.get("colour", 71)))
	plan.frame = int(pattern.get("frame_color", pattern.get("frame_colour", 72)))
	plan.centre = Vector2(roundf(float(at.get("x", 0.0))), roundf(float(at.get("z", 0.0))))
	plan.ground = int(roundf(float(at.get("y", 0.0))))
	plan.ball = kind == "ball"
	plan.hinge = hinge
	plan.choose(across)
	if plan.bands.is_empty():
		trouble.append("shell: no band of panels fits a shell %s studs across" % across)
		return {}
	plan.build()
	return plan.out()


## Everything worked out for one shell, in LDU unless said.
class Plan extends RefCounted:
	var name: String
	var colour: int
	var frame: int
	var centre: Vector2            ## studs, a stud corner
	var ground: int                ## plates
	var ball: bool
	var hinge: Dictionary
	var pivot: float               ## studs, the upper swivels from the centre
	var turn0: float               ## degrees, the first strip's
	var radius: float              ## the hinge lines from the centre
	var step: float                ## degrees between bands
	var lift: float                ## a panel's tiles above its line
	var foot: int                  ## plates, the ring's bottom
	var margin: float = MARGIN     ## LDU, with the swivels' error
	## Per band: {"length": studs of plates, "low": [width, taper], "high":
	## [width, taper], "lip": a low panel's lip, studs, "ends": [the far end
	## of a low and a high panel's tiles, (out, up) from the centre]}.
	var bands: Array = []
	var sections: Array = []
	var bricks: Array = []
	var said := PackedStringArray()
	var _pieces: Array = []        ## the panel being laid, see [method _panel]

	## The ring that makes the shell nearest [param across] studs over its
	## panels, and its bands.
	func choose(across: float) -> void:
		var pin: Vector3 = hinge["pin"]
		var line: Vector3 = hinge["line"]
		var reach: float = pin.z - STUD * 0.5
		lift = -line.y + 2.0 * PLATE
		var best: float = INF
		for row: Array in RINGS:
			var r: float = float(row[0]) * STUD - reach
			var made: float = 2.0 * (r + lift) / STUD
			if made < SMALLEST_DOME - 0.5 or made > LARGEST + 0.5:
				continue
			# A ball's lower bases swivel inside the line by as much as the
			# upper ones stand outside it.
			if ball and not _has_ring(float(row[0]) - 2.0 * reach / STUD, float(row[1])):
				continue
			var miss: float = absf(2.0 * (r + lift) / STUD - across)
			if miss < best:
				best = miss
				pivot = float(row[0])
				turn0 = float(row[1])
				radius = r
		step = rad_to_deg(2.0 * asin(LENGTH * STUD / (2.0 * radius)))
		# Two neighbours' swivels each off their circle toward each other.
		for strip: int in STRIPS:
			var a: float = deg_to_rad(turn0 + 360.0 * strip / STRIPS)
			var exact: Vector2 = centre + Vector2(sin(a), cos(a)) * pivot
			margin = maxf(margin, MARGIN + 2.0 * STUD * exact.distance_to(_pivot(strip, 0)))
		_plan_bands()

	static func _has_ring(at: float, turn: float) -> bool:
		for row: Array in RINGS:
			if is_equal_approx(float(row[0]), at) and is_equal_approx(float(row[1]), turn):
				return true
		return false

	## The bands from the equator up, each as long and wide as fits, the
	## last shortened to fit; the crown takes the rest. Where the twelve
	## strips crowd toward the pole, every other one stopping and the rest
	## going on a step up was tried: those going on had to be fourteen studs
	## wide to lap their neighbours, stood out past the crown like wings, and
	## left holes where the others stopped.
	func _plan_bands() -> void:
		bands.clear()
		for k: int in 12:
			var band: Dictionary = {}
			for length: int in [4, 3, 2]:
				band = _fit(k, length)
				if not band.is_empty():
					break
			if band.is_empty():
				break
			bands.append(band)
			if int(band["length"]) < LENGTH - 1:
				break
			# Its end within the widest dish: the crown takes the rest.
			if (band["ends"][1] as Vector2).x < float(CROWNS[-1][1]) * STUD - PLATE:
				break

	## Band [param k]'s panels [param length] studs long, or {} where they
	## cannot be both closed and clear of each other: the widest low panel
	## inside where its top meets its high neighbours' plates, at both its
	## ends, and a high one past those low edges by OVER, short of where it
	## meets the next high one.
	func _fit(k: int, length: int) -> Dictionary:
		var apart: float = 360.0 / STRIPS
		var start: float = STUD * 0.5
		var end: float = STUD * (0.5 + length)
		var top: float = lift                       ## a low panel's tiles
		var bottom: float = 2.0 + HIGH * PLATE      ## a high panel's plates
		# Ending within two studs of the axis, the strips run into each other
		# whatever their widths; the crown takes over before that.
		if _point(k, end, top).x < 2.0 * STUD:
			return {}
		var low := Vector2(_meet(k, start, top, bottom, apart),
			_meet(k, end, top, bottom, apart)) - Vector2(margin, margin)
		# Near the pole, where the panels lie almost flat and their planes meet
		# far off, no wider than their share of the round round the axis.
		var near_axis: float = _point(k, end, top).x
		low.y = minf(low.y, near_axis * tan(deg_to_rad(apart * 0.5)) - margin)
		if low.y < STUD * 0.5:
			return {}
		var low_fit: Array = []
		for width: int in range(_odd_within(2.0 * low.x / STUD), 0, -2):
			for taper: int in [0, 2, 4]:
				if _buildable(width, taper, length) and (width - taper) * STUD * 0.5 <= low.y:
					low_fit = [width, taper]
					break
			if not low_fit.is_empty():
				break
		if low_fit.is_empty():
			return {}
		var need := Vector2(_reach(k, start, int(low_fit[0]) * STUD * 0.5, apart, top,
			bottom + PLATE * 0.5), _reach(k, end, (int(low_fit[0]) - int(low_fit[1])) * STUD
			* 0.5, apart, top, bottom + PLATE * 0.5)) + Vector2(OVER, OVER)
		var room := Vector2(_meet(k, start, bottom, bottom, 2.0 * apart),
			_meet(k, end, bottom, bottom, 2.0 * apart)) - Vector2(margin, margin)
		room.y = minf(room.y, _point(k, end, bottom).x * tan(deg_to_rad(apart)) - margin)
		# As wide as there is room for: the wider the high panels, the less of
		# the low ones between them shows, and the less a low panel's lip has
		# to cover at its seam.
		var high_fit: Array = []
		for width: int in range(_odd_within(2.0 * room.x / STUD), 0, -2):
			if width * STUD * 0.5 < need.x:
				continue
			for taper: int in [0, 2, 4]:
				var end_half: float = (width - taper) * STUD * 0.5
				if _buildable(width, taper, length) and end_half >= need.y and end_half <= room.y:
					high_fit = [width, taper]
					break
			if not high_fit.is_empty():
				break
		if high_fit.is_empty():
			return {}
		# A low panel's lip: its middle, a plate up, clear of where it would
		# meet the high panels beside it, this band's at its last row and the
		# band above's, folded in, two studs past its end.
		var lip: float = minf(_room(k, end - STUD, top + PLATE, bottom, apart),
			_room(k, end + 2.0 * STUD, top + PLATE, bottom, apart, k + 1))
		return {"length": length, "low": low_fit, "high": high_fit,
			"lip": 0 if lip < STUD * 0.5 else _odd_within(2.0 * lip / STUD),
			"ends": [_point(k, end, top), _point(k, end, bottom + 2.0 * PLATE)]}

	## Where a point of band [param k]'s panel is in the shell's meridian:
	## (out from the axis, up from the equator), LDU, [param along] from its
	## hinge line and [param up] out from it.
	func _point(k: int, along: float, up: float) -> Vector2:
		var a: float = deg_to_rad(step * k)
		var mid: float = deg_to_rad(step * (k + 0.5))
		return Vector2(cos(a), sin(a)) * radius + Vector2(-sin(mid), cos(mid)) * along \
			+ Vector2(cos(mid), sin(mid)) * up

	## How far across band [param k]'s panel, [param along] its length, the
	## plane [param up] over it meets the plane [param up_there] over the
	## same band (or band [param there]) of a strip [param degrees] round,
	## or comes within [param clear] of it: the panel's half-width there that
	## stays its own side. In 3D, the strip facing +z: its line
	## out along z, the panel rising along -sin, cos of the band's middle,
	## across along x.
	func _meet(k: int, along: float, up: float, up_there: float, degrees: float,
			there: int = -1, clear: float = 0.0) -> float:
		var a: float = deg_to_rad(step * k)
		var mid: float = deg_to_rad(step * (k + 0.5))
		var line := Vector3(0.0, radius * sin(a), radius * cos(a))
		var way := Vector3(0.0, cos(mid), -sin(mid))
		var out := Vector3(0.0, sin(mid), cos(mid))
		# The other panel, of band [param there] (this one's unless said).
		var b: float = deg_to_rad(step * (k if there < 0 else there))
		var b_mid: float = deg_to_rad(step * ((k if there < 0 else there) + 0.5))
		var turn := Basis(Vector3.UP, deg_to_rad(degrees))
		var other_out: Vector3 = turn * Vector3(0.0, sin(b_mid), cos(b_mid))
		var other_line: Vector3 = turn * Vector3(0.0, radius * sin(b), radius * cos(b))
		var across: float = other_out.dot(Vector3.RIGHT)
		if absf(across) < 1e-6:
			return INF
		var here: Vector3 = line + way * along + out * up
		# Square to the other plane, less [param clear] (none left, none).
		var gap: float = up_there - other_out.dot(here - other_line)
		gap = signf(gap) * maxf(absf(gap) - clear, 0.0)
		return absf(gap / across)

	## How far a lip may reach across, as [method _meet] asks: the margin
	## short of where the planes meet, and, near the pole, where they meet at
	## a slant and a margin across leaves almost nothing between them, its
	## corner CLEAR from the other plane square to it.
	func _room(k: int, along: float, up: float, up_there: float, degrees: float,
			there: int = -1) -> float:
		return minf(_meet(k, along, up, up_there, degrees, there) - margin,
			_meet(k, along, up, up_there, degrees, there, CLEAR))

	## How far across a high panel of band [param k], [param along] its
	## length, it has to reach to cover the edge of the low panel beside it,
	## [param half] across its own, as seen from the shell's centre: where
	## the ray out through that edge meets the high panel's plates. Taken
	## square across instead, a high panel near the pole reached three
	## studs short of its low neighbours.
	func _reach(k: int, along: float, half: float, apart: float, low_up: float,
			high_up: float) -> float:
		var a: float = deg_to_rad(step * k)
		var mid: float = deg_to_rad(step * (k + 0.5))
		var line := Vector3(0.0, radius * sin(a), radius * cos(a))
		var way := Vector3(0.0, cos(mid), -sin(mid))
		var out := Vector3(0.0, sin(mid), cos(mid))
		# The low strip [param apart] degrees round, its edge toward this one.
		var turn := Basis(Vector3.UP, deg_to_rad(apart))
		var edge: Vector3 = turn * (line + way * along + out * low_up - Vector3.RIGHT * half)
		var t: float = (high_up + out.dot(line)) / maxf(out.dot(edge), 1e-6)
		return absf(edge.x * t)

	static func _odd_within(value: float) -> int:
		var n: int = int(floor(value + 0.001))
		if n % 2 == 0:
			n -= 1
		return maxi(1, n)

	static func _odd_over(value: float) -> int:
		var n: int = int(ceil(value - 0.001))
		if n % 2 == 0:
			n += 1
		return maxi(1, n)

	## Whether a panel this wide and long can take this taper: two studs in
	## needs a wedge plate each side and a stud of plates between them, four
	## needs 2 x 2 wedges twice along a panel four long and the same.
	static func _buildable(width: int, taper: int, length: int) -> bool:
		match taper:
			0:
				return true
			2:
				return width >= 5
			4:
				return width >= 7 and length == 4
		return false

	func build() -> void:
		var top: Vector2 = bands[-1]["ends"][1]
		# A ball held up on its stand clear of the ground by its lowest panels,
		# the high ones near the pole standing three steps out.
		foot = ground + (int(ceil((radius + lift + 3.0 * HIGH * PLATE) / PLATE)) + 4 if ball else 0)
		_ring()
		for half: int in (2 if ball else 1):
			for strip: int in STRIPS:
				_strip(strip, half)
		_crown()
		if ball:
			_stand()
		said.append("%s %d studs across over its panels: %d strips of %d bands on clip "
			% ["a ball" if ball else "a dome", roundi(2.0 * (radius + lift) / STUD), STRIPS,
				bands.size()] + "hinges, sections \"%s 1.1\" to \"%s %d.%d\"%s, the crown %s"
			% [name, name, STRIPS, bands.size(), " and under" if ball else "",
				"a dish" if top.x + PLATE <= float(CROWNS[-1][1]) * STUD
				else "a dish on a disc of plates"])

	## Strip [param strip]'s swivel stud, in studs, on the half grid: outside
	## its line for the upper half, as far inside it for a ball's lower one.
	func _pivot(strip: int, half: int) -> Vector2:
		var a: float = deg_to_rad(turn0 + 360.0 * strip / STRIPS)
		var out: float = pivot if half == 0 else pivot - 2.0 * (pivot - radius / STUD)
		return ((centre + Vector2(sin(a), cos(a)) * out) * 2.0).round() / 2.0

	## The ring: plates in two crossed layers, a disc out past the swivels,
	## and round its edge a course of bricks as tall as the slot between the
	## ring and the panels, which a person sees through at the foot. A
	## ball's is its equator: the slot is above the ring and below it, so a
	## second course hangs under it. Stopped inside its lines instead, a
	## ball's ring left a belt round its middle half open to the sky.
	func _ring() -> void:
		var cells: Dictionary = {}
		# Out past the swivels by a band of studs thick enough that no two
		# of its cells meet only at a corner, which shows daylight.
		_disc(cells, centre, pivot + 3.0)
		# Its plates on top only where no panel's foot comes down over them:
		# a high panel's wide foot reaches round past its strip. Under a
		# ball's, the bricks only where none of the lower half's does.
		var drum: Dictionary = {}
		var capped: Dictionary = {}
		var hung: Dictionary = {}
		var hung_capped: Dictionary = {}
		for cell: Vector2i in cells:
			if Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(centre) > pivot + 1.45:
				drum[cell] = true
				if not _under_panels(cell, (foot + 6) * PLATE - _line_height(0)):
					capped[cell] = true
				if ball and not _under_panels(cell, _line_height(1) - (foot - 3) * PLATE):
					hung[cell] = true
					if not _under_panels(cell, _line_height(1) - (foot - 4) * PLATE):
						hung_capped[cell] = true
		# Round a ball's middle the ring shows as a band: the panels' colour.
		var band: int = colour if ball else -1
		_lay(drum, foot + 2, true, BRICKS, band)
		_lay(capped, foot + 5, false, PLATES, band)
		_lay(hung, foot - 3, true, BRICKS, band)
		_lay(hung_capped, foot - 4, false, PLATES, band)
		_lay(cells, foot, true, PLATES, band)
		_lay(cells, foot + 1, false, PLATES, band)
		for half: int in (2 if ball else 1):
			for strip: int in STRIPS:
				_swivel(_pivot(strip, half), foot + 2 if half == 0 else foot - 1, strip, half)

	## Whether ring cell [param cell], reaching [param h] LDU from a half's
	## line (up the upper half's, down the lower's), reaches into a
	## first-band panel's foot. The drum stands outside the feet, but a
	## panel is flat and the drum round: a wide one's corners reach out to
	## it. So: anywhere in the cell inside a strip's width, on its side, in
	## from the furthest out its panel comes within that height of its line,
	## and a margin, since a turned part's cover reaches a cell past it.
	func _under_panels(cell: Vector2i, h: float) -> bool:
		var mid: float = deg_to_rad(step * 0.5)
		var start: float = STUD * 0.5
		for strip: int in STRIPS:
			var rise: int = _rise(strip)
			# Out from its line by its tiles' top, or as far as comes no
			# nearer the line than the cell at the panel's foot.
			var up: float = minf(lift + rise * PLATE, (h - start * cos(mid)) / sin(mid))
			if up < 2.0 + rise * PLATE:
				continue
			var reach: float = radius - start * sin(mid) + up * cos(mid)
			var half: float = int(bands[0]["high" if _high(strip) else "low"][0]) * 0.5 * STUD
			var a: float = deg_to_rad(turn0 + 360.0 * strip / STRIPS)
			var out := Vector2(sin(a), cos(a))
			var side := Vector2(out.y, -out.x)
			for i: int in 5:
				for j: int in 5:
					var c: Vector2 = (Vector2(cell) + Vector2(i, j) * 0.25 - centre) * STUD
					if absf(c.dot(side)) <= half + MARGIN and c.dot(out) > radius * 0.5 \
							and c.dot(out) < reach + MARGIN:
						return true
		return false

	static func _disc(cells: Dictionary, middle: Vector2, out: float) -> void:
		for x: int in range(int(floor(middle.x - out)) - 1, int(ceil(middle.x + out)) + 1):
			for z: int in range(int(floor(middle.y - out)) - 1, int(ceil(middle.y + out)) + 1):
				if Vector2(x + 0.5 - middle.x, z + 0.5 - middle.y).length() <= out:
					cells[Vector2i(x, z)] = true

	## [param cells] laid at [param y] in runs along x or along z of plates,
	## or of what [param kind] names (BRICKS, TILES), in the frame's colour
	## or [param color].
	func _lay(cells: Dictionary, y: int, along_x: bool, kind: Dictionary = PLATES,
			color: int = -1) -> void:
		if cells.is_empty():
			return
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := -lo
		for cell: Vector2i in cells:
			lo = lo.min(cell)
			hi = hi.max(cell)
		for line_at: int in range((lo.y if along_x else lo.x), (hi.y if along_x else hi.x) + 1):
			var run: Array[int] = []
			for along: int in range((lo.x if along_x else lo.y), (hi.x if along_x else hi.y) + 2):
				var cell := Vector2i(along, line_at) if along_x else Vector2i(line_at, along)
				if cells.has(cell):
					run.append(along)
					continue
				if not run.is_empty():
					_lay_run(y, line_at, run[0], run[-1] + 1, along_x, kind, color)
				run.clear()

	## A stud on the half grid at [param at] for a base to turn on: a round
	## plate on a stud, a 1 x 2 jumper either way, or a 2 x 2 jumper,
	## standing on the ring. Hung under it (the lower [param half]), the
	## jumper's stud goes up into the ring and the base's into one of its
	## sockets on the half grid, the jumper reaching away from the base's
	## other stud so that one meets nothing.
	func _swivel(at: Vector2, y: int, strip: int, half: int) -> void:
		var odd := Vector2(fposmod(at.x, 1.0), fposmod(at.y, 1.0))
		var a: float = deg_to_rad(turn0 + 360.0 * strip / STRIPS)
		var nose := Vector2(sin(a), cos(a))
		var back := Vector2(1.0 if nose.x > 0.0 else 0.0, 1.0 if nose.y > 0.0 else 0.0)
		var one: Dictionary
		if is_equal_approx(odd.x, 0.5) and is_equal_approx(odd.y, 0.5):
			one = {"part": "6141", "x": at.x - 0.5, "z": at.y - 0.5, "rot": 0}
		elif half == 0 and is_zero_approx(odd.x) and not is_zero_approx(odd.y):
			one = {"part": "3794b", "x": at.x - 1.0, "z": at.y - 0.5, "rot": 0}
		elif half == 0 and is_zero_approx(odd.x):
			one = {"part": "87580", "x": at.x - 1.0, "z": at.y - 1.0, "rot": 0}
		elif half == 0:
			one = {"part": "3794b", "x": at.x - 0.5, "z": at.y - 1.0, "rot": 1}
		elif is_zero_approx(odd.x) and not is_zero_approx(odd.y):
			one = {"part": "3794b", "x": at.x - 0.5 - back.x, "z": at.y - 0.5, "rot": 0}
		elif not is_zero_approx(odd.x):
			one = {"part": "3794b", "x": at.x - 0.5, "z": at.y - 0.5 - back.y, "rot": 1}
		else:
			one = {"part": "87580", "x": at.x - 0.5 - back.x, "z": at.y - 0.5 - back.y,
				"rot": 0}
		one["color"] = frame
		one["y"] = y
		bricks.append(one)

	## One strip: a hinged section per band, each within the one below.
	## Even strips are low, odd ones high.
	func _strip(strip: int, half: int) -> void:
		var pin: Vector3 = hinge["pin"]
		var line: Vector3 = hinge["line"]
		var yaw: float = turn0 + 360.0 * strip / STRIPS + (180.0 if half == 0 else 0.0)
		var at: Vector2 = _pivot(strip, half)
		var stands: int = foot + 3 if half == 0 else foot - 2
		var stem: String = "%s %s%d" % [name, "" if half == 0 else "under ", strip + 1]
		# The base's corner, so its first stud is on the swivel's.
		sections.append({"name": "%s.1" % stem, "x": at.x - 0.5, "y": stands, "z": at.y - 0.5,
			"yaw": yaw, "pitch": (90.0 - step * 0.5) if half == 0 else -(90.0 + step * 0.5),
			"hinge": hinge["kind"], "hinge_color": frame})
		var next: Vector3 = line + Vector3(0, 0, LENGTH * STUD) - pin
		for k: int in bands.size():
			var band: Dictionary = bands[k]
			var here: String = "%s.%d" % [stem, k + 1]
			if k > 0:
				sections.append({"name": here, "within": "%s.%d" % [stem, k],
					"x": next.x / STUD, "y": next.y / PLATE, "z": next.z / STUD,
					"pitch": -step, "hinge": hinge["kind"], "hinge_color": frame})
			var high: bool = _high(strip)
			var width: Array = band["high" if high else "low"]
			# The seam with the band above, lapped by this band's lip: all of
			# a high panel's width, the panel above being high too; a low
			# one's middle, clear of the high panels lapping the one above.
			var lip: int = 0
			if k + 1 < bands.size():
				lip = 99 if high else int(band["lip"])
			_panel(here, int(width[0]), int(width[1]), _rise(strip), int(band["length"]), lip)

	## Whether a strip's panels are high ones: the odd strips.
	static func _high(strip: int) -> bool:
		return strip % 2 == 1

	## How many plates its panels stand up on: a low one none, a high one
	## HIGH.
	static func _rise(strip: int) -> int:
		return HIGH if _high(strip) else 0

	## A panel in [param section]: plates [param length] studs along over its
	## hinge, [param width] across at its foot, narrowing by [param taper]
	## to its end with wedge plates each side; tiles over them, raised on
	## [param rise] plates of spacer. With [param lip] its last row a plate
	## higher, at most that many studs of its middle, its tiles reaching two
	## studs on over the next band.
	##
	## A tile ties only the plates under it, so where the rows' seams fall
	## decides whether the panel is one piece: a seam over the joint beside a
	## short plate or a wedge leaves it, and the tiles on it, held by nothing.
	## The rows are laid with their seams each way they go, two deep and
	## then a stud deep, until every part is held from the hinge.
	func _panel(section: String, width: int, taper: int, rise: int, length: int,
			lip: int) -> void:
		var first: Array = []
		var chosen: Array = []
		for deep: int in [2, 1]:
			var tries: int = 0
			var ways: int = 1
			while tries < ways and chosen.is_empty():
				_pieces = []
				ways = _panel_pieces(width, taper, rise, length, lip, deep, tries)
				if first.is_empty():
					first = _pieces
				if _held(_pieces):
					chosen = _pieces
				tries += 1
			if not chosen.is_empty():
				break
		for one: Dictionary in (first if chosen.is_empty() else chosen):
			_add(str(one["part"]), int(one["color"]), int(one["x"]), int(one["y"]),
				int(one["z"]), section, int(one["rot"]))
		_pieces = []

	## The parts of a panel (see [method _panel]) into [member _pieces], the
	## main tile rows [param deep] studs deep at most, their seams the
	## [param way]th of the ways they go. Returns how many ways there are.
	func _panel_pieces(width: int, taper: int, rise: int, length: int, lip: int,
			deep_most: int, way: int) -> int:
		var left: int = -(width - 1) / 2
		var right: int = left + width       ## one past
		for y: int in rise:
			_put(_plate_along(length), frame, 0, y, 0, 1, Rect2i(0, 0, 1, length))
		var y0: int = rise
		# The tile rows' extents as [from z, to z, left, right].
		var rows: Array = []
		match taper:
			0:
				for x: int in range(left, right):
					_put(_plate_along(length), colour, x, y0, 0, 1, Rect2i(x, 0, 1, length))
				rows.append([0, length, left, right])
			2:
				var wings: Array = WINGS[4] if length == 4 else WINGS[2]
				var long: int = 4 if length == 4 else 2
				# A wedge's studs are along its straight edge only, the inner one.
				_put(str(wings[0]), colour, left, y0, 0, 0, Rect2i(left + 1, 0, 1, long))
				_put(str(wings[1]), colour, right - 2, y0, 0, 0, Rect2i(right - 2, 0, 1, long))
				for x: int in range(left + 2, right - 2):
					_put(_plate_along(length), colour, x, y0, 0, 1, Rect2i(x, 0, 1, length))
				if long < length:
					# A wedge shorter than the panel: plates along on from it.
					for x: int in [left + 1, right - 2]:
						_put(_plate_along(length - long), colour, x, y0, long, 1,
							Rect2i(x, long, 1, length - long))
				rows.append([0, length, left + 1, right - 1])
			4:
				_put(str(WINGS[2][0]), colour, left, y0, 0, 0, Rect2i(left + 1, 0, 1, 2))
				_put(str(WINGS[2][1]), colour, right - 2, y0, 0, 0, Rect2i(right - 2, 0, 1, 2))
				_put(str(WINGS[2][0]), colour, left + 1, y0, 2, 0, Rect2i(left + 2, 2, 1, 2))
				_put(str(WINGS[2][1]), colour, right - 3, y0, 2, 0, Rect2i(right - 3, 2, 1, 2))
				for x: int in [left + 2, right - 3]:
					_put(_plate_along(2), colour, x, y0, 0, 1, Rect2i(x, 0, 1, 2))
				for x: int in range(left + 3, right - 3):
					_put(_plate_along(length), colour, x, y0, 0, 1, Rect2i(x, 0, 1, length))
				rows.append([0, 2, left + 1, right - 1])
				rows.append([2, length, left + 2, right - 2])
		# The tiles, their seams moved along from one row to the next so they
		# tie the plates across; the last row raised a plate for the lip.
		var stop: int = length - 1 if lip > 0 else length
		var row_n: int = 0
		var ways: int = 1
		var digits: int = way
		for row: Array in rows:
			var z: int = int(row[0])
			while z < mini(int(row[1]), stop):
				var deep: int = mini(deep_most, mini(int(row[1]), stop) - z)
				# The first way alternates plain and moved along; the rest
				# count through the four ways each row's seams go.
				var seams: int = (row_n + digits % 4) % 4 if way > 0 else row_n % 2
				_tiles(y0 + 1, z, deep, int(row[2]), int(row[3]), seams)
				digits /= 4
				ways *= 4
				row_n += 1
				z += deep
		if lip > 0:
			var last: Array = rows[-1]
			var edge_from: int = int(last[2])
			var edge_to: int = int(last[3])
			# As wide as [param lip] at most, on the middle: a low panel's lip
			# stops short of where the high panels beside it lap over.
			var from: int = maxi(edge_from, -(lip - 1) / 2)
			var to: int = mini(edge_to, -(lip - 1) / 2 + lip)
			_tiles(y0 + 1, length - 1, 1, edge_from, from, 0)
			_tiles(y0 + 1, length - 1, 1, to, edge_to, 0)
			_plates_across(y0 + 1, length - 1, from, to)
			_lip_tiles(y0 + 2, length - 1, from, to)
		return ways

	## A part of the panel being laid, its studs (or, a tile, its face) over
	## [param cells] (x and z).
	func _put(part: String, color: int, x: int, y: int, z: int, rot: int,
			cells: Rect2i) -> void:
		_pieces.append({"part": part, "color": color, "x": x, "y": y, "z": z, "rot": rot,
			"cells": cells})

	## Whether every one of [param pieces] is held from the hinge's stud at
	## the panel's foot, through parts a plate above or below it over the
	## same studs.
	static func _held(pieces: Array) -> bool:
		var reached: Dictionary = {}
		var todo: Array[int] = []
		for index: int in pieces.size():
			var one: Dictionary = pieces[index]
			if int(one["y"]) == 0 and (one["cells"] as Rect2i).has_point(Vector2i.ZERO):
				reached[index] = true
				todo.append(index)
		while not todo.is_empty():
			var here: Dictionary = pieces[todo.pop_back()]
			for index: int in pieces.size():
				var other: Dictionary = pieces[index]
				if not reached.has(index) and absi(int(here["y"]) - int(other["y"])) == 1 \
						and (here["cells"] as Rect2i).intersects(other["cells"]):
					reached[index] = true
					todo.append(index)
		return reached.size() == pieces.size()

	## Tiles three deep from [param z] across [param from] to [param to]: a
	## lip, held by the one row of studs under its first.
	func _lip_tiles(y: int, z: int, from: int, to: int) -> void:
		var x: int = from
		while x < to:
			var wide: int = mini(2, to - x)
			var part: String = "26603" if wide == 2 else "63864"
			_put(part, colour, x, y, z, _turn_for(part, wide), Rect2i(x, z, wide, 3))
			x += wide

	## Tiles [param deep] rows from [param z], across [param from] to [param
	## to], in the longest pieces that fit, their seams where [param way]
	## says: 0 longest first, 1 moved along by a short piece first, 2 the
	## longest last, 3 the other short piece first.
	func _tiles(y: int, z: int, deep: int, from: int, to: int, way: int) -> void:
		var widths: Array[int] = []
		var left: int = to - from
		if (way == 1 or way == 3) and left > 2:
			var odd: bool = left % 2 == 1
			widths.append((1 if odd else 2) if way == 1 else (2 if odd else 1))
			left -= widths[0]
		var rest: Array[int] = []
		while left > 0:
			var piece: int = 6 if left >= 8 or left == 6 else (4 if left >= 4 else left)
			if left == 5:
				piece = 3
			if left == 7:
				piece = 4
			rest.append(piece)
			left -= piece
		if way == 2:
			rest.reverse()
		widths.append_array(rest)
		var x: int = from
		for wide: int in widths:
			var part: String = _tile(wide, deep)
			_put(part, colour, x, y, z, _turn_for(part, wide), Rect2i(x, z, wide, deep))
			x += wide

	## Plates a stud deep across [param from] to [param to] at row [param z].
	func _plates_across(y: int, z: int, from: int, to: int) -> void:
		var x: int = from
		while x < to:
			var left: int = to - x
			var wide: int = 6 if left >= 6 else (4 if left >= 4 else left)
			_put(_plate_along(wide), colour, x, y, z, 0, Rect2i(x, z, wide, 1))
			x += wide

	## The crown, as near the sphere as its cover lets it sit, clear of the
	## top band's highest end. Where a dish laps that end and hides the low
	## panels' ends below it from the middle, that dish; else discs of
	## plates, the first two crossed and as wide as that takes, each one up
	## stepping in as the sphere does, under the dish that covers the last.
	## On a column of round bricks from the ring. Sized to the high ends
	## alone, a dish's rim showed sky over each low end; one flat disc out
	## to the top band in the frame's colour read as a lid on a cone.
	##
	## The dish is held by round plates from the column or the disc up into
	## the 2 x 2 under its middle, and the last disc is tiles wherever a stud
	## would reach under it. Set down on the disc's studs, every shell's dish
	## was held by nothing and had a ring of them pushed into its rim.
	func _crown() -> void:
		var top: Dictionary = bands[-1]
		var end: Vector2 = top["ends"][1]
		var low: Vector2 = top["ends"][0]
		var line_y: float = _line_height(0)
		var at: int = int(ceil((line_y + end.y + 3.0) / PLATE))
		var need: float = end.x + PLATE
		_column(foot + 2, at)
		# The round the tiers step in along: through the top band's high
		# ends, which stand off the sphere by their spacers and tiles.
		var outer: float = maxf(radius + lift, end.length())
		# The discs' layers as [cells, y, along x], laid once the dish is known.
		var layers: Array = []
		var tier: int = 0
		while float(CROWNS[-1][1]) * STUD < need:
			var cells: Dictionary = {}
			_disc(cells, centre, need / STUD + 0.5)
			if tier == 0:
				layers.append([cells.duplicate(), at, true])
				at += 1
			layers.append([cells, at, tier % 2 == 1])
			at += 1
			tier += 1
			# The next in to where the sphere is at its top, by half a plate
			# at least.
			var h: float = (at + 1) * PLATE - line_y
			need = minf(need - PLATE * 0.5, sqrt(maxf(outer * outer - h * h, 0.0)))
		var dish: Array = CROWNS[-1]
		for row: Array in CROWNS:
			if float(row[1]) * STUD >= need:
				dish = row
				break
		var r: float = float(dish[1])
		# Under the dish, but for the 2 x 2 the round plates stand on, the
		# last layer's cells whose stud (6 LDU round its middle) reaches in.
		var under: Dictionary = {}
		if not layers.is_empty():
			var last: Dictionary = layers[-1][0]
			for cell: Vector2i in last.keys():
				var off: Vector2 = Vector2(cell.x + 0.5, cell.y + 0.5) - centre
				if off.length() * STUD < r * STUD + 6.0 and maxf(absf(off.x), absf(off.y)) > 1.0:
					under[cell] = true
					last.erase(cell)
		for layer: Array in layers:
			_lay(layer[0], layer[1], layer[2], PLATES, colour)
		if not under.is_empty():
			_lay(under, at - 1, layers[-1][2], TILES, colour)
		for y: int in range(at, at + int(dish[2])):
			bricks.append({"part": "4032a", "color": frame, "x": centre.x - 1, "y": y,
				"z": centre.y - 1, "rot": 0})
		bricks.append({"part": str(dish[0]), "color": colour, "x": centre.x - r, "y": at,
			"z": centre.y - r, "rot": 0})

	## The equator's height, LDU, for the upper half.
	func _line_height(half: int) -> float:
		var pin: Vector3 = hinge["pin"]
		return ((foot + 3) * PLATE if half == 0 else (foot - 2) * PLATE) + pin.y

	## 2 x 2 round bricks, then round plates, from [param from] up to
	## [param to] plates on the centre.
	func _column(from: int, to: int) -> void:
		var y: int = from
		while y + 3 <= to:
			bricks.append({"part": "3941", "color": frame, "x": centre.x - 1, "y": y,
				"z": centre.y - 1, "rot": 0})
			y += 3
		while y < to:
			bricks.append({"part": "4032a", "color": frame, "x": centre.x - 1, "y": y,
				"z": centre.y - 1, "rot": 0})
			y += 1

	## A ball's stand: a plate on the ground and a column up to the ring.
	## A ball's stand: a plate on the ground and a column of 1 x 1 round
	## bricks up to the ring, through the opening its lower strips leave,
	## thin enough to keep clear of them as they close in.
	func _stand() -> void:
		bricks.append({"part": "3958", "color": frame, "x": centre.x - 3, "y": ground,
			"z": centre.y - 3, "rot": 0})
		var y: int = ground + 1
		while y + 3 <= foot:
			bricks.append({"part": "3062b", "color": frame, "x": centre.x, "y": y,
				"z": centre.y, "rot": 0})
			y += 3
		while y < foot:
			bricks.append({"part": "6141", "color": frame, "x": centre.x, "y": y,
				"z": centre.y, "rot": 0})
			y += 1

	## A row of plates (or [param kind]) from [param from] to [param to]. Their
	## joints fall where the row's own place says, three studs on from the
	## row beside it, not where the run starts: a disc's middle rows all
	## start together, and laid from there both layers of a ball's ring broke
	## at the same lines into blocks eight studs square, each held by nothing.
	func _lay_run(y: int, at: int, from: int, to: int, along_x: bool,
			kind: Dictionary = PLATES, color: int = -1) -> void:
		var shift: int = posmod(at * 3, 8)
		var pieces: Array[int] = []
		var here: int = from
		while here < to:
			var room: int = mini(to - here, 8 - posmod(here + shift, 8))
			for size: int in [8, 6, 4, 3, 2, 1]:
				if size <= room:
					pieces.append(size)
					here += size
					break
		# A stud-long piece at the tip of a run may have only a stud-long
		# piece across it, the pair held by nothing: join it to its neighbour.
		var index := 0
		while pieces.size() > 1 and index < pieces.size():
			if pieces[index] != 1:
				index += 1
				continue
			var other: int = index - 1 if index > 0 else index + 1
			var joined: Array = {2: [2], 3: [3], 4: [4], 5: [3, 2], 7: [4, 3],
				9: [6, 3]}[pieces[other] + 1]
			var first: int = mini(index, other)
			pieces.remove_at(first)
			pieces.remove_at(first)
			for size: int in joined.duplicate():
				pieces.insert(first, size)
				first += 1
			index = 0
		here = from
		for used: int in pieces:
			bricks.append({"part": str(kind[used]), "color": frame if color < 0 else color,
				"x": here if along_x else at, "y": y,
				"z": at if along_x else here, "rot": 0 if along_x else 1})
			here += used

	func _add(part: String, color: int, x: int, y: int, z: int, section: String,
			rot: int) -> void:
		bricks.append({"part": part, "color": color, "x": x, "y": y, "z": z, "rot": rot,
			"section": section})

	## A plate a stud wide and [param long] along the panel.
	static func _plate_along(long: int) -> String:
		return str({1: "3024", 2: "3023b", 3: "3623", 4: "3710", 6: "3666"}[long])

	static func _tile(wide: int, deep: int) -> String:
		var key := Vector2i(maxi(wide, deep), mini(wide, deep))
		return str({Vector2i(1, 1): "3070b", Vector2i(2, 1): "3069b", Vector2i(2, 2): "3068b",
			Vector2i(3, 1): "63864", Vector2i(3, 2): "26603", Vector2i(4, 1): "2431",
			Vector2i(4, 2): "87079", Vector2i(6, 1): "6636", Vector2i(6, 2): "69729"}[key])

	## The quarter turn that lays a part [param wide] studs along x: a part
	## longer than it is wide lies along x at 0.
	static func _turn_for(part: String, wide: int) -> int:
		var long: Dictionary = {"3070b": 1, "3069b": 2, "3068b": 2, "63864": 3, "26603": 3,
			"2431": 4, "87079": 4, "6636": 6, "69729": 6}
		return 0 if int(long.get(part, wide)) == wide else 1

	func out() -> Dictionary:
		var middle: float = _line_height(0)
		if ball:
			middle = (_line_height(0) + _line_height(1)) * 0.5
		# Where a ball is open below, round its stand: the lower strips' end.
		var end: Vector2 = bands[-1]["ends"][0]
		return {"sections": sections, "bricks": bricks, "said": "; ".join(said), "bands": bands,
			"centre": Vector3(centre.x * STUD, middle, centre.y * STUD), "radius": radius + lift,
			"open_below": -rad_to_deg(atan2(end.y, end.x)) if ball else -90.0}
