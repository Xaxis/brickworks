## Does the model appear while it is being written?
##
##   godot --headless --path . --script src/dev/stream_probe.gd
##
## Not in the offline suite: it spends a real request against a real
## key. Run it when the streaming path has changed.
##
## Two things have to be true and the second is the one that is easy to
## lose. Bricks must arrive spread out over the time the answer takes,
## rather than all at the end — which is what a stream that is buffered
## somewhere along the way looks like, and it looks exactly like a
## working one from the code's side. And the reassembled message must
## be indistinguishable from an unstreamed reply, because the next turn
## sends it back and a mangled transcript is refused in ways that are
## hard to read.
extends SceneTree

var _done := false
var _ok := false
var _summary := ""
var _first_brick_ms := 0
var _arrivals: Array[int] = []
var _failures := 0


func _initialize() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame

	var assistant: Assistant = main.get("_assistant")
	if assistant == null:
		print("no assistant")
		quit(1)
		return
	assistant.direct_key = Brain.api_key()
	if assistant.direct_key.is_empty():
		print("no ANTHROPIC_API_KEY — this one talks to the model directly")
		quit(1)
		return

	assistant.finished.connect(func(good: bool, said: String) -> void:
		_done = true
		_ok = good
		_summary = said)
	assistant.progress.connect(func(note: String) -> void:
		print("      · %s" % note))
	assistant.sketched.connect(func(count: int) -> void:
		_arrivals.append(Time.get_ticks_msec())
		if _first_brick_ms == 0:
			_first_brick_ms = Time.get_ticks_msec())

	var began: int = Time.get_ticks_msec()
	assistant.design("a red post box: a tall narrow box on a base, "
		+ "with a slot near the top and a small roof")
	var deadline: int = began + 600_000
	while not _done and Time.get_ticks_msec() < deadline:
		await process_frame
	var took: int = Time.get_ticks_msec() - began

	print("")
	print("  finished in %.1fs: %s" % [took / 1000.0, _summary])
	if not _ok:
		_failures += 1
		print("  FAIL  the design did not finish")

	if _arrivals.is_empty():
		_failures += 1
		print("  FAIL  no brick arrived before the end — "
			+ "the stream was buffered somewhere, or is not a stream")
	else:
		var first: float = (_arrivals[0] - began) / 1000.0
		var last: float = (_arrivals[-1] - began) / 1000.0
		print("  %d bricks arrived, first at %.1fs, last at %.1fs"
			% [_arrivals.size(), first, last])
		# Spread out, not a burst. A buffered stream delivers every
		# fragment in the same handful of milliseconds at the end, which
		# passes any test that only asks whether fragments arrived.
		if last - first < 0.5:
			_failures += 1
			print("  FAIL  every brick arrived within %.2fs of the "
				% (last - first) + "first: that is a lump, not a stream")
		else:
			print("  ok    bricks arrived over %.1fs" % (last - first))

	print("")
	if _failures == 0:
		print("the model appears as it is written")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
