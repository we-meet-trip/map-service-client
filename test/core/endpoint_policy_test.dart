import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/core/config/endpoint_policy.dart';

const prod = EndpointPolicy(
  environment: 'prod',
  allowedOrigins: 'https://api.example.com',
  configUrl: 'https://config.example.com/prod.json',
  explicitOrigins: true,
  explicitConfigUrl: true,
);

void main() {
  test('production remote document must match the installed environment', () {
    expect(
      prod.remote({
        'environment': 'prod',
        'api_base_url': 'https://api.example.com/',
      }),
      'https://api.example.com',
    );
    for (final environment in [null, 'test', true, 'unknown']) {
      expect(
        prod.remote({
          'environment': environment,
          'api_base_url': 'https://api.example.com',
        }),
        isNull,
      );
    }
  });

  test(
    'all release sources obey the same exact canonical origin allowlist',
    () {
      expect(
        prod.trusted('https://API.EXAMPLE.COM:443/'),
        'https://api.example.com',
      );
      for (final url in [
        'http://api.example.com',
        'https://api.example.com:8443',
        'https://api.example.com/other',
        'https://api.example.com//',
        'https://api.example.com.evil.invalid',
        'https://api.example.com@evil.invalid',
        'https://api.example.com?token=x',
        'https://api.example.com#fragment',
        'https://api.example.com\\@evil.invalid',
        ' https://api.example.com',
        'https://api.example.com\n',
        'https://api.example.com:65536',
      ]) {
        expect(prod.trusted(url), isNull, reason: url);
        expect(
          prod.remote({'environment': 'prod', 'api_base_url': url}),
          isNull,
          reason: url,
        );
      }
    },
  );

  test(
    'production cannot silently use a test default or its hosting alias',
    () {
      for (final config in [
        'https://mapcenter-b59ca.web.app/other.json',
        'https://mapcenter-b59ca.firebaseapp.com/prod.json',
      ]) {
        expect(
          EndpointPolicy(
            environment: 'prod',
            allowedOrigins: prod.allowedOrigins,
            configUrl: config,
            explicitOrigins: true,
            explicitConfigUrl: true,
          ).valid,
          isFalse,
        );
      }
      expect(
        const EndpointPolicy(
          environment: 'prod',
          allowedOrigins: 'https://api.example.com',
          configUrl: 'https://config.example.com/prod.json',
          explicitOrigins: false,
          explicitConfigUrl: true,
        ).valid,
        isFalse,
      );
      expect(
        const EndpointPolicy(
          environment: 'prod',
          allowedOrigins: 'https://mapapptest.duckdns.org',
          configUrl: 'https://config.example.com/prod.json',
          explicitOrigins: true,
          explicitConfigUrl: true,
        ).valid,
        isFalse,
      );
    },
  );

  test('legacy test document is accepted only by the explicit test policy', () {
    const test = EndpointPolicy(
      environment: 'test',
      allowedOrigins: 'https://mapapptest.duckdns.org',
      configUrl: 'https://mapcenter-b59ca.web.app/app_config.json',
      explicitOrigins: false,
      explicitConfigUrl: false,
    );
    expect(
      test.remote({'api_base_url': 'https://mapapptest.duckdns.org'}),
      'https://mapapptest.duckdns.org',
    );
    expect(
      test.remote({
        'environment': 'prod',
        'api_base_url': 'https://mapapptest.duckdns.org',
      }),
      isNull,
    );
  });

  test(
    'malformed configuration is rejected without throwing or making a request',
    () {
      for (final config in [
        'https://config.example.com:bad',
        'https://config.example.com:65536',
        'http://config.example.com',
        'https://user@config.example.com',
        'https://config.example.com?secret=1',
      ]) {
        final policy = EndpointPolicy(
          environment: 'prod',
          allowedOrigins: prod.allowedOrigins,
          configUrl: config,
          explicitOrigins: true,
          explicitConfigUrl: true,
        );
        expect(policy.valid, isFalse);
        expect(policy.trusted('https://api.example.com'), isNull);
      }
    },
  );
}
