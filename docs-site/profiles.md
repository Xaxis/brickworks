---
ai: A person's profile and public page (/u/<handle>), following designers, the feed of what they make, notifications, the account menu and the site's settings (profile, appearance, the daily email, orangecheck, privacy, assistants, reports).
rules:
  - Following is for people 13 and over.
title: Profiles, following and your feed
nav: Profiles and your feed
description: Make your profile, follow designers, read your feed and notifications, and find the account menu and your settings.
---

Your profile is your page on the site: your models, your builds and what you have earned, at `/u/<handle>` for everybody and at [brickworks.diy/profile](/profile) for you, signed in: **Your profile** in [the account menu](#account-menu) under your avatar.

## Your profile {#profile}

1. Open [brickworks.diy/profile](/profile). The first time, **Make your profile**: a name and a handle (3 to 24 lower-case letters, digits and dashes), then **Make my profile**. Your public page is then `/u/<handle>`.
2. **Edit profile** sets your **Name**, **Handle**, **About you**, up to two links, **Across the top** (a model's picture for the banner) and up to three models **Pinned above the rest, in this order**. **Save** keeps them.

Its tabs are **Models**, **Builds**, **Likes** (only when you chose to show them, in [Settings › Privacy](#settings)), **Saved** (your Favourites and [collections](/docs/collections)), **Sets**, **Insights** and **Achievements**. Saved, Sets and Achievements say *Only you see this tab.*

![Your profile, signed in: the banner, your avatar, name and handle with Edit profile, Settings and Share, your numbers and achievements, and the tabs Models, Builds, Saved, Sets, Insights and Achievements over your models' cards.](/docs/img/profile-page.webp "brickworks.diy/profile, signed in.")

<!-- covers
ui:your profile page
ui:profile and collection pages
api:GET/POST /api/people
-->

### Your picture {#avatar}

**Edit profile › Choose a picture**: a JPEG, PNG or WebP up to 8 MB and at least 120 pixels a side. Drag it in the circle, and zoom with the buttons, the wheel, two fingers or [[+]] and [[-]]; **Use this picture** keeps it. **Remove the picture** goes back to the letter on a coloured tile.

<!-- covers
ui:your own picture as your avatar
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

The **Achievements** tab shows every track: your level, how many more reach the next and what gets you there. Reaching a level is a [notification](#notifications). **Insights** (*How your models are doing* on your own `/u/` page) says, for you alone, how each of your models is doing.

<!-- covers
ui:achievements on a profile
lib:achievements with levels
ui:your achievements tab
ui:your models as a designer
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

## Your feed {#feed}

[brickworks.diy/feed](/feed) is what the people you follow made, newest first: new models, new versions, photos of builds, and models added to collections you follow. With nothing new it shows **Latest on Brickworks** and designers to follow. In the app, **Account** says how many posts are new (*Account · 3*), with **Open your feed**.

<!-- covers
ui:your feed page
lib:latest on Brickworks and designers to follow
ui:the app's Account count
-->

## Notifications {#notifications}

[brickworks.diy/notifications](/notifications) says what happened to your models, grouped by model, newest first: comments, replies, [mentions](/docs/model-pages#mentions), photos of builds, remixes, and how many liked it that day. **Your achievements** are a group of their own, and so is each [challenge](/docs/challenges#told). Opening it clears the count on your avatar; **Mark all read** clears them all.

<!-- covers
ui:notifications page
lib:notifications apart from the feed
-->

## The account menu {#account-menu}

Signed in, your avatar at the top right of every page opens your name and handle, **Your profile**, **Notifications** and **Your feed** with their counts, **Saved**, **Settings**, **Beta hub** (for a [beta tester](/docs/beta)), **Send feedback** ([feedback](/docs/feedback)), the theme (**System**, **Light**, **Dark**) and **Sign out**. On a phone the same avatar holds the site's menu too.

![The account menu open under the avatar: your name and handle, Your profile, Notifications and Your feed with their counts, Saved, Settings, Send feedback, the theme as System, Light and Dark, and Sign out.](/docs/img/profile-menu.webp "The account menu.")

<!-- covers
ui:the account menu
-->

## Settings {#settings}

[brickworks.diy/settings](/settings), from the account menu:

- **Profile**: **Edit profile**.
- **Appearance**: **System**, **Light** or **Dark**, kept in this browser and with your account.
- **Email**: the daily email, every box off until you tick it. **Email me when somebody comments on a model I shared**, and in the same email what came into your feed: new models and versions from people you follow, photos of builds, remixes of yours. At most one email a day.
- **orangecheck**: **Link orangecheck** to sign in with it as well as your email ([signing in](/docs/account#sign-in)); **Unlink** to stop. Each first sends a code to your email to confirm it is you, unless you signed in with one in the last five minutes, and your email is told.
- **Privacy**: your age answer, **Show on my profile whom I follow**, and **Show on my profile the models I liked** (the Likes tab).
- **Assistants**: the AI apps that can work in your Brickworks tabs ([the connector](/docs/connector)).
- **Your reports**: **Send feedback**, and each report you sent with where it stands and our answer ([feedback](/docs/feedback#yours)).
- **Sign out** and **Delete account** ([your account](/docs/account#delete)).

While the [beta](/docs/beta) is open, **Beta** comes after Profile.

![Settings: the contents list down the side, and Profile, Appearance with System, Light and Dark, and Email with its boxes for the daily email.](/docs/img/settings-page.webp "brickworks.diy/settings.")

<!-- covers
ui:your settings page
ui:likes on a profile
ui:theme choice
-->
