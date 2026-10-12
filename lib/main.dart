import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const FitTrackApp());

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTrack Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
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
    {"name": "Paneer & Roti", "calories": 480, "protein": 24, "carbs": 42, "fat": 21},
  ];

  @override
  void initState() {
    super.initState();
    _recalculateMetabolism();
    _initSensors();
  }

  void _recalculateMetabolism() {
    double bmr = (_sex == 'Male')
        ? (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) + 5
        : (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) - 161;
    double mult = 1.2;
    if (_activityLevel.startsWith('Light')) mult = 1.375;
    if (_activityLevel.startsWith('Moderate')) mult = 1.55;
    if (_activityLevel.startsWith('Very Active')) mult = 1.725;
    double tdee = bmr * mult;
    if (_goal.startsWith('Fat Loss')) tdee -= 500;
    if (_goal.startsWith('Muscle Gain')) tdee += 300;
    setState(() => _targetCalories = tdee.round().clamp(1200, 5000));
  }

  Future<void> _initSensors() async {
    await [Permission.activityRecognition, Permission.location].request();
    _stepSubscription = Pedometer.stepCountStream.listen((StepCount event) {
      if (_baselineSteps == -1) _baselineSteps = event.steps;
      int delta = event.steps - _baselineSteps;
      if (_isTransitPaused || _currentSpeedKmh > 20.0) {
        _transitIgnoredSteps = delta - _displaySteps;
      } else {
        setState(() => _displaySteps = (delta - _transitIgnoredSteps).clamp(0, 999999));
      }
    });
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 4),
    ).listen((Position pos) {
      setState(() {
        _currentSpeedKmh = pos.speed * 3.6;
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _routePoints.add(_currentLocation);
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
  int get totalFoodCalories => _meals.fold(0, (s, m) => s + (m['calories'] as int));
  int get totalProtein => _meals.fold(0, (s, m) => s + (m['protein'] as int));
  int get totalCarbs => _meals.fold(0, (s, m) => s + (m['carbs'] as int));
  int get totalFat => _meals.fold(0, (s, m) => s + (m['fat'] as int));

  Future<void> _analyzeMealWithAi(String foodQuery, String apiKey) async {
    setState(() => _isAiAnalyzing = true);
    try {
      final res = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [{"parts": [{"text": 'Analyze meal "$foodQuery". Return ONLY JSON: {"name": "meal summary", "calories": 400, "protein": 20, "carbs": 40, "fat": 10}'}]}]
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String txt = data['candidates'][0]['content']['parts'][0]['text'].replaceAll('```json', '').replaceAll('```', '').trim();
        final p = jsonDecode(txt);
        setState(() => _meals.add({
          "name": p['name'] ?? foodQuery,
          "calories": (p['calories'] as num).toInt(),
          "protein": (p['protein'] as num).toInt(),
          "carbs": (p['carbs'] as num).toInt(),
          "fat": (p['fat'] as num).toInt(),
        }));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
  }
    void _editStepGoalDialog() {
    final c = TextEditingController(text: '$_targetSteps');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Set Daily Step Goal'),
      content: TextField(controller: c, keyboardType: TextInputType.number),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          final v = int.tryParse(c.text);
          if (v != null && v > 0) setState(() => _targetSteps = v);
          Navigator.pop(ctx);
        }, child: const Text('Save')),
      ],
    ));
  }

  void _manualAddMealDialog() {
    final n = TextEditingController(), cal = TextEditingController();
    final p = TextEditingController(), c = TextEditingController(), f = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Add Meal'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: n, decoration: const InputDecoration(labelText: 'Food Name')),
            TextField(controller: cal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories (kcal)')),
            TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)')),
            TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)')),
            TextField(controller: f, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fats (g)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          if (n.text.isNotEmpty && cal.text.isNotEmpty) {
            setState(() => _meals.add({
              "name": n.text,
              "calories": int.tryParse(cal.text) ?? 0,
              "protein": int.tryParse(p.text) ?? 0,
              "carbs": int.tryParse(c.text) ?? 0,
              "fat": int.tryParse(f.text) ?? 0,
            }));
            Navigator.pop(ctx);
          }
        }, child: const Text('Add')),
      ],
    ));
  }

  void _openAiMealDialog() {
    final f = TextEditingController(), k = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('AI Meal Breakdown'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: f, decoration: const InputDecoration(labelText: 'Describe meal (e.g. 2 eggs)')),
        TextField(controller: k, obscureText: true, decoration: const InputDecoration(labelText: 'Gemini API Key')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () {
          Navigator.pop(ctx);
          if (f.text.isNotEmpty && k.text.isNotEmpty) _analyzeMealWithAi(f.text, k.text);
        }, child: const Text('Analyze')),
      ],
    ));
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 100, padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }

  Widget _macroCol(String title, String val, Color c) => Column(children: [
    Text(title, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
    Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  ]);

  Widget _slider(String title, String dVal, double val, double min, double max, ValueChanged<double> fn) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title), Text(dVal, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
    ]),
    Slider(value: val, min: min, max: max, activeColor: const Color(0xFF00E676), onChanged: fn),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildActivityScreen(),
          _buildNutritionScreen(),
          _buildGpsScreen(),
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E1E1E),
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_walk), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Nutrition'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'GPS'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildActivityScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Activity Tracker', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Chip(label: Text(_isTransitPaused ? 'Transit Paused' : 'Active')),
            ]),
            const SizedBox(height: 25),
            Center(
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 200, height: 200,
                  child: CircularProgressIndicator(
                    value: (_displaySteps / _targetSteps).clamp(0.0, 1.0),
                    strokeWidth: 14,
                    color: const Color(0xFF00E676),
                    backgroundColor: Colors.white12,
                  ),
                ),
                Column(children: [
                  Text('$_displaySteps', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: _editStepGoalDialog,
                    child: Text('Goal: $_targetSteps ✎', style: const TextStyle(color: Colors.grey)),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _metricCard('Burned', '${_burnedStepCalories.round()} kcal', Icons.local_fire_department, Colors.orangeAccent),
              _metricCard('Distance', '${_distanceKm.toStringAsFixed(2)} km', Icons.straighten, Colors.lightBlueAccent),
              _metricCard('Speed', '${_currentSpeedKmh.toStringAsFixed(1)} km/h', Icons.speed, Colors.greenAccent),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.commute, color: Colors.amber),
                const SizedBox(width: 10),
                const Expanded(child: Text('Transit Pause (Vehicles/Bus)')),
                Switch(value: _isTransitPaused, onChanged: (v) => setState(() => _isTransitPaused = v)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionScreen() {
    int rem = _targetCalories - totalFoodCalories;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Macro Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Row(children: [
            IconButton(icon: const Icon(Icons.auto_awesome, color: Color(0xFF00E676)), onPressed: _openAiMealDialog),
            IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF00E676), size: 28), onPressed: _manualAddMealDialog),
          ]),
        ]),
        Card(
          color: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$rem', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: rem >= 0 ? const Color(0xFF00E676) : Colors.redAccent)),
                  const Text('Remaining kcal', style: TextStyle(color: Colors.grey)),
                ]),
                Text('Target: $_targetCalories\nBurned: -${_burnedStepCalories.round()}', textAlign: TextAlign.right),
              ]),
              const Divider(color: Colors.white12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _macroCol('Carbs', '${totalCarbs}g', Colors.orangeAccent),
                _macroCol('Protein', '${totalProtein}g', Colors.lightBlueAccent),
                _macroCol('Fats', '${totalFat}g', Colors.pinkAccent),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        ..._meals.asMap().entries.map((e) => Card(
          color: const Color(0xFF1E1E1E),
          child: ListTile(
            title: Text(e.value['name']),
            subtitle: Text('P:${e.value['protein']}g C:${e.value['carbs']}g F:${e.value['fat']}g'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${e.value['calories']} kcal', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => _meals.removeAt(e.key))),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildGpsScreen() {
    return FlutterMap(
      options: MapOptions(initialCenter: _currentLocation, initialZoom: 16),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.fittrack.ai'),
        PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5, color: const Color(0xFF2979FF))]),
        MarkerLayer(markers: [Marker(point: _currentLocation, child: const Icon(Icons.navigation, color: Colors.blueAccent))]),
      ],
    );
  }

  Widget _buildProfileScreen() {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Profile & Metabolism', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              DropdownButton<String>(
                isExpanded: true,
                value: _sex,
                items: ['Male', 'Female'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) { if (v != null) { setState(() => _sex = v); _recalculateMetabolism(); } },
              ),
              _slider('Age', '$_age yrs', _age.toDouble(), 15, 80, (v) { setState(() => _age = v.toInt()); _recalculateMetabolism(); }),
              _slider('Height', '${_heightCm.toInt()} cm', _heightCm, 120, 220, (v) { setState(() => _heightCm = v); _recalculateMetabolism(); }),
              _slider('Weight', '${_weightKg.toStringAsFixed(1)} kg', _weightKg, 35, 150, (v) { setState(() => _weightKg = v); _recalculateMetabolism(); }),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              DropdownButton<String>(
                isExpanded: true,
                value: _activityLevel,
                items: ['Sedentary (Little/no exercise)', 'Light (1-3 days/wk)', 'Moderate (3-5 days/wk)', 'Very Active (6-7 days/wk)']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) { if (v != null) { setState(() => _activityLevel = v); _recalculateMetabolism(); } },
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: _goal,
                items: ['Fat Loss (-500 kcal)', 'Maintain Weight', 'Muscle Gain (+300 kcal)']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) { if (v != null) { setState(() => _goal = v); _recalculateMetabolism(); } },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Daily Budget Target:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('$_targetCalories kcal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
          ]),
        ),
      ]),
    );
  }
}
