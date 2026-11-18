# The studio on phones

phonetruth, 2026-11-18. The owner asked two things: does the studio need a
mobile version, or should phone users be warned? This page answers both
from measurements. Every earlier phone check (phone_flow, phonewalk_flow,
tablet_flow and the probes' phone sizes) was desktop Chromium pretending
to be a phone, on this box's fast CPU and SwiftShader. None had run
WebKit, a phone's CPU speed, a phone's memory or a mobile network.

<!-- MEASURES -->

## What the platforms allow, cited

**WebGL 2.**
- Godot 4's web export draws only with WebGL 2, through the Compatibility
  renderer, and has no WebGL 1 path
  ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)).
  The same page warns that "Safari has several issues with WebGL 2.0
  support".
- Safari has had WebGL 2 since Safari 15 on iOS 15, drawn on Metal through
  ANGLE ([WebKit](https://webkit.org/blog/11989/new-webkit-features-in-safari-15/)).
  Chrome for Android has had it since 58
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebGL2RenderingContext)).
- Chromium's GPU blocklist turns WebGL off on one class of Android GPU:
  those with no separate GPU process and no reset notification
  ([software_rendering_list.json](https://chromium.googlesource.com/chromium/src/+/main/gpu/config/software_rendering_list.json)).
- The model pages' 3D view uses three.js 0.186, which since r163 also
  draws only with WebGL 2. Its check accepted WebGL 1 until this unit.

**Memory per tab.**
- On an iPhone, a tab's WebContent process has a soft limit of "around
  1.5GB". Above it the process is "subject to getting killed by jetsam",
  and the limit is lower on iPhones with less RAM. One reporter measured
  about 1.5 GB on an iPhone 12 Pro and about 3 GB on a 15 Pro
  ([WebKit 277848](https://bugs.webkit.org/show_bug.cgi?id=277848)).
- WebKit's Gigacage held 2 GB of such allocations on iOS. An 8 GB iPad gave
  a page only 1.88 GB
  ([WebKit 268816](https://bugs.webkit.org/show_bug.cgi?id=268816)).
- Wasm memory and SharedArrayBuffers share that cage. A duplicate bug is
  titled "Only ~300 MB of RAM is reliably available to WebAssembly pages"
  ([WebKit 269937](https://bugs.webkit.org/show_bug.cgi?id=269937)).
- In Safari, `memory.grow()` does not fail. The tab is killed and
  reopened instead, and "too much memory is decided based on system
  pressure not a fixed limit"
  ([WebKit 221530](https://bugs.webkit.org/show_bug.cgi?id=221530)).
- The "A problem repeatedly occurred" reload is jetsam's
  `per_process_limit`. It has been seen past 1.4 GB in a Wasm app on an
  iPhone 13 Pro ([WebKit 256703](https://bugs.webkit.org/show_bug.cgi?id=256703)).
- Godot #70621: on iOS 16.2, a `WebAssembly.Memory` with a 2048 MB maximum
  failed as out of memory, and a 256 MB maximum worked
  ([godot#70621](https://github.com/godotengine/godot/issues/70621)).
  Brickworks' threaded build asks for exactly that: shared, 32 MB to start,
  2048 MB at most (build/web/index.js).
- Chrome on Android kills background tabs aggressively, losing their state
  ([Chrome](https://developer.chrome.com/blog/tab-discarding/)). No
  official per-tab figure for Android is published.

**Threads.**
- Safari 15.2 (iOS 15.2) added COOP and COEP and turned SharedArrayBuffer
  back on for cross-origin isolated pages
  ([WebKit](https://webkit.org/blog/12140/new-webkit-features-in-safari-15-2/)).
  Android Chrome 88 requires the same isolation
  ([Chrome](https://developer.chrome.com/blog/enabling-shared-array-buffer)).
- Godot 4.3 added a single-threaded web export and made it the default.
  Among its reasons, the long-standing problems on Apple devices "fortunately
  disappear" without threads
  ([Godot](https://godotengine.org/article/progress-report-web-export-in-4-3/)).
  The 4.7 docs say threads "always had compatibility issues" on iOS.
- Brickworks has a no-threads preset (`Web (no threads)`,
  build/web-nothreads), but only the threaded build is deployed.
- Emscripten notes that threads together with memory growth make
  JavaScript's reads of Wasm memory slow
  ([Emscripten](https://emscripten.org/docs/porting/pthreads.html)).

**Sound.**
- An AudioContext must be made or resumed inside a user gesture
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices);
  [WebKit 180522](https://bugs.webkit.org/show_bug.cgi?id=180522)).
- iOS suspends it when the page goes to the background
  ([WebKit 231105](https://bugs.webkit.org/show_bug.cgi?id=231105)).
- Godot resumes it on every key, mouse, touch and IME event
  ([display_server_web.cpp](https://github.com/godotengine/godot/blob/master/platform/web/display_server_web.cpp)).

**The soft keyboard.**
- Since Chrome 108, Android Chrome resizes only the visual viewport when
  the keyboard opens, as Safari on iOS does
  ([Chrome](https://developer.chrome.com/blog/viewport-resize-behavior)).
  `visualViewport` exists in both
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/VisualViewport)).
- Godot's `html/experimental_virtual_keyboard` uses a hidden input. It
  never reads `visualViewport`
  ([library_godot_display.js](https://github.com/godotengine/godot/blob/master/platform/web/js/libs/library_godot_display.js)).
  The studio lifts its own dialogs above the keyboard (dialogs_430,
  field_drag).

**In the background.**
- A hidden tab's requestAnimationFrame is paused
  ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame)).
  Chrome holds its timers to once a second, then once a minute after five
  minutes ([Chrome](https://developer.chrome.com/blog/timer-throttling-in-chrome-88)).
- On iOS, "tabs are completely suspended when possible"
  ([WebKit](https://webkit.org/blog/8970/how-web-content-can-affect-power-usage/)).
  Low Power Mode caps requestAnimationFrame at 30 frames a second
  ([WebKit 215745](https://bugs.webkit.org/show_bug.cgi?id=215745)).
- A frozen Android page runs nothing, and a discarded one starts again
  ([Chrome](https://developer.chrome.com/docs/web-platform/page-lifecycle-api)).
  The studio keeps every edit in IndexedDB as it is made, so a reload
  reopens the work (docs/APP_UX8.md, the connector with the tab hidden).

**How honest the stand-ins are.**
- A 4x CPU throttle is Lighthouse's calibration of a high-end desktop down
  to a mid-tier phone (a Moto G4). Its table suggests 10x for a low-end
  phone ([Lighthouse](https://github.com/GoogleChrome/lighthouse/blob/main/docs/throttling.md)).
- DevTools calls throttling "a first-order approximation"
  ([DevTools](https://developer.chrome.com/docs/devtools/device-mode)).
  Its CPU throttling "doesn't touch the GPU process"
  ([DevTools](https://developer.chrome.com/blog/devtools-grounded-real-world)).
- Fast 4G is 9 Mbps down × 0.9, 1.5 Mbps up × 0.9, and 60 ms × 2.75 =
  165 ms a request
  ([NetworkManager.ts](https://github.com/ChromeDevTools/devtools-frontend/blob/main/front_end/core/sdk/NetworkManager.ts)).
- Playwright's WebKit is WebKit's main branch with patches, not Safari. On
  Linux it is WPE's MiniBrowser
  ([Playwright](https://playwright.dev/docs/browsers)). It shares
  JavaScriptCore and WebKit's layout with iOS Safari. It has none of
  iOS's jetsam limits or Gigacage size, and none of its Metal path:
  here it draws on Mesa's llvmpipe. So it tells what WebKit runs and how,
  never whether an iPhone keeps the tab.
