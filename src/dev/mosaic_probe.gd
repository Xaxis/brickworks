## Check a picture comes out looking like the picture.
##
##   godot --headless --path . --script src/dev/mosaic_probe.gd [-- --ldr=PATH]
##
## The failure that matters is not a crash — it is a mosaic that is
## recognisably the wrong colours, which looks like a working feature
## until you hold it against the photograph. So the checks are on the
## colour decisions: a flat red square must come out red, the palette
## must be honoured, and Oklab has to survive the round trip the dither
## depends on.
##
## Then the Art mode (MosaicArt), which is the classic mosaic's colour
## matching laid as a LEGO Art set is: a galaxy has to come out with its
## stars in round tiles, its core raised, quarter circles along its arms
## and the whole of it one piece; a flat picture in merged tiles, fewer
## parts than plates; every element in a colour it is made in; and the
## parts list and the booklet right. --ldr writes the galaxy for a render.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _checker: Assistant
var _store: ModelStore

## What the classic mosaic of the probe's gradient came to before the Art
## mode was written, as a hash of every plate's place and colour. The Art
## mode is a file of its own; this is what says the classic one did not move.
const CLASSIC_PRINT := 3764428421


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_classic()
	await _art()
	print("")
	print("%d failed" % _failures if _failures else "the mosaic reads true")
	quit(1 if _failures else 0)


func _classic() -> void:
	var library: PartLibrary = _library
	var palette := PackedInt32Array(Mosaic.PALETTE)
	print("the classic mosaic")
	print("  palette: %d colours" % palette.size())

	# Oklab both ways. The dither subtracts a matched colour from the
	# wanted one, so a lossy round trip becomes error injected into every
	# neighbour — noise that looks like grain.
	#
	# The comparison is in linear, because that is what both sides of
	# that subtraction are: the image buffer is decoded once up front and
	# _from_oklab hands back light rather than encoded values.
	var drift: float = 0.0
	for sample: Color in [Color.RED, Color.WHITE, Color.BLACK,
			Color(0.2, 0.45, 0.7), Color(0.9, 0.85, 0.1)]:
		var back: Color = Mosaic._from_oklab(Mosaic._oklab(sample))
		drift = maxf(drift, absf(back.r - Mosaic._linear(sample.r)))
		drift = maxf(drift, absf(back.g - Mosaic._linear(sample.g)))
		drift = maxf(drift, absf(back.b - Mosaic._linear(sample.b)))
	_check("Oklab round-trips in linear, worst channel off by %.5f" % drift,
		drift < 0.001)

	# A flat square of one colour, which must come back as that colour
	# and nothing else.
	var flat := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	flat.fill(library.color(4).rgb)   # Red
	var laid: Array[Mosaic.Pixel] = Mosaic.lay_out(flat, 16, palette, library, false)
	_check("a 16 x 16 square makes 256 plates, got %d" % laid.size(),
		laid.size() == 256)
	var all_red: bool = true
	for pixel: Mosaic.Pixel in laid:
		if pixel.color_code != 4:
			all_red = false
	_check("a red square comes out red", all_red)

	# Every colour chosen has to be one you can actually buy.
	var gradient := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			gradient.set_pixel(x, y, Color(x / 31.0, y / 31.0, 0.5))
	var mixed: Array[Mosaic.Pixel] = Mosaic.lay_out(
		gradient, 32, palette, library, true)
	var stray: int = 0
	var used: Dictionary = {}
	var said := PackedStringArray()
	for pixel: Mosaic.Pixel in mixed:
		used[pixel.color_code] = true
		said.append("%d,%d,%d" % [pixel.x, pixel.z, pixel.color_code])
		if not palette.has(pixel.color_code):
			stray += 1
	_check("every plate is a palette colour (%d strays)" % stray, stray == 0)
	_check("a gradient uses more than a handful of colours, got %d"
		% used.size(), used.size() >= 6)
	var print_of: int = " ".join(said).hash()
	_check("the classic mosaic lays the gradient as it did (%d)" % print_of,
		print_of == CLASSIC_PRINT)

	# Dithering is the difference between a gradient and three stripes.
	var banded: Array[Mosaic.Pixel] = Mosaic.lay_out(
		gradient, 32, palette, library, false)
	var flat_colours: Dictionary = {}
	for pixel: Mosaic.Pixel in banded:
		flat_colours[pixel.color_code] = true
	_check("dithering uses more colours than not: %d vs %d"
		% [used.size(), flat_colours.size()], used.size() > flat_colours.size())

	# A transparent background is a hole, not a black slab.
	var logo := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	logo.fill(Color(0, 0, 0, 0))
	for n: int in 16:
		logo.set_pixel(n, 8, Color(1, 1, 1, 1))
	var sparse: Array[Mosaic.Pixel] = Mosaic.lay_out(
		logo, 16, palette, library, false)
	_check("transparent pixels are left out, got %d plates" % sparse.size(),
		sparse.size() == 16)

	# Non-square images keep their proportions.
	var wide := Image.create_empty(64, 16, false, Image.FORMAT_RGBA8)
	wide.fill(Color.WHITE)
	var stretched: Array[Mosaic.Pixel] = Mosaic.lay_out(
		wide, 32, palette, library, false)
	var depth: int = 0
	for pixel: Mosaic.Pixel in stretched:
		depth = maxi(depth, pixel.z + 1)
	_check("a 4:1 picture stays 4:1, got 32 x %d" % depth, depth == 8)


func _art() -> void:
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_checker = Assistant.new()
	_checker.library = _library
	_checker.world = _world
	_checker.builder = _builder
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame

	print("\nthe Art mode: which way the shaped elements face")
	# The turn tables are written down because a browser lays a picture
	# before it has the parts; here they are read off the meshes again.
	var quarter: Lbm.PartMesh = _library.mesh_for(MosaicArt.QUARTER)
	var slope: Lbm.PartMesh = _library.mesh_for(MosaicArt.SLOPE)
	var quarters_ok: bool = quarter != null
	var slopes_ok: bool = slope != null
	for facing: Vector2i in MosaicArt.QUARTER_TURN:
		var lean: Vector2 = Rounds.lean(quarter, int(MosaicArt.QUARTER_TURN[facing]))
		if quarter == null or Vector2i(lean) != -facing:
			quarters_ok = false
	for rising: Vector2i in MosaicArt.SLOPE_TURN:
		var lean: Vector2 = Rounds.lean(slope, int(MosaicArt.SLOPE_TURN[rising]))
		if slope == null or Vector2i(lean) != rising:
			slopes_ok = false
	_check("a quarter circle's curve faces where its turn says", quarters_ok)
	_check("a cheese slope rises toward where its turn says", slopes_ok)

	await _galaxy_case()
	_flat_case()
	_switches_case()
	await _dialog_case()


## A dark sky with points of light, a bright core and two spiral arms.
## Drawn at two pixels a stud, so a star is a stud.
func _galaxy(studs: int) -> Dictionary:
	var size: int = studs * 2
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var sky := Color(0.02, 0.025, 0.07)
	var arm := Color(0.55, 0.68, 1.0)
	var core := Color(1.0, 0.93, 0.75)
	var lit := PackedFloat32Array()
	lit.resize(studs * studs)
	var centre := Vector2(size / 2.0, size / 2.0)
	for y: int in size:
		for x: int in size:
			var at := Vector2(x + 0.5, y + 0.5) - centre
			var r: float = at.length() / size
			var theta: float = atan2(at.y, at.x)
			var arms: float = 0.0
			for k: int in 2:
				var want: float = 3.2 * log(maxf(r, 0.02) / 0.05) + k * PI
				var off: float = absf(wrapf(theta - want, -PI, PI))
				arms = maxf(arms, clampf(1.0 - off / 0.55, 0.0, 1.0))
			arms *= clampf((0.46 - r) / 0.12, 0.0, 1.0) * clampf((r - 0.05) / 0.05, 0.0, 1.0)
			arms = 1.0 if arms > 0.35 else 0.0
			var glow: float = clampf(1.0 - r / 0.11, 0.0, 1.0)
			var c: Color = sky.lerp(arm, arms)
			c = c.lerp(core, clampf(glow * 1.6, 0.0, 1.0))
			image.set_pixel(x, y, c)
			var cell: int = x / 2 + (y / 2) * studs
			lit[cell] = maxf(lit[cell], maxf(arms, 1.0 if glow > 0.3 else 0.0))
	# Stars, in the sky, apart.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31212
	var stars: Array[Vector2i] = []
	for _try: int in 400:
		if stars.size() >= 40:
			break
		var s := Vector2i(rng.randi_range(2, studs - 3), rng.randi_range(2, studs - 3))
		var clear: bool = true
		for dz: int in range(-2, 3):
			for dx: int in range(-2, 3):
				if lit[(s.x + dx) + (s.y + dz) * studs] > 0.0:
					clear = false
		for other: Vector2i in stars:
			if absi(other.x - s.x) <= 2 and absi(other.y - s.y) <= 2:
				clear = false
		if not clear:
			continue
		stars.append(s)
		for dy: int in 2:
			for dx: int in 2:
				image.set_pixel(s.x * 2 + dx, s.y * 2 + dy, Color(1, 1, 1))
	return {"image": image, "stars": stars, "lit": lit}


func _galaxy_case() -> void:
	print("\na galaxy: dark sky, stars, a bright core and two arms, 3 x 3 panels")
	var made: Dictionary = _galaxy(48)
	var options := MosaicArt.Options.new()
	var began: int = Time.get_ticks_msec()
	var art: MosaicArt.Art = MosaicArt.make(made["image"], options, _library)
	var plan: MosaicArt.Plan = art.plan
	print("  laid in %d ms: %d parts — %s" % [Time.get_ticks_msec() - began,
		art.placements.size(), _words(art)])
	_check("48 x 48 studs on 3 x 3 panels", plan.across == 48 and plan.down == 48
		and art.panels == Vector2i(3, 3))
	_check("on black panels (%d)" % art.base_colour, art.base_colour == 0)

	# Stars: round tiles, in an accent finish, a plate proud.
	var at_star: int = 0
	var finishes: Dictionary = {}
	var stars: Array[Vector2i] = made["stars"]
	var tops: Dictionary = _tops(art)
	for star: Vector2i in stars:
		var top: Assistant.Placement = tops.get(star)
		if top != null and top.part == MosaicArt.ROUND and MosaicArt.ACCENTS.has(top.color) \
				and plan.relief[plan.at(star.x, star.y)] >= 1:
			at_star += 1
			finishes[_library.color(top.color).name] = true
	_check("%d of %d stars are round tiles in an accent finish set a plate proud (%s)"
		% [at_star, stars.size(), ", ".join(PackedStringArray(finishes.keys()))],
		at_star >= stars.size() * 3 / 4)

	# The core raised, the sky not.
	var middle: int = plan.relief[plan.at(24, 24)]
	var corners: int = 0
	for c: Vector2i in [Vector2i(1, 1), Vector2i(46, 1), Vector2i(1, 46), Vector2i(46, 46)]:
		corners = maxi(corners, plan.relief[plan.at(c.x, c.y)])
	_check("the core stands %d plates up, the sky's corners %d" % [middle, corners],
		middle >= options.depth - 1 and corners == 0)
	var slopes: int = int(art.counts().get(MosaicArt.SLOPE, 0))
	_check("cheese slopes on the way down from it: %d" % slopes, slopes >= 8)

	# Quarter circles along the arms' edges, curve out.
	var lit: PackedFloat32Array = made["lit"]
	var quarters: int = 0
	var on_rim: int = 0
	for placement: Assistant.Placement in art.placements:
		if placement.part != MosaicArt.QUARTER:
			continue
		quarters += 1
		var x: int = int(placement.x)
		var z: int = int(placement.z)
		var inside: bool = false
		var outside: bool = false
		for dz: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if plan.inside(x + dx, z + dz):
					if lit[(x + dx) + (z + dz) * 48] > 0.0:
						inside = true
					else:
						outside = true
		if inside and outside:
			on_rim += 1
	_check("%d quarter circles, %d of them on an arm's or the core's edge" % [quarters, on_rim],
		quarters >= 12 and on_rim * 10 >= quarters * 8)

	_check_made_in(art)
	_check_one_piece(art, "the galaxy")

	# Without the plates under the seams it is nine pictures, not one:
	# what says the check above is about the frame.
	var loose: MosaicArt.Art = MosaicArt.Art.new()
	for index: int in art.placements.size():
		if art.panel_of[index] >= 0:
			loose.placements.append(art.placements[index])
	var apart: Dictionary = _checker._check(loose.model(), true)
	_check("without its frame it is %d pieces" % int(apart.get("pieces", 0)),
		int(apart.get("pieces", 0)) >= 9)

	# Into the world as main puts it, then the parts list and the booklet.
	_world.clear()
	_builder.lattice.clear()
	var ids: PackedInt64Array = MosaicArt.put_down(art, _world, _builder, _checker)
	_check("every part went into the world: %d of %d" % [ids.size(), art.placements.size()],
		ids.size() == art.placements.size())
	var stock: Inventory = Inventory.of(_world, _library, {})
	var listed: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		listed[lot.part_id] = int(listed.get(lot.part_id, 0)) + lot.count
	var counts: Dictionary = art.counts()
	var agree: bool = stock.pieces == art.placements.size()
	for part: String in counts:
		if int(listed.get(part, 0)) != int(counts[part]):
			agree = false
	_check("the parts list has %d pieces in %d lots, part for part what was laid"
		% [stock.pieces, stock.lots.size()], agree)
	var t0: int = Time.get_ticks_msec()
	var steps: Array[Instructions.Step] = Instructions.plan(_world, _library)
	var seen: Dictionary = {}
	var sections: Dictionary = {}
	var twice: int = 0
	for step: Instructions.Step in steps:
		sections[step.section] = true
		for brick_id: int in step.brick_ids:
			if seen.has(brick_id):
				twice += 1
			seen[brick_id] = true
	var panels: int = 0
	for section: String in sections:
		if section.begins_with("Panel "):
			panels += 1
	_check("the booklet: %d steps in %d ms, every part once (%d of %d, %d twice), a panel at a time (%d panels)"
		% [steps.size(), Time.get_ticks_msec() - t0, seen.size(), ids.size(), twice, panels],
		seen.size() == ids.size() and twice == 0 and panels == 9)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ldr="):
			var path: String = arg.substr(6)
			print("  wrote %s: %s" % [path, _store.export_to(path, "Galaxy")])


func _flat_case() -> void:
	print("\na flat red picture, 2 x 2 panels")
	var flat := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	flat.fill(_library.color(4).rgb)
	var options := MosaicArt.Options.new()
	options.panels_across = 2
	var art: MosaicArt.Art = MosaicArt.make(flat, options, _library)
	var top: int = 0
	var red: bool = true
	var raised: int = 0
	for placement: Assistant.Placement in art.placements:
		if placement.y < MosaicArt.SURFACE:
			continue
		top += 1
		raised = maxi(raised, int(placement.y) - MosaicArt.SURFACE)
		if placement.color != 4:
			red = false
	var counts: Dictionary = art.counts()
	print("  %d parts — %s" % [art.placements.size(), _words(art)])
	_check("1,024 studs in %d tiles, %d of them 2 x 4" % [top, int(counts.get("87079", 0))],
		top <= 1024 / 6 and int(counts.get("87079", 0)) >= 100)
	_check("fewer parts all told than the classic mosaic's 1,024 plates: %d"
		% art.placements.size(), art.placements.size() < 1024 / 3)
	_check("all red, flat, and no quarter circles", red and raised == 0
		and not counts.has(MosaicArt.QUARTER) and not counts.has(MosaicArt.SLOPE))
	_check_made_in(art)
	_check_one_piece(art, "the flat picture")


## The switches do what they say: flat is flat, and the element styles turned
## off are not used.
func _switches_case() -> void:
	print("\nthe dialog's switches")
	var made: Dictionary = _galaxy(32)
	var options := MosaicArt.Options.new()
	options.panels_across = 2
	options.depth = 0
	options.round_texture = false
	options.contours = false
	var art: MosaicArt.Art = MosaicArt.make(made["image"], options, _library)
	var counts: Dictionary = art.counts()
	var highest: int = 0
	for placement: Assistant.Placement in art.placements:
		highest = maxi(highest, int(placement.y))
	_check("depth 0 lays every element on the panel (highest at plate %d)" % highest,
		highest == MosaicArt.SURFACE)
	_check("contours off: no quarter circles; round texture off: no round tiles (%s)"
		% _words(art), not counts.has(MosaicArt.QUARTER) and not counts.has(MosaicArt.ROUND))
	_check("and flat, a star is a round plate, stud proud: %d"
		% int(counts.get(MosaicArt.SPECK, 0)), int(counts.get(MosaicArt.SPECK, 0)) >= 10)
	_check_one_piece(art, "the flat galaxy")


## The dialog: Art by default, the count by element and the picture of the
## result before anything is built, and Build it asking for what was chosen.
func _dialog_case() -> void:
	print("\nthe dialog")
	var dialog := MosaicDialog.new()
	dialog.library = _library
	root.add_child(dialog)
	await process_frame
	var made: Dictionary = _galaxy(32)
	dialog.show_for(made["image"])
	dialog._panels.value = 2
	dialog._work_out()
	var said: String = dialog._detail.text
	_check("opens in LEGO Art and says what it comes to: \"%s\"" % said,
		dialog.is_art() and said.contains("round tiles") and said.contains("16 × 16 panels")
		and said.contains("32 × 32 studs"))
	var shown: Texture2D = dialog._preview.texture
	_check("and draws the result, %s" % (str(shown.get_size()) if shown != null else "nothing"),
		shown != null and shown.get_width() == 32 * 8)
	var asked: Array = []
	dialog.art_wanted.connect(func(options: MosaicArt.Options) -> void: asked.append(options))
	dialog._depth.value = 0
	dialog._round.button_pressed = false
	dialog.build()
	var chosen: MosaicArt.Options = asked[0] if not asked.is_empty() else null
	_check("Build it asks for the Art as chosen: depth %s, round texture %s"
		% [str(chosen.depth) if chosen else "-", str(chosen.round_texture) if chosen else "-"],
		chosen != null and chosen.depth == 0 and not chosen.round_texture
		and chosen.panels_across == 2 and chosen.panels_down == 2)
	var classic: Array = []
	dialog.build_wanted.connect(func(across: int, _dither: bool) -> void: classic.append(across))
	dialog.set_mode("classic")
	dialog.build()
	_check("and Classic still asks for plates %d wide" % (classic[0] if classic else 0),
		classic.size() == 1 and asked.size() == 1)
	dialog.queue_free()


func _tops(art: MosaicArt.Art) -> Dictionary:
	var out: Dictionary = {}
	for placement: Assistant.Placement in art.placements:
		if placement.y < MosaicArt.SURFACE:
			continue
		var key := Vector2i(int(placement.x), int(placement.z))
		var was: Assistant.Placement = out.get(key)
		if was == null or placement.y > was.y:
			out[key] = placement
	return out


func _check_made_in(art: MosaicArt.Art) -> void:
	var wrong := PackedStringArray()
	for placement: Assistant.Placement in art.placements:
		var info: PartLibrary.PartInfo = _library.parts.get(placement.part)
		if info == null or info.never_made_in(placement.color):
			wrong.append("%s in %d" % [placement.part, placement.color])
	_check("every element in a colour it is made in (%d not: %s)"
		% [wrong.size(), ", ".join(wrong.slice(0, 5))], wrong.is_empty())


func _check_one_piece(art: MosaicArt.Art, what: String) -> void:
	var t0: int = Time.get_ticks_msec()
	var report: Dictionary = _checker._check(art.model(), true)
	_check("%s is one buildable piece: %s, %d piece%s, nothing floating, in %d ms"
		% [what, str(report.get("summary", "")), int(report.get("pieces", 0)),
		"" if int(report.get("pieces", 0)) == 1 else "s", Time.get_ticks_msec() - t0],
		bool(report.get("ok", false)) and int(report.get("pieces", 0)) == 1
		and (report.get("floating", []) as Array).is_empty())


func _words(art: MosaicArt.Art) -> String:
	var said := PackedStringArray()
	for entry: Array in art.by_element():
		said.append("%d %s" % [int(entry[1]), str(entry[0])])
	return ", ".join(said)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
