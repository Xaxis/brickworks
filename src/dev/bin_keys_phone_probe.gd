## bin_keys_probe laid out for a phone, in a phone's window.
##
##   godot --path . --resolution 390x844 --script src/dev/bin_keys_phone_probe.gd
##   tools/probe.sh bin_keys_phone_probe
##
## The suite gives a probe its header's window: so a script of its own, which
## is bin_keys_probe in all else.
extends "res://src/dev/bin_keys_probe.gd"


func _finger() -> String:
	return "phone"
