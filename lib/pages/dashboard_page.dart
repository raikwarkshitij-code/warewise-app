import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/product_chart_view.dart';

// DashboardPage shows an overview of the whole inventory:
// three summary stat cards at the top and a bar chart below.
// It is shown when the user taps the Dashboard tab in MainShell.
// Like InventoryPage, it does NOT have its own Scaffold — MainShell provides it.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // _buildBarGroups() converts Firestore docs into the bar data fl_chart needs.
  // Each doc becomes one bar whose height equals the product's quantity.
  List<BarChartGroupData> _buildBarGroups(List<QueryDocumentSnapshot> docs) {
    return docs.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value.data() as Map<String, dynamic>;
      final qty = double.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: qty,
            color: Colors.blue.shade400,
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to the products collection in real time.
    // Every time a product is added, edited, or deleted the dashboard updates.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // Build the products list the same way InventoryPage does
        final products = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return <String, dynamic>{
            'id': d.id,
            'name': data['name']?.toString() ?? '',
            'quantity': data['quantity']?.toString() ?? '0',
            'minStockLevel': data['minStockLevel']?.toString() ?? '0',
          };
        }).toList();

        // Count how many products are at or below their minimum stock level
        final lowStock = products.where((p) {
          final qty = int.tryParse(p['quantity']?.toString() ?? '0') ?? 0;
          final min = int.tryParse(p['minStockLevel']?.toString() ?? '0') ?? 0;
          return qty > 0 && qty <= min;
        }).length;

        // Count how many products have zero quantity
        final outOfStock = products.where((p) {
          final qty = int.tryParse(p['quantity']?.toString() ?? '0') ?? 0;
          return qty == 0;
        }).length;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Three summary cards in a row at the top
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.inventory_2,
                      label: 'Total Products',
                      value: '${products.length}',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.warning_amber,
                      label: 'Low Stock',
                      value: '$lowStock',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.remove_shopping_cart,
                      label: 'Out of Stock',
                      value: '$outOfStock',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bar chart fills all remaining space below the cards
              Expanded(
                child: ProductChartView(
                  products: products,
                  barGroups: _buildBarGroups(docs),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// _SummaryCard shows a single statistic: an icon, a big number, and a label.
// The underscore means it is private to this file.
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

