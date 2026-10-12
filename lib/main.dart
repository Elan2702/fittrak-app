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

  int _displaySteps = 0;
  int _baselineSteps = -1;
  int _transitIgnoredSteps = 0;
  bool _isTransitPaused = false;
  double _currentSpeedKmh = 0.0;

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<Position>? _positionSubscription;

  final List<LatLng> _routePoints = [];
  LatLng _currentLocation = const LatLng(12.9716, 77.5946);

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
        _transitIgnoredSteps = rawDelta - _displaySteps;
      } else {
        setState(() {
          _displaySteps = (rawDelta - _transitIgnoredSteps).clamp(0, 999999);
        });
      }
    }, onError: (err) {
      debugPrint("Pedometer error: $err");
    });
  }

  void _startGps() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 4,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _currentSpeedKmh = position.speed * 3.6;
        _currentLocation = LatLng(position.latitude, position.longitude);
        _routePoints.add(_currentLocation);

        if (_currentSpeedKmh > 20.0 && !_isTransitPaused) {
          _isTransitPaused = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  int get totalCalories => _meals.fold(0, (sum, m) => sum + (m['calories'] as int));
  int get totalProtein => _meals.fold(0, (sum, m) => sum + (m['protein'] as int));
  int get totalCarbs => _meals.fold(0, (sum, m) => sum + (m['carbs'] as int));
  int get totalFat => _meals.fold(0, (sum, m) => sum + (m['fat'] as int));

  Future<void> _analyzeMealWithAi(String foodQuery, String geminiApiKey) async {
    setState(() => _isAiAnalyzing = true);

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey',
      );

      final prompt = 'Analyze this meal: "$foodQuery". Return ONLY valid raw JSON: {"name": "Short summary", "calories": 450, "protein": 25, "carbs": 50, "fat": 15}';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [{"text": prompt}]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['candidates'][0]['content']['parts'][0]['text'];
        rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(rawText);

        setState(() {
          _meals.add({
            "name": parsed['name'] ?? foodQuery,
            "calories": (parsed['calories'] as num).toInt(),
            "protein": (parsed['protein'] as num).toInt(),
            "carbs": (parsed['carbs'] as num).toInt(),
            "fat": (parsed['fat'] as num).toInt(),
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Analysis failed: $e')),
      );
    } finally {
      setState(() => _isAiAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildStepsScreen(),
          _buildGpsScreen(),
          _buildNutritionScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E1E1E),
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_walk), label: 'Pedometer'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'GPS Route'),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'AI Macros'),
        ],
      ),
    );
  }

  Widget _buildStepsScreen() {
    double burnedKcal = _displaySteps * 0.04;
    double distanceKm = (_displaySteps * 0.75) / 1000;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Step Counter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Chip(
                  avatar: Icon(
                    _isTransitPaused ? Icons.directions_bus : Icons.directions_walk,
                    color: _isTransitPaused ? Colors.amber : Colors.greenAccent,
                    size: 18,
                  ),
                  label: Text(_isTransitPaused ? 'Transit Paused' : 'Pedometer Active'),
                ),
              ],
            ),
            const SizedBox(height: 35),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: (_displaySteps / 10000).clamp(0.0, 1.0),
                      strokeWidth: 16,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  Column(
                    children: [
                      Text('$_displaySteps',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                      const Text('Goal: 10,000 steps', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricCard('Distance', '${distanceKm.toStringAsFixed(2)} km', Icons.straighten),
                _metricCard('Burned', '${burnedKcal.toStringAsFixed(0)} kcal', Icons.local_fire_department),
                _metricCard('Speed', '${_currentSpeedKmh.toStringAsFixed(1)} km/h', Icons.speed),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _isTransitPaused ? Colors.amber : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(Icons.commute, color: _isTransitPaused ? Colors.amber : Colors.grey, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Transit Pause (Bike / Bus / Car)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Eliminates false steps from bumps & engine vibrations',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isTransitPaused,
                    activeColor: Colors.amber,
                    onChanged: (val) => setState(() => _isTransitPaused = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildGpsScreen() {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 16.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fittrack.ai',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  strokeWidth: 5.0,
                  color: const Color(0xFF2979FF),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 32),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("GPS Speed: ${_currentSpeedKmh.toStringAsFixed(1)} km/h",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Waypoints: ${_routePoints.length}"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionScreen() {
    int remainingKcal = _targetCalories - totalCalories;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Macro & Calorie Engine',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: Color(0xFF00E676)),
                onPressed: _openAiFoodDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$remainingKcal',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                          const Text('Remaining Calories', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Text('Budget: $_targetCalories kcal', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 28, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroColumn('Carbs', '${totalCarbs}g', Colors.orangeAccent),
                      _macroColumn('Protein', '${totalProtein}g', Colors.lightBlueAccent),
                      _macroColumn('Fats', '${totalFat}g', Colors.pinkAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Logged Meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_isAiAnalyzing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
            ),
          ..._meals.map((meal) => Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(meal['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('P: ${meal['protein']}g | C: ${meal['carbs']}g | F: ${meal['fat']}g'),
                  trailing: Text('${meal['calories']} kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                ),
              )),
        ],
      ),
    );
  }

  Widget _macroColumn(String title, String val, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _openAiFoodDialog() {
    final foodController = TextEditingController();
    final keyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('AI Meal Analyzer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: foodController,
              decoration: const InputDecoration(
                labelText: 'Describe your meal',
                hintText: 'e.g. 2 dosa with sambar and coconut chutney',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'Paste Google AI Studio key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (foodController.text.isNotEmpty && keyController.text.isNotEmpty) {
                _analyzeMealWithAi(foodController.text, keyController.text);
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }
}
