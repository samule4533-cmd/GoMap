/// 그룹 목록 응답(`list_my_groups` RPC).
///
/// 모임장 정보는 평탄화해서 내려옴(`owner_nickname`/`owner_tag`).
/// `memberCount`는 RPC 가 집계해서 내려주는 값.
class Group {
  final String id;
  final String name;
  final String ownerId;
  final String? ownerNickname;
  final String? ownerTag;
  final int memberCount;
  final bool isOwner;
  final DateTime joinedAt;

  Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerNickname,
    required this.ownerTag,
    required this.memberCount,
    required this.isOwner,
    required this.joinedAt,
  });

  String get ownerHandle {
    if (ownerNickname == null) return '-';
    return '$ownerNickname#${ownerTag ?? ''}';
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      ownerNickname: json['owner_nickname'] as String?,
      ownerTag: json['owner_tag'] as String?,
      memberCount: (json['member_count'] as num).toInt(),
      isOwner: json['is_owner'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
