## subexport_probe's F5 laid out for a phone, in a phone's window.
##
##   godot --path . --resolution 390x844 --script src/dev/subexport_phone_probe.gd
##   tools/probe.sh subexport_phone_probe
##
## The suite gives a probe its header's window, and a phone's is not the
## desktop's: so a script of its own, which runs subexport_probe's F5 alone,
## a finger's hold and a right click on a row of the model tree, their
## menus at the size a phone gives them (se3check 1).
extends "res://src/dev/subexport_probe.gd"


func _finger() -> String:
	return "phone"
