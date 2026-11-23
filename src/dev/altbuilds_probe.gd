## Alternate builds (altbuilds): what the site counts of a model against a
## real set is what the app's own Collection check says, part for part.
##
##   godot --headless --path . --script src/dev/altbuilds_probe.gd -- --pairs=PAIRS.json
##
## PAIRS.json is tools/web/altbuilds_probe.mjs's: (a model of the LDraw
## library, a set) pairs, and what api/_alts.js counted the set holds of the
## model, part and colour by part and colour, in the gallery's spelling (a
## mould's letter off). Here each model is read as the app opens it
## (Collection.needs_of_ldraw, the app's own LDraw reader), the set is put in
## a collection of its own (one copy, no spares, as Use what I own counts a
## set somebody owns), and the app's check is asked: Collection.coverage's
## owned and pieces must be the site's have and pieces, and Collection.allocate's
## have for each part and colour (its mouldings summed, as allocate lets one
## stand in for another) the site's for it.
##
## Reads only: the library's files, the sets' shards and the catalogue.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var asked: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pairs="):
			asked = arg.trim_prefix("--pairs=")
	if asked.is_empty() or not FileAccess.file_exists(asked):
		print("FAIL no --pairs= file (tools/web/altbuilds_probe.mjs writes it)")
		quit(1)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("FAIL no catalogue")
		quit(1)
		return
	var given: Variant = JSON.parse_string(FileAccess.get_file_as_string(asked))
	var pairs: Array = (given as Dictionary).get("pairs", []) if given is Dictionary else []
	if pairs.size() < 20:
		print("FAIL %d pairs in %s, not 20" % [pairs.size(), asked])
		quit(1)
		return
	var same: int = 0
	for pair: Variant in pairs:
		same += int(_check(pair as Dictionary, library))
	print("%s %d of %d pairs: the site's share is the app's Collection check, part for part"
		% ["ok" if same == pairs.size() else "FAIL", same, pairs.size()])
	quit(0 if _failures == 0 else 1)


func _check(pair: Dictionary, library: PartLibrary) -> bool:
	var file: String = str(pair["file"])
	var number: String = str(pair["set"])
	var needs: Dictionary = Collection.needs_of_ldraw(
		FileAccess.get_file_as_string("res://vendor/omr/files/" + file), library)
	var shard: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		SetInventories.ROOT + "%03d.json" % SetInventories.shard_of(number)))
	if not shard is Dictionary:
		return _fail("%s from %s: no shard" % [file, number])
	var mine := Collection.new()
	mine.sets = [{"set": number, "qty": 1}]
	var on_hand: Dictionary = mine.pool((shard as Dictionary).get("sets", {}), library)
	var cover: Dictionary = Collection.coverage(needs, on_hand)
	var shared: Dictionary = Collection.allocate(needs, on_hand)
	# The app's keys keep a mould's letter; the site's are its family's.
	var app: Dictionary = {}
	for key: String in needs:
		var family: String = "%s/%d" % [Collection.family_of(Collection.part_of(key)), Collection.colour_of(key)]
		var row: Array = app.get(family, [0, 0])
		app[family] = [int(row[0]) + int(needs[key]), int(row[1]) + int(shared["have"].get(key, 0))]
	var site: Dictionary = {}
	for lot: Variant in pair["lots"]:
		var one: Array = lot
		site["%s/%d" % [str(one[0]), int(one[1])]] = [int(one[2]), int(one[3])]
	var wrong: PackedStringArray = []
	for key: String in app:
		if not site.has(key) or int(site[key][0]) != int(app[key][0]) or int(site[key][1]) != int(app[key][1]):
			wrong.append("%s app %s site %s" % [key, str(app[key]), str(site.get(key, "none"))])
	for key: String in site:
		if not app.has(key):
			wrong.append("%s app none site %s" % [key, str(site[key])])
	var line: String = "%s from %s (%s): app %d of %d, site %d of %d" % [file, number, str(pair.get("why", "")),
		int(cover["owned"]), int(cover["pieces"]), int(pair["have"]), int(pair["pieces"])]
	if int(cover["owned"]) != int(pair["have"]) or int(cover["pieces"]) != int(pair["pieces"]) or not wrong.is_empty():
		return _fail("%s; %d parts and colours differ: %s" % [line, wrong.size(), "; ".join(wrong.slice(0, 6))])
	print("ok   " + line + ", %d parts and colours the same" % app.size())
	return true


func _fail(words: String) -> bool:
	_failures += 1
	print("FAIL " + words)
	return false
