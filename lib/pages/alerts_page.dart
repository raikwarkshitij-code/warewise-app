import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_detail_screen.dart';
import 'main_shell.dart'; // FIXED: Added import statement to resolve cross-tab routing triggers

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final CollectionReference collection =
        FirebaseFirestore.instance.collection('products');

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 20.0, bottom: 8.0),
            child: Text(
              'Logistics Alert Center',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: collection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                List<Map<String, dynamic>> lowStockAlerts = [];

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final String id = doc.id;
                  final String name =
                      data['name']?.toString() ?? 'Unknown Item';
                  final int dynamicMinThreshold =
                      int.tryParse(data['minStockLevel']?.toString() ?? '0') ??
                          0;

                  final cityMap = data['cityStock'] as Map? ?? {};
                  final int berlin =
                      int.tryParse(cityMap['Berlin']?.toString() ?? '0') ?? 0;
                  final int hamburg =
                      int.tryParse(cityMap['Hamburg']?.toString() ?? '0') ?? 0;
                  final int munich =
                      int.tryParse(cityMap['Munich']?.toString() ?? '0') ?? 0;

                  List<MapEntry<String, int>> nodes = [
                    MapEntry('Berlin', berlin),
                    MapEntry('Hamburg', hamburg),
                    MapEntry('Munich', munich),
                  ];

                  nodes.sort((a, b) => b.value.compareTo(a.value));
                  final surplusNode = nodes.first;

                  if (berlin <= dynamicMinThreshold) {
                    lowStockAlerts.add(_createAlertPayload(id, name, 'Berlin',
                        berlin, dynamicMinThreshold, surplusNode, data));
                  }
                  if (hamburg <= dynamicMinThreshold) {
                    lowStockAlerts.add(_createAlertPayload(id, name, 'Hamburg',
                        hamburg, dynamicMinThreshold, surplusNode, data));
                  }
                  if (munich <= dynamicMinThreshold) {
                    lowStockAlerts.add(_createAlertPayload(id, name, 'Munich',
                        munich, dynamicMinThreshold, surplusNode, data));
                  }
                }

                if (lowStockAlerts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gpp_good, size: 64, color: Colors.green),
                        SizedBox(height: 12),
                        Text(
                          'All Warehouses Secure\nNo node threshold shortages detected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: lowStockAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = lowStockAlerts[index];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side:
                            BorderSide(color: Colors.orange.shade100, width: 1),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.swap_horizontal_circle,
                                    color: Colors.orange.shade700, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Inter-City Asymmetry Detected',
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              alert['productName'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${alert['lowHubName']} center is critically low (${alert['lowHubQty']} units), but ${alert['surplusHubName']} has an operational surplus (${alert['surplusHubQty']} units).",
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                  height: 1.3),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                                // FIXED: Changed navigation closure context expression to asynchronous return listener
                                onPressed: () async {
                                  final navigationResponseTag =
                                      await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ProductDetailScreen(
                                            product: alert['productData'])),
                                  );

                                  // Intercept redirection commands from pop scopes context
                                  if (navigationResponseTag ==
                                          'route_to_logistics' &&
                                      context.mounted) {
                                    MainShell.switchToTab(context,
                                        2); // Instantly snap index frame view viewport to Tab 2 (Logistics Terminal)
                                  }
                                },
                                icon: const Icon(Icons.bar_chart, size: 16),
                                label: const Text('Review & Set Transfer',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _createAlertPayload(
      String id,
      String name,
      String lowCity,
      int lowQty,
      int limit,
      MapEntry<String, int> surplus,
      Map<String, dynamic> raw) {
    return {
      'productName': name,
      'lowHubName': lowCity,
      'lowHubQty': lowQty,
      'surplusHubName': surplus.key,
      'surplusHubQty': surplus.value,
      'productData': {
        'id': id,
        'name': name,
        'quantity': raw['quantity']?.toString() ?? '0',
        'minStockLevel': raw['minStockLevel']?.toString() ?? '0',
        'price': raw['price']?.toString() ??
            '0.0', // FIXED: Injected missing pricing parameter payload to drive calculations
        'cityStock': raw['cityStock'] ?? {},
        'category': raw['category']?.toString() ?? 'Uncategorized',
      }
    };
  }
}
