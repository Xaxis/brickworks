## The person's own keys in the system's keychain (KeyStore), on made-up
## keys in a keyring of the run's own, never the person's:
##
##   tools/keyring_session.sh tools/probe.sh keychain_probe
##   godot --headless --path . --script src/dev/keychain_probe.gd   (inside keyring_session.sh)
##
## Outside a keyring_session.sh it skips itself (exit 3): it keeps keys,
## and the person's keyring is theirs.
##
## Linux's two ways to the Secret Service, each for real, in the run's own
## GNOME Keyring:
## - secret-tool: a key given in Settings, AI goes into the keyring and is in
##   no file; read back with nothing held; the panel's words name the
##   keyring; an Anthropic key kept plain by the first slices, and a provider's
##   kept in an encrypted file, move into it once and their files go; This
##   visit only takes it out; one deleted in the keyring by hand is no key;
##   Forget leaves it in neither the keyring nor a file;
## - Python's libsecret, where secret-tool is not installed: the same keyring
##   item, which secret-tool reads too;
## - no keyring answering (no Secret Service on the bus): the encrypted file,
##   and the words say so.
## And macOS's and Windows' ways, whose tools are not on this computer: their
## protocol against stand-ins that keep keys as `security` and Credential
## Manager do (the stand-in reads `security -i`'s commands and PowerShell's
## -EncodedCommand), so what reaches each tool, and how, is checked; the
## tools themselves are not.
## Through all of it every tool's arguments are written down as it starts,
## and no key is ever among them (another user can read a program's
## arguments, never its input), and no file the app wrote holds a key.
extends SceneTree

var _failures: int = 0
## Every made-up key the run gives, to be found nowhere it should not be.
var _keys: PackedStringArray = []
var _spy_log: String = ""
var _stdin_log: String = ""
var _real_secret_tool: String = ""
var _python: String = ""


func _initialize() -> void:
	if OS.get_environment("BRICKWORKS_KEYRING_SESSION") != "1":
		print("keychain_probe: skipped, not in a keyring of its own "
			+ "(tools/keyring_session.sh tools/probe.sh keychain_probe)")
		quit(3)
		return
	var dir: String = ProjectSettings.globalize_path("user://keychain_probe")
	DirAccess.make_dir_recursive_absolute(dir)
	_spy_log = dir.path_join("argv.log")
	_stdin_log = dir.path_join("stdin.log")
	OS.set_environment("BW_SPY_LOG", _spy_log)
	OS.set_environment("BW_STDIN_LOG", _stdin_log)
	OS.set_environment("BW_FAKE_STORE", dir.path_join("stand_in_store.json"))
	_real_secret_tool = KeyStore._tool("secret-tool")
	_python = KeyStore._tool("python3")
	print("bus %s, secret-tool %s, python3 %s" % [OS.get_environment("DBUS_SESSION_BUS_ADDRESS"),
		_real_secret_tool, _python])
	_check("in a keyring of the run's own, not the person's session bus",
		not OS.get_environment("DBUS_SESSION_BUS_ADDRESS").contains("/run/user/"))
	_check("secret-tool and python3 are here to drive", not _real_secret_tool.is_empty()
		and not _python.is_empty())
	if _failures > 0:
		quit(1)
		return
	_secret_tool(dir)
	_libsecret(dir)
	_no_keyring()
	_mac(dir)
	_windows(dir)
	_nowhere_else()
	if _failures == 0:
		print("keys go into the system's keychain, by its input, and nowhere else")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)


## A made-up key, written down so it can be looked for everywhere.
func _key(prefix: String) -> String:
	var key: String = "%sKEYSAFE%s" % [prefix, Crypto.new().generate_random_bytes(18).hex_encode()]
	_keys.append(key)
	return key


## The keychain [param route] for the rest of the run, as a new run finds it.
func _use(route: String, tools: Dictionary = {}) -> void:
	OS.set_environment("BRICKWORKS_KEYCHAIN", route)
	KeyStore.tools = tools
	KeyStore._route = ""
	KeyStore._held.clear()
	KeyStore._silent.clear()


## What secret-tool, run by the probe itself, finds for the key file [param name].
func _in_keyring(name: String) -> String:
	var out: Array = []
	var data: String = OS.get_user_data_dir().sha256_text().left(16)
	var code: int = OS.execute(_real_secret_tool, ["lookup", "application", "brickworks", "key",
		name, "data", data], out, false)
	return str(out[0]) if code == 0 and not out.is_empty() else ""


func _secret_tool(dir: String) -> void:
	print("\n── the Secret Service, by secret-tool ──")
	_use(KeyStore.SECRET_TOOL, {"secret-tool": _spy(dir, "secret-tool", _real_secret_tool)})
	_check("this run's keychain is secret-tool", KeyStore.keychain() == KeyStore.SECRET_TOOL)

	# As the first slices kept an Anthropic key: plain, in the app's data.
	var ant: String = _key("sk-ant-api03-")
	var plain: FileAccess = FileAccess.open(OwnKey.WHERE, FileAccess.WRITE)
	plain.store_string(ant)
	plain.close()
	var started: int = Time.get_ticks_msec()
	_check("an Anthropic key kept plain is read", OwnKey.load_key() == ant)
	print("  (moved in %d ms)" % (Time.get_ticks_msec() - started))
	_check("...moved into the keyring once, and its file removed",
		_in_keyring("anthropic.key") == ant and not FileAccess.file_exists(OwnKey.WHERE)
		and KeyStore.place(OwnKey.WHERE) == KeyStore.SECRET_TOOL and OwnKey.has_key())

	# As aiset345 kept a provider's: encrypted, in the app's data.
	var mistral: String = _key("mistral")
	KeyStore._write_file(ProviderSettings.key_file("mistral"), mistral)
	_check("a provider's key kept in an encrypted file is read, moved in, and its file removed",
		ProviderSettings.load_key("mistral") == mistral
		and _in_keyring("provider-mistral.key") == mistral
		and not FileAccess.file_exists(ProviderSettings.key_file("mistral")))

	var openai: String = _key("sk-proj-")
	started = Time.get_ticks_msec()
	_check("a key given in Settings, AI is kept", ProviderSettings.remember("openai", openai, true)
		.is_empty())
	print("  (kept and read back in %d ms)" % (Time.get_ticks_msec() - started))
	_check("...in the keyring, and in no file",
		_in_keyring("provider-openai.key") == openai
		and not FileAccess.file_exists(ProviderSettings.key_file("openai"))
		and ProviderSettings.kept_on_device("openai"))
	var marks: String = FileAccess.get_file_as_string(KeyStore.MARKS)
	_check("the app's note of where holds the place and not the key: %s"
		% marks.strip_edges().replace("\n", " | "),
		marks.contains("provider-openai.key") and marks.contains(KeyStore.SECRET_TOOL)
		and not _holds(marks.to_utf8_buffer()))
	KeyStore._held.clear()
	started = Time.get_ticks_msec()
	_check("read back as a new run reads it, from the keyring",
		ProviderSettings.load_key("openai") == openai)
	print("  (read in %d ms)" % (Time.get_ticks_msec() - started))
	var words: String = ProviderSettings.custody("openai", ProviderSettings.key_source("openai"))
	_check("the panel says it is in this computer's keyring: \"%s\"" % words,
		words.begins_with("Kept in this computer's keyring") and words.contains("Secret Service"))

	ProviderSettings.remember("openai", openai, false)
	_check("This visit only: out of the keyring, in no file, used for the visit",
		_in_keyring("provider-openai.key").is_empty()
		and not FileAccess.file_exists(ProviderSettings.key_file("openai"))
		and not ProviderSettings.kept_on_device("openai")
		and ProviderSettings.load_key("openai") == openai)
	ProviderSettings.forget("openai")

	var groq: String = _key("gsk_")
	ProviderSettings.remember("groq", groq, true)
	var data: String = OS.get_user_data_dir().sha256_text().left(16)
	OS.execute(_real_secret_tool, ["clear", "application", "brickworks", "key",
		"provider-groq.key", "data", data])
	KeyStore._held.clear()
	_check("a key deleted in the keyring by hand is no key, and the app's note of it goes",
		ProviderSettings.load_key("groq").is_empty() and not ProviderSettings.kept_on_device("groq"))

	OwnKey.forget()
	ProviderSettings.forget("mistral")
	KeyStore._held.clear()
	_check("Forget: in neither the keyring nor a file, and not read back",
		_in_keyring("anthropic.key").is_empty() and _in_keyring("provider-mistral.key").is_empty()
		and not FileAccess.file_exists(OwnKey.WHERE)
		and not FileAccess.file_exists(ProviderSettings.key_file("mistral"))
		and not OwnKey.has_key() and OwnKey.load_key().is_empty()
		and ProviderSettings.load_key("mistral").is_empty())
	_check("...and with no key kept, no note of where either",
		not FileAccess.file_exists(KeyStore.MARKS))


func _libsecret(dir: String) -> void:
	print("\n── the Secret Service, by Python's libsecret ──")
	_use(KeyStore.LIBSECRET, {"python3": _spy(dir, "python3", _python)})
	_check("this run's keychain is libsecret", KeyStore.keychain() == KeyStore.LIBSECRET)
	var key: String = _key("sk-or-v1-")
	_check("kept", ProviderSettings.remember("openrouter", key, true).is_empty()
		and KeyStore.place(ProviderSettings.key_file("openrouter")) == KeyStore.LIBSECRET)
	_check("...in the keyring, the same item secret-tool reads, and in no file",
		_in_keyring("provider-openrouter.key") == key
		and not FileAccess.file_exists(ProviderSettings.key_file("openrouter")))
	KeyStore._held.clear()
	_check("read back as a new run reads it", ProviderSettings.load_key("openrouter") == key)
	ProviderSettings.forget("openrouter")
	_check("Forget: gone from the keyring", _in_keyring("provider-openrouter.key").is_empty()
		and not ProviderSettings.kept_on_device("openrouter"))


func _no_keyring() -> void:
	print("\n── no keyring answering ──")
	var bus: String = OS.get_environment("DBUS_SESSION_BUS_ADDRESS")
	OS.set_environment("DBUS_SESSION_BUS_ADDRESS", "unix:path=/nonexistent/keychain_probe_bus")
	_use(KeyStore.SECRET_TOOL)
	var key: String = _key("sk-proj-")
	var started: int = Time.get_ticks_msec()
	var problem: String = ProviderSettings.remember("openai", key, true)
	var took: int = Time.get_ticks_msec() - started
	OS.set_environment("DBUS_SESSION_BUS_ADDRESS", bus)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ProviderSettings.key_file("openai"))
	_check("kept all the same, in %d ms" % took, problem.is_empty() and took < 10000)
	_check("...in the encrypted file, which does not hold the key",
		KeyStore.place(ProviderSettings.key_file("openai")) == KeyStore.FILE
		and bytes.slice(0, 4).get_string_from_ascii() == KeyStore.ENCRYPTED and not _holds(bytes))
	var words: String = ProviderSettings.custody("openai", "device")
	_check("the panel says so: \"%s\"" % words,
		words.contains("in a file of the app's own data") and words.contains("no keyring answered"))
	KeyStore._held.clear()
	_check("read back from the file", ProviderSettings.load_key("openai") == key)
	ProviderSettings.forget("openai")
	_check("Forget: the file gone", not FileAccess.file_exists(ProviderSettings.key_file("openai")))


func _mac(dir: String) -> void:
	print("\n── macOS's login Keychain (security), against a stand-in ──")
	var fake: String = _stand_in(dir, "security", SECURITY_PY)
	_use(KeyStore.MAC, {"security": fake, "sh": "/bin/sh"})
	var key: String = _key("sk-ant-api03-")
	_check("kept", OwnKey.remember(key).is_empty()
		and KeyStore.place(OwnKey.WHERE) == KeyStore.MAC and not FileAccess.file_exists(OwnKey.WHERE))
	var given: String = FileAccess.get_file_as_string(_stdin_log)
	_check("...given to `security -i` on its input, in hex, never as an argument",
		given.contains("add-generic-password -U -s Brickworks -a anthropic.key@")
		and given.contains(key.to_utf8_buffer().hex_encode()) and not given.contains(key))
	KeyStore._held.clear()
	_check("read back with find-generic-password -w", OwnKey.load_key() == key)
	var words: String = ProviderSettings.custody("anthropic", "device")
	_check("the panel names the login Keychain for a key not given yet: \"%s\"" % words,
		words.begins_with("Kept in your login Keychain on this Mac"))
	OwnKey.forget()
	KeyStore._held.clear()
	_check("Forget: deleted from it", OwnKey.load_key().is_empty()
		and not FileAccess.get_file_as_string(dir.path_join("stand_in_store.json")).contains("anthropic"))


func _windows(dir: String) -> void:
	print("\n── Windows Credential Manager (PowerShell), against a stand-in ──")
	var fake: String = _stand_in(dir, "powershell", POWERSHELL_PY)
	_use(KeyStore.WINDOWS, {"powershell": fake})
	var key: String = _key("sk-proj-")
	_check("kept", ProviderSettings.remember("openai", key, true).is_empty()
		and KeyStore.place(ProviderSettings.key_file("openai")) == KeyStore.WINDOWS)
	var given: String = FileAccess.get_file_as_string(_stdin_log)
	_check("...on PowerShell's input, its command (-EncodedCommand) holding no key",
		given.contains("powershell store Brickworks/provider-openai.key@") and given.contains(key))
	KeyStore._held.clear()
	_check("read back", ProviderSettings.load_key("openai") == key)
	var words: String = ProviderSettings.custody("openai", "device")
	_check("the panel names Credential Manager: \"%s\"" % words,
		words.begins_with("Kept in Windows Credential Manager on this computer"))
	ProviderSettings.forget("openai")
	KeyStore._held.clear()
	_check("Forget: deleted from it", ProviderSettings.load_key("openai") == OS.get_environment(
		"OPENAI_API_KEY") and not FileAccess.get_file_as_string(
		dir.path_join("stand_in_store.json")).contains("provider-openai"))


func _nowhere_else() -> void:
	print("\n── nowhere else ──")
	var argv: String = FileAccess.get_file_as_string(_spy_log)
	var started: int = argv.count("\n")
	_check("%d programs started, and no key among their arguments" % started,
		started >= 20 and not _holds(argv.to_utf8_buffer()))
	var found: PackedStringArray = []
	for path: String in _files("user://"):
		if path.ends_with("stdin.log"):
			continue
		if _holds(FileAccess.get_file_as_bytes(path)):
			found.append(path)
	_check("no file the app wrote holds a key, as it is or in hex or base64%s"
		% ("" if found.is_empty() else ": " + ", ".join(found)), found.is_empty())


## Whether [param bytes] hold any of the run's keys: as written, in hex, or
## in base64.
func _holds(bytes: PackedByteArray) -> bool:
	var text: String = bytes.get_string_from_ascii()
	for key: String in _keys:
		for form: String in [key, key.to_utf8_buffer().hex_encode(),
				Marshalls.utf8_to_base64(key).trim_suffix("=").trim_suffix("=")]:
			if text.contains(form):
				return true
	return false


func _files(at: String) -> PackedStringArray:
	var all: PackedStringArray = []
	for name: String in DirAccess.get_files_at(at):
		all.append(at.path_join(name))
	for name: String in DirAccess.get_directories_at(at):
		all.append_array(_files(at.path_join(name)))
	return all


## A program that writes down its arguments and runs [param real] with them.
func _spy(dir: String, name: String, real: String) -> String:
	var path: String = dir.path_join("spy-" + name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("#!/bin/sh\nprintf '%%s\\n' \"%s $*\" | tr '\\n' ' ' >> \"$BW_SPY_LOG\"\n" % name
		+ "echo >> \"$BW_SPY_LOG\"\nexec \"%s\" \"$@\"\n" % real)
	file.close()
	OS.execute("chmod", ["+x", path])
	return path


func _stand_in(dir: String, name: String, source: String) -> String:
	var path: String = dir.path_join("stand-in-" + name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("#!%s\n%s" % [_python, source])
	file.close()
	OS.execute("chmod", ["+x", path])
	return path


## macOS's security(1) as KeyStore drives it: add-generic-password from
## `security -i`'s input (-U -s -a -X hex), find-generic-password -w, and
## delete-generic-password, 44 for an item it has not got.
const SECURITY_PY := """
import json, os, shlex, sys
store, spy, given = os.environ["BW_FAKE_STORE"], os.environ["BW_SPY_LOG"], os.environ["BW_STDIN_LOG"]
with open(spy, "a") as log:
    log.write("security " + " ".join(sys.argv[1:]) + "\\n")
items = json.load(open(store)) if os.path.exists(store) else {}
def run(args):
    opts, i = {}, 1
    while i < len(args):
        if args[i] in ("-s", "-a", "-X", "-l"):
            opts[args[i]] = args[i + 1]; i += 2
        else:
            opts[args[i]] = True; i += 1
    name = opts.get("-s", "") + "/" + opts.get("-a", "")
    if args[0] == "add-generic-password":
        if name in items and "-U" not in opts:
            return 45
        items[name] = bytes.fromhex(opts["-X"]).decode()
    elif args[0] == "find-generic-password":
        if name not in items:
            sys.stderr.write("security: The specified item could not be found in the keychain.\\n")
            return 44
        if "-w" in opts:
            print(items[name])
    elif args[0] == "delete-generic-password":
        if name not in items:
            return 44
        del items[name]
    json.dump(items, open(store, "w"))
    return 0
if sys.argv[1:] == ["-i"]:
    for line in sys.stdin:
        with open(given, "a") as log:
            log.write(line)
        sys.stdout.write("security> ")
        run(shlex.split(line))
    sys.exit(0)
sys.exit(run(sys.argv[1:]))
"""

## Windows PowerShell as KeyStore drives it: -NoProfile -NonInteractive
## -EncodedCommand (UTF-16 in base64), holding KeyStore's script; the
## credential's name and the operation are read out of the script, and the
## key from the input, as [Console]::In.ReadLine() reads it.
const POWERSHELL_PY := """
import base64, json, os, re, sys
store, spy, given = os.environ["BW_FAKE_STORE"], os.environ["BW_SPY_LOG"], os.environ["BW_STDIN_LOG"]
with open(spy, "a") as log:
    log.write("powershell " + " ".join(sys.argv[1:]) + "\\n")
assert sys.argv[1:4] == ["-NoProfile", "-NonInteractive", "-EncodedCommand"], sys.argv
script = base64.b64decode(sys.argv[4]).decode("utf-16-le")
with open(spy, "a") as log:
    log.write("powershell's command: " + script.replace("\\n", " ") + "\\n")
assert "CredWriteW" in script and "Add-Type" in script
target = re.search(r"\\$target = '([^']*)'", script).group(1)
op = re.search(r"switch \\('(\\w+)'\\)", script).group(1)
items = json.load(open(store)) if os.path.exists(store) else {}
if op == "store":
    key = sys.stdin.readline().rstrip("\\r\\n")
    with open(given, "a") as log:
        log.write("powershell store %s %s\\n" % (target, key))
    items[target] = key
elif op == "lookup":
    if target not in items:
        sys.exit(2)
    sys.stdout.write(items[target])
elif op == "clear":
    items.pop(target, None)
json.dump(items, open(store, "w"))
"""


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)
