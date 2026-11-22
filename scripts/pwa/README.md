# Prayer Times PWA — private source, separate public compiled site

## Current web behavior: offline after first online preparation

New installations cache the complete compiled app, bundled schedules, themes,
fonts, and local rendering resources before the worker activates. The first
visit and every update require an internet connection. Once preparation
finishes, the installed PWA can reopen and use its bundled content offline.
Browser storage keeps user settings and imported schedules separate from the
worker's replaceable app-file cache.

Each release has a content-derived cache name. A new release is downloaded and
verified before it can replace the active release; if any required file is
missing, the previous offline version remains available. When an update is
ready, the app offers a reload button rather than interrupting unsaved work.
The previous `flutter_service_worker.js` URL remains available for installed
Flutter releases to migrate. Native Android behavior is unchanged.

`release-files.json` is a CI integrity manifest, not a browser pre-cache list.
The generated `offline-sw.js` contains the pre-cache list for the release. The
Pages workflow template validates the full release manifest. When publishing
to the existing output repository, keep its Pages workflow from
`scripts/pwa/pages.yml`; do not change credentials or approval flags.

## Current safety boundary

No repository is created, made public or published by preparing this release.
The original Flutter/Android source repository stays private. The PWA uses the
existing Flutter application and bundled content; it does not need the Replit API
server, an online prayer-times API, analytics, or notification permission.
Optional web adhan audio is limited by browser rules.

Build a release:

```sh
cd mobile/prayer_times
flutter pub get --enforce-lockfile
cd ../..
python3 scripts/pwa/build.py --base-href /SITE-REPOSITORY/ --output generated-artifacts/pwa-site
python3 -m unittest discover -s scripts/pwa -p 'test_*.py'
node --test scripts/pwa/test_worker.cjs
```

Flutter 3.32.0 and the committed dependency lockfile match Android CI. Use `/`
for an account-level `OWNER.github.io` repository, or `/REPOSITORY/` for a
project site. This base path must be final before users install the PWA.

## Browser storage

Flutter's default caching worker is not used; the release-aware worker in
`scripts/pwa/offline-sw.js` provides offline support and safe updates. The app
must be opened online once and remain open until caching completes. It requires
HTTPS (localhost is test-only). The worker replaces only app-file caches and
never clears localStorage or IndexedDB.

Local settings and selected region remain under the existing browser storage
key. A first installation has no selected region. A fresh origin/site path has
separate storage from Replit Preview. On iOS, install from Safari using Share →
Add to Home Screen, then open the installed app online and wait for cache
completion.
Home Screen storage may differ from a normal Safari tab;
clearing website data, uninstalling, or OS storage eviction can remove data.
The app recomputes its clock/countdowns on foreground. Optional web adhan audio
is available only while the page is open and does not provide a background
alarm or Android-style notification-shade schedule.

## Publication setup — only after the owner's separate approval

1. Agree the exact name of a **new, dedicated public output repository** with the
   owner. Do not change the original repository's visibility. Compiled JS,
   schedule JSON and religious content will be public; compiled JS is not
   source-code encryption and can be inspected/reverse-engineered.
2. Create the approved output repository with an initial commit containing an
   empty `.pwa-publish-target` marker. This marker prevents accidentally replacing
   an unrelated repository's contents. Only compiled PWA files, `.nojekyll` and
   this safety marker and the Pages deployment workflow belong there; no Dart sources, source maps, Android files,
   APK/AAB files, repository history, `.env` files or credentials are copied.
3. In the **private source repository**, configure Actions variable
   `PWA_PUBLIC_REPOSITORY` as `OWNER/OUTPUT-REPOSITORY`.
4. For cross-repository publishing, the source repository's default
   `GITHUB_TOKEN` is insufficient. Provision a fine-grained token limited to
   **Contents: read/write on the dedicated output repository only**, stored as
   Actions secret `PWA_PUBLISH_TOKEN` in the private source repository.
   Never paste it into source, YAML, commits, release files or logs. Account or
   organization policy may require additional approval. Revoke/rotate it if
   necessary; expiration affects future updates, not the already-published site.
5. Only after final owner approval, set private Actions variable
   `PWA_PUBLISH_APPROVED` to `true`. Until then, the publish job is skipped and
   the build artifact stays in the private repository.
6. Copy `scripts/pwa/pages.yml` to `.github/workflows/pages.yml` in the output
   repository. Configure GitHub Pages there with source **GitHub Actions** and
   enforce HTTPS. This workflow independently validates every compiled asset
   and deploys the site. The private source publish job preserves this workflow
   when replacing the compiled release in the explicitly marked repository.
7. Run `Build Prayer Times PWA`. Future matching pushes build in GitHub Actions
   without Replit. Confirm the real Pages URL and test that origin before sharing.

The built site needs no server process and stays independent of the Replit Run
button. GitHub Pages has usage limits and no promise of uninterrupted service.
Private-source Actions build minutes are subject to the owner's GitHub plan;
do not describe this entire setup as unlimited/free under every account.

For an initial publication without a cross-repository token, run the private
build workflow, download its successful compiled artifact, and transfer only
that artifact into the approved output repository. Its own Pages workflow then
deploys it. Fully automatic future private-to-public transfers still require
the separately provisioned restricted Actions secret; do not extract or reuse
Replit's GitHub connection credential for this purpose.

## Release acceptance

- Inspect compiled output and verify no secrets/source maps/private sources.
- Open online until the worker confirms all required files are cached, then
  close/reopen in airplane mode and verify bundled regions and saved settings.
- Interrupt an update during caching and verify the previous offline release
  remains usable; complete the update and verify the user can reload into it.
- Upgrade an older installation without deleting local settings/imported schedules.
- On iOS, test an installed Safari Home Screen app separately from a Safari tab.
- Web audio/notifications remain subject to browser restrictions; native Android
  notification-shade features do not automatically exist in the PWA.
