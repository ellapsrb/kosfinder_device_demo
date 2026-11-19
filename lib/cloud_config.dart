/// Konfigurasi cloud opsional.
/// Aplikasi tetap bisa berjalan tanpa Supabase.
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get enabled => url.isNotEmpty && publishableKey.isNotEmpty;
}
