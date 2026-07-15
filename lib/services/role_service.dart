import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Reads the caller's role from their Firebase Auth custom claims
/// (`request.auth.token.role` in firestore.rules / functions/index.js) and
/// exposes it as listenable app state. Roles are assigned server-side by the
/// `setUserRole` Cloud Function; this service only reads them.
class RoleService extends ChangeNotifier {
  static const List<String> knownRoles = [
    'associate',
    'manager',
    'finance',
    'owner'
  ];

  String? _role;
  bool _isLoading = true;

  RoleService() {
    FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  String? get role => _role;
  bool get isLoading => _isLoading;

  bool get isAssociate => _role == 'associate';
  bool get isManager => _role == 'manager';
  bool get isFinance => _role == 'finance';
  bool get isOwner => _role == 'owner';

  bool hasAnyRole(List<String> roles) => _role != null && roles.contains(_role);

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _role = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    await refresh();
  }

  /// Force-refreshes the ID token so a just-changed role (via setUserRole)
  /// is picked up immediately instead of waiting for the cached token to expire.
  Future<void> refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _role = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final tokenResult = await user.getIdTokenResult(true);
    _role = tokenResult.claims?['role'] as String?;
    _isLoading = false;
    notifyListeners();
  }
}
