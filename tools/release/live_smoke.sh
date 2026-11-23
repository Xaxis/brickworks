#!/bin/bash
# live_smoke.sh: the live site looked at the moment a release goes live, and
# put back on the build before it when the release broke it (fastship,
# 2026-11-23). ship.sh asks `current` before it promotes, and runs `guard`
# once the domain serves the release.
#
#   live_smoke.sh current [DOMAIN]
#       The deployment DOMAIN (brickworks.diy) points at now, as Vercel says
#       (vercel inspect DOMAIN): its https://brickworks-XXXX-xaxis-projects.vercel.app
#       on stdout. Exit 0, or 1 when Vercel did not say.
#
#   live_smoke.sh check ORIGIN
#       A smoke that only reads, about a minute on a calm box. GETs first, each
#       cache-busted (?_smoke=), seconds: the home page is the site's (a header,
#       a main, a heading); /app names its build (/b/<sha>/); the gallery's
#       list (api/share?op=list) answers, and its first model with a picture
#       has its page, titled with its name, and that picture; Talk (/talk), on
#       a build that has it (its /talk.js), lists its threads, and on one that
#       has not "no Talk on this build" is said and nothing fails. Then, only
#       if every GET held, a browser under heavy, on SwiftShader, signed out,
#       that sends no request but a GET, HEAD or OPTIONS
#       (tools/web/live_smoke.mjs): the home page at two widths, the model
#       page with its picture drawn, Talk, and /app started to its first
#       screen. Never signs in, posts or writes a row: tools/web/check.mjs,
#       the deploy's own start check, is not used, as its browser is signed in
#       as the test account (browser.mjs) and it drives the view. A GET of
#       /talk on production may have the site write its house threads, once,
#       as any visitor's first look there would (api/_talk.js houseWrites).
#       Its last line: "live_smoke: passed ORIGIN (build SHA, Ns): ...",
#       "live_smoke: FAILED ORIGIN (build SHA, Ns): REASONS" or
#       "live_smoke: not checked ORIGIN: WHY". Exit 0 passed, 1 failed, 2 not
#       checked (heavy gave no slot in LIVE_SMOKE_HEAVY_WAIT, no browser):
#       no verdict on the site.
#
#   live_smoke.sh guard DOMAIN PREVIOUS_URL TAG
#       check https://DOMAIN; failed, once more after LIVE_SMOKE_AGAIN_WAIT s (a
#       flake); failed again, PREVIOUS_URL (what `current` said before TAG
#       was promoted) is checked on its own URL first: when it fails too, the
#       fault is not TAG's (the database, the box, the network) and nothing
#       is rolled back. Otherwise DOMAIN goes back to PREVIOUS_URL: the
#       production domain by `vercel rollback PREVIOUS_URL`, any other alias
#       by `vercel alias set PREVIOUS_URL DOMAIN`; then DOMAIN must serve
#       PREVIOUS's build (its /app names its /b/<sha>/, cache-busted) within
#       LIVE_SMOKE_SERVES_WAIT s, and it is checked again there. Written down
#       for the owner's console (/admin › Site) through release_live.sh's
#       site_release_live: a row tagged TAG-rolled-back with PREVIOUS's build
#       and a title that says TAG failed its live smoke and why, which lists
#       first, as what is live now. Every line of its own begins
#       "live_smoke: "; the one ship.sh copies into the release's log begins
#       "live_smoke: rolled back", and is said only once DOMAIN serves
#       PREVIOUS's build. A check's own lines are indented.
#       Exit 0 passed (first or second go); 3 rolled back, and PREVIOUS's build
#       passes there; 1 failed otherwise: rolled back with PREVIOUS failing
#       too, or not rolled back (PREVIOUS fails on its own URL as well, or the
#       rollback did not take: the "rolled back" line says which); 2 no
#       verdict (a check could not run), nothing done.
#
#   Exit 64: not asked right.
#
# vercel rollback (vercel@48; vercel.com/docs/instant-rollback): it points the
# production domains at a deployment that was production before (only those
# are eligible, which the one `current` named before the promotion is) and
# turns off auto-assignment of production domains, so a later production
# deploy does not take the domain by itself. A later `vercel promote` undoes
# that: it points the domains at the promoted build and turns auto-assignment
# back on. Brickworks never relies on auto-assignment (deploy.sh uploads with
# --skip-domain and promotes), so the next release's promote both puts it live
# and ends the rolled-back state. Environment variables are the rolled-back
# build's, as they were when it was made; cron definitions are its too. One
# rollback or promotion runs at a time a project (409 meanwhile): a refused
# one is asked again once after 30 s.
#
# Reads VERCEL_TOKEN and VERCEL_BYPASS from the environment, else the main
# checkout's .env; the team from .vercel/project.json, as deploy.sh's go_live.
# The bypass header goes to *.vercel.app origins only. Never prints a secret.
#   LIVE_SMOKE_VERCEL   the vercel command (npx --yes vercel@48)
#   LIVE_SMOKE_CHECK    the check guard runs ("this script" check)
#   LIVE_SMOKE_HEAVY    the heavy the browser runs under (~/.claude/claude-core/bin/heavy)
#   LIVE_SMOKE_BROWSER=0  the GETs alone, said in its passed line: to prove the
#                       rollback's own steps on a throwaway alias while heavy's
#                       queue is full; never in a release
#   LIVE_SMOKE_OUT      where the browser's pictures go (a fresh folder)
#   LIVE_SMOKE_HEAVY_WAIT (1200) LIVE_SMOKE_BROWSER_S (420) LIVE_SMOKE_AGAIN_WAIT (20)
#   LIVE_SMOKE_SERVES_WAIT (180) LIVE_SMOKE_POLL (5)
set -u
here=$(cd "$(dirname "$0")" && pwd)
W=$(cd "$here/../.." && pwd)
R=$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$W/.git")")
PRODUCTION=" brickworks.diy www.brickworks.diy "

usage() {
  echo "usage: live_smoke.sh current [DOMAIN] | check ORIGIN | guard DOMAIN PREVIOUS_URL TAG" >&2
  exit 64
}

secrets() {
  if [ -z "${VERCEL_TOKEN:-}" ] || [ -z "${VERCEL_BYPASS:-}" ]; then
    [ -f "$R/.env" ] && { set -a; . "$R/.env"; set +a; }
  fi
}

# vc SECONDS ARGS...: the vercel CLI as go_live runs it, the team named and the
# token given, for at most SECONDS. The bound is inside: `timeout N vc` would
# run whatever `vc` is on the PATH (the CLI installs one), not this function.
vc() {
  local scope cmd bound=$1; shift
  read -r -a cmd <<< "${LIVE_SMOKE_VERCEL:-npx --yes vercel@48}"
  scope=$(sed -n 's/.*"orgId":"\([^"]*\)".*/\1/p' "$W/.vercel/project.json" 2>/dev/null)
  [ -n "$scope" ] || scope=$(sed -n 's/.*"orgId":"\([^"]*\)".*/\1/p' "$R/.vercel/project.json" 2>/dev/null)
  (cd "$W" && timeout "$bound" "${cmd[@]}" "$@" --scope "$scope" --token "${VERCEL_TOKEN:-}" </dev/null)
}

# A host name from DOMAIN or https://DOMAIN/, or nothing.
host_of() {
  local h=${1#https://}; h=${h#http://}; h=${h%%/*}
  [[ "$h" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:[0-9]{1,5})?$ ]] && echo "$h"
}

# The headers a GET to [origin] takes: the bypass, for a deployment's own URL.
bypass_for() {
  case "$(host_of "$1")" in
    *.vercel.app) [ -n "${VERCEL_BYPASS:-}" ] && printf '%s\n' "-H" "x-vercel-protection-bypass: $VERCEL_BYPASS" ;;
  esac
}

# The build [origin] serves, by the /b/<sha>/ its /app names: the sha, or nothing.
build_of() {
  local headers=()
  mapfile -t headers < <(bypass_for "$1")
  curl -s --max-time 20 --connect-timeout 10 ${headers[@]+"${headers[@]}"} "${1%/}/app?_smoke=$EPOCHSECONDS$RANDOM" </dev/null \
    | grep -oE '/b/[0-9a-f]{7,40}/' | head -1 | sed 's#/b/##; s#/##'
}

current() {
  local domain said url
  domain=$(host_of "${1:-brickworks.diy}") || true
  [ -n "$domain" ] || usage
  said=$(vc 120 inspect "$domain" 2>&1)
  # "    url		https://brickworks-XXXX-xaxis-projects.vercel.app" in its General.
  url=$(sed -n 's#^[[:space:]]*url[[:space:]][[:space:]]*\(https://[a-z0-9.-]*\.vercel\.app\).*#\1#p' <<< "$said" | head -1)
  if [ -z "$url" ]; then
    echo "live_smoke: could not tell what $domain points at: $(grep -v '^[[:space:]]*$' <<< "$said" | tail -2 | tr '\n' ' ' | cut -c1-200)" >&2
    return 1
  fi
  echo "$url"
}

# ---------------------------------------------------------------------------
# check ORIGIN

check() {
  local origin host t0=$SECONDS nonce tmp out code fails=() talk=0 build="" commit model="" name="" said
  origin=${1%/}
  host=$(host_of "$origin") || true
  [[ "$origin" =~ ^https?:// ]] && [ -n "$host" ] && [ "$origin" = "${origin%%://*}://$host" ] || usage
  nonce="$EPOCHSECONDS$RANDOM"
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/live_smoke.XXXXXX")
  out=${LIVE_SMOKE_OUT:-}
  local headers=()
  mapfile -t headers < <(bypass_for "$origin")
  # GET [path] into $tmp/body: "STATUS TYPE" in $code (000 when nothing came), asked twice when nothing came.
  get() {
    local sep="?"; case "$1" in *\?*) sep="&" ;; esac
    for _ in 1 2; do
      code=$(curl -s -o "$tmp/body" -w '%{http_code} %{content_type}' --max-time "${LIVE_SMOKE_GET_S:-20}" --connect-timeout 10 \
        ${headers[@]+"${headers[@]}"} "$origin$1$sep""_smoke=$nonce" </dev/null) || true
      [ "${code%% *}" = 000 ] || break
      sleep 2
    done
    code=${code:-000}
  }
  status() { echo "${code%% *}"; }
  # The status said for a person: 000 is no answer at all.
  answer() { [ "$(status)" = 000 ] && echo "nothing within ${LIVE_SMOKE_GET_S:-20} s" || status; }
  fail() { fails+=("$1"); echo "  FAIL  $1"; }
  ok() { echo "  ok    $1"; }

  # The home page: the site's own, by its frame.
  get /
  if [ "$(status)" != 200 ]; then
    fail "the home page answers $(answer)"
  elif ! grep -qi '<header' "$tmp/body" || ! grep -qi '<main' "$tmp/body" || ! grep -qi '<h1' "$tmp/body"; then
    fail "the home page is not the site's: no header, main or heading in it (titled \"$(grep -oiE '<title>[^<]{0,80}' "$tmp/body" | head -1 | sed 's/<title>//I')\")"
  else
    ok "the home page answers 200 with the site's header, main and heading"
  fi
  # Its build: what /app names, and what version.json says.
  get /app
  if [ "$(status)" != 200 ]; then
    fail "/app answers $(answer)"
  else
    build=$(grep -oE '/b/[0-9a-f]{7,40}/' "$tmp/body" | head -1 | sed 's#/b/##; s#/##')
    if [ -n "$build" ]; then ok "/app answers 200, naming its build /b/$build/"; else fail "/app names no build (/b/<sha>/): not the app's page"; fi
  fi
  get /version.json
  commit=$(sed -n 's/.*"commit": *"\([0-9a-f]*\)".*/\1/p' "$tmp/body" 2>/dev/null | head -1)
  # The gallery's list, and its first model with a picture.
  get "/api/share?op=list&page=1"
  if [ "$(status)" != 200 ]; then
    fail "the gallery's list (/api/share?op=list) answers $(answer)"
  else
    said=$(python3 -I -c '
import json, re, sys
try:
    models = json.load(open(sys.argv[1])).get("models") or []
except Exception:
    print("not json"); sys.exit()
for one in models:
    if one.get("image") and re.fullmatch(r"[A-Za-z0-9]{10}", str(one.get("id", ""))):
        print("model", one["id"], " ".join(str(one.get("name") or "").split())); sys.exit()
print("none", len(models))' "$tmp/body")
    case "$said" in
      model\ *) model=$(cut -d' ' -f2 <<< "$said"); name=$(cut -d' ' -f3- <<< "$said")
        ok "the gallery's list answers; its first model with a picture is $model, \"$name\"" ;;
      "not json") fail "the gallery's list (/api/share?op=list) is not JSON" ;;
      *) fail "the gallery's list has no model with a picture (${said#none } models)" ;;
    esac
  fi
  # That model's page: its title, its picture.
  if [ -n "$model" ]; then
    get "/m/$model"
    if [ "$(status)" != 200 ]; then
      fail "/m/$model answers $(answer)"
    else
      said=$(NAME="$name" python3 -I -c '
import html, os, re, sys
page = open(sys.argv[1], encoding="utf-8", errors="replace").read()
title = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
title = " ".join(html.unescape(re.sub(r"<[^>]+>", "", title.group(1))).split()) if title else ""
picture = re.search(r"class=\"picture\"[^>]*>.*?<img src=\"([^\"]+)\"", page, re.S)
print(picture.group(1) if picture else "-")
print(title)' "$tmp/body")
      local picture title
      picture=$(head -1 <<< "$said"); title=$(sed -n 2p <<< "$said")
      if [ "$title" != "$name" ]; then
        fail "/m/$model is titled \"${title:0:80}\", where the gallery calls it \"${name:0:80}\""
      elif [ "$picture" = "-" ]; then
        fail "/m/$model has no picture in its page"
      else
        case "$picture" in /*) picture="$origin$picture" ;; esac
        # The bypass only to this origin: a picture kept elsewhere is asked without it.
        local pic mine=()
        [ "${picture#"$origin"/}" != "$picture" ] && mine=(${headers[@]+"${headers[@]}"})
        pic=$(curl -s -o "$tmp/picture" -w '%{http_code} %{content_type} %{size_download}' --max-time 20 --connect-timeout 10 \
          ${mine[@]+"${mine[@]}"} "$picture" </dev/null) || true
        local bytes=${pic##* }; [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
        case "$pic" in
          "200 image/"*) if [ "$bytes" -gt 1000 ]; then ok "/m/$model is titled \"$name\", its picture answers (${pic#200 } bytes)"
                         else fail "/m/$model's picture is $bytes bytes"; fi ;;
          *) fail "/m/$model's picture (${picture#"$origin"}) answers ${pic%% *}" ;;
        esac
      fi
    fi
  fi
  # Talk, where this build has it.
  get /talk.js
  case "$code" in
    "200 application/javascript"*|"200 text/javascript"*)
      talk=1
      get /talk
      if [ "$(status)" != 200 ]; then
        fail "Talk (/talk) answers $(answer)$(grep -qF 'Talk is not open' "$tmp/body" && echo ': "Talk is not open on Brickworks yet" (its SQL is not applied)')"
      elif ! grep -q 'data-talk=' "$tmp/body" || ! grep -qi '<h1' "$tmp/body"; then
        fail "Talk (/talk) is not Talk's page (no [data-talk] or heading)"
      else
        ok "Talk (/talk) answers 200 with its list ($(grep -o 'class="talk-row"' "$tmp/body" | wc -l) threads)"
      fi ;;
    404*) ok "no Talk on this build (/talk.js answers 404)" ;;
    *) fail "Talk's script (/talk.js) answers $code" ;;
  esac

  # The browser, only over pages that answered.
  local verdict=0 why="" gets=""
  if [ ${#fails[@]} -gt 0 ]; then
    echo "  (the browser does not look: the pages' GETs failed)"
    verdict=1
  elif [ "${LIVE_SMOKE_BROWSER:-1}" = 0 ]; then
    echo "  (the browser does not look: LIVE_SMOKE_BROWSER=0, the GETs alone)"
    gets=" (GETs only)"
  else
    local browser=() look lcode
    # Its pictures: kept in LIVE_SMOKE_OUT, else in a folder of their own that a pass takes away.
    if [ -n "$out" ]; then mkdir -p "$out"; else out=$(mktemp -d "${TMPDIR:-/tmp}/live_smoke_pictures.XXXXXX"); fi
    if [ ${#headers[@]} -gt 0 ]; then export BW_BYPASS="$VERCEL_BYPASS"; else unset BW_BYPASS; fi
    [ "$talk" = 1 ] && browser+=(--talk)
    look=$(cd "$W" && BOX_HEAVY_WAIT=${LIVE_SMOKE_HEAVY_WAIT:-1200} "${LIVE_SMOKE_HEAVY:-$HOME/.claude/claude-core/bin/heavy}" \
      timeout "${LIVE_SMOKE_BROWSER_S:-420}" node tools/web/live_smoke.mjs --origin="$origin" --model="$model" --name="$name" \
      "${browser[@]}" --out="$out" 2>&1 </dev/null); lcode=$?
    grep -E '^  (ok|FAIL) |^  \(held back' <<< "$look"
    case $lcode in
      0) ;;
      1) verdict=1
         while IFS= read -r line; do fails+=("${line#  FAIL  }"); done < <(grep '^  FAIL  ' <<< "$look" | sed 's/  \[[0-9.]*s\]$//') ;;
      *) verdict=2
         why=$(grep -E '^heavy: no slot|^live_smoke.mjs: ' <<< "$look" | tail -1)
         [ -n "$why" ] || why="the browser ended with exit $lcode$( [ "$lcode" = 124 ] && echo ", past its ${LIVE_SMOKE_BROWSER_S:-420} s")"
         echo "  (the browser could not look: $why)" ;;
    esac
    if [ $verdict = 0 ] && [ -z "${LIVE_SMOKE_OUT:-}" ]; then rm -rf "$out"
    elif [ -n "$(ls -A "$out" 2>/dev/null)" ]; then echo "  (its pictures: $out)"; fi
  fi
  rm -rf "$tmp"
  local about="build ${build:-none}${commit:+ of $commit}, $((SECONDS - t0))s"
  if [ ${#fails[@]} -gt 0 ]; then
    local reasons="" one
    for one in "${fails[@]}"; do reasons="${reasons:+$reasons; }$one"; done
    echo "live_smoke: FAILED $origin ($about): ${reasons:0:600}"
    return 1
  fi
  if [ $verdict = 2 ]; then
    echo "live_smoke: not checked $origin: $why"
    return 2
  fi
  echo "live_smoke: passed $origin ($about)$gets: home, /m/$model, /app$([ "$talk" = 1 ] && echo ", Talk" || echo "; no Talk on this build")"
  return 0
}

# ---------------------------------------------------------------------------
# guard DOMAIN PREVIOUS_URL TAG

# One check of [origin], its lines indented: its exit in $code and its last line in $last.
run_check() {
  local cmd lines
  if [ -n "${LIVE_SMOKE_CHECK:-}" ]; then read -r -a cmd <<< "$LIVE_SMOKE_CHECK"; else cmd=(bash "$here/live_smoke.sh" check); fi
  lines=$("${cmd[@]}" "$1" 2>&1 </dev/null); code=$?
  sed 's/^/  /' <<< "$lines"
  last=$(grep '^live_smoke: ' <<< "$lines" | tail -1)
}
# Why a check failed, from its last line.
reason_of() { local r=${1#*): }; [ "$r" != "$1" ] && echo "$r" || echo "${1#live_smoke: }"; }

guard() {
  local domain previous tag code last first prev_build said moved="" t0=$SECONDS
  domain=$(host_of "${1:-}") || true; previous=${2%/}; tag=$(tr '[:upper:]' '[:lower:]' <<< "${3:-}")
  [ -n "$domain" ] && [[ "$previous" =~ ^https://[a-z0-9.-]+\.vercel\.app$ ]] && [[ "$tag" =~ ^[a-z0-9][a-z0-9._-]{0,28}$ ]] || usage
  echo "live_smoke: $tag on $domain, checked; $previous is the build before it"
  run_check "https://$domain"
  if [ $code = 0 ]; then echo "live_smoke: $domain passed its live smoke ($tag, $((SECONDS - t0)) s)"; return 0; fi
  local code1=$code; first=$last
  echo "live_smoke: $domain did not pass ($(reason_of "$first" | cut -c1-200)); once more in ${LIVE_SMOKE_AGAIN_WAIT:-20} s"
  sleep "${LIVE_SMOKE_AGAIN_WAIT:-20}"
  run_check "https://$domain"
  if [ $code = 0 ]; then echo "live_smoke: $domain passed its live smoke on its second go ($tag, $((SECONDS - t0)) s)"; return 0; fi
  if [ $code1 != 1 ] || [ $code != 1 ]; then
    echo "live_smoke: no verdict on $domain ($(reason_of "$last" | cut -c1-200)): nothing rolled back"
    return 2
  fi
  local why; why=$(reason_of "$last")
  # The build before, on its own URL: failing too, the fault is not this release's.
  echo "live_smoke: $domain failed twice; $previous, the build before, checked on its own URL"
  run_check "$previous"
  if [ $code != 0 ]; then
    echo "live_smoke: FAILED, not rolled back: $domain fails its live smoke ($why), and $previous $([ $code = 1 ] && echo "fails it too ($(reason_of "$last" | cut -c1-200))" || echo "could not be checked"): what is live stays"
    return 1
  fi
  prev_build=$(sed -n 's/.*(build \([0-9a-f]\{7,40\}\).*/\1/p' <<< "$last")
  [ -n "$prev_build" ] || prev_build=$(build_of "$previous")
  case "$PRODUCTION" in
    *" $domain "*) moving() { vc 300 rollback "$previous" --yes --timeout 3m 2>&1; } ;;
    *) moving() { vc 120 alias set "$previous" "$domain" 2>&1; } ;;
  esac
  # A refusal may come after the move was made (the CLI's own wait ran out):
  # the domain serving the build before is the answer, whatever was said.
  if ! said=$(moving) && [ "$(build_of "https://$domain")" != "$prev_build" ]; then
    echo "live_smoke: the first ask to move $domain was refused ($(tail -1 <<< "$said" | cut -c1-200)); again in ${LIVE_SMOKE_REFUSED_WAIT:-30} s"
    sleep "${LIVE_SMOKE_REFUSED_WAIT:-30}"
    if ! said=$(moving) && [ "$(build_of "https://$domain")" != "$prev_build" ]; then
      echo "live_smoke: FAILED, could not roll $domain back to $previous: $(tail -2 <<< "$said" | tr '\n' ' ' | cut -c1-300)"
      return 1
    fi
  fi
  # Moved is not served: done once the domain names the build before's files.
  local until=$((SECONDS + ${LIVE_SMOKE_SERVES_WAIT:-180})) now=""
  while :; do
    now=$(build_of "https://$domain")
    [ -n "$prev_build" ] && [ "$now" = "$prev_build" ] && { moved=1; break; }
    [ $SECONDS -lt $until ] || break
    sleep "${LIVE_SMOKE_POLL:-5}"
  done
  if [ -z "$moved" ]; then
    echo "live_smoke: FAILED, asked to roll $domain back to $previous, but it serves ${now:-nothing} (not ${prev_build:-a build}) after ${LIVE_SMOKE_SERVES_WAIT:-180} s"
    return 1
  fi
  run_check "https://$domain"
  local after=$code after_why; after_why=$(reason_of "$last")
  # For the owner's console: what is live now, and why.
  local spec title
  spec=$(mktemp -d "${TMPDIR:-/tmp}/live_smoke_spec.XXXXXX")
  title="$tag failed its live smoke on $domain twice (${why:0:400}) and was rolled back: $domain serves $prev_build again"
  if [ $after = 0 ]; then title="$title, which passes the smoke"; else title="$title, which fails the smoke too (${after_why:0:300})"; fi
  echo "$title" > "$spec/title"; : > "$spec/units"
  "$here/release_live.sh" "${tag}-rolled-back" "$prev_build" "$spec" 2>&1 | sed 's/^/  /'
  rm -rf "$spec"
  echo "live_smoke: rolled back $domain to $previous (build $prev_build): $tag failed its live smoke twice: ${why:0:300}; the build before $([ $after = 0 ] && echo "passes there" || echo "fails there too: ${after_why:0:200}") ($((SECONDS - t0)) s)"
  [ $after = 0 ] && return 3
  return 1
}

case "${1:-}" in
  current) [ $# -le 2 ] || usage; secrets; current "${2:-brickworks.diy}" ;;
  check) [ $# -eq 2 ] || usage; secrets; check "$2" ;;
  guard) [ $# -eq 4 ] || usage; secrets; guard "$2" "$3" "$4" ;;
  *) usage ;;
esac
