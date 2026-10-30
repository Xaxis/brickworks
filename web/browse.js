// What a page of cards to browse does with its search and its bar of
// filters (the gallery and the LDraw library, site357): "/" puts the
// cursor in the search, as on most sites with one, the field saying so
// until it is used; the bar of filters, which stays under the header as
// the list scrolls, has the header's edge under it once it is stuck. How
// each is drawn is the page's own <style>; its row of pills is a scroller
// (web/scroller.js).
//
//   import { browseBar } from "/browse.js";
//   browseBar({ search: q, above: tabsRow, bar: toolbar });

/// [search] the field "/" focuses; [bar] the sticky bar, data-stuck once
/// [above] (what is over it in the page) has gone under the header.
export function browseBar({ search, above, bar }) {
  addEventListener("keydown", (event) => {
    if (event.key !== "/" || event.metaKey || event.ctrlKey || event.altKey || event.defaultPrevented) return;
    const at = document.activeElement;
    if (at && (at.isContentEditable || /^(INPUT|SELECT|TEXTAREA)$/.test(at.tagName) || at.closest("dialog[open]"))) return;
    event.preventDefault();
    search.focus();
    search.select();
  });
  if (bar && above && "IntersectionObserver" in window) {
    const head = Math.round(document.querySelector(".site-head")?.getBoundingClientRect().height || 61);
    new IntersectionObserver(([seen]) => {
      bar.toggleAttribute("data-stuck", !seen.isIntersecting && seen.boundingClientRect.top < head);
    }, { rootMargin: `-${head}px 0px 0px 0px` }).observe(above);
  }
}
