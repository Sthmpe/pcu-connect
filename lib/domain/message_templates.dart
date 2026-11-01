import '../core/utils/lagos_time.dart';
import 'entities/guest_entity.dart';

/// One WhatsApp message the worker can send a guest.
class MessageTemplate {
  final String id;
  final String label;
  final String text;
  const MessageTemplate({required this.id, required this.label, required this.text});
}

/// WhatsApp templates (config/messageTemplates in Firestore, editable by the
/// HOD). Placeholders: {title} (sis or bro from gender, left out when gender
/// is missing), {name}, {worker} and {service}.
abstract class MessageTemplates {
  /// The messages a worker sends a guest.
  static const ids = ['thanks', 'missedCall', 'checkIn'];

  /// The HOD's WhatsApp nudge to a worker. Placeholders: {worker} (first
  /// name), {n} (guests waiting) and {oldest} (the longest wait, "9 days").
  static const nudgeId = 'nudge';

  /// Every template in config/messageTemplates.
  static const allIds = [...ids, nudgeId];

  static const labels = {
    'thanks': 'Thank you for coming',
    'missedCall': 'After a missed call',
    'checkIn': 'Checking in',
    'nudge': 'Nudge a worker',
  };

  /// Used until the HOD saves their own wording.
  static const defaults = {
    'thanks': "Dear {title} {name}, I'm reaching out to you from Pastor Ayo. He asked me to send you his love and "
        'to thank you for coming. How was the service, and how was your experience? We love and celebrate you. '
        '{worker}, COZA Ilorin',
    'missedCall': 'Dear {title} {name}, I tried calling you earlier but could not reach you, so I decided to message '
        'you. Pastor Ayo sends his love and thanks you for worshipping with us. How was the service, and how was your '
        'experience? We love and celebrate you. {worker}, COZA Ilorin',
    'checkIn': 'Dear {title} {name}, this is {worker} from COZA Ilorin. We have been thinking of you since {service}. '
        'How have you been, and can we expect you this Sunday? We love and celebrate you.',
    'nudge': 'Hello {worker}, you have {n} guests waiting for a call. A quick call today makes a big difference. '
        'We are cheering you on.',
  };

  static const placeholders = ['{title}', '{name}', '{worker}', '{service}'];

  static const maxLength = 1000;

  /// The templates from the config document; a missing or blank one falls back to its default.
  static List<MessageTemplate> from(Map<String, dynamic>? data) => [
        for (final id in allIds)
          MessageTemplate(
            id: id,
            label: labels[id]!,
            text: _text(data?[id]) ?? defaults[id]!,
          ),
      ];

  static List<MessageTemplate> get defaultList => from(null);

  static String? _text(Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? null : s;
  }

  /// The guest messages only (what a worker chooses from).
  static List<MessageTemplate> forGuests(List<MessageTemplate> all) => all.where((t) => ids.contains(t.id)).toList();

  /// The nudge template from [all] (its default when missing).
  static String nudgeText(List<MessageTemplate> all) =>
      all.firstWhere((t) => t.id == nudgeId, orElse: () => from(null).last).text;

  /// The nudge filled in: {worker} the worker's first name, {n} the guests
  /// waiting, {oldest} the longest wait ("9 days").
  static String fillNudge(String text, {required String workerName, required int waiting, required int oldestDays}) {
    final first = workerName.trim().replaceFirst(RegExp(r'^TEST\s+'), '').split(RegExp(r'\s+')).first;
    return text
        .replaceAll('{worker}', first)
        .replaceAll('{n}', '$waiting')
        .replaceAll('{oldest}', '$oldestDays ${oldestDays == 1 ? 'day' : 'days'}')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  /// 'sis' for a female guest, 'bro' for a male guest, '' when unknown.
  static String titleFor(String gender) => switch (gender.trim().toLowerCase()) {
        'female' => 'sis',
        'male' => 'bro',
        _ => '',
      };

  /// [text] with the placeholders filled. Without a title, "{title} " is left
  /// out so "Dear {title} {name}" reads "Dear Ada".
  static String fill(String text, {required String gender, required String name, required String worker, required String service}) {
    final title = titleFor(gender);
    var out = title.isEmpty ? text.replaceAll(RegExp(r'\{title\} ?'), '') : text.replaceAll('{title}', title);
    out = out.replaceAll('{name}', name).replaceAll('{worker}', worker).replaceAll('{service}', service);
    return out.replaceAll(RegExp(r'[ \t]{2,}'), ' ').replaceAllMapped(RegExp(r' +([,.?!])'), (m) => m[1]!).trim();
  }

  /// [text] filled for [guest], sent by [workerName]. {name} is the guest's
  /// first name and {service} their first visit, e.g. "Sunday 25 October".
  static String forGuest(String text, GuestEntity guest, {required String workerName, DateTime? clock}) => fill(
        text,
        gender: guest.gender,
        name: guest.name.trim().split(RegExp(r'\s+')).first,
        worker: workerName.trim(),
        service: LagosTime.fullDate(guest.serviceDate, clock: clock),
      );

  /// wa.me link for [guest] with [text] typed in, correctly encoded.
  static String whatsAppLink(GuestEntity guest, String text) =>
      '${guest.whatsAppUrl}?text=${Uri.encodeComponent(text)}';
}
