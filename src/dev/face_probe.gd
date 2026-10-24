## A face is laid onto a shaped head as a set lays one: a round plate disc on
## real side studs, flush with the curve, with 2 x 2 eyes and a beak on it.
##
##   godot --headless --path . --script src/dev/face_probe.gd [-- OUTDIR]
##
## owl_d4, the last held-out owl, built its features as parts but its face
## was still a flat panel of white tiles on the shape's shell, and its eyes
## 1 x 1: a 2 x 2 round plate wants four studs facing out where the shell
## offers tiles. A shape's "face" leaves the face's square out of the shell,
## and lays it on the side-stud bricks the core already has behind it. Each
## head here is laid with a face and checked as a design is: one piece, held,
## the disc and both eyes 2 x 2 and studs out, and the face no deeper in the
## head than the curve round it. With OUTDIR each is saved as face_<name>.ldr.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary

## The held-out owl's post and body (shapes_probe's OWL_POST and OWL_BODY),
## with a face said on its white facial disc.
const OWL_POST: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "top": "smooth",
	"solids": [{"box": {"from": [6, 0, 5], "size": [8, 20, 6], "edge": 1, "round": 1}, "color": 72}]}
const OWL_BODY: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "solids": [
	{"ellipsoid": {"centre": [10, 35, 7.5], "radii": [5, 15, 4.5]}, "color": 15},
	{"loft": {"along": "z", "centre": 10, "sections": [
		{"at": 1, "width": 5, "height": 3, "bottom": 20, "round": 0.6},
		{"at": 4, "width": 7, "height": 8, "bottom": 23, "round": 0.8},
		{"at": 6, "width": 6, "height": 6, "bottom": 30, "round": 0.8}]}, "color": 84},
	{"ellipsoid": {"centre": [5.8, 35, 6.5], "radii": [1.6, 14, 4.2]}, "color": 84},
	{"ellipsoid": {"centre": [14.2, 35, 6.5], "radii": [1.6, 14, 4.2]}, "color": 84},
	{"ellipsoid": {"centre": [10, 54, 7.5], "radii": [4.5, 11, 4]}, "color": 84},
	{"ellipsoid": {"centre": [10, 53, 9.5], "radii": [3.8, 9, 2.2]}, "color": 15}]}

## Heads, each with the face said on it: [name, the shape, its face]. The
## cat's nose in bright pink (29), as 54200 is made: in pink (13), which it
## never was, it has been put in the nearest colour it was since 101c4e40
## (2026-10-24), and no nose of its colour was found.
const HEADS: Array = [
	["owl", "owl", {"facing": "+z", "x": 10, "y": 53, "z": 11, "across": 6, "color": 15,
		"rim": 84, "eyes": 0, "beak": 19}],
	["cat", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 25, "solids": [
		{"ellipsoid": {"centre": [6, 12, 6], "radii": [5, 12, 5]}}]},
		{"facing": "+z", "x": 6, "y": 13, "z": 11, "across": 4, "color": 15, "eyes": 2,
			"beak": 29}],
	["big owl", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 84, "solids": [
		{"ellipsoid": {"centre": [8, 15, 8], "radii": [7, 15, 7]}}]},
		{"facing": "+z", "x": 8, "y": 17, "z": 15, "across": 8, "color": 15, "eyes": 0,
			"beak": 19}],
	["bear facing -x", {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 70, "solids": [
		{"ellipsoid": {"centre": [7, 11, 7], "radii": [6, 11, 6]}}]},
		{"facing": "-x", "x": 1, "y": 12, "z": 7, "across": 6, "color": 19, "eyes": 0,
			"beak": 0}],
]


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var out_dir: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	var assistant := Assistant.new()
	assistant.library = _library
	assistant.world = world
	assistant.builder = builder
	get_root().add_child(assistant)
	var store := ModelStore.new()
	store.world = world
	store.library = _library
	store.builder = builder
	store.keeps = false
	await process_frame

	for head: Array in HEADS:
		var name: String = head[0]
		print("")
		print("  a %s's head, with a face said on it" % name)
		var shape: Dictionary = (OWL_BODY if head[1] is String else head[1] as Dictionary).duplicate(true)
		shape["face"] = head[2]
		var patterns: Array = [OWL_POST, shape] if name == "owl" else [shape]
		assistant._brief = "a %s" % name
		var model: Assistant.Model = assistant._read_model({"name": name, "patterns": patterns})
		_check("laid without trouble: %s" % str(assistant._pattern_trouble),
			assistant._pattern_trouble.is_empty())
		print("    %s" % str(Shapes.last.get("faces", [])))
		print("    %s" % str(Shapes.last.get("shells_kept", [])))
		var verdict: Dictionary = assistant._check(model, true)
		if not bool(verdict["ok"]):
			print("    %s" % str(verdict["feedback"]).substr(0, 1500))
		_check("passes the check in one piece: %s, %d pieces" % [verdict["summary"],
			int(verdict.get("pieces", 0))], bool(verdict["ok"]) and int(verdict.get("pieces", 0)) == 1)
		var facing: String = str((head[2] as Dictionary)["facing"])
		var across: int = int((head[2] as Dictionary)["across"])
		var disc: String = str(Shapes.FACE_DISCS[across][0])
		var found: Dictionary = {}
		var held: Dictionary = {}
		var floating: Array = verdict.get("floating", [])
		for index: int in model.placements.size():
			var placement: Assistant.Placement = model.placements[index]
			if placement.part in [disc, "18674", "98138p07", "3794b"] or (placement.part == "54200"
					and placement.color == int((head[2] as Dictionary)["beak"])):
				var key: String = "%s %s" % [placement.part, placement.face]
				found[key] = int(found.get(key, 0)) + 1
				if not floating.has(index) and placement.face == facing:
					held[placement.part] = int(held.get(placement.part, 0)) + 1
		print("    face parts: %s" % str(found))
		_check("...its disc a %d x %d round plate, studs out %s" % [across, across, facing],
			int(found.get("%s %s" % [disc, facing], 0)) == 1)
		_check("...two 2 x 2 round eyes with printed eye tiles, studs out",
			int(found.get("18674 %s" % facing, 0)) == 2
				and int(found.get("98138p07 %s" % facing, 0)) == 2)
		_check("...and a beak on a jumper", int(found.get("54200 %s" % facing, 0)) == 1
			and int(found.get("3794b %s" % facing, 0)) == 1)
		_check("...every face part held (%s)" % str(held), int(held.get(disc, 0)) == 1
			and int(held.get("18674", 0)) == 2 and int(held.get("54200", 0)) == 1)
		# The disc's other studs under tiles: none of it left bare round the
		# features, every tile held.
		var tiled: int = 0
		var tiled_held: int = 0
		var colour: int = int((head[2] as Dictionary)["color"])
		for index: int in model.placements.size():
			var placement: Assistant.Placement = model.placements[index]
			if placement.part in ["3068b", "3070b", "98138"] and placement.face == facing \
					and placement.color == colour:
				tiled += 1
				if not floating.has(index):
					tiled_held += 1
		_check("...the disc tiled round its features: %d tiles, %d held" % [tiled, tiled_held],
			tiled >= 3 and tiled == tiled_held)
		if not out_dir.is_empty():
			assistant._apply(model)
			for _n: int in 3:
				await process_frame
			var path: String = "%s/face_%s.ldr" % [out_dir, name.replace(" ", "_")]
			print("    saved %s: %s" % [path, store.export_to(path, "Model")])
			world.clear()
			builder.lattice.clear()

	print("")
	print("  a face where no side curves out is said, not dropped")
	var flat: Dictionary = {"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
		"box": {"from": [0, 0, 0], "size": [8, 15, 8]},
		"face": {"facing": "+z", "x": 4, "y": 8, "z": 8, "across": 4}}
	var trouble: Array = []
	Shapes.lay(flat, trouble, _library)
	_check("a box's flat side: %s" % str(trouble), trouble.size() == 1
		and str(trouble[0]).contains("nothing to sit on"))
	trouble = []
	Shapes.lay({"pattern": "shape", "at": {"x": 0, "y": 0, "z": 0}, "color": 4,
		"ellipsoid": {"centre": [6, 9, 6], "radii": [5, 9, 5]},
		"face": {"facing": "+y", "across": 5}}, trouble, _library)
	_check("a face said wrong is refused with what it wants: %s" % str(trouble),
		trouble.size() == 1 and str(trouble[0]).contains("+x, -x, +z or -z"))

	print("")
	if _failures == 0:
		print("OK face_probe")
	else:
		print("FAILED face_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
