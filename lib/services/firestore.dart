import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared Firestore accessor — the default ("(default)") database, in
/// Native mode. Use `db` everywhere instead of calling
/// `FirebaseFirestore.instance` directly, so there's one place to change if
/// the target database ever needs to change again.
final FirebaseFirestore db = FirebaseFirestore.instance;
