## Sign this machine's Brickworks in from a checkout, without an inbox.
##
##   godot --headless --path . --script src/dev/sign_in.gd -- you@example.com
##   godot --headless --path . --script src/dev/sign_in.gd -- --out
##
## Everyone who opens the app signs in, and a windowed app driven from a
## checkout — `godot --path . -- --mcp` for tools/brick.py, a look at a
## change by hand — opens on the sign-in screen like anyone's. This signs
## the machine in the way the app would, keeping the session where the
## app keeps its own (user://session.json), so the next window opens
## signed in. The code is minted with Supabase's admin API rather than
## emailed, so it needs SUPABASE_SECRET_KEY in .env: only the owner's
## machines can do this. --out signs out again.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var deployment := Deployment.new()
	get_root().add_child(deployment)
	var account := Account.new()
	account.deployment = deployment
	get_root().add_child(account)
	while account.state == Account.State.CHECKING:
		await account.changed

	if args.has("--out"):
		if account.signed_in():
			await account.sign_out()
			print("signed out")
		else:
			print("nobody was signed in")
		quit(0)
		return
	if args.is_empty() or not args[0].contains("@"):
		print("which address? godot --headless --path . --script src/dev/sign_in.gd -- you@example.com")
		quit(2)
		return
	if account.signed_in() and account.email == args[0].to_lower():
		print("already signed in as %s" % account.email)
		quit(0)
		return
	if account.state == Account.State.UNREACHABLE:
		print("cannot reach %s to sign in" % Deployment.api_base())
		quit(1)
		return
	if account.state == Account.State.NOT_NEEDED:
		print("%s has no accounts, so there is nothing to sign in to" % Deployment.api_base())
		quit(0)
		return
	var problem: String = await SignInHelper.sign_in(account, args[0], get_root())
	if not problem.is_empty():
		print("could not sign in: %s" % problem)
		quit(1)
		return
	print("signed in as %s, kept at %s" % [account.email,
		ProjectSettings.globalize_path(Account.where)])
	quit(0)
