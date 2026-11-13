## A part line's numbers are written as the author wrote them and read back
## the same to the bit (LdrModel._line_numbers).
##
##   godot --headless --path . --script src/dev/number_text_probe.gd
##
## A placement is held in single precision, so an author's 0.806 came back
## "0.80599999" on any save that rewrote its line (a recolour, a move): the
## file changed where nothing had (keeptext5's review, 11-09). Here: real
## authors' lines are written back as they came; every whole number stays
## whole and -0 is 0; and a thousand turned and moved placements, written
## and read again, are the same placement to the bit, written twice the same.
extends SceneTree

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	# Lines as other authors' tools write them: LDCad's and MLCad's cosines,
	# Studio's eight-place ones, a slope's half-plates, whole grid moves.
	var lines: Array[String] = [
		"0 0 0 0.806 0 -0.592 0 1 0 0.592 0 0.806",
		"10 -24 30 0.707107 0 0.707107 0 1 0 -0.707107 0 0.707107",
		"-12.5 8 0.25 1 0 0 0 0.866025 -0.5 0 0.5 0.866025",
		"130 -96 -250 0 0 1 0 1 0 -1 0 0",
		"0.001 -0.004 7.0625 0.6 0.8 0 -0.8 0.6 0 0 0 1",
	]
	for text: String in lines:
		var wrote: String = LdrModel._line_numbers(LdrModel.to_transform(_numbers(text)))
		_ok(wrote == text, "written as it came: %s -> %s" % [text, wrote])

	# Studio's eight places carry more than single precision holds: the same
	# number comes back, in the fewest places that are that number.
	var studio: String = "20 -8 -40 0.95105652 0 0.30901699 0 1 0 -0.30901699 0 0.95105652"
	var held: Transform3D = LdrModel.to_transform(_numbers(studio))
	var short: String = LdrModel._line_numbers(held)
	_ok(LdrModel.to_transform(_numbers(short)) == held and short.length() <= studio.length(),
		"Studio's eight places: the same placement, no longer: %s" % short)

	var turned := Transform3D(Basis(Vector3(-0.0, -0.0, -1), Vector3(-0.0, 1, -0.0), Vector3(1, -0.0, -0.0)),
		Vector3(20, -24, -0.0))
	var said: String = LdrModel._line_numbers(turned)
	_ok(said == "20 24 0 0 0 -1 0 1 0 1 0 0", "a quarter turn about the vertical: whole, no -0: %s" % said)

	var random := RandomNumberGenerator.new()
	random.seed = 20261110
	var drifted: int = 0
	var changed: int = 0
	var longest: int = 0
	var example: String = ""
	for _n: int in 1000:
		var axis := Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), random.randf_range(-1, 1))
		if axis.length() < 0.01:
			axis = Vector3.UP
		var at := Transform3D(Basis(axis.normalized(), random.randf_range(-PI, PI)),
			Vector3(random.randf_range(-800, 800), random.randf_range(-800, 800), random.randf_range(-800, 800)))
		var once: String = LdrModel._line_numbers(at)
		var back: Transform3D = LdrModel.to_transform(_numbers(once))
		var twice: String = LdrModel._line_numbers(back)
		if once != twice:
			changed += 1
			example = "%s / %s" % [once, twice]
		for word: String in once.split(" "):
			longest = maxi(longest, word.length())
		# A cosine to its written eight places (a single's step near 1 is
		# 6e-8), a position to its 1/10000 LDU (a single's step at 800 is 6e-5).
		var off: float = 0.0
		for axis_n: int in 3:
			off = maxf(off, (back.basis[axis_n] - at.basis[axis_n]).abs()[(back.basis[axis_n] - at.basis[axis_n]).abs().max_axis_index()])
		if off > 1e-7 or back.origin.distance_to(at.origin) > 2e-4:
			drifted += 1
			example = "%s: %s vs %s" % [once, back, at]
	_ok(drifted == 0, "1000 turned placements read back within their written places: %d drifted %s" % [drifted, example])
	_ok(changed == 0, "...and written again the same: %d changed %s" % [changed, example])
	_ok(longest <= 13, "...no number longer than a cosine's ten places need: %d" % longest)

	print("number_text: %s" % ("all ok, %d" % _passed if _failed == 0 else "%d FAILED, %d ok" % [_failed, _passed]))
	quit(1 if _failed > 0 else 0)


func _numbers(text: String) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for word: String in text.split(" ", false):
		out.append(word.to_float())
	return out


func _ok(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
