## suggest_probe laid out for a phone, in a phone's window: Compare's change
## sent back as wide as the phone has room for, every tick and button on the
## screen to press.
##
##   godot --path . --resolution 390x844 --script src/dev/suggest_phone_probe.gd -- --pictures=DIR
##   tools/probe.sh suggest_phone_probe -- --pictures=DIR
##
## The suite gives a probe its header's window: so a script of its own, which
## is suggest_probe in all else, on its own port.
extends "res://src/dev/suggest_probe.gd"


func _port_for() -> int:
	return 11792


func _finger() -> String:
	return "390"
