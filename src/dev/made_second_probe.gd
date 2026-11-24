## moulds4, the case before it: does one person's second made part, of an id
## the first has, write over the first in their own library? Runs on the live
## app (pre261) and on moulds4 alike, only through what both have.
##   - two cuts of a 3001 that pre261 named alike (bw-3001-cc79, mouldreview3);
##   - two prints of a 3068b, one picture, two titles whose 24-bit tag (pre261's
##     PartPrints.tag_of) is the same, found here by trying titles;
##   - two moulds of 3901 of one title whose 24-bit shape tag (pre261's
##     Mould.id_for) is the same, found by moving one corner.
## Each made one after the other and kept; then the first's kept file, and
## both read back by a library that starts again from the kept folder.
## RESULT / FINDING lines. Headless.
##   godot --headless --path . --script src/dev/made_second_probe.gd
extends SceneTree

const PROBE_DIR := "user://made_second/"

var _library: PartLibrary
var _findings: int = 0


func _initialize() -> void:
	_run()


func _say(what: String) -> void:
	print("RESULT  " + what)


func _check(passed: bool, what: String) -> void:
	if passed:
		_say(what)
	else:
		_findings += 1
		print("FINDING " + what)


func _run() -> void:
	await process_frame
	for name: String in DirAccess.get_files_at(PROBE_DIR):
		DirAccess.remove_absolute(PROBE_DIR + name)
	DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	CustomParts.dir = PROBE_DIR
	_library = PartLibrary.new()
	_library.load_catalogue()
	var firsts: Array = []
	firsts.append_array(_cuts())
	firsts.append_array(_prints())
	firsts.append_array(_moulds())
	print("\nA LIBRARY STARTED AGAIN FROM THE KEPT FOLDER")
	var again := PartLibrary.new()
	again.load_catalogue()
	var loaded: int = CustomParts.load_all(again)
	for first: Array in firsts:
		var id: String = first[0]
		_check(again.custom_source(id) == str(first[1]),
			"%s: the first made, read back: %s" % [id, "as made" if again.custom_source(id) == str(first[1])
				else "OTHER TEXT (%d chars, made %d)" % [again.custom_source(id).length(), str(first[1]).length()]])
	_say("%d kept parts read back" % loaded)
	print("\nMADE SECOND DONE: %d finding line%s" % [_findings, "" if _findings == 1 else "s"])
	quit(0)


## Made one after the other: [first id, its text as made], after saying what
## the second did to it.
func _second(kind: String, first: Dictionary, second: Dictionary, first_text: String) -> Array:
	var first_id: String = _id_of(first)
	var second_id: String = _id_of(second)
	var kept: String = FileAccess.get_file_as_string(PROBE_DIR + first_id + ".dat")
	_check(kept == first_text and _library.custom_source(first_id) == first_text,
		"%s: first %s, second %s; the first's kept file after the second: %s; in the library: %s" % [kind,
			first_id, second_id, "as made" if kept == first_text else "OVERWRITTEN",
			"as made" if _library.custom_source(first_id) == first_text else "OVERWRITTEN"])
	return [first_id, first_text]


## A maker's answer's id: {"id"}, or a print's {"ids"} first.
static func _id_of(made: Dictionary) -> String:
	if made.has("ids"):
		return str(made["ids"][0]) if not (made["ids"] as Array).is_empty() else ""
	return str(made.get("id", ""))


func _edit(cut: Array) -> PartEditor.Edit:
	var edit := PartEditor.Edit.new()
	edit.from = "3001"
	edit.cut = PackedInt32Array(cut)
	return edit


func _cuts() -> Array:
	print("\nTWO CUTS OF 3001 THAT PRE261 NAMED ALIKE")
	var first: Dictionary = CustomParts.make_modified(_library, _edit([0, 0, 1, 2, 0, 2]))
	var text: String = _library.custom_source(str(first["id"]))
	var second: Dictionary = CustomParts.make_modified(_library, _edit([0, 0, 3, 2, 0, 3]))
	return [_second("cuts", first, second, text)]


func _prints() -> Array:
	print("\nTWO PRINTS OF 3068B WHOSE 24-BIT TAGS ARE ONE")
	var tile: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3068b")
	var drawn: Dictionary = {}
	var parts: Array = ["3068b"]
	for area: PartPrints.Area in tile:
		var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
		PrintPaint.disc(picture, Vector2(area.size) * 0.5, 20.0, Color.RED)
		drawn[area.key] = picture
		parts.append_array([area.key, PartPrints.finished(picture, area).save_png_to_buffer()])
	var seen: Dictionary = {}
	var pair: Array = []
	for n: int in 40000:
		var title: String = "Sign %d" % n
		var things: Array = ["3068b", title]
		things.append_array(parts.slice(1))
		var tag: String = _old_tag(things)
		if seen.has(tag):
			pair = [seen[tag], title, tag]
			break
		seen[tag] = title
	if pair.is_empty():
		_say("no two titles of one 24-bit tag in 40,000")
		return []
	_say("titles \"%s\" and \"%s\" have one 24-bit tag, %s" % pair)
	var first: Dictionary = PartPrints.make(_library, "3068b", tile, drawn, pair[0])
	var text: String = _library.custom_source(_id_of(first))
	var second: Dictionary = PartPrints.make(_library, "3068b", tile, drawn, pair[1])
	return [_second("prints", first, second, text)]


func _moulds() -> Array:
	print("\nTWO MOULDS OF 3901 WHOSE 24-BIT SHAPE TAGS ARE ONE")
	var mould: Mould = Mould.of_part(_library, "3901", "headwear")
	if mould == null:
		_say("no mould of 3901")
		return []
	var start: PackedVector3Array = mould.positions.duplicate()
	var seen: Dictionary = {}
	var pair: Array = []
	for n: int in 40000:
		var moved: PackedVector3Array = start.duplicate()
		moved[0] = start[0] + Vector3(float(n % 200) / 64.0, float(n / 200) / 64.0, 0.0)
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_MD5)
		hashing.update(mould.base.to_utf8_buffer())
		hashing.update(moved.to_byte_array())
		hashing.update(mould.triangles.to_byte_array())
		var tag: String = hashing.finish().hex_encode().left(6)
		if seen.has(tag):
			pair = [seen[tag], n, tag]
			break
		seen[tag] = n
	if pair.is_empty():
		_say("no two shapes of one 24-bit tag in 40,000")
		return []
	_say("corner 0 moved by steps %d and %d: one 24-bit tag, %s" % pair)
	var n_first: int = int(pair[0])
	var n_second: int = int(pair[1])
	mould.positions = start.duplicate()
	mould.positions[0] = start[0] + Vector3(float(n_first % 200) / 64.0, float(n_first / 200) / 64.0, 0.0)
	var first: Dictionary = mould.make(_library, "Quiff")
	var text: String = _library.custom_source(str(first["id"]))
	mould.positions = start.duplicate()
	mould.positions[0] = start[0] + Vector3(float(n_second % 200) / 64.0, float(n_second / 200) / 64.0, 0.0)
	var second: Dictionary = mould.make(_library, "Quiff")
	return [_second("moulds", first, second, text)]


## pre261's PartPrints.tag_of: six hex digits of an MD5 of the things run together.
static func _old_tag(things: Array) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_MD5)
	for thing: Variant in things:
		if thing is PackedByteArray:
			hashing.update(thing)
		else:
			hashing.update(str(thing).to_utf8_buffer())
	return hashing.finish().hex_encode().left(6)
