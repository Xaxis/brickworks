// A person's page, /u/<handle>, and a collection's, /c/<id> (api/people.js):
// Share opens the page's share sheet (web/share-sheet.js): its link, the
// networks to post it to, and the phone's own sheet where there is one;
// hidden until this is here to make it work. Without a sheet, the phone's
// own sheet, else the page's link copied and said so in the toast. Their
// lists are paged by web/pager.js, as every list is.
import { toast } from "/kit.js";
import { wireShare } from "/share-sheet.js";

const sheet = document.getElementById("share-sheet");
for (const button of document.querySelectorAll("button[data-share]")) {
  if (sheet) {
    wireShare(button, sheet);
    continue;
  }
  button.hidden = false;
  button.addEventListener("click", async () => {
    const url = button.dataset.share || location.href;
    if (navigator.share && matchMedia("(pointer: coarse)").matches) {
      try {
        await navigator.share({ title: document.title, url });
        return;
      } catch (trouble) {
        if (trouble?.name === "AbortError") return;
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      toast("Link copied");
    } catch {
      toast("Could not copy it: the address is in the bar above");
    }
  });
}
