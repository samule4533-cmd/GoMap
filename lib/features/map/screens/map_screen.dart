import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../models/naver_place.dart';
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
        ],
      ),
    );
  }

  Future<void> _focusPlace(
    BuildContext context,
    WidgetRef ref,
    NaverPlace place,
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

  void _showSheet(BuildContext context, NaverPlace place) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => PlaceBottomSheet(place: place),
    );
  }
}
