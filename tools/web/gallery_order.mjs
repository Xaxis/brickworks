// Where a flow's own model stands in a page of the gallery while other
// flows publish beside it.
//
// The release's preview checks run two flows at a time against one
// deployment and one database (tools/release/preview_checks.sh), and
// several of them list a test model. A flow that wanted its own model
// first in the newest-first order failed whenever the other's was listed
// after it: m115's share_probe and m122's share_flow (2026-10-20), each a
// release held an hour until it ran alone.
//
// So a flow judges its model against what was listed before it: ahead of
// every card its sort ranks lower, the page in that order throughout, and
// a card ahead of it only one the sort ranks higher, as another flow's
// model listed after it is. The order is the database's (directory_models,
// supabase/play.sql): the sort's own count, more first, then listed_at,
// newest first.

/// A listed_at to the microsecond: Postgres gives up to six places, which
/// Date.parse drops, and a tie read as one is not one.
function when(stamp) {
  if (!stamp) return -Infinity;
  const text = String(stamp);
  const fraction = (text.match(/\.(\d+)/) || ["", ""])[1];
  const whole = Date.parse(text.replace(/\.\d+/, ""));
  return Number.isNaN(whole) ? -Infinity : whole * 1000 + Number(fraction.padEnd(6, "0").slice(0, 6));
}

function nth(n) {
  if (n % 100 >= 11 && n % 100 <= 13) return `${n}th`;
  return `${n}${["th", "st", "nd", "rd"][n % 10] || "th"}`;
}

/// Where [id] stands in [cards], a page of the gallery in the order it was
/// given, each card with its id and listed_at. [by] names the sort's own
/// count on a card ("builds", "views"), more first; none for Newest.
/// [since], when given, is when the flow listed its model (ms since the
/// epoch): its listed_at must be that listing's, give or take a minute.
/// {ok, at, ahead, said}: its place from 1 (0 when it is not there), how
/// many cards are ahead of it, and a few words for a check's line.
export function placed(cards, id, { by = null, since = null } = {}) {
  const rank = (card) => [by ? Number(card[by]) || 0 : 0, when(card.listed_at)];
  const above = (a, b) => a[0] > b[0] || (a[0] === b[0] && a[1] > b[1]);
  const told = (card) => `${card.id} (${by ? `${card[by]} ${by}, ` : ""}${card.listed_at})`;
  const index = cards.findIndex((card) => card.id === id);
  if (index < 0) return { ok: false, at: 0, ahead: 0, said: `not among the ${cards.length} shown` };
  const place = `${nth(index + 1)} of ${cards.length}`;
  const wrong = (why) => ({ ok: false, at: index + 1, ahead: index, said: `${place}; ${why}` });
  const unknown = cards.find((card) => !card.listed_at);
  if (unknown) return wrong(`${unknown.id} says no listed_at`);
  for (let k = 1; k < cards.length; k += 1) {
    if (above(rank(cards[k]), rank(cards[k - 1]))) {
      return wrong(`out of order at the ${nth(k + 1)}: ${told(cards[k])} after ${told(cards[k - 1])}`);
    }
  }
  if (since !== null) {
    const listed = when(cards[index].listed_at) / 1000;
    if (listed < since - 60000 || listed > Date.now() + 60000) {
      return wrong(`listed at ${cards[index].listed_at}, not as it was listed`);
    }
  }
  return { ok: true, at: index + 1, ahead: index,
    said: place + (index ? `, behind ${index}${by ? ` with more ${by}, or as many and` : ""} listed after it` : "") };
}
