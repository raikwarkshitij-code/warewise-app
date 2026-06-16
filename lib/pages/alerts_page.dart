import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fulfillment_sourcing_page.dart';

class AlertsPage extends StatelessWidget {
  final VoidCallback? onTabRedirect; // Link callback from root shell navigation tree

  const AlertsPage({super.key, this.onTabRedirect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF01604B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Restock Urgent List',
          style: TextStyle(color: Color(0xFF01604B), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF009473)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No database inventory records mapped.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          // Filter low stock records dynamically using your baseline wholesale limit
          final lowStockItems = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String rawQuantity = data['quantity']?.toString() ?? '0';
            final int quantity = int.tryParse(rawQuantity) ?? 0;
            const int forcedAlertThreshold = 1000; 
            return quantity <= forcedAlertThreshold;
          }).toList();

          if (lowStockItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF1CB08F)),
                  SizedBox(height: 12),
                  Text(
                    'All stock levels operational!', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF01604B)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockItems.length,
            itemBuilder: (context, index) {
              final doc = lowStockItems[index];
              final item = doc.data() as Map<String, dynamic>;
              final String sku = item['sku'] ?? doc.id; 
              final String name = item['name'] ?? 'Unknown Product';
              final int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
              final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FulfillmentSourcingPage(
                        productSku: sku,
                        productName: name,
                        currentStock: qty,
                        onTransferExecuted: () {
                          // 1. Pop back out of the alert list completely to clean navigation history
                          Navigator.pop(context); 
                          // 2. Fire root redirection shortcut to slide open the Ops tab view
                          if (onTabRedirect != null) onTabRedirect!();
                        },
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5), 
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 14),
                    ),
                    subtitle: Text(
                      'SKU: $sku • Cat: ${item['category'] ?? 'Unassigned'}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Text(
                            '$qty Units Left',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900, 
                              color: Color(0xFFEA580C), 
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${price.toStringAsFixed(2)} / unit',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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