---
panels: AccountPanel#account-panel
ai: Signing in (an email code or orangecheck, no password), the age question, what Brickworks keeps, and deleting the account. Account in the app shows the saved models, the Claude connection and the tabs.
rules:
  - Comments, the Build together chat and following are for people 13 and over.
  - Deleting the account ends Claude's connection too.
title: Your account and privacy
nav: Your account and privacy
description: Signing in, the age question, what Brickworks keeps, and deleting your account.
---

## Sign in {#sign-in}

There is no password. Sign in with **a code by email**, six digits sent to your address; or with **orangecheck**, which opens its own window and accepts a Bitcoin wallet, email, Google or GitHub. The site and the app share one account, and a browser signed in to the app is signed in to the site.

<!-- covers
api:POST /api/otp
ui:sign in with orangecheck
api:POST /api/orangecheck
lib:site sign-in
api:GET /api/account
-->

## The age question {#age}

A new account is asked its month and year of birth, once. Some things are for people 13 and over: comments, the chat in Build together, and following.

<!-- covers
ui:age question
api:POST /api/account?op=age
-->

## Account in the app {#account-panel}

**Account** on the toolbar (or **File › Account…**) says who is signed in, how many saved models your account holds, your Claude connection with **Disconnect Claude**, your tabs and their chats, and **Sign out**.

<!-- covers
ui:account panel
-->

## What Brickworks keeps {#privacy}

Your models, your collection and your profile are kept with your account, and nobody sees a model until you share it. An Anthropic API key stays in your browser and goes only to Anthropic. A photo of a build is cleaned of what the camera wrote into it, such as where it was taken. The [privacy page](/privacy) says everything kept and why, and the [terms](/terms) and [guidelines](/guidelines) what the site asks of everyone.

<!-- covers
ui:privacy page
ui:terms and guidelines
-->

## Delete your account {#delete}

[Settings](/settings) › **Delete account** deletes your account and what is kept with it, Claude's connection among them. Before you do, **File › Export › All my models** saves every model as LDraw files in one .zip.
