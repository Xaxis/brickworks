## moulds4: a made part's id names its whole text, and a part someone else made
## under an id of mine (an older app's, which did not) is kept as theirs.
##   --made-stage=ids: every kind of made part (a cut, an element, a part from a
##     3D file, a mould, a print, a sticker), made from inputs that differ, has
##     as many ids as texts, each ending in a tag of CustomParts.TAG_DIGITS hex
##     digits; the same made twice is one id. 180 cut boxes of a 3001: 180 ids.
##   --made-stage=collide: mouldreview3's collide stage (mr3_cross_probe.gd) on
##     files an older app made: two people's cuts of a 3001 under one id
##     (bw-3001-cc79), mine kept here, theirs in their model. Their model
##     opened, a 3003 put down, saved and read on a library that never saw
##     either: theirs drawn and saved as theirs, mine still mine. Then the
##     other ways their part comes in (opened again, a paste, a kept
##     sub-assembly, put into a model), my own model of mine, a copy of mine
##     cut short (mended, not renamed) and a print whose picture differs.
## RESULT / FINDING lines. Headless.
## Both stages when none is named.
##   godot --headless --path . --script src/dev/made_ids_probe.gd -- --made-stage=collide --made-out=DIR
extends SceneTree

const PROBE_DIR := "user://made_ids/"
## The pair mouldreview3 found: pre261 named both bw-3001-cc79.
const MINE_CUT := [0, 0, 1, 2, 0, 2]
const THEIR_CUT := [0, 0, 3, 2, 0, 3]
const OLD_ID := "bw-3001-cc79"

var _main: Node
var _world: BrickWorld
var _builder: Builder
var _library: PartLibrary
var _verbs: EditVerbs
var _store: ModelStore
var _findings: int = 0
var _args: Dictionary = {}


func _initialize() -> void:
	_run()


func _say(what: String) -> void:
	print("RESULT  " + what)


func _finding(what: String) -> void:
	_findings += 1
	print("FINDING " + what)


func _check(passed: bool, what: String) -> void:
	if passed:
		_say(what)
	else:
		_finding(what)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--made-") and arg.contains("="):
			_args[arg.get_slice("=", 0).trim_prefix("--made-")] = arg.substr(arg.find("=") + 1)
	var out: String = str(_args.get("out", ProjectSettings.globalize_path(PROBE_DIR + "out")))
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(PROBE_DIR + "kept/")
	CustomParts.dir = PROBE_DIR + "kept/"
	SaveTo.native = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(240)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_library = _main.get("_library")
	_verbs = _main.get("_verbs")
	_store = _main.get("_store")
	var stage: String = str(_args.get("stage", ""))
	if stage in ["", "ids"]:
		await _ids()
	if stage in ["", "collide"]:
		await _collide(out)
	print("\nMADE IDS DONE: %d finding line%s" % [_findings, "" if _findings == 1 else "s"])
	quit(1 if _findings > 0 else 0)


# -- every kind of made part: one text, one id -------------------------------------


func _edit(cut: Array) -> PartEditor.Edit:
	var edit := PartEditor.Edit.new()
	edit.from = "3001"
	edit.cut = PackedInt32Array(cut)
	return edit


## Of [param made] ([id, text] pairs): how many ids, how many texts, and the ids
## whose tag is not TAG_DIGITS hex digits.
func _tally(kind: String, made: Array) -> void:
	var ids: Dictionary = {}
	var texts: Dictionary = {}
	var bad: Array = []
	for pair: Array in made:
		ids[pair[0]] = true
		texts[pair[1]] = true
		var tag: String = str(pair[0]).get_slice("-", str(pair[0]).get_slice_count("-") - 1)
		if tag.length() != CustomParts.TAG_DIGITS or not tag.is_valid_hex_number():
			bad.append(pair[0])
	_check(ids.size() == texts.size() and bad.is_empty(),
		"%s: %d made, %d texts, %d ids; ids without a %d-digit tag: %s; e.g. %s" % [kind, made.size(),
			texts.size(), ids.size(), CustomParts.TAG_DIGITS, bad.slice(0, 3),
			made[0][0] if not made.is_empty() else "-"])


func _ids() -> void:
	print("\nONE TEXT, ONE ID, FOR EVERY KIND OF MADE PART")
	# Cuts: every box of a 3001 (4 x 2 studs, 3 plates).
	var cuts: Array = []
	for x0: int in 5:
		for x1: int in range(x0 + 1, 5):
			for z0: int in 3:
				for z1: int in range(z0 + 1, 3):
					for p0: int in 4:
						for p1: int in range(p0 + 1, 4):
							var made: Dictionary = CustomParts.modified_text(_library, _edit([x0, z0, x1, z1, p0, p1]))
							if str(made["problem"]).is_empty():
								cuts.append([made["id"], made["text"]])
	_say("%d cut boxes of 3001 make %d ids" % [cuts.size(), _distinct(cuts)])
	_tally("cut boxes of 3001", cuts)
	var again: Dictionary = CustomParts.modified_text(_library, _edit(MINE_CUT))
	var first: Dictionary = CustomParts.modified_text(_library, _edit(MINE_CUT))
	_check(again["id"] == first["id"] and again["text"] == first["text"],
		"the same cut made twice: one id (%s)" % first["id"])
	# Other edits of parts: lengths, plates, studs, and a title.
	var edits: Array = []
	for words: String in ["from=3700 length=6", "from=3001 plates=6", "from=3001 studs=none",
			"from=3068b studs=fill", "from=3062b studs=none", "from=3941 plates=6"]:
		var edit: PartEditor.Edit = PartEditor.parse_edit(PartEditor.MODIFIED_BY + " " + words)
		for title: String in ["", "My Beam"]:
			edit.title = title
			var made: Dictionary = CustomParts.modified_text(_library, edit)
			if str(made["problem"]).is_empty():
				edits.append([made["id"], made["text"]])
	_tally("edits of six parts, each with and without a title", edits)
	# Elements: the fixtures' specs, each under two titles.
	var elements: Array = []
	for raw: String in FileAccess.get_file_as_string("res://tests/fixtures/elements/specs.txt").split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		for title: String in ["", "Sill"]:
			var spec: ElementMaker.Spec = ElementMaker.from_words(line)
			spec.title = title
			var made: Dictionary = CustomParts.make(_library, spec, false)
			if str(made["problem"]).is_empty():
				elements.append([made["id"], _library.custom_source(str(made["id"]))])
	_tally("elements of the fixtures' specs, each under two titles", elements)
	# Parts from a 3D file, the hair among them.
	var shapes: Array = []
	var stl: PackedByteArray = FileAccess.get_file_as_bytes("res://tests/fixtures/own_parts/lego-goblet.stl")
	for title: String in ["Goblet", "Goblet two", "goblet"]:
		var part: MeshPart = MeshPart.read(stl, "goblet.stl")
		if part == null:
			continue
		if part.unit_unsure:
			part.read_as("mm")
		var made: Dictionary = part.make(_library, title, false)
		if str(made["problem"]).is_empty():
			shapes.append([made["id"], _library.custom_source(str(made["id"]))])
	for file: String in ["mohawk.stl", "wig_67.stl"]:
		var hair: MeshPart = MeshPart.read(FileAccess.get_file_as_bytes(
			"res://tests/fixtures/own_parts/" + file), file)
		if hair == null:
			continue
		if hair.unit_unsure:
			hair.read_as("mm")
		hair.hair = true
		var made: Dictionary = hair.make(_library, "Hair", false)
		if str(made["problem"]).is_empty():
			shapes.append([made["id"], _library.custom_source(str(made["id"]))])
	_tally("parts from 3D files (a goblet under three titles, two hairs called Hair)", shapes)
	# Moulds: one sculpted shape under two titles, and another shape.
	var moulds: Array = []
	var mould: Mould = Mould.of_part(_library, "3901", "headwear")
	if mould != null:
		for title: String in ["Quiff", "Mop"]:
			var made: Dictionary = mould.make(_library, title, false)
			if str(made["problem"]).is_empty():
				moulds.append([made["id"], _library.custom_source(str(made["id"]))])
		mould.grab(Vector3(0, 7, -10), 8.0, true)
		mould.drag(Vector3(0, 3, -4))
		mould.let_go()
		var made: Dictionary = mould.make(_library, "Quiff", false)
		if str(made["problem"]).is_empty():
			moulds.append([made["id"], _library.custom_source(str(made["id"]))])
	_tally("moulds of 3901 (one shape under two titles, another)", moulds)
	# Prints: a tile under two titles and two pictures.
	var prints: Array = []
	var tile: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3068b")
	for colour: Color in [Color.RED, Color.BLUE]:
		for title: String in ["Sign", "Door"]:
			var drawn: Dictionary = {}
			for area: PartPrints.Area in tile:
				var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
				PrintPaint.disc(picture, Vector2(area.size) * 0.5, 20.0, colour)
				drawn[area.key] = picture
			var made: Dictionary = PartPrints.make(_library, "3068b", tile, drawn, title, false)
			for id: String in made["ids"]:
				prints.append([id, _library.custom_source(id)])
	_tally("prints on a 3068b (two pictures, two titles)", prints)
	# Stickers.
	var stickers: Array = []
	for title: String in ["Plate", "Sign"]:
		var picture := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
		picture.fill(Color.YELLOW)
		var made: Dictionary = Stickers.make(_library, picture, Vector2(31.4, 15.4), title, false)
		if str(made["problem"]).is_empty():
			stickers.append([made["id"], _library.custom_source(str(made["id"]))])
	_tally("stickers (two titles)", stickers)


func _distinct(made: Array) -> int:
	var ids: Dictionary = {}
	for pair: Array in made:
		ids[pair[0]] = true
	return ids.size()


# -- two people's parts of one old id ------------------------------------------------


## A part's text without its Name line, as a reader takes it: what it is,
## whatever it is called.
static func _body(text: String) -> String:
	var out := PackedStringArray()
	for line: String in CustomParts.as_read(text).split("\n", false):
		if not line.to_lower().begins_with("0 name:"):
			out.append(line)
	return "\n".join(out)


## Whose [param text] is: "THEIRS", "MINE" or "other (N lines)".
func _whose(text: String, mine: String, theirs: String) -> String:
	if not text.is_empty() and _body(text) == _body(theirs):
		return "THEIRS"
	if not text.is_empty() and _body(text) == _body(mine):
		return "MINE"
	return "other (%d lines)" % CustomParts.as_read(text).split("\n", false).size()


func _collide(out: String) -> void:
	print("\nTWO PEOPLE'S CUTS OF 3001 UNDER ONE OLD ID")
	var mesh: Lbm.PartMesh = _library.mesh_for("3001")
	var info: PartLibrary.PartInfo = _library.parts["3001"]
	var mine: String = str(PartEditor.make_dat(_edit(MINE_CUT), mesh, info.name, info.category, OLD_ID)["text"])
	var theirs: String = str(PartEditor.make_dat(_edit(THEIR_CUT), mesh, info.name, info.category, OLD_ID)["text"])
	# An older app's name for each: the 12-bit tag mouldreview3 found.
	_say("pre261 named cut %s %s and cut %s %s" % [MINE_CUT, _old_id(MINE_CUT), THEIR_CUT, _old_id(THEIR_CUT)])
	# Mine, made by that app and kept here.
	var kept: Dictionary = CustomParts.add(_library, mine, OLD_ID)
	var their_lib := PartLibrary.new()
	their_lib.load_catalogue()
	CustomParts.add(their_lib, theirs, OLD_ID, false)
	var their_tri: int = their_lib.parts[OLD_ID].triangles if their_lib.parts.has(OLD_ID) else -1
	var my_tri: int = _library.parts[OLD_ID].triangles if _library.parts.has(OLD_ID) else -1
	_say("mine kept here as %s (%s), %d triangles; theirs %d triangles; the same text: %s" % [OLD_ID,
		kept["problem"], my_tri, their_tri, mine == theirs])
	var their_model: String = ("0 FILE their-model.ldr\n0 Their model\n0 Name: their-model.ldr\n0 Author: Them\n"
		+ "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 2 0 -24 0 1 0 0 0 1 0 0 0 1 %s.dat\n0 NOFILE\n") % OLD_ID \
		+ "0 FILE " + OLD_ID + ".dat\n" + theirs.strip_edges() + "\n0 NOFILE\n"
	var path: String = PROBE_DIR + "their-model.mpd"
	_write_abs(path, their_model)
	_write_abs(out.path_join("their-model.mpd"), their_model)
	var kept_before: int = DirAccess.get_files_at(CustomParts.dir).size()
	# Opened here (File, Open), a 3003 put down, saved.
	await _open(path)
	var theirs_as: String = _made_brick()
	_check(not theirs_as.is_empty() and _whose(_library.custom_source(theirs_as), mine, theirs) == "THEIRS",
		"their model opened here: %d parts; their part is %s, drawn as %s" % [_world.brick_count(),
			theirs_as, _whose(_library.custom_source(theirs_as), mine, theirs)])
	_check(theirs_as != OLD_ID and _whose(_library.custom_source(OLD_ID), mine, theirs) == "MINE",
		"%s in this library is still %s" % [OLD_ID, _whose(_library.custom_source(OLD_ID), mine, theirs)])
	var placed: int = await _put("3003")
	var saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "their-model-saved.mpd")
	_main.call("save_model", saved_at)
	var saved: String = FileAccess.get_file_as_string(saved_at)
	_write_abs(out.path_join("their-model-saved.mpd"), saved)
	var their_line: String = _line_in(saved, 2)
	var named: String = LdrModel.stem(LdrModel.reference_of(their_line)) if not their_line.is_empty() else ""
	var carried: String = _section(saved, named + ".dat")
	var got: Dictionary = _reopen(saved)
	_check(_whose(carried, mine, theirs) == "THEIRS" and _section(saved, OLD_ID + ".dat").is_empty()
			and int(got["tris"].get(named, -1)) == their_tri,
		"a 3003 put down (%d), saved: their line places %s, its section is %s; read where never made: %s, %s %d triangles of %d" % [
			placed, named, _whose(carried, mine, theirs), got["counts"], named,
			int(got["tris"].get(named, -1)), their_tri])
	var lost: Array = _lost_lines(their_model, saved, {OLD_ID: named})
	_check(lost.is_empty(), "lines of their file lost, their part's name read as its new one: %d %s" % [
		lost.size(), lost.slice(0, 3)])
	_check(FileAccess.get_file_as_string(CustomParts.dir + OLD_ID + ".dat") == mine,
		"my kept file of %s after: %s" % [OLD_ID, _whose(FileAccess.get_file_as_string(
			CustomParts.dir + OLD_ID + ".dat"), mine, theirs)])
	_check(_whose(FileAccess.get_file_as_string(CustomParts.dir + theirs_as + ".dat"), mine, theirs) == "THEIRS",
		"theirs kept beside it as %s: %s" % [theirs_as, _whose(FileAccess.get_file_as_string(
			CustomParts.dir + theirs_as + ".dat"), mine, theirs)])

	print("\nTHEIR MODEL OPENED AGAIN")
	await _open(path)
	_check(_made_brick() == theirs_as and DirAccess.get_files_at(CustomParts.dir).size() == kept_before + 1,
		"their part is %s again; kept files %d before their model, %d now" % [_made_brick(), kept_before,
			DirAccess.get_files_at(CustomParts.dir).size()])

	print("\nMY OWN MODEL OF MINE")
	var my_model: String = ("0 FILE my-model.ldr\n0 My model\n0 Name: my-model.ldr\n0 Author: Me\n"
		+ "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 %s.dat\n0 NOFILE\n") % OLD_ID \
		+ "0 FILE " + OLD_ID + ".dat\n" + mine.strip_edges() + "\n0 NOFILE\n"
	_write_abs(PROBE_DIR + "my-model.mpd", my_model)
	await _open(PROBE_DIR + "my-model.mpd")
	var mine_as: String = _made_brick()
	await _put("3003")
	var my_saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "my-model-saved.mpd")
	_main.call("save_model", my_saved_at)
	var my_saved: String = FileAccess.get_file_as_string(my_saved_at)
	_check(mine_as == OLD_ID and _whose(_section(my_saved, OLD_ID + ".dat"), mine, theirs) == "MINE",
		"my model opened: my part is %s, saved section %s" % [mine_as,
			_whose(_section(my_saved, OLD_ID + ".dat"), mine, theirs)])

	print("\nTHEIR PART COMING IN OTHER WAYS, MY MODEL OPEN")
	# A copy from their window, as Carry.as_file puts it on the clipboard.
	var copied: String = "0 FILE copied.ldr\n1 2 0 0 0 1 0 0 0 1 0 0 0 1 %s.dat\n0 NOFILE\n" % OLD_ID \
		+ "0 FILE " + OLD_ID + ".dat\n" + theirs.strip_edges() + "\n0 NOFILE\n"
	var pasted: Array = Carry.from_ldraw(copied, _library)
	var pasted_as: String = str(pasted[0]["part"]) if not pasted.is_empty() else ""
	_check(pasted_as == theirs_as and _whose(_library.custom_source(pasted_as), mine, theirs) == "THEIRS"
			and _whose(_library.custom_source(OLD_ID), mine, theirs) == "MINE",
		"a paste of their copy: %s, drawn as %s; %s still %s" % [pasted_as,
			_whose(_library.custom_source(pasted_as), mine, theirs), OLD_ID,
			_whose(_library.custom_source(OLD_ID), mine, theirs)])
	# A sub-assembly they kept, its made parts beside its lines (PartShelf).
	var entry: Dictionary = {"ldraw": "1 2 0 0 0 1 0 0 0 1 0 0 0 1 %s.dat\n" % OLD_ID,
		"made": "0 FILE " + OLD_ID + ".dat\n" + theirs.strip_edges() + "\n0 NOFILE\n"}
	var from_kept: Array = Carry.from_kept(entry, _library)
	var kept_as: String = str(from_kept[0]["part"]) if not from_kept.is_empty() else ""
	_check(kept_as == theirs_as and Carry.kept_lines(entry, _library).contains(theirs_as + ".dat"),
		"a kept sub-assembly of theirs: %s, its lines name %s" % [kept_as,
			LdrModel.stem(LdrModel.reference_of(Carry.kept_lines(entry, _library).strip_edges()))])
	# Their model put into mine (Open into, MCP open_model into=true).
	var held: Dictionary = await _store.held_from(their_model, "their-model.ldr")
	var held_parts: Array = []
	for item: Variant in held.get("items", []):
		if item is Dictionary and str((item as Dictionary).get("part", "")).begins_with("bw-"):
			held_parts.append(str(item["part"]))
	_check(held_parts == [theirs_as], "their model put into mine: its made part %s (%s)" % [held_parts,
		held.get("error", "")])
	_check(_whose(_library.custom_source(OLD_ID), mine, theirs) == "MINE"
			and FileAccess.get_file_as_string(CustomParts.dir + OLD_ID + ".dat") == mine,
		"after all of it %s is %s here and kept as %s" % [OLD_ID, _whose(_library.custom_source(OLD_ID),
			mine, theirs), _whose(FileAccess.get_file_as_string(CustomParts.dir + OLD_ID + ".dat"), mine, theirs)])

	print("\nA COPY OF MINE CUT SHORT: MENDED, NOT RENAMED")
	var mine_lines: PackedStringArray = mine.strip_edges().split("\n")
	var header: int = 0
	while header < mine_lines.size() and not mine_lines[header].begins_with("0 //"):
		header += 1
	var short_texts: Dictionary = {
		"cut at 40%": "\n".join(mine_lines.slice(0, int(mine_lines.size() * 0.4))),
		"cut inside a face line": "\n".join(mine_lines.slice(0, int(mine_lines.size() * 0.6))) + "\n"
			+ mine_lines[int(mine_lines.size() * 0.6)].left(12),
		"its header alone": "\n".join(mine_lines.slice(0, header))}
	for what: String in short_texts:
		var cut_model: String = ("0 FILE short.ldr\n0 Short\n0 Name: short.ldr\n0 Author: Them\n"
			+ "1 2 0 -24 0 1 0 0 0 1 0 0 0 1 %s.dat\n0 NOFILE\n") % OLD_ID \
			+ "0 FILE " + OLD_ID + ".dat\n" + str(short_texts[what]) + "\n0 NOFILE\n"
		_write_abs(PROBE_DIR + "short.mpd", cut_model)
		await _open(PROBE_DIR + "short.mpd")
		var drawn_as: String = _made_brick()
		await _put("3003")
		var short_at: String = ProjectSettings.globalize_path(PROBE_DIR + "short-saved.mpd")
		_main.call("save_model", short_at)
		var short_saved: String = FileAccess.get_file_as_string(short_at)
		var back: Dictionary = _reopen(short_saved)
		_check(drawn_as == OLD_ID and _whose(_section(short_saved, OLD_ID + ".dat"), mine, theirs) == "MINE"
				and int(back["tris"].get(OLD_ID, -1)) == my_tri,
			"%s: drawn as %s, saved section %s, read where never made %d triangles of %d" % [what, drawn_as,
				_whose(_section(short_saved, OLD_ID + ".dat"), mine, theirs),
				int(back["tris"].get(OLD_ID, -1)), my_tri])

	await _pictures(out)


## Two prints of one old id whose text is the same and whose picture is not.
func _pictures(out: String) -> void:
	print("\nTWO PRINTS OF ONE OLD ID, THE SAME TEXT, ANOTHER PICTURE")
	var id: String = "bw-3068b-pabc123"
	var picture_name: String = id + "-top.png"
	var part: String = ("0 Tile 2 x 2, Custom Print Sign\n0 Name: %s.dat\n" % id
		+ "0 !LDRAW_ORG Unofficial_Part\n0 BFC CERTIFY CCW\n"
		+ "0 !TEXMAP START PLANAR -20 0 20 20 0 20 -20 0 -20 %s\n" % picture_name
		+ "4 16 -20 0 20 20 0 20 20 0 -20 -20 0 -20\n0 !TEXMAP END\n")
	var red := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	red.fill(Color.RED)
	var blue := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	blue.fill(Color.BLUE)
	var my_png: PackedByteArray = red.save_png_to_buffer()
	var their_png: PackedByteArray = blue.save_png_to_buffer()
	var kept: Dictionary = CustomParts.add(_library, part, id, true, {picture_name: my_png})
	_say("my print kept as %s (%s); its picture kept: %s" % [id, kept["problem"],
		FileAccess.get_file_as_bytes(CustomParts.dir + picture_name) == my_png])
	var encoded: String = Marshalls.raw_to_base64(their_png)
	var model: String = ("0 FILE their-sign.ldr\n0 Their sign\n0 Name: their-sign.ldr\n0 Author: Them\n"
		+ "1 4 0 -8 0 1 0 0 0 1 0 0 0 1 %s.dat\n0 NOFILE\n" % id
		+ "0 FILE %s.dat\n" % id + part + "0 NOFILE\n"
		+ "0 !DATA %s\n0 !: %s\n" % [picture_name, encoded])
	_write_abs(PROBE_DIR + "their-sign.mpd", model)
	await _open(PROBE_DIR + "their-sign.mpd")
	var as_id: String = _made_brick()
	var mesh: Lbm.PartMesh = _library.mesh_for(as_id)
	var drawn_with: Array = mesh.print_files.keys() if mesh != null else []
	var theirs_drawn: bool = mesh != null and mesh.print_files.size() == 1 \
		and mesh.print_files.values()[0] == their_png
	_check(as_id != id and theirs_drawn, "their sign opened: %s, drawn with %s, their picture: %s" % [
		as_id, drawn_with, theirs_drawn])
	_check(FileAccess.get_file_as_bytes(CustomParts.dir + picture_name) == my_png
			and _library.mesh_for(id) != null and _library.mesh_for(id).print_files.values()[0] == my_png,
		"my print %s and its kept picture are still mine" % id)
	var saved_at: String = ProjectSettings.globalize_path(PROBE_DIR + "their-sign-saved.mpd")
	_main.call("save_model", saved_at)
	var saved: String = FileAccess.get_file_as_string(saved_at)
	_write_abs(out.path_join("their-sign-saved.mpd"), saved)
	var back: LdrModel = LdrModel.parse(saved, "probe.mpd")
	var data_ok: bool = false
	for name: String in back.embedded_data:
		if name != picture_name and back.embedded_data[name] == their_png:
			data_ok = true
	_check(data_ok and back.embedded_parts.has(as_id + ".dat") and not saved.contains(picture_name + "\n"),
		"saved: carries %s and their picture under its own name: %s (names %s)" % [as_id, data_ok,
			back.embedded_data.keys()])


## An older app's name for a cut of 3001 (pre261's PartEditor.id_for).
static func _old_id(cut: Array) -> String:
	return ("bw-3001-c%03x" % (hash(cut) & 0xfff)).left(21)


## The made part on the baseplate: the first brick that is not one of LEGO's.
func _made_brick() -> String:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id.begins_with("bw-"):
			return brick.part_id
	return ""


## The first part line of [param text] in [param colour].
static func _line_in(text: String, colour: int) -> String:
	for line: String in text.split("\n"):
		var fields: PackedStringArray = line.strip_edges().split(" ", false)
		if fields.size() >= 15 and fields[0] == "1" and fields[1] == str(colour):
			return line.strip_edges()
	return ""


# -- helpers, as mr3_cross_probe has them --------------------------------------------


## The body of [param text]'s first FILE section called [param name].
static func _section(text: String, name: String) -> String:
	var out := PackedStringArray()
	var inside: bool = false
	for line: String in text.split("\n"):
		var word: String = LdrModel.section_word(line)
		if not word.is_empty():
			if inside:
				break
			if word == "FILE" and line.strip_edges().to_lower().ends_with(name.to_lower()):
				inside = true
			continue
		if inside:
			out.append(line)
	return "\n".join(out)


## The lines of [param original] not in [param saved] in order, a part named
## in [param renamed] read under its new name.
func _lost_lines(original: String, saved: String, renamed: Dictionary) -> Array:
	var have: PackedStringArray = saved.replace("\r\n", "\n").split("\n")
	var at: int = 0
	var lost: Array = []
	for line: String in original.replace("\r\n", "\n").split("\n"):
		if line.strip_edges().is_empty():
			continue
		var wanted: String = line.strip_edges()
		for old: String in renamed:
			wanted = wanted.replace(old, str(renamed[old]))
		var found: int = -1
		for n: int in range(at, have.size()):
			if have[n].strip_edges() == wanted:
				found = n
				break
		if found < 0:
			lost.append(line.left(80))
		else:
			at = found + 1
	return lost


func _reopen(text: String) -> Dictionary:
	var was: String = CustomParts.dir
	CustomParts.dir = PROBE_DIR + "elsewhere-%d/" % randi()
	var library := PartLibrary.new()
	library.load_catalogue()
	var model: LdrModel = LdrModel.parse(text, "probe.mpd")
	CustomParts.take_from(library, model)
	var counts: Dictionary = {}
	var tris: Dictionary = {}
	for placement: LdrModel.Placement in model.flatten(library.parts):
		var key: String = "%s:%d" % [placement.part_id, placement.color_code]
		counts[key] = int(counts.get(key, 0)) + 1
		tris[placement.part_id] = library.parts[placement.part_id].triangles \
			if library.parts.has(placement.part_id) and library.mesh_for(placement.part_id) != null else -1
	CustomParts.dir = was
	return {"counts": counts, "tris": tris}


func _open(path: String) -> void:
	_builder.clear_selection()
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 600:
		await process_frame
		if _store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	(_main.get("_bar") as ModelBar).opened.emit(_world.brick_count())
	await _frames(5)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
		await _frames(3)
	_builder.forget_history()
	_verbs.set_mode("select")
	_builder.clear_selection()


## [param part] in colour 4, put down clear of the model as a person would.
func _put(part: String) -> int:
	var before: int = _world.brick_count()
	var far: float = 0.0
	for brick: BrickWorld.Brick in _world.bricks():
		far = maxf(far, brick.transform.origin.x)
	_builder.cancel_carry()
	_builder.hold_copy([{"part": part, "color": 4, "at": Transform3D.IDENTITY}])
	for dx: int in [200, 280, 360, 480, 640]:
		for dz: int in [0, 120, -120]:
			for _n: int in 6:
				_builder.update_preview(Vector3(far + dx, 600, dz), Vector3.DOWN)
				await process_frame
			_builder.place()
			await _frames(3)
			if _world.brick_count() > before:
				_builder.cancel_carry()
				return _world.brick_count() - before
	_builder.cancel_carry()
	return _world.brick_count() - before


func _write_abs(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
