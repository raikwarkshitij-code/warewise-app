import 'package:cloud_functions/cloud_functions.dart';
import 'firestore.dart';

/// Wraps the adminUpsertProduct Cloud Function (functions/index.js) — the
/// only legal write path for `products/{sku}` and its `restricted/cost`
/// subdoc, since firestore.rules blocks direct client writes to both.
class ProductService {
  static Future<void> upsertProduct(Map<String, dynamic> payload) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('adminUpsertProduct')
          .call(payload);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Request failed (${e.code}).');
    }
  }

  static Future<Map<String, dynamic>?> fetchRestrictedCost(String sku) async {
    final snap = await db
        .collection('products')
        .doc(sku)
        .collection('restricted')
        .doc('cost')
        .get();
    return snap.data();
  }
}
