import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/guest_entity.dart';
import '../../domain/message_templates.dart';
import '../widgets/app_feedback.dart';
import 'call_return_watcher.dart';

/// Opens the dialer or WhatsApp for a guest.
abstract class ContactLauncher {
  static Future<void> call(GuestEntity guest) =>
      _open(guest.telUrl, 'Could not start a call to ${guest.phone}.', guestId: guest.id);

  static Future<void> whatsApp(GuestEntity guest) =>
      _open(guest.whatsAppUrl, 'Could not open WhatsApp for ${guest.phone}.', guestId: guest.id);

  /// WhatsApp with a message already typed.
  static Future<void> whatsAppMessage(GuestEntity guest, String text) => _open(
      MessageTemplates.whatsAppLink(guest, text), 'Could not open WhatsApp for ${guest.phone}.',
      guestId: guest.id);

  /// Long-press on a number: copy it and say so.
  static Future<void> copyPhone(GuestEntity guest) async {
    if (guest.phone.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: guest.phone.trim()));
    AppFeedback.success('Number copied', '${guest.phone.trim()} is ready to paste.');
  }

  /// Opens [url]. With [guestId], coming back to the app afterwards asks
  /// "How did the call go?" (CallReturnWatcher).
  static Future<void> _open(String url, String failure, {String? guestId}) async {
    final uri = Uri.parse(url);
    // Before launching: the app can be hidden while launchUrl is still running.
    if (guestId != null) CallReturnWatcher.instance.launched(guestId);
    final opened = await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      if (guestId != null) CallReturnWatcher.instance.cancel();
      AppFeedback.error('Not available', failure);
    }
  }
}
