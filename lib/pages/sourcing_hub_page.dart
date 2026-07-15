import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import '../widgets/stream_error_view.dart';
import 'fulfillment_sourcing_page.dart';

/// Lists products currently below threshold and lets a manager/owner open
/// the sourcing engine (transfer vs. reorder) for any one of them.
class SourcingHubPage extends StatelessWidget {
  final VoidCallback? onTransferExecuted;

  const SourcingHubPage({super.key, this.onTransferExecuted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF01604B)),
        title: const Text('Supply Chain Sourcing',
            style: TextStyle(
                color: Color(0xFF01604B), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(
              error: snapshot.error,
              message: 'Could not load sourcing candidates.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF009473)));
          }

          final lowStockDocs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final qty = (data['quantity'] as num?) ?? 0;
            final threshold = (data['threshold'] as num?) ?? 0;
            return qty <= threshold;
          }).toList();

          if (lowStockDocs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 60, color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text('No products need sourcing right now.',
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockDocs.length,
            itemBuilder: (context, index) {
              final doc = lowStockDocs[index];
              final product = doc.data() as Map<String, dynamic>;
              final qty = (product['quantity'] as num?)?.toInt() ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF7ED),
                      child: Icon(Icons.local_shipping_outlined,
                          color: Color(0xFFEA580C))),
                  title: Text(product['name'] ?? 'Unknown Item',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Stock: $qty / Threshold: ${product['threshold'] ?? 0}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FulfillmentSourcingPage(
                        productSku: doc.id,
                        productName: product['name'] ?? 'Unknown Item',
                        currentStock: qty,
                        onTransferExecuted: onTransferExecuted,
                      ),
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
