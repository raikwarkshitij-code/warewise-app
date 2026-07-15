import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper around the transfer-related Cloud Functions
/// (functions/index.js). All stock-mutating writes to `products`/`transfers`
/// must go through these — firestore.rules blocks direct client writes.
class TransferService {
  static final _functions = FirebaseFunctions.instance;

  static Future<void> approveAndShip(String transferId) =>
      _call('approveAndShipTransfer', {'transferId': transferId});

  static Future<void> confirmDelivery(String transferId) =>
      _call('confirmDelivery', {'transferId': transferId});

  static Future<void> reject(String transferId) =>
      _call('rejectTransfer', {'transferId': transferId});

  static Future<void> _call(String name, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(name).call(data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Request failed (${e.code}).');
    }
  }
}
