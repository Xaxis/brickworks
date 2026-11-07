## A picture of a model file, for the system's file browser.
##
##   brickworks --headless --thumbnail MODEL PICTURE [SIZE]
##
## draws the .ldr, .mpd or .io at MODEL from the app's corner view (ModelShot's
## "corner") into a SIZE x SIZE PNG at PICTURE (256 when no size is given),
## on a clear ground, and exits 0; or says why not on stderr and exits 1. The
## Linux package's thumbnailer runs it (tools/release.py, THUMBNAILER), so a
## folder of models shows each model and not one icon over and over.
##
## Drawn here on the processor, a triangle at a time into a depth buffer, and
## not by the graphics card: a file browser runs its thumbnailers with no
## display and no graphics device (GNOME's in a bubblewrap sandbox: /usr read
## only, the file itself, an empty /tmp, no network), and an engine with no
## display draws nothing (ModelShot.possible). The geometry is the app's own
## (.lbm, the catalogue), the reading LdrModel's and StudioIo's, the camera
## ModelShot's: the same parts, placed where the app places them, seen from
## where the app's corner picture sees them, framed as it frames them.
##
## Reached from BrickworksLoop before the main scene loads, so the app's own
## start (several seconds of compiling and setting up) is never paid for a
## picture. So this names nothing beyond the reading it needs: every class
## named here is compiled with it.
class_name ModelThumbnail
extends RefCounted

const FLAG := "--thumbnail"
## What a file browser asks for most ("large", 256 px); a size given after
## the picture's path is used instead, kept to what a browser can ask for.
const SIZE := 256
const SMALLEST := 16
const BIGGEST := 1024
## Drawn at twice the size and scaled down, so an edge is smooth. Above
## 512 the picture is fine enough as drawn, and four times the pixels would
## cost more than a browser waits.
const OVERSAMPLE := 2

## ModelShot.ANGLES["corner"], the app's corner picture (thumbs_probe checks
## the two are one): named here and not read from there, since naming
## ModelShot would compile it and the app's 3D world with it.
const CORNER := Vector3(0.72, 0.52, 0.72)
## ModelShot's lights: the key and the fill, as the turns of a
## DirectionalLight3D, which shines along its -Z.
const KEY_TURN := Vector3(-42.0, -38.0, 0.0)
const FILL_TURN := Vector3(-14.0, 132.0, 0.0)
const AMBIENT := 0.50
const KEY := 0.58
const FILL := 0.22
## A tenth of margin round the model, as ModelShot frames it, and never
## narrower than its 40 LDU.
const MARGIN := 1.1
const NARROWEST := 40.0
## Where two parts meet, the picture darkened by this much: the app draws a
## line round every part, and without one a wall of bricks of one colour is
## one flat face.
const SEAM := 0.30
## A colour the palette has no number for.
const UNKNOWN_COLOUR := Color(0.62, 0.64, 0.66)
const LIBRARY := "res://assets/generated/"


## The command: args are the engine's (OS.get_cmdline_args); the exit code.
static func run(args: PackedStringArray) -> int:
	var at: int = args.find(FLAG)
	if at < 0 or at + 2 >= args.size():
		printerr("usage: brickworks --headless %s MODEL PICTURE [SIZE]" % FLAG)
		return 1
	var size: int = SIZE
	if at + 3 < args.size() and args[at + 3].is_valid_int():
		size = clampi(args[at + 3].to_int(), SMALLEST, BIGGEST)
	var made: Dictionary = make(args[at + 1], size)
	if not str(made.get("error", "")).is_empty():
		printerr("thumbnail: %s" % made["error"])
		return 1
	var image: Image = made["image"]
	var saved: int = image.save_png(args[at + 2])
	if saved != OK:
		printerr("thumbnail: cannot write %s (%s)" % [args[at + 2], error_string(saved)])
		return 1
	print("thumbnail: %s, %d of %d parts drawn, %d ms" % [args[at + 2].get_file(),
		int(made["drawn"]), int(made["parts"]), int(made["ms"])])
	return 0


## The picture of the model file at [param path], [param size] pixels
## square: {"image", "parts" placed, "drawn" of them (a part the library has
## not got is left out, and the rest drawn), "ms"}, or {"error"}.
static func make(path: String, size: int) -> Dictionary:
	var began: int = Time.get_ticks_msec()
	var read: Dictionary = model_text(path)
	if not str(read.get("error", "")).is_empty():
		return read
	var model: LdrModel = LdrModel.parse(str(read["text"]), path.get_file())
	var placed: Array[LdrModel.Placement] = model.flatten()
	# Every part placed and every sub-model's name: a sub-model named after
	# a part is the part, as the app reads it (LdrModel.flatten's known
	# parts), and the file is read again so where one is.
	var named: Dictionary = {}
	for placement: LdrModel.Placement in placed:
		named[placement.part_id] = true
	for key: String in model.submodels:
		named[key] = true
	var meshes: Dictionary = mesh_names(PackedStringArray(named.keys()))
	for key: String in model.submodels:
		if meshes.has(key):
			placed = model.flatten(meshes)
			break
	if placed.is_empty():
		return {"error": "there are no parts in %s" % path.get_file()}
	var shapes: Dictionary = _shapes(placed, meshes)
	var drawer := Drawer.new()
	drawer.colours = _colours()
	var image: Image = drawer.draw(placed, meshes, shapes, size)
	if image == null:
		return {"error": "none of the %d parts in %s is in the library" % [placed.size(),
			path.get_file()]}
	return {"image": image, "parts": placed.size(), "drawn": drawer.drawn,
		"ms": Time.get_ticks_msec() - began}


## The LDraw text of the model at [param path]: an .io's model.ldr
## (StudioIo), or the file itself. {"text"} or {"error"}.
static func model_text(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return {"error": "cannot read %s (%s)" % [path,
			error_string(FileAccess.get_open_error())]}
	if path.get_extension().to_lower() == "io":
		return StudioIo.model_ldr(bytes)
	return {"text": StudioIo._text_of(bytes)}


## Each part id of [param ids] the library has, and the name of its
## geometry (catalogue.json's "mesh"): id -> mesh.
##
## Found in the catalogue's text and not parsed whole: JSON.parse of its 16 MB
## and twenty-nine thousand parts is most of a second, the ids a model names
## are found in it in tens of milliseconds. tools/build_meshes.py writes each
## part's "id" first and its "mesh" a few fields on, with nothing between
## them in braces (thumbs_probe checks every part is found so).
static func mesh_names(ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	if ids.is_empty():
		return out
	var text: String = FileAccess.get_file_as_bytes(LIBRARY + "catalogue.json") \
		.get_string_from_utf8()
	var wanted := PackedStringArray()
	for id: String in ids:
		wanted.append(_escaped(id))
	var finder := RegEx.create_from_string(
		'\\{"id":"(' + "|".join(wanted) + ')",[^{}]*?"mesh":"([0-9a-f]+)"')
	for found: RegExMatch in finder.search_all(text):
		out[found.get_string(1)] = found.get_string(2)
	return out


static func _escaped(id: String) -> String:
	var out: String = ""
	for c: String in id:
		out += ("\\" + c) if "\\^$.|?*+()[]{}".contains(c) else c
	return out


## The geometry each mesh name of the parts placed: mesh -> Shape. Read on
## the engine's workers, the first on this thread, since a GDScript
## function's first run on two threads at once can take the engine down
## (WorkerTasks.first_here).
static func _shapes(placed: Array[LdrModel.Placement], meshes: Dictionary) -> Dictionary:
	var names := PackedStringArray()
	var seen: Dictionary = {}
	for placement: LdrModel.Placement in placed:
		var mesh: String = str(meshes.get(placement.part_id, ""))
		if not mesh.is_empty() and not seen.has(mesh):
			seen[mesh] = true
			names.append(mesh)
	var out: Dictionary = {}
	if names.is_empty():
		return out
	var lock := Mutex.new()
	var read_one := func(index: int) -> void:
		var shape: Shape = Shape.read(LIBRARY + "parts/" + names[index] + ".lbm")
		lock.lock()
		out[names[index]] = shape
		lock.unlock()
	read_one.call(0)
	if names.size() > 1:
		var rest := func(index: int) -> void: read_one.call(index + 1)
		var group: int = WorkerThreadPool.add_group_task(rest, names.size() - 1, -1, true,
			"thumbnail parts")
		WorkerThreadPool.wait_for_group_task_completion(group)
	return out


## The palette: LDraw colour code -> Color, alpha and all.
static func _colours() -> Dictionary:
	var out: Dictionary = {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY + "colors.json"))
	if not raw is Array:
		return out
	for item: Variant in raw:
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		var rgb: Array = entry.get("rgb", [158, 163, 168])
		out[int(entry.get("code", -1))] = Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0,
			float(rgb[2]) / 255.0, float(entry.get("alpha", 255)) / 255.0)
	return out


## A part's triangles as drawn here: each surface's corners, its triangles'
## corners by index, each triangle's outward normal, and its colour code.
class Shape extends RefCounted:
	var bounds: AABB
	var positions: Array[PackedVector3Array] = []
	var triangles: Array[PackedInt32Array] = []
	var normals: Array[PackedVector3Array] = []
	var codes := PackedInt32Array()
	var two_sided := PackedByteArray()

	## The part at [param path] (an .lbm), or null when it cannot be read.
	static func read(path: String) -> Shape:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		var part: Lbm.PartMesh = Lbm.parse(bytes, path, false)
		if part == null:
			return null
		var shape := Shape.new()
		shape.bounds = part.bounds
		for s: int in part.arrays.size():
			var arrays: Array = part.arrays[s]
			var corners: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var given: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var faces := PackedVector3Array()
			faces.resize(order.size() / 3)
			# Outward by the corners' own normals, so which way round a
			# triangle is wound does not matter here.
			for t: int in faces.size():
				var i: int = order[t * 3]
				var j: int = order[t * 3 + 1]
				var k: int = order[t * 3 + 2]
				var face: Vector3 = (corners[j] - corners[i]).cross(corners[k] - corners[i])
				if face.dot(given[i] + given[j] + given[k]) < 0.0:
					face = -face
				faces[t] = face.normalized()
			shape.positions.append(corners)
			shape.triangles.append(order)
			shape.normals.append(faces)
			shape.codes.append(part.surface_colors[s])
			shape.two_sided.append(part.surface_two_sided[s])
		return shape


## The picture: parts drawn a triangle at a time into a depth buffer, a band
## of rows to each of the engine's workers.
class Drawer extends RefCounted:
	## LDraw colour code -> Color.
	var colours: Dictionary = {}
	## Parts drawn in the last [method draw].
	var drawn: int = 0

	var _wide: int = 0
	var _rows: int = 0
	## Each surface of each part to draw, the opaque ones first: [its corners
	## in the picture, its triangles, each triangle's [key, fill, facing],
	## its colour, whether it is drawn from behind too, the part's number,
	## the first and last row it reaches].
	var _jobs: Array = []
	var _clear_from: int = 0
	## What each band drew: [colour, part], by band.
	var _bands: Array = []
	var _bands_lock := Mutex.new()


	## [param placed] drawn from the corner, [param size] pixels square, or null
	## when not one of them has geometry.
	func draw(placed: Array[LdrModel.Placement], meshes: Dictionary, shapes: Dictionary,
			size: int) -> Image:
		var shown: Array[int] = []
		var corners := PackedVector3Array()
		for n: int in placed.size():
			var shape: Shape = shapes.get(str(meshes.get(placed[n].part_id, "")))
			if shape == null:
				continue
			shown.append(n)
			var box: AABB = shape.bounds
			for c: int in 8:
				corners.append(placed[n].transform * box.get_endpoint(c))
		drawn = shown.size()
		if shown.is_empty():
			return null

		# ModelShot's camera: along the corner, framed on every corner of every
		# part's box, a tenth of margin round them.
		var toward: Vector3 = CORNER.normalized()
		var across: Vector3 = Vector3.UP.cross(toward).normalized()
		var up: Vector3 = toward.cross(across).normalized()
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point: Vector3 in corners:
			var flat := Vector2(point.dot(across), point.dot(up))
			low = low.min(flat)
			high = high.max(flat)
		var middle: Vector2 = (low + high) * 0.5
		var reach: float = maxf(maxf(high.x - low.x, high.y - low.y) * MARGIN, NARROWEST)
		var oversample: int = OVERSAMPLE if size <= 512 else 1
		_wide = size * oversample
		var scale: float = float(_wide) / reach
		# World to the picture: x right and y down in pixels, z the distance
		# from the camera (nearer is less).
		var view := Transform3D(Basis(across * scale, -up * scale, -toward).transposed(),
			Vector3(_wide * 0.5 - middle.x * scale, _wide * 0.5 + middle.y * scale, 0.0))

		var key: Vector3 = Basis.from_euler(KEY_TURN * (PI / 180.0)).z
		var fill: Vector3 = Basis.from_euler(FILL_TURN * (PI / 180.0)).z
		var opaque: Array = []
		var clear: Array = []
		for k: int in shown.size():
			var placement: LdrModel.Placement = placed[shown[k]]
			var shape: Shape = shapes[str(meshes[placement.part_id])]
			var at: Transform3D = placement.transform
			var onto: Transform3D = view * at
			# The rows it reaches, from its box's corners in the picture.
			var top: float = INF
			var bottom: float = -INF
			for c: int in 8:
				var y: float = (view * corners[k * 8 + c]).y
				top = minf(top, y)
				bottom = maxf(bottom, y)
			# Each triangle's light, and whether it faces the camera, from its
			# normal in the part's own frame: rows that are the key, the fill
			# and the camera turned into it, so the engine does the dot products.
			var turned: Basis = at.basis.transposed()
			var lit := Transform3D(Basis((turned * key).normalized(), (turned * fill).normalized(),
				(turned * toward).normalized()).transposed(), Vector3.ZERO)
			for s: int in shape.positions.size():
				var base: Color = _colour_of(shape.codes[s], placement.color_code)
				var job: Array = [onto * shape.positions[s], shape.triangles[s],
					lit * shape.normals[s], base, shape.two_sided[s] != 0, k, top, bottom]
				if base.a < 0.99:
					clear.append(job)
				else:
					opaque.append(job)
		_jobs = opaque + clear
		_clear_from = opaque.size()

		# Bands of rows, more than there are workers so they end together.
		var bands: int = clampi(OS.get_processor_count() * 2, 1, 32)
		_rows = ceili(float(_wide) / float(bands))
		bands = ceili(float(_wide) / float(_rows))
		_bands.clear()
		_bands.resize(bands)
		# The first on this thread: a GDScript function's first run on two
		# threads at once can take the engine down (WorkerTasks.first_here).
		_band(0)
		if bands > 1:
			var rest := func(index: int) -> void: _band(index + 1)
			var group: int = WorkerThreadPool.add_group_task(rest, bands - 1, -1, true,
				"thumbnail bands")
			WorkerThreadPool.wait_for_group_task_completion(group)
		var colour := PackedInt32Array()
		var part := PackedInt32Array()
		for band: Array in _bands:
			colour.append_array(band[0] as PackedInt32Array)
			part.append_array(band[1] as PackedInt32Array)
		_jobs = []
		_bands = []
		return _picture(colour, part, size, oversample)


	## The colour a surface of code [param code] is drawn in, on a part placed
	## in [param placed].
	func _colour_of(code: int, placed: int) -> Color:
		if code == Lbm.COLOR_INHERIT:
			code = placed
		if code >= 0x2000000:
			return Color.hex((code & 0xFFFFFF) << 8 | 0xFF)
		return colours.get(code, UNKNOWN_COLOUR)


	## Band [param index] of the picture: every surface that reaches its rows,
	## a triangle at a time, into a depth buffer of its own. A clear surface is
	## laid over what is drawn and hides nothing.
	func _band(index: int) -> void:
		var wide: int = _wide
		var first: int = index * _rows
		var last: int = mini(first + _rows, wide) - 1
		var cells: int = (last - first + 1) * wide
		var depth := PackedFloat32Array()
		depth.resize(cells)
		depth.fill(INF)
		var colour := PackedInt32Array()
		colour.resize(cells)
		colour.fill(0)
		var part := PackedInt32Array()
		part.resize(cells)
		part.fill(-1)
		# A triangle is in a row when it reaches the row's pixel centres.
		var top_row: float = float(first) + 0.5
		var bottom_row: float = float(last) + 0.5
		for j: int in _jobs.size():
			var job: Array = _jobs[j]
			var reaches_from: float = job[6]
			var reaches_to: float = job[7]
			if reaches_to < top_row or reaches_from > bottom_row:
				continue
			var see_through: bool = j >= _clear_from
			var points: PackedVector3Array = job[0]
			var order: PackedInt32Array = job[1]
			var light: PackedVector3Array = job[2]
			var base: Color = job[3]
			var both: bool = job[4]
			var number: int = job[5]
			var alpha: float = base.a
			for t: int in light.size():
				var facing: Vector3 = light[t]
				if facing.z <= 0.0:
					if not both:
						continue
					facing = -facing
				var a: Vector3 = points[order[t * 3]]
				var b: Vector3 = points[order[t * 3 + 1]]
				var c: Vector3 = points[order[t * 3 + 2]]
				var y_low: float = minf(a.y, minf(b.y, c.y))
				var y_high: float = maxf(a.y, maxf(b.y, c.y))
				if y_high < top_row or y_low > bottom_row:
					continue
				var area: float = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
				if absf(area) < 0.0001:
					continue
				if area < 0.0:
					var swap: Vector3 = b
					b = c
					c = swap
					area = -area
				var x_low: float = minf(a.x, minf(b.x, c.x))
				var x0: int = maxi(int(ceilf(x_low - 0.5)), 0)
				var x1: int = mini(int(floorf(maxf(a.x, maxf(b.x, c.x)) - 0.5)), wide - 1)
				var y0: int = maxi(int(ceilf(y_low - 0.5)), first)
				var y1: int = mini(int(floorf(y_high - 0.5)), last)
				if x0 > x1 or y0 > y1:
					continue
				var bright: float = AMBIENT + KEY * maxf(facing.x, 0.0) + FILL * maxf(facing.y, 0.0)
				var red: int = clampi(int(base.r * bright * 255.0), 0, 255)
				var green: int = clampi(int(base.g * bright * 255.0), 0, 255)
				var blue: int = clampi(int(base.b * bright * 255.0), 0, 255)
				var packed: int = 0xFF000000 | (blue << 16) | (green << 8) | red
				# The edge functions at the first pixel's centre, and their steps.
				var px: float = float(x0) + 0.5
				var py: float = float(y0) + 0.5
				var w0_row: float = (c.x - b.x) * (py - b.y) - (c.y - b.y) * (px - b.x)
				var w1_row: float = (a.x - c.x) * (py - c.y) - (a.y - c.y) * (px - c.x)
				var w2_row: float = (b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x)
				var w0_x: float = b.y - c.y
				var w1_x: float = c.y - a.y
				var w2_x: float = a.y - b.y
				var w0_y: float = c.x - b.x
				var w1_y: float = a.x - c.x
				var w2_y: float = b.x - a.x
				var za: float = a.z / area
				var zb: float = b.z / area
				var zc: float = c.z / area
				for y: int in range(y0, y1 + 1):
					var w0: float = w0_row
					var w1: float = w1_row
					var w2: float = w2_row
					var row: int = (y - first) * wide
					for x: int in range(x0, x1 + 1):
						if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
							var z: float = w0 * za + w1 * zb + w2 * zc
							var at: int = row + x
							if z < depth[at]:
								if see_through:
									colour[at] = _over(colour[at], red, green, blue, alpha)
								else:
									depth[at] = z
									colour[at] = packed
									part[at] = number
						w0 += w0_x
						w1 += w1_x
						w2 += w2_x
					w0_row += w0_y
					w1_row += w1_y
					w2_row += w2_y
		_bands_lock.lock()
		_bands[index] = [colour, part]
		_bands_lock.unlock()


	## [param under] (packed RGBA) with a clear colour laid over it.
	static func _over(under: int, red: int, green: int, blue: int, alpha: float) -> int:
		var below: float = float((under >> 24) & 0xFF) / 255.0
		if below <= 0.0:
			return (int(alpha * 255.0) << 24) | (blue << 16) | (green << 8) | red
		var keep: float = 1.0 - alpha
		var r: int = int(float(under & 0xFF) * keep + red * alpha)
		var g: int = int(float((under >> 8) & 0xFF) * keep + green * alpha)
		var b: int = int(float((under >> 16) & 0xFF) * keep + blue * alpha)
		return (under & 0xFF000000) | (b << 16) | (g << 8) | r


	## What was drawn ([param colour], packed RGBA, and which part each pixel
	## is of), scaled down to [param size], with a line where two parts meet.
	## The ground is clear and black, so the scaling gives every part's outline
	## a dark edge of its own.
	func _picture(colour: PackedInt32Array, part: PackedInt32Array, size: int,
			oversample: int) -> Image:
		var image := Image.create_from_data(_wide, _wide, false, Image.FORMAT_RGBA8,
			colour.to_byte_array())
		# Each pixel the mean of the four drawn for it.
		if oversample == 2:
			image.shrink_x2()
		var data: PackedByteArray = image.get_data()
		var keep: float = 1.0 - SEAM
		for y: int in size - 1:
			var row: int = y * oversample * _wide
			var below: int = row + oversample * _wide
			for x: int in size - 1:
				var here: int = part[row + x * oversample]
				if here < 0:
					continue
				if here != part[row + (x + 1) * oversample] or here != part[below + x * oversample]:
					var at: int = (y * size + x) * 4
					data[at] = int(data[at] * keep)
					data[at + 1] = int(data[at + 1] * keep)
					data[at + 2] = int(data[at + 2] * keep)
		return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
