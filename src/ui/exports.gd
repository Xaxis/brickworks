## What Export writes besides the LDraw file: a picture of the model, its
## parts list for BrickLink, Rebrickable or LEGO® Pick a Brick, the model as a
## BrickLink Studio file, and the model as a 3D file. See [Picture],
## [ShopLists], [StudioIo], [MeshExport].
class_name Exports
extends Node

## The size of the picture inside a Studio file, which Studio shows for
## it in its own Open dialog.
const STUDIO_THUMBNAIL := Vector2i(800, 600)

var world: BrickWorld
var library: PartLibrary
## The model's text, for the Studio file.
var store: ModelStore
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass
## The model's name, for the file's.
var named: Callable = func() -> String: return "Model"
## Where files go on the desktop; the Downloads folder when empty. A probe
## points it at a folder of its own. A person's own press asks instead
## ([param asking] on each: SaveTo).
var folder: String = ""

var picture: Picture


func _ready() -> void:
	picture = Picture.new()
	add_child(picture)


func take_picture(asking: bool = false) -> String:
	if world.brick_count() - scenery.size() <= 0:
		say.call("nothing to take a picture of")
		return ""
	if not Picture.possible():
		say.call("no picture: a run with no window draws nothing")
		return ""
	var to: String = await _where(_file("png"), asking)
	if to.is_empty():
		return ""
	say.call("taking the picture…")
	var image: Image = await picture.take()
	if image == null:
		say.call("nothing to take a picture of")
		return ""
	var line: String = Picture.keep(image, to.get_file(), to.get_base_dir())
	say.call(line)
	return line


## A shop's list of the model's parts: [param shop] "bricklink",
## "rebrickable" or "pickabrick". [param wants]: what a BrickLink wanted list
## asks of each item; the person's last choice when null (ShopLists.Wants).
func shop_list(shop: String, skip: Dictionary = {}, asking: bool = false,
		wants: ShopLists.Wants = null) -> String:
	# [param skip]: the bricks to leave off besides the baseplate, for the
	# list of one part of what is built (a brickified model, from its panel).
	var left: Dictionary = scenery
	if not skip.is_empty():
		left = scenery.duplicate()
		left.merge(skip)
	var stock: Inventory = Inventory.of(world, library, left)
	if stock.lots.is_empty():
		say.call("nothing to list yet")
		return ""
	if shop == "pickabrick":
		return await _pick_a_brick(stock, asking)
	var made: Dictionary
	var file_name: String
	var mime: String
	if shop == "bricklink":
		if wants == null:
			wants = ShopLists.Wants.kept()
		made = ShopLists.bricklink_xml(stock, library, wants)
		file_name = _file("xml", "_bricklink")
		mime = "application/xml"
	else:
		made = ShopLists.rebrickable_csv(stock)
		file_name = _file("csv", "_rebrickable")
		mime = "text/csv"
	var to: String = await _where(file_name, asking)
	if to.is_empty():
		return ""
	var line: String = _give(str(made["text"]), to.get_file(), mime, to.get_base_dir())
	if shop == "bricklink" and not wants.words().is_empty():
		line += " — " + wants.words()
	if int(made["left_out"]) > 0:
		line += " — %d of %s left off: %s" % [int(made["left_out"]), Counted.of(stock.lots.size(), "lot"),
			ShopLists.why_left_off(made, shop)]
	say.call(line)
	return line


## The parts LEGO's Pick a Brick sells, as its list upload takes them
## (ShopLists.pick_a_brick): NAME_pickabrick.csv, or past 400 elements one
## file a 400, NAME_pickabrick_1.csv, _2.csv… beside the one chosen (in a
## browser, one .zip of them, as an OBJ and its colours come). What it says
## names the parts not on it, for the person to find elsewhere.
func _pick_a_brick(stock: Inventory, asking: bool) -> String:
	var made: Dictionary = ShopLists.pick_a_brick(stock)
	var files: PackedStringArray = made["files"]
	if files.is_empty():
		var none: String = ("no LEGO® element number is known for any part of this model, "
			+ "so there is nothing for Pick a Brick")
		say.call(none)
		return none
	var to: String = await _where(_file("csv", "_pickabrick"), asking)
	if to.is_empty():
		return ""
	var line: String
	if files.size() == 1:
		line = _give(files[0], to.get_file(), "text/csv", to.get_base_dir())
	else:
		var base: String = to.get_file().get_basename()
		var members: Array = []
		for n: int in files.size():
			members.append(["%s_%d.csv" % [base, n + 1], files[n].to_utf8_buffer()])
		if OS.has_feature("web"):
			line = _give_bytes(StudioIo.zip(members), base + ".zip", "application/zip")
		else:
			var paths := PackedStringArray()
			for member: Array in members:
				var one: String = _give_bytes(member[1], member[0], "text/csv", to.get_base_dir())
				if not one.begins_with("wrote "):
					say.call(one)
					return one
				paths.append(one.trim_prefix("wrote "))
			# Show in folder shows the first.
			SaveTo.wrote(paths[0])
			line = "wrote %s" % " and ".join(paths)
	if not line.begins_with("wrote ") and not line.begins_with("downloaded "):
		say.call(line)
		return line
	line += " — %s, %s, to upload at LEGO® Pick a Brick" % [
		Counted.of(int(made["lines"]), "element"), Counted.of(int(made["pieces"]), "piece")]
	if files.size() > 1:
		line += " — in %d files of %d lines at most, as Pick a Brick takes them" % [
			files.size(), ShopLists.PICK_A_BRICK_LINES]
	var over: Dictionary = made["over"]
	if not over.is_empty():
		var asked := PackedStringArray()
		for element: String in over:
			asked.append("%d more of %s" % [int(over[element]), element])
		line += " — Pick a Brick takes %d of an element: add by hand %s" % [
			ShopLists.PICK_A_BRICK_MOST, ", ".join(asked)]
	var missing: Array[Inventory.Lot] = made["missing"]
	if not missing.is_empty():
		var named: PackedStringArray = ShopLists.named_lots(missing)
		var shown: PackedStringArray = named.slice(0, MOST_NAMED)
		line += " — not on it, with no LEGO® element number known: %s" % "; ".join(shown)
		if named.size() > shown.size():
			line += "; and %s more" % Counted.of(named.size() - shown.size(), "lot")
	say.call(line)
	return line


## The most lots a Pick a Brick list's line names as not on it.
const MOST_NAMED := 24


## The model as a BrickLink Studio file (.io): its LDraw, with the build
## order, and a picture of it, in a zip. See [StudioIo].
func studio_io(asking: bool = false) -> String:
	if store == null or world.brick_count() - scenery.size() <= 0:
		say.call("nothing to export")
		return ""
	var to: String = await _where(_file("io"), asking)
	if to.is_empty():
		return ""
	say.call("writing the Studio file…")
	var text: String = await store.text_for_file(str(named.call()), "Writing the Studio file…")
	if text.is_empty():
		say.call("stopped writing the Studio file")
		return ""
	# A headless run draws nothing (Picture.possible), and a Studio file
	# without its picture is still the model.
	var thumbnail := PackedByteArray()
	var image: Image = await picture.take(STUDIO_THUMBNAIL)
	if image != null and not image.is_empty():
		thumbnail = image.save_png_to_buffer()
	var bytes: PackedByteArray = StudioIo.pack(text, thumbnail, ModelStore.count_in(text),
		studio_parts(world, library))
	var line: String = _give_bytes(bytes, to.get_file(), "application/octet-stream",
		to.get_base_dir())
	say.call(line)
	return line


## The model's prints and stickers as Studio carries a decorated part, for
## an .io's CustomParts/: file name -> text (StudioDecor.studio_text). The
## model.ldr beside them carries them as LDraw has them, TEXMAP and !DATA,
## for every other program and for opening here again.
static func studio_parts(model: BrickWorld, parts: PartLibrary) -> Dictionary:
	var out: Dictionary = {}
	for item: Variant in model.bricks():
		var id: String = (item as BrickWorld.Brick).part_id
		if out.has(id + ".dat"):
			continue
		var text: String = parts.custom_source(id)
		var mesh: Lbm.PartMesh = parts.mesh_for(id)
		if text.is_empty() or mesh == null or not PartPrints.has_pictures(text):
			continue
		out[id + ".dat"] = StudioDecor.studio_text(id, text, mesh.print_files)
	return out


## Every saved model in one .zip, each the .ldr it is kept as: File, Export,
## All my models, and the warning shown where a browser may clear them
## (StorageOffer). On the web a person's models are in the browser and
## nowhere else, and this is a copy of their own that outlives it.
func all_models(asking: bool = false) -> String:
	var members: Array = []
	for entry: ModelStore.Entry in store.list_saved():
		members.append([entry.path.get_file(), FileAccess.get_file_as_bytes(entry.path)])
	if members.is_empty():
		say.call("no saved models to download yet")
		return ""
	var to: String = await _where("brickworks_models_%s.zip" % Time.get_date_string_from_system(),
		asking)
	if to.is_empty():
		return ""
	var line: String = _give_bytes(StudioIo.zip(members), to.get_file(), "application/zip",
		to.get_base_dir())
	line += " — %d model%s" % [members.size(), "" if members.size() == 1 else "s"]
	say.call(line)
	return line


## File, Export, 3D model…: which format, GLB unless another was chosen
## last, and what each is for and holds.
func ask_model_3d() -> void:
	if world.brick_count() - scenery.size() <= 0:
		say.call("nothing to export")
		return
	if _model_3d == null:
		_model_3d = ConfirmationDialog.new()
		_model_3d.title = "Export a 3D model"
		_model_3d.ok_button_text = "Export"
		var asking := VBoxContainer.new()
		var words := Label.new()
		words.text = "The model as a 3D file, at its real size, for Blender or another 3D program, AR, or a 3D printer."
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# A wrapping label with no width of its own is a word a line until it
		# is laid out, and the dialog took the window's whole height from it.
		words.custom_minimum_size = Vector2(440, 0)
		asking.add_child(words)
		_format_choice = OptionButton.new()
		for format: String in MeshExport.FORMATS:
			_format_choice.add_item(MeshExport.NAMES[format])
		_format_choice.item_selected.connect(func(_index: int) -> void: _describe_format())
		asking.add_child(_format_choice)
		_format_note = Label.new()
		_format_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_format_note.custom_minimum_size = Vector2(440, 0)
		_format_note.add_theme_font_size_override("font_size", 12)
		_format_note.modulate = Color(1, 1, 1, 0.75)
		asking.add_child(_format_note)
		_model_3d.add_child(asking)
		_model_3d.confirmed.connect(func() -> void:
			_format = MeshExport.FORMATS[_format_choice.selected]
			model_3d(_format, true))
		add_child(_model_3d)
	_format_choice.select(maxi(MeshExport.FORMATS.find(_format), 0))
	_describe_format()
	_model_3d.popup_centered()
	_model_3d.get_ok_button().grab_focus()


var _model_3d: ConfirmationDialog
var _format_choice: OptionButton
var _format_note: Label
var _format: String = "glb"
## A 3D model is being written; one at a time.
static var _writing: bool = false


## What the chosen format is for, and whether this model fits in it: OBJ and
## STL write every triangle and are capped (MeshExport.most_triangles).
func _describe_format() -> void:
	var format: String = MeshExport.FORMATS[_format_choice.selected]
	var maker: MeshExport = _mesh_export()
	var refused: String = maker.refusal(format)
	var cap: String = ""
	if MeshExport.most_triangles.has(format):
		cap = " Up to %s triangles; this model is %s." % [
			Working.comma(int(MeshExport.most_triangles[format])),
			Working.comma(maker.triangles_in(maker.bricks()))]
	var note: String = {
		"glb": "Every part a node, in its sub-model, and each shape kept once, so any model fits. In metres. Opens in Blender, three.js and AR viewers.",
		"gltf": "The same as GLB, written as text with its data inside.",
		"obj": "Every part with its own triangles, and an .mtl of its colours. In metres." + cap,
		"stl": "One mesh of every part, in millimetres, standing on Z, for a slicer." + cap,
	}[format]
	if not refused.is_empty():
		note = refused.left(1).to_upper() + refused.substr(1) + "."
	_format_note.text = note
	_model_3d.get_ok_button().disabled = not refused.is_empty()
	# As tall as what it now says.
	_model_3d.reset_size()


func _mesh_export() -> MeshExport:
	var maker := MeshExport.new()
	maker.world = world
	maker.library = library
	maker.scenery = scenery
	return maker


## The model as a 3D file (MeshExport): glb, gltf, obj or stl. Downloaded in a
## browser, where an OBJ and its MTL come as one zip; on the desktop written
## where the person chose, an OBJ's MTL beside it, or to Downloads. What was
## written, or why not: the dialog, and a session over MCP (AppTools).
func model_3d(format: String, asking: bool = false) -> String:
	if _writing:
		say.call("already writing a 3D model")
		return "already writing a 3D model"
	var maker: MeshExport = _mesh_export()
	var refused: String = maker.refusal(format)
	if not refused.is_empty():
		say.call(refused)
		return refused
	var title: String = str(named.call())
	var to: String = await _where(MeshExport._file_base(title) + "." + format, asking)
	if to.is_empty():
		return ""
	_writing = true
	var job: Working.Job = Working.begin("Writing the model as %s…" % format.to_upper(), 0, true)
	maker.job = job
	await job.shown()
	var made: MeshExport.Made = await maker.write(format, title, to.get_file().get_basename())
	var line: String
	if made.cancelled:
		line = "stopped writing the 3D model"
	elif not made.refused.is_empty():
		line = made.refused
	else:
		job.can_cancel = false
		job.count(0, 0)
		var files: Array = made.files
		if OS.has_feature("web") and files.size() > 1:
			job.say("Packing the OBJ and its colours…")
			files = [[str(files[0][0]).get_basename() + "_obj.zip",
				await maker.zip(files), MeshExport.MIME["zip"]]]
		job.say("Saving %s…" % str(files[0][0]))
		await job.shown()
		var said: PackedStringArray = []
		for file: Array in files:
			said.append(_give_bytes(file[1], file[0], file[2], to.get_base_dir()))
		line = " and ".join(said)
		line += " — %s parts" % Working.comma(made.parts)
		if made.shapes > 0:
			line += ", %d shapes kept once (%s triangles)" % [made.shapes,
				Working.comma(made.triangles)]
		else:
			line += ", %s triangles" % Working.comma(made.triangles)
		if not made.left_out.is_empty():
			var count: int = 0
			for id: String in made.left_out:
				count += int(made.left_out[id])
			line += " — %d left out, with no shape here yet (%s)" % [count,
				ModelStore.named_counts(made.left_out)]
	job.end()
	_writing = false
	say.call(line)
	return line


func _file(extension: String, suffix: String = "") -> String:
	var base: String = str(named.call()).to_snake_case()
	if base.is_empty():
		base = "model"
	return "%s%s.%s" % [base, suffix, extension]


## Where [param file_name] goes: on the desktop the path the person chose
## when [param asking] ("" when they cancelled), else [member folder] or
## Downloads; in a browser, its name alone.
func _where(file_name: String, asking: bool) -> String:
	if OS.has_feature("web"):
		return file_name
	if asking:
		return await SaveTo.ask(file_name, folder)
	return (folder if not folder.is_empty() else Download.downloads()).path_join(
		file_name.replace("\\", "/").get_file())


## Downloaded in a browser, written into [param into] (or Downloads) on the
## desktop.
static func _give(text: String, file_name: String, mime: String,
		into: String = "") -> String:
	return _give_bytes(text.to_utf8_buffer(), file_name, mime, into)


static func _give_bytes(bytes: PackedByteArray, file_name: String, mime: String,
		into: String = "") -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, file_name, mime)
		return "downloaded %s" % file_name
	var to: String = into if not into.is_empty() else Download.downloads()
	var path: String = to.path_join(file_name.replace("\\", "/").get_file())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % file_name
	file.store_buffer(bytes)
	file.close()
	SaveTo.wrote(path)
	return "wrote %s" % path
