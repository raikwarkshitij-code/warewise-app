import 'lane_metrics.dart';

/// The three-hub network. Kept as a single source of truth so relocation
/// logic, product editing, and the upload script all agree on hub names.
const List<String> kHubs = ['Berlin', 'Munich', 'Hamburg'];

class DecisionResult {
  /// 'TRANSFER' | 'PURCHASE' | 'ESCALATE' | 'OPTIMAL'
  final String recommendedAction;
  final String targetName;
  final double estimatedCost;
  final int leadTimeDays;
  final String reasoning;

  /// The hub identified as short of stock — where a TRANSFER or PURCHASE
  /// should ultimately deliver units. Always set, even for OPTIMAL/ESCALATE.
  final String shortageHub;

  /// Units needed to bring [shortageHub] back up to threshold. 0 if already
  /// at/above threshold.
  final int unitsNeeded;

  DecisionResult({
    required this.recommendedAction,
    required this.targetName,
    required this.estimatedCost,
    required this.leadTimeDays,
    required this.reasoning,
    required this.shortageHub,
    required this.unitsNeeded,
  });
}

/// Deterministic, rule-based relocation/reorder engine. No network calls —
/// callers own fetching `cityStock` (public) and `restricted/cost` (role
/// gated) and pass both in here.
class OperationsAI {
  static int _stockOf(Map<String, dynamic> cityStock, String hub) {
    final value = cityStock[hub];
    if (value is num) return value.toInt();
    return 0;
  }

  /// Picks the hub furthest below its threshold as the shortage location,
  /// unless [homeHub] is explicitly given (e.g. the hub the alert fired for).
  static String _shortageHub(Map<String, dynamic> cityStock, int threshold,
      {String? homeHub}) {
    if (homeHub != null) return homeHub;
    String worst = kHubs.first;
    int worstDeficit = -1 << 30;
    for (final hub in kHubs) {
      final deficit = threshold - _stockOf(cityStock, hub);
      if (deficit > worstDeficit) {
        worstDeficit = deficit;
        worst = hub;
      }
    }
    return worst;
  }

  /// [restrictedData] should only be passed when the caller has confirmed the
  /// current user's role permits reading `products/{sku}/restricted/cost`
  /// (manager/finance/owner) — passing null for other roles is what drives
  /// associates toward the ESCALATE branch instead of a cost-bearing PURCHASE
  /// recommendation.
  static DecisionResult calculateOptimalRoute(
    Map<String, dynamic> product, {
    String? homeHub,
    Map<String, dynamic>? restrictedData,
  }) {
    final cityStock =
        Map<String, dynamic>.from(product['cityStock'] as Map? ?? {});
    final threshold = (product['threshold'] as num?)?.toInt() ?? 0;
    final shortageHub = _shortageHub(cityStock, threshold, homeHub: homeHub);
    final currentQty = _stockOf(cityStock, shortageHub);
    final unitsNeeded = threshold - currentQty;

    if (unitsNeeded <= 0) {
      return DecisionResult(
        recommendedAction: 'OPTIMAL',
        targetName: shortageHub,
        estimatedCost: 0,
        leadTimeDays: 0,
        reasoning: '$shortageHub is stocked at or above threshold.',
        shortageHub: shortageHub,
        unitsNeeded: 0,
      );
    }

    // Look across the other hubs for enough surplus to cover the shortfall.
    String? bestHub;
    double bestTransferCost = double.infinity;
    int bestTransferLeadTime = 0;
    for (final hub in kHubs) {
      if (hub == shortageHub) continue;
      final surplus = _stockOf(cityStock, hub) - threshold;
      if (surplus < unitsNeeded) continue;

      final lane = LaneMetricsService.forRoute(hub, shortageHub);
      final cost = unitsNeeded * lane.costPerUnit;
      if (cost < bestTransferCost) {
        bestTransferCost = cost;
        bestTransferLeadTime = lane.leadTimeDays;
        bestHub = hub;
      }
    }

    if (restrictedData != null) {
      final costPerUnit =
          (restrictedData['costPerUnit'] as num?)?.toDouble() ?? 0;
      final purchaseCost = unitsNeeded * costPerUnit;
      final purchaseLeadTime =
          (restrictedData['leadTimeDays'] as num?)?.toInt() ?? 0;
      final supplierName =
          restrictedData['supplierName'] as String? ?? 'Supplier';

      if (bestHub != null && bestTransferCost <= purchaseCost) {
        final savings = purchaseCost - bestTransferCost;
        return DecisionResult(
          recommendedAction: 'TRANSFER',
          targetName: bestHub,
          estimatedCost: bestTransferCost,
          leadTimeDays: bestTransferLeadTime,
          reasoning:
              'Transfer from $bestHub saves \$${savings.toStringAsFixed(2)} versus reordering from $supplierName.',
          shortageHub: shortageHub,
          unitsNeeded: unitsNeeded,
        );
      }

      return DecisionResult(
        recommendedAction: 'PURCHASE',
        targetName: supplierName,
        estimatedCost: purchaseCost,
        leadTimeDays: purchaseLeadTime,
        reasoning: bestHub == null
            ? 'No hub has surplus stock — reorder from $supplierName is the only option.'
            : 'Reordering from $supplierName is cheaper than transferring from $bestHub.',
        shortageHub: shortageHub,
        unitsNeeded: unitsNeeded,
      );
    }

    if (bestHub != null) {
      return DecisionResult(
        recommendedAction: 'TRANSFER',
        targetName: bestHub,
        estimatedCost: bestTransferCost,
        leadTimeDays: bestTransferLeadTime,
        reasoning: '$bestHub has surplus stock covering the shortfall.',
        shortageHub: shortageHub,
        unitsNeeded: unitsNeeded,
      );
    }

    return DecisionResult(
      recommendedAction: 'ESCALATE',
      targetName: 'Manager',
      estimatedCost: 0,
      leadTimeDays: 0,
      reasoning:
          'All hubs are below threshold and supplier pricing isn\'t visible at your access level — flag this for a manager to reorder.',
      shortageHub: shortageHub,
      unitsNeeded: unitsNeeded,
    );
  }
}
