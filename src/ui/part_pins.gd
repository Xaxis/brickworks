## Comments on a part of a shared model in the app (partpins, 2026-11-23):
## which part each is on (PinPlace), a numbered dot over each open one's
## part, and the part lit and framed when its comment is pressed. In a
## shared model's viewer, the menu a right click, a finger held or the menu
## key offers on a part (Comment on this part). In the studio, for the
## model's builder, the count of open ones with the model's other notices,
## and their list (PartPinsPanel), each resolved or reopened there.
##
## main.gd makes it (Later), over the model (_over_model), the first time
## the viewer's answer says the server keeps comments on parts, or the
## studio's model with a link has some for its builder. It shows what the
## server said and sends what was pressed: who may write, and what a pin
## keeps, are the server's (api/_comments.js, supabase/comment_pins.sql).
class_name PartPins
extends Control

## Comment on this part was chosen: [param part] is the part as a pin sends
## it ({part, colour, at}) with its brick, its name and how the box says it
## (said: "On the 2 × 4 brick").
signal comment_wanted(part: Dictionary)
## A pin's part was lit (the viewer) or selected (the studio), and framed.
signal shown(brick_id: int)

## A dot's size, in the interface's units.
const DOT := 22.0
## The dots' colour: the site's pins', apart from the file's own (PinsView).
const TINT := Color("#e8590c")
## Above the part's top, as the file's pins sit (PinnedComments.ABOVE).
const ABOVE := 6.0
## A part framed with at least this much round it, in LDU: a 1 x 1 plate
## framed alone filled the view, with nothing to say where it was.
const ROOM := 160.0

## The studio's (the model's builder, signed in) rather than a viewer's.
var studio: bool = false
var world: BrickWorld
var store: ModelStore
var camera: CadCamera
var library: PartLibrary
## The viewer's: what lights a pin's part (the step's outline).
var outline: SelectionOutline
## The studio's: what selects a pin's part.
var builder: Builder
## Where the menu goes, over everything (the HUD).
var menu_host: Node
## The studio's: the strip of notices above the model, what seats the list
## in the tool column, the link's server, the token to send as, and what
## asks for the answer again.
var notices: Control
var seat: Callable = Callable()
var shared: SharedModels
var token_for: Callable = Callable()
var look_again: Callable = Callable()

## The server's answer ({pins, comments, you, ...}), as the comments have it.
var answer: Dictionary = {}
## How many Resolve presses the server took, this visit (the page's tally).
var resolves: int = 0
## The part last lit or selected for a pin, for a check.
var lit: int = 0

var _bricks: Array = []
var _bricks_key: String = ""
var _placed_ms: int = -100000
## Each comment on a part by id: {brick, moved}, or {} for on no part here.
var _placed: Dictionary = {}
## Each comment on a part by id: its number, as its dot and its line say it.
var _numbers: Dictionary = {}
var _dots: Dictionary = {}
var _scrim: Control
var _menu: PanelContainer
var _menu_item: Button
var _offered: Dictionary = {}
var _notice: RestoreNotice
var _notice_show: Button
## The open ones the builder has seen the notice of: it comes back for a new one.
var _seen: Dictionary = {}
var _panel: PartPinsPanel
var _told: String = ""


func _ready() -> void:
	name = "PartPins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# -- what the answer says ---------------------------------------------------------

## The server's answer, as the comments show it: its pins placed on the
## model as it stands, their dots drawn, and in the studio the notice and
## the list.
func set_answer(given: Dictionary) -> void:
	answer = given
	_bricks_key = ""
	_place_all()
	_after_change()


## No model with a link, or nobody signed in: nothing shown.
func forget() -> void:
	answer = {}
	_seen.clear()
	_place_all()
	_after_change()


static func _yes(v: Variant) -> bool:
	return v is bool and bool(v)


## Whether the server keeps comments on parts.
func pins_on() -> bool:
	return _yes(answer.get("pins"))


## Whether whoever asked is the model's builder.
func is_builder() -> bool:
	return answer.get("you") is Dictionary and _yes((answer["you"] as Dictionary).get("owner"))


## The comments on parts, in the answer's order (oldest first).
func pinned() -> Array:
	var out: Array = []
	var listed: Variant = answer.get("comments")
	if listed is Array:
		for one: Variant in listed:
			if one is Dictionary and (one as Dictionary).get("pin") is Dictionary:
				out.append(one)
	return out


func open_ones() -> Array:
	return pinned().filter(func(one: Dictionary) -> bool: return not StepComments.resolved(one))


func resolved_ones() -> Array:
	return pinned().filter(func(one: Dictionary) -> bool: return StepComments.resolved(one))


static func _id(one: Dictionary) -> int:
	var id: Variant = one.get("id")
	return int(id) if id is int or id is float else 0


## What the parts were read at: the studio's as it is edited, the viewer's
## as it was opened (a part played with stays the part it was).
func _key_now() -> String:
	if world == null:
		return ""
	return "%d:%d:%d" % [world.generation(), world.brick_count(), world.revision if studio else 0]


func _place_all() -> void:
	_placed_ms = Time.get_ticks_msec()
	_placed.clear()
	_numbers.clear()
	var key: String = _key_now()
	if key != _bricks_key:
		_bricks = PinPlace.bricks_of(world, store.lift(), store.scenery) \
			if world != null and store != null else []
		_bricks_key = key
	var n: int = 0
	for one: Dictionary in pinned():
		n += 1
		var id: int = _id(one)
		_numbers[id] = n
		var at: Dictionary = PinPlace.place(one["pin"], _bricks)
		_placed[id] = {} if at.is_empty() else {
			"brick": int((_bricks[int(at["index"])] as Dictionary)["id"]), "moved": bool(at["moved"])}


## The part [param one] is on in the model shown, or 0.
func brick_of(one: Dictionary) -> int:
	if _key_now() != _bricks_key:
		_place_all()
	return int((_placed.get(_id(one), {}) as Dictionary).get("brick", 0))


## How [param one] is said where it is listed: {words, number, pressable,
## resolved}: "On the 2 × 4 brick, step 12", with ", moved since" for a part
## moved since; "On version 2" for one on no part of the model shown, which
## is not pressed.
func line_of(one: Dictionary) -> Dictionary:
	if not one.get("pin") is Dictionary:
		return {}
	if _key_now() != _bricks_key:
		_place_all()
	var id: int = _id(one)
	var at: Dictionary = _placed.get(id, {})
	var name: String = ""
	if not at.is_empty():
		var brick: BrickWorld.Brick = world.get_brick(int(at["brick"]))
		name = _name_of(brick.part_id) if brick != null else ""
	var on: Variant = one.get("on_step")
	var step: int = int(on) if on is int or on is float else 0
	var version: Variant = one.get("version")
	var words: String = PinPlace.where(name, step, at, int(version) if version is int or version is float else 1)
	return {"words": words.substr(0, 1).to_upper() + words.substr(1), "number": int(_numbers.get(id, 0)),
		"pressable": not at.is_empty(), "resolved": StepComments.resolved(one)}


func _name_of(part_id: String) -> String:
	var parts: PartLibrary = library if library != null else (world.library if world != null else null)
	var info: PartLibrary.PartInfo = parts.parts.get(part_id) if parts != null else null
	return info.name if info != null else ""


## [param brick_id]'s part as a pin is sent ({part, colour, at}, at where it
## stood as the model was opened, in the file's coordinates), with its
## brick, its name and how the box says it. {} for none.
func part_of(brick_id: int) -> Dictionary:
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if world != null and brick_id != 0 else null
	if brick == null or store.scenery.has(brick_id):
		return {}
	if _key_now() != _bricks_key:
		_place_all()
	var at: Variant = null
	var turn: Variant = null
	for one: Dictionary in _bricks:
		if int(one["id"]) == brick_id:
			at = one["at"]
			turn = one.get("turn")
			break
	if at == null:
		var home: Transform3D = world.home_of(brick)
		var stands: Vector3 = (home.origin - store.lift()) * LdrModel.FLIP
		at = [snappedf(stands.x, 0.001), snappedf(stands.y, 0.001), snappedf(stands.z, 0.001)]
		turn = PinPlace.turn_of_basis(home.basis)
	var name: String = _name_of(brick.part_id)
	var said: String = PinPlace.part_said(name)
	# Its turn tells it apart from another of its kind in its place (the
	# server's pinFrom, api/_comments.js).
	return {"part": brick.part_id, "colour": brick.color_code, "at": at, "turn": turn, "brick": brick_id,
		"name": name, "said": ("On the %s" % said) if not said.is_empty() else "On a part"}


# -- showing a pin's part ----------------------------------------------------------

## The part [param one] is on lit (the viewer) or selected (the studio), and
## the view framed on it with room round it. False when it is on no part of
## the model shown.
func show_pin(one: Dictionary) -> bool:
	var brick_id: int = brick_of(one)
	var brick: BrickWorld.Brick = world.get_brick(brick_id) if brick_id != 0 else null
	if brick == null:
		return false
	if studio and builder != null:
		builder.clear_selection()
		builder.select_brick(brick_id, false)
	elif outline != null:
		outline.show_selection({brick_id: true})
	var box: AABB = _box_of(brick)
	camera.frame(box.grow(maxf(0.0, (ROOM - box.size.length()) * 0.5)))
	lit = brick_id
	shown.emit(brick_id)
	return true


func _box_of(brick: BrickWorld.Brick) -> AABB:
	var parts: PartLibrary = library if library != null else world.library
	var mesh: Lbm.PartMesh = parts.mesh_for(brick.part_id) if parts != null else null
	if mesh == null:
		return AABB(brick.transform.origin - Vector3(10, 10, 10), Vector3(20, 20, 20))
	return (brick.transform * mesh.bounds).abs()


# -- the dots ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if world == null or camera == null:
		Wake.rest(self)
		return
	# Placed again as the model is edited: at most twice a second, so a part
	# dragged in a big model is not every part read again each frame.
	var due: bool = _key_now() != _bricks_key
	if due and Time.get_ticks_msec() - _placed_ms >= 500:
		_place_all()
		_after_change()
		due = false
	var area := Rect2(Vector2.ZERO, size)
	var drawn: Dictionary = {}
	if not studio or is_builder():
		for one: Dictionary in pinned():
			if StepComments.resolved(one):
				continue
			var id: int = _id(one)
			var brick_id: int = int((_placed.get(id, {}) as Dictionary).get("brick", 0))
			var brick: BrickWorld.Brick = world.get_brick(brick_id) if brick_id != 0 else null
			if brick == null or brick.hidden:
				continue
			var box: AABB = _box_of(brick)
			var point := Vector3(box.get_center().x, box.end.y + ABOVE, box.get_center().z)
			if camera.is_position_behind(point):
				continue
			var at: Vector2 = camera.unproject_position(point) - get_global_rect().position
			if not area.grow(-DOT / 2.0).has_point(at):
				continue
			var dot: Button = _dots.get(id)
			if dot == null:
				dot = _dot(one)
				_dots[id] = dot
			dot.text = str(_numbers.get(id, 0))
			dot.position = (at - Vector2(DOT, DOT) / 2.0).round()
			drawn[id] = true
	for id: int in _dots.keys():
		if not drawn.has(id):
			(_dots[id] as Button).queue_free()
			_dots.erase(id)
	# Asleep at rest (Wake): the dots move with the view (a drawn frame) and
	# change with an answer or an edit.
	if not due:
		Wake.rest(self)


func _dot(one: Dictionary) -> Button:
	var dot := Button.new()
	dot.focus_mode = Control.FOCUS_NONE
	dot.custom_minimum_size = Vector2(DOT, DOT)
	dot.size = Vector2(DOT, DOT)
	dot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	dot.add_theme_font_size_override("font_size", 12)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = TINT.lightened(0.15) if state == "hover" else TINT
		face.set_corner_radius_all(int(DOT / 2.0))
		face.border_color = Color.WHITE
		face.set_border_width_all(2)
		dot.add_theme_stylebox_override(state, face)
	for which: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		dot.add_theme_color_override(which, Color.WHITE)
	var who: String = str(one.get("by", "")) if one.get("by") is String else ""
	dot.tooltip_text = "%s: %s" % [who if not who.is_empty() else "A builder",
		str(one.get("body", "")).left(80)]
	var id: int = _id(one)
	dot.pressed.connect(func() -> void:
		for now: Dictionary in pinned():
			if _id(now) == id:
				show_pin(now)
				return)
	add_child(dot)
	return dot


# -- the viewer's menu on a part ----------------------------------------------------

## Comment on this part offered on [param brick_id], beside [param at] (a
## point in the window): beside a finger rather than under it. False for no
## part, or nowhere to show it.
func offer(brick_id: int, at: Vector2, by_finger: bool) -> bool:
	var part: Dictionary = part_of(brick_id)
	if part.is_empty() or menu_host == null:
		return false
	_offered = part
	if _menu == null:
		_make_menu()
	var pt: float = Phone.per_point(get_viewport()) if by_finger else 1.0
	_menu_item.add_theme_font_size_override("font_size", roundi((15.0 if by_finger else 13.0) * pt))
	_menu_item.custom_minimum_size = Vector2(0.0, (44.0 if by_finger else 26.0) * pt)
	_scrim.visible = true
	_menu.visible = true
	_menu.reset_size()
	var tall: Vector2 = _menu.get_combined_minimum_size()
	var room: Rect2 = get_viewport().get_visible_rect()
	var spot: Vector2 = at + Vector2(-tall.x * 0.5, -tall.y - 30.0 * pt) if by_finger \
		else at + Vector2(2.0, 2.0)
	spot.x = clampf(spot.x, room.position.x + 4.0, room.end.x - tall.x - 4.0)
	spot.y = clampf(spot.y, room.position.y + 4.0, room.end.y - tall.y - 4.0)
	_menu.position = spot.round()
	# The keys choose it too: Enter, or Escape for none.
	_menu_item.grab_focus()
	return true


func _make_menu() -> void:
	_scrim = Control.new()
	_scrim.name = "PinMenuScrim"
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	# A press anywhere else puts the menu away, as a menu's does.
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
				or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			close_menu()
			_scrim.accept_event())
	_scrim.visible = false
	menu_host.add_child(_scrim)
	_menu = PanelContainer.new()
	_menu.name = "PinMenu"
	_menu.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "PopupMenu"))
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	_menu_item = Button.new()
	_menu_item.text = "Comment on this part"
	_menu_item.flat = true
	_menu_item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_menu_item.tooltip_text = "Say something about this part, for its builder and everyone who looks at it"
	_menu_item.add_theme_stylebox_override("hover", get_theme_stylebox("hover", "PopupMenu"))
	_menu_item.add_theme_stylebox_override("focus", get_theme_stylebox("hover", "PopupMenu"))
	_menu_item.add_theme_stylebox_override("pressed", get_theme_stylebox("hover", "PopupMenu"))
	_menu_item.pressed.connect(func() -> void:
		var part: Dictionary = _offered
		close_menu()
		if not part.is_empty():
			comment_wanted.emit(part))
	_menu.add_child(_menu_item)
	_scrim.add_child(_menu)


func close_menu() -> void:
	if _menu != null:
		_menu.visible = false
		_scrim.visible = false
		if _menu_item.has_focus():
			_menu_item.release_focus()


func menu_open() -> bool:
	return _menu != null and _menu.visible


func _input(event: InputEvent) -> void:
	if menu_open() and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()


# -- the studio's notice and list ------------------------------------------------

## Something the answer says changed: the notice, the list and the page told.
func _after_change() -> void:
	if studio:
		_notice_now()
		if _panel != null and _panel.visible:
			_panel.fill(open_ones(), resolved_ones(), line_of)
	_tell()
	set_process(true)


func _notice_now() -> void:
	var open: Array = open_ones() if is_builder() else []
	var unseen: bool = false
	for one: Dictionary in open:
		unseen = unseen or not _seen.has(_id(one))
	if open.is_empty() or not unseen or notices == null:
		if _notice != null:
			_notice.dismiss()
		return
	if _notice == null:
		_notice = RestoreNotice.new()
		_notice.name = "PinsNotice"
		_notice.key = "pins_notice_close"
		notices.add_child(_notice)
		_notice_show = ReloadOffer.button("Show", true)
		_notice_show.tooltip_text = "List them, and see each one's part"
		_notice_show.pressed.connect(open_list)
		var row: Control = _notice.get_child(0)
		row.add_child(_notice_show)
		row.move_child(_notice_show, row.get_child_count() - 2)
		# Put away, it says nothing more of these: a new one brings it back.
		_notice.visibility_changed.connect(func() -> void:
			if not _notice.visible:
				for one: Dictionary in open_ones():
					_seen[_id(one)] = true)
	_notice.tell("1 comment on a part of this model" if open.size() == 1
		else "%d comments on parts of this model" % open.size())


## The list in the tool column, filled, the notice put away.
func open_list() -> void:
	if _notice != null:
		_notice.dismiss()
	if _panel == null:
		_panel = PartPinsPanel.new()
		_panel.name = "PartPinsPanel"
		_panel.show_wanted.connect(func(one: Dictionary) -> void: show_pin(one))
		_panel.resolve_wanted.connect(resolve)
		if seat.is_valid():
			seat.call(_panel)
		else:
			add_child(_panel)
	_panel.fill(open_ones(), resolved_ones(), line_of)
	_panel.open()
	# And asked again, for what came since.
	if look_again.is_valid():
		look_again.call()


func list_open() -> bool:
	return _panel != null and _panel.visible


## [param one] done with ([param done] true), or open again, as the model's
## builder: sent, and the list and the dots as the server answers.
func resolve(one: Dictionary, done: bool) -> void:
	var id: int = _id(one)
	var token: String = ""
	if token_for.is_valid():
		token = await token_for.call()
	if token.is_empty() or shared == null:
		_said("Sign in again to resolve comments.")
		return
	var reply: Dictionary = await shared.resolve_pin(token, id, done)
	var body: Variant = reply.get("body")
	if int(reply.get("code", 0)) != 200 or not body is Dictionary \
			or not (body as Dictionary).get("comment") is Dictionary:
		_said(SharedModels.trouble(reply, "Brickworks could not take that just now. Try again in a minute."))
		if _panel != null:
			_panel.fill(open_ones(), resolved_ones(), line_of)
		return
	var now: Dictionary = (body as Dictionary)["comment"]
	for kept: Variant in answer.get("comments", []):
		if kept is Dictionary and _id(kept as Dictionary) == id:
			(kept as Dictionary)["resolved_at"] = now.get("resolved_at")
			(kept as Dictionary)["resolved"] = now["resolved"] if now.get("resolved") is bool \
				else now.get("resolved_at") is String
	if done:
		resolves += 1
	# Seen: Reopen does not bring the notice back for one its builder opened.
	_seen[id] = true
	_said("")
	_after_change()


func _said(words: String) -> void:
	if _panel != null:
		_panel.say(words)


# -- for the page and a check ------------------------------------------------------

## The page told how many are open and resolved (window.brickworksPins), on
## the web, as they change: what its tally counts (web/tally.js).
func _tell() -> void:
	if not OS.has_feature("web"):
		return
	var said: String = JSON.stringify({"open": open_ones().size(), "resolved": resolved_ones().size(),
		"resolves": resolves, "studio": studio})
	if said == _told:
		return
	_told = said
	JavaScriptBridge.eval("window.brickworksPins = " + said, true)


func page_state() -> Dictionary:
	var listed: Array = []
	for one: Dictionary in pinned():
		var at: Dictionary = _placed.get(_id(one), {})
		listed.append({"id": _id(one), "number": int(_numbers.get(_id(one), 0)),
			"brick": int(at.get("brick", 0)), "moved": bool(at.get("moved", false)),
			"resolved": StepComments.resolved(one), "words": str(line_of(one).get("words", ""))})
	return {"on": pins_on(), "studio": studio, "owner": is_builder(), "open": open_ones().size(),
		"resolved": resolved_ones().size(), "resolves": resolves, "dots": _dots.size(), "pins": listed,
		"lit": lit, "menu": menu_open(),
		"offered": {"part": _offered.get("part", ""), "colour": _offered.get("colour", -1),
			"at": _offered.get("at", [])} if menu_open() else {},
		"notice": _notice.words() if _notice != null else "",
		"list": _panel.page_state() if _panel != null else {}}


## What a check presses: the menu's one row, each dot (pin_dot_N), the
## notice's Show and Got it, and the list's.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	if menu_open():
		out["view_pin_comment"] = _menu_item
	for id: int in _dots:
		var dot: Button = _dots[id]
		if dot.is_visible_in_tree():
			out["pin_dot_%d" % int(_numbers.get(id, 0))] = dot
	if _notice != null and _notice.visible:
		out.merge(_notice.controls_by_name())
		out["pins_notice_show"] = _notice_show
	if _panel != null:
		out.merge(_panel.controls_by_name())
	return out
