## The sign-in screen's line about where models are kept is true in every
## state it is shown in.
##
##   godot --headless --path . --script src/dev/gate_line_probe.gd
##
## walk239 (2026-10-24, A12): signed in, the account kept the person's model
## ("kept", 1 model), yet the sign-in screen said "Your models are saved on
## this device, not with your account" (SignInGate). tidy232 made the
## Account panel's line and the storage warning true in each way the models
## stand with the account (StorageKeep, CloudModels.standing); this is the
## gate's own line. Here the screen is shown as it is to a first visit
## (signed out), to a returning visitor being signed in (checking), with no
## connection (unreachable) and at the age question (signed in), the
## account's models standing out, looking, kept, full and offline: each line
## says models are saved on this device and kept with the account. On a
## deployment that keeps none ("none") it says they are not. And Claude's
## half stays as it was, with the assistant shown and without.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var account := Account.new()
	account.keeps = false
	root.add_child(account)
	await process_frame
	var gate := SignInGate.new()
	gate.setup(account)
	root.add_child(gate)
	await process_frame
	var was: String = CloudModels.standing
	for state: Array in [[Account.State.SIGNED_OUT, "signed out"], [Account.State.CHECKING, "being signed in"],
			[Account.State.UNREACHABLE, "no connection"], [Account.State.SIGNED_IN, "at the age question"]]:
		for standing: String in ["out", "looking", "kept", "full", "offline", "none"]:
			CloudModels.standing = standing
			account.state = state[0]
			account.age_ask = state[0] == Account.State.SIGNED_IN
			account.changed.emit()
			await process_frame
			var line: String = _line(gate)
			var kept: bool = line.contains("kept with your account")
			var not_kept: bool = line.contains("not with your account")
			_check("%s, the models %s: \"%s\"" % [state[1], standing, line.left(140)],
				line.contains("saved on this device") and (not_kept and not kept if standing == "none"
					else kept and not not_kept))
	CloudModels.standing = was
	print("")
	print("gate_line: %s" % ("all checks passed" if _failures == 0 else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## The screen's line about what an account is: the one that says where the
## models are.
func _line(gate: Node) -> String:
	for label: Node in gate.find_children("*", "Label", true, false):
		if (label as Label).text.begins_with("An account is"):
			return (label as Label).text
	return ""
