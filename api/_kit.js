// The site's kit (web/kit.js: an avatar, an icon, an icon button), for the
// pages the server makes. In a checkout this passes web/kit.js through; a
// deployment has no web/ beside its functions, so tools/deploy.sh puts
// web/kit.js here in its place, reading its card from _card.js, and the
// server and the browser draw the kit from the same file.
export * from "../web/kit.js";
