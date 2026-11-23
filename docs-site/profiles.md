---
ai: A person's profile and public page (/u/<handle>), following designers, the feed of what they make, notifications, the account menu and the site's settings (profile, appearance, notifications: what you hear of here, by push and by email, and muted models, orangecheck, privacy, assistants, reports).
rules:
  - Following is for people 13 and over.
title: Profiles, following and your feed
nav: Profiles and your feed
description: Make your profile, follow designers, read your feed and notifications, and find the account menu and your settings.
---

Your profile is your page on the site: your models, your builds and what you have earned, at `/u/<handle>` for everybody and at [brickworks.diy/profile](/profile) for you, signed in: **Your profile** in [the account menu](#account-menu) under your avatar.

## Your profile {#profile}

1. Open [brickworks.diy/profile](/profile). The first time, **Make your profile**: a name and a handle (3 to 24 lower-case letters, digits and dashes), then **Make my profile**. Your public page is then `/u/<handle>`.
2. **Edit profile** sets your **Name**, **Handle**, **About you**, up to two links, **Across the top** (a model's picture for the banner) and up to three models **Pinned above the rest, in this order**, first in the **Models** tab. **Save** keeps them.

Its tabs are **Models**, **Builds**, **Likes** (only when you chose to show them, in [Settings › Privacy](#settings)), **Saved** (the models you saved and [your lists](/docs/lists)), **Sets**, **Insights** and **Achievements**. Saved, Sets and Achievements say *Only you see this tab.*

![Your profile, signed in: the banner, your avatar, name and handle with Edit profile, Settings and Share, your numbers and achievements, and the tabs Models, Builds, Saved, Sets, Insights and Achievements over your models' cards.](/docs/img/profile-page.webp "brickworks.diy/profile, signed in.")

<!-- covers
ui:your profile page
ui:profile and collection pages
api:GET/POST /api/people
-->

### Your picture {#avatar}

Everybody starts with a minifig made from their handle: a face, hair or a hat and a torso of real parts from the LDraw™ library, the same on every page. You can make your own, or put a picture of your own in its place.

**Edit profile › Make a minifig** opens the maker on your minifig. Pick a **Face**, **Hair or hat** (and its **Hair colour**), a **Torso** print, the **Torso colour**, the **Legs colour** and a **Background**; each choice shows your minifig with it. **Surprise me** makes one at random. The minifig is shown large and at the sizes the site uses (beside a comment, on a card, on your profile) on a light page and a dark one. **Save** makes it your avatar; **Change your minifig** opens the maker on it again.

![Make your minifig: the minifig large, then at its sizes on a light and a dark page, Surprise me, and its choices: faces, hair or a hat, hair colour, torso prints and colours, legs colour and background, then Save and Cancel.](/docs/img/profile-minifig.webp "Edit profile › Make a minifig.")

**Edit profile › Choose a picture**: a JPEG, PNG or WebP up to 8 MB and at least 120 pixels a side. Drag it in the circle, and zoom with the buttons, the wheel, two fingers or [[+]] and [[-]]; **Use this picture** keeps it. Your minifig and a picture are alternatives: whichever you saved last is your avatar. **Remove the picture** (or **Remove your minifig**) goes back to the minifig made from your handle.

<!-- covers
ui:your own picture as your avatar
ui:a minifig of your own as your avatar
-->

### Achievements and insights {#achievements}

Under your numbers are your achievements, for everybody to see: each challenge your models won, then your level on each track, the highest first.

| Track | What counts | Its levels |
| --- | --- | --- |
| **Designer** | models you listed in the gallery | 1, 3, 10, 25, 50, 100 |
| **Built** | builds of your models finished to the last step | 1, 10, 50, 100, 500, 1,000 |
| **Builder** | photos you posted of your real builds | 1, 5, 10, 25, 50 |
| **Remixed** | remixes of your models | 1, 5, 25, 100 |
| **Tested** | your models marked [Tested](/docs/sharing#tested) | 1, 5, 10, 25 |
| **Challenger** | [challenges](/docs/challenges) you entered | 1, 3, 6, 12 |

The **Achievements** tab shows every track: your level, how many more reach the next and what gets you there. Reaching a level is a [notification](#notifications). **Insights** (*How your models are doing* on your own `/u/` page) says, for you alone, how each of your models is doing, each number set against the same number of days before it, in whole days up to yesterday.

<!-- covers
ui:achievements on a profile
lib:achievements with levels
ui:your achievements tab
ui:your models as a designer
lib:a designer's numbers against last month
-->

## First steps {#first-steps}

After a first sign-in and the age question, **First steps** helps you start: **Make your profile**, **What do you build?**, and **Designers and models to start with**. Each can be skipped; **See your feed** or **Done** ends it.

<!-- covers
ui:first steps after a first sign-in
-->

## Follow {#follow}

**Follow** on a designer's page or a model's page puts what they make in your feed; it then reads **Following**, and pressing it again stops. Your profile counts who you follow and who follows you.

**More like** on a designer's page (on yours, *Designers like you*) lists up to six designers whose models share the most with theirs: themes, tags and parts, never you or anyone you follow already. **Share** on a profile opens the sheet a model's page has.

<!-- covers
ui:follow a person and the count on Account
lib:follows and the feed
ui:more like on a profile
lib:more like a designer
-->

### Block someone {#block}

**Block** in the **More** menu on a person's profile, or beside one of their comments, blocks them after one question. Their models leave your gallery, feed and search, and you hear nothing more from them. Their comments on your models are hidden from everyone but them. Follows between you end both ways, and neither of you can follow, like, comment on, reply to, remix, put in a collection or `@`-name the other. Their remixes and public collections leave your model's page, for everyone. They are never told: if they try, they see only that it can't be done.

**Settings › Blocked people** lists everyone you blocked, with **Unblock**. Unblocking brings back their models and comments, but not the follows. The site's owner sees only how many people blocked an account, never who.

<!-- covers
ui:block a person
lib:blocking a person
-->

## Your feed {#feed}

[brickworks.diy/feed](/feed) is what the people you follow made, newest first: new models, new versions, photos of builds, and models added to lists you follow. With nothing new it shows **Latest on Brickworks** and designers to follow. In the app, **Account** says how many posts are new (*Account · 3*), with **Open your feed**.

<!-- covers
ui:your feed page
lib:latest on Brickworks and designers to follow
ui:the app's Account count
-->

## Notifications {#notifications}

[brickworks.diy/notifications](/notifications) says what happened to your models, grouped by model, newest first: comments, replies, [mentions](/docs/model-pages#mentions), photos of builds, remixes, and how many liked it that day. **Your achievements** are a group of their own, and so is each [challenge](/docs/challenges#told). News from Brickworks, such as a new feature or planned upkeep, is a group of its own too, marked *From Brickworks* (and *edited* if it was changed after it went). So is each [Talk](/docs/talk) thread you follow or that names you. Opening it clears the count on your avatar; **Mark all read** clears them all.

Each group has **Done** (the tick) and **More**:

- **Done** takes the group out of your count and out of the inbox into **Done**, at the top of the page beside **Inbox**. Anything new about it brings it back, with only what is new. **Mark all done** does it to everything at once. Each says so at the foot of the window, with **Undo**.
- **More › Mute this model**: nothing about that model reaches you any more, here, by push or by email, until you unmute it in [Settings](#settings) (or from the model's own page: **More › Unmute notifications**). A model's page has **More › Mute notifications** too.

Which kinds come here at all, and which by push or by email, is yours to choose in [Settings › Notifications](#settings).

![Notifications: Inbox and Done, Mark all read and Mark all done, then a group a model with its picture, newest first: the sports car's comment, likes and a photo of a build, a reply on the corner shop, your achievements, a remix, a challenge's last days and a mention, each with Done and More.](/docs/img/notifications-page.webp "brickworks.diy/notifications.")

![Notifications on a phone: the same groups, each with its picture, its name, Done and More, and its rows under it.](/docs/img/notifications-phone.webp "On a phone, at 390 px.")

<!-- covers
ui:notifications page
lib:notifications apart from the feed
ui:an announcement on a person's Notifications
ui:notifications done
ui:mute a model's notifications
-->

## The account menu {#account-menu}

Signed in, your avatar at the top right of every page opens your name and handle, **Your profile**, **Notifications** and **Your feed** with their counts, **Saved**, **Settings**, **Beta hub** (for a [beta tester](/docs/beta)), **Send feedback** ([feedback](/docs/feedback)), the theme (**System**, **Light**, **Dark**) and **Sign out**. Under your places, **Newest** shows your five newest [notifications](#notifications), each with its picture, the first five of the page: one opens its place, the comment or the photo itself. Looking at them there does not count them as seen. On a phone the same avatar holds the site's menu too.

![The account menu open under the avatar: your name and handle, Your profile, Notifications and Your feed with their counts, Saved, Settings, Send feedback, the newest five notifications with their pictures, the theme as System, Light and Dark, and Sign out.](/docs/img/profile-menu.webp "The account menu.")

<!-- covers
ui:the account menu
ui:the account menu's newest five
-->

## Settings {#settings}

[brickworks.diy/settings](/settings), from the account menu:

- **Profile**: **Edit profile**.
- **Appearance**: **System**, **Light** or **Dark**, kept in this browser and with your account.
- **Notifications**: **On this device**, **Notify me on this device** shows what you choose to have pushed (below) as this device's own notification within the minute: at first replies to your comments and mentions of you. Your browser asks whether to allow it only once you tick it, and each device you use is chosen on its own; signing out there, from any page, stops it there, and so does that sign-in ending any other way. **Turn off on every device** stops it everywhere at once, a phone left somewhere included. Several notifications about one model, or one thread of Talk, within three minutes come as one, which says how many more. On an iPhone or iPad (iOS 16.4 or later), [add Brickworks to your Home Screen](/docs/web-and-desktop#install) first and turn it on there: it opens in the studio, so open its menu, **Back to brickworks.diy**, then **Menu › Settings**. **Install Brickworks** is here too while your browser offers it.
  **What you hear of, and where**: a row for each kind (comments on your models, replies to your comments, mentions of you, photos of builds of your models, remixes, likes, new posts in Talk threads you follow, challenges, who won one you entered or voted in, levels of achievements, news from Brickworks) and a box for each place: **Here** (the bell, and your [notifications](#notifications)), **Push** (each device you turned on) and **Email** (one email a day at most, from the address sign-in codes come from). Everything comes here until you untick it; push is replies and mentions until you tick more; email is off until you tick it. Untick a kind everywhere and you do not hear of it at all. Each box says what it did under the grid.
  **Your feed by email**: in the same email, new models and versions from people you follow.
  News from Brickworks by email is new features and planned upkeep, a few times a month at most. Every one of those emails has an **Unsubscribe** link, and your mail app's own unsubscribe button works too.
  **Muted models**: the models you muted, each with **Unmute**.
- **Notifications**: **On this device**, **Notify me on this device** shows what your [notifications](#notifications) tell you, a comment or a reply, a mention, a photo of a build of your model, a remix, a challenge's result or a new post in [Talk](/docs/talk#thread), as this device's own notification within the minute. Your browser asks whether to allow it only once you tick it, and each device you use is chosen on its own; signing out there, from any page, stops it there, and so does that sign-in ending any other way. **Turn off on every device** stops it everywhere at once, a phone left somewhere included. Several notifications about one model, or one thread of Talk, within three minutes come as one, which says how many more. On an iPhone or iPad (iOS 16.4 or later), [add Brickworks to your Home Screen](/docs/web-and-desktop#install) first and turn it on there: it opens in the studio, so press the Brickworks mark at the top left for the home page, then **Menu › Settings**. **Install Brickworks** is here too while your browser offers it.
  **By email**: the daily email, every box off until you tick it. **Email me when somebody comments on a model I shared**, and in the same email what came into your feed: new models and versions from people you follow, photos of builds, remixes of yours. At most one email a day.
  **Email me Brickworks news** is off until you tick it: new features and planned upkeep, a few times a month at most. Every one of those emails has an **Unsubscribe** link, and your mail app's own unsubscribe button works too.
- **orangecheck**: **Link orangecheck** to sign in with it as well as your email ([signing in](/docs/account#sign-in)); **Unlink** to stop. Each first sends a code to your email to confirm it is you, unless you signed in with one in the last five minutes, and your email is told.
- **Privacy**: your age answer, **Show on my profile whom I follow**, and **Show on my profile the models I liked** (the Likes tab).
- **Assistants**: the AI apps that can work in your Brickworks tabs ([the connector](/docs/connector)).
- **Your reports**: **Send feedback**, and each report you sent with where it stands and our answer ([feedback](/docs/feedback#yours)).
- **Sign out** and **Delete account** ([your account](/docs/account#delete)).

While the [beta](/docs/beta) is open, **Beta** comes after Profile.

![Settings: the contents list down the side, and Profile, Appearance with System, Light and Dark, and Notifications with this device's and the grid of what you hear of, and where.](/docs/img/settings-page.webp "brickworks.diy/settings.")

![Settings › Notifications: On this device with Notify me on this device, then What you hear of, and where: a row for each of the eleven kinds, from comments on your models to news from Brickworks, each with a box for Here, Push and Email, then Your feed by email and Muted models with the boat and its Unmute.](/docs/img/settings-kinds.webp "Settings › Notifications: each kind here, by push, by email, or not at all.")

![The same grid on a phone: each kind's words, and its three boxes, each a finger's size.](/docs/img/settings-kinds-phone.webp "On a phone, at 390 px.")

<!-- covers
ui:your settings page
ui:what you hear of in settings
lib:what you hear of and where
ui:likes on a profile
ui:theme choice
ui:this device's notifications
lib:push sent to devices
lib:push subscriptions
-->
