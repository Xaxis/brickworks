## Print what search returns for a handful of queries.
##
## The assistant reported "search is returning a thin slice of the
## catalogue" and it was right, so this exists to check the claim
## directly rather than by inference from a design transcript.
##
##   godot --headless --path . --script src/dev/search_probe.gd
##
## After `--`, `--catalogue=PATH` reads that catalogue instead of the one
## in assets/generated: a corrected copy is checked before it is swapped in.
extends SceneTree


func _initialize() -> void:
	var library := PartLibrary.new()
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--catalogue="):
			path = arg.trim_prefix("--catalogue=")
	if not library.load_catalogue(path):
		print("no catalogue")
		quit(1)
		return

	print("catalogue: %d parts" % library.parts.size())
	var queries: Array[String] = [
		"slope curved", "brick 2 x 4", "plate 1 x 2", "slope",
		"round brick 2 x 2", "tile 1 x 2", "cone", "wheel", "window",
	]
	for query: String in queries:
		var found: Array[PartLibrary.PartInfo] = library.search(query, 6)
		var names := PackedStringArray()
		for info: PartLibrary.PartInfo in found:
			names.append("%s(%s)" % [info.id, info.name.strip_edges().substr(0, 26)])
		print("  %-20s -> %s" % [query, ", ".join(names)])

	print("")
	var failed: int = _rankings(library)
	failed += _numbers(library)
	failed += _only_numbered(library)
	failed += _names(library)
	quit(1 if failed > 0 else 0)


## Names and keywords as LDraw writes them, and found as typed. The
## library read as Latin-1 put "ThÃ©oden" and "90Â°" in 54 names and
## 299 keywords (2026-10-20): typing "Théoden" or "90°" found nothing.
## UTF-8 read as Latin-1 leaves a lead byte, Ã or Â, before a byte the
## spec reserves for what follows one.
static var MISREAD := RegEx.create_from_string("[\\x{c2}-\\x{f4}][\\x{80}-\\x{bf}]")


static func _names(library: PartLibrary) -> int:
	var misread := PackedStringArray()
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		for said: String in [info.name] + Array(info.keywords):
			if MISREAD.search(said) != null:
				misread.append("%s %s" % [id, said])
	var failures: int = 0
	if not misread.is_empty():
		failures += 1
		print("  FAIL %d names and keywords misread, e.g. %s" % [misread.size(),
			", ".join(misread.slice(0, 3))])
	# What each query must find, and a word of the name it is found by.
	var wanted: Dictionary = {"Théoden": "10054p02", "90°": "7334", "Å": "3005pwc",
		"Éomer": "10054p01", "忍者": "57895p01"}
	for query: String in wanted:
		var ids := PackedStringArray()
		for info: PartLibrary.PartInfo in library.search(query, 200):
			ids.append(info.id)
		var ok: bool = ids.has(wanted[query])
		failures += 0 if ok else 1
		print("  %s %-8s finds %s%s" % ["ok  " if ok else "FAIL", query, wanted[query],
			"" if ok else " (%d found: %s)" % [ids.size(), ", ".join(ids.slice(0, 4))]])
	if misread.is_empty():
		print("  ok   no name or keyword of %d parts misread" % library.parts.size())
	return failures


## What a bare family name should lead with.
##
## Naming four "correct" parts per family and demanding they appear is
## how this was written first, and it was the wrong test twice over: the
## list had redirects and a slope filed under wedges in it, and where the
## list was right it still encoded one person's opinion of which 2 x 1
## slope matters most. Tests that assert an opinion get edited until they
## agree with the code.
##
## So it checks the property instead. Typing a family name should lead
## with a plain, small member of that family — and specifically must not
## lead with the parts that prompted this: Slope 5 x 8 x 0.667 and the
## 10 x 2 x 2 curved slopes, which is what "slope" used to return.
## A family, a size, and at most the one qualifier that names a standard
## form rather than a variant.
static var PLAIN_NAME := RegEx.create_from_string(
	"^[A-Za-z]+( [A-Za-z]+)? ?\\d*\\s*\\d+ x \\d+( x [\\d.]+)?( with Groove)?$")


static func _rankings(library: PartLibrary) -> int:
	var families: PackedStringArray = PackedStringArray([
		"brick", "plate", "tile", "slope", "wedge", "panel"])
	## Parts that were at the top and had no business being there.
	var regressions: PackedStringArray = PackedStringArray([
		"75539", "77180", "77182"])

	var failures: int = 0
	for family: String in families:
		var found: Array[PartLibrary.PartInfo] = library.search(family, 8)
		if found.is_empty():
			print("  FAIL %-7s no results at all" % family)
			failures += 1
			continue

		var top: PartLibrary.PartInfo = found[0]
		var name: String = top.name.strip_edges()
		while name.contains("  "):
			name = name.replace("  ", " ")

		# Read off the name, not off the score. Asking the scorer whether
		# its own answer is plain proves nothing, and the score carries
		# family bonuses and a height penalty that have no bearing on it.
		var plain: bool = PLAIN_NAME.search(name) != null
		# Or a part of the family sets use most. A plain name stood in for a
		# staple until search knew how much sets use a part (search242): the
		# curved 4 x 4 wedge on most cars (45677), the 1 x 2 x 1 panel moulded
		# with rounded corners since 2011 (4865b).
		var staple: bool = _most_used(library, family).has(top.id)
		var area: int = top.footprint_studs().x * top.footprint_studs().y
		# A wedge is not sold in 1 x 1, so "small" has to mean small for
		# the family rather than small in the absolute.
		var small: bool = area <= 16
		var intruders := PackedStringArray()
		for info: PartLibrary.PartInfo in found:
			if regressions.has(info.id):
				intruders.append(info.id)

		var ok: bool = (plain or staple) and small and intruders.is_empty()
		if not ok:
			failures += 1
		print("  %s %-7s leads with %s (%s) — %s%s%s"
			% ["ok  " if ok else "FAIL", family, top.id, name,
				"plain" if plain else ("among the most used" if staple else "NOT PLAIN"),
				", %d studs" % area,
				"" if intruders.is_empty() else ", intruders: " + ", ".join(intruders)])

	print("")
	print("%d family(s) ranked badly" % failures if failures
		else "every family name leads with something plain and small")
	return 1 if failures else 0


## The three parts filed under [param family] that sets use most.
static func _most_used(library: PartLibrary, family: String) -> PackedStringArray:
	var filed: Array[PartLibrary.PartInfo] = []
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if info.category.to_lower() == family and not info.is_redirect():
			filed.append(info)
	filed.sort_custom(func(a: PartLibrary.PartInfo, b: PartLibrary.PartInfo) -> bool:
		return a.commonness() > b.commonness())
	var out := PackedStringArray()
	for info: PartLibrary.PartInfo in filed.slice(0, 3):
		out.append(info.id)
	return out


## A part number typed brings that part first: a builder working from a
## parts list types numbers all day. "6157" listed a minifigure leg first,
## whose shop number 761579 has it in its keywords (the CAD task test,
## 2026-10-16). A retired or obsolete number may bring the part it became
## (3023 as 3023b, 61409 as 61409b), a letter on, never another number that
## merely begins the same.
## Every number the CAD task's three sets use is asked, so a new keyword or
## a ranking change that buries one fails here.
## A part number typed finds the parts it numbers and nothing that merely
## has the digits: walk256 (S3) typed 3648 and was shown three torsos of set
## 3648's ("Set 3648" in their keywords), and 3001 two torsos printed with
## a 3001 brick. Each answer is the number's own part, one it numbers (3648a,
## 3001p01), or the one it stands for (PartLibrary.resolve), in the bin's
## search (every word) and the assistant's.
static func _only_numbered(library: PartLibrary) -> int:
	var failures: int = 0
	for number: String in ["3648", "3001", "3626", "973", "3062", "3023", "4070", "60596",
			"3005", "3010", "3039", "2357"]:
		var stray := PackedStringArray()
		var first: String = ""
		for every_word: bool in [true, false]:
			# All of them, as the bin asks (PartsBin._find): for 3626 the parts
			# that only say it in their keywords come after sixty of its heads.
			var found: Array[PartLibrary.PartInfo] = library.search(number, -1, every_word)
			if every_word and not found.is_empty():
				first = found[0].id
			for info: PartLibrary.PartInfo in found:
				var own: bool = info.id.begins_with(number) \
					and not info.id.substr(number.length(), 1).is_valid_int()
				if not own and info.id != library.resolve(number) \
						and info.id != library.current(number) and not stray.has(info.id):
					stray.append(info.id)
		var ok: bool = stray.is_empty() and first.begins_with(number)
		failures += 0 if ok else 1
		print("  %s %-6s lists its own parts only, %s first%s" % ["ok  " if ok else "FAIL", number,
			first, "" if stray.is_empty() else " (and %s)" % ", ".join(stray.slice(0, 5))])
	return failures


static func _numbers(library: PartLibrary) -> int:
	var sets: Array[String] = ["5762-1_Plane.mpd", "8643-1_Combination-with-8644.mpd",
		"8841-1_Balance.mpd"]
	var numbers: Dictionary = {"6157": true, "3001": true, "3023": true, "4081b": true}
	for name: String in sets:
		var text: String = FileAccess.get_file_as_string("res://vendor/omr/files/" + name)
		for line: String in text.split("\n"):
			var words: PackedStringArray = line.strip_edges().split(" ", false)
			if words.size() >= 15 and words[0] == "1":
				var id: String = " ".join(words.slice(14)).to_lower().trim_suffix(".dat")
				if not id.ends_with(".ldr") and not id.ends_with(".mpd"):
					numbers[id] = true
	var failures: int = 0
	var asked: int = 0
	for number: String in numbers:
		if not library.parts.has(number):
			continue
		asked += 1
		var found: Array[PartLibrary.PartInfo] = library.search(number, 3)
		var top: String = found[0].id if not found.is_empty() else "nothing"
		var meant: String = library.resolve(number)
		# Retired, or kept as an obsolete stub ("~Slope Brick 18 ... (Obsolete)",
		# 61409): the part it became, a letter on, is what is meant.
		var gone: bool = library.parts[number].is_redirect() \
			or library.parts[number].name.begins_with("~")
		# One LDraw keeps only for old files brings the part made now in its
		# shape (PartLibrary.current): 50746, an alias, its slope.
		var ok: bool = top == number or top == meant or top == library.current(number) \
			or (top.begins_with(number)
			and not top.substr(number.length(), 1).is_valid_int() and gone)
		if not ok:
			failures += 1
			print("  FAIL %-10s leads with %s" % [number, top])
	print("  %s %d part numbers typed, each leads with its own part%s" % [
		"ok  " if failures == 0 else "FAIL", asked,
		"" if failures == 0 else " but %d" % failures])
	return failures
