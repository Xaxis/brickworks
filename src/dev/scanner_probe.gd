## Does a half-written argument list yield whole bricks?
##
##   godot --headless --path . --script src/dev/scanner_probe.gd
##
## The model writes a design as a stream of JSON fragments split
## wherever the network happened to split them — mid-number, mid-key,
## inside a string. Anything that reads them has to cope with that, and
## the failure mode to avoid is not "misses a brick" but "invents one".
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var whole := '{"name":"Car","description":"a red car, 2x4",' \
		+ '"bricks":[' \
		+ '{"part":"3001","color":4,"x":0,"y":0,"z":0,"rot":0},' \
		+ '{"part":"3024","color":15,"x":1,"y":3,"z":0,"rot":1,' \
		+ '"face":"+z"},' \
		+ '{"part":"3070b","color":0,"x":2,"y":3,"z":0,"rot":0}]}'

	# One character at a time is the worst split there is, and the one
	# most likely to break a brace counter that trusts its input.
	_expect("one character at a time", whole, 1, 3)
	_expect("in sevens", whole, 7, 3)
	_expect("all at once", whole, whole.length(), 3)

	# A brace inside a string must not count. The description here holds
	# both a brace and an escaped quote, which is exactly what a model
	# writes when it is describing its own output.
	var tricky := '{"name":"X","description":"a {curly} \\"quoted\\" thing",' \
		+ '"bricks":[{"part":"3005","color":1,"x":0,"y":0,"z":0,"rot":0}]}'
	_expect("with braces and quotes in the prose", tricky, 3, 1)

	# An argument list that is not a design at all yields nothing, and
	# must not yield half of something.
	_expect("a search, which has no bricks",
		'{"query":"brick 2 x 4","limit":10}', 4, 0)

	# Cut off part way: what arrived is what you get, no guesses.
	var cut: String = whole.substr(0, whole.find('"3070b"'))
	_expect("cut off in the middle of a brick", cut, 5, 2)

	print("")
	if _failures == 0:
		print("fragments make whole bricks and nothing else")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _expect(what: String, text: String, chunk: int, want: int) -> void:
	var scanner := Assistant.Scanner.new()
	var found: Array[Dictionary] = []
	var at: int = 0
	while at < text.length():
		found.append_array(scanner.feed(text.substr(at, chunk)))
		at += chunk

	var bricks: Array[Dictionary] = []
	for entry: Dictionary in found:
		if entry.has("part"):
			bricks.append(entry)

	if bricks.size() != want:
		_failures += 1
		print("  FAIL  %s: %d bricks, wanted %d" % [what, bricks.size(), want])
		return

	# And they have to be the bricks that were written, not merely the
	# right number of them.
	for entry: Dictionary in bricks:
		var placement: Assistant.Placement = Assistant.Placement.from_dict(entry)
		if placement.part.is_empty():
			_failures += 1
			print("  FAIL  %s: a brick came out with no part" % what)
			return
	print("  ok    %s — %d brick%s" % [
		what, bricks.size(), "" if bricks.size() == 1 else "s"])
