## What Export writes besides the LDraw file: a picture of the model, its
## parts list for BrickLink or Rebrickable, the model as a BrickLink Studio
## file, and the model as a 3D file. See [Picture], [ShopLists], [StudioIo],
## [MeshExport].
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
## points it at a folder of its own.
var folder: String = ""

var picture: Picture


func _ready() -> void:
	picture = Picture.new()
	add_child(picture)


func take_picture() -> String:
	if world.brick_count() - scenery.size() <= 0:
		say.call("nothing to take a picture of")
		return ""
	if not Picture.possible():
		say.call("no picture: a run with no window draws nothing")
		return ""
	say.call("taking the picture…")
	var image: Image = await picture.take()
	if image == null:
		say.call("nothing to take a picture of")
		return ""
	var line: String = Picture.keep(image, _file("png"), folder)
	say.call(line)
	return line


func shop_list(shop: String) -> String:
	var stock: Inventory = Inventory.of(world, library, scenery)
	if stock.lots.is_empty():
		say.call("nothing to list yet")
		return ""
	var made: Dictionary
	var file_name: String
	var mime: String
	if shop == "bricklink":
		made = ShopLists.bricklink_xml(stock, library)
		file_name = _file("xml", "_bricklink")
		mime = "application/xml"
	else:
		made = ShopLists.rebrickable_csv(stock)
		file_name = _file("csv", "_rebrickable")
		mime = "text/csv"
	var line: String = _give(str(made["text"]), file_name, mime, folder)
	if int(made["left_out"]) > 0:
		line += " — %d of %d lots left off: %s" % [int(made["left_out"]), stock.lots.size(),
			ShopLists.why_left_off(made, shop)]
	say.call(line)
	return line


## The model as a BrickLink Studio file (.io): its LDraw, with the build
## order, and a picture of it, in a zip. See [StudioIo].
func studio_io() -> String:
	if store == null or world.brick_count() - scenery.size() <= 0:
		say.call("nothing to export")
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
	var bytes: PackedByteArray = StudioIo.pack(text, thumbnail, ModelStore.count_in(text))
	var line: String = _give_bytes(bytes, _file("io"), "application/octet-stream", folder)
	say.call(line)
	return line


## Every saved model in one .zip, each the .ldr it is kept as: File, Export,
## All my models, and the warning shown where a browser may clear them
## (StorageOffer). On the web a person's models are in the browser and
## nowhere else, and this is a copy of their own that outlives it.
func all_models() -> String:
	var members: Array = []
	for entry: ModelStore.Entry in store.list_saved():
		members.append([entry.path.get_file(), FileAccess.get_file_as_bytes(entry.path)])
	if members.is_empty():
		say.call("no saved models to download yet")
		return ""
	var line: String = _give_bytes(StudioIo.zip(members),
		"brickworks_models_%s.zip" % Time.get_date_string_from_system(), "application/zip", folder)
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
			model_3d(_format))
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
## browser, where an OBJ and its MTL come as one zip; written to Downloads
## on the desktop. What was written, or why not: the dialog, and a session
## over MCP (AppTools).
func model_3d(format: String) -> String:
	if _writing:
		say.call("already writing a 3D model")
		return "already writing a 3D model"
	var maker: MeshExport = _mesh_export()
	var refused: String = maker.refusal(format)
	if not refused.is_empty():
		say.call(refused)
		return refused
	_writing = true
	var job: Working.Job = Working.begin("Writing the model as %s…" % format.to_upper(), 0, true)
	maker.job = job
	await job.shown()
	var made: MeshExport.Made = await maker.write(format, str(named.call()))
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
			said.append(_give_bytes(file[1], file[0], file[2], folder))
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


## Downloaded in a browser, written to Downloads on the desktop.
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
	return "wrote %s" % path
