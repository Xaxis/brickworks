## likethis_probe laid out for a tablet, in a tablet's window.
##
##   godot --path . --resolution 1024x768 --script src/dev/likethis_tablet_probe.gd
##   tools/probe.sh likethis_tablet_probe
##
## The suite gives a probe its header's window, and a tablet's is not a
## phone's: so a script of its own, which is likethis_probe in all else.
extends "res://src/dev/likethis_probe.gd"


func _finger() -> String:
	return "tablet"
