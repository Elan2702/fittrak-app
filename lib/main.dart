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
      title: 'FitTrack Pro',
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

  String _sex = 'Male';
  int _age = 25;
  double _heightCm = 175.0;
  double _weightKg = 70.0;
  String _activityLevel = 'Moderate (3-5 days/wk)';
  String _goal = 'Fat Loss (-500 kcal)';

  int _targetCalories = 2100;
  int _targetSteps = 10000;

  int _displaySteps = 0;
  int _baselineSteps = -1;
  int _transitIgnoredSteps = 0;
  bool _isTransitPaused = false;
  double _currentSpeedKmh = 0.0;

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<Position>? _positionSubscription;

  final List<LatLng> _routePoints = [];
  LatLng _currentLocation = const LatLng(12.9716, 77.5946);

  bool _isAiAnalyzing = false;
  final List<Map<String, dynamic>> _meals = [
    {"name": "Boiled Eggs (3) & Toast", "calories": 310, "protein": 21, "carbs": 26, "fat": 11},
    {"name": "Grilled Chicken & Rice", "calories": 520, "protein": 42, "carbs": 55, "fat": 12},
  ];

  @override
  void initState() {
    super.initState();
    _recalculateMetabolism();
    _initPermissionsAndSensors();
  }

  void _recalculateMetabolism() {
    double bmr;
    if (_sex == 'Male') {
      bmr = (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) + 5;
    } else {
      bmr = (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) - 161;
    }

    double multiplier = 1.2;
    if (_activityLevel.startsWith('Light')) multiplier = 1.375;
    if (_activityLevel.startsWith('Moderate')) multiplier = 1.55;
    if (_activityLevel.startsWith('Very Active')) multiplier = 1.725;

    double tdee = bmr * multiplier;
    if (_goal.startsWith('Fat Loss')) {
      tdee -= 500;
    } else if (_goal.startsWith('Muscle Gain')) {
      tdee += 300;
    }

    setState(() {
      _targetCalories = tdee.round().clamp(1200, 5000);
    });
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

  double get _burnedStepCalories => _displaySteps * (_weightKg * 0.00057);
  double get _distanceKm => (_displaySteps * 0.75) / 1000;

  int get totalFoodCalories => _meals.fold(0, (sum, m) => sum + (m['calories'] as int));
  int get totalProtein => _meals.fold(0, (sum, m) => sum + (m['protein'] as int));
  int get totalCarbs => _meals.fold(0, (sum, m) => sum + (m['carbs'] as int));
  int get totalFat => _meals.fold(0, (sum, m) => sum + (m['fat'] as int));

  Future<void> _analyzeMealWithAi(String foodQuery, String geminiApiKey) async {
    setState(() => _isAiAnalyzing = true);

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey',
      );

      final prompt = 'Analyze: "$foodQuery". Return ONLY valid JSON: {"name": "Summary", "calories": 400, "protein": 20, "carbs": 40, "fat": 10}';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
  }

  void _editStepGoalDialog() {
    final ctrl = TextEditingController(text: '$_targetSteps');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Set Daily Step Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Steps Target', suffixText: 'steps'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0) {
                setState(() => _targetSteps = val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _manualAddMealDialog() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final fCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add Meal Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Food Name')),
              TextField(controller: calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
              TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
              TextField(controller: cCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbohydrates (g)')),
              TextField(controller: fCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fats (g)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && calCtrl.text.isNotEmpty) {
                setState(() {
                  _meals.add({
                    "name": nameCtrl.text,
                    "calories": int.tryParse(calCtrl.text) ?? 0,
                    "protein": int.tryParse(pCtrl.text) ?? 0,
                    "carbs": int.tryParse(cCtrl.text) ?? 0,
                    "fat": int.tryParse(fCtrl.text) ?? 0,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Meal'),
          ),
        ],
      ),
    );
  }

  void _openAiMealDialog() {
    final foodCtrl = TextEditingController();
    final keyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('AI Meal Breakdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: foodCtrl, decoration: const InputDecoration(labelText: 'Describe meal (e.g. 2 dosa with sambar)')),
            const SizedBox(height: 8),
            TextField(controller: keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Gemini API Key')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (foodCtrl.text.isNotEmpty && keyCtrl.text.isNotEmpty) {
                _analyzeMealWithAi(foodCtrl.text, keyCtrl.text);
              }
            },
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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

  Widget _sliderTile(String title, String displayVal, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            Text(displayVal, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF00E676),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildPedometerScreen(),
          _buildNutritionScreen(),
          _buildGpsScreen(),
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E1E1E),
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_walk), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Nutrition'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'GPS'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildPedometerScreen() {
    double progress = (_displaySteps / _targetSteps).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activity Tracker', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 25),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 16,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  Column(
                    children: [
                      Text('$_displaySteps', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.bold)),
                      InkWell(
                        onTap: _editStepGoalDialog,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Goal: $_targetSteps', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricCard('Burned', '${_burnedStepCalories.toStringAsFixed(0)} kcal', Icons.local_fire_department, Colors.orangeAccent),
                _metricCard('Distance', '${_distanceKm.toStringAsFixed(2)} km', Icons.straighten, Colors.lightBlueAccent),
                _metricCard('Speed', '${_currentSpeedKmh.toStringAsFixed(1)} km/h', Icons.speed, Colors.greenAccent),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _isTransitPaused ? Colors.amber : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(Icons.commute, color: _isTransitPaused ? Colors.amber : Colors.grey, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Transit Pause Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Ignores steps while on vehicle/bike', style: TextStyle(color: Colors.grey, fontSize: 11)),
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

  Widget _buildNutritionScreen() {
    int netCalories = totalFoodCalories - _burnedStepCalories.round();
    int remaining = _targetCalories - totalFoodCalories;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Macro Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF00E676)),
                    tooltip: 'AI Scan',
                    onPressed: _openAiMealDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF00E676), size: 28),
                    tooltip: 'Add Food',
                    onPressed: _manualAddMealDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                          Text(
                            '$remaining',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: remaining >= 0 ? const Color(0xFF00E676) : Colors.redAccent,
                            ),
                          ),
                          const Text('Remaining Calories', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Target: $_targetCalories kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Burned: -${_burnedStepCalories.round()} kcal', style: const TextStyle(color: Colors.orangeAccent)),
                          Text('Net: $netCalories kcal', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const 
