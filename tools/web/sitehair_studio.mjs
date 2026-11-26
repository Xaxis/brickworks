// sitehair_flow.mjs --probe's studio: src/dev/sitehair_probe.gd, headless
// through tools/probe.sh, signed in as the flow's Ada against its relay.
// Apart from the flow, so the flow a preview runs (no --probe: the web
// build's studio) starts no engine. Only an imported tree can run one, and
// a release's web lane never imports its tree (preview_checks.sh's
// ENGINE_CHECKS, tests/test_flow_models.py); a unit's relay run can.
import { spawnSync } from "node:child_process";

/// The probe run in [work] against [site] as [token] and [user], the
/// mould's text written to [file]: spawnSync's {status, stdout, stderr}.
export function runStudioProbe({ work, site, token, user, file }) {
  return spawnSync("bash", ["tools/probe.sh", "sitehair_probe"], {
    cwd: work, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, BRICKWORKS_API: site, BW_PROBE_TOKEN: token, BW_PROBE_USER: user, BW_MOULD_OUT: file,
      PROBE_TIMEOUT: "900" },
  });
}
