# Plans: Free and Pro

The owner chose this on 2026-11-02, from the research report
`bench/results/research/reports/Brickworks pricing and competitor landscape.md`,
section "Sell cloud saves and commercial use, and give the desktop away".
**The desktop app is free again. Pro is every model kept with the account
and a licence for commercial use.** Nothing takes money: billing is off on
the live site, and no plan goes live until the owner says yes and the nine
conditions of section 5 are met.

It replaces plans332's design of 2026-10-29 (Pro was the desktop app; read it
with `git show 6efd991d:docs/PLANS.md`). What that design built and still
stands is kept: plans from Admission (U1), paying for Pro (U3), the interest
form. What only the paid desktop needed is gone (section 4). It is not legal
advice.

## 1. The plans

| | **Free** | **Pro** |
|---|---|---|
| Price | $0 | **$8 a month or $80 a year** ($6.67 a month, billed yearly) |
| Use | Personal and educational | **Commercial use**: selling instructions, kits, renders or builds made to order, under terms that come with Pro |
| The apps | The web app **and the desktop app** (offline, every part on disk, Claude Code started by the app) | The same |
| AI | Unlimited, on the person's own AI | The same |
| Models kept with the account | 25; saving to the device and exporting unlimited | **Unlimited**; later, a longer history of each model's versions (not built) |
| Trial | None | 30 days, no card, offered when someone first reaches 25 (not built) |

**Admission's names** (section 6): `saved_models` (cap; Free 25, Pro
unlimited) and `commercial_use` (flag; Pro on). `ai_builds` and `desktop`
still exist as features, because a feature cannot be deleted, but no plan
includes them.

- **Accounts made before 29 October 2026 keep Pro, free, with no end date**,
  as /plans promised when Pro was the desktop. They keep it now that Pro is
  unlimited models and commercial use. Given at launch as comps (U7).
- **Students and teachers get Pro free**, a year at a time, as a comp.
- **Over the cap nothing is deleted or locked.** Every model already kept
  stays; a new one goes to the account once it holds fewer than 25.
- **Every desktop version anyone downloaded keeps working**, with or
  without an account's plan: no build checks one.

## 2. Why

The report's case, in short: the server enforces a cloud limit, so a copied
app gains nothing, and commercial use is what LDCad, Fusion and JetBrains
charge for while personal use stays free. It also follows the LEGO Group's
Fair Play policy, which allows the trademarks only for non-commercial use.
The paid desktop was a fence that never held: versions 0.8 to 0.14 and the
public source are out. A free desktop answers "why not Studio?" for anyone
who wants Linux, offline use or Claude Code.

## 3. How it is enforced

- **Models kept:** `api/_billing.js` reads the account's plan from Admission
  (`entitlementOf`), and `api/models.js` refuses a new model over the
  account's cap (`mostModels`). With `BRICKWORKS_BILLING` off, as on the live
  site, nothing is asked and nothing is limited.
- **Commercial use:** a licence the terms grant to Pro. `?op=plan` says
  `commercialUse`; the app never checks it, and nothing in it is locked.
- **The desktop:** nothing. No download, start or sign-in asks a plan.

## 4. The desktop is free

Removed on 2026-11-02, built dark and never switched on: `api/_desktop.js`
and `?op=download` / `?op=entitlement` (GitHub's signed asset URLs, the RS256
desktop token), `src/account/desktop_pass.gd`, the Pro screen
(`src/ui/pass_gate.gd`), its probe, `tools/desktop_key.mjs`,
`tests/test_desktop.py`, and `supabase/desktop_paid_through.sql`, which was
never applied. `web/download.js` links every file to its public address. The
desktop still asks for sign-in exactly as before (`src/account/`).

The releases repo no longer has to go private for Pro: that was only the
paid desktop's fence (the report's condition 4 asks it "if the desktop is
sold"). `RELEASES_TOKEN` stays useful to the link checks
(`tools/release/release_links.sh`).

## 5. Before the first payment

The report's nine conditions, none optional. Where each stands on 2026-11-03 (golive, section 8):

| # | Condition | Stands |
|---|---|---|
| 1 | Fair Play review (docs/TRADEMARKS.md Decision 6): a lawyer's written view | Open: the owner's, with the terms of 8.2 to read |
| 2 | The name: a trademark search (US, EU, WIPO; classes 9, 28, 42) | Knock-out search done 2026-11-03 (8.5): nothing live for BRICKWORKS in 9, 28 or 42 in the US, the EU or Madrid; a lawyer's clearance still open |
| 3 | Photo search: Brickognize's permission or paid credits, or off in paid use | Its terms allow personal, non-commercial use only, so Pro's licence leaves it out and the app says so (8.4); permission is the owner's to ask |
| 4 | An "All rights reserved" licence (repos private only if the desktop is sold) | Done 2026-11-03: `LICENSE` (8.3) |
| 5 | Signed builds for macOS and Windows | Open, and no longer a gate for Pro (8.6) |
| 6 | Claims match the product on /plans, /faq, /download | Done 2026-11-02 (plans2): only Anthropic's key in a browser, other AIs' keys on the desktop; `.io` written but not yet opened in Studio; the beta shown only while open |
| 7 | Billing and terms: live prices, seller terms that cover commercial use, consent to renewal (M7, built), cancelling from Settings, a refund policy | Terms, refunds, consent and Cancel Pro done 2026-11-03 (8.2), proven in test mode (8.1); live prices and live plans wait for the switch (8.8) |
| 8 | An audience: about 2,000 monthly active designers, and a count of who nears 25 | Not met |
| 9 | Proof of demand: 30 founding annual plans, or stay free | Not run |

Kept from the earlier design: **M1**, our own promises, changed in the
release that turns Pro on and said on the changelog; **M6**, the licences of
what ships (Godot's and BrickNet's notices, Rebrickable's credit in About,
`src/dev/about_credits_probe.gd`); **M7**, the step before Checkout
(`web/plan.js`, `supabase/plan_consents.sql`).

## 6. The Admission product

`brickworks`, tax code `txcd_10103100`, Managed Payments, the `main` account.
Plans and features are shared by test and live; prices are per mode.

- Free (default, draft) `{saved_models: 25}`; Pro (rank 10, draft)
  `{saved_models: unlimited, commercial_use: on}`.
- Test prices: Pro 800 usd a month, 8000 usd a year. **Live: no prices.**
- No trial set in either mode: the 30-day trial waits on the owner's yes
  (`set_trial` changes what customers pay).

Read it with `get_product brickworks test` (or `live`) through Admission's
MCP. `tests/fixtures/billing/fake_admission.mjs` says the same plans for
`tests/test_billing.py`.

## 7. The work

- **U1** plans from Admission: built dark (`api/_billing.js`,
  `api/_admission.js`, `supabase/admission_snapshots.sql`).
- **U3** paying for Pro: built dark (`?op=checkout`, `?op=portal`,
  `?op=webhook`, `web/plan.js`).
- **U4** the pages: /plans, /faq, /download and their German, French and
  Spanish say this design (plans2, 2026-11-02). The terms of commercial use
  are written with Pro, before live.
- **U5, U6** gated downloads and desktop activation: removed (section 4).
- **U7** the comps for accounts made before 29 October 2026, and education:
  chosen and counted (8.7), given at the switch.
- **U8** the switch to live: the owner's yes, every condition of section 5,
  live prices, plans set live: the steps are 8.8.
- Not built: the 30-day trial offered at the cap, a longer version history.

## 8. Going live (golive, 2026-11-03)

The owner, 2026-11-03: "activate real payments". This is everything up to
the switch, and the switch written as steps. Nothing here took money:
every call was in Admission's test mode, on Stripe's sandbox.

### 8.1 Test mode, end to end

Run 2026-11-03 on Admission's test mode and Stripe's sandbox ("Atypic
sandbox").

- **A purchase in a real browser** (`tools/web/billing_real_test.mjs
  --stage=buy,paid,cancel`, all ok), on a preview of 713ec7b3 deployed with
  `tools/deploy.sh --unit --billing-test` (BRICKWORKS_BILLING=test for that
  deployment alone): a new account at a Resend test address; /plans for
  sale at $8 and $80; Upgrade to Pro, the step before Checkout, Continue off
  until the box is ticked; Stripe's Checkout saying "$8.00 per month,
  Brickworks Pro, Billed monthly", "Sold through Link"; paid with 4242 by
  the script. No bot check stopped it. Back on /settings as Pro at once
  ("Plan Pro, $8.00 USD a month. Renews 3 December 2026. Included: any
  number of models kept with your account, and a licence for commercial
  use"), Manage billing and Cancel Pro offered; `?op=plan` Pro by
  subscription, commercialUse true, no limit; /plans "You have Pro: your
  plan"; **26 models saved**, every save 200, and the list names no totals.
- **Admission's record** of that account (e84a1556), test mode:
  `subscription.created` and `invoice.paid` (800 usd, 17:24:35Z), then
  `subscription.changed` at the cancel (cancelAt 2026-12-03), Pro by
  subscription until then.
- **The agreement kept** before Checkout was asked for, in
  `plan_consents` at 17:24:19Z: pro, month, 800 usd, and the terms "Pro at
  $8.00 USD a month, plus any tax; charged today, then renews automatically
  at that price until cancelled; cancel any time in Settings, under Plan,
  with Cancel Pro, or at link.com, and Pro stays on to the end of the month
  paid for; sold through Link, the merchant of record."
- **Cancelling**: Cancel Pro on /settings, then on Stripe's page Continue to
  cancellation (it asks why; no answer needed) and Cancel subscription:
  **three clicks**, asserted by the run. Back on /settings: "Plan Pro until
  3 December 2026. You will not be charged again. Then this account moves
  to Free and keeps everything in it". The pages said two clicks until this
  run; they now say "then confirm".
- **Free after Pro, nothing lost** (`--stage=free`, all ok): an account
  given Pro, 26 models saved, Pro ended: `?op=plan` Free, limit 25, kept 26;
  every model still kept and the 26th read back; one of them saved again
  over the cap (200, v2); a new one refused with the way to Pro (413).
- **The site against a stand-in Admission** (`tools/web/billing_flow.mjs
  --stand-in`, 44 checks, all ok): Checkout refused without the box (422),
  the portal 409 for an account that never paid, 401 signed out; a webhook
  unsigned or signed with another secret 400, Admission's signed 200; the
  step before Checkout at 1280 light and 390 dark, axe clean; Checkout
  closed says nothing was charged; paid, cancelled, and an account deleted
  while Pro renews ends its subscription at Admission.
- **The webhook, signed by Admission's own code**
  (`tools/web/webhook_replay.mjs`, run under Admission's tsx, its
  `signatureHeader`) into a billing-test preview: Pro given by
  `grant_override`, then removed by `end_override`; each time the held
  answer stood within its 30 s, a body signed with another secret or ten
  minutes old was refused (400) and forgot nothing, the signed event was
  heard (200), the same event again said "again", and `?op=plan` then read
  the new plan. Real delivery to brickworks.diy is proven at the switch
  (8.8 step 7): a preview is behind Vercel's protection, and its bypass is
  never put in a URL Admission keeps.
- **The plan is read on load.** `GET /api/plans?op=plan` asks Admission's
  entitlement (held for 30 s), and the page asks
  fresh (`fresh=1`) when it comes back from Checkout or the portal, which
  is why Pro showed at once with no webhook in test mode.
- **Comps, dry run**: the 42 `grant_override` calls of 8.7 made in test
  mode (kind plan, plan pro, no end), each in Admission's audit log.

### 8.2 What a paying customer has

- **Seller terms**, on /terms: Paid plans (`#paid-plans`), Paying for Pro
  (`#paying`), Refunds (`#refunds`) and Pro's licence for commercial use
  (`#commercial-use`); and on /privacy, Paying for Pro (`#paying`). Every
  sentence is true before the switch and after it: "Pro is on sale once
  those pages offer it".
- **The licence.** While an account has Pro, paid for or given, Atypic
  licenses its holder to use Brickworks in a business and to sell what they
  make with it: instructions, booklets, renders, parts lists, model files,
  kits and builds made to order. It is personal and cannot be passed on.
  What was sold under it stays sold; selling more after Pro ends needs Pro.
  It licenses Brickworks alone, never the LEGO Group's marks or designs,
  licensed theme names, other people's models or the services the app
  calls, and it says docs/TRADEMARKS.md's rules to the buyer: not
  affiliated with the LEGO Group, LEGO® only as an adjective and never in a
  product, kit or shop name, never "LEGO® compatible", no LEGO Group logo,
  box art or Minifigure in their branding, no instructions for a LEGO® set
  or a copy of one (the library's real sets included), LDraw's CC BY credit
  kept on what is sold (the booklet prints it), and photo search outside
  the licence (8.4).
- **Refunds are Atypic's, the seller's** (atypic.ai/refunds): /terms,
  /plans and /faq point to that policy and to Link's 60 days, and add no
  rule of their own. Atypic's policy refunds no unused part of a term by
  default, looks at every request (a charge twice or unexpected, a renewal
  meant to be cancelled and not used since, a payment not made by the
  holder, the app not working as described), and refunds the unused part
  when Atypic takes away a material part of a paid plan, closes an account
  that broke no term, or stops offering the app. golive first proposed a
  14-day refund of our own; the lead and atypicbw decided against it
  (2026-11-03): it would promise more than the seller's own page, and both
  pages must say the same. Link refunds anyway within 60 days, "regardless
  of any more restrictive refund policy", and honours the EU and UK 14-day
  cooling-off period, at the seller's cost
  (https://stripe.com/legal/ssa-service-terms#stripe-managed-payments §3.3).
- **Only an adult buys Pro**, as atypic.ai/terms (#account) requires: 18 or
  over, or a parent or guardian for their child. Nothing changes for
  accounts under 18; under 13 is the owner's open question (agegate).
- **Any number is any number.** Pro, a comp of Pro and the owner keep any
  number of models with no total size (`save_account_model_any`,
  `supabase/account_models_any.sql`, applied 2026-11-03); the 500 models
  and 64 MB in all stay for Free and for plans off. What holds Pro is each
  model's own size (4 MB as saved, about 30 MB of LDraw) and a guard
  against scripts: at most 1,000 models or 256 MB saved in an hour, past
  which a save is answered 429 and the app sends it again later. The terms
  say both (#paid-plans); atypic.ai's facts say "Every model kept with your
  account, with no limit on how many (each model up to 4 MB as saved)".
- **Consent to renewal (M7)**: the step before Checkout (`web/plan.js`)
  says the price, how often, that it renews until cancelled, how to cancel
  and who sells it, beside a box nobody ticks but the person;
  `?op=checkout` refuses without it and keeps the agreement first
  (`supabase/plan_consents.sql`). Shown and kept in 8.1.
- **Cancelling from Settings**: `Cancel Pro` on /settings, under Plan, opens the
  portal's own cancel step (`?op=portal` flow `cancel`). Stripe then asks
  why (Admission's portal has `cancellation_reason` on; no answer is
  needed: Continue to cancellation) and confirms (Cancel subscription):
  three clicks in all, measured in 8.1. Two would need that question off
  in Admission's portal configuration, which is Admission's to change.
  Manage billing stays for the card and invoices.
- **Receipts come from Link**, never from us: "Stripe always sends
  receipts, invoices, and any refund or credit note notifications directly
  to the customer ... These emails are sent from Link"
  (https://docs.stripe.com/payments/managed-payments/how-it-works), from an
  @link.com address (https://support.link.com/topics/sold-through-link).
  A sandbox sends none on its own ("In sandbox mode, you won't receive
  receipt emails automatically", docs.stripe.com/payments/managed-payments/set-up).
- **The words**: /plans (Pro's commercial use under its terms; the trial
  said only while Pro is coming soon, since it is not built; education by
  writing in; "How do I cancel Pro, and can I have my money back?"; an
  account with Pro is shown "You have Pro: your plan", not Upgrade), /faq
  (the same question, the licence), and /settings (Pro says what it
  includes, the licence linked to its terms; Cancel Pro), in English,
  German, French and Spanish.

### 8.3 The licence of the code

`LICENSE`: "Copyright (c) 2026 Xaxis. All rights reserved.", as
Bookwright's, with the third-party licences named (docs/ATTRIBUTION.md)
and use of the site and the published builds left to /terms.

### 8.4 Photo search (Brickognize)

Brickognize publishes one set of terms, its website's, and its API names
them as its own (`"termsOfService": "https://brickognize.com/terms-of-service/"`,
https://api.brickognize.com/openapi.json). They grant "personal,
non-commercial transitory viewing only" and forbid using "the materials
for any commercial purpose" (§2), and take a perpetual licence to what is
uploaded (§8). They say nothing of attribution or volume. Paid API credits
exist, by asking (its signed-in "API Credits" page: "Contact support to
purchase credits"), and the no-key endpoint the app uses is marked
deprecated (https://api.brickognize.com/docs).

**Decision: a paying user may use photo search as anyone may, for
personal, non-commercial use; it is never part of Pro.** Brickworks charges
nothing for it and Pro sells nothing of it, so the photo goes from the
person's own browser to Brickognize under Brickognize's terms, as on
brickognize.com. The app says so before the first photo ("it is for
personal, non-commercial use: Pro's licence for commercial use does not
cover it", `src/ui/parts_bin.gd`), and so do the terms
(`/terms#commercial-use`) and the docs (`docs-site/parts-bin.md`). Turning
it off for Pro alone would take from payers what Free keeps, and the app
does not read plans (section 3). **For the owner:** write to Piotr Rybak
(piotr.rybak@brickognize.com) for written permission for a paid app's
users, credits for a keyed endpoint, and whether he wants a credit line.
If he says no, photo search goes off everywhere, not for Pro alone.

### 8.5 The name: a knock-out search

Searched 2026-11-03 for BRICKWORKS, BRICK WORKS, BRIKWORKS, BRICKWORX and
near spellings, classes 9, 28 and 42 first. A screen, not a clearance.
Evidence (queries, raw answers, pictures) was kept in the session's
scratchpad, `golive/tm/`.

- **USPTO** (tmsearch's own index, to 2026-11-02): 31 records, 15 live. No
  live BRICKWORKS in 9, 28 or 42 for software or toys. The nearest:
  **BRICKWORK** (singular), Brickwork India, reg. 7376310 (SN 77683759),
  registered 2024-05-07, class 42 "Consultancy in the fields of
  information technology (IT) and software development". Glen-Gery's
  BRICKWORKS DESIGN STUDIO (reg. 7435871, class 42) is interior design; its
  BRICKWORKS (reg. 4802624) masonry, class 37. Glen-Gery's SN 97709741 was
  interior design too, not software design as docs/TRADEMARKS.md had it.
  Also live: BRICKWORKS for an ETF (SN 50062315, class 36) and for frozen
  pizza (class 30). Dead: BRICK WORK board games (class 28, cancelled
  2022), BRIXWORX network software (9, 42, cancelled 2023).
- **EUIPO** (eSearch plus): no EU mark or international registration for
  BRICKWORKS; "brickwork" finds only a builder (class 37). Brickworks Games
  Ltd (Cyprus, the maker of Grim Soul) holds other marks but none of the
  name. **TMview** (EU national offices and about 75 more): nothing live in
  9, 28 or 42 in an EU office.
- **WIPO Global Brand Database**: no Madrid registration for BRICKWORKS.
  National marks: the **Brickworks Ltd group** (Australia) holds class 42
  design marks in Australia (BRICKWORKS SUPERCENTRE 2090285, COLOURHUB
  2277455) and New Zealand (BRICKWORKS 1262893), and has BRICKWORKS pending
  in Australia (2584000, classes 9, 16, 41, 42; its class 9 is downloadable
  publications and media, not software). Brickworks SpA (Chile) holds a
  logo mark for software design in class 42. Near marks worth knowing:
  BRACEWORKS (Vectorworks, class 9, CAD software), BRICKWORLD (the fan
  convention, class 41).
- **Unregistered use**: the Mac App Store's Brickworks LDraw viewer
  (Matusalem Marques) is still on sale, $2.99, last updated 2017-01-11, with
  no registration anywhere; Brickworks Games sells under the name.
- Partial: TMview and WIPO's fuzzy searches were read to their top
  results only; the UK and New Zealand registers refused this machine.

Read: class 9 and 28 look clear; class 42 carries a moderate risk from
BRICKWORK (US) and the Brickworks Ltd group (Australia, New Zealand). A US
filing, if the owner wants one, should name the service narrowly (an
online 3D design tool for toy building-brick models). A lawyer's clearance,
unregistered use included, is still the owner's (condition 2).

### 8.6 What remains for the owner

- **A lawyer's view** of Fair Play and commercial use (condition 1): the
  licence of 8.2 as written on /terms, whether a paid plan and a
  commercial licence beside the LEGO® name are safe, and docs/TRADEMARKS.md
  "For counsel". No Pro sale before it.
- **The name's clearance** (condition 2), from 8.5.
- **Brickognize's answer** (condition 3), from 8.4.
- **Signed desktop builds** (condition 5): no longer a gate for Pro. Pro
  sells cloud saves and a licence, the desktop is free, and no plan touches
  it (section 4). Signing still matters for the free desktop's reach:
  unsigned, macOS Gatekeeper and Windows SmartScreen warn every new user,
  paying or not. Do it when the desktop's downloads grow, not for Pro.
- **Conditions 8 and 9**, the audience and 30 founding plans, stay the
  owner's call: they say when selling is worth it, not whether it is safe.
- **Stripe's Dashboard**, before live: the support email Link escalates to,
  the refund preference ("Stripe may refund the transaction without your
  input" after 48 hours), and the product's tax code (`txcd_10103100` now;
  Managed Payments names `txcd_10103000` and `txcd_10103001` for SaaS for
  personal and for business use: confirm which Pro is).

### 8.7 Comps

- **Accounts made before 29 October 2026: Pro, free, no end date.** One
  `grant_override` each, kind `plan`, plan `pro`, no `expires`, note
  "made before 2026-10-29: Pro free for life (docs/PLANS.md)", mode live,
  at the switch. Not a promotion (that asks for a card and renews at full
  price) and not `set_api_comps` (31 days at most). Counted 2026-11-03:
  **43 accounts** were made before then; one is the owner's (MASTER_EMAIL,
  every feature already), so **42 comps**. All 42 are the project's own:
  33 Resend test addresses, 8 brickworks.diy role addresses and one
  orangecheck account; no outside person had an account yet. They are
  given anyway, because the promise is to every account and costs nothing.
  `tools/plan_comps.py` lists their ids, and which already have a comp in a
  mode.
- **Students and teachers: Pro free, a year at a time.** A person writes
  to support@atypic.ai from a school or university address, or says where
  they study or teach; the owner gives one `grant_override`, kind `plan`,
  plan `pro`, `expires` a year on, note "education", and again on asking.
  By hand, because no check of a school address is good enough to do it
  alone, and there are few enough to read.
- **Beta testers** keep the 30 days they were promised, from
  `set_api_comps` (api/_beta.js); in live mode that needs its limit set
  (8.8 step 6).

### 8.8 The switch, as steps (not run)

Done already (golive, 2026-11-03, with the owner's leave to use
admission.sh as a tool): the live key, minted by Admission's
`scripts/key.ts brickworks live` into .env as `ADMISSION_LIVE_KEY` (label
"Brickworks (live)", key_fJ7oi43A3dHx); the live webhook URL
`https://brickworks.diy/api/plans?op=webhook`, set by its
`scripts/webhook.ts`, its secret in .env as `ADMISSION_LIVE_WEBHOOK_SECRET`,
not pinged (a refused ping retries for three days); the product's Website,
https://brickworks.diy, set before (live Checkout and the portal answer
409 `no_product_url` without it); `supabase/account_models_any.sql`
applied. Nothing in Production's env has changed. The test webhook has no
URL, and keeps none: a preview is behind Vercel's protection, and the
bypass never goes in a URL Admission keeps.

The lead runs the rest only after the owner's final yes, which covers the
prices and the 42 comps together. Steps 1, 2, 5 and 6 take money or change
what customers pay: Admission asks for the owner's yes on each.

1. **Live prices**: `set_price brickworks live pro month 800 usd` and
   `set_price brickworks live pro year 8000 usd`; `get_product brickworks
   live` then lists both active.
2. **The plans live**: `set_plan_status brickworks live free live`, then
   `pro live` (plans are shared by both modes).
3. **Production's env** on Vercel, Production scope only, each value from
   .env and never printed: `ADMISSION_KEY` = `ADMISSION_LIVE_KEY`,
   `ADMISSION_WEBHOOK_SECRET` = `ADMISSION_LIVE_WEBHOOK_SECRET` (marked
   sensitive), `BRICKWORKS_BILLING=live`, and
   `PUBLIC_ORIGIN=https://brickworks.diy` if not set; no `ADMISSION_URL`.
   Then the release that carries step 4, promoted as usual.
4. **The words of the release that turns Pro on** (M1): /faq's "Pro,
   coming soon at $8 a month or $80 a year ... Nothing takes money yet."
   made present, and the changelog saying Pro opened; /plans, /settings and
   /terms need nothing (they read Admission).
5. **The comps** (8.7): `python3 tools/plan_comps.py` (with .env sourced)
   lists the 42 ids, the ones given in test mode on 2026-11-03; for each,
   `grant_override` product `brickworks`, mode `live`, customerId the id,
   kind `plan`, plan `pro`, no expires, note "made before 2026-10-29: Pro
   free for life (docs/PLANS.md 8.7)". `plan_comps.py --mode=live` then
   says "live: 42 given, 0 left of 42".
6. **The beta's comps**: `set_api_comps brickworks live` with the beta's
   limit (100), only if the beta is open.
7. **The webhook answers**: Admission's ping, `cd ~/Projects/admission.sh/apps/admission
   && pnpm exec tsx --env-file=../../.env scripts/webhook.ts brickworks
   live --keep --ping`, says `delivered, answered 200`, and
   `webhook_deliveries brickworks live` shows it and step 5's
   customer.updated events delivered, each answered 200.
8. **A live checkout opens, without paying**: signed in on brickworks.diy
   as a throwaway Free account, /plans, Upgrade to Pro, tick the box,
   Continue to checkout: the page is `checkout.stripe.com/c/pay/cs_live_…`
   and shows $8.00 a month (or $80.00 a year) and "Sold through Link".
   Close it; /settings says "Checkout closed. You have not been charged".
   `plan_consents` has the row. Delete the throwaway.
9. **Atypic's pages** (atypicbw, `land.sh`): atypic.ai lists Brickworks Pro,
   its prices and "Every model kept with your account, with no limit on
   how many (each model up to 4 MB as saved)", and its terms carry the
   Brickworks section; its refund page is the one /terms points to.

In Stripe's Dashboard, the owner's, before step 8: "Upcoming renewal
events" at 21 days or less, and Billing's own automations left off
(Admission ends a subscription after Stripe's retries, about two weeks,
and keeps Pro while they run). Receipts, invoices and renewal reminders
are Stripe's and Link's under Managed Payments; the one email Brickworks
owes is the notice of a price change (Admission's integrating.md, "When
the owner changes a price").
