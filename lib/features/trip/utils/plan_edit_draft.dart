import 'package:flutter/foundation.dart';
import '../../../core/api/trip_api_service.dart';

/// An edit belongs to one open editor. Saving replaces the source only after the
/// server accepts it; retries retain this draft and cancellation restores it.
class PlanEditDraft {
  PlanEditDraft({required List<TripStop> stops, required this.transport})
    : _initialStops = List.unmodifiable(stops),
      _initialTransport = transport,
      stops = List.of(stops);

  final List<TripStop> _initialStops;
  final String _initialTransport;
  final List<TripStop> stops;
  String transport;

  bool get isDirty =>
      transport != _initialTransport || !listEquals(stops, _initialStops);

  void reset() {
    stops
      ..clear()
      ..addAll(_initialStops);
    transport = _initialTransport;
  }

  void moveToDay(TripStop stop, int day) {
    if (!stops.remove(stop)) return;
    final moved = TripStop(
      order: stop.order,
      day: day,
      name: stop.name,
      address: stop.address,
      time: stop.time,
      latitude: stop.latitude,
      longitude: stop.longitude,
      transportToNext: stop.transportToNext,
      placeId: stop.placeId,
      placeUrl: stop.placeUrl,
      reason: stop.reason,
      category: stop.category,
      bullets: stop.bullets,
      endTime: stop.endTime,
      stayMinutes: stop.stayMinutes,
      contentId: stop.contentId,
    );
    final followingDay = stops.indexWhere((item) => item.day > day);
    stops.insert(followingDay < 0 ? stops.length : followingDay, moved);
  }

  void reorderWithinDay(int day, int oldIndex, int newIndex) {
    final inDay = stops.where((item) => item.day == day).toList();
    if (oldIndex < 0 || oldIndex >= inDay.length) return;
    if (newIndex > oldIndex) newIndex--;
    final moved = inDay.removeAt(oldIndex);
    inDay.insert(newIndex.clamp(0, inDay.length), moved);
    var index = 0;
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].day == day) stops[i] = inDay[index++];
    }
  }
}
