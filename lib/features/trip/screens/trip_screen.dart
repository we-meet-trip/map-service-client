import 'package:flutter/material.dart';
import 'trip_step1_screen.dart';
import 'trip_step2_screen.dart';
import 'trip_step3_screen.dart';
import 'trip_step4_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  int _currentStep = 1;
  static const int _totalSteps = 7;

  // Step 1
  DateTime? _startDate;
  DateTime? _endDate;
  double _startHour = 9;
  double _endHour = 20;

  // Step 2
  double _minBudget = 0;
  double _maxBudget = 470000;

  // Step 3
  final Set<String> _selectedThemes = {};

  // Step 4
  String? _selectedTransport;

  void _next() {
    if (_currentStep < _totalSteps) setState(() => _currentStep++);
  }

  void _prev() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 1:
        return TripStep1Screen(
          onNext: _next,
          startDate: _startDate,
          endDate: _endDate,
          startHour: _startHour,
          endHour: _endHour,
          onDateChanged: (s, e) => setState(() {
            _startDate = s;
            _endDate = e;
          }),
          onTimeChanged: (s, e) => setState(() {
            _startHour = s;
            _endHour = e;
          }),
        );
      case 2:
        return TripStep2Screen(
          onNext: _next,
          onPrev: _prev,
          minBudget: _minBudget,
          maxBudget: _maxBudget,
          onBudgetChanged: (min, max) => setState(() {
            _minBudget = min;
            _maxBudget = max;
          }),
        );
      case 3:
        return TripStep3Screen(
          onNext: _next,
          onPrev: _prev,
          selectedThemes: _selectedThemes,
          onThemesChanged: (t) => setState(() {
            _selectedThemes
              ..clear()
              ..addAll(t);
          }),
        );
      case 4:
        return TripStep4Screen(
          onNext: _next,
          onPrev: _prev,
          selectedTransport: _selectedTransport,
          onTransportChanged: (t) => setState(() => _selectedTransport = t),
        );
      default:
        return Center(
          child: Text(
            'STEP $_currentStep — 준비 중입니다.',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        );
    }
  }
}
