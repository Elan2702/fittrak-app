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
  
