## Temporary: measure what search_parts actually returns for builder words.
extends SceneTree

func _initialize() -> void:
	var lib := PartLibrary.new()
	if not lib.load_catalogue():
		print("no catalogue"); quit(1); return
	print("catalogue: %d" % lib.parts.size())
	var queries: Array[String] = [
		"wheel", "window", "jumper plate", "brick 2x4", "brick 2 x 4",
		"round brick 1 x 1", "cone", "leaves", "plant", "tree",
		"leaf", "cheese slope", "slope 1 x 1", "headlight",
		"curved slope", "hinge plate", "clip", "bar", "door",
		"arch", "tile 1 x 2", "plate 1 x 2 with 1 stud", "dish",
		"cylinder", "battlement", "sail", "flag", "grille",
		"round plate 1 x 1", "tyre",
	]
	for q: String in queries:
		var found: Array[PartLibrary.PartInfo] = lib.search(q, 15)
		var out := PackedStringArray()
		for i: int in mini(5, found.size()):
			out.append("%s|%s" % [found[i].id, found[i].name.strip_edges()])
		print("%-26s (%d) %s" % [q, found.size(), " ;; ".join(out)])
	# how many packed parts exist at all on this root
	var packed: int = 0
	for id: String in lib.parts:
		if lib.parts[id].packed: packed += 1
	print("packed in this build: %d" % packed)
	quit(0)
