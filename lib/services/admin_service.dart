import 'package:cloud_functions/cloud_functions.dart';

/// Wraps the owner-only setUserRole Cloud Function (functions/index.js).
class AdminService {
  static Future<void> setUserRole(String uid, String role) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setUserRole')
          .call({'uid': uid, 'role': role});
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Request failed (${e.code}).');
    }
  }
}
