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
	quit(_rankings(library))


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
