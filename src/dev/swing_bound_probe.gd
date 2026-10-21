## A swing let go in a session's move_part answers in bounded time, and a
## stop does not spin up a wheel it carries.
##
##   godot --headless --path . --script src/dev/swing_bound_probe.gd
##
## A design session's move_part on a motorcycle (the technic lever's 42107-1,
## 2026-10-20) never answered: it hung 600 s, until the session's MCP server
## dropped. The move tipped the model over, and as it landed its free joints
## swung (Swing.run): the frame, stopped against the model, carried the rear
## wheel on its free axle. Each step the frame's turn was set to nought by
## itself, and the wheel kept the turn the frame's fall would have given it,
## so it spun faster and faster, never at rest; each step of it ran a room
## test of about 100 ms, and 40 s of it would have taken an hour. Built here
## by hand, without a model:
##  - a frame pressed against what stopped it, carrying a wheel whose centre
##    is on its axle: the wheel stays still and the swing is at rest at once.
##  - a frame swinging into a stop: as it meets it, the wheel on its free
##    axle turns on as it was turning (still), not with the frame's turn.
##  - a swing whose room test takes 20 ms, let go turning: run() stops when
##    its time is up, keeps it where it was last tested, and says so.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_pressed_frame()
	_meeting_frame()
	_out_of_time()
	print("a swing answers in bounded time" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## A frame on a pin at the origin, its weight 10 studs out, carrying a wheel
## on a free axle 10 studs further out, the wheel's centre on its axle.
static func _frame_and_wheel() -> Swing:
	var swing := Swing.new()
	var frame: int = swing.add_joint(Vector3.ZERO, Vector3.RIGHT, -1, "frame")
	var axle: int = swing.add_joint(Vector3(0.0, 0.0, 400.0), Vector3.RIGHT, frame, "wheel")
	swing.add_segment(frame, {}, {"grams": 300.0, "centre": Vector3(0.0, 0.0, 200.0),
		"inertia": Basis(Vector3(1e5, 0, 0), Vector3(0, 1e5, 0), Vector3(0, 0, 1e5))})
	swing.add_segment(axle, {}, {"grams": 200.0, "centre": Vector3(0.0, 0.0, 400.0),
		"inertia": Basis(Vector3(1e6, 0, 0), Vector3(0, 5e5, 0), Vector3(0, 0, 5e5))})
	swing.ready_up(null, null)
	return swing


func _pressed_frame() -> void:
	print("── a frame pressed against what stopped it, a wheel on its free axle ──")
	var swing: Swing = _frame_and_wheel()
	# Its weight turns it +x, into what stopped it.
	swing.joints[0].pressed = 1
	var began: int = Time.get_ticks_msec()
	swing.run()
	print("    at rest after %.3f s of swing, %d ms; frame %.4f rad, wheel %.4f rad at %.4f rad/s"
		% [swing.time, Time.get_ticks_msec() - began, swing.q[0], swing.q[1], swing.qd[1]])
	_check("the frame stays against its stop (%.4f rad)" % swing.q[0], absf(swing.q[0]) < 1e-6)
	_check("the wheel stays still on its axle (%.4f rad; it spun up for 40 s before)" % swing.q[1],
		absf(swing.q[1]) < 0.001)
	_check("at rest as soon as it is still (%.3f s)" % swing.time,
		swing.time <= Swing.STILL_S + 0.01 and not swing.cut_short)


func _meeting_frame() -> void:
	print("── a frame swinging into a stop, a wheel on its free axle ──")
	var swing: Swing = _frame_and_wheel()
	# No friction: whatever turns the wheel is the stop's push.
	swing.set_mu(0.0)
	swing.joints[0].reach = 500.0
	swing.joints[1].reach = 500.0
	# The frame's own part, for the room test to read its turn: it meets
	# something 0.3 rad down.
	swing.segments[0].start = {1: Transform3D.IDENTITY}
	swing.room = func(at: Dictionary) -> int:
		var frame: Transform3D = at.get(1, Transform3D.IDENTITY)
		return 1 if atan2(frame.basis.y.z, frame.basis.y.y) > 0.3 else 0
	var spin_before: float = 0.0
	var frame_rate: float = 0.0
	while swing.stops == 0 and swing.time < 2.0:
		spin_before = swing.qd[0] + swing.qd[1]
		frame_rate = swing.qd[0]
		swing.step()
	var spin_after: float = swing.qd[0] + swing.qd[1]
	var wheel_at_meet: float = swing.q[1]
	print("    met it at %.3f s, the frame turning at %.3f rad/s; the wheel's own spin %.6f before, %.6f after"
		% [swing.time, frame_rate, spin_before, spin_after])
	_check("it meets the stop (%d)" % swing.stops, swing.stops == 1 and absf(frame_rate) > 1.0)
	_check("the wheel turns on as it was turning: %.6f rad/s, not the frame's %.3f" % [spin_after,
		frame_rate], absf(spin_after - spin_before) < 1e-4 * absf(frame_rate))
	swing.run()
	print("    at rest after %.3f s; wheel %.4f rad from where the frame met it"
		% [swing.time, swing.q[1] - wheel_at_meet])
	_check("then it rests, the wheel where it was (%.4f rad)" % (swing.q[1] - wheel_at_meet),
		absf(swing.q[1] - wheel_at_meet) < 0.001 and swing.time < 1.0 and not swing.cut_short)


func _out_of_time() -> void:
	print("── a swing whose room test takes 20 ms, let go turning ──")
	var swing := Swing.new()
	var pin: int = swing.add_joint(Vector3.ZERO, Vector3.RIGHT, -1, "arm")
	swing.add_segment(pin, {}, {"grams": 50.0, "centre": Vector3(0.0, -100.0, 0.0),
		"inertia": Basis(Vector3(1e4, 0, 0), Vector3(0, 1e4, 0), Vector3(0, 0, 1e4))})
	swing.ready_up(null, null)
	swing.set_mu(0.0)
	swing.joints[0].reach = 500.0
	swing.room = func(_at: Dictionary) -> int:
		OS.delay_msec(20)
		return 0
	swing.fling(20.0)
	var began: int = Time.get_ticks_msec()
	swing.run(500.0)
	var took: int = Time.get_ticks_msec() - began
	print("    stopped after %d ms, %.3f s of swing, %d tests: %s" % [took, swing.time, swing.tests,
		swing.words()])
	_check("asked for 500 ms, it stops within a test of it (%d ms)" % took, took < 600 and swing.cut_short)
	_check("kept where it was last tested", swing.q == swing.get("_tested"))
	_check("and says so", swing.words().contains("kept where it was: the app works a swing out for at most"))
	# The time move_part gives it.
	swing = Swing.new()
	pin = swing.add_joint(Vector3.ZERO, Vector3.RIGHT, -1, "arm")
	swing.add_segment(pin, {}, {"grams": 50.0, "centre": Vector3(0.0, -100.0, 0.0),
		"inertia": Basis(Vector3(1e4, 0, 0), Vector3(0, 1e4, 0), Vector3(0, 0, 1e4))})
	swing.ready_up(null, null)
	swing.set_mu(0.0)
	swing.joints[0].reach = 500.0
	swing.room = func(_at: Dictionary) -> int:
		OS.delay_msec(100)
		return 0
	swing.fling(20.0)
	began = Time.get_ticks_msec()
	swing.run()
	took = Time.get_ticks_msec() - began
	print("    as move_part runs it: stopped after %d ms, %.3f s of swing" % [took, swing.time])
	_check("move_part's swing stops by %d ms and a test (%d ms)" % [roundi(Swing.RUN_MOST_MS), took],
		took < Swing.RUN_MOST_MS + 200.0 and swing.cut_short)
