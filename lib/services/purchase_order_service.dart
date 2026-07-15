import 'package:cloud_functions/cloud_functions.dart';

/// Wraps the confirmGoodsReceipt Cloud Function (functions/index.js) — the
/// only path that increases stock for a purchase order. Raising a PO never
/// touches inventory on its own.
class PurchaseOrderService {
  static Future<void> confirmGoodsReceipt(
    String poId, {
    int? qualityScore,
    double? priceVariancePercent,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('confirmGoodsReceipt')
          .call({
        'poId': poId,
        if (qualityScore != null) 'qualityScore': qualityScore,
        if (priceVariancePercent != null)
          'priceVariancePercent': priceVariancePercent,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Request failed (${e.code}).');
    }
  }
}
