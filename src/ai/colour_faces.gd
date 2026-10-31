## A model's outside by colour, read the way its pictures show it: from each
## of its four sides and from above, every part's box drawn nearest first, half
## a stud across and a plate up to a cell. What the surface pass's colour
## findings (SurfacePass, "colour") are read from.
##
## Why. Against the 44 real sets of proof (d5base, 2026-10-30) the judge
## preferred the set's colour in 59 of 88 verdicts, and in 41 of those 59 it
## said the same thing: ours is "mostly one flat expanse" of a colour, "with few
## accents", where the set breaks it with a second colour, the parts that do
## something in their own colour and printed detail. Read this way, 21 of our
## 44 designs had a side or the top that one connected colour covered more than
## 55% of; they won 6 of their 42 colour verdicts, the other 23 won 23 of 46.
## Nothing in the app read it: the one-colour advice speaks above 75% of the
## parts, which no finished design reaches, and no pass looked at colour.
##
## A face is the largest region of one colour, connected in a view, that
## covers EXPANSE or more of what that view shows. Sets have them too (56 of
## 150 measured the same way, a black car, a silver tower): the finding says
## where, and the design keeps it where the subject is that colour.
class_name ColourFaces
extends RefCounted

## A cell: half a stud across, a plate up (LDU).
const ACROSS := 10.0
const UP := 8.0
## The share of a view one connected colour must cover to be a flat face.
const EXPANSE := 0.55
## And the fewest cells it must cover: a face of four studs by four bricks.
const SMALLEST := 96
## Below this many parts there was no real chance to vary (Assistant
## .WORTH_COLOURING says the same of the one-colour advice).
const FEWEST_PARTS := 40
## The views, as [name, the axis looked along, which way]: "+x" looks at the
## model's +x side from beyond it.
const VIEWS: Array = [["+x", 0, 1], ["-x", 0, -1], ["+z", 2, 1], ["-z", 2, -1], ["top", 1, 1]]

## The darker tone a set breaks a face of each colour with: a dark tan string
## course on tan, a dark grey line on light grey, a black sill on yellow. The
## commonest plastic colours; any other has no line laid.
const TONE: Dictionary = {
	0: 72, 1: 272, 2: 288, 3: 272, 4: 320, 5: 26, 10: 2, 13: 5, 14: 0, 15: 71, 19: 28,
	22: 85, 25: 484, 26: 85, 27: 2, 28: 70, 29: 5, 30: 85, 31: 30, 70: 308, 71: 72,
	72: 0, 73: 1, 78: 84, 84: 70, 92: 84, 115: 2, 191: 25, 212: 73, 226: 14, 272: 0,
	288: 0, 308: 0, 320: 0, 321: 272, 322: 321, 323: 322, 326: 27, 330: 288, 335: 320,
	353: 4, 378: 288, 379: 272, 484: 70,
}


## One flat face: the view it is seen from, its colour, how much of that view
## it covers, and the parts that show in it with how many of its cells each.
class Face extends RefCounted:
	var view: String = ""
	var colour: int = 0
	var share: float = 0.0
	var cells: Array[Vector2i] = []
	## Brick id -> the cells of the face it shows in.
	var owners: Dictionary = {}
	## Its bricks' box, LDU, in the world.
	var box := AABB()


## The outside: {"shares": {colour: share of all five views}, "faces":
## Array[Face], the biggest first}. Nothing for a model under FEWEST_PARTS.
static func read(bricks: Array[BrickWorld.Brick], library: PartLibrary) -> Dictionary:
	var out: Dictionary = {"shares": {}, "faces": []}
	var boxes: Array = []        # [AABB, colour, id]
	var whole := AABB()
	for brick: BrickWorld.Brick in bricks:
		if brick.hidden:
			continue
		var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
		var mesh: Lbm.PartMesh = library.mesh_for(brick.part_id)
		if info == null or mesh == null or info.family_category() == "Baseplate":
			continue
		var box: AABB = (brick.transform * mesh.bounds).abs()
		whole = box if boxes.is_empty() else whole.merge(box)
		boxes.append([box, brick.color_code, brick.id])
	if boxes.size() < FEWEST_PARTS:
		return out
	var counted: Dictionary = {}
	var total: int = 0
	var faces: Array[Face] = []
	for view: Array in VIEWS:
		var drawn: Dictionary = _draw(boxes, whole, int(view[1]), int(view[2]))
		var owner: PackedInt32Array = drawn["owner"]
		var colour_of: PackedInt32Array = drawn["colour"]
		var filled: int = 0
		for n: int in owner.size():
			if owner[n] < 0:
				continue
			filled += 1
			counted[colour_of[n]] = int(counted.get(colour_of[n], 0)) + 1
		total += filled
		var face: Face = _largest(drawn, boxes, filled)
		if face != null and face.share >= EXPANSE and face.cells.size() >= SMALLEST:
			face.view = str(view[0])
			faces.append(face)
	for code: int in counted:
		(out["shares"] as Dictionary)[code] = float(counted[code]) / float(maxi(1, total))
	# The biggest first: a course laid through a long side runs round the
	# ends, and lines them too.
	faces.sort_custom(func(a: Face, b: Face) -> bool: return a.cells.size() > b.cells.size())
	out["faces"] = faces
	return out


## One view drawn: for each cell, the index into [param boxes] of the box
## nearest the eye and its colour, -1 where nothing is. Image axes: along the
## two axes that are not [param axis], in the order x, y, z.
static func _draw(boxes: Array, whole: AABB, axis: int, way: int) -> Dictionary:
	var across: Array[int] = [0, 1, 2]
	across.erase(axis)
	var a: int = across[0]
	var b: int = across[1]
	var size_a: float = ACROSS if a != 1 else UP
	var size_b: float = ACROSS if b != 1 else UP
	var wide: int = int(ceil(whole.size[a] / size_a)) + 1
	var tall: int = int(ceil(whole.size[b] / size_b)) + 1
	var depth := PackedFloat32Array()
	depth.resize(wide * tall)
	depth.fill(-INF)
	var owner := PackedInt32Array()
	owner.resize(wide * tall)
	owner.fill(-1)
	var colour := PackedInt32Array()
	colour.resize(wide * tall)
	for n: int in boxes.size():
		var box: AABB = boxes[n][0]
		var near: float = box.end[axis] if way > 0 else -box.position[axis]
		# A box's edge on a cell's edge does not take the next cell.
		var i0: int = int(floor((box.position[a] - whole.position[a]) / size_a + 0.05))
		var i1: int = maxi(i0 + 1, int(ceil((box.end[a] - whole.position[a]) / size_a - 0.05)))
		var j0: int = int(floor((box.position[b] - whole.position[b]) / size_b + 0.05))
		var j1: int = maxi(j0 + 1, int(ceil((box.end[b] - whole.position[b]) / size_b - 0.05)))
		for i: int in range(maxi(0, i0), mini(wide, i1)):
			for j: int in range(maxi(0, j0), mini(tall, j1)):
				var at: int = i * tall + j
				if near > depth[at]:
					depth[at] = near
					owner[at] = n
					colour[at] = int(boxes[n][1])
	return {"owner": owner, "colour": colour, "wide": wide, "tall": tall}


## The largest region of one colour, connected across cells, as a Face, or null.
static func _largest(drawn: Dictionary, boxes: Array, filled: int) -> Face:
	var owner: PackedInt32Array = drawn["owner"]
	var colour: PackedInt32Array = drawn["colour"]
	var wide: int = int(drawn["wide"])
	var tall: int = int(drawn["tall"])
	var seen := PackedByteArray()
	seen.resize(owner.size())
	var best: Array[int] = []
	for start: int in owner.size():
		if owner[start] < 0 or seen[start] == 1:
			continue
		var region: Array[int] = []
		var queue: Array[int] = [start]
		seen[start] = 1
		while not queue.is_empty():
			var at: int = queue.pop_back()
			region.append(at)
			var i: int = at / tall
			var j: int = at % tall
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var u: int = i + step.x
				var v: int = j + step.y
				if u < 0 or v < 0 or u >= wide or v >= tall:
					continue
				var next: int = u * tall + v
				if seen[next] == 0 and owner[next] >= 0 and colour[next] == colour[start]:
					seen[next] = 1
					queue.append(next)
		if region.size() > best.size():
			best = region
	if best.is_empty():
		return null
	var face := Face.new()
	face.colour = colour[best[0]]
	face.share = float(best.size()) / float(maxi(1, filled))
	var first: bool = true
	for at: int in best:
		var cell := Vector2i(at / tall, at % tall)
		face.cells.append(cell)
		var entry: Array = boxes[owner[at]]
		var id: int = int(entry[2])
		if not face.owners.has(id):
			face.owners[id] = []
			face.box = entry[0] if first else face.box.merge(entry[0])
			first = false
		(face.owners[id] as Array).append(cell)
	return face


## The colours of a reading in a line, commonest first: "Yellow 59%, Dark
## Bluish Grey 31%, Black 6%", those over 2%.
static func said(shares: Dictionary, name_of: Callable) -> String:
	var codes: Array = shares.keys()
	codes.sort_custom(func(x: int, y: int) -> bool: return float(shares[x]) > float(shares[y]))
	var out := PackedStringArray()
	for code: int in codes:
		if float(shares[code]) < 0.02:
			break
		out.append("%s %d%%" % [str(name_of.call(code)), roundi(100.0 * float(shares[code]))])
	return ", ".join(out)


## How many colours cover at least [param least] of what shows.
static func colours_over(shares: Dictionary, least: float) -> int:
	var n: int = 0
	for code: int in shares:
		if float(shares[code]) >= least:
			n += 1
	return n
