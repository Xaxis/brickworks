#!/bin/bash
# resend_webhook.sh [--check] : Resend tells brickworks.diy what became of
# each mail it sent (delivered, bounced, complained) by a webhook to
# https://brickworks.diy/api/otp?op=mail_event (api/_console_mail.js, the
# owner's console at /admin#mail). This sets that webhook up, once, on the
# Resend team that sends brickworks.diy's mail, and puts its signing secret
# in Vercel's production env as RESEND_WEBHOOK_SECRET and in .env.
#
# Why a webhook: production's RESEND_API_KEY may only send, and a key that
# can read mail is the team's full-access key, which every product on the
# team shares. That key is read here from RESEND_ADMIN_KEY in this shell,
# used for these calls alone, and never put in any deployment's env.
#
# Run it once a release with the op is live: it asks live first (404 "takes
# no mail events" without a secret, 401 with one; anything else, it stops).
# The next deployment made after it carries the secret: production gets it
# with the next release, or at once with --redeploy.
#
#   --check     reads only: the team, its webhooks, live's answer, the env.
#   --redeploy  after setting the secret, redeploys production's build so it
#               reads it now.
set -u
here=$(cd "$(dirname "$0")" && pwd)
R=$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)")
check=0; redeploy=0
for a in "$@"; do
  case "$a" in
    --check) check=1 ;;
    --redeploy) redeploy=1 ;;
    *) echo "usage: resend_webhook.sh [--check] [--redeploy]"; exit 2 ;;
  esac
done
ENDPOINT="https://brickworks.diy/api/otp?op=mail_event"
EVENTS='["email.sent","email.delivered","email.delivery_delayed","email.bounced","email.complained","email.failed","email.suppressed"]'
[ -n "${RESEND_ADMIN_KEY:-}" ] || {
  echo "resend_webhook: give the full-access key of the Resend team that sends brickworks.diy's mail as RESEND_ADMIN_KEY in this shell"
  exit 1; }
api() { curl -s --max-time 30 "$@" -H "Authorization: Bearer $RESEND_ADMIN_KEY" -H "Content-Type: application/json" </dev/null; }
field() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)" 2>/dev/null; }

# The right team: the one brickworks.diy is a domain of.
domains=$(api https://api.resend.com/domains)
case "$(field 'd.get("name") or " ".join(x["name"] for x in d.get("data", []))' <<< "$domains")" in
  restricted_api_key) echo "resend_webhook: that key may only send; it needs full access"; exit 1 ;;
  *brickworks.diy*) echo "resend_webhook: the team sends brickworks.diy's mail" ;;
  *) echo "resend_webhook: brickworks.diy is not a domain of that key's team"; exit 1 ;;
esac

# Live takes the op.
said=$(curl -s --max-time 30 -w ' %{http_code}' -X POST "$ENDPOINT" -H "Content-Type: application/json" -d '{}' </dev/null)
case "${said##* }:$said" in
  404:*"takes no mail events"*) live="takes the op, with no secret yet" ;;
  401:*"not from Resend"*) live="takes the op, with a secret" ;;
  *) echo "resend_webhook: live does not take mail events yet (${said:0:160}): run it after the release"; exit 1 ;;
esac
echo "resend_webhook: live $live"

# The webhook, if there is one already.
id=$(api https://api.resend.com/webhooks | field "next((w['id'] for w in d.get('data', []) if w.get('endpoint') == '$ENDPOINT'), '')")
if [ -n "$id" ]; then
  echo "resend_webhook: the webhook is there ($id)"
  secret=$(api "https://api.resend.com/webhooks/$id" | field 'd.get("signing_secret", "")')
elif [ $check = 1 ]; then
  echo "resend_webhook: no webhook to $ENDPOINT yet"; exit 0
else
  made=$(api -X POST https://api.resend.com/webhooks -d "{\"endpoint\":\"$ENDPOINT\",\"events\":$EVENTS}")
  id=$(field 'd.get("id", "")' <<< "$made")
  secret=$(field 'd.get("signing_secret", "")' <<< "$made")
  [ -n "$id" ] || { echo "resend_webhook: Resend would not make it: ${made:0:300}"; exit 1; }
  echo "resend_webhook: made the webhook ($id)"
fi
case "$secret" in whsec_*) ;; *) echo "resend_webhook: Resend gave no signing secret for $id"; exit 1 ;; esac

kept=$(grep -m1 '^RESEND_WEBHOOK_SECRET=' "$R/.env" 2>/dev/null | cut -d= -f2-)
if [ "$kept" = "$secret" ]; then
  echo "resend_webhook: .env has its secret"
  [ $check = 1 ] && exit 0
elif [ $check = 1 ]; then
  echo "resend_webhook: .env lacks its secret"; exit 0
else
  grep -v '^RESEND_WEBHOOK_SECRET=' "$R/.env" > "$R/.env.resend_webhook" && echo "RESEND_WEBHOOK_SECRET=$secret" >> "$R/.env.resend_webhook" \
    && mv "$R/.env.resend_webhook" "$R/.env" && echo "resend_webhook: .env has its secret now"
fi

# Vercel's production env (which unit previews override with the checks' own).
cd "$R" || exit 1
[ -n "${VERCEL_TOKEN:-}" ] || { set -a; . "$R/.env"; set +a; }
npx --yes vercel@48 env rm RESEND_WEBHOOK_SECRET production --yes --token "$VERCEL_TOKEN" </dev/null >/dev/null 2>&1
if printf %s "$secret" | npx --yes vercel@48 env add RESEND_WEBHOOK_SECRET production --token "$VERCEL_TOKEN" >/dev/null 2>&1; then
  echo "resend_webhook: Vercel's production env has its secret: deployments made from now on read it"
else
  echo "resend_webhook: could not set RESEND_WEBHOOK_SECRET in Vercel's production env"; exit 1
fi
if [ $redeploy = 1 ]; then
  npx --yes vercel@48 redeploy https://brickworks.diy --target production --token "$VERCEL_TOKEN" </dev/null 2>&1 | tail -3
fi
exit 0
