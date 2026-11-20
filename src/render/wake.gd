## Nodes asleep at rest, woken by what gives them work.
##
## Every panel looked at its world every frame to see whether anything had
## changed: the status bar, the steps bar, the phone's tools, the bin, the
## camera, the view cube and thirty more. Each look is small, but on a slow
## phone (a quarter of this box's speed in Chromium) the forty of them were
## 4 to 6 ms of every frame with nothing moving, over an engine that needs
## 0.4 (idleframes, 2026-11-19): battery and heat for nobody, and the frame
## budget a turn needs.
##
## So a node that only shows what changed sleeps once it has nothing to do
## ([method rest]: it stops processing), and anything that can give it work
## wakes every sleeper at once ([method all]): an input (a key, a click, a
## finger, the pointer moving), the window resized or brought back into
## view, the model changed (BrickWorld's revision), the camera moving, a
## server's answer (PageFetch), a message from the connector or a Together
## peer. Nothing polls to find out whether to wake.
##
## After anything happens every sleeper runs for at least [constant FRAMES]
## frames and [constant MS] ms before it may sleep again, so what an act
## sets going (a layout settling, a deferred call, an answer a frame later)
## is seen. A node with work of its own still to come (a search on a
## worker, a timer it is counting down, a part's picture on its way) does
## not call [method rest] until it has done it.
##
## As the app runs, but not in a probe that did not turn it on itself
## ([method begin]): most probes change the model and the selection by
## calling the app directly, with no input, and look at the panels a frame
## later, as IdleDraw is kept off for them.
class_name Wake
extends RefCounted

## After a wake, every sleeper runs for at least this many frames...
const FRAMES := 3
## ...and this many milliseconds, before it may sleep again.
const MS := 400

## Whether sleeping is on: off until the app (or a probe) turns it on.
static var on: bool = false
## The process frame the last wake was in, and when it was (ticks, ms).
static var _woke_frame: int = -100
static var woke_ms: int = 0
## The nodes put to sleep since the last wake, by instance id.
static var _asleep: PackedInt64Array = PackedInt64Array()
static var _listening: bool = false
## How many times anything woke the sleepers, and how many nodes were put
## to sleep, since the start: for a probe and the page's state.
static var wakes: int = 0
static var slept: int = 0


## As the app runs: on, but not in a probe that did not turn it on itself,
## or was not run with `-- --wake` (a probe that drives the app by input
## alone, as idle_probe does: what a person does, with every node asleep).
static func for_the_app() -> void:
	if OS.get_cmdline_args().has("--script") and not OS.get_cmdline_user_args().has("--wake"):
		return
	begin()


## Sleeping on, listening for every input and the window's size.
static func begin() -> void:
	on = true
	all()
	if _listening:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_listening = true
	# The class's own functions, not lambdas: the window outlives the
	# scripts at exit (PointerPace._listen).
	tree.root.window_input.connect(Wake._heard)
	tree.root.size_changed.connect(Wake.all)
	tree.root.focus_entered.connect(Wake.all)
	# A frame drawn: something on screen changed (the camera moved, a part's
	# shape came, a panel folded, a dialog opened), and at rest none is
	# drawn (IdleDraw), so whatever shows what follows from it looks again.
	RenderingServer.frame_pre_draw.connect(Wake.all)
	if OS.has_feature("web"):
		_listen_to_page()


## The page's own events that give the app work with no input of its own:
## the tab brought back into view, and a check's question
## (window.brickworksAsk<what>, brickworksGrabAsk, brickworksTogetherAsk,
## brickworksLookAsk), which the app reads when it next tells the page and
## which a sleeping app would never read. Each is made a property whose
## setter wakes the app when it is set to anything but nothing.
static func _listen_to_page() -> void:
	_page_wakes = JavaScriptBridge.create_callback(Wake._page_said)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.set(&"brickworksWake", _page_wakes)
	JavaScriptBridge.eval("""(function () {
	var wake = function () { if (window.brickworksWake) window.brickworksWake(); };
	document.addEventListener("visibilitychange", wake);
	window.addEventListener("resize", wake);
	window.addEventListener("pageshow", wake);
	%s.forEach(function (name) {
		var held = window[name];
		Object.defineProperty(window, name, { configurable: true, enumerable: true,
			get: function () { return held; },
			set: function (value) { held = value; if (value) wake(); } });
	});
})();""" % JSON.stringify(PAGE_ASKS), true)


## What a check asks the app by setting on the page.
const PAGE_ASKS := ["brickworksAskLayout", "brickworksAskPhone", "brickworksAskWords",
	"brickworksGrabAsk", "brickworksTogetherAsk", "brickworksLookAsk"]
static var _page_wakes: JavaScriptObject = null


static func _page_said(_args: Array) -> void:
	all()


## Sleeping off: every sleeper woken, and none put to sleep again.
static func end() -> void:
	all()
	on = false


static func _heard(_event: InputEvent) -> void:
	all()


## Something happened that may give any node work: every node asleep is
## woken, and none sleeps again for [constant FRAMES] frames and
## [constant MS] ms. Cheap when called again in the same frame (a model's
## every brick changed). Only on the main thread: a world changed on a
## worker is a copy that nobody is shown.
static func all() -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _woke_frame:
		return
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return
	_woke_frame = frame
	woke_ms = Time.get_ticks_msec()
	wakes += 1
	if _asleep.is_empty():
		return
	var woken: PackedInt64Array = _asleep
	_asleep = PackedInt64Array()
	for id: int in woken:
		var node: Node = instance_from_id(id) as Node
		if node != null:
			node.set_process(true)


## [param node] has nothing to do: it stops processing from the next frame
## until something wakes it, unless something happened lately. Called from
## its _process when nothing it shows has changed and nothing of its own
## is under way.
static func rest(node: Node) -> void:
	if not on or not node.is_processing():
		return
	if lately():
		return
	node.set_process(false)
	var id: int = node.get_instance_id()
	if not _asleep.has(id):
		_asleep.append(id)
	slept += 1


## Whether something happened within the last [constant FRAMES] frames and
## [constant MS] ms: nothing sleeps meanwhile.
static func lately() -> bool:
	return Engine.get_process_frames() - _woke_frame <= FRAMES or Time.get_ticks_msec() - woke_ms < MS


## Whether a page told at [param told_ms] (ticks, ms) was told before what
## the last wake set going had settled, so it is owed one more telling: a
## node that tells the page stays awake until it has told it.
static func owed(told_ms: int) -> bool:
	return on and told_ms <= woke_ms + MS


## Whether [param node] is asleep (a probe's question).
## [param node] turned off by its owner rather than put to sleep: nothing
## wakes it until the owner turns it on again (the grab in a viewer until the
## model has been read, Main._enter_view).
static func off(node: Node) -> void:
	var at: int = _asleep.find(node.get_instance_id())
	if at >= 0:
		_asleep.remove_at(at)
	node.set_process(false)


static func is_asleep(node: Node) -> bool:
	return _asleep.has(node.get_instance_id())
