import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import 'package:provider/provider.dart';
import '../services/operations_ai.dart';
import '../services/role_service.dart';
import '../services/supplier_service.dart';
import '../widgets/relocation_path_indicator.dart';
import '../widgets/stream_error_view.dart';

class AlertsPage extends StatelessWidget {
  final VoidCallback? onTabRedirect;

  const AlertsPage({super.key, this.onTabRedirect});

  static const _costVisibleRoles = ['manager', 'finance', 'owner'];

  @override
  Widget build(BuildContext context) {
    final canSeeCost =
        context.watch<RoleService>().hasAnyRole(_costVisibleRoles);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF01604B)),
        title: const Text('Wise AI Recommendations',
            style: TextStyle(
                color: Color(0xFF01604B), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(
              error: snapshot.error,
              message: 'Could not load Wise AI recommendations.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF009473)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No items currently tracked.",
                    style: TextStyle(color: Colors.grey)));
          }

          final lowStockItems = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final qty = (data['quantity'] as num?) ?? 0;
            final threshold = (data['threshold'] as num?) ?? 0;
            return qty <= threshold;
          }).toList();

          if (lowStockItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 60, color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text("Inventory Optimal",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                  Text("No AI interventions required at this time.",
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lowStockItems.length,
            itemBuilder: (context, index) {
              final doc = lowStockItems[index];
              final product = doc.data() as Map<String, dynamic>;
              return _AiDecisionCard(
                sku: doc.id,
                product: product,
                canSeeCost: canSeeCost,
                onTabRedirect: onTabRedirect,
              );
            },
          );
        },
      ),
    );
  }
}

class _AiDecisionCard extends StatefulWidget {
  final String sku;
  final Map<String, dynamic> product;
  final bool canSeeCost;
  final VoidCallback? onTabRedirect;

  const _AiDecisionCard({
    required this.sku,
    required this.product,
    required this.canSeeCost,
    required this.onTabRedirect,
  });

  @override
  State<_AiDecisionCard> createState() => _AiDecisionCardState();
}

class _AiDecisionCardState extends State<_AiDecisionCard> {
  late final Future<DecisionResult> _decisionFuture = _computeDecision();

  Future<DecisionResult> _computeDecision() async {
    Map<String, dynamic>? restrictedData;
    if (widget.canSeeCost) {
      // Sourced from the same getSupplierRanking ranking that powers the
      // Sourcing page's "Compare Suppliers" table, so both surfaces always
      // agree on which vendor is the top pick.
      try {
        final result = await SupplierService.getSupplierRanking(widget.sku);
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
    }
    return OperationsAI.calculateOptimalRoute(widget.product,
        restrictedData: restrictedData);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DecisionResult>(
      future: _decisionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF009473)))),
          );
        }
        return _buildIntelligentAlertCard(
            context, widget.product, snapshot.data!);
      },
    );
  }

  Widget _buildIntelligentAlertCard(BuildContext context,
      Map<String, dynamic> product, DecisionResult decision) {
    final bool isTransfer = decision.recommendedAction == 'TRANSFER';
    final bool isEscalate = decision.recommendedAction == 'ESCALATE';
    final Color themeColor = isTransfer
        ? const Color(0xFF009473)
        : isEscalate
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);
    final Color bgColor = isTransfer
        ? const Color(0xFFF0FDF4)
        : isEscalate
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFEFF6FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_rounded,
                      color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] ?? 'Unknown Item',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B))),
                      Text(
                          'Stock: ${product['quantity']} / Minimum: ${product['threshold'] ?? 0}',
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: bgColor,
                border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                    bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: themeColor, size: 18),
                    const SizedBox(width: 8),
                    Text('WISE AI RECOMMENDATION',
                        style: TextStyle(
                            color: themeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isEscalate
                      ? 'ESCALATE TO MANAGER'
                      : '${decision.recommendedAction} FROM ${decision.targetName.toUpperCase()}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: themeColor),
                ),
                const SizedBox(height: 4),
                Text(decision.reasoning,
                    style: const TextStyle(
                        color: Color(0xFF475569), fontSize: 13, height: 1.4)),
                if (isTransfer) ...[
                  const SizedBox(height: 12),
                  RelocationPathIndicator(
                    fromHub: decision.targetName,
                    toHub: _lowestStockHub(product),
                    color: themeColor,
                  ),
                ],
                if (!isEscalate) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMetricChip(
                          Icons.payments_rounded,
                          '\$${decision.estimatedCost.toStringAsFixed(2)} Total',
                          themeColor),
                      const SizedBox(width: 12),
                      _buildMetricChip(Icons.local_shipping_rounded,
                          '${decision.leadTimeDays} Day ETA', themeColor),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Ignore',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEscalate
                          ? 'Flagged for manager review.'
                          : 'Executing ${decision.recommendedAction}...'),
                    ));
                    if (widget.onTabRedirect != null) {
                      widget.onTabRedirect!();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    isEscalate
                        ? 'Flag for Manager'
                        : 'Approve ${decision.recommendedAction}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _lowestStockHub(Map<String, dynamic> product) {
    final cityStock =
        Map<String, dynamic>.from(product['cityStock'] as Map? ?? {});
    String worst = kHubs.first;
    int worstStock = 1 << 30;
    for (final hub in kHubs) {
      final stock = (cityStock[hub] as num?)?.toInt() ?? 0;
      if (stock < worstStock) {
        worstStock = stock;
        worst = hub;
      }
    }
    return worst;
  }

  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
