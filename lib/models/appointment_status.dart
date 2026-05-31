/// 약속 상태. DB 의 `appointments.status` 값과 1:1 매칭.
///
/// - [open]: 투표 진행 중.
/// - [tie]: 자동 마감했지만 동률. 모임장이 `resolve_appointment_tie` 로 확정해야 함.
/// - [closed]: 확정됨. `winning_place_id` 가 결정된 상태.
enum AppointmentStatus {
  open('open'),
  tie('tie'),
  closed('closed');

  const AppointmentStatus(this.dbValue);

  final String dbValue;

  static AppointmentStatus fromDb(String value) => values.firstWhere(
    (v) => v.dbValue == value,
    orElse: () => AppointmentStatus.open,
  );
}
