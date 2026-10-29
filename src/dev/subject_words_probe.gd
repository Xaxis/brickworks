## A brief's words name a kind as whole words, never as letters inside
## another word.
##
##   godot --headless --path . --script src/dev/subject_words_probe.gd
##
## The owner's Claude session built an orrery and found the review "is
## classifying this orrery as an airplane. It keeps recommending tail planes
## and jet engines, likely because 'planet' or 'planetarium' matches
## 'plane'." It did: the kinds of real set were matched by any kind a word
## began with, and other vocabularies by letters anywhere in the brief. So
## the review is asked about an orrery and a planetarium, and then every
## vocabulary that reads a brief — the kinds of real set, the groups of
## real sets a model is measured against, the traits that pick its
## techniques, the tower words, the kinds of room, the techniques by name —
## is run against near misses: words that hold a word of it inside them.
## Each may match a near miss only where the near miss is itself one of its
## words.
extends SceneTree

## Each with the words of a vocabulary it holds and is not.
const NEAR_MISSES: Dictionary = {
	"planet": "plane", "planets": "plane", "planetarium": "plane, planet",
	"crater": "rat, crate", "pirate": "rat", "bowl": "owl", "knowledge": "owl",
	"howl": "owl", "growl": "owl", "cathedral": "cat", "category": "cat",
	"scatter": "cat", "carriage": "car", "scar": "car", "scarlet": "car",
	"carpet": "car, pet", "cartoon": "cart, car", "carnival": "car", "cargo": "car",
	"worship": "ship", "hardship": "ship", "friendship": "ship", "shipment": "ship",
	"giant": "ant", "elephant": "ant", "restaurant": "ant", "antenna": "ant",
	"landscape": "ape", "beetle": "bee", "trainer": "train", "abuse": "bus",
	"bust": "bus", "busy": "bus", "starling": "star", "standard": "stand",
	"basement": "base", "liner": "line", "lineage": "line", "engineer": "engine",
	"inspired": "spire", "shopkeeper": "keep, shop", "beekeeper": "keep, bee",
	"storey": "store", "dinner": "inn", "inner": "inn", "shelf": "elf",
	"electricity": "city", "gatehouse": "house", "firework": "fire",
	"fireplace": "fire", "towel": "tow", "batter": "bat", "petal": "pet",
	"dogma": "dog", "hotel": "hot", "icicle": "ice", "bedrock": "bed",
	"spittoon": "pit", "stopwatch": "top", "tiered": "tie", "season": "sea",
}

## And what must still be found: the word, the kind of real set.
const STILL: Array = [["castles", "castle"], ["a spaceship", "space"],
	["fire engines", "fire"], ["two buses", "bus"], ["pirates", "pirate"],
	["an X-wing", "wing"], ["the police station", "police"], ["a farmhouse", "farm"]]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	print("\nthe review, asked about an orrery")
	for asked: String in ["an orrery of the solar system", "a planetarium",
			"a brass orrery, the planets on arms round the sun"]:
		var kinds: Array = library.kinds_for(asked).map(
			func(kind: Dictionary) -> String: return str(kind.get("kind", "")))
		_ok(not kinds.has("plane"), "\"%s\" is no kind of aeroplane (%s)"
			% [asked, ", ".join(PackedStringArray(kinds)) if not kinds.is_empty() else "no kind"])
		var answer: String = str(assistant._how_real_sets_build_this(asked)["content"])
		_ok(not answer.contains("PLANE"), "...how_real_sets_build_this hands it no plane set's parts")
	var opening: String = ""
	for block: Variant in assistant.opening_for("Build an orrery of the solar system, "
			+ "its planets on arms round the sun"):
		opening += str((block as Dictionary).get("text", ""))
	_ok(not opening.contains("PLANE"), "the brief's first message brings no plane set with it")
	var bricks: Array = []
	for n: int in 4:
		bricks.append({"part": "3001", "color": 70, "x": 0, "y": 3 * n, "z": 0, "rot": 0})
	await assistant.use_tool("submit_design", {"name": "Orrery",
		"description": "an orrery of the solar system, the planets on arms round the sun",
		"bricks": bricks, "assemblies": [{"name": "base", "where": {"x_from": -1, "x_to": 5,
			"y_from": -1, "y_to": 13, "z_from": -1, "z_to": 3}}]})
	var whole: String = await assistant.review("")
	var close: String = await assistant.review("base")
	_ok(not whole.contains("plane") and not close.contains("plane"),
		"review_model, whole and close up, says nothing of planes")
	var about: String = "Orrery. an orrery of the solar system, the planets on arms"
	var traits: Dictionary = Style.traits_of(about)
	_ok(traits.has("mechanism"), "an orrery is a mechanism (%s)" % ", ".join(
		PackedStringArray(traits.keys())))
	var calls: String = "; ".join(Style.calls_for(traits, {}, {}, about))
	_ok(calls.contains("a gear train from one crank") and calls.contains("counterweight"),
		"...told how one is built: %s" % calls.left(90))

	print("\nevery vocabulary against %d near misses" % NEAR_MISSES.size())
	var vocabularies: Dictionary = {
		# Less what a word is a kind of (SubjectWords.IS_A, each "is_a"): a
		# cathedral read as a building is what it is, not a cat inside it.
		"kinds of real set": func(word: String) -> PackedStringArray:
			return PackedStringArray(library.kinds_for(word).filter(
				func(kind: Dictionary) -> bool: return not kind.has("is_a")).map(
				func(kind: Dictionary) -> String: return str(kind.get("kind", "")))),
		"traits": func(word: String) -> PackedStringArray:
			return _vocabulary_named(word, Style.TRAITS),
		"groups of real sets": func(word: String) -> PackedStringArray:
			var group: String = Style.group_for(word)
			return PackedStringArray() if group == Style.group_for("") else PackedStringArray([group]),
		"tower words": func(word: String) -> PackedStringArray:
			return PackedStringArray(["tower"]) if Style.is_tower(word) else PackedStringArray(),
		"kinds of room": func(word: String) -> PackedStringArray:
			var kind: String = Rooms.kind_of(word)
			return PackedStringArray() if kind.is_empty() else PackedStringArray([kind]),
	}
	# What each vocabulary may match a near miss as: its own words.
	var own: Dictionary = {
		"kinds of real set": library.kinds.keys(),
		"traits": _words_of(Style.TRAITS),
		"groups of real sets": _words_of_pairs(Style.GROUP_WORDS),
		"tower words": Style.TOWER_WORDS,
		"kinds of room": _room_words(),
	}
	for name: String in vocabularies:
		var wrong := PackedStringArray()
		for word: String in NEAR_MISSES:
			var found: PackedStringArray = (vocabularies[name] as Callable).call(word)
			if found.is_empty():
				continue
			var legit: bool = false
			for form: String in SubjectWords.forms(word):
				legit = legit or (own[name] as Array).has(form)
			if not legit:
				wrong.append("%s as %s" % [word, ", ".join(found)])
		_ok(wrong.is_empty(), "%s: %s" % [name, "no near miss matched" if wrong.is_empty()
			else "matched " + "; ".join(wrong)])
	var named_ear: String = str(Techniques.named("ear").get("name", ""))
	_ok(named_ear != "hearth", "a technique asked for as \"ear\" is not the hearth (%s)"
		% (named_ear if not named_ear.is_empty() else "none"))
	_ok(str(Techniques.named("ant").get("name", "")) != "planter",
		"...nor \"ant\" the planter")

	# A brief is read once for what each of its words names (perf331), and a
	# vocabulary looked up in that: it must be what kind_of_word finds each
	# word to be, word for word, or the two have drifted apart.
	print("\na word names alone what kind_of_word finds it to be")
	var briefs: Array = NEAR_MISSES.keys() + STILL.map(func(pair: Array) -> String: return pair[0])
	briefs.append_array(["spacecraft spaceports firetrucks speedboats seaplanes houseboats",
		"firemen policemen snowmobiles helicopters motorbikes racecars", "the bodies of castles"])
	var wanted: Dictionary = {}
	for word: Variant in _words_of(Style.TRAITS) + library.kinds.keys() + SubjectWords.COMPOUND_ENDS:
		for one: String in SubjectWords.of(str(word)):
			wanted[one] = true
	var drifted := PackedStringArray()
	var asked: int = 0
	for brief: Variant in briefs:
		for word: String in SubjectWords.of(str(brief)):
			var alone: Dictionary = SubjectWords.named_alone(word)
			for one: String in wanted.keys() + alone.keys():
				asked += 1
				if alone.has(one) == SubjectWords.kind_of_word(word, {one: true}).is_empty():
					drifted.append("%s/%s" % [word, one])
	_ok(drifted.is_empty() and asked > 10000, "%d words of briefs against a vocabulary of one: %s"
		% [asked, "the same" if drifted.is_empty() else "differ " + ", ".join(drifted.slice(0, 8))])

	print("\nand what a brief means is still found")
	for pair: Array in STILL:
		var kinds: Array = library.kinds_for(str(pair[0])).map(
			func(kind: Dictionary) -> String: return str(kind.get("kind", "")))
		_ok(kinds.has(pair[1]), "\"%s\" finds the %s kind (%s)" % [pair[0], pair[1],
			", ".join(PackedStringArray(kinds))])
	_ok(Style.group_for("a spacecraft") == "space", "a spacecraft is measured with space sets")
	_ok(Style.is_tower("the tower of Orthanc") and Style.is_tower("Barad-dûr"),
		"a tower and Barad-dûr are towers")
	_ok(Style.traits_of("two buses and a steam locomotive").has("vehicle")
		and Style.traits_of("a steam locomotive").has("round"),
		"buses are vehicles, a locomotive round")
	_ok(Rooms.kind_of("the smithy") == "forge" and Rooms.kind_of("wine cellar") == "dungeon"
		and Rooms.kind_of("the libraries") == "library", "rooms by their words and plurals")

	print("")
	if _failures > 0:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	else:
		print("an orrery is not an aeroplane")
	quit(1 if _failures > 0 else 0)


## The words of [param table] (name -> its words) a word names, as name.
static func _vocabulary_named(word: String, table: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for name: String in table:
		if not SubjectWords.first_named(word, table[name]).is_empty():
			out.append(name)
	return out


static func _words_of(table: Dictionary) -> Array:
	var out: Array = []
	for name: String in table:
		out.append_array(table[name])
	return out


static func _room_words() -> Array:
	return _words_of_pairs(Rooms.SAID)


## The words of [[words], what they name] pairs.
static func _words_of_pairs(pairs: Array) -> Array:
	var out: Array = []
	for pair: Array in pairs:
		out.append_array(pair[0])
	return out


func _ok(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		_failures += 1
