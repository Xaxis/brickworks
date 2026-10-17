## The model as it now stands, for the viewer Claude shows beside a call.
##
## Claude on the web, the desktop and the phone can show a server's own
## page inline in a conversation (MCP Apps). The relay serves one, a model
## viewer (api/_viewer.js), names it on the tools whose answer is the model
## as it now stands, and asks the tab for this only on a session whose
## client said at initialize that it shows such pages. Every other client
## is answered exactly as before, and the app draws nothing more for it.
##
## What the viewer is given rides in the answer's _meta, which no client
## hands the model it is talking to: the parts count, the model itself,
## packed for the viewer to draw in 3D (ModelScene), and a picture a person
## would look at, without the stud numbers a design is shown, to show while
## the 3D comes and wherever it cannot. An answer with a picture of its own
## (view_model, edit_model) is shown with that picture; one with none
## (submit_design, look_at_model, open_model, brickify) is given the front
## corner, and the viewer asks for the rest of the turntable, four corners
## round the model, only where it cannot draw in 3D (ViewerTools). Each is
## drawn once for each change of the model however often it is asked for.
##
## A host need not hand the card this at all, and most sessions of Claude's
## do not say they show pages: the card then asks the tab itself
## (ViewerTools, viewer_scene), so the model is shown either way.
class_name ModelViews
extends RefCounted

## Where it goes in the answer's _meta. api/_viewer.js reads it.
const KEY := "brickworks/view"
## What the relay puts in a call's own _meta to ask for it.
const ASKED := "brickworks/views"

## The tools the viewer is named on, as api/_viewer.js names them, and
## whether each needs a turntable drawn (true) or carries its own picture.
const TOOLS := {
	"submit_design": true,
	"look_at_model": true,
	"view_model": false,
	"edit_model": false,
	"open_model": true,
	"brickify": true,
}

## Round the model, a quarter turn each: front right, back right, back
## left, front left (ModelShot.ANGLES).
const TURNTABLE: Array[String] = ["corner", "back right", "far corner", "front left"]
## The order they are drawn in: front and back first.
const DRAWN_FIRST: Array[String] = ["corner", "far corner", "back right", "front left"]

## Small enough that four ride in one answer, big enough to fill the frame
## a chat gives a page.
const SIZE := 480
## And all of them in at most this many characters: claude.ai keeps a tool
## result over about 150,000 out of the conversation, and the viewer with it
## (claude.com/docs/connectors/building/mcp-apps/troubleshooting).
const MOST_CHARACTERS := 100000
## The packed model takes what it needs of that first, up to this; a model
## bigger still is left for the viewer to ask for (viewer_scene).
const MOST_SCENE := 80000
## A turntable is cut short rather than hold up the answer: on a big model
## in a browser drawing in software one picture can take tens of seconds.
var budget_s: float = 12.0

## The views drawn of the model as it last stood, by side, and what it was.
var _kept_of: Array = []
var _kept: Dictionary = {}
## The model packed, kept as the views are; ViewerTools packs with it too.
var scene := ModelScene.new()


## Whether a call asked for the viewer's share of the answer.
static func asked(params: Dictionary) -> bool:
	var meta: Variant = params.get("_meta")
	return meta is Dictionary and bool((meta as Dictionary).get(ASKED, false))


## What the viewer is given for [param tool]'s answer: {parts, scene,
## views}, or scene_by_call in place of a scene too big to carry. A view is
## {from, mimeType, data}, the data base64. [param whole]: the whole
## turntable, for a viewer that cannot draw in 3D; else the front corner.
func of(assistant: Assistant, tool: String, whole: bool = false) -> Dictionary:
	var world: BrickWorld = assistant.world if assistant != null else null
	if world == null:
		return {}
	var shown: Dictionary = {"parts": maxi(world.brick_count() - assistant.scenery.size(), 0),
		"views": []}
	var carried: int = 0
	if int(shown["parts"]) > 0:
		var packed: Dictionary = scene.pack(world, assistant.library, assistant.scenery)
		carried = JSON.stringify(packed).length()
		if carried <= MOST_SCENE:
			shown["scene"] = packed
		else:
			carried = 0
			shown["scene_by_call"] = true
	if (whole or bool(TOOLS.get(tool, false))) and int(shown["parts"]) > 0 and ModelShot.possible():
		var sides: Array[String] = ["corner"]
		if whole:
			sides = TURNTABLE
		shown["views"] = await _turntable(assistant, sides, MOST_CHARACTERS - carried)
	return shown


## The turntable of the model as it stands: the views kept for it, and as
## many more drawn as the budget allows, the front first and then the back,
## so a call cut short shows the front and the next call goes on with the
## rest. In turning order.
func _turntable(assistant: Assistant, sides: Array[String], room: int) -> Array:
	var world: BrickWorld = assistant.world
	var of_now: Array = [world.get_instance_id(), world.generation(), world.revision]
	if of_now != _kept_of:
		_kept_of = of_now
		_kept = {}
	var shot: ModelShot = assistant._ensure_shot()
	# As a person sees it: no studs written on, nothing picked out.
	var was: Array = [shot.rulers, shot.highlight, shot.marks]
	shot.rulers = false
	shot.highlight = {}
	shot.marks = []
	var until: float = Time.get_unix_time_from_system() + budget_s
	for from: String in DRAWN_FIRST:
		if _kept.has(from) or not sides.has(from):
			continue
		if Time.get_unix_time_from_system() > until:
			break
		var image: Image = await shot.take(world, from, assistant.scenery)
		var data: String = ""
		if image != null:
			data = await _encoded(assistant, image)
		# Kept only when the model did not change while it was drawn.
		if not data.is_empty() and of_now == [world.get_instance_id(), world.generation(),
				world.revision] and of_now == _kept_of:
			_kept[from] = data
	shot.rulers = was[0]
	shot.highlight = was[1]
	shot.marks = was[2]
	var views: Array = []
	var carried: int = 0
	for from: String in TURNTABLE:
		var data: String = str(_kept.get(from, ""))
		if sides.has(from) and not data.is_empty() and carried + data.length() <= room:
			carried += data.length()
			views.append({"from": from, "mimeType": "image/webp", "data": data})
	return views


## A picture made small and encoded, off the page's one thread where there
## are others (as ModelShot.encode).
static func _encoded(on: Node, image: Image) -> String:
	var small: Image = image.duplicate()
	var out: Array = [""]
	var work := func() -> void:
		small.convert(Image.FORMAT_RGB8)
		small.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		out[0] = Marshalls.raw_to_base64(small.save_webp_to_buffer(true, 0.8))
	if OS.has_feature("nothreads"):
		work.call()
	else:
		var task: int = WorkerTasks.add(work, false, "encode a view of the model")
		while not WorkerThreadPool.is_task_completed(task):
			await on.get_tree().process_frame
		WorkerTasks.collect(task)
	return str(out[0])
