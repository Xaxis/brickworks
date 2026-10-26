## The parts bin's Techniques found as a builder asks for them, in the real
## bin.
##
##   godot --headless --path . --script src/dev/technique_search_probe.gd
##
## walk256 (TQ1): "door" listed Columns With Capitals, Hinged Wing and
## Striped Awning before Door In A Wall, each only saying a door somewhere
## in what it is for, and every title read as a slug in capitals. The
## queries below were written down before the search was changed, each with
## the constructions a builder typing it means, and are not tuned to: each
## must put one of them in the first three rows the Techniques tab shows.
## Then every title and heading reads as words ("Door in a wall", "Windows
## and doors"), and so does its hover text.
extends SceneTree

## query -> the constructions it means, any of them.
const ASKED: Dictionary = {
	"door": ["door in a wall"],
	"window": ["window in a wall", "arched window", "window with shutters"],
	"roof": ["roof ridge", "raked screen and falling roof", "smooth top"],
	"hinge": ["leaning on a hinge", "hinged panels", "hinged wing"],
	"stairs": ["staircase"],
	"chimney": ["chimney"],
	"lamp": ["lamp post", "hanging lamp", "bedside lamp"],
	"tree": ["tree"],
	"fence": ["fence"],
	"column": ["stone column", "columns with capitals"],
	"tower": ["round tower", "wide round tower"],
	"bed": ["bed", "four-poster bed"],
	"arch": ["postern arch", "arched window"],
	"fire": ["campfire", "fireplace", "hearth"],
	"flowers": ["flower bed", "hedge with flowers"],
	"shutters": ["window with shutters"],
	"dome": ["smooth dome", "dome and cone cap"],
	"path": ["cobbled path"],
}
const TOP := 3

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 60:
		await process_frame
	var bin: PartsBin = main.get("_bin")
	bin.show_category(PartsBin.TECHNIQUES)
	print("\n  each query's constructions in the first %d rows" % TOP)
	var within: int = 0
	for query: String in ASKED:
		bin._run_search(query)
		var rows: PackedStringArray = _rows(bin)
		var at: int = -1
		for n: int in rows.size():
			if (ASKED[query] as Array).has(rows[n]):
				at = n
				break
		if at >= 0 and at < TOP:
			within += 1
		_check("%s: %s at row %s (first: %s)" % [query, rows[at] if at >= 0 else ASKED[query][0],
			str(at + 1) if at >= 0 else "none", ", ".join(rows.slice(0, TOP))], at >= 0 and at < TOP)
	print("     %d of %d queries have it in the first %d" % [within, ASKED.size(), TOP])

	print("\n  the titles read as words")
	bin._run_search("")
	var slugs := PackedStringArray()
	var titles: int = 0
	for child: Node in bin._grid.get_children():
		for text: String in _words_shown(child):
			titles += 1
			if _title_cased(text):
				slugs.append(text)
	_check("%d titles and headings, none in capitals word by word%s" % [titles,
		"" if slugs.is_empty() else " (%s)" % ", ".join(slugs.slice(0, 6))],
		titles > 50 and slugs.is_empty())
	var door: Button = _cell(bin, "door in a wall")
	_check("its hover text names it so: %s" % (door.tooltip_text.get_slice(":", 0) if door != null else "none"),
		door != null and door.tooltip_text.begins_with("Door in a wall:"))

	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	main.queue_free()
	await process_frame
	quit(1 if _failures else 0)


## The constructions the tab shows, top to bottom, by name.
static func _rows(bin: PartsBin) -> PackedStringArray:
	var out := PackedStringArray()
	for child: Node in bin._grid.get_children():
		if child.has_meta("technique"):
			out.append(str(child.get_meta("technique")))
	return out


static func _cell(bin: PartsBin, name: String) -> Button:
	for child: Node in bin._grid.get_children():
		if str(child.get_meta("technique", "")) == name:
			return child as Button
	return null


## A heading's words, or a row's title.
static func _words_shown(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	elif node.has_meta("technique"):
		for label: Node in node.find_children("*", "Label", true, false):
			out.append((label as Label).text)
			break
	return out


## Every word of more than three letters begun in a capital, as a slug
## title-cased is: "Door In A Wall", "Windows And Doors".
static func _title_cased(text: String) -> bool:
	var words: PackedStringArray = text.split(" ", false)
	if words.size() < 2:
		return false
	for word: String in words.slice(1):
		if word.length() <= 1:
			continue
		var first: String = word.substr(0, 1)
		if first != first.to_upper() or first == first.to_lower():
			return false
	return true
