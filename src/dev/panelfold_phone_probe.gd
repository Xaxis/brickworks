## panelfold_probe laid out for a phone, in a phone's window: the drawer's
## model tree, properties and Colour fold and size as the desktop's
## columns do, by a finger.
##
##   godot --path . --resolution 390x844 --script src/dev/panelfold_phone_probe.gd
##   tools/probe.sh panelfold_phone_probe
##
## The suite gives a probe its header's window: so a script of its own, which
## is panelfold_probe in all else.
extends "res://src/dev/panelfold_probe.gd"


func _finger() -> bool:
	return true
