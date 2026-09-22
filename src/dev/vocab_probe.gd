## Does a search answer the words a builder would actually type?
##
##   godot --headless --path . --script src/dev/vocab_probe.gd
##
## LDraw's names and a builder's words are different vocabularies, and
## the search only ever knew one of them. A wedge plate is filed as
## "Wedge 4 x 6", so "wedge plate" found one part out of two hundred and
## it was a 2 x 16 triple with an axle hole. A cheese slope is "Slope
## Brick 31 1 x 1". A jumper is a plate "with 1 Centre Stud".
##
## An assistant takes the first result. It never discovers that the
## library has the part under another name — it builds with the wrong
## one, or decides there isn't one. A starship saucer is wedge plates,
## so the cost of the gap is the whole shape.
extends SceneTree

## What somebody types, something the right answer must contain, and —
## where the old wrong answer also contained it — a word it must not.
##
## "Wedge" alone was not enough: the part that used to answer "wedge
## plate" was "Wedge Plate 2 x 16 x 0.333 Triple with Axlehole", which
## contains it. A check that the broken behaviour also passes is not a
## check.
const WANTED: Array = [
	["wedge plate", "Wedge", "Axlehole"],
	["cheese slope", "Slope Brick 31"],
	["snot brick", "Stud"],
	["headlight brick", "Headlight"],
	["curved slope", "Curved"],
	["bracket", "Bracket"],
	["round plate", "Round"],
	["technic pin", "Technic"],
]

## Words that must not come back empty, whatever they return.
const MUST_ANSWER: Array = [
	"jumper plate", "dish", "clip", "bar", "hinge", "ball joint",
	"cone", "windscreen", "tile with groove", "plate with clip",
]

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("  the words a builder types")
	for pair: Array in WANTED:
		var hits: Array[PartLibrary.PartInfo] = library.search(pair[0], 5)
		if hits.is_empty():
			_fail("%s found nothing" % pair[0])
			continue
		var first: String = hits[0].name.strip_edges()
		if not first.contains(pair[1]):
			_fail("%s -> %s, wanted something with '%s' in it"
				% [pair[0], first, pair[1]])
			continue
		if pair.size() > 2 and first.contains(pair[2]):
			_fail("%s -> %s, which is the oddity, not the staple"
				% [pair[0], first])
			continue
		print("  ok    %-16s %s" % [pair[0], first.substr(0, 44)])

	print("")
	print("  and the rest at least answer")
	for word: String in MUST_ANSWER:
		if library.search(word, 3).is_empty():
			_fail("%s found nothing" % word)

	print("")
	print("  whole words, not the starts of longer ones")
	# "bar" used to be answered with Barrel 4.5 x 4.5, because "barrel"
	# begins with "bar".
	var bars: Array[PartLibrary.PartInfo] = library.search("bar", 5)
	if not bars.is_empty() and bars[0].name.strip_edges().to_lower() \
			.begins_with("barrel"):
		_fail("'bar' is still answered with a barrel")

	# Modulex is a different product on its own scale, filed in the same
	# library, and nobody building with LEGO wants one.
	for pair: Array in WANTED:
		var hits: Array[PartLibrary.PartInfo] = library.search(pair[0], 1)
		if not hits.is_empty() and hits[0].name.strip_edges().to_lower() \
				.begins_with("modulex"):
			_fail("%s is answered with a Modulex part" % pair[0])

	print("")
	print("  and says where a part's studs actually are")
	# The one line the model reads about a part used to say "N studs on
	# top" and count every stud whichever way it pointed. So 87087 —
	# "Brick 1 x 1 with Stud on 1 Side", whose side stud is the entire
	# reason the part exists — was described as having two studs on
	# top, and a bracket as having six. The feature that makes it the
	# part being looked for was the feature misstated.
	var assistant := Assistant.new()
	assistant.library = library
	get_root().add_child(assistant)
	for pair: Array in [
			["87087", true], ["4070", true], ["99207", true],
			["44728", true], ["3001", false], ["3024", false]]:
		var info: PartLibrary.PartInfo = library.parts.get(pair[0])
		if info == null:
			_fail("%s is not in the catalogue" % pair[0])
			continue
		var said: String = assistant._describe(info)
		var sideways: bool = said.contains("facing another way")
		if sideways != bool(pair[1]):
			_fail("%s: %s" % [pair[0], said])
			continue
		print("  ok    %s" % said.substr(0, 96))

	print("")
	if _failures == 0:
		print("the library answers in the words people use")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _fail(what: String) -> void:
	_failures += 1
	print("  FAIL  %s" % what)
