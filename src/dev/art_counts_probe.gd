## Brick Art's counts, each right for one and for many, in every language
## (smallwords, 2026-11-08). mosaic3 found the dialog saying "1 stars", as
## it said "1 16 × 16 panels" and "in 1 colours", and a session was told
## the same (ArtPlan.said_of).
##
##   godot --headless --path . --script src/dev/art_counts_probe.gd
##
## Every kind of element an Art is laid in, one of it and two, as the
## dialog and a session count them (MosaicArt.Art.element_words, read
## through ArtPlan.said_of), with the parts and the plates it stands up to;
## then the dialog itself, on pictures that come to one and to two: a
## Classic of one plate and of two, in one colour and in two; an Art of one
## panel and of two; a relief one plate and two high; a set's colours and
## the colours owned, one and two. Each count is checked in English, then in
## German, French and Spanish: found whole, nothing left in English, and its
## one said apart from its many. Each line the dialog showed is found whole
## in each language too. Every pair is printed in all four.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
## [one, many]: what was said of one and of two, in English, each checked
## in every language once its English is.
var _pairs: Array = []
## Whole lines the dialog showed, each found in every language.
var _lines: PackedStringArray = []
## A count of two, said as one: what a language's one must not read as.
var _two: RegEx = RegEx.create_from_string(r"(?<![\d.,])2(?![\d.,])")
var _letter: RegEx = RegEx.create_from_string(r"\p{L}")

const SET_NAME := "A picture"


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var dialog := MosaicDialog.new()
	dialog.library = _library
	root.add_child(dialog)
	await process_frame
	_classic_case(dialog)
	_art_case(dialog)
	_palette_case(dialog)
	_elements_case(dialog.last_art)
	_languages_case()
	dialog.queue_free()
	print("")
	print("%d failed" % _failures if _failures else "every count reads right for one and for many")
	quit(1 if _failures else 0)


## A picture [param wide] x [param high], its left half the first colour
## and its right half the last.
static func _picture(wide: int, high: int, colours: Array) -> Image:
	var image := Image.create(wide, high, false, Image.FORMAT_RGB8)
	for y: int in high:
		for x: int in wide:
			image.set_pixel(x, y, colours[0] if x < wide / 2 else colours.back())
	return image


func _classic_case(dialog: MosaicDialog) -> void:
	print("\nClassic: one plate and two, in one colour and in two")
	dialog.set_mode("classic")
	dialog._dither.button_pressed = false
	dialog._mixed.button_pressed = true
	dialog.set_colours("all")
	# A row of studs, one plate long in one colour or a plate a colour: a
	# 1 x 8 is sold in black and in white, where an 8 x 8 picture came to
	# four black plates.
	var read := RegEx.create_from_string(r" — (.+?) for its (\S+) studs, in (.+?): ")
	var plates: Array = []
	var colours: Array = []
	for case: Array in [[8, [Color.BLACK], 1, "1 plate", "1 colour"],
			[16, [Color.BLACK, Color.WHITE], 2, "2 plates", "2 colours"],
			[16, [Color.BLACK], 2, "2 plates", "1 colour"]]:
		dialog.show_for(_picture(int(case[0]), 1, case[1]))
		dialog._slider.value = int(case[0])
		dialog._work_out()
		var detail: String = dialog._detail.text
		var found: RegExMatch = read.search(detail)
		var laid: int = dialog.last_classic.plates.size() if dialog.last_classic != null else 0
		var said: Array = [found.get_string(1), found.get_string(3)] if found != null else ["", ""]
		_check("%d x 1 studs in %d colour%s, %d plate%s laid: \"%s\"" % [int(case[0]),
			(case[1] as Array).size(), "" if (case[1] as Array).size() == 1 else "s", laid,
			"" if laid == 1 else "s", detail], laid == int(case[2]) and said == [case[3], case[4]])
		_lines.append(detail)
		plates.append(said[0])
		colours.append(said[1])
	_pairs.append(plates.slice(0, 2))
	_pairs.append([colours[0], colours[1]])


## The kinds a Brick Art detail line lists, each as it says it.
static func _listed(detail: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part: String in detail.split(" — "):
		out.append_array(part.split(" · "))
	return out


func _art_case(dialog: MosaicDialog) -> void:
	print("\nBrick Art: one panel and two, and a relief one plate and two high")
	dialog.set_mode("art")
	dialog.set_colours("all")
	var panels: Array = []
	for across: int in [1, 2]:
		dialog.show_for(_picture(16 * across, 16, [Color(0.15, 0.25, 0.55), Color(0.9, 0.8, 0.2)]))
		dialog._panels.value = across
		dialog._describe()
		dialog._work_out()
		var detail: String = dialog._detail.text
		var said: String = ""
		for kind: String in _listed(detail):
			if kind.ends_with("16 × 16 panel") or kind.ends_with("16 × 16 panels"):
				said = kind
		_check("%d x 1 panels: \"%s\"" % [across, detail],
			said == ("1 16 × 16 panel" if across == 1 else "2 16 × 16 panels"))
		_lines.append(detail)
		panels.append(said)
	_pairs.append(panels)
	var high: Array = []
	for depth: int in [1, 2]:
		dialog._depth.value = depth
		dialog._describe()
		high.append(dialog._depth_said.text)
		_check("a relief %d plate%s high: \"%s\"" % [depth, "" if depth == 1 else "s", high.back()],
			high.back() == ("1 plate" if depth == 1 else "2 plates"))
	_pairs.append(high)
	# Laid again one panel across, flat, for the elements below.
	dialog._depth.value = 0
	dialog.show_for(_picture(16, 16, [Color(0.15, 0.25, 0.55), Color(0.9, 0.8, 0.2)]))
	dialog._panels.value = 1
	dialog._describe()
	dialog._work_out()


func _palette_case(dialog: MosaicDialog) -> void:
	print("\na set's colours and the colours owned, one and two")
	dialog.set_mode("classic")
	dialog._set_found = "40000-1"
	dialog._set_name = SET_NAME
	dialog.set_colours("set")
	var said: Array = []
	for codes: Array in [[0], [0, 15]]:
		dialog.palette = PackedInt32Array(codes)
		dialog._tell_palette()
		var line: String = dialog._palette_said.text
		var wanted: String = "40000 “%s”: %s" % [SET_NAME, "1 colour" if codes.size() == 1 else "2 colours"]
		_check("a set of %d colour%s: \"%s\"" % [codes.size(), "" if codes.size() == 1 else "s", line],
			line == wanted)
		said.append(line)
	_pairs.append(said)
	said = []
	for owned: Dictionary in [{"3024/0": 5}, {"3024/0": 5, "3024/15": 5}]:
		dialog.owned = func() -> Dictionary: return owned
		dialog.set_colours("owned")
		var line: String = dialog._palette_said.text
		var wanted: String = ("1 colour you own its parts in" if owned.size() == 1
			else "2 colours you own its parts in")
		_check("plates owned in %d colour%s: \"%s\"" % [owned.size(), "" if owned.size() == 1 else "s",
			line], line == wanted)
		said.append(line)
	_pairs.append(said)
	dialog.set_colours("all")


## Each kind of element an Art is laid in: one of it and two, as a session
## is told them (ArtPlan.said_of counts them as the dialog does).
func _elements_case(art: MosaicArt.Art) -> void:
	print("\nevery kind of element, one and two, with the parts and the plates it stands up to")
	if art == null:
		_check("an Art was laid to count", false)
		return
	var kinds: Array = [
		# part, colour, panel, one, many
		[MosaicArt.JOINER, 0, -1, "joining plate", "joining plates"],
		[MosaicArt.BASE, 0, 0, "16 × 16 panel", "16 × 16 panels"],
		[MosaicArt.ROUND, MosaicArt.ACCENTS[0], 0, "star", "stars"],
		[MosaicArt.ROUND, 15, 0, "round tile", "round tiles"],
		[MosaicArt.BIG_ROUND, MosaicArt.ACCENTS[0], 0, "large star", "large stars"],
		[MosaicArt.SQUARE, 15, 0, "square tile", "square tiles"],
		[MosaicArt.QUARTER, 15, 0, "quarter circle", "quarter circles"],
		[MosaicArt.SPECK, 15, 0, "round plate", "round plates"],
		[MosaicArt.SLOPE, 15, 0, "cheese slope", "cheese slopes"],
		[str(MosaicArt.TILES[0][0]), 15, 0, "larger tile", "larger tiles"],
		[MosaicArt.RISER, 15, 0, "relief plate", "relief plates"],
	]
	var read := RegEx.create_from_string(r"standing up to (.+?): (.+?) — (.+)\.$")
	var parts: Array = []
	for kind: Array in kinds:
		var words: Array = []
		for many: int in [1, 2]:
			art.placements.clear()
			art.panel_of = PackedInt32Array()
			for _n: int in many:
				var placement := Assistant.Placement.new()
				placement.part = str(kind[0])
				placement.color = int(kind[1])
				art.placements.append(placement)
				art.panel_of.append(int(kind[2]))
			art.plan.relief.fill(0)
			art.plan.relief[0] = many
			var said: String = ArtPlan.said_of(art)
			var found: RegExMatch = read.search(said)
			var wanted: Array = (["1 plate", "1 part", "1 " + str(kind[3])] if many == 1
				else ["2 plates", "2 parts", "2 " + str(kind[4])])
			var got: Array = [found.get_string(1), found.get_string(2), found.get_string(3)] \
				if found != null else []
			_check("%d %s: \"…%s\"" % [many, str(kind[3]), said.get_slice("standing ", 1)], got == wanted)
			# What it said, so a language is asked for the words it was given.
			words.append(got[2] if not got.is_empty() else wanted[2])
			if parts.size() < 2:
				parts.append(got[1] if not got.is_empty() else wanted[1])
		_pairs.append(words)
	# The parts, said the same whatever they are.
	_pairs.append(parts)


func _languages_case() -> void:
	print("\neach count in German, French and Spanish: found whole, its one said apart from its many")
	var said: Dictionary = {}
	var lines_left: Dictionary = {}
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		said[code] = []
		for pair: Array in _pairs:
			var one: String = Language.says(pair[0])
			var many: String = Language.says(pair[1])
			var left: Array = _english(pair[0]) + _english(pair[1])
			(said[code] as Array).append([one, many, left])
		lines_left[code] = []
		for line: String in _lines:
			var whole: String = Language.says(line)
			var left: Array = _english(line)
			print("    %s: %s" % [code, whole])
			if whole.is_empty() or not left.is_empty():
				(lines_left[code] as Array).append("%s (%s)" % [line, ", ".join(left)])
	Language.apply("en")
	for n: int in _pairs.size():
		var pair: Array = _pairs[n]
		var row: PackedStringArray = ["%s / %s" % pair]
		var ok: bool = true
		for code: String in ["de", "fr", "es"]:
			var one: String = said[code][n][0]
			var many: String = said[code][n][1]
			var left: Array = said[code][n][2]
			row.append("%s %s / %s%s" % [code, one, many, "" if left.is_empty() else
				" (in English: %s)" % ", ".join(left)])
			ok = ok and not one.is_empty() and not many.is_empty() and left.is_empty() \
				and one != _two.sub(many, "1", true)
		_check(" — ".join(row), ok)
	for code: String in ["de", "fr", "es"]:
		var lacking: Array = lines_left[code]
		_check("%s: each of the %d lines the dialog showed found whole%s" % [code, _lines.size(),
			"" if lacking.is_empty() else "; not: " + " | ".join(lacking)], lacking.is_empty())


## What [param text] keeps in English in the language in use: words, not a
## number or a set's name.
func _english(text: String) -> Array:
	var out: Array = []
	for kept: String in Language.left_in_english(text):
		if _letter.search(kept) != null and kept != SET_NAME:
			out.append(kept)
	return out
