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

The report's nine conditions, none optional. Where each stands on 2026-11-02:

| # | Condition | Stands |
|---|---|---|
| 1 | Fair Play review (docs/TRADEMARKS.md Decision 6): a lawyer's written view | Open |
| 2 | The name: a trademark search (US, EU, WIPO; classes 9, 28, 42) | Open |
| 3 | Photo search: Brickognize's permission or paid credits, or off in paid use | Open |
| 4 | An "All rights reserved" licence (repos private only if the desktop is sold) | Open |
| 5 | Signed builds for macOS and Windows | Open |
| 6 | Claims match the product on /plans, /faq, /download | Done 2026-11-02 (plans2): only Anthropic's key in a browser, other AIs' keys on the desktop; `.io` written but not yet opened in Studio; the beta shown only while open |
| 7 | Billing and terms: live prices, seller terms that cover commercial use, consent to renewal (M7, built), cancelling in two clicks, a refund policy | Admission plans are drafts; no live prices |
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
- **U7** the comps for accounts made before 29 October 2026: at launch, with
  the owner's yes.
- **U8** the switch to live: the owner's yes, every condition of section 5,
  live prices, plans set live.
- Not built: the 30-day trial offered at the cap, a longer version history.
