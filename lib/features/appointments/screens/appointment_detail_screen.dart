import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/appointment.dart';
import '../../../models/appointment_candidate.dart';
import '../../../models/appointment_status.dart';
import '../../../services/supabase_service.dart';
import '../providers/appointments_provider.dart';

/// 약속 상세 화면.
///
/// - 진입 시 1회 `maybe_close_appointment` 호출해 시간 만료 lazy close 처리
/// - 메타(상태/만든이/메모/마감)는 [groupAppointmentsProvider] 캐시에서 derive,
///   후보 + 투표 표 수는 [appointmentDetailProvider]
/// - open: 후보 탭으로 투표 (변경 가능)
/// - tie + owner: 후보 탭으로 동률 해소 확정
/// - closed: winner 강조
class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    required this.groupId,
  });

  final String appointmentId;
  final String groupId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  // 사용자가 화면에서 고른 후보. 서버 반영 전 임시 선택.
  // null 이면 "아직 변경 안 함" 의미 — 화면은 서버 값(myCandidateId) 을 보여준다.
  String? _localChoice;
  // 투표 저장 / 동률 해소 / 약속 삭제 진행 상태 공용.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lazyClose());
  }

  Future<void> _lazyClose() async {
    try {
      await SupabaseService.maybeCloseAppointment(widget.appointmentId);
    } catch (_) {
      // 만료 lazy close 는 실패해도 사용자에게 알릴 필요 없음.
      // 진짜로 상태 변경이 필요했다면 다음 진입 / refresh 에서 다시 시도된다.
    }
    if (!mounted) return;
    ref.invalidate(groupAppointmentsProvider(widget.groupId));
    ref.invalidate(appointmentDetailProvider(widget.appointmentId));
  }

  void _setLocalChoice(String candidateId) {
    if (_busy) return;
    setState(() => _localChoice = candidateId);
  }

  Future<void> _saveVote() async {
    final pending = _localChoice;
    if (pending == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SupabaseService.castVote(
        appointmentId: widget.appointmentId,
        candidateId: pending,
      );
      if (!mounted) return;
      ref.invalidate(groupAppointmentsProvider(widget.groupId));
      ref.invalidate(appointmentDetailProvider(widget.appointmentId));
      // 저장 성공 → 서버 값을 진실로. 로컬 변경 상태 초기화.
      setState(() => _localChoice = null);
      messenger.showSnackBar(const SnackBar(content: Text('투표를 저장했습니다')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('투표 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveTie(AppointmentCandidate c) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이 후보로 확정'),
        content: Text('${c.placeName} 으로 확정하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('확정'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.resolveAppointmentTie(
        appointmentId: widget.appointmentId,
        winningCandidateId: c.candidateId,
      );
      if (!mounted) return;
      ref.invalidate(groupAppointmentsProvider(widget.groupId));
      ref.invalidate(appointmentDetailProvider(widget.appointmentId));
      messenger.showSnackBar(
        SnackBar(content: Text('${c.placeName} 으로 확정했습니다')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('확정 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('약속 삭제'),
        content: const Text('이 약속을 삭제하시겠습니까? 후보와 투표가 모두 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.cancelAppointment(widget.appointmentId);
      if (!mounted) return;
      ref.invalidate(groupAppointmentsProvider(widget.groupId));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('약속을 삭제했습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(
      groupAppointmentsProvider(widget.groupId),
    );
    final detailsAsync = ref.watch(
      appointmentDetailProvider(widget.appointmentId),
    );
    final currentUserId = SupabaseService.auth.currentUser?.id;

    final appt = appointmentsAsync.maybeWhen(
      data: (list) {
        for (final a in list) {
          if (a.id == widget.appointmentId) return a;
        }
        return null;
      },
      orElse: () => null,
    );
    final isOwner = appt != null && appt.ownerId == currentUserId;
    final displayedChoice = _localChoice ?? appt?.myCandidateId;
    final isDirty =
        appt != null &&
        _localChoice != null &&
        _localChoice != appt.myCandidateId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('약속'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') _cancel();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cancel', child: Text('약속 삭제')),
              ],
            ),
        ],
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('약속을 불러올 수 없습니다: $e')),
        data: (list) {
          if (appt == null) {
            return const Center(child: Text('약속이 삭제되었거나 접근 권한이 없습니다'));
          }
          return detailsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('후보를 불러올 수 없습니다: $e')),
            data: (candidates) => _buildBody(
              appt,
              candidates,
              isOwner: isOwner,
              displayedChoice: displayedChoice,
            ),
          );
        },
      ),
      bottomNavigationBar: appt != null && appt.isOpen
          ? _SaveBar(
              hasMyVote: appt.hasMyVote,
              hasSelection: displayedChoice != null,
              isDirty: isDirty,
              saving: _busy,
              onSave: _saveVote,
            )
          : null,
    );
  }

  Widget _buildBody(
    Appointment appt,
    List<AppointmentCandidate> candidates, {
    required bool isOwner,
    required String? displayedChoice,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(groupAppointmentsProvider(widget.groupId));
        ref.invalidate(appointmentDetailProvider(widget.appointmentId));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _MetaCard(appointment: appt),
          if (appt.isTie) ...[
            const SizedBox(height: 12),
            _TieNotice(isOwner: isOwner),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              appt.isOpen ? '투표' : '후보',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final c in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CandidateCard(
                candidate: c,
                isWinner: appt.winningPlaceId == c.placeId,
                isMyChoice: appt.isOpen && displayedChoice == c.candidateId,
                canVote: appt.isOpen,
                canResolveTie: appt.isTie && isOwner,
                onTap: () {
                  if (appt.isOpen) {
                    _setLocalChoice(c.candidateId);
                  } else if (appt.isTie && isOwner) {
                    _resolveTie(c);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color badgeBg;
    final Color badgeFg;
    final String badgeText;
    switch (appointment.status) {
      case AppointmentStatus.open:
        badgeBg = scheme.primaryContainer;
        badgeFg = scheme.onPrimaryContainer;
        badgeText = '진행 중';
      case AppointmentStatus.tie:
        badgeBg = Colors.orange.shade100;
        badgeFg = Colors.orange.shade900;
        badgeText = '동률';
      case AppointmentStatus.closed:
        badgeBg = Colors.green.shade100;
        badgeFg = Colors.green.shade900;
        badgeText = '확정';
    }

    final deadlineLabel = DateFormat(
      'M월 d일 HH:mm',
    ).format(appointment.deadlineAt.toLocal());
    final closedLabel = appointment.closedAt == null
        ? null
        : DateFormat('M월 d일 HH:mm').format(appointment.closedAt!.toLocal());

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  appointment.ownerHandle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (appointment.memo != null && appointment.memo!.isNotEmpty)
              Text(appointment.memo!, style: theme.textTheme.bodyLarge)
            else
              Text(
                '메모 없음',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  appointment.isOpen
                      ? '투표 마감 $deadlineLabel'
                      : (closedLabel != null ? '$closedLabel 마감됨' : '마감됨'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (appointment.isClosed &&
                appointment.winningPlaceName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '확정 장소: ${appointment.winningPlaceName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TieNotice extends StatelessWidget {
  const _TieNotice({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.balance, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOwner ? '동률입니다. 후보를 탭해 확정해주세요.' : '동률입니다. 모임장의 결정을 기다리는 중입니다.',
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.isWinner,
    required this.isMyChoice,
    required this.canVote,
    required this.canResolveTie,
    required this.onTap,
  });

  final AppointmentCandidate candidate;
  final bool isWinner;

  /// 화면에 표시될 "내 선택". 저장 안 된 로컬 선택과 서버 저장본을 통합한 값.
  final bool isMyChoice;
  final bool canVote;
  final bool canResolveTie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color borderColor;
    final Color bg;
    if (isWinner) {
      borderColor = Colors.green.shade400;
      bg = Colors.green.shade50;
    } else if (isMyChoice) {
      borderColor = scheme.primary;
      bg = scheme.primaryContainer.withValues(alpha: 0.4);
    } else {
      borderColor = scheme.outlineVariant;
      bg = scheme.surface;
    }

    final tappable = canVote || canResolveTie;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: tappable ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: isMyChoice ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            candidate.placeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (isWinner) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                        ] else if (isMyChoice) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.radio_button_checked,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ],
                      ],
                    ),
                    if (candidate.placeAddress != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        candidate.placeAddress!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (candidate.placeCategory != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        candidate.placeCategory!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _VoteCount(count: candidate.voteCount, highlight: isWinner),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.hasMyVote,
    required this.hasSelection,
    required this.isDirty,
    required this.saving,
    required this.onSave,
  });

  /// 서버에 이미 저장된 내 투표가 있는지.
  final bool hasMyVote;

  /// 화면 상의 선택(서버 + 로컬) 이 하나라도 있는지.
  final bool hasSelection;

  /// 로컬 선택이 서버 값과 다른 상태 (저장 필요).
  final bool isDirty;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final String hint;
    if (saving) {
      hint = '투표 저장 중…';
    } else if (isDirty) {
      hint = hasMyVote ? '변경된 투표를 저장하세요' : '선택한 후보로 투표하세요';
    } else if (hasMyVote) {
      hint = '내 투표 저장됨';
    } else if (hasSelection) {
      // 미투표인데 선택은 있을 수 없는 케이스. defensive.
      hint = '후보를 선택해주세요';
    } else {
      hint = '후보를 선택해주세요';
    }

    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: isDirty && !saving ? onSave : null,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_vote, size: 18),
                label: Text(hasMyVote ? '변경 저장' : '투표 저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteCount extends StatelessWidget {
  const _VoteCount({required this.count, required this.highlight});

  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? Colors.green.shade700
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text('표', style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
