import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  bool _isManager = false;
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showEditQuantityDialog(
      BuildContext context, String docId, int currentQty) {
    final qtyController = TextEditingController(text: currentQty.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Colors.blue),
            SizedBox(width: 8),
            Text('Modify Batch Quantity'),
          ],
        ),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New Allocation Count',
            border: OutlineInputBorder(),
            suffixText: 'Units',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final parsedQty = int.tryParse(qtyController.text);
              if (parsedQty == null || parsedQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid positive quantity')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('transfers')
                    .doc(docId)
                    .update({'volume': parsedQty});

                if (ctx.mounted) Navigator.pop(ctx);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Batch allocation adjusted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error modifying record: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Map<String, String> _calculateLaneMetrics(String from, String to) {
    final String path = '${from}_$to';
    switch (path) {
      case 'Berlin_Hamburg':
      case 'Hamburg_Berlin':
        return {
          'distance': '289 km',
          'leadTime': '4.5 Hours',
          'carrier': 'DHL Freight Express',
          'route': 'Autobahn A24'
        };
      case 'Berlin_Munich':
      case 'Munich_Berlin':
        return {
          'distance': '585 km',
          'leadTime': '8.2 Hours',
          'carrier': 'DB Schenker Logistics',
          'route': 'Autobahn A9'
        };
      case 'Hamburg_Munich':
      case 'Munich_Hamburg':
        return {
          'distance': '792 km',
          'leadTime': '11.4 Hours',
          'carrier': 'Amazon Surface Freight',
          'route': 'Autobahn A7'
        };
      default:
        return {
          'distance': '450 km',
          'leadTime': '6.0 Hours',
          'carrier': 'Inter-Hub Regional Courier',
          'route': 'Federal Highway'
        };
    }
  }

  void _showPinGatewayDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Text('Manager Access PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Enter authorization credentials to unlock approval privileges.',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    labelText: 'Security PIN',
                    prefixIcon: const Icon(Icons.password)),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                if (_pinController.text.trim() == 'mwis2026') {
                  Navigator.pop(context);
                  setState(() => _isManager = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Access Denied: Invalid PIN.'),
                      backgroundColor: Colors.red));
                }
              },
              child: const Text('Verify Code'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MWIS Fulfillment Terminal',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        _isManager
                            ? 'Manager View: Open Authorizations'
                            : 'Associate View: Active Tracking Lines',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _isManager
                          ? Colors.amber.shade700
                          : Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10)),
                  onPressed: () {
                    if (_isManager) {
                      setState(() => _isManager = false);
                    } else {
                      _showPinGatewayDialog();
                    }
                  },
                  icon: Icon(
                      _isManager ? Icons.verified_user : Icons.lock_outline,
                      size: 16),
                  label: Text(
                      _isManager ? 'Manager Mode Active' : 'Switch to Manager'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transfers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Pipeline error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  List<QueryDocumentSnapshot> sortedDocs = allDocs.toList()
                    ..sort((a, b) {
                      int getWeight(String s) {
                        if (s == 'Pending Approval') return 0;
                        if (s == 'In Transit') return 1;
                        if (s == 'Delivered') return 2;
                        return 3;
                      }

                      return getWeight((a.data() as Map)['status'] ?? '')
                          .compareTo(
                              getWeight((b.data() as Map)['status'] ?? ''));
                    });

                  if (sortedDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                              'No logistics history or active freight shipments found.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      final currentDoc = sortedDocs[index];
                      final currentOrder =
                          currentDoc.data() as Map<String, dynamic>;
                      final String orderId = currentDoc.id;

                      final String status =
                          currentOrder['status'] ?? 'Pending Approval';
                      final bool isPending = status == 'Pending Approval';
                      final bool isInTransit = status == 'In Transit';
                      final bool isDelivered = status == 'Delivered';

                      final String origin = currentOrder['from'] ?? 'Unknown';
                      final String dest = currentOrder['to'] ?? 'Unknown';
                      final laneMetrics = _calculateLaneMetrics(origin, dest);

                      final int volumeInt = int.tryParse(
                              currentOrder['volume']?.toString() ?? '0') ??
                          0;

                      final double procCost = double.tryParse(
                              currentOrder['procurementCost']?.toString() ??
                                  '0') ??
                          0.0;
                      final double transCost = double.tryParse(
                              currentOrder['transferCost']?.toString() ??
                                  '0') ??
                          0.0;
                      final double savings = double.tryParse(
                              currentOrder['netSavings']?.toString() ?? '0') ??
                          0.0;

                      Color badgeBg = isDelivered
                          ? Colors.green.shade50
                          : (isInTransit
                              ? Colors.blue.shade50
                              : Colors.amber.shade50);
                      Color badgeBorder = isDelivered
                          ? Colors.green.shade200
                          : (isInTransit
                              ? Colors.blue.shade200
                              : Colors.amber.shade200);
                      Color badgeTextC = isDelivered
                          ? Colors.green.shade900
                          : (isInTransit
                              ? Colors.blue.shade900
                              : Colors.amber.shade900);
                      String badgeText = isDelivered
                          ? 'Transfer Completed'
                          : (isInTransit
                              ? 'Transfer Initiated'
                              : 'Awaiting Approval');

                      List<Widget> cardContent = [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TRF-${orderId.substring(0, 5).toUpperCase()}',
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
                              child: Text(badgeText,
                                  style: TextStyle(
                                      color: badgeTextC,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                            currentOrder['productName'] ?? 'Inventory SKU Item',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Origin: $origin',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Batch Qty: $volumeInt Units',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                        fontSize: 14)),
                                // FIXED: The edit action is now explicitly isolated to "Pending Approval" manifests
                                if (isPending) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 14),
                                    color: Colors.blue.shade700,
                                    tooltip: 'Modify Manifest Volume',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    onPressed: () {
                                      _showEditQuantityDialog(
                                          context, orderId, volumeInt);
                                    },
                                  ),
                                ],
                              ],
                            ),
                            Text('Destination: $dest',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            _buildStatusNode(
                                Icons.playlist_add_check, 'Requested', true),
                            _buildProgressLine(
                                active: isInTransit || isDelivered),
                            _buildStatusNode(Icons.local_shipping, 'In Transit',
                                isInTransit || isDelivered),
                            _buildProgressLine(active: isDelivered),
                            _buildStatusNode(
                                Icons.warehouse, 'Delivered', isDelivered),
                          ],
                        ),
                      ];

                      if (_isManager && isPending && procCost > 0) {
                        cardContent.add(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.analytics,
                                          size: 18, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Text(
                                          'EXECUTIVE DECISION MATRIX: SUPPLY CHAIN OPTIMIZATION',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade400,
                                              letterSpacing: 0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      const Icon(Icons.cancel,
                                          size: 14, color: Colors.redAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                          'Option A: External Vendor Procurement Loss:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade300)),
                                      const Spacer(),
                                      Text('- €${procCost.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          size: 14, color: Colors.greenAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                          'Option B: Internal Transfer Route Freight:',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade300)),
                                      const Spacer(),
                                      Text('- €${transCost.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orangeAccent)),
                                    ],
                                  ),
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 10.0),
                                      child: Divider(color: Colors.white24)),
                                  Row(
                                    children: [
                                      const Icon(Icons.savings,
                                          size: 16, color: Colors.greenAccent),
                                      const SizedBox(width: 8),
                                      const Text(
                                          'TOTAL CAPITAL RETAINED (NET PROFIT):',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                      const Spacer(),
                                      Text('+ €${savings.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ));
                      }

                      if (isInTransit || isDelivered) {
                        cardContent.add(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.blueGrey.shade100)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.navigation,
                                            size: 16,
                                            color: Colors.blue.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                            'Distance: ${laneMetrics['distance']}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold))
                                      ]),
                                      Row(children: [
                                        Icon(
                                            isDelivered
                                                ? Icons.check_circle
                                                : Icons.timer,
                                            size: 16,
                                            color: isDelivered
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                            isDelivered
                                                ? 'Status: Received'
                                                : 'Est. Lead Time: ${laneMetrics['leadTime']}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDelivered
                                                    ? Colors.green.shade900
                                                    : Colors.orange.shade900))
                                      ])
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    const Icon(Icons.alt_route,
                                        size: 14, color: Colors.black54),
                                    const SizedBox(width: 6),
                                    Text('Freight Highway: ',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.bold)),
                                    Text('${laneMetrics['route']}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700))
                                  ]),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    const Icon(Icons.business,
                                        size: 14, color: Colors.black54),
                                    const SizedBox(width: 6),
                                    Text('Carrier Log: ',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.bold)),
                                    Text('${laneMetrics['carrier']}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic))
                                  ])
                                ],
                              ),
                            )
                          ],
                        ));
                      }

                      if (isDelivered && savings > 0) {
                        cardContent.add(Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.green.shade200)),
                            child: Row(
                              children: [
                                Icon(Icons.verified,
                                    size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                    '✔ Procurement Sourcing Deflected: Saved €${savings.toStringAsFixed(2)}',
                                    style: TextStyle(
                                        color: Colors.green.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ));
                      }

                      if (_isManager && isPending) {
                        cardContent.add(Column(
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                    onPressed: () => _rejectOrder(
                                        context, currentDoc.reference),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text('Reject Manifest',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8))),
                                  onPressed: () => _managerApproveAndShip(
                                      context, orderId, currentOrder),
                                  icon: const Icon(Icons.local_shipping,
                                      size: 18),
                                  label: const Text('Approve & Ship',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ));
                      }

                      if (!_isManager && isInTransit) {
                        cardContent.add(Column(
                          children: [
                            const SizedBox(height: 20),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                onPressed: () => _associateConfirmDelivery(
                                    context, orderId, currentOrder),
                                icon: const Icon(Icons.library_add_check,
                                    size: 18),
                                label: const Text(
                                    'Confirm Arrival & Receive Stock',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ));
                      }

                      return Card(
                        elevation: isDelivered ? 1 : 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: isDelivered ? Colors.grey.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isDelivered
                                ? BorderSide(color: Colors.grey.shade300)
                                : BorderSide.none),
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: cardContent)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusNode(IconData icon, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
            radius: 18,
            backgroundColor:
                active ? Colors.orange.shade700 : Colors.grey.shade200,
            child: Icon(icon,
                size: 16, color: active ? Colors.white : Colors.grey)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.black87 : Colors.grey)),
      ],
    );
  }

  Widget _buildProgressLine({required bool active}) {
    return Expanded(
        child: Container(
            height: 2,
            color: active ? Colors.orange.shade700 : Colors.grey.shade200,
            margin: const EdgeInsets.only(bottom: 16)));
  }

  Future<void> _rejectOrder(
      BuildContext context, DocumentReference docRef) async {
    try {
      docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Transfer manifest rejected and removed.'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _managerApproveAndShip(BuildContext context, String transferId,
      Map<String, dynamic> order) async {
    try {
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(order['productId']);
      final transferRef =
          FirebaseFirestore.instance.collection('transfers').doc(transferId);
      String sourceHub = order['from'] ?? 'Berlin';
      int volume = int.tryParse(order['volume']?.toString() ?? '100') ?? 100;

      productRef.set({
        'cityStock': {sourceHub: FieldValue.increment(-volume)}
      }, SetOptions(merge: true));
      transferRef.update({'status': 'In Transit'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Shipment authorized! Manifest progress set to Transfer Initiated.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Authorization Failed: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _associateConfirmDelivery(BuildContext context,
      String transferId, Map<String, dynamic> order) async {
    try {
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(order['productId']);
      final transferRef =
          FirebaseFirestore.instance.collection('transfers').doc(transferId);
      String destinationHub = order['to'] ?? 'Munich';
      int volume = int.tryParse(order['volume']?.toString() ?? '100') ?? 100;

      productRef.set({
        'cityStock': {destinationHub: FieldValue.increment(volume)}
      }, SetOptions(merge: true));
      transferRef.update({'status': 'Delivered'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Stock received on dock! Quantities updated successfully.'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Receipt Failed: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }
}
