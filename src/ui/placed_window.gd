## A window drawn inside the main one, said to a screen reader to be where it
## is drawn ([method AccessTree.place]). AccessTree gives it to each such
## window that has no script of its own, while a screen reader is on.
extends Window


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		AccessTree.place(self)
