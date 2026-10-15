## The tools only the viewer in Claude calls (MCP Apps), through the host,
## from the card the conversation shows beside a call (api/_viewer.js).
##
## The spec lets a server keep a tool from the model and give it to its
## app alone (_meta.ui.visibility ["app"]): the relay lists these so, and
## only to a client that says it shows such pages, so Claude's own list and
## the guidance it reads do not grow by a word. The relay also answers a
## resources/read of brickworks://viewer/<name> with the same, for a host
## that will not call a tool its model was not given (api/mcp.js).
##
##   viewer_scene  the model, packed (ModelScene), its parts count, the tab
##                 and the model's name; views: true for pictures as well
##   viewer_check  Tools, Check stability, read and not shown: the weak
##                 joints Stability finds and the stud joints Balance finds
##                 carrying half their working load or more
##   viewer_steps  the steps, as the booklet sets them out
##                 (Instructions.plan, the author's where they set them)
##   viewer_parts  the parts list (Inventory) and the BrickLink wanted list
##   viewer_pick   select one part in this tab, as a click on it would, so
##                 Claude's selection tool reads what the person picked in
##                 the card
##
## None of them changes the model. They do not take the app's turn either:
## a card asks while Claude is working, and reading the model then gives it
## as it stands. viewer_pick only selects, and not while a call is running.
class_name ViewerTools
extends RefCounted

const NAMES: Array[String] = ["viewer_scene", "viewer_check", "viewer_steps", "viewer_parts",
	"viewer_pick"]
## From this many parts the steps are set out a little each frame, as the
## booklet's are, which is only done when no call is changing the model.
const PACED_FROM := 1500

var assistant: Assistant
var app: Node = null
## The pictures the viewer is given, from the socket's ModelViews, when
## asked for: Callable() -> {parts, views}.
var pictures: Callable = Callable()
## The socket's packer (ModelViews.scene), so a model packed for an answer
## is not packed again for the card that asks.
var scenes := ModelScene.new()


static func handles(name: String) -> bool:
	return NAMES.has(name)


## [param busy]: another call has the app.
func answer(name: String, input: Dictionary, busy: bool) -> Dictionary:
	if assistant == null or assistant.world == null:
		return _said("This tab has no model to show.", {"busy": true})
	match name:
		"viewer_scene":
			return await _scene_of(input, busy)
		"viewer_check":
			return await _check(busy)
		"viewer_steps":
			return await _steps(busy)
		"viewer_parts":
			return _parts()
		"viewer_pick":
			return _pick(input, busy)
	return _said("No viewer tool called %s." % name, {}, true)


static func _said(words: String, data: Dictionary, error: bool = false) -> Dictionary:
	return {"content": [{"type": "text", "text": words}], "structuredContent": data, "isError": error}


func _parts_count() -> int:
	return maxi(assistant.world.brick_count() - assistant.scenery.size(), 0)


func _now() -> String:
	return ModelScene.of(assistant.world)


## What the model is called, as the window's title has it.
func _title() -> String:
	var store: Variant = app.get("_store") if app != null else null
	return str(store.get("title")) if store is Object and store.get("title") != null else ""


func _scene_of(input: Dictionary, busy: bool) -> Dictionary:
	var world: BrickWorld = assistant.world
	var packed: Dictionary = scenes.pack(world, assistant.library, assistant.scenery)
	var data: Dictionary = {"of": packed["of"], "scene": packed, "parts": _parts_count(),
		"model": _title(), "tab": TabSession.id(),
		"working": busy}
	if bool(input.get("views", false)) and not busy and pictures.is_valid():
		var shown: Dictionary = await pictures.call()
		data["views"] = shown.get("views", [])
	return _said("The model as it stands: %d parts." % int(data["parts"]), data)


func _check(busy: bool) -> Dictionary:
	var world: BrickWorld = assistant.world
	var scenery: Dictionary = assistant.scenery
	var weak: Array = []
	var said: String = "it stands up — no joint is carrying more than it can hold"
	var stability: Stability = app.get("_stability") if app != null else null
	if stability != null:
		stability.floor_ids = scenery
		var report: Stability.Report = stability.check(world)
		for risk: Stability.Risk in report.risks:
			if risk.kind == "tips" or risk.brick_id == 0 or scenery.has(risk.brick_id) \
					or world.get_brick(risk.brick_id) == null:
				continue
			weak.append({"id": risk.brick_id, "message": risk.message})
		if not weak.is_empty():
			said = "%d weak joint%s: %s" % [weak.size(), "" if weak.size() == 1 else "s",
				str(weak[0]["message"])]
	var stress: Array = []
	var shell: Shell = app.get("_shell") as Shell if app != null else null
	var balance: Balance.Report = null
	# As it stands, no pose swept: the sweep swings the joints through their
	# reach and back, which is a change of the model to anyone watching it
	# (the card's own "of"), and a card looks without touching.
	if shell != null and not busy:
		balance = await shell.weigh_balance([], false, false)
	if balance != null:
		for one: Balance.JointLoad in balance.joints:
			if one.ratio >= 0.5 and not scenery.has(one.beyond) and world.get_brick(one.beyond) != null:
				stress.append([one.beyond, snappedf(one.ratio, 0.01)])
	var words: String = said
	if balance != null and not balance.empty:
		words = balance.words() if weak.is_empty() else "%s. %s" % [said, balance.words()]
	words = words.left(1).to_upper() + words.substr(1)
	return _said(words, {"of": _now(), "weak": weak, "stress": stress, "words": words,
		"weighed": balance != null})


func _steps(busy: bool) -> Dictionary:
	var world: BrickWorld = assistant.world
	var steps: Array[Instructions.Step] = []
	if world.brick_count() >= PACED_FROM:
		if busy:
			return _said("Brickworks is busy with Claude's call; set out the steps again in a moment.",
				{"busy": true})
		var job: Working.Job = Working.begin("Setting out the steps…")
		await job.shown()
		steps = await Instructions.plan_paced(world, assistant.library, assistant.scenery, {}, job, true)
		job.end()
	else:
		steps = Instructions.plan(world, assistant.library, assistant.scenery, {}, true)
	var out: Array = []
	for step: Instructions.Step in steps:
		var ids: Array = []
		for id: int in step.brick_ids:
			ids.append(id)
		var shown: Array = []
		for id: int in step.shown_ids:
			shown.append(id)
		out.append({"number": step.number, "ids": ids, "shown": shown, "section": step.section,
			"assembly": step.assembly, "times": step.times, "callout": step.callout,
			"callout_step": step.callout_step, "callout_steps": step.callout_steps,
			"figure": step.figure})
	return _said("%d steps, as the booklet sets them out." % out.size(), {"of": _now(), "steps": out})


func _parts() -> Dictionary:
	var stock: Inventory = Inventory.of(assistant.world, assistant.library, assistant.scenery)
	var lots: Array = []
	for lot: Inventory.Lot in stock.lots:
		lots.append({"part": lot.part_id, "name": lot.name, "code": lot.color_code,
			"colour": lot.color_name, "rgb": lot.rgb_hex.trim_prefix("#"), "count": lot.count,
			"element": lot.element, "bricklink": lot.bricklink_id, "custom": lot.custom})
	var bricklink: Dictionary = ShopLists.bricklink_xml(stock, assistant.library)
	var title: String = _title()
	var file: String = (title if not title.is_empty() else "brickworks").to_lower() \
		.replace(" ", "-").validate_filename() + "-bricklink.xml"
	return _said("%d pieces in %d lots." % [stock.pieces, lots.size()], {"of": _now(), "lots": lots,
		"pieces": stock.pieces, "grams": snappedf(stock.grams, 0.1), "file": file,
		"bricklink": {"text": str(bricklink.get("text", "")),
			"left_out": ShopLists.why_left_off(bricklink, "BrickLink")}})


func _pick(input: Dictionary, busy: bool) -> Dictionary:
	var world: BrickWorld = assistant.world
	var builder: Builder = assistant.builder
	if str(input.get("of", "")) != _now():
		return _said("The model has changed since the card was made: nothing selected.",
			{"of": _now(), "selected": false, "changed": true})
	if busy or builder == null:
		return _said("Not now: a call is changing the model.", {"of": _now(), "selected": false,
			"why": "busy" if busy else "no builder"})
	var id: int = int(input.get("brick", 0))
	builder.selection.clear()
	if id != 0 and world.get_brick(id) != null and not assistant.scenery.has(id):
		builder.selection[id] = true
	builder.selection_changed.emit(builder.selection.size())
	return _said("Selected #%d." % id if builder.selection.has(id) else "Nothing selected.",
		{"of": _now(), "selected": builder.selection.has(id)})
