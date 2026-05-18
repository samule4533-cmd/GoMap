import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../models/naver_place.dart';

final mapCenterProvider = StateProvider<({double lat, double lng})>(
  (ref) => (lat: 37.5665, lng: 126.9780),
);

final mapboxMapProvider = StateProvider<MapboxMap?>((ref) => null);

final circleAnnotationManagerProvider = StateProvider<CircleAnnotationManager?>(
  (ref) => null,
);

final selectedPlaceProvider = StateProvider<NaverPlace?>((ref) => null);
