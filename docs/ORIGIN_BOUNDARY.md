# API and invite origins

A signed release accepts API destinations only from its build-time `API_ALLOWED_ORIGINS`. The same rule applies to injected `API_BASE_URL`, cached addresses and remote configuration. An invalid injected address stops configuration instead of falling through to another environment. API addresses are origins: HTTPS, host and optional port, with no credentials, query, fragment or path prefix. Local debug injection can use HTTP.

Production requires explicit `API_ALLOWED_ORIGINS`, `APP_CONFIG_URL` and `INVITE_LINK_ORIGIN`. The known GCP test API and both Firebase test hosting names are rejected, including alternate paths. A production remote document must contain `"environment": "prod"` and its allowed `api_base_url`. Only the existing test document may omit `environment`; a declared conflicting environment is always rejected. Invalid build configuration stops before fetching remote data. Tokens and cached origins remain scoped by environment and API origin.

`INVITE_LINK_ORIGIN` is an HTTPS origin on the default port. Android's link host and Dart's exact web origin come from the same generated defines. Only one-token invite paths are accepted; userinfo, query, fragment, extra segments and encoded path delimiters are rejected. The existing test origin remains the test default.

This change does not complete native environment separation. The existing Android application ID, iOS bundle ID, custom invite/auth schemes, Firebase app record, verified-domain files and Kakao callback registration still require separate test/production contracts and actual platform verification before production publication. iOS universal links are not enabled by this change. Do not deploy production by repointing the test hosting document or database.

Validation: Python configuration/build-helper regressions can run locally without Flutter. Dart regressions and Android compilation run in remote CI. A passing parser test does not prove OS link dispatch or Google Maps platform registration.
