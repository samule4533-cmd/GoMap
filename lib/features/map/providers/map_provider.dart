import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../models/kakao_place.dart';

final mapCenterProvider = StateProvider<({double lat, double lng})>(
  (ref) => (lat: 37.5665, lng: 126.9780),
);

final mapboxMapProvider = StateProvider<MapboxMap?>((ref) => null);

final circleAnnotationManagerProvider = StateProvider<CircleAnnotationManager?>(
  (ref) => null,
);

final selectedPlaceProvider = StateProvider<KakaoPlace?>((ref) => null);

final is3dProvider = StateProvider<bool>((ref) => false);
