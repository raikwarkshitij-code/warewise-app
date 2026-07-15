import 'package:flutter/material.dart';
import '../services/supplier_service.dart';

/// Manager-facing supplier comparison table. Shows the AI-computed Vendor
/// Score and track record for every eligible supplier, and — driven by a
/// selectable business-priority strategy — actively recommends one. It
/// still never picks one automatically: raising a PO always requires an
/// explicit tap + confirm from a manager/owner (human-in-the-loop), even
/// when using "Execute AI Strategy" to pre-fill that confirmation.
class SupplierDecisionMatrix extends StatefulWidget {
  final String productSku;
  final String productName;
  final int defaultQuantity;
  final String destinationHub;

  /// Optional pre-started ranking fetch (Balanced strategy) to reuse for the
  /// initial render, so this table and any sibling recommendation banner
  /// read the exact same first result instead of two independent calls that
  /// could theoretically race/differ. Switching strategy inside this widget
  /// always triggers its own fresh fetch after that.
  final Future<SupplierRankingResult>? rankingFuture;

  const SupplierDecisionMatrix({
    super.key,
    required this.productSku,
    required this.productName,
    required this.defaultQuantity,
    required this.destinationHub,
    this.rankingFuture,
  });

  @override
  State<SupplierDecisionMatrix> createState() => _SupplierDecisionMatrixState();
}

class _SupplierDecisionMatrixState extends State<SupplierDecisionMatrix> {
  SourcingStrategy _strategy = SourcingStrategy.balanced;
  late Future<SupplierRankingResult> _currentFuture = widget.rankingFuture ??
      SupplierService.getSupplierRanking(widget.productSku,
          strategy: _strategy);
  bool _isRaising = false;

  void _changeStrategy(SourcingStrategy strategy) {
    if (strategy == _strategy) return;
    setState(() {
      _strategy = strategy;
      _currentFuture = SupplierService.getSupplierRanking(widget.productSku,
          strategy: strategy);
    });
  }

  Future<void> _confirmAndRaisePo(SupplierRanking supplier,
      {String? rationale}) async {
    final qtyController =
        TextEditingController(text: widget.defaultQuantity.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Authorize PO — ${supplier.supplierName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Unit cost: \$${supplier.unitCost.toStringAsFixed(2)} · Lead time: ${supplier.leadTimeDays} days · Ships to: ${widget.destinationHub}',
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
            if (rationale != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(rationale,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF01604B), height: 1.3)),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
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
            child: const Text('Authorize & Raise PO'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final quantity = int.tryParse(qtyController.text) ?? widget.defaultQuantity;
    if (quantity <= 0) return;

    setState(() => _isRaising = true);
    try {
      final poId = await SupplierService.raisePurchaseOrder(
        productId: widget.productSku,
        supplierId: supplier.supplierId,
        quantity: quantity,
        destinationHub: widget.destinationHub,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'PO raised with ${supplier.supplierName} (#${poId.substring(0, 6).toUpperCase()}).'),
            backgroundColor: const Color(0xFF009473),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRaising = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StrategySelector(selected: _strategy, onChanged: _changeStrategy),
        const SizedBox(height: 16),
        FutureBuilder<SupplierRankingResult>(
          future: _currentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF009473))),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'Could not load supplier ranking: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }
            final result = snapshot.data;
            final suppliers = result?.suppliers ?? [];
            if (suppliers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No suppliers are registered for this product yet.',
                    style: TextStyle(color: Colors.grey)),
              );
            }

            final recommended = result!.recommended;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recommended != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF01604B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isRaising
                            ? null
                            : () => _confirmAndRaisePo(recommended,
                                rationale: recommended.rationale),
                        icon: const Icon(Icons.bolt_rounded),
                        label: Text(
                            'Execute AI Strategy (${result.strategyLabel})',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                for (int i = 0; i < suppliers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SupplierCard(
                      supplier: suppliers[i],
                      isRecommended: recommended != null &&
                          suppliers[i].supplierId == recommended.supplierId,
                      strategyLabel: result.strategyLabel,
                      isBusy: _isRaising,
                      onSelect: () => _confirmAndRaisePo(suppliers[i],
                          rationale: suppliers[i].rationale),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StrategySelector extends StatelessWidget {
  final SourcingStrategy selected;
  final ValueChanged<SourcingStrategy> onChanged;

  const _StrategySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SourcingStrategy.values.map((strategy) {
        final isSelected = strategy == selected;
        return ChoiceChip(
          label: Text(strategy.label),
          selected: isSelected,
          onSelected: (_) => onChanged(strategy),
          selectedColor: const Color(0xFF009473),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          side: BorderSide(
              color: isSelected
                  ? const Color(0xFF009473)
                  : const Color(0xFFCBD5E1)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        );
      }).toList(),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierRanking supplier;
  final bool isRecommended;
  final String strategyLabel;
  final bool isBusy;
  final VoidCallback onSelect;

  const _SupplierCard({
    required this.supplier,
    required this.isRecommended,
    required this.strategyLabel,
    required this.isBusy,
    required this.onSelect,
  });

  Color _scoreColor(double score) {
    if (score >= 80) return const Color(0xFF16A34A);
    if (score >= 60) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final score = supplier.vendorScore;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isRecommended
                ? const Color(0xFF009473)
                : const Color(0xFFE2E8F0),
            width: isRecommended ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(supplier.supplierName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4F1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('Recommended for $strategyLabel',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF01604B))),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: supplier.rationale,
                            triggerMode: TooltipTriggerMode.tap,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: const TextStyle(
                                fontSize: 12, color: Colors.white),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.info_outline_rounded,
                                size: 16, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                    if (supplier.contactPerson != null)
                      Text(supplier.contactPerson!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (score != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(score.toStringAsFixed(0),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _scoreColor(score))),
                    Text('VENDOR SCORE',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _scoreColor(score))),
                  ],
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('No track record',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(supplier.rationale,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip(Icons.attach_money_rounded,
                  '\$${supplier.unitCost.toStringAsFixed(2)}/unit'),
              _statChip(Icons.local_shipping_outlined,
                  '${supplier.leadTimeDays}d lead time'),
              _statChip(Icons.inventory_2_outlined, 'MOQ ${supplier.moq}'),
              if (supplier.hasHistory) ...[
                _statChip(Icons.timer_outlined,
                    '${(supplier.onTimeRate! * 100).toStringAsFixed(0)}% on-time'),
                _statChip(Icons.verified_outlined,
                    'Quality ${supplier.avgQualityScore!.toStringAsFixed(0)}/100'),
                _statChip(Icons.trending_flat_rounded,
                    '${supplier.avgPriceVariancePercent! >= 0 ? '+' : ''}${supplier.avgPriceVariancePercent!.toStringAsFixed(1)}% price var.'),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF009473),
                side: const BorderSide(color: Color(0xFF009473)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isBusy ? null : onSelect,
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
              label: const Text('Select & Authorize PO'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
