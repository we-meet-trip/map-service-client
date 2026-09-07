/// The API origin is also the token storage boundary. Paths and userinfo cannot
/// select a different API below an otherwise allowed host.
class EndpointPolicy {
  const EndpointPolicy({
    required this.environment,
    required this.allowedOrigins,
    required this.configUrl,
    required this.explicitOrigins,
    required this.explicitConfigUrl,
  });

  final String environment;
  final String allowedOrigins;
  final String configUrl;
  final bool explicitOrigins;
  final bool explicitConfigUrl;

  static const testHosts = {
    'mapapptest.duckdns.org',
    'mapcenter-b59ca.web.app',
    'mapcenter-b59ca.firebaseapp.com',
  };

  bool get valid {
    if (environment != 'test' && environment != 'prod') return false;
    if (configUrl.contains(RegExp(r'[\s\\]'))) return false;
    final config = Uri.tryParse(configUrl);
    if (config == null || !_safeHttps(config)) return false;
    final origins = allowedOrigins.split(',').map((s) => s.trim()).toList();
    if (origins.isEmpty ||
        origins.any((s) => normalize(s, requireHttps: true) == null)) {
      return false;
    }
    if (environment == 'prod') {
      if (!explicitOrigins || !explicitConfigUrl) return false;
      if (testHosts.contains(config.host.toLowerCase()) ||
          origins.any(
            (s) => testHosts.contains(Uri.parse(s).host.toLowerCase()),
          )) {
        return false;
      }
    }
    return true;
  }

  String? trusted(String? raw) {
    if (!valid) return null;
    final value = normalize(raw, requireHttps: true);
    if (value == null) return null;
    final allowed = allowedOrigins
        .split(',')
        .map((s) => normalize(s.trim(), requireHttps: true));
    return allowed.contains(value) ? value : null;
  }

  String? remote(dynamic decoded) {
    if (!valid || decoded is! Map<String, dynamic>) return null;
    final declaredEnvironment = decoded['environment'];
    // Only the existing test document may omit this field during transition.
    if ((environment == 'prod' || declaredEnvironment != null) &&
        declaredEnvironment != environment) {
      return null;
    }
    final value = decoded['api_base_url'];
    return value is String ? trusted(value) : null;
  }

  static bool _safeHttps(Uri uri) {
    try {
      return uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment &&
          uri.port > 0 &&
          uri.port <= 65535;
    } on FormatException {
      return false;
    }
  }

  static String? normalize(String? raw, {bool requireHttps = false}) {
    if (raw == null || raw.isEmpty || raw.contains(RegExp(r'[\s\\]')))
      return null;
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'http' && uri.scheme != 'https') return null;
      if (requireHttps && !_safeHttps(uri)) return null;
      if (uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          uri.port < 1 ||
          uri.port > 65535 ||
          (uri.path.isNotEmpty && uri.path != '/'))
        return null;
      return uri.origin;
    } on FormatException {
      return null;
    }
  }
}
