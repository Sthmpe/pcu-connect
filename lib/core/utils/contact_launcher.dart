import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/guest_entity.dart';
import '../widgets/app_feedback.dart';

/// Opens the dialer or WhatsApp for a guest.
abstract class ContactLauncher {
  static Future<void> call(GuestEntity guest) =>
      _open(guest.telUrl, 'Could not start a call to ${guest.phone}.');

  static Future<void> whatsApp(GuestEntity guest) =>
      _open(guest.whatsAppUrl, 'Could not open WhatsApp for ${guest.phone}.');

  static Future<void> _open(String url, String failure) async {
    final uri = Uri.parse(url);
    final opened = await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) AppFeedback.error('Not available', failure);
  }
}
