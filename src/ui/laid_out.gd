## Once a panel is laid out: a scroll to what a change just put in waits for
## that, not for a count of frames.
##
## A press is read before its frame's layout, and that frame's process_frame
## can come before its layout too. One frame on, the card Build it opened had no
## size yet, and the chat stopped 240 px short of it, 19 clicks in 30
## (chat_follow_probe); the connector form's box just opened was 3,815 px
## tall, and the panel scrolled 16 px where the box fitted (suitegrab). A
## second frame held only because the press was read where those were.
class_name LaidOut
extends RefCounted

signal _passed


## Returns once the layout a change just made sets off is done. A frame lays
## its panels out in one pass of deferred calls, every sort the pass sets off
## done in it, and a call deferred now runs in that pass: so that call is
## waited for, then the next frame, which begins once the pass is done. No
## sort is asked for here: a ScrollContainer sorted before what it holds was
## laid out took its scroll back to fit the shorter content and kept it
## there, 202 px, 2 runs in 4 (connect_form_probe).
static func settled(node: Node) -> void:
	var hook := LaidOut.new()
	(func() -> void: hook._passed.emit()).call_deferred()
	await hook._passed
	if is_instance_valid(node) and node.is_inside_tree():
		await node.get_tree().process_frame


## [param scroll] at the end of what it holds, once that is laid out.
static func to_end(scroll: ScrollContainer) -> void:
	await settled(scroll)
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## [param control] scrolled into [param scroll]'s view, once it is laid out.
static func into_view(scroll: ScrollContainer, control: Control) -> void:
	await settled(scroll)
	if is_instance_valid(scroll) and is_instance_valid(control) and control.is_visible_in_tree():
		scroll.ensure_control_visible(control)
