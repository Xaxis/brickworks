# Releasing the desktop app

The web build at brickworks.diy is deployed whenever something is worth
showing, and is not versioned. A **release** is a snapshot of the same app
for Linux, macOS and Windows, with the whole part library inside so it works
with no network. It is versioned, it lives on GitHub Releases, and the site's
download page offers it.

Everything below is `tools/release.py`; `--help` lists its commands.

## The cadence

- **A release every week that something a person would notice has landed**,
  and at least one a month while `main` is moving. Friday is a good day: the
  week's web deploys have been live and looked at by then.
- **A patch release at any time** for a desktop build that is broken: one
  that will not start, loses work, or cannot open what the last one saved.
  The fix goes to `main` first, then out as `X.Y.Z+1`.
- **Only from a commit that is on `main`, pushed, and already deployed to the
  web**, so the desktop never ships something the site has not run. The
  build refuses a commit that is not pushed.

Versions are [Semantic Versioning](https://semver.org/) on `0.y.z` until the
owner calls it 1.0: the minor number for a release with new features, the
patch number for fixes only. A file saved by one release must open in the
next; a release that cannot promise that says so at the top of its notes.

## Cutting one

On the machine with the part library (`assets/generated/`, which
`tools/doctor.sh` checks):

```sh
# 1. The version, in VERSION, project.godot and CHANGELOG.md at once.
#    [Unreleased] becomes the release's section, dated today.
tools/release.py version --set 0.2.0
#    Write the section: one plain paragraph on what the release means to a
#    person, then Added / Changed / Fixed. Then:
tools/release.py version                       # all three agree
git -c user.name=Xaxis -c user.email=william.neeley@gmail.com \
  commit -m "Release 0.2.0" VERSION project.godot CHANGELOG.md && git push

# 2. Build. 22 minutes for 0.1.0 at a load of about 60 (each export is
#    five to seven of them); it queues itself on `heavy`. Writes
#    dist/0.2.0/ and reads every package back: versions, architectures,
#    signatures, contents.
tools/release.py build

# 3. Run it, as a person would, in a clean home.
tools/release.py smoke dist/0.2.0/Brickworks-0.2.0-linux-x86_64.tar.xz --window
tools/release.py smoke dist/0.2.0/Brickworks-0.2.0-linux-x86_64.AppImage

# 4. Upload to a draft. Nobody else can see it yet. GitHub's own SHA-256 of
#    every file is compared with dist/.
tools/release.py publish --draft

# 5. Each package on its own system: Linux, macOS on Apple silicon and on
#    Intel, and Windows, each unpacked and run in a clean home. Wait for green.
gh workflow run release.yml -f tag=v0.2.0
gh run watch "$(gh run list --workflow=release.yml --limit 1 --json databaseId -q '.[0].databaseId')"

# 6. Publish the draft that was checked, then put it on the download page.
tools/release.py publish                       # writes web/releases.json
git -c user.name=Xaxis -c user.email=william.neeley@gmail.com \
  commit -m "Brickworks 0.2.0 on the download page" web/releases.json && git push
tools/deploy.sh --prod

# 7. Check it live.
node tools/web/download_check.mjs --url=https://brickworks.diy/download.html
```

`gh` here means `env -u GITHUB_TOKEN gh`: this machine's `GITHUB_TOKEN` is
stale and shadows the keyring login. `tools/release.py` drops it itself.

### What "done" means

- `tools/release.py build` ends with `built 0.2.0` and its read-back shows
  `Brickworks.app 0.2.0`, `arm64 + x86_64`, a signature on both, and
  `version 0.2.0` on both Windows executables.
- `smoke` ends `... starts, loads the part library, opens a model and takes
  bricks` for both Linux packages, and the `--window` picture
  (`shots/release-linux.png`) shows the example car.
- The release workflow is green on all five jobs.
- `publish` prints `ok` for every file: GitHub's SHA-256 matches.
- The live page's check passes for linux, macos, windows and phone, and a
  file fetched from the live button matches its checksum:

  ```sh
  curl -sLO "$(python3 -c 'import json; r=json.load(open("web/releases.json")); print(r["releases"][0]["files"][0]["url"])')"
  ```

## What a release is made of

| File | What |
|---|---|
| `Brickworks-X-linux-x86_64.AppImage` | one file, runs as it is (FUSE, or `--appimage-extract-and-run`) |
| `Brickworks-X-linux-x86_64.tar.xz` | the same, as a folder |
| `Brickworks-X-macos-universal.zip` | `Brickworks.app`, Apple silicon and Intel in one |
| `Brickworks-X-windows-x86_64.zip` | `Brickworks.exe`, `Brickworks.console.exe`, `Brickworks.pck` |
| `SHA256SUMS` | `sha256sum -c SHA256SUMS` |

Each carries `README.txt` (how to start it, the first-launch steps while it
is unsigned, where saves live), `ATTRIBUTION.md` (the LDraw and LEGO notices
`docs/ATTRIBUTION.md` requires in any distributed build) and
`THIRD-PARTY-NOTICES.txt` (Godot's licence and its components', read from
the engine by `tools/release_notices.gd`).

How it is built:

- **From the commit, not the working tree.** `git archive HEAD` into
  `build/release/stage/`, so a release is exactly a commit, and its stamp
  (`res://release.json`: version, commit, date) says which. Uncommitted
  changes are named and left out.
- **Only the meshes the catalogue names.** The cache carries geometry left
  by older builds (3,924 files, 234 MB at the first release); staging links
  in the 27,364 the catalogue uses, and stops if one is missing or the
  catalogue does not parse (a mesh build half-way through rewriting it).
- **Exported with the presets in `export_presets.cfg`**, the same ones
  `tools/export.sh` uses.
- **The macOS app is signed by rcodesign, never by Godot.** An Apple
  silicon Mac runs nothing unsigned, so without a certificate it is signed
  ad hoc. Godot signs its export too, but 4.7.2 writes its entitlements in
  a DER form that is not Apple's (a bare SET, TRUE as `01`) and lists its
  code directory twice, and macOS 12 and later check both at launch.
  rcodesign re-signs the bundle the way Apple's `codesign` does, and the
  read-back fails a package whose signature has either fault.
- **Archives are reproducible from the commit**: the commit's time inside,
  sorted, owned by nobody.

## Signing: what the owner provides

Nothing is signed by a certificate yet, so each system asks once before the
first launch, and the download page and every README say how to answer.
The pipeline is ready for both; each switches on by environment variable,
read from `.env` or the shell and never printed.

### macOS: a Developer ID, and notarisation

Without these the app is ad-hoc signed: it runs, but Gatekeeper asks for
**Open Anyway** in System Settings the first time.

1. **Join the Apple Developer Program** as an individual or organisation
   ($99 a year): https://developer.apple.com/programs/
2. **A Developer ID Application certificate.** On a Mac: Xcode > Settings >
   Accounts > Manage Certificates > + > Developer ID Application. Or at
   https://developer.apple.com/account/resources/certificates with a CSR.
   Then export it *with its private key* from Keychain Access as a `.p12`,
   with a password. Keychain Access writes the older PKCS#12 encryption,
   which is the one rcodesign reads; a `.p12` made with OpenSSL 3 is
   refused as "incorrect password" unless it was exported with `-legacy`.
3. **An App Store Connect API key, to notarise.** App Store Connect > Users
   and Access > Integrations > App Store Connect API > Team Keys > +, role
   **Developer**. Download the `.p8` (once only), and note its **Key ID** and
   the **Issuer ID** above the list.
4. In `.env`:

   ```sh
   APPLE_SIGN_P12=/path/to/developer-id.p12
   APPLE_SIGN_P12_PASSWORD=...
   APPLE_NOTARY_KEY=/path/to/AuthKey_XXXXXXXXXX.p8
   APPLE_NOTARY_KEY_ID=XXXXXXXXXX
   APPLE_NOTARY_ISSUER=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

`tools/release.py build mac` then re-signs the app with the Developer ID and
the hardened runtime, submits it to Apple, waits, and staples the ticket,
using `rcodesign` (pinned and fetched by the tool; it runs on Linux, so no
Mac is needed). The read-back says `developer-id <TEAMID>, hardened runtime`
and `notarisation ticket True`, the page drops its Open Anyway steps, and the
release workflow's `spctl --assess` on a real Mac turns from rejected to
accepted. An Apple ID with an app-specific password also notarises, but only
through Apple's own `notarytool` on a Mac; `rcodesign` needs the API key.

### Windows: a code-signing certificate

Without one, SmartScreen says "Windows protected your PC" and the person
chooses **More info** > **Run anyway**.

Certificates have lived on hardware or in a cloud HSM since June 2023, so a
`.pfx` file is no longer something a CA will issue. The two practical routes:

- **Azure Trusted Signing** (about $10 a month; identity validation for an
  individual or organisation): a Trusted Signing account and certificate
  profile in Azure, signed from Linux with
  [jsign](https://ebourg.github.io/jsign/).
- **An OV or EV certificate from a CA** on a USB token or the CA's cloud
  signing service (SSL.com eSigner, DigiCert KeyLocker, ...), signed with the
  CA's tool, `jsign` or `osslsigncode`.

Either way, the pipeline takes one command that signs one file in place,
with `{file}` where the path goes. In `.env`, for example:

```sh
# Azure Trusted Signing through jsign (az login, or a service principal, first)
WINDOWS_SIGN_COMMAND=jsign --storetype TRUSTEDSIGNING --keystore weu.codesigning.azure.net --storepass "$(az account get-access-token --resource https://codesigning.azure.net -q accessToken -o tsv)" --alias ACCOUNT/PROFILE --tsaurl http://timestamp.acs.microsoft.com --tsmode RFC3161 {file}
```

The build runs it on `Brickworks.exe` and `Brickworks.console.exe` and
fails if either still carries no signature afterwards. Even signed,
SmartScreen warns until the certificate has built reputation from
downloads; that fades on its own.

## Where the files go, and why

- **GitHub Releases, not Vercel.** A release is 1.7 GB across four
  packages (0.1.0: AppImage 383 MB, tar.xz 255 MB, macOS zip 543 MB,
  Windows zip 521 MB; each unpacks to 1.1-1.2 GB, nearly all of it the
  part library). Vercel takes about 15,000 files and a few hundred MB per
  deployment, and the site deploys in seconds because it carries none of
  it. GitHub allows 2 GiB a file and serves them from its CDN with resumable
  downloads.
- **The page reads `web/releases.json`, not GitHub's API.** The site's
  content security policy (`tools/deploy.sh`) lets a page connect only to
  itself, Anthropic, Wikimedia and the parts store; it is the defence for
  the API key the app holds, and widening it for one page widens it for
  all. A manifest from the same origin also means no third-party request on
  a visit and no rate limit (GitHub's is 60 an hour per address), and every
  link in it is pinned to its release, so the size and SHA-256 on the page
  are exactly those of the file the button fetches. The cost is one site
  deploy per release, which step 6 already is.
- **Versioned file names**, so a download says what it is in the Downloads
  folder. `https://github.com/Xaxis/brickworks/releases/latest` is the
  stable address for a person; the page is the stable address for the
  right file.

## What Reelwright does that this does too, and what it does not

Taken from Reelwright's release cycle: `VERSION` as the one version with a
tool that sets it everywhere and a check that it agrees; Keep a Changelog
with a plain paragraph on top of each release; `v<version>` tags; tar.xz and
AppImage for Linux (appimagetool and its runtime pinned by SHA-256, the
runtime passed in so nothing is fetched mid-build); `SHA256SUMS`; a smoke
test that unpacks each package into a clean home and runs it; a release
workflow that runs each package on its own system; and its wording for the
unsigned first launch.

Done differently: the packages live on GitHub Releases, where Reelwright's
repository is private and serves its own; the macOS package is a zip rather
than a DMG, because a zip is built and inspected on Linux and a DMG needs
`hdiutil`; nothing is built in CI, because the part library is not in git;
there is no installer for Windows yet (a zip, extracted); and signing is
wired in, by environment, rather than planned.

## Gotchas

- **Export templates must match the engine**: Godot 4.7.2, in
  `~/.local/share/godot/export_templates/4.7.2.stable/`.
- **A zip extracted by Python loses its executable bits.** `smoke` uses
  `unzip` or `ditto`, which keep them; a person's Finder does too.
- **Windows runs nothing from inside a zip** that needs a file beside it:
  `Brickworks.pck` has to be next to `Brickworks.exe`. The page says
  extract first.
- **A download from a browser on macOS is quarantined**; one from `gh` or
  `curl` is not. The release workflow therefore proves the signature and the
  launch, not the Gatekeeper prompt; `spctl --assess` is the closest it gets.
