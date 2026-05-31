/// 약속 상세(`get_appointment_detail` RPC) 한 행.
///
/// 한 후보 장소에 대한 place 메타 + 표 수 + 내가 이 후보에 투표했는지 여부.
/// place 정보는 평탄화돼 있어서 별도 Place 객체로 감싸지 않는다.
class AppointmentCandidate {
  final String candidateId;
  final String placeId;
  final String placeName;
  final String? placeAddress;
  final double placeLat;
  final double placeLng;
  final String? placeCategory;
  final int voteCount;
  final bool isMyVote;

  AppointmentCandidate({
    required this.candidateId,
    required this.placeId,
    required this.placeName,
    required this.placeAddress,
    required this.placeLat,
    required this.placeLng,
    required this.placeCategory,
    required this.voteCount,
    required this.isMyVote,
  });

  factory AppointmentCandidate.fromJson(Map<String, dynamic> json) {
    return AppointmentCandidate(
      candidateId: json['candidate_id'] as String,
      placeId: json['place_id'] as String,
      placeName: json['place_name'] as String,
      placeAddress: json['place_address'] as String?,
      placeLat: (json['place_lat'] as num).toDouble(),
      placeLng: (json['place_lng'] as num).toDouble(),
      placeCategory: json['place_category'] as String?,
      voteCount: (json['vote_count'] as num).toInt(),
      isMyVote: json['is_my_vote'] as bool,
    );
  }
}
