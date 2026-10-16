## Print what search returns for a handful of queries.
##
## The assistant reported "search is returning a thin slice of the
## catalogue" and it was right, so this exists to check the claim
## directly rather than by inference from a design transcript.
##
##   godot --headless --path . --script src/dev/search_probe.gd
extends SceneTree


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
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
	quit(1 if failed > 0 else 0)


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
		var area: int = top.footprint_studs().x * top.footprint_studs().y
		# A wedge is not sold in 1 x 1, so "small" has to mean small for
		# the family rather than small in the absolute.
		var small: bool = area <= 16
		var intruders := PackedStringArray()
		for info: PartLibrary.PartInfo in found:
			if regressions.has(info.id):
				intruders.append(info.id)

		var ok: bool = plain and small and intruders.is_empty()
		if not ok:
			failures += 1
		print("  %s %-7s leads with %s (%s) — %s%s%s"
			% ["ok  " if ok else "FAIL", family, top.id, name,
				"plain" if plain else "NOT PLAIN",
				", %d studs" % area,
				"" if intruders.is_empty() else ", intruders: " + ", ".join(intruders)])

	print("")
	print("%d family(s) ranked badly" % failures if failures
		else "every family name leads with something plain and small")
	return 1 if failures else 0


## A part number typed brings that part first: a builder working from a
## parts list types numbers all day. "6157" listed a minifigure leg first,
## whose shop number 761579 has it in its keywords (the CAD task test,
## 2026-10-16). A retired or obsolete number may bring the part it became
## (3023 as 3023b, 61409 as 61409b), a letter on, never another number that
## merely begins the same.
## Every number the CAD task's three sets use is asked, so a new keyword or
## a ranking change that buries one fails here.
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
		var ok: bool = top == number or top == meant or (top.begins_with(number)
			and not top.substr(number.length(), 1).is_valid_int() and gone)
		if not ok:
			failures += 1
			print("  FAIL %-10s leads with %s" % [number, top])
	print("  %s %d part numbers typed, each leads with its own part%s" % [
		"ok  " if failures == 0 else "FAIL", asked,
		"" if failures == 0 else " but %d" % failures])
	return failures
