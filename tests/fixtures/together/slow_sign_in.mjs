// slow_sign_in.mjs: each sign-in's signature check held 0-300 ms at random,
// as a busy box's thread pool holds it without stalling the event loop
// (pollreads, 2026-11-16). poll_check.mjs must pass with it:
//
//   NODE_OPTIONS="--import ./tests/fixtures/together/slow_sign_in.mjs" \
//     python3 tools/minitest.py tests/test_together_poll.py
import { webcrypto } from "node:crypto";

const verify = webcrypto.subtle.verify.bind(webcrypto.subtle);
webcrypto.subtle.verify = async (...args) => {
  const ok = await verify(...args);
  await new Promise((done) => setTimeout(done, Math.random() * 300));
  return ok;
};
