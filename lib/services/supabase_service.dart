import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/api_keys.dart';
import '../models/friend.dart';
import '../models/friend_relation.dart';
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
    // supabase_flutter 2.x 의 기본 auth flow 는 PKCE. PKCE 흐름에서 6자리 OTP
    // 검증은 OtpType.email 로 받는다. OtpType.signup 은 implicit flow 잔재라
    // PKCE 환경에서는 'token expired or invalid' 로 떨어진다.
    return auth.verifyOTP(email: email, token: token, type: OtpType.email);
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

  /// 친구 요청 보내기. 양쪽 row 가 pending 으로 생성된다.
  /// 이미 관계가 있으면 RPC 가 조용히 무시.
  static Future<void> requestFriend(String targetUserId) async {
    await client.rpc(
      'request_friend',
      params: {'target_user_id': targetUserId},
    );
  }

  /// 받은 친구 요청 수락. requester 가 보낸 pending 만 수락 가능.
  static Future<void> acceptFriendRequest(String requesterUserId) async {
    await client.rpc(
      'accept_friend_request',
      params: {'requester_user_id': requesterUserId},
    );
  }

  /// 양방향 friendship 삭제. 보낸 요청 취소, 받은 요청 거절, 친구 해제 공통.
  static Future<void> removeFriend(String targetUserId) async {
    await client.rpc('remove_friend', params: {'target_user_id': targetUserId});
  }

  /// 내 친구 목록 (accepted only, 생성일 내림차순).
  static Future<List<Friend>> listMyFriends() async {
    final data = await client.rpc('list_my_friends');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(
          (json) =>
              Friend.fromJson(json, overrideRelation: FriendRelation.accepted),
        )
        .toList();
  }

  /// 내가 받은 친구 요청 목록 (pending only).
  static Future<List<Friend>> listMyPendingRequests() async {
    final data = await client.rpc('list_my_pending_requests');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(
          (json) => Friend.fromJson(
            json,
            overrideRelation: FriendRelation.pendingReceived,
          ),
        )
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
