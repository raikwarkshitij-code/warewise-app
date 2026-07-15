import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import 'package:provider/provider.dart';
import '../services/lane_metrics.dart';
import '../services/role_service.dart';
import '../services/transfer_service.dart';
import '../widgets/stream_error_view.dart';
import 'purchase_orders_tab.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage>
    with SingleTickerProviderStateMixin {
  bool _isBusy = false;
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, String> _calculateLaneMetrics(String from, String to) {
    final lane = LaneMetricsService.forRoute(from, to);
    return {
      'distance': lane.distance,
      'leadTime': lane.leadTimeLabel,
      'carrier': lane.carrier,
      'route': lane.route,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic adaptive screen tracker
    final bool isWideScreen = MediaQuery.of(context).size.width > 750;
    final roleService = context.watch<RoleService>();
    final bool isManager = roleService.hasAnyRole(['manager', 'owner']);
    final bool isAssociate =
        roleService.hasAnyRole(['associate', 'manager', 'owner']);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Header Configuration Block
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MWIS Fulfillment Terminal',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          isManager
                              ? 'Manager View: Open Authorizations'
                              : 'Associate View: Active Tracking Lines',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isManager
                        ? Colors.amber.shade700
                        : Colors.blueGrey.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          isManager
                              ? Icons.verified_user
                              : Icons.badge_outlined,
                          size: 16,
                          color: Colors.white),
                      const SizedBox(width: 6),
                      Text(roleService.role?.toUpperCase() ?? 'UNKNOWN',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF009473),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF009473),
              tabs: const [
                Tab(text: 'Inter-Hub Transfers'),
                Tab(text: 'Purchase Orders'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransfersTab(
                      context, isWideScreen, isManager, isAssociate),
                  PurchaseOrdersTab(isManager: isManager),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersTab(BuildContext context, bool isWideScreen,
      bool isManager, bool isAssociate) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('transfers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamErrorView(
            error: snapshot.error,
            message: 'Could not load inter-hub transfers.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];
        List<QueryDocumentSnapshot> sortedDocs = allDocs.toList()
          ..sort((a, b) {
            int getWeight(String s) {
              if (s == 'Pending') return 0;
              if (s == 'In Transit') return 1;
              if (s == 'Delivered') return 2;
              if (s == 'Rejected') return 4;
              return 3;
            }

            return getWeight((a.data() as Map)['status'] ?? '')
                .compareTo(getWeight((b.data() as Map)['status'] ?? ''));
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
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final currentDoc = sortedDocs[index];
            final currentOrder = currentDoc.data() as Map<String, dynamic>;
            final String orderId = currentDoc.id;

            final String status = currentOrder['status'] ?? 'Pending';
            final bool isPending = status == 'Pending';
            final bool isInTransit = status == 'In Transit';
            final bool isDelivered = status == 'Delivered';
            final bool isRejected = status == 'Rejected';

            final String origin = currentOrder['from'] ?? 'Unknown';
            final String dest = currentOrder['to'] ?? 'Unknown';
            final laneMetrics = _calculateLaneMetrics(origin, dest);

            final int volumeInt =
                int.tryParse(currentOrder['volume']?.toString() ?? '0') ?? 0;

            // AUTOMATED FALLBACK MATH CALCULATOR
            double procCost = double.tryParse(
                    currentOrder['procurementCost']?.toString() ?? '0') ??
                0.0;
            double transCost = double.tryParse(
                    currentOrder['transferCost']?.toString() ?? '0') ??
                0.0;
            double savings = double.tryParse(
                    currentOrder['netSavings']?.toString() ?? '0') ??
                0.0;

            if (procCost == 0.0) {
              procCost = volumeInt * 85.20;
              transCost = volumeInt * 2.925;
              savings = procCost - transCost;
            }

            Color badgeBg = isDelivered
                ? Colors.green.shade50
                : (isRejected
                    ? Colors.red.shade50
                    : (isInTransit
                        ? Colors.blue.shade50
                        : Colors.amber.shade50));
            Color badgeBorder = isDelivered
                ? Colors.green.shade200
                : (isRejected
                    ? Colors.red.shade200
                    : (isInTransit
                        ? Colors.blue.shade200
                        : Colors.amber.shade200));
            Color badgeTextC = isDelivered
                ? Colors.green.shade900
                : (isRejected
                    ? Colors.red.shade900
                    : (isInTransit
                        ? Colors.blue.shade900
                        : Colors.amber.shade900));
            String badgeText = isDelivered
                ? 'Transfer Completed'
                : (isRejected
                    ? 'Rejected'
                    : (isInTransit
                        ? 'Transfer Initiated'
                        : 'Awaiting Approval'));

            List<Widget> cardContent = [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TRF-${orderId.substring(0, 5).toUpperCase()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              Text(currentOrder['productName'] ?? 'Inventory SKU Item',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              // HIGH-FIDELITY ADAPTIVE STRUCTURE TRACK ROUTE
              isWideScreen
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Origin: $origin',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black54)),
                        Text('Batch Qty: $volumeInt Units',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 14)),
                        Text('Destination: $dest',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black54)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            Text('Origin: $origin',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54)),
                            Text('Destination: $dest',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black54)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Batch Qty: $volumeInt Units',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 14)),
                      ],
                    ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildStatusNode(Icons.playlist_add_check, 'Requested', true),
                  _buildProgressLine(active: isInTransit || isDelivered),
                  _buildStatusNode(Icons.local_shipping, 'In Transit',
                      isInTransit || isDelivered),
                  _buildProgressLine(active: isDelivered),
                  _buildStatusNode(Icons.warehouse, 'Delivered', isDelivered),
                ],
              ),
            ];

            // HIGH-FIDELITY MATRIX INJECTION CARD
            if (isManager && isPending) {
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
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics,
                                size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            // FIXED COMPONENT: Wrapped text inside Expanded to block horizontal 46px breaks on mobile screens
                            Expanded(
                              child: Text(
                                  'EXECUTIVE DECISION MATRIX: SUPPLY CHAIN OPTIMIZATION',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade400,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                  'Option A: External Vendor Procurement Loss:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade300)),
                            ),
                            Text('- €${procCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                  'Option B: Internal Transfer Route Freight:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade300)),
                            ),
                            Text('- €${transCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orangeAccent)),
                          ],
                        ),
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Divider(color: Colors.white24)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                  'TOTAL CAPITAL RETAINED (NET PROFIT):',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade100)),
                            ),
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
                        border: Border.all(color: Colors.blueGrey.shade100)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isWideScreen
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    Icon(Icons.navigation,
                                        size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Text('Distance: ${laneMetrics['distance']}',
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
                              )
                            : Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.navigation,
                                          size: 16,
                                          color: Colors.blue.shade700),
                                      const SizedBox(width: 6),
                                      Text(
                                          'Distance: ${laneMetrics['distance']}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                                  : Colors.orange.shade900)),
                                    ],
                                  ),
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
                                  fontSize: 12, color: Colors.grey.shade700))
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200)),
                  child: Row(
                    children: [
                      Icon(Icons.verified,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '✔ Procurement Sourcing Deflected: Saved €${savings.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ));
            }

            if (isManager && isPending) {
              cardContent.add(Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => _rejectOrder(context, orderId),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Reject Manifest',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: _isBusy
                            ? null
                            : () => _managerApproveAndShip(context, orderId),
                        icon: const Icon(Icons.local_shipping, size: 18),
                        label: const Text('Approve & Ship',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ));
            }

            if (isAssociate && isInTransit) {
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
                              borderRadius: BorderRadius.circular(8))),
                      onPressed: _isBusy
                          ? null
                          : () => _associateConfirmDelivery(context, orderId),
                      icon: const Icon(Icons.library_add_check, size: 18),
                      label: const Text('Confirm Arrival & Receive Stock',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            height: 2,
            color: active ? Colors.orange.shade700 : Colors.grey.shade200,
            margin: const EdgeInsets.only(bottom: 16)));
  }

  Future<void> _runTransferAction(
    BuildContext context,
    Future<void> Function() action, {
    required String successMessage,
    required String failurePrefix,
  }) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$failurePrefix: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _rejectOrder(BuildContext context, String transferId) {
    return _runTransferAction(
      context,
      () => TransferService.reject(transferId),
      successMessage: 'Transfer manifest rejected.',
      failurePrefix: 'Rejection failed',
    );
  }

  Future<void> _managerApproveAndShip(BuildContext context, String transferId) {
    return _runTransferAction(
      context,
      () => TransferService.approveAndShip(transferId),
      successMessage:
          'Shipment authorized! Manifest progress set to Transfer Initiated.',
      failurePrefix: 'Authorization failed',
    );
  }

  Future<void> _associateConfirmDelivery(
      BuildContext context, String transferId) {
    return _runTransferAction(
      context,
      () => TransferService.confirmDelivery(transferId),
      successMessage:
          'Stock received on dock! Quantities updated successfully.',
      failurePrefix: 'Receipt failed',
    );
  }
}
