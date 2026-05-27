import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../models/kakao_place.dart';
import '../../../services/location_service.dart';
import '../../auth/screens/profile_screen.dart';
import '../../place/widgets/place_bottom_sheet.dart';
import '../../place/widgets/search_overlay.dart';
import '../providers/map_provider.dart';
import '../widgets/map_view.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  void initState() {
    super.initState();
    // 지도 진입 시 위치 권한 다이얼로그를 한 번 노출.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.ensurePermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final is3d = ref.watch(is3dProvider);
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'myLocation',
                    onPressed: () => _moveToMyLocation(context, ref),
                    tooltip: '내 위치',
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'toggle3d',
                    onPressed: () => _toggle3d(ref),
                    tooltip: is3d ? '2D로 보기' : '3D로 보기',
                    child: Text(
                      is3d ? '2D' : '3D',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'profile',
                    onPressed: () => _openProfile(context),
                    tooltip: '내 프로필',
                    child: const Icon(Icons.person),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToMyLocation(BuildContext context, WidgetRef ref) async {
    final coord = await LocationService.getCurrentPosition();
    if (coord == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치를 가져올 수 없습니다. 권한과 위치 서비스를 확인해주세요.')),
      );
      return;
    }
    final mapboxMap = ref.read(mapboxMapProvider);
    if (mapboxMap == null) return;

    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    final is3d = ref.read(is3dProvider);
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(coord.lng, coord.lat)),
        zoom: 16.0,
        pitch: is3d ? 60.0 : 0.0,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _toggle3d(WidgetRef ref) async {
    final mapboxMap = ref.read(mapboxMapProvider);
    if (mapboxMap == null) return;
    final next = !ref.read(is3dProvider);
    ref.read(is3dProvider.notifier).state = next;

    final camera = await mapboxMap.getCameraState();
    await mapboxMap.flyTo(
      CameraOptions(
        center: camera.center,
        zoom: next ? camera.zoom.clamp(15.0, 20.0) : camera.zoom,
        pitch: next ? 60.0 : 0.0,
        bearing: camera.bearing,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
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

    final is3d = ref.read(is3dProvider);
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(place.lng, place.lat)),
        zoom: 16.0,
        pitch: is3d ? 60.0 : 0.0,
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
