---
ai: Own and Want mark official sets, Save keeps gallery models, and lists of your own hold both. Every set card, set page, gallery model card and model page has the same control (Save on a model's page is its card's, one panel); Your lists (the account menu, /lists) manages them all. The sets you own are My collection, the parts the app counts as yours. A list is private, shared by a link, or public. Public lists have their page at /c/<id> and are listed in the gallery's Lists tab at /gallery-lists (/collections redirects there); a list shared by a link opens only at /c/<id>?link=<key>, never on the profile, in the directory, search or the sitemap, and Stop sharing makes that link answer 404 at once. Add sets shows what an import would do (to add, already there, not found) before anything is written.
rules:
  - A private list is its owner's alone; a new list is private.
  - A list shared by a link opens only by that link, and the link stops working the moment its owner stops sharing; sharing again makes a new link.
  - A wishlist shared is shared by its link unless its owner chooses Public.
  - Add sets writes nothing until Add is pressed; Cancel or Back writes nothing.
  - The sets you own show on a profile only when its owner switches it on.
title: Your sets and lists
nav: Sets and lists
description: Mark the sets you own and want in a tap, save gallery models, gather both into lists of your own, share a list by a link or publicly, see an import before it is made, and browse every public list.
---

Every LEGO® set in the [library](/library) and every model in the [gallery](/gallery) has the same control on its card, and a model's page has it beside **Like**: **Own** or **Save** at a tap, and a chevron beside it for all your lists. Your lists, from the account menu, is where you manage them. Each list is **Only you**, **Anyone with the link** or **Public**: a public one has its own page and is in the gallery's [Lists](#directory).

The sets you own are [My collection](/docs/collection): owning a set on the site puts its parts in the app's **Build › My collection…** at once, and the other way round.

## Own and want a set {#own}

1. On a set's card, press **Own**. It shows a check at once, and a note at the foot of the page says it is in the sets you own, with **Undo**.
2. On a set's page, the bar under its name has **Own**, **Want** (your wishlist) and **Add to a list**.
3. Press the chevron (or **Add to a list**) for the panel: **I own it**, with − and + for how many copies, **I want it**, a box for each of your lists, and **New list…** to make one with the set already in it. Each box saves as you tick it and says so. On a phone the panel is a sheet at the foot of the screen.

Own and Want are separate: you can own one copy and want another. Signed out, any of these asks you to sign in (a code by email, no password) and then does what you pressed. A card shows ×2 when you own two, and a dot on its chevron when it is in a list of yours.

On a set's page you own, **Parts you own** has **You own** with − and + round how many copies: type a number from 1 to 99 and press Enter, or 0 to take the set out (with **Undo**). Each copy counts its parts again, for the gallery's cards and every model's [What you're missing](/docs/model-pages#missing). Changed on another device or tab meanwhile, it says so and shows the number there now.

![Parts you own on a set's page, signed in: You own, with − and + round a box saying 2, copies of this set: its parts count as yours that many times; then Parts you own: all of them.](/docs/img/set-own-count.webp "How many of a set you own, on its page.")

![You own − 2 + on a set's page on a phone, and Parts you own: all of them.](/docs/img/set-own-count-phone.webp "How many you own, on a phone.")

A set's page also says **In 3 lists** when people put it in public lists: each list by name and whose, a link to it. Wishlists and private lists are never counted.

![In 3 lists on a set's page: People put it in 3 public lists, and the lists by name, each with whose it is.](/docs/img/set-in-lists.webp "The public lists a set is in.")

![In 3 lists on a phone: the three public lists the set is in, as pills.](/docs/img/set-in-lists-phone.webp "The lists a set is in, on a phone.")

## Save a model {#save-card}

A model's card in the gallery, and a model's own page beside **Like**, have **Save** and the same chevron. **Save** keeps it in **Saved** at a tap (your own, nobody else sees it), with **Undo** in the note it shows. The chevron opens the panel: **Saved** and a box for each of your lists, each saying who sees it (*only you*, *by its link* or *public*), and **New list…** to make one with the model already in it. It is the same panel and the same Saved, on the card and on the page.

![A model's page, signed in, with Save pressed and its chevron's panel open: the model's name, Saved ticked, Your lists with a box for each marked only you, by its link or public, New list… and Manage your lists.](/docs/img/lists-save.webp "Save and your lists, on a model's page.")

![Save's panel on a phone: a sheet from the foot of the screen with Saved and your lists.](/docs/img/lists-save-phone.webp "The same panel on a phone.")

## Your lists {#your-lists}

**Your lists** in the account menu ([brickworks.diy/lists](/lists)) has, on the left (a dropdown on a phone), **I own**, **I want**, **Saved** and every list of yours, and **New list**. A list shows its sets and models as cards, and:

- **Share**: its link, to copy or send. A list only you see asks first who may open it: **Anyone with the link** (chosen for you) or **Public**. See [Who sees a list](#who-sees).
- **Stop sharing** (a list shared by a link): its link opens nothing from then on.
- **Edit**: its name, its words, **Who sees it**, its cover (any picture in it), and **Delete list** (with **Undo** for a few seconds).
- **Newest first** or **Your order**: in your order, drag a card or use its arrows; **Undo** puts it back.
- **Select**: tick cards, then **Copy to**, **Move to** or **Take out**.
- **Add sets**: a Rebrickable CSV, a BrickLink XML or a Brickset CSV file, or set numbers typed in ("10497, 6080, 75192-1"). It shows what it would do first, and adds nothing until you press **Add**: see [Bring sets in](#import). Into **I own**, a file from a site can replace what that site's file brought in before.
- **Download CSV**: the sets, in Rebrickable's columns, for Rebrickable or Brickset.

The wishlist (**I want**) is private until you share it. **Share** on it chooses **Anyone with the link** for you: its link tells whoever gives you a present what to give, and it is on no profile and in no directory. Choose **Public** instead and it is on your profile too (never in the directory).

## Who sees a list {#who-sees}

Each list of yours is one of three, chosen in **Edit** or when you first press **Share**:

- **Only you**: a new list, until you choose otherwise.
- **Anyone with the link**: it opens at its own link (`brickworks.diy/c/<id>?link=…`) for whoever has it, and nowhere else. It is not on your profile, not in the gallery's Lists, not in the search and not in the sitemap, and search engines are told not to list it. **Stop sharing** (or **Only you** in **Edit**) turns the link off: from the next time anyone opens it, it says there is nothing there. Sharing again makes a new link, so the old one never opens it again.
- **Public**: its page at `/c/<id>` is on your profile and in the gallery's [Lists](#directory), and anyone may follow it.

A list Brickworks took down after a report stays **Only you**, with everything in it.

![Share on a list only you see: Share Weekend builds asks who may open it once you send its link, with Anyone with the link chosen (not on your profile or in the gallery, and you can stop sharing at any time) and Public, then Share it and Cancel.](/docs/img/lists-share-link.webp "Sharing a list by its link.")

![The same on a phone.](/docs/img/lists-share-link-phone.webp "Sharing by a link, on a phone.")

## Bring sets in {#import}

**Add sets** on **I own**, **I want** or a list of yours takes set numbers typed or pasted, or a file: Rebrickable's CSV, BrickLink's XML or Brickset's CSV. Press **See what it adds** and it shows, before anything is written:

- **to add**: sets Brickworks has that are not there yet;
- **already there**: left as they are (into **I own** with **replace**, kept as the file counts them);
- **not found**: numbers no set has (a typing slip, or a set too new for the catalogue), left out;
- into **I own**, also the loose parts' lots, what a replace takes out, and a Brickset file's wanted sets for your wishlist.

Press **Add** to bring them in, **Back** to change what you gave, or **Cancel**: nothing is written until **Add**.

![Add sets showing what it adds: 3 to add, 1 already there, 1 not found with its number, and Add 3 sets, Back and Cancel.](/docs/img/lists-import-preview.webp "What an import adds, before it adds it.")

![The same on a phone.](/docs/img/lists-import-preview-phone.webp "An import's preview, on a phone.")

## The sets you own on your profile {#owned}

On **Your lists › I own**, switch on **Show on my profile**. Your profile then has a **Sets** tab: how many sets, parts, minifigures and themes, the theme you own most, and every set as a card, with a search and filters by theme, decade and size and an order. A filtered view's address can be shared. Switch it off and the tab is gone.

<!-- covers
lib:your sets and lists
ui:own want and save
ui:your lists page
ui:the sets you own on a profile
-->

## Save a model from its page {#save}

On a model's page, **Save** beside **Like** is the card's: press it to keep the model in **Saved**, or its chevron for your lists (see [Save a model](#save-card)). Signed out, it asks you to sign in first, then saves it. Press it again to let it go.

## Your account's Saved tab {#public}

On your profile, **Saved** shows the models you saved and your lists. For each list: its name, **Public**, **Save**, **Delete**, **Its page** and **What is in it**; who else sees each, by its link too, is on [Your lists](#who-sees).

## A list's page {#page}

Each public list has a page at `/c/<id>`: its cover, its name, *Made by* its owner and when it was last added to, its words, its sets and models (the last put in first, or in its owner's order), **Follow**, **Share** (the sheet a model's page has, with the list's link) and **More** (**Report it**). Following a list puts each model added to it in [your feed](/docs/profiles#feed). A model's page says how many public lists it is in. A list shared by a link has the same page at its link, says it was shared with you by its link, and has no **Follow**.

## The directory {#directory}

[brickworks.diy/gallery-lists](/gallery-lists), the gallery's **Lists** tab, lists every public list with at least one set or a model in the gallery (never a wishlist, never one shared only by a link). Each card has its cover (up to four of its models' pictures), its name, its owner, how many models and followers, and **Follow**. Order them by **Recently added to** (the default: the one a model went into last first) or **Most followed**. **Search lists by name or builder** finds one by its name, its words or its owner. It is linked from the site's footer too. It was called Collections, at `/collections`: that address, with anything after it, still lands here.

![The gallery's Lists tab: the search, the pills Recently added to and Most followed, and lists as cards, each with a cover of four model pictures, its name, its owner, how many models and followers, and Follow.](/docs/img/lists-directory.webp "brickworks.diy/gallery-lists.")

![The gallery's Lists tab on a phone.](/docs/img/lists-directory-phone.webp "The gallery's Lists, on a phone.")

<!-- covers
ui:collections directory
-->
