// A part's geometry as the app loads it (web/lbm.js), for the pictures the
// server draws of a set's parts (api/_flatlay.js). In a checkout this passes
// web/lbm.js through; a deployment has no web/ beside its functions, so
// tools/deploy.sh puts web/lbm.js here in its place, as it does web/card.js.
export * from "../web/lbm.js";
