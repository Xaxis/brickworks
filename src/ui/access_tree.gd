## What the engine tells a screen reader wrong about the window, put right
## in one place (a11ytree). Each is a fault of Godot 4.7.2's or AccessKit's,
## not of the app's scripts, but a person with a screen reader meets it in
## the app all the same:
##
## A list cut short. AccessKit 0.22 (accesskit_consumer 0.38, iterators.rs,
## next_filtered_sibling and previous_filtered_sibling) ends a list of
## children where an element of no role and no children (a spacer, a
## separator, a Timer) is followed, past any hidden ones, by a hidden one that
## has children: from the spacer it goes on into the next one's children, and
## having gone into the hidden one's it climbs back to that hidden one and
## stops there. The top bar had one (Model name's spacer, then the hidden
## Claude tab), so the window's list ended at Model name and browsing it
## reached only the menus. Each such element is given a child of its own, an
## empty node (AccessKit goes into it, comes back out and goes on), whenever
## its parent's children change.
##
## A panel hidden still shown. CanvasItem::set_visible never queues an
## accessibility update (Godot's master does, in _handle_visibility_change),
## so a panel the app put away stayed in the tree, and pointing at a dialog
## behind where it was found the panel. Each change of an element's own
## visibility queues its update here, so the frame it changes in tells it.
##
## A window said to be elsewhere. Window::get_accessibility_transform undoes
## only its parent control's own offset, but AccessKit composes every
## ancestor's: a dialog or a menu under controls not at the window's corner
## was said to be that far from where it is drawn. Each window drawn inside
## the main one is placed again in its own update ([method place]; a window
## with no script of its own is given placed_window.gd for it).
##
## Only while a screen reader is on: the web has no tree to tell (Godot's web
## DisplayServer has no screen reader), and none of this runs for a person
## without one. Shell.build adds it beside Access.
class_name AccessTree
extends Node

const PLACED := preload("res://src/ui/placed_window.gd")
## Set on the empty child that keeps a list whole, and on the element given it.
const SEAL := &"access_seal"
const SEALED := &"access_sealed"

## The visibility each canvas item last told the tree, by its instance id.
var _told: Dictionary = {}
## The callable each canvas item's visibility_changed calls, by instance id.
var _heard: Dictionary = {}
## The callable each parent's child_order_changed calls, by instance id.
var _parents: Dictionary = {}
## Parents whose children are looked at again before the frame's tree is sent.
var _pending: Dictionary = {}
var _engaged: bool = false


func _ready() -> void:
	if get_tree().is_accessibility_supported():
		_watch()


## A screen reader can come on while the app runs: looked for once a second
## until one has.
func _watch() -> void:
	if _engaged or not is_inside_tree():
		return
	if get_tree().is_accessibility_enabled():
		_engage()
	else:
		get_tree().create_timer(1.0).timeout.connect(_watch)


func _engage() -> void:
	_engaged = true
	get_tree().node_added.connect(_on_added)
	get_tree().node_removed.connect(_on_removed)
	_take(get_tree().root)


func _take(node: Node) -> void:
	_on_added(node)
	for child: Node in node.get_children(true):
		_take(child)


func _on_added(node: Node) -> void:
	if node.has_meta(SEAL):
		return
	if node is CanvasItem:
		var item: CanvasItem = node
		var id: int = item.get_instance_id()
		_told[id] = item.visible
		if not _heard.has(id):
			var heard: Callable = _on_visibility.bind(item)
			_heard[id] = heard
			item.visibility_changed.connect(heard)
		# Its parent's children: a canvas item among them can be the hidden
		# one a list stops at.
		var parent: Node = item.get_parent()
		if parent != null:
			var at: int = parent.get_instance_id()
			if not _parents.has(at):
				var tidy: Callable = _tidy_later.bind(parent)
				_parents[at] = tidy
				parent.child_order_changed.connect(tidy)
			_tidy_later(parent)
	elif node is Window and node != get_tree().root and node.get_script() == null:
		_give_place.call_deferred(node)


func _on_removed(node: Node) -> void:
	var id: int = node.get_instance_id()
	_told.erase(id)
	if _heard.has(id):
		(node as CanvasItem).visibility_changed.disconnect(_heard[id])
		_heard.erase(id)
	if _parents.has(id):
		node.child_order_changed.disconnect(_parents[id])
		_parents.erase(id)


## Its own visibility changed (a parent's showing or hiding it tells nothing
## new of it: it was told what it is itself).
func _on_visibility(item: CanvasItem) -> void:
	var id: int = item.get_instance_id()
	if bool(_told.get(id, not item.visible)) != item.visible:
		_told[id] = item.visible
		item.queue_accessibility_update()


func _tidy_later(parent: Node) -> void:
	if _pending.is_empty():
		_tidy_pending.call_deferred()
	_pending[parent.get_instance_id()] = true


func _tidy_pending() -> void:
	var ids: Array = _pending.keys()
	_pending.clear()
	for id: int in ids:
		var parent: Node = instance_from_id(id) as Node
		if parent != null and parent.is_inside_tree():
			_tidy(parent)


## Every child of [param parent] that lists nothing and has no role, with a
## canvas item beside it, given the empty child that keeps the list whole;
## and [param parent] itself, if it now lists nothing.
func _tidy(parent: Node) -> void:
	var children: Array[Node] = parent.get_children(true)
	var canvases: int = 0
	for child: Node in children:
		if child is CanvasItem:
			canvases += 1
	for child: Node in children:
		if canvases > (1 if child is CanvasItem else 0) and _ends_lists(child):
			_seal(child)
	if _ends_lists(parent) and parent.get_parent() != null:
		for sibling: Node in parent.get_parent().get_children(true):
			if sibling != parent and sibling is CanvasItem:
				_seal(parent)
				break


## No role of its own and no children AccessKit lists: the element that
## cuts a list short beside a hidden one.
static func _ends_lists(node: Node) -> bool:
	if node.has_meta(SEAL) or node.has_meta(SEALED) or _has_role(node):
		return false
	for child: Node in node.get_children(true):
		# A window is listed only while shown, and when it is the element
		# lists it.
		if not child is Window:
			return false
	return true


## The classes Godot 4.7.2 gives a role of their own (their
## NOTIFICATION_ACCESSIBILITY_UPDATE sets one; every other node is a
## container AccessKit passes through).
static func _has_role(node: Node) -> bool:
	if node is Container and (node as Container).accessibility_region:
		return true
	return node is BaseButton or node is Label or node is LineEdit or node is TextEdit \
		or node is ScrollContainer or node is GraphNode or node is ColorPicker or node is MenuBar \
		or node is RichTextLabel or node is Range or node is ItemList or node is Tree \
		or node is TabBar or node is Panel or node is VideoStreamPlayer or node is Window \
		or node is AudioStreamPlayer or node is Sprite2D or node is AnimatedSprite2D \
		or node is TouchScreenButton


func _seal(node: Node) -> void:
	var seal := Node.new()
	seal.name = &"Seal"
	seal.set_meta(SEAL, true)
	node.set_meta(SEALED, true)
	node.add_child(seal, false, Node.INTERNAL_MODE_BACK)


## A window with no script of its own is given the one that places it, before
## the tree is next sent.
func _give_place(window: Window) -> void:
	if is_instance_valid(window) and window.is_inside_tree() and window.get_script() == null:
		window.set_script(PLACED)
		window.queue_accessibility_update()


## [param window] said to be where it is drawn: called in its own
## accessibility update, after the engine's, which said it was as far off as
## the controls above its parent are from the window's corner. AccessKit
## places each element by its parent's place and its own transform, so this
## one's is the inverse of what AccessKit composes down to its parent, then
## where the window is in the window that draws it.
static func place(window: Window) -> void:
	if window.get_embedder() == null:
		return
	var element: RID = window.get_accessibility_element()
	if not element.is_valid():
		return
	AccessibilityServer.update_set_transform(element,
		_composed(window.get_parent()).affine_inverse() * _drawn(window))


## Where [param window] is drawn in the window that draws it, as the engine
## gives an embedded window's place: its position, at its content's scale.
static func _drawn(window: Window) -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * window.content_scale_factor, 0.0, Vector2(window.position))


## What AccessKit composes from under the native window down to [param node]:
## each control's own transform, an embedded window's place (each is placed
## here), nothing for any other node.
static func _composed(node: Node) -> Transform2D:
	var chain: Array[Node] = []
	var at: Node = node
	while at != null and not (at is Window and (at as Window).get_embedder() == null):
		chain.append(at)
		at = at.get_parent()
	var composed := Transform2D.IDENTITY
	for n: int in range(chain.size() - 1, -1, -1):
		var each: Node = chain[n]
		if each is Control:
			composed = composed * (each as Control).get_transform()
		elif each is Window:
			composed = _drawn(each as Window)
	return composed
