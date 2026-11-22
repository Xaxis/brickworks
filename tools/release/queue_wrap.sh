#!/bin/bash
# queue_wrap.sh: sourced by the tools that queue in heavy themselves (tools/probe.sh,
# tools/release/unit_preview.sh, tools/release/ci_gate.sh). It refuses at once when
# the run sits under a coreutils `timeout` of under 6 h with no heavy or gpu
# between: that timeout counts heavy's queue, and under a release's solo checks the
# wait passes hours, so the run dies at exit 124 without starting. On 11-22 three
# unit previews, a gate run's eight probes and a ci_gate went that way, after the
# unit rules had said so in words. A timeout under heavy (`heavy timeout 1800 …`,
# ci_gate's own re-run) bounds the run alone and is fine; so is PROBE_TIMEOUT.
# ALLOW_QUEUE_TIMEOUT=1 lets one through.

queue_wrap_seconds() {   # DURATION as coreutils timeout reads it: 90, 1.5h, 30m, 2d
  awk -v d="$1" 'BEGIN { n = d + 0; u = substr(d, length(d));
    if (u == "m") n *= 60; else if (u == "h") n *= 3600; else if (u == "d") n *= 86400;
    printf "%d", n }'
}

queue_wrap_check() {
  [ "${ALLOW_QUEUE_TIMEOUT:-}" = 1 ] && return 0
  # Inside a slot already: heavy sets BOX_HEAVY_HELD for its job (ci_gate reads it
  # the same way), gpu sets BOX_GPU_LEASE. A timeout above that bounds the run.
  [ -n "${BOX_HEAVY_HELD:-}" ] || [ -n "${BOX_GPU_LEASE:-}" ] && return 0
  local pid=$$ hops=0 short="" args a0 a1 stat ppid
  while [ "$pid" -gt 1 ] && [ $hops -lt 16 ]; do
    mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || break
    a0=$(basename -- "${args[0]:-}"); a1=$(basename -- "${args[1]:-}")
    case "$a0 $a1" in
      heavy\ *|gpu\ *|*\ heavy|*\ gpu) return 0 ;;   # already past a queue
    esac
    if [ "$a0" = timeout ] && [ -z "$short" ]; then
      local i=1 v
      while [ $i -lt ${#args[@]} ]; do
        v=${args[$i]}
        case "$v" in
          -s|-k|--signal|--kill-after) i=$((i + 2)); continue ;;
          -*) i=$((i + 1)); continue ;;
        esac
        break
      done
      v=${args[$i]:-}
      if [ -n "$v" ] && [ "$(queue_wrap_seconds "$v")" -lt 21600 ]; then short=$v; fi
    fi
    stat=$(cat "/proc/$pid/stat" 2>/dev/null) || break
    stat=${stat##*) }; ppid=$(echo "$stat" | cut -d' ' -f2)
    pid=${ppid:-1}; hops=$((hops + 1))
  done
  [ -z "$short" ] && return 0
  {
    echo "refused: this run sits under \`timeout $short\`, which counts heavy's queue: under a"
    echo "release's solo checks it dies at exit 124 before it starts. Give the outer timeout 6 h or"
    echo "more (BOX_HEAVY_WAIT=21600), or bound the run alone: PROBE_TIMEOUT=N for a probe,"
    echo "\`heavy timeout N CMD\` for anything else. ALLOW_QUEUE_TIMEOUT=1 lets this one through."
  } >&2
  return 2
}
