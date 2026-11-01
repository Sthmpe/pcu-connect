import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../domain/repositories/i_auth_repository.dart';

enum PushPermission { unsupported, notAsked, granted, denied }

/// A push that arrived while the app was open.
class ForegroundPush {
  final String title;
  final String body;
  const ForegroundPush(this.title, this.body);
}

abstract class IPushService {
  Future<PushPermission> permission();

  /// Asks the browser for permission and saves this device's token.
  Future<PushPermission> enable();

  /// Saves the current token again when permission was given before.
  Future<void> refresh();

  Stream<ForegroundPush> get foreground;
}

/// Firebase Cloud Messaging web push. The device token is kept at
/// users/{email}/tokens/{token} so Apps Script can send to every device.
class PushService implements IPushService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final IAuthRepository _auth;
  StreamSubscription<String>? _refreshSub;

  PushService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore db,
    required IAuthRepository authRepository,
  })  : _messaging = messaging,
        _db = db,
        _auth = authRepository;

  String get _email => (_auth.currentUser?.email ?? '').trim().toLowerCase();

  Future<bool> _supported() async {
    if (!kIsWeb || _email.isEmpty) return false;
    try {
      return await _messaging.isSupported();
    } catch (_) {
      return false;
    }
  }

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notAsked,
      };

  @override
  Future<PushPermission> permission() async {
    if (!await _supported()) return PushPermission.unsupported;
    return _map((await _messaging.getNotificationSettings()).authorizationStatus);
  }

  @override
  Future<PushPermission> enable() async {
    if (!await _supported()) return PushPermission.unsupported;
    final result = _map((await _messaging.requestPermission()).authorizationStatus);
    if (result == PushPermission.granted) await _saveToken();
    return result;
  }

  @override
  Future<void> refresh() async {
    if (await permission() != PushPermission.granted) return;
    await _saveToken();
    // ignore: deprecated_member_use
    _refreshSub ??= _messaging.onTokenRefresh.listen((t) => _store(t));
  }

  Future<void> _saveToken() async {
    try {
      // The FCM registration token, which the Apps Script sender targets with
      // the HTTP v1 API (message.token). register()/onRegistered give an
      // installation id for a newer direct-send route that it does not use.
      // ignore: deprecated_member_use
      final token = await _messaging.getToken(vapidKey: AppConfig.fcmVapidKey);
      if (token != null && token.isNotEmpty) await _store(token);
    } catch (e) {
      debugPrint('Push token not saved: $e');
    }
  }

  Future<void> _store(String token) async {
    final ref = _db.collection('users').doc(_email).collection('tokens').doc(token);
    final userAgent = AppConfig.userAgent;
    try {
      await ref.update({'lastSeenAt': FieldValue.serverTimestamp(), 'userAgent': userAgent});
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow;
      await ref.set({
        'token': token,
        'platform': 'web',
        'userAgent': userAgent,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Stream<ForegroundPush> get foreground => FirebaseMessaging.onMessage.map((m) => ForegroundPush(
        m.notification?.title ?? m.data['title']?.toString() ?? 'PCU Connect',
        m.notification?.body ?? m.data['body']?.toString() ?? '',
      ));
}
