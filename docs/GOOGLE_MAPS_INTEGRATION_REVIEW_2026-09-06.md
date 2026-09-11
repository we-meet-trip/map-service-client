# Google Maps integration review

Reviewed 2026-09-07; retain the release work start date in this filename.

Team source: `feat/#82-Google-map` at `64e111f553c27bced1edee1205713aad3429eb58`.
Release candidate before integration: `054416d5d7cbacb6bb39b7aa152e539051e43716`.
Remote source SHA was rechecked immediately before the integration commit.

The team branch was 10 commits ahead and 19 behind develop, with 12 content
conflicts during the actual merge. A direct merge was unsuitable: its parallel
trip screens bypassed stored KMA forecasts, route fallbacks drew straight lines,
and native key configuration conflicted with the platform-specific release
defines. iOS xcconfig references also depended on a gitignored local file.

## Decisions

| Change | Integrated result and reason |
| --- | --- |
| Full-screen Google map | A shared AppMap screen displays supplied stops by day, in their original order. Verified OSRM legs remain separate. Missing or invalid stops never create connecting lines. |
| Gestures in scrollable trip pages | AppMap exposes an opt-in gesture recognizer. It remains disabled by the existing pointer gate when overlays own input. Other maps retain their defaults. |
| Transit endpoint colors | Green origin and red destination use the shared marker adapter. |
| Duplicate generated-trip and step-5 screens | Current trip screens remain the routing targets, preserving stored forecasts, editing/saving, authentication and route provenance. |
| Android/iOS/web key changes | Existing platform-specific key contracts and SDK failure UI are retained. No key is added to source. The extra local xcconfig ignore rule is retained. |
| Full-screen entry | A button outside the embedded platform view passes original API stops, preserving source/profile/version. The route uses the existing authentication gate. |

Root code review, a separate agent review, actual merge conflict inspection,
and executable regression checks informed these decisions. The merge records
the team history while resolving conflicting behavior into the release candidate.

## Executed validation

- Entire Flutter suite: 305 tests passed locally.
- Standalone map regressions: 7 passed, covering manual order, day boundaries,
  incomplete routes, invalid intermediate coordinates, empty data and missing SDK.
- Focused analysis of changed map, router and trip files: no issues.
- `git diff --check`: passed.

These checks made no live Google Maps, routing-provider, recommendation or
Vision calls. They do not establish native signing, device installation, API key
restrictions, live tiles, GCP routing, or store readiness. CI and artifact build
results are recorded separately in the root release execution ledger.
