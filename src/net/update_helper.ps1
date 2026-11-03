# Brickworks' update helper, on Windows: what the app cannot do to itself
# while it runs, since a running .exe cannot be replaced. src/net/updater.gd
# writes this beside its state and starts it as the app quits
# (docs/UPDATES.md). The same steps as update_helper.sh:
#
#   helper.ps1 MODE PID TARGET STAGED BACKUP MARKER VERSION ABOUT LOG -- LAUNCH...
#
# restart  wait for the app (PID) to end, then start LAUNCH.
# install  wait for it to end; put the STAGED folder in place of TARGET, the
#          old one kept as BACKUP; ask the copy now there its version (ABOUT
#          --about); start LAUNCH and wait for the new copy to write MARKER.
#          A copy that cannot say its version, or ends before it has
#          started, is taken away and BACKUP put back, then started saying so
#          (--update-failed=VERSION). The new copy takes BACKUP away itself.
# quit     as install, but nothing is started after: the app was quitting.
$ErrorActionPreference = "Continue"
$mode, $appPid, $target, $staged, $backup, $marker, $version, $about, $log = $args[0..8]
$launch = @($args | Select-Object -Skip 9)
if ($launch.Count -gt 0 -and $launch[0] -eq "--") { $launch = @($launch | Select-Object -Skip 1) }

function Say($line) {
  $stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
  Add-Content -LiteralPath $log -Value "$stamp helper: $line"
}

# An argument as CreateProcess reads it back: quoted when it has a space.
function Quoted($text) {
  if ($text -match '[\s"]') { return '"' + ($text -replace '"', '\"') + '"' }
  return $text
}

function Start-Launch([string[]]$more) {
  $all = @($launch) + @($more)
  $rest = @($all | Select-Object -Skip 1 | ForEach-Object { Quoted $_ })
  if ($rest.Count -gt 0) {
    return Start-Process -FilePath $all[0] -ArgumentList ($rest -join " ") -PassThru
  }
  return Start-Process -FilePath $all[0] -PassThru
}

# Moved, retried for a minute: another window of the app still running from
# the folder holds it, and so, for a moment, does a virus scanner.
function Move-Retried($from, $to) {
  for ($n = 0; $n -lt 60; $n++) {
    try {
      Move-Item -LiteralPath $from -Destination $to -ErrorAction Stop
      return $true
    } catch {
      Start-Sleep -Seconds 1
    }
  }
  Say "could not move $from to ${to}: $($_.Exception.Message)"
  return $false
}

$app = Get-Process -Id $appPid -ErrorAction SilentlyContinue
if ($app -and -not $app.WaitForExit(120000)) {
  Say "the app (pid $appPid) did not end in 120 s: nothing changed"
  exit 1
}

if ($mode -eq "restart") {
  $p = Start-Launch @()
  Say "restarted (pid $($p.Id))"
  exit 0
}

if (-not (Test-Path -LiteralPath $staged)) {
  Say "nothing staged at ${staged}: nothing changed"
  if ($mode -eq "install") { Start-Launch @() | Out-Null }
  exit 1
}

if ((Test-Path -LiteralPath $target) -and -not (Move-Retried $target $backup)) {
  Say "nothing changed: close Brickworks' other windows, and it is put in place next time"
  if ($mode -eq "install") { Start-Launch @("--update-failed=$version") | Out-Null }
  exit 1
}
if (-not (Move-Retried $staged $target)) {
  if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $target }
  if ($mode -eq "install") { Start-Launch @("--update-failed=$version") | Out-Null }
  exit 1
}
Say "put $version in place at $target"

function Put-Back($why) {
  Say "${why}: putting the old copy back"
  if (Test-Path -LiteralPath "$backup.failed") { Remove-Item -LiteralPath "$backup.failed" -Recurse -Force }
  Move-Retried $target "$backup.failed" | Out-Null
  if (Test-Path -LiteralPath $backup) { Move-Retried $backup $target | Out-Null }
  if ($mode -eq "install") { Start-Launch @("--update-failed=$version") | Out-Null }
  exit 1
}

# The copy now in place asked which version it is, as a person reporting a
# bug would: a copy that cannot start says nothing.
$said = "$log.about"
$asked = Start-Process -FilePath $about -ArgumentList "--headless -- --about" -PassThru `
  -NoNewWindow -RedirectStandardOutput $said
if (-not $asked.WaitForExit(120000)) {
  Stop-Process -Id $asked.Id -Force -ErrorAction SilentlyContinue
  Put-Back "the new copy did not say its version in 120 s"
}
$line = Get-Content -LiteralPath $said -ErrorAction SilentlyContinue | Where-Object { $_ -like "Brickworks *" } | Select-Object -First 1
if (-not ($line -like "Brickworks $version*")) {
  Put-Back "the new copy says '$line', not $version"
}
Remove-Item -LiteralPath $said -ErrorAction SilentlyContinue
Say "the new copy says it is $version"

if ($mode -eq "quit") { exit 0 }

$p = Start-Launch @()
Say "started $version (pid $($p.Id)); waiting for it to say it is up"
for ($n = 0; $n -lt 900; $n++) {
  if (Test-Path -LiteralPath $marker) {
    Say "$version is up"
    exit 0
  }
  if ($p.HasExited) {
    Put-Back "the new copy ended before its window was up"
  }
  Start-Sleep -Milliseconds 200
}
Say "the new copy is still starting after 180 s: left to it"
exit 0
