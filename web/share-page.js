// A shared model's link, /m/<id> (api/share.js): the page is there for
// anything that previews a link — its title and picture — and a person
// goes straight on to the viewer. Replaced, not followed, so Back leaves
// the link rather than landing on it and being sent on again.
const viewer = document.body && document.body.dataset.viewer;
if (viewer && viewer.startsWith("/app?view=")) location.replace(viewer);
