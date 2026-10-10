// What the app needs to know about this deployment, in one request.
//
// One thing, now: where the part geometry the build did not ship is
// served from. The library runs to 27,000 meshes and a deployment takes
// 15,000 files, so the parts cannot live beside the app — and the ones
// that would have been cut are the big interesting pieces, because a
// size budget takes the smallest first. Null means "next to the app",
// which is what a deployment carrying its own parts wants.
//
// The name is older than the answer. Until 2026-10-09 there were
// accounts, so that one of them could design on this project's own key.
// There are none now: the assistant runs on each person's own key, sent
// only to Anthropic, or on their own Claude plan with Claude as the
// client, and nobody signs in to anything. The route stays where it was
// because builds already out ask it here, and moving it would cut every
// one of them off from the parts.
//
// `enabled: false` and `assistant: "own_key"` are for those builds too.
// They are how an older one learns there is nothing to sign in to.

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type")
      .setHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
      .end();
  }

  response.setHeader("Access-Control-Allow-Origin", "*");
  // The same answer for everybody, so any cache may keep it for a while.
  response.setHeader("Cache-Control", "public, max-age=300");

  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET only" });
  }

  return response.status(200).json({
    enabled: false,
    assistant: "own_key",
    parts_url: process.env.PARTS_URL || null,
  });
}
