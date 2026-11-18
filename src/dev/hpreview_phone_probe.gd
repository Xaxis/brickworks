## hpreview_probe's phone section, in a phone's window: the program row by
## finger, Run and Stop tapped, what the run says and the slider in view.
##
##   godot --path . --resolution 430x932 --script src/dev/hpreview_phone_probe.gd
##
## The suite gives a probe its header's window: so a script of its own,
## which is hpreview_probe's phone section in all else.
extends "res://src/dev/hpreview_probe.gd"


func _sections() -> String:
	return "phone"
