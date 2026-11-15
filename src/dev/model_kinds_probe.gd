## The kind the Share panel guesses for a model is what the model is, not
## what it carries: a car with its driver is a vehicle, a minifigure of a
## chef a figure.
##
##   godot --headless --path . --script src/dev/model_kinds_probe.gd [-- --sets=FILE]
##
## docs5 (2026-11-11): a car tagged "minifigure" was filed under Figures and
## characters. The guess read the name, the tags and the description as one
## text, and took the first kind any of it named in an order that put
## figures and art before vehicles, buildings, robots and living things, so
## anything that carried a figure, a sign or a portrait was one, and a house
## with a car a vehicle. Now the name's subject says what it is, the words
## before what it has, and figures and art come last. Here: a few
## names of each sort, and every model of the gallery's fixture
## (tools/web/gallery_seeds, 49 models whose kinds their makers chose), each
## guessed as the panel guesses it (ModelKinds.guess_from with its three
## boxes; on a build that has only ModelKinds.guess, the three as one text, as
## its panel did), against the kind chosen. --sets=FILE (a JSON list of
## {number, title, theme}, as bench/results' real sets) prints the guess for
## each title beside its theme, for the before and after; nothing is judged
## of those. Exits non-zero on a failure.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	print("── names, as the panel's Name box alone ──")
	for pair: Array in [
			["A sports car, and its driver", "vehicle"], ["A house with a minifigure family", "town"],
			["A pirate ship carrying a flag and a figurehead", "vehicle"],
			["A corner shop with a sign over the door", "town"], ["A robot holding a portrait", "robot"],
			["A minifigure of a chef", "figure"], ["A mosaic of a sunflower", "art"],
			["A bust of Beethoven", "figure"], ["A minifigure-scale racing car", "vehicle"],
			["Art deco cinema building", "town"], ["An orrery with nine planets", "mechanism"],
			["A barn owl", "nature"], ["Wizard's Tower", "castle"], ["A three-core heavy-lift rocket", "space"],
			["A small modular corner shop", "town"], ["A statue", "figure"], ["", ""]]:
		var guessed: String = _guessed(str(pair[0]), "", "")
		_check("\"%s\": %s (%s)" % [pair[0], pair[1], guessed], guessed == str(pair[1]))

	print("── a model's three boxes ──")
	for case: Array in [
			["Red racer", "car, minifigure", "", "vehicle"],
			["My build", "minifigures, house, garden", "", "town"],
			["Chef", "minifigure, kitchen", "", "figure"],
			["Lakeside", "camping", "A minifigure camping scene: a tent and a campfire.", "figure"],
			["", "", "", ""]]:
		var guessed: String = _guessed(str(case[0]), str(case[1]), str(case[2]))
		_check("name \"%s\", tags \"%s\", about \"%s\": %s (%s)" % [case[0], case[1], case[2], case[3],
			guessed], guessed == str(case[3]))

	print("── the gallery's fixture: the kind its maker chose ──")
	var agreed: int = 0
	var counted: int = 0
	var carried_wrong := PackedStringArray()
	for file: String in ["res://tools/web/gallery_seeds/seeds.json", "res://tools/web/gallery_seeds/ldraw_library.json"]:
		var seeds: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		for seed: Variant in seeds if seeds is Array else []:
			var said: Dictionary = seed
			var tags: String = ", ".join(PackedStringArray(said.get("tags", [])))
			var guessed: String = _guessed(str(said.get("name", "")), tags, str(said.get("about", "")))
			var chosen: String = str(said.get("kind", ""))
			counted += 1
			agreed += 1 if guessed == chosen else 0
			if guessed in ["figure", "art"] and guessed != chosen:
				carried_wrong.append(str(said.get("name", "")))
			print("    %s %-12s guessed %-12s %s" % ["  " if guessed == chosen else "≠ ", chosen, guessed,
				said.get("name", "")])
	print("    %d of %d as chosen" % [agreed, counted])
	_check("no model of the fixture filed as a figure or art its maker did not call one (%s)"
		% ", ".join(carried_wrong), carried_wrong.is_empty())
	# 32 when the three were one text, figures and art first (pre261 9cdb1937e);
	# 40 read by the name's subject. The nine left: a name that says nothing
	# a kind's words hold (Backhoe Grader, Wright Flyer, Mountain Hut, Island
	# Hopper), a treehouse in an oak (a tree), a moon rover (a vehicle; no
	# word of space), and a windmill, a mobile crane and the Robot Command
	# Center, each a machine by its name, which their makers filed under
	# Mechanisms, Vehicles and Space.
	_check("at least 40 of the 49 guessed as chosen (%d)" % agreed, counted == 49 and agreed >= 40)

	var sets: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sets="):
			sets = argument.substr(7)
	if not sets.is_empty():
		print("── real sets, by title: the guess beside the set's theme ──")
		var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sets))
		for one: Variant in listed if listed is Array else []:
			print("    %-10s %-12s %-40s %s" % [one["number"], _guessed(str(one["title"]), "", ""),
				one["title"], one["theme"]])

	print("\nmodel_kinds: %s" % ("%d FAILED" % _failures if _failures > 0 else "all passed"))
	quit(1 if _failures > 0 else 0)


## As the panel guesses: the three boxes, or on a build before guess_from the
## three as one text.
func _guessed(name: String, tags: String, about: String) -> String:
	var script: GDScript = load("res://src/net/model_kinds.gd")
	for method: Dictionary in script.get_script_method_list():
		if str(method["name"]) == "guess_from":
			return str(script.call("guess_from", name, tags, about))
	return str(script.call("guess", "%s %s %s" % [name, tags.replace(",", " "), about]))
