---
panels: AccountPanel#account-panel
ai: Signing in (an email code or orangecheck, no password), the age question, what Brickworks keeps, and deleting the account. Account in the app says who is signed in and where the models are kept; with the assistant on, it shows the AI apps connected and this tab's chats.
rules:
  - Brickworks accounts are for people 13 and over; a younger builder builds on a parent's or guardian's account.
  - Deleting the account ends every AI app's connection too.
title: Your account and privacy
nav: Your account and privacy
description: Signing in with a code or orangecheck, the age question, Account in the app, what Brickworks keeps, and deleting your account.
---

Your account keeps your models, your collection and your profile, and the app and the site share it: a browser signed in to one is signed in to the other. In the app it is **Account** on the top bar (also **Brickworks › Account…**); on the site, [Settings](/settings), under your picture at the top right.

## Sign in {#sign-in}

There is no password. The app asks the first time it opens; on the site, **Sign in** at the top right.

1. Type your email address and press **Email me a code**. Signing in makes your account if you have none.
2. Type the six-digit code from the email and press **Sign in**. It works once, for ten minutes; if it has not come, look in spam, or ask for a new one.

Or press **Sign in with orangecheck**: it opens its own window and takes a Bitcoin wallet, email, Google or GitHub, and Brickworks gets an id for you, not your address. On the site, ticking **Also create my orangecheck account** under it makes you an orangecheck account as you sign in by code; it stays with orangecheck until you claim it at ochk.app.

![The site's Sign in to Brickworks dialog: the email box with Email me a code and Not now, Sign in with orangecheck with what it takes, and the box to also create an orangecheck account.](/docs/img/account-sign-in.webp "Signing in on the site.")

You stay signed in on that device until you sign out. To sign in with orangecheck as well as your email, [Settings](/settings) › **orangecheck** › **Link orangecheck**; it first sends a code to your email, to be sure it is you ([Settings](/docs/profiles#settings)).

<!-- covers
api:POST /api/otp
ui:sign in with orangecheck
api:POST /api/orangecheck
lib:site sign-in
api:GET /api/account
-->

## The age question {#age}

A new account is asked its month and year of birth, once, and the date itself is not kept. Brickworks accounts are for people 13 and over. An answer under 13 deletes the account just made, with its email address, and says to ask a parent or guardian to sign in with their own email and build with you. The browser or computer keeps only that it was told, so it says so at once the next time.

<!-- covers
ui:age question
api:POST /api/account?op=age
-->

## Account in the app {#account-panel}

**Account** on the top bar opens it; a number beside the word (*Account · 3*) is what came into your feed since you last looked.

![The Account panel over the model: Signed in as you@example.com, where your models are kept, Your AI with Connect Claude, the chats of this tab, and Sign out and Done at its foot.](/docs/img/account-panel.webp "Account, from the top bar.")

- who is signed in, and where your models are kept: on this device and with your account, and whether the browser has agreed not to clear them;
- with the assistant on (**Tools › Settings…**, *Assistant (AI)*), **Your AI**: the AI apps connected to your account, since when and when last used, with **Connect** (**Open in Claude** once Claude is connected) and **Disconnect**; once connected, this tab's name to say to your AI, its chats, and **New chat for this tab** ([the connector](/docs/connector#tabs)). With the assistant off, nothing here speaks of AI;
- what is new in your feed, and **Open your feed**;
- while the [beta](/docs/beta) is open, **Beta**: join or leave in one press;
- **Sign out**, which signs this device out and keeps your models on it, and **Done**.

<!-- covers
ui:account panel
-->

## What Brickworks keeps {#privacy}

Your models, your collection and your profile are kept with your account, and nobody sees a model until you share it. A key you give for an AI, Anthropic's or any other provider's, stays in your browser and goes only to that provider ([where a key is kept](/docs/connect#key-custody)). A photo of a build is cleaned of what the camera wrote into it, such as where it was taken. The [privacy page](/privacy) says everything kept and why, and the [terms](/terms) and [guidelines](/guidelines) what the site asks of everyone.

<!-- covers
ui:privacy page
ui:terms and guidelines
-->

## Delete your account {#delete}

1. First, if you want your models: **File › Export › All my models (.zip)** saves every one as LDraw files in one .zip.
2. [Settings](/settings), at the foot: **Delete this account…**.
3. Type your email address, press **Delete my account**, and say yes.

Signed in with orangecheck, it first emails a code to the account's address: type it and press **Delete my account** again. An account made with orangecheck alone has **Sign in with orangecheck to delete** instead.

It cannot be undone. Your models come out of the gallery and their links stop working; your profile, favourites, collections, comments, follows, photos, the sets you own and every AI app's connection are deleted with the account.
