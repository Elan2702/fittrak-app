import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTrack AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E676),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF2979FF),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  // Step Tracking State
  int _displaySteps = 0;
  int _baselineSteps = -1;
  int _transitIgnoredSteps = 0;
  bool _isTransitPaused = false;
  double _currentSpeedKmh = 0.0;

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<Position>? _positionSubscription;

  // GPS Map State
  final List<LatLng> _routePoints = [];
  LatLng _currentLocation = const LatLng(12.9716, 77.5946); // Default: Bengaluru

  // Nutrition & AI State
  final int _targetCalories = 2200;
  bool _isAiAnalyzing = false;
  final List<Map<String, dynamic>> _meals = [
    {"name": "Oatmeal with Almonds", "calories": 320, "protein": 11, "carbs": 52, "fat": 7},
    {"name": "Paneer Bhurji & 2 Rotis", "calories": 480, "protein": 24, "carbs": 42, "fat": 21},
  ];

  @override
  void initState() {
    super.initState();
    _initPermissionsAndSensors();
  }

  Future<void> _initPermissionsAndSensors() async {
    await [
      Permission.activityRecognition,
      Permission.location,
    ].request();

    _startPedometer();
    _startGps();
  }

  void _startPedometer() {
    _stepSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      if (_baselineSteps == -1) {
        _baselineSteps = event.steps;
      }

      int rawDelta = event.steps - _baselineSteps;

      if (_isTransitPaused || _currentSpeedKmh > 20.0) {
        // Accumulate steps counted during transit to discard them from actual count
        _transitIgnoredSteps = rawDelta - _displaySteps;
      } else {
        setState(() {
          _displaySteps = (
            
