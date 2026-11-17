## typedturn_probe laid out for a phone, in a phone's window.
##
##   godot --path . --resolution 390x844 --script src/dev/typedturn_phone_probe.gd
##
## The suite gives a probe its header's window, and a phone's is not a
## tablet's: so a script of its own, which is typedturn_probe in all else.
extends "res://src/dev/typedturn_probe.gd"


func _wide() -> bool:
	return false
