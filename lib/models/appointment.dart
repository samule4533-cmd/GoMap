import 'appointment_status.dart';

/// 약속 목록(`list_group_appointments` RPC) 한 행.
///
/// 모임장 정보는 평탄화되어 내려옴(`owner_nickname` / `owner_tag`).
/// `myCandidateId` 는 호출자가 이 약속에서 투표한 후보의 id (`candidate_places.id`)
/// 이며 미투표면 null.
class Appointment {
  final String id;
  final String groupId;
  final String ownerId;
  final String? ownerNickname;
  final String? ownerTag;
  final String? memo;
  final DateTime deadlineAt;
  final AppointmentStatus status;
  final String? winningPlaceId;
  final String? winningPlaceName;
  final DateTime? closedAt;
  final int candidateCount;
  final int voteCount;
  final String? myCandidateId;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.groupId,
    required this.ownerId,
    required this.ownerNickname,
    required this.ownerTag,
    required this.memo,
    required this.deadlineAt,
    required this.status,
    required this.winningPlaceId,
    required this.winningPlaceName,
    required this.closedAt,
    required this.candidateCount,
    required this.voteCount,
    required this.myCandidateId,
    required this.createdAt,
  });

  String get ownerHandle {
    if (ownerNickname == null) return '-';
    return '$ownerNickname#${ownerTag ?? ''}';
  }

  bool get isOpen => status == AppointmentStatus.open;
  bool get isTie => status == AppointmentStatus.tie;
  bool get isClosed => status == AppointmentStatus.closed;
  bool get hasMyVote => myCandidateId != null;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      ownerId: json['owner_id'] as String,
      ownerNickname: json['owner_nickname'] as String?,
      ownerTag: json['owner_tag'] as String?,
      memo: json['memo'] as String?,
      deadlineAt: DateTime.parse(json['deadline_at'] as String),
      status: AppointmentStatus.fromDb(json['status'] as String),
      winningPlaceId: json['winning_place_id'] as String?,
      winningPlaceName: json['winning_place_name'] as String?,
      closedAt: json['closed_at'] == null
          ? null
          : DateTime.parse(json['closed_at'] as String),
      candidateCount: (json['candidate_count'] as num).toInt(),
      voteCount: (json['vote_count'] as num).toInt(),
      myCandidateId: json['my_candidate_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
