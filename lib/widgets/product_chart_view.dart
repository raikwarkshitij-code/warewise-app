import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProductChartView extends StatelessWidget {
  final List<Map<String, String>> products;
  final List<BarChartGroupData> barGroups;

  const ProductChartView({
    super.key,
    required this.products,
    required this.barGroups,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Add products to see the chart!',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    double maxQty = products
        .map((p) => double.tryParse(p['quantity'] ?? '0') ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Levels by Product',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxQty + 5,
              barGroups: barGroups,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index >= products.length) return const SizedBox();
                      String name = products[index]['name']!;
                      if (name.length > 8) name = '${name.substring(0, 7)}..';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(name, style: const TextStyle(fontSize: 11)),
                      );
                    },
                    reservedSize: 36,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Each bar = quantity of one product',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ],
    );
  }
}