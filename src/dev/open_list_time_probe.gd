## Does File › Open say when each saved model was saved by this computer's
## clock, as File › Versions… does?
##
##   godot --headless --path . --script src/dev/open_list_time_probe.gd
##
## walk180 (D4): the desktop's Open list said "Harbour Tug — 253 bricks,
## 2026-10-23 15:48:46" for a save made at 07:48 in Alaska, the time in UTC.
## Here a model is saved, and File › Open's list and File › Open recent are
## read as the menus show them: its row must say "today at HH:MM:SS" by the
## local clock, a second either side of the save, and not the time in UTC.
## And one saved on another day says the day as Versions… does ("11 Oct at
## 09:30:00").
extends SceneTree

const NAME := "Open List Time Probe"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var store: ModelStore = main.get("_store")
	var bar: ModelBar = main.get("_bar")
	var shell: Shell = main.get("_shell")
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	print("this computer's clock is %+d minutes from UTC" % bias)

	DirAccess.remove_absolute(ModelStore.saved_path(NAME))
	store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	_check("the house is saved as %s" % NAME, store.save_as(NAME))
	var saved_at: int = FileAccess.get_modified_time(ModelStore.saved_path(NAME))

	bar._on_open()
	var row: String = _row(bar.get("_saves"))
	(bar.get("_saves") as PopupMenu).hide()
	_held("File › Open", row, saved_at, bias)
	var recent := PopupMenu.new()
	root.add_child(recent)
	shell._fill_recent(recent)
	_held("File › Open recent", _row(recent), saved_at, bias)

	# Saved on another day (its file's time set back three days): the day,
	# as Versions… says it.
	var then: int = saved_at - 3 * 86400
	OS.execute("touch", ["-d", "@%d" % then, ProjectSettings.globalize_path(ModelStore.saved_path(NAME))])
	var day: Dictionary = Time.get_datetime_dict_from_unix_time(then + bias * 60)
	var months: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var want: String = "%d %s%s at %02d:%02d:%02d" % [day.day, months[int(day.month) - 1],
		"" if day.year == Time.get_datetime_dict_from_system().year else " %d" % day.year,
		day.hour, day.minute, day.second]
	bar._on_open()
	row = _row(bar.get("_saves"))
	(bar.get("_saves") as PopupMenu).hide()
	_check("saved three days before: \"%s\" says \"%s\"" % [row, want], row.ends_with(", " + want))

	DirAccess.remove_absolute(ModelStore.saved_path(NAME))
	print("")
	if _failures == 0:
		print("File › Open says when each model was saved by this computer's clock")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## The menu's row for the probe's model.
func _row(menu: PopupMenu) -> String:
	for n: int in menu.item_count:
		if menu.get_item_text(n).begins_with(NAME + " — "):
			return menu.get_item_text(n)
	return ""


## [param row] held to the save's time on the local clock, a second either
## side, and not the time in UTC.
func _held(where: String, row: String, saved_at: int, bias: int) -> void:
	var local: PackedStringArray = []
	for off: int in [-1, 0, 1]:
		var at: Dictionary = Time.get_datetime_dict_from_unix_time(saved_at + off + bias * 60)
		local.append("today at %02d:%02d:%02d" % [at.hour, at.minute, at.second])
	var utc: String = Time.get_datetime_string_from_unix_time(saved_at).replace("T", " ")
	_check("%s: \"%s\" says the save's time here (%s)" % [where, row, local[1]],
		not row.is_empty() and Array(local).any(func(words: String) -> bool:
			return row.ends_with(", " + words)))
	_check("%s: ...not the time in UTC (%s)" % [where, utc], not row.contains(utc)
		and not row.contains(utc.substr(11)) if bias != 0 else not row.contains(utc))


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)
