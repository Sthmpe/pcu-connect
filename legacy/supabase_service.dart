import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase is used ONLY for:
///  - Edge Functions (Google Sheets intake, fair assignment writes to Firestore)
///  - Storage (guest/media file uploads, if any)
///
/// Firebase (FirebaseService) is the source of truth for all app data and
/// authentication. This client never reads/writes app data directly.
///
/// Only the PUBLIC anon key is read here - safe to ship because it grants
/// no privileged access on its own. The service-role key must never appear
/// in this codebase; it lives only in Supabase Edge Function secrets.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Copy .env.example to .env '
        'and fill in your project values before running the app.',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  SupabaseClient get client => Supabase.instance.client;

  SupabaseStorageClient get storage => client.storage;

  FunctionsClient get functions => client.functions;
}
