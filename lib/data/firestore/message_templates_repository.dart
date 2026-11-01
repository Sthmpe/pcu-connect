import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_result.dart';
import '../../core/utils/read_errors.dart';
import '../../domain/message_templates.dart';
import '../../domain/repositories/i_auth_repository.dart';

abstract class IMessageTemplatesRepository {
  /// The templates, live. Defaults until the HOD saves their own.
  Stream<List<MessageTemplate>> watch();

  /// True where the HOD can edit them (Firestore mode).
  bool get canEdit;

  /// Saves the wording for every template (admin only).
  Future<ApiResult<void>> save(Map<String, String> texts);
}

/// config/messageTemplates: read by every active user, written by active admins.
class FirestoreMessageTemplatesRepository implements IMessageTemplatesRepository {
  final FirebaseFirestore _db;
  final IAuthRepository _auth;

  FirestoreMessageTemplatesRepository({required FirebaseFirestore db, required IAuthRepository authRepository})
      : _db = db,
        _auth = authRepository;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('config').doc('messageTemplates');

  @override
  bool get canEdit => true;

  @override
  Stream<List<MessageTemplate>> watch() async* {
    yield MessageTemplates.defaultList;
    // Unreadable (offline first run, or rules): the defaults stay.
    yield* _doc.snapshots().map((s) => MessageTemplates.from(s.data())).handleError((Object e) => logReadError('message templates', e));
  }

  @override
  Future<ApiResult<void>> save(Map<String, String> texts) async {
    final data = <String, dynamic>{};
    for (final id in MessageTemplates.allIds) {
      final text = (texts[id] ?? '').trim();
      if (text.isEmpty) return const ApiResult.failure(ValidationFailure('Every message needs some words.'));
      if (text.length > MessageTemplates.maxLength) {
        return const ApiResult.failure(
            ValidationFailure('Each message can be at most ${MessageTemplates.maxLength} characters.'));
      }
      data[id] = text;
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedBy'] = (_auth.currentUser?.email ?? '').trim().toLowerCase();
    try {
      // Offline, the write is kept and synced later; do not wait for the server.
      await _doc.set(data).timeout(const Duration(seconds: 10), onTimeout: () {});
      return const ApiResult.success(null);
    } on FirebaseException catch (e) {
      return ApiResult.failure(e.code == 'permission-denied'
          ? const SecurityFailure('Only an active admin can change the messages.')
          : const ServerFailure('We could not save the messages. Try again.'));
    }
  }
}

/// Apps Script mode: the default wording, not editable.
class DefaultMessageTemplatesRepository implements IMessageTemplatesRepository {
  const DefaultMessageTemplatesRepository();

  @override
  bool get canEdit => false;

  @override
  Stream<List<MessageTemplate>> watch() => Stream.value(MessageTemplates.defaultList);

  @override
  Future<ApiResult<void>> save(Map<String, String> texts) async =>
      const ApiResult.failure(ServerFailure('Editing messages needs the Firestore version of the app.'));
}
