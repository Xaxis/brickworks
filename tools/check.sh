#!/usr/bin/env bash
# Everything that can be checked without a person looking at it.
#
#   tools/check.sh
#
# The Python suite covers the offline pipeline — geometry, connectivity,
# occupancy, the design validator. The Godot probes cover what only
# exists at runtime: search ranking, whether a model survives a save, and
# whether the stability model agrees with arrangements whose answer is
# known by inspection.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

echo "── python ──"
python3 -m pytest tests/ -q || fail=1

for probe in stability store; do
  echo "── $probe ──"
  godot --headless --path . --script "src/dev/${probe}_probe.gd" 2>&1 \
    | grep -viE '^$|Godot Engine|godotengine|TextServer|^  OK ' || true
  # shellcheck disable=SC2181
  godot --headless --path . --script "src/dev/${probe}_probe.gd" >/dev/null 2>&1 \
    || { echo "  FAILED"; fail=1; }
done

[ "$fail" = 0 ] && echo "all checks pass"
exit $fail
