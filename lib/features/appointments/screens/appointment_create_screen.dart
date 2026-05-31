import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../models/kakao_place.dart';
import '../../../services/supabase_service.dart';
import '../../map/providers/map_provider.dart';
import '../../place/providers/search_provider.dart';
import '../../place/widgets/search_overlay.dart';
import '../providers/appointments_provider.dart';

/// 모임장이 그룹 안에서 새 약속을 만드는 화면.
///
/// 흐름: 검색 → 마커 탭 → 후보 추가/제거(2~5개) → "다음" → 메모+마감 → 생성.
/// 메인 지도(MapScreen) 의 전역 mapbox provider 와 충돌하지 않도록 자체
/// MapWidget 인스턴스와 로컬 state 로 격리한다.
class AppointmentCreateScreen extends ConsumerStatefulWidget {
  const AppointmentCreateScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  static const int minCandidates = 2;
  static const int maxCandidates = 5;

  @override
  ConsumerState<AppointmentCreateScreen> createState() =>
      _AppointmentCreateScreenState();
}

class _AppointmentCreateScreenState
    extends ConsumerState<AppointmentCreateScreen> {
  MapboxMap? _map;
  // 현재 검색/선택 핀 (파란).
  CircleAnnotationManager? _selectionManager;
  // 후보 핀들 (빨강).
  CircleAnnotationManager? _candidatesManager;

  ViewportState? _viewport;
  KakaoPlace? _focusedPlace;
  final List<KakaoPlace> _candidates = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final center = ref.read(mapCenterProvider);
    _viewport = CameraViewportState(
      center: Point(coordinates: Position(center.lng, center.lat)),
      zoom: 14.0,
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    final selectionManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    final candidatesManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    if (!mounted) return;
    selectionManager.tapEvents(onTap: (_) => _showFocusedSheet());
    candidatesManager.tapEvents(onTap: (_) => _showCandidatesListSheet());
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    setState(() {
      _map = mapboxMap;
      _selectionManager = selectionManager;
      _candidatesManager = candidatesManager;
      _viewport = null;
    });
  }

  Future<void> _focusPlace(KakaoPlace place) async {
    FocusScope.of(context).unfocus();
    final map = _map;
    final manager = _selectionManager;
    if (map == null || manager == null) return;

    await manager.deleteAll();
    await manager.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(place.lng, place.lat)),
        circleRadius: 8.0,
        circleColor: 0xFF2196F3,
        circleStrokeWidth: 3.0,
        circleStrokeColor: 0xFFFFFFFF,
      ),
    );
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(place.lng, place.lat)),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 800),
    );

    setState(() => _focusedPlace = place);
    if (!mounted) return;
    _showFocusedSheet();
  }

  void _showFocusedSheet() {
    final place = _focusedPlace;
    if (place == null) return;
    final isCandidate = _candidates.any((c) => c.id == place.id);
    final atLimit = _candidates.length >= AppointmentCreateScreen.maxCandidates;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _PickCandidateSheet(
        place: place,
        isCandidate: isCandidate,
        atLimit: atLimit,
        onAdd: () {
          Navigator.of(sheetContext).pop();
          _addCandidate(place);
        },
        onRemove: () {
          Navigator.of(sheetContext).pop();
          _removeCandidate(place);
        },
      ),
    );
  }

  Future<void> _addCandidate(KakaoPlace place) async {
    if (_candidates.any((c) => c.id == place.id)) return;
    if (_candidates.length >= AppointmentCreateScreen.maxCandidates) return;
    setState(() => _candidates.add(place));
    final manager = _candidatesManager;
    if (manager == null) return;
    await manager.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(place.lng, place.lat)),
        circleRadius: 9.0,
        circleColor: 0xFFEF5350,
        circleStrokeWidth: 3.0,
        circleStrokeColor: 0xFFFFFFFF,
      ),
    );
  }

  Future<void> _removeCandidate(KakaoPlace place) async {
    setState(() => _candidates.removeWhere((c) => c.id == place.id));
    // 핀 단건 식별이 까다로워 전체 재그리기. 후보 최대 5개라 비용 무시 가능.
    final manager = _candidatesManager;
    if (manager == null) return;
    await manager.deleteAll();
    for (final c in _candidates) {
      await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(c.lng, c.lat)),
          circleRadius: 9.0,
          circleColor: 0xFFEF5350,
          circleStrokeWidth: 3.0,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    }
  }

  Future<void> _showCandidatesListSheet() async {
    if (_candidates.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _CandidatesListSheet(
        candidates: List.unmodifiable(_candidates),
        onRemove: (place) {
          Navigator.of(sheetContext).pop();
          _removeCandidate(place);
        },
      ),
    );
  }

  Future<void> _next() async {
    if (_candidates.length < AppointmentCreateScreen.minCandidates) return;
    final meta = await showModalBottomSheet<_MetaResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MetaSheet(),
    );
    if (meta == null) return;
    await _submit(meta);
  }

  Future<void> _submit(_MetaResult meta) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final placeIds = <String>[];
      for (final kp in _candidates) {
        final id = await SupabaseService.upsertPlaceFromKakao(kp);
        placeIds.add(id);
      }
      await SupabaseService.createAppointment(
        groupId: widget.groupId,
        memo: meta.memo,
        deadlineAt: meta.deadlineAt,
        placeIds: placeIds,
      );
      if (!mounted) return;
      ref.invalidate(groupAppointmentsProvider(widget.groupId));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('약속을 만들었습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('약속 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed =
        _candidates.length >= AppointmentCreateScreen.minCandidates && !_saving;
    final collapsed = ref.watch(searchListCollapsedProvider);
    final results = ref.watch(searchResultsProvider);
    final showBackdrop =
        !collapsed &&
        results.maybeWhen(
          data: (places) => places.isNotEmpty,
          orElse: () => false,
        );
    return Scaffold(
      appBar: AppBar(title: Text('새 약속 · ${widget.groupName}')),
      body: Stack(
        children: [
          MapWidget(
            viewport: _viewport,
            styleUri: MapboxStyles.STANDARD,
            onMapCreated: _onMapCreated,
          ),
          if (showBackdrop)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  ref.read(searchListCollapsedProvider.notifier).state = true;
                },
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SearchOverlay(onPlaceTap: _focusPlace),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CandidatesBar(
              count: _candidates.length,
              max: AppointmentCreateScreen.maxCandidates,
              min: AppointmentCreateScreen.minCandidates,
              canProceed: canProceed,
              saving: _saving,
              onListTap: _candidates.isEmpty ? null : _showCandidatesListSheet,
              onNext: _next,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickCandidateSheet extends StatelessWidget {
  const _PickCandidateSheet({
    required this.place,
    required this.isCandidate,
    required this.atLimit,
    required this.onAdd,
    required this.onRemove,
  });

  final KakaoPlace place;
  final bool isCandidate;
  final bool atLimit;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = place.roadAddress ?? place.address;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.title, style: theme.textTheme.titleLarge),
            if (place.category != null) ...[
              const SizedBox(height: 4),
              Text(
                place.category!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(subtitle)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (isCandidate)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('후보에서 제거'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: atLimit ? null : onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(atLimit ? '후보는 최대 5개까지' : '후보로 추가'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CandidatesListSheet extends StatelessWidget {
  const _CandidatesListSheet({
    required this.candidates,
    required this.onRemove,
  });

  final List<KakaoPlace> candidates;
  final void Function(KakaoPlace) onRemove;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '후보 ${candidates.length}개',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = candidates[i];
                final subtitle = p.roadAddress ?? p.address;
                return ListTile(
                  title: Text(p.title),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '제거',
                    onPressed: () => onRemove(p),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidatesBar extends StatelessWidget {
  const _CandidatesBar({
    required this.count,
    required this.max,
    required this.min,
    required this.canProceed,
    required this.saving,
    required this.onListTap,
    required this.onNext,
  });

  final int count;
  final int max;
  final int min;
  final bool canProceed;
  final bool saving;
  final VoidCallback? onListTap;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hint = count < min ? '후보를 $min개 이상 골라주세요' : '$count/$max 선택됨';
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onListTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(hint, style: theme.textTheme.bodyMedium),
                        if (onListTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_less,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: canProceed ? onNext : null,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('다음'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaResult {
  _MetaResult({required this.memo, required this.deadlineAt});

  final String? memo;
  final DateTime deadlineAt;
}

class _MetaSheet extends StatefulWidget {
  const _MetaSheet();

  @override
  State<_MetaSheet> createState() => _MetaSheetState();
}

class _MetaSheetState extends State<_MetaSheet> {
  final _memoController = TextEditingController();
  // 분(minute) 단위.
  static const _options = [
    (label: '1시간', minutes: 60),
    (label: '6시간', minutes: 360),
    (label: '24시간', minutes: 1440),
    (label: '48시간', minutes: 2880),
  ];
  int _selectedMinutes = 1440;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _submit() {
    final deadlineAt = DateTime.now().add(Duration(minutes: _selectedMinutes));
    final memo = _memoController.text.trim();
    Navigator.of(context).pop(
      _MetaResult(memo: memo.isEmpty ? null : memo, deadlineAt: deadlineAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = DateFormat(
      'M월 d일 HH:mm',
    ).format(DateTime.now().add(Duration(minutes: _selectedMinutes)).toLocal());
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('메모', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '시간 / 장소 상세 / 기타 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('투표 마감', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final opt in _options)
                  ChoiceChip(
                    label: Text(opt.label),
                    selected: _selectedMinutes == opt.minutes,
                    onSelected: (_) =>
                        setState(() => _selectedMinutes = opt.minutes),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '마감: $preview',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.event_available),
                label: const Text('약속 만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
