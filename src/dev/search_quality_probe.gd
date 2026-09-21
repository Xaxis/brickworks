## How much of an answer is worth reading?
##
##   godot --headless --path . --script src/dev/search_quality_probe.gd
##
## The assistant picks every part it uses by searching, so what comes
## back decides what gets built. A query for a wedge plate came back
## with a 2 x 16 triple and then four printed variants of one 2 x 3 —
## Aquashark, a silver V, a red V, an MTron logo — which is one usable
## suggestion out of six.
##
## A printed variant is the same shape with a picture on it. It is
## never what somebody searching by shape wants, and there are
## thousands of them; the same goes for names LDraw marks as aliases of
## another part. Both crowd out the part they are a variant of.
extends SceneTree

## Queries a design actually makes, taken from the logs of real runs.
const ASKED: Array[String] = [
	"wedge plate 4 x 2", "slope 45 2 x 2", "plate 1 x 4", "brick 2 x 4",
	"tile 1 x 2", "curved slope 2 x 1", "window 1 x 2 x 2",
	"door frame", "round brick 1 x 1", "cone 2 x 2", "panel 1 x 4",
	"wheel", "windscreen", "arch 1 x 6", "bracket 1 x 2",
]

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	var shown: int = 0
	var wasted: int = 0
	for query: String in ASKED:
		var found: Array[PartLibrary.PartInfo] = library.search(query, 6)
		var junk: PackedStringArray = PackedStringArray()
		for info: PartLibrary.PartInfo in found:
			shown += 1
			if _is_a_variant(info):
				wasted += 1
				junk.append(info.id)
		if junk.is_empty():
			print("  ok    %-22s 6 distinct shapes" % query)
		else:
			print("  ——    %-22s %d of them variants: %s"
				% [query, junk.size(), ", ".join(junk)])

	var share: float = 100.0 * float(wasted) / float(maxi(shown, 1))
	print("")
	print("  %d of %d suggestions are printed or alias variants (%.0f%%)"
		% [wasted, shown, share])

	# A fifth is the line between a list worth reading and one that
	# mostly repeats itself. It will not reach zero: for a narrow query
	# like "wedge plate 4 x 2" only six parts match at all, four of them
	# prints of one shape, so ranking cannot help — there is nothing
	# else to put in front of them.
	if share > 20.0:
		_failures += 1
		print("")
		print("  FAIL  too much of the answer is the same shape twice")
	else:
		print("")
		print("search answers with distinct shapes")
	quit(1 if _failures else 0)


## A printed or renamed version of another part, rather than a shape of
## its own.
static func _is_a_variant(info: PartLibrary.PartInfo) -> bool:
	var name: String = info.name.strip_edges()
	if name.begins_with("=") or name.begins_with("~"):
		return true
	if name.to_lower().contains("pattern"):
		return true
	# LDraw suffixes a printed part with p and a number: 3001p01.
	var printed := RegEx.new()
	printed.compile("p[0-9]+[a-z]?$")
	return printed.search(info.id) != null
