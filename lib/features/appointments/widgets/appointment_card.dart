import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/appointment.dart';
import '../../../models/appointment_status.dart';

/// 그룹 상세 / 약속 목록에 노출되는 한 줄 카드.
///
/// totalMemberCount 는 상위(그룹 멤버 목록)에서 전달. 별도 RPC 호출 없이
/// 현재 화면에 이미 있는 정보로 "투표 V/M명" 표시를 구성한다.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.totalMemberCount,
    required this.onTap,
  });

  final Appointment appointment;
  final int totalMemberCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final IconData icon;
    final Color iconColor;
    final Color iconBg;
    switch (appointment.status) {
      case AppointmentStatus.open:
        icon = Icons.schedule;
        iconColor = scheme.primary;
        iconBg = scheme.primaryContainer;
      case AppointmentStatus.tie:
        icon = Icons.balance;
        iconColor = Colors.orange.shade700;
        iconBg = Colors.orange.shade50;
      case AppointmentStatus.closed:
        icon = Icons.check_circle;
        iconColor = Colors.green.shade700;
        iconBg = Colors.green.shade50;
    }

    final String subtitle;
    if (appointment.isOpen) {
      final base =
          '후보 ${appointment.candidateCount} · 투표 ${appointment.voteCount}/$totalMemberCount명';
      subtitle = appointment.hasMyVote ? '$base · 내 투표 완료' : base;
    } else if (appointment.isTie) {
      subtitle = '동률 · 모임장 결정 대기';
    } else if (appointment.winningPlaceName != null) {
      subtitle = '확정: ${appointment.winningPlaceName}';
    } else {
      subtitle = '확정됨';
    }

    final timeLabel = appointment.isOpen
        ? _formatRemaining(appointment.deadlineAt)
        : appointment.closedAt != null
        ? '${DateFormat('M월 d일 HH:mm').format(appointment.closedAt!.toLocal())} 마감'
        : '';

    final title = (appointment.memo == null || appointment.memo!.trim().isEmpty)
        ? '${appointment.ownerHandle}의 약속'
        : appointment.memo!.split('\n').first.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRemaining(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return '마감 도과';
    if (diff.inDays >= 1) return 'D-${diff.inDays}';
    if (diff.inHours >= 1) return '${diff.inHours}시간 뒤';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}분 뒤';
    return '곧 마감';
  }
}
