import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  bool _isProcessing = false;

  // --- SHOW EDITABLE DECISION DIALOG ---
  void _showTransferDialog({
    required String docId,
    required String productTitle,
    required String sourceCity,
    required String destinationCity,
    required int sourceAvailableStock,
    required int destCurrentStock,
  }) {
    final TextEditingController quantityController = TextEditingController(text: "250");
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.blueAccent, size: 28),
              const SizedBox(width: 8),
              const Text("Configure Transfer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  
                  // Logistics Route Overview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("FROM: $sourceCity", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text("Stock: $sourceAvailableStock units", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        const Icon(Icons.trending_flat, color: Colors.grey),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("TO: $destinationCity", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text("Stock: $destCurrentStock units", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Editable Quantity Field
                  const Text("Target Transfer Quantity", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Locks input to positive integers only
                    decoration: InputDecoration(
                      hintText: "Enter volume to ship",
                      prefixIcon: const Icon(Icons.unarchive_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Quantity is required";
                      }
                      final int? enteredQty = int.tryParse(value);
                      if (enteredQty == null || enteredQty <= 0) {
                        return "Must be greater than 0";
                      }
                      if (enteredQty > sourceAvailableStock) {
                        return "Exceeds source stock ($sourceAvailableStock)";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final int finalSelectedQty = int.parse(quantityController.text);
                  Navigator.pop(context); // Close the popup configuration prompt
                  
                  // Forward the tailored custom data parameters to your database generator pipeline
                  _createStockTransportOrder(
                    docId: docId,
                    productTitle: productTitle,
                    sourceCity: sourceCity,
                    destinationCity: destinationCity,
                    transferAmount: finalSelectedQty,
                  );
                }
              },
              child: const Text("Create Order"),
            ),
          ],
        );
      },
    );
  }

  // --- MWIS LOGISTICS ENGINE: INITIALIZE RECORD DOCUMENT ---
  Future<void> _createStockTransportOrder({
    required String docId,
    required String productTitle,
    required String sourceCity,
    required String destinationCity,
    required int transferAmount,
  }) async {
    setState(() => _isProcessing = true);

    final String generatedOrderNumber = "ORD-${Random().nextInt(900000) + 100000}";

    try {
      await FirebaseFirestore.instance.collection('transfers').add({
        'orderNumber': generatedOrderNumber,
        'productId': docId,
        'productName': productTitle,
        'sourceCity': sourceCity,
        'destinationCity': destinationCity,
        'quantity': transferAmount,
        'status': 'Pending Approval',
        'initiatedBy': 'Warehouse Associate Terminal',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated $generatedOrderNumber for $transferAmount units! Sent to manager queue.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      print("Failed to issue system tracing document: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistics Alert Center', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                List<Map<String, dynamic>> structuralAlerts = [];

                // --- SCANNING ALL REAL-TIME INVENTORY VOLUMES ---
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String docId = doc.id;
                  final String name = data['name'] ?? 'Unknown';
                  final int minLevel = int.tryParse(data['minStockLevel']?.toString() ?? '0') ?? 0;

                  Map<String, int> cityStock = {};
                  if (data.containsKey('cityStock')) {
                    final map = data['cityStock'] as Map<String, dynamic>;
                    cityStock = map.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 0));
                  }

                  final int totalStock = cityStock.values.fold(0, (sum, val) => sum + val);

                  // CONDITION 1: Global Stock depletion below standard parameters
                  if (totalStock <= minLevel) {
                    structuralAlerts.add({
                      'type': 'CRITICAL_GLOBAL',
                      'docId': docId,
                      'name': name,
                      'title': 'Global Deficit Warning',
                      'details': 'Total warehouse volume ($totalStock units) dropped below minimum safety threshold ($minLevel).',
                      'color': Colors.red,
                      'icon': Icons.gpp_bad,
                      'actionable': false,
                    });
                  }

                  // CONDITION 2: Balancing and re-allocating opportunities
                  cityStock.forEach((city, stock) {
                    if (stock < 100) {
                      cityStock.forEach((donorCity, donorStock) {
                        if (donorStock > 800) {
                          structuralAlerts.add({
                            'type': 'MISMATCH_TRANSFER',
                            'docId': docId,
                            'name': name,
                            'title': 'Inter-City Asymmetry Detected',
                            'details': '$city center is critically low ($stock units), but $donorCity has an operational surplus ($donorStock units).',
                            'color': Colors.orange,
                            'icon': Icons.swap_horizontal_circle,
                            'actionable': true,
                            'fromCity': donorCity,
                            'toCity': city,
                            'fromStockAvailable': donorStock,
                            'toStockAvailable': stock,
                          });
                        }
                      });
                    }
                  });
                }

                if (structuralAlerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
                        const SizedBox(height: 16),
                        const Text('All Hub Nodes Synchronized', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Supply chain metrics are inside optimal bands.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: structuralAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = structuralAlerts[index];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: alert['color'].withOpacity(0.3), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(alert['icon'], color: alert['color'], size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(alert['title'], style: TextStyle(color: alert['color'], fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text(alert['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            Text(alert['details'], style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.3)),
                            if (alert['actionable']) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showTransferDialog(
                                    docId: alert['docId'],
                                    productTitle: alert['name'],
                                    sourceCity: alert['fromCity'],
                                    destinationCity: alert['toCity'],
                                    sourceAvailableStock: alert['fromStockAvailable'],
                                    destCurrentStock: alert['toStockAvailable'],
                                  ),
                                  icon: const Icon(Icons.edit_road, size: 16),
                                  label: const Text('Review & Set Transfer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}