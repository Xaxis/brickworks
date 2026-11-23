// Four cottages in the design stand-in, a chain of three remixes, each
// counted (remixdiff, 2026-11-23): what tools/web/remix_flow.mjs drives and
// tools/web/page_lcp_pairs.mjs times.
//
//   Stone Cottage (CottageA01, Robin's): tests/fixtures/remix_pairs 09's original
//   Cottage with a Garden (CottageB01, Mika's): that pair's remix, one part
//     added, one taken away, one recoloured and two moved (one turned)
//   Cottage at Dusk (CottageC01, Jo's): five bricks more
//   Winter Cottage (CottageD01, Priya's): a brick fewer
//
// Each remix is counted by the same countRemix a publish runs
// (api/_remix.js) into the stand-in's remix_changes, with the one-colour
// parts as the app reads them (the fixtures' part_current.json).
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { countRemix } from "../../api/_remix.js";
import { useCurrent } from "../../api/_parts.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
export const PAIRS = path.join(root, "tests/fixtures/remix_pairs");
export const PAIR = "09_mix_move_turn_recolour";

/// The four added to [stand] (design_stand_in.mjs), their files given and
/// the three remixes counted; [api] the handlers' folder the stand-in's
/// first page is made by. {models, was, garden}.
export async function cottageWorld(stand, api) {
  const was = readFileSync(path.join(PAIRS, `${PAIR}.was.ldr`), "utf8");
  const garden = readFileSync(path.join(PAIRS, `${PAIR}.now.ldr`), "utf8");
  const more = [0, 1, 2, 3, 4].map((k) => `1 14 ${-60 + 30 * k} -8 20 1 0 0 0 1 0 0 0 1 3003.dat`).join("\n");
  const dusk = garden.replace("\n0 NOFILE\n", `\n${more}\n0 NOFILE\n`);
  const winter = dusk.split("\n").filter((line) => !/^1 15 -90 -32 -100 /.test(line)).join("\n");
  const { ROBIN, MIKA, JO, PRIYA } = stand.OWNERS;
  const models = [
    { id: "CottageA01", owner: ROBIN, name: "Stone Cottage", author: "Robin Castell", parts: 42, file: was, from: null },
    { id: "CottageB01", owner: MIKA, name: "Cottage with a Garden", author: "Mika Tanaka", parts: 42, file: garden, from: "CottageA01" },
    { id: "CottageC01", owner: JO, name: "Cottage at Dusk", author: "Jo Lindqvist", parts: 47, file: dusk, from: "CottageB01" },
    { id: "CottageD01", owner: PRIYA, name: "Winter Cottage", author: "Priya Raman", parts: 46, file: winter, from: "CottageC01" },
  ];
  models.forEach((m, k) => {
    stand.addModel({ id: m.id, owner: m.owner, name: m.name, author: m.author, parts: m.parts, steps: 1, kind: "town",
      tags: ["cottage"], remixed_from: m.from, listed_at: `2026-11-0${k + 1}T10:00:00Z`, updated_at: `2026-11-0${k + 1}T10:00:00Z` });
    stand.useFileOf(m.id, m.file);
  });
  useCurrent(JSON.parse(readFileSync(path.join(PAIRS, "part_current.json"), "utf8")).parts);
  // The stand-in's database answers from here on: it is put in place by the first page asked.
  await stand.serverPage(api, "/m/CottageA01");
  const getFile = async (name) => {
    const answer = await fetch(`${stand.DB}/storage/v1/object/shared-models/${name}`);
    return answer.ok ? Buffer.from(await answer.arrayBuffer()) : null;
  };
  for (const m of models.slice(1)) await countRemix({ id: m.id, n: 1, text: m.file, from: m.from, said: 1, getFile });
  return { models, was, garden };
}
