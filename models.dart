import 'package:flutter/material.dart';

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

MealItem estimateIndianFood(String foodText, String category) {
  String lower = foodText.toLowerCase();
  int qty = 1;
  final match = RegExp(r'\b(\d+)\b').firstMatch(lower);
  if (match != null) qty = int.tryParse(match.group(1)!) ?? 1;

  int cal = 150, p = 5, c = 25, f = 4;
  if (lower.contains('roti') || lower.contains('chapati')) {
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
  } else if (lower.contains('curd')) {
    cal = 100 * qty; p = 4 * qty; c = 6 * qty; f = 4 * qty;
  } else if (lower.contains('tea') || lower.contains('chai')) {
    cal = 90 * qty; p = 3 * qty; c = 10 * qty; f = 3 * qty;
  } else {
    cal = 160 * qty; p = 6 * qty; c = 24 * qty; f = 5 * qty;
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

Widget metricBox(String label, String value, IconData icon, Color color) {
  return Container(
    width: 105,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(12),
    ),
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

Widget macroCol(String title, String val, Color color) {
  return Column(
    children: [
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ],
  );
}

Widget energyRow(String label, String value, Color color, {bool isBold = false}) {
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
