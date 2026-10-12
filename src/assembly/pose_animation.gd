## A few poses at a few moments, made a smooth animation: a crane's arm
## raised over two seconds and lowered again, doors opened, and the model
## turned round once as well if asked.
##
## Each joint's angle between its keys is a monotone cubic (Fritsch and
## Carlson): it eases out of the first key and into the last, passes
## through every key exactly, and never swings past one, so an arm keyed to
## stop at 60 degrees stops there rather than overshooting to 64 and coming
## back. Pure: the frames are asked for by time, and turned into pictures
## by StudioRender.animate.
class_name PoseAnimation
extends RefCounted

## {t: seconds, angles: {path: degrees}}, in time order.
var keys: Array = []
## Turn the model round once over the animation.
var turntable: bool = false
var fps: int = 12


## A pose at [param t] seconds: in place of one already there.
func add_key(t: float, angles: Dictionary) -> void:
	for n: int in keys.size():
		if absf(float(keys[n]["t"]) - t) < 0.01:
			keys[n] = {"t": t, "angles": angles.duplicate()}
			return
	keys.append({"t": t, "angles": angles.duplicate()})
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["t"]) < float(b["t"]))


func remove_key(n: int) -> void:
	if n >= 0 and n < keys.size():
		keys.remove_at(n)


## How long it runs, seconds: to its last key, and at least a second.
func length() -> float:
	var last: float = float(keys.back()["t"]) if not keys.is_empty() else 0.0
	return maxf(last, 1.0)


## How many frames: every 1/fps of a second, the last key's own included;
## a turntable comes back to where it began, so not that one twice.
func frame_count() -> int:
	var frames: int = roundi(length() * float(fps))
	return maxi(frames if turntable else frames + 1, 1)


func time_of(frame: int) -> float:
	return float(frame) / float(fps)


## How far round the model has turned at [param t], in turns, 0 to 1.
func turn_at(t: float) -> float:
	if not turntable:
		return 0.0
	return clampf(t / length(), 0.0, 1.0)


## Every joint any key names.
func paths() -> PackedStringArray:
	var found: Dictionary = {}
	for key: Dictionary in keys:
		for path: Variant in key["angles"]:
			found[str(path)] = true
	var out := PackedStringArray(found.keys())
	out.sort()
	return out


## Each joint's angle at [param t] seconds: path -> degrees.
func angles_at(t: float) -> Dictionary:
	var out: Dictionary = {}
	for path: String in paths():
		out[path] = angle_at(path, t)
	return out


## One joint's angle at [param t]: before its first key, its first; after
## its last, its last; between, the monotone cubic through them.
func angle_at(path: String, t: float) -> float:
	var times := PackedFloat64Array()
	var values := PackedFloat64Array()
	for key: Dictionary in keys:
		var said: Dictionary = key["angles"]
		if said.has(path):
			times.append(float(key["t"]))
			values.append(float(said[path]))
	var count: int = times.size()
	if count == 0:
		return 0.0
	if count == 1 or t <= times[0]:
		return values[0]
	if t >= times[count - 1]:
		return values[count - 1]
	var slopes := PackedFloat64Array()
	for n: int in count - 1:
		var span: float = times[n + 1] - times[n]
		slopes.append((values[n + 1] - values[n]) / span if span > 0.0 else 0.0)
	# Tangents: none at the ends, so it eases in and out; none at a key
	# where it turns back; otherwise the mean, cut so it cannot overshoot.
	var tangents := PackedFloat64Array()
	tangents.resize(count)
	for n: int in count:
		if n == 0 or n == count - 1:
			tangents[n] = 0.0
		elif slopes[n - 1] * slopes[n] <= 0.0:
			tangents[n] = 0.0
		else:
			tangents[n] = (slopes[n - 1] + slopes[n]) * 0.5
	for n: int in count - 1:
		if is_zero_approx(slopes[n]):
			tangents[n] = 0.0
			tangents[n + 1] = 0.0
			continue
		var a: float = tangents[n] / slopes[n]
		var b: float = tangents[n + 1] / slopes[n]
		var size: float = a * a + b * b
		if size > 9.0:
			var cut: float = 3.0 / sqrt(size)
			tangents[n] = cut * a * slopes[n]
			tangents[n + 1] = cut * b * slopes[n]
	var k: int = 0
	while k < count - 2 and t > times[k + 1]:
		k += 1
	var h: float = times[k + 1] - times[k]
	var s: float = (t - times[k]) / h
	var s2: float = s * s
	var s3: float = s2 * s
	return values[k] * (2.0 * s3 - 3.0 * s2 + 1.0) + h * tangents[k] * (s3 - 2.0 * s2 + s) \
		+ values[k + 1] * (-2.0 * s3 + 3.0 * s2) + h * tangents[k + 1] * (s3 - s2)
