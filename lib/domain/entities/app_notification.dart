import 'package:equatable/equatable.dart';

/// One item in the bell list: users/{email}/notifications/{id}, written by
/// Apps Script whenever it tells someone something (with or without a push).
class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;

  /// What it is about, for example 'guest-G-1A2B3C4D', 'daily-reminder' or 'sync-failed'.
  final String tag;
  final DateTime? createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.tag = '',
    this.createdAt,
    this.read = false,
  });

  /// The guest this is about, if any.
  String? get guestId => tag.startsWith('guest-') && tag.length > 6 ? tag.substring(6) : null;

  @override
  List<Object?> get props => [id, title, body, tag, createdAt, read];
}
