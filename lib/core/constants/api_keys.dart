class ApiKeys {
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
  );
  static const String kakaoRestApiKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
  );
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}
