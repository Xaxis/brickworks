## A turntable, an animation or a building video as an animated GIF: the
## format every chat, forum and mail program takes as a picture and plays,
## where an animated WebP is still refused by some (StudWorx shares its
## turntables so; APP_UX6 gap 12, unit video2).
##
## A GIF has at most 256 colours, so the frames share one palette made from
## the whole video: a frame's own palette shifts from frame to frame and the
## sweep shimmers as the model turns. The palette is cut from the colours of
## frames spread through the video by splitting the box of colours with the
## most error in two, again and again (median cut, on a 5-5-5 histogram), and
## each pixel takes its nearest palette colour after an 8 x 8 ordered dither:
## the same pattern in every frame, so what stands still in the picture (the
## sweep, the floor) stays still in the GIF, as error diffusion's noise does
## not. Each frame is a whole picture, compressed with LZW as GIF89a says.
##
## A GIF is shared, so it is made to fit 8 MB, what chats and forums take
## (Discord's limit for years, GitHub's 10 MB, mail less): at most 640 pixels
## on its long side, and when the video is longer than that allows, fewer
## frames a second (down to 12) and then a smaller picture, chosen from what
## a few of its frames came to. Godot writes no GIF, so it is written here;
## byte layout from the GIF89a specification, LZW as every GIF encoder has it.
class_name AnimatedGif
extends RefCounted

## The most a GIF may come to, in bytes: 8 MB.
const BUDGET := 8_000_000
## Its long side: shared GIFs are this size or smaller.
const LONGEST := 640
## Smaller than this the model is hard to make out: frames go first.
const SHORTEST := 320
## How few frames a second a GIF drops to before its picture gets smaller.
const FEWEST_FPS := 12.0
## How many frames the palette is cut from, spread through the video.
const PALETTE_FRAMES := 12
## And how wide each is for it.
const PALETTE_WIDTH := 200
## How strong the ordered dither is, in levels of 255: a 5-5-5 cell.
const DITHER := 16
## The 8 x 8 Bayer matrix, 0 to 63.
const BAYER: Array[int] = [
	0, 32, 8, 40, 2, 34, 10, 42,
	48, 16, 56, 24, 50, 18, 58, 26,
	12, 44, 4, 36, 14, 46, 6, 38,
	60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43, 1, 33, 9, 41,
	51, 19, 59, 27, 49, 17, 57, 25,
	15, 47, 7, 39, 13, 45, 5, 37,
	63, 31, 55, 23, 61, 29, 53, 21]
## The index a pixel with no colour takes, when a GIF has those.
const CLEAR := 255


## The GIF of the [param count] frames of [param webp] (an animated WebP's
## bytes, RenderOutput's) at [param fps]; [param clear]: the render has no
## backdrop, so a pixel may have no colour. The palette and the size are
## worked out on a worker, then the frames are made on workers a few at a
## time (here, a frame a frame, where there are no threads), [param told]
## hearing "frame N of M" as they are. Returns {"bytes", "size", "frames",
## "fps", "colours"}, or {} when there is nothing to make it of.
static func from_webp(webp: PackedByteArray, count: int, fps: int, clear: bool,
		told: Callable = Callable()) -> Dictionary:
	if count <= 0 or webp.is_empty():
		return {}
	# Planned in pieces, each on a worker in turn (a frame apart where there
	# are no threads, so a page without them keeps answering).
	var samples: Variant = await _off_thread(func() -> Variant:
		return _samples(webp, count), "read a GIF's colours")
	if not samples is Array or (samples as Array).is_empty():
		return {}
	var full: Vector2i = (samples as Array)[0]
	var pictures: Array[Image] = []
	pictures.assign((samples as Array).slice(1))
	var palette: PackedByteArray = await _off_thread(func() -> Variant:
		return palette_of(pictures, 255 if clear else 256), "cut a GIF's palette")
	var table: PackedByteArray = await _off_thread(func() -> Variant:
		return nearest_table(palette), "a GIF's colour table")
	var plan: Dictionary = await _off_thread(func() -> Variant:
		return _plan(webp, count, fps, clear, full, table), "plan a GIF")
	plan["palette"] = palette
	var size: Vector2i = plan["size"]
	var step: int = plan["step"]
	var chosen := PackedInt32Array()
	for n: int in range(0, count, step):
		chosen.append(n)
	var frames: Array[PackedByteArray] = []
	frames.resize(chosen.size())
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var at_once: int = clampi(OS.get_processor_count() - 1, 1, 8)
	var out: Array = []  ## [task, [bytes], k], oldest first
	var done: int = 0
	for k: int in chosen.size():
		var made: Array = [PackedByteArray()]
		var n: int = chosen[k]
		var delay: int = delay_of(k, step, fps)
		var work := func() -> void:
			made[0] = _frame_of(webp, n, size, table, delay, clear)
		if OS.has_feature("nothreads"):
			work.call()
			frames[k] = made[0]
			done += 1
			if told.is_valid():
				told.call("frame %d of %d" % [done, chosen.size()])
			await tree.process_frame
			continue
		out.append([WorkerTasks.add(work, false, "make a GIF frame"), made, k])
		while out.size() >= at_once or (k == chosen.size() - 1 and not out.is_empty()):
			var oldest: Array = out[0]
			while not WorkerThreadPool.is_task_completed(int(oldest[0])):
				await tree.process_frame
			WorkerTasks.collect(int(oldest[0]))
			out.pop_front()
			frames[int(oldest[2])] = (oldest[1] as Array)[0]
			done += 1
			if told.is_valid():
				told.call("frame %d of %d" % [done, chosen.size()])
	# Over all the same (a few frames' measure is a guess): every other
	# frame, each shown twice as long, until it fits.
	var bytes: PackedByteArray = file(size, plan["palette"], frames)
	while bytes.size() > BUDGET and frames.size() > 1:
		step *= 2
		var kept: Array[PackedByteArray] = []
		for k: int in range(0, frames.size(), 2):
			kept.append(with_delay(frames[k], delay_of(kept.size(), step, fps)))
		frames = kept
		bytes = file(size, plan["palette"], frames)
	return {"bytes": bytes, "size": size, "frames": frames.size(), "fps": float(fps) / float(step),
		"colours": (plan["palette"] as PackedByteArray).size() / 3 + (1 if clear else 0)}


## [param work] on a worker, waited for a frame at a time: what it returns.
## Here and now where there are no threads.
static func _off_thread(work: Callable, description: String) -> Variant:
	if OS.has_feature("nothreads"):
		return work.call()
	var out: Array = [null]
	var task: int = WorkerTasks.add(func() -> void: out[0] = work.call(), false, description)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerTasks.collect(task)
	return out[0]


## The video's size, then [constant PALETTE_FRAMES] of its frames spread
## through it, small, for its palette: [Vector2i, Image, …]; empty if its
## frames do not read.
static func _samples(webp: PackedByteArray, count: int) -> Array:
	var first: Image = _decoded(webp, 0)
	if first == null:
		return []
	var full := Vector2i(first.get_width(), first.get_height())
	var out: Array = [full]
	var spread: int = mini(PALETTE_FRAMES, count)
	for k: int in spread:
		var n: int = roundi(float(k) * float(count - 1) / float(maxi(spread - 1, 1)))
		var image: Image = first if n == 0 else _decoded(webp, n)
		if image == null:
			continue
		image = image.duplicate() as Image
		image.resize(PALETTE_WIDTH, maxi(roundi(float(PALETTE_WIDTH) * full.y / full.x), 1),
			Image.INTERPOLATE_BILINEAR)
		out.append(image)
	return out


## What the GIF will be: its size and how many of the frames it keeps
## (every step-th). Made to fit [constant BUDGET] by what three of its
## frames come to: every frame up to its long side's [constant LONGEST];
## over that, fewer frames a second down to [constant FEWEST_FPS], then a
## smaller picture down to [constant SHORTEST], then fewer frames again. Its
## own frames go through the frame's code first here, on one thread: a
## GDScript operator run for the first time on two threads at once crashes
## the engine (WorkerTasks).
static func _plan(webp: PackedByteArray, count: int, fps: int, clear: bool, full: Vector2i,
		table: PackedByteArray) -> Dictionary:
	var scale: float = minf(1.0, float(LONGEST) / float(maxi(full.x, full.y)))
	var step: int = 1
	var each: float = _measure(webp, count, _sized(full, scale), table, clear)
	var room: float = float(BUDGET) * 0.92 - 800.0
	while each * ceilf(float(count) / float(step)) > room and float(fps) / float(step + 1) >= FEWEST_FPS:
		step += 1
	var over: float = each * ceilf(float(count) / float(step)) / room
	if over > 1.0:
		var least: float = float(SHORTEST) / float(maxi(full.x, full.y))
		var smaller: float = maxf(scale / sqrt(over), minf(least, scale))
		if smaller < scale:
			scale = smaller
			each = _measure(webp, count, _sized(full, scale), table, clear)
	while each * ceilf(float(count) / float(step)) > room and step < count:
		step += 1
	return {"size": _sized(full, scale), "step": step}


static func _sized(full: Vector2i, scale: float) -> Vector2i:
	return Vector2i(maxi(roundi(float(full.x) * scale), 1), maxi(roundi(float(full.y) * scale), 1))


## What a frame of [param size] comes to, from the first, the middle and
## the last.
static func _measure(webp: PackedByteArray, count: int, size: Vector2i, table: PackedByteArray,
		clear: bool) -> float:
	var total: float = 0.0
	var measured: int = 0
	for n: int in [0, count / 2, count - 1]:
		var bytes: PackedByteArray = _frame_of(webp, n, size, table, 4, clear)
		if not bytes.is_empty():
			total += float(bytes.size())
			measured += 1
	return total / float(maxi(measured, 1))


## Frame [param n] of [param webp] as a GIF's frame of [param size].
static func _frame_of(webp: PackedByteArray, n: int, size: Vector2i, table: PackedByteArray,
		delay: int, clear: bool) -> PackedByteArray:
	var image: Image = _decoded(webp, n)
	if image == null:
		return PackedByteArray()
	if image.get_size() != size:
		image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return frame(image, table, delay, clear)


## Frame [param n] of an animated WebP, as RGBA8; null if it is not there.
static func _decoded(webp: PackedByteArray, n: int) -> Image:
	var still: PackedByteArray = AnimatedWebP.still(webp, n)
	if still.is_empty():
		return null
	var image := Image.new()
	if image.load_webp_from_buffer(still) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


## The colours [param samples] are made of (RGBA8 images; a pixel less than
## half there is no colour), as at most [param most] colours: three bytes,
## red, green and blue, for each.
static func palette_of(samples: Array[Image], most: int) -> PackedByteArray:
	var counts := PackedInt32Array()
	counts.resize(32768)
	counts.fill(0)
	var sums := PackedInt64Array()
	sums.resize(32768 * 3)
	sums.fill(0)
	for image: Image in samples:
		var data: PackedByteArray = image.get_data()
		for at: int in range(0, data.size(), 4):
			if data[at + 3] < 128:
				continue
			var r: int = data[at]
			var g: int = data[at + 1]
			var b: int = data[at + 2]
			var bin: int = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
			counts[bin] += 1
			sums[bin * 3] += r
			sums[bin * 3 + 1] += g
			sums[bin * 3 + 2] += b
	var occupied := PackedInt32Array()
	for bin: int in 32768:
		if counts[bin] > 0:
			occupied.append(bin)
	if occupied.is_empty():
		return PackedByteArray([0, 0, 0])
	# Each bin as the mean of its pixels.
	var means := PackedFloat32Array()
	means.resize(32768 * 3)
	for bin: int in occupied:
		for c: int in 3:
			means[bin * 3 + c] = float(sums[bin * 3 + c]) / float(counts[bin])
	var boxes: Array[PackedInt32Array] = [occupied]
	var errors: Array[float] = [_error(occupied, counts, means)]
	while boxes.size() < most:
		var worst: int = -1
		for n: int in boxes.size():
			if boxes[n].size() > 1 and (worst < 0 or errors[n] > errors[worst]):
				worst = n
		if worst < 0 or errors[worst] <= 0.0:
			break
		var halves: Array[PackedInt32Array] = _split(boxes[worst], counts, means)
		boxes[worst] = halves[0]
		errors[worst] = _error(halves[0], counts, means)
		boxes.append(halves[1])
		errors.append(_error(halves[1], counts, means))
	var palette := PackedByteArray()
	for box: PackedInt32Array in boxes:
		var total: float = 0.0
		var colour := Vector3.ZERO
		for bin: int in box:
			total += float(counts[bin])
			colour += Vector3(float(sums[bin * 3]), float(sums[bin * 3 + 1]), float(sums[bin * 3 + 2]))
		colour /= maxf(total, 1.0)
		palette.append_array([clampi(roundi(colour.x), 0, 255), clampi(roundi(colour.y), 0, 255),
			clampi(roundi(colour.z), 0, 255)])
	return palette


## How far a box's pixels are from its mean, summed and squared.
static func _error(box: PackedInt32Array, counts: PackedInt32Array,
		means: PackedFloat32Array) -> float:
	var n: float = 0.0
	var sum := Vector3.ZERO
	var squares: float = 0.0
	for bin: int in box:
		var count: float = float(counts[bin])
		var mean := Vector3(means[bin * 3], means[bin * 3 + 1], means[bin * 3 + 2])
		n += count
		sum += mean * count
		squares += mean.length_squared() * count
	return squares - sum.length_squared() / maxf(n, 1.0)


## A box cut in two across the channel its pixels spread most along, where
## half its pixels lie each side.
static func _split(box: PackedInt32Array, counts: PackedInt32Array,
		means: PackedFloat32Array) -> Array[PackedInt32Array]:
	var n: float = 0.0
	var sum := Vector3.ZERO
	var squares := Vector3.ZERO
	for bin: int in box:
		var count: float = float(counts[bin])
		var mean := Vector3(means[bin * 3], means[bin * 3 + 1], means[bin * 3 + 2])
		n += count
		sum += mean * count
		squares += mean * mean * count
	var spread: Vector3 = squares - sum * sum / maxf(n, 1.0)
	var channel: int = 0 if spread.x >= spread.y and spread.x >= spread.z else (
		1 if spread.y >= spread.z else 2)
	var shift: int = 10 - 5 * channel
	# The pixels along that channel's 32 levels, then the level half of
	# them are at or under, with something either side.
	var along := PackedFloat32Array()
	along.resize(32)
	along.fill(0.0)
	var low: int = 31
	var high: int = 0
	for bin: int in box:
		var level: int = (bin >> shift) & 31
		along[level] += float(counts[bin])
		low = mini(low, level)
		high = maxi(high, level)
	var cut: int = low
	var seen: float = 0.0
	for level: int in range(low, high):
		seen += along[level]
		cut = level
		if seen >= n * 0.5:
			break
	var halves: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for bin: int in box:
		halves[0 if ((bin >> shift) & 31) <= cut else 1].append(bin)
	if halves[1].is_empty() or halves[0].is_empty():
		# One level only along it: cut the bins in two as they come.
		var half: int = box.size() / 2
		halves = [box.slice(0, half), box.slice(half)]
	return halves


## For every 5-5-5 colour, the index of the nearest of [param palette]'s
## colours: what a pixel takes, after the dither.
static func nearest_table(palette: PackedByteArray) -> PackedByteArray:
	var colours: int = palette.size() / 3
	# The palette by green, so a search goes out from a colour's green and
	# stops once green alone is farther than the nearest found.
	var order: Array[int] = []
	for n: int in colours:
		order.append(n)
	order.sort_custom(func(a: int, b: int) -> bool: return palette[a * 3 + 1] < palette[b * 3 + 1])
	var greens := PackedInt32Array()
	for n: int in order:
		greens.append(palette[n * 3 + 1])
	var starts := PackedInt32Array()
	starts.resize(256)
	var at: int = 0
	for g: int in 256:
		while at < colours and greens[at] < g:
			at += 1
		starts[g] = mini(at, colours - 1)
	var table := PackedByteArray()
	table.resize(32768)
	for bin: int in 32768:
		var r: int = ((bin >> 10) & 31) * 8 + 4
		var g: int = ((bin >> 5) & 31) * 8 + 4
		var b: int = (bin & 31) * 8 + 4
		var best: int = 1 << 30
		var found: int = 0
		var up: int = starts[g]
		var down: int = up - 1
		while up < colours or down >= 0:
			if up < colours:
				var dg: int = greens[up] - g
				if dg * dg >= best:
					up = colours
				else:
					var n: int = order[up]
					var dr: int = palette[n * 3] - r
					var db: int = palette[n * 3 + 2] - b
					var d: int = dr * dr + dg * dg + db * db
					if d < best:
						best = d
						found = n
					up += 1
			if down >= 0:
				var dg: int = greens[down] - g
				if dg * dg >= best:
					down = -1
				else:
					var n: int = order[down]
					var dr: int = palette[n * 3] - r
					var db: int = palette[n * 3 + 2] - b
					var d: int = dr * dr + dg * dg + db * db
					if d < best:
						best = d
						found = n
					down -= 1
		table[bin] = found
	return table


## One frame of the GIF: its Graphic Control Extension, its Image Descriptor
## and its pixels, as [param table] (nearest_table's) takes each after the
## dither, LZW-compressed. [param image] is RGBA8, the GIF's size;
## [param delay] is how long it shows, in hundredths of a second; with
## [param clear], a pixel less than half there is no colour.
static func frame(image: Image, table: PackedByteArray, delay: int, clear: bool) -> PackedByteArray:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var indices: PackedByteArray = _indices(image.get_data(), width, height, table, clear)
	var out := PackedByteArray()
	# Shown for [param delay]; a frame with no colour in places is put away
	# before the next, or what was there shows through.
	out.append_array([0x21, 0xF9, 0x04, (8 if clear else 4) | (1 if clear else 0)])
	out.append_array(_u16(delay))
	out.append_array([CLEAR if clear else 0, 0x00])
	out.append(0x2C)
	out.append_array(_u16(0))
	out.append_array(_u16(0))
	out.append_array(_u16(width))
	out.append_array(_u16(height))
	out.append(0x00)
	out.append(8)
	var packed: PackedByteArray = lzw(indices)
	for at: int in range(0, packed.size(), 255):
		var piece: PackedByteArray = packed.slice(at, mini(at + 255, packed.size()))
		out.append(piece.size())
		out.append_array(piece)
	out.append(0x00)
	return out


## [param frame_bytes] (frame's) shown for [param delay] hundredths of a
## second instead: frames thinned out show longer.
static func with_delay(frame_bytes: PackedByteArray, delay: int) -> PackedByteArray:
	var out: PackedByteArray = frame_bytes.duplicate()
	out.encode_u16(4, delay)
	return out


## How long frame [param n] of frames [param step] apart in a video of
## [param fps] shows, in hundredths of a second: the delays add up to the
## video's length, as near as hundredths can (24 a second: 4, 4, 5, 4, …),
## and no frame shows for less than 2, which browsers stretch to 10.
static func delay_of(n: int, step: int, fps: float) -> int:
	var each: float = 100.0 * float(step) / maxf(fps, 1.0)
	return maxi(roundi(each * float(n + 1)) - roundi(each * float(n)), 2)


## The whole file: [param size], the palette (three bytes a colour, at most
## 256) and the frames, looping for ever.
static func file(size: Vector2i, palette: PackedByteArray, frames: Array[PackedByteArray]) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array("GIF89a".to_ascii_buffer())
	out.append_array(_u16(size.x))
	out.append_array(_u16(size.y))
	# A global table of 256 colours, 8 bits a channel; no background, square pixels.
	out.append_array([0xF7, 0x00, 0x00])
	var table: PackedByteArray = palette.slice(0, 768)
	table.resize(768)
	out.append_array(table)
	# NETSCAPE2.0: loop for ever.
	out.append_array([0x21, 0xFF, 0x0B])
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array([0x03, 0x01, 0x00, 0x00, 0x00])
	for each: PackedByteArray in frames:
		out.append_array(each)
	out.append(0x3B)
	return out


## Each pixel's palette index, after the dither.
static func _indices(data: PackedByteArray, width: int, height: int, table: PackedByteArray,
		clear: bool) -> PackedByteArray:
	# Each of the 64 dither offsets as a table from a channel's level to
	# its 5-bit level after the offset: three look-ups a pixel.
	var levels := PackedByteArray()
	levels.resize(64 * 256)
	for k: int in 64:
		var offset: int = roundi((float(BAYER[k]) + 0.5) / 64.0 * DITHER - DITHER * 0.5)
		for value: int in 256:
			levels[k * 256 + value] = clampi(value + offset, 0, 255) >> 3
	var out := PackedByteArray()
	out.resize(width * height)
	var p: int = 0
	for y: int in height:
		var row: int = (y & 7) << 3
		for x: int in width:
			var at: int = p << 2
			if clear and data[at + 3] < 128:
				out[p] = CLEAR
			else:
				var base: int = (row | (x & 7)) << 8
				out[p] = table[(levels[base + data[at]] << 10) | (levels[base + data[at + 1]] << 5)
					| levels[base + data[at + 2]]]
			p += 1
	return out


## [param indices] (8-bit) LZW-compressed as a GIF's image data is, its
## codes packed low bit first, before it is cut into blocks.
static func lzw(indices: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	if indices.is_empty():
		return out
	const CLEAR_CODE := 256
	const END_CODE := 257
	# A code for every run seen: code -> the code of the run with one more
	# index after it, at code * 256 + index, 0 for none yet.
	var table := PackedInt32Array()
	table.resize(4096 * 256)
	table.fill(0)
	var next_code: int = END_CODE + 1
	var size: int = 9
	var bits: int = CLEAR_CODE
	var count: int = size
	var run: int = indices[0]
	for at: int in range(1, indices.size()):
		var index: int = indices[at]
		var key: int = (run << 8) | index
		var known: int = table[key]
		if known != 0:
			run = known
			continue
		bits |= run << count
		count += size
		while count >= 8:
			out.append(bits & 0xFF)
			bits >>= 8
			count -= 8
		if next_code == 4096:
			bits |= CLEAR_CODE << count
			count += size
			while count >= 8:
				out.append(bits & 0xFF)
				bits >>= 8
				count -= 8
			table.fill(0)
			next_code = END_CODE + 1
			size = 9
		else:
			if next_code >= (1 << size):
				size += 1
			table[key] = next_code
			next_code += 1
		run = index
	bits |= run << count
	count += size
	bits |= END_CODE << count
	count += size
	while count > 0:
		out.append(bits & 0xFF)
		bits >>= 8
		count -= 8
	return out


static func _u16(value: int) -> PackedByteArray:
	return PackedByteArray([value & 0xFF, (value >> 8) & 0xFF])
