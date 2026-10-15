## The page is told where a control is only where it is drawn.
##
##   godot --headless --path . --script src/dev/page_places_probe.gd
##
## Browser checks press the app's controls where the app says they are
## (window.brickworksControls, Main._tell_page). The warning that the browser
## may clear the models is offered in the same frame the page is told, every
## second, and a control shown this frame is not laid out until the frame
## ends. So its Download my models was told at its place before layout, 440
## px from where it is drawn, for half a second, and keep_flow pressed
## nothing there: on 480b81a and on 9aba2b9 alike, about one run in two.
## Here the warning is shown, the page's places are worked out in that frame
## as Main works them out, and again once it is laid out.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var offer: StorageOffer = main.get("_storage_offer")
	var to_window: Transform2D = main.get_viewport().get_final_transform()
	# Told once before, with the warning not up.
	offer.visible = false
	await _frames(3)
	main.call("_page_places", main.call("_page_controls"), to_window, 1.0)

	print("\nthe warning shown, and the page told in the same frame")
	StorageKeep.pretend({"asked": true, "answered": true, "kept": false})
	ShellPrefs.put("storage_warned", false)
	_check("the warning is offered", offer.offer_if_due(true))
	var button: Button = offer.controls_by_name().get("storage_download_all")
	var unsorted: Vector2 = to_window * button.get_global_rect().get_center()
	var first: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	await _frames(3)
	var drawn: Vector2 = to_window * button.get_global_rect().get_center()
	var drawn_at: Dictionary = {"x": roundi(drawn.x), "y": roundi(drawn.y)}
	_check("in that frame Download my models is not yet where it is drawn: at %s, drawn at %s"
		% [unsorted.round(), drawn.round()], unsorted.round() != drawn.round())
	var told: Variant = first.get("storage_download_all")
	_check("...and the page is told no place it is not drawn at: told %s" % str(told),
		told == null or told == drawn_at)
	var second: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	told = second.get("storage_download_all")
	_check("laid out, the page is told no other place: told %s" % str(told),
		told == null or told == drawn_at)
	var third: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	_check("...and once it has stayed there, it is told where it is drawn: %s"
		% str(third.get("storage_download_all")), third.get("storage_download_all") == drawn_at)

	print("\nput away, it is gone at once")
	offer.visible = false
	var fourth: Dictionary = main.call("_page_places", main.call("_page_controls"), to_window, 1.0)
	_check("Got it, and the page is told no Download my models", not fourth.has("storage_download_all"))
	_check("...and the controls that stayed put are still told: Save at %s" % str(fourth.get("save")),
		fourth.has("save"))

	StorageKeep.pretend({})
	print("")
	if _failures == 0:
		print("the page is told where a control is only where it is drawn")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)
