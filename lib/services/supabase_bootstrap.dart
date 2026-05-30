import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static const String _defaultSupabaseUrl =
      'https://waewrivhfwxqemdjmlpz.supabase.co';
  static const String _defaultSupabasePublishableKey =
      'sb_publishable_ERsb30EjqLGAHfjp9owkcA_xscOD1vR';

  static const String _defineSupabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _defineSupabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _defineSupabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static String get _supabaseUrl =>
      _defineSupabaseUrl.isNotEmpty ? _defineSupabaseUrl : _defaultSupabaseUrl;

  static String get _supabaseAnonKey {
    if (_defineSupabaseAnonKey.isNotEmpty) {
      return _defineSupabaseAnonKey;
    }
    if (_defineSupabasePublishableKey.isNotEmpty) {
      return _defineSupabasePublishableKey;
    }
    return _defaultSupabasePublishableKey;
  }

  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!isConfigured) {
      if (kDebugMode) {
        debugPrint(
          'Supabase is not configured yet. Set --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... (or SUPABASE_PUBLISHABLE_KEY=...).',
        );
      }
      return;
    }

    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    _initialized = true;

    final SupabaseClient client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      try {
        await client.auth.signInAnonymously();
      } on AuthException catch (error) {
        if (kDebugMode) {
          debugPrint('Supabase anonymous sign-in failed: ${error.message}');
        }
      }
    }
  }

  static SupabaseClient? get client =>
      (isConfigured && _initialized) ? Supabase.instance.client : null;
}
