## timelinefit_probe laid out for a tablet, in a tablet's window.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1024x768 \
##     --script src/dev/timelinefit_tablet_probe.gd
##
## The suite gives a probe its header's window, and a tablet's is not a
## laptop's: so a script of its own, which is timelinefit_probe in all else.
## The panels are the tablet's own: the parts sheet, the drawer of the model
## tree and the properties, Stress beside the model and the assistant's
## drawer, opened by the tablet's own controls.
extends "res://src/dev/timelinefit_probe.gd"


func _finger() -> String:
	return "tablet"
