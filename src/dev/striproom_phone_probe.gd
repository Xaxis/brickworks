## striproom_probe laid out for a phone, in a phone's window.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 390x844 \
##     --script src/dev/striproom_phone_probe.gd
##
## The suite gives a probe its header's window, and a phone's is not a
## desktop's: so a script of its own, which is striproom_probe in all else.
extends "res://src/dev/striproom_probe.gd"


func _finger() -> String:
	return "phone"
