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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF2979FF),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

class MealItem {
  final String name;
  final String category;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;

  MealItem({
    required this.name,
    required this.category,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});
  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 1;

  String _sex = 'Male';
  int _age = 26;
  int _heightCm = 182;
  int _weightKg = 92;
  int _goalWeightKg = 80;
  String _activityLevel = 'Moderate (3-5 days/wk)';
  String _fitnessGoal = 'Fat Loss (-500 kcal)';

  int _targetSteps = 10000;
  int _displaySteps = 0;
  int _baselineSteps = -1;
  StreamSubscription<StepCount>? _stepSub;

  final List<MealItem> _meals = [
    MealItem(name: "2 Idli with Sambar", category: "Breakfast", calories: 180, carbs: 32, protein: 6, fat: 2),
    MealItem(name: "2 Roti with Paneer Curry", category: "Lunch", calories: 460, carbs: 48, protein: 22, fat: 18),
  ];

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  Future<void> _initSensors() async {
    await Permission.activityRecognition.request();
    _stepSub = Pedometer.stepCountStream.listen((StepCount event) {
      if (_baselineSteps == -1) _baselineSteps = event.steps;
      int delta = event.steps - _baselineSteps;
      setState(() => _displaySteps = delta.clamp(0, 999999));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    super.dispose();
  }

  double get _bmr {
    if (_sex == 'Male') {
      return (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) + 5;
    } else {
      return (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) - 161;
    }
  }

  double get _maintenanceCalories {
    double mult = 1.2;
    if (_activityLevel.startsWith('Light')) mult = 1.375;
    if (_activityLevel.startsWith('Moderate')) mult = 1.55;
    if (_activityLevel.startsWith('Very Active')) mult = 1.725;
    return _bmr * mult;
  }

  int get _deficitCalories => (_maintenanceCalories - 500).round();
  int get _surplusCalories => (_maintenanceCalories + 300).round();

  int get _goalCalories {
    if (_fitnessGoal.startsWith('Fat Loss')) return _deficitCalories;
    if (_fitnessGoal.startsWith('Muscle Gain')) return _surplusCalories;
    return _maintenanceCalories.round();
  }

  double get _bmi {
    double hm = _heightCm / 100;
    return _weightKg / (hm * hm);
  }

  String get _bmiCategory {
    if (_bmi < 18.5) return 'Underweight';
    if (_bmi < 24.9) return 'Normal';
    if (_bmi < 29.9) return 'Overweight';
    return 'Obese';
  }

  double get _burnedCalories => _displaySteps * (_weightKg * 0.00057);
  double get _distanceKm => (_displaySteps * 0.75) / 1000;

  int get _totalCaloriesConsumed => _meals.fold(0, (s, m) => s + m.calories);
  int get _totalCarbs => _meals.fold(0, (s, m) => s + m.carbs);
  int get _totalProtein => _meals.fold(0, (s, m) => s + m.protein);
  int get _totalFat => _meals.fold(0, (s, m) => s + m.fat);

  MealItem _estimateIndianFoodMacros(String foodText, String category) {
    String lower = foodText.toLowerCase();
    int qty = 1;
    final match = RegExp(r'\b(\d+)\b').firstMatch(lower);
    if (match != null) {
      qty = int.tryParse(match.group(1)!) ?? 1;
    }

    int cal = 150, p = 5, c = 25, f = 4;

    if (lower.contains('roti') || lower.contains('chapati') || lower.contains('phulka')) {
      cal = 100 * qty; p = 3 * qty; c = 20 * qty; f = 1 * qty;
    } else if (lower.contains('paratha')) {
      cal = 260 * qty; p = 5 * qty; c = 32 * qty; f = 12 * qty;
    } else if (lower.contains('rice') || lower.contains('chawal')) {
      cal = 200 * qty; p = 4 * qty; c = 44 * qty; f = 1 * qty;
    } else if (lower.contains('biryani')) {
      cal = 420 * qty; p = 18 * qty; c = 50 * qty; f = 16 * qty;
    } else if (lower.contains('idli')) {
      cal = 65 * qty; p = 2 * qty; c = 12 * qty; f = 1 * qty;
    } else if (lower.contains('dosa')) {
      cal = 160 * qty; p = 4 * qty; c = 24 * qty; f = 6 * qty;
    } else if (lower.contains('dal') || lower.contains('sambar')) {
      cal = 140 * qty; p = 8 * qty; c = 20 * qty; f = 3 * qty;
    } else if (lower.contains('paneer')) {
      cal = 290 * qty; p = 18 * qty; c = 8 * qty; f = 22 * qty;
    } else if (lower.contains('chicken')) {
      cal = 240 * qty; p = 28 * qty; c = 2 * qty; f = 12 * qty;
    } else if (lower.contains('egg')) {
      cal = 78 * qty; p = 6 * qty; c = 1 * qty; f = 5 * qty;
    } else if (lower.contains('curd') || lower.contains('yogurt')) {
      cal = 100 * qty; p = 4 * qty; c = 6 * qty; f = 4 * qty;
    } else if (lower.contains('milk') || lower.contains('chai') || lower.contains('tea')) {
      cal = 90 * qty; p = 3 * qty; c = 10 * qty; f = 3 * qty;
    } else if (lower.contains('samosa') || lower.contains('vada')) {
      cal = 260 * qty; p = 4 * qty; c = 28 * qty; f = 15 * qty;
    } else {
      cal = (160 * qty).clamp(50, 900);
      p = (6 * qty).clamp(2, 60);
      c = (24 * qty).clamp(5, 120);
      f = (5 * qty).clamp(1, 45);
    }

    return MealItem(
      name: foodText,
      category: category,
      calories: cal,
      carbs: c,
      protein: p,
      fat: f,
    );
  }
  
  void _showAddMealSheet() {
    final foodCtrl = TextEditingController();
    String selectedCategory = 'Breakfast';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Meal (AI Estimator)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: const Color(0xFF2C2C2C),
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: ['Breakfast', 'Lunch', 'Snacks', 'Dinner'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setSheetState(() => selectedCategory = val!),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: foodCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Food Name & Quantity',
                  hintText: 'e.g. 2 Roti and Chicken Curry',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Calculate Macros & Add Meal', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (foodCtrl.text.trim().isNotEmpty) {
                      final item = _estimateIndianFoodMacros(foodCtrl.text.trim(), selectedCategory);
                      setState(() => _meals.add(item));
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNumberPickerDialog({
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Select $title ($unit)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: max - min + 1,
                itemBuilder: (context, idx) {
                  int val = min + idx;
                  bool isSelected = val == currentValue;
                  return ListTile(
                    title: Center(
                      child: Text(
                        '$val $unit',
                        style: TextStyle(
                          fontSize: isSelected ? 20 : 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF00E676) : Colors.white70,
                        ),
                      ),
                    ),
                    onTap: () {
                      onSelected(val);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _energyRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isBold ? 18 : 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildActivityScreen(),
          _buildNutritionScreen(),
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
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildActivityScreen() {
    double progress = (_displaySteps / _targetSteps).clamp(0.0, 1.0);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Daily Activity Tracking', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Chip(avatar: Icon(Icons.directions_walk, color: Colors.greenAccent, size: 18), label: Text('Active')),
            ],
          ),
          const SizedBox(height: 30),
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
                    Text('$_displaySteps', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () => _showNumberPickerDialog(
                        title: 'Step Goal',
                        currentValue: _targetSteps,
                        min: 2000,
                        max: 30000,
                        unit: 'steps',
                        onSelected: (v) => setState(() => _targetSteps = v),
                      ),
                      child: Text('Goal: $_targetSteps steps ✎', style: const TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricBox('Burned', '${_burnedCalories.round()} kcal', Icons.local_fire_department, Colors.orangeAccent),
              _metricBox('Distance', '${_distanceKm.toStringAsFixed(2)} km', Icons.straighten, Colors.lightBlueAccent),
              _metricBox('Progress', '${(progress * 100).toInt()}%', Icons.flag, const Color(0xFF00E676)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionScreen() {
    int remaining = _goalCalories - _totalCaloriesConsumed;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Macro Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Meal', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showAddMealSheet,
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
                          Text(
                            '$remaining',
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: remaining >= 0 ? const Color(0xFF00E676) : Colors.redAccent),
                          ),
                          const Text('Remaining kcal', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Goal: $_goalCalories kcal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Burned: -${_burnedCalories.round()} kcal', style: const TextStyle(color: Colors.orangeAccent)),
                          Text('Consumed: $_totalCaloriesConsumed kcal', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroColumn('Carbs', '${_totalCarbs}g', Colors.orangeAccent),
                      _macroColumn('Protein', '${_totalProtein}g', Colors.lightBlueAccent),
                      _macroColumn('Fats', '${_totalFat}g', Colors.pinkAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...['Breakfast', 'Lunch', 'Snacks', 'Dinner'].map((cat) => _buildMealCategorySection(cat)),
        ],
      ),
    );
  }

  Widget _buildMealCategorySection(String category) {
    final catMeals = _meals.where((m) => m.category == category).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        ),
        if (catMeals.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
            child: Text('No $category logged yet.', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          )
        else
          ...catMeals.map((meal) => Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('P: ${meal.protein}g | C: ${meal.carbs}g | F: ${meal.fat}g'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${meal.calories} kcal', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => setState(() => _meals.remove(meal)),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Widget _buildProfileScreen() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Profile & Metabolism', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Body Mass Index (BMI)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(_bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                    ],
                  ),
                  Chip(
                    backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                    label: Text(_bmiCategory, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                    items: ['Male', 'Female'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => _sex = v!),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                ListTile(
                  title: const Text('Age'),
                  trailing: Text('$_age yrs  ›', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                  onTap: () => _showNumberPickerDialog(title: 'Age', currentValue: _age, min: 10, max: 100, unit: 'yrs', onSelected: (v) => setState(() => _age = v)),
                ),
                const Divider(height: 1, color: Colors.white12),
                ListTile(
                  title: const Text('Height'),
                  trailing: Text('$_heightCm cm  ›', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                  onTap: () => _showNumberPickerDialog(title: 'Height', currentValue: _heightCm, min: 100, max: 230, unit: 'cm', onSelected: (v) => setState(() => _heightCm = v)),
                ),
                const Divider(height: 1, color: Colors.white12),
                ListTile(
                  title: const Text('Current Weight'),
                  trailing: Text('$_weightKg kg  ›', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                  onTap: () => _showNumberPickerDialog(title: 'Weight', currentValue: _weightKg, min: 30, max: 200, unit: 'kg', onSelected: (v) => setState(() => _weightKg = v)),
                ),
                const Divider(height: 1, color: Colors.white12),
                ListTile(
                  title: const Text('Goal Weight'),
                  trailing: Text('$_goalWeightKg kg  ›', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                  onTap: () => _showNumberPickerDialog(title: 'Goal Weight', currentValue: _goalWeightKg, min: 30, max: 200, unit: 'kg', onSelected: (v) => setState(() => _goalWeightKg = v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Activity Level', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _activityLevel,
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: [
                      'Sedentary (Little/no exercise)',
                      'Light (1-3 days/wk)',
                      'Moderate (3-5 days/wk)',
                      'Very Active (6-7 days/wk)',
                    ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => _activityLevel = v!),
                  ),
                  const SizedBox(height: 12),
                  const Text('Fitness Goal', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _fitnessGoal,
                    dropdownColor: const Color(0xFF2C2C2C),
                    items: [
                      'Fat Loss (-500 kcal)',
                      'Maintain Weight',
                      'Muscle Gain (+300 kcal)',
                    ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setState(() => _fitnessGoal = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _energyRow('Maintenance Calories', '${_maintenanceCalories.round()} kcal', Colors.grey),
                  const Divider(colo
