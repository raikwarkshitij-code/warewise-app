import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProductChartView extends StatelessWidget {
  final String productName;
  final Map<String, int> cityData;

  const ProductChartView({
    super.key,
    required this.productName,
    required this.cityData,
  });

  List<BarChartGroupData> _buildBarGroups() {
    return cityData.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final qty = entry.value.value.toDouble();
      
      // Determine bar color based on stock health
      Color barColor = Colors.blue.shade400;
      if (qty == 0) barColor = Colors.red.shade400;
      else if (qty < 10) barColor = Colors.orange.shade400; // Simulated threshold
      else barColor = Colors.green.shade400;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: qty,
            color: barColor,
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (cityData.isEmpty) {
      return const Center(
        child: Text('No city data available for this product.', style: TextStyle(color: Colors.grey)),
      );
    }

    double maxQty = cityData.values.fold(0, (prev, amount) => amount > prev ? amount : prev).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Node Telemetry: $productName',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxQty + 10,
              barGroups: _buildBarGroups(),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      final cities = cityData.keys.toList();
                      if (index >= cities.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(cities[index], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
      ],
    );
  }
}