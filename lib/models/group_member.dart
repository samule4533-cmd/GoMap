/// 그룹 멤버 응답(`list_group_members` RPC).
class GroupMember {
  final String userId;
  final String? nickname;
  final String? tag;
  final DateTime joinedAt;
  final bool isOwner;

  GroupMember({
    required this.userId,
    required this.nickname,
    required this.tag,
    required this.joinedAt,
    required this.isOwner,
  });

  String get handle {
    if (nickname == null) return '-';
    return '$nickname#${tag ?? ''}';
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String?,
      tag: json['tag'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isOwner: json['is_owner'] as bool,
    );
  }
}
