import 'package:flutter/material.dart';
import 'dart:math';

class CityStockChartView extends StatelessWidget {
  final String productName;
  final Map<String, dynamic> cityData;

  const CityStockChartView({
    super.key,
    required this.productName,
    required this.cityData,
  });

  @override
  Widget build(BuildContext context) {
    final int berlin = int.tryParse(cityData['Berlin']?.toString() ?? '0') ?? 0;
    final int hamburg =
        int.tryParse(cityData['Hamburg']?.toString() ?? '0') ?? 0;
    final int munich = int.tryParse(cityData['Munich']?.toString() ?? '0') ?? 0;

    int maxVal = [berlin, hamburg, munich, 10]
        .reduce((curr, next) => curr > next ? curr : next);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildChartBar('Berlin', berlin, maxVal),
          _buildChartBar('Hamburg', hamburg, maxVal),
          _buildChartBar('Munich', munich, maxVal),
        ],
      ),
    );
  }

  Widget _buildChartBar(String label, int value, int maxVal) {
    double scaleFactor = value / maxVal;
    if (scaleFactor.isNaN || scaleFactor.isInfinite) scaleFactor = 0.0;

    final bool isZero = value == 0;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$value',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isZero ? Colors.grey : Colors.green.shade700),
          ),
          const SizedBox(height: 8),
          Container(
            height: max(160 * scaleFactor, 8.0),
            width: 36,
            decoration: BoxDecoration(
              color: isZero ? Colors.grey.shade300 : Colors.green.shade500,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}
