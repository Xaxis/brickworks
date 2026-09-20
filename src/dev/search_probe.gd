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
	quit()
