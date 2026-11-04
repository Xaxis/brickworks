## Build together's chat ends on its newest line, each time one is said
## (layoutwait).
##
##   godot --headless --path . --script src/dev/together_chat_probe.gd
##
## The chat is four lines tall and shows the last eight, and went to its end
## in a call deferred from the line's arrival: that call ran before the
## layout had made room for the line, so the chat stopped a line short of
## the newest. Here, in a session with no server, nine lines said one after
## another, a long one among them that wraps, and after each the chat must
## be at its end, the newest line in view.
extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var together := Together.new()
	together.store = ModelStore.new()
	together.store.title = "A small red house"
	together.live = true
	together.link = "https://brickworks.diy/together/probe"
	together.people = [{"who": "00000000", "name": "You", "me": true, "here": true, "owner": true},
		{"who": "11111111", "name": "Sam", "here": true}]
	var dialog := TogetherDialog.new()
	dialog.together = together
	root.add_child(dialog)
	dialog.open()
	await _frames(10)
	var scroll: ScrollContainer = dialog._chat_scroll
	var bar: ScrollBar = scroll.get_v_scroll_bar()
	for n: int in 9:
		var words: String = "line %d" % (n + 1)
		if n == 6:
			words += ", a long one that wraps across the chat's width and takes two lines or three"
		together.messages.append({"who": "11111111", "name": "Sam", "text": words, "mine": false})
		together.changed.emit()
		await _frames(8)
		var scrolls: bool = bar.max_value > bar.page + 1.0
		_check(not scrolls or bar.value >= bar.max_value - bar.page - 1.0,
			"%d said: the chat at its end, the newest in view (%d of %d)"
				% [n + 1, bar.value, bar.max_value - bar.page])
	dialog.queue_free()
	together.free()
	print("\n%s" % ("all checks passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
