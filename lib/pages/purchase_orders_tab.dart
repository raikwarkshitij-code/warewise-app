import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import '../services/purchase_order_service.dart';
import '../widgets/stream_error_view.dart';

/// Ops-tab view of purchase orders raised from the Sourcing decision matrix.
/// Stock only ever increases when a manager taps "Confirm Goods Receipt" —
/// raising the PO itself never touches inventory.
class PurchaseOrdersTab extends StatefulWidget {
  final bool isManager;

  const PurchaseOrdersTab({super.key, required this.isManager});

  @override
  State<PurchaseOrdersTab> createState() => _PurchaseOrdersTabState();
}

class _PurchaseOrdersTabState extends State<PurchaseOrdersTab> {
  bool _isBusy = false;

  Future<void> _confirmGoodsReceipt(
      BuildContext context, String poId, String productName) async {
    final qualityController = TextEditingController(text: '85');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Goods Receipt — $productName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will increase stock at the destination hub and record a real supplier performance event.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qualityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quality Score (0-100)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009473),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final quality = int.tryParse(qualityController.text)?.clamp(0, 100);

    setState(() => _isBusy = true);
    try {
      await PurchaseOrderService.confirmGoodsReceipt(poId,
          qualityScore: quality);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Goods receipt confirmed — stock updated.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Receipt failed: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Widget _statusNode(IconData icon, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              active ? const Color(0xFF009473) : Colors.grey.shade200,
          child:
              Icon(icon, size: 16, color: active ? Colors.white : Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.black87 : Colors.grey)),
      ],
    );
  }

  Widget _progressLine({required bool active}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        height: 2,
        color: active ? const Color(0xFF009473) : Colors.grey.shade200,
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('purchase_orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamErrorView(
            error: snapshot.error,
            message: 'Could not load purchase orders.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final sorted = docs.toList()
          ..sort((a, b) {
            int weight(String s) => s == 'Raised' ? 0 : 1;
            final aStatus = (a.data() as Map)['status'] ?? 'Raised';
            final bStatus = (b.data() as Map)['status'] ?? 'Raised';
            return weight(aStatus).compareTo(weight(bStatus));
          });

        if (sorted.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No purchase orders raised yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final doc = sorted[index];
            final po = doc.data() as Map<String, dynamic>;
            final poId = doc.id;

            final String status = po['status'] ?? 'Raised';
            final bool isRaised = status == 'Raised';
            final bool isReceived = status == 'Received';

            final String productName = po['productName'] ?? 'Unknown Product';
            final String supplierName =
                po['supplierName'] ?? 'Unknown Supplier';
            final String destinationHub = po['destinationHub'] ?? 'Unknown';
            final int quantity = (po['quantity'] as num?)?.toInt() ?? 0;
            final double unitCost = (po['unitCost'] as num?)?.toDouble() ?? 0;
            final double totalCost = (po['totalCost'] as num?)?.toDouble() ?? 0;
            final int leadTimeDays = (po['leadTimeDays'] as num?)?.toInt() ?? 0;

            final Color badgeBg =
                isReceived ? Colors.green.shade50 : Colors.amber.shade50;
            final Color badgeBorder =
                isReceived ? Colors.green.shade200 : Colors.amber.shade200;
            final Color badgeText =
                isReceived ? Colors.green.shade900 : Colors.amber.shade900;
            final String badgeLabel =
                isReceived ? 'Received' : 'Awaiting Goods Receipt';

            return Card(
              elevation: isReceived ? 1 : 3,
              margin: const EdgeInsets.only(bottom: 16),
              color: isReceived ? Colors.grey.shade50 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isReceived
                    ? BorderSide(color: Colors.grey.shade300)
                    : BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PO-${poId.substring(0, 5).toUpperCase()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: badgeBorder)),
                          child: Text(badgeLabel,
                              style: TextStyle(
                                  color: badgeText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(productName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Supplier: $supplierName',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Text('Qty: $quantity units',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Unit Cost: \$${unitCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54)),
                        Text('Total: \$${totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF01604B))),
                        Text('Ships to: $destinationHub',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54)),
                        Text('Lead time: $leadTimeDays days',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _statusNode(
                            Icons.playlist_add_check, 'Requested', true),
                        _progressLine(active: true),
                        _statusNode(Icons.local_shipping, 'In Transit', true),
                        _progressLine(active: isReceived),
                        _statusNode(Icons.warehouse, 'Delivered', isReceived),
                      ],
                    ),
                    if (widget.isManager && isRaised) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009473),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isBusy
                              ? null
                              : () => _confirmGoodsReceipt(
                                  context, poId, productName),
                          icon: const Icon(Icons.inventory_2_rounded, size: 18),
                          label: const Text('Confirm Goods Receipt',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
