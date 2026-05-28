import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/api_keys.dart';
import '../models/friend.dart';
import '../models/friend_relation.dart';
import '../models/group.dart';
import '../models/group_member.dart';
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

  // ===== Groups =====

  /// 그룹 생성. owner 는 자동 가입되고, member_user_ids 는 owner 의 accepted 친구여야 한다.
  /// 친구가 아닌 id 가 들어가면 서버에서 raise.
  static Future<String> createGroup({
    required String name,
    required List<String> memberUserIds,
  }) async {
    final data = await client.rpc(
      'create_group',
      params: {'group_name': name, 'member_user_ids': memberUserIds},
    );
    return data as String;
  }

  /// 멤버 추가 (owner only). 친구 관계 검증은 서버에서 한다.
  static Future<void> addGroupMembers({
    required String groupId,
    required List<String> memberUserIds,
  }) async {
    await client.rpc(
      'add_group_members',
      params: {'target_group_id': groupId, 'member_user_ids': memberUserIds},
    );
  }

  /// 멤버 강퇴 (owner only). owner 본인 제거는 RPC 가 거부한다 (leaveGroup 사용).
  static Future<void> removeGroupMember({
    required String groupId,
    required String targetUserId,
  }) async {
    await client.rpc(
      'remove_group_member',
      params: {'target_group_id': groupId, 'target_user_id': targetUserId},
    );
  }

  /// 그룹 나가기. owner 가 나가면 가장 오래된 멤버에게 자동 위임, 멤버가 본인뿐이면 그룹 삭제.
  static Future<void> leaveGroup(String groupId) async {
    await client.rpc('leave_group', params: {'target_group_id': groupId});
  }

  /// owner 가 명시적으로 위임. new_owner 는 이미 그룹 멤버여야 한다.
  static Future<void> transferGroupOwnership({
    required String groupId,
    required String newOwnerId,
  }) async {
    await client.rpc(
      'transfer_group_ownership',
      params: {'target_group_id': groupId, 'new_owner_id': newOwnerId},
    );
  }

  /// 그룹 삭제 (owner only).
  static Future<void> deleteGroup(String groupId) async {
    await client.rpc('delete_group', params: {'target_group_id': groupId});
  }

  /// 그룹 이름 변경 (owner only).
  static Future<void> renameGroup({
    required String groupId,
    required String newName,
  }) async {
    await client.rpc(
      'rename_group',
      params: {'target_group_id': groupId, 'new_name': newName},
    );
  }

  /// 내 그룹 목록 (owner / 일반 멤버 모두).
  static Future<List<Group>> listMyGroups() async {
    final data = await client.rpc('list_my_groups');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Group.fromJson)
        .toList();
  }

  /// 그룹 멤버 목록. 호출자가 그룹 멤버일 때만 의미 있는 결과.
  static Future<List<GroupMember>> listGroupMembers(String groupId) async {
    final data = await client.rpc(
      'list_group_members',
      params: {'target_group_id': groupId},
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(GroupMember.fromJson)
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
