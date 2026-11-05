## likethis_probe laid out for a phone, in a phone's window.
##
##   godot --path . --resolution 390x844 --script src/dev/likethis_phone_probe.gd
##   tools/probe.sh likethis_phone_probe
##
## The suite gives a probe its header's window: so a script of its own, which
## is likethis_probe in all else.
extends "res://src/dev/likethis_probe.gd"


func _finger() -> String:
	return "phone"
