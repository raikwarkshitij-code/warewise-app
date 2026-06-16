import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FulfillmentSourcingPage extends StatefulWidget {
  final String productSku;
  final String productName;
  final int currentStock;
  final VoidCallback? onTransferExecuted; // Callback to trigger root tab switching

  const FulfillmentSourcingPage({
    super.key,
    required this.productSku,
    required this.productName,
    required this.currentStock,
    this.onTransferExecuted,
  });

  @override
  State<FulfillmentSourcingPage> createState() => _FulfillmentSourcingPageState();
}

class _FulfillmentSourcingPageState extends State<FulfillmentSourcingPage> {
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _otherWarehouses = [
    {'name': 'Munich Logistics Hub (Zone South)', 'availableStock': 1420, 'transitDays': 1},
    {'name': 'Frankfurt Fulfillment Center', 'availableStock': 95, 'transitDays': 2},
    {'name': 'Hamburg Port Warehouse', 'availableStock': 0, 'transitDays': 4},
  ];

  final Map<String, dynamic> _primarySupplier = {
    'company': 'Apex Global Distribution GmbH',
    'moq': 500,
    'unitCost': 12.50,
    'leadTimeDays': 7,
  };

  Future<void> _executeInterWarehouseTransfer(String sourceWarehouse, int transferQty) async {
    setState(() => _isProcessing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      
      final docRef = FirebaseFirestore.instance.collection('products').doc(widget.productSku);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        int currentQty = int.tryParse(snapshot.get('quantity').toString()) ?? 0;
        transaction.update(docRef, {'quantity': currentQty + transferQty});
      });

      if (mounted) {
        // 1. Pop back out of this sourcing sub-page view stack
        Navigator.pop(context);
        
        // 2. Fire the redirection callback to change global bottom navigation index
        if (widget.onTransferExecuted != null) {
          widget.onTransferExecuted!();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logistics Pipeline Initiated: Transfer order created from $sourceWarehouse!'),
            backgroundColor: const Color(0xFF009473),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _raisePurchaseOrder() async {
    setState(() => _isProcessing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showPODialog();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _showPODialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF01604B)),
            SizedBox(width: 8),
            Text('PO Raised Successfully'),
          ],
        ),
        content: Text(
          'Purchase Order Manifest signed and transmitted to ${_primarySupplier['company']}.\n\n'
          '• Standard MOQ: ${_primarySupplier['moq']} Units\n'
          '• Expected Delivery Lead Time: ${_primarySupplier['leadTimeDays']} Days',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Acknowledge', style: TextStyle(color: Color(0xFF009473), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapWarehouse = _otherWarehouses.firstWhere(
      (w) => w['availableStock'] >= 500,
      orElse: () => {},
    );
    
    final bool canTransferInternally = mapWarehouse.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF01604B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Supply Chain Sourcing Engine', style: TextStyle(color: Color(0xFF01604B), fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF009473)))
          : SingleChildScrollView(
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
                        Text('SKU: ${widget.productSku}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.productName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Local Stock:', style: TextStyle(color: Colors.grey)),
                            Text('${widget.currentStock} Units', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    canTransferInternally ? '💡 Recommended Strategy: Internal Transfer' : '🏭 Recommended Strategy: Procurement PO',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF01604B)),
                  ),
                  const SizedBox(height: 12),
                  if (canTransferInternally)
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
                              Icon(Icons.local_shipping_outlined, color: Color(0xFF009473)),
                              SizedBox(width: 8),
                              Text('Network Inventory Discovered', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF01604B))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Source Hub: ${mapWarehouse['name']}'),
                          Text('Available Network Stock: ${mapWarehouse['availableStock']} Units'),
                          Text('Logistics ETA: Only ${mapWarehouse['transitDays']} Day Transit'),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF009473), 
                                foregroundColor: Colors.white, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                              ),
                              icon: const Icon(Icons.swap_horiz_rounded),
                              label: const Text('Execute Inter-Warehouse Rebalance (500 Units)', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _executeInterWarehouseTransfer(mapWarehouse['name'], 500),
                            ),
                          )
                        ],
                      ),
                    ),
                  if (!canTransferInternally)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.business_center_outlined, color: Color(0xFFD97706)),
                              SizedBox(width: 8),
                              Text('Logistics Network Stock Exhausted', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Assigned Vendor: ${_primarySupplier['company']}'),
                          Text('Supplier MOQ Reorder constraint: ${_primarySupplier['moq']} Units'),
                          Text('Procurement Lead Time: ${_primarySupplier['leadTimeDays']} Days via Factory Freight'),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706), 
                                foregroundColor: Colors.white, 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                              ),
                              icon: const Icon(Icons.shopping_cart_checkout_rounded),
                              label: const Text('Authorize & Raise Purchase Order (PO)', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _raisePurchaseOrder,
                            ),
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}