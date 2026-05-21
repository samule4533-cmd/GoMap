import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../models/kakao_place.dart';
import '../../../services/supabase_service.dart';
import '../../place/widgets/place_bottom_sheet.dart';
import '../../place/widgets/search_overlay.dart';
import '../providers/map_provider.dart';
import '../widgets/map_view.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          MapView(onMarkerTap: () => _onMarkerTap(context, ref)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SearchOverlay(
                  onPlaceTap: (place) => _focusPlace(context, ref, place),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'logout',
                onPressed: () => _confirmLogout(context),
                child: const Icon(Icons.logout),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.signOut();
      // 세션 종료 시 authStateProvider 가 변화를 받아 AuthGate 가 로그인 화면으로 전환.
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e')));
    }
  }

  Future<void> _focusPlace(
    BuildContext context,
    WidgetRef ref,
    KakaoPlace place,
  ) async {
    FocusScope.of(context).unfocus();

    final mapboxMap = ref.read(mapboxMapProvider);
    final manager = ref.read(circleAnnotationManagerProvider);
    if (mapboxMap == null || manager == null) return;

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

    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(place.lng, place.lat)),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    ref.read(selectedPlaceProvider.notifier).state = place;
    if (!context.mounted) return;
    _showSheet(context, place);
  }

  void _onMarkerTap(BuildContext context, WidgetRef ref) {
    final place = ref.read(selectedPlaceProvider);
    if (place == null) return;
    _showSheet(context, place);
  }

  void _showSheet(BuildContext context, KakaoPlace place) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => PlaceBottomSheet(place: place),
    );
  }
}
