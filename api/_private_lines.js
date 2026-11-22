// A file's private lines left out of a shared model (web/private-lines.js), for the share function.
// In a checkout this passes web/private-lines.js through; a deployment has no web/ beside its
// functions, so tools/package_api.sh puts web/private-lines.js here in its place, and the browser
// and the server leave out the same lines.
export * from "../web/private-lines.js";
