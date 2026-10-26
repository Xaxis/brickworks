## View, Stress on a big Technic set: its pins and axles weighed, in seconds.
##
##   godot --headless --path . --script src/dev/technic_stress_probe.gd
##
## walk256 (findings D12): Stress on the Cat D11 (42131-1, 6,793 parts drawn)
## took 47 s and listed 14 joints, every one on studs: Balance weighed only
## stud joints and put each joint pins or axles alone make among the parts
## "held otherwise". Here the D11 is weighed as Stress weighs it
## (Stability.check with its margins, Main.weigh_joints on a worker): it must
## finish in under [constant MOST_MS], and its joints must count pins and
## axles (Balance._pin_load): an axle keyed in its hole or pins on two lines
## held square, on one line a friction pin against its torque and a
## frictionless one against nothing; and Stress's own words (StressView.said)
## say them. Exits non-zero when it is
## slow or no pin is weighed.
extends SceneTree

const D11 := "res://vendor/omr/files/42131-1.mpd"
const MOST_MS := 10000

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	await process_frame
	store.open(D11)
	print("the Cat D11: %d parts drawn, %d a builder counts" % [world.brick_count(),
		Inventory.pieces_in(world, library, store.scenery)])
	var judge := Stability.new()
	judge.library = library
	judge.lattice = builder.lattice
	judge.floor_ids = store.scenery
	judge.with_margins = true
	var began: int = Time.get_ticks_msec()
	var report: Stability.Report = judge.check(world)
	var took: int = Time.get_ticks_msec() - began
	var kinds: Dictionary = {}
	for one: Balance.JointLoad in report.margins.values():
		kinds[one.kind] = int(kinds.get(one.kind, 0)) + 1
	print("  weighed as Stress weighs it in %d ms: %s; %d joints: %s" % [took, report.summary(),
		report.margins.size(), kinds])
	_check("Stress on the D11 in under %d s: %.1f s" % [MOST_MS / 1000, took / 1000.0], took < MOST_MS)
	var pins: int = 0
	for kind: String in kinds:
		if kind != "studs":
			pins += int(kinds[kind])
	_check("its pins and axles are joints it weighs: %d of %d" % [pins, report.margins.size()],
		pins > 0)
	var said: String = StressView.said(report, world, library, store.scenery, 40, 0)
	_check("...and Stress says them: %s" % _line_with(said, " pin").strip_edges().left(160),
		said.contains("friction pin") or said.contains("frictionless") or said.contains("keyed in its hole"))
	print("")
	print("technic stress: the D11 weighed in seconds, its pins and axles among its joints"
		if _failures == 0 else "technic stress: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


static func _line_with(text: String, words: String) -> String:
	for line: String in text.split("\n"):
		if line.contains(words):
			return line
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
