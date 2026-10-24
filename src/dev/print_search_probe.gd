## Does a search find a printed part by what is printed on it?
##
##   godot --headless --path . --script src/dev/print_search_probe.gd
##
## "porsche print" did not find 3623pt1, Plate 1 x 3 with "PORSCHE" First
## Half Pattern, and "turbo print" did not find 15068pt2 (2026-10-13).
## Every word of a query had to be in a part's name, and LDraw's names
## say "Pattern" where a builder says "print", so a word that only asks
## for a print found nothing. A part's !KEYWORDS were in the catalogue
## and no search read them: 15068pt2 is the turbo on a Porsche, and only
## its keywords say Porsche.
##
## A designer that cannot find a print does not know there is one. It
## builds a logo out of plates, or goes without. So the tool results say
## when a part has prints, as well as finding them when asked.
##
## The same queries go through the assistant's search (search_parts, and
## so the MCP tool) and the parts bin's, which rank with the same code.
extends SceneTree

## What somebody types, the parts any one of which is a right answer, and
## how far down the list it may be: two rows of the bin's four columns.
## Each answer was read off the catalogue by hand: a part with the thing
## printed on it, not a part shaped like it (a flame print is a tile with
## flames on, not the transparent flame piece with a marbled pattern).
const PRINTS: Array = [
	["porsche print", ["3623pt1", "3623pt2", "4162pt3", "42918p02"], 8],
	["turbo print", ["15068pt2"], 3],
	["flame print", ["98138pm7", "3069bp0x", "3039pc2", "92262py0", "92263py0"], 8],
	["eye print", ["98138p07", "3005pe1"], 8],
	["control panel print", ["2431pc1", "3039pcc", "3039pcl", "3069bp61", "3069bpa2"], 8],
	["computer screen print", ["3039p23", "3039pca", "15210pc0", "30258pc0"], 8],
	["number 1 print", ["87079pz0"], 8],
	["racing stripes print", ["15068p07"], 8],
	["wood grain print", ["2431p03", "63864p04", "6636p10", "2431p01"], 8],
	["grille print", ["3001p10", "3004p06", "3004p05", "3004p12", "2431p72"], 8],
	["gauge print", ["3039pc1", "3068bp70", "3069bpa0", "3069bpc2"], 8],
	# Most minifigure heads are named for their expression and never say
	# face; these say it.
	["face print", ["3004p51", "3024ptc9", "3005p04", "3005p05", "3004p0c", "3622px1",
		"3622px3", "3070bp1d", "3070bp1f", "3001pe1", "69729p05", "1751p01"], 8],
	# Speed Champions marks.
	["ferrari print", ["3069bpt9", "2431pc2", "3024p03", "2431ptc"], 8],
	["mclaren print", ["14769pt0", "63864pc0"], 8],
	["chevrolet print", ["3623pt3"], 8],
	["lamborghini print", ["4162pt1", "3068bpta", "2431pc3"], 8],
	["bugatti print", ["3023bp01", "89679pt1"], 8],
	["koenigsegg print", ["98138pt7", "14769pt3", "87079pte"], 8],
	["audi print", ["18973p03", "76382py5", "76382py6"], 8],
	# By the part it is printed on, and by the other words for a print.
	["3623 print", ["3623pt1"], 15],
	["plate 1x3 print", ["3623pt1"], 15],
	["printed plate 1 x 3", ["3623pt1"], 15],
	["porsche pattern", ["3623pt1"], 8],
	["patterned tile 1x8 porsche", ["4162pt3"], 3],
	["15068 printed", ["15068pt2"], 30],
	# A sticker put on a part is found as one, and a sticker itself.
	["porsche sticker", ["93606dy3", "3010d0q", "6636d0d", "87079d0y", "2431d0p"], 8],
]

## Plain parts asked for plainly, which must not move: the part each led
## with before prints could be found (at 960498a), and the first two rows
## the same as an index of names alone gives.
const PLAIN: Array = [
	["1x2 plate", "3023b"], ["plate 1 x 2", "3023b"], ["brick 2x4", "3001"],
	["2x4 brick", "3001"], ["tile 2 x 2", "3068b"], ["tile 1 x 2", "3069b"],
	["plate 2x8", "3034"], ["plate 4x4", "3031"], ["slope 45 2 x 2", "3039"],
	["cheese slope", "54200"], ["3001", "3001"], ["3623", "3623"],
	["round plate 1 x 1", "6141"], ["technic pin", "3673"],
	["bracket 1 x 2", "93274"], ["headlight brick", "4070"],
	["wedge plate", "51739"], ["jumper", "87580"], ["arch 1 x 4", "3659"],
	["cone", "4589"], ["window", "3853"], ["wheel", "4624"],
]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var bin := PartsBin.new()
	bin.library = library
	if library.has_method("_index_prints"):
		var started: int = Time.get_ticks_usec()
		library.call("_index_prints")
		var indexed: int = Time.get_ticks_usec()
		library.search("porsche print", 15)
		var first: int = Time.get_ticks_usec()
		library.search("brick 2 x 4", 15)
		print("  (indexing the prints %d ms; a first search %d ms, the next %d ms)" % [
			(indexed - started) / 1000, (first - indexed) / 1000,
			(Time.get_ticks_usec() - first) / 1000])

	print("  a print, found by what is printed on it")
	for row: Array in PRINTS:
		var asked: String = row[0]
		var within: int = row[2]
		var wanted: Array = row[1]
		var searched: Array = _ids(library.search(asked, within))
		var binned: Array = _ids(bin._find(asked, "All").slice(0, within))
		var hit: String = _first_of(wanted, searched)
		var in_bin: String = _first_of(wanted, binned)
		if hit.is_empty() or in_bin.is_empty():
			_fail("%s -> %s in search, %s in the bin; wanted one of %s in the first %d"
				% [asked, _brief(searched), _brief(binned), str(wanted), within])
			continue
		# A print asked for is answered with prints, not with plain parts
		# that happen to share a word.
		var plain: Array = []
		for info: PartLibrary.PartInfo in library.search(asked, 8):
			if not _decorated(info):
				plain.append(info.id)
		if not plain.is_empty():
			_fail("%s is answered with plain parts in its first 8: %s" % [asked, str(plain)])
			continue
		print("  ok    %-22s %s at %d, %s" % [asked, hit, searched.find(hit) + 1,
			library.parts[hit].name.strip_edges().substr(0, 50)])

	# The bin keeps to the parts with every word, in the order names alone
	# give. search_parts ranks every part by the words it has (PartSearch)
	# and lists the plain parts before their prints and stickers, so past its
	# first answer it is not that order: it is held to the same first answer,
	# and to no print or sticker ahead of a plain part.
	print("")
	print("  plain parts asked for plainly do not move")
	for row: Array in PLAIN:
		var asked: String = row[0]
		var found: Array[PartLibrary.PartInfo] = library.search(asked, 8)
		var searched: Array = _ids(found)
		var binned: Array = _ids(bin._find(asked, "All").slice(0, 8))
		var by_name: Array = _ids(_by_name_alone(library, asked).slice(0, 8))
		var led: String = searched[0] if not searched.is_empty() else "nothing"
		var crowded: bool = false
		var after_a_print: bool = false
		for info: PartLibrary.PartInfo in found:
			after_a_print = after_a_print or _decorated(info)
			crowded = crowded or (after_a_print and not _decorated(info)
				and _as_good(info, asked, found[0]))
		if led != row[1] or binned != by_name or crowded:
			_fail("%s -> %s (the bin %s), wanted %s first, the bin what names alone give, %s%s"
				% [asked, str(searched), str(binned), row[1], str(by_name),
				", and no print before a plain part" if crowded else ""])
			continue
		print("  ok    %-22s %s" % [asked, ", ".join(PackedStringArray(searched.slice(0, 5)))])

	# The figure builder's search read the name and number alone too: a
	# torso printed as Homer says so only in its keywords.
	var homer: PartLibrary.PartInfo = library.parts.get("16360pd11")
	if homer == null or not MinifigDialog._matches(homer, PackedStringArray(["homer"])):
		_fail("the figure builder's search does not find 16360pd11 by \"homer\"")
	else:
		print("  ok    the figure builder finds 16360pd11 by \"homer\"")

	print("")
	print("  and the designer is told a part has prints")
	var assistant := Assistant.new()
	assistant.library = library
	get_root().add_child(assistant)
	var said: String = str(await assistant._tool_answer({"name": "search_parts",
		"input": {"query": "plate 1 x 3", "limit": 5}}))
	var counted: int = 0
	var example: String = ""
	if library.has_method("prints_of"):
		for info: PartLibrary.PartInfo in library.call("prints_of", "3623"):
			counted += 1
			if example.is_empty():
				example = info.id
	var note := "3623 has %d prints" % counted
	if counted < 5 or not said.contains(note) or not said.contains(example + " ") \
			or not said.contains("\"3623 print\""):
		_fail("search_parts \"plate 1 x 3\" does not say %s, name one and how to list them:\n%s"
			% [note, said])
	else:
		print("  ok    plate 1 x 3: %s" % said.substr(said.find(note)).get_slice("\n", 0))
	var porsche: String = str(await assistant._tool_answer({"name": "search_parts",
		"input": {"query": "porsche print", "limit": 8}}))
	if not porsche.contains("3623pt1") or not porsche.contains("a print of 3623"):
		_fail("search_parts \"porsche print\" does not offer 3623pt1 as a print of 3623:\n%s"
			% porsche)
	else:
		print("  ok    porsche print: %s" % porsche.get_slice("\n", 0).substr(0, 110))
	# One line a part, and short: a list of 15 a designer reads in full.
	var longest: int = 0
	for line: String in said.split("\n"):
		longest = maxi(longest, line.length())
	if longest > 260:
		_fail("a search_parts line is %d characters" % longest)
	var looks: String = str(await assistant._tool_answer({"name": "find_parts_like",
		"input": {"query": "control panel"}}))
	var printed_found: bool = false
	for id: String in ["2431pc1", "3039pcc", "3039pcl", "3069bp61", "3069bpa2",
			"3039pcd", "3039pcg", "3069bpce", "3069bpsa", "2431pzr", "3039pc2"]:
		printed_found = printed_found or looks.contains(id)
	if not printed_found or not looks.contains("print"):
		_fail("find_parts_like \"control panel\" names no printed control panel:\n%s" % looks)
	else:
		print("  ok    find_parts_like control panel names a printed one")
	assistant.queue_free()
	bin.free()

	print("")
	if _failures == 0:
		print("prints are found by what is printed on them")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## What a query found when only a part's number, name and category were
## read (the index before 2026-10-13), ranked as the search ranks.
static func _by_name_alone(library: PartLibrary, query: String) -> Array[PartLibrary.PartInfo]:
	var asked: String = PartLibrary.in_ldraw_words(query)
	var needles: PackedStringArray = asked.split(" ", false)
	var found: Array[PartLibrary.PartInfo] = []
	for id: String in library.ids():
		var info: PartLibrary.PartInfo = library.parts[id]
		# As the bin: not a part LDraw keeps only for old files that one made
		# now stands for (PartLibrary.superseded), 30069 beside 4070.
		if info.is_redirect() or not info.reachable or library.superseded(id):
			continue
		var text: String = ("%s %s %s" % [info.id, info.name, info.category]).to_lower()
		if Array(needles).all(func(needle: String) -> bool: return text.contains(needle)):
			found.append(info)
	PartsBin._sort_for(found, asked)
	return found


## Whether a plain part answers [param asked] as well as the first answer
## does: every word of it in its name, and the first's size. With the aliases
## of 4070 left out of the search (PartLibrary.superseded), "headlight brick"
## reaches u609, a 1 x 4 bell, and 3005, a plain 1 x 1, after 4070's prints,
## and rightly.
static func _as_good(info: PartLibrary.PartInfo, asked: String, first: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.to_lower()
	for word: String in asked.to_lower().split(" ", false):
		if not name.contains(word):
			return false
	return info.footprint_studs() == first.footprint_studs()


## Whether a part carries a print or a sticker, read from what LDraw says
## of it and nothing the search computes, so the old index is judged by
## the same rule as the new.
static func _decorated(info: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.to_lower()
	return name.contains("pattern") or name.contains("patt.") \
		or name.contains("sticker") or info.category.begins_with("Sticker")


static func _ids(found: Array) -> Array:
	var out: Array = []
	for info: Variant in found:
		out.append((info as PartLibrary.PartInfo).id)
	return out


static func _first_of(wanted: Array, found: Array) -> String:
	for id: Variant in found:
		if wanted.has(id):
			return str(id)
	return ""


static func _brief(ids: Array) -> String:
	return "nothing" if ids.is_empty() else str(ids.slice(0, 6))


func _fail(what: String) -> void:
	_failures += 1
	print("  FAIL  %s" % what)
