import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import 'package:provider/provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/city_stock_chart_view.dart';
import '../services/lane_metrics.dart';
import '../services/role_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isSuccess =
      false; // Internal state flag to manage immediate onscreen feedback

  @override
  Widget build(BuildContext context) {
    final canRequestTransfer =
        context.watch<RoleService>().hasAnyRole(['manager', 'owner']);
    final productName = widget.product['name']?.toString() ?? 'Unknown Product';
    final String productId = widget.product['sku']?.toString() ?? 'unknown_id';
    final int qty =
        int.tryParse(widget.product['quantity']?.toString() ?? '0') ?? 0;
    final int minStock =
        int.tryParse(widget.product['threshold']?.toString() ?? '0') ?? 0;

    final double retailPrice =
        double.tryParse(widget.product['price']?.toString() ?? '0.0') ?? 0.0;
    final double unitCogs = retailPrice * 0.60;

    final Map<String, dynamic> cityStock =
        Map<String, dynamic>.from(widget.product['cityStock'] ?? {});

    final int berlin =
        int.tryParse(cityStock['Berlin']?.toString() ?? '0') ?? 0;
    final int hamburg =
        int.tryParse(cityStock['Hamburg']?.toString() ?? '0') ?? 0;
    final int munich =
        int.tryParse(cityStock['Munich']?.toString() ?? '0') ?? 0;

    List<MapEntry<String, int>> hubs = [
      MapEntry('Berlin', berlin),
      MapEntry('Hamburg', hamburg),
      MapEntry('Munich', munich),
    ];
    hubs.sort((a, b) => a.value.compareTo(b.value));

    String depletedHub = hubs.first.key;
    String surplusHub = hubs.last.key;

    final double procurementCost = unitCogs * 100;
    final double transferCost =
        LaneMetricsService.forRoute(surplusHub, depletedHub).costPerUnit * 100;
    final double netSavings = procurementCost - transferCost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Telemetry', style: TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(productName,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                      child: StatCard(
                          icon: Icons.inventory_2,
                          label: 'Global Stock',
                          value: '$qty',
                          flagColor: Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: StatCard(
                          icon: Icons.warning_amber,
                          label: 'Min Threshold',
                          value: '$minStock',
                          flagColor: qty <= minStock
                              ? Colors.red
                              : Colors.grey.shade700)),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Stock Distribution by City',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 12),

              SizedBox(
                height: 260,
                child: CityStockChartView(
                    productName: productName, cityData: cityStock),
              ),
              const SizedBox(height: 32),

              // DYNAMIC ONSCREEN MESSAGE COMPONENT
              if (_isSuccess)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green.shade300, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Transfer Initiated Successfully!',
                          style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSuccess
                        ? Colors.grey.shade400
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isSuccess || !canRequestTransfer)
                      ? null
                      : () async {
                          try {
                            // Dispatches data straight to Firestore tracking collection
                            db.collection('transfers').add({
                              'productId': productId,
                              'productName': productName,
                              'from': surplusHub,
                              'to': depletedHub,
                              'volume': 100,
                              'status': 'Pending',
                              'procurementCost': procurementCost,
                              'transferCost': transferCost,
                              'netSavings': netSavings,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            // Trigger localized UI state shift instantly
                            setState(() {
                              _isSuccess = true;
                            });

                            // Pause briefly so user can view the feedback banner, then snap back
                            await Future.delayed(
                                const Duration(milliseconds: 1500));
                            if (mounted) {
                              Navigator.pop(context, 'route_to_logistics');
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                  icon: Icon(_isSuccess ? Icons.done : Icons.send),
                  label: Text(
                      _isSuccess
                          ? 'Transfer Request Dispatched'
                          : (canRequestTransfer
                              ? 'Request Transfer'
                              : 'Only Managers Can Request Transfers'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
