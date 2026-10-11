## Prints drawn in the app: where they go on a part, the part file that
## carries them, and the part built from it with the picture where LDView
## puts it.
##
##   godot --headless --path . --script src/dev/print_probe.gd
##
## The claim of PartPrints is that a picture drawn on an area's canvas
## lands on the part where it was drawn, in the app and in any program
## that reads LDraw's !TEXMAP — so the projection is checked against the
## spec's points (a torso's front corner is the picture's top-left
## corner, a head's front is the middle of its face picture, right on the
## part is right in the picture as seen from outside), and every corner of
## the built part's printed surfaces is checked to carry the coordinates
## the projection gives its position. Then the plain part's geometry and
## connectors are kept to the triangle, the file travels in a model as
## LDraw's MPD spec carries pictures and comes back byte for byte in a
## library that never saw it, a figure wearing the print stands as one
## wearing the plain part, and a print LEGO made can be started from.
##
## Made parts go to user://print_probe_parts/, never the person's own.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary

const PROBE_DIR := "user://print_probe_parts/"


func _initialize() -> void:
	_forget(PROBE_DIR)
	_forget(PROBE_DIR + "elsewhere/")
	CustomParts.dir = PROBE_DIR
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return

	print("\nwhere a print can go")
	var head: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3626c")
	_ok(head.size() == 2 and head[0].key == "face" and head[0].method == "CYLINDRICAL"
			and is_equal_approx(head[0].angle, 180.0) and head[1].key == "back",
		"3626c: its face and the back of its head, each half way round its cylinder (%s)"
			% _keys(head))
	if head.size() == 2:
		var face: PartPrints.Area = head[0]
		_ok(face.size.x > 380 and face.size.x < 440 and face.size.y > 170 and face.size.y < 210,
			"the face canvas is the face unrolled at 10 pixels an LDU: %s" % face.size)
		_ok(_covered(face.mask) > 0.9, "the whole canvas is head to print on (%.0f%%)"
			% (_covered(face.mask) * 100.0))
		var front: Vector2 = face.uv(Vector3(0, 10, -13))
		var right: Vector2 = face.uv(Vector3(9, 10, -9))
		var low: Vector2 = face.uv(Vector3(0, 15, -13))
		_ok(absf(front.x - 0.5) < 1e-4 and right.x > 0.7 and low.y > front.y,
			"LDView's cylinder: the front of the face is the middle of the picture, the "
				+ "part's +X is right in it seen from outside, down is down (%s %s %s)"
				% [front, right, low])
	var torso: Array[PartPrints.Area] = PartPrints.areas_for(_library, "973")
	_ok(torso.size() == 2 and torso[0].key == "front" and torso[1].key == "back",
		"973: its front and its back (%s)" % _keys(torso))
	if torso.size() == 2:
		var front: PartPrints.Area = torso[0]
		_ok(front.p1.is_equal_approx(Vector3(-19.5, -0.5, -10))
				and front.p2.is_equal_approx(Vector3(19.5, -0.5, -10))
				and front.p3.is_equal_approx(Vector3(-19.5, 32.5, -10)),
			"the front's TEXMAP points: top left, top right, bottom left as seen from the "
				+ "front, half an LDU outside the face (%s %s %s)" % [front.p1, front.p2, front.p3])
		var back: PartPrints.Area = torso[1]
		_ok(back.p1.x > 0.0 and back.p2.x < 0.0,
			"the back's picture runs right to left in X, as it is seen from behind")
		# A trapezoid: nothing at the shoulders' corners, all of it at the
		# bottom.
		_ok(front.mask.get_pixel(3, 3).a == 0.0
				and front.mask.get_pixel(front.size.x / 2, front.size.y / 2).a > 0.0
				and front.mask.get_pixel(10, front.size.y - 8).a > 0.0,
			"the front is a trapezoid on its canvas: narrow at the shoulders")
	var legs: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3816c",
		{"hips": "3815b", "left": "3817c"})
	_ok(legs.size() == 1 and legs[0].parts.size() == 3,
		"3816c with its hips and left leg: one front over all three (%s, %d parts)"
			% [_keys(legs), legs[0].parts.size() if not legs.is_empty() else 0])
	var tile: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3068b")
	_ok(not tile.is_empty() and tile[0].key == "top" and tile[0].size == Vector2i(410, 410),
		"3068b: its top, 41 LDU square with the spare edge (%s)" % _keys(tile))
	var slope: Array[PartPrints.Area] = PartPrints.areas_for(_library, "3039")
	_ok(_keys(slope).contains("slope"), "3039: its slope (%s)" % _keys(slope))

	print("\ndrawing")
	var paint := PrintPaint.new(100, 60)
	paint.begin()
	paint.brush_to(Vector2(10, 10), 3.0, Color.BLACK)
	paint.brush_to(Vector2(30, 10), 3.0, Color.BLACK)
	paint.end()
	_ok(paint.layer().image.get_pixel(20, 10).a == 1.0
			and paint.layer().image.get_pixel(20, 20).a == 0.0,
		"a brush stroke marks along its way and nowhere else")
	paint.mirror = true
	paint.begin()
	paint.brush_to(Vector2(10, 40), 2.0, Color.RED)
	paint.end()
	_ok(paint.layer().image.get_pixel(89, 40).r > 0.9, "mirrored, it is drawn again across the middle")
	paint.mirror = false
	paint.rectangle(Vector2(50, 30), Vector2(70, 50), 1.0, Color.BLUE, false)
	paint.fill(Vector2i(60, 40), Color.YELLOW)
	_ok(paint.layer().image.get_pixel(60, 40).is_equal_approx(Color.YELLOW)
			and paint.layer().image.get_pixel(80, 40).a == 0.0,
		"a fill fills inside a drawn box and stops at its edge")
	paint.undo()
	_ok(paint.layer().image.get_pixel(60, 40).a == 0.0, "undo takes the fill back")
	paint.redo()
	_ok(paint.layer().image.get_pixel(60, 40).is_equal_approx(Color.YELLOW), "redo puts it back")
	paint.add_layer("Words")
	paint.text(Vector2(4, 56), "LEGO", 14, Color.WHITE)
	_ok(not paint.layer().image.is_invisible() and paint.layers.size() == 2,
		"words are written on a layer of their own")
	paint.set_visible(1, false)
	_ok(paint.composite().get_pixel(60, 40).is_equal_approx(Color.YELLOW),
		"the picture is every layer shown, bottom first")

	print("\na face, printed")
	var drawn: Dictionary = {}
	if head.size() == 2:
		drawn = _a_face(head[0], head[1])
	var made: Dictionary = PartPrints.make(_library, "3626c", head, drawn, "Probe Grin")
	var ids: Array = made["ids"]
	_ok(str(made["problem"]).is_empty() and ids.size() == 1 and str(ids[0]).begins_with("bw-3626c-p"),
		"made %s %s" % [ids, made["problem"]])
	if ids.size() == 1:
		_check_print(str(ids[0]), "3626c", 2)
		var again: Dictionary = PartPrints.make(_library, "3626c", head, drawn, "Probe Grin")
		_ok(again["ids"] == ids, "the same print twice is the same part")

	print("\na torso front and back, a pair of legs, a tile")
	var torso_drawn: Dictionary = {}
	for area: PartPrints.Area in torso:
		var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
		PrintPaint.disc(picture, Vector2(area.size) * 0.5, 40.0, Color(0.8, 0.1, 0.1))
		torso_drawn[area.key] = picture
	var torso_made: Dictionary = PartPrints.make(_library, "973", torso, torso_drawn, "Probe Shirt")
	_ok(str(torso_made["problem"]).is_empty() and (torso_made["ids"] as Array).size() == 1,
		"a torso printed front and back %s" % torso_made)
	if (torso_made["ids"] as Array).size() == 1:
		_check_print(str(torso_made["ids"][0]), "973", 2)
	var legs_drawn: Dictionary = {}
	var leg_ids: Array = []
	if legs.size() == 1:
		var picture := Image.create_empty(legs[0].size.x, legs[0].size.y, false, Image.FORMAT_RGBA8)
		picture.fill(Color(0.1, 0.3, 0.8))
		legs_drawn["legs"] = picture
		var legs_made: Dictionary = PartPrints.make(_library, "3816c", legs, legs_drawn, "Probe Jeans")
		leg_ids = legs_made["ids"]
		_ok(leg_ids.size() == 3, "one print over the legs makes the hips and both legs %s" % legs_made)
		for id: String in leg_ids:
			_check_print(id, PartPrints.base_of(id), 1)
	var tile_made: Dictionary = {}
	if not tile.is_empty():
		var picture := Image.create_empty(tile[0].size.x, tile[0].size.y, false, Image.FORMAT_RGBA8)
		PrintPaint.draw_rectangle(picture, Vector2(40, 40), Vector2(370, 370), 0.0, Color.BLACK, true)
		tile_made = PartPrints.make(_library, "3068b", tile.slice(0, 1), {"top": picture}, "Probe Sign")
		_ok((tile_made["ids"] as Array).size() == 1, "a printed 2 x 2 tile %s" % tile_made)
		if (tile_made["ids"] as Array).size() == 1:
			var mesh: Lbm.PartMesh = _library.mesh_for(str(tile_made["ids"][0]))
			var up: bool = true
			for n: int in mesh.prints:
				var normals: PackedVector3Array = mesh.surfaces[n].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
				for normal: Vector3 in normals:
					up = up and normal.y > 0.99
			_ok(mesh.prints.size() == 1 and up, "only the tile's top carries the print")

	print("\nin a figure")
	if ids.size() == 1 and leg_ids.size() == 3:
		var plain := Minifig.new()
		var printed := Minifig.new()
		printed.parts["head"] = ids[0]
		printed.choose(_library, "legs", leg_ids[1])
		_ok(printed.part("hips") == leg_ids[0],
			"choosing the printed legs brings their printed hips (%s)" % printed.part("hips"))
		var a: Array[Dictionary] = plain.assemble(_library)
		var b: Array[Dictionary] = printed.assemble(_library)
		var same: bool = a.size() == b.size()
		var swapped: Dictionary = {}
		for n: int in mini(a.size(), b.size()):
			same = same and (a[n]["at"] as Transform3D).is_equal_approx(b[n]["at"])
			if str(a[n]["part"]) != str(b[n]["part"]):
				swapped[a[n]["part"]] = b[n]["part"]
		_ok(same and swapped.size() == 4 and swapped.get("3817c", "") == leg_ids[2]
				and swapped.get("3626cp01", "") == ids[0],
			"a figure in the prints stands as the plain one does, every part where it was, "
				+ "the printed left leg on the left (%s)" % swapped)
		printed.choose(_library, "legs", Minifig.PLAIN_LEGS)
		_ok(printed.part("hips") == Minifig.PLAIN_HIPS, "the plain legs give the plain hips back")
		printed.choose(_library, "legs", leg_ids[1])
		var offered: Array = Minifig.choices(_library, "head").map(
			func(info: PartLibrary.PartInfo) -> String: return info.id)
		_ok(not offered.is_empty() and offered[0] == ids[0],
			"the print is offered first in the head slot, as made here")
		var frame: Variant = Minifig.frame_of(b, _library)
		_ok(frame is Transform3D and (frame as Transform3D).is_equal_approx(Transform3D.IDENTITY),
			"read back off the model, the figure is found where it stands")

		print("\nin a model file")
		var placements: Array = []
		for item: Dictionary in b:
			var placement := LdrModel.Placement.new(item["part"], item["color"], item["at"], 0)
			placements.append(placement)
		var used: Array = []
		for item: Dictionary in b:
			used.append(item["part"])
		var text: String = LdrModel.write_ldr(placements, "Probe", "Brickworks", {},
			CustomParts.sources_for(_library, used))
		# Kept, to open in another LDraw program: LDView draws the prints.
		var kept: String = ProjectSettings.globalize_path("res://shots/print_probe.mpd")
		DirAccess.make_dir_recursive_absolute(kept.get_base_dir())
		var out: FileAccess = FileAccess.open(kept, FileAccess.WRITE)
		if out != null:
			out.store_string(text)
			out.close()
		var data_lines: int = 0
		var longest: int = 0
		for line: String in text.split("\n"):
			if line.begins_with("0 !: "):
				data_lines += 1
				longest = maxi(longest, line.length() - 5)
		_ok(text.contains("0 !DATA %s-face.png" % ids[0]) and text.contains("0 !TEXMAP START CYLINDRICAL")
				and text.contains("0 !DATA %s-legs.png" % PartPrints.id_for("3816c",
					str(leg_ids[1]).get_slice("-p", 1))) and longest <= 80,
			"the file carries each picture as a !DATA section, %d lines of base64 none over 80"
				% data_lines)
		var read: LdrModel = LdrModel.parse(text, "probe.mpd")
		var face_name: String = "%s-face.png" % ids[0]
		var original: PackedByteArray = _library.mesh_for(ids[0]).print_files.get(face_name,
			PackedByteArray())
		_ok(read.embedded_data.get(face_name, PackedByteArray()) == original and not original.is_empty(),
			"read back, its pictures are the same bytes (%d)" % original.size())
		_ok(read.embedded_parts.size() == 4 and read.submodels.size() == 1,
			"and its four printed parts are parts, not sub-models (%d)" % read.embedded_parts.size())
		CustomParts.dir = PROBE_DIR + "elsewhere/"
		var fresh := PartLibrary.new()
		fresh.load_catalogue()
		var carried: Dictionary = CustomParts.take_from(fresh, read)
		_ok((carried["added"] as Array).size() == 4 and (carried["problems"] as Array).is_empty(),
			"a library that never saw them builds all four from the file %s" % carried)
		var rebuilt: Lbm.PartMesh = fresh.mesh_for(ids[0])
		_ok(rebuilt != null and rebuilt.prints.size() == 2
				and rebuilt.print_files.get(face_name, PackedByteArray()) == original,
			"the printed head comes back with its two pictures")
		_ok(FileAccess.file_exists(PROBE_DIR + "elsewhere/" + face_name),
			"and keeps them beside it, to build again next time")
		var check := PartLibrary.new()
		check.load_catalogue()
		var loaded: int = CustomParts.load_all(check)
		var reloaded: Lbm.PartMesh = check.mesh_for(ids[0])
		_ok(loaded == 4 and reloaded != null and reloaded.prints.size() == 2,
			"a restart finds them kept, pictures and all (%d)" % loaded)
		CustomParts.dir = PROBE_DIR

	print("\nstarting from a print LEGO made")
	if head.size() == 2:
		var grin: Image = PartPrints.picture_of(_library, "3626cp01", head[0])
		var dark: int = _count(grin, func(c: Color) -> bool: return c.a > 0.0 and c.v < 0.3)
		var middle: Rect2i = Rect2i(head[0].size.x / 4, 0, head[0].size.x / 2, head[0].size.y)
		var off_middle: int = _count(grin, func(c: Color) -> bool: return c.a > 0.0, middle, true)
		_ok(dark > 500 and off_middle == 0,
			"3626cp01's grin on 3626c's face: %d black pixels, all in the middle half" % dark)
		var behind: Image = PartPrints.picture_of(_library, "3626cp01", head[1])
		_ok(behind.is_invisible(), "and nothing on the back of the head")
	var shirt: Image = PartPrints.picture_of(_library, "973p01", torso[0]) if not torso.is_empty() \
		else Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	_ok(_count(shirt, func(c: Color) -> bool: return c.a > 0.0) > 5000,
		"973p01's stripes on 973's front")
	var heads: Array[PartLibrary.PartInfo] = PartPrints.prints_of(_library, "3626c")
	_ok(heads.size() >= 20 and heads[0].in_sets >= heads[heads.size() - 1].in_sets,
		"%d of LEGO's printed 3626c heads to start from, the most used first (%s)"
			% [heads.size(), heads[0].id if not heads.is_empty() else ""])

	_forget(PROBE_DIR + "elsewhere/")
	_forget(PROBE_DIR)
	if _failures == 0:
		print("\na print drawn here is on the part where it was drawn, in the app and the file")
	else:
		print("\n%d check%s failed" % [_failures, "" if _failures == 1 else "s"])
	quit(1 if _failures > 0 else 0)


## A grin: two black eyes and a mouth on the face, a red stripe behind.
func _a_face(face: PartPrints.Area, back: PartPrints.Area) -> Dictionary:
	var paint := PrintPaint.new(face.size.x, face.size.y)
	var middle: float = face.size.x * 0.5
	paint.mirror = true
	paint.begin()
	paint.brush_to(Vector2(middle - 40, 70), 9.0, Color.BLACK)
	paint.end()
	paint.mirror = false
	paint.ellipse(Vector2(middle - 50, 95), Vector2(middle + 50, 135), 4.0, Color.BLACK, false)
	var behind := Image.create_empty(back.size.x, back.size.y, false, Image.FORMAT_RGBA8)
	behind.fill_rect(Rect2i(0, 20, back.size.x, 30), Color(0.8, 0.1, 0.1))
	return {"face": paint.composite(), "back": behind}


## Everything a printed part has to be: the plain part's geometry and
## connectors, its pictures on surfaces of their own, and every printed
## corner carrying the coordinates its position projects to.
func _check_print(id: String, base: String, pictures: int) -> void:
	var made: Lbm.PartMesh = _library.mesh_for(id)
	var plain: Lbm.PartMesh = _library.mesh_for(base)
	if made == null or plain == null:
		_ok(false, "%s has geometry" % id)
		return
	var text: String = _library.custom_source(id)
	_ok(PartPrints.is_print(text) and PartPrints.base_in(text) == base
			and text.count("0 !TEXMAP START") == pictures and text.count("0 !TEXMAP END") == pictures,
		"%s's file: %d TEXMAP blocks, made from %s" % [id, pictures, base])
	_ok(made.triangle_count == plain.triangle_count and made.boxes == plain.boxes
			and made.connectors.size() == plain.connectors.size()
			and _near(made.bounds.position, plain.bounds.position)
			and _near(made.bounds.size, plain.bounds.size),
		"%s is %s to the triangle, the collision cell and the connector (%d triangles, %d connectors)"
			% [id, base, made.triangle_count, made.connectors.size()])
	var moved: int = 0
	for n: int in made.connectors.size():
		if not made.connectors[n].position.is_equal_approx(plain.connectors[n].position):
			moved += 1
	_ok(moved == 0, "every connector where %s has it" % base)
	_ok(made.prints.size() == pictures and made.print_files.size() == pictures,
		"%d printed surfaces, each with its picture" % made.prints.size())
	var worst: float = 0.0
	var corners: int = 0
	var inside: int = 0
	for line: String in text.split("\n"):
		if not line.begins_with("0 !TEXMAP START"):
			continue
		var words: PackedStringArray = line.split(" ", false)
		var area := PartPrints.Area.new()
		area.method = words[3]
		area.p1 = Vector3(words[4].to_float(), words[5].to_float(), words[6].to_float())
		area.p2 = Vector3(words[7].to_float(), words[8].to_float(), words[9].to_float())
		area.p3 = Vector3(words[10].to_float(), words[11].to_float(), words[12].to_float())
		area.angle = words[13].to_float() if area.method == "CYLINDRICAL" else 0.0
		var picture: String = words[words.size() - 1]
		for n: int in made.prints:
			if (made.prints[n] as Texture2D).resource_name != picture:
				continue
			var arrays: Array = made.surfaces[n].surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for v: int in positions.size():
				var p: Vector3 = positions[v]
				var wanted: Vector2 = area.uv(Vector3(p.x, -p.y, -p.z))
				worst = maxf(worst, wanted.distance_to(uvs[v]))
				corners += 1
				if uvs[v].x >= -0.05 and uvs[v].x <= 1.05 and uvs[v].y >= -0.05 and uvs[v].y <= 1.05:
					inside += 1
	_ok(corners > 0 and worst < 1e-4 and inside == corners,
		"all %d printed corners carry the coordinates their TEXMAP gives them, on the picture "
			% corners + "(worst %.6f)" % worst)


## Within the 64th of an LDU a mesh is stored to: the library's bounds are
## worked out before that, the made part's after.
func _near(a: Vector3, b: Vector3) -> bool:
	return (a - b).abs().max_axis_index() >= 0 and (a - b).length() < 0.02


func _covered(mask: Image) -> float:
	return float(_count(mask, func(c: Color) -> bool: return c.a > 0.0)) \
		/ (mask.get_width() * mask.get_height())


func _count(image: Image, test: Callable, within: Rect2i = Rect2i(), outside: bool = false) -> int:
	var found: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if within.size != Vector2i.ZERO:
				var in_it: bool = within.has_point(Vector2i(x, y))
				if in_it == outside:
					continue
			if test.call(image.get_pixel(x, y)):
				found += 1
	return found


func _keys(areas: Array[PartPrints.Area]) -> String:
	return ",".join(areas.map(func(a: PartPrints.Area) -> String: return a.key))


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir + name + "/")
	DirAccess.remove_absolute(dir)
