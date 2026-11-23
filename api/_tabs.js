// The tabs of an object's page, as the server draws them (pagekit,
// 2026-11-23; web/tabs.js makes them work, docs/DESIGN_SYSTEM.md "An
// object's page"): a model's, a set's, a challenge's, a Talk thread's. One
// row, `.tabs.obj-tabs[role=tablist]`, each tab a link to its panel's key
// with its count once there is one, the first chosen; each panel a
// `[role=tabpanel]` labelled by its tab, hidden but the first.

import { asText, escapeHtml } from "./_directory.js";
import { number } from "./_card.js";

/// [tabs]: [{ key, name, n, also }] in order (name the words to show, n a
/// count or nothing, also a key it answers to as well, as Overview does
/// #about); [label] what the row is, for a screen reader; [id] the row's.
export function tabsHtml(tabs, { label, id = "page-tabs", extra = "" } = {}) {
  const shown = tabs.filter(Boolean);
  return `<div class="tabs obj-tabs${extra ? ` ${extra}` : ""}" id="${id}" role="tablist" aria-label="${asText(label)}">`
    + shown.map((tab, at) => `<a href="#${tab.key}" role="tab" id="tab-${tab.key}" aria-controls="${tab.key}" data-tab="${tab.key}"`
      + `${tab.also ? ` data-also="${escapeHtml(tab.also)}"` : ""} aria-selected="${at === 0}">${asText(tab.name)}`
      + (Number(tab.n) ? ` <span class="n">${escapeHtml(number(Number(tab.n)))}</span>` : "") + "</a>").join("")
    + "</div>";
}

/// A tab's panel's attributes, labelled by its tab; [first], the one shown
/// before a tab is chosen (with no script, site.css shows the one the
/// address names).
export function panelAttrs(key, first = false) {
  return ` role="tabpanel" aria-labelledby="tab-${key}" tabindex="0"${first ? "" : " hidden"}`;
}
