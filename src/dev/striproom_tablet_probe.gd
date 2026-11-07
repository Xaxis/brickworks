## striproom_probe laid out for a tablet, in a tablet's window.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1024x768 \
##     --script src/dev/striproom_tablet_probe.gd
##
## The suite gives a probe its header's window, and a tablet's is not a
## phone's: so a script of its own, which is striproom_probe in all else.
extends "res://src/dev/striproom_probe.gd"


func _finger() -> String:
	return "tablet"
