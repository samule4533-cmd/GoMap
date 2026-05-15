import 'package:flutter_riverpod/flutter_riverpod.dart';

final mapCenterProvider = StateProvider<({double lat, double lng})>(
  (ref) => (lat: 37.5665, lng: 126.9780),
);
