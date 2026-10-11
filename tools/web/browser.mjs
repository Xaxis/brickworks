// The one way a browser is started here: drawing in software, on SwiftShader.
//
// Never on the GPU. This box's GPU is leased one job at a time, because two
// amdgpu hangs that took the desktop down both began with several programs on
// it at once, one of them headless Chromium on Vulkan. Two of these scripts
// asked for SwiftShader and five took Playwright's default, so whether a
// deploy's landing check stayed off the GPU was up to Playwright.
//
// And signed in. Everyone who uses Brickworks signs in (2026-10-11), and the
// app shows nothing but the sign-in screen until they have, so every flow
// here that drives the app would otherwise drive that screen. Each context
// this browser opens starts as a returning visitor's: a session of the test
// account, minted on the test side (session.mjs) and put where the app keeps
// one. Needs .env sourced; without it the pages start signed out and say
// so. launch({ signedOut: true }) for a flow about signing in itself.
import { chromium } from "playwright";
import { canSignIn, signInContext, TEST_EMAIL } from "./session.mjs";

export const SOFTWARE = [
  "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
];

let warned = false;

async function signedIn(context) {
  if (!canSignIn()) {
    if (!warned) {
      warned = true;
      console.log("  (not signed in: no Supabase keys in the environment — "
        + "`set -a; . ./.env; set +a` — so the app will show its sign-in screen)");
    }
    return context;
  }
  try {
    await signInContext(context);
  } catch (trouble) {
    console.log(`  (could not sign the test account in: ${trouble.message})`);
  }
  return context;
}

export async function launch(options = {}) {
  const { signedOut = false, ...rest } = options;
  const browser = await chromium.launch({ ...rest, args: [...SOFTWARE, ...(rest.args || [])] });
  if (signedOut) return browser;
  const newContext = browser.newContext.bind(browser);
  browser.newContext = async (contextOptions) => signedIn(await newContext(contextOptions));
  // A page of its own context, which Playwright closes with the page.
  browser.newPage = async (pageOptions) => {
    const context = await browser.newContext(pageOptions);
    const page = await context.newPage();
    page.on("close", () => context.close().catch(() => {}));
    return page;
  };
  browser.testAccount = canSignIn() ? TEST_EMAIL : null;
  return browser;
}
