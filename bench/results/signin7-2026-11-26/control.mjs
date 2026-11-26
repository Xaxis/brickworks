// signreview3: the counters' control. The flows' own Chromium (tools/web/browser.mjs launch,
// NO_PROVIDERS and all) sent straight to Google's and GitHub's sign-in pages, which this
// machine must refuse before anything leaves it, and to example.com, which it must reach, so
// that run_flows.sh's strace, net log and netwatch are seen to catch a request when one is
// made. Nothing here reaches Google or GitHub if NO_PROVIDERS holds; if it does not, this
// says so (one GET of each sign-in page, with no client id or anything of anyone's).
import { launch } from "../../../tools/web/browser.mjs";

const browser = await launch({ signedOut: true });
const ctx = await browser.newContext();
const page = await ctx.newPage();
const seen = [];
page.on("request", (request) => seen.push(request.url()));
for (const url of ["https://accounts.google.com/o/oauth2/v2/auth", "https://github.com/login/oauth/authorize", "https://example.com/"]) {
  const got = await page.goto(url, { timeout: 30000 }).then((reply) => `answered ${reply?.status()}`, (trouble) => `refused: ${String(trouble.message).split("\n")[0].slice(0, 120)}`);
  console.log(`  --      ${url}: ${got}`);
}
console.log(`  --      Playwright saw ${seen.length} request(s): ${seen.join(" ")}`);
await browser.close();
