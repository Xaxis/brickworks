#!/usr/bin/env bash
# Write tests/fixtures/elements/pipeline.json: what the Python mesh pipeline
# makes of every fixture the element maker wrote and of the library parts
# in tests/fixtures/elements/library.txt. src/dev/element_files_probe.gd
# holds the app's own build of each against it, byte for byte.
#
#   tools/element_pipeline.sh                 # with a python that has numpy
#   PYTHON=/path/to/venv/bin/python tools/element_pipeline.sh
#
# Needs numpy and scipy (see .claude/skills/verify/features/pipeline.md).
set -euo pipefail
cd "$(dirname "$0")/.."
here=tests/fixtures/elements
library=()
while read -r id; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  library+=("vendor/ldraw/parts/$id.dat")
done < "$here/library.txt"
exec "${PYTHON:-python3}" tools/build_custom.py "$here"/*.dat "${library[@]}" \
  --summary "$here/pipeline.json"
