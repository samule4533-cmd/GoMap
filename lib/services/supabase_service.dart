import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/api_keys.dart';
import '../models/friend.dart';
import '../models/kakao_place.dart';
import '../models/place_visibility.dart';
import '../models/profile.dart';
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

  /// 현재 로그인된 사용자의 프로필. 없으면 null (= 신규 가입 직후).
  static Future<Profile?> fetchMyProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// 프로필 생성. (nickname, tag) 중복 시 PostgrestException(code 23505).
  static Future<Profile> createMyProfile({
    required String nickname,
    required String tag,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    final data = await client
        .from('profiles')
        .insert({'id': userId, 'nickname': nickname, 'tag': tag})
        .select()
        .single();
    return Profile.fromJson(data);
  }

  /// 프로필 수정. (nickname, tag) 중복 시 PostgrestException(code 23505).
  /// updated_at 은 DB 트리거가 자동 갱신하므로 보내지 않는다.
  static Future<Profile> updateMyProfile({
    required String nickname,
    required String tag,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    final data = await client
        .from('profiles')
        .update({'nickname': nickname, 'tag': tag})
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  // ===== Friends =====

  /// 핸들로 사용자 검색 (정확 매칭). 결과 없으면 null.
  static Future<Friend?> searchProfileByHandle({
    required String nickname,
    required String tag,
  }) async {
    final data = await client.rpc(
      'search_profile_by_handle',
      params: {'search_nickname': nickname, 'search_tag': tag},
    );
    final list = (data as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    return Friend.fromJson(list.first);
  }

  /// 친구 추가 (양방향). 본인 추가/이미 친구 시 RPC 가 처리.
  static Future<void> addFriend(String targetUserId) async {
    await client.rpc('add_friend', params: {'target_user_id': targetUserId});
  }

  /// 친구 삭제 (양방향).
  static Future<void> removeFriend(String targetUserId) async {
    await client.rpc('remove_friend', params: {'target_user_id': targetUserId});
  }

  /// 내 친구 목록 (가입일 내림차순).
  static Future<List<Friend>> listMyFriends() async {
    final data = await client.rpc('list_my_friends');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Friend.fromJson)
        .toList();
  }

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
