import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/api_keys.dart';
import '../models/kakao_place.dart';
import '../models/place_visibility.dart';
import '../models/saved_place.dart';

class SupabaseService {
  static Future<void> init() async {
    if (ApiKeys.supabaseUrl.isEmpty || ApiKeys.supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY 가 비어있습니다. '
        '.env 에 값을 넣고 `flutter run --dart-define-from-file=.env` 로 실행하세요.',
      );
    }
    await Supabase.initialize(
      url: ApiKeys.supabaseUrl,
      anonKey: ApiKeys.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => Supabase.instance.client.auth;

  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) {
    return auth.verifyOTP(email: email, token: token, type: OtpType.signup);
  }

  static Future<void> resendSignupOtp({required String email}) {
    return auth.resend(type: OtpType.signup, email: email);
  }

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => auth.signOut();

  Future<List<SavedPlace>> fetchMySavedPlaces() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await client
        .from('saved_places')
        .select('*, place:places(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(SavedPlace.fromJson)
        .toList();
  }

  Future<void> saveFromKakao({
    required KakaoPlace kakaoPlace,
    String? memo,
    PlaceVisibility visibility = PlaceVisibility.private,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');

    final placeRow = await client
        .from('places')
        .upsert({
          'provider': 'kakao',
          'provider_key': kakaoPlace.id,
          'name': kakaoPlace.title,
          'address': kakaoPlace.roadAddress ?? kakaoPlace.address,
          'lat': kakaoPlace.lat,
          'lng': kakaoPlace.lng,
          'category': kakaoPlace.category,
        }, onConflict: 'provider,provider_key')
        .select()
        .single();

    await client.from('saved_places').insert({
      'user_id': userId,
      'place_id': placeRow['id'],
      'memo': memo,
      'visibility': visibility.dbValue,
    });
  }
}
