# Rules for an agent working a unit of Brickworks

Every agent brief says "read tools/release/AGENT_RULES.md first" and then only
what is particular to its unit: where it works, its ports, its scratch folder,
the problem, the proof. Each rule here was learned from a real incident; the
date says when.

## The unit
- One bounded unit, then stop. **Do it yourself: never spawn subagents.**
  The owner watches the agent count, and eight subagents appeared under one
  unit on 2026-10-20. Read in sequence, or ask the lead for help. Commit, then end the final message with exactly
  one line `ready: <sha>` or `not ready: <sha>`.
- The final report: the ready line's sha first, then at most 20 lines (what
  changed, each check with its numbers, what is left). Longer reports were cut
  off and needed asking for again (2026-10-19).
- Time-box as the brief says (3-4 hours). Land what is proven by then rather
  than chase one more experiment (2026-10-15). If the proof will run past it,
  say so once with an estimate, and run only the final checks after that: no
  more code changes (2026-10-19).
- Done means proven: report numbers you watched, not expectations. A probe
  that printed "SKIPPED" proved nothing.

## Git
- Commit as the user only:
  `git -c user.name=Xaxis -c user.email=william.neeley@gmail.com commit -F <msgfile>`.
  No assistant attribution of any kind. Messages lead with why, short sentences.
- Stage only your own paths, never `git add -A`.
- **Commit at least every hour**, a `WIP:` commit if need be. One agent worked
  five hours with nothing committed (2026-10-19). Committing changes no file,
  so a running sweep is unaffected.
- Never push, never touch main or a rel-* branch, never deploy production. A
  preview deploy only by unit_preview.sh (below) or where the brief says.
  The lead merges and ships.
- When told main moved under you, `git merge main` and resolve; take main's
  side of anything main fixed (two units fixed the same check twice,
  2026-10-19).

## The box
- Probes run as `tools/probe.sh NAME` (it reads the probe's header: headless
  in a heavy slot, or windowed on the GPU). Every other Godot run gets its own
  XDG_DATA_HOME. Never touch ~/.local/share/godot/app_userdata/Brickworks/.
- CPU-heavy work under `~/.claude/claude-core/bin/heavy`, GPU work under
  `~/.claude/claude-core/bin/gpu`. When either waits, wait: `--status` says
  why. Never bypass, never give your jobs a label of their own, never set
  BOX_HEAVY_PRIORITY (the release's alone).
- At most 2 heavy jobs of yours at once; sweeps at most 3 shards (2 when
  another agent sweeps). One SwiftShader browser at a time: each burns about
  7 cores, and three at once held a release at the gate (2026-10-19).
- **Take the GPU per job, not per batch.** A batch that holds the lease for
  its whole run held both GPU slots for 45 minutes while a probe waited
  (2026-10-19). Wrap each design, render or windowed probe on its own.
- **A measurement longer than an hour is the lead's, not yours.** An agent
  sat four hours waiting on a 44-design proof run, doing nothing, and the
  owner asked why anything had been running that long (2026-10-20). Prove
  the change on something short (a probe, the tune half's first few), then
  commit and hand over: the exact command, what it writes, how to read the
  result and the bar for ready. Then stop. The lead runs it and reads it,
  or starts a short agent to.
- **Never end your turn while a job of yours runs.** A background job's notice
  does not wake an agent that has gone idle: three agents sat idle for hours
  on 2026-10-19 (ownedsets 3.5 h, then studioio and tabwalk) waiting for one.
  Start a long job with run_in_background (no trailing `&` inside it: that
  detaches it), note its PID, then wait in the foreground on that PID, ten
  minutes a call, as often as it takes:
  `timeout 590 tail --pid=PID -f /dev/null` (it ends when the job does). Or
  keep working on something else and check the job between steps. Never loop
  on a file or spin (`read -t` on /dev/zero spun a core, 2026-10-16). Give
  every run a timeout; a timeout includes the time it waits in heavy's or the
  GPU's queue.
- Never `pgrep -f`/`pkill -f` a pattern that appears in your own command line.
  Kill only processes you started, by PID. Stop every server you start.
- A worktree you make for yourself (a base build to compare against) is
  locked at once: `git worktree lock --reason "<you>: base" <path>`, and
  removed by you when you finish. Unlocked at main with nothing running in it,
  tools/release/clean_worktrees.sh takes it for finished work and removes it
  (animaudit's base, 2026-10-20).
- Scratch files only in the scratch folder the brief names; ports only in the
  range it names (two agents once measured each other's build on one port).
- Never run the full suite (tools/check.sh); run what
  `~/.claude/claude-core/bin/featuremap affected` lists, and your own checks.

## The product
- **A new probe goes on one line of tools/suite/headless.txt or
  windowed.txt** (as its `##` header runs it), or of out.txt with why it is
  not run. `tools/check.sh --lists` must pass before you send ready: four units
  on 2026-10-23 forgot, and each merge stopped at the gate.
- **SQL that replaces another file's function** adds one line to
  supabase/later.tsv (tab-separated: the earlier file, the function, the later
  file, words only the later body has), never to tools/apply_sql.mjs. SQL is
  additive and server-only, dry-run first, and applied by the lead, not you.
- Never change the app's on-screen interface (layout, controls, wording a
  person sees) unless the brief says the owner asked for exactly that change.
- The website follows docs/DESIGN_SYSTEM.md: the shared components in
  web/site.css, no per-page control styles. Before replacing a control, grep
  tools/web/*.mjs and src/dev/*.gd for its old ids. Look at what you change at
  390 and 1280 px in light and dark.
- **A new browser flow is wired into tools/release/preview_checks.sh** (or
  marked there `# local only: NAME` with why) and, where it can, run against a
  deployment before ready. Two flows proven only against the local server
  held a release three times on a real deployment (2026-10-19). ship.sh holds
  a release with an unwired new flow.
- **A unit that changes web/, api/ or tools/web/ runs
  `tools/release/unit_preview.sh <its worktree>` on its branch before
  ready** (with `RELEASE_OUT` in its scratch folder), and puts its
  `pass`/`FAIL` lines in its report. It deploys a preview, never
  production. Four release previews held on 2026-10-22, about an hour
  each, every time on a check that read markup a unit had changed.
- A feature that runs every frame or on a timer: prove a big model's step,
  orbit and select-all cost unchanged (cad_frames.mjs --gate).
- Add, rename or remove a feature: update .claude/skills/verify/
  (`/mnt/Projects/claude-core/bin/featuremap generate --write`, and a recipe).
- Supabase is production: additive changes only. Secrets live in .env: never
  print them. Claude Code sessions start as `env -u ANTHROPIC_API_KEY claude`.
- Generated data under assets/generated/ is shared: write a changed copy inside
  your worktree and say what must be regenerated or uploaded.
- "LEGO®" only as an adjective. Rebrickable at most once a day. No BrickBench
  submission or MCP registry listing. Don't touch /mnt/Projects/Reelwright.
