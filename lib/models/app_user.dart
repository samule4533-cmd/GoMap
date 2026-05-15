class AppUser {
  final String id;
  final String? nickname;
  final String? profileImage;

  AppUser({
    required this.id,
    this.nickname,
    this.profileImage,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        nickname: json['nickname'] as String?,
        profileImage: json['profile_image'] as String?,
      );
}
