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
  @override
  Widget build(BuildContext context) {
    final center = ref.watch(mapCenterProvider);
    return MapWidget(
      viewport: CameraViewportState(
        center: Point(coordinates: Position(center.lng, center.lat)),
        zoom: 14.0,
      ),
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    final manager = await mapboxMap.annotations.createCircleAnnotationManager();
    if (!mounted) return;
    manager.tapEvents(onTap: (_) => widget.onMarkerTap?.call());
    ref.read(mapboxMapProvider.notifier).state = mapboxMap;
    ref.read(circleAnnotationManagerProvider.notifier).state = manager;
  }
}
