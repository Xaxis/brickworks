// The one way a browser is started here: drawing in software, on SwiftShader.
//
// Never on the GPU. This box's GPU is leased one job at a time, because two
// amdgpu hangs that took the desktop down both began with several programs on
// it at once, one of them headless Chromium on Vulkan. Two of these scripts
// asked for SwiftShader and five took Playwright's default, so whether a
// deploy's landing check stayed off the GPU was up to Playwright.
import { chromium } from "playwright";

export const SOFTWARE = [
  "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
];

export function launch(options = {}) {
  return chromium.launch({ ...options, args: [...SOFTWARE, ...(options.args || [])] });
}
