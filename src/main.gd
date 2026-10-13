## The workbench: the scene you build in.
##
## For now this is the proof that the pipeline holds end to end — LDraw
## source converted offline, loaded as quantised geometry, batched by shape
## and drawn with per-instance colour — with a real published model opened
## as the test. Everything it does by hand here becomes a tool later.
extends Node3D

## Shipped with the build. It used to be read out of vendor/, which the
## export excludes, so the web build silently fell back to the demo wall.
const SAMPLE_MODEL := "res://models/car.ldr"

@onready var _camera: CadCamera = $CadCamera
@onready var _world: BrickWorld = $BrickWorld
@onready var _builder: Builder = $Builder
@onready var _status: Label = $HUD/Status
@onready var _title: Label = $HUD/Title

var _catalogue_ms: int = 0
var _stability: Stability
var _stability_text: String = ""
var _counts_base: String = ""
var _stability_at: int = 0
## The world's revision the stability line was worked out for.
var _stability_revision: int = -1
## Whether a worker is weighing the model now.
var _weighing: bool = false
## Bricks from which the model is weighed on a worker.
const WEIGH_OFF_THREAD_FROM := 600
var _counts: Label
var _bin_dock: SideDock
var _chat_dock: SideDock
## The left-hand column's sections: the parts bin, the model tree and the
## properties (src/ui/panel_stack.gd).
var _stack: PanelStack
## The strip along the top of the model for what is said about it for a
## while: the sub-assembly being edited, the offer to seat old parts.
var _notices: PanelContainer
## The part of the middle column the model shows through: what floats over
## the model (the cut-away's strip) is laid in it.
var _over_model: Control
var _store: ModelStore
## The baseplate, the grid floor or nothing under the model.
var _floor: FloorLayer
var _bar: ModelBar
var _bin: PartsBin
var _chat: ChatPanel
## The baseplate holds the example car of a first visit and nothing has
## been done to it. A design started then is built on a clear baseplate:
## it used to be built into the car, so a first-time visitor asking for a
## house got a house around a car they never asked for.
var _sample_untouched: bool = false
## What the model was named for the work going down on it (see
## [method _make_room]), until somebody saves it or opens another: the
## design's own title, when it stands, is a better name than its brief.
var _named_for_work: String = ""
## Driven from the command line, off-screen: nobody is watching the window.
## Set by [method _unthrottle_if_nobody_is_watching].
var _driven: bool = false
## Renderer numbers on the status line, for --stats only.
var _stats_shown: bool = _has_argument("--stats")
var _connector: ClaudeConnector
## When the controls were last told to the page. See [method _tell_page].
var _told_page_at: int = 0
## ...and how long telling it took the last time, which is a frame's work
## twice a second: a check reads it beside the slow frames.
var _told_page_us: int = 0
var _told_page_most_us: int = 0
var _deployment: Deployment
## Who is signed in. Everyone using Brickworks is (src/account/account.gd).
var _account: Account
## Over everything until someone is signed in, when a person is in front
## of the window to sign in (see [method _gate_wanted]).
var _gate: SignInGate
var _account_panel: AccountPanel
## Whether the connector has been put back as it was for this sign-in.
var _connector_resumed: bool = false
## A probe about the sign-in screen puts it up for itself (set before the
## scene enters the tree). The session it signs in with is never kept.
var gate_for_probe: bool = false
## A model shared by link (api/share.js). [member _viewing] is the link's id
## when this run is its read-only viewer (/app?view=<id>, as --view=<id>):
## no sign-in, nothing that edits, nothing written (_enter_view).
## [member _copying] is one to copy into this person's own models once
## they are signed in (/app?copy=<id>, Open in Brickworks). A probe sets
## either before the scene enters the tree.
var _viewing: String = ""
var _copying: String = ""
var _copy_started: bool = false
var _first_open_done: bool = false
var _shared: SharedModels
var _share_panel: SharePanel
var _share_view: ShareView
## Build it, in the viewer: the step player, the pages it shows, the line
## round each page's new parts, and the page it is on (_enter_build).
var _build_mode: BuildMode
var _build_pages: BuildSteps
var _build_outline: SelectionOutline
var _build_page: int = 0
## What was in sight before the player took the window, put back after.
var _build_left: Dictionary = {}
## How long turning to the last page took, and the longest, in microseconds:
## the page's own work, before the batches are written at the frame's end.
var _build_turned_us: int = 0
var _build_turned_most_us: int = 0
## ...and where the longest one's time went, ms by what it did.
var _build_turned_most: Dictionary = {}
## The part under the pointer, outlined: in the viewer, and named beside
## it; with Select in hand, what a click would take. -1 is not yet looked
## at: what is under a still pointer may have changed.
var _hover_outline: SelectionOutline
var _hovered: int = 0
var _hovered_from: Vector2 = Vector2(-1, -1)
var _view_pointer: Vector2 = Vector2(-1, -1)
var _steps: StepsBar
var _inventory: InventoryPanel
var _mosaic: MosaicDialog
var _brickify: BrickifyDialog
## The element maker: a part that is not in the library, made.
var _elements: ElementDialog
## Prints and stickers for any part (src/prints/print_studio.gd).
var _studio: PrintStudio
var _controls: ControlsDialog
var _figures: MinifigDialog
## File, Render… (src/ui/render_dialog.gd).
var _render: RenderDialog
## Build, Pose and animate… (src/ui/pose_panel.gd).
var _pose: PosePanel
## Tools, Simulate mechanism… (src/ui/simulate_panel.gd).
var _simulate: SimulatePanel
## Whether --ask finished with a design rather than an apology. Read by
## the exit status, so a script can tell.
var _ask_went_well: bool = true
## Whether a left press this handler saw started the box being drawn.
## The watchdog below will not finish one it never saw begin.
var _box_began: bool = false
## A box Escape threw away while the button was still down. Its release
## is not a click, and the rest of the drag does not start another box.
var _box_dropped: bool = false
## What the pointer says. See src/ui/cursors.gd.
var _cursors: Cursors
## Which of the two things that want a picture opened the file dialog.
var _picking_reference: bool = false
var _hint: ControlsHint
var _picker: PickImage
var _mosaic_source: Image
var _playback: BuildPlayback
var _outline: SelectionOutline
var _gizmo: ViewCube
var _turning: PivotMark
var _tools: TouchTools
var _marquee: Marquee
var _thumbnails: PartThumbnails
## Copy, paste, duplicate, moving and turning a selection: src/ui/edit_verbs.gd.
var _verbs: EditVerbs
## Those verbs as buttons down the left of the model.
var _shell: Shell
## The offer to seat an old model's parts on their studs.
var _seat_offer: SeatOffer
## A picture of the model, and its parts list for a shop.
var _exports: Exports
## The ruler: src/ui/measure.gd.
var _measure: Measure
## Laying a hose, a tube or a chain: src/ui/flex_tool.gd.
var _flex: FlexTool
var _assistant: Assistant
## Open only when --mcp asked for it. See src/net/command_socket.gd.
var _commands: CommandSocket = null
## Designing on the person's own Claude subscription, by starting the
## Claude Code they already have and pointing it back at this app.
var _claude_code: ClaudeCode = null

var _library: PartLibrary


## Screen-space antialiasing, where there is any.
##
## It was a project setting, which the web build could not honour:
## FXAA exists only on Forward+ and Mobile, and the browser runs
## Compatibility. Godot does not fall back quietly — it warns on every
## load, which is a line in everyone's console about a setting they
## cannot change.
## Make a pixel of interface the size a person expects.
##
## The project stretches its 1600 x 900 layout to the canvas
## (canvas_items, expand), device pixels and all, so a high-density
## screen is already accounted for: a 1400 point window shows 1600 units
## of interface at any ratio. This multiplied that by the device ratio as
## well, so at two to one the same window had 800 units for a toolbar and
## two panels that need about 1270, and the toolbar ran off at "He…"
## with the assistant off the page — on every Retina screen.
##
## A narrow screen is the case that wants more: there the panels are
## drawers (ROOMY), and a phone given the full 1600 units shows them a
## few millimetres tall. So below that width the factor is worked out
## from the window's size in points, giving about 720 units across and
## 480 down, whatever the ratio. The 3D is unaffected either way; it
## renders at full device resolution.
##
## And a laptop's window is the case between: wide enough for both panels,
## narrower than the layout. At 1280 x 720 the stretch alone drew all of it
## at 0.8, so text set at eleven units was under nine pixels — part
## numbers, notes, the key strip — on exactly the screens most people
## have. So no window that keeps its panels is drawn below MOST_SHRUNK,
## on the desktop as in a browser; the model's column gives up the room.
const MOST_SHRUNK := 0.92


## The content scale for a window this many points across and down: a
## pure function of the window, so a check can ask it about any size.
static func screen_factor(across: float, down: float, web: bool) -> float:
	var stretched: float = minf(across / 1600.0, down / 900.0)
	if across < ROOMY and web:
		var wanted: float = minf(across / 720.0, down / 480.0)
		return clampf(wanted / stretched, 1.0, 3.0)
	if stretched < MOST_SHRUNK:
		return MOST_SHRUNK / stretched
	return 1.0


func _match_screen_density() -> void:
	var across: float = Room.across()
	var down: float = Room.down()
	if across <= 0.0 or down <= 0.0:
		return
	var factor: float = screen_factor(across, down, OS.has_feature("web"))
	# Only when it changes: setting it resizes the visible rect, which
	# is what calls this again.
	if absf(get_window().content_scale_factor - factor) > 0.01:
		get_window().content_scale_factor = factor


## Each sub-assembly's own parts, where they are on the page: path ->
## {x, y} in CSS pixels, the top middle of their bounds.
func _assembly_places(to_window: Transform2D, per_css: float) -> Dictionary:
	var out: Dictionary = {}
	if _shell == null or _camera == null:
		return out
	var boxes: Dictionary = _shell.assemblies.own_bounds()
	for path: String in boxes:
		var box: AABB = boxes[path]
		var top := Vector3(box.get_center().x, box.end.y, box.get_center().z)
		if _camera.is_position_behind(top):
			continue
		var at: Vector2 = to_window * _camera.unproject_position(top) / per_css
		out[path] = {"x": roundi(at.x), "y": roundi(at.y)}
	return out


## Each sub-assembly's own parts, how high: path -> [lowest, highest], the
## heights of their origins in LDU.
func _assembly_heights() -> Dictionary:
	var out: Dictionary = {}
	if _shell == null:
		return out
	var boxes: Dictionary = _shell.assemblies.own_bounds()
	for path: String in boxes:
		var box: AABB = boxes[path]
		out[path] = [box.position.y, box.end.y]
	return out


## Where on the page each connector a part could be put onto is: a hole's
## middle, the middle of what a pin or an axle has free, a bar's or a
## clip's middle (JointSnap.End.middle). At most 160, in front of the view.
func _joint_places(to_window: Transform2D, per_css: float) -> Array:
	var out: Array = []
	if _builder == null or _camera == null:
		return out
	for site: JointSnap.End in _builder.joint_sites():
		if out.size() >= 160:
			break
		var point: Vector3 = site.middle()
		if _camera.is_position_behind(point):
			continue
		var brick: BrickWorld.Brick = _world.get_brick(site.brick)
		var at: Vector2 = to_window * _camera.unproject_position(point) / per_css
		out.append({"brick": site.brick, "part": brick.part_id if brick != null else "",
			"kind": site.kind, "x": roundi(at.x), "y": roundi(at.y)})
	return out


## Where the assistant's controls are on screen, put where the page can
## read it: window.brickworksControls, centres in CSS pixels, visible ones
## only. Web builds only, twice a second.
##
## tools/web/assistant_flow.mjs drives the panel as a person does, by
## clicking, and clicked at fixed positions — until a longer paragraph in
## the key form moved the field down seventeen pixels, the click landed on
## the text, and the key was typed into the app as keyboard shortcuts.
## A person finds the field by looking; this is how the test looks.
func _tell_page() -> void:
	if not OS.has_feature("web") or _chat == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _told_page_at < 500:
		return
	_told_page_at = now
	var telling: int = Time.get_ticks_usec()
	var ratio: Variant = JavaScriptBridge.eval("window.devicePixelRatio", true)
	var per_css: float = float(ratio) if ratio != null and float(ratio) > 0.0 else 1.0
	var to_window: Transform2D = get_viewport().get_final_transform()
	var where: Dictionary = {}
	var named: Dictionary = _chat.controls_by_name()
	if _bar != null:
		named.merge(_bar.controls_by_name())
	if _figures != null and _figures.visible:
		named.merge(_figures.controls_by_name())
	if _render != null and _render.visible:
		named.merge(_render.controls_by_name())
	if _pose != null:
		named.merge(_pose.controls_by_name())
	if _simulate != null:
		named.merge(_simulate.controls_by_name())
	if _elements != null:
		named.merge(_bin.controls_by_name())
		named.merge(_elements.controls_by_name())
	if _studio != null:
		named.merge(_studio.controls_by_name())
	if _account_panel != null:
		named.merge(_account_panel.controls_by_name())
	if _shell != null:
		named.merge(_shell.controls_by_name())
	if _seat_offer != null:
		named.merge(_seat_offer.controls_by_name())
	if _brickify != null:
		named.merge(_brickify.controls_by_name())
	if _shell != null:
		named.merge(_shell.status.working.controls_by_name())
	if _mosaic != null and _mosaic.visible:
		named.merge(_mosaic.controls_by_name())
	# Sharing: the owner's panel, the viewer's bar, and the two things the
	# viewer opens — the timeline and the parts list.
	if _share_panel != null:
		named.merge(_share_panel.controls_by_name())
	if _share_view != null:
		named.merge(_share_view.controls_by_name())
	if _build_mode != null:
		named.merge(_build_mode.controls_by_name())
	if _inventory != null:
		named.merge(_inventory.controls_by_name())
	if _steps != null:
		named.merge(_steps.controls_by_name())
	if _flex != null:
		named.merge(_flex.controls_by_name())
	# And the model's own part of the window, the column the box select
	# is laid over (the box itself is hidden until one is drawn): a
	# browser test aiming at the model found a panel there at a device
	# ratio of two, where the panels take more of the page.
	if _marquee != null:
		named["view"] = _marquee.get_parent()
	# The view cube's arrows and buttons, and below its visible faces.
	if _gizmo != null:
		named.merge(_gizmo.controls_by_name())
	# And the two rails, which on a phone are the only way to either panel:
	# the toolbar once ran wider than a phone and took the assistant's off
	# the page.
	if _bin_dock != null:
		named["parts_rail"] = _bin_dock.rail()
		named["assistant_rail"] = _chat_dock.rail()
	# The way in. While the sign-in screen is up nothing else can be
	# pressed, so nothing else is said to be there.
	if _gated():
		named = _gate.controls_by_name()
	for name: String in named:
		var control: Control = named[name]
		if control == null or not control.is_visible_in_tree():
			continue
		# A dialog's button is placed in the dialog, which is placed in the
		# window (New's question: tools/web/progress_check.mjs).
		var rect: Rect2 = control.get_global_rect()
		var holder: Viewport = control.get_viewport()
		if holder is Window and holder != get_window():
			rect.position += Vector2((holder as Window).position)
		var centre: Vector2 = (to_window * rect).get_center() / per_css
		where[name] = {"x": roundi(centre.x), "y": roundi(centre.y)}
	if _gizmo != null and _gizmo.is_visible_in_tree() and not _gated():
		var faces: Dictionary = _gizmo.face_points()
		for face: String in faces:
			var at: Vector2 = to_window * (faces[face] as Vector2) / per_css
			where[face] = {"x": roundi(at.x), "y": roundi(at.y)}
	JavaScriptBridge.eval("window.brickworksControls = %s" % JSON.stringify(where), true)
	# And, when a check asks for it, the model's part of the window and
	# what covers it (model_cover): a grid of points over it walked
	# through the interface is too much work to do twice a second.
	if not _gated() and bool(JavaScriptBridge.eval("window.brickworksAskLayout === true", true)):
		JavaScriptBridge.eval("window.brickworksAskLayout = false", true)
		JavaScriptBridge.eval("window.brickworksLayout = %s"
			% JSON.stringify(_layout_for_page(to_window, per_css)), true)
	if not _page_title.is_empty():
		JavaScriptBridge.eval("if (document.title !== %s) document.title = %s"
			% [JSON.stringify(_page_title), JSON.stringify(_page_title)], true)
	# And how many parts are standing, so a browser check can tell that a
	# click put something down rather than guess it from the pixels.
	if _world != null:
		JavaScriptBridge.eval("window.brickworksBricks = %d" % _world.brick_count(), true)
	# And what a test cannot see in the canvas: how many bricks there are,
	# what is in hand, which parts were made here.
	JavaScriptBridge.eval("window.brickworksState = %s" % JSON.stringify({
		"bricks": _world.brick_count() - _store.scenery.size(),
		# What it stands on, and the plates laid as scenery, for
		# tools/web/floor_flow.mjs.
		"floor": _store.model_floor.to_meta().trim_prefix(ModelFloor.META),
		"scenery": _store.scenery.size(),
		"own_plate": _floor != null and _floor.has_own_plate(),
		"held": _builder.held_part,
		"custom": _library.custom.keys(),
		# The tool in use and what is selected, so a browser check can
		# tell a click that selected from one that put a part down.
		"mode": _verbs.mode if _verbs != null else "",
		"selected": _builder.selection.size(),
		# ...and which, the first few: tools/web/centre_check.mjs clicks a
		# part and asks whether that one was taken.
		"selection": _builder.selection.keys().slice(0, 12),
		"carrying": _builder.is_carrying(),
		# The timeline, while it is up: its order, caption and step's parts
		# (tools/web/steps_flow.mjs).
		"timeline": _steps.page_state() if _steps != null else {},
		# What the renderer is drawing it with, and the frames this app's own
		# work made slow, for tools/web/freeze_check.mjs: a browser's long
		# tasks include drawing, which in software is most of a second a
		# frame and says nothing about this code.
		"batches": _drawn[0],
		"triangles": _drawn[1],
		"now": Time.get_ticks_msec(),
		"slow": _slow_frames,
		"told_ms": roundi(_told_page_us / 1000.0),
		"told_most_ms": roundi(_told_page_most_us / 1000.0),
		"playing": _playback != null and _playback.is_playing(),
		# The sub-assemblies, path -> their own parts, and the one being
		# edited: what tools/web/assembly_flow.mjs reads the tree by.
		"tree": _shell.assemblies.parts_by_path() if _shell != null else {},
		"editing": _shell.assemblies.entered if _shell != null else "",
		# ...and where on the page each one's own parts are, since opening
		# a model frames the view on it afresh.
		"places": _assembly_places(to_window, per_css),
		# ...and how high, lowest and highest part, in LDU: where to put a
		# cut that opens the room one stands in (see_inside_flow.mjs).
		"heights": _assembly_heights(),
		# Where the connectors a part can be put onto are on the page, and
		# whether the ghost is on one and may go down there, for
		# tools/web/technic_flow.mjs to aim a pin at a hole as a person does.
		"joints": _joint_places(to_window, per_css),
		"on_joint": _builder.is_on_joint(),
		"can_place": _builder.can_place(),
		# Where the view is: how far it has turned in all (not wrapped),
		# its tilt, its distance and what it looks at, for
		# tools/web/nav_flow.mjs to see a drag turn it all the way round.
		"view": {"yaw": _camera.yaw_turned(), "pitch": _camera.pitch_now(),
			"distance": _camera.distance_now(),
			"focus": [_camera.focus_now().x, _camera.focus_now().y, _camera.focus_now().z],
			"tool": _verbs.mode if _verbs != null else ""},
		# The status bar's line: what the mouse will do now.
		"hint": _verbs.hint() if _verbs != null else "",
		# Which columns are open, and how the window shares them out: a
		# narrow window shows one at a time, so a browser flow knows which
		# rail to click for a control in the other (openColumnFor in
		# tools/web/browser.mjs).
		"columns": {"parts": _bin_dock.is_open(), "assistant": _chat_dock.is_open(),
			"share": _columns},
		# What the last 3D model brickified came to, for brickify_flow.mjs.
		"brickified": _brickify.last_summary if _brickify != null else "",
		# And the last picture laid in LEGO Art, for art_flow.mjs.
		"art": _art_said,
		# The cut-away and x-ray (SeeInside), for tools/web/see_inside_flow.mjs:
		# where the plane is, and how many parts are drawn see-through.
		"cut": {"on": _world.is_cut(), "axis": _shell.see_inside.axis,
			"at": _shell.see_inside.at} if _shell != null else {},
		"xray": _world.xray_ids().size(),
		# What the status bar says just now (it clears after a few seconds).
		"said": _shell.status.message.text if _shell != null else "",
		# And what the app is busy with, if anything (Working): its words,
		# how far along, and how long it has been going.
		"working": Working.page_state(),
	}), true)
	# And a model shared by link: the owner's panel, what the viewer is
	# showing, how far along its timeline, and whether this run can write
	# anything at all (tools/web/share_flow.mjs).
	JavaScriptBridge.eval("window.brickworksShare = %s" % JSON.stringify({
		"viewing": _viewing,
		"copying": _copying,
		"read_only": _store.read_only,
		"keeps": _store.keeps,
		"panel": _share_panel.page_state() if _share_panel != null else {},
		"view": _share_view.page_state() if _share_view != null else {},
		"steps": [_steps.timeline_at().x, _steps.timeline_at().y] if _steps.is_playing_back() else [],
		"build": build_state(),
		"parts_open": _inventory.is_showing(),
		"title": _store.title,
	}), true)
	# And who is signed in, and whether the sign-in screen is up, so a
	# browser test can wait for the way in rather than guess it.
	if _account != null:
		JavaScriptBridge.eval("window.brickworksAccount = %s" % JSON.stringify({
			"state": ["checking", "signed_out", "signed_in", "unreachable",
				"not_needed"][_account.state],
			"email": _account.email,
			"offline": _account.offline,
			"gated": _gated(),
		}), true)
	# And where Claude stands: listening here, which of its apps are
	# connected to the account, and the panel's line about it — what a
	# person reads, which a test cannot read off the canvas.
	if _connector != null:
		var clients: Array = []
		for one: Variant in _connector.connections:
			clients.append(str((one as Dictionary).get("client", "")))
		JavaScriptBridge.eval("window.brickworksClaude = %s" % JSON.stringify({
			"on": _connector.is_on(),
			"connected": clients,
			"status": _chat.connector_status(),
		}), true)
	_told_page_us = Time.get_ticks_usec() - telling
	_told_page_most_us = maxi(_told_page_most_us, _told_page_us)


## The model's part of the window and every panel's, in CSS pixels, and
## the points over the model a click would not reach it at.
## tools/web/fit_check.mjs samples the model's rectangle by this and fails
## on anything over it but the view cube.
func _layout_for_page(to_window: Transform2D, per_css: float) -> Dictionary:
	var css := func(rect: Rect2) -> Array:
		var on_page: Rect2 = to_window * rect
		return [roundi(on_page.position.x / per_css), roundi(on_page.position.y / per_css),
			roundi(on_page.size.x / per_css), roundi(on_page.size.y / per_css)]
	var cover: Dictionary = model_cover()
	var covered: Array = []
	for one: Dictionary in cover["covered"]:
		var at: Vector2 = to_window * (one["at"] as Vector2) / per_css
		covered.append({"x": roundi(at.x), "y": roundi(at.y), "by": one["by"]})
	var panels: Dictionary = {}
	var named: Dictionary = _panels_by_name()
	for name: String in named:
		var panel: Control = named[name]
		if panel != null and panel.is_visible_in_tree():
			panels[name] = css.call(panel.get_global_rect())
	# Where the middle of the model is drawn, and parts a click should
	# find: tools/web/centre_check.mjs checks the first is the middle of
	# the view and clicks the others.
	var point := func(at: Vector2) -> Dictionary:
		var on_page: Vector2 = to_window * at / per_css
		return {"x": snappedf(on_page.x, 0.1), "y": snappedf(on_page.y, 0.1)}
	var targets: Array = []
	for one: Dictionary in _parts_to_click():
		targets.append((point.call(one["at"]) as Dictionary).merged({"brick": one["brick"],
			"part": _world.get_brick(int(one["brick"])).part_id}))
	return {"view": css.call(cover["view"]), "samples": cover["samples"],
		"covered": covered, "panels": panels, "columns": _columns,
		"centre": point.call(_camera.unproject_position(_built_bounds().get_center())),
		"targets": targets}


## Up to five parts and a point on each a click would find them at, spread
## over the model, chosen without asking the screen: a point on a part's
## top that a straight line from the eye meets before anything else, and
## where that point is drawn. Only the clicking goes through the screen.
## For tools/web/centre_check.mjs, through the page.
func _parts_to_click(most: int = 5) -> Array:
	var bricks: Array = _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id) and not b.hidden)
	var every: int = maxi(1, bricks.size() / 200)
	var view: Rect2 = _over_model.get_global_rect().grow(-8.0)
	var forward: Vector3 = -_camera.global_transform.basis.z
	var found: Array = []
	for n: int in range(0, bricks.size(), every):
		var brick: BrickWorld.Brick = bricks[n]
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = (brick.transform * part.bounds).abs()
		var top := Vector3(box.get_center().x, box.end.y - 4.0, box.get_center().z)
		var eye: Vector3 = top - forward * 100000.0 if _camera.is_square_on() \
			else _camera.global_position
		var hit: BrickLattice.Hit = _builder.lattice.raycast(eye, (top - eye).normalized())
		if not hit.is_valid() or hit.brick_id != brick.id \
				or absf(hit.distance - eye.distance_to(top)) > 6.0:
			continue
		var at: Vector2 = _camera.unproject_position(top)
		if view.has_point(at) and not _over_panel_at(at):
			found.append({"brick": brick.id, "at": at})
	# Spread out: the one nearest the middle, then each next the farthest
	# from those already taken.
	var middle: Vector2 = view.get_center()
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["at"] as Vector2).distance_to(middle) < (b["at"] as Vector2).distance_to(middle))
	var chosen: Array = []
	while chosen.size() < most and not found.is_empty():
		var best: int = 0
		var far: float = -1.0
		for n: int in found.size():
			if chosen.is_empty():
				break
			var nearest: float = INF
			for taken: Dictionary in chosen:
				nearest = minf(nearest, (found[n]["at"] as Vector2).distance_to(taken["at"]))
			if nearest > far:
				far = nearest
				best = n
		chosen.append(found[best])
		found.remove_at(best)
	return chosen


## Everything laid out round the model, by name.
func _panels_by_name() -> Dictionary:
	var out: Dictionary = {"parts": _bin_dock, "right_column": _chat_dock, "assistant": _chat,
		"menus": _bar, "notices": _notices, "steps": _steps, "keys": _hint, "cube": _gizmo,
		"touch_tools": _tools}
	if _shell != null:
		out.merge({"toolbar": _shell.toolbar, "status": _shell.status,
			"model_tree": _shell.outliner, "properties": _shell.inspector})
	return out


## The model's part of the window, sampled: the points of a grid over it
## that a click would not reach the model at, and what it would reach
## instead. The view cube is the one thing kept over the model, so the
## points under it are not asked about. Read by tools/web/fit_check.mjs
## through the page, and by probes directly.
func model_cover(across: int = 12, down: int = 8) -> Dictionary:
	var view: Control = _marquee.get_parent()
	var rect: Rect2 = view.get_global_rect()
	var covered: Array = []
	# Where the interface is drawn, found once: every canvas layer, the
	# topmost first, and any control drawn straight onto the window.
	var canvases: Array[Node] = []
	_canvas_roots(get_tree().root, canvases)
	canvases.sort_custom(func(a: Node, b: Node) -> bool: return _layer_of(a) > _layer_of(b))
	for i: int in across:
		for j: int in down:
			var at: Vector2 = rect.position + Vector2((i + 0.5) / across * rect.size.x,
				(j + 0.5) / down * rect.size.y)
			if _gizmo != null and _gizmo.is_visible_in_tree() and _gizmo.get_global_rect().has_point(at):
				continue
			var by: String = _covering(at, canvases)
			if not by.is_empty():
				covered.append({"at": at, "by": by})
	return {"view": rect, "samples": across * down, "covered": covered}


## The canvas layers and the controls drawn straight onto the window, under
## ``node``: not inside another viewport, which finds its own.
func _canvas_roots(node: Node, into: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child is Viewport:
			continue
		if child is CanvasLayer or child is Control:
			into.append(child)
		elif not child is CanvasItem:
			_canvas_roots(child, into)


static func _layer_of(node: Node) -> int:
	return (node as CanvasLayer).layer if node is CanvasLayer else 0


## What is at a point over the model instead of the model, by name, or
## nothing. Both ways a click is kept from the model are asked: the list
## the app keeps of its panels, and any control there that takes the
## mouse, so a panel added later and laid over the model is found too.
func _covering(at: Vector2, canvases: Array[Node]) -> String:
	var control: Control = null
	for canvas: Node in canvases:
		if canvas is CanvasLayer and not (canvas as CanvasLayer).visible:
			continue
		var found: Control = _control_at(canvas, at) if canvas is CanvasLayer \
			else _control_in(canvas, at)
		# The drag sheet is under the pointer during a drag, over everything,
		# and is not a panel: what is under it is asked about instead.
		if found != null and not (_cursors != null and _cursors.is_shield(found)):
			control = found
			break
	var cube: bool = control != null and _gizmo != null \
		and (control == _gizmo or _gizmo.is_ancestor_of(control))
	if control != null and not cube:
		return _name_of(control)
	if _over_panel_at(at):
		var named: Dictionary = _panels_by_name()
		for name: String in named:
			var panel: Control = named[name]
			if panel != null and panel.is_visible_in_tree() and panel.get_global_rect().has_point(at):
				return name
		return "a panel"
	return ""


## The topmost shown control at a point that takes the mouse there, found
## the way the window finds one: last drawn first, inside whatever clips.
func _control_at(node: Node, at: Vector2) -> Control:
	for n: int in range(node.get_child_count() - 1, -1, -1):
		var found: Control = _control_in(node.get_child(n), at)
		if found != null:
			return found
	return null


## The topmost control at a point within ``node`` and its children that
## takes the mouse there, or null.
func _control_in(node: Node, at: Vector2) -> Control:
	# Windows and viewports find their own.
	if node is Viewport:
		return null
	if node is CanvasItem and not (node as CanvasItem).visible:
		return null
	var control := node as Control
	if control != null and control.clip_contents and not control.get_global_rect().has_point(at):
		return null
	var inner: Control = _control_at(node, at)
	if inner != null:
		return inner
	if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and control.get_global_rect().has_point(at):
		return control
	return null


## A control by the panel it belongs to: its nearest scripted ancestor's
## class, and its own.
static func _name_of(control: Control) -> String:
	var node: Node = control
	while node != null:
		var script: Script = node.get_script()
		if script != null and not script.get_global_name().is_empty():
			var found: String = script.get_global_name()
			return found if node == control else "%s (%s)" % [found, control.get_class()]
		node = node.get_parent()
	return control.get_class()


## The model's name where a window shows one: the browser tab, or the
## title bar. "Untitled" on a model saved as something else was the
## owner's complaint; the tab says the same name the bar does.
var _page_title: String = ""


func _show_name(name: String) -> void:
	var text: String = "%s — Brickworks" % name
	if OS.has_feature("web"):
		# Kept and put back by _tell_page as well: the engine titles the
		# page itself as it starts, after the model it restored had been
		# named, and the tab said "Brickworks" over a model called Flow Tower.
		_page_title = text
		JavaScriptBridge.eval("document.title = %s" % JSON.stringify(text), true)
	else:
		# With the version, as the title said before it had a name to say.
		get_window().title = "%s %s" % [text, BuildInfo.version()]


func _enable_antialiasing() -> void:
	var method: String = RenderingServer.get_current_rendering_method()
	if method == "forward_plus" or method == "mobile":
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


func _ready() -> void:
	# What this build is, said before the catalogue costs fifteen seconds:
	# how a person reporting a bug, and the release smoke test, ask a
	# downloaded build which one it is.
	if _has_argument("--about"):
		print(BuildInfo.describe())
		# quit() ends the run after this frame, not now, and _process
		# would steer a camera through a UI that was never built.
		set_process(false)
		get_tree().quit()
		return
	if not OS.has_feature("web"):
		get_window().title = "Brickworks %s" % BuildInfo.version()
	IdleDraw.for_the_app()
	# Before anything draws: the controls strip reads these to say what
	# the middle button does, and a strip built from the defaults and
	# never rebuilt would be wrong for everyone who has changed them.
	ViewPrefs.load_them()
	_light_for_this_renderer()
	_enable_antialiasing()
	_match_screen_density()
	_library = PartLibrary.new()
	var started: int = Time.get_ticks_msec()
	if not _library.load_catalogue():
		_title.text = "No catalogue"
		_status.text = "Run tools/build_meshes.py to generate assets/generated/."
		# Nothing below was built, so there is nothing for _process to
		# steer: it called into a playback bar that does not exist.
		set_process(false)
		return
	_catalogue_ms = Time.get_ticks_msec() - started
	# Parts made here before, built again from their LDraw files, so they
	# are in the bin and so a model that uses them reopens.
	CustomParts.load_all(_library)

	_world.library = _library
	_world.rebuilt.connect(_on_rebuilt)
	_builder.world = _world
	_builder.library = _library
	# A link's id from the page's address, checked here at the edge: a
	# shared model to look at, or one to copy.
	if _viewing.is_empty() and SharedModels.is_id(_argument("--view")):
		_viewing = _argument("--view")
	if _copying.is_empty() and SharedModels.is_id(_argument("--copy")):
		_copying = _argument("--copy")
	if not _viewing.is_empty():
		# Before anything reads or writes the visitor's own layout, or a
		# part the model carries is kept for next time.
		ShellPrefs.frozen = true
		CustomParts.keeps = false
	_build_ui()

	if not _viewing.is_empty():
		_enter_view()
		_lay_baseplate()
		await get_tree().process_frame
		_camera.frame(_built_bounds())
		_unthrottle_if_nobody_is_watching()
		# Nothing below is for a viewer: no autosave to restore, no port,
		# no design, nothing written out.
		await _view_shared()
		return

	var stress: String = _argument("--stress")
	var wanted: String = _argument("--model")
	var placed: int = 0
	if not stress.is_empty():
		placed = _build_stress(stress.to_int())
	elif not wanted.is_empty():
		placed = _open(wanted)
		if placed == 0:
			push_error("could not open %s" % wanted)
	else:
		# Whatever was on screen last time comes back first; the sample
		# model is only for a first visit. Not for a probe, which starts
		# where a first visit does: it restored this machine's autosave,
		# so a probe saw whatever the last test or agent had left — a
		# minifigure once, and X lifted the whole figure where the probe
		# meant to lift a brick.
		if not OS.get_cmdline_args().has("--script"):
			placed = _store.restore()
		if placed == 0:
			placed = _open(SAMPLE_MODEL)
			_sample_untouched = placed > 0
		if placed == 0:
			placed = _build_demo()
	_lay_baseplate()


	# Wait a frame so the deferred batch rebuild has run and the bounds are
	# real before framing them.
	await get_tree().process_frame
	_camera.frame(_built_bounds())
	# The model that came back may be one saved before parts were seated
	# by their footprint.
	if _seat_offer != null:
		_seat_offer.check()
	# Open in Brickworks, from a shared model's viewer: once whatever was
	# here is back, and once somebody is signed in (_on_account_changed).
	_first_open_done = true
	_maybe_copy()

	_unthrottle_if_nobody_is_watching()

	var mcp: String = _argument("--mcp")
	# Present with no value is the common case: --mcp, not --mcp=8787.
	if not mcp.is_empty() or _has_argument("--mcp"):
		_open_commands(CommandSocket.PORT if mcp.is_empty() else mcp.to_int())

	var autobuild: String = _argument("--autobuild")
	if not autobuild.is_empty():
		_autobuild(autobuild.to_int())

	# Keep the model on disk as it is built, not only at the end.
	#
	# Measured the hard way: a ninety-minute Voyager run reached 371
	# bricks, lost its connection twice to a TLS fault, and was still
	# retrying when the clock ran out — so the file was never written
	# and an hour and a half of design went in the bin. Nothing about
	# that was the design's fault, and nothing about it needed to cost
	# anything: the model stands on the baseplate the whole time.
	_keep_as_it_builds(_argument("--out"))

	# The same brief, designed by the Claude Code on this machine rather
	# than by the loop inside the app. No API key: it is the person's own
	# subscription doing the thinking.
	var local: String = _argument("--ask-claude-code")
	if not local.is_empty():
		await _ask_claude_code(local)

	var ask: String = _argument("--ask")
	if not ask.is_empty():
		# For this run, not for the person's settings.
		Brain.use_model(_argument("--model"))
		Brain.use_effort(_argument("--effort"))
		await _ask(ask)

	if not _argument("--showcase").is_empty():
		_showcase()

	var bench: String = _argument("--bench")
	if not bench.is_empty():
		await _benchmark(bench.to_int())

	# Whatever ended up on the baseplate, written out and done.
	#
	# --ask runs the assistant the application itself uses: the one that
	# can turn a part on its side, look at what it built and revise it.
	# Until now it could only print, so anything wanting a file went
	# through the second designer in brain/, which has no notion of a
	# face at all — its rot is quarter turns about the vertical axis and
	# nothing else. A sail, a tiled wall, lettering, a grille: all of it
	# is out of reach there, and a brief asking for one comes back as a
	# stack of bricks with no way to tell why.
	var out: String = _argument("--out")
	if not out.is_empty():
		var written: int = _world.brick_count() - _store.scenery.size()
		if not _store.export_to(out, "Model"):
			get_tree().quit(1)
			return
		print("wrote %s (%d parts)" % [out, written])
		# The file is written either way — a design that failed at the
		# last revision still leaves the last version that held
		# together, and throwing it away would be the worse answer. The
		# status is how a script finds out.
		get_tree().quit(0 if _ask_went_well else 1)
		return

	var shot: String = _argument("--shot")
	if not shot.is_empty():
		await _capture(shot)

	# The booklet for whatever --model opened, then quit: how a booklet is
	# checked without a person pressing the button, and how one is made
	# for the site.
	var booklet: String = _argument("--booklet")
	if not booklet.is_empty():
		var said: String = await _export_booklet(booklet)
		print("booklet %s" % said)
		get_tree().quit(0 if said.begins_with("wrote") else 1)


## Write the baseplate out every time something is stood up on it.
##
## Only when a file was asked for, and only in a run that is being
## driven: an interactive session saves itself already, and writing
## somebody's working file on every brick would be a surprise.
##
## The last write wins, which is what is wanted — each one is the whole
## model as it then stood, and a model that got better has a better
## file. A run that is killed, times out, or gives up still leaves the
## best thing it had.
func _keep_as_it_builds(keeping_to: String) -> void:
	if keeping_to.is_empty() or _assistant == null:
		return
	_assistant.built.connect(func(_count: int) -> void:
		if not _store.export_to(keeping_to, "Model"):
			# Said once and not once a brick: a path that cannot be
			# written will not start working later in the run.
			push_warning("could not keep the model at %s" % keeping_to)
			return
		print("  kept %d parts at %s" % [
			_world.brick_count() - _store.scenery.size(), keeping_to]))


## A few parts, close up, for judging how they look rather than whether
## they are in the right place.
func _showcase() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	var wanted: String = _argument("--showcase")
	var row: Array = [
		["3001", 4], ["3003", 14], ["3024", 15], ["3062b", 1],
		["3040b", 2], ["3941", 25], ["4073", 47], ["3005", 0],
	]
	if wanted != "1" and not wanted.is_empty():
		row = [[wanted, 4]]
	var x: float = 0.0
	for entry: Array in row:
		var at := Transform3D(Basis.IDENTITY, Vector3(x, 24.0, 0.0))
		var id: int = _world.add_brick(entry[0], entry[1], at)
		if id != 0:
			_builder.register(id, entry[0], at)
		x += 60.0
	await get_tree().process_frame
	_camera.frame(_built_bounds(), 1.05)
	_camera.set_view("default")


## Run one design through the assistant and report, for checking the
## whole loop without a person having to type into the panel.
func _ask(brief: String) -> void:
	# Start from a bare baseplate, so what appears is what was asked for
	# and not a sample model with something new beside it.
	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_lay_baseplate()

	var started: int = Time.get_ticks_msec()
	_assistant.progress.connect(func(note: String) -> void:
		print("  [%5.1fs] %s" % [(Time.get_ticks_msec() - started) / 1000.0, note]))
	_assistant.said.connect(func(text: String) -> void:
		print("  said: %s" % text.substr(0, 300)))
	# What it cost, because a run from here is a measurement somebody
	# paid for and the bill was being counted and never printed.
	_assistant.spent.connect(func(model_id: String, tokens: Brain.Spend) -> void:
		print("spent %s on %s: %s fresh, %s cached, %s written, %s made" % [
			Brain.in_money(Brain.cost(model_id, tokens)), model_id,
			Brain.in_tokens(tokens.fresh), Brain.in_tokens(tokens.cached),
			Brain.in_tokens(tokens.written), Brain.in_tokens(tokens.made)]))

	_assistant.design(brief)
	var outcome: Array = await _assistant.finished
	_ask_went_well = bool(outcome[0])
	print("ask ok=%s bricks=%d  %s  (%.0fs)" % [
		outcome[0], _assistant._placed_ids.size(), outcome[1],
		(Time.get_ticks_msec() - started) / 1000.0])
	_camera.frame(_built_bounds())
	await get_tree().process_frame


## Drive a local Claude Code session and print what it does.
##
## With --ask-about=x0,x1,y0,y1,z0,z1 (studs and plates, as view_model's
## where) the brief is about the parts of the open model (--model) inside
## that box, as Ask Claude about this… asks: they are selected, and the
## session changes them and nothing else.
func _ask_claude_code(brief: String) -> void:
	var about: String = _argument("--ask-about")
	if about.is_empty():
		_world.clear()
		_builder.lattice.clear()
		_builder.forget_history()
		_lay_baseplate()
	else:
		var picked: int = _select_inside(about)
		if picked == 0 or not _assistant.focus_on(_builder.selection.keys(), true).is_empty():
			print("claude code: nothing to ask about inside %s" % about)
			_ask_went_well = false
			return
		print("asking about %d parts inside %s, room %s" % [picked, about,
			Assistant._box_words(_assistant.focus.region)])
		brief = Assistant.selection_brief(brief, picked)
	# Three massings first, the session choosing among them (Sketch first).
	if about.is_empty() and _has_argument("--sketch-first"):
		brief = Assistant.sketch_brief(brief)
	if not design_with_claude_code(brief):
		print("claude code: could not start")
		_ask_went_well = false
		return
	var started: int = Time.get_ticks_msec()
	var session: ClaudeCode = claude_code()
	session.progress.connect(func(note: String) -> void:
		print("  [%5.1fs] %s" % [
			(Time.get_ticks_msec() - started) / 1000.0, note]))
	session.said.connect(func(text: String) -> void:
		print("  said: %s" % text.substr(0, 300)))
	# What the app made of each call too: a change kept to the room or
	# refused and why, a feature worked and with what. The session's own
	# lines name only the tool.
	_assistant.progress.connect(func(note: String) -> void:
		print("  [%5.1fs]   app: %s" % [(Time.get_ticks_msec() - started) / 1000.0,
			note.replace("\n", "\n             ")]))
	_watch_sketches(session, started)
	if not about.is_empty():
		_assistant.focus_edited.connect(func(words: String, _b: Image, _a: Image) -> void:
			print("  [%5.1fs]   changed the selection: %s (history %d)" % [
				(Time.get_ticks_msec() - started) / 1000.0, words, _builder.history_depth()]))
	var outcome: Array = await session.finished
	_ask_went_well = bool(outcome[0])
	print("claude code ok=%s bricks=%d  (%.0fs)\n  %s" % [
		outcome[0], _world.brick_count() - _store.scenery.size(),
		(Time.get_ticks_msec() - started) / 1000.0,
		str(outcome[1]).substr(0, 600)])
	print("  the session spent %s over %d replies" % [_tokens_said(session.spent()),
		session.replies()])
	_camera.frame(_built_bounds())
	await get_tree().process_frame


## Sketch first, from the command line: each sketch said, its picture kept
## beside --out as NAME_sketchN.png, and when one is chosen how long the
## sketches took and what they spent, against the design after them.
func _watch_sketches(session: ClaudeCode, started: int) -> void:
	var out: String = _argument("--out")
	_assistant.sketches_ready.connect(func(sketches: Array, _model: String,
			_tokens: Brain.Spend, _ours: bool) -> void:
		for one: Sketches.Sketch in sketches:
			var kept: String = ""
			if one.picture != null and not out.is_empty():
				var path: String = "%s_sketch%d.png" % [out.get_basename(), one.number]
				if one.picture.save_png(path) == OK:
					kept = ", pictured at " + path
			print("  [%5.1fs]   sketch %d, \"%s\": %d parts, %s, %s%s" % [
				(Time.get_ticks_msec() - started) / 1000.0, one.number, one.name, one.parts,
				one.measures(), "holds" if one.holds() else "does not hold", kept]))
	_assistant.sketch_chosen.connect(func(number: int) -> void:
		var so_far: Brain.Spend = session.spent()
		print("  [%5.1fs]   chose sketch %d; the sketches took %.0fs, %d replies, %s in (%s of it cached)" % [
			(Time.get_ticks_msec() - started) / 1000.0, number,
			(Time.get_ticks_msec() - started) / 1000.0, session.replies(),
			Brain.in_tokens(so_far.total_in()), Brain.in_tokens(so_far.cached)]))


static func _tokens_said(tokens: Brain.Spend) -> String:
	return "%s in (%s of it cached), %s out" % [Brain.in_tokens(tokens.total_in()),
		Brain.in_tokens(tokens.cached), Brain.in_tokens(tokens.made)]


## Run at full speed when the window is a formality.
##
## A window nothing is looking at gets one frame a second on this
## machine — measured, 989 ms a frame — because that is how long the
## compositor takes to accept one. For somebody using the app that is
## correct and invisible: their window is in front of them at sixty.
## For a run driven from the command line it is a disaster, because
## everything the app does between calls is measured in frames. The
## command socket polls in _process, so a tool call waits up to a second
## each way; a picture is six frames, so it took six seconds at every
## model size; and a design makes hundreds of calls. A real Voyager run
## spent its last ten minutes reporting "the renderer keeps timing out".
##
## So: if the app was started to be driven rather than used, vsync comes
## off for the whole run. Nothing else changes, and an interactive
## window is left exactly as it was — a CAD program spinning at four
## hundred frames a second is a laptop fan and nothing else.
func _unthrottle_if_nobody_is_watching() -> void:
	# A page has no command line to be driven from, and a DisplayServer
	# call the web platform does not implement is an engine error, which
	# this project treats as a failed deploy.
	if OS.has_feature("web"):
		return
	if not _given_any(["--mcp", "--ask", "--ask-claude-code", "--bench",
			"--shot", "--booklet", "--autobuild", "--showcase", "--out"]):
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_driven = true
	print("driven from the command line, so vsync is off for this run")


func _given_any(flags: Array[String]) -> bool:
	for flag: String in flags:
		if _has_argument(flag) or not _argument(flag).is_empty():
			return true
	return false


## Measure a settled frame rate and print it, then quit.
func _benchmark(frames: int) -> void:
	# Without this the number is the monitor's refresh rate, not the
	# renderer's: a 120 Hz panel reports 120 fps however little work it is.
	# And every frame drawn, or it measures frames that drew nothing.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	IdleDraw.end()

	# Discard the first second: shader compilation, the shadow atlas and
	# the camera easing all land in it and none of them recur.
	for _warm: int in 60:
		await get_tree().process_frame

	var started: int = Time.get_ticks_usec()
	for _n: int in frames:
		await get_tree().process_frame
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1_000_000.0

	# The engine's own counters, so the claim can be checked rather than
	# inferred from a frame time that might be capped by something else.
	var draw_calls: int = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(
		Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var video_mb: float = Performance.get_monitor(
		Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

	print("bench bricks=%d batches=%d  %.2f ms/frame  %.0f fps  draws=%d  prims=%d  vram=%.0fMB" % [
		_world.brick_count(), _world.get_child_count(),
		elapsed / float(frames) * 1000.0, float(frames) / elapsed,
		draw_calls, primitives, video_mb])
	get_tree().quit()


## Save a frame and quit. Used by tools/shot.sh so a change to how parts
## look can be checked without a person having to look at it.
func _capture(path: String) -> void:
	# Several frames, not one: the camera eases towards its framing and the
	# shadow atlas fills over a few frames, so the first frame is neither
	# framed nor lit the way a real one is.
	#
	# The frames are forced, not awaited. A process frame is not a drawn
	# frame: when the window is in the background — which it is whenever
	# this runs unattended — the OS stops asking for redraws entirely, so
	# awaiting frame_post_draw waits forever and the captured texture is
	# whatever was last drawn.
	#
	# That cost most of an afternoon. Bricks added after a long wait were
	# absent from every screenshot while the scene tree, the batches, the
	# instance transforms and the instance colours all insisted they were
	# there. They were. The picture was old.
	# Anything that has to come off the network before the picture is
	# worth taking — where the parts are served from, for one — needs
	# longer than a dozen frames. --settle buys that time in frames
	# rather than in a sleep, so the scene keeps drawing while it waits.
	var settle: float = maxf(_argument("--settle").to_float(), 0.0)
	for _n: int in 12 + int(settle * 60.0):
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png(path)
	if error != OK:
		push_error("shot: could not write %s (%d)" % [path, error])
	else:
		print("shot %s  %dx%d" % [path, image.get_width(), image.get_height()])
	get_tree().quit(0 if error == OK else 1)


## The scene's lights are set for Forward+; the web build's renderer
## needs them weaker to show the same colours (BrickWorld.light_energy).
func _light_for_this_renderer() -> void:
	for light_name: String in ["Sun", "Fill", "Rim"]:
		var light: DirectionalLight3D = get_node(light_name)
		light.light_energy = BrickWorld.light_energy(light.light_energy,
			light.shadow_enabled)
		light.light_specular = BrickWorld.light_specular(light.light_specular)
	var environment: Environment = ($WorldEnvironment as WorldEnvironment).environment
	environment.ambient_light_energy = BrickWorld.light_energy(
		environment.ambient_light_energy)


static func _argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="):
			return argument.substr(prefix.length() + 1)
	return ""


## A switch with no value, which _argument cannot report: it returns the
## empty string both for --mcp and for no --mcp at all.
static func _has_argument(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)


## Design on the person's Claude subscription instead of ours.
##
## Opens the port if it is not already open, so this works from a plain
## double-click and not only from a command line that remembered --mcp.
## Returns false, having said why, when it cannot start.
func design_with_claude_code(brief: String) -> bool:
	if ClaudeCode.found().is_empty():
		push_warning("claude code: not installed on this machine")
		return false
	if _commands == null:
		_open_commands(CommandSocket.PORT)
	if _commands == null:
		push_warning("claude code: no port to talk to the app on")
		return false
	if _claude_code == null:
		_claude_code = ClaudeCode.new()
		add_child(_claude_code)
	if _claude_code.busy():
		return false
	_claude_code.design(brief, _commands.port(), _commands.tool_names())
	return true


## The one running, if one is.
func claude_code() -> ClaudeCode:
	return _claude_code


## Select the parts whose middles are inside a box given as
## "x0,x1,y0,y1,z0,z1" in studs and plates. How many.
func _select_inside(box: String) -> int:
	var sides: PackedFloat64Array = box.split_floats(",")
	if sides.size() != 6:
		return 0
	var inside: AABB = Assistant._box_from({"x_from": sides[0], "x_to": sides[1],
		"y_from": sides[2], "y_to": sides[3], "z_from": sides[4], "z_to": sides[5]})
	_builder.selection.clear()
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var at: AABB = SelectionScope.box_of(brick.part_id, brick.transform, _library)
		if at.has_volume() and inside.has_point(at.get_center()):
			_builder.selection[brick.id] = true
	_builder.selection_changed.emit(_builder.selection.size())
	return _builder.selection.size()


## Edit, Ask Claude about this… (and the menu on a part): the assistant's
## panel, its next request about what is selected.
func ask_about_selection() -> void:
	_builder.hide_preview()
	_chat_dock.set_open(true)
	_chat.ask_about(_builder.selection.keys())


## Empty the baseplate, as starting a design does, and begin a new model.
##
## Public for the command socket. A session driving from outside has no
## moment of its own where the board is cleared — asked for a lighthouse
## it would build one into whatever was standing — and the design loop
## clears the board itself, so it never needed this.
##
## Untitled, because what goes down next is something new: it kept the
## name of what was taken off, and Save would have written the lighthouse
## over the model it replaced. The design names it when it stands.
func clear_model() -> void:
	_world.clear()
	_builder.lattice.clear()
	_builder.clear_selection()
	_builder.forget_history()
	_assistant.forget_built()
	_store.model_floor = ModelFloor.preferred()
	_lay_baseplate()
	_sample_untouched = false
	_store.begin(ModelStore.UNTITLED)


## Work is about to go down on the baseplate, and [param name] is what it is.
##
## The example car of a first visit, untouched, comes off first, and the
## model is a new one named after the work: it kept the example's name, so
## the tower built in its place was "Example Car for Demonstration of LDRAW
## Library" and Save saved it as that. A bare baseplate nobody has named is named the
## same way. Anything else is somebody's model, and keeps its name.
func _make_room(name: String) -> void:
	if _sample_untouched:
		clear_model()
		if _chat != null:
			_chat.note("Took the example car off the baseplate to make room.")
	elif _world.brick_count() > _store.scenery.size() or _store.title != ModelStore.UNTITLED:
		return
	_store.begin(name)
	_named_for_work = _store.title


## Write what is on the baseplate to a file. Returns false if it could not.
func save_model(path: String) -> bool:
	return _store.export_to(path, "Model")


## Open the local port that lets a session outside the app drive it.
##
## Off unless asked for, and 127.0.0.1 only. See
## src/net/command_socket.gd for why this exists at all.
func _open_commands(port: int) -> void:
	_commands = CommandSocket.new()
	_commands.assistant = _assistant
	_commands.app = self
	add_child(_commands)
	if not _commands.listen(port):
		_commands.queue_free()
		_commands = null
		return
	# What it does is narrated already: every tool emits the assistant's
	# own progress signal, which the chat panel is bound to, so the
	# window says "looking up \"wedge\"" while an outside session works.
	# Only who is connected needs saying here.
	_commands.attached.connect(func(how_many: int) -> void:
		print("command socket: %d session(s) attached" % how_many))


## Whether a person is in front of this window to sign in, so the sign-in
## screen goes over it. Not in a probe, a headless run, or a command line
## that renders, exports or designs and then quits: those are tools and
## tests driving a checkout, and nobody could answer the screen. Everyone
## who opens the app to use it is asked.
func _gate_wanted() -> bool:
	if gate_for_probe:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	if OS.get_cmdline_args().has("--script"):
		return false
	return not _given_any(["--ask", "--ask-claude-code", "--bench", "--shot",
		"--booklet", "--autobuild", "--showcase", "--out", "--stress", "--about"])


## Whether the sign-in screen is up, so nothing behind it moves.
func _gated() -> bool:
	return _gate != null and _gate.visible


## Somebody signed in, or out. The connector belongs to an account: put
## back as it was once somebody is in, and off when they leave.
func _on_account_changed() -> void:
	if _bar != null:
		_bar.show_account(_account.email if _account.signed_in() else "")
	# A viewer is nobody's session: no connector, ever.
	if _connector == null or not _viewing.is_empty():
		return
	_maybe_copy()
	if _account.signed_in() and not _connector_resumed:
		_connector_resumed = true
		_connector.resume()
	elif not _account.signed_in() and _account.state != Account.State.CHECKING:
		_connector_resumed = false
		if _connector.is_on():
			_connector.stop()
		# Whose connections they were is nobody's business here now.
		_connector.refresh_connections()


## File › Share…: the panel that publishes this model as the signed-in
## account and hands back its link.
func _share_wanted() -> void:
	if _viewing.is_empty() and _share_panel != null:
		_share_panel.open()


## Turn this run into a shared model's viewer (/app?view=<id>).
##
## The builder's bars, panels and tools go out of sight, the viewer's own
## bar takes their place. What keeps it read-only is not what is hidden but
## what refuses: Shell.can runs only the commands in Shell.LOOKING, from a
## menu, a button or a key; the mouse and the keys go to _view_input and
## _looking_key, which only look; the store writes nothing
## (ModelStore.read_only, the autosave and every save); parts the model
## carries are built for this visit only (CustomParts.keeps); the layout
## is neither read nor written (ShellPrefs.frozen); the account is never
## read, renewed or written (Account.keeps), and the connector never starts.
func _enter_view() -> void:
	_shell.read_only = true
	# Somebody else's steps, to step through and not to change.
	_steps.editable = false
	var column: Control = _bar.get_parent()
	# The status bar too: what it holds is the builder's (the tool's hint,
	# the snap, the selection), and the viewer says its own things.
	for hidden: Control in [_bar, _shell.toolbar, _shell.inspector, _shell.outliner,
			_shell.banner, _bin_dock, _chat_dock, _tools, _seat_offer]:
		if hidden != null:
			hidden.visible = false
	# ...but not what the app is busy with (Working): the timeline of a big
	# model takes a while to work out here too.
	_shell.status.only_the_work()
	# The strip of editing keys, and the room kept for it.
	if _hint != null:
		(_hint.get_parent() as Control).visible = false
	_share_view = ShareView.new()
	$HUD.add_child(_share_view)
	_share_view.put_bar_in(column)
	_share_view.steps_wanted.connect(_toggle_steps)
	_share_view.booklet_wanted.connect(_booklet_wanted)
	_share_view.parts_wanted.connect(_toggle_parts)
	_share_view.copy_wanted.connect(_open_copy)
	_share_view.build_wanted.connect(func() -> void: _enter_build())
	# The big Build it of a phone sits above the timeline.
	_share_view.floor_at = func() -> float:
		return _steps.get_global_rect().position.y if _steps.is_visible_in_tree() \
			else _share_view.size.y
	_share_view.loading()
	_build_mode = BuildMode.new()
	_build_mode.thumbnails = _thumbnails
	$HUD.add_child(_build_mode)
	_build_mode.next_wanted.connect(func() -> void: _build_go(_build_page + 1))
	_build_mode.back_wanted.connect(func() -> void: _build_go(_build_page - 1))
	_build_mode.close_wanted.connect(_leave_build)
	_build_outline = SelectionOutline.new()
	_build_outline.world = _world
	_build_outline.library = _library
	_build_outline.width = 3.0
	add_child(_build_outline)
	# A step scrubbed shows and hides parts under a pointer that has not moved.
	_steps.reveal.connect(func(_ids: Dictionary) -> void:
		_hovered_from = Vector2(-1, -1))


## Fetch the shared model and open it, read-only.
func _view_shared() -> void:
	_share_view.loading()
	var answer: Dictionary = await _shared.fetch(_viewing)
	var code: int = int(answer["code"])
	if code == 410 or code == 404:
		var title: String = ("This model is no longer shared" if code == 410
			else "There is no model at this link")
		_share_view.gone(title, ("Whoever shared it has taken it down. If they share "
			+ "it again, this link will work again.") if code == 410
			else "The link may be mistyped, or cut short.")
		_show_name(title)
		_set_address("/m/" + _viewing)
		return
	if code != 200 or not answer["body"] is Dictionary:
		_share_view.failed(SharedModels.trouble(answer,
			"Brickworks did not answer as it should. Try again in a minute."), _view_shared)
		return
	var shared: Dictionary = answer["body"]
	var name: String = str(shared.get("name", "A shared model"))
	var author: String = str(shared["author"]) if shared.get("author") is String else ""
	var result: Dictionary = _store.open_text(str(shared.get("model", "")), name)
	if not str(result["error"]).is_empty():
		_share_view.failed("It could not be opened here: %s." % result["error"], _view_shared)
		return
	_store.title = name
	_store.share_id = ""
	_share_view.show_model(name, author, int(shared.get("parts", 0)), str(shared.get("url", "")),
		shared["remixed_from"] if shared.get("remixed_from") is Dictionary else {})
	_show_name(name)
	_set_address("/m/" + _viewing)
	_lay_baseplate()
	_shell.assemblies.enter("")
	await get_tree().process_frame
	_camera.frame(_built_bounds())
	# On the web most parts are fetched as they are wanted; the steps are
	# worked out from all of them, so they wait for the last.
	var since: int = Time.get_ticks_msec()
	var waited: bool = not _store.awaited.is_empty()
	while not _store.awaited.is_empty() and Time.get_ticks_msec() - since < 120000:
		_share_view.arriving(_store.awaited.size())
		await get_tree().create_timer(0.3).timeout
	if waited and _store.awaited.is_empty():
		# Opened again now every part is here, so the parts stand in the
		# file's order and not the order they happened to arrive in. The
		# steps break ties by that order: worked out from an arrival order,
		# a reload could make step 12 a different step 12, and someone
		# coming back to the page they left would be on another one.
		_store.open_text(str(shared.get("model", "")), name)
		_store.title = name
		_store.share_id = ""
	_lay_baseplate()
	await get_tree().process_frame
	_camera.frame(_built_bounds())
	_share_view.ready_to_look()
	# The finished model, on a timeline to drag back through.
	if await _steps.start(_world, _library, _store.scenery):
		_steps.to_end()
	# Back where this device left it: a phone that slept mid-build opens on
	# the page it was on.
	_build_pages = null
	var kept: Dictionary = BuildSteps.recall(_viewing)
	if bool(kept.get("building", false)):
		_enter_build(int(kept["page"]))


## Open in Brickworks, from the viewer: the app as everybody else gets
## it, which signs the visitor in and then copies the model (_maybe_copy).
func _open_copy() -> void:
	var address: String = "/app?copy=" + _viewing
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.assign(%s)" % JSON.stringify(address), true)
	else:
		OS.shell_open(Deployment.api_base() + address)


## Build it: the viewer as a step player, full screen, at [param page] —
## where this device left the link when none is given (BuildSteps.recall).
func _enter_build(page: int = -1) -> void:
	if _share_view == null or _share_view.state != "ready" or _build_mode.is_open():
		return
	if _inventory.is_showing():
		_inventory.hide_list()
	var made: Array[Instructions.Step] = _steps.steps()
	# start() works the steps out a slice at a time with the progress bar,
	# so it has to be waited for.
	if made.is_empty() and not await _steps.start(_world, _library, _store.scenery):
		return
	made = _steps.steps()
	_build_left = {"timeline": _steps.is_playing_back(), "cube": _gizmo.visible}
	# Put out of sight, not stopped: stopping forgets nothing, but starting
	# it again afterwards works the steps out again, and on a castle that
	# is seconds of a phone's time for the press of Close.
	if _steps.is_playing_back():
		_steps.to_end()
		_steps.visible = false
	if _build_pages == null:
		_build_pages = BuildSteps.of(_world, _library, made, _store.scenery)
	_share_view.show_bar(false)
	_share_view.hover("", Vector2.ZERO)
	_hovered = 0
	_hover_outline.show_selection({})
	_gizmo.visible = false
	_build_mode.open()
	_camera.seen = _build_mode.free_rect
	if page < 0:
		page = int(BuildSteps.recall(_viewing).get("page", 0))
	# A frame for the bars to be laid out, so the view is framed between them.
	await get_tree().process_frame
	_build_go(page)


## Put [param page] on screen: what is built by then, the rest out of
## sight; what was built before it faded; its new parts outlined; its
## parts along the bottom; the view the booklet would draw it from. And
## kept as where this device is on the link.
func _build_go(page: int) -> void:
	if _build_pages == null or not _build_mode.is_open():
		return
	if page > _build_pages.last():
		# Finish, on the last page: the whole model, as it is now built.
		_leave_build()
		return
	var started: int = Time.get_ticks_usec()
	var took: Dictionary = {}
	var lap: int = started
	page = _build_pages.clamped(page)
	_build_page = page
	# Faded first: it only marks the batches, and showing them writes each
	# once, faded and shown together, rather than once each.
	_world.set_faded(_build_pages.faded(page))
	_world.show_only(_build_pages.shown(page))
	lap = _lap(took, "world", lap)
	_build_outline.show_selection(_build_pages.fresh(page))
	lap = _lap(took, "outline", lap)
	var view: Dictionary = _build_pages.view(page)
	_camera.look_from(view["from"])
	# The ball round a flat box is roomy already: a step on a baseplate
	# framed at the usual 1.25 sat in the middle third of a phone.
	_camera.frame(view["box"], 1.0)
	lap = _lap(took, "view", lap)
	_build_mode.show_page(page, _build_pages.last(), _build_pages.caption(page),
		_build_pages.note(page), _build_pages.lots(page))
	lap = _lap(took, "page", lap)
	BuildSteps.remember(_viewing, page, true)
	_lap(took, "kept", lap)
	_build_turned_us = Time.get_ticks_usec() - started
	if _build_turned_us > _build_turned_most_us:
		_build_turned_most_us = _build_turned_us
		_build_turned_most = took


## Milliseconds since [param since], under [param name]; now.
static func _lap(took: Dictionary, name: String, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	took[name] = snappedf((now - since) / 1000.0, 0.1)
	return now


## Back to the whole model, as the viewer opened it: the timeline at the
## end, the bar along the top. The page reached is kept, for Build it to
## come back to.
func _leave_build() -> void:
	if _build_mode == null or not _build_mode.is_open():
		return
	_build_mode.close()
	_world.set_faded({})
	_build_outline.show_selection({})
	_camera.seen = _model_rect
	_share_view.show_bar(true)
	_gizmo.visible = bool(_build_left.get("cube", true))
	BuildSteps.remember(_viewing, _build_page, false)
	if bool(_build_left.get("timeline", false)):
		_steps.visible = true
		_steps.to_end()
	else:
		_world.show_only({})
	_camera.look_from(BookletStudio.FRONT)
	_camera.frame(_built_bounds())


## The step player as a check reads it (tools/web/build_flow.mjs,
## share_view_probe): the page and what it says, and what the world draws.
func build_state() -> Dictionary:
	if _build_mode == null:
		return {}
	var said: Dictionary = _build_mode.page_state()
	if not _build_mode.is_open():
		return said
	said["faded"] = _world.faded_ids().size()
	said["fresh"] = _build_pages.fresh(_build_page).size() if _build_pages != null else 0
	said["turn_ms"] = roundi(_build_turned_us / 1000.0)
	said["turn_most_ms"] = roundi(_build_turned_most_us / 1000.0)
	said["turn_most"] = _build_turned_most
	var shown: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not brick.hidden and not _store.scenery.has(brick.id):
			shown += 1
	said["shown"] = shown
	said["from"] = ("back" if _build_pages != null and _build_mode.is_open()
		and _build_pages.view(_build_page)["from"] == BookletStudio.BACK else "front")
	return said


## The page's address, put right without a reload: the link itself while
## its model is being looked at, and the app's own address once a copy is
## made, so a reload does not make another. Empty is this page with no query.
func _set_address(path: String) -> void:
	if not OS.has_feature("web"):
		return
	var to: String = JSON.stringify(path) if not path.is_empty() else "location.pathname"
	JavaScriptBridge.eval("history.replaceState(null, '', %s)" % to, true)


## Copy a shared model into this person's own models (/app?copy=<id>): once
## they are signed in and whatever was on the baseplate is back. That is
## kept first if it was not saved, so following a link never loses work.
## The copy is saved under its own name, never over one of theirs, and has
## no link: it is theirs to change and to share as their own. It does know
## which link it came from (ModelStore.remixed_from), so when they share
## it, its page says what it was remixed from.
func _maybe_copy() -> void:
	if _copying.is_empty() or _copy_started or not _first_open_done \
			or _account == null or not _account.lets_in():
		return
	_copy_started = true
	_bar.say("copying the shared model…")
	var answer: Dictionary = await _shared.fetch(_copying)
	_set_address("")
	if int(answer["code"]) != 200 or not answer["body"] is Dictionary:
		_bar.say("could not copy it: " + SharedModels.trouble(answer, "Brickworks did not answer"))
		return
	var shared: Dictionary = answer["body"]
	var name: String = str(shared.get("name", "Shared model"))
	if not _sample_untouched and _store.has_unsaved_work():
		_store.save_as(_store.unused_name(_store.title if _store.title != ModelStore.UNTITLED
			else "Untitled"))
	var result: Dictionary = _store.open_text(str(shared.get("model", "")), name)
	if not str(result["error"]).is_empty():
		_bar.say("could not open that model: %s" % result["error"])
		return
	_store.share_id = ""
	_store.remixed_from = _copying
	_bar.opened.emit(int(result["placed"]))
	var since: int = Time.get_ticks_msec()
	while not _store.awaited.is_empty() and Time.get_ticks_msec() - since < 120000:
		_bar.say("copying “%s” — %d parts on their way…" % [name, _store.awaited.size()])
		await get_tree().create_timer(0.3).timeout
	if not _store.awaited.is_empty():
		_bar.say("“%s” is open, but %d parts did not arrive: save it once they have" % [
			name, _store.awaited.size()])
		return
	var kept: String = _store.unused_name(name)
	_store.save_as(kept)
	_bar.say("“%s” is in your models now, yours to change — the shared one stays as it was" % kept)


## The mouse in the viewer: a left drag turns the view (Shift slides it),
## and nothing else. The right and middle buttons and the wheel are the
## camera's own (CadCamera), as they are in the builder.
func _view_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	# A finger's click, emulated: the camera turns the view with the finger
	# itself already (CadCamera), and the two together turned it twice.
	if button.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if button.pressed:
		if _over_panel_at(button.position):
			return
		_press_at = button.position
		_start_left_nav("slide" if button.shift_pressed else "turn", button.position)
	elif not _left_nav.is_empty():
		_left_nav = ""
		_camera.end_drag(MOUSE_BUTTON_LEFT)


## The keys a viewer answers to. True for one the builder's own handling
## may go on to — it only looks: fit, the named views, the timeline's keys
## and the arrows, which turn the view with nothing selected. B and P open
## the steps and the parts list here; everything else does nothing.
func _looking_key(key: InputEventKey) -> bool:
	if key.ctrl_pressed or key.meta_pressed:
		return false
	# The step player: pages and closing, and the views; nothing of the
	# timeline's, which is put away while it is up.
	if _build_mode != null and _build_mode.is_open():
		match key.keycode:
			KEY_RIGHT, KEY_SPACE, KEY_PAGEDOWN, KEY_ENTER:
				_build_go(_build_page + 1)
			KEY_LEFT, KEY_PAGEUP, KEY_BACKSPACE:
				_build_go(_build_page - 1)
			KEY_HOME:
				_build_go(0)
			KEY_END:
				_build_go(_build_pages.last() if _build_pages != null else 0)
			KEY_ESCAPE:
				_leave_build()
			KEY_F, KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, \
					KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, \
					KEY_KP_6, KEY_KP_7:
				return true
		return false
	match key.keycode:
		KEY_B:
			_toggle_steps()
			return false
		KEY_P:
			_toggle_parts()
			return false
		KEY_ESCAPE:
			if _inventory.is_showing():
				_inventory.hide_list()
			return false
		KEY_F, KEY_HOME, KEY_END, KEY_SPACE, KEY_LEFT, KEY_RIGHT, \
				KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, \
				KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, \
				KEY_KP_6, KEY_KP_7:
			return true
	return false


## With Select in hand, what a click would take, outlined faintly while the
## pointer is on it, as Studio and Fusion do: what the click will pick, seen
## before it is made. Not over a panel, not while a button is held, and not
## round what is already selected, which has its own line.
func _select_hover() -> void:
	if _hover_outline == null or _verbs == null:
		return
	var under: int = 0
	if _verbs.mode == "select" and not _verbs.shows_ghost() and not _verbs.is_view_tool() \
			and not _dragging_part and Input.get_mouse_button_mask() == 0 \
			and not (_measure != null and _measure.active) and not (_flex != null and _flex.active):
		under = _brick_under_pointer()
	if under == _hovered:
		return
	_hovered = under
	var taken: Dictionary = {}
	if under != 0 and not _builder.selection.has(under):
		for brick_id: int in _builder.takes(under):
			taken[brick_id] = true
	_hover_outline.show_selection(taken)


## What is under a still pointer may have changed: the selection did, or
## the model. Looked at again next frame.
func _look_under_again() -> void:
	if _viewing.is_empty():
		_hovered = -1


## The part under the pointer in the viewer: outlined, and named beside it.
func _view_hover() -> void:
	if _share_view == null or _share_view.state != "ready":
		return
	# Building, every part on show is one to look at, not one to name.
	if _build_mode != null and _build_mode.is_open():
		return
	var at: Vector2 = _view_pointer
	if at == _hovered_from:
		return
	_hovered_from = at
	var under: int = 0
	var over_panel: bool = _over_panel_at(at) or _share_view.covers(at) \
		or (_steps.is_visible_in_tree() and _steps.get_global_rect().has_point(at))
	if not over_panel and Input.get_mouse_button_mask() == 0:
		under = _verbs.brick_at(at)
		var brick: BrickWorld.Brick = _world.get_brick(under) if under != 0 else null
		if brick == null or brick.hidden:
			under = 0
	if under != _hovered:
		_hovered = under
		_hover_outline.show_selection({under: true} if under != 0 else {})
	if under == 0:
		_share_view.hover("", at)
		return
	var shown: BrickWorld.Brick = _world.get_brick(under)
	var info: PartLibrary.PartInfo = _library.parts.get(shown.part_id)
	var colour: PartLibrary.BrickColor = _library.color(shown.color_code)
	_share_view.hover("%s · %s" % [Inventory._tidy(info.name) if info != null else shown.part_id,
		colour.name if colour != null else "colour %d" % shown.color_code], at)


## The panels either side of the viewport: the parts bin on the left, the
## design assistant on the right. Both are built in code rather than in
## the scene because they are data-driven — 24,731 parts and 322 colours
## are not things to lay out by hand.
func _build_ui() -> void:
	# The library has no scene tree of its own, so it borrows this one to
	# park its HTTP requests on.
	_library.set_fetch_host(self)
	_library.fetched.connect(_on_part_fetched)
	_library.fetch_failed.connect(func(part_id: String, why: String) -> void:
		push_warning("could not fetch %s: %s" % [part_id, why])
		# Said out loud when it is the part someone is holding, because
		# otherwise clicking does nothing and nothing explains why.
		if _bar != null and _builder != null and _builder.held_part == part_id:
			_bar.say("could not load %s — %s" % [part_id, why]))

	_store = ModelStore.new()
	# A run driven from the command line is not somebody's session, so it
	# leaves their working model alone. Set before anything opens, or the
	# open's own autosave gets in first. A session over MCP is somebody's:
	# it builds in front of them.
	_store.keeps = not _given_any(["--ask", "--ask-claude-code", "--bench",
		"--shot", "--booklet", "--autobuild", "--showcase", "--out"])
	# Nor a probe: every one that opened the app wrote this machine's own
	# autosave, so the desktop app reopened whatever the last test left.
	# A probe about the autosave turns it on for itself.
	if OS.get_cmdline_args().has("--script"):
		_store.keeps = false
	# Nor somebody else's model, shared by link and opened to look at:
	# nothing about it is written anywhere, Save included.
	if not _viewing.is_empty():
		_store.keeps = false
		_store.read_only = true
	_store.world = _world
	_store.library = _library
	_store.builder = _builder

	# What the model stands on: src/render/floor_layer.gd.
	_floor = FloorLayer.new()
	_floor.name = "Floor"
	_floor.world = _world
	_floor.builder = _builder
	_floor.store = _store
	_floor.library = _library
	_floor.model_bounds = _model_bounds
	add_child(_floor)
	# The ground's shadow is the sun's alone: lit by the fill or the rim,
	# which cast none, it is clear everywhere (FloorLayer.SHADOW_LAYER).
	for light_name: String in ["Fill", "Rim"]:
		var light: DirectionalLight3D = get_node(light_name)
		light.light_cull_mask &= ~FloorLayer.SHADOW_LAYER
	# A plate made part of the model, or the floor again, changes what is
	# counted and weighed without changing a brick: counted again now.
	_floor.changed.connect(func() -> void:
		_stability_revision = -1
		_stability_at = 0
		_on_rebuilt(_world.brick_count(), _drawn[0], _drawn[1]))
	_builder.scenery = _store.scenery
	_builder.floor_hook = _floor.put

	_stability = Stability.new()
	_stability.library = _library
	_stability.lattice = _builder.lattice

	_thumbnails = PartThumbnails.new()
	_thumbnails.library = _library
	add_child(_thumbnails)

	# The geometry this build did not ship may not live beside it, and
	# only the deployment knows where it does. Everything the builder
	# does is already running by the time it answers, and none of it
	# waits on the answer except a part this build does not carry:
	# requests for those are held until it says, and a deployment that
	# serves its own parts would otherwise hold them for ever waiting
	# on a URL that was never going to come.
	_deployment = Deployment.new()
	_deployment.settled.connect(func() -> void:
		if not _deployment.parts_url.is_empty():
			# The real answer, which replaces anything guessed before
			# it arrived. A probe that fails — offline for a moment at
			# startup — used to pin the guess for the rest of the
			# session, and the guess is this deployment, which carries
			# only the parts it shipped with. Every other part then
			# fetched a web page and was reported as broken geometry.
			_library.remote_parts = _deployment.parts_url
		elif _deployment.answered and _library.remote_parts.is_empty():
			# Only once the deployment has actually said so.
			#
			# This fired whenever the probe finished, including when it
			# failed — pinning "next to the app" for the rest of the
			# session. This deployment serves no geometry at all, so
			# every part outside the pack it ships with was then
			# fetched from somewhere that 404s, and the browser console
			# filled up with parts that do exist, at an address that
			# was never going to have them.
			_library.remote_parts = Origin.here() + "/parts/")
	add_child(_deployment)

	# Who is here. It waits on the deployment to learn where to sign in,
	# then renews any session this device kept.
	_account = Account.new()
	_account.deployment = _deployment
	# A probe or a command-line run starts signed out and leaves the
	# person's kept session alone. So does a shared model's viewer: it
	# needs nobody signed in, and a session renewed here and in the
	# visitor's own tab at once would end it.
	_account.keeps = _gate_wanted() and not gate_for_probe and _viewing.is_empty()
	add_child(_account)

	# Models shared by link: publishing this one, and opening somebody's.
	# A probe hands in its own, which answers without a network.
	if _shared == null:
		_shared = SharedModels.new()
	add_child(_shared)

	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	# Every request goes straight to Anthropic on a key of the person's
	# own. One from the environment is a developer running with theirs;
	# one pasted into the panel is handled by the assistant itself, and
	# wins when there are both.
	var key: String = "" if OS.has_feature("web") else _anthropic_key()
	if not key.is_empty():
		_assistant.direct_key = key
	add_child(_assistant)

	# Before the first panel, so every tick box and switch is made with
	# pictures that show on a dark panel; redrawn when the density changes.
	Look.apply(get_viewport())
	get_tree().root.size_changed.connect(func() -> void:
		Look.apply.call_deferred(get_viewport()))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(column)

	_bar = ModelBar.new()
	_bar.world = _world
	_bar.builder = _builder
	column.add_child(_bar)
	_bar.bind(_store)
	# The assistant remembers which bricks were its own by id, and
	# BrickWorld numbers from one again after a clear — so without this
	# those ids name the new model's bricks and the next design deletes
	# them. Same family as the undo bug, through a different door.
	# Forget, not clear. By the time either of these fires the world has
	# already been replaced, and the ids the assistant is holding name
	# bricks of the new model — so clearing removes the first few bricks
	# of whatever was just opened.
	_bar.cleared.connect(func() -> void:
		# Clear keeps a model's name, but an example's is not the person's
		# to keep: what they build next is not the example.
		if _store.example:
			_store.begin(ModelStore.UNTITLED)
		_sample_untouched = false
		_assistant.forget_built()
		_lay_baseplate()
		_on_model_changed())
	_bar.model_named.connect(_show_name)
	_bar.started_new.connect(func() -> void:
		_sample_untouched = false
		_assistant.forget_built()
		if _chat != null:
			_chat.new_chat()
		# A new model stands on what the person chose for new ones.
		_store.model_floor = ModelFloor.preferred()
		_lay_baseplate()
		_on_model_changed()
		_camera.frame(_built_bounds()))
	_bar.opened.connect(func(_bricks: int) -> void:
		_sample_untouched = false
		_assistant.forget_built()
		_lay_baseplate()
		_on_model_changed()
		_camera.frame(_built_bounds()))

	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(layout)

	_bin = PartsBin.new()
	_bin.library = _library
	_bin.thumbnails = _thumbnails
	# The eyedropper changes what is held, so the bin and the palette have
	# to follow — a swatch that still shows red after picking up a blue
	# brick is a swatch that is lying.
	_builder.picked.connect(func(part_id: String, color_code: int) -> void:
		_bin.show_held(part_id, color_code)
		_refresh_preview()
		_bar.say("picked %s" % part_id))

	_bin.part_chosen.connect(_on_part_chosen)
	_bin.color_chosen.connect(_on_color_chosen)
	_bin.swatch_pressed.connect(_on_swatch_pressed)
	# A part dragged out of the bin: in hand from the start of the drag
	# (part_chosen), its ghost after the pointer over the model, and put
	# down where it is let go. Let go over a panel, it stays in hand.
	_bin.part_drag_moved.connect(func(at: Vector2) -> void:
		if _over_panel_at(at):
			_builder.hide_preview()
		else:
			_refresh_preview(at))
	_bin.part_dropped.connect(func(at: Vector2) -> void:
		if _over_panel_at(at):
			return
		_aim_at(at)
		_builder.place()
		_refresh_preview(at))

	# The parts bin at the top of the left-hand column, which takes the
	# model tree and the properties under it (Shell.build).
	_stack = PanelStack.new()
	_stack.add_section(_bin)
	_bin_dock = SideDock.new()
	_bin_dock.title = "Parts"
	_bin_dock.icon = "parts"
	_bin_dock.holds = "the parts bin, the model tree, the properties and the colours"
	_bin_dock.setup(_stack, SideDock.Edge.LEFT, 336.0)
	layout.add_child(_bin_dock)

	# The middle column is the viewport. Nothing is drawn into it, but the
	# counters and the key list live at its top and bottom so they cannot
	# end up underneath a panel.
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_theme_constant_override("separation", 0)
	layout.add_child(middle)

	# Above the model, not over it: what is said about the model for a
	# while. The banner for a sub-assembly being edited and the offer to
	# seat old parts lay over its top middle, where a click meant for a
	# part landed on them. Shown only while something in it is.
	_notices = PanelContainer.new()
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	strip.border_color = Color(1, 1, 1, 0.08)
	strip.border_width_bottom = 1
	strip.content_margin_top = 4
	strip.content_margin_bottom = 4
	_notices.add_theme_stylebox_override("panel", strip)
	_notices.visible = false
	var notes := VBoxContainer.new()
	notes.add_theme_constant_override("separation", 4)
	_notices.add_child(notes)
	notes.child_entered_tree.connect(func(note: Node) -> void:
		(note as Control).visibility_changed.connect(_show_notices))
	middle.add_child(_notices)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(spacer)
	_over_model = spacer
	# The view is centred on this column and framed to it, rather than to
	# the window behind the columns (CadCamera.seen): with one column open
	# the model sat 168 units to the side of the room it had.
	_camera.seen = _model_rect
	_camera.lens_moved.connect(_hover_again)

	# In the viewport column, at the top, which is where every other 3D
	# tool puts a view cube.
	#
	# It was anchored to the bottom right of the whole window, which
	# meant two collisions rather than none: its square lay over the
	# assistant panel and swallowed clicks meant for the buttons
	# underneath, and on a tall screen it sat on top of the key strip.
	# Anchoring it inside this column makes both impossible rather than
	# unlikely. A view cube now, with arrows to turn, slide and zoom the
	# view by clicking (ViewCube): navigating with a left button alone.
	_gizmo = ViewCube.new()
	_gizmo.camera = _camera
	_gizmo.fit = func() -> void:
		_camera.frame(_selection_bounds() if not _builder.selection.is_empty()
			else _built_bounds())
	var cube: Vector2 = ViewCube.size_for()
	_gizmo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gizmo.offset_left = -cube.x - 14.0
	_gizmo.offset_top = 14.0
	_gizmo.offset_right = -14.0
	_gizmo.offset_bottom = cube.y + 14.0
	spacer.add_child(_gizmo)

	# The hint is wide, and a container asks its children how narrow they
	# can get. Left to itself the strip set the middle column's minimum
	# width and squeezed the assistant off the right edge, so it lives in
	# a clipping wrapper that claims no width of its own.
	# Above the key strip, so the strip stays where it always is rather
	# than jumping down the screen when playback starts.
	_steps = StepsBar.new()
	# The end of the timeline shows the model again as it was, which is
	# with whatever was hidden by hand still hidden.
	_steps.reveal.connect(func(ids: Dictionary) -> void:
		# What the timeline has not put on yet is passed through by the
		# pointer, as it is by the eye: a click on the step showing took
		# the invisible part above it, and moving that a step moved the
		# wrong one.
		var ahead: Dictionary = {}
		if not ids.is_empty():
			for brick: BrickWorld.Brick in _world.bricks():
				if not ids.has(brick.id):
					ahead[brick.id] = true
		_builder.lattice.ahead = ahead
		if ids.is_empty() and _verbs != null:
			_verbs.apply_hidden()
		else:
			_world.show_only(ids))
	_steps.export_wanted.connect(_booklet_wanted)
	_steps.edit_wanted.connect(func(op: String) -> void: _shell.edit_steps(op))
	# A part put down while the timeline shows the author's steps goes in
	# the step it is on.
	_builder.place_step = _steps.place_step
	middle.add_child(_steps)

	# Room for two lines. The strip wraps rather than truncating when the
	# window is narrow, and a clipped area would put the wrapped line
	# behind the viewport edge instead of showing it.
	# Tall enough for the rows it actually needs.
	#
	# It was a fixed 48 pixels with clipping on, and twenty bindings
	# wrap to three rows at this app's own default window size — so the
	# strip that exists precisely so the controls cannot go unsaid cut
	# its own last row off.
	var hint_area := Control.new()
	hint_area.custom_minimum_size = Vector2(0, 48)
	hint_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(hint_area)

	# Bottom right, above the hint strip: out of the way of the model,
	# and where every other 3D tool puts it.
	_marquee = Marquee.new()
	spacer.add_child(_marquee)

	_turning = PivotMark.new()
	_turning.camera = _camera
	add_child(_turning)


	# The editing verbs, for a screen with no keyboard to press.
	if TouchTools.wanted():
		_tools = TouchTools.new()
		_tools.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		_tools.anchor_top = 0.5
		_tools.anchor_bottom = 0.5
		_tools.offset_left = 12.0
		_tools.offset_top = -TouchTools.TARGET * 2.2
		_tools.offset_bottom = TouchTools.TARGET * 2.2
		spacer.add_child(_tools)
		_tools.chose.connect(_on_touch_tool)

	var hint := ControlsHint.new()
	_hint = hint
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -46.0
	hint.offset_bottom = 0.0
	hint.alignment = FlowContainer.ALIGNMENT_CENTER
	hint_area.add_child(hint)
	# The box grows to whatever the strip needs, however it wraps.
	hint.resized.connect(func() -> void:
		var wants: float = maxf(hint.get_combined_minimum_size().y, 46.0)
		hint_area.custom_minimum_size = Vector2(0, wants + 4.0)
		hint.offset_top = -wants)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(pad)

	_chat = ChatPanel.new()
	# Decided before the panel is built, because it decides whether the
	# choice appears in the composer at all.
	_chat.claude_code_here = not ClaudeCode.found().is_empty()
	_chat_dock = SideDock.new()
	_chat_dock.title = "Assistant"
	_chat_dock.icon = "assistant"
	_chat_dock.holds = "the assistant"
	_chat_dock.setup(_chat, SideDock.Edge.RIGHT, 340.0)
	layout.add_child(_chat_dock)
	_chat.bind(_assistant)
	# Claude asking for more room than the selection waits on the person: the
	# panel the question is in comes into view.
	_assistant.room_asked.connect(func(_why: String, _where: String) -> void:
		_chat_dock.set_open(true))
	# Claude as the client, on the person's own plan: this tab offered as
	# a connector. Its requests are answered by a CommandSocket that never
	# listens on a port — only its answer_rpc is used, the same code the
	# desktop's MCP port answers with.
	var answering := CommandSocket.new()
	answering.assistant = _assistant
	answering.app = self
	add_child(answering)
	_connector = ClaudeConnector.new()
	_connector.rpc = answering
	_connector.account = _account
	add_child(_connector)
	_chat.use_connector(_connector)
	# On again with the same address if it was on last time, so the
	# connector added to Claude keeps working from one visit to the next —
	# once somebody is signed in, because a connector belongs to an
	# account. Signing out switches it off.
	_account.changed.connect(_on_account_changed)
	_on_account_changed()
	_chat.steps_wanted.connect(_toggle_steps)
	_chat.parts_list_wanted.connect(_toggle_parts)
	_chat.designing.connect(func(brief: String) -> void:
		_make_room(ModelStore.name_for(brief)))
	# The design's own name, once it stands, over the one its brief gave the
	# model, or over none; never over a name somebody gave it.
	_assistant.titled.connect(func(name: String) -> void:
		if name != _store.title and _store.title in [ModelStore.UNTITLED, _named_for_work]:
			_store.begin(name)
			_named_for_work = _store.title)
	# What the design said it stands on, laid when it stands.
	_assistant.floor_chosen.connect(_on_floor_chosen)
	_assistant.finished.connect(func(ok: bool, _summary: String) -> void:
		if _plate_after_design and ok:
			floor_part_of_model(true)
		_plate_after_design = false)
	# Saved, opened or begun again, it is not named for that work any more.
	_store.saved.connect(func(_name: String) -> void: _named_for_work = "")
	_store.loaded.connect(func(_name: String, _bricks: int) -> void: _named_for_work = "")
	_store.begun.connect(func(_name: String) -> void: _named_for_work = "")
	_builder.placed.connect(func(_id: int, _part: String) -> void:
		_sample_untouched = false)
	_builder.removed.connect(func(_id: int) -> void:
		_sample_untouched = false)
	# Designing on the person's own Claude subscription, when this
	# machine has the Claude Code to do it with. The panel offers the
	# choice only then.
	_chat.design_locally.connect(func(brief: String) -> void:
		if not design_with_claude_code(brief):
			_chat.gave_up("Could not start Claude Code.")
			return
		_chat.follow(claude_code()))

	# Across the window rather than inside a column: a parts list is
	# consulted and dismissed, and at four hundred pieces it wants the
	# room. Added to the HUD directly so no dock resizes around it.
	# Inset from the edges rather than a fixed 860 by 600.
	#
	# A fixed size centred on the screen is off the screen as soon as
	# the screen is smaller than the size: on a phone held sideways the
	# list overflowed top and bottom, taking its header with it — and
	# the header holds the only Done button, so the way out was a key
	# nobody has. It is now as big as there is room for, up to the size
	# it used to be.
	_inventory = InventoryPanel.new()
	_inventory.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD.add_child(_inventory)
	_inset(_inventory, 860.0, 600.0)
	get_viewport().size_changed.connect(func() -> void:
		_inset(_inventory, 860.0, 600.0)
		_inset(_controls, ControlsDialog.WIDE, ControlsDialog.TALL)
		_inset(_mosaic, MOSAIC_WIDE, MOSAIC_TALL)
		_inset(_brickify, 400.0, 690.0)
		_inset(_figures, 1040.0, 660.0)
		_inset(_elements, 440.0, 760.0))
	_bar.parts_wanted.connect(_toggle_parts)
	_bar.timeline_wanted.connect(_toggle_steps)
	# The booklet is Build, Instructions and the toolbar's Instructions
	# button (Shell._instructions, which calls _booklet_wanted).

	# Over the model rather than beside it, like the parts list: making
	# a figure wants the room, and is done before going back to build.
	_figures = MinifigDialog.new()
	_figures.library = _library
	_figures.thumbnails = _thumbnails
	$HUD.add_child(_figures)
	_inset(_figures, 1040.0, 660.0)
	_bar.minifig_wanted.connect(_open_figures)
	_figures.place_wanted.connect(_hold_figure)

	_controls = ControlsDialog.new()
	$HUD.add_child(_controls)
	_inset(_controls, ControlsDialog.WIDE, ControlsDialog.TALL)
	_bar.controls_wanted.connect(_controls.open)
	# The strip along the bottom names what the middle button does, so
	# it is wrong the moment somebody changes it.
	_controls.changed.connect(func() -> void:
		if _hint != null:
			_hint.rebuild())

	_picker = PickImage.new()
	add_child(_picker)
	_mosaic = MosaicDialog.new()
	_mosaic.library = _library
	$HUD.add_child(_mosaic)
	_inset(_mosaic, MOSAIC_WIDE, MOSAIC_TALL)

	# Straight from the button press into the file dialog, with nothing
	# awaited between. A browser only opens a file picker while it is
	# still handling a real click, so anything deferred here would be
	# silently ignored on the web and work perfectly on the desktop.
	# One picker, two things that want a picture, so which one asked has
	# to be remembered — the file dialog answers long after the click
	# that opened it.
	_bar.mosaic_wanted.connect(func() -> void:
		_picking_reference = false
		_picker.ask())
	_chat.reference_wanted.connect(func() -> void:
		_picking_reference = true
		_picker.ask())
	_picker.failed.connect(func(why: String) -> void: _bar.say(why))
	_picker.picked.connect(func(image: Image) -> void:
		if _picking_reference:
			if _assistant.remember_reference(image):
				_chat.references_are(_assistant.references.size())
				_bar.say("kept — the proportions will be measured off it")
			else:
				_bar.say("could not read that picture")
			return
		_mosaic_source = image
		_assistant.art_source = image
		_mosaic.show_for(image))
	_mosaic.build_wanted.connect(_build_mosaic)
	_mosaic.art_wanted.connect(_build_art)
	_mosaic.claude_wanted.connect(_design_art_with_claude)
	_assistant.art_laid.connect(_art_laid)

	# A 3D model laid in bricks, as a sub-assembly beside what is built.
	_brickify = BrickifyDialog.new()
	_brickify.library = _library
	_brickify.world = _world
	_brickify.builder = _builder
	_brickify.scenery = _store.scenery
	$HUD.add_child(_brickify)
	_inset(_brickify, 400.0, 690.0)
	# Straight from the press into the file chooser, as the mosaic's.
	_bar.brickify_wanted.connect(_brickify.ask)
	_brickify.said.connect(func(text: String) -> void: _bar.say(text))
	_brickify.placing.connect(func(name: String) -> void:
		if _shell != null:
			_brickify.assemblies = _shell.assemblies
		_make_room(name))
	_brickify.brickified.connect(func(_ids: PackedInt64Array, summary: String) -> void:
		_ground_for_the_model()
		_camera.frame(_selection_bounds(), 1.4)
		_on_model_edited()
		_bar.say(summary))

	_elements = ElementDialog.new()
	_elements.library = _library
	$HUD.add_child(_elements)
	_inset(_elements, 440.0, 760.0)
	_bin.make_wanted.connect(func() -> void:
		_elements.color_code = _builder.held_color
		_elements.open(_builder.held_part))
	_elements.made.connect(func(part_id: String) -> void:
		_bin.populate()
		_bin.show_category("Custom")
		_bin.show_held(part_id, _builder.held_color)
		_on_part_chosen(part_id)
		var info: PartLibrary.PartInfo = _library.parts.get(part_id)
		_bar.say("made %s — it is in the parts bin under Custom" % (
			Inventory._tidy(info.name) if info != null else part_id)))

	# Prints and stickers for any part of the model (src/prints).
	_studio = PrintStudio.new()
	_studio.library = _library
	_studio.world = _world
	_studio.builder = _builder
	_studio.camera = _camera
	add_child(_studio)
	_studio.setup($HUD)
	_bin.print_wanted.connect(func() -> void: _studio.print_part(_builder.held_part))
	_bin.stickers_wanted.connect(_studio.open_sheet)
	_studio.said.connect(func(words: String) -> void: _bar.say(words))
	_studio.made.connect(func(part_id: String) -> void:
		_bin.populate()
		if not Stickers.is_sticker(_library, part_id):
			_bin.show_category(PartPrints.MY_PRINTS)
			_bin.show_held(part_id, _builder.held_color)
			_on_part_chosen(part_id))

	# Panels sized to the window, and folded away when there is no room
	# for them beside the model. On a phone a panel that takes its
	# design width would leave about fifty pixels of viewport, so it
	# becomes a drawer: most of the screen while you are using it, gone
	# the moment you are not.
	get_tree().root.size_changed.connect(_match_screen_density)
	get_tree().root.size_changed.connect(_fit_panels)
	_bin_dock.opening.connect(_column_opening.bind(_bin_dock))
	_chat_dock.opening.connect(_column_opening.bind(_chat_dock))
	_bin_dock.toggled.connect(func(_open: bool) -> void: _column_toggled())
	_chat_dock.toggled.connect(func(_open: bool) -> void: _column_toggled())
	_fit_panels()

	_bin.populate()
	_builder.held_color = _bin.selected_color()

	# Anything that changes the model marks it for saving. Placing and
	# removing are somebody's own doing, so they also settle the
	# question of whether the model on screen is the one to keep.
	# Once a frame, not once a part (_edited_soon).
	_builder.placed.connect(func(_id: int, _part: String) -> void: _edited_soon())
	_builder.removed.connect(func(_id: int) -> void: _edited_soon())
	# Watch it go up, in the order it would be built, rather than find
	# it already there.
	_playback = BuildPlayback.new()
	_playback.world = _world
	_playback.library = _library
	add_child(_playback)
	_watch_own_frames()
	_world.rebuilds_in_slices = true

	# What the camera turns around. Without this it orbits the middle of
	# whatever was last framed, so grabbing a chimney and dragging swings
	# the chimney out of shot.
	_camera.pick = func(at: Vector2) -> Variant:
		var from: Vector3 = _camera.ray_origin(at)
		var towards: Vector3 = _camera.ray_normal(at)
		var hit: BrickLattice.Hit = _builder.lattice.raycast(from, towards)
		if hit.is_valid():
			return from + towards * hit.distance
		# Nothing under the pointer, but there is still a baseplate to
		# turn around: where the ray meets the ground reads as the place
		# you pointed at far better than the middle of the model does.
		var ground := Plane(Vector3.UP, 0.0)
		var landing: Variant = ground.intersects_ray(from, towards)
		return landing if landing != null else null

	_outline = SelectionOutline.new()
	_outline.world = _world
	_outline.library = _library
	add_child(_outline)
	_hover_outline = SelectionOutline.new()
	_hover_outline.world = _world
	_hover_outline.library = _library
	_hover_outline.colour = SelectionOutline.HOVER
	_hover_outline.width = SelectionOutline.HOVER_WIDTH
	add_child(_hover_outline)

	_verbs = EditVerbs.new()
	_verbs.builder = _builder
	_verbs.world = _world
	_verbs.library = _library
	_verbs.say = _bar.say
	_verbs.edited = _on_model_edited
	_verbs.aim_again = _hover_again
	_verbs.scenery = _store.scenery
	_verbs.camera = _camera
	add_child(_verbs)
	# A part in hand (Q, the bin, the eyedropper) brings the parts bin out
	# if it was folded: a laptop's window starts with the assistant
	# showing, and the part in hand and its colours are in the bin.
	_verbs.mode_changed.connect(func(mode: String) -> void:
		# A part in hand: the palette's colour is for it now, not the
		# selection's.
		_tell_bin_selection()
		if mode == "place":
			_bring_out_bin())
	# The menus, the toolbar, the properties and the status bar:
	# src/ui/shell.gd. The parts count is the status bar's.
	_shell = Shell.new()
	_shell.app = self
	add_child(_shell)
	_shell.build(column, _stack, _notices.get_child(0) as Control, _over_model)
	# Claude's change to a selection made in one copy of a sub-assembly is
	# followed by the others, as a change by hand is.
	_assistant.assemblies = _shell.assemblies
	# The colours at the foot of the column, under the model tree and the
	# properties: what those do moves the parts grid's foot, never them.
	_stack.add_section(_bin.colours)
	_bin.column = _stack
	_counts = _shell.status.counts

	# The ruler, and what it says, under the counts.
	_measure = Measure.new()
	_measure.lattice = _builder.lattice
	_measure.camera = _camera
	_measure.label = _viewport_label(13)
	_measure.label.visible = false
	_measure.label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_measure.label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_measure.label.offset_top = 10.0
	spacer.add_child(_measure.label)
	add_child(_measure)
	_verbs.measure = _measure

	# Build, Hose, tube or chain…: src/ui/flex_tool.gd, its panel over the
	# model's left edge.
	_flex = FlexTool.new()
	_flex.world = _world
	_flex.builder = _builder
	_flex.library = _library
	_flex.assemblies = _shell.assemblies
	_flex.camera = _camera
	_flex.say = _bar.say
	add_child(_flex)
	spacer.add_child(_flex.panel)
	_flex.panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_flex.panel.position = Vector2(12, 48)
	_flex.changed.connect(_on_model_edited)

	# Along the top of the model, when a model opened with parts a fraction
	# of a stud off their studs: src/ui/seat_offer.gd.
	_seat_offer = SeatOffer.new()
	_seat_offer.builder = _builder
	_seat_offer.world = _world
	_seat_offer.assistant = _assistant
	_seat_offer.scenery = _store.scenery
	_seat_offer.say = _bar.say
	_seat_offer.edited = _on_model_edited
	_seat_offer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notices.get_child(0).add_child(_seat_offer)
	_bar.opened.connect(func(_bricks: int) -> void: _seat_offer.check())
	_bar.started_new.connect(_seat_offer.dismiss)
	_bar.cleared.connect(_seat_offer.dismiss)

	# Export's picture and shop lists: src/ui/exports.gd.
	_exports = Exports.new()
	_exports.world = _world
	_exports.library = _library
	_exports.scenery = _store.scenery
	_exports.say = _bar.say
	_exports.named = _bar.model_name
	_exports.store = _store
	add_child(_exports)
	_exports.picture.world = _world
	_exports.picture.camera = _camera
	_exports.picture.scenery = _store.scenery
	_exports.picture.aside = [_builder, _turning, _shell.see_inside.frame, _floor.grid_node(),
		_floor.shadow_node(), _shell.grid]
	_exports.picture.shown_again = _verbs.apply_hidden
	_bar.picture_wanted.connect(_exports.take_picture)
	_bar.shop_list_wanted.connect(_exports.shop_list)
	_bar.studio_wanted.connect(_exports.studio_io)

	# File, Render…: a photo-real picture or turntable, drawn off screen
	# in the window's own light (src/ui/render_dialog.gd, src/render/studio_render.gd).
	_render = RenderDialog.new()
	_render.world = _world
	_render.library = _library
	_render.scenery = _store.scenery
	_render.eye = _camera
	_render.look = ($WorldEnvironment as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(get_node(light_name) as DirectionalLight3D)
	_render.named = _bar.model_name
	$HUD.add_child(_render)
	_inset(_render, RenderDialog.WIDE, RenderDialog.TALL)
	get_viewport().size_changed.connect(func() -> void:
		_inset(_render, RenderDialog.WIDE, RenderDialog.TALL))
	# Build, Pose and animate…: sliders for the joints, keys, and the
	# animation rendered the same way (src/ui/pose_panel.gd), over the
	# model's left edge so the pose is seen as it is set.
	_pose = PosePanel.new()
	_pose.world = _world
	_pose.builder = _builder
	_pose.library = _library
	_pose.assemblies = _shell.assemblies
	_pose.scenery = _store.scenery
	_pose.eye = _camera
	_pose.look = _render.look
	_pose.rig_lights = _render.rig_lights
	_pose.named = _bar.model_name
	_over_model.add_child(_pose)
	_pose.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pose.position = Vector2(12, 48)
	_pose.changed.connect(_on_model_edited)
	# Tools, Simulate mechanism…: a gear train turned from its driver, in the
	# same place over the model's left edge (src/ui/simulate_panel.gd). It
	# changes nothing, so it has no changed signal: what turns is drawn.
	_simulate = SimulatePanel.new()
	_simulate.world = _world
	_simulate.builder = _builder
	_simulate.library = _library
	_simulate.shell = _shell
	_simulate.scenery = _store.scenery
	_simulate.eye = _camera
	_simulate.look = _render.look
	_simulate.rig_lights = _render.rig_lights
	_simulate.named = _bar.model_name
	_over_model.add_child(_simulate)
	_simulate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_simulate.position = Vector2(12, 48)
	_builder.selection_changed.connect(_simulate._on_selection)
	_builder.selection_changed.connect(func(count: int) -> void:
		_outline.show_selection(_builder.selection)
		_tell_bin_selection()
		_look_under_again()
		if count == 0:
			_bar.say("")
		else:
			_bar.say("%d selected — %s-C copies, X moves, R turns, C paints, Delete removes"
				% [count, ControlsHint._hold()]))
	# The world is redrawn whenever anything in it changes, which
	# includes a selected brick being removed by undo or replaced by the
	# assistant. Without redrawing the outline then, it is a box round
	# nothing.
	_world.rebuilt.connect(func(_bricks: int, _batches: int, _tris: int) -> void:
		# Painted, or taken off by undo: what the palette's note says too.
		_tell_bin_selection()
		if not _builder.selection.is_empty():
			_outline.show_selection(_builder.selection)
		_look_under_again())
	# So a snapshot does not carry the baseplate off with it.
	_assistant.scenery = _store.scenery

	_assistant.built.connect(func(_n: int) -> void:
		# A design can be bigger than the ground it was given.
		#
		# The baseplate is laid when a model is opened and when the
		# board is cleared, and never after something is built on it —
		# so a ship the assistant designs larger than thirty-two studs
		# hangs off the edge into nothing, which reads as the model
		# being broken rather than the ground being small.
		# Next frame, not inside the signal.
		#
		# built is emitted from the middle of applying a design, and
		# laying fresh ground removes the old plates from the world and
		# the lattice. Doing that while the apply is still walking its
		# own placements is how a run reaches the last critique and
		# then simply stops, with no error and nothing written.
		#
		# And framed, when nobody can see it: whoever comes back to the tab
		# finds the model in view rather than wherever the camera was left.
		_watch_view()
		_ground_for_the_model.call_deferred(_out_of_view)
		_on_model_changed()
		# Not when nobody is watching. Every edit emits this, and the
		# assembly planned build steps for the whole model and then showed
		# it a step at a time, each step walking every brick: on a
		# 3,000-part Orthanc driven over MCP a frame took 13 s while it
		# played, so a look took two to three minutes, add_rooms nearly
		# three and a restyle four, waiting on an animation in a window
		# nobody could see. Without it a look is 0.3 s and each of those
		# 12 s. And only what the change put down: what was standing
		# already does not vanish to be built again.
		# Nor when nobody can see it: a design made from claude.ai with the
		# tab out of view is there, whole, when the tab is looked at.
		if not _driven and not _out_of_view and _playback.play_new(_assistant.fresh_ids):
			_bar.say("building…"))
	# A draft appears as it is; it is about to be replaced, so animating
	# it would be an assembly that never finishes.
	_assistant.sketched.connect(func(count: int) -> void:
		if _playback.is_playing():
			_playback.stop()
		_on_model_changed()
		# A check puts the design down too: framed the same, out of view.
		_watch_view()
		if _out_of_view:
			_camera.frame(_built_bounds())
		_bar.say("working — %d bricks so far" % count))

	# Who is signed in, and the way out: from Account on the bar.
	_account_panel = AccountPanel.new()
	_account_panel.setup(_account)
	if _connector != null:
		_account_panel.use_connector(_connector)
	$HUD.add_child(_account_panel)
	_inset(_account_panel, AccountPanel.WIDE, AccountPanel.TALL)
	get_viewport().size_changed.connect(func() -> void:
		_inset(_account_panel, AccountPanel.WIDE, AccountPanel.TALL))
	_bar.account_wanted.connect(_account_panel.open)
	_account_panel.sign_out_wanted.connect(func() -> void:
		_connector.stop()
		_account.sign_out())

	# Share this model: File › Share… and the toolbar's Share.
	_share_panel = SharePanel.new()
	_share_panel.account = _account
	_share_panel.store = _store
	_share_panel.shared = _shared
	_share_panel.picture = _exports.picture
	_share_panel.named = _bar.model_name
	_share_panel.setup()
	$HUD.add_child(_share_panel)
	_inset(_share_panel, SharePanel.WIDE, SharePanel.TALL)
	get_viewport().size_changed.connect(func() -> void:
		_inset(_share_panel, SharePanel.WIDE, SharePanel.TALL))

	# The parts list's own BrickLink and Rebrickable buttons.
	_inventory.shop_wanted.connect(func(shop: String) -> void:
		_inventory.tell(_exports.shop_list(shop)))

	# Over everything else, so it is added last: nothing in the builder can
	# be used until someone is signed in. Not over a shared model's viewer,
	# which is for anybody with the link.
	if _gate_wanted() and _viewing.is_empty():
		_gate = SignInGate.new()
		_gate.setup(_account)
		$HUD.add_child(_gate)

	# Last, so the buttons above are all there for it to give a
	# pointing hand to; any made later are caught as they arrive.
	_cursors = Cursors.new()
	add_child(_cursors)
	_cursors.looked_again.connect(_hover_again)
	# A wheel, a swipe or a button over a panel is the panel's. See
	# CadCamera._begins_over_interface.
	_camera.over_interface = _over_interface


## A label that reads over the 3D behind it, whatever colour that is.
##
## On a dark pill as wide as its words. It was white with a black outline
## four units thick, which at twelve points filled in every letter's
## counters: over the pale sky on an ordinary screen "62 bricks" was a
## grey smudge, and smaller than 1040 points across it could not be read.
static func _viewport_label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.09, 0.1, 0.12, 0.66)
	pill.set_corner_radius_all(10)
	pill.content_margin_left = 10
	pill.content_margin_right = 10
	pill.content_margin_top = 2
	pill.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", pill)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The key for a direct desktop call. Brain holds the one copy of this,
## because five probes had their own and all five read only the
## environment — so a key in .env made every one of them skip.
static func _anthropic_key() -> String:
	return Brain.api_key()


## The working model is written a couple of seconds after the last
## change, so closing the tab costs seconds rather than an afternoon.
## Turn the whole build on the baseplate, keeping the lattice exact.
func _turn_model(quarter_turns: int) -> void:
	var moved: Array = _world.rotate_model(quarter_turns, _store.scenery)
	if moved.is_empty():
		return
	for entry: Dictionary in moved:
		_builder.lattice.release(entry["id"])
	for entry: Dictionary in moved:
		_builder.register(entry["id"], entry["part"], entry["at"])
	_on_model_changed()


## The booklet: drawn off screen by BookletMaker, then handed over.
##
## [param to] writes it to a file and says so, which is how the command
## line and the checks ask for one. Otherwise it goes where people are: on
## the web into the tab [method _booklet_wanted] opened as the button was
## pressed (a browser only lets a page open a tab in answer to a click,
## and the pictures take longer than that), and on the desktop into the
## Downloads folder and open in the browser, ready to print.
func _export_booklet(to: String = "", job: Working.Job = null) -> String:
	# Said in the status bar while it works (Working), and in the tab it is
	# going to on the web, which is the one in front while it draws. A
	# session's job (ToolJobs) is the same bar, handed in.
	if job == null:
		job = Working.begin("Planning the booklet…", 0, true)
	else:
		job.say("Planning the booklet…")
		job.can_cancel = true
	await job.shown()
	var maker := BookletMaker.new()
	maker.library = _library
	maker.job = job
	add_child(maker)
	maker.progress.connect(func(_said: String) -> void:
		BookletMaker.tell_tab(job.line()))
	var title: String = _bar.model_name()
	var html: String = await maker.make(_world, _store.scenery, title)
	var steps: int = maker.document.steps if maker.document != null else 0
	if not to.is_empty():
		print("booklet took %s" % ", ".join(maker.laps.map(func(lap: Array) -> String:
			return "%s %.1f s" % [lap[0], float(lap[1]) / 1000.0])))
	maker.queue_free()
	if job.cancelled or html.is_empty():
		job.end()
		BookletMaker.close_tab()
		var why: String = "stopped drawing the booklet" if job.cancelled \
			else "nothing to write instructions for"
		_bar.say(why)
		return why
	job.say("Opening the booklet…")
	job.count(0, 0)
	job.can_cancel = false
	var file_name: String = title.to_snake_case() + "_instructions.html"
	var note: String
	if not to.is_empty():
		var file: FileAccess = FileAccess.open(to, FileAccess.WRITE)
		if file == null:
			note = "could not write %s" % to
		else:
			file.store_string(html)
			file.close()
			note = "wrote %s, %d steps" % [to, steps]
	elif OS.has_feature("web") and BookletMaker.fill_tab(html):
		note = "the booklet is open in a new tab, %d steps" % steps
	else:
		note = Download.give(html, file_name, "text/html")
		if note.begins_with("wrote ") and BookletMaker.open_when_written:
			OS.shell_open("file://" + note.trim_prefix("wrote "))
	job.end()
	_bar.say(note)
	return note


## The Instructions button, on the toolbar and on the timeline.
func _booklet_wanted() -> void:
	if BookletMaker.busy:
		_bar.say("already drawing the booklet…")
		return
	if OS.has_feature("web"):
		BookletMaker.open_tab()
	await _export_booklet()


## What was built, without the baseplate it was built on. Falls back to
## everything when the model *is* scenery, so a picture of a bare plate
## still gets framed rather than pointing at nothing.
func _built_bounds() -> AABB:
	var bounds: AABB = _model_bounds()
	if bounds.size.length_squared() > 0.0:
		return bounds
	# Everything, including the scenery, when nothing has been built —
	# a box round nothing frames nothing, and the baseplate is at least
	# somewhere to stand. Not _built_bounds(), which is this function.
	# With no baseplate, the ground the floor covers.
	var everything: AABB = _world.model_bounds()
	if everything.size.length_squared() <= 0.0 and _floor != null \
			and _floor.area.size.length_squared() > 0.0:
		return AABB(_floor.area.position, _floor.area.size + Vector3(0.0, BrickLattice.BRICK, 0.0))
	return everything


## Lay the chosen picture out in plates.
##
## The mosaic replaces whatever was there, because a picture is a whole
## model rather than an addition to one — and it goes through the
## ordinary placement path, so it is undoable, saveable, counted by the
## parts list and walked by the booklet like anything else.
func _build_mosaic(across: int, dither: bool) -> void:
	if _mosaic_source == null:
		return
	_bar.say("laying it out…")
	await get_tree().process_frame

	var pixels: Array[Mosaic.Pixel] = Mosaic.lay_out(
		_mosaic_source, across, PackedInt32Array(Mosaic.PALETTE),
		_library, dither)
	if pixels.is_empty():
		_bar.say("nothing to lay out")
		return

	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_assistant.forget_built()
	_store.scenery.clear()

	var part: Lbm.PartMesh = _library.mesh_for(Mosaic.PIXEL_PART)
	for pixel: Mosaic.Pixel in pixels:
		# A 1 x 1 plate sits centred on its stud, and the mosaic is laid
		# on the ground, so y is the plate height and nothing else.
		var at := Transform3D(Basis.IDENTITY, Vector3(
			pixel.x * BrickLattice.STUD + BrickLattice.STUD * 0.5,
			part.bounds.size.y,
			pixel.z * BrickLattice.STUD + BrickLattice.STUD * 0.5))
		var brick_id: int = _world.add_brick(
			Mosaic.PIXEL_PART, pixel.color_code, at)
		if brick_id != 0:
			_builder.register(brick_id, Mosaic.PIXEL_PART, at)

	_on_a_floor_of_its_own()
	_camera.frame(_built_bounds(), 1.1)
	_camera.set_view("top")
	_on_model_changed()
	_bar.say("%d plates — press P for what to buy" % pixels.size())


## A picture laid in plates is a whole model on its own panels, with nothing
## under it: its floor is none, or the next edit would lay a baseplate under
## the picture (FloorLayer.is_stale). Not a step of the history, which the
## picture replaced.
func _on_a_floor_of_its_own() -> void:
	var none: ModelFloor = _store.model_floor.copy()
	none.kind = ModelFloor.NONE
	_store.model_floor = none
	_lay_baseplate()


## The picture dialog's size: room for the Art mode's picture, its
## switches and what it comes to.
const MOSAIC_WIDE := 440.0
const MOSAIC_TALL := 720.0


## Lay the chosen picture out as a LEGO Art set lays one (MosaicArt): its
## panels joined underneath, its elements chosen region by region. Like the
## classic mosaic it replaces what was there, through the ordinary placement
## path, each panel its own sub-assembly so the booklet builds a panel at a
## time.
func _build_art(options: MosaicArt.Options) -> void:
	if _mosaic_source == null:
		return
	var job: Working.Job = Working.begin("Laying the picture out as Brick Art…")
	await job.shown()
	var art: MosaicArt.Art = _mosaic.current_art() if _mosaic != null else null
	if art == null:
		art = MosaicArt.make(_mosaic_source, options, _library)
	if art.placements.is_empty():
		job.end()
		_bar.say("nothing to lay out")
		return
	# On the web most of these parts are fetched rather than shipped.
	job.say("Fetching the parts…")
	await _assistant._ensure_parts(art.model())

	_world.clear()
	_builder.lattice.clear()
	_builder.forget_history()
	_assistant.forget_built()
	_store.scenery.clear()
	job.say("Putting down %s parts…" % Working.comma(art.placements.size()))
	await MosaicArt.put_down_paced(art, _world, _builder, _assistant, job)
	job.say("Checking it holds together…")
	job.count(0, 0)
	await _art_laid(art)
	job.end()


## The mosaic dialog's Design with Claude: the picture handed to the
## assistant, which plans it with make_art in whichever way the person
## designs — their key, or their own Claude on this machine.
func _design_art_with_claude(said: String) -> void:
	if _mosaic_source == null:
		return
	_assistant.art_source = _mosaic_source
	_chat_dock.set_open(true)
	var why: String = _chat.ask(MosaicDialog.art_brief(said, _mosaic.chosen_panels()))
	if not why.is_empty():
		_bar.say(why)


## What the last picture laid in LEGO Art came to, checked: its parts, its
## panels and how many pieces it is, for the status line and for
## tools/web/art_flow.mjs (window.brickworksState.art).
var _art_said: Dictionary = {}


## A picture laid in LEGO Art, by the dialog's Build or by make_art: looked
## at, then checked as a design is, so the line says whether it is one piece.
func _art_laid(art: MosaicArt.Art) -> void:
	_on_a_floor_of_its_own()
	if _shell != null:
		_shell.assemblies.changed.emit()
	_camera.frame(_built_bounds(), 1.1)
	var raised: bool = false
	for plates: int in art.plan.relief:
		raised = raised or plates > 0
	_camera.set_view("isometric" if raised else "top")
	_on_model_changed()
	_art_said = {"parts": art.placements.size(), "panels": [art.panels.x, art.panels.y],
		"pieces": 0, "ok": false}
	_bar.say("%s parts on %d × %d panels — checking it holds together…" % [
		MosaicDialog._comma(art.placements.size()), art.panels.x, art.panels.y])
	var report: Dictionary = await _assistant._checked(art.model(), true)
	_art_said["pieces"] = int(report.get("pieces", 0))
	_art_said["ok"] = bool(report.get("ok", false))
	_bar.say("%s parts on %d × %d panels, %s — press P for what to buy" % [
		MosaicDialog._comma(art.placements.size()), art.panels.x, art.panels.y,
		"one piece" if _art_said["pieces"] == 1 and _art_said["ok"]
		else str(report.get("summary", ""))])


## Width below which the two panels cannot both sit beside the model.
## Their design widths plus something worth looking at between them.
const ROOMY := 1040.0
## How much of the window, across, the model keeps between the two
## columns, in the interface's units, or the columns take turns. It has 872
## at the design width (1600), both open. A laptop's window is narrower:
## at 1280 x 720 both left it 53% of the width, less again with the model
## tree and the properties laid over it, and a click meant for a part
## landed on a panel. One at a time it keeps 72%.
const MODEL_ROOM := 860.0

## How the window shares its width out: "wide" (both columns, as they
## were left), "turns" (one column at a time: opening one folds the
## other) or "drawers" (a phone: both start folded, and each opens over
## most of the screen).
var _columns: String = ""
## Set while the window, not a person, opens and folds the columns: what
## it does is not the person's layout to keep.
var _arranging: bool = false
## What Tab put away, [parts, model], to bring back.
var _tabbed: Array = []


## Fit the panels to the window, and decide how it shares them out.
func _fit_panels() -> void:
	if _bin_dock == null or _chat_dock == null or not _viewing.is_empty():
		return
	# The real window, in points, not the viewport and not in pixels.
	#
	# With canvas_items stretch the visible rect is the design size —
	# 1600 wide whatever the window is — so asking it how much room
	# there is always answers "plenty". Dividing the canvas by the
	# app's own content scale was the next attempt and is wrong above
	# two device pixels to the point, which is every modern phone: an
	# eight-hundred-point phone held sideways measured as roomier than
	# the threshold and kept both panels open across a screen with room
	# for neither.
	var across: float = Room.across()
	var phone: bool = across < ROOMY

	# A drawer leaves the far rail showing, so the way out is visible
	# from inside it. Measured in the interface's own units, which a
	# panel's width is: in points a phone is 390 across where it shows
	# about 720 units, and the drawers came out 322 wide round panels
	# that need 340, cut off down their right edge.
	var units: float = get_viewport().get_visible_rect().size.x
	var drawer: float = maxf(units - SideDock.RAIL_WIDTH * 2.0 - 16.0, 220.0)
	_bin_dock.set_open_width(minf(336.0, drawer) if phone else 336.0)
	_chat_dock.set_open_width(minf(340.0, drawer) if phone else 340.0)

	# Whether both columns at their own widths leave the model its room.
	var both: float = 336.0 + 340.0 + SideDock.RAIL_WIDTH * 2.0
	var share: String = "drawers" if phone else (
		"turns" if units - both < MODEL_ROOM else "wide")
	# Only when it changes. Arranging them on every resize would fight
	# anyone dragging a window edge with a panel deliberately open.
	if share == _columns:
		return
	_columns = share
	_arrange_columns()


## The part of the window the model is seen in, for the camera to centre
## the view on and frame to: the model's column, between the bars, as
## model_cover samples it. A phone's drawer opens over most of the screen
## and is put away again to build, so there the column is taken as both
## drawers folded, and the model does not leap to the sliver beside one.
func _model_rect() -> Rect2:
	var rect: Rect2 = _over_model.get_global_rect()
	if _columns == "drawers":
		var across: float = get_viewport().get_visible_rect().size.x
		rect.position.x = SideDock.RAIL_WIDTH
		rect.size.x = across - SideDock.RAIL_WIDTH * 2.0
	return rect


## Open and fold the columns as the window's share says, from what the
## person left for a window of this kind.
func _arrange_columns() -> void:
	var parts: bool = false
	var assistant: bool = false
	match _columns:
		"wide":
			parts = bool(ShellPrefs.value("parts_open"))
			assistant = bool(ShellPrefs.value("assistant_open"))
		"turns":
			var side: String = str(ShellPrefs.value("narrow_side"))
			parts = side == "parts"
			assistant = side == "assistant"
	_arranging = true
	_bin_dock.set_open(parts, false)
	_chat_dock.set_open(assistant, false)
	_arranging = false


## A column about to open, by a person or a command: where there is room
## for one, the other folds, so the model keeps its share of the window.
func _column_opening(dock: SideDock) -> void:
	if _arranging or _columns == "wide":
		return
	(_chat_dock if dock == _bin_dock else _bin_dock).set_open(false)


## A column opened or folded: kept as the person's layout for a window of
## this kind. A phone's drawers are not kept; they start folded.
func _column_toggled() -> void:
	if _arranging:
		return
	match _columns:
		"wide":
			ShellPrefs.put("parts_open", _bin_dock.is_open())
			ShellPrefs.put("assistant_open", _chat_dock.is_open())
		"turns":
			ShellPrefs.put("narrow_side", "parts" if _bin_dock.is_open()
				else ("assistant" if _chat_dock.is_open() else ""))


## The parts bin out, if it is folded, for a part just put in hand. Not
## on a phone, where it would be a drawer over the model the part is for.
func _bring_out_bin() -> void:
	if _bin_dock == null or _bin_dock.is_open() or _columns == "drawers":
		return
	_bin_dock.set_open(true)


## Tab: both columns away, for looking at the model, and back as they were.
func _tab_columns() -> void:
	if _bin_dock.is_open() or _chat_dock.is_open():
		_tabbed = [_bin_dock.is_open(), _chat_dock.is_open()]
		_bin_dock.set_open(false)
		_chat_dock.set_open(false)
		return
	var back: Array = _tabbed if not _tabbed.is_empty() else [true, _columns == "wide"]
	_tabbed = []
	_bin_dock.set_open(bool(back[0]))
	_chat_dock.set_open(bool(back[1]))


## The strip over the model shows while something in it does.
func _show_notices() -> void:
	var any: bool = false
	for note: Node in _notices.get_child(0).get_children():
		any = any or (note as Control).visible
	_notices.visible = any


## Show or hide the parts list. Worked out on opening rather than kept
## up to date: it is a snapshot of a finished model, and recomputing it
## on every brick placed would be work for a panel nobody is looking at.
func _toggle_parts() -> void:
	if _inventory.is_showing():
		_inventory.hide_list()
		return
	if not _inventory.show_for(_world, _library, _store.scenery, _bar.model_name()):
		_bar.say("nothing to list yet")


## Start or leave the booklet. Editing while playback is on would place
## bricks into a model that is only half on screen, so the build steps
## are worked out once, on entry, from whatever is there.
func _toggle_steps() -> void:
	if _playback != null and _playback.is_playing():
		_playback.stop()
	# Pressed again while the steps are still being worked out: never mind.
	if _steps.is_starting():
		_steps.cancel_start()
		return
	if _steps.is_playing_back():
		_steps.stop()
		return
	if _world.brick_count() == 0:
		return
	await _steps.start(_world, _library, _store.scenery)


func _on_model_changed() -> void:
	if _store != null:
		_store.touch()
	# Steps being worked out are for the model as it was.
	if _steps != null and _steps.is_starting():
		_steps.cancel_start()


## Somebody changed the model by hand, so it is theirs now.
##
## Kept apart from _on_model_changed, which also fires for things the
## app did to itself — opening, clearing, the assistant rebuilding. Only
## a deliberate change should let the autosave write over a file that
## opened short of parts.
func _on_model_edited() -> void:
	if _store != null:
		_store.adopt()
		_store.touch()
	# A model's own baseplate taken off, or brought back by an undo: the
	# floor's plate goes back under it, or comes away.
	if _floor != null and _floor.is_stale():
		_lay_baseplate()
	elif _floor != null:
		_floor.follow(_model_bounds())
	# Every other copy of a sub-assembly just edited follows it.
	if _verbs != null and _verbs.assemblies != null:
		_verbs.assemblies.after_edit()
	# The timeline in the author's steps shows the model as it now is: a
	# part put down in the step showing, an undone step edit. (Worked out,
	# it is the order it was when opened, as it always was: on Orthanc the
	# working out takes five seconds.)
	if _steps != null and _steps.is_playing_back() and _steps.mode() == StepsBar.AUTHORS:
		_steps.refresh()


## [method _on_model_edited] at the end of this frame, once however many
## parts were placed or taken off in it. What it does is for the whole model
## (the floor asks every part whether it is a baseplate): once a part,
## taking all of Orthanc off held the window for a minute (2026-10-13,
## command_probe).
func _edited_soon() -> void:
	if _edit_coming:
		return
	_edit_coming = true
	_edited_now.call_deferred()


var _edit_coming: bool = false


func _edited_now() -> void:
	_edit_coming = false
	_on_model_edited()


## File, Render….
func open_render() -> void:
	_builder.hide_preview()
	_render.open()


## Build, Hose, tube or chain…; Edit, Reshape the hose or chain.
func open_flex() -> void:
	if _measure != null:
		_measure.leave()
	_flex.open()


func reshape_flex() -> void:
	var path: String = _flex.selected_item()
	if path.is_empty() or not _flex.reshape(path):
		_bar.say("select a hose, a tube or a chain first")


func can_reshape_flex() -> bool:
	return _flex != null and not _flex.selected_item().is_empty()


## Build, Pose and animate….
func open_pose() -> void:
	_builder.hide_preview()
	if _simulate.visible:
		_simulate.close()
	_pose.open()


## Tools, Simulate mechanism…: the Select tool in hand, so a click on an
## axle or a crank drives it rather than putting a part down.
func open_simulate() -> void:
	_builder.hide_preview()
	if _pose.visible:
		_pose.close()
	_verbs.set_mode("select")
	await _simulate.open()


func _open_figures() -> void:
	_builder.hide_preview()
	_figures.open()


## Hold a figure from the builder the way a part is held: the next click
## on a stud stands it there.
func _hold_figure(figure: Minifig) -> void:
	_builder.hold_figure(figure.assemble(_library), figure.name)
	var fetching: int = 0
	for part_id: String in figure.part_ids():
		if not _library.is_resident(part_id) and _library.request_mesh(part_id, true):
			fetching += 1
	_bar.say("placing %s — point at a stud, R to turn, click to stand it there, Esc to stop%s"
		% [figure.name, " (fetching %d parts…)" % fetching if fetching > 0 else ""])
	_refresh_preview()


func _on_part_chosen(part_id: String) -> void:
	_builder.drop_figure()
	_builder.held_part = part_id
	# A part picked is a part in hand, to put down.
	if _verbs != null:
		_verbs.set_mode("place")
	# On the web most parts are a request away rather than resident. Ask
	# for it as soon as it is picked, so it is usually there by the time
	# the cursor reaches the model.
	if not _library.is_resident(part_id):
		_library.request_mesh(part_id, true)
		# And say so. Until the bytes land there is no ghost and a click
		# does nothing, which reads as the app being broken rather than
		# as the app waiting — and on a slow connection that is several
		# seconds of it.
		_bar.say("fetching %s…" % part_id)
	_refresh_preview()


func _on_part_fetched(part_id: String) -> void:
	# Not there yet is not the same as not there: a model opened on the
	# web before its parts were fetched gets them as they come.
	if _store.place_awaited(part_id) > 0:
		_on_model_changed()
		if _store.awaited.is_empty():
			_bar.say("%d bricks" % _world.brick_count())
	if _builder.held_part == part_id:
		_refresh_preview()
		_bar.say("%s ready" % part_id)


func _on_color_chosen(color_code: int) -> void:
	_builder.held_color = color_code
	_refresh_preview()


## A colour clicked in the palette paints what is selected, as Studio's
## and Mecabricks' palettes do. It only changed the colour in hand: a
## person selected a brick, clicked blue, saw it stay red, and had to
## learn C from the status line (brickworks.diy at dd5c10c, 2026-10-12).
## Not with a part in hand or a copy held, where the colour is for what
## goes down next. Edit, Paint the selection, so it is one undo step and
## refused where that is.
func _on_swatch_pressed(_color_code: int) -> void:
	if not _swatch_paints():
		return
	_shell.run("paint")


## Whether a colour clicked in the palette paints the selection, rather
## than being the colour of what goes down next.
func _swatch_paints() -> bool:
	return not _builder.selection.is_empty() and _verbs.mode != "place" \
		and not _builder.is_carrying()


## The palette's note says what a colour clicked would paint: the
## selection, while there is one to paint (PartsBin.show_selection).
func _tell_bin_selection() -> void:
	if _bin == null or _verbs == null:
		return
	var parts := PackedStringArray()
	var colours := PackedInt32Array()
	if _swatch_paints():
		for brick_id: int in _builder.selection:
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick != null:
				parts.append(brick.part_id)
				colours.append(brick.color_code)
	_bin.show_selection(parts, colours)


## Open an LDraw model and place every part of it. Returns how many landed.
## Open a model through the store, the one way models open: stood on the
## ground, and parts not yet fetched put down as they arrive (_on_part_fetched).
func _open(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var placed: int = _store.open(path)
	if not _store.awaited.is_empty():
		_bar.say("%d bricks — fetching %d more…" % [placed, _store.awaited.size()])
	return placed


## A fallback when no sample model is around: a wall that exercises the
## batching, the palette and the lattice all at once.
func _build_demo() -> int:
	const BRICK := "3001"          # Brick 2 x 4
	const COURSE_HEIGHT := 24      # one brick
	const STUD := 20
	var palette: PackedInt32Array = PackedInt32Array([4, 14, 2, 1, 26, 25, 15, 0])

	var placed: int = 0
	for course: int in 10:
		# Offset alternate courses by two studs, the way a real wall is laid.
		var offset: int = (course % 2) * STUD * 2
		for column: int in 6:
			# Courses go up. The negated height was left over from thinking
			# in LDraw's axes, where -Y is up, and built the whole wall
			# downward through the baseplate.
			var at := Transform3D(
				Basis.IDENTITY,
				Vector3(column * STUD * 4 + offset, course * COURSE_HEIGHT, 0))
			if _world.add_brick(BRICK, palette[course % palette.size()], at) != 0:
				placed += 1
	return placed


## Build something by driving the placement path rather than the model, so
## the whole chain gets exercised: a ray is cast, the lattice is marched,
## the hit face decides a target, the target is snapped to the stud grid
## and dropped onto whatever is below, the result is collision checked, and
## only then is a brick placed.
##
## A brick that lands half a plate low, or one that is allowed to overlap
## its neighbour, shows up here and nowhere else — placing bricks by
## writing transforms directly would prove nothing about any of it.
func _autobuild(courses: int) -> void:
	var palette: Array[int] = [4, 14, 2, 1, 26, 25, 15, 191]
	const BRICK := "3001"      # Brick 2 x 4: 80 x 40 LDU
	const LONG := 80.0
	const SHORT := 40.0
	# A hollow square, four bricks to a side. The long walls take the full
	# span and the short walls fit between them, which is what stops the
	# corners overlapping; the pair swaps every course, so the courses bond
	# the way a real wall does instead of stacking four separate columns.
	const REACH := 2.0 * LONG          # 160: half the outer span
	var placed: int = 0
	var refused: int = 0

	for course: int in courses:
		_builder.held_color = palette[course % palette.size()]
		var swap: bool = course % 2 == 1

		for side: int in 4:
			var full: bool = (side < 2) != swap
			var offset: float = REACH - SHORT * 0.5    # 140
			for n: int in (4 if full else 3):
				var along: float
				var target: Vector3
				if full:
					along = -1.5 * LONG + n * LONG     # -120 -40 40 120
				else:
					along = -LONG + n * LONG           # -80 0 80

				match side:
					0:
						target = Vector3(along, 0.0, -offset)
						_builder.held_rotation = 0
					1:
						target = Vector3(along, 0.0, offset)
						_builder.held_rotation = 0
					2:
						target = Vector3(-offset, 0.0, along)
						_builder.held_rotation = 1
					_:
						target = Vector3(offset, 0.0, along)
						_builder.held_rotation = 1

				# Aim straight down from well above, the way a cursor would.
				_builder.update_preview(
					target + Vector3(0.0, 2000.0, 0.0), Vector3.DOWN)
				if _builder.place() != 0:
					placed += 1
				else:
					refused += 1

	# Collision has to be shown firing, not merely never asked. Every brick
	# above sat on a clear column, so nothing was refused; put one exactly
	# where another already is and it must be.
	var overlap_refused: bool = false
	var sample: BrickWorld.Brick = null
	for brick: Variant in _world.bricks():
		sample = brick
		break
	if sample != null:
		var cells: Array[Vector3i] = _builder._cells_for(
			_library.mesh_for(sample.part_id), sample.transform)
		overlap_refused = _builder.lattice.collides(cells)

	print("autobuild placed=%d refused=%d cells=%d overlap_detected=%s" % [
		placed, refused, _builder.lattice.occupied_cells(), overlap_refused])


## Fill a cube with bricks to find where the frame time goes.
##
## Deliberately uses a handful of part types rather than one: a single part
## would collapse into one batch and flatter the numbers, whereas a real
## model spreads over dozens.
func _build_stress(target: int) -> int:
	var kinds: PackedStringArray = PackedStringArray([
		"3001", "3003", "3004", "3005", "3020", "3024", "3068b", "3062b"])
	var palette: PackedInt32Array = PackedInt32Array([
		4, 14, 2, 1, 26, 25, 15, 0, 70, 72, 191, 308])

	# A roughly cubic arrangement on the real lattice, so the spatial
	# spread matches what a big model actually looks like.
	var side: int = int(ceil(pow(float(target), 1.0 / 3.0)))
	var placed: int = 0
	var n: int = 0
	for y: int in side:
		for z: int in side:
			for x: int in side:
				if placed >= target:
					return placed
				var at := Transform3D(Basis.IDENTITY,
					Vector3(x * 80.0, y * 24.0, z * 40.0))
				if _world.add_brick(
						kinds[n % kinds.size()], palette[(n / 7) % palette.size()], at) != 0:
					placed += 1
				n += 1
	return placed


## Something to build on. A model opened from a file floats in space
## otherwise, and there is nothing for a first brick to rest against.
## Lay more ground if what is built has outgrown it.
##
## Only when it has: re-laying on every change would rebuild the plates
## each time a brick is put down by hand, for nothing.
func _ground_for_the_model(and_frame: bool = false) -> void:
	var box: AABB = _built_bounds()
	if box.size.length_squared() <= 0.0:
		return
	if and_frame:
		_camera.frame(box)
	var model: AABB = _model_bounds()
	_floor.follow(model)
	if _floor.covers(model):
		return
	_lay_baseplate()


## Put the model's floor down under it (FloorLayer): the baseplate it
## stands on, the grid floor, or nothing, as its floor says.
##
## At zero, not a plate below it. A part's origin sits at the top of its
## body, and bricks rest with their undersides on the plane that
## GROUND_CELL names — which is zero. Laying the baseplate at -8 put its
## surface a full plate under them, so everything on it floated three
## millimetres clear of the studs it was supposed to be on. Centred on the
## model and tiled to cover it: a set-sized model on one plate ran off the
## edge and hung in the air, which reads as the model being broken.
func _lay_baseplate() -> void:
	if _floor == null:
		return
	_floor.lay(_model_bounds())


## What is built, without the floor, and nothing when nothing is.
func _model_bounds() -> AABB:
	var bounds := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var box: AABB = brick.transform * part.bounds
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## Change what the model stands on (View, Floor; the properties), as one
## step of the history. Never moves what is built.
func choose_floor(chosen: ModelFloor) -> void:
	if _floor == null or _store.read_only:
		return
	if _floor.choose(chosen):
		_on_model_edited()
		_bar.say("Now on %s." % chosen.words().to_lower())


## The design's baseplate is made part of the model when the design is
## done: while it is being designed, the plate is the floor, and the
## pictures the designer judges by are of the model and not a green square.
var _plate_after_design: bool = false


## What a design said it stands on (Assistant.floor_chosen): no floor for a
## vehicle, a baseplate in its ground's colour for a scene, made part of
## the build. Said in the chat, and the person can change it.
func _on_floor_chosen(choice: Dictionary) -> void:
	var chosen: ModelFloor = _store.model_floor.copy()
	chosen.kind = str(choice.get("kind", ModelFloor.BASEPLATE))
	if chosen.is_plate():
		if int(choice.get("colour", -1)) >= 0:
			chosen.colour = int(choice["colour"])
		# The least plate the model stands on with a stud to spare: one of
		# the three sizes when it fits one, in eights otherwise.
		var box: AABB = _model_bounds()
		var wide: int = int(ceil(box.size.x / BrickLattice.STUD)) + 2
		var deep: int = int(ceil(box.size.z / BrickLattice.STUD)) + 2
		var side: int = -1
		for studs: int in ModelFloor.SIZES:
			if side < 0 and studs >= maxi(wide, deep):
				side = studs
		chosen.across = side if side > 0 else wide
		chosen.deep = side if side > 0 else deep
	var was_own: bool = _floor.has_own_plate()
	var changed: bool = not chosen.same_as(_store.model_floor)
	if changed:
		_floor.choose(chosen)
		_on_model_edited()
	if chosen.is_plate() and bool(choice.get("part", false)) and not was_own:
		changed = changed or not _plate_after_design
		if _assistant.is_busy():
			_plate_after_design = true
		else:
			floor_part_of_model(true)
	# Once, not at every revision of the design.
	if changed and _chat != null:
		_chat.note(("It stands on %s, part of the build." % chosen.words().to_lower())
			if chosen.is_plate() and bool(choice.get("part", false))
			else "It stands on %s. View, Floor changes it." % chosen.words().to_lower())


## Make the baseplate part of the model, or the floor again. One step of
## the history either way, and nothing moves.
func floor_part_of_model(part: bool) -> void:
	if _floor == null or _store.read_only:
		return
	var plates: int = _floor.adopt() if part else _floor.release()
	if plates == 0:
		return
	_on_model_edited()
	_bar.say(("The baseplate is part of the model: counted, saved and step 1 of the booklet."
		if part else "The baseplate is the floor again: not counted, not saved."))


## Counted once. Walking 29,479 entries on every rebuild would be work
## done for a number that cannot change while the app is running.
var _placeable: int = -1


func _placeable_parts() -> int:
	if _placeable >= 0:
		return _placeable
	_placeable = 0
	for id: String in _library.ids():
		var info: PartLibrary.PartInfo = _library.parts[id]
		if not info.is_redirect() and info.reachable:
			_placeable += 1
	return _placeable


## The batches and triangles the world was last drawn with.
var _drawn: Array[int] = [0, 0]
## The model's pieces as the parts list counts them, and the change they
## were counted at: the world's revision, the scenery, the undo history (a
## part moved out of a hose's sub-model changes neither of the others).
var _pieces: int = 0
var _pieces_at: Array = []


func _on_rebuilt(brick_count: int, batch_count: int, triangle_count: int) -> void:
	_drawn = [batch_count, triangle_count]
	if _counts == null:
		return
	# The count of parts you can place, which is not the size of the
	# catalogue: 1,160 of its entries are redirect stubs forwarding to
	# whatever replaced them. The bin says 28,319 and this said 29,479,
	# and two numbers for the same thing on one screen is how the app
	# looked like it was hiding parts.
	# What a person building wants to know is how many bricks and whether
	# it stands. Batches, triangles, the catalogue and the frame rate are
	# for whoever is working on the renderer, and were the first line
	# every visitor read; they come back with --stats.
	#
	# The model's own bricks, not the baseplate under them. Counted with
	# it, the line over the example car said 62 bricks and 149 g while the
	# toolbar said it opened 61 and the parts list 61 pieces, 48 g; and an
	# empty baseplate was "1 brick · stands up · 101 g".
	var scenery: Dictionary = _store.scenery if _store != null else {}
	var own: int = maxi(brick_count - scenery.size(), 0)
	# And a hose laid along a bend as the one hose the parts list counts,
	# not its thirty rings. Counted once a change: it is 15 ms over the
	# 9,429 parts of Orthanc, and the build animation redraws every frame.
	if own > 0 and _library != null:
		var change: Array = [_world.revision, scenery.size(),
			_builder.history_depth() if _builder != null else 0]
		if change != _pieces_at:
			_pieces_at = change
			_pieces = Inventory.pieces_in(_world, _library, scenery)
		own = _pieces
	if _stats_shown:
		_counts_base = "%s bricks · %d batches · %s triangles · %s parts" % [
			_comma(brick_count), batch_count, _comma(triangle_count),
			_comma(_placeable_parts())]
	elif own == 0:
		_counts_base = "Nothing built yet: pick a part, then click the %s" % (
			"baseplate" if _store != null and _store.model_floor.is_plate() else "ground")
	else:
		_counts_base = "%s brick%s" % [_comma(own), "" if own == 1 else "s"]
	_weigh()
	# Nothing to stand up, whenever the last check was; and the first
	# brick placed is weighed at once rather than up to a second later.
	if own == 0 and not _stats_shown:
		_stability_text = ""
		_stability_at = 0


## Whether the model stands, for the counts line.
##
## Stability is cheap but not free, and a rebuild can fire several times
## while a model is being dropped in. Once a second is plenty for something
## a person reads — and the last change of a burst is weighed too, from
## _process, rather than left out because it came inside the second. Only
## when the model changed, not when what is drawn of it did: the build
## animation rebuilt every frame and this ran each time, 4.4 s on the
## Falcon Heavy's 4,242 parts.
##
## And on a worker for a big model: a quarter of a second on the desktop for
## the 4,242-part Falcon, several times that in a browser, after every
## change. The worker reads copies of the world and the lattice, made here
## in a few milliseconds, and the library holds new parts aside meanwhile.
func _weigh() -> void:
	if _stability == null or _world == null or _counts == null or _weighing \
			or _world.revision == _stability_revision or _world.is_drawing_held():
		return
	var now: int = Time.get_ticks_msec()
	if now - _stability_at <= 900:
		return
	_stability_at = now
	_stability_revision = _world.revision
	var scenery: Dictionary = _store.scenery if _store != null else {}
	if _world.brick_count() <= scenery.size() and not _stats_shown:
		_stability_text = ""
		return
	var report: Stability.Report
	# The baseplate is the floor, not the model: whether it tips is asked
	# of what stands on it.
	_stability.floor_ids = scenery
	if _world.brick_count() < WEIGH_OFF_THREAD_FROM or OS.has_feature("nothreads"):
		report = _stability.check(_world)
	else:
		_weighing = true
		var judge := Stability.new()
		judge.library = _library
		judge.floor_ids = scenery.duplicate()
		judge.lattice = _builder.lattice.copy_for_reading()
		var still: BrickWorld = _world.copy_for_reading()
		var weighed: Array = [null]
		_library.begin_reading()
		var task: int = WorkerThreadPool.add_task(func() -> void:
			weighed[0] = judge.check(still), false, "weigh the model")
		_library.reading_in(task)
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		_library.end_reading(task)
		still.free()
		_weighing = false
		report = weighed[0]
		if report == null:
			return
	for id: int in scenery:
		var plate: BrickWorld.Brick = _world.get_brick(id)
		var info: PartLibrary.PartInfo = \
			_library.parts.get(plate.part_id) if plate != null else null
		if info != null:
			report.total_grams -= Stability.grams(info)
	_stability_text = report.summary()


## Which way a key zooms: 1 in, -1 out, 0 when it is not a zoom key.
static func _zoom_key(key: InputEventKey) -> int:
	if key.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_PAGEUP] \
			or key.unicode == "+".unicode_at(0):
		return 1
	if key.keycode in [KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN] \
			or key.unicode == "-".unicode_at(0):
		return -1
	return 0


## How long the view keys have been held, so a tap is one step and only
## a key kept down goes on moving.
var _held_for: float = 0.0
## A tap is shorter than this; past it, the view moves while held.
const HOLD_AFTER := 0.22


## Keep moving the view while a view key is held: + or - zooming, arrows
## turning, shift and arrows sliding — but never while someone is typing,
## and the arrows only when a selection or the booklet is not using them.
func _steer_from_keys(delta: float) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit or _camera == null or _gated():
		_held_for = 0.0
		return
	var free: bool = _builder.selection.is_empty()
	var zoom: int = 0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS) \
			or Input.is_key_pressed(KEY_KP_ADD) or (free and Input.is_key_pressed(KEY_PAGEUP)):
		zoom += 1
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT) \
			or (free and Input.is_key_pressed(KEY_PAGEDOWN)):
		zoom -= 1
	var arrows := Vector2.ZERO
	var wasd := Vector2.ZERO
	var modified: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) \
		or Input.is_key_pressed(KEY_ALT)
	if free and not _steps.is_playing_back():
		arrows = Vector2(
			float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN)))
		if not modified:
			wasd = Vector2(
				float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
				float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S)))
	if zoom == 0 and arrows == Vector2.ZERO and wasd == Vector2.ZERO:
		_held_for = 0.0
		return
	_held_for += delta
	if _held_for < HOLD_AFTER:
		return
	var sliding: bool = Input.is_key_pressed(KEY_SHIFT)
	_camera.key_hold(delta, zoom, Vector2.ZERO if sliding else arrows,
		(arrows if sliding else Vector2.ZERO) + wasd)


## Frames whose own work — scripts, coroutines, deferred calls, not drawing —
## took over SLOW_FRAME_MS, as [when in ticks, ms of work, ms waiting for a
## picture to be read back, what the app was doing: the tool Claude called
## and the assistant's last step], the latest SLOW_FRAMES of them. Kept on the web
## only, where the page reads them. Timed by OwnFrames, drawn or not; the
## wait for a picture (ModelShot.gpu_wait_us) is the graphics card's time,
## not this app's, and is said apart.
var _slow_frames: Array = []
var _doing: String = ""
const SLOW_FRAME_MS := 50.0
const SLOW_FRAMES := 200


func _watch_own_frames() -> void:
	if not OS.has_feature("web"):
		return
	_assistant.progress.connect(func(note: String) -> void:
		_doing = note)
	if _connector != null and _connector.rpc != null:
		_connector.rpc.asked.connect(func(tool: String) -> void:
			_doing = tool)
	var frames := OwnFrames.new()
	add_child(frames)
	frames.timed.connect(func(spent_us: int) -> void:
		var spent: float = spent_us / 1000.0
		var waited: float = ModelShot.gpu_wait_us / 1000.0
		ModelShot.gpu_wait_us = 0
		if spent > SLOW_FRAME_MS:
			# What the status bar says it is busy with, if anything: the
			# slow frames of a timeline or a booklet say which part of it.
			var doing: String = Working.current().line() if Working.is_busy() else _doing
			_slow_frames.append([Time.get_ticks_msec(),
				roundi(maxf(spent - waited, 0.0)), roundi(waited), doing])
			if _slow_frames.size() > SLOW_FRAMES:
				_slow_frames = _slow_frames.slice(-SLOW_FRAMES))


## Whether nobody can see the model: the browser tab out of view, or the
## window minimised.
##
## Claude designs from claude.ai with the Brickworks tab out of view, and the
## connector keeps the app running there (ClaudeConnector._watch_the_page).
## It went on drawing the model every frame for nobody, and went on to play
## the build animation for nobody, so when the person looked the model was
## still going up (2026-10-11). Out of view now nothing 3D is drawn, and a
## design arrives whole.
var _out_of_view: bool = false


func _watch_view() -> void:
	var away: bool = _nobody_looking()
	if away == _out_of_view:
		return
	_out_of_view = away
	get_viewport().disable_3d = away
	FramePace.unwatched = away
	if _verbs != null:
		_verbs.out_of_view = away
	if away and _playback != null and _playback.is_playing():
		_playback.stop()


static func _nobody_looking() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("document.hidden", true))
	return DisplayServer.get_name() != "headless" \
		and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED


func _process(_delta: float) -> void:
	_watch_view()
	_steer_from_keys(_delta)
	if not _viewing.is_empty():
		_view_hover()
	else:
		_select_hover()
	if _cursors != null:
		_cursors.show_for(_cursor_state())
	# A box whose ending went somewhere else.
	#
	# Letting go over a button hands the release to that button, which
	# handles it and stops it there — so the guard above never runs and
	# the box is still being drawn with nothing holding it. The camera
	# keeps the same watch over its own drags, after the same bug.
	# Only a box this handler saw begin.
	#
	# Asking the marquee alone was enough to select an entire model on
	# startup: a motion event arriving with a stale left-button mask
	# puts it into drawing without any press ever reaching here, and the
	# watchdog then dutifully finished a box nobody drew. Everything
	# selected, "took 50" in the bar, and one keypress from deleting the
	# lot.
	if _box_began and _marquee != null and _marquee.is_drawing() \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_box(Input.is_key_pressed(KEY_SHIFT))
	# And a dragged part whose release went somewhere this never heard.
	if (_dragging_part or _press_brick != 0 or not _left_nav.is_empty() or _pending_left) \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and not DisplayServer.is_touchscreen_available():
		_press_brick = 0
		_pending_left = false
		if not _left_nav.is_empty():
			_left_nav = ""
			_camera.end_drag(MOUSE_BUTTON_LEFT)
		if _dragging_part:
			_drop_dragged(get_viewport().get_mouse_position())
	if _store != null:
		_store.tick()
	_weigh()
	_tell_page()
	if _counts == null:
		return
	# Frame time belongs beside the counts: the whole point of batching is
	# that the counts can grow without it moving.
	# The counts line is rebuilt from its parts rather than patched, so
	# repeated frames cannot accrete suffixes.
	var line: String = _counts_base
	if _stats_shown:
		line += " · fps %.0f" % Engine.get_frames_per_second()
	if not _stability_text.is_empty():
		line += " · " + _stability_text
	_counts.text = line
	# No empty pill before the first count.
	_counts.self_modulate.a = 0.0 if line.is_empty() else 1.0


## The palette the number keys reach for: a readable spread rather than
## the first twelve codes, which are mostly greys and browns.
const QUICK_COLORS: Array[int] = [4, 14, 2, 1, 26, 25, 15, 0, 70, 191]

## Parts the bracket keys cycle. A starter bin, not the catalogue — the
## catalogue has 24,731 entries and needs a search box, which is next.
const QUICK_PARTS: Array[String] = [
	"3005", "3004", "3622", "3009", "3003", "3001", "3007",
	"3024", "3023", "3020", "3031", "3068b", "3040b", "3298", "4070", "3062b"]

var _part_index: int = 5
var _color_index: int = 0


## How long a finger must stay down to mean "take this one off"
## rather than "put one here", in milliseconds.
const HOLD_MS := 480


var _touch_down_at: int = 0
var _touch_index: int = -1

## A left press on a part with the Select tool, not yet a click or a drag:
## the part, where the press was, and whether it copies (Ctrl).
var _press_brick: int = 0
var _press_at: Vector2 = Vector2.ZERO
var _press_copies: bool = false
## A part (with its selection) picked up by a drag and following it.
var _dragging_part: bool = false
## A left press that is not yet a click or a drag. A drag from it moves the
## view ("turn", "slide", "zoom") or draws a box ("box"); "" for a finger,
## whose drags are the camera's. Nothing is placed or selected until it
## comes up without having moved. Alt: a click takes the part into hand.
## Right: Ctrl-click on a Mac, which is a right click.
var _pending_left: bool = false
var _pending_verb: String = ""
var _pending_alt: bool = false
var _pending_right: bool = false
## A finger's press that moved: the camera turned the view, and the
## release is nobody's click.
var _left_spent: bool = false
## A left drag lent to the view, while it lasts: its verb.
var _left_nav: String = ""
## How far a press may move and still be a click, in interface units.
const DRAG_SLOP := 5.0


## The part under the pointer, for a key that acts on it: none when the
## pointer is over a panel, which a key must not reach through.
func _brick_under_pointer() -> int:
	var at: Vector2 = get_viewport().get_mouse_position()
	if _verbs == null or _over_interface(at):
		return 0
	return _verbs.brick_at(at)


## What a left drag from this press does, by the tool and the keys held:
##
##   a view tool (O, H, Z)     its own: turn, slide or zoom
##   Space held                slide, as a hand tool does everywhere
##   Alt                       turn; Alt-Shift slides, Alt-Ctrl (Cmd) zooms
##   Ctrl (Cmd on a Mac)       a box, which selects what it catches
##   anything else             turn, and with Shift slide (ViewPrefs)
##
## "" for a finger: its drags belong to the camera, which turns the view
## with them already.
func _left_drag_verb(button: InputEventMouseButton) -> String:
	if button.device == InputEvent.DEVICE_ID_EMULATION:
		return ""
	var held: bool = button.meta_pressed if EditVerbs.on_mac() \
		else (button.ctrl_pressed or button.meta_pressed)
	if _verbs != null and _verbs.is_view_tool():
		var own: String = _verbs.view_verb()
		if button.shift_pressed and own != "zoom":
			return "slide" if own == "turn" else "turn"
		return own
	if Input.is_key_pressed(KEY_SPACE):
		return "slide"
	if button.alt_pressed:
		if held:
			return "zoom"
		return "slide" if button.shift_pressed else "turn"
	if held:
		return "box"
	return ViewPrefs.drag_verb(MOUSE_BUTTON_LEFT, button.shift_pressed)


## The left button lent to the view until it comes up.
func _start_left_nav(verb: String, at: Vector2) -> void:
	_pending_left = false
	_left_nav = verb
	_builder.hide_preview()
	_camera.begin_drag(MOUSE_BUTTON_LEFT, at, verb)


## Ctrl and the left button on a Mac, which every Mac program reads as the
## right button — a trackpad's one button needs it.
func _mac_right_click(button: InputEventMouseButton) -> bool:
	return EditVerbs.on_mac() and button.ctrl_pressed and not button.meta_pressed \
		and not button.alt_pressed


## A right click: lets go of what is in hand and goes back to Select, as
## Studio's does. It takes nothing off the model (Delete does, or the Delete
## tool) — the right button is for looking.
func _right_click(at: Vector2 = Vector2(-1, -1)) -> void:
	# At rest, on a part: its menu, as Studio and Mecabricks have one. The
	# part is selected first unless it is already in the selection, which
	# the menu then acts on whole.
	if _verbs != null and _shell != null and at.x >= 0.0 and _verbs.mode == "select" \
			and not _builder.is_carrying() and not _builder.is_holding_figure():
		var brick_id: int = _verbs.brick_at(at)
		if brick_id != 0 and not _builder.is_locked(brick_id):
			if not _builder.selection.has(brick_id):
				_builder.select_brick(brick_id, false)
			_builder.hide_preview()
			_shell.open_context(at)
			return
	if _verbs != null:
		if _builder.is_carrying():
			_verbs.put_away()
		_builder.drop_figure()
		_verbs.set_mode("select")
	_refresh_preview()


## The end of a drag that carried a part: down where the pointer is, if it
## fits there, and back where it came from (or the copy gone) if not.
func _drop_dragged(at: Vector2) -> void:
	_dragging_part = false
	if not _builder.is_carrying():
		return
	_aim_at(at)
	if _builder.place() == 0:
		_verbs.put_away()
		_bar.say("no room there — put back where it was")
	_refresh_preview(at)


func _unhandled_input(event: InputEvent) -> void:
	# A shared model's viewer only looks: none of what follows — placing,
	# picking up, a finger held down to take a part off — is reachable.
	if not _viewing.is_empty():
		_view_input(event)
		return
	# The ruler, while it is out, has the left button and the pointer.
	if _measure != null and _measure.takes(event):
		_builder.hide_preview()
		return
	if _flex != null and _flex.takes(event):
		_builder.hide_preview()
		return
	# Touch handles only what a mouse has no gesture for: holding a
	# finger down to take a brick off, which is what a second button
	# would have been. Placing is left to the click that emulation
	# raises from the same tap, because emulation has to stay on — no
	# text field in the app can be focused without it.
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _over_panel_at(touch.position):
				return
			# The first finger only. A second is a pinch, which belongs
			# to the camera and must not remove anything.
			if _touch_index == -1:
				_touch_index = touch.index
				_touch_down_at = Time.get_ticks_msec()
			return

		if touch.index != _touch_index:
			return
		# Cleared wherever the finger comes up, including over a panel.
		#
		# The panel test used to come first and return, so a finger that
		# started on the model and ended on a panel left this set and
		# left its press time behind — and the next tap, measured
		# against a timestamp from minutes ago, read as a hold and took
		# a brick off instead of putting one on.
		_touch_index = -1
		if _over_panel_at(touch.position):
			return
		# The camera saw the same finger and knows whether it travelled.
		# A gesture that moved has already asked for its click to be
		# swallowed, and is not a hold either.
		if not _camera.last_touch_was_a_tap():
			return
		if Time.get_ticks_msec() - _touch_down_at < HOLD_MS:
			return

		_builder.update_preview(
			_camera.ray_origin(touch.position),
			_camera.ray_normal(touch.position))
		_builder.remove_hovered()
		_builder.hide_preview()
		# The hold raises a click too, and it would put back what was
		# just taken off.
		_camera.swallow_next_click()
		return

	if event is InputEventMouseMotion:
		var moved: InputEventMouseMotion = event
		# A left drag that began on a part, with the Select tool: past a
		# few pixels it picks the part up (Ctrl: a copy of it), and from
		# then on the part follows the pointer until the button comes up.
		if _press_brick != 0 and not _dragging_part \
				and (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
				and moved.position.distance_to(_press_at) > DRAG_SLOP:
			_dragging_part = _verbs.drag_start(_press_brick, _press_copies)
			_press_brick = 0
		if _dragging_part:
			_refresh_preview(moved.position)
			return
		# A left press that moves is a drag, never a placement: past a few
		# pixels it turns or slides the view (the camera follows the
		# pointer from here), or with Ctrl draws a box. Whatever is in hand
		# stays in hand, out of sight until the button comes up.
		if _pending_left and (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
				and moved.position.distance_to(_press_at) > DRAG_SLOP:
			_pending_left = false
			match _pending_verb:
				"":
					_left_spent = true
				"box":
					_marquee.begin(_press_at)
					_box_began = true
				_:
					_start_left_nav(_pending_verb, _press_at)
		if not _left_nav.is_empty():
			_builder.hide_preview()
			return
		# Drawing a box, which is not aiming the ghost. Shift decides
		# whether what it catches is added to the selection or replaces it.
		if (moved.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not _box_dropped \
				and _box_began:
			if _marquee.drag_to(moved.position):
				_builder.hide_preview()
				return
		if _over_panel_at(moved.position):
			_builder.hide_preview()
			return
		_refresh_preview(moved.position)
		return

	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	# Alt with any button but the left is the system's. (Alt with the left:
	# a click takes the part into hand, a drag turns the view — below.)
	if button.alt_pressed and button.button_index != MOUSE_BUTTON_LEFT:
		return
	# A press that lands on a panel belongs to the panel. A release does
	# not always: if a box is being drawn, that drag started out here
	# and owns its own ending, wherever the pointer has got to by then.
	#
	# Dropping it lost the selection without saying so. Drag a box
	# rightwards and let go over the parts bin — which is where the
	# pointer naturally ends up — and the release never arrived, so
	# nothing was ever selected. The rectangle sat there until the next
	# press cleared it. You drew a box round six bricks and got
	# nothing, with no way to tell that from having missed them.
	#
	# Asked of the event's own position, not of the pointer.
	#
	# This used to ask where the system says the mouse is now, which
	# during a drag is not where the button was let go — and on the web,
	# where the pointer can be locked or a frame behind, is not reliably
	# anywhere in particular. An event should be judged by where it says
	# it happened. The helper that asked the other way is gone rather
	# than merely unused, because it is an easy thing to reach for
	# again.
	var ending_a_box: bool = (button.button_index == MOUSE_BUTTON_LEFT
		and not button.pressed and _marquee.is_drawing())
	if _over_panel_at(button.position) and not ending_a_box:
		return

	# The right button acts on release, not on press.
	#
	# Right-drag turns the model — which it has to, since a trackpad has
	# no middle button and orbiting is not an advanced feature. Acting
	# on the press would take a brick off at the start of every turn.
	# The camera decides which it was by whether the pointer moved, and
	# says so through swallowing_click.
	if button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			return
		if _camera.turned_rather_than_clicked():
			return
		_right_click(button.position)
		return

	if button.button_index != MOUSE_BUTTON_LEFT:
		return

	# A left drag lent to the view, let go: nothing is placed, picked or
	# selected by it, and whatever is in hand is still in hand. The Zoom
	# tool's click without a drag is a step in (Shift: out) at the pointer.
	if not _left_nav.is_empty() and not button.pressed:
		_left_nav = ""
		_camera.end_drag(MOUSE_BUTTON_LEFT)
		if _verbs != null and _verbs.mode == "zoom" \
				and button.position.distance_to(_press_at) <= DRAG_SLOP:
			_camera.zoom_by_drag(-40.0 if not button.shift_pressed else 40.0, button.position)
		_refresh_preview(button.position)
		return
	# A part being dragged, let go of where the drag ends: put down there
	# if it fits, and back where it was if not.
	if _dragging_part and not button.pressed:
		_drop_dragged(button.position)
		return
	# A click on a part with the Select tool that never became a drag.
	if _press_brick != 0 and not button.pressed:
		_press_brick = 0
		if not _camera.swallowing_click():
			_verbs.click(button.position, button.shift_pressed or button.ctrl_pressed
				or button.meta_pressed)
		return

	# Every other left press is decided by whether the pointer moves before
	# it comes up. A drag moves the view (or with Ctrl draws a box) and
	# places nothing; a click places, selects, or does what the tool does.
	if button.pressed:
		_box_dropped = false
		_box_began = false
		_left_spent = false
		_press_at = button.position
		var verb: String = _left_drag_verb(button)
		# A view tool, or Space held: the press is the view's at once.
		if not verb.is_empty() and verb != "box" and _verbs != null \
				and (_verbs.is_view_tool() or Input.is_key_pressed(KEY_SPACE)):
			_start_left_nav(verb, button.position)
			return
		# Ctrl-click on a Mac is a right click: a click lets go of what
		# is in hand, a drag turns the view, as the right button's do.
		if _mac_right_click(button):
			_pending_left = true
			_pending_verb = "turn"
			_pending_alt = false
			_pending_right = true
			return
		# With the Select tool a press on a part is the start of a click
		# that selects it or a drag that moves it. (Not while anything is
		# in hand — a carried group or a minifigure — whose click puts it
		# down.)
		if _verbs != null and _verbs.mode == "select" and not _verbs.shows_ghost() \
				and not button.shift_pressed and not button.double_click \
				and not button.alt_pressed:
			var under: int = _verbs.brick_at(button.position)
			if under != 0:
				_press_brick = under
				_press_copies = button.ctrl_pressed or button.meta_pressed
				return
		_pending_left = true
		_pending_verb = verb
		_pending_alt = button.alt_pressed
		_pending_right = false
		if button.shift_pressed and button.double_click:
			_aim_at(button.position)
			_builder.select_alike()
		# A double-click with the Select tool edits inside the sub-assembly
		# under the pointer; the click that ends it picks a part inside.
		elif button.double_click and _verbs != null and _verbs.mode == "select" \
				and _verbs.assemblies != null:
			var unit: Variant = _verbs.assemblies.unit_path_of(_verbs.brick_at(button.position))
			if unit != null and not str(unit).is_empty():
				_verbs.assemblies.enter(str(unit))
				_bar.say("editing %s — Esc when done" % Assemblies.label(str(unit)))
		return

	# A drag is never a placement.
	#
	# This is the gesture everyone tries first, because it is how every
	# other 3D viewport turns the model — and here it once placed a brick
	# wherever the pointer happened to stop, and then drew a box. A drag
	# turns the view now (with Ctrl, draws a box); only a click acts.
	if _marquee.is_drawing():
		_finish_box(button.shift_pressed)
		return
	_marquee.finish()
	_box_began = false
	if _box_dropped:
		# The end of a box Escape already threw away, not a click.
		_box_dropped = false
		return
	if _left_spent:
		# A finger that moved: the camera turned the view with it.
		_left_spent = false
		return
	var was_pending: bool = _pending_left
	_pending_left = false
	if was_pending and _pending_right:
		_right_click(_press_at)
		return
	# Alt and a click takes the part under the pointer into hand, in its
	# colour: Studio's eyedropper.
	if was_pending and _pending_alt:
		if _verbs != null and _verbs.pick_at(button.position):
			_refresh_preview(button.position)
		return

	# A tool other than Build: the click is the tool's (EditVerbs.click).
	if _verbs != null and not _verbs.shows_ghost():
		if _playback != null and _playback.is_playing():
			_playback.stop()
			return
		if not _camera.swallowing_click():
			_verbs.click(button.position, button.shift_pressed)
		return

	if button.shift_pressed:
		_aim_at(button.position)
		_builder.toggle_hovered()
		return

	# Placing goes on the release, not the press.
	#
	# A finger raises an emulated press the instant it lands, so placing
	# on the press dropped a brick before the finger had moved — and
	# then the drag turned the model, leaving the brick wherever the
	# finger first touched. Waiting for the release gives the camera
	# time to see the drag and ask for the click to be thrown away.

	if _playback != null and _playback.is_playing():
		# Reaching for the model ends the animation, and this click is
		# what ended it rather than a placement.
		_playback.stop()
		return
	# A finger that turned the model raises a click on release just as a
	# tap does; without this a drag leaves a brick wherever it ended.
	if _camera.swallowing_click():
		return

	# Aimed before it is placed.
	#
	# A mouse moves before it clicks, so the ghost is already where the
	# pointer is and placing first was harmless. A finger does not: it
	# arrives, and the only position anything knows is wherever the
	# pointer was last left. So every tap placed its brick where the
	# previous tap had been.
	_aim_at(button.position)
	_builder.place()
	_refresh_preview()


## Where a brick lands on the screen, as a rectangle.
##
## Its eight corners projected and bounded, which is close enough for
## deciding whether a box covers it and far cheaper than anything
## exact. A corner behind the camera projects to nonsense, so a brick
## with any corner behind it is left out rather than guessed at.
func _brick_on_screen(brick: BrickWorld.Brick) -> Variant:
	if _store != null and _store.scenery.has(brick.id):
		return null
	# Nor what is hidden: a box drawn over a hidden roof takes what is
	# under it.
	if brick.hidden:
		return null
	var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	if part == null:
		return null
	var box: AABB = part.bounds
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n: int in 8:
		var corner: Vector3 = brick.transform * (box.position + Vector3(
			box.size.x if n & 1 else 0.0,
			box.size.y if n & 2 else 0.0,
			box.size.z if n & 4 else 0.0))
		if _camera.is_position_behind(corner):
			return null
		var at: Vector2 = _camera.unproject_position(corner)
		lo = Vector2(minf(lo.x, at.x), minf(lo.y, at.y))
		hi = Vector2(maxf(hi.x, at.x), maxf(hi.y, at.y))
	return Rect2(lo, hi - lo)


## Point the ghost at a place on the screen, whatever the pointer is
## doing. A finger raises no motion to do it for us.
func _aim_at(point: Vector2) -> void:
	_builder.update_preview(
		_camera.ray_origin(point),
		_camera.ray_normal(point))


## Centre a panel, no larger than it wants and no larger than the room
## there is.
##
## The margin is what keeps the way out reachable: a dialog that runs to
## the edges has its close button under the notch, the rounded corner,
## or nothing at all.
func _inset(panel: Control, wants_wide: float, wants_tall: float) -> void:
	if panel == null:
		return
	const MARGIN := 24.0
	var room: Vector2 = get_viewport().get_visible_rect().size
	var wide: float = minf(wants_wide, room.x - MARGIN * 2.0)
	var tall: float = minf(wants_tall, room.y - MARGIN * 2.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -wide * 0.5
	panel.offset_right = wide * 0.5
	panel.offset_top = -tall * 0.5
	panel.offset_bottom = tall * 0.5


## One of the round buttons a finger can reach.
func _on_touch_tool(what: String) -> void:
	match what:
		"rotate":
			_builder.rotate_held(1)
			_refresh_preview()
			_bar.say("turned a quarter")
		"tip":
			_builder.tip_held(1)
			_refresh_preview()
			_bar.say("on its %s" % _builder.held_face)
		"undo":
			if _builder.undo():
				_refresh_preview()
				_on_model_edited()
			else:
				_bar.say("nothing to undo")
		"redo":
			if _builder.redo():
				_refresh_preview()
				_on_model_edited()
			else:
				_bar.say("nothing to redo")


## A box around everything selected, for framing it.
func _selection_bounds() -> AABB:
	var box := AABB()
	var first: bool = true
	for brick_id: int in _builder.selection:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null:
			continue
		var part: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if part == null:
			continue
		var here: AABB = (brick.transform * part.bounds).abs()
		box = here if first else box.merge(here)
		first = false
	return _built_bounds() if first else box


## Move the selection one stud in a direction named on the screen
## rather than in the world.
##
## Pressing left should move things left as they look, not along
## whichever world axis happens to be called x. The model can be turned
## to any angle, so "left" is worked out from where the camera is
## standing and snapped to the nearest axis of the lattice.
func _nudge(screen_way: Vector3) -> void:
	var basis: Basis = _camera.global_transform.basis
	var world_way: Vector3 = basis * screen_way
	world_way.y = 0.0
	if world_way.length_squared() < 0.0001:
		return
	# The nearest of the four ground directions.
	var axis: Vector3 = (Vector3(signf(world_way.x), 0.0, 0.0)
		if absf(world_way.x) >= absf(world_way.z)
		else Vector3(0.0, 0.0, signf(world_way.z)))
	_nudge_by(Vector3i(axis * _verbs.across_cells()))


func _nudge_by(cells: Vector3i) -> void:
	if _builder.move_selection(cells) > 0:
		_on_model_edited()
	else:
		_bar.say("no room that way")


## True when the cursor is over a panel rather than the model.
##
## Without this, clicking a part in the bin also drops a brick behind it,
## and moving the mouse across the assistant leaves a ghost following the
## cursor over the text.
## Whether a point is over one of the panels rather than the model.
## The existing test asks where the mouse is, which on a touch screen is
## wherever it was last left — usually nowhere near the finger.
## Is this point over something other than the model?
##
## One list, used by both the touch path and the mouse path. They used
## to have a list each and the mouse one was shorter — it did not know
## about the parts list, so with that open the ghost still followed the
## cursor and a click beside the panel dropped a brick into the model
## behind it. Nor about the axis gizmo, whose square swallows clicks
## wherever it sits.
## Take whatever the box caught and put it away.
##
## One function because two callers need it to do the same thing: the
## release that ends the drag, and the watchdog for when that release
## goes somewhere this handler never sees.
func _finish_box(add: bool) -> void:
	_box_began = false
	if not _marquee.is_drawing():
		_marquee.finish()
		return
	var took: int = _builder.select_in(_marquee.box(),
		_brick_on_screen, _marquee.takes_touching(), add)
	_marquee.finish()
	_bar.say("took %d" % took if took > 0 else "nothing in there")


## Whether a point is over the interface, by the interface's own
## reckoning as well as by the list below.
##
## The control under the pointer is what the window itself found there:
## every panel, dialog, popup and button, including the ones added after
## the list was written. The list stays for the overlays that claim the
## whole window while they are up. The drag sheet (Cursors) is under the
## pointer during every drag and is not a panel.
func _over_interface(point: Vector2) -> bool:
	var over: Control = get_viewport().gui_get_hovered_control()
	if over != null and (_cursors == null or not _cursors.is_shield(over)):
		return true
	return _over_panel_at(point)


func _over_panel_at(point: Vector2) -> bool:
	for panel: Control in [_bin_dock, _chat_dock, _bar, _gizmo, _notices]:
		if panel != null and panel.visible \
				and panel.get_global_rect().has_point(point):
			return true
	if _shell != null and _shell.covers(point):
		return true
	if _build_mode != null and _build_mode.covers(point):
		return true
	# These cover the model rather than sitting beside it, so anywhere
	# is over them.
	if _inventory != null and _inventory.is_showing():
		return true
	if _mosaic != null and _mosaic.visible:
		return true
	if _brickify != null and _brickify.visible:
		return true
	if _figures != null and _figures.visible:
		return true
	if _elements != null and _elements.visible:
		return true
	if _render != null and _render.visible:
		return true
	return false


## Aim the ghost brick.
##
## ``at`` is where the pointer actually is for this event. Without it
## the ghost is aimed wherever the system says the mouse is now, which
## during a drag is not where the event happened, and on the web, with
## the pointer locked or a frame behind, is not reliably anywhere. It
## is the same fault that was fixed for deciding whether a click landed
## on a panel, left in the one place that decides what the click is
## aimed AT.
##
## Callers with no event — after an undo, after a key — pass nothing
## and get the live pointer, which for them is right.
func _refresh_preview(at: Vector2 = Vector2.INF) -> void:
	# No part to place while the ruler is out, or with a tool other than
	# Build in hand.
	if (_measure != null and _measure.active) or (_flex != null and _flex.active):
		_builder.hide_preview()
		return
	if _verbs != null and not _verbs.shows_ghost():
		_builder.hide_preview()
		return
	var mouse: Vector2 = at
	if not (mouse.x < INF):
		mouse = get_viewport().get_mouse_position()
	_builder.update_preview(
		_camera.ray_origin(mouse),
		_camera.ray_normal(mouse))


## Aim the ghost where the pointer already is, as a movement there would.
##
## For when what is under a still pointer may have changed: a box let go
## or thrown away, a dialog closed, a panel folded. The ghost was hidden
## for the box, and nothing put it back until the mouse moved — so the
## pointer said there was nothing to click where a click would place.
## Godot replays a motion for the interface (Cursors asks it to), but a
## motion it makes up is marked internal and never reaches any
## _unhandled_input, so this does here what that motion would have.
func _hover_again() -> void:
	if _marquee.is_drawing() or _camera.is_turning() or _camera.is_sliding():
		return
	var at: Vector2 = get_viewport().get_mouse_position()
	if _over_panel_at(at):
		_builder.hide_preview()
		return
	_refresh_preview(at)


## What the pointer should say over the model, from what is true this
## frame. Cursors.choose decides; this only gathers.
func _cursor_state() -> Cursors.Situation:
	# A shared model's viewer: what a left drag does there (turn, Shift
	# slides; _view_input), and grabbing while it does. Never a tool's
	# state: the Orbit tool's once kept the cursor's sheet over the whole
	# window, and the viewer's buttons stopped answering clicks under it.
	if not _viewing.is_empty():
		var looking := Cursors.Situation.new()
		looking.holding_view = _camera.is_dragging()
		looking.shift = Input.is_key_pressed(KEY_SHIFT)
		looking.left_drag = Cursors.VERBS["slide" if looking.shift else "turn"]
		return looking
	var now := Cursors.Situation.new()
	now.holding_view = _camera.is_dragging()
	now.holding_part = _dragging_part
	now.boxing = _marquee != null and _marquee.is_drawing()
	var focused: Control = get_viewport().gui_get_focus_owner()
	var typing: bool = focused is LineEdit or focused is TextEdit
	# Keys typed into a field are words, not the mouse's modifiers.
	now.shift = not typing and Input.is_key_pressed(KEY_SHIFT)
	now.ctrl = not typing and Input.is_key_pressed(
		KEY_META if EditVerbs.on_mac() else KEY_CTRL)
	# Held, C paints whatever comes under the pointer: the key repeats,
	# and each repeat paints what is there.
	now.painting = not typing and Input.is_key_pressed(KEY_C)
	var moment: String = _camera.moment()
	now.moment = "hand" if moment == "slide" else moment
	now.playing = _playback != null and _playback.is_playing()
	now.left_drag = Cursors.VERBS.get(ViewPrefs.drag_verb(MOUSE_BUTTON_LEFT, now.shift), "orbit")
	# The view's: a view tool on, or a key held that lends it the left
	# button — what _left_drag_verb will do with the next press.
	if _verbs != null and _verbs.is_view_tool():
		var own: String = _verbs.view_verb()
		if own == "zoom":
			now.tool = "zoom_out" if now.shift else "zoom_in"
		elif now.shift:
			now.tool = "hand" if own == "turn" else "orbit"
		else:
			now.tool = Cursors.VERBS[own]
	elif not typing and Input.is_key_pressed(KEY_SPACE):
		now.tool = "hand"
	elif not typing and Input.is_key_pressed(KEY_ALT):
		now.tool = "zoom_in" if now.ctrl else ("hand" if now.shift else "orbit")
	if _verbs != null:
		now.mode = _verbs.mode
		now.in_hand = _verbs.shows_ghost()
	now.aimed = _builder.has_preview()
	now.can_place = _builder.can_place()
	now.loading = _library.is_on_its_way(_builder.held_part)
	if not now.in_hand:
		now.over_part = _brick_under_pointer() != 0
	return now


## Escape, before the interface sees it.
##
## On the web a tooltip on the screen took the first press for itself:
## Help clicked, its tooltip up, and Escape did nothing to the Controls
## sheet until the pointer had moved off the button. Every probe passed,
## because no probe leaves a tooltip up. Taken here, ahead of the
## interface; a menu or a dialog that is open still gets it first, being
## a window of its own.
func _input(event: InputEvent) -> void:
	# Where the pointer is, for the viewer's hover: every move, over the
	# model or not, so moving onto the bar lets go of the part.
	if event is InputEventMouseMotion and not _viewing.is_empty():
		_view_pointer = (event as InputEventMouseMotion).position
	var key: InputEventKey = event as InputEventKey
	if key == null or key.keycode != KEY_ESCAPE or not key.pressed or key.echo:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	# Only for what the ladder below closes; anything else that answers
	# Escape for itself (the account panel) still gets it.
	if not _escape_closes_something():
		return
	_unhandled_key_input(event)
	get_viewport().set_input_as_handled()


func _escape_closes_something() -> bool:
	return (_marquee != null and _marquee.is_drawing()) \
		or (_controls != null and _controls.visible) \
		or (_mosaic != null and _mosaic.visible) \
		or (_brickify != null and _brickify.visible) \
		or (_figures != null and _figures.visible) \
		or _builder.is_holding_figure() or _builder.is_carrying() \
		or (_measure != null and _measure.active) \
		or (_elements != null and _elements.visible) \
		or not _builder.selection.is_empty() \
		or (_inventory != null and _inventory.is_showing()) \
		or (_steps != null and _steps.is_playing_back()) \
		or (_build_mode != null and _build_mode.is_open()) \
		or (_verbs != null and _verbs.mode != "select") \
		or (_verbs != null and _verbs.assemblies != null and not _verbs.assemblies.entered.is_empty())


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed():
		return
	# Whoever is pressing keys has stopped watching.
	if _playback != null and _playback.is_playing():
		_playback.stop()
	# A single-letter shortcut must never fire while someone is typing a
	# part name or a brief.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	var key: InputEventKey = event
	# A command's key is that command, as from its menu: timed, and said on
	# the status bar first when it is slow (Shell.attend). Echoes are a key
	# held down, never put off.
	var command: String = _shell.command_for_key(key) \
		if _shell != null and _viewing.is_empty() and not key.echo else ""
	if command.is_empty():
		_key_pressed(key)
	else:
		_shell.attend(command, _key_pressed.bind(key))


func _key_pressed(key: InputEventKey) -> void:
	# Zoom from the keys every viewer answers to: + and -, on the main keys
	# or the keypad, and Page Up and Down. A tap is a wheel notch; holding
	# goes on in _steer_from_keys. "+" is shift and = on most keyboards and
	# a key of its own on others, so the character is asked as well.
	var zoom: int = _zoom_key(key)
	# Page Up and Down raise and lower a selection rather than zoom.
	if key.keycode in [KEY_PAGEUP, KEY_PAGEDOWN] and not _builder.selection.is_empty():
		zoom = 0
	if zoom != 0:
		if not key.echo and not key.ctrl_pressed and not key.meta_pressed:
			_camera.key_zoom(zoom)
		return
	# A shared model's viewer: only the keys that look get past here, and
	# never to the editing verbs or the shell's shortcuts.
	if not _viewing.is_empty():
		if not _looking_key(key):
			return
	elif _verbs != null and _verbs.handle_key(key):
		return
	elif _shell != null and _shell.handle_key(key):
		return
	match key.keycode:
		KEY_F:
			# The selection if there is one, everything with shift —
			# which is what "zoom to fit" means in every tool that has
			# both.
			if key.shift_pressed or _builder.selection.is_empty():
				_camera.frame(_built_bounds())
			else:
				_camera.frame(_selection_bounds())
		KEY_HOME:
			# On the timeline, the start of the build; otherwise the model.
			if _steps.is_playing_back():
				_steps.to_start()
			else:
				_camera.frame(_built_bounds())
		KEY_END:
			if _steps.is_playing_back():
				_steps.to_end()
		KEY_SPACE:
			if _steps.is_playing_back() and not key.echo:
				_steps.toggle_play()
		KEY_6:
			_camera.set_view("bottom")
		KEY_7:
			_camera.set_view("isometric")
		KEY_1, KEY_KP_1: _camera.set_view("front")
		KEY_2, KEY_KP_2: _camera.set_view("back")
		KEY_3, KEY_KP_3: _camera.set_view("left")
		KEY_4, KEY_KP_4: _camera.set_view("right")
		KEY_5, KEY_KP_5: _camera.set_view("top")
		KEY_KP_6: _camera.set_view("bottom")
		KEY_KP_7: _camera.set_view("isometric")
		KEY_0, KEY_KP_0: _camera.set_view("default")
		KEY_KP_PERIOD:
			# Blender's and Mecabricks' key for the selection, framed.
			_camera.frame(_selection_bounds())
		KEY_QUOTELEFT:
			# Straight-on and back (O is the Orbit tool now). A CAD drawing
			# is read square on; a model on a table is seen in perspective.
			_camera.square_on(not _camera.is_square_on())
			_bar.say("square on" if _camera.is_square_on() else "in perspective")
		KEY_R:
			_builder.rotate_held(-1 if key.shift_pressed else 1)
			_refresh_preview()
		KEY_T:
			# Tip the selection over, forwards as you look (Shift: back),
			# or the part in hand onto its next face.
			if not _builder.selection.is_empty() and not _builder.is_carrying():
				_verbs.tip_selection(-1 if key.shift_pressed else 1)
			else:
				_builder.tip_held(-1 if key.shift_pressed else 1)
				_refresh_preview()
		KEY_W, KEY_S, KEY_A, KEY_D:
			# Studio's WASD: a selection nudged by the snap across the
			# ground as you look at it, and with nothing selected the view
			# slid. Ctrl with them is Save, Select all and Duplicate.
			if key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
				if key.keycode == KEY_A and (key.ctrl_pressed or key.meta_pressed):
					_verbs.select_by("all")
				if key.keycode == KEY_S and (key.ctrl_pressed or key.meta_pressed) and _bar:
					_bar._on_save()
				return
			var way: Vector3 = {KEY_W: Vector3.FORWARD, KEY_S: Vector3.BACK,
				KEY_A: Vector3.LEFT, KEY_D: Vector3.RIGHT}[key.keycode]
			if not _builder.selection.is_empty() and not _steps.is_playing_back():
				_nudge(way)
			elif not key.echo:
				_camera.key_slide(Vector2(way.x, -way.z))
		KEY_PAGEUP, KEY_PAGEDOWN:
			# Up and down a plate with a selection; the zoom took them
			# above when there is none.
			if not _builder.selection.is_empty():
				_nudge_by(Vector3i(0, _verbs.up_cells()
					* (1 if key.keycode == KEY_PAGEUP else -1), 0))
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step: int = 1 if key.keycode == KEY_BRACKETRIGHT else -1
			_color_index = posmod(_color_index + step, QUICK_COLORS.size())
			_builder.held_color = QUICK_COLORS[_color_index]
			_bin._on_colour(QUICK_COLORS[_color_index])
			_refresh_preview()
		KEY_Q, KEY_E:
			# Ctrl+Q quits, the way it does in every desktop app here. The
			# web page is closed by its tab.
			if key.keycode == KEY_Q and (key.ctrl_pressed or key.meta_pressed):
				if not OS.has_feature("web"):
					get_tree().quit()
				return
			# Shift with them turns the whole model; Q alone takes the last
			# part again (EditVerbs).
			if key.shift_pressed:
				_turn_model(1 if key.keycode == KEY_E else -1)
		KEY_B:
			_toggle_steps()
		KEY_P:
			_toggle_parts()
		KEY_M:
			_open_figures()
		KEY_I:
			# Ctrl-I, as an import is in most apps: plain I is x-ray
			# (src/ui/shell.gd). A key is a press a browser lets open its
			# file chooser.
			if (key.ctrl_pressed or key.meta_pressed) and _brickify != null:
				_brickify.ask()
		KEY_C:
			# Paint the selection if there is one, or what is under the
			# cursor if there is not.
			if not _builder.selection.is_empty():
				var painted: int = _builder.paint_selection(_builder.held_color)
				if painted > 0:
					_on_model_edited()
					_bar.say("painted %d" % painted)
			else:
				# The brick under the pointer, found by the pointer: with
				# nothing in hand there is no ghost to say which it is.
				var under: int = _brick_under_pointer()
				# With a part in hand, the brick its ghost was last aimed at.
				if under == 0 and _verbs.mode == "place":
					under = _builder.hovered_brick()
				if _builder.paint_brick(under, _builder.held_color):
					_on_model_edited()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selection()
		KEY_G:
			# And take a colour and part back off the model, into hand.
			if _brick_under_pointer() != 0 \
					and _verbs.pick_at(get_viewport().get_mouse_position()):
				_refresh_preview()
			elif _verbs.mode == "place" and _builder.pick_hovered():
				_refresh_preview()
		KEY_X:
			# Lift a brick off to move it. The next click puts it down.
			var lifting: int = _brick_under_pointer()
			if lifting == 0 and _verbs.mode == "place":
				lifting = _builder.hovered_brick()
			# Off the model and into hand, to put down again where a click
			# says; undo puts it back where it was.
			if lifting != 0 and _builder.lift_brick(lifting):
				_verbs.set_mode("place")
				_on_model_changed()
				_bar.say("lifted — click to put it down")
				_refresh_preview()
		KEY_LEFT, KEY_RIGHT:
			# Three claims on these keys, in order. A booklet being read
			# owns them; then a selection being nudged; then whatever
			# has focus, because stealing them unconditionally breaks
			# the search box and the brief.
			if _steps.is_playing_back():
				if key.keycode == KEY_RIGHT:
					_steps.step_forward()
				else:
					_steps.step_back()
			elif not _builder.selection.is_empty():
				_nudge(Vector3.RIGHT if key.keycode == KEY_RIGHT
					else Vector3.LEFT)
			elif not key.echo:
				# Nothing else wants them: they move the view. Turn, or
				# slide with shift; holding goes on in _steer_from_keys.
				var way := Vector2(1 if key.keycode == KEY_RIGHT else -1, 0)
				if key.shift_pressed:
					_camera.key_slide(way)
				else:
					_camera.key_turn(way)
		KEY_UP, KEY_DOWN:
			if not _builder.selection.is_empty():
				# Along the ground with no modifier; up and down with
				# shift, which is the axis you want far less often.
				if key.shift_pressed:
					_nudge_by(Vector3i(0,
						_verbs.up_cells() * (1 if key.keycode == KEY_UP else -1), 0))
				else:
					_nudge(Vector3.FORWARD if key.keycode == KEY_UP
						else Vector3.BACK)
			elif not _steps.is_playing_back() and not key.echo:
				var way := Vector2(0, 1 if key.keycode == KEY_UP else -1)
				if key.shift_pressed:
					_camera.key_slide(way)
				else:
					_camera.key_turn(way)
		KEY_TAB:
			_tab_columns()
		KEY_Z:
			# The same undo as Edit's, which says what it took back.
			if key.ctrl_pressed or key.meta_pressed:
				_verbs.press("redo" if key.shift_pressed else "undo")
				_refresh_preview()
		KEY_COMMA:
			# Where a preferences panel lives in every app on this
			# machine.
			_controls.open()
		KEY_SLASH:
			if _bin:
				# The bin opened first, if it was folded away: the search
				# box is in it.
				_bin_dock.set_open(true)
				_bin.focus_search()
		KEY_N:
			# Not on the web, where Ctrl+N is the browser's new window and
			# never reaches the page.
			if (key.ctrl_pressed or key.meta_pressed) and _bar:
				_bar.ask_for_new()
		KEY_ESCAPE:
			# Leaving playback first. Escape reads as "out of this mode",
			# and quitting the app because someone wanted the whole model
			# back would be a bad surprise.
			#
			# A selection is the innermost of these modes and so goes
			# first. Adding it as a second arm of the same match was the
			# obvious way and silently took the whole ladder over: one
			# match statement runs one arm, so leaving the booklet
			# stopped working and nobody would find out until they
			# tried it.
			# Everything that is up, innermost first, and nothing below
			# it. The bottom rung was quit on the desktop, and it cost
			# work three times: a ladder that did not know about the
			# mosaic dialog closed the whole app from it, and a design
			# run forty-six minutes in ended on one stray press. Escape
			# means "out of this"; leaving the app is Ctrl+Q or the
			# window's close button.
			# A box being drawn is the innermost of all: the button is
			# still down. Thrown away, and the release that ends the
			# drag is not taken for a click.
			if _marquee != null and _marquee.is_drawing():
				_marquee.finish()
				_box_began = false
				_box_dropped = true
				return
			# The controls panel was missing from this ladder, so
			# Escape walked straight past it to whatever was behind.
			if _controls != null and _controls.visible:
				_controls.visible = false
				return
			if _mosaic != null and _mosaic.visible:
				_mosaic.visible = false
				return
			if _brickify != null and _brickify.visible:
				_brickify.close()
				return
			if _figures != null and _figures.visible:
				_figures.close()
				return
			if _builder.is_holding_figure():
				_builder.drop_figure()
				_bar.say("")
				_refresh_preview()
				return
			if _elements != null and _elements.visible:
				_elements.visible = false
				return
			# Back to Select with nothing in hand, from placing or any
			# other tool — and on down the ladder in the same press, so
			# one Escape is always enough to be back at rest.
			var resting: bool = _verbs == null or _verbs.mode == "select"
			if not resting:
				_verbs.set_mode("select")
				_refresh_preview()
			if not _builder.selection.is_empty():
				_builder.clear_selection()
				return
			# Out of the sub-assembly being edited, a level at a time — but
			# not on the press that put a tool down: a part put away while
			# working inside one is not being done with it.
			if resting and _verbs != null and _verbs.assemblies != null \
					and not _verbs.assemblies.entered.is_empty():
				_verbs.leave_assembly()
				return
			if _inventory.is_showing():
				_inventory.hide_list()
				return
			if _steps.is_playing_back():
				_steps.stop()
				return


## Delete or Backspace: the selection taken off, said first when it is a
## big one (EditVerbs._say_first), since that is one long frame.
func _delete_selection() -> void:
	var job: Working.Job = await _verbs._say_first(_builder.selection.size(),
		"Taking off %s parts…")
	var gone: int = _builder.remove_selection()
	if gone > 0:
		_on_model_edited()
		_bar.say("removed %d" % gone)
	if job != null:
		job.end()


static func _comma(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	var count: int = 0
	for n: int in range(text.length() - 1, -1, -1):
		out = text[n] + out
		count += 1
		if count % 3 == 0 and n > 0:
			out = "," + out
	return out
