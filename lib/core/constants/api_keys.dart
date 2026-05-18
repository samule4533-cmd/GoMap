class ApiKeys {
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
  );
  static const String naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');
  static const String naverClientSecret = String.fromEnvironment(
    'NAVER_CLIENT_SECRET',
  );
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}
