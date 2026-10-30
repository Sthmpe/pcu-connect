import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase is the source of truth: Auth for sessions, Firestore for all
/// contact/assignment/interaction data. Access is enforced by Firestore
/// Security Rules using scoped membership documents - never by anything
/// decided client-side.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  User? get currentUser => auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Stream<User?> get authStateChanges => auth.authStateChanges();
}
