/// 현재 로그인 사용자와 다른 사용자 간의 친구 관계 상태.
///
/// 검색 RPC (`search_profile_by_handle`) 응답의 `relation` 컬럼이 곧 이 값.
/// UI 는 이 값으로 친구 신청 / 수락 / 취소 / 이미 친구 분기를 한 번에 한다.
enum FriendRelation {
  /// 아무 관계도 없음.
  none,

  /// 내가 보낸 요청이 수락 대기 중.
  pendingSent,

  /// 상대가 나에게 보낸 요청을 내가 수락해야 하는 상태.
  pendingReceived,

  /// 양방향 친구.
  accepted;

  String get dbValue => switch (this) {
    FriendRelation.none => 'none',
    FriendRelation.pendingSent => 'pending_sent',
    FriendRelation.pendingReceived => 'pending_received',
    FriendRelation.accepted => 'accepted',
  };

  static FriendRelation fromDb(String? value) => switch (value) {
    'pending_sent' => FriendRelation.pendingSent,
    'pending_received' => FriendRelation.pendingReceived,
    'accepted' => FriendRelation.accepted,
    _ => FriendRelation.none,
  };
}
