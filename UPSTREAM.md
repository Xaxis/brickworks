# Upstream

Code copied from the owner's other repositories, by source path, commit and
blob hash, so a fix upstream can be found and brought over.

| Here | From | Commit | Blob |
| --- | --- | --- | --- |
| api/_admission.js | Admission packages/client/src/index.ts | 76dfd2b | 3550e036dd13 |

**api/_admission.js** is Admission's client with its types taken out, and
nothing else changed: Vercel runs `api/` here as plain JavaScript modules
(tools/deploy.sh packages each route by hand, with no build step), so a
`.ts` file would not run. Made with the TypeScript in Admission's own
checkout, never edited by hand. To bring a newer client over, read
"What changed" in Admission's docs/integrating.md first, then:

```sh
A=~/Projects/admission.sh
mkdir -p /tmp/admission-client && cp $A/packages/client/src/index.ts /tmp/admission-client/
$A/node_modules/.pnpm/typescript@7.0.2/node_modules/typescript/bin/tsc \
  /tmp/admission-client/index.ts --target es2022 --module esnext \
  --outDir /tmp/admission-client/out --noCheck --skipLibCheck --declaration false
cp /tmp/admission-client/out/index.js api/_admission.js
git -C $A log -1 --format=%h -- packages/client/src/index.ts       # the commit
git -C $A rev-parse --short=12 HEAD:packages/client/src/index.ts    # the blob
```

and update the row. **One exception, until Admission's client has them:**
`comp` and `endComp` (ADR-0015, a product's own comps, for the beta's
month of Pro: api/_beta.js) were added to the copy by hand on 2026-10-29,
in the shape Admission's ADR-0015 gives them (`PUT` and `DELETE
/v1/customers/{id}/comps/{reason}`), while Admission built them. Bring the
next client over as above; it replaces both.

tests/test_billing.py runs it against a stand-in
Admission (tests/fixtures/fake_admission.mjs).
