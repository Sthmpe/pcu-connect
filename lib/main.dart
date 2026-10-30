import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/supabase_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Supabase is only for Edge Functions + Storage - see supabase_service.dart.
  await SupabaseService.init();
  runApp(const PCUWorkflowApp());
}
