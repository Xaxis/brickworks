// The embed (/m/<id>/embed, api/share.js embedCard), in somebody else's
// page: its picture is the way into the model in 3D, in the frame, as on
// the model's page (web/start3d.js). Nothing more of the 3D view comes
// until it is asked for.
import { start3d } from "/start3d.js";

const picture = document.querySelector(".embed a.picture[data-scene]");
if (picture) start3d(picture);
