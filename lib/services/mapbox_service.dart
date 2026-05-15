import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../core/constants/api_keys.dart';

class MapboxService {
  static void init() {
    MapboxOptions.setAccessToken(ApiKeys.mapboxAccessToken);
  }
}
