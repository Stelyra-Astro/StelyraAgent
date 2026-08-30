# StelyraAgent for iOS

This repository contains the public native iOS source for StelyraAgent.

Included here are the SwiftUI application, local astrology calculation
packages, Swiss Ephemeris source and data, tests, public content schemas, and
the four-language fixed UI catalog.

## Deliberately excluded content

StelyraAgent's proprietary interpretation copy, editorial translations,
prompt material, scoring and composition rules, and their generated runtime
catalogs are not part of this repository or the AGPL source-code grant. A
public build keeps local chart calculation available and reports proprietary
interpretation content as unavailable; it does not replace that content with
generic text.

The Relay service, production infrastructure, credentials, user data, build
artifacts, and the unrelated web application are also not included.

See [ios/LICENSE.md](ios/LICENSE.md) for the precise licensing boundary.

## Requirements

- macOS with Xcode supporting Swift 6 and iOS 17 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Node.js for fixed-UI localization validation

## Generate and build

```sh
xcodegen generate --spec ios/project.yml

xcodebuild \
  -project ios/StelyraAgent.xcodeproj \
  -scheme StelyraAgent \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The checked-in Xcode project is generated from `ios/project.yml`. Regenerate
it after changing project structure; do not hand-edit `project.pbxproj`.

## Offline location data

The app bundles a compact SQLite index of global GeoNames cities and their
IANA time zones. Attribution and dataset versions are recorded in
`ios/App/Resources/OfflineLocationData-LICENSES.txt` and in the database
metadata table. The large Timezone Boundary Builder source archive is only a
build-time input and is not included in the app or this repository.

`scripts/build-ios-offline-locations.py` deterministically rebuilds the index
from checksum-locked GeoNames and Timezone Boundary Builder archives. Its
fixture test is in `tests/data/test_build_ios_offline_locations.py`.

Package tests can be run independently:

```sh
swift test --package-path ios/Packages/AstroCore
swift test --package-path ios/Packages/ContentKit
```

## Runtime services

AI report delivery, commerce synchronization, and feedback use an external
Relay API. The Relay implementation and production configuration are not part
of this iOS source repository. No API keys or private credentials are included.

## License

Unless excluded in [ios/LICENSE.md](ios/LICENSE.md) or covered by a bundled
third-party notice, the iOS source is licensed under the GNU Affero General
Public License version 3. The root `LICENSE` contains the full text.

Swiss Ephemeris is distributed under its AGPL option; its upstream notices are
preserved in `ios/Packages/AstroCore/Sources/CSwissEphemeris/`.

## Support

For app support and feedback, see [SUPPORT.md](SUPPORT.md).
