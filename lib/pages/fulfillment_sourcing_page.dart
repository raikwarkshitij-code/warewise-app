import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import '../services/operations_ai.dart';
import '../services/supplier_service.dart';
import '../widgets/supplier_decision_matrix.dart';

class FulfillmentSourcingPage extends StatefulWidget {
  final String productSku;
  final String productName;
  final int currentStock;
  final VoidCallback?
      onTransferExecuted; // Callback to trigger root tab switching

  const FulfillmentSourcingPage({
    super.key,
    required this.productSku,
    required this.productName,
    required this.currentStock,
    this.onTransferExecuted,
  });

  @override
  State<FulfillmentSourcingPage> createState() =>
      _FulfillmentSourcingPageState();
}

class _FulfillmentSourcingPageState extends State<FulfillmentSourcingPage> {
  bool _isProcessing = false;

  // Fetched once (Balanced strategy) and shared as the INITIAL ranking for
  // both the recommendation banner and the Compare Suppliers matrix below,
  // so on first load the two surfaces agree on the #1 supplier. The matrix
  // lets the manager switch strategy locally afterwards — see its own
  // strategy selector — which only re-ranks the matrix, not this banner.
  late final Future<SupplierRankingResult> _rankingFuture =
      SupplierService.getSupplierRanking(widget.productSku);
  late final Future<_SourcingData> _dataFuture = _loadData();

  Future<_SourcingData> _loadData() async {
    final productSnap =
        await db.collection('products').doc(widget.productSku).get();
    final product = productSnap.data() ?? {};

    Map<String, dynamic>? restrictedData;
    try {
      final result = await _rankingFuture;
      final top = result.recommended;
      if (top != null) {
        restrictedData = {
          'supplierName': top.supplierName,
          'costPerUnit': top.unitCost,
          'leadTimeDays': top.leadTimeDays,
        };
      }
    } catch (_) {
      restrictedData = null;
    }

    final decision = OperationsAI.calculateOptimalRoute(product,
        restrictedData: restrictedData);
    return _SourcingData(product: product, decision: decision);
  }

  Future<void> _executeInterWarehouseTransfer(
      String sourceHub, String destinationHub, int transferQty) async {
    setState(() => _isProcessing = true);
    try {
      await db.collection('transfers').add({
        'productId': widget.productSku,
        'productName': widget.productName,
        'from': sourceHub,
        'to': destinationHub,
        'volume': transferQty,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        if (widget.onTransferExecuted != null) {
          widget.onTransferExecuted!();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Transfer request created from $sourceHub — awaiting manager approval.'),
            backgroundColor: const Color(0xFF009473),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create transfer: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF01604B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Supply Chain Sourcing Engine',
            style: TextStyle(
                color: Color(0xFF01604B),
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ),
      body: _isProcessing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF009473)))
          : FutureBuilder<_SourcingData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF009473)));
                }
                final data = snapshot.data!;
                final decision = data.decision;
                final bool canTransfer =
                    decision.recommendedAction == 'TRANSFER';
                final bool canPurchase =
                    decision.recommendedAction == 'PURCHASE';
                final cityStock = Map<String, dynamic>.from(
                    data.product['cityStock'] as Map? ?? {});
                final unitsNeeded = decision.unitsNeeded;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SKU: ${widget.productSku}',
                                style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(widget.productName,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937))),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Current Local Stock:',
                                    style: TextStyle(color: Colors.grey)),
                                Text('${widget.currentStock} Units',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.redAccent)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        canTransfer
                            ? '💡 Recommended Strategy: Internal Transfer'
                            : '🏭 Recommended Strategy: Procurement PO',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF01604B)),
                      ),
                      const SizedBox(height: 12),
                      if (canTransfer)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF99D4C7)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.local_shipping_outlined,
                                      color: Color(0xFF009473)),
                                  SizedBox(width: 8),
                                  Text('Network Inventory Discovered',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF01604B))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Source Hub: ${decision.targetName}'),
                              Text(
                                  'Available Network Stock: ${cityStock[decision.targetName] ?? 0} Units'),
                              Text(
                                  'Logistics ETA: ${decision.leadTimeDays} Day Transit'),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF009473),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.swap_horiz_rounded),
                                  label: Text(
                                      'Request Transfer (${unitsNeeded > 0 ? unitsNeeded : 0} Units)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () =>
                                      _executeInterWarehouseTransfer(
                                    decision.targetName,
                                    decision.shortageHub,
                                    unitsNeeded > 0 ? unitsNeeded : 0,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      if (canPurchase)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business_center_outlined,
                                  color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    'No hub has surplus stock — reorder from a supplier below. AI-suggested pick: ${decision.targetName}.',
                                    style: const TextStyle(
                                        color: Color(0xFFB45309),
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      if (!canTransfer && !canPurchase)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(decision.reasoning,
                              style: const TextStyle(color: Color(0xFF475569))),
                        ),
                      const SizedBox(height: 28),
                      const Text('Compare Suppliers',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF01604B))),
                      const SizedBox(height: 4),
                      const Text(
                          'Choose a business priority to re-rank suppliers, or use the AI recommendation as-is. The Balanced view matches the recommendation above. The system never picks for you — every PO needs your confirmation.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      SupplierDecisionMatrix(
                        productSku: widget.productSku,
                        productName: widget.productName,
                        defaultQuantity: unitsNeeded > 0 ? unitsNeeded : 100,
                        destinationHub: decision.shortageHub,
                        rankingFuture: _rankingFuture,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _SourcingData {
  final Map<String, dynamic> product;
  final DecisionResult decision;

  _SourcingData({required this.product, required this.decision});
}
