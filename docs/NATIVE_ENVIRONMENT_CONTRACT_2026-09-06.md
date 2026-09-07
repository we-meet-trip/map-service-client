# Native environment and release preparation contract

Prepared 2026-09-07 for session D. The filename retains the 2026-09-06 work-start date. This is a candidate implementation contract, not a deployed configuration or store-readiness PASS.

## Ownership and baseline

- Baseline: verified Client `bd819551e8bdf5fa754e5357b45bff26bdd0949a` from `fix/client-origin-boundary-20260906`.
- Candidate branch: `fix/native-environment-split-20260907-01`; worktree `/tmp/map-client-native-env-20260907-01`.
- Delegated under the root session's native-store claim. Root coordinates remote CI and integration. This work does not modify GCP, another session's worktree, User service source, or develop/master.
- Google Maps feature code, route/weather flows, consent persistence and reporting behavior are preserved. Two policy URL call sites now use the compiled public site origin.

## App identity

| Field | test | prod |
| --- | --- | --- |
| Android applicationId / iOS bundle ID | `kr.mapservice.client.test` | `kr.mapservice.client` |
| Display name | MAP Test | MAP |
| Invite custom URL | `mapservice-test://invite/TOKEN` | `mapservice://invite/TOKEN` |
| Kakao app callback | `mapauth-test://kakao` | `mapauth://kakao` |
| API allowlist / remote config / invite / policy origin | Existing test defaults; explicit overrides allowed | All four explicit; known test hosts rejected |

Android namespace and MainActivity source remain `kr.mapservice.client`. The installed application ID determines sandbox and platform registration. iOS RunnerTests remains a development test target and is not a store application identity.

`scripts/mobile-release-config.py` generates Dart defines. Native identity fields are derived from `APP_ENV`, not customizable application IDs. It emits only the selected platform's public Maps key. It never imports a server dotenv, Kakao REST secret, location master key, or Apple private key into the app.

For iOS, also pass `--ios-xcconfig ios/Flutter/NativeEnvironment.xcconfig`. Xcode reads this ignored generated file after safe test defaults. Before the Flutter build phase, `ios/Flutter/verify_native_environment.py` rejects any mismatch between Dart and native bundle ID, app environment, URL schemes or invite host. The generator rejects non-DNS syntax that could expand Xcode variables; native invite links require a DNS hostname and default HTTPS port.

`PUBLIC_SITE_ORIGIN` is the policy/support/delete website origin. Production requires it explicitly. `AppEnvironment.policyUrl` allows only the documented legal filenames. It cannot fall back to test hosting or construct arbitrary paths. The public support email remains `mapadmin26@gmail.com`; the developer account remains `decemryu77@gmail.com`.

## Root integration requests: live changes are not performed here

### Kakao callback and Apple audience

The Client contract stays `GET /api/v1/auth/kakao?state=...`, server HTTPS provider callback, app callback with the same `state`, then `POST /api/v1/auth/kakao/callback` carrying only the authorization code. No user-controlled arbitrary callback URL is added.

The test User deployment must return `mapauth-test://kakao?state=...&code=...` or the same origin with its error result. The production deployment keeps `mapauth://kakao`. The misleadingly named `KAKAO_APP_CALLBACK_SCHEME` holds the complete callback URI: test `mapauth-test://kakao`, prod `mapauth://kakao`. Do not change the OAuth HTTPS redirect registration by substituting a custom URL. The configured `KAKAO_OAUTH_REDIRECT_URI` must remain the exact HTTPS URI registered for the relevant Kakao application and server environment.

Root verified the deployed R3 User source (`1d4f394b...`): `src/main/resources/application.yml:343`, `global/config/KakaoProperties.java:20`, `domain/auth/service/KakaoOAuthService.java:79` (`buildAppCallbackLocation`) and `controller/AuthController.java` (`GET /kakao/callback`). The service's error branch currently omits `state`, causing the Client's correct state check to ignore provider cancellation until timeout. Required User patch: preserve the validated incoming state in both success and error redirects; keep proper URI query encoding; retain the configured complete callback URI. Add isolated success/cancellation/state regression coverage. Do not weaken Client state validation.

The Client now ignores callbacks for the other environment, callback userinfo/ports/fragments, and duplicate state/code/error parameters. Existing state and session-epoch checks remain. Root must test successful login, provider cancellation, stale callback and logout against each environment after server changes. Until the test server's scheme is integrated, the candidate test app's Kakao flow cannot be accepted as working.

Apple token verification and revocation need an audience for the actual native bundle ID and the matching Apple developer team/key configuration. A test app with `.test` must not be verified against only the production audience. Root's deployed-source check identified `domain/auth/apple/AppleSettings.java:11` and `AppleProviderClient.java:67` (audience), `:108` (client-secret JWT subject), `:156` (code-exchange client ID), so each environment must use its exact registered client ID consistently across those operations. The User owner must confirm environment-specific authorized audiences, server revoke credentials and the retained provider token/revoke flow; no provider private key belongs in Client configuration. Root's read-only `native-auth-server-readiness-20260906.json` captures current runtime readiness, separately from this source contract.

### Platform key and certificate registration

Root's read-only inspection found existing native Maps key restrictions for `kr.mapservice.client`, with no `.test` registration at that observation. The new candidate `.test` app therefore needs an Android-restricted key allowing its application ID plus the certificate that actually signs the installed APK, and an iOS-restricted key allowing its exact bundle ID. The current source change does not modify cloud API-key resources. Having a nonempty key or a signed artifact does not verify map rendering.

For Android, distinguish direct-install signing, upload-key signing and Play App Signing. Use actual installed-app signing fingerprints for Maps and `assetlinks.json`; obtain the Play app-signing fingerprint from the verified app record when available. Never assume the upload fingerprint signs Play-delivered installs. Kakao Android package/key-hash and iOS bundle platform entries also require console verification for the chosen provider flow.

## Association and invite hosting preparation

After actual Android signing fingerprints and the Apple signed `application-identifier` prefix are available:

```sh
python3 scripts/mobile-link-associations.py \
  --config /private/path/validated-mobile-config.json \
  --android-cert-sha256 "$INSTALLED_APP_CERT_SHA256" \
  --apple-app-id-prefix "$SIGNED_APP_IDENTIFIER_PREFIX" \
  --output-dir /private/path/environment-hosting
```

The command generates `.well-known/assetlinks.json`, `.well-known/apple-app-site-association`, and `invite-environment.json` for exactly one native identity. It refuses absent/malformed identifiers and a pre-existing sidecar for the other environment. Synthetic fixture identifiers in tests must never be published.

The Apple application-identifier prefix is taken from the signed app/profile. Do not fabricate a Team ID or assume the prefix and Team ID are always the same. The iOS app contains `applinks:<compiled-invite-host>` and the AASA limits paths to `/invite/*`. This follows [Apple's associated-domain contract](https://developer.apple.com/documentation/xcode/supporting-associated-domains) and [Apple's application-identifier explanation](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html).

The landing page requires a matching `invite-environment.json` before enabling app launch. It validates environment, origin, package and scheme; fetches only an allowlisted HTTPS API origin; sends no credentials; and rejects redirects and malformed invite tokens. A failed preview can still open the verified app, while a missing/mismatched environment manifest fails closed. Publish the generated sidecar and association files together with the matching landing page, under the intended invite origin. Publishing only the new landing page is incomplete. `tool/build_web.sh` preserves the sidecar and association files; Firebase source declares the AASA JSON MIME type and a no-store sidecar. No hosting publication is performed by generation.

After authorized hosting integration, verify HTTPS status/content/MIME without redirects, installed Android App Links verification, iOS Universal Links and custom URLs. Source fixtures are not device association evidence.

## CI, signing and evidence

`release.yml` provides explicit `build_android`, `signed_android`, `build_ios`, `signed_ios`, and `build_ios_simulator` controls. iOS waits for the Android job to finish or be skipped. No simulator is booted by CI. Simulator output requires an arm64 runner and verifies the produced executable's arm64 slice. Runner labels follow [GitHub's current runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), and the job records actual architecture instead of inferring it from the label.

Environment-scoped configuration:

| GitHub variable/secret | Purpose |
| --- | --- |
| `API_ALLOWED_ORIGINS`, `APP_CONFIG_URL`, `INVITE_LINK_ORIGIN`, `PUBLIC_SITE_ORIGIN` | Environment-specific public URL contract |
| `GOOGLE_MAPS_ANDROID_API_KEY`, `GOOGLE_MAPS_IOS_API_KEY` secrets | Separately restricted public client keys; only current platform enters the artifact |
| Existing Android signing secrets | Direct-install APK/AAB signing; current expected signer check is preserved |
| `IOS_TEAM_ID`, `IOS_APP_ID_PREFIX`, `IOS_DISTRIBUTION_CERT_SHA1` variables | Verified developer/signing identity, not placeholders |
| `IOS_DISTRIBUTION_P12_B64`, `IOS_DISTRIBUTION_P12_PASSWORD`, `IOS_APP_STORE_PROFILE_B64` secrets | Private signing inputs scoped to the selected app environment |

`scripts/ios-signing.py` runs setup only on ephemeral GitHub macOS runners. It requires all signing inputs, validates exact profile app/team/prefix/certificate, expiration, distribution type, Apple sign-in and associated-domain capability, and installs temporary credentials with cleanup. Export options use `destination=export`. The workflow calls [Flutter IPA export](https://docs.flutter.dev/deployment/ios) and contains no Apple upload, account creation, final submission or release action. Supplying private signing material belongs in the secret store, never chat, logs or source.

`scripts/mobile-artifact-manifest.py` records exact source SHA, artifact SHA-256, app environment, iOS built bundle metadata, resolved dependency-lock hashes, actual Flutter/Xcode/SDK versions, and each built `.xcprivacy` file's relative location/hash/declarations. The workflow retains resolved `Podfile.lock` and `pubspec.lock`. Plugin privacy manifests and GoogleMaps framework manifests are separate inventory entries. No SDK minimum/version is raised based on guessed privacy behavior.

This inventory does not itself certify SDK policy compliance, Android 16KB page behavior, ELF `GNU_RELRO`, Apple token revocation, live Maps rendering or service acceptance. Root must inspect actual candidate artifacts. A 16KB alignment PASS cannot replace the separate `libapp.so` GNU_RELRO finding.

## Executed verification and remaining gates

Local verification: 28 Python/Node fixture tests passed; plist/pbxproj syntax and workflow YAML/embedded-shell syntax passed; Dart formatter parsed changed Dart files. No local Flutter test/analyze/build, Gradle, Docker, Xcode build, simulator or emulator was started. Dart regression tests and production environment tests are prepared for root-managed remote CI. Source graph update is AST-only, with no semantic paid extraction.

Remaining external gates include candidate remote CI/build results, real `.test` native key registrations, User callback integration, Apple membership/signing/profile inputs, actual app records/store declarations, actual association hosting verification, and the root's all-service acceptance gate. These are not converted into PASS by source fixtures. Root's native-store handoff is the authoritative place for executed CI/artifact/device/console/GCP evidence and current blockers.

## 2026-09-07 SDK 및 artifact 보존 보강

Apple의 2026-04-28 이후 업로드 최소 조건은 Xcode 26 및 iOS 26 SDK다. [공식 요구사항](https://developer.apple.com/news/upcoming-requirements/). 첫 CI의 Xcode 16.4 컴파일 성공은 이 조건을 충족하지 않는다. iOS job은 macOS 26 runner의 Xcode 26.6을 명시하고 실제 Xcode/iOS SDK major를 검사한다. 배포 대상 최소 iOS 버전과 빌드 SDK 버전은 별개다. 실제 bundle의 DTSDKName/DTXcode는 artifact manifest에서도 대조한다.

첫 simulator 빌드는 성공했으나 lipo 인자 순서 때문에 검증 단계가 실패했다. 입력 파일을 먼저 전달하도록 수정했다. 후속 단계 실패에도 완료된 산출물과 SDK 잠금 파일은 업로드하며, 미완 산출물이 전체 job 성공이나 서명 IPA로 집계되지 않도록 결과를 구분한다.
