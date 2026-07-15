import 'package:cloud_functions/cloud_functions.dart';

/// Business-priority strategy for ranking/recommending suppliers. Changes
/// which factor `getSupplierRanking` optimizes for — see functions/index.js
/// `computeStrategyScore` for the exact formula per strategy.
enum SourcingStrategy {
  cost('cost', 'Cost-Focused'),
  reliability('reliability', 'Reliability-Focused'),
  balanced('balanced', 'Balanced');

  final String apiValue;
  final String label;

  const SourcingStrategy(this.apiValue, this.label);

  static SourcingStrategy fromApiValue(String? value) {
    return SourcingStrategy.values.firstWhere(
      (s) => s.apiValue == value,
      orElse: () => SourcingStrategy.balanced,
    );
  }
}

class SupplierRanking {
  final String supplierId;
  final String supplierName;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final double unitCost;
  final int leadTimeDays;
  final int moq;
  final int eventCount;
  final double? onTimeRate;
  final double? avgQualityScore;
  final double? avgPriceVariancePercent;

  /// Fixed 40/40/20 weighted score — the same regardless of selected
  /// strategy, so it's always directly comparable across strategy switches.
  final double? vendorScore;

  /// Strategy-relative fit score that drives sort order and the
  /// "Recommended for X" badge. Meaning depends on the strategy the ranking
  /// was fetched with (see [SourcingStrategy]).
  final double? strategyScore;

  /// Plain-language explanation of this supplier's rank under the current
  /// strategy, e.g. "Chosen for reliability: 99% on-time delivery...".
  final String rationale;

  SupplierRanking({
    required this.supplierId,
    required this.supplierName,
    this.contactPerson,
    this.email,
    this.phone,
    required this.unitCost,
    required this.leadTimeDays,
    required this.moq,
    required this.eventCount,
    this.onTimeRate,
    this.avgQualityScore,
    this.avgPriceVariancePercent,
    this.vendorScore,
    this.strategyScore,
    required this.rationale,
  });

  bool get hasHistory => eventCount > 0;

  factory SupplierRanking.fromMap(Map<String, dynamic> map) {
    return SupplierRanking(
      supplierId: map['supplierId'] as String,
      supplierName: map['supplierName'] as String? ?? 'Unknown Supplier',
      contactPerson: map['contactPerson'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
      leadTimeDays: (map['leadTimeDays'] as num?)?.toInt() ?? 0,
      moq: (map['moq'] as num?)?.toInt() ?? 0,
      eventCount: (map['eventCount'] as num?)?.toInt() ?? 0,
      onTimeRate: (map['onTimeRate'] as num?)?.toDouble(),
      avgQualityScore: (map['avgQualityScore'] as num?)?.toDouble(),
      avgPriceVariancePercent:
          (map['avgPriceVariancePercent'] as num?)?.toDouble(),
      vendorScore: (map['vendorScore'] as num?)?.toDouble(),
      strategyScore: (map['strategyScore'] as num?)?.toDouble(),
      rationale: map['rationale'] as String? ?? '',
    );
  }
}

class SupplierRankingResult {
  final List<SupplierRanking> suppliers;
  final SourcingStrategy strategy;
  final String strategyLabel;

  SupplierRankingResult({
    required this.suppliers,
    required this.strategy,
    required this.strategyLabel,
  });

  /// The recommended pick under this strategy — first in rank order with a
  /// non-null strategyScore (suppliers that can't be scored under the
  /// current strategy, e.g. no history for 'reliability', sort last and are
  /// never the recommendation).
  SupplierRanking? get recommended {
    for (final s in suppliers) {
      if (s.strategyScore != null) return s;
    }
    return null;
  }
}

/// Wraps the getSupplierRanking / raisePurchaseOrder Cloud Functions
/// (functions/index.js) backing the manager decision matrix.
class SupplierService {
  static Future<SupplierRankingResult> getSupplierRanking(
    String productId, {
    SourcingStrategy strategy = SourcingStrategy.balanced,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSupplierRanking')
          .call({'productId': productId, 'strategy': strategy.apiValue});
      final suppliers = (result.data['suppliers'] as List<dynamic>? ?? [])
          .map((s) =>
              SupplierRanking.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();
      final resolvedStrategy =
          SourcingStrategy.fromApiValue(result.data['strategy'] as String?);
      final strategyLabel =
          result.data['strategyLabel'] as String? ?? resolvedStrategy.label;
      return SupplierRankingResult(
        suppliers: suppliers,
        strategy: resolvedStrategy,
        strategyLabel: strategyLabel,
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Request failed (${e.code}).');
    }
  }

  static Future<String> raisePurchaseOrder({
    required String productId,
    required String supplierId,
    required int quantity,
    required String destinationHub,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('raisePurchaseOrder')
          .call({
        'productId': productId,
        'supplierId': supplierId,
        'quantity': quantity,
        'destinationHub': destinationHub,
      });
      return result.data['poId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Request failed (${e.code}).');
    }
  }
}
