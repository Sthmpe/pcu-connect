import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/i_auth_repository.dart';

abstract class INotificationsRepository {
  /// Newest first (the last 50).
  Stream<List<AppNotification>> watch();

  /// Marks every unread notification as read.
  Future<void> markAllRead();
}

/// The signed-in person's notifications at users/{email}/notifications.
class NotificationsRepository implements INotificationsRepository {
  final FirebaseFirestore _db;
  final IAuthRepository _auth;

  NotificationsRepository({required FirebaseFirestore db, required IAuthRepository authRepository})
      : _db = db,
        _auth = authRepository;

  String get _email => (_auth.currentUser?.email ?? '').trim().toLowerCase();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_email).collection('notifications');

  static AppNotification fromDoc(String id, Map<String, dynamic> d) {
    final created = d['createdAt'];
    return AppNotification(
      id: id,
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      tag: (d['tag'] ?? '').toString(),
      createdAt: created is Timestamp ? created.toDate() : (created is DateTime ? created : null),
      read: d['read'] == true,
    );
  }

  @override
  Stream<List<AppNotification>> watch() {
    if (_email.isEmpty) return const Stream.empty();
    return _col
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => fromDoc(d.id, d.data())).toList());
  }

  @override
  Future<void> markAllRead() async {
    if (_email.isEmpty) return;
    final unread = await _col.where('read', isEqualTo: false).limit(200).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true, 'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }
}
