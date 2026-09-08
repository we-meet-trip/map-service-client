import 'package:flutter/foundation.dart';
import 'auth_store.dart';

const servicePolicyVersion = '2026-09-07';
const servicePrivacyVersion = '2026-09-07.1';
const serviceMinimumAge = 18;

class ServiceConsentStatus {
  const ServiceConsentStatus({
    required this.termsVersion,
    required this.privacyVersion,
    required this.minimumAge,
    required this.accepted,
    required this.ageEligible,
    required this.acceptedAt,
  });
  final String termsVersion;
  final String privacyVersion;
  final int minimumAge;
  final bool accepted;
  final bool? ageEligible;
  final DateTime? acceptedAt;
  bool get supported =>
      termsVersion == servicePolicyVersion &&
      privacyVersion == servicePrivacyVersion &&
      minimumAge == serviceMinimumAge;
  bool get permitsService =>
      supported && accepted && ageEligible == true && acceptedAt != null;
  factory ServiceConsentStatus.fromJson(Map<String, dynamic> json) {
    final terms = json['terms_version'];
    final privacy = json['privacy_version'];
    final age = json['minimum_age'];
    final accepted = json['accepted'];
    final eligible = json['age_eligible'];
    final rawTime = json['accepted_at'];
    if (!json.containsKey('age_eligible') ||
        terms is! String ||
        privacy is! String ||
        age is! int ||
        accepted is! bool ||
        (eligible != null && eligible is! bool) ||
        (rawTime != null && rawTime is! String)) {
      throw const FormatException('Invalid policy response');
    }
    final time = rawTime is String ? DateTime.tryParse(rawTime) : null;
    if (accepted && time == null) {
      throw const FormatException('Missing policy acceptance receipt');
    }
    return ServiceConsentStatus(
      termsVersion: terms,
      privacyVersion: privacy,
      minimumAge: age,
      accepted: accepted,
      ageEligible: eligible as bool?,
      acceptedAt: time,
    );
  }
}

class PolicyDestination {
  const PolicyDestination(this.location, this.extra);
  final String location;
  final Object? extra;
}

/// Server receipts only, bound to the current account session and never persisted.
class ServiceConsentStore extends ChangeNotifier {
  ServiceConsentStore({
    int Function()? sessionVersion,
    bool Function()? authenticated,
    Listenable? sessionChanges,
  }) : _sessionVersion =
           sessionVersion ?? (() => AuthStore.instance.sessionVersion),
       _authenticated =
           authenticated ?? (() => AuthStore.instance.isLoggedIn.value),
       _sessionChanges = sessionChanges ?? AuthStore.instance.sessionChanges {
    _sessionChanges.addListener(_sessionChanged);
  }
  static final instance = ServiceConsentStore();
  final int Function() _sessionVersion;
  final bool Function() _authenticated;
  final Listenable _sessionChanges;
  Future<ServiceConsentStatus> Function()? loadStatus;
  Future<ServiceConsentStatus> Function(ServiceConsentStatus)? submitAcceptance;
  ServiceConsentStatus? _status;
  int? _statusSession;
  int _revision = 0;
  Future<void>? _pending;
  String? error;
  PolicyDestination? _destination;
  int? _destinationSession;

  ServiceConsentStatus? get status =>
      _authenticated() && _statusSession == _sessionVersion() ? _status : null;
  bool get canAccess => status?.permitsService == true;
  bool get loading => _pending != null;
  void rememberDestination(String location, Object? extra) {
    _destination = PolicyDestination(location, extra);
    _destinationSession = _sessionVersion();
  }

  PolicyDestination takeDestination() {
    final out = _destinationSession == _sessionVersion() ? _destination : null;
    _destination = null;
    return out ?? const PolicyDestination('/', null);
  }

  void _sessionChanged() {
    _revision++;
    _status = null;
    _statusSession = null;
    _pending = null;
    _destination = null;
    error = null;
    notifyListeners();
  }

  void invalidate({String? reason}) {
    _revision++;
    _status = null;
    _statusSession = null;
    _pending = null;
    error = reason;
    notifyListeners();
  }

  Future<void> refresh({bool force = false}) {
    if (!force && status != null) return Future.value();
    if (_pending case final active?) return active;
    return _run(() {
      final load = loadStatus;
      if (load == null) throw StateError('Policy service is not configured');
      return load();
    });
  }

  Future<void> accept({
    required bool adult,
    required bool terms,
    required bool privacy,
  }) {
    if (_pending case final active?) return active;
    final current = status;
    if (!adult ||
        !terms ||
        !privacy ||
        current == null ||
        !current.supported ||
        current.ageEligible != true) {
      return Future.error(
        StateError('Explicit eligible policy acceptance required'),
      );
    }
    return _run(() {
      final submit = submitAcceptance;
      if (submit == null) throw StateError('Policy service is not configured');
      return submit(current);
    });
  }

  Future<void> _run(Future<ServiceConsentStatus> Function() operation) {
    final version = _sessionVersion();
    final revision = _revision;
    late final Future<void> work;
    work = Future<ServiceConsentStatus>.sync(operation)
        .then((value) {
          if (version != _sessionVersion() ||
              revision != _revision ||
              !_authenticated()) {
            return;
          }
          _status = value;
          _statusSession = version;
          error = null;
        })
        .catchError((Object e) {
          if (version == _sessionVersion() && revision == _revision) {
            _status = null;
            error = '이용 조건을 확인하지 못했어요. 다시 시도해주세요.';
          }
          throw e;
        })
        .whenComplete(() {
          if (identical(_pending, work)) {
            _pending = null;
            notifyListeners();
          }
        });
    _pending = work;
    notifyListeners();
    return work;
  }

  static bool permitsWithoutConsent(String method, String path) =>
      path.startsWith('/api/v1/auth/') ||
      (path == '/api/v1/consents' && (method == 'GET' || method == 'POST')) ||
      (path == '/api/v1/users/me' &&
          const ['GET', 'PATCH', 'DELETE'].contains(method)) ||
      path.startsWith('/api/v1/moderation/');

  static bool isPolicyDenial(int status, String code) =>
      (status == 403 &&
          const [
            'AGE_RESTRICTED',
            'AGE_INFORMATION_REQUIRED',
            'SERVICE_POLICY_REQUIRED',
          ].contains(code)) ||
      (status == 409 && code == 'POLICY_VERSION_MISMATCH');

  @override
  void dispose() {
    _sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }
}

bool isAtLeast18(DateTime birthDate, {DateTime? now}) {
  final kst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  final adultYear = birthDate.year + serviceMinimumAge;
  // Match the server's LocalDate.plusYears(18): Feb 29 becomes Feb 28.
  final lastDay = DateTime.utc(adultYear, birthDate.month + 1, 0).day;
  final adultDay = birthDate.day > lastDay ? lastDay : birthDate.day;
  return DateTime.utc(
        adultYear,
        birthDate.month,
        adultDay,
      ).compareTo(DateTime.utc(kst.year, kst.month, kst.day)) <=
      0;
}
