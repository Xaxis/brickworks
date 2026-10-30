// A person's page, /u/<handle>, and a collection's, /c/<id> (api/people.js):
// Share, the phone's own share sheet where there is one, else the page's
// link copied and said so in the toast; hidden until this is here to make
// it work. Their lists are paged by web/pager.js, as every list is.
import { toast } from "/kit.js";

for (const button of document.querySelectorAll("button[data-share]")) {
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
