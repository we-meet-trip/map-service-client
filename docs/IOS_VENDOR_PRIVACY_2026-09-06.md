# iOS Maps vendor privacy preparation

Prepared 2026-09-07. This change follows Client `d04b79d6b1b0e8814e27d8fc00405bf4bfe67ac9` and preserves the team's Flutter map implementation and its Dart dependency lock. It is a build candidate, not device or store acceptance.

## Confirmed gap and selected versions

The actual `ios-compile-only.zip` from release run `34087373416` contains GoogleMaps 8.4.0 and Google-Maps-iOS-Utils 5.0.0 in its resolved Podfile.lock. Its `GoogleMapsResources.bundle` has no `PrivacyInfo.xcprivacy`. The separate `google_maps_flutter_ios_privacy.bundle` exists; that declares the Flutter plugin's behavior and does not replace the Maps vendor declaration.

[Google's Maps release notes](https://developers.google.com/maps/documentation/ios-sdk/release-notes) identify Maps 9.0.0 as the version introducing the vendor privacy manifest, with minimum iOS 15. Maps 9.4.0 is the final 9.x release shown in those notes. [The exact Flutter plugin 2.18.6 podspec](https://raw.githubusercontent.com/flutter/packages/google_maps_flutter_ios-v2.18.6/packages/google_maps_flutter/google_maps_flutter_ios/ios/google_maps_flutter_ios.podspec) allows Maps >=8.4/<11 and Utils >=5/<7. Its comment about 8.4 supporting privacy manifests does not prove this app contains Google's vendor manifest; the actual artifact and vendor release notes determine this gap.

Two approaches were compared. Maps 9.4.0 with Utils 6.1.0 fits the existing plugin and raises the minimum iOS version from 14 to 15. Maps 10 with later Utils requires iOS 16 and changes additional Maps behavior. The smaller upgrade is pinned exactly in Podfile and all three Xcode deployment configurations now specify iOS 15. Existing iOS 14 devices will no longer be eligible for a new build. This is a minimum compatibility choice, not a claim that 9.x receives new bug fixes indefinitely; Google's [version maintenance policy](https://developers.google.com/maps/documentation/ios-sdk/versions) requires continued version review.

[Utils 6.1.0's own podspec](https://raw.githubusercontent.com/googlemaps/google-maps-ios-utils/v6.1.0/Google-Maps-iOS-Utils.podspec) requires Maps ~>9 and iOS 15. [The Utils release history](https://github.com/googlemaps/google-maps-ios-utils/releases) documents that 6.1.1 introduced Maps 10/iOS 16 as a breaking change. A broad `~>6.1` pin would silently widen the intended platform floor.

## Vendor provenance gate

`scripts/ios_vendor_privacy.py` requires exact resolved Maps 9.4.0/Utils 6.1.0 versions and byte-identical Podfile.lock/Pods Manifest.lock. It checks the original vendor file under `Pods/GoogleMaps/Maps/Resources/GoogleMapsResources`, including its SHA-256, against [Google's tagged 9.4.0 source](https://raw.githubusercontent.com/googlemaps/ios-maps-sdk/9.4.0/Maps/Resources/GoogleMapsResources/GoogleMaps.bundle/PrivacyInfo.xcprivacy). The reference was fetched over verified HTTPS on 2026-09-07:

- Original vendor file: 3,171 bytes; SHA-256 `47734417f3f8617743fdfa6efdda9df04664f8a91519ff22208df9f022598501`.
- Parsed declarations, compact JSON with sorted keys: SHA-256 `3ac68d0dcd83454f684b76aa5c9187479bc5dffb41368a4864086e278133cb44`.
- [CocoaPods Maps 9.4.0 spec](https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/a/d/d/GoogleMaps/9.4.0/GoogleMaps.podspec.json), retrieved SHA-256 `f0c70ae67aa84df59e6f5377260aef9274ed3306307224a62776f45589d38292`, confirms the vendor archive origin and resource-bundle rule.
- [CocoaPods Utils 6.1.0 spec](https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/3/5/e/Google-Maps-iOS-Utils/6.1.0/Google-Maps-iOS-Utils.podspec.json), retrieved SHA-256 `c606c9198f5a16c280f7dc9c2533f94a44ef94292eda6386c89d5875ec5b8549`.

For built apps, the gate requires a separate vendor manifest inside `GoogleMapsResources.bundle`, equal parsed declarations, and MinimumOSVersion 15.0. Binary plist conversion by Xcode is allowed, but declaration changes fail. Plugin-only bundles, absent vendor files, modified source bytes, mismatched installed locks and unrelated pod version changes fail. `mobile-artifact-manifest.py` runs this gate for device, simulator and signed iOS artifacts. No vendor declaration is copied into the app or invented in this repository.

The vendor manifest declares crash/performance/product interaction data, device identifiers and other data types with their own linkage and purposes. App Privacy answers must include the vendor behavior as well as MAP's own server behavior. An inventory PASS only proves declared vendor provenance; it does not decide the complete disclosure or submission outcome.

## Remote lock resolution and acceptance sequence

The existing tracked Podfile.lock is intentionally unchanged in this preparation commit: it is an executed resolver artifact, not text to invent locally. The normal native release remains blocked by the new Podfile/lock mismatch until the following is completed by root:

1. Manually dispatch `ios-native-lock.yml` on the integrated work branch after prior remote work finishes. Push merely registers this workflow and skips the resolver. It has read-only repository permissions, no environment secrets, no native compilation and no deployment or submission step.
2. The remote job runs Flutter 3.41.9 pub get, requires the Dart lock to remain unchanged, then runs `pod update GoogleMaps Google-Maps-iOS-Utils` only. The version comparison rejects unrelated pod version changes. It verifies the original installed Maps vendor manifest and publishes generated Podfile.lock, previous lock, diff, Podfile, source SHA, vendor declaration inventory and tool versions as a GitHub artifact.
3. Root downloads the exact artifact, verifies its GitHub digest/source run, reviews lock version/checksum/dependency changes, and commits the actual generated lock in its own branch.
4. Build signed Android and iOS compile/simulator artifacts from that final committed SHA using the existing serialized release workflow. The vendor gate must execute against those actual builds. Root independently verifies artifact identity, SDK/minimum OS, vendor/plugin inventories and byte hashes.
5. Service, native-key restrictions, signing, console and account blockers remain separate. Physical/simulator map rendering, login/revoke and final app demonstrations require those gates; this preparation does not claim they passed.

Local checks are stdlib synthetic unit tests, Python/Ruby syntax, plist/project syntax and AST graph refresh. CocoaPods resolution, Flutter builds, SDK behavior and vendor resources in a newly built app have not been executed locally.
