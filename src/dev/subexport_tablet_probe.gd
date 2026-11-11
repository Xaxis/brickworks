## subexport_probe's F5 laid out for a tablet, in a tablet's window.
##
##   godot --path . --resolution 1180x820 --script src/dev/subexport_tablet_probe.gd
##   tools/probe.sh subexport_tablet_probe
##
## The suite gives a probe its header's window, and a tablet's is not the
## desktop's: so a script of its own, which runs subexport_probe's F5 alone,
## a finger's hold and a right click on a row of the model tree, their
## menus at the size a tablet gives them (se3check 1, at 1180 x 820).
extends "res://src/dev/subexport_probe.gd"


func _finger() -> String:
	return "tablet"
