// The minifig maker's parts and what a figure made in it may be
// (web/minifig-parts.js figureShape), for the avatar the server keeps with
// its recipe (api/_avatars.js, api/people.js ?op=avatar). In a checkout this
// passes web/minifig-parts.js through; a deployment has no web/ beside its
// functions, so tools/package_api.sh puts web/minifig-parts.js here in its
// place, as it does web/card.js.
export * from "../web/minifig-parts.js";
