class Profile {
  final String id;
  final String nickname;
  final String tag;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.nickname,
    required this.tag,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 친구 식별자. 예: "신승우#개발자"
  String get handle => '$nickname#$tag';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    tag: json['tag'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}
