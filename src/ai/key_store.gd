## Where the person's own API keys are kept on this device: OwnKey's
## Anthropic key for the assistant's column, and each provider's in
## Settings, AI (ProviderSettings).
##
## In the operating system's own keychain where one answers: the login
## Keychain on a Mac, Credential Manager on Windows, the Secret Service
## (GNOME Keyring, KWallet) on Linux. Each is locked with the person's
## login, so a copy of the disk or a backup holds nothing usable, and the
## person can see and delete the key there. Godot has no keychain of its
## own, so each is reached through the system's own command-line tool, and
## the key goes to that tool on its standard input, never as an argument:
## any user of the computer can read a program's arguments (ps,
## /proc/<pid>/cmdline), and nobody else its input.
##
## Where none answers (a Linux with no Secret Service, and every browser),
## in a file of the app's own data (user://), encrypted with a password made
## of this computer's id and a salt the app made once, so a copy of the file
## taken elsewhere cannot be read. In a browser user:// is the site's
## storage and a browser has no id to give, so there the encryption only
## scrambles it.
##
## A key kept in a file before moves into the keychain the first time it is
## read, and the file is removed. Which place holds each key is written down
## (MARKS: the place, never the key), so asking whether there is a key
## starts no program; the key itself is asked of the keychain once a run.
##
## A run's keychain is chosen by BRICKWORKS_KEYCHAIN where it is set: off
## (the file; what tools/probe.sh gives every probe, so none reaches the
## person's keyring), or one of the routes below by name.
class_name KeyStore
extends RefCounted

## What every file FileAccess encrypts begins with, so a plain one (as the
## first slices kept keys) is told from it without asking FileAccess to
## decrypt it, which says a wrong guess in the console as an engine error.
const ENCRYPTED := "GDEC"
## The salt the key files' password is made with, made once on this device.
const SALT := "user://provider-salt"
## Which keychain holds each key, by its file's name. Never the key.
const MARKS := "user://keys.cfg"

## The ways to a keychain, and the file where there is none.
const SECRET_TOOL := "secret-tool"
const LIBSECRET := "libsecret"
const MAC := "keychain"
const WINDOWS := "credential-manager"
const FILE := "file"

## How long a keychain's tool is waited for. A locked keyring asks the
## person for their password, which can take a while, but not for ever.
const PATIENCE_MS := 30000

## Python's binding to libsecret, for a Linux without secret-tool (GNOME's
## desktops carry it; secret-tool is a package of its own). The key comes on
## the standard input; the arguments say only which key.
const LIBSECRET_PY := """
import sys
import gi
gi.require_version("Secret", "1")
from gi.repository import Secret
if sys.argv[1] == "probe":
    sys.exit(0)
op, name, data = sys.argv[1:4]
schema = Secret.Schema.new("diy.brickworks.Key", Secret.SchemaFlags.DONT_MATCH_NAME, {
    "application": Secret.SchemaAttributeType.STRING,
    "key": Secret.SchemaAttributeType.STRING,
    "data": Secret.SchemaAttributeType.STRING})
which = {"application": "brickworks", "key": name, "data": data}
if op == "store":
    sys.exit(0 if Secret.password_store_sync(schema, which, Secret.COLLECTION_DEFAULT,
        sys.argv[4], sys.stdin.readline().strip(), None) else 1)
if op == "lookup":
    found = Secret.password_lookup_sync(schema, which, None)
    if found is None:
        sys.exit(2)
    sys.stdout.write(found)
if op == "clear":
    Secret.password_clear_sync(schema, which, None)
"""

## Credential Manager, through advapi32's own calls: a generic credential
## kept on this computer alone (CRED_PERSIST_LOCAL_MACHINE, never roamed).
## Windows PowerShell 5.1, which every Windows 10 and 11 has, compiles it;
## the key comes on the standard input. %s: the credential's name, then
## store, lookup or clear.
const WINDOWS_PS := """
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class BrickworksCredential {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct Credential {
        public int Flags; public int Type; public string TargetName; public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize; public IntPtr CredentialBlob; public int Persist;
        public int AttributeCount; public IntPtr Attributes; public string TargetAlias;
        public string UserName;
    }
    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CredWrite(ref Credential credential, int flags);
    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32.dll")]
    static extern void CredFree(IntPtr buffer);
    public static bool Write(string target, string secret) {
        byte[] blob = Encoding.UTF8.GetBytes(secret);
        Credential c = new Credential();
        c.Type = 1; c.TargetName = target; c.UserName = "Brickworks"; c.Persist = 2;
        c.CredentialBlobSize = blob.Length; c.CredentialBlob = Marshal.AllocHGlobal(blob.Length);
        try { Marshal.Copy(blob, 0, c.CredentialBlob, blob.Length); return CredWrite(ref c, 0); }
        finally { Marshal.FreeHGlobal(c.CredentialBlob); }
    }
    public static string Read(string target) {
        IntPtr found;
        if (!CredRead(target, 1, 0, out found)) return null;
        try {
            Credential c = (Credential)Marshal.PtrToStructure(found, typeof(Credential));
            byte[] blob = new byte[c.CredentialBlobSize];
            Marshal.Copy(c.CredentialBlob, blob, 0, blob.Length);
            return Encoding.UTF8.GetString(blob);
        } finally { CredFree(found); }
    }
    public static bool Delete(string target) { return CredDelete(target, 1, 0); }
}
'@
$target = '%s'
switch ('%s') {
    'store' { if ([BrickworksCredential]::Write($target, [Console]::In.ReadLine())) { exit 0 }; exit 1 }
    'lookup' { $found = [BrickworksCredential]::Read($target); if ($null -eq $found) { exit 2 }; [Console]::Out.Write($found); exit 0 }
    'clear' { [void][BrickworksCredential]::Delete($target); exit 0 }
}
"""

## Programs a probe puts in place of a route's own (security, powershell),
## by name, to drive the route's protocol on a computer without it.
static var tools: Dictionary = {}

## The keychain new keys go to this run, once asked: a route, or FILE.
static var _route: String = ""
## Each key read this run, by its file's name; "" for one that could not be.
static var _held: Dictionary = {}
## Keychains that did not answer in PATIENCE_MS this run, not asked again:
## one waited for with every question would hold the app up each time.
static var _silent: Dictionary = {}
## The key table is read and written under this: a design's worker may ask
## for its provider's key.
static var _lock := Mutex.new()


## The key kept at [param path] (a key file's place in user://, which also
## names it in a keychain), or "".
static func read(path: String) -> String:
	_lock.lock()
	var key: String = _read(path)
	_lock.unlock()
	return key


## Whether a key is kept at [param path], without asking a keychain for it.
static func kept(path: String) -> bool:
	_lock.lock()
	var name: String = path.get_file()
	var is_kept: bool = not str(_held[name]).is_empty() if _held.has(name) \
		else not _marked(name).is_empty() or FileAccess.file_exists(path)
	_lock.unlock()
	return is_kept


## Keep [param key] at [param path]: in the keychain where one answers, else
## in the encrypted file. Returns where it went (a route, or FILE), "" when
## it could not be kept.
static func write(path: String, key: String) -> String:
	_lock.lock()
	var name: String = path.get_file()
	var was: String = _marked(name)
	var route: String = keychain()
	var went: String = ""
	if route != FILE and _put(route, name, key):
		went = route
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	else:
		# Nothing older left in a keychain to be read in this one's place.
		if not was.is_empty():
			_ask(was, "clear", name)
			_mark(name, "")
		if _write_file(path, key):
			went = FILE
	if not went.is_empty():
		_held[name] = key
	_lock.unlock()
	return went


## No copy of the key at [param path] left anywhere: not in the keychain
## that held it, the keychain this run would use, the file, or this run.
static func remove(path: String) -> void:
	_lock.lock()
	var name: String = path.get_file()
	_held.erase(name)
	var was: String = _marked(name)
	if not was.is_empty():
		_ask(was, "clear", name)
		_mark(name, "")
	# Asked even with no mark: a mark can be lost (the app's data folder
	# cleared by hand) while the keychain still holds the key.
	var route: String = keychain()
	if route != FILE and route != was:
		_ask(route, "clear", name)
	if FileAccess.file_exists(path):
		# On the web this path is the site's storage; DirAccess handles both.
		DirAccess.remove_absolute(path)
	_lock.unlock()


## Where the key at [param path] is kept: a route, FILE, or "" for none.
static func place(path: String) -> String:
	_lock.lock()
	var name: String = path.get_file()
	var where: String = _marked(name)
	if where.is_empty() and FileAccess.file_exists(path):
		where = FILE
	_lock.unlock()
	return where


## Where a key is kept, said for the person: [param where] is place()'s
## answer, or for a key not given yet, keychain()'s; [param on_web], in a
## browser, where FILE is the site's storage.
static func said(where: String, on_web: bool) -> String:
	match where:
		SECRET_TOOL, LIBSECRET:
			return ("Kept in this computer's keyring (the Secret Service, as GNOME Keyring "
				+ "or KWallet keeps it), locked with your login.")
		MAC:
			return "Kept in your login Keychain on this Mac, locked with your login."
		WINDOWS:
			return ("Kept in Windows Credential Manager on this computer, locked with your "
				+ "Windows sign-in.")
	if on_web:
		return ("Kept in this browser's storage for this site, scrambled but not secret: "
			+ "anyone using this browser could recover it, so untick Remember on a shared "
			+ "computer. No script but Brickworks' own may run on this site.")
	return ("Kept on this computer only, in a file of the app's own data encrypted to this "
		+ "computer, because no keyring answered here.")


## The keychain this run keeps keys in: one of the routes, or FILE.
static func keychain() -> String:
	_lock.lock()
	if _route.is_empty():
		_route = _find_keychain()
	var route: String = _route
	_lock.unlock()
	return route


static func _find_keychain() -> String:
	# A browser cannot start a program, and asking prints an engine error
	# into every visitor's console (ClaudeCode.found).
	if OS.has_feature("web"):
		return FILE
	var asked: String = OS.get_environment("BRICKWORKS_KEYCHAIN").strip_edges().to_lower()
	if asked == "off":
		return FILE
	if asked == MAC or asked.is_empty() and OS.get_name() == "macOS":
		return MAC if FileAccess.file_exists(_tool("security")) else FILE
	if asked == WINDOWS or asked.is_empty() and OS.get_name() == "Windows":
		return WINDOWS if FileAccess.file_exists(_tool("powershell")) else FILE
	if asked in [SECRET_TOOL, ""] and not _tool("secret-tool").is_empty():
		return SECRET_TOOL
	if asked in [LIBSECRET, ""] and not _tool("python3").is_empty() \
			and int(_run(_tool("python3"), ["-c", LIBSECRET_PY, "probe"])["code"]) == 0:
		return LIBSECRET
	return FILE


## Store [param key] as [param name] by [param route], and read it back:
## kept only when the keychain gives back what it was given.
static func _put(route: String, name: String, key: String) -> bool:
	var stored: Dictionary = _ask(route, "store", name, key)
	if int(stored["code"]) == 0:
		var back: Dictionary = _ask(route, "lookup", name)
		if int(back["code"]) == 0 and str(back["out"]).strip_edges() == key:
			_mark(name, route)
			return true
		# Kept, but not as given: not left there.
		_ask(route, "clear", name)
	# Not asked again this run: one that did not answer would be waited for
	# again with every key.
	_route = FILE
	push_warning("KeyStore: %s did not keep the key (%d): %s" % [route, int(stored["code"]),
		str(stored["err"]).replace(key, "…").strip_edges().left(200)])
	return false


## [param op] (store, lookup or clear) on the key [param name] by
## [param route]: {code, out, err, absent}. absent: the keychain answered,
## and holds no such key.
static func _ask(route: String, op: String, name: String, key: String = "") -> Dictionary:
	if _silent.has(route):
		return {"code": -1, "out": "", "err": "did not answer before", "absent": false}
	# This data folder's keys apart from another's: a probe's own data
	# folder never reads or overwrites the person's.
	var data: String = OS.get_user_data_dir().sha256_text().left(16)
	var label: String = "Brickworks: %s" % name.get_basename()
	var said: Dictionary = {}
	match route:
		SECRET_TOOL:
			var which: PackedStringArray = ["application", "brickworks", "key", name, "data", data]
			var args: PackedStringArray = [op]
			if op == "store":
				args.append("--label=" + label)
			args.append_array(which)
			# secret-tool reads the key to the end of its input.
			said = _run(_tool("secret-tool"), args, key, op == "store")
			said["absent"] = op == "lookup" and int(said["code"]) == 1 \
				and str(said["err"]).strip_edges().is_empty()
		LIBSECRET:
			var args: PackedStringArray = ["-c", LIBSECRET_PY, op, name, data]
			if op == "store":
				args.append(label)
			said = _run(_tool("python3"), args, key + "\n" if op == "store" else "")
			said["absent"] = int(said["code"]) == 2
		MAC:
			var account: String = "%s@%s" % [name, data]
			if op == "store":
				# `security -i` reads its commands from its input, so the key
				# (in hex, -X) is never an argument; its prompts go nowhere, so
				# closing its input ends it with nothing left to write to.
				said = _run(_tool("sh"), ["-c", "exec \"$0\" -i >/dev/null", _tool("security")],
					"add-generic-password -U -s Brickworks -a %s -X %s\n"
					% [account, key.to_utf8_buffer().hex_encode()], true)
			else:
				var args: PackedStringArray = ["find-generic-password" if op == "lookup"
					else "delete-generic-password", "-s", "Brickworks", "-a", account]
				if op == "lookup":
					args.append("-w")
				said = _run(_tool("security"), args)
			# 44: errSecItemNotFound.
			said["absent"] = int(said["code"]) == 44
		WINDOWS:
			var script: String = WINDOWS_PS % ["Brickworks/%s@%s" % [name, data], op]
			said = _run(_tool("powershell"), ["-NoProfile", "-NonInteractive",
				"-EncodedCommand", Marshalls.raw_to_base64(script.to_utf16_buffer())],
				key + "\n" if op == "store" else "")
			said["absent"] = int(said["code"]) == 2
		_:
			said = {"code": -1, "out": "", "err": "no keychain", "absent": false}
	if bool(said.get("late", false)):
		_silent[route] = true
	return said


## Where [param program] is: a probe's stand-in, the route's own place, or
## the first on PATH; "" where it is not.
static func _tool(program: String) -> String:
	if tools.has(program):
		return str(tools[program])
	match program:
		"security":
			return "/usr/bin/security"
		"sh":
			return "/bin/sh"
		"powershell":
			# Named whole: Windows looks in the folder the app was started
			# from before PATH, where anything could be called powershell.exe.
			return OS.get_environment("SystemRoot") \
				+ "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
	# An app started from a desktop's menu has only the system's PATH.
	for folder: String in OS.get_environment("PATH").split(":", false) + PackedStringArray([
			"/usr/bin", "/bin", "/usr/local/bin"]):
		if folder.is_absolute_path() and FileAccess.file_exists(folder.path_join(program)):
			return folder.path_join(program)
	return ""


## Run [param program] with [param args], [param given] on its input
## (closed after it when [param close]), and wait PATIENCE_MS for it at most:
## {code, out, err}, code -1 when it could not start or did not finish.
## Pipes that never wait: a read with nothing in it is empty.
static func _run(program: String, args: PackedStringArray, given: String = "",
		close: bool = false) -> Dictionary:
	var said: Dictionary = {"code": -1, "out": "", "err": ""}
	if program.is_empty():
		return said
	var started: Dictionary = OS.execute_with_pipe(program, args, false)
	if started.is_empty():
		return said
	var pipe: FileAccess = started["stdio"]
	var errors: FileAccess = started["stderr"]
	var pid: int = int(started["pid"])
	if not given.is_empty():
		pipe.store_buffer(given.to_utf8_buffer())
		pipe.flush()
	if close:
		pipe.close()
	var out := PackedByteArray()
	var err := PackedByteArray()
	var deadline: int = Time.get_ticks_msec() + PATIENCE_MS
	var running: bool = true
	while running:
		running = OS.is_process_running(pid)
		# Read as it runs, so a tool with more to say than a pipe holds is
		# never left waiting for room.
		if pipe.is_open():
			out.append_array(pipe.get_buffer(65536))
		err.append_array(errors.get_buffer(65536))
		if running:
			if Time.get_ticks_msec() > deadline:
				OS.kill(pid)
				OS.is_process_running(pid)
				said["late"] = true
				break
			OS.delay_msec(2)
	if pipe.is_open():
		pipe.close()
	errors.close()
	if not running:
		said["code"] = OS.get_process_exit_code(pid)
	said["out"] = out.get_string_from_utf8()
	said["err"] = err.get_string_from_utf8()
	return said


static func _read(path: String) -> String:
	var name: String = path.get_file()
	if _held.has(name):
		return str(_held[name])
	var route: String = _marked(name)
	if not route.is_empty():
		var asked: Dictionary = _ask(route, "lookup", name)
		var key: String = str(asked["out"]).strip_edges()
		if int(asked["code"]) == 0 and not key.is_empty():
			_held[name] = key
			return key
		if bool(asked["absent"]):
			# Deleted in the keychain by the person: as good as forgotten.
			_mark(name, "")
		elif not FileAccess.file_exists(path):
			# The keychain did not answer (locked, or gone): no key this run,
			# rather than a wait with every question.
			_held[name] = ""
			return ""
	var kept: String = _read_file(path)
	if kept.is_empty():
		return ""
	_held[name] = kept
	# Into the keychain, once, and out of the file.
	var into: String = keychain()
	if into != FILE and _put(into, name, kept):
		DirAccess.remove_absolute(path)
	return kept


static func _marked(name: String) -> String:
	if not FileAccess.file_exists(MARKS):
		return ""
	var marks := ConfigFile.new()
	if marks.load(MARKS) != OK:
		return ""
	return str(marks.get_value("kept", name, ""))


static func _mark(name: String, route: String) -> void:
	var marks := ConfigFile.new()
	if FileAccess.file_exists(MARKS):
		marks.load(MARKS)
	if route.is_empty():
		if marks.has_section_key("kept", name):
			marks.erase_section_key("kept", name)
	else:
		marks.set_value("kept", name, route)
	if marks.get_sections().is_empty():
		if FileAccess.file_exists(MARKS):
			DirAccess.remove_absolute(MARKS)
		return
	marks.save(MARKS)


static func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var head: PackedByteArray = FileAccess.get_file_as_bytes(path).slice(0, 4)
	if head.get_string_from_ascii() != ENCRYPTED:
		# Kept plain by the first slices: read once, and kept again encrypted
		# (or in the keychain, by _read).
		var plain: String = FileAccess.get_file_as_string(path).strip_edges()
		if not plain.is_empty():
			_write_file(path, plain)
		return plain
	var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _password())
	if file == null:
		# Another computer's, or this one's id changed: as good as no key.
		return ""
	var key: String = file.get_as_text().strip_edges()
	file.close()
	return key


static func _write_file(path: String, key: String) -> bool:
	var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE,
		_password())
	if file == null:
		return false
	file.store_string(key)
	file.close()
	return true


## This computer's id and this device's salt, hashed: what the key files are
## encrypted with. A browser has no id to give (asking prints an error).
static func _password() -> String:
	var salt: String = ""
	if FileAccess.file_exists(SALT):
		salt = FileAccess.get_file_as_string(SALT).strip_edges()
	if salt.is_empty():
		salt = Crypto.new().generate_random_bytes(32).hex_encode()
		var file: FileAccess = FileAccess.open(SALT, FileAccess.WRITE)
		if file != null:
			file.store_string(salt)
			file.close()
	var machine: String = "" if OS.has_feature("web") else OS.get_unique_id()
	return ("brickworks:%s:%s" % [machine, salt]).sha256_text()
