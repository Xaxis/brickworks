## movedparts_probe's list laid out for a phone, in a phone's window.
##
##   godot --path . --resolution 390x844 --script src/dev/movedparts_phone_probe.gd
##   tools/probe.sh movedparts_phone_probe
##
## The suite gives a probe its header's window: so a script of its own, which
## is movedparts_probe's phone case in all else (Missing and moved parts
## wholly in the window, every check box and button 44 points or more).
extends "res://src/dev/movedparts_probe.gd"


func _phone() -> bool:
	return true
