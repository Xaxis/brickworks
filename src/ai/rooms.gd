## Floors and furnished rooms inside a building that already stands, in
## one call.
##
## Twelve Orthancs were built here and every one was a solid shell or a
## bare open back. The twelfth came to 46 different shapes and six colours,
## where a real fantasy set has a median of 109 and 23, and real sets get
## that variety from their interiors: LEGO's 10237 Tower of Orthanc opens at
## the back onto a library, Saruman's chamber, a dungeon and the room of the
## palantír, and its furniture, books, lamps and figures are most of its
## one-off pieces. The guidance has asked for rooms in words since run 10,
## and no run built one. The runs say a technique is taken up when it is
## one call shaped like the work — the finishing pass, a figure — and not
## when it is described.
##
## An edit of what stands, not a pattern: the measurement that says variety
## is thin arrives once the model is built, when a design is told never to
## submit again, and restyle_model and add_minifig — the two calls made on
## what stands — are the two the runs took up unprompted. Reading the shell
## off the lattice also means it can be anything: a prism, a fill with a
## wall, or a shaft laid brick by brick, as run 12's was.
##
## Each floor is a layer of plates and tiles over them laid across the
## joints, held up by columns on the floor below; a stair climbs to the next
## floor where asked; each room is furnished from the worked examples real
## sets built (Techniques), turned to stand against a wall and face into the
## room, chosen and coloured by its kind and a seed, so two libraries are two
## libraries. Every part is tried against the live lattice and against what
## this has laid before it, with the boxes the check uses, so what comes out
## is on the lattice and never in the shell.
class_name Rooms
extends RefCounted

## Lattice cells a stud across and a plate up (BrickLattice).
const ACROSS := 10
const UP := 4
## A storey when none is said: the bookcase LEGO built for 10270 is 23
## plates tall, the floor it stands on two more, and a plate to spare.
const STOREY := 26
## The lowest a storey may be and still be a room: a minifigure is 12
## plates with a hat.
const LOWEST := 15
## The fewest studs worth calling a room.
const SMALLEST := 12
## How far to look for a wall, in studs.
const REACH := 40
## The most floors one call lays.
const MOST_FLOORS := 12

## The four ways along the ground, in the order a quarter turn about +y
## walks them: +z, +x, -z, -x.
const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0),
	Vector2i(0, -1), Vector2i(-1, 0)]
const DIR_NAMES: Array[String] = ["+z", "+x", "-z", "-x"]
## Which picture shows a room open that way.
const VIEWS: Dictionary = {"+z": "front", "-z": "back", "+x": "right", "-x": "left"}

## What each kind of room is: its floor (boards, flags, checker), the tones
## of it, what holds the floor above (timber or stone), and what it is
## furnished with, its signature first.
const KINDS: Dictionary = {
	"library": {"floor": "boards", "tones": [70, 308], "column": "timber",
		"items": ["bookcase", "bookcase", "table", "armchair", "candles",
			"bookcase", "chest", "globe"]},
	"study": {"floor": "boards", "tones": [308, 70], "column": "timber",
		"items": ["bookcase", "potion shelf", "table", "armchair", "globe",
			"candles", "chest", "dresser"]},
	"bedchamber": {"floor": "boards", "tones": [70, 19], "column": "timber",
		"items": ["four-poster bed", "chest", "bedside lamp", "dresser",
			"armchair", "bed", "candles"]},
	"hall": {"floor": "checker", "tones": [72, 71], "column": "stone",
		"items": ["fireplace", "table", "bench", "armchair", "wall lantern",
			"barrels", "sofa"]},
	"throne room": {"floor": "checker", "tones": [0, 72], "carpet": 320,
		"column": "stone", "items": ["throne", "wall lantern", "candles",
			"wall lantern", "chest", "armchair"]},
	"forge": {"floor": "flags", "tones": [72, 0, 71], "column": "stone",
		"items": ["hearth", "anvil", "log pile", "campfire", "barrels",
			"crates", "chest"]},
	"armoury": {"floor": "flags", "tones": [71, 72], "column": "stone",
		"items": ["chest", "barrels", "anvil", "crates", "table", "chest",
			"wall lantern"]},
	"dungeon": {"floor": "flags", "tones": [72, 71, 0], "column": "stone",
		"items": ["skeleton", "chest", "campfire", "barrels", "crates",
			"log pile", "wall lantern"]},
	"kitchen": {"floor": "flags", "tones": [19, 28, 84], "column": "timber",
		"items": ["hearth", "table", "dresser", "barrels", "log pile",
			"potion shelf", "crates", "campfire"]},
	"lookout": {"floor": "flags", "tones": [71, 19], "column": "stone",
		"items": ["telescope", "bench", "chest", "wall lantern", "table",
			"barrels"]},
	"palantir room": {"floor": "checker", "tones": [0, 320], "column": "stone",
		"items": ["palantir", "armchair", "bookcase", "candles",
			"wall lantern", "chest"]},
	"stair": {"floor": "flags", "tones": [72, 71], "column": "stone",
		"items": ["candles", "wall lantern", "barrels", "crates"]},
}

## The words a design uses for a room, to the kind it is. Read as words of
## what was said, so "Saruman's chamber" is a study and "the great hall" a
## hall — whole words (SubjectWords), so a room on the top storey is not a
## store, nor the inner keep an inn.
const SAID: Array = [
	[["palantir", "seeing stone"], "palantir room"],
	[["throne"], "throne room"],
	[["library", "librarian", "book", "archive", "scriptorium"], "library"],
	[["study", "chamber", "office", "wizard", "solar", "alchemist", "alchemy",
		"laboratory", "lab"], "study"],
	[["bed", "bedroom", "sleep", "sleeping", "dormitory", "barrack", "quarters"],
		"bedchamber"],
	[["forge", "smith", "smithy", "blacksmith", "workshop", "foundry"], "forge"],
	[["armour", "armor", "armoury", "armory", "weapon", "treasure", "treasury", "vault",
		"store", "storeroom"], "armoury"],
	[["dungeon", "cell", "prison", "gaol", "jail", "crypt", "cellar", "pit"], "dungeon"],
	[["kitchen", "cook", "pantry", "larder", "scullery", "brewery", "brewhouse"], "kitchen"],
	[["lookout", "watch", "watchtower", "observatory", "platform", "top", "summit",
		"belfry"], "lookout"],
	[["stair", "staircase", "stairwell", "landing", "entrance", "vestibule", "lobby"],
		"stair"],
	[["hall", "dining", "feast", "great", "common", "tavern", "inn"], "hall"],
]

## The furniture, by name. "technique" is a worked example LEGO built in a
## real set (Techniques), used as it stands; "bricks" is one put together
## here of parts real castle sets furnish with. "front" is the side it is
## used from, in its own frame, which is turned to face into the room;
## "wall" is whether it stands against one. "tones" swaps a colour for one
## of a few, chosen by the seed, so the same piece is not the same piece
## twice.
const FURNITURE: Dictionary = {
	"bookcase": {"technique": "bookcase", "front": "+z", "wall": true,
		"tones": {378: [378, 320, 1, 72], 84: [84, 25, 19, 15],
			1: [1, 272, 4, 2], 4: [4, 320, 14, 1], 272: [272, 1, 288, 320],
			25: [25, 191, 14, 4], 3: [3, 2, 378, 1]}},
	"fireplace": {"technique": "fireplace", "front": "+z", "wall": true,
		"tones": {71: [71, 72], 2: [72, 0, 28]}},
	"hearth": {"technique": "hearth", "front": "+z", "wall": true},
	"anvil": {"technique": "anvil", "front": "+x", "wall": false},
	"chest": {"technique": "chest", "front": "+z", "wall": true,
		"tones": {30: [70, 320, 288], 27: [0, 71, 308]}},
	"potion shelf": {"technique": "potion shelf", "front": "+z", "wall": true,
		"tones": {33: [33, 36, 46], 34: [34, 42, 36], 47: [47, 33, 34]}},
	"dresser": {"technique": "dresser", "front": "+x", "wall": true,
		"tones": {70: [70, 28, 19]}},
	"sofa": {"technique": "sofa", "front": "+z", "wall": true,
		"tones": {320: [320, 378, 19, 72]}},
	# Its feet are its front posts and two headlight bricks on their sides,
	# all along its foot, which take no stud: on the ground the ground held
	# it, and on a floor it tipped back off them. Two plates under its
	# frame's middle give it a footing there, hidden under the bed.
	"four-poster bed": {"technique": "four-poster bed", "front": "+x",
		"wall": true, "tones": {191: [191, 320, 272, 378, 1]}, "footing": [
		{"part": "3021", "color": 70, "x": 2.5, "y": 0, "z": 1, "rot": 0},
		{"part": "3021", "color": 70, "x": 2.5, "y": 1, "z": 1, "rot": 0},
	]},
	"bed": {"technique": "bed", "front": "+z", "wall": true,
		"tones": {320: [320, 272, 288, 1]}},
	"log pile": {"technique": "log pile", "front": "-x", "wall": true},
	"table": {"technique": "table", "front": "+x", "wall": false},
	"bench": {"technique": "bench", "front": "+z", "wall": true},
	"armchair": {"technique": "armchair", "front": "+x", "wall": true,
		"tones": {70: [70, 320, 272, 288]}},
	"wall lantern": {"technique": "wall lantern", "front": "+z", "wall": true},
	"bedside lamp": {"technique": "bedside lamp", "front": "+z", "wall": true,
		"tones": {15: [15, 19, 70]}},
	"campfire": {"technique": "campfire", "wall": false},
	"barrels": {"wall": true, "tones": {70: [70, 308, 19]}, "bricks": [
		{"part": "2489", "color": 70, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "2489", "color": 70, "x": 2, "y": 0, "z": 0, "rot": 0},
		{"part": "2489", "color": 308, "x": 0, "y": 0, "z": 2, "rot": 0},
	]},
	"crates": {"wall": true, "tones": {70: [70, 72, 0], 84: [84, 71]}, "bricks": [
		{"part": "61780", "color": 70, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "35700", "color": 84, "x": 2, "y": 0, "z": 0, "rot": 0},
	]},
	"candles": {"wall": true, "tones": {15: [15, 19]}, "bricks": [
		{"part": "4032a", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3062b", "color": 15, "x": 0, "y": 1, "z": 0, "rot": 0},
		{"part": "3062b", "color": 15, "x": 1, "y": 1, "z": 1, "rot": 0},
		{"part": "3062b", "color": 15, "x": 1, "y": 4, "z": 1, "rot": 0},
		{"part": "6141", "color": 46, "x": 0, "y": 4, "z": 0, "rot": 0},
		{"part": "6141", "color": 46, "x": 1, "y": 7, "z": 1, "rot": 0},
	]},
	"globe": {"wall": true, "tones": {41: [41, 43, 47]}, "bricks": [
		{"part": "3941", "color": 70, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "30106", "color": 41, "x": 0, "y": 3, "z": 0, "rot": 0},
	]},
	"palantir": {"wall": false, "tones": {72: [72, 0]}, "bricks": [
		{"part": "3941", "color": 72, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3941", "color": 0, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "20953", "color": 0, "x": 0, "y": 6, "z": 0, "rot": 0},
	]},
	"telescope": {"wall": true, "bricks": [
		{"part": "3062b", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3062b", "color": 0, "x": 0, "y": 3, "z": 0, "rot": 0},
		{"part": "64644", "color": 297, "x": 0.1, "y": 6, "z": 0.1, "rot": 0},
	]},
	"skeleton": {"front": "+z", "wall": true, "bricks": [
		{"part": "6260c01", "color": 15, "x": 0, "y": 0, "z": 0, "rot": 0},
	]},
	"throne": {"front": "+z", "wall": true, "tones": {320: [320, 272, 288]},
		"bricks": [
		{"part": "3031", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0},
		{"part": "3020", "color": 0, "x": 0, "y": 1, "z": 0, "rot": 0},
		{"part": "3068b", "color": 320, "x": 0, "y": 1, "z": 2, "rot": 0},
		{"part": "3068b", "color": 320, "x": 2, "y": 1, "z": 2, "rot": 0},
		{"part": "3062b", "color": 0, "x": 0, "y": 2, "z": 0, "rot": 0},
		{"part": "3062b", "color": 0, "x": 3, "y": 2, "z": 0, "rot": 0},
		{"part": "3062b", "color": 0, "x": 0, "y": 5, "z": 0, "rot": 0},
		{"part": "3062b", "color": 0, "x": 3, "y": 5, "z": 0, "rot": 0},
		{"part": "4589", "color": 297, "x": 0, "y": 8, "z": 0, "rot": 0},
		{"part": "4589", "color": 297, "x": 3, "y": 8, "z": 0, "rot": 0},
		# Its back hangs a quarter stud behind its base, so its corner is that
		# far behind the plate's. At the plate's corner its base was a quarter
		# stud off the studs: against a wall the check could not move it onto
		# them, and it stood 2 LDU into two of them by its real shape.
		{"part": "4079", "color": 320, "x": 1, "y": 2, "z": -0.25, "rot": 0},
	]},
}

## What holds a floor up, by the room under it: a stone column is round
## 1 x 1 bricks on a round plate (as 4954 builds one), a timber one the same
## in reddish brown with a tan cap (as 10182 Cafe Corner turns its posts).
const COLUMNS: Dictionary = {
	"stone": {"shaft": "3062b", "plate": "6141", "colour": 71, "cap": 72},
	"timber": {"shaft": "3062b", "plate": "6141", "colour": 70, "cap": 19},
}

## Plates for the layer that holds a floor, two studs wide and laid along
## z: [studs long, part, quarter turns]. Then one stud wide, for an edge.
## As long as they come, so a strip across a room is one plate and has no
## joint for the floor to part along; a 1 x 2 across for a last stud.
const PLATES_TWO: Array = [[16, "4282", 1], [14, "91988", 1], [12, "2445", 1],
	[10, "3832", 1], [8, "3034", 1], [6, "3795", 1], [4, "3020", 1],
	[3, "3021", 1], [2, "3022", 0], [1, "3023", 0]]
const PLATES_ONE: Array = [[8, "3460", 1], [6, "3666", 1], [4, "3710", 1],
	[3, "3623", 1], [2, "3023", 1], [1, "3024", 0]]
## Tiles for the floor itself, laid along x: boards one stud wide, flags two.
const BOARDS: Array = [[6, "6636", 0], [4, "2431", 0], [3, "63864", 0],
	[2, "3069b", 0], [1, "3070b", 0]]
## The same as plates, for the studs something stands on.
const BOARD_PLATES: Array = [[6, "3666", 0], [4, "3710", 0], [3, "3623", 0],
	[2, "3023", 0], [1, "3024", 0]]
const FLAG := "3068b"

var _assistant: Assistant
var _library: PartLibrary
var _builder: Builder
var _world: BrickLattice
## What this call has laid, so nothing it lays meets anything else it laid.
var _mine := BrickLattice.new()
## Every brick laid, in order; an emptied one was taken back out.
var _laid: Array[Dictionary] = []
## Every item laid: {"name", "floor", "role", "bricks": indices into _laid,
## "cells": the studs it covers, "base": the plate it stands at}.
var _items: Array[Dictionary] = []
## The floors, bottom up: what was asked and what it came to.
var _floors: Array[Dictionary] = []
var _x0: int = 0
var _x1: int = 0
var _z0: int = 0
var _z1: int = 0
var _prism: Dictionary = {}
var _seed: int = 0
## name|turns -> {"bricks", "cells", "tall"}: an item turned and measured.
var _shapes: Dictionary = {}


func _init(assistant: Assistant) -> void:
	_assistant = assistant
	_library = assistant.library
	_builder = assistant.builder
	_world = assistant.builder.lattice if assistant.builder != null else null


## Every part this may lay, for the caller to fetch before planning.
static func parts_wanted() -> PackedStringArray:
	var wanted: Dictionary = {}
	for name: String in FURNITURE:
		for brick: Dictionary in _bricks_of(name):
			wanted[str(brick["part"])] = true
	for list: Array in [PLATES_TWO, PLATES_ONE, BOARDS, BOARD_PLATES]:
		for one: Array in list:
			wanted[str(one[1])] = true
	for style: Dictionary in COLUMNS.values():
		wanted[str(style["shaft"])] = true
		wanted[str(style["plate"])] = true
	for part: String in [FLAG, "3003", "3022", "3069b", "3004", "3023", "4175"]:
		wanted[part] = true
	return PackedStringArray(wanted.keys())


## The bricks of a piece of furniture as it is defined, before any turn.
static func _bricks_of(name: String) -> Array:
	var def: Dictionary = FURNITURE.get(name, {})
	if def.has("bricks"):
		return def["bricks"]
	# A withdrawn one is no piece at all, not the nearest name to it.
	if Techniques.WITHDRAWN.has(str(def.get("technique", ""))):
		return []
	var technique: Dictionary = Techniques.named(str(def.get("technique", "")))
	# A footing a piece stands on away from the ground, after its own parts.
	return (technique.get("bricks", []) as Array) + (def.get("footing", []) as Array)


## The kind of room a design means by what it said, or "" for none.
static func kind_of(said: String) -> String:
	var words: String = said.strip_edges().to_lower().replace("í", "i")
	if KINDS.has(words):
		return words
	for pair: Array in SAID:
		if not SubjectWords.first_named(words, pair[0]).is_empty():
			return str(pair[1])
	return ""


## Lay the floors and furnish them. Returns {"bricks": the parts to add,
## "summary": what was done, "view": which side the rooms show from,
## "box": an AABB round them in LDU, "floors": what each came to}, or
## {"trouble": why nothing could be done}.
func plan(args: Dictionary) -> Dictionary:
	if _world == null or _library == null:
		return {"trouble": "There is no model standing to put rooms in."}
	var trouble: String = _read(args)
	if not trouble.is_empty():
		return {"trouble": trouble}
	for k: int in _floors.size():
		_measure_floor(k)
	_floors = _floors.filter(func(one: Dictionary) -> bool:
		return not (one["cells"] as Dictionary).is_empty())
	if _floors.is_empty():
		return {"trouble": "There is no room inside that box at any of those "
			+ "heights: every stud of it is taken, or nothing stands round it "
			+ "to be a wall. Give where= the box of the building's inside, "
			+ "or prism= the same at, sides and radius as its prism."}
	for k: int in _floors.size():
		_floors[k]["rng"] = _rng_for(k)
	for k: int in _floors.size():
		if bool(_floors[k].get("stair", false)) and k + 1 < _floors.size():
			_plan_stair(k)
	for k: int in _floors.size():
		_plan_columns(k)
	for k: int in _floors.size():
		_lay_plates(k)
	for k: int in _floors.size():
		_lay_columns(k)
		_lay_stair(k)
	for k: int in _floors.size():
		_furnish(k)
	for k: int in _floors.size():
		_lay_tiles(k)
	for k: int in _floors.size():
		_hold(k)
	return answer()


## The bricks laid, without the bookkeeping on them.
func bricks() -> Array:
	var out: Array = []
	for brick: Dictionary in _laid:
		if brick.is_empty():
			continue
		var one: Dictionary = brick.duplicate()
		one.erase("item")
		out.append(one)
	return out


## Take out the items that hold any of these bricks (indices into
## [method bricks]), because the check found them floating: what is left
## is said again. Returns how many items went.
func drop(indices: Array) -> int:
	var live: Array[int] = []
	for n: int in _laid.size():
		if not _laid[n].is_empty():
			live.append(n)
	var gone: Dictionary = {}
	for raw: Variant in indices:
		var at: int = int(raw)
		if at >= 0 and at < live.size():
			gone[int(_laid[live[at]]["item"])] = true
	for item: int in gone:
		_take_out(item)
	return gone.size()


# -- reading the call ----------------------------------------------------


func _read(args: Dictionary) -> String:
	_seed = int(args.get("seed", 0))
	var where: Dictionary = args.get("where", {}) if args.get("where") is Dictionary else {}
	var prism: Dictionary = args.get("prism", {}) if args.get("prism") is Dictionary else {}
	if not prism.is_empty():
		var at: Dictionary = prism.get("at", {}) if prism.get("at") is Dictionary else prism
		var sides: int = int(prism.get("sides", 8))
		var radius: float = float(prism.get("radius", 0))
		if sides < 5 or sides > 16 or radius < 3:
			return ("prism= wants the prism's own at, sides (5-16) and radius, "
				+ "so the floors follow its faces")
		_prism = {"x": float(at.get("x", 0)), "z": float(at.get("z", 0)),
			"sides": sides, "radius": radius,
			"apothem": radius - clampf(float(prism.get("thickness", 2)), 1, 2)}
		_x0 = int(floor(float(_prism["x"]) - radius))
		_x1 = int(ceil(float(_prism["x"]) + radius))
		_z0 = int(floor(float(_prism["z"]) - radius))
		_z1 = int(ceil(float(_prism["z"]) + radius))
		if not where.has("y_from") and at.has("y"):
			where["y_from"] = float(at["y"])
	if where.has("x_from") and where.has("x_to") and where.has("z_from") \
			and where.has("z_to"):
		_x0 = int(floor(minf(float(where["x_from"]), float(where["x_to"]))))
		_x1 = int(ceil(maxf(float(where["x_from"]), float(where["x_to"]))))
		_z0 = int(floor(minf(float(where["z_from"]), float(where["z_to"]))))
		_z1 = int(ceil(maxf(float(where["z_from"]), float(where["z_to"]))))
	elif prism.is_empty():
		return ("add_rooms wants where= the box of the building, x_from to "
			+ "x_to and z_from to z_to in studs, or prism= the at, sides and "
			+ "radius of the prism it is built with")
	if _x1 - _x0 < 3 or _z1 - _z0 < 3 or (_x1 - _x0) * (_z1 - _z0) > 4000:
		return "where= has to be at least 3 studs a side and not more than 4000 studs in all"

	var asked: Array = args.get("floors", []) if args.get("floors") is Array else []
	if asked.is_empty():
		return ("add_rooms wants floors=, bottom up, each a kind of room — "
			+ "%s — or {\"room\": ..., \"y\": plates up, \"stair\": true}"
			% ", ".join(PackedStringArray(KINDS.keys())))
	var bottom: float = float(where.get("y_from", -1))
	var top: float = float(where.get("y_to", -1))
	if top < 0:
		top = _top_of_shell()
	var storey: float = float(args.get("height", STOREY))
	var stacked: bool = true
	for raw: Variant in asked:
		if raw is Dictionary and (raw as Dictionary).has("y"):
			stacked = false
	if bottom < 0:
		bottom = _lowest_room()
	# Stacked from the bottom when no heights are said, fitted to the shell:
	# a storey of 24 in a shell 60 tall is two floors and an attic.
	if stacked and not args.has("height") and top > bottom:
		storey = clampf(floor((top - bottom) / asked.size()), LOWEST, STOREY)
	var y: float = bottom
	for n: int in mini(asked.size(), MOST_FLOORS):
		var raw: Variant = asked[n]
		var one: Dictionary = raw if raw is Dictionary else {"room": str(raw)}
		var said: String = str(one.get("room", one.get("kind", "hall")))
		var kind: String = kind_of(said)
		var floor_y: float = float(one.get("y", y))
		_floors.append({"said": said, "room": kind if not kind.is_empty() else "hall",
			"guessed": kind.is_empty(), "y": int(round(floor_y)),
			"stair": bool(one.get("stair", false)), "cells": {},
			"hole": {}, "reserved": {}, "plated": {}, "columns": [], "props": [],
			"missed": []})
		y = floor_y + float(one.get("height", storey))
	_floors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["y"]) < int(b["y"]))
	return ""


## The highest plate anything stands at inside the box — or, inside a prism
## with a roof across it as high as its walls, the roof. A prism with piers is
## capped with a summit and its horns rise past it at the corners of the box,
## and a first cluster had its fifth room laid on the summit, in the open,
## between the horns. A floor a design laid itself lower down is not a roof.
func _top_of_shell() -> float:
	var top: int = 0
	var inside: Array[int] = []
	var walls: Array[int] = []
	for x: int in range(_x0, _x1):
		for z: int in range(_z0, _z1):
			var here: int = _world.surface_height(x * ACROSS + 5, z * ACROSS + 5, 0)
			top = maxi(top, here)
			if _prism.is_empty():
				continue
			if _in_prism(Vector2i(x, z)):
				inside.append(here)
			elif _in_prism(Vector2i(x, z), float(_prism["radius"])):
				walls.append(here)
	if inside.size() >= SMALLEST and not walls.is_empty():
		inside.sort()
		walls.sort()
		var roof: int = inside[inside.size() / 2]
		if roof >= LOWEST * UP and roof >= walls[walls.size() / 2] - 2 * UP:
			return float(_roof_under(roof)) / UP
	return float(top) / UP


## The underside of a roof whose top is at [param top] cells, over the middle
## of the inside: where the floors stop.
func _roof_under(top: int) -> int:
	var x: int = int(round(float(_prism["x"]) - 0.5))
	var z: int = int(round(float(_prism["z"]) - 0.5))
	var y: int = top
	while y > 0 and _world.brick_at(Vector3i(x * ACROSS + 5, y - 2, z * ACROSS + 5)) != 0:
		y -= UP
	return y


## Where the lowest room can go: the first plate up from the ground at which
## there is a room's worth of studs clear and walled.
func _lowest_room() -> float:
	for y: int in range(0, 120):
		if _inside(y).size() >= SMALLEST:
			return float(y)
	return 0.0


func _rng_for(k: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, k, str(_floors[k]["room"])])
	return rng


# -- the inside ----------------------------------------------------------


## What floor k covers, and whether it is the ground, a floor already
## there, or one to lay.
func _measure_floor(k: int) -> void:
	var level: Dictionary = _floors[k]
	var y: int = level["y"]
	var cells: Dictionary = _inside(y)
	level["existing"] = false
	if cells.size() < SMALLEST:
		# A floor the design laid itself: furnish what is on it.
		for up: int in range(1, 9):
			var on: Dictionary = _inside(y + up)
			if on.size() >= SMALLEST and _stands_on_something(on, y + up):
				cells = on
				level["y"] = y + up
				level["existing"] = true
				break
	y = level["y"]
	level["cells"] = cells if cells.size() >= SMALLEST else {}
	level["ground"] = y <= 0
	# What things stand at, and the top of the floor. A laid floor is plates
	# along z and a layer along x over them, tiles where it is walked on and
	# plates where something stands, and things stand on top of it. They
	# stood on the plates first, in holes in the tiles, and a bookcase on the
	# whole of an edge strip left that strip tied to nothing.
	if level["existing"] or level["ground"]:
		level["base"] = y
		level["surface"] = y if level["existing"] else y + 1
	else:
		level["base"] = y + 2
		level["surface"] = y + 2
	level["open"] = _open_side(cells, int(level["base"]))


## The studs of the inside at plate y: inside the prism's faces, or walled
## on two opposite sides inside the box, and with nothing in the way of a
## floor. The largest piece of it, so a groove or a gap outside is not a
## room.
func _inside(y: int) -> Dictionary:
	var cells: Dictionary = {}
	for x: int in range(_x0, _x1):
		for z: int in range(_z0, _z1):
			var at := Vector2i(x, z)
			if not _prism.is_empty() and not _in_prism(at):
				continue
			if not _clear(at, y, y + 2):
				continue
			if _prism.is_empty() and not _walled(at, y):
				continue
			cells[at] = true
	return _largest(cells)


func _in_prism(at: Vector2i, reach: float = -1.0) -> bool:
	var sides: int = _prism["sides"]
	var apothem: float = _prism["apothem"] if reach < 0.0 else reach
	var middle := Vector2(_prism["x"], _prism["z"])
	for face: int in sides:
		var angle: float = TAU * face / sides
		var out := Vector2(sin(angle), cos(angle))
		for corner: Vector2 in [Vector2(at), Vector2(at) + Vector2(1, 0),
				Vector2(at) + Vector2(0, 1), Vector2(at) + Vector2(1, 1)]:
			if (corner - middle).dot(out) > apothem + 0.05:
				return false
	return true


## Whether a stud's column is empty from plate y0 up to y1.
func _clear(at: Vector2i, y0: int, y1: int) -> bool:
	return _world.blockers_boxes(_stud_box(at, y0, y1)).is_empty()


static func _stud_box(at: Vector2i, y0: int, y1: int) -> PackedInt32Array:
	return PackedInt32Array([at.x * ACROSS, y0 * UP, at.y * ACROSS,
		at.x * ACROSS + ACROSS, y1 * UP, at.y * ACROSS + ACROSS])


## Walled on both sides along x, or along z, a few plates above the floor:
## inside a building open at the back, not out in the corner of its box.
func _walled(at: Vector2i, y: int) -> bool:
	for up: int in [y + 4, y + 8]:
		if _meets(at, DIRS[1], up) and _meets(at, DIRS[3], up):
			return true
		if _meets(at, DIRS[0], up) and _meets(at, DIRS[2], up):
			return true
	return false


func _meets(at: Vector2i, way: Vector2i, y: int) -> bool:
	for step: int in range(1, REACH):
		var stud: Vector2i = at + way * step
		if _world.brick_at(Vector3i(stud.x * ACROSS + 5, y * UP + 2,
				stud.y * ACROSS + 5)) != 0:
			return true
	return false


static func _largest(cells: Dictionary) -> Dictionary:
	var seen: Dictionary = {}
	var best: Dictionary = {}
	for start: Variant in cells:
		if seen.has(start):
			continue
		var piece: Dictionary = {start: true}
		var queue: Array = [start]
		seen[start] = true
		while not queue.is_empty():
			var here: Vector2i = queue.pop_back()
			for way: Vector2i in DIRS:
				var next: Vector2i = here + way
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					piece[next] = true
					queue.append(next)
		if piece.size() > best.size():
			best = piece
	return best


func _stands_on_something(cells: Dictionary, y: int) -> bool:
	var under: int = 0
	for at: Vector2i in cells:
		if not _clear(at, y - 1, y):
			under += 1
	return under * 2 >= cells.size()


## Whether there is a wall one stud past this edge of the floor: something
## standing there above it.
func _wall_at(cells: Dictionary, at: Vector2i, way: int, base: int) -> bool:
	var next: Vector2i = at + DIRS[way]
	if cells.has(next):
		return false
	return not _clear(next, base + 1, base + 6)


## Which way the floor is open to the air rather than walled, by most of its
## edge: "-z" for a tower open at the back, or "" when it is closed all round.
func _open_side(cells: Dictionary, base: int) -> String:
	var open: Array[int] = [0, 0, 0, 0]
	for at: Vector2i in cells:
		for way: int in 4:
			var next: Vector2i = at + DIRS[way]
			if cells.has(next):
				continue
			if _clear(next, base + 1, base + 10) and not _meets(at, DIRS[way], base + 4):
				open[way] += 1
	var best: int = -1
	for way: int in 4:
		if open[way] > 1 and (best < 0 or open[way] > open[best]):
			best = way
	return DIR_NAMES[best] if best >= 0 else ""


## The studs of floor k nothing has claimed yet.
func _free_cells(k: int) -> Dictionary:
	var level: Dictionary = _floors[k]
	var out: Dictionary = {}
	for at: Variant in level["cells"]:
		if not (level["hole"] as Dictionary).has(at) \
				and not (level["reserved"] as Dictionary).has(at):
			out[at] = true
	return out


# -- laying a part -------------------------------------------------------


func _boxes(brick: Dictionary) -> PackedInt32Array:
	var mesh: Lbm.PartMesh = _library.mesh_for(str(brick["part"]))
	if mesh == null:
		return PackedInt32Array()
	var at: Transform3D = _assistant._transform(
		Assistant.Placement.from_dict(brick), mesh)
	return _builder.boxes_for(mesh, at)


## Whether every brick goes where nothing is, neither what stands nor what
## this has laid.
func _fits(bricks: Array) -> bool:
	for brick: Dictionary in bricks:
		var packed: PackedInt32Array = _boxes(brick)
		if packed.is_empty():
			return false
		if not _world.blockers_boxes(packed).is_empty() \
				or not _mine.blockers_boxes(packed).is_empty():
			return false
	return true


## Whether a stud of floor k's top layer at [param at], on plate [param y],
## would run into a piece of furniture standing over it, by the parts' real
## shapes (Exact): a part there that is off the grid, on its side, or whose
## underside is solid takes no stud.
func _stud_meets_furniture(k: int, at: Vector2i, y: int) -> bool:
	var plate: Exact.Item = _exact_item({"part": "3024", "color": 0, "x": at.x, "y": y,
		"z": at.y, "rot": 0})
	if plate == null:
		return false
	for item: Dictionary in _items:
		if int(item["floor"]) != k or item["role"] != "furniture" or item.has("gone") \
				or not (item["cells"] as Array).has(at):
			continue
		for index: int in item["bricks"]:
			var brick: Dictionary = _laid[index]
			if brick.is_empty() or float(brick["y"]) > y + 2.0:
				continue
			var theirs: Exact.Item = _exact_item(brick)
			if theirs != null and not Exact.clash(plate, theirs).is_empty():
				return true
	return false


## A brick as the exact check holds it: its real shape where it is, or null
## where the part has none.
func _exact_item(brick: Dictionary) -> Exact.Item:
	var shape: Exact.Shape = Exact.shape_for(_library, str(brick["part"]))
	var mesh: Lbm.PartMesh = _library.mesh_for(str(brick["part"]))
	if shape == null or mesh == null or not shape.has_pieces():
		return null
	return Exact.Item.new(shape, _assistant._transform(Assistant.Placement.from_dict(brick),
		mesh))


## Lay an item's bricks, which [method _fits] has passed. Returns its number.
func _lay(bricks: Array, name: String, k: int, role: String,
		cells: Array, base: int) -> int:
	var item: int = _items.size()
	var indices: Array[int] = []
	for raw: Dictionary in bricks:
		var brick: Dictionary = raw.duplicate()
		brick["item"] = item
		var index: int = _laid.size()
		_laid.append(brick)
		_mine.occupy_boxes(index + 1, _boxes(brick))
		indices.append(index)
	_items.append({"name": name, "floor": k, "role": role, "bricks": indices,
		"cells": cells, "base": base})
	return item


func _take_out(item: int) -> void:
	var one: Dictionary = _items[item]
	for index: int in one["bricks"]:
		if not _laid[index].is_empty():
			_mine.release(index + 1)
			_laid[index] = {}
	one["bricks"] = [] as Array[int]
	one["gone"] = true
	if one["role"] == "plate":
		for at: Vector2i in one["cells"]:
			(_floors[int(one["floor"])]["plated"] as Dictionary).erase(at)
	elif one["role"] == "stair":
		# And a ladder takes the props it gave the floor above with it. Left,
		# the plate over its pillar counted itself held by a pillar that was
		# not there, and the check found it floating: a tower's library lost
		# a floor plate and its two tiles that way.
		var k: int = int(one["floor"])
		var level: Dictionary = _floors[k]
		level.erase("climb")
		if level.has("ladder_at"):
			level.erase("ladder_at")
			if k + 1 < _floors.size():
				_floors[k + 1]["props"] = []


## The studs of floor k a thing can stand on: all of the ground, a laid
## floor where its plates are, a floor already there where something is
## under it.
func _standing(k: int) -> Dictionary:
	var level: Dictionary = _floors[k]
	if bool(level["ground"]):
		return level["cells"]
	if not bool(level["existing"]):
		return level["plated"]
	var out: Dictionary = {}
	var base: int = level["base"]
	for at: Vector2i in level["cells"]:
		var under := PackedInt32Array([at.x * ACROSS, base * UP - 1, at.y * ACROSS,
			at.x * ACROSS + ACROSS, base * UP, at.y * ACROSS + ACROSS])
		if not _world.blockers_boxes(under).is_empty():
			out[at] = true
	return out


## One part, if it fits: for floors and tiles, laid stud by stud.
func _lay_one(brick: Dictionary, k: int, role: String, cells: Array) -> bool:
	if not _fits([brick]):
		return false
	_lay([brick], role, k, role, cells, int(brick["y"]))
	return true


# -- stairs and columns --------------------------------------------------


## How floor k climbs to the one above: a stair where one fits, two studs
## wide along a wall, one stud of run to every brick of rise and a stud
## clear at either end; a ladder up a pillar where one does not, as the
## rooms of a tower are joined when they are small. Reserved below, a hole
## above.
func _plan_stair(k: int) -> void:
	if bool(_floors[k + 1]["existing"]):
		return
	if not _plan_flight(k):
		_plan_ladder(k)


func _plan_flight(k: int) -> bool:
	var low: Dictionary = _floors[k]
	var high: Dictionary = _floors[k + 1]
	var rise: int = int(high["surface"]) - int(low["base"])
	var steps: int = rise / 3
	if steps < 2 or steps > 14:
		return false
	var free: Dictionary = _free_cells(k)
	var rng: RandomNumberGenerator = low["rng"]
	var starts: Array = free.keys()
	_shuffle(starts, rng)
	for start: Vector2i in starts:
		for run: int in 4:
			for side: int in [(run + 1) % 4, (run + 3) % 4]:
				var against: int = 0
				var ok: bool = true
				for i: int in steps + 1:
					for j: int in 2:
						var at: Vector2i = start + DIRS[run] * i + DIRS[side] * j
						if not free.has(at) or not (high["cells"] as Dictionary).has(at):
							ok = false
					if _wall_at(low["cells"], start + DIRS[run] * i, (side + 2) % 4,
							int(low["base"])):
						against += 1
				if not ok or against * 2 < steps:
					continue
				var foot: Array[Vector2i] = [start - DIRS[run], start - DIRS[run] + DIRS[side]]
				var head: Array[Vector2i] = [start + DIRS[run] * (steps + 1),
					start + DIRS[run] * (steps + 1) + DIRS[side]]
				for at: Vector2i in foot:
					if not free.has(at):
						ok = false
				for at: Vector2i in head:
					if not (high["cells"] as Dictionary).has(at):
						ok = false
				if not ok:
					continue
				for i: int in steps + 1:
					for j: int in 2:
						var at: Vector2i = start + DIRS[run] * i + DIRS[side] * j
						low["reserved"][at] = true
						high["hole"][at] = true
				for at: Vector2i in foot:
					low["reserved"][at] = true
				for at: Vector2i in head:
					high["reserved"][at] = true
				low["stair_at"] = {"start": start, "run": run, "side": side,
					"steps": steps, "gap": rise - steps * 3}
				return true
	return false


## A ladder up a pillar of 1 x 2 bricks against a wall: a plate with a
## ladder (4175) every six plates, the ladder hanging over the bricks below
## it, the pillar's top holding the floor above and the hole beside it to
## climb through. Two studs by two where a straight stair of a 24-plate
## storey is eleven long, which is longer than an octagonal tower is wide.
func _plan_ladder(k: int) -> void:
	var low: Dictionary = _floors[k]
	var high: Dictionary = _floors[k + 1]
	var tall: int = int(high["y"]) - int(low["base"])
	if tall < 6 or tall > 72:
		return
	var bricks: Array = _ladder(tall, 0 if str(KINDS[low["room"]]["column"]) == "stone" else 70)
	var free: Dictionary = _free_cells(k)
	var rng: RandomNumberGenerator = low["rng"]
	var turns: Array = [0, 1, 2, 3]
	_shuffle(turns, rng)
	for turn: int in turns:
		var shape: Dictionary = _shape("ladder %d" % tall, bricks, turn)
		var footprint: Array = shape["cells"]
		var front: int = turn
		var back: int = (turn + 2) % 4
		var pillar: Array = footprint.filter(func(at: Vector2i) -> bool:
			return not footprint.has(at + DIRS[back]))
		var rungs: Array = footprint.filter(func(at: Vector2i) -> bool:
			return not pillar.has(at))
		var edges: Array = free.keys()
		_shuffle(edges, rng)
		for edge: Vector2i in edges:
			if not _wall_at(low["cells"], edge, back, int(low["base"])):
				continue
			for f: Vector2i in pillar:
				var by: Vector2i = edge - f
				var ok: bool = true
				for at: Vector2i in footprint:
					if not free.has(at + by):
						ok = false
				for at: Vector2i in pillar:
					if not _wall_at(low["cells"], at + by, back, int(low["base"])):
						ok = false
				for at: Vector2i in rungs:
					# Room to stand in front of it, and the hole above it.
					if not free.has(at + by + DIRS[front]) \
							or not (high["cells"] as Dictionary).has(at + by):
						ok = false
				if not ok:
					continue
				var placed: Array = []
				for raw: Dictionary in shape["bricks"]:
					var brick: Dictionary = raw.duplicate()
					brick["x"] = snappedf(float(brick["x"]) + by.x, 0.1)
					brick["z"] = snappedf(float(brick["z"]) + by.y, 0.1)
					brick["y"] = snappedf(float(brick["y"]) + int(low["base"]), 0.25)
					placed.append(brick)
				var cells: Array = []
				for at: Vector2i in footprint:
					cells.append(at + by)
					low["reserved"][at + by] = true
				for at: Vector2i in rungs:
					low["reserved"][at + by + DIRS[front]] = true
					high["hole"][at + by] = true
					high["reserved"][at + by + DIRS[front]] = true
				for at: Vector2i in pillar:
					high["props"].append(at + by)
				# And under it, where it stands on a floor of plates: a column
				# from the room below to a stud of its pillar, kept clear of
				# that room's furniture. Left to the end, a log pile in the
				# dungeon had the stud a column wanted, and the forge's ladder
				# went out with the plates it stood on.
				if k > 0 and not bool(low["ground"]) and not bool(low["existing"]):
					var foot: Vector2i = (pillar[0] as Vector2i) + by
					(low["columns"] as Array).append(foot)
					(_floors[k - 1]["reserved"] as Dictionary)[foot] = true
				low["ladder_at"] = {"bricks": placed, "cells": cells}
				return


## A ladder [param tall] plates high, facing +z from a pillar at z = 0:
## filler plates at the foot, then six plates at a time — two plates and a
## brick of pillar with a ladder plate on top, its ladder hanging over them.
static func _ladder(tall: int, colour: int) -> Array:
	var made: Array = []
	var y: int = 0
	for _n: int in tall % 6:
		made.append({"part": "3023", "color": colour, "x": 0, "y": y, "z": 0, "rot": 0})
		y += 1
	while y < tall:
		made.append({"part": "3023", "color": colour, "x": 0, "y": y, "z": 0, "rot": 0})
		made.append({"part": "3023", "color": colour, "x": 0, "y": y + 1, "z": 0, "rot": 0})
		made.append({"part": "3004", "color": colour, "x": 0, "y": y + 2, "z": 0, "rot": 0})
		made.append({"part": "4175", "color": 70, "x": 0, "y": y, "z": 0, "rot": 0})
		y += 6
	return made


func _lay_stair(k: int) -> void:
	var level: Dictionary = _floors[k]
	if level.has("ladder_at"):
		var plan: Dictionary = level["ladder_at"]
		if _fits(plan["bricks"]):
			_lay(plan["bricks"], "ladder", k, "stair", plan["cells"], level["base"])
			level["climb"] = "a ladder"
		else:
			level.erase("ladder_at")
			_floors[k + 1]["props"] = []
		return
	if not level.has("stair_at"):
		return
	var plan: Dictionary = level["stair_at"]
	var start: Vector2i = plan["start"]
	var run: Vector2i = DIRS[int(plan["run"])]
	var side: Vector2i = DIRS[int(plan["side"])]
	var steps: int = plan["steps"]
	var gap: int = plan["gap"]
	var base: int = level["base"]
	var stone: bool = str(KINDS[level["room"]]["column"]) == "stone"
	var colour: int = 72 if stone else 70
	var tread: int = 0 if stone else 28
	var made: Array = []
	var cells: Array = []
	for i: int in steps + 1:
		for j: int in 2:
			cells.append(start + run * i + side * j)
	# The low corner of the two by two the stair covers at run i to i + 1.
	var corner := func(i: int) -> Vector2i:
		var a: Vector2i = start + run * i
		var b: Vector2i = start + run * (i + 1) + side
		return Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	for g: int in gap:
		var at: Vector2i = corner.call(0)
		made.append({"part": "3022", "color": colour, "x": at.x, "y": base + g,
			"z": at.y, "rot": 0})
	for i: int in steps:
		var at: Vector2i = corner.call(i)
		var y: int = base + gap + 3 * i
		made.append({"part": "3003", "color": colour, "x": at.x, "y": y,
			"z": at.y, "rot": 0})
		if i + 1 < steps:
			# A tile on the tread the next step leaves bare.
			var bare: Vector2i = start + run * i
			var other: Vector2i = bare + side
			made.append({"part": "3069b", "color": tread,
				"x": mini(bare.x, other.x), "y": y + 3, "z": mini(bare.y, other.y),
				"rot": 0 if side.x != 0 else 1})
	if _fits(made):
		_lay(made, "stair", k, "stair", cells, base)
		level["climb"] = "a stair"
	else:
		level.erase("stair_at")


## Where the columns holding floor k up stand: two, or three under a big
## floor, against the walls of the room below, spread apart — in its corners
## first, where a wall turns or a diagonal face steps, because a straight
## run of wall is where the bookcase goes. The first plan took them from
## anywhere along the wall, and an octagonal tower's five-stud faces lost
## their bookcases and hearths to them.
func _plan_columns(k: int) -> void:
	var level: Dictionary = _floors[k]
	if bool(level["ground"]) or bool(level["existing"]):
		return
	var cells: Dictionary = level["cells"]
	var below: Dictionary = _floors[k - 1] if k > 0 else {}
	var rng: RandomNumberGenerator = level["rng"]
	var wanted: int = 3 if cells.size() > 150 else 2
	var choices: Array = []
	var best_walls: int = 1
	for at: Vector2i in cells:
		if (level["hole"] as Dictionary).has(at):
			continue
		if not below.is_empty():
			if not (below["cells"] as Dictionary).has(at) \
					or (below["reserved"] as Dictionary).has(at) \
					or (below["hole"] as Dictionary).has(at):
				continue
		var walls: int = 0
		for way: int in 4:
			if _wall_at(cells, at, way, int(level["base"])):
				walls += 1
		if walls > 0:
			choices.append([at, walls])
			best_walls = maxi(best_walls, walls)
	_shuffle(choices, rng)
	var chosen: Array[Vector2i] = []
	for walls: int in range(best_walls, 0, -1):
		var these: Array = choices.filter(func(one: Array) -> bool:
			return int(one[1]) == walls)
		while chosen.size() < wanted and not these.is_empty():
			# The one furthest from those already chosen.
			var pick: int = 0
			var far: float = -1.0
			for n: int in these.size():
				var near: float = 0.0 if chosen.is_empty() else INF
				for one: Vector2i in chosen:
					near = minf(near, Vector2((these[n][0] as Vector2i) - one).length())
				if near > far:
					far = near
					pick = n
			chosen.append(these[pick][0])
			these.remove_at(pick)
	for at: Vector2i in chosen:
		level["columns"].append(at)
		if not below.is_empty():
			below["reserved"][at] = true


func _lay_columns(k: int) -> void:
	var level: Dictionary = _floors[k]
	var kept: Array = []
	for at: Vector2i in level["columns"]:
		if _column(k, at):
			kept.append(at)
	level["columns"] = kept


## A column from whatever is under this stud of floor k up to the floor's
## plates. Stone or timber by the room it stands in.
func _column(k: int, at: Vector2i) -> bool:
	var level: Dictionary = _floors[k]
	var top: int = level["y"]
	var from: int = -1
	for y: int in range(top - 1, -1, -1):
		var ours: PackedInt64Array = _mine.blockers_boxes(_stud_box(at, y, y + 1))
		if not _clear(at, y, y + 1) or not ours.is_empty():
			# On a floor or the shell, never on furniture: a column stood on
			# the round top of a barrel in the room below touched nothing it
			# could rest on, and floated.
			for id: int in ours:
				if _items[int(_laid[id - 1]["item"])]["role"] in ["furniture", "stair"]:
					return false
			from = y + 1
			break
	if from < 0:
		from = 0
	var tall: int = top - from
	if tall < 1 or tall > 72:
		return false
	var under: Dictionary = _floors[k - 1] if k > 0 else level
	var style: Dictionary = COLUMNS[KINDS[under["room"]]["column"]]
	var made: Array = []
	var y: int = from
	for _n: int in tall % 3:
		made.append({"part": style["plate"], "color": style["cap"], "x": at.x,
			"y": y, "z": at.y, "rot": 0})
		y += 1
	while y < top:
		made.append({"part": style["shaft"], "color": style["colour"], "x": at.x,
			"y": y, "z": at.y, "rot": 0})
		y += 3
	if not _fits(made):
		return false
	_lay(made, "column", k, "column", [at], from)
	return true


# -- floors --------------------------------------------------------------


## The plates that hold a floor up, two studs wide along z, longest first;
## a stud that will not take a long one takes a short one.
func _lay_plates(k: int) -> void:
	var level: Dictionary = _floors[k]
	if bool(level["ground"]) or bool(level["existing"]):
		return
	var y: int = level["y"]
	var stone: bool = str(KINDS[level["room"]]["column"]) == "stone"
	var colour: int = 72 if stone else 70
	var left: Dictionary = {}
	for at: Variant in level["cells"]:
		if not (level["hole"] as Dictionary).has(at):
			left[at] = true
	var xs: Array = []
	for at: Vector2i in left:
		xs.append(at.x)
	xs.sort()
	if xs.is_empty():
		return
	# Where the strips start, for the tiles to lay their joints between.
	level["strip_x"] = int(xs[0])
	# Two wide, each strip one plate as long as it runs, then one wide at
	# the edges. Four wide was tried, and its ends came out as plates across
	# a single row that nothing over them tied to the row before.
	for x: int in range(int(xs[0]), int(xs[xs.size() - 1]) + 1, 2):
		for z: int in range(_z0, _z1):
			var at := Vector2i(x, z)
			if left.has(at) and left.has(at + Vector2i(1, 0)):
				_strip(left, at, 2, y, colour, PLATES_TWO, k)
		for z: int in range(_z0, _z1):
			for dx: int in 2:
				var at := Vector2i(x + dx, z)
				if left.has(at):
					_strip(left, at, 1, y, colour, PLATES_ONE, k)


## Lay the longest part of [param lengths] that fits along +z from [param
## at], [param wide] studs across, and take its studs out of [param left].
## Where none fits the studs are left for a narrower pass: this used to
## give them up, and a 4-wide strip two studs long gave up a room's worth
## of floor that the 2-wide pass would have laid — so the tiles and a
## candlestick stood there on nothing.
func _strip(left: Dictionary, at: Vector2i, wide: int, y: int, colour: int,
		lengths: Array, k: int) -> void:
	var room: int = 0
	while room < 16:
		var ok: bool = true
		for dx: int in wide:
			if not left.has(at + Vector2i(dx, room)):
				ok = false
		if not ok:
			break
		room += 1
	for one: Array in lengths:
		var long: int = one[0]
		if long > room:
			continue
		var brick := {"part": one[1], "color": colour, "x": at.x, "y": y,
			"z": at.y, "rot": one[2]}
		var cells: Array = []
		for dz: int in long:
			for dx: int in wide:
				cells.append(at + Vector2i(dx, dz))
		if _lay_one(brick, k, "plate", cells):
			for cell: Vector2i in cells:
				left.erase(cell)
				_floors[k]["plated"][cell] = true
			return


## The floor itself: boards of 1 x 6 down to 1 x 1 tiles along x, every row
## starting at a different place; flags of 2 x 2 tiles a row of two at a
## time, staggered, in mixed tones; or a checker of 2 x 2s in two. A carpet
## runs from the room's signature piece to the open side, where the kind has
## one. On a laid floor, the studs something stands on — furniture, a stair,
## a column for the floor above — take plates of the same size instead, so
## it clutches them; on the ground, they are left out round it.
func _lay_tiles(k: int) -> void:
	var level: Dictionary = _floors[k]
	if bool(level["existing"]):
		return
	var kind: Dictionary = KINDS[level["room"]]
	var rng: RandomNumberGenerator = level["rng"]
	var y: int = int(level["surface"]) - 1
	var tones: Array = (kind["tones"] as Array).duplicate()
	if rng.randf() < 0.5 and tones.size() > 1:
		tones.reverse()
	var left: Dictionary = {}
	for at: Variant in _standing(k):
		if not (level["hole"] as Dictionary).has(at):
			left[at] = true
	var under: Dictionary = {}
	if not bool(level["ground"]):
		for item: Dictionary in _items:
			if int(item["floor"]) == k and not item.has("gone") \
					and item["role"] in ["furniture", "stair"]:
				for at: Vector2i in item["cells"]:
					under[at] = true
		if k + 1 < _floors.size():
			for at: Vector2i in _floors[k + 1]["columns"]:
				under[at] = true
		# A tile, not a stud, under a part of a piece that does not take the
		# stud by its real shape: a dresser's door rail plates, a log pile on
		# its side, a four-poster's headlight bricks on theirs. The floor's
		# studs ran 4 LDU into each, 24 of them on rooms_probe's eight floors,
		# and the pieces stood joined to nothing; where a part does take them,
		# they hold it.
		for at: Variant in under.keys():
			if _stud_meets_furniture(k, at, y):
				under.erase(at)
	var carpet: Dictionary = _carpet(k)
	var style: String = kind["floor"]
	# The plates under a floor are strips from strip_x, and this layer is
	# all that ties one strip to the next: a joint here over a joint there
	# ties nothing. So flags and checks start a stud off the strips, and a
	# board ends a stud off them where it can.
	var strips: int = int(level.get("strip_x", _x0))
	var from_x: int = strips + 1 - 2 * ((strips + 1 - _x0 + 1) / 2)
	if style == "flags" or style == "checker":
		for z: int in range(_z0, _z1, 2):
			var shift: int = 0 if style == "checker" or (z - _z0) % 4 == 0 else 1
			for x: int in range(from_x - shift, _x1, 2):
				var at := Vector2i(x, z)
				var four: Array = [at, at + Vector2i(1, 0), at + Vector2i(0, 1),
					at + Vector2i(1, 1)]
				if not four.all(func(one: Vector2i) -> bool:
						return left.has(one) and not under.has(one)):
					continue
				var tone: int
				if carpet.has(at) and carpet.has(at + Vector2i(1, 1)):
					tone = int(kind.get("carpet", tones[0]))
				elif style == "checker":
					tone = tones[posmod((x - from_x) / 2 + (z - _z0) / 2, 2)]
				else:
					var pick: float = Patterns._scatter(x, y, z, 61 + _seed + k)
					tone = tones[0] if pick < 0.6 else tones[mini(1 + int(pick > 0.9),
						tones.size() - 1)]
				if _lay_one({"part": FLAG, "color": tone, "x": x, "y": y, "z": z,
						"rot": 0}, k, "tile", four):
					for one: Vector2i in four:
						left.erase(one)
	# Boards, and whatever the flags left: rows along x, a run of tiles or a
	# run of plates at a time.
	for z: int in range(_z0, _z1):
		var x: int = _x0
		var first: bool = true
		while x < _x1:
			var at := Vector2i(x, z)
			if not left.has(at):
				x += 1
				first = true
				continue
			var plates: bool = under.has(at)
			var room: int = 0
			while room < 6 and left.has(at + Vector2i(room, 0)) \
					and under.has(at + Vector2i(room, 0)) == plates:
				room += 1
			var tone: int = tones[0]
			if carpet.has(at):
				tone = int(kind.get("carpet", tones[0]))
			elif style == "boards" and tones.size() > 1 \
					and Patterns._scatter(x, y, z, 67 + _seed + k) < 0.3:
				tone = tones[1]
			# Each row starts its boards at a different place, so the joints
			# do not line up across the floor.
			var want: int = room
			if first and style == "boards" and not plates:
				want = mini(room, [2, 4, 1, 3, 6, 3][posmod(z + k, 6)])
			first = false
			var laid: int = _board(k, at, room, want, strips, y, tone,
				BOARD_PLATES if plates else BOARDS)
			if laid == 0:
				left.erase(at)
				x += 1
				continue
			for dx: int in laid:
				left.erase(at + Vector2i(dx, 0))
			x += laid


## One board along x from [param at], at most [param want] long out of a
## run of [param room], from [param sizes]: ending a stud off the plates'
## joints if one will, since a board ending on one ties nothing across it.
## Returns how long it was, or 0.
func _board(k: int, at: Vector2i, room: int, want: int, strips: int, y: int,
		tone: int, sizes: Array) -> int:
	for tidy: bool in [true, false]:
		for one: Array in sizes:
			var long: int = one[0]
			if long > want:
				continue
			if tidy and long < room and posmod(at.x + long - strips, 2) == 0:
				continue
			var cells: Array = []
			for dx: int in long:
				cells.append(at + Vector2i(dx, 0))
			if _lay_one({"part": one[1], "color": tone, "x": at.x, "y": y,
					"z": at.y, "rot": one[2]}, k, "tile", cells):
				return long
	return 0


## The studs a carpet covers: two wide, from the room's signature piece to
## its open side, for a room whose kind has one.
func _carpet(k: int) -> Dictionary:
	var level: Dictionary = _floors[k]
	var kind: Dictionary = KINDS[level["room"]]
	var out: Dictionary = {}
	if not kind.has("carpet") or str(level["open"]).is_empty():
		return out
	var way: int = DIR_NAMES.find(str(level["open"]))
	var start: Vector2 = Vector2.ZERO
	var found: bool = false
	for item: Dictionary in _items:
		if int(item["floor"]) == k and item["role"] == "furniture" \
				and not item.has("gone"):
			for at: Vector2i in item["cells"]:
				start += Vector2(at)
			start /= float((item["cells"] as Array).size())
			found = true
			break
	if not found:
		return out
	var across: Vector2i = DIRS[(way + 1) % 4]
	var at := Vector2i(int(floor(start.x)), int(floor(start.y)))
	at -= Vector2i(across.x * (1 if across.x > 0 else 0), across.y * (1 if across.y > 0 else 0))
	for step: int in REACH:
		var here: Vector2i = at + DIRS[way] * step
		if not (level["cells"] as Dictionary).has(here) and step > 4:
			break
		out[here] = true
		out[here + across] = true
	return out


## Every piece of floor k held up: by a column, by what stands under it or
## by the ground, or through the tiles over the joints to one that is.
##
## A piece held by nothing is first tied to its neighbour with a tile across
## the joint between them: its own tile and the one beside it come up and a
## 1 x 2 goes down over both. The first tower here came out with six columns
## a floor where two were planned, each holding up a 1 x 1 plate at the edge
## of an octagon whose only tile was its own. What still floats gets a column
## if one will stand under it, and is taken out with what is on it if not.
func _hold(k: int) -> void:
	var level: Dictionary = _floors[k]
	if bool(level["ground"]) or bool(level["existing"]):
		return
	var pieces: Dictionary = _pieces(k)
	for root: int in pieces["groups"]:
		if not (pieces["held"] as Dictionary).has(root):
			_stitch(k, pieces, root)
	pieces = _pieces(k)
	var groups: Dictionary = pieces["groups"]
	for root: int in groups:
		if (pieces["held"] as Dictionary).has(root):
			continue
		var cells: Array = []
		for n: int in groups[root]:
			cells.append_array(_items[n]["cells"])
		# A stud or two of edge with nothing on it but its tile is not worth
		# a column in the room below: the floor goes without it.
		var bare: bool = cells.size() <= 2 and not _items.any(
			func(item: Dictionary) -> bool:
				return int(item["floor"]) == k and not item.has("gone") \
					and item["role"] in ["furniture", "stair"] \
					and (item["cells"] as Array).any(func(at: Vector2i) -> bool:
						return cells.has(at)))
		var propped: bool = false
		for at: Vector2i in ([] if bare else cells):
			if _column(k, at):
				level["columns"].append(at)
				propped = true
				break
		if propped:
			continue
		# Nothing will stand under it: take it out, and what is on it.
		var gone: Dictionary = {}
		for at: Vector2i in cells:
			gone[at] = true
		for n: int in groups[root]:
			_take_out(n)
		for n: int in _items.size():
			var item: Dictionary = _items[n]
			if int(item["floor"]) != k or item.has("gone") or item["role"] == "plate" \
					or item["role"] == "column":
				continue
			for at: Vector2i in item["cells"]:
				if gone.has(at):
					_take_out(n)
					if item["role"] == "furniture":
						level["missed"].append(item["name"])
					break
		# And a column of the floor above that stood on it: laid again from
		# whatever is under it now. Left standing, a tower in storeys lost the
		# column, the plate on it and the tile on that to the check.
		if k + 1 < _floors.size():
			var over: Dictionary = _floors[k + 1]
			for n: int in _items.size():
				var item: Dictionary = _items[n]
				if int(item["floor"]) != k + 1 or item.has("gone") or item["role"] != "column":
					continue
				var at: Vector2i = (item["cells"] as Array)[0]
				if not gone.has(at):
					continue
				_take_out(n)
				(over["columns"] as Array).erase(at)
				if _column(k + 1, at):
					(over["columns"] as Array).append(at)


## Floor k's plates in the pieces that hold together: {"groups": root ->
## its plates, "held": root -> true where one of them is held, "plate_at":
## stud -> plate, "tile_at": stud -> tile}.
func _pieces(k: int) -> Dictionary:
	var plates: Array[int] = []
	var tiles: Array[int] = []
	for n: int in _items.size():
		var item: Dictionary = _items[n]
		if int(item["floor"]) != k or item.has("gone"):
			continue
		if item["role"] == "plate":
			plates.append(n)
		elif item["role"] == "tile":
			tiles.append(n)
	var plate_at: Dictionary = {}
	var tile_at: Dictionary = {}
	for n: int in plates:
		for at: Vector2i in _items[n]["cells"]:
			plate_at[at] = n
	for n: int in tiles:
		for at: Vector2i in _items[n]["cells"]:
			tile_at[at] = n
	var parent: Dictionary = {}
	for n: int in plates:
		parent[n] = n
	var find := func(n: int) -> int:
		var at: int = n
		while parent[at] != at:
			at = parent[at]
		return at
	# A tile ties every plate it lies on. Furniture standing across two does
	# not, though it looks as if it should: a chest half a stud off the grid
	# rests on its plates without one tube on one stud, and a plate under it
	# that was counted as tied by it floated in the check.
	for item: Dictionary in _items:
		if int(item["floor"]) != k or item.has("gone") or item["role"] != "tile":
			continue
		var first: int = -1
		for at: Vector2i in item["cells"]:
			if not plate_at.has(at):
				continue
			if first < 0:
				first = plate_at[at]
			else:
				parent[find.call(plate_at[at])] = find.call(first)
	var held: Dictionary = {}
	var groups: Dictionary = {}
	for n: int in plates:
		var root: int = find.call(n)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(n)
		if _plate_held(n, k):
			held[root] = true
	return {"groups": groups, "held": held, "plate_at": plate_at,
		"tile_at": tile_at, "find": find}


## Tie the piece of floor k under [param root] to a neighbouring piece with
## a 1 x 2 tile across the joint. Returns whether it did.
func _stitch(k: int, pieces: Dictionary, root: int) -> bool:
	var plate_at: Dictionary = pieces["plate_at"]
	var tile_at: Dictionary = pieces["tile_at"]
	var find: Callable = pieces["find"]
	for n: int in pieces["groups"][root]:
		for at: Vector2i in _items[n]["cells"]:
			for way: int in 4:
				var next: Vector2i = at + DIRS[way]
				if not plate_at.has(next) or find.call(plate_at[next]) == root:
					continue
				if not tile_at.has(at) or not tile_at.has(next):
					continue
				var one: int = tile_at[at]
				var two: int = tile_at[next]
				if one == two or _items[one].has("gone") or _items[two].has("gone"):
					continue
				var y: int = int(_items[one]["base"])
				var tone: int = int(_laid[(_items[one]["bricks"] as Array)[0]]["color"])
				var left: Array = []
				for cell: Vector2i in _items[one]["cells"] + _items[two]["cells"]:
					if cell != at and cell != next:
						left.append(cell)
				var colours: Dictionary = {}
				for cell: Vector2i in _items[one]["cells"]:
					colours[cell] = tone
				for cell: Vector2i in _items[two]["cells"]:
					colours[cell] = int(_laid[(_items[two]["bricks"] as Array)[0]]["color"])
				# Plates where something stands on either, as the floor has
				# there; tiles where nothing does.
				var studded: bool = [one, two].any(func(n2: int) -> bool:
					return BOARD_PLATES.any(func(size: Array) -> bool:
						return str(size[1]) == str(_laid[(_items[n2]["bricks"] as Array)[0]]["part"])))
				_take_out(one)
				_take_out(two)
				var low := Vector2i(mini(at.x, next.x), mini(at.y, next.y))
				var across: bool = DIRS[way].x != 0
				if not _lay_one({"part": "3023" if studded else "3069b", "color": tone,
						"x": low.x, "y": y, "z": low.y, "rot": 0 if across else 1},
						k, "tile", [at, next]):
					left.append(at)
					left.append(next)
				# What else the two tiles covered, again, in runs along x as
				# long as they will go, so the boards they were still cross the
				# joints they crossed.
				left.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
					return a.y < b.y or (a.y == b.y and a.x < b.x))
				var run: int = 0
				while run < left.size():
					var from: Vector2i = left[run]
					var long: int = 1
					while run + long < left.size() and long < 6 \
							and left[run + long] == from + Vector2i(long, 0):
						long += 1
					var x: int = from.x
					while x < from.x + long:
						var room: int = from.x + long - x
						x += maxi(1, _board(k, Vector2i(x, from.y), room, room,
							int(_floors[k].get("strip_x", _x0)), y, colours[from],
							BOARD_PLATES if studded else BOARDS))
					run += long
				if not left.has(at):
					return true
	return false


## Whether a plate of floor k is held from below: by a column or a ladder's
## pillar, or by something in the one layer of cells under it, which is
## what the check asks; a whole plate's depth below was asked first, and a
## diagonal wall's corner a cell lower held a plate the check called
## floating.
func _plate_held(n: int, k: int) -> bool:
	var level: Dictionary = _floors[k]
	var y: int = level["y"]
	for at: Vector2i in _items[n]["cells"]:
		if (level["columns"] as Array).has(at) or (level["props"] as Array).has(at):
			return true
		var under := PackedInt32Array([at.x * ACROSS, y * UP - 1, at.y * ACROSS,
			at.x * ACROSS + ACROSS, y * UP, at.y * ACROSS + ACROSS])
		if not _world.blockers_boxes(under).is_empty() \
				or not _mine.blockers_boxes(under).is_empty():
			return true
	return false


# -- furniture -----------------------------------------------------------


func _furnish(k: int) -> void:
	var level: Dictionary = _floors[k]
	var kind: Dictionary = KINDS[level["room"]]
	var rng: RandomNumberGenerator = level["rng"]
	# Not a piece whose worked construction is withdrawn: it does not build
	# by the parts' real shapes (Techniques.WITHDRAWN).
	var wanted: Array = (kind["items"] as Array).filter(func(name: Variant) -> bool:
		return not _bricks_of(str(name)).is_empty())
	if wanted.is_empty():
		return
	# The signature stays first; the rest come in an order of the seed's.
	var rest: Array = wanted.slice(1)
	_shuffle(rest, rng)
	wanted = [wanted[0]] + rest
	for name: String in wanted:
		if not _place(k, name):
			level["missed"].append(name)


## Stand one piece of furniture in room k: against a wall with its front to
## the room, or free-standing clear of everything, wherever it fits best.
func _place(k: int, name: String) -> bool:
	var level: Dictionary = _floors[k]
	var def: Dictionary = FURNITURE.get(name, {})
	if def.is_empty():
		return false
	var rng: RandomNumberGenerator = level["rng"]
	var bricks: Array = _recoloured(name, rng)
	var front: int = DIR_NAMES.find(str(def.get("front", "")))
	var wall: bool = bool(def.get("wall", true))
	var free: Dictionary = _free_cells(k)
	var standing: Dictionary = _standing(k)
	for at: Variant in free.keys():
		if not standing.has(at):
			free.erase(at)
	var cells: Dictionary = level["cells"]
	var base: int = level["base"]
	var middle := Vector2.ZERO
	for at: Vector2i in cells:
		middle += Vector2(at) + Vector2(0.5, 0.5)
	middle /= float(cells.size())
	var others: Array[Vector2] = []
	for item: Dictionary in _items:
		if int(item["floor"]) == k and item["role"] == "furniture" \
				and not item.has("gone"):
			others.append(_centre(item["cells"]))
	var candidates: Array = []
	for turns: int in 4:
		var shape: Dictionary = _shape(name, bricks, turns)
		var footprint: Array = shape["cells"]
		if footprint.is_empty():
			continue
		var back: int = (front + turns + 2) % 4 if front >= 0 else -1
		# Its back to the wall, or any side to one for a piece with no
		# front; standing free, one way is every place it can stand.
		var ways: Array = [back] if back >= 0 else ([0, 1, 2, 3] if wall else [0])
		for way: int in ways:
			# The row of the footprint that goes to the wall: its furthest
			# studs that way. Every stud with nothing behind it was the
			# first rule, and a four-poster bed, whose shelf stands out to
			# one side, had a "back" half of which was in the middle of the
			# room, so it fitted nowhere.
			var furthest: int = -0x7FFFFFFF
			for at: Vector2i in footprint:
				furthest = maxi(furthest, at.x * DIRS[way].x + at.y * DIRS[way].y)
			var row: Array = footprint.filter(func(at: Vector2i) -> bool:
				return at.x * DIRS[way].x + at.y * DIRS[way].y == furthest)
			for edge: Vector2i in free:
				if wall and not _wall_at(cells, edge, way, base):
					continue
				for f: Vector2i in row:
					var by: Vector2i = edge - f
					var fits: bool = true
					for at: Vector2i in footprint:
						if not free.has(at + by):
							fits = false
							break
					if not fits:
						continue
					var score: float = rng.randf() * 0.5
					if wall:
						var against: int = 0
						for at: Vector2i in row:
							if _wall_at(cells, at + by, way, base):
								against += 1
						if against * 2 < row.size():
							continue
						score += 2.0 * against / row.size()
					else:
						# Clear all round, nearer the middle than the walls.
						var clear: bool = true
						for at: Vector2i in footprint:
							for step: Vector2i in DIRS:
								var next: Vector2i = at + by + step
								if not free.has(next) and not footprint.has(next - by):
									clear = false
						if not clear:
							continue
						score -= 0.15 * (_centre(footprint, by) - middle).length()
					var near: float = 8.0
					for other: Vector2 in others:
						near = minf(near, (_centre(footprint, by) - other).length())
					score += 0.3 * near
					candidates.append([score, turns, by])
	candidates.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) > float(b[0]))
	for n: int in mini(candidates.size(), 40):
		var turns: int = candidates[n][1]
		var by: Vector2i = candidates[n][2]
		var shape: Dictionary = _shape(name, bricks, turns)
		var placed: Array = []
		for raw: Dictionary in shape["bricks"]:
			var brick: Dictionary = raw.duplicate()
			brick["x"] = snappedf(float(brick["x"]) + by.x, 0.1)
			brick["z"] = snappedf(float(brick["z"]) + by.y, 0.1)
			brick["y"] = snappedf(float(brick["y"]) + base, 0.25)
			placed.append(brick)
		if not _fits(placed):
			continue
		var covered: Array = []
		for at: Vector2i in shape["cells"]:
			covered.append(at + by)
			level["reserved"][at + by] = true
		_lay(placed, name, k, "furniture", covered, base)
		return true
	return false


static func _centre(cells: Array, by: Vector2i = Vector2i.ZERO) -> Vector2:
	var sum := Vector2.ZERO
	for at: Vector2i in cells:
		sum += Vector2(at + by) + Vector2(0.5, 0.5)
	return sum / maxf(1.0, cells.size())


## The furniture's bricks with its tones chosen by the seed: each colour
## that has alternatives becomes one of them, the same one throughout.
func _recoloured(name: String, rng: RandomNumberGenerator) -> Array:
	var def: Dictionary = FURNITURE.get(name, {})
	var tones: Dictionary = def.get("tones", {})
	var chosen: Dictionary = {}
	for colour: Variant in tones:
		var choices: Array = tones[colour]
		chosen[int(colour)] = int(choices[rng.randi_range(0, choices.size() - 1)])
	var out: Array = []
	for raw: Dictionary in _bricks_of(name):
		var brick: Dictionary = raw.duplicate()
		var colour: int = int(brick.get("color", 71))
		if chosen.has(colour):
			brick["color"] = chosen[colour]
		out.append(brick)
	return out


## A piece of furniture turned a number of quarter turns about +y and moved
## so the studs it covers start at 0, 0: {"bricks", "cells", "tall"}.
## [param bricks] is it in this call's colours, in the order of its own
## definition, which is what is measured once under [param name].
##
## Turned as transforms and read back as placements, the way the lattice
## itself reads a brick, so a part on its side stays on its side and every
## stud stays on its stud.
func _shape(name: String, bricks: Array, turns: int) -> Dictionary:
	var key: String = "%s|%d" % [name, turns]
	var geometry: Dictionary = _shapes.get(key, {})
	if geometry.is_empty():
		geometry = _measure_shape(_bricks_of(name) if FURNITURE.has(name)
			else bricks, turns)
		_shapes[key] = geometry
	# The same geometry, in this call's colours.
	var out: Array = []
	var placed: Array = geometry["bricks"]
	for n: int in placed.size():
		var brick: Dictionary = (placed[n] as Dictionary).duplicate()
		brick["color"] = (bricks[n] as Dictionary).get("color", brick["color"])
		out.append(brick)
	return {"bricks": out, "cells": geometry["cells"], "tall": geometry["tall"]}


func _measure_shape(bricks: Array, turns: int) -> Dictionary:
	var spin := Basis(Vector3.UP, turns * PI * 0.5)
	var turned: Array = []
	for raw: Dictionary in bricks:
		var mesh: Lbm.PartMesh = _library.mesh_for(str(raw["part"]))
		if mesh == null:
			return {"bricks": [], "cells": [], "tall": 0}
		var at: Transform3D = _assistant._transform(Assistant.Placement.from_dict(raw), mesh)
		var basis: Basis = BrickLattice.snap_basis(spin * at.basis)
		var origin: Vector3 = spin * at.origin
		var face: String = BrickLattice.face_of(basis)
		var rot: int = BrickLattice.turns_about(basis, face)
		var square: Basis = BrickLattice.basis_for(face, rot)
		var corner: Vector3i = _assistant._corner_cell(mesh, str(raw["part"]), square)
		var cell := Vector3i(int(round(origin.x / BrickLattice.CELL)),
			int(round(origin.y / BrickLattice.CELL)),
			int(round(origin.z / BrickLattice.CELL)))
		var low: Vector3i = cell + corner
		var one: Dictionary = raw.duplicate()
		one["face"] = face
		one["rot"] = rot
		one["x"] = float(low.x) / ACROSS
		one["y"] = float(low.y) / UP
		one["z"] = float(low.z) / ACROSS
		turned.append(one)
	# The studs it covers, from the boxes the check will use.
	var studs: Dictionary = {}
	var tall: int = 0
	var lo := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
	for brick: Dictionary in turned:
		var packed: PackedInt32Array = _boxes(brick)
		for n: int in range(0, packed.size(), 6):
			for sx: int in range(_floor_div(packed[n], ACROSS),
					_floor_div(packed[n + 3] - 1, ACROSS) + 1):
				for sz: int in range(_floor_div(packed[n + 2], ACROSS),
						_floor_div(packed[n + 5] - 1, ACROSS) + 1):
					studs[Vector2i(sx, sz)] = true
					lo = Vector2i(mini(lo.x, sx), mini(lo.y, sz))
			tall = maxi(tall, ceili(float(packed[n + 4]) / UP))
	var cells: Array = []
	for at: Vector2i in studs:
		cells.append(at - lo)
	for brick: Dictionary in turned:
		brick["x"] = snappedf(float(brick["x"]) - lo.x, 0.1)
		brick["z"] = snappedf(float(brick["z"]) - lo.y, 0.1)
	return {"bricks": turned, "cells": cells, "tall": tall}


static func _floor_div(value: int, by: int) -> int:
	return int(floor(float(value) / by))


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for n: int in range(list.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, n)
		var keep: Variant = list[n]
		list[n] = list[other]
		list[other] = keep


# -- the answer ----------------------------------------------------------


func answer() -> Dictionary:
	var said := PackedStringArray()
	var report: Array = []
	var columns: int = 0
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var open: Dictionary = {}
	for k: int in _floors.size():
		var level: Dictionary = _floors[k]
		var furniture: Array = []
		for item: Dictionary in _items:
			if int(item["floor"]) == k and item["role"] == "furniture" \
					and not item.has("gone"):
				furniture.append(item["name"])
		columns += (level["columns"] as Array).size()
		if not str(level["open"]).is_empty():
			open[level["open"]] = int(open.get(level["open"], 0)) + 1
		var room: String = str(level["room"])
		var line: String = "  %s at y=%d" % [room, int(level["y"])]
		if bool(level["guessed"]):
			line += " (for \"%s\")" % level["said"]
		if bool(level["existing"]):
			line += ", on the floor already there"
		line += ": " + (", ".join(PackedStringArray(_counted(furniture)))
			if not furniture.is_empty() else "nothing fitted")
		if level.has("climb"):
			line += "; %s up to the %s" % [level["climb"], _floors[k + 1]["room"]]
		var missed: Array = level["missed"]
		if not missed.is_empty():
			line += " (no room for %s)" % ", ".join(PackedStringArray(_counted(missed)))
		said.append(line)
		report.append({"room": room, "y": level["y"], "furniture": furniture,
			"studs": (level["cells"] as Dictionary).size(),
			"climb": str(level.get("climb", "")),
			"columns": (level["columns"] as Array).size() + (level["props"] as Array).size(),
			"open": level["open"], "existing": level["existing"]})
		for at: Vector2i in level["cells"]:
			low = Vector3(minf(low.x, at.x), minf(low.y, float(level["y"])), minf(low.z, at.y))
			high = Vector3(maxf(high.x, at.x + 1), maxf(high.y, float(level["y"]) + STOREY),
				maxf(high.z, at.y + 1))
	var side: String = ""
	var most: int = 0
	for way: String in open:
		if int(open[way]) > most:
			most = open[way]
			side = way
	var count: int = bricks().size()
	var head: String = "Laid %d floor%s and furnished %s, %d parts" % [
		_floors.size(), "" if _floors.size() == 1 else "s",
		"it" if _floors.size() == 1 else "them", count]
	if columns > 0:
		head += ", the floors held up on %d column%s" % [columns, "" if columns == 1 else "s"]
	head += (", open to the %s (%s):" % [VIEWS[side], side] if not side.is_empty()
		else ". The inside is walled all round, so none of this shows: leave a "
		+ "side open (a prism's open, or take the back wall's bricks out) for "
		+ "the rooms to be seen:")
	var tail: String = ("\nA room reads as one with somebody in it: stand a figure "
		+ "in each with add_minifig.")
	return {"bricks": bricks(), "summary": head + "\n" + "\n".join(said) + tail,
		"view": VIEWS.get(side, "corner"), "floors": report,
		"box": AABB(Vector3(low.x * 20.0, low.y * 8.0, low.z * 20.0),
			Vector3((high.x - low.x) * 20.0, (high.y - low.y) * 8.0,
				(high.z - low.z) * 20.0)) if low.x < INF else AABB()}


## "bookcase x 2, table" from a list with repeats.
static func _counted(names: Array) -> Array:
	var order: Array = []
	var times: Dictionary = {}
	for name: Variant in names:
		if not times.has(name):
			order.append(name)
		times[name] = int(times.get(name, 0)) + 1
	var out: Array = []
	for name: Variant in order:
		out.append("%s x %d" % [name, times[name]] if int(times[name]) > 1 else str(name))
	return out
