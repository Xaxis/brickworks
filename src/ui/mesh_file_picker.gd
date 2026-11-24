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

## What is asked for: Brickify's every kind, or fewer (a part of one's own
## takes an STL or an OBJ), with the desktop dialog's title and filter.
var accept: String = ACCEPT
var title: String = "Brickify a 3D model"
var filter: PackedStringArray = ["*.obj, *.stl, *.gltf, *.glb, *.ply, *.3mf, *.vox, *.fbx",
	"3D models (OBJ, STL, glTF, PLY, 3MF, VOX, FBX)"]
## The platform's own Open dialog on the desktop, as SaveTo's is (a probe
## turns SaveTo.native off: the portal's would open on the desktop its bus
## belongs to, not in the probe's display).
var native: bool = false
## The most the files chosen may be, together, judged from their sizes before
## a byte is read: Brickify's MeshFile.most_bytes (less in a browser), a
## part's MeshPart.MOST_BYTES. Past it the file is refused in a sentence.
## Up to moulds3 a browser read the whole file first, as base64 in JSON: a
## 100 MB STL grew the tab past 6 GB and it never answered (mouldreview2).
var most_bytes: int = MeshFile.most_bytes()

## The model's bytes and name, and the files beside it by name.
signal picked(bytes: PackedByteArray, name: String, extras: Dictionary)
signal failed(why: String)

var _dialog: FileDialog
var _on_files: JavaScriptObject
## Each choice in a browser is numbered, so a file still arriving from one
## before is let fall; and what has come of this one, by its place.
var _choice: int = 0
var _arrived: Dictionary = {}


## Ask for a file. Called straight from the press that wanted it.
func ask() -> void:
	if OS.has_feature("web"):
		_ask_browser()
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.add_filter(filter[0], filter[1])
		_dialog.title = title
		_dialog.use_native_dialog = native
		_dialog.size = Vector2i(760, 520)
		_dialog.file_selected.connect(open_path)
		# On the window, not under the Brickify panel, which waits hidden
		# until a model is chosen: a screen reader is told nothing under a
		# hidden node is there, the chooser with it (a11ymodal).
		get_window().add_child(_dialog)
	OpenFrom.ask(_dialog, "mesh")


func _exit_tree() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


## A model on this computer, with the files it names read from beside it:
## its size judged first, before it is read ([member most_bytes]).
func open_path(path: String) -> void:
	var size: int = size_of(path)
	if size > most_bytes:
		failed.emit(MeshFile.too_large(path.get_file(), size, most_bytes))
		return
	var read: Dictionary = read_path(path)
	take(read["bytes"], path.get_file(), read["extras"])


## How many bytes the file at [param path] is, read from the file system
## without reading it; 0 when it cannot be opened.
static func size_of(path: String) -> int:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return 0
	var size: int = handle.get_length()
	handle.close()
	return size


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
		failed.emit(MeshFile.refusal(file_name))
		return
	picked.emit(bytes, file_name, extras)


## The page's own chooser. The files' sizes are judged in the page, before
## one is read ([member most_bytes]); each is then read as bytes and handed
## over as they are (JavaScriptBridge.js_buffer_to_packed_byte_array), one
## call a file: no base64, no JSON, no string of it in Godot.
func _ask_browser() -> void:
	_on_files = JavaScriptBridge.create_callback(_from_browser)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		failed.emit("this build cannot open files")
		return
	window.brickworksPickMeshFile = _on_files
	_choice += 1
	_arrived = {}
	JavaScriptBridge.eval("""
		(function (choice, most) {
			var input = document.createElement('input');
			input.type = 'file';
			input.multiple = true;
			input.accept = '%s';
			input.style.display = 'none';
			document.body.appendChild(input);
			input.addEventListener('change', function () {
				var files = Array.prototype.slice.call(input.files || []);
				document.body.removeChild(input);
				var say = window.brickworksPickMeshFile;
				if (!files.length) { say(choice, '', -2, 0, null); return; }
				var total = 0;
				var biggest = files[0];
				files.forEach(function (file) {
					total += file.size;
					if (file.size > biggest.size) { biggest = file; }
				});
				if (total > most) { say(choice, biggest.name, -1, total, null); return; }
				files.forEach(function (file, n) {
					var reader = new FileReader();
					reader.onload = function () {
						say(choice, file.name, n, files.length, new Uint8Array(reader.result));
					};
					reader.onerror = function () {
						say(choice, file.name, n, files.length, new Uint8Array(0));
					};
					reader.readAsArrayBuffer(file);
				});
			});
			input.click();
		})(%d, %d);
	""" % [accept, _choice, most_bytes], true)


## One call a file of a choice: [choice, its name, its place (-1: the files
## are too large together, their size in the next; -2: none chosen), how
## many files, its bytes].
func _from_browser(arguments: Array) -> void:
	if arguments.size() < 5 or int(arguments[0]) != _choice:
		return
	var name: String = str(arguments[1])
	var place: int = int(arguments[2])
	if place == -2:
		failed.emit("no model chosen")
		return
	if place == -1:
		failed.emit(MeshFile.too_large(name, int(arguments[3]), most_bytes))
		return
	var data: Variant = arguments[4]
	_arrived[place] = [name, JavaScriptBridge.js_buffer_to_packed_byte_array(data)
		if data is JavaScriptObject else PackedByteArray()]
	if _arrived.size() < int(arguments[3]):
		return
	var main: String = ""
	var bytes := PackedByteArray()
	var extras: Dictionary = {}
	var places: Array = _arrived.keys()
	places.sort()
	for n: Variant in places:
		var one: Array = _arrived[n]
		if main.is_empty() and str(one[0]).get_extension().to_lower() in MeshFile.KINDS:
			main = str(one[0])
			bytes = one[1]
		else:
			extras[str(one[0])] = one[1]
	_arrived = {}
	if main.is_empty():
		failed.emit(MeshFile.refusal(str(extras.keys()[0])) if extras.size() == 1
			else "none of those is a 3D model — choose an %s" % MeshFile.NAMED)
		return
	take(bytes, main, extras)
