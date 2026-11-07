## A line that places a part at no size places nothing, and the file keeps it.
##
##   godot --headless --path . --script src/dev/no_size_probe.gd
##
## Studio and LDCad write a matrix with a row or a column of zeros where a
## flexible part's path doubles back: 653 lines in 7 of vendor/omr's sets,
## each drawing nothing of its part. Read as parts, there was no inverse of
## where they stood, and Mechanism takes one of every part to read what rests
## on studs (_rest_on_studs): grab_probe logged 15 to 20 'det == 0' engine
## errors from 42125-1 alone (APP_UX6 #23, unit mechdet).
##
## The sets are read as an open reads them: no placement without size, the
## lines counted from the text itself, every other part read as before. Then
## 42125-1 opened as a file is: every part on the baseplate has an inverse,
## its gears read (Mechanism.build, as a grab reads them), and a save writes
## each of its four such lines back byte for byte. And a part's state sent by
## a session's other side at no size is no part (Together._as_state).
extends SceneTree

const OMR := "res://vendor/omr/files/"
## The sets with such lines, and how many each has.
const SETS: Dictionary = {
	"42125-1.mpd": 4, "42108-1.mpd": 639, "42082-1.mpd": 4, "42114-1.mpd": 3,
	"42120-1.mpd": 1, "6285-1.mpd": 1, "75253-1.mpd": 1,
}
## Under this, a part's turn has no size: those sets place every other part
## at a thousandth of its volume or more.
const NO_SIZE := 0.000001

var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _failures: int = 0
var _passed: int = 0


func _initialize() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("FAIL: no catalogue")
		quit(1)
		return
	CustomParts.keeps = false
	_run.call_deferred()


func _run() -> void:
	for file_name: String in SETS:
		if not FileAccess.file_exists(OMR + file_name):
			print("SKIPPED: no %s (tools/omr.py fetch brings the sets)" % file_name)
			quit(3)
			return
	_read_sets()
	_world = BrickWorld.new()
	_world.library = _library
	get_root().add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	get_root().add_child(_builder)
	_store = ModelStore.new()
	_store.world = _world
	_store.library = _library
	_store.builder = _builder
	_store.keeps = false
	await process_frame
	_opened("42125-1.mpd")
	_sent()
	print("")
	if _failures == 0:
		print("no size: %d checks passed: a line placing a part at no size places nothing, " % _passed
			+ "the file keeps it, and a session's other side cannot send one")
	else:
		print("no size: %d FAILED, %d passed" % [_failures, _passed])
	quit(1 if _failures > 0 else 0)


## Each set read as an open reads it: no placement without size, and as many
## placements as the file has lines with size.
func _read_sets() -> void:
	print("\nthe sets read")
	var lines_total: int = 0
	var placed_total: int = 0
	var shapeless_total: int = 0
	for file_name: String in SETS:
		var text: String = FileAccess.get_file_as_string(OMR + file_name)
		var counted: Array = _lines_without_size(text)
		var model: LdrModel = LdrModel.parse(text, file_name.get_basename())
		var read: int = 0
		var shapeless: int = 0
		for submodel: LdrModel.SubModel in model.submodels.values():
			for placement: LdrModel.Placement in submodel.placements:
				read += 1
				if absf(placement.transform.basis.determinant()) <= NO_SIZE:
					shapeless += 1
		var placed: Array = model.flatten(_library.parts)
		var flat_shapeless: int = placed.filter(func(p: LdrModel.Placement) -> bool:
			return absf(p.transform.basis.determinant()) <= NO_SIZE).size()
		print("  %s: %d lines at no size in its text, %d read as placements (of %d), %d placed (of %d)"
			% [file_name, counted.size(), shapeless, read, flat_shapeless, placed.size()])
		_check(counted.size() == int(SETS[file_name]),
			"%s has %d lines at no size, as counted from its text: %d" % [file_name, SETS[file_name], counted.size()])
		lines_total += counted.size()
		shapeless_total += shapeless
		placed_total += flat_shapeless
	_check(shapeless_total == 0 and placed_total == 0,
		"none of the %d lines at no size is read as a placement: %d read, %d placed"
		% [lines_total, shapeless_total, placed_total])


## 42125-1 opened as a file is: its parts each with an inverse, its gears
## read, and its lines at no size written back as they were.
func _opened(file_name: String) -> void:
	print("\n%s opened" % file_name)
	var text: String = FileAccess.get_file_as_string(OMR + file_name)
	var opened: Dictionary = _store.open_text(text, file_name.get_basename())
	var bricks: Array = _world.bricks()
	var shapeless: int = 0
	var unturned: int = 0
	var list: Array = []
	for brick: BrickWorld.Brick in bricks:
		var at: Transform3D = brick.transform
		if absf(at.basis.determinant()) <= NO_SIZE:
			shapeless += 1
			continue
		if not (at * at.affine_inverse()).is_equal_approx(Transform3D.IDENTITY):
			unturned += 1
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh != null:
			list.append({"key": brick.id, "part": brick.part_id, "at": at, "mesh": mesh})
	print("  %d parts placed, %d bricks, %d with meshes" % [int(opened.get("placed", 0)), bricks.size(), list.size()])
	_check(not bricks.is_empty() and shapeless == 0,
		"every part on the baseplate has size: %d of %d without" % [shapeless, bricks.size()])
	_check(unturned == 0, "every part's place has an inverse: %d without" % unturned)
	# Read as a grab reads them (GrabDrag._read_all): an inverse taken of
	# every part standing on studs (Mechanism._rest_on_studs).
	var mechanism: Mechanism = Mechanism.build(list)
	print("  its gears: %d bodies, %d joints, %d gears" % [mechanism.bodies.size(), mechanism.joints.size(),
		mechanism.gears.size()])
	_check(mechanism.bodies.size() > 1 and not mechanism.joints.is_empty(),
		"its mechanism is read: %d bodies, %d joints" % [mechanism.bodies.size(), mechanism.joints.size()])
	var saved: String = _store.to_text(file_name.get_basename()).replace("\r\n", "\n")
	var kept: int = 0
	var lines: Array = _lines_without_size(text)
	for line: String in lines:
		if saved.contains("\n" + line + "\n"):
			kept += 1
	_check(not lines.is_empty() and kept == lines.size(),
		"a save writes each line at no size back as it was: %d of %d" % [kept, lines.size()])


## A part's state at no size from a session's other side is no part; the same
## part turned as parts are is.
func _sent() -> void:
	print("\nsent by the other side")
	var flat: Array = ["77", 16, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.999426, 0.0, 10.25, 0.0],
		"", "", 0]
	var turned: Array = ["77", 16, [1.0, 0.0, 0.0, 0.0, 0.999426, 0.0, 0.0, 0.0, 1.0, 0.0, 10.25, 0.0],
		"", "", 0]
	_check(Together._as_state(flat) == null, "a part's state at no size is refused")
	_check(Together._as_state(turned) != null, "the same part's state turned as parts are is taken")


## The type-1 lines of [param text] whose matrix has no size, as written,
## worked out from its own numbers.
static func _lines_without_size(text: String) -> Array:
	var out: Array = []
	for raw: String in text.replace("\r\n", "\n").split("\n"):
		var words: PackedStringArray = raw.strip_edges().split(" ", false)
		if words.size() < 15 or words[0] != "1":
			continue
		var m: Array = []
		for k: int in range(5, 14):
			m.append(words[k].to_float())
		var det: float = m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) \
			+ m[2] * (m[3] * m[7] - m[4] * m[6])
		if absf(det) <= NO_SIZE:
			out.append(raw)
	return out


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ok    ", what)
	else:
		_failures += 1
		print("  FAIL  ", what)
