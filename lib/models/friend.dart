/// 친구 또는 친구 검색 결과.
/// addedAt 이 null 이면 아직 친구가 아닌 검색 결과,
/// not null 이면 이미 친구 관계 (friendship.created_at).
///
/// isFriend 는 검색 결과 응답에 서버가 채워주는 플래그다.
/// 친구 목록에서 만들어진 인스턴스는 항상 true.
class Friend {
  final String id;
  final String nickname;
  final String tag;
  final DateTime? addedAt;
  final bool isFriend;

  Friend({
    required this.id,
    required this.nickname,
    required this.tag,
    this.addedAt,
    this.isFriend = false,
  });

  String get handle => '$nickname#$tag';

  factory Friend.fromJson(Map<String, dynamic> json) {
    final addedAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null;
    return Friend(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      tag: json['tag'] as String,
      addedAt: addedAt,
      // 친구 목록 응답에는 is_friend 가 없지만 그 자체로 친구다.
      isFriend: (json['is_friend'] as bool?) ?? (addedAt != null),
    );
  }
}
