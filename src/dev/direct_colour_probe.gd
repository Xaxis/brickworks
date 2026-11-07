## A part in a direct colour comes out of every writer as its own colour.
##
##   godot --headless --path . --script src/dev/direct_colour_probe.gd
##   ... -- --shots=DIR   the thumbnail it draws, kept to look at
##
## LDraw lets a file give a part an RGB of its own, 0x2RRGGBB, in place of a
## palette number (LdrModel.is_direct_colour). Export wrote such a part as
## magenta "Unknown 33488896" while the site's GLB of the same file wrote
## its hex (arview). Here a file of three 2 x 4 bricks, one at each channel's
## extreme (0x2FF0000, 0x200FF00, 0x20000FF), and one in the palette's Red to
## hold the rest still, is opened as the app opens it, and every writer that
## turns a colour code into a colour is read back:
##   the colour the 3D view draws each brick in, which its pictures, the
##   booklet's pages and a session's model shots are drawn from, and the
##   booklet's own colour key and parts box (PartLibrary.color, Inventory);
##   Export's GLB and glTF (each material's base colour within 1/255 of the
##   hex, opaque, named by it) and OBJ (its MTL's Kd, named with no "#",
##   which an MTL reader may take for a comment); STL carries no colour;
##   the GLB against the site's of the same file (tools/web/arview_check.mjs);
##   the file's thumbnail (ModelThumbnail), each colour in it and no magenta;
##   the shops' lists, which have no such colour: each part listed in the
##   nearest colour LEGO makes (PartLibrary.catalogue_nearest), BrickLink's
##   with a REMARKS saying so, Pick a Brick's named where that colour has no
##   element, each list's words naming every stand-in, and none dropped;
##   the site's parts list and lists of the same file (api/_parts.js,
##   tools/web/direct_colour_check.mjs), named and coloured alike, and its
##   choice of stand-in the app's across a grid of 512 colours.
## Exits non-zero when one differs.
extends SceneTree

const DIRECT: Array[int] = [0x2FF0000, 0x200FF00, 0x20000FF]
const PALETTE_RED := 4
const PART := "3001"
## One step of eight bits, as near as a writer can come.
const ONE_STEP := 1.0 / 255.0 + 1e-6

var _failures: int = 0
var _shots: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	CustomParts.keeps = false
	await process_frame
	var out: String = OS.get_user_data_dir().path_join("direct_colour_probe")
	DirAccess.make_dir_recursive_absolute(out)
	var path: String = out.path_join("direct_colours.ldr")
	var lines := PackedStringArray(["0 Direct colours", "0 Name: direct_colours.ldr",
		"0 Author: direct_colour_probe"])
	var x: int = 0
	for code: int in DIRECT + [PALETTE_RED]:
		lines.append("1 %s %d 0 0 1 0 0 0 1 0 0 0 1 %s.dat" % [
			("0x%07X" % code) if code >= 0x2000000 else str(code), x, PART])
		x += 100
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\r\n".join(lines) + "\r\n")
	file.close()
	store.open(path)
	# Laid and drawn over frames (ModelStore._open_into, BrickWorld._flush).
	for _n: int in 600:
		await process_frame
		if not world.is_being_laid() and world._dirty.is_empty():
			break
	_check("the file opens as four bricks", world.brick_count() == 4)

	print("drawn: the 3D view, its pictures and the booklet")
	for brick: BrickWorld.Brick in world.bricks():
		if not brick.color_code in DIRECT:
			continue
		var want: Color = _hex_colour(brick.color_code)
		var drawn: Color = _drawn_colour(world, brick.id)
		_check("%s is drawn %s" % [_hex(brick.color_code), drawn.to_html(false)], _near(drawn, want))
		var colour: PartLibrary.BrickColor = library.color(brick.color_code)
		_check("...its colour named %s, %s, opaque (the booklet's colour key and parts box)" % [colour.name,
			colour.rgb.to_html(false)], colour.name == _hex(brick.color_code) and _near(colour.rgb, want)
			and colour.alpha == 255)

	print("Export")
	var maker := MeshExport.new()
	maker.world = world
	maker.library = library
	maker.scenery = store.scenery
	var glb: MeshExport.Made = await maker.write("glb", "direct_colours")
	var glb_ok: bool = glb.refused.is_empty() and glb.files.size() == 1
	_check("GLB written (%d parts)" % glb.parts, glb_ok)
	var glb_path: String = out.path_join("direct_colours.glb")
	if glb_ok:
		var bytes: PackedByteArray = glb.files[0][1]
		var saved: FileAccess = FileAccess.open(glb_path, FileAccess.WRITE)
		saved.store_buffer(bytes)
		saved.close()
		var json_length: int = bytes.decode_u32(12)
		_gltf_colours("GLB", JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8()))
	var gltf: MeshExport.Made = await maker.write("gltf", "direct_colours")
	_check("glTF written", gltf.refused.is_empty() and gltf.files.size() == 1)
	if gltf.files.size() == 1:
		_gltf_colours("glTF", JSON.parse_string((gltf.files[0][1] as PackedByteArray).get_string_from_utf8()))
	var obj: MeshExport.Made = await maker.write("obj", "direct_colours")
	_check("OBJ and its MTL written", obj.refused.is_empty() and obj.files.size() == 2)
	if obj.files.size() == 2:
		_obj_colours((obj.files[0][1] as PackedByteArray).get_string_from_utf8(),
			(obj.files[1][1] as PackedByteArray).get_string_from_utf8())
	print("  --    STL carries no colour, so there is none to check")

	if glb_ok:
		var listed: Dictionary = {path: {"glb": glb_path, "title": "direct_colours", "parts": glb.parts,
			"left_out": glb.left_out, "custom": []}}
		var app_json: String = out.path_join("direct_colours_app.json")
		var app_file: FileAccess = FileAccess.open(app_json, FileAccess.WRITE)
		app_file.store_string(JSON.stringify(listed))
		app_file.close()
		var said: Array = []
		var code: int = OS.execute("node", [ProjectSettings.globalize_path("res://tools/web/arview_check.mjs"),
			"--app=" + app_json], said, true)
		for line: Variant in said:
			print(str(line).strip_edges(false, true).indent("    "))
		_check("the site's GLB of the file is Export's, colour for colour (arview_check exit %d)" % code,
			code == 0)

	print("thumbnail")
	var thumb: Dictionary = ModelThumbnail.make(path, 256)
	var image: Image = thumb.get("image")
	_check("drawn (%s)" % str(thumb.get("error", "%d parts" % int(thumb.get("drawn", 0)))), image != null)
	if image != null:
		if not _shots.is_empty():
			image.save_png(_shots.path_join("direct_colours_thumbnail.png"))
		var seen: Dictionary = _hues(image)
		for name: String in ["red", "green", "blue"]:
			_check("%s in it (%d pixels)" % [name, int(seen[name])], int(seen[name]) > 200)
		_check("no magenta in it (%d pixels)" % int(seen["magenta"]), int(seen["magenta"]) == 0)

	print("the shops' lists")
	var stock: Inventory = Inventory.of(world, library, store.scenery)
	var by_code: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		by_code[lot.color_code] = lot
	var nearest: Callable = func(code: int) -> int:
		return int(library.call("catalogue_nearest", code)) if library.has_method("catalogue_nearest") else -1
	for code: int in DIRECT:
		var lot: Inventory.Lot = by_code.get(code)
		if lot == null:
			_check("%s has its lot" % _hex(code), false)
			continue
		var stand_in: int = int(lot.get("stand_in")) if lot.get("stand_in") != null else -1
		_check("%s's lot is named %s, %s, with no element of its own (%s)" % [_hex(code), lot.color_name,
			lot.rgb_hex, lot.element], lot.color_name == _hex(code)
			and lot.rgb_hex == _hex(code).trim_prefix("#").to_lower() and lot.element.is_empty())
		_check("...and stands in as %s, %s, the nearest current solid colour" % [stand_in,
			library.color(stand_in).name if stand_in >= 0 else "none"],
			stand_in >= 0 and stand_in == nearest.call(code) and stand_in == _brute_nearest(library, code))
	var control: Inventory.Lot = by_code.get(PALETTE_RED)
	_check("the palette's Red is ordered as itself", control != null and (control.get("stand_in") == null
		or int(control.get("stand_in")) == -1))

	var xml: Dictionary = ShopLists.bricklink_xml(stock, library)
	var text: String = str(xml["text"])
	_check("BrickLink: all %d lots listed, none left off (%d)" % [stock.lots.size(), int(xml["left_out"])],
		int(xml["left_out"]) == 0 and int(xml["lots"]) == stock.lots.size())
	var items: PackedStringArray = text.split("<ITEM>", false)
	for code: int in DIRECT:
		var lot: Inventory.Lot = by_code.get(code)
		if lot == null or lot.get("stand_in") == null:
			_check("BrickLink lists %s in its stand-in" % _hex(code), false)
			continue
		var stand_in: int = int(lot.get("stand_in"))
		var found: bool = false
		for item: String in items:
			if item.contains("<REMARKS>") and item.contains(_hex(code)) \
					and item.contains("<COLOR>%d</COLOR>" % library.bricklink_colour(stand_in)) \
					and item.contains(library.color(stand_in).name):
				found = true
		_check("BrickLink lists %s as BrickLink colour %d, a REMARKS saying so" % [_hex(code),
			library.bricklink_colour(stand_in)], found)
	_check("...every tag where BrickLink's help lists it", _tags_in_order(text))
	_check("...and its words name each: %s" % _words(xml), _names_all(_words(xml)))
	var csv: Dictionary = ShopLists.rebrickable_csv(stock)
	_check("Rebrickable: all %d lots listed (%d left off)" % [stock.lots.size(), int(csv["left_out"])],
		int(csv["left_out"]) == 0)
	_check("...and its words name each: %s" % _words(csv), _names_all(_words(csv)))
	var pick: Dictionary = ShopLists.pick_a_brick(stock)
	var rows: String = "\n".join(pick["files"])
	var missing: PackedStringArray = ShopLists.named_lots(pick["missing"])
	for code: int in DIRECT:
		var lot: Inventory.Lot = by_code.get(code)
		if lot == null:
			continue
		var element: String = str(lot.get("stand_in_element")) if lot.get("stand_in_element") != null else ""
		var named: bool = false
		for one: String in missing:
			named = named or one.contains(_hex(code))
		if not element.is_empty():
			_check("Pick a Brick lists %s as element %s, and its words say so" % [_hex(code), element],
				rows.contains("\n%s," % element) and not named and _words(pick).contains(_hex(code)))
		else:
			_check("Pick a Brick names %s, its stand-in having no element: %s" % [_hex(code),
				"; ".join(missing)], named)
	_check("...every lot on it or named (%d + %d of %d); its words: %s" % [int(pick["lots"]),
		(pick["missing"] as Array).size(), stock.lots.size(), _words(pick)],
		int(pick["lots"]) + (pick["missing"] as Array).size() == stock.lots.size())

	print("the site's parts list and lists")
	var said: Array = []
	var exit: int = OS.execute("node", [ProjectSettings.globalize_path("res://tools/web/direct_colour_check.mjs"),
		path], said, false)
	var site: Variant = JSON.parse_string(str(said[0])) if exit == 0 and not said.is_empty() else null
	_check("tools/web/direct_colour_check.mjs answers (exit %d)" % exit, exit == 0 and site is Dictionary)
	if exit == 0 and site is Dictionary:
		var grid: Dictionary = site["grid"]
		var differing := PackedStringArray()
		for key: Variant in grid:
			var app: int = nearest.call(int(key))
			if app != int(grid[key]):
				differing.append("%s app %d site %d" % [_hex(int(key)), app, int(grid[key])])
		_check("the site chooses the app's stand-in for each of %d colours%s" % [grid.size(),
			"" if differing.is_empty() else ": " + ", ".join(differing.slice(0, 8))], differing.is_empty())
		for lot: Variant in site["lots"]:
			var row: Dictionary = lot
			var code: int = int(row["colour"])
			if not code in DIRECT:
				continue
			var mine: Inventory.Lot = by_code.get(code)
			var stood: Variant = row.get("stand_in")
			_check("the site's %s lot is named %s, %s, standing in as %s" % [_hex(code), row["colour_name"],
				row["hex"], str((stood as Dictionary).get("name")) if stood is Dictionary else "none"],
				str(row["colour_name"]) == _hex(code) and str(row["hex"]) == _hex(code).trim_prefix("#").to_lower()
				and stood is Dictionary and mine != null and mine.get("stand_in") != null
				and int((stood as Dictionary)["colour"]) == int(mine.get("stand_in")))
		var wanted: Dictionary = site["wanted"]
		_check("the site's wanted list leaves none off and names each stand-in (%s)" % ", ".join(
			wanted["stand_ins"]), int(wanted["left_out"]) == 0 and (wanted["stand_ins"] as Array).size() == 3
			and str(wanted["text"]).count("<REMARKS>") == 3)
		var rebrickable: Dictionary = site["rebrickable"]
		_check("the site's Rebrickable list leaves none off and names each stand-in",
			int(rebrickable["left_out"]) == 0 and (rebrickable["stand_ins"] as Array).size() == 3)

	print("")
	print("direct_colour: every writer gives a direct colour its own colour" if _failures == 0
		else "direct_colour: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## Each material a direct-coloured part's mesh uses in a glTF document:
## its base colour, back from linear, within a step of the hex; opaque;
## named by the hex.
func _gltf_colours(what: String, doc: Variant) -> void:
	if not doc is Dictionary:
		_check("%s's document reads" % what, false)
		return
	var nodes: Array = (doc as Dictionary).get("nodes", [])
	var meshes: Array = (doc as Dictionary).get("meshes", [])
	var materials: Array = (doc as Dictionary).get("materials", [])
	for code: int in DIRECT:
		var checked: int = 0
		var right: int = 0
		var said: String = ""
		for node: Variant in nodes:
			var extras: Dictionary = (node as Dictionary).get("extras", {})
			if int(extras.get("ldraw_colour", -1)) != code:
				continue
			var mesh: Dictionary = meshes[int((node as Dictionary)["mesh"])]
			for primitive: Variant in mesh["primitives"]:
				var material: Dictionary = materials[int((primitive as Dictionary)["material"])]
				var factor: Array = (material["pbrMetallicRoughness"] as Dictionary)["baseColorFactor"]
				var linear := Color(float(factor[0]), float(factor[1]), float(factor[2]), float(factor[3]))
				var srgb: Color = linear.linear_to_srgb()
				srgb.a = linear.a
				said = "%s %s alpha %.3f" % [str(material.get("name", "")), srgb.to_html(false), srgb.a]
				checked += 1
				if _near(srgb, _hex_colour(code)) and is_equal_approx(srgb.a, 1.0) \
						and not material.has("alphaMode") and str(material.get("name", "")) == _hex(code):
					right += 1
		_check("%s: %s's %d surfaces in its own colour (%s)" % [what, _hex(code), checked, said],
			checked > 0 and right == checked)


## Each direct-coloured part's material in an OBJ's MTL: named with no "#",
## its Kd within a step of the hex.
func _obj_colours(obj: String, mtl: String) -> void:
	var kd: Dictionary = {}
	var current: String = ""
	var hashed: bool = false
	for line: String in mtl.split("\n"):
		if line.begins_with("newmtl "):
			current = line.trim_prefix("newmtl ")
			hashed = hashed or current.contains("#")
		elif line.begins_with("Kd ") and not current.is_empty():
			var v: PackedStringArray = line.split(" ", false)
			kd[current] = Color(float(v[1]), float(v[2]), float(v[3]))
	for line: String in obj.split("\n"):
		if line.begins_with("usemtl ") and line.contains("#"):
			hashed = true
	_check("OBJ: no material named with a \"#\"", not hashed)
	for code: int in DIRECT:
		var name: String = "rgb_" + _hex(code).trim_prefix("#")
		var colour: Variant = kd.get(name)
		_check("OBJ: %s is material %s, Kd %s" % [_hex(code), name,
			(colour as Color).to_html(false) if colour is Color else "none"],
			colour is Color and _near(colour, _hex_colour(code)) and obj.contains("usemtl " + name + "\n"))


## The colour a brick's own surfaces are drawn in: what BrickWorld hands the
## GPU for each of its own (colour 16) surfaces, by the functions that fill
## the MultiMesh's slot (_write_instance and _pack both write _shown_colour of
## _brick_colour). Read from the functions, as a headless engine keeps no
## MultiMesh colours to read back (its RenderingServer is a dummy).
func _drawn_colour(world: BrickWorld, brick_id: int) -> Color:
	var brick: BrickWorld.Brick = world.get_brick(brick_id)
	for key: String in world._brick_batches.get(brick_id, PackedStringArray()):
		var batch: BrickWorld.Batch = world._batches[key]
		var surface: int = world._surface_colour(batch, key.split(":")[1].to_int())
		if surface == Lbm.COLOR_INHERIT:
			return world._shown_colour(brick, world._brick_colour(brick, surface))
	return Color(0, 0, 0, 0)


## Pixels of the picture strongly of each primary, and magenta's.
func _hues(image: Image) -> Dictionary:
	var seen: Dictionary = {"red": 0, "green": 0, "blue": 0, "magenta": 0}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if c.r > 0.45 and c.g < 0.2 and c.b < 0.2:
				seen["red"] += 1
			elif c.g > 0.45 and c.r < 0.25 and c.b < 0.25:
				seen["green"] += 1
			elif c.b > 0.45 and c.r < 0.2 and c.g < 0.2:
				seen["blue"] += 1
			elif c.r > 0.5 and c.b > 0.5 and c.g < 0.3:
				seen["magenta"] += 1
	return seen


## The nearest of the stand-in colours by CIEDE2000, worked here the long way.
func _brute_nearest(library: PartLibrary, code: int) -> int:
	if not library.has_method("stand_in_codes"):
		return -2
	var here: Vector3 = HiddenColours.lab(_hex_colour(code))
	var best: int = -1
	var gap: float = INF
	for choice: int in library.call("stand_in_codes"):
		var colour: PartLibrary.BrickColor = library.colors[choice]
		if colour.group != "solid" or colour.alpha != 255 or colour.bricklink < 0 or not colour.current:
			return -3
		var apart: float = HiddenColours.de2000(here, HiddenColours.lab(colour.rgb))
		if apart < gap:
			gap = apart
			best = choice
	return best


## Whether every tag of each item is in the order BrickLink's help lists them.
func _tags_in_order(text: String) -> bool:
	var order: Array[String] = ["ITEMTYPE", "ITEMID", "COLOR", "MAXPRICE", "MINQTY", "QTYFILLED",
		"CONDITION", "REMARKS", "NOTIFY", "WANTEDSHOW", "WANTEDLISTID"]
	for item: String in text.split("<ITEM>", false).slice(1):
		var last: int = -1
		var regex := RegEx.create_from_string("<([A-Z]+)>")
		for found: RegExMatch in regex.search_all(item.get_slice("</ITEM>", 0)):
			var at: int = order.find(found.get_string(1))
			if at <= last:
				return false
			last = at
	return true


func _words(made: Dictionary) -> String:
	var lists := ShopLists.new()
	return str(lists.call("stand_in_words", made)) if lists.has_method("stand_in_words") else ""


func _names_all(words: String) -> bool:
	for code: int in DIRECT:
		if not words.contains(_hex(code)):
			return false
	return true


func _hex(code: int) -> String:
	return "#%06X" % (code & 0xFFFFFF)


func _hex_colour(code: int) -> Color:
	return Color.hex((code & 0xFFFFFF) << 8 | 0xFF)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= ONE_STEP and absf(a.g - b.g) <= ONE_STEP and absf(a.b - b.b) <= ONE_STEP


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
