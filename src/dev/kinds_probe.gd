## Does the app know how real sets of a kind are built?
##
##   godot --headless --path . --script src/dev/kinds_probe.gd
##
## Everything else this project tells a designer about what to reach for
## was written by me: tile a roof, curve a bonnet, use a bracket for a
## sign. Good advice and still only advice. A castle is not arches
## because I say so — it is arches because a hundred and seventy-five
## real castle sets use the arch door twenty-six times as often as sets
## at large do, and build in tan and pearl gold.
##
## The check that matters is the fourth one: two kinds have to give
## different answers. Measured by lift rather than count on purpose,
## because counted plainly every kind of set is a list of the same
## plates and the answer would be true and useless.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	get_root().add_child(assistant)
	await process_frame

	print("\nwhat the catalogue knows about kinds of set")
	_ok(library.kinds.size() > 200,
		"%d kinds of set" % library.kinds.size())
	_ok(library.kinds_measured_over > 10000,
		"measured over %d real models" % library.kinds_measured_over)

	print("\na castle, which is arches and tan")
	var castle: Array = library.kinds_for("a medieval castle")
	_ok(castle.size() == 1 and str(castle[0].get("kind", "")) == "castle",
		"the brief finds the castle kind")
	var arches: int = 0
	for entry: Variant in castle[0].get("parts", []):
		var name: String = _named(library, str((entry as Array)[0])).to_lower()
		if name.contains("arch") or name.contains("window"):
			arches += 1
	_ok(arches >= 3, "%d of its twelve parts are arches or windows" % arches)
	_ok(_has_colour(castle[0], 19) or _has_colour(castle[0], 28),
		"and it builds in tan")

	print("\na spaceship, which is not")
	var space: Array = library.kinds_for("spaceship")
	_ok(space.size() == 1 and str(space[0].get("kind", "")) == "space",
		"\"spaceship\" finds the space kind, which is the word sets use")
	# The check this all stands on. Counted plainly, every kind is the
	# same plates; measured by lift, a castle and a spaceship share
	# almost nothing.
	var shared: int = 0
	var in_castle: Dictionary = {}
	for entry: Variant in castle[0].get("parts", []):
		in_castle[str((entry as Array)[0])] = true
	for entry: Variant in space[0].get("parts", []):
		if in_castle.has(str((entry as Array)[0])):
			shared += 1
	_ok(shared <= 2,
		"a castle and a spaceship share %d of twelve parts" % shared)
	_ok(_has_colour(space[0], 15) or _has_colour(space[0], 7)
			or _has_colour(space[0], 71),
		"and a spaceship is white or grey")

	print("\nwhat it is built from, and what it carries")
	var pirate: Array = library.kinds_for("pirate")
	_ok(not (pirate[0].get("props", []) as Array).is_empty(),
		"a pirate set carries props")
	var swords: bool = false
	for entry: Variant in pirate[0].get("props", []):
		if _named(library, str((entry as Array)[0])).to_lower().contains("sword"):
			swords = true
	_ok(swords, "...and they are cutlasses")
	var weapons: int = 0
	for entry: Variant in pirate[0].get("parts", []):
		var info: PartLibrary.PartInfo = library.parts.get(
			str((entry as Array)[0]))
		if info != null and info.category.begins_with("Minifig"):
			weapons += 1
	_ok(weapons == 0,
		"while what it is built from holds no minifig accessory")

	print("\nand every part named can actually be placed")
	var bad: Array = []
	var duplo: Array = []
	var flat: int = 0
	for word: Variant in library.kinds:
		var kind: Dictionary = library.kinds[word]
		for entry: Variant in kind.get("parts", []):
			var pair: Array = entry
			var info: PartLibrary.PartInfo = library.parts.get(str(pair[0]))
			if info == null or info.is_redirect():
				bad.append(str(pair[0]))
			elif info.name.to_lower().begins_with("duplo"):
				duplo.append(str(pair[0]))
			if float(pair[1]) <= 1.0:
				flat += 1
	_ok(bad.is_empty(), "%d parts across every kind are unplaceable" % bad.size())
	# LDraw files Duplo train track under Train, so "train" came back
	# led by two Duplo tracks at seventy times the base rate.
	_ok(duplo.is_empty(), "%d are another product line's" % duplo.size())
	_ok(flat == 0,
		"%d are no more common in their kind than anywhere else" % flat)

	print("\nand it says so when it does not know")
	var answer: Dictionary = assistant._how_real_sets_build_this("a lighthouse")
	var said: String = str(answer.get("content", ""))
	_ok(said.contains("No kind of real set matches"),
		"a lighthouse is admitted to rather than guessed at")
	_ok(said.contains("not a verdict on the idea"),
		"...and the design is not told to build something else")

	print("\nand a word that is not a kind of thing does not outrank one")
	# The harm this does if it is wrong: a brief matches several kinds
	# and the most specific-looking goes first, so "a large castle" led
	# with "large" over 88 sets instead of castle over 175.
	#
	# It is a word list and not a measurement, and that was measured:
	# across all 367 kinds "play" topped out at 190 times the base rate
	# and "version" at 121 — above castle's 26 — while farm is 3.3, car
	# 4.2 and fire 4.5. A distinctiveness threshold deletes farm and car
	# and keeps play.
	# The subject is named first; a word naming a feature is not the
	# kind. "engine" is fire engines — ladders — and "pod" is a storage
	# tub, and both outranked "space" when the narrowest kind went first.
	var cruiser: Array = library.kinds_for("a large space cruiser with a "
		+ "bridge tower, two engine pods on angled pylons and landing legs")
	_ok(not cruiser.is_empty() and str(cruiser[0].get("kind")) == "space",
		"a space cruiser leads with space (%s)" % ", ".join(
			cruiser.map(func(k: Dictionary) -> String: return str(k.get("kind")))))
	_ok(not cruiser.any(func(k: Dictionary) -> bool: return k.get("kind") == "engine"),
		"...and is not handed fire-engine ladders for its engine pods")
	var big: Array = library.kinds_for("a large castle")
	_ok(not big.is_empty() and str(big[0].get("kind", "")) == "castle",
		"\"a large castle\" leads with castle (%s)"
			% ("nothing" if big.is_empty() else str(big[0].get("kind", ""))))
	for word: String in ["large", "small", "play", "version", "fun",
			"battle", "team", "advent"]:
		_ok(not library.kinds.has(word),
			"\"%s\" is not offered as a kind of thing" % word)
	# And the real ones are still there, including the three with the
	# least distinctive parts, which a threshold would have taken.
	for word: String in ["castle", "farm", "car", "fire", "tractor"]:
		_ok(library.kinds.has(word), "\"%s\" still is" % word)

	print("\nand it arrives with the brief, unasked")
	# The capability that can be got by without is the one that never
	# gets used. Measured twice on this project: sideways building was
	# reached for because a smooth sign face is impossible studs-up, and
	# wedge plates never were across three runs, because a staircase of
	# plates still satisfies "build a saucer".
	var opening: Array = assistant.opening_for(
		"build a medieval castle with a gatehouse")
	var sent: String = ""
	for block: Variant in opening:
		sent += str((block as Dictionary).get("text", ""))
	_ok(sent.contains("CASTLE"),
		"the castle data is in the first message of the run")
	_ok(sent.contains("40066"), "...naming the arch door")
	_ok(sent.contains("measured over every"),
		"...and saying it is measurement rather than advice")
	# A brief that names no kind must not drag an unrelated one in.
	var second: String = ""
	for block: Variant in assistant.opening_for("make it two studs taller"):
		second += str((block as Dictionary).get("text", ""))
	_ok(not second.contains("measured over"),
		"while a revision that names no kind gets nothing")

	print("\nand the model is told what it is looking at")
	var rules: String = assistant.guidance()
	_ok(rules.contains("how_real_sets_build_this"), "the prompt names the tool")
	_ok(rules.contains("tan and pearl gold"),
		"...with what it will get back")

	print("")
	if _failures == 0:
		print("a castle is arches because real castles are")
	else:
		print("%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


func _named(library: PartLibrary, part_id: String) -> String:
	var info: PartLibrary.PartInfo = library.parts.get(part_id)
	return "" if info == null else info.name


func _has_colour(kind: Dictionary, code: int) -> bool:
	for entry: Variant in kind.get("colors", []):
		if int((entry as Array)[0]) == code:
			return true
	return false


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
