## Best path traced in a browser (photoreal28): PathTracer's set handed to
## page_tracer.js, the desktop's own tracer (path_tracer.glsl) run as WebGL2
## shaders on the visitor's graphics card, beside the page.
##
## Nothing of it is fetched until a Best that is path traced starts: tracer.js
## sits beside the build (tools/export.sh writes it, tools/web/tracer_port.py
## puts the shaders in it), so a first visit's load is what it was. Whether this
## browser can is asked of a throwaway WebGL2 context, which needs none of it:
## WebGL2 with float targets on a graphics card. A browser drawing without one
## (SwiftShader and its like: a picture would take many minutes) keeps Best
## frames averaged unless the address asks for the tracer (?tracer=on), and
## ?tracer=off keeps it so anywhere. What PathTracer gives the card is given
## here as it is: bytes go over as base64, the picture comes back as a
## Uint8Array (JavaScriptBridge.js_buffer_to_packed_byte_array).
##
## PathTracer and StudioRender preload it (no class_name): nothing else needs it.
extends RefCounted

## What this browser was found to do: "" not yet asked, "yes", "software",
## "off" (the address said), "no WebGL2", "no float targets", "no parallel
## compile" (no KHR_parallel_shader_compile: the compile would hold the page).
## A browser drawing without a graphics card says "software" first: that is
## why it does not trace, whatever else it lacks (SwiftShader has neither).
static var _can: String = ""
## Why the tracer stopped in this tab, "" while it has not: Best is frames
## averaged from then on.
static var _failed: String = ""
static var _asked: bool = false

const CAN := """(function () {
	try {
		var asked = new URLSearchParams(location.search).get('tracer');
		if (asked === 'off') { return 'off'; }
		var canvas = typeof OffscreenCanvas !== 'undefined' ? new OffscreenCanvas(1, 1) : document.createElement('canvas');
		var gl = canvas.getContext('webgl2');
		if (!gl) { return 'no WebGL2'; }
		var floats = !!gl.getExtension('EXT_color_buffer_float');
		var parallel = !!gl.getExtension('KHR_parallel_shader_compile');
		var info = gl.getExtension('WEBGL_debug_renderer_info');
		var name = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : '';
		var lose = gl.getExtension('WEBGL_lose_context');
		if (lose) { lose.loseContext(); }
		if (!floats) { return 'no float targets'; }
		if (/swiftshader|llvmpipe|software|basic render/i.test(name) && asked !== 'on') { return 'software'; }
		if (!parallel && asked !== 'on') { return 'no parallel compile'; }
		return 'yes';
	} catch (e) {
		return 'no WebGL2';
	}
})()"""


## Whether Best can be path traced in this tab.
static func usable() -> bool:
	return can() == "yes" and _failed.is_empty()


## What this browser can do, asked once.
static func can() -> String:
	if not OS.has_feature("web"):
		return "no WebGL2"
	if _can.is_empty():
		var said: Variant = JavaScriptBridge.eval(CAN, true)
		_can = "no WebGL2" if said == null else str(said)
	return _can


## Why Best is not path traced in this tab, in plain words.
static func why_not() -> String:
	if not _failed.is_empty():
		return "Path tracing stopped in this browser, so Best is frames averaged."
	match can():
		"software":
			return ("This browser draws without a graphics card, too slowly to path trace, "
				+ "so Best is frames averaged.")
		"off":
			return "Path tracing is turned off for this page, so Best is frames averaged."
		"no parallel compile":
			# Without KHR_parallel_shader_compile the page can only ask whether
			# the tracer compiled by waiting for it: half a minute or more of a
			# tab that does not answer, the first time.
			return ("This browser would freeze the page while it readies path tracing, "
				+ "so Best is frames averaged.")
		"yes":
			return ""
	return "This browser's graphics cannot path trace, so Best is frames averaged."


## What stopped the tracer, for the log and the checks: "" while nothing has.
static func failure() -> String:
	return _failed


## The tracer stopped: Best is frames averaged in this tab from now on.
static func fail(why: String) -> void:
	if _failed.is_empty():
		_failed = why if not why.is_empty() else "failed"
		push_warning("page tracer: " + _failed)


## Whether the tracer is there to be given a set: fetched, started, not failed.
static func started() -> bool:
	return usable() and _tracer() != null


static func _state() -> String:
	var said: Variant = JavaScriptBridge.eval("String(window.brickworksTracerState || '')", true)
	return "" if said == null else str(said)


## The page's tracer, or null until a path-traced Best has fetched it.
## get_interface reports a script error for a name the page has not set, and
## the first Best asks (shape_of, started) before the script has come.
static func _tracer() -> JavaScriptObject:
	if str(JavaScriptBridge.eval("window.brickworksTracer ? 'there' : ''", true)) != "there":
		return null
	return JavaScriptBridge.get_interface("brickworksTracer")


## The tracer fetched and started, and [param version]'s shaders compiled
## for this card (beside the page: KHR_parallel_shader_compile where the
## browser has it), a frame at a time. [param doing] is told what it waits on.
## False, and the tracer failed, when any of it did not happen.
static func ready(version: String, doing: Callable = Callable()) -> bool:
	if not usable():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if not _asked:
		_asked = true
		var at: String = Origin.build() + "tracer.js"
		JavaScriptBridge.eval(("(function (at) { window.brickworksTracerState = 'loading';"
			+ " import(at).then(function (m) { m.start(); }).catch(function (e) {"
			+ " window.brickworksTracerState = 'failed: ' + String(e && e.message || e); }); })(%s)")
			% JSON.stringify(at), true)
	var began: int = Time.get_ticks_msec()
	if doing.is_valid():
		doing.call("fetching the path tracer")
	while _state() == "loading":
		if Time.get_ticks_msec() - began > 60000:
			fail("its script did not arrive in a minute")
			return false
		await tree.process_frame
	if _state() != "started":
		fail(_state() if not _state().is_empty() else "its script did not start")
		return false
	if doing.is_valid():
		doing.call("readying the path tracer for this graphics card")
	began = Time.get_ticks_msec()
	while true:
		var tracer: JavaScriptObject = _tracer()
		if tracer == null:
			fail("it went")
			return false
		var said: String = str(tracer.state(version))
		if said == "ready":
			return true
		if said != "compiling":
			fail(said)
			return false
		if Time.get_ticks_msec() - began > 120000:
			fail("its shaders took more than two minutes")
			return false
		await tree.process_frame
	return false


static func _b64(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes)


## A shape, by [param key]: points and normals (3 floats each), corners (3 a triangle).
static func shape(key: int, points: PackedByteArray, normals: PackedByteArray,
		corners: PackedByteArray) -> int:
	var tracer: JavaScriptObject = _tracer()
	if tracer == null:
		return 0
	return int(tracer.shape(key, _b64(points), _b64(normals), _b64(corners)))


## Every shape let go.
static func forget_all() -> void:
	var tracer: JavaScriptObject = _tracer()
	if tracer != null:
		JavaScriptBridge.eval("window.brickworksTracer && window.brickworksTracer.tracer.shapes.clear()", true)


## The set: [param keys] the shapes in the stage's order, [param records] 80
## bytes an instance, [param places] 16 floats an instance, [param which]
## each instance's shape in [param keys].
static func stage(keys: PackedInt32Array, records: PackedByteArray, places: PackedFloat32Array,
		which: PackedInt32Array) -> bool:
	var tracer: JavaScriptObject = _tracer()
	if tracer == null:
		return false
	var joined := PackedStringArray()
	for key: int in keys:
		joined.append(str(key))
	var shapes := PackedStringArray()
	for n: int in which:
		shapes.append(str(n))
	var done: bool = bool(tracer.stage(",".join(joined), _b64(records), _b64(places.to_byte_array()),
		",".join(shapes)))
	if not done:
		fail(str(tracer.problem()))
	return done


## The place's picture as half floats (RGBAH), and its table.
static func place(size: Vector2i, halves: PackedByteArray, table: PackedFloat32Array) -> void:
	var tracer: JavaScriptObject = _tracer()
	if tracer != null:
		tracer.place(size.x, size.y, _b64(halves), _b64(table.to_byte_array()))


## What a staged model stands on: an RGBA8 tile.
static func surface(size: Vector2i, bytes: PackedByteArray) -> void:
	var tracer: JavaScriptObject = _tracer()
	if tracer != null:
		tracer.surface(size.x, size.y, _b64(bytes))


static func begin(size: Vector2i, scene: PackedByteArray, version: String) -> bool:
	var tracer: JavaScriptObject = _tracer()
	if tracer == null:
		return false
	var done: bool = bool(tracer.begin(size.x, size.y, _b64(scene), version))
	if not done:
		fail(str(tracer.problem()))
	return done


## [param count] samples more, the whole picture at once when [param whole];
## else as much as the card does in a frame's share. The samples so far.
static func trace(count: int, seed: int, whole: bool) -> int:
	var tracer: JavaScriptObject = _tracer()
	if tracer == null:
		return 0
	return int(tracer.trace(count, seed, whole))


## Whether no block of samples is part way down the picture: every row has
## as many samples.
static func between() -> bool:
	var tracer: JavaScriptObject = _tracer()
	return tracer == null or bool(tracer.between())


## The picture through the resolve's [param numbers]: RGBA8, top row first.
static func picture(numbers: PackedFloat32Array) -> PackedByteArray:
	var tracer: JavaScriptObject = _tracer()
	if tracer == null:
		return PackedByteArray()
	var pixels: Variant = tracer.picture(_b64(numbers.to_byte_array()))
	if not pixels is JavaScriptObject:
		return PackedByteArray()
	return JavaScriptBridge.js_buffer_to_packed_byte_array(pixels)


## What the tracer did, for the checks: passes, rows a pass, its timings.
static func stats() -> String:
	var tracer: JavaScriptObject = _tracer()
	return "" if tracer == null else str(tracer.stats())


static func release() -> void:
	var tracer: JavaScriptObject = _tracer()
	if tracer != null:
		tracer.release()
