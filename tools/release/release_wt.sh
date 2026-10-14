#!/bin/bash
# release_wt.sh NAME REF
# A worktree that can export, deploy and run the browser checks: the big
# untracked folders linked from the main checkout and the Vercel project
# link copied. A bare `git worktree add` lacks them, so the deploy fails
# with "no geometry in assets/generated/parts".
set -eu
R=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)"); W=$R/.claude/worktrees/$1
[ -d "$W" ] || git -C $R worktree add -q "$W" -b "$1" "$2"
ln -sfn $R/assets/generated "$W/assets/generated"
ln -sfn $R/node_modules "$W/node_modules"
ln -sfn $R/vendor "$W/vendor"
[ -e "$W/tools/web/node_modules" ] || ln -s $R/tools/web/node_modules "$W/tools/web/node_modules"
mkdir -p "$W/.vercel"; cp $R/.vercel/project.json "$W/.vercel/project.json"
echo "$W at $(git -C "$W" log --oneline -1)"
