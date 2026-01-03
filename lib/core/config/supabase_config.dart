import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Fallback values in case .env fails to load (these are public anon keys, safe to include)
  static const String _fallbackUrl = 'https://amthgthvrxhlxpttioxu.supabase.co';
  static const String _fallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFtdGhndGh2cnhobHhwdHRpb3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTc5NTMxMDgsImV4cCI6MjAxMzUyOTEwOH0.bA8yP-YtJLwsvbQqS5CwUtUAjuY-75aZPTylU-tZHYI';

  static String get url {
    final envUrl = dotenv.env['SUPABASE_URL'];
    return (envUrl != null && envUrl.isNotEmpty) ? envUrl : _fallbackUrl;
  }

  static String get anonKey {
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    return (envKey != null && envKey.isNotEmpty) ? envKey : _fallbackAnonKey;
  }
}
