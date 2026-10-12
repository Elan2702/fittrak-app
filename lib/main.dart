import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

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
  int _tab = 1;
  String _sex = 'Male';
  int _age = 26;
  int _height = 182;
  int _weight = 92;
  int _goalWeight = 80;
  String _act = 'Moderate';
  String _goal = 'Fat Loss';

  int _stepGoal = 10000;
  int _steps = 0;
  int _base = -1;
  StreamSubscription<StepCount>? _sub;

  final List<Map<String, dynamic>> _meals = [
    {'name': '2 Idli Sambar', 'cat': 'Breakfast', 'cal': 180, 'c': 32, 'p': 6, 'f': 2},
    {'name': '2 Roti Paneer', 'cat': 'Lunch', 'cal': 460, 'c': 48, 'p': 22, 'f': 18},
  ];

  @override
  void initState() {
    super.initState();
    Permission.activityRecognition.request();
    _sub = Pedometer.stepCountStream.listen((e) {
      if (_base == -1) _base = e.steps;
      setState(() => _steps = (e.steps - _base).clamp(0, 999999));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  double get _bmr => (_sex == 'Male')
      ? (10 * _weight) + (6.25 * _height) - (5 * _age) + 5
      : (10 * _weight) + (6.25 * _height) - (5 * _age) - 161;

  double get _maint {
    double m = 1.2;
    if (_act == 'Light') m = 1.375;
    if (_act == 'Moderate') m = 1.55;
    if (_act == 'Active') m = 1.725;
    return _bmr * m;
  }

  int get _deficit => (_maint - 500).round();
  int get _targetCal => (_goal == 'Fat Loss') ? _deficit : ((_goal == 'Muscle Gain') ? (_maint + 300).round() : _maint.round());

  double get _bmi => _weight / ((_height / 100) * (_height / 100));
  String get _bmiText => _bmi < 18.5 ? 'Underweight' : (_bmi < 25 ? 'Normal' : (_bmi < 30 ? 'Overweight' : 'Obese'));

  double get _burned => _steps * (_weight * 0.00057);
  int get _eaten => _meals.fold(0, (s, m) => s + (m['cal'] as int));
  int get _carbs => _meals.fold(0, (s, m) => s + (m['c'] as int));
  int get _protein => _meals.fold(0, (s, m) => s + (m['p'] as int));
  int get _fat => _meals.fold(0, (s, m) => s + (m['f'] as int));

  Map<String, dynamic> _estimateFood(String txt, String cat) {
    String l = txt.toLowerCase();
    int qty = 1;
    final match = RegExp(r'\b(\d+)\b').firstMatch(l);
    if (match != null) qty = int.tryParse(match.group(1)!) ?? 1;

    int cal = 150, p = 5, c = 25, f = 4;
    if (l.contains('roti') || l.contains('chapati')) {
      cal = 100 * qty; p = 3 * qty; c = 20 * qty; f = 1 * qty;
    } else if (l.contains('paratha')) {
      cal = 260 * qty; p = 5 * qty; c = 32 * qty; f = 12 * qty;
    } else if (l.contains('rice') || l.contains('chawal')) {
      cal = 200 * qty; p = 4 * qty; c = 44 * qty; f = 1 * qty;
    } else if (l.contains('biryani')) {
      cal = 420 * qty; p = 18 * qty; c = 50 * qty; f = 16 * qty;
    } else if (l.contains('idli')) {
      cal = 65 * qty; p = 2 * qty; c = 12 * qty; f = 1 * qty;
    } else if (l.contains('dosa')) {
      cal = 160 * qty; p = 4 * qty; c = 24 * qty; f = 6 * qty;
    } else if (l.contains('dal') || l.contains('sambar')) {
      cal = 140 * qty; p = 8 * qty; c = 20 * qty; f = 3 * qty;
    } else if (l.contains('paneer')) {
      cal = 290 * qty; p = 18 * qty; c = 8 * qty; f = 22 * qty;
    } else if (l.contains('chicken')) {
      cal = 240 * qty; p = 28 * qty; c = 2 * qty; f = 12 * qty;
    } else if (l.contains('egg')) {
      cal = 78 * qty; p = 6 * qty; c = 1 * qty; f = 5 * qty;
    } else if (l.contains('curd')) {
      cal = 100 * qty; p = 4 * qty; c = 6 * qty; f = 4 * qty;
    } else if (l.contains('tea') || l.contains('chai')) {
      cal = 90 * qty; p = 3 * qty; c = 10 * qty; f = 3 * qty;
    } else {
      cal = 160 * qty; p = 6 * qty; c = 24 * qty; f = 5 * qty;
    }
    return {'name': txt, 'cat': cat, 'cal': cal, 'c': c, 'p': p, 'f': f};
  }

  void _addMealSheet() {
    final ctrl = TextEditingController();
    String cat = 'Breakfast';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Food (AI Estimator)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                isExpanded: true,
                value: cat,
                dropdownColor: const Color(0xFF2C2C2C),
                items: ['Breakfast', 'Lunch', 'Snacks', 'Dinner'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setS(() => cat = v!),
              ),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: 'Food & Qty', hintText: 'e.g. 2 Roti and Chicken Curry'),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    setState(() => _meals.add(_estimateFood(ctrl.text.trim(), cat)));
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add Meal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickNum(String title, int cur, int min, int max, String unit, ValueChanged<int> onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => SizedBox(
        height: 280,
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(12), child: Text('$title ($unit)', style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                itemCount: max - min + 1,
                itemBuilder: (c, i) {
                  int val = min + i;
                  return ListTile(
                    title: Center(child: Text('$val $unit', style: TextStyle(color: val == cur ? const Color(0xFF00E676) : Colors.white))),
                    onTap: () { onPick(val); Navigator.pop(ctx); },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _buildActivityTab(),
          _buildNutritionTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: const Color(0xFF1E1E1E),
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_walk), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.bolt), label: 'Nutrition'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    double prog = (_steps / _stepGoal).clamp(0.0, 1.0);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Daily Activity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200, height: 200,
                  child: CircularProgressIndicator(value: prog, strokeWidth: 16, backgroundColor: Colors.white12, color: const Color(0xFF00E676)),
                ),
                Column(
                  children: [
                    Text('$_steps', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () => _pickNum('Step Goal', _stepGoal, 2000, 30000, 'steps', (v) => setState(() => _stepGoal = v)),
                      child: Text('Goal: $_stepGoal ✎', style: const TextStyle(color: Colors.grey)),
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
              _box('Burned', '${_burned.round()} kcal', Icons.local_fire_department, Colors.orangeAccent),
              _box('Distance', '${((_steps * 0.75) / 1000).toStringAsFixed(2)} km', Icons.straighten, Colors.lightBlueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTab() {
    int rem = _targetCal - _eaten;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Nutrition Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Meal'),
                onPressed: _addMealSheet,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E1E1E),
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
                          Text('$rem', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: rem >= 0 ? const Color(0xFF00E676) : Colors.redAccent)),
                          const Text('Remaining kcal', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Goal: $_targetCal kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Burned: -${_burned.round()} kcal', style: const TextStyle(color: Colors.orangeAccent)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macro('Carbs', '${_carbs}g', Colors.orangeAccent),
                      _macro('Protein', '${_protein}g', Colors.lightBlueAccent),
                      _macro('Fats', '${_fat}g', Colors.pinkAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...['Breakfast', 'Lunch', 'Snacks', 'Dinner'].map((cat) {
            final items = _meals.where((m) => m['cat'] == cat).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(cat, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                if (items.isEmpty)
                  const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('No food added.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                else
                  ...items.map((meal) => Card(
                    color: const Color(0xFF1E1E1E),
                    child: ListTile(
                      title: Text(meal['name'] as String),
                      subtitle: Text('P:${meal['p']}g  C:${meal['c']}g  F:${meal['f']}g'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${meal['cal']} kcal', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => setState(() => _meals.remove(meal))),
                        ],
                      ),
                    ),
                  )),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Profile & Target', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E1E1E),
            child: ListTile(
              title: const Text('Body Mass Index (BMI)'),
              subtitle: Text(_bmiText, style: const TextStyle(color: Color(0xFF00E676))),
              trailing: Text(_bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
            ),
          ),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Sex'),
                  trailing: DropdownButton<String>(
                    value: _sex,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _sex = v!),
                  ),
                ),
                ListTile(title: const Text('Age'), trailing: Text('$_age yrs ›'), onTap: () => _pickNum('Age', _age, 10, 100, 'yrs', (v) => setState(() => _age = v))),
                ListTile(title: const Text('Height'), trailing: Text('$_height cm ›'), onTap: () => _pickNum('Height', _height, 100, 230, 'cm', (v) => setState(() => _height = v))),
                ListTile(title: const Text('Current Weight'), trailing: Text('$_weight kg ›'), onTap: () => _pickNum('Weight', _weight, 30, 200, 'kg', (v) => setState(() => _weight = v))),
                ListTile(title: const Text('Goal Weight'), trailing: Text('$_goalWeight kg ›'), onTap: () => _pickNum('Goal Weight', _goalWeight, 30, 200, 'kg', (v) => setState(() => _goalWeight = v))),
              ],
            ),
          ),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Activity'),
                  trailing: DropdownButton<String>(
                    value: _act,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: const [
                      DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
                      DropdownMenuItem(value: 'Light', child: Text('Light')),
                      DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                    ],
                    onChanged: (v) => setState(() => _act = v!),
                  ),
                ),
                ListTile(
                  title: const Text('Goal'),
                  trailing: DropdownButton<String>(
                    value: _goal,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: const [
                      DropdownMenuItem(value: 'Fat Loss', child: Text('Fat Loss')),
                      DropdownMenuItem(value: 'Maintain', child: Text('Maintain')),
                      DropdownMenuItem(value: 'Muscle Gain', child: Text('Muscle Gain')),
                    ],
                    onChanged: (v) => setState(() => _goal = v!),
                  ),
                ),
              ],
            ),
          ),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Maintenance Calories:'), Text('${_maint.round()} kcal')]),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Calorie Deficit (-500):'), Text('$_deficit kcal', style: const TextStyle(color: Colors.orangeAccent))]),
                  const Divider(color: Colors.white12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Goal Calories:', style: TextStyle(fontWeight: FontWeight.bold)), Text('$_targetCal kcal', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676)))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(String t, String v, IconData ic, Color c) => Container(
    width: 140, padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Icon(ic, color: c, size: 22),
      const SizedBox(height: 4),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text(t, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]),
  );

  Widget _macro(String t, String v, Color c) => Column(children: [
    Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
  ]);
}
