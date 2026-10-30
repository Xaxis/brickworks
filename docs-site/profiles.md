---
ai: A person's profile and public page (/u/<handle>), following designers, the feed of what they make, notifications, the account menu and the site's settings.
rules:
  - Following is for people 13 and over.
title: Profiles, following and your feed
nav: Profiles and your feed
description: Your profile, following designers, your feed and notifications, your account menu and settings.
---

## Your profile {#profile}

[brickworks.diy/profile](/profile) is your own page, signed in. The first time, give it a name and a handle; your public page is then `/u/<handle>`. **Edit profile** sets your name, your links, a banner and the models pinned at the top. Its tabs are **Models**, **Builds**, **Saved**, **Sets**, **Insights** and **Achievements**.

<!-- covers
ui:your profile page
ui:profile and collection pages
api:GET/POST /api/people
-->

### Your picture {#avatar}

**Edit profile › Choose a picture**: a JPEG, PNG or WebP up to 8 MB, cropped to a circle in the page (drag it, zoom with the buttons, the wheel or two fingers). **Use this picture** keeps it; **Remove the picture** goes back to the letter on a coloured tile.

<!-- covers
ui:your own picture as your avatar
-->

### Achievements and insights {#achievements}

Under your numbers are your achievements, on your page for everybody to see: each challenge your models won, then your level on each track, the highest first.

| Track | What counts | Its levels |
| --- | --- | --- |
| **Designer** | models you listed in the gallery | 1, 3, 10, 25, 50, 100 |
| **Built** | builds of your models finished to the last step | 1, 10, 50, 100, 500, 1,000 |
| **Builder** | photos you posted of your real builds | 1, 5, 10, 25, 50 |
| **Remixed** | remixes of your models | 1, 5, 25, 100 |
| **Tested** | your models marked [Tested](/docs/sharing#tested) | 1, 5, 10, 25 |
| **Challenger** | [challenges](/docs/challenges) you entered | 1, 3, 6, 12 |

Your profile's **Achievements** tab shows every track, for you alone: your level, how far the next one is and what gets you there. Reaching a level is a [notification](#notifications). A level stays yours if a number goes down later.

**Insights** (and *How your models are doing* on your own `/u/` page) says, for you alone, how each of your models is doing.

<!-- covers
ui:achievements on a profile
lib:achievements with levels
ui:your achievements tab
ui:your models as a designer
-->

## First steps {#first-steps}

After a first sign-in, **First steps** helps you start: make your profile, say what you build, and pick designers and models to start with. Each step can be skipped; **See your feed** ends it.

<!-- covers
ui:first steps after a first sign-in
-->

## Follow {#follow}

**Follow** on a designer's page or a model's page puts what they make in your feed. Your profile counts who you follow and who follows you.

**More like** on a designer's page lists up to six designers whose models share the most with theirs: the same themes, tags and parts. Each has **Follow** beside it. It never lists you or anyone you follow already, and it is not shown when nobody is close.

**Share** on anybody's page, and on your own, opens the sheet a model's page has: the page's link to copy, and **Post it to** Reddit, Bluesky, Pinterest (with the banner's picture), X, Facebook or email.

<!-- covers
ui:follow a person and the count on Account
lib:follows and the feed
ui:more like on a profile
lib:more like a designer
-->

## Your feed {#feed}

[brickworks.diy/feed](/feed) is what the people you follow made, newest first: each new model, new version and photo of a build as a post with its picture. Following nobody, or with nothing new, it shows **Latest on Brickworks** and designers to follow. In the app, **Account** says how many new posts there are (*Account · 3*), with **Open your feed**.

<!-- covers
ui:your feed page
lib:latest on Brickworks and designers to follow
ui:the app's Account count
-->

## Notifications {#notifications}

[brickworks.diy/notifications](/notifications) says what happened to your models: comments, replies, photos of builds and likes, grouped by model with its picture, newest first. A comment that [mentions you](/docs/model-pages#mentions) is there too, under its model. Each level of an [achievement](#achievements) you reach is there too, in a group of its own. So is each [challenge](/docs/challenges#told): when it opens, its last two days, and who won one you voted in. Opening it clears the count on your avatar; **Mark all read** clears them all.

<!-- covers
ui:notifications page
lib:notifications apart from the feed
-->

## The account menu {#account-menu}

Signed in, your avatar at the top right of every page opens who you are, **Your profile**, **Notifications** and **Your feed** with their counts, **Saved**, **Settings**, the theme and **Sign out**. On a phone it is **Menu**.

<!-- covers
ui:the account menu
-->

## Settings {#settings}

[brickworks.diy/settings](/settings): **Profile**, **Appearance** (System, Light or Dark, kept with your account), **Email**, **Privacy** (whether your liked models show on your profile, off by default), **Claude** (your connection), **Sign out** and **Delete account**.

<!-- covers
ui:your settings page
ui:likes on a profile
ui:theme choice
-->
