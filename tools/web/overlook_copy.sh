#!/bin/bash
# overlook_copy.sh : bring the site's copy of Overlook's visit counter
# (web/ov/s.js and v.js) up to the one Overlook serves.
#
# The counter is Overlook's script, and the site serves it as its own: the
# site's and the app's security policy runs no script from anywhere else
# (tools/deploy.sh), because a script from another server runs with the
# site's storage, where a person's own AI key is kept in the browser. A copy
# here changes only when this is run and the copy is read and committed;
# the counter's hits still go to Overlook (data-api on each page's tag).
# Run it when Overlook's counter changes, and read the difference before
# committing it: it is code that will run beside the key.
set -euo pipefail
cd "$(dirname "$0")/../.."
for name in s.js v.js; do
  got=$(mktemp)
  curl -fsS "https://overlook.technology/$name" -o "$got"
  { printf '/* Overlook'"'"'s visit counter, https://overlook.technology/%s as served %s,\n' "$name" "$(date -u +%F)"
    printf '   kept here by tools/web/overlook_copy.sh: the site runs no script from elsewhere. */\n'
    cat "$got"; } > "web/ov/$name"
  rm -f "$got"
done
git diff --stat -- web/ov
