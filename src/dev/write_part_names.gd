## Each part's and colour's name in German, French and Spanish, as the app
## says them, written for the site's parts lists (api/_parts.js partNames),
## so a set's page and the app's parts bin name a part alike: the bin's own
## words for it (PartsBin.tile_name through PartWords.part, as
## PartsBin.said_name says a tile), and a colour's as the palette's
## (PartWords.colour), and a category's as the bin's chips have it, from
## the language's locale/<code>.po. Only the names the glossary says whole,
## and the categories the po has, are written; the site shows any other as
## LDraw writes it. Written beside each web build by tools/export.sh (DIR
## is <build>/part_names), which tools/deploy.sh puts beside /api/share:
##
##   godot --headless --path . --script src/dev/write_part_names.gd -- --out=DIR
##
## Each language's is part_names_<code>.json in DIR, {format, lang, parts:
## {id: name}, colours: {code: name}, categories: {name: name}}. Never into
## the shared assets/generated, which every worktree reads.
extends SceneTree


func _initialize() -> void:
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	if out.is_empty():
		printerr("part_names: say where: -- --out=DIR")
		quit(2)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue(PartLibrary.FULL_ROOT + "catalogue.json"):
		printerr("part_names: no catalogue at %scatalogue.json (tools/build_meshes.py)" % PartLibrary.FULL_ROOT)
		quit(1)
		return
	for code: String in PartWords.LANGUAGES:
		var named: Dictionary = names(library, code)
		var path: String = out.path_join("part_names_%s.json" % code)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("part_names: cannot write %s" % path)
			quit(1)
			return
		file.store_string(JSON.stringify({"format": 1, "lang": code, "parts": named.parts,
			"colours": named.colours, "categories": named.categories}))
		file.close()
		print("part_names: %s %d of %d parts, %d of %d colours, %d categories" % [
			code, named.parts.size(), library.parts.size(), named.colours.size(), library.colors.size(),
			named.categories.size()])
	quit(0)


## [param library]'s names in [param code]: {parts: {id: name}, colours:
## {code: name}, categories: {name: name}}, each only where the app says it
## in the language (src/dev/parts_page_probe.gd checks the bin says each so).
static func names(library: PartLibrary, code: String) -> Dictionary:
	var parts: Dictionary = {}
	var categories: Dictionary = {}
	var words: Translation = load("res://locale/%s.po" % code) as Translation
	for id: String in library.parts:
		var info: PartLibrary.PartInfo = library.parts[id]
		if not categories.has(info.category) and words != null and not info.category.is_empty():
			categories[info.category] = String(words.get_message(info.category))
		if id.begins_with("bw-"):
			continue
		var said: String = PartWords.part(PartsBin.tile_name(info), code)
		if not said.is_empty():
			parts[id] = said
	for category: String in categories.keys():
		if str(categories[category]).is_empty():
			categories.erase(category)
	var colours: Dictionary = {}
	for colour_code: int in library.colors:
		var said: String = PartWords.colour((library.colors[colour_code] as PartLibrary.BrickColor).name, code)
		if not said.is_empty():
			colours[str(colour_code)] = said
	return {"parts": parts, "colours": colours, "categories": categories}
