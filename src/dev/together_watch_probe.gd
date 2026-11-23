## Building now, in the studio (buildlive): what the designer's Build
## together panel shows of watchers, with no server.
##
##   godot --headless --path . --script src/dev/together_watch_probe.gd
##
## A session the designer owns, as the session's log brings watchers'
## words (client "watching", api/together.js watchAppend): a line said
## with its name as "~by", an ask to build, and the seat given for it.
## The line is in the chat by the watcher's name. The ask is said on the
## status line and shown with Give a seat (together_seat_1). The seat takes
## it away. None of the watchers' keys is taken for the model's own state.
## The panel offers Open to watchers until the session is open, then shows
## its page, how many watch (Copy, Close to watchers), and to a joiner none
## of it.
extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var world := BrickWorld.new()
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.builder = builder
	store.keeps = false
	store.title = "A small red house"
	var together := Together.new()
	together.world = world
	together.builder = builder
	together.store = store
	together.keeps_place = false
	root.add_child(together)
	together.set_process(false)
	together.live = true
	together.owns = true
	together.link = "https://brickworks.diy/app?together=probe"
	together.people = [{"who": "00000000", "name": "Ada", "me": true, "here": true, "owner": true}]
	var said: Array = []
	together.said.connect(func(words: String) -> void: said.append(words))
	var dialog := TogetherDialog.new()
	dialog.together = together
	root.add_child(dialog)
	dialog.open()
	await _frames(6)

	print("1. not open to watchers yet")
	var named: Dictionary = dialog.controls_by_name()
	_check(named.has("together_watch_open"), "the owner is offered Open to watchers", str(named.keys()))
	_check(not named.has("together_watch_close"), "and no Close to watchers yet")

	print("2. open: its page and how many watch")
	together.watch = {"watch": "AbcdEfghIjkL", "link": "https://brickworks.diy/live/AbcdEfghIjkL", "watchers": 3}
	together.changed.emit()
	await _frames(4)
	named = dialog.controls_by_name()
	_check(not named.has("together_watch_open"), "Open to watchers is gone once it is open")
	_check(named.has("together_watch_copy") and named.has("together_watch_close"), "its page with Copy, and Close to watchers",
		str(named.keys()))
	_check(str(dialog.page_state().get("watch", "")) == "3 watching", "how many watch",
		str(dialog.page_state().get("watch", "")))
	# Open and Close in End's row, apart from End: no row of their own
	# (together_fit keeps End in sight on a tablet held sideways).
	_check(dialog._watch_close.get_parent() == dialog._end.get_parent()
		and dialog._watch_close.get_index() > dialog._end.get_index() + 1, "Close to watchers at the far end of End's row")

	print("3. a watcher's line, as the log brings it")
	together._take([{"seq": 1, "who": "5a5a5a5a", "client": Together.WATCHING, "cid": 1,
		"changes": {"~chat": "Nice wheels!", "~by": "Wren"}}])
	await _frames(2)
	var last: Dictionary = together.messages.back() if not together.messages.is_empty() else {}
	_check(str(last.get("name", "")) == "Wren" and str(last.get("text", "")) == "Nice wheels!",
		"the line in the chat by the watcher's name", str(last))
	_check(said.has("Wren: Nice wheels!"), "and said on the status line", str(said))

	print("4. an ask to build, then the seat")
	together._take([{"seq": 2, "who": "5a5a5a5a", "client": Together.WATCHING, "cid": 2,
		"changes": {"~ask": "Wren", "~by": "Wren"}}])
	await _frames(4)
	_check(together.asks.size() == 1 and str((together.asks[0] as Dictionary).get("who")) == "5a5a5a5a",
		"the ask kept, by who asked", str(together.asks))
	_check(said.any(func(words: String) -> bool: return words.begins_with("Wren asks to build with you")),
		"the designer told on the status line", str(said))
	named = dialog.controls_by_name()
	_check(named.has("together_seat_1") and (named["together_seat_1"] as Button).text == "Give a seat",
		"Give a seat beside it", str(named.keys()))
	# The same person asking again is one ask.
	together._take([{"seq": 3, "who": "5a5a5a5a", "client": Together.WATCHING, "cid": 3,
		"changes": {"~ask": "Wren", "~by": "Wren"}}])
	await _frames(2)
	_check(together.asks.size() == 1, "asked twice, one ask", str(together.asks))
	together._take([{"seq": 4, "who": "00000000", "client": Together.WATCHING, "cid": 4,
		"changes": {"~seat": "5a5a5a5a", "~key": "sealed"}}])
	await _frames(4)
	_check(together.asks.is_empty(), "the seat given takes the ask away", str(together.asks))
	_check(not dialog.controls_by_name().has("together_seat_1"), "and its Give a seat")
	for key: String in ["~ask", "~by", "~seat", "~key", "~chat"]:
		_check(not together._confirmed.has(key), "%s is not taken for the model's own state" % key)
	_check(together.seq == 4, "every op numbered in order", str(together.seq))

	print("5. a joiner sees none of it")
	together.owns = false
	together.changed.emit()
	await _frames(4)
	named = dialog.controls_by_name()
	_check(not named.has("together_watch_open") and not named.has("together_watch_close"),
		"no watch controls for a joiner", str(named.keys()))
	_check(not dialog._watch_box.visible, "the watch box hidden")

	print("6. the session stopped: the show forgotten")
	together.owns = true
	together._stop("ended")
	_check(together.watch.is_empty() and together.asks.is_empty(), "no show and no asks once it stopped")

	dialog.queue_free()
	together.queue_free()
	builder.queue_free()
	world.queue_free()
	await _frames(2)
	print("\ntogether_watch probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(ok: bool, what: String, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("  %s  %s%s" % ["ok" if ok else "FAIL", what, "" if ok or detail.is_empty() else " (%s)" % detail])
