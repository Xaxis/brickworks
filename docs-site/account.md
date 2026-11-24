---
panels: AccountPanel#account-panel
ai: Signing in (an email code, Google, GitHub or orangecheck, no password; every sign-in also makes your orangecheck account), the age question, what Brickworks keeps, and deleting the account. Account in the app says who is signed in and where the models are kept; with the assistant on, it shows the AI apps connected and this tab's chats.
rules:
  - Brickworks accounts are for people 13 and over; a younger builder builds on a parent's or guardian's account.
  - Deleting the account ends every AI app's connection too.
title: Your account and privacy
nav: Your account and privacy
description: Signing in with a code, Google, GitHub or orangecheck, the orangecheck account signing in makes, the age question, Account in the app, what Brickworks keeps, and deleting your account.
---

Your account keeps your models, your collection and your profile, and the app and the site share it: a browser signed in to one is signed in to the other. In the app it is **Account** on the top bar (also **Brickworks › Account…**); on the site, [Settings](/settings), under your picture at the top right.

## Sign in {#sign-in}

There is no password. The app asks the first time it opens; on the site, **Sign in** at the top right.

1. Type your email address and press **Email me a code**. Signing in makes your account if you have none.
2. Type the six-digit code from the email and press **Sign in**. It works once, for ten minutes; if it has not come, look in spam, or ask for a new one.

Or press **Sign in with Google** or **Sign in with GitHub**: you sign in there and come back to the page you were on, signed in. Brickworks asks either only for your email address, and only one it has verified, so it is the same account a code to that address signs you in to; a new address makes a new account. Google signs you in with a Gmail address, or a Google Workspace address of your organisation; for any other address, sign in with a code. The first time GitHub signs in to an account you already have, it asks for a code to the address once, then GitHub signs you in from then on. Signed in with Google or GitHub many times in a few minutes, from one account or one network, you are asked to wait a few minutes; a code still signs you in. In the desktop app it opens in your browser and comes back to the app.

Or press **Sign in with orangecheck**: it opens its own window and takes a Bitcoin wallet, email, Google or GitHub, and Brickworks gets an id for you, not your address.

![The site's Sign in to Brickworks dialog: the Email box with Email me a code, then Sign in with Google, Sign in with GitHub and Sign in with orangecheck, and the line Signing in without orangecheck also makes your orangecheck account, with What is that?](/docs/img/account-sign-in.webp "Signing in on the site: a code by email, Google, GitHub or orangecheck.")

You stay signed in on that device until you sign out. [Settings](/settings) › **How you sign in** lists each way that signs you in: a code to your address always does; **Unlink** takes Google or GitHub off, and signs out wherever it signed you in, and **Link again** puts it back. To sign in with orangecheck as well as your email, [Settings](/settings) › **orangecheck** › **Link orangecheck**; it first sends a code to your email, to be sure it is you ([Settings](/docs/profiles#settings)).

<!-- covers
ui:sign in with google
ui:sign in with github
api:GET /auth/google
api:GET /auth/github
api:POST /api/otp?op=way_take
api:POST /api/otp?op=way_bind
api:GET /api/otp?op=ways
ui:how you sign in
-->

## Your orangecheck account {#orangecheck}

Signing in, with a code, Google or GitHub, also makes you an [orangecheck](https://ochk.io) account, as the sign-in says: once you are 13 or over, at the first sign-in after that, and only once. There is nothing to tick. Your address goes with it: as one you showed is yours when you signed in with a code in the last five minutes, and otherwise as one orangecheck checks itself. orangecheck keeps it for you until you claim it at [ochk.app](https://ochk.app) by signing in there with the same address; then you can use it on other sites, or delete it. If orangecheck is slow or down when you sign in, you are signed in all the same, and the account is made at a later sign-in. [Settings](/settings) › **orangecheck** says when it was made. Deleting your Brickworks account deletes it too, unless you have claimed it ([what is sent, and kept](/privacy#signing-in-with-orangecheck)).

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

![The Account panel: Signed in as you@example.com, signed in on this device until you sign out, where your models are kept, then Your AI: not connected, with Connect Claude, and Sign out and Close at its foot.](/docs/img/account-panel.webp "Account, from the top bar, with the assistant on.")

- who is signed in, and where your models are kept: on this device and with your account, and whether the browser has agreed not to clear them;
- with the assistant on (**Tools › Settings…**, *Assistant (AI)*), **Your AI**: the AI apps connected to your account, since when and when last used, with **Connect** (**Open in Claude** once Claude is connected) and **Disconnect**; once connected, this tab's name to say to your AI, its chats, and **New chat for this tab** ([the connector](/docs/connector#tabs)). With the assistant off, nothing here speaks of AI;
- what is new in your feed, and **Open your feed**;
- while the [beta](/docs/beta) is open, **Beta**: join or leave in one press;
- **Sign out**, which signs this device out and keeps your models on it, and **Close**.

<!-- covers
ui:account panel
-->

## What Brickworks keeps {#privacy}

Your models, your collection and your profile are kept with your account, and nobody sees a model until you share it. A key you give for an AI, Anthropic's or any other provider's, stays in your browser and goes only to that provider ([where a key is kept](/docs/connect#key-custody)). A photo of a build is cleaned of what the camera wrote into it, such as where it was taken. The [privacy page](/privacy) says everything kept and why, and the [terms](/terms) and [guidelines](/guidelines) what the site asks of everyone.

Brickworks also counts how its site and studio are used, to make them better: which kinds of page, tools and panels, how long the studio takes to start and what goes wrong. Never your models, what you type, your email address or your IP address. Where the law asks for a yes first, you are asked; a browser sending Do Not Track or Global Privacy Control is never counted, and **Settings › Privacy** turns it off. [What is counted](/counting) says it all.

<!-- covers
ui:privacy page
ui:terms and guidelines
ui:the counter and its ask
ui:what is counted page
-->

## Delete your account {#delete}

1. First, if you want your models: **File › Export › All my models (.zip)** saves every one as LDraw files in one .zip.
2. [Settings](/settings), at the foot: **Delete this account…**.
3. Type your email address, press **Delete my account**, and say yes.

Signed in with orangecheck, it first emails a code to the account's address: type it and press **Delete my account** again. An account made with orangecheck alone has **Sign in with orangecheck to delete** instead.

It cannot be undone. Your models come out of the gallery and their links stop working; your profile, saved models, lists (public, shared by a link or private), comments, follows, photos, the sets you own and every AI app's connection are deleted with the account.

<!-- covers
lib:an account's deletion
-->
