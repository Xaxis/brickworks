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
	["wedge plate", "Wing"],
	["cheese slope", "Slope Brick 31"],
	["snot brick", "Stud"],
	["headlight brick", "Headlight"],
	["curved slope", "Curved"],
	["bracket", "Bracket"],
	["round plate", "Round"],
	["technic pin", "Technic"],
]

## Words whose answer has to be the right *thickness*, not merely a
## plausible name.
##
## This is where the old check went wrong. It asked that "wedge plate"
## answer with something containing "Wedge" — and 126 of the 203 parts
## named Wedge are three and a half plates tall, which is a wedge
## *brick*. So the check passed on the wrong family for as long as it
## existed, while the comment at the top of this file said the cost of
## the gap is the whole shape. A plate is one plate thick. Nothing else
## settles it.
const THICKNESS: Array = [
	["wedge plate", 1.5],    # 8 LDU of plate plus a 4 LDU stud
	["wedge plates", 1.5],
	["wedge brick", 3.5],    # 24 LDU of brick plus the stud
	["jumper", 1.5],
	["tile 2 x 2", 1.0],     # no stud on top at all
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
	print("  and it is the right thickness")
	for pair: Array in THICKNESS:
		var hits: Array[PartLibrary.PartInfo] = library.search(pair[0], 1)
		if hits.is_empty():
			_fail("%s found nothing" % pair[0])
			continue
		var plates: float = snappedf(hits[0].size.y / 8.0, 0.1)
		if absf(plates - float(pair[1])) > 0.2:
			_fail("%s -> %s is %.1f plates tall, wanted %.1f"
				% [pair[0], hits[0].name.strip_edges(), plates, pair[1]])
			continue
		print("  ok    %-16s %.1f plates   %s" % [pair[0], plates,
			hits[0].name.strip_edges().substr(0, 34)])

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
	# And which way, not merely "another way", because that was the
	# whole question: a bracket and a headlight brick both had studs
	# "facing another way", and finding out whether either does the job
	# in hand cost an attachment_points call. Sideways carries a wall;
	# underneath hangs something below a floor. They are different
	# parts for different problems.
	for pair: Array in [
			["87087", "1 facing sideways"],
			["4070", "1 facing sideways"],
			["99207", "4 facing sideways"],
			["44728", "4 facing sideways"],
			["3001", ""], ["3024", ""]]:
		var info: PartLibrary.PartInfo = library.parts.get(pair[0])
		if info == null:
			_fail("%s is not in the catalogue" % pair[0])
			continue
		var said: String = assistant._describe(info)
		var wanted: String = str(pair[1])
		if wanted.is_empty():
			if said.contains("facing") or said.contains("underneath"):
				_fail("%s has no sideways studs and says it has: %s"
					% [pair[0], said])
				continue
		elif not said.contains(wanted):
			_fail("%s should say '%s': %s" % [pair[0], wanted, said])
			continue
		print("  ok    %s" % said.substr(0, 96))
	# Nothing should still be settling for the old vague wording.
	for part: String in ["87087", "4070", "99207", "44728"]:
		var info: PartLibrary.PartInfo = library.parts.get(part)
		if info != null and assistant._describe(info).contains("another way"):
			_fail("%s still says only 'another way'" % part)

	print("")
	print("  every colour the rules name is a real one")
	# A prompt that names a colour code the palette does not have is a
	# hint that lies: the part is placed in whatever the renderer makes
	# of an unknown number, and nothing says so.
	var rules: String = assistant._system_prompt()
	var block: String = rules.substr(rules.find("COLOUR"))
	block = block.substr(0, block.find("AT AN ANGLE"))
	var checked: int = 0
	for word: String in block.replace("\n", " ").split(" ", false):
		if not word.is_valid_int():
			continue
		var code: int = word.to_int()
		# Years and the like are not colours; the palette stops well
		# below four digits.
		if code > 999:
			continue
		checked += 1
		# Asked of the table, not of color(), which never says no — it
		# hands back a magenta stand-in for an unknown code so a bad
		# colour is visible in the model rather than plausible. A check
		# written against it passes for every number there is, which is
		# how this one first reported an invented colour as real.
		if not library.colors.has(code):
			_fail("the rules name colour %d, which does not exist" % code)
	if checked < 20:
		_fail("only found %d colour codes in the rules" % checked)
	else:
		print("  ok    %d codes named, all of them real" % checked)

	print("")
	if _failures == 0:
		print("the library answers in the words people use")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _fail(what: String) -> void:
	_failures += 1
	print("  FAIL  %s" % what)
