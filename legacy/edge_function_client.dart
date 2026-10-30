import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_result.dart';
import 'supabase_service.dart';

/// Thin wrapper around Supabase Edge Function invocation.
///
/// Supabase's public anon key only transports the request. Privileged
/// functions receive a Firebase ID token in their body and verify it with
/// Firebase Admin before trusting the caller. The app never asserts its own
/// role or authority.
class EdgeFunctionClient {
  final SupabaseService _supabaseService;

  EdgeFunctionClient({SupabaseService? supabaseService})
    : _supabaseService = supabaseService ?? SupabaseService();

  Future<Result<Map<String, dynamic>>> invoke(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _supabaseService.client.functions.invoke(
        functionName,
        body: body,
      );

      final status = response.status;
      final data = response.data;

      if (status >= 200 && status < 300) {
        return Result.success(
          data is Map<String, dynamic> ? data : <String, dynamic>{},
        );
      }

      final message = (data is Map && data['error'] is String)
          ? data['error'] as String
          : 'Request failed ($status)';

      return Result.failure(AppFailure(_failureTypeFor(status), message));
    } on FunctionException catch (e) {
      return Result.failure(
        AppFailure(
          _failureTypeFor(e.status),
          e.details?.toString() ?? 'Edge function error',
        ),
      );
    } catch (_) {
      return Result.failure(AppFailure.unknown());
    }
  }

  FailureType _failureTypeFor(int status) {
    switch (status) {
      case 401:
        return FailureType.unauthorized;
      case 403:
        return FailureType.forbidden;
      case 404:
        return FailureType.notFound;
      case 400:
      case 422:
        return FailureType.validation;
      default:
        return status >= 500 ? FailureType.server : FailureType.unknown;
    }
  }
}
