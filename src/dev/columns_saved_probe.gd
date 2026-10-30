## columns_probe from a layout kept before the right column was made: the
## parts bin folded, the assistant open, the model tree dragged to 300 and
## folded. The bin stays folded and the assistant shows, as they were left;
## View, Properties opens the right column on them, the tree out of its fold
## once and at the height it was dragged to (docs/APP_UX.md A10).
##
##   godot --path . --resolution 1280x720 --script src/dev/columns_saved_probe.gd
extends "res://src/dev/columns_probe.gd"


func _init() -> void:
	_saved = true
