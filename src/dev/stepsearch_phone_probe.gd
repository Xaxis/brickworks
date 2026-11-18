## stepsearch_probe laid out for a phone, in a phone's window.
##
##   godot --path . --resolution 390x844 --script src/dev/stepsearch_phone_probe.gd
##
## The suite gives a probe its header's window: so a script of its own,
## which is stepsearch_probe's phone half in all else.
extends "res://src/dev/stepsearch_probe.gd"


func _on_a_phone_wanted() -> bool:
	return true
