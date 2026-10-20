## Choosing a 3D model to brickify: OBJ, STL, glTF, GLB, PLY, 3MF, VOX or
## FBX.
##
## The same two ways in as a model file (ModelFilePicker): the desktop's
## own file dialog, and in a browser the page's file chooser, which has to
## be asked for while the click or key that wanted it is still being
## handled. A model can come with files of its own — an OBJ's .mtl and its
## pictures, a .gltf's .bin — so in a browser several can be chosen at once,
## and on the desktop the ones it names are read from beside it, and the one
## picture beside an OBJ that names none.
class_name MeshFilePicker
extends Node

const ACCEPT := ".obj,.stl,.gltf,.glb,.ply,.3mf,.vox,.fbx,.mtl,.bin,.png,.jpg,.jpeg,.webp,.tga,.bmp"

## The model's bytes and name, and the files beside it by name.
signal picked(bytes: PackedByteArray, name: String, extras: Dictionary)
signal failed(why: String)

var _dialog: FileDialog
var _on_files: JavaScriptObject


## Ask for a file. Called straight from the press that wanted it.
func ask() -> void:
	if OS.has_feature("web"):
		_ask_browser()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.add_filter("*.obj, *.stl, *.gltf, *.glb, *.ply, *.3mf, *.vox, *.fbx",
			"3D models (OBJ, STL, glTF, PLY, 3MF, VOX, FBX)")
		_dialog.title = "Brickify a 3D model"
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(open_path)
		add_child(_dialog)
	_dialog.popup_centered()


## A model on this computer, with the files it names read from beside it.
func open_path(path: String) -> void:
	var read: Dictionary = read_path(path)
	take(read["bytes"], path.get_file(), read["extras"])


## A model's bytes on this computer and the files it names, read from beside
## it: {"bytes", "extras"}. The dialog's way in, and brickify's file=.
static func read_path(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var extras: Dictionary = {}
	var folder: PackedStringArray = DirAccess.get_files_at(path.get_base_dir()) \
		if path.get_extension().to_lower() == "obj" else PackedStringArray()
	# Twice: an OBJ names its .mtl, and only then the .mtl its pictures.
	for _round: int in 2:
		for wanted: String in MeshFile.companions(bytes, path.get_file(), extras, folder):
			# Beside it or under it, never anywhere a "../" in a file reaches.
			var beside: String = path.get_base_dir().path_join(
				wanted.replace("\\", "/")).simplify_path()
			if not beside.begins_with(path.get_base_dir().simplify_path() + "/") \
					or not FileAccess.file_exists(beside):
				continue
			extras[wanted] = FileAccess.get_file_as_bytes(beside)
	return {"bytes": bytes, "extras": extras}


func take(bytes: PackedByteArray, file_name: String, extras: Dictionary = {}) -> void:
	if bytes.is_empty():
		failed.emit("could not read that file")
		return
	if not file_name.get_extension().to_lower() in MeshFile.KINDS:
		failed.emit("%s is not a 3D model this can brickify — %s" % [file_name,
			MeshFile.NAMED])
		return
	picked.emit(bytes, file_name, extras)


func _ask_browser() -> void:
	_on_files = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickMeshFiles = _on_files
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.multiple = true;
			input.accept = '%s';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var files = Array.prototype.slice.call(input.files || []);
				document.body.removeChild(input);
				if (!files.length) { window.brickworksPickMeshFiles(''); return; }
				var read = [];
				var left = files.length;
				files.forEach(function (file, n) {
					var reader = new FileReader();
					reader.onload = function () {
						var url = String(reader.result);
						read[n] = {name: file.name, data: url.substring(url.indexOf(',') + 1)};
						if (--left === 0) window.brickworksPickMeshFiles(JSON.stringify(read));
					};
					reader.onerror = function () {
						read[n] = {name: file.name, data: ''};
						if (--left === 0) window.brickworksPickMeshFiles(JSON.stringify(read));
					};
					reader.readAsDataURL(file);
				});
			});
			input.click();
		})();
	""" % ACCEPT, true)


func _from_browser(arguments: Array) -> void:
	var said: Variant = JSON.parse_string(str(arguments[0])) if not arguments.is_empty() else null
	if not said is Array or (said as Array).is_empty():
		failed.emit("no model chosen")
		return
	var main: String = ""
	var bytes := PackedByteArray()
	var extras: Dictionary = {}
	for entry: Variant in said:
		if not entry is Dictionary:
			continue
		var name: String = str(entry.get("name", ""))
		var data: PackedByteArray = Marshalls.base64_to_raw(str(entry.get("data", "")))
		if main.is_empty() and name.get_extension().to_lower() in MeshFile.KINDS:
			main = name
			bytes = data
		else:
			extras[name] = data
	if main.is_empty():
		failed.emit("none of those is a 3D model — choose an %s" % MeshFile.NAMED)
		return
	take(bytes, main, extras)
