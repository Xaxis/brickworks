## The THIRD-PARTY-NOTICES.txt each desktop release carries: everyone whose
## work ships in Brickworks with their terms, BrickNet's MIT text, and the
## engine's licence with every component's notice.
##
##   godot --headless --path . --script res://tools/release_notices.gd -- OUT
##
## Written from Credits, the list Help, About shows, so the package and the
## app say the same. Godot's part is read from the running engine rather
## than copied by hand, so it is the one for the version that exported the
## build. tools/release.py runs it; nothing else does.
extends SceneTree

const CREDITS := preload("res://src/ui/credits.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("release_notices: say where to write")
		quit(2)
		return
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("release_notices: cannot write %s" % args[0])
		quit(1)
		return
	file.store_string(CREDITS.notices())
	file.close()
	print("notices %s, %d credits, %d components" % [args[0], CREDITS.LIST.size(),
		Engine.get_copyright_info().size()])
	quit(0)
