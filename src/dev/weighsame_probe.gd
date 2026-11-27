## The status bar's weighing says the same of a model whether its copies are
## made in one frame or a slice a frame: each joint's load, what stands and
## what falls, and the Stress view's tints, after the same edits, one of them
## made while the copy is being made.
##
##   godot --headless --path . --script src/dev/weighsame_probe.gd \
##       [-- --models=orthanc,6660-1,10176-1]
##
## Up to grabtake Main.weigh_joints copied the model and its lattice whole in
## one frame (97 ms on Orthanc) at every change; since, a slice a frame
## (BrickWorld.ReadingCopy), a change meanwhile letting the copy go and the
## model weighed again. Run on a checkout from before and one after, the
## WEIGHSAME lines (a section's line count and md5) must be the same; with
## WEIGHSAME_DIR set in the environment each section is written there whole,
## to compare line by line.
##
## For each model, Stress on: opened and weighed; its top part taken off;
## the next one lifted a brick's height; the next taken off and, while that
## change is weighed (on Orthanc, while its copy is being made), the next
## taken off too. Each weighed as it stands, then written: the report
## (Main._weighed, every margin, what is held, what tips) and the tints the
## Stress view gave each part (BrickWorld._stressed).
extends SceneTree

const MODELS := {
	"orthanc": "res://models/orthanc.ldr",
	"6660-1": "res://vendor/omr/files/6660-1.mpd",
	"10176-1": "res://vendor/omr/files/10176-1.mpd",
}
## A weighing waited for at most this long, ms.
const WAIT_MS := 300000
## Frames a weighing is waited for to begin.
const BEGIN_FRAMES := 600

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _stress: StressView
var _dir: String = ""


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	var names: Array = MODELS.keys()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--models="):
			names = Array(arg.trim_prefix("--models=").split(",", false))
	_dir = OS.get_environment("WEIGHSAME_DIR")
	if not _dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_dir)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	var shell: Shell = _main.get("_shell")
	_stress = shell.stress if shell != null else null
	_check("the app has its Stress view and status bar", _stress != null and _main.get("_counts") != null)
	if _stress == null or _main.get("_counts") == null:
		_finish()
		return
	print("  weigh_joints copies a slice a frame here: %s" % (_main.get("_weigh_copying") != null))
	for name: String in names:
		if not MODELS.has(name):
			_check("%s is a model this probe knows" % name, false)
			continue
		await _model(name, MODELS[name])
	_finish()


func _model(name: String, path: String) -> void:
	print("")
	print("%s:" % name)
	var placed: int = int(_main.call("_open", ProjectSettings.globalize_path(path)))
	_check("%s opens (%d parts)" % [name, placed], placed > 0)
	if placed <= 0:
		return
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_stress.set_on(true)
	await _until_laid()
	# Weighed again with Stress on, so the tints are of this weighing: once
	# a weighing begun before it was on has ended, as one begun with it off
	# tints nothing.
	var began: int = Time.get_ticks_msec()
	while bool(_main.get("_weighing")) and Time.get_ticks_msec() - began < WAIT_MS:
		await process_frame
	_main.set("_stability_revision", -1)
	_main.set("_weighed_revision", -1)
	_main.set("_stability_at", 0)
	if not await _until_weighed(name, "opened"):
		return
	_dump(name, "opened")

	var tops: Array = _tops(4)
	_check("%s has four parts at its top to change (%s)" % [name, tops], tops.size() == 4)
	if tops.size() < 4:
		return

	_check("%s: #%d taken off" % [name, tops[0]], _builder.remove_brick_id(tops[0]))
	if not await _until_weighed(name, "removed"):
		return
	_dump(name, "removed")

	var lifted: Transform3D = _world.get_brick(tops[1]).transform.translated(Vector3(0.0, -24.0, 0.0))
	var moved: int = _builder.move_bricks({tops[1]: lifted})
	print("    #%d lifted a brick's height: %d moved" % [tops[1], moved])
	if not await _until_weighed(name, "moved"):
		return
	_dump(name, "moved")

	# A change, its weighing begun at once, and while it is under way (its
	# copy being made, where it is made a slice a frame) another change.
	var dropped_before: Variant = _main.get("_weigh_copies_dropped")
	_check("%s: #%d taken off" % [name, tops[2]], _builder.remove_brick_id(tops[2]))
	_main.set("_stability_at", 0)
	var waited: int = 0
	while not bool(_main.get("_weighing")) and waited < BEGIN_FRAMES:
		await process_frame
		waited += 1
	var copying: Variant = _main.get("_weigh_copying")
	var under_way: String = "not weighing" if not bool(_main.get("_weighing")) \
		else ("its copy being made" if copying == true else "the worker weighing")
	_check("%s: #%d taken off while the change before is weighed (%s)" % [name, tops[3], under_way],
		_builder.remove_brick_id(tops[3]))
	if not await _until_weighed(name, "edited while weighed"):
		return
	if dropped_before != null:
		var dropped: int = int(_main.get("_weigh_copies_dropped")) - int(dropped_before)
		print("    copies the change let go of: %d" % dropped)
		if name == "orthanc":
			_check("orthanc: the second change came while the copy was being made, and let it go (%s, %d)"
				% [under_way, dropped], copying == true and dropped >= 1)
	_dump(name, "edited while weighed")
	_stress.set_on(false)


## The parts highest in the model (least y), by height then id, scenery and
## locked parts left out: [param count] of them.
func _tops(count: int) -> Array:
	var scenery: Dictionary = _store.scenery
	var locked: Dictionary = _builder.locked
	var all: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if scenery.has(brick.id) or locked.has(brick.id):
			continue
		all.append([snappedf(brick.transform.origin.y, 0.01), brick.id])
	all.sort()
	var out: Array = []
	for pair: Array in all.slice(0, count):
		out.append(int(pair[1]))
	return out


func _until_laid() -> void:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < WAIT_MS:
		await process_frame
		if not _world.is_being_laid() and _store.awaited.is_empty():
			return
	_check("the model is laid within %d s" % (WAIT_MS / 1000), false)


## Frames until the model as it stands is weighed and nothing is being
## weighed: false when it is not within WAIT_MS.
func _until_weighed(name: String, step: String) -> bool:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < WAIT_MS:
		await process_frame
		if not bool(_main.get("_weighing")) and int(_main.get("_weighed_revision")) == _world.revision \
				and not _world.is_being_laid():
			await _frames(3)
			if not bool(_main.get("_weighing")) and int(_main.get("_weighed_revision")) == _world.revision:
				print("    %s: weighed in %d ms" % [step, Time.get_ticks_msec() - began])
				return true
	_check("%s %s: weighed within %d s" % [name, step, WAIT_MS / 1000], false)
	return false


## The weighing and the tints as they stand, each section a WEIGHSAME line.
func _dump(name: String, step: String) -> void:
	var report: Stability.Report = _main.get("_weighed")
	_check("%s %s: a weighing to write" % [name, step], report != null)
	if report == null:
		return
	print("    %s: %s" % [step, report.summary()])
	var lines: PackedStringArray = PackedStringArray()
	for property: Dictionary in report.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key: String = property["name"]
		var value: Variant = report.get(key)
		if value is Dictionary and (value as Dictionary).size() > 1:
			for item: Variant in _sorted_keys(value):
				lines.append("%s %s %s" % [key, _plain(item, 0, []), _plain(value[item], 0, [])])
		elif value is Array and (value as Array).size() > 1:
			var at: int = 0
			for item: Variant in value:
				lines.append("%s[%d] %s" % [key, at, _plain(item, 0, [])])
				at += 1
		else:
			lines.append("%s %s" % [key, _plain(value, 0, [])])
	_section(name, step, "report", lines)
	var tints: Dictionary = _world.get("_stressed")
	var tinted: PackedStringArray = PackedStringArray()
	for id: Variant in _sorted_keys(tints):
		tinted.append("%s %s" % [id, (tints[id] as Color).to_html()])
	_section(name, step, "tints", tinted)
	_section(name, step, "summary", PackedStringArray([report.summary(),
		"stands %s" % report.is_stable(), "parts %d" % _world.brick_count()]))


func _section(name: String, step: String, section: String, lines: PackedStringArray) -> void:
	var text: String = "\n".join(lines)
	print("WEIGHSAME %s %s %s %d %s" % [name, step.replace(" ", "_"), section, lines.size(), text.md5_text()])
	if _dir.is_empty():
		return
	var file := FileAccess.open("%s/%s_%s_%s.txt" % [_dir, name, step.replace(" ", "_"), section],
		FileAccess.WRITE)
	if file != null:
		file.store_string(text + "\n")
		file.close()


func _sorted_keys(dict: Dictionary) -> Array:
	var keys: Array = dict.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) == typeof(b) and (a is int or a is float):
			return a < b
		return str(a) < str(b))
	return keys


## [param value] as text that is the same on every run: floats to 5
## places, objects by their script's variables, dictionaries by key.
func _plain(value: Variant, depth: int, above: Array) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "%.5f" % value
		TYPE_VECTOR3:
			var v: Vector3 = value
			return "(%.4f,%.4f,%.4f)" % [v.x, v.y, v.z]
		TYPE_TRANSFORM3D:
			var t: Transform3D = value
			return "[%s %s %s %s]" % [_plain(t.basis.x, depth, above), _plain(t.basis.y, depth, above),
				_plain(t.basis.z, depth, above), _plain(t.origin, depth, above)]
		TYPE_COLOR:
			return (value as Color).to_html()
		TYPE_CALLABLE:
			return "<callable>"
		TYPE_DICTIONARY:
			var parts: PackedStringArray = PackedStringArray()
			for key: Variant in _sorted_keys(value):
				parts.append("%s: %s" % [_plain(key, depth + 1, above), _plain(value[key], depth + 1, above)])
			return "{%s}" % ", ".join(parts)
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR3_ARRAY:
			var items: PackedStringArray = PackedStringArray()
			for item: Variant in value:
				items.append(_plain(item, depth + 1, above))
			return "[%s]" % ", ".join(items)
		TYPE_OBJECT:
			var object: Object = value
			if object == null or not is_instance_valid(object):
				return "null"
			if object is Node:
				return "<node>"
			if depth > 4 or above.has(object):
				return "<again>"
			var fields: PackedStringArray = PackedStringArray()
			var inside: Array = above + [object]
			for property: Dictionary in object.get_property_list():
				if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
					fields.append("%s=%s" % [property["name"],
						_plain(object.get(property["name"]), depth + 1, inside)])
			return "<%s>" % " ".join(fields)
	return str(value)


func _finish() -> void:
	print("")
	print("weighsame probe: %s" % ("%d FAILED" % _failures if _failures > 0
		else "every weighing written; compare the WEIGHSAME lines with another checkout's"))
	quit(1 if _failures > 0 else 0)
