# StelyraAgent for iOS

This directory contains the native, offline-first iPhone application.

The current implementation is the V1 offline-first vertical slice:

- Today / Charts / Ask / Profile SwiftUI navigation;
- Natal, Current Sky, Transits, and Secondary Progressions;
- Modern and Classical consumer presets, with legacy Special decoding only;
- single and double wheels, aspect matrices, and expandable insight cards;
- local-day Today events, event-time chart links, and a locally calculated
  seven-day transit calendar and comprehensive weekly view;
- English by default with Simplified Chinese selectable in Settings;
- a local people library with relationships and avatars, Apple Maps
  search/selection, reverse geocoding, automatic time zones, editable
  coordinates, and opt-in location;
- a local `AstroCore` Swift package;
- the official Swiss Ephemeris 2.10.3 C engine compiled from source;
- bundled Swiss Ephemeris data;
- chart-specific, Git-ignored proprietary source packs compiled into removable
  runtime interpretation bundles.

The current full application still requires physical-device installation,
offline regression, small-screen/accessibility checks, and release licensing
review before it can be treated as a release candidate. See
[`../docs/ios-v6-rebuild-plan.md`](../docs/ios-v6-rebuild-plan.md).

## Generate and verify

```sh
cd ios
xcodegen generate
swift test --package-path Packages/AstroCore
xcodebuild \
  -project StelyraAgent.xcodeproj \
  -scheme StelyraAgent \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The Xcode project is generated from `project.yml`; do not hand-edit
`project.pbxproj`.

Before staging or publishing any iOS work, run:

```sh
../scripts/check-private-content.sh
```

## Commerce Sandbox

`StelyraAgent Live Sandbox` runs the Debug configuration without attaching a
local StoreKit configuration, uses real App Store Connect Sandbox products,
uses development App Attest, and never falls back to the production Relay.
Set `STELYRAAGENT_SANDBOX_RELAY_BASE_URL` to the
HTTPS hostname of the staging Relay before running on a physical device; the
default `http://127.0.0.1:8080` is only for a local Relay.

The staging Relay is defined by `../infra/deploy/compose.relay-sandbox.yaml`
and `../infra/deploy/Caddyfile.sandbox`. It keeps App Attest verification on,
uses the development App Attest environment, and has a separate database and
host from production. Production continues to use the `StelyraAgent` scheme,
the Release configuration, and the production-only Relay.

Official builds compile chart-specific files under `PrivateContent/` and
`PrivateRules/` into `PrivateContent-*.json`, `PrivateCorpus-*.json`, and
`PrivateRules-*.json` runtime resources. All private sources and compiled
resources are intentionally ignored. A public
build without them keeps chart calculation available but marks interpretation
content unavailable; it never substitutes generic copy for proprietary
interpretation.

## Licensing

The iOS source uses Swiss Ephemeris under the AGPL 3.0 choice.
The pinned upstream source and its license texts are stored in
`Packages/AstroCore/Sources/CSwissEphemeris`. A closed-source distribution
requires resolving the separate Swiss Ephemeris Professional License before
release. Original interpretation copy, translations, and private editorial
rule packs are separately copyrighted content; see [`LICENSE.md`](./LICENSE.md).
