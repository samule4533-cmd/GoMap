import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../providers/map_provider.dart';

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key, this.onMarkerTap});

  final VoidCallback? onMarkerTap;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  // 초기 카메라 위치만 viewport로 설정. onMapCreated 이후 null로 해제하여
  // flyTo / setCamera 가 viewport state machine과 충돌하지 않도록.
  ViewportState? _viewport;

  @override
  void initState() {
    super.initState();
    final center = ref.read(mapCenterProvider);
    _viewport = CameraViewportState(
      center: Point(coordinates: Position(center.lng, center.lat)),
      zoom: 14.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(viewport: _viewport, onMapCreated: _onMapCreated);
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    final manager = await mapboxMap.annotations.createCircleAnnotationManager();
    if (!mounted) return;
    manager.tapEvents(onTap: (_) => widget.onMarkerTap?.call());
    ref.read(mapboxMapProvider.notifier).state = mapboxMap;
    ref.read(circleAnnotationManagerProvider.notifier).state = manager;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    // 초기 카메라 셋팅 끝나면 viewport 해제 → 이후 flyTo 동작 가능
    if (mounted) {
      setState(() => _viewport = null);
    }
  }
}
