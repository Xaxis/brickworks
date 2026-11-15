// /challenge as a person sees it, read from the page, and what it should
// say for a challenge in a given state (challengepage, 2026-11-13: the page
// laid out as the best contest pages are). challenges_flow.mjs judges the
// real page with these, on a deployment or the local relay; any check that
// draws the page from fixtures can call them too.
//
//   import { drawn, judged } from "./challenge_page.mjs";
//   const d = await drawn(page);
//   for (const [what, ok] of judged(d, { state: "open", groups: { hand: 1, assistant: 1 } })) check(what, ok);

/// /challenge as drawn: the head (status, countdown, numbers, the way in),
/// the rules, the winners, the groups' tabs and every entry's card in both
/// groups (the one not shown is drawn too, its panel hidden), the line over
/// the cards, and the challenges that ran. Runs in the page.
export const drawn = (page) => page.evaluate(() => {
  const text = (el) => (el?.textContent || "").replace(/\s+/g, " ").trim();
  const seen = (el) => Boolean(el && !el.closest("[hidden]") && el.getClientRects().length);
  const $ = (id) => document.getElementById(id);
  const top = (el) => (seen(el) ? el.getBoundingClientRect().top + scrollY : null);
  const cells = [...document.querySelectorAll("#countdown b")].map(text);
  return {
    state: document.documentElement.dataset.challenge || "",
    title: text($("title")),
    days: text($("days")),
    brief: text($("brief")),
    eyebrow: text($("eyebrow")),
    status: seen($("status")) ? text($("status")) : "",
    clock: seen($("clock-h")) ? text($("clock-h")) : "",
    countdown: seen($("countdown")) ? { label: $("countdown").getAttribute("aria-label") || "", cells,
      role: $("countdown").getAttribute("role") } : null,
    numbers: Object.fromEntries([...document.querySelectorAll("#numbers li")].filter(seen)
      .map((li) => [li.dataset.number, text(li.querySelector("b")) || text(li)])),
    enter: seen($("enter")) ? text($("enter")) : "",
    share: seen($("share")),
    rules: [...document.querySelectorAll("#rules li")].map(text),
    tabs: [...document.querySelectorAll('#group-tabs [role="tab"]')].map((tab) => ({ way: tab.dataset.way,
      selected: tab.getAttribute("aria-selected") === "true", name: text(tab.firstChild), n: text(tab.querySelector(".n")),
      controls: tab.getAttribute("aria-controls") })),
    tablist: $("group-tabs")?.getAttribute("role") || "",
    voteSaid: seen($("vote-said")) ? text($("vote-said")) : "",
    groups: Object.fromEntries([...document.querySelectorAll("#groups .group")].map((panel) => [panel.dataset.way, {
      shown: !panel.hidden, empty: text(panel.querySelector(".state")),
      entries: [...panel.querySelectorAll(".model[data-entry]")].map((card) => ({ id: card.dataset.entry,
        card: Boolean(card.querySelector(".frame") && card.querySelector("a.open b")), voted: card.classList.contains("voted"),
        marks: [...card.querySelectorAll(".vote-line .badge")].map(text), votes: text(card.querySelector(".vote-line .votes")),
        button: text(card.querySelector(".vote-line button")), broken: text(card.querySelector(".vote-line .broken")) })) }])),
    sort: [...document.querySelectorAll("#sort button")].filter(seen).map((b) => [b.dataset.sort, b.getAttribute("aria-pressed") === "true"]),
    winners: [...document.querySelectorAll("#winner-cards .winner")].map((box) => ({ id: box.dataset.entry, way: box.dataset.way,
      line: text(box.querySelector(".winner-h b")), votes: text(box.querySelector(".winner-h small")) })),
    winnersShown: seen($("winners")),
    // The winners over the entries, as a person scrolling meets them.
    winnersFirst: seen($("winners")) && seen($("entries")) && top($("winners")) < top($("entries")),
    why: [...document.querySelectorAll("#groups .why-not")].map(text),
    past: [...document.querySelectorAll("#past article[data-past]")].map((card) => ({ id: card.dataset.past,
      href: card.querySelector("h3 a")?.getAttribute("href") || "", title: text(card.querySelector("h3")),
      days: text(card.querySelector(".note")), won: [...card.querySelectorAll(".past-won [data-entry]")].map((one) => ({
        id: one.dataset.entry, text: text(one) })) })),
  };
});

/// What /challenge in [want] should say, as [what, ok] pairs, of [d]
/// (drawn): want.state ("open", "upcoming", "ended"); want.groups, each
/// group's count of entries ({hand: 1, assistant: 1}); want.signedIn; and
/// signed in, want.voted ({hand: id}) and want.mine ([ids]); once ended,
/// want.winners ([[id, way, votes]]); want.shown, the group chosen when it
/// is not the first with entries.
export function judged(d, want) {
  const out = [];
  const say = (what, ok) => out.push([what, Boolean(ok)]);
  const status = { open: "Open", upcoming: "Opens soon", ended: "Ended" }[want.state];
  say(`its status "${d.status}" (${d.state})`, d.state === want.state && d.status === status);
  if (want.state === "ended") {
    say(`no countdown once it ended; "${d.clock}", "${d.days}"`, !d.countdown && d.clock === "Final results" && /^Ran /.test(d.days));
  } else {
    const label = want.state === "open" ? /^Ends in / : /^Opens in /;
    const time = /in (?:\d+ days?, \d+ hours?|\d+ hours?, \d+ minutes?)$/;
    say(`a live countdown: "${d.clock}", ${JSON.stringify(d.countdown?.cells)}, "${d.countdown?.label}"`, d.countdown
      && d.countdown.role === "timer" && d.countdown.cells.length === 4 && d.countdown.cells.every((one) => /^\d[\d,.]*$/.test(one))
      && label.test(d.countdown.label) && time.test(d.countdown.label) && d.clock === (want.state === "open" ? "Ends in" : "Opens in"));
  }
  if (want.state === "open") {
    say(`its days and how far through them: "${d.days}"`, /· day \d+ of \d+$/.test(d.days));
    say(`one way in, "${d.enter}", beside Share`, d.enter === "Enter a model" && d.share);
  } else {
    say(`no Enter while it is ${want.state}`, !d.enter && d.share);
  }
  const counts = want.groups || {};
  const total = Object.values(counts).reduce((sum, n) => sum + n, 0);
  if (total) say(`its numbers: ${JSON.stringify(d.numbers)}`, d.numbers.entries === String(total));
  const shownWay = want.shown || Object.entries(counts).find(([, n]) => n > 0)?.[0] || "hand";
  say(`the groups as tabs with their counts: ${JSON.stringify(d.tabs.map((one) => [one.way, one.name, one.n, one.selected]))}`,
    d.tablist === "tablist" && d.tabs.length === 2
    && d.tabs[0].way === "hand" && d.tabs[0].name === "Built by hand" && d.tabs[1].way === "assistant" && d.tabs[1].name === "Built with the assistant"
    && d.tabs.every((one) => one.n === (counts[one.way] ? String(counts[one.way]) : "") && one.controls === `group-${one.way}`)
    && d.tabs.filter((one) => one.selected).map((one) => one.way).join() === shownWay
    && Object.entries(counts).every(([way, n]) => (d.groups[way]?.entries || []).length === n && d.groups[way].shown === (way === shownWay)));
  if (want.state === "open" && want.signedIn) {
    for (const [way, id] of Object.entries(want.voted || {})) {
      if (!id) continue;
      const card = (d.groups[way]?.entries || []).find((one) => one.id === id);
      const others = (d.groups[way]?.entries || []).filter((one) => one.id !== id);
      say(`your vote shown in ${way}: ${JSON.stringify(card)}; no Vote on the rest`, card && card.voted && card.marks.includes("Your vote")
        && !card.button && others.every((one) => !one.button));
    }
    for (const id of want.mine || []) {
      const card = Object.values(d.groups).flatMap((one) => one.entries).find((one) => one.id === id);
      say(`your entry marked: ${JSON.stringify(card)}`, card && card.marks.includes("Your entry") && !card.button);
    }
  }
  if (want.state === "open" && !want.signedIn) {
    const buttons = Object.values(d.groups).flatMap((one) => one.entries.map((entry) => entry.button));
    say(`Vote on every card for a visitor: ${JSON.stringify(buttons)}`, buttons.length === total && buttons.every((one) => one === "Vote"));
  }
  if (want.state === "ended") {
    const won = (want.winners || []).map(([id, way, votes]) => [id, way, way === "assistant" ? "Winner, built with the assistant"
      : "Winner, built by hand", votes ? `${votes} vote${votes === 1 ? "" : "s"}` : ""]);
    say(`the winners first: ${JSON.stringify(d.winners)}`, d.winnersShown && d.winnersFirst && d.winners.length === won.length
      && won.every(([id, way, line, votes], at) => d.winners[at].id === id && d.winners[at].way === way && d.winners[at].line === line
        && d.winners[at].votes === votes));
    const cards = Object.values(d.groups).flatMap((one) => one.entries);
    say("...and among the entries, the winners marked with their votes, and no Vote on any", won.every(([id, , , votes]) => {
      const card = cards.find((one) => one.id === id);
      return card && card.marks.includes("Winner") && card.votes === votes;
    }) && cards.every((one) => !one.button));
  }
  return out;
}
