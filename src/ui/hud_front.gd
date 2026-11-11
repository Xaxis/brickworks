## The panels over the model, the one last asked for in front, as a desktop's
## windows are (the hudfront unit, 2026-11-09).
##
## Main's panels (the keys sheet, Render, Find's list, My collection, the
## Library, Share, Account, the prints and the rest) are each a child of
## the HUD, and a child is drawn and takes the pointer in its parent's
## order. They stayed in the order they were made: Find's list, made the
## first time Find was used, kept over the keys sheet and Render opened
## after it, which showed beneath it (typingkeys, 2026-11-08).
##
## Now a panel put in the HUD through here (Main._add_to_hud, [method
## add_beside]) comes to the front of it:
## - as it is shown, however it was asked for: a key, a menu, a button, a
##   session over MCP, a check; and asked for again while it shows behind
##   another, as its own open shows it with [method show_panel];
## - as a press lands on it, before the press reaches what is under the
##   pointer, so a panel that is shown but covered comes forward when it is
##   clicked;
## - as the keys go into it (Tab, F6).
## Always under the sign-in screen (SignInGate), which is over everything
## in the HUD; a dialog that is a window of its own (Page setup, Versions,
## the menus) is drawn over the whole HUD by the window anyway. What a
## panel keeps just under it (Render's veil, [constant UNDER]) goes with
## it. Tab and F6 go into the one in front (FocusGuard reads the panels in
## this order).
class_name HudFront
extends Node

## The group the one in the window is in, for [method add_beside].
const GROUP := &"hud_front"
## Meta on a child of the HUD naming the panel it stays just under: Render's
## veil, which darkens what is behind Render and takes the clicks there.
const UNDER := &"hud_front_under"

## The layer the panels are in (Main's $HUD).
var hud: CanvasLayer
## The control a press at a point of a layer reaches, as the window finds
## it (Main._control_at): func(node: Node, at: Vector2) -> Control.
var control_at: Callable
## Each panel taken, and whether it was itself shown when last heard of:
## the HUD hidden and shown again (a picture taken without it) brings
## nothing forward, only a panel shown that was not.
var _shown: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	get_viewport().gui_focus_changed.connect(_focused)


## [param panel] shown, in front of the other panels: each panel's own open
## shows itself so, so that asked for again while it shows behind another
## (its key, its menu, its button, a session), it comes forward then too.
static func show_panel(panel: Control) -> void:
	panel.visible = true
	var keeper: HudFront = _keeper(panel)
	if keeper != null and keeper._shown.has(panel):
		keeper.front(panel)


## [param panel] put in the HUD beside [param beside], one of the HUD's
## panels, and kept in order with the others: the minifigure builder's
## print and mould editors. Beside it as before where there is no HudFront
## (a check's bare panel).
static func add_beside(beside: Control, panel: Control) -> void:
	var parent: Node = beside.get_parent()
	parent.add_child(panel)
	var keeper: HudFront = _keeper(beside)
	if keeper != null and keeper.hud == parent:
		keeper.take(panel)


## The window's HudFront, or null (a check's bare panel).
static func _keeper(node: Node) -> HudFront:
	return node.get_tree().get_first_node_in_group(GROUP) as HudFront if node.is_inside_tree() else null


## [param panel], just added to the HUD, kept in front of the others
## whenever it is shown, clicked or given the keys; under the sign-in
## screen from now on.
func take(panel: Control) -> void:
	if panel == null or _shown.has(panel):
		return
	_shown[panel] = panel.visible
	panel.visibility_changed.connect(_heard.bind(panel))
	panel.tree_exiting.connect(func() -> void: _shown.erase(panel))
	front(panel)


## [param panel] in front of every other panel in the HUD, under the
## sign-in screen, with what it keeps under it.
func front(panel: Control) -> void:
	var to: int = _front_index(panel)
	if to < 0:
		return
	if panel.get_index() != to:
		hud.move_child(panel, to)
	for child: Node in hud.get_children():
		if child.has_meta(UNDER) and child.get_meta(UNDER) == panel:
			hud.move_child(child, panel.get_index() - (1 if child.get_index() < panel.get_index() else 0))


## Whether a press at [param at] (the window's units) lands on something
## drawn over the HUD first: What's This?'s sheet, a number typed for the
## part in hand.
func _drawn_over(at: Vector2) -> bool:
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var over: CanvasLayer = layer as CanvasLayer
		if over.layer > hud.layer and over.visible and over.get_viewport() == hud.get_viewport() \
				and control_at.call(over, over.get_final_transform().affine_inverse() * at) != null:
			return true
	return false


## Where [param panel] goes to be in front: just under the sign-in screen,
## or last; -1 when it is not in the HUD.
func _front_index(panel: Control) -> int:
	if hud == null or panel == null or panel.get_parent() != hud:
		return -1
	for child: Node in hud.get_children():
		if child is SignInGate:
			# Moved out from under it, the screen comes down one.
			return child.get_index() - (1 if panel.get_index() < child.get_index() else 0)
	return hud.get_child_count() - 1


func _heard(panel: Control) -> void:
	var now: bool = panel.visible
	if now and not bool(_shown.get(panel, false)):
		front(panel)
	_shown[panel] = now


## Pressed (any button but the wheel, or a finger): the panel under it to
## the front first, as a window comes forward when it is clicked. The press
## goes on to what it was on.
func _input(event: InputEvent) -> void:
	var at: Vector2
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed or button.button_index not in [MOUSE_BUTTON_LEFT,
				MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			return
		at = button.position
	elif event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return
		at = (event as InputEventScreenTouch).position
	else:
		return
	if hud == null or not hud.visible or not control_at.is_valid():
		return
	var hit: Control = control_at.call(hud, hud.get_final_transform().affine_inverse() * at)
	var panel: Control = _panel_of(hit)
	# Render's veil, the sign-in screen, the model: nothing comes forward.
	# And the common press, in the panel in front, has nothing to move.
	if panel == null or not _shown.has(panel) or panel.get_index() == _front_index(panel):
		return
	if not _drawn_over(at):
		front(panel)


## The keys gone into a panel: that panel to the front.
func _focused(control: Control) -> void:
	var panel: Control = _panel_of(control)
	if panel != null and _shown.has(panel) and panel.is_visible_in_tree():
		front(panel)


## The child of [member hud] that [param control] is in, or null.
func _panel_of(control: Node) -> Control:
	var node: Node = control
	while node != null and node.get_parent() != hud:
		node = node.get_parent()
	return node as Control
