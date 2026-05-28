import 'friend_relation.dart';

/// 친구 또는 친구 검색 결과.
///
/// - 검색 결과: 서버가 `relation` 을 채워서 내려준다. `addedAt` 은 null.
/// - 친구 목록 / 받은 요청 목록 응답: `relation` 은 응답에 없고
///   목록의 의미상 명확하므로 (`accepted` / `pendingReceived`) 클라이언트가
///   `fromJson` 호출 시 명시적으로 주입한다. `addedAt` 은 친구 관계 생성 시각.
class Friend {
  final String id;
  final String nickname;
  final String tag;
  final DateTime? addedAt;
  final FriendRelation relation;

  Friend({
    required this.id,
    required this.nickname,
    required this.tag,
    required this.relation,
    this.addedAt,
  });

  String get handle => '$nickname#$tag';

  factory Friend.fromJson(
    Map<String, dynamic> json, {
    FriendRelation? overrideRelation,
  }) {
    final addedAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null;
    return Friend(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      tag: json['tag'] as String,
      addedAt: addedAt,
      relation:
          overrideRelation ??
          FriendRelation.fromDb(json['relation'] as String?),
    );
  }
}
